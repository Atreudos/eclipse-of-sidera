class_name RingFx
extends Node2D
## Genişleyen halka efekti (parry, dash, vuruş). Kendini temizler.

var color := Color.WHITE
var radius_from := 10.0
var radius_to := 60.0
var duration := 0.25
var _t := 0.0


static func spawn(parent: Node, pos: Vector2, ring_color: Color, from_r: float, to_r: float, time: float) -> void:
	if parent == null:
		return
	var fx := RingFx.new()
	fx.color = ring_color
	fx.radius_from = from_r
	fx.radius_to = to_r
	fx.duration = time
	fx.z_index = 20
	parent.add_child(fx)
	fx.global_position = pos


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := clampf(_t / duration, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - k, 3.0)
	var r := lerpf(radius_from, radius_to, eased)
	var c := Color(color, color.a * (1.0 - k))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, c, lerpf(6.0, 1.5, k))
