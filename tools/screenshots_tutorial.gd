extends Node
## Öğretici ipucu panelinin ekran görüntüleri: lobi adımları (hareket, zıplama, dash, saldırı, ilerle), tamamlanma tiki,
## savaşta altın uyarı (PARRY), kaçırma, sersemletme, kırmızı uyarı (DASH).
## Çalıştırma (sanal ekranla):
##   xvfb-run -a -s "-screen 0 1280x720x24" env LIBGL_ALWAYS_SOFTWARE=1 \
##     godot --path . --rendering-driver opengl3 --fixed-fps 60 res://tools/screenshots_tutorial.tscn -- /cikti/klasoru

const RUN := preload("res://levels/run.tscn")
const TAURUS := preload("res://actors/enemies/taurus.tscn")
const SAGITTA := preload("res://actors/enemies/sagitta.tscn")

var out_dir := "user://shots"
var run: RunController
var player: Player
var guide: TutorialGuide


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	Hitstop.enabled = false
	GameState.end_session()
	run = RUN.instantiate() as RunController
	run.seed_value = 20261108
	(run.get_node("Player") as Player).scripted = true
	add_child(run)
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await get_tree().physics_frame
	return cond.call()


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, shot_name]
	img.save_png(ProjectSettings.globalize_path(path))
	print("kaydedildi: ", path, "  ipucu: ", guide.active)


func _run() -> void:
	player = run.player
	guide = run.tutorial
	player.stats.set_base("max_health", 99.0)
	player.health = 99
	await _frames(40)
	await _shot("t1_hareket")
	player.intent.move_x = 1.0
	await _until(func() -> bool: return guide.done.has("move"), 400)
	player.intent.move_x = 0.0
	await _frames(4)
	await _shot("t2_hareket_tamam")
	await _until(func() -> bool: return guide.active == Tutorial.STEP_JUMP, 400)
	await _frames(12)
	await _shot("t3_ziplama")
	player.intent.jump_pressed = true
	player.intent.jump_held = true
	await _frames(8)
	player.intent.jump_held = false
	await _until(func() -> bool: return guide.active == Tutorial.STEP_DASH, 600)
	await _frames(12)
	await _shot("t4_dash")
	player.intent.move_x = 1.0
	player.intent.dash_pressed = true
	await _frames(6)
	player.intent.move_x = 0.0
	await _until(func() -> bool: return guide.active == Tutorial.STEP_ATTACK, 600)
	await _frames(12)
	await _shot("t5_saldiri")
	player.facing = 1
	player.intent.attack_pressed = true
	await _frames(14)
	await _shot("t6_saldiri_1_3")
	for i in 2:
		await _frames(14)
		player.intent.attack_pressed = true
	await _frames(6)
	await _shot("t7_saldiri_tamam")
	await _until(func() -> bool: return guide.active == Tutorial.STEP_GO, 600)
	await _frames(12)
	await _shot("t8_ilerle")
	# Savaş odası: gerçek ilk Taurus (yavaş, yalnız altın) uyarı verince
	var from := run.current
	var room := run.rooms[from] as Room
	player.global_position = Vector2(room.rect.end.x - 200.0, 612.0)
	player.facing = 1
	player.intent.move_x = 1.0
	await _until(func() -> bool: return run.current == from + 1, 300)
	player.intent.move_x = 0.0
	await _frames(20)
	await _shot("t9_savas_odasi")
	var got := await _until(func() -> bool: return guide.active == Tutorial.STEP_PARRY, 1500)
	print("altın uyarı ipucu geldi mi: ", got)
	await _frames(6)
	await _shot("t10_parry_altin")
	EventBus.parry_failed.emit(player)
	await _frames(10)
	var cur := run.current_room()
	await _until(func() -> bool: return guide.active == Tutorial.STEP_PARRY_MISS or guide.active == Tutorial.STEP_PARRY, 60)
	await _shot("t11_kacirdin_ya_da_parry")
	# Parry başarılı -> tik -> VUR
	EventBus.parry_success.emit(player, null)
	await _frames(6)
	await _shot("t12_parry_tik")
	await _until(func() -> bool: return guide.active == Tutorial.STEP_STRIKE, 900)
	await _frames(8)
	await _shot("t13_vur")
	# Kırmızı uyarı
	guide._strike_t = 0.0
	guide.done["strike"] = true
	guide._hold_t = 0.0
	guide._refresh()
	run.skip_room()
	await _frames(10)
	var t := TAURUS.instantiate() as Taurus
	run.enemies_root.add_child(t)
	t.global_position = Vector2(cur.rect.position.x + 900.0, 612.0)
	t.process_mode = Node.PROCESS_MODE_DISABLED
	t.set_tell(EnemyBase.Tell.RED)
	await _frames(10)
	await _shot("t14_kirmizi")
	t.set_tell(EnemyBase.Tell.NONE)
	var s := SAGITTA.instantiate() as Sagitta
	run.enemies_root.add_child(s)
	s.global_position = Vector2(cur.rect.position.x + 1000.0, 612.0)
	s.process_mode = Node.PROCESS_MODE_DISABLED
	guide.done.erase("parry")
	guide._hold_t = 0.0
	s.set_tell(EnemyBase.Tell.GOLD)
	await _frames(10)
	await _shot("t15_altin_mermi")
	get_tree().quit()
