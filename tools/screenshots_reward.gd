extends Node
## Gölge ödülü ekran görüntüleri: yükselen iki sunak, ödül menüsü (iki eşya + "Gölge alırsa"), seçimden sonra sunaklar ve açılan kat geçidi.
## Çalıştırma (sanal ekranla):
##   xvfb-run -a -s "-screen 0 1280x720x24" env LIBGL_ALWAYS_SOFTWARE=1 \
##     godot --path . --rendering-driver opengl3 --fixed-fps 60 res://tools/screenshots_reward.tscn -- /cikti/klasoru [kat]

const RUN := preload("res://levels/run.tscn")

var out_dir := "user://shots"
var floor_no := 5
var run: RunController
var player: Player


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		floor_no = int(args[1])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	Hitstop.enabled = false
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
	player.global_position = Vector2(room.rect.end.x - 150.0, 612.0)
	player.facing = 1
	player.intent.move_x = 1.0
	for i in 300:
		await get_tree().physics_frame
		if run.current == from + 1:
			break
	player.intent.move_x = 0.0


func _run() -> void:
	GameState.umbra_items.clear()
	run = RUN.instantiate() as RunController
	run.seed_value = 20261111
	run.floors_enabled = true
	(run.get_node("Player") as Player).scripted = true
	add_child(run)
	await _frames(5)
	player = run.player
	player.stats.set_base("max_health", 99.0)
	player.health = 99
	GameState.god_mode = true
	run.current = FloorPlan.index_of(floor_no - 1, 5)
	run.dev_next_floor()
	for k in 5:
		await _frames(3)
		if k > 0:
			var room := run.current_room()
			for i in 400:
				if room.pending_count() == 0 and room.alive_count() > 0:
					break
				await get_tree().physics_frame
			run.skip_room()
			await _frames(3)
		await _walk_to_next()
	var boss_room := run.current_room()
	var umbra: Umbra = null
	for i in 600:
		await get_tree().physics_frame
		for e in get_tree().get_nodes_in_group("boss"):
			umbra = e as Umbra
		if umbra != null:
			break
	umbra._cooldown = 999.0
	await _frames(30)
	player.global_position = Vector2(boss_room.rect.size.x * 0.5 + boss_room.rect.position.x - 330.0, 612.0)
	umbra.take_damage(umbra.max_hp, player)
	for i in 200:
		await get_tree().physics_frame
		if boss_room.is_cleared():
			break
	# sunaklar yükselirken
	await _frames(30)
	await _shot("r1_sunaklar_yukseliyor")
	await _frames(90)
	player.global_position = boss_room.reward.global_position + Vector2(-60.0, -28.0)
	await _frames(20)
	await _shot("r2_sunaklar_hazir")
	# menü: ilk eşya, sonra ikinci eşya
	run._on_reward_requested(boss_room.reward)
	await _frames(6)
	await _shot("r3_menu_ilk_esya")
	run.hud.reward_menu.focus(1)
	await _frames(3)
	await _shot("r4_menu_ikinci_esya")
	# çanta dolu mesajı
	for i in player.inventory.bag_free():
		var dummy := ItemData.new()
		dummy.id = "dolgu%d" % i
		dummy.display_name = dummy.id
		player.inventory.give(dummy)
	run.hud.reward_menu.take_cursor()
	await _frames(4)
	await _shot("r5_menu_canta_dolu")
	player.inventory.bag.clear()
	# al: ışık patlaması + Gölge'nin aldığı sunak
	run.hud.reward_menu.take_cursor()
	await _frames(20)
	await _shot("r6_secim_patlama")
	await _frames(110)
	player.global_position = boss_room.floor_exit.global_position + Vector2(-260.0, -28.0)
	await _frames(40)
	await _shot("r7_secim_sonrasi_gecit_acik")
	GameState.god_mode = false
	get_tree().quit()
