class_name SlotMenuScreen
extends MenuScreen
## Bir kaydın menüsü: sol panelde ad, zorluk, rekorlar ve süre; sağda kipler (NORMAL, SINIRSIZ), zorluk, sil, geri.
## Yarım kalmış koşu varsa o kipte DEVAM (kaldığın yer yazar) ve YENİ KOŞU (onaylı) görünür, yoksa BAŞLA.
## Zorluk yalnızca yarım koşu yokken değişir (koşunun ortasında düşmanlar değişmesin).

const INFO := Rect2(60.0, 130.0, 480.0, 520.0)
const LIST_TOP := Vector2(900.0, 150.0)
const ROW := Vector2(440.0, 50.0)
const BLURB := Rect2(680.0, 575.0, 520.0, 80.0)

var slot: SaveSlot
var list := MenuList.new()


func _init(s: SaveSlot) -> void:
	slot = s


func screen_id() -> String:
	return "slot"


func on_enter() -> void:
	_rebuild()


## Alttaki ekrandan dönünce slotu diskten tazeler (silinmişse ekrandan çıkar).
func on_resume() -> void:
	var fresh := SaveStore.load_slot(slot.index)
	if fresh == null:
		menu.pop()
		return
	slot = fresh
	_rebuild()


func hint() -> String:
	return "YUKARI / AŞAĞI SEÇ     ENTER ONAYLA     SOL / SAĞ ZORLUK     ESC GERİ"


func has_any_run() -> bool:
	for kind in GameMode.count():
		if slot.has_run(kind):
			return true
	return false


func _rebuild() -> void:
	var keep := list.current_id()
	list.clear()
	list.top_center = LIST_TOP
	list.row_size = ROW
	list.font_size = 26
	list.centered = false
	for kind in GameMode.count():
		var tag := "endless" if kind == GameMode.Kind.ENDLESS else "normal"
		var playable := SceneRouter.can_play(kind)
		var mode_name := GameMode.name_of(kind)
		if slot.has_run(kind):
			list.add("play_" + tag, mode_name + "  DEVAM", playable, slot.progress_text(kind) if playable else "YAKINDA")
			list.add("new_" + tag, mode_name + "  YENİ KOŞU", playable)
		else:
			list.add("play_" + tag, mode_name + "  BAŞLA", playable, "" if playable else "YAKINDA")
	list.add("difficulty", "ZORLUK")
	list.add("delete", "KAYDI SİL")
	list.add("back", "GERİ")
	if keep != "":
		list.focus(keep)


func on_action(action: String) -> void:
	match action:
		"up":
			if list.move(-1):
				menu.play_move()
		"down":
			if list.move(1):
				menu.play_move()
		"left":
			if list.current_id() == "difficulty":
				change_difficulty(-1)
		"right":
			if list.current_id() == "difficulty":
				change_difficulty(1)
		"accept":
			activate()
		"delete":
			ask_delete()
		"back":
			menu.play_move()
			menu.pop()


## Şu anki satırı çalıştırır.
func activate() -> void:
	var id := list.current_id()
	if not list.current_enabled():
		menu.play_deny()
		menu.say("BU KİP HENÜZ HAZIR DEĞİL", false)
		return
	match id:
		"play_normal":
			play(GameMode.Kind.NORMAL)
		"new_normal":
			ask_new_run(GameMode.Kind.NORMAL)
		"play_endless":
			play(GameMode.Kind.ENDLESS)
		"new_endless":
			ask_new_run(GameMode.Kind.ENDLESS)
		"difficulty":
			change_difficulty(1)
		"delete":
			ask_delete()
		"back":
			menu.play_move()
			menu.pop()


## Kipte oyuna girer: yarım koşu varsa onu sürdürür, yoksa yenisini başlatır.
func play(kind: int) -> void:
	menu.play_select()
	if not menu.start_game(slot, kind, true):
		menu.play_deny()
		menu.say("OYUN BAŞLATILAMADI", false)


func ask_new_run(kind: int) -> void:
	menu.play_select()
	var body := ["Yarım kalan koşun (%s) silinip baştan başlanacak." % slot.progress_text(kind), "Rekorların ve kaydın kalır."]
	menu.push(ConfirmScreen.new("YENİ KOŞU", body, "BAŞLA", "VAZGEÇ", _start_fresh.bind(kind), true))


func _start_fresh(kind: int) -> void:
	slot.clear_run(kind)
	SaveStore.save_slot(slot)
	_rebuild()
	if not menu.start_game(slot, kind, false):
		menu.say("OYUN BAŞLATILAMADI", false)


func ask_delete() -> void:
	menu.play_select()
	var body := ["KAYIT %d  %s" % [slot.index + 1, slot.name], "Bu kayıt ve içindeki tüm ilerleme silinir.", "Bu işlem geri alınamaz."]
	menu.push(ConfirmScreen.new("KAYDI SİL", body, "SİL", "VAZGEÇ", _delete_slot, true))


func _delete_slot() -> void:
	SaveStore.delete_slot(slot.index)
	menu.pop()
	menu.say("KAYIT SİLİNDİ")


## Zorluğu değiştirir (yalnızca yarım koşu yokken). Slot hemen yazılır.
func change_difficulty(step: int) -> void:
	if has_any_run():
		menu.play_deny()
		menu.say("YARIM KOŞU VARKEN ZORLUK DEĞİŞMEZ", false)
		return
	slot.difficulty = posmod(slot.difficulty + step, Difficulty.count())
	SaveStore.save_slot(slot)
	menu.play_move()
	_rebuild()


func on_hover(pos: Vector2) -> void:
	var i := list.index_at(pos)
	if i >= 0 and list.set_cursor(i):
		menu.play_move()


func on_click(pos: Vector2) -> void:
	var i := list.index_at(pos)
	if i < 0:
		return
	list.set_cursor(i)
	activate()


func draw(ci: CanvasItem, t: float) -> void:
	_draw_info(ci, t)
	list.draw(ci, t)
	_draw_difficulty_row(ci)
	var blurb := _focus_blurb()
	if blurb != "":
		var y := BLURB.position.y + 14.0
		for line in GameFont.wrap(blurb, 16, BLURB.size.x):
			GameFont.draw_left(ci, line, Vector2(BLURB.position.x, y), 16, Color(MenuUi.DIM, 0.95), false)
			y += 22.0


func _focus_blurb() -> String:
	match list.current_id():
		"play_normal", "new_normal":
			return GameMode.blurb_of(GameMode.Kind.NORMAL)
		"play_endless", "new_endless":
			return GameMode.blurb_of(GameMode.Kind.ENDLESS)
		"difficulty":
			if has_any_run():
				return "Zorluk yalnızca yarım kalan koşun yokken değişir."
			return Difficulty.blurb_of(slot.difficulty)
		"delete":
			return "Bu kaydı ve tüm ilerlemeyi siler."
	return ""


## ZORLUK satırının sağına ok ve seçili zorluğun adı.
func _draw_difficulty_row(ci: CanvasItem) -> void:
	var i := list.index_of("difficulty")
	if i < 0:
		return
	var r := list.rect_of(i)
	var name := Difficulty.name_of(slot.difficulty)
	var color := MenuUi.difficulty_color(slot.difficulty)
	var nw := GameFont.width(name, 22)
	var locked := has_any_run()
	var right := r.end.x - 16.0
	if locked:
		GameFont.draw_left(ci, name, Vector2(right - nw, r.get_center().y - 8.0), 22, Color(color, 0.55))
		var tag := "KİLİTLİ"
		GameFont.draw_left(ci, tag, Vector2(right - GameFont.width(tag, 11), r.get_center().y + 12.0), 11, Color(MenuUi.DIM, 0.8), false)
		return
	MenuUi.arrow(ci, Vector2(right - 7.0, r.get_center().y), 1, 7.0, color)
	var nx := right - 7.0 - 8.0 - nw
	GameFont.draw_left(ci, name, Vector2(nx, r.get_center().y), 22, color)
	MenuUi.arrow(ci, Vector2(nx - 15.0, r.get_center().y), -1, 7.0, color)


func _draw_info(ci: CanvasItem, t: float) -> void:
	MenuUi.panel(ci, INFO)
	var x := INFO.position.x + 30.0
	var w := INFO.size.x - 60.0
	var top := INFO.position.y
	MenuUi.fit_left(ci, slot.name, Vector2(x, top + 44.0), 46, w, MenuUi.GOLD)
	GameFont.draw_left(ci, "KAYIT %d" % (slot.index + 1), Vector2(x, top + 86.0), 14, Color(MenuUi.DIM, 0.8), false)
	MenuUi.difficulty_emblem(ci, slot.difficulty, Rect2(x, top + 106.0, 70.0, 70.0), t)
	GameFont.draw_left(ci, Difficulty.name_of(slot.difficulty), Vector2(x + 90.0, top + 141.0), 30, MenuUi.difficulty_color(slot.difficulty))
	var y := top + 204.0
	for line in GameFont.wrap(Difficulty.blurb_of(slot.difficulty), 15, w):
		GameFont.draw_left(ci, line, Vector2(x, y), 15, Color(MenuUi.DIM, 0.9), false)
		y += 20.0
	var rec := slot.records
	var rows: Array = []
	var nb := slot.best_text(GameMode.Kind.NORMAL)
	var eb := slot.best_text(GameMode.Kind.ENDLESS)
	rows.append([["NORMAL  ", MenuUi.DIM], [nb if nb != "" else "HENÜZ YOK", MenuUi.WHITE if nb != "" else Color(MenuUi.DIM, 0.6)]])
	rows.append([["SINIRSIZ  ", MenuUi.DIM], [eb if eb != "" else "HENÜZ YOK", MenuUi.WHITE if eb != "" else Color(MenuUi.DIM, 0.6)]])
	rows.append([["KOŞU ", MenuUi.DIM], [str(rec["runs"]), MenuUi.GOLD], ["    ÖLÜM ", MenuUi.DIM], [str(rec["deaths"]), MenuUi.GOLD]])
	rows.append([["ÖLDÜRÜLEN ", MenuUi.DIM], [str(rec["kills"]), MenuUi.GOLD]])
	rows.append([["EN İYİ KOMBO ", MenuUi.DIM], [str(rec["best_combo"]), MenuUi.GOLD]])
	rows.append([["SÜRE ", MenuUi.DIM], [SaveSlot.format_playtime(slot.playtime), MenuUi.GOLD]])
	rows.append([["SON OYNANAN ", MenuUi.DIM], [SaveSlot.format_date(slot.last_played), MenuUi.WHITE]])
	y = top + 308.0
	for row: Array in rows:
		GameFont.draw_runs_left(ci, row, Vector2(x, y), 20)
		y += 29.0
	if slot.recovered:
		GameFont.draw_left(ci, "YEDEKTEN YÜKLENDİ", Vector2(x, INFO.end.y - 22.0), 14, MenuUi.BAD, false)
