class_name SpriteSetLoader
extends RefCounted
## Bir klasördeki PNG'leri SpriteFrames'e çevirir. Kodu değiştirmeden sprite eklemeyi sağlar.
##
## Her animasyon için iki biçimden biri kabul edilir:
##   <ad>.png            yatay şerit (kareler yan yana). Kare genişliği = görüntü yüksekliği (kare kare),
##                       farklıysa spec içinde "frame_w" verilir.
##   <ad>_0.png, <ad>_1.png, ...   numaralı tek kareler
## Önce çizim listesindeki ad aranır (`sidera_walk.png`: `<karakter>_<hareket>.png`, `assets/` altında nerede durursa durur; bkz. ArtManifest),
## bulunamazsa klasördeki eski adlar (`assets/sprites/sidera/run.png`). Ayrıntı: docs/SPRITES.md


## folder: "res://assets/sprites/sidera".  spec: {anim_adı: {"fps": 10, "loop": true, "fallback": "idle", "frame_w": 0}}
## owner: çizim listesindeki karakter adı ("sidera"); boşsa yalnız klasör aranır.
## Hiç animasyon bulunamazsa null döner (yer tutucu görsel kullanılır).
static func build(folder: String, spec: Dictionary, owner: String = "") -> SpriteFrames:
	var frames := SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")
	var found := 0
	for anim_name: String in spec:
		var cfg: Dictionary = spec[anim_name]
		var textures := load_listed_textures(owner, anim_name)
		if textures.is_empty() and folder != "":
			textures = load_textures(folder, anim_name, int(cfg.get("frame_w", 0)))
		if textures.is_empty():
			continue
		add_animation(frames, anim_name, textures, float(cfg.get("fps", 10.0)), bool(cfg.get("loop", true)))
		found += 1
	return frames if found > 0 else null


static func add_animation(frames: SpriteFrames, anim_name: String, textures: Array[Texture2D], fps: float, loop: bool) -> void:
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, fps)
	frames.set_animation_loop(anim_name, loop)
	for t in textures:
		frames.add_frame(anim_name, t)


## Çizim listesindeki adla yükler: `<karakter>_<dosya eki>.png` (örn. `run` hareketi `sidera_walk.png`), yoksa `<karakter>_<hareket>.png`.
## Kareler kare biçimlidir (kare genişliği = görüntü yüksekliği). Bulunamazsa boş dizi.
static func load_listed_textures(owner: String, anim_name: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	if owner == "":
		return out
	var listed := ArtManifest.file_for(owner, anim_name)
	for file in [listed, "%s_%s" % [owner, anim_name]]:
		var tex := Art.texture(file)
		if tex != null:
			return slice_strip(tex)
	return out


static func load_textures(folder: String, anim_name: String, frame_w: int = 0) -> Array[Texture2D]:
	var strip_path := "%s/%s.png" % [folder, anim_name]
	if ResourceLoader.exists(strip_path):
		var tex := load(strip_path) as Texture2D
		if tex != null:
			return slice_strip(tex, frame_w)
	var out: Array[Texture2D] = []
	var i := 0
	while true:
		var p := "%s/%s_%d.png" % [folder, anim_name, i]
		if not ResourceLoader.exists(p):
			break
		var t := load(p) as Texture2D
		if t == null:
			break
		out.append(t)
		i += 1
	return out


## Yatay şeridi karelere böler.
static func slice_strip(tex: Texture2D, frame_w: int = 0) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var h := tex.get_height()
	var fw := frame_w if frame_w > 0 else h
	if fw <= 0:
		return out
	var n := maxi(tex.get_width() / fw, 1)
	for i in n:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * fw, 0, fw, h)
		out.append(at)
	return out
