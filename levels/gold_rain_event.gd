class_name GoldRainEvent
extends Node2D
## Kat sonu olayı: Gölge ödülü alınınca tavandan kısa süre altın yağar. Paralar gerçektir (Coin), toplamak oyuncunun işi.
## Oda düğümünün çocuğu olarak eklenir. Godot'ta henüz koşulmadı.

const DURATION := 5.0
const INTERVAL := 0.2
const MARGIN := 90.0
## Antika (3 altın) para olasılığı.
const ANTIQUE_CHANCE := 0.12

var room: Room
var running := false
var dropped := 0

var _t := 0.0
var _next := 0.0
var _rng := RandomNumberGenerator.new()


func start(r: Room) -> void:
	room = r
	_rng.randomize()
	running = true
	Sfx.play("coin", -3.0, 0.7)


func _physics_process(delta: float) -> void:
	if not running:
		return
	if room == null or not is_instance_valid(room):
		queue_free()
		return
	_t += delta
	_next -= delta
	while _next <= 0.0 and _t < DURATION:
		_next += INTERVAL
		_drop_one()
	if _t >= DURATION + 0.3:
		running = false
		queue_free()


func _drop_one() -> void:
	var c := Coin.new()
	c.antique = _rng.randf() < ANTIQUE_CHANCE
	c.value = Coin.ANTIQUE_VALUE if c.antique else Coin.SMALL_VALUE
	c.velocity = Vector2(_rng.randf_range(-30.0, 30.0), 60.0)
	room.add_child(c)
	var x := room.rect.position.x + _rng.randf_range(MARGIN, room.rect.size.x - MARGIN)
	c.global_position = Vector2(x, room.rect.position.y + 24.0)
	dropped += 1
