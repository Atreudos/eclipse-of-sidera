extends Node
## Geliştirici aracı: çizim listesini (ArtManifest) markdown dosyalarına döker; çizere verilen doküman bunlardan dolar.
## Çalıştır:  godot --headless --path . res://tools/export_art_list.tscn -- <çıktı klasörü>
## Çıktı: <klasör>/<bölüm>.md (her bölüm), packs.md, summary.md


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := args[0] if args.size() > 0 else "user://art_list"
	DirAccess.make_dir_recursive_absolute(dir)
	for s in ArtManifest.SECTIONS:
		_write(dir.path_join("%s.md" % s["id"]), ArtDoc.section_markdown(s["id"]))
	_write(dir.path_join("packs.md"), ArtDoc.packs_markdown())
	_write(dir.path_join("summary.md"), ArtDoc.summary_markdown())
	print("çizim listesi yazıldı: ", dir, "  toplam dosya: ", ArtManifest.entries().size())
	print(ArtDoc.summary_markdown())
	get_tree().quit(0)


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("yazılamadı: " + path)
		return
	f.store_string(text)
	f.close()
