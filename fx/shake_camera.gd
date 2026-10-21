class_name ShakeCamera
extends Camera2D
## Pürüzsüz kamera efektleri:
##  - screen_shake: "trauma" modeli. Rastgele zıplama yerine yumuşak gürültü, sona doğru yavaşça söner.
##  - camera_kick:  vuruşun yönüne doğru iter, yay gibi geri döner (darbe hissi).
##  - camera_punch: kısa bir yakınlaşma (parry).
## Zaman gerçek saatten akar, böylece hitstop (dondurma) anında da sarsıntı hissedilir.

@export var max_offset := 26.0
@export var noise_speed := 22.0
@export var spring_stiffness := 120.0
@export var spring_damping := 16.0
@export var max_kick := 22.0

var trauma := 0.0

var _decay := 1.0
var _time := 0.0
var _kick := Vector2.ZERO
var _kick_vel := Vector2.ZERO
var _punch := 0.0
var _punch_vel := 0.0
var _last_usec := 0
var _noise := FastNoiseLite.new()


func _ready() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_noise.seed = randi()
	EventBus.screen_shake.connect(_on_shake)
	EventBus.camera_kick.connect(_on_kick)
	EventBus.camera_punch.connect(_on_punch)


func _on_shake(strength: float, duration: float) -> void:
	var t := sqrt(clampf(strength / max_offset, 0.0, 1.0))
	if t >= trauma:
		trauma = t
		_decay = t / maxf(duration, 0.05)
	else:
		# Daha küçük bir sarsıntı, süren büyüğe hafifçe eklenir.
		trauma = minf(trauma + t * 0.25, 1.0)


func _on_kick(direction: Vector2, strength: float) -> void:
	if direction.length() < 0.01:
		return
	_kick_vel += direction.normalized() * strength * 24.0


func _on_punch(amount: float) -> void:
	_punch_vel += amount * 24.0


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := 0.0
	if _last_usec != 0:
		dt = clampf(float(now - _last_usec) / 1000000.0, 0.0, 0.05)
	_last_usec = now
	step(dt)


## Bir zaman adımı ilerletir (testler doğrudan çağırabilir).
func step(dt: float) -> void:
	_time += dt
	trauma = maxf(trauma - _decay * dt, 0.0)
	var shake := Vector2.ZERO
	var amp := max_offset * trauma * trauma
	if amp > 0.001:
		var t := _time * noise_speed
		shake = Vector2(_noise.get_noise_2d(t, 0.0), _noise.get_noise_2d(t, 100.0)) * amp
	# yaylar: itme ve yakınlaşma
	_kick_vel += (-spring_stiffness * _kick - spring_damping * _kick_vel) * dt
	_kick += _kick_vel * dt
	if _kick.length() > max_kick:
		_kick = _kick.normalized() * max_kick
	_punch_vel += (-spring_stiffness * _punch - spring_damping * _punch_vel) * dt
	_punch += _punch_vel * dt
	offset = shake + _kick
	zoom = Vector2.ONE * (1.0 + clampf(_punch, -0.1, 0.12))
