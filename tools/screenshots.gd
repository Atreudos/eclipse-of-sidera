extends Node
## Oyunun belirli anlarının ekran görüntüsünü alır (görsel kontrol için).
## Çalıştırma (sanal ekranla):
##   xvfb-run -a -s "-screen 0 1280x720x24" env LIBGL_ALWAYS_SOFTWARE=1 \
##     godot --path . --rendering-driver opengl3 --fixed-fps 60 res://tools/screenshots.tscn -- /cikti/klasoru

const SHOOTER := preload("res://actors/enemies/shooter.tscn")
const BIDDER := preload("res://actors/enemies/bidder.tscn")
const PROJECTILE := preload("res://combat/projectile.tscn")

var out_dir := "user://shots"
var arena: Node2D
var player: Player


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


func _run() -> void:
	player = arena.player
	player.scripted = true
	arena._next_wave_t = 99999.0  # otomatik dalga gelmesin
	arena.hud.wave = 3
	await _frames(40)
	await _shot("1_arena")

	# Düşman uyarıları: altın (parry'lenebilir) ve kırmızı (kaçılmalı)
	var s := SHOOTER.instantiate() as Shooter
	var b := BIDDER.instantiate() as Bidder
	arena.enemies_root.add_child(s)
	arena.enemies_root.add_child(b)
	s.global_position = Vector2(1020, 600)
	b.global_position = Vector2(300, 600)
	await _frames(30)
	s.set_physics_process(false)
	b.set_physics_process(false)
	s.facing = -1
	b.facing = 1
	s.set_tell(EnemyBase.Tell.GOLD)
	b.set_tell(EnemyBase.Tell.RED)
	await _frames(6)
	await _shot("2_uyarilar_altin_kirmizi")

	# Parry penceresi + gelen altın ve kırmızı mermi
	s.set_tell(EnemyBase.Tell.NONE)
	b.set_tell(EnemyBase.Tell.NONE)
	var gold := PROJECTILE.instantiate() as Projectile
	arena.add_child(gold)
	gold.global_position = Vector2(780, 600)
	gold.launch(Vector2(-60, 0), true, s, 1)
	var red := PROJECTILE.instantiate() as Projectile
	arena.add_child(red)
	red.global_position = Vector2(500, 560)
	red.launch(Vector2(60, 0), false, b, 1)
	await _frames(2)
	player.intent.parry_pressed = true
	await _frames(1)
	player.intent.parry_pressed = false
	await _shot("3_parry_penceresi")

	# Parry başarısı: mermi parry bölgesine giriyor
	gold.queue_free()
	red.queue_free()
	var near := PROJECTILE.instantiate() as Projectile
	arena.add_child(near)
	near.global_position = Vector2(700, 600)
	near.launch(Vector2(-360, 0), true, s, 1)
	await _frames(24)
	player.intent.parry_pressed = true
	await _frames(4)
	await _shot("4_parry_basarisi")

	# Saldırı (parry toparlanmasının bitmesini bekle)
	await _frames(45)
	player.global_position = Vector2(640, 612)
	b.global_position = Vector2(700, 612)
	await _frames(4)
	player.intent.attack_pressed = true
	await _frames(7)
	await _shot("5_saldiri_guclu_vurus")
	arena.hud._debug_label.visible = true
	await _frames(3)
	await _shot("6_debug_paneli")
	get_tree().quit()
