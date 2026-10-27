class_name Stats
extends RefCounted
## Bir aktörün sayısal değerleri. Eşyalar (Aşama 3) buraya "modifier" ekleyerek çalışır:
##   değer = (taban + toplam_ekleme) * toplam_çarpım
## Her modifier bir "kaynak"a (genelde eşya) bağlıdır; kaynak kaldırılınca etkisi de gider.

signal changed

var base: Dictionary = {}
var _mods: Dictionary = {}  # kaynak -> [{stat, add, mul}, ...]


func _init(base_values: Dictionary = {}) -> void:
	base = base_values.duplicate()


## `default_base`: bu stat taban değerlerde yoksa kullanılacak taban (örn. çarpan statları için 1.0).
func value(stat: String, default_base: float = 0.0) -> float:
	var add := 0.0
	var mul := 1.0
	for source in _mods:
		for m: Dictionary in _mods[source]:
			if m["stat"] == stat:
				add += m["add"]
				mul *= m["mul"]
	return (float(base.get(stat, default_base)) + add) * mul


func int_value(stat: String) -> int:
	return roundi(value(stat))


func set_base(stat: String, new_value: float) -> void:
	base[stat] = new_value
	changed.emit()


func add_modifier(source: Variant, stat: String, add: float = 0.0, mul: float = 1.0) -> void:
	if not _mods.has(source):
		_mods[source] = []
	_mods[source].append({"stat": stat, "add": add, "mul": mul})
	changed.emit()


func remove_modifiers(source: Variant) -> void:
	if _mods.erase(source):
		changed.emit()
