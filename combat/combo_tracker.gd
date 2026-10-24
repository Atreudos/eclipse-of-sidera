class_name ComboTracker
extends Node
## Kombo sayacı (oyuncunun çocuğu). Her vuruş ve her parry kombo süresini tazeler (varsayılan 1 sn,
## stat: "combo_window"). Süre dolarsa kombo biter ve her şey SIFIRLANIR; sonraki vuruş yeni bir
## kombonun ilk vuruşu olur.
##
## Düşmana vurulunca hasar sayısı (DamageNumber) çıkar; kombo bilgisi düşmanın üstündeki ComboTag'de görünür.
## Süre oyun zamanıyla akar, yani hitstop sırasında kombo süresi de durur.

signal updated(hits: int, parries: int, damage: int)
signal ended(hits: int, parries: int, damage: int)

## Kombo "COMBO" yazısı bu kadar olaydan (vuruş + parry) sonra görünür. 1. vuruş sıradan sayılır.
const COMBO_MIN_EVENTS := 2

var hits := 0
var parries := 0
var damage := 0
## Kalan kombo süresi (sn). 0 = kombo yok.
var time_left := 0.0
## Son olayda tanınan süre. Barın doluluk oranı time_left / window.
var window := 1.0
## Göstergenin üstünde duracağı düşman (son vurulan / parry'lenen).
var last_target: Node2D = null
var player: Player
## Testlerde ve özel durumlarda kapatılabilir.
var spawn_numbers := true

var _side := 1.0
var _tag: ComboTag


func _ready() -> void:
	player = get_parent() as Player
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.parry_success.connect(_on_parry_success)
	if player != null:
		player.died.connect(reset)
	_tag = ComboTag.new()
	_tag.tracker = self
	add_child(_tag)


func is_active() -> bool:
	return time_left > 0.0


## Vuruş + parry sayısı.
func events() -> int:
	return hits + parries


## İkinci olaydan itibaren gerçek bir "kombo" sayılır.
func is_combo() -> bool:
	return events() >= COMBO_MIN_EVENTS


## Kalan sürenin oranı (1 = yeni tazelendi, 0 = bitti).
func fraction() -> float:
	return clampf(time_left / maxf(window, 0.001), 0.0, 1.0)


func _process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if time_left <= 0.0:
		return
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		_finish()


## Düşmana vuruş kaydeder (sayı çıkarır, süreyi tazeler).
func register_hit(target: Node2D, amount: int) -> void:
	hits += 1
	damage += amount
	if target != null:
		last_target = target
		if spawn_numbers:
			_spawn_number(target, amount)
	_refresh()


## Başarılı parry kaydeder (süreyi tazeler). `from`: parry'lenen saldırıyı yapan düşman.
func register_parry(from: Node2D = null) -> void:
	parries += 1
	if from != null:
		last_target = from
	_refresh()


## Kombo bitmeden sıfırlar (ölüm vb.).
func reset() -> void:
	if time_left > 0.0 or events() > 0:
		time_left = 0.0
		_finish()


func _refresh() -> void:
	window = player.stats.value("combo_window") if player != null and player.stats != null else 1.0
	time_left = window
	updated.emit(hits, parries, damage)
	EventBus.combo_updated.emit(hits, parries, damage)


func _finish() -> void:
	var h := hits
	var p := parries
	var d := damage
	hits = 0
	parries = 0
	damage = 0
	ended.emit(h, p, d)
	EventBus.combo_ended.emit(h, p, d)


func _spawn_number(target: Node2D, amount: int) -> void:
	var parent: Node = player.get_parent() if player != null else get_parent()
	_side = -_side
	var at := target.global_position + Vector2(randf_range(-10.0, 10.0), -30.0)
	DamageNumber.spawn(parent, at, amount, _side * randf_range(0.4, 1.0))


func _on_damage_dealt(target: Node, amount: int, source: Node) -> void:
	if player == null or source != player:
		return
	var t := target as ActorBase
	if t == null or t == player or t.faction != "enemy":
		return
	register_hit(t, amount)


func _on_parry_success(actor: Node, hitbox: Node) -> void:
	if actor != player:
		return
	var hb := hitbox as Hitbox
	var from: Node2D = null
	if hb != null:
		from = hb.attacker() as Node2D
	register_parry(from)
