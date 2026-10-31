class_name EnemyBase
extends ActorBase
## Düşman tabanı: yerçekimi, geri itilme, sersemleme (stun), ölüm efekti, "tell" (uyarı) parlaması,
## animasyon ve (istenirse) platformlara zıplayarak çıkma.
## Saldırı renkleri: ALTIN = parry'lenebilir, KIRMIZI = kaçman gerekir.
##
## Her düşman ailesi yüksekliğe KENDİ yöntemiyle cevap verir:
##   Taurus: zıplayıp platforma çıkar.  Sagitta: çıkmaz, yukarıya ateş eder.  Scorpius: kılıç mesafesini korur.
##
## VURULUNCA: zırhsız düşmanın hazırladığı/yaptığı saldırı İPTAL olur (`stagger`), kısa süre savunmasız kalır.
## Böylece 3'lü kombo kesintisiz akar: kombo yaparken düşman sana saldıramaz.

enum Tell { NONE, GOLD, RED }

const GOLD := Color(1.0, 0.8, 0.2)
const RED := Color(1.0, 0.22, 0.22)
## Başına konulan oyuncudan kayma hızı (px/sn).
const SLIDE_OFF_SPEED := 220.0
## Vuruşla sersemleme süreleri (sn). Hafif vuruş, oyuncunun kombo hızından (~0.28 sn) uzun sürer ki zincir kopmasın;
## ağır vuruş (hasar >= 2: 3. vuruş, parry sonrası güçlü vuruş, ritim bonusu) daha uzun sürer.
const STAGGER_LIGHT := 0.36
const STAGGER_HEAVY := 0.6
## Sarı parry sembolünün belirme süresi (sn).
const TELL_POP_TIME := 0.18

# Düşman animasyonları (PNG'ler assets/sprites/<düşman>/ içine konunca otomatik kullanılır).
const ANIM_SPEC := {
	"idle": {"fps": 8.0, "loop": true},
	"run": {"fps": 10.0, "loop": true, "fallback": "idle"},
	"jump": {"fps": 10.0, "loop": false, "fallback": "idle"},
	"fall": {"fps": 10.0, "loop": true, "fallback": "jump"},
	"telegraph": {"fps": 12.0, "loop": false, "fallback": "idle"},
	"attack": {"fps": 14.0, "loop": false, "fallback": "telegraph"},
	"recover": {"fps": 10.0, "loop": false, "fallback": "idle"},
	"stun": {"fps": 8.0, "loop": true, "fallback": "hurt"},
	"hurt": {"fps": 12.0, "loop": false, "fallback": "idle"},
	"death": {"fps": 10.0, "loop": false, "fallback": "hurt"},
}

@export var max_hp: int = 3
## Ölünce düşen altın (min..max, rastgele).
@export var gold_min := 1
@export var gold_max := 3
@export var gravity := 1900.0
@export var knockback_force := 240.0
## > 0 ise platformlara zıplayabilir (piksel/sn). Zıplama yüksekliği = v² / (2 * gravity).
@export var jump_velocity := 0.0
@export var air_speed := 150.0

## Doğarken uygulanan zorluk + tur ayarı (null = ayarsız: düşman eskisi gibi davranır). `_ready`'den ÖNCE verilmelidir
## (SpawnMarker ağaca eklemeden önce verir). Bkz. Difficulty ve EnemyScaling.
var tuning: EnemyTuning = null
var target: Player = null
var facing := -1
var stun_t := 0.0
var knock_t := 0.0
## true iken vuruşla geri itilmez ve saldırısı bölünmez ("süper zırh"; ileride zırhlı düşmanlar için).
## Taurus/Sagitta/Scorpius zırhsızdır: vurulunca saldırıları iptal olur.
var armored := false
var nav: PlatformNav

var _tell := Tell.NONE
## Uyarı başlayalı geçen süre (görsel animasyon için).
var _tell_age := 0.0
## Görünürlük çarpanı (0 = görünmez). Scorpius'un gölge adımı kullanır.
var visual_alpha := 1.0
## Yanma: kalan süre ve bir sonraki hasar tiki.
var burn_t := 0.0
var _burn_tick := 0.0
## Zehir (Engerek Dişi Kolyesi): kalan süre, saniyedeki hasar ve biriken kesir.
var poison_t := 0.0
var poison_dps := 0.0
var _poison_acc := 0.0

const BURN_INTERVAL := 0.6
const BURN_COLOR := Color(1.0, 0.55, 0.15)
const POISON_COLOR := Color(0.55, 1.0, 0.4)

@onready var tell_glow: ColorRect = get_node_or_null("Visual/Glow")
@onready var hurtbox: Hurtbox = get_node_or_null("Hurtbox")


func anim_spec() -> Dictionary:
	return ANIM_SPEC


func _ready() -> void:
	super._ready()
	faction = "enemy"
	if tuning == null:
		tuning = EnemyTuning.new()  # etkisiz ayar
	max_hp = tuning.scale_hp(max_hp)
	gold_min = tuning.scale_gold(gold_min)
	gold_max = tuning.scale_gold(gold_max)
	stats = Stats.new({"max_health": float(max_hp)})
	health = max_hp
	nav = PlatformNav.new(self)
	add_to_group("enemies")
	set_tell(Tell.NONE)
	_apply_tuning()


func max_jump_height() -> float:
	return jump_velocity * jump_velocity / (2.0 * gravity)


func _physics_process(delta: float) -> void:
	if dead or TimeStop.active:
		return  # zaman durduysa düşman donar (Satürn'ün Kum Saati)
	_find_target()
	_tick_burn(delta)
	_tick_poison(delta)
	if dead:
		return
	velocity.y = minf(velocity.y + gravity * delta, 1200.0)
	var frozen := false
	var brake := 2400.0
	if knock_t > 0.0:
		knock_t -= delta
		frozen = true
		brake = 1800.0
	if stun_t > 0.0:
		stun_t -= delta
		frozen = true
		if stun_t <= 0.0:
			_on_stun_end()
	if frozen:
		velocity.x = move_toward(velocity.x, 0.0, brake * delta)
	else:
		_ai(delta)
	move_and_slide()
	_slide_off_player()


## Oyuncunun başına konduysak yana kay (gövdeler katı olduğu için üstünde asılı kalmasın).
func _slide_off_player() -> void:
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		if col.get_collider() is Player and col.get_normal().y < -0.6:
			var dir := signf(global_position.x - (col.get_collider() as Node2D).global_position.x)
			velocity.x = (dir if dir != 0.0 else 1.0) * SLIDE_OFF_SPEED
			return


func _process(delta: float) -> void:
	if visual != null:
		# Sprite ve yer tutucular SAĞA bakacak şekilde çizilir; facing = -1 aynalar.
		(visual as Node2D).scale.x = facing if facing != 0 else 1
	if _tell != Tell.NONE:
		_tell_age += delta
		if tell_glow != null:
			tell_glow.modulate.a = 0.7 + 0.25 * sin(Time.get_ticks_msec() / 45.0)
		queue_redraw()
	tint = Color(0.6, 0.8, 1.0) if stun_t > 0.0 else Color.WHITE
	if burn_t > 0.0 and stun_t <= 0.0:
		tint = Color(1.0, 0.72, 0.5).lerp(Color.WHITE, 0.5 + 0.5 * sin(Time.get_ticks_msec() / 70.0))
	elif poison_t > 0.0 and stun_t <= 0.0:
		tint = POISON_COLOR.lerp(Color.WHITE, 0.45 + 0.35 * sin(Time.get_ticks_msec() / 110.0))
	if TimeStop.active and not dead:
		tint = Color(0.62, 0.78, 1.0)  # zaman durdu: buz mavisi, animasyon donuk
	tint.a = visual_alpha
	anim.set_paused(TimeStop.active and not dead)
	anim.play(pick_animation())
	super._process(delta)


## Duruma göre animasyon adı. Alt sınıflar kendi evrelerini ekler.
func pick_animation() -> String:
	if dead:
		return "death"
	if stun_t > 0.0:
		return "stun"
	if knock_t > 0.0:
		return "hurt"
	if not is_on_floor():
		return "jump" if velocity.y < 0.0 else "fall"
	return "run" if absf(velocity.x) > 20.0 else "idle"


func _find_target() -> void:
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as Player


## Düşmanı tutuşturur: `duration` sn boyunca her 0.6 sn'de 1 hasar (yenilenir, üst üste binmez).
## Yanma hasarı kaynaksızdır: ritim/kombo doldurmaz, başka eşyaları tetiklemez.
func ignite(duration: float) -> void:
	if dead:
		return
	if burn_t <= 0.0:
		_burn_tick = 0.0
	burn_t = maxf(burn_t, duration)


func _tick_burn(delta: float) -> void:
	if burn_t <= 0.0 or dead:
		return
	burn_t = maxf(burn_t - delta, 0.0)
	_burn_tick += delta
	if _burn_tick >= BURN_INTERVAL:
		_burn_tick -= BURN_INTERVAL
		var n := DamageNumber.spawn(get_parent(), global_position + Vector2(randf_range(-10.0, 10.0), -30.0), 1, randf_range(-0.6, 0.6))
		if n != null:
			n.color = BURN_COLOR
		take_damage(1, null)


## Zehirler: `duration` sn boyunca saniyede `dps` hasar (tam sayı tikler halinde). Yenilenir, üst üste binmez.
## Zehir hasarı kaynaksızdır: ritim/kombo doldurmaz, başka eşyaları tetiklemez.
func poison(dps: float, duration: float) -> void:
	if dead:
		return
	if poison_t <= 0.0:
		_poison_acc = 0.0
		poison_dps = dps
	else:
		poison_dps = maxf(poison_dps, dps)
	poison_t = maxf(poison_t, duration)


func _tick_poison(delta: float) -> void:
	if poison_t <= 0.0 or dead:
		return
	var dt := minf(delta, poison_t)
	poison_t -= dt
	_poison_acc += poison_dps * dt
	while _poison_acc >= 0.999 and not dead:
		_poison_acc -= 1.0
		var n := DamageNumber.spawn(get_parent(), global_position + Vector2(randf_range(-10.0, 10.0), -30.0), 1, randf_range(-0.6, 0.6))
		if n != null:
			n.color = POISON_COLOR
		take_damage(1, null)
	if poison_t <= 0.0:
		_poison_acc = 0.0


func is_stunned() -> bool:
	return stun_t > 0.0


## Alt sınıflar bunu doldurur.
func _ai(_delta: float) -> void:
	pass


## Zorluk/tur ayarını (`tuning`) kendi sayılarına uygular: hız, bekleme, uyarı süresi... `_ready` sonunda bir kez çağrılır.
func _apply_tuning() -> void:
	pass


## Vuruşla bölündü (hazırlanan ya da süren saldırı iptal). Alt sınıflar kendi evrelerini sıfırlar.
func _on_interrupted() -> void:
	pass


func _on_stun_end() -> void:
	pass


func _on_stunned() -> void:
	pass


## Platforma zıplarken çağrılır.
func on_nav_jump() -> void:
	anim.trigger("jump")


func stun(duration: float) -> void:
	stun_t = maxf(stun_t, duration)
	armored = false
	set_tell(Tell.NONE)
	_on_stunned()


func set_tell(mode: Tell) -> void:
	var changed := mode != _tell
	if changed:
		_tell_age = 0.0
	_tell = mode
	if tell_glow != null:
		tell_glow.visible = mode != Tell.NONE
		tell_glow.color = GOLD if mode == Tell.GOLD else RED
	if changed and mode != Tell.NONE:
		Sfx.play("tell_gold" if mode == Tell.GOLD else "tell_red")
	queue_redraw()


## Başın üstündeki sarı sembol sadece parry'lenebilir (altın) saldırıda görünür.
func has_tell_symbol() -> bool:
	return _tell == Tell.GOLD


## Saldırı uyarısı: SADECE parry'lenebilir (altın) saldırıda başın üstünde sarı elmas çıkar.
## Kırmızı saldırıda sembol yok; yalnızca gövde kırmızı parlar (kaç!).
func _draw() -> void:
	if not has_tell_symbol():
		return
	var pop := DamageNumber.pop_scale(_tell_age / TELL_POP_TIME)
	var pulse := 1.0 + 0.12 * sin(Time.get_ticks_msec() / 55.0)
	var y := -64.0
	var r := 15.0 * pulse * pop
	# Yumuşak hale
	draw_circle(Vector2(0, y), r * 2.0, Color(1.0, 0.82, 0.25, 0.10))
	draw_circle(Vector2(0, y), r * 1.5, Color(1.0, 0.85, 0.3, 0.14))
	var pts := PackedVector2Array([Vector2(0, y - r), Vector2(r * 0.8, y), Vector2(0, y + r), Vector2(-r * 0.8, y)])
	draw_colored_polygon(pts, GOLD)
	var inner := PackedVector2Array([Vector2(0, y - r * 0.55), Vector2(r * 0.42, y), Vector2(0, y + r * 0.55), Vector2(-r * 0.42, y)])
	draw_colored_polygon(inner, Color(1.0, 0.96, 0.7))
	pts.append(pts[0])
	draw_polyline(pts, Color.WHITE, 2.5)


func on_hit_by(hitbox: Hitbox) -> bool:
	if dead:
		return false
	var amount := hitbox.damage
	if is_stunned():
		amount = ceili(amount * 1.5)  # sersemlemiş düşman daha çok hasar alır
	take_damage(amount, hitbox.source)
	if not dead and not armored:
		var dir := signf(global_position.x - hitbox.global_position.x)
		var heavy := hitbox.damage >= 2
		velocity.x = (dir if dir != 0.0 else 1.0) * knockback_force * (1.6 if heavy else 1.0) * ActorBase.knockback_mult_of(hitbox.source)
		velocity.y = -110.0
		stagger(STAGGER_HEAVY if heavy else STAGGER_LIGHT)
		anim.trigger("hurt", 0.2)
	return true


## Vuruşla sersemlet: hazırlanan/süren saldırı iptal olur, düşman `duration` sn boyunca bir şey yapamaz.
## (Yanma gibi kaynaksız hasar bunu çağırmaz; sadece vuruşlar çağırır.)
func stagger(duration: float) -> void:
	if dead or armored:
		return
	knock_t = maxf(knock_t, duration)
	set_tell(Tell.NONE)
	_on_interrupted()


func die() -> void:
	if dead:
		return
	super.die()
	remove_from_group("enemies")
	EventBus.enemy_died.emit(self)
	set_tell(Tell.NONE)
	# Ölü düşman artık engel olmaz (oyuncu içinden geçebilir).
	set_deferred("collision_layer", 0)
	if hurtbox != null:
		hurtbox.set_deferred("monitorable", false)
	_drop_gold()
	_on_death()
	if anim.has_anim("death"):
		# Ölüm animasyonu varsa bitmesini bekle, sonra sön.
		anim.trigger("death")
		var tw_art := create_tween()
		tw_art.tween_interval(clampf(anim.duration_of("death"), 0.25, 1.5))
		tw_art.tween_property(self, "modulate:a", 0.0, 0.25)
		tw_art.tween_callback(queue_free)
	else:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "modulate:a", 0.0, 0.3)
		tw.tween_property(self, "scale", Vector2(1.25, 0.1), 0.3)
		tw.chain().tween_callback(queue_free)
	RingFx.spawn(get_parent(), global_position, Color(1, 1, 1, 0.8), 10.0, 60.0, 0.3)


## Ölünce altın saçar (oyuncu toplar; kat başlarındaki mağazada harcanacak).
func _drop_gold() -> void:
	var n := randi_range(gold_min, maxi(gold_max, gold_min))
	if n > 0:
		Coin.drop(get_parent(), global_position + Vector2(0.0, -8.0), n)


func _on_death() -> void:
	pass
