class_name Door
extends Node2D
## Odalar arasındaki kapı. Kapalıyken duvar gibi durur (oyuncu ve düşmanlar geçemez),
## açılınca yukarı kayar. Başlangıç noktası (origin) = kapının orta hattı = iki oda arasındaki sınır.
##
## Görünüm (look):
##   LOCKED = kırmızı çizgi (oda savaşı sürüyor),  OPEN = altın, oklar sağa akar (geç!),
##   SEALED = soluk (arkanda kaldı).

signal opened
signal closed

enum Look { LOCKED, OPEN, SEALED }

const WIDTH := 36.0
const HEIGHT := 640.0
const OPEN_SPEED := 1.6
const CLOSE_SPEED := 6.0

var accent := Color(0.95, 0.78, 0.3)
var look: Look = Look.LOCKED
var is_open := false

var _slide := 0.0
var _t := 0.0
var _was_closing := false
var _shape: CollisionShape2D


func _ready() -> void:
	z_index = 5
	var body := StaticBody2D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	_shape = CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(WIDTH, 1400.0)
	_shape.shape = rs
	_shape.position = Vector2(0.0, 300.0)
	body.add_child(_shape)
	add_child(body)


## Kapıyı açar (oda temizlendi).
func open() -> void:
	if is_open:
		return
	is_open = true
	look = Look.OPEN
	_shape.set_deferred("disabled", true)
	Sfx.play("door_open", -3.0)
	opened.emit()


## Kapıyı kapatır (oyuncu odaya girdi, kapı arkasından kapanır). `sealed`: arkada kalan kapı görünümü.
func close(sealed: bool = true) -> void:
	look = Look.SEALED if sealed else Look.LOCKED
	if not is_open:
		return
	is_open = false
	_shape.set_deferred("disabled", false)
	_was_closing = true
	closed.emit()


## Kapı şu an yolu kapatıyor mu?
func is_blocking() -> bool:
	return _shape != null and not _shape.disabled


## 0 = tamamen kapalı, 1 = tamamen açık.
func slide() -> float:
	return _slide


func _process(delta: float) -> void:
	_t += delta
	var target := 1.0 if is_open else 0.0
	var speed := OPEN_SPEED if is_open else CLOSE_SPEED
	_slide = move_toward(_slide, target, speed * delta)
	if _was_closing and _slide <= 0.0:
		# Levha yere çakıldı.
		_was_closing = false
		Sfx.play("door_slam", 0.0, 1.0, 0.04)
		EventBus.screen_shake.emit(8.0, 0.28)
		EventBus.camera_kick.emit(Vector2(0.0, 1.0), 6.0)
		RingFx.spawn(get_parent(), global_position + Vector2(0.0, HEIGHT - 6.0), Color(1, 1, 1, 0.5), 8.0, 70.0, 0.25)
	queue_redraw()


func _draw() -> void:
	var half := WIDTH * 0.5
	var frame := Color(accent.r * 0.28, accent.g * 0.28, accent.b * 0.28, 1.0)
	# Çerçeve sütunları: levha kalksa da kapının yeri belli olur.
	draw_rect(Rect2(-half - 12.0, 0.0, 12.0, HEIGHT), frame)
	draw_rect(Rect2(half, 0.0, 12.0, HEIGHT), frame)
	var glow := Color(0.9, 0.2, 0.28, 0.85)
	match look:
		Look.OPEN:
			glow = Color(accent, 0.55 + 0.4 * (0.5 + 0.5 * sin(_t * 5.0)))
		Look.SEALED:
			glow = Color(0.45, 0.4, 0.5, 0.35)
	# Işık çizgisi çerçevelerde
	draw_rect(Rect2(-half - 4.0, 0.0, 4.0, HEIGHT), Color(glow, glow.a * 0.7))
	draw_rect(Rect2(half, 0.0, 4.0, HEIGHT), Color(glow, glow.a * 0.7))
	if _slide < 1.0:
		var y := -_slide * (HEIGHT + 24.0)
		draw_rect(Rect2(-half, y, WIDTH, HEIGHT), Color(0.12, 0.1, 0.15, 1.0))
		# Levha üstündeki yatay oluklar ve orta ışık çizgisi
		var gy := 36.0
		while gy < HEIGHT:
			draw_rect(Rect2(-half, y + gy, WIDTH, 3.0), Color(0.07, 0.06, 0.09, 1.0))
			gy += 64.0
		draw_rect(Rect2(-2.5, y, 5.0, HEIGHT), glow)
	if look == Look.OPEN and _slide >= 0.6:
		_draw_arrows()


## Sağa akan oklar: "bu yönde ilerle".
func _draw_arrows() -> void:
	var half := WIDTH * 0.5
	for i in 3:
		var phase := sin(_t * 6.0 - float(i) * 0.9)
		var a := 0.25 + 0.75 * maxf(phase, 0.0)
		var cx := half + 46.0 + float(i) * 30.0
		var cy := HEIGHT - 80.0
		var pts := PackedVector2Array([Vector2(cx - 9.0, cy - 17.0), Vector2(cx + 9.0, cy), Vector2(cx - 9.0, cy + 17.0)])
		draw_polyline(pts, Color(accent, a), 6.0, true)
