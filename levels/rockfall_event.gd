class_name RockfallEvent
extends Node2D
## Kat sonu olayı: tavan çatlar, taşlar düşer. Her taşın düşeceği yer önce zeminde kırmızı bir uyarıyla görünür (WARN sn),
## sonra taş iner. Altında kalırsan 1 can gidersin. Süre bitince biter; geçit baştan açıktır, koşup çıkabilirsin.
## Oda düğümünün çocuğu olarak eklenir; yerel koordinat = oda koordinatı. Godot'ta henüz koşulmadı.

const DURATION := 16.0
const WARN := 0.8
const FALL := 0.22
const LINGER := 0.5
const HIT_HALF := 34.0
const MARGIN := 80.0

var room: Room
var running := false
var impacts := 0

var _t := 0.0
var _next := 1.2
var _rocks: Array = []
var _player: Player
var _rng := RandomNumberGenerator.new()


func start(r: Room) -> void:
	room = r
	z_index = 6
	_rng.randomize()
	running = true
	Sfx.play("door_open", -3.0, 0.5)
	EventBus.screen_shake.emit(7.0, 0.8)


func _physics_process(delta: float) -> void:
	if not running:
		return
	if room == null or not is_instance_valid(room):
		queue_free()
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	_t += delta
	if _t < DURATION:
		_next -= delta
		if _next <= 0.0:
			_spawn_rock()
			_next = maxf(0.95 - _t * 0.03, 0.5)
	var i := _rocks.size() - 1
	while i >= 0:
		var rk: Dictionary = _rocks[i]
		rk["age"] = float(rk["age"]) + delta
		var age := float(rk["age"])
		if not bool(rk["hit"]) and age >= WARN + FALL:
			rk["hit"] = true
			_impact(float(rk["x"]))
		if age >= WARN + FALL + LINGER:
			_rocks.remove_at(i)
		i -= 1
	if _t >= DURATION and _rocks.is_empty():
		running = false
		queue_free()


func _process(_delta: float) -> void:
	if running:
		queue_redraw()


func _spawn_rock() -> void:
	var w := room.rect.size.x
	var px := w * 0.5
	if _player != null and is_instance_valid(_player):
		px = room.to_local(_player.global_position).x
	var x := clampf(px + _rng.randf_range(-260.0, 260.0), MARGIN, w - MARGIN)
	_rocks.append({"x": x, "age": 0.0, "hit": false, "seed": _rng.randf()})
	Sfx.play("hit", -14.0, 0.4, 0.05)


func _impact(x: float) -> void:
	impacts += 1
	var spot := room.to_global(Vector2(x, RoomLayouts.FLOOR_Y))
	RingFx.spawn(room, spot, Color(0.85, 0.75, 0.6, 0.9), 6.0, 74.0, 0.3)
	EventBus.screen_shake.emit(6.0, 0.18)
	Sfx.play("hit", -6.0, 0.5, 0.05)
	if _player == null or not is_instance_valid(_player) or _player.dead:
		return
	var pl := room.to_local(_player.global_position)
	if absf(pl.x - x) <= HIT_HALF and _player.feet_y() > RoomLayouts.FLOOR_Y - 120.0:
		_player.take_damage(1, null)


func _draw() -> void:
	var fy := RoomLayouts.FLOOR_Y
	for rk in _rocks:
		var d: Dictionary = rk
		var x := float(d["x"])
		var age := float(d["age"])
		if age < WARN:
			var k := age / WARN
			var pulse := 0.5 + 0.5 * sin(age * 22.0)
			var a := (0.35 + 0.45 * pulse) * (0.5 + 0.5 * k)
			var half := 28.0 + 10.0 * k
			draw_colored_polygon(PackedVector2Array([Vector2(x - half, fy), Vector2(x + half, fy), Vector2(x, fy - 26.0)]), Color(1.0, 0.25, 0.2, a))
			draw_line(Vector2(x, fy - 30.0), Vector2(x, fy - 140.0), Color(1.0, 0.3, 0.25, a * 0.5), 2.0)
		elif age < WARN + FALL:
			var k := (age - WARN) / FALL
			var y := lerpf(-70.0, fy - 22.0, k * k)
			_draw_rock(Vector2(x, y), float(d["seed"]), 1.0)
		else:
			var k := (age - WARN - FALL) / LINGER
			var s := float(d["seed"])
			for j in 5:
				var ang := -PI * (0.15 + 0.7 * float(j) / 4.0)
				var dist := 46.0 * k
				var p := Vector2(x + cos(ang) * dist * (1.0 + s * 0.4), fy - 6.0 + sin(ang) * dist * 1.1 + 40.0 * k * k)
				draw_circle(p, 5.0 - 3.0 * k, Color(0.5, 0.42, 0.36, 1.0 - k))


func _draw_rock(c: Vector2, seed_value: float, scale_f: float) -> void:
	var pts := PackedVector2Array()
	for i in 7:
		var ang := TAU * float(i) / 7.0
		var r := (22.0 + 7.0 * sin(float(i) * 2.3 + seed_value * 9.0)) * scale_f
		pts.append(c + Vector2(cos(ang) * r, sin(ang) * r * 0.9))
	draw_colored_polygon(pts, Color(0.34, 0.29, 0.27))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.16, 0.13, 0.13), 3.0)
	draw_circle(c + Vector2(-7.0, -8.0), 5.0, Color(0.5, 0.44, 0.4))
