extends Node
## Uçtan uca duman testi (gerçek pencere gerekir): ana menü -> yeni kayıt -> oyunda gerçek tuş girdileriyle dövüş, envanter,
## deneme menüsü, duraklatma -> ölünce ana menü -> kaydı tekrar aç -> oyun.
## Motorun ürettiği hata/uyarı satırlarını görmek içindir (testler bunları yakalamaz).
## Çalıştırma:
##   xvfb-run -a -s "-screen 0 1280x720x24" env LIBGL_ALWAYS_SOFTWARE=1 \
##     godot --path . --rendering-driver opengl3 --fixed-fps 60 res://tools/e2e_flow.tscn 2>&1 | grep -v ObjectDB

var frame := 0
var menu: MainMenu
var phase := "menu"
var game_frame := 0


func _ready() -> void:
	# Oyun duraklayınca (envanter, menü) sürücü de durmasın: tuşları göndermeye devam etmeli.
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveStore.dir = "user://e2e_saves"
	for i in SaveStore.COUNT:
		SaveStore.delete_slot(i)
	_open_menu()


## Menüyü ana sahne yapar; bu düzenek düğümü kökte kalır (sahne değişince silinmez).
func _open_menu() -> void:
	var packed: PackedScene = load("res://ui/menu/main_menu.tscn")
	menu = packed.instantiate() as MainMenu
	get_tree().root.add_child.call_deferred(menu)
	await get_tree().process_frame
	get_tree().current_scene = menu


func _log(text: String) -> void:
	print("[e2e %d  %.1fs] %s" % [frame, float(Time.get_ticks_msec()) / 1000.0, text])


func _key(code: Key, pressed: bool = true) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _tap(code: Key) -> void:
	_key(code, true)
	_key(code, false)


func _process(_delta: float) -> void:
	frame += 1
	var scene := get_tree().current_scene
	match phase:
		"menu":
			_menu_phase(scene)
		"game":
			_game_phase(scene)
		"menu2":
			_menu2_phase(scene)


func _menu_phase(scene: Node) -> void:
	match frame:
		20:
			_tap(KEY_ENTER)
		30:
			(menu.top() as SlotsScreen).cursor = 0
			_tap(KEY_ENTER)
			_log("boş kayıt -> " + menu.top_id())
		40:
			for ch in "umut":
				var ev := InputEventKey.new()
				ev.unicode = ch.unicode_at(0)
				ev.keycode = ch.unicode_at(0) - 32
				ev.pressed = true
				Input.parse_input_event(ev)
		45:
			_tap(KEY_ENTER)
		50:
			_tap(KEY_ENTER)
			_log("zorluk -> " + menu.top_id())
		60:
			_log("kayıt menüsü: " + menu.top_id())
			_tap(KEY_ENTER)
		70:
			_log("sahne: " + str(scene.name if scene != null else "yok"))
			phase = "game"
			game_frame = 0


func _game_phase(scene: Node) -> void:
	game_frame += 1
	var g := game_frame
	if g % 100 == 0:
		_log("oyun karesi %d  sahne=%s  duraklı=%s" % [g, str(scene.name if scene != null else "yok"), str(get_tree().paused)])
	# Gerçek tuşlarla oyna: sağa yürü, saldır, dash, parry, zıpla.
	if g == 30:
		Input.action_press("move_right")
	if g == 150:
		Input.action_release("move_right")
		Input.action_press("move_left")
	if g == 210:
		Input.action_release("move_left")
	if g > 30 and g < 290 and g % 17 == 0:
		_tap(KEY_J)
	if g > 30 and g < 290 and g % 41 == 0:
		_tap(KEY_SHIFT)
	if g > 30 and g < 290 and g % 53 == 0:
		_tap(KEY_K)
	if g > 30 and g < 290 and g % 67 == 0:
		_tap(KEY_SPACE)
	if g == 300:
		_tap(KEY_I)
	if g == 330:
		_tap(KEY_ESCAPE)
	if g == 350:
		_tap(KEY_F5)
	if g == 380:
		_tap(KEY_ESCAPE)
	if g == 400:
		_tap(KEY_ESCAPE)
		_log("duraklatma açıldı: " + str(get_tree().paused))
	if g == 430:
		_tap(KEY_ESCAPE)
		_log("duraklatma kapandı: " + str(get_tree().paused))
	if g == 460:
		_tap(KEY_F6)
	if g == 700:
		var run := scene as RunController
		if run != null:
			_log("oda=%d ölü=%s can=%d" % [run.current, str(run.player.dead), run.player.health])
		_tap(KEY_ESCAPE)
	if g == 710 or g == 735:
		var rc := scene as RunController
		if rc != null:
			_log("duraklatma açık mı=%s imleç=%d ağaç duraklı=%s" % [str(rc.hud.pause_menu.is_open), rc.hud.pause_menu.list.cursor, str(get_tree().paused)])
	if g == 720:
		# Duraklatma menüsünden ana menüye (iki basış onayı): aşağı git, kabul et.
		_tap(KEY_DOWN)
		_tap(KEY_DOWN)
		_tap(KEY_ENTER)
		_tap(KEY_ENTER)
	if g == 800:
		_log("sahne: " + str(scene.name if scene != null else "yok"))
		phase = "menu2"
		frame = 0


func _menu2_phase(scene: Node) -> void:
	match frame:
		10:
			_log("menüde: " + str(scene.name if scene != null else "yok"))
			menu = scene as MainMenu
			if menu == null:
				get_tree().quit(1)
		20:
			_tap(KEY_ENTER)
		30:
			(menu.top() as SlotsScreen).cursor = 0
			_tap(KEY_ENTER)
			_log("dolu kayıt -> " + menu.top_id())
		40:
			_tap(KEY_ENTER)
		200:
			var run := scene as RunController
			_log("devam edilen oyun: oda=%d" % [run.current if run != null else -1])
			get_tree().quit(0)
