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


## Türkçe büyük harf ("i" -> "İ", "ı" -> "I"); Godot'un to_upper'ı bunu bilmez.
static func upper(text: String) -> String:
	return text.replace("i", "İ").replace("ı", "I").replace("ğ", "Ğ").replace("ş", "Ş").replace("ç", "Ç").replace("ö", "Ö").replace("ü", "Ü").to_upper()


## Yazıyı `max_width` pikseli aşmayacak şekilde kelime sınırlarında satırlara böler.
## (Tek başına sığmayan uzun kelime kendi satırında taşar.)
static func wrap(text: String, size: int, max_width: float) -> Array[String]:
	var lines: Array[String] = []
	var cur := ""
	for word in text.split(" ", false):
		var trial: String = word if cur == "" else cur + " " + word
		if cur == "" or width(trial, size) <= max_width:
			cur = trial
		else:
			lines.append(cur)
			cur = word
	if cur != "":
		lines.append(cur)
	return lines


## Fontun '%' işareti boş çiziliyor. Türkçede "%15" zaten "yüzde 15" diye okunur: çizmeden önce yazıya çevrilir
## (ölçme de aynı yazıyı kullanır, hizalar şaşmaz).
static func _prep(text: String) -> String:
	return text.replace("%", "yüzde ") if text.contains("%") else text


## Yazının piksel genişliği.
static func width(text: String, size: int) -> float:
	return get_font().get_string_size(_prep(text), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Yazıyı `center` noktasına ortalayarak çizer (önce koyu hale, sonra renkli yazı).
static func draw_centered(ci: CanvasItem, text: String, center: Vector2, size: int, color: Color, halo: bool = true) -> void:
	var f := get_font()
	var w := width(text, size)
	var pos := Vector2(center.x - w * 0.5, center.y + (f.get_ascent(size) - f.get_descent(size)) * 0.5)
	_draw_at(ci, f, text, pos, size, color, halo)


## Yazıyı soldan hizalı çizer: `left_center` yazının SOL-ORTA noktasıdır.
static func draw_left(ci: CanvasItem, text: String, left_center: Vector2, size: int, color: Color, halo: bool = true) -> void:
	var f := get_font()
	var pos := Vector2(left_center.x, left_center.y + (f.get_ascent(size) - f.get_descent(size)) * 0.5)
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


## Renkli parçalardan oluşan tek satır, SOLDAN hizalı: `left_center` satırın sol-orta noktasıdır.
static func draw_runs_left(ci: CanvasItem, runs: Array, left_center: Vector2, size: int, alpha: float = 1.0, halo: bool = true) -> void:
	var f := get_font()
	var x := left_center.x
	var y := left_center.y + (f.get_ascent(size) - f.get_descent(size)) * 0.5
	for r: Array in runs:
		var c: Color = r[1]
		c.a *= alpha
		_draw_at(ci, f, r[0], Vector2(x, y), size, c, halo)
		x += width(r[0], size)


static func _draw_at(ci: CanvasItem, f: Font, raw_text: String, pos: Vector2, size: int, color: Color, halo: bool) -> void:
	var text := _prep(raw_text)
	if halo:
		var h := HALO
		h.a *= color.a
		ci.draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(size / 4, 4), h)
	ci.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
