class_name Aries
extends Taurus
## Aries (Koç): zırhlı, ağır ve yavaş. Uzun, güçlü bir hamleyle kafa atar.
## ÖNDEN vuruşlar zırha çarpar (hasar 1 azalır, geri itmez, saldırısı bölünmez); ARKASINDAN ve sersemken tam hasar alır.
## Hamlesi bir duvara/yere kenarına çarparsa kafası takılır: uzun süre sersemler (fırsat). Parry'lenirse de sersemler (Taurus gibi).

## Zırhın önden vuruşta düştüğü hasar.
const FRONT_ARMOR := 1
## Duvara çarpınca sersemleme süresi (sn).
const CRASH_STUN := 1.6
## Hamlenin ilk bu kadar saniyesinde duvar çarpması sayılmaz (hamle yeni başlarken sürtünme).
const CRASH_GRACE := 0.08


func anim_folder() -> String:
	return "res://assets/sprites/aries"


func _ai(delta: float) -> void:
	if _phase == Phase.LUNGE and _hit_wall() and _timer < lunge_time - CRASH_GRACE:
		_crash()
		return
	super._ai(delta)


## Hamle sırasında düz bir duvara (oyuncuya ya da düşmana değil) çarptık mı?
func _hit_wall() -> bool:
	if not is_on_wall():
		return false
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		if col.get_collider() is StaticBody2D and absf(col.get_normal().x) > 0.6:
			return true
	return false


func _crash() -> void:
	attack_hitbox.active = false
	velocity.x = -facing * 140.0
	stun(tuning.stun_time(CRASH_STUN, PARRY_STUN_FLOOR))
	_phase = Phase.RECOVER
	_timer = 0.4
	RingFx.spawn(get_parent(), global_position + Vector2(facing * 28.0, -8.0), Color(1.0, 0.9, 0.6, 0.9), 8.0, 56.0, 0.3)
	Sfx.play("hit", -2.0)


func on_hit_by(hitbox: Hitbox) -> bool:
	if dead:
		return false
	if is_stunned() or not _front_hit(hitbox):
		return super.on_hit_by(hitbox)
	# Önden: zırh.
	var amount := maxi(hitbox.damage - FRONT_ARMOR, 0)
	if amount > 0:
		take_damage(amount, hitbox.source)
	RingFx.spawn(get_parent(), global_position + Vector2(facing * 18.0, -10.0), Color(0.8, 0.88, 1.0, 0.9), 4.0, 26.0, 0.18)
	Sfx.play("hit", -9.0)
	return true


## Vuruş ön tarafımızdan mı geldi?
func _front_hit(hitbox: Hitbox) -> bool:
	return hit_from_front(hitbox)
