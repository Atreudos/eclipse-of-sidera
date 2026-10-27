extends Node
## Zaman durdurma (Satürn'ün Kum Saati): süre boyunca düşmanlar, mermiler, doğma işaretleri ve oda sayaçları donar;
## sadece oyuncu (ve altın, efektler) akmaya devam eder. Donmuş düşmana vurabilirsin: hasar işlenir,
## geri itme ve sersemlik zaman akınca uygulanır.
##
## Donacak şeyler kendi `_physics_process` başında `if TimeStop.active: return` der.
## Süre oyun zamanıyla (fizik kareleriyle) akar: hitstop sırasında da düzgün işler.

signal started(duration: float)
signal ended

var active := false
var remaining := 0.0
var total := 0.0


## Zamanı `duration` sn durdurur. Zaten duruyorsa süreyi yeniler.
func start(duration: float) -> void:
	if duration <= 0.0:
		return
	var was_active := active
	active = true
	remaining = duration
	total = duration
	if not was_active:
		started.emit(duration)
		Sfx.play("timestop")
		EventBus.screen_flash.emit(Color(0.75, 0.9, 1.0), 0.55, 0.3)
		EventBus.camera_punch.emit(0.05)
		EventBus.screen_shake.emit(5.0, 0.2)


## Zamanı erken akıtır.
func stop() -> void:
	if not active:
		return
	active = false
	remaining = 0.0
	Sfx.play("timestop_end", -4.0)
	ended.emit()


## Sessizce sıfırlar (sahne yenilenirken).
func reset() -> void:
	active = false
	remaining = 0.0
	total = 0.0


## Kalan süre oranı (1 = yeni başladı, 0 = bitti). Durmuyorsa 0.
func progress() -> float:
	if not active or total <= 0.0:
		return 0.0
	return clampf(remaining / total, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	if not active:
		return
	remaining -= delta
	if remaining <= 0.0:
		stop()
