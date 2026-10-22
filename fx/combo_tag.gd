class_name ComboTag
extends Node2D
## Kombo göstergesi. Son vurulan düşmanın üstünde durur ve onu yumuşakça takip eder.
##   - İlk vuruştan itibaren: 1 sn'de biten kombo barı (her vuruş/parry barı tazeler).
##   - İkinci olaydan (vuruş ya da parry) itibaren: "COMBO" yazısı (sarı) ve sayaçlar
##     (sayılar sarı, yazılar beyaz): vuruş, parry, toplam hasar.
##   - Süre dolunca sönerek kaybolur; sayaçlar sıfırlanır, yeni kombo sıfırdan başlar.
## Göstergeyi düşman yerine sabit bir noktaya almak istersen: use_fixed = true ve fixed_position (dünya noktası).

const BAR_W := 150.0
const BAR_H := 9.0
const FOLLOW_SPEED := 14.0
const ANCHOR_OFFSET := Vector2(0.0, -150.0)
const FADE_SPEED := 4.5
const POP_DECAY := 5.5
var tracker: ComboTracker
## true ise gösterge düşmanı değil, fixed_position (DÜNYA noktası) civarını izler.
var use_fixed := false
var fixed_position := Vector2.ZERO

var _pop := 0.0
var _flash := 0.0
var _fade := 0.0
var _fading := false
var _final: Array[int] = [0, 0, 0]
var _placed := false
var _anchor := Vector2.ZERO


func _ready() -> void:
	top_level = true
	z_index = 80
	z_as_relative = false
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	visible = false
	if tracker != null:
		tracker.updated.connect(_on_updated)
		tracker.ended.connect(_on_ended)


func _on_updated(_hits: int, _parries: int, _damage: int) -> void:
	_pop = 1.0
	_flash = 1.0
	_fading = false
	if not _placed:
		_follow(1.0, true)


func _on_ended(hits: int, parries: int, damage: int) -> void:
	_final = [hits, parries, damage]
	_fading = hits + parries >= 1
	_fade = 1.0


## Gösterge şu an ekranda mı?
func is_showing() -> bool:
	return tracker != null and (tracker.is_active() or _fading)


func _process(delta: float) -> void:
	if tracker == null:
		return
	_pop = maxf(_pop - delta * POP_DECAY, 0.0)
	_flash = maxf(_flash - delta * 7.0, 0.0)
	if _fading:
		_fade -= delta * FADE_SPEED
		if _fade <= 0.0:
			_fading = false
	visible = is_showing()
	if not visible:
		_placed = false
		return
	_follow(1.0 - exp(-FOLLOW_SPEED * delta), false)
	queue_redraw()


func _follow(weight: float, snap: bool) -> void:
	if use_fixed:
		_anchor = fixed_position
	elif tracker.last_target != null and is_instance_valid(tracker.last_target):
		_anchor = tracker.last_target.global_position
	var desired := _clamp_to_view(_anchor + ANCHOR_OFFSET)
	if snap or not _placed or global_position.distance_to(desired) > 700.0:
		global_position = desired
		_placed = true
	else:
		global_position = global_position.lerp(desired, weight)


## Gösterge kameranın gördüğü alanın dışına taşmasın.
func _clamp_to_view(p: Vector2) -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return p
	var inv := vp.get_canvas_transform().affine_inverse()
	var r: Rect2 = inv * vp.get_visible_rect()
	return Vector2(
		clampf(p.x, r.position.x + 140.0, maxf(r.end.x - 140.0, r.position.x + 140.0)),
		clampf(p.y, r.position.y + 80.0, maxf(r.end.y - 80.0, r.position.y + 80.0)))


func _draw() -> void:
	if tracker == null:
		return
	var hits := 0
	var parries := 0
	var damage := 0
	var frac := 0.0
	var alpha := 1.0
	if tracker.is_active():
		hits = tracker.hits
		parries = tracker.parries
		damage = tracker.damage
		frac = tracker.fraction()
	elif _fading:
		hits = _final[0]
		parries = _final[1]
		damage = _final[2]
		alpha = clampf(_fade, 0.0, 1.0)
	else:
		return
	var is_combo := hits + parries >= ComboTracker.COMBO_MIN_EVENTS
	if is_combo:
		# "COMBO": her artışta "pat" diye büyür, kombo uzadıkça biraz daha iri durur.
		var base := 34 + 3 * mini(hits + parries - ComboTracker.COMBO_MIN_EVENTS, 8)
		var punch := 1.0 + 0.32 * _pop * _pop
		GameFont.draw_centered(self, "COMBO", Vector2(0.0, -40.0), int(round(base * punch)), Color(GameFont.YELLOW, alpha))
	_draw_bar(frac, alpha)
	if is_combo:
		var s := 17 + int(round(5.0 * _pop))
		var gap := ["   ", GameFont.WHITE]
		var runs: Array = [[str(hits), GameFont.YELLOW], [" VURUŞ", GameFont.WHITE], gap]
		# Parry sayacı ilk parry'den sonra çıkar (0 PARRY kalabalık yapıyor, ödül gibi belirsin).
		if parries > 0:
			runs.append_array([[str(parries), GameFont.YELLOW], [" PARRY", GameFont.WHITE], gap])
		runs.append_array([[str(damage), GameFont.YELLOW], [" HASAR", GameFont.WHITE]])
		GameFont.draw_runs_centered(self, runs, Vector2(0.0, 28.0), s, alpha)


func _draw_bar(frac: float, alpha: float) -> void:
	var r := Rect2(-BAR_W * 0.5, -6.0, BAR_W, BAR_H)
	draw_rect(r.grow(2.0), Color(0.03, 0.02, 0.06, 0.8 * alpha))
	draw_rect(r, Color(0.22, 0.18, 0.08, 0.9 * alpha))
	var fill := Rect2(r.position, Vector2(r.size.x * frac, r.size.y))
	# Süre azalınca sarıdan turuncuya döner (kombo bitmek üzere).
	var c := GameFont.YELLOW.lerp(Color(1.0, 0.45, 0.15), clampf((0.35 - frac) / 0.35, 0.0, 1.0))
	draw_rect(fill, Color(c, alpha))
	if _flash > 0.0:
		draw_rect(fill, Color(1.0, 1.0, 1.0, 0.75 * _flash * alpha))
