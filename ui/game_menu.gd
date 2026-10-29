class_name GameMenu
extends Control
## Oyunu durduran tam ekran menülerin ortak tabanı (envanter ekranı, F5 deneme menüsü).
## Açılınca `get_tree().paused = true` olur; menü kendi `PROCESS_MODE_ALWAYS` modunda çalışmaya devam eder.
## Aynı anda yalnız bir menü açılabilir (`ItemView.active_menu`).

signal opened
signal closed

var player: Player
var is_open := false

var _msg := ""
var _msg_good := true
var _msg_t := 0.0
var _t := 0.0
var _last_usec := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	visible = false


func _exit_tree() -> void:
	if is_open:
		is_open = false
		if ItemView.active_menu == self:
			ItemView.active_menu = null
		if get_tree() != null:
			get_tree().paused = false


## Menüyü açar ve oyunu durdurur. Açılamazsa (oyuncu ölü, başka menü açık) false.
func open(p: Player) -> bool:
	if is_open or p == null or not is_instance_valid(p) or p.dead:
		return false
	if ItemView.active_menu != null:
		return false
	player = p
	is_open = true
	ItemView.active_menu = self
	visible = true
	get_tree().paused = true
	_msg = ""
	_msg_t = 0.0
	_on_open()
	Sfx.play("ui_select", -4.0)
	opened.emit()
	queue_redraw()
	return true


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	if ItemView.active_menu == self:
		ItemView.active_menu = null
	get_tree().paused = false
	Sfx.play("ui_move", -6.0)
	closed.emit()


## Alt sınıflar açılışta kendi durumlarını kurar (imleç, kutular...).
func _on_open() -> void:
	pass


func _find_player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func _say(text: String, good: bool) -> void:
	_msg = text
	_msg_good = good
	_msg_t = 2.2


## Son mesajı `center` noktasında yazar (süre bitince soluklaşır). Boşsa bir şey çizmez.
## `max_width` verilirse mesaj o genişliğe sığana kadar küçülür.
func _draw_message(center: Vector2, max_width: float = 0.0) -> void:
	if _msg_t > 0.0 and _msg != "":
		var a := minf(_msg_t / 0.4, 1.0)
		var size := 24
		while max_width > 0.0 and size > 14 and GameFont.width(_msg, size) > max_width:
			size -= 2
		GameFont.draw_centered(self, _msg, center, size, Color(ItemView.GOOD if _msg_good else ItemView.BAD, a))


func _w() -> float:
	return size.x if size.x > 1.0 else 1280.0


func _h() -> float:
	return size.y if size.y > 1.0 else 720.0


func _process(_delta: float) -> void:
	if not is_open:
		return
	var now := Time.get_ticks_usec()
	var dt := 0.0
	if _last_usec != 0:
		dt = clampf(float(now - _last_usec) / 1000000.0, 0.0, 0.05)
	_last_usec = now
	_t += dt
	_msg_t = maxf(_msg_t - dt, 0.0)
	queue_redraw()
