class_name WeaponBar
extends Control
## Ekranın altında ortada iki silah kartı: J ve I slotundaki silahın adı, seviyesi (5 kutucuk) ve menzilli silahın soğuması.
## Oyuncunun `loadout`'unu okur; silah değişince/yükselince kendiliğinden güncellenir. Simge `item_weapon_<id>.png`
## (çizim listesindeki ad) ya da eski `assets/items/weapon_<id>.png` varsa kartta o çizilir (yoksa yalnız ad). Gerçek zamanla akar (hitstop sırasında da düzgün görünür).

const CARD_SIZE := Vector2(196.0, 50.0)
const GAP := 12.0
const BOTTOM := 48.0

var player: Player

var _t := 0.0
var _last_usec := 0
## Son karede her slotun silahı ve seviyesi: değişince kartta kısa bir parlama olur.
var _seen: Array = ["", ""]
var _seen_level: Array = [0, 0]
var _flash: Array[float] = [0.0, 0.0]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := 0.0
	if _last_usec != 0:
		dt = clampf(float(now - _last_usec) / 1000000.0, 0.0, 0.05)
	_last_usec = now
	_t += dt
	for i in _flash.size():
		_flash[i] = maxf(_flash[i] - dt * 2.5, 0.0)
	if player != null and is_instance_valid(player) and player.loadout != null:
		for i in WeaponDB.SLOT_COUNT:
			var id := player.weapon_in(i)
			var lv := player.loadout.level_of(id)
			if id != _seen[i] or lv != _seen_level[i]:
				if _seen[i] != "" or _seen_level[i] != 0:
					_flash[i] = 1.0
				_seen[i] = id
				_seen_level[i] = lv
	queue_redraw()


## Kartın yeri (slot 0 solda, 1 sağda; ekranın altında ortalı).
func card_rect(slot: int) -> Rect2:
	var w := size.x if size.x > 1.0 else 1280.0
	var h := size.y if size.y > 1.0 else 720.0
	var total := CARD_SIZE.x * float(WeaponDB.SLOT_COUNT) + GAP * float(WeaponDB.SLOT_COUNT - 1)
	var x0 := (w - total) * 0.5
	return Rect2(Vector2(x0 + float(slot) * (CARD_SIZE.x + GAP), h - BOTTOM - CARD_SIZE.y), CARD_SIZE)


func _draw() -> void:
	if player == null or not is_instance_valid(player) or player.loadout == null or player.dead:
		return
	for slot in WeaponDB.SLOT_COUNT:
		_draw_card(slot)


func _draw_card(slot: int) -> void:
	var r := card_rect(slot)
	var id := player.weapon_in(slot)
	var cd := player.weapon_cooldown_k(slot)
	var col := WeaponDB.color(id) if id != "" else ItemView.CELL_EDGE
	draw_rect(r, Color(0.05, 0.03, 0.09, 0.8))
	draw_rect(r.grow(-2.0), Color(col, 0.1))
	# soğuma: kartın üstünden aşağı doğru kararan perde + alt çizgi
	if cd > 0.0:
		draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * cd)), Color(0.0, 0.0, 0.0, 0.5))
	var ready := cd <= 0.0
	draw_rect(r, Color(col, 0.95 if ready else 0.45), false, 2.0)
	if _flash[slot] > 0.0:
		draw_rect(r.grow(2.0 + 3.0 * _flash[slot]), Color(GameFont.YELLOW, 0.8 * _flash[slot]), false, 3.0)
	# tuş rozeti
	var badge := Rect2(r.position + Vector2(8.0, 10.0), Vector2(30.0, 30.0))
	draw_rect(badge, Color(col, 0.22))
	draw_rect(badge, Color(col, 0.9), false, 2.0)
	GameFont.draw_centered(self, WeaponLoadout.key_of(slot), badge.get_center() + Vector2(0.0, -1.0), 22, GameFont.WHITE, false)
	if id == "":
		GameFont.draw_left(self, "BOŞ", r.position + Vector2(50.0, r.size.y * 0.5), 20, Color(ItemView.DIM, 0.7), false)
		return
	var text_x := 48.0
	if WeaponDB.draw_icon(self, Rect2(r.position + Vector2(42.0, 5.0), Vector2(40.0, 40.0)), id, _t):
		text_x = 88.0
	var name_color := GameFont.WHITE if ready else Color(1.0, 1.0, 1.0, 0.6)
	GameFont.draw_left(self, WeaponDB.display_name(id), r.position + Vector2(text_x, 16.0), 20, name_color)
	# seviye kutucukları
	var lv := player.loadout.level_of(id)
	var mx := WeaponDB.max_level(id)
	for i in mx:
		var pip := Rect2(r.position + Vector2(text_x + float(i) * 14.0, 33.0), Vector2(10.0, 8.0))
		if i < lv:
			draw_rect(pip, col if lv < mx else GameFont.YELLOW)
		else:
			draw_rect(pip, Color(col, 0.18))
	# menzilli silah hazır olunca kısa bir "tık"
	if WeaponDB.is_ranged(id):
		var bar := Rect2(r.position + Vector2(2.0, r.size.y - 5.0), Vector2(r.size.x - 4.0, 3.0))
		draw_rect(bar, Color(0.0, 0.0, 0.0, 0.4))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * (1.0 - cd), bar.size.y)), Color(col, 0.9))
