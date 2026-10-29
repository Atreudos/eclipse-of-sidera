class_name DevMenu
extends GameMenu
## F5 deneme menüsü: eşyaları seçip envantere eklersin (geliştirme ve deneme içindir; ödül seçme mekaniği sonra gelecek).
##
## Yukarı/aşağı (ya da W/S, fare tekerleği) gezinir. Enter / Space / E / J ya da tıklama = envantere ekler
## (takılabilir ve slotta yer varsa hemen takar). Diğer tuşlar altta yazıyor. F5 / Esc kapatır.

const S := ItemData.Slot
const ORDER := [S.FEET, S.CHARM, S.HEAD, S.POCKET, S.WRIST, S.ARMOR, S.FOOD]
const PANEL := Rect2(40.0, 30.0, 1200.0, 660.0)
## Liste 19 satır alır: şimdiki 13 eşya + 6 slot başlığı kaydırmadan sığar. Eşya artınca kaydırma devreye girer.
const LIST := Rect2(72.0, 100.0, 596.0, 494.0)
const DETAIL := Rect2(706.0, 100.0, 502.0, 494.0)
const ROW_H := 26.0
const GOLD_STEP := 50

## Satırlar: {"header": slot} ya da {"item": ItemData, "entry": int}
var _rows: Array[Dictionary] = []
## Seçilebilir eşyalar (satırlardaki sırayla).
var _entries: Array[ItemData] = []
var _sel := 0
## Listenin kaç satır yukarı kaydırıldığı.
var _scroll := 0
## Listenin görünen yüksekliği (testler kısaltıp kaydırmayı dener).
var _list_h := LIST.size.y


func _on_open() -> void:
	_build_rows()
	_sel = clampi(_sel, 0, maxi(_entries.size() - 1, 0))
	_scroll = 0
	_ensure_visible()


func _build_rows() -> void:
	_rows.clear()
	_entries.clear()
	for slot in ORDER:
		var group: Array[ItemData] = []
		for it in ItemDB.all():
			if it.slot == slot:
				group.append(it)
		if group.is_empty():
			continue
		_rows.append({"header": slot})
		for it in group:
			_entries.append(it)
			_rows.append({"item": it, "entry": _entries.size() - 1})


func selected_item() -> ItemData:
	return _entries[_sel] if _sel >= 0 and _sel < _entries.size() else null


## Testler ve kısayollar için: imleci verilen eşyaya götürür.
func select_item(item_id: String) -> bool:
	for i in _entries.size():
		if _entries[i].id == item_id:
			_sel = i
			_ensure_visible()
			return true
	return false


func _row_of_entry(entry: int) -> int:
	for i in _rows.size():
		if _rows[i].get("entry", -1) == entry:
			return i
	return 0


func _visible_rows() -> int:
	return int(_list_h / ROW_H)


func _ensure_visible() -> void:
	var row := _row_of_entry(_sel)
	if row < _scroll + 1:
		_scroll = maxi(row - 1, 0)  # üstündeki başlık da görünsün
	elif row >= _scroll + _visible_rows():
		_scroll = row - _visible_rows() + 1


# ---------------------------------------------------------------- giriş

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	var f5 := key != null and key.pressed and not key.echo and key.physical_keycode == KEY_F5
	if not is_open:
		if f5 and open(_find_player()):
			get_viewport().set_input_as_handled()
		return
	if f5 or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	var step := 0
	if event.is_action_pressed("ui_up", true):
		step = -1
	elif event.is_action_pressed("ui_down", true):
		step = 1
	elif key != null and key.pressed:
		match key.physical_keycode:
			KEY_W:
				step = -1
			KEY_S:
				step = 1
			KEY_PAGEUP:
				step = -8
			KEY_PAGEDOWN:
				step = 8
			KEY_HOME:
				step = -999
			KEY_END:
				step = 999
	if step != 0:
		_move(step)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept"):
		add_selected(true)
		get_viewport().set_input_as_handled()
		return
	if key != null and key.pressed and not key.echo:
		match key.physical_keycode:
			KEY_E, KEY_J:
				add_selected(true)
			KEY_T:
				add_selected(false)
			KEY_G:
				player.add_gold(GOLD_STEP)
				_say("+%d ALTIN" % GOLD_STEP, true)
				Sfx.play("coin", -4.0)
			KEY_H:
				var healed := player.heal(player.stats.int_value("max_health"))
				_say("CAN DOLDU" if healed > 0 else "CAN ZATEN DOLU", healed > 0)
			KEY_B:
				player.set_immunity(player.immunity + 1)
				_say("+1 BAĞIŞIKLIK KALBİ", true)
				Sfx.play("ui_select", -4.0)
			KEY_C:
				player.inventory.clear_all()
				_say("TÜM EŞYALAR SİLİNDİ", true)
				Sfx.play("ui_deny", -6.0)
	if key != null or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not is_open:
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		var e := _entry_at(motion.position)
		if e >= 0 and e != _sel:
			_sel = e
			Sfx.play("ui_move", -8.0, 1.0, 0.03)
		return
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	match button.button_index:
		MOUSE_BUTTON_LEFT:
			var e := _entry_at(button.position)
			if e >= 0:
				_sel = e
				add_selected(true)
			elif not PANEL.has_point(button.position):
				close()
		MOUSE_BUTTON_WHEEL_UP:
			_scroll = maxi(_scroll - 2, 0)
		MOUSE_BUTTON_WHEEL_DOWN:
			_scroll = clampi(_scroll + 2, 0, maxi(_rows.size() - _visible_rows(), 0))
	accept_event()


func _entry_at(pos: Vector2) -> int:
	if not Rect2(LIST.position, Vector2(LIST.size.x, _list_h)).has_point(pos):
		return -1
	var row := int((pos.y - LIST.position.y) / ROW_H) + _scroll
	if row < 0 or row >= _rows.size():
		return -1
	return int(_rows[row].get("entry", -1))


func _move(step: int) -> void:
	if _entries.is_empty():
		return
	var before := _sel
	_sel = clampi(_sel + step, 0, _entries.size() - 1)
	_ensure_visible()
	if _sel != before:
		Sfx.play("ui_move", -8.0, 1.0, 0.03)


## Seçili eşyayı envantere ekler. `equip` true ise ve slotta yer varsa hemen takar; yoksa çantaya koyar.
func add_selected(equip: bool) -> void:
	var item := selected_item()
	if item == null or player == null:
		return
	var inv := player.inventory
	var worn_before := inv.count(item.id)
	var reason := inv.add(item) if equip else inv.give(item)
	if reason != "":
		_say(reason, false)
		Sfx.play("ui_deny", -4.0)
		return
	var worn := inv.count(item.id) > worn_before
	_say(("TAKILDI  " if worn else "ÇANTAYA  ") + item.upper_name(), true)
	Sfx.play("equip" if worn else "ui_select", -3.0)


# ---------------------------------------------------------------- çizim

func _draw() -> void:
	if not is_open or player == null or not is_instance_valid(player):
		return
	draw_rect(Rect2(0.0, 0.0, _w(), _h()), Color(0.0, 0.0, 0.03, 0.74))
	ItemView.draw_panel(self, PANEL)
	GameFont.draw_left(self, "DENEME MENÜSÜ", Vector2(LIST.position.x, 66.0), 36, GameFont.YELLOW)
	var inv := player.inventory
	var info: Array = [["CAN  ", ItemView.DIM], ["%d/%d" % [player.health, player.stats.int_value("max_health")], ItemView.HEART]]
	if player.immunity > 0:
		info.append(["  +%d" % player.immunity, ItemView.BLUE])
	info.append(["     ALTIN  ", ItemView.DIM])
	info.append([str(player.gold), GameFont.YELLOW])
	info.append(["     ÇANTA  ", ItemView.DIM])
	info.append(["%d/%d" % [inv.bag.size(), Inventory.BAG_SIZE], GameFont.WHITE])
	var info_w := 0.0
	for run in info:
		info_w += GameFont.width(run[0], 20)
	GameFont.draw_runs_left(self, info, Vector2(DETAIL.end.x - info_w, 66.0), 20)  # sağa yaslı
	_draw_list()
	ItemView.draw_detail(self, DETAIL, selected_item(), "Eşya yok.")
	_draw_message(Vector2(PANEL.get_center().x, 616.0), InventoryScreen.MESSAGE_MAX_W)
	GameFont.draw_centered(self, "ENTER EKLE (SLOT BOŞSA TAK)    T YALNIZ ÇANTAYA    G +50 ALTIN    H CANI DOLDUR    B +1 BAĞIŞIKLIK", Vector2(_w() * 0.5, 644.0), 16, Color(ItemView.DIM, 0.95), false)
	GameFont.draw_centered(self, "C HEPSİNİ SİL    YUKARI/AŞAĞI VEYA W/S GEZİN    F5 / ESC KAPAT", Vector2(_w() * 0.5, 668.0), 16, Color(ItemView.DIM, 0.95), false)


func _draw_list() -> void:
	var inv := player.inventory
	var first := _scroll
	var last := mini(_scroll + _visible_rows(), _rows.size())
	for r in range(first, last):
		var row := _rows[r]
		var y := LIST.position.y + float(r - _scroll) * ROW_H
		var center_y := y + ROW_H * 0.5
		if row.has("header"):
			var slot: int = row["header"]
			var cap := int(ItemData.SLOT_CAPACITY.get(slot, 0))
			var label: String = ItemData.SLOT_NAMES[slot]
			if slot != S.FOOD:
				label += "  (%d SLOT)" % cap
			GameFont.draw_left(self, label, Vector2(LIST.position.x, center_y + 2.0), 16, Color(GameFont.YELLOW, 0.8), false)
			continue
		var item: ItemData = row["item"]
		var selected := int(row["entry"]) == _sel
		var rect := Rect2(LIST.position.x, y + 1.0, LIST.size.x, ROW_H - 2.0)
		if selected:
			var pulse := 0.12 + 0.05 * sin(_t * 7.0)
			draw_rect(rect, Color(GameFont.YELLOW, pulse))
			draw_rect(Rect2(rect.position, Vector2(4.0, rect.size.y)), GameFont.YELLOW)
		draw_rect(Rect2(rect.position.x + 14.0, center_y - 6.0, 12.0, 12.0), item.color())
		var runs: Array = []
		var worn := inv.count(item.id)
		var bagged := inv.bag_count(item.id)
		if worn > 0:
			runs.append(["TAKILI" if worn == 1 else "TAKILI x%d" % worn, ItemView.GOOD])
		if bagged > 0:
			if not runs.is_empty():
				runs.append(["  ", GameFont.WHITE])
			runs.append(["ÇANTADA" if bagged == 1 else "ÇANTADA x%d" % bagged, ItemView.BLUE])
		var tags_w := 0.0
		for run in runs:
			tags_w += GameFont.width(run[0], 14)
		# Ad, durum yazısına binmesin diye gerekirse küçülür.
		var name_x := rect.position.x + 36.0
		var avail := rect.size.x - 36.0 - tags_w - 20.0
		var name_size := 19
		while name_size > 13 and GameFont.width(item.upper_name(), name_size) > avail:
			name_size -= 1
		GameFont.draw_left(self, item.upper_name(), Vector2(name_x, center_y + 1.0), name_size, GameFont.YELLOW if selected else GameFont.WHITE, false)
		if not runs.is_empty():
			GameFont.draw_runs_left(self, runs, Vector2(rect.end.x - tags_w - 10.0, center_y + 1.0), 14, 1.0, false)
	# Kaydırma çubuğu
	if _rows.size() > _visible_rows():
		var track := Rect2(LIST.end.x + 6.0, LIST.position.y, 4.0, _list_h)
		draw_rect(track, Color(ItemView.EDGE, 0.3))
		var k0 := float(_scroll) / float(_rows.size())
		var k1 := float(_scroll + _visible_rows()) / float(_rows.size())
		draw_rect(Rect2(track.position.x, track.position.y + track.size.y * k0, 4.0, track.size.y * (k1 - k0)), ItemView.EDGE)
