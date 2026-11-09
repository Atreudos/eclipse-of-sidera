class_name UmbraMark
extends Node2D
## Gölge'nin yere koyduğu uyarı işareti. Süre dolunca `fired` sinyali verir (Gölge o anda bıçağı düşürür / belirir),
## sonra `linger` kadar daha görünür kalır ve kendini siler.
##   LINE: gökten düşecek bıçağın dikey çizgisi (Bıçak Yağmuru).  RING: Gölge adımının çıkacağı yerde daralan halka.
## Sahibi (Gölge) ölürse ya da silinirse işaret de kaybolur; zaman durunca işaret de durur.

signal fired

enum Look { LINE, RING }

var look := Look.LINE
var duration := 0.8
var linger := 0.0
var color := Color(1.0, 0.3, 0.3)
var height := 700.0
var owner_boss: Node = null

var _t := 0.0
var _fired := false


## `pos`: işaretin zemindeki noktası (dünya). LINE'da çizgi bu noktadan `h` px yukarı uzanır.
static func spawn(parent: Node, pos: Vector2, kind: Look, time: float, col: Color, boss: Node = null, h: float = 700.0, extra_visible: float = 0.0) -> UmbraMark:
	var m := UmbraMark.new()
	m.look = kind
	m.duration = maxf(time, 0.05)
	m.linger = maxf(extra_visible, 0.0)
	m.color = col
	m.owner_boss = boss
	m.height = h
	m.z_index = 8
	parent.add_child(m)
	m.global_position = pos
	return m


func _process(delta: float) -> void:
	if owner_boss != null:
		var gone := not is_instance_valid(owner_boss)
		if not gone and owner_boss is ActorBase and (owner_boss as ActorBase).dead:
			gone = true
		if gone:
			queue_free()
			return
	if TimeStop.active:
		return
	_t += delta
	if not _fired and _t >= duration:
		_fired = true
		fired.emit()
	if _t >= duration + linger:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := clampf(_t / duration, 0.0, 1.0)
	match look:
		Look.LINE:
			var a := 0.14 + 0.5 * k * k
			if _fired:
				a = 0.7
			draw_line(Vector2(0.0, -height), Vector2.ZERO, Color(color, a), lerpf(2.0, 7.0, k))
			draw_arc(Vector2.ZERO, lerpf(28.0, 13.0, k), 0.0, TAU, 24, Color(color, 0.4 + 0.5 * k), 3.0)
			draw_line(Vector2(-20.0, 0.0), Vector2(20.0, 0.0), Color(color, 0.5 + 0.4 * k), 3.0)
		Look.RING:
			var r := lerpf(64.0, 22.0, k)
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(color, 0.3 + 0.6 * k), 4.0)
			draw_arc(Vector2.ZERO, r * 0.55, 0.0, TAU, 24, Color(color, 0.2 + 0.5 * k), 2.0)
			draw_line(Vector2(-r * 1.3, 0.0), Vector2(r * 1.3, 0.0), Color(color, 0.4 + 0.5 * k), 3.0)
