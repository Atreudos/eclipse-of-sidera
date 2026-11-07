class_name RunController
extends Node2D
## Koşu (run). Normal kipte koşu 18 KATtan oluşur; her kat 6 odadır:
##
##   1. LOBİ (düşmansız: hazırlık + dükkân) -> 2-5. SAVAŞ odaları -> 6. GÖLGE odası (patron) -> kat geçidi -> sonraki katın lobisi
##
## Bir katın odaları SAĞA doğru soldan sağa dizilir. Savaş odasında dalgalar sırayla doğar; temizlenince sağ kapı açılır,
## yeni odanın içine ~130 px girince kapı arkandan kapanır. Gölge odasının sonunda kapı yerine KAT GEÇİDİ vardır: açık geçide
## yürüyünce ekran kararır, eski kat silinir, yeni katın lobisi x = 0'dan kurulur ve "KAT n" kartı çıkar.
## Oda içeriği (yerleşim, dalgalar, dükkân rafı) yalnız (tohum, oda no)'ya bağlıdır: aynı tohum = aynı koşu.
## `floors_enabled = false`: eski davranış (kat ve lobi yok; odalar tek sonsuz şeritte akar). Testler ve geliştirme içindir.
## Kamera sınırları: yalnızca bulunduğun oda; oda temizlenince sağdaki oda da eklenir, geçince eskisi çıkar.

signal room_changed(index: int)
## Yeni bir katın lobisine girildi.
signal floor_changed(floor_no: int)
## Son katın Gölge'si yenildi.
signal run_won

const SAGITTA := preload("res://actors/enemies/sagitta.tscn")
const TAURUS := preload("res://actors/enemies/taurus.tscn")
const SCORPIUS := preload("res://actors/enemies/scorpius.tscn")

## Scorpius ilk kez bu tur ilerlemesinde (0'dan sayılır) görünür: 3. savaş odası, 2. dalga.
const SCORPIUS_FIRST_ROOM := 2

## İlk savaş odası: test arenasına benzer (iki platform), oyuncu alışsın.
const FIRST_LAYOUT := "iki_kule"
## Oyuncu yeni odanın sol sınırından bu kadar içeri girince kapı arkasından kapanır.
const ENTER_DEPTH := 130.0
## Odaya girdikten sonra ilk dalganın başlama gecikmesi (sn).
const ENTER_DELAY := 1.0
## Mevcut odadan bu kadar geride kalan odalar silinir.
const KEEP_BEHIND := 1
## Oyuncunun odanın sol sınırından başlama uzaklığı (kat başı ve kayıttan devam).
const START_OFFSET := 180.0
## Kat geçişi: kararma, kat kartı bekleme, açılma süreleri (sn).
const FADE_OUT_TIME := 0.8
const CARD_TIME := 1.4
const FADE_IN_TIME := 0.9
## Son Gölge yenildikten sonra zafer ekranı bu kadar sonra açılır (sn).
const VICTORY_DELAY := 2.5

enum Trans { NONE, OUT, HOLD, IN }

## 0 = her seferinde rastgele tohum.
@export var seed_value := 0
## Normal kip: katlar + lobi + Gölge. false: eski tek sonsuz şerit (testler).
@export var floors_enabled := true
## Kayıttan devam: kaydedilmiş koşunun anlık görüntüsü (RunSnapshot). Boşsa (ve GameState'te de bekleyen yoksa) yeni koşu.
var restore: Dictionary = {}

var run_seed := 0
## oda no -> Room
var rooms := {}
var current := -1
var stats := {"kills": 0, "rooms_cleared": 0, "best_combo": 0, "time": 0.0, "room": 1, "floor": 0}
var player: Player
## Bu koşuda karşılaşılan düşman türleri (sahne yolu -> true). Taurus ve Sagitta baştan tanıdıktır.
var seen_enemies := {SAGITTA.resource_path: true, TAURUS.resource_path: true}
## Şu anki lobinin dükkân rafı (lobide değilsen son lobinin rafı; kayda yalnız lobideyken yazılır).
var shop_stock: ShopStock = null
## Son katın Gölge'si yenildi.
var won := false
## Zafer ekranı açıldı.
var victory_shown := false
## Kat 1 öğretici rehberi (yalnız kat 1'de ve profilde öğretici bitmemişse; yoksa null).
var tutorial: TutorialGuide = null

var _trans: Trans = Trans.NONE
var _trans_t := 0.0
var _victory_t := -1.0
var _run_finished := false
## Kayıttan gelen raf (lobiye girilince bir kez kullanılır).
var _restored_shop: ShopStock = null

@onready var camera: ShakeCamera = $Camera
@onready var rooms_root: Node2D = $Rooms
@onready var enemies_root: Node2D = $Enemies
@onready var hud: Hud = $Hud


# ---------------------------------------------------------------- oda içeriği (saf fonksiyonlar)

## Savaş odasındaki dalga sayısı: ilk odalar tek dalga, sonra artar. `progress`: bu odadan önceki savaş odası sayısı.
static func wave_count_for(progress: int) -> int:
	if progress < 2:
		return 1
	if progress < 5:
		return 2
	return 3


## Bir dalgadaki düşman sayısı (ilerledikçe artar, 6'da durur).
static func enemies_in_wave(progress: int, wave_index: int) -> int:
	return clampi(2 + (progress + wave_index) / 2, 2, 6)


## Odanın tur ilerlemesi (EnemyScaling `n`). Katlı kipte: bu odadan önceki savaş odası sayısı (kat başına 4);
## kapalıyken oda numarasının kendisi.
static func progress_of(room_index: int, floors: bool = false) -> int:
	if floors:
		return int(FloorPlan.locate(room_index, true)["progress"])
	return maxi(room_index, 0)


## Bir dalgada kaç Scorpius olacağı. Zorlayıcı bir düşman: ilk kez 3. savaş odasının 2. dalgasında tek bir tane tanışır,
## sonra yavaşça artar; dalganın en fazla yarısı olabilir.
static func scorpius_in_wave(progress: int, wave_index: int, enemy_count: int) -> int:
	if progress < SCORPIUS_FIRST_ROOM:
		return 0
	if progress == SCORPIUS_FIRST_ROOM and wave_index == 0:
		return 0
	var n := 1 + (progress - SCORPIUS_FIRST_ROOM) / 4
	return clampi(n, 0, enemy_count / 2)


## Düşman sahnesinin duyuru adı: dosya adından ("scorpius.tscn" -> "SCORPIUS").
static func enemy_title(scene: PackedScene) -> String:
	return scene.resource_path.get_file().get_basename().to_upper()


## Katın Gölge odasındaki patron.
static func boss_scene_for(_floor_no: int) -> PackedScene:
	return TAURUS  # yer tutucu: Umbra sahnesi gelince burası değişir


## Gölge odasının dalgaları: tek dalga, tek patron.
static func boss_waves(floor_no: int) -> Array:
	return [[boss_scene_for(floor_no)]]


# ---------------------------------------------------------------- oda içeriği (koşuya bağlı)

## Oda numarasının yeri (FloorPlan.locate): kat, kat içi sıra, tür, tur ilerlemesi...
func loc_of(room_index: int) -> Dictionary:
	return FloorPlan.locate(room_index, floors_enabled)


func current_loc() -> Dictionary:
	return loc_of(maxi(current, 0))


func current_floor() -> int:
	return int(current_loc()["floor"])


## Oda `i`'nin tur ilerlemesi.
func progress_for(room_index: int) -> int:
	return int(loc_of(room_index)["progress"])


## Oda `i`'nin düşman ayarı: seçili zorluk seviyesi + odanın tur ilerlemesi.
func tuning_for(room_index: int) -> EnemyTuning:
	return EnemyScaling.tuning(GameState.difficulty, progress_for(room_index))


## Oda `i` için bağımsız rastgele akış: oda içeriği oyuncunun yaptıklarından etkilenmesin.
func rng_for(room_index: int, channel: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d/%d/%s" % [run_seed, room_index, channel])
	return r


## Oda `i`'nin yerleşimi. Katlı kipte lobi ve Gölge odasının yerleşimi sabit; savaş odalarında bir öncekiyle aynı olmaz.
func layout_for(room_index: int) -> String:
	if not floors_enabled:
		if room_index <= 0:
			return FIRST_LAYOUT
		return RoomLayouts.pick(rng_for(room_index, "layout"), layout_for(room_index - 1))
	var loc := loc_of(room_index)
	match int(loc["kind"]):
		FloorPlan.Kind.LOBBY:
			return RoomLayouts.LOBBY_ID
		FloorPlan.Kind.BOSS:
			return RoomLayouts.BOSS_ID
	if int(loc["floor"]) == 1 and int(loc["slot"]) == 1:
		return FIRST_LAYOUT
	var avoid := layout_for(room_index - 1) if int(loc["slot"]) > 1 else ""
	return RoomLayouts.pick(rng_for(room_index, "layout"), avoid)


## Oda `i`'nin dalgaları: her dalga bir PackedScene dizisi. Lobide dalga yok.
func make_waves(room_index: int) -> Array:
	var loc := loc_of(room_index)
	var kind := int(loc["kind"])
	if kind == FloorPlan.Kind.LOBBY:
		return []
	if kind == FloorPlan.Kind.BOSS:
		return boss_waves(int(loc["floor"]))
	if floors_enabled and Tutorial.applies(loc):
		return Tutorial.waves(int(loc["slot"]))  # kat 1: elle yazılmış müfredat (tek tek, yavaş)
	var n := int(loc["progress"])
	var r := rng_for(room_index, "waves")
	var waves: Array = []
	for w in wave_count_for(n):
		var count := enemies_in_wave(n, w)
		var flip := r.randi_range(0, 1)
		var wave: Array = []
		for k in count:
			wave.append(SAGITTA if (k + flip) % 2 == 0 else TAURUS)
		var scorpions := scorpius_in_wave(n, w, count)
		if scorpions > 0:
			var slots: Array = range(count)
			for i in range(slots.size() - 1, 0, -1):
				var j := r.randi_range(0, i)
				var tmp = slots[i]
				slots[i] = slots[j]
				slots[j] = tmp
			for i in scorpions:
				wave[slots[i]] = SCORPIUS
		waves.append(wave)
	if n == 0:
		waves[0] = [TAURUS, SAGITTA]  # ilk savaş odasında her aileden bir tane
	return waves


## Odanın sol kenarının dünya x'i: aynı kattaki önceki odaların genişliklerinin toplamı (odaları kurmadan hesaplanır).
func x_left_of(index: int) -> float:
	var first := int(loc_of(index)["first"]) if floors_enabled else 0
	var x := 0.0
	for k in range(first, index):
		x += RoomLayouts.width_of(layout_for(k))
	return x


## Odadan sonra aynı şeritte başka oda var mı? (Katın son odasından sonra yok: orada kat geçidi var.)
func has_next_room(index: int) -> bool:
	return not floors_enabled or not bool(loc_of(index)["last"])


# ---------------------------------------------------------------- kurulum

func _ready() -> void:
	Hitstop.reset()
	TimeStop.reset()
	if restore.is_empty():
		restore = GameState.take_resume()
	run_seed = seed_value if seed_value != 0 else int(Time.get_ticks_usec() & 0x7fffffff)
	var start := 0
	if not restore.is_empty():
		run_seed = SaveSlot._int(restore.get("seed", run_seed), run_seed)
		start = _restore_start(restore)
	player = get_tree().get_first_node_in_group("player") as Player
	if player == null:
		player = $Player as Player
	player.died.connect(_on_player_died)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.combo_ended.connect(_on_combo_ended)
	var has_prev := start > 0 and (not floors_enabled or int(loc_of(start)["slot"]) > 0)
	if has_prev:
		_build_room(start - 1)  # sol sınır: önceki odanın kapısı (kapanır)
	_build_room(start)
	if not restore.is_empty():
		_apply_restore(start)
	_enter_room(start, true)
	_setup_tutorial()


## Kat 1'de, profilde öğretici daha bitmediyse ekrandaki ipuçlarını başlatır.
func _setup_tutorial() -> void:
	if not floors_enabled or current_floor() != 1 or not Tutorial.hints_wanted(GameState.slot):
		return
	tutorial = TutorialGuide.new()
	tutorial.name = "Tutorial"
	add_child(tutorial)
	tutorial.setup(self, player, hud.tutorial_hint)


func _exit_tree() -> void:
	if EventBus.enemy_died.is_connected(_on_enemy_died):
		EventBus.enemy_died.disconnect(_on_enemy_died)
	if EventBus.combo_ended.is_connected(_on_combo_ended):
		EventBus.combo_ended.disconnect(_on_combo_ended)


## Odayı (yoksa) kurar. Odalar sıralı yan yana dizilir: oda i, oda i-1'in sağ kenarında başlar (kat başında x = 0).
func _build_room(index: int) -> Room:
	if rooms.has(index):
		return rooms[index]
	var loc := loc_of(index)
	var room := Room.new()
	rooms_root.add_child(room)
	room.tuning = tuning_for(index)
	if floors_enabled and Tutorial.applies(loc):
		room.wave_tunings = Tutorial.wave_tunings(int(loc["slot"]), room.tuning)
	var opts := {}
	if floors_enabled:
		var kind := int(loc["kind"])
		var f := int(loc["floor"])
		var lobby := kind == FloorPlan.Kind.LOBBY
		opts = {
			"kind": kind, "floor": f, "slot": int(loc["slot"]),
			"theme": FloorPlan.LOBBY_THEME if lobby else FloorPlan.theme_of(f),
			"palette": Room.LOBBY_PALETTE if lobby else Room.palette_for_floor(f),
			"left_wall": lobby,
			"exit": bool(loc["last"]) and not FloorPlan.is_final_floor(f),
			"seal": bool(loc["last"]),
		}
		if kind == FloorPlan.Kind.BOSS:
			room.spawn_meta = {"floor": f}
	room.build(index, x_left_of(index), layout_for(index), enemies_root, rng_for(index, "room"), make_waves(index), opts)
	room.cleared.connect(_on_room_cleared)
	room.wave_started.connect(_on_wave_started)
	if room.floor_exit != null:
		room.floor_exit.used.connect(_on_floor_exit_used)
	rooms[index] = room
	return room


func current_room() -> Room:
	return rooms.get(current) as Room


## Oyuncu `index`. odaya girdi: arkadaki kapı kapanır, kamera yeni odaya geçer, dalgalar başlar (lobide dükkân kurulur).
## `announce`: oda adı duyurulsun (kat geçişinde "KAT n" kartı zaten gösterildi).
func _enter_room(index: int, first: bool = false, announce: bool = true) -> void:
	var loc := loc_of(index)
	var prev := rooms.get(index - 1) as Room
	if prev != null and not (floors_enabled and int(loc["slot"]) == 0):
		prev.door.close(true)
	current = index
	var room := _build_room(index)
	camera.set_bounds(room.camera_rect(), first)
	if has_next_room(index):
		_build_room(index + 1)
	_free_old_rooms()
	stats["room"] = int(loc["number"]) if floors_enabled else index + 1
	stats["floor"] = int(loc["floor"]) if floors_enabled else 0
	_set_hud_room(room, 1, room.waves.size(), false)
	if room.kind == FloorPlan.Kind.LOBBY:
		_setup_shop(room)
		floor_changed.emit(room.floor_no)
		EventBus.floor_entered.emit(room.floor_no)
	if announce:
		_announce_room(room)
	room.begin_encounter(ENTER_DELAY)
	EventBus.room_entered.emit(index)
	room_changed.emit(index)
	save_checkpoint()


func _set_hud_room(room: Room, wave_now: int, wave_total: int, is_cleared: bool) -> void:
	if floors_enabled:
		hud.set_room(room.slot + 1, wave_now, wave_total, is_cleared, room.floor_no, room.kind)
	else:
		hud.set_room(room.index + 1, wave_now, wave_total, is_cleared)


func _announce_room(room: Room) -> void:
	if not floors_enabled:
		hud.announcer.push_runs([["ODA ", GameFont.WHITE], [str(room.index + 1), GameFont.YELLOW]], 64, 1.5)
		return
	match room.kind:
		FloorPlan.Kind.LOBBY:
			hud.announcer.push_runs([["KAT ", GameFont.WHITE], [str(room.floor_no), GameFont.YELLOW]], 64, 1.8)
		FloorPlan.Kind.BOSS:
			hud.announcer.push("GÖLGE", Color(0.78, 0.55, 1.0), 72, 2.0)
		_:
			hud.announcer.push_runs([["ODA ", GameFont.WHITE], [str(room.slot + 1), GameFont.YELLOW]], 64, 1.5)


func _free_old_rooms() -> void:
	for k in rooms.keys():
		if int(k) < current - KEEP_BEHIND:
			var old: Room = rooms[k]
			rooms.erase(k)
			if is_instance_valid(old):
				old.queue_free()


# ---------------------------------------------------------------- dükkân

## Lobiye tezgâhı koyar. Raf: kayıttan gelen varsa o, yoksa tohumdan üretilir (sahip olunan ve Umbra'ya kalan eşyalar çıkmaz).
func _setup_shop(room: Room) -> void:
	if room.shop != null:
		return
	var stock: ShopStock = null
	if _restored_shop != null and _restored_shop.size() > 0:
		stock = _restored_shop
	_restored_shop = null
	if stock == null:
		var owned: Array = player.inventory.owned_ids() if player != null and player.inventory != null else []
		stock = ShopStock.generate(rng_for(room.index, "shop"), room.floor_no, owned, GameState.umbra_ids())
	shop_stock = stock
	var stand := ShopStand.new()
	stand.name = "Shop"
	stand.position = Vector2(RoomLayouts.shop_x(room.layout_id), RoomLayouts.FLOOR_Y)
	stand.stock = stock
	room.add_child(stand)
	room.shop = stand
	stand.requested.connect(_on_shop_requested)


func _on_shop_requested(stand: ShopStand) -> void:
	if player == null or not is_instance_valid(player) or player.dead or _trans != Trans.NONE:
		return
	hud.shop_menu.open_shop(player, stand.stock, stand)


# ---------------------------------------------------------------- akış

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		restart()
		return
	_tick_transition(delta)
	_tick_victory(delta)
	if player == null or not is_instance_valid(player) or player.dead:
		return
	if not victory_shown:
		stats["time"] = float(stats["time"]) + delta
		if GameState.slot != null:
			GameState.slot.playtime += delta
	var room := current_room()
	var next := rooms.get(current + 1) as Room
	if _trans == Trans.NONE and room != null and next != null and room.is_cleared() and player.global_position.x > next.rect.position.x + ENTER_DEPTH:
		_enter_room(current + 1)


## Baştan başla (R). Koşu sürerken basılırsa terk edilmiş sayılır: sayaçlara işlenir, yarım koşu silinir.
func restart() -> void:
	if player != null and is_instance_valid(player) and not player.dead:
		_finish_run(false)
	Hitstop.reset()
	TimeStop.reset()
	get_tree().reload_current_scene()


func _on_wave_started(wave_number: int, wave_total: int) -> void:
	var room := current_room()
	if room == null:
		return
	_set_hud_room(room, wave_number, wave_total, false)
	if wave_number >= 2:
		hud.announcer.push_runs([["DALGA ", GameFont.WHITE], [str(wave_number), GameFont.YELLOW]], 44, 1.1)
	if room.kind != FloorPlan.Kind.BOSS:
		_announce_new_enemies(room.waves[wave_number - 1])


## Koşuda ilk kez karşılaşılan düşman türü duyurulur ("YENİ DÜŞMAN  SCORPIUS").
## İlk odanın düşmanları (Taurus, Sagitta) tanıdık sayılır: onlar için duyuru çıkmaz.
func _announce_new_enemies(wave: Array) -> void:
	for scene in wave:
		var key := (scene as PackedScene).resource_path
		if seen_enemies.has(key):
			continue
		seen_enemies[key] = true
		hud.announcer.push_runs([["YENİ DÜŞMAN  ", GameFont.WHITE], [enemy_title(scene), GameFont.YELLOW]], 46, 1.7)


func _on_room_cleared(room: Room) -> void:
	var next := rooms.get(room.index + 1) as Room
	if next != null:
		camera.extend_bounds(next.camera_rect())
	if floors_enabled and room.kind == FloorPlan.Kind.LOBBY:
		_set_hud_room(room, 1, 1, true)
		EventBus.room_cleared.emit(room.index)
		return
	stats["rooms_cleared"] = int(stats["rooms_cleared"]) + 1
	_set_hud_room(room, room.waves.size(), room.waves.size(), true)
	if room.kind == FloorPlan.Kind.BOSS:
		if FloorPlan.is_final_floor(room.floor_no):
			hud.announcer.push("GÖLGE YENİLDİ", GameFont.YELLOW, 64, 2.2)
			_begin_victory()
		else:
			hud.announcer.push_runs([["GÖLGE YENİLDİ", GameFont.YELLOW]], 58, 2.2)
	else:
		hud.announcer.push("ODA TEMİZ", GameFont.YELLOW, 58, 1.8)
	EventBus.room_cleared.emit(room.index)


func _on_enemy_died(_enemy: Node) -> void:
	stats["kills"] = int(stats["kills"]) + 1


func _on_combo_ended(hits: int, parries: int, _damage: int) -> void:
	stats["best_combo"] = maxi(int(stats["best_combo"]), hits + parries)


func _on_player_died() -> void:
	hud.set_summary(stats)
	_finish_run(true)


# ---------------------------------------------------------------- kat geçişi

func is_transitioning() -> bool:
	return _trans != Trans.NONE


## Kat geçidi kullanıldı: ekran kararır, yeni katın lobisi kurulur, "KAT n" kartı çıkar, ekran açılır.
## Başlatılamazsa (zaten geçişte, ölü, son kat) false.
func descend() -> bool:
	if _trans != Trans.NONE or player == null or not is_instance_valid(player) or player.dead:
		return false
	if FloorPlan.is_final_floor(current_floor()):
		return false
	var room := current_room()
	if room == null or room.floor_exit == null:
		return false  # yalnız kat geçidi olan odadan inilir
	_trans = Trans.OUT
	_trans_t = 0.0
	player.input_locked = true
	return true


func _on_floor_exit_used(_floor_exit: FloorExit) -> void:
	descend()


func _tick_transition(delta: float) -> void:
	if _trans == Trans.NONE:
		return
	_trans_t += delta
	match _trans:
		Trans.OUT:
			hud.set_fade(clampf(_trans_t / FADE_OUT_TIME, 0.0, 1.0))
			if _trans_t >= FADE_OUT_TIME:
				_go_next_floor()
				_trans = Trans.HOLD
				_trans_t = 0.0
		Trans.HOLD:
			hud.set_card("KAT %d" % current_floor(), "", clampf(_trans_t / 0.3, 0.0, 1.0))
			if _trans_t >= CARD_TIME:
				_trans = Trans.IN
				_trans_t = 0.0
		Trans.IN:
			hud.set_fade(1.0 - clampf(_trans_t / FADE_IN_TIME, 0.0, 1.0))
			hud.set_card("KAT %d" % current_floor(), "", 1.0 - clampf(_trans_t / (FADE_IN_TIME * 0.5), 0.0, 1.0))
			if _trans_t >= FADE_IN_TIME:
				hud.set_fade(0.0)
				hud.set_card("", "", 0.0)
				_trans = Trans.NONE
				if player != null and is_instance_valid(player) and not won:
					player.input_locked = false


## Eski katı siler, bir sonraki katın lobisini kurar ve oyuncuyu oraya koyar (kararmanın altında; geliştirme kısayolu da kullanır).
func _go_next_floor() -> void:
	var f := mini(current_floor() + 1, FloorPlan.FLOOR_COUNT)
	for k in rooms.keys():
		var old: Room = rooms[k]
		if is_instance_valid(old):
			old.queue_free()
	rooms.clear()
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.queue_free()
	get_tree().call_group("projectiles", "queue_free")
	shop_stock = null
	var index := FloorPlan.index_of(f, 0)
	var room := _build_room(index)
	player.global_position = Vector2(room.rect.position.x + START_OFFSET, 600.0)
	player.velocity = Vector2.ZERO
	_enter_room(index, true, false)


## Geliştirici kısayolu (F7): bir sonraki katın lobisine kararma olmadan geç.
func dev_next_floor() -> bool:
	if _trans != Trans.NONE or not floors_enabled or FloorPlan.is_final_floor(current_floor()):
		return false
	_go_next_floor()
	return true


# ---------------------------------------------------------------- zafer

func _begin_victory() -> void:
	if won:
		return
	won = true
	_victory_t = 0.0
	_finish_run(false, true)
	run_won.emit()


func _tick_victory(delta: float) -> void:
	if _victory_t < 0.0:
		return
	_victory_t += delta
	if _victory_t >= VICTORY_DELAY:
		_victory_t = -1.0
		show_victory()


## Zafer ekranını açar (gecikme beklenmeden de çağrılabilir: testler).
func show_victory() -> void:
	if victory_shown:
		return
	victory_shown = true
	hud.set_summary(stats)
	hud.set_victory(stats)
	if player != null and is_instance_valid(player):
		player.input_locked = true


# ---------------------------------------------------------------- kayıt

## Kayıt sürümü: 2 = katlı yapı. Sürümsüz ya da 1 (eski) kayıtlar tek sonsuz şeritteydi (`floors_enabled = false` koşular da 1 yazar).
const SAVE_VERSION := 2

## Koşunun anlık görüntüsü (kayıt için). Konum: odanın başı; devam edince oda baştan başlar.
func snapshot() -> Dictionary:
	var seen: Array = []
	for key in seen_enemies:
		seen.append(String(key).get_file().get_basename())
	var loc := current_loc()
	var d := {"v": SAVE_VERSION if floors_enabled else 1, "seed": run_seed, "floor": int(loc["floor"]), "room": int(loc["slot"]), "wave": 0, "seen": seen}
	d["player"] = RunSnapshot.capture_player(player)
	d.merge(RunSnapshot.capture_umbra())
	d["stats"] = RunSnapshot.capture_stats(stats)
	var room := current_room()
	if room != null and room.kind == FloorPlan.Kind.LOBBY and shop_stock != null:
		d["shop"] = shop_stock.to_array()
	return d


## Kayıt slotu açıksa (menüden başlandıysa) koşuyu yazar. Slot yoksa (test/geliştirme) hiçbir şey yapmaz.
func save_checkpoint() -> bool:
	var slot := GameState.slot
	if slot == null or GameState.mode != GameMode.Kind.NORMAL or player == null or player.dead or won:
		return false
	slot.set_run(GameMode.Kind.NORMAL, snapshot())
	slot.touch()
	return SaveStore.save_slot(slot)


## Kayıtlı koşunun başlayacağı oda numarası. Eski (sürümsüz) kayıt tek şeritteydi: aynı ilerleme için uygun katın lobisine alınır.
func _restore_start(data: Dictionary) -> int:
	var r := maxi(SaveSlot._int(data.get("room", 0)), 0)
	if not floors_enabled:
		return r
	if SaveSlot._int(data.get("v", 1), 1) < SAVE_VERSION:
		var guessed := clampi(r / FloorPlan.COMBAT_ROOMS + 1, 1, FloorPlan.FLOOR_COUNT)
		return FloorPlan.index_of(guessed, 0)
	var f := clampi(SaveSlot._int(data.get("floor", 1), 1), 1, FloorPlan.FLOOR_COUNT)
	return FloorPlan.index_of(f, r)


## Kayıttaki durumu oyuncuya, Umbra'ya, istatistiklere ve dükkâna işler.
func _apply_restore(start: int) -> void:
	var pl: Variant = restore.get("player")
	if pl is Dictionary:
		RunSnapshot.apply_player(player, pl as Dictionary)
	RunSnapshot.apply_umbra(restore)
	var st: Variant = restore.get("stats")
	if st is Dictionary:
		RunSnapshot.apply_stats(stats, st as Dictionary)
	var seen: Variant = restore.get("seen", [])
	if seen is Array:
		for n in seen:
			var path := "res://actors/enemies/%s.tscn" % str(n)
			if ResourceLoader.exists(path):
				seen_enemies[path] = true
	var shop: Variant = restore.get("shop")
	if shop is Array and SaveSlot._int(restore.get("v", 1), 1) >= SAVE_VERSION:
		_restored_shop = ShopStock.from_array(shop)
	if start > 0:
		var room := rooms[start] as Room
		player.global_position = Vector2(room.rect.position.x + START_OFFSET, 600.0)


## Koşu bitti (öldün, terk ettin ya da kazandın): rekorlar işlenir, yarım koşu silinir, slot yazılır. Bir koşu bir kez sayılır.
func _finish_run(died: bool, victory: bool = false) -> void:
	var slot := GameState.slot
	if slot == null or GameState.mode != GameMode.Kind.NORMAL or _run_finished:
		return
	_run_finished = true
	var loc := current_loc()
	slot.record_run(GameMode.Kind.NORMAL, {
		"kills": int(stats["kills"]), "best_combo": int(stats["best_combo"]), "floor": int(loc["floor"]), "room": int(loc["slot"]),
	}, died, victory)
	slot.touch()
	SaveStore.save_slot(slot)


## Ana menüye döner (duraklatma menüsü ve ölüm ekranı). Yarım koşu son oda başlangıcında kalır; süre yazılır.
func return_to_menu() -> void:
	_save_slot_time()
	SceneRouter.go_menu(get_tree())


## Oyundan çıkar (süre yazılır).
func quit_game() -> void:
	_save_slot_time()
	SceneRouter.quit(get_tree())


## Kayıt slotu açıksa oynama süresini ve son oynama tarihini yazar (yarım koşuya dokunmaz).
func _save_slot_time() -> void:
	var slot := GameState.slot
	if slot != null:
		slot.touch()
		SaveStore.save_slot(slot)


## Geliştirici kısayolları: F6 = odadaki herkesi öldür ve odayı temizle, F7 = bir sonraki kata geç (akışı hızlı denemek için).
## (F4 = deneme/god modu, F5 = eşya menüsü.) Ölüm ve zafer ekranında M = ana menü.
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_F6:
		skip_room()
	elif key.physical_keycode == KEY_F7:
		dev_next_floor()
	elif key.physical_keycode == KEY_M and player != null and is_instance_valid(player) and (player.dead or victory_shown):
		return_to_menu()


## Odayı hemen temizler (geliştirici kısayolu ve testler için).
func skip_room() -> void:
	var room := current_room()
	if room == null or room.is_cleared():
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		var a := e as ActorBase
		if a != null and not a.dead:
			a.die()
	room.force_clear()
