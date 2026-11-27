class_name Player
extends ActorBase
## Oyuncu: koşma, zıplama, dash, parry ve iki silah slotu (J, I): yakın dövüş kombosu (kılıç/yumruk) ya da sapan (menzilli).
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
## Bağışıklık kalbi sayısı değişti.
signal immunity_changed(value: int)
## Bir durum (geçici stat değişikliği) başladı ya da bitti.
signal statuses_changed
## Altın miktarı değişti (toplam).
signal gold_changed(total: int)
## Oyuncu zıpladı (air: havada ikinci zıplama). Öğretici dinler.
signal jumped(air: bool)
## Bir saldırı başladı (combo_index: kombonun kaçıncı vuruşu, 0'dan). Öğretici dinler.
signal attack_started(combo_index: int)
## Menzilli silah (sapan) fırlatmaya başladı (slot: 0 = J, 1 = I; dir: nişan yönü). Öğretici dinler.
signal ranged_started(slot: int, dir: Vector2)

enum State { MOVE, DASH, ATTACK, PARRY, HURT, DEAD, THROW }

## Başarılı bir parry'den sonra bu süre (sn) içinde gelen altın saldırılar da parry'lenir (zincir).
## Aynı anda gelen iki saldırıyı yakalamayı mümkün kılar; Satürn'ün Kum Saati bunu kullanır.
const PARRY_CHAIN_TIME := 0.3

## Düşmanın başına konulunca kayma hızı (px/sn).
const SLIDE_OFF_SPEED := 220.0
## Duvar kayma hızı, sekme hızı (yatay, duvardan uzağa), sekmeden sonra yatay girdinin kilitli kaldığı süre (sn), duvara değme payı (sn).
const WALL_SLIDE_SPEED := 130.0
const WALL_JUMP_SPEED_X := 380.0
const WALL_LOCK_TIME := 0.18
const WALL_COYOTE := 0.1
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
	"reflex": 1.0,           # refleks: parry penceresini çarpar (1.0 normal; eşya/durumlar artırır ya da düşürür)
	"parry_recovery": 0.35,  # kaçırırsan toparlanma süresi
	"parry_zone_radius": 48.0,
	"parry_iframes": 0.25,   # başarılı parry sonrası dokunulmazlık
	"empower_time": 1.5,     # başarılı parry sonrası güçlü vuruş süresi
	"empower_mult": 2.0,
	# --- saldırı / hasar ---
	"attack_damage": 1.0,
	"hurt_iframes": 1.0,
	"damage_taken": 1.0,     # alınan hasar çarpanı (Antika Muhafız Kaskı 0.85)
	"knockback_mult": 1.0,   # vuruşlarının geri itme çarpanı (Yıldız Tozu Broşu)
	"auto_aim": 0.0,         # > 0: sapan taşları menzildeki en yakın düşmana kendiliğinden yönelir (Süperteknolojik Nişangâh)
	# --- kombo ---
	"combo_window": 1.0,     # her vuruş/parry bu kadar saniye daha kombo süresi verir
	# --- ritim (eşyalar bu çarpanları değiştirir) ---
	"rhythm_gain": 1.0,      # ritim kazanımı çarpanı
	"rhythm_decay": 1.0,     # ritim düşüş hızı çarpanı
}

## Sapan taşı sahnesi.
const STONE := preload("res://combat/sling_stone.tscn")
## Bekleyen (soğuma süren) menzilli silah tuşuna basılırsa, bu süre (sn) içinde soğuma bitince fırlatılır.
const SLOT_BUFFER_TIME := 0.2

# Kombo (vuruş süreleri, hasar, menzil) silah verisindedir: bkz. items/weapon_db.gd. Her vuruşta startup = hazırlık,
# active = vuruş açık, recovery = toparlanma (saniye).

# Animasyonlar (PNG'ler assets/sprites/sidera/ içine konunca otomatik kullanılır; bkz. docs/SPRITES.md).
# fps: saniyedeki kare, loop: döngü, fallback: dosya yoksa yedek animasyon.
const ANIM_SPEC := {
	"idle": {"fps": 8.0, "loop": true},
	"run": {"fps": 12.0, "loop": true, "fallback": "idle"},
	"jump": {"fps": 10.0, "loop": false, "fallback": "idle"},
	"wall_slide": {"fps": 8.0, "loop": true, "fallback": "fall"},
	"wall_jump": {"fps": 14.0, "loop": false, "fallback": "jump"},
	"fall": {"fps": 10.0, "loop": true, "fallback": "jump"},
	"dash": {"fps": 14.0, "loop": false, "fallback": "run"},
	"attack1": {"fps": 16.0, "loop": false, "fallback": "idle"},
	"attack2": {"fps": 16.0, "loop": false, "fallback": "attack1"},
	"attack3": {"fps": 16.0, "loop": false, "fallback": "attack2"},
	"punch1": {"fps": 18.0, "loop": false, "fallback": "attack1"},
	"punch2": {"fps": 18.0, "loop": false, "fallback": "punch1"},
	"punch3": {"fps": 18.0, "loop": false, "fallback": "punch2"},
	"punch4": {"fps": 16.0, "loop": false, "fallback": "punch3"},
	"throw": {"fps": 16.0, "loop": false, "fallback": "attack1"},
	"throw_up": {"fps": 16.0, "loop": false, "fallback": "throw"},
	"throw_diag": {"fps": 16.0, "loop": false, "fallback": "throw"},
	"parry": {"fps": 14.0, "loop": false, "fallback": "idle"},
	"parry_fail": {"fps": 10.0, "loop": false, "fallback": "idle"},
	"hurt": {"fps": 12.0, "loop": false, "fallback": "idle"},
	"death": {"fps": 10.0, "loop": false, "fallback": "hurt"},
}

var intent := Intent.new()
## true ise tuş okunmaz; intent'i dışarıdan (test/yapay zeka) doldurursun.
var scripted := false
## true ise tuşlar okunmaz ve yürüme durur (kat geçişinde kararırken). `scripted`tan farkı: dışarıdan intent verilmez.
var input_locked := false
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
## Bağışıklık kalbi (mavi kalkan): fazla yemekten gelir, hasarı önce o karşılar. Varken yemek yenmez.
var immunity := 0
## Ölümcül darbeyi engelleyebilen eşyalar (Çatlak El Aynası) buraya bir Callable ekler:
## `func() -> bool`; true dönerse oyuncu kurtuldu (canı o ayarlar), diğerlerine bakılmaz.
var death_savers: Array[Callable] = []
## Etkin durumlar: kimlik -> {"t": kalan sn, "total": toplam sn, "label": ekranda görünen ad}.
var statuses := {}
## Altın (mağazada harcanacak). Koşu bitince sıfırlanır.
var gold := 0
## Silahlar: iki slot (J, I), sahip olunanlar ve seviyeleri (WeaponLoadout).
var loadout: WeaponLoadout
## Otomatik nişanın kilitlendiği düşman (Süperteknolojik Nişangâh takılıysa; yoksa null). Üstünde hedef işareti çizilir.
var aim_target: Node2D = null

var _last_absorbed := 0

var _coyote := 0.0
var _jump_buffer := 0.0
var _air_jumps_left := 0
var _jump_cut_done := true
## Duvar sekmesi (Reçineli Eldivenler, `wall_jump` stat'ı): duvarın yönü (-1 sol, 1 sağ), duvara değme payı, kayıyor mu, sekme sonrası yatay kilit.
var _wall_dir := 0
var _wall_t := 0.0
var _wall_sliding := false
var _wall_lock := 0.0

var _dash_recharge_t := 0.0
var _dash_t := 0.0
var _dash_dir := 1

var _parry_chain_t := 0.0
var _parry_t := 0.0
var _parry_succeeded := false
var _parry_recovering := false

var _attack_t := 0.0
var _attack_cur := 0
var _attack_next := 0
## Saldırı/fırlatma sürerken tuşuna basılıp sıraya alınan slot (-1 = yok).
var _queued_slot := -1
## Kombonun silahı ve o silahın (seviyesine göre ölçeklenmiş) vuruş listesi.
var _combo_weapon := ""
var _combo_list: Array[Dictionary] = []
var _combo_window_t := 0.0
## Menzilli silahların kalan soğuma süresi ve ilk değeri (silah kimliğine göre: silahı slottan çıkarıp geri takmak soğumayı atlatmaz).
var _weapon_cd := {}
var _weapon_cd_max := {}
## Soğuması süren menzilli silaha basışın kısa süreli tamponu (slot başına).
var _slot_buffer: Array[float] = [0.0, 0.0]
var _throw_t := 0.0
var _throw_slot := 0
var _throw_dir := Vector2.RIGHT
var _throw_face := 1
var _throw_released := false
var _throw_shot := {}
var _melee_empowered := false
var _empower_t := 0.0

var _hurt_t := 0.0
var _blink_t := 0.0

@onready var melee: Hitbox = $MeleeHitbox
@onready var melee_shape: CollisionShape2D = $MeleeHitbox/Shape
@onready var parry_zone: Area2D = $ParryZone
@onready var parry_shape: CollisionShape2D = $ParryZone/Shape


func anim_folder() -> String:
	return "res://assets/sprites/sidera"


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
	loadout = WeaponLoadout.new()


# ---------------------------------------------------------------- giriş

func _gather_intent() -> void:
	intent.move_x = Input.get_axis("move_left", "move_right")
	intent.jump_held = Input.is_action_pressed("jump")
	intent.jump_pressed = Input.is_action_just_pressed("jump")
	intent.dash_pressed = Input.is_action_just_pressed("dash")
	intent.parry_pressed = Input.is_action_just_pressed("parry")
	intent.attack_pressed = Input.is_action_just_pressed("attack")
	intent.attack2_pressed = Input.is_action_just_pressed("attack2")
	intent.attack_held = Input.is_action_pressed("attack")
	intent.attack2_held = Input.is_action_pressed("attack2")
	intent.aim_y = Input.get_axis("aim_up", "aim_down")
	intent.interact_pressed = Input.is_action_just_pressed("interact")


# ---------------------------------------------------------------- ana döngü

func _physics_process(delta: float) -> void:
	if not scripted:
		if input_locked:
			intent.move_x = 0.0
			intent.jump_held = false
			intent.attack_held = false
			intent.attack2_held = false
			intent.aim_y = 0.0
		else:
			_gather_intent()
	_tick_timers(delta)
	_update_aim_target()
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
		State.THROW:
			_state_throw(delta)
	if _parry_chain_t > 0.0 and state != State.PARRY and not dead:
		_try_parry_zone()  # başarılı parry'nin hemen ardından gelen altın saldırılar da parry'lenir
	_sync_enemy_collision()
	var fall_speed := velocity.y
	var was_on_floor := is_on_floor()
	move_and_slide()
	if not was_on_floor and is_on_floor() and fall_speed > HARD_LANDING_SPEED:
		_on_landed(fall_speed)
	_post_move(delta)
	if intent.interact_pressed and not dead and not Interact.blocked():
		interacted.emit()
	intent.clear_edges()
	queue_redraw()


## Sert iniş: tok ses ve ayak dibinde küçük bir toz halkası.
func _on_landed(speed: float) -> void:
	var k := clampf((speed - HARD_LANDING_SPEED) / 700.0, 0.0, 1.0)
	Sfx.play("land", -11.0 + 7.0 * k, 1.0, 0.05)
	RingFx.spawn(get_parent(), Vector2(global_position.x, feet_y() - 2.0), Color(1.0, 1.0, 1.0, 0.22 + 0.2 * k), 5.0, 18.0 + 24.0 * k, 0.2)
	DustFx.puff(get_parent(), Vector2(global_position.x, feet_y() - 2.0), 0.0, 0.3 + 0.7 * k)
	landed.emit(speed)


## Hayalet Adım: dash sırasında düşman katmanı çarpışmadan çıkar, dash bitince geri gelir.
## (Dash düşmanın içinde biterse gövde geri geldiğinde fizik motoru oyuncuyu dışarı iter.)
func _sync_enemy_collision() -> void:
	if dash_ghost and state == State.DASH:
		collision_mask &= ~Layers.ENEMY
	else:
		collision_mask |= Layers.ENEMY


## Dash yapılabilir mi? (şarj var, serbest dash süresi sürüyor ya da deneme modu açık)
func can_dash() -> bool:
	return GameState.god_mode or dash_charges > 0 or free_dash_t > 0.0


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
			return "%s%d" % [WeaponDB.anim_prefix(_combo_weapon), _attack_cur + 1]
		State.THROW:
			return throw_animation()
		State.PARRY:
			return "parry_fail" if _parry_recovering else "parry"
		State.HURT:
			return "hurt"
		State.DEAD:
			return "death"
	if _wall_sliding:
		return "wall_slide"
	if _wall_lock > WALL_LOCK_TIME * 0.5 and not is_on_floor():
		return "wall_jump"
	if not is_on_floor():
		return "jump" if velocity.y < 0.0 else "fall"
	if absf(velocity.x) > 30.0 and absf(intent.move_x) > 0.05:
		return "run"
	return "idle"


func _tick_timers(delta: float) -> void:
	invulnerable_t = maxf(invulnerable_t - delta, 0.0)
	free_dash_t = maxf(free_dash_t - delta, 0.0)
	_tick_statuses(delta)
	_parry_chain_t = maxf(_parry_chain_t - delta, 0.0)
	_empower_t = maxf(_empower_t - delta, 0.0)
	_combo_window_t = maxf(_combo_window_t - delta, 0.0)
	for id in _weapon_cd.keys():
		var left := maxf(float(_weapon_cd[id]) - delta, 0.0)
		if left > 0.0:
			_weapon_cd[id] = left
		else:
			_weapon_cd.erase(id)
	for i in _slot_buffer.size():
		_slot_buffer[i] = maxf(_slot_buffer[i] - delta, 0.0)
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	_wall_lock = maxf(_wall_lock - delta, 0.0)
	_wall_t = maxf(_wall_t - delta, 0.0)
	_wall_sliding = false
	if intent.jump_pressed:
		_jump_buffer = stats.value("jump_buffer")
	if is_on_floor():
		_coyote = stats.value("coyote_time")
		_air_jumps_left = stats.int_value("air_jumps")
	else:
		_coyote = maxf(_coyote - delta, 0.0)
	var max_charges := stats.int_value("dash_charges")
	if GameState.god_mode and dash_charges < max_charges:
		dash_charges = max_charges
		dash_charges_changed.emit(dash_charges, max_charges)
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
	if _wall_lock > 0.0:
		return  # duvardan sekerken kısa süre girdi yok: karşı yöne gerçekten sıçrasın
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
			jumped.emit(false)
		elif _air_jumps_left > 0:
			_air_jumps_left -= 1
			_do_jump()
			jumped.emit(true)
	if not intent.jump_held and velocity.y < 0.0 and not _jump_cut_done:
		velocity.y *= stats.value("jump_cut")
		_jump_cut_done = true


## Reçineli Eldivenler (`wall_jump` > 0): havada duvara yaslanıp düşersen yavaş kayarsın; zıplarsan duvardan karşı yöne sekersin.
## Duvar eldivensiz hiçbir şey yapmaz.
func _handle_wall() -> void:
	if stats.value("wall_jump") <= 0.0 or is_on_floor():
		_wall_t = 0.0
		return
	if is_on_wall():
		var n := get_wall_normal()
		if absf(n.x) > 0.5:
			_wall_dir = -1 if n.x > 0.0 else 1  # duvar normali bize doğru; duvar ters yönde
			_wall_t = WALL_COYOTE
			if velocity.y > 0.0 and intent.move_x * float(_wall_dir) > 0.05:
				velocity.y = minf(velocity.y, WALL_SLIDE_SPEED)
				_wall_sliding = true
				facing = _wall_dir
	if _jump_buffer > 0.0 and _wall_t > 0.0 and _wall_dir != 0:
		velocity = Vector2(-float(_wall_dir) * WALL_JUMP_SPEED_X, -stats.value("jump_velocity") * 0.95)
		facing = -_wall_dir
		_wall_lock = WALL_LOCK_TIME
		_wall_t = 0.0
		_wall_sliding = false
		_air_jumps_left = stats.int_value("air_jumps")
		_jump_buffer = 0.0
		_coyote = 0.0
		_jump_cut_done = false
		jumped.emit(true)


func _do_jump() -> void:
	velocity.y = -stats.value("jump_velocity")
	_jump_buffer = 0.0
	_coyote = 0.0
	_jump_cut_done = false
	if is_on_floor():
		DustFx.puff(get_parent(), Vector2(global_position.x, feet_y() - 2.0), 0.0, 0.2)


func _state_move(delta: float) -> void:
	_apply_horizontal(delta, 1.0)
	_apply_gravity(delta)
	_handle_wall()
	_handle_jump()
	_handle_actions()


func _handle_actions() -> void:
	if intent.dash_pressed and can_dash():
		_start_dash()
	elif intent.parry_pressed:
		_start_parry()
	else:
		var slot := _wanted_slot(true)
		if slot >= 0:
			_use_slot(slot)


# ---------------------------------------------------------------- dash

func _start_dash() -> void:
	if free_dash_t <= 0.0 and not GameState.god_mode:
		dash_charges = maxi(dash_charges - 1, 0)
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
	if is_on_floor():
		DustFx.puff(get_parent(), Vector2(global_position.x, feet_y() - 2.0), -float(_dash_dir), 0.6)


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
	EventBus.parry_started.emit(self)
	_refresh_parry_zone()
	state = State.PARRY
	_parry_t = 0.0
	_parry_succeeded = false
	_parry_recovering = false
	melee.active = false
	anim.trigger("parry", parry_window_time())
	_try_parry_zone()  # tuşa bastığın karede zaten içerideki mermiler


## Parry penceresinin gerçek süresi (sn): `parry_window` (sn, eşyalar ekler) x `reflex` (çarpan).
## Refleks 1.0 normaldir; 1.25 = pencere %25 uzun, 0.8 = %20 kısa. Çok düşük refleks bile pencereyi sıfırlamaz.
func parry_window_time() -> float:
	return stats.value("parry_window") * maxf(stats.value("reflex", 1.0), 0.25)


## Parry'yi kaçırınca toparlanma süresi. Deneme modunda neredeyse yok (parry'yi bedavaya spamleyebilirsin).
func parry_recovery_time() -> float:
	return 0.04 if GameState.god_mode else stats.value("parry_recovery")


func _parry_window_open() -> bool:
	return state == State.PARRY and not _parry_recovering and _parry_t <= parry_window_time()


func _state_parry(delta: float) -> void:
	_parry_t += delta
	_apply_gravity(delta)
	if not _parry_recovering:
		_apply_horizontal(delta, 0.6)
		if _parry_t <= parry_window_time():
			_try_parry_zone()
		else:
			_parry_recovering = true
			anim.trigger("parry_fail", parry_recovery_time())
			EventBus.parry_failed.emit(self)
	else:
		_apply_horizontal(delta, 0.4)
		if _parry_t >= parry_window_time() + parry_recovery_time():
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
	_parry_chain_t = PARRY_CHAIN_TIME
	if _parry_succeeded:
		# Aynı parry'nin (ya da hemen ardından gelen) fazladan saldırısı: tam gösteri yok ama parry SAYILIR
		# (kombo, ritim ve eşyalar görür; Satürn'ün Kum Saati bunu "aynı anda iki parry" sayar).
		EventBus.parry_success.emit(self, hb)
		RingFx.spawn(get_parent(), hb.global_position, Color(1.0, 0.95, 0.7, 0.9), 8.0, 38.0, 0.18)
		HitSpark.spawn(get_parent(), hb.global_position, Vector2(-facing, -0.2), Color(1.0, 0.85, 0.3), 1.1)
		Sfx.play_parry(combo.parries)
		return
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
	if hitbox.parryable and (_parry_window_open() or _parry_chain_t > 0.0):
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


# ---------------------------------------------------------------- silahlar (slotlar)

## `slot`taki silahın kimliği ("sword", "fist", "sling"; boşsa "").
func weapon_in(slot: int) -> String:
	return loadout.weapon_in(slot) if loadout != null else ""


## Slot tuşuna şu an basılabilir mi? (Menzilli silahta soğuma bitmiş olmalı; yakın silahta hep evet.)
func _slot_usable(slot: int) -> bool:
	var id := weapon_in(slot)
	if id == "":
		return false
	if WeaponDB.is_ranged(id):
		return float(_weapon_cd.get(id, 0.0)) <= 0.0
	return true


## Slottaki silahın soğuma durumu: 0 = hazır, 1 = az önce atıldı (HUD'da dolan halka/çubuk için). Yakın silahlar hep hazırdır.
func weapon_cooldown_k(slot: int) -> float:
	var id := weapon_in(slot)
	var left := float(_weapon_cd.get(id, 0.0))
	if left <= 0.0:
		return 0.0
	return clampf(left / maxf(float(_weapon_cd_max.get(id, left)), 0.001), 0.0, 1.0)


## Bu karede hangi slotun kullanılmak istendiği (-1 = hiçbiri): önce yeni basışlar (J, sonra I), sonra soğuma bekleyen
## tamponlanmış basışlar, en son (`include_held`) basılı tutulan menzilli silahlar. Soğuması süren menzilli silaha basış kısa
## süre tamponlanır, soğuma bitince kendiliğinden fırlatılır.
func _wanted_slot(include_held: bool) -> int:
	for slot in WeaponDB.SLOT_COUNT:
		var pressed := intent.attack_pressed if slot == 0 else intent.attack2_pressed
		if not pressed:
			continue
		if _slot_usable(slot):
			return slot
		if weapon_in(slot) != "":
			_slot_buffer[slot] = SLOT_BUFFER_TIME
	for slot in WeaponDB.SLOT_COUNT:
		if _slot_buffer[slot] > 0.0 and _slot_usable(slot):
			_slot_buffer[slot] = 0.0
			return slot
	if include_held:
		for slot in WeaponDB.SLOT_COUNT:
			var held := intent.attack_held if slot == 0 else intent.attack2_held
			if held and WeaponDB.is_ranged(weapon_in(slot)) and _slot_usable(slot):
				return slot
	return -1


## Slottaki silahı kullanır: yakın silah kombo vuruşu, menzilli silah fırlatma.
func _use_slot(slot: int) -> void:
	var id := weapon_in(slot)
	if id == "":
		return
	if WeaponDB.is_ranged(id):
		_start_throw(slot)
	else:
		_start_attack(slot)


## Slotlardan birinde menzilli silah (sapan) var mı?
func has_ranged_weapon() -> bool:
	for slot in WeaponDB.SLOT_COUNT:
		if WeaponDB.is_ranged(weapon_in(slot)):
			return true
	return false


# ---------------------------------------------------------------- yakın dövüş

func _start_attack(slot: int = 0) -> void:
	var id := weapon_in(slot)
	if not WeaponDB.is_melee(id):
		return
	var list := WeaponDB.combo(id, loadout.level_of(id))
	if list.is_empty():
		return
	if id != _combo_weapon or list.size() != _combo_list.size():
		_combo_window_t = 0.0  # silah değişti: kombo baştan başlar
	_combo_weapon = id
	_combo_list = list
	_attack_cur = _attack_next if _combo_window_t > 0.0 else 0
	if _attack_cur >= _combo_list.size():
		_attack_cur = 0
	_attack_next = (_attack_cur + 1) % _combo_list.size()
	var a: Dictionary = _combo_list[_attack_cur]
	state = State.ATTACK
	_attack_t = 0.0
	_queued_slot = -1
	_combo_window_t = float(a["startup"]) + float(a["active"]) + float(a["recovery"]) + 0.25
	(melee_shape.shape as RectangleShape2D).size = a["size"]
	melee.position = Vector2(facing * float(a["reach"]), 0.0)
	_melee_empowered = _empower_t > 0.0
	var mult := stats.value("empower_mult") if _melee_empowered else 1.0
	melee.damage = maxi(roundi(stats.value("attack_damage") * float(a["dmg"]) * mult), 1)
	melee.knock_mult = float(a["knock"])
	melee.active = false
	anim.trigger("%s%d" % [WeaponDB.anim_prefix(id), _attack_cur + 1], float(a["startup"]) + float(a["active"]) + float(a["recovery"]))
	var pitch := 1.0 + 0.08 * _attack_cur if id == WeaponDB.SWORD else 1.3 + 0.05 * _attack_cur
	Sfx.play("slash", -4.0 if id == WeaponDB.SWORD else -7.0, pitch, 0.04)
	attack_started.emit(_attack_cur)


func _state_attack(delta: float) -> void:
	if _attack_cur >= _combo_list.size():
		melee.active = false
		state = State.MOVE
		return
	var a: Dictionary = _combo_list[_attack_cur]
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
	var wanted := _wanted_slot(false)
	if wanted >= 0:
		if WeaponDB.is_ranged(weapon_in(wanted)) and _attack_t >= active_end:
			melee.active = false
			_start_throw(wanted)  # vuruş bittikten sonra menzilli silaha geçiş (iptal)
			return
		_queued_slot = wanted
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
		var queued := _queued_slot
		_queued_slot = -1
		if queued >= 0 and _slot_usable(queued):
			_use_slot(queued)
		else:
			state = State.MOVE


func _on_melee_landed(_target: Hurtbox) -> void:
	if _melee_empowered:
		_empower_t = 0.0
		_melee_empowered = false
	var weight := float(_attack_cur)
	if _attack_cur < _combo_list.size():
		weight = float(_combo_list[_attack_cur].get("weight", weight))
	Hitstop.freeze(0.04 + 0.02 * weight)
	EventBus.screen_shake.emit(3.0 + 2.0 * weight, 0.14)
	EventBus.camera_kick.emit(Vector2(facing, 0.0), 3.5 + 2.5 * weight)


# ---------------------------------------------------------------- menzilli (sapan)

## Fırlatma animasyonunun adı: yukarı, çapraz ya da düz.
func throw_animation() -> String:
	if _throw_dir.y < -0.9:
		return "throw_up"
	if absf(_throw_dir.y) > 0.3:
		return "throw_diag"
	return "throw"


## Taşın gideceği yön: nişangâh takılı ve hedef varsa (ve yukarı/aşağı tuşuna basılmıyorsa) hedefe doğru (hareketi de hesaba katarak),
## yoksa elle nişan (8 yön).
func aim_direction() -> Vector2:
	if aim_target != null and is_instance_valid(aim_target) and absf(intent.aim_y) < 0.5:
		var body := aim_target as CharacterBody2D
		var vel := body.velocity if body != null else Vector2.ZERO
		return Aiming.lead(global_position + Vector2(0.0, -6.0), aim_target.global_position, vel, WeaponDB.SLING_SPEED)
	return Aiming.manual(intent.move_x, intent.aim_y, facing, is_on_floor())


## Nişangâh için hedefi tazeler (her fizik karesi): yalnız `auto_aim` > 0 ve elde menzilli silah varsa çalışır.
func _update_aim_target() -> void:
	aim_target = null
	if dead or loadout == null or stats.value("auto_aim") <= 0.0 or not has_ranged_weapon():
		return
	aim_target = Aiming.pick_target(global_position, facing, get_tree().get_nodes_in_group("enemies"), Aiming.AUTO_RANGE, _can_see)


## Arada duvar yoksa true (taş duvara çarpacaksa nişangâh o düşmanı seçmez).
func _can_see(n: Node2D) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position + Vector2(0.0, -6.0), n.global_position, Layers.WORLD)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _start_throw(slot: int) -> void:
	var id := weapon_in(slot)
	if not WeaponDB.is_ranged(id) or float(_weapon_cd.get(id, 0.0)) > 0.0:
		return
	_throw_shot = WeaponDB.shot(id, loadout.level_of(id))
	_throw_slot = slot
	_throw_t = 0.0
	_throw_released = false
	_throw_dir = aim_direction()
	if absf(_throw_dir.x) > 0.1:
		facing = 1 if _throw_dir.x > 0.0 else -1
	_throw_face = facing
	_weapon_cd[id] = float(_throw_shot["cooldown"])
	_weapon_cd_max[id] = float(_throw_shot["cooldown"])
	_slot_buffer[slot] = 0.0
	_queued_slot = -1
	state = State.THROW
	melee.active = false
	anim.trigger(throw_animation(), float(_throw_shot["windup"]) + float(_throw_shot["recovery"]))
	Sfx.play("slash", -10.0, 1.7, 0.05)
	ranged_started.emit(slot, _throw_dir)


func _state_throw(delta: float) -> void:
	_throw_t += delta
	_apply_horizontal(delta, 0.55)
	facing = _throw_face
	_apply_gravity(delta)
	_handle_jump()
	if not _throw_released and _throw_t >= float(_throw_shot["windup"]):
		_release_stones()
	if _throw_released:
		# iptal: dash ve parry taş çıktıktan sonra her an; öbür silah slotu da (yakın silah vuruşu)
		if intent.dash_pressed and can_dash():
			_start_dash()
			return
		if intent.parry_pressed:
			_start_parry()
			return
		var wanted := _wanted_slot(false)
		if wanted >= 0 and wanted != _throw_slot:
			_use_slot(wanted)
			return
	if _throw_t >= float(_throw_shot["windup"]) + float(_throw_shot["recovery"]):
		state = State.MOVE


## Taşları (seviyeye göre 1-2 tane) fırlatır. Parry sonrası "güçlü vuruş" hakkı ilk atışa geçer (tüketilir).
func _release_stones() -> void:
	_throw_released = true
	var parent := get_parent()
	if parent == null:
		return
	var shot := _throw_shot
	var empowered := _empower_t > 0.0
	var mult := 1.0
	if empowered:
		mult = stats.value("empower_mult")
		_empower_t = 0.0
	var dmg := maxi(roundi(stats.value("attack_damage") * float(shot["damage"]) * mult), 1)
	var n: int = shot["count"]
	var origin := global_position + Vector2(_throw_dir.x * 20.0, -6.0 + _throw_dir.y * 18.0)
	for i in n:
		var d := _throw_dir.rotated((float(i) - float(n - 1) * 0.5) * float(shot["spread"]))
		var stone := STONE.instantiate() as SlingStone
		parent.add_child(stone)
		stone.global_position = origin
		stone.empowered = empowered
		stone.fire(d * float(shot["speed"]), dmg, self, int(shot["pierce"]), float(shot["lifetime"]))
		stone.landed.connect(_on_stone_landed)
	Sfx.play("shoot", -9.0, 1.5, 0.05)
	RingFx.spawn(parent, origin, Color(1, 1, 1, 0.35), 3.0, 14.0, 0.12)


func _on_stone_landed(_target: Hurtbox) -> void:
	Hitstop.freeze(0.025)
	EventBus.screen_shake.emit(1.6, 0.09)


# ---------------------------------------------------------------- hasar / ölüm

## Gelen hasardan canı gerçekten götürecek kısım: önce hasar azaltma (`damage_taken`), sonra bağışıklık kalbi
## karşılar, kalan can götürür. Deneme modunda hiçbir şey gitmez (vuruş tepkisi, flaş ve ritim kaybı yine olur).
func _damage_after_defenses(amount: int, _source: Node) -> int:
	_last_absorbed = 0
	var dmg := _scale_damage(amount)
	if immunity > 0 and dmg > 0:
		_last_absorbed = mini(immunity, dmg)
		dmg -= _last_absorbed
		set_immunity(immunity - _last_absorbed)
		Sfx.play("shield_break", -2.0, 1.0, 0.05)
	if GameState.god_mode:
		return 0
	return dmg


## Can sıfıra indi: önce ölümü engelleyen eşyalara (Çatlak El Aynası) sorulur.
func _on_health_depleted() -> void:
	for saver in death_savers.duplicate():
		if saver.is_valid() and saver.call():
			return
	die()


## Bağışıklık kalbi sayısını ayarlar.
func set_immunity(value: int) -> void:
	value = maxi(value, 0)
	if value == immunity:
		return
	immunity = value
	immunity_changed.emit(immunity)


## `seconds` sn boyunca hasar almaz (daha uzun bir dokunulmazlık varsa onu kısaltmaz); yanıp söner.
func grant_invulnerability(seconds: float) -> void:
	invulnerable_t = maxf(invulnerable_t, seconds)
	_blink_t = maxf(_blink_t, seconds)


# ---------------------------------------------------------------- altın

func add_gold(amount: int) -> void:
	if amount == 0:
		return
	gold = maxi(gold + amount, 0)
	gold_changed.emit(gold)
	if amount > 0:
		EventBus.gold_collected.emit(self, amount)


## Altın yeterliyse harcar ve true döner (mağaza için).
func spend_gold(amount: int) -> bool:
	if amount < 0 or gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


# ---------------------------------------------------------------- yemek

## true olsa can doluyken de yemek yenir (tamamı bağışıklığa dönüşür). Tasarım: can tamken yenmez.
const ALLOW_EAT_AT_FULL := false


## Yemeği yemeyi dener. Yenirse "" döner, yenmezse nedenini (ekrana yazılacak kısa metin).
##  - Canda boşluk varsa önce can dolar; yemeğin kalan kısmı bağışıklık kalbine dönüşür.
##  - Bağışıklık kalbi varken HİÇBİR yemek yenmez (sınırsız bağışıklık biriktirilemesin).
func try_eat(item: ItemData) -> String:
	if dead:
		return "ÖLÜSÜN"
	if item == null or not item.is_food():
		return "BU YENMEZ"
	if immunity > 0:
		return "BAĞIŞIKLIK KALBİ VARKEN YEMEK YENMEZ"
	var max_hp := stats.int_value("max_health")
	var missing := max_hp - health
	if missing <= 0 and not ALLOW_EAT_AT_FULL:
		return "CANIN ZATEN DOLU"
	var amount := item.heal_amount(max_hp)
	var healed := heal(mini(amount, maxi(missing, 0)))
	var overflow := maxi(amount - healed, 0)
	if overflow > 0:
		set_immunity(overflow)
	Sfx.play("eat", -2.0, 1.0, 0.04)
	EventBus.food_eaten.emit(self, item, healed, overflow)
	return ""


# ---------------------------------------------------------------- durumlar (geçici stat değişiklikleri)

## Geçici bir durum başlatır: `mods` = [[stat, ekleme, çarpım], ...]. Aynı kimlikle tekrar çağrılırsa süre yenilenir
## (etki üst üste binmez). Örn. yorgunluk: apply_status("yorgun", 6.0, [["reflex", 0.0, 0.8]], "YORGUN")
func apply_status(status_id: String, duration: float, mods: Array, label: String = "") -> void:
	if dead or duration <= 0.0:
		return
	var source := "durum:" + status_id
	if not statuses.has(status_id):
		for m: Array in mods:
			stats.add_modifier(source, m[0], m[1], m[2])
	statuses[status_id] = {"t": duration, "total": duration, "label": label if label != "" else status_id.to_upper()}
	statuses_changed.emit()


func remove_status(status_id: String) -> void:
	if not statuses.has(status_id):
		return
	stats.remove_modifiers("durum:" + status_id)
	statuses.erase(status_id)
	statuses_changed.emit()


func has_status(status_id: String) -> bool:
	return statuses.has(status_id)


## HUD için: "YORGUN 4.2" gibi satırlar.
func status_lines() -> Array[String]:
	var out: Array[String] = []
	for k in statuses:
		var st: Dictionary = statuses[k]
		out.append("%s %.1f" % [st["label"], float(st["t"])])
	return out


func _tick_statuses(delta: float) -> void:
	if statuses.is_empty():
		return
	var ended: Array[String] = []
	for k in statuses:
		var st: Dictionary = statuses[k]
		st["t"] = float(st["t"]) - delta
		if float(st["t"]) <= 0.0:
			ended.append(k)
	for k in ended:
		remove_status(k)


func _enter_hurt(hitbox: Hitbox) -> void:
	if dead:
		return
	var dir := 1 if global_position.x >= hitbox.global_position.x else -1
	velocity = Vector2(dir * 260.0 * ActorBase.knockback_mult_of(hitbox.source), -220.0)
	state = State.HURT
	_hurt_t = 0.0
	melee.active = false
	grant_invulnerability(stats.value("hurt_iframes"))
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


## Hasar flaşı: oyuncuda beyaz yerine kırmızımsı, biraz daha uzun. Bağışıklık kalbi karşıladıysa mavi.
func _hit_flash() -> void:
	if _last_absorbed > 0:
		flash(Color(0.55, 0.8, 1.0), 0.26)
	else:
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
	if TimeStop.active:
		# Kalan süreyi gösteren ince halka.
		draw_arc(Vector2.ZERO, 40.0, 0.0, TAU, 40, Color(0.7, 0.88, 1.0, 0.18), 2.0)
		draw_arc(Vector2.ZERO, 40.0, -PI * 0.5, -PI * 0.5 + TAU * TimeStop.progress(), 40, Color(0.75, 0.92, 1.0, 0.95), 3.0)
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
	_draw_aim()


## Sapan nişanı: otomatik hedef varsa üstünde hedef işareti; yukarı/aşağı tuşuna basılıyorsa elle nişan yönünde küçük ok.
func _draw_aim() -> void:
	if loadout == null or dead or not has_ranged_weapon():
		return
	var manual := absf(intent.aim_y) > 0.5
	if aim_target != null and is_instance_valid(aim_target) and not manual:
		var pos := to_local(aim_target.global_position)
		var t := Time.get_ticks_msec() / 1000.0
		var c := Color(0.45, 1.0, 0.9, 0.9)
		var r := 26.0 + 2.0 * sin(t * 7.0)
		draw_arc(pos, r, 0.0, TAU, 32, c, 2.0)
		for i in 4:
			var d := Vector2.from_angle(float(i) * PI * 0.5 + t * 0.8)
			draw_line(pos + d * (r - 7.0), pos + d * (r + 7.0), c, 2.0)
		draw_circle(pos, 2.5, c)
	elif manual:
		var dir := Aiming.manual(intent.move_x, intent.aim_y, facing, is_on_floor())
		var col := Color(0.72, 0.86, 0.45, 0.85)
		draw_line(dir * 40.0, dir * 62.0, Color(col, 0.5), 2.0)
		draw_circle(dir * 54.0, 4.0, col)