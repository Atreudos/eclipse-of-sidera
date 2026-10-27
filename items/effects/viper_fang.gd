extends ItemEffect
## Engerek Dişi Kolyesi: parry'lediğin saldırının sahibini zehirler (saniyede 2 hasar).
## Gölge alırsa (Umbra dövüşü): seni parry'lerse sana aynı zehri bırakır. Güç birebir aynı.

const DPS := 2.0
const DURATION := 1.5


func on_acquire() -> void:
	listen(EventBus.parry_success, _on_parry)


func _on_parry(actor: Node, hitbox: Node) -> void:
	if actor != owner:
		return
	var hb := hitbox as Hitbox
	if hb == null:
		return
	var enemy := hb.attacker() as EnemyBase
	if enemy != null and is_instance_valid(enemy) and not enemy.dead:
		enemy.poison(DPS, DURATION)
