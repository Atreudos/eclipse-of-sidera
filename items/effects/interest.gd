extends ItemEffect
## Faiz: her dash hasar biriktirir (en çok 6). Parry'de birikenin hepsi, etraftaki düşmanlara patlar.

const MAX_STACKS := 6
const RADIUS := 170.0

var stacks := 0


func on_acquire() -> void:
	listen(EventBus.dash_used, _on_dash)
	listen(EventBus.parry_success, _on_parry)


func hud_text() -> String:
	return "FAİZ %d" % stacks if stacks > 0 else ""


func _on_dash(actor: Node) -> void:
	if actor == owner:
		stacks = mini(stacks + 1, MAX_STACKS)


func _on_parry(actor: Node, _hitbox: Node) -> void:
	if actor != owner or stacks <= 0:
		return
	var dmg := stacks
	stacks = 0
	RingFx.spawn(owner.get_parent(), owner.global_position, Color(1.0, 0.85, 0.3, 0.9), 20.0, RADIUS, 0.35)
	EventBus.screen_shake.emit(4.0 + float(dmg), 0.22)
	Sfx.play("hit", -2.0, 0.8)
	for e in owner.get_tree().get_nodes_in_group("enemies"):
		var enemy := e as EnemyBase
		if enemy != null and not enemy.dead and enemy.global_position.distance_to(owner.global_position) <= RADIUS:
			enemy.take_damage(dmg, owner)
