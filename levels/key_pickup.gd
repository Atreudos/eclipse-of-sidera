class_name KeyPickup
extends Node2D
## Anahtar: yaklaşınca alınır (`taken`). Orijin = anahtarın altı. Çizim: `key_item` (yoksa yer tutucu).

signal taken

const RADIUS := 60.0

var _t := 0.0
var _got := false
var _player: Player


func _ready() -> void:
	add_to_group("keys")


func _process(delta: float) -> void:
	_t += delta
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	elif not _got and not _player.dead and _player.global_position.distance_to(global_position + Vector2(0.0, -30.0)) <= RADIUS:
		_got = true
		Sfx.play("pickup", -2.0, 1.3)
		taken.emit()
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var bob := 6.0 * sin(_t * 3.0)
	if Art.draw(self, "key_item", Rect2(-24.0, -64.0 + bob, 48.0, 48.0), _t):
		return
	var c := Color(1.0, 0.85, 0.3)
	var o := Vector2(0.0, -44.0 + bob)
	draw_arc(o + Vector2(0, -8), 9.0, 0.0, TAU, 16, c, 3.0)
	draw_line(o + Vector2(0, 1), o + Vector2(0, 20), c, 3.0)
	draw_line(o + Vector2(0, 14), o + Vector2(8, 14), c, 3.0)
	draw_line(o + Vector2(0, 20), o + Vector2(7, 20), c, 3.0)
	draw_circle(o, 38.0, Color(c, 0.07 + 0.05 * sin(_t * 4.0)))
