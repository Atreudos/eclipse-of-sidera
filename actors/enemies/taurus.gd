class_name Taurus
extends EnemyBase
## Taurus: yaklaşır, uyarı verir, atılıp vurur. Atılma ALTIN ise parry'lenince sersemler;
## bazen KIRMIZI (2 hasar, parry'lenemez) atılır, o zaman dash'lemelisin.

@export var walk_speed := 115.0
@export var lunge_range := 210.0
@export var telegraph_time := 0.55
@export var lunge_speed := 640.0
@export var lunge_time := 0.28
@export var recover_time := 0.85
@export_range(0.0, 1.0) var red_chance := 0.25

enum Phase { CHASE, TELEGRAPH, LUNGE, RECOVER }

var _phase := Phase.CHASE
var _timer := 0.0
var _cooldown := 0.0
var _red := false

## Saldırıya geçmek için hedefle ayak seviyesi farkı en fazla bu kadar olabilir (px).
const ATTACK_LEVEL_TOLERANCE := 72.0

@onready var attack_hitbox: Hitbox = $AttackHitbox


func anim_folder() -> String:
	return "res://assets/sprites/taurus"


func _ready() -> void:
	super._ready()
	attack_hitbox.source = self
	attack_hitbox.set_faction("enemy")
	attack_hitbox.active = false
	attack_hitbox.parried.connect(_on_attack_parried)
	_cooldown = randf_range(0.6, 1.2)


func _ai(delta: float) -> void:
	if target == null or target.dead:
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	var dx := target.global_position.x - global_position.x
	match _phase:
		Phase.CHASE:
			# Hedef başka bir yüksekliktedeyse: platforma zıpla / aşağı in (yatay saldırı boşa gider).
			if nav.update(delta, walk_speed * 1.2):
				return
			if not is_on_floor():
				return
			facing = 1 if dx > 0.0 else -1
			if absf(dx) > lunge_range * 0.5:
				velocity.x = facing * walk_speed
			else:
				velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			var same_level := absf(target.feet_y() - feet_y()) <= ATTACK_LEVEL_TOLERANCE
			if same_level and absf(dx) <= lunge_range and _cooldown <= 0.0:
				_begin_telegraph()
		Phase.TELEGRAPH:
			velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
			_timer -= delta
			if _timer <= 0.0:
				_begin_lunge()
		Phase.LUNGE:
			velocity.x = facing * lunge_speed
			_timer -= delta
			if _timer <= 0.0:
				_end_lunge()
		Phase.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
			_timer -= delta
			if _timer <= 0.0:
				_phase = Phase.CHASE
				_cooldown = randf_range(0.5, 1.1)


func _begin_telegraph() -> void:
	_red = randf() < red_chance
	_phase = Phase.TELEGRAPH
	_timer = telegraph_time
	armored = true
	facing = 1 if target.global_position.x > global_position.x else -1
	set_tell(Tell.RED if _red else Tell.GOLD)
	anim.trigger("telegraph", telegraph_time)


func _begin_lunge() -> void:
	_phase = Phase.LUNGE
	_timer = lunge_time
	attack_hitbox.position = Vector2(facing * 28.0, 0.0)
	attack_hitbox.parryable = not _red
	attack_hitbox.damage = 2 if _red else 1
	attack_hitbox.active = true
	anim.trigger("attack", lunge_time)


func _end_lunge() -> void:
	attack_hitbox.active = false
	armored = false
	set_tell(Tell.NONE)
	_phase = Phase.RECOVER
	_timer = recover_time
	anim.trigger("recover", recover_time)


func pick_animation() -> String:
	if not dead and stun_t <= 0.0 and knock_t <= 0.0:
		match _phase:
			Phase.TELEGRAPH:
				return "telegraph"
			Phase.LUNGE:
				return "attack"
			Phase.RECOVER:
				return "recover"
	return super.pick_animation()


func _on_attack_parried(_by: Node) -> void:
	attack_hitbox.active = false
	stun(0.9)
	velocity.x = 0.0
	_phase = Phase.RECOVER
	_timer = 0.4


func _on_stunned() -> void:
	attack_hitbox.active = false


func _on_death() -> void:
	attack_hitbox.active = false
