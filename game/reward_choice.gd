class_name RewardChoice
extends RefCounted
## Gölge'yi yenince çıkan ödül: iki eşya sunulur; birini alırsın, SEÇMEDİĞİN Gölge'ye gider ve sonraki katlarda sana karşı kullanılır.
## Mantık burada. Sunak (RewardStand) ve menü (RewardMenu) yalnız gösterir; koşu denetleyicisi (RunController) akışı yönetir.
## Son kat hariç her katın Gölge'sinden sonra bir kez çıkar (son katta zafer var).

## Eşya alındı: alınan eşya ve geride kalanlar (Gölge'ye giden ya da "Sadece Oyuncu" ise yok olan).
signal taken(item: ItemData, left: Array)

## Sunulan eşyalar (normalde 2).
var items: Array[ItemData] = []
## Alınan eşyanın sırası; -1 = henüz seçilmedi.
var chosen := -1
var floor_no := 1


## Seçimi kurar. Sahip olunan ve Gölge'ye kalmış eşyalar çıkmaz (havuz daralırsa sahip olunanlar da çıkar).
## Aynı `rng` durumu aynı çifti verir (kayıttan devam edince aynı ödül gelir).
static func generate(rng: RandomNumberGenerator, for_floor: int, owned_ids: Array = [], umbra_ids: Array = []) -> RewardChoice:
	var c := RewardChoice.new()
	c.floor_no = for_floor
	c.items = ItemDB.roll_pair(rng, owned_ids, umbra_ids, for_floor)
	return c


func size() -> int:
	return items.size()


func is_done() -> bool:
	return chosen >= 0


## Alınan eşya (seçilmediyse null).
func chosen_item() -> ItemData:
	return items[chosen] if is_done() else null


## Seçilmeyen eşyalar (seçim yapılmadıysa boş).
func left_items() -> Array[ItemData]:
	var out: Array[ItemData] = []
	if not is_done():
		return out
	for i in items.size():
		if i != chosen:
			out.append(items[i])
	return out


## `index`. eşyayı almaya engel var mı? Yoksa "". Menü bunu düğme ipucu olarak gösterir.
func why_not(player: Player, index: int) -> String:
	if is_done():
		return "ZATEN SEÇİLDİ"
	if index < 0 or index >= items.size():
		return "YOK"
	if player == null or not is_instance_valid(player) or player.dead:
		return "ÖLÜSÜN"
	var inv := player.inventory
	if inv == null:
		return "ENVANTER YOK"
	if not inv.can_give(items[index]):
		return "ÇANTA DOLU"
	return ""


## `index`. eşyayı alır: oyuncuya verilir (slotunda yer varsa takılır, yoksa çantada durur), seçilmeyenler Gölge'ye gider.
## Başarılıysa "", değilse ekrana yazılacak neden (hiçbir şey değişmez). Seçim geri alınmaz.
func take(player: Player, index: int) -> String:
	var reason := why_not(player, index)
	if reason != "":
		return reason
	var item := items[index]
	var inv := player.inventory
	reason = inv.give(item)
	if reason != "":
		return reason
	if item.is_equippable() and inv.slot_free(item.slot) > 0:
		inv.equip(item)
	chosen = index
	var left := left_items()
	for it in left:
		if it.umbra_allowed:
			GameState.leave_behind(it)
	taken.emit(item, left)
	return ""
