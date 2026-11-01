class_name RunSnapshot
extends RefCounted
## Koşunun anlık görüntüsü (kayıt için): oyuncunun durumu, Umbra'nın eşyaları, istatistikler ve konum.
## Sözlük biçimindedir (JSON'a yazılır); sayılar dosyadan float gelebilir, o yüzden her okuma int()'e çevrilir.
##
## {"seed", "floor", "room", "wave", "player": {...}, "umbra": [id], "umbra_carry", "stats": {...}, "seen": [sahne adı]}
##   floor: 1'den, room: kat içi 0'dan (Normal kip); wave: 1'den (Sınırsız kip).

## Oyuncunun durumu: can, bağışıklık, altın, takılı eşyalar (sırayla) ve çanta.
static func capture_player(p: Player) -> Dictionary:
	var equipped: Array = []
	for it in p.inventory.items:
		equipped.append(it.id)
	var bag: Array = []
	for e in p.inventory.bag:
		bag.append({"id": (e["item"] as ItemData).id, "count": int(e["count"])})
	return {"health": p.health, "immunity": p.immunity, "gold": p.gold, "equipped": equipped, "bag": bag}


## Kayıttaki durumu oyuncuya uygular. Tanınmayan eşya kimlikleri (silinmiş eşyalar) atlanır.
static func apply_player(p: Player, d: Dictionary) -> void:
	var inv := p.inventory
	inv.clear_all()
	var equipped: Variant = d.get("equipped", [])
	if equipped is Array:
		for id in equipped:
			var item := ItemDB.get_item(str(id))
			if item != null and inv.give(item) == "":
				inv.equip(item)
	var bag: Variant = d.get("bag", [])
	if bag is Array:
		for e in bag:
			if not (e is Dictionary):
				continue
			var item := ItemDB.get_item(str((e as Dictionary).get("id", "")))
			if item == null:
				continue
			var n := clampi(SaveSlot._int((e as Dictionary).get("count", 1), 1), 1, 99)
			for k in n:
				if inv.give(item) != "":
					break
	p.set_immunity(maxi(SaveSlot._int(d.get("immunity", 0)), 0))
	p.gold = maxi(SaveSlot._int(d.get("gold", 0)), 0)
	p.gold_changed.emit(p.gold)
	p.health = clampi(SaveSlot._int(d.get("health", 1), 1), 1, p.stats.int_value("max_health"))


## Umbra'ya bırakılan eşyaların kimlikleri ve taşıma artışı.
static func capture_umbra() -> Dictionary:
	var ids: Array = []
	for it in GameState.umbra_items:
		ids.append(it.id)
	return {"umbra": ids, "umbra_carry": GameState.umbra_extra_carry}


static func apply_umbra(d: Dictionary) -> void:
	GameState.umbra_items.clear()
	var ids: Variant = d.get("umbra", [])
	if ids is Array:
		for id in ids:
			var item := ItemDB.get_item(str(id))
			if item != null:
				GameState.umbra_items.append(item)
	GameState.umbra_extra_carry = maxi(SaveSlot._int(d.get("umbra_carry", 0)), 0)
	GameState.umbra_changed.emit()


## Koşu istatistiklerinin kayıtlı kopyası (yalnızca sayılar).
static func capture_stats(stats: Dictionary) -> Dictionary:
	return {
		"kills": int(stats.get("kills", 0)),
		"rooms_cleared": int(stats.get("rooms_cleared", 0)),
		"best_combo": int(stats.get("best_combo", 0)),
		"time": snappedf(float(stats.get("time", 0.0)), 0.1),
	}


## Kayıttaki istatistikleri `stats` sözlüğüne işler (eksik alanlar olduğu gibi kalır).
static func apply_stats(stats: Dictionary, d: Dictionary) -> void:
	stats["kills"] = maxi(SaveSlot._int(d.get("kills", 0)), 0)
	stats["rooms_cleared"] = maxi(SaveSlot._int(d.get("rooms_cleared", 0)), 0)
	stats["best_combo"] = maxi(SaveSlot._int(d.get("best_combo", 0)), 0)
	stats["time"] = maxf(SaveSlot._num(d.get("time", 0.0)), 0.0)
