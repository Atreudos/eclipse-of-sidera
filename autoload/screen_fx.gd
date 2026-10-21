extends CanvasLayer
## Tüm ekranı kısa süre boyayan efekt (hasar = kırmızı kenar, parry = altın).
## EventBus.screen_flash(color, alpha, duration) ile tetiklenir. Gerçek zamanda akar.

var _vignette: TextureRect
var _tint: ColorRect
var _color := Color.WHITE
var _peak := 0.0
var _duration := 0.2
var _age := 0.0
var _last_usec := 0


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.0))
	grad.set_color(1, Color(1, 1, 1, 1.0))
	grad.set_offset(0, 0.35)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	_vignette = TextureRect.new()
	_vignette.texture = tex
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vignette)
	_tint = ColorRect.new()
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tint)
	_vignette.modulate.a = 0.0
	_tint.color.a = 0.0
	EventBus.screen_flash.connect(_on_flash)


func _on_flash(color: Color, alpha: float, duration: float) -> void:
	_color = color
	_peak = clampf(alpha, 0.0, 1.0)
	_duration = maxf(duration, 0.05)
	_age = 0.0


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := 0.0
	if _last_usec != 0:
		dt = clampf(float(now - _last_usec) / 1000000.0, 0.0, 0.05)
	_last_usec = now
	_age += dt
	var k := clampf(_age / _duration, 0.0, 1.0)
	var a := _peak * pow(1.0 - k, 2.0)
	_vignette.modulate = Color(_color, a)
	_tint.color = Color(_color, a * 0.1)
