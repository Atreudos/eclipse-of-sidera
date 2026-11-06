class_name LobbyDecor
extends Node2D
## Lobinin süsü: mum direkleri ve asılı bayraklar. Koddan çizilir (yer tutucu): sıcak, loş, güvenli bir oda hissi.
## Odanın sol üstü orijin; zemin yüzeyi y = RoomLayouts.FLOOR_Y.

## Mum direklerinin ve bayrakların oda genişliğine oranla yerleri.
const CANDLES := [0.14, 0.4, 0.72, 0.93]
const BANNERS := [0.27, 0.57, 0.86]

var width := 1500.0
var accent := Color(1.0, 0.76, 0.38)

var _t := 0.0


func _ready() -> void:
	z_index = -6


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	for f in BANNERS:
		_banner(width * float(f))
	for i in CANDLES.size():
		_candle(width * float(CANDLES[i]), float(i) * 1.7)


func _banner(x: float) -> void:
	var cloth := Color(0.3, 0.09, 0.1)
	var pts := PackedVector2Array([Vector2(x - 34.0, 0.0), Vector2(x + 34.0, 0.0), Vector2(x + 34.0, 190.0), Vector2(x, 160.0), Vector2(x - 34.0, 190.0)])
	draw_colored_polygon(pts, cloth)
	draw_rect(Rect2(x - 40.0, 0.0, 80.0, 8.0), Color(accent, 0.7))
	draw_polyline(PackedVector2Array([Vector2(x - 34.0, 190.0), Vector2(x, 160.0), Vector2(x + 34.0, 190.0)]), Color(accent, 0.55), 2.0)
	draw_circle(Vector2(x, 88.0), 12.0, Color(accent, 0.4))
	draw_circle(Vector2(x, 88.0), 7.0, cloth)


func _candle(x: float, phase: float) -> void:
	var fy := RoomLayouts.FLOOR_Y
	# Direk
	draw_rect(Rect2(x - 10.0, fy - 6.0, 20.0, 6.0), Color(0.16, 0.11, 0.09))
	draw_rect(Rect2(x - 3.0, fy - 96.0, 6.0, 90.0), Color(0.2, 0.14, 0.11))
	draw_rect(Rect2(x - 11.0, fy - 104.0, 22.0, 9.0), Color(0.26, 0.18, 0.12))
	draw_rect(Rect2(x - 4.0, fy - 124.0, 8.0, 20.0), Color(0.93, 0.88, 0.76))
	# Alev: hafifçe titrer
	var flick := 0.5 + 0.5 * sin(_t * 9.0 + phase) * sin(_t * 5.3 + phase * 2.0)
	var fh := 12.0 + 4.0 * flick
	var top := fy - 124.0
	var flame := PackedVector2Array([Vector2(x - 4.0, top), Vector2(x + 4.0, top), Vector2(x + 1.0 * sin(_t * 7.0 + phase), top - fh)])
	draw_colored_polygon(flame, Color(1.0, 0.78, 0.3))
	draw_circle(Vector2(x, top - 2.0), 2.4, Color(1.0, 0.96, 0.8))
	# Işık halesi: üst üste birkaç silik daire
	var base_a := 0.05 + 0.02 * flick
	for k in 4:
		var r := 150.0 - 32.0 * float(k)
		draw_circle(Vector2(x, top - 4.0), r, Color(1.0, 0.7, 0.3, base_a))
