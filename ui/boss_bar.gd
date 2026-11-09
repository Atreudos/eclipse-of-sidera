class_name BossBar
extends Control
## Ekranın üstündeki patron (Gölge) can barı: ad + kat, can dolgusu, hasarda geriden sönen "hayalet" şerit,
## öfke evresinde kırmızıya döner, gerçek dövüşte (18. kat) yarıda bir çentik taşır. Gölge belirince `EventBus.boss_spawned` ile
## bağlanır, ölünce söner. Oyunun fontuyla çizilir.

const BAR_W := 440.0
const BAR_H := 18.0
const TOP := 52.0
const FILL_NORMAL := Color(0.62, 0.32, 0.95)
const FILL_ENRAGED := Color(0.95, 0.22, 0.26)
const FADE_IN := 0.6
const FADE_OUT := 0.8
const HOLD_AFTER_DEATH := 1.0

var boss: Node = null

var _shown := 0.0
var _frac := 1.0
var _ghost := 1.0
var _flash := 0.0
var _hold := 0.0
var _phase := 1
var _floor := 1
var _real := false
var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.boss_spawned.connect(bind)
	EventBus.boss_phase.connect(_on_phase)
	EventBus.boss_defeated.connect(_on_defeated)


func _exit_tree() -> void:
	if EventBus.boss_spawned.is_connected(bind):
		EventBus.boss_spawned.disconnect(bind)
	if EventBus.boss_phase.is_connected(_on_phase):
		EventBus.boss_phase.disconnect(_on_phase)
	if EventBus.boss_defeated.is_connected(_on_defeated):
		EventBus.boss_defeated.disconnect(_on_defeated)


## Patrona bağlanır (`Umbra`: health, max_hp, floor_no, phase alanları okunur).
func bind(b: Node) -> void:
	boss = b
	_shown = 0.0
	_hold = 0.0
	_floor = int(b.get("floor_no")) if b.get("floor_no") != null else 1
	_phase = int(b.get("phase")) if b.get("phase") != null else 1
	_real = UmbraKit.has_passive(_floor, "real")
	_frac = _fraction_of(b)
	_ghost = _frac
	queue_redraw()


func is_active() -> bool:
	return _shown > 0.0


func fraction() -> float:
	return _frac


func is_enraged() -> bool:
	return _phase >= 2


func _fraction_of(b: Node) -> float:
	var hp: float = float(b.get("health"))
	var mx: float = maxf(float(b.get("max_hp")), 1.0)
	return clampf(hp / mx, 0.0, 1.0)


func _on_phase(b: Node, p: int) -> void:
	if b == boss:
		_phase = p
		_flash = 0.4


func _on_defeated(b: Node) -> void:
	if b == boss:
		boss = null
		_frac = 0.0
		_hold = HOLD_AFTER_DEATH


func _process(delta: float) -> void:
	_t += delta
	if boss != null and not is_instance_valid(boss):
		boss = null
		_hold = 0.2
	if boss != null:
		_shown = minf(_shown + delta / FADE_IN, 1.0)
		var f := _fraction_of(boss)
		if f < _frac - 0.0001:
			_flash = 0.16
		elif f > _frac + 0.0001:
			_ghost = maxf(_ghost, f)  # ikinci nefes: bar yukarı dolar
		_frac = f
	else:
		_hold = maxf(_hold - delta, 0.0)
		if _hold <= 0.0:
			_shown = maxf(_shown - delta / FADE_OUT, 0.0)
	_flash = maxf(_flash - delta, 0.0)
	# Hayalet şerit: hasardan sonra kısa süre bekler, sonra erir.
	if _ghost > _frac:
		_ghost = maxf(_frac, _ghost - delta * 0.35)
	else:
		_ghost = _frac
	if _shown > 0.0:
		queue_redraw()


func _w() -> float:
	return size.x if size.x > 1.0 else 1280.0


func _draw() -> void:
	if _shown <= 0.0:
		return
	var a := _shown
	var w := _w()
	var x := (w - BAR_W) * 0.5
	var r := Rect2(x, TOP, BAR_W, BAR_H)
	var accent := FILL_ENRAGED if _phase >= 2 else FILL_NORMAL
	GameFont.draw_runs_centered(self, [["GÖLGE", GameFont.WHITE], ["  ·  KAT %d" % _floor, GameFont.YELLOW]], Vector2(w * 0.5, TOP - 22.0), 24, a)
	draw_rect(r.grow(5.0), Color(0.04, 0.02, 0.08, 0.88 * a))
	draw_rect(r, Color(0.16, 0.08, 0.2, a))
	draw_rect(Rect2(x, TOP, BAR_W * _ghost, BAR_H), Color(1.0, 0.92, 0.85, 0.5 * a))
	draw_rect(Rect2(x, TOP, BAR_W * _frac, BAR_H), Color(accent, a))
	draw_rect(Rect2(x, TOP, BAR_W * _frac, BAR_H * 0.38), Color(1.0, 1.0, 1.0, 0.16 * a))
	if _real:
		var cx := x + BAR_W * 0.5
		draw_line(Vector2(cx, TOP - 4.0), Vector2(cx, TOP + BAR_H + 4.0), Color(1.0, 1.0, 1.0, 0.85 * a), 2.0)
	if _flash > 0.0:
		draw_rect(r, Color(1.0, 1.0, 1.0, clampf(_flash * 2.2, 0.0, 0.45) * a))
	draw_rect(r.grow(5.0), Color(accent.lightened(0.15), 0.95 * a), false, 2.0)
	GameFont.draw_runs_centered(self, [[UmbraKit.ability_name(_floor), Color(accent.lightened(0.35), 1.0)]], Vector2(w * 0.5, TOP + BAR_H + 22.0), 17, a * 0.9)
