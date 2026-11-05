class_name MenuList
extends RefCounted
## Dikey seçenek listesi: imleç, kapalı satırlar, fareyle seçme ve çizim. Ana menü ekranları kullanır.
## Satır: {"id": String, "text": String, "note": String, "enabled": bool}
## Kapalı satıra imleç gelebilir (notu görünür: "YAKINDA"), ama seçilemez.

const GAP := 10.0

var rows: Array[Dictionary] = []
var cursor := 0
## İlk satırın üst-orta noktası.
var top_center := Vector2(640.0, 400.0)
var row_size := Vector2(380.0, 52.0)
var font_size := 30
## true: yazı satırın ortasında; false: solda (sağda not yazılır).
var centered := true


func clear() -> void:
	rows.clear()
	cursor = 0


func add(id: String, text: String, enabled: bool = true, note: String = "") -> void:
	rows.append({"id": id, "text": text, "enabled": enabled, "note": note})


func count() -> int:
	return rows.size()


func current() -> Dictionary:
	return rows[cursor] if cursor >= 0 and cursor < rows.size() else {}


func current_id() -> String:
	return String(current().get("id", ""))


func current_enabled() -> bool:
	return bool(current().get("enabled", false))


func index_of(id: String) -> int:
	for i in rows.size():
		if rows[i]["id"] == id:
			return i
	return -1


## İmleci `id` satırına koyar (yoksa dokunmaz).
func focus(id: String) -> void:
	var i := index_of(id)
	if i >= 0:
		cursor = i


## İmleci `step` satır kaydırır (uçlarda döner). Değiştiyse true.
func move(step: int) -> bool:
	if rows.size() < 2:
		return false
	cursor = posmod(cursor + step, rows.size())
	return true


func set_cursor(i: int) -> bool:
	if i < 0 or i >= rows.size() or i == cursor:
		return false
	cursor = i
	return true


func rect_of(i: int) -> Rect2:
	var pos := Vector2(top_center.x - row_size.x * 0.5, top_center.y + float(i) * (row_size.y + GAP))
	return Rect2(pos, row_size)


## Fare konumundaki satır (yoksa -1).
func index_at(pos: Vector2) -> int:
	for i in rows.size():
		if rect_of(i).has_point(pos):
			return i
	return -1


func draw(ci: CanvasItem, t: float) -> void:
	for i in rows.size():
		var row := rows[i]
		var r := rect_of(i)
		var focused := i == cursor
		var enabled: bool = row["enabled"]
		var art := "ui_menu_button_focus" if focused else "ui_menu_button_normal"
		var tint := Color.WHITE if enabled else Color(1.0, 1.0, 1.0, 0.45)
		if not Art.draw(ci, art, r, t, tint, true):
			var fill := Color(0.16, 0.12, 0.3, 0.88) if focused else Color(0.07, 0.055, 0.13, 0.62)
			ci.draw_rect(r, fill)
			ci.draw_rect(r, Color(MenuUi.PANEL_EDGE, 0.8 if enabled else 0.35), false, 2.0)
			if focused:
				MenuUi.focus_frame(ci, r, t)
		if focused:
			var wob := sin(t * 6.0) * 3.0
			MenuUi.arrow(ci, Vector2(r.position.x - 20.0 + wob, r.get_center().y), 1, 8.0, MenuUi.GOLD if enabled else MenuUi.OFF)
		var color := MenuUi.OFF
		if enabled:
			color = MenuUi.GOLD if focused else MenuUi.WHITE
		var note: String = row["note"]
		var note_w := GameFont.width(note, 16) + 24.0 if note != "" else 0.0
		var avail := r.size.x - 40.0 - note_w
		if centered:
			MenuUi.fit_centered(ci, row["text"], r.get_center() + Vector2(0.0, -2.0), font_size, avail, color)
		else:
			MenuUi.fit_left(ci, row["text"], Vector2(r.position.x + 22.0, r.get_center().y - 2.0), font_size, avail, color)
		if note != "":
			var nc := Color(0.9, 0.9, 1.0, 0.95) if enabled else Color(MenuUi.GOLD, 0.7)
			GameFont.draw_left(ci, note, Vector2(r.end.x - GameFont.width(note, 16) - 16.0, r.get_center().y), 16, nc, false)
