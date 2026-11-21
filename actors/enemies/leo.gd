class_name Leo
extends EnemyBase
## Leo (Aslan): orta mesafeden pençe dalgası atar. Periyodik KÜKRER: yanındaki bütün düşmanlar kısa süre hızlanır
## (kararları ve saldırı tempoları ~%35 hızlı). Kükremesi sırasında savunmasızdır: vurursan kükreme iptal olur.
## Yalnız başına kükremez (etrafta başka düşman yoksa hazırlığı atlar).

const PROJECTILE := preload("res://combat/projectile.tscn")

@export var walk_speed := 90.0
@export var claw_interval := 2.0
@export var roar_interval := 8.5
@export var claw_tell := 0.6
@export var roar_tell := 0.9
@export var projectile_speed := 330.0

const TELEGRAPH_FLOOR := 0.35
const NEAR_DISTANCE := 240.0
const FAR_DISTANCE := 440.0
const ROAR_TIME := 0.6
const RALLY_DURATION := 4.5
const ROAR_RADIUS := 700.0
const RALLY_FALLBACK_WAIT := 2.5

enum Phase { IDLE, CLAW_TELL, CLAW_RECOVER, ROAR_TELL, ROAR }

var _phase := Phase.IDLE
var _timer := 0.0
var _claw_t := 1.0
var _roar_t := 5.0
var _shots := 0
var _next_red := true


func anim_folder() -> String:
	return "res://assets/sprites/leo"


func anim_spec() -> Dictionary:
	return EnemyBase.ANIM_SPEC.merged({"roar": {"fps": 10.0, "loop": false, "fallback": "telegraph"}})


func _ready() -> void:
	super._ready()
	_claw_t = tuning.wait(randf_range(0.8, 1.4))
	_roar_t = tuning.wait(randf_range(4.0, 6.0))


func _apply_tuning() -> void:
	walk_speed *= tuning.speed
	projectile_speed *= tuning.speed
	claw_interval = maxf(tuning.wait(claw_interval), 1.2)
	roar_interval = maxf(tuning.wait(roar_interval), 5.0)
	claw_tell = tuning.warn(claw_tell, TELEGRAPH_FLOOR)


func pick_animation() -> String:
	if not dead and stun_t <= 0.0 and knock_t <= 0.0:
		match _phase:
			Phase.CLAW_TELL:
				return "telegraph"
			Phase.CLAW_RECOVER:
				return "attack"
			Phase.ROAR_TELL, Phase.ROAR:
				return "roar"
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
			if dist > FAR_DISTANCE:
				velocity.x = facing * walk_speed
			elif dist < NEAR_DISTANCE:
				velocity.x = -facing * walk_speed * 0.9
			else:
				velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
			_claw_t -= delta
			_roar_t -= delta
			if _roar_t <= 0.0:
				if _others_nearby() > 0:
					_begin_roar()
				else:
					_roar_t = RALLY_FALLBACK_WAIT
			elif _claw_t <= 0.0:
				_begin_claw()
		Phase.CLAW_TELL:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			_timer -= delta
			if _timer <= 0.0:
				_fire_claw()
				_phase = Phase.CLAW_RECOVER
				_timer = tuning.open_time(0.4, 0.25)
				set_tell(Tell.NONE)
		Phase.CLAW_RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			_timer -= delta
			if _timer <= 0.0:
				_phase = Phase.IDLE
				_claw_t = claw_interval
		Phase.ROAR_TELL:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			_timer -= delta
			if _timer <= 0.0:
				_do_roar()
		Phase.ROAR:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			_timer -= delta
			if _timer <= 0.0:
				_phase = Phase.IDLE
				_roar_t = roar_interval
				_claw_t = maxf(_claw_t, 0.8)


func _others_nearby() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as EnemyBase
		if en != null and en != self and not en.dead and absf(en.global_position.x - global_position.x) <= ROAR_RADIUS:
			n += 1
	return n


func _begin_claw() -> void:
	_shots += 1
	_next_red = _shots % 2 != 0  # kırmızı, altın, kırmızı...
	_phase = Phase.CLAW_TELL
	_timer = claw_tell
	set_tell(Tell.RED if _next_red else Tell.GOLD)
	anim.trigger("telegraph", claw_tell)


func _fire_claw() -> void:
	var p := PROJECTILE.instantiate() as Projectile
	var origin := global_position + Vector2(facing * 26.0, -4.0)
	get_parent().add_child(p)
	p.global_position = origin
	p.radius = 13.0
	p.launch(Vector2(facing * projectile_speed, 0.0), not _next_red, self, tuning.scale_damage(1))
	anim.trigger("attack", 0.4)
	Sfx.play("shoot", -2.0, 0.8, 0.05)


## Kükreme hazırlığı: parry sembolü YOK (saldırı değil); halka + animasyon uyarır.
func _begin_roar() -> void:
	_phase = Phase.ROAR_TELL
	_timer = roar_tell
	anim.trigger("roar", roar_tell + ROAR_TIME)
	RingFx.spawn(get_parent(), global_position + Vector2(0.0, -14.0), Color(1.0, 0.7, 0.3, 0.6), 10.0, 40.0, roar_tell)


func _do_roar() -> void:
	_phase = Phase.ROAR
	_timer = ROAR_TIME
	RingFx.spawn(get_parent(), global_position + Vector2(0.0, -14.0), Color(1.0, 0.65, 0.25, 0.9), 14.0, ROAR_RADIUS * 0.6, 0.5)
	Sfx.play("tell_red", -2.0, 0.7)
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as EnemyBase
		if en != null and not en.dead and absf(en.global_position.x - global_position.x) <= ROAR_RADIUS:
			en.rally_t = maxf(en.rally_t, RALLY_DURATION)


func _on_stunned() -> void:
	_phase = Phase.IDLE
	_claw_t = 1.0


## Vurulunca pençe ya da kükreme iptal olur; kükreme biraz sonra yeniden denenir.
func _on_interrupted() -> void:
	if _phase == Phase.ROAR_TELL:
		_roar_t = 3.0
	if _phase == Phase.CLAW_TELL or _phase == Phase.ROAR_TELL:
		_phase = Phase.IDLE
		_claw_t = maxf(_claw_t, 0.9)
