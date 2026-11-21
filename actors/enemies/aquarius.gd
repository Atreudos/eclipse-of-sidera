class_name Aquarius
extends Sagitta
## Aquarius (Kova): mesafeyi korur; oyuncunun durduğu yere kırmızı uyarıyla SU DÖKER. Uyarı bitince su çarpar (1 hasar),
## yerde birkaç saniye SU BİRİKİNTİSİ kalır: içinde yürürken yavaşlarsın (ıslak). Hareket etmeyen oyuncuyu cezalandırır.

const PUDDLE := preload("res://combat/water_puddle.tscn")


func anim_folder() -> String:
	return "res://assets/sprites/aquarius"


func _apply_tuning() -> void:
	super._apply_tuning()
	gold_every = 0  # su parry'lenmez: uyarı hep kırmızı

func _fire() -> void:
	if target == null:
		return
	var puddle := PUDDLE.instantiate() as WaterPuddle
	get_parent().add_child(puddle)
	puddle.global_position = Vector2(target.global_position.x, target.feet_y())
	puddle.setup(self, tuning.scale_damage(1))
	anim.trigger("attack", 0.35)
	Sfx.play("shoot", -4.0, 0.6, 0.05)
