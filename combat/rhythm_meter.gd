class_name RhythmMeter
extends Node
## Ritim (agresiflik) metresi: oyuncunun çocuğu. Saldıran oyuncu ödüllendirilir, bekleyen zayıflar.
##
## Değer 0..100, dört kademe:  SOĞUK (0-25) -> ISINMIŞ (25-50) -> ATEŞLİ (50-75) -> COŞKULU (75-100).
## DOLDURAN: vuruş, parry (en çok), öldürme, dash ile saldırıdan sıyrılma (dodge).
## AZALAN:   ~2 sn hiçbir şey yapmazsan düşmeye başlar. Hasar alınca bir kademe aşağı iner.
## KADEME ETKİLERİ: koşma hızı, dash şarj hızı, hasar (Stats modifier'ı ile); Ateşli ve üstünde
##   parry'den can toparlama şansı. Oda temizlenince değer donar (kapıya yürürken kaybetmezsin).

signal changed(value: float, tier: int)
signal tier_changed(tier: int, previous: int)

const TIER_NAMES: Array[String] = ["SOĞUK", "ISINMIŞ", "ATEŞLİ", "COŞKULU"]
## Her kademenin başladığı değer.
const TIER_AT: Array[float] = [0.0, 25.0, 50.0, 75.0]
const MAX_VALUE := 100.0

## Kademe -> [[stat, ekleme, çarpım], ...]. Eşyalar da aynı Stats sistemine modifier ekler.
const TIER_EFFECTS: Array = [
	[],
	[["move_speed", 0.0, 1.06], ["dash_recharge", 0.0, 0.9]],
	[["move_speed", 0.0, 1.10], ["dash_recharge", 0.0, 0.75], ["attack_damage", 0.0, 1.5]],
	[["move_speed", 0.0, 1.16], ["dash_recharge", 0.0, 0.55], ["attack_damage", 0.0, 2.0], ["parry_window", 0.02, 1.0]],
]

@export var gain_hit := 4.0
@export var gain_parry := 12.0
@export var gain_kill := 7.0
@export var gain_dodge := 8.0
## Son kazanımdan bu kadar sn sonra değer düşmeye başlar.
@export var decay_delay := 2.0
## Düşme hızı (değer/sn).
@export var decay_rate := 14.0

## true ise hasar alınca ritim tamamen sıfırlanır (Coşku eşyası); false ise bir kademe düşer.
var drop_to_floor := false
## Parry'den can toparlama şansı, kademeye göre (testlerde değiştirilebilir).
var heal_chances: Array[float] = [0.0, 0.0, 0.15, 0.25]
var rng := RandomNumberGenerator.new()

var value := 0.0
var tier := 0
## true iken değer ne artar ne azalır (odalar arası geçiş).
var paused := false
var player: Player

var _idle := 0.0


## Değere karşılık gelen kademe.
static func tier_for(v: float) -> int:
	var t := 0
	for i in TIER_AT.size():
		if v >= TIER_AT[i]:
			t = i
	return t


static func tier_name(t: int) -> String:
	return TIER_NAMES[clampi(t, 0, TIER_NAMES.size() - 1)]


func _ready() -> void:
	player = get_parent() as Player
	rng.randomize()
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.parry_success.connect(_on_parry_success)
	EventBus.dodge_success.connect(_on_dodge_success)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.room_cleared.connect(_on_room_cleared)
	EventBus.room_entered.connect(_on_room_entered)
	if player != null:
		player.damaged.connect(_on_player_damaged)
		player.died.connect(_on_player_died)
	_apply_tier_effects()


func _exit_tree() -> void:
	if player != null and is_instance_valid(player) and player.stats != null:
		player.stats.remove_modifiers(self)


func _process(delta: float) -> void:
	tick(delta)


## Zamanı ilerletir: kazanımdan `decay_delay` sn sonra değer düşer.
func tick(delta: float) -> void:
	if paused or value <= 0.0 or _is_player_dead():
		return
	_idle += delta
	if _idle >= decay_delay:
		_set_value(value - decay_rate * _stat("rhythm_decay") * delta)


## Değeri artırır (kazanım). Düşme gecikmesi sıfırlanır.
func add(amount: float) -> void:
	if _is_player_dead():
		return
	_idle = 0.0
	_set_value(value + amount)


## Hasar alınca: bir kademe aşağı (bir önceki kademenin başına).
func drop_tier() -> void:
	if tier <= 0:
		return
	_idle = 0.0
	_set_value(TIER_AT[tier - 1])


func reset() -> void:
	_idle = 0.0
	_set_value(0.0)


func fraction() -> float:
	return clampf(value / MAX_VALUE, 0.0, 1.0)


## Mevcut kademe içindeki doluluk (0..1): çubuğun kademe parçalarını çizmek için.
func tier_fraction() -> float:
	var lo := TIER_AT[tier]
	var hi := TIER_AT[tier + 1] if tier + 1 < TIER_AT.size() else MAX_VALUE
	return clampf((value - lo) / (hi - lo), 0.0, 1.0)


func _set_value(v: float) -> void:
	var before := value
	value = clampf(v, 0.0, MAX_VALUE)
	var previous := tier
	tier = tier_for(value)
	if not is_equal_approx(before, value):
		changed.emit(value, tier)
		EventBus.rhythm_changed.emit(value, tier)
	if tier != previous:
		_apply_tier_effects()
		tier_changed.emit(tier, previous)
		EventBus.rhythm_tier_changed.emit(tier, previous)
		Sfx.play("tier_up" if tier > previous else "tier_down", -4.0, 1.0 + 0.08 * float(tier))


func _apply_tier_effects() -> void:
	if player == null or player.stats == null:
		return
	player.stats.remove_modifiers(self)
	for fx: Array in TIER_EFFECTS[tier]:
		player.stats.add_modifier(self, fx[0], fx[1], fx[2])


func _is_player_dead() -> bool:
	return player != null and is_instance_valid(player) and player.dead


# ---------------------------------------------------------------- olaylar

## Oyuncunun stat'ı (eşyalar "rhythm_gain" / "rhythm_decay" çarpanlarını değiştirir). Yoksa 1.
func _stat(stat_name: String) -> float:
	if player == null or player.stats == null or not player.stats.base.has(stat_name):
		return 1.0
	return player.stats.value(stat_name)


func _on_damage_dealt(target: Node, _amount: int, source: Node) -> void:
	if player == null or source != player:
		return
	var t := target as ActorBase
	if t == null or t == player or t.faction != "enemy":
		return
	add(gain_hit * _stat("rhythm_gain"))


func _on_parry_success(actor: Node, _hitbox: Node) -> void:
	if actor != player:
		return
	add(gain_parry * _stat("rhythm_gain"))
	var chance: float = heal_chances[tier]
	if chance > 0.0 and rng.randf() < chance:
		player.heal(1)


func _on_dodge_success(actor: Node, _hitbox: Node) -> void:
	if actor == player:
		add(gain_dodge * _stat("rhythm_gain"))


func _on_enemy_died(_enemy: Node) -> void:
	add(gain_kill * _stat("rhythm_gain"))


func _on_player_damaged(_amount: int, _source: Node) -> void:
	if drop_to_floor:
		reset()
	else:
		drop_tier()


func _on_player_died() -> void:
	paused = true


func _on_room_cleared(_index: int) -> void:
	paused = true


func _on_room_entered(_index: int) -> void:
	paused = false
	_idle = 0.0
