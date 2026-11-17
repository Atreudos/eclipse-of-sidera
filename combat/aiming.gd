class_name Aiming
extends RefCounted
## Sapanın nişan hesapları (saf fonksiyonlar; Player kullanır, testler doğrudan çağırır).
##
## ELLE NİŞAN (8 yön): baktığın yön; YUKARI tuşu (W / ↑) basılıysa yukarı, yatay tuşla birlikte çapraz yukarı;
## havadayken AŞAĞI tuşu (S / ↓) aşağı ya da çapraz aşağı. Yerdeyken aşağı tuşu etkisizdir (taşı yere atmanın anlamı yok).
## OTOMATİK NİŞAN ("Süperteknolojik Nişangâh" eşyası): menzildeki en yakın görünür düşmana yönelir, düşmanın hızını da hesaba
## katıp önüne atar. Yukarı/aşağı tuşuna basıyorsan (elle nişan) otomatik nişan devre dışı kalır.

## Otomatik nişanın düşman arayacağı en uzak mesafe (px).
const AUTO_RANGE := 900.0
## Arkandaki düşmanın mesafesi bu çarpanla büyütülür: önündekiler tercih edilir.
const BEHIND_PENALTY := 1.5
## Önden hedeflemede düşmanın ileri tahmin edilen mesafesi en fazla bu kadar olur (px) ve en çok bu kadar sn ilerisine bakılır.
const LEAD_MAX := 260.0
const LEAD_TIME_MAX := 0.6
const DIAG := 0.70710678


## Elle nişan yönü (birim vektör). `move_x`: yatay tuş (0 = yok, bakış yönü kullanılır), `aim_y`: -1 yukarı, +1 aşağı.
static func manual(move_x: float, aim_y: float, facing: int, on_floor: bool) -> Vector2:
	var hx := 0.0
	if absf(move_x) > 0.05:
		hx = signf(move_x)
	var vy := 0.0
	if aim_y < -0.5:
		vy = -1.0
	elif aim_y > 0.5 and not on_floor:
		vy = 1.0
	if vy == 0.0:
		return Vector2(float(facing) if hx == 0.0 else hx, 0.0)
	if hx == 0.0:
		return Vector2(0.0, vy)
	return Vector2(hx * DIAG, vy * DIAG)


## Menzildeki en uygun düşmanı seçer (yoksa null). Puan = mesafe (arkadakiler BEHIND_PENALTY kat); en düşük puan kazanır.
## `visible`: isteğe bağlı `func(node) -> bool`; false dönen (arada duvar olan) düşman seçilmez.
static func pick_target(origin: Vector2, facing: int, enemies: Array, max_range: float = AUTO_RANGE, visible: Callable = Callable()) -> Node2D:
	var best: Node2D = null
	var best_score := INF
	for e in enemies:
		var n := e as Node2D
		if n == null or not is_instance_valid(n) or n.is_queued_for_deletion():
			continue
		var actor := n as ActorBase
		if actor != null and actor.dead:
			continue
		var d := n.global_position - origin
		var dist := d.length()
		if dist > max_range:
			continue
		var score := dist
		if absf(d.x) > 1.0 and (1 if d.x > 0.0 else -1) != facing:
			score *= BEHIND_PENALTY
		if score >= best_score:
			continue
		if visible.is_valid() and not bool(visible.call(n)):
			continue
		best = n
		best_score = score
	return best


## Hareket eden hedefin önüne nişan: `speed` hızlı bir taşın hedefle buluşacağı noktaya doğru birim vektör.
## Hedef duruyorsa doğrudan hedefe bakar.
static func lead(origin: Vector2, target_pos: Vector2, target_vel: Vector2, speed: float) -> Vector2:
	var aim := target_pos
	var spd := maxf(speed, 1.0)
	for i in 3:
		var t := minf(origin.distance_to(aim) / spd, LEAD_TIME_MAX)
		var offset := target_vel * t
		if offset.length() > LEAD_MAX:
			offset = offset.normalized() * LEAD_MAX
		aim = target_pos + offset
	var dir := aim - origin
	if dir.length() < 1.0:
		return Vector2.RIGHT
	return dir.normalized()
