class_name Libra
extends Sagitta
## Libra (Terazi): iki kefeli mermi atar: bir ALTIN (parry'lenebilir) "denge küresi" ve yanında bir KIRMIZI küre (kaçmalısın).
## Altın küre PARRY'lenince DENGE bozulur: küre sahibine döner ve AYNI hasarla en yakın diğer düşmana da bir kopyası gider
## (bkz. BalanceOrb). Yani doğru parry iki düşmanı birden vurur.

const BALANCE_ORB := preload("res://combat/balance_orb.tscn")

## Kırmızı kürenin altın küreden sapma açısı (radyan).
const RED_SPREAD := 0.32


func anim_folder() -> String:
	return "res://assets/sprites/libra"


func _apply_tuning() -> void:
	super._apply_tuning()
	gold_every = 1  # her atışta altın küre var: uyarı hep altın

func _fire() -> void:
	if target == null:
		return
	var origin := global_position + Vector2(facing * 24.0, -10.0)
	var dir := (_aim_point(origin) - origin).normalized()
	var gold := BALANCE_ORB.instantiate() as BalanceOrb
	get_parent().add_child(gold)
	gold.global_position = origin
	gold.launch(dir * projectile_speed, true, self, tuning.scale_damage(1))
	# Yan kefe: kırmızı. Yön her atışta değişir (üst / alt).
	var red := PROJECTILE.instantiate() as Projectile
	get_parent().add_child(red)
	red.global_position = origin
	var side := 1.0 if _shots % 2 == 0 else -1.0
	red.launch(dir.rotated(RED_SPREAD * side) * projectile_speed * 0.92, false, self, tuning.scale_damage(1))
	anim.trigger("attack", 0.35)
	Sfx.play("shoot", -3.0, 0.9, 0.05)
