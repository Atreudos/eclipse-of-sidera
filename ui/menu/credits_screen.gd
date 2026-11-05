class_name CreditsScreen
extends MenuScreen
## Krediler: yukarı doğru kayan yazı. Aşağıdaki LINES listesini istediğin gibi düzenle.
## Satır: [tür, yazı]. Türler: "title" büyük başlık, "role" küçük soluk başlık, "name" isim, "note" açıklama, "gap" boşluk.

const LINES: Array = [
	["title", "ECLIPSE OF SIDERA"],
	["note", "PARRY, DASH VE EŞYA ODAKLI AKSİYON ROGUELİTE"],
	["gap", ""],
	["role", "OYUN FİKRİ, TASARIM VE ÇİZİMLER"],
	["name", "(ADINI BURAYA YAZ)"],
	["gap", ""],
	["role", "KODLAMA"],
	["name", "CLAUDE (ANTHROPIC)"],
	["gap", ""],
	["role", "YAZI TİPİ"],
	["name", "AGENTORANGE"],
	["gap", ""],
	["role", "OYUN MOTORU"],
	["name", "GODOT 4"],
	["gap", ""],
	["role", "SES EFEKTLERİ"],
	["name", "KODLA ÜRETİLDİ"],
	["gap", ""],
	["role", "DÜŞMANLAR"],
	["name", "TAURUS   SAGITTA   SCORPIUS"],
	["gap", ""],
	["role", "VE GÖLGESİ"],
	["name", "UMBRA"],
	["gap", ""],
	["role", "ÖZEL TEŞEKKÜR"],
	["name", "OYNADIĞIN İÇİN"],
	["gap", ""],
	["title", "TEŞEKKÜRLER"],
]
const SPEED := 46.0
const HEIGHTS := {"title": 96.0, "role": 40.0, "name": 52.0, "note": 36.0, "gap": 44.0}
const SIZES := {"title": 60, "role": 20, "name": 32, "note": 18}

var offset := 0.0


func screen_id() -> String:
	return "credits"


## Alt ipucu satırı kayan yazının üstüne bindiği için kredilerde sabit küçük bir etiket kullanılır (sol üst).
func hint() -> String:
	return ""


func content_height() -> float:
	var h := 0.0
	for l in LINES:
		h += float(HEIGHTS.get(l[0], 40.0))
	return h


func on_tick(dt: float) -> void:
	offset += SPEED * dt
	if offset > content_height() + MainMenu.H + 40.0:
		offset = 0.0


func on_action(action: String) -> void:
	match action:
		"up":
			offset = maxf(offset - 90.0, 0.0)
		"down":
			offset += 90.0
		"accept", "back":
			menu.play_move()
			menu.pop()


func on_click(_pos: Vector2) -> void:
	menu.play_move()
	menu.pop()


func draw(ci: CanvasItem, t: float) -> void:
	Art.draw(ci, "ui_credits_bg", Rect2(0.0, 0.0, MainMenu.W, MainMenu.H), t, Color.WHITE, true)
	var y := MainMenu.H - offset
	for l in LINES:
		var kind: String = l[0]
		var h := float(HEIGHTS.get(kind, 40.0))
		if kind != "gap" and y > -60.0 and y < MainMenu.H + 60.0:
			var color := MenuUi.WHITE
			match kind:
				"title":
					color = MenuUi.GOLD
				"role":
					color = Color(MenuUi.DIM, 0.9)
				"note":
					color = Color(MenuUi.DIM, 0.8)
			MenuUi.fit_centered(ci, l[1], Vector2(MainMenu.W * 0.5, y + h * 0.5), int(SIZES.get(kind, 24)), 900.0, color)
		y += h
	# Alttan giren yazı yumuşakça belirsin.
	for i in 10:
		var k := float(i) / 9.0
		ci.draw_rect(Rect2(0.0, MainMenu.H - 100.0 + float(i) * 10.0, MainMenu.W, 10.0), Color(MenuUi.BG, 0.95 * (1.0 - k)))
	GameFont.draw_left(ci, "ESC GERİ     YUKARI / AŞAĞI KAYDIR", Vector2(28.0, 30.0), 16, Color(MenuUi.DIM, 0.85), false)
