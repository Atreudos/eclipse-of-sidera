class_name Inventory
extends Node
## Oyuncunun eşyaları (oyuncunun çocuğu): ÇANTA (takılmamış eşyalar ve yemekler) + TAKILI eşyalar (slotlar).
##
##   give(item)    eşyayı çantaya koyar (yerde bulunan/alınan eşya)
##   equip(item)   çantadaki eşyayı slotuna takar (yer yoksa reddeder)
##   unequip(item) takılı eşyayı çantaya geri koyar
##   add(item)     give + (yer varsa) equip: testler ve geliştirici menüsü için kısayol
##   use(item)     çantadaki yemeği yer (bağışıklık kuralları Player.try_eat'te)
##   remove(id) / destroy(item)  takılı eşyayı yok eder (tek kullanımlık eşyalar, testler)
##
## Her işlem "" (başarılı) ya da ekrana yazılacak kısa bir neden metni döndürür.
## Takılan eşyanın Stats modifier'ları uygulanır, davranış betiği çalışır; aynı etiketten 3+ eşya takılıysa sinerji bonusu eklenir.

signal item_added(item: ItemData)
signal item_removed(item: ItemData)
## Çanta ya da takılı eşyalar değişti (envanter ekranı yenilenir).
signal changed

const SYNERGY_SOURCE := "synergy"
## Aynı etiketten bu kadar eşya = sinerji bonusu.
const SYNERGY_COUNT := 3
## Çantadaki hücre sayısı (aynı eşyanın kopyaları tek hücrede yığılır).
const BAG_SIZE := 24

var player: Player
## TAKILI (etkin) eşyalar, takılma sırasıyla.
var items: Array[ItemData] = []
## Çanta: [{"item": ItemData, "count": int}, ...]
var bag: Array[Dictionary] = []

var _entries: Array[Dictionary] = []
var _serial := 0


func _ready() -> void:
	player = get_parent() as Player


func _exit_tree() -> void:
	# Sahne kapanırken eşyaların EventBus bağlantıları kopsun.
	for e in _entries:
		var fx := e["effect"] as ItemEffect
		if fx != null:
			fx.release()


# ---------------------------------------------------------------- çanta

## Eşyayı çantaya koyar. Aynı eşya varsa yığılır. Başarılıysa "".
func give(item: ItemData) -> String:
	var idx := _bag_index(item.id)
	if idx >= 0:
		bag[idx]["count"] = int(bag[idx]["count"]) + 1
	else:
		if bag.size() >= BAG_SIZE:
			return "ÇANTA DOLU"
		bag.append({"item": item, "count": 1})
	changed.emit()
	if player != null:
		EventBus.item_acquired.emit(player, item)
	return ""


## Çantadaki bir kopyayı kaldırır (yığın bitince hücre boşalır). Yoksa false.
func take_from_bag(item_id: String) -> bool:
	var idx := _bag_index(item_id)
	if idx < 0:
		return false
	var n := int(bag[idx]["count"]) - 1
	if n <= 0:
		bag.remove_at(idx)
	else:
		bag[idx]["count"] = n
	return true


func bag_count(item_id: String) -> int:
	var idx := _bag_index(item_id)
	return int(bag[idx]["count"]) if idx >= 0 else 0


func bag_free() -> int:
	return BAG_SIZE - bag.size()


func _bag_index(item_id: String) -> int:
	for i in bag.size():
		if (bag[i]["item"] as ItemData).id == item_id:
			return i
	return -1


# ---------------------------------------------------------------- slotlar

## Slottaki takılı eşyalar (takılma sırasıyla).
func equipped_in(slot: ItemData.Slot) -> Array[ItemData]:
	var out: Array[ItemData] = []
	for it in items:
		if it.slot == slot:
			out.append(it)
	return out


## Slotta kaç boş yer var.
func slot_free(slot: ItemData.Slot) -> int:
	return int(ItemData.SLOT_CAPACITY.get(slot, 0)) - equipped_in(slot).size()


## Çantadaki eşyayı slotuna takar. Başarılıysa "".
func equip(item: ItemData) -> String:
	if not item.is_equippable():
		return "BU TAKILMAZ"
	if _bag_index(item.id) < 0:
		return "ÇANTADA YOK"
	if slot_free(item.slot) <= 0:
		return "%s SLOTLARI DOLU" % item.slot_name()
	take_from_bag(item.id)
	_activate(item)
	changed.emit()
	if player != null:
		EventBus.item_equipped.emit(player, item)
	return ""


## Çantadaki eşyayı takar; tek kapasiteli slot doluysa oradaki eşyayla YER DEĞİŞTİRİR (envanter ekranı bunu kullanır).
## Çok kapasiteli slot doluysa reddeder (önce biri elle çıkarılır). Başarılıysa "".
func swap_in(item: ItemData) -> String:
	if not item.is_equippable():
		return "BU TAKILMAZ"
	if _bag_index(item.id) < 0:
		return "ÇANTADA YOK"
	if slot_free(item.slot) > 0:
		return equip(item)
	var occupants := equipped_in(item.slot)
	if occupants.size() != 1:
		return "%s SLOTLARI DOLU" % item.slot_name()
	var old: ItemData = occupants[0]
	# Eski eşya çantaya dönecek: yeni eşya çantadaki son kopyaysa onun hücresi boşalır, yoksa yer gerekir.
	var frees_cell := bag_count(item.id) == 1
	if _bag_index(old.id) < 0 and not frees_cell and bag.size() >= BAG_SIZE:
		return "ÇANTA DOLU"
	_deactivate(_entry_index(old.id))
	take_from_bag(item.id)
	_activate(item)
	var existing := _bag_index(old.id)
	if existing >= 0:
		bag[existing]["count"] = int(bag[existing]["count"]) + 1
	else:
		bag.append({"item": old, "count": 1})
	changed.emit()
	if player != null:
		EventBus.item_unequipped.emit(player, old)
		EventBus.item_equipped.emit(player, item)
	return ""


## Takılı eşyayı çıkarıp çantaya koyar. Başarılıysa "".
func unequip(item: ItemData) -> String:
	var idx := _entry_index(item.id)
	if idx < 0:
		return "TAKILI DEĞİL"
	if _bag_index(item.id) < 0 and bag.size() >= BAG_SIZE:
		return "ÇANTA DOLU"
	_deactivate(idx)
	var existing := _bag_index(item.id)
	if existing >= 0:
		bag[existing]["count"] = int(bag[existing]["count"]) + 1
	else:
		bag.append({"item": item, "count": 1})
	changed.emit()
	if player != null:
		EventBus.item_unequipped.emit(player, item)
	return ""


## Kısayol: çantaya koy, slotta yer varsa tak. (Yemekler çantada kalır.)
func add(item: ItemData) -> String:
	var r := give(item)
	if r != "":
		return r
	if item.is_equippable() and slot_free(item.slot) > 0:
		return equip(item)
	return ""


## Çantadaki yemeği yer. Yenirse "" (bir adet düşer), yenmezse nedeni.
func use(item: ItemData) -> String:
	if not item.is_food():
		return "BU YENMEZ"
	if _bag_index(item.id) < 0:
		return "ÇANTADA YOK"
	if player == null:
		return "OYUNCU YOK"
	var reason := player.try_eat(item)
	if reason != "":
		return reason
	take_from_bag(item.id)
	changed.emit()
	return ""


# ---------------------------------------------------------------- yok etme

## Takılı eşyayı (en son takılan kopya) yok eder; çantaya dönmez. Takılı değilse çantadakini siler.
func remove(item_id: String) -> bool:
	var idx := _entry_index(item_id)
	if idx >= 0:
		var item := _entries[idx]["item"] as ItemData
		_deactivate(idx)
		changed.emit()
		if player != null:
			EventBus.item_unequipped.emit(player, item)
		return true
	if take_from_bag(item_id):
		changed.emit()
		return true
	return false


func destroy(item: ItemData) -> bool:
	return remove(item.id)


## Her şeyi (çanta + takılılar) boşaltır.
func clear_all() -> void:
	while not _entries.is_empty():
		_deactivate(_entries.size() - 1)
	bag.clear()
	changed.emit()


# ---------------------------------------------------------------- sorgular

## Takılı mı?
func has(item_id: String) -> bool:
	return count(item_id) > 0


## Takılı kopya sayısı.
func count(item_id: String) -> int:
	var n := 0
	for it in items:
		if it.id == item_id:
			n += 1
	return n


## Takılı + çantadaki toplam kopya.
func owned_count(item_id: String) -> int:
	return count(item_id) + bag_count(item_id)


## Takılı eşyalar arasında bu etiketten kaç tane var.
func tag_count(tag: String) -> int:
	var n := 0
	for it in items:
		if it.has_tag(tag):
			n += 1
	return n


## Eşyanın davranış betiği (yoksa null).
func effect_of(item_id: String) -> ItemEffect:
	for e in _entries:
		if (e["item"] as ItemData).id == item_id:
			return e["effect"] as ItemEffect
	return null


## HUD için: eşyaların kısa durum yazıları ("ZAMAN DURDU" gibi), boş olanlar atlanır.
func status_lines() -> Array[String]:
	var out: Array[String] = []
	for e in _entries:
		var fx := e["effect"] as ItemEffect
		if fx != null:
			var t := fx.hud_text()
			if t != "":
				out.append(t)
	return out


## Aktif sinerjiler: etiket -> eşya sayısı (SYNERGY_COUNT ve üstü).
func active_synergies() -> Dictionary:
	var out := {}
	for tag in ItemDB.SYNERGIES:
		var n := tag_count(tag)
		if n >= SYNERGY_COUNT:
			out[tag] = n
	return out


# ---------------------------------------------------------------- iç işler

func _entry_index(item_id: String) -> int:
	for i in range(_entries.size() - 1, -1, -1):
		if (_entries[i]["item"] as ItemData).id == item_id:
			return i
	return -1


## Eşyayı etkinleştirir: modifier'lar, davranış betiği.
func _activate(item: ItemData) -> void:
	if player == null:
		player = get_parent() as Player
	var source := "item:%s:%d" % [item.id, _serial]
	_serial += 1
	for m: Array in item.mods:
		player.stats.add_modifier(source, m[0], m[1], m[2])
	var fx: ItemEffect = null
	if item.effect_script != null:
		fx = item.effect_script.new() as ItemEffect
		fx.owner = player
		fx.data = item
	_entries.append({"item": item, "source": source, "effect": fx})
	items.append(item)
	if fx != null:
		fx.on_acquire()
	_refresh_synergies()
	item_added.emit(item)


## `_entries[idx]` eşyasını devre dışı bırakır (modifier'lar gider, betik kapanır).
func _deactivate(idx: int) -> void:
	var e := _entries[idx]
	var item := e["item"] as ItemData
	var fx := e["effect"] as ItemEffect
	player.stats.remove_modifiers(e["source"])
	if fx != null:
		fx.on_remove()
		fx.release()
	_entries.remove_at(idx)
	items.clear()
	for entry in _entries:
		items.append(entry["item"])
	_refresh_synergies()
	item_removed.emit(item)


func _refresh_synergies() -> void:
	player.stats.remove_modifiers(SYNERGY_SOURCE)
	for tag in active_synergies():
		for m: Array in ItemDB.SYNERGIES[tag]:
			player.stats.add_modifier(SYNERGY_SOURCE, m[0], m[1], m[2])
