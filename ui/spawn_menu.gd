class_name SpawnMenu
extends GameMenu
## F8 yaratık çağırma menüsü (demo / deneme): bir yaratık seç, Enter ile önüne çağır. Menü açık kalır, istediğin kadar çağırırsın.
## K ya da F6: odadaki herkesi öldür ve odayı temizle. F8 / Esc kapatır.

signal spawn_requested(scene_path: String)
signal kill_requested

const PANEL := Rect2(340.0, 60.0, 600.0, 600.0)
const ROW_H := 36.0
## [görünen ad, sahne yolu]
const ENTRIES := [
	["Boğa (Taurus)", "res://actors/enemies/taurus.tscn"],
	["Yay (Sagitta)", "res://actors/enemies/sagitta.tscn"],
	["Akrep (Scorpius)", "res://actors/enemies/scorpius.tscn"],
	["Koç (Aries)", "res://actors/enemies/aries.tscn"],
	["Yengeç (Cancer)", "res://actors/enemies/cancer.tscn"],
	["İkizler (Gemini)", "res://actors/enemies/gemini.tscn"],
	["Aslan (Leo)", "res://actors/enemies/leo.tscn"],
	["Terazi (Libra)", "res://actors/enemies/libra.tscn"],
	["Kova (Aquarius)", "res://actors/enemies/aquarius.tscn"],
	["Gölge Minyonu", "res://actors/enemies/umbra_minion.tscn"],
	["Gölge (Umbra, patron)", "res://actors/enemies/umbra.tscn"],
]

var _sel := 0
var _count := 0


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	var f8 := key != null and key.pressed and not key.echo and key.physical_keycode == KEY_F8
	if not is_open:
		if f8 and open(_find_player()):
			get_viewport().set_input_as_handled()
		return
	if f8 or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	if key != null and key.pressed:
		match key.physical_keycode:
			KEY_UP, KEY_W:
				_sel = (_sel - 1 + ENTRIES.size()) % ENTRIES.size()
				Sfx.play("ui_move", -8.0)
			KEY_DOWN, KEY_S:
				_sel = (_sel + 1) % ENTRIES.size()
				Sfx.play("ui_move", -8.0)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E, KEY_J:
				if not key.echo:
					request_spawn(_sel)
			KEY_K, KEY_F6:
				if not key.echo:
					kill_requested.emit()
					_say("ODADAKİ HERKES ÖLDÜ", true)
					Sfx.play("kill", -4.0)
	if key != null:
		get_viewport().set_input_as_handled()


## `index`. yaratığı çağırır (testler de kullanır).
func request_spawn(index: int) -> void:
	if index < 0 or index >= ENTRIES.size():
		return
	_count += 1
	spawn_requested.emit(str((ENTRIES[index] as Array)[1]))
	_say("ÇAĞRILDI  " + GameFont.upper(str((ENTRIES[index] as Array)[0])), true)
	Sfx.play("spawn", -6.0)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var row := int((mb.position.y - (PANEL.position.y + 80.0)) / ROW_H)
	if row >= 0 and row < ENTRIES.size() and PANEL.has_point(mb.position):
		_sel = row
		request_spawn(row)
		accept_event()


func _draw() -> void:
	if not is_open:
		return
	draw_rect(Rect2(0.0, 0.0, _w(), _h()), Color(0.0, 0.0, 0.03, 0.7))
	ItemView.draw_panel(self, PANEL)
	GameFont.draw_centered(self, "YARATIK ÇAĞIR", Vector2(PANEL.get_center().x, PANEL.position.y + 36.0), 34, GameFont.YELLOW)
	for i in ENTRIES.size():
		var y := PANEL.position.y + 80.0 + float(i) * ROW_H
		var sel := i == _sel
		if sel:
			draw_rect(Rect2(PANEL.position.x + 24.0, y, PANEL.size.x - 48.0, ROW_H - 4.0), Color(1.0, 0.76, 0.38, 0.16))
		GameFont.draw_left(self, ("> " if sel else "  ") + str((ENTRIES[i] as Array)[0]), Vector2(PANEL.position.x + 44.0, y + ROW_H * 0.5 - 2.0), 24, GameFont.YELLOW if sel else GameFont.WHITE)
	_draw_message(Vector2(PANEL.get_center().x, PANEL.end.y - 78.0), PANEL.size.x - 40.0)
	GameFont.draw_centered(self, "ENTER ÇAĞIR (MENÜ AÇIK KALIR)    K / F6 ODAYI TEMİZLE", Vector2(PANEL.get_center().x, PANEL.end.y - 44.0), 16, Color(ItemView.DIM, 0.95), false)
	GameFont.draw_centered(self, "W/S GEZİN    F8 / ESC KAPAT", Vector2(PANEL.get_center().x, PANEL.end.y - 22.0), 16, Color(ItemView.DIM, 0.95), false)
