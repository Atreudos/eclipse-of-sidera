class_name SideRoom
extends Node2D
## Ara oda: lobiden girilen küçük, güvenli oda. Bir konuşulabilir karakter, 2-3 sandık ve çıkış kapısı. Düşman yok.
## Dünyada başka odaların çok uzağında (solda) kurulur; koşu denetleyicisi oyuncuyu kararma altında taşır.

const WIDTH := 1300.0
const WALL := 80.0
const DOOR_X := 150.0
const NPC_X := 560.0
const CHEST_XS := [820.0, 1000.0, 1170.0]

var floor_no := 1
var rect := Rect2()
var palette: Dictionary = {}
var npc: Npc = null
var return_door: SideDoor = null
var chests: Array[Chest] = []
## Bulmaca odasıysa mantık ve kilitli ödül sandığı (değilse null).
var logic: PuzzleLogic = null
var reward_chest: Chest = null

signal puzzle_solved
signal shard_found(total: int)


## `x_left`: odanın sol kenarı (dünya). `rng`: sandık türleri için.
func build(x_left: float, floor_n: int, npc_id: String, rng: RandomNumberGenerator, puzzle: bool = false) -> void:
	floor_no = floor_n
	name = "SideRoom%d" % floor_n
	position = Vector2(x_left, 0.0)
	rect = Rect2(x_left, 0.0, WIDTH, RoomLayouts.HEIGHT)
	palette = Room.palette_for_floor(floor_n)
	_build_background()
	_build_solids()
	var decor := LobbyDecor.new()
	decor.name = "Decor"
	decor.width = WIDTH
	decor.accent = palette["accent"]
	add_child(decor)
	return_door = SideDoor.new()
	return_door.name = "ReturnDoor"
	return_door.label = "ÇIK"
	return_door.target = "back"
	return_door.accent = palette["accent"]
	return_door.position = Vector2(DOOR_X, RoomLayouts.FLOOR_Y)
	add_child(return_door)
	if puzzle:
		_build_puzzle(rng)
		return
	if npc_id != "":
		npc = Npc.new()
		npc.name = "Npc_" + npc_id
		npc.npc_id = npc_id
		npc.display_name = NpcTalk.display_name(npc_id)
		npc.tint = NpcTalk.tint(npc_id)
		npc.position = Vector2(NPC_X, RoomLayouts.FLOOR_Y)
		add_child(npc)
	var count := 2 + (1 if rng.randf() < 0.55 else 0)
	var kinds: Array[String] = ["gold", "heal" if rng.randf() < 0.4 else "item"]
	if count == 3:
		kinds.append("rich")
	var first_x := 0 if count == 3 else 1
	for i in count:
		var c := Chest.new()
		c.name = "Chest%d" % i
		c.kind = kinds[i]
		c.floor_no = floor_n
		c.chest_id = "pocket_f%d_%d" % [floor_n, i]
		c.seed_value = rng.randi() % 1000000 + 1
		c.position = Vector2(float(CHEST_XS[first_x + i]), RoomLayouts.FLOOR_Y)
		add_child(c)
		chests.append(c)


## Bulmaca odası: bulmaca parçaları + kilitli ödül sandığı.
func _build_puzzle(rng: RandomNumberGenerator) -> void:
	var spec := PuzzleLogic.spec_for(floor_no)
	logic = PuzzleLogic.new()
	add_child(logic)
	logic.build(spec, rng)
	reward_chest = Chest.new()
	reward_chest.name = "RewardChest"
	reward_chest.kind = "rich"
	reward_chest.locked = true
	reward_chest.floor_no = floor_no
	reward_chest.chest_id = "puzzle_f%d" % floor_no
	reward_chest.seed_value = rng.randi() % 1000000 + 1
	reward_chest.position = Vector2(PuzzleLogic.chest_x(spec), RoomLayouts.FLOOR_Y)
	add_child(reward_chest)
	chests.append(reward_chest)
	if Chest.opened_ids.has(reward_chest.chest_id):
		reward_chest.locked = false  # bu koşuda zaten çözüldü ve alındı
	logic.solved.connect(_on_puzzle_solved)


func _on_puzzle_solved() -> void:
	if reward_chest != null and is_instance_valid(reward_chest):
		reward_chest.locked = false
	puzzle_solved.emit()
	var key := "shard_f%d" % floor_no
	if not Story.has(key):
		Story.set_flag(key)
		var total := Story.add("shards")
		shard_found.emit(total)


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
	_rect(bg, Rect2(0.0, 0.0, WIDTH, RoomLayouts.CAMERA_HEIGHT), palette["wall"])
	var x := 260.0
	while x < WIDTH - 120.0:
		_rect(bg, Rect2(x, 0.0, 40.0, RoomLayouts.FLOOR_Y), palette["pillar"])
		x += 380.0
	var fc: Color = palette["floor"]
	var depth := RoomLayouts.CAMERA_HEIGHT - RoomLayouts.FLOOR_Y
	_rect(self, Rect2(0.0, RoomLayouts.FLOOR_Y, WIDTH, depth), fc)
	_rect(self, Rect2(0.0, RoomLayouts.FLOOR_Y + 70.0, WIDTH, depth - 70.0), fc.darkened(0.3))
	_rect(self, Rect2(0.0, RoomLayouts.FLOOR_Y + 150.0, WIDTH, depth - 150.0), fc.darkened(0.55))
	_rect(self, Rect2(0.0, RoomLayouts.FLOOR_Y, WIDTH, 4.0), palette["edge"])


func _build_solids() -> void:
	var body := StaticBody2D.new()
	body.name = "World"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	add_child(body)
	_shape(body, Vector2(WIDTH * 0.5, RoomLayouts.FLOOR_Y + 50.0), Vector2(WIDTH + 8.0, 100.0))
	_shape(body, Vector2(WIDTH * 0.5, -WALL * 0.5), Vector2(WIDTH + 8.0, WALL))
	_shape(body, Vector2(-WALL * 0.5, 360.0), Vector2(WALL, 1400.0))
	_shape(body, Vector2(WIDTH + WALL * 0.5, 360.0), Vector2(WALL, 1400.0))


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
