class_name WaterPuddle
extends Node2D
## Aquarius'un suyu. Önce kırmızı UYARI halkası (zeminde, nereye döküleceği), sonra su çarpar (kısa hasar alanı),
## ardından birkaç saniye SU BİRİKİNTİSİ kalır: içindeki oyuncu yavaşlar ("ISLAK").

const WARN_TIME := 0.85
const SPLASH_TIME := 0.12
const LIFE := 4.5
const RADIUS := 90.0
const SLOW_MULT := 0.55
## Birikintiye değmek için ayaklar zeminden en fazla bu kadar yukarıda olabilir (px).
const REACH_Y := 40.0

var damage := 1
var source: Node = null
var _t := 0.0
var _splash: Hitbox = null


func setup(owner_node: Node, dmg: int) -> void:
	source = owner_node
	damage = dmg


func _ready() -> void:
	z_index = -1
	add_to_group("puddles")


func _physics_process(delta: float) -> void:
	if TimeStop.active:
		return
	_t += delta
	if _splash == null and _t >= WARN_TIME:
		_make_splash()
	if _splash != null and is_instance_valid(_splash) and _t >= WARN_TIME + SPLASH_TIME:
		_splash.active = false
		_splash.queue_free()
		_splash = null
	if _t >= WARN_TIME:
		_slow_player()
	if _t >= WARN_TIME + LIFE:
		queue_free()
	queue_redraw()


func _make_splash() -> void:
	_splash = Hitbox.new()
	_splash.faction = "enemy"
	_splash.parryable = false
	_splash.damage = damage
	_splash.source = source
	_splash.original_source = source
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(RADIUS * 2.0, 60.0)
	shape.shape = rect
	_splash.add_child(shape)
	_splash.position = Vector2(0.0, -30.0)
	add_child(_splash)
	_splash.active = true
	RingFx.spawn(get_parent(), global_position, Color(0.5, 0.8, 1.0, 0.9), 10.0, RADIUS, 0.3)


func _slow_player() -> void:
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null or p.dead:
		return
	if absf(p.global_position.x - global_position.x) <= RADIUS and absf(p.feet_y() - global_position.y) <= REACH_Y:
		p.apply_status("wet", 0.35, [["move_speed", 0.0, SLOW_MULT]], "ISLAK")


func _draw() -> void:
	if _t < WARN_TIME:
		var k := _t / WARN_TIME
		var a := 0.35 + 0.35 * sin(_t * 18.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.22))
		draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 40, Color(1.0, 0.25, 0.25, a), 4.0)
		draw_circle(Vector2.ZERO, RADIUS * k, Color(1.0, 0.25, 0.25, 0.12))
		return
	var fade := clampf((WARN_TIME + LIFE - _t) / 1.0, 0.0, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, RADIUS, Color(0.3, 0.6, 1.0, 0.35 * fade))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 40, Color(0.6, 0.85, 1.0, 0.7 * fade), 3.0)
