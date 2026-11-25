class_name PuzzleLogic
extends Node2D
## Bir ara odadaki bulmacanın mantığı. Parçalar: kule+kristal şeritleri ("lane") ve sıralı yıldızlar.
##   Şerit:   kule altın mermi atar; sen PARRY'lersin; mermi kuleye döner; kule ile aralarındaki kristal onu yakalar.
##            `hits` kadar vurunca kristal sönmeden yanar. DENGE kipinde kristal `window` sn sonra söner: hepsi aynı anda yanmalı.
##   Yıldız:  sıra kısa süre parlayarak gösterilir; yıldızlara AYNI sırayla kılıçla vur. Yanlış vuruş her şeyi sıfırlar.
## Hepsi çözülünce `solved` gelir.

signal solved
signal progress(text: String)
signal failed

const FLOOR_Y := 640.0
const MID_Y := FLOOR_Y - 55.0
## Yıldız yüksekliği.
const STAR_Y := FLOOR_Y - 70.0
const SHOW_STEP := 0.7
const SHOW_EVERY := 10.0
## Şerit konumları (oda içi x): kule, kristal.
const LANE_X := {"L": [360.0, 540.0], "R": [1200.0, 1020.0]}

var spec: Dictionary = {}
var towers: Array[PuzzleTower] = []
var crystals: Array[PuzzleTarget] = []
var stars: Array[PuzzleTarget] = []
var seq: Array[int] = []
var is_solved := false

var _hits: Array[int] = []
var _lit_left: Array[float] = []
var _progress := 0
var _stars_done := false
var _show_t := -1.0
var _idle_t := 0.0
var _player: Player


## Kata göre bulmaca tarifi: {"lanes": ["L"/"R"], "hits": n, "balance": bool, "window": sn, "interval": sn, "stars": n}
static func spec_for(floor_no: int) -> Dictionary:
	var f := clampi(floor_no, 1, 18)
	var act := NpcTalk.act_of(f)
	var k := (f - 1) % 4
	match act:
		0:
			return {"lanes": ["R"], "hits": 1 if k < 2 else 2, "balance": false, "window": 0.0, "interval": 3.0, "stars": 0}
		1:
			return {"lanes": [], "hits": 0, "balance": false, "window": 0.0, "interval": 3.0, "stars": 3 if k < 2 else 4}
		2:
			return {"lanes": ["L", "R"], "hits": 1, "balance": true, "window": 6.5, "interval": 3.0 if k < 2 else 2.5, "stars": 0}
		3:
			return {"lanes": [], "hits": 0, "balance": false, "window": 0.0, "interval": 3.0, "stars": 5 if k < 2 else 6}
	return {"lanes": ["L"], "hits": 2, "balance": false, "window": 0.0, "interval": 2.6, "stars": 4 if k == 0 else 5}


## Ödül sandığının oda içi x konumu (bulmaca parçalarına çarpmasın).
static func chest_x(spec_dict: Dictionary) -> float:
	var lanes: Array = spec_dict.get("lanes", [])
	if lanes.has("L") and lanes.has("R"):
		return 780.0
	if lanes.has("R"):
		return 700.0
	return 1230.0


func build(spec_dict: Dictionary, rng: RandomNumberGenerator) -> void:
	spec = spec_dict
	name = "Puzzle"
	var lanes: Array = spec.get("lanes", [])
	var n_lane := 0
	for side in lanes:
		var xs: Array = LANE_X[side]
		var tower := PuzzleTower.new()
		tower.name = "Tower" + str(side)
		tower.dir = 1 if side == "L" else -1
		tower.interval = float(spec.get("interval", 3.0))
		tower.phase = 1.2 * float(n_lane)
		tower.position = Vector2(float(xs[0]), MID_Y)
		add_child(tower)
		towers.append(tower)
		var cr := PuzzleTarget.new()
		cr.name = "Crystal" + str(side)
		cr.kind = "crystal"
		cr.index = n_lane
		cr.position = Vector2(float(xs[1]), MID_Y)
		add_child(cr)
		cr.struck.connect(_on_crystal_struck)
		crystals.append(cr)
		_hits.append(0)
		_lit_left.append(0.0)
		n_lane += 1
	var n_star := int(spec.get("stars", 0))
	if n_star > 0:
		var x0 := 440.0 if lanes.is_empty() else 680.0
		var x1 := 1130.0 if lanes.is_empty() else 1100.0
		for i in n_star:
			var st := PuzzleTarget.new()
			st.name = "Star%d" % i
			st.kind = "star"
			st.index = i
			st.show_number = true
			var px := x0 + (x1 - x0) * float(i) / float(maxi(n_star - 1, 1))
			st.position = Vector2(px, STAR_Y)
			add_child(st)
			st.struck.connect(_on_star_struck)
			stars.append(st)
		seq = _shuffled(n_star, rng)
		_show_t = 1.0
	else:
		_stars_done = true


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
	for c in crystals:
		if not c.lit:
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
	if _show_t >= 0.0:
		_show_t = -1.0  # vururken ipucu animasyonu kesilir
	if seq[_progress] == target.index:
		target.set_lit(true)
		_progress += 1
		progress.emit("YILDIZ  %d/%d" % [_progress, seq.size()])
		if _progress >= seq.size():
			_stars_done = true
			_check_solved()
	else:
		_reset_stars()
		failed.emit()
		progress.emit("YANLIŞ SIRA")
		Sfx.play("ui_deny", -4.0)
		_show_t = 0.9


func _reset_stars() -> void:
	_progress = 0
	for s in stars:
		s.set_lit(false)


func _check_solved() -> void:
	if is_solved or not _stars_done or not lanes_done():
		return
	is_solved = true
	for t in towers:
		t.active = false
	get_tree().call_group("projectiles", "queue_free")
	Sfx.play("room_clear", -2.0)
	solved.emit()


func _process(delta: float) -> void:
	if is_solved:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	var near := false
	if _player != null and is_instance_valid(_player) and not _player.dead:
		near = true
	for t in towers:
		t.active = near and absf(_player.global_position.x - t.global_position.x) <= PuzzleTower.RANGE_X
	# Denge kipi: kristaller zamanla söner
	if bool(spec.get("balance", false)):
		for i in crystals.size():
			if crystals[i].lit and not lanes_done():
				_lit_left[i] -= delta
				if _lit_left[i] <= 0.0:
					crystals[i].set_lit(false)
					_hits[i] = 0
	# Yıldız sırası ipucu: başta ve sık aralıklarla gösterilir
	if not _stars_done and not stars.is_empty():
		if _show_t >= 0.0:
			_show_t += delta
			var step := int((_show_t - 0.0) / SHOW_STEP)
			if step < seq.size():
				stars[seq[step]].hint_t = SHOW_STEP * 0.9
			elif _show_t > float(seq.size()) * SHOW_STEP + 0.5:
				_show_t = -1.0
				_idle_t = 0.0
		else:
			_idle_t += delta
			if _idle_t >= SHOW_EVERY:
				_show_t = 0.0
				_idle_t = 0.0
