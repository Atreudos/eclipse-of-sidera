class_name EndlessRun
extends RunController
## SINIRSIZ kip: tek geniş arena, bitmeyen dalgalar. Her dalgada düşman sayısı ve gücü artar (güç `EnemyScaling`, `n = dalga - 1`).
## 5., 10., 25., 50., 75. ve 100. dalgalar BİTİNCE arenanın ortasında dükkân açılır; hazır olunca arenanın sağ ucundaki
## ışık sütununa yürüyerek sonraki dalga başlatılır. Diğer dalgalar arasında kısa bir ara vardır.
## Koşu `RunController`'ın oyuncu/HUD/kayıt altyapısını kullanır; kat ve oda yoktur: arena tek bir `Room`, dalgalar o odaya sırayla eklenir.
## Aynı tohum = aynı dalgalar. Her dalganın başında koşu kaydedilir (menüden "devam"), dükkân arasında raf da kaydedilir.

## Dükkân açılan dalgalar (bu dalga BİTİNCE).
const SHOP_WAVES: Array[int] = [5, 10, 25, 50, 75, 100]
## Scorpius ilk kez bu dalgada görünür.
const SCORPIUS_FIRST_WAVE := 4
## Her bu kadar dalgada bir (3, 6, 9...) dalga bitince 1 can yenilenir.
const HEAL_EVERY := 3
## Dalgalar arası bekleme (sn) ve dükkândan sonraki bekleme.
const WAVE_GAP := 2.2
const AFTER_SHOP_GAP := 1.5
## Dalga kapısı (sağ uç): bu kadar içeride durur, oyuncu bu x'ten ileri geçince dalga başlar.
const GATE_MARGIN := 260.0

var arena: Room = null
## Başlamış son dalganın numarası (0 = henüz yok).
var wave := 0
## Dükkân arasında mı (dalga kapısı bekleniyor).
var breaking := false

var _gate: EndlessGate = null


func _init() -> void:
	floors_enabled = false


# ---------------------------------------------------------------- dalga matematiği (saf fonksiyonlar)

## `w`. dalgadaki toplam düşman: 1 -> 3, 10 -> 10, 25 -> 18, 50 -> 29, 100 -> 50.
static func wave_size(w: int) -> int:
	return int(2.5 + 1.2 * pow(float(maxi(w, 1)), 0.8))


## Aynı anda ekranda bulunabilecek en çok düşman (dalga parçalara bölünür): 4'ten başlar, 10'a çıkar.
static func alive_cap(w: int) -> int:
	return clampi(4 + maxi(w, 1) / 6, 4, 10)


## Dalgadaki Scorpius sayısı: 4. dalgada 1, sonra her 3 dalgada +1; dalganın en çok %40'ı.
static func scorpius_count(w: int, total: int) -> int:
	if w < SCORPIUS_FIRST_WAVE:
		return 0
	return clampi(1 + (w - SCORPIUS_FIRST_WAVE) / 3, 1, maxi(total * 2 / 5, 1))


static func is_shop_wave(w: int) -> bool:
	return SHOP_WAVES.has(w)


## Dükkân rafının "kat"ı: ilerledikçe daha değerli eşyalar (1 .. 18). Efsanevi eşya yine dükkâna girmez.
static func shop_floor(w: int) -> int:
	return clampi(1 + (maxi(w, 1) - 1) / 4, 1, FloorPlan.FLOOR_COUNT)


## Yeni düşmanların (Aries, Cancer...) açılması için dalganın karşılık geldiği "kat": 1 + dalga / 3 (1 .. 18).
static func roster_floor(w: int) -> int:
	return clampi(1 + maxi(w, 1) / 3, 1, FloorPlan.FLOOR_COUNT)


## `w`. dalganın düşman listesi (karışık sırada).
static func compose(w: int, rng: RandomNumberGenerator) -> Array:
	var total := wave_size(w)
	var scorpions := scorpius_count(w, total)
	var flip := rng.randi_range(0, 1)
	var list: Array = []
	for k in total:
		if k < scorpions:
			list.append(SCORPIUS)
		else:
			list.append(SAGITTA if (k + flip) % 2 == 0 else TAURUS)
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = list[i]
		list[i] = list[j]
		list[j] = tmp
	EnemyRoster.apply(list, roster_floor(w), rng, false)
	if w == 1:
		list = [TAURUS, SAGITTA, TAURUS]
	return list


## Dalgayı `alive_cap` sınırını aşmayan, eşit büyüklükte parçalara böler (her parça bir "alt dalga").
static func batches(w: int, rng: RandomNumberGenerator) -> Array:
	var list := compose(w, rng)
	var cap := alive_cap(w)
	var parts := int(ceil(float(list.size()) / float(cap)))
	var chunk := int(ceil(float(list.size()) / float(parts)))
	var out: Array = []
	var i := 0
	while i < list.size():
		out.append(list.slice(i, mini(i + chunk, list.size())))
		i += chunk
	return out


# ---------------------------------------------------------------- kurulum

func _ready() -> void:
	Hitstop.reset()
	TimeStop.reset()
	if restore.is_empty():
		restore = GameState.take_resume()
	run_seed = seed_value if seed_value != 0 else int(Time.get_ticks_usec() & 0x7fffffff)
	if not restore.is_empty():
		run_seed = SaveSlot._int(restore.get("seed", run_seed), run_seed)
	player = get_tree().get_first_node_in_group("player") as Player
	if player == null:
		player = $Player as Player
	player.died.connect(_on_player_died)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.combo_ended.connect(_on_combo_ended)
	_build_arena()
	var resume_wave := 1
	var resume_shop: Variant = null
	if not restore.is_empty():
		resume_wave = maxi(SaveSlot._int(restore.get("wave", 1), 1), 1)
		resume_shop = restore.get("shop")
		_apply_endless_restore()
	wave = resume_wave - 1
	if resume_shop is Array and wave >= 1:
		var stock := ShopStock.from_array(resume_shop)
		if stock != null and stock.size() > 0:
			player.global_position = Vector2(arena.rect.position.x + RoomLayouts.shop_x(RoomLayouts.ARENA_ID) - 160.0, 600.0)
			_begin_break(stock)
			return
	_launch_wave(wave + 1, ENTER_DELAY)


func _build_arena() -> void:
	var room := Room.new()
	rooms_root.add_child(room)
	var opts := {
		"kind": FloorPlan.Kind.COMBAT, "floor": 1, "slot": 0, "theme": FloorPlan.theme_of(1),
		"palette": Room.palette_for_floor(1), "left_wall": true, "exit": false, "seal": true,
	}
	room.build(0, 0.0, RoomLayouts.ARENA_ID, enemies_root, rng_for(0, "room"), [], opts)
	room.cleared.connect(_on_room_cleared)
	room.wave_started.connect(_on_wave_started)
	arena = room
	rooms[0] = room
	current = 0
	camera.set_bounds(room.camera_rect(), true)


func _apply_endless_restore() -> void:
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


# ---------------------------------------------------------------- dalga akışı

## `w`. dalgayı başlatır (`delay` sn sonra ilk düşmanlar doğar).
func _launch_wave(w: int, delay: float) -> void:
	wave = w
	stats["wave"] = w
	stats["room"] = w
	stats["floor"] = 0
	arena.waves.append_array(batches(w, rng_for(w, "waves")))
	arena.tuning = EnemyScaling.tuning(GameState.difficulty, w - 1)
	arena.state = Room.State.PENDING
	arena.begin_encounter(delay)
	hud.wave = w
	hud.announcer.push_runs([["DALGA ", GameFont.WHITE], [str(w), GameFont.YELLOW]], 56, 1.5)
	EventBus.room_entered.emit(w)
	room_changed.emit(w)
	save_checkpoint()


func _on_wave_started(wave_number: int, _wave_total: int) -> void:
	if arena == null or wave_number < 1 or wave_number > arena.waves.size():
		return
	_announce_new_enemies(arena.waves[wave_number - 1])


## Dalganın tüm parçaları bitti.
func _on_room_cleared(_room: Room) -> void:
	stats["rooms_cleared"] = int(stats["rooms_cleared"]) + 1
	EventBus.room_cleared.emit(wave)
	if player == null or not is_instance_valid(player) or player.dead:
		return
	if wave % HEAL_EVERY == 0 and player.heal(1) > 0:
		hud.announcer.push_runs([["+1 CAN", Color(1.0, 0.45, 0.5)]], 36, 1.4)
	if is_shop_wave(wave):
		_begin_break(null)
	else:
		hud.announcer.push("DALGA TEMİZ", GameFont.YELLOW, 46, 1.2)
		_launch_wave(wave + 1, WAVE_GAP)


# ---------------------------------------------------------------- dükkân arası

## Arenanın ortasında dükkân açılır, sağ uçta dalga kapısı belirir. `stock`: kayıttan gelen raf (yoksa tohumdan üretilir).
func _begin_break(stock: ShopStock) -> void:
	breaking = true
	var loadout: WeaponLoadout = player.loadout if player != null else null
	var floor_no := shop_floor(wave)
	if stock == null:
		var owned: Array = player.inventory.owned_ids() if player != null and player.inventory != null else []
		stock = ShopStock.generate(rng_for(wave, "shop"), floor_no, owned, GameState.umbra_ids(), loadout)
	else:
		stock.add_weapon_offers(loadout, floor_no)
	shop_stock = stock
	var stand := ShopStand.new()
	stand.name = "Shop"
	stand.position = Vector2(RoomLayouts.shop_x(RoomLayouts.ARENA_ID), RoomLayouts.FLOOR_Y)
	stand.stock = stock
	arena.add_child(stand)
	arena.shop = stand
	stand.requested.connect(_on_shop_requested)
	_gate = EndlessGate.new()
	_gate.name = "WaveGate"
	_gate.position = Vector2(gate_x(), RoomLayouts.FLOOR_Y)
	_gate.accent = arena.palette["accent"]
	arena.add_child(_gate)
	hud.wave = wave
	hud.announcer.push("DÜKKÂN", GameFont.YELLOW, 58, 2.0)
	hud.announcer.push_runs([["HAZIR OLUNCA SAĞ UÇTAKİ IŞIĞA YÜRÜ", GameFont.WHITE]], 28, 2.8)
	save_checkpoint()


## Dalga kapısının arena-yerel x'i.
func gate_x() -> float:
	return RoomLayouts.width_of(RoomLayouts.ARENA_ID) - GATE_MARGIN


## Dükkân arası bitti: dükkân ve kapı kalkar, sonraki dalga başlar.
func end_break() -> void:
	if not breaking:
		return
	breaking = false
	if arena.shop != null and is_instance_valid(arena.shop):
		arena.shop.queue_free()
	arena.shop = null
	shop_stock = null
	if _gate != null and is_instance_valid(_gate):
		_gate.queue_free()
	_gate = null
	_launch_wave(wave + 1, AFTER_SHOP_GAP)


func _process(delta: float) -> void:
	super._process(delta)
	if breaking and player != null and is_instance_valid(player) and not player.dead and ItemView.active_menu == null:
		if player.global_position.x >= arena.rect.position.x + gate_x():
			end_break()


# ---------------------------------------------------------------- kayıt

func snapshot() -> Dictionary:
	var seen: Array = []
	for key in seen_enemies:
		seen.append(String(key).get_file().get_basename())
	# Dalga kaydı: savaşta o dalga baştan oynanır; dükkân arasında bir sonraki dalga + raf.
	var d := {"v": SAVE_VERSION, "seed": run_seed, "floor": 0, "room": 0, "wave": (wave + 1 if breaking else maxi(wave, 1)), "seen": seen}
	d["player"] = RunSnapshot.capture_player(player)
	d.merge(RunSnapshot.capture_umbra())
	d["stats"] = RunSnapshot.capture_stats(stats)
	if breaking and shop_stock != null:
		d["shop"] = shop_stock.to_array()
	return d


func save_checkpoint() -> bool:
	var slot := GameState.slot
	if slot == null or GameState.mode != GameMode.Kind.ENDLESS or player == null or player.dead:
		return false
	slot.set_run(GameMode.Kind.ENDLESS, snapshot())
	slot.touch()
	return SaveStore.save_slot(slot)


func _finish_run(died: bool, victory: bool = false) -> void:
	var slot := GameState.slot
	if slot == null or GameState.mode != GameMode.Kind.ENDLESS or _run_finished:
		return
	_run_finished = true
	slot.record_run(GameMode.Kind.ENDLESS, {
		"kills": int(stats["kills"]), "best_combo": int(stats["best_combo"]), "wave": maxi(wave, 1),
	}, died, victory)
	slot.touch()
	SaveStore.save_slot(slot)


## Geliştirici kısayolları: F6 = dalgayı hemen bitir, F7 yok (kat yok).
func dev_next_floor() -> bool:
	return false


## Dalga kapısı: sağ uçta duran, nabız gibi atan ışık sütunu.
class EndlessGate extends Node2D:
	var accent := Color(1.0, 0.8, 0.4)
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var pulse := 0.55 + 0.25 * sin(_t * 3.0)
		var c := Color(accent.r, accent.g, accent.b, 0.16 * pulse)
		draw_rect(Rect2(-60.0, -520.0, 120.0, 520.0), c)
		draw_rect(Rect2(-20.0, -520.0, 40.0, 520.0), Color(accent.r, accent.g, accent.b, 0.32 * pulse))
		draw_rect(Rect2(-60.0, -4.0, 120.0, 4.0), Color(accent.r, accent.g, accent.b, 0.9))
