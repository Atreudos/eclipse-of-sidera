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
## Ritim (agresiflik) çubuğu.
var rhythm_bar: RhythmBar

var _hearts: Array[ColorRect] = []
var _pips: Array[ColorRect] = []
var _pip_fills: Array[ColorRect] = []
var _debug_label: Label
var _hint_label: Label


func _ready() -> void:
	layer = 10
	_build()
	player = get_tree().get_first_node_in_group("player") as Player
	EventBus.rhythm_tier_changed.connect(_on_rhythm_tier_changed)
	EventBus.food_eaten.connect(_on_food_eaten)
	EventBus.item_consumed.connect(_on_item_consumed)
	GameState.god_mode_changed.connect(_on_god_mode_changed)
	overlay.god_mode = GameState.god_mode


func _exit_tree() -> void:
	if EventBus.rhythm_tier_changed.is_connected(_on_rhythm_tier_changed):
		EventBus.rhythm_tier_changed.disconnect(_on_rhythm_tier_changed)
	if EventBus.food_eaten.is_connected(_on_food_eaten):
		EventBus.food_eaten.disconnect(_on_food_eaten)
	if EventBus.item_consumed.is_connected(_on_item_consumed):
		EventBus.item_consumed.disconnect(_on_item_consumed)
	if GameState.god_mode_changed.is_connected(_on_god_mode_changed):
		GameState.god_mode_changed.disconnect(_on_god_mode_changed)


func _on_god_mode_changed(enabled: bool) -> void:
	overlay.god_mode = enabled
	if enabled:
		announcer.push_runs([["DENEME MODU ", GameFont.YELLOW], ["AÇIK", GameFont.WHITE]], 40, 1.4)
	else:
		announcer.push_runs([["DENEME MODU ", GameFont.WHITE], ["KAPALI", GameFont.YELLOW]], 40, 1.2)


## Yemek yenince: ne kadar can doldu, ne kadar bağışıklık kalbi geldi.
func _on_food_eaten(_actor: Node, item: ItemData, healed: int, overflow: int) -> void:
	var runs: Array = [[item.upper_name() + "  ", GameFont.WHITE]]
	if healed > 0:
		runs.append(["+%d CAN" % healed, Color(1.0, 0.45, 0.5)])
	if healed > 0 and overflow > 0:
		runs.append(["  ", GameFont.WHITE])
	if overflow > 0:
		runs.append(["+%d BAĞIŞIKLIK" % overflow, Color(0.5, 0.78, 1.0)])
	announcer.push_runs(runs, 34, 1.5)


## Tek kullanımlık eşya kırılınca (Çatlak El Aynası).
func _on_item_consumed(_actor: Node, item: ItemData) -> void:
	announcer.push_runs([[item.upper_name(), GameFont.YELLOW], [" KIRILDI", GameFont.WHITE]], 42, 1.8)


## Kademe yükselince küçük bir duyuru (düşüşlerde sessiz).
func _on_rhythm_tier_changed(tier: int, previous: int) -> void:
	if tier > previous and tier >= 1:
		announcer.push(RhythmMeter.tier_name(tier), RhythmBar.TIER_COLORS[tier], 40, 0.9)


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	for i in 12:
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
	_hint_label.text = "A/D hareket  Space zıpla  Shift dash  K parry  J saldır  R yeniden  F3 debug  F4 deneme modu"
	_hint_label.modulate = Color(1, 1, 1, 0.55)
	rhythm_bar = RhythmBar.new()
	rhythm_bar.name = "RhythmBar"
	rhythm_bar.position = Vector2(24, 82)
	rhythm_bar.size = Vector2(260, 60)
	root.add_child(rhythm_bar)
	_debug_label = _make_label(root, Vector2(24, 160), 15)
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
	var imm := player.immunity
	for i in _hearts.size():
		if i < max_hp:
			_hearts[i].visible = true
			_hearts[i].color = Color(0.9, 0.18, 0.28) if i < player.health else Color(0.25, 0.12, 0.16)
		elif i < max_hp + imm:
			_hearts[i].visible = true  # bağışıklık kalbi: mavi
			_hearts[i].color = Color(0.35, 0.68, 1.0)
		else:
			_hearts[i].visible = false
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
	overlay.gold = player.gold
	overlay.time_stop_k = TimeStop.progress()
	overlay.statuses = player.status_lines()
	overlay.equipped = player.inventory.items if player.inventory != null else []
	if rhythm_bar.meter == null and player.rhythm != null:
		rhythm_bar.bind(player.rhythm)
	_debug_label.text = _debug_text()


func _debug_text() -> String:
	var s := player.stats
	return "FPS %d\nDurum: %s\nParry penceresi (1/2): %.2f sn\nParry bölgesi (3/4): %.0f px\nDash hızı (5/6): %.0f\nHitstop çarpanı (7/8): %.2f\nDash şarjı: %d\nRitim: %.0f (%s)" % [
		Engine.get_frames_per_second(),
		Player.State.keys()[player.state],
		s.value("parry_window"),
		s.value("parry_zone_radius"),
		s.value("dash_speed"),
		Hitstop.duration_mult,
		player.dash_charges,
		player.rhythm.value if player.rhythm != null else 0.0,
		RhythmMeter.tier_name(player.rhythm.tier) if player.rhythm != null else "-",
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
