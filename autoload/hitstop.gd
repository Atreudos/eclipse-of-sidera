extends Node
## Vuruş anında oyunu çok kısa süre yavaşlatır (hitstop). Parry hissinin en önemli parçası.
## Süre GERÇEK zamandır (Engine.time_scale'den etkilenmez).

const FROZEN_SCALE := 0.05

var enabled := true
## Debug ayarı: tüm hitstop sürelerini çarpar (1.0 = normal).
var duration_mult := 1.0

var _end_msec := 0


func freeze(duration: float) -> void:
	if not enabled:
		return
	var ms := int(duration * duration_mult * 1000.0)
	if ms <= 0:
		return
	var end := Time.get_ticks_msec() + ms
	if end <= _end_msec:
		return
	_end_msec = end
	Engine.time_scale = FROZEN_SCALE
	# 4. parametre: zaman ölçeğini yok say
	get_tree().create_timer(ms / 1000.0, true, false, true).timeout.connect(_on_timeout)


func reset() -> void:
	_end_msec = 0
	Engine.time_scale = 1.0


func _on_timeout() -> void:
	if Time.get_ticks_msec() >= _end_msec:
		Engine.time_scale = 1.0
