class_name Room
extends Node2D
## Tek bir oda: SAVAŞ odası, LOBİ (düşman yok, dükkân) ya da GÖLGE odası (patron). Kodla kurulur (zemin, tavan, duvarlar,
## platformlar, arka plan, sağ kapı). Oda dünyada soldan sağa dizilir: bir odanın sağ kapısı sonraki odanın sol sınırıdır.
## Katın son odasında sağ kapı hiç açılmaz; onun yerine KAT GEÇİDİ (FloorExit) vardır.
##
## Akış:  PENDING (oyuncu girmedi) -> ACTIVE (dalgalar sırayla doğar) -> CLEARED (kapı / kat geçidi açılır).
## Düşmanlar doğmadan önce SpawnMarker (ışık sütunu) çıkar. Son dalga bitince kapı açılır. Lobi girişte hemen CLEARED olur.

enum State { PENDING, ACTIVE, CLEARED }

signal wave_started(wave_number: int, wave_total: int)
signal cleared(room: Room)

const ROOMS_PER_PALETTE := 3
## Doğma noktaları oyuncudan en az bu kadar uzakta seçilir (yeterince nokta varsa).
const MIN_SPAWN_DISTANCE := 380.0
const NEXT_WAVE_DELAY := 1.0
## Gölge'nin doğuş süresi (uzun, gösterişli).
const BOSS_SPAWN_DELAY := 1.4
const CLEAR_DELAY := 0.5
const SPAWN_DELAY := 0.55
const WALL_THICKNESS := 80.0
## Kat geçidi sağ uçtan bu kadar içeride durur.
const EXIT_MARGIN := 170.0

## Her 3 odada bir renk teması değişir (kapıdan geçerken fark edilir).
const PALETTES := [
	{
		"wall": Color(0.075, 0.063, 0.094), "pillar": Color(0.095, 0.082, 0.118), "floor": Color(0.16, 0.135, 0.19),
		"edge": Color(0.95, 0.78, 0.3, 0.8), "platform": Color(0.22, 0.19, 0.27), "accent": Color(0.95, 0.78, 0.3),
	},
	{
		"wall": Color(0.05, 0.08, 0.09), "pillar": Color(0.07, 0.11, 0.12), "floor": Color(0.11, 0.17, 0.18),
		"edge": Color(0.35, 0.85, 0.8, 0.8), "platform": Color(0.14, 0.24, 0.25), "accent": Color(0.4, 0.9, 0.85),
	},
	{
		"wall": Color(0.095, 0.05, 0.06), "pillar": Color(0.125, 0.07, 0.08), "floor": Color(0.19, 0.11, 0.12),
		"edge": Color(0.95, 0.42, 0.35, 0.8), "platform": Color(0.27, 0.16, 0.17), "accent": Color(1.0, 0.5, 0.38),
	},
	{
		"wall": Color(0.055, 0.06, 0.115), "pillar": Color(0.075, 0.085, 0.15), "floor": Color(0.12, 0.13, 0.22),
		"edge": Color(0.55, 0.6, 1.0, 0.8), "platform": Color(0.17, 0.19, 0.32), "accent": Color(0.62, 0.68, 1.0),
	},
	# Tutulma (son katlar): simsiyah, beyaz-altın ışık.
	{
		"wall": Color(0.025, 0.025, 0.035), "pillar": Color(0.05, 0.05, 0.068), "floor": Color(0.09, 0.09, 0.105),
		"edge": Color(1.0, 0.94, 0.72, 0.85), "platform": Color(0.13, 0.13, 0.16), "accent": Color(1.0, 0.93, 0.7),
	},
]

## Lobi: sıcak, loş, güvenli.
const LOBBY_PALETTE := {
	"wall": Color(0.085, 0.062, 0.058), "pillar": Color(0.115, 0.085, 0.07), "floor": Color(0.2, 0.15, 0.115),
	"edge": Color(1.0, 0.72, 0.35, 0.8), "platform": Color(0.27, 0.2, 0.15), "accent": Color(1.0, 0.76, 0.38),
}
## Kat kat kayan ton: aynı temadaki katlar birbirinden hafifçe ayrılsın.
const HUE_STEP := 0.022

var index := 0
var layout_id := ""
var layout: Dictionary = {}
## Odanın türü (FloorPlan.Kind): savaş, lobi, Gölge. Kat/sıra/tema koşu denetleyicisinden gelir.
var kind: FloorPlan.Kind = FloorPlan.Kind.COMBAT
var floor_no := 1
var slot := 0
var theme_id := ""
## Katın son odası: sağ kapı kalıcı duvardır, kat geçidi vardır.
var has_exit := false
var floor_exit: FloorExit = null
## Lobideki dükkân tezgâhı (yoksa null).
var shop: ShopStand = null
## Odanın DÜNYA dikdörtgeni (x, 0, genişlik, 720).
var rect := Rect2()
var state: State = State.PENDING
## Sağ kapı (sonraki odaya geçiş).
var door: Door
var palette: Dictionary = {}
## Her dalga: PackedScene dizisi.
var waves: Array = []
var wave_number := 0

## Bu odada doğan düşmanların zorluk/tur ayarı (null = ayarsız).
var tuning: EnemyTuning = null
## Dalga başına ayar (kat 1 öğretici dersleri: tempo, yalnız altın/kırmızı). Boşsa ya da eksikse `tuning` geçerlidir.
var wave_tunings: Array = []
## Doğan düşmanlara `set_meta` ile verilecek bilgiler (Gölge odasında {"floor": kat}).
var spawn_meta: Dictionary = {}

var _enemies_root: Node
var _rng: RandomNumberGenerator
var _pending := 0
var _wait := 0.0


static func palette_for(room_index: int) -> Dictionary:
	return PALETTES[floori(float(room_index) / float(ROOMS_PER_PALETTE)) % PALETTES.size()]


## Katın paleti: tema her 4 katta değişir, temanın içinde her kat tonu azıcık kayar.
static func palette_for_floor(floor_no: int) -> Dictionary:
	var f := maxi(floor_no, 1) - 1
	var base: Dictionary = PALETTES[mini(f / FloorPlan.FLOORS_PER_THEME, PALETTES.size() - 1)]
	var shift := float(f % FloorPlan.FLOORS_PER_THEME) * HUE_STEP
	if is_zero_approx(shift):
		return base
	var out := {}
	for k in base:
		var c: Color = base[k]
		out[k] = Color.from_hsv(fposmod(c.h + shift, 1.0), c.s, c.v, c.a)
	return out


## Odayı kurar. Odanın ağaca eklenmiş olması gerekir.
## `opts` (hepsi isteğe bağlı): kind (FloorPlan.Kind), floor, slot, theme, palette, left_wall (bool), exit (bool: kat geçidi var),
## seal (bool: sağ kapı hiç açılmaz; son katın Gölge odası gibi).
func build(room_index: int, x_left: float, layout_name: String, enemies_parent: Node, rng: RandomNumberGenerator, wave_list: Array, opts: Dictionary = {}) -> void:
	index = room_index
	layout_id = layout_name
	layout = RoomLayouts.get_layout(layout_name)
	_enemies_root = enemies_parent
	_rng = rng
	waves = wave_list
	kind = int(opts.get("kind", FloorPlan.Kind.COMBAT)) as FloorPlan.Kind
	floor_no = int(opts.get("floor", 1))
	slot = int(opts.get("slot", room_index))
	theme_id = String(opts.get("theme", ""))
	has_exit = bool(opts.get("exit", false))
	palette = opts.get("palette", palette_for(room_index))
	var left_wall := bool(opts.get("left_wall", room_index == 0))
	var width := RoomLayouts.width_of(layout_name)
	position = Vector2(x_left, 0.0)
	rect = Rect2(x_left, 0.0, width, RoomLayouts.HEIGHT)
	name = "Room%d" % index
	_build_background(width)
	_build_solids(width, left_wall)
	_build_platforms()
	door = Door.new()
	door.name = "Door"
	door.position = Vector2(width, 0.0)
	door.accent = palette["accent"]
	var sealed := has_exit or bool(opts.get("seal", false))
	door.permanent = sealed
	if sealed:
		door.look = Door.Look.SEALED
	add_child(door)
	if has_exit:
		floor_exit = FloorExit.new()
		floor_exit.name = "FloorExit"
		floor_exit.position = Vector2(width - EXIT_MARGIN, RoomLayouts.FLOOR_Y)
		floor_exit.next_floor = floor_no + 1
		floor_exit.accent = palette["accent"]
		add_child(floor_exit)
	if kind == FloorPlan.Kind.LOBBY:
		var decor := LobbyDecor.new()
		decor.name = "Decor"
		decor.width = width
		decor.accent = palette["accent"]
		add_child(decor)


func _build_background(width: float) -> void:
	var bg := Node2D.new()
	bg.name = "Background"
	bg.z_index = -10
	add_child(bg)
	_add_rect(bg, Rect2(0.0, 0.0, width, RoomLayouts.CAMERA_HEIGHT), palette["wall"])
	# Sütunlar: oda başına hafif kaydırılmış, böylece her oda biraz farklı görünür.
	var shift := float(_rng.randi_range(0, 120)) if _rng != null else 0.0
	var x := 150.0 + shift
	while x < width - 120.0:
		_add_rect(bg, Rect2(x, 0.0, 40.0, RoomLayouts.FLOOR_Y), palette["pillar"])
		x += 470.0
	# Zemin: kamera aşağıyı da gösterebilsin diye derinliğe uzanır, aşağı doğru kararır.
	var floor_color: Color = palette["floor"]
	var depth := RoomLayouts.CAMERA_HEIGHT - RoomLayouts.FLOOR_Y
	_add_rect(self, Rect2(0.0, RoomLayouts.FLOOR_Y, width, depth), floor_color)
	_add_rect(self, Rect2(0.0, RoomLayouts.FLOOR_Y + 70.0, width, depth - 70.0), floor_color.darkened(0.3))
	_add_rect(self, Rect2(0.0, RoomLayouts.FLOOR_Y + 150.0, width, depth - 150.0), floor_color.darkened(0.55))
	_add_rect(self, Rect2(0.0, RoomLayouts.FLOOR_Y, width, 4.0), palette["edge"])


func _build_solids(width: float, left_wall: bool) -> void:
	var body := StaticBody2D.new()
	body.name = "World"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	add_child(body)
	# Zemin: komşu odalarla birleşsin diye 4 px taşar.
	_add_shape(body, Vector2(width * 0.5, RoomLayouts.FLOOR_Y + 50.0), Vector2(width + 8.0, 100.0))
	# Tavan
	_add_shape(body, Vector2(width * 0.5, -WALL_THICKNESS * 0.5), Vector2(width + 8.0, WALL_THICKNESS))
	# Katın ilk odasının sol duvarı (diğer odalarda sol sınır, öncekinin kapısıdır)
	if left_wall:
		_add_shape(body, Vector2(-WALL_THICKNESS * 0.5, 360.0), Vector2(WALL_THICKNESS, 1400.0))


func _build_platforms() -> void:
	var body := StaticBody2D.new()
	body.name = "Platforms"
	body.collision_layer = Layers.PLATFORM
	body.collision_mask = 0
	add_child(body)
	for r in RoomLayouts.platform_rects(layout_id):
		var cs := _add_shape(body, r.position + r.size * 0.5, r.size)
		cs.one_way_collision = true
		cs.add_to_group("platforms")
		_add_rect(self, r, palette["platform"])
		_add_rect(self, Rect2(r.position, Vector2(r.size.x, 3.0)), (palette["platform"] as Color).lightened(0.25))


func _add_shape(body: StaticBody2D, center: Vector2, size: Vector2) -> CollisionShape2D:
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = size
	cs.shape = rs
	cs.position = center
	body.add_child(cs)
	return cs


func _add_rect(parent: Node, r: Rect2, color: Color) -> ColorRect:
	var cr := ColorRect.new()
	cr.position = r.position
	cr.size = r.size
	cr.color = color
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(cr)
	return cr


# ---------------------------------------------------------------- savaş akışı

## Oyuncu odaya girdi: kapı kilitli, dalgalar `delay` sn sonra başlar. Lobide düşman yok: oda hemen temizlenmiş sayılır.
func begin_encounter(delay: float = 1.0) -> void:
	if kind == FloorPlan.Kind.LOBBY:
		force_clear()
		return
	state = State.ACTIVE
	_wait = delay
	if not door.permanent:
		door.look = Door.Look.LOCKED


func is_cleared() -> bool:
	return state == State.CLEARED


## Kameranın bu odada görebileceği dünya dikdörtgeni (zeminin altı da dahil).
func camera_rect() -> Rect2:
	return Rect2(rect.position.x, 0.0, rect.size.x, RoomLayouts.CAMERA_HEIGHT)


func alive_count() -> int:
	return get_tree().get_nodes_in_group("enemies").size()


## Henüz doğmamış (işaret bekleyen) düşman sayısı.
func pending_count() -> int:
	return _pending


func _process(delta: float) -> void:
	if state != State.ACTIVE or TimeStop.active:
		return
	_kill_stragglers()
	if _pending > 0 or alive_count() > 0:
		return
	_wait -= delta
	if _wait > 0.0:
		return
	if wave_number < waves.size():
		_start_wave()
	else:
		force_clear()


## Dünyadan düşen düşman odayı kilitli bırakmasın.
func _kill_stragglers() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		var n := e as ActorBase
		if n != null and not n.dead and n.global_position.y > 1500.0:
			n.die()


## `i`. dalganın (0'dan) düşman ayarı.
func tuning_for_wave(i: int) -> EnemyTuning:
	if i >= 0 and i < wave_tunings.size() and wave_tunings[i] is EnemyTuning:
		return wave_tunings[i]
	return tuning


func _start_wave() -> void:
	var wave: Array = waves[wave_number]
	wave_number += 1
	var points := _pick_spawn_points(wave.size())
	var wave_tuning := tuning_for_wave(wave_number - 1)
	for i in wave.size():
		_pending += 1
		var m := SpawnMarker.spawn(self, points[i], wave[i], _enemies_root, SPAWN_DELAY + 0.12 * float(i))
		m.tuning = wave_tuning
		m.meta = spawn_meta
		if kind == FloorPlan.Kind.BOSS:
			m.color = Color(0.7, 0.45, 1.0)
			m.duration = BOSS_SPAWN_DELAY
		m.finished.connect(_on_marker_finished)
	_wait = NEXT_WAVE_DELAY if wave_number < waves.size() else CLEAR_DELAY
	wave_started.emit(wave_number, waves.size())


func _on_marker_finished(_enemy: Node) -> void:
	_pending = maxi(_pending - 1, 0)


## Doğma noktalarını (dünya koordinatı) seçer: oyuncudan uzak olanlar tercih edilir, sıra rastgele.
func _pick_spawn_points(count: int) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	for s in RoomLayouts.spawn_points(layout_id):
		pts.append(to_global(s))
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		var far: Array[Vector2] = []
		for p in pts:
			if absf(p.x - player.global_position.x) >= MIN_SPAWN_DISTANCE:
				far.append(p)
		if far.size() >= mini(count, 3):
			pts = far
	for i in range(pts.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i) if _rng != null else 0
		var tmp := pts[i]
		pts[i] = pts[j]
		pts[j] = tmp
	var out: Array[Vector2] = []
	for i in count:
		var lap := floori(float(i) / float(pts.size()))
		out.append(pts[i % pts.size()] + Vector2(56.0 * float(lap), 0.0))
	return out


## Odayı hemen temizlenmiş sayar: kapı açılır. (Normalde son dalga bitince kendiliğinden olur.)
func force_clear() -> void:
	if state == State.CLEARED:
		return
	state = State.CLEARED
	door.open()
	if floor_exit != null:
		floor_exit.open_up()
	get_tree().call_group("projectiles", "queue_free")
	cleared.emit(self)
