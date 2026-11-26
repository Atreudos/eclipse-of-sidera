class_name Launcher
extends Node2D
## Fırlatıcı: üstüne basan oyuncuyu yukarı fırlatır (parkurlarda yüksek platformlara çıkmak için).
## Orijin = zeminin üstündeki orta nokta. Çizim: `launcher` (yoksa yer tutucu yay).

const POWER := 1250.0
const RANGE_X := 46.0
const COOLDOWN := 0.45

var _t := 0.0
var _cool := 0.0
var _pulse := 0.0
var _player: Player


func _ready() -> void:
	z_index = -1
	add_to_group("launchers")


func _physics_process(delta: float) -> void:
	_t += delta
	_cool = maxf(_cool - delta, 0.0)
	_pulse = maxf(_pulse - delta * 3.0, 0.0)
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
		return
	if _player.dead or _cool > 0.0:
		return
	var d := _player.global_position - global_position
	if absf(d.x) <= RANGE_X and d.y > -40.0 and d.y < 16.0 and _player.velocity.y >= -50.0:
		_player.velocity.y = -POWER
		_cool = COOLDOWN
		_pulse = 1.0
		Sfx.play("spawn", -4.0, 1.4)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if Art.draw(self, "launcher", Rect2(-40.0, -40.0, 80.0, 40.0), _t):
		return
	var c := Color(0.45, 0.95, 0.7)
	var squash := 6.0 * _pulse
	draw_rect(Rect2(-36.0, -14.0 + squash, 72.0, 14.0 - squash), c.darkened(0.5))
	draw_rect(Rect2(-36.0, -14.0 + squash, 72.0, 14.0 - squash), c, false, 2.0)
	for i in 3:
		var y := -26.0 - 8.0 * float(i) - 6.0 * sin(_t * 6.0 + float(i))
		draw_polyline(PackedVector2Array([Vector2(-12, y + 8), Vector2(0, y), Vector2(12, y + 8)]), Color(c, 0.9 - 0.25 * float(i)), 2.0)
