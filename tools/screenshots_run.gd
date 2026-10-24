extends Node
## Koşu (oda sistemi) ekran görüntüleri: oda başı, doğuş işaretleri, savaş, temiz oda, kapı, ölüm ekranı.
## Çalıştırma (sanal ekranla):
##   xvfb-run -a -s "-screen 0 1280x720x24" env LIBGL_ALWAYS_SOFTWARE=1 \
##     godot --path . --rendering-driver opengl3 --fixed-fps 60 res://tools/screenshots_run.tscn -- /cikti/klasoru

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
	run.seed_value = 20261023
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


func _kill_all() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		var a := e as ActorBase
		if a != null and not a.dead:
			a.take_damage(99, player)


func _walk_through(to_room: int) -> void:
	var door_x := (run.rooms[run.current] as Room).rect.end.x
	player.global_position = Vector2(door_x - 260.0, 612.0)
	player.facing = 1
	player.intent.move_x = 1.0
	for i in 400:
		await get_tree().physics_frame
		if run.current == to_room:
			break
	player.intent.move_x = 0.0


func _run() -> void:
	player = run.player
	player.stats.set_base("max_health", 99.0)
	player.health = 99
	await _frames(25)
	await _shot("r1_oda_basi")
	await _frames(55)
	await _shot("r2_dogus_isaretleri")
	await _frames(40)
	await _shot("r3_savas")
	# Ritim çubuğu: ATEŞLİ kademesi (kademe atlama animasyonu sırasında) ve COŞKULU
	player.rhythm.add(55.0)
	await _frames(6)
	await _shot("r3b_ritim_atesli")
	player.rhythm.add(25.0)
	await _frames(40)
	await _shot("r3c_ritim_coskulu")
	_kill_all()
	await _frames(75)
	player.global_position = Vector2((run.rooms[0] as Room).rect.end.x - 380.0, 612.0)
	await _frames(70)
	await _shot("r4_oda_temiz_kapi_acik")
	await _walk_through(1)
	await _frames(14)
	await _shot("r5_kapi_kapaniyor")
	await _frames(90)
	await _shot("r6_ikinci_oda")
	# Daha ileri odalar: farklı yerleşim, renk teması
	for target in [2, 3, 4]:
		await _frames(30)
		run.skip_room()
		await _frames(30)
		await _walk_through(target)
	await _frames(120)
	await _shot("r7_oda_5_dalgalar")
	_kill_all()
	await _frames(100)
	await _shot("r8_oda_5_ikinci_dalga")
	# Ölüm ekranı
	run.stats["kills"] = 41
	run.stats["best_combo"] = 17
	run.stats["rooms_cleared"] = 4
	player.stats.set_base("max_health", 1.0)
	player.health = 1
	player.take_damage(3, null)
	await _frames(90)
	await _shot("r9_olum_ekrani")
	get_tree().quit()
