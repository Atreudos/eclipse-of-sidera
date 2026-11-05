class_name SlotsScreen
extends MenuScreen
## Kayıt slotları: üç kart. Dolu kartta ad, zorluk, kaldığımız yer ve süre; boş kartta YENİ OYUN.
## Boş slot -> yeni oyun sihirbazı. Dolu slot -> slot menüsü. Del: kaydı sil (onaylı).

const CARD := Vector2(800.0, 128.0)
const TOP := 136.0
const GAP := 18.0

## Üç eleman: SaveSlot ya da null (boş).
var slots: Array = []
var cursor := 0


func screen_id() -> String:
	return "slots"


func on_enter() -> void:
	_reload()
	cursor = _preferred_cursor()


func on_resume() -> void:
	_reload()


func _reload() -> void:
	slots = SaveStore.list_slots()


## En son oynanan slot; hiç dolu yoksa ilk slot.
func _preferred_cursor() -> int:
	var best := 0
	var best_time := -1
	for i in slots.size():
		var s := slots[i] as SaveSlot
		if s != null and s.last_played > best_time:
			best = i
			best_time = s.last_played
	return best


func slot_at(i: int) -> SaveSlot:
	return slots[i] as SaveSlot if i >= 0 and i < slots.size() else null


func card_rect(i: int) -> Rect2:
	return Rect2(Vector2((MainMenu.W - CARD.x) * 0.5, TOP + float(i) * (CARD.y + GAP)), CARD)


func hint() -> String:
	return "YUKARI / AŞAĞI SEÇ     ENTER AÇ     DEL SİL     ESC GERİ"


func on_action(action: String) -> void:
	match action:
		"up":
			_move(-1)
		"down":
			_move(1)
		"accept":
			open_slot(cursor)
		"delete":
			ask_delete(cursor)
		"back":
			menu.play_move()
			menu.pop()


func _move(step: int) -> void:
	cursor = posmod(cursor + step, SaveStore.COUNT)
	menu.play_move()


func open_slot(i: int) -> void:
	menu.play_select()
	var s := slot_at(i)
	if s == null:
		menu.push(NewGameScreen.new(i))
	else:
		menu.push(SlotMenuScreen.new(s))


func ask_delete(i: int) -> void:
	var s := slot_at(i)
	if s == null:
		menu.play_deny()
		return
	menu.play_select()
	var body := ["SLOT %d  %s" % [i + 1, s.name], "Bu kayıt ve içindeki tüm ilerleme silinir.", "Bu işlem geri alınamaz."]
	menu.push(ConfirmScreen.new("KAYDI SİL", body, "SİL", "VAZGEÇ", _delete.bind(i), true))


func _delete(i: int) -> void:
	SaveStore.delete_slot(i)
	_reload()
	menu.say("SLOT %d SİLİNDİ" % (i + 1))


func on_hover(pos: Vector2) -> void:
	for i in slots.size():
		if card_rect(i).has_point(pos) and cursor != i:
			cursor = i
			menu.play_move()


func on_click(pos: Vector2) -> void:
	for i in slots.size():
		if card_rect(i).has_point(pos):
			cursor = i
			open_slot(i)
			return


func draw(ci: CanvasItem, t: float) -> void:
	GameFont.draw_centered(ci, "KAYIT SEÇ", Vector2(640.0, 60.0), 54, MenuUi.GOLD)
	for i in slots.size():
		_draw_card(ci, i, t)
	var below := card_rect(slots.size() - 1).end.y + 44.0
	GameFont.draw_centered(ci, "Her kayıt ayrı bir profil: rekorların kalır, yarım koşun kaldığın odadan sürer.", Vector2(640.0, below), 17, Color(MenuUi.DIM, 0.85), false)


func _draw_card(ci: CanvasItem, i: int, t: float) -> void:
	var r := card_rect(i)
	var s := slot_at(i)
	var focused := i == cursor
	if not Art.draw_nine(ci, "ui_slot_card_focus" if focused else "ui_slot_card", r, t):
		MenuUi.panel(ci, r)
		if focused:
			MenuUi.focus_frame(ci, r, t)
	var cy := r.get_center().y
	GameFont.draw_centered(ci, str(i + 1), Vector2(r.position.x + 40.0, cy), 60, Color(MenuUi.DIM, 0.45), false)
	if s == null:
		MenuUi.plus(ci, Vector2(r.position.x + 118.0, cy), 26.0, MenuUi.GOLD if focused else MenuUi.DIM, t)
		GameFont.draw_left(ci, "BOŞ KAYIT", Vector2(r.position.x + 178.0, cy - 14.0), 32, MenuUi.WHITE if focused else MenuUi.DIM)
		GameFont.draw_left(ci, "YENİ OYUN BAŞLAT", Vector2(r.position.x + 178.0, cy + 22.0), 18, Color(MenuUi.DIM, 0.8), false)
		return
	MenuUi.difficulty_emblem(ci, s.difficulty, Rect2(r.position.x + 78.0, cy - 40.0, 80.0, 80.0), t)
	MenuUi.fit_left(ci, s.name, Vector2(r.position.x + 176.0, cy - 22.0), 36, 270.0, MenuUi.GOLD)
	GameFont.draw_left(ci, Difficulty.name_of(s.difficulty), Vector2(r.position.x + 176.0, cy + 18.0), 22, MenuUi.difficulty_color(s.difficulty))
	var x := r.position.x + 470.0
	var w := r.end.x - x - 18.0
	for kind in GameMode.count():
		var prog := s.progress_text(kind)
		var runs: Array = [[GameMode.name_of(kind) + "  ", MenuUi.DIM]]
		runs.append([prog if prog != "" else "KOŞU YOK", MenuUi.WHITE if prog != "" else Color(MenuUi.DIM, 0.6)])
		_runs_fit(ci, runs, Vector2(x, cy - 32.0 + float(kind) * 28.0), 19, w)
	_runs_fit(ci, [["SÜRE ", MenuUi.DIM], [SaveSlot.format_playtime(s.playtime), MenuUi.WHITE], ["   SON ", MenuUi.DIM], [SaveSlot.format_date(s.last_played), MenuUi.WHITE]], Vector2(x, cy + 34.0), 15, w)
	if s.recovered:
		var warn := "YEDEKTEN YÜKLENDİ"
		GameFont.draw_left(ci, warn, Vector2(r.end.x - 16.0 - GameFont.width(warn, 13), r.position.y + 16.0), 13, MenuUi.BAD, false)


## Renkli parçalardan satırı `max_width`e sığana kadar küçültüp soldan hizalı çizer.
func _runs_fit(ci: CanvasItem, runs: Array, left_center: Vector2, size: int, max_width: float) -> void:
	var s := size
	while s > 11:
		var total := 0.0
		for run: Array in runs:
			total += GameFont.width(run[0], s)
		if total <= max_width:
			break
		s -= 1
	GameFont.draw_runs_left(ci, runs, left_center, s)
