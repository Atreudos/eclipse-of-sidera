extends ItemEffect
## Soğukkanlı: başarılı parry'den sonra 1 sn boyunca dash şarj harcamaz.

const FREE_TIME := 1.0


func on_acquire() -> void:
	listen(EventBus.parry_success, _on_parry)


func on_remove() -> void:
	owner.free_dash_t = 0.0


func hud_text() -> String:
	return "SINIRSIZ DASH" if owner != null and owner.free_dash_t > 0.0 else ""


func _on_parry(actor: Node, _hitbox: Node) -> void:
	if actor == owner:
		owner.free_dash_t = FREE_TIME
