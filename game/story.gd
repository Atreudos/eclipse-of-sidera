class_name Story
extends RefCounted
## Hikâye bayrakları: kayıt dosyasındaki `SaveSlot.story` sözlüğünün üstünde ince bir yardımcı.
## Bayrak değeri bool, int ya da kısa yazı olabilir. Kayıt yoksa (test, deneme) bellekteki geçici sözlük kullanılır.

static var _fallback: Dictionary = {}


static func _store() -> Dictionary:
	var gs := Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs != null and gs.get("slot") != null:
		return gs.slot.story
	return _fallback


static func reset_fallback() -> void:
	_fallback = {}


static func get_flag(key: String, default: Variant = false) -> Variant:
	return _store().get(key, default)


static func has(key: String) -> bool:
	var v: Variant = _store().get(key, false)
	return v != false and v != 0 and v != ""


static func set_flag(key: String, value: Variant = true) -> void:
	_store()[key] = value


static func add(key: String, amount: int = 1) -> int:
	var n := int(_store().get(key, 0)) + amount
	_store()[key] = n
	return n


## "a" ya da "a,b" (hepsi) / "a|b" (biri) biçiminde koşul. Boş koşul her zaman doğrudur; "!a" olumsuzlar.
static func check_cond(cond: String) -> bool:
	if cond == "":
		return true
	if cond.contains("|"):
		for part in cond.split("|"):
			if check_cond(part.strip_edges()):
				return true
		return false
	for part in cond.split(","):
		var k := part.strip_edges()
		if k == "":
			continue
		if k.begins_with("!"):
			if has(k.substr(1)):
				return false
		elif not has(k):
			return false
	return true


## Kayıttan okunan bayrak sözlüğünü temizler: yalnız kısa anahtar + bool/int/kısa yazı.
static func sanitize(raw: Variant) -> Dictionary:
	var out := {}
	if not (raw is Dictionary):
		return out
	for k in (raw as Dictionary):
		var key := str(k)
		if key == "" or key.length() > 48 or out.size() >= 400:
			continue
		var v: Variant = (raw as Dictionary)[k]
		if v is bool:
			out[key] = v
		elif v is int or v is float:
			out[key] = int(v)
		elif v is String and (v as String).length() <= 48:
			out[key] = v
	return out
