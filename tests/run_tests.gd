extends Node
## Başsız (headless) oyun testleri.
## Çalıştırma:
##   godot --headless --fixed-fps 60 --path . res://tests/test_runner.tscn
## Hata varsa çıkış kodu 0'dan farklı olur.

const PLAYER := preload("res://actors/player/player.tscn")
const PROJECTILE := preload("res://combat/projectile.tscn")
const SAGITTA := preload("res://actors/enemies/sagitta.tscn")
const TAURUS := preload("res://actors/enemies/taurus.tscn")
const SCORPIUS := preload("res://actors/enemies/scorpius.tscn")
const RUN := preload("res://levels/run.tscn")
const UMBRA := preload("res://actors/enemies/umbra.tscn")
const UM = UmbraKit.Move

var _checks := 0
var _fails := 0
var _world: Node2D
var _parry_ok := 0
var _parry_fail := 0
var _kills := 0


var _start_msec := 0


func _ready() -> void:
	# Menüler oyunu duraklatır (get_tree().paused). Bekçi zamanlayıcısı ve test düzeneği bundan etkilenmesin;
	# oyun dünyası (_new_world) ise normal duraklatılabilir kalır.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_start_msec = Time.get_ticks_msec()
	_run_all()


## Koruma: bir test koroutini hata ile durursa süreç sonsuza kadar açık kalmasın.
## (Zamanlayıcı yerine duvar saatine bakılır; ignore_time_scale zamanlayıcıları hitstop ile çakışıyor.)
func _process(_delta: float) -> void:
	if Time.get_ticks_msec() - _start_msec > 240000:
		print("ZAMAN AŞIMI: testler 240 sn içinde bitmedi")
		get_tree().quit(2)


func _run_all() -> void:
	Hitstop.enabled = false
	EventBus.parry_success.connect(func(_a: Node, _b: Node) -> void: _parry_ok += 1)
	EventBus.parry_failed.connect(func(_a: Node) -> void: _parry_fail += 1)
	EventBus.enemy_died.connect(func(_e: Node) -> void: _kills += 1)

	# Belirli testleri çalıştırmak için: ... res://tests/test_runner.tscn -- kalıp
	var only: Array[String] = []
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		for k in args[0].split(","):
			only.append(k)
	var tests := {
		"stats": _test_stats,
		"hitstop": _test_hitstop_resets,
		"hareket": _test_movement,
		"zipla": _test_jump,
		"dash": _test_dash,
		"parry_basari": _test_parry_success,
		"parry_erken": _test_parry_early_and_iframes,
		"kirmizi_mermi": _test_red_projectile,
		"dash_mermi": _test_dash_through_projectile,
		"kati_govde": _test_solid_bodies,
		"kati_govde_dusman": _test_enemy_blocked_by_player,
		"kombo": _test_melee_combo_and_kill,
		"taurus_parry": _test_taurus_lunge_parry,
		"taurus_kirmizi": _test_taurus_red_lunge_and_death,
		"sagitta": _test_sagitta_cadence,
		"vurus_geri_bildirim": _test_hit_feedback,
		"kamera": _test_camera_fx,
		"kamera_takip": _test_camera_follow,
		"kamera_sinir": _test_camera_bounds,
		"kamera_tepki": _test_camera_reactions,
		"kamera_dikey": _test_camera_vertical,
		"kamera_oda_gecis": _test_camera_room_transition,
		"kamera_patron": _test_camera_boss,
		"ritim": _test_rhythm_meter,
		"ritim_dodge": _test_rhythm_dodge_and_heal,
		"ritim_gercek": _test_rhythm_real_fight,
		"oda_yerlesim": _test_room_layouts,
		"oda_dalga": _test_run_waves,
		"oda_akis": _test_run_flow,
		"oda_dalga_akis": _test_run_wave_progression,
		"oda_olum": _test_run_death,
		"ekran_flas": _test_screen_flash,
		"platform_cik": _test_taurus_climbs_platform,
		"platform_in": _test_taurus_descends_platform,
		"mermi_platform": _test_shot_passes_platform,
		"sprite_yukleyici": _test_sprite_loader,
		"animasyon": _test_animation_selection,
		"font": _test_font,
		"hasar_sayisi": _test_damage_number,
		"combo_sayac": _test_combo_counter,
		"combo_gercek": _test_combo_real_fight,
		"parry_dalga": _test_parry_wave,
		"parry_dalga_gercek": _test_parry_wave_real,
		"parry_ses": _test_parry_sound,
		"scorpius_mesafe": _test_scorpius_spacing,
		"scorpius_dürtüş": _test_scorpius_lunge,
		"scorpius_parry": _test_scorpius_parry_stun,
		"scorpius_yem": _test_scorpius_feint_bait,
		"scorpius_sahte": _test_scorpius_feint_calm,
		"scorpius_kurallar": _test_scorpius_rules,
		"scorpius_platform": _test_scorpius_platform,
		"sersemleme_taurus": _test_stagger_taurus,
		"sersemleme_kombo": _test_stagger_combo_real,
		"sersemleme_sagitta": _test_stagger_sagitta,
		"sersemleme_kurallar": _test_stagger_rules,
		"parry_oran": _test_parry_ratio,
		"god_modu": _test_god_mode,
		"esya_db": _test_items_db,
		"esya_envanter": _test_inventory,
		"yemek_bagisiklik": _test_food_immunity,
		"refleks_durum": _test_reflex_statuses,
		"hasar_geri_itme": _test_damage_and_knockback,
		"altin_para": _test_gold_coins,
		"esya_ayak": _test_item_feet,
		"esya_charm_bilek": _test_item_charms,
		"esya_cat_ayna": _test_item_cracked_mirror,
		"parry_zincir": _test_parry_chain,
		"zaman_durdur": _test_time_stop,
		"esya_kum_saati": _test_item_hourglass,
		"hud_ek": _test_run_hud_extras,
		"envanter_degisim": _test_inventory_swap,
		"envanter_ekrani": _test_inventory_screen,
		"gelistirici_menu": _test_dev_menu,
		"zorluk_profil": _test_difficulty_profiles,
		"zorluk_olcek": _test_enemy_scaling,
		"zorluk_dusman": _test_enemy_tuning_hooks,
		"zorluk_zeka": _test_enemy_brain,
		"zorluk_oda": _test_difficulty_run,
		"kayit_slot": _test_save_slot_data,
		"kayit_dosya": _test_save_store,
		"kayit_oyuncu": _test_save_player_snapshot,
		"kayit_kosu": _test_save_run,
		"art_yukleyici": _test_art_loader,
		"menu_giris": _test_menu_input,
		"menu_akis": _test_menu_flow,
		"menu_kayitlar": _test_menu_slots,
		"menu_kayit_menusu": _test_menu_slot_menu,
		"menu_duraklat": _test_menu_pause,
		"menu_sahne": _test_menu_scene,
		"menu_sahne_degisimi": _test_menu_scene_change_input,
		"kat_plani": _test_floor_plan,
		"dukkan_raf": _test_shop_stock,
		"dukkan_menu": _test_shop_menu,
		"kat_cikisi": _test_floor_exit,
		"kat_akisi": _test_floor_flow,
		"kat_son": _test_final_floor,
		"kat_kayit": _test_floor_save,
		"ogretici_mufredat": _test_tutorial_curriculum,
		"ogretici_ipucu": _test_tutorial_hints,
		"ogretici_savas": _test_tutorial_combat,
		"ogretici_kayit": _test_tutorial_save,
		"ogretici_panel": _test_tutorial_view,
		"ogretici_gercek": _test_tutorial_real_parry,
		"golge_kit": _test_umbra_kit,
		"golge_sahne": _test_umbra_scene,
		"golge_bicak": _test_umbra_knife,
		"golge_firlatma": _test_umbra_throw,
		"golge_tirmanis": _test_umbra_climb,
		"golge_minyon": _test_umbra_minions,
		"golge_hamleler": _test_umbra_moves,
		"golge_zirh": _test_umbra_armor,
		"golge_nefes": _test_umbra_second_wind,
		"golge_olum": _test_umbra_death,
		"golge_bar": _test_umbra_bar,
		"golge_zeka": _test_umbra_brain,
		"golge_oda": _test_umbra_room,
	}
	for test_name: String in tests:
		if not only.is_empty():
			var wanted := false
			for k in only:
				if test_name.contains(k):
					wanted = true
			if not wanted:
				continue
		await (tests[test_name] as Callable).call()

	print("\n%d kontrol, %d hata" % [_checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


# ------------------------------------------------------------------ yardımcılar

func check(cond: bool, label: String) -> void:
	_checks += 1
	if cond:
		print("  ok    ", label)
	else:
		_fails += 1
		print("  HATA  ", label)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _new_world(title: String) -> void:
	print("\n", title)
	if _world != null:
		_world.queue_free()
		await get_tree().physics_frame
		await get_tree().physics_frame
	get_tree().paused = false
	_world = Node2D.new()
	_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_world)
	var ground := StaticBody2D.new()
	ground.collision_layer = 1
	ground.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(6000, 100)
	cs.shape = rs
	cs.position = Vector2(640, 690)  # üst yüzey y=640
	ground.add_child(cs)
	_world.add_child(ground)
	_parry_ok = 0
	_parry_fail = 0
	_kills = 0


## Tek yönlü platform ekler (yüzey y = rect.position.y). Oyun sahnesindeki gibi: katman PLATFORM, grup "platforms".
func _add_platform(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = Layers.PLATFORM
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = rect.size
	cs.shape = rs
	cs.one_way_collision = true
	cs.position = rect.position + rect.size * 0.5
	cs.add_to_group("platforms")
	body.add_child(cs)
	_world.add_child(body)


func _spawn_player(x: float = 640.0) -> Player:
	var p := PLAYER.instantiate() as Player
	p.scripted = true
	_world.add_child(p)
	p.global_position = Vector2(x, 612)
	return p


func _spawn_projectile(pos: Vector2, vel: Vector2, parryable: bool, src: Node, dmg: int = 1) -> Projectile:
	var pr := PROJECTILE.instantiate() as Projectile
	_world.add_child(pr)
	pr.global_position = pos
	pr.launch(vel, parryable, src, dmg)
	return pr


func _dummy_source(x: float) -> Node2D:
	var n := Node2D.new()
	_world.add_child(n)
	n.global_position = Vector2(x, 612)
	return n


# ------------------------------------------------------------------ testler

func _test_stats() -> void:
	print("\nStats / modifier sistemi")
	var s := Stats.new({"a": 10.0})
	check(is_equal_approx(s.value("a"), 10.0), "taban değer")
	s.add_modifier("item1", "a", 5.0, 1.0)
	check(is_equal_approx(s.value("a"), 15.0), "ekleme modifier'ı")
	s.add_modifier("item2", "a", 0.0, 2.0)
	check(is_equal_approx(s.value("a"), 30.0), "çarpan modifier'ı")
	s.remove_modifiers("item1")
	check(is_equal_approx(s.value("a"), 20.0), "kaynak kaldırınca etkisi gider")
	check(is_equal_approx(s.value("yok"), 0.0), "olmayan değer 0")


## Gerçek (duvar saati) zamanı bekler. Hitstop süresi gerçek zamandır.
func _wait_real(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame


func _test_hitstop_resets() -> void:
	print("\nHitstop: yavaşlama geri alınıyor (slow-mo takılma hatası)")
	Hitstop.enabled = true
	Hitstop.reset()
	Hitstop.freeze(0.07)
	check(Engine.time_scale < 0.5, "hitstop zamanı yavaşlattı")
	await _wait_real(0.5)
	check(is_equal_approx(Engine.time_scale, 1.0), "tek vuruştan sonra zaman normale döndü (%.2f)" % Engine.time_scale)
	# Üst üste binen vuruşlar (kombo, parry + vuruş)
	for i in 6:
		Hitstop.freeze(0.05)
		await _wait_real(0.02)
	await _wait_real(0.5)
	check(is_equal_approx(Engine.time_scale, 1.0), "üst üste vuruşlardan sonra da normale döndü (%.2f)" % Engine.time_scale)
	# Aşırı uzun süre istense bile sınırlı kalmalı
	Hitstop.freeze(5.0)
	await _wait_real(0.4)
	check(is_equal_approx(Engine.time_scale, 1.0), "aşırı uzun hitstop sınırlandı (%.2f)" % Engine.time_scale)
	Hitstop.enabled = false
	Hitstop.reset()


func _test_movement() -> void:
	await _new_world("Hareket")
	var p := _spawn_player()
	await _frames(30)
	check(p.is_on_floor(), "oyuncu yere basıyor")
	var x0 := p.global_position.x
	p.intent.move_x = 1.0
	await _frames(30)
	check(p.global_position.x - x0 > 100.0, "sağa koşuyor (%.0f px)" % (p.global_position.x - x0))
	check(p.facing == 1, "yön sağ")
	p.intent.move_x = -1.0
	await _frames(15)
	check(p.facing == -1, "yön sola döndü")
	p.intent.move_x = 0.0
	await _frames(30)
	check(absf(p.velocity.x) < 5.0, "bırakınca duruyor")


func _test_jump() -> void:
	await _new_world("Zıplama")
	var p := _spawn_player()
	await _frames(30)
	var floor_y := p.global_position.y
	var apex_hold := 0.0
	await get_tree().physics_frame
	p.intent.jump_pressed = true
	p.intent.jump_held = true
	for i in 70:
		await get_tree().physics_frame
		p.intent.jump_held = true
		apex_hold = maxf(apex_hold, floor_y - p.global_position.y)
	p.intent.jump_held = false
	await _frames(40)
	check(p.is_on_floor(), "zıplama sonrası yere indi")
	check(apex_hold > 90.0, "tam zıplama yüksekliği (%.0f px)" % apex_hold)
	# kısa basış
	var apex_tap := 0.0
	await get_tree().physics_frame
	p.intent.jump_pressed = true
	p.intent.jump_held = false
	for i in 50:
		await get_tree().physics_frame
		apex_tap = maxf(apex_tap, floor_y - p.global_position.y)
	check(apex_tap < apex_hold * 0.5, "kısa basış daha alçak zıplıyor (%.0f px)" % apex_tap)
	await _frames(40)
	# çift zıplama
	await get_tree().physics_frame
	p.intent.jump_pressed = true
	p.intent.jump_held = true
	await _frames(14)
	var y_before := p.global_position.y
	p.intent.jump_pressed = true
	await _frames(10)
	check(p.global_position.y < y_before - 20.0, "havada ikinci zıplama çalışıyor")
	p.intent.jump_held = false


func _test_dash() -> void:
	await _new_world("Dash")
	var p := _spawn_player()
	await _frames(30)
	var x0 := p.global_position.x
	check(p.dash_charges == 2, "2 dash şarjı ile başlıyor")
	await get_tree().physics_frame
	p.intent.move_x = 1.0
	p.intent.dash_pressed = true
	await get_tree().physics_frame
	check(p.state == Player.State.DASH, "dash durumuna geçti")
	check(p.is_invulnerable(), "dash başında dokunulmaz")
	check(p.dash_charges == 1, "bir şarj harcandı")
	await _frames(14)
	check(p.state != Player.State.DASH, "dash bitti")
	check(p.global_position.x - x0 > 120.0, "dash mesafesi (%.0f px)" % (p.global_position.x - x0))
	check(not p.is_invulnerable(), "dash sonrası dokunulabilir")
	p.intent.move_x = 0.0
	await _frames(90)
	check(p.dash_charges == 2, "şarj zamanla doldu")


func _test_parry_success() -> void:
	await _new_world("Parry: altın mermi, doğru zamanlama")
	var p := _spawn_player()
	var src := _dummy_source(1100.0)
	await _frames(20)
	var hp0 := p.health
	var pr := _spawn_projectile(Vector2(820, 612), Vector2(-360, 0), true, src)
	var pressed := false
	for i in 120:
		await get_tree().physics_frame
		if not pressed and pr.global_position.x - p.global_position.x < 85.0:
			p.intent.parry_pressed = true
			pressed = true
		if _parry_ok > 0:
			break
	await _frames(2)
	check(_parry_ok == 1, "parry_success sinyali geldi")
	check(p.health == hp0, "can kaybı yok")
	check(is_instance_valid(pr) and pr.velocity.x > 0.0, "mermi geri döndü")
	check(is_instance_valid(pr) and pr.faction == "player", "mermi artık oyuncunun")
	check(is_instance_valid(pr) and pr.damage == 2, "geri dönen mermi hasarı x2")
	check(is_instance_valid(pr) and not pr.parryable, "geri dönen mermi tekrar parry'lenemez")
	check(p.state == Player.State.MOVE, "parry sonrası hareket serbest")
	check(p._empower_t > 1.0, "güçlü vuruş süresi başladı")


func _test_parry_early_and_iframes() -> void:
	await _new_world("Parry: erken basış = ceza, hasar sonrası dokunulmazlık")
	var p := _spawn_player()
	var src := _dummy_source(1100.0)
	await _frames(20)
	var hp0 := p.health
	var pr := _spawn_projectile(Vector2(960, 612), Vector2(-360, 0), true, src)
	var pressed := false
	for i in 150:
		await get_tree().physics_frame
		if not pressed and pr.global_position.x - p.global_position.x < 300.0:
			p.intent.parry_pressed = true
			pressed = true
		if p.health < hp0:
			break
	check(_parry_ok == 0, "erken parry başarısız")
	check(_parry_fail >= 1, "parry_failed sinyali geldi")
	check(p.health == hp0 - 1, "mermi çarptı, 1 can gitti")
	await _frames(2)
	check(p.is_invulnerable(), "hasar sonrası dokunulmazlık var")
	var hp1 := p.health
	var pr2 := _spawn_projectile(Vector2(740, 612), Vector2(-360, 0), true, src)
	await _frames(40)
	check(p.health == hp1, "dokunulmazken ikinci mermi hasar vermedi")
	if is_instance_valid(pr2):
		pr2.queue_free()


func _test_red_projectile() -> void:
	await _new_world("Parry: kırmızı mermi parry'lenemez")
	var p := _spawn_player()
	var src := _dummy_source(1100.0)
	await _frames(20)
	var hp0 := p.health
	var pr := _spawn_projectile(Vector2(820, 612), Vector2(-360, 0), false, src)
	var pressed := false
	for i in 120:
		await get_tree().physics_frame
		if not pressed and pr.global_position.x - p.global_position.x < 85.0:
			p.intent.parry_pressed = true
			pressed = true
		if p.health < hp0:
			break
	check(_parry_ok == 0, "kırmızı mermi parry'lenmedi")
	check(p.health == hp0 - 1, "kırmızı mermi hasar verdi")


func _test_dash_through_projectile() -> void:
	await _new_world("Dash: mermiden geçmek")
	var p := _spawn_player()
	var src := _dummy_source(1100.0)
	await _frames(20)
	var hp0 := p.health
	var pr := _spawn_projectile(Vector2(900, 612), Vector2(-360, 0), false, src)
	var pressed := false
	for i in 90:
		await get_tree().physics_frame
		if not pressed and pr.global_position.x - p.global_position.x < 120.0:
			p.intent.move_x = 1.0
			p.intent.dash_pressed = true
			pressed = true
	check(pressed, "dash tetiklendi")
	check(p.health == hp0, "dash i-frame'i kırmızı mermiyi geçirdi")


func _test_solid_bodies() -> void:
	await _new_world("Gövdeler katı: oyuncu ve düşman birbirinin içinden geçmez")
	var p := _spawn_player(500.0)
	var e := TAURUS.instantiate() as Taurus
	_world.add_child(e)
	e.global_position = Vector2(700.0, 612.0)
	e.set_physics_process(false)
	await _frames(20)
	var gap_min := p.body_half_width() + e.body_half_width()
	# 1) Yürüyerek içinden geçilmez
	p.intent.move_x = 1.0
	await _frames(120)
	p.intent.move_x = 0.0
	check(p.global_position.x < e.global_position.x, "yürürken düşmanın içinden geçilmiyor (oyuncu %.0f, düşman %.0f)" % [p.global_position.x, e.global_position.x])
	check(e.global_position.x - p.global_position.x >= gap_min - 1.5, "gövdeler iç içe girmiyor (%.1f px, en az %.1f)" % [e.global_position.x - p.global_position.x, gap_min])
	# 2) Dash düşmana çarpınca durur
	p.global_position.x = 600.0
	await _frames(10)
	var bumps := [0]
	p.dash_bumped.connect(func(_en: EnemyBase) -> void: bumps[0] += 1)
	p.facing = 1
	p.intent.move_x = 1.0
	p.intent.dash_pressed = true
	await _frames(1)
	var dash_frames := 0
	for i in 40:
		await get_tree().physics_frame
		if p.state == Player.State.DASH:
			dash_frames += 1
	p.intent.move_x = 0.0
	check(bumps[0] == 1, "dash düşmana çarptı (çarpma sayısı %d)" % bumps[0])
	check(e.global_position.x - p.global_position.x >= gap_min - 1.5, "dash düşmanın içinden geçmedi (%.1f px)" % (e.global_position.x - p.global_position.x))
	check(dash_frames < 9, "çarpan dash erken bitti (%d kare, tam dash ~10)" % dash_frames)
	# 3) Dash düşmandan UZAĞA serbest
	p.global_position.x = 500.0
	await _frames(10)
	var x0 := p.global_position.x
	p.facing = -1
	p.intent.move_x = -1.0
	p.intent.dash_pressed = true
	await _frames(14)
	p.intent.move_x = 0.0
	check(x0 - p.global_position.x > 120.0, "düşmandan uzağa dash serbest (%.0f px)" % (x0 - p.global_position.x))
	# 4) Düşmanın başına inen oyuncu yana kayar
	p.global_position = Vector2(e.global_position.x, 520.0)
	p.velocity = Vector2.ZERO
	await _frames(100)
	check(p.is_on_floor() and absf(p.global_position.y - 614.0) < 4.0, "düşmanın başında asılı kalmadı, yere indi (y %.0f)" % p.global_position.y)
	check(absf(p.global_position.x - e.global_position.x) >= gap_min - 1.5, "baştan yana kaydı (%.1f px)" % absf(p.global_position.x - e.global_position.x))
	# 5) Ölü düşman engel olmaz (ölüm efekti ~0.3 sn'de düşmanı siler; konumu önceden al)
	var dead_x := e.global_position.x
	e.take_damage(99, p)
	await _frames(3)
	check(e.dead, "düşman öldü")
	check(e.collision_layer == 0, "ölü düşmanın çarpışma katmanı kapandı (layer %d)" % e.collision_layer)
	p.global_position.x = dead_x - 70.0
	await _frames(5)
	p.intent.move_x = 1.0
	var crossed := false
	for i in 40:
		await get_tree().physics_frame
		if p.global_position.x > dead_x + 20.0:
			crossed = true
			break
	p.intent.move_x = 0.0
	check(crossed, "ölü düşmanın içinden geçilebiliyor (oyuncu %.0f, ölü düşman x=%.0f)" % [p.global_position.x, dead_x])


func _test_enemy_blocked_by_player() -> void:
	await _new_world("Gövdeler katı: düşman da oyuncunun içinden geçmez")
	var p := _spawn_player(500.0)
	p.stats.set_base("max_health", 99.0)
	p.health = 99
	var e := TAURUS.instantiate() as Taurus
	_world.add_child(e)
	e.global_position = Vector2(740.0, 612.0)
	await _frames(240)
	var gap_min := p.body_half_width() + e.body_half_width()
	check(not e.dead and not p.dead, "ikisi de hayatta")
	check(absf(e.global_position.x - p.global_position.x) >= gap_min - 1.5, "kovalayan düşman oyuncunun içine girmedi (%.1f px)" % absf(e.global_position.x - p.global_position.x))
	# Düşman oyuncunun başına düşerse kayıp iner
	e.global_position = Vector2(p.global_position.x, p.global_position.y - 90.0)
	e.velocity = Vector2.ZERO
	await _frames(100)
	check(e.is_on_floor() and absf(e.global_position.y - 613.0) < 4.0, "düşman oyuncunun başında asılı kalmadı (y %.0f)" % e.global_position.y)


func _test_melee_combo_and_kill() -> void:
	await _new_world("Yakın dövüş kombosu ve öldürme")
	var p := _spawn_player()
	var b := TAURUS.instantiate() as Taurus
	_world.add_child(b)
	b.set_physics_process(false)  # sabit hedef (ağaca eklendikten sonra kapatılmalı)
	b.global_position = Vector2(700, 612)
	await _frames(20)
	p.dash_charges = 0
	check(b.health == 4, "hedef 4 canla başlıyor")
	var dmg_log: Array[int] = []
	for hit in 3:
		var hp_before := b.health
		p.intent.attack_pressed = true
		for i in 60:
			await get_tree().physics_frame
			if b.health < hp_before or b.dead:
				break
		dmg_log.append(hp_before - b.health)
		# bu vuruş bitene kadar bekle (kombo penceresi içinde kal)
		for i in 40:
			await get_tree().physics_frame
			if p.state != Player.State.ATTACK:
				break
	check(dmg_log == [1, 1, 2], "kombo hasarı 1-1-2 (%s)" % str(dmg_log))
	check(_kills == 1, "düşman öldü (enemy_died sinyali geldi)")
	check(p.dash_charges == 1, "öldürme 1 dash şarjı geri verdi")


func _test_taurus_lunge_parry() -> void:
	await _new_world("Taurus: altın atılma parry'lenince sersemler")
	var p := _spawn_player()
	var b := TAURUS.instantiate() as Taurus
	b.red_chance = 0.0
	_world.add_child(b)
	b.global_position = Vector2(830, 612)
	await _frames(20)
	var hp0 := p.health
	var pressed := false
	for i in 300:
		await get_tree().physics_frame
		if not pressed and b._phase == Taurus.Phase.LUNGE and b.global_position.x - p.global_position.x < 120.0:
			p.intent.parry_pressed = true
			pressed = true
		if _parry_ok > 0:
			break
	await _frames(2)
	check(pressed, "taurus atıldı")
	check(_parry_ok == 1, "atılma parry'lendi")
	check(p.health == hp0, "can kaybı yok")
	check(b.is_stunned(), "taurus sersemledi")
	# sersemlemiş hedefe vur: parry sonrası güçlü vuruş (x2) * sersem bonusu (x1.5) = 3
	var hb := b.health
	p.global_position.x = b.global_position.x - 50.0
	await _frames(3)
	p.intent.attack_pressed = true
	for i in 30:
		await get_tree().physics_frame
		if b.health < hb:
			break
	check(hb - b.health == 3, "güçlü vuruş + sersem bonusu = 3 hasar (%d)" % (hb - b.health))


func _test_taurus_red_lunge_and_death() -> void:
	await _new_world("Taurus: kırmızı atılma parry'lenemez, ölüm")
	var p := _spawn_player()
	var b := TAURUS.instantiate() as Taurus
	b.red_chance = 1.0
	_world.add_child(b)
	b.global_position = Vector2(830, 612)
	await _frames(20)
	var hp0 := p.health
	var pressed := false
	for i in 300:
		await get_tree().physics_frame
		if not pressed and b._phase == Taurus.Phase.LUNGE and b.global_position.x - p.global_position.x < 120.0:
			p.intent.parry_pressed = true
			pressed = true
		if p.health < hp0:
			break
	check(_parry_ok == 0, "kırmızı atılma parry'lenmedi")
	check(p.health == hp0 - 2, "kırmızı atılma 2 hasar verdi (%d)" % (hp0 - p.health))
	# ölüm
	p.invulnerable_t = 0.0
	p.health = 1
	b.global_position = Vector2(p.global_position.x + 190.0, 612)
	b._phase = Taurus.Phase.CHASE
	b._cooldown = 0.0
	b.stun_t = 0.0
	b.knock_t = 0.0
	for i in 400:
		await get_tree().physics_frame
		if p.dead:
			break
	check(p.dead, "can bitince oyuncu öldü")
	check(p.state == Player.State.DEAD, "ölüm durumuna geçti")


func _test_sagitta_cadence() -> void:
	await _new_world("Sagitta: mermi ritmi (çoğu kırmızı, her 3. mermi altın)")
	var p := _spawn_player()
	p.health = 999
	var s := SAGITTA.instantiate() as Sagitta
	_world.add_child(s)
	s.global_position = Vector2(1000, 612)
	await _frames(10)
	var seen: Array[Projectile] = []
	var colors: Array[bool] = []
	for i in 1500:
		await get_tree().physics_frame
		for c in _world.get_children():
			var pr := c as Projectile
			if pr != null and not seen.has(pr):
				seen.append(pr)
				colors.append(pr.parryable)
		if seen.size() >= 4:
			break
	check(seen.size() >= 3, "sagitta mermi attı (%d adet)" % seen.size())
	if seen.size() >= 3:
		check(not colors[0] and not colors[1] and colors[2], "ilk iki kırmızı, üçüncü altın %s" % str(colors))


func _count_sparks() -> int:
	var n := 0
	for c in _world.get_children():
		if c is HitSpark:
			n += 1
	return n


func _test_hit_feedback() -> void:
	await _new_world("Vuruş geri bildirimi: flash + kıvılcım")
	var p := _spawn_player()
	var b := TAURUS.instantiate() as Taurus
	_world.add_child(b)
	b.set_physics_process(false)  # _ready bunu geri açtığı için ağaca eklendikten SONRA kapatılır
	b.global_position = Vector2(900, 613)
	await _frames(5)
	check(b.flash_amount() == 0.0, "vuruştan önce flash yok")
	b.take_damage(1, p)
	await get_tree().process_frame
	await get_tree().process_frame
	check(b.flash_amount() > 0.9, "düşman vurulunca beyaz flash (%.2f)" % b.flash_amount())
	check(b.flash_color.is_equal_approx(Color.WHITE), "düşman flaşı beyaz")
	check(_count_sparks() >= 1, "vuruş kıvılcımı çıktı")
	await _frames(30)
	check(b.flash_amount() == 0.0, "flash söndü")
	# oyuncu hasar flaşı kırmızımsı
	p.take_damage(1, b)
	await get_tree().process_frame
	await get_tree().process_frame
	check(p.flash_amount() > 0.9, "oyuncu hasar alınca flash (%.2f)" % p.flash_amount())
	check(p.flash_color.r > p.flash_color.g + 0.2, "oyuncu flaşı kırmızımsı")
	# oyuncu hasar alınca zaman YAVAŞLAMAZ
	Hitstop.enabled = true
	Hitstop.reset()
	p.invulnerable_t = 0.0
	var hb := Hitbox.new()
	hb.damage = 1
	hb.source = b
	_world.add_child(hb)
	hb.global_position = p.global_position
	p.on_hit_by(hb)
	check(is_equal_approx(Engine.time_scale, 1.0), "oyuncu hasar alınca slow-mo yok (%.2f)" % Engine.time_scale)
	Hitstop.enabled = false
	Hitstop.reset()
	hb.queue_free()


func _test_camera_fx() -> void:
	await _new_world("Kamera efektleri: pürüzsüz sarsıntı, vuruş itmesi, zoom vuruşu")
	var cam := ShakeCamera.new()
	cam.set_process(false)
	_world.add_child(cam)
	cam._noise.seed = 7
	EventBus.screen_shake.emit(10.0, 0.4)
	check(cam.trauma > 0.5, "sarsıntı başladı (trauma %.2f)" % cam.trauma)
	# Pürüzsüzlük: ardışık kareler arasındaki fark, rastgele (beyaz gürültü) sarsıntıdan çok daha küçük.
	var prev := Vector2.ZERO
	var diffs := 0.0
	var peak := 0.0
	for i in 14:
		cam.step(1.0 / 60.0)
		if i > 0:
			diffs += cam.offset.distance_to(prev)
		prev = cam.offset
		peak = maxf(peak, cam.offset.length())
	var mean_step := diffs / 13.0
	check(peak > 2.0 and peak < 22.0, "sarsıntı genliği makul (%.1f px)" % peak)
	check(mean_step < peak * 0.45, "kare başına değişim küçük, yani pürüzsüz (%.2f px / tepe %.1f)" % [mean_step, peak])
	for i in 60:
		cam.step(1.0 / 60.0)
	check(cam.trauma == 0.0 and cam.offset.length() < 0.05, "sarsıntı tamamen söndü")
	# Yönlü itme
	EventBus.camera_kick.emit(Vector2.RIGHT, 8.0)
	var max_x := 0.0
	for i in 12:
		cam.step(1.0 / 60.0)
		max_x = maxf(max_x, cam.offset.x)
	check(max_x > 3.0, "kamera vuruş yönüne itildi (%.1f px)" % max_x)
	for i in 120:
		cam.step(1.0 / 60.0)
	check(cam.offset.length() < 0.2, "itme sonrası yerine döndü")
	# Zoom vuruşu
	EventBus.camera_punch.emit(0.03)
	var max_zoom := 0.0
	for i in 12:
		cam.step(1.0 / 60.0)
		max_zoom = maxf(max_zoom, cam.zoom.x)
	check(max_zoom > cam.base_zoom * 1.01, "zoom vuruşu yakınlaştırdı (%.3f, taban %.3f)" % [max_zoom, cam.base_zoom])
	for i in 120:
		cam.step(1.0 / 60.0)
	check(absf(cam.zoom.x - cam.base_zoom) < 0.002, "zoom taban değere döndü (%.3f)" % cam.zoom.x)
	cam.queue_free()


## Kamerayı test için kurar: kendi kendine akmaz (süreyi biz veriyoruz), oyuncuyu hedef alır.
func _make_camera(p: Player, cam_bounds: Rect2) -> ShakeCamera:
	var cam := ShakeCamera.new()
	_world.add_child(cam)
	cam.set_process(false)  # ağaca girince _process yeniden açılıyor; gerçek saatle akmasın diye ağaçtayken kapatılır
	cam.target = p
	cam.set_bounds(cam_bounds, true)
	return cam


## n fizik karesi bekler; her karede kamerayı 1/60 sn ilerletir.
func _cam_run(cam: ShakeCamera, n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		cam.step(1.0 / 60.0)


func _test_camera_follow() -> void:
	await _new_world("Kamera: oyuncuyu takip, öne bakış, hafif zoom")
	var p := _spawn_player(1500.0)
	await _frames(20)
	var cam := _make_camera(p, Rect2(0.0, -1000.0, 4000.0, 2000.0))
	await _cam_run(cam, 90)
	check(cam.zoom.x > 1.08 and cam.zoom.x < 1.3, "hafif zoom-in (%.3f)" % cam.zoom.x)
	check(cam.view_rect().has_point(p.global_position), "oyuncu ekranda")
	# Öne bakış: baktığı yöne doğru kayar, yön değişince sıçramadan diğer tarafa geçer
	p.facing = 1
	await _cam_run(cam, 90)
	var ahead := cam.center().x - p.global_position.x
	check(ahead > 60.0 and ahead < 130.0, "sağa bakınca kamera sağa kaydı (%.0f px)" % ahead)
	p.facing = -1
	var prev := cam.center().x
	var max_step := 0.0
	for i in 90:
		await get_tree().physics_frame
		cam.step(1.0 / 60.0)
		max_step = maxf(max_step, absf(cam.center().x - prev))
		prev = cam.center().x
	var behind := cam.center().x - p.global_position.x
	check(behind < -60.0 and behind > -130.0, "sola dönünce kamera sola kaydı (%.0f px)" % behind)
	check(max_step < 10.0, "yön değişiminde kamera sıçramadı, kayıyor (en büyük adım %.1f px)" % max_step)
	# Koşarken takip eder, durunca önüne yerleşir
	p.facing = 1
	p.intent.move_x = 1.0
	var start_x := p.global_position.x
	var lost := false
	for i in 60:
		await get_tree().physics_frame
		cam.step(1.0 / 60.0)
		if not cam.view_rect().has_point(p.global_position):
			lost = true
	p.intent.move_x = 0.0
	check(p.global_position.x - start_x > 150.0, "oyuncu koştu (%.0f px)" % (p.global_position.x - start_x))
	check(not lost, "koşarken oyuncu hep ekranda kaldı")
	await _cam_run(cam, 150)
	ahead = cam.center().x - p.global_position.x
	check(absf(ahead - cam.look_ahead) < 10.0, "durunca kamera oyuncunun önüne yerleşti (%.0f px)" % ahead)
	# Uzağa ışınlanma: kamera yetişir, oyuncu yine de ekranda kalır
	p.global_position.x += 900.0
	await _cam_run(cam, 1)
	check(cam.view_rect().has_point(p.global_position), "uzağa ışınlanınca bile oyuncu ekranda")


func _test_camera_boss() -> void:
	await _new_world("Kamera: patron çerçevesi (Gölge uzaktayken ikisi birden görünür)")
	var room := Rect2(0.0, -200.0, 1600.0, 900.0)
	var p := _spawn_player(200.0)
	await _frames(20)
	var cam := _make_camera(p, room)
	var boss := Node2D.new()
	boss.add_to_group("boss")
	_world.add_child(boss)
	# Patron yakında: çerçeve hiçbir şeyi değiştirmez (zoom ve konum aynı kalır)
	boss.global_position = Vector2(p.global_position.x + 420.0, 612.0)
	await _cam_run(cam, 150)
	check(absf(cam.zoom.x - cam.base_zoom) < 0.01, "patron yakınken zoom aynı (%.3f)" % cam.zoom.x)
	check(cam.view_rect().has_point(boss.global_position), "yakın patron ekranda")
	# Patron karşı uçta: kamera açılır ve ikisi de payla birlikte ekranda
	boss.global_position = Vector2(1500.0, 612.0)
	await _cam_run(cam, 240)
	var v := cam.view_rect()
	check(cam.zoom.x < cam.base_zoom - 0.05, "uzak patronda kamera açıldı (%.3f)" % cam.zoom.x)
	check(cam.zoom.x >= cam.boss_min_zoom - 0.005, "ama alt sınırın altına inmedi (%.3f)" % cam.zoom.x)
	check(v.has_point(p.global_position), "oyuncu ekranda")
	check(v.has_point(boss.global_position), "uzak patron da ekranda")
	check(v.position.x >= room.position.x - 0.5 and v.end.x <= room.end.x + 0.5, "oda dışı görünmüyor (%.0f..%.0f)" % [v.position.x, v.end.x])
	# Kenar payları (oda sınırı kamerayı kısıtlamasın diye sınırsız kurulumda): oyuncu 150, patron 170 px içeride
	cam.set_bounds(Rect2(), true)
	boss.global_position = Vector2(p.global_position.x + 1000.0, 612.0)
	await _cam_run(cam, 300)
	v = cam.view_rect()
	check(v.end.x - boss.global_position.x > cam.boss_margin.x - 12.0, "patron sağ kenara payı kadar uzak (%.0f px)" % (v.end.x - boss.global_position.x))
	check(p.global_position.x - v.position.x > cam.screen_margin.x - 12.0, "oyuncu sol kenara payı kadar uzak (%.0f px)" % (p.global_position.x - v.position.x))
	cam.set_bounds(room, true)
	# Yukarıda asılı patron (duvar tırmanışı): dikeyde de görünür
	boss.global_position = Vector2(1500.0, 612.0 - 420.0)
	await _cam_run(cam, 240)
	v = cam.view_rect()
	check(v.has_point(p.global_position) and v.has_point(boss.global_position), "yukarıdaki patron da oyuncu da ekranda (%s)" % str(v))
	check(v.position.y >= room.position.y - 0.5 and v.end.y <= room.end.y + 0.5, "dikeyde oda dışı görünmüyor (%.0f..%.0f)" % [v.position.y, v.end.y])
	# Patron yakına gelince kamera yeniden yaklaşır
	boss.global_position = Vector2(p.global_position.x + 380.0, 612.0)
	await _cam_run(cam, 240)
	check(absf(cam.zoom.x - cam.base_zoom) < 0.01, "patron yakına gelince zoom eski haline döndü (%.3f)" % cam.zoom.x)
	# Aşırı uzak patron: oyuncu öncelikli, zoom alt sınırda
	boss.global_position = Vector2(5000.0, 612.0)
	cam.set_bounds(Rect2(), true)
	await _cam_run(cam, 300)
	check(cam.zoom.x >= cam.boss_min_zoom - 0.005 and cam.zoom.x < cam.base_zoom - 0.1, "aşırı uzakta zoom alt sınırda (%.3f)" % cam.zoom.x)
	check(cam.view_rect().has_point(p.global_position), "aşırı uzak patronda bile oyuncu ekranda")
	# Patron gruptan çıkınca (öldü) çerçeve kalkar
	boss.remove_from_group("boss")
	await _cam_run(cam, 240)
	check(absf(cam.zoom.x - cam.base_zoom) < 0.01, "patron gidince zoom eski haline döndü (%.3f)" % cam.zoom.x)
	# Çerçeveleme kapatılabilir
	boss.add_to_group("boss")
	boss.global_position = Vector2(1500.0, 612.0)
	cam.boss_frame = false
	await _cam_run(cam, 240)
	check(absf(cam.zoom.x - cam.base_zoom) < 0.01, "boss_frame kapalıyken kamera açılmaz (%.3f)" % cam.zoom.x)
	# Ölü Gölge çerçeveyi tutmaz
	cam.boss_frame = true
	boss.remove_from_group("boss")
	var u := _spawn_umbra(1500.0)
	u.set_physics_process(false)  # kendi kendine yürüyüp yaklaşmasın
	await _frames(5)
	await _cam_run(cam, 240)
	check(cam.zoom.x < cam.base_zoom - 0.05, "gerçek Gölge uzaktayken kamera açıldı (%.3f)" % cam.zoom.x)
	check(cam.view_rect().has_point(u.global_position), "gerçek Gölge ekranda")
	u.die()
	await _frames(3)
	await _cam_run(cam, 240)
	check(absf(cam.zoom.x - cam.base_zoom) < 0.01, "Gölge ölünce kamera eski haline döndü (%.3f)" % cam.zoom.x)


func _test_camera_bounds() -> void:
	await _new_world("Kamera: oda sınırları")
	var room := Rect2(0.0, 0.0, 1280.0, 720.0)
	var p := _spawn_player(60.0)
	await _frames(20)
	var cam := _make_camera(p, room)
	await _cam_run(cam, 90)
	var v := cam.view_rect()
	check(v.position.x >= room.position.x - 0.5, "sol sınır: oda dışı görünmüyor (%.1f)" % v.position.x)
	check(v.position.y >= room.position.y - 0.5 and v.end.y <= room.end.y + 0.5, "dikey sınırlar içinde (%.0f..%.0f)" % [v.position.y, v.end.y])
	check(v.has_point(p.global_position), "sol kenarda oyuncu ekranda")
	p.global_position.x = 1220.0
	await _cam_run(cam, 120)
	v = cam.view_rect()
	check(v.end.x <= room.end.x + 0.5, "sağ sınır: oda dışı görünmüyor (%.1f)" % v.end.x)
	check(v.has_point(p.global_position), "sağ kenarda oyuncu ekranda")
	check(absf(v.size.x - 1280.0 / cam.zoom.x) < 1.0, "görüş alanı zoom ile uyumlu (%.0f px)" % v.size.x)
	# Oda ekrandan küçükse ortalanır
	var tiny := Rect2(100.0, 100.0, 800.0, 400.0)
	cam.set_bounds(tiny, true)
	await _cam_run(cam, 10)
	check(cam.center().is_equal_approx(tiny.get_center()), "oda ekrandan küçükse kamera ortalar (%s)" % str(cam.center()))
	# Sınırsız (boyut 0)
	cam.set_bounds(Rect2(), true)
	p.global_position.x = -2000.0
	await _cam_run(cam, 150)
	check(cam.view_rect().has_point(p.global_position), "sınırsız modda kamera oyuncuyu izliyor")


func _test_camera_reactions() -> void:
	await _new_world("Kamera: dikey tembellik, dash/kombo zoom'u, düşman odağı")
	var p := _spawn_player(1500.0)
	await _frames(20)
	var cam := _make_camera(p, Rect2(0.0, -1000.0, 4000.0, 2000.0))
	await _cam_run(cam, 120)
	# Dikey: zıplayınca kamera ÇOK AZ yukarı kayar (bire bir izlemez), inince eski yüksekliğine döner
	var base_y := cam.center().y
	var start_p := p.global_position.y
	p.intent.jump_held = true
	p.intent.jump_pressed = true
	var top_p := start_p
	var top_c := base_y
	for i in 50:
		await get_tree().physics_frame
		cam.step(1.0 / 60.0)
		top_p = minf(top_p, p.global_position.y)
		top_c = minf(top_c, cam.center().y)
	p.intent.jump_held = false
	var rose := base_y - top_c
	check(start_p - top_p > 80.0, "oyuncu zıpladı (%.0f px)" % (start_p - top_p))
	check(rose >= 8.0, "kamera zıplarken azıcık yukarı kaydı (%.0f px)" % rose)
	check(rose < (start_p - top_p) * 0.5, "ama zıplamayı bire bir izlemedi (kamera %.0f px, oyuncu %.0f px)" % [rose, start_p - top_p])
	await _cam_run(cam, 150)
	check(absf(cam.center().y - base_y) < 3.0, "iniş sonrası kamera eski yüksekliğine döndü (%.1f px fark)" % (cam.center().y - base_y))
	# Dash'te hafifçe açılır
	var base_zoom := cam.base_zoom
	p.state = Player.State.DASH
	for i in 40:
		cam.step(1.0 / 60.0)
	check(cam.zoom.x < base_zoom - 0.02, "dash'te kamera hafifçe açıldı (%.3f)" % cam.zoom.x)
	p.state = Player.State.MOVE
	for i in 90:
		cam.step(1.0 / 60.0)
	check(absf(cam.zoom.x - base_zoom) < 0.005, "dash bitince zoom eski haline döndü (%.3f)" % cam.zoom.x)
	# Kombo uzadıkça biraz yaklaşır
	p.combo.spawn_numbers = false
	var dummy := _dummy_source(1800.0)
	for i in 4:
		p.combo.register_hit(dummy, 1)
	for i in 90:
		cam.step(1.0 / 60.0)
	check(cam.zoom.x > base_zoom + 0.03, "kombo uzadıkça kamera biraz yaklaştı (%.3f)" % cam.zoom.x)
	p.combo.reset()
	for i in 120:
		cam.step(1.0 / 60.0)
	check(absf(cam.zoom.x - base_zoom) < 0.005, "kombo bitince zoom döndü (%.3f)" % cam.zoom.x)
	# Yakındaki düşmana doğru azıcık kayar
	var e := TAURUS.instantiate() as Taurus
	_world.add_child(e)
	e.global_position = Vector2(p.global_position.x + 350.0, 612.0)
	e.set_physics_process(false)
	await _cam_run(cam, 150)
	var pull := cam.center().x - (p.global_position.x + cam.look_ahead)
	check(pull > 30.0 and pull <= cam.focus_max + 5.0, "yakındaki düşmana doğru azıcık kaydı (%.0f px)" % pull)
	check(cam.view_rect().has_point(p.global_position), "odak kayarken oyuncu ekranda")
	e.queue_free()
	await _cam_run(cam, 150)
	pull = cam.center().x - (p.global_position.x + cam.look_ahead)
	check(absf(pull) < 6.0, "düşman gidince kamera tekrar oyuncuya döndü (%.1f px)" % pull)


func _test_camera_vertical() -> void:
	await _new_world("Kamera: dikey hareket çok az; çıkarken/düşerken kayma, sert inişte çökme")
	var p := _spawn_player(1500.0)
	await _frames(20)
	var room := Rect2(0.0, 0.0, 4000.0, RoomLayouts.CAMERA_HEIGHT)
	var cam := _make_camera(p, room)
	await _cam_run(cam, 120)
	var base_y := cam.center().y
	# Oyuncu ekranın alt-orta kısmında durur; zeminin altında da görünür alan var
	var view := cam.view_rect()
	var rel := (p.global_position.y - view.position.y) / view.size.y
	check(rel > 0.58 and rel < 0.78, "oyuncu ekranın alt-orta kısmında (yüksekliğin %%%.0f'i)" % (rel * 100.0))
	check(view.end.y > RoomLayouts.FLOOR_Y + 100.0, "zeminin altı da görünüyor (görüş alt kenarı y=%.0f)" % view.end.y)
	check(view.position.y >= room.position.y - 0.5 and view.end.y <= room.end.y + 0.5, "görüş odanın dikey sınırları içinde")
	# Yüksekten düşüş: kamera azıcık aşağı bakar, oyuncu hep ekranda, sınırda çökme ve geri dönüş
	p.global_position.y -= 200.0
	p.velocity = Vector2.ZERO
	var max_down := 0.0
	var max_up := 0.0
	var lost := false
	var kick_peak := 0.0
	var landed := false
	for i in 150:
		await get_tree().physics_frame
		cam.step(1.0 / 60.0)
		max_down = maxf(max_down, cam.center().y - base_y)
		max_up = maxf(max_up, base_y - cam.center().y)
		if not cam.view_rect().has_point(p.global_position):
			lost = true
		if p.is_on_floor():
			landed = true
		if landed:
			kick_peak = maxf(kick_peak, cam.offset.y)
	check(landed, "oyuncu yere indi")
	check(not lost, "düşerken oyuncu hep ekranda")
	check(max_down > 6.0, "düşerken kamera azıcık aşağı baktı (%.0f px)" % max_down)
	check(max_down < 70.0 and max_up < 70.0, "dikey kayma çok az kaldı (aşağı %.0f, yukarı %.0f px)" % [max_down, max_up])
	check(kick_peak > 1.5, "sert inişte kamera hafifçe çöktü (%.1f px)" % kick_peak)
	await _cam_run(cam, 120)
	check(absf(cam.center().y - base_y) < 3.0, "iniş sonrası kamera yerine döndü (%.1f px fark)" % (cam.center().y - base_y))
	check(cam.offset.length() < 0.3, "çökme tamamen söndü (%.2f px)" % cam.offset.length())
	# Yumuşak iniş (kısa zıplama) kamerayı çökertmez
	p.global_position.y -= 20.0
	p.velocity = Vector2.ZERO
	var soft_peak := 0.0
	for i in 60:
		await get_tree().physics_frame
		cam.step(1.0 / 60.0)
		soft_peak = maxf(soft_peak, cam.offset.y)
	check(soft_peak < 0.5, "küçük inişte kamera çökmedi (%.2f px)" % soft_peak)
	# Yeni bir zemine (yüksek platform) çıkınca kamera oraya yerleşir
	_add_platform(Rect2(1300.0, 500.0, 400.0, 20.0))
	await _frames(2)
	p.global_position = Vector2(1500.0, 440.0)
	p.velocity = Vector2.ZERO
	await _cam_run(cam, 150)
	check(p.is_on_floor() and p.global_position.y < 520.0, "oyuncu platformun üstünde (y %.0f)" % p.global_position.y)
	check(base_y - cam.center().y > 100.0, "kamera yeni zemine yerleşti (%.0f px yukarı)" % (base_y - cam.center().y))
	var rel2 := (p.global_position.y - cam.view_rect().position.y) / cam.view_rect().size.y
	check(rel2 > 0.58 and rel2 < 0.78, "platformda da oyuncu ekranın alt-orta kısmında (%%%.0f)" % (rel2 * 100.0))


func _test_camera_room_transition() -> void:
	await _new_world("Kamera: odadan odaya SAĞA geçişte kayıyor, sıçramıyor")
	var a := Rect2(0.0, 0.0, 1280.0, 720.0)
	var b := Rect2(1280.0, 0.0, 1280.0, 720.0)
	var p := _spawn_player(1000.0)
	await _frames(20)
	var cam := _make_camera(p, a)
	await _cam_run(cam, 60)
	check(cam.view_rect().end.x <= a.end.x + 0.5, "geçişten önce kamera A odasında (%.0f)" % cam.view_rect().end.x)
	var cap := cam.max_speed / 60.0 + 0.5
	cam.extend_bounds(b)
	p.facing = 1
	p.intent.move_x = 1.0
	var prev := cam.center().x
	var max_step := 0.0
	var went_back := false
	for i in 150:
		await get_tree().physics_frame
		cam.step(1.0 / 60.0)
		var c := cam.center().x
		max_step = maxf(max_step, absf(c - prev))
		if c < prev - 0.5:
			went_back = true
		prev = c
	p.intent.move_x = 0.0
	check(p.global_position.x > 1500.0, "oyuncu kapıdan geçip B odasına girdi (%.0f)" % p.global_position.x)
	check(max_step <= cap, "geçişte kamera fırlamadı (en büyük adım %.1f px, sınır %.1f)" % [max_step, cap])
	check(not went_back, "kamera geriye kaymadı")
	# Yeni odanın sınırları geçerli olur; eski oda artık görünmez
	cam.set_bounds(b)
	max_step = 0.0
	prev = cam.center().x
	for i in 120:
		await get_tree().physics_frame
		cam.step(1.0 / 60.0)
		max_step = maxf(max_step, absf(cam.center().x - prev))
		prev = cam.center().x
	check(max_step <= cap, "yeni oda sınırı uygulanırken kamera sıçramadı (%.1f px)" % max_step)
	check(cam.view_rect().position.x >= b.position.x - 0.5, "eski oda artık görünmüyor (%.0f)" % cam.view_rect().position.x)
	check(cam.view_rect().has_point(p.global_position), "oyuncu ekranda")


# ------------------------------------------------------------------ oda sistemi

## Koşuyu gerçek sahneden kurar (test için oyuncu betikli, çok canlı). Tohum sabit.
## `floors`: katlı yapı (lobi, Gölge, kat geçidi). Varsayılan kapalı: eski testler tek sonsuz şeritte çalışır.
func _start_run(seed_value: int, floors: bool = false) -> RunController:
	var run := RUN.instantiate() as RunController
	run.seed_value = seed_value
	run.floors_enabled = floors
	var p := run.get_node("Player") as Player
	p.scripted = true
	_world.add_child(run)
	# Kamera gerçek saatle akar; testte süreyi biz veririz (_cam_run). (set_process, ağaca girdikten sonra kapatılır.)
	(run.get_node("Camera") as ShakeCamera).set_process(false)
	p.stats.set_base("max_health", 99.0)
	p.health = 99
	return run


## Odadaki tüm düşmanları öldürür.
func _kill_all_enemies(p: Player) -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		var a := e as ActorBase
		if a != null and not a.dead:
			a.take_damage(99, p)
			n += 1
	return n


## `cond` doğru olana kadar en fazla `max_frames` kare bekler. Doğru olduğunda true.
func _wait_until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await get_tree().physics_frame
	return cond.call()


# ------------------------------------------------------------------ ritim (agresiflik) metresi

func _test_rhythm_meter() -> void:
	await _new_world("Ritim: kazanımlar, kademeler, azalma, hasarla düşüş, kademe etkileri")
	var p := _spawn_player(500.0)
	p.stats.set_base("max_health", 99.0)
	p.health = 99
	var r := p.rhythm
	r.set_process(false)  # zamanı biz veririz (tick)
	check(r != null and r.value == 0.0 and r.tier == 0, "ritim 0'dan başlıyor (SOĞUK)")
	check(RhythmMeter.tier_for(0.0) == 0 and RhythmMeter.tier_for(24.9) == 0, "0-25 SOĞUK")
	check(RhythmMeter.tier_for(25.0) == 1 and RhythmMeter.tier_for(49.9) == 1, "25-50 ISINMIŞ")
	check(RhythmMeter.tier_for(50.0) == 2 and RhythmMeter.tier_for(74.9) == 2, "50-75 ATEŞLİ")
	check(RhythmMeter.tier_for(75.0) == 3 and RhythmMeter.tier_for(100.0) == 3, "75-100 COŞKULU")
	check(RhythmMeter.tier_name(2) == "ATEŞLİ" and RhythmMeter.tier_name(99) == "COŞKULU", "kademe adları")
	# Kazanımlar
	var e := TAURUS.instantiate() as Taurus
	e.max_hp = 99
	_world.add_child(e)
	e.global_position = Vector2(900.0, 612.0)
	e.set_physics_process(false)
	await _frames(3)
	e.take_damage(1, p)
	check(is_equal_approx(r.value, r.gain_hit), "vuruş ritmi doldurdu (+%.0f -> %.0f)" % [r.gain_hit, r.value])
	var before := r.value
	p.take_damage(1, e)
	check(is_equal_approx(r.value, before), "oyuncunun aldığı hasar ritmi doldurmaz (kademe 0'da düşmez de)")
	before = r.value
	var fake_hit := Hitbox.new()
	fake_hit.source = e
	_world.add_child(fake_hit)
	EventBus.parry_success.emit(p, fake_hit)
	check(is_equal_approx(r.value, before + r.gain_parry), "parry ritmi doldurdu (+%.0f -> %.0f)" % [r.gain_parry, r.value])
	before = r.value
	EventBus.dodge_success.emit(p, fake_hit)
	check(is_equal_approx(r.value, before + r.gain_dodge), "dodge ritmi doldurdu (+%.0f)" % r.gain_dodge)
	before = r.value
	e.take_damage(500, p)
	check(is_equal_approx(r.value, before + r.gain_hit + r.gain_kill), "öldürme = vuruş + öldürme kazanımı (+%.0f)" % (r.value - before))
	fake_hit.queue_free()
	# Üst sınır
	r.add(500.0)
	check(r.value == RhythmMeter.MAX_VALUE and r.tier == 3, "değer 100'de sınırlı, COŞKULU")
	# Kademe sinyalleri
	r.reset()
	var changes: Array = []
	r.tier_changed.connect(func(t: int, prev: int) -> void: changes.append([t, prev]))
	r.add(30.0)
	r.add(30.0)
	r.add(30.0)
	check(changes == [[1, 0], [2, 1], [3, 2]], "kademe sinyalleri sırayla geldi %s" % str(changes))
	# Azalma: 2 sn bekleme payı, sonra düşer
	r.reset()
	r.add(60.0)
	r.tick(1.9)
	check(is_equal_approx(r.value, 60.0), "2 sn dolmadan değer düşmedi")
	r.tick(0.2)
	check(r.value < 60.0 and r.value > 55.0, "2 sn sonra düşmeye başladı (%.1f)" % r.value)
	r.tick(0.5)
	var v1 := r.value
	r.tick(0.5)
	check(is_equal_approx(v1 - r.value, r.decay_rate * 0.5), "düşüş hızı %.0f/sn" % r.decay_rate)
	r.add(5.0)
	var v2 := r.value
	r.tick(1.5)
	check(is_equal_approx(r.value, v2), "yeni kazanım bekleme süresini sıfırladı")
	r.paused = true
	r.tick(10.0)
	check(is_equal_approx(r.value, v2), "duraklatılınca değer donuyor")
	r.paused = false
	r.tick(30.0)
	check(r.value == 0.0 and r.tier == 0, "uzun süre beklersen sıfıra iner")
	# Hasar alınca bir kademe düşer
	r.add(80.0)
	check(r.tier == 3, "COŞKULU'ya çıktı")
	p.take_damage(1, null)
	check(r.tier == 2 and is_equal_approx(r.value, 50.0), "hasar: COŞKULU -> ATEŞLİ başı (%.0f)" % r.value)
	p.take_damage(1, null)
	check(r.tier == 1 and is_equal_approx(r.value, 25.0), "hasar: ATEŞLİ -> ISINMIŞ başı (%.0f)" % r.value)
	p.take_damage(1, null)
	p.take_damage(1, null)
	check(r.tier == 0 and r.value == 0.0, "hasar: dibe iniyor, eksiye düşmüyor")
	# Kademe etkileri: Stats modifier'ı olarak uygulanır, geri alınınca taban değerler döner
	var base_speed := float(Player.BASE_STATS["move_speed"])
	var base_recharge := float(Player.BASE_STATS["dash_recharge"])
	var base_window := float(Player.BASE_STATS["parry_window"])
	check(is_equal_approx(p.stats.value("move_speed"), base_speed) and is_equal_approx(p.stats.value("attack_damage"), 1.0), "SOĞUK: bonus yok")
	r.add(30.0)
	check(is_equal_approx(p.stats.value("move_speed"), base_speed * 1.06), "ISINMIŞ: koşma +%%6 (%.0f)" % p.stats.value("move_speed"))
	r.reset()
	r.add(60.0)
	check(is_equal_approx(p.stats.value("move_speed"), base_speed * 1.10), "ATEŞLİ: koşma +%10")
	check(is_equal_approx(p.stats.value("attack_damage"), 1.5), "ATEŞLİ: hasar x1.5")
	check(is_equal_approx(p.stats.value("dash_recharge"), base_recharge * 0.75), "ATEŞLİ: dash şarjı %25 hızlı")
	r.add(30.0)
	check(is_equal_approx(p.stats.value("attack_damage"), 2.0) and is_equal_approx(p.stats.value("move_speed"), base_speed * 1.16), "COŞKULU: hasar x2, koşma +%16")
	check(is_equal_approx(p.stats.value("parry_window"), base_window + 0.02), "COŞKULU: parry penceresi +0.02 sn (%.2f)" % p.stats.value("parry_window"))
	r.reset()
	check(is_equal_approx(p.stats.value("move_speed"), base_speed) and is_equal_approx(p.stats.value("attack_damage"), 1.0), "sıfırlanınca bonuslar tamamen kalktı")
	check(is_equal_approx(p.stats.value("parry_window"), base_window) and is_equal_approx(p.stats.value("dash_recharge"), base_recharge), "parry penceresi ve dash şarjı da eski haline döndü")
	# Oda temizlenince donar, yeni odada çözülür
	r.add(40.0)
	EventBus.room_cleared.emit(0)
	r.tick(10.0)
	check(r.paused and is_equal_approx(r.value, 40.0), "oda temizlenince ritim donar")
	EventBus.room_entered.emit(1)
	check(not r.paused, "yeni odaya girince ritim yeniden akar")
	r.reset()


func _test_rhythm_dodge_and_heal() -> void:
	await _new_world("Ritim: dash'le savuşturma (dodge) ve Ateşli'de parry'den can")
	var p := _spawn_player(500.0)
	p.stats.set_base("max_health", 10.0)
	p.health = 6
	var r := p.rhythm
	r.set_process(false)
	var enemy_hb := Hitbox.new()
	enemy_hb.faction = "enemy"
	enemy_hb.damage = 1
	_world.add_child(enemy_hb)
	enemy_hb.global_position = p.global_position
	var dodges := [0]
	EventBus.dodge_success.connect(func(_a: Node, _h: Node) -> void: dodges[0] += 1)
	# Dash'in ilk karelerinde saldırı değerse = dodge
	p.state = Player.State.DASH
	p._dash_t = 0.0
	var landed := p.on_hit_by(enemy_hb)
	check(not landed and p.health == 6, "dash dokunulmazken hasar yok")
	check(dodges[0] == 1 and is_equal_approx(r.value, r.gain_dodge), "dodge sinyali geldi, ritim doldu (%.0f)" % r.value)
	# Dokunulmazlık bittikten sonra aynı dash'te saldırı değerse hasar + dodge yok
	p._dash_t = 0.3
	landed = p.on_hit_by(enemy_hb)
	check(landed and p.health == 5, "dash dokunulmazlığı bitince hasar alınıyor")
	check(dodges[0] == 1, "iframe dışında dodge sayılmadı")
	p.state = Player.State.MOVE
	p.invulnerable_t = 0.0
	# Parry sonrası dokunulmazlık dodge değildir
	p.invulnerable_t = 0.5
	p.on_hit_by(enemy_hb)
	check(dodges[0] == 1, "hasar sonrası dokunulmazlık dodge sayılmadı")
	p.invulnerable_t = 0.0
	# Can toparlama: sadece ATEŞLİ ve üstü; şans 1'e çekilerek deterministik test
	r.reset()
	r.heal_chances = [1.0, 1.0, 1.0, 1.0] as Array[float]
	var heals := [0]
	EventBus.healed.connect(func(_a: Node, n: int) -> void: heals[0] += n)
	r.heal_chances = [0.0, 0.0, 1.0, 1.0] as Array[float]
	p.health = 5
	r.add(20.0)  # parry +12 -> 32 = ISINMIŞ
	EventBus.parry_success.emit(p, enemy_hb)
	check(r.tier == 1 and p.health == 5, "ISINMIŞ'ta parry can vermez (kademe %d)" % r.tier)
	r.reset()
	r.add(45.0)  # parry +12 -> 57 = ATEŞLİ
	EventBus.parry_success.emit(p, enemy_hb)
	check(r.tier == 2 and p.health == 6 and heals[0] == 1, "ATEŞLİ'de parry 1 can verdi (can %d)" % p.health)
	p.health = 10
	EventBus.parry_success.emit(p, enemy_hb)
	check(p.health == 10 and heals[0] == 1, "can zaten doluyken fazladan can yok")
	r.heal_chances = [0.0, 0.0, 0.0, 0.0] as Array[float]
	p.health = 5
	EventBus.parry_success.emit(p, enemy_hb)
	check(p.health == 5, "şans 0'sa can gelmez")
	check(p.heal(3) == 3 and p.health == 8, "heal() istenen kadar yeniler")
	check(p.heal(99) == 2 and p.health == 10, "heal() en çok max can'a kadar")
	enemy_hb.queue_free()


func _test_rhythm_real_fight() -> void:
	await _new_world("Ritim: gerçek dövüşte vuruşlar ritmi doldurur, HUD çubuğu bağlanır")
	var run := _start_run(2024)
	var p := run.player
	var r := p.rhythm
	await _frames(5)
	check(run.hud.rhythm_bar.meter == r, "HUD ritim çubuğu oyuncunun metresine bağlı")
	var shown := run.hud.announcer.count()
	r.add(30.0)
	check(run.hud.announcer.count() > shown, "kademe yükselince duyuru çıktı")
	r.reset()
	# Boşta duran bir düşmana gerçekten vur
	var e := TAURUS.instantiate() as Taurus
	e.max_hp = 99
	run.enemies_root.add_child(e)
	e.global_position = Vector2(p.global_position.x + 52.0, 612.0)
	e.set_physics_process(false)
	await _frames(10)
	p.facing = 1
	for i in 3:
		p.intent.attack_pressed = true
		await _frames(25)
	check(r.value >= r.gain_hit * 2.0, "gerçek vuruşlar ritmi doldurdu (%.0f)" % r.value)
	run.queue_free()



func _test_room_layouts() -> void:
	print("\nOda yerleşimleri geçerli (platformlara çıkılabilir, doğma noktaları yüzeyde)")
	for id in RoomLayouts.ids():
		var probs := RoomLayouts.problems(id)
		check(probs.is_empty(), "yerleşim '%s' kurallara uyuyor %s" % [id, str(probs)])
		check(RoomLayouts.width_of(id) >= 1280.0, "'%s' en az ekran genişliğinde (%.0f)" % [id, RoomLayouts.width_of(id)])
		check(RoomLayouts.spawn_points(id).size() >= 5, "'%s' en az 5 doğma noktası" % id)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var repeats := 0
	var last := ""
	var seen := {}
	for i in 60:
		var id := RoomLayouts.pick(rng, last)
		if id == last:
			repeats += 1
		seen[id] = true
		last = id
	check(repeats == 0, "art arda aynı yerleşim gelmiyor")
	check(seen.size() >= 4, "yerleşimlerin çoğu kullanılıyor (%d çeşit)" % seen.size())


func _test_run_waves() -> void:
	print("\nKoşu: dalga ölçeklenmesi ve tohumla aynı oda içeriği")
	check(RunController.wave_count_for(0) == 1 and RunController.wave_count_for(1) == 1, "ilk iki oda tek dalga")
	check(RunController.wave_count_for(2) == 2 and RunController.wave_count_for(4) == 2, "2-4. odalar iki dalga")
	check(RunController.wave_count_for(5) == 3 and RunController.wave_count_for(20) == 3, "5. oda ve sonrası üç dalga")
	var prev := 0
	var monotonic := true
	var in_range := true
	for room in 14:
		for w in RunController.wave_count_for(room):
			var n := RunController.enemies_in_wave(room, w)
			if n < 2 or n > 6:
				in_range = false
		var first := RunController.enemies_in_wave(room, 0)
		if first < prev:
			monotonic = false
		prev = first
	check(in_range, "dalga başına 2..6 düşman")
	check(monotonic, "oda ilerledikçe düşman sayısı azalmıyor")
	var a := RunController.new()
	a.floors_enabled = false  # eski tek şerit: katlı yapı ayrı testlerde
	a.run_seed = 4242
	var b := RunController.new()
	b.floors_enabled = false
	b.run_seed = 4242
	var c := RunController.new()
	c.floors_enabled = false
	c.run_seed = 99
	var same := true
	var diff := false
	for i in 12:
		if a.layout_for(i) != b.layout_for(i):
			same = false
		if a.layout_for(i) != c.layout_for(i):
			diff = true
		var wa := a.make_waves(i)
		var wb := b.make_waves(i)
		if wa.size() != wb.size():
			same = false
		for k in mini(wa.size(), wb.size()):
			if (wa[k] as Array) != (wb[k] as Array):
				same = false
	check(same, "aynı tohum aynı yerleşim ve dalgaları üretiyor")
	check(diff, "farklı tohum farklı yerleşim üretiyor")
	check(a.layout_for(0) == RunController.FIRST_LAYOUT, "ilk oda sabit yerleşim")
	var no_repeat := true
	for i in range(1, 30):
		if a.layout_for(i) == a.layout_for(i - 1):
			no_repeat = false
	check(no_repeat, "art arda iki oda aynı yerleşimde değil")
	var w0 := a.make_waves(0)
	var taurus_n := (w0[0] as Array).count(TAURUS)
	var sagitta_n := (w0[0] as Array).count(SAGITTA)
	check(w0.size() == 1 and taurus_n == 1 and sagitta_n == 1, "ilk odada bir Taurus + bir Sagitta (%d/%d)" % [taurus_n, sagitta_n])
	# Scorpius: 3. odanın 2. dalgasında tek başına tanışılır, sonra yavaş yavaş artar
	var early_none := true
	for i in 2:
		for wave in a.make_waves(i):
			if (wave as Array).has(SCORPIUS):
				early_none = false
	check(early_none, "ilk iki odada Scorpius yok")
	var w2 := a.make_waves(2)
	check(w2.size() == 2 and not (w2[0] as Array).has(SCORPIUS), "3. odanın 1. dalgasında Scorpius yok")
	check((w2[1] as Array).count(SCORPIUS) == 1, "3. odanın 2. dalgasında tam bir Scorpius (%d)" % (w2[1] as Array).count(SCORPIUS))
	check((w2[1] as Array).size() == RunController.enemies_in_wave(2, 1), "Scorpius düşman sayısını artırmıyor, birinin yerine geçiyor")
	var cap_ok := true
	var late_has := true
	for i in range(3, 20):
		var ws := a.make_waves(i)
		for k in ws.size():
			var arr := ws[k] as Array
			var sc := arr.count(SCORPIUS)
			if sc > arr.size() / 2:
				cap_ok = false
			if sc < 1:
				late_has = false
			if arr.size() != RunController.enemies_in_wave(i, k):
				cap_ok = false
	check(cap_ok, "Scorpius dalganın en fazla yarısı ve dalga boyu değişmiyor")
	check(late_has, "3. odadan sonra her dalgada en az bir Scorpius var")
	check(RunController.enemy_title(SCORPIUS) == "SCORPIUS" and RunController.enemy_title(TAURUS) == "TAURUS", "duyuru adı dosya adından geliyor")
	a.free()
	b.free()
	c.free()


func _test_run_flow() -> void:
	await _new_world("Koşu: oda kilitli başlar, temizlenince kapı açılır, sağa geçince arkadan kapanır")
	var run := _start_run(1234)
	var p := run.player
	await _frames(5)
	var r0 := run.rooms[0] as Room
	var r1 := run.rooms[1] as Room
	check(run.current == 0, "koşu 0. odada başladı")
	check(r0.state == Room.State.ACTIVE, "ilk oda aktif")
	check(r1 != null and r1.rect.position.x == r0.rect.end.x, "ikinci oda ilkinin hemen sağında (x=%.0f)" % r1.rect.position.x)
	check(r0.door.is_blocking(), "kapı kapalı (engel)")
	check(run.hud.overlay.room_number == 1, "HUD oda numarası 1")
	check(run.hud.announcer.count() >= 1, "oda duyurusu çıktı")
	check(run.camera.bounds.is_equal_approx(r0.camera_rect()), "kamera sınırı ilk oda (%s)" % str(run.camera.bounds))
	# Kapıyı zorla geçmeye çalış: kilitliyken geçilemez
	p.global_position = Vector2(r0.rect.end.x - 90.0, 612.0)
	p.intent.move_x = 1.0
	await _frames(45)
	p.intent.move_x = 0.0
	check(p.global_position.x < r0.rect.end.x, "kilitli kapıdan geçilemiyor (x=%.0f, kapı %.0f)" % [p.global_position.x, r0.rect.end.x])
	# İlk dalga doğar
	p.global_position = Vector2(180.0, 612.0)
	var spawned := await _wait_until(func() -> bool: return r0.alive_count() >= 2, 240)
	check(spawned, "ilk dalga doğdu (%d düşman)" % r0.alive_count())
	var inside := true
	for e in get_tree().get_nodes_in_group("enemies"):
		if not r0.rect.has_point((e as Node2D).global_position):
			inside = false
	check(inside, "düşmanlar oda içinde doğdu")
	check(r0.wave_number == 1 and not r0.is_cleared(), "dalga 1/1 sürüyor, oda temiz değil")
	# Hepsini öldür -> oda temiz, kapı açılır
	var killed := _kill_all_enemies(p)
	check(killed == 2, "iki düşman öldürüldü (%d)" % killed)
	var cleared := await _wait_until(func() -> bool: return r0.is_cleared(), 120)
	check(cleared, "son düşman ölünce oda temizlendi")
	await _frames(3)
	check(not r0.door.is_blocking() and r0.door.is_open, "kapı açıldı, artık engel değil")
	check(run.hud.overlay.cleared, "HUD 'ilerle' gösteriyor")
	check(int(run.stats["rooms_cleared"]) == 1 and int(run.stats["kills"]) == 2, "istatistikler: 1 oda, 2 öldürme (%s)" % str(run.stats))
	check(run.camera.bounds.end.x >= r1.camera_rect().end.x - 0.5, "kamera sınırı sağdaki odayı da kapsıyor (%.0f)" % run.camera.bounds.end.x)
	# Sağa yürü: kapıdan geç
	p.global_position = Vector2(r0.rect.end.x - 150.0, 612.0)
	p.facing = 1
	p.intent.move_x = 1.0
	var entered := await _wait_until(func() -> bool: return run.current == 1, 150)
	p.intent.move_x = 0.0
	check(entered, "sağa geçince 1. odaya girildi")
	check(p.global_position.x > r1.rect.position.x + RunController.ENTER_DEPTH - 2.0, "oyuncu yeni odanın içinde (x=%.0f)" % p.global_position.x)
	await _frames(20)
	check(r0.door.is_blocking() and r0.door.look == Door.Look.SEALED, "arkadaki kapı kapandı ve mühürlendi")
	check(r1.state == Room.State.ACTIVE, "yeni oda aktif")
	check(run.hud.overlay.room_number == 2 and not run.hud.overlay.cleared, "HUD oda 2, 'ilerle' kalktı")
	check(run.rooms.has(2), "sonraki oda (2) hazırlandı")
	# Geri dönülemez
	p.intent.move_x = -1.0
	await _frames(70)
	p.intent.move_x = 0.0
	check(p.global_position.x > r1.rect.position.x, "geri dönülemiyor (x=%.0f, sınır %.0f)" % [p.global_position.x, r1.rect.position.x])
	# Kamera yeni odaya yerleşir, eski oda görünmez
	await _cam_run(run.camera, 150)
	check(run.camera.bounds.is_equal_approx(r1.camera_rect()), "kamera sınırı yeni oda")
	check(run.camera.view_rect().position.x >= r1.rect.position.x - 1.0, "kamera eski odayı göstermiyor (%.0f)" % run.camera.view_rect().position.x)
	# Odalar silinir: oda 0, oda 2'ye girince gider
	run.skip_room()
	await _frames(5)
	p.global_position = Vector2(r1.rect.end.x - 150.0, 612.0)
	p.intent.move_x = 1.0
	var entered2 := await _wait_until(func() -> bool: return run.current == 2, 150)
	p.intent.move_x = 0.0
	check(entered2, "2. odaya girildi")
	await _frames(5)
	check(not run.rooms.has(0), "iki oda gerideki oda listeden çıktı")
	check(not is_instance_valid(r0), "iki oda gerideki oda silindi")
	check(run.rooms.has(1) and run.rooms.has(3), "bir gerideki ve bir ilerideki oda duruyor")
	run.queue_free()


func _test_run_wave_progression() -> void:
	await _new_world("Koşu: çok dalgalı odada dalgalar sırayla gelir, hepsi bitince kapı açılır")
	var run := _start_run(777)
	var p := run.player
	await _frames(5)
	# Oda 0 ve 1'i atla
	for target in [1, 2]:
		await _wait_until(func() -> bool: return run.current_room().alive_count() > 0 or run.current_room().pending_count() > 0, 200)
		run.skip_room()
		await _frames(5)
		var door_x := (run.rooms[run.current] as Room).rect.end.x
		p.global_position = Vector2(door_x - 150.0, 612.0)
		p.intent.move_x = 1.0
		await _wait_until(func() -> bool: return run.current == target, 150)
		p.intent.move_x = 0.0
		await _frames(3)
	check(run.current == 2, "2. odaya (3. oda) ulaşıldı")
	var room := run.current_room()
	check(room.waves.size() == 2, "bu odada iki dalga var")
	var first_n := RunController.enemies_in_wave(2, 0)
	var spawned := await _wait_until(func() -> bool: return room.alive_count() >= first_n, 300)
	check(spawned and room.wave_number == 1, "1. dalga doğdu (%d düşman, beklenen %d)" % [room.alive_count(), first_n])
	await _frames(30)
	check(room.alive_count() == first_n, "1. dalgada tam %d düşman (%d)" % [first_n, room.alive_count()])
	check(room.wave_number == 1, "ikinci dalga henüz gelmedi (düşmanlar canlı)")
	_kill_all_enemies(p)
	var second := await _wait_until(func() -> bool: return room.wave_number == 2, 200)
	check(second, "ilk dalga bitince 2. dalga başladı")
	check(run.seen_enemies.has(SCORPIUS.resource_path), "Scorpius görüldü olarak işaretlendi")
	var announced := false
	for it in run.hud.announcer._items:
		for part in it["runs"]:
			if str(part[0]).contains("SCORPIUS"):
				announced = true
	check(announced, "yeni düşman duyurusu çıktı (SCORPIUS)")
	check(not room.is_cleared() and room.door.is_blocking(), "oda hâlâ kilitli")
	check(run.hud.overlay.wave == 2 and run.hud.overlay.wave_total == 2, "HUD dalga 2/2")
	var n2 := RunController.enemies_in_wave(2, 1)
	await _wait_until(func() -> bool: return room.alive_count() >= n2, 200)
	check(room.alive_count() == n2, "2. dalgada %d düşman (%d)" % [n2, room.alive_count()])
	_kill_all_enemies(p)
	var done := await _wait_until(func() -> bool: return room.is_cleared(), 200)
	check(done, "son dalga bitince oda temizlendi")
	run.queue_free()


func _test_run_death() -> void:
	await _new_world("Koşu: ölünce özet ekranı, istatistikler")
	var run := _start_run(31)
	var p := run.player
	await _frames(5)
	run.stats["kills"] = 7
	run.stats["best_combo"] = 12
	p.stats.set_base("max_health", 1.0)
	p.health = 1
	p.take_damage(5, null)
	await _frames(5)
	check(p.dead, "oyuncu öldü")
	check(run.hud.overlay.dead, "ölüm ekranı açıldı")
	check(int(run.hud.overlay.summary.get("kills", -1)) == 7 and int(run.hud.overlay.summary.get("best_combo", -1)) == 12, "özet istatistikleri taşıyor (%s)" % str(run.hud.overlay.summary))
	check(RunOverlay.format_time(83.4) == "1:23" and RunOverlay.format_time(5.0) == "0:05", "süre biçimi 1:23 / 0:05")
	var t0 := float(run.stats["time"])
	await _frames(30)
	check(is_equal_approx(float(run.stats["time"]), t0), "ölünce süre sayacı durdu")
	run.queue_free()


func _test_screen_flash() -> void:
	print("\nEkran flaşı (hasar/parry)")
	EventBus.screen_flash.emit(Color(1, 0.2, 0.2), 0.5, 0.2)
	await get_tree().process_frame
	await get_tree().process_frame
	check(ScreenFx._vignette.modulate.a > 0.2, "flaş görünür (%.2f)" % ScreenFx._vignette.modulate.a)
	await _wait_real(0.5)
	check(ScreenFx._vignette.modulate.a < 0.01, "flaş söndü (%.3f)" % ScreenFx._vignette.modulate.a)


# Platform yüzeyi y=490 (oyun sahnesindeki gibi), zemin yüzeyi y=640, x: 390..610
const PLATFORM_RECT := Rect2(390, 490, 220, 20)


func _test_taurus_climbs_platform() -> void:
	await _new_world("Taurus: üst platformdaki oyuncuya zıplayıp çıkar")
	_add_platform(PLATFORM_RECT)
	var p := _spawn_player(500.0)
	p.health = 999
	p.global_position = Vector2(500, 490.0 - 26.0)
	var b := TAURUS.instantiate() as Taurus
	b.red_chance = 0.0
	_world.add_child(b)
	b.global_position = Vector2(900, 613)
	await _frames(20)
	check(p.is_on_floor() and p.feet_y() < 495.0, "oyuncu platformun üstünde duruyor")
	var lunged_below := false
	var reached := false
	var jumped := false
	for i in 900:
		await get_tree().physics_frame
		if b.is_on_floor() and b.feet_y() > 600.0 and b._phase != Taurus.Phase.CHASE:
			lunged_below = true  # altından boşuna saldırmaya çalıştı
		if not b.is_on_floor() and b.velocity.y < -200.0:
			jumped = true
		if b.is_on_floor() and b.feet_y() < 500.0:
			reached = true
			break
	check(not lunged_below, "altındayken boşuna saldırı başlatmadı")
	check(jumped, "zıpladı")
	check(reached, "platformun üstüne çıktı (ayak y=%.0f)" % b.feet_y())


func _test_taurus_descends_platform() -> void:
	await _new_world("Taurus: platformdan, altındaki oyuncuya iner")
	_add_platform(PLATFORM_RECT)
	var p := _spawn_player(500.0)
	p.health = 999
	var b := TAURUS.instantiate() as Taurus
	b.red_chance = 0.0
	_world.add_child(b)
	b.global_position = Vector2(500, 490.0 - 27.0)
	await _frames(20)
	check(b.is_on_floor() and b.feet_y() < 495.0, "taurus platformda başladı")
	var landed := false
	for i in 600:
		await get_tree().physics_frame
		if b.is_on_floor() and b.feet_y() > 630.0:
			landed = true
			break
	check(landed, "kenardan yürüyüp zemine indi (ayak y=%.0f)" % b.feet_y())


func _test_shot_passes_platform() -> void:
	await _new_world("Sagitta: mermi platformdan geçip üstteki oyuncuya ulaşır")
	_add_platform(PLATFORM_RECT)
	var p := _spawn_player(500.0)
	p.health = 50
	p.global_position = Vector2(500, 490.0 - 26.0)
	var s := SAGITTA.instantiate() as Sagitta
	_world.add_child(s)
	s.global_position = Vector2(560, 615)
	await _frames(20)
	var hit := false
	for i in 1500:
		await get_tree().physics_frame
		if p.health < 50:
			hit = true
			break
	check(hit, "alttaki Sagitta'nın mermisi platformdan geçip oyuncuya çarptı")


func _test_sprite_loader() -> void:
	print("\nSprite yükleyici (PNG'ler gelince otomatik çalışacak altyapı)")
	var img := Image.create(96, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	var frames_sq := SpriteSetLoader.slice_strip(tex)
	check(frames_sq.size() == 3, "96x32 şerit, kare genişliği = yükseklik -> 3 kare (%d)" % frames_sq.size())
	check((frames_sq[1] as AtlasTexture).region == Rect2(32, 0, 32, 32), "ikinci karenin bölgesi doğru")
	check(SpriteSetLoader.slice_strip(tex, 48).size() == 2, "kare genişliği 48 verilince 2 kare")
	check(SpriteSetLoader.build("res://assets/sprites/yok_boyle_klasor", Player.ANIM_SPEC) == null, "PNG yoksa null döner (yer tutucu kalır)")
	var sf := SpriteSetLoader.build("res://assets/sprites/sidera", Player.ANIM_SPEC)
	check(sf == null, "boş sprite klasörü: yer tutucu görsel kullanılıyor")


func _fake_frames(names: Array[String]) -> SpriteFrames:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color.MAGENTA)
	var tex := ImageTexture.create_from_image(img)
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for n in names:
		SpriteSetLoader.add_animation(frames, n, [tex] as Array[Texture2D], 10.0, n == "idle" or n == "run")
	return frames


func _test_animation_selection() -> void:
	await _new_world("Animasyon: durum -> animasyon seçimi ve eksik animasyon yedeği")
	var p := _spawn_player()
	await _frames(30)
	check(not p.anim.has_art, "PNG yokken yer tutucu görünür (sprite yok)")
	var ph := p.visual.get_node("Placeholder") as CanvasItem
	check(ph.visible, "yer tutucu şekiller açık")
	# Sadece idle/run/attack1 olan sahte sprite seti
	p.anim.use_frames(_fake_frames(["idle", "run", "attack1"] as Array[String]))
	check(p.anim.has_art, "sprite seti takıldı")
	check(not ph.visible, "sprite varken yer tutucu gizlendi")
	check(is_equal_approx(p.anim.sprite.position.y, 26.0 - 4.0), "sprite hizası: kare altı = çarpışma kutusu altı (%.1f)" % p.anim.sprite.position.y)
	check(p.anim.resolve("attack3") == "attack1", "attack3 yoksa attack2 -> attack1'e düşer")
	check(p.anim.resolve("fall") == "idle", "fall -> jump -> idle yedek zinciri")
	check(p.anim.resolve("death") == "idle", "death -> hurt -> idle yedek zinciri")
	# durum -> animasyon
	check(p.pick_animation() == "idle", "yerde duruyor -> idle (%s)" % p.pick_animation())
	p.intent.move_x = 1.0
	await _frames(20)
	check(p.pick_animation() == "run", "koşuyor -> run (%s)" % p.pick_animation())
	p.intent.move_x = 0.0
	await _frames(30)
	p.intent.jump_pressed = true
	p.intent.jump_held = true
	await _frames(3)
	check(p.pick_animation() == "jump", "yükseliyor -> jump (%s)" % p.pick_animation())
	p.intent.jump_held = false
	var saw_fall := false
	for i in 80:
		await get_tree().physics_frame
		if p.pick_animation() == "fall":
			saw_fall = true
			break
	check(saw_fall, "düşüyor -> fall")
	await _frames(60)
	p.state = Player.State.DASH
	check(p.pick_animation() == "dash", "dash durumu -> dash")
	p.state = Player.State.ATTACK
	p._attack_cur = 1
	check(p.pick_animation() == "attack2", "ikinci kombo vuruşu -> attack2")
	p.state = Player.State.PARRY
	p._parry_recovering = false
	check(p.pick_animation() == "parry", "parry penceresi -> parry")
	p._parry_recovering = true
	check(p.pick_animation() == "parry_fail", "parry toparlanması -> parry_fail")
	p.state = Player.State.HURT
	check(p.pick_animation() == "hurt", "hasar -> hurt")
	p.state = Player.State.DEAD
	check(p.pick_animation() == "death", "ölüm -> death")
	p.state = Player.State.MOVE
	# kayıtlı animasyon gerçekten oynuyor
	p.anim.trigger("attack1", 0.3)
	check(p.anim.current == "attack1" and p.anim.sprite.is_playing(), "attack1 oynuyor")
	# düşman için
	var b := TAURUS.instantiate() as Taurus
	_world.add_child(b)
	b.global_position = Vector2(900, 613)
	await _frames(20)
	b.anim.use_frames(_fake_frames(["idle", "run", "telegraph", "attack", "recover"] as Array[String]))
	check(b.pick_animation() == "idle" or b.pick_animation() == "run", "taurus yürürken idle/run (%s)" % b.pick_animation())
	b._phase = Taurus.Phase.TELEGRAPH
	check(b.pick_animation() == "telegraph", "taurus hazırlanırken telegraph")
	b._phase = Taurus.Phase.LUNGE
	check(b.pick_animation() == "attack", "taurus atılırken attack")
	b._phase = Taurus.Phase.RECOVER
	check(b.pick_animation() == "recover", "taurus toparlanırken recover")


# ------------------------------------------------------------------ font, hasar sayıları, kombo

func _spawn_dummy_enemy(x: float, hp: int = 50) -> EnemyBase:
	var e := TAURUS.instantiate() as EnemyBase
	e.max_hp = hp
	_world.add_child(e)
	e.set_physics_process(false)  # sabit hedef (ağaca eklendikten sonra kapatılmalı)
	e.global_position = Vector2(x, 612)
	return e


func _count_numbers() -> int:
	var n := 0
	for c in _world.get_children():
		if c is DamageNumber:
			n += 1
	return n


func _test_font() -> void:
	print("\nFont (Fraunces)")
	check(ResourceLoader.exists(GameFont.PATH), "font dosyası projede ve içe aktarılmış")
	var f := GameFont.get_font()
	check(f is FontFile and f.resource_path == GameFont.PATH, "oyun fontu yüklendi (yedek font değil)")
	check(ThemeDB.fallback_font != null and ThemeDB.fallback_font.resource_path == GameFont.PATH, "proje teması da aynı fontu kullanıyor (gui/theme/custom_font)")
	var tr_ok := true
	for ch in "çğıöşüÇĞİÖŞÜ":
		if not f.has_char(ch.unicode_at(0)):
			tr_ok = false
	check(tr_ok, "Türkçe harflerin hepsi fontta var")
	var sym_ok := true
	for ch in "ÂâçÇ·×—–%…":
		if not f.has_char(ch.unicode_at(0)):
			sym_ok = false
	check(sym_ok, "şapkalı A, tireler, yüzde ve · × işaretleri fontta var")
	check(GameFont._prep("A%20 — Â") == "A%20 — Â", "çizilebilen karakterler olduğu gibi çizilir (değiştirilmez)")
	check(GameFont._prep("← →") == "< >", "fontta olmayan oklar < > olarak çizilir")
	check(GameFont.width("COMBO", 34) > GameFont.width("COMBO", 17), "yazı genişliği boyutla büyüyor")
	check(GameFont.YELLOW.r > 0.9 and GameFont.YELLOW.g > 0.7 and GameFont.YELLOW.b < 0.4, "sarı renk sarı")


func _test_damage_number() -> void:
	await _new_world("Hasar sayısı animasyonu")
	var n := DamageNumber.spawn(_world, Vector2(400, 500), 3, 0.5)
	check(n != null and n.amount == 3, "sayı oluştu (3)")
	check(n.base_size > DamageNumber.spawn(_world, Vector2(0, 0), 1).base_size, "büyük hasar daha iri yazılır")
	check(is_equal_approx(DamageNumber.pop_scale(0.0), 0.45), "belirirken küçükten başlar")
	check(DamageNumber.pop_scale(0.5) > 1.0, "belirirken hafif aşırı büyür (pat hissi)")
	check(is_equal_approx(DamageNumber.pop_scale(1.0), 1.0), "sonunda normal boyuta oturur")
	check(is_equal_approx(n.current_alpha(), 1.0), "başta tam görünür")
	check(n.color.r > 0.9 and n.color.g > 0.7 and n.color.b < 0.4, "hasar sayısı sarı")
	await _frames(int(DamageNumber.LIFETIME * 60.0 * 0.8))
	check(is_instance_valid(n) and n.current_alpha() < 1.0, "yaşamının sonuna doğru sönüyor")
	await _frames(40)
	check(not is_instance_valid(n), "süre bitince kendini siliyor")


func _test_combo_counter() -> void:
	await _new_world("Kombo sayacı: sayma, süre, sıfırlama")
	var p := _spawn_player()
	var c := p.combo
	var e := _spawn_dummy_enemy(700.0)
	var ended_log: Array = []
	c.ended.connect(func(h: int, pr: int, d: int) -> void: ended_log.append([h, pr, d]))
	await _frames(10)
	check(c != null and c.hits == 0 and c.parries == 0 and not c.is_active(), "başlangıçta kombo yok")

	e.take_damage(1, p)
	check(c.hits == 1 and c.damage == 1, "ilk vuruş sayıldı (1 vuruş, 1 hasar)")
	check(c.is_active() and not c.is_combo(), "ilk vuruş sıradan: bar var, COMBO yazısı yok")
	check(is_equal_approx(c.time_left, 1.0), "kombo süresi 1 sn")
	check(_count_numbers() == 1, "hasar sayısı çıktı")
	check(c.last_target == e, "gösterge vurulan düşmanı izliyor")

	c.tick(0.6)
	check(is_equal_approx(c.time_left, 0.4) and is_equal_approx(c.fraction(), 0.4), "bar süreyle azalıyor (0.4)")
	e.take_damage(2, p)
	check(c.hits == 2 and c.damage == 3, "ikinci vuruş (2 vuruş, 3 hasar)")
	check(c.is_combo(), "ikinci vuruşta COMBO yazısı çıkar")
	check(is_equal_approx(c.time_left, 1.0), "her vuruş barı tazeler")

	var hb := Hitbox.new()
	hb.source = e
	_world.add_child(hb)
	EventBus.parry_success.emit(p, hb)
	check(c.parries == 1 and c.hits == 2, "parry ayrı sayılıyor (1 parry)")
	check(is_equal_approx(c.time_left, 1.0), "parry de barı tazeler")
	hb.queue_free()

	EventBus.parry_success.emit(e, null)
	check(c.parries == 1, "başkasının parry'si sayılmadı")

	c.tick(0.7)
	e.take_damage(1, e)
	check(c.hits == 2, "oyuncudan gelmeyen hasar kombo yapmaz")
	p.take_damage(1, e)
	check(c.hits == 2, "oyuncunun yediği hasar kombo yapmaz")
	check(is_equal_approx(c.time_left, 0.3), "ve süreyi de tazelemez")

	c.tick(0.35)
	check(not c.is_active(), "süre dolunca kombo bitti")
	check(c.hits == 0 and c.parries == 0 and c.damage == 0, "sayaçlar SIFIRLANDI")
	check(ended_log.size() == 1 and ended_log[0] == [2, 1, 3], "bitiş sinyali son sayıları taşıdı %s" % str(ended_log))

	e.take_damage(1, p)
	check(c.hits == 1 and c.parries == 0 and c.damage == 1, "yeni kombo sıfırdan başladı")

	# Süre bir bekleme ile de (oyun karelerinden) doluyor mu?
	await _frames(75)
	check(not c.is_active() and c.hits == 0, "1 sn boyunca vuruş yoksa kendiliğinden sıfırlandı")

	# Kombo süresi stat'tan okunuyor (eşyalar uzatabilir)
	p.stats.set_base("combo_window", 2.5)
	e.take_damage(1, p)
	check(is_equal_approx(c.time_left, 2.5), "combo_window stat'ı süreyi belirliyor")

	# Ölünce kombo biter
	e.take_damage(1, p)
	check(c.hits == 2, "ölmeden önce 2 vuruş")
	p.die()
	check(not c.is_active() and c.hits == 0, "oyuncu ölünce kombo sıfırlandı")


func _test_combo_real_fight() -> void:
	await _new_world("Kombo: gerçek saldırı ve gerçek parry")
	var p := _spawn_player()
	var e := _spawn_dummy_enemy(690.0, 50)
	await _frames(20)
	p.dash_charges = 0
	var c := p.combo
	var spawned := [0]
	_world.child_entered_tree.connect(func(n: Node) -> void:
		if n is DamageNumber:
			spawned[0] += 1)
	for hit in 3:
		var before := c.hits
		p.intent.attack_pressed = true
		for i in 60:
			await get_tree().physics_frame
			if c.hits > before:
				break
		for i in 40:
			await get_tree().physics_frame
			if p.state != Player.State.ATTACK:
				break
	check(c.hits == 3, "3 gerçek vuruş 3 kez sayıldı (%d)" % c.hits)
	check(c.damage == 4, "toplam hasar 1+1+2 = 4 (%d)" % c.damage)
	check(c.is_combo() and c.is_active(), "3'lü seri bir kombo")
	check(spawned[0] == 3, "her vuruşta bir hasar sayısı çıktı (%d)" % spawned[0])

	# Aynı kombonun içinde gerçek parry: altın mermi hızla gelir
	var src := _dummy_source(1100.0)
	var pr := _spawn_projectile(Vector2(800, 612), Vector2(-600, 0), true, src)
	var pressed := false
	for i in 150:
		await get_tree().physics_frame
		if not pressed and pr.global_position.x - p.global_position.x < 85.0:
			p.intent.parry_pressed = true
			pressed = true
		if c.parries > 0:
			break
	check(c.parries == 1, "gerçek parry kombo sayacına işledi")
	check(c.hits == 3 and c.damage == 4, "aynı kombo sürüyor: vuruşlar sıfırlanmadı (%d vuruş)" % c.hits)
	check(c.events() == 4, "toplam olay 4 (3 vuruş + 1 parry)")


# ------------------------------------------------------------------ parry dalgası ve sesi

func _test_parry_wave() -> void:
	await _new_world("Parry dalgası: ekranı kaplar, menzil dışında soluklaşır")
	var range_px := 48.0
	var view := Vector2(1280, 720)
	var center := Vector2(640, 600)
	var r_max := ParryWave.cover_radius(center, view)
	check(r_max >= center.distance_to(Vector2.ZERO) and r_max >= center.distance_to(view), "kaplama yarıçapı en uzak köşeyi aşıyor (%.0f)" % r_max)
	check(is_equal_approx(ParryWave.ring_alpha_at(range_px * 0.5, range_px), 1.0), "menzil içinde halka tam opak")
	check(is_equal_approx(ParryWave.ring_alpha_at(range_px, range_px), 1.0), "menzil sınırında hâlâ tam opak")
	var outside := ParryWave.ring_alpha_at(range_px * 3.0, range_px)
	check(outside >= 0.1 and outside <= 0.25, "menzil dışında opaklık belirgin düşük (%.2f)" % outside)
	var mid := ParryWave.ring_alpha_at(range_px * 1.4, range_px)
	check(mid < 1.0 and mid > outside, "geçiş yumuşak (%.2f)" % mid)
	var prev := -1.0
	var monotonic := true
	for i in 63:
		var r := ParryWave.radius_at(i * 0.01, range_px, r_max)
		if r < prev - 0.001:
			monotonic = false
		prev = r
	check(monotonic, "dalga yarıçapı hiç küçülmüyor")
	check(ParryWave.radius_at(0.0, range_px, r_max) < range_px, "başlangıçta menzilin içinde")
	check(is_equal_approx(ParryWave.radius_at(ParryWave.INNER_TIME, range_px, r_max), range_px * 1.1), "ilk aşamada menzil kenarına oturuyor")
	check(ParryWave.radius_at(ParryWave.DURATION, range_px, r_max) >= r_max - 0.01, "sonunda ekranı tamamen kaplıyor")
	# büyük menzil (eşya ile) -> dalga yine menzile göre ölçekleniyor
	check(ParryWave.ring_alpha_at(100.0, 140.0) > 0.99 and ParryWave.ring_alpha_at(100.0, 48.0) < 0.5, "opaklık parry menziline göre değişiyor")

	var w := ParryWave.spawn(_world, center, range_px)
	check(w != null and w.layer < 10, "dalga HUD'un altında bir katmanda")
	await _frames(2)
	check(w.current_ring_alpha() > 0.8, "ilk karelerde parlak (%.2f)" % w.current_ring_alpha())
	check(w.current_radius() < range_px * 1.3, "ilk karelerde menzil civarında (%.0f px)" % w.current_radius())
	await _frames(24)
	check(w.current_radius() > range_px * 3.0, "ilerleyen karelerde menzilin çok dışında (%.0f px)" % w.current_radius())
	check(w.current_ring_alpha() < 0.4, "menzil dışında soluk (%.2f)" % w.current_ring_alpha())
	await _frames(8)
	check(w.current_radius() > 500.0, "dalga ekranın büyük bölümünü geçti (%.0f px)" % w.current_radius())
	await _frames(14)
	check(not is_instance_valid(w), "süre bitince kendini siliyor")


func _count_waves() -> int:
	var n := 0
	for c in _world.get_children():
		if c is ParryWave:
			n += 1
	return n


func _test_parry_wave_real() -> void:
	await _new_world("Parry: gerçek parry dalgayı oyuncudan başlatır")
	var p := _spawn_player()
	var src := _dummy_source(1100.0)
	await _frames(20)
	check(_count_waves() == 0, "parry öncesi dalga yok")
	var pr := _spawn_projectile(Vector2(820, 612), Vector2(-360, 0), true, src)
	var pressed := false
	for i in 120:
		await get_tree().physics_frame
		if not pressed and pr.global_position.x - p.global_position.x < 85.0:
			p.intent.parry_pressed = true
			pressed = true
		if _parry_ok > 0:
			break
	await _frames(2)
	check(_parry_ok == 1, "parry başarılı")
	check(_count_waves() == 1, "parry bir dalga başlattı")
	for c in _world.get_children():
		if c is ParryWave:
			var w := c as ParryWave
			check(w.world_pos.distance_to(p.global_position) < 1.0, "dalga oyuncunun olduğu yerden çıkıyor")
			check(is_equal_approx(w.range_world, p.stats.value("parry_zone_radius")), "dalga parry menziline göre ayarlı (%.0f)" % w.range_world)
	# menzil büyütülürse dalga da ona göre
	p.stats.set_base("parry_zone_radius", 90.0)
	await _frames(60)
	var pr2 := _spawn_projectile(Vector2(820, 612), Vector2(-360, 0), true, src)
	_parry_ok = 0
	pressed = false
	for i in 120:
		await get_tree().physics_frame
		if not pressed and pr2.global_position.x - p.global_position.x < 120.0:
			p.intent.parry_pressed = true
			pressed = true
		if _parry_ok > 0:
			break
	await _frames(2)
	var found := false
	for c in _world.get_children():
		if c is ParryWave and is_equal_approx((c as ParryWave).range_world, 90.0):
			found = true
	check(found, "menzil 90 iken dalga da 90'a göre")


func _test_parry_sound() -> void:
	print("\nParry sesi")
	var stream := load("res://assets/sfx/parry.wav") as AudioStreamWAV
	check(stream != null, "parry.wav yüklendi")
	check(stream != null and stream.stereo, "parry sesi stereo")
	check(stream != null and stream.get_length() > 0.7 and stream.get_length() < 1.1, "süre ~0.9 sn (%.2f)" % (stream.get_length() if stream != null else 0.0))
	check(is_equal_approx(Sfx.parry_pitch(1), 1.0), "ilk parry: normal perde")
	check(is_equal_approx(Sfx.parry_pitch(2), pow(2.0, 2.0 / 12.0)), "2. parry: 2 yarım ton yukarı")
	check(is_equal_approx(Sfx.parry_pitch(4), pow(2.0, 7.0 / 12.0)), "4. parry: beşli yukarı")
	var prev := 0.0
	var rising := true
	for i in range(1, 9):
		var pitch := Sfx.parry_pitch(i)
		if pitch <= prev:
			rising = false
		prev = pitch
	check(rising, "art arda parry'lerde perde sürekli yükseliyor")
	check(is_equal_approx(Sfx.parry_pitch(50), Sfx.parry_pitch(8)), "merdivenin sonunda sabit kalıyor")
	check(is_equal_approx(Sfx.parry_pitch(0), 1.0), "geçersiz sayı güvenli")



# ------------------------------------------------------------------ deneme (god) modu

func _f_key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	return e


func _test_god_mode() -> void:
	await _new_world("Deneme modu (F4): can düşmez, dash ve parry bekleme yok")
	GameState.god_mode = false
	var p := _spawn_player()
	await _frames(2)
	check(not GameState.god_mode, "varsayılan: kapalı")
	GameState._unhandled_key_input(_f_key(KEY_F4))
	check(GameState.god_mode, "F4 modu açtı")
	var hp0 := p.health
	p.take_damage(3, null)
	check(p.health == hp0 and not p.dead, "3 hasar aldı ama can düşmedi (%d/%d)" % [p.health, hp0])
	p.take_damage(99, null)
	check(p.health == hp0 and not p.dead, "ölümcül hasar da öldürmedi")
	# dash: şarj bitse de yapılır, harcanmaz
	p.dash_charges = 0
	check(p.can_dash(), "şarjsız bile dash yapılabilir")
	p.intent.dash_pressed = true
	await _frames(2)
	check(p.state == Player.State.DASH, "dash başladı")
	check(p.dash_charges == p.stats.int_value("dash_charges"), "şarjlar anında dolu (%d)" % p.dash_charges)
	await _frames(20)
	var dashes := 0
	for i in 5:
		p.intent.dash_pressed = true
		await _frames(2)
		if p.state == Player.State.DASH:
			dashes += 1
		await _frames(14)
	check(dashes == 5, "art arda 5 dash: hepsi yapıldı (%d)" % dashes)
	# parry: kaçırınca toparlanma neredeyse yok
	p.state = Player.State.MOVE
	await _frames(3)
	p.intent.parry_pressed = true
	await _frames(2)
	check(p.state == Player.State.PARRY, "parry açıldı")
	await _frames(14)
	check(p.state == Player.State.MOVE, "kaçırılan parry'den hemen çıkıldı (%s)" % Player.State.keys()[p.state])
	# kapatınca her şey normale döner
	GameState._unhandled_key_input(_f_key(KEY_F4))
	check(not GameState.god_mode, "F4 tekrar basınca kapandı")
	p.health = 4
	p.invulnerable_t = 0.0
	p.take_damage(1, null)
	check(p.health == 3, "kapalıyken hasar can götürür (%d)" % p.health)
	p.dash_charges = 0
	check(not p.can_dash(), "kapalıyken şarjsız dash yok")
	# Oda atlama artık F6'da
	GameState.god_mode = false
	await _new_world("Deneme modu: HUD rozeti ve oda atlama (F6)")
	var run := _start_run(55)
	await _frames(5)
	check(not run.hud.overlay.god_mode, "rozet kapalı")
	var ann0 := run.hud.announcer.count()
	GameState.god_mode = true
	check(run.hud.overlay.god_mode and run.hud.announcer.count() == ann0 + 1, "açılınca rozet çıktı ve duyuru yapıldı")
	GameState.god_mode = false
	check(not run.hud.overlay.god_mode, "kapanınca rozet gitti")
	await _wait_until(func() -> bool: return run.current_room().alive_count() > 0, 200)
	run._unhandled_key_input(_f_key(KEY_F4))
	check(not run.current_room().is_cleared(), "F4 artık odayı atlamıyor")
	run._unhandled_key_input(_f_key(KEY_F6))
	check(run.current_room().is_cleared(), "F6 odayı temizledi")
	run.queue_free()


# ------------------------------------------------------------------ eşyalar, yemek, altın, zaman durdurma

func _item(item_id: String) -> ItemData:
	return ItemDB.get_item(item_id)


## Slotu/kimliği elle verilen deneme eşyası (veritabanında olmayan).
func _dummy_item(item_id: String, slot: ItemData.Slot = ItemData.Slot.CHARM) -> ItemData:
	var it := ItemData.new()
	it.id = item_id
	it.display_name = item_id
	it.description = "deneme"
	it.slot = slot
	return it


## Çarpışma şekli olmayan sahte düşman saldırısı (parry_success sinyalini elle yollamak için).
func _fake_parry_hitbox(src: Node = null) -> Hitbox:
	var hb := Hitbox.new()
	hb.faction = "enemy"
	hb.source = src
	hb.original_source = src
	_world.add_child(hb)
	return hb


## Gerçek düşman saldırısı (çarpışma şekilli): parry bölgesine ve oyuncunun hurtbox'ına değer.
## Parry'lenince kendini kapatır (gerçek düşmanların yaptığı gibi).
func _enemy_strike(at: Vector2, src: Node = null, parryable: bool = true, dmg: int = 1) -> Hitbox:
	var hb := Hitbox.new()
	hb.faction = "enemy"
	hb.parryable = parryable
	hb.damage = dmg
	hb.source = src
	hb.original_source = src
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	cs.shape = circle
	hb.add_child(cs)
	hb.parried.connect(func(_by: Node) -> void: hb.active = false)
	_world.add_child(hb)
	hb.global_position = at
	return hb


## Ritim metresinin parry'de rastgele can yenileme şansını kapatır (parry'li eşya testleri deterministik kalsın).
func _no_rhythm_heal(p: Player) -> void:
	p.rhythm.heal_chances = [0.0, 0.0, 0.0, 0.0] as Array[float]


## Hareketsiz, çok canlı, para düşürmeyen düşman (yapay zekâsı sersemletilerek susturulmuş).
func _quiet_enemy(at: Vector2) -> Taurus:
	var e := TAURUS.instantiate() as Taurus
	e.max_hp = 99
	e.gold_min = 0
	e.gold_max = 0
	_world.add_child(e)
	e.global_position = at
	e.stun(600.0)
	return e


func _test_items_db() -> void:
	print("\nEşya veritabanı")
	const S := ItemData.Slot
	var all := ItemDB.all()
	check(all.size() == 14, "11 donanım + 3 yemek = 14 eşya (%d)" % all.size())
	var seen := {}
	var fields_ok := true
	var price_ok := true
	var tags_ok := true
	var fx_ok := true
	var known := ["PARRY", "DASH", "MERMI", "ALEV", "BUZ", "ZEHIR", "CAN", "RITIM", "KARMA", "ZAMAN", "ALTIN", "HAREKET", "SAVUNMA"]
	for it in all:
		if seen.has(it.id) or it.id == "" or it.display_name == "" or it.description == "":
			fields_ok = false
		seen[it.id] = true
		if it.price <= 0:
			price_ok = false
		for t in it.tags:
			if not (t in known):
				tags_ok = false
		if it.effect_script != null and not (it.effect_script.new() is ItemEffect):
			fx_ok = false
	check(fields_ok, "kimlik/ad/açıklama dolu, kimlikler tekil")
	check(price_ok, "her eşyanın mağaza fiyatı var")
	check(tags_ok, "etiketler bilinen listeden")
	check(fx_ok, "davranış betikleri ItemEffect'ten türüyor")
	check(ItemDB.get_item("yok_boyle_esya") == null, "olmayan eşya null döner")
	# Slotlar senin listene göre
	var slots := {
		"mirror_boots": S.FEET, "feather_boots": S.FEET,
		"viper_fang": S.CHARM, "stardust_brooch": S.CHARM, "vampire_relic": S.CHARM,
		"guardian_helm": S.HEAD, "watcher_band": S.HEAD,
		"cracked_mirror": S.POCKET, "saturn_hourglass": S.POCKET,
		"thief_chain": S.WRIST, "resin_gloves": S.WRIST,
		"tower_bread": S.FOOD, "baked_sweet_potato": S.FOOD, "cosmic_star_soup": S.FOOD,
	}
	var slots_ok := true
	for item_id in slots:
		var it := _item(item_id)
		if it == null or it.slot != slots[item_id]:
			slots_ok = false
	check(slots_ok, "her eşya doğru slotta")
	var cap := ItemData.SLOT_CAPACITY
	check(cap[S.FEET] == 1 and cap[S.CHARM] == 3 and cap[S.HEAD] == 2 and cap[S.POCKET] == 1 and cap[S.WRIST] == 1 and cap[S.ARMOR] == 1, "slot sayıları: ayak 1, charm 3, kafa 2, cep 1, bilek 1, zırh 1")
	var shadow_ok := true
	for sid in ["mirror_boots", "feather_boots", "viper_fang", "stardust_brooch", "vampire_relic", "guardian_helm", "watcher_band", "cracked_mirror"]:
		if _item(sid).shadow_text == "":
			shadow_ok = false
	check(shadow_ok, "8 eşyanın 'Gölge alırsa' metni var")
	# Yemekler
	var bread := _item("tower_bread")
	var potato := _item("baked_sweet_potato")
	var soup := _item("cosmic_star_soup")
	check(bread.is_food() and potato.is_food() and soup.is_food() and not bread.is_equippable(), "yemekler takılmaz, yenir")
	check(bread.heal_amount(4) == 1 and potato.heal_amount(4) == 2 and soup.heal_amount(4) == 4 and soup.heal_amount(6) == 6, "yemek miktarları: 1, 2, tam doldur")
	check(not bread.umbra_allowed and not potato.umbra_allowed and not soup.umbra_allowed, "yemekler Umbra'ya gitmez")
	var gear := ItemDB.equipment()
	var no_food := true
	for it in gear:
		if it.is_food():
			no_food = false
	check(gear.size() == 11 and no_food, "donanım havuzu 11 eşya, yemek yok")
	check(GameFont.upper("Kule Ekmeği") == "KULE EKMEĞİ" and GameFont.upper("Satürn'ün Kum Saati") == "SATÜRN'ÜN KUM SAATİ", "Türkçe büyük harf (i -> İ)")
	# Ödül çifti
	var r1 := RandomNumberGenerator.new()
	r1.seed = 7
	var pair := ItemDB.roll_pair(r1, ["viper_fang"], ["guardian_helm"])
	check(pair.size() == 2 and pair[0].id != pair[1].id, "ödül çifti iki farklı eşya")
	check(not (pair[0].id in ["viper_fang", "guardian_helm"]) and not (pair[1].id in ["viper_fang", "guardian_helm"]), "sahip olunan ve Umbra'ya giden eşya çıkmıyor")
	var r2 := RandomNumberGenerator.new()
	r2.seed = 7
	var pair2 := ItemDB.roll_pair(r2, ["viper_fang"], ["guardian_helm"])
	check(pair2[0].id == pair[0].id and pair2[1].id == pair[1].id, "aynı tohum aynı çifti verir")
	var food_free := true
	for sd in 40:
		var rr := RandomNumberGenerator.new()
		rr.seed = sd
		for it in ItemDB.roll_pair(rr):
			if it.is_food():
				food_free = false
	check(food_free, "ödül çiftinde hiç yemek çıkmıyor (40 tohum)")
	var pair3 := ItemDB.roll_pair(r2, ItemDB.ids(), [])
	check(pair3.size() == 2 and pair3[0].id != pair3[1].id, "havuz tükenince de iki farklı eşya (sahip olunanlar dahil)")
	# Umbra'nın eşyaları
	GameState.reset()
	GameState.leave_behind(_item("viper_fang"))
	check(GameState.umbra_has("viper_fang") and GameState.umbra_items.size() == 1, "bırakılan eşya Umbra'ya gitti")
	GameState.reset()
	check(GameState.umbra_items.is_empty() and GameState.umbra_extra_carry == 0, "yeni koşuda sıfırlanır")


func _test_inventory() -> void:
	await _new_world("Envanter: çanta, slotlar, takma/çıkarma, modifier'lar, sinerji")
	const S := ItemData.Slot
	var p := _spawn_player()
	await _frames(2)
	var inv := p.inventory
	check(inv != null and inv.items.is_empty() and inv.bag.is_empty(), "oyuncuda boş envanter var")
	var counts := [0, 0, 0]  # alınan, takılan, çıkarılan
	var on_acq := func(_a: Node, _i: ItemData) -> void: counts[0] += 1
	var on_eq := func(_a: Node, _i: ItemData) -> void: counts[1] += 1
	var on_un := func(_a: Node, _i: ItemData) -> void: counts[2] += 1
	EventBus.item_acquired.connect(on_acq)
	EventBus.item_equipped.connect(on_eq)
	EventBus.item_unequipped.connect(on_un)
	var band := _item("watcher_band")
	var helm := _item("guardian_helm")
	var w0 := p.stats.value("parry_window")
	# çanta -> slot -> çanta
	check(inv.give(band) == "", "eşya çantaya girdi")
	check(inv.bag.size() == 1 and inv.bag_count("watcher_band") == 1 and inv.items.is_empty(), "çantada duruyor, takılı değil")
	check(is_equal_approx(p.stats.value("parry_window"), w0), "çantadaki eşya etki etmez")
	check(inv.equip(band) == "", "takıldı")
	check(inv.has("watcher_band") and inv.bag.is_empty() and inv.items.size() == 1, "takılı listede, çanta boşaldı")
	check(is_equal_approx(p.stats.value("parry_window"), w0 + 0.1), "Gözcü Bandı: parry penceresi +0.1")
	check(inv.slot_free(S.HEAD) == 1 and inv.equipped_in(S.HEAD).size() == 1, "kafa slotunda 1 boş yer kaldı")
	check(inv.unequip(band) == "" and not inv.has("watcher_band") and inv.bag_count("watcher_band") == 1, "çıkarınca çantaya döndü")
	check(is_equal_approx(p.stats.value("parry_window"), w0), "çıkarınca etkisi gitti")
	check(inv.equip(band) == "", "tekrar takıldı")
	check(inv.unequip(helm) == "TAKILI DEĞİL", "takılı olmayan çıkarılamaz")
	check(inv.equip(helm) == "ÇANTADA YOK", "çantada olmayan eşya takılamaz")
	# yemek takılmaz
	var bread := _item("tower_bread")
	inv.give(bread)
	check(inv.equip(bread) == "BU TAKILMAZ", "yemek takılmaz")
	inv.take_from_bag("tower_bread")
	# kafa: 2 slot, aynı eşyadan ikisi takılabilir
	inv.give(helm)
	check(inv.equip(helm) == "" and inv.slot_free(S.HEAD) == 0, "ikinci kafa eşyası takıldı, slotlar doldu")
	inv.give(helm)
	check(inv.equip(helm) == "KAFA SLOTLARI DOLU" and inv.bag_count("guardian_helm") == 1, "3. kafa eşyası reddedildi, çantada kaldı")
	# charm: 3 slot
	var charms: Array[ItemData] = []
	for i in 4:
		charms.append(_dummy_item("test_charm_%d" % i))
	var ok3 := true
	for i in 3:
		inv.give(charms[i])
		if inv.equip(charms[i]) != "":
			ok3 = false
	check(ok3 and inv.slot_free(S.CHARM) == 0, "3 charm takıldı")
	inv.give(charms[3])
	check(inv.equip(charms[3]) == "CHARM SLOTLARI DOLU", "4. charm reddedildi")
	# tek slotlular: ayak, cep
	for pair in [["mirror_boots", "feather_boots", "AYAK"], ["cracked_mirror", "saturn_hourglass", "CEP"]]:
		inv.give(_item(pair[0]))
		inv.give(_item(pair[1]))
		var first := inv.equip(_item(pair[0]))
		var second := inv.equip(_item(pair[1]))
		check(first == "" and second == "%s SLOTLARI DOLU" % pair[2], "%s: tek slot, ikinci eşya reddedildi" % pair[2])
	# add() kısayolu: yer varsa takar, yoksa çantada bırakır
	inv.clear_all()
	check(inv.items.is_empty() and inv.bag.is_empty(), "clear_all her şeyi boşalttı")
	check(is_equal_approx(p.stats.value("parry_window"), w0) and p.stats.int_value("dash_charges") == 2, "boşaltınca tüm etkiler gitti")
	check(inv.add(_item("thief_chain")) == "" and inv.has("thief_chain"), "add: yer varsa hemen takar")
	check(inv.add(_item("thief_chain")) == "" and inv.count("thief_chain") == 1 and inv.bag_count("thief_chain") == 1, "add: slot doluysa çantada bırakır")
	check(inv.add(bread) == "" and inv.bag_count("tower_bread") == 1 and not inv.has("tower_bread"), "add: yemek çantada kalır")
	# sinerji: 3 PARRY etiketli eşya
	inv.clear_all()
	var r0 := p.stats.value("parry_zone_radius")
	inv.add(_item("viper_fang"))
	inv.add(_item("vampire_relic"))
	check(inv.active_synergies().is_empty(), "2 PARRY eşyası: sinerji yok")
	inv.add(band)
	check(inv.active_synergies().has("PARRY"), "3 PARRY eşyası: sinerji açıldı")
	check(is_equal_approx(p.stats.value("parry_zone_radius"), r0 + 6.0) and is_equal_approx(p.stats.value("parry_window"), w0 + 0.12), "sinerji parry bölgesini ve penceresini büyüttü")
	check(inv.remove("watcher_band") and inv.active_synergies().is_empty() and is_equal_approx(p.stats.value("parry_zone_radius"), r0), "eşya çıkınca sinerji de gider")
	check(not inv.remove("yok_boyle_esya"), "olmayan eşya çıkarılamaz")
	# davranış betiği: takılınca bağlanır, çıkınca kopar
	inv.clear_all()
	var base_links := EventBus.parry_success.get_connections().size()
	inv.add(_item("viper_fang"))
	check(EventBus.parry_success.get_connections().size() == base_links + 1, "takılı eşyanın betiği sinyale bağlandı")
	inv.unequip(_item("viper_fang"))
	check(EventBus.parry_success.get_connections().size() == base_links, "çıkarınca bağlantı koptu")
	# çanta kapasitesi
	inv.clear_all()
	var fillers: Array[ItemData] = []
	for i in Inventory.BAG_SIZE:
		fillers.append(_dummy_item("dolgu_%d" % i))
	var all_in := true
	for f in fillers:
		if inv.give(f) != "":
			all_in = false
	check(all_in and inv.bag.size() == Inventory.BAG_SIZE and inv.bag_free() == 0, "çanta %d hücreye kadar doldu" % Inventory.BAG_SIZE)
	check(inv.give(_dummy_item("fazla")) == "ÇANTA DOLU", "dolu çantaya yeni eşya girmez")
	check(inv.give(fillers[0]) == "" and inv.bag_count("dolgu_0") == 2 and inv.bag.size() == Inventory.BAG_SIZE, "aynı eşya dolu çantada bile yığılır")
	# dolu çantada takılıyı çıkarmak
	inv.clear_all()
	var cuff := _dummy_item("bilek_deneme", S.WRIST)
	inv.give(cuff)
	inv.equip(cuff)
	for f in fillers:
		inv.give(f)
	check(inv.unequip(cuff) == "ÇANTA DOLU" and inv.has("bilek_deneme"), "çanta doluyken takılı eşya çıkarılamaz, takılı kalır")
	inv.take_from_bag("dolgu_3")
	check(inv.unequip(cuff) == "" and inv.bag_count("bilek_deneme") == 1, "yer açılınca çıkarılabildi")
	# olaylar
	inv.clear_all()
	counts[0] = 0
	counts[1] = 0
	counts[2] = 0
	inv.give(band)
	inv.equip(band)
	inv.unequip(band)
	check(counts[0] == 1 and counts[1] == 1 and counts[2] == 1, "alma/takma/çıkarma olayları yayıldı %s" % str(counts))
	EventBus.item_acquired.disconnect(on_acq)
	EventBus.item_equipped.disconnect(on_eq)
	EventBus.item_unequipped.disconnect(on_un)


func _test_food_immunity() -> void:
	await _new_world("Yemek ve bağışıklık kalbi: taşan iyileşme mavi kalp olur, bağışıklık varken yemek yenmez")
	var p := _spawn_player()
	await _frames(2)
	var inv := p.inventory
	var bread := _item("tower_bread")
	var potato := _item("baked_sweet_potato")
	var soup := _item("cosmic_star_soup")
	var eaten_log := []
	var on_eat := func(_a: Node, it: ItemData, healed: int, overflow: int) -> void: eaten_log.append([it.id, healed, overflow])
	EventBus.food_eaten.connect(on_eat)
	var imm_events := [0]
	p.immunity_changed.connect(func(_v: int) -> void: imm_events[0] += 1)
	inv.give(bread)
	inv.give(potato)
	inv.give(soup)
	check(p.health == 4 and p.immunity == 0, "tam canla ve bağışıklıksız başlıyor")
	check(inv.use(bread) == "CANIN ZATEN DOLU" and inv.bag_count("tower_bread") == 1, "can doluyken yemek yenmez, çantada kalır")
	# Örnek: 3/4 can + 2 kalplik tatlı patates = can 4 + 1 bağışıklık kalbi
	p.health = 3
	check(inv.use(potato) == "", "tatlı patates yendi")
	check(p.health == 4 and p.immunity == 1, "3/4 can + 2 kalp: can 4, bağışıklık +1 (%d, %d)" % [p.health, p.immunity])
	check(inv.bag_count("baked_sweet_potato") == 0 and eaten_log.size() == 1 and eaten_log[0] == ["baked_sweet_potato", 1, 1], "yemek çantadan düştü, olay doğru bildirildi %s" % str(eaten_log))
	check(imm_events[0] == 1, "bağışıklık sinyali yayıldı")
	# Suistimal engeli: bağışıklık kalbi varken hiçbir yemek yenmez
	p.health = 2
	check(inv.use(bread) == "BAĞIŞIKLIK KALBİ VARKEN YEMEK YENMEZ", "bağışıklık kalbi varken ekmek yenmez")
	check(inv.use(soup) == "BAĞIŞIKLIK KALBİ VARKEN YEMEK YENMEZ", "bağışıklık kalbi varken çorba da yenmez")
	check(p.try_eat(bread) != "" and p.health == 2 and inv.bag_count("tower_bread") == 1 and inv.bag_count("cosmic_star_soup") == 1, "reddedilen yemek harcanmadı, can değişmedi")
	# Hasar önce bağışıklık kalbini götürür
	p.take_damage(1, null)
	check(p.immunity == 0 and p.health == 2, "1 hasar: önce bağışıklık kalbi gitti, can aynı (%d / %d)" % [p.health, p.immunity])
	p.set_immunity(1)
	p.take_damage(2, null)
	check(p.immunity == 0 and p.health == 1, "2 hasar: bağışıklık 1'ini karşıladı, kalan 1 can götürdü (%d)" % p.health)
	# Bağışıklık bitince yemek yine yenir
	check(inv.use(bread) == "" and p.health == 2 and p.immunity == 0, "bağışıklık bitince ekmek yenir (+1 can)")
	check(eaten_log.back() == ["tower_bread", 1, 0], "ekmek: 1 can, taşma yok")
	# Çorba: canı tamamen doldurur, kalan miktar bağışıklık olur
	check(inv.use(soup) == "" and p.health == 4 and p.immunity == 2, "çorba 2/4'te: +2 can, taşan 2 bağışıklık (%d, %d)" % [p.health, p.immunity])
	check(eaten_log.back() == ["cosmic_star_soup", 2, 2], "olay: çorba 2 can + 2 bağışıklık")
	p.set_immunity(0)
	p.health = 1
	inv.give(soup)
	check(inv.use(soup) == "" and p.health == 4 and p.immunity == 1, "çorba 1/4'te: +3 can, taşan 1 bağışıklık (%d, %d)" % [p.health, p.immunity])
	# Ölümcül hasar bağışıklığı da aşar
	p.take_damage(99, null)
	check(p.dead and p.immunity == 0, "ölümcül hasar bağışıklığı da geçti")
	check(p.try_eat(bread) == "ÖLÜSÜN", "ölü yemek yemez")
	EventBus.food_eaten.disconnect(on_eat)
	# Deneme modunda bağışıklık yine karşılar, can yine düşmez
	await _new_world("Bağışıklık: deneme modu ve savunma çarpanı")
	var q := _spawn_player()
	await _frames(2)
	q.set_immunity(2)
	GameState.god_mode = true
	q.take_damage(1, null)
	check(q.immunity == 1 and q.health == 4, "deneme modunda bağışıklık yine harcanır, can düşmez")
	GameState.god_mode = false
	q.inventory.add(_item("guardian_helm"))
	q.set_immunity(0)
	var before := q.health
	q.take_damage(1, null)
	check(q.health == before - 1, "kaskın %%15'i tek hasarı silmez (ilk vuruş: %d)" % q.health)
	# Bağışıklık varken yemek yenmesin kuralı Inventory.use ve Player.try_eat ortak: şarj yemek de çıkmaz
	q.set_immunity(3)
	check(q.try_eat(soup) == "BAĞIŞIKLIK KALBİ VARKEN YEMEK YENMEZ", "3 bağışıklıkla çorba da yenmez")


func _parry_open_frames(p: Player) -> int:
	p.state = Player.State.MOVE
	await _frames(3)
	p.intent.parry_pressed = true
	var n := 0
	for i in 80:
		await get_tree().physics_frame
		if p.state == Player.State.PARRY and not p._parry_recovering:
			n += 1
		elif n > 0:
			break
	await _frames(45)
	return n


func _test_reflex_statuses() -> void:
	await _new_world("Refleks (parry süresi çarpanı) ve durumlar (geçici stat değişiklikleri)")
	var p := _spawn_player()
	await _frames(2)
	check(is_equal_approx(p.stats.value("reflex", 1.0), 1.0), "refleks varsayılan 1.0")
	check(is_equal_approx(p.parry_window_time(), 0.12), "parry süresi 0.12 sn")
	p.stats.add_modifier("t", "reflex", 0.0, 1.5)
	check(is_equal_approx(p.parry_window_time(), 0.18), "refleks x1.5 -> parry 0.18 sn")
	p.stats.remove_modifiers("t")
	p.stats.add_modifier("t", "reflex", 0.0, 0.0)
	check(is_equal_approx(p.parry_window_time(), 0.12 * 0.25), "refleks sıfır olsa da pencere kapanmaz (alt sınır x0.25)")
	p.stats.remove_modifiers("t")
	# Eşya penceresi toplanır, refleks çarpar
	p.stats.add_modifier("band", "parry_window", 0.1, 1.0)
	p.stats.add_modifier("t", "reflex", 0.0, 0.5)
	check(is_equal_approx(p.parry_window_time(), 0.22 * 0.5), "pencere = (0.12 + 0.1) x refleks 0.5")
	p.stats.remove_modifiers("band")
	p.stats.remove_modifiers("t")
	# Gerçek pencere: kaç kare açık kalıyor
	var normal := await _parry_open_frames(p)
	p.stats.add_modifier("t", "reflex", 0.0, 0.5)
	var slow := await _parry_open_frames(p)
	p.stats.remove_modifiers("t")
	p.stats.add_modifier("t", "reflex", 0.0, 2.0)
	var fast := await _parry_open_frames(p)
	p.stats.remove_modifiers("t")
	check(normal >= 7 and normal <= 9, "normal refleks: pencere ~8 kare (%d)" % normal)
	check(slow >= 3 and slow <= 5, "refleks x0.5: pencere ~4 kare (%d)" % slow)
	check(fast >= 14 and fast <= 16, "refleks x2: pencere ~15 kare (%d)" % fast)
	# Durumlar
	var changes := [0]
	p.statuses_changed.connect(func() -> void: changes[0] += 1)
	p.apply_status("yorgun", 2.0, [["reflex", 0.0, 0.5]], "YORGUN")
	check(p.has_status("yorgun") and is_equal_approx(p.stats.value("reflex"), 0.5), "durum başladı, refleks yarıya indi")
	check(p.status_lines().size() == 1 and p.status_lines()[0].begins_with("YORGUN"), "HUD satırı: %s" % str(p.status_lines()))
	p.apply_status("yorgun", 2.0, [["reflex", 0.0, 0.5]], "YORGUN")
	check(is_equal_approx(p.stats.value("reflex"), 0.5), "aynı durum tekrar gelince etki katlanmadı")
	await _frames(70)
	var left := float(p.statuses["yorgun"]["t"]) if p.has_status("yorgun") else -1.0
	check(left > 0.7 and left < 1.0, "durum süresi akıyor (%.2f sn kaldı)" % left)
	await _frames(70)
	check(not p.has_status("yorgun") and is_equal_approx(p.stats.value("reflex"), 1.0), "süre bitince refleks eski haline döndü")
	check(changes[0] == 3, "durum değişim sinyalleri: başla, yenile, bitir (%d)" % changes[0])
	p.apply_status("coskulu", 5.0, [["reflex", 0.0, 1.5]], "COŞKULU")
	p.apply_status("yorgun", 5.0, [["reflex", 0.0, 0.5]])
	check(is_equal_approx(p.stats.value("reflex"), 0.75), "iki farklı durum çarpılır (1.5 x 0.5)")
	check(p.status_lines().size() == 2, "iki durum satırı")
	p.remove_status("yorgun")
	check(is_equal_approx(p.stats.value("reflex"), 1.5) and p.status_lines().size() == 1, "durum elle kaldırılınca yalnız o gider")
	p.apply_status("yok", 0.0, [["reflex", 0.0, 9.0]])
	check(not p.has_status("yok"), "süresi 0 olan durum başlamaz")
	p.take_damage(99, null)
	p.apply_status("olu", 5.0, [["reflex", 0.0, 9.0]])
	check(not p.has_status("olu"), "ölüyken durum başlamaz")


func _test_damage_and_knockback() -> void:
	await _new_world("Hasar çarpanı (Antika Muhafız Kaskı) ve geri itme çarpanı (Yıldız Tozu Broşu)")
	var p := _spawn_player(300.0)
	await _frames(2)
	var inv := p.inventory
	check(p._scale_damage(1) == 1 and p._scale_damage(2) == 2, "kasksız hasar aynen geçer")
	inv.add(_item("guardian_helm"))
	check(is_equal_approx(p.stats.value("damage_taken", 1.0), 0.85), "kask: alınan hasar x0.85")
	var total := 0
	for i in 7:
		total += p._scale_damage(1)
	check(total == 6, "7 tek hasar vuruşundan biri silindi (toplam %d)" % total)
	total = 0
	for i in 100:
		total += p._scale_damage(1)
	check(absi(total - 85) <= 1, "100 tek hasar -> yaklaşık 85 (%d)" % total)
	check(p._scale_damage(0) == 0, "0 hasar 0 kalır")
	# Gerçek hasar yolu
	p.health = 50
	p._damage_carry = 0.0
	for i in 7:
		p.take_damage(1, null)
	check(p.health == 44, "take_damage ile 7 vuruşta 6 can gitti (%d)" % (50 - p.health))
	# İki kask çarpılır
	inv.give(_item("guardian_helm"))
	inv.equip(_item("guardian_helm"))
	check(is_equal_approx(p.stats.value("damage_taken", 1.0), 0.7225), "iki kask: x0.85 x0.85")
	inv.clear_all()
	check(p._scale_damage(3) == 3 and p._damage_carry == 0.0, "kasklar çıkınca hasar tam ve kalıntı sıfır")
	# Düşman hasarı çarpandan etkilenmez (stats yok)
	var e := _quiet_enemy(Vector2(900.0, 612.0))
	var hp0 := e.health
	e.take_damage(2, p)
	check(e.health == hp0 - 2, "düşman hasarı etkilenmedi")
	e.queue_free()
	# Yıldız Tozu Broşu: geri itme x2
	var speeds: Array[float] = []
	for with_brooch in [false, true]:
		inv.clear_all()
		if with_brooch:
			inv.add(_item("stardust_brooch"))
		var t := TAURUS.instantiate() as Taurus
		t.max_hp = 99
		t.gold_min = 0
		t.gold_max = 0
		_world.add_child(t)
		t.global_position = Vector2(900.0, 612.0)
		t.set_physics_process(false)
		await _frames(2)
		var hb := _player_hitbox(p, Vector2(880.0, 612.0))
		t.on_hit_by(hb)
		speeds.append(absf(t.velocity.x))
		hb.queue_free()
		t.queue_free()
	check(speeds[0] > 100.0 and is_equal_approx(speeds[1], speeds[0] * 2.0), "Yıldız Tozu Broşu: geri itme 2 kat (%.0f -> %.0f)" % [speeds[0], speeds[1]])
	# Gölge/Umbra tarafı: düşman vuruşu oyuncuyu aynı mesafede iter (düşmanda çarpan yok)
	check(ActorBase.knockback_mult_of(null) == 1.0 and ActorBase.knockback_mult_of(_dummy_source(0.0)) == 1.0, "kaynak yoksa/aktör değilse çarpan 1")
	inv.clear_all()
	inv.add(_item("stardust_brooch"))
	check(is_equal_approx(ActorBase.knockback_mult_of(p), 2.0), "oyuncunun çarpanı 2")


func _test_gold_coins() -> void:
	await _new_world("Altın: toplama, harcama, saçılan paralar, mıknatıs, oda temizlenince çekim, düşman ödülü")
	var p := _spawn_player(400.0)
	await _frames(2)
	var got := [0]
	var on_gold := func(_a: Node, amount: int) -> void: got[0] += amount
	EventBus.gold_collected.connect(on_gold)
	var changes := [0]
	p.gold_changed.connect(func(_t: int) -> void: changes[0] += 1)
	check(p.gold == 0, "altın 0 ile başlar")
	p.add_gold(5)
	check(p.gold == 5 and got[0] == 5 and changes[0] == 1, "5 altın eklendi, olay ve sinyal geldi")
	check(p.spend_gold(3) and p.gold == 2 and changes[0] == 2, "3 altın harcandı")
	check(not p.spend_gold(10) and p.gold == 2, "yetmeyen altın harcanamaz")
	check(not p.spend_gold(-1) and p.gold == 2, "negatif harcama olmaz")
	p.gold = 0
	got[0] = 0
	# Saçılan paralar oyuncuya çekilir
	Coin.drop(_world, p.global_position + Vector2(0.0, -10.0), 3)
	for c in get_tree().get_nodes_in_group("coins"):
		(c as Coin).velocity = Vector2.ZERO
	check(get_tree().get_nodes_in_group("coins").size() == 3, "3 para saçıldı")
	await _frames(12)
	check(p.gold == 0, "doğar doğmaz toplanmaz (kısa gecikme)")
	await _frames(110)
	check(p.gold == 3 and got[0] == 3, "3 küçük para toplandı: +3 (%d)" % p.gold)
	check(get_tree().get_nodes_in_group("coins").is_empty(), "paralar yok oldu")
	# Antika para 3 değerinde
	Coin.drop(_world, p.global_position + Vector2(0.0, -10.0), 2, true)
	for c in get_tree().get_nodes_in_group("coins"):
		(c as Coin).velocity = Vector2.ZERO
		check((c as Coin).antique and (c as Coin).value == Coin.ANTIQUE_VALUE, "antika para değeri %d" % (c as Coin).value)
	await _frames(120)
	check(p.gold == 9, "2 antika para: +6 (%d)" % p.gold)
	# Mıknatıs: yakındaki para çekilir, uzaktaki yerinde kalır
	var near := p.global_position + Vector2(90.0, 26.0)
	var far := p.global_position + Vector2(420.0, 26.0)
	Coin.drop(_world, near, 1)
	Coin.drop(_world, far, 1)
	for c in get_tree().get_nodes_in_group("coins"):
		(c as Coin).velocity = Vector2.ZERO
	await _frames(100)
	check(p.gold == 10, "yakın para mıknatısla çekildi, uzaktaki kaldı (%d)" % p.gold)
	check(get_tree().get_nodes_in_group("coins").size() == 1, "uzaktaki para yerinde duruyor")
	# Oda temizlenince yerde kalan paralar oyuncuya uçar
	EventBus.room_cleared.emit(0)
	await _frames(150)
	check(p.gold == 11 and get_tree().get_nodes_in_group("coins").is_empty(), "oda temizlenince uzaktaki para da toplandı (%d)" % p.gold)
	# Düşman ölünce para düşer
	var e := TAURUS.instantiate() as Taurus
	_world.add_child(e)
	e.global_position = Vector2(1500.0, 612.0)
	e.set_physics_process(false)
	check(e.gold_min == 2 and e.gold_max == 4, "Taurus 2-4 altın düşürür")
	var s := SAGITTA.instantiate() as Sagitta
	var sc := SCORPIUS.instantiate() as Scorpius
	check(s.gold_min == 2 and s.gold_max == 3 and sc.gold_min == 3 and sc.gold_max == 5, "Sagitta 2-3, Scorpius 3-5 altın düşürür")
	s.free()
	sc.free()
	e.gold_min = 3
	e.gold_max = 3
	e.die()
	check(get_tree().get_nodes_in_group("coins").size() == 3, "ölen düşman 3 para düşürdü")
	var bag_total := 0
	for c in get_tree().get_nodes_in_group("coins"):
		bag_total += (c as Coin).value
	check(bag_total == 3, "paralar küçük (değer 1)")
	# Ölü oyuncu altın toplamaz
	EventBus.room_cleared.emit(0)
	p.take_damage(99, null)
	var gold_dead := p.gold
	await _frames(150)
	check(p.gold == gold_dead, "ölü oyuncu altın toplamaz")
	EventBus.gold_collected.disconnect(on_gold)


func _test_item_feet() -> void:
	await _new_world("Ayak eşyaları: Ayna Tabanlı Çizmeler (+1 dash), Hafif Tüy Botlar (yürüme %20 hızlı)")
	var p := _spawn_player(300.0)
	await _frames(30)
	var inv := p.inventory
	check(p.dash_charges == 2 and p.stats.int_value("dash_charges") == 2, "başlangıçta 2 dash")
	inv.add(_item("mirror_boots"))
	check(p.stats.int_value("dash_charges") == 3 and p.dash_charges == 3, "Ayna Tabanlı Çizmeler: 3 dash, yeni şarj dolu geldi")
	inv.unequip(_item("mirror_boots"))
	check(p.stats.int_value("dash_charges") == 2 and p.dash_charges == 2, "çıkarınca 2 dash'e döndü")
	inv.equip(_item("mirror_boots"))
	var made := 0
	for i in 3:
		p.state = Player.State.MOVE
		p.intent.dash_pressed = true
		await _frames(2)
		if p.state == Player.State.DASH:
			made += 1
		await _frames(14)
	check(made == 3 and p.dash_charges == 0, "art arda 3 dash yapıldı (%d), şarj bitti (%d)" % [made, p.dash_charges])
	p.intent.dash_pressed = true
	await _frames(2)
	check(p.state != Player.State.DASH, "4. dash yapılamadı")
	inv.clear_all()
	# Hafif Tüy Botlar: yürüme hızı x1.2
	await _frames(30)
	p.global_position = Vector2(200.0, 612.0)
	p.velocity = Vector2.ZERO
	p.intent.move_x = 1.0
	await _frames(40)
	var v0 := absf(p.velocity.x)
	p.intent.move_x = 0.0
	await _frames(40)
	inv.add(_item("feather_boots"))
	p.global_position = Vector2(200.0, 612.0)
	p.velocity = Vector2.ZERO
	p.intent.move_x = 1.0
	await _frames(40)
	var v1 := absf(p.velocity.x)
	p.intent.move_x = 0.0
	check(is_equal_approx(v0, 290.0) and is_equal_approx(v1, 348.0), "Hafif Tüy Botlar: yürüme hızı %.0f -> %.0f (+%%20)" % [v0, v1])


func _test_item_charms() -> void:
	await _new_world("Charm ve bilek: Engerek Dişi (zehir), Vampir Yadigarı (+3 can), Hırsızın Zinciri (antika para)")
	var p := _spawn_player(300.0)
	_no_rhythm_heal(p)
	await _frames(2)
	var inv := p.inventory
	var e := _quiet_enemy(Vector2(1100.0, 612.0))
	await _frames(2)
	var hb := _fake_parry_hitbox(e)
	# --- Engerek Dişi Kolyesi
	EventBus.parry_success.emit(p, hb)
	check(e.poison_t <= 0.0, "kolyesiz: zehir yok")
	inv.add(_item("viper_fang"))
	EventBus.parry_success.emit(p, hb)
	check(e.poison_t > 1.4 and is_equal_approx(e.poison_dps, 2.0), "Engerek: parry'lenen düşman zehirlendi (%.1f sn, %.0f/sn)" % [e.poison_t, e.poison_dps])
	var hp0 := e.health
	var hits0 := p.combo.hits
	await _frames(100)
	check(hp0 - e.health == 3, "zehir 1.5 sn'de 3 hasar verdi (%d -> %d)" % [hp0, e.health])
	check(e.poison_t <= 0.0, "zehir bitti")
	check(p.combo.hits == hits0, "zehir hasarı kombo saymadı")
	EventBus.parry_success.emit(p, hb)
	await _frames(30)
	EventBus.parry_success.emit(p, hb)
	check(e.poison_t > 1.4 and is_equal_approx(e.poison_dps, 2.0), "tekrar parry zehri yeniledi, hasarı katlamadı (%.1f sn, %.0f/sn)" % [e.poison_t, e.poison_dps])
	e.poison_t = 0.0
	EventBus.parry_success.emit(e, hb)
	check(e.poison_t <= 0.0, "başkasının parry'si zehirlemez")
	inv.remove("viper_fang")
	EventBus.parry_success.emit(p, hb)
	check(e.poison_t <= 0.0, "kolye çıkınca zehir yok")
	# --- Vampir Yadigarı
	var healed := [0]
	var on_heal := func(_a: Node, amount: int) -> void: healed[0] += amount
	EventBus.healed.connect(on_heal)
	p.health = 1
	EventBus.parry_success.emit(p, hb)
	check(p.health == 1, "yadigârsız: parry can vermez")
	inv.add(_item("vampire_relic"))
	EventBus.parry_success.emit(p, hb)
	check(p.health == 4 and healed[0] == 3, "Vampir Yadigarı: parry +3 can (1 -> %d)" % p.health)
	EventBus.parry_success.emit(p, hb)
	check(p.health == 4 and healed[0] == 3, "tam canda fazladan can verilmez")
	p.health = 2
	EventBus.parry_success.emit(e, hb)
	check(p.health == 2, "başkasının parry'si can vermez")
	EventBus.healed.disconnect(on_heal)
	# --- İkisi birden, GERÇEK parry ile
	inv.add(_item("viper_fang"))
	p.health = 1
	e.poison_t = 0.0
	p.intent.parry_pressed = true
	await _frames(2)
	var strike := _enemy_strike(p.global_position + Vector2(20.0, 0.0), e)
	await _frames(4)
	check(p.health == 4 and e.poison_t > 1.0, "gerçek parry: +3 can ve düşman zehirli (can %d, zehir %.1f)" % [p.health, e.poison_t])
	check(not strike.active, "parry'lenen saldırı kapandı")
	inv.clear_all()
	# --- Hırsızın Zinciri (bilek)
	await _frames(40)
	var coins0 := get_tree().get_nodes_in_group("coins").size()
	EventBus.parry_success.emit(p, hb)
	check(get_tree().get_nodes_in_group("coins").size() == coins0, "zincirsiz: para düşmedi")
	inv.add(_item("thief_chain"))
	EventBus.parry_success.emit(p, hb)
	var coins := get_tree().get_nodes_in_group("coins")
	check(coins.size() == coins0 + 1, "Hırsızın Zinciri: parry'lenen düşman 1 antika para düşürdü")
	var coin := coins.back() as Coin
	check(coin != null and coin.antique and coin.value == 3, "düşen para antika (değer 3)")
	EventBus.parry_success.emit(e, hb)
	check(get_tree().get_nodes_in_group("coins").size() == coins0 + 1, "başkasının parry'si para düşürmez")
	coin.global_position = p.global_position + Vector2(0.0, -10.0)
	coin.velocity = Vector2.ZERO
	var gold0 := p.gold
	await _frames(120)
	check(p.gold == gold0 + 3, "antika para toplandı: +3 altın (%d)" % (p.gold - gold0))


func _test_item_cracked_mirror() -> void:
	await _new_world("Çatlak El Aynası: ölümcül darbeyi engeller, 1 can + 2 sn ölümsüzlük, tek kullanımlık")
	GameState.god_mode = false
	var p := _spawn_player(300.0)
	var src := _dummy_source(1100.0)
	await _frames(2)
	var inv := p.inventory
	var consumed := [0]
	var on_c := func(_a: Node, _i: ItemData) -> void: consumed[0] += 1
	EventBus.item_consumed.connect(on_c)
	inv.add(_item("cracked_mirror"))
	check(inv.has("cracked_mirror") and p.death_savers.size() == 1, "ayna takılı ve devrede")
	# Çıkarınca devre dışı
	inv.unequip(_item("cracked_mirror"))
	check(p.death_savers.is_empty(), "çıkarınca devre dışı")
	inv.equip(_item("cracked_mirror"))
	check(p.death_savers.size() == 1, "yeniden takınca devrede")
	# Deneme modunda hasar zaten sıfır: ayna harcanmaz
	GameState.god_mode = true
	p.take_damage(99, null)
	check(inv.has("cracked_mirror") and p.health == 4 and not p.dead, "deneme modunda ayna harcanmadı")
	GameState.god_mode = false
	# Ölümcül gerçek darbe
	var big := _enemy_strike(p.global_position, src, false, 9)
	await _frames(3)
	check(not p.dead and p.health == 1, "ölümcül darbe engellendi, 1 canla kaldı (can %d)" % p.health)
	check(p.invulnerable_t > 1.7, "2 sn dokunulmazlık (%.2f)" % p.invulnerable_t)
	check(consumed[0] == 1 and not inv.has("cracked_mirror") and inv.owned_count("cracked_mirror") == 0, "ayna kırıldı: ne takılı ne çantada")
	check(p.death_savers.is_empty(), "ayna işi bitince devreden çıktı")
	# Dokunulmazken yeni darbe işlemez
	var hb := _enemy_strike(p.global_position, src, false, 1)
	await _frames(4)
	check(p.health == 1 and not p.dead, "dokunulmazken darbe işlemedi")
	hb.queue_free()
	big.queue_free()
	await _frames(130)
	check(p.invulnerable_t <= 0.0, "dokunulmazlık bitti")
	# İkinci ölümcül darbe artık öldürür
	p.take_damage(1, null)
	check(p.dead, "ayna yok: ikinci ölümcül darbe öldürdü")
	EventBus.item_consumed.disconnect(on_c)
	# Bağışıklık kalbi önce karşılar: ayna ancak can gerçekten sıfırlanınca devreye girer
	await _new_world("Çatlak El Aynası + bağışıklık kalbi")
	var q := _spawn_player(300.0)
	await _frames(2)
	q.inventory.add(_item("cracked_mirror"))
	q.set_immunity(2)
	q.take_damage(2, null)
	check(q.health == 4 and q.inventory.has("cracked_mirror"), "bağışıklık hasarı karşıladı, ayna harcanmadı")
	q.take_damage(6, null)
	check(not q.dead and q.health == 1 and not q.inventory.has("cracked_mirror"), "can sıfırlanınca ayna devreye girdi")


func _test_parry_chain() -> void:
	await _new_world("Parry zinciri: parry'nin hemen ardından gelen altın saldırılar da parry'lenir")
	GameState.god_mode = false
	var p := _spawn_player(400.0)
	_no_rhythm_heal(p)
	var src := _dummy_source(1100.0)
	await _frames(20)
	var hp0 := p.health
	# 1) Aynı karede iki altın saldırı
	p.intent.parry_pressed = true
	await _frames(2)
	var a := _enemy_strike(p.global_position + Vector2(24.0, 0.0), src)
	var b := _enemy_strike(p.global_position + Vector2(-24.0, 0.0), src)
	await _frames(4)
	check(_parry_ok == 2 and p.health == hp0, "iki altın saldırı aynı anda parry'lendi, can kaybı yok (%d parry)" % _parry_ok)
	check(not a.active and not b.active, "ikisi de parry'lenince kapandı")
	check(p.combo.parries == 2, "kombo iki parry saydı (%d)" % p.combo.parries)
	# 2) Parry'den ~0.1 sn sonra gelen altın saldırı da zincirle parry'lenir
	await _frames(2)
	var c := _enemy_strike(p.global_position + Vector2(20.0, 0.0), src)
	await _frames(4)
	check(_parry_ok == 3 and not c.active and p.health == hp0, "0.1 sn sonra gelen altın saldırı da parry'lendi (%d)" % _parry_ok)
	check(p.combo.parries == 3, "zincirdeki parry'ler kombo parry sayısına eklendi (%d)" % p.combo.parries)
	# 3) Zincir bitince (0.3 sn) parry'siz altın saldırı hasar verir
	await _frames(40)
	var d := _enemy_strike(p.global_position + Vector2(20.0, 0.0), src)
	await _frames(4)
	check(_parry_ok == 3 and p.health == hp0 - 1, "zincir bitti: parry'siz altın saldırı vurdu (can %d)" % p.health)
	d.queue_free()
	# 4) Kırmızı saldırı zincirle de parry'lenmez
	await _frames(90)
	p.intent.parry_pressed = true
	await _frames(2)
	var f := _enemy_strike(p.global_position + Vector2(20.0, 0.0), src)
	await _frames(3)
	var parries_before := _parry_ok
	var red := _enemy_strike(p.global_position + Vector2(-20.0, 0.0), src, false, 1)
	await _frames(4)
	check(_parry_ok == parries_before and red.active, "kırmızı saldırı zincirle parry'lenmedi")
	f.queue_free()
	red.queue_free()


func _test_time_stop() -> void:
	await _new_world("Zaman durdurma: düşmanlar, mermiler, saldırılar donar; oyuncu ve altın akar")
	GameState.god_mode = false
	TimeStop.reset()
	var p := _spawn_player(300.0)
	var src := _dummy_source(1200.0)
	var e := TAURUS.instantiate() as Taurus
	e.max_hp = 99
	e.gold_min = 0
	e.gold_max = 0
	_world.add_child(e)
	e.global_position = Vector2(1300.0, 612.0)
	await _frames(5)
	var fired := [0, 0]
	var on_start := func(_d: float) -> void: fired[0] += 1
	var on_end := func() -> void: fired[1] += 1
	TimeStop.started.connect(on_start)
	TimeStop.ended.connect(on_end)
	check(not TimeStop.active and TimeStop.progress() == 0.0, "başlangıçta zaman akıyor")
	var x0 := e.global_position.x
	await _frames(10)
	check(absf(e.global_position.x - x0) > 5.0, "önce düşman yürüyor (%.0f -> %.0f)" % [x0, e.global_position.x])
	var pr := _spawn_projectile(Vector2(800.0, 560.0), Vector2(-80.0, 0.0), true, src)
	await _frames(5)
	var pr_x := pr.global_position.x
	check(pr_x < 800.0, "önce mermi ilerliyor")
	# --- durdur
	TimeStop.start(1.0)
	check(TimeStop.active and is_equal_approx(TimeStop.remaining, 1.0) and fired[0] == 1, "zaman durdu (sinyal geldi)")
	check(is_equal_approx(TimeStop.progress(), 1.0), "ilerleme 1.0")
	var ex := e.global_position.x
	var px := p.global_position.x
	p.intent.move_x = 1.0
	await _frames(30)
	check(is_equal_approx(e.global_position.x, ex), "düşman donuk (%.1f -> %.1f)" % [ex, e.global_position.x])
	check(is_equal_approx(pr.global_position.x, pr_x), "mermi havada asılı")
	check(p.global_position.x > px + 60.0, "oyuncu hareket ediyor (+%.0f px)" % (p.global_position.x - px))
	check(TimeStop.progress() > 0.4 and TimeStop.progress() < 0.6, "yarısı geçti (%.2f)" % TimeStop.progress())
	check(e.tint.b > e.tint.r, "düşman buz mavisi tonda (%s)" % str(e.tint))
	p.intent.move_x = 0.0
	# Düşman saldırıları vurmaz
	var strike := _enemy_strike(p.global_position, src, false, 1)
	var hp := p.health
	await _frames(10)
	check(p.health == hp, "zaman durmuşken düşman saldırısı vurmadı")
	# Paralar akmaya devam eder
	Coin.drop(_world, p.global_position + Vector2(0.0, -200.0), 1)
	var coin := get_tree().get_nodes_in_group("coins").back() as Coin
	coin.velocity = Vector2.ZERO
	var cy := coin.global_position.y
	await _frames(8)
	check(coin.global_position.y > cy + 5.0, "para düşmeye devam etti")
	coin.queue_free()
	# --- süre doldu
	await _frames(35)
	check(not TimeStop.active and fired[1] == 1, "süre dolunca zaman aktı (sinyal geldi)")
	check(TimeStop.progress() == 0.0 and TimeStop.remaining == 0.0, "ilerleme sıfırlandı")
	await _frames(10)
	check(absf(e.global_position.x - ex) > 3.0, "düşman yeniden yürüyor (%.1f -> %.1f)" % [ex, e.global_position.x])
	check(pr.global_position.x < pr_x - 3.0, "mermi yeniden ilerliyor")
	check(p.health < hp, "bekleyen saldırı zaman akınca vurdu")
	strike.queue_free()
	# --- yenileme, erken bitirme, sessiz sıfırlama
	await _frames(70)
	TimeStop.start(2.0)
	await _frames(30)
	TimeStop.start(2.0)
	check(fired[0] == 2 and is_equal_approx(TimeStop.remaining, 2.0), "duruyorken tekrar başlatmak süreyi yeniler, 'started' yeniden yayılmaz")
	TimeStop.stop()
	check(not TimeStop.active and fired[1] == 2, "stop() zamanı erken akıttı")
	TimeStop.start(2.0)
	TimeStop.reset()
	check(not TimeStop.active and fired[1] == 2, "reset() sessizce sıfırladı (ended yayılmadı)")
	TimeStop.start(0.0)
	check(not TimeStop.active, "0 saniyelik durdurma başlamaz")
	TimeStop.started.disconnect(on_start)
	TimeStop.ended.disconnect(on_end)
	# --- donmuş düşmana vurulur, geri itme zaman akınca uygulanır
	await _new_world("Zaman durdurma: donmuş düşmana vurulur, geri itme zaman akınca işler")
	var q := _spawn_player(500.0)
	await _frames(2)
	var t := TAURUS.instantiate() as Taurus
	t.max_hp = 99
	t.gold_min = 0
	t.gold_max = 0
	_world.add_child(t)
	t.global_position = Vector2(560.0, 612.0)
	await _frames(2)
	TimeStop.start(3.0)
	q.facing = 1
	var thp := t.health
	var tx := t.global_position.x
	q.intent.attack_pressed = true
	await _frames(14)
	check(t.health < thp, "donmuş düşman vuruldu (%d -> %d)" % [thp, t.health])
	check(is_equal_approx(t.global_position.x, tx), "ama yerinden oynamadı")
	check(absf(t.velocity.x) > 10.0, "geri itme bekliyor (%.0f)" % t.velocity.x)
	TimeStop.stop()
	await _frames(8)
	check(t.global_position.x > tx + 2.0, "zaman akınca geri itildi (%.1f -> %.1f)" % [tx, t.global_position.x])
	TimeStop.reset()
	# --- oda: dalga başlamaz
	await _new_world("Zaman durdurma: oda sayacı ve doğma işaretleri de donar")
	var run := _start_run(88)
	await _frames(3)
	TimeStop.start(5.0)
	await _frames(100)
	check(run.current_room().wave_number == 0 and run.current_room().alive_count() == 0, "zaman durmuşken dalga başlamadı")
	TimeStop.stop()
	check(await _wait_until(func() -> bool: return run.current_room().wave_number >= 1, 200), "zaman akınca dalga başladı")
	# Doğma işareti donar
	TimeStop.start(2.0)
	var markers := get_tree().get_nodes_in_group("enemies").size()
	await _frames(100)
	check(get_tree().get_nodes_in_group("enemies").size() == markers, "zaman durmuşken yeni düşman doğmadı")
	TimeStop.reset()
	run.queue_free()


func _test_item_hourglass() -> void:
	await _new_world("Satürn'ün Kum Saati: iki saldırıyı aynı anda parry'le, zaman 1.5 sn dursun")
	GameState.god_mode = false
	TimeStop.reset()
	var p := _spawn_player(400.0)
	_no_rhythm_heal(p)
	var src := _dummy_source(1100.0)
	await _frames(20)
	var inv := p.inventory
	var hb := _fake_parry_hitbox(src)
	# Kum saatsiz: iki parry zamanı durdurmaz
	EventBus.parry_success.emit(p, hb)
	EventBus.parry_success.emit(p, hb)
	check(not TimeStop.active, "kum saatsiz: iki parry zamanı durdurmaz")
	inv.add(_item("saturn_hourglass"))
	check(inv.has("saturn_hourglass") and inv.status_lines().is_empty(), "kum saati takılı, zaman akıyor")
	EventBus.parry_success.emit(p, hb)
	check(not TimeStop.active, "tek parry zamanı durdurmaz")
	await _frames(30)
	EventBus.parry_success.emit(p, hb)
	check(not TimeStop.active, "0.5 sn arayla iki parry zamanı durdurmaz")
	await _frames(40)
	EventBus.parry_success.emit(p, hb)
	EventBus.parry_success.emit(p, hb)
	check(TimeStop.active and is_equal_approx(TimeStop.remaining, 1.5), "aynı anda iki parry: zaman 1.5 sn durdu (%.2f)" % TimeStop.remaining)
	check(inv.status_lines().size() == 1 and inv.status_lines()[0] == "ZAMAN DURDU", "HUD yazısı: ZAMAN DURDU")
	await _frames(95)
	check(not TimeStop.active, "1.5 sn sonra zaman aktı")
	# Başkasının parry'si sayılmaz
	var other := _dummy_source(0.0)
	EventBus.parry_success.emit(other, hb)
	EventBus.parry_success.emit(other, hb)
	check(not TimeStop.active, "başkasının parry'si zamanı durdurmaz")
	# Zamanı durduran parry'den sonra sayaç sıfırlanır: üçüncü parry tek başına durdurmaz
	await _frames(30)
	EventBus.parry_success.emit(p, hb)
	EventBus.parry_success.emit(p, hb)
	TimeStop.stop()
	EventBus.parry_success.emit(p, hb)
	check(not TimeStop.active, "üçüncü parry yeni bir çift sayılmaz")
	# Çıkarınca etkisiz
	await _frames(40)
	inv.unequip(_item("saturn_hourglass"))
	EventBus.parry_success.emit(p, hb)
	EventBus.parry_success.emit(p, hb)
	check(not TimeStop.active, "kum saati çıkarılınca etkisiz")
	inv.equip(_item("saturn_hourglass"))
	# --- GERÇEK: iki altın saldırı parry bölgesinde
	await _frames(60)
	TimeStop.reset()
	var parries0 := _parry_ok
	p.intent.parry_pressed = true
	await _frames(2)
	check(p.state == Player.State.PARRY, "parry açıldı")
	var a := _enemy_strike(p.global_position + Vector2(24.0, 0.0), src)
	var b := _enemy_strike(p.global_position + Vector2(-24.0, 0.0), src)
	await _frames(4)
	check(_parry_ok - parries0 == 2, "iki saldırı da parry'lendi (%d)" % (_parry_ok - parries0))
	check(TimeStop.active, "gerçek çift parry: zaman durdu")
	check(p.health == p.stats.int_value("max_health"), "can kaybı yok")
	a.queue_free()
	b.queue_free()
	await _frames(100)
	check(not TimeStop.active, "süre bitti")
	# --- GERÇEK: tek saldırı = durdurmaz
	await _frames(60)
	p.intent.parry_pressed = true
	await _frames(2)
	var s := _enemy_strike(p.global_position + Vector2(24.0, 0.0), src)
	await _frames(4)
	check(not TimeStop.active and not s.active, "tek saldırıyı parry'lemek zamanı durdurmaz")
	s.queue_free()
	TimeStop.reset()


func _test_run_hud_extras() -> void:
	await _new_world("HUD: bağışıklık kalpleri, altın sayacı, zaman durdu çubuğu, durum satırları, eşya simgeleri")
	GameState.god_mode = false
	TimeStop.reset()
	var run := _start_run(61)
	await _frames(5)
	var p := run.player
	p.stats.set_base("max_health", 4.0)
	p.health = 4
	p.set_immunity(2)
	await _frames(3)
	var hearts := run.hud._hearts
	check(hearts[3].visible and hearts[3].color.r > 0.8 and hearts[3].color.b < 0.4, "4 kırmızı kalp")
	check(hearts[4].visible and hearts[5].visible and hearts[4].color.b > 0.9 and hearts[4].color.r < 0.5, "5. ve 6. kalp mavi (bağışıklık)")
	check(not hearts[6].visible, "7. kalp yok")
	p.set_immunity(0)
	await _frames(3)
	check(not hearts[4].visible, "bağışıklık bitince mavi kalpler kayboldu")
	p.add_gold(7)
	await _frames(3)
	check(run.hud.overlay.gold == 7, "altın sayacı 7")
	p.apply_status("yorgun", 3.0, [["reflex", 0.0, 0.8]], "YORGUN")
	p.inventory.add(_item("watcher_band"))
	await _frames(3)
	check(run.hud.overlay.statuses.size() == 1 and run.hud.overlay.equipped.size() == 1, "durum satırı ve takılı eşya simgesi")
	TimeStop.start(2.0)
	await _frames(12)
	check(run.hud.overlay.time_stop_k > 0.5, "zaman durdu çubuğu doldu (%.2f)" % run.hud.overlay.time_stop_k)
	check(ScreenFx._stop_tint.color.a > 0.02 and ScreenFx._stop_vig.modulate.a > 0.1, "ekran mavi-gri tonlandı")
	TimeStop.stop()
	await _frames(40)
	check(ScreenFx._stop_tint.color.a < 0.01, "zaman akınca ton gitti")
	# Yemek duyurusu
	p.health = 2
	p.inventory.give(_item("baked_sweet_potato"))
	var ann0 := run.hud.announcer.count()
	p.inventory.use(_item("baked_sweet_potato"))
	check(run.hud.announcer.count() == ann0 + 1, "yemek yenince duyuru çıktı")
	p.inventory.add(_item("cracked_mirror"))
	var ann1 := run.hud.announcer.count()
	p.set_immunity(0)
	p.take_damage(99, null)
	check(run.hud.announcer.count() == ann1 + 1, "ayna kırılınca duyuru çıktı")
	TimeStop.reset()
	run.queue_free()


# ------------------------------------------------------------------ sersemleme (vurulan düşman saldıramaz) ve parry oranı

func _player_hitbox(p: Player, at: Vector2, dmg: int = 1) -> Hitbox:
	var hb := Hitbox.new()
	hb.faction = "player"
	hb.damage = dmg
	hb.source = p
	_world.add_child(hb)
	hb.global_position = at
	return hb


func _test_stagger_taurus() -> void:
	await _new_world("Sersemleme: vurulan Taurus'un atılması iptal olur")
	var p := _spawn_player(500.0)
	var b := TAURUS.instantiate() as Taurus
	b.red_chance = 0.0
	b.max_hp = 99
	_world.add_child(b)
	b.global_position = Vector2(620.0, 612.0)
	await _frames(20)
	# 1) Hazırlık (telegraph) sırasında vurulunca iptal
	b._begin_telegraph()
	await _frames(5)
	check(b._phase == Taurus.Phase.TELEGRAPH and b._tell == EnemyBase.Tell.GOLD, "taurus hazırlanıyor, altın uyarı açık")
	b.on_hit_by(_player_hitbox(p, b.global_position + Vector2(-30.0, 0.0)))
	check(b._phase == Taurus.Phase.CHASE, "vurulunca hazırlık iptal oldu (faz %d)" % b._phase)
	check(b._tell == EnemyBase.Tell.NONE, "uyarı söndü")
	check(b.knock_t >= EnemyBase.STAGGER_LIGHT - 0.01, "sersemledi (%.2f sn)" % b.knock_t)
	check(b._cooldown >= 0.7, "hemen yeniden saldırmaz (bekleme %.2f)" % b._cooldown)
	# Sersemlik süresince ve beklemede saldırmaz: 0.6 sn boyunca atılma yok
	var attacked := false
	var hp0 := p.health
	for i in 36:
		await get_tree().physics_frame
		if b._phase == Taurus.Phase.LUNGE or b._phase == Taurus.Phase.TELEGRAPH:
			attacked = true
	check(not attacked and p.health == hp0, "0.6 sn boyunca saldırı yok, can kaybı yok")
	# 2) Atılma (lunge) sırasında vurulunca: hasar veren alan kapanır
	b.knock_t = 0.0
	b._cooldown = 0.0
	b._begin_telegraph()
	b._begin_lunge()
	check(b.attack_hitbox.active, "atılma sırasında saldırı alanı açık")
	b.on_hit_by(_player_hitbox(p, b.global_position + Vector2(-30.0, 0.0)))
	check(not b.attack_hitbox.active, "atılırken vurulunca saldırı alanı kapandı")
	check(b._phase == Taurus.Phase.CHASE, "atılma iptal (faz %d)" % b._phase)
	# 3) Toparlanma (recover) evresinde vurulunca o evre bozulmaz
	b.knock_t = 0.0
	b._phase = Taurus.Phase.RECOVER
	b._timer = 0.8
	b.on_hit_by(_player_hitbox(p, b.global_position + Vector2(-30.0, 0.0)))
	check(b._phase == Taurus.Phase.RECOVER, "toparlanırken vurulunca evre aynı kalır")


func _test_stagger_combo_real() -> void:
	await _new_world("Sersemleme: 5+ vuruşluk kombo sırasında düşman sana saldıramaz")
	var p := _spawn_player(500.0)
	p.facing = 1
	var b := TAURUS.instantiate() as Taurus
	b.red_chance = 1.0  # kırmızı atılma 2 hasar vurur: dokunursa net görülür
	b.max_hp = 99
	_world.add_child(b)
	b.global_position = Vector2(570.0, 612.0)
	await _frames(15)
	var hp0 := p.health
	var hits := [0]
	var last_hp := [b.health]
	var lunged := false
	b._cooldown = 0.0
	b._begin_telegraph()
	for i in 220:
		await get_tree().physics_frame
		if i % 15 == 0 and not p.dead:
			p.intent.attack_pressed = true
		if b.health < last_hp[0]:
			hits[0] += 1
		last_hp[0] = b.health
		if b._phase == Taurus.Phase.LUNGE:
			lunged = true
		# Oyuncu düşmanı kovalasın (kombo sürerken yaklaş)
		var gap := b.global_position.x - p.global_position.x
		p.intent.move_x = 1.0 if gap > 62.0 else 0.0
	p.intent.move_x = 0.0
	check(hits[0] >= 5, "5+ vuruş indirdik (%d)" % hits[0])
	check(not lunged, "kombo boyunca Taurus hiç atılmadı")
	check(p.health == hp0, "oyuncu hasar almadı (%d -> %d)" % [hp0, p.health])


func _test_stagger_sagitta() -> void:
	await _new_world("Sersemleme: nişan alan Sagitta vurulunca ateş etmez")
	var p := _spawn_player(500.0)
	var s := SAGITTA.instantiate() as Sagitta
	s.max_hp = 99
	_world.add_child(s)
	s.global_position = Vector2(800.0, 612.0)
	await _frames(15)
	s._begin_telegraph()
	await _frames(8)
	check(s._phase == Sagitta.Phase.TELEGRAPH, "sagitta nişan alıyor")
	s.on_hit_by(_player_hitbox(p, s.global_position + Vector2(-30.0, 0.0)))
	check(s._phase == Sagitta.Phase.IDLE and s._tell == EnemyBase.Tell.NONE, "nişan iptal, uyarı söndü")
	var shots := 0
	for i in 50:
		await get_tree().physics_frame
		for c in _world.get_children():
			if c is Projectile:
				shots += 1
	check(shots == 0, "iptal edilen atış çıkmadı")


func _test_stagger_rules() -> void:
	await _new_world("Sersemleme kuralları: ağır vuruş, zırh, yanma, sersemlikte süre")
	var p := _spawn_player(300.0)
	var b := TAURUS.instantiate() as Taurus
	b.max_hp = 99
	_world.add_child(b)
	b.global_position = Vector2(900.0, 612.0)
	await _frames(15)
	b.on_hit_by(_player_hitbox(p, b.global_position + Vector2(-30.0, 0.0), 1))
	check(is_equal_approx(b.knock_t, EnemyBase.STAGGER_LIGHT), "hafif vuruş %.2f sn" % b.knock_t)
	b.knock_t = 0.0
	b.on_hit_by(_player_hitbox(p, b.global_position + Vector2(-30.0, 0.0), 2))
	check(is_equal_approx(b.knock_t, EnemyBase.STAGGER_HEAVY), "ağır vuruş (hasar 2) %.2f sn" % b.knock_t)
	# Zırhlı düşman bölünmez
	b.knock_t = 0.0
	b.armored = true
	b._phase = Taurus.Phase.TELEGRAPH
	b.on_hit_by(_player_hitbox(p, b.global_position + Vector2(-30.0, 0.0)))
	check(b.knock_t == 0.0 and b._phase == Taurus.Phase.TELEGRAPH, "zırhlı düşman sersemlemez, saldırısı bölünmez")
	b.armored = false
	b._phase = Taurus.Phase.CHASE
	# Yanma / kaynaksız hasar sersemletmez
	b.knock_t = 0.0
	b.take_damage(1, null)
	check(b.knock_t == 0.0, "yanma gibi kaynaksız hasar sersemletmedi")
	# Sersemlemiş (parry sonrası) düşman vurulunca sersemlik süresi akmaya devam eder
	b.knock_t = 0.0
	b.stun(1.0)
	b.on_hit_by(_player_hitbox(p, b.global_position + Vector2(-30.0, 0.0)))
	var stun0 := b.stun_t
	await _frames(30)
	check(stun0 - b.stun_t > 0.45, "vuruş sırasında da sersemlik süresi akıyor (%.2f -> %.2f)" % [stun0, b.stun_t])
	# Altın uyarı sembolü sadece altın saldırıda
	b.set_tell(EnemyBase.Tell.GOLD)
	check(b.has_tell_symbol(), "altın saldırıda sarı sembol var")
	b.set_tell(EnemyBase.Tell.RED)
	check(not b.has_tell_symbol(), "kırmızı saldırıda sembol (çarpı) yok")
	b.set_tell(EnemyBase.Tell.NONE)
	check(not b.has_tell_symbol(), "uyarı yokken sembol yok")


func _test_parry_ratio() -> void:
	await _new_world("Parry fırsatı seyrek: altın saldırı payı düşük")
	var p := _spawn_player(300.0)
	var b := TAURUS.instantiate() as Taurus
	_world.add_child(b)
	b.global_position = Vector2(900.0, 612.0)
	b.set_physics_process(false)
	b.target = p
	await _frames(5)
	var gold := 0
	var n := 400
	for i in n:
		b._begin_telegraph()
		if not b._red:
			gold += 1
		b._phase = Taurus.Phase.CHASE
		b.set_tell(EnemyBase.Tell.NONE)
	var share := float(gold) / float(n)
	check(share > 0.28 and share < 0.52, "Taurus atılmalarının ~%%40'ı altın (%.0f%%)" % (share * 100.0))
	var s := SAGITTA.instantiate() as Sagitta
	_world.add_child(s)
	s.global_position = Vector2(1000.0, 612.0)
	s.set_physics_process(false)
	await _frames(5)
	var golds := 0
	for i in 12:
		s._begin_telegraph()
		if not s._next_is_red:
			golds += 1
		s._phase = Sagitta.Phase.IDLE
		s.set_tell(EnemyBase.Tell.NONE)
	check(golds == 4, "Sagitta'nın 12 mermisinin 4'ü altın (%d)" % golds)


# ------------------------------------------------------------------ Scorpius (rapier'li vur-kaç düşmanı)

func _spawn_scorpius(x: float, attacks_done: int = 1) -> Scorpius:
	var sc := SCORPIUS.instantiate() as Scorpius
	sc.max_hp = 99
	_world.add_child(sc)
	sc.global_position = Vector2(x, 612.0)
	sc._attacks_done = attacks_done
	sc._decide_t = 999.0  # kendi kendine saldırmasın; testler `_begin_attack` ile başlatır
	return sc


func _test_scorpius_spacing() -> void:
	await _new_world("Scorpius: kılıç menzilini korur (yürür, geri takla atar, köşede dürtüşür)")
	var p := _spawn_player(300.0)
	p.health = 999
	var sc := _spawn_scorpius(900.0)
	await _frames(10)
	# 1) Uzaktayken sakin adımlarla yaklaşır
	var d0 := sc.global_position.x - p.global_position.x
	await _frames(60)
	var d1 := sc.global_position.x - p.global_position.x
	check(d0 - d1 > 100.0 and d0 - d1 < 150.0, "uzaktayken ~130 px/sn yürüyor (%.0f px/sn)" % (d0 - d1))
	for i in 400:
		await get_tree().physics_frame
		if sc.global_position.x - p.global_position.x <= sc.far_range + 2.0:
			break
	var dist := sc.global_position.x - p.global_position.x
	check(dist <= sc.far_range + 4.0 and dist >= sc.close_range, "kılıç menziline girip durdu (%.0f px)" % dist)
	await _frames(40)
	dist = sc.global_position.x - p.global_position.x
	check(absf(dist - sc.ideal_distance) < 45.0, "ideal mesafeye (%.0f) yakın bekliyor: %.0f px" % [sc.ideal_distance, dist])
	check(sc._phase == Scorpius.Phase.SPACING, "hâlâ mesafe kontrolünde")
	# 2) Oyuncu çok yaklaşınca geri takla
	p.global_position.x = sc.global_position.x - 60.0
	sc._hop_cooldown = 0.0
	var flipped := false
	var rotated := false
	var landed_at := -1
	for i in 80:
		await get_tree().physics_frame
		if sc._phase == Scorpius.Phase.BACKFLIP:
			flipped = true
			if absf((sc.visual as Node2D).rotation) > 0.5:
				rotated = true
		elif flipped and sc._phase == Scorpius.Phase.SPACING:
			landed_at = i
			break
	check(flipped, "çok yakında geri takla attı")
	check(rotated, "takla sırasında gövde dönüyor (yer tutucu)")
	check(landed_at > 0, "takla bitip mesafe kontrolüne döndü")
	dist = sc.global_position.x - p.global_position.x
	check(dist >= 115.0 and dist <= 185.0, "takladan sonra kılıç menzilinde (%.0f px)" % dist)
	check(sc.facing == -1, "takla sırasında hedefe bakmaya devam etti")
	# 3) Köşeye sıkışınca (arkası duvar) takla atamaz, dürtüşle karşılık verir
	await _new_world("Scorpius: köşeye sıkışınca çaresiz dürtüş")
	var wall := StaticBody2D.new()
	wall.collision_layer = Layers.WORLD
	wall.collision_mask = 0
	var wcs := CollisionShape2D.new()
	var wrs := RectangleShape2D.new()
	wrs.size = Vector2(20.0, 500.0)
	wcs.shape = wrs
	wcs.position = Vector2(850.0, 400.0)
	wall.add_child(wcs)
	_world.add_child(wall)
	var p2 := _spawn_player(740.0)
	p2.health = 999
	var sc2 := _spawn_scorpius(800.0)
	await _frames(10)
	sc2._decide_t = 0.2
	var flipped2 := false
	var attacked := false
	var was_feint := false
	for i in 120:
		await get_tree().physics_frame
		if sc2._phase == Scorpius.Phase.BACKFLIP:
			flipped2 = true
		if sc2._phase == Scorpius.Phase.TELL:
			attacked = true
			was_feint = sc2._feint
			break
	check(not flipped2, "arkası duvarken takla atmadı")
	check(attacked and not was_feint, "köşede gerçek bir dürtüş başlattı")


func _test_scorpius_lunge() -> void:
	await _new_world("Scorpius: gerçek dürtüş (kısa altın uyarı, hızlı hat), sonra geri çekilme")
	var p := _spawn_player(500.0)
	var sc := _spawn_scorpius(635.0)
	await _frames(10)
	var hp0 := p.health
	sc._begin_attack(false)
	await _frames(3)
	check(sc._phase == Scorpius.Phase.TELL and sc._tell == EnemyBase.Tell.GOLD and sc.has_tell_symbol(), "altın uyarı ve sarı sembol")
	check(not sc.attack_hitbox.active, "uyarı sırasında hasar alanı kapalı")
	var lunge_frame := -1
	var retreat_frame := -1
	for i in 120:
		await get_tree().physics_frame
		if lunge_frame < 0 and sc._phase == Scorpius.Phase.LUNGE:
			lunge_frame = i + 3
			check(sc.attack_hitbox.active and sc.attack_hitbox.parryable and sc.attack_hitbox.damage == 1, "dürtüş: altın, parry'lenebilir, 1 hasar")
			check(absf(sc.attack_hitbox.position.x - float(sc.facing) * Scorpius.BLADE_CENTER) < 0.1, "hasar alanı önde (bakılan yönde) ve uzun")
		if lunge_frame >= 0 and sc._phase == Scorpius.Phase.RETREAT:
			retreat_frame = i + 3
			break
	var t_lunge := float(lunge_frame) / 60.0
	check(lunge_frame > 0 and absf(t_lunge - sc.tell_time) < 0.08, "uyarı çok kısa: %.2f sn (hedef %.2f)" % [t_lunge, sc.tell_time])
	check(retreat_frame > lunge_frame and float(retreat_frame - lunge_frame) / 60.0 < 0.2, "dürtüş çok hızlı biter, hemen geri çekilir (%d kare)" % (retreat_frame - lunge_frame))
	check(p.health == hp0 - 1, "parry'lenmeyen dürtüş 1 hasar verdi (%d -> %d)" % [hp0, p.health])
	check(not sc.attack_hitbox.active, "geri çekilirken hasar alanı kapalı")
	var x_retreat_start := sc.global_position.x
	await _frames(40)
	check(sc._phase == Scorpius.Phase.SPACING, "geri çekilme bitip mesafe kontrolüne döndü")
	check(sc.global_position.x - x_retreat_start > 100.0, "oyuncudan uzaklaştı (%.0f px)" % (sc.global_position.x - x_retreat_start))
	check(sc._tell == EnemyBase.Tell.NONE, "uyarı söndü")
	# Dash ile savuşturma: dürtüş boşa gider, yine geri çekilir
	await _new_world("Scorpius: dürtüşe dash (dodge)")
	var p2 := _spawn_player(500.0)
	p2.facing = 1
	var sc2 := _spawn_scorpius(635.0)
	await _frames(10)
	var hp1 := p2.health
	var dodges := [0]
	EventBus.dodge_success.connect(func(_a: Node, _h: Node) -> void: dodges[0] += 1)
	sc2._begin_attack(false)
	var dashed := false
	for i in 120:
		await get_tree().physics_frame
		# Dürtüşten hemen önce dash: dokunulmazlık karesi dürtüşü yakalar
		if not dashed and sc2._phase == Scorpius.Phase.TELL and sc2._timer < 0.03:
			p2.intent.dash_pressed = true
			dashed = true
		if dashed and sc2._attacks_done >= 2:
			break
	check(dashed and sc2._attacks_done >= 2, "dürtüş tamamlandı ve Scorpius yoluna devam etti")
	check(p2.health == hp1, "dürtüşe denk gelen dash hasar yedirmedi (can %d)" % p2.health)
	check(dodges[0] == 1, "dodge sayıldı (%d)" % dodges[0])


func _test_scorpius_parry_stun() -> void:
	await _new_world("Scorpius: gerçek dürtüşü tam zamanında parry'le -> geri çekilemez, 1.5 sn stun")
	var p := _spawn_player(500.0)
	var sc := _spawn_scorpius(635.0)
	await _frames(10)
	var hp0 := p.health
	sc._begin_attack(false)
	var pressed := false
	for i in 120:
		await get_tree().physics_frame
		# Dürtüşten ~0.05 sn önce bas: pencere (0.12 sn) dürtüşü yakalar.
		if not pressed and sc._phase == Scorpius.Phase.TELL and sc._timer < 0.05:
			p.intent.parry_pressed = true
			pressed = true
		if _parry_ok > 0:
			break
	await _frames(2)
	check(pressed and _parry_ok == 1, "dürtüş parry'lendi")
	check(p.health == hp0, "can kaybı yok")
	check(sc.is_stunned() and sc.stun_t > 1.3 and sc.stun_t <= sc.stun_time, "Scorpius %.1f sn sersemledi" % sc.stun_t)
	check(sc._phase == Scorpius.Phase.STUNNED and not sc.attack_hitbox.active, "hasar alanı kapandı")
	var x0 := sc.global_position.x
	await _frames(50)
	check(absf(sc.global_position.x - x0) < 25.0 and sc._phase == Scorpius.Phase.STUNNED, "geri çekilmedi, olduğu yerde (%.0f px kaydı)" % absf(sc.global_position.x - x0))
	# Sersemlemişken vurulursa x1.5 hasar (ve güçlü parry vuruşu)
	var hb := sc.health
	sc.on_hit_by(_player_hitbox(p, sc.global_position + Vector2(-30.0, 0.0), 1))
	check(hb - sc.health == 2, "sersemlemiş düşman 1.5 kat hasar alır (%d)" % (hb - sc.health))
	check(sc.is_stunned(), "vuruş sersemliği bitirmedi")
	await _frames(60)
	check(not sc.is_stunned() and sc._phase == Scorpius.Phase.SPACING, "1.5 sn sonra toparlandı, mesafe kontrolüne döndü")


func _test_scorpius_feint_bait() -> void:
	await _new_world("Scorpius: sahte saldırıya erken parry = arkana geçip sırttan vurur")
	var p := _spawn_player(500.0)
	var sc := _spawn_scorpius(635.0)
	await _frames(10)
	var hp0 := p.health
	var side0 := signf(sc.global_position.x - p.global_position.x)
	sc._begin_attack(true)
	await _frames(5)
	check(sc._feint and sc._tell == EnemyBase.Tell.GOLD and sc.has_tell_symbol(), "sahte saldırı da aynı altın uyarıyla başlar")
	# 0.08 sn'de erken parry
	p.intent.parry_pressed = true
	var vanished := false
	var ghost_layer_ok := false
	var alpha_low := false
	var appeared := -1
	for i in 60:
		await get_tree().physics_frame
		if sc._phase == Scorpius.Phase.VANISH:
			vanished = true
			ghost_layer_ok = sc.collision_layer == 0
			alpha_low = alpha_low or sc.visual_alpha < 0.6
		if vanished and sc._phase == Scorpius.Phase.STAB_TELL:
			appeared = i
			break
	check(vanished, "yem yutulunca kayboldu")
	check(ghost_layer_ok, "kaybolurken gövdesi dokunulmaz")
	check(appeared >= 0, "oyuncunun arkasında belirdi")
	var side1 := signf(sc.global_position.x - p.global_position.x)
	check(side1 == -side0, "oyuncunun öbür yanında (önce %+d, şimdi %+d)" % [int(side0), int(side1)])
	check(absf(absf(sc.global_position.x - p.global_position.x) - Scorpius.STAB_OFFSET) < 6.0, "arkasında ~%.0f px (%.0f)" % [Scorpius.STAB_OFFSET, absf(sc.global_position.x - p.global_position.x)])
	check(sc.collision_layer == Layers.ENEMY and sc.visual_alpha > 0.99, "belirince gövde ve görünüm geri geldi")
	check(sc._tell == EnemyBase.Tell.RED and not sc.has_tell_symbol(), "arkadan vuruş kırmızı (parry'lenemez, sembolsüz)")
	check(sc.facing == -side1, "oyuncuya dönük")
	var stabbed := false
	for i in 60:
		await get_tree().physics_frame
		if sc._phase == Scorpius.Phase.STAB:
			stabbed = true
			check(sc.attack_hitbox.active and not sc.attack_hitbox.parryable, "sırttan vuruş parry'lenemez")
			break
	check(stabbed, "sırttan vurdu")
	await _frames(12)
	check(p.health == hp0 - 1, "erken parry cezası: 1 hasar (%d -> %d)" % [hp0, p.health])
	await _frames(50)
	check(sc._phase == Scorpius.Phase.SPACING and sc._attacks_done == 2, "sonra geri çekilip mesafe kontrolüne döndü")


func _test_scorpius_feint_calm() -> void:
	await _new_world("Scorpius: sahte saldırıda sakin kalırsan boşa çıkar")
	var p := _spawn_player(500.0)
	var sc := _spawn_scorpius(635.0)
	await _frames(10)
	var hp0 := p.health
	sc._begin_attack(true)
	var hitbox_ever := false
	var vanish_ever := false
	var ended := false
	for i in 90:
		await get_tree().physics_frame
		if sc.attack_hitbox.active:
			hitbox_ever = true
		if sc._phase == Scorpius.Phase.VANISH or sc._phase == Scorpius.Phase.STAB:
			vanish_ever = true
		if sc._phase == Scorpius.Phase.FEINT_END or sc._phase == Scorpius.Phase.RETREAT:
			ended = true
	check(ended, "sahte saldırı boşa çıkıp geri çekilmeye geçti")
	check(not hitbox_ever and not vanish_ever, "hasar alanı hiç açılmadı, arkana geçmedi")
	check(p.health == hp0, "can kaybı yok")
	check(sc._tell == EnemyBase.Tell.NONE, "uyarı söndü")
	# Geç basış (gerçek dürtüşü yakalayabilecek zamanda) tuzağa düşmez
	await _new_world("Scorpius: sahte saldırıda geç parry tuzağa düşmez, erken olan düşer (pencereye göre)")
	var p2 := _spawn_player(500.0)
	var sc2 := _spawn_scorpius(635.0)
	await _frames(10)
	var hp1 := p2.health
	sc2._begin_attack(true)
	var vanish2 := false
	var pressed := false
	for i in 60:
		await get_tree().physics_frame
		if not pressed and sc2._phase_t >= sc2._tell_total - 0.10:
			p2.intent.parry_pressed = true
			pressed = true
		if sc2._phase == Scorpius.Phase.VANISH:
			vanish2 = true
	check(pressed and not vanish2, "pencere (%.2f) içinde basılan parry yem sayılmadı" % p2.stats.value("parry_window"))
	check(p2.health == hp1, "can kaybı yok")
	# Pencere büyükse (eşya) "erken" sınırı da öne kayar: 0.2 sn pencerede 0.17 sn'deki basış erken değil
	await _new_world("Scorpius: erken sınırı oyuncunun parry penceresine uyar")
	var p3 := _spawn_player(500.0)
	p3.stats.set_base("parry_window", 0.2)
	var sc3 := _spawn_scorpius(635.0)
	await _frames(10)
	sc3._begin_attack(true)
	var vanish3 := false
	var pressed3 := false
	for i in 60:
		await get_tree().physics_frame
		if not pressed3 and sc3._phase_t >= 0.17:
			p3.intent.parry_pressed = true
			pressed3 = true
		if sc3._phase == Scorpius.Phase.VANISH:
			vanish3 = true
	check(pressed3 and not vanish3, "geniş pencerede (0.20) 0.17 sn'deki basış gerçek dürtüşü yakalardı, yem değil")


func _test_scorpius_rules() -> void:
	await _new_world("Scorpius: sahte saldırı kuralları, vurulunca iptal")
	var p := _spawn_player(300.0)
	var sc := _spawn_scorpius(900.0, 0)
	await _frames(5)
	var any_feint := false
	for i in 60:
		sc._last_feint = false
		if sc._pick_feint():
			any_feint = true
	check(not any_feint, "ilk saldırı hiçbir zaman sahte değil")
	sc._attacks_done = 3
	sc._last_feint = true
	check(not sc._pick_feint() and not sc._last_feint, "bir sahteden sonra gerçek gelir")
	var feints := 0
	for i in 400:
		sc._last_feint = false
		if sc._pick_feint():
			feints += 1
	var share := float(feints) / 400.0
	check(share > 0.25 and share < 0.45, "sahte oranı ~%%35 (%.0f%%)" % (share * 100.0))
	check(is_equal_approx(sc.stun_time, 1.5), "parry stun'ı 1.5 sn")
	check(sc.max_hp == 99 and SCORPIUS.instantiate().max_hp == 3, "sahnede 3 can")
	# Vurulunca hazırlanan dürtüş iptal olur
	sc._attacks_done = 1
	sc.global_position.x = 435.0
	sc.set_physics_process(false)
	sc._begin_attack(false)
	sc.set_physics_process(true)
	await _frames(5)
	check(sc._phase == Scorpius.Phase.TELL, "hazırlanıyor")
	sc.on_hit_by(_player_hitbox(p, sc.global_position + Vector2(-30.0, 0.0)))
	check(sc._phase == Scorpius.Phase.SPACING and sc._tell == EnemyBase.Tell.NONE, "vurulunca dürtüş iptal, uyarı söndü")
	check(not sc.attack_hitbox.active, "hasar alanı kapalı")
	# Dürtüş sırasında vurulunca hasar alanı kapanır
	sc.knock_t = 0.0
	sc._begin_attack(false)
	sc._begin_lunge()
	check(sc.attack_hitbox.active, "dürtüş aktif")
	sc.on_hit_by(_player_hitbox(p, sc.global_position + Vector2(-30.0, 0.0)))
	check(not sc.attack_hitbox.active and sc._phase == Scorpius.Phase.SPACING, "dürtüş sırasında vurulunca iptal")
	# Animasyon seçimi
	sc.knock_t = 0.0
	sc._phase = Scorpius.Phase.TELL
	check(sc.pick_animation() == "telegraph", "uyarı: telegraph animasyonu")
	sc._phase = Scorpius.Phase.BACKFLIP
	check(sc.pick_animation() == "backflip", "takla: backflip animasyonu")
	sc._phase = Scorpius.Phase.STAB
	check(sc.pick_animation() == "stab", "sırttan vuruş: stab animasyonu")
	check(sc.anim_spec().has("backflip") and sc.anim_spec().has("telegraph"), "animasyon tanımı taban + Scorpius'a özgü")


func _test_scorpius_platform() -> void:
	await _new_world("Scorpius: üst platformdaki oyuncuya zıplayıp çıkar")
	_add_platform(PLATFORM_RECT)
	var p := _spawn_player(500.0)
	p.health = 999
	p.global_position = Vector2(500, 490.0 - 26.0)
	var sc := SCORPIUS.instantiate() as Scorpius
	sc.max_hp = 99
	_world.add_child(sc)
	sc.global_position = Vector2(900, 613)
	await _frames(20)
	var reached := false
	var jumped := false
	var attacked_below := false
	for i in 900:
		await get_tree().physics_frame
		if sc.is_on_floor() and sc.feet_y() > 600.0 and sc._phase == Scorpius.Phase.TELL:
			attacked_below = true
		if not sc.is_on_floor() and sc.velocity.y < -200.0:
			jumped = true
		if sc.is_on_floor() and sc.feet_y() < 500.0:
			reached = true
			break
	check(not attacked_below, "altındayken boşuna dürtüş başlatmadı")
	check(jumped and reached, "platforma zıplayıp çıktı (ayak y=%.0f)" % sc.feet_y())


# ------------------------------------------------------------------ envanter ekranı ve F5 menüsü

## Koddan gönderilen klavye olayı: keycode ve physical_keycode ikisi de dolu (ui_* eylemleri keycode ile eşleşir).
func _ui_key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e


func _mouse_click(pos: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.position = pos
	e.pressed = true
	return e


func _mouse_move(pos: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = pos
	return e


func _test_inventory_swap() -> void:
	await _new_world("Envanter: swap_in (tek kapasiteli slotta yer değiştirme), dolu slot, dolu çanta")
	var p := _spawn_player()
	await _frames(2)
	var inv := p.inventory
	var boots := _item("mirror_boots")
	var feather := _item("feather_boots")
	var base_speed := p.stats.value("move_speed")
	var base_dash := p.stats.int_value("dash_charges")
	var events: Array[String] = []
	var on_eq := func(_a: Node, i: ItemData) -> void: events.append("+" + i.id)
	var on_un := func(_a: Node, i: ItemData) -> void: events.append("-" + i.id)
	EventBus.item_equipped.connect(on_eq)
	EventBus.item_unequipped.connect(on_un)
	var changed := [0]
	var on_changed := func() -> void: changed[0] += 1
	inv.changed.connect(on_changed)
	# Reddedilenler
	check(inv.swap_in(_item("tower_bread")) == "BU TAKILMAZ", "yemek takılmaz")
	check(inv.swap_in(boots) == "ÇANTADA YOK", "çantada olmayan eşya takılmaz")
	# Boş slot: sıradan takma
	inv.give(boots)
	check(inv.swap_in(boots) == "" and inv.count("mirror_boots") == 1 and inv.bag.is_empty(), "boş slota takıldı, çanta boşaldı")
	check(p.stats.int_value("dash_charges") == base_dash + 1, "ayna çizmeler +1 dash verdi")
	# Dolu tek kapasiteli slot: yer değiştirme
	inv.give(feather)
	events.clear()
	changed[0] = 0
	check(inv.swap_in(feather) == "", "dolu ayak slotunda yer değiştirdi")
	check(inv.count("feather_boots") == 1 and inv.count("mirror_boots") == 0, "tüy botlar takılı, ayna çizmeler çıktı")
	check(inv.bag.size() == 1 and inv.bag_count("mirror_boots") == 1, "eski eşya çantaya döndü")
	check(p.stats.int_value("dash_charges") == base_dash, "eski eşyanın dash'i gitti")
	check(is_equal_approx(p.stats.value("move_speed"), base_speed * 1.2), "yeni eşyanın hız etkisi geldi")
	check(",".join(events) == "-mirror_boots,+feather_boots", "olaylar: önce çıkar sonra tak (%s)" % ",".join(events))
	check(changed[0] == 1, "tek 'changed' sinyali (%d)" % changed[0])
	# Geri
	check(inv.swap_in(boots) == "" and inv.count("mirror_boots") == 1 and inv.bag_count("feather_boots") == 1, "geri değişti")
	check(is_equal_approx(p.stats.value("move_speed"), base_speed) and p.stats.int_value("dash_charges") == base_dash + 1, "etkiler de geri döndü")
	# Çantada eşyanın başka kopyası varsa yığılır
	inv.give(feather)
	check(inv.bag_count("feather_boots") == 2, "çantada 2 tüy bot")
	check(inv.swap_in(feather) == "" and inv.bag_count("feather_boots") == 1 and inv.bag_count("mirror_boots") == 1 and inv.bag.size() == 2, "yer değiştirme: çanta hücreleri doğru")
	inv.give(boots)
	check(inv.swap_in(boots) == "" and inv.bag_count("feather_boots") == 2 and inv.bag_count("mirror_boots") == 1 and inv.bag.size() == 2, "eski eşya çantadaki yığına eklendi")
	# Çok kapasiteli slot doluysa reddedilir (önce biri elle çıkarılır)
	inv.clear_all()
	for cid in ["viper_fang", "stardust_brooch", "vampire_relic"]:
		inv.add(_item(cid))
	var spare := _dummy_item("yedek_charm")
	inv.give(spare)
	events.clear()
	check(inv.swap_in(spare) == "CHARM SLOTLARI DOLU", "3 charm doluyken 4.sü reddedildi")
	check(inv.equipped_in(ItemData.Slot.CHARM).size() == 3 and inv.bag_count("yedek_charm") == 1 and events.is_empty(), "hiçbir şey değişmedi")
	check(inv.unequip(_item("stardust_brooch")) == "" and inv.swap_in(spare) == "", "bir charm çıkarılınca yenisi takıldı")
	# Dolu çanta: yer değiştirmek için yer yoksa reddedilir
	inv.clear_all()
	inv.add(feather)
	inv.give(boots)
	inv.give(boots)
	for i in Inventory.BAG_SIZE - 1:
		inv.give(_dummy_item("dolgu_%d" % i))
	check(inv.bag.size() == Inventory.BAG_SIZE and inv.bag_free() == 0, "çanta tam dolu (24 hücre)")
	events.clear()
	check(inv.swap_in(boots) == "ÇANTA DOLU", "çanta dolu ve hücre boşalmıyorken yer değiştirme reddedildi")
	check(inv.count("feather_boots") == 1 and inv.bag_count("mirror_boots") == 2 and events.is_empty(), "hiçbir şey değişmedi")
	check(inv.unequip(feather) == "ÇANTA DOLU", "çanta doluyken çıkarma da reddedildi")
	inv.take_from_bag("mirror_boots")
	check(inv.bag_count("mirror_boots") == 1 and inv.bag.size() == Inventory.BAG_SIZE, "tek kopya kaldı, çanta hâlâ dolu")
	check(inv.swap_in(boots) == "" and inv.bag_count("feather_boots") == 1 and inv.bag.size() == Inventory.BAG_SIZE, "tek kopyanın hücresi boşalacağı için yer değiştirildi")
	EventBus.item_equipped.disconnect(on_eq)
	EventBus.item_unequipped.disconnect(on_un)
	inv.changed.disconnect(on_changed)
	inv.clear_all()


func _test_inventory_screen() -> void:
	await _new_world("Envanter ekranı (I / Tab): duraklatma, kutu düzeni, gezinme, tak / çıkar / ye, reddedilenler, fare")
	const S := ItemData.Slot
	GameState.god_mode = false
	TimeStop.reset()
	ItemView.active_menu = null
	var run := _start_run(71)
	await _frames(5)
	var p := run.player
	var inv := p.inventory
	var scr := run.hud.inventory_screen
	check(scr != null and not scr.is_open and not scr.visible and not get_tree().paused, "ekran HUD'da var, kapalı, oyun akıyor")
	check(InputMap.has_action("inventory"), "'inventory' eylemi tanımlı")
	check(run.hud._hint_label.text.contains("I envanter") and run.hud._hint_label.text.contains("F5"), "ipucu satırında I ve F5 yazıyor")
	inv.give(_item("watcher_band"))
	inv.give(_item("viper_fang"))
	inv.give(_item("tower_bread"))
	# Açılış: oyun durur
	var x0 := p.global_position.x
	p.intent.move_x = 1.0
	scr._unhandled_input(_ui_key(KEY_I))
	check(scr.is_open and scr.visible and scr.player == p and get_tree().paused and ItemView.active_menu == scr, "I açtı: oyun durdu, menü aktif")
	await _frames(10)
	check(is_equal_approx(p.global_position.x, x0), "açıkken oyuncu yürümüyor (x %.1f -> %.1f)" % [x0, p.global_position.x])
	# Kutu düzeni
	var slot_total := 0
	for slot in [S.FEET, S.CHARM, S.HEAD, S.POCKET, S.WRIST, S.ARMOR]:
		slot_total += int(ItemData.SLOT_CAPACITY[slot])
	check(scr.cell_count() == slot_total + Inventory.BAG_SIZE and scr.cell_count() == 33, "33 kutu: 9 slot + 24 çanta (%d)" % scr.cell_count())
	var inside := true
	var overlap := false
	for i in scr.cell_count():
		var r := scr.cell_rect(i)
		if not InventoryScreen.PANEL.encloses(r) or r.intersects(InventoryScreen.DETAIL):
			inside = false
		for j in range(i + 1, scr.cell_count()):
			if r.intersects(scr.cell_rect(j)):
				overlap = true
	check(inside, "bütün kutular panelin içinde, ayrıntı paneline taşmıyor")
	check(not overlap, "kutular birbirine binmiyor")
	# Sayılar iki sütunda: en uzun yazılar bile komşu sütuna / ayrıntı paneline taşmamalı
	var col1_w := maxf(GameFont.width("YÜRÜME  9999", InventoryScreen.STATS_SIZE), GameFont.width("ALTIN  99999", InventoryScreen.STATS_SIZE))
	var col2_w := maxf(GameFont.width("REFLEKS  x0.25", InventoryScreen.STATS_SIZE), maxf(GameFont.width("PARRY  0.99 SN", InventoryScreen.STATS_SIZE), GameFont.width("GERİ İTME  x2.0", InventoryScreen.STATS_SIZE)))
	check(col1_w < InventoryScreen.STATS_X2 - 6.0, "1. sütun yazıları 2. sütuna binmiyor (%.0f < %.0f)" % [col1_w, InventoryScreen.STATS_X2])
	check(InventoryScreen.BAG_ORIGIN.x + InventoryScreen.STATS_X2 + col2_w < InventoryScreen.DETAIL.position.x - 6.0, "2. sütun yazıları ayrıntı paneline taşmıyor (sağ kenar %.0f < %.0f)" % [InventoryScreen.BAG_ORIGIN.x + InventoryScreen.STATS_X2 + col2_w, InventoryScreen.DETAIL.position.x])
	var msg_w := GameFont.width("BAĞIŞIKLIK KALBİ VARKEN YEMEK YENMEZ", 24)
	for it in ItemDB.all():
		msg_w = maxf(msg_w, GameFont.width("TAKILDI  " + it.upper_name(), 24))
		msg_w = maxf(msg_w, GameFont.width("ÇANTAYA  " + it.upper_name(), 24))
	check(msg_w < InventoryScreen.MESSAGE_MAX_W, "en uzun işlem mesajı bile alt şeride tam boyda sığıyor (%.0f < %.0f)" % [msg_w, InventoryScreen.MESSAGE_MAX_W])
	check(GameFont.width("Yürüme hızın %20 artar.", 17) > GameFont.width("Yürüme hızın 20 artar.", 17), "'%' fontta var, boş çizilmiyor (yazıya genişlik katıyor)")
	# İlk imleç: çantadaki ilk eşya
	var bag0 := scr.cursor_index()
	check(scr.cursor_item() != null and scr.cursor_item().id == "watcher_band" and scr._cells[bag0]["kind"] == "bag" and scr._cells[bag0]["idx"] == 0, "imleç çantadaki ilk eşyada")
	# Enter: tak
	scr._unhandled_input(_ui_key(KEY_ENTER))
	check(inv.count("watcher_band") == 1 and inv.bag_count("watcher_band") == 0, "Enter: Gözcü Bandı takıldı")
	check(scr._msg == "TAKILDI  " + _item("watcher_band").upper_name() and scr._msg_good, "mesaj: " + scr._msg)
	check(scr.cursor_item() != null and scr.cursor_item().id == "viper_fang", "çanta kaydı: imleç sıradaki eşyada")
	scr._unhandled_input(_ui_key(KEY_E))
	check(inv.count("viper_fang") == 1, "E tuşu da işlem yapar: Engerek Dişi takıldı")
	# Yemek: reddedilenler ve yenmesi
	check(scr.cursor_item() != null and scr.cursor_item().id == "tower_bread", "imleç ekmekte")
	scr._unhandled_input(_ui_key(KEY_ENTER))
	check(inv.bag_count("tower_bread") == 1 and scr._msg == "CANIN ZATEN DOLU" and not scr._msg_good, "can doluyken yemek reddedildi: " + scr._msg)
	p.stats.set_base("max_health", 4.0)
	p.health = 2
	p.set_immunity(1)
	scr._unhandled_input(_ui_key(KEY_ENTER))
	check(inv.bag_count("tower_bread") == 1 and scr._msg == "BAĞIŞIKLIK KALBİ VARKEN YEMEK YENMEZ" and p.health == 2, "bağışıklık kalbi varken yemek reddedildi")
	p.set_immunity(0)
	scr._unhandled_input(_ui_key(KEY_ENTER))
	check(p.health == 3 and inv.bag.is_empty(), "yemek yendi: can 3, çanta boş")
	check(scr._msg == "YENDİ  " + _item("tower_bread").upper_name() and scr._msg_good, "mesaj: " + scr._msg)
	check(scr.cursor_item() == null, "boşalan kutuda imleç")
	scr._unhandled_input(_ui_key(KEY_ENTER))
	check(scr._msg == "BOŞ" and not scr._msg_good, "boş kutu: BOŞ")
	# Gezinme: her hamle seçilen yönde ilerler; bütün kutulara ulaşılır
	var reach := {0: true}
	var queue := [0]
	var strict := true
	while not queue.is_empty():
		var from: int = queue.pop_back()
		for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			scr._cursor = from
			scr._move_cursor(d)
			var to := scr.cursor_index()
			if to == from:
				continue
			if (scr.cell_rect(to).get_center() - scr.cell_rect(from).get_center()).dot(d) <= 0.0:
				strict = false
			if not reach.has(to):
				reach[to] = true
				queue.append(to)
	check(strict, "her hamle seçilen yönde ilerliyor")
	check(reach.size() == scr.cell_count(), "bütün kutulara yön tuşlarıyla ulaşılıyor (%d/%d)" % [reach.size(), scr.cell_count()])
	scr._cursor = bag0
	scr._unhandled_input(_ui_key(KEY_DOWN))
	check(scr.cursor_index() == bag0 + InventoryScreen.BAG_COLUMNS, "aşağı: bir alt çanta satırı")
	scr._unhandled_input(_ui_key(KEY_UP))
	check(scr.cursor_index() == bag0, "yukarı: geri")
	scr._unhandled_input(_ui_key(KEY_D))
	check(scr.cursor_index() == bag0 + 1, "D: sağdaki kutu")
	scr._unhandled_input(_ui_key(KEY_A))
	check(scr.cursor_index() == bag0, "A: soldaki kutu")
	scr._unhandled_input(_ui_key(KEY_LEFT))
	check(scr._cells[scr.cursor_index()]["kind"] == "slot", "çantanın solunda slotlar var: sola gidince slota geçti")
	var right_edge := bag0 + InventoryScreen.BAG_COLUMNS - 1
	scr._cursor = right_edge
	scr._unhandled_input(_ui_key(KEY_RIGHT))
	check(scr.cursor_index() == right_edge, "çantanın sağ kenarında sağa gidilmez")
	# Fare: üstüne gelince imleç gider, tıklayınca işlem yapılır
	var head0 := -1
	for i in scr.cell_count():
		if scr._cells[i]["kind"] == "slot" and scr._cells[i]["slot"] == S.HEAD and scr._cells[i]["idx"] == 0:
			head0 = i
	check(head0 >= 0, "1. kafa slotu bulundu")
	var pos := scr.cell_rect(head0).get_center()
	scr._gui_input(_mouse_move(pos))
	check(scr.cursor_index() == head0 and scr.cursor_item() != null and scr.cursor_item().id == "watcher_band", "fare üstüne gelince imleç slota gitti")
	scr._gui_input(_mouse_click(pos))
	check(inv.count("watcher_band") == 0 and inv.bag_count("watcher_band") == 1, "tıklama: Gözcü Bandı çıkarıldı")
	check(scr._msg == "ÇIKARILDI  " + _item("watcher_band").upper_name() and scr._msg_good, "mesaj: " + scr._msg)
	scr._gui_input(_mouse_click(scr.cell_rect(bag0).get_center()))
	check(inv.count("watcher_band") == 1 and inv.bag.is_empty(), "çanta kutusuna tıklayınca takıldı")
	scr._gui_input(_mouse_click(pos + Vector2(InventoryScreen.CELL + InventoryScreen.GAP, 0.0)))
	check(scr._msg == "BOŞ" and not scr._msg_good, "boş slota tıklama: BOŞ")
	# Yer değiştirme (ayak: tek slot) ve dolu charm slotu
	inv.give(_item("mirror_boots"))
	inv.give(_item("feather_boots"))
	scr._cursor = bag0
	scr.activate()
	check(inv.count("mirror_boots") == 1 and inv.bag_count("feather_boots") == 1, "boş ayak slotuna Ayna Çizmeler takıldı")
	scr.activate()
	check(inv.count("feather_boots") == 1 and inv.bag_count("mirror_boots") == 1, "dolu ayak slotunda yer değiştirildi")
	check(scr._msg == "TAKILDI  " + _item("feather_boots").upper_name(), "mesaj: " + scr._msg)
	inv.take_from_bag("mirror_boots")
	inv.give(_item("stardust_brooch"))
	inv.give(_item("vampire_relic"))
	inv.give(_dummy_item("yedek_charm"))
	scr.activate()
	scr.activate()
	check(inv.equipped_in(S.CHARM).size() == 3, "3 charm takıldı")
	scr.activate()
	check(scr._msg == "CHARM SLOTLARI DOLU" and not scr._msg_good and inv.bag_count("yedek_charm") == 1, "4. charm reddedildi: " + scr._msg)
	# Kapatma
	scr._unhandled_input(_ui_key(KEY_ESCAPE))
	check(not scr.is_open and not scr.visible and not get_tree().paused and ItemView.active_menu == null, "Esc kapattı: oyun devam ediyor")
	await _frames(12)
	check(p.global_position.x > x0 + 3.0, "kapanınca oyuncu yürümeye devam etti (x %.1f -> %.1f)" % [x0, p.global_position.x])
	p.intent.move_x = 0.0
	scr._unhandled_input(_ui_key(KEY_TAB))
	check(scr.is_open, "Tab açtı")
	scr._unhandled_input(_ui_key(KEY_I))
	check(not scr.is_open and not get_tree().paused, "I kapattı")
	check(scr.open(p), "open() doğrudan çağrılabiliyor")
	scr._gui_input(_mouse_click(Vector2(8.0, 8.0)))
	check(not scr.is_open and not get_tree().paused, "panelin dışına tıklayınca kapandı")
	# Açılmaması gereken durumlar
	p.dead = true
	check(not scr.open(p) and not scr.is_open, "ölüyken açılmaz")
	scr._unhandled_input(_ui_key(KEY_I))
	check(not scr.is_open and not get_tree().paused, "ölüyken I tuşu da açmaz")
	p.dead = false
	var dm := run.hud.dev_menu
	check(dm.open(p) and ItemView.active_menu == dm, "F5 menüsü açıldı")
	check(not scr.open(p), "başka menü açıkken envanter açılmaz")
	scr._unhandled_input(_ui_key(KEY_I))
	check(not scr.is_open, "başka menü açıkken I tuşu bir şey yapmaz")
	dm.close()
	check(not get_tree().paused and ItemView.active_menu == null, "F5 menüsü kapanınca oyun devam ediyor")
	# Menü açıkken sahne kapanırsa oyun kilitli kalmamalı
	check(scr.open(p) and get_tree().paused, "yeniden açıldı")
	run.queue_free()
	await _frames(4)
	check(not get_tree().paused and ItemView.active_menu == null, "sahne kapanınca duraklatma kalktı")


func _test_dev_menu() -> void:
	await _new_world("F5 deneme menüsü: aç / kapa, gezinme, ekle (tak / çantaya), G H B C, fare")
	const S := ItemData.Slot
	GameState.god_mode = false
	TimeStop.reset()
	ItemView.active_menu = null
	var run := _start_run(72)
	await _frames(5)
	var p := run.player
	var inv := p.inventory
	var dm := run.hud.dev_menu
	check(dm != null and not dm.is_open and not dm.visible, "F5 menüsü HUD'da var, kapalı")
	dm._unhandled_input(_f_key(KEY_F5))
	check(dm.is_open and dm.visible and get_tree().paused and ItemView.active_menu == dm, "F5 açtı ve oyunu durdurdu")
	check(dm._entries.size() == ItemDB.all().size(), "menüde bütün eşyalar var (%d)" % dm._entries.size())
	check(dm._rows.size() == dm._entries.size() + 6, "6 slot grubu başlığı (zırhta eşya yok): %d satır" % dm._rows.size())
	check(dm._rows.size() <= dm._visible_rows(), "bütün satırlar kaydırmadan sığıyor (%d satır, %d görünür)" % [dm._rows.size(), dm._visible_rows()])
	check(dm.selected_item() != null and dm.selected_item().slot == S.FEET, "imleç ilk gruptaki (ayak) eşyada")
	# Gezinme
	dm._unhandled_input(_ui_key(KEY_DOWN))
	check(dm._sel == 1, "aşağı: 2. eşya")
	dm._unhandled_input(_ui_key(KEY_S))
	check(dm._sel == 2, "S: 3. eşya")
	dm._unhandled_input(_ui_key(KEY_W))
	dm._unhandled_input(_ui_key(KEY_UP))
	check(dm._sel == 0, "yukarı: başa döndü")
	dm._unhandled_input(_ui_key(KEY_UP))
	check(dm._sel == 0, "en üstte yukarı: sabit")
	dm._unhandled_input(_ui_key(KEY_END))
	check(dm._sel == dm._entries.size() - 1 and dm.selected_item().is_food(), "End: son eşya (yemek)")
	var row := dm._row_of_entry(dm._sel)
	check(row >= dm._scroll and row < dm._scroll + dm._visible_rows(), "seçili satır görünür alanda (satır %d, kaydırma %d)" % [row, dm._scroll])
	dm._unhandled_input(_ui_key(KEY_HOME))
	check(dm._sel == 0 and dm._scroll == 0, "Home: başa dön, kaydırma sıfır")
	# Kaydırma: liste kısalınca (eşya sayısı artınca olacağı gibi) imleç görünür kalır
	dm._list_h = DevMenu.ROW_H * 6.0
	dm._unhandled_input(_ui_key(KEY_END))
	row = dm._row_of_entry(dm._sel)
	check(dm._scroll > 0 and row >= dm._scroll and row < dm._scroll + dm._visible_rows(), "kısa listede End: kaydı, seçili satır görünür (satır %d, kaydırma %d)" % [row, dm._scroll])
	dm._unhandled_input(_ui_key(KEY_HOME))
	check(dm._sel == 0 and dm._scroll == 0, "kısa listede Home: başa döndü, kaydırma sıfır")
	dm._list_h = DevMenu.LIST.size.y
	# Ekle: Enter = ekle, boşsa tak
	var first := dm.selected_item()
	dm._unhandled_input(_ui_key(KEY_ENTER))
	check(inv.count(first.id) == 1 and inv.bag.is_empty(), "Enter: ilk eşya eklendi ve takıldı")
	check(dm._msg == "TAKILDI  " + first.upper_name() and dm._msg_good, "mesaj: " + dm._msg)
	dm._unhandled_input(_ui_key(KEY_ENTER))
	check(inv.count(first.id) == 1 and inv.bag_count(first.id) == 1, "ikinci Enter: slot dolu, kopya çantaya girdi")
	check(dm._msg == "ÇANTAYA  " + first.upper_name(), "mesaj: " + dm._msg)
	# T: yalnız çantaya
	check(dm.select_item("viper_fang"), "Engerek Dişi menüde")
	dm._unhandled_input(_ui_key(KEY_T))
	check(inv.count("viper_fang") == 0 and inv.bag_count("viper_fang") == 1, "T: takılmadan çantaya girdi")
	# Yemek: çantaya
	check(dm.select_item("tower_bread"), "Kule Ekmeği menüde")
	dm._unhandled_input(_ui_key(KEY_E))
	check(inv.bag_count("tower_bread") == 1 and inv.count("tower_bread") == 0, "yemek çantaya girdi (takılmaz)")
	# G, H, B
	var gold0 := p.gold
	dm._unhandled_input(_ui_key(KEY_G))
	check(p.gold == gold0 + DevMenu.GOLD_STEP, "G: +%d altın (%d)" % [DevMenu.GOLD_STEP, p.gold])
	p.stats.set_base("max_health", 4.0)
	p.health = 1
	dm._unhandled_input(_ui_key(KEY_H))
	check(p.health == 4 and dm._msg == "CAN DOLDU" and dm._msg_good, "H: can doldu")
	dm._unhandled_input(_ui_key(KEY_H))
	check(p.health == 4 and dm._msg == "CAN ZATEN DOLU" and not dm._msg_good, "H: zaten doluysa uyarı")
	dm._unhandled_input(_ui_key(KEY_B))
	check(p.immunity == 1, "B: +1 bağışıklık kalbi")
	dm._unhandled_input(_ui_key(KEY_B))
	check(p.immunity == 2, "B tekrar: 2 bağışıklık")
	p.set_immunity(0)
	# Dolu çanta
	inv.clear_all()
	for i in Inventory.BAG_SIZE:
		inv.give(_dummy_item("dolgu_%d" % i))
	check(dm.select_item("stardust_brooch"), "Yıldız Tozu Broşu menüde")
	dm._unhandled_input(_ui_key(KEY_ENTER))
	check(inv.owned_count("stardust_brooch") == 0 and dm._msg == "ÇANTA DOLU" and not dm._msg_good, "çanta doluyken ekleme reddedildi: " + dm._msg)
	# C: hepsini sil
	dm._unhandled_input(_ui_key(KEY_C))
	check(inv.items.is_empty() and inv.bag.is_empty(), "C: çanta ve slotlar boşaldı")
	# Fare
	dm._unhandled_input(_ui_key(KEY_HOME))
	var entry_row := dm._row_of_entry(2)
	var pos := Vector2(DevMenu.LIST.position.x + 120.0, DevMenu.LIST.position.y + float(entry_row - dm._scroll) * DevMenu.ROW_H + DevMenu.ROW_H * 0.5)
	dm._gui_input(_mouse_move(pos))
	check(dm._sel == 2, "fare üstüne gelince satır seçildi")
	dm._gui_input(_mouse_click(pos))
	check(inv.owned_count(dm._entries[2].id) == 1, "tıklama: eşya eklendi (%s)" % dm._entries[2].id)
	dm._gui_input(_mouse_click(Vector2(DevMenu.LIST.position.x + 60.0, DevMenu.LIST.position.y + 10.0)))
	check(dm.is_open, "başlık satırına tıklamak kapatmaz")
	dm._list_h = DevMenu.ROW_H * 16.0  # 20 satır 16'lık pencerede: en çok 4 satır kayar
	dm._gui_input(_mouse_click(pos, MOUSE_BUTTON_WHEEL_DOWN))
	check(dm._scroll == 2, "tekerlek aşağı: 2 satır kaydı (%d)" % dm._scroll)
	dm._gui_input(_mouse_click(pos, MOUSE_BUTTON_WHEEL_DOWN))
	check(dm._scroll == dm._rows.size() - dm._visible_rows(), "kaydırma en alt sınırda durdu (%d)" % dm._scroll)
	dm._gui_input(_mouse_click(pos, MOUSE_BUTTON_WHEEL_UP))
	dm._gui_input(_mouse_click(pos, MOUSE_BUTTON_WHEEL_UP))
	dm._gui_input(_mouse_click(pos, MOUSE_BUTTON_WHEEL_UP))
	check(dm._scroll == 0, "tekerlek yukarı: en üste döndü")
	# Karşılıklı dışlama
	var scr := run.hud.inventory_screen
	check(not scr.open(p), "F5 menüsü açıkken envanter ekranı açılmaz")
	dm._unhandled_input(_ui_key(KEY_I))
	check(not scr.is_open and dm.is_open, "F5 menüsünde I tuşu bir şey yapmaz")
	# Kapatma
	dm._unhandled_input(_f_key(KEY_F5))
	check(not dm.is_open and not dm.visible and not get_tree().paused and ItemView.active_menu == null, "F5 kapattı: oyun devam ediyor")
	dm._unhandled_input(_f_key(KEY_F5))
	check(dm.is_open, "F5 yeniden açtı")
	dm._unhandled_input(_ui_key(KEY_ESCAPE))
	check(not dm.is_open and not get_tree().paused, "Esc kapattı")
	check(dm.open(p), "yeniden açıldı")
	dm._gui_input(_mouse_click(Vector2(6.0, 6.0)))
	check(not dm.is_open and not get_tree().paused, "panelin dışına tıklayınca kapandı")
	# F5 ölüyken açılmaz
	p.dead = true
	dm._unhandled_input(_f_key(KEY_F5))
	check(not dm.is_open and not get_tree().paused, "ölüyken F5 açmaz")
	p.dead = false
	run.queue_free()
	await _frames(3)


# ------------------------------------------------------------------ zorluk seviyeleri ve tur ölçeklemesi

const SCALE_UP_FIELDS := ["hp", "damage", "speed", "gold", "red", "reach", "kite", "patience", "punish", "lead", "feint"]
const SCALE_DOWN_FIELDS := ["cooldown", "telegraph", "recover", "stun"]
## Toplanan (çarpan olmayan) profil anahtarları: NORMAL'de 0'dır.
const ADDITIVE_KEYS := ["red", "patience", "punish", "lead", "feint"]


func _test_difficulty_profiles() -> void:
	print("\nZorluk: 4 seviye; Normal etkisiz, sıralama Easy < Normal < Difficult < Immortal")
	check(Difficulty.count() == 4, "4 zorluk seviyesi")
	check(Difficulty.NAMES == ["EASY", "NORMAL", "DIFFICULT", "IMMORTAL"], "menü adları: " + str(Difficulty.NAMES))
	check(Difficulty.DEFAULT == Difficulty.Level.NORMAL, "varsayılan seviye NORMAL")
	check(GameState.difficulty == Difficulty.Level.NORMAL, "oyun durumu NORMAL'le başlıyor")
	GameState.reset()
	check(GameState.difficulty == Difficulty.Level.NORMAL, "reset() zorluğu değiştirmez")
	# Her profilin anahtar kümesi aynı; hepsi ya "büyüdükçe zor" ya "küçüldükçe zor" diye sınıflı
	var keys: Array = Difficulty.profile(0).keys()
	var same := true
	for lv in Difficulty.count():
		var prof := Difficulty.profile(lv)
		if prof.size() != keys.size():
			same = false
		for k in keys:
			if not prof.has(k):
				same = false
	check(same, "bütün profillerde aynı %d anahtar var" % keys.size())
	var classified := {}
	for k in Difficulty.HARDER_UP:
		classified[k] = true
	for k in Difficulty.HARDER_DOWN:
		classified[k] = true
	check(classified.size() == Difficulty.HARDER_UP.size() + Difficulty.HARDER_DOWN.size() and classified.size() == keys.size(), "her anahtar tam bir kez sınıflandı (%d)" % classified.size())
	# NORMAL = etkisiz
	var normal := Difficulty.profile(Difficulty.Level.NORMAL)
	var neutral := true
	for k in keys:
		if k == "ai_half":
			continue
		var want := 0.0 if ADDITIVE_KEYS.has(k) else 1.0
		if not is_equal_approx(float(normal[k]), want):
			neutral = false
			print("    NORMAL '%s' = %s (beklenen %s)" % [k, str(normal[k]), str(want)])
	check(neutral, "NORMAL profil etkisiz (çarpanlar 1, zekâ ekleri 0)")
	# Sıralama
	var ordered := true
	for k in Difficulty.HARDER_UP:
		for lv in range(Difficulty.count() - 1):
			if float(Difficulty.profile(lv)[k]) > float(Difficulty.profile(lv + 1)[k]) + 0.000001:
				ordered = false
				print("    sıra bozuk (büyüdükçe zor): %s %d->%d" % [k, lv, lv + 1])
	for k in Difficulty.HARDER_DOWN:
		for lv in range(Difficulty.count() - 1):
			if float(Difficulty.profile(lv)[k]) < float(Difficulty.profile(lv + 1)[k]) - 0.000001:
				ordered = false
				print("    sıra bozuk (küçüldükçe zor): %s %d->%d" % [k, lv, lv + 1])
	check(ordered, "her ayar seviye arttıkça sertleşiyor ya da eşit kalıyor")
	var differs := true
	for k in keys:
		if is_equal_approx(float(Difficulty.profile(0)[k]), float(Difficulty.profile(3)[k])):
			differs = false
			print("    EASY ile IMMORTAL aynı: ", k)
	check(differs, "EASY ile IMMORTAL her ayarda farklı")
	# Adlar / kayıt anahtarları
	var roundtrip := true
	for lv in Difficulty.count():
		if Difficulty.from_key(Difficulty.key_of(lv)) != lv:
			roundtrip = false
	check(roundtrip, "kayıt anahtarı gidiş-dönüş: " + str(Difficulty.KEYS))
	check(Difficulty.from_key("bozuk") == Difficulty.DEFAULT and Difficulty.from_key("bozuk", 0) == 0, "tanınmayan anahtar varsayılana düşer")
	check(Difficulty.clamp_level(-5) == 0 and Difficulty.clamp_level(99) == 3, "geçersiz seviye en yakın geçerliye çekilir")
	check(Difficulty.name_of(99) == "IMMORTAL" and Difficulty.name_of(-1) == "EASY", "geçersiz seviyenin adı da çözülür")
	var blurbs_ok := Difficulty.BLURBS.size() == Difficulty.count()
	for b in Difficulty.BLURBS:
		if (b as String).strip_edges() == "":
			blurbs_ok = false
	check(blurbs_ok, "her seviyenin menü açıklaması var")


func _tuning_field(t: EnemyTuning, field: String) -> float:
	return float(t.get(field))


func _test_enemy_scaling() -> void:
	print("\nTur ölçeklemesi: 1. tur != 100000. tur; zekâ doyar, can/hasar sınırsız ama yavaş")
	var lv_normal := Difficulty.Level.NORMAL
	check(EnemyScaling.tuning(lv_normal, 0).is_identity(), "NORMAL, tur 0 = etkisiz (eski düşmanla aynı)")
	check(not EnemyScaling.tuning(lv_normal, 1).is_identity(), "NORMAL, tur 1 artık etkisiz değil")
	var all_fields := SCALE_UP_FIELDS + SCALE_DOWN_FIELDS
	# 1) Her seviyede ilk tur ile 100000. tur farklı (bütün sayısal ayarlarda)
	var varying := ["hp", "damage", "speed", "gold", "cooldown", "telegraph", "recover", "stun", "red", "reach", "kite"]
	for lv in Difficulty.count():
		var first := EnemyScaling.tuning(lv, 0)
		var last := EnemyScaling.tuning(lv, 100000)
		var diff := true
		for f in varying:
			if is_equal_approx(_tuning_field(first, f), _tuning_field(last, f)):
				diff = false
				print("    %s: tur 0 ile 100000 aynı (%s)" % [f, f])
		check(diff, "%s: tur 0 ile tur 100000 her ayarda farklı" % Difficulty.name_of(lv))
		check(last.scale_hp(4) > first.scale_hp(4) * 100 and last.scale_damage(2) > first.scale_damage(2), "%s: 100000. turda Taurus çok daha canlı (%d -> %d can) ve daha sert (%d -> %d)" % [
			Difficulty.name_of(lv), first.scale_hp(4), last.scale_hp(4), first.scale_damage(2), last.scale_damage(2)])
	# 2) Tur arttıkça tek yönde büyür/küçülür
	var steps := [0, 1, 2, 5, 10, 25, 50, 75, 100, 1000, 100000, 1000000000]
	var mono := true
	for lv in Difficulty.count():
		for i in range(steps.size() - 1):
			var a := EnemyScaling.tuning(lv, steps[i])
			var b := EnemyScaling.tuning(lv, steps[i + 1])
			for f in SCALE_UP_FIELDS:
				if _tuning_field(b, f) < _tuning_field(a, f) - 0.000001:
					mono = false
					print("    düştü: %s %s tur %d -> %d" % [Difficulty.name_of(lv), f, steps[i], steps[i + 1]])
			for f in SCALE_DOWN_FIELDS:
				if _tuning_field(b, f) > _tuning_field(a, f) + 0.000001:
					mono = false
					print("    çıktı: %s %s tur %d -> %d" % [Difficulty.name_of(lv), f, steps[i], steps[i + 1]])
	check(mono, "tur arttıkça düşman hiçbir ayarda geri gitmiyor (4 seviye x 12 tur)")
	# 3) Aynı turda seviye arttıkça sertleşir
	var ordered := true
	for n in [0, 25, 100, 100000]:
		for lv in range(Difficulty.count() - 1):
			var a := EnemyScaling.tuning(lv, n)
			var b := EnemyScaling.tuning(lv + 1, n)
			for f in SCALE_UP_FIELDS:
				if _tuning_field(b, f) < _tuning_field(a, f) - 0.000001:
					ordered = false
					print("    sıra bozuk: tur %d %s seviye %d->%d" % [n, f, lv, lv + 1])
			for f in SCALE_DOWN_FIELDS:
				if _tuning_field(b, f) > _tuning_field(a, f) + 0.000001:
					ordered = false
					print("    sıra bozuk: tur %d %s seviye %d->%d" % [n, f, lv, lv + 1])
	check(ordered, "aynı turda seviye arttıkça düşman sertleşiyor (tur 0/25/100/100000)")
	# 4) Sınırlar: sonsuz büyüyenler sonlu kalır, doyanlar doyar, alt sınırlar korunur
	var bounded := true
	var saturated := true
	for lv in Difficulty.count():
		for n in [100000, 1000000000, 1 << 62, -7]:
			var t := EnemyScaling.tuning(lv, n)
			for f in all_fields:
				if not is_finite(_tuning_field(t, f)):
					bounded = false
					print("    sonlu değil: %s %s tur %d" % [Difficulty.name_of(lv), f, n])
			if t.cooldown < EnemyScaling.MIN_COOLDOWN - 0.000001 or t.recover < EnemyScaling.MIN_RECOVER - 0.000001 or t.stun < EnemyScaling.MIN_STUN - 0.000001:
				bounded = false
			if t.red > EnemyScaling.MAX_RED_SHARE + 0.000001 or t.patience > 1.0 or t.punish > 1.0 or t.lead > 1.0 or t.patience < 0.0:
				bounded = false
			if t.telegraph <= 0.0 or t.speed <= 0.0 or t.hp <= 0.0:
				bounded = false
		var a := EnemyScaling.tuning(lv, 100000)
		var b := EnemyScaling.tuning(lv, 1000000000)
		for f in ["speed", "cooldown", "telegraph", "recover", "stun", "red", "reach", "kite", "patience", "punish", "lead", "feint"]:
			if absf(_tuning_field(a, f) - _tuning_field(b, f)) > 0.0001:
				saturated = false
				print("    doymadı: %s %s" % [Difficulty.name_of(lv), f])
		if not (b.hp > a.hp and b.damage > a.damage and b.gold > a.gold):
			saturated = false
	check(bounded, "çok büyük/negatif turlarda hiçbir değer taşmıyor, NaN olmuyor, alt sınırlar korunuyor")
	check(saturated, "zekâ ve süreler 100000. turda doymuş; can, hasar, altın hâlâ büyüyor")
	var neg := EnemyScaling.tuning(lv_normal, -7)
	check(neg.is_identity() and neg.progress == 0, "negatif tur 0'a çekilir")
	var huge := EnemyScaling.tuning(lv_normal, 1 << 62)
	check(huge.progress == EnemyScaling.MAX_PROGRESS, "devasa tur üst sınıra çekilir (%d)" % huge.progress)
	# 5) Tam sayıya çevirme: kalp ve can
	var e0 := EnemyScaling.tuning(Difficulty.Level.EASY, 0)
	var n0 := EnemyScaling.tuning(lv_normal, 0)
	var i0 := EnemyScaling.tuning(Difficulty.Level.IMMORTAL, 0)
	check(n0.scale_hp(4) == 4 and n0.scale_hp(3) == 3 and n0.scale_damage(1) == 1 and n0.scale_damage(2) == 2, "NORMAL tur 0: Taurus 4 can, hasar 1/2 (eskisi gibi)")
	check(e0.scale_hp(4) == 3 and e0.scale_hp(3) == 2, "EASY tur 0: Taurus 3 can, Sagitta 2 can")
	check(e0.scale_damage(1) == 1 and e0.scale_damage(2) == 1, "EASY: kırmızı atılma 1 kalp (hasar asla 0 olmaz)")
	check(i0.scale_hp(4) == 7 and i0.scale_damage(1) == 1 and i0.scale_damage(2) == 3, "IMMORTAL tur 0: 7 can; kırmızı atılma 3 kalp")
	var n100 := EnemyScaling.tuning(lv_normal, 100)
	check(n100.scale_hp(4) >= 20 and n100.scale_hp(4) <= 28, "NORMAL tur 100: Taurus ~24 can (%d)" % n100.scale_hp(4))
	check(n100.scale_damage(1) == 2 and n100.scale_damage(2) == 3, "NORMAL tur 100: hafif 2, kırmızı 3 kalp (%d/%d)" % [n100.scale_damage(1), n100.scale_damage(2)])
	check(n0.scale_gold(0) == 0 and i0.scale_gold(1) >= 1 and n100.scale_gold(3) > 3, "altın: 0 kalır, en az 1, tur ilerledikçe artar")
	check(n0.scale_hp(0) == 1 and n0.scale_damage(0) == 0, "can en az 1; hasarsız saldırı hasarsız kalır")
	# 6) Uyarı süresi insan tepkisinin altına inemez
	var worst := EnemyScaling.tuning(Difficulty.Level.IMMORTAL, 1000000000)
	check(worst.warn(0.55, 0.5) >= 0.5 and worst.warn(0.55, 0.3) >= 0.3, "uyarı süresi tabanın altına inmiyor (%.3f)" % worst.warn(0.55, 0.5))
	check(is_equal_approx(e0.warn(0.55, 0.3), 0.55 * 1.25), "EASY uyarıyı uzatır (%.3f)" % e0.warn(0.55, 0.3))
	check(not n0.summary().is_empty() and n0.summary().contains("NORMAL"), "özet satırı: " + n0.summary().substr(0, 40))


## `t` ayarıyla bir düşman sahnesini doğurur (tuning, ağaca girmeden önce verilir). Yapay zekâ kapalı: yalnız sayılara bakılır.
func _tuned(scene: PackedScene, t: EnemyTuning, at: Vector2) -> EnemyBase:
	var e := scene.instantiate() as EnemyBase
	if t != null:
		e.tuning = t
	_world.add_child(e)
	e.global_position = at
	e.set_physics_process(false)
	return e


func _test_enemy_tuning_hooks() -> void:
	await _new_world("Düşman ayarı: Taurus/Sagitta/Scorpius sayıları zorluk ve tura göre değişir, alt sınırlar korunur")
	var imm := EnemyScaling.tuning(Difficulty.Level.IMMORTAL, 0)
	var easy := EnemyScaling.tuning(Difficulty.Level.EASY, 0)
	var worst := EnemyScaling.tuning(Difficulty.Level.IMMORTAL, 1000000000)
	# --- ayarsız düşman = eski düşman
	var t0 := _tuned(TAURUS, null, Vector2(300, 612)) as Taurus
	check(t0.tuning != null and t0.tuning.is_identity(), "ayar verilmeyen düşman etkisiz ayar taşır")
	check(t0.max_hp == 4 and t0.gold_min == 2 and t0.gold_max == 4 and t0.health == 4, "Taurus: can 4, altın 2-4 (değişmedi)")
	check(is_equal_approx(t0.walk_speed, 115.0) and is_equal_approx(t0.lunge_range, 210.0) and is_equal_approx(t0.lunge_speed, 640.0), "Taurus: hız 115, menzil 210, atılma 640")
	check(is_equal_approx(t0.telegraph_time, 0.55) and is_equal_approx(t0.recover_time, 0.85) and is_equal_approx(t0.red_chance, 0.6), "Taurus: uyarı 0.55, açık kalma 0.85, kırmızı %60")
	var s0 := _tuned(SAGITTA, null, Vector2(500, 612)) as Sagitta
	check(s0.max_hp == 3 and is_equal_approx(s0.fire_interval, 1.9) and is_equal_approx(s0.telegraph_time, 0.45) and is_equal_approx(s0.projectile_speed, 360.0) and s0.gold_every == 3, "Sagitta: can 3, 1.9 sn, uyarı 0.45, mermi 360, 3'te 1 altın")
	var c0 := _tuned(SCORPIUS, null, Vector2(700, 612)) as Scorpius
	check(c0.max_hp == 3 and is_equal_approx(c0.tell_time, 0.34) and is_equal_approx(c0.stun_time, 1.5) and is_equal_approx(c0.feint_chance, 0.35) and is_equal_approx(c0.close_range, 85.0), "Scorpius: can 3, uyarı 0.34, sersem 1.5, sahte %35, yakın 85")
	# --- IMMORTAL, tur 0
	var t1 := _tuned(TAURUS, imm, Vector2(900, 612)) as Taurus
	check(t1.max_hp == 7 and t1.health == 7, "IMMORTAL Taurus: 7 can (%d)" % t1.health)
	check(t1.gold_min == 3 and t1.gold_max == 6, "IMMORTAL Taurus: altın 3-6 (%d-%d)" % [t1.gold_min, t1.gold_max])
	check(is_equal_approx(t1.walk_speed, 138.0) and is_equal_approx(t1.lunge_speed, 768.0) and is_equal_approx(t1.lunge_range, 252.0), "IMMORTAL Taurus: hızlı (%.0f), menzili uzun (%.0f)" % [t1.walk_speed, t1.lunge_range])
	check(is_equal_approx(t1.telegraph_time, 0.44) and is_equal_approx(t1.recover_time, 0.595) and is_equal_approx(t1.red_chance, 0.8), "IMMORTAL Taurus: uyarı 0.44, açık 0.595, kırmızı %80")
	var t_easy := _tuned(TAURUS, easy, Vector2(900, 612)) as Taurus
	check(t_easy.max_hp == 3 and is_equal_approx(t_easy.telegraph_time, 0.6875) and is_equal_approx(t_easy.red_chance, 0.35), "EASY Taurus: 3 can, uzun uyarı (%.2f), kırmızı %%35" % t_easy.telegraph_time)
	# hasar: gerçek atılmanın hasar alanı
	var p := _spawn_player(100.0)
	t1.target = p
	t1._red = true
	t1._begin_lunge()
	check(t1.attack_hitbox.damage == 3 and not t1.attack_hitbox.parryable, "IMMORTAL kırmızı atılma 3 kalp, parry'lenemez")
	t1._end_lunge()
	t1._red = false
	t1._begin_lunge()
	check(t1.attack_hitbox.damage == 1 and t1.attack_hitbox.parryable, "IMMORTAL altın atılma 1 kalp, parry'lenebilir")
	t_easy.target = p
	t_easy._red = true
	t_easy._begin_lunge()
	check(t_easy.attack_hitbox.damage == 1, "EASY kırmızı atılma 1 kalp")
	# parry sonrası sersemleme: seviyeyle kısalır, tabanın altına inmez
	t1._on_attack_parried(p)
	check(is_equal_approx(t1.stun_t, 0.9 * 0.7), "IMMORTAL Taurus parry'de %.2f sn sersemler (EASY: 1.17)" % t1.stun_t)
	t_easy._on_attack_parried(p)
	check(is_equal_approx(t_easy.stun_t, 0.9 * 1.3), "EASY Taurus parry'de %.2f sn sersemler" % t_easy.stun_t)
	# --- en kötü bileşim: alt sınırlar
	var tw := _tuned(TAURUS, worst, Vector2(1100, 612)) as Taurus
	check(tw.telegraph_time >= Taurus.TELEGRAPH_FLOOR - 0.0001, "en kötü bileşimde Taurus uyarısı %.3f sn (taban %.1f)" % [tw.telegraph_time, Taurus.TELEGRAPH_FLOOR])
	check(is_equal_approx(tw.recover_time, Taurus.RECOVER_FLOOR), "en kötü bileşimde açık kalma tabanda: %.3f" % tw.recover_time)
	check(tw.red_chance <= EnemyScaling.MAX_RED_SHARE + 0.0001 and tw.red_chance > 0.9, "kırmızı payı tavanda: %.2f" % tw.red_chance)
	tw.target = p
	tw._on_attack_parried(p)
	check(tw.stun_t >= Taurus.PARRY_STUN_FLOOR - 0.0001, "en kötü bileşimde parry sersemlemesi tabanın üstünde (%.2f)" % tw.stun_t)
	# --- Sagitta
	var s1 := _tuned(SAGITTA, imm, Vector2(1300, 612)) as Sagitta
	check(s1.max_hp == 5 and is_equal_approx(s1.fire_interval, 1.14) and is_equal_approx(s1.telegraph_time, 0.36) and is_equal_approx(s1.projectile_speed, 432.0), "IMMORTAL Sagitta: 5 can, 1.14 sn, uyarı 0.36, mermi 432")
	check(s1.gold_every >= 6 and s1.gold_every <= 10, "IMMORTAL Sagitta: altın mermi seyrek (her %d. mermi)" % s1.gold_every)
	var s_easy := _tuned(SAGITTA, easy, Vector2(1300, 612)) as Sagitta
	check(s_easy.gold_every == 2 and s_easy.max_hp == 2, "EASY Sagitta: her 2. mermi altın, 2 can")
	var sw := _tuned(SAGITTA, worst, Vector2(1300, 612)) as Sagitta
	check(is_equal_approx(sw.fire_interval, Sagitta.FIRE_INTERVAL_FLOOR) and sw.telegraph_time >= Sagitta.TELEGRAPH_FLOOR - 0.0001 and sw.gold_every == 10, "en kötü bileşim: ateş aralığı tabanda (%.2f), uyarı %.2f, her 10. mermi altın" % [sw.fire_interval, sw.telegraph_time])
	s1.target = p
	s1.global_position = Vector2(500, 612)
	var proj_before := get_tree().get_nodes_in_group("projectiles").size()
	s1._fire()
	var shots := get_tree().get_nodes_in_group("projectiles")
	check(shots.size() == proj_before + 1 and (shots[shots.size() - 1] as Projectile).damage == 1 and is_equal_approx((shots[shots.size() - 1] as Projectile).velocity.length(), 432.0), "IMMORTAL mermisi: hasar 1, hız 432")
	# --- Scorpius
	var c1 := _tuned(SCORPIUS, imm, Vector2(1500, 612)) as Scorpius
	check(c1.max_hp == 5 and is_equal_approx(c1.tell_time, 0.272) and is_equal_approx(c1.stun_time, 1.05) and is_equal_approx(c1.feint_chance, 0.55), "IMMORTAL Scorpius: 5 can, uyarı 0.272, sersem 1.05, sahte %55")
	check(is_equal_approx(c1.walk_speed, 156.0) and is_equal_approx(c1.lunge_speed, 672.0) and is_equal_approx(c1.close_range, 106.25), "IMMORTAL Scorpius: hızlı, erken geri takla (yakın %.1f)" % c1.close_range)
	var cw := _tuned(SCORPIUS, worst, Vector2(1500, 612)) as Scorpius
	check(cw.tell_time >= Scorpius.TELL_FLOOR - 0.0001 and cw.stun_time >= Scorpius.STUN_FLOOR - 0.0001 and cw.feint_chance <= 0.7001, "en kötü bileşim: uyarı %.3f, sersem %.2f, sahte %.2f (tabanlar korunur)" % [cw.tell_time, cw.stun_time, cw.feint_chance])
	check(cw.close_range <= cw.ideal_distance - 25.0 + 0.0001, "geri takla eşiği ideal mesafedeki geri adım bölgesine taşmıyor (%.1f)" % cw.close_range)
	c1.target = p
	c1._begin_lunge()
	check(c1.attack_hitbox.damage == 1 and c1.attack_hitbox.parryable, "IMMORTAL Scorpius dürtüşü: tur 0'da 1 kalp")
	var c100 := _tuned(SCORPIUS, EnemyScaling.tuning(Difficulty.Level.NORMAL, 100), Vector2(1500, 612)) as Scorpius
	c100.target = p
	c100._begin_lunge()
	check(c100.attack_hitbox.damage == 2 and c100.max_hp == 18, "NORMAL tur 100 Scorpius: dürtüş 2 kalp, 18 can (%d/%d)" % [c100.attack_hitbox.damage, c100.max_hp])
	# --- ölünce altın: ölçeklenmiş
	var coins_before := get_tree().get_nodes_in_group("coins").size()
	t1.take_damage(99, p)
	await _frames(2)
	check(t1.dead, "ölçeklenmiş Taurus öldü (99 hasar)")
	check(get_tree().get_nodes_in_group("coins").size() >= coins_before, "altın düştü")
	GameState.difficulty = Difficulty.DEFAULT


func _test_enemy_brain() -> void:
	await _new_world("Düşman zekâsı: sabır (parry'yi bekletir), ceza (ıskalanan parry), önden hedefleme, kaçış")
	var p := _spawn_player(700.0)
	var smart := EnemyTuning.new()
	smart.patience = 1.0
	smart.punish = 1.0
	smart.lead = 1.0
	smart.kite = 1.25
	var dumb := EnemyTuning.new()
	# --- Taurus: SABIR
	var t := _tuned(TAURUS, smart, Vector2(900, 612)) as Taurus
	t.target = p
	t._phase = Taurus.Phase.TELEGRAPH
	t._timer = 0.05
	t._on_player_parry_started(p)
	var dist := absf(p.global_position.x - t.global_position.x)
	var want := maxf(p.parry_window_time() + 0.75 * p.parry_recovery_time() - maxf(dist - Taurus.LUNGE_LEAD_IN, 0.0) / t.lunge_speed, 0.05)
	check(is_equal_approx(t._timer, want) and t._delayed, "sabırlı Taurus parry'ye basılınca atılmayı geciktirdi (0.05 -> %.3f sn)" % t._timer)
	t._timer = 0.01
	t._on_player_parry_started(p)
	check(is_equal_approx(t._timer, 0.01), "bir uyarıda en çok bir kez geciktirir")
	t._delayed = false
	t._timer = 0.9
	t._on_player_parry_started(p)
	check(is_equal_approx(t._timer, 0.9) and not t._delayed, "zaten geç gelecek atılmayı hızlandırmaz, bekletme saymaz")
	t._timer = 0.05
	t._phase = Taurus.Phase.CHASE
	t._on_player_parry_started(p)
	check(is_equal_approx(t._timer, 0.05), "uyarı yokken (kovalarken) parry'ye tepki vermez")
	t._phase = Taurus.Phase.TELEGRAPH
	t._on_player_parry_started(t)
	check(is_equal_approx(t._timer, 0.05), "başkasının parry'si umurunda değil")
	var td := _tuned(TAURUS, dumb, Vector2(1100, 612)) as Taurus
	td.target = p
	td._phase = Taurus.Phase.TELEGRAPH
	td._timer = 0.05
	td._on_player_parry_started(p)
	check(is_equal_approx(td._timer, 0.05) and not td._delayed, "NORMAL Taurus bekletmez (sabır 0)")
	# --- Taurus: CEZA
	t._phase = Taurus.Phase.CHASE
	t._cooldown = 1.0
	t._on_player_parry_failed(p)
	check(is_equal_approx(t._cooldown, 0.0) and t._quick, "parry'yi ıskalayana menzildeki Taurus hemen saldırıya geçer")
	t._begin_telegraph()
	check(is_equal_approx(t._timer, t.telegraph_time * Taurus.PUNISH_QUICK) and not t._quick, "uyarı kısalmış (%.3f sn) ve bir kerelik" % t._timer)
	t._phase = Taurus.Phase.CHASE
	t._cooldown = 1.0
	t.global_position.x = 1700.0
	t._on_player_parry_failed(p)
	check(is_equal_approx(t._cooldown, 1.0) and not t._quick, "menzil dışındaki Taurus ceza vermez")
	td._phase = Taurus.Phase.CHASE
	td._cooldown = 1.0
	td.global_position.x = 900.0
	td._on_player_parry_failed(p)
	check(is_equal_approx(td._cooldown, 1.0), "NORMAL Taurus cezalandırmaz (ceza 0)")
	# --- Sagitta: ÖNDEN HEDEFLEME ve CEZA ve KAÇIŞ
	var s := _tuned(SAGITTA, smart, Vector2(1000, 612)) as Sagitta
	s.target = p
	p.velocity = Vector2(300.0, 0.0)
	var origin := s.global_position + Vector2(-24.0, -6.0)
	var aim := s._aim_point(origin)
	var flight := origin.distance_to(p.global_position) / s.projectile_speed
	var shift := minf(300.0 * flight, Sagitta.LEAD_MAX)
	check(is_equal_approx(aim.x, p.global_position.x + shift) and is_equal_approx(aim.y, p.global_position.y), "önden hedefleme: koşan oyuncunun %.0f px önüne nişan (yalnız yatay)" % shift)
	check(is_equal_approx(shift, Sagitta.LEAD_MAX), "uzak hedefte öne tahmin tavanı (%.0f px) geçilmiyor" % Sagitta.LEAD_MAX)
	s.global_position.x = 900.0
	origin = s.global_position + Vector2(-24.0, -6.0)
	aim = s._aim_point(origin)
	flight = origin.distance_to(p.global_position) / s.projectile_speed
	check(is_equal_approx(aim.x, p.global_position.x + 300.0 * flight) and 300.0 * flight < Sagitta.LEAD_MAX, "yakın hedefte tahmin sınırın altında (%.0f px)" % (300.0 * flight))
	p.velocity = Vector2.ZERO
	check(s._aim_point(origin).is_equal_approx(p.global_position), "duran oyuncuya doğrudan nişan")
	var sd := _tuned(SAGITTA, dumb, Vector2(900, 612)) as Sagitta
	sd.target = p
	p.velocity = Vector2(300.0, 0.0)
	check(sd._aim_point(origin).is_equal_approx(p.global_position), "NORMAL Sagitta hareketi önceden kestirmez (önden hedefleme 0)")
	p.velocity = Vector2.ZERO
	s._phase = Sagitta.Phase.IDLE
	s._timer = 2.0
	s._on_player_parry_failed(p)
	check(s._timer <= 0.05, "parry'yi ıskalayana Sagitta hemen nişan alır (%.2f)" % s._timer)
	sd._phase = Sagitta.Phase.IDLE
	sd._timer = 2.0
	sd._on_player_parry_failed(p)
	check(is_equal_approx(sd._timer, 2.0), "NORMAL Sagitta cezalandırmaz")
	# Kaçış: oyuncu 300 px uzakta (260 ile 260x1.25=325 arası): NORMAL durur, akıllı olan geri çekilir
	var near_p := _spawn_player(600.0)
	var sk := _tuned(SAGITTA, smart, Vector2(900, 612)) as Sagitta
	var sn := _tuned(SAGITTA, dumb, Vector2(900, 612)) as Sagitta
	for e in [sk, sn]:
		e.target = near_p
		(e as Sagitta)._phase = Sagitta.Phase.IDLE
		(e as Sagitta)._timer = 10.0
		e.velocity = Vector2.ZERO
		e._ai(0.016)
	check(sk.velocity.x > 50.0, "akıllı Sagitta 300 px'te geri çekilir (hız %.0f, sağa = uzağa)" % sk.velocity.x)
	check(absf(sn.velocity.x) < 1.0, "NORMAL Sagitta 300 px'te durur (260 px'in altına girmeden kaçmaz)")
	sk.global_position.x = 600.0 + 400.0
	sk.velocity = Vector2.ZERO
	sk._ai(0.016)
	check(absf(sk.velocity.x) < 1.0, "400 px'te (kaçış bölgesinin dışında) durur")
	# --- Scorpius: CEZA
	var c := _tuned(SCORPIUS, smart, Vector2(900, 612)) as Scorpius
	c.target = p
	c._phase = Scorpius.Phase.SPACING
	c._decide_t = 1.0
	c._on_player_parry_failed(p)
	check(c._decide_t <= 0.05, "parry'yi ıskalayana Scorpius hemen saldırıya geçer (%.2f)" % c._decide_t)
	c._decide_t = 1.0
	c._phase = Scorpius.Phase.TELL
	c._on_player_parry_failed(p)
	check(is_equal_approx(c._decide_t, 1.0), "saldırı sürerken karar süresine dokunmaz")
	var cd := _tuned(SCORPIUS, dumb, Vector2(900, 612)) as Scorpius
	cd.target = p
	cd._decide_t = 1.0
	cd._on_player_parry_failed(p)
	check(is_equal_approx(cd._decide_t, 1.0), "NORMAL Scorpius cezalandırmaz")
	# Karar süreleri zorlukla kısalır
	var fast := EnemyTuning.new()
	fast.cooldown = 0.5
	var cf := _tuned(SCORPIUS, fast, Vector2(900, 612)) as Scorpius
	var sum_fast := 0.0
	var sum_slow := 0.0
	for i in 40:
		sum_fast += cf._decide_in(1.0, 2.0)
		sum_slow += cd._decide_in(1.0, 2.0)
	check(sum_fast < sum_slow * 0.7, "bekleme çarpanı 0.5: karar süreleri belirgin kısa (%.1f / %.1f)" % [sum_fast, sum_slow])


func _test_difficulty_run() -> void:
	await _new_world("Zorluk koşuda: odanın ayarı seviye + oda numarasından, doğan düşman ölçekli")
	GameState.difficulty = Difficulty.Level.IMMORTAL
	var run := _start_run(777)
	var p := run.player
	await _frames(5)
	var r0 := run.rooms[0] as Room
	var r1 := run.rooms[1] as Room
	check(r0.tuning != null and r0.tuning.level == Difficulty.Level.IMMORTAL and r0.tuning.progress == 0, "oda 0: IMMORTAL, tur 0")
	check(r1.tuning != null and r1.tuning.level == Difficulty.Level.IMMORTAL and r1.tuning.progress == 1, "oda 1: IMMORTAL, tur 1")
	check(RunController.progress_of(7) == 7 and RunController.progress_of(-3) == 0, "tur ilerlemesi şimdilik oda numarası")
	check(run.tuning_for(9).progress == 9 and run.tuning_for(9).hp > run.tuning_for(1).hp, "uzak odanın düşmanı daha canlı")
	var spawned := await _wait_until(func() -> bool: return r0.alive_count() >= 2, 240)
	check(spawned, "ilk dalga doğdu (%d düşman)" % r0.alive_count())
	var all_scaled := true
	var seen := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as EnemyBase
		if en == null:
			continue
		seen += 1
		var base := 4 if en is Taurus else 3
		if en.tuning == null or en.tuning.level != Difficulty.Level.IMMORTAL or en.max_hp != en.tuning.scale_hp(base) or en.health != en.max_hp:
			all_scaled = false
	check(seen >= 2 and all_scaled, "doğan %d düşmanın hepsi IMMORTAL ayarıyla ölçeklendi (Taurus 7, Sagitta 5 can)" % seen)
	_kill_all_enemies(p)
	await _wait_until(func() -> bool: return r0.is_cleared(), 120)
	run.queue_free()
	await _frames(3)
	# Aynı koşu NORMAL'de: ilk odanın düşmanı eskisi gibi
	GameState.difficulty = Difficulty.Level.NORMAL
	await _new_world("Zorluk koşuda: NORMAL, 0. oda = eski düşman")
	run = _start_run(777)
	await _frames(5)
	r0 = run.rooms[0] as Room
	check(r0.tuning.is_identity(), "NORMAL oda 0 ayarı etkisiz")
	spawned = await _wait_until(func() -> bool: return r0.alive_count() >= 2, 240)
	var old_stats := true
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as EnemyBase
		if en != null and en.max_hp != (4 if en is Taurus else 3):
			old_stats = false
	check(spawned and old_stats, "NORMAL ilk oda: Taurus 4 can, Sagitta 3 can (eskisi gibi)")
	check(GameState.difficulty == Difficulty.Level.NORMAL, "zorluk koşu boyunca değişmedi")
	run.queue_free()
	await _frames(3)


# ------------------------------------------------------------------ kayıt sistemi

const TEST_SAVE_DIR := "user://test_saves"


func _clean_saves() -> void:
	SaveStore.dir = TEST_SAVE_DIR
	for i in SaveStore.COUNT:
		SaveStore.delete_slot(i)


func _end_saves() -> void:
	_clean_saves()
	DirAccess.remove_absolute(TEST_SAVE_DIR)
	SaveStore.dir = "user://saves"
	GameState.end_session()
	GameState.difficulty = Difficulty.DEFAULT
	GameState.mode = GameMode.DEFAULT


func _write_raw(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _read_raw(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var t := f.get_as_text()
	f.close()
	return t


func _json_roundtrip(v: Variant) -> Variant:
	var j := JSON.new()
	j.parse(JSON.stringify(v))
	return j.data


func _test_save_slot_data() -> void:
	print("\nKayıt slotu: isim temizleme, rekorlar, kaldığımız yer, doğrulama")
	check(SaveSlot.clean_name("  Sidera  ") == "Sidera", "baştaki/sondaki boşluk atılır")
	check(SaveSlot.clean_name("ÇAĞRI Şen") == "ÇAĞRI Şen", "Türkçe harfler korunur")
	check(SaveSlot.clean_name("a<b>c\n") == "abc", "geçersiz karakterler atılır (<>, satır sonu)")
	check(SaveSlot.clean_name("A      B") == "A B", "ardışık boşluklar tek olur")
	check(SaveSlot.clean_name("Umut-2.0-x'") == "Umut-2.0-x'", "rakam ve - . ' kalır")
	check(SaveSlot.clean_name("a_b") == "ab", "alt çizgi atılır (yazı tipinde yok)")
	check(SaveSlot.clean_name("") == SaveSlot.DEFAULT_NAME and SaveSlot.clean_name("   ") == SaveSlot.DEFAULT_NAME and SaveSlot.clean_name("<<>>") == SaveSlot.DEFAULT_NAME, "boş kalan isim varsayılana döner")
	check(SaveSlot.clean_name("0123456789ABCDEFGHIJ").length() == SaveSlot.NAME_MAX, "isim en çok %d karakter" % SaveSlot.NAME_MAX)
	check(SaveSlot.clean_name("😀Ali😀") == "Ali", "emoji atılır")
	var s := SaveSlot.create(1, "  Test  ", 99)
	check(s.index == 1 and s.name == "Test" and s.difficulty == Difficulty.Level.IMMORTAL, "create: isim temiz, zorluk geçerliye çekildi")
	check(s.created > 0 and s.last_played == s.created and s.playtime == 0.0, "create: tarih atandı, süre 0")
	check(int(s.records["runs"]) == 0 and int(s.records["best_wave"]) == 0, "create: rekorlar sıfır")
	check(not s.has_run(GameMode.Kind.NORMAL) and s.run_of(GameMode.Kind.NORMAL).is_empty(), "başta yarım koşu yok")
	check(s.progress_text(GameMode.Kind.NORMAL) == "" and s.best_text(GameMode.Kind.NORMAL) == "" and s.best_text(GameMode.Kind.ENDLESS) == "", "başta 'kaldığımız yer' ve rekor satırı boş")
	# Yarım koşu ve kaldığımız yer
	var snap := {"seed": 42, "floor": 2, "room": 3, "wave": 0, "player": {"health": 3}}
	s.set_run(GameMode.Kind.NORMAL, snap)
	snap["seed"] = 7  # kopyalandı: dışarıdaki değişiklik kaydı etkilemez
	check(s.has_run(GameMode.Kind.NORMAL) and int(s.run_of(GameMode.Kind.NORMAL)["seed"]) == 42, "koşu kopyalanarak saklanır")
	check(s.progress_text(GameMode.Kind.NORMAL) == "KAT 2  ODA 4", "kaldığımız yer: " + s.progress_text(GameMode.Kind.NORMAL))
	s.set_run(GameMode.Kind.ENDLESS, {"seed": 1, "wave": 37, "player": {}})
	check(s.progress_text(GameMode.Kind.ENDLESS) == "DALGA 37", "sınırsız: " + s.progress_text(GameMode.Kind.ENDLESS))
	var copy := s.run_of(GameMode.Kind.NORMAL)
	copy["seed"] = 99
	check(int(s.run_of(GameMode.Kind.NORMAL)["seed"]) == 42, "run_of kopya döndürür")
	# Rekorlar
	s.record_run(GameMode.Kind.NORMAL, {"kills": 12, "best_combo": 9, "floor": 2, "room": 3}, true)
	check(not s.has_run(GameMode.Kind.NORMAL) and s.has_run(GameMode.Kind.ENDLESS), "biten koşu silindi, diğer kipin koşusu durdu")
	check(int(s.records["runs"]) == 1 and int(s.records["deaths"]) == 1 and int(s.records["kills"]) == 12 and int(s.records["best_combo"]) == 9, "rekorlar işlendi %s" % str(s.records))
	check(int(s.records["best_floor"]) == 2 and int(s.records["best_room"]) == 4 and s.best_text(GameMode.Kind.NORMAL) == "EN İYİ KAT 2  ODA 4", "en iyi konum: " + s.best_text(GameMode.Kind.NORMAL))
	s.record_run(GameMode.Kind.NORMAL, {"kills": 3, "best_combo": 20, "floor": 1, "room": 6}, false)
	check(int(s.records["best_floor"]) == 2 and int(s.records["best_room"]) == 4, "daha kötü koşu rekoru düşürmez")
	check(int(s.records["runs"]) == 2 and int(s.records["deaths"]) == 1 and int(s.records["kills"]) == 15 and int(s.records["best_combo"]) == 20, "terk edilen koşu ölüm sayılmaz, toplamlar birikir")
	s.record_run(GameMode.Kind.NORMAL, {"kills": 0, "best_combo": 0, "floor": 2, "room": 7}, true)
	check(int(s.records["best_room"]) == 8, "aynı katta daha ileri oda rekoru artırır")
	s.record_run(GameMode.Kind.ENDLESS, {"kills": 40, "best_combo": 5, "wave": 37}, true)
	check(int(s.records["best_wave"]) == 37 and s.best_text(GameMode.Kind.ENDLESS) == "EN İYİ DALGA 37" and not s.has_run(GameMode.Kind.ENDLESS), "sınırsız rekor: dalga 37, koşu silindi")
	s.record_run(GameMode.Kind.ENDLESS, {"kills": 1, "wave": 12}, true)
	check(int(s.records["best_wave"]) == 37, "daha düşük dalga rekoru düşürmez")
	# Biçimlendirme
	check(SaveSlot.format_playtime(0.0) == "0:00" and SaveSlot.format_playtime(65.9) == "1:05" and SaveSlot.format_playtime(3725.0) == "1:02:05" and SaveSlot.format_playtime(-30.0) == "0:00", "süre biçimi")
	check(SaveSlot.format_date(0) == "-", "tarih yoksa '-'")
	var d := SaveSlot.format_date(1790000000)
	check(d.length() == 10 and d[2] == "." and d[5] == "." and d.ends_with("2026"), "tarih gg.aa.yyyy: " + d)
	# Dosya biçimi gidiş-dönüş (JSON'dan sayılar float döner)
	var full := SaveSlot.create(2, "Gidiş", Difficulty.Level.HARD)
	full.playtime = 1234.56
	full.records["kills"] = 77
	full.set_run(GameMode.Kind.NORMAL, snap)
	var back := SaveSlot.from_dict(_json_roundtrip(full.to_dict()), 2)
	check(back != null and back.name == "Gidiş" and back.difficulty == Difficulty.Level.HARD and back.index == 2, "gidiş-dönüş: isim, zorluk, indeks")
	check(back != null and back.created == full.created and is_equal_approx(back.playtime, 1234.6) and int(back.records["kills"]) == 77, "gidiş-dönüş: tarih, süre, rekor")
	check(back != null and back.has_run(GameMode.Kind.NORMAL) and back.progress_text(GameMode.Kind.NORMAL) == "KAT 2  ODA 4", "gidiş-dönüş: yarım koşu (JSON float'ları int'e çevrildi)")
	check(full.to_dict()["difficulty"] == "difficult" and full.to_dict()["version"] == SaveSlot.VERSION, "dosyada zorluk anahtarı 'difficult', sürüm var")
	# Doğrulama: bozuk veri güvenli değerlere çekilir
	check(SaveSlot.from_dict("x", 0) == null and SaveSlot.from_dict(null, 0) == null and SaveSlot.from_dict([1, 2], 0) == null, "sözlük olmayan veri reddedilir")
	check(SaveSlot.from_dict({"version": 999}, 0) == null, "gelecek sürümün dosyası reddedilir")
	var junk := SaveSlot.from_dict({
		"name": 12345, "difficulty": "çılgın", "created": -5, "last_played": "abc", "playtime": "bozuk",
		"records": {"kills": -9, "runs": "7", "deaths": [1], "best_wave": 2.9},
		"runs": {"normal": "yok", "endless": {"wave": 5}},
	}, 1)
	check(junk != null and junk.name == "12345" and junk.difficulty == Difficulty.DEFAULT, "bozuk isim/zorluk: metne çevrildi, varsayılana düştü")
	check(junk.created == 0 and junk.last_played == 0 and junk.playtime == 0.0, "negatif/bozuk tarih ve süre 0 oldu")
	check(int(junk.records["kills"]) == 0 and int(junk.records["runs"]) == 7 and int(junk.records["deaths"]) == 0 and int(junk.records["best_wave"]) == 2, "bozuk rekorlar: negatif 0, '7' sayıya, liste 0, 2.9 -> 2")
	check(not junk.has_run(GameMode.Kind.NORMAL) and not junk.has_run(GameMode.Kind.ENDLESS), "tohumsuz/sözlük olmayan yarım koşu atıldı")
	var minimal := SaveSlot.from_dict({}, 0)
	check(minimal != null and minimal.name == SaveSlot.DEFAULT_NAME and minimal.difficulty == Difficulty.DEFAULT, "boş sözlük bile geçerli (varsayılanlar)")
	var nan_slot := SaveSlot.from_dict({"playtime": NAN, "created": INF}, 0)
	check(nan_slot != null and nan_slot.playtime == 0.0 and nan_slot.created == 0, "NaN/sonsuz değerler 0 olur")
	check(GameMode.count() == 2 and GameMode.name_of(0) == "NORMAL" and GameMode.name_of(1) == "SINIRSIZ" and GameMode.from_key("endless") == GameMode.Kind.ENDLESS and GameMode.from_key("x") == GameMode.DEFAULT, "oyun kipleri: adlar ve anahtarlar")
	check(GameMode.clamp_kind(-3) == 0 and GameMode.clamp_kind(9) == 1 and GameMode.blurb_of(0) != "" and GameMode.blurb_of(1) != "", "kip sınırlandırma ve açıklamalar")


func _test_save_store() -> void:
	print("\nKayıt dosyası: yazma, okuma, yedek, bozuk dosya, silme")
	_clean_saves()
	check(SaveStore.list_slots() == [null, null, null], "boş klasör: 3 slot da boş")
	check(SaveStore.first_free() == 0, "ilk boş slot 0")
	check(SaveStore.load_slot(-1) == null and SaveStore.load_slot(3) == null, "geçersiz indeks null")
	check(not SaveStore.save_slot(null) and not SaveStore.save_slot(SaveSlot.create(7, "X", 1)) and not SaveStore.delete_slot(5), "geçersiz kayıt/silme reddedilir")
	var a := SaveSlot.create(0, "Birinci", Difficulty.Level.EASY)
	a.records["kills"] = 5
	check(SaveStore.save_slot(a), "slot 0 yazıldı")
	check(FileAccess.file_exists(SaveStore.path_of(0)) and not FileAccess.file_exists(SaveStore.path_of(0) + ".tmp") and not FileAccess.file_exists(SaveStore.path_of(0) + ".bak"), "ana dosya var, geçici dosya kalmadı, yedek henüz yok")
	check(SaveStore.path_of(0).ends_with("slot_1.json") and SaveStore.path_of(2).ends_with("slot_3.json"), "dosya adları slot_1..3.json")
	var back := SaveStore.load_slot(0)
	check(back != null and back.name == "Birinci" and back.difficulty == Difficulty.Level.EASY and int(back.records["kills"]) == 5 and not back.recovered, "slot 0 aynen okundu")
	check(SaveStore.first_free() == 1, "ilk boş slot 1'e kaydı")
	var b := SaveSlot.create(1, "ÇAĞRI", Difficulty.Level.IMMORTAL)
	b.set_run(GameMode.Kind.NORMAL, {"seed": 5, "floor": 1, "room": 0, "player": {}})
	check(SaveStore.save_slot(b), "slot 1 yazıldı")
	var listed := SaveStore.list_slots()
	check(listed[0] != null and listed[1] != null and listed[2] == null and (listed[1] as SaveSlot).name == "ÇAĞRI" and (listed[1] as SaveSlot).has_run(GameMode.Kind.NORMAL), "liste: dolu, dolu, boş; Türkçe isim ve koşu korundu")
	check(SaveStore.first_free() == 2, "ilk boş slot 2")
	var c := SaveSlot.create(2, "Üçüncü", Difficulty.Level.HARD)
	SaveStore.save_slot(c)
	check(SaveStore.first_free() == -1, "hepsi doluyken ilk boş yok (-1)")
	# Üzerine yazma: eski sürüm .bak olur
	a.records["kills"] = 9
	check(SaveStore.save_slot(a), "slot 0 yeniden yazıldı")
	check(FileAccess.file_exists(SaveStore.path_of(0) + ".bak"), "eski dosya .bak olarak saklandı")
	check(int(SaveStore.load_slot(0).records["kills"]) == 9, "ana dosya yeni sürüm (9)")
	var bak_text := _read_raw(SaveStore.path_of(0) + ".bak")
	check(bak_text.contains("\"kills\": 5"), "yedek eski sürüm (5)")
	check(_read_raw(SaveStore.path_of(0)).contains("\"version\": 1"), "dosyada sürüm numarası var")
	# Ana dosya bozuldu: yedekten
	_write_raw(SaveStore.path_of(0), "{ bu json degil")
	var rec := SaveStore.load_slot(0)
	check(rec != null and rec.recovered and int(rec.records["kills"]) == 5 and rec.name == "Birinci", "ana dosya bozukken yedekten okundu (recovered)")
	check(SaveStore.save_slot(rec), "yedekten kurtarılan slot yeniden yazılabilir")
	var again := SaveStore.load_slot(0)
	check(again != null and not again.recovered and int(again.records["kills"]) == 5, "yeniden yazınca ana dosya sağlam")
	# Boş dosya ve sözlük olmayan JSON da bozuk sayılır
	_write_raw(SaveStore.path_of(1), "")
	_write_raw(SaveStore.path_of(1) + ".bak", "[1,2,3]")
	check(SaveStore.load_slot(1) == null, "boş ana dosya + liste yedek = okunamaz, slot boş görünür")
	check(FileAccess.file_exists(SaveStore.path_of(1) + ".corrupt") and FileAccess.file_exists(SaveStore.path_of(1) + ".bak.corrupt"), "bozuk dosyalar silinmedi, .corrupt olarak kenara alındı")
	check(not FileAccess.file_exists(SaveStore.path_of(1)) and not FileAccess.file_exists(SaveStore.path_of(1) + ".bak"), "ana ve yedek adı boşaldı (yeni oyun açılabilir)")
	check(SaveStore.first_free() == 1, "bozuk slot yeni oyun için boş sayıldı")
	var fresh := SaveSlot.create(1, "Yeni", Difficulty.Level.NORMAL)
	check(SaveStore.save_slot(fresh) and SaveStore.load_slot(1).name == "Yeni", "bozuk slotun yerine yeni oyun yazıldı")
	# Sürüm: gelecekteki dosya okunamaz sayılır ama silinmez
	_write_raw(SaveStore.path_of(2), "{\"version\": 99, \"name\": \"Gelecek\"}")
	SaveStore.delete_slot(2)
	check(not FileAccess.file_exists(SaveStore.path_of(2)), "delete: ana dosya silindi")
	_write_raw(SaveStore.path_of(2) + ".bak", "{\"name\": \"Yedek\"}")
	_write_raw(SaveStore.path_of(2) + ".corrupt", "x")
	check(SaveStore.delete_slot(2), "delete true döndü")
	check(not FileAccess.file_exists(SaveStore.path_of(2) + ".bak") and not FileAccess.file_exists(SaveStore.path_of(2) + ".corrupt"), "delete: yedek ve bozuk kopyalar da silindi")
	check(SaveStore.load_slot(2) == null, "silinen slot boş")
	_end_saves()


func _test_save_player_snapshot() -> void:
	await _new_world("Kayıt: oyuncunun durumu (eşyalar, çanta, can, bağışıklık, altın) ve Umbra'nın eşyaları")
	var p := _spawn_player(300.0)
	await _frames(2)
	var inv := p.inventory
	inv.add(_item("feather_boots"))
	inv.add(_item("viper_fang"))
	inv.give(_item("tower_bread"))
	inv.give(_item("tower_bread"))
	inv.give(_item("mirror_boots"))  # ayak slotu dolu: çantada kalır
	p.gold = 77
	p.set_immunity(2)
	p.health = 2
	var speed_with := p.stats.value("move_speed")
	var snap := RunSnapshot.capture_player(p)
	check(snap["equipped"] == ["feather_boots", "viper_fang"] and int(snap["gold"]) == 77 and int(snap["immunity"]) == 2 and int(snap["health"]) == 2, "capture: takılı eşyalar sırayla, altın, bağışıklık, can")
	var bag_ids: Array = []
	for e in snap["bag"]:
		bag_ids.append("%s x%d" % [e["id"], int(e["count"])])
	check(bag_ids.has("tower_bread x2") and bag_ids.has("mirror_boots x1") and bag_ids.size() == 2, "capture: çanta yığınları " + str(bag_ids))
	var disk := _json_roundtrip(snap) as Dictionary
	# Başka bir oyuncuya yükle
	var q := _spawn_player(500.0)
	await _frames(2)
	q.inventory.add(_item("hourglass_of_saturn")) if _item("hourglass_of_saturn") != null else null
	q.gold = 1
	RunSnapshot.apply_player(q, disk)
	check(q.inventory.items.size() == 2 and q.inventory.has("feather_boots") and q.inventory.has("viper_fang") and not q.inventory.has("hourglass_of_saturn"), "apply: eski eşyalar silindi, kayıttakiler takıldı")
	check(q.inventory.bag_count("tower_bread") == 2 and q.inventory.bag_count("mirror_boots") == 1, "apply: çanta yığınları geri geldi")
	check(q.gold == 77 and q.immunity == 2 and q.health == 2, "apply: altın 77, bağışıklık 2, can 2")
	check(is_equal_approx(q.stats.value("move_speed"), speed_with), "apply: takılan eşyaların etkileri çalışıyor (hız %.0f)" % q.stats.value("move_speed"))
	# Bozuk/eski veri
	var weird := {"health": 999, "immunity": -4, "gold": -50, "equipped": ["yok_boyle_esya", "feather_boots", 5], "bag": [{"id": "tower_bread", "count": 1000}, {"id": "silinmis"}, "x", {"id": "viper_fang", "count": "3"}]}
	RunSnapshot.apply_player(q, weird)
	check(q.health == q.stats.int_value("max_health"), "can en çok max_health (%d)" % q.health)
	check(q.immunity == 0 and q.gold == 0, "negatif bağışıklık/altın 0")
	check(q.inventory.items.size() == 1 and q.inventory.has("feather_boots"), "tanınmayan eşya kimlikleri atlandı")
	check(q.inventory.bag_count("tower_bread") == 99 and q.inventory.bag_count("viper_fang") == 3, "yığın en çok 99; metin sayı '3' çözüldü")
	RunSnapshot.apply_player(q, {"health": -3})
	check(q.health == 1 and q.inventory.items.is_empty() and q.inventory.bag.is_empty(), "can en az 1; eksik alanlar boş envanter")
	RunSnapshot.apply_player(q, {})
	check(q.health >= 1 and q.gold == 0, "boş sözlük çökmeden uygulanır")
	# Umbra
	GameState.reset()
	GameState.leave_behind(_item("mirror_boots"))
	GameState.leave_behind(_item("viper_fang"))
	GameState.umbra_extra_carry = 1
	var um := _json_roundtrip(RunSnapshot.capture_umbra()) as Dictionary
	GameState.reset()
	check(GameState.umbra_items.is_empty(), "sıfırlandı")
	RunSnapshot.apply_umbra(um)
	check(GameState.umbra_has("mirror_boots") and GameState.umbra_has("viper_fang") and GameState.umbra_items.size() == 2 and GameState.umbra_extra_carry == 1, "Umbra'nın eşyaları ve taşıma artışı geri geldi")
	RunSnapshot.apply_umbra({"umbra": ["yok", "viper_fang", 3], "umbra_carry": -2})
	check(GameState.umbra_items.size() == 1 and GameState.umbra_extra_carry == 0, "Umbra: tanınmayan kimlik atlandı, negatif taşıma 0")
	# İstatistikler
	var st := {"kills": 5, "rooms_cleared": 2, "best_combo": 7, "time": 123.456, "room": 3}
	var cs := _json_roundtrip(RunSnapshot.capture_stats(st)) as Dictionary
	var st2 := {"kills": 0, "rooms_cleared": 0, "best_combo": 0, "time": 0.0, "room": 1}
	RunSnapshot.apply_stats(st2, cs)
	check(st2["kills"] == 5 and st2["rooms_cleared"] == 2 and st2["best_combo"] == 7 and is_equal_approx(st2["time"], 123.5) and st2["room"] == 1, "istatistikler geri geldi (oda alanına dokunulmadı)")
	GameState.reset()


func _test_save_run() -> void:
	await _new_world("Kayıt: koşu odanın başında kendiliğinden kaydedilir, devam edince aynı oda, eşya, can ve altınla başlar")
	_clean_saves()
	# Kayıt slotu yokken hiçbir şey yazılmaz
	check(GameState.slot == null, "oturum açık değil")
	var run0 := _start_run(5)
	await _frames(3)
	check(not run0.save_checkpoint(), "slot yokken kaydedilmez")
	check(SaveStore.first_free() == 0, "diske hiçbir şey yazılmadı")
	run0.queue_free()
	await _frames(3)
	# Oturum aç: yeni slot, zorluk slottan gelir
	await _new_world("Kayıt: oturum ve ilk kayıt noktası")
	var slot := SaveSlot.create(0, "Deneme", Difficulty.Level.HARD)
	GameState.begin_session(slot, GameMode.Kind.NORMAL)
	check(GameState.difficulty == Difficulty.Level.HARD and GameState.slot == slot and GameState.mode == GameMode.Kind.NORMAL, "oturum: zorluk slottan geldi")
	var run := _start_run(4242)
	var p := run.player
	await _frames(3)
	var on_disk := SaveStore.load_slot(0)
	check(on_disk != null and on_disk.has_run(GameMode.Kind.NORMAL), "0. odaya girince koşu kendiliğinden kaydedildi")
	var r := on_disk.run_of(GameMode.Kind.NORMAL)
	check(SaveSlot._int(r["seed"]) == 4242 and SaveSlot._int(r["room"]) == 0 and SaveSlot._int(r["floor"]) == 1, "kayıt: tohum 4242, kat 1, oda 0")
	check(on_disk.progress_text(GameMode.Kind.NORMAL) == "KAT 1  ODA 1" and on_disk.difficulty == Difficulty.Level.HARD, "kaldığımız yer 'KAT 1  ODA 1', zorluk DIFFICULT")
	check((run.rooms[0] as Room).tuning.level == Difficulty.Level.HARD, "koşunun düşmanları slotun zorluğunda")
	var t0 := slot.playtime
	await _frames(30)
	check(slot.playtime > t0, "oynama süresi işliyor (%.2f sn)" % slot.playtime)
	# Oyuncu eşya toplasın, sonra yeni odaya geçsin
	p.inventory.add(_item("feather_boots"))
	p.inventory.give(_item("tower_bread"))
	p.gold = 41
	p.health = 3
	GameState.leave_behind(_item("mirror_boots"))
	run.stats["kills"] = 6
	var r0 := run.rooms[0] as Room
	var spawned := await _wait_until(func() -> bool: return r0.alive_count() >= 2, 240)
	check(spawned, "ilk dalga doğdu")
	_kill_all_enemies(p)
	var cleared := await _wait_until(func() -> bool: return r0.is_cleared(), 120)
	check(cleared, "oda temizlendi")
	p.global_position = Vector2(r0.rect.end.x - 150.0, 612.0)
	p.facing = 1
	p.intent.move_x = 1.0
	var entered := await _wait_until(func() -> bool: return run.current == 1, 150)
	p.intent.move_x = 0.0
	check(entered, "1. odaya geçildi")
	var saved := SaveStore.load_slot(0)
	var r1 := saved.run_of(GameMode.Kind.NORMAL)
	check(SaveSlot._int(r1["room"]) == 1 and saved.progress_text(GameMode.Kind.NORMAL) == "KAT 1  ODA 2", "yeni odaya girince kayıt güncellendi: " + saved.progress_text(GameMode.Kind.NORMAL))
	var pl: Dictionary = r1["player"]
	check(pl["equipped"] == ["feather_boots"] and SaveSlot._int(pl["gold"]) >= 41 and SaveSlot._int(pl["health"]) == 3, "kayıtta oyuncu: eşya, altın, can")
	check((r1["umbra"] as Array) == ["mirror_boots"], "kayıtta Umbra'nın eşyası")
	var layout1 := (run.rooms[1] as Room).layout_id
	var rect1_x := (run.rooms[1] as Room).rect.position.x
	var waves1 := _wave_names(run.make_waves(1))
	var gold_then := p.gold
	var kills_then := int(run.stats["kills"])
	check(kills_then >= 8 and SaveSlot._int(r1["stats"]["kills"]) == kills_then, "kayıttaki öldürme sayısı koşununkiyle aynı (%d)" % kills_then)
	run.queue_free()
	await _frames(3)
	GameState.reset()
	# --- Devam: yeni oyuncu, yeni koşu sahnesi; her şey kayıttan gelir
	await _new_world("Kayıt: devam et (odanın başından, kayıtlı durumla)")
	var slot2 := SaveStore.load_slot(0)
	GameState.begin_session(slot2, GameMode.Kind.NORMAL)
	GameState.resume_run = slot2.run_of(GameMode.Kind.NORMAL)
	var run2 := RUN.instantiate() as RunController
	run2.floors_enabled = false
	run2.seed_value = 999  # kayıttaki tohum kazanmalı
	var p2 := run2.get_node("Player") as Player
	p2.scripted = true
	_world.add_child(run2)
	(run2.get_node("Camera") as ShakeCamera).set_process(false)
	await _frames(3)
	check(GameState.resume_run.is_empty(), "bekleyen devam koşusu bir kez alındı")
	check(run2.run_seed == 4242 and run2.current == 1, "devam: kayıttaki tohum (4242) ve oda (1)")
	check(run2.rooms.has(0) and run2.rooms.has(1) and run2.rooms.has(2) and not run2.rooms.has(3), "önceki (sol sınır), mevcut ve sonraki oda kurulu")
	var rr := run2.rooms[1] as Room
	check(rr.layout_id == layout1 and is_equal_approx(rr.rect.position.x, rect1_x), "oda aynı yerleşim ve konumda (%s, x=%.0f)" % [rr.layout_id, rr.rect.position.x])
	check(_wave_names(run2.make_waves(1)) == waves1, "aynı dalgalar (tohum aynı): " + str(waves1))
	check((run2.rooms[0] as Room).door.is_blocking(), "sol sınır: önceki odanın kapısı kapalı")
	check(rr.rect.has_point(p2.global_position) and p2.global_position.x < rr.rect.position.x + 400.0, "oyuncu odanın başında (x=%.0f)" % p2.global_position.x)
	check(run2.camera.bounds.is_equal_approx(rr.camera_rect()), "kamera yeni odada")
	check(p2.inventory.has("feather_boots") and p2.inventory.bag_count("tower_bread") == 1 and p2.gold == gold_then and p2.health == 3, "oyuncu: eşya, çanta, altın (%d), can 3 geri geldi" % p2.gold)
	check(GameState.umbra_has("mirror_boots"), "Umbra'nın eşyası geri geldi")
	check(int(run2.stats["kills"]) == kills_then and int(run2.stats["room"]) == 2, "istatistikler: %d öldürme, oda 2" % kills_then)
	check(rr.tuning.level == Difficulty.Level.HARD and rr.tuning.progress == 1, "düşman ayarı: DIFFICULT, tur 1")
	var spawned2 := await _wait_until(func() -> bool: return rr.alive_count() >= 2, 300)
	check(spawned2 and rr.state == Room.State.ACTIVE, "devam edilen odada dalga başladı (%d düşman)" % rr.alive_count())
	# --- Ölüm: rekor işlenir, yarım koşu silinir
	_kill_all_enemies(p2)
	run2.stats["kills"] = 10
	run2.stats["best_combo"] = 8
	p2.health = 1
	p2.take_damage(99, null)
	await _frames(3)
	var after := SaveStore.load_slot(0)
	check(p2.dead and after != null and not after.has_run(GameMode.Kind.NORMAL), "ölünce yarım koşu silindi")
	check(int(after.records["runs"]) == 1 and int(after.records["deaths"]) == 1 and int(after.records["kills"]) == 10 and int(after.records["best_combo"]) == 8, "ölünce rekorlar işlendi %s" % str(after.records))
	check(int(after.records["best_floor"]) == 1 and int(after.records["best_room"]) == 2 and after.best_text(GameMode.Kind.NORMAL) == "EN İYİ KAT 1  ODA 2", "en iyi konum: " + after.best_text(GameMode.Kind.NORMAL))
	check(after.playtime > 0.0 and after.last_played >= after.created, "oynama süresi ve son oynama tarihi kaydedildi")
	run2.queue_free()
	await _frames(3)
	# --- Terk etme (R): ölüm sayılmaz
	await _new_world("Kayıt: koşuyu terk etmek ölüm sayılmaz")
	var slot3 := SaveStore.load_slot(0)
	GameState.begin_session(slot3, GameMode.Kind.NORMAL)
	var run3 := _start_run(31)
	await _frames(3)
	check(SaveStore.load_slot(0).has_run(GameMode.Kind.NORMAL), "yeni koşu kaydedildi")
	run3._finish_run(false)
	var ab := SaveStore.load_slot(0)
	check(not ab.has_run(GameMode.Kind.NORMAL) and int(ab.records["runs"]) == 2 and int(ab.records["deaths"]) == 1, "terk: koşu sayıldı (2), ölüm değil (1), yarım koşu silindi")
	run3.queue_free()
	await _frames(3)
	# --- Ölü oyuncu kaydetmez; Sınırsız kipte Normal koşu kaydı yazılmaz
	await _new_world("Kayıt: kip uyuşmazlığı ve ölü oyuncu")
	GameState.begin_session(SaveStore.load_slot(0), GameMode.Kind.ENDLESS)
	var run4 := _start_run(32)
	await _frames(3)
	check(not SaveStore.load_slot(0).has_run(GameMode.Kind.NORMAL), "Sınırsız kipte Normal koşu kaydı yazılmaz")
	GameState.mode = GameMode.Kind.NORMAL
	run4.player.dead = true
	check(not run4.save_checkpoint(), "ölü oyuncu kaydetmez")
	run4.player.dead = false
	run4.queue_free()
	await _frames(3)
	_end_saves()


## Dalga listesini karşılaştırmak için sahne adlarına çevirir.
func _wave_names(waves: Array) -> Array:
	var out: Array = []
	for w in waves:
		var names: Array = []
		for sc in w:
			names.append((sc as PackedScene).resource_path.get_file().get_basename())
		out.append(names)
	return out



# ------------------------------------------------------------------ çizim yükleyici ve ana menü

const MAIN_MENU := preload("res://ui/menu/main_menu.tscn")


## Art.draw / Art.draw_nine'ı gerçek bir _draw içinde çağırıp sonucunu saklar.
class _ArtProbe extends Control:
	var file := ""
	var nine := false
	var result := false

	func _draw() -> void:
		var r := Rect2(0.0, 0.0, 64.0, 64.0)
		result = Art.draw_nine(self, file, r) if nine else Art.draw(self, file, r, 0.0)


func _new_menu() -> MainMenu:
	var m := MAIN_MENU.instantiate() as MainMenu
	_world.add_child(m)
	return m


func _menu_key(code: Key, pressed := true, echo := false) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	e.echo = echo
	return e


## Yarım koşu kaydı örneği (menü testleri için): 1. kat, 3. oda.
func _fake_run(seed_value: int = 77, room: int = 2) -> Dictionary:
	return {"seed": seed_value, "floor": 1, "room": room, "wave": 0, "seen": [], "player": {"health": 3, "gold": 10, "equipped": [], "bag": []}}


func _test_art_loader() -> void:
	await _new_world("Art: çizim yükleyici (ada göre bulma, şerit kareleri, yoksa yer tutucu)")
	Art.reset()
	check(not Art.has("ui_logo") and Art.texture("ui_logo") == null and Art.frame_count("ui_logo") == 0, "çizim yokken: yok, doku null, kare 0")
	var img := Image.create(128, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	Art.override["ui_arrow_left"] = ImageTexture.create_from_image(img)
	check(Art.has("ui_arrow_left") and Art.frame_count("ui_arrow_left") == 4, "128x32 şerit, kare 32 geniş: 4 kare")
	check(Art.frame_at("ui_arrow_left", 0.0) == 0 and Art.frame_at("ui_arrow_left", 0.26) == 2 and Art.frame_at("ui_arrow_left", 0.51) == 0, "döngülü: 0.26 sn kare 2, 0.51 sn başa döner")
	check(Art.frame_rect("ui_arrow_left", 2) == Rect2(64.0, 0.0, 32.0, 32.0) and Art.frame_rect("ui_arrow_left", 99) == Rect2(96.0, 0.0, 32.0, 32.0), "kare alanı; sınır dışı kare sona çekilir")
	var strip := Image.create(288, 48, false, Image.FORMAT_RGBA8)
	Art.override["ui_heart_break"] = ImageTexture.create_from_image(strip)
	check(Art.frame_count("ui_heart_break") == 6 and Art.frame_at("ui_heart_break", 0.0) == 0 and Art.frame_at("ui_heart_break", 0.16) == 3, "tek seferlik şerit: 6 kare, ortada kare 3")
	check(Art.frame_at("ui_heart_break", 5.0) == 5 and Art.frame_at("ui_heart_break", -1.0) == 0, "tek seferlik: bitince son karede kalır, negatif süre ilk kare")
	Art.override["bilinmeyen_cizim"] = ImageTexture.create_from_image(img)
	check(Art.frame_count("bilinmeyen_cizim") == 1 and Art.frame_rect("bilinmeyen_cizim", 0) == Rect2(0.0, 0.0, 128.0, 32.0), "manifestte olmayan ad: tek kare")
	Art.override["ui_arrow_right"] = ImageTexture.create_from_image(Image.create(16, 16, false, Image.FORMAT_RGBA8))
	check(Art.frame_count("ui_arrow_right") == 1, "kare genişliğinden dar çizim: tek kare")
	# Gerçek bir _draw içinde
	var probe := _ArtProbe.new()
	_world.add_child(probe)
	probe.file = "ui_arrow_left"
	probe.queue_redraw()
	await _frames(3)
	check(probe.result, "Art.draw: çizim varsa çizer")
	probe.file = "ui_logo"
	probe.queue_redraw()
	await _frames(3)
	check(not probe.result, "Art.draw: çizim yoksa false (yer tutucu çizilir)")
	probe.nine = true
	probe.file = "ui_inv_panel"
	Art.override["ui_inv_panel"] = ImageTexture.create_from_image(Image.create(96, 96, false, Image.FORMAT_RGBA8))
	probe.queue_redraw()
	await _frames(3)
	check(probe.result, "Art.draw_nine: 9 dilimli çerçeve çizilir")
	# Dosya dizini: ada göre, klasör önemsiz
	var dir := "user://art_test"
	DirAccess.make_dir_recursive_absolute(dir + "/a")
	DirAccess.make_dir_recursive_absolute(dir + "/b")
	img.save_png(dir + "/a/ayni_ad.png")
	img.save_png(dir + "/b/ayni_ad.png")
	img.save_png(dir + "/b/sadece_b.png")
	var old_root := Art.root
	Art.root = dir
	Art.reset()
	check(Art.path_of("sadece_b") == dir + "/b/sadece_b.png" and Art.has("sadece_b"), "dosya adıyla bulunur (klasör önemsiz)")
	check(Art.path_of("ayni_ad") == dir + "/a/ayni_ad.png", "aynı ad iki yerdeyse alfabetik ilk klasör kazanır")
	check(Art.path_of("yok_boyle_dosya") == "" and not Art.has("yok_boyle_dosya"), "olmayan dosya: boş yol")
	for f in ["/a/ayni_ad.png", "/b/ayni_ad.png", "/b/sadece_b.png"]:
		DirAccess.remove_absolute(dir + f)
	for d in ["/a", "/b", ""]:
		DirAccess.remove_absolute(dir + d)
	Art.root = old_root
	Art.reset()
	check(Art.override.is_empty() and Art.texture("ui_arrow_left") == null, "reset: geçersiz kılmalar temizlendi")


func _test_menu_input() -> void:
	await _new_world("Menü: giriş eşlemesi (klavye, kumanda, çubuk, yazı modu)")
	_clean_saves()
	var m := _new_menu()
	await _frames(2)
	check(m.top_id() == "title" and m.stack.size() == 1, "açılış: başlık ekranı")
	check(m.action_of(_menu_key(KEY_W)) == "up" and m.action_of(_menu_key(KEY_S)) == "down" and m.action_of(_menu_key(KEY_A)) == "left" and m.action_of(_menu_key(KEY_D)) == "right", "WASD gezinir")
	check(m.action_of(_menu_key(KEY_UP)) == "up" and m.action_of(_menu_key(KEY_DOWN)) == "down" and m.action_of(_menu_key(KEY_LEFT)) == "left" and m.action_of(_menu_key(KEY_RIGHT)) == "right", "ok tuşları gezinir")
	check(m.action_of(_menu_key(KEY_ENTER)) == "accept" and m.action_of(_menu_key(KEY_SPACE)) == "accept" and m.action_of(_menu_key(KEY_E)) == "accept" and m.action_of(_menu_key(KEY_J)) == "accept", "Enter / Space / E / J seçer")
	check(m.action_of(_menu_key(KEY_ESCAPE)) == "back" and m.action_of(_menu_key(KEY_BACKSPACE)) == "back", "Esc ve Backspace geri")
	check(m.action_of(_menu_key(KEY_DELETE)) == "delete", "Delete: sil")
	check(m.action_of(_menu_key(KEY_W, false)) == "" and m.action_of(_menu_key(KEY_K)) == "", "tuş bırakma ve ilgisiz tuş eylem değil")
	check(m.action_of(_menu_key(KEY_ENTER, true, true)) == "" and m.action_of(_menu_key(KEY_DOWN, true, true)) == "down", "tuş tekrarı: yön tuşu tekrarlar, Enter tekrarlamaz")
	var jb := InputEventJoypadButton.new()
	jb.pressed = true
	jb.button_index = JOY_BUTTON_DPAD_UP
	var pad_up := m.action_of(jb)
	jb.button_index = JOY_BUTTON_A
	var pad_a := m.action_of(jb)
	jb.button_index = JOY_BUTTON_B
	var pad_b := m.action_of(jb)
	check(pad_up == "up" and pad_a == "accept" and pad_b == "back", "kumanda: D-pad yukarı, A seç, B geri")
	var jm := InputEventJoypadMotion.new()
	jm.axis = JOY_AXIS_LEFT_Y
	jm.axis_value = 0.8
	var s1 := m.action_of(jm)
	jm.axis_value = 0.9
	var s2 := m.action_of(jm)
	jm.axis_value = 0.1
	var s3 := m.action_of(jm)
	jm.axis_value = -0.8
	var s4 := m.action_of(jm)
	check(s1 == "down" and s2 == "" and s3 == "" and s4 == "up", "sol çubuk: itişte bir kez, basılı tutarken tekrarlamaz, bırakınca yeniden")
	# Yazı modu: harf tuşları gezinmez, yazılır
	m.push(NewGameScreen.new(0))
	check(m.top().wants_text(), "yeni oyun adımı yazı modunda")
	check(m.action_of(_menu_key(KEY_W)) == "" and m.action_of(_menu_key(KEY_SPACE)) == "" and m.action_of(_menu_key(KEY_E)) == "", "yazı modunda harf tuşları ve Space gezinme/seçme olmaz")
	check(m.action_of(_menu_key(KEY_BACKSPACE)) == "backspace" and m.action_of(_menu_key(KEY_ENTER)) == "accept" and m.action_of(_menu_key(KEY_ESCAPE)) == "back" and m.action_of(_menu_key(KEY_UP)) == "up", "yazı modunda Backspace siler; Enter, Esc, ok tuşları çalışır")
	var typed := _menu_key(KEY_W)
	typed.unicode = "w".unicode_at(0)
	m._unhandled_input(typed)
	check((m.top() as NewGameScreen).name_text == "W", "gerçek tuş olayı: 'w' yazıldı (büyük harf)")
	# Yazı modu dışında yazılan harf isme gitmez
	m.pop()
	m.type_char("x")
	check(m.top_id() == "title", "başlıkta karakter yazmak bir şey yapmaz")
	_end_saves()


func _test_menu_flow() -> void:
	await _new_world("Menü: başlık ekranı, krediler, çıkış ve fare")
	_clean_saves()
	var quits := [0]
	SceneRouter.quit_hook = func() -> void: quits[0] += 1
	var m := _new_menu()
	await _frames(2)
	var title := m.top() as TitleScreen
	check(title != null and title.list.count() == 3 and title.list.current_id() == "play", "başlık: 3 seçenek, imleç OYNA'da")
	m.press("down")
	check(title.list.current_id() == "credits", "aşağı: KREDİLER")
	m.press("down")
	m.press("down")
	check(title.list.current_id() == "play", "aşağı uçta başa sarar")
	m.press("up")
	check(title.list.current_id() == "quit", "yukarı başta sona sarar")
	m.press("up")
	m.press("accept")
	check(m.top_id() == "credits", "KREDİLER açıldı")
	var cr := m.top() as CreditsScreen
	var o0 := cr.offset
	cr.on_tick(1.0)
	check(cr.offset > o0 and cr.content_height() > 500.0, "krediler kayıyor, içerik dolu (%.0f px)" % cr.content_height())
	var kinds_ok := true
	for l in CreditsScreen.LINES:
		if not CreditsScreen.HEIGHTS.has(l[0]):
			kinds_ok = false
	check(kinds_ok, "kredi satırlarının hepsi bilinen türde")
	m.press("up")
	check(cr.offset >= 0.0, "yukarı kaydırma sınırı aşmaz")
	await _frames(3)
	m.press("back")
	check(m.top_id() == "title", "geri: başlığa dönüldü")
	# Fare
	var r_quit := title.list.rect_of(2)
	m.hover_at(r_quit.get_center())
	check(title.list.current_id() == "quit", "fare üstüne gelince seçer")
	m.click_at(Vector2(4.0, 4.0))
	check(quits[0] == 0, "boş yere tıklamak çıkış yapmaz")
	m.click_at(r_quit.get_center())
	check(quits[0] == 1, "ÇIKIŞ'a tıklayınca çıkış kancası çağrıldı")
	m.press("back")
	m.pop()
	check(m.top_id() == "title" and m.stack.size() == 1, "kök ekranda geri/pop ekranı kapatmaz")
	title.list.focus("play")
	m.press("accept")
	check(m.top_id() == "slots", "OYNA: kayıt ekranı")
	await _frames(3)
	m.press("back")
	check(m.top_id() == "title", "geri: başlık")
	m.push(CreditsScreen.new())
	m.push(SlotsScreen.new())
	m.pop_to_root()
	check(m.stack.size() == 1 and m.top_id() == "title", "pop_to_root: başlığa döner")
	# F8: kayıtsız hızlı koşu (yalnız başlıkta)
	var went := [""]
	SceneRouter.hook = func(path: String) -> void: went[0] = path
	m.push(CreditsScreen.new())
	m._unhandled_input(_menu_key(KEY_F8))
	check(went[0] == "", "F8 yalnız başlık ekranında çalışır")
	m.pop()
	m._unhandled_input(_menu_key(KEY_F8))
	check(went[0] == SceneRouter.RUN and GameState.slot == null, "F8: kayıtsız koşu sahnesi")
	SceneRouter.hook = Callable()
	SceneRouter.quit_hook = Callable()
	_end_saves()


func _test_menu_slots() -> void:
	await _new_world("Menü: kayıt ekranı (boş/dolu kartlar, yeni oyun sihirbazı, silme)")
	_clean_saves()
	var m := _new_menu()
	await _frames(2)
	m.press("accept")
	var sl := m.top() as SlotsScreen
	check(sl != null and sl.slots.size() == 3 and sl.slot_at(0) == null and sl.slot_at(1) == null and sl.slot_at(2) == null, "üç boş kart")
	check(sl.cursor == 0, "hepsi boşken imleç ilk kartta")
	m.press("down")
	m.press("down")
	check(sl.cursor == 2, "aşağı: 3. kart")
	m.press("down")
	check(sl.cursor == 0, "aşağı uçta başa sarar")
	m.press("delete")
	check(m.top_id() == "slots", "boş kartı silmeye çalışmak onay açmaz")
	await _frames(3)
	# Yeni oyun: isim
	m.press("accept")
	check(m.top_id() == "new_game", "boş kart: yeni oyun sihirbazı")
	var ng := m.top() as NewGameScreen
	check(ng.slot_index == 0 and ng.step == 0 and ng.wants_text() and ng.name_text == "", "adım 1: isim, boş")
	m.type_text("ali veli")
	check(ng.name_text == "ALİ VELİ", "Türkçe büyük harf: 'ali veli' -> 'ALİ VELİ' (i -> İ)")
	m.type_text("<_>")
	check(ng.name_text == "ALİ VELİ", "yazı tipinde olmayan karakterler yazılmaz")
	m.type_text("1234567890")
	check(ng.name_text == "ALİ VELİ1234" and ng.name_text.length() == SaveSlot.NAME_MAX, "en çok %d karakter" % SaveSlot.NAME_MAX)
	m.press("backspace")
	check(ng.name_text == "ALİ VELİ123", "Backspace sondan siler")
	await _frames(3)
	m.press("accept")
	check(ng.step == 1 and not ng.wants_text() and ng.level == Difficulty.DEFAULT, "adım 2: zorluk, varsayılan NORMAL")
	m.press("down")
	check(ng.level == Difficulty.Level.HARD, "aşağı: DIFFICULT")
	m.press("down")
	m.press("down")
	check(ng.level == Difficulty.Level.EASY, "aşağı uçta başa sarar: EASY")
	m.press("up")
	check(ng.level == Difficulty.Level.IMMORTAL, "yukarı başta sona sarar: IMMORTAL")
	await _frames(3)
	m.press("back")
	check(ng.step == 0 and ng.name_text == "ALİ VELİ123" and m.top_id() == "new_game", "geri: isim adımına döner, isim korunur")
	m.press("accept")
	check(ng.step == 1 and ng.level == Difficulty.Level.IMMORTAL, "yeniden ileri: seçili zorluk korunur")
	m.press("accept")
	check(m.top_id() == "slot" and (m.top() as SlotMenuScreen).slot.index == 0, "oluşturunca kayıt menüsü açıldı")
	var disk := SaveStore.load_slot(0)
	check(disk != null and disk.name == "ALİ VELİ123" and disk.difficulty == Difficulty.Level.IMMORTAL and not disk.has_run(GameMode.Kind.NORMAL), "diskte: ad, zorluk IMMORTAL, koşu yok")
	m.press("back")
	check(m.top_id() == "slots" and sl.slot_at(0) != null and sl.slot_at(0).name == "ALİ VELİ123", "geri: kayıt ekranı, kart doldu")
	# Mouse ile 3. slot; boş isim = varsayılan
	m.click_at(sl.card_rect(2).get_center())
	check(m.top_id() == "new_game" and (m.top() as NewGameScreen).slot_index == 2, "karta tıklamak onu açar (3. kart)")
	m.press("accept")
	m.press("accept")
	var d2 := SaveStore.load_slot(2)
	check(d2 != null and d2.name == SaveSlot.DEFAULT_NAME and d2.difficulty == Difficulty.DEFAULT, "boş isim varsayılana döndü, zorluk NORMAL")
	m.press("back")
	# Son oynanan slota imleç
	var s0 := SaveStore.load_slot(0)
	var s2 := SaveStore.load_slot(2)
	s2.last_played = s0.last_played + 500
	SaveStore.save_slot(s2)
	m.pop_to_root()
	m.press("accept")
	sl = m.top() as SlotsScreen
	check(sl.cursor == 2, "kayıt ekranı en son oynanan slotta açılır")
	# Silme: vazgeç, sonra onayla
	sl.cursor = 0
	m.press("delete")
	check(m.top_id() == "confirm" and (m.top() as ConfirmScreen).cursor == 1, "Del: onay penceresi, imleç güvenli seçenekte (hayır)")
	await _frames(3)
	m.press("accept")
	check(m.top_id() == "slots" and SaveStore.load_slot(0) != null, "VAZGEÇ: kayıt silinmedi")
	m.press("delete")
	m.press("left")
	m.press("accept")
	check(m.top_id() == "slots" and SaveStore.load_slot(0) == null and sl.slot_at(0) == null, "SİL: kayıt diskten ve karttan kalktı")
	check(m.message() == "SLOT 1 SİLİNDİ" and SaveStore.load_slot(2) != null, "mesaj gösterildi, diğer kayıt yerinde")
	_end_saves()


func _test_menu_slot_menu() -> void:
	await _new_world("Menü: kayıt menüsü (kipler, devam, yeni koşu, zorluk, silme) ve oyuna geçiş")
	_clean_saves()
	var went := [""]
	SceneRouter.hook = func(path: String) -> void: went[0] = path
	var s := SaveSlot.create(1, "Test", Difficulty.Level.NORMAL)
	s.set_run(GameMode.Kind.NORMAL, _fake_run())
	s.records["best_floor"] = 2
	s.records["best_room"] = 4
	check(SaveStore.save_slot(s), "kayıt yazıldı")
	var m := _new_menu()
	await _frames(2)
	m.press("accept")
	check(m.top_id() == "slots" and (m.top() as SlotsScreen).cursor == 1, "dolu tek kayıt: imleç ona")
	m.press("accept")
	var sm := m.top() as SlotMenuScreen
	check(sm != null and sm.slot.name == "Test", "dolu kart: kayıt menüsü")
	var ids: Array = []
	for r in sm.list.rows:
		ids.append(r["id"])
	check(ids == ["play_normal", "new_normal", "play_endless", "difficulty", "delete", "back"], "satırlar: " + str(ids))
	check(sm.list.rows[0]["text"] == "NORMAL  DEVAM" and sm.list.rows[0]["note"] == "KAT 1  ODA 3", "yarım koşu: DEVAM ve kaldığın yer (KAT 1  ODA 3)")
	var endless_ok := SceneRouter.can_play(GameMode.Kind.ENDLESS)
	check(bool(sm.list.rows[2]["enabled"]) == endless_ok and bool(sm.list.rows[0]["enabled"]), "NORMAL açık; SINIRSIZ yalnız sahnesi varsa açık")
	await _frames(3)
	if not endless_ok:
		check(sm.list.rows[2]["note"] == "YAKINDA", "kapalı kipte YAKINDA notu")
		sm.list.focus("play_endless")
		m.press("accept")
		check(went[0] == "" and m.message() == "BU KİP HENÜZ HAZIR DEĞİL", "kapalı kipe girilmez, mesaj gösterilir")
		check(not m.start_game(sm.slot, GameMode.Kind.ENDLESS, false) and GameState.slot == null, "sahnesi olmayan kip başlatılamaz, oturum açılmaz")
	# Zorluk yarım koşu varken kilitli
	sm.list.focus("difficulty")
	m.press("right")
	check(sm.slot.difficulty == Difficulty.Level.NORMAL and m.message() == "YARIM KOŞU VARKEN ZORLUK DEĞİŞMEZ", "yarım koşu varken zorluk değişmez")
	# Devam
	sm.list.focus("play_normal")
	m.press("accept")
	check(went[0] == SceneRouter.RUN, "DEVAM: koşu sahnesine geçildi")
	check(GameState.slot != null and GameState.slot.index == 1 and GameState.mode == GameMode.Kind.NORMAL and GameState.difficulty == Difficulty.Level.NORMAL, "oturum kayıtla kuruldu")
	check(not GameState.resume_run.is_empty() and SaveSlot._int(GameState.resume_run["seed"]) == 77, "kayıtlı koşu devam için hazır (tohum 77)")
	GameState.end_session()
	went[0] = ""
	# Yeni koşu: vazgeç, sonra onayla
	sm.list.focus("new_normal")
	m.press("accept")
	check(m.top_id() == "confirm", "YENİ KOŞU: onay soruldu")
	m.press("accept")
	check(m.top_id() == "slot" and went[0] == "" and SaveStore.load_slot(1).has_run(GameMode.Kind.NORMAL), "VAZGEÇ: yarım koşu silinmedi")
	m.press("accept")
	m.press("left")
	m.press("accept")
	check(went[0] == SceneRouter.RUN and GameState.resume_run.is_empty(), "onaylandı: koşu sahnesi, devam verisi yok (yeni koşu)")
	check(not SaveStore.load_slot(1).has_run(GameMode.Kind.NORMAL), "eski yarım koşu diskten silindi")
	check(SaveStore.load_slot(1).records["best_floor"] == 2, "rekorlar korundu")
	GameState.end_session()
	went[0] = ""
	# Koşu yok: BAŞLA ve zorluk serbest
	check(not sm.has_any_run() and sm.list.rows[0]["text"] == "NORMAL  BAŞLA" and sm.list.index_of("new_normal") == -1, "koşu yok: BAŞLA, YENİ KOŞU satırı yok")
	sm.list.focus("difficulty")
	m.press("right")
	check(sm.slot.difficulty == Difficulty.Level.HARD and SaveStore.load_slot(1).difficulty == Difficulty.Level.HARD, "sağ: DIFFICULT, diske yazıldı")
	m.press("left")
	m.press("left")
	check(sm.slot.difficulty == Difficulty.Level.EASY, "sol sol: EASY")
	m.press("left")
	check(sm.slot.difficulty == Difficulty.Level.IMMORTAL, "sol başta sona sarar: IMMORTAL")
	m.press("right")
	check(sm.slot.difficulty == Difficulty.Level.EASY, "sağ sonda başa sarar: EASY")
	await _frames(3)
	sm.list.focus("play_normal")
	m.press("accept")
	check(went[0] == SceneRouter.RUN and GameState.difficulty == Difficulty.Level.EASY and GameState.resume_run.is_empty(), "BAŞLA: seçili zorlukla yeni koşu")
	GameState.end_session()
	went[0] = ""
	# Fare: satıra tıklamak çalıştırır
	m.click_at(sm.list.rect_of(sm.list.index_of("delete")).get_center())
	check(m.top_id() == "confirm", "satıra tıklamak çalıştırır (KAYDI SİL onayı)")
	m.press("left")
	m.press("accept")
	check(m.top_id() == "slots" and SaveStore.load_slot(1) == null and (m.top() as SlotsScreen).slot_at(1) == null, "kayıt silindi, kayıt ekranına dönüldü")
	check(m.message() == "KAYIT SİLİNDİ", "silme mesajı")
	SceneRouter.hook = Callable()
	_end_saves()


func _test_menu_pause() -> void:
	await _new_world("Menü: duraklatma menüsü, ana menüye dönüş, ölüm ekranında M")
	_clean_saves()
	GameState.end_session()
	var went := [""]
	SceneRouter.hook = func(path: String) -> void: went[0] = path
	var run := _start_run(5)
	await _frames(3)
	var pm := run.hud.pause_menu
	check(pm != null and not pm.is_open, "duraklatma menüsü HUD'da var, kapalı")
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	pm._unhandled_input(esc)
	check(pm.is_open and get_tree().paused, "Esc: açıldı, oyun durdu")
	check(pm.list.current_id() == "resume", "imleç DEVAM ET'te")
	pm.press("down")
	check(pm.list.current_id() == "restart", "aşağı: YENİDEN BAŞLA")
	pm.press("accept")
	check(pm.armed == "restart" and pm.is_open and went[0] == "", "YENİDEN BAŞLA ilk basışta onay ister")
	pm.press("down")
	check(pm.armed == "" and pm.list.current_id() == "menu", "imleç oynayınca onay iptal olur")
	pm.press("accept")
	check(pm.armed == "menu" and went[0] == "", "kayıtsız oturumda ANA MENÜ de onay ister")
	await _frames(3)
	pm.press("accept")
	check(went[0] == SceneRouter.MENU and not pm.is_open and not get_tree().paused, "ikinci basış: ana menüye geçildi, duraklama kalktı")
	went[0] = ""
	pm.open(run.player)
	pm._unhandled_input(esc)
	check(not pm.is_open and not get_tree().paused, "Esc yeniden: kapandı, oyun sürüyor")
	pm.open(run.player)
	pm.press("accept")
	check(not pm.is_open, "DEVAM ET: kapanır")
	# Başka menü açıkken Esc duraklatmayı açmaz
	run.hud.inventory_screen.open(run.player)
	pm._unhandled_input(esc)
	check(not pm.is_open and ItemView.active_menu == run.hud.inventory_screen, "envanter açıkken Esc duraklatmayı açmaz")
	run.hud.inventory_screen.close()
	# Ölüyken açılmaz; ölüm ekranında M
	run.player.dead = true
	pm._unhandled_input(esc)
	check(not pm.is_open, "ölüyken duraklatma açılmaz")
	run._unhandled_key_input(_ui_key(KEY_M))
	check(went[0] == SceneRouter.MENU, "ölüm ekranında M: ana menü")
	went[0] = ""
	run.player.dead = false
	run._unhandled_key_input(_ui_key(KEY_M))
	check(went[0] == "", "yaşarken M bir şey yapmaz")
	run.queue_free()
	await _frames(3)
	# Kayıtlı oturum: onay istemez, süre yazılır, yarım koşu (oda başı) durur
	await _new_world("Menü: kayıtlı oturumda ana menüye dönüş")
	var slot := SaveSlot.create(0, "Deneme", Difficulty.Level.NORMAL)
	GameState.begin_session(slot, GameMode.Kind.NORMAL)
	var run2 := _start_run(9)
	await _frames(40)
	var played := slot.playtime
	check(played > 0.0 and SaveStore.load_slot(0).has_run(GameMode.Kind.NORMAL), "koşu sürüyor, oda başı kaydı var")
	var pm2 := run2.hud.pause_menu
	pm2.open(run2.player)
	pm2.list.focus("menu")
	check(not pm2.needs_confirm("menu") and pm2.needs_confirm("restart"), "kayıtlı oturumda ANA MENÜ onay istemez, YENİDEN BAŞLA ister")
	run2.return_to_menu()
	check(went[0] == SceneRouter.MENU and GameState.slot == null and not get_tree().paused, "ana menüye dönüldü, oturum kapandı")
	var disk := SaveStore.load_slot(0)
	check(disk != null and disk.has_run(GameMode.Kind.NORMAL) and disk.playtime >= played - 0.01, "diskte: yarım koşu duruyor, süre yazıldı (%.1f sn)" % disk.playtime)
	run2.queue_free()
	await _frames(3)
	SceneRouter.hook = Callable()
	_end_saves()


# ------------------------------------------------------------------ katlar, dükkân, Gölge odası

func _test_floor_plan() -> void:
	print("\nKat planı: 18 kat x 6 oda (lobi, 4 savaş, Gölge), tur ilerlemesi, temalar")
	check(FloorPlan.ROOMS_PER_FLOOR == 6 and FloorPlan.FLOOR_COUNT == 18 and FloorPlan.COMBAT_ROOMS == 4, "kat başına 6 oda (4 savaş), toplam 18 kat")
	var lobbies := 0
	var combats := 0
	var bosses := 0
	var monotonic := true
	var shape_ok := true
	var prev_progress := -1
	for i in FloorPlan.FLOOR_COUNT * FloorPlan.ROOMS_PER_FLOOR:
		var loc := FloorPlan.locate(i)
		match int(loc["kind"]):
			FloorPlan.Kind.LOBBY:
				lobbies += 1
			FloorPlan.Kind.BOSS:
				bosses += 1
			_:
				combats += 1
		if int(loc["progress"]) < prev_progress:
			monotonic = false
		prev_progress = int(loc["progress"])
		if int(loc["floor"]) != i / 6 + 1 or int(loc["slot"]) != i % 6 or int(loc["number"]) != i % 6 + 1 or int(loc["first"]) != (i / 6) * 6:
			shape_ok = false
		if bool(loc["last"]) != (i % 6 == 5):
			shape_ok = false
	check(lobbies == 18 and combats == 72 and bosses == 18, "18 lobi, 72 savaş, 18 Gölge odası (%d/%d/%d)" % [lobbies, combats, bosses])
	check(monotonic, "tur ilerlemesi hiç geri gitmiyor")
	check(shape_ok, "kat / sıra / numara / ilk oda / son oda tutarlı")
	var l0 := FloorPlan.locate(0)
	check(int(l0["floor"]) == 1 and int(l0["kind"]) == FloorPlan.Kind.LOBBY and int(l0["number"]) == 1 and int(l0["progress"]) == 0, "oda 0: kat 1 lobisi")
	var l1 := FloorPlan.locate(1)
	check(int(l1["kind"]) == FloorPlan.Kind.COMBAT and int(l1["number"]) == 2 and int(l1["progress"]) == 0, "oda 1: ilk savaş odası, tur 0")
	check(int(FloorPlan.locate(4)["progress"]) == 3, "kat 1'in son savaş odası: tur 3")
	var l5 := FloorPlan.locate(5)
	check(int(l5["kind"]) == FloorPlan.Kind.BOSS and int(l5["number"]) == 6 and bool(l5["last"]) and int(l5["progress"]) == 4, "oda 5: Gölge odası, son oda")
	var l6 := FloorPlan.locate(6)
	check(int(l6["floor"]) == 2 and int(l6["kind"]) == FloorPlan.Kind.LOBBY and int(l6["progress"]) == 4, "oda 6: kat 2 lobisi, ilerleme sürüyor")
	var l107 := FloorPlan.locate(107)
	check(int(l107["floor"]) == 18 and int(l107["kind"]) == FloorPlan.Kind.BOSS and int(l107["progress"]) == 72, "son oda: kat 18 Gölge'si, tur 72")
	check(FloorPlan.index_of(3, 2) == 14 and FloorPlan.first_index_of(18) == 102 and FloorPlan.index_of(1, 99) == 5 and FloorPlan.index_of(1, -4) == 0, "oda numarası <-> kat/sıra (kırpılır)")
	check(FloorPlan.is_final_floor(18) and not FloorPlan.is_final_floor(17), "son kat 18")
	check(FloorPlan.theme_of(1) == "kat1" and FloorPlan.theme_of(4) == "kat1" and FloorPlan.theme_of(5) == "kat2" and FloorPlan.theme_of(13) == "kat4" and FloorPlan.theme_of(17) == "kat5" and FloorPlan.theme_of(18) == "kat5", "tema her 4 katta bir değişir, son iki kat tutulma")
	var old := FloorPlan.locate(7, false)
	check(int(old["floor"]) == 1 and int(old["slot"]) == 7 and int(old["kind"]) == FloorPlan.Kind.COMBAT and int(old["number"]) == 8 and int(old["progress"]) == 7 and not bool(old["last"]), "katsız kip: tek sonsuz şerit, ilerleme = oda no")
	check(FloorPlan.room_label(l0) == "LOBİ" and FloorPlan.room_label(l5) == "GÖLGE" and FloorPlan.room_label(FloorPlan.locate(3)) == "ODA 4", "oda adları")
	check(RunController.progress_of(14, true) == int(FloorPlan.locate(14)["progress"]) and RunController.progress_of(14) == 14, "RunController.progress_of: katlı / katsız")


func _test_shop_stock() -> void:
	await _new_world("Dükkân rafı: tohumla aynı, sahip olunanı ve Umbra'nınkini içermez, satış kuralları")
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 77
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 77
	var a := ShopStock.generate(rng_a, 1)
	var b := ShopStock.generate(rng_b, 1)
	check(a.size() == ShopStock.GEAR_OFFERS + ShopStock.FOOD_OFFERS, "kat 1: %d eşya + %d yemek (%d)" % [ShopStock.GEAR_OFFERS, ShopStock.FOOD_OFFERS, a.size()])
	var same := a.size() == b.size()
	for i in mini(a.size(), b.size()):
		if a.offers[i].item.id != b.offers[i].item.id or a.offers[i].price != b.offers[i].price:
			same = false
	check(same, "aynı tohum aynı raf")
	var varied := false
	for s in range(1, 30):
		var r := RandomNumberGenerator.new()
		r.seed = s
		var other := ShopStock.generate(r, 1)
		for i in mini(a.size(), other.size()):
			if other.offers[i].item.id != a.offers[i].item.id:
				varied = true
	check(varied, "başka tohum başka raf")
	var late_rng := RandomNumberGenerator.new()
	late_rng.seed = 3
	var late := ShopStock.generate(late_rng, 6)
	check(late.size() == ShopStock.GEAR_OFFERS_LATE + ShopStock.FOOD_OFFERS, "kat 6: 4 eşya + 2 yemek (%d)" % late.size())
	# Değere göre raf: Efsanevi ve Lanetli HİÇBİR katta çıkmaz; fiyat sınırı; yemekler tam sayıda
	var no_cursed := true
	var no_epic := true
	var no_legend_ids := true
	var price_ok := true
	var all_sellable := true
	var rare_seen := false
	var food_count_ok := true
	for f in [1, 2, 3, 4, 8, 12, 18]:
		for s in 60:
			var r := RandomNumberGenerator.new()
			r.seed = s * 31 + f
			var st := ShopStock.generate(r, f)
			var foods := 0
			for o in st.offers:
				if o.item.rarity == ItemData.Rarity.CURSED:
					no_cursed = false
				if o.item.rarity == ItemData.Rarity.EPIC:
					no_epic = false
				if o.item.id == "vampire_relic" or o.item.id == "saturn_hourglass":
					no_legend_ids = false
				if not ShopStock.sellable(o.item):
					all_sellable = false
				if o.item.is_food():
					foods += 1
				else:
					if o.item.price > ShopStock.MAX_PRICE:
						price_ok = false
					if o.item.rarity == ItemData.Rarity.RARE:
						rare_seen = true
			if foods != ShopStock.FOOD_OFFERS:
				food_count_ok = false
	check(no_cursed, "Lanetli eşya dükkânda yok")
	check(no_epic and no_legend_ids, "Efsanevi (en değerli) eşya hiçbir katta dükkâna düşmüyor (kat 1..18, 420 raf)")
	check(price_ok and all_sellable, "rafın her eşyası satılabilir sınırlar içinde (nadirlik + fiyat tavanı)")
	check(rare_seen, "Nadir eşya yine de çıkabiliyor")
	check(food_count_ok, "her rafta tam %d yemek var" % ShopStock.FOOD_OFFERS)
	# Satılabilirlik kuralı
	check(not ShopStock.sellable(_item("vampire_relic")) and not ShopStock.sellable(_item("saturn_hourglass")), "Vampir Yadigârı ve Satürn'ün Kum Saati satılamaz")
	check(ShopStock.sellable(_item("watcher_band")) and ShopStock.sellable(_item("viper_fang")) and ShopStock.sellable(_item("tower_bread")) and ShopStock.sellable(_item("cosmic_star_soup")), "yaygın/nadir eşya ve yemekler satılabilir")
	var pricey := _dummy_item("pahali_yaygin")
	pricey.slot = ItemData.Slot.CHARM
	pricey.rarity = ItemData.Rarity.COMMON
	pricey.price = ShopStock.MAX_PRICE + 1
	var cursed := _dummy_item("lanetli_ucuz")
	cursed.slot = ItemData.Slot.CHARM
	cursed.rarity = ItemData.Rarity.CURSED
	cursed.price = 10
	var fair := _dummy_item("makul_nadir")
	fair.slot = ItemData.Slot.CHARM
	fair.rarity = ItemData.Rarity.RARE
	fair.price = ShopStock.MAX_PRICE
	check(not ShopStock.sellable(pricey) and not ShopStock.sellable(cursed) and ShopStock.sellable(fair) and not ShopStock.sellable(null), "fiyat tavanı: yaygın bile olsa pahalı eşya satılmaz; ucuz Lanetli satılmaz; tavan fiyatlı Nadir satılır")
	check(ShopStock.max_rarity(1) == ItemData.Rarity.RARE and ShopStock.max_rarity(18) == ItemData.Rarity.RARE, "en yüksek satılabilir nadirlik her katta NADİR")
	# Şans (ağırlık) değere göre: yaygın > nadir; nadir derin katlarda sıklaşır
	var wb := _item("watcher_band")
	var vf := _item("viper_fang")
	check(is_equal_approx(ShopStock.weight_of(wb, 1), 60.0) and is_equal_approx(ShopStock.weight_of(wb, 18), 60.0), "yaygın eşyanın şansı katla değişmez (60)")
	check(is_equal_approx(ShopStock.weight_of(vf, 1), 30.0 * ShopStock.RARE_EARLY_WEIGHT) and is_equal_approx(ShopStock.weight_of(vf, ShopStock.RARE_FULL_FLOOR), 30.0) and is_equal_approx(ShopStock.weight_of(vf, 18), 30.0), "nadir eşya: 1. katta yarı şans, 9. katta tam şans")
	check(ShopStock.weight_of(vf, 5) > ShopStock.weight_of(vf, 1) and ShopStock.weight_of(vf, 5) < ShopStock.weight_of(vf, 9), "nadir eşyanın şansı kat kat artıyor")
	var rare_share := {}
	for f in [1, 9]:
		var rares := 0
		var gears := 0
		var commons := 0
		for s in 300:
			var r := RandomNumberGenerator.new()
			r.seed = s + f * 1000
			for o in ShopStock.generate(r, f).offers:
				if o.item.is_food():
					continue
				gears += 1
				if o.item.rarity == ItemData.Rarity.RARE:
					rares += 1
				else:
					commons += 1
		rare_share[f] = float(rares) / float(maxi(gears, 1))
		check(commons > rares, "kat %d: yaygın eşya nadirden çok çıkıyor (%d yaygın / %d nadir)" % [f, commons, rares])
	check(rare_share[9] > rare_share[1] + 0.05 and rare_share[1] > 0.0, "nadir payı derin katta daha yüksek (kat 1: %.2f, kat 9: %.2f)" % [rare_share[1], rare_share[9]])
	# Uygun eşya kalmazsa raf eksik kalır; Efsanevi'ye asla düşülmez
	var every_sellable: Array = []
	for it in ItemDB.equipment():
		if ShopStock.sellable(it):
			every_sellable.append(it.id)
	var drained := true
	var empty_gear := true
	for s in 20:
		var r := RandomNumberGenerator.new()
		r.seed = s
		var st := ShopStock.generate(r, 12, every_sellable)
		for o in st.offers:
			if not o.item.is_food():
				empty_gear = false
			if o.item.rarity == ItemData.Rarity.EPIC:
				drained = false
		if st.size() != ShopStock.FOOD_OFFERS:
			drained = false
	check(empty_gear and drained, "hepsi sahipliyken raf yalnız yemek satar (Efsanevi'ye düşmez)")
	# Sahip olunan ve Umbra'nın eşyaları çıkmaz
	var gear := ItemDB.equipment()
	var banned: Array = []
	for i in mini(14, gear.size()):
		banned.append(gear[i].id)
	var clean := true
	for s in 30:
		var r := RandomNumberGenerator.new()
		r.seed = s
		var st := ShopStock.generate(r, 5, banned.slice(0, 7), banned.slice(7))
		for o in st.offers:
			if o.item.id in banned:
				clean = false
	check(clean, "sahip olunan ve Umbra'ya kalan eşyalar rafa konmuyor")
	# Fiyat
	var it := _item("watcher_band")
	check(ShopStock.price_of(it, 1) == it.price and ShopStock.price_of(it, 10) > ShopStock.price_of(it, 1) and ShopStock.price_of(it, 1) >= 1, "fiyat kat arttıkça pahalanıyor (%d -> %d)" % [ShopStock.price_of(it, 1), ShopStock.price_of(it, 10)])
	# Satın alma
	var p := _spawn_player(500.0)
	var inv := p.inventory
	var stock := ShopStock.new()
	stock._add(_item("watcher_band"), 1)
	stock._add(_item("tower_bread"), 1)
	stock._add(_item("viper_fang"), 1)
	var bought := []
	var on_buy := func(_actor: Node, item: ItemData, price: int) -> void: bought.append([item.id, price])
	EventBus.item_purchased.connect(on_buy)
	p.gold = 0
	check(stock.buy(p, 0) == "YETERLİ ALTIN YOK" and p.gold == 0 and not stock.offers[0].sold and inv.owned_count("watcher_band") == 0, "altın yetmezse reddedilir, hiçbir şey değişmez")
	check(stock.buy(p, 9) == "YOK" and stock.buy(p, -1) == "YOK", "olmayan teklif: YOK")
	p.add_gold(500)
	var price0 := stock.offers[0].price
	check(stock.buy(p, 0) == "", "satın alındı")
	check(p.gold == 500 - price0, "altın tam fiyat kadar düştü (%d)" % p.gold)
	check(stock.offers[0].sold and inv.count("watcher_band") == 1, "eşya takıldı (slot boştu), teklif satıldı")
	check(stock.buy(p, 0) == "SATILDI" and p.gold == 500 - price0, "satılan ikinci kez alınamaz, altın düşmez")
	var price1 := stock.offers[1].price
	check(stock.buy(p, 1) == "" and inv.bag_count("tower_bread") == 1 and p.gold == 500 - price0 - price1, "yemek çantaya gitti")
	check(bought.size() == 2 and bought[0][0] == "watcher_band" and bought[0][1] == price0, "item_purchased olayı yayıldı")
	EventBus.item_purchased.disconnect(on_buy)
	check(stock.unsold_count() == 1, "rafta bir eşya kaldı")
	# Çanta dolu: yemek (çantada olmayan) alınamaz, altın düşmez
	for e in ItemDB.equipment():
		if inv.bag.size() >= Inventory.BAG_SIZE:
			break
		if e.id != "viper_fang" and inv.owned_count(e.id) == 0:
			inv.give(e)
	var full := ShopStock.new()
	full._add(_item("sweet_potato") if ItemDB.get_item("sweet_potato") != null else _item("tower_bread"), 1)
	var gold_before := p.gold
	if inv.bag_count(full.offers[0].item.id) == 0:
		check(full.buy(p, 0) == "ÇANTA DOLU" and p.gold == gold_before and not full.offers[0].sold, "çanta doluysa reddedilir, altın düşmez")
	# Ölü oyuncu
	var dead := ShopStock.new()
	dead._add(_item("viper_fang"), 1)
	p.dead = true
	check(dead.buy(p, 0) == "ÖLÜSÜN", "ölü oyuncu alışveriş yapamaz")
	p.dead = false
	# Kayıt
	var data := stock.to_array()
	var back := ShopStock.from_array(data)
	check(back.size() == stock.size() and back.offers[0].sold and not back.offers[2].sold and back.offers[0].price == stock.offers[0].price and back.offers[2].item.id == "viper_fang", "raf kayda yazılıp geri okunuyor (satıldı bayrağı dahil)")
	data.append({"id": "yok_boyle_esya", "price": 5, "sold": false})
	check(ShopStock.from_array(data).size() == stock.size(), "tanınmayan eşya kimliği atlanıyor")
	check(ShopStock.from_array("bozuk").size() == 0 and ShopStock.from_array(null).size() == 0, "bozuk veri boş raf verir")


func _test_shop_menu() -> void:
	await _new_world("Dükkân menüsü (tezgâhta E): duraklatma, gezinme, satın alma, reddetme, kapatma, fare")
	GameState.god_mode = false
	TimeStop.reset()
	ItemView.active_menu = null
	var run := _start_run(81)
	await _frames(5)
	var p := run.player
	var menu := run.hud.shop_menu
	check(menu != null and not menu.is_open and not menu.visible and not get_tree().paused, "menü HUD'da var, kapalı")
	var stock := ShopStock.new()
	for id in ["watcher_band", "viper_fang", "tower_bread"]:
		stock._add(_item(id), 1)
	check(menu.open_shop(p, stock) and menu.is_open and get_tree().paused and ItemView.active_menu == menu, "açıldı: oyun durdu, menü aktif")
	check(menu.cell_count() == 3, "üç kutu")
	var inside := true
	for i in menu.cell_count():
		if not ShopMenu.PANEL.encloses(menu.cell_rect(i)) or menu.cell_rect(i).intersects(ShopMenu.DETAIL):
			inside = false
	check(inside, "kutular panelin içinde, ayrıntı paneline taşmıyor")
	check(not menu.cell_rect(0).intersects(menu.cell_rect(1)) and menu.cell_rect(2).position.y > menu.cell_rect(0).position.y, "eşyalar üst satırda, yemek alt satırda")
	check(menu.cursor_index() == 0 and menu.cursor_offer().item.id == "watcher_band", "imleç ilk teklifte")
	menu._unhandled_input(_ui_key(KEY_RIGHT))
	check(menu.cursor_index() == 1, "sağ: yandaki eşya")
	menu._unhandled_input(_ui_key(KEY_DOWN))
	check(menu.cursor_index() == 2, "aşağı: yemek satırı")
	menu._unhandled_input(_ui_key(KEY_UP))
	check(menu.cursor_index() in [0, 1], "yukarı: eşya satırına döndü")
	menu.focus(0)
	# Altın yok: reddedilir
	p.gold = 0
	menu._unhandled_input(_ui_key(KEY_ENTER))
	check(not stock.offers[0].sold and menu._msg == "YETERLİ ALTIN YOK" and not menu._msg_good and p.gold == 0, "altın yoksa Enter reddeder: " + menu._msg)
	# Altın var: Enter satın alır
	p.add_gold(300)
	var g0 := p.gold
	menu._unhandled_input(_ui_key(KEY_ENTER))
	check(stock.offers[0].sold and p.gold == g0 - stock.offers[0].price and p.inventory.count("watcher_band") == 1, "Enter satın aldı ve taktı")
	check(menu._msg == "SATIN ALINDI  " + _item("watcher_band").upper_name() and menu._msg_good, "mesaj: " + menu._msg)
	menu._unhandled_input(_ui_key(KEY_ENTER))
	check(menu._msg == "SATILDI" and p.gold == g0 - stock.offers[0].price, "satılana tekrar basınca SATILDI, altın düşmez")
	# E tuşu ve J de satın alır
	menu.focus(1)
	var g1 := p.gold
	menu._unhandled_input(_ui_key(KEY_E))
	check(stock.offers[1].sold and p.gold == g1 - stock.offers[1].price, "E tuşu da satın alır")
	# Fare: ilk tık seçer, seçiliye ikinci tık satın alır
	menu.focus(0)
	var pos := menu.cell_rect(2).get_center()
	var g2 := p.gold
	menu._gui_input(_mouse_click(pos))
	check(menu.cursor_index() == 2 and not stock.offers[2].sold and p.gold == g2, "fare: ilk tık yalnız seçer")
	menu._gui_input(_mouse_click(pos))
	check(stock.offers[2].sold and p.inventory.bag_count("tower_bread") == 1, "fare: seçiliye ikinci tık satın alır")
	# Açıkken oyun tuşları alta geçmez; Esc kapatır
	menu._unhandled_input(_ui_key(KEY_ESCAPE))
	check(not menu.is_open and not get_tree().paused and ItemView.active_menu == null, "Esc kapattı, oyun akıyor")
	check(not menu.open_shop(p, null), "raf yoksa açılmaz")
	p.dead = true
	check(not menu.open_shop(p, stock) and not menu.is_open, "ölüyken açılmaz")
	p.dead = false
	run.queue_free()
	await _frames(2)


func _test_floor_exit() -> void:
	await _new_world("Kat geçidi: kapalıyken kullanılmaz, açılma süresi, E ve yürüyerek geçiş, bir kez kullanılır")
	var p := _spawn_player(300.0)
	var ex := FloorExit.new()
	ex.position = Vector2(300.0, RoomLayouts.FLOOR_Y)
	ex.next_floor = 2
	_world.add_child(ex)
	var used := [0]
	ex.used.connect(func(_e: FloorExit) -> void: used[0] += 1)
	p.global_position = Vector2(300.0, 612.0)
	await _frames(3)
	check(ex.state == FloorExit.State.CLOSED and ex.in_range and not ex.is_open(), "kapalı, oyuncu yakında")
	check(not ex.try_use() and used[0] == 0, "kapalıyken kullanılamaz")
	p.interacted.emit()
	await _frames(15)
	check(used[0] == 0, "kapalıyken E de işe yaramaz; yürüyerek içine girmek de")
	ex.open_up()
	check(ex.state == FloorExit.State.OPENING and not ex.is_open(), "açılıyor (henüz kullanılamaz)")
	check(not ex.try_use(), "açılırken kullanılamaz")
	await _frames(int(FloorExit.OPEN_TIME * 60.0) + 12)
	check(ex.state == FloorExit.State.OPEN and ex.is_open(), "açıldı")
	# Oyuncu içine yürüdü (WALK_IN_X içinde): HOLD_TIME sonra geçilir
	await _wait_until(func() -> bool: return used[0] > 0, 60)
	check(used[0] == 1, "açık geçidin içinde durunca geçildi")
	await _frames(30)
	check(used[0] == 1 and not ex.try_use(), "bir geçit yalnız bir kez kullanılır")
	# Yakında ama içinde değil: yalnız E geçirir
	var ex2 := FloorExit.new()
	ex2.position = Vector2(900.0, RoomLayouts.FLOOR_Y)
	_world.add_child(ex2)
	var used2 := [0]
	ex2.used.connect(func(_e: FloorExit) -> void: used2[0] += 1)
	ex2.open_up()
	p.global_position = Vector2(900.0 - 70.0, 612.0)
	await _frames(int(FloorExit.OPEN_TIME * 60.0) + 25)
	check(ex2.is_open() and ex2.in_range and used2[0] == 0, "yakında ama içinde değil: kendiliğinden geçmez")
	p.interacted.emit()
	check(used2[0] == 1, "E ile geçildi")
	# Uzaktan E işe yaramaz
	var ex3 := FloorExit.new()
	ex3.position = Vector2(1500.0, RoomLayouts.FLOOR_Y)
	_world.add_child(ex3)
	var used3 := [0]
	ex3.used.connect(func(_e: FloorExit) -> void: used3[0] += 1)
	ex3.open_up()
	await _frames(int(FloorExit.OPEN_TIME * 60.0) + 5)
	p.interacted.emit()
	check(used3[0] == 0 and not ex3.in_range, "uzaktayken E geçirmez")


## Odadan odaya yürümeden: oyuncuyu bir sonraki odaya götürür ve girildiğini bekler.
func _walk_to_next_room(run: RunController) -> bool:
	var p := run.player
	var from := run.current
	var room := run.rooms[from] as Room
	p.global_position = Vector2(room.rect.end.x - 150.0, 612.0)
	p.facing = 1
	p.intent.move_x = 1.0
	var ok := await _wait_until(func() -> bool: return run.current == from + 1, 200)
	p.intent.move_x = 0.0
	return ok


func _test_floor_flow() -> void:
	await _new_world("Kat akışı: lobi (dükkân) -> 4 savaş odası -> Gölge odası -> kat geçidi -> kararma -> Kat 2")
	GameState.god_mode = false
	TimeStop.reset()
	ItemView.active_menu = null
	var run := _start_run(2024, true)
	var p := run.player
	await _frames(5)
	var lobby := run.rooms[0] as Room
	check(run.current == 0 and lobby.kind == FloorPlan.Kind.LOBBY and lobby.floor_no == 1, "koşu kat 1'in lobisinde başladı")
	check(lobby.waves.is_empty() and lobby.is_cleared() and lobby.alive_count() == 0, "lobide düşman yok, oda baştan temiz")
	check(not lobby.door.is_blocking(), "lobinin kapısı açık")
	check(lobby.rect.position.x == 0.0 and run.rooms.has(1) and (run.rooms[1] as Room).kind == FloorPlan.Kind.COMBAT, "kat x = 0'dan başlıyor, yanındaki oda savaş odası")
	check(lobby.shop != null and lobby.shop.stock != null and lobby.shop.stock.size() == ShopStock.GEAR_OFFERS + ShopStock.FOOD_OFFERS, "tezgâh kurulu, rafta %d teklif" % lobby.shop.stock.size())
	check(run.hud.overlay.floor_number == 1 and run.hud.overlay.room_kind == FloorPlan.Kind.LOBBY and run.hud.overlay.room_number == 1, "HUD: KAT 1, LOBİ")
	check(int(run.stats["rooms_cleared"]) == 0 and int(run.stats["floor"]) == 1 and int(run.stats["room"]) == 1, "lobi temizlenen oda sayılmaz (%s)" % str(run.stats))
	check(run.camera.bounds.end.x >= (run.rooms[1] as Room).camera_rect().end.x - 0.5, "kamera lobiden yan odaya uzanabiliyor")
	# Tezgâh
	p.global_position = Vector2(lobby.rect.position.x + RoomLayouts.shop_x(RoomLayouts.LOBBY_ID), 612.0)
	await _frames(3)
	check(lobby.shop.in_range, "tezgâhın yanında")
	p.interacted.emit()
	check(run.hud.shop_menu.is_open and get_tree().paused, "E: dükkân menüsü açıldı")
	p.add_gold(500)
	run.hud.shop_menu._unhandled_input(_ui_key(KEY_ENTER))
	check(lobby.shop.stock.unsold_count() == lobby.shop.stock.size() - 1, "menüden bir şey alındı")
	run.hud.shop_menu._unhandled_input(_ui_key(KEY_ESCAPE))
	check(not run.hud.shop_menu.is_open and not get_tree().paused, "kapandı")
	p.global_position = Vector2(60.0, 612.0)
	await _frames(3)
	p.interacted.emit()
	check(not run.hud.shop_menu.is_open, "tezgâhtan uzakta E menü açmaz")
	# Lobiden sağa geç
	check(await _walk_to_next_room(run), "lobiden sağa geçince 1. odaya girildi")
	await _frames(20)
	var r1 := run.rooms[1] as Room
	check(r1.state == Room.State.ACTIVE and run.hud.overlay.room_number == 2 and run.hud.overlay.room_kind == FloorPlan.Kind.COMBAT and run.hud.overlay.floor_number == 1, "savaş odası aktif; HUD KAT 1 ODA 2")
	check(lobby.door.is_blocking() and not lobby.shop.in_range, "lobinin kapısı arkadan kapandı (dükkân geride kaldı)")
	# 2-5. odalar: sırayla temizle ve geç
	for slot in [1, 2, 3, 4]:
		var room := run.current_room()
		check(room.kind == FloorPlan.Kind.COMBAT and room.slot == slot, "oda %d savaş odası" % (slot + 1))
		await _wait_until(func() -> bool: return room.alive_count() > 0 or room.pending_count() > 0, 300)
		run.skip_room()
		await _frames(4)
		check(room.is_cleared() and int(run.stats["rooms_cleared"]) == slot, "oda %d temizlendi (temizlenen: %d)" % [slot + 1, int(run.stats["rooms_cleared"])])
		check(await _walk_to_next_room(run), "oda %d'den sonrakine geçildi" % (slot + 1))
		await _frames(10)
	# Gölge odası
	var boss_room := run.current_room()
	check(boss_room.kind == FloorPlan.Kind.BOSS and boss_room.slot == 5 and run.current == 5, "6. oda: Gölge odası")
	check(run.hud.overlay.room_kind == FloorPlan.Kind.BOSS and run.hud.overlay.room_number == 6, "HUD: GÖLGE")
	check(boss_room.floor_exit != null and boss_room.floor_exit.state == FloorExit.State.CLOSED and boss_room.floor_exit.next_floor == 2, "kat geçidi kapalı, KAT 2'ye gidiyor")
	check(not run.has_next_room(5) and not run.rooms.has(6), "Gölge odasının sağında oda yok")
	check(boss_room.door.permanent, "sağ kapı hiç açılmaz (yerine geçit var)")
	var spawned := await _wait_until(func() -> bool: return boss_room.alive_count() >= 1, 360)
	check(spawned and boss_room.alive_count() == 1, "patron doğdu (tek düşman)")
	var boss: ActorBase = null
	for e in get_tree().get_nodes_in_group("enemies"):
		boss = e as ActorBase
	check(boss != null and boss.has_meta("floor") and int(boss.get_meta("floor")) == 1, "patron katını biliyor (meta floor = 1)")
	check(boss_room.floor_exit.state == FloorExit.State.CLOSED, "patron yaşarken geçit kapalı")
	run.skip_room()
	await _frames(int(FloorExit.OPEN_TIME * 60.0) + 12)
	check(boss_room.is_cleared() and int(run.stats["rooms_cleared"]) == 5, "Gölge yenildi, 5 oda temizlendi")
	check(boss_room.floor_exit.is_open(), "kat geçidi açıldı")
	# Gerçek yol: açık geçidin içine yürü
	p.global_position = boss_room.floor_exit.global_position + Vector2(0.0, -12.0)
	var started := await _wait_until(func() -> bool: return run.is_transitioning(), 60)
	check(started, "geçidin içine yürüyünce geçiş başladı")
	check(not run.descend(), "geçiş sürerken ikinci geçiş başlamaz")
	check(not run.dev_next_floor() and run.current_floor() == 1, "geçiş sürerken F7 kısayolu karışmıyor")
	check(p.input_locked, "kararırken oyuncu girişi kilitli")
	var dark := await _wait_until(func() -> bool: return run.hud.overlay.fade >= 0.99, 120)
	check(dark, "ekran karardı")
	var swapped := await _wait_until(func() -> bool: return run.current_floor() == 2, 120)
	check(swapped and run.current == 6, "yeni kata geçildi: kat 2, oda 6 (lobi)")
	var lobby2 := run.rooms[6] as Room
	check(lobby2.kind == FloorPlan.Kind.LOBBY and lobby2.floor_no == 2 and lobby2.rect.position.x == 0.0, "kat 2'nin lobisi x = 0'da")
	await _frames(3)
	check(not is_instance_valid(boss_room) or boss_room.is_queued_for_deletion(), "eski katın odaları silindi")
	check(run.rooms.size() == 2 and run.rooms.has(6) and run.rooms.has(7), "yalnız yeni katın ilk iki odası kurulu")
	check(is_equal_approx(p.global_position.x, lobby2.rect.position.x + RunController.START_OFFSET), "oyuncu yeni lobinin başında (x=%.0f)" % p.global_position.x)
	check(run.hud.overlay.card_title == "KAT 2" and run.hud.overlay.card_k > 0.0, "karanlıkta 'KAT 2' kartı")
	check(lobby2.shop != null and lobby2.shop.stock != null and lobby2.shop.stock.size() > 0, "yeni lobide yeni raf")
	check(run.hud.overlay.floor_number == 2 and run.hud.overlay.room_kind == FloorPlan.Kind.LOBBY, "HUD: KAT 2, LOBİ")
	var done := await _wait_until(func() -> bool: return not run.is_transitioning(), 400)
	check(done and run.hud.overlay.fade == 0.0 and run.hud.overlay.card_k == 0.0 and not p.input_locked, "ekran açıldı, giriş serbest")
	check(not run.descend(), "lobide (geçit yokken) geçiş başlatılamaz")
	check(int(run.stats["floor"]) == 2 and int(run.stats["room"]) == 1, "istatistik: kat 2, oda 1")
	# F7: kısayol
	check(run.dev_next_floor() and run.current_floor() == 3 and run.current == 12, "F7: kat 3'ün lobisine ışınlandı")
	run.queue_free()
	await _frames(2)


## Kayıttan (JSON) geri yüklenmiş bir koşu kurar: `data` GameState'in bekleyen devam koşusu olur.
func _resume_run(data: Dictionary, floors: bool = true) -> RunController:
	GameState.resume_run = data
	var run := RUN.instantiate() as RunController
	run.floors_enabled = floors
	run.seed_value = 999  # kayıttaki tohum kazanmalı
	var p := run.get_node("Player") as Player
	p.scripted = true
	_world.add_child(run)
	(run.get_node("Camera") as ShakeCamera).set_process(false)
	return run


func _test_floor_save() -> void:
	await _new_world("Kayıt (katlı yapı): lobide raf kaydı, devam, katın ortasından devam, eski kaydın taşınması")
	GameState.god_mode = false
	TimeStop.reset()
	ItemView.active_menu = null
	_clean_saves()
	var slot := SaveSlot.create(0, "Kat", Difficulty.Level.NORMAL)
	SaveStore.save_slot(slot)
	GameState.begin_session(slot, GameMode.Kind.NORMAL)
	var run := _start_run(4242, true)
	await _frames(5)
	var p := run.player
	var data := slot.run_of(GameMode.Kind.NORMAL)
	check(int(data.get("v", 0)) == 2 and int(data.get("floor", 0)) == 1 and int(data.get("room", -1)) == 0, "kayıt: sürüm 2, kat 1, oda 0 (lobi)")
	check(data.get("shop") is Array and (data["shop"] as Array).size() == ShopStock.GEAR_OFFERS + ShopStock.FOOD_OFFERS, "lobide raf kayda yazıldı")
	check(slot.progress_text(GameMode.Kind.NORMAL) == "KAT 1  ODA 1", "kaldığımız yer: " + slot.progress_text(GameMode.Kind.NORMAL))
	# Bir şey satın al ve kaydet
	p.add_gold(500)
	var stock := run.shop_stock
	check(stock != null and stock.buy(p, 0) == "", "bir şey satın alındı")
	var ids: Array = []
	for o in stock.offers:
		ids.append(o.item.id)
	var gold_then := p.gold
	check(run.save_checkpoint(), "kayıt yazıldı")
	run.queue_free()
	await _frames(3)
	# Devam: aynı raf, satılan satılmış, altın aynı
	var slot2 := SaveStore.load_slot(0)
	GameState.begin_session(slot2, GameMode.Kind.NORMAL)
	var base := slot2.run_of(GameMode.Kind.NORMAL).duplicate(true)
	var run2 := _resume_run(slot2.run_of(GameMode.Kind.NORMAL))
	await _frames(5)
	var p2 := run2.player
	check(GameState.resume_run.is_empty() and run2.run_seed == 4242 and run2.current == 0, "devam: kayıttaki tohum, kat 1 lobisi")
	var lobby := run2.rooms[0] as Room
	var got: Array = []
	var sold: Array = []
	for o in lobby.shop.stock.offers:
		got.append(o.item.id)
		sold.append(o.sold)
	check(got == ids, "aynı raf geri geldi")
	check(sold[0] and not sold[1] and not sold[2], "satılan eşya satılmış kaldı (%s)" % str(sold))
	check(p2.gold == gold_then and p2.inventory.owned_count(ids[0]) == 1, "altın ve satın alınan eşya geri geldi (%d)" % p2.gold)
	# Yeniden girince yeni raf üretilmez: aynı lobiye tekrar kurulum raf değiştirmez
	check(run2.shop_stock == lobby.shop.stock, "koşu denetleyicisi aynı rafı tutuyor")
	run2.queue_free()
	await _frames(3)
	# --- Katın ortasından devam: kat 4, 4. oda (sıra 3)
	var mid := base.duplicate(true)
	mid["floor"] = 4
	mid["room"] = 3
	mid.erase("shop")
	var run3 := _resume_run(mid)
	await _frames(5)
	var idx := FloorPlan.index_of(4, 3)
	check(run3.current == idx and run3.current_floor() == 4, "devam: kat 4, 4. oda (oda no %d)" % run3.current)
	check(run3.rooms.has(idx - 1) and run3.rooms.has(idx) and run3.rooms.has(idx + 1) and not run3.rooms.has(idx - 2), "önceki (sol sınır), mevcut ve sonraki oda kurulu")
	var rr := run3.rooms[idx] as Room
	check(rr.kind == FloorPlan.Kind.COMBAT and rr.slot == 3 and rr.floor_no == 4, "savaş odası, kat 4")
	check(rr.rect.position.x > 0.0 and is_equal_approx(rr.rect.position.x, run3.x_left_of(idx)), "oda katın içinde doğru x'te (%.0f)" % rr.rect.position.x)
	check(rr.rect.has_point(p3_pos(run3)) and run3.player.global_position.x < rr.rect.position.x + 400.0, "oyuncu odanın başında")
	check(rr.tuning.progress == 14, "düşman ayarı: tur 14 (kat 4 üçüncü savaş odası): %d" % rr.tuning.progress)
	check(run3.hud.overlay.floor_number == 4 and run3.hud.overlay.room_number == 4, "HUD: KAT 4 ODA 4")
	check(run3.shop_stock == null and rr.shop == null, "lobi dışında raf yok")
	var again := run3.snapshot()
	check(int(again["floor"]) == 4 and int(again["room"]) == 3 and not again.has("shop"), "kayıt aynı yeri gösteriyor, raf yok")
	# Ölünce en iyi konum: KAT 4  ODA 4
	run3.player.health = 1
	run3.player.take_damage(99, null)
	await _frames(3)
	var after := SaveStore.load_slot(0)
	check(int(after.records["best_floor"]) == 4 and int(after.records["best_room"]) == 4 and after.best_text(GameMode.Kind.NORMAL) == "EN İYİ KAT 4  ODA 4", "en iyi konum: " + after.best_text(GameMode.Kind.NORMAL))
	check(int(run3.hud.overlay.summary.get("floor", 0)) == 4 and int(run3.hud.overlay.summary.get("room", 0)) == 4, "ölüm özeti: KAT 4 ODA 4")
	run3.queue_free()
	await _frames(3)
	# --- Eski (tek şeritli) kayıt: aynı ilerleme için uygun katın lobisine taşınır
	var legacy := base.duplicate(true)
	legacy.erase("v")
	legacy.erase("shop")
	legacy["floor"] = 1
	legacy["room"] = 17
	var run4 := _resume_run(legacy)
	await _frames(5)
	check(run4.current == FloorPlan.index_of(5, 0) and run4.current_room().kind == FloorPlan.Kind.LOBBY, "eski kayıt (oda 18) -> kat 5'in lobisi")
	check(run4.player.gold == gold_then, "eski kayıttaki altın korundu")
	check(run4.shop_stock != null and run4.shop_stock.size() > 0, "taşınan lobide yeni raf var")
	run4.queue_free()
	await _frames(3)
	var legacy2 := legacy.duplicate(true)
	legacy2["v"] = 1
	legacy2["room"] = 3
	var run5 := _resume_run(legacy2)
	await _frames(5)
	check(run5.current == 0, "eski kayıt (oda 4) -> kat 1'in lobisi")
	run5.queue_free()
	await _frames(3)
	# Katsız (eski) kip sürümsüz yazar ve kayıttaki oda no'yu doğrudan kullanır
	var run6 := _start_run(7, false)
	await _frames(3)
	check(int(run6.snapshot()["v"]) == 1, "katsız kip: kayıt sürümü 1")
	run6.queue_free()
	await _frames(3)
	_end_saves()


func p3_pos(run: RunController) -> Vector2:
	return run.player.global_position


func _test_final_floor() -> void:
	await _new_world("Son kat: Gölge yenilince zafer (geçit yok), zafer ekranı, rekor ve kayıt")
	GameState.god_mode = false
	TimeStop.reset()
	ItemView.active_menu = null
	_clean_saves()
	var slot := SaveSlot.create(0, "Zafer", Difficulty.Level.NORMAL)
	GameState.begin_session(slot, GameMode.Kind.NORMAL)
	var run := _start_run(555, true)
	var p := run.player
	await _frames(5)
	# 18. katın lobisine ışınla
	run.current = FloorPlan.index_of(17, 5)
	check(run.dev_next_floor() and run.current_floor() == 18 and run.current == FloorPlan.index_of(18, 0), "kat 18'e geçildi")
	check(not run.dev_next_floor() and not run.descend(), "son katın ötesi yok")
	var wins := []
	run.run_won.connect(func() -> void: wins.append(true))
	# Gölge odasına git
	for k in 5:
		await _frames(3)
		if k > 0:
			var room := run.current_room()
			await _wait_until(func() -> bool: return room.alive_count() > 0 or room.pending_count() > 0, 300)
			run.skip_room()
			await _frames(3)
		check(await _walk_to_next_room(run), "kat 18: %d. odadan geçildi" % (k + 1))
	var boss_room := run.current_room()
	check(boss_room.kind == FloorPlan.Kind.BOSS and FloorPlan.is_final_floor(boss_room.floor_no), "kat 18'in Gölge odası")
	check(boss_room.floor_exit == null and boss_room.door.permanent, "son katta geçit yok, kapı mühürlü")
	await _wait_until(func() -> bool: return boss_room.alive_count() > 0, 360)
	var kills_before := int(run.stats["kills"])
	run.skip_room()
	await _frames(5)
	check(run.won and wins.size() == 1, "son Gölge yenildi: zafer (run_won bir kez)")
	check(not run.victory_shown, "zafer ekranı hemen değil, kısa bir gecikmeyle")
	check(int(slot.records["wins"]) == 1 and int(slot.records["runs"]) == 1 and int(slot.records["deaths"]) == 0, "rekorlar: 1 zafer, 1 koşu, 0 ölüm (%s)" % str(slot.records))
	check(int(slot.records["best_floor"]) == 18 and int(slot.records["best_room"]) == 6, "en iyi: KAT 18 ODA 6")
	check(slot.run_of(GameMode.Kind.NORMAL).is_empty(), "yarım koşu silindi")
	var shown := await _wait_until(func() -> bool: return run.victory_shown, int(RunController.VICTORY_DELAY * 60.0) + 60)
	check(shown and run.hud.overlay.victory and p.input_locked, "zafer ekranı açıldı, oyuncu kilitli")
	check(int(run.hud.overlay.summary.get("floor", 0)) == 18 and int(run.hud.overlay.summary.get("kills", 0)) >= kills_before, "özet 18. katı gösteriyor")
	await _frames(30)
	check(int(slot.records["wins"]) == 1, "zafer iki kez sayılmadı")
	# R ile yeniden başlamak (terk) zaferi bozmaz: koşu zaten bitmişti, tekrar sayılmaz
	run._finish_run(false)
	run._finish_run(true)
	check(int(slot.records["runs"]) == 1 and int(slot.records["deaths"]) == 0, "zaferden sonra terk/ölüm: koşu tekrar sayılmadı")
	GameState.end_session()
	_end_saves()
	await _frames(3)


## Sahneyi değiştiren bir tuş menüyü ağaçtan çıkarır; tuş ONDAN ÖNCE "işlendi" işaretlenmiş olmalı
## (eskiden sonradan `get_viewport()` null dönüp "null değerde set_input_as_handled" hatası veriyordu).
func _test_menu_scene_change_input() -> void:
	await _new_world("Menü: sahne değiştiren tuş, menü ağaçtan çıksa bile hatasız işlenir")
	var went := [""]
	var m := _new_menu()
	var vp := m.get_viewport()
	SceneRouter.hook = func(path: String) -> void:
		went[0] = path
		if m.get_parent() != null:
			m.get_parent().remove_child(m)  # gerçek sahne değişimi gibi: menü ağaçtan çıkar
	m._unhandled_input(_menu_key(KEY_F8))
	check(went[0] == SceneRouter.RUN and not m.is_inside_tree(), "F8 hızlı koşuyu başlattı, menü ağaçtan çıktı")
	check(vp.is_input_handled(), "başlatan tuş 'işlendi' diye işaretlendi")
	m.queue_free()
	GameState.end_session()
	# Duraklatma menüsünden ANA MENÜ: aynı kalıp
	went[0] = ""
	vp.push_input(_menu_key(KEY_F23))  # kimsenin işlemediği bir tuş: "işlendi" bayrağını sıfırlar
	check(not vp.is_input_handled(), "bayrak sıfırlandı (ikinci sınama anlamlı olsun)")
	var slot := SaveSlot.create(0, "Deneme", Difficulty.Level.NORMAL)
	GameState.begin_session(slot, GameMode.Kind.NORMAL)
	var run := _start_run(11)
	await _frames(5)
	var pm := run.hud.pause_menu
	var vp2 := pm.get_viewport()
	SceneRouter.hook = func(path: String) -> void:
		went[0] = path
		if run.get_parent() != null:
			run.get_parent().remove_child(run)
	pm.open(run.player)
	pm.list.focus("menu")
	pm._unhandled_input(_menu_key(KEY_ENTER))
	check(went[0] == SceneRouter.MENU and not pm.is_inside_tree(), "duraklatma menüsünden ANA MENÜ: sahne değişti, menü ağaçtan çıktı")
	check(vp2.is_input_handled(), "tuş yine 'işlendi' işaretli")
	run.queue_free()
	await _frames(3)
	SceneRouter.hook = Callable()
	_end_saves()


func _test_menu_scene() -> void:
	await _new_world("Menü: ana sahne ve oturum temizliği")
	check(str(ProjectSettings.get_setting("application/run/main_scene")) == SceneRouter.MENU, "oyun ana menüyle açılır (main_scene)")
	check(ResourceLoader.exists(SceneRouter.MENU) and ResourceLoader.exists(SceneRouter.RUN), "menü ve koşu sahneleri var")
	GameState.begin_session(SaveSlot.create(0, "X", Difficulty.Level.HARD), GameMode.Kind.NORMAL)
	GameState.resume_run = {"seed": 1}
	get_tree().paused = true
	var m := _new_menu()
	check(GameState.slot == null and GameState.resume_run.is_empty() and not get_tree().paused, "menü açılınca eski oturum kapanır, duraklama kalkar")
	check(m.stack.size() == 1 and m.top() is TitleScreen, "başlık ekranı açıldı")
	check(not m.start_game(null, GameMode.Kind.NORMAL, false), "slotsuz başlatılamaz")
	var went := [""]
	SceneRouter.hook = func(path: String) -> void: went[0] = path
	GameState.begin_session(SaveSlot.create(0, "T", Difficulty.Level.IMMORTAL), GameMode.Kind.NORMAL)
	m.quick_run()
	check(went[0] == SceneRouter.RUN and GameState.slot == null, "hızlı koşu kayıtsız oturum açar")
	check(SceneRouter.scene_for(GameMode.Kind.NORMAL) == SceneRouter.RUN and SceneRouter.scene_for(GameMode.Kind.ENDLESS) == SceneRouter.ENDLESS, "kip -> sahne eşlemesi")
	went[0] = ""
	GameState.begin_session(SaveSlot.create(0, "T", Difficulty.Level.HARD), GameMode.Kind.NORMAL)
	get_tree().paused = true
	SceneRouter.go_menu(get_tree())
	check(went[0] == SceneRouter.MENU and GameState.slot == null and not get_tree().paused, "go_menu: oturum kapanır, duraklama kalkar")
	SceneRouter.hook = Callable()
	_end_saves()


# ------------------------------------------------------------------ öğretici (kat 1)

## `cond` doğru olana kadar en fazla `seconds` GERÇEK saniye bekler (gerçek zamanla akan arayüz animasyonları için).
func _wait_until_real(cond: Callable, seconds: float) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await get_tree().physics_frame
	return cond.call()


## İpucu panelindeki tuş ikonlarının etiketleri (satırlar sırasıyla, soldan sağa).
func _hint_keys(hint: TutorialHint) -> Array:
	var keys: Array = []
	for row: Dictionary in hint.rows:
		for part: Dictionary in row["parts"]:
			if part.has("k"):
				keys.append(String(part["k"]))
	return keys


## İpucu panelindeki bütün yazılar (başlık dahil) tek dizgede.
func _hint_text(hint: TutorialHint) -> String:
	var s := hint.title
	for row: Dictionary in hint.rows:
		for part: Dictionary in row["parts"]:
			if part.has("t"):
				s += " " + String(part["t"])
	return s


func _test_tutorial_curriculum() -> void:
	await _new_world("Öğretici müfredatı: kat 1'de düşmanlar tek tek, yavaş, önce yalnız altın")
	GameState.god_mode = false
	TimeStop.reset()
	ItemView.active_menu = null
	check(Tutorial.applies({"floor": 1, "kind": FloorPlan.Kind.COMBAT}), "kat 1'in savaş odaları müfredatı kullanır")
	check(not Tutorial.applies({"floor": 2, "kind": FloorPlan.Kind.COMBAT}), "kat 2'nin savaş odaları normal")
	check(not Tutorial.applies({"floor": 1, "kind": FloorPlan.Kind.LOBBY}) and not Tutorial.applies({"floor": 1, "kind": FloorPlan.Kind.BOSS}), "lobi ve Gölge odası müfredatsız")
	check(Tutorial.lessons(0).is_empty() and Tutorial.lessons(5).is_empty(), "savaş odası olmayan sıralarda ders yok")
	var single := true
	var scorpius := false
	var total := 0
	for slot in [1, 2, 3, 4]:
		for l: Dictionary in Tutorial.lessons(slot):
			var en: Array = l["enemies"]
			total += en.size()
			if slot < 4 and en.size() != 1:
				single = false
			if en.has(SCORPIUS):
				scorpius = true
	check(single, "2-4. odalar: her dalgada tek düşman (tek tek gelir)")
	check(not scorpius, "kat 1'de Scorpius yok (kat 2'de başlar)")
	var last := Tutorial.lessons(4)
	check((last[0]["enemies"] as Array).size() == 2 and (last[last.size() - 1]["enemies"] as Array).size() == 2, "ilk ikili dalga yalnız 5. odada")
	check(total >= 10 and total <= 16, "kat 1'de toplam %d düşman" % total)
	# Ayarlar
	var base := EnemyScaling.tuning(Difficulty.Level.NORMAL, 0)
	var speed0 := base.speed
	var tel0 := base.telegraph
	var ts := Tutorial.wave_tunings(1, base)
	var t0 := ts[0] as EnemyTuning
	check(ts.size() == 2 and t0.gold_only and not t0.red_only, "oda 2: yalnız altın saldırı (parry dersi)")
	check(t0.speed < base.speed and t0.telegraph > base.telegraph and t0.cooldown > base.cooldown and t0.recover > base.recover and t0.stun > base.stun, "oda 2: yavaş tempo (hız düşük; uyarı, bekleme, açık kalma uzun)")
	check(is_equal_approx(base.speed, speed0) and is_equal_approx(base.telegraph, tel0) and not base.gold_only and not base.red_only, "odanın kendi ayarı değişmedi (kopya üstünde çalışıldı)")
	check(not t0.is_identity() and base.copy() != base and is_equal_approx(base.copy().hp, base.hp), "ayar kopyası bağımsız")
	var t3 := Tutorial.wave_tunings(2, base)
	check(t3.size() == 3 and (t3[0] as EnemyTuning).gold_only and (t3[1] as EnemyTuning).red_only and not (t3[2] as EnemyTuning).gold_only and not (t3[2] as EnemyTuning).red_only, "oda 3: altın mermi -> kırmızı (dash) -> karışık")
	var t5 := Tutorial.wave_tunings(4, base)
	check(is_equal_approx((t5[t5.size() - 1] as EnemyTuning).speed, base.speed) and is_equal_approx((t5[t5.size() - 1] as EnemyTuning).telegraph, base.telegraph), "son ders normal tempoda")
	# Düşmanlar bayrakları uyguluyor
	var tg := TAURUS.instantiate() as Taurus
	tg.tuning = Tutorial.lesson_tuning(base, Tutorial.Style.GOLD, Tutorial.Pace.SLOW)
	var tr := TAURUS.instantiate() as Taurus
	tr.tuning = Tutorial.lesson_tuning(base, Tutorial.Style.RED, Tutorial.Pace.SLOW)
	var sg := SAGITTA.instantiate() as Sagitta
	sg.tuning = Tutorial.lesson_tuning(base, Tutorial.Style.GOLD, Tutorial.Pace.SLOW)
	var sr := SAGITTA.instantiate() as Sagitta
	sr.tuning = Tutorial.lesson_tuning(base, Tutorial.Style.RED, Tutorial.Pace.SLOW)
	for e: Node in [tg, tr, sg, sr]:
		_world.add_child(e)
	await _frames(2)
	check(is_equal_approx(tg.red_chance, 0.0) and is_equal_approx(tr.red_chance, 1.0), "Taurus: yalnız altın -> kırmızı şansı 0; yalnız kırmızı -> 1")
	check(sg.gold_every == 1 and sr.gold_every == 0, "Sagitta: yalnız altın -> her mermi altın; yalnız kırmızı -> hiçbiri altın")
	for e: Node in [tg, tr, sg, sr]:
		e.queue_free()
	check(GameFont._prep("DÜKKÂN TEZGÂH") == "DÜKKÂN TEZGÂH" and GameFont.get_font().has_char("Â".unicode_at(0)), "font: şapkalı A (DÜKKÂN) fontta var, olduğu gibi çizilir")
	# Gerçek koşu: kat 1'in 2. odası
	var run := _start_run(11, true)
	await _frames(5)
	var room := run.rooms[1] as Room
	check(room.waves.size() == 2 and (room.waves[0] as Array).size() == 1 and (room.waves[0] as Array)[0] == TAURUS, "oda 2: iki tek-Taurus dalgası")
	check(room.wave_tunings.size() == 2 and room.tuning_for_wave(0).gold_only and room.tuning_for_wave(1).gold_only, "oda 2: dalga ayarları kurulu")
	check(room.tuning_for_wave(7) == room.tuning and room.tuning_for_wave(-1) == room.tuning, "olmayan dalga odanın ayarını kullanır")
	check((run.rooms[0] as Room).wave_tunings.is_empty(), "lobide ders yok")
	var floor2 := run.make_waves(FloorPlan.index_of(2, 1))
	check(not floor2.is_empty() and (floor2[0] as Array).size() >= 2, "kat 2: normal dalgalar (ikili ve fazlası)")
	check(await _walk_to_next_room(run), "lobiden 2. odaya girildi")
	var p := run.player
	var max_alive := 0
	var kills := 0
	var tuned := true
	var guard := 0
	while not room.is_cleared() and guard < 2400:
		await get_tree().physics_frame
		guard += 1
		var alive := room.alive_count()
		max_alive = maxi(max_alive, alive)
		if alive >= 1:
			for e in get_tree().get_nodes_in_group("enemies"):
				var eb := e as EnemyBase
				if eb != null and not eb.dead and not (eb.tuning != null and eb.tuning.gold_only and eb is Taurus and is_equal_approx((eb as Taurus).red_chance, 0.0)):
					tuned = false
			kills += _kill_all_enemies(p)
	check(room.is_cleared() and kills == 2, "oda 2: iki düşman tek tek öldürüldü, oda temizlendi (öldürülen %d)" % kills)
	check(max_alive == 1, "aynı anda en fazla 1 düşman (%d)" % max_alive)
	check(tuned, "doğan Taurus'lar yalnız-altın ayarlı (kırmızı şansı 0)")
	run.queue_free()
	await _frames(3)


func _test_tutorial_hints() -> void:
	await _new_world("Öğretici ipuçları (lobi): hareket -> zıplama -> dash -> saldırı -> ilerle")
	GameState.god_mode = false
	TimeStop.reset()
	ItemView.active_menu = null
	GameState.end_session()
	var run := _start_run(31, true)
	await _frames(5)
	var p := run.player
	var g := run.tutorial
	var hint := run.hud.tutorial_hint
	check(g != null and hint != null and not g.finished_flag, "rehber ve ipucu paneli kuruldu (kayıtsız oturum)")
	check(g.active == Tutorial.STEP_MOVE and hint.is_showing() and hint.hint_id == "move" and hint.title == "HAREKET", "ilk ipucu: HAREKET")
	check(_hint_keys(hint) == ["A", "D"], "ipucu A ve D tuşlarını gösteriyor (%s)" % str(_hint_keys(hint)))
	check(hint.occupied_height() > 60.0 and hint.occupied_height() <= 140.0, "panel üstte, duyuru bandının üstünde kalıyor (%.0f px)" % hint.occupied_height())
	# Yürümeden hareket adımı tamamlanmaz
	await _frames(30)
	check(not g.done.has("move") and g.moved < 5.0, "yerinde dururken adım tamamlanmaz")
	# Hareket
	p.intent.move_x = 1.0
	var moved := await _wait_until(func() -> bool: return g.done.has("move"), 300)
	p.intent.move_x = 0.0
	check(moved and g.moved >= TutorialGuide.MOVE_DISTANCE, "yürüyünce HAREKET tamamlandı (%.0f px)" % g.moved)
	check(hint.is_done_flashing(), "tamamlanınca tik/yeşil geçiş")
	check(await _wait_until_real(func() -> bool: return g.active == Tutorial.STEP_JUMP, 5.0), "ardından ZIPLAMA ipucu")
	check(hint.title == "ZIPLAMA" and _hint_keys(hint) == ["W", "SPACE"], "ZIPLAMA: W ve SPACE (%s)" % str(_hint_keys(hint)))
	# Zıplama (gerçek zıplama)
	await get_tree().physics_frame
	p.intent.jump_pressed = true
	p.intent.jump_held = true
	await _frames(6)
	p.intent.jump_held = false
	check(g.done.has("jump"), "zıplayınca ZIPLAMA tamamlandı")
	await _frames(40)
	check(await _wait_until_real(func() -> bool: return g.active == Tutorial.STEP_DASH, 5.0), "ardından DASH ipucu")
	check(_hint_keys(hint) == ["SHIFT"], "DASH: SHIFT tuşu")
	await get_tree().physics_frame
	p.intent.move_x = 1.0
	p.intent.dash_pressed = true
	await _frames(3)
	p.intent.move_x = 0.0
	check(g.done.has("dash"), "dash yapınca DASH tamamlandı")
	await _frames(30)
	check(await _wait_until_real(func() -> bool: return g.active == Tutorial.STEP_ATTACK, 5.0), "ardından SALDIRI ipucu")
	check(_hint_keys(hint) == ["J"] and _hint_text(hint).contains("0/3"), "SALDIRI: J tuşu, sayaç 0/3")
	p.facing = 1
	p.intent.attack_pressed = true
	await _frames(25)
	check(g.attacks == 1 and _hint_text(hint).contains("1/3") and not g.done.has("attack"), "ilk vuruş: sayaç 1/3")
	p.intent.attack_pressed = true
	await _frames(25)
	p.intent.attack_pressed = true
	await _frames(25)
	check(g.attacks == 3 and g.done.has("attack"), "3 vuruşta SALDIRI tamamlandı")
	check(await _wait_until_real(func() -> bool: return g.active == Tutorial.STEP_GO, 5.0), "ardından İLERLE ipucu")
	check(_hint_keys(hint) == ["D"] and _hint_text(hint).contains("DÜKKÂN"), "İLERLE: D tuşu, tezgâh hatırlatması (%s)" % str(_hint_keys(hint)))
	check(not g.finished_flag and not g.done.has("parry"), "savaş dersleri bekliyor: öğretici henüz bitmedi")
	# Sağa geçince lobi ipuçları kapanır
	check(await _walk_to_next_room(run), "lobiden sağa geçildi")
	await _frames(5)
	check(g.active == "" and not hint.is_showing(), "savaş odasında (uyarı yokken) ipucu yok")
	run.queue_free()
	await _frames(3)
	# Sırası gelmeden yapılan beceri: ipucu hiç gösterilmez
	await _new_world("Öğretici: sırası gelmeden yapılan beceri atlanır")
	var run2 := _start_run(32, true)
	await _frames(5)
	var g2 := run2.tutorial
	run2.player.jumped.emit(false)
	check(g2.done.has("jump") and g2.active == "move" and not run2.hud.tutorial_hint.is_done_flashing(), "önce zıplayan oyuncuya ZIPLAMA gösterilmez, HAREKET sürer")
	g2._complete("move")
	check(await _wait_until_real(func() -> bool: return g2.active == Tutorial.STEP_DASH, 5.0), "HAREKET sonrası ZIPLAMA atlanıp DASH gelir")
	run2.queue_free()
	await _frames(3)


func _test_tutorial_combat() -> void:
	await _new_world("Öğretici ipuçları (savaş): altın -> PARRY, kaçırma, vur, kırmızı -> DASH")
	GameState.god_mode = false
	TimeStop.reset()
	ItemView.active_menu = null
	GameState.end_session()
	var run := _start_run(41, true)
	await _frames(5)
	var p := run.player
	var g := run.tutorial
	var hint := run.hud.tutorial_hint
	check(await _walk_to_next_room(run), "2. odaya girildi")
	await _wait_until(func() -> bool: return run.current_room().alive_count() > 0 or run.current_room().pending_count() > 0, 300)
	run.skip_room()
	await _frames(6)
	var room := run.current_room()
	check(room.kind == FloorPlan.Kind.COMBAT and room.is_cleared() and g.active == "", "savaş odası temiz; ipucu yok")
	# Kendi düşmanlarımız (yapay zekâsız): uyarıyı biz veririz
	var t := TAURUS.instantiate() as Taurus
	run.enemies_root.add_child(t)
	t.global_position = Vector2(room.rect.position.x + 900.0, 612.0)
	t.process_mode = Node.PROCESS_MODE_DISABLED
	var s := SAGITTA.instantiate() as Sagitta
	run.enemies_root.add_child(s)
	s.global_position = Vector2(room.rect.position.x + 1000.0, 612.0)
	s.process_mode = Node.PROCESS_MODE_DISABLED
	# 1) Altın uyarı -> PARRY
	t.set_tell(EnemyBase.Tell.GOLD)
	check(g.active == Tutorial.STEP_PARRY and hint.hint_id == "parry" and hint.title == "PARRY", "altın uyarı: PARRY ipucu")
	check(_hint_keys(hint) == ["K"] and _hint_text(hint).contains("ALTIN"), "K tuşu ve 'ALTIN İŞARET' yazısı")
	# Sagitta'nın altın mermisi
	s.set_tell(EnemyBase.Tell.GOLD)
	check(g.active == Tutorial.STEP_PARRY_SHOT and _hint_text(hint).contains("MERMİ"), "Sagitta altın uyarısı: 'ALTIN MERMİ' ipucu")
	# 2) Uyarı bitti, parry denendi ve kaçırıldı
	t.set_tell(EnemyBase.Tell.NONE)
	s.set_tell(EnemyBase.Tell.NONE)
	EventBus.parry_failed.emit(p)
	check(g.active == Tutorial.STEP_PARRY_MISS and _hint_text(hint).contains("KAÇIRDIN"), "kaçırınca 'KAÇIRDIN, tekrar dene'")
	# Altın uyarıdan çok sonra boşa K: ipucu çıkmaz
	g._miss_t = 0.0
	g._hold_t = 0.0
	g._since_gold = 9.0
	g._refresh()
	check(g.active == "", "uyarı yokken basılan K 'kaçırdın' göstermez")
	EventBus.parry_failed.emit(p)
	check(g.active == "" and g._miss_t == 0.0, "altın uyarıdan çok sonra gelen başarısız parry yok sayılır")
	# 3) Parry başarılı -> tik -> "VUR"
	t.set_tell(EnemyBase.Tell.GOLD)
	check(g.active == Tutorial.STEP_PARRY, "altın uyarı yine PARRY gösteriyor")
	EventBus.parry_success.emit(p, null)
	check(g.done.has("parry") and hint.is_done_flashing(), "parry yapılınca tik")
	t.set_tell(EnemyBase.Tell.NONE)
	check(await _wait_until_real(func() -> bool: return g.active == Tutorial.STEP_STRIKE, 5.0), "ardından 'VUR' ipucu")
	check(_hint_keys(hint) == ["J"] and hint.title == "SERSEMLEDİ", "SERSEMLEDİ: J tuşu")
	EventBus.damage_dealt.emit(t, 1, p)
	check(g.done.has("strike") and hint.is_done_flashing(), "sersemlemiş düşmana vurunca tik")
	check(await _wait_until_real(func() -> bool: return g.active == "" and not hint.is_showing(), 5.0), "ipucu kapandı")
	# Parry öğrenildi: altın uyarı artık ipucu göstermez
	t.set_tell(EnemyBase.Tell.GOLD)
	check(g.active == "", "parry yapılmışsa altın uyarıda ipucu yok")
	t.set_tell(EnemyBase.Tell.NONE)
	# 4) Kırmızı uyarı -> DASH
	t.set_tell(EnemyBase.Tell.RED)
	check(g.active == Tutorial.STEP_RED and hint.title == "KIRMIZI İŞARET" and _hint_keys(hint) == ["SHIFT"], "kırmızı uyarı: SHIFT = DASH ipucu")
	check(_hint_text(hint).contains("PARRY'LENEMEZ"), "'PARRY'LENEMEZ' yazıyor")
	# Gerçekten dash'le savuşturma: altın saldırıyı savuşturmak yetmez, kırmızı gerekir
	var gold_hb := Hitbox.new()
	gold_hb.parryable = true
	EventBus.dodge_success.emit(p, gold_hb)
	check(not g.done.has("red"), "altın saldırıyı dash'le savuşturmak kırmızı dersini bitirmez")
	var red_hb := Hitbox.new()
	red_hb.parryable = false
	EventBus.dodge_success.emit(p, red_hb)
	check(g.done.has("red") and hint.is_done_flashing(), "kırmızı saldırıyı dash'le savuşturunca tik")
	gold_hb.free()
	red_hb.free()
	run.queue_free()
	await _frames(3)
	# Kırmızı ipucu 3 kez gösterilince (savuşturulmasa da) bir daha çıkmaz
	await _new_world("Öğretici: kırmızı ipucu en fazla 3 kez gösterilir")
	var runb := _start_run(42, true)
	await _frames(5)
	var gb := runb.tutorial
	check(await _walk_to_next_room(runb), "2. odaya girildi")
	await _wait_until(func() -> bool: return runb.current_room().alive_count() > 0 or runb.current_room().pending_count() > 0, 300)
	runb.skip_room()
	await _frames(6)
	var tb := TAURUS.instantiate() as Taurus
	runb.enemies_root.add_child(tb)
	tb.process_mode = Node.PROCESS_MODE_DISABLED
	var shown := 0
	for i in 5:
		tb.set_tell(EnemyBase.Tell.RED)
		if gb.active == Tutorial.STEP_RED:
			shown += 1
		tb.set_tell(EnemyBase.Tell.NONE)
		gb._hold_t = 0.0
		gb._refresh()
	check(shown == TutorialGuide.RED_HINT_LIMIT and gb.done.has("red"), "kırmızı ipucu %d kez gösterildi, sonra bırakıldı" % shown)
	runb.queue_free()
	await _frames(3)


func _test_tutorial_save() -> void:
	await _new_world("Öğretici kaydı: profil bayrağı, bitince ipucu çıkmaz, kat 1'den çıkınca biter")
	GameState.god_mode = false
	TimeStop.reset()
	ItemView.active_menu = null
	_clean_saves()
	var slot := SaveSlot.create(0, "Ogr", Difficulty.Level.NORMAL)
	check(not slot.tutorial_done and not (slot.to_dict()["tutorial_done"] as bool), "yeni profil: öğretici yapılmadı")
	var d := slot.to_dict()
	d["tutorial_done"] = true
	check(SaveSlot.from_dict(d, 0).tutorial_done, "bayrak kayıttan okunuyor")
	d.erase("tutorial_done")
	check(not SaveSlot.from_dict(d, 0).tutorial_done, "eski kayıtta (bayraksız) öğretici yapılmamış sayılır")
	d["tutorial_done"] = "evet"
	check(not SaveSlot.from_dict(d, 0).tutorial_done, "bozuk değer yok sayılır")
	check(Tutorial.hints_wanted(null) and Tutorial.hints_wanted(slot), "kayıtsız oturumda ve yeni profilde ipuçları açık")
	SaveStore.save_slot(slot)
	GameState.begin_session(slot, GameMode.Kind.NORMAL)
	var run := _start_run(51, true)
	await _frames(5)
	var g := run.tutorial
	check(g != null and run.hud.tutorial_hint.is_showing(), "profilde öğretici bitmemiş: rehber kuruldu")
	var finished := [false]
	g.finished.connect(func() -> void: finished[0] = true)
	var steps_done: Array = []
	g.step_done.connect(func(id: String) -> void: steps_done.append(id))
	for id: String in Tutorial.REQUIRED:
		check(not slot.tutorial_done, "'%s' öncesinde profil işaretli değil" % id)
		g._complete(id)
	check(finished[0] and g.finished_flag, "hepsi yapılınca rehber bitti")
	check(steps_done == Tutorial.REQUIRED, "adımlar sırayla bildirildi (%s)" % str(steps_done))
	check(slot.tutorial_done and SaveStore.load_slot(0).tutorial_done, "profil 'öğretici tamam' diye kaydedildi")
	check(run.hud.announcer.count() >= 1, "'ÖĞRETİCİ TAMAM' duyurusu")
	g._complete("go")
	run.queue_free()
	await _frames(3)
	# Bitmiş profilde yeni koşu: ipucu yok (kat 1'in tek tek akışı yine de var)
	GameState.begin_session(SaveStore.load_slot(0), GameMode.Kind.NORMAL)
	var run2 := _start_run(52, true)
	await _frames(5)
	check(run2.tutorial == null and not run2.hud.tutorial_hint.is_showing(), "öğretici bitmiş profilde ipucu çıkmaz")
	check((run2.rooms[1] as Room).waves.size() == 2 and (run2.rooms[1] as Room).tuning_for_wave(0).gold_only, "kat 1'in müfredatı (tek tek, yavaş) yine de var")
	run2.queue_free()
	await _frames(3)
	# Yarım kalan öğretici: kat 1'den çıkınca (kat 2) biter ve profil işaretlenir
	var slot3 := SaveSlot.create(1, "Yarim", Difficulty.Level.NORMAL)
	SaveStore.save_slot(slot3)
	GameState.begin_session(slot3, GameMode.Kind.NORMAL)
	var run3 := _start_run(53, true)
	await _frames(5)
	var g3 := run3.tutorial
	check(g3 != null and not slot3.tutorial_done, "yeni profil: rehber açık")
	run3.dev_next_floor()
	await _frames(3)
	check(run3.current_floor() == 2 and g3.finished_flag and slot3.tutorial_done and not run3.hud.tutorial_hint.is_showing(), "kat 2'ye geçince öğretici biter, profil işaretlenir")
	run3.queue_free()
	await _frames(3)
	# Katın ortasından devam (kat 3): rehber yok
	var mid := slot3.run_of(GameMode.Kind.NORMAL).duplicate(true)
	if mid.is_empty():
		mid = {"v": 2, "floor": 3, "room": 2, "seed": 77}
	mid["floor"] = 3
	mid["room"] = 2
	var slot4 := SaveSlot.create(2, "Orta", Difficulty.Level.NORMAL)
	GameState.begin_session(slot4, GameMode.Kind.NORMAL)
	var run4 := _resume_run(mid)
	await _frames(5)
	check(run4.current_floor() == 3 and run4.tutorial == null, "kat 3'ten devam: rehber kurulmaz")
	run4.queue_free()
	await _frames(3)
	_end_saves()


func _test_tutorial_view() -> void:
	await _new_world("Öğretici paneli: tüm ipuçları sığıyor, fontta olmayan harf yok")
	var hint := TutorialHint.new()
	_world.add_child(hint)
	await _frames(2)
	var ids := [Tutorial.STEP_MOVE, Tutorial.STEP_JUMP, Tutorial.STEP_DASH, Tutorial.STEP_ATTACK, Tutorial.STEP_GO, Tutorial.STEP_PARRY, Tutorial.STEP_PARRY_SHOT, Tutorial.STEP_PARRY_MISS, Tutorial.STEP_STRIKE, Tutorial.STEP_RED]
	var complete := true
	var fits := true
	var worst := 0.0
	var missing := ""
	var font := GameFont.get_font()
	for id: String in ids:
		var data := Tutorial.hint(id, 1)
		if data.is_empty() or String(data["title"]) == "" or (data["rows"] as Array).is_empty() or String(data["id"]) != id:
			complete = false
			continue
		hint.show_hint(data)
		var r := hint._panel_rect()
		worst = maxf(worst, r.end.y)
		if r.size.x > TutorialHint.PANEL_MAX_W + 0.5 or r.end.y > 142.0 or r.position.x < 0.0:
			fits = false
		# İçerik panelin içinde kalmalı (panel genişliği kırpılmamalı)
		for row: Dictionary in hint.rows:
			if hint._row_width(row) + TutorialHint.PAD_X * 2.0 > TutorialHint.PANEL_MAX_W:
				fits = false
		var all := hint.title
		for row: Dictionary in hint.rows:
			for part: Dictionary in row["parts"]:
				if part.has("t"):
					all += String(part["t"])
				elif part.has("k"):
					all += String(part["k"])
		for ch in GameFont._prep(all):
			if ch != " " and not font.has_char(ch.unicode_at(0)):
				missing += ch
	check(complete, "10 ipucunun hepsinin başlığı ve satırları var")
	check(fits, "paneller 700 px'e ve üstteki 142 px'e sığıyor, içerik kırpılmıyor (en alt %.0f)" % worst)
	check(missing == "", "ipucu yazılarında fontun çizemediği harf yok ('%s')" % missing)
	check(Tutorial.hint("yok").is_empty(), "bilinmeyen ipucu boş döner")
	hint.hide_hint()
	check(not hint.is_showing() and hint.occupied_height() == 0.0, "gizlenince yer kaplamaz")
	# Aynı ipucunu tekrar göstermek animasyonu baştan başlatmaz, yalnız satırları yeniler
	hint.show_hint(Tutorial.hint(Tutorial.STEP_ATTACK, 0))
	await _frames(10)
	var age := hint._age
	hint.show_hint(Tutorial.hint(Tutorial.STEP_ATTACK, 2))
	check(hint._age == age and _hint_text(hint).contains("2/3"), "sayaç güncellenince panel yeniden belirmez")
	hint.mark_done()
	check(hint.is_done_flashing(), "tamamlanma geçişi başladı")
	var fin := [false]
	hint.flash_finished.connect(func() -> void: fin[0] = true)
	check(await _wait_until_real(func() -> bool: return fin[0], 4.0) and not hint.is_showing(), "geçiş bitince panel kapanır ve haber verir")


## Gerçek fizikle: kat 1'in ilk Taurus'u (yavaş, yalnız altın) uyarı verir -> PARRY ipucu; gerçek parry -> tik -> vur -> tik.
func _test_tutorial_real_parry() -> void:
	await _new_world("Öğretici (gerçek akış): ilk Taurus altın uyarır, gerçek parry ve vuruşla ipuçları ilerler")
	GameState.god_mode = false
	TimeStop.reset()
	ItemView.active_menu = null
	GameState.end_session()
	var run := _start_run(61, true)
	await _frames(5)
	var p := run.player
	var g := run.tutorial
	var hint := run.hud.tutorial_hint
	var hp0 := p.health
	check(await _walk_to_next_room(run), "2. odaya girildi")
	p.global_position.x = run.current_room().rect.position.x + 120.0
	p.facing = 1
	var parry_hint := await _wait_until(func() -> bool: return g.active == Tutorial.STEP_PARRY, 1500)
	check(parry_hint, "Taurus altın uyarı verince PARRY ipucu çıktı")
	var taurus: Taurus = null
	for e in get_tree().get_nodes_in_group("enemies"):
		taurus = e as Taurus
	check(taurus != null and taurus.tuning != null and taurus.tuning.gold_only and taurus.tell_mode() == EnemyBase.Tell.GOLD, "uyarı veren: yalnız-altın ayarlı Taurus")
	# Gerçek parry: atılma yaklaşınca K
	var pressed := false
	for i in 400:
		await get_tree().physics_frame
		if not pressed and taurus._phase == Taurus.Phase.LUNGE and absf(taurus.global_position.x - p.global_position.x) < 120.0:
			p.intent.parry_pressed = true
			pressed = true
		if g.done.has("parry"):
			break
	check(pressed and g.done.has("parry") and p.health == hp0, "gerçek parry yapıldı, can kaybı yok (rehber bunu gördü)")
	check(taurus.is_stunned(), "Taurus sersemledi")
	check(await _wait_until_real(func() -> bool: return g.active == Tutorial.STEP_STRIKE, 5.0), "tikten sonra 'VUR' ipucu")
	# Gerçek vuruş
	p.global_position.x = taurus.global_position.x - 50.0
	await _frames(3)
	p.intent.attack_pressed = true
	var hit := await _wait_until(func() -> bool: return g.done.has("strike"), 40)
	check(hit, "sersemlemiş Taurus'a gerçek vuruş: VUR adımı tamamlandı")
	check(hint.is_done_flashing() or not hint.is_showing(), "tik gösterildi")
	run.queue_free()
	await _frames(3)


# ------------------------------------------------------------------ Gölge (Umbra)

## Gölge'yi sahneye koyar. `auto` = false: kendi kendine hamle seçmez (testler `force_move` ile başlatır).
func _spawn_umbra(x: float, floor_no: int = 1, t: EnemyTuning = null, auto: bool = false) -> Umbra:
	var u := UMBRA.instantiate() as Umbra
	u.set_meta("floor", floor_no)
	u.gold_min = 0
	u.gold_max = 0
	if t != null:
		u.tuning = t
	_world.add_child(u)
	u.global_position = Vector2(x, 612.0)
	if not auto:
		u.abilities = []
		u._cooldown = 999.0
	return u


## İki yana dikey duvar (Gölge'nin duvar tırmanışı ve arena sınırı için). İç yüzler: sol_x + 20 ve sağ_x - 20.
func _add_walls(left_x: float, right_x: float) -> void:
	for x in [left_x, right_x]:
		var wall := StaticBody2D.new()
		wall.collision_layer = Layers.WORLD
		wall.collision_mask = 0
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = Vector2(40.0, 1400.0)
		cs.shape = rs
		cs.position = Vector2(float(x), 40.0)
		wall.add_child(cs)
		_world.add_child(wall)


## Sahnede Gölge'nin attığı (hâlâ ona ait) bıçaklar.
func _umbra_knives(u: Umbra) -> Array[Projectile]:
	var out: Array[Projectile] = []
	for node in get_tree().get_nodes_in_group("projectiles"):
		var pr := node as Projectile
		if pr != null and not pr.is_queued_for_deletion() and pr.original_source == u:
			out.append(pr)
	return out


func _count_marks() -> int:
	var n := 0
	for c in _world.get_children():
		if c is UmbraMark and not c.is_queued_for_deletion():
			n += 1
	return n


func _count_clones() -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("minions"):
		var mm := node as UmbraMinion
		if mm != null and mm.kind == UmbraMinion.Kind.CLONE:
			n += 1
	return n


## Gölge'yi ve oyuncuyu bir sonraki hamle sınaması için sıfırlar (hamle, mermi, minyon, işaret, zırh, kilit temizlenir).
func _umbra_reset(u: Umbra, p: Player) -> void:
	u._end_move(0.0)
	get_tree().call_group("projectiles", "queue_free")
	get_tree().call_group("minions", "dissolve")
	for c in _world.get_children():
		if c is UmbraMark:
			c.queue_free()
	u.health = u.max_hp
	u.stun_t = 0.0
	u.knock_t = 0.0
	u._armor_t = 0.0
	u._poise_hits = 0
	u._force_melee = false
	u._lock.clear()
	u.velocity = Vector2.ZERO
	u.global_position = Vector2(900.0, 612.0)
	u._cooldown = 999.0
	p.invulnerable_t = 0.0
	p.health = 999
	p.global_position = Vector2(500.0, 612.0)
	p.velocity = Vector2.ZERO
	p.facing = 1
	await _frames(20)


## Hamleyi başlatır, bitene dek (en çok `max_frames` kare) izler; gözlemleri sözlük olarak döndürür.
func _observe_umbra_move(u: Umbra, m: int, max_frames: int = 900) -> Dictionary:
	var obs := {
		"started": false, "done": false, "frames": 0, "strikes": 0, "last_red": false, "knives": [],
		"min_y": u.global_position.y, "alpha_min": 1.0, "blades": 0, "minions": 0, "clones": 0, "marks": 0,
		"knife_x": NAN, "untouchable": false, "armored": false, "counter": false, "gravity_min": u.gravity,
	}
	var seen := {}
	var was_active := false
	obs["started"] = u.force_move(m)
	if not bool(obs["started"]):
		return obs
	for i in max_frames:
		await get_tree().physics_frame
		obs["frames"] = i + 1
		var active := u.attack_hitbox.active
		if active and not was_active:
			obs["strikes"] = int(obs["strikes"]) + 1
			obs["last_red"] = not u.attack_hitbox.parryable
		was_active = active
		for pr in _umbra_knives(u):
			if not seen.has(pr):
				seen[pr] = true
				(obs["knives"] as Array).append({"parryable": pr.parryable, "vx": pr.velocity.x, "vy": pr.velocity.y})
		obs["min_y"] = minf(float(obs["min_y"]), u.global_position.y)
		obs["alpha_min"] = minf(float(obs["alpha_min"]), u.visual_alpha)
		obs["gravity_min"] = minf(float(obs["gravity_min"]), u.gravity)
		obs["blades"] = maxi(int(obs["blades"]), u._blades.size())
		obs["minions"] = maxi(int(obs["minions"]), u.minion_count())
		obs["clones"] = maxi(int(obs["clones"]), _count_clones())
		obs["marks"] = maxi(int(obs["marks"]), _count_marks())
		if u._untouchable:
			obs["untouchable"] = true
		if u.armored:
			obs["armored"] = true
		if u._counter_on:
			obs["counter"] = true
		if u.current_move == UM.KNIFE and is_nan(float(obs["knife_x"])):
			obs["knife_x"] = u.global_position.x
		if u.is_idle():
			obs["done"] = true
			break
	return obs


func _test_umbra_kit() -> void:
	await _new_world("Gölge: yetenek merdiveni ve kat ölçeklemesi (UmbraKit)")
	var n: int = UmbraKit.LADDER.size()
	check(n == 18 and n == FloorPlan.FLOOR_COUNT, "merdiven 18 katlık, kat sayısıyla aynı (%d)" % n)
	var names := {}
	var ids := {}
	var shape_ok := true
	var filled_ok := true
	for i in n:
		var a: Dictionary = UmbraKit.LADDER[i]
		names[str(a["name"])] = true
		ids[str(a["id"])] = true
		if a.has("move") == a.has("passive"):
			shape_ok = false
		if str(a["name"]) == "" or str(a["text"]) == "":
			filled_ok = false
	check(names.size() == n and ids.size() == n, "her katın yeteneği ayrı ad ve kimlik taşıyor")
	check(shape_ok, "her yetenek ya hamle ya pasif (ikisi birden değil)")
	check(filled_ok, "adlar ve açıklamalar dolu")
	# Kullanıcının tarifi: 1 bıçak, 2 fırlatma, 3 duvar tırmanışı, 4 minyon
	check(UmbraKit.moves_for(1) == [UM.KNIFE], "kat 1: yalnız bıçak")
	check(UmbraKit.moves_for(2) == [UM.KNIFE, UM.THROW], "kat 2: + fırlatma")
	check(UM.CLIMB in UmbraKit.moves_for(3) and UmbraKit.floor_of_move(UM.CLIMB) == 3, "kat 3: + duvar tırmanışı")
	check(UM.MINIONS in UmbraKit.moves_for(4) and UmbraKit.floor_of_move(UM.MINIONS) == 4, "kat 4: + minyon çağırma")
	var prev: Array = []
	var cumulative := true
	var one_at_a_time := true
	for f in range(1, 19):
		var mv := UmbraKit.moves_for(f)
		for m in prev:
			if not (m in mv):
				cumulative = false
		if mv.size() - prev.size() > 1:
			one_at_a_time = false
		prev = mv
	check(cumulative, "her kat öncekilerin hepsini korur")
	check(one_at_a_time, "her kat en çok bir yeni hamle ekler")
	check(UmbraKit.moves_for(18).size() == 15, "kat 18: 15 hamle")
	check(UmbraKit.passives_for(18) == ["armor", "second_wind", "real"], "kat 18 pasifleri: zırh, ikinci nefes, gerçek dövüş")
	check(UmbraKit.has_passive(8, "armor") and not UmbraKit.has_passive(7, "armor"), "zırh kat 8'den")
	check(UmbraKit.has_passive(15, "second_wind") and not UmbraKit.has_passive(14, "second_wind"), "ikinci nefes kat 15'ten")
	check(UmbraKit.has_passive(18, "real") and not UmbraKit.has_passive(17, "real"), "gerçek dövüş yalnız kat 18'de")
	check(UmbraKit.ability_name(99) == UmbraKit.ability_name(18) and UmbraKit.clamp_floor(0) == 1, "kat dışı değerler kırpılır")
	check(UmbraKit.ability_name(1) == "BIÇAK" and UmbraKit.ability_name(18) == "GERÇEK DÖVÜŞ", "ilk ve son yetenek adları")
	var every_move_named := true
	for m in UmbraKit.moves_for(18):
		if not UmbraKit.LOCKOUT.has(m) or not UmbraKit.MOVE_NAMES.has(m) or UmbraKit.move_name(m) == "?":
			every_move_named = false
	check(every_move_named, "her hamlenin kilit süresi ve adı tanımlı")
	# Ölçekleme
	var up := true
	var down := true
	for f in range(1, 18):
		if not (UmbraKit.hp_mult(f + 1) > UmbraKit.hp_mult(f) and UmbraKit.speed_mult(f + 1) > UmbraKit.speed_mult(f)):
			up = false
		if UmbraKit.red_bonus(f + 1) < UmbraKit.red_bonus(f):
			up = false
		if not (UmbraKit.wait_mult(f + 1) < UmbraKit.wait_mult(f)):
			down = false
	check(up, "her kat daha canlı, daha hızlı, daha çok kırmızı")
	check(down, "her kat hamleler arası bekleme kısalıyor")
	check(is_equal_approx(UmbraKit.hp_mult(1), 1.0) and is_equal_approx(UmbraKit.wait_mult(1), 1.0) and is_equal_approx(UmbraKit.red_bonus(1), 0.0), "kat 1: can x1, bekleme x1, kırmızı +0")
	check(is_equal_approx(UmbraKit.wait_mult(18), 0.55) and is_equal_approx(UmbraKit.red_bonus(18), 0.15), "kat 18: bekleme x0.55, kırmızı +0.15")
	check(UmbraKit.hp_for(1, 30) == 30 and UmbraKit.hp_for(18, 30) == 66, "can: kat 1 = 30, kat 18 = 66 (%d)" % UmbraKit.hp_for(18, 30))
	check(UmbraKit.minion_count(4, false) == 2 and UmbraKit.minion_count(11, true) == 5, "minyon sayısı: kat 4'te 2, kat 11 sürüsü 5")
	var cap_ok := true
	for f in range(UmbraKit.floor_of_move(UM.SWARM), 19):
		if UmbraKit.minion_cap(f) < UmbraKit.minion_count(f, true):
			cap_ok = false
	check(cap_ok, "sürü sayısı sahne sınırını aşmıyor")
	check(UmbraKit.rain_count(9) == 6 and UmbraKit.rain_count(18) == 8, "bıçak yağmuru: kat 9'da 6, kat 18'de 8")
	check(UmbraKit.orbit_count(12) == 3 and UmbraKit.orbit_count(18) == 4, "dönen bıçak: kat 12'de 3, kat 18'de 4")
	var sp := UmbraKit.spec(18)
	check(bool(sp["armor"]) and bool(sp["second_wind"]) and bool(sp["real"]) and (sp["moves"] as Array).size() == 15, "spec(18) hepsini taşıyor")
	check(not bool(UmbraKit.spec(1)["armor"]) and not bool(UmbraKit.spec(1)["real"]), "spec(1) pasifsiz")
	# Hamle ağırlıkları
	var near := {"dx": 120.0, "level": true, "hp": 1.0, "minions": 0, "proj": 0, "phase": 1, "last": UM.NONE}
	var far := near.duplicate()
	far["dx"] = 600.0
	check(UmbraKit.weight(UM.KNIFE, near) > 0.0 and UmbraKit.weight(UM.KNIFE, far) == 0.0, "bıçak yakında seçilir, uzaktan seçilmez")
	check(UmbraKit.weight(UM.COMBO, far) == 0.0 and UmbraKit.weight(UM.COMBO, near) > 0.0, "kombo yalnız yakında")
	check(UmbraKit.weight(UM.THROW, far) > UmbraKit.weight(UM.THROW, near), "fırlatma uzaktan daha olası")
	var crowd := near.duplicate()
	crowd["minions"] = 2
	crowd["hp"] = 0.5
	check(UmbraKit.weight(UM.MINIONS, crowd) == 0.0 and UmbraKit.weight(UM.SWARM, crowd) == 0.0, "minyonlar sağken yenisi çağrılmaz")
	var hurt := near.duplicate()
	hurt["hp"] = 0.5
	check(UmbraKit.weight(UM.MINIONS, hurt) > 0.0 and UmbraKit.weight(UM.SWARM, hurt) > 0.0, "canı düşünce minyon çağırır")
	check(UmbraKit.weight(UM.SWARM, near) == 0.0, "sürü yalnız canı %80'in altına inince")
	var knives := near.duplicate()
	knives["proj"] = 3
	check(UmbraKit.weight(UM.THROW, knives) == 0.0 and UmbraKit.weight(UM.FAN, knives) == 0.0 and UmbraKit.weight(UM.COUNTER, knives) == 0.0, "havada bıçak varken fırlatma/karşı duruş yok")
	var far_wall := far.duplicate()
	far_wall["wall"] = 1200.0
	check(UmbraKit.weight(UM.CLIMB, far_wall) < UmbraKit.weight(UM.CLIMB, far), "duvar çok uzaksa tırmanış az seçilir")
	var melee := near.duplicate()
	melee["force_melee"] = true
	check(UmbraKit.weight(UM.KNIFE, melee) > UmbraKit.weight(UM.KNIFE, near) and UmbraKit.weight(UM.THROW, melee) < UmbraKit.weight(UM.THROW, near), "poise kırılınca yakın dövüş öne çıkar")
	var repeat := near.duplicate()
	repeat["last"] = UM.KNIFE
	check(UmbraKit.weight(UM.KNIFE, repeat) < UmbraKit.weight(UM.KNIFE, near), "aynı hamle üst üste az seçilir")
	# Seçim
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	check(UmbraKit.pick(UmbraKit.moves_for(1), far, {}, rng) == UM.NONE, "kat 1'de uzakta seçecek hamle yok (yaklaşır)")
	check(UmbraKit.pick(UmbraKit.moves_for(1), near, {}, rng) == UM.KNIFE, "kat 1'de yakında bıçak")
	check(UmbraKit.pick([UM.KNIFE], near, {UM.KNIFE: 2.0}, rng) == UM.NONE, "kilitli hamle seçilmez")
	var mid := {"dx": 300.0, "level": true, "hp": 0.6, "minions": 0, "proj": 0, "phase": 1, "last": UM.NONE, "wall": 300.0}
	var seen := {}
	for i in 600:
		seen[UmbraKit.pick(UmbraKit.moves_for(18), mid, {}, rng)] = true
	check(seen.size() >= 9, "kat 18'de çok çeşitli hamle seçiliyor (%d tür)" % seen.size())
	check(not seen.has(UM.NONE) and not seen.has(UM.WIND), "seçim NONE/WIND vermiyor")
	# Umbra'ya kalan eşyalar
	var good := _dummy_item("g1")
	good.mods = [["max_health", 1.0, 1.0], ["move_speed", 0.0, 1.2], ["parry_window", 0.05, 1.0]]
	check(UmbraKit.usable_mods(good).size() == 2, "yalnız can ve hız Gölge'ye geçer (parry penceresi geçmez)")
	var blocked := _dummy_item("g2")
	blocked.umbra_allowed = false
	blocked.mods = [["max_health", 1.0, 1.0]]
	check(UmbraKit.usable_mods(blocked).is_empty() and UmbraKit.usable_mods(null).is_empty(), "umbra_allowed=false ya da boş eşya: etki yok")


func _test_umbra_scene() -> void:
	await _new_world("Gölge: sahne, kat ölçeklemesi, gruplar, patron sinyali ve kalan eşyalar")
	GameState.umbra_items.clear()
	var p := _spawn_player(300.0)
	var spawned := []
	var cb := func(b: Node) -> void: spawned.append(b)
	EventBus.boss_spawned.connect(cb)
	var u1 := _spawn_umbra(900.0, 1, null, true)
	var u18 := _spawn_umbra(1300.0, 18, null, true)
	EventBus.boss_spawned.disconnect(cb)
	await _frames(5)
	check(spawned.size() == 2 and spawned[0] == u1 and spawned[1] == u18, "boss_spawned her Gölge için bir kez")
	check(u1.is_in_group("boss") and u1.is_in_group("enemies"), "gruplar: boss + enemies")
	check(u1.floor_no == 1 and u18.floor_no == 18, "kat meta'dan okundu")
	check(u1.max_hp == 30 and u1.health == 30, "kat 1: 30 can")
	check(u18.max_hp == UmbraKit.hp_for(18, 30) and u18.max_hp > u1.max_hp * 2, "kat 18: çok daha canlı (%d)" % u18.max_hp)
	check(u1.abilities == [UM.KNIFE] and u18.abilities.size() == 15, "açık hamleler: kat 1 = 1, kat 18 = 15")
	check(not u1.armored and u1.is_idle() and u1.phase == 1, "başlangıç: zırhsız, boşta, evre 1")
	check(u1.get_node("Visual") != null and u1.hurtbox != null and u1.attack_hitbox.faction == "enemy" and not u1.attack_hitbox.active, "yer tutucu çizim, hurtbox ve kapalı saldırı alanı")
	check(u1.attack_shape.shape != u18.attack_shape.shape, "her Gölge kendi saldırı şeklini taşıyor (paylaşılmıyor)")
	check(u1.anim_folder() == "res://assets/sprites/umbra" and u1.anim_spec().has("throw") and u1.anim_spec().has("climb") and u1.anim_spec().has("roar"), "sanat klasörü ve hamle animasyon adları (umbra_throw, umbra_climb, umbra_roar...)")
	# Düşman ölçeklemesi (EnemyScaling) üstüne biner
	var t := EnemyScaling.tuning(Difficulty.Level.NORMAL, 60)
	var us := _spawn_umbra(1500.0, 18, t)
	check(us.max_hp == t.scale_hp(UmbraKit.hp_for(18, 30)) and us.max_hp > u18.max_hp, "kat ölçeği + düşman ölçeği çarpılıyor (%d)" % us.max_hp)
	# Umbra'ya kalan eşyalar Gölge'yi güçlendirir
	var it := _dummy_item("kalan_kilic")
	it.mods = [["max_health", 5.0, 1.0], ["attack_damage", 0.0, 1.5], ["move_speed", 0.0, 1.2]]
	GameState.umbra_items.append(it)
	var ui := _spawn_umbra(1700.0, 1)
	GameState.umbra_items.erase(it)
	check(ui.max_hp == 39 and ui.health == 39, "kalan 'can' eşyası: 30 x 1.30 = 39 (%d)" % ui.max_hp)
	check(ui._dmg(2) == 3 and u1._dmg(2) == 2, "kalan 'hasar' eşyası: kırmızı 2 -> 3")
	check(is_equal_approx(ui._spd(), 180.0) and is_equal_approx(u1._spd(), 150.0), "kalan 'hız' eşyası: 150 -> 180")
	check(p != null, "oyuncu hazır")


func _test_umbra_knife() -> void:
	await _new_world("Gölge: bıçak (altın = parry'le, kırmızı = kaç), vurulunca hazırlık bozulur")
	var p := _spawn_player(600.0)
	p.health = 999
	var u := _spawn_umbra(700.0, 1)
	u.red_override = 0
	await _frames(10)
	check(u.force_move(UM.KNIFE), "bıçak hamlesi başladı")
	check(u.current_move == UM.KNIFE and u.stage == Umbra.K_TELL and u.tell_mode() == EnemyBase.Tell.GOLD, "altın uyarı verdi")
	await _frames(2)
	check(not u.armored, "kat 1'de hazırlık sırasında zırh yok")
	var hp0 := p.health
	var pressed := false
	for i in 200:
		await get_tree().physics_frame
		if not pressed and u.stage == Umbra.K_STRIKE and u.current_move == UM.KNIFE:
			check(u.attack_hitbox.active and u.attack_hitbox.parryable, "darbe sırasında alan açık ve parry'lenebilir")
			p.intent.parry_pressed = true
			pressed = true
		if _parry_ok > 0:
			break
	await _frames(2)
	check(pressed and _parry_ok == 1, "altın bıçak parry'lendi")
	check(p.health == hp0, "can kaybı yok")
	check(u.is_stunned() and u.is_idle() and not u.attack_hitbox.active, "Gölge sersemledi, hamle kesildi, alan kapandı")
	var hb := u.health
	p.global_position.x = u.global_position.x - 50.0
	await _frames(3)
	p.intent.attack_pressed = true
	for i in 30:
		await get_tree().physics_frame
		if u.health < hb:
			break
	check(hb - u.health == 3, "parry sonrası güçlü vuruş x sersem bonusu = 3 hasar (%d)" % (hb - u.health))
	# Kırmızı bıçak
	await _new_world("Gölge: kırmızı bıçak parry'lenemez ve 2 hasar verir")
	p = _spawn_player(600.0)
	p.health = 999
	u = _spawn_umbra(700.0, 1)
	u.red_override = 1
	await _frames(10)
	hp0 = p.health
	check(u.force_move(UM.KNIFE) and u.tell_mode() == EnemyBase.Tell.RED, "kırmızı uyarı verdi")
	var in_strike := false
	for i in 200:
		await get_tree().physics_frame
		if u.stage == Umbra.K_STRIKE and not in_strike:
			in_strike = true
			check(u.attack_hitbox.active and not u.attack_hitbox.parryable and u.attack_hitbox.damage == 2, "kırmızı darbe: parry'lenemez, 2 hasar")
		if u.is_idle():
			break
	check(in_strike and u.is_idle(), "darbe bitti, Gölge boşa döndü")
	check(p.health == hp0 - 2, "kaçmayan oyuncu 2 can kaybetti (%d)" % (hp0 - p.health))
	check(_parry_ok == 0, "kırmızı darbe parry sayılmadı")
	# Vurulunca (zırhsız) hazırlık bozulur
	await _frames(5)
	u.red_override = 0
	u.stun_t = 0.0
	u.knock_t = 0.0
	check(u.force_move(UM.KNIFE), "yeniden hazırlanıyor")
	await _frames(5)
	check(u.on_hit_by(_player_hitbox(p, u.global_position + Vector2(-30.0, 0.0))), "vuruş işledi")
	check(u.is_idle() and u.tell_mode() == EnemyBase.Tell.NONE and u.knock_t > 0.0, "kat 1'de vurulunca hazırlık iptal, uyarı söndü")
	check(u._cooldown > 0.2, "hemen yeniden saldırmıyor (bekleme %.2f)" % u._cooldown)


func _test_umbra_throw() -> void:
	await _new_world("Gölge: fırlatma (altın bıçağı parry'lersen ona döner), üçlü fırlatma")
	var p := _spawn_player(300.0)
	p.health = 999
	var u := _spawn_umbra(800.0, 2)
	u.red_override = 0
	await _frames(10)
	check(u.force_move(UM.THROW) and u.tell_mode() == EnemyBase.Tell.GOLD, "fırlatma: altın uyarı")
	var got := await _wait_until(func() -> bool: return u._own_projectiles() >= 1, 120)
	check(got and u._own_projectiles() == 1, "tek bıçak fırlattı")
	var pr: Projectile = _umbra_knives(u)[0]
	check(pr.parryable and pr.faction == "enemy" and pr.velocity.x < 0.0, "bıçak altın ve oyuncuya doğru")
	check(u.tell_mode() == EnemyBase.Tell.NONE, "fırlatınca uyarı söndü")
	var hp_u := u.health
	var hp_p := p.health
	var pressed := false
	for i in 240:
		await get_tree().physics_frame
		if not pressed and is_instance_valid(pr) and pr.global_position.x - p.global_position.x < 85.0:
			p.intent.parry_pressed = true
			pressed = true
		if _parry_ok > 0:
			break
	await _frames(2)
	check(_parry_ok == 1 and p.health == hp_p, "bıçak parry'lendi, can kaybı yok")
	check(is_instance_valid(pr) and pr.faction == "player" and pr.velocity.x > 0.0, "bıçak Gölge'ye geri döndü")
	var hit := await _wait_until(func() -> bool: return u.health < hp_u, 240)
	check(hit and hp_u - u.health == 2, "geri dönen bıçak 2 hasar verdi (%d)" % (hp_u - u.health))
	# Üçlü fırlatma
	await _new_world("Gölge: üçlü fırlatma yelpazesi")
	p = _spawn_player(300.0)
	p.health = 999
	u = _spawn_umbra(900.0, 6)
	u.red_override = 1
	await _frames(10)
	check(u.force_move(UM.FAN) and u.tell_mode() == EnemyBase.Tell.RED, "üçlü fırlatma: kırmızı uyarı")
	await _wait_until(func() -> bool: return u._own_projectiles() >= 3, 160)
	var ks := _umbra_knives(u)
	check(ks.size() == 3, "üç bıçak (%d)" % ks.size())
	var angs: Array[float] = []
	var all_red := true
	for k in ks:
		angs.append(atan2(k.velocity.y, -k.velocity.x))
		if k.parryable:
			all_red = false
	angs.sort()
	check(all_red, "kırmızı uyarı = üç bıçak da parry'lenemez")
	check(angs.size() == 3 and absf((angs[2] - angs[0]) - 0.6) < 0.02 and absf(angs[1] - 0.5 * (angs[0] + angs[2])) < 0.05, "yelpaze: ±0.3 rad (%.2f)" % (angs[2] - angs[0] if angs.size() == 3 else 0.0))


func _test_umbra_climb() -> void:
	await _new_world("Gölge: duvara tırmanır, tepeden atlar; duvardan bıçak yağdırır")
	_add_walls(100.0, 1500.0)
	var p := _spawn_player(500.0)
	p.health = 999
	var u := _spawn_umbra(900.0, 3)
	u.red_override = 0
	await _frames(10)
	var hp0 := p.health
	check(u.force_move(UM.CLIMB) and u._wall_dir == 1, "tırmanış başladı: oyuncudan uzaktaki sağ duvara koşuyor")
	var y0 := u.global_position.y
	var min_y := y0
	var reached_wall := false
	var hung := false
	var hang_ok := false
	var dove := false
	var dive_ok := false
	var landed := false
	for i in 700:
		await get_tree().physics_frame
		min_y = minf(min_y, u.global_position.y)
		if u.stage == Umbra.C_UP and absf(u.global_position.x - 1465.0) < 30.0:
			reached_wall = true
		if u.stage == Umbra.C_HANG and not hung:
			hung = true
			hang_ok = u.gravity == 0.0 and u.armored and u.tell_mode() == EnemyBase.Tell.GOLD
		if u.stage == Umbra.C_ACT and u.attack_hitbox.active and not dove:
			dove = true
			dive_ok = u.attack_hitbox.parryable and u.velocity.y > 0.0 and u.velocity.x < 0.0 and u.armored
		if u.stage == Umbra.C_RECOVER and u.is_on_floor():
			landed = true
		if u.is_idle():
			break
	check(reached_wall, "duvara yaslandı (x ≈ 1465)")
	check(y0 - min_y > 350.0, "duvarda yukarı tırmandı (%.0f px; uzak oyuncu = yüksek tırmanış)" % (y0 - min_y))
	check(hung and hang_ok, "duvarda asılı: yerçekimi 0, zırhlı, altın uyarı")
	check(dove and dive_ok, "dalış: altın alan açık, aşağı-sola hızlı, zırhlı")
	check(landed, "yere indi ve toparlanıyor")
	check(u.is_idle() and u.gravity == u._base_gravity and not u.armored, "bitti: yerçekimi geri geldi, zırh kalktı")
	check(p.health == hp0 - 1, "dalış uzaktaki oyuncuya yetişti (1 hasar, altın) (%d)" % (hp0 - p.health))
	# Dalışı parry'le
	await _umbra_reset(u, p)
	u.red_override = 0
	var pressed := false
	u.force_move(UM.CLIMB)
	for i in 700:
		await get_tree().physics_frame
		if not pressed and u.stage == Umbra.C_ACT and u.attack_hitbox.active and u.global_position.distance_to(p.global_position) < 140.0:
			p.intent.parry_pressed = true
			pressed = true
		if _parry_ok > 0:
			break
	await _frames(2)
	check(pressed and _parry_ok == 1 and u.is_stunned(), "dalışı parry'lemek Gölge'yi sersemletir")
	check(u.gravity == u._base_gravity and not u._committed and u.is_idle(), "sersemleyince yerçekimi geri geldi, tırmanış kesildi")
	# Duvardan atış
	await _new_world("Gölge: duvardan atış (kat 14): tepeden üç bıçak, sonuncusu kırmızı")
	_add_walls(100.0, 1500.0)
	p = _spawn_player(500.0)
	p.health = 999
	u = _spawn_umbra(900.0, 14)
	u.red_override = 0
	await _frames(10)
	var o: Dictionary = await _observe_umbra_move(u, UM.VOLLEY)
	var ks := o["knives"] as Array
	check(bool(o["done"]) and ks.size() == 3, "duvardan atış: 3 bıçak (%d)" % ks.size())
	check(ks.size() == 3 and bool(ks[0]["parryable"]) and bool(ks[1]["parryable"]) and not bool(ks[2]["parryable"]), "ilk ikisi altın, sonuncusu kırmızı")
	check(612.0 - float(o["min_y"]) > 350.0 and float(o["gravity_min"]) == 0.0, "atışı duvarın tepesinden, yerçekimsiz yaptı")
	check(u.gravity == u._base_gravity and not u._committed, "atış bitince yerçekimi geri geldi")


func _test_umbra_minions() -> void:
	await _new_world("Gölge: minyon çağırır (doğarken vurulamaz), sayı sınırı, sürü, klon")
	_add_walls(100.0, 1500.0)
	var p := _spawn_player(500.0)
	p.health = 999
	var u := _spawn_umbra(900.0, 4)
	await _frames(10)
	check(u.force_move(UM.MINIONS) and u._casting and u.tell_mode() == EnemyBase.Tell.NONE, "çağırma: mor parlama (parry uyarısı değil)")
	var came := await _wait_until(func() -> bool: return u.minion_count() >= 1, 150)
	check(came and u.minion_count() == UmbraKit.minion_count(4, false), "kat 4: %d minyon geldi" % u.minion_count())
	var m := get_tree().get_nodes_in_group("minions")[0] as UmbraMinion
	check(m.is_in_group("enemies") and m.is_emerging(), "minyon düşman sayılır, doğuyor")
	check(not m.on_hit_by(_player_hitbox(p, m.global_position)), "doğarken vurulamaz")
	var spots_ok := true
	for node in get_tree().get_nodes_in_group("minions"):
		var mm := node as UmbraMinion
		if absf(mm.global_position.x - p.global_position.x) < 60.0 or mm.global_position.x < 110.0 or mm.global_position.x > 1480.0:
			spots_ok = false
	check(spots_ok, "minyonlar oyuncunun üstüne ve duvarın içine doğmadı")
	await _frames(60)
	check(not m.is_emerging() and m.visual_alpha > 0.99, "doğuş bitti")
	var hpm := m.health
	m.stun_t = 0.0
	check(m.on_hit_by(_player_hitbox(p, m.global_position)) and m.health < hpm, "doğduktan sonra vurulabilir")
	# Sayı sınırı
	await _wait_until(func() -> bool: return u.is_idle(), 200)
	for k in 3:
		u._cooldown = 999.0
		u.force_move(UM.MINIONS)
		await _wait_until(func() -> bool: return u.is_idle(), 200)
	check(u.minion_count() <= UmbraKit.minion_cap(4), "sahnede en çok %d minyon (%d)" % [UmbraKit.minion_cap(4), u.minion_count()])
	# Sürü
	await _new_world("Gölge: sürü (kat 11) ve klon (kat 16)")
	_add_walls(100.0, 1500.0)
	p = _spawn_player(500.0)
	p.health = 999
	var u11 := _spawn_umbra(900.0, 11)
	await _frames(10)
	u11.force_move(UM.SWARM)
	await _wait_until(func() -> bool: return u11.minion_count() >= 1, 150)
	check(u11.minion_count() == UmbraKit.minion_count(11, true), "sürü: %d minyon" % u11.minion_count())
	get_tree().call_group("minions", "dissolve")
	u11.queue_free()
	await _frames(3)
	# Klon: karşı yanda belirir, tek KIRMIZI darbe vurur ve kaybolur; Gölge'nin kendi darbesi ALTIN
	var u16 := _spawn_umbra(1300.0, 16)
	u16.max_hp = 99999
	u16.health = 99999
	await _frames(10)
	p.global_position.x = 700.0
	u16.force_move(UM.CLONE)
	var cl: UmbraMinion = null
	for i in 200:
		await get_tree().physics_frame
		for node in get_tree().get_nodes_in_group("minions"):
			var mm := node as UmbraMinion
			if mm != null and mm.kind == UmbraMinion.Kind.CLONE:
				cl = mm
		if cl != null:
			break
	check(cl != null, "klon belirdi")
	check(cl != null and cl.global_position.x < p.global_position.x and u16.global_position.x > p.global_position.x, "klon Gölge'nin KARŞI yanında (oyuncunun diğer tarafı)")
	check(u16.current_move == UM.KNIFE and not u16._red, "Gölge'nin kendi darbesi altın (klonunki kırmızı)")
	var clone_struck := false
	var clone_red := false
	for i in 300:
		await get_tree().physics_frame
		if cl != null and is_instance_valid(cl) and cl.attack_hitbox.active:
			clone_struck = true
			clone_red = not cl.attack_hitbox.parryable
		if cl == null or not is_instance_valid(cl) or cl.dead:
			break
	check(clone_struck and clone_red, "klon KIRMIZI darbe vurdu")
	for i in 120:
		if not is_instance_valid(cl) or cl.is_queued_for_deletion():
			break
		await get_tree().physics_frame
	check(not is_instance_valid(cl) or cl.is_queued_for_deletion(), "klon vuruştan sonra kayboldu")


func _test_umbra_moves() -> void:
	await _new_world("Gölge: kat 18'de 15 hamlenin hepsi çalışıyor ve kendine özgü izini bırakıyor")
	_add_walls(100.0, 1500.0)
	var p := _spawn_player(500.0)
	p.health = 999
	var u := _spawn_umbra(900.0, 18)
	u.max_hp = 99999
	u.health = 99999
	u.red_override = 0
	await _frames(10)
	var o: Dictionary = {}
	# 1) BIÇAK
	o = await _observe_umbra_move(u, UM.KNIFE)
	check(bool(o["started"]) and bool(o["done"]) and int(o["strikes"]) == 1, "BIÇAK: bir darbe, bitti (%d)" % int(o["strikes"]))
	# 2) KOMBO: üç darbe, sonuncusu hep kırmızı
	await _umbra_reset(u, p)
	u.red_override = -1
	o = await _observe_umbra_move(u, UM.COMBO)
	check(bool(o["done"]) and int(o["strikes"]) == 3, "KOMBO: üç darbe (%d)" % int(o["strikes"]))
	check(bool(o["last_red"]), "KOMBO: sonuncusu kırmızı")
	u.red_override = 0
	# 3) FIRLATMA
	await _umbra_reset(u, p)
	o = await _observe_umbra_move(u, UM.THROW)
	check(bool(o["done"]) and (o["knives"] as Array).size() == 1, "FIRLATMA: 1 bıçak")
	# 4) ÜÇLÜ FIRLATMA
	await _umbra_reset(u, p)
	o = await _observe_umbra_move(u, UM.FAN)
	check(bool(o["done"]) and (o["knives"] as Array).size() == 3, "ÜÇLÜ FIRLATMA: 3 bıçak")
	# 5) DUVAR TIRMANIŞI
	await _umbra_reset(u, p)
	o = await _observe_umbra_move(u, UM.CLIMB)
	check(bool(o["done"]) and 612.0 - float(o["min_y"]) > 300.0 and float(o["gravity_min"]) == 0.0 and bool(o["armored"]), "TIRMANIŞ: yükseldi, yerçekimsiz, zırhlı")
	# 6) MİNYON ÇAĞIRMA
	await _umbra_reset(u, p)
	o = await _observe_umbra_move(u, UM.MINIONS)
	check(bool(o["done"]) and int(o["minions"]) == UmbraKit.minion_count(18, false), "MİNYON: %d minyon" % int(o["minions"]))
	# 7) SÜRÜ
	await _umbra_reset(u, p)
	o = await _observe_umbra_move(u, UM.SWARM)
	check(bool(o["done"]) and int(o["minions"]) == UmbraKit.minion_count(18, true), "SÜRÜ: %d minyon" % int(o["minions"]))
	# 8) GÖLGE ADIMI: kaybolur, işaret bırakır, arkandan vurur
	await _umbra_reset(u, p)
	var px := p.global_position.x
	o = await _observe_umbra_move(u, UM.BLINK)
	check(bool(o["done"]) and float(o["alpha_min"]) < 0.05 and bool(o["untouchable"]), "GÖLGE ADIMI: kayboldu, dokunulmaz")
	check(int(o["marks"]) >= 1 and int(o["strikes"]) == 1, "GÖLGE ADIMI: işaret bıraktı, çıkınca vurdu")
	check(not is_nan(float(o["knife_x"])) and absf(float(o["knife_x"]) - (px - Umbra.BLINK_OFFSET)) < 12.0, "GÖLGE ADIMI: oyuncunun ARKASINDA belirdi (x = %.0f)" % float(o["knife_x"]))
	check(u.collision_layer == Layers.ENEMY and u.visual_alpha == 1.0 and not u._untouchable, "GÖLGE ADIMI: bitince normale döndü")
	# 9) YER DARBESİ
	await _umbra_reset(u, p)
	o = await _observe_umbra_move(u, UM.SLAM)
	var sk := o["knives"] as Array
	check(bool(o["done"]) and 612.0 - float(o["min_y"]) > 150.0, "YER DARBESİ: zıpladı (%.0f px)" % (612.0 - float(o["min_y"])))
	check(sk.size() == 2 and not bool(sk[0]["parryable"]) and not bool(sk[1]["parryable"]) and float(sk[0]["vx"]) * float(sk[1]["vx"]) < 0.0, "YER DARBESİ: iki yana kırmızı şok dalgası")
	check(int(o["strikes"]) == 1 and bool(o["last_red"]), "YER DARBESİ: iniş darbesi kırmızı")
	# 10) BIÇAK YAĞMURU
	await _umbra_reset(u, p)
	o = await _observe_umbra_move(u, UM.RAIN)
	var rk := o["knives"] as Array
	check(bool(o["done"]) and int(o["marks"]) == UmbraKit.rain_count(18), "YAĞMUR: %d işaret" % int(o["marks"]))
	check(rk.size() == UmbraKit.rain_count(18), "YAĞMUR: %d bıçak düştü" % rk.size())
	var rain_ok := rk.size() > 0
	for k in rk:
		if bool(k["parryable"]) or float(k["vy"]) < 800.0 or absf(float(k["vx"])) > 0.01:
			rain_ok = false
	check(rain_ok, "YAĞMUR: bıçaklar dikey iniyor, kırmızı")
	# 11) DÖNEN BIÇAKLAR
	await _umbra_reset(u, p)
	o = await _observe_umbra_move(u, UM.ORBIT)
	check(bool(o["done"]) and int(o["blades"]) == UmbraKit.orbit_count(18), "DÖNEN BIÇAKLAR: %d bıçak" % int(o["blades"]))
	check(u._blades.is_empty(), "DÖNEN BIÇAKLAR: bitince kalkıyor")
	# 12) GİZLENME
	await _umbra_reset(u, p)
	o = await _observe_umbra_move(u, UM.CLOAK)
	check(bool(o["done"]) and float(o["alpha_min"]) <= Umbra.CLOAK_ALPHA + 0.01, "GİZLENME: neredeyse görünmez (%.2f)" % float(o["alpha_min"]))
	check(int(o["strikes"]) == 1, "GİZLENME: yaklaşıp sinsi bir darbe vurdu")
	check(u.visual_alpha == 1.0, "GİZLENME: bitince tamamen görünür")
	# 13) GÖLGE KLONU
	await _umbra_reset(u, p)
	o = await _observe_umbra_move(u, UM.CLONE)
	check(bool(o["done"]) and int(o["clones"]) == 1 and int(o["strikes"]) == 1, "KLON: bir klon, Gölge'nin kendi darbesi")
	# 14) KARŞI DURUŞ: beklersen altın bir darbe
	await _umbra_reset(u, p)
	o = await _observe_umbra_move(u, UM.COUNTER)
	check(bool(o["done"]) and bool(o["counter"]) and int(o["strikes"]) == 1 and not bool(o["last_red"]), "KARŞI DURUŞ: beklenirse yavaş ALTIN darbe")
	check(not u._counter_on, "KARŞI DURUŞ: duruş bitti")
	# 15) DUVARDAN ATIŞ
	await _umbra_reset(u, p)
	o = await _observe_umbra_move(u, UM.VOLLEY)
	check(bool(o["done"]) and (o["knives"] as Array).size() == 3, "DUVARDAN ATIŞ: 3 bıçak")
	check(not u.is_stunned() and u.gravity == u._base_gravity, "hamleler bitince Gölge sağlam ve yerçekimi normal")
	# Karşı duruşa vurmak: vuruş boşa gider, anında kırmızı karşılık
	await _umbra_reset(u, p)
	u.red_override = -1
	u.force_move(UM.COUNTER)
	await _frames(5)
	var hp := u.health
	check(not u.on_hit_by(_player_hitbox(p, u.global_position + Vector2(-30.0, 0.0))) and u.health == hp, "KARŞI DURUŞ: yakın vuruş boşa gitti (can aynı)")
	check(u.current_move == UM.KNIFE and u._red and u.tell_mode() == EnemyBase.Tell.RED and not u._counter_on, "KARŞI DURUŞ: anında KIRMIZI karşılık hazırlıyor")
	check(u._t < 0.25, "KARŞI DURUŞ: karşılık hızlı (%.2f sn)" % u._t)
	# Karşı duruş mermiye karşı koruma sağlamaz
	await _umbra_reset(u, p)
	u.force_move(UM.COUNTER)
	await _frames(5)
	var pr := _spawn_projectile(u.global_position + Vector2(-20.0, 0.0), Vector2.ZERO, false, p)
	pr.set_faction("player")
	hp = u.health
	check(u.on_hit_by(pr) and u.health < hp and u._counter_on, "KARŞI DURUŞ: mermi (sapan) duruşu deler, karşılık tetiklemez")
	# Dönen bıçak parry'lenince kırılır, sonra yenilenir
	await _umbra_reset(u, p)
	u.force_move(UM.ORBIT)
	await _wait_until(func() -> bool: return u._blades.size() == UmbraKit.orbit_count(18), 120)
	var pressed := false
	for i in 360:
		await get_tree().physics_frame
		if not pressed:
			for b in u._blades:
				if is_instance_valid(b) and not b.is_broken() and b.global_position.distance_to(p.global_position) < 58.0:
					p.intent.parry_pressed = true
					pressed = true
					break
		if _parry_ok > 0:
			break
	await _frames(2)
	var broken: UmbraBlade = null
	for b in u._blades:
		if is_instance_valid(b) and b.is_broken():
			broken = b
	check(_parry_ok >= 1 and broken != null, "dönen bıçak parry'lenince kırıldı")
	if broken != null:
		check(not broken.visible and not broken.active, "kırık bıçak görünmez ve etkisiz")
		for k in 8:
			broken._physics_process(0.5)
		check(not broken.is_broken() and broken.visible and broken.active, "birkaç sn sonra yenilendi")
	await _umbra_reset(u, p)


func _test_umbra_armor() -> void:
	await _new_world("Gölge: zırh (kat 8) hazırlığı bölünmez; poise (3 sersemletme = 1.5 sn zırh) sonsuz komboyu önler")
	var p := _spawn_player(500.0)
	p.health = 999
	# Kat 7: zırh yok -> vuruş hazırlığı iptal eder. Kat 8: zırh var -> vuruş can götürür ama hazırlık sürer.
	var res := {}
	for f in [7, 8]:
		var uf := _spawn_umbra(700.0, f)
		uf.red_override = 0
		await _frames(5)
		uf.force_move(UM.KNIFE)
		await _frames(3)
		var armored_in_tell := uf.armored
		var hp0 := uf.health
		var landed := uf.on_hit_by(_player_hitbox(p, uf.global_position + Vector2(-30.0, 0.0)))
		res[f] = {
			"armored": armored_in_tell, "landed": landed, "hurt": hp0 - uf.health,
			"kept": uf.current_move == UM.KNIFE, "knock": uf.knock_t,
		}
		if f == 8:
			var struck := await _wait_until(func() -> bool: return uf.attack_hitbox.active, 90)
			res[f]["struck"] = struck
		uf.queue_free()
		await _frames(3)
	check(not res[7]["armored"] and res[7]["landed"] and res[7]["hurt"] == 1 and not res[7]["kept"] and res[7]["knock"] > 0.0, "kat 7: zırhsız, vuruş hazırlığı iptal etti")
	check(res[8]["armored"] and res[8]["landed"] and res[8]["hurt"] == 1 and res[8]["kept"] and res[8]["knock"] == 0.0, "kat 8: ZIRHLI, vuruş hasar verdi ama hazırlığı bölmedi, geri itmedi")
	check(res[8]["struck"], "kat 8: darbe yine de geldi (zırh yalnız parry'ye açık)")
	# Zırhlı hazırlık yine de parry'lenince sersemler
	var u8 := _spawn_umbra(700.0, 8)
	u8.red_override = 0
	p.global_position.x = 600.0
	await _frames(5)
	u8.force_move(UM.KNIFE)
	var pressed := false
	for i in 200:
		await get_tree().physics_frame
		if not pressed and u8.stage == Umbra.K_STRIKE and u8.current_move == UM.KNIFE:
			p.intent.parry_pressed = true
			pressed = true
		if _parry_ok > 0:
			break
	await _frames(2)
	check(_parry_ok == 1 and u8.is_stunned() and not u8.armored, "zırh parry'ye karşı koruma sağlamaz: sersemledi, zırh düştü")
	u8.queue_free()
	await _frames(3)
	# Poise: kısa sürede 3 sersemletme -> 1.5 sn zırh + yakın dövüş
	var u := _spawn_umbra(700.0, 3)
	await _frames(5)
	var hits := 0
	for k in 3:
		u.stun_t = 0.0
		if u.on_hit_by(_player_hitbox(p, u.global_position + Vector2(-30.0, 0.0))):
			hits += 1
		if k < 2:
			u.knock_t = 0.0
	check(hits == 3, "üç vuruş da işledi")
	check(is_equal_approx(u._armor_t, Umbra.POISE_ARMOR) and u._force_melee and u._cooldown == 0.0 and u._poise_hits == 0, "3. sersemletme: 1.5 sn zırh + yakın dövüş zorlaması, sayaç sıfırlandı")
	await _frames(40)
	check(u.armored and u.knock_t <= 0.0, "sersemlik bitti, Gölge ZIRHLI")
	var hp := u.health
	check(u.on_hit_by(_player_hitbox(p, u.global_position + Vector2(-30.0, 0.0))) and u.health == hp - 1 and u.knock_t <= 0.0, "zırhlıyken vuruş can götürür ama sersemletmez (sonsuz kombo yok)")
	var armor_gone := await _wait_until(func() -> bool: return not u.armored, 200)
	check(armor_gone, "1.5 sn sonra zırh kalktı")
	u.knock_t = 0.0
	check(u.on_hit_by(_player_hitbox(p, u.global_position + Vector2(-30.0, 0.0))) and u.knock_t > 0.0, "zırh bitince yeniden sersemletilebilir")
	# Poise hafızası: vuruşlar 1.6 sn'den seyrek gelirse birikmez
	u.knock_t = 0.0
	u._poise_hits = 0
	u._poise_t = 0.0
	u._force_melee = false
	u._armor_t = 0.0
	u.on_hit_by(_player_hitbox(p, u.global_position + Vector2(-30.0, 0.0)))
	check(u._poise_hits == 1, "bir sersemletme sayıldı")
	u.knock_t = 0.0
	await _frames(120)
	check(u._poise_hits == 0, "1.6 sn geçince sayaç sıfırlandı")


func _test_umbra_second_wind() -> void:
	await _new_world("Gölge: ikinci nefes (kat 15) ve gerçek dövüşün ikinci evresi (kat 18)")
	var p := _spawn_player(300.0)
	p.health = 999
	var phases := []
	var cbp := func(b: Node, ph: int) -> void: phases.append([b, ph])
	EventBus.boss_phase.connect(cbp)
	var defeated := []
	var cbd := func(b: Node) -> void: defeated.append(b)
	EventBus.boss_defeated.connect(cbd)
	# Kat 14: ikinci nefes yok: can bitince ölür
	var u14 := _spawn_umbra(900.0, 14)
	await _frames(5)
	u14.take_damage(u14.max_hp, p)
	await _frames(2)
	check(u14.dead and defeated.size() == 1 and defeated[0] == u14 and phases.is_empty(), "kat 14: can bitince ölür (evre sinyali yok)")
	# Kat 15: ikinci nefes
	var u := _spawn_umbra(1100.0, 15)
	await _frames(5)
	u.take_damage(u.max_hp, p)
	await _frames(2)
	check(not u.dead and u.current_move == UM.WIND and u.phase == 2, "kat 15: ölmedi, soluklanıyor, evre 2")
	check(u.health == roundi(float(u.max_hp) * 0.3), "canı %%30'a döndü (%d / %d)" % [u.health, u.max_hp])
	check(u._untouchable and u.armored and not u.on_hit_by(_player_hitbox(p, u.global_position)), "kükrerken dokunulmaz ve vurulamaz")
	check(phases.size() == 1 and phases[0][0] == u and phases[0][1] == 2, "boss_phase(2) tam bir kez")
	check(defeated.size() == 1, "henüz yenilmedi (boss_defeated gelmedi)")
	var ph_hp := u.health
	await _frames(30)
	check(u.health == ph_hp, "kükreme sürerken can sabit")
	var calm := await _wait_until(func() -> bool: return u.is_idle(), 140)
	check(calm and not u._untouchable and not u.armored, "kükreme bitti: vurulabilir, zırhsız")
	check(is_equal_approx(u._spd(), 150.0 * UmbraKit.speed_mult(15) * Umbra.PHASE2_SPEED), "evre 2: %%%d daha hızlı" % roundi((Umbra.PHASE2_SPEED - 1.0) * 100.0))
	u.take_damage(u.max_hp, p)
	await _frames(2)
	check(u.dead and defeated.size() == 2 and defeated[1] == u, "ikinci kez can bitince ÖLDÜ (ikinci nefes tek sefer)")
	check(phases.size() == 1, "evre sinyali tekrarlanmadı")
	# Kat 17: gerçek dövüş yok: yarı canda evre değişmez
	var u17 := _spawn_umbra(1300.0, 17)
	await _frames(5)
	u17.take_damage(u17.max_hp / 2 + 2, p)
	await _frames(10)
	check(u17.phase == 1 and u17.current_move != UM.WIND, "kat 17: yarı canda evre değişmez")
	# Kat 18: yarı canda ikinci evre (kükreme), ölümde ikinci nefes
	var u18 := _spawn_umbra(1500.0, 18)
	await _frames(5)
	var half := u18.max_hp - u18.max_hp / 2
	u18.take_damage(half - 1, p)
	await _frames(6)
	check(u18.phase == 1, "kat 18: yarıdan önce evre 1 (%d / %d)" % [u18.health, u18.max_hp])
	u18.take_damage(1, p)
	await _frames(6)
	check(u18.phase == 2 and u18.current_move == UM.WIND, "kat 18: canı yarıya inince KÜKREDİ, evre 2")
	check(phases.size() == 2 and phases[1][0] == u18 and phases[1][1] == 2, "boss_phase(2) kat 18 için")
	check(u18.health == u18.max_hp - half, "öfke canı yenilemez (yalnız ikinci nefes yeniler)")
	await _wait_until(func() -> bool: return u18.is_idle(), 140)
	u18.take_damage(u18.max_hp, p)
	await _frames(3)
	check(not u18.dead and u18.health == roundi(float(u18.max_hp) * 0.3) and u18.phase == 2, "kat 18: öldü sanılınca ikinci nefes (evre zaten 2)")
	check(phases.size() == 2, "evre 2 yeniden duyurulmadı")
	EventBus.boss_phase.disconnect(cbp)
	EventBus.boss_defeated.disconnect(cbd)


func _test_umbra_death() -> void:
	await _new_world("Gölge: ölünce her şey temizlenir (bıçak, işaret, minyon, dönen bıçak), boss_defeated, gruplar")
	_add_walls(100.0, 1500.0)
	var p := _spawn_player(500.0)
	p.health = 999
	var defeated := []
	var cbd := func(b: Node) -> void: defeated.append(b)
	EventBus.boss_defeated.connect(cbd)
	var died := []
	var cbe := func(e: Node) -> void: died.append(e)
	EventBus.enemy_died.connect(cbe)
	var u := _spawn_umbra(900.0, 12)
	await _frames(10)
	# Minyonlar + havada bıçak + yağmur işaretleri + dönen bıçaklar
	u.force_move(UM.SWARM)
	await _wait_until(func() -> bool: return u.minion_count() >= 3, 150)
	u.force_move(UM.THROW)
	await _wait_until(func() -> bool: return u._own_projectiles() >= 1, 120)
	u.force_move(UM.RAIN)
	await _wait_until(func() -> bool: return _count_marks() >= 3, 120)
	u.force_move(UM.ORBIT)
	await _wait_until(func() -> bool: return u._blades.size() >= 2, 120)
	var had_minions := u.minion_count()
	check(had_minions >= 3 and not u._blades.is_empty(), "ölüm öncesi sahne dolu (%d minyon, %d dönen bıçak)" % [had_minions, u._blades.size()])
	u.take_damage(u.max_hp, p)
	await _frames(3)
	check(u.dead and not u.is_in_group("enemies"), "Gölge öldü ve düşman sayılmıyor")
	check(defeated.size() == 1 and defeated[0] == u, "boss_defeated tam bir kez")
	check(died.has(u), "enemy_died de geldi (kat/oda sayaçları için)")
	check(u.minion_count() == 0, "minyonlar eridi")
	check(u._blades.is_empty() and not u.attack_hitbox.active, "dönen bıçaklar ve saldırı alanı kapandı")
	await _frames(4)
	check(_umbra_knives(u).is_empty(), "Gölge'nin bıçakları silindi")
	check(_count_marks() == 0, "yağmur işaretleri silindi")
	var left_alive := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e as ActorBase).dead:
			left_alive += 1
	check(left_alive == 0, "sahnede canlı düşman kalmadı (oda temizlenebilir)")
	EventBus.boss_defeated.disconnect(cbd)
	EventBus.enemy_died.disconnect(cbe)


func _test_umbra_bar() -> void:
	await _new_world("Gölge: üstteki can barı (bağlanma, dolgu, hayalet şerit, öfke, çentik, ölünce söner)")
	var p := _spawn_player(300.0)
	p.health = 999
	var bar := BossBar.new()
	bar.set_process(false)  # zamanı biz veririz
	_world.add_child(bar)
	check(not bar.is_active() and bar.boss == null, "Gölge yokken bar görünmez")
	var u := _spawn_umbra(900.0, 5)
	check(bar.boss == u and is_equal_approx(bar.fraction(), 1.0) and not bar.is_enraged(), "boss_spawned barı Gölge'ye bağladı: dolu, öfkesiz")
	check(not bar.is_active(), "belirmeden önce görünmez")
	bar._process(0.3)
	check(bar.is_active(), "bar belirmeye başladı")
	bar._process(0.5)
	var full := u.max_hp
	u.take_damage(10, p)
	bar._process(1.0 / 60.0)
	check(is_equal_approx(bar.fraction(), float(full - 10) / float(full)), "hasarla dolgu azaldı (%.3f)" % bar.fraction())
	check(bar._ghost > bar._frac, "hayalet şerit hasarın arkasında kaldı")
	for i in 150:
		bar._process(1.0 / 60.0)
	check(is_equal_approx(bar._ghost, bar._frac), "hayalet şerit eridi")
	check(not bar._real, "kat 5: yarı çentik yok")
	EventBus.boss_phase.emit(u, 2)
	check(bar.is_enraged() and bar._flash > 0.0, "evre 2: bar öfkeli (kırmızı) ve parladı")
	# Gerçek dövüş: çentik, ikinci nefeste bar yukarı dolar
	var u15 := _spawn_umbra(1300.0, 15)
	check(bar.boss == u15 and not bar.is_enraged(), "yeni Gölge barı yeniden bağladı, öfke sıfırlandı")
	bar._process(0.8)
	u15.take_damage(u15.max_hp, p)
	bar._process(1.0 / 60.0)
	check(not u15.dead and bar.fraction() > 0.25 and bar.fraction() < 0.35, "ikinci nefesten sonra bar %%30 civarında (%.2f)" % bar.fraction())
	check(bar.is_enraged(), "ikinci nefes evre 2 yaptı: bar kırmızı")
	var u18 := _spawn_umbra(1500.0, 18)
	check(bar.boss == u18 and bar._real, "kat 18: bar yarı çentikli")
	# Ölüm: bir süre kalır, sonra söner
	bar._process(0.8)
	u18.take_damage(u18.max_hp, p)
	u18.take_damage(u18.max_hp, p)
	check(u18.dead and bar.boss == null and is_equal_approx(bar.fraction(), 0.0), "ölünce bar boşaldı ve Gölge'den ayrıldı")
	bar._process(0.5)
	check(bar.is_active(), "ölümden hemen sonra bar kısa süre ekranda")
	for i in 5:
		bar._process(0.5)
	check(not bar.is_active(), "birkaç sn sonra bar söndü")
	# Silinen Gölge: bar takılı kalmaz
	var u2 := _spawn_umbra(700.0, 2)
	bar._process(0.8)
	check(bar.is_active() and bar.boss == u2, "yeni Gölge: bar yeniden çıktı")
	u2.free()
	bar._process(0.1)
	check(bar.boss == null, "Gölge sahneden silinirse bar ondan kopar")
	bar.queue_free()


func _test_umbra_brain() -> void:
	await _new_world("Gölge: oyuncuya yaklaşır, mesafe tutar, kendi başına hamle seçer, boş parry'yi cezalandırır")
	_add_walls(100.0, 1500.0)
	var p := _spawn_player(500.0)
	p.health = 999
	# Yaklaşma
	var u := _spawn_umbra(1300.0, 1)
	await _frames(10)
	var x0 := u.global_position.x
	await _frames(300)
	var d := absf(u.global_position.x - p.global_position.x)
	check(u.global_position.x < x0 - 300.0, "oyuncuya doğru yürüdü")
	check(d > Umbra.PREFERRED_DIST - 80.0 and d < Umbra.PREFERRED_DIST + 45.0, "tercih ettiği mesafede durdu (%.0f px)" % d)
	check(u.facing == -1, "oyuncuya dönük")
	# Çok yakındaysa geri çekilir
	u.global_position.x = p.global_position.x + 40.0
	await _frames(100)
	d = absf(u.global_position.x - p.global_position.x)
	check(d > 80.0, "fazla yakınsa geri çekildi (%.0f px)" % d)
	# Kendi başına hamle seçer; yalnız açık hamleleri yapar
	await _new_world("Gölge: kendi başına hamle yapar (kat 4: bıçak, fırlatma, tırmanış, minyon)")
	_add_walls(100.0, 1500.0)
	p = _spawn_player(500.0)
	p.health = 999
	u = _spawn_umbra(1000.0, 4, null, true)
	u._rng.seed = 424242
	u._cooldown = 0.2
	var moves := []
	u.move_started.connect(func(m: int) -> void: moves.append(m))
	await _frames(900)
	check(moves.size() >= 3, "15 sn'de en az 3 hamle yaptı (%d)" % moves.size())
	var legal := true
	for m in moves:
		if not (m in UmbraKit.moves_for(4)):
			legal = false
	check(legal, "yalnız kat 4'ün açık hamlelerini yaptı: %s" % str(moves))
	var distinct := {}
	for m in moves:
		distinct[m] = true
	check(distinct.size() >= 2, "farklı hamleler seçti (%d tür)" % distinct.size())
	check(p.health > 0, "oyuncu hayatta")
	# CEZA: oyuncu parry'yi ıskalarsa (toparlanırken) Gölge hemen, kısa uyarıyla yakından vurur
	await _new_world("Gölge: boş parry'yi cezalandırır (kısaltılmış uyarıyla yakın dövüş)")
	p = _spawn_player(600.0)
	p.health = 999
	u = _spawn_umbra(730.0, 5)
	u.tuning.punish = 1.0
	u.abilities = [UM.KNIFE]
	u.red_override = 0
	await _frames(10)
	var punished := false
	var tele := 9.0
	for attempt in 6:
		u._cooldown = 999.0
		u._quick = false
		u._force_melee = false
		p.invulnerable_t = 0.0
		p.intent.parry_pressed = true
		var got_punish := await _wait_until(func() -> bool: return u.current_move == UM.KNIFE, 40)
		if got_punish:
			punished = true
			tele = u._t
			break
		await _frames(40)
	check(punished, "boş parry'nin ardından Gölge hemen saldırdı")
	check(tele < 0.46, "uyarı kısaltıldı (%.2f sn, normalde ~0.62)" % tele)


func _run_to_boss_room(run: RunController, floor_no: int) -> Room:
	if floor_no > 1:
		run.current = FloorPlan.index_of(floor_no - 1, 5)
		run.dev_next_floor()
	for k in 5:
		await _frames(3)
		if k > 0:
			var room := run.current_room()
			# Dalganın hepsi doğsun (bekleyen işaret kalmasın); yoksa geç doğanlar sonraki odaya sızar.
			await _wait_until(func() -> bool: return room.pending_count() == 0 and room.alive_count() > 0, 400)
			run.skip_room()
			await _frames(3)
		await _walk_to_next_room(run)
	return run.current_room()


func _test_umbra_room() -> void:
	await _new_world("Gölge: kat entegrasyonu (kat 3 Gölge odası: bar, duyuru, ölçek, kendi hamleleri, ölünce geçit)")
	GameState.god_mode = false
	TimeStop.reset()
	ItemView.active_menu = null
	GameState.umbra_items.clear()
	var run := _start_run(777, true)
	var p := run.player
	await _frames(5)
	var boss_room := await _run_to_boss_room(run, 3)
	check(boss_room.kind == FloorPlan.Kind.BOSS and boss_room.floor_no == 3 and run.current_floor() == 3, "kat 3'ün Gölge odasındayız")
	var spawned := await _wait_until(func() -> bool: return boss_room.alive_count() >= 1, 360)
	check(spawned and boss_room.alive_count() == 1, "Gölge doğdu (tek düşman)")
	var u: Umbra = null
	for e in get_tree().get_nodes_in_group("boss"):
		u = e as Umbra
	check(u != null and u.floor_no == 3 and u.is_in_group("enemies"), "doğan Gölge kat 3'ün Gölge'si")
	if u == null:
		run.queue_free()
		await _frames(2)
		return
	var tuning := run.tuning_for(run.current)
	check(u.max_hp == tuning.scale_hp(UmbraKit.hp_for(3, 30)), "can = kat ölçeği x tur ölçeği (%d)" % u.max_hp)
	check(u.abilities == [UM.KNIFE, UM.THROW, UM.CLIMB], "kat 3: bıçak + fırlatma + duvar tırmanışı")
	check(run.hud.boss_bar.boss == u, "HUD'daki boss barı Gölge'ye bağlandı")
	var shown := await _wait_until(func() -> bool: return run.hud.boss_bar.is_active(), 120)
	check(shown, "boss barı ekranda")
	var announced := false
	for it in run.hud.announcer._items:
		var line := ""
		for part in it["runs"]:
			line += str(part[0])
		if line.contains("YENİ YETENEK") and line.contains("DUVAR TIRMANIŞI"):
			announced = true
	check(announced, "yeni yetenek duyurusu çıktı (YENİ YETENEK  DUVAR TIRMANIŞI)")
	check(boss_room.floor_exit != null and boss_room.floor_exit.state == FloorExit.State.CLOSED, "Gölge yaşarken geçit kapalı")
	# Kendi başına hamle yapıyor mu?
	var moves := []
	u.move_started.connect(func(m: int) -> void: moves.append(m))
	var acted := await _wait_until(func() -> bool: return moves.size() >= 1, 900)
	check(acted and moves[0] in UmbraKit.moves_for(3), "Gölge kendi başına hamle yaptı (%s)" % str(moves))
	# Gerçek yoldan öldür: oda temizlenir, geçit açılır
	var kills_before := int(run.stats["kills"])
	u.take_damage(u.max_hp, p)
	var cleared := await _wait_until(func() -> bool: return boss_room.is_cleared(), 120)
	check(cleared and (not is_instance_valid(u) or u.dead), "Gölge ölünce oda temizlendi")
	check(int(run.stats["kills"]) == kills_before + 1, "öldürme sayıldı")
	check(run.hud.boss_bar.boss == null, "bar Gölge'den ayrıldı")
	await _frames(int(FloorExit.OPEN_TIME * 60.0) + 12)
	check(boss_room.floor_exit.is_open(), "kat geçidi açıldı")
	run.queue_free()
	await _frames(2)
