class_name RoomLayouts
extends RefCounted
## Oda yerleşimleri. Odalar kodla kurulur; burada sadece yerleşim verisi durur.
## Koordinatlar oda SOLUNA göre: x sağa doğru, y ekran yüksekliği (zemin yüzeyi y = 640).
##   platforms: [x, yüzey_y, genişlik]   tek yönlü platform (20 px kalın)
##   spawns:    [x, ayak_y]              düşmanın duracağı yüzey (zemin 640 ya da bir platformun üstü)
## Yeni yerleşim eklemek için LAYOUTS'a bir satır eklemen yeter.
##
## Erişilebilirlik kuralı (testle de denetlenir): her platform, altındaki bir yüzeyden en fazla
## MAX_RISE yukarıda olmalı (oyuncu çift zıplamayla ~210 px çıkar, ama rahat çıkması için 150).

const FLOOR_Y := 640.0
const HEIGHT := 720.0
## Kameranın görebileceği yükseklik: zeminin ALTINDA da yer var, böylece kamera yukarı/aşağı azıcık oynayabilir.
const CAMERA_HEIGHT := 900.0
const PLATFORM_H := 20.0
const MAX_RISE := 150.0

const LAYOUTS := {
	# Düz zemin: sadece parry/dash hissi.
	"duz": {
		"width": 1500,
		"platforms": [],
		"spawns": [[820, 640], [1000, 640], [1180, 640], [1360, 640], [920, 640]],
	},
	# İki yan platform (test arenasındaki gibi): Ateşçiler yukarıdan sıkıştırır.
	"iki_kule": {
		"width": 1600,
		"platforms": [[260, 490, 240], [1120, 490, 240]],
		"spawns": [[880, 640], [1050, 640], [1480, 640], [380, 490], [1240, 490], [700, 640]],
	},
	# Ortada yüksek bir sahne, iki yanında basamak platformlar.
	"orta_kule": {
		"width": 1700,
		"platforms": [[180, 510, 250], [1270, 510, 250], [640, 400, 420]],
		"spawns": [[900, 640], [1100, 640], [1580, 640], [850, 400], [1390, 510], [700, 640]],
	},
	# Piramit: çıkıp inen basamaklar.
	"basamak": {
		"width": 1700,
		"platforms": [[300, 560, 200], [560, 480, 200], [820, 400, 200], [1080, 480, 200], [1340, 560, 200]],
		"spawns": [[920, 400], [1180, 480], [1440, 560], [1000, 640], [700, 640], [620, 480]],
	},
	# Uzun köprü: üstte uzun bir geçit, uçlarda basamaklar.
	"kopru": {
		"width": 1800,
		"platforms": [[220, 560, 180], [460, 470, 880], [1400, 560, 180]],
		"spawns": [[700, 470], [1100, 470], [1500, 560], [900, 640], [1250, 640], [1650, 640]],
	},
}


static func ids() -> Array:
	return LAYOUTS.keys()


static func get_layout(id: String) -> Dictionary:
	return LAYOUTS[id] if LAYOUTS.has(id) else LAYOUTS["duz"]


static func width_of(id: String) -> float:
	return float(get_layout(id)["width"])


## Rastgele bir yerleşim seçer; bir öncekiyle aynı olmaz.
static func pick(rng: RandomNumberGenerator, avoid_id: String = "") -> String:
	var all := ids()
	var options: Array = []
	for k in all:
		if k != avoid_id:
			options.append(k)
	if options.is_empty():
		options = all
	return options[rng.randi_range(0, options.size() - 1)]


## Platformların oda-yerel dikdörtgenleri (yüzey y'si üstte).
static func platform_rects(id: String) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for p in get_layout(id)["platforms"]:
		out.append(Rect2(float(p[0]), float(p[1]), float(p[2]), PLATFORM_H))
	return out


## Düşman doğma noktaları (oda-yerel, ayak konumu).
static func spawn_points(id: String) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for s in get_layout(id)["spawns"]:
		out.append(Vector2(float(s[0]), float(s[1])))
	return out


## Yerleşim kurallara uyuyor mu? Hata varsa açıklamalarını döndürür (boşsa sorun yok).
static func problems(id: String) -> Array[String]:
	var out: Array[String] = []
	var w := width_of(id)
	var plats := platform_rects(id)
	for r in plats:
		if r.position.x < 40.0 or r.end.x > w - 40.0:
			out.append("%s: platform oda dışına taşıyor %s" % [id, r])
		if r.position.y < 300.0 or r.position.y > FLOOR_Y - 60.0:
			out.append("%s: platform yüksekliği uygunsuz %s" % [id, r])
	# Her platform altındaki bir yüzeyden MAX_RISE içinde, yatayda en çok 230 px uzakta olmalı.
	for r in plats:
		var ok := false
		var rise_floor := FLOOR_Y - r.position.y
		if rise_floor <= MAX_RISE:
			ok = true
		for o in plats:
			if o == r or o.position.y <= r.position.y:
				continue
			var gap := maxf(maxf(o.position.x - r.end.x, r.position.x - o.end.x), 0.0)
			if gap <= 230.0 and (o.position.y - r.position.y) <= MAX_RISE:
				ok = true
		if not ok:
			out.append("%s: platforma çıkılamıyor %s" % [id, r])
	# Doğma noktaları bir yüzeyin üstünde olmalı.
	for s in spawn_points(id):
		if s.x < 40.0 or s.x > w - 40.0:
			out.append("%s: doğma noktası oda dışında %s" % [id, s])
		var on_surface := is_equal_approx(s.y, FLOOR_Y)
		for r in plats:
			if is_equal_approx(s.y, r.position.y) and s.x >= r.position.x + 20.0 and s.x <= r.end.x - 20.0:
				on_surface = true
		if not on_surface:
			out.append("%s: doğma noktası havada %s" % [id, s])
	return out
