class_name MainMenu
extends Control
## Ana menü: ekran yığını (başlık, kayıtlar, yeni oyun, krediler...), hareketli arka plan ve giriş.
##
## Arka plan: koddan çizilen yıldızlı gökyüzü ve tutulma (eclipse). `ui_menu_bg_far` / `ui_logo` gibi çizimlerin gelince
## (assets/ altına PNG olarak konunca) onların yerine çizilir; kod değişmez.
## Giriş: yön tuşları / WASD / D-pad / sol çubuk gezinir, Enter / Space / E / J / A seçer, Esc / Backspace / B / sağ tık geri.
## Fare: üstüne gelince seçer, tıklayınca onaylar.
##
## Testler `press`, `type_char`, `hover_at`, `click_at` ile gerçek girişin gittiği yoldan sürer.

signal screen_changed(screen_id: String)

const W := 1280.0
const H := 720.0
const STAR_COUNT := 110
const FADE_TIME := 0.16
const STICK_ON := 0.6
const STICK_OFF := 0.3
const MESSAGE_TIME := 2.4

## En üstteki ekran yığının SONUNDADIR.
var stack: Array[MenuScreen] = []

var _t := 0.0
var _msg := ""
var _msg_good := true
var _msg_t := 0.0
var _eclipse := Vector3.ZERO
var _stars: Array[Dictionary] = []
var _stick := {}
var _layer: Control = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	get_tree().paused = false
	GameState.end_session()
	_make_stars()
	_layer = _Layer.new(self)
	add_child(_layer)
	push(TitleScreen.new())
	_eclipse = top().eclipse()


# ---------------------------------------------------------------- ekran yığını

func top() -> MenuScreen:
	return stack.back() if not stack.is_empty() else null


func top_id() -> String:
	return top().screen_id() if top() != null else ""


## Yeni ekran açar (altındaki ekran yığında kalır; geri dönülünce `on_resume` çağrılır).
func push(screen: MenuScreen) -> void:
	screen.menu = self
	stack.append(screen)
	screen.on_enter()
	_changed()


## Üstteki ekranı kapatır. Yığında tek ekran kalmışsa kapatmaz.
func pop() -> void:
	if stack.size() < 2:
		return
	stack.pop_back()
	top().on_resume()
	_changed()


## Üstteki ekranı yenisiyle değiştirir (geri dönülünce alttaki ekran görünür).
func replace(screen: MenuScreen) -> void:
	if not stack.is_empty():
		stack.pop_back()
	push(screen)


func _changed() -> void:
	if _layer != null:
		_layer.modulate.a = 0.0
	_msg_t = 0.0
	screen_changed.emit(top_id())


## Başlık ekranına kadar geri döner.
func pop_to_root() -> void:
	while stack.size() > 1:
		stack.pop_back()
	if top() != null:
		top().on_resume()
	_changed()


# ---------------------------------------------------------------- oyun başlatma

## Slotla bir kipte oyuna girer. `resume`: kaydedilmiş koşu varsa onu sürdür. Başlatılamazsa (kip sahnesi yok) false.
func start_game(slot: SaveSlot, kind: int, resume: bool) -> bool:
	if slot == null or not SceneRouter.can_play(kind):
		return false
	GameState.begin_session(slot, kind)
	if resume and slot.has_run(kind):
		GameState.resume_run = slot.run_of(kind)
	slot.touch()
	SaveStore.save_slot(slot)
	SceneRouter.go_game(get_tree(), kind)
	return true


## Kayıtsız hızlı deneme koşusu (geliştirici kısayolu F8): ilerleme kaydedilmez.
func quick_run() -> void:
	GameState.end_session()
	SceneRouter.go_game(get_tree(), GameMode.Kind.NORMAL)


func quit_game() -> void:
	SceneRouter.quit(get_tree())


# ---------------------------------------------------------------- mesaj ve ses

func say(text: String, good: bool = true) -> void:
	_msg = text
	_msg_good = good
	_msg_t = MESSAGE_TIME


func message() -> String:
	return _msg if _msg_t > 0.0 else ""


func play_move() -> void:
	Sfx.play("ui_move", -8.0, 1.0, 0.03)


func play_select() -> void:
	Sfx.play("ui_select", -4.0)


func play_deny() -> void:
	Sfx.play("ui_deny", -5.0)


# ---------------------------------------------------------------- giriş

## Gerçek giriş olayını eyleme çevirir ("" = menü eylemi değil). Kumanda çubuğunda kenar algılama için durum tutar.
func action_of(event: InputEvent) -> String:
	var text_mode := top() != null and top().wants_text()
	var key := event as InputEventKey
	if key != null:
		if not key.pressed:
			return ""
		var k := key.physical_keycode
		match k:
			KEY_UP:
				return "up"
			KEY_DOWN:
				return "down"
			KEY_LEFT:
				return "left"
			KEY_RIGHT:
				return "right"
		if k == KEY_BACKSPACE:
			return "backspace" if text_mode else ("" if key.echo else "back")
		if not text_mode:
			match k:
				KEY_W:
					return "up"
				KEY_S:
					return "down"
				KEY_A:
					return "left"
				KEY_D:
					return "right"
		if key.echo:
			return ""
		match k:
			KEY_ENTER, KEY_KP_ENTER:
				return "accept"
			KEY_ESCAPE:
				return "back"
			KEY_DELETE:
				return "delete"
		if not text_mode and (k == KEY_SPACE or k == KEY_E or k == KEY_J):
			return "accept"
		return ""
	var button := event as InputEventJoypadButton
	if button != null:
		if not button.pressed:
			return ""
		match button.button_index:
			JOY_BUTTON_DPAD_UP:
				return "up"
			JOY_BUTTON_DPAD_DOWN:
				return "down"
			JOY_BUTTON_DPAD_LEFT:
				return "left"
			JOY_BUTTON_DPAD_RIGHT:
				return "right"
			JOY_BUTTON_A:
				return "accept"
			JOY_BUTTON_B:
				return "back"
			JOY_BUTTON_X:
				return "delete"
		return ""
	var motion := event as InputEventJoypadMotion
	if motion != null and (motion.axis == JOY_AXIS_LEFT_X or motion.axis == JOY_AXIS_LEFT_Y):
		var v := motion.axis_value
		var held := int(_stick.get(motion.axis, 0))
		if absf(v) <= STICK_OFF:
			_stick[motion.axis] = 0
		elif absf(v) >= STICK_ON and held == 0:
			_stick[motion.axis] = 1 if v > 0.0 else -1
			if motion.axis == JOY_AXIS_LEFT_X:
				return "right" if v > 0.0 else "left"
			return "down" if v > 0.0 else "up"
	return ""


func _unhandled_input(event: InputEvent) -> void:
	if top() == null:
		return
	var act := action_of(event)
	if act != "":
		press(act)
		get_viewport().set_input_as_handled()
		return
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	if top().wants_text():
		if key.unicode >= 32 and key.unicode != 127:
			type_char(char(key.unicode))
			get_viewport().set_input_as_handled()
	elif not key.echo and key.physical_keycode == KEY_F8 and top_id() == "title":
		quick_run()
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if top() == null:
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		hover_at(motion.position)
		return
	var button := event as InputEventMouseButton
	if button != null and button.pressed:
		if button.button_index == MOUSE_BUTTON_LEFT:
			click_at(button.position)
		elif button.button_index == MOUSE_BUTTON_RIGHT:
			press("back")
		accept_event()


## Bir eylemi üstteki ekrana iletir.
func press(action: String) -> void:
	if top() != null:
		top().on_action(action)


func type_char(ch: String) -> void:
	if top() != null and top().wants_text():
		top().on_char(ch)


## Bir yazıyı karakter karakter yazar (testler).
func type_text(text: String) -> void:
	for i in text.length():
		type_char(text.substr(i, 1))


func hover_at(pos: Vector2) -> void:
	if top() != null:
		top().on_hover(pos)


func click_at(pos: Vector2) -> void:
	if top() != null:
		top().on_click(pos)


# ---------------------------------------------------------------- zaman ve çizim

func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	_t += dt
	_msg_t = maxf(_msg_t - dt, 0.0)
	if top() != null:
		top().on_tick(dt)
		var target := top().eclipse()
		_eclipse = _eclipse.lerp(target, 1.0 - exp(-5.0 * dt))
	if _layer != null:
		_layer.modulate.a = minf(_layer.modulate.a + dt / FADE_TIME, 1.0)
		_layer.queue_redraw()
	queue_redraw()


func _make_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261031
	_stars.clear()
	for i in STAR_COUNT:
		_stars.append({
			"x": rng.randf(), "y": rng.randf(), "depth": rng.randf_range(0.25, 1.0),
			"phase": rng.randf() * TAU, "size": 1.0 + float(rng.randi() % 3),
		})


func _draw() -> void:
	var full := Rect2(0.0, 0.0, W, H)
	draw_rect(full, MenuUi.BG)
	var has_art := Art.has("ui_menu_bg_far")
	if has_art:
		Art.draw(self, "ui_menu_bg_far", full, _t, Color.WHITE, true)
		Art.draw(self, "ui_menu_bg_mid", full, _t, Color.WHITE, true)
	else:
		_draw_stars()
		_draw_eclipse()
	if has_art:
		Art.draw(self, "ui_menu_bg_near", full, _t, Color.WHITE, true)


func _draw_stars() -> void:
	for s in _stars:
		var depth: float = s["depth"]
		var x := fposmod(float(s["x"]) - _t * 0.006 * depth, 1.0) * W
		var y := float(s["y"]) * H
		var twinkle := 0.5 + 0.5 * sin(_t * (0.8 + depth) + float(s["phase"]))
		var a := 0.18 + 0.6 * depth * (0.45 + 0.55 * twinkle)
		var sz: float = s["size"]
		draw_rect(Rect2(x, y, sz, sz), Color(0.82, 0.86, 1.0, a))


## Tutulma: altın parıltı, ışınlar, altın disk ve üstüne hafif kaymış kara disk (kenarda ince bir hilal görünür).
func _draw_eclipse() -> void:
	var c := Vector2(_eclipse.x, _eclipse.y)
	var r := _eclipse.z
	for i in 14:
		var k := float(i) / 13.0
		draw_circle(c, r * (1.12 + k * 1.15), Color(1.0, 0.78, 0.25, 0.02 * (1.0 - k) + 0.002))
	for i in 30:
		var ang := float(i) / 30.0 * TAU + _t * 0.04
		var dir := Vector2(cos(ang), sin(ang))
		var len := r * (0.16 + 0.14 * (0.5 + 0.5 * sin(_t * 1.3 + float(i) * 1.7)))
		draw_line(c + dir * r * 1.02, c + dir * (r * 1.02 + len), Color(1.0, 0.86, 0.42, 0.32), 2.0, true)
	draw_circle(c, r, Color(1.0, 0.86, 0.4))
	var off := Vector2(sin(_t * 0.33), cos(_t * 0.27) * 0.6) * r * 0.055 + Vector2(r * 0.02, -r * 0.012)
	draw_circle(c + off, r * 0.965, Color(0.012, 0.008, 0.03))
	# Elmas halka: kenarda dolanan parlak nokta.
	var a2 := _t * 0.42
	var spot := c + Vector2(cos(a2), sin(a2)) * r * 0.985
	draw_circle(spot, r * 0.1, Color(1.0, 0.95, 0.75, 0.16))
	draw_circle(spot, r * 0.055, Color(1.0, 0.97, 0.85, 0.45))
	draw_circle(spot, r * 0.025, Color(1.0, 1.0, 0.95, 0.95))


## Ekran içeriği: `_Layer` çağırır (geçişte solup yanar).
func _draw_screen(ci: CanvasItem) -> void:
	var s := top()
	if s == null:
		return
	s.draw(ci, _t)
	var h := s.hint()
	if h != "":
		GameFont.draw_centered(ci, h, Vector2(W * 0.5, H - 28.0), 16, Color(MenuUi.DIM, 0.85), false)
	if _msg_t > 0.0 and _msg != "":
		var a := minf(_msg_t / 0.4, 1.0)
		MenuUi.fit_centered(ci, _msg, Vector2(W * 0.5, H - 62.0), 24, W - 200.0, Color(MenuUi.GOOD if _msg_good else MenuUi.BAD, a))


## Ekran katmanı: arka planın üstünde, kendi `modulate`ı ile solarak açılır.
class _Layer extends Control:
	var _menu: MainMenu

	func _init(m: MainMenu) -> void:
		_menu = m

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	func _draw() -> void:
		_menu._draw_screen(self)
