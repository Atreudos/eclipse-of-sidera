class_name HitSpark
extends Node2D
## Vuruş kıvılcımı: vuruş yönünde yayılan kısa çizgiler + merkezde beyaz parlama. Kendini temizler.
## Süre oyun zamanına bağlıdır: hitstop sırasında kıvılcım da donar (vuruş anı net görünür).

var color := Color.WHITE
var dir := Vector2.RIGHT
var size := 1.0
var duration := 0.2

var _t := 0.0
var _rays: Array[Dictionary] = []


static func spawn(parent: Node, pos: Vector2, direction: Vector2, spark_color: Color = Color.WHITE, spark_size: float = 1.0) -> void:
	if parent == null:
		return
	var fx := HitSpark.new()
	fx.color = spark_color
	fx.dir = direction.normalized() if direction.length() > 0.01 else Vector2.RIGHT
	fx.size = spark_size
	fx.z_index = 25
	parent.add_child(fx)
	fx.global_position = pos


func _ready() -> void:
	var base := dir.angle()
	for i in 8:
		_rays.append({
			"angle": base + randf_range(-0.95, 0.95),
			"length": randf_range(34.0, 72.0) * size,
			"start": randf_range(4.0, 10.0) * size,
			"width": randf_range(3.0, 6.0),
		})


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := clampf(_t / duration, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - k, 3.0)
	for r in _rays:
		var v := Vector2.from_angle(r["angle"])
		var a: float = r["start"] + float(r["length"]) * eased * 0.45
		var b: float = r["start"] + float(r["length"]) * eased
		draw_line(v * a, v * b, Color(color, 1.0 - k), lerpf(float(r["width"]), 1.0, k))
	draw_circle(Vector2.ZERO, lerpf(20.0, 0.0, eased) * size, Color(1, 1, 1, 0.9 * (1.0 - k)))
