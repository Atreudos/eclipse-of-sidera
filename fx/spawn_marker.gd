class_name SpawnMarker
extends Node2D
## Düşman doğmadan önce görünen işaret: yerden yükselen ışık sütunu ve halka.
## Süre dolunca düşmanı çıkarır (`finished` sinyali ile haber verir).

signal finished(enemy: Node)

var scene: PackedScene
var enemies_root: Node
## Doğan düşmana verilecek zorluk/tur ayarı (null = ayarsız).
var tuning: EnemyTuning = null
var duration := 0.55
var color := Color(1.0, 0.86, 0.4)

var _t := 0.0


## `feet`: düşmanın duracağı yüzey noktası (dünya). `host`: işaretin ekleneceği düğüm.
static func spawn(host: Node, feet: Vector2, enemy_scene: PackedScene, enemy_parent: Node, delay: float = 0.55) -> SpawnMarker:
	var m := SpawnMarker.new()
	m.scene = enemy_scene
	m.enemies_root = enemy_parent
	m.duration = maxf(delay, 0.05)
	m.z_index = 12
	host.add_child(m)
	m.global_position = feet
	Sfx.play("spawn", -9.0, 1.0, 0.08)
	return m


func _process(delta: float) -> void:
	if TimeStop.active:
		return
	_t += delta
	if _t >= duration:
		_emerge()
		return
	queue_redraw()


func _emerge() -> void:
	var enemy: Node = null
	if scene != null and enemies_root != null and is_instance_valid(enemies_root):
		enemy = scene.instantiate()
		if tuning != null and enemy is EnemyBase:
			(enemy as EnemyBase).tuning = tuning  # _ready'den önce: can ve altın doğarken ölçeklensin
		enemies_root.add_child(enemy)
		if enemy is Node2D:
			(enemy as Node2D).global_position = global_position + Vector2(0.0, -34.0)
		if enemy is ActorBase:
			(enemy as ActorBase).flash(Color(1.0, 0.95, 0.7), 0.25)
		RingFx.spawn(get_parent(), global_position + Vector2(0.0, -24.0), Color(color, 0.9), 10.0, 64.0, 0.3)
	finished.emit(enemy)
	queue_free()


func _draw() -> void:
	var k := clampf(_t / duration, 0.0, 1.0)
	# Sütun: önce ince ve soluk, sonra parlayıp genişler; çıkış anında söner.
	var h := 150.0 * (1.0 - pow(1.0 - minf(k * 1.6, 1.0), 3.0))
	var w := lerpf(4.0, 38.0, k * k)
	var a := 0.15 + 0.6 * k
	draw_rect(Rect2(-w * 0.5, -h, w, h), Color(color, a * 0.35))
	draw_rect(Rect2(-w * 0.2, -h, w * 0.4, h), Color(1.0, 1.0, 1.0, a * 0.7))
	# Zeminde daralan halka
	var r := lerpf(46.0, 14.0, k)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 28, Color(color, 0.35 + 0.6 * k), 3.0)
	draw_line(Vector2(-r * 1.2, 0.0), Vector2(r * 1.2, 0.0), Color(color, 0.4 + 0.5 * k), 3.0)
