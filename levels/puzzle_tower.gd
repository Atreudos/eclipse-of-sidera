class_name PuzzleTower
extends Node2D
## Bulmaca kulesi: oyuncu menzildeyken belli aralıkla yatay yönde ALTIN (parry'lenebilir) mermi atar.
## Parry'lenen mermi kuleye döner; kule ile oyuncu arasındaki kristal onu yakalar. Atıştan önce kısa bir parlama uyarısı verir.
## Orijin = merminin çıktığı yükseklik. Çizim: `puzzle_tower` (yoksa yer tutucu).

const PROJECTILE := preload("res://combat/projectile.tscn")
const TELEGRAPH := 0.55
const SPEED := 330.0
const RANGE_X := 760.0

## +1 sağa, -1 sola atar.
var dir := -1
var interval := 3.0
var active := false
## Atışlar arası beklemeye eklenen başlangıç gecikmesi (iki kule aynı anda atmasın).
var phase := 0.0
var shots := 0

var _t := 0.0
var _timer := 0.0
var _tell := 0.0


func _ready() -> void:
	z_index = -1
	add_to_group("puzzle_towers")
	_timer = interval + phase


func _process(delta: float) -> void:
	_t += delta
	if TimeStop.active:
		return
	if not active:
		_tell = 0.0
		_timer = maxf(_timer, 1.0)  # menzile girince hemen sıkıştırmasın
		queue_redraw()
		return
	_timer -= delta
	if _timer <= TELEGRAPH:
		_tell = clampf(1.0 - _timer / TELEGRAPH, 0.0, 1.0)
	if _timer <= 0.0:
		fire()
		_timer = interval
		_tell = 0.0
	queue_redraw()


## Bir altın mermi atar (testler de çağırır).
func fire() -> Projectile:
	var p := PROJECTILE.instantiate() as Projectile
	get_parent().add_child(p)
	p.global_position = global_position + Vector2(float(dir) * 26.0, 0.0)
	p.launch(Vector2(float(dir) * SPEED, 0.0), true, self, 1)
	p.lifetime = 4.0
	shots += 1
	Sfx.play("shoot", -4.0, 0.9)
	return p


func _draw() -> void:
	if not Art.draw(self, "puzzle_tower", Rect2(-48.0, -64.0, 96.0, 128.0), _t):
		draw_rect(Rect2(-18.0, -4.0, 36.0, 64.0), Color(0.16, 0.12, 0.2))
		draw_rect(Rect2(-18.0, -4.0, 36.0, 64.0), Color(1.0, 0.76, 0.38, 0.6), false, 2.0)
		var glow := 0.25 + 0.75 * _tell
		draw_circle(Vector2.ZERO, 16.0, Color(1.0, 0.8, 0.2, 0.4 + 0.5 * glow))
		draw_circle(Vector2.ZERO, 7.0, Color(1, 1, 1, 0.9))
		draw_circle(Vector2.ZERO, 16.0 + 14.0 * _tell, Color(1.0, 0.8, 0.2, 0.15 * _tell))
		draw_line(Vector2.ZERO, Vector2(float(dir) * 30.0, 0.0), Color(1.0, 0.8, 0.2, 0.7), 4.0)
