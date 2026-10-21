class_name ActorBase
extends CharacterBody2D
## Oyuncu, düşmanlar ve (ileride) Rakip için ortak taban: can, hasar, görsel geri bildirim, animasyon.

signal damaged(amount: int, source: Node)
signal died

const FLASH_SHADER := preload("res://fx/flash.gdshader")

@export_enum("player", "enemy") var faction: String = "enemy"

var stats: Stats
var health: int = 1
var dead := false
## Ekstra dokunulmazlık süresi (parry sonrası, hasar sonrası vb.)
var invulnerable_t := 0.0

## Görsel renk (modulate). Alt sınıflar bunu değiştirerek durum gösterir.
var tint := Color.WHITE
## Vuruş flaşı: görsel kısa süre bu renge boyanır ve eski haline söner.
var flash_color := Color.WHITE
var flash_t := 0.0
var flash_total := 0.1

## Animasyonlar. Sprite PNG'leri varsa onlar oynar, yoksa yer tutucu şekiller görünür.
var anim := ActorAnim.new()

var _flash_mat: ShaderMaterial

@onready var visual: CanvasItem = get_node_or_null("Visual")


func _ready() -> void:
	_setup_visual()


## Alt sınıflar: sprite klasörü (örn. "res://assets/sprites/player") ve animasyon tanımı.
func anim_folder() -> String:
	return ""


func anim_spec() -> Dictionary:
	return {}


func _setup_visual() -> void:
	if visual == null:
		return
	anim.setup(visual, anim_folder(), anim_spec(), _body_bottom())
	_flash_mat = ShaderMaterial.new()
	_flash_mat.shader = FLASH_SHADER
	_apply_flash_material(visual)


func _apply_flash_material(node: Node) -> void:
	for c in node.get_children():
		# "Glow" (saldırı uyarısı) kendi renginde kalır.
		if c is CanvasItem and c.name != &"Glow":
			(c as CanvasItem).material = _flash_mat
		_apply_flash_material(c)


func _body_bottom() -> float:
	var body := get_node_or_null("Body") as CollisionShape2D
	if body != null and body.shape is RectangleShape2D:
		return body.position.y + (body.shape as RectangleShape2D).size.y * 0.5
	return 26.0


## Ayakların dünya y koordinatı (çarpışma kutusunun altı).
func feet_y() -> float:
	return global_position.y + _body_bottom()


func body_half_width() -> float:
	var body := get_node_or_null("Body") as CollisionShape2D
	if body != null and body.shape is RectangleShape2D:
		return (body.shape as RectangleShape2D).size.x * 0.5
	return 14.0


func _process(delta: float) -> void:
	if visual == null:
		return
	flash_t = maxf(flash_t - delta, 0.0)
	visual.modulate = tint
	if _flash_mat != null:
		# Başta tam parlak kalır, sonra söner.
		var amount := minf(flash_t / maxf(flash_total, 0.001) * 1.6, 1.0) if flash_t > 0.0 else 0.0
		_flash_mat.set_shader_parameter("flash_color", flash_color)
		_flash_mat.set_shader_parameter("flash_amount", amount)


func flash_amount() -> float:
	if _flash_mat == null:
		return 0.0
	return float(_flash_mat.get_shader_parameter("flash_amount"))


func is_invulnerable() -> bool:
	return invulnerable_t > 0.0


## Bir hitbox bu aktörün hurtbox'ına değdi. true = hasar işlendi.
func on_hit_by(hitbox: Hitbox) -> bool:
	if dead or is_invulnerable():
		return false
	take_damage(hitbox.damage, hitbox.source)
	return true


func take_damage(amount: int, source: Node = null) -> void:
	if dead:
		return
	health = maxi(health - amount, 0)
	damaged.emit(amount, source)
	EventBus.damage_dealt.emit(self, amount, source)
	_hit_feedback(source)
	if health <= 0:
		die()


## Vuruş geri bildirimi: flaş + kıvılcım. Alt sınıflar _hit_flash'ı değiştirebilir.
func _hit_feedback(source: Node) -> void:
	_hit_flash()
	var to_attacker := Vector2.RIGHT
	if source is Node2D and (source as Node2D).global_position.distance_to(global_position) > 1.0:
		to_attacker = ((source as Node2D).global_position - global_position).normalized()
	HitSpark.spawn(get_parent(), global_position + to_attacker * 12.0, -to_attacker, Color(1.0, 0.95, 0.8), 1.25)


func _hit_flash() -> void:
	flash(Color.WHITE, 0.14)


func die() -> void:
	if dead:
		return
	dead = true
	died.emit()
	EventBus.actor_died.emit(self)


func flash(color: Color, duration: float = 0.1) -> void:
	flash_color = color
	flash_t = duration
	flash_total = duration
