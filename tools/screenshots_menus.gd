extends Node
## Envanter ekranı ve F5 deneme menüsü ekran görüntüleri (yerleşimi gözle kontrol etmek için).
## Çalıştırma (sanal ekranla):
##   xvfb-run -a -s "-screen 0 1280x720x24" env LIBGL_ALWAYS_SOFTWARE=1 \
##     godot --path . --rendering-driver opengl3 --fixed-fps 60 res://tools/screenshots_menus.tscn -- /cikti/klasoru

const RUN := preload("res://levels/run.tscn")

var out_dir := "user://shots"
var run: RunController
var player: Player


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	Hitstop.enabled = false
	run = RUN.instantiate() as RunController
	run.seed_value = 20261027
	(run.get_node("Player") as Player).scripted = true
	add_child(run)
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, shot_name]
	img.save_png(ProjectSettings.globalize_path(path))
	print("kaydedildi: ", path)


func _key(code: Key, physical_only := false) -> InputEventKey:
	var e := InputEventKey.new()
	if not physical_only:
		e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e


func _run() -> void:
	player = run.player
	var inv := player.inventory
	player.stats.set_base("max_health", 4.0)
	player.health = 4
	await _frames(30)
	var inventory_screen := run.hud.inventory_screen
	var dev_menu := run.hud.dev_menu

	# 1) Boş envanter
	inventory_screen._unhandled_input(_key(KEY_I))
	await _frames(6)
	await _shot("m1_envanter_bos")
	inventory_screen._unhandled_input(_key(KEY_I))
	await _frames(4)

	# 2) Dolu envanter: slotlar takılı, çantada eşyalar, can 3/4 + 2 bağışıklık, altın
	for id in ["mirror_boots", "viper_fang", "stardust_brooch", "vampire_relic", "guardian_helm", "watcher_band", "cracked_mirror", "thief_chain"]:
		inv.add(ItemDB.get_item(id))
	for id in ["feather_boots", "saturn_hourglass", "tower_bread", "tower_bread", "baked_sweet_potato", "cosmic_star_soup"]:
		inv.give(ItemDB.get_item(id))
	player.health = 3
	player.set_immunity(2)
	player.add_gold(37)
	await _frames(20)
	await _shot("m2_oyun_hud")
	inventory_screen._unhandled_input(_key(KEY_I))
	await _frames(8)
	await _shot("m3_envanter_dolu")
	# Çanta eşyası üstünde (Satürn'ün Kum Saati: cep slotu dolu, yer değiştirme)
	inventory_screen.focus_item("saturn_hourglass")
	await _frames(4)
	await _shot("m4_envanter_cep_degisim")
	inventory_screen.activate()
	await _frames(4)
	await _shot("m5_envanter_degisti")
	# Takılı eşya üstünde
	inventory_screen.focus_item("vampire_relic")
	await _frames(4)
	await _shot("m6_envanter_takili_charm")
	# Reddedilen işlem (can dolu değil ama bağışıklık kalbi var)
	inventory_screen.focus_item("tower_bread")
	inventory_screen.activate()
	await _frames(4)
	await _shot("m7_envanter_ret")
	inventory_screen._unhandled_input(_key(KEY_ESCAPE))
	await _frames(4)

	# 3) F5 menüsü
	dev_menu._unhandled_input(_key(KEY_F5, true))
	await _frames(8)
	await _shot("m8_deneme_menusu")
	dev_menu.select_item("saturn_hourglass")
	dev_menu._unhandled_input(_key(KEY_ENTER))
	await _frames(4)
	await _shot("m9_deneme_menusu_secili")
	dev_menu._unhandled_input(_key(KEY_END))
	await _frames(4)
	await _shot("m10_deneme_menusu_son")
	dev_menu._unhandled_input(_key(KEY_F5, true))
	get_tree().quit()
