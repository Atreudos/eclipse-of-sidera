extends ItemEffect
## Kıvılcım: oyuncunun vuruşları düşmanı tutuşturur (EnemyBase.ignite; yanma hasarı kaynaksızdır, ritim/kombo doldurmaz).

const BURN_TIME := 1.8


func on_acquire() -> void:
	listen(EventBus.damage_dealt, _on_damage)


func _on_damage(target: Node, _amount: int, source: Node) -> void:
	if source != owner:
		return
	var enemy := target as EnemyBase
	if enemy != null and not enemy.dead:
		enemy.ignite(BURN_TIME)
