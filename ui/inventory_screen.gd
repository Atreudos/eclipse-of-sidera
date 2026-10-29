class_name InventoryScreen
extends GameMenu
## Envanter ekranı (I ya da Tab): karakter, takılı eşyalar (slotlar) ve çanta. Açıkken oyun durur.
## Geçici ve idare eder: çizimlerin gelince görünüm yeniden yapılacak; mantık (slotlar, çanta) aynı kalır.
##
## Kontroller: yön tuşları / WASD / D-pad gezinir. Enter / Space / E / J ya da fare tıklaması işlem yapar:
## çantadaki eşya takılır (tek kapasiteli slot doluysa yer değiştirir), takılı eşya çıkar, yemek yenir.
## Esc / I / Tab kapatır.
##
## Slot sayıları ItemData.SLOT_CAPACITY'den okunur: orada sayıyı değiştirmek ekranı da günceller.

const S := ItemData.Slot
const BAG_COLUMNS := 6
const CELL := 60.0
const GAP := 8.0
const PANEL := Rect2(50.0, 28.0, 1180.0, 664.0)
const DETAIL := Rect2(926.0, 92.0, 284.0, 500.0)
const BAG_ORIGIN := Vector2(490.0, 118.0)
const DOLL_CENTER := Vector2(262.0, 332.0)
## Çantanın altındaki sayılar iki sütun: ikinci sütunun çanta sol kenarına uzaklığı ve yazı boyu.
const STATS_X2 := 204.0
const STATS_SIZE := 18
## Alttaki işlem mesajının (TAKILDI ..., ÇANTA DOLU) en çok kaplayacağı genişlik; sığmazsa küçülür.
const MESSAGE_MAX_W := 1000.0
const SLOT_LABELS := {
	S.HEAD: "KAFA", S.CHARM: "CHARM", S.ARMOR: "ZIRH", S.WRIST: "BİLEK", S.POCKET: "CEP", S.FEET: "AYAK",
}

## Tıklanabilir kutular: {"kind": "slot"|"bag", "slot": Slot (kind=slot), "idx": int, "rect": Rect2}
var _cells: Array[Dictionary] = []
## Slot gruplarının üstündeki küçük başlıklar: {"text": String, "pos": Vector2}
var _captions: Array[Dictionary] = []
var _cursor := 0


## Açılışta kutular kurulur, imleç ilk dolu kutuya konur.
func _on_open() -> void:
	_build_cells()
	_cursor = _first_cursor()


# ---------------------------------------------------------------- düzen

func _build_cells() -> void:
	_cells.clear()
	_captions.clear()
	var cap := ItemData.SLOT_CAPACITY
	# Kafa: bebeğin üstünde yan yana
	_add_slot_group(S.HEAD, _spread(Vector2(DOLL_CENTER.x, 156.0), int(cap.get(S.HEAD, 0)), true))
	# Charm: solda alt alta
	_add_slot_group(S.CHARM, _spread(Vector2(118.0, DOLL_CENTER.y), int(cap.get(S.CHARM, 0)), false))
	# Sağ sütun: zırh, bilek, cep (her biri bir satır)
	var right_slots := [S.ARMOR, S.WRIST, S.POCKET]
	var right_y := [DOLL_CENTER.y - 84.0, DOLL_CENTER.y, DOLL_CENTER.y + 84.0]
	for i in right_slots.size():
		_add_slot_group(right_slots[i], _spread(Vector2(406.0, right_y[i]), int(cap.get(right_slots[i], 0)), true))
	# Ayak: bebeğin altında
	_add_slot_group(S.FEET, _spread(Vector2(DOLL_CENTER.x, 520.0), int(cap.get(S.FEET, 0)), true))
	# Çanta
	for i in Inventory.BAG_SIZE:
		var pos := BAG_ORIGIN + Vector2(i % BAG_COLUMNS, i / BAG_COLUMNS) * (CELL + GAP)
		_cells.append({"kind": "bag", "slot": -1, "idx": i, "rect": Rect2(pos, Vector2(CELL, CELL))})


## `n` kutuyu `center` etrafında ortalayarak yan yana (ya da alt alta) dizer.
func _spread(center: Vector2, n: int, horizontal: bool) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in n:
		var off := (float(i) - float(n - 1) * 0.5) * (CELL + GAP)
		out.append(center + (Vector2(off, 0.0) if horizontal else Vector2(0.0, off)))
	return out


func _add_slot_group(slot: int, centers: Array[Vector2]) -> void:
	if centers.is_empty():
		return
	var min_y := centers[0].y
	var sum_x := 0.0
	for i in centers.size():
		_cells.append({"kind": "slot", "slot": slot, "idx": i, "rect": Rect2(centers[i] - Vector2(CELL, CELL) * 0.5, Vector2(CELL, CELL))})
		min_y = minf(min_y, centers[i].y)
		sum_x += centers[i].x
	# Başlık: grubun (dikey grupta ilk kutunun) hemen üstünde
	_captions.append({"text": SLOT_LABELS.get(slot, ""), "pos": Vector2(sum_x / float(centers.size()), min_y - CELL * 0.5 - 12.0)})


func cell_count() -> int:
	return _cells.size()


func cell_rect(i: int) -> Rect2:
	return _cells[i]["rect"]


func cursor_index() -> int:
	return _cursor


func cursor_item() -> ItemData:
	return _item_of(_cells[_cursor]) if is_open and not _cells.is_empty() else null


## İlk imleç: dolu ilk çanta kutusu; çanta boşsa ilk takılı eşya; o da yoksa ilk kutu.
func _first_cursor() -> int:
	var inv := player.inventory
	for i in _cells.size():
		if _cells[i]["kind"] == "bag" and _item_of(_cells[i]) != null:
			return i
	for i in _cells.size():
		if _item_of(_cells[i]) != null:
			return i
	return 0 if inv != null else 0


## İmleci verilen eşyanın bulunduğu kutuya götürür (önce çanta, sonra slotlar). Bulursa true.
func focus_item(item_id: String) -> bool:
	for pass_kind in ["bag", "slot"]:
		for i in _cells.size():
			var it := _item_of(_cells[i])
			if _cells[i]["kind"] == pass_kind and it != null and it.id == item_id:
				_cursor = i
				return true
	return false


func _item_of(cell: Dictionary) -> ItemData:
	var inv := player.inventory
	var idx: int = cell["idx"]
	if cell["kind"] == "slot":
		var list := inv.equipped_in(cell["slot"])
		return list[idx] if idx < list.size() else null
	return inv.bag[idx]["item"] if idx < inv.bag.size() else null


func _count_of(cell: Dictionary) -> int:
	if cell["kind"] != "bag":
		return 1
	var inv := player.inventory
	var idx: int = cell["idx"]
	return int(inv.bag[idx]["count"]) if idx < inv.bag.size() else 0


# ---------------------------------------------------------------- giriş

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		if event.is_action_pressed("inventory"):
			if open(_find_player()):
				get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("inventory") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	var dir := Vector2.ZERO
	if event.is_action_pressed("ui_left", true):
		dir = Vector2.LEFT
	elif event.is_action_pressed("ui_right", true):
		dir = Vector2.RIGHT
	elif event.is_action_pressed("ui_up", true):
		dir = Vector2.UP
	elif event.is_action_pressed("ui_down", true):
		dir = Vector2.DOWN
	var key := event as InputEventKey
	if dir == Vector2.ZERO and key != null and key.pressed:
		match key.physical_keycode:
			KEY_A:
				dir = Vector2.LEFT
			KEY_D:
				dir = Vector2.RIGHT
			KEY_W:
				dir = Vector2.UP
			KEY_S:
				dir = Vector2.DOWN
	if dir != Vector2.ZERO:
		_move_cursor(dir)
		get_viewport().set_input_as_handled()
		return
	var accept := event.is_action_pressed("ui_accept")
	if key != null and key.pressed and not key.echo and (key.physical_keycode == KEY_E or key.physical_keycode == KEY_J):
		accept = true
	if accept:
		activate()
		get_viewport().set_input_as_handled()
		return
	# Açıkken oyun tuşları (dash, parry...) alta geçmesin
	if key != null or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()


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
			_cursor = i
			activate()
		elif not PANEL.has_point(button.position):
			close()
		accept_event()


func _cell_at(pos: Vector2) -> int:
	for i in _cells.size():
		if (_cells[i]["rect"] as Rect2).grow(GAP * 0.5).has_point(pos):
			return i
	return -1


func _set_cursor(i: int) -> void:
	if i == _cursor:
		return
	_cursor = i
	Sfx.play("ui_move", -8.0, 1.0, 0.03)


## İmleci `dir` yönündeki en yakın kutuya taşır (yönde ilerleme + yana sapma cezası).
func _move_cursor(dir: Vector2) -> void:
	if _cells.is_empty():
		return
	var from := (_cells[_cursor]["rect"] as Rect2).get_center()
	var best := -1
	var best_score := INF
	for i in _cells.size():
		if i == _cursor:
			continue
		var d := (_cells[i]["rect"] as Rect2).get_center() - from
		var along := d.dot(dir)
		if along <= 4.0:
			continue
		var score := along + absf(d.cross(dir)) * 2.5
		if score < best_score:
			best_score = score
			best = i
	if best >= 0:
		_set_cursor(best)


# ---------------------------------------------------------------- işlemler

## İmlecin üstündeki kutuda işlem yapar: çantadaki eşyayı tak, takılıyı çıkar, yemeği ye.
func activate() -> void:
	if not is_open or player == null or _cells.is_empty():
		return
	var cell := _cells[_cursor]
	var item := _item_of(cell)
	if item == null:
		_say("BOŞ", false)
		Sfx.play("ui_deny", -6.0)
		return
	var inv := player.inventory
	var reason := ""
	var done := ""
	if cell["kind"] == "slot":
		reason = inv.unequip(item)
		done = "ÇIKARILDI  " + item.upper_name()
	elif item.is_food():
		reason = inv.use(item)
		done = "YENDİ  " + item.upper_name()
	else:
		reason = inv.swap_in(item)
		done = "TAKILDI  " + item.upper_name()
	if reason != "":
		_say(reason, false)
		Sfx.play("ui_deny", -4.0)
		return
	_say(done, true)
	if not item.is_food():
		Sfx.play("equip", -3.0)


# ---------------------------------------------------------------- çizim

func _draw() -> void:
	if not is_open or player == null or not is_instance_valid(player):
		return
	draw_rect(Rect2(0.0, 0.0, _w(), _h()), Color(0.0, 0.0, 0.03, 0.74))
	ItemView.draw_panel(self, PANEL)
	GameFont.draw_left(self, "ENVANTER", Vector2(82.0, 62.0), 40, GameFont.YELLOW)
	_draw_doll()
	for cap in _captions:
		GameFont.draw_centered(self, cap["text"], cap["pos"], 14, Color(ItemView.DIM, 0.95), false)
	for i in _cells.size():
		var cell := _cells[i]
		ItemView.draw_cell(self, cell["rect"], _item_of(cell), _count_of(cell), i == _cursor, _t)
	var inv := player.inventory
	GameFont.draw_runs_left(self, [["ÇANTA", GameFont.WHITE], ["   %d/%d" % [inv.bag.size(), Inventory.BAG_SIZE], ItemView.DIM]], Vector2(BAG_ORIGIN.x, 92.0), 24)
	_draw_stats()
	var focused := _item_of(_cells[_cursor]) if not _cells.is_empty() else null
	var hint := "Boş kutu."
	if not _cells.is_empty() and _cells[_cursor]["kind"] == "slot":
		hint = "%s slotu boş." % SLOT_LABELS.get(_cells[_cursor]["slot"], "")
	ItemView.draw_detail(self, DETAIL, focused, hint)
	_draw_action_hint(focused)
	_draw_message(Vector2(PANEL.get_center().x, 644.0), MESSAGE_MAX_W)
	GameFont.draw_centered(self, "YÖN TUŞLARI / WASD GEZİN     ENTER TAK / ÇIKAR / YE     ESC KAPAT", Vector2(_w() * 0.5, 676.0), 15, Color(ItemView.DIM, 0.85), false)


## Karakter: sprite varsa onun ilk idle karesi, yoksa oyundaki yer tutucu kutunun 3 kat büyüğü.
func _draw_doll() -> void:
	var c := DOLL_CENTER
	draw_circle(c, 156.0, Color(0.22, 0.16, 0.38, 0.24))
	draw_circle(c, 120.0, Color(0.3, 0.22, 0.5, 0.16))
	var drawn := false
	var anim := player.anim
	if anim != null and anim.has_art and anim.sprite != null and anim.sprite.sprite_frames != null:
		var frames := anim.sprite.sprite_frames
		var names := frames.get_animation_names()
		if names.size() > 0:
			var anim_name := "idle" if frames.has_animation("idle") else names[0]
			if frames.get_frame_count(anim_name) > 0:
				var tex := frames.get_frame_texture(anim_name, 0)
				draw_texture_rect(tex, Rect2(c - tex.get_size() * 1.5, tex.get_size() * 3.0), false)
				drawn = true
	if not drawn:
		var k := 3.0
		draw_rect(Rect2(c + Vector2(-14.0, -26.0) * k, Vector2(28.0, 52.0) * k), Color(0.93, 0.91, 0.86))
		draw_rect(Rect2(c + Vector2(3.0, -18.0) * k, Vector2(10.0, 8.0) * k), Color(0.09, 0.08, 0.11))
	GameFont.draw_centered(self, "SIDERA", Vector2(c.x, 590.0), 32, GameFont.YELLOW)


## Çantanın altında: can, altın, refleks ve diğer sayılar (iki sütun; yalnız normalden farklı olanlar eklenir).
func _draw_stats() -> void:
	var p := player
	var st := p.stats
	var x := BAG_ORIGIN.x
	var x2 := x + STATS_X2
	var y := 410.0
	var step := 25.0
	var max_hp := st.int_value("max_health")
	var runs: Array = [["CAN  ", ItemView.DIM], ["%d/%d" % [p.health, max_hp], ItemView.HEART]]
	if p.immunity > 0:
		runs.append(["   +%d BAĞIŞIKLIK" % p.immunity, ItemView.BLUE])
	GameFont.draw_runs_left(self, runs, Vector2(x, y), STATS_SIZE)
	y += step
	GameFont.draw_runs_left(self, [["ALTIN  ", ItemView.DIM], [str(p.gold), GameFont.YELLOW]], Vector2(x, y), STATS_SIZE)
	GameFont.draw_runs_left(self, [["REFLEKS  ", ItemView.DIM], ["x%.2f" % st.value("reflex", 1.0), GameFont.WHITE]], Vector2(x2, y), STATS_SIZE)
	y += step
	GameFont.draw_runs_left(self, [["DASH  ", ItemView.DIM], [str(st.int_value("dash_charges")), GameFont.WHITE]], Vector2(x, y), STATS_SIZE)
	GameFont.draw_runs_left(self, [["PARRY  ", ItemView.DIM], ["%.2f SN" % p.parry_window_time(), GameFont.WHITE]], Vector2(x2, y), STATS_SIZE)
	y += step
	GameFont.draw_runs_left(self, [["YÜRÜME  ", ItemView.DIM], [str(roundi(st.value("move_speed"))), GameFont.WHITE]], Vector2(x, y), STATS_SIZE)
	var kb := st.value("knockback_mult", 1.0)
	if not is_equal_approx(kb, 1.0):
		GameFont.draw_runs_left(self, [["GERİ İTME  ", ItemView.DIM], ["x%.1f" % kb, GameFont.WHITE]], Vector2(x2, y), STATS_SIZE)
	y += step
	var dmg_taken := st.value("damage_taken", 1.0)
	if not is_equal_approx(dmg_taken, 1.0):
		GameFont.draw_runs_left(self, [["ALINAN HASAR  ", ItemView.DIM], ["%%%d" % roundi(dmg_taken * 100.0), GameFont.WHITE]], Vector2(x, y), STATS_SIZE)
		y += step
	var text_w := DETAIL.position.x - 16.0 - x
	for tag in p.inventory.active_synergies():
		GameFont.draw_runs_left(self, [["SİNERJİ  ", ItemView.DIM], [str(tag), GameFont.YELLOW]], Vector2(x, y), 17)
		y += 22.0
		for line in GameFont.wrap(String(ItemDB.SYNERGY_TEXT.get(tag, "")), 15, text_w):
			GameFont.draw_left(self, line, Vector2(x, y), 15, ItemView.DIM)
			y += 19.0
		y += 3.0
	for line in p.status_lines():
		GameFont.draw_left(self, line, Vector2(x, y), 17, ItemView.BLUE)
		y += 22.0


## Ayrıntı panelinin altında: imlecin üstündeki eşyayla ne yapılacağı.
func _draw_action_hint(item: ItemData) -> void:
	if item == null or _cells.is_empty():
		return
	var text := "ENTER  ÇIKAR"
	if _cells[_cursor]["kind"] == "bag":
		text = "ENTER  YE" if item.is_food() else "ENTER  TAK"
	GameFont.draw_centered(self, text, Vector2(DETAIL.get_center().x, DETAIL.end.y + 22.0), 20, GameFont.YELLOW)
