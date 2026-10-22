class_name ParryWave
extends CanvasLayer
## Parry dalgası: parry anında oyuncudan yayılan beyaz-sarı şok dalgası.
##
## Dalga TÜM EKRANI kaplayana kadar büyür. Parry menzili içindeyken (oyuncunun parry bölgesi) parlak ve
## opaktır; menzilin dışına çıkınca opaklığı belirgin biçimde düşer ama ekran dolana kadar görünür kalır.
## Zaman oyun zamanıdır: parry'nin hitstop'u sırasında dalga menzil sınırında "donar", sonra patlayarak yayılır.

const SHADER := preload("res://fx/parry_wave.gdshader")

const DURATION := 0.62
## İlk aşama: parlak halka parry bölgesinin kenarına oturur.
const INNER_TIME := 0.09
## Menzil dışındaki halkanın opaklığı (menzil içi 1.0).
const OUTSIDE_ALPHA := 0.2

var world_pos := Vector2.ZERO
## Parry menzili (dünya birimi). Oyuncunun "parry_zone_radius" stat'ı.
var range_world := 48.0

var _t := 0.0
var _rect: ColorRect
var _mat: ShaderMaterial


static func spawn(parent: Node, at: Vector2, parry_range: float) -> ParryWave:
	if parent == null:
		return null
	var w := ParryWave.new()
	w.world_pos = at
	w.range_world = parry_range
	parent.add_child(w)
	return w


func _ready() -> void:
	layer = 5  # dünyanın üstünde, HUD'un (10) altında
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	add_child(_rect)
	update_visual()


## Dalga önünün yarıçapı (piksel). t: saniye, range_px: parry menzili, r_max: ekranı tamamen saran yarıçap.
static func radius_at(t: float, range_px: float, r_max: float) -> float:
	var r0 := range_px * 0.7
	var r1 := range_px * 1.1
	if t < INNER_TIME:
		var k := clampf(t / INNER_TIME, 0.0, 1.0)
		return lerpf(r0, r1, 1.0 - pow(1.0 - k, 3.0))
	var u := clampf((t - INNER_TIME) / (DURATION - INNER_TIME), 0.0, 1.0)
	# Menzil sınırında kısa süre oyalanır (opaklık düşüşü görünsün), sonra ekranı hızla doldurur.
	return lerpf(r1, r_max, smoothstep(0.0, 1.0, u))


## Halkanın opaklığı: menzil içinde 1, menzilin dışına çıkınca OUTSIDE_ALPHA'ya düşer.
static func ring_alpha_at(r: float, range_px: float) -> float:
	var inside := 1.0 - smoothstep(range_px, range_px * 1.8, r)
	return lerpf(OUTSIDE_ALPHA, 1.0, inside)


## Ekranın en uzak köşesine kadar uzanan yarıçap.
static func cover_radius(center: Vector2, view_size: Vector2) -> float:
	var far := 0.0
	for corner in [Vector2.ZERO, Vector2(view_size.x, 0.0), Vector2(0.0, view_size.y), view_size]:
		far = maxf(far, center.distance_to(corner))
	return far + 70.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
		return
	update_visual()


## Mevcut zamana göre görünümü günceller (kamera hareket ederse dalga dünyada sabit kalır).
func update_visual() -> void:
	var vp := get_viewport()
	if vp == null or _mat == null:
		return
	var xf := vp.get_canvas_transform()
	var center := xf * world_pos
	var size := vp.get_visible_rect().size
	var range_px := range_world * xf.get_scale().x
	var r_max := cover_radius(center, size)
	var r := radius_at(_t, range_px, r_max)
	var k := clampf(_t / DURATION, 0.0, 1.0)
	var late := 1.0 - smoothstep(0.62, 1.0, k)
	var wash := lerpf(0.34, 0.1, smoothstep(range_px, range_px * 3.0, r)) * (1.0 - smoothstep(0.35, 1.0, k))
	_mat.set_shader_parameter("center", center)
	_mat.set_shader_parameter("viewport_size", size)
	_mat.set_shader_parameter("radius", r)
	_mat.set_shader_parameter("thickness", lerpf(14.0, 64.0, smoothstep(0.0, r_max, r)))
	_mat.set_shader_parameter("trail", 40.0 + 0.18 * r)
	_mat.set_shader_parameter("ring_alpha", ring_alpha_at(r, range_px) * late)
	_mat.set_shader_parameter("wash_alpha", wash)


## Testler için: şu anki halka yarıçapı ve opaklığı.
func current_radius() -> float:
	return float(_mat.get_shader_parameter("radius")) if _mat != null else 0.0


func current_ring_alpha() -> float:
	return float(_mat.get_shader_parameter("ring_alpha")) if _mat != null else 0.0


func age() -> float:
	return _t
