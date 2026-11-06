class_name FloorExit
extends Node2D
## Kat geçidi: katın SON odasının (Gölge odası) sonunda, sağ uçtaki duvara yakın durur (basamaklı bir iniş / kapı).
## Oda temizlenene kadar kapalı (ızgara), temizlenince açılır. Oyuncu açık geçidin içine YÜRÜYÜNCE (ya da başında E'ye basınca)
## `used` sinyali gelir; koşu denetleyicisi ekranı karartır ve yeni katın lobisini kurar.
##
## Orijin = geçidin zemindeki orta noktası. Koddan çizilir (yer tutucu); `exit_closed` / `exit_opening` / `exit_open`
## çizimleri gelince onlar kullanılır.

signal used(floor_exit: FloorExit)

enum State { CLOSED, OPENING, OPEN }

const SIZE := Vector2(128.0, 192.0)
const RANGE_X := 84.0
const RANGE_Y := 170.0
## Geçidin içine bu kadar yaklaşıp HOLD_TIME sn durursan (yürüyerek) geçilmiş sayılır.
const WALK_IN_X := 40.0
const HOLD_TIME := 0.2
## `exit_opening` çizimi ve ızgaranın kalkma süresi.
const OPEN_TIME := 0.8

var state: State = State.CLOSED
## Geçidin götürdüğü kat (üstünde "KAT 2" yazar).
var next_floor := 2
var accent := Color(0.95, 0.78, 0.3)
var in_range := false

var _t := 0.0
var _open_t := 0.0
var _hold := 0.0
var _used := false
var _player: Player


func _ready() -> void:
	z_index = -3
	add_to_group("floor_exits")
	_hook_player()


func _exit_tree() -> void:
	if _player != null and is_instance_valid(_player) and _player.interacted.is_connected(_on_interacted):
		_player.interacted.disconnect(_on_interacted)


func is_open() -> bool:
	return state == State.OPEN


## Geçidi açar (oda temizlendi). Açılma çizimi OPEN_TIME sn sürer; açılırken de kullanılamaz.
func open_up() -> void:
	if state != State.CLOSED:
		return
	state = State.OPENING
	_open_t = 0.0
	Sfx.play("door_open", -2.0, 0.8)


## Oyuncu geçidin başındaysa ve geçit açıksa kullanır. Kullanıldıysa true (bir geçit yalnız bir kez kullanılır).
func try_use() -> bool:
	if state != State.OPEN or not in_range or _used:
		return false
	_used = true
	used.emit(self)
	return true


func _hook_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player != null and not _player.interacted.is_connected(_on_interacted):
		_player.interacted.connect(_on_interacted)


func _on_interacted() -> void:
	try_use()


func _process(delta: float) -> void:
	_t += delta
	if state == State.OPENING:
		_open_t += delta
		if _open_t >= OPEN_TIME:
			state = State.OPEN
	if _player == null or not is_instance_valid(_player):
		_hook_player()
	in_range = false
	var walking_in := false
	if _player != null and is_instance_valid(_player) and not _player.dead:
		var d := _player.global_position - global_position
		in_range = absf(d.x) <= RANGE_X and absf(d.y) <= RANGE_Y
		walking_in = absf(d.x) <= WALK_IN_X and absf(d.y) <= RANGE_Y
	if state == State.OPEN and walking_in and not _used:
		_hold += delta
		if _hold >= HOLD_TIME:
			try_use()
	else:
		_hold = 0.0
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(-SIZE.x * 0.5, -SIZE.y, SIZE.x, SIZE.y)
	var file := "exit_closed"
	var art_t := _t
	if state == State.OPENING:
		file = "exit_opening"
		art_t = _open_t
	elif state == State.OPEN:
		file = "exit_open"
	if not Art.draw(self, file, rect, art_t):
		_draw_placeholder(rect)
	var label_col := GameFont.YELLOW if state == State.OPEN else Color(0.72, 0.66, 0.8)
	GameFont.draw_runs_centered(self, [["KAT ", label_col], [str(next_floor), label_col]], Vector2(0.0, rect.position.y - 24.0), 24)
	if state == State.OPEN and not _used:
		var pulse := 0.7 + 0.3 * sin(_t * 6.0)
		GameFont.draw_runs_centered(self, [["KATI GEÇ", GameFont.WHITE]], Vector2(0.0, rect.position.y - 56.0), 22, pulse)


## Yer tutucu: çerçeveli, basamakla aşağı inen bir geçit.
func _draw_placeholder(rect: Rect2) -> void:
	var frame := Color(accent.r * 0.3, accent.g * 0.3, accent.b * 0.3)
	var inner := Rect2(rect.position + Vector2(18.0, 16.0), rect.size - Vector2(36.0, 16.0))
	draw_rect(rect, frame)
	draw_rect(inner, Color(0.02, 0.015, 0.04))
	# Aşağı inen basamaklar: gittikçe daralan şeritler
	for i in 6:
		var inset := 10.0 + 7.0 * float(i)
		var y := inner.position.y + 46.0 + 24.0 * float(i)
		draw_rect(Rect2(inner.position.x + inset, y, inner.size.x - inset * 2.0, 5.0), Color(0.2, 0.17, 0.26))
		draw_rect(Rect2(inner.position.x + inset, y + 5.0, inner.size.x - inset * 2.0, 3.0), Color(0.08, 0.06, 0.12))
	var glow := Color(0.9, 0.2, 0.28, 0.8)
	if state == State.OPEN:
		glow = Color(accent, 0.55 + 0.35 * (0.5 + 0.5 * sin(_t * 5.0)))
		draw_rect(inner, Color(accent, 0.1 + 0.06 * sin(_t * 4.0)))
		_draw_chevrons(inner)
	elif state == State.OPENING:
		glow = Color(accent, 0.6)
	# Işık çizgileri iç kenarlarda
	draw_rect(Rect2(inner.position.x, inner.position.y, 4.0, inner.size.y), glow)
	draw_rect(Rect2(inner.end.x - 4.0, inner.position.y, 4.0, inner.size.y), glow)
	draw_rect(Rect2(inner.position.x, inner.position.y, inner.size.x, 4.0), glow)
	# Izgara: kapalıyken tamamen iner, açılırken yukarı kalkar
	var grate_k := 1.0
	if state == State.OPENING:
		grate_k = 1.0 - clampf(_open_t / OPEN_TIME, 0.0, 1.0)
	elif state == State.OPEN:
		grate_k = 0.0
	if grate_k > 0.0:
		var gh := inner.size.y * grate_k
		draw_rect(Rect2(inner.position, Vector2(inner.size.x, gh)), Color(0.1, 0.05, 0.08, 0.55))
		var x := inner.position.x + 10.0
		while x < inner.end.x - 6.0:
			draw_rect(Rect2(x, inner.position.y, 4.0, gh), Color(0.42, 0.16, 0.2))
			x += 15.0
		draw_rect(Rect2(inner.position.x, inner.position.y + gh - 5.0, inner.size.x, 5.0), Color(0.42, 0.16, 0.2))


## Açıkken içeride aşağı akan oklar: "in".
func _draw_chevrons(inner: Rect2) -> void:
	var cx := inner.get_center().x
	for i in 3:
		var phase := fposmod(_t * 1.3 - float(i) * 0.28, 1.0)
		var cy := inner.position.y + 30.0 + phase * (inner.size.y - 60.0)
		var a := sin(phase * PI)
		var pts := PackedVector2Array([Vector2(cx - 14.0, cy - 8.0), Vector2(cx, cy + 8.0), Vector2(cx + 14.0, cy - 8.0)])
		draw_polyline(pts, Color(0.05, 0.03, 0.09, a * 0.8), 9.0, true)
		draw_polyline(pts, Color(GameFont.YELLOW, a), 5.0, true)
