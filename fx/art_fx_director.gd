class_name ArtFxDirector
extends Node
## Çizim efektlerinin yönetmeni: EventBus olaylarını ve oyuncunun durumunu dinler, çizim listesindeki `fx_*` şeritlerini
## doğru anda oynatır (ArtFx). Çizim yoksa hiçbir şey yapmaz; kod efektleri (RingFx, DustFx, BurstFx...) kendi yerinde çalışır.
## Koşu denetleyicisi bir tane ekler. Godot'ta henüz koşulmadı.

var _player: Player = null
var _imm := -1
var _timestop := false


func _ready() -> void:
	EventBus.parry_success.connect(_on_parry)
	EventBus.parry_started.connect(_on_parry_started)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.healed.connect(_on_healed)
	EventBus.item_acquired.connect(_on_item)
	EventBus.item_purchased.connect(_on_purchased)


func _exit_tree() -> void:
	if _player != null and is_instance_valid(_player) and _player.attack_started.is_connected(_on_attack):
		_player.attack_started.disconnect(_on_attack)
	var pairs: Array = [
		[EventBus.parry_success, _on_parry], [EventBus.parry_started, _on_parry_started], [EventBus.enemy_died, _on_enemy_died],
		[EventBus.healed, _on_healed], [EventBus.item_acquired, _on_item], [EventBus.item_purchased, _on_purchased],
	]
	for pair in pairs:
		var sig: Signal = pair[0]
		var cb: Callable = pair[1]
		if sig.is_connected(cb):
			sig.disconnect(cb)


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
		_imm = -1
		if _player != null and not _player.attack_started.is_connected(_on_attack):
			_player.attack_started.connect(_on_attack)
		return
	var parent := _player.get_parent()
	var imm := _player.immunity
	if _imm >= 0 and imm != _imm:
		ArtFx.play(parent, "fx_immunity_gain" if imm > _imm else "fx_immunity_hit", _player.global_position, {"follow": _player})
	_imm = imm
	var ts := TimeStop.active
	if ts and not _timestop:
		ArtFx.play(parent, "fx_timestop_burst", _player.global_position)
		ArtFx.play(parent, "fx_timestop_ring", _player.global_position, {"follow": _player, "life": 1.5})
	_timestop = ts


func _on_parry(actor: Node, _hitbox: Node) -> void:
	var a := actor as Node2D
	if a == null or not is_instance_valid(a):
		return
	var f := float(a.get("facing")) if "facing" in a else 1.0
	ArtFx.play(a.get_parent(), "fx_parry_flash", a.global_position + Vector2(f * 36.0, -6.0))


func _on_parry_started(actor: Node) -> void:
	var p := actor as Player
	if p == null or not is_instance_valid(p):
		return
	var k := maxf(float(p.stats.value("parry_zone_radius")) / 64.0, 0.5)
	ArtFx.play(p.get_parent(), "fx_parry_zone", p.global_position, {"follow": p, "life": p.parry_window_time() + 0.05, "scale": k, "z": 20})


func _on_enemy_died(enemy: Node) -> void:
	var e := enemy as Node2D
	if e == null or not is_instance_valid(e):
		return
	ArtFx.play(e.get_parent(), "fx_enemy_death", e.global_position)


func _on_healed(actor: Node, amount: int) -> void:
	var p := actor as Player
	if p == null or amount <= 0 or not is_instance_valid(p):
		return
	ArtFx.play(p.get_parent(), "fx_heal", p.global_position + Vector2(0.0, 26.0), {"follow": p, "offset": Vector2(0.0, 26.0)})


func _on_item(actor: Node, _item: ItemData) -> void:
	_item_burst(actor)


func _on_purchased(actor: Node, _item: ItemData, _price: int) -> void:
	_item_burst(actor)


func _item_burst(actor: Node) -> void:
	var p := actor as Player
	if p == null or not is_instance_valid(p):
		return
	ArtFx.play(p.get_parent(), "fx_item_pickup", p.global_position, {"follow": p})


## Kılıç izi: 1., 2. ve 3. vuruş (yumruk vuruşları iz bırakmaz).
func _on_attack(combo_index: int) -> void:
	var p := _player
	if p == null or not is_instance_valid(p) or p._combo_weapon != WeaponDB.SWORD:
		return
	var n := (combo_index % 3) + 1
	ArtFx.play(p.get_parent(), "fx_slash%d" % n, p.global_position + Vector2(float(p.facing) * 8.0, -6.0), {"flip": p.facing < 0, "z": 22})
