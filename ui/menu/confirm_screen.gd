class_name ConfirmScreen
extends MenuScreen
## Onay penceresi (kaydı silmek, yarım koşuyu bırakmak...). İmleç güvenli seçenekte (HAYIR) başlar.
## EVET seçilince ekran kendini kapatır, sonra `on_yes` çağrılır.

const PANEL := Rect2(240.0, 190.0, 800.0, 340.0)
const BUTTON := Vector2(250.0, 58.0)

var title_text := ""
var lines: Array = []
var yes_text := "EVET"
var no_text := "HAYIR"
var on_yes := Callable()
var danger := false
## 0 = evet, 1 = hayır.
var cursor := 1


func _init(title: String, body: Array, yes: String, no: String, callback: Callable, is_danger: bool = false) -> void:
	title_text = title
	lines = body
	yes_text = yes
	no_text = no
	on_yes = callback
	danger = is_danger


func screen_id() -> String:
	return "confirm"


func button_rect(i: int) -> Rect2:
	var cx := PANEL.get_center().x + (-1.0 if i == 0 else 1.0) * 150.0
	return Rect2(Vector2(cx - BUTTON.x * 0.5, PANEL.end.y - 40.0 - BUTTON.y), BUTTON)


func hint() -> String:
	return "SOL / SAĞ SEÇ     ENTER ONAYLA     ESC VAZGEÇ"


func on_action(action: String) -> void:
	match action:
		"left", "right", "up", "down":
			cursor = 1 - cursor
			menu.play_move()
		"accept":
			choose(cursor)
		"back":
			menu.play_move()
			menu.pop()


## 0 = evet, 1 = hayır.
func choose(i: int) -> void:
	if i == 0:
		menu.play_select()
		menu.pop()
		if on_yes.is_valid():
			on_yes.call()
	else:
		menu.play_move()
		menu.pop()


func on_hover(pos: Vector2) -> void:
	for i in 2:
		if button_rect(i).has_point(pos) and cursor != i:
			cursor = i
			menu.play_move()


func on_click(pos: Vector2) -> void:
	for i in 2:
		if button_rect(i).has_point(pos):
			cursor = i
			choose(i)
			return


func draw(ci: CanvasItem, t: float) -> void:
	ci.draw_rect(Rect2(0.0, 0.0, MainMenu.W, MainMenu.H), Color(0.0, 0.0, 0.02, 0.5))
	MenuUi.panel(ci, PANEL, "ui_confirm_panel")
	var accent := MenuUi.BAD if danger else MenuUi.GOLD
	MenuUi.fit_centered(ci, title_text, Vector2(PANEL.get_center().x, PANEL.position.y + 56.0), 44, PANEL.size.x - 80.0, accent)
	var y := PANEL.position.y + 118.0
	for raw in lines:
		for line in GameFont.wrap(str(raw), 22, PANEL.size.x - 100.0):
			GameFont.draw_centered(ci, line, Vector2(PANEL.get_center().x, y), 22, MenuUi.WHITE)
			y += 30.0
	for i in 2:
		var r := button_rect(i)
		var focused := cursor == i
		var label := yes_text if i == 0 else no_text
		var fill := Color(0.16, 0.12, 0.3, 0.9) if focused else Color(0.07, 0.055, 0.13, 0.7)
		if not Art.draw(ci, "ui_menu_button_focus" if focused else "ui_menu_button_normal", r, t, Color.WHITE, true):
			ci.draw_rect(r, fill)
			ci.draw_rect(r, Color(MenuUi.PANEL_EDGE, 0.8), false, 2.0)
			if focused:
				MenuUi.focus_frame(ci, r, t)
		var col := MenuUi.WHITE
		if focused:
			col = MenuUi.BAD if (danger and i == 0) else MenuUi.GOLD
		GameFont.draw_centered(ci, label, r.get_center() + Vector2(0.0, -2.0), 28, col)
