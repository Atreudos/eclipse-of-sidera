class_name Dialogue
extends RefCounted
## Konuşma verisi. Biçim:
## {"speaker": "Mira", "start": "a", "nodes": {"a": {"text": "...", "next": "b", "set": "bayrak",
##   "choices": [{"text": "...", "next": "c", "set": "bayrak", "if": "koşul"}]}}}
## `next` boşsa ya da "end" ise konuşma biter. `set`: "bayrak" ya da "bayrak=değer". `if`: Story.check_cond koşulu.
## Bir düğümün `speaker` alanı varsa o satır için konuşan adı değiştirir.


## Yalnız ardışık satırlardan oluşan konuşma.
static func linear(speaker: String, lines: Array, flag: String = "") -> Dictionary:
	var nodes := {}
	for i in lines.size():
		var n := {"text": str(lines[i]), "next": ("n%d" % (i + 1)) if i + 1 < lines.size() else "end"}
		if i + 1 == lines.size() and flag != "":
			n["set"] = flag
		nodes["n%d" % i] = n
	return {"speaker": speaker, "start": "n0", "nodes": nodes}


static func apply_set(spec: String) -> void:
	if spec == "":
		return
	for part in spec.split(","):
		var p := part.strip_edges()
		if p == "":
			continue
		if p.contains("="):
			var kv := p.split("=", true, 1)
			var val: Variant = kv[1]
			if str(val).is_valid_int():
				val = int(val)
			Story.set_flag(kv[0], val)
		else:
			Story.set_flag(p, true)


## Düğümün görünen seçenekleri (koşulu geçenler).
static func visible_choices(node: Dictionary) -> Array:
	var out: Array = []
	for c in node.get("choices", []):
		if c is Dictionary and Story.check_cond(str(c.get("if", ""))):
			out.append(c)
	return out


## Yapı denetimi: eksik başlangıç, var olmayan `next` hedefleri. Sorunlar listelenir.
static func problems(d: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var nodes: Dictionary = d.get("nodes", {})
	if not nodes.has(d.get("start", "")):
		out.append("başlangıç düğümü yok")
	for id in nodes:
		var n: Dictionary = nodes[id]
		if str(n.get("text", "")) == "":
			out.append("%s: boş metin" % id)
		var targets: Array = [n.get("next", "end")]
		for c in n.get("choices", []):
			targets.append((c as Dictionary).get("next", "end"))
		for t in targets:
			if str(t) != "end" and str(t) != "" and not nodes.has(str(t)):
				out.append("%s: bilinmeyen hedef %s" % [id, t])
	return out
