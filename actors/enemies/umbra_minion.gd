class_name UmbraMinion
extends EnemyBase
## Gölge'nin minyonu: küçük bir gölge. Yerden yükselir (bu sırada vurulamaz), sonra Taurus gibi yaklaşıp atılır.
## Çoğu atılışı ALTINdır (parry'le), seyrek KIRMIZI. Gölge ölünce bütün minyonlar erir (`dissolve`).
## Kind.CLONE: Gölge Klonu: bulunduğu yerde bekler, tek bir KIRMIZI atılış yapıp kaybolur (tek vuruşta ölür).

enum Kind { SHADE, CLONE }
enum Phase { EMERGE, CHASE, TELEGRAPH, LUNGE, RECOVER }

const TELEGRAPH_FLOOR := 0.3
const RECOVER_FLOOR := 0.5
const PARRY_STUN_FLOOR := 0.45
const ATTACK_LEVEL_TOLERANCE := 72.0

@export var walk_speed := 165.0
@export var lunge_range := 150.0
@export var telegraph_time := 0.55
@export var lunge_speed := 560.0
@export var lunge_time := 0.2
@export var recover_time := 0.95
@export_range(0.0, 1.0) var red_chance := 0.25

## Doğuş süresi (sn): bu sürede vurulamaz ve saldırmaz. `add_child`'dan ÖNCE verilir.
var emerge_time := 0.7
var kind: Kind = Kind.SHADE

var _phase := Phase.EMERGE
var _timer := 0.0
var _cooldown := 0.0
var _red := false

@onready var attack_hitbox: Hitbox = $AttackHitbox


func anim_folder() -> String:
	return "res://assets/sprites/umbra_minion"


func _ready() -> void:
	super._ready()
	add_to_group("minions")
	attack_hitbox.source = self
	attack_hitbox.set_faction("enemy")
	attack_hitbox.active = false
	attack_hitbox.parried.connect(_on_attack_parried)
	_timer = emerge_time
	_cooldown = tuning.wait(randf_range(0.5, 1.0))
	visual_alpha = 0.0
	if kind == Kind.CLONE:
		telegraph_time = tuning.warn(0.85, 0.5)
		var rect := get_node_or_null("Visual/Placeholder/Rect") as ColorRect
		if rect != null:
			rect.color = Color(0.45, 0.8, 0.95, 0.85)


func _apply_tuning() -> void:
	walk_speed *= tuning.speed
	lunge_speed *= tuning.speed
	telegraph_time = tuning.warn(telegraph_time, TELEGRAPH_FLOOR)
	recover_time = tuning.open_time(recover_time, RECOVER_FLOOR)
	red_chance = clampf(red_chance + tuning.red, 0.0, EnemyScaling.MAX_RED_SHARE)
	if tuning.gold_only:
		red_chance = 0.0
	elif tuning.red_only:
		red_chance = 1.0


func is_emerging() -> bool:
	return _phase == Phase.EMERGE


## Doğuş sırasında vurulamaz.
func on_hit_by(hitbox: Hitbox) -> bool:
	if _phase == Phase.EMERGE:
		return false
	return super.on_hit_by(hitbox)


func _ai(delta: float) -> void:
	if target == null or target.dead:
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
		return
	match _phase:
		Phase.EMERGE:
			velocity.x = 0.0
			_timer -= delta
			visual_alpha = clampf(1.0 - _timer / maxf(emerge_time, 0.01), 0.0, 1.0)
			if _timer <= 0.0:
				visual_alpha = 1.0
				if kind == Kind.CLONE:
					_begin_telegraph(true)
				else:
					_phase = Phase.CHASE
		Phase.CHASE:
			_cooldown = maxf(_cooldown - delta, 0.0)
			if nav.update(delta, walk_speed * 1.2):
				return
			if not is_on_floor():
				return
			var dx := target.global_position.x - global_position.x
			facing = 1 if dx > 0.0 else -1
			if absf(dx) > lunge_range * 0.55:
				velocity.x = facing * walk_speed
			else:
				velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			var same_level := absf(target.feet_y() - feet_y()) <= ATTACK_LEVEL_TOLERANCE
			if same_level and absf(dx) <= lunge_range and _cooldown <= 0.0:
				_begin_telegraph(randf() < red_chance)
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
				if kind == Kind.CLONE:
					dissolve()
				else:
					_phase = Phase.CHASE
					_cooldown = tuning.wait(randf_range(0.6, 1.2))


func _begin_telegraph(red: bool) -> void:
	_red = red
	_phase = Phase.TELEGRAPH
	_timer = telegraph_time
	facing = 1 if target.global_position.x > global_position.x else -1
	set_tell(Tell.RED if _red else Tell.GOLD)
	anim.trigger("telegraph", _timer)


func _begin_lunge() -> void:
	_phase = Phase.LUNGE
	_timer = lunge_time
	attack_hitbox.position = Vector2(facing * 22.0, 0.0)
	attack_hitbox.parryable = not _red
	attack_hitbox.damage = tuning.scale_damage(2 if _red else 1)
	attack_hitbox.active = true
	anim.trigger("attack", lunge_time)


func _end_lunge() -> void:
	attack_hitbox.active = false
	set_tell(Tell.NONE)
	_phase = Phase.RECOVER
	_timer = 0.35 if kind == Kind.CLONE else recover_time
	anim.trigger("recover", _timer)


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
	stun(tuning.stun_time(0.9, PARRY_STUN_FLOOR))
	velocity.x = 0.0
	_phase = Phase.RECOVER
	_timer = 0.4


func _on_stunned() -> void:
	attack_hitbox.active = false


func _on_interrupted() -> void:
	if _phase == Phase.TELEGRAPH or _phase == Phase.LUNGE:
		attack_hitbox.active = false
		_phase = Phase.CHASE
		_cooldown = maxf(_cooldown, tuning.wait(randf_range(0.7, 1.1)))


func _on_death() -> void:
	attack_hitbox.active = false


## Gölge öldü: minyon altın bırakmadan, sayılmadan erir (oda temizlenebilsin diye hemen gruptan çıkar).
func dissolve() -> void:
	if dead:
		return
	dead = true
	remove_from_group("enemies")
	remove_from_group("minions")
	set_tell(Tell.NONE)
	attack_hitbox.active = false
	set_deferred("collision_layer", 0)
	if hurtbox != null:
		hurtbox.set_deferred("monitorable", false)
	RingFx.spawn(get_parent(), global_position, Color(0.72, 0.5, 1.0, 0.8), 6.0, 36.0, 0.3)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)
