class_name TutorialGuide
extends Node
## Kat 1 öğretici rehberi: oyuncunun ne yaptığını izler ve o an uygun ipucunu TutorialHint'e koyar.
##
## LOBİ: sırayla  hareket (A/D) -> zıplama (W/Space) -> dash (Shift) -> saldırı (J, 3 kez) -> "sağa ilerle".
##       Bir beceriyi zaten yaptıysan (sırası gelmeden) o ipucu hiç gösterilmez.
## SAVAŞ: altın uyarı çıkınca "K = PARRY" (parry yapana kadar), kaçırınca "tekrar dene", parry sonrası "J = VUR",
##        kırmızı uyarı çıkınca "SHIFT = DASH" (dash ile savuşturunca ya da 3 kez gösterilince biter).
## Hepsi yapılınca (ya da kat 1 bitince) profil `tutorial_done` olur ve rehber kapanır; ipuçları bir daha çıkmaz.
## Kurulum: RunController (kat 1'de, profilde öğretici bitmemişse). Rehber yalnız İPUCU gösterir, oyunu değiştirmez.

signal step_done(id: String)
signal finished

## Hareket adımı için gereken toplam yürüme (px).
const MOVE_DISTANCE := 320.0
## Bir karede bundan büyük konum sıçraması ışınlanmadır, yürüme sayılmaz.
const TELEPORT_JUMP := 60.0
## "Kaçırdın" ipucunun görünme süresi, parry sonrası "vur" ipucunun süresi (sn).
const MISS_TIME := 2.6
const STRIKE_TIME := 3.2
## Bir ipucu belirince en az bu kadar kalır (uyarı bitse de saldırı sırasında kaybolmasın).
const HOLD_MIN := 1.3
## "Kaçırdın" yalnız son altın uyarıdan bu kadar sonrasına kadar gösterilir (boşa K'ya basınca çıkmasın).
const MISS_WINDOW := 1.4
## Kırmızı ipucu bu kadar kez gösterilince (dash'le savuşturulmamış olsa da) bir daha gösterilmez.
const RED_HINT_LIMIT := 3

const PARRY_FAMILY := [Tutorial.STEP_PARRY, Tutorial.STEP_PARRY_SHOT, Tutorial.STEP_PARRY_MISS]

var run: RunController
var player: Player
var hint: TutorialHint

## Yapılan adımlar: kimlik -> true.
var done := {}
## Şu an gösterilen ipucu kimliği ("" = yok).
var active := ""
var attacks := 0
var moved := 0.0
var finished_flag := false

var _last_x := 0.0
var _tell_enemy: EnemyBase = null
## Son altın uyarıdan beri geçen oyun süresi (sn).
var _since_gold := 99.0
# İpucu süreleri GERÇEK zamanla akar (panelin animasyonuyla aynı saat; hitstop/zaman durması bozmaz).
var _miss_t := 0.0
var _strike_t := 0.0
var _hold_t := 0.0
var _last_usec := 0
var _red_shown := 0


func setup(controller: RunController, p: Player, hint_panel: TutorialHint) -> void:
	run = controller
	player = p
	hint = hint_panel
	_last_x = player.global_position.x
	player.jumped.connect(_on_jumped)
	player.attack_started.connect(_on_attack_started)
	EventBus.dash_used.connect(_on_dash_used)
	EventBus.parry_success.connect(_on_parry_success)
	EventBus.parry_failed.connect(_on_parry_failed)
	EventBus.dodge_success.connect(_on_dodge_success)
	EventBus.enemy_tell.connect(_on_enemy_tell)
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.room_entered.connect(_on_room_entered)
	EventBus.floor_entered.connect(_on_floor_entered)
	hint.flash_finished.connect(_on_flash_finished)
	_refresh()


func _exit_tree() -> void:
	_disconnect_all()


func _disconnect_all() -> void:
	if player != null and is_instance_valid(player):
		if player.jumped.is_connected(_on_jumped):
			player.jumped.disconnect(_on_jumped)
		if player.attack_started.is_connected(_on_attack_started):
			player.attack_started.disconnect(_on_attack_started)
	var links := [
		[EventBus.dash_used, _on_dash_used], [EventBus.parry_success, _on_parry_success], [EventBus.parry_failed, _on_parry_failed],
		[EventBus.dodge_success, _on_dodge_success], [EventBus.enemy_tell, _on_enemy_tell], [EventBus.damage_dealt, _on_damage_dealt],
		[EventBus.room_entered, _on_room_entered], [EventBus.floor_entered, _on_floor_entered],
	]
	for l: Array in links:
		var sig: Signal = l[0]
		var fn: Callable = l[1]
		if sig.is_connected(fn):
			sig.disconnect(fn)
	if hint != null and is_instance_valid(hint) and hint.flash_finished.is_connected(_on_flash_finished):
		hint.flash_finished.disconnect(_on_flash_finished)


# ---------------------------------------------------------------- akış

func in_lobby() -> bool:
	var room := run.current_room() if run != null else null
	return room != null and room.kind == FloorPlan.Kind.LOBBY


func _physics_process(delta: float) -> void:
	if finished_flag or player == null or not is_instance_valid(player):
		return
	var dt := _real_dt()
	_miss_t = maxf(_miss_t - dt, 0.0)
	_strike_t = maxf(_strike_t - dt, 0.0)
	_hold_t = maxf(_hold_t - dt, 0.0)
	_since_gold += delta
	if _tell_enemy != null and is_instance_valid(_tell_enemy) and _tell_enemy.tell_mode() == EnemyBase.Tell.GOLD:
		_since_gold = 0.0
	# Yürüme (yalnız lobide ve henüz yapılmadıysa).
	var x := player.global_position.x
	if not done.has(Tutorial.STEP_MOVE) and in_lobby():
		var dx := absf(x - _last_x)
		if player.state == Player.State.MOVE and dx < TELEPORT_JUMP:
			moved += dx
		if moved >= MOVE_DISTANCE:
			_complete(Tutorial.STEP_MOVE)
	_last_x = x
	_refresh()


## Son çağrıdan beri geçen gerçek süre (sn); duraklatma sonrası sıçramasın diye kırpılır.
func _real_dt() -> float:
	var now := Time.get_ticks_usec()
	var dt := 0.0
	if _last_usec != 0:
		dt = clampf(float(now - _last_usec) / 1000000.0, 0.0, 0.05)
	_last_usec = now
	return dt


## O an görünmesi gereken ipucu ("" = hiçbiri).
func pick() -> String:
	var room := run.current_room() if run != null else null
	if room == null:
		return ""
	if room.kind == FloorPlan.Kind.LOBBY:
		for id: String in Tutorial.LOBBY_STEPS:
			if not done.has(id):
				return id
		return ""
	if room.kind != FloorPlan.Kind.COMBAT:
		return ""
	if _strike_t > 0.0 and not done.has(Tutorial.STEP_STRIKE):
		return Tutorial.STEP_STRIKE
	var e := _tell_enemy
	if e != null and is_instance_valid(e) and not e.dead:
		match e.tell_mode():
			EnemyBase.Tell.GOLD:
				if not done.has(Tutorial.STEP_PARRY):
					return Tutorial.STEP_PARRY_SHOT if e is Sagitta else Tutorial.STEP_PARRY
			EnemyBase.Tell.RED:
				if not done.has(Tutorial.STEP_RED):
					return Tutorial.STEP_RED
	if _miss_t > 0.0 and not done.has(Tutorial.STEP_PARRY):
		return Tutorial.STEP_PARRY_MISS
	return ""


func _refresh() -> void:
	if finished_flag or hint == null or not is_instance_valid(hint) or hint.is_done_flashing():
		return
	var want := pick()
	if want == "" and active != "" and _hold_t > 0.0 and not done.has(active) and not (active in PARRY_FAMILY and done.has(Tutorial.STEP_PARRY)):
		want = active  # en az HOLD_MIN kadar kal
	if want == active:
		return
	active = want
	if want == "":
		hint.hide_hint()
		return
	if want == Tutorial.STEP_RED:
		_red_shown += 1
		if _red_shown > RED_HINT_LIMIT:
			done[Tutorial.STEP_RED] = true  # yeterince gösterildi: bir daha gösterme
			active = ""
			hint.hide_hint()
			_check_finished()
			return
	hint.show_hint(Tutorial.hint(want, attacks))
	_hold_t = HOLD_MIN


## Bir adımı tamamlar. Görünen ipucu o adımınsa tik çıkar; sıradaki ipucu tik bitince gelir.
func _complete(id: String) -> void:
	if done.has(id):
		return
	done[id] = true
	step_done.emit(id)
	var showing := active == id or (id == Tutorial.STEP_PARRY and active in PARRY_FAMILY)
	if showing and hint != null and is_instance_valid(hint) and hint.is_showing():
		hint.mark_done()
	_check_finished()


func _check_finished() -> void:
	for id: String in Tutorial.REQUIRED:
		if not done.has(id):
			return
	_finish(false)


## Rehberi kapatır ve profili işaretler. `left_floor`: kat 1'den çıkıldı (ipucu hemen kapanır, duyuru çıkmaz).
func _finish(left_floor: bool) -> void:
	if finished_flag:
		return
	finished_flag = true
	Tutorial.mark_done(GameState.slot)
	if left_floor:
		if hint != null and is_instance_valid(hint):
			hint.hide_hint()
	elif run != null and is_instance_valid(run) and run.hud != null:
		run.hud.announcer.push("ÖĞRETİCİ TAMAM", GameFont.YELLOW, 44, 1.8)
	active = ""
	_disconnect_all()
	finished.emit()


func _on_flash_finished() -> void:
	active = ""
	if not finished_flag:
		_refresh()


# ---------------------------------------------------------------- olaylar

func _on_jumped(_air: bool) -> void:
	_complete(Tutorial.STEP_JUMP)


func _on_dash_used(actor: Node) -> void:
	if actor == player:
		_complete(Tutorial.STEP_DASH)


func _on_attack_started(_combo_index: int) -> void:
	attacks += 1
	if done.has(Tutorial.STEP_ATTACK):
		return
	if attacks >= Tutorial.ATTACKS_NEEDED:
		_complete(Tutorial.STEP_ATTACK)
	elif active == Tutorial.STEP_ATTACK and hint != null and is_instance_valid(hint):
		hint.show_hint(Tutorial.hint(Tutorial.STEP_ATTACK, attacks))  # sayaç güncellenir


func _on_enemy_tell(enemy: Node, _mode: int) -> void:
	_tell_enemy = enemy as EnemyBase
	if _tell_enemy != null and _tell_enemy.tell_mode() == EnemyBase.Tell.GOLD:
		_since_gold = 0.0
	_refresh()


func _on_parry_success(actor: Node, _hitbox: Node) -> void:
	if actor != player:
		return
	var first := not done.has(Tutorial.STEP_PARRY)
	_complete(Tutorial.STEP_PARRY)
	_miss_t = 0.0
	if first and not in_lobby():
		_strike_t = STRIKE_TIME


func _on_parry_failed(actor: Node) -> void:
	if actor != player or done.has(Tutorial.STEP_PARRY) or in_lobby():
		return
	if _since_gold <= MISS_WINDOW:
		_miss_t = MISS_TIME
		_refresh()


func _on_dodge_success(actor: Node, hitbox: Node) -> void:
	if actor != player:
		return
	var hb := hitbox as Hitbox
	if hb != null and not hb.parryable:
		_complete(Tutorial.STEP_RED)


func _on_damage_dealt(target: Node, _amount: int, source: Node) -> void:
	if source == player and target is EnemyBase and _strike_t > 0.0:
		_strike_t = 0.0
		_complete(Tutorial.STEP_STRIKE)


func _on_room_entered(_index: int) -> void:
	_last_x = player.global_position.x if player != null and is_instance_valid(player) else 0.0
	if not in_lobby():
		done[Tutorial.STEP_GO] = true
	# Yeni odada önceki odanın ipucu (ve bekleyen süreleri) kalmaz.
	_hold_t = 0.0
	_miss_t = 0.0
	_strike_t = 0.0
	_tell_enemy = null
	_refresh()


func _on_floor_entered(floor_no: int) -> void:
	if floor_no >= 2:
		_finish(true)
