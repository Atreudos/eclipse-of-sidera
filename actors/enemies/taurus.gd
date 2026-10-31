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
## Atılmanın KIRMIZI (parry'lenemez, 2 hasar) olma şansı. Çoğu atılma kırmızıdır; altın (parry) fırsatı seyrek gelir.
@export_range(0.0, 1.0) var red_chance := 0.6

enum Phase { CHASE, TELEGRAPH, LUNGE, RECOVER }

var _phase := Phase.CHASE
var _timer := 0.0
var _cooldown := 0.0
var _red := false
## Bu uyarıda bekletme yapıldı mı (bir saldırıda en çok bir kez).
var _delayed := false
## Sıradaki uyarı kısaltılmış mı (oyuncu parry'yi ıskaladı, fırsat kolluyor).
var _quick := false

## Saldırıya geçmek için hedefle ayak seviyesi farkı en fazla bu kadar olabilir (px).
const ATTACK_LEVEL_TOLERANCE := 72.0
## Zorluk/tur ayarının inemeyeceği alt sınırlar (sn): uyarı insan tepkisinin altına düşmesin, saldırı sonrası hep bir açık kalsın.
const TELEGRAPH_FLOOR := 0.3
const RECOVER_FLOOR := 0.4
const PARRY_STUN_FLOOR := 0.45
## Oyuncunun parry'sini ıskalamasını kolluyor (zekâ): atılma, parry'den toparlanırken yetişsin diye bu oranda kısa uyarı.
const PUNISH_QUICK := 0.65
## Parry'yi bekleten atılmanın hedefe varışı, toparlanma süresinin bu oranına denk gelir.
const PATIENCE_ARRIVAL := 0.75
## Atılmanın gövdeden hasar alanına, parry bölgesine varana kadar kat ettiği ön mesafe (px): hasar alanı 28 px önde, parry bölgesi 48 px yarıçaplı.
const LUNGE_LEAD_IN := 28.0 + 48.0

@onready var attack_hitbox: Hitbox = $AttackHitbox


func anim_folder() -> String:
	return "res://assets/sprites/taurus"


func _ready() -> void:
	super._ready()
	attack_hitbox.source = self
	attack_hitbox.set_faction("enemy")
	attack_hitbox.active = false
	attack_hitbox.parried.connect(_on_attack_parried)
	EventBus.parry_started.connect(_on_player_parry_started)
	EventBus.parry_failed.connect(_on_player_parry_failed)
	_cooldown = tuning.wait(randf_range(0.6, 1.2))


func _exit_tree() -> void:
	if EventBus.parry_started.is_connected(_on_player_parry_started):
		EventBus.parry_started.disconnect(_on_player_parry_started)
	if EventBus.parry_failed.is_connected(_on_player_parry_failed):
		EventBus.parry_failed.disconnect(_on_player_parry_failed)


func _apply_tuning() -> void:
	walk_speed *= tuning.speed
	lunge_speed *= tuning.speed
	lunge_range *= tuning.reach
	telegraph_time = tuning.warn(telegraph_time, TELEGRAPH_FLOOR)
	recover_time = tuning.open_time(recover_time, RECOVER_FLOOR)
	red_chance = clampf(red_chance + tuning.red, 0.0, EnemyScaling.MAX_RED_SHARE)


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
				_cooldown = tuning.wait(randf_range(0.5, 1.1))


func _begin_telegraph() -> void:
	_red = randf() < red_chance
	_phase = Phase.TELEGRAPH
	_timer = telegraph_time * (PUNISH_QUICK if _quick else 1.0)
	_quick = false
	_delayed = false
	facing = 1 if target.global_position.x > global_position.x else -1
	set_tell(Tell.RED if _red else Tell.GOLD)
	anim.trigger("telegraph", _timer)


func _begin_lunge() -> void:
	_phase = Phase.LUNGE
	_timer = lunge_time
	attack_hitbox.position = Vector2(facing * 28.0, 0.0)
	attack_hitbox.parryable = not _red
	attack_hitbox.damage = tuning.scale_damage(2 if _red else 1)
	attack_hitbox.active = true
	anim.trigger("attack", lunge_time)


func _end_lunge() -> void:
	attack_hitbox.active = false
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
	stun(tuning.stun_time(0.9, PARRY_STUN_FLOOR))
	velocity.x = 0.0
	_phase = Phase.RECOVER
	_timer = 0.4


func _on_stunned() -> void:
	attack_hitbox.active = false


## Vurulunca hazırlanan ya da süren atılma iptal olur; kısa süre sonra yeniden dener.
func _on_interrupted() -> void:
	if _phase == Phase.TELEGRAPH or _phase == Phase.LUNGE:
		attack_hitbox.active = false
		_phase = Phase.CHASE
		_cooldown = maxf(_cooldown, tuning.wait(randf_range(0.7, 1.1)))


func _on_death() -> void:
	attack_hitbox.active = false


# ---------------------------------------------------------------- zekâ (zorluk seviyesi açar; NORMAL'de kapalıdır)

## SABIR: oyuncu uyarı sürerken parry'ye bastı. Taurus atılmasını bekletir, öyle ki hasar alanı oyuncuya parry'den
## toparlanırken ulaşsın (oyuncu dash'le kaçabilir ama parry'ye güvenemez). Bir uyarıda en çok bir kez.
func _on_player_parry_started(actor: Node) -> void:
	if actor != target or _phase != Phase.TELEGRAPH or _delayed or target == null:
		return
	if randf() >= tuning.patience:
		return
	var arrive := target.parry_window_time() + PATIENCE_ARRIVAL * target.parry_recovery_time()
	var travel := maxf(absf(target.global_position.x - global_position.x) - LUNGE_LEAD_IN, 0.0) / maxf(lunge_speed, 1.0)
	var wanted := maxf(arrive - travel, 0.05)
	if wanted > _timer:
		_timer = wanted
		_delayed = true


## CEZA: oyuncu parry'yi ıskaladı (toparlanıyor). Menzildeki Taurus beklemeyi bırakıp hemen, kısaltılmış uyarıyla saldırır.
func _on_player_parry_failed(actor: Node) -> void:
	if actor != target or _phase != Phase.CHASE or dead or target == null:
		return
	if absf(target.global_position.x - global_position.x) > lunge_range * 1.3:
		return
	if randf() >= tuning.punish:
		return
	_cooldown = 0.0
	_quick = true
