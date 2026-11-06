class_name PauseMenu
extends GameMenu
## Duraklatma menüsü (Esc): devam, yeniden başla, ana menü, oyundan çık. Açıkken oyun durur.
## Koşuyu kaybettirecek seçimler ikinci basışta onaylanır. Ana menüye dönünce koşu son oda başlangıcından sürer.

const PANEL := Rect2(400.0, 100.0, 480.0, 500.0)
const ROW := Vector2(340.0, 52.0)

var list := MenuList.new()
## İkinci basış bekleyen seçenek ("" = yok).
var armed := ""


func _ready() -> void:
	super._ready()
	list.top_center = Vector2(PANEL.get_center().x, PANEL.position.y + 112.0)
	list.row_size = ROW
	list.font_size = 28
	list.add("resume", "DEVAM ET")
	list.add("restart", "YENİDEN BAŞLA")
	list.add("menu", "ANA MENÜ")
	list.add("quit", "OYUNDAN ÇIK")


func _on_open() -> void:
	list.cursor = 0
	armed = ""


func _unhandled_input(event: InputEvent) -> void:
	# Eylemler sahneyi değiştirebilir (ana menü, yeniden başla): tuşu önce işaretle, sonra işle.
	var vp := get_viewport()
	if not is_open:
		if event.is_action_pressed("ui_cancel"):
			if open(_find_player()):
				vp.set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		vp.set_input_as_handled()
		return
	var action := ""
	if event.is_action_pressed("ui_up", true):
		action = "up"
	elif event.is_action_pressed("ui_down", true):
		action = "down"
	elif event.is_action_pressed("ui_accept"):
		action = "accept"
	var key := event as InputEventKey
	if action == "" and key != null and key.pressed:
		match key.physical_keycode:
			KEY_W:
				action = "up"
			KEY_S:
				action = "down"
			KEY_E, KEY_J:
				action = "accept" if not key.echo else ""
	# Açıkken oyun tuşları (dash, parry...) alta geçmesin.
	if key != null or event is InputEventJoypadButton:
		vp.set_input_as_handled()
	if action != "":
		press(action)


## Testler ve gerçek giriş aynı yoldan: "up" "down" "accept".
func press(action: String) -> void:
	match action:
		"up":
			if list.move(-1):
				armed = ""
				Sfx.play("ui_move", -8.0, 1.0, 0.03)
		"down":
			if list.move(1):
				armed = ""
				Sfx.play("ui_move", -8.0, 1.0, 0.03)
		"accept":
			activate()


func _gui_input(event: InputEvent) -> void:
	if not is_open:
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		var i := list.index_at(motion.position)
		if i >= 0 and list.set_cursor(i):
			armed = ""
			Sfx.play("ui_move", -8.0, 1.0, 0.03)
		return
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		var i := list.index_at(button.position)
		if i >= 0:
			list.set_cursor(i)
			activate()
		elif not PANEL.has_point(button.position):
			close()
		accept_event()


## Bu seçenek ikinci basış ister mi?
func needs_confirm(id: String) -> bool:
	match id:
		"restart":
			return true
		"menu", "quit":
			return GameState.slot == null  # kayıtsız oturumda ilerleme kaybolur
	return false


func activate() -> void:
	var id := list.current_id()
	if needs_confirm(id) and armed != id:
		armed = id
		Sfx.play("ui_select", -6.0)
		_say("TEKRAR BAS: KOŞU KAYBOLUR" if id == "restart" else "TEKRAR BAS: İLERLEME KAYDEDİLMEZ", false)
		return
	armed = ""
	perform(id)


func perform(id: String) -> void:
	var tree := get_tree()
	var run := tree.current_scene as RunController
	match id:
		"resume":
			close()
		"restart":
			close()
			if run != null:
				run.restart()
			else:
				tree.reload_current_scene()
		"menu":
			close()
			if run != null:
				run.return_to_menu()
			else:
				SceneRouter.go_menu(tree)
		"quit":
			close()
			if run != null:
				run.quit_game()
			else:
				SceneRouter.quit(tree)


func _draw() -> void:
	if not is_open:
		return
	var cx := PANEL.get_center().x
	draw_rect(Rect2(0.0, 0.0, _w(), _h()), Color(0.0, 0.0, 0.03, 0.72))
	MenuUi.panel(self, PANEL, "ui_pause_panel")
	MenuUi.fit_centered(self, "DURAKLATILDI", Vector2(cx, PANEL.position.y + 58.0), 40, PANEL.size.x - 80.0, MenuUi.GOLD)
	list.draw(self, _t)
	_draw_message(Vector2(cx, PANEL.position.y + 376.0), PANEL.size.x - 40.0)
	var note := "KAYIT: %s     Ana menüden odanın başından devam edersin." % GameState.slot.name if GameState.slot != null else "Kayıtsız oturum: ilerleme kaydedilmez."
	var y := PANEL.end.y - 92.0
	for line in GameFont.wrap(note, 15, PANEL.size.x - 60.0):
		GameFont.draw_centered(self, line, Vector2(cx, y), 15, Color(MenuUi.DIM, 0.9), false)
		y += 21.0
	GameFont.draw_centered(self, "YUKARI / AŞAĞI     ENTER SEÇ     ESC DEVAM", Vector2(cx, PANEL.end.y - 24.0), 14, Color(MenuUi.DIM, 0.85), false)
