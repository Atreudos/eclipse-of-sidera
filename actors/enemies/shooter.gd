class_name Shooter
extends EnemyBase
## Ateşçi: mesafeyi korur, uyarı verip mermi atar. Her 3. mermi KIRMIZI (parry'lenemez).

const PROJECTILE := preload("res://combat/projectile.tscn")

@export var fire_interval := 1.9
@export var telegraph_time := 0.45
@export var projectile_speed := 360.0
## Her N. mermi kırmızı olur (0 = hiç kırmızı yok).
@export var red_every := 3

enum Phase { IDLE, TELEGRAPH, COOLDOWN }

var _phase := Phase.IDLE
var _timer := 0.0
var _shots := 0
var _next_is_red := false


func anim_folder() -> String:
	return "res://assets/sprites/shooter"


func _ready() -> void:
	super._ready()
	_timer = randf_range(0.7, 1.4)


func pick_animation() -> String:
	if not dead and stun_t <= 0.0 and knock_t <= 0.0:
		match _phase:
			Phase.TELEGRAPH:
				return "telegraph"
			Phase.COOLDOWN:
				return "attack"
	return super.pick_animation()


func _ai(delta: float) -> void:
	if target == null or target.dead:
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
		return
	var dx := target.global_position.x - global_position.x
	facing = 1 if dx > 0.0 else -1
	match _phase:
		Phase.IDLE:
			var dist := absf(dx)
			if dist > 560.0:
				velocity.x = facing * 70.0
			elif dist < 260.0:
				velocity.x = -facing * 85.0
			else:
				velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
			_timer -= delta
			if _timer <= 0.0:
				_begin_telegraph()
		Phase.TELEGRAPH:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			_timer -= delta
			if _timer <= 0.0:
				_fire()
				_phase = Phase.COOLDOWN
				_timer = 0.35
				set_tell(Tell.NONE)
				armored = false
		Phase.COOLDOWN:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			_timer -= delta
			if _timer <= 0.0:
				_phase = Phase.IDLE
				_timer = fire_interval


func _begin_telegraph() -> void:
	_shots += 1
	_next_is_red = red_every > 0 and _shots % red_every == 0
	_phase = Phase.TELEGRAPH
	_timer = telegraph_time
	armored = true
	set_tell(Tell.RED if _next_is_red else Tell.GOLD)
	anim.trigger("telegraph", telegraph_time)


func _fire() -> void:
	if target == null:
		return
	var p := PROJECTILE.instantiate() as Projectile
	var origin := global_position + Vector2(facing * 24.0, -6.0)
	get_parent().add_child(p)
	p.global_position = origin
	var dir := (target.global_position - origin).normalized()
	p.launch(dir * projectile_speed, not _next_is_red, self, 1)
	anim.trigger("attack", 0.35)
	Sfx.play("shoot", -3.0, 1.0, 0.05)


func _on_stunned() -> void:
	_phase = Phase.COOLDOWN
	_timer = 0.3


func _on_death() -> void:
	pass
