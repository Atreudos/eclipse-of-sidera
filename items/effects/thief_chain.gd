extends ItemEffect
## Hırsızın Zinciri: parry yaptığın düşman yere fazladan antika para (altın) düşürür.

const COINS := 1


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
		Coin.drop(enemy.get_parent(), enemy.global_position + Vector2(0.0, -14.0), COINS, true)
