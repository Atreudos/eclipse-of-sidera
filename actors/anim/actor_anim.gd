class_name ActorAnim
extends RefCounted
## Bir aktörün (oyuncu/düşman) animasyonlarını yönetir.
##
## Sprite klasöründe PNG varsa bir AnimatedSprite2D eklenir ve yer tutucu şekiller ("Placeholder")
## gizlenir. PNG yoksa hiçbir şey değişmez: oyun şimdiki görünümüyle çalışır.
## Eksik bir animasyon, spec'teki "fallback" zinciriyle yedeğine düşer (örn. attack3 -> attack2 -> attack1).

var sprite: AnimatedSprite2D
var has_art := false
var current := ""
## Sprite'ı elle kaydırmak için (px). Varsayılan hizalama: karenin altı = çarpışma kutusunun altı.
var art_offset := Vector2.ZERO

var _paused := false
var _spec: Dictionary = {}
var _placeholder: CanvasItem
var _frames: SpriteFrames
var _body_bottom := 26.0
var _visual: Node


func setup(visual: Node, folder: String, spec: Dictionary, body_bottom: float) -> void:
	_visual = visual
	_spec = spec
	_body_bottom = body_bottom
	_placeholder = visual.get_node_or_null("Placeholder") as CanvasItem
	if folder == "":
		return
	var frames := SpriteSetLoader.build(folder, spec)
	if frames != null:
		use_frames(frames)


## Hazır SpriteFrames kullanır (testler ve ileride kod ile üretilen animasyonlar için).
func use_frames(frames: SpriteFrames) -> void:
	_frames = frames
	if sprite == null:
		sprite = AnimatedSprite2D.new()
		sprite.name = "Sprite"
		_visual.add_child(sprite)
		_visual.move_child(sprite, 0)
	sprite.sprite_frames = frames
	has_art = true
	if _placeholder != null:
		_placeholder.visible = false
	_align()


func _align() -> void:
	var height := 0.0
	for a in _frames.get_animation_names():
		if _frames.get_frame_count(a) > 0:
			height = _frames.get_frame_texture(a, 0).get_height()
			break
	sprite.position = Vector2(0.0, _body_bottom - height * 0.5) + art_offset


## Ad, eksikse yedeğine çözülür. Hiçbiri yoksa "".
func resolve(anim_name: String) -> String:
	var n := anim_name
	for i in 6:
		if _frames != null and _frames.has_animation(n):
			return n
		var cfg: Variant = _spec.get(n, {})
		var fb := str((cfg as Dictionary).get("fallback", "")) if cfg is Dictionary else ""
		if fb == "":
			return ""
		n = fb
	return ""


func has_anim(anim_name: String) -> bool:
	return has_art and resolve(anim_name) != ""


## Aynı animasyon zaten oynuyorsa devam eder (tek seferlikler son karede kalır).
func play(anim_name: String, fit_duration: float = 0.0) -> void:
	if not has_art:
		return
	var r := resolve(anim_name)
	if r == "":
		return
	if r != current:
		current = r
		sprite.play(r)
		_set_speed(r, fit_duration)


## Animasyonu baştan başlatır (aynı saldırının art arda tekrarı gibi).
func trigger(anim_name: String, fit_duration: float = 0.0) -> void:
	if not has_art:
		return
	var r := resolve(anim_name)
	if r == "":
		return
	current = r
	sprite.play(r)
	sprite.frame = 0
	_set_speed(r, fit_duration)


## fit_duration > 0 ise animasyon tam o sürede biter (saldırı süresine uydurmak için).
func _set_speed(anim_name: String, fit_duration: float) -> void:
	if fit_duration <= 0.0 or _frames.get_animation_loop(anim_name):
		sprite.speed_scale = 1.0
		return
	var natural := float(_frames.get_frame_count(anim_name)) / maxf(_frames.get_animation_speed(anim_name), 0.01)
	sprite.speed_scale = maxf(natural / fit_duration, 0.05)


## Animasyonu dondurur / bırakır (zaman durunca düşmanlar donar).
func set_paused(paused: bool) -> void:
	if not has_art or paused == _paused:
		return
	_paused = paused
	if paused:
		sprite.pause()
	else:
		sprite.play()


func is_finished() -> bool:
	return not has_art or not sprite.is_playing()


## Animasyonun şu anki hızıyla süresi (saniye).
func duration_of(anim_name: String) -> float:
	var r := resolve(anim_name)
	if r == "":
		return 0.0
	var natural := float(_frames.get_frame_count(r)) / maxf(_frames.get_animation_speed(r), 0.01)
	return natural / maxf(sprite.speed_scale, 0.05)
