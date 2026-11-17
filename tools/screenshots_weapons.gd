extends Node
## Silah sistemi ekran görüntüleri: HUD silah kartları (J/I), fırlatılan sapan taşı, Süperteknolojik Nişangâh hedef işareti,
## elle yukarı nişan oku, yumruk kombosu, seviye parlaması.
## Çalıştırma (sanal ekranla):
##   xvfb-run -a -s "-screen 0 1280x720x24" env LIBGL_ALWAYS_SOFTWARE=1 \
##     godot --path . --rendering-driver opengl3 --fixed-fps 60 res://tools/screenshots_weapons.tscn -- /cikti/klasoru

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


func _first_enemy() -> EnemyBase:
	for e in get_tree().get_nodes_in_group("enemies"):
		var a := e as EnemyBase
		if a != null and not a.dead:
			return a
	return null


func _run() -> void:
	GameState.umbra_items.clear()
	run = RUN.instantiate() as RunController
	run.seed_value = 20261113
	run.floors_enabled = true
	(run.get_node("Player") as Player).scripted = true
	add_child(run)
	await _frames(5)
	player = run.player
	player.stats.set_base("max_health", 99.0)
	player.health = 99
	GameState.god_mode = true
	await _frames(20)
	await _shot("w1_lobi_hud_baslangic")
	# ilk dövüş odasına geç
	var lobby := run.current_room()
	player.global_position = Vector2(lobby.rect.end.x - 150.0, 612.0)
	player.facing = 1
	player.intent.move_x = 1.0
	for i in 300:
		await get_tree().physics_frame
		if run.current == 1:
			break
	player.intent.move_x = 0.0
	await _frames(120)
	var room := run.current_room()
	var foe := _first_enemy()
	if foe != null:
		foe.set_physics_process(false)
		foe.global_position = Vector2(player.global_position.x + 420.0, 612.0)
		foe.health = 99
	await _frames(4)
	# sapan: taş havada
	player.intent.attack2_pressed = true
	await _frames(12)
	await _shot("w2_sapan_tasi_havada")
	await _frames(40)
	# yumruk: J slotuna al, seviye 3'e çıkar
	player.loadout.grant("fist")
	player.loadout.upgrade("fist")
	player.loadout.upgrade("fist")
	player.loadout.upgrade("sling")
	await _frames(4)
	await _shot("w3_hud_yumruk_seviye_parlama")
	if foe != null:
		foe.global_position = Vector2(player.global_position.x + 56.0, 612.0)
	player.intent.attack_pressed = true
	await _frames(14)
	player.intent.attack_pressed = true
	await _frames(5)
	await _shot("w4_yumruk_kombo")
	await _frames(60)
	# elle yukarı nişan
	player.intent.aim_y = -1.0
	player.intent.move_x = 0.0
	await _frames(3)
	await _shot("w5_nisan_yukari_ok")
	player.intent.attack2_pressed = true
	await _frames(10)
	await _shot("w6_sapan_yukari")
	player.intent.aim_y = 0.0
	await _frames(60)
	# nişangâh: hedef işareti
	player.inventory.give(ItemDB.get_item("super_scope"))
	player.inventory.equip(ItemDB.get_item("super_scope"))
	if foe != null:
		foe.global_position = Vector2(player.global_position.x + 520.0, 470.0)
	await _frames(6)
	await _shot("w7_nisangah_hedef")
	player.intent.attack2_pressed = true
	await _frames(10)
	await _shot("w8_nisangah_atis")
	# dükkân menüsü: silah satırı (yükseltme ve yeni silah)
	player.gold = 260
	var shop_menu := run.hud.shop_menu
	var rack := ShopStock.generate(RandomNumberGenerator.new(), 3, player.inventory.owned_ids(), [], WeaponLoadout.new())
	shop_menu.open_shop(player, rack)
	shop_menu.focus(rack.size() - 3)
	await _frames(3)
	await _shot("w9_dukkan_yukselt")
	shop_menu.focus(rack.size() - 1)
	await _frames(3)
	await _shot("w10_dukkan_yeni_silah")
	shop_menu.close()
	# envanter: silah kutuları, yedek silah
	player.loadout.grant("fist", false)
	player.loadout.upgrade("fist")
	player.loadout.upgrade("fist")
	var inv_screen := run.hud.inventory_screen
	inv_screen.open(player)
	for i in inv_screen.cell_count():
		if inv_screen._cells[i]["kind"] == "weapon" and inv_screen._cells[i]["idx"] == 0:
			inv_screen._cursor = i
	await _frames(3)
	await _shot("w11_envanter_silah_j")
	inv_screen.activate()
	await _frames(3)
	await _shot("w12_envanter_silah_degisti")
	inv_screen.close()
	get_tree().quit()
