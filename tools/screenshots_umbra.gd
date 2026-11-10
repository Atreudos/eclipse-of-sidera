extends Node
## Gölge (Umbra) ekran görüntüleri: üstteki can barı, altın/kırmızı uyarı, zırh çerçevesi, duvar tırmanışı, yer darbesi,
## bıçak yağmuru, dönen bıçaklar, gizlenme, klon, kükreme (yer tutucu çizimlerin gözle kontrolü).
## Çalıştırma (sanal ekranla):
##   xvfb-run -a -s "-screen 0 1280x720x24" env LIBGL_ALWAYS_SOFTWARE=1 \
##     godot --path . --rendering-driver opengl3 --fixed-fps 60 res://tools/screenshots_umbra.tscn -- /cikti/klasoru
## İsteğe bağlı ikinci argüman yalnız bazı bölümleri çeker (virgülle): kat1 kat3 kat7 kat8 kat9 kat12 kat13 kat16 kat18. Örn. "-- /cikti kat3,kat18".

const RUN := preload("res://levels/run.tscn")

var out_dir := "user://shots"
var only: PackedStringArray = PackedStringArray()
var run: RunController
var player: Player
var umbra: Umbra


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		only = args[1].split(",", false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	Hitstop.enabled = false
	_run()


## Bölüm çekilsin mi? (süzgeç boşsa hepsi)
func _want(section: String) -> bool:
	return only.is_empty() or section in only


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


## Yeni bir koşu kurar ve verilen katın Gölge odasına götürür; Gölge doğunca hazır bekletir.
func _enter_boss(floor_no: int) -> void:
	if run != null and is_instance_valid(run):
		run.queue_free()
		await _frames(3)
	GameState.umbra_items.clear()
	run = RUN.instantiate() as RunController
	run.seed_value = 20261109
	run.floors_enabled = true
	(run.get_node("Player") as Player).scripted = true
	add_child(run)
	await _frames(5)
	player = run.player
	player.stats.set_base("max_health", 99.0)
	player.health = 99
	if floor_no > 1:
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
	umbra = null
	for i in 600:
		await get_tree().physics_frame
		for e in get_tree().get_nodes_in_group("boss"):
			umbra = e as Umbra
		if umbra != null:
			break
	umbra._cooldown = 999.0  # kendi kendine hamle seçmesin
	umbra.max_hp = 9999
	umbra.health = 9999
	player.health = 99
	await _frames(40)  # çubuk belirsin, duyuru sönmeye başlasın


## Oyuncuyu Gölge'nin soluna koyar (kamera ikisini birden görsün).
func _face_off(gap: float = 260.0) -> void:
	player.global_position = Vector2(umbra.global_position.x - gap, 612.0)
	player.facing = 1
	player.velocity = Vector2.ZERO
	player.health = 99
	await _frames(25)


func _run() -> void:
	# Kat 1: yalnız bıçak. Çubuk + altın uyarı, sonra kırmızı uyarı.
	if _want("kat1"):
		await _enter_boss(1)
		await _face_off(170.0)
		await _shot("u1_bar_kat1")
		umbra.red_override = 0
		umbra.force_move(UmbraKit.Move.KNIFE)
		await _frames(22)
		await _shot("u2_bicak_altin_uyari")
		await _frames(60)
		umbra.red_override = 1
		umbra._cooldown = 999.0
		player.health = 99
		umbra.force_move(UmbraKit.Move.KNIFE)
		await _frames(22)
		await _shot("u3_bicak_kirmizi_uyari")

	# Kat 3: duvar tırmanışı (asılı: altın uyarı, zırhlı çerçeve)
	if _want("kat3"):
		await _enter_boss(3)
		await _face_off(520.0)
		umbra.red_override = 0
		umbra.force_move(UmbraKit.Move.CLIMB)
		for i in 400:
			await get_tree().physics_frame
			if umbra.stage == Umbra.C_HANG:
				break
		await _frames(8)
		await _shot("u4_duvar_tirmanisi")

	# Kat 7: yer darbesi (kırmızı şok dalgaları)
	if _want("kat7"):
		await _enter_boss(7)
		await _face_off(300.0)
		umbra.force_move(UmbraKit.Move.SLAM)
		for i in 300:
			await get_tree().physics_frame
			if umbra.stage == Umbra.S_SHOCK:
				break
		await _frames(8)
		await _shot("u5_yer_darbesi")

	# Kat 8: zırh (hazırlık sırasında çerçeve)
	if _want("kat8"):
		await _enter_boss(8)
		await _face_off(170.0)
		umbra.red_override = 0
		umbra.force_move(UmbraKit.Move.KNIFE)
		await _frames(25)
		await _shot("u6_zirh_cercevesi")

	# Kat 9: bıçak yağmuru (işaretler)
	if _want("kat9"):
		await _enter_boss(9)
		await _face_off(300.0)
		umbra.force_move(UmbraKit.Move.RAIN)
		await _frames(62)
		await _shot("u7_bicak_yagmuru")

	# Kat 12: dönen bıçaklar
	if _want("kat12"):
		await _enter_boss(12)
		await _face_off(260.0)
		umbra.force_move(UmbraKit.Move.ORBIT)
		for i in 200:
			await get_tree().physics_frame
			if umbra._blades.size() > 0:
				break
		await _frames(50)
		await _shot("u8_donen_bicaklar")

	# Kat 13: gizlenme (neredeyse görünmez)
	if _want("kat13"):
		await _enter_boss(13)
		await _face_off(300.0)
		umbra.force_move(UmbraKit.Move.CLOAK)
		await _frames(45)
		await _shot("u9_gizlenme")

	# Kat 16: klon (karşı yanda belirir)
	if _want("kat16"):
		await _enter_boss(16)
		await _face_off(260.0)
		umbra.red_override = 0
		umbra.force_move(UmbraKit.Move.CLONE)
		for i in 200:
			await get_tree().physics_frame
			if umbra.minion_count() > 0:
				break
		await _frames(25)
		await _shot("u10_klon")

	# Kat 18: gerçek dövüş: çubukta yarı çentik; yarı canda kükreme (kırmızı çubuk)
	if _want("kat18"):
		await _enter_boss(18)
		umbra.max_hp = UmbraKit.hp_for(18, 30)
		umbra.health = umbra.max_hp
		await _face_off(320.0)
		await _frames(20)
		await _shot("u11_bar_kat18")
		umbra.take_damage(umbra.max_hp / 2 + 3, player)
		for i in 200:
			await get_tree().physics_frame
			if umbra.current_move == UmbraKit.Move.WIND:
				break
		await _frames(25)
		await _shot("u12_kukreme")

	get_tree().quit()
