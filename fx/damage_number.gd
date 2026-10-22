class_name DamageNumber
extends Node2D
## Vurulan düşmanın üstünde çıkan hasar sayısı. Büyüyerek "pat" diye belirir, yukarı süzülür, söner.
## Süre oyun zamanına bağlıdır: hitstop sırasında sayı belirdiği halde donuk kalır (vuruş anı net okunur).

const LIFETIME := 0.85
const POP_TIME := 0.2
const FADE_START := 0.5

var amount := 1
var color := GameFont.YELLOW
var base_size := 30
## Yatay savrulma yönü (-1..1). Art arda gelen sayılar birbirinin üstüne binmesin diye.
var drift := 0.0

var _t := 0.0
var _tilt := 0.0
var _rise := 0.0


## `pos`: sayının doğduğu dünya konumu (düşmanın göğsü civarı).
static func spawn(parent: Node, pos: Vector2, dmg: int, side: float = 0.0) -> DamageNumber:
	if parent == null:
		return null
	var n := DamageNumber.new()
	n.amount = dmg
	n.drift = side
	n.base_size = 30 + 7 * clampi(dmg - 1, 0, 5)
	parent.add_child(n)
	n.global_position = pos
	return n


func _ready() -> void:
	z_index = 60
	z_as_relative = false
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_tilt = randf_range(-0.09, 0.09)


## Belirme anında hafif aşırı büyüyüp yerine oturan eğri (easeOutBack). 0 -> 0.45x, 1 -> 1x.
static func pop_scale(k: float) -> float:
	var x := clampf(k, 0.0, 1.0)
	var c1 := 2.4
	var c3 := c1 + 1.0
	var eased := 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)
	return lerpf(0.45, 1.0, eased)


func current_alpha() -> float:
	if _t < FADE_START:
		return 1.0
	return clampf(1.0 - (_t - FADE_START) / (LIFETIME - FADE_START), 0.0, 1.0)


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFETIME:
		queue_free()
		return
	_rise = 1.0 - pow(1.0 - clampf(_t / LIFETIME, 0.0, 1.0), 3.0)
	rotation = _tilt * (1.0 - clampf(_t / 0.3, 0.0, 1.0))
	queue_redraw()


func _draw() -> void:
	var size := maxi(int(round(base_size * pop_scale(_t / POP_TIME))), 8)
	var c := color
	c.a = current_alpha()
	GameFont.draw_centered(self, str(amount), Vector2(drift * 38.0, -62.0) * _rise, size, c)
