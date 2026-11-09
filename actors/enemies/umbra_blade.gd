class_name UmbraBlade
extends Hitbox
## Gölge'nin etrafında dönen bıçak (Dönen Bıçaklar yeteneği). Altındır: parry'lersen KIRILIR (birkaç sn sonra yenilenir).
## Değdiği oyuncuya hasar verir, sonra kısa süre bekler (üst üste vurmasın).

const RADIUS := 13.0
const SHATTER_TIME := 3.2
const REHIT_TIME := 0.8

var boss: Node2D = null
var orbit_radius := 82.0
var spin := 3.4
var angle := 0.0

var _broken := 0.0
var _cool := 0.0


func _init() -> void:
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = RADIUS
	cs.shape = shape
	add_child(cs)
	z_index = 3


func _ready() -> void:
	super._ready()
	landed.connect(_on_landed_player)


## `index`/`count`: bıçaklar çembere eşit aralıkla dizilir.
func setup(owner_boss: Node2D, index: int, count: int, dmg: int, radius_px: float) -> void:
	boss = owner_boss
	source = owner_boss
	original_source = owner_boss
	damage = dmg
	parryable = true
	orbit_radius = radius_px
	angle = TAU * float(index) / float(maxi(count, 1))
	position = _orbit_pos()


func is_broken() -> bool:
	return _broken > 0.0


func _orbit_pos() -> Vector2:
	return Vector2(cos(angle), sin(angle) * 0.85) * orbit_radius + Vector2(0.0, -4.0)


func _physics_process(delta: float) -> void:
	if TimeStop.active:
		return
	if _broken > 0.0:
		_broken -= delta
		if _broken <= 0.0:
			_mend()
		return
	angle += spin * delta
	position = _orbit_pos()
	rotation = angle + PI * 0.5
	if _cool > 0.0:
		_cool -= delta
		if _cool <= 0.0:
			active = true
	super._physics_process(delta)


func _on_landed_player(_target: Hurtbox) -> void:
	active = false
	_cool = REHIT_TIME


## Parry'lenince kırılır: görünmez ve etkisiz, SHATTER_TIME sonra yenilenir.
func _on_parried(_by: Node) -> void:
	active = false
	_broken = SHATTER_TIME
	visible = false
	RingFx.spawn(get_parent(), global_position, Color(1.0, 0.85, 0.3, 0.9), 6.0, 40.0, 0.25)
	Sfx.play("shield_break", -4.0, 1.2)


func _mend() -> void:
	visible = true
	active = true
	_cool = 0.0
	RingFx.spawn(get_parent(), global_position, Color(0.72, 0.5, 1.0, 0.8), 4.0, 24.0, 0.2)


func _draw() -> void:
	# Küçük bir hançer: altın hale (parry'lenebilir) + mor bıçak.
	draw_arc(Vector2.ZERO, RADIUS + 4.0, 0.0, TAU, 20, Color(1.0, 0.8, 0.2, 0.55), 2.0)
	var blade := PackedVector2Array([Vector2(0.0, -17.0), Vector2(6.0, 0.0), Vector2(0.0, 10.0), Vector2(-6.0, 0.0)])
	draw_colored_polygon(blade, Color(0.78, 0.62, 1.0))
	var core := PackedVector2Array([Vector2(0.0, -11.0), Vector2(2.6, 0.0), Vector2(0.0, 5.0), Vector2(-2.6, 0.0)])
	draw_colored_polygon(core, Color(1.0, 1.0, 1.0, 0.95))
	draw_line(Vector2(-6.0, 10.0), Vector2(6.0, 10.0), Color(1.0, 0.8, 0.2), 3.0)
