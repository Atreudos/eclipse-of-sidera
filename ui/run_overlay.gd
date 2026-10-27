class_name RunOverlay
extends Control
## Koşu bilgileri, oyunun fontuyla (AGENTORANGE): oda numarası, dalga, "ilerle" oku, ölüm özeti.
## Gerçek zamanla akar (hitstop sırasında da düzgün görünür).
##
## Yazı tipinde ok ve "·" karakterleri yok; oklar çizgiyle çizilir.

const MARGIN_RIGHT := 112.0

## Ekranda görünen oda numarası (1'den başlar). 0 = oda sistemi yok (test arenası).
var room_number := 0
## Test arenasındaki sonsuz dalga sayacı (oda yokken kullanılır).
var arena_wave := 0
var wave := 0
var wave_total := 0
## Oda temizlendi: sağa ilerle okunu göster.
var cleared := false
var dead := false
## Deneme (god) modu açık: üstte rozet gösterilir.
var god_mode := false
## Altın miktarı (sağ üstte).
var gold := 0
## Zaman durdu: kalan oran (0 = durmuyor). Üstte ince bir çubuk çizilir.
var time_stop_k := 0.0
## Etkin durumların kısa satırları ("YORGUN 4.2"), sol üstte.
var statuses: Array[String] = []
## Takılı eşyalar (sol altta küçük simgeler).
var equipped: Array = []
## Ölüm özeti: kills, rooms_cleared, best_combo, time
var summary := {}

var _t := 0.0
var _dead_t := 0.0
var _last_usec := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := 0.0
	if _last_usec != 0:
		dt = clampf(float(now - _last_usec) / 1000000.0, 0.0, 0.05)
	_last_usec = now
	_t += dt
	if dead:
		_dead_t += dt
	else:
		_dead_t = 0.0
	queue_redraw()


func _w() -> float:
	return size.x if size.x > 1.0 else 1280.0


func _h() -> float:
	return size.y if size.y > 1.0 else 720.0


func _draw() -> void:
	var w := _w()
	var h := _h()
	if room_number > 0:
		GameFont.draw_runs_centered(self, [["ODA ", GameFont.WHITE], [str(room_number), GameFont.YELLOW]], Vector2(w - MARGIN_RIGHT, 44.0), 38)
		if wave_total > 1 and not cleared:
			var shown := clampi(wave, 1, wave_total)
			GameFont.draw_runs_centered(self, [["DALGA ", GameFont.WHITE], [str(shown), GameFont.YELLOW], ["/%d" % wave_total, GameFont.WHITE]], Vector2(w - MARGIN_RIGHT, 84.0), 22)
	elif arena_wave > 0:
		GameFont.draw_runs_centered(self, [["DALGA ", GameFont.WHITE], [str(arena_wave), GameFont.YELLOW]], Vector2(w - MARGIN_RIGHT, 44.0), 30)
	if god_mode and not dead:
		var pulse := 0.7 + 0.3 * sin(_t * 3.0)
		GameFont.draw_runs_centered(self, [["DENEME MODU", GameFont.YELLOW]], Vector2(w * 0.5, 28.0), 24, pulse)
	if not dead:
		_draw_hud_extras(w, h)
	if cleared and not dead:
		_draw_go_hint(w, h)
	if dead:
		_draw_death(w, h)


## Altın, zaman durdu çubuğu, durumlar ve takılı eşya simgeleri.
func _draw_hud_extras(w: float, h: float) -> void:
	if room_number > 0 or arena_wave > 0:
		var gy := 126.0 if room_number > 0 and wave_total > 1 and not cleared else 96.0
		var gx := w - MARGIN_RIGHT
		draw_circle(Vector2(gx - 62.0, gy), 9.0, Color(0.55, 0.36, 0.05))
		draw_circle(Vector2(gx - 62.0, gy), 7.5, Color(1.0, 0.82, 0.2))
		GameFont.draw_runs_centered(self, [[str(gold), GameFont.YELLOW]], Vector2(gx + 6.0, gy), 26)
	if time_stop_k > 0.0:
		var bw := 260.0
		var bx := w * 0.5 - bw * 0.5
		GameFont.draw_runs_centered(self, [["ZAMAN DURDU", Color(0.75, 0.92, 1.0)]], Vector2(w * 0.5, 62.0), 24)
		draw_rect(Rect2(bx, 80.0, bw, 6.0), Color(0.05, 0.08, 0.2, 0.7))
		draw_rect(Rect2(bx, 80.0, bw * time_stop_k, 6.0), Color(0.75, 0.92, 1.0))
	var sy := 150.0
	for line in statuses:
		GameFont.draw_left(self, line, Vector2(24.0, sy), 18, GameFont.WHITE)
		sy += 22.0
	var ex := 24.0
	for it in equipped:
		var item := it as ItemData
		if item == null:
			continue
		var r := Rect2(ex, h - 76.0, 30.0, 30.0)
		draw_rect(r, Color(0.05, 0.03, 0.09, 0.75))
		draw_rect(r, item.color(), false, 2.0)
		GameFont.draw_centered(self, item.glyph(), r.get_center(), 20, item.color(), false)
		ex += 36.0


## Sağ kenarda nabız gibi atan oklar ve "İLERLE": kapı açık, sağa git.
func _draw_go_hint(w: float, h: float) -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	var cy := h * 0.5
	var base_x := w - 86.0
	for i in 3:
		var phase := sin(_t * 6.0 - float(i) * 0.9)
		var a := 0.2 + 0.8 * maxf(phase, 0.0)
		var cx := base_x + float(i) * 22.0
		var pts := PackedVector2Array([Vector2(cx - 10.0, cy - 20.0), Vector2(cx + 10.0, cy), Vector2(cx - 10.0, cy + 20.0)])
		draw_polyline(pts, Color(0.05, 0.03, 0.09, a * 0.85), 12.0, true)
		draw_polyline(pts, Color(GameFont.YELLOW, a), 6.0, true)
	GameFont.draw_centered(self, "İLERLE", Vector2(w - 108.0, cy - 52.0 - 4.0 * pulse), 26, Color(GameFont.YELLOW, 0.75 + 0.25 * pulse))


func _draw_death(w: float, h: float) -> void:
	var k := clampf(_dead_t / 0.6, 0.0, 1.0)
	draw_rect(Rect2(0.0, 0.0, w, h), Color(0.03, 0.01, 0.06, 0.72 * k))
	# Başlık pat diye büyüyüp yerine oturur.
	var pop := clampf(_dead_t / 0.25, 0.0, 1.0)
	var s := lerpf(1.6, 1.0, 1.0 - pow(1.0 - pop, 3.0))
	draw_set_transform(Vector2(w * 0.5, h * 0.3), 0.0, Vector2(s, s))
	GameFont.draw_centered(self, "ÖLDÜN", Vector2.ZERO, 112, Color(GameFont.YELLOW, k))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not summary.is_empty():
		var rows: Array = [
			[["ULAŞILAN ODA ", GameFont.WHITE], [str(int(summary.get("room", 1))), GameFont.YELLOW]],
			[["TEMİZLENEN ODA ", GameFont.WHITE], [str(int(summary.get("rooms_cleared", 0))), GameFont.YELLOW]],
			[["ÖLDÜRÜLEN ", GameFont.WHITE], [str(int(summary.get("kills", 0))), GameFont.YELLOW]],
			[["EN İYİ KOMBO ", GameFont.WHITE], [str(int(summary.get("best_combo", 0))), GameFont.YELLOW]],
			[["SÜRE ", GameFont.WHITE], [format_time(float(summary.get("time", 0.0))), GameFont.YELLOW]],
		]
		var y := h * 0.47
		for i in rows.size():
			var row_k := clampf((_dead_t - 0.35 - 0.1 * float(i)) / 0.25, 0.0, 1.0)
			GameFont.draw_runs_centered(self, rows[i], Vector2(w * 0.5, y + 46.0 * float(i)), 30, row_k)
	var blink := 0.65 + 0.35 * sin(_t * 4.0)
	GameFont.draw_runs_centered(self, [["R", GameFont.YELLOW], ["  YENİDEN BAŞLA", GameFont.WHITE]], Vector2(w * 0.5, h * 0.86), 28, clampf((_dead_t - 0.9) / 0.3, 0.0, 1.0) * blink)


## 83.4 -> "1:23"
static func format_time(seconds: float) -> String:
	var total := maxi(int(seconds), 0)
	return "%d:%02d" % [total / 60, total % 60]
