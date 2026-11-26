class_name SideDoor
extends Node2D
## Ara oda kapısı: yaklaşıp E'ye basınca `used` sinyali gelir (koşu denetleyicisi ekranı karartıp oyuncuyu taşır).
## Lobide "ARA ODA", ara odada "ÇIK" yazar. Orijin = zemindeki orta nokta. Çizim: `side_door` (yoksa yer tutucu kemer).

signal used(door: SideDoor)

const RANGE_X := 90.0
const RANGE_Y := 170.0

var label := "ARA ODA"
var accent := Color(0.95, 0.78, 0.3)
var in_range := false

var _t := 0.0
var _player: Player


func _ready() -> void:
	z_index = -3
	add_to_group("side_doors")
	_hook_player()


func _exit_tree() -> void:
	if _player != null and is_instance_valid(_player) and _player.interacted.is_connected(_on_interacted):
		_player.interacted.disconnect(_on_interacted)


func _hook_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player != null and not _player.interacted.is_connected(_on_interacted):
		_player.interacted.connect(_on_interacted)


func _on_interacted() -> void:
	if in_range and ItemView.active_menu == null and _player != null and not _player.dead:
		used.emit(self)


func _process(delta: float) -> void:
	_t += delta
	if _player == null or not is_instance_valid(_player):
		_hook_player()
	in_range = false
	if _player != null and is_instance_valid(_player) and not _player.dead:
		var d := _player.global_position - global_position
		in_range = absf(d.x) <= RANGE_X and absf(d.y) <= RANGE_Y
	queue_redraw()


func _draw() -> void:
	if not Art.draw(self, "side_door", Rect2(-64.0, -192.0, 128.0, 192.0), _t):
		var glow := 0.5 + 0.5 * sin(_t * 2.2)
		var dark := Color(0.02, 0.015, 0.03)
		draw_rect(Rect2(-46.0, -150.0, 92.0, 150.0), dark)
		draw_circle(Vector2(0.0, -150.0), 46.0, dark)
		draw_rect(Rect2(-46.0, -150.0, 92.0, 150.0), accent.darkened(0.2), false, 3.0)
		draw_arc(Vector2(0.0, -150.0), 46.0, PI, TAU, 24, accent.darkened(0.2), 3.0)
		draw_rect(Rect2(-40.0, -144.0, 80.0, 144.0), Color(accent, 0.05 + 0.07 * glow))
	if label != "":
		GameFont.draw_centered(self, label, Vector2(0.0, -218.0), 20, Color(1, 1, 1, 0.8))
	if in_range:
		var pulse := 0.7 + 0.3 * sin(_t * 6.0)
		GameFont.draw_runs_centered(self, [["E", GameFont.YELLOW], ["  ÇIK" if label == "ÇIK" else "  GİR", GameFont.WHITE]], Vector2(0.0, -244.0), 22, pulse)
