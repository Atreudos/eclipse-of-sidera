class_name DialogueMenu
extends GameMenu
## Konuşma kutusu: ekranın altında panel, harf harf yazılan metin, seçenekler. Oyunu durdurur.
## E / Enter / Boşluk / J / tık: yazıyı hızlandırır, bitince sonrakine geçer. Yukarı/Aşağı + aynı tuşlar: seçenek. Esc: kapat.

const CPS := 55.0
const PANEL_H := 240.0

var data: Dictionary = {}
var speaker := ""
var node_id := ""
var shown := 0.0
var cursor := 0

var _node: Dictionary = {}
var _choices: Array = []


## Konuşmayı başlatır. Açılamazsa false.
func talk(p: Player, dialogue: Dictionary, who: String = "") -> bool:
	if not open(p):
		return false
	data = dialogue
	speaker = who if who != "" else str(dialogue.get("speaker", ""))
	_goto(str(dialogue.get("start", "")))
	return true


func _goto(id: String) -> void:
	if id == "" or id == "end" or not (data.get("nodes", {}) as Dictionary).has(id):
		close()
		return
	node_id = id
	_node = data["nodes"][id]
	Dialogue.apply_set(str(_node.get("set_before", "")))
	_choices = Dialogue.visible_choices(_node)
	cursor = 0
	shown = 0.0
	if _node.has("speaker"):
		speaker = str(_node["speaker"])
	_give_gift()


## Düğümde `gold` varsa (ve `gold_flag` daha kurulmadıysa) oyuncuya altın verir.
func _give_gift() -> void:
	var g := int(_node.get("gold", 0))
	if g <= 0 or player == null or not is_instance_valid(player):
		return
	var gf := str(_node.get("gold_flag", ""))
	if gf != "" and Story.has(gf):
		return
	player.add_gold(g)
	if gf != "":
		Story.set_flag(gf)
	Sfx.play("coin", -2.0)
	_say("+%d ALTIN" % g, true)


func _text() -> String:
	return str(_node.get("text", ""))


func _typing_done() -> bool:
	return int(shown) >= _text().length()


func _advance() -> void:
	if not _typing_done():
		shown = float(_text().length())
		return
	if not _choices.is_empty():
		var c: Dictionary = _choices[clampi(cursor, 0, _choices.size() - 1)]
		Dialogue.apply_set(str(c.get("set", "")))
		Sfx.play("ui_select", -6.0)
		_goto(str(c.get("next", "end")))
		return
	Dialogue.apply_set(str(_node.get("set", "")))
	_goto(str(_node.get("next", "end")))


func _process(delta: float) -> void:
	super._process(delta)
	if is_open and not _typing_done():
		shown += CPS * clampf(delta, 0.0, 0.05)


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_ESCAPE:
			Dialogue.apply_set(str(_node.get("set", "")) if _typing_done() and _choices.is_empty() else "")
			close()
			get_viewport().set_input_as_handled()
		elif k in [KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_J]:
			_advance()
			get_viewport().set_input_as_handled()
		elif (k == KEY_UP or k == KEY_W) and _typing_done() and _choices.size() > 1:
			cursor = (cursor - 1 + _choices.size()) % _choices.size()
			Sfx.play("ui_move", -8.0)
			get_viewport().set_input_as_handled()
		elif (k == KEY_DOWN or k == KEY_S) and _typing_done() and _choices.size() > 1:
			cursor = (cursor + 1) % _choices.size()
			Sfx.play("ui_move", -8.0)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_advance()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	if not is_open:
		return
	var w := _w()
	var h := _h()
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.35))
	var panel := Rect2(60.0, h - PANEL_H - 30.0, w - 120.0, PANEL_H)
	draw_rect(panel, Color(0.05, 0.04, 0.09, 0.95))
	draw_rect(panel, Color(1.0, 0.76, 0.38, 0.7), false, 2.0)
	_draw_message(Vector2(w * 0.5, panel.position.y - 44.0))
	if speaker != "":
		var tag := Rect2(panel.position.x + 18.0, panel.position.y - 18.0, GameFont.width(speaker, 24) + 28.0, 34.0)
		draw_rect(tag, Color(0.12, 0.08, 0.16))
		draw_rect(tag, Color(1.0, 0.76, 0.38, 0.7), false, 2.0)
		GameFont.draw_centered(self, speaker, tag.get_center(), 24, GameFont.YELLOW)
	var text := _text().substr(0, int(shown))
	var lines := GameFont.wrap(text, 24, panel.size.x - 60.0)
	var y := panel.position.y + 44.0
	for l in lines:
		GameFont.draw_centered(self, l, Vector2(panel.get_center().x, y), 24, GameFont.WHITE)
		y += 30.0
	if _typing_done():
		if _choices.is_empty():
			var a := 0.5 + 0.5 * sin(_t * 6.0)
			GameFont.draw_runs_centered(self, [["E", GameFont.YELLOW], ["  DEVAM", GameFont.WHITE]], Vector2(panel.end.x - 90.0, panel.end.y - 22.0), 18, a)
		else:
			var cy := panel.end.y - 18.0 - 30.0 * _choices.size()
			for i in _choices.size():
				var sel := i == cursor
				var col := GameFont.YELLOW if sel else GameFont.WHITE
				var label := ("> " if sel else "  ") + str((_choices[i] as Dictionary).get("text", ""))
				GameFont.draw_centered(self, label, Vector2(panel.get_center().x, cy + 30.0 * i + 12.0), 22, col)
