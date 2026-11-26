class_name Prop
extends Node2D
## Etkileşimli eşya: yaklaşınca "E BAK", E'ye basınca esprili bir satır (Undertale tarzı). Çizim: `prop_<kind>` (yoksa yer tutucu).
## Aynı eşyaya tekrar bakınca sıradaki satır gelir. `requested` sinyalini koşu denetleyicisi konuşma kutusuna çevirir.

signal requested(prop: Prop)

const RANGE_X := 90.0
const RANGE_Y := 170.0

const TEXTS := {
	"vazo": ["*Bir vazo. İçinde çiçek yok, ama umut var.*", "*Vazoya baktın. Vazo sana baktı. Kimse kırılmadı.*", "*Vazo: 'Lütfen itme.' (Demedi. Vazo bu.)*"],
	"sandalye": ["*Üç bacaklı bir sandalye. Dördüncü bacak başka bir maceraya çıkmış.*", "*Oturdun. Sandalye 'tamam' dedi. Sonra yine 'tamam' dedi. Kalktın.*"],
	"tabela": ["*Tabelada 'DİKKAT: DİKKAT' yazıyor.*", "*Altında küçük harflerle: 'dikkat etmezsen dikkat çeker'.*"],
	"tas": ["*Bir taş. Çok taş.*", "*Taşı kaldırdın. Altında başka bir taş vardı.*", "*Taşla bir bağ kurdun. Adını 'Taş' koydun.*"],
	"ayna": ["*Aynada bir sen var. Biraz yorgun görünüyor.*", "*Aynadaki sen göz kırptı. Sen kırpmadın.*"],
	"kitap": ["*Bir kitap. Son sayfa yırtılmış. Katil kim, hiç bilemeyeceksin.*", "*Kapağında: 'Kule İçin 100 Kolay Adım'. İlk adım: Kuleye girme.*"],
	"kova": ["*Bir kova. İçi boş. Kova bu durumdan memnun.*", "*Kovaya 'merhaba' dedin. Yankı: 'merhaba'. Kova konuşuyor!*"],
	"mum": ["*Bir mum yanıyor. Kimse yakmadı. Belki fener ailesindendir.*", "*Üfledin. Mum sönmedi. Gözlerini devirdi.*"],
}
const KINDS := ["vazo", "sandalye", "tabela", "tas", "ayna", "kitap", "kova", "mum"]
const SPEAKER := ""

var kind := "tas"
var uses := 0
var in_range := false

var _t := 0.0
var _player: Player


func _ready() -> void:
	z_index = -1
	add_to_group("props")
	_hook_player()


func _exit_tree() -> void:
	if _player != null and is_instance_valid(_player) and _player.interacted.is_connected(_on_interacted):
		_player.interacted.disconnect(_on_interacted)


func _hook_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player != null and not _player.interacted.is_connected(_on_interacted):
		_player.interacted.connect(_on_interacted)


func _on_interacted() -> void:
	if in_range and ItemView.active_menu == null and _player != null and not _player.dead:
		requested.emit(self)


## Sıradaki satırı verir ve sayacı artırır.
func next_text() -> String:
	var lines: Array = TEXTS.get(kind, TEXTS["tas"])
	var s := str(lines[mini(uses, lines.size() - 1)])
	if uses >= lines.size() - 1 and lines.size() > 1:
		uses = 1  # son satırdan sonra son iki satır arasında döner
	else:
		uses += 1
	return s


func _process(delta: float) -> void:
	_t += delta
	if _player == null or not is_instance_valid(_player):
		_hook_player()
	in_range = false
	if _player != null and is_instance_valid(_player) and not _player.dead:
		var d := _player.global_position - global_position
		in_range = absf(d.x) <= RANGE_X and absf(d.y) <= RANGE_Y
	queue_redraw()


func _draw() -> void:
	if not Art.draw(self, "prop_%s" % kind, Rect2(-40.0, -80.0, 80.0, 80.0), _t):
		var c := Color(0.6, 0.55, 0.7)
		draw_rect(Rect2(-18.0, -46.0, 36.0, 46.0), c.darkened(0.6))
		draw_rect(Rect2(-18.0, -46.0, 36.0, 46.0), c, false, 2.0)
		GameFont.draw_centered(self, kind.substr(0, 1).to_upper(), Vector2(0.0, -24.0), 22, c.lightened(0.3))
	if in_range:
		var pulse := 0.7 + 0.3 * sin(_t * 6.0)
		GameFont.draw_runs_centered(self, [["E", GameFont.YELLOW], ["  BAK", GameFont.WHITE]], Vector2(0.0, -70.0), 20, pulse)
