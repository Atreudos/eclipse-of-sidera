class_name ArtFx
extends Node2D
## Çizim tabanlı tek seferlik efekt: manifestteki bir `fx_*` şeridini (Art) oynatır ve kendini siler.
## Çizim yoksa HİÇBİR ŞEY eklenmez ve `play` null döner: çağıran yerin kod efekti (RingFx, HitSpark, DustFx...) zaten çalışır.
## Çizimin kutusu ve çıpası manifestten gelir: "alt orta" -> tabanı düğümde, "sol orta" -> solu düğümde, "üst orta" -> üstü düğümde, aksi merkez.
##
## Seçenekler (`opts`): scale (float), flip (bool, yatay aynalama), rot (radyan), life (döngülü çizim için sn), follow (Node2D: onu izler),
## offset (Vector2, izlerken), z (int), modulate (Color). Godot'ta henüz koşulmadı.

var file := ""
var follow: Node2D = null
var follow_offset := Vector2.ZERO
var life := 0.0
var modulate_color := Color.WHITE

var _t := 0.0
var _rect := Rect2()


## `file` çizimi yoksa null. Varsa `parent` altına `pos` (dünya) noktasında bir efekt ekler.
static func play(parent: Node, file_name: String, pos: Vector2, opts: Dictionary = {}) -> ArtFx:
	if parent == null or not Art.has(file_name):
		return null
	var fx := ArtFx.new()
	fx.file = file_name
	var spec := ArtManifest.find(file_name)
	var k := float(opts.get("scale", 1.0))
	var w := float(spec.get("w", 64)) * k
	var h := float(spec.get("h", 64)) * k
	var anchor := str(spec.get("anchor", ""))
	if anchor.begins_with("alt orta"):
		fx._rect = Rect2(-w * 0.5, -h, w, h)
	elif anchor.begins_with("sol orta"):
		fx._rect = Rect2(0.0, -h * 0.5, w, h)
	elif anchor.begins_with("üst orta"):
		fx._rect = Rect2(-w * 0.5, 0.0, w, h)
	else:
		fx._rect = Rect2(-w * 0.5, -h * 0.5, w, h)
	var dur := float(spec.get("dur", 0.3))
	fx.life = float(opts.get("life", dur + 0.02)) if bool(spec.get("loop", false)) else dur + 0.02
	fx.follow = opts.get("follow") as Node2D
	fx.follow_offset = opts.get("offset", Vector2.ZERO)
	fx.modulate_color = opts.get("modulate", Color.WHITE)
	fx.z_index = int(opts.get("z", 24))
	fx.rotation = float(opts.get("rot", 0.0))
	if bool(opts.get("flip", false)):
		fx.scale.x = -1.0
	parent.add_child(fx)
	fx.global_position = pos
	return fx


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	if follow != null:
		if is_instance_valid(follow):
			global_position = follow.global_position + follow_offset
		else:
			follow = null
	queue_redraw()


func _draw() -> void:
	Art.draw(self, file, _rect, _t, modulate_color, true)
