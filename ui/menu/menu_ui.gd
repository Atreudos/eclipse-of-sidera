class_name MenuUi
extends RefCounted
## Ana menü ekranlarının ortak çizimleri ve renkleri. Her çizim önce `Art`'ta o adla bir PNG arar (senin çizimin),
## yoksa koddan çizilen yer tutucuyu kullanır.

const BG := Color(0.035, 0.028, 0.06)
const GOLD := Color(1.0, 0.84, 0.2)
const WHITE := Color(1.0, 1.0, 1.0)
const DIM := Color(0.66, 0.63, 0.78)
const OFF := Color(0.46, 0.44, 0.56)
const PANEL_FILL := Color(0.06, 0.045, 0.11, 0.92)
const PANEL_EDGE := Color(0.36, 0.28, 0.58)
const GOOD := Color(0.55, 1.0, 0.65)
const BAD := Color(1.0, 0.45, 0.45)

## Zorluk renkleri (EASY, NORMAL, DIFFICULT, IMMORTAL).
const DIFFICULTY_COLORS := [
	Color(0.55, 0.95, 0.62),
	Color(0.58, 0.82, 1.0),
	Color(1.0, 0.64, 0.26),
	Color(1.0, 0.36, 0.5),
]
const MODE_COLORS := [Color(1.0, 0.84, 0.2), Color(0.8, 0.6, 1.0)]


static func difficulty_color(level: int) -> Color:
	return DIFFICULTY_COLORS[Difficulty.clamp_level(level)]


static func mode_color(kind: int) -> Color:
	return MODE_COLORS[GameMode.clamp_kind(kind)]


## Çerçeveli pencere: `art_key` çizimi (9 dilim) varsa o, yoksa kod paneli.
static func panel(ci: CanvasItem, rect: Rect2, art_key: String = "") -> void:
	if art_key != "" and Art.draw_nine(ci, art_key, rect):
		return
	ci.draw_rect(rect, PANEL_FILL)
	ci.draw_rect(rect, PANEL_EDGE, false, 2.0)
	ci.draw_rect(rect.grow(-5.0), Color(PANEL_EDGE, 0.3), false, 1.0)


## Seçili kutunun nabız gibi atan sarı çerçevesi.
static func focus_frame(ci: CanvasItem, rect: Rect2, t: float, grow: float = 3.0) -> void:
	var pulse := 0.65 + 0.35 * sin(t * 7.0)
	ci.draw_rect(rect.grow(grow), Color(GOLD, pulse), false, 3.0)


## Küçük üçgen ok (yön: -1 sol, +1 sağ). Yazı tipinde ok karakteri olmadığı için çizilir.
static func arrow(ci: CanvasItem, center: Vector2, dir: int, size: float, color: Color) -> void:
	var s := float(dir) * size
	var pts := PackedVector2Array([
		center + Vector2(-s * 0.5, -size * 0.8),
		center + Vector2(s * 0.7, 0.0),
		center + Vector2(-s * 0.5, size * 0.8),
	])
	ci.draw_colored_polygon(pts, color)


## Zorluk amblemi: çizim varsa o (`ui_diff_easy`...), yoksa renkli elmas ve içinde seviye kadar nokta.
static func difficulty_emblem(ci: CanvasItem, level: int, rect: Rect2, t: float) -> void:
	level = Difficulty.clamp_level(level)
	if Art.draw(ci, "ui_diff_" + Difficulty.key_of(level), rect, t):
		return
	var c := difficulty_color(level)
	var center := rect.get_center()
	var r := minf(rect.size.x, rect.size.y) * 0.5 * (0.9 + 0.04 * sin(t * 3.0 + float(level)))
	var pts := PackedVector2Array([center + Vector2(0.0, -r), center + Vector2(r, 0.0), center + Vector2(0.0, r), center + Vector2(-r, 0.0)])
	ci.draw_colored_polygon(pts, Color(c, 0.16))
	var loop := PackedVector2Array(pts)
	loop.append(pts[0])
	ci.draw_polyline(loop, c, 3.0, true)
	var n := level + 1
	var gap := r * 0.3
	for i in n:
		var x := center.x + (float(i) - float(n - 1) * 0.5) * gap
		ci.draw_circle(Vector2(x, center.y), r * 0.09, c)


## Kip amblemi (NORMAL: kule/katlar, SINIRSIZ: sonsuzluk). Çizim yoksa renkli halka ve simge.
static func mode_emblem(ci: CanvasItem, kind: int, rect: Rect2, t: float) -> void:
	kind = GameMode.clamp_kind(kind)
	var key := "ui_mode_endless" if kind == GameMode.Kind.ENDLESS else "ui_mode_normal"
	if Art.draw(ci, key, rect, t):
		return
	var c := mode_color(kind)
	var center := rect.get_center()
	var r := minf(rect.size.x, rect.size.y) * 0.45
	ci.draw_arc(center, r, 0.0, TAU, 48, Color(c, 0.9), 3.0, true)
	if kind == GameMode.Kind.ENDLESS:
		# Yan yatmış sekiz (sonsuzluk): iki halka.
		var o := r * 0.36
		ci.draw_arc(center + Vector2(-o, 0.0), o, 0.0, TAU, 28, c, 3.0, true)
		ci.draw_arc(center + Vector2(o, 0.0), o, 0.0, TAU, 28, c, 3.0, true)
	else:
		# Basamaklar: üç kat.
		for i in 3:
			var w := r * (0.5 + 0.3 * float(i))
			ci.draw_rect(Rect2(center.x - w * 0.5, center.y + r * 0.42 - float(i) * r * 0.32, w, r * 0.22), Color(c, 0.85))


## Artı simgesi ("yeni oyun").
static func plus(ci: CanvasItem, center: Vector2, size: float, color: Color, t: float) -> void:
	if Art.draw(ci, "ui_slot_new_icon", Rect2(center - Vector2(size, size), Vector2(size, size) * 2.0), t):
		return
	ci.draw_line(center + Vector2(-size * 0.6, 0.0), center + Vector2(size * 0.6, 0.0), color, 5.0)
	ci.draw_line(center + Vector2(0.0, -size * 0.6), center + Vector2(0.0, size * 0.6), color, 5.0)


## Yazıyı `max_width`e sığana kadar küçültüp ortalayarak çizer (uzun isimler için).
static func fit_centered(ci: CanvasItem, text: String, center: Vector2, size: int, max_width: float, color: Color) -> void:
	var s := size
	while s > 12 and GameFont.width(text, s) > max_width:
		s -= 2
	GameFont.draw_centered(ci, text, center, s, color)


## Soldan hizalı, sığana kadar küçülen yazı.
static func fit_left(ci: CanvasItem, text: String, left_center: Vector2, size: int, max_width: float, color: Color) -> void:
	var s := size
	while s > 12 and GameFont.width(text, s) > max_width:
		s -= 2
	GameFont.draw_left(ci, text, left_center, s, color)
