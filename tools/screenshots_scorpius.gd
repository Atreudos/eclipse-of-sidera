extends Node
## Scorpius'un evreleri için ekran görüntüleri (yer tutucu çizimlerin gözle kontrolü).
## Çalıştırma (sanal ekranla):
##   xvfb-run -a -s "-screen 0 1280x720x24" env LIBGL_ALWAYS_SOFTWARE=1 \
##     godot --path . --rendering-driver opengl3 --fixed-fps 60 res://tools/screenshots_scorpius.tscn -- /cikti/klasoru

const SCORPIUS := preload("res://actors/enemies/scorpius.tscn")

var out_dir := "user://shots"
var arena: Node2D
var player: Player
var sc: Scorpius


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	Hitstop.enabled = false
	arena = (load("res://levels/test_arena.tscn") as PackedScene).instantiate()
	add_child(arena)
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


func _wait_phase(phase: Scorpius.Phase, max_frames: int = 200) -> bool:
	for i in max_frames:
		await get_tree().physics_frame
		if sc._phase == phase:
			return true
	return false


func _spawn(x: float) -> void:
	if sc != null and is_instance_valid(sc):
		sc.queue_free()
	await _frames(3)
	sc = SCORPIUS.instantiate() as Scorpius
	sc.max_hp = 99
	arena.enemies_root.add_child(sc)
	sc.global_position = Vector2(x, 612.0)
	sc._attacks_done = 1
	sc._decide_t = 999.0
	await _frames(10)


func _run() -> void:
	player = arena.player
	player.scripted = true
	player.health = 999
	arena._next_wave_t = 99999.0
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await _frames(30)
	player.global_position = Vector2(500.0, 612.0)
	player.facing = 1

	# 1) Dinlenme: kılıç menzilinde bekliyor
	await _spawn(640.0)
	await _frames(20)
	await _shot("s1_mesafe")

	# 2) Uyarı: sarı elmas + altın parıltı, rapier geride
	sc._begin_attack(false)
	await _frames(14)
	await _shot("s2_uyari_altin")

	# 3) Dürtüş: ince parlak hat
	await _wait_phase(Scorpius.Phase.LUNGE)
	await _frames(3)
	await _shot("s3_durtus")
	await _frames(50)
	player.health = 999

	# 4) Geri takla: gövde havada dönüyor
	await _spawn(660.0)
	player.global_position.x = sc.global_position.x - 60.0
	sc._hop_cooldown = 0.0
	await _wait_phase(Scorpius.Phase.BACKFLIP)
	await _frames(8)
	await _shot("s4_geri_takla")
	await _frames(40)

	# 5) Sahte saldırı + erken parry: kaybolma, arkada belirme (kırmızı uyarı, sembol yok), sırttan vuruş
	await _spawn(640.0)
	sc._begin_attack(true)
	await _frames(6)
	player.intent.parry_pressed = true
	await _wait_phase(Scorpius.Phase.VANISH)
	await _frames(3)
	await _shot("s5_kaybolma")
	await _wait_phase(Scorpius.Phase.STAB_TELL)
	await _frames(6)
	await _shot("s6_arkada_kirmizi_uyari")
	await _wait_phase(Scorpius.Phase.STAB)
	await _frames(3)
	await _shot("s7_sirttan_vurus")
	await _frames(60)
	player.health = 999

	# 6) Parry sonrası stun
	player.global_position = Vector2(500.0, 612.0)
	await _spawn(640.0)
	sc._begin_attack(false)
	var pressed := false
	for i in 120:
		await get_tree().physics_frame
		if not pressed and sc._phase == Scorpius.Phase.TELL and sc._timer < 0.05:
			player.intent.parry_pressed = true
			pressed = true
		if sc.is_stunned():
			break
	await _frames(10)
	await _shot("s8_stun")
	get_tree().quit()
