class_name Interact
extends RefCounted
## Etkileşim hakemi: aynı anda birden çok etkileşim alanındaysan YALNIZ en yakın olan çalışır ve "E" ipucunu o gösterir.
## Etkileşimli düğümler (Npc, Prop, Chest, SideDoor, ShopStand) `GROUP` grubuna girer; `in_range: bool` değişkeni ve
## `can_interact() -> bool` yöntemi sunar. Karar fizik karesi başına bir kez verilir: bir E basışı birden çok düğüme
## ulaşsa da (biri sandığı açıp durumu değiştirse de) yalnız tek düğüm çalışır.

const GROUP := "interactables"

static var _frame := -1
static var _winner := 0


## `who`, oyuncuya yatayda en yakın (menzildeki ve kullanılabilir) etkileşimli mi?
static func is_best(who: Node2D) -> bool:
	if who == null or not who.is_inside_tree():
		return false
	var frame := Engine.get_physics_frames()
	if frame != _frame:
		_frame = frame
		_winner = _pick(who.get_tree())
	return _winner == who.get_instance_id()


## Önbelleği sıfırlar (testler, sahne değişimi).
static func reset() -> void:
	_frame = -1
	_winner = 0


static func _pick(tree: SceneTree) -> int:
	var player := tree.get_first_node_in_group("player") as Node2D
	if player == null:
		return 0
	var best := 0
	var best_d := INF
	for n in tree.get_nodes_in_group(GROUP):
		var o := n as Node2D
		if o == null or not o.is_inside_tree() or not o.has_method("can_interact"):
			continue
		if not bool(o.get("in_range")) or not bool(o.call("can_interact")):
			continue
		var d := absf(o.global_position.x - player.global_position.x)
		var oid := o.get_instance_id()
		if d < best_d or (is_equal_approx(d, best_d) and oid < best):
			best = oid
			best_d = d
	return best
