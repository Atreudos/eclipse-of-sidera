class_name Hitbox
extends Area2D
## Hasar veren alan. Altın (parryable = true) veya kırmızı (parryable = false) olabilir.
## Çarpışmaları kendisi kontrol eder (polling), böylece kısa süreli açılıp kapanan
## saldırılar da güvenilir çalışır.

signal landed(hurtbox: Hurtbox)
signal parried(by: Node)
signal hit_world(body: Node)

@export var damage: int = 1
## true = altın (parry'lenebilir), false = kırmızı (kaçman gerekir)
@export var parryable: bool = true
@export_enum("player", "enemy") var faction: String = "enemy"
@export var collides_with_world: bool = false
@export var active: bool = true:
	set = set_active

## Saldırıyı başlatan aktör (Umbra sistemi ve eşyalar bunu kullanacak).
## Parry'lenen mermide `source` parry yapana geçer (hasar ona yazılsın diye); ilk sahibi `original_source`'ta kalır.
var source: Node = null
var original_source: Node = null

var _hit_targets: Array[Hurtbox] = []


func _ready() -> void:
	apply_faction()


func apply_faction() -> void:
	if faction == "player":
		collision_layer = Layers.PLAYER_HIT
		collision_mask = Layers.ENEMY_HURT
	else:
		collision_layer = Layers.ENEMY_HIT
		collision_mask = Layers.PLAYER_HURT
	if collides_with_world:
		collision_mask |= Layers.WORLD


func set_faction(new_faction: String) -> void:
	faction = new_faction
	apply_faction()


func set_active(value: bool) -> void:
	if value and not active:
		_hit_targets.clear()
	active = value


func clear_hit_targets() -> void:
	_hit_targets.clear()


func _physics_process(_delta: float) -> void:
	if not active:
		return
	for area in get_overlapping_areas():
		var target := area as Hurtbox
		if target == null or target in _hit_targets:
			continue
		_hit_targets.append(target)
		if target.receive_hit(self):
			landed.emit(target)
	if collides_with_world:
		for body in get_overlapping_bodies():
			hit_world.emit(body)
			break


## Saldırıyı ASIL yapan aktör (parry'den sonra bile). Geçersizse null.
func attacker() -> Node:
	if original_source != null and is_instance_valid(original_source):
		return original_source
	return source if source != null and is_instance_valid(source) else null


## Oyuncu parry yaptığında çağrılır.
func on_parried(by: Node) -> void:
	parried.emit(by)
	_on_parried(by)


func _on_parried(_by: Node) -> void:
	pass
