extends ItemEffect
## Don: parry'lediğin saldırıyı yapan düşman uzun süre donar (sersemler, her vuruş x1.5 hasar alır).

const FREEZE_TIME := 2.2


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
		enemy.stun(FREEZE_TIME)
		RingFx.spawn(enemy.get_parent(), enemy.global_position, Color(0.6, 0.9, 1.0, 0.9), 12.0, 70.0, 0.4)
