class_name ShopStock
extends RefCounted
## Lobideki dükkânın rafı: birkaç takılabilir eşya + birkaç yemek. Kat başına bir kez, tohumla üretilir.
##
## DEĞERE GÖRE RAF: dükkân yalnız YAYGIN ve NADİR eşya satar. EFSANEVİ (en değerli / en güçlü) ve LANETLİ eşya dükkâna HİÇ düşmez
## (hiçbir katta, raf boş kalsa bile); onlar Gölge'yi yenince çıkan ödül sehpasından gelir. Taban fiyatı MAX_PRICE'ı aşan eşya da
## nadirliği ne olursa olsun satılmaz. Raftaki şans değere göre: yaygın eşya çok çıkar, nadir eşya 1. katta seyrek çıkar
## (RARE_EARLY_WEIGHT) ve RARE_FULL_FLOOR. kata doğru sıklaşır.
## Sahip olunan eşyalar (takılı ya da çantada) ve Umbra'ya kalmış eşyalar rafa konmaz.
## Fiyat = eşyanın fiyatı, her kat için %12 pahalı. Altın yetmiyorsa ya da çanta doluysa satış REDDEDİLİR (altın düşmez).

class Offer extends RefCounted:
	var item: ItemData
	var price := 0
	var sold := false

const GEAR_OFFERS := 3
## LATE_FLOOR ve sonrası dördüncü bir eşya daha satar.
const GEAR_OFFERS_LATE := 4
const LATE_FLOOR := 4
const FOOD_OFFERS := 2
const PRICE_STEP := 0.12
## Dükkânda satılabilecek en yüksek nadirlik: NADİR. (Efsanevi ve Lanetli hiçbir katta satılmaz.)
const MAX_RARITY := ItemData.Rarity.RARE
## Taban fiyatı bunu aşan eşya dükkâna konmaz (nadirliği yanlış girilmiş çok değerli eşyalara karşı ikinci güvence).
const MAX_PRICE := 80
## Nadir eşyanın şansı 1. katta bu çarpanla başlar...
const RARE_EARLY_WEIGHT := 0.5
## ...ve bu katta tam şansa (x1) ulaşır.
const RARE_FULL_FLOOR := 9

var offers: Array[Offer] = []


## Dükkânda satılabilecek en yüksek nadirlik (her katta aynı; kat parametresi eski çağrılar için).
static func max_rarity(_floor_no: int = 1) -> int:
	return MAX_RARITY


## Bu eşya dükkânda SATILABİLİR mi? (yemekler: her biri; takılabilir eşya: nadirlik ve fiyat sınırı içinde)
static func sellable(item: ItemData) -> bool:
	if item == null:
		return false
	if item.is_food():
		return item.rarity <= MAX_RARITY
	return item.is_equippable() and item.rarity <= MAX_RARITY and item.price <= MAX_PRICE


## Eşyanın bu kattaki raf şansı (ağırlık): değer arttıkça seyrekleşir; nadir eşya derin katlarda sıklaşır.
static func weight_of(item: ItemData, floor_no: int) -> float:
	var w: float = ItemDB.RARITY_WEIGHT[item.rarity]
	if item.rarity == ItemData.Rarity.RARE and not item.is_food():
		var t := clampf(float(maxi(floor_no, 1) - 1) / float(RARE_FULL_FLOOR - 1), 0.0, 1.0)
		w *= lerpf(RARE_EARLY_WEIGHT, 1.0, t)
	return w


static func gear_count(floor_no: int) -> int:
	return GEAR_OFFERS_LATE if floor_no >= LATE_FLOOR else GEAR_OFFERS


## Eşyanın bu kattaki fiyatı (en az 1).
static func price_of(item: ItemData, floor_no: int) -> int:
	return maxi(roundi(float(item.price) * (1.0 + PRICE_STEP * float(maxi(floor_no, 1) - 1))), 1)


## Raf üretir. `rng` aynıysa (ve sahip olunanlar aynıysa) raf aynıdır.
static func generate(rng: RandomNumberGenerator, floor_no: int, owned_ids: Array = [], umbra_ids: Array = []) -> ShopStock:
	var stock := ShopStock.new()
	var gear: Array[ItemData] = []
	for it in ItemDB.equipment():
		if sellable(it) and not (it.id in owned_ids) and not (it.id in umbra_ids):
			gear.append(it)
	var foods: Array[ItemData] = []
	for it in ItemDB.all():
		if it.is_food() and sellable(it):
			foods.append(it)
	for k in gear_count(floor_no):
		if gear.is_empty():
			break  # uygun eşya kalmadıysa raf eksik kalır; Efsanevi'ye asla düşülmez
		var picked := _pick(rng, gear, floor_no)
		gear.erase(picked)
		stock._add(picked, floor_no)
	for k in FOOD_OFFERS:
		if foods.is_empty():
			break
		var picked := _pick(rng, foods, floor_no)
		foods.erase(picked)
		stock._add(picked, floor_no)
	return stock


static func _pick(rng: RandomNumberGenerator, pool: Array[ItemData], floor_no: int) -> ItemData:
	var total := 0.0
	for it in pool:
		total += weight_of(it, floor_no)
	var roll := rng.randf() * total
	for it in pool:
		roll -= weight_of(it, floor_no)
		if roll <= 0.0:
			return it
	return pool[pool.size() - 1]


func _add(item: ItemData, floor_no: int) -> Offer:
	var o := Offer.new()
	o.item = item
	o.price = price_of(item, floor_no)
	offers.append(o)
	return o


func size() -> int:
	return offers.size()


func unsold_count() -> int:
	var n := 0
	for o in offers:
		if not o.sold:
			n += 1
	return n


## `index`. tekliften satın alır. Başarılıysa "", değilse ekrana yazılacak neden. Reddedilen satışta altın düşmez.
## Takılabilir eşya slotunda yer varsa kendiliğinden takılır; yoksa çantaya konur. Yemek çantaya konur (envanterden yenir).
func buy(player: Player, index: int) -> String:
	if index < 0 or index >= offers.size():
		return "YOK"
	var o := offers[index]
	if o.sold:
		return "SATILDI"
	if player == null or not is_instance_valid(player) or player.dead:
		return "ÖLÜSÜN"
	var inv := player.inventory
	if inv == null:
		return "ENVANTER YOK"
	if player.gold < o.price:
		return "YETERLİ ALTIN YOK"
	if not inv.can_give(o.item):
		return "ÇANTA DOLU"
	if not player.spend_gold(o.price):
		return "YETERLİ ALTIN YOK"
	var reason := inv.give(o.item)
	if reason != "":
		player.add_gold(o.price)  # olmaması gereken durum: parayı geri ver
		return reason
	if o.item.is_equippable() and inv.slot_free(o.item.slot) > 0:
		inv.equip(o.item)
	o.sold = true
	EventBus.item_purchased.emit(player, o.item, o.price)
	return ""


# ---------------------------------------------------------------- kayıt

## Kayıt için: [{"id", "price", "sold"}, ...]
func to_array() -> Array:
	var out: Array = []
	for o in offers:
		out.append({"id": o.item.id, "price": o.price, "sold": o.sold})
	return out


## Kayıttan raf kurar. Tanınmayan eşya kimlikleri (silinmiş eşyalar) atlanır.
static func from_array(data: Variant) -> ShopStock:
	var stock := ShopStock.new()
	if not (data is Array):
		return stock
	for e in data:
		if not (e is Dictionary):
			continue
		var item := ItemDB.get_item(str((e as Dictionary).get("id", "")))
		if item == null:
			continue
		var o := Offer.new()
		o.item = item
		o.price = maxi(SaveSlot._int((e as Dictionary).get("price", item.price), item.price), 1)
		o.sold = bool((e as Dictionary).get("sold", false))
		stock.offers.append(o)
	return stock
