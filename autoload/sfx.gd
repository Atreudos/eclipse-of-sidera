extends Node
## Ses efektleri. Dosyalar assets/sfx/ klasöründe (tools/make_sfx.py ile üretilen geçici sesler).
## Gerçek sesleri aynı dosya adlarıyla üzerine koyman yeterli.
##
## Kullanım:  Sfx.play("parry")

const NAMES := ["parry", "hit", "hurt", "dash", "whiff", "shoot", "kill", "tell_gold", "tell_red", "slash"]
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
	EventBus.parry_success.connect(func(_a: Node, _b: Node) -> void: play("parry", 0.0))
	EventBus.parry_failed.connect(func(_a: Node) -> void: play("whiff", -4.0))
	EventBus.dash_used.connect(func(_a: Node) -> void: play("dash", -3.0, 1.0, 0.05))
	EventBus.enemy_died.connect(func(_e: Node) -> void: play("kill", -2.0, 1.0, 0.06))
	EventBus.damage_dealt.connect(_on_damage)


func _on_damage(target: Node, _amount: int, _source: Node) -> void:
	if target is Player:
		play("hurt", 0.0)
	else:
		play("hit", -2.0, 1.0, 0.08)


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
