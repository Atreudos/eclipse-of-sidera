class_name Hud
extends CanvasLayer
## Can, dash şarjları, oda/dalga bilgisi, duyurular ve F3 ile açılan debug/ayar paneli.
## Debug panelinde sayı tuşlarıyla hissi CANLI ayarlayabilirsin:
##   1 / 2  parry penceresi  -/+ 0.01 sn
##   3 / 4  parry bölgesi yarıçapı  -/+ 4 px
##   5 / 6  dash hızı  -/+ 50
##   7 / 8  hitstop süresi çarpanı  -/+ 0.25

var player: Player
## Test arenasındaki sonsuz dalga sayacı (oda sistemi olmayan sahneler için).
var wave := 0:
	set(value):
		wave = value
		if overlay != null:
			overlay.arena_wave = value
## Oda/dalga/ilerle oku/ölüm özeti (AGENTORANGE ile çizilir).
var overlay: RunOverlay
## Ekranın üstünde kısa süre görünen büyük duyurular.
var announcer: Announcer

var _hearts: Array[ColorRect] = []
var _pips: Array[ColorRect] = []
var _pip_fills: Array[ColorRect] = []
var _debug_label: Label
var _hint_label: Label


func _ready() -> void:
	layer = 10
	_build()
	player = get_tree().get_first_node_in_group("player") as Player


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	for i in 8:
		var h := ColorRect.new()
		h.size = Vector2(26, 26)
		h.position = Vector2(24 + i * 34, 22)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(h)
		_hearts.append(h)

	for i in 4:
		var bg := ColorRect.new()
		bg.size = Vector2(44, 10)
		bg.position = Vector2(24 + i * 52, 60)
		bg.color = Color(0.2, 0.2, 0.25)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(bg)
		var fill := ColorRect.new()
		fill.size = Vector2(44, 10)
		fill.color = Color(0.85, 0.95, 1.0)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(fill)
		_pips.append(bg)
		_pip_fills.append(fill)

	_hint_label = _make_label(root, Vector2(24, 682), 14)
	_hint_label.text = "A/D hareket  Space zıpla  Shift dash  K parry  J saldır  R yeniden  F3 debug"
	_hint_label.modulate = Color(1, 1, 1, 0.55)
	_debug_label = _make_label(root, Vector2(24, 96), 15)
	_debug_label.visible = false
	overlay = RunOverlay.new()
	overlay.name = "Overlay"
	overlay.arena_wave = wave
	root.add_child(overlay)
	announcer = Announcer.new()
	announcer.name = "Announcer"
	root.add_child(announcer)


## Oda sistemi bilgisi: görünen oda no (1'den), mevcut dalga, toplam dalga, oda temizlendi mi.
func set_room(room_number: int, wave_now: int, wave_count: int, is_cleared: bool = false) -> void:
	overlay.room_number = room_number
	overlay.wave = wave_now
	overlay.wave_total = wave_count
	overlay.cleared = is_cleared


## Ölüm ekranındaki özet (kills, rooms_cleared, best_combo, time, room).
func set_summary(data: Dictionary) -> void:
	overlay.summary = data


func _make_label(parent: Control, pos: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
		return
	var max_hp := player.stats.int_value("max_health")
	for i in _hearts.size():
		_hearts[i].visible = i < max_hp
		_hearts[i].color = Color(0.9, 0.18, 0.28) if i < player.health else Color(0.25, 0.12, 0.16)
	var max_dash := player.stats.int_value("dash_charges")
	var recharge := player.stats.value("dash_recharge")
	for i in _pips.size():
		_pips[i].visible = i < max_dash
		var fill_w := 44.0
		if i == player.dash_charges and player.dash_charges < max_dash:
			fill_w = 44.0 * clampf(player._dash_recharge_t / recharge, 0.0, 1.0)
			_pip_fills[i].color = Color(0.5, 0.6, 0.7)
		elif i > player.dash_charges:
			fill_w = 0.0
		else:
			_pip_fills[i].color = Color(0.85, 0.95, 1.0)
		_pip_fills[i].size.x = fill_w
	overlay.dead = player.dead
	_debug_label.text = _debug_text()


func _debug_text() -> String:
	var s := player.stats
	return "FPS %d\nDurum: %s\nParry penceresi (1/2): %.2f sn\nParry bölgesi (3/4): %.0f px\nDash hızı (5/6): %.0f\nHitstop çarpanı (7/8): %.2f\nDash şarjı: %d" % [
		Engine.get_frames_per_second(),
		Player.State.keys()[player.state],
		s.value("parry_window"),
		s.value("parry_zone_radius"),
		s.value("dash_speed"),
		Hitstop.duration_mult,
		player.dash_charges,
	]


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_F3:
		_debug_label.visible = not _debug_label.visible
		return
	if player == null:
		return
	var s := player.stats
	match key.physical_keycode:
		KEY_1:
			s.set_base("parry_window", maxf(s.value("parry_window") - 0.01, 0.03))
		KEY_2:
			s.set_base("parry_window", minf(s.value("parry_window") + 0.01, 0.4))
		KEY_3:
			s.set_base("parry_zone_radius", maxf(s.value("parry_zone_radius") - 4.0, 20.0))
		KEY_4:
			s.set_base("parry_zone_radius", minf(s.value("parry_zone_radius") + 4.0, 140.0))
		KEY_5:
			s.set_base("dash_speed", maxf(s.value("dash_speed") - 50.0, 400.0))
		KEY_6:
			s.set_base("dash_speed", minf(s.value("dash_speed") + 50.0, 1800.0))
		KEY_7:
			Hitstop.duration_mult = maxf(Hitstop.duration_mult - 0.25, 0.0)
		KEY_8:
			Hitstop.duration_mult = minf(Hitstop.duration_mult + 0.25, 3.0)
