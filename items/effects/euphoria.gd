extends ItemEffect
## Coşku: Coşkulu kademede hasar +%50 (ritim kademe bonusunun üstüne), ama hasar alınca ritim tamamen sıfırlanır.

const DAMAGE_MULT := 1.5


func on_acquire() -> void:
	listen(EventBus.rhythm_tier_changed, _on_tier)
	owner.rhythm.drop_to_floor = true
	_apply(owner.rhythm.tier)


func on_remove() -> void:
	owner.stats.remove_modifiers(self)
	owner.rhythm.drop_to_floor = false


func _on_tier(tier: int, _previous: int) -> void:
	_apply(tier)


func _apply(tier: int) -> void:
	owner.stats.remove_modifiers(self)
	if tier >= 3:
		owner.stats.add_modifier(self, "attack_damage", 0.0, DAMAGE_MULT)
