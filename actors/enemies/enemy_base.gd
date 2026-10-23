class_name EnemyBase
extends ActorBase
## Düşman tabanı: yerçekimi, geri itilme, sersemleme (stun), ölüm efekti, "tell" (uyarı) parlaması,
## animasyon ve (istenirse) platformlara zıplayarak çıkma.
## Saldırı renkleri: ALTIN = parry'lenebilir, KIRMIZI = kaçman gerekir.
##
## Her düşman ailesi yüksekliğe KENDİ yöntemiyle cevap verir:
##   Teklifçi: zıplayıp platforma çıkar.  Ateşçi: çıkmaz, yukarıya ateş eder.  (Diğerleri sonra.)

enum Tell { NONE, GOLD, RED }

const GOLD := Color(1.0, 0.8, 0.2)
const RED := Color(1.0, 0.22, 0.22)
## Başına konulan oyuncudan kayma hızı (px/sn).
const SLIDE_OFF_SPEED := 220.0

# Düşman animasyonları (PNG'ler assets/sprites/<düşman>/ içine konunca otomatik kullanılır).
const ANIM_SPEC := {
	"idle": {"fps": 8.0, "loop": true},
	"run": {"fps": 10.0, "loop": true, "fallback": "idle"},
	"jump": {"fps": 10.0, "loop": false, "fallback": "idle"},
	"fall": {"fps": 10.0, "loop": true, "fallback": "jump"},
	"telegraph": {"fps": 12.0, "loop": false, "fallback": "idle"},
	"attack": {"fps": 14.0, "loop": false, "fallback": "telegraph"},
	"recover": {"fps": 10.0, "loop": false, "fallback": "idle"},
	"stun": {"fps": 8.0, "loop": true, "fallback": "hurt"},
	"hurt": {"fps": 12.0, "loop": false, "fallback": "idle"},
	"death": {"fps": 10.0, "loop": false, "fallback": "hurt"},
}

@export var max_hp: int = 3
@export var gravity := 1900.0
@export var knockback_force := 240.0
## > 0 ise platformlara zıplayabilir (piksel/sn). Zıplama yüksekliği = v² / (2 * gravity).
@export var jump_velocity := 0.0
@export var air_speed := 150.0

var target: Player = null
var facing := -1
var stun_t := 0.0
var knock_t := 0.0
## true iken vuruşla geri itilmez (saldırı sırasında "süper zırh").
var armored := false
var nav: PlatformNav

var _tell := Tell.NONE

@onready var tell_glow: ColorRect = get_node_or_null("Visual/Glow")
@onready var hurtbox: Hurtbox = get_node_or_null("Hurtbox")


func anim_spec() -> Dictionary:
	return ANIM_SPEC


func _ready() -> void:
	super._ready()
	faction = "enemy"
	stats = Stats.new({"max_health": float(max_hp)})
	health = max_hp
	nav = PlatformNav.new(self)
	add_to_group("enemies")
	set_tell(Tell.NONE)


func max_jump_height() -> float:
	return jump_velocity * jump_velocity / (2.0 * gravity)


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
	_slide_off_player()


## Oyuncunun başına konduysak yana kay (gövdeler katı olduğu için üstünde asılı kalmasın).
func _slide_off_player() -> void:
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		if col.get_collider() is Player and col.get_normal().y < -0.6:
			var dir := signf(global_position.x - (col.get_collider() as Node2D).global_position.x)
			velocity.x = (dir if dir != 0.0 else 1.0) * SLIDE_OFF_SPEED
			return


func _process(delta: float) -> void:
	if visual != null:
		# Sprite ve yer tutucular SAĞA bakacak şekilde çizilir; facing = -1 aynalar.
		(visual as Node2D).scale.x = facing if facing != 0 else 1
	if _tell != Tell.NONE:
		if tell_glow != null:
			tell_glow.modulate.a = 0.7 + 0.25 * sin(Time.get_ticks_msec() / 45.0)
		queue_redraw()
	tint = Color(0.6, 0.8, 1.0) if stun_t > 0.0 else Color.WHITE
	anim.play(pick_animation())
	super._process(delta)


## Duruma göre animasyon adı. Alt sınıflar kendi evrelerini ekler.
func pick_animation() -> String:
	if dead:
		return "death"
	if stun_t > 0.0:
		return "stun"
	if knock_t > 0.0:
		return "hurt"
	if not is_on_floor():
		return "jump" if velocity.y < 0.0 else "fall"
	return "run" if absf(velocity.x) > 20.0 else "idle"


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


## Platforma zıplarken çağrılır.
func on_nav_jump() -> void:
	anim.trigger("jump")


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
		anim.trigger("hurt", 0.2)
	return true


func die() -> void:
	if dead:
		return
	super.die()
	remove_from_group("enemies")
	EventBus.enemy_died.emit(self)
	set_tell(Tell.NONE)
	# Ölü düşman artık engel olmaz (oyuncu içinden geçebilir).
	set_deferred("collision_layer", 0)
	if hurtbox != null:
		hurtbox.set_deferred("monitorable", false)
	_on_death()
	if anim.has_anim("death"):
		# Ölüm animasyonu varsa bitmesini bekle, sonra sön.
		anim.trigger("death")
		var tw_art := create_tween()
		tw_art.tween_interval(clampf(anim.duration_of("death"), 0.25, 1.5))
		tw_art.tween_property(self, "modulate:a", 0.0, 0.25)
		tw_art.tween_callback(queue_free)
	else:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "modulate:a", 0.0, 0.3)
		tw.tween_property(self, "scale", Vector2(1.25, 0.1), 0.3)
		tw.chain().tween_callback(queue_free)
	RingFx.spawn(get_parent(), global_position, Color(1, 1, 1, 0.8), 10.0, 60.0, 0.3)


func _on_death() -> void:
	pass
