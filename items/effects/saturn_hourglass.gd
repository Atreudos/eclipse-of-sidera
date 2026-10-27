extends ItemEffect
## Satürn'ün Kum Saati: iki saldırıyı AYNI ANDA parry'lersen zaman 1.5 sn durur; sadece sen hareket edersin.
## "Aynı anda": iki başarılı parry arası LINK_WINDOW sn'den kısa (Player, parry'den hemen sonra gelen altın
## saldırıları da parry'ler, bkz. Player.PARRY_CHAIN_TIME = 0.3).

const STOP_TIME := 1.5
const LINK_WINDOW := 0.35

var _last_parry := -100.0


func on_acquire() -> void:
	listen(EventBus.parry_success, _on_parry)


func hud_text() -> String:
	return "ZAMAN DURDU" if TimeStop.active else ""


static func _clock() -> float:
	return float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second)


func _on_parry(actor: Node, _hitbox: Node) -> void:
	if actor != owner:
		return
	var now := _clock()
	if now - _last_parry <= LINK_WINDOW:
		_last_parry = -100.0
		TimeStop.start(STOP_TIME)
	else:
		_last_parry = now
