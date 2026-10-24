class_name ItemDB
extends RefCounted
## Tüm eşyaların listesi ve ödül seçimi. Yeni eşya = `_build()` içine bir `_add(...)` satırı
## (+ gerekirse items/effects/ altına davranış betiği).
##
## Etiketler: PARRY, DASH, MERMI, ALEV, BUZ, ZEHIR, CAN, RITIM, KARMA.

const R := ItemData.Rarity

## Aynı etiketten 3 eşya olunca verilen küçük bonus: etiket -> [[stat, ekleme, çarpım], ...]
const SYNERGIES := {
	"PARRY": [["parry_window", 0.02, 1.0], ["parry_zone_radius", 6.0, 1.0]],
	"DASH": [["dash_recharge", 0.0, 0.85]],
	"RITIM": [["rhythm_gain", 0.0, 1.15]],
	"CAN": [["max_health", 1.0, 1.0]],
	"ALEV": [["attack_damage", 0.0, 1.15]],
	"BUZ": [["parry_window", 0.015, 1.0]],
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


static func _add(item_id: String, item_name: String, desc: String, tags: Array[String], rarity: ItemData.Rarity, mods: Array = [], effect_path: String = "", umbra_allowed: bool = true) -> void:
	var it := ItemData.new()
	it.id = item_id
	it.display_name = item_name
	it.description = desc
	it.tags = tags
	it.rarity = rarity
	it.mods = mods
	it.umbra_allowed = umbra_allowed
	if effect_path != "":
		it.effect_script = load(effect_path) as Script
	_all.append(it)
	_by_id[item_id] = it


static func _build() -> void:
	const FX := "res://items/effects/"
	# --- Parry
	_add("golden_tooth", "Altın Diş", "Parry penceresi +0.04 sn.", ["PARRY"], R.COMMON, [["parry_window", 0.04, 1.0]])
	_add("echo_bullet", "Yankılı Mermi", "Parry'lediğin mermi 3'e bölünür.", ["PARRY", "MERMI"], R.RARE, [], FX + "echo_bullet.gd")
	_add("cold_blood", "Soğukkanlı", "Parry'den sonra 1 sn boyunca dash şarjı harcanmaz.", ["PARRY", "DASH"], R.RARE, [], FX + "cold_blood.gd")
	# --- Dash
	_add("third_charge", "Üçüncü Şarj", "+1 dash şarjı ama dash mesafesi kısalır.", ["DASH"], R.RARE, [["dash_charges", 1.0, 1.0], ["dash_speed", 0.0, 0.88]], FX + "third_charge.gd")
	_add("ghost_step", "Hayalet Adım", "Dash sırasında düşmanların içinden geçersin.", ["DASH"], R.RARE, [], FX + "ghost_step.gd")
	_add("interest", "Faiz", "Her dash hasar biriktirir (en çok 6), parry'de hepsi etrafa patlar.", ["DASH", "PARRY"], R.RARE, [], FX + "interest.gd")
	# --- Ritim
	_add("restless", "Kıpırdama", "Ritim çok daha yavaş düşer, ama daha yavaş dolar.", ["RITIM"], R.COMMON, [["rhythm_decay", 0.0, 0.55], ["rhythm_gain", 0.0, 0.8]])
	_add("euphoria", "Coşku", "Coşkulu kademede hasar +%50, ama hasar alınca ritim sıfırlanır.", ["RITIM"], R.RARE, [], FX + "euphoria.gd")
	# --- Element
	_add("spark", "Kıvılcım", "Vuruşların düşmanı tutuşturur (yanma hasarı verir).", ["ALEV"], R.COMMON, [], FX + "spark.gd")
	_add("frost", "Don", "Parry'lediğin düşman uzun süre donar.", ["BUZ", "PARRY"], R.COMMON, [], FX + "frost.gd")
	# --- Lanetli (risk / ödül)
	_add("glass_heart", "Cam Kalp", "Canın 1'e düşer, parry penceresi iki katı olur.", ["PARRY", "CAN"], R.CURSED, [["parry_window", 0.0, 2.0]], FX + "glass_heart.gd")
	_add("open_door", "Aç Kapı", "Hasarın iki katı, ama Umbra her pusuda fazladan bir eşya taşır.", ["KARMA"], R.CURSED, [["attack_damage", 0.0, 2.0]], FX + "open_door.gd")


## Ödül sehpası için iki farklı eşya seçer. Sahip olunan ve Umbra'ya gitmiş eşyalar havuzdan çıkar;
## havuz iki eşyadan azsa sahip olunanlar da dahil edilir. `rng` verilirse sonuç tekrarlanabilir.
static func roll_pair(rng: RandomNumberGenerator, owned_ids: Array = [], umbra_ids: Array = []) -> Array[ItemData]:
	var pool: Array[ItemData] = []
	for it in all():
		if not (it.id in owned_ids) and not (it.id in umbra_ids):
			pool.append(it)
	if pool.size() < 2:
		pool.clear()
		for it in all():
			if not (it.id in umbra_ids):
				pool.append(it)
	if pool.size() < 2:
		pool = all().duplicate()
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
