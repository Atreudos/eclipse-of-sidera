class_name ConfettiFx
extends CPUParticles2D
## Konfeti patlaması (doğum günü, kutlama). Tek seferlik; bitince kendini siler. Duraklatılmış oyunda (konuşma açıkken) da akar.
## Godot'ta henüz koşulmadı.

const LIFE := 1.7


static func burst(parent: Node, pos: Vector2, count: int = 70) -> void:
	if parent == null:
		return
	var c := ConfettiFx.new()
	c.process_mode = Node.PROCESS_MODE_ALWAYS
	c.z_index = 30
	c.one_shot = true
	c.explosiveness = 0.95
	c.amount = count
	c.lifetime = LIFE
	c.direction = Vector2(0.0, -1.0)
	c.spread = 75.0
	c.gravity = Vector2(0.0, 640.0)
	c.initial_velocity_min = 260.0
	c.initial_velocity_max = 560.0
	c.angular_velocity_min = -540.0
	c.angular_velocity_max = 540.0
	c.damping_min = 30.0
	c.damping_max = 60.0
	c.scale_amount_min = 3.0
	c.scale_amount_max = 6.5
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.35, 0.4))
	g.set_color(1, Color(0.4, 0.85, 1.0))
	g.add_point(0.33, Color(1.0, 0.85, 0.3))
	g.add_point(0.66, Color(0.6, 1.0, 0.5))
	c.color_initial_ramp = g
	parent.add_child(c)
	c.global_position = pos
	c.emitting = true
	var timer := c.get_tree().create_timer(LIFE + 0.8, true)
	timer.timeout.connect(c.queue_free)
