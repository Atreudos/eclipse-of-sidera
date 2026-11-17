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
##
## SİLAH TEKLİFLERİ (rafın üçüncü satırı): sahip olunan her silah için, seviyesi en üstte değilse BİR yükseltme ("KILIÇ 2 > 3") ve
## sahip olunmayan satılık silah için (yumruk) "yeni silah" teklifi. Fiyatlar WeaponDB'den, kata göre eşyalarla aynı oranda artar.
## Her silah için kat başına en çok bir yükseltme alınır (satılan teklif o kat boş kalır). Silah teklifleri oyuncunun o andaki
## donanımından kurulur; satın alırken yeniden doğrulanır.

class Offer extends RefCounted:
	var item: ItemData
	var price := 0
	var sold := false
	## Silah teklifi ise silahın kimliği ("" = eşya / yemek), türü ("unlock" ya da "upgrade") ve yükseltmede ulaşılacak seviye.
	var weapon_id := ""
	var weapon_kind := ""
	var to_level := 0

	func is_weapon() -> bool:
		return weapon_id != ""

const WEAPON_UNLOCK := "unlock"
const WEAPON_UPGRADE := "upgrade"

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


## Raf üretir. `rng` aynıysa (ve sahip olunanlar aynıysa) raf aynıdır. `loadout` verilirse silah teklifleri de eklenir (rastgelelik yok).
static func generate(rng: RandomNumberGenerator, floor_no: int, owned_ids: Array = [], umbra_ids: Array = [], loadout: WeaponLoadout = null) -> ShopStock:
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
	stock.add_weapon_offers(loadout, floor_no)
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


## Taban fiyatı kata göre artırır (eşyalarla aynı oran).
static func scaled_price(base: int, floor_no: int) -> int:
	return maxi(roundi(float(base) * (1.0 + PRICE_STEP * float(maxi(floor_no, 1) - 1))), 1)


## Silah tekliflerini ekler (yoksa): önce slotlardaki silahlar (J, I), sonra yedektekiler, sonra satılık yeni silahlar.
func add_weapon_offers(loadout: WeaponLoadout, floor_no: int) -> void:
	if loadout == null or has_weapon_offers():
		return
	var order: Array[String] = []
	for id in loadout.slots:
		if id != "" and not (id in order):
			order.append(id)
	for id in loadout.reserve_ids():
		if not (id in order):
			order.append(id)
	for id in order:
		var lv := loadout.level_of(id)
		if lv < WeaponDB.max_level(id):
			_add_weapon(id, WEAPON_UPGRADE, lv + 1, floor_no)
	for id in WeaponDB.ids():
		if not loadout.owns(id) and WeaponDB.unlock_price(id) > 0:
			_add_weapon(id, WEAPON_UNLOCK, 1, floor_no)


func has_weapon_offers() -> bool:
	for o in offers:
		if o.is_weapon():
			return true
	return false


func _add_weapon(id: String, kind: String, to_level: int, floor_no: int) -> Offer:
	var o := Offer.new()
	o.weapon_id = id
	o.weapon_kind = kind
	o.to_level = to_level
	if kind == WEAPON_UNLOCK:
		o.item = WeaponDB.unlock_display(id)
		o.price = scaled_price(WeaponDB.unlock_price(id), floor_no)
	else:
		o.item = WeaponDB.upgrade_display(id, to_level)
		o.price = scaled_price(WeaponDB.upgrade_cost(id, to_level), floor_no)
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
	if o.is_weapon():
		return _buy_weapon(player, o)
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


## Silah teklifini satın alır: teklif hâlâ geçerli mi (silah sahiplik ve seviye) bakılır, altın düşülür, silah verilir / yükseltilir.
## Yeni silah kendiliğinden aynı türden silahın yerine takılır (öncekinin yerini envanterden geri değiştirebilirsin).
func _buy_weapon(player: Player, o: Offer) -> String:
	var lo := player.loadout
	if lo == null:
		return "SİLAH YOK"
	if o.weapon_kind == WEAPON_UNLOCK:
		if lo.owns(o.weapon_id):
			return "ZATEN SAHİPSİN"
	else:
		if not lo.owns(o.weapon_id):
			return "BU SİLAH SENDE YOK"
		if lo.level_of(o.weapon_id) >= o.to_level:
			return "ZATEN YÜKSELTİLDİ"
		if lo.level_of(o.weapon_id) + 1 != o.to_level:
			return "ÖNCE ÖNCEKİ SEVİYE"
	if player.gold < o.price:
		return "YETERLİ ALTIN YOK"
	if not player.spend_gold(o.price):
		return "YETERLİ ALTIN YOK"
	var reason := lo.grant(o.weapon_id) if o.weapon_kind == WEAPON_UNLOCK else lo.upgrade(o.weapon_id)
	if reason != "":
		player.add_gold(o.price)  # olmaması gereken durum: parayı geri ver
		return reason
	o.sold = true
	EventBus.item_purchased.emit(player, o.item, o.price)
	return ""


# ---------------------------------------------------------------- kayıt

## Kayıt için: [{"id", "price", "sold"}, ...]; silah tekliflerine "weapon", "kind", "level" da yazılır.
func to_array() -> Array:
	var out: Array = []
	for o in offers:
		var e := {"id": o.item.id, "price": o.price, "sold": o.sold}
		if o.is_weapon():
			e["weapon"] = o.weapon_id
			e["kind"] = o.weapon_kind
			e["level"] = o.to_level
		out.append(e)
	return out


## Kayıttan raf kurar. Tanınmayan eşya kimlikleri (silinmiş eşyalar) atlanır.
static func from_array(data: Variant) -> ShopStock:
	var stock := ShopStock.new()
	if not (data is Array):
		return stock
	for e in data:
		if not (e is Dictionary):
			continue
		var weapon_id := str((e as Dictionary).get("weapon", ""))
		if weapon_id != "":
			var kind := str((e as Dictionary).get("kind", ""))
			if not WeaponDB.has(weapon_id) or not (kind in [WEAPON_UNLOCK, WEAPON_UPGRADE]):
				continue
			var level := clampi(SaveSlot._int((e as Dictionary).get("level", 1), 1), 1, WeaponDB.max_level(weapon_id))
			if kind == WEAPON_UPGRADE and level < 2:
				continue
			var w := stock._add_weapon(weapon_id, kind, level, 1)
			w.price = maxi(SaveSlot._int((e as Dictionary).get("price", w.price), w.price), 1)
			w.sold = bool((e as Dictionary).get("sold", false))
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
