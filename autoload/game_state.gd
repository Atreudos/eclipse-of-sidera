extends Node
## Koşu durumu (run): Umbra'ya bırakılan eşyalar vb. Her yeni koşuda `reset()` çağrılır.
## Umbra dövüşü (Aşama 4) buradaki envanteri kullanacak.

signal umbra_changed
signal god_mode_changed(enabled: bool)

## Deneme (god) modu, F4 ile açılıp kapanır: can düşmez, dash/parry bekleme yok. Geliştirme ve deneme içindir.
## `reset()` bunu kapatmaz: ölüp yeniden başlasan da açık kalır.
var god_mode := false:
	set(value):
		if god_mode == value:
			return
		god_mode = value
		god_mode_changed.emit(value)

## Zorluk seviyesi (Difficulty.Level). Yeni oyun başlarken seçilir; düşman ayarı buna göre kurulur.
## `reset()` bunu değiştirmez: ölüp yeniden başlayınca aynı zorlukta devam edilir.
var difficulty: int = Difficulty.DEFAULT

## Şu an oynanan kayıt slotu (null = kayıtsız oturum: testler, geliştirme). Doluyken koşu kendiliğinden kaydedilir.
var slot: SaveSlot = null
## Oynanan kip (GameMode.Kind).
var mode: int = GameMode.DEFAULT
## Menüden "devam" denince yüklenecek koşu (RunSnapshot sözlüğü). Koşu sahnesi `_ready`'de bir kez alır.
var resume_run: Dictionary = {}

## Oyuncunun seçmeyip BIRAKTIĞI eşyalar: Umbra bunları alır.
var umbra_items: Array[ItemData] = []
## "Aç Kapı" gibi eşyalar Umbra'nın her pusuda fazladan taşıyacağı eşya sayısını artırır.
var umbra_extra_carry := 0


## Bir kayıt slotuyla oyuna başlar: zorluk slottan gelir, koşu durumu sıfırlanır.
func begin_session(s: SaveSlot, kind: int) -> void:
	slot = s
	mode = GameMode.clamp_kind(kind)
	difficulty = s.difficulty
	reset()


## Kayıt oturumunu kapatır (ana menüye dönüş).
func end_session() -> void:
	slot = null
	resume_run = {}
	reset()


## Bekleyen "devam" koşusunu verir ve temizler (boşsa yeni koşu başlar).
func take_resume() -> Dictionary:
	var r := resume_run
	resume_run = {}
	return r


func reset() -> void:
	umbra_items.clear()
	umbra_extra_carry = 0
	umbra_changed.emit()


## Seçilmeyen eşya Umbra'ya gider.
func leave_behind(item: ItemData) -> void:
	umbra_items.append(item)
	umbra_changed.emit()
	EventBus.item_left_behind.emit(item)


func umbra_has(item_id: String) -> bool:
	for it in umbra_items:
		if it.id == item_id:
			return true
	return false


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_F4:
		god_mode = not god_mode
