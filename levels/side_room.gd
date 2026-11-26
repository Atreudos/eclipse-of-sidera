class_name SideRoom
extends Node2D
## Ara oda: lobiden girilen küçük, güvenli oda. Bir konuşulabilir karakter, 2-3 sandık ve çıkış kapısı. Düşman yok.
## Dünyada başka odaların çok uzağında (solda) kurulur; koşu denetleyicisi oyuncuyu kararma altında taşır.

const WIDTH := 1300.0
const KEY_WIDTH := 2300.0
const WALL := 80.0
const DOOR_X := 150.0
const NPC_X := 560.0

var floor_no := 1
var rect := Rect2()
var palette: Dictionary = {}
var npc: Npc = null
var return_door: SideDoor = null
var kind := "npc"
var width := WIDTH
var key_taken := false
var key_item: KeyPickup = null
var chests: Array[Chest] = []


## `x_left`: odanın sol kenarı (dünya). `rng`: sandık türleri için.
func build(x_left: float, floor_n: int, npc_id: String, rng: RandomNumberGenerator, kind_name: String = "npc") -> void:
	floor_no = floor_n
	kind = kind_name
	width = KEY_WIDTH if kind == "key" else WIDTH
	name = "SideRoom%d" % floor_n
	position = Vector2(x_left, 0.0)
	rect = Rect2(x_left, 0.0, width, RoomLayouts.HEIGHT)
	palette = Room.palette_for_floor(floor_n)
	_build_background()
	_build_solids()
	var decor := LobbyDecor.new()
	decor.name = "Decor"
	decor.width = width
	decor.accent = palette["accent"]
	add_child(decor)
	return_door = SideDoor.new()
	return_door.name = "ReturnDoor"
	return_door.label = "ÇIK"
	return_door.accent = palette["accent"]
	return_door.position = Vector2(DOOR_X, RoomLayouts.FLOOR_Y)
	add_child(return_door)
	if npc_id != "":
		npc = Npc.new()
		npc.name = "Npc_" + npc_id
		npc.npc_id = npc_id
		npc.display_name = NpcTalk.display_name(npc_id)
		npc.tint = NpcTalk.tint(npc_id)
		npc.position = Vector2(NPC_X, RoomLayouts.FLOOR_Y)
		add_child(npc)
	match kind:
		"key":
			_build_key_parkour()
		"treasure":
			_build_treasure(rng)


## Anahtar parkuru: basamaklar, fırlatıcı, sonda anahtar. Düşersen zemine inersin (ölüm yok), tekrar denersin.
func _build_key_parkour() -> void:
	var fy := RoomLayouts.FLOOR_Y
	var plats := [Vector2(420, 550), Vector2(700, 460), Vector2(980, 370), Vector2(1470, 330), Vector2(1800, 330), Vector2(2060, 250)]
	var widths := [180.0, 160.0, 160.0, 200.0, 140.0, 160.0]
	var body := StaticBody2D.new()
	body.name = "Platforms"
	body.collision_layer = Layers.PLATFORM
	body.collision_mask = 0
	add_child(body)
	for i in plats.size():
		var r := Rect2(plats[i].x - widths[i] * 0.5, plats[i].y, widths[i], 22.0)
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = r.size
		cs.shape = rs
		cs.position = r.get_center()
		cs.one_way_collision = true
		cs.add_to_group("platforms")
		body.add_child(cs)
		_rect(self, r, palette["platform"])
		_rect(self, Rect2(r.position, Vector2(r.size.x, 3.0)), (palette["platform"] as Color).lightened(0.25))
	var l := Launcher.new()
	l.name = "Launcher"
	l.position = Vector2(1290.0, fy)
	add_child(l)
	key_item = KeyPickup.new()
	key_item.name = "Key"
	key_item.position = Vector2(plats[5].x, plats[5].y)
	add_child(key_item)
	key_item.taken.connect(func(): key_taken = true)


## Hazine odası: iki sandık, bir eşya.
func _build_treasure(rng: RandomNumberGenerator) -> void:
	var kinds := ["rich", "gold"]
	for i in 2:
		var c := Chest.new()
		c.name = "Chest_sec%d" % i
		c.kind = kinds[i]
		c.floor_no = floor_no
		c.chest_id = "sec_f%d_%d_%d" % [floor_no, int(rng.randi() % 100000), i]
		c.seed_value = rng.randi() % 1000000 + 1
		c.position = Vector2(500.0 + 320.0 * float(i), RoomLayouts.FLOOR_Y)
		add_child(c)
		chests.append(c)


func camera_rect() -> Rect2:
	return Rect2(rect.position.x, 0.0, rect.size.x, RoomLayouts.CAMERA_HEIGHT)


## Oyuncunun girişte duracağı nokta (dünya).
func entry_pos() -> Vector2:
	return Vector2(rect.position.x + DOOR_X + 90.0, 600.0)


## Dönüşte oyuncunun konacağı nokta: kapının önü.
func door_pos() -> Vector2:
	return to_global(Vector2(DOOR_X, RoomLayouts.FLOOR_Y))


func _build_background() -> void:
	var bg := Node2D.new()
	bg.name = "Background"
	bg.z_index = -10
	add_child(bg)
	_rect(bg, Rect2(0.0, 0.0, width, RoomLayouts.CAMERA_HEIGHT), palette["wall"])
	var x := 260.0
	while x < width - 120.0:
		_rect(bg, Rect2(x, 0.0, 40.0, RoomLayouts.FLOOR_Y), palette["pillar"])
		x += 380.0
	var fc: Color = palette["floor"]
	var depth := RoomLayouts.CAMERA_HEIGHT - RoomLayouts.FLOOR_Y
	_rect(self, Rect2(0.0, RoomLayouts.FLOOR_Y, width, depth), fc)
	_rect(self, Rect2(0.0, RoomLayouts.FLOOR_Y + 70.0, width, depth - 70.0), fc.darkened(0.3))
	_rect(self, Rect2(0.0, RoomLayouts.FLOOR_Y + 150.0, width, depth - 150.0), fc.darkened(0.55))
	_rect(self, Rect2(0.0, RoomLayouts.FLOOR_Y, width, 4.0), palette["edge"])


func _build_solids() -> void:
	var body := StaticBody2D.new()
	body.name = "World"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	add_child(body)
	_shape(body, Vector2(width * 0.5, RoomLayouts.FLOOR_Y + 50.0), Vector2(width + 8.0, 100.0))
	_shape(body, Vector2(width * 0.5, -WALL * 0.5), Vector2(width + 8.0, WALL))
	_shape(body, Vector2(-WALL * 0.5, 360.0), Vector2(WALL, 1400.0))
	_shape(body, Vector2(width + WALL * 0.5, 360.0), Vector2(WALL, 1400.0))


func _shape(body: StaticBody2D, center: Vector2, size: Vector2) -> void:
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = size
	cs.shape = rs
	cs.position = center
	body.add_child(cs)


func _rect(parent: Node, r: Rect2, color: Color) -> void:
	var cr := ColorRect.new()
	cr.position = r.position
	cr.size = r.size
	cr.color = color
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(cr)
