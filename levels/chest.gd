class_name Chest
extends Node2D
## Sandık: yaklaşıp E'ye basınca açılır. Türleri: "gold" (para saçar), "item" (eşya ya da yemek), "heal" (can verir),
## "rich" (bol para + eşya). `chest_id` doluysa açıldığı kayda geçer (`Chest.opened_ids`, koşu boyunca); bir daha açılmaz.
## Orijin = ayak noktası. Çizim: `chest_closed` / `chest_open` (yoksa yer tutucu).

signal looted(chest: Chest, text: String, color: Color)

const RANGE_X := 80.0
const RANGE_Y := 120.0

## Bu koşuda açılmış sandıkların kimlikleri (koşu başında RunController sıfırlar; kayıtla saklanır).
static var opened_ids: Dictionary = {}

var kind := "gold"
var floor_no := 1
var chest_id := ""
var seed_value := 1
var opened := false
## Kilitliyken açılmaz (bulmaca ödülü); kilit kalkınca açılır.
var locked := false
var in_range := false

var _t := 0.0
var _open_t := 0.0
var _player: Player


func _ready() -> void:
	z_index = -1
	add_to_group("chests")
	if chest_id != "" and opened_ids.has(chest_id):
		opened = true
		_open_t = 1.0
	_hook_player()


func _exit_tree() -> void:
	if _player != null and is_instance_valid(_player) and _player.interacted.is_connected(_on_interacted):
		_player.interacted.disconnect(_on_interacted)


func _hook_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player != null and not _player.interacted.is_connected(_on_interacted):
		_player.interacted.connect(_on_interacted)


func _on_interacted() -> void:
	if in_range and not opened and ItemView.active_menu == null and _player != null and not _player.dead:
		if locked:
			Sfx.play("ui_deny", -6.0)
		else:
			open_by(_player)


## Sandığı `p` için açar. Açıldıysa true.
func open_by(p: Player) -> bool:
	if opened or locked or p == null or not is_instance_valid(p) or p.dead:
		return false
	opened = true
	if chest_id != "":
		opened_ids[chest_id] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	Sfx.play("pickup", -2.0)
	var text := ""
	var color := GameFont.YELLOW
	match kind:
		"item":
			var r := _give_item(p, rng)
			if r.is_empty():
				r = _give_gold(rng, false)
			text = r["text"]
			color = r["color"]
		"heal":
			var healed := p.heal(2)
			Sfx.play("heal", -3.0)
			if healed > 0:
				text = "CAN +%d" % healed
				color = Color(0.5, 1.0, 0.6)
			else:
				var g := _give_gold(rng, false)
				text = g["text"]
				color = g["color"]
		"rich":
			var g := _give_gold(rng, true)
			text = g["text"]
			color = g["color"]
			var r := _give_item(p, rng)
			if not r.is_empty():
				text = r["text"]
				color = r["color"]
		_:
			var g := _give_gold(rng, false)
			text = g["text"]
			color = g["color"]
	looted.emit(self, text, color)
	return true


func _give_gold(rng: RandomNumberGenerator, rich: bool) -> Dictionary:
	var small := 5 + floor_no / 3 + rng.randi_range(0, 3)
	var antique := 1 + floor_no / 6
	if rich:
		small += 6
		antique += 2
	var at := get_parent() if get_parent() != null else self
	Coin.drop(at, global_position + Vector2(0.0, -40.0), small, false)
	Coin.drop(at, global_position + Vector2(0.0, -40.0), antique, true)
	var total := small + antique * Coin.ANTIQUE_VALUE
	get_tree().create_timer(0.9).timeout.connect(_vacuum_coins)
	return {"text": "ALTIN  %d" % total, "color": GameFont.YELLOW}


func _vacuum_coins() -> void:
	if not is_inside_tree():
		return
	get_tree().call_group("coins", "vacuum")


## Sahip olunmayan, Gölge'de olmayan, dükkânda satılabilen bir eşya verir. Veremezse boş sözlük.
func _give_item(p: Player, rng: RandomNumberGenerator) -> Dictionary:
	var inv := p.inventory
	if inv == null:
		return {}
	var owned := inv.owned_ids()
	var umbra := GameState.umbra_ids()
	var pool: Array[ItemData] = []
	for it in ItemDB.all():
		if ShopStock.sellable(it) and not (it.id in owned) and not (it.id in umbra) and inv.can_give(it):
			pool.append(it)
	if pool.is_empty():
		return {}
	var total := 0.0
	for it in pool:
		total += ShopStock.weight_of(it, floor_no)
	var roll := rng.randf() * total
	var picked := pool[pool.size() - 1]
	for it in pool:
		roll -= ShopStock.weight_of(it, floor_no)
		if roll <= 0.0:
			picked = it
			break
	if inv.add(picked) != "":
		return {}
	Sfx.play("equip", -3.0)
	return {"text": "BULUNDU  " + picked.upper_name(), "color": picked.color()}


func _process(delta: float) -> void:
	_t += delta
	if opened:
		_open_t = minf(_open_t + delta * 4.0, 1.0)
	if _player == null or not is_instance_valid(_player):
		_hook_player()
	in_range = false
	if _player != null and is_instance_valid(_player) and not _player.dead:
		var d := _player.global_position - global_position
		in_range = absf(d.x) <= RANGE_X and absf(d.y) <= RANGE_Y
	queue_redraw()


func _draw() -> void:
	var art := "chest_open" if opened else "chest_closed"
	if not Art.draw(self, art, Rect2(-48.0, -64.0, 96.0, 64.0), _t):
		var body := Color(0.34, 0.2, 0.1)
		var trim := Color(1.0, 0.76, 0.38) if kind == "rich" else Color(0.7, 0.5, 0.25)
		draw_rect(Rect2(-34.0, -34.0, 68.0, 34.0), body)
		draw_rect(Rect2(-34.0, -34.0, 68.0, 34.0), trim, false, 2.0)
		var lift := _open_t * 22.0
		var lid := Rect2(-36.0, -50.0 - lift, 72.0, 18.0)
		draw_rect(lid, body.lightened(0.1))
		draw_rect(lid, trim, false, 2.0)
		if opened:
			draw_rect(Rect2(-28.0, -34.0, 56.0, 6.0), Color(1.0, 0.85, 0.4, 0.6 * (1.0 - _open_t * 0.5)))
		else:
			draw_rect(Rect2(-5.0, -38.0, 10.0, 12.0), trim)
			var glow := 0.5 + 0.5 * sin(_t * 3.0)
			draw_circle(Vector2(0.0, -30.0), 46.0, Color(1.0, 0.8, 0.35, 0.05 + 0.04 * glow))
	if in_range and not opened:
		var pulse := 0.7 + 0.3 * sin(_t * 6.0)
		if locked:
			GameFont.draw_centered(self, "KİLİTLİ  BULMACAYI ÇÖZ", Vector2(0.0, -84.0), 20, Color(1.0, 0.5, 0.45, pulse))
		else:
			GameFont.draw_runs_centered(self, [["E", GameFont.YELLOW], ["  AÇ", GameFont.WHITE]], Vector2(0.0, -84.0), 22, pulse)
