extends ItemEffect
## Yankılı Mermi: parry'lediğin mermi 3'e bölünür (orta mermi + iki yana açılan kopya).

const PROJECTILE := preload("res://combat/projectile.tscn")
const SPREAD := 0.38


func on_acquire() -> void:
	listen(EventBus.parry_success, _on_parry)


func _on_parry(actor: Node, hitbox: Node) -> void:
	if actor != owner:
		return
	var proj := hitbox as Projectile
	if proj == null or not is_instance_valid(proj) or proj.faction != "player":
		return
	var parent := proj.get_parent()
	if parent == null:
		return
	for side in [-1.0, 1.0]:
		var clone := PROJECTILE.instantiate() as Projectile
		parent.add_child(clone)
		clone.global_position = proj.global_position
		clone.launch((proj.velocity as Vector2).rotated(SPREAD * float(side)), false, owner, proj.damage)
		clone.set_faction("player")
		clone.clear_hit_targets()
