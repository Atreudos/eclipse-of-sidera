class_name PuzzleLogic
extends Node2D
## Bir bulmaca odasının mantığı. Oda içinde (oda-yerel koordinat) kurulur; çözülünce `solved` gelir.
## Türler (`spec_for(kat, tür)`):
##   parry    Kule altın mermi atar; PARRY'le, mermi kuleye döner, aradaki kristali yakar (kristal `hits` vuruş ister).
##   stars    Yıldızların sırası parlayarak gösterilir; aynı sırayla kılıçla vur. Yanlış vuruş sıfırlar. 10 sn'de bir ipucu tekrar eder.
##   simon    Yıldız sırası TEK TEK büyür (1, 2, 3 ... adım): gösterileni tekrarla; yanlışta turu baştan dener.
##   balance  İki kule iki yandan atar; iki kristal AYNI ANDA yanık olmalı (kristal `window` sn sonra söner).
##   parkur   Platformlardaki basınç plakalarının hepsine `plate_time` sn içinde bas (ilk plakadan itibaren sayar). Süre dolarsa plakalar söner.
##   mix      Sol şerit (parry) + yıldız sırası birlikte.

signal solved
signal progress(text: String)
signal failed

const FLOOR_Y := 640.0
const MID_Y := FLOOR_Y - 55.0
const STAR_Y := FLOOR_Y - 70.0
const SHOW_STEP := 0.7
const SHOW_EVERY := 10.0
const PLATE_RADIUS := 44.0
## `_show_t` durumları: IDLE (ipucu yok), IDLE'dan büyük negatif (gösterimden önce duraklama), 0 ve üstü (gösteriliyor).
const IDLE := -10.0

const KINDS := ["parry", "stars", "simon", "balance", "parkur", "mix"]
const KIND_TITLES := {
	"parry": "PARRY ANAHTARI", "stars": "YILDIZ SIRASI", "simon": "YILDIZ YANKISI",
	"balance": "DENGE", "parkur": "BASINÇ PARKURU", "mix": "ÇİFT KİLİT",
}

var spec: Dictionary = {}
var width := 2000.0
var towers: Array[PuzzleTower] = []
var crystals: Array[PuzzleTarget] = []
var stars: Array[PuzzleTarget] = []
var plates: Array[Vector2] = []
var plate_lit: Array[bool] = []
var seq: Array[int] = []
var is_solved := false
## false iken kuleler ateş etmez, sayaçlar işlemez (oda henüz başlamadı).
var running := true

var _hits: Array[int] = []
var _lit_left: Array[float] = []
var _progress := 0
var _round := 1
var _stars_done := false
var _show_t := IDLE
var _show_n := 0
var _idle_t := 0.0
var _plate_clock := -1.0
var _t := 0.0
var _player: Player


## Bu kat için uygun bulmaca türleri (perdeye göre).
static func kinds_for(floor_no: int) -> Array:
	match NpcTalk.act_of(floor_no):
		0:
			return ["parry", "parkur"]
		1:
			return ["stars", "simon", "parkur"]
		2:
			return ["balance", "simon", "parry"]
		3:
			return ["stars", "simon", "parkur", "balance"]
	return ["mix", "simon", "parkur"]


static func pick_kind(floor_no: int, rng: RandomNumberGenerator) -> String:
	var pool := kinds_for(floor_no)
	return str(pool[rng.randi_range(0, pool.size() - 1)])


## Türün oda yerleşimi: parkur platform zinciri ister, diğerleri düz geniş oda.
static func layout_for_kind(kind_name: String) -> String:
	return "bulmaca_parkur" if kind_name == "parkur" else "bulmaca_duz"


## Tür ve kata göre tarif: {"kind", "lanes": ["L"/"R"], "hits", "balance", "window", "interval", "stars", "grow", "plates", "plate_time"}
static func spec_for(floor_no: int, kind_name: String) -> Dictionary:
	var f := clampi(floor_no, 1, 18)
	var interval := clampf(3.2 - 0.06 * float(f), 2.2, 3.2)
	var s := {"kind": kind_name, "lanes": [], "hits": 1, "balance": false, "window": 0.0, "interval": interval, "stars": 0, "grow": false, "plates": 0, "plate_time": 0.0}
	match kind_name:
		"parry":
			s["lanes"] = ["R"]
			s["hits"] = 1 if f < 6 else 2
		"stars":
			s["stars"] = clampi(3 + (f - 1) / 4, 3, 6)
		"simon":
			s["stars"] = clampi(3 + (f - 1) / 5, 3, 6)
			s["grow"] = true
		"balance":
			s["lanes"] = ["L", "R"]
			s["balance"] = true
			s["window"] = 6.5
		"parkur":
			s["plates"] = 6
			s["plate_time"] = clampf(18.0 - 0.3 * float(f), 12.0, 18.0)
		"mix":
			s["lanes"] = ["L"]
			s["hits"] = 2
			s["stars"] = 4 if f < 18 else 5
	return s


## Ödül sandığının oda-yerel x konumu: çıkış kapısının yakını.
static func chest_x(room_width: float) -> float:
	return room_width - 260.0


func build(spec_dict: Dictionary, rng: RandomNumberGenerator, room_width: float = 2000.0, layout_id: String = "") -> void:
	spec = spec_dict
	width = room_width
	name = "Puzzle"
	z_index = -1
	var c := width * 0.5
	var lanes: Array = spec.get("lanes", [])
	var n_lane := 0
	for side in lanes:
		var sgn := -1.0 if side == "L" else 1.0
		var tower := PuzzleTower.new()
		tower.name = "Tower" + str(side)
		tower.dir = 1 if side == "L" else -1
		tower.interval = float(spec.get("interval", 3.0))
		tower.phase = 1.3 * float(n_lane)
		tower.position = Vector2(c + sgn * 420.0, MID_Y)
		add_child(tower)
		towers.append(tower)
		var cr := PuzzleTarget.new()
		cr.name = "Crystal" + str(side)
		cr.kind = "crystal"
		cr.index = n_lane
		cr.position = Vector2(c + sgn * 240.0, MID_Y)
		add_child(cr)
		cr.struck.connect(_on_crystal_struck)
		crystals.append(cr)
		_hits.append(0)
		_lit_left.append(0.0)
		n_lane += 1
	var n_star := int(spec.get("stars", 0))
	if n_star > 0:
		var x0 := c - 330.0 if lanes.is_empty() else c - 90.0
		var x1 := c + 330.0 if lanes.is_empty() else c + 420.0
		for i in n_star:
			var st := PuzzleTarget.new()
			st.name = "Star%d" % i
			st.kind = "star"
			st.index = i
			st.show_number = true
			st.position = Vector2(x0 + (x1 - x0) * float(i) / float(maxi(n_star - 1, 1)), STAR_Y)
			add_child(st)
			st.struck.connect(_on_star_struck)
			stars.append(st)
		seq = _shuffled(n_star, rng)
		_round = 1 if bool(spec.get("grow", false)) else n_star
		_show_n = _round
		_show_t = -1.0
	else:
		_stars_done = true
	var n_plate := int(spec.get("plates", 0))
	if n_plate > 0:
		var plats := RoomLayouts.platform_rects(layout_id)
		for r in plats:
			if plates.size() >= n_plate:
				break
			plates.append(Vector2(r.position.x + r.size.x * 0.5, r.position.y))
			plate_lit.append(false)


static func _shuffled(n: int, rng: RandomNumberGenerator) -> Array[int]:
	var a: Array[int] = []
	for i in n:
		a.append(i)
	for i in range(n - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := a[i]
		a[i] = a[j]
		a[j] = t
	return a


func lanes_done() -> bool:
	for cr in crystals:
		if not cr.lit:
			return false
	return true


func plates_done() -> bool:
	for l in plate_lit:
		if not l:
			return false
	return true


func _on_crystal_struck(target: PuzzleTarget) -> void:
	if is_solved:
		return
	var i := crystals.find(target)
	if i < 0:
		return
	_hits[i] += 1
	if _hits[i] >= int(spec.get("hits", 1)):
		target.set_lit(true)
		_lit_left[i] = float(spec.get("window", 0.0))
		progress.emit("KRİSTAL YANDI")
		_check_solved()
	else:
		progress.emit("KRİSTAL  %d/%d" % [_hits[i], int(spec.get("hits", 1))])


func _on_star_struck(target: PuzzleTarget) -> void:
	if is_solved or _stars_done:
		return
	_show_t = IDLE  # vururken ipucu animasyonu kesilir
	_idle_t = 0.0
	if seq[_progress] == target.index:
		target.set_lit(true)
		_progress += 1
		if _progress >= _round:
			if _round >= seq.size():
				_stars_done = true
				progress.emit("SIRA TAMAM")
				_check_solved()
			else:
				_round += 1
				_progress = 0
				_unlight_stars()
				_show_n = _round
				_show_t = -0.6  # kısa duraklama, sonra yeni tur gösterilir
				progress.emit("TUR  %d/%d" % [_round - 1, seq.size()])
				Sfx.play("tell_gold", -6.0, 1.2)
		else:
			progress.emit("YILDIZ  %d/%d" % [_progress, _round])
	else:
		_progress = 0
		_unlight_stars()
		failed.emit()
		progress.emit("YANLIŞ SIRA")
		Sfx.play("ui_deny", -4.0)
		_show_n = _round
		_show_t = -0.9


func _unlight_stars() -> void:
	for s in stars:
		s.set_lit(false)


func _check_solved() -> void:
	if is_solved or not _stars_done or not lanes_done() or not plates_done():
		return
	is_solved = true
	for t in towers:
		t.active = false
	get_tree().call_group("projectiles", "queue_free")
	Sfx.play("room_clear", -2.0)
	solved.emit()


## Çözülmüş sayar (zor takılırsa oda yardımı; ödül verilmez, çağıran karar verir).
func assist() -> void:
	is_solved = true
	for t in towers:
		t.active = false
	get_tree().call_group("projectiles", "queue_free")


func _process(delta: float) -> void:
	_t += delta
	if is_solved or not running:
		for t in towers:
			t.active = false
		queue_redraw()
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	var near := _player != null and is_instance_valid(_player) and not _player.dead
	for t in towers:
		t.active = near and absf(_player.global_position.x - t.global_position.x) <= PuzzleTower.RANGE_X
	if bool(spec.get("balance", false)):
		for i in crystals.size():
			if crystals[i].lit and not lanes_done():
				_lit_left[i] -= delta
				if _lit_left[i] <= 0.0:
					crystals[i].set_lit(false)
					_hits[i] = 0
	if not _stars_done and not stars.is_empty():
		_tick_stars(delta)
	if not plates.is_empty() and near:
		_tick_plates(delta)
	queue_redraw()


func _tick_stars(delta: float) -> void:
	if _show_t > IDLE and _show_t < 0.0:
		_show_t += delta  # duraklama
		if _show_t >= 0.0:
			_show_t = 0.0
		return
	if _show_t >= 0.0:
		_show_t += delta
		var step := int(_show_t / SHOW_STEP)
		if step < _show_n:
			stars[seq[step]].hint_t = SHOW_STEP * 0.9
		elif _show_t > float(_show_n) * SHOW_STEP + 0.5:
			_show_t = IDLE
			_idle_t = 0.0
	else:
		_idle_t += delta
		if _idle_t >= SHOW_EVERY:
			_show_t = 0.0
			_idle_t = 0.0


func _tick_plates(delta: float) -> void:
	if not plates_done():
		var feet := _player.feet_y()
		for i in plates.size():
			if plate_lit[i]:
				continue
			var world := to_global(plates[i])
			if absf(_player.global_position.x - world.x) < PLATE_RADIUS and absf(feet - world.y) < 18.0 and _player.is_on_floor():
				plate_lit[i] = true
				Sfx.play("tell_gold", -4.0, 1.0 + 0.08 * float(plate_lit.count(true)))
				if _plate_clock < 0.0:
					_plate_clock = float(spec.get("plate_time", 15.0))
					progress.emit("SÜRE BAŞLADI")
				else:
					progress.emit("PLAKA  %d/%d" % [plate_lit.count(true), plates.size()])
		if plates_done():
			_plate_clock = -1.0
			_check_solved()
			return
	if _plate_clock >= 0.0:
		_plate_clock -= delta
		if _plate_clock <= 0.0:
			_plate_clock = -1.0
			for i in plate_lit.size():
				plate_lit[i] = false
			failed.emit()
			progress.emit("SÜRE DOLDU")
			Sfx.play("ui_deny", -4.0)


func _draw() -> void:
	for i in plates.size():
		var lit := plate_lit[i]
		var base := Color(1.0, 0.82, 0.3)
		var col := base if lit else base.darkened(0.65)
		if not Art.draw(self, "puzzle_plate", Rect2(plates[i].x - 48.0, plates[i].y - 24.0, 96.0, 24.0), _t):
			draw_rect(Rect2(plates[i].x - PLATE_RADIUS, plates[i].y - 6.0, PLATE_RADIUS * 2.0, 8.0), col)
			draw_rect(Rect2(plates[i].x - PLATE_RADIUS, plates[i].y - 6.0, PLATE_RADIUS * 2.0, 8.0), base.lightened(0.2), false, 2.0)
			if lit:
				draw_circle(Vector2(plates[i].x, plates[i].y - 10.0), 26.0, Color(base, 0.18))
	if _plate_clock >= 0.0:
		GameFont.draw_centered(self, "%.1f" % _plate_clock, Vector2(width * 0.5, 150.0), 56, Color(1.0, 0.82, 0.3, 0.9))
