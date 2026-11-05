class_name NewGameScreen
extends MenuScreen
## Yeni oyun sihirbazı. 1. adım: kayıt adı (yazılır). 2. adım: zorluk (EASY / NORMAL / DIFFICULT / IMMORTAL).
## Bitince slot oluşturulup yazılır ve slot menüsü açılır. Esc bir önceki adıma döner.

const NAME_FIELD := Rect2(390.0, 300.0, 500.0, 72.0)
const DIFF_TOP := Vector2(330.0, 200.0)
const DIFF_ROW := Vector2(380.0, 70.0)
const DIFF_GAP := 14.0
const DETAIL := Rect2(750.0, 184.0, 470.0, 480.0)
## Zorluk ayrıntısında gösterilen satırlar: [etiket, profil anahtarı, ters mi (küçük = daha sık/zor)].
const FACTS := [
	["DÜŞMAN CANI", "hp", false],
	["DÜŞMAN HASARI", "damage", false],
	["DÜŞMAN HIZI", "speed", false],
	["SALDIRI SIKLIĞI", "cooldown", true],
	["UYARI SÜRESİ", "telegraph", false],
	["ALTIN", "gold", false],
]

var slot_index := 0
## 0 = isim, 1 = zorluk.
var step := 0
var name_text := ""
var level: int = Difficulty.DEFAULT
var _t := 0.0


func _init(index: int) -> void:
	slot_index = index


func screen_id() -> String:
	return "new_game"


func wants_text() -> bool:
	return step == 0


func hint() -> String:
	if step == 0:
		return "ADINI YAZ     ENTER DEVAM     ESC İPTAL"
	return "YUKARI / AŞAĞI SEÇ     ENTER BAŞLAT     ESC GERİ"


func on_tick(dt: float) -> void:
	_t += dt


## Oluşturulacak ismin temiz hâli.
func final_name() -> String:
	return SaveSlot.clean_name(name_text)


func on_char(ch: String) -> void:
	if step != 0:
		return
	if ch == " ":
		if name_text == "" or name_text.ends_with(" "):
			return
	elif not SaveSlot.name_char_ok(ch):
		return
	if name_text.length() >= SaveSlot.NAME_MAX:
		menu.play_deny()
		return
	name_text += GameFont.upper(ch)
	menu.play_move()


func on_action(action: String) -> void:
	if step == 0:
		match action:
			"backspace":
				if name_text != "":
					name_text = name_text.substr(0, name_text.length() - 1)
					menu.play_move()
			"accept":
				step = 1
				menu.play_select()
			"back":
				menu.play_move()
				menu.pop()
		return
	match action:
		"up", "left":
			_pick(level - 1)
		"down", "right":
			_pick(level + 1)
		"accept":
			create()
		"back":
			step = 0
			menu.play_move()


func _pick(i: int) -> void:
	level = posmod(i, Difficulty.count())
	menu.play_move()


## Slotu oluşturur, yazar ve slot menüsüne geçer. Yazılamazsa mesaj gösterir, ekranda kalır.
func create() -> void:
	var s := SaveSlot.create(slot_index, name_text, level)
	if not SaveStore.save_slot(s):
		menu.play_deny()
		menu.say("KAYIT YAZILAMADI", false)
		return
	menu.play_select()
	menu.say("KAYIT OLUŞTURULDU")
	menu.replace(SlotMenuScreen.new(s))


func diff_rect(i: int) -> Rect2:
	return Rect2(DIFF_TOP + Vector2(0.0, float(i) * (DIFF_ROW.y + DIFF_GAP)), DIFF_ROW)


func on_hover(pos: Vector2) -> void:
	if step != 1:
		return
	for i in Difficulty.count():
		if diff_rect(i).has_point(pos) and level != i:
			level = i
			menu.play_move()


func on_click(pos: Vector2) -> void:
	if step != 1:
		return
	for i in Difficulty.count():
		if diff_rect(i).has_point(pos):
			level = i
			create()
			return


func draw(ci: CanvasItem, t: float) -> void:
	GameFont.draw_centered(ci, "YENİ OYUN", Vector2(640.0, 60.0), 54, MenuUi.GOLD)
	GameFont.draw_centered(ci, "KAYIT %d" % (slot_index + 1), Vector2(640.0, 114.0), 20, MenuUi.DIM)
	if step == 0:
		_draw_name(ci, t)
	else:
		_draw_difficulty(ci, t)


func _draw_name(ci: CanvasItem, t: float) -> void:
	GameFont.draw_centered(ci, "KAYDIN ADI", Vector2(640.0, 250.0), 28, MenuUi.WHITE)
	if not Art.draw_nine(ci, "ui_text_field", NAME_FIELD, t):
		MenuUi.panel(ci, NAME_FIELD)
	var cy := NAME_FIELD.get_center().y
	var x := NAME_FIELD.position.x + 26.0
	if name_text == "":
		GameFont.draw_left(ci, SaveSlot.DEFAULT_NAME, Vector2(x, cy), 42, Color(MenuUi.DIM, 0.4), false)
	else:
		GameFont.draw_left(ci, name_text, Vector2(x, cy), 42, MenuUi.GOLD)
	if fmod(_t, 1.0) < 0.62:
		var cx := x + (GameFont.width(name_text, 42) + 5.0 if name_text != "" else 0.0)
		if not Art.draw(ci, "ui_text_cursor", Rect2(cx, cy - 22.0, 8.0, 44.0), _t):
			ci.draw_rect(Rect2(cx, cy - 20.0, 4.0, 40.0), MenuUi.GOLD)
	var counter := "%d/%d" % [name_text.length(), SaveSlot.NAME_MAX]
	GameFont.draw_left(ci, counter, Vector2(NAME_FIELD.end.x - GameFont.width(counter, 15), NAME_FIELD.end.y + 18.0), 15, Color(MenuUi.DIM, 0.8), false)
	GameFont.draw_centered(ci, "Boş bırakırsan SIDERA olur. Harf, rakam ve - . ' kullanabilirsin.", Vector2(640.0, 430.0), 17, Color(MenuUi.DIM, 0.85), false)


func _draw_difficulty(ci: CanvasItem, t: float) -> void:
	MenuUi.fit_centered(ci, final_name(), Vector2(640.0, 152.0), 30, 600.0, MenuUi.WHITE)
	for i in Difficulty.count():
		var r := diff_rect(i)
		var focused := i == level
		if not Art.draw(ci, "ui_menu_button_focus" if focused else "ui_menu_button_normal", r, t, Color.WHITE, true):
			ci.draw_rect(r, Color(0.16, 0.12, 0.3, 0.88) if focused else Color(0.07, 0.055, 0.13, 0.62))
			ci.draw_rect(r, Color(MenuUi.PANEL_EDGE, 0.8), false, 2.0)
			if focused:
				MenuUi.focus_frame(ci, r, t)
		MenuUi.difficulty_emblem(ci, i, Rect2(r.position.x + 12.0, r.position.y + 7.0, 56.0, 56.0), t)
		var col := MenuUi.difficulty_color(i) if focused else MenuUi.WHITE
		GameFont.draw_left(ci, Difficulty.name_of(i), Vector2(r.position.x + 90.0, r.get_center().y - 2.0), 30, col)
		if focused:
			MenuUi.arrow(ci, Vector2(r.position.x - 20.0 + sin(t * 6.0) * 3.0, r.get_center().y), 1, 8.0, MenuUi.GOLD)
	MenuUi.panel(ci, DETAIL)
	var dx := DETAIL.position.x + 26.0
	var dw := DETAIL.size.x - 52.0
	MenuUi.difficulty_emblem(ci, level, Rect2(dx, DETAIL.position.y + 22.0, 96.0, 96.0), t)
	GameFont.draw_left(ci, Difficulty.name_of(level), Vector2(dx + 116.0, DETAIL.position.y + 70.0), 40, MenuUi.difficulty_color(level))
	var y := DETAIL.position.y + 150.0
	for line in GameFont.wrap(Difficulty.blurb_of(level), 18, dw):
		GameFont.draw_left(ci, line, Vector2(dx, y), 18, MenuUi.WHITE)
		y += 25.0
	y = maxf(y + 14.0, DETAIL.position.y + 296.0)
	var prof := Difficulty.profile(level)
	for f: Array in FACTS:
		var v := float(prof.get(f[1], 1.0))
		if bool(f[2]):
			v = 1.0 / maxf(v, 0.01)
		GameFont.draw_left(ci, String(f[0]), Vector2(dx, y), 17, MenuUi.DIM)
		var harder := v > 1.001
		var easier := v < 0.999
		# Telegraph (uyarı süresi) için büyük sayı KOLAYDIR; diğerlerinde büyük sayı zordur.
		if f[1] == "telegraph":
			var tmp := harder
			harder = easier
			easier = tmp
		var c := MenuUi.BAD if harder else (MenuUi.GOOD if easier else MenuUi.WHITE)
		var txt := ratio_text(v)
		GameFont.draw_left(ci, txt, Vector2(dx + dw - GameFont.width(txt, 20), y), 20, c)
		y += 28.0


## 1.35 -> "x1.35", 1.0 -> "x1", 0.75 -> "x0.75"
static func ratio_text(v: float) -> String:
	var s := ("%.2f" % v).rstrip("0").rstrip(".")
	return "x" + s
