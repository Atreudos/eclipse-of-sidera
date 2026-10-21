class_name PlatformNav
extends RefCounted
## Düşmanın farklı yükseklikteki hedefe ulaşması:
##  - hedef YUKARIDA (başka bir platformda): platformun altına yürür, düz yukarı zıplayıp üstüne çıkar.
##  - hedef AŞAĞIDA ve tam altımızdaysa: platformun kenarına yürüyüp aşağı iner.
## Platformlar: "platforms" grubundaki CollisionShape2D (RectangleShape2D) düğümleridir.
## Tek yönlü (one-way) platformlar aşağıdan geçilebildiği için düz zıplamak yeter.

const EDGE_MARGIN := 6.0          # gövde kenarı ile platform kenarı arasındaki pay (px)
const MIN_RISE := 28.0            # bundan alçak basamaklar için zıplamaya gerek yok
const CLEARANCE := 44.0           # zıplama zirvesi platform yüzeyinin bu kadar üstünde olsun
const LEVEL_TOLERANCE := 56.0     # hedef bu kadar yüksek/alçaksa farklı seviyede sayılır
const GROUNDED_TIME := 0.25       # hedef bu süre yerdeyse seviyesi "oturmuş" sayılır (zıplarken tetiklenmesin)
const JUMP_COOLDOWN := 0.9

var enemy: EnemyBase
var jump_cooldown := 0.0
var climbing := false

var _goal_x := 0.0
var _target_grounded_t := 0.0
## Aşağı inmeye karar verdiyse yönü (0 = karar yok). Gövde kenardan tamamen çıkana kadar korunur.
var _descend_dir := 0


func _init(owner_enemy: EnemyBase) -> void:
	enemy = owner_enemy


## Her fizik karesinde çağır. true = bu karede yatay hareketi bu sınıf yönetti (normal kovalamayı atla).
func update(delta: float, walk_speed: float) -> bool:
	var t := enemy.target
	if t == null or not is_instance_valid(t) or t.dead:
		climbing = false
		return false
	jump_cooldown = maxf(jump_cooldown - delta, 0.0)
	if t.is_on_floor():
		_target_grounded_t += delta
	else:
		_target_grounded_t = 0.0

	if not enemy.is_on_floor():
		_descend_dir = 0
		if climbing:
			# Zıplamadayız: platformun üstüne konmak için süzül.
			enemy.velocity.x = clampf((_goal_x - enemy.global_position.x) * 8.0, -enemy.air_speed, enemy.air_speed)
			return true
		return false
	climbing = false

	if _target_grounded_t < GROUNDED_TIME:
		_descend_dir = 0
		return false
	var dy := t.feet_y() - enemy.feet_y()  # negatif = hedef yukarıda
	if dy < -LEVEL_TOLERANCE:
		_descend_dir = 0
		return _climb(delta, walk_speed, t)
	if dy > LEVEL_TOLERANCE:
		return _descend(walk_speed, t)
	_descend_dir = 0
	return false


func _climb(delta: float, walk_speed: float, t: ActorBase) -> bool:
	if enemy.jump_velocity <= 0.0:
		return false
	var plat := best_platform_up(t)
	if plat.size == Vector2.ZERO:
		return false
	var half_w := enemy.body_half_width()
	var lo := plat.position.x + half_w + EDGE_MARGIN
	var hi := plat.end.x - half_w - EDGE_MARGIN
	if hi < lo:
		return false
	var x := enemy.global_position.x
	var gx := clampf(x, lo, hi)
	if absf(gx - x) > 6.0:
		# Önce platformun altına yürü.
		enemy.facing = 1 if gx > x else -1
		enemy.velocity.x = enemy.facing * walk_speed
		return true
	enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, 1800.0 * delta)
	if jump_cooldown <= 0.0:
		var need := enemy.feet_y() - plat.position.y + CLEARANCE
		enemy.velocity.y = -minf(sqrt(2.0 * enemy.gravity * need), enemy.jump_velocity)
		jump_cooldown = JUMP_COOLDOWN
		climbing = true
		_goal_x = clampf(t.global_position.x, lo, hi)
		enemy.on_nav_jump()
	return true


func _descend(walk_speed: float, t: ActorBase) -> bool:
	if _descend_dir == 0:
		var plat := platform_under_feet()
		if plat.size == Vector2.ZERO:
			return false
		var tx := t.global_position.x
		if tx < plat.position.x - 8.0 or tx > plat.end.x + 8.0:
			return false  # hedef platformun dışında: normal kovalama zaten kenardan düşürür
		var x := enemy.global_position.x
		_descend_dir = -1 if (x - plat.position.x) < (plat.end.x - x) else 1
	# Gövde kenardan tamamen çıkıp düşene kadar aynı yöne yürü (yarı destekliyken geri dönmesin).
	enemy.facing = _descend_dir
	enemy.velocity.x = _descend_dir * walk_speed
	return true


## Zıplayarak ulaşılabilecek, hedefe en yakın platform. Yoksa boş Rect2.
func best_platform_up(t: ActorBase) -> Rect2:
	var my_feet := enemy.feet_y()
	var reach := enemy.max_jump_height() - 10.0
	var tfeet := t.feet_y()
	var tx := t.global_position.x
	var best := Rect2()
	var best_score := INF
	for r in platform_rects():
		var rise := my_feet - r.position.y
		if rise < MIN_RISE or rise > reach:
			continue
		if r.position.y < tfeet - 24.0:
			continue  # hedefin ayaklarından yüksek: fazla çıkmış oluruz
		var hx := 0.0
		if tx < r.position.x or tx > r.end.x:
			hx = minf(absf(tx - r.position.x), absf(tx - r.end.x))
		var score := absf(tfeet - r.position.y) + hx * 0.5
		if score < best_score:
			best_score = score
			best = r
	return best


## Düşmanın ayaklarının bastığı platform. Yerdeyse (platform değilse) boş Rect2.
func platform_under_feet() -> Rect2:
	var feet := enemy.feet_y()
	var x := enemy.global_position.x
	for r in platform_rects():
		if absf(r.position.y - feet) <= 6.0 and x >= r.position.x - 4.0 and x <= r.end.x + 4.0:
			return r
	return Rect2()


func platform_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for n in enemy.get_tree().get_nodes_in_group("platforms"):
		var cs := n as CollisionShape2D
		if cs == null or not (cs.shape is RectangleShape2D):
			continue
		var size := (cs.shape as RectangleShape2D).size * cs.global_scale.abs()
		out.append(Rect2(cs.global_position - size * 0.5, size))
	return out
