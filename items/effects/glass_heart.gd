extends ItemEffect
## Cam Kalp (lanetli): canın 1'e düşer. (Parry penceresi x2 ItemDB'de modifier olarak verilir.)


func on_acquire() -> void:
	var max_hp := owner.stats.int_value("max_health")
	owner.stats.add_modifier(self, "max_health", -float(max_hp - 1))
	owner.health = mini(owner.health, 1)


func on_remove() -> void:
	owner.stats.remove_modifiers(self)
