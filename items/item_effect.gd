class_name ItemEffect
extends RefCounted
## Eşya davranışı için taban sınıf. Eşya Inventory'ye eklenince `on_acquire`, çıkarılınca `on_remove` çağrılır.
## Eşyalar çekirdek koda DOKUNMAZ: EventBus sinyallerine abone olur ve Stats modifier'ı ekler.
## Aynı betik Umbra'da de çalışabilsin diye "sahip" (`owner`) bir Player'dır ama ActorBase'e de uyar.

var owner: Player
var data: ItemData

var _connections: Array = []


## Eşya alındığında bir kez çağrılır (Stats modifier'ları bu noktada zaten uygulanmıştır).
func on_acquire() -> void:
	pass


## Eşya çıkarılırken çağrılır (kendi eklediğin modifier'ları ve durumu temizle).
func on_remove() -> void:
	pass


## HUD'da eşyanın yanında görünecek kısa yazı (örn. "FAİZ 3"). Boşsa görünmez.
func hud_text() -> String:
	return ""


## Bir sinyale bağlanır; eşya çıkarılınca (release) otomatik koparılır.
func listen(sig: Signal, callable: Callable) -> void:
	sig.connect(callable)
	_connections.append([sig, callable])


func release() -> void:
	for c: Array in _connections:
		var sig: Signal = c[0]
		var callable: Callable = c[1]
		if sig.is_connected(callable):
			sig.disconnect(callable)
	_connections.clear()
