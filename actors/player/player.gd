class_name Player
extends ActorBase
## Oyuncu: koşma, zıplama, dash, 3'lü kombo, parry.
##
## HIZLI AYAR: Aşağıdaki BASE_STATS içindeki sayıları değiştirerek hissi ayarlayabilirsin.
## (Oyun içinde F3 ile açılan debug panelinden de bazılarını canlı değiştirebilirsin.)

signal dash_charges_changed(current: int, maximum: int)
## Sert bir inişten sonra yere değdi (hız: px/sn).
signal landed(speed: float)
## Dash bir düşmanın gövdesine çarptı (içinden geçilmez).
signal dash_bumped(enemy: EnemyBase)
## Etkileşim tuşuna (E) basıldı (ödül sehpası vb. dinler).
signal interacted

enum State { MOVE, DASH, ATTACK, PARRY, HURT, DEAD }

## Düşmanın başına konulunca kayma hızı (px/sn).
const SLIDE_OFF_SPEED := 220.0
## Bu hızdan (px/sn) hızlı inişler ses/toz efekti verir.
const HARD_LANDING_SPEED := 520.0

const BASE_STATS := {
	"max_health": 4.0,
	# --- hareket ---
	"move_speed": 290.0,
	"ground_accel": 2800.0,
	"air_accel": 1900.0,
	"ground_friction": 3400.0,
	"air_friction": 700.0,
	"gravity": 1950.0,
	"max_fall_speed": 1200.0,
	"jump_velocity": 640.0,
	"jump_cut": 0.45,        # zıplama tuşu erken bırakılınca dikey hız çarpanı
	"coyote_time": 0.10,
	"jump_buffer": 0.12,
	"air_jumps": 1.0,
	# --- dash ---
	"dash_speed": 980.0,
	"dash_time": 0.16,
	"dash_iframes": 0.15,
	"dash_charges": 2.0,
	"dash_recharge": 1.2,    # saniye / şarj
	# --- parry ---
	"parry_window": 0.12,    # parry'nin etkili olduğu süre (sn)
	"parry_recovery": 0.35,  # kaçırırsan toparlanma süresi
	"parry_zone_radius": 48.0,
	"parry_iframes": 0.25,   # başarılı parry sonrası dokunulmazlık
	"empower_time": 1.5,     # başarılı parry sonrası güçlü vuruş süresi
	"empower_mult": 2.0,
	# --- saldırı / hasar ---
	"attack_damage": 1.0,
	"hurt_iframes": 1.0,
	# --- kombo ---
	"combo_window": 1.0,     # her vuruş/parry bu kadar saniye daha kombo süresi verir
	# --- ritim (eşyalar bu çarpanları değiştirir) ---
	"rhythm_gain": 1.0,      # ritim kazanımı çarpanı
	"rhythm_decay": 1.0,     # ritim düşüş hızı çarpanı
}

# Kombo: startup = hazırlık, active = vuruş açık, recovery = toparlanma (saniye)
const ATTACKS := [
	{"startup": 0.05, "active": 0.10, "recovery": 0.13, "dmg": 1.0, "size": Vector2(62, 46), "reach": 40.0, "lunge": 230.0},
	{"startup": 0.05, "active": 0.10, "recovery": 0.13, "dmg": 1.0, "size": Vector2(66, 46), "reach": 42.0, "lunge": 250.0},
	{"startup": 0.09, "active": 0.12, "recovery": 0.24, "dmg": 2.0, "size": Vector2(90, 56), "reach": 52.0, "lunge": 340.0},
]

# Animasyonlar (PNG'ler assets/sprites/player/ içine konunca otomatik kullanılır; bkz. docs/SPRITES.md).
# fps: saniyedeki kare, loop: döngü, fallback: dosya yoksa yedek animasyon.
const ANIM_SPEC := {
	"idle": {"fps": 8.0, "loop": true},
	"run": {"fps": 12.0, "loop": true, "fallback": "idle"},
	"jump": {"fps": 10.0, "loop": false, "fallback": "idle"},
	"fall": {"fps": 10.0, "loop": true, "fallback": "jump"},
	"dash": {"fps": 14.0, "loop": false, "fallback": "run"},
	"attack1": {"fps": 16.0, "loop": false, "fallback": "idle"},
	"attack2": {"fps": 16.0, "loop": false, "fallback": "attack1"},
	"attack3": {"fps": 16.0, "loop": false, "fallback": "attack2"},
	"parry": {"fps": 14.0, "loop": false, "fallback": "idle"},
	"parry_fail": {"fps": 10.0, "loop": false, "fallback": "idle"},
	"hurt": {"fps": 12.0, "loop": false, "fallback": "idle"},
	"death": {"fps": 10.0, "loop": false, "fallback": "hurt"},
}

var intent := Intent.new()
## true ise tuş okunmaz; intent'i dışarıdan (test/yapay zeka) doldurursun.
var scripted := false
var state: State = State.MOVE
var facing := 1

var dash_charges := 0
## Kombo sayacı (vuruş/parry sayısı, hasar sayıları, kombo barı).
var combo: ComboTracker
## Ritim (agresiflik) metresi: kademeye göre hız/hasar/dash bonusu, yüksek kademede parry'den can.
var rhythm: RhythmMeter
## Eşyalar: Stats modifier'ları, davranış betikleri, etiket sinerjileri.
var inventory: Inventory
## Hayalet Adım eşyası: dash sırasında düşman gövdelerinin içinden geçilir.
var dash_ghost := false
## Soğukkanlı eşyası: bu süre (sn) kaldıkça dash şarj harcamaz.
var free_dash_t := 0.0

var _coyote := 0.0
var _jump_buffer := 0.0
var _air_jumps_left := 0
var _jump_cut_done := true

var _dash_recharge_t := 0.0
var _dash_t := 0.0
var _dash_dir := 1

var _parry_t := 0.0
var _parry_succeeded := false
var _parry_recovering := false

var _attack_t := 0.0
var _attack_cur := 0
var _attack_next := 0
var _attack_queued := false
var _combo_window_t := 0.0
var _melee_empowered := false
var _empower_t := 0.0

var _hurt_t := 0.0
var _blink_t := 0.0

@onready var melee: Hitbox = $MeleeHitbox
@onready var melee_shape: CollisionShape2D = $MeleeHitbox/Shape
@onready var parry_zone: Area2D = $ParryZone
@onready var parry_shape: CollisionShape2D = $ParryZone/Shape


func anim_folder() -> String:
	return "res://assets/sprites/player"


func anim_spec() -> Dictionary:
	return ANIM_SPEC


func _ready() -> void:
	super._ready()
	faction = "player"
	stats = Stats.new(BASE_STATS)
	health = stats.int_value("max_health")
	dash_charges = stats.int_value("dash_charges")
	_air_jumps_left = stats.int_value("air_jumps")
	add_to_group("player")
	melee.source = self
	melee.set_faction("player")
	melee.active = false
	melee.landed.connect(_on_melee_landed)
	parry_zone.collision_layer = 0
	parry_zone.collision_mask = Layers.ENEMY_HIT
	EventBus.enemy_died.connect(_on_enemy_died)
	_refresh_parry_zone()
	combo = ComboTracker.new()
	combo.name = "Combo"
	add_child(combo)
	rhythm = RhythmMeter.new()
	rhythm.name = "Rhythm"
	add_child(rhythm)
	inventory = Inventory.new()
	inventory.name = "Inventory"
	add_child(inventory)


# ---------------------------------------------------------------- giriş

func _gather_intent() -> void:
	intent.move_x = Input.get_axis("move_left", "move_right")
	intent.jump_held = Input.is_action_pressed("jump")
	intent.jump_pressed = Input.is_action_just_pressed("jump")
	intent.dash_pressed = Input.is_action_just_pressed("dash")
	intent.parry_pressed = Input.is_action_just_pressed("parry")
	intent.attack_pressed = Input.is_action_just_pressed("attack")
	intent.interact_pressed = Input.is_action_just_pressed("interact")


# ---------------------------------------------------------------- ana döngü

func _physics_process(delta: float) -> void:
	if not scripted:
		_gather_intent()
	_tick_timers(delta)
	match state:
		State.MOVE:
			_state_move(delta)
		State.DASH:
			_state_dash(delta)
		State.ATTACK:
			_state_attack(delta)
		State.PARRY:
			_state_parry(delta)
		State.HURT:
			_state_hurt(delta)
		State.DEAD:
			_state_dead(delta)
	_sync_enemy_collision()
	var fall_speed := velocity.y
	var was_on_floor := is_on_floor()
	move_and_slide()
	if not was_on_floor and is_on_floor() and fall_speed > HARD_LANDING_SPEED:
		_on_landed(fall_speed)
	_post_move(delta)
	if intent.interact_pressed and not dead:
		interacted.emit()
	intent.clear_edges()
	queue_redraw()


## Sert iniş: tok ses ve ayak dibinde küçük bir toz halkası.
func _on_landed(speed: float) -> void:
	var k := clampf((speed - HARD_LANDING_SPEED) / 700.0, 0.0, 1.0)
	Sfx.play("land", -11.0 + 7.0 * k, 1.0, 0.05)
	RingFx.spawn(get_parent(), Vector2(global_position.x, feet_y() - 2.0), Color(1.0, 1.0, 1.0, 0.22 + 0.2 * k), 5.0, 18.0 + 24.0 * k, 0.2)
	landed.emit(speed)


## Hayalet Adım: dash sırasında düşman katmanı çarpışmadan çıkar, dash bitince geri gelir.
## (Dash düşmanın içinde biterse gövde geri geldiğinde fizik motoru oyuncuyu dışarı iter.)
func _sync_enemy_collision() -> void:
	if dash_ghost and state == State.DASH:
		collision_mask &= ~Layers.ENEMY
	else:
		collision_mask |= Layers.ENEMY


## Dash yapılabilir mi? (şarj var ya da Soğukkanlı'nın serbest süresi sürüyor)
func can_dash() -> bool:
	return dash_charges > 0 or free_dash_t > 0.0


## Hareketten sonra: düşman gövdesine çarpan dash erken biter; düşmanın başına konulursa yana kayılır.
func _post_move(delta: float) -> void:
	var bumped: EnemyBase = null
	var on_head: EnemyBase = null
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var other := col.get_collider() as EnemyBase
		if other == null:
			continue
		if col.get_normal().y < -0.6:
			on_head = other
		elif state == State.DASH and col.get_normal().x * float(_dash_dir) < -0.5:
			bumped = other
	if bumped != null:
		_dash_bump(bumped)
	elif on_head != null and not dead:
		var dir := signf(global_position.x - on_head.global_position.x)
		if dir == 0.0:
			dir = float(facing)
		velocity.x = dir * SLIDE_OFF_SPEED
		move_and_collide(Vector2(dir * SLIDE_OFF_SPEED * delta, 0.0))


## Dash bir düşmanın gövdesine çarptı: içinden geçilmez, dash orada biter.
func _dash_bump(enemy: EnemyBase) -> void:
	_dash_t = stats.value("dash_time")
	velocity.x = -float(_dash_dir) * 70.0
	EventBus.screen_shake.emit(4.0, 0.12)
	EventBus.camera_kick.emit(Vector2(float(_dash_dir), 0.0), 4.0)
	var at := (global_position + enemy.global_position) * 0.5
	HitSpark.spawn(get_parent(), at, Vector2(-float(_dash_dir), -0.2), Color(1.0, 1.0, 1.0), 0.8)
	Sfx.play("hit", -9.0, 1.5)
	dash_bumped.emit(enemy)


func _process(delta: float) -> void:
	var alpha := 1.0
	if _blink_t > 0.0:
		_blink_t -= delta
		alpha = 0.35 if int(Time.get_ticks_msec() / 70.0) % 2 == 0 else 1.0
	if state == State.DASH:
		alpha = 0.45
	if dead:
		tint = Color(0.35, 0.35, 0.4, 1.0)
	elif _empower_t > 0.0:
		tint = Color(1.0, 0.88, 0.45, alpha)
	else:
		tint = Color(1, 1, 1, alpha)
	if visual != null:
		(visual as Node2D).scale.x = facing
	anim.play(pick_animation())
	super._process(delta)


## Duruma göre hangi animasyonun oynayacağı. (PNG yoksa kullanılmaz ama mantık hazır.)
func pick_animation() -> String:
	match state:
		State.DASH:
			return "dash"
		State.ATTACK:
			return "attack%d" % (_attack_cur + 1)
		State.PARRY:
			return "parry_fail" if _parry_recovering else "parry"
		State.HURT:
			return "hurt"
		State.DEAD:
			return "death"
	if not is_on_floor():
		return "jump" if velocity.y < 0.0 else "fall"
	if absf(velocity.x) > 30.0 and absf(intent.move_x) > 0.05:
		return "run"
	return "idle"


func _tick_timers(delta: float) -> void:
	invulnerable_t = maxf(invulnerable_t - delta, 0.0)
	free_dash_t = maxf(free_dash_t - delta, 0.0)
	_empower_t = maxf(_empower_t - delta, 0.0)
	_combo_window_t = maxf(_combo_window_t - delta, 0.0)
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	if intent.jump_pressed:
		_jump_buffer = stats.value("jump_buffer")
	if is_on_floor():
		_coyote = stats.value("coyote_time")
		_air_jumps_left = stats.int_value("air_jumps")
	else:
		_coyote = maxf(_coyote - delta, 0.0)
	var max_charges := stats.int_value("dash_charges")
	if dash_charges < max_charges:
		_dash_recharge_t += delta
		if _dash_recharge_t >= stats.value("dash_recharge"):
			_dash_recharge_t = 0.0
			dash_charges += 1
			dash_charges_changed.emit(dash_charges, max_charges)
	else:
		_dash_recharge_t = 0.0


func is_invulnerable() -> bool:
	if state == State.DASH and _dash_t < stats.value("dash_iframes"):
		return true
	return invulnerable_t > 0.0


# ---------------------------------------------------------------- hareket

func _apply_horizontal(delta: float, speed_mult: float) -> void:
	var on_floor := is_on_floor()
	if absf(intent.move_x) > 0.05:
		var target := intent.move_x * stats.value("move_speed") * speed_mult
		var accel := stats.value("ground_accel") if on_floor else stats.value("air_accel")
		velocity.x = move_toward(velocity.x, target, accel * delta)
		facing = 1 if intent.move_x > 0.0 else -1
	else:
		var friction := stats.value("ground_friction") if on_floor else stats.value("air_friction")
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)


func _apply_gravity(delta: float) -> void:
	velocity.y = minf(velocity.y + stats.value("gravity") * delta, stats.value("max_fall_speed"))


func _handle_jump() -> void:
	if _jump_buffer > 0.0:
		if _coyote > 0.0:
			_do_jump()
		elif _air_jumps_left > 0:
			_air_jumps_left -= 1
			_do_jump()
	if not intent.jump_held and velocity.y < 0.0 and not _jump_cut_done:
		velocity.y *= stats.value("jump_cut")
		_jump_cut_done = true


func _do_jump() -> void:
	velocity.y = -stats.value("jump_velocity")
	_jump_buffer = 0.0
	_coyote = 0.0
	_jump_cut_done = false


func _state_move(delta: float) -> void:
	_apply_horizontal(delta, 1.0)
	_apply_gravity(delta)
	_handle_jump()
	_handle_actions()


func _handle_actions() -> void:
	if intent.dash_pressed and can_dash():
		_start_dash()
	elif intent.parry_pressed:
		_start_parry()
	elif intent.attack_pressed:
		_start_attack()


# ---------------------------------------------------------------- dash

func _start_dash() -> void:
	if free_dash_t <= 0.0:
		dash_charges -= 1
		dash_charges_changed.emit(dash_charges, stats.int_value("dash_charges"))
	if absf(intent.move_x) > 0.05:
		_dash_dir = 1 if intent.move_x > 0.0 else -1
	else:
		_dash_dir = facing
	facing = _dash_dir
	_dash_t = 0.0
	state = State.DASH
	melee.active = false
	anim.trigger("dash", stats.value("dash_time"))
	EventBus.dash_used.emit(self)
	RingFx.spawn(get_parent(), global_position, Color(1, 1, 1, 0.55), 8.0, 38.0, 0.2)


func _state_dash(delta: float) -> void:
	_dash_t += delta
	velocity = Vector2(_dash_dir * stats.value("dash_speed"), 0.0)
	if _dash_t >= stats.value("dash_time"):
		velocity = Vector2(_dash_dir * stats.value("move_speed") * 1.15, 0.0)
		state = State.MOVE


# ---------------------------------------------------------------- parry

func _refresh_parry_zone() -> void:
	(parry_shape.shape as CircleShape2D).radius = stats.value("parry_zone_radius")


func _start_parry() -> void:
	_refresh_parry_zone()
	state = State.PARRY
	_parry_t = 0.0
	_parry_succeeded = false
	_parry_recovering = false
	melee.active = false
	anim.trigger("parry", stats.value("parry_window"))
	_try_parry_zone()  # tuşa bastığın karede zaten içerideki mermiler


func _parry_window_open() -> bool:
	return state == State.PARRY and not _parry_recovering and _parry_t <= stats.value("parry_window")


func _state_parry(delta: float) -> void:
	_parry_t += delta
	_apply_gravity(delta)
	if not _parry_recovering:
		_apply_horizontal(delta, 0.6)
		if _parry_t <= stats.value("parry_window"):
			_try_parry_zone()
		else:
			_parry_recovering = true
			anim.trigger("parry_fail", stats.value("parry_recovery"))
			EventBus.parry_failed.emit(self)
	else:
		_apply_horizontal(delta, 0.4)
		if _parry_t >= stats.value("parry_window") + stats.value("parry_recovery"):
			state = State.MOVE


## Parry bölgesindeki tüm altın saldırıları parry'ler. Hiçbiri yoksa false.
func _try_parry_zone() -> bool:
	var any := false
	for area in parry_zone.get_overlapping_areas():
		var hb := area as Hitbox
		if hb != null and hb.active and hb.parryable and hb.faction == "enemy":
			_do_parry(hb)
			any = true
	return any


func _do_parry(hb: Hitbox) -> void:
	hb.on_parried(self)
	if _parry_succeeded:
		return  # aynı pencerede ikinci mermi: sadece yönü değişsin
	_parry_succeeded = true
	_empower_t = stats.value("empower_time")
	invulnerable_t = maxf(invulnerable_t, stats.value("parry_iframes"))
	state = State.MOVE
	EventBus.parry_success.emit(self, hb)
	Hitstop.freeze(0.07)
	EventBus.screen_shake.emit(6.0, 0.2)
	EventBus.camera_punch.emit(0.03)
	EventBus.screen_flash.emit(Color(1.0, 0.82, 0.25), 0.2, 0.22)
	# Beyaz-sarı dalga oyuncudan çıkıp ekranı doldurur (menzil içinde parlak, dışında soluk).
	ParryWave.spawn(get_parent(), global_position, stats.value("parry_zone_radius"))
	RingFx.spawn(get_parent(), hb.global_position, Color(1.0, 0.95, 0.7, 1.0), 10.0, 46.0, 0.2)
	HitSpark.spawn(get_parent(), hb.global_position, Vector2(-facing, -0.2), Color(1.0, 0.85, 0.3), 1.4)
	Sfx.play_parry(combo.parries)
	flash(Color(1.0, 0.92, 0.5), 0.16)


func on_hit_by(hitbox: Hitbox) -> bool:
	if dead:
		return false
	if _parry_window_open() and hitbox.parryable:
		_do_parry(hitbox)
		return false
	if is_invulnerable():
		# Dash'in dokunulmazlık karesinde savuşturulan saldırı = "dodge" (agresiflik ödülü).
		if state == State.DASH and _dash_t < stats.value("dash_iframes"):
			EventBus.dodge_success.emit(self, hitbox)
		return false
	take_damage(hitbox.damage, hitbox.source)
	_enter_hurt(hitbox)
	return true


# ---------------------------------------------------------------- saldırı

func _start_attack() -> void:
	_attack_cur = _attack_next if _combo_window_t > 0.0 else 0
	_attack_next = (_attack_cur + 1) % ATTACKS.size()
	var a: Dictionary = ATTACKS[_attack_cur]
	state = State.ATTACK
	_attack_t = 0.0
	_attack_queued = false
	_combo_window_t = float(a["startup"]) + float(a["active"]) + float(a["recovery"]) + 0.25
	(melee_shape.shape as RectangleShape2D).size = a["size"]
	melee.position = Vector2(facing * float(a["reach"]), 0.0)
	_melee_empowered = _empower_t > 0.0
	var mult := stats.value("empower_mult") if _melee_empowered else 1.0
	melee.damage = maxi(roundi(stats.value("attack_damage") * float(a["dmg"]) * mult), 1)
	melee.active = false
	anim.trigger("attack%d" % (_attack_cur + 1), float(a["startup"]) + float(a["active"]) + float(a["recovery"]))
	Sfx.play("slash", -4.0, 1.0 + 0.08 * _attack_cur, 0.04)


func _state_attack(delta: float) -> void:
	var a: Dictionary = ATTACKS[_attack_cur]
	var startup: float = a["startup"]
	var active_end: float = startup + float(a["active"])
	var total: float = active_end + float(a["recovery"])
	_attack_t += delta
	if _attack_t < active_end:
		velocity.x = facing * float(a["lunge"]) * (1.0 - _attack_t / active_end)
	else:
		velocity.x = move_toward(velocity.x, 0.0, stats.value("ground_friction") * delta)
	_apply_gravity(delta)
	var hit_on := _attack_t >= startup and _attack_t < active_end
	if hit_on != melee.active:
		melee.active = hit_on
	if intent.attack_pressed:
		_attack_queued = true
	# iptal: dash her zaman (vuruş başladıktan sonra), parry vuruş bittikten sonra
	if intent.dash_pressed and can_dash() and _attack_t >= startup:
		melee.active = false
		_start_dash()
		return
	if intent.parry_pressed and _attack_t >= active_end:
		melee.active = false
		_start_parry()
		return
	if _attack_t >= total:
		melee.active = false
		if _attack_queued:
			_start_attack()
		else:
			state = State.MOVE


func _on_melee_landed(_target: Hurtbox) -> void:
	if _melee_empowered:
		_empower_t = 0.0
		_melee_empowered = false
	Hitstop.freeze(0.04 + 0.02 * _attack_cur)
	EventBus.screen_shake.emit(3.0 + 2.0 * _attack_cur, 0.14)
	EventBus.camera_kick.emit(Vector2(facing, 0.0), 3.5 + 2.5 * _attack_cur)


# ---------------------------------------------------------------- hasar / ölüm

func _enter_hurt(hitbox: Hitbox) -> void:
	if dead:
		return
	var dir := 1 if global_position.x >= hitbox.global_position.x else -1
	velocity = Vector2(dir * 260.0, -220.0)
	state = State.HURT
	_hurt_t = 0.0
	melee.active = false
	invulnerable_t = stats.value("hurt_iframes")
	_blink_t = stats.value("hurt_iframes")
	# Hasar alınca zaman YAVAŞLAMAZ (slow-mo sadece vurma/parry hissi içindir): sarsıntı + flash yeter.
	anim.trigger("hurt", 0.22)
	EventBus.screen_shake.emit(10.0, 0.3)
	EventBus.camera_kick.emit(Vector2(dir, -0.25), 9.0)
	EventBus.screen_flash.emit(Color(0.95, 0.15, 0.2), 0.3, 0.35)


func _state_hurt(delta: float) -> void:
	_hurt_t += delta
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
	if _hurt_t >= 0.22:
		state = State.MOVE


## Hasar flaşı: oyuncuda beyaz yerine kırmızımsı, biraz daha uzun.
func _hit_flash() -> void:
	flash(Color(1.0, 0.5, 0.5), 0.24)


func die() -> void:
	super.die()
	state = State.DEAD
	melee.active = false
	anim.trigger("death")
	EventBus.screen_shake.emit(14.0, 0.5)
	EventBus.screen_flash.emit(Color(0.95, 0.15, 0.2), 0.4, 0.6)


func _state_dead(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)


func _on_enemy_died(_enemy: Node) -> void:
	# Düşman öldürmek 1 dash şarjı geri verir.
	var max_charges := stats.int_value("dash_charges")
	if dash_charges < max_charges and not dead:
		dash_charges += 1
		_dash_recharge_t = 0.0
		dash_charges_changed.emit(dash_charges, max_charges)


# ---------------------------------------------------------------- çizim (yer tutucu efektler)

func _draw() -> void:
	if state == State.PARRY:
		var r := stats.value("parry_zone_radius")
		if not _parry_recovering:
			draw_circle(Vector2.ZERO, r, Color(1.0, 0.82, 0.25, 0.14))
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(1.0, 0.82, 0.25, 0.95), 4.0)
		else:
			draw_arc(Vector2.ZERO, r * 0.8, 0.0, TAU, 40, Color(0.55, 0.55, 0.6, 0.55), 2.0)
	if melee.active:
		var size := (melee_shape.shape as RectangleShape2D).size
		var color := Color(1.0, 0.9, 0.4, 0.6) if _melee_empowered else Color(1, 1, 1, 0.5)
		draw_rect(Rect2(melee.position - size * 0.5, size), color)
