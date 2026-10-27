extends Node
## Ses efektleri. Dosyalar assets/sfx/ klasöründe (tools/make_sfx.py ile üretilen geçici sesler).
## Gerçek sesleri aynı dosya adlarıyla üzerine koyman yeterli.
##
## Kullanım:  Sfx.play("parry")

const NAMES := [
	"parry", "hit", "hurt", "dash", "whiff", "shoot", "kill", "tell_gold", "tell_red", "slash",
	"door_open", "door_slam", "spawn", "room_clear", "land", "pickup", "left_behind",
	"tier_up", "tier_down", "heal", "thrust", "vanish",
	"eat", "shield_break", "coin", "mirror_crack", "timestop", "timestop_end",
	"ui_move", "ui_select", "ui_deny", "equip",
]
const VOICES := 12

## Genel ses seviyesi (dB). Daha kısık için negatif sayıyı büyüt (örn. -12).
var master_db := -6.0

var _streams := {}
var _voices: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for sfx_name: String in NAMES:
		var path := "res://assets/sfx/%s.wav" % sfx_name
		if ResourceLoader.exists(path):
			_streams[sfx_name] = load(path)
	for i in VOICES:
		var v := AudioStreamPlayer.new()
		add_child(v)
		_voices.append(v)
	EventBus.parry_failed.connect(func(_a: Node) -> void: play("whiff", -4.0))
	EventBus.dash_used.connect(func(_a: Node) -> void: play("dash", -3.0, 1.0, 0.05))
	EventBus.enemy_died.connect(func(_e: Node) -> void: play("kill", -2.0, 1.0, 0.06))
	EventBus.room_cleared.connect(func(_i: int) -> void: play("room_clear", -2.0))
	EventBus.healed.connect(func(_a: Node, _n: int) -> void: play("heal", -2.0))
	EventBus.damage_dealt.connect(_on_damage)


func _on_damage(target: Node, _amount: int, _source: Node) -> void:
	if target is Player:
		play("hurt", 0.0)
	else:
		play("hit", -2.0, 1.0, 0.08)


## Kombo içindeki art arda parry'ler pentatonik bir merdiven çıkar (1. parry en alçak).
const PARRY_STEPS := [0, 2, 4, 7, 9, 12, 14, 16]


## Kombodaki `index`. parry'nin perde çarpanı (1 = ilk = 1.0). Merdivenin sonunda sabit kalır.
static func parry_pitch(index: int) -> float:
	var step: int = PARRY_STEPS[clampi(index - 1, 0, PARRY_STEPS.size() - 1)]
	return pow(2.0, step / 12.0)


## `index`: kombodaki kaçıncı parry (1 = ilk). Perde her parry'de yükselir; kombo bitince başa döner.
func play_parry(index: int = 1) -> void:
	play("parry", 0.0, parry_pitch(index))


## pitch_jitter: sesin her çalışta hafifçe değişmesi (tekrar hissini azaltır).
func play(sfx_name: String, volume_db: float = 0.0, pitch: float = 1.0, pitch_jitter: float = 0.0) -> void:
	if not _streams.has(sfx_name) or _voices.is_empty():
		return
	var v := _voices[_next]
	_next = (_next + 1) % _voices.size()
	v.stream = _streams[sfx_name]
	v.volume_db = master_db + volume_db
	v.pitch_scale = maxf(pitch + randf_range(-pitch_jitter, pitch_jitter), 0.1)
	v.play()
