extends Node
## Vuruş anında oyunu çok kısa süre yavaşlatır (hitstop). Parry hissinin en önemli parçası.
##
## Süre GERÇEK zamandır (Engine.time_scale'den etkilenmez).
## Zamanlayıcı yerine her karede duvar saatine bakılır: eskiden zamanlayıcı bir kare "erken"
## bittiğinde zaman ölçeği hiç geri alınmıyor ve oyun yavaş kalıyordu.

const FROZEN_SCALE := 0.05
## Üst üste binen vuruşlar bile bu süreyi (saniye) aşamaz.
const MAX_FREEZE := 0.12

var enabled := true
## Debug ayarı: tüm hitstop sürelerini çarpar (1.0 = normal).
var duration_mult := 1.0

var _end_usec := 0
var _start_usec := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_frozen() -> bool:
	return _end_usec != 0


func freeze(duration: float) -> void:
	if not enabled:
		return
	var seconds := minf(duration * duration_mult, MAX_FREEZE)
	if seconds <= 0.0:
		return
	var now := Time.get_ticks_usec()
	if _end_usec == 0:
		_start_usec = now
	var end := mini(now + int(seconds * 1000000.0), _start_usec + int(MAX_FREEZE * 1000000.0))
	if end <= _end_usec:
		return
	_end_usec = end
	Engine.time_scale = FROZEN_SCALE


func reset() -> void:
	_end_usec = 0
	_start_usec = 0
	Engine.time_scale = 1.0


func _process(_delta: float) -> void:
	if _end_usec != 0:
		if Time.get_ticks_usec() >= _end_usec:
			reset()
	elif is_equal_approx(Engine.time_scale, FROZEN_SCALE):
		# Emniyet: bizim ayarladığımız yavaşlıkta kalmış, ama biten bir hitstop yok.
		Engine.time_scale = 1.0
