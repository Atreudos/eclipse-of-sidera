class_name Projectile
extends Hitbox
## Mermi. Altın = parry'lenebilir. Parry'lenirse sahibine geri döner, hasarı artar.

const GOLD := Color(1.0, 0.8, 0.2)
const RED := Color(1.0, 0.22, 0.22)
const PARRIED := Color(0.45, 0.95, 1.0)

@export var radius := 10.0
@export var lifetime := 5.0
@export var parried_damage_mult := 2
@export var parried_speed_mult := 1.6

var velocity := Vector2.ZERO
var _age := 0.0


func _ready() -> void:
	collides_with_world = true
	add_to_group("projectiles")
	super._ready()
	hit_world.connect(_on_hit_world)
	landed.connect(_on_landed)
	queue_redraw()


## Mermiyi ateşler. `is_parryable` altın/kırmızı rengi belirler.
func launch(vel: Vector2, is_parryable: bool, shooter: Node, dmg: int = 1) -> void:
	velocity = vel
	parryable = is_parryable
	source = shooter
	damage = dmg
	rotation = vel.angle()
	queue_redraw()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	position += velocity * delta
	_age += delta
	if _age >= lifetime:
		queue_free()


func _on_landed(_target: Hurtbox) -> void:
	queue_free()


func _on_hit_world(_body: Node) -> void:
	queue_free()


func _on_parried(by: Node) -> void:
	# Fırlatana geri gönder (hâlâ hayattaysa), yoksa tam tersi yöne.
	var speed := velocity.length() * parried_speed_mult
	var dir := -velocity.normalized()
	if is_instance_valid(source) and source is Node2D and source != by:
		var shooter_pos := (source as Node2D).global_position
		dir = (shooter_pos - global_position).normalized()
	velocity = dir * speed
	rotation = velocity.angle()
	source = by
	damage *= parried_damage_mult
	parryable = false
	set_faction("player")
	clear_hit_targets()
	_age = 0.0
	queue_redraw()


func _draw() -> void:
	var color := GOLD
	if faction == "player":
		color = PARRIED
	elif not parryable:
		color = RED
	draw_circle(Vector2.ZERO, radius, color)
	draw_circle(Vector2.ZERO, radius * 0.45, Color(1, 1, 1, 0.9))
	draw_arc(Vector2.ZERO, radius + 3.0, 0.0, TAU, 24, Color(color, 0.45), 2.0)
	# kuyruk: hareket yönünü gösterir
	draw_line(Vector2(-radius, 0), Vector2(-radius * 2.6, 0), Color(color, 0.5), 3.0)
