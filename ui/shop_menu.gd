class_name ShopMenu
extends GameMenu
## Dükkân menüsü (lobide tezgâha E): rafta duran eşyaları ve yemekleri altınla satın al. Açıkken oyun durur.
## Geçici ve idare eder: çizimlerin gelince görünüm yeniden yapılacak; mantık (ShopStock.buy) aynı kalır.
##
## Kontroller: yön tuşları / WASD gezinir. Enter / Space / E / J ya da fare (seçiliye tekrar tıkla) satın alır. Esc kapatır.
## Satış kuralları ShopStock.buy'da: altın ya da çantada yer yoksa satış reddedilir ve altın düşmez.

const PANEL := Rect2(100.0, 40.0, 1080.0, 640.0)
const DETAIL := Rect2(852.0, 118.0, 300.0, 456.0)
const CELL := 92.0
const GAP := 26.0
## Raf satırlarının ortası (x) ve ilk satırın üst kenarı (y).
const GRID_CENTER_X := 470.0
const GRID_TOP := 176.0
const ROW_STEP := 190.0

var stock: ShopStock
## Oyuncunun bu menüyü açtığı tezgâh (kapanınca tezgâh yeniden çizilir).
var stand: ShopStand

## Teklif i'nin kutusu (stock.offers ile aynı sırada).
var _rects: Array[Rect2] = []
## Satır başlıkları: {"text", "pos"}
var _captions: Array[Dictionary] = []
var _cursor := 0


## Menüyü bir raf için açar. Açılamazsa (raf yok, başka menü açık, oyuncu ölü) false.
func open_shop(p: Player, shop_stock: ShopStock, shop_stand: ShopStand = null) -> bool:
	if shop_stock == null:
		return false
	stock = shop_stock
	stand = shop_stand
	if not open(p):
		stock = null
		stand = null
		return false
	return true


func _on_open() -> void:
	_build_layout()
	_cursor = _first_unsold()


func close() -> void:
	super.close()
	if stand != null and is_instance_valid(stand):
		stand.queue_redraw()


# ---------------------------------------------------------------- düzen

## Eşyalar üst satırda, yemekler alt satırda; her satır kendi içinde ortalanır.
func _build_layout() -> void:
	_rects.clear()
	_captions.clear()
	if stock == null:
		return
	var gear: Array[int] = []
	var food: Array[int] = []
	for i in stock.size():
		if stock.offers[i].item.is_food():
			food.append(i)
		else:
			gear.append(i)
	_rects.resize(stock.size())
	var row := 0
	for group in [["EŞYA", gear], ["YEMEK", food]]:
		var idxs: Array = group[1]
		if idxs.is_empty():
			continue
		var y := GRID_TOP + ROW_STEP * float(row)
		for k in idxs.size():
			var x := GRID_CENTER_X + (float(k) - float(idxs.size() - 1) * 0.5) * (CELL + GAP) - CELL * 0.5
			_rects[idxs[k]] = Rect2(x, y, CELL, CELL)
		_captions.append({"text": group[0], "pos": Vector2(GRID_CENTER_X, y - 22.0)})
		row += 1


func cell_count() -> int:
	return _rects.size()


func cell_rect(i: int) -> Rect2:
	return _rects[i]


func cursor_index() -> int:
	return _cursor


func cursor_offer() -> ShopStock.Offer:
	if not is_open or stock == null or _cursor < 0 or _cursor >= stock.size():
		return null
	return stock.offers[_cursor]


## İmleci `i`. teklife götürür (testler).
func focus(i: int) -> bool:
	if stock == null or i < 0 or i >= stock.size():
		return false
	_cursor = i
	return true


func _first_unsold() -> int:
	if stock == null:
		return 0
	for i in stock.size():
		if not stock.offers[i].sold:
			return i
	return 0


# ---------------------------------------------------------------- giriş

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	# Eylem sahneyi değiştirmez ama kalıp aynı kalsın: önce işaretle.
	var vp := get_viewport()
	if event.is_action_pressed("ui_cancel"):
		vp.set_input_as_handled()
		close()
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
		vp.set_input_as_handled()
		_move_cursor(dir)
		return
	var accept := event.is_action_pressed("ui_accept")
	if key != null and key.pressed and not key.echo and (key.physical_keycode == KEY_E or key.physical_keycode == KEY_J):
		accept = true
	if accept:
		vp.set_input_as_handled()
		buy_cursor()
		return
	# Açıkken oyun tuşları (dash, parry...) alta geçmesin.
	if key != null or event is InputEventJoypadButton:
		vp.set_input_as_handled()


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
			if i == _cursor:
				buy_cursor()  # seçiliye ikinci tıklama: satın al
			else:
				_set_cursor(i)
		elif not PANEL.has_point(button.position):
			close()
		accept_event()


func _cell_at(pos: Vector2) -> int:
	for i in _rects.size():
		if _rects[i].grow(GAP * 0.5).has_point(pos):
			return i
	return -1


func _set_cursor(i: int) -> void:
	if i == _cursor:
		return
	_cursor = i
	Sfx.play("ui_move", -8.0, 1.0, 0.03)


## İmleci `dir` yönündeki en yakın kutuya taşır (yönde ilerleme + yana sapma cezası).
func _move_cursor(dir: Vector2) -> void:
	if _rects.is_empty():
		return
	var from := _rects[_cursor].get_center()
	var best := -1
	var best_score := INF
	for i in _rects.size():
		if i == _cursor:
			continue
		var d := _rects[i].get_center() - from
		var along := d.dot(dir)
		if along <= 4.0:
			continue
		var score := along + absf(d.cross(dir)) * 2.5
		if score < best_score:
			best_score = score
			best = i
	if best >= 0:
		_set_cursor(best)


# ---------------------------------------------------------------- işlem

## İmlecin üstündeki teklifi satın alır. Başarılıysa true.
func buy_cursor() -> bool:
	if not is_open or stock == null or player == null:
		return false
	var offer := cursor_offer()
	if offer == null:
		return false
	var item_name := offer.item.upper_name()
	var reason := stock.buy(player, _cursor)
	if reason != "":
		_say(reason, false)
		Sfx.play("ui_deny", -4.0)
		return false
	_say("SATIN ALINDI  " + item_name, true)
	Sfx.play("coin", -2.0)
	if not offer.item.is_food():
		Sfx.play("equip", -3.0)
	return true


# ---------------------------------------------------------------- çizim

func _draw() -> void:
	if not is_open or stock == null or player == null or not is_instance_valid(player):
		return
	draw_rect(Rect2(0.0, 0.0, _w(), _h()), Color(0.0, 0.0, 0.03, 0.78))
	ItemView.draw_panel(self, PANEL)
	GameFont.draw_left(self, "DÜKKÂN", Vector2(PANEL.position.x + 34.0, PANEL.position.y + 40.0), 40, GameFont.YELLOW)
	GameFont.draw_left(self, "TÜCCAR ESKİ BİR DOSTUN GİBİ GÜLÜMSER", Vector2(PANEL.position.x + 34.0, PANEL.position.y + 70.0), 15, Color(ItemView.DIM, 0.9), false)
	# Altın (sağ üst)
	var gold_text := str(player.gold)
	var gw := GameFont.width(gold_text, 30)
	var gx := PANEL.end.x - 34.0 - gw
	draw_circle(Vector2(gx - 26.0, PANEL.position.y + 36.0), 11.0, Color(0.55, 0.36, 0.05))
	draw_circle(Vector2(gx - 26.0, PANEL.position.y + 36.0), 9.0, Color(1.0, 0.82, 0.2))
	GameFont.draw_left(self, gold_text, Vector2(gx, PANEL.position.y + 36.0), 30, GameFont.YELLOW)
	for cap in _captions:
		GameFont.draw_centered(self, cap["text"], cap["pos"], 16, Color(ItemView.DIM, 0.95), false)
	for i in _rects.size():
		_draw_offer(i)
	var focused: ShopStock.Offer = cursor_offer()
	var empty_text := "Raf boş."
	if focused != null and focused.sold:
		empty_text = "Bu eşya satıldı."
	ItemView.draw_detail(self, DETAIL, focused.item if focused != null and not focused.sold else null, empty_text, focused.price if focused != null else -1)
	_draw_action_hint(focused)
	var inv := player.inventory
	if inv != null:
		GameFont.draw_runs_left(self, [["ÇANTA  ", ItemView.DIM], ["%d/%d" % [inv.bag.size(), Inventory.BAG_SIZE], GameFont.WHITE]], Vector2(PANEL.position.x + 34.0, PANEL.end.y - 64.0), 20)
	_draw_message(Vector2(GRID_CENTER_X, PANEL.end.y - 96.0), 640.0)
	GameFont.draw_centered(self, "YÖN TUŞLARI / WASD GEZİN     ENTER SATIN AL     ESC KAPAT", Vector2(PANEL.get_center().x, PANEL.end.y - 26.0), 15, Color(ItemView.DIM, 0.85), false)


func _draw_offer(i: int) -> void:
	var o := stock.offers[i]
	var r := _rects[i]
	if o.sold:
		draw_rect(r, Color(0.05, 0.03, 0.08, 0.7))
		draw_rect(r, Color(0.3, 0.26, 0.38, 0.8), false, 2.0)
		GameFont.draw_centered(self, "SATILDI", r.get_center(), 14, Color(ItemView.DIM, 0.8), false)
		if i == _cursor:
			var pulse := 0.65 + 0.35 * sin(_t * 7.0)
			draw_rect(r.grow(3.0), Color(GameFont.YELLOW, pulse), false, 3.0)
		return
	ItemView.draw_cell(self, r, o.item, 1, i == _cursor, _t)
	var affordable := player.gold >= o.price
	var col := GameFont.YELLOW if affordable else Color(1.0, 0.45, 0.45)
	GameFont.draw_centered(self, str(o.price), Vector2(r.get_center().x, r.end.y + 22.0), 20, col)


## Ayrıntı panelinin altında: ne yapılacağı ya da neden yapılamayacağı.
func _draw_action_hint(offer: ShopStock.Offer) -> void:
	if offer == null or offer.sold:
		return
	var text := "ENTER  SATIN AL"
	var col := GameFont.YELLOW
	if player.gold < offer.price:
		text = "YETERLİ ALTIN YOK"
		col = Color(1.0, 0.45, 0.45)
	elif player.inventory != null and not player.inventory.can_give(offer.item):
		text = "ÇANTA DOLU"
		col = Color(1.0, 0.45, 0.45)
	GameFont.draw_centered(self, text, Vector2(DETAIL.get_center().x, DETAIL.end.y + 22.0), 20, col)
