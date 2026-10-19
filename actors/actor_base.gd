class_name ActorBase
extends CharacterBody2D
## Oyuncu, düşmanlar ve (ileride) Rakip için ortak taban: can, hasar, görsel geri bildirim.

signal damaged(amount: int, source: Node)
signal died

@export_enum("player", "enemy") var faction: String = "enemy"

var stats: Stats
var health: int = 1
var dead := false
## Ekstra dokunulmazlık süresi (parry sonrası, hasar sonrası vb.)
var invulnerable_t := 0.0

## Görsel renk (modulate). Alt sınıflar bunu değiştirerek durum gösterir.
var tint := Color.WHITE
var flash_color := Color.WHITE
var flash_t := 0.0

@onready var visual: CanvasItem = get_node_or_null("Visual")


func _process(delta: float) -> void:
	if visual == null:
		return
	flash_t = maxf(flash_t - delta, 0.0)
	visual.modulate = flash_color if flash_t > 0.0 else tint


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
	flash(Color.WHITE, 0.09)
	if health <= 0:
		die()


func die() -> void:
	if dead:
		return
	dead = true
	died.emit()
	EventBus.actor_died.emit(self)


func flash(color: Color, duration: float = 0.09) -> void:
	flash_color = color
	flash_t = duration
