class_name ShakeCamera
extends Camera2D
## Dinamik oyun kamerası.
##
## TAKİP
##  - Oyuncuyu yumuşakça izler. Baktığı yöne doğru "öne bakar" (look-ahead), hızına göre hafifçe öne kayar.
##  - Yakındaki düşmana doğru azıcık kayar (aksiyon odağı), oyuncu her zaman ekranda kalır.
##  - Dikey takip "çok az" oynar: yerdeyken zemine yerleşir (oyuncu ekranın alt-orta kısmında durur),
##    zıplarken yükselişin küçük bir kısmı kadar yukarı, düşerken hızına göre biraz aşağı kayar, sert inişte hafifçe çöker.
## ZOOM
##  - Hafif yakınlaşma (base_zoom). Kombo uzadıkça biraz daha yaklaşır, dash'te hafifçe açılır.
## SINIRLAR
##  - `bounds` (oda dikdörtgeni) dışı hiç görünmez. Odalar arası geçişte sınırlar değişir, kamera kendiliğinden kayar.
## EFEKTLER
##  - screen_shake: "trauma" modeli, yumuşak gürültü, sona doğru yavaşça söner.
##  - camera_kick: vuruşun yönüne iter, yay gibi geri döner.
##  - camera_punch: kısa yakınlaşma (parry).
## Zaman gerçek saatten akar, böylece hitstop (dondurma) anında da kamera ve sarsıntı akıcı kalır.

# --- sarsıntı / efekt ayarları
@export var max_offset := 26.0
@export var noise_speed := 22.0
@export var spring_stiffness := 120.0
@export var spring_damping := 16.0
@export var max_kick := 22.0

# --- takip ayarları
## Hafif yakınlaşma. 1.0 = yakınlaşma yok.
@export var base_zoom := 1.15
## Yumuşak takip hızı (1/sn). Büyük = daha sıkı takip.
@export var follow_speed := Vector2(7.0, 5.0)
## Baktığı yöne ne kadar önden bakılır (piksel).
@export var look_ahead := 90.0
## Öne bakışın yön değiştirme hızı (tam salınımın saniyede kaç katı).
@export var look_ahead_swing := 3.0
## Koşarken hız başına öne kayma (piksel / (piksel/sn)).
@export var velocity_lead := 0.08
## Oyuncu ekranın alt-orta kısmında dursun diye kamerayı yukarı iter (negatif = yukarı).
@export var vertical_bias := -90.0
## Havadayken kamera, oyuncunun zemine göre yükselişinin bu oranı kadar kayar (0.25 = dörtte biri; çok az).
@export var vertical_gain := 0.25
## Bu havadaki kayma en fazla bu kadar piksel olabilir.
@export var vertical_range := 48.0
## Zemine inince zemin referansının yerleşme hızı (1/sn).
@export var ground_follow := 3.5
## Düşerken aşağıya, çıkarken yukarıya bakma: hız başına kayma ve üst sınırlar (piksel).
@export var fall_look := 0.05
@export var fall_look_max := 55.0
@export var rise_look := 0.02
@export var rise_look_max := 12.0
## Bu hızdan (px/sn) sert inişte kamera hafifçe çöker (itme gücü piksel/24).
@export var landing_min_speed := 520.0
@export var landing_kick_min := 2.0
@export var landing_kick_max := 5.0
## Yakındaki düşmana doğru kayma: ağırlık, erişim ve üst sınır (piksel).
@export var focus_weight := 0.22
@export var focus_range := 520.0
@export var focus_max := 110.0
## Oyuncunun ekran kenarına en fazla bu kadar yaklaşmasına izin verilir.
@export var screen_margin := Vector2(150.0, 120.0)
## Oda sınırları değişince kamera sınırlarının yeni odaya kayma hızı (1/sn).
@export var bounds_speed := 6.0
## Kameranın en yüksek hızı (piksel/sn). Odalar arası geçişte kamera "fırlamasın" diye.
@export var max_speed := 1100.0

## Kameranın görebileceği dünya dikdörtgeni (oda). Boyutu sıfırsa sınırsız.
var bounds := Rect2(0.0, 0.0, 1280.0, 720.0)
## Takip edilen düğüm. Boşsa "player" grubundaki ilk düğüm bulunur.
var target: Node2D = null

var trauma := 0.0

var _decay := 1.0
var _time := 0.0
var _kick := Vector2.ZERO
var _kick_vel := Vector2.ZERO
var _punch := 0.0
var _punch_vel := 0.0
var _last_usec := 0
var _noise := FastNoiseLite.new()

var _pos := Vector2.ZERO
var _look_x := 0.0
var _lead := Vector2.ZERO
var _focus := Vector2.ZERO
var _ref_y := 0.0
var _air_dy := 0.0
var _was_grounded := true
var _fall_vy := 0.0
var _zoom_mod := 0.0
var _initialized := false
## Etkin sınırlar: `bounds`'a yumuşakça kayar, böylece oda değişince kamera sıçramaz.
var _beff := Rect2(0.0, 0.0, 1280.0, 720.0)


func _ready() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_noise.seed = randi()
	EventBus.screen_shake.connect(_on_shake)
	EventBus.camera_kick.connect(_on_kick)
	EventBus.camera_punch.connect(_on_punch)
	_pos = global_position
	_beff = bounds
	zoom = Vector2.ONE * base_zoom
	_find_target()
	if target != null:
		snap()


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


# ---------------------------------------------------------------- dış API

## Kameranın görebileceği alanı değiştirir (oda geçişi). `snap_now`: kamera hemen oraya yerleşsin.
func set_bounds(rect: Rect2, snap_now: bool = false) -> void:
	bounds = rect
	if snap_now:
		snap()


## Mevcut sınırları verilen dikdörtgeni de içine alacak şekilde genişletir (kapıdan geçiş sırasında).
func extend_bounds(rect: Rect2) -> void:
	bounds = bounds.merge(rect)


## Kamerayı beklemeden hedefine yerleştirir (oda başlangıcı, sahne açılışı).
func snap() -> void:
	_find_target()
	if target == null:
		return
	_beff = bounds
	_look_x = _facing() * look_ahead
	_lead = Vector2.ZERO
	_focus = Vector2.ZERO
	_ref_y = target.global_position.y
	_air_dy = 0.0
	_was_grounded = true
	_fall_vy = 0.0
	_zoom_mod = _zoom_goal() - base_zoom
	_pos = _clamp_to_bounds(_desired(), _total_zoom())
	_initialized = true
	_apply()


## Kameranın şu an gördüğü dünya dikdörtgeni (sarsıntı hariç).
func view_rect() -> Rect2:
	var z := _total_zoom()
	var size := _view_size() / z
	return Rect2(_pos - size * 0.5, size)


## Efektler hariç kamera merkezi.
func center() -> Vector2:
	return _pos


# ---------------------------------------------------------------- ana adım

## Bir zaman adımı ilerletir (testler doğrudan çağırabilir).
func step(dt: float) -> void:
	_time += dt
	_slide_bounds(dt)
	_find_target()
	if target != null:
		if not _initialized:
			snap()
		else:
			_follow(dt)
	_update_effects(dt)
	_apply()


func _find_target() -> void:
	if target != null and is_instance_valid(target):
		return
	target = null
	if is_inside_tree():
		target = get_tree().get_first_node_in_group("player") as Node2D


func _facing() -> float:
	if target != null and "facing" in target:
		return float(target.get("facing"))
	return 1.0


func _view_size() -> Vector2:
	return get_viewport_rect().size if is_inside_tree() else Vector2(1280.0, 720.0)


## Kombo uzadıkça biraz yaklaşır, dash'te açılır. base_zoom'un üstüne eklenen miktarla birlikte hedef zoom.
func _zoom_goal() -> float:
	var goal := base_zoom
	if target is Player:
		var p := target as Player
		if p.combo != null:
			goal += 0.012 * float(mini(p.combo.events(), 5))
		if p.state == Player.State.DASH:
			goal -= 0.05
	return goal


func _total_zoom() -> float:
	return (base_zoom + _zoom_mod) * (1.0 + clampf(_punch, -0.1, 0.12))


## Hedef kamera merkezi (sınırlar uygulanmadan).
func _desired() -> Vector2:
	var pos := target.global_position
	return Vector2(pos.x + _look_x + _lead.x + _focus.x, _ref_y + vertical_bias + _air_dy + _lead.y + _focus.y)


## Etkin sınırlar hedef sınırlara yumuşakça kayar (oda geçişinde kamera sıçramasın).
func _slide_bounds(dt: float) -> void:
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0 or _beff.size.x <= 0.0 or _beff.size.y <= 0.0:
		_beff = bounds
		return
	var k := 1.0 - exp(-bounds_speed * dt)
	var pos := _beff.position.lerp(bounds.position, k)
	var size := _beff.size.lerp(bounds.size, k)
	if pos.distance_to(bounds.position) < 0.25 and size.distance_to(bounds.size) < 0.25:
		_beff = bounds
	else:
		_beff = Rect2(pos, size)


func _clamp_to_bounds(p: Vector2, zoom_value: float) -> Vector2:
	if _beff.size.x <= 0.0 or _beff.size.y <= 0.0:
		return p
	var half := _view_size() / zoom_value * 0.5
	var lo := _beff.position + half
	var hi := _beff.end - half
	var out := p
	out.x = _beff.get_center().x if lo.x > hi.x else clampf(p.x, lo.x, hi.x)
	out.y = _beff.get_center().y if lo.y > hi.y else clampf(p.y, lo.y, hi.y)
	return out


func _follow(dt: float) -> void:
	var pos := target.global_position
	var vel := Vector2.ZERO
	var grounded := true
	if target is CharacterBody2D:
		vel = (target as CharacterBody2D).velocity
		grounded = (target as CharacterBody2D).is_on_floor()
	# Öne bakış: yön değiştirince yumuşakça diğer tarafa geçer.
	_look_x = move_toward(_look_x, _facing() * look_ahead, look_ahead * look_ahead_swing * dt)
	# Hız payı: koşarken biraz önden, düşerken biraz aşağıdan, çıkarken azıcık yukarıdan bak.
	var lead_goal := Vector2(
		clampf(vel.x * velocity_lead, -70.0, 70.0),
		clampf(vel.y * (fall_look if vel.y > 0.0 else rise_look), -rise_look_max, fall_look_max))
	_lead = _lead.lerp(lead_goal, 1.0 - exp(-6.0 * dt))
	# Aksiyon odağı: en yakın düşmana doğru azıcık kay.
	_focus = _focus.lerp(_focus_goal(pos), 1.0 - exp(-4.0 * dt))
	# Dikey: zemin referansı yerdeyken yavaşça zemine yerleşir; havadayken kamera yükselişin küçük bir kısmı kadar kayar.
	if grounded:
		_ref_y = lerpf(_ref_y, pos.y, 1.0 - exp(-ground_follow * dt))
	_air_dy = clampf((pos.y - _ref_y) * vertical_gain, -vertical_range, vertical_range)
	# Sert iniş: kamera hafifçe çöker.
	if grounded and not _was_grounded and _fall_vy > landing_min_speed:
		var impact := clampf((_fall_vy - landing_min_speed) / 700.0, 0.0, 1.0)
		_kick_vel.y += lerpf(landing_kick_min, landing_kick_max, impact) * 24.0
	_was_grounded = grounded
	_fall_vy = 0.0 if grounded else maxf(vel.y, 0.0)
	# Zoom
	_zoom_mod = lerpf(_zoom_mod, _zoom_goal() - base_zoom, 1.0 - exp(-5.0 * dt))
	var z := _total_zoom()
	var want := _clamp_to_bounds(_oyuncu_gorunur(_desired(), pos, z), z)
	# Yumuşak takip; hız sınırı sayesinde kamera hiçbir zaman "fırlamaz" (örn. kapıdan geçişte).
	var lim := max_speed * dt
	_pos.x += clampf((want.x - _pos.x) * (1.0 - exp(-follow_speed.x * dt)), -lim, lim)
	_pos.y += clampf((want.y - _pos.y) * (1.0 - exp(-follow_speed.y * dt)), -lim, lim)
	# Sınırlar ya da zoom değişmiş olabilir; oyuncu da her zaman ekranda kalmalı.
	_pos = _clamp_to_bounds(_oyuncu_gorunur(_pos, pos, z), z)


## Oyuncu ekran kenarına `screen_margin`'den fazla yaklaşmasın (look-ahead/odak/gecikme ne olursa olsun).
func _oyuncu_gorunur(cam: Vector2, player_pos: Vector2, zoom_value: float) -> Vector2:
	var half := _view_size() / zoom_value * 0.5
	var reach := Vector2(maxf(half.x - screen_margin.x, 20.0), maxf(half.y - screen_margin.y, 20.0))
	return Vector2(
		clampf(cam.x, player_pos.x - reach.x, player_pos.x + reach.x),
		clampf(cam.y, player_pos.y - reach.y, player_pos.y + reach.y))


func _focus_goal(player_pos: Vector2) -> Vector2:
	if not is_inside_tree():
		return Vector2.ZERO
	var best: Node2D = null
	var best_d := focus_range
	for e in get_tree().get_nodes_in_group("enemies"):
		var n := e as Node2D
		if n == null or (n is ActorBase and (n as ActorBase).dead):
			continue
		var d := n.global_position.distance_to(player_pos)
		if d < best_d:
			best_d = d
			best = n
	if best == null:
		return Vector2.ZERO
	var pull := (best.global_position - player_pos) * focus_weight
	return pull.limit_length(focus_max)


func _update_effects(dt: float) -> void:
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


func _apply() -> void:
	global_position = _pos
	zoom = Vector2.ONE * _total_zoom()
