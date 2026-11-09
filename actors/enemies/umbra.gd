class_name Umbra
extends EnemyBase
## Umbra (Gölge): her katın 6. odasındaki patron, Sidera'nın gölgesi. Kat başına yeni bir yetenek kazanır (bkz. UmbraKit).
##
## Okunabilirlik kuralları Taurus'la aynıdır: ALTIN uyarı = parry'le (sersemler, cezalandır), KIRMIZI uyarı = kaç/dash.
## Gölge'nin kendine özgü kuralları:
##  - POISE: kısa sürede 3 vuruş yersen "poise" kırılır: 1.5 sn zırhlanır ve hemen karşılık verir (tek kombo serbest, art arda kombo yok).
##  - ZIRH yeteneği (kat 8+): saldırı hazırlarken vurulunca bölünmez; yalnız parry bozar.
##  - Duvara tırmanış, yer darbesi, dalış gibi "taahhütlü" hamlelerde zırhlıdır (vurulunca kesilmez ama hasar alır).
##  - Parry'yi ıskalarsan (toparlanırken) yakındaysa hemen, kısaltılmış uyarıyla cezalandırır.
##  - Minyonlar ve mermiler Gölge ölünce kaybolur.
##
## Her hamle `current_move` + `stage` ile yürüyen küçük bir durum makinesidir. `force_move()` testler ve geliştirme içindir.

signal move_started(move: int)
signal phase_changed(phase: int)

const PROJECTILE := preload("res://combat/projectile.tscn")
const MINION_SCENE := preload("res://actors/enemies/umbra_minion.tscn")

const PURPLE := Color(0.72, 0.5, 1.0)
const CAST_RED := Color(1.0, 0.35, 0.35)
const CAST_GOLD := Color(1.0, 0.8, 0.3)
const GUARD_BLUE := Color(0.5, 0.85, 1.0)

## Animasyonlar (PNG'ler assets/sprites/umbra/ içine konunca kullanılır; eksikler yedeğine düşer).
const UMBRA_ANIM_SPEC := {
	"idle": {"fps": 8.0, "loop": true},
	"run": {"fps": 11.0, "loop": true, "fallback": "idle"},
	"jump": {"fps": 10.0, "loop": false, "fallback": "idle"},
	"fall": {"fps": 10.0, "loop": true, "fallback": "jump"},
	"telegraph": {"fps": 12.0, "loop": false, "fallback": "idle"},
	"attack": {"fps": 14.0, "loop": false, "fallback": "telegraph"},
	"recover": {"fps": 10.0, "loop": false, "fallback": "idle"},
	"stun": {"fps": 8.0, "loop": true, "fallback": "hurt"},
	"hurt": {"fps": 12.0, "loop": false, "fallback": "idle"},
	"death": {"fps": 10.0, "loop": false, "fallback": "hurt"},
	"throw": {"fps": 14.0, "loop": false, "fallback": "attack"},
	"climb": {"fps": 12.0, "loop": true, "fallback": "run"},
	"cling": {"fps": 8.0, "loop": true, "fallback": "climb"},
	"dive": {"fps": 12.0, "loop": true, "fallback": "attack"},
	"summon": {"fps": 12.0, "loop": false, "fallback": "telegraph"},
	"cast": {"fps": 12.0, "loop": false, "fallback": "summon"},
	"vanish": {"fps": 16.0, "loop": false, "fallback": "idle"},
	"slam": {"fps": 12.0, "loop": false, "fallback": "attack"},
	"counter": {"fps": 8.0, "loop": true, "fallback": "telegraph"},
	"roar": {"fps": 10.0, "loop": true, "fallback": "cast"},
}

@export var walk_speed := 150.0
## Hamleler arası temel bekleme (sn); kat ve zorlukla kısalır.
@export var base_wait := 1.5

# ---- sayılar
const INTRO_WAIT := 1.3
const LEVEL_TOLERANCE := 72.0
const PREFERRED_DIST := 165.0
const KNIFE_NEAR := 215.0
const TELEGRAPH_FLOOR := 0.3
const RECOVER_FLOOR := 0.5
const PARRY_STUN_FLOOR := 0.5
const BASE_RED := 0.45
const PHASE2_WAIT := 0.72
const PHASE2_RED := 0.12
const PHASE2_SPEED := 1.18
const WIND_REVIVE := 0.3
const WIND_TIME := 1.4
const POISE_LIMIT := 3
const POISE_MEMORY := 1.6
const POISE_ARMOR := 1.5
const KNIFE_SPEED := 540.0
const SHOCK_SPEED := 430.0
const RAIN_SPEED := 950.0
const RAIN_HEIGHT := 760.0
const CLIMB_SPEED := 780.0
## Tırmanış yüksekliği: oyuncu duvardan ne kadar uzaksa o kadar yükselir (dalış açısı yetişsin); bu iki sınır arasında.
const CLIMB_MIN := 220.0
const CLIMB_MAX := 420.0
const CLIMB_PER_PX := 0.45
const DIVE_SPEED := 880.0
const WALL_MARGIN := 44.0
const BLINK_OFFSET := 96.0
const MINION_HALF_H := 18.0
const ORBIT_TIME := 4.2
const ORBIT_RADIUS := 82.0
const COUNTER_TIME := 1.7
const CLOAK_ALPHA := 0.12
const SLAM_AIR_SPEED := 480.0

# ---- hamle aşamaları
const K_TELL := 0
const K_STRIKE := 1
const K_RECOVER := 2

const T_TELL := 0
const T_RECOVER := 1

const C_RUN := 0
const C_UP := 1
const C_HANG := 2
const C_ACT := 3
const C_RECOVER := 4

const M_CAST := 0
const M_RECOVER := 1

const B_VANISH := 0
const B_MARK := 1

const S_TELL := 0
const S_AIR := 1
const S_SHOCK := 2
const S_RECOVER := 3

const R_CAST := 0
const R_WAIT := 1
const R_RECOVER := 2

const O_TELL := 0
const O_ACTIVE := 1
const O_RECOVER := 2

const Z_FADE := 0
const Z_STALK := 1

# ---- durum
var floor_no := 1
var spec: Dictionary = {}
## Bu katta açık hamleler (UmbraKit.Move).
var abilities: Array = []
var current_move: int = UmbraKit.Move.NONE
var stage := 0
## 1 = normal, 2 = öfkeli (ikinci nefes / gerçek dövüşün ikinci evresi).
var phase := 1
## Test ve geliştirme: -1 rastgele, 0 hep ALTIN, 1 hep KIRMIZI saldırı rengi.
var red_override := -1

var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _fx_t := 0.0
var _cooldown := INTRO_WAIT
## Hamle seçimini sık sık denememek için (uygun hamle yoksa her kare raycast yapılmasın).
var _pick_cd := 0.0
var _lock: Dictionary = {}
var _last_move: int = UmbraKit.Move.NONE
var _red := false
var _combo_left := 0
var _variant := 0
var _shots := 0
var _lunge := 0.0
var _air_t := 0.0
var _wall_dir := 1
var _wall_x := 0.0
var _hang_y := 0.0
var _dest := Vector2.ZERO
var _base_gravity := 1900.0
var _speed_mult := 1.0
var _wait_mult := 1.0
var _red_bonus := 0.0
var _quick := false
var _force_melee := false
var _anim := ""
var _casting := false
var _armor_drawn := false
var _blades: Array[UmbraBlade] = []

## Zırh kaynakları: poise kırıldı (`_armor_t`), taahhütlü hamle (`_committed`), saldırı hazırlığı (`_guard`, yalnız ZIRH yeteneğiyle).
var _guard := false
var _committed := false
var _armor_t := 0.0
var _untouchable := false
var _counter_on := false
var _poise_hits := 0
var _poise_t := 0.0
var _wind_used := false
var _pending_phase := false

@onready var attack_hitbox: Hitbox = $AttackHitbox
@onready var attack_shape: CollisionShape2D = $AttackHitbox/Shape


func anim_folder() -> String:
	return "res://assets/sprites/umbra"


func anim_spec() -> Dictionary:
	return UMBRA_ANIM_SPEC


func _ready() -> void:
	floor_no = UmbraKit.clamp_floor(int(get_meta("floor", 1)))
	spec = UmbraKit.spec(floor_no)
	abilities = spec["moves"]
	max_hp = UmbraKit.hp_for(floor_no, max_hp)
	super._ready()
	add_to_group("boss")
	_base_gravity = gravity
	_rng.randomize()
	_apply_umbra_items()
	attack_shape.shape = RectangleShape2D.new()  # sahne kaynağını paylaşma: her Gölge kendi şeklini boyar
	_set_attack_box(Vector2(76.0, 54.0), Vector2.ZERO)
	attack_hitbox.source = self
	attack_hitbox.set_faction("enemy")
	attack_hitbox.active = false
	attack_hitbox.parried.connect(_on_attack_parried)
	EventBus.parry_failed.connect(_on_player_parry_failed)
	_cooldown = tuning.wait(INTRO_WAIT)
	EventBus.boss_spawned.emit(self)


func _exit_tree() -> void:
	if EventBus.parry_failed.is_connected(_on_player_parry_failed):
		EventBus.parry_failed.disconnect(_on_player_parry_failed)


func _apply_tuning() -> void:
	_speed_mult = float(spec["speed"]) * tuning.speed
	_wait_mult = float(spec["wait"])
	_red_bonus = float(spec["red"]) + tuning.red


## Umbra'ya kalan eşyaların sayısal etkileri (can, hasar, hız, alınan hasar) Gölge'ye de uygulanır.
func _apply_umbra_items() -> void:
	var extra_hp := 0.0
	for it: ItemData in GameState.umbra_items:
		for m in UmbraKit.usable_mods(it):
			var stat := str(m[0])
			if stat == "max_health":
				extra_hp += float(m[1])
			else:
				stats.add_modifier(it, stat, float(m[1]), float(m[2]))
	if extra_hp > 0.0:
		max_hp = maxi(1, roundi(float(max_hp) * (1.0 + UmbraKit.ITEM_HP_PER_POINT * extra_hp)))
		health = max_hp


# ---------------------------------------------------------------- yardımcılar

func _spd() -> float:
	return walk_speed * _speed_mult * stats.value("move_speed", 1.0) * (PHASE2_SPEED if phase >= 2 else 1.0)


func _spd_factor() -> float:
	return _spd() / maxf(walk_speed, 1.0)


## Saldırının kalp hasarı: düşman ölçeklemesi x Umbra'nın eşya çarpanı, 1..4.
func _dmg(base: int) -> int:
	var d := float(tuning.scale_damage(base)) * stats.value("attack_damage", 1.0)
	return clampi(roundi(d), 1, 4)


func _face_target() -> int:
	return 1 if target.global_position.x > global_position.x else -1


## Uyarı süresi: zorlukla kısalır (alt sınırı var), biraz rastgele, ceza modunda kısalır.
func _tele(base: float) -> float:
	var t := tuning.warn(base * _rng.randf_range(0.92, 1.12), TELEGRAPH_FLOOR)
	if _quick:
		_quick = false
		t = maxf(t * 0.65, minf(TELEGRAPH_FLOOR, t))
	return t


## Saldırı rengi: true = KIRMIZI. force: -1 rastgele, 0 altın, 1 kırmızı.
func _roll_red(mult: float = 1.0, force: int = -1) -> bool:
	if red_override >= 0:
		return red_override == 1
	if force >= 0:
		return force == 1
	if tuning.gold_only:
		return false
	if tuning.red_only:
		return true
	return _rng.randf() < clampf((BASE_RED + _red_bonus + (PHASE2_RED if phase >= 2 else 0.0)) * mult, 0.0, EnemyScaling.MAX_RED_SHARE)


func _next_wait() -> float:
	return tuning.wait(base_wait * _wait_mult * (0.72 if phase >= 2 else 1.0) * _rng.randf_range(0.8, 1.2))


func _play(anim_name: String, dur: float = 0.0) -> void:
	_anim = anim_name
	anim.trigger(anim_name, dur)


func _set_attack_box(size: Vector2, offset: Vector2) -> void:
	(attack_shape.shape as RectangleShape2D).size = size
	attack_hitbox.position = offset


func _cast_glow(c: Color) -> void:
	_casting = true
	if tell_glow != null:
		tell_glow.visible = true
		tell_glow.color = Color(c, 0.5)


func _clear_cast_glow() -> void:
	_casting = false
	if tell_glow != null and tell_mode() == Tell.NONE:
		tell_glow.visible = false


func _refresh_armor() -> void:
	if dead or stun_t > 0.0:
		armored = false
		return
	armored = _armor_t > 0.0 or _committed or (_guard and bool(spec["armor"]))


## Zırh açıkken gövdenin etrafına ince bir çerçeve çizilir: "şimdi vurman bölmez".
func _draw() -> void:
	super._draw()
	if armored and not dead:
		draw_rect(Rect2(-17.0, -30.0, 34.0, 60.0), Color(0.85, 0.92, 1.0, 0.75), false, 3.0)


func _process(delta: float) -> void:
	if _casting and tell_glow != null:
		tell_glow.modulate.a = 0.6 + 0.3 * sin(Time.get_ticks_msec() / 60.0)
	if armored != _armor_drawn:
		_armor_drawn = armored
		queue_redraw()
	super._process(delta)


func pick_animation() -> String:
	if dead or stun_t > 0.0 or knock_t > 0.0 or current_move == UmbraKit.Move.NONE or _anim == "":
		return super.pick_animation()
	return _anim


func is_idle() -> bool:
	return current_move == UmbraKit.Move.NONE


## Gölge'nin bölgesinin (arena) yatay sınırları: iki yandaki duvarlar. Duvar bulunamazsa ±700 px.
func arena_bounds() -> Vector2:
	return Vector2(_scan_wall(-1), _scan_wall(1))


## `dir` yönündeki en yakın duvara yaslanmış x (gövde yarı genişliği payıyla).
func _scan_wall(dir: int) -> float:
	var space := get_world_2d().direct_space_state
	var from := global_position + Vector2(0.0, -8.0)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(float(dir) * 1800.0, 0.0), Layers.WORLD)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return global_position.x + float(dir) * 700.0
	return (hit["position"] as Vector2).x - float(dir) * (body_half_width() + 2.0)


## Gövdemizin bu noktada duvara girmediği ve altında zemin olduğu doğrulanır (Gölge adımı / klon için).
func _spot_free(pos: Vector2) -> bool:
	var body := get_node_or_null("Body") as CollisionShape2D
	if body == null:
		return false
	var space := get_world_2d().direct_space_state
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = body.shape
	q.transform = Transform2D(0.0, pos + body.position)
	q.collision_mask = Layers.WORLD
	if not space.intersect_shape(q, 1).is_empty():
		return false
	var ray := PhysicsRayQueryParameters2D.create(pos, pos + Vector2(0.0, 90.0), Layers.WORLD | Layers.PLATFORM)
	return not space.intersect_ray(ray).is_empty()


## Oyuncuya doğru nişan (isteğe bağlı önden). Birim vektör.
func _aim_at(origin: Vector2, speed: float) -> Vector2:
	var tp := target.global_position + Vector2(0.0, -6.0)
	if tuning.lead > 0.0:
		tp += target.velocity * (origin.distance_to(tp) / maxf(speed, 1.0)) * tuning.lead
	return (tp - origin).normalized()


func _spawn_knife(pos: Vector2, vel: Vector2, parryable: bool, dmg: int = -1) -> Projectile:
	var p := PROJECTILE.instantiate() as Projectile
	get_parent().add_child(p)
	p.global_position = pos
	p.launch(vel, parryable, self, _dmg(1) if dmg < 0 else dmg)
	return p


func _own_projectiles() -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("projectiles"):
		var pr := node as Projectile
		if pr != null and pr.faction == "enemy" and pr.original_source == self:
			n += 1
	return n


func minion_count() -> int:
	return get_tree().get_nodes_in_group("minions").size()


func _remove_blades() -> void:
	for b in _blades:
		if is_instance_valid(b):
			b.queue_free()
	_blades.clear()


# ---------------------------------------------------------------- ana döngü

func _ai(delta: float) -> void:
	_tick_timers(delta)
	# Gerçek dövüş (kat 18): yarı canda ikinci evre. Yanma/zehir gibi kaynaksız hasar da sayılsın diye her karede bakılır.
	if bool(spec["real"]) and phase == 1 and health * 2 <= max_hp:
		_pending_phase = true
	if target == null or target.dead:
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
		_refresh_armor()
		return
	if _pending_phase and current_move != UmbraKit.Move.WIND:
		_pending_phase = false
		_begin_wind(false)
	if current_move == UmbraKit.Move.NONE:
		_neutral(delta)
	else:
		_run_move(delta)
	_refresh_armor()


func _tick_timers(delta: float) -> void:
	for m in _lock.keys():
		_lock[m] = maxf(float(_lock[m]) - delta, 0.0)
	_armor_t = maxf(_armor_t - delta, 0.0)
	if _poise_t > 0.0:
		_poise_t -= delta
		if _poise_t <= 0.0:
			_poise_hits = 0


func _context() -> Dictionary:
	var dx := absf(target.global_position.x - global_position.x)
	var away := 1 if global_position.x >= target.global_position.x else -1
	return {
		"dx": dx,
		"level": absf(target.feet_y() - feet_y()) <= LEVEL_TOLERANCE,
		"hp": float(health) / float(maxi(max_hp, 1)),
		"minions": minion_count(),
		"proj": _own_projectiles(),
		"phase": phase,
		"last": _last_move,
		"floor": floor_no,
		"force_melee": _force_melee,
		"wall": absf(global_position.x - _scan_wall(away)),
	}


## Hamle yokken: oyuncuya yaklaş / mesafe tut, bekleme bitince hamle seç.
func _neutral(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_pick_cd = maxf(_pick_cd - delta, 0.0)
	if _cooldown <= 0.0 and _pick_cd <= 0.0:
		var m := UmbraKit.pick(abilities, _context(), _lock, _rng)
		if m != UmbraKit.Move.NONE:
			_force_melee = false
			_start_move(m)
			return
		_pick_cd = 0.12
	if nav.update(delta, _spd() * 1.25):
		return
	if not is_on_floor():
		return
	var dx := target.global_position.x - global_position.x
	facing = 1 if dx > 0.0 else -1
	var ad := absf(dx)
	if ad > PREFERRED_DIST + 25.0:
		velocity.x = facing * _spd()
	elif ad < PREFERRED_DIST - 80.0:
		velocity.x = -facing * _spd() * 0.5
	else:
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)


## Hamleyi hemen başlatır (testler / geliştirme). Hamle sürüyorsa kesilir. Başlarsa true.
func force_move(m: int) -> bool:
	if dead or m == UmbraKit.Move.NONE or target == null:
		return false
	if current_move != UmbraKit.Move.NONE:
		_end_move(0.0)
	_start_move(m)
	return true


func _start_move(m: int) -> void:
	current_move = m
	stage = 0
	_t = 0.0
	_last_move = m
	_lock[m] = UmbraKit.lockout(m) * _wait_mult
	_anim = ""
	move_started.emit(m)
	match m:
		UmbraKit.Move.KNIFE:
			_enter_knife(1)
		UmbraKit.Move.COMBO:
			_enter_knife(3)
		UmbraKit.Move.THROW:
			_enter_throw(1)
		UmbraKit.Move.FAN:
			_enter_throw(3)
		UmbraKit.Move.CLIMB:
			_enter_climb(false)
		UmbraKit.Move.VOLLEY:
			_enter_climb(true)
		UmbraKit.Move.MINIONS:
			_enter_summon(false)
		UmbraKit.Move.SWARM:
			_enter_summon(true)
		UmbraKit.Move.BLINK:
			_enter_blink()
		UmbraKit.Move.SLAM:
			_enter_slam()
		UmbraKit.Move.RAIN:
			_enter_rain()
		UmbraKit.Move.ORBIT:
			_enter_orbit()
		UmbraKit.Move.CLOAK:
			_enter_cloak()
		UmbraKit.Move.CLONE:
			_enter_clone()
		UmbraKit.Move.COUNTER:
			_enter_counter()
		UmbraKit.Move.WIND:
			_begin_wind(false)
		_:
			_end_move(0.0)


func _run_move(delta: float) -> void:
	match current_move:
		UmbraKit.Move.KNIFE, UmbraKit.Move.COMBO:
			_tick_knife(delta)
		UmbraKit.Move.THROW, UmbraKit.Move.FAN:
			_tick_throw(delta)
		UmbraKit.Move.CLIMB, UmbraKit.Move.VOLLEY:
			_tick_climb(delta)
		UmbraKit.Move.MINIONS, UmbraKit.Move.SWARM:
			_tick_summon(delta)
		UmbraKit.Move.BLINK:
			_tick_blink(delta)
		UmbraKit.Move.SLAM:
			_tick_slam(delta)
		UmbraKit.Move.RAIN:
			_tick_rain(delta)
		UmbraKit.Move.ORBIT:
			_tick_orbit(delta)
		UmbraKit.Move.CLOAK:
			_tick_cloak(delta)
		UmbraKit.Move.CLONE:
			_tick_clone(delta)
		UmbraKit.Move.COUNTER:
			_tick_counter(delta)
		UmbraKit.Move.WIND:
			_tick_wind(delta)


## Hamleyi bitirir ve her şeyi eski haline getirir. `wait`: sonraki hamleye kadar bekleme (< 0 ise normal bekleme).
func _end_move(wait: float = -1.0) -> void:
	attack_hitbox.active = false
	set_tell(Tell.NONE)
	_clear_cast_glow()
	_remove_blades()
	_counter_on = false
	_guard = false
	_committed = false
	_untouchable = false
	gravity = _base_gravity
	if not dead:
		collision_layer = Layers.ENEMY
	visual_alpha = 1.0
	current_move = UmbraKit.Move.NONE
	stage = 0
	_anim = ""
	_cooldown = wait if wait >= 0.0 else _next_wait()
	_refresh_armor()


## Vurulma / sersemleme: hamle yarıda kalır, kısa süre sonra yeniden karar verir.
func _cancel_move() -> void:
	if current_move == UmbraKit.Move.NONE:
		return
	_end_move(tuning.wait(_rng.randf_range(0.5, 0.9)))


# ---------------------------------------------------------------- BIÇAK / KOMBO

func _enter_knife(chain: int) -> void:
	_combo_left = chain
	_begin_slash(0.62 if chain == 1 else 0.52, -1)


## Bıçak hazırlığı (uyarı). force: -1 rastgele, 0 altın, 1 kırmızı. Kombonun son vuruşu hep kırmızıdır.
func _begin_slash(base_time: float, force: int) -> void:
	var last_of_combo := current_move == UmbraKit.Move.COMBO and _combo_left == 1
	var mult := 0.6 if current_move == UmbraKit.Move.COMBO else 1.0
	_red = _roll_red(mult, 1 if (last_of_combo and force < 0) else force)
	stage = K_TELL
	_t = _tele(base_time)
	facing = _face_target()
	_guard = true
	set_tell(Tell.RED if _red else Tell.GOLD)
	_play("telegraph", _t)


func _tick_knife(delta: float) -> void:
	_t -= delta
	match stage:
		K_TELL:
			velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
			if _t <= 0.0:
				_begin_strike()
		K_STRIKE:
			velocity.x = facing * _lunge
			if _t <= 0.0:
				_end_strike()
		K_RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
			if _t <= 0.0:
				_end_move()


func _begin_strike() -> void:
	var far := absf(target.global_position.x - global_position.x) > KNIFE_NEAR
	_lunge = (760.0 if far else 420.0) * _spd_factor()
	stage = K_STRIKE
	_t = 0.3 if far else 0.2
	visual_alpha = 1.0
	_set_attack_box(Vector2(76.0, 54.0), Vector2(facing * 40.0, 0.0))
	attack_hitbox.parryable = not _red
	attack_hitbox.damage = _dmg(2 if _red else 1)
	attack_hitbox.active = true
	_play("attack", _t)
	Sfx.play("slash", -3.0, 0.75, 0.05)


func _end_strike() -> void:
	attack_hitbox.active = false
	set_tell(Tell.NONE)
	if _combo_left > 1:
		_combo_left -= 1
		_begin_slash(0.4, -1)
		return
	stage = K_RECOVER
	_guard = false
	_t = tuning.open_time(1.0, RECOVER_FLOOR)
	_play("recover", _t)


# ---------------------------------------------------------------- FIRLATMA / ÜÇLÜ FIRLATMA

func _enter_throw(shots: int) -> void:
	_shots = shots
	_red = _roll_red(0.7)
	stage = T_TELL
	_t = _tele(0.55 if shots == 1 else 0.72)
	facing = _face_target()
	_guard = true
	set_tell(Tell.RED if _red else Tell.GOLD)
	_play("telegraph", _t)


func _tick_throw(delta: float) -> void:
	_t -= delta
	velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
	match stage:
		T_TELL:
			facing = _face_target()
			if _t <= 0.0:
				_fire_throw()
		T_RECOVER:
			if _t <= 0.0:
				_end_move()


func _fire_throw() -> void:
	set_tell(Tell.NONE)
	var origin := global_position + Vector2(facing * 20.0, -8.0)
	var speed := KNIFE_SPEED * _spd_factor()
	var base_angle := _aim_at(origin, speed).angle()
	var spread := 0.0 if _shots == 1 else 0.3
	for i in _shots:
		var ang := base_angle + (float(i) - float(_shots - 1) * 0.5) * spread
		_spawn_knife(origin, Vector2.from_angle(ang) * speed, not _red)
	_play("throw", 0.3)
	Sfx.play("shoot", -3.0, 0.9, 0.05)
	stage = T_RECOVER
	_guard = false
	_t = tuning.open_time(0.75, 0.4)


# ---------------------------------------------------------------- DUVAR TIRMANIŞI / DUVARDAN ATIŞ

func _enter_climb(volley: bool) -> void:
	_variant = 1 if volley else 0
	var away := 1 if global_position.x >= target.global_position.x else -1
	_wall_dir = away  # oyuncudan uzaktaki duvara kaçar (oyuncunun gövdesinin içinden geçemez)
	_wall_x = _scan_wall(_wall_dir)
	stage = C_RUN
	_t = clampf(absf(_wall_x - global_position.x) / maxf(_spd() * 2.0, 1.0) + 0.9, 0.9, 4.5)
	facing = _wall_dir
	_play("run")


func _tick_climb(delta: float) -> void:
	_t -= delta
	match stage:
		C_RUN:
			facing = _wall_dir
			velocity.x = _wall_dir * _spd() * 2.0
			if absf(global_position.x - _wall_x) <= 14.0:
				_begin_climb_up()
			elif _t <= 0.0:
				_end_move(0.8)  # duvara varamadı (bir engele takıldı): vazgeç
		C_UP:
			facing = _wall_dir
			velocity = Vector2(_wall_dir * 50.0, -CLIMB_SPEED)
			if global_position.y <= _hang_y or _t <= 0.0:
				_begin_hang()
		C_HANG:
			velocity = Vector2.ZERO
			if _t <= 0.0:
				if _variant == 0:
					_begin_dive()
				else:
					_begin_volley()
		C_ACT:
			if _variant == 0:
				_tick_dive()
			else:
				_tick_volley(delta)
		C_RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
			if _t <= 0.0:
				_end_move()


func _begin_climb_up() -> void:
	stage = C_UP
	_committed = true
	gravity = 0.0
	_hang_y = global_position.y - clampf(absf(_wall_x - target.global_position.x) * CLIMB_PER_PX, CLIMB_MIN, CLIMB_MAX)
	velocity = Vector2(_wall_dir * 50.0, -CLIMB_SPEED)
	_t = 1.2
	_play("climb")
	Sfx.play("dash", -8.0, 0.8)


func _begin_hang() -> void:
	stage = C_HANG
	velocity = Vector2.ZERO
	facing = -_wall_dir  # arenaya döner
	if _variant == 0:
		_red = _roll_red(1.1)
	else:
		_red = false  # atış: ilk iki bıçak altın, sonuncu kırmızı; uyarı altın
	_t = _tele(0.85 if _variant == 0 else 0.7)
	set_tell(Tell.RED if _red else Tell.GOLD)
	_play("cling", _t)


func _begin_dive() -> void:
	stage = C_ACT
	var aim := ((target.global_position + Vector2(0.0, -6.0)) - global_position).normalized()
	aim.y = maxf(aim.y, 0.4)
	aim = aim.normalized()
	velocity = aim * DIVE_SPEED * _spd_factor()
	facing = 1 if velocity.x >= 0.0 else -1
	_t = clampf(global_position.distance_to(target.global_position) / maxf(velocity.length(), 1.0) + 0.45, 0.8, 1.8)  # uzak oyuncuya da yetişsin
	_set_attack_box(Vector2(52.0, 62.0), Vector2.ZERO)
	attack_hitbox.parryable = not _red
	attack_hitbox.damage = _dmg(2 if _red else 1)
	attack_hitbox.active = true
	_play("dive")
	Sfx.play("thrust", -2.0, 0.85, 0.04)


func _tick_dive() -> void:
	# (`_t` _tick_climb'in başında azaltılır)
	if is_on_floor() or is_on_wall() or _t <= 0.0:
		_end_dive()


func _end_dive() -> void:
	attack_hitbox.active = false
	set_tell(Tell.NONE)
	gravity = _base_gravity
	_committed = false
	velocity.x *= 0.15
	stage = C_RECOVER
	_t = tuning.open_time(1.1, RECOVER_FLOOR)
	_play("recover", _t)
	EventBus.screen_shake.emit(6.0, 0.2)
	RingFx.spawn(get_parent(), Vector2(global_position.x, feet_y()), Color(1.0, 0.85, 0.5, 0.8), 8.0, 70.0, 0.3)
	Sfx.play("land", -3.0, 0.9)


func _begin_volley() -> void:
	stage = C_ACT
	_shots = 3
	_fx_t = 0.0
	set_tell(Tell.NONE)


func _tick_volley(delta: float) -> void:
	_fx_t -= delta
	if _fx_t > 0.0:
		return
	if _shots <= 0:
		_end_volley()
		return
	var origin := global_position + Vector2(facing * 18.0, 4.0)
	var speed := KNIFE_SPEED * _spd_factor()
	var dir := _aim_at(origin, speed)
	dir.y = maxf(dir.y, -0.1)
	_spawn_knife(origin, dir.normalized() * speed, _shots != 1)  # sonuncu kırmızı
	_play("throw", 0.25)
	Sfx.play("shoot", -3.0, 0.95, 0.05)
	_shots -= 1
	_fx_t = 0.36 if _shots > 0 else 0.5


func _end_volley() -> void:
	gravity = _base_gravity
	_committed = false
	velocity = Vector2(-_wall_dir * 160.0, -120.0)
	stage = C_RECOVER
	_t = tuning.open_time(0.9, RECOVER_FLOOR)
	_play("recover", _t)


# ---------------------------------------------------------------- MİNYON / SÜRÜ

func _enter_summon(swarm: bool) -> void:
	_variant = 1 if swarm else 0
	stage = M_CAST
	_t = tuning.warn(1.0, 0.55)
	velocity.x = 0.0
	facing = _face_target()
	_guard = true
	_cast_glow(PURPLE)
	_play("summon", _t)
	RingFx.spawn(get_parent(), Vector2(global_position.x, feet_y()), Color(PURPLE, 0.8), 8.0, 56.0, _t)


func _tick_summon(delta: float) -> void:
	_t -= delta
	velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
	if _t > 0.0:
		return
	match stage:
		M_CAST:
			_do_summon()
			stage = M_RECOVER
			_guard = false
			_clear_cast_glow()
			_t = tuning.open_time(0.7, 0.4)
			_play("recover", _t)
		M_RECOVER:
			_end_move()


func _do_summon() -> void:
	var want := UmbraKit.minion_count(floor_no, _variant == 1)
	var room_left := maxi(int(spec["minion_cap"]) - minion_count(), 0)
	var n := mini(want, room_left)
	var bounds := arena_bounds()
	for i in n:
		var x := global_position.x + (float(i) - float(n - 1) * 0.5) * 120.0
		if absf(x - target.global_position.x) < 70.0:
			x += 130.0 * (1.0 if x >= target.global_position.x else -1.0)
		x = clampf(x, bounds.x + WALL_MARGIN, bounds.y - WALL_MARGIN)
		_spawn_minion(Vector2(x, feet_y() - MINION_HALF_H), UmbraMinion.Kind.SHADE, 0.7)
	Sfx.play("spawn", -3.0, 0.7)


func _spawn_minion(pos: Vector2, kind: int, emerge: float) -> UmbraMinion:
	var m := MINION_SCENE.instantiate() as UmbraMinion
	m.tuning = tuning
	m.kind = kind as UmbraMinion.Kind
	m.emerge_time = emerge
	m.set_meta("floor", floor_no)
	get_parent().add_child(m)
	m.global_position = pos
	RingFx.spawn(get_parent(), pos + Vector2(0.0, MINION_HALF_H), Color(PURPLE, 0.9), 8.0, 46.0, 0.4)
	return m


# ---------------------------------------------------------------- GÖLGE ADIMI

func _enter_blink() -> void:
	stage = B_VANISH
	_t = 0.28
	velocity.x = 0.0
	_untouchable = true
	set_tell(Tell.NONE)
	RingFx.spawn(get_parent(), global_position, Color(PURPLE, 0.8), 6.0, 40.0, 0.25)
	Sfx.play("vanish", -3.0)
	_play("vanish", _t)


func _tick_blink(delta: float) -> void:
	_t -= delta
	velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
	match stage:
		B_VANISH:
			visual_alpha = clampf(_t / 0.28, 0.0, 1.0)
			if _t <= 0.0:
				_dest = _blink_spot()
				if is_nan(_dest.x):
					_end_move(0.8)  # arkasına geçecek yer yok
					return
				visual_alpha = 0.0
				collision_layer = 0
				stage = B_MARK
				_t = tuning.warn(0.55, 0.3)
				UmbraMark.spawn(get_parent(), Vector2(_dest.x, _dest.y + _body_bottom()), UmbraMark.Look.RING, _t, PURPLE, self)
		B_MARK:
			visual_alpha = 0.0
			if _t <= 0.0:
				_blink_appear()


## Oyuncunun arkasında boş bir nokta (gövde pozisyonu). Yoksa (NAN, NAN).
func _blink_spot() -> Vector2:
	var side := -target.facing
	for s: int in [side, -side]:
		var pos := Vector2(target.global_position.x + float(s) * BLINK_OFFSET, target.feet_y() - _body_bottom())
		if _spot_free(pos):
			return pos
	return Vector2(NAN, NAN)


func _blink_appear() -> void:
	global_position = _dest
	velocity = Vector2.ZERO
	collision_layer = Layers.ENEMY
	_untouchable = false
	visual_alpha = 1.0
	flash(Color(0.8, 0.6, 1.0), 0.2)
	RingFx.spawn(get_parent(), global_position, Color(PURPLE, 0.9), 6.0, 46.0, 0.25)
	Sfx.play("spawn", -6.0, 1.2)
	current_move = UmbraKit.Move.KNIFE  # çıkar çıkmaz bıçak: arkadan vuruş
	_combo_left = 1
	_begin_slash(0.34, -1)


# ---------------------------------------------------------------- YER DARBESİ

func _enter_slam() -> void:
	_red = true
	stage = S_TELL
	_t = tuning.warn(0.55, 0.32)
	facing = _face_target()
	velocity.x = 0.0
	_guard = true
	set_tell(Tell.RED)
	_play("telegraph", _t)


func _tick_slam(delta: float) -> void:
	_t -= delta
	match stage:
		S_TELL:
			velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
			facing = _face_target()
			if _t <= 0.0:
				_begin_leap()
		S_AIR:
			_air_t += delta
			var want := clampf((target.global_position.x - global_position.x) * 1.4, -SLAM_AIR_SPEED, SLAM_AIR_SPEED)
			velocity.x = move_toward(velocity.x, want, 500.0 * delta)
			if (_air_t > 0.2 and is_on_floor()) or _air_t > 2.5:
				_begin_shock()
		S_SHOCK:
			velocity.x = 0.0
			if _t <= 0.0:
				attack_hitbox.active = false
				stage = S_RECOVER
				_guard = false
				_committed = false
				_t = tuning.open_time(1.0, RECOVER_FLOOR)
				_play("recover", _t)
		S_RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
			if _t <= 0.0:
				_end_move()


func _begin_leap() -> void:
	stage = S_AIR
	_air_t = 0.0
	_committed = true
	var dx := target.global_position.x - global_position.x
	velocity = Vector2(clampf(dx, -SLAM_AIR_SPEED, SLAM_AIR_SPEED), -980.0)
	_play("slam")
	Sfx.play("dash", -4.0, 0.7)


func _begin_shock() -> void:
	stage = S_SHOCK
	_t = 0.16
	set_tell(Tell.NONE)
	_set_attack_box(Vector2(150.0, 50.0), Vector2(0.0, 8.0))
	attack_hitbox.parryable = false
	attack_hitbox.damage = _dmg(2)
	attack_hitbox.active = true
	var y := feet_y() - 14.0
	for dir in [-1, 1]:
		var p := _spawn_knife(Vector2(global_position.x + float(dir) * 50.0, y), Vector2(float(dir) * SHOCK_SPEED * _spd_factor(), 0.0), false)
		p.lifetime = 2.2
	EventBus.screen_shake.emit(9.0, 0.3)
	RingFx.spawn(get_parent(), Vector2(global_position.x, feet_y()), Color(1.0, 0.4, 0.4, 0.9), 12.0, 140.0, 0.35)
	Sfx.play("land", -1.0, 0.8)


# ---------------------------------------------------------------- BIÇAK YAĞMURU

func _enter_rain() -> void:
	stage = R_CAST
	_t = tuning.warn(0.8, 0.45)
	velocity.x = 0.0
	facing = _face_target()
	_guard = true
	_cast_glow(CAST_RED)
	_play("cast", _t)


func _tick_rain(delta: float) -> void:
	_t -= delta
	velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
	if _t > 0.0:
		return
	match stage:
		R_CAST:
			_do_rain()
			stage = R_WAIT
			_clear_cast_glow()
			_t = 1.5
		R_WAIT:
			stage = R_RECOVER
			_guard = false
			_t = tuning.open_time(0.5, 0.3)
			_play("recover", _t)
		R_RECOVER:
			_end_move()


func _do_rain() -> void:
	var n := int(spec["rain"])
	var bounds := arena_bounds()
	var px := target.global_position.x
	var floor_y := target.feet_y()
	for i in n:
		var x := px
		if i > 0:
			var k := (i + 1) / 2
			var sgn := 1.0 if i % 2 == 1 else -1.0
			x = px + sgn * (float(k) * 120.0 + _rng.randf_range(-30.0, 30.0))
		x = clampf(x, bounds.x + WALL_MARGIN, bounds.y - WALL_MARGIN)
		var mark := UmbraMark.spawn(get_parent(), Vector2(x, floor_y), UmbraMark.Look.LINE, 0.35 + 0.1 * float(i), CAST_RED, self, RAIN_HEIGHT, 0.9)
		mark.fired.connect(_drop_knife.bind(x, floor_y - RAIN_HEIGHT))


func _drop_knife(x: float, y: float) -> void:
	if dead or not is_inside_tree():
		return
	_spawn_knife(Vector2(x, y), Vector2(0.0, RAIN_SPEED), false)
	Sfx.play("shoot", -9.0, 1.3, 0.05)


# ---------------------------------------------------------------- DÖNEN BIÇAKLAR

func _enter_orbit() -> void:
	stage = O_TELL
	_t = tuning.warn(0.6, 0.35)
	velocity.x = 0.0
	facing = _face_target()
	_guard = true
	_cast_glow(CAST_GOLD)
	_play("cast", _t)


func _tick_orbit(delta: float) -> void:
	_t -= delta
	match stage:
		O_TELL:
			velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
			if _t <= 0.0:
				_spawn_blades()
				_clear_cast_glow()
				stage = O_ACTIVE
				_t = ORBIT_TIME
		O_ACTIVE:
			var dx := target.global_position.x - global_position.x
			facing = 1 if dx > 0.0 else -1
			if absf(dx) > 60.0:
				velocity.x = facing * _spd() * 1.1
			else:
				velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
			if _t <= 0.0:
				_remove_blades()
				stage = O_RECOVER
				_guard = false
				_t = tuning.open_time(0.8, 0.4)
				_play("recover", _t)
		O_RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
			if _t <= 0.0:
				_end_move()


func _spawn_blades() -> void:
	_remove_blades()
	var n := int(spec["orbit"])
	for i in n:
		var b := UmbraBlade.new()
		add_child(b)
		b.setup(self, i, n, _dmg(1), ORBIT_RADIUS)
		_blades.append(b)
	Sfx.play("spawn", -5.0, 1.3)


# ---------------------------------------------------------------- GİZLENME

func _enter_cloak() -> void:
	stage = Z_FADE
	_t = 0.3
	velocity.x = 0.0
	set_tell(Tell.NONE)
	Sfx.play("vanish", -4.0, 0.8)
	_play("vanish", _t)


func _tick_cloak(delta: float) -> void:
	_t -= delta
	match stage:
		Z_FADE:
			velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
			visual_alpha = lerpf(CLOAK_ALPHA, 1.0, clampf(_t / 0.3, 0.0, 1.0))
			if _t <= 0.0:
				visual_alpha = CLOAK_ALPHA
				stage = Z_STALK
				_t = 2.4
				_anim = ""
		Z_STALK:
			visual_alpha = CLOAK_ALPHA
			var dx := target.global_position.x - global_position.x
			var level := absf(target.feet_y() - feet_y()) <= LEVEL_TOLERANCE
			if not level and nav.update(delta, _spd() * 1.4):
				if _t <= 0.0:
					_end_move()
				return
			facing = 1 if dx > 0.0 else -1
			if absf(dx) > 120.0:
				velocity.x = facing * _spd() * 1.4
			else:
				velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
			if level and absf(dx) <= 150.0:
				current_move = UmbraKit.Move.KNIFE  # sinsi bir darbe: uyarı sırasında yarı görünür
				_combo_left = 1
				visual_alpha = 0.55
				_begin_slash(0.38, -1)
			elif _t <= 0.0:
				_end_move()


# ---------------------------------------------------------------- GÖLGE KLONU

func _enter_clone() -> void:
	stage = M_CAST
	_t = tuning.warn(0.7, 0.4)
	velocity.x = 0.0
	facing = _face_target()
	_guard = true
	_cast_glow(PURPLE)
	_play("cast", _t)
	RingFx.spawn(get_parent(), Vector2(global_position.x, feet_y()), Color(PURPLE, 0.8), 8.0, 56.0, _t)


func _tick_clone(delta: float) -> void:
	_t -= delta
	velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
	if _t > 0.0:
		return
	_do_clone()
	_clear_cast_glow()
	# Gölge'nin kendi darbesi ALTIN, klonunki KIRMIZI: önce altını parry'le, sonra kırmızıdan kaç.
	current_move = UmbraKit.Move.KNIFE
	_combo_left = 1
	_begin_slash(0.7, 0)


func _do_clone() -> void:
	var bounds := arena_bounds()
	var px := target.global_position.x
	var side := -1.0 if global_position.x >= px else 1.0  # Gölge'nin KARŞI yanı
	var x := clampf(px + side * 130.0, bounds.x + WALL_MARGIN, bounds.y - WALL_MARGIN)
	var m := _spawn_minion(Vector2(x, target.feet_y() - MINION_HALF_H), UmbraMinion.Kind.CLONE, 0.35)
	m.facing = 1 if px > x else -1


# ---------------------------------------------------------------- KARŞI DURUŞ

func _enter_counter() -> void:
	stage = 0
	_t = COUNTER_TIME
	velocity.x = 0.0
	facing = _face_target()
	_counter_on = true
	_guard = true
	_cast_glow(GUARD_BLUE)
	_play("counter")


func _tick_counter(delta: float) -> void:
	_t -= delta
	velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
	facing = _face_target()
	if _t <= 0.0:
		# Beklediysen: yavaş, ALTIN bir darbe (parry fırsatı).
		_counter_on = false
		_clear_cast_glow()
		current_move = UmbraKit.Move.KNIFE
		_combo_left = 1
		_begin_slash(0.55, 0)


## Duruştayken oyuncunun vuruşu boşa gider; Gölge anında KIRMIZI karşılık verir.
func _counter_hit() -> void:
	_counter_on = false
	_clear_cast_glow()
	flash(GUARD_BLUE, 0.2)
	RingFx.spawn(get_parent(), global_position, Color(GUARD_BLUE, 0.9), 8.0, 70.0, 0.25)
	Sfx.play("parry", -3.0, 1.4)
	current_move = UmbraKit.Move.KNIFE
	_combo_left = 1
	_begin_slash(0.17, 1)


# ---------------------------------------------------------------- SOLUKLANMA (ikinci nefes / öfke)

## `revive`: ikinci nefes (canı %30'a döner). Her iki durumda da evre 2'ye geçer ve kükrerken dokunulmazdır.
func _begin_wind(revive: bool) -> void:
	_end_move(0.0)
	current_move = UmbraKit.Move.WIND
	stage = 0
	_t = WIND_TIME
	_fx_t = 0.0
	_untouchable = true
	_committed = true
	_armor_t = 0.0
	stun_t = 0.0
	knock_t = 0.0
	velocity = Vector2.ZERO
	if revive:
		health = maxi(1, roundi(float(max_hp) * WIND_REVIVE))
	flash(Color(1.0, 0.5, 0.5), 0.5)
	Sfx.play("tier_up", 0.0, 0.7)
	_enter_phase(2)
	_play("roar")
	_refresh_armor()
	move_started.emit(current_move)


func _tick_wind(delta: float) -> void:
	_t -= delta
	velocity.x = 0.0
	_fx_t -= delta
	if _fx_t <= 0.0:
		_fx_t = 0.35
		RingFx.spawn(get_parent(), global_position, Color(1.0, 0.4, 0.4, 0.8), 10.0, 120.0, 0.5)
		EventBus.screen_shake.emit(5.0, 0.2)
	if _t <= 0.0:
		_end_move(tuning.wait(0.5))


func _enter_phase(p: int) -> void:
	if p <= phase:
		return
	phase = p
	phase_changed.emit(p)
	EventBus.boss_phase.emit(self, p)


# ---------------------------------------------------------------- vurulma / sersemleme

func on_hit_by(hitbox: Hitbox) -> bool:
	if dead or _untouchable:
		return false
	if _counter_on and hitbox.faction == "player" and not (hitbox is Projectile):
		_counter_hit()
		return false
	var was_armored := armored
	var landed := super.on_hit_by(hitbox)
	if landed and not dead:
		_after_hit(was_armored)
	return landed


func _after_hit(was_armored: bool) -> void:
	# Poise: kısa sürede 3 kez sersemletilirse 1.5 sn zırhlanır ve karşılık verir (sonsuz kombo yok).
	if not was_armored and knock_t > 0.0:
		_poise_hits += 1
		_poise_t = POISE_MEMORY
		if _poise_hits >= POISE_LIMIT:
			_poise_hits = 0
			_armor_t = POISE_ARMOR
			_cooldown = 0.0
			_force_melee = true
			RingFx.spawn(get_parent(), global_position, Color(0.85, 0.92, 1.0, 0.9), 8.0, 80.0, 0.3)
			Sfx.play("shield_break", -3.0, 0.8)


## Can bitti: ikinci nefes yeteneği varsa bir kez kalkar.
func _on_health_depleted() -> void:
	if bool(spec["second_wind"]) and not _wind_used:
		_wind_used = true
		_begin_wind(true)
		return
	super._on_health_depleted()


func _on_interrupted() -> void:
	if current_move == UmbraKit.Move.WIND:
		return
	_cancel_move()


func _on_stunned() -> void:
	attack_hitbox.active = false
	_armor_t = 0.0
	_committed = false
	_guard = false
	if current_move != UmbraKit.Move.NONE:
		_end_move(tuning.wait(_rng.randf_range(0.4, 0.7)))


func _on_stun_end() -> void:
	_cooldown = minf(_cooldown, tuning.wait(0.5))


## Altın darbe parry'lendi: Gölge sersemler, cezalandırma fırsatı.
func _on_attack_parried(_by: Node) -> void:
	attack_hitbox.active = false
	stun(tuning.stun_time(1.0, PARRY_STUN_FLOOR))
	velocity.x = 0.0


## CEZA (zekâ): oyuncu parry'yi ıskaladı (toparlanıyor). Yakındaysa Gölge hemen, kısaltılmış uyarıyla yakın dövüşle saldırır.
func _on_player_parry_failed(actor: Node) -> void:
	if actor != target or current_move != UmbraKit.Move.NONE or dead or target == null:
		return
	if absf(target.global_position.x - global_position.x) > KNIFE_NEAR * 1.3:
		return
	if randf() >= clampf(0.25 + tuning.punish + 0.01 * float(floor_no), 0.0, 0.95):
		return
	_cooldown = 0.0
	_quick = true
	_force_melee = true


func _on_death() -> void:
	attack_hitbox.active = false
	_counter_on = false
	_remove_blades()
	gravity = _base_gravity
	get_tree().call_group("minions", "dissolve")
	for node in get_tree().get_nodes_in_group("projectiles"):
		var pr := node as Projectile
		if pr != null and pr.faction == "enemy" and pr.original_source == self:
			pr.queue_free()
	EventBus.boss_defeated.emit(self)
	EventBus.screen_flash.emit(Color(0.8, 0.65, 1.0), 0.55, 0.7)
	EventBus.screen_shake.emit(14.0, 0.6)
	Hitstop.freeze(0.2)
	Sfx.play("kill", 0.0, 0.7)
	for i in 3:
		RingFx.spawn(get_parent(), global_position, Color(PURPLE, 0.9), 12.0, 120.0 + 60.0 * float(i), 0.5 + 0.12 * float(i))
