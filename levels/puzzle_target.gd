class_name PuzzleTarget
extends ActorBase
## Bulmaca hedefi. İki tür:
##   "crystal": yalnız PARRY'lenmiş (geri dönen) mermi yakar. Kılıç vuruşu işe yaramaz.
##   "star":    yalnız kılıç / yumruk vuruşu yakar (mermi geçer). Sıra bulmacasında kullanılır.
## Yanınca `lit` olur; bulmaca mantığı (`PuzzleLogic`) `struck` sinyalini dinler. Çarpışma kutusu yoktur (oyuncuyu engellemez).
## Çizim: `puzzle_crystal` / `puzzle_star` (yoksa yer tutucu).

signal struck(target: PuzzleTarget)

const RADIUS := 26.0

var kind := "crystal"
var index := 0
var lit := false
## Sıra ipucu: 0'dan büyükse parlar (sn); numara gösterilir.
var hint_t := 0.0
var show_number := false
var _t := 0.0
var _deny_t := 0.0
var _hit_t := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	super._ready()
	var hb := Hurtbox.new()
	hb.name = "Hurtbox"
	hb.faction = "enemy"
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = RADIUS
	cs.shape = shape
	hb.add_child(cs)
	add_child(hb)


func on_hit_by(hitbox: Hitbox) -> bool:
	var proj := hitbox is Projectile
	if (kind == "crystal") != proj:
		_deny_t = 0.25
		Sfx.play("hit", -12.0)
		return false
	_hit_t = 0.3
	Sfx.play("tell_gold" if kind == "crystal" else "slash", -4.0, 1.3)
	struck.emit(self)
	return true


func set_lit(value: bool) -> void:
	lit = value


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta
	hint_t = maxf(hint_t - delta, 0.0)
	_deny_t = maxf(_deny_t - delta, 0.0)
	_hit_t = maxf(_hit_t - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var name := "puzzle_crystal" if kind == "crystal" else "puzzle_star"
	var glow := 1.0 if lit else (0.8 if hint_t > 0.0 else 0.0)
	if not Art.draw(self, name, Rect2(-48.0, -48.0, 96.0, 96.0), _t):
		var base := Color(1.0, 0.82, 0.3) if kind == "star" else Color(0.5, 0.9, 1.0)
		var dim := base.darkened(0.6)
		var col := dim.lerp(base, glow)
		if _deny_t > 0.0:
			col = Color(1.0, 0.3, 0.3)
		var pulse := 1.0 + 0.06 * sin(_t * 3.0) + _hit_t
		if kind == "crystal":
			var pts := PackedVector2Array([Vector2(0, -RADIUS * 1.3 * pulse), Vector2(RADIUS * 0.8 * pulse, 0), Vector2(0, RADIUS * 1.3 * pulse), Vector2(-RADIUS * 0.8 * pulse, 0)])
			draw_colored_polygon(pts, col)
			draw_polyline(pts + PackedVector2Array([pts[0]]), base.lightened(0.3), 2.0)
		else:
			var star := PackedVector2Array()
			for i in 10:
				var r := RADIUS * pulse if i % 2 == 0 else RADIUS * 0.45 * pulse
				var a := -PI * 0.5 + float(i) * PI / 5.0
				star.append(Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(star, col)
			draw_polyline(star + PackedVector2Array([star[0]]), base.lightened(0.3), 2.0)
		if glow > 0.0:
			draw_circle(Vector2.ZERO, RADIUS * 2.0, Color(base, 0.12 * glow))
	if show_number and (hint_t > 0.0 or lit):
		GameFont.draw_centered(self, str(index + 1), Vector2(0.0, -RADIUS * 1.9), 22, Color(1, 1, 1, 0.9))
