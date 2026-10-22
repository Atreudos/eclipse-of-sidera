class_name GameFont
extends RefCounted
## Oyunun yazı tipi (AGENTORANGE). Dosya yoksa ya da henüz içe aktarılmadıysa Godot'un
## varsayılan fontuna düşer, yani oyun fontsuz da çalışır.
##
## Font içi boş (kontür) harflerden oluşur. Okunurluk için her yazının arkasına koyu bir hale çizilir.

const PATH := "res://assets/fonts/AGENTORANGE.ttf"

const YELLOW := Color(1.0, 0.84, 0.2)
const WHITE := Color(1.0, 1.0, 1.0)
const HALO := Color(0.05, 0.03, 0.09, 0.9)

static var _font: Font = null


static func get_font() -> Font:
	if _font == null:
		if ResourceLoader.exists(PATH):
			_font = load(PATH) as Font
		if _font == null:
			_font = ThemeDB.fallback_font
	return _font


## Yazının piksel genişliği.
static func width(text: String, size: int) -> float:
	return get_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Yazıyı `center` noktasına ortalayarak çizer (önce koyu hale, sonra renkli yazı).
static func draw_centered(ci: CanvasItem, text: String, center: Vector2, size: int, color: Color, halo: bool = true) -> void:
	var f := get_font()
	var w := width(text, size)
	var pos := Vector2(center.x - w * 0.5, center.y + (f.get_ascent(size) - f.get_descent(size)) * 0.5)
	_draw_at(ci, f, text, pos, size, color, halo)


## Renkli parçalardan oluşan tek satır. runs: [[yazı, renk], ...]. Satır `center` etrafında ortalanır.
## Örnek: [["12", SARI], [" VURUŞ", BEYAZ]]
static func draw_runs_centered(ci: CanvasItem, runs: Array, center: Vector2, size: int, alpha: float = 1.0, halo: bool = true) -> void:
	var f := get_font()
	var total := 0.0
	for r: Array in runs:
		total += width(r[0], size)
	var x := center.x - total * 0.5
	var y := center.y + (f.get_ascent(size) - f.get_descent(size)) * 0.5
	for r: Array in runs:
		var c: Color = r[1]
		c.a *= alpha
		_draw_at(ci, f, r[0], Vector2(x, y), size, c, halo)
		x += width(r[0], size)


static func _draw_at(ci: CanvasItem, f: Font, text: String, pos: Vector2, size: int, color: Color, halo: bool) -> void:
	if halo:
		var h := HALO
		h.a *= color.a
		ci.draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(size / 4, 4), h)
	ci.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
