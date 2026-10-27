class_name Coin
extends CharacterBody2D
## Altın para: düşmandan saçılır, zıplar, oyuncuya yaklaşınca çekilir ve toplanır.
## Oda temizlenince yerde kalan paralar oyuncuya uçar (kaçırılmasın). Mağaza (kat başlarında) bu altınla alışveriş yapılacak.
##
## Koddan çizilir (spritesız): dönen sarı para. "Antika" para daha büyük, bronz renkli ve daha değerlidir.

const SMALL_VALUE := 1
const ANTIQUE_VALUE := 3
const GRAVITY := 1500.0
const BOUNCE := 0.45
const PICKUP_RADIUS := 26.0
const MAGNET_RADIUS := 110.0
## Doğduktan bu kadar sonra toplanabilir (saçılma görünsün).
const COLLECT_DELAY := 0.35
const LIFETIME := 45.0
## Oda temizlenince paralar bu kadar sonra oyuncuya uçar.
const VACUUM_DELAY := 0.5
## Art arda toplanan paraların sesi bu aralıkta (sn) yükselir.
const CHAIN_GAP := 0.45

static var _chain := 0
static var _last_pickup := -10.0

var value := SMALL_VALUE
var antique := false

var _age := 0.0
var _homing := false
var _vacuum_t := -1.0
var _target: Player
var _spin := 0.0


## `pos` civarına `count` para saçar. `antique_coin` = antika para (değeri ANTIQUE_VALUE).
static func drop(parent: Node, pos: Vector2, count: int, antique_coin: bool = false) -> void:
	if parent == null:
		return
	for i in count:
		var c := Coin.new()
		c.antique = antique_coin
		c.value = ANTIQUE_VALUE if antique_coin else SMALL_VALUE
		c.velocity = Vector2(randf_range(-170.0, 170.0), randf_range(-470.0, -300.0))
		parent.add_child(c)
		c.global_position = pos + Vector2(randf_range(-8.0, 8.0), randf_range(-6.0, 6.0))


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.WORLD | Layers.PLATFORM
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0 if not antique else 8.0
	shape.shape = circle
	add_child(shape)
	add_to_group("coins")
	z_index = 8
	_spin = randf() * TAU
	EventBus.room_cleared.connect(_on_room_cleared)


func _exit_tree() -> void:
	if EventBus.room_cleared.is_connected(_on_room_cleared):
		EventBus.room_cleared.disconnect(_on_room_cleared)


func _on_room_cleared(_index: int) -> void:
	_vacuum_t = VACUUM_DELAY


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	if _target == null or not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("player") as Player
	if _vacuum_t >= 0.0:
		_vacuum_t -= delta
		if _vacuum_t < 0.0:
			_homing = true
	var dist := INF
	if _target != null and not _target.dead:
		dist = global_position.distance_to(_target.global_position)
		if _age > COLLECT_DELAY and dist <= MAGNET_RADIUS:
			_homing = true
	if _homing and _target != null and not _target.dead:
		var dir := (_target.global_position - global_position).normalized()
		var speed := minf(260.0 + _age * 260.0 + (MAGNET_RADIUS - minf(dist, MAGNET_RADIUS)) * 4.0, 1100.0)
		velocity = velocity.lerp(dir * speed, clampf(delta * 12.0, 0.0, 1.0))
		global_position += velocity * delta
	else:
		_homing = false
		velocity.y += GRAVITY * delta
		var col := move_and_collide(velocity * delta)
		if col != null:
			var n := col.get_normal()
			if n.y < -0.5:
				velocity.y = -velocity.y * BOUNCE if absf(velocity.y) > 140.0 else 0.0
				velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta * 8.0)
			else:
				velocity = velocity.bounce(n) * 0.6
	if _age > COLLECT_DELAY and dist <= PICKUP_RADIUS:
		_collect()
		return
	queue_redraw()


func _collect() -> void:
	if _target == null:
		return
	var now := float(Time.get_ticks_msec()) / 1000.0
	_chain = _chain + 1 if now - _last_pickup <= CHAIN_GAP else 0
	_last_pickup = now
	_target.add_gold(value)
	Sfx.play("coin", -6.0, 1.0 + 0.05 * float(mini(_chain, 10)), 0.02)
	RingFx.spawn(get_parent(), global_position, Color(1.0, 0.85, 0.3, 0.8), 4.0, 22.0, 0.16)
	queue_free()


func _draw() -> void:
	var t := float(_age) * 7.0 + _spin
	var w := maxf(absf(cos(t)), 0.18)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(w, 1.0))
	if antique:
		draw_circle(Vector2.ZERO, 9.0, Color(0.32, 0.18, 0.05))
		draw_circle(Vector2.ZERO, 7.5, Color(0.86, 0.6, 0.22))
		draw_arc(Vector2.ZERO, 5.0, 0.0, TAU, 18, Color(0.45, 0.27, 0.08), 1.6)
		draw_circle(Vector2.ZERO, 2.2, Color(0.32, 0.18, 0.05))
		draw_circle(Vector2(-2.6, -3.0), 1.6, Color(1.0, 0.92, 0.7, 0.9))
	else:
		draw_circle(Vector2.ZERO, 7.0, Color(0.55, 0.36, 0.05))
		draw_circle(Vector2.ZERO, 5.8, Color(1.0, 0.82, 0.2))
		draw_circle(Vector2(-1.6, -2.0), 2.0, Color(1.0, 0.97, 0.75, 0.95))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
