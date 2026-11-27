class_name FloodEvent
extends Node2D
## Kat sonu olayı: su odanın dibinden yavaşça yükselir; sağ uçtaki basamaklardan en üste (kat geçidine) tırmanmalısın.
## Su en üst platformun altında durur, yani tepe hep güvenlidir (sıkışma yok). Sudaysan yavaş yavaş can kaybedersin.
## Oda düğümünün çocuğu olarak eklenir; yerel koordinat = oda koordinatı. Çizim: yer tutucu (`flood_water` çizimi gelirse kullanılır).

const RISE_SPEED := 20.0
const WATER_STOP_Y := 340.0
const HURT_EVERY := 1.4
const STEP_RISE := 85.0
const STEPS := 4

var room: Room
var water_y := RoomLayouts.FLOOR_Y + 10.0
var running := false

var _t := 0.0
var _hurt := 3.0  # suya ilk girişte can kaybından önce 3 sn tolerans
var _player: Player


## Basamakları kurar, geçidi tepeye taşır, suyu başlatır.
func start(r: Room) -> void:
	room = r
	z_index = 4
	var w := r.rect.size.x
	var fy := RoomLayouts.FLOOR_Y
	var body := StaticBody2D.new()
	body.name = "FloodSteps"
	body.collision_layer = Layers.PLATFORM
	body.collision_mask = 0
	add_child(body)
	var top_x := w - 220.0
	for i in STEPS:
		var surf := fy - STEP_RISE * float(i + 1)
		var px := top_x - 230.0 * float(STEPS - 1 - i)
		var rect := Rect2(px - 90.0, surf, 180.0 if i < STEPS - 1 else 260.0, 22.0)
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = rect.size
		cs.shape = rs
		cs.position = rect.get_center()
		cs.one_way_collision = true
		cs.add_to_group("platforms")
		body.add_child(cs)
		var vis := ColorRect.new()
		vis.position = rect.position
		vis.size = rect.size
		vis.color = (r.palette["platform"] as Color).lightened(0.1)
		vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(vis)
	if r.floor_exit != null:
		r.floor_exit.position = Vector2(top_x, fy - STEP_RISE * float(STEPS))
		r.floor_exit.pit = true
	running = true
	Sfx.play("door_open", -3.0, 0.6)


func _physics_process(delta: float) -> void:
	if not running:
		return
	_t += delta
	water_y = maxf(water_y - RISE_SPEED * delta, WATER_STOP_Y)
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
		return
	_hurt = maxf(_hurt - delta, 0.0)
	var feet := to_local(Vector2(_player.global_position.x, _player.feet_y())).y
	if not _player.dead and feet > water_y + 4.0 and _hurt <= 0.0:
		_hurt = HURT_EVERY
		_player.take_damage(1, null)
		Sfx.play("hit", -8.0, 0.6)


func _process(_delta: float) -> void:
	if running:
		queue_redraw()


func _draw() -> void:
	if room == null:
		return
	var w := room.rect.size.x
	var h := RoomLayouts.CAMERA_HEIGHT - water_y
	var wave := 4.0 * sin(_t * 2.0)
	draw_rect(Rect2(0.0, water_y, w, h), Color(0.2, 0.5, 0.75, 0.45))
	draw_rect(Rect2(0.0, water_y + wave, w, 4.0), Color(0.7, 0.9, 1.0, 0.7))
