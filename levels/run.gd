class_name RunController
extends Node2D
## Koşu (run): odalar SAĞA doğru soldan sağa dizilir.
##
## Akış:  oda 0'da başla -> düşmanları temizle (dalgalar sırayla doğar) -> kapı açılır ->
##        sağa yürü -> yeni odanın içine ~130 px girince kapı arkandan kapanır -> yeni oda başlar.
## Oda içeriği (yerleşim, dalgalar) sadece (tohum, oda no)'ya bağlıdır: aynı tohum = aynı koşu.
## Kamera sınırları: yalnızca bulunduğun oda; oda temizlenince sağdaki oda da eklenir, geçince eskisi çıkar.

signal room_changed(index: int)

const SAGITTA := preload("res://actors/enemies/sagitta.tscn")
const TAURUS := preload("res://actors/enemies/taurus.tscn")
const SCORPIUS := preload("res://actors/enemies/scorpius.tscn")

## Scorpius ilk kez bu odada (0'dan sayılır) görünür: 3. oda, 2. dalga.
const SCORPIUS_FIRST_ROOM := 2

## İlk oda: test arenasına benzer (iki platform), oyuncu alışsın.
const FIRST_LAYOUT := "iki_kule"
## Oyuncu yeni odanın sol sınırından bu kadar içeri girince kapı arkasından kapanır.
const ENTER_DEPTH := 130.0
## Odaya girdikten sonra ilk dalganın başlama gecikmesi (sn).
const ENTER_DELAY := 1.0
## Mevcut odadan bu kadar geride kalan odalar silinir.
const KEEP_BEHIND := 1

## 0 = her seferinde rastgele tohum.
@export var seed_value := 0

var run_seed := 0
## oda no -> Room
var rooms := {}
var current := -1
var stats := {"kills": 0, "rooms_cleared": 0, "best_combo": 0, "time": 0.0, "room": 1}
var player: Player
## Bu koşuda karşılaşılan düşman türleri (sahne yolu -> true). Taurus ve Sagitta baştan tanıdıktır.
var seen_enemies := {SAGITTA.resource_path: true, TAURUS.resource_path: true}

@onready var camera: ShakeCamera = $Camera
@onready var rooms_root: Node2D = $Rooms
@onready var enemies_root: Node2D = $Enemies
@onready var hud: Hud = $Hud


# ---------------------------------------------------------------- oda içeriği (saf fonksiyonlar)

## Odadaki dalga sayısı: ilk odalar tek dalga, sonra artar.
static func wave_count_for(room_index: int) -> int:
	if room_index < 2:
		return 1
	if room_index < 5:
		return 2
	return 3


## Bir dalgadaki düşman sayısı (oda ve dalga ilerledikçe artar, 6'da durur).
static func enemies_in_wave(room_index: int, wave_index: int) -> int:
	return clampi(2 + (room_index + wave_index) / 2, 2, 6)


## Odanın tur ilerlemesi (EnemyScaling `n`): şimdilik oda numarası. Katlar gelince kat başına oda sayısını da hesaba katacak.
static func progress_of(room_index: int) -> int:
	return maxi(room_index, 0)


## Oda `i`'nin düşman ayarı: seçili zorluk seviyesi + odanın tur ilerlemesi.
func tuning_for(room_index: int) -> EnemyTuning:
	return EnemyScaling.tuning(GameState.difficulty, progress_of(room_index))


## Oda `i` için bağımsız rastgele akış: oda içeriği oyuncunun yaptıklarından etkilenmesin.
func rng_for(room_index: int, channel: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d/%d/%s" % [run_seed, room_index, channel])
	return r


## Oda `i`'nin yerleşimi. Bir öncekiyle aynı olmaz; ilk oda sabittir.
func layout_for(room_index: int) -> String:
	if room_index <= 0:
		return FIRST_LAYOUT
	return RoomLayouts.pick(rng_for(room_index, "layout"), layout_for(room_index - 1))


## Bir dalgada kaç Scorpius olacağı. Zorlayıcı bir düşman: 3. odanın 2. dalgasında tek bir tane tanışır,
## sonra yavaşça artar; dalganın en fazla yarısı olabilir.
static func scorpius_in_wave(room_index: int, wave_index: int, enemy_count: int) -> int:
	if room_index < SCORPIUS_FIRST_ROOM:
		return 0
	if room_index == SCORPIUS_FIRST_ROOM and wave_index == 0:
		return 0
	var n := 1 + (room_index - SCORPIUS_FIRST_ROOM) / 4
	return clampi(n, 0, enemy_count / 2)


## Düşman sahnesinin duyuru adı: dosya adından ("scorpius.tscn" -> "SCORPIUS").
static func enemy_title(scene: PackedScene) -> String:
	return scene.resource_path.get_file().get_basename().to_upper()


## Oda `i`'nin dalgaları: her dalga bir PackedScene dizisi.
func make_waves(room_index: int) -> Array:
	var r := rng_for(room_index, "waves")
	var waves: Array = []
	for w in wave_count_for(room_index):
		var count := enemies_in_wave(room_index, w)
		var flip := r.randi_range(0, 1)
		var wave: Array = []
		for k in count:
			wave.append(SAGITTA if (k + flip) % 2 == 0 else TAURUS)
		var scorpions := scorpius_in_wave(room_index, w, count)
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
	if room_index == 0:
		waves[0] = [TAURUS, SAGITTA]  # ilk odada her aileden bir tane
	return waves


# ---------------------------------------------------------------- kurulum

func _ready() -> void:
	Hitstop.reset()
	TimeStop.reset()
	run_seed = seed_value if seed_value != 0 else int(Time.get_ticks_usec() & 0x7fffffff)
	player = get_tree().get_first_node_in_group("player") as Player
	if player == null:
		player = $Player as Player
	player.died.connect(_on_player_died)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.combo_ended.connect(_on_combo_ended)
	_build_room(0)
	_enter_room(0, true)


func _exit_tree() -> void:
	if EventBus.enemy_died.is_connected(_on_enemy_died):
		EventBus.enemy_died.disconnect(_on_enemy_died)
	if EventBus.combo_ended.is_connected(_on_combo_ended):
		EventBus.combo_ended.disconnect(_on_combo_ended)


## Odayı (yoksa) kurar. Odalar sıralı kurulur: oda i, oda i-1'in sağ kenarında başlar.
func _build_room(index: int) -> Room:
	if rooms.has(index):
		return rooms[index]
	var x_left := 0.0
	if index > 0:
		var prev: Room = _build_room(index - 1)
		x_left = prev.rect.end.x
	var room := Room.new()
	rooms_root.add_child(room)
	room.tuning = tuning_for(index)
	room.build(index, x_left, layout_for(index), enemies_root, rng_for(index, "room"), make_waves(index))
	room.cleared.connect(_on_room_cleared)
	room.wave_started.connect(_on_wave_started)
	rooms[index] = room
	return room


func current_room() -> Room:
	return rooms.get(current) as Room


## Oyuncu `index`. odaya girdi: arkadaki kapı kapanır, kamera yeni odaya geçer, dalgalar başlar.
func _enter_room(index: int, first: bool = false) -> void:
	var prev := rooms.get(index - 1) as Room
	if prev != null:
		prev.door.close(true)
	current = index
	var room := _build_room(index)
	camera.set_bounds(room.camera_rect(), first)
	room.begin_encounter(ENTER_DELAY)
	_build_room(index + 1)
	_free_old_rooms()
	stats["room"] = index + 1
	hud.set_room(index + 1, 1, room.waves.size())
	hud.announcer.push_runs([["ODA ", GameFont.WHITE], [str(index + 1), GameFont.YELLOW]], 64, 1.5)
	EventBus.room_entered.emit(index)
	room_changed.emit(index)


func _free_old_rooms() -> void:
	for k in rooms.keys():
		if int(k) < current - KEEP_BEHIND:
			var old: Room = rooms[k]
			rooms.erase(k)
			if is_instance_valid(old):
				old.queue_free()


# ---------------------------------------------------------------- akış

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		restart()
		return
	if player == null or not is_instance_valid(player) or player.dead:
		return
	stats["time"] = float(stats["time"]) + delta
	var room := current_room()
	var next := rooms.get(current + 1) as Room
	if room != null and next != null and room.is_cleared() and player.global_position.x > next.rect.position.x + ENTER_DEPTH:
		_enter_room(current + 1)


func restart() -> void:
	Hitstop.reset()
	TimeStop.reset()
	get_tree().reload_current_scene()


func _on_wave_started(wave_number: int, wave_total: int) -> void:
	var room := current_room()
	if room == null:
		return
	hud.set_room(room.index + 1, wave_number, wave_total)
	if wave_number >= 2:
		hud.announcer.push_runs([["DALGA ", GameFont.WHITE], [str(wave_number), GameFont.YELLOW]], 44, 1.1)
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
	stats["rooms_cleared"] = int(stats["rooms_cleared"]) + 1
	hud.set_room(room.index + 1, room.waves.size(), room.waves.size(), true)
	hud.announcer.push("ODA TEMİZ", GameFont.YELLOW, 58, 1.8)
	var next := rooms.get(room.index + 1) as Room
	if next != null:
		camera.extend_bounds(next.camera_rect())
	EventBus.room_cleared.emit(room.index)


func _on_enemy_died(_enemy: Node) -> void:
	stats["kills"] = int(stats["kills"]) + 1


func _on_combo_ended(hits: int, parries: int, _damage: int) -> void:
	stats["best_combo"] = maxi(int(stats["best_combo"]), hits + parries)


func _on_player_died() -> void:
	hud.set_summary(stats)


## Geliştirici kısayolu: F6 = odadaki herkesi öldür ve odayı temizle (akışı hızlı denemek için).
## (F4 = deneme/god modu, F5 = eşya menüsü.)
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_F6:
		skip_room()


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
