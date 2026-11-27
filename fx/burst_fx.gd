class_name BurstFx
extends CPUParticles2D
## Dairesel kıvılcım patlaması (düşman ölümü, ödül). Tek seferlik; bitince kendini siler. Godot'ta henüz koşulmadı.


## `pos`'ta `count` kıvılcım saçar. `speed`: en yüksek hız (px/sn).
static func spawn(parent: Node, pos: Vector2, tint: Color = Color(1.0, 0.9, 0.7), count: int = 14, speed: float = 340.0) -> void:
	if parent == null:
		return
	var b := BurstFx.new()
	b.z_index = 22
	b.one_shot = true
	b.explosiveness = 1.0
	b.amount = clampi(count, 4, 60)
	b.lifetime = 0.55
	b.direction = Vector2(0.0, -1.0)
	b.spread = 180.0
	b.gravity = Vector2(0.0, 520.0)
	b.initial_velocity_min = speed * 0.35
	b.initial_velocity_max = speed
	b.damping_min = 40.0
	b.damping_max = 90.0
	b.scale_amount_min = 2.5
	b.scale_amount_max = 5.0
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	b.scale_amount_curve = curve
	b.color = tint
	parent.add_child(b)
	b.global_position = pos
	b.emitting = true
	var timer := b.get_tree().create_timer(b.lifetime + 0.4)
	timer.timeout.connect(b.queue_free)
