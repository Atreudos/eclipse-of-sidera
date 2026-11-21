class_name Gemini
extends Taurus
## Gemini (İkizler): iki ayrı düşman olarak birlikte doğar, hızlı ve hafif. Biri ölünce diğeri ÖFKELENİR:
## daha hızlı, daha kısa uyarılı ve daha sık kırmızı saldırır. İlk hangisini öldüreceğin seçimdir.

const ENRAGE_SPEED := 1.4
const ENRAGE_WARN := 0.8
const ENRAGE_RED := 0.3
const TWIN_A := Color(0.8, 0.95, 1.0)
const TWIN_B := Color(1.0, 0.85, 1.0)
const ENRAGED := Color(1.0, 0.6, 0.6)

## Doğarken eşleşmeyi bekleyen ikiz (sahneye girerken eşsiz kalan ilki).
static var _waiting: Gemini = null

var twin: Gemini = null
var enraged := false


func anim_folder() -> String:
	return "res://assets/sprites/gemini"


func _ready() -> void:
	super._ready()
	if is_instance_valid(_waiting) and not _waiting.dead and _waiting.twin == null and _waiting != self:
		twin = _waiting
		twin.twin = self
		base_tint = TWIN_B
		_waiting = null
	else:
		_waiting = self
		base_tint = TWIN_A


func _exit_tree() -> void:
	super._exit_tree()
	if _waiting == self:
		_waiting = null


func _on_death() -> void:
	super._on_death()
	if is_instance_valid(twin) and not twin.dead:
		twin.enrage()


func enrage() -> void:
	if enraged or dead:
		return
	enraged = true
	walk_speed *= ENRAGE_SPEED
	lunge_speed *= ENRAGE_SPEED
	telegraph_time = maxf(telegraph_time * ENRAGE_WARN, TELEGRAPH_FLOOR)
	red_chance = clampf(red_chance + ENRAGE_RED, 0.0, EnemyScaling.MAX_RED_SHARE)
	base_tint = ENRAGED
	RingFx.spawn(get_parent(), global_position + Vector2(0.0, -10.0), Color(1.0, 0.35, 0.3, 0.9), 8.0, 70.0, 0.4)
