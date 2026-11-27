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
## true ise zaman durunca (Satürn'ün Kum Saati) da uçar (oyuncunun sapan taşı).
var ignores_time_stop := false
## Yön takibi (Gölge "Süperteknolojik Nişangâh"ı aldıysa fırlattığı bıçaklar): saniyede en çok `homing_turn` radyan hedefe döner.
## Parry'lenince ya da hedef arkaya düşünce biter. 0 = takip yok.
var homing_target: Node2D = null
var homing_turn := 0.0
var _age := 0.0

## Hedef bu açıdan (rad) fazla yan/arka tarafta kaldıysa mermi dönmez (geri dönüp çarpmaz).
const HOMING_MAX_ANGLE := 1.6


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
	original_source = shooter
	damage = dmg
	rotation = vel.angle()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if TimeStop.active and not ignores_time_stop:
		return  # zaman durdu: mermi havada asılı kalır
	super._physics_process(delta)
	_steer(delta)
	position += velocity * delta
	_age += delta
	if Art.has("fx_projectile_gold"):
		queue_redraw()  # çizim şeridi oynasın
	if _age >= lifetime:
		queue_free()


## Hafif yön takibi: hızın yönü hedefe doğru, saniyede `homing_turn` radyanı aşmayacak kadar döner (hız aynı kalır).
func _steer(delta: float) -> void:
	if homing_turn <= 0.0 or faction != "enemy" or homing_target == null or not is_instance_valid(homing_target):
		return
	var want := (homing_target.global_position + Vector2(0.0, -6.0) - global_position).angle()
	var diff := wrapf(want - velocity.angle(), -PI, PI)
	if absf(diff) > HOMING_MAX_ANGLE:
		return
	var step := clampf(diff, -homing_turn * delta, homing_turn * delta)
	velocity = velocity.rotated(step)
	rotation = velocity.angle()


func _on_landed(_target: Hurtbox) -> void:
	_burst()
	queue_free()


func _on_hit_world(_body: Node) -> void:
	_burst()
	queue_free()


## İsabet / sönme patlaması (fx_projectile_hit çizimi varsa).
func _burst() -> void:
	ArtFx.play(get_parent(), "fx_projectile_hit", global_position)


func _on_parried(by: Node) -> void:
	# Fırlatana geri gönder (hâlâ hayattaysa), yoksa tam tersi yöne.
	var speed := velocity.length() * parried_speed_mult
	var dir := -velocity.normalized()
	if is_instance_valid(source) and source is Node2D and source != by:
		var shooter_pos := (source as Node2D).global_position
		dir = (shooter_pos - global_position).normalized()
	velocity = dir * speed
	rotation = velocity.angle()
	homing_turn = 0.0
	homing_target = null
	source = by
	damage *= parried_damage_mult
	parryable = false
	set_faction("player")
	clear_hit_targets()
	_age = 0.0
	queue_redraw()


func _draw() -> void:
	# Çizim varsa (fx_projectile_gold / red / parried) o; yoksa kod çizimi.
	var art := "fx_projectile_gold"
	if faction == "player":
		art = "fx_projectile_parried"
	elif not parryable:
		art = "fx_projectile_red"
	var sz := radius * 3.2
	if Art.draw(self, art, Rect2(-sz * 0.5, -sz * 0.5, sz, sz), _age):
		return
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
