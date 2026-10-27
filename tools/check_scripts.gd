extends Node
## Geliştirici aracı: projedeki tüm .gd ve .tscn dosyalarını yükler; derleme hataları konsola düşer.
## Çalıştır:  godot --headless --path . res://tools/check_scripts.tscn


func _ready() -> void:
	var bad := 0
	var files: Array[String] = []
	_collect("res://", files)
	files.sort()
	for f in files:
		if f.begins_with("res://tools/check_scripts"):
			continue
		if load(f) == null:
			print("YÜKLENEMEDİ: ", f)
			bad += 1
	print("kontrol edilen dosya: ", files.size(), "  hatalı: ", bad)
	get_tree().quit(1 if bad > 0 else 0)


func _collect(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if n.begins_with(".") or n == "addons":
			n = d.get_next()
			continue
		var p := dir_path.path_join(n)
		if d.current_is_dir():
			_collect(p, out)
		elif n.ends_with(".gd") or n.ends_with(".tscn"):
			out.append(p)
		n = d.get_next()
