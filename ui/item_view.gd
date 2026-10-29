class_name ItemView
extends RefCounted
## Envanter ekranı ile F5 menüsünün ortak çizimleri: çerçeve, eşya kutusu, ayrıntı paneli.
## Hepsi koddan çizilir (yer tutucu). Kendi eşya çizimlerin `assets/items/<id>.png` olarak gelince
## `ItemData.icon()` onları otomatik kullanır; harf yer tutucusu kaybolur.

const BG := Color(0.05, 0.035, 0.09, 0.97)
const EDGE := Color(0.36, 0.28, 0.58)
const CELL_BG := Color(0.1, 0.075, 0.17, 0.97)
const CELL_EDGE := Color(0.27, 0.22, 0.42)
const DIM := Color(0.66, 0.63, 0.78)
const SHADOW := Color(0.82, 0.64, 1.0)
const GOOD := Color(0.55, 1.0, 0.65)
const BAD := Color(1.0, 0.45, 0.45)
const BLUE := Color(0.5, 0.78, 1.0)
const HEART := Color(1.0, 0.45, 0.5)

## Şu an açık olan menü (envanter ekranı ya da F5 menüsü). Aynı anda yalnız biri açılır.
static var active_menu: Control = null


static func draw_panel(ci: CanvasItem, rect: Rect2) -> void:
	ci.draw_rect(rect, BG)
	ci.draw_rect(rect, EDGE, false, 2.0)
	ci.draw_rect(rect.grow(-5.0), Color(EDGE, 0.3), false, 1.0)


## Tek eşya kutusu: dolu (rarity renkli çerçeve, simge/harf, yığın sayısı) ya da boş (slot adı soluk).
static func draw_cell(ci: CanvasItem, rect: Rect2, item: ItemData, count: int, focused: bool, t: float, empty_label: String = "") -> void:
	ci.draw_rect(rect, CELL_BG)
	if item != null:
		var c := item.color()
		ci.draw_rect(rect.grow(-3.0), Color(c, 0.1))
		ci.draw_rect(rect, Color(c, 0.9), false, 2.0)
		var tex := item.icon()
		if tex != null:
			ci.draw_texture_rect(tex, rect.grow(-6.0), false)
		else:
			GameFont.draw_centered(ci, item.glyph(), rect.get_center() + Vector2(0.0, -2.0), 32, c, false)
		if count > 1:
			var label := "x%d" % count
			var w := GameFont.width(label, 15)
			GameFont.draw_left(ci, label, Vector2(rect.end.x - w - 5.0, rect.end.y - 11.0), 15, GameFont.WHITE)
	else:
		ci.draw_rect(rect, CELL_EDGE, false, 2.0)
		if empty_label != "":
			GameFont.draw_centered(ci, empty_label, rect.get_center(), 13, Color(DIM, 0.75), false)
	if focused:
		var pulse := 0.65 + 0.35 * sin(t * 7.0)
		ci.draw_rect(rect.grow(3.0), Color(GameFont.YELLOW, pulse), false, 3.0)


## Ayrıntı paneli: ad, nadirlik + slot, açıklama, "Gölge alırsa", etiketler, fiyat. `item` null ise `empty_text` yazılır.
static func draw_detail(ci: CanvasItem, rect: Rect2, item: ItemData, empty_text: String = "") -> void:
	draw_panel(ci, rect)
	var x := rect.position.x + 18.0
	var w := rect.size.x - 36.0
	var y := rect.position.y + 30.0
	if item == null:
		for line in GameFont.wrap(empty_text, 18, w):
			GameFont.draw_left(ci, line, Vector2(x, y), 18, DIM)
			y += 24.0
		return
	var title := item.upper_name()
	var size := 28
	while size > 16 and GameFont.width(title, size) > w:
		size -= 2
	GameFont.draw_left(ci, title, Vector2(x, y), size, item.color())
	y += 30.0
	GameFont.draw_runs_left(ci, [[item.rarity_name(), item.color()], ["   " + item.slot_name(), DIM]], Vector2(x, y), 16)
	y += 32.0
	for line in GameFont.wrap(item.description, 17, w):
		GameFont.draw_left(ci, line, Vector2(x, y), 17, GameFont.WHITE)
		y += 23.0
	if item.shadow_text != "":
		y += 12.0
		GameFont.draw_left(ci, "GÖLGE ALIRSA", Vector2(x, y), 15, SHADOW)
		y += 22.0
		for line in GameFont.wrap(item.shadow_text, 16, w):
			GameFont.draw_left(ci, line, Vector2(x, y), 16, Color(SHADOW, 0.92))
			y += 22.0
	if not item.tags.is_empty():
		y += 14.0
		GameFont.draw_left(ci, "ETİKET  " + "  ".join(item.tags), Vector2(x, y), 14, DIM)
		y += 22.0
	if item.price > 0:
		var py := rect.end.y - 26.0
		ci.draw_circle(Vector2(x + 9.0, py), 8.0, Color(0.55, 0.36, 0.05))
		ci.draw_circle(Vector2(x + 9.0, py), 6.6, Color(1.0, 0.82, 0.2))
		GameFont.draw_left(ci, "FİYAT  %d" % item.price, Vector2(x + 26.0, py), 17, GameFont.YELLOW)
