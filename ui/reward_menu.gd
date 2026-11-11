class_name RewardMenu
extends GameMenu
## Ödül menüsü (Gölge'yi yenince sunağa E): iki eşyadan birini seç; SEÇMEDİĞİN Gölge'ye gider. Açıkken oyun durur.
## Geçici ve idare eder: çizimlerin gelince görünüm yeniden yapılacak; mantık (RewardChoice.take) aynı kalır.
##
## Kontroller: sol/sağ ya da A/D gezinir. Enter / Space / E / J ya da fare (seçiliye tekrar tıkla) alır. Esc kapatır (sonra yine seçebilirsin).
## Seçim geri alınmaz: alınan eşya sende kalır, diğeri Gölge'nin envanterine gider ve sonraki katlarda sana karşı kullanılır.

const PANEL := Rect2(100.0, 40.0, 1080.0, 640.0)
const DETAIL := Rect2(852.0, 118.0, 300.0, 456.0)
const CELL := 150.0
const GAP := 90.0
## Kutuların ortası (x) ve üst kenarı (y).
const GRID_CENTER_X := 470.0
const GRID_TOP := 170.0
const COST_TOP := 470.0

var choice: RewardChoice
## Oyuncunun bu menüyü açtığı sunak (kapanınca sunak yeniden çizilir).
var stand: RewardStand

var _rects: Array[Rect2] = []
var _cursor := 0


## Menüyü bir ödül için açar. Açılamazsa (seçim yok / zaten yapılmış, başka menü açık, oyuncu ölü) false.
func open_reward(p: Player, c: RewardChoice, s: RewardStand = null) -> bool:
	if c == null or c.is_done() or c.size() == 0:
		return false
	choice = c
	stand = s
	if not open(p):
		choice = null
		stand = null
		return false
	return true


func _on_open() -> void:
	_build_layout()
	_cursor = 0


func close() -> void:
	super.close()
	if stand != null and is_instance_valid(stand):
		stand.queue_redraw()


# ---------------------------------------------------------------- düzen

func _build_layout() -> void:
	_rects.clear()
	if choice == null:
		return
	var n := choice.size()
	for i in n:
		var x := GRID_CENTER_X + (float(i) - float(n - 1) * 0.5) * (CELL + GAP) - CELL * 0.5
		_rects.append(Rect2(x, GRID_TOP, CELL, CELL))


func cell_count() -> int:
	return _rects.size()


func cell_rect(i: int) -> Rect2:
	return _rects[i]


func cursor_index() -> int:
	return _cursor


## İmlecin üstündeki eşya (menü kapalıysa null).
func cursor_item() -> ItemData:
	if not is_open or choice == null or _cursor < 0 or _cursor >= choice.size():
		return null
	return choice.items[_cursor]


## İmleci `i`. eşyaya götürür (testler).
func focus(i: int) -> bool:
	if choice == null or i < 0 or i >= choice.size():
		return false
	_cursor = i
	return true


# ---------------------------------------------------------------- giriş

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	var vp := get_viewport()
	if event.is_action_pressed("ui_cancel"):
		vp.set_input_as_handled()
		close()
		return
	var step := 0
	if event.is_action_pressed("ui_left", true):
		step = -1
	elif event.is_action_pressed("ui_right", true):
		step = 1
	var key := event as InputEventKey
	if step == 0 and key != null and key.pressed:
		match key.physical_keycode:
			KEY_A:
				step = -1
			KEY_D:
				step = 1
	if step != 0:
		vp.set_input_as_handled()
		_move_cursor(step)
		return
	var accept := event.is_action_pressed("ui_accept")
	if key != null and key.pressed and not key.echo and (key.physical_keycode == KEY_E or key.physical_keycode == KEY_J):
		accept = true
	if accept:
		vp.set_input_as_handled()
		take_cursor()
		return
	# Açıkken oyun tuşları (dash, parry...) alta geçmesin.
	if key != null or event is InputEventJoypadButton:
		vp.set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not is_open:
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		var i := _cell_at(motion.position)
		if i >= 0 and i != _cursor:
			_set_cursor(i)
		return
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		var i := _cell_at(button.position)
		if i >= 0:
			if i == _cursor:
				take_cursor()  # seçiliye ikinci tıklama: al
			else:
				_set_cursor(i)
		elif not PANEL.has_point(button.position):
			close()
		accept_event()


func _cell_at(pos: Vector2) -> int:
	for i in _rects.size():
		if _rects[i].grow(GAP * 0.5).has_point(pos):
			return i
	return -1


func _set_cursor(i: int) -> void:
	if i == _cursor:
		return
	_cursor = i
	Sfx.play("ui_move", -8.0, 1.0, 0.03)


func _move_cursor(step: int) -> void:
	if _rects.size() < 2:
		return
	_set_cursor(posmod(_cursor + step, _rects.size()))


# ---------------------------------------------------------------- işlem

## İmlecin üstündeki eşyayı alır; diğeri Gölge'ye gider. Başarılıysa menü kapanır ve true döner.
func take_cursor() -> bool:
	if not is_open or choice == null or player == null:
		return false
	if cursor_item() == null:
		return false
	var reason := choice.take(player, _cursor)
	if reason != "":
		_say(reason, false)
		Sfx.play("ui_deny", -4.0)
		return false
	close()
	return true


# ---------------------------------------------------------------- çizim

func _draw() -> void:
	if not is_open or choice == null or player == null or not is_instance_valid(player):
		return
	draw_rect(Rect2(0.0, 0.0, _w(), _h()), Color(0.0, 0.0, 0.03, 0.78))
	ItemView.draw_panel(self, PANEL)
	GameFont.draw_left(self, "ÖDÜL", Vector2(PANEL.position.x + 34.0, PANEL.position.y + 40.0), 40, GameFont.YELLOW)
	GameFont.draw_left(self, "GÖLGE YENİLDİ. BİRİNİ SEÇ; SEÇMEDİĞİN GÖLGE'NİN OLUR.", Vector2(PANEL.position.x + 34.0, PANEL.position.y + 70.0), 15, Color(ItemView.DIM, 0.9), false)
	for i in _rects.size():
		_draw_option(i)
	var focused := cursor_item()
	ItemView.draw_detail(self, DETAIL, focused, "", 0)
	_draw_action_hint()
	if focused != null:
		_draw_cost(focused)
	if _msg != choice.why_not(player, _cursor):  # engel zaten sağ altta yazıyor; aynısını ikinci kez gösterme
		_draw_message(Vector2(GRID_CENTER_X, PANEL.end.y - 70.0), 640.0)
	GameFont.draw_centered(self, "SOL / SAĞ GEZİN     ENTER AL     ESC KAPAT (SONRA SEÇ)", Vector2(PANEL.get_center().x, PANEL.end.y - 26.0), 15, Color(ItemView.DIM, 0.85), false)


func _draw_option(i: int) -> void:
	var item := choice.items[i]
	var r := _rects[i]
	var c := item.color()
	draw_circle(r.get_center(), CELL * 0.78, Color(c, 0.07))
	ItemView.draw_cell(self, r, item, 1, i == _cursor, _t)
	var y := r.end.y + 26.0
	for line in GameFont.wrap(item.upper_name(), 20, CELL + GAP - 12.0):
		GameFont.draw_centered(self, line, Vector2(r.get_center().x, y), 20, c)
		y += 24.0
	GameFont.draw_runs_centered(self, [[item.rarity_name(), c], ["   " + item.slot_name(), ItemView.DIM]], Vector2(r.get_center().x, y + 4.0), 15, 1.0, false)


## Ayrıntı panelinin altında: ne yapılacağı ya da neden yapılamayacağı.
func _draw_action_hint() -> void:
	var reason := choice.why_not(player, _cursor)
	var text := "ENTER  AL"
	var col := GameFont.YELLOW
	if reason != "":
		text = reason
		col = Color(1.0, 0.45, 0.45)
	GameFont.draw_centered(self, text, Vector2(DETAIL.get_center().x, DETAIL.end.y + 22.0), 20, col)


## Seçimin bedeli: odaklı eşyayı alırsan Gölge'ye ne gider.
func _draw_cost(focused: ItemData) -> void:
	var x := PANEL.position.x + 34.0
	var w := 740.0
	var y := COST_TOP
	draw_rect(Rect2(x - 12.0, y - 30.0, w + 24.0, 120.0), Color(0.2, 0.1, 0.32, 0.45))
	draw_rect(Rect2(x - 12.0, y - 30.0, w + 24.0, 120.0), Color(ItemView.SHADOW, 0.5), false, 1.0)
	var others: Array[ItemData] = []
	for it in choice.items:
		if it != focused:
			others.append(it)
	if others.is_empty():
		GameFont.draw_left(self, "BUNU ALIRSAN GÖLGE'YE BİR ŞEY KALMAZ", Vector2(x, y), 17, Color(ItemView.SHADOW, 0.9))
		return
	for other in others:
		GameFont.draw_runs_left(self, [["BUNU ALIRSAN GÖLGE ALIR:  ", ItemView.SHADOW], [other.upper_name(), other.color()]], Vector2(x, y), 18)
		y += 28.0
		var text := other.shadow_text
		if not other.umbra_allowed:
			text = "Bu eşya Gölge'ye gitmez; yok olur."
		elif text == "":
			text = "Gölge bu eşyayı alır."
		for line in GameFont.wrap(text, 16, w):
			GameFont.draw_left(self, line, Vector2(x, y), 16, Color(ItemView.SHADOW, 0.92))
			y += 22.0
