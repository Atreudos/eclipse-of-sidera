class_name ShopStock
extends RefCounted
## Lobideki dükkânın rafı: birkaç takılabilir eşya + birkaç yemek. Kat başına bir kez, tohumla üretilir.
##
## "Çok değerli olmayan" kuralı: dükkânda Lanetli eşya yoktur; Efsanevi eşya yalnız LATE_FLOOR. kattan sonra çıkar.
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

var offers: Array[Offer] = []


## Dükkânda satılabilecek en yüksek nadirlik.
static func max_rarity(floor_no: int) -> int:
	return ItemData.Rarity.EPIC if floor_no >= LATE_FLOOR else ItemData.Rarity.RARE


static func gear_count(floor_no: int) -> int:
	return GEAR_OFFERS_LATE if floor_no >= LATE_FLOOR else GEAR_OFFERS


## Eşyanın bu kattaki fiyatı (en az 1).
static func price_of(item: ItemData, floor_no: int) -> int:
	return maxi(roundi(float(item.price) * (1.0 + PRICE_STEP * float(maxi(floor_no, 1) - 1))), 1)


## Raf üretir. `rng` aynıysa (ve sahip olunanlar aynıysa) raf aynıdır.
static func generate(rng: RandomNumberGenerator, floor_no: int, owned_ids: Array = [], umbra_ids: Array = []) -> ShopStock:
	var stock := ShopStock.new()
	var cap := max_rarity(floor_no)
	var gear: Array[ItemData] = []
	for it in ItemDB.equipment():
		if it.rarity <= cap and not (it.id in owned_ids) and not (it.id in umbra_ids):
			gear.append(it)
	var foods: Array[ItemData] = []
	for it in ItemDB.all():
		if it.is_food():
			foods.append(it)
	for k in gear_count(floor_no):
		if gear.is_empty():
			break
		var picked := _pick(rng, gear)
		gear.erase(picked)
		stock._add(picked, floor_no)
	for k in FOOD_OFFERS:
		if foods.is_empty():
			break
		var picked := _pick(rng, foods)
		foods.erase(picked)
		stock._add(picked, floor_no)
	return stock


static func _pick(rng: RandomNumberGenerator, pool: Array[ItemData]) -> ItemData:
	var total := 0.0
	for it in pool:
		total += ItemDB.RARITY_WEIGHT[it.rarity]
	var roll := rng.randf() * total
	for it in pool:
		roll -= ItemDB.RARITY_WEIGHT[it.rarity]
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
