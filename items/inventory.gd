class_name Inventory
extends Node
## Oyuncunun eşyaları (oyuncunun çocuğu). Eşya eklenince Stats modifier'ları uygulanır, davranış betiği çalışır,
## aynı etiketten 3+ eşya varsa sinerji bonusu eklenir.

signal item_added(item: ItemData)
signal item_removed(item: ItemData)
signal changed

const SYNERGY_SOURCE := "synergy"
## Aynı etiketten bu kadar eşya = sinerji bonusu.
const SYNERGY_COUNT := 3

var player: Player
var items: Array[ItemData] = []

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


## Eşyayı ekler. Aynı eşya ikinci kez eklenirse etkileri üst üste biner.
func add(item: ItemData) -> void:
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
	changed.emit()
	EventBus.item_acquired.emit(player, item)


## Eşyayı çıkarır (en son eklenen kopya). Gerçek oyunda nadiren (Kara Kalem vb.), testlerde sık kullanılır.
func remove(item_id: String) -> bool:
	for i in range(_entries.size() - 1, -1, -1):
		var e := _entries[i]
		var item := e["item"] as ItemData
		if item.id != item_id:
			continue
		var fx := e["effect"] as ItemEffect
		player.stats.remove_modifiers(e["source"])
		if fx != null:
			fx.on_remove()
			fx.release()
		_entries.remove_at(i)
		items.erase(item)
		_refresh_synergies()
		item_removed.emit(item)
		changed.emit()
		return true
	return false


func has(item_id: String) -> bool:
	return count(item_id) > 0


func count(item_id: String) -> int:
	var n := 0
	for it in items:
		if it.id == item_id:
			n += 1
	return n


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


## HUD için: eşyaların kısa durum yazıları ("FAİZ 3" gibi), boş olanlar atlanır.
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


func _refresh_synergies() -> void:
	player.stats.remove_modifiers(SYNERGY_SOURCE)
	for tag in active_synergies():
		for m: Array in ItemDB.SYNERGIES[tag]:
			player.stats.add_modifier(SYNERGY_SOURCE, m[0], m[1], m[2])
