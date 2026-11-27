class_name BlackoutEvent
extends CanvasLayer
## Kat sonu olayı: ışıklar söner; yalnız oyuncunun çevresi görünür. Karanlıkta üç antika para saklıdır (yalnız yakınken görünür).
## HUD'ın altında (katman 9) bir örtü çizer. Süre bitince açılır ve kendini siler. Godot'ta henüz koşulmadı.

signal finished

const DURATION := 14.0
const FADE := 1.2
const RADIUS := 250.0
const DARK := 0.96
const HIDDEN_COINS := 3

var room: Room
var running := false

var _t := 0.0
var _ctl: Control
var _tex: GradientTexture2D
var _player: Player


## `r`: olayın geçtiği oda (odadan çıkılırsa ışık hemen geri gelir).
func start(r: Room) -> void:
	room = r
	layer = 9
	_ctl = Control.new()
	_ctl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ctl.draw.connect(_draw_dark)
	add_child(_ctl)
	var g := Gradient.new()
	g.set_color(0, Color(0.0, 0.0, 0.0, 0.0))
	g.set_color(1, Color(0.0, 0.0, 0.0, DARK))
	g.add_point(0.5, Color(0.0, 0.0, 0.0, 0.12))
	_tex = GradientTexture2D.new()
	_tex.gradient = g
	_tex.fill = GradientTexture2D.FILL_RADIAL
	_tex.fill_from = Vector2(0.5, 0.5)
	_tex.fill_to = Vector2(1.0, 0.5)
	_tex.width = 256
	_tex.height = 256
	_hide_coins()
	running = true
	Sfx.play("door_open", -4.0, 0.4)


func _hide_coins() -> void:
	if room == null or not is_instance_valid(room):
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in HIDDEN_COINS:
		var c := Coin.new()
		c.antique = true
		c.value = Coin.ANTIQUE_VALUE
		room.add_child(c)
		var x := room.rect.position.x + rng.randf_range(300.0, room.rect.size.x - 300.0)
		c.global_position = Vector2(x, room.rect.position.y + 480.0)


func _alpha() -> float:
	var left := DURATION - _t
	return clampf(minf(_t / FADE, left / FADE), 0.0, 1.0)


func _process(delta: float) -> void:
	if not running:
		return
	_t += delta
	if room == null or not is_instance_valid(room) or (_player != null and is_instance_valid(_player) and _player.dead):
		_t = maxf(_t, DURATION - FADE)
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	if _t >= DURATION:
		running = false
		finished.emit()
		queue_free()
		return
	if _ctl != null:
		_ctl.queue_redraw()


func _draw_dark() -> void:
	var a := _alpha()
	if a <= 0.0 or _ctl == null:
		return
	var vs := get_viewport().get_visible_rect().size
	var c := vs * 0.5
	if _player != null and is_instance_valid(_player):
		c = get_viewport().get_canvas_transform() * _player.global_position
	var r := RADIUS * (1.0 + 0.04 * sin(_t * 7.0) * sin(_t * 3.1))
	var black := Color(0.0, 0.0, 0.0, DARK * a)
	var x0 := c.x - r
	var x1 := c.x + r
	var y0 := c.y - r
	var y1 := c.y + r
	if y0 > 0.0:
		_ctl.draw_rect(Rect2(0.0, 0.0, vs.x, y0), black)
	if y1 < vs.y:
		_ctl.draw_rect(Rect2(0.0, y1, vs.x, vs.y - y1), black)
	var top := maxf(y0, 0.0)
	var bottom := minf(y1, vs.y)
	if x0 > 0.0 and bottom > top:
		_ctl.draw_rect(Rect2(0.0, top, x0, bottom - top), black)
	if x1 < vs.x and bottom > top:
		_ctl.draw_rect(Rect2(x1, top, vs.x - x1, bottom - top), black)
	_ctl.draw_texture_rect(_tex, Rect2(x0, y0, r * 2.0, r * 2.0), false, Color(1.0, 1.0, 1.0, a))
