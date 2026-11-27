class_name Npc
extends Node2D
## Konuşulabilen karakter. Yaklaşınca "E KONUŞ" çıkar; E'ye basınca `requested` sinyali gelir, koşu denetleyicisi
## konuşma kutusunu açar. Orijin = ayak noktası. Çizim: `npc_<id>_idle` (yoksa yer tutucu siluet).

signal requested(npc: Npc)

const RANGE_X := 130.0
const RANGE_Y := 170.0

var npc_id := ""
var display_name := ""
var tint := Color(0.5, 0.7, 1.0)
var in_range := false

var _t := 0.0
var _player: Player


func _ready() -> void:
	z_index = -1
	add_to_group("npcs")
	add_to_group(Interact.GROUP)
	_hook_player()


func _exit_tree() -> void:
	if _player != null and is_instance_valid(_player) and _player.interacted.is_connected(_on_interacted):
		_player.interacted.disconnect(_on_interacted)


func _hook_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player != null and not _player.interacted.is_connected(_on_interacted):
		_player.interacted.connect(_on_interacted)


func can_interact() -> bool:
	return true


func _on_interacted() -> void:
	if in_range and ItemView.active_menu == null and _player != null and not _player.dead and Interact.is_best(self):
		requested.emit(self)


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
	var breathe := 1.5 * sin(_t * 1.8)
	if not Art.draw(self, "npc_%s_idle" % npc_id, Rect2(-64.0, -128.0, 128.0, 128.0), _t):
		var body := PackedVector2Array([Vector2(-26, 0), Vector2(26, 0), Vector2(18, -84 + breathe), Vector2(0, -108 + breathe), Vector2(-18, -84 + breathe)])
		draw_colored_polygon(body, tint.darkened(0.55))
		draw_polyline(body + PackedVector2Array([body[0]]), tint, 2.0)
		draw_circle(Vector2(0, -98 + breathe), 14.0, tint.darkened(0.7))
		draw_circle(Vector2(-5, -100 + breathe), 2.0, tint.lightened(0.4))
		draw_circle(Vector2(5, -100 + breathe), 2.0, tint.lightened(0.4))
	GameFont.draw_centered(self, display_name, Vector2(0.0, -146.0), 20, Color(1, 1, 1, 0.75))
	if in_range and Interact.is_best(self):
		var pulse := 0.7 + 0.3 * sin(_t * 6.0)
		GameFont.draw_runs_centered(self, [["E", GameFont.YELLOW], ["  KONUŞ", GameFont.WHITE]], Vector2(0.0, -172.0), 22, pulse)
