class_name BalanceOrb
extends Projectile
## Libra'nın altın "denge küresi". Parry'lenince normal mermi gibi sahibine döner (hasar x2) VE en yakın diğer düşmana
## aynı hasar ve hızla bir kopyası gider: terazinin diğer kefesi.

var _is_copy := false


func _on_parried(by: Node) -> void:
	var from := global_position
	var origin_source := original_source
	super._on_parried(by)
	if _is_copy:
		return
	var best: Node2D = null
	var best_d := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Node2D
		if en == null or en == origin_source or (en is ActorBase and (en as ActorBase).dead):
			continue
		var d := from.distance_to(en.global_position)
		if d < best_d:
			best_d = d
			best = en
	if best == null:
		return
	var twin := (load("res://combat/balance_orb.tscn") as PackedScene).instantiate() as BalanceOrb
	twin._is_copy = true
	get_parent().add_child(twin)
	twin.global_position = from
	twin.launch((best.global_position + Vector2(0.0, -10.0) - from).normalized() * velocity.length(), false, by, damage)
	twin.set_faction("player")
	twin.radius = radius
	RingFx.spawn(get_parent(), from, Color(PARRIED, 0.9), 6.0, 44.0, 0.3)


func _draw() -> void:
	# fx_balance_orb çizimi varsa o (parry'lenince mavi-camgöbeği tonla); yoksa mermi + iki kefe.
	var sz := radius * 4.8
	var tone := Color(0.6, 1.0, 1.0) if faction == "player" else Color.WHITE
	if Art.draw(self, "fx_balance_orb", Rect2(-sz * 0.5, -sz * 0.5, sz, sz), _age_for_art(), tone):
		return
	super._draw()
	# İki kefe: küçük yan toplar (terazi)
	var c := PARRIED if faction == "player" else GOLD
	draw_circle(Vector2(0.0, -radius * 1.5), radius * 0.4, Color(c, 0.9))
	draw_circle(Vector2(0.0, radius * 1.5), radius * 0.4, Color(c, 0.9))
	draw_line(Vector2(0.0, -radius * 1.5), Vector2(0.0, radius * 1.5), Color(c, 0.5), 2.0)


func _age_for_art() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
