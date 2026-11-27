class_name DustFx
extends CPUParticles2D
## Toz bulutu: iniş, zıplama, dash başlangıcı. Tek seferlik; bitince kendini siler. Godot'ta henüz koşulmadı.


## `pos`'ta küçük toz fışkırtır. `dir`: yatay yön (-1/0/+1; 0 = iki yana), `power`: 0..1.
static func puff(parent: Node, pos: Vector2, dir: float = 0.0, power: float = 0.5, tint: Color = Color(0.85, 0.82, 0.78, 0.55)) -> void:
	if parent == null:
		return
	var d := DustFx.new()
	d.z_index = 4
	d.one_shot = true
	d.explosiveness = 0.9
	d.amount = 5 + int(round(8.0 * clampf(power, 0.0, 1.0)))
	d.lifetime = 0.45 + 0.25 * power
	d.direction = Vector2(dir, -0.35) if absf(dir) > 0.1 else Vector2(0.0, -1.0)
	d.spread = 50.0 if absf(dir) > 0.1 else 85.0
	d.gravity = Vector2(0.0, -30.0)
	d.initial_velocity_min = 30.0 + 40.0 * power
	d.initial_velocity_max = 90.0 + 90.0 * power
	d.damping_min = 90.0
	d.damping_max = 160.0
	d.scale_amount_min = 3.0
	d.scale_amount_max = 6.0 + 4.0 * power
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	d.scale_amount_curve = curve
	d.color = tint
	parent.add_child(d)
	d.global_position = pos
	d.emitting = true
	var timer := d.get_tree().create_timer(d.lifetime + 0.4)
	timer.timeout.connect(d.queue_free)
