class_name Announcer
extends Control
## Ekranın üstünde kısa süre görünen büyük duyurular ("ODA TEMİZ", "ODA 3"). AGENTORANGE fontuyla çizilir.
## Gerçek zamanla akar (hitstop sırasında da düzgün görünür). Üst üste gelenler alt alta dizilir.
##   push("ODA TEMİZ", GameFont.YELLOW, 58)
##   push_runs([["ODA ", GameFont.WHITE], ["3", GameFont.YELLOW]], 58)

const POP_TIME := 0.22
const FADE_TIME := 0.45

var _items: Array[Dictionary] = []
var _last_usec := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	process_mode = Node.PROCESS_MODE_ALWAYS


## Tek renkli duyuru. life: ekranda kalma süresi (sn).
func push(text: String, color: Color = GameFont.YELLOW, size: int = 56, life: float = 1.8) -> void:
	push_runs([[text, color]], size, life)


## Renkli parçalardan oluşan duyuru: [[yazı, renk], ...]
func push_runs(runs: Array, size: int = 56, life: float = 1.8) -> void:
	_items.append({"runs": runs, "size": size, "life": life, "age": 0.0})
	if _items.size() > 4:
		_items.pop_front()
	queue_redraw()


func count() -> int:
	return _items.size()


func clear() -> void:
	_items.clear()
	queue_redraw()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := 0.0
	if _last_usec != 0:
		dt = clampf(float(now - _last_usec) / 1000000.0, 0.0, 0.05)
	_last_usec = now
	if _items.is_empty():
		return
	for it in _items:
		it["age"] = float(it["age"]) + dt
	_items = _items.filter(func(it: Dictionary) -> bool: return float(it["age"]) < float(it["life"]))
	queue_redraw()


func _draw() -> void:
	var y := 168.0
	for it in _items:
		var age: float = it["age"]
		var life: float = it["life"]
		var size: int = it["size"]
		# Pat diye büyür, yerine oturur; sonunda söner.
		var pop := clampf(age / POP_TIME, 0.0, 1.0)
		var overshoot := 1.0 + 0.45 * pow(1.0 - pop, 2.0) * (1.0 if pop < 1.0 else 0.0)
		var scale_k := lerpf(0.35, 1.0, 1.0 - pow(1.0 - pop, 3.0)) * overshoot
		var alpha := clampf((life - age) / FADE_TIME, 0.0, 1.0)
		var center := Vector2(size_x() * 0.5, y)
		draw_set_transform(center, 0.0, Vector2(scale_k, scale_k))
		GameFont.draw_runs_centered(self, it["runs"], Vector2.ZERO, size, alpha)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		y += float(size) * 1.15


func size_x() -> float:
	return size.x if size.x > 1.0 else 1280.0
