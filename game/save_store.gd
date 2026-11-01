class_name SaveStore
extends RefCounted
## Kayıt slotlarının dosya işlemleri: `<klasör>/slot_1.json` ... `slot_3.json`.
##
## Güvenlik:
##  - Yazarken önce `.tmp` dosyasına yazılır ve geri okunup doğrulanır; ancak sonra ana dosyanın yerine geçer.
##  - Eski ana dosya `.bak` olarak saklanır. Ana dosya bozuksa yedekten okunur (`SaveSlot.recovered`).
##  - İkisi de bozuksa dosya SİLİNMEZ: `.corrupt` adıyla kenara alınır (elle kurtarılabilir), slot boş görünür.

const COUNT := 3
## Kayıt klasörü. Testler başka bir klasöre yönlendirir.
static var dir := "user://saves"


static func is_valid_index(i: int) -> bool:
	return i >= 0 and i < COUNT


static func path_of(i: int) -> String:
	return "%s/slot_%d.json" % [dir, i + 1]


## Üç slotun hepsi: dolu olan SaveSlot, boş olan null.
static func list_slots() -> Array:
	var out: Array = []
	for i in COUNT:
		out.append(load_slot(i))
	return out


## İlk boş (okunabilir kaydı olmayan) slot; hepsi doluysa -1.
static func first_free() -> int:
	for i in COUNT:
		if load_slot(i) == null:
			return i
	return -1


static func load_slot(i: int) -> SaveSlot:
	if not is_valid_index(i):
		return null
	var main := path_of(i)
	var s := _read(main, i)
	if s != null:
		return s
	s = _read(main + ".bak", i)
	if s != null:
		s.recovered = true
		return s
	# İkisi de okunamıyor: silme, kenara al (elle kurtarılabilir). Slot boş görünür.
	for p in [main, main + ".bak"]:
		if FileAccess.file_exists(p):
			_remove(p + ".corrupt")
			DirAccess.rename_absolute(p, p + ".corrupt")
	return null


static func save_slot(slot: SaveSlot) -> bool:
	if slot == null or not is_valid_index(slot.index):
		return false
	DirAccess.make_dir_recursive_absolute(dir)
	var main := path_of(slot.index)
	var tmp := main + ".tmp"
	var bak := main + ".bak"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(slot.to_dict(), "\t"))
	f.close()
	if _read(tmp, slot.index) == null:
		_remove(tmp)
		return false  # yazılan dosya geri okunamadı: ana dosyaya dokunma
	if FileAccess.file_exists(main):
		_remove(bak)
		DirAccess.rename_absolute(main, bak)
	return DirAccess.rename_absolute(tmp, main) == OK


## Slotu tamamen siler (ana dosya, yedek, kenara alınmış bozuk dosya).
static func delete_slot(i: int) -> bool:
	if not is_valid_index(i):
		return false
	var main := path_of(i)
	for p in [main, main + ".bak", main + ".tmp", main + ".corrupt", main + ".bak.corrupt"]:
		_remove(p)
	return not FileAccess.file_exists(main)


static func _read(path: String, i: int) -> SaveSlot:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return SaveSlot.from_dict(json.data, i)


static func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
