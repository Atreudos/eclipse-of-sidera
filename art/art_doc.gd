class_name ArtDoc
extends RefCounted
## ArtManifest'ten çizere verilecek doküman metinlerini (markdown tabloları) üretir.
## Çalıştır: godot --headless --path . res://tools/export_art_list.tscn -- <çıktı klasörü>


## 0.6 -> "0.6", 0.28 -> "0.28", 1.0 -> "1"
static func num(v: float) -> String:
	var s := ("%.2f" % v)
	if s.contains("."):
		s = s.rstrip("0").rstrip(".")
	return s


static func time_text(e: Dictionary) -> String:
	var d := float(e["dur"])
	if d <= 0.0:
		return "—"
	return "döngü %s sn" % num(d) if bool(e["loop"]) else "%s sn" % num(d)


static func importance(e: Dictionary) -> String:
	return "şart" if bool(e["core"]) else "isteğe bağlı"


## Bir bölümün markdown'ı (başlık yok; tablolar ve alt başlıklar).
static func section_markdown(section: String) -> String:
	if section == "dunya":
		return _world_markdown()
	var out: Array[String] = []
	for g in ArtManifest.groups_of(section):
		out.append(group_markdown(section, g))
	return "\n".join(out)


static func group_markdown(section: String, group: String) -> String:
	var rows := ArtManifest.in_group(section, group)
	var lines: Array[String] = ["### " + group, ""]
	if rows.is_empty():
		return "\n".join(lines)
	if rows[0].has("owner"):
		var size := "%d×%d" % [int(rows[0]["w"]), int(rows[0]["h"])]
		lines.append("Kare boyutu **%s piksel**, hepsi aynı tuvalde. Karakter SAĞA bakar, ayakları karenin alt ortasına değer." % size)
		lines.append("")
		lines.append("| Dosya | Ne zaman oynar | Kare sayısı | Süre | Paket | Önem |")
		lines.append("|---|---|---|---|---|---|")
		for e in rows:
			lines.append("| `%s.png` | %s | %s | %s | %d | %s |" % [e["file"], e["desc"], e["frames"], time_text(e), int(e["pack"]), importance(e)])
	else:
		lines.append("| Dosya | Nerede görünür | Kare (piksel) | Kare sayısı | Süre | Hizalama | Paket | Önem |")
		lines.append("|---|---|---|---|---|---|---|---|")
		for e in rows:
			lines.append("| `%s.png` | %s | %d×%d | %s | %s | %s | %d | %s |" % [
				e["file"], _desc_with_tile(e), int(e["w"]), int(e["h"]), e["frames"], time_text(e), e["anchor"], int(e["pack"]), importance(e)])
	lines.append("")
	return "\n".join(lines)


static func _desc_with_tile(e: Dictionary) -> String:
	return String(e["desc"])


## Dünya bölümü: kapılar bir tablo, tema başına çizimler tek tabloda ({tema}_ ön eki) + tema listesi.
static func _world_markdown() -> String:
	var out: Array[String] = []
	out.append(group_markdown("dunya", ArtManifest.groups_of("dunya")[0]))
	out.append("### Tema başına aynı 8 çizim")
	out.append("")
	out.append("Her tema için aşağıdaki 8 çizim istenir; dosya adının başına temanın adı gelir (`kat1_bg_far.png`, `lobi_floor.png`...). Katmanlar ekranda yataya tekrarlanır, yer çizgisi yüksekliği 640. pikseldedir.")
	out.append("")
	out.append("| Dosya (`{tema}_` ile başlar) | Nerede görünür | Kare (piksel) | Kare sayısı | Süre | Hizalama | Önem |")
	out.append("|---|---|---|---|---|---|---|")
	var first_theme: String = ArtManifest.THEMES[0]["id"]
	for e in ArtManifest.entries():
		var f := String(e["file"])
		if f.begins_with(first_theme + "_"):
			var suffix := f.trim_prefix(first_theme + "_")
			out.append("| `{tema}_%s.png` | %s | %d×%d | %s | %s | %s | %s |" % [
				suffix, e["desc"], int(e["w"]), int(e["h"]), e["frames"], time_text(e), e["anchor"], importance(e)])
	out.append("")
	out.append("### Temalar")
	out.append("")
	out.append("| Tema (dosya ön eki) | Hava | Paket |")
	out.append("|---|---|---|")
	for t in ArtManifest.THEMES:
		out.append("| `%s_` | %s | %d |" % [t["id"], t["mood"], int(t["pack"])])
	out.append("")
	return "\n".join(out)


## Paketler: sıralı liste ve kaç dosya olduğu.
static func packs_markdown() -> String:
	var lines: Array[String] = ["| Sıra | Paket | Dosya sayısı | Bu pakette |", "|---|---|---|---|"]
	for p in ArtManifest.PACKS:
		var names: Array[String] = []
		var seen := {}
		for e in ArtManifest.entries():
			if int(e["pack"]) == int(p):
				var s := _section_title(String(e["section"]))
				if not seen.has(s):
					seen[s] = true
					names.append(s)
		lines.append("| %d | %s | %d | %s |" % [int(p), ArtManifest.PACKS[p], ArtManifest.count_in_pack(int(p)), ", ".join(names)])
	return "\n".join(lines) + "\n"


static func _section_title(id: String) -> String:
	for s in ArtManifest.SECTIONS:
		if s["id"] == id:
			return s["title"]
	return id


## Toplam sayım tablosu (bölüm başına dosya sayısı ve "şart" olanlar).
static func summary_markdown() -> String:
	var lines: Array[String] = ["| Bölüm | Dosya | Şart | İsteğe bağlı |", "|---|---|---|---|"]
	var total := 0
	var total_core := 0
	for s in ArtManifest.SECTIONS:
		var n := 0
		var core := 0
		for e in ArtManifest.entries():
			if e["section"] == s["id"]:
				n += 1
				if bool(e["core"]):
					core += 1
		total += n
		total_core += core
		lines.append("| %s | %d | %d | %d |" % [s["title"], n, core, n - core])
	lines.append("| **Toplam** | **%d** | **%d** | **%d** |" % [total, total_core, total - total_core])
	return "\n".join(lines) + "\n"
