extends Node
## Başsız (headless) oyun testleri.
## Çalıştırma:
##   godot --headless --fixed-fps 60 --path . res://tests/test_runner.tscn
## Hata varsa çıkış kodu 0'dan farklı olur.

const PLAYER := preload("res://actors/player/player.tscn")
const PROJECTILE := preload("res://combat/projectile.tscn")
const SHOOTER := preload("res://actors/enemies/shooter.tscn")
const BIDDER := preload("res://actors/enemies/bidder.tscn")
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
		"teklifci_parry": _test_bidder_lunge_parry,
		"teklifci_kirmizi": _test_bidder_red_lunge_and_death,
		"atesci": _test_shooter_cadence,
		"vurus_geri_bildirim": _test_hit_feedback,
		"kamera": _test_camera_fx,
		"kamera_takip": _test_camera_follow,
		"kamera_sinir": _test_camera_bounds,
		"kamera_tepki": _test_camera_reactions,
		"kamera_dikey": _test_camera_vertical,
		"kamera_oda_gecis": _test_camera_room_transition,
		"oda_yerlesim": _test_room_layouts,
		"oda_dalga": _test_run_waves,
		"oda_akis": _test_run_flow,
		"oda_dalga_akis": _test_run_wave_progression,
		"oda_olum": _test_run_death,
		"ekran_flas": _test_screen_flash,
		"platform_cik": _test_bidder_climbs_platform,
		"platform_in": _test_bidder_descends_platform,
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
	var e := BIDDER.instantiate() as Bidder
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
	var e := BIDDER.instantiate() as Bidder
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
	var b := BIDDER.instantiate() as Bidder
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


func _test_bidder_lunge_parry() -> void:
	await _new_world("Teklifçi: altın atılma parry'lenince sersemler")
	var p := _spawn_player()
	var b := BIDDER.instantiate() as Bidder
	b.red_chance = 0.0
	_world.add_child(b)
	b.global_position = Vector2(830, 612)
	await _frames(20)
	var hp0 := p.health
	var pressed := false
	for i in 300:
		await get_tree().physics_frame
		if not pressed and b._phase == Bidder.Phase.LUNGE and b.global_position.x - p.global_position.x < 120.0:
			p.intent.parry_pressed = true
			pressed = true
		if _parry_ok > 0:
			break
	await _frames(2)
	check(pressed, "teklifçi atıldı")
	check(_parry_ok == 1, "atılma parry'lendi")
	check(p.health == hp0, "can kaybı yok")
	check(b.is_stunned(), "teklifçi sersemledi")
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


func _test_bidder_red_lunge_and_death() -> void:
	await _new_world("Teklifçi: kırmızı atılma parry'lenemez, ölüm")
	var p := _spawn_player()
	var b := BIDDER.instantiate() as Bidder
	b.red_chance = 1.0
	_world.add_child(b)
	b.global_position = Vector2(830, 612)
	await _frames(20)
	var hp0 := p.health
	var pressed := false
	for i in 300:
		await get_tree().physics_frame
		if not pressed and b._phase == Bidder.Phase.LUNGE and b.global_position.x - p.global_position.x < 120.0:
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
	b._phase = Bidder.Phase.CHASE
	b._cooldown = 0.0
	b.stun_t = 0.0
	b.knock_t = 0.0
	for i in 400:
		await get_tree().physics_frame
		if p.dead:
			break
	check(p.dead, "can bitince oyuncu öldü")
	check(p.state == Player.State.DEAD, "ölüm durumuna geçti")


func _test_shooter_cadence() -> void:
	await _new_world("Ateşçi: mermi ritmi (her 3. mermi kırmızı)")
	var p := _spawn_player()
	p.health = 999
	var s := SHOOTER.instantiate() as Shooter
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
	check(seen.size() >= 3, "ateşçi mermi attı (%d adet)" % seen.size())
	if seen.size() >= 3:
		check(colors[0] and colors[1] and not colors[2], "ilk iki altın, üçüncü kırmızı %s" % str(colors))


func _count_sparks() -> int:
	var n := 0
	for c in _world.get_children():
		if c is HitSpark:
			n += 1
	return n


func _test_hit_feedback() -> void:
	await _new_world("Vuruş geri bildirimi: flash + kıvılcım")
	var p := _spawn_player()
	var b := BIDDER.instantiate() as Bidder
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
	var e := BIDDER.instantiate() as Bidder
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
	var bidders := (w0[0] as Array).count(BIDDER)
	var shooters := (w0[0] as Array).count(SHOOTER)
	check(w0.size() == 1 and bidders == 1 and shooters == 1, "ilk odada bir Teklifçi + bir Ateşçi (%d/%d)" % [bidders, shooters])
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


func _test_bidder_climbs_platform() -> void:
	await _new_world("Teklifçi: üst platformdaki oyuncuya zıplayıp çıkar")
	_add_platform(PLATFORM_RECT)
	var p := _spawn_player(500.0)
	p.health = 999
	p.global_position = Vector2(500, 490.0 - 26.0)
	var b := BIDDER.instantiate() as Bidder
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
		if b.is_on_floor() and b.feet_y() > 600.0 and b._phase != Bidder.Phase.CHASE:
			lunged_below = true  # altından boşuna saldırmaya çalıştı
		if not b.is_on_floor() and b.velocity.y < -200.0:
			jumped = true
		if b.is_on_floor() and b.feet_y() < 500.0:
			reached = true
			break
	check(not lunged_below, "altındayken boşuna saldırı başlatmadı")
	check(jumped, "zıpladı")
	check(reached, "platformun üstüne çıktı (ayak y=%.0f)" % b.feet_y())


func _test_bidder_descends_platform() -> void:
	await _new_world("Teklifçi: platformdan, altındaki oyuncuya iner")
	_add_platform(PLATFORM_RECT)
	var p := _spawn_player(500.0)
	p.health = 999
	var b := BIDDER.instantiate() as Bidder
	b.red_chance = 0.0
	_world.add_child(b)
	b.global_position = Vector2(500, 490.0 - 27.0)
	await _frames(20)
	check(b.is_on_floor() and b.feet_y() < 495.0, "teklifçi platformda başladı")
	var landed := false
	for i in 600:
		await get_tree().physics_frame
		if b.is_on_floor() and b.feet_y() > 630.0:
			landed = true
			break
	check(landed, "kenardan yürüyüp zemine indi (ayak y=%.0f)" % b.feet_y())


func _test_shot_passes_platform() -> void:
	await _new_world("Ateşçi: mermi platformdan geçip üstteki oyuncuya ulaşır")
	_add_platform(PLATFORM_RECT)
	var p := _spawn_player(500.0)
	p.health = 50
	p.global_position = Vector2(500, 490.0 - 26.0)
	var s := SHOOTER.instantiate() as Shooter
	_world.add_child(s)
	s.global_position = Vector2(560, 615)
	await _frames(20)
	var hit := false
	for i in 1500:
		await get_tree().physics_frame
		if p.health < 50:
			hit = true
			break
	check(hit, "alttaki ateşçinin mermisi platformdan geçip oyuncuya çarptı")


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
	var sf := SpriteSetLoader.build("res://assets/sprites/player", Player.ANIM_SPEC)
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
	var b := BIDDER.instantiate() as Bidder
	_world.add_child(b)
	b.global_position = Vector2(900, 613)
	await _frames(20)
	b.anim.use_frames(_fake_frames(["idle", "run", "telegraph", "attack", "recover"] as Array[String]))
	check(b.pick_animation() == "idle" or b.pick_animation() == "run", "teklifçi yürürken idle/run (%s)" % b.pick_animation())
	b._phase = Bidder.Phase.TELEGRAPH
	check(b.pick_animation() == "telegraph", "teklifçi hazırlanırken telegraph")
	b._phase = Bidder.Phase.LUNGE
	check(b.pick_animation() == "attack", "teklifçi atılırken attack")
	b._phase = Bidder.Phase.RECOVER
	check(b.pick_animation() == "recover", "teklifçi toparlanırken recover")


# ------------------------------------------------------------------ font, hasar sayıları, kombo

func _spawn_dummy_enemy(x: float, hp: int = 50) -> EnemyBase:
	var e := BIDDER.instantiate() as EnemyBase
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

