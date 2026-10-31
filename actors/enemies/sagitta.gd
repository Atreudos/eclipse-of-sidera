class_name Sagitta
extends EnemyBase
## Sagitta: mesafeyi korur, uyarı verip mermi atar. Mermilerin çoğu KIRMIZI (parry'lenemez), her 3.'sü ALTIN.

const PROJECTILE := preload("res://combat/projectile.tscn")

@export var fire_interval := 1.9
@export var telegraph_time := 0.45
@export var projectile_speed := 360.0
## Her N. mermi altın (parry'lenebilir) olur, diğerleri kırmızıdır (0 = hiç altın yok).
@export var gold_every := 3

## Zorluk/tur ayarının inemeyeceği alt sınırlar (sn).
const TELEGRAPH_FLOOR := 0.3
const FIRE_INTERVAL_FLOOR := 0.9
## Mesafe ayarı (px/sn ve px): yaklaş, uzaklaş, durma bölgesi.
const APPROACH_SPEED := 70.0
const RETREAT_SPEED := 85.0
const FAR_DISTANCE := 560.0
const CLOSE_DISTANCE := 260.0
## Önden hedeflemede hedefin ileri tahmin mesafesi en fazla bu kadar olur (px).
const LEAD_MAX := 220.0

enum Phase { IDLE, TELEGRAPH, COOLDOWN }

var _phase := Phase.IDLE
var _timer := 0.0
var _shots := 0
var _next_is_red := false


func anim_folder() -> String:
	return "res://assets/sprites/sagitta"


func _ready() -> void:
	super._ready()
	_timer = tuning.wait(randf_range(0.7, 1.4))
	EventBus.parry_failed.connect(_on_player_parry_failed)


func _exit_tree() -> void:
	if EventBus.parry_failed.is_connected(_on_player_parry_failed):
		EventBus.parry_failed.disconnect(_on_player_parry_failed)


func _apply_tuning() -> void:
	fire_interval = maxf(tuning.wait(fire_interval), minf(FIRE_INTERVAL_FLOOR, fire_interval))
	telegraph_time = tuning.warn(telegraph_time, TELEGRAPH_FLOOR)
	projectile_speed *= tuning.speed
	# Her N. mermi altın: kırmızı payı (3 -> %67) zorlukla kayar. Kayma yoksa değer olduğu gibi kalır.
	if gold_every > 0 and not is_zero_approx(tuning.red):
		var share := clampf(1.0 - 1.0 / float(gold_every) + tuning.red, 0.0, 0.9)
		gold_every = clampi(roundi(1.0 / (1.0 - share)), 2, 10)


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
			if dist > FAR_DISTANCE:
				velocity.x = facing * APPROACH_SPEED * tuning.speed
			elif dist < CLOSE_DISTANCE * tuning.kite:
				velocity.x = -facing * RETREAT_SPEED * tuning.speed * tuning.kite
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
				_timer = tuning.open_time(0.35, 0.2)
				set_tell(Tell.NONE)
		Phase.COOLDOWN:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			_timer -= delta
			if _timer <= 0.0:
				_phase = Phase.IDLE
				_timer = fire_interval


func _begin_telegraph() -> void:
	_shots += 1
	_next_is_red = not (gold_every > 0 and _shots % gold_every == 0)
	_phase = Phase.TELEGRAPH
	_timer = telegraph_time
	set_tell(Tell.RED if _next_is_red else Tell.GOLD)
	anim.trigger("telegraph", telegraph_time)


func _fire() -> void:
	if target == null:
		return
	var p := PROJECTILE.instantiate() as Projectile
	var origin := global_position + Vector2(facing * 24.0, -6.0)
	get_parent().add_child(p)
	p.global_position = origin
	var dir := (_aim_point(origin) - origin).normalized()
	p.launch(dir * projectile_speed, not _next_is_red, self, tuning.scale_damage(1))
	anim.trigger("attack", 0.35)
	Sfx.play("shoot", -3.0, 1.0, 0.05)


## Nişan noktası. ÖNDEN HEDEFLEME (zekâ): hareket eden oyuncunun mermi varana kadar gideceği yere nişan alır
## (yalnızca yatayda; zıplayan oyuncuyu tahmin etmek haksız olur). `lead` 0 ise doğrudan oyuncuyu hedefler.
func _aim_point(origin: Vector2) -> Vector2:
	var aim := target.global_position
	if tuning.lead > 0.0:
		var flight := origin.distance_to(aim) / maxf(projectile_speed, 1.0)
		aim.x += clampf(target.velocity.x * flight * tuning.lead, -LEAD_MAX, LEAD_MAX)
	return aim


## CEZA (zekâ): oyuncu parry'yi ıskaladı. Hazırda bekleyen Sagitta hemen nişan almaya başlar.
func _on_player_parry_failed(actor: Node) -> void:
	if actor != target or _phase != Phase.IDLE or dead:
		return
	if randf() < tuning.punish:
		_timer = minf(_timer, 0.05)


func _on_stunned() -> void:
	_phase = Phase.COOLDOWN
	_timer = 0.3


## Vurulunca nişan alıp ateş etmek iptal olur; biraz sonra yeniden hedef alır.
func _on_interrupted() -> void:
	if _phase == Phase.TELEGRAPH:
		_phase = Phase.IDLE
		_timer = tuning.wait(randf_range(0.9, 1.3))


func _on_death() -> void:
	pass
