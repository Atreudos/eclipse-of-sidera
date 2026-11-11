class_name RewardStand
extends Node2D
## Gölge ödül sunakları: Gölge yenilince odanın ortasında iki sunak yükselir, her birinin üstünde bir eşya süzülür.
## Oyuncu yaklaşıp E'ye basınca `requested` sinyali gelir; koşu denetleyicisi ödül menüsünü açar (RewardMenu).
## Birini alınca o sunak ışıkla patlar, DİĞERİ kararır ve eşyayı Gölge alır (sonraki katlarda sana karşı kullanır).
##
## Orijin = iki sunağın zemindeki orta noktası. Koddan çizilir (yer tutucu); `altar_rise`, `altar_idle`, `altar_take`,
## `altar_dim`, `fx_umbra_grab` çizimleri gelince onlar kullanılır.

signal requested(stand: RewardStand)

const RANGE_X := 330.0
const RANGE_Y := 170.0
## İki sunağın merkezleri arası.
const SPACING := 250.0
## Sunak çizim kutusu (128x128, ayak noktası alt orta).
const ALTAR := Vector2(128.0, 128.0)
## Sunağın yerden yükselme süresi.
const RISE_TIME := 1.0
## Seçimden sonra: ışık patlaması ve kararma süreleri.
const TAKE_TIME := 0.7
const DIM_TIME := 1.0
const CELL := 54.0

## Gölge'nin rengi (seçilmeyen sunakta ve ipuçlarında).
const SHADOW := Color(0.78, 0.55, 1.0)

var choice: RewardChoice
var accent := Color(0.95, 0.78, 0.3)
var in_range := false

var _t := 0.0
## Seçimden bu yana geçen süre (seçim yoksa -1).
var _since := -1.0
var _player: Player


func _ready() -> void:
	z_index = -2
	add_to_group("reward_stands")
	_hook_player()
	if choice != null and not choice.taken.is_connected(_on_taken):
		choice.taken.connect(_on_taken)
	Sfx.play("door_open", -6.0, 1.3)


func _exit_tree() -> void:
	if _player != null and is_instance_valid(_player) and _player.interacted.is_connected(_on_interacted):
		_player.interacted.disconnect(_on_interacted)


## Sunağın seçimini bağlar (sahneye eklenmeden önce ya da sonra çağrılabilir).
func set_choice(c: RewardChoice) -> void:
	if choice != null and choice.taken.is_connected(_on_taken):
		choice.taken.disconnect(_on_taken)
	choice = c
	_since = 0.0 if c != null and c.is_done() else -1.0
	if choice != null and not choice.taken.is_connected(_on_taken):
		choice.taken.connect(_on_taken)


## `i`. sunağın orijine göre x konumu.
func altar_x(i: int) -> float:
	var n := choice.size() if choice != null else 2
	return (float(i) - float(n - 1) * 0.5) * SPACING


func is_risen() -> bool:
	return _t >= RISE_TIME


func _hook_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player != null and not _player.interacted.is_connected(_on_interacted):
		_player.interacted.connect(_on_interacted)


func _on_interacted() -> void:
	if in_range and is_risen() and choice != null and not choice.is_done() and ItemView.active_menu == null and _player != null and not _player.dead:
		requested.emit(self)


func _on_taken(_item: ItemData, _left: Array) -> void:
	_since = 0.0
	Sfx.play("equip", -3.0)


func _process(delta: float) -> void:
	_t += delta
	if _since >= 0.0:
		_since += delta
	if _player == null or not is_instance_valid(_player):
		_hook_player()
	in_range = false
	if _player != null and is_instance_valid(_player) and not _player.dead:
		var d := _player.global_position - global_position
		in_range = absf(d.x) <= RANGE_X and absf(d.y) <= RANGE_Y
	queue_redraw()


# ---------------------------------------------------------------- çizim

func _draw() -> void:
	if choice == null:
		return
	var rise := clampf(_t / RISE_TIME, 0.0, 1.0)
	var rise_k := 1.0 - pow(1.0 - rise, 3.0)
	_draw_beam(rise)
	for i in choice.size():
		_draw_altar(i, altar_x(i), rise_k)
	if in_range and is_risen() and not choice.is_done():
		var pulse := 0.7 + 0.3 * sin(_t * 6.0)
		GameFont.draw_runs_centered(self, [["E", GameFont.YELLOW], ["  EŞYA SEÇ", GameFont.WHITE]], Vector2(0.0, -296.0), 24, pulse)
		GameFont.draw_centered(self, "BİRİNİ ALIRSAN DİĞERİ GÖLGE'NİN OLUR", Vector2(0.0, -270.0), 15, Color(SHADOW, 0.9), false)


## Sunaklar yükselirken yukarıdan inen ışık sütunu (önce parlak, sonra söner).
func _draw_beam(rise: float) -> void:
	if rise >= 1.0:
		return
	var a := (1.0 - rise) * 0.35
	var w := SPACING + 120.0
	draw_rect(Rect2(-w * 0.5, -420.0, w, 420.0), Color(accent, a * 0.35))
	draw_rect(Rect2(-w * 0.28, -420.0, w * 0.56, 420.0), Color(accent, a * 0.55))


func _draw_altar(i: int, x: float, rise_k: float) -> void:
	var item := choice.items[i]
	var done := choice.is_done()
	var is_chosen := done and i == choice.chosen
	var is_left := done and not is_chosen
	var rise_dy := (1.0 - rise_k) * 96.0
	var rect := Rect2(x - ALTAR.x * 0.5, -ALTAR.y + rise_dy, ALTAR.x, ALTAR.y)
	# Sunak: çizim varsa o, yoksa yer tutucu.
	var file := "altar_rise" if not is_risen() else "altar_idle"
	var art_t := _t
	if is_chosen:
		file = "altar_take"
		art_t = _since
	elif is_left:
		file = "altar_dim"
		art_t = _since
	if not Art.draw(self, file, rect, art_t):
		_draw_placeholder(x, rise_dy, item, is_chosen, is_left)
	if not is_risen():
		return
	var cell_y := -ALTAR.y - 8.0 + 3.0 * sin(_t * 2.1 + float(i) * 1.3)
	var cell := Rect2(x - CELL * 0.5, cell_y - CELL, CELL, CELL)
	if not done:
		_draw_floating_item(item, cell, x)
	elif is_chosen:
		_draw_taken_burst(cell)
		GameFont.draw_centered(self, "ALINDI", Vector2(x, cell.position.y - 14.0), 16, Color(GameFont.YELLOW, 0.9), false)
	else:
		_draw_shadow_grab(item, cell, x)


## Süzülen eşya: nadirlik renginde hâle, eşya kutusu ve altında adı.
func _draw_floating_item(item: ItemData, cell: Rect2, x: float) -> void:
	var c := item.color()
	var glow := 0.12 + 0.05 * sin(_t * 3.0)
	draw_circle(cell.get_center(), CELL * 0.95, Color(c, glow))
	draw_circle(cell.get_center(), CELL * 0.62, Color(c, glow * 1.4))
	ItemView.draw_cell(self, cell, item, 1, false, _t)
	var title := item.upper_name()
	var size := 16
	while size > 11 and GameFont.width(title, size) > SPACING - 24.0:
		size -= 1
	GameFont.draw_centered(self, title, Vector2(x, cell.position.y - 16.0), size, c)
	GameFont.draw_centered(self, item.rarity_name(), Vector2(x, cell.position.y - 36.0), 13, Color(c, 0.8), false)


## Seçilen sunakta ışık patlaması: genişleyen halkalar.
func _draw_taken_burst(cell: Rect2) -> void:
	if _since < 0.0 or _since > TAKE_TIME:
		return
	var k := _since / TAKE_TIME
	var center := cell.get_center()
	draw_arc(center, 20.0 + 90.0 * k, 0.0, TAU, 40, Color(GameFont.YELLOW, (1.0 - k) * 0.9), 4.0 * (1.0 - k) + 1.0, true)
	draw_circle(center, 60.0 * (1.0 - k), Color(1.0, 0.95, 0.7, (1.0 - k) * 0.5))


## Seçilmeyen sunakta: eşya aşağı batıp morlaşır ve Gölge alır (çizim varsa Gölge'nin eli).
func _draw_shadow_grab(item: ItemData, cell: Rect2, x: float) -> void:
	var k := clampf(_since / DIM_TIME, 0.0, 1.0)
	var label_pos := Vector2(x, cell.position.y - 14.0)
	if Art.draw(self, "fx_umbra_grab", Rect2(x - 128.0, -ALTAR.y - 190.0, 256.0, 256.0), _since):
		GameFont.draw_centered(self, "GÖLGE'NİN", label_pos, 16, Color(SHADOW, 0.9), false)
		return
	if k < 1.0:
		var sunk := Rect2(cell.position + Vector2(0.0, 46.0 * k), cell.size)
		ItemView.draw_cell(self, sunk, item, 1, false, _t)
		draw_rect(sunk, Color(0.28, 0.12, 0.45, 0.25 + 0.7 * k))
		draw_circle(sunk.get_center(), CELL * (0.9 + 0.5 * k), Color(SHADOW, 0.12 * (1.0 - k)))
	GameFont.draw_centered(self, "GÖLGE'NİN", label_pos, 16, Color(SHADOW, 0.9), false)


## Yer tutucu sunak: taş kaide, üstte levha ve rün çizgisi. Nadirlik rengi kenarda görünür.
func _draw_placeholder(x: float, rise_dy: float, item: ItemData, is_chosen: bool, is_left: bool) -> void:
	var stone := Color(0.17, 0.13, 0.24)
	var edge := item.color()
	if is_left:
		edge = Color(SHADOW, 0.55)
		stone = Color(0.1, 0.07, 0.15)
	elif is_chosen:
		edge = Color(GameFont.YELLOW, 0.9)
	draw_rect(Rect2(x - 52.0, -18.0 + rise_dy, 104.0, 18.0), stone.darkened(0.25))
	draw_rect(Rect2(x - 34.0, -64.0 + rise_dy, 68.0, 48.0), stone)
	draw_rect(Rect2(x - 46.0, -78.0 + rise_dy, 92.0, 14.0), stone.lightened(0.1))
	draw_rect(Rect2(x - 46.0, -78.0 + rise_dy, 92.0, 14.0), edge, false, 2.0)
	var pulse := 0.5 + 0.2 * sin(_t * 3.0)
	draw_rect(Rect2(x - 3.0, -58.0 + rise_dy, 6.0, 32.0), Color(edge, pulse if not is_left else 0.25))
