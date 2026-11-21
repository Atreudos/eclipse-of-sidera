class_name Cancer
extends Taurus
## Cancer (Yengeç): yavaş, kalkanlı. Kalkan önden gelen her vuruşu durdurur (hasar yok).
## Çözüm: arkasına geç (dash'le içinden geçebilirsin) ya da kıskaç hamlesini PARRY'le: kalkan kırılır ve sersemler.
## Hamlesi kısa menzilli bir kıskaç çarpmasıdır.

var shield_up := true


func anim_folder() -> String:
	return "res://assets/sprites/cancer"


func _process(delta: float) -> void:
	super._process(delta)
	queue_redraw()


func _draw() -> void:
	super._draw()
	if not shield_up or dead:
		return
	var col := Color(0.75, 0.9, 1.0, 0.85)
	var c := Vector2(float(facing) * 22.0, -6.0)
	if facing > 0:
		draw_arc(c, 22.0, -PI * 0.5, PI * 0.5, 14, col, 5.0)
	else:
		draw_arc(c, 22.0, PI * 0.5, PI * 1.5, 14, col, 5.0)


func on_hit_by(hitbox: Hitbox) -> bool:
	if dead:
		return false
	if shield_up and not is_stunned() and signf(hitbox.global_position.x - global_position.x) == float(facing):
		RingFx.spawn(get_parent(), global_position + Vector2(facing * 22.0, -8.0), Color(0.75, 0.9, 1.0, 0.9), 4.0, 28.0, 0.18)
		Sfx.play("hit", -9.0)
		return true  # kalkan: hasar yok
	return super.on_hit_by(hitbox)


## Kıskaç parry'lenince kalkan kırılır.
func _on_attack_parried(by: Node) -> void:
	super._on_attack_parried(by)
	break_shield()


func break_shield() -> void:
	if not shield_up:
		return
	shield_up = false
	base_tint = Color(1.0, 0.78, 0.78)
	Sfx.play("shield_break", -2.0)
	RingFx.spawn(get_parent(), global_position + Vector2(facing * 14.0, -8.0), Color(0.75, 0.9, 1.0, 0.9), 6.0, 50.0, 0.3)
