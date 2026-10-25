class_name Scorpius
extends EnemyBase
## Scorpius (Akrep): iki rapier'li vur-kaç dövüşçüsü. Mesafe oyunu oynar; saldırıları az ama keskindir.
##
## DURUMLAR (Phase)
##   SPACING   Mesafe kontrolü. Kılıç menzilinde (ideal_distance) durur. Oyuncu çok yakınsa (close_range)
##             geriye hızlı takla (BACKFLIP) atar; uzaksa (far_range) sakin adımlarla yürür.
##             Menzildeyken kısa bir süre sonra saldırır. Kaçacak yeri yoksa (köşe) çaresiz bir dürtüşle karşılık verir.
##   TELL      Çok kısa ALTIN uyarı. Bu GERÇEK dürtüş mü, SAHTE mi? Oyuncu bilemez.
##   LUNGE     Gerçek dürtüş: ince, çok hızlı ve parry'lenebilir (altın) bir hat. Tam zamanında parry'lenirse
##             Scorpius geri çekilemez: STUNNED (1.5 sn) ve oyuncunun hasar vurabileceği güvenli pencere açılır.
##   RETREAT   Dürtüş biter bitmez (vursa da, kaçılsa da) arkaya zıplayıp SPACING'e döner.
##   FEINT     Sahte saldırı: TELL ile birebir aynı başlar. Oyuncu "erken" parry'ye basarsa (gerçek bir dürtüşü
##             asla tutamayacak kadar erken) Scorpius iptal eder, VANISH ile oyuncunun arkasına geçer,
##             STAB_TELL + STAB ile sırttan vurur. Basmazsa saldırı boşa çıkar (FEINT_END) ve RETREAT.
##
## Sahte saldırı kuralları: ilk saldırı hep gerçektir; arka arkaya iki sahte saldırı yapmaz.
## Vurulunca (zırhsız) hazırlanan her saldırı iptal olur (EnemyBase.stagger).

const BLADE_START := 20.0
const BLADE_LENGTH := 112.0
const BLADE_CENTER := BLADE_START + BLADE_LENGTH * 0.5
## Saldırıya geçmek için hedefle ayak seviyesi farkı en fazla bu kadar olabilir (px).
const ATTACK_LEVEL_TOLERANCE := 72.0
## Bundan kısa takla/geri zıplama yapılmaz (kaçacak yer yok sayılır).
const MIN_HOP_DISTANCE := 40.0
const STAB_OFFSET := 52.0
const VANISH_TIME := 0.1
const STAB_TELL_TIME := 0.2
const STAB_TIME := 0.1
const RETREAT_DISTANCE := 170.0
const RETREAT_TIME := 0.34
const BACKFLIP_TIME := 0.42

## Scorpius'a özgü animasyonlar (taban düşman animasyonlarına eklenir).
const SCORPIUS_ANIMS := {
	"backflip": {"fps": 14.0, "loop": false, "fallback": "jump"},
	"retreat": {"fps": 12.0, "loop": false, "fallback": "backflip"},
	"vanish": {"fps": 16.0, "loop": false, "fallback": "idle"},
	"stab_telegraph": {"fps": 14.0, "loop": false, "fallback": "telegraph"},
	"stab": {"fps": 16.0, "loop": false, "fallback": "attack"},
}

@export var walk_speed := 130.0
## Kılıç menzili: dürtüşün oyuncuya ulaştığı mesafe. Scorpius bu mesafeyi korumaya çalışır.
@export var ideal_distance := 135.0
## Bundan yakınsa geri takla atar.
@export var close_range := 85.0
## Bundan uzaksa yürüyerek yaklaşır; saldırı da en çok bu mesafeden başlar.
@export var far_range := 175.0
## Uyarı (telegraph) süresi: dürtüşten önce altın işaretin görünme süresi.
@export var tell_time := 0.34
@export var lunge_time := 0.12
@export var lunge_speed := 560.0
## Gerçek dürtüş parry'lenince sersemleme süresi.
@export var stun_time := 1.5
## Saldırının sahte olma şansı (ilk saldırı hariç, arka arkaya iki sahte yok).
@export_range(0.0, 1.0) var feint_chance := 0.35

enum Phase { SPACING, BACKFLIP, TELL, LUNGE, FEINT_END, RETREAT, VANISH, STAB_TELL, STAB, STUNNED }

var _phase := Phase.SPACING
## Evrenin başından beri geçen süre ve evreye özgü geri sayım.
var _phase_t := 0.0
var _timer := 0.0
var _decide_t := 1.0
var _hop_cooldown := 0.0
var _hop_duration := BACKFLIP_TIME
var _cornered_t := 0.0
var _feint := false
var _last_feint := false
var _bait := false
var _tell_total := 0.34
var _attacks_done := 0
var _stab_x := 0.0
var _alpha_tween: Tween

@onready var attack_hitbox: Hitbox = $AttackHitbox


func anim_folder() -> String:
	return "res://assets/sprites/scorpius"


func anim_spec() -> Dictionary:
	return EnemyBase.ANIM_SPEC.merged(SCORPIUS_ANIMS)


func _ready() -> void:
	super._ready()
	attack_hitbox.source = self
	attack_hitbox.set_faction("enemy")
	attack_hitbox.active = false
	attack_hitbox.parried.connect(_on_attack_parried)
	EventBus.parry_started.connect(_on_player_parry_started)
	_decide_t = randf_range(0.9, 1.5)


func _exit_tree() -> void:
	if EventBus.parry_started.is_connected(_on_player_parry_started):
		EventBus.parry_started.disconnect(_on_player_parry_started)


# ---------------------------------------------------------------- yapay zekâ

func _ai(delta: float) -> void:
	if target == null or target.dead:
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
		return
	_phase_t += delta
	_hop_cooldown = maxf(_hop_cooldown - delta, 0.0)
	match _phase:
		Phase.SPACING:
			_ai_spacing(delta)
		Phase.BACKFLIP, Phase.RETREAT:
			_ai_hop(delta)
		Phase.TELL:
			_ai_tell(delta)
		Phase.LUNGE:
			_ai_lunge(delta)
		Phase.FEINT_END:
			_ai_feint_end(delta)
		Phase.VANISH:
			_ai_vanish(delta)
		Phase.STAB_TELL:
			_ai_stab_tell(delta)
		Phase.STAB:
			_ai_stab(delta)
		Phase.STUNNED:
			velocity.x = move_toward(velocity.x, 0.0, 2400.0 * delta)


func _set_phase(p: Phase) -> void:
	if _phase == Phase.VANISH and p != Phase.VANISH:
		_restore_body()
	_phase = p
	_phase_t = 0.0


func _dir_to_target() -> int:
	return 1 if target.global_position.x > global_position.x else -1


# ---- SPACING: mesafe kontrolü

func _ai_spacing(delta: float) -> void:
	# Hedef başka bir yükseklikteyse: platforma çık / in (Taurus ile aynı yöntem).
	if nav.update(delta, walk_speed * 1.2):
		return
	if not is_on_floor():
		return
	var dx := target.global_position.x - global_position.x
	var dist := absf(dx)
	facing = 1 if dx > 0.0 else -1
	var same_level := absf(target.feet_y() - feet_y()) <= ATTACK_LEVEL_TOLERANCE
	_cornered_t = maxf(_cornered_t - delta, 0.0)
	# Çok yakın: geriye takla. Kaçacak yer yoksa köşeye sıkışmış sayılır.
	if same_level and dist < close_range and _hop_cooldown <= 0.0:
		if _begin_backflip(dist):
			return
		_cornered_t = 0.6
	if dist > far_range:
		velocity.x = facing * walk_speed
	elif dist < ideal_distance - 22.0:
		velocity.x = -facing * walk_speed * 0.75  # küçük geri adım (kılıç oyunu ayak hareketi)
	elif dist > ideal_distance + 22.0:
		velocity.x = facing * walk_speed * 0.75
	else:
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
	var in_band := dist >= close_range and dist <= far_range
	if same_level and (in_band or _cornered_t > 0.0):
		_decide_t -= delta
		if _decide_t <= 0.0:
			_begin_attack(false if _cornered_t > 0.0 else _pick_feint())


## Bir sonraki saldırı sahte mi? İlk saldırı gerçek, art arda iki sahte yok.
func _pick_feint() -> bool:
	if _attacks_done < 1 or _last_feint:
		_last_feint = false
		return false
	_last_feint = randf() < feint_chance
	return _last_feint


# ---- Zıplamalar: BACKFLIP (mesafe düzeltme) ve RETREAT (saldırı sonrası geri çekilme)

func _begin_backflip(dist: float) -> bool:
	var want := clampf(ideal_distance + randf_range(-10.0, 25.0) - dist, 80.0, 220.0)
	return _begin_hop(Phase.BACKFLIP, want, BACKFLIP_TIME)


func _begin_retreat() -> void:
	if not _begin_hop(Phase.RETREAT, RETREAT_DISTANCE, RETREAT_TIME):
		_set_phase(Phase.SPACING)
		_decide_t = randf_range(0.5, 0.9)


## Hedeften uzağa, hedefe bakmaya devam ederek zıplar. Arkası kapalıysa (duvar) false döner.
func _begin_hop(kind: Phase, distance: float, duration: float) -> bool:
	var away := -_dir_to_target()
	var free := _free_distance(away, distance)
	if free < MIN_HOP_DISTANCE:
		return false
	facing = -away
	velocity = Vector2(away * free / duration, -gravity * duration * 0.5)
	_set_phase(kind)
	_timer = duration
	_hop_duration = duration
	set_tell(Tell.NONE)
	Sfx.play("dash", -9.0, 1.3, 0.05)
	return true


## `dir` yönünde en çok `max_dist` px'lik serbest yol (20 px adımlarla). Hiç yoksa 0.
func _free_distance(dir: int, max_dist: float) -> float:
	var d := max_dist
	while d >= MIN_HOP_DISTANCE:
		if not test_move(global_transform, Vector2(dir * d, 0.0)):
			return d
		d -= 20.0
	return 0.0


func _ai_hop(delta: float) -> void:
	_timer -= delta
	# Havadayken yatay hız korunur; yere inince biter (en az 0.12 sn sonra, emniyet için üst sınır da var).
	var landed := is_on_floor() and _phase_t > 0.12
	if landed or _phase_t > _hop_duration + 0.6:
		var was_flip := _phase == Phase.BACKFLIP
		velocity.x = 0.0
		_set_phase(Phase.SPACING)
		_hop_cooldown = 0.35
		_decide_t = randf_range(0.5, 0.9) if was_flip else randf_range(0.7, 1.3)


# ---- TELL / LUNGE / FEINT

## Saldırıyı başlatır. `feint` true ise sahte (dışarıdan aynı görünür).
func _begin_attack(feint: bool) -> void:
	_feint = feint
	_bait = false
	if not feint:
		_last_feint = false
	facing = _dir_to_target()
	_tell_total = tell_time * (1.25 if (_attacks_done == 0 and not feint) else 1.0)
	_set_phase(Phase.TELL)
	_timer = _tell_total
	set_tell(Tell.GOLD)
	anim.trigger("telegraph", _tell_total)


## Oyuncu parry'ye bastı. Sahte saldırının uyarısı sürerken, gerçek bir dürtüşü tutamayacak kadar erkense yem yutuldu.
func _on_player_parry_started(actor: Node) -> void:
	if actor != target or _phase != Phase.TELL or not _feint or _bait:
		return
	var window := 0.12
	if target != null and target.stats != null:
		window = target.stats.value("parry_window")
	if _phase_t < _tell_total - window:
		_bait = true


func _ai_tell(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
	if _bait:
		_begin_vanish()
		return
	_timer -= delta
	if _timer > 0.0:
		return
	if _feint:
		_begin_feint_end()
	else:
		_begin_lunge()


func _begin_lunge() -> void:
	_set_phase(Phase.LUNGE)
	_timer = lunge_time
	attack_hitbox.position = Vector2(facing * BLADE_CENTER, -4.0)
	attack_hitbox.parryable = true
	attack_hitbox.damage = 1
	attack_hitbox.active = true
	anim.trigger("attack", lunge_time)
	Sfx.play("thrust", -3.0, 1.0, 0.04)


func _ai_lunge(delta: float) -> void:
	velocity.x = facing * lunge_speed
	_timer -= delta
	if _timer <= 0.0:
		attack_hitbox.active = false
		set_tell(Tell.NONE)
		_attacks_done += 1
		_begin_retreat()


## Sahte saldırı boşa çıktı: kısa bir sahte adım, sonra geri çekilme. Hasar alanı HİÇ açılmaz.
func _begin_feint_end() -> void:
	_set_phase(Phase.FEINT_END)
	_timer = 0.1
	set_tell(Tell.NONE)
	anim.trigger("attack", 0.1)
	Sfx.play("whiff", -7.0, 1.4)


func _ai_feint_end(delta: float) -> void:
	velocity.x = facing * 200.0
	_timer -= delta
	if _timer <= 0.0:
		_attacks_done += 1
		_begin_retreat()


## Gerçek dürtüş tam zamanında parry'lendi: geri çekilemez, 1.5 sn sersemler.
func _on_attack_parried(_by: Node) -> void:
	attack_hitbox.active = false
	stun(stun_time)
	velocity.x = 0.0


# ---- Yem yutuldu: VANISH -> STAB_TELL -> STAB

func _begin_vanish() -> void:
	var spot := _find_stab_spot()
	if is_nan(spot):
		# Arkasına geçecek yer yok: sahte saldırı boşa çıkmış gibi davran.
		_bait = false
		_begin_feint_end()
		return
	_stab_x = spot
	_bait = false
	set_tell(Tell.NONE)
	velocity = Vector2.ZERO
	_set_phase(Phase.VANISH)
	_timer = VANISH_TIME
	collision_layer = 0
	if hurtbox != null:
		hurtbox.set_deferred("monitorable", false)
	if _alpha_tween != null:
		_alpha_tween.kill()
	_alpha_tween = create_tween()
	_alpha_tween.tween_property(self, "visual_alpha", 0.0, VANISH_TIME * 0.8)
	RingFx.spawn(get_parent(), global_position, Color(0.75, 0.55, 1.0, 0.8), 6.0, 38.0, 0.25)
	Sfx.play("vanish", -3.0)
	anim.trigger("vanish", VANISH_TIME)


func _ai_vanish(delta: float) -> void:
	velocity = Vector2.ZERO
	_timer -= delta
	if _timer > 0.0:
		return
	global_position.x = _stab_x
	velocity = Vector2.ZERO
	facing = _dir_to_target()
	_set_phase(Phase.STAB_TELL)  # görünmezlik burada geri alınır (_restore_body)
	_timer = STAB_TELL_TIME
	visual_alpha = 1.0
	flash(Color(0.8, 0.6, 1.0), 0.2)
	RingFx.spawn(get_parent(), global_position, Color(0.75, 0.55, 1.0, 0.9), 6.0, 42.0, 0.25)
	set_tell(Tell.RED)  # arkadan vuruş parry'lenemez: kırmızı (sembolsüz) uyarı
	anim.trigger("stab_telegraph", STAB_TELL_TIME)


func _ai_stab_tell(delta: float) -> void:
	velocity.x = 0.0
	facing = _dir_to_target()
	_timer -= delta
	if _timer <= 0.0:
		_begin_stab()


func _begin_stab() -> void:
	_set_phase(Phase.STAB)
	_timer = STAB_TIME
	attack_hitbox.position = Vector2(facing * BLADE_CENTER, -4.0)
	attack_hitbox.parryable = false
	attack_hitbox.damage = 1
	attack_hitbox.active = true
	anim.trigger("stab", STAB_TIME)
	Sfx.play("thrust", -3.0, 0.9, 0.04)


func _ai_stab(delta: float) -> void:
	velocity.x = facing * lunge_speed * 0.6
	_timer -= delta
	if _timer <= 0.0:
		attack_hitbox.active = false
		set_tell(Tell.NONE)
		_attacks_done += 1
		_begin_retreat()


## Oyuncunun, bize göre karşı yanında boş bir nokta (x). Yoksa NAN.
func _find_stab_spot() -> float:
	var px := target.global_position.x
	var side := 1.0 if px > global_position.x else -1.0
	for s: float in [side, -side]:
		var x := px + s * STAB_OFFSET
		if _spot_free(Vector2(x, global_position.y)):
			return x
	return NAN


## Gövdemizin bu noktada duvara girmediği ve altında zemin olduğu doğrulanır.
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


func _restore_body() -> void:
	if not dead:
		collision_layer = Layers.ENEMY
		if hurtbox != null:
			hurtbox.set_deferred("monitorable", true)
	if _alpha_tween != null:
		_alpha_tween.kill()
		_alpha_tween = null
	visual_alpha = 1.0


# ---------------------------------------------------------------- olaylar

## Vurulunca hazırlanan/süren her hamle iptal olur; kısa süre sonra yeniden karar verir.
func _on_interrupted() -> void:
	if _phase == Phase.VANISH or _phase == Phase.STUNNED or _phase == Phase.SPACING:
		return
	attack_hitbox.active = false
	_bait = false
	_set_phase(Phase.SPACING)
	_decide_t = randf_range(0.8, 1.3)


func _on_stunned() -> void:
	attack_hitbox.active = false
	_bait = false
	_set_phase(Phase.STUNNED)


func _on_stun_end() -> void:
	_set_phase(Phase.SPACING)
	_decide_t = randf_range(0.6, 1.0)
	_hop_cooldown = 0.0


func _on_death() -> void:
	attack_hitbox.active = false
	_restore_body()


func pick_animation() -> String:
	if not dead and stun_t <= 0.0 and knock_t <= 0.0:
		match _phase:
			Phase.TELL:
				return "telegraph"
			Phase.LUNGE, Phase.FEINT_END:
				return "attack"
			Phase.BACKFLIP:
				return "backflip"
			Phase.RETREAT:
				return "retreat"
			Phase.VANISH:
				return "vanish"
			Phase.STAB_TELL:
				return "stab_telegraph"
			Phase.STAB:
				return "stab"
	return super.pick_animation()


# ---------------------------------------------------------------- çizim (yer tutucu)

func _process(delta: float) -> void:
	super._process(delta)
	if visual != null and not anim.has_art:
		# Geri takla: yer tutucu gövde havada bir tur döner (sprite gelince animasyon yapar).
		var rot := 0.0
		if _phase == Phase.BACKFLIP and not dead:
			rot = -TAU * clampf(_phase_t / _hop_duration, 0.0, 1.0)
		(visual as Node2D).rotation = rot
	if _phase in [Phase.TELL, Phase.LUNGE, Phase.STAB_TELL, Phase.STAB, Phase.FEINT_END, Phase.BACKFLIP, Phase.RETREAT, Phase.SPACING]:
		queue_redraw()


func _draw() -> void:
	super._draw()
	if dead or visual_alpha < 0.2:
		return
	var f := float(facing)
	# Dürtüş hattı: ince, parlak çizgi hızla uzar (hasar alanıyla aynı uzunlukta).
	if _phase == Phase.LUNGE or _phase == Phase.STAB:
		var total := lunge_time if _phase == Phase.LUNGE else STAB_TIME
		var k := clampf(_phase_t / (total * 0.45), 0.0, 1.0)
		var tip := BLADE_START + BLADE_LENGTH * k
		var col := Color(1.0, 0.95, 0.75) if _phase == Phase.LUNGE else Color(0.95, 0.5, 0.65)
		draw_line(Vector2(f * 12.0, -4.0), Vector2(f * tip, -4.0), Color(col, 0.35), 9.0)
		draw_line(Vector2(f * 12.0, -4.0), Vector2(f * tip, -4.0), col, 3.0)
		return
	if anim.has_art:
		return
	# Yer tutucu rapier'ler: dinlenirken aşağıda, hazırlanırken geriye çekik.
	var blade := Color(0.88, 0.92, 0.97)
	if _phase == Phase.TELL or _phase == Phase.STAB_TELL:
		draw_line(Vector2(f * -4.0, -6.0), Vector2(f * -34.0, -16.0), blade, 3.0)
	else:
		draw_line(Vector2(f * 12.0, 4.0), Vector2(f * 48.0, 14.0), blade, 3.0)
