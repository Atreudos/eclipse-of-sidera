class_name SlingStone
extends Projectile
## Sapan taşı: oyuncunun fırlattığı mermi. Parry'lenemez, oyuncuya zarar vermez, düşmana değince (delme hakkı yoksa) kaybolur,
## duvara çarpınca durur. Zaman durunca (Satürn'ün Kum Saati) bile uçmaya devam eder: yalnız oyuncu hareket eder.
##
## Çizim yer tutucudur (gri taş + kuyruk); `fx_sling_stone` çizimi gelince onu kullanır.

const STONE := Color(0.62, 0.6, 0.56)
const STONE_LIGHT := Color(0.92, 0.9, 0.84)

## Bu taş kaç düşmanın içinden daha geçebilir (0 = ilk düşmanda biter).
var pierce_left := 0
## Parry sonrası "güçlü vuruş" hakkıyla atılan taş (altın hâleyle çizilir).
var empowered := false

var _fx_t := 0.0


func _ready() -> void:
	faction = "player"
	ignores_time_stop = true
	super._ready()


## Taşı fırlatır. `vel` yön ve hız; `dmg` tam sayı hasar; `pierce` delinebilecek düşman sayısı.
func fire(vel: Vector2, dmg: int, shooter: Node, pierce: int = 0, life: float = WeaponDB.SLING_LIFETIME, knock: float = 1.0) -> void:
	launch(vel, false, shooter, dmg)
	pierce_left = pierce
	lifetime = life
	knock_mult = knock


func _physics_process(delta: float) -> void:
	_fx_t += delta
	super._physics_process(delta)
	queue_redraw()


func _on_landed(target: Hurtbox) -> void:
	HitSpark.spawn(get_parent(), global_position, -velocity.normalized(), Color(0.95, 0.92, 0.8), 0.6)
	if pierce_left > 0:
		pierce_left -= 1
		return
	super._on_landed(target)


func _on_hit_world(body: Node) -> void:
	RingFx.spawn(get_parent(), global_position, Color(0.8, 0.78, 0.7, 0.5), 3.0, 14.0, 0.14)
	super._on_hit_world(body)


func _draw() -> void:
	var r := radius
	if empowered:
		draw_circle(Vector2.ZERO, r * 1.9, Color(1.0, 0.85, 0.35, 0.18))
	if Art.draw(self, "fx_sling_stone", Rect2(Vector2(-r * 1.6, -r * 1.6), Vector2(r * 3.2, r * 3.2)), _fx_t):
		return
	# kuyruk: hareket yönünün tersine uzanan soluk çizgiler
	draw_line(Vector2(-r, 0.0), Vector2(-r * 3.4, 0.0), Color(STONE_LIGHT, 0.35), 3.0)
	draw_line(Vector2(-r, -r * 0.45), Vector2(-r * 2.4, -r * 0.45), Color(STONE_LIGHT, 0.18), 2.0)
	draw_line(Vector2(-r, r * 0.45), Vector2(-r * 2.4, r * 0.45), Color(STONE_LIGHT, 0.18), 2.0)
	draw_circle(Vector2.ZERO, r, STONE)
	draw_circle(Vector2(r * 0.25, -r * 0.3), r * 0.4, STONE_LIGHT)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 20, Color(0.2, 0.19, 0.22, 0.9), 2.0)
