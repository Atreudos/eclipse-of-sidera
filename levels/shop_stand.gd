class_name ShopStand
extends Node2D
## Lobideki dükkân tezgâhı: tüccar, tezgâh, tabela ve tezgâhta duran eşyalar. Oyuncu yaklaşıp E'ye basınca
## `requested` sinyali gelir; koşu denetleyicisi dükkân menüsünü açar (ShopMenu).
##
## Orijin = tezgâhın zemindeki orta noktası. Koddan çizilir (yer tutucu); `shop_counter`, `merchant_idle`, `shop_sign`
## çizimleri gelince onlar kullanılır.

signal requested(stand: ShopStand)

const RANGE_X := 190.0
const RANGE_Y := 170.0
## Tezgâh (orijine göre).
const COUNTER := Rect2(-150.0, -64.0, 300.0, 64.0)
## Tüccarın ayak noktası (tezgâhın solunda).
const MERCHANT_X := -214.0
const CELL := 38.0

var stock: ShopStock
var in_range := false

var _t := 0.0
var _player: Player


func _ready() -> void:
	z_index = -2
	add_to_group("shop_stands")
	_hook_player()


func _exit_tree() -> void:
	if _player != null and is_instance_valid(_player) and _player.interacted.is_connected(_on_interacted):
		_player.interacted.disconnect(_on_interacted)


func _hook_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player != null and not _player.interacted.is_connected(_on_interacted):
		_player.interacted.connect(_on_interacted)


func _on_interacted() -> void:
	if in_range and stock != null and ItemView.active_menu == null and _player != null and not _player.dead:
		requested.emit(self)


func _process(delta: float) -> void:
	_t += delta
	if _player == null or not is_instance_valid(_player):
		_hook_player()
	in_range = false
	if _player != null and is_instance_valid(_player) and not _player.dead:
		var d := _player.global_position - global_position
		in_range = absf(d.x) <= RANGE_X and absf(d.y) <= RANGE_Y
	queue_redraw()


func _draw() -> void:
	# Halı
	draw_rect(Rect2(-250.0, -5.0, 500.0, 5.0), Color(0.3, 0.1, 0.1, 0.9))
	draw_rect(Rect2(-250.0, -5.0, 500.0, 2.0), Color(1.0, 0.76, 0.38, 0.45))
	_draw_merchant()
	_draw_counter()
	_draw_offers()
	_draw_sign()
	if in_range and stock != null:
		var pulse := 0.7 + 0.3 * sin(_t * 6.0)
		GameFont.draw_runs_centered(self, [["E", GameFont.YELLOW], ["  ALIŞVERİŞ", GameFont.WHITE]], Vector2(0.0, -336.0), 24, pulse)


func _draw_counter() -> void:
	if Art.draw(self, "shop_counter", Rect2(-128.0, -128.0, 256.0, 128.0), _t):
		return
	draw_rect(COUNTER, Color(0.2, 0.12, 0.08))
	draw_rect(Rect2(COUNTER.position.x - 6.0, COUNTER.position.y - 7.0, COUNTER.size.x + 12.0, 9.0), Color(0.42, 0.28, 0.14))
	draw_rect(Rect2(COUNTER.position.x - 6.0, COUNTER.position.y - 7.0, COUNTER.size.x + 12.0, 3.0), Color(0.62, 0.44, 0.22))
	# Ön yüzdeki oyma paneller
	var x := COUNTER.position.x + 14.0
	while x < COUNTER.end.x - 30.0:
		draw_rect(Rect2(x, COUNTER.position.y + 12.0, 44.0, 38.0), Color(0.15, 0.09, 0.06))
		draw_rect(Rect2(x, COUNTER.position.y + 12.0, 44.0, 38.0), Color(0.5, 0.34, 0.16, 0.5), false, 2.0)
		x += 56.0
	# Tezgâhın sağ ucunda bir fener
	var lx := COUNTER.end.x - 14.0
	var flick := 0.5 + 0.5 * sin(_t * 8.0) * sin(_t * 4.7)
	draw_circle(Vector2(lx, COUNTER.position.y - 24.0), 54.0, Color(1.0, 0.72, 0.3, 0.06 + 0.02 * flick))
	draw_rect(Rect2(lx - 8.0, COUNTER.position.y - 30.0, 16.0, 22.0), Color(0.3, 0.2, 0.1))
	draw_rect(Rect2(lx - 5.0, COUNTER.position.y - 27.0, 10.0, 16.0), Color(1.0, 0.8, 0.35, 0.85 + 0.1 * flick))


func _draw_merchant() -> void:
	var feet := Vector2(MERCHANT_X, 0.0)
	var breathe := 1.5 * sin(_t * 1.8)
	if Art.draw(self, "merchant_idle", Rect2(feet.x - 64.0, -128.0, 128.0, 128.0), _t):
		return
	# Pelerinli, kukuletalı siluet
	var robe := PackedVector2Array([
		feet + Vector2(-40.0, 0.0), feet + Vector2(40.0, 0.0), feet + Vector2(30.0, -92.0 + breathe),
		feet + Vector2(0.0, -120.0 + breathe), feet + Vector2(-30.0, -92.0 + breathe),
	])
	draw_colored_polygon(robe, Color(0.17, 0.09, 0.13))
	draw_polyline(robe + PackedVector2Array([robe[0]]), Color(1.0, 0.76, 0.38, 0.5), 2.0)
	draw_circle(feet + Vector2(0.0, -106.0 + breathe), 18.0, Color(0.07, 0.04, 0.08))
	# Parlayan gözler
	draw_circle(feet + Vector2(-6.0, -108.0 + breathe), 2.2, Color(1.0, 0.84, 0.3))
	draw_circle(feet + Vector2(6.0, -108.0 + breathe), 2.2, Color(1.0, 0.84, 0.3))
	# Kese
	draw_circle(feet + Vector2(26.0, -34.0), 9.0, Color(0.4, 0.26, 0.1))
	draw_rect(Rect2(feet.x + 22.0, feet.y - 48.0, 8.0, 6.0), Color(0.55, 0.36, 0.14))


func _draw_sign() -> void:
	if Art.draw(self, "shop_sign", Rect2(-80.0, -300.0, 160.0, 80.0), _t):
		return
	var sway := 2.0 * sin(_t * 1.4)
	var board := Rect2(-78.0 + sway, -286.0, 156.0, 40.0)
	draw_line(Vector2(-56.0, -330.0), Vector2(-56.0 + sway, -286.0), Color(0.5, 0.4, 0.3), 2.0)
	draw_line(Vector2(56.0, -330.0), Vector2(56.0 + sway, -286.0), Color(0.5, 0.4, 0.3), 2.0)
	draw_rect(board, Color(0.2, 0.12, 0.08))
	draw_rect(board, Color(1.0, 0.76, 0.38, 0.7), false, 2.0)
	GameFont.draw_centered(self, "DÜKKÂN", board.get_center(), 22, GameFont.YELLOW)


## Tezgâhın üstünde süzülen eşyalar: fiyatları altında yazar; satılanlar boş kalır.
func _draw_offers() -> void:
	if stock == null:
		return
	var n := stock.size()
	var gap := CELL + 10.0
	for i in n:
		var o: ShopStock.Offer = stock.offers[i]
		var x := (float(i) - float(n - 1) * 0.5) * gap
		var bob := 3.0 * sin(_t * 2.2 + float(i) * 0.9)
		var r := Rect2(x - CELL * 0.5, COUNTER.position.y - CELL - 14.0 + bob, CELL, CELL)
		if o.sold:
			draw_rect(r, Color(0.05, 0.03, 0.08, 0.55))
			draw_rect(r, Color(0.3, 0.26, 0.38, 0.7), false, 2.0)
			continue
		ItemView.draw_cell(self, r, o.item, 1, false, _t)
		var affordable := _player != null and is_instance_valid(_player) and _player.gold >= o.price
		var price_col := GameFont.YELLOW if affordable else Color(1.0, 0.45, 0.45)
		GameFont.draw_centered(self, str(o.price), Vector2(x, COUNTER.position.y + 30.0), 15, price_col)
