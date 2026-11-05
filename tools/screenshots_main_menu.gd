extends Node
## Ana menü ekran görüntüleri (yerleşimi gözle kontrol etmek için). Kayıtlar geçici klasöre yazılır.
## Çalıştırma (sanal ekranla):
##   xvfb-run -a -s "-screen 0 1280x720x24" env LIBGL_ALWAYS_SOFTWARE=1 \
##     godot --path . --rendering-driver opengl3 --fixed-fps 60 res://tools/screenshots_main_menu.tscn -- /cikti/klasoru

const MAIN_MENU := preload("res://ui/menu/main_menu.tscn")

var out_dir := "user://shots_main_menu"
var menu: MainMenu


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	SaveStore.dir = "user://shots_saves"
	for i in SaveStore.COUNT:
		SaveStore.delete_slot(i)
	_make_slots()
	menu = MAIN_MENU.instantiate() as MainMenu
	add_child(menu)
	_run()


func _make_slots() -> void:
	var day := 86400
	var a := SaveSlot.create(0, "SİDERA", Difficulty.Level.NORMAL)
	a.created = SaveSlot.now() - 9 * day
	a.last_played = SaveSlot.now() - 1 * day
	a.playtime = 5025.0
	a.records = {"runs": 14, "deaths": 13, "kills": 612, "best_floor": 2, "best_room": 5, "best_wave": 0, "best_combo": 23}
	a.set_run(GameMode.Kind.NORMAL, {"seed": 11, "floor": 2, "room": 2, "wave": 0, "seen": [], "player": {"health": 3, "gold": 40, "equipped": [], "bag": []}})
	SaveStore.save_slot(a)
	var b := SaveSlot.create(1, "UMUT", Difficulty.Level.IMMORTAL)
	b.created = SaveSlot.now() - 3 * day
	b.last_played = SaveSlot.now() - 3600
	b.playtime = 812.0
	b.records = {"runs": 3, "deaths": 3, "kills": 91, "best_floor": 1, "best_room": 3, "best_wave": 12, "best_combo": 9}
	SaveStore.save_slot(b)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await _frames(8)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, shot_name]
	img.save_png(ProjectSettings.globalize_path(path))
	print("kaydedildi: ", path)


func _run() -> void:
	await _frames(10)
	await _shot("a1_baslik")
	menu.press("down")
	await _shot("a2_baslik_krediler_secili")
	menu.press("up")
	menu.press("accept")
	await _shot("a3_kayitlar")
	# Boş slot: yeni oyun sihirbazı
	(menu.top() as SlotsScreen).cursor = 2
	menu.press("accept")
	menu.type_text("ali veli")
	await _shot("a4_yeni_oyun_isim")
	menu.press("accept")
	menu.press("down")
	menu.press("down")
	await _shot("a5_yeni_oyun_zorluk")
	menu.press("back")
	menu.press("back")
	# Dolu slot menüsü (yarım koşulu)
	var sl := menu.top() as SlotsScreen
	sl.cursor = 0
	menu.press("accept")
	await _shot("a6_kayit_menusu")
	(menu.top() as SlotMenuScreen).list.focus("new_normal")
	menu.press("accept")
	await _shot("a7_yeni_kosu_onay")
	menu.press("back")
	menu.press("back")
	# İkinci slot: zorluk satırı
	sl = menu.top() as SlotsScreen
	sl.cursor = 1
	menu.press("accept")
	(menu.top() as SlotMenuScreen).list.focus("difficulty")
	await _shot("a8_kayit_menusu_zorluk")
	menu.press("back")
	menu.press("back")
	menu.press("down")
	menu.press("accept")
	var cr := menu.top() as CreditsScreen
	cr.offset = 380.0
	await _shot("a9_krediler")
	get_tree().quit()
