class_name WeaponLoadout
extends RefCounted
## Oyuncunun silahları: iki SLOT (0 = J, 1 = I) ve sahip olunan silahların seviyeleri.
## Koşuya kılıç (J) ve sapanla (I) başlanır; yumruk dükkândan alınır. Her silah slotlara serbestçe takılır (Cuphead gibi):
## kılıcı I'ya, sapanı J'ye de koyabilirsin. İki slotta AYNI silah olmaz; tuttuğun silahı diğer slottakiyle değiştirirsen yer değiştirirler.
## Mantık burada; Player slottaki silahı kullanır, envanter ekranı ve dükkân değiştirir.
##
## Her işlem "" (başarılı) ya da ekrana yazılacak kısa bir neden metni döndürür.

signal changed

## Slotlardaki silah kimlikleri (WeaponDB.SLOT_COUNT kadar).
var slots: Array[String] = []
## Sahip olunan silah -> seviye (1..WeaponDB.max_level).
var levels: Dictionary = {}


func _init() -> void:
	reset()


## Başlangıç silahlarına döner (yeni koşu).
func reset() -> void:
	slots = []
	for id in WeaponDB.start_slots():
		slots.append(id)
	levels = {}
	for id in WeaponDB.start_owned():
		levels[id] = 1
	changed.emit()


# ---------------------------------------------------------------- sorgular

## `slot`taki silah ("" = boş ya da geçersiz slot).
func weapon_in(slot: int) -> String:
	if slot < 0 or slot >= slots.size():
		return ""
	return slots[slot]


func owns(id: String) -> bool:
	return levels.has(id)


## Silahın seviyesi (sahip değilsen 0).
func level_of(id: String) -> int:
	return int(levels.get(id, 0))


## Silah hangi slotta takılı (-1 = takılı değil).
func slot_of(id: String) -> int:
	return slots.find(id)


## Slottaki silahın seviyesi.
func level_in(slot: int) -> int:
	return level_of(weapon_in(slot))


## Sahip olunan silahlar (WeaponDB.order() sırasıyla).
func owned_ids() -> Array[String]:
	var out: Array[String] = []
	for id in WeaponDB.order():
		if levels.has(id):
			out.append(id)
	return out


## Sahip olunup hiçbir slota takılı olmayan silahlar.
func reserve_ids() -> Array[String]:
	var out: Array[String] = []
	for id in owned_ids():
		if slot_of(id) < 0:
			out.append(id)
	return out


## Slottaki silahın tuşu ("J" / "I").
static func key_of(slot: int) -> String:
	return WeaponDB.SLOT_KEYS[slot] if slot >= 0 and slot < WeaponDB.SLOT_KEYS.size() else ""


# ---------------------------------------------------------------- değişiklik

## Silahı kazanır (seviye 1). `auto_equip` açıksa aynı türden silahın yerine (yoksa 1. slota) takılır; eskisi sahipliğinde kalır.
## Zaten varsa ya da böyle bir silah yoksa neden metni döner.
func grant(id: String, auto_equip: bool = true) -> String:
	if not WeaponDB.has(id):
		return "BÖYLE BİR SİLAH YOK"
	if owns(id):
		return "ZATEN VAR"
	levels[id] = 1
	if auto_equip:
		var target := 0
		for i in slots.size():
			if WeaponDB.kind(slots[i]) == WeaponDB.kind(id):
				target = i
				break
		slots[target] = id
	changed.emit()
	return ""


## `id` silahını `slot`a takar. Silah öbür slottaysa iki slot YER DEĞİŞTİRİR; aksi halde slottaki silah yedeğe geçer.
func equip(slot: int, id: String) -> String:
	if slot < 0 or slot >= slots.size():
		return "GEÇERSİZ SLOT"
	if not owns(id):
		return "SİLAH YOK"
	if slots[slot] == id:
		return ""
	var other := slot_of(id)
	if other >= 0:
		var tmp := slots[slot]
		slots[slot] = id
		slots[other] = tmp
	else:
		slots[slot] = id
	changed.emit()
	return ""


## Slottaki silahı sahip olunanlar arasında bir sonrakiyle (step = 1) ya da öncekiyle (step = -1) değiştirir.
## Envanter ekranı bunu kullanır; sahip olunan tek silah varsa bir şey yapmaz.
func cycle(slot: int, step: int = 1) -> String:
	var owned := owned_ids()
	if slot < 0 or slot >= slots.size() or owned.size() < 2:
		return "BAŞKA SİLAH YOK"
	var idx := owned.find(slots[slot])
	var next_id := owned[posmod(idx + step, owned.size())]
	return equip(slot, next_id)


## İki slottaki silahları yer değiştirir (J <-> I).
func swap_slots() -> void:
	if slots.size() < 2:
		return
	var tmp := slots[0]
	slots[0] = slots[1]
	slots[1] = tmp
	changed.emit()


func can_upgrade(id: String) -> bool:
	return owns(id) and level_of(id) < WeaponDB.max_level(id)


## Silahı bir seviye yükseltir (bedeli dükkân çeker; burada para yok). Başarılıysa "".
func upgrade(id: String) -> String:
	if not owns(id):
		return "SİLAH YOK"
	if not can_upgrade(id):
		return "EN ÜST SEVİYE"
	levels[id] = level_of(id) + 1
	changed.emit()
	return ""


# ---------------------------------------------------------------- kayıt

func to_dict() -> Dictionary:
	var lv := {}
	for id in levels:
		lv[id] = int(levels[id])
	return {"slots": slots.duplicate(), "levels": lv}


## Kayıttan kurar. Bozuk/eksik kayıtta (eski sürüm dahil) başlangıç silahlarına döner; bilinmeyen silahlar atılır,
## slotlar sahip olunan ve birbirinden farklı silahlarla doldurulur.
func from_dict(d: Dictionary) -> void:
	var lv: Variant = d.get("levels", null)
	if not (lv is Dictionary) or (lv as Dictionary).is_empty():
		reset()
		return
	levels = {}
	for id in (lv as Dictionary):
		var key := String(id)
		if WeaponDB.has(key):
			levels[key] = WeaponDB.clamp_level(key, int((lv as Dictionary)[id]))
	for id in WeaponDB.start_owned():
		if not levels.has(id):
			levels[id] = 1  # başlangıç silahları hiç kaybolmaz
	var wanted: Array = d.get("slots", [])
	slots = []
	for i in WeaponDB.SLOT_COUNT:
		var id := String(wanted[i]) if i < wanted.size() else ""
		if id == "" or not levels.has(id) or slots.has(id):
			id = ""
		slots.append(id)
	# Boş kalan slotları sahip olunan, takılı olmayan silahlarla doldur (öncelik başlangıç sırası).
	for i in slots.size():
		if slots[i] != "":
			continue
		for id in owned_ids():
			if not slots.has(id):
				slots[i] = id
				break
	changed.emit()
