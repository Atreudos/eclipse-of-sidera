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

var _checks := 0
var _fails := 0
var _world: Node2D
var _parry_ok := 0
var _parry_fail := 0
var _kills := 0


var _start_msec := 0


func _ready() -> void:
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
	_world = Node2D.new()
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
	cam.set_process(false)
	_world.add_child(cam)
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
func _start_run(seed_value: int) -> RunController:
	var run := RUN.instantiate() as RunController
	run.seed_value = seed_value
	var p := run.get_node("Player") as Player
	p.scripted = true
	# Kamera gerçek saatle akar; testte süreyi biz veririz (_cam_run).
	(run.get_node("Camera") as ShakeCamera).set_process(false)
	_world.add_child(run)
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
	a.run_seed = 4242
	var b := RunController.new()
	b.run_seed = 4242
	var c := RunController.new()
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
	print("\nFont (AGENTORANGE)")
	check(ResourceLoader.exists(GameFont.PATH), "font dosyası projede ve içe aktarılmış")
	var f := GameFont.get_font()
	check(f != null and f != ThemeDB.fallback_font, "oyun fontu yüklendi (yedek font değil)")
	var tr_ok := true
	for ch in "çğıöşüÇĞİÖŞÜ":
		if not f.has_char(ch.unicode_at(0)):
			tr_ok = false
	check(tr_ok, "Türkçe harflerin hepsi fontta var")
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
	check(all.size() == 13, "10 donanım + 3 yemek = 13 eşya (%d)" % all.size())
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
		"thief_chain": S.WRIST,
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
	check(gear.size() == 10 and no_food, "donanım havuzu 10 eşya, yemek yok")
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
