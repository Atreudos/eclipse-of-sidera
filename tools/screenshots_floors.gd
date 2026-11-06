extends Node
## Kat sistemi ekran görüntüleri: lobi + dükkân, dükkân menüsü, savaş odası HUD'ı, Gölge odası, kat geçidi, kararma kartı,
## farklı katların renkleri, zafer ekranı.
## Çalıştırma (sanal ekranla):
##   xvfb-run -a -s "-screen 0 1280x720x24" env LIBGL_ALWAYS_SOFTWARE=1 \
##     godot --path . --rendering-driver opengl3 --fixed-fps 60 res://tools/screenshots_floors.tscn -- /cikti/klasoru

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
	run.seed_value = 20261107
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


func _walk_to_next() -> void:
	var from := run.current
	var room := run.rooms[from] as Room
	player.global_position = Vector2(room.rect.end.x - 200.0, 612.0)
	player.facing = 1
	player.intent.move_x = 1.0
	for i in 300:
		await get_tree().physics_frame
		if run.current == from + 1:
			break
	player.intent.move_x = 0.0


func _clear_room() -> void:
	var room := run.current_room()
	for i in 400:
		if room.alive_count() > 0 or room.pending_count() > 0:
			break
		await get_tree().physics_frame
	run.skip_room()
	await _frames(20)


func _run() -> void:
	player = run.player
	player.stats.set_base("max_health", 99.0)
	player.health = 99
	player.add_gold(180)
	await _frames(30)
	await _shot("f1_lobi_kat1")
	var lobby := run.rooms[0] as Room
	player.global_position = Vector2(lobby.rect.position.x + RoomLayouts.shop_x(RoomLayouts.LOBBY_ID) - 40.0, 612.0)
	await _frames(40)
	await _shot("f2_tezgah_yaninda")
	player.interacted.emit()
	await _frames(12)
	await _shot("f3_dukkan_menusu")
	run.hud.shop_menu._unhandled_input(_key(KEY_RIGHT))
	run.hud.shop_menu._unhandled_input(_key(KEY_ENTER))
	await _frames(6)
	await _shot("f3b_dukkan_satin_alindi")
	run.hud.shop_menu.close()
	await _frames(4)
	await _walk_to_next()
	await _frames(90)
	await _shot("f4_savas_odasi_hud")
	for k in 3:
		await _clear_room()
		await _walk_to_next()
		await _frames(20)
	await _clear_room()
	await _walk_to_next()
	await _frames(30)
	await _shot("f5_golge_odasi_baslangic")
	await _frames(120)
	await _shot("f6_golge_odasi_patron")
	run.skip_room()
	await _frames(70)
	var boss_room := run.current_room()
	player.global_position = boss_room.floor_exit.global_position + Vector2(-190.0, -12.0)
	await _frames(20)
	await _shot("f7_kat_gecidi_acik")
	player.global_position = boss_room.floor_exit.global_position + Vector2(0.0, -12.0)
	await _frames(int(RunController.FADE_OUT_TIME * 60.0 * 0.6))
	await _shot("f8_kararma")
	await _frames(int(RunController.FADE_OUT_TIME * 60.0 * 0.4) + 40)
	await _shot("f9_kat2_karti")
	await _frames(int((RunController.CARD_TIME + RunController.FADE_IN_TIME) * 60.0) + 20)
	await _shot("f10_kat2_lobi")
	# Daha derin katların renkleri
	for f in [5, 9, 13, 17]:
		run.current = FloorPlan.index_of(f - 1, 5)
		run.dev_next_floor()
		await _frames(45)
		await _shot("f11_kat%d_lobi" % f)
		player.global_position = Vector2((run.current_room().rect.end.x) - 200.0, 612.0)
		await _walk_to_next()
		await _frames(60)
		await _shot("f12_kat%d_savas" % f)
	# Son kat: Gölge odası + zafer
	run.current = FloorPlan.index_of(17, 5)
	run.dev_next_floor()
	await _frames(20)
	for k in 5:
		if k > 0:
			await _clear_room()
		await _walk_to_next()
		await _frames(10)
	await _frames(150)
	await _shot("f13_son_kat_golge")
	run.stats["kills"] = 412
	run.stats["best_combo"] = 57
	run.stats["rooms_cleared"] = 72
	run.stats["time"] = 5423.0
	run.skip_room()
	await _frames(int(RunController.VICTORY_DELAY * 60.0) + 90)
	await _shot("f14_zafer")
	get_tree().quit()


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e
