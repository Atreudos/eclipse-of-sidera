extends Node2D
## Test arenası: parry/dash hissini denemek için sonsuz dalgalar.
## Dalga bitince (tüm düşmanlar ölünce) kısa bir aradan sonra bir sonraki dalga gelir.

const SHOOTER := preload("res://actors/enemies/shooter.tscn")
const BIDDER := preload("res://actors/enemies/bidder.tscn")

const SPAWN_X := [140.0, 1140.0, 420.0, 860.0, 640.0]
const SPAWN_Y := 200.0

var wave := 0
var _next_wave_t := 1.2

@onready var player: Player = $Player
@onready var hud: Hud = $Hud
@onready var enemies_root: Node2D = $Enemies
@onready var camera: ShakeCamera = $Camera


func _ready() -> void:
	Hitstop.reset()
	# Zeminin altında da görünür alan var: kamera yukarı/aşağı azıcık oynayabilsin.
	camera.set_bounds(Rect2(0.0, 0.0, 1280.0, RoomLayouts.CAMERA_HEIGHT), true)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		Hitstop.reset()
		get_tree().reload_current_scene()
		return
	if player.dead:
		return
	if get_tree().get_nodes_in_group("enemies").is_empty():
		_next_wave_t -= delta
		if _next_wave_t <= 0.0:
			_spawn_wave()
			_next_wave_t = 1.8


func _spawn_wave() -> void:
	wave += 1
	hud.wave = wave
	var count := 1 + wave / 2
	for i in count:
		var scene: PackedScene = SHOOTER if (wave + i) % 2 == 0 else BIDDER
		var e := scene.instantiate() as Node2D
		enemies_root.add_child(e)
		e.global_position = Vector2(SPAWN_X[(wave + i) % SPAWN_X.size()], SPAWN_Y)
