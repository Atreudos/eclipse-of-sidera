extends Node
## Oyunun belirli anlarının ekran görüntüsünü alır (görsel kontrol için).
## Çalıştırma (sanal ekranla):
##   xvfb-run -a -s "-screen 0 1280x720x24" env LIBGL_ALWAYS_SOFTWARE=1 \
##     godot --path . --rendering-driver opengl3 --fixed-fps 60 res://tools/screenshots.tscn -- /cikti/klasoru

const SAGITTA := preload("res://actors/enemies/sagitta.tscn")
const TAURUS := preload("res://actors/enemies/taurus.tscn")
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
	var s := SAGITTA.instantiate() as Sagitta
	var b := TAURUS.instantiate() as Taurus
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
	await _frames(5)
	await _shot("4b_parry_dalga_orta")
	await _frames(8)
	await _shot("4c_parry_dalga_genis")
	await _frames(9)
	await _shot("4d_parry_dalga_son")

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
	arena.hud._debug_label.visible = false

	# Vuruş flaşı: düşman vurulduğu karede beyaza boyanır, kıvılcım çıkar
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await _frames(3)
	var dummy := TAURUS.instantiate() as Taurus
	arena.enemies_root.add_child(dummy)
	dummy.set_physics_process(false)
	dummy.global_position = Vector2(700, 613)
	player.global_position = Vector2(640, 614)
	player.state = Player.State.MOVE
	await _frames(40)
	dummy.take_damage(1, player)
	await _frames(2)
	await _shot("7_vurus_flasi")

	# Hasar: kırmızı kenar flaşı
	EventBus.screen_flash.emit(Color(0.95, 0.15, 0.2), 0.45, 0.6)
	await _frames(3)
	await _shot("8_hasar_kenar_flasi")
	dummy.queue_free()

	# Platformdaki oyuncuya düşman zıplayıp çıkar
	await _frames(40)
	player.global_position = Vector2(300, 464)
	var climber := TAURUS.instantiate() as Taurus
	arena.enemies_root.add_child(climber)
	climber.global_position = Vector2(700, 613)
	var frames_used := 0
	for i in 600:
		await get_tree().physics_frame
		frames_used += 1
		if climber.is_on_floor() and climber.feet_y() < 500.0:
			break
	await _frames(6)
	print("taurus platforma çıktı: ", climber.feet_y() < 500.0, " (", frames_used, " kare)")
	await _shot("9_platformda_dusman")

	# Parry dalgası: belirli yaşlarda dondurulmuş kareler (menzil içinde parlak, dışında soluk)
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await _frames(3)
	player.global_position = Vector2(640, 614)
	player.state = Player.State.MOVE
	await _frames(20)
	for age in [0.02, 0.06, 0.09, 0.13, 0.2, 0.3, 0.42, 0.55]:
		var wave := ParryWave.spawn(arena, player.global_position, player.stats.value("parry_zone_radius"))
		wave.set_process(false)
		wave.set("_t", age)
		wave.update_visual()
		await _frames(2)
		await _shot("wave_%03d" % int(age * 100))
		wave.queue_free()

	# Kombo: ilk vuruş (sadece sayı + bar), sonra 3 vuruş + parry (COMBO yazısı ve sayaçlar)
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await _frames(3)
	player.global_position = Vector2(560, 614)
	player.state = Player.State.MOVE
	var target := TAURUS.instantiate() as Taurus
	target.max_hp = 99
	arena.enemies_root.add_child(target)
	target.set_physics_process(false)
	target.global_position = Vector2(660, 613)
	await _frames(40)
	target.take_damage(1, player)
	await _frames(4)
	await _shot("10_kombo_ilk_vurus")
	await _frames(14)
	target.take_damage(1, player)
	await _frames(8)
	target.take_damage(2, player)
	await _frames(5)
	await _shot("11_kombo_uc_vurus")
	var fake_hit := Hitbox.new()
	fake_hit.source = target
	arena.add_child(fake_hit)
	EventBus.parry_success.emit(player, fake_hit)
	fake_hit.queue_free()
	await _frames(24)
	await _shot("12_kombo_bar_azaliyor")
	get_tree().quit()
