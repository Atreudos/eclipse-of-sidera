class_name Prop
extends Node2D
## Etkileşimli eşya: yaklaşınca "E BAK", E'ye basınca esprili bir satır (Undertale tarzı). Aynı eşyaya tekrar bakınca sıradaki
## satır gelir; liste bitince son iki satır arasında döner. İlk bakışta (tür başına bir kez) +1 DOPAMİN verir.
## Çizim: `prop_<kind>` (yoksa koddan çizilen yer tutucu). `ghost = true` ise çizimsiz, yalnız etkileşim alanıdır
## (kapı gibi var olan bir nesnenin üstüne konur). `requested` sinyalini koşu denetleyicisi konuşma kutusuna çevirir.
## Orijin = zemindeki orta nokta.

signal requested(prop: Prop)

const RANGE_Y := 170.0

const KINDS := ["vazo", "sandalye", "tabela", "tas", "ayna", "kitap", "kova", "mum"]
const TEXTS := {
	"vazo": [
		"*Bir vazo. İçinde çiçek yok, ama umut var.*",
		"*Vazoya baktın. Vazo sana baktı. Kimse kırılmadı.*",
		"*Vazoyu hafifçe ittin. Vazo 'lütfen' dedi. (Demedi. Vazo bu.)*",
		"*Vazonun dibinde bir not var: 'Kırarsan senin olur.'*",
		"*Vazoyla artık arkadaşsınız. Vazo bunu bilmiyor.*",
	],
	"sandalye": [
		"*Üç bacaklı bir sandalye. Dördüncü bacak başka bir maceraya çıkmış.*",
		"*Oturdun. Sandalye 'tamam' dedi. Sonra yine 'tamam' dedi. Kalktın.*",
		"*Sandalyenin altında bir kâğıt: 'Dördüncü bacak geri gelmeyecek.'*",
		"*Sandalyeye bir daha oturmak istemedin. Sandalye bunu hissetti.*",
	],
	"tabela": [
		"*Tabelada 'DİKKAT: DİKKAT' yazıyor.*",
		"*Altında küçük harflerle: 'dikkat etmezsen dikkat çeker'.*",
		"*Tabelanın arkasında: 'Bu tabela da bir tabeladır.' Derin.*",
		"*Biri 'Şu tarafa gitme' yazıp ok çizmiş. Ok sana bakıyor.*",
	],
	"tas": [
		"*Bir taş. Çok taş.*",
		"*Taşı kaldırdın. Altında başka bir taş vardı.*",
		"*Taşla bir bağ kurdun. Adını 'Taş' koydun.*",
		"*Taş hiçbir şey söylemedi. İlk kez bir şeyin sessizliğine saygı duydun.*",
	],
	"ayna": [
		"*Aynada bir sen var. Biraz yorgun görünüyor.*",
		"*Aynadaki sen göz kırptı. Sen kırpmadın.*",
		"*Aynaya dil çıkardın. Aynadaki sen daha yaratıcıydı.*",
		"*Bir an aynada Umbra'yı gördün. Sonra sadece kendini. Ya da tersi.*",
	],
	"kitap": [
		"*Bir kitap. Son sayfa yırtılmış. Katil kim, hiç bilemeyeceksin.*",
		"*Kapağında: 'Kule İçin 100 Kolay Adım'. İlk adım: Kuleye girme.*",
		"*Kitabın içi boş. Sadece bir not: 'Okuduğun için teşekkürler.'*",
		"*Kenar boşluğuna biri yazmış: 'Gölge yalan söylemez.' Altı çizili.*",
	],
	"kova": [
		"*Bir kova. İçi boş. Kova bu durumdan memnun.*",
		"*Kovaya 'merhaba' dedin. Yankı: 'merhaba'. Kova konuşuyor!*",
		"*Kovayı kafana geçirdin. Karanlık, sessiz, huzurlu. Çıkardın.*",
		"*Kovanın dibinde bir damla su var. Su Taşıyıcı'nın mı? Belki.*",
	],
	"mum": [
		"*Bir mum yanıyor. Kimse yakmadı. Belki fener ailesindendir.*",
		"*Üfledin. Mum sönmedi. Gözlerini devirdi.*",
		"*Mum: 'Ben küçük bir fener sayılırım.' (Demedi. Ama düşündü.)*",
		"*Fenerlerin hepsi yansın diye yoldasın. Bu mum zaten yanıyor. Ona teşekkür et.*",
	],
}
## Odanın sağ kapısına bakınca.
const DOOR_LINES := [
	"*Bir kapı. Açılınca geçit olur, kapalıyken sadece kapı.*",
	"*Kapıya kulağını dayadın. Sanki 'önce şunları temizle' diyor.*",
	"*Kapı hiçbir şey demedi. Kapılar böyledir; en iyi dinleyiciler.*",
	"*Tokmağı yok. Kapı 'ben böyle rahatım' diyor.*",
]

var kind := "tas"
## Doluysa `TEXTS` yerine bu satırlar okunur.
var lines: Array = []
var range_x := 90.0
var ghost := false
var tint := Color(0.62, 0.56, 0.74)
var uses := 0
var in_range := false

var _t := 0.0
var _player: Player


## Var olan bir nesnenin yanına görünmez bir etkileşim alanı koyar.
static func attach(parent: Node, local_x: float, line_list: Array, reach: float = 90.0) -> Prop:
	var p := Prop.new()
	p.name = "Inspect_%d" % parent.get_child_count()
	p.ghost = true
	p.lines = line_list
	p.range_x = reach
	p.position = Vector2(local_x, RoomLayouts.FLOOR_Y)
	parent.add_child(p)
	return p


func _ready() -> void:
	z_index = -1
	add_to_group("props")
	add_to_group(Interact.GROUP)
	_hook_player()


func _exit_tree() -> void:
	if _player != null and is_instance_valid(_player) and _player.interacted.is_connected(_on_interacted):
		_player.interacted.disconnect(_on_interacted)


func _hook_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player != null and not _player.interacted.is_connected(_on_interacted):
		_player.interacted.connect(_on_interacted)


func can_interact() -> bool:
	return true


func _on_interacted() -> void:
	if in_range and ItemView.active_menu == null and _player != null and not _player.dead and Interact.is_best(self):
		requested.emit(self)


## Sıradaki satırı verir ve sayacı ilerletir.
func next_text() -> String:
	var pool: Array = lines if not lines.is_empty() else (TEXTS.get(kind, TEXTS["tas"]) as Array)
	var i := clampi(uses, 0, pool.size() - 1)
	uses = i + 1
	if uses >= pool.size():
		uses = maxi(pool.size() - 2, 0)
	return str(pool[i])


func _process(delta: float) -> void:
	_t += delta
	if _player == null or not is_instance_valid(_player):
		_hook_player()
	in_range = false
	if _player != null and is_instance_valid(_player) and not _player.dead:
		var d := _player.global_position - global_position
		in_range = absf(d.x) <= range_x and absf(d.y) <= RANGE_Y
	queue_redraw()


func _draw() -> void:
	var top := -100.0 if kind == "slime" else -70.0
	if not ghost:
		var art_rect := Rect2(-72.0, -100.0, 144.0, 100.0) if kind == "slime" else Rect2(-40.0, -80.0, 80.0, 80.0)
		if not Art.draw(self, "prop_%s" % kind, art_rect, _t):
			top = _draw_placeholder()
	if in_range and Interact.is_best(self):
		var pulse := 0.7 + 0.3 * sin(_t * 6.0)
		var ty := -150.0 if ghost else minf(top, -50.0) - 20.0
		GameFont.draw_runs_centered(self, [["E", GameFont.YELLOW], ["  BAK", GameFont.WHITE]], Vector2(0.0, ty), 20, pulse * (0.6 if ghost else 1.0))


## Türe göre küçük bir siluet çizer. Dönüş: çizimin en üst noktası (ipucu yazısının yeri için).
func _draw_placeholder() -> float:
	var fill := tint.darkened(0.62)
	var edge := tint
	match kind:
		"vazo":
			var pts := PackedVector2Array([Vector2(-7, -48), Vector2(7, -48), Vector2(9, -40), Vector2(17, -26), Vector2(14, -8), Vector2(10, 0), Vector2(-10, 0), Vector2(-14, -8), Vector2(-17, -26), Vector2(-9, -40)])
			draw_colored_polygon(pts, fill)
			draw_polyline(pts + PackedVector2Array([pts[0]]), edge, 2.0)
			draw_line(Vector2(0, -48), Vector2(0, -64), Color(0.45, 0.8, 0.45), 2.0)
			draw_circle(Vector2(0, -67), 4.0, Color(1.0, 0.7, 0.8))
			return -76.0
		"sandalye":
			draw_rect(Rect2(-17, -30, 34, 5), fill)
			draw_rect(Rect2(-17, -30, 34, 5), edge, false, 2.0)
			draw_line(Vector2(-14, -30), Vector2(-14, -62), edge, 3.0)
			draw_line(Vector2(-14, -62), Vector2(8, -62), edge, 3.0)
			draw_line(Vector2(-14, -25), Vector2(-17, 0), edge, 3.0)
			draw_line(Vector2(14, -25), Vector2(17, 0), edge, 3.0)
			draw_line(Vector2(0, -25), Vector2(0, -9), edge, 3.0)  # kısa, kırık üçüncü bacak
			return -66.0
		"tabela":
			draw_rect(Rect2(-3, -58, 6, 58), fill)
			draw_rect(Rect2(-3, -58, 6, 58), edge, false, 2.0)
			draw_rect(Rect2(-28, -80, 56, 28), fill)
			draw_rect(Rect2(-28, -80, 56, 28), edge, false, 2.0)
			GameFont.draw_centered(self, "!", Vector2(0.0, -66.0), 24, GameFont.YELLOW)
			return -86.0
		"tas":
			var pts2 := PackedVector2Array([Vector2(-26, 0), Vector2(-22, -14), Vector2(-9, -25), Vector2(8, -23), Vector2(21, -12), Vector2(27, 0)])
			draw_colored_polygon(pts2, fill.lightened(0.1))
			draw_polyline(pts2, edge, 2.0)
			draw_circle(Vector2(-4, -12), 2.0, edge.darkened(0.3))
			draw_circle(Vector2(8, -8), 1.5, edge.darkened(0.3))
			return -30.0
		"ayna":
			var oval := PackedVector2Array()
			for i in 24:
				var a := TAU * float(i) / 24.0
				oval.append(Vector2(16.0 * cos(a), -44.0 + 30.0 * sin(a)))
			draw_colored_polygon(oval, Color(0.55, 0.8, 0.95, 0.22))
			draw_polyline(oval + PackedVector2Array([oval[0]]), edge, 2.5)
			draw_polyline(PackedVector2Array([Vector2(-4, -62), Vector2(2, -50), Vector2(-3, -42), Vector2(5, -30)]), Color(1, 1, 1, 0.7), 1.5)
			draw_line(Vector2(0, -14), Vector2(-13, 0), edge, 3.0)
			draw_line(Vector2(0, -14), Vector2(13, 0), edge, 3.0)
			return -78.0
		"kitap":
			draw_rect(Rect2(-19, -11, 38, 11), fill)
			draw_rect(Rect2(-19, -11, 38, 11), edge, false, 2.0)
			draw_rect(Rect2(-15, -22, 31, 11), fill.lightened(0.12))
			draw_rect(Rect2(-15, -22, 31, 11), edge, false, 2.0)
			draw_line(Vector2(-15, -16), Vector2(16, -16), edge.darkened(0.2), 1.5)
			draw_line(Vector2(-19, -5), Vector2(19, -5), edge.darkened(0.2), 1.5)
			return -30.0
		"kova":
			var pts3 := PackedVector2Array([Vector2(-17, -34), Vector2(17, -34), Vector2(12, 0), Vector2(-12, 0)])
			draw_colored_polygon(pts3, fill)
			draw_polyline(pts3 + PackedVector2Array([pts3[0]]), edge, 2.0)
			draw_arc(Vector2(0, -34), 17.0, PI, TAU, 14, edge, 2.0)
			draw_line(Vector2(-16, -26), Vector2(16, -26), edge.darkened(0.25), 1.5)
			return -54.0
		"mum":
			draw_rect(Rect2(-6, -34, 12, 34), Color(0.92, 0.88, 0.78))
			draw_rect(Rect2(-6, -34, 12, 34), edge.darkened(0.2), false, 1.5)
			var flick := 1.0 + 0.12 * sin(_t * 9.0)
			var flame := PackedVector2Array([Vector2(0, -34), Vector2(-5, -42), Vector2(0, -56.0 * flick), Vector2(5, -42)])
			draw_colored_polygon(flame, Color(1.0, 0.78, 0.3))
			draw_circle(Vector2(0, -44), 36.0, Color(1.0, 0.8, 0.4, 0.07 + 0.03 * sin(_t * 5.0)))
			return -62.0
		"slime":
			return _draw_slime()
	draw_rect(Rect2(-18, -46, 36, 46), fill)
	draw_rect(Rect2(-18, -46, 36, 46), edge, false, 2.0)
	return -50.0


## Neden geldiği bilinmeyen büyük slime: nefes alıp titreşen yeşil bir kütle.
func _draw_slime() -> float:
	var squish := 0.06 * sin(_t * 2.2)
	var rx := 58.0 * (1.0 + squish)
	var ry := 44.0 * (1.0 - squish)
	var dome := PackedVector2Array()
	for i in 21:
		var a := PI * float(i) / 20.0
		dome.append(Vector2(cos(a) * rx, -sin(a) * ry))
	draw_colored_polygon(dome, Color(0.35, 0.85, 0.5, 0.88))
	draw_polyline(dome, Color(0.6, 1.0, 0.7), 2.5)
	draw_circle(Vector2(-rx * 0.35, -ry * 0.62), 7.0, Color(1, 1, 1, 0.35))
	draw_circle(Vector2(-14, -ry * 0.45), 5.0, Color(0.05, 0.2, 0.1))
	draw_circle(Vector2(14, -ry * 0.45), 5.0, Color(0.05, 0.2, 0.1))
	draw_arc(Vector2(0, -ry * 0.32), 9.0, 0.2, PI - 0.2, 8, Color(0.05, 0.2, 0.1), 2.0)
	return -ry - 22.0
