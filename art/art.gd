class_name Art
extends RefCounted
## Çizim yükleyici. Oyun bir çizimi manifestteki ADIYLA ister ("ui_logo"); dosya `assets/` altında nerede durursa durur
## bulunur (klasör önemli değil). Dosya yoksa `null`/`false` döner ve çağıran yer tutucusunu çizer:
## çizimler geldikçe oyun kendiliğinden güzelleşir, kodu değiştirmek gerekmez.
##
## Şerit (sprite sheet): kareler yan yana dizilir. Kare genişliği ArtManifest'teki `w` değeridir,
## kare sayısı = görüntü genişliği / w. Döngülü çizim `dur` saniyede bir tur atar, tek seferlik çizim `dur` saniyede
## oynayıp son karede kalır. Manifestte olmayan bir ad tek kare sayılır.

## Çizimlerin aranacağı klasör (testler başka klasöre yönlendirir).
static var root := "res://assets"
## Testler ve geliştirme: dosya adı -> hazır doku. Diskten önce buna bakılır.
static var override: Dictionary = {}

static var _paths: Dictionary = {}
static var _indexed := false
static var _cache: Dictionary = {}


## Önbelleği ve dosya dizinini sıfırlar (yeni dosya eklendikten sonra ya da testlerde).
static func reset() -> void:
	override.clear()
	_paths.clear()
	_cache.clear()
	_indexed = false


## Çizim var mı?
static func has(file: String) -> bool:
	return override.has(file) or path_of(file) != ""


## Çizimin `res://` yolu; yoksa "".
static func path_of(file: String) -> String:
	_index()
	return String(_paths.get(file, ""))


## Dokuyu verir; çizim yoksa null (sonuç önbelleğe alınır: yokluğu da).
static func texture(file: String) -> Texture2D:
	var forced: Variant = override.get(file)
	if forced is Texture2D:
		return forced
	if _cache.has(file):
		return _cache[file]
	var tex: Texture2D = null
	var p := path_of(file)
	if p != "" and ResourceLoader.exists(p):
		tex = load(p) as Texture2D
	_cache[file] = tex
	return tex


## Şeritteki kare sayısı (çizim yoksa 0).
static func frame_count(file: String) -> int:
	var tex := texture(file)
	if tex == null:
		return 0
	var fw := frame_width(file, tex)
	return maxi(tex.get_width() / fw, 1)


## Tek karenin piksel genişliği.
static func frame_width(file: String, tex: Texture2D) -> int:
	var spec := ArtManifest.find(file)
	var fw := int(spec.get("w", 0))
	if fw <= 0 or fw > tex.get_width():
		return maxi(tex.get_width(), 1)
	return fw


## `t` saniyedeki kare numarası (0'dan).
static func frame_at(file: String, t: float) -> int:
	var n := frame_count(file)
	if n <= 1:
		return 0
	var spec := ArtManifest.find(file)
	var dur := float(spec.get("dur", 0.0))
	if dur <= 0.0:
		return 0
	if bool(spec.get("loop", true)):
		return clampi(int(fposmod(t, dur) / dur * float(n)), 0, n - 1)
	return clampi(int(maxf(t, 0.0) / dur * float(n)), 0, n - 1)


## Verilen karenin doku içindeki alanı.
static func frame_rect(file: String, frame: int) -> Rect2:
	var tex := texture(file)
	if tex == null:
		return Rect2()
	var fw := frame_width(file, tex)
	var n := maxi(tex.get_width() / fw, 1)
	return Rect2(float(clampi(frame, 0, n - 1) * fw), 0.0, float(fw), float(tex.get_height()))


## Çizimi `rect` içine çizer. stretch=false: en-boy oranı korunur ve ortalanır; true: kutuyu doldurur.
## Çizim yoksa false döner (hiçbir şey çizilmez), çağıran yer tutucusunu çizer.
static func draw(ci: CanvasItem, file: String, rect: Rect2, t: float = 0.0, modulate: Color = Color.WHITE, stretch: bool = false) -> bool:
	var tex := texture(file)
	if tex == null:
		return false
	var src := frame_rect(file, frame_at(file, t))
	var dest := rect
	if not stretch and src.size.x > 0.0 and src.size.y > 0.0:
		var k := minf(rect.size.x / src.size.x, rect.size.y / src.size.y)
		var sz := src.size * k
		dest = Rect2(rect.position + (rect.size - sz) * 0.5, sz)
	ci.draw_texture_rect_region(tex, dest, src, modulate)
	return true


## Çerçeve çizimini (9 dilim) `rect` boyuna esneterek çizer. Dilim kalınlığı manifesttir (`nine`).
static func draw_nine(ci: CanvasItem, file: String, rect: Rect2, t: float = 0.0, modulate: Color = Color.WHITE) -> bool:
	var tex := texture(file)
	if tex == null:
		return false
	var spec := ArtManifest.find(file)
	var m := float(int(spec.get("nine", 0)))
	var src := frame_rect(file, frame_at(file, t))
	m = minf(m, minf(src.size.x, src.size.y) * 0.5)
	var box := StyleBoxTexture.new()
	box.texture = tex
	box.region_rect = src
	box.texture_margin_left = m
	box.texture_margin_right = m
	box.texture_margin_top = m
	box.texture_margin_bottom = m
	box.modulate_color = modulate
	box.draw_center = true
	ci.draw_style_box(box, rect)
	return true


## `assets/` altındaki PNG'leri bir kez tarar: dosya adı (uzantısız) -> yol. Aynı ad iki yerdeyse alfabetik ilki kazanır.
static func _index() -> void:
	if _indexed:
		return
	_indexed = true
	_paths.clear()
	_scan(root)


static func _scan(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	var names: Array[String] = []
	var folders: Array[String] = []
	dir.list_dir_begin()
	var n := dir.get_next()
	while n != "":
		if not n.begins_with("."):
			if dir.current_is_dir():
				folders.append(n)
			else:
				names.append(n)
		n = dir.get_next()
	dir.list_dir_end()
	names.sort()
	folders.sort()
	for f in names:
		# Dışa aktarılmış oyunda dosyalar `x.png.import` / `x.png.remap` adıyla görünür.
		var base := f
		if base.ends_with(".import"):
			base = base.trim_suffix(".import")
		elif base.ends_with(".remap"):
			base = base.trim_suffix(".remap")
		if base.get_extension().to_lower() == "png":
			var key := base.get_basename()
			if not _paths.has(key):
				_paths[key] = "%s/%s" % [dir_path, base]
	for d in folders:
		_scan("%s/%s" % [dir_path, d])
