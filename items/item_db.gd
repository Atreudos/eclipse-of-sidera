class_name ItemDB
extends RefCounted
## Tüm eşyaların listesi ve ödül seçimi. Yeni eşya = `_build()` içine bir `_add({...})` bloğu
## (+ gerekirse items/effects/ altına davranış betiği).
##
## Etiketler: PARRY, DASH, MERMI, ALEV, BUZ, ZEHIR, CAN, RITIM, KARMA, ZAMAN, ALTIN, HAREKET, SAVUNMA.
## Sayılar (hasar, süre, fiyat) tasarımcının listesinden gelir; denge ayarı için burası ve items/effects/ yeterli.

const R := ItemData.Rarity
const S := ItemData.Slot

## Aynı etiketten 3 eşya olunca verilen küçük bonus: etiket -> [[stat, ekleme, çarpım], ...]
const SYNERGIES := {
	"PARRY": [["parry_window", 0.02, 1.0], ["parry_zone_radius", 6.0, 1.0]],
	"DASH": [["dash_recharge", 0.0, 0.85]],
	"RITIM": [["rhythm_gain", 0.0, 1.15]],
	"CAN": [["max_health", 1.0, 1.0]],
	"ALEV": [["attack_damage", 0.0, 1.15]],
	"BUZ": [["parry_window", 0.015, 1.0]],
}
## Sinerjilerin ekranda görünen açıklaması.
const SYNERGY_TEXT := {
	"PARRY": "Parry penceresi +0.02 sn, parry alanı +6 px",
	"DASH": "Dash şarjı %15 daha hızlı dolar",
	"RITIM": "Ritim %15 daha hızlı dolar",
	"CAN": "En çok can +1",
	"ALEV": "Hasar %15 artar",
	"BUZ": "Parry penceresi +0.015 sn",
}

## Seçim ağırlıkları (yaygın daha sık, lanetli nadir).
const RARITY_WEIGHT := [60.0, 30.0, 8.0, 14.0]

static var _all: Array[ItemData] = []
static var _by_id: Dictionary = {}


static func all() -> Array[ItemData]:
	if _all.is_empty():
		_build()
	return _all


static func get_item(item_id: String) -> ItemData:
	all()
	return _by_id.get(item_id) as ItemData


static func ids() -> Array[String]:
	var out: Array[String] = []
	for it in all():
		out.append(it.id)
	return out


## Sadece takılabilir eşyalar (ödül havuzu): yemekler hariç.
static func equipment() -> Array[ItemData]:
	var out: Array[ItemData] = []
	for it in all():
		if it.is_equippable():
			out.append(it)
	return out


## `spec` anahtarları: id, name, slot, desc, shadow, tags, rarity, price, mods, fx (betik dosya adı), umbra, heal, heal_all.
static func _add(spec: Dictionary) -> void:
	var it := ItemData.new()
	it.id = spec["id"]
	it.display_name = spec["name"]
	it.slot = spec["slot"]
	it.description = spec["desc"]
	it.shadow_text = spec.get("shadow", "")
	var tag_list: Array[String] = []
	for t in spec.get("tags", []):
		tag_list.append(t)
	it.tags = tag_list
	it.rarity = spec.get("rarity", R.COMMON)
	it.price = spec.get("price", 0)
	it.mods = spec.get("mods", [])
	it.umbra_allowed = spec.get("umbra", true)
	it.heal = spec.get("heal", 0)
	it.heal_all = spec.get("heal_all", false)
	var fx: String = spec.get("fx", "")
	if fx != "":
		it.effect_script = load("res://items/effects/" + fx) as Script
	_all.append(it)
	_by_id[it.id] = it


static func _build() -> void:
	# ------------------------------------------------------------ AYAK (1 slot)
	_add({
		"id": "mirror_boots", "name": "Ayna Tabanlı Çizmeler", "slot": S.FEET, "tags": ["DASH"], "rarity": R.RARE, "price": 55,
		"desc": "+1 ekstra dash hakkı verir.",
		"shadow": "Gölge de son savaşta sana karşı fazladan 1 dash atabilir. Kimse uçup kaçmıyor, eşitlik var.",
		"mods": [["dash_charges", 1.0, 1.0]], "fx": "extra_dash.gd",
	})
	_add({
		"id": "feather_boots", "name": "Hafif Tüy Botlar", "slot": S.FEET, "tags": ["HAREKET"], "rarity": R.COMMON, "price": 30,
		"desc": "Yürüme hızın %20 artar.",
		"shadow": "Gölge de seninle birebir aynı hızda yürür. Kim hızlıysa o vurur.",
		"mods": [["move_speed", 0.0, 1.2]],
	})
	# ------------------------------------------------------------ CHARM / KOLYE (3 slot)
	_add({
		"id": "viper_fang", "name": "Engerek Dişi Kolyesi", "slot": S.CHARM, "tags": ["PARRY", "ZEHIR"], "rarity": R.RARE, "price": 50,
		"desc": "Parry'lediğin düşmana zehir verir (saniyede 2 hasar).",
		"shadow": "O da seni parrylerse saniyede 2 hasar veren zehir bırakır. Güç birebir aynı.",
		"fx": "viper_fang.gd",
	})
	_add({
		"id": "stardust_brooch", "name": "Yıldız Tozu Broşu", "slot": S.CHARM, "tags": ["KARMA"], "rarity": R.COMMON, "price": 30,
		"desc": "Saldırıların düşmanı geri iter (geri itme 2 kat).",
		"shadow": "Gölge de sana vurduğunda seni aynı mesafede geriye iter.",
		"mods": [["knockback_mult", 0.0, 2.0]],
	})
	_add({
		"id": "vampire_relic", "name": "Vampir Yadigarı", "slot": S.CHARM, "tags": ["PARRY", "CAN"], "rarity": R.EPIC, "price": 95,
		"desc": "Başarılı her parry sana +3 can yeniler.",
		"shadow": "Gölge de seni parrylemeyi başarırsa kendine +1 can çeker. Yani parry atan kazanır.",
		"fx": "vampire_relic.gd",
	})
	# ------------------------------------------------------------ KAFA (2 slot)
	_add({
		"id": "guardian_helm", "name": "Antika Muhafız Kaskı", "slot": S.HEAD, "tags": ["SAVUNMA"], "rarity": R.COMMON, "price": 35,
		"desc": "Aldığın hasarları %15 azaltır.",
		"shadow": "Gölge de senden %15 daha az hasar alır. Dövüş biraz daha uzar ama tek yemezsin.",
		"mods": [["damage_taken", 0.0, 0.85]],
	})
	_add({
		"id": "watcher_band", "name": "Gözcü Bandı", "slot": S.HEAD, "tags": ["PARRY"], "rarity": R.COMMON, "price": 35,
		"desc": "Parry pencereni 0.1 saniye genişletir; parry atmak kolaylaşır.",
		"shadow": "Gölgenin de parry yapma penceresi 0.1 saniye genişler. İki taraf da usta birer parryci olur.",
		"mods": [["parry_window", 0.1, 1.0]],
	})
	# ------------------------------------------------------------ CEP (1 slot)
	_add({
		"id": "cracked_mirror", "name": "Çatlak El Aynası", "slot": S.POCKET, "tags": ["SAVUNMA", "CAN"], "rarity": R.RARE, "price": 60,
		"desc": "Canın sıfıra indiğinde ölümcül darbeyi engeller, seni 1 canla kurtarıp 2 saniye ölümsüz yapar. Tek kullanımlıktır, kırılır.",
		"shadow": "Gölge son savaşta canı sıfırlanınca 2. evresine geçer, tam canla dirilir!",
		"fx": "cracked_mirror.gd",
	})
	_add({
		"id": "saturn_hourglass", "name": "Satürn'ün Kum Saati", "slot": S.POCKET, "tags": ["PARRY", "ZAMAN"], "rarity": R.EPIC, "price": 120,
		"desc": "İki saldırıyı aynı anda parry'lersen zaman 1.5 saniye durur; sadece sen hareket edersin.",
		"fx": "saturn_hourglass.gd",
	})
	# ------------------------------------------------------------ BİLEK (1 slot)
	_add({
		"id": "thief_chain", "name": "Hırsızın Zinciri", "slot": S.WRIST, "tags": ["PARRY", "ALTIN"], "rarity": R.RARE, "price": 50,
		"desc": "Parry yaptığın düşmanlar yere fazladan antika para (altın) düşürür.",
		"fx": "thief_chain.gd",
	})
	# ------------------------------------------------------------ YEMEK (çantada durur, yenir)
	# Fazla iyileşme bağışıklık kalbine (mavi) dönüşür; bağışıklık kalbi varken yemek yenmez (bkz. Player.try_eat).
	_add({
		"id": "tower_bread", "name": "Kule Ekmeği", "slot": S.FOOD, "rarity": R.COMMON, "price": 6, "umbra": false, "heal": 1,
		"desc": "+1 kalp iyileştirir.",
	})
	_add({
		"id": "baked_sweet_potato", "name": "Fırınlanmış Tatlı Patates", "slot": S.FOOD, "rarity": R.COMMON, "price": 12, "umbra": false, "heal": 2,
		"desc": "+2 kalp iyileştirir. Canına sığmayan kısım bağışıklık kalbi olur.",
	})
	_add({
		"id": "cosmic_star_soup", "name": "Kozmik Yıldız Çorbası", "slot": S.FOOD, "rarity": R.RARE, "price": 24, "umbra": false, "heal_all": true,
		"desc": "Canı tamamen doldurur. Canına sığmayan kısım bağışıklık kalbi olur.",
	})


## Ödül sehpası için iki farklı eşya seçer (yemekler çıkmaz). Sahip olunan ve Umbra'ya gitmiş eşyalar havuzdan çıkar;
## havuz iki eşyadan azsa sahip olunanlar da dahil edilir. `rng` verilirse sonuç tekrarlanabilir.
static func roll_pair(rng: RandomNumberGenerator, owned_ids: Array = [], umbra_ids: Array = []) -> Array[ItemData]:
	var pool: Array[ItemData] = []
	for it in equipment():
		if not (it.id in owned_ids) and not (it.id in umbra_ids):
			pool.append(it)
	if pool.size() < 2:
		pool.clear()
		for it in equipment():
			if not (it.id in umbra_ids):
				pool.append(it)
	if pool.size() < 2:
		pool = equipment()
	var out: Array[ItemData] = []
	while out.size() < 2 and not pool.is_empty():
		var picked := _weighted_pick(rng, pool)
		out.append(picked)
		pool.erase(picked)
	return out


static func _weighted_pick(rng: RandomNumberGenerator, pool: Array[ItemData]) -> ItemData:
	var total := 0.0
	for it in pool:
		total += RARITY_WEIGHT[it.rarity]
	var roll := rng.randf() * total
	for it in pool:
		roll -= RARITY_WEIGHT[it.rarity]
		if roll <= 0.0:
			return it
	return pool[pool.size() - 1]
