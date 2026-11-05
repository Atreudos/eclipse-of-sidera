class_name TitleScreen
extends MenuScreen
## Başlık ekranı: logo ve OYNA / KREDİLER / ÇIKIŞ.
## Logo çizimin (`ui_logo`) gelince onun yerine çizilir; o zamana kadar yazı ve tutulma yer tutucudur.

const VERSION_TEXT := "SÜRÜM 0.1"

var list := MenuList.new()


func screen_id() -> String:
	return "title"


func on_enter() -> void:
	list.clear()
	list.top_center = Vector2(640.0, 436.0)
	list.row_size = Vector2(340.0, 54.0)
	list.font_size = 30
	list.add("play", "OYNA")
	list.add("credits", "KREDİLER")
	list.add("quit", "ÇIKIŞ")


func eclipse() -> Vector3:
	return ECLIPSE_TITLE


func hint() -> String:
	return "YÖN TUŞLARI / WASD GEZİN     ENTER SEÇ"


func on_action(action: String) -> void:
	match action:
		"up":
			if list.move(-1):
				menu.play_move()
		"down":
			if list.move(1):
				menu.play_move()
		"accept":
			activate()


func activate() -> void:
	match list.current_id():
		"play":
			menu.play_select()
			menu.push(SlotsScreen.new())
		"credits":
			menu.play_select()
			menu.push(CreditsScreen.new())
		"quit":
			menu.quit_game()


func on_hover(pos: Vector2) -> void:
	var i := list.index_at(pos)
	if i >= 0 and list.set_cursor(i):
		menu.play_move()


func on_click(pos: Vector2) -> void:
	var i := list.index_at(pos)
	if i >= 0:
		list.set_cursor(i)
		activate()


func draw(ci: CanvasItem, t: float) -> void:
	if not Art.draw(ci, "ui_logo", Rect2(320.0, 40.0, 640.0, 240.0), t):
		var pulse := 0.85 + 0.15 * sin(t * 1.6)
		GameFont.draw_centered(ci, "ECLIPSE OF", Vector2(640.0, 92.0), 38, Color(1.0, 0.93, 0.7, pulse))
		MenuUi.fit_centered(ci, "SIDERA", Vector2(640.0, 240.0), 112, 520.0, MenuUi.GOLD)
	list.draw(ci, t)
	GameFont.draw_left(ci, VERSION_TEXT, Vector2(1256.0 - GameFont.width(VERSION_TEXT, 14), 698.0), 14, Color(MenuUi.DIM, 0.6), false)
