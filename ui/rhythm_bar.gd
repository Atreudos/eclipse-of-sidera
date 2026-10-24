class_name RhythmBar
extends Control
## Ritim (agresiflik) çubuğu: 4 kademeli, kademeye göre renk değiştirir; kademe atlayınca isim pat diye büyür,
## kademe düşünce titrer. Yazılar oyunun fontuyla (AGENTORANGE). Gerçek zamanla akar.

const BAR_SIZE := Vector2(224.0, 12.0)
const SEGMENT_GAP := 3.0
const TIER_COLORS: Array[Color] = [
	Color(0.55, 0.66, 0.82),  # SOĞUK
	Color(1.0, 0.86, 0.3),    # ISINMIŞ
	Color(1.0, 0.55, 0.15),   # ATEŞLİ
	Color(1.0, 0.42, 0.36),   # COŞKULU
]

var meter: RhythmMeter

var _pop := 0.0
var _shake := 0.0
var _t := 0.0
var _last_usec := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	process_mode = Node.PROCESS_MODE_ALWAYS


func bind(m: RhythmMeter) -> void:
	meter = m
	m.tier_changed.connect(_on_tier_changed)


func _on_tier_changed(tier: int, previous: int) -> void:
	if tier > previous:
		_pop = 1.0
	else:
		_shake = 1.0
	queue_redraw()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := 0.0
	if _last_usec != 0:
		dt = clampf(float(now - _last_usec) / 1000000.0, 0.0, 0.05)
	_last_usec = now
	_t += dt
	_pop = maxf(_pop - dt * 3.5, 0.0)
	_shake = maxf(_shake - dt * 4.0, 0.0)
	queue_redraw()


func _draw() -> void:
	if meter == null or not is_instance_valid(meter):
		return
	var tier := meter.tier
	var seg_w := (BAR_SIZE.x - SEGMENT_GAP * 3.0) / 4.0
	for i in 4:
		var x := float(i) * (seg_w + SEGMENT_GAP)
		var rect := Rect2(x, 0.0, seg_w, BAR_SIZE.y)
		var col := TIER_COLORS[i]
		draw_rect(Rect2(rect.position - Vector2.ONE, rect.size + Vector2(2.0, 2.0)), Color(0.04, 0.03, 0.07, 0.85))
		draw_rect(rect, Color(col.r * 0.22, col.g * 0.22, col.b * 0.22, 0.9))
		var fill := 0.0
		if i < tier:
			fill = 1.0
		elif i == tier:
			fill = meter.tier_fraction()
		if fill > 0.0:
			var bright := 1.0
			if tier >= 3 and i == 3:
				bright = 0.85 + 0.15 * sin(_t * 12.0)
			draw_rect(Rect2(rect.position, Vector2(rect.size.x * fill, rect.size.y)), Color(col.r * bright, col.g * bright, col.b * bright, 1.0))
	# Kademe adı: kademe atlayınca büyür, düşünce titrer.
	var name_col := TIER_COLORS[tier]
	if tier >= 3:
		# Coşku: kırmızıyla beyaz arasında parlar (koyu zeminde okunsun).
		name_col = name_col.lerp(Color.WHITE, 0.4 + 0.35 * sin(_t * 10.0))
	var font_size := int(round(22.0 * (1.0 + 0.45 * _pop * _pop)))
	var jitter := Vector2(sin(_t * 90.0) * 4.0 * _shake, 0.0)
	GameFont.draw_left(self, RhythmMeter.tier_name(tier), Vector2(2.0, BAR_SIZE.y + 20.0) + jitter, font_size, name_col)
