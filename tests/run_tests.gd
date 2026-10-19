extends Node
## Başsız (headless) oyun testleri.
## Çalıştırma:
##   godot --headless --fixed-fps 60 --path . res://tests/test_runner.tscn
## Hata varsa çıkış kodu 0'dan farklı olur.

const PLAYER := preload("res://actors/player/player.tscn")
const PROJECTILE := preload("res://combat/projectile.tscn")
const SHOOTER := preload("res://actors/enemies/shooter.tscn")
const BIDDER := preload("res://actors/enemies/bidder.tscn")

var _checks := 0
var _fails := 0
var _world: Node2D
var _parry_ok := 0
var _parry_fail := 0
var _kills := 0


func _ready() -> void:
	_run_all()


func _run_all() -> void:
	Hitstop.enabled = false
	EventBus.parry_success.connect(func(_a: Node, _b: Node) -> void: _parry_ok += 1)
	EventBus.parry_failed.connect(func(_a: Node) -> void: _parry_fail += 1)
	EventBus.enemy_died.connect(func(_e: Node) -> void: _kills += 1)

	_test_stats()
	await _test_movement()
	await _test_jump()
	await _test_dash()
	await _test_parry_success()
	await _test_parry_early_and_iframes()
	await _test_red_projectile()
	await _test_dash_through_projectile()
	await _test_melee_combo_and_kill()
	await _test_bidder_lunge_parry()
	await _test_bidder_red_lunge_and_death()
	await _test_shooter_cadence()

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


func _test_melee_combo_and_kill() -> void:
	await _new_world("Yakın dövüş kombosu ve öldürme")
	var p := _spawn_player()
	var b := BIDDER.instantiate() as Bidder
	b.set_physics_process(false)  # sabit hedef
	_world.add_child(b)
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
