class_name AmbientFx
extends Node2D
## Odaya hafif ortam parçacıkları (toz, kıvılcım, yağmur, kül). Kata göre tema seçilir; her oda bir tane taşır.
## Parçacıklar CPUParticles2D'dir (GL Compatibility uyumlu), oda koordinatındadır. Godot'ta henüz koşulmadı.

## Varsayılan "dust"; buradaki katlar kendi temasını alır.
const THEMES := {4: "rain", 13: "rain", 6: "ember", 7: "ember", 12: "ember", 16: "ember", 17: "ash", 18: "ash"}

var theme := "dust"
var particles: CPUParticles2D = null


static func theme_of(floor_no: int) -> String:
	return str(THEMES.get(floor_no, "dust"))


## Odaya ortam efekti ekler (bir kez). Oda yoksa null.
static func attach(room: Room) -> AmbientFx:
	if room == null or room.get_node_or_null("Ambient") != null:
		return null
	var fx := AmbientFx.new()
	fx.name = "Ambient"
	fx.theme = theme_of(room.floor_no)
	room.add_child(fx)
	fx.build(room.rect.size)
	return fx


func build(area: Vector2) -> void:
	var w := maxf(area.x, 400.0)
	var fy := RoomLayouts.FLOOR_Y
	var p := CPUParticles2D.new()
	p.name = "Particles"
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	match theme:
		"rain":
			p.position = Vector2(w * 0.5, -20.0)
			p.emission_rect_extents = Vector2(w * 0.5 + 100.0, 4.0)
			p.amount = clampi(int(w / 18.0), 50, 160)
			p.lifetime = (fy + 20.0) / 900.0
			p.direction = Vector2(-0.15, 1.0)
			p.spread = 3.0
			p.gravity = Vector2.ZERO
			p.initial_velocity_min = 860.0
			p.initial_velocity_max = 940.0
			p.texture = _streak()
			p.scale_amount_min = 0.8
			p.scale_amount_max = 1.3
			p.color = Color(0.7, 0.85, 1.0, 0.4)
			p.preprocess = 1.0
			p.set("particle_flag_align_y", true)
			z_index = 9
		"ember":
			p.position = Vector2(w * 0.5, fy)
			p.emission_rect_extents = Vector2(w * 0.5, 8.0)
			p.amount = clampi(int(w / 45.0), 16, 60)
			p.lifetime = 3.6
			p.direction = Vector2(0.0, -1.0)
			p.spread = 25.0
			p.gravity = Vector2(10.0, -24.0)
			p.initial_velocity_min = 40.0
			p.initial_velocity_max = 120.0
			p.scale_amount_min = 1.6
			p.scale_amount_max = 3.4
			p.color_ramp = _ramp(Color(1.0, 0.8, 0.3, 0.9), Color(1.0, 0.35, 0.1, 0.0), Color(1.0, 0.55, 0.15, 0.8))
			p.preprocess = 3.0
			z_index = 3
		"ash":
			p.position = Vector2(w * 0.5, 120.0)
			p.emission_rect_extents = Vector2(w * 0.5, 120.0)
			p.amount = clampi(int(w / 50.0), 14, 44)
			p.lifetime = 8.0
			p.direction = Vector2(0.25, 1.0)
			p.spread = 20.0
			p.gravity = Vector2.ZERO
			p.initial_velocity_min = 14.0
			p.initial_velocity_max = 40.0
			p.scale_amount_min = 1.5
			p.scale_amount_max = 3.0
			p.color_ramp = _ramp(Color(0.8, 0.75, 0.85, 0.0), Color(0.8, 0.75, 0.85, 0.0), Color(0.8, 0.75, 0.85, 0.4))
			p.preprocess = 7.0
			z_index = 3
		_:
			p.position = Vector2(w * 0.5, fy * 0.5)
			p.emission_rect_extents = Vector2(w * 0.5, fy * 0.5)
			p.amount = clampi(int(w / 60.0), 12, 40)
			p.lifetime = 9.0
			p.direction = Vector2(0.3, -1.0)
			p.spread = 180.0
			p.gravity = Vector2.ZERO
			p.initial_velocity_min = 4.0
			p.initial_velocity_max = 14.0
			p.scale_amount_min = 1.4
			p.scale_amount_max = 3.0
			p.color_ramp = _ramp(Color(1.0, 1.0, 1.0, 0.0), Color(1.0, 1.0, 1.0, 0.0), Color(1.0, 1.0, 1.0, 0.2))
			p.preprocess = 8.0
			z_index = -2
	p.emitting = true
	particles = p
	add_child(p)


## Başta ve sonda saydam, ortada `mid` renginde bir renk geçişi (`start`, `end`: uçlar).
static func _ramp(start: Color, end: Color, mid: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, start)
	g.set_color(1, end)
	g.add_point(0.4, mid)
	return g


static func _streak() -> ImageTexture:
	var img := Image.create(2, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 1.0, 1.0, 1.0))
	return ImageTexture.create_from_image(img)
