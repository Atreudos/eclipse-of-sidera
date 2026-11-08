class_name TutorialHint
extends Control
## Ekranın üstünde duran öğretici ipucu paneli: başlık + tuş ikonlu satırlar ("[A] [D]  KOŞ").
## İçerik Tutorial.hint() ile gelir; ne zaman hangi ipucunun görüneceğini TutorialGuide seçer.
## Oyunun fontuyla ve kodla çizilir (tuş ikonları dahil); gerçek zamanla akar (duraklatınca da canlı kalır).
##
## Adım yapılınca `mark_done()`: panel yeşile döner, tik çıkar, kısa süre sonra kapanır ve `flash_finished` gelir.

signal flash_finished

const PANEL_MAX_W := 700.0
const PANEL_MIN_W := 380.0
const TOP := 14.0
const PAD_X := 30.0
const POP_TIME := 0.18
const DONE_TIME := 0.9
const KEY_H := 38.0
const TITLE_SIZE := 16
const BG := Color(0.035, 0.028, 0.075, 0.94)
const DIM := Color(0.74, 0.72, 0.86)

var hint_id := ""
var title := ""
## Tutorial.hint() satırları: {"parts": [...], "size": int, "dim": bool}
var rows: Array = []

var _age := 0.0
var _done_t := -1.0
var _t := 0.0
var _last_usec := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	process_mode = Node.PROCESS_MODE_ALWAYS


## Bir ipucunu gösterir (`data`: Tutorial.hint()). Aynı ipucu zaten görünüyorsa yalnız satırlar yenilenir (sayaç).
func show_hint(data: Dictionary) -> void:
	if data.is_empty():
		hide_hint()
		return
	var id := String(data["id"])
	if id == hint_id and _done_t < 0.0:
		rows = data["rows"]
		queue_redraw()
		return
	hint_id = id
	title = String(data["title"])
	rows = data["rows"]
	_age = 0.0
	_done_t = -1.0
	queue_redraw()


func hide_hint() -> void:
	hint_id = ""
	title = ""
	rows = []
	_done_t = -1.0
	queue_redraw()


func is_showing() -> bool:
	return hint_id != ""


## Adım tamamlandı: tik ve yeşil çerçeve, sonra kapanır.
func mark_done() -> void:
	if hint_id == "" or _done_t >= 0.0:
		return
	_done_t = 0.0
	queue_redraw()


func is_done_flashing() -> bool:
	return _done_t >= 0.0


## Panelin kapladığı yükseklik (px); görünmüyorsa 0.
func occupied_height() -> float:
	return _panel_rect().size.y + TOP if hint_id != "" else 0.0


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := 0.0
	if _last_usec != 0:
		dt = clampf(float(now - _last_usec) / 1000000.0, 0.0, 0.05)
	_last_usec = now
	if hint_id == "":
		return
	_t += dt
	_age += dt
	if _done_t >= 0.0:
		_done_t += dt
		if _done_t >= DONE_TIME:
			hide_hint()
			flash_finished.emit()
			return
	queue_redraw()


# ---------------------------------------------------------------- ölçü

func _width() -> float:
	return size.x if size.x > 1.0 else 1280.0


func _part_width(part: Dictionary, size_px: int) -> float:
	if part.has("k"):
		return _cap_width(String(part["k"]))
	if part.has("i"):
		return 30.0
	return GameFont.width(String(part.get("t", "")), size_px)


func _cap_width(label: String) -> float:
	match label:
		"LEFT", "RIGHT", "UP", "DOWN":
			return KEY_H
	return maxf(KEY_H, GameFont.width(label, 20) + 24.0)


func _row_width(row: Dictionary) -> float:
	var w := 0.0
	var size_px := int(row.get("size", 28))
	var parts: Array = row["parts"]
	for i in parts.size():
		var part: Dictionary = parts[i]
		w += _part_width(part, size_px)
		if part.has("k") and i + 1 < parts.size() and (parts[i + 1] as Dictionary).has("k"):
			w += 8.0  # yan yana iki tuş arası
	return w


func _row_height(row: Dictionary) -> float:
	var h := float(int(row.get("size", 28))) * 1.15
	for part: Dictionary in row["parts"]:
		if part.has("k"):
			h = maxf(h, KEY_H)
		elif part.has("i"):
			h = maxf(h, 30.0)
	return h


## Panel dikdörtgeni (ekran koordinatı).
func _panel_rect() -> Rect2:
	var inner := float(GameFont.width(title, TITLE_SIZE))
	for row: Dictionary in rows:
		inner = maxf(inner, _row_width(row))
	var w := clampf(inner + PAD_X * 2.0, PANEL_MIN_W, PANEL_MAX_W)
	var h := 14.0 + float(TITLE_SIZE) + 10.0
	for row: Dictionary in rows:
		h += _row_height(row) + 8.0
	h += 8.0
	return Rect2((_width() - w) * 0.5, TOP, w, h)


# ---------------------------------------------------------------- çizim

func _draw() -> void:
	if hint_id == "":
		return
	var pop := clampf(_age / POP_TIME, 0.0, 1.0)
	var ease_k := 1.0 - pow(1.0 - pop, 3.0)
	var rect := _panel_rect()
	var center := rect.get_center()
	var k := lerpf(0.92, 1.0, ease_k)
	var done := _done_t >= 0.0
	# Tamamlanınca iki yana küçük bir "yay" etkisi: panel hafifçe şişip söner.
	if done:
		k *= 1.0 + 0.04 * sin(clampf(_done_t / 0.25, 0.0, 1.0) * PI)
	draw_set_transform(center * (1.0 - k), 0.0, Vector2(k, k))
	var alpha := ease_k
	if done:
		alpha *= clampf((DONE_TIME - _done_t) / 0.25, 0.0, 1.0)
	var accent := Tutorial.GREEN if done else GameFont.YELLOW
	draw_rect(rect, Color(BG, BG.a * alpha))
	draw_rect(rect, Color(accent, 0.8 * alpha), false, 2.0)
	draw_rect(rect.grow(-5.0), Color(accent, 0.22 * alpha), false, 1.0)
	# Üst kenarda kısa vurgu çizgisi
	var pulse := 0.65 + 0.35 * sin(_t * 5.0)
	draw_rect(Rect2(rect.position.x + 24.0, rect.position.y - 1.0, rect.size.x - 48.0, 3.0), Color(accent, (0.35 + 0.4 * pulse) * alpha))
	var y := rect.position.y + 14.0 + float(TITLE_SIZE) * 0.5
	GameFont.draw_centered(self, title, Vector2(center.x, y), TITLE_SIZE, Color(accent, alpha), false)
	y += float(TITLE_SIZE) * 0.5 + 10.0
	for row: Dictionary in rows:
		var rh := _row_height(row)
		_draw_row(row, Vector2(center.x, y + rh * 0.5), alpha, pulse)
		y += rh + 8.0
	if done:
		_draw_check(Vector2(rect.end.x - 34.0, rect.position.y + 30.0), alpha)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_row(row: Dictionary, center: Vector2, alpha: float, pulse: float) -> void:
	var size_px := int(row.get("size", 28))
	var dim := bool(row.get("dim", false))
	var parts: Array = row["parts"]
	var x := center.x - _row_width(row) * 0.5
	for i in parts.size():
		var part: Dictionary = parts[i]
		var w := _part_width(part, size_px)
		if part.has("k"):
			_draw_cap(Vector2(x, center.y), String(part["k"]), w, alpha, pulse)
			x += w
			if i + 1 < parts.size() and (parts[i + 1] as Dictionary).has("k"):
				x += 8.0
		elif part.has("i"):
			_draw_icon(Vector2(x + w * 0.5, center.y), String(part["i"]), alpha, pulse)
			x += w
		else:
			var c: Color = DIM if dim else (part.get("c", Color.WHITE) as Color)
			c.a *= alpha
			GameFont.draw_left(self, String(part["t"]), Vector2(x, center.y), size_px, c, not dim)
			x += w


## Tuş ikonu: koyu gövde, parlak çerçeve, altta "basılma" payı. Ok tuşları üçgen olarak çizilir.
func _draw_cap(left_mid: Vector2, label: String, w: float, alpha: float, pulse: float) -> void:
	var r := Rect2(left_mid.x, left_mid.y - KEY_H * 0.5, w, KEY_H)
	var edge := Color(GameFont.YELLOW, (0.7 + 0.3 * pulse) * alpha)
	draw_rect(Rect2(r.position + Vector2(0.0, 4.0), r.size), Color(0.0, 0.0, 0.0, 0.55 * alpha))
	draw_rect(r, Color(0.13, 0.1, 0.22, 0.97 * alpha))
	draw_rect(r, edge, false, 2.0)
	draw_rect(Rect2(r.position.x + 3.0, r.end.y - 7.0, r.size.x - 6.0, 4.0), Color(GameFont.YELLOW, 0.22 * alpha))
	var c := r.get_center()
	var tri := PackedVector2Array()
	match label:
		"LEFT":
			tri = PackedVector2Array([c + Vector2(-9, 0), c + Vector2(7, -10), c + Vector2(7, 10)])
		"RIGHT":
			tri = PackedVector2Array([c + Vector2(9, 0), c + Vector2(-7, -10), c + Vector2(-7, 10)])
		"UP":
			tri = PackedVector2Array([c + Vector2(0, -9), c + Vector2(-10, 7), c + Vector2(10, 7)])
		"DOWN":
			tri = PackedVector2Array([c + Vector2(0, 9), c + Vector2(-10, -7), c + Vector2(10, -7)])
	if tri.is_empty():
		GameFont.draw_centered(self, label, c + Vector2(0.0, -1.0), 20, Color(1.0, 1.0, 1.0, alpha), false)
	else:
		draw_colored_polygon(tri, Color(1.0, 1.0, 1.0, alpha))


## Saldırı işareti ikonu: altın elmas (parry'lenebilir) ya da kırmızı daire (kaçılacak); oyundaki işaretlerle aynı dil.
func _draw_icon(center: Vector2, kind: String, alpha: float, pulse: float) -> void:
	if kind == "gold":
		var r := 13.0 * (0.92 + 0.12 * pulse)
		draw_circle(center, r * 1.7, Color(1.0, 0.82, 0.25, 0.12 * alpha))
		var pts := PackedVector2Array([center + Vector2(0, -r), center + Vector2(r * 0.8, 0), center + Vector2(0, r), center + Vector2(-r * 0.8, 0)])
		draw_colored_polygon(pts, Color(GameFont.YELLOW, alpha))
		var inner := PackedVector2Array([center + Vector2(0, -r * 0.5), center + Vector2(r * 0.38, 0), center + Vector2(0, r * 0.5), center + Vector2(-r * 0.38, 0)])
		draw_colored_polygon(inner, Color(1.0, 0.96, 0.7, alpha))
		pts.append(pts[0])
		draw_polyline(pts, Color(1.0, 1.0, 1.0, alpha), 2.0)
	else:
		var rr := 11.0 * (0.92 + 0.12 * pulse)
		draw_circle(center, rr * 1.7, Color(1.0, 0.22, 0.22, 0.14 * alpha))
		draw_circle(center, rr, Color(1.0, 0.22, 0.22, alpha))
		draw_arc(center, rr + 3.0, 0.0, TAU, 24, Color(1.0, 0.6, 0.6, 0.6 * alpha), 2.0)


func _draw_check(center: Vector2, alpha: float) -> void:
	var pts := PackedVector2Array([center + Vector2(-12, 1), center + Vector2(-4, 10), center + Vector2(13, -10)])
	draw_polyline(pts, Color(0.0, 0.0, 0.0, 0.5 * alpha), 8.0)
	draw_polyline(pts, Color(Tutorial.GREEN, alpha), 5.0)
