class_name EnemyBase
extends ActorBase
## Düşman tabanı: yerçekimi, geri itilme, sersemleme (stun), ölüm efekti, "tell" (uyarı) parlaması.
## Saldırı renkleri: ALTIN = parry'lenebilir, KIRMIZI = kaçman gerekir.

enum Tell { NONE, GOLD, RED }

const GOLD := Color(1.0, 0.8, 0.2)
const RED := Color(1.0, 0.22, 0.22)

@export var max_hp: int = 3
@export var gravity := 1900.0
@export var knockback_force := 240.0

var target: Player = null
var facing := -1
var stun_t := 0.0
var knock_t := 0.0
## true iken vuruşla geri itilmez (saldırı sırasında "süper zırh").
var armored := false

var _tell := Tell.NONE

@onready var tell_glow: ColorRect = get_node_or_null("Visual/Glow")
@onready var hurtbox: Hurtbox = get_node_or_null("Hurtbox")


func _ready() -> void:
	faction = "enemy"
	stats = Stats.new({"max_health": float(max_hp)})
	health = max_hp
	add_to_group("enemies")
	set_tell(Tell.NONE)


func _physics_process(delta: float) -> void:
	if dead:
		return
	_find_target()
	velocity.y = minf(velocity.y + gravity * delta, 1200.0)
	if knock_t > 0.0:
		knock_t -= delta
		velocity.x = move_toward(velocity.x, 0.0, 1800.0 * delta)
	elif stun_t > 0.0:
		stun_t -= delta
		velocity.x = move_toward(velocity.x, 0.0, 2400.0 * delta)
		if stun_t <= 0.0:
			_on_stun_end()
	else:
		_ai(delta)
	move_and_slide()


func _process(delta: float) -> void:
	if visual != null:
		(visual as Node2D).scale.x = -facing if facing != 0 else 1
	if _tell != Tell.NONE:
		if tell_glow != null:
			tell_glow.modulate.a = 0.7 + 0.25 * sin(Time.get_ticks_msec() / 45.0)
		queue_redraw()
	tint = Color(0.6, 0.8, 1.0) if stun_t > 0.0 else Color.WHITE
	super._process(delta)


func _find_target() -> void:
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as Player


func is_stunned() -> bool:
	return stun_t > 0.0


## Alt sınıflar bunu doldurur.
func _ai(_delta: float) -> void:
	pass


func _on_stun_end() -> void:
	pass


func _on_stunned() -> void:
	pass


func stun(duration: float) -> void:
	stun_t = maxf(stun_t, duration)
	armored = false
	set_tell(Tell.NONE)
	_on_stunned()


func set_tell(mode: Tell) -> void:
	var changed := mode != _tell
	_tell = mode
	if tell_glow != null:
		tell_glow.visible = mode != Tell.NONE
		tell_glow.color = GOLD if mode == Tell.GOLD else RED
	if changed and mode != Tell.NONE:
		Sfx.play("tell_gold" if mode == Tell.GOLD else "tell_red")
	queue_redraw()


## Saldırı uyarısı: altın = parry'le (elmas), kırmızı = kaç (X). Şekil, renk körlüğüne karşı da ayırt edici.
func _draw() -> void:
	if _tell == Tell.NONE:
		return
	var pulse := 1.0 + 0.18 * sin(Time.get_ticks_msec() / 55.0)
	var y := -58.0
	if _tell == Tell.GOLD:
		var r := 14.0 * pulse
		var pts := PackedVector2Array([Vector2(0, y - r), Vector2(r, y), Vector2(0, y + r), Vector2(-r, y)])
		draw_colored_polygon(pts, GOLD)
		pts.append(pts[0])
		draw_polyline(pts, Color.WHITE, 2.5)
	else:
		var r := 11.0 * pulse
		draw_line(Vector2(-r, y - r), Vector2(r, y + r), Color.WHITE, 9.0)
		draw_line(Vector2(-r, y + r), Vector2(r, y - r), Color.WHITE, 9.0)
		draw_line(Vector2(-r, y - r), Vector2(r, y + r), RED, 5.0)
		draw_line(Vector2(-r, y + r), Vector2(r, y - r), RED, 5.0)


func on_hit_by(hitbox: Hitbox) -> bool:
	if dead:
		return false
	var amount := hitbox.damage
	if is_stunned():
		amount = ceili(amount * 1.5)  # sersemlemiş düşman daha çok hasar alır
	take_damage(amount, hitbox.source)
	if not dead and not armored:
		var dir := signf(global_position.x - hitbox.global_position.x)
		velocity.x = (dir if dir != 0.0 else 1.0) * knockback_force
		velocity.y = -110.0
		knock_t = 0.12
	return true


func die() -> void:
	if dead:
		return
	super.die()
	remove_from_group("enemies")
	EventBus.enemy_died.emit(self)
	set_tell(Tell.NONE)
	if hurtbox != null:
		hurtbox.set_deferred("monitorable", false)
	_on_death()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_property(self, "scale", Vector2(1.25, 0.1), 0.3)
	tw.chain().tween_callback(queue_free)
	RingFx.spawn(get_parent(), global_position, Color(1, 1, 1, 0.8), 10.0, 60.0, 0.3)


func _on_death() -> void:
	pass
