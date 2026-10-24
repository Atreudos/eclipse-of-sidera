extends Node
## Koşu durumu (run): Umbra'ya bırakılan eşyalar vb. Her yeni koşuda `reset()` çağrılır.
## Umbra dövüşü (Aşama 4) buradaki envanteri kullanacak.

signal umbra_changed

## Oyuncunun seçmeyip BIRAKTIĞI eşyalar: Umbra bunları alır.
var umbra_items: Array[ItemData] = []
## "Aç Kapı" gibi eşyalar Umbra'nın her pusuda fazladan taşıyacağı eşya sayısını artırır.
var umbra_extra_carry := 0


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
