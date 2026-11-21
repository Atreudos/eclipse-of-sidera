class_name WeaponDB
extends RefCounted
## Silahlar (Cuphead gibi): KILIÇ, YUMRUK ve SAPAN. Oyuncunun iki silah slotu vardır: J (birinci) ve I (ikinci);
## istediğin silahı istediğin slota takarsın (envanter ekranında). Her silahın 5 seviyesi vardır; seviye dükkânda yükseltilir.
##
## Bu dosya yalnız VERİDİR ve tablolardan okunan hesaplardır; oyuncu davranışı Player'dadır.
## Sayıları değiştirmek için DATA tablosuna bak: her seviye kendi tam değerlerini taşır (toplanma yok), yani
## "3. seviyede kılıç 2/2/3 vurur" diye düz okunur.
##
## Seviye girdileri (hepsi isteğe bağlı, yoksa varsayılan):
##   dmg       yakın silahta her kombo vuruşunun hasarı (dizi); sapanda taşın hasarı (sayı)
##   reach     vuruşun öne uzaklığı çarpanı (1.0)        speed  saldırı hızı çarpanı (1.0; 1.15 = %15 hızlı)
##   size      vuruş alanı çarpanı (1.0)                  knock  geri itme çarpanı (1.0)
##   cooldown  sapan: iki fırlatma arası (sn)            pierce sapan: taşın içinden geçtiği düşman sayısı
##   count     sapan: bir seferde fırlatılan taş
##   name/text bu seviyeye ULAŞTIRAN yükseltmenin adı ve ne yaptığı (1. seviyede yok)

const SWORD := "sword"
const FIST := "fist"
const SLING := "sling"

const MELEE := "melee"
const RANGED := "ranged"

## SAPAN KAPALI: oyunda kullanılmaz (verisi, kodu ve çizim adları durur). Açmak için `sling_enabled = true`
## (testler eski sapan kapsamını korumak için açar). Kapalıyken silahlar: kılıç (J) ve yumruk (I), ikisi de başta elde.
static var sling_enabled := false

## Tüm silahlar (sapan dahil), sapan açıkken ekranlarda ve dükkânda bu sırayla gelir.
const ORDER_ALL: Array[String] = ["sword", "fist", "sling"]
const ORDER_NO_SLING: Array[String] = ["sword", "fist"]
## Koşuya başlarken elindeki silahlar. Sapan açıkken J = kılıç, I = sapan (yumruk dükkândan); kapalıyken J = kılıç, I = yumruk.
const START_SLOTS_ALL: Array[String] = ["sword", "sling"]
const START_OWNED_ALL: Array[String] = ["sword", "sling"]
const START_NO_SLING: Array[String] = ["sword", "fist"]


static func order() -> Array[String]:
	return ORDER_ALL if sling_enabled else ORDER_NO_SLING


static func start_slots() -> Array[String]:
	return START_SLOTS_ALL if sling_enabled else START_NO_SLING


static func start_owned() -> Array[String]:
	return START_OWNED_ALL if sling_enabled else START_NO_SLING

## Slotların tuş adları (slot 0 = J, slot 1 = I).
const SLOT_KEYS: Array[String] = ["J", "I"]
const SLOT_COUNT := 2

## Dükkândan satın alınabilen silahlar ve taban fiyatları (başlangıç silahları satılmaz).
const UNLOCK_PRICES := {"fist": 45}
## Seviye yükseltme bedeli (taban): 1->2, 2->3, 3->4, 4->5.
const UPGRADE_COSTS: Array[int] = [30, 55, 90, 140]

## Sapan taşının genel ayarları (seviyeden bağımsız).
const SLING_SPEED := 880.0
const SLING_LIFETIME := 0.9
const SLING_RADIUS := 9.0
## Birden çok taşta taşlar arası açı (radyan).
const SLING_SPREAD := 0.14
## Fırlatma anı: hazırlık ve toparlanma (sn). Taş hazırlık bitince çıkar.
const THROW_WINDUP := 0.06
const THROW_RECOVERY := 0.11

const DATA := {
	"sword": {
		"name": "KILIÇ", "kind": "melee", "color": Color(0.85, 0.92, 1.0), "anim": "attack",
		"desc": "Dengeli üçlü kombo. Son vuruş ağır ve geniştir.",
		"attacks": [
			{"startup": 0.05, "active": 0.10, "recovery": 0.13, "size": Vector2(62, 46), "reach": 40.0, "lunge": 230.0},
			{"startup": 0.05, "active": 0.10, "recovery": 0.13, "size": Vector2(66, 46), "reach": 42.0, "lunge": 250.0},
			{"startup": 0.09, "active": 0.12, "recovery": 0.24, "size": Vector2(90, 56), "reach": 52.0, "lunge": 340.0},
		],
		"levels": [
			{"dmg": [1, 1, 2]},
			{"dmg": [1, 2, 2], "name": "KESKİN KENAR", "text": "Kombo hasarı artar."},
			{"dmg": [2, 2, 3], "reach": 1.2, "name": "UZUN SAP", "text": "Hasar artar, menzil %20 uzar."},
			{"dmg": [2, 3, 4], "reach": 1.2, "speed": 1.15, "name": "ÇEVİK BİLEK", "text": "Hasar artar, saldırı hızı %15 artar."},
			{"dmg": [3, 3, 6], "reach": 1.2, "speed": 1.15, "size": 1.15, "knock": 1.3, "name": "TUTULMA KILICI", "text": "Hasar çok artar, vuruş alanı ve geri itme büyür."},
		],
	},
	"fist": {
		"name": "YUMRUK", "kind": "melee", "color": Color(1.0, 0.7, 0.4), "anim": "punch",
		"desc": "Çok hızlı dörtlü kombo, kısa menzil. Son vuruş sert bir yumruktur.",
		"attacks": [
			{"startup": 0.03, "active": 0.07, "recovery": 0.08, "size": Vector2(44, 40), "reach": 30.0, "lunge": 120.0, "weight": 0.0},
			{"startup": 0.03, "active": 0.07, "recovery": 0.08, "size": Vector2(46, 40), "reach": 32.0, "lunge": 130.0, "weight": 0.0},
			{"startup": 0.03, "active": 0.07, "recovery": 0.09, "size": Vector2(48, 42), "reach": 32.0, "lunge": 140.0, "weight": 1.0},
			{"startup": 0.07, "active": 0.10, "recovery": 0.20, "size": Vector2(60, 56), "reach": 36.0, "lunge": 260.0, "weight": 2.0},
		],
		"levels": [
			{"dmg": [1, 1, 1, 2]},
			{"dmg": [1, 1, 2, 2], "name": "SERT EKLEMLER", "text": "Kombo hasarı artar."},
			{"dmg": [1, 2, 2, 3], "reach": 1.25, "name": "DEMİR YUMRUKLUK", "text": "Hasar artar, menzil %25 uzar."},
			{"dmg": [2, 2, 2, 3], "reach": 1.25, "speed": 1.15, "name": "ÇEVİK PARMAKLAR", "text": "Hasar artar, saldırı hızı %15 artar."},
			{"dmg": [2, 2, 3, 5], "reach": 1.25, "speed": 1.15, "knock": 1.5, "name": "TUTULMA YUMRUĞU", "text": "Hasar çok artar, geri itme %50 artar."},
		],
	},
	"sling": {
		"name": "SAPAN", "kind": "ranged", "color": Color(0.72, 0.86, 0.45), "anim": "throw",
		"desc": "Baktığın yöne taş fırlatır. Yukarı için W (ya da yukarı ok), havada aşağı için S (ya da aşağı ok) basılı tut. Nişangâh eşyası varsa kendiliğinden hedefler.",
		"levels": [
			{"dmg": 1.0, "cooldown": 0.50, "pierce": 0, "count": 1},
			{"dmg": 1.0, "cooldown": 0.40, "pierce": 0, "count": 1, "name": "SAĞLAM İP", "text": "Daha sık fırlatır."},
			{"dmg": 2.0, "cooldown": 0.40, "pierce": 0, "count": 1, "name": "SİVRİ TAŞ", "text": "Taş 2 hasar verir."},
			{"dmg": 2.0, "cooldown": 0.40, "pierce": 1, "count": 1, "name": "DELİCİ TAŞ", "text": "Taş bir düşmanın içinden geçip ikincisine de vurur."},
			{"dmg": 2.0, "cooldown": 0.36, "pierce": 1, "count": 2, "name": "ÇİFT TAŞ", "text": "Her seferinde iki taş fırlatır."},
		],
	},
}


# ---------------------------------------------------------------- sorgular

static func has(id: String) -> bool:
	return DATA.has(id) and id in order()


static func ids() -> Array[String]:
	return order().duplicate()


static func data(id: String) -> Dictionary:
	return DATA.get(id, {})


static func display_name(id: String) -> String:
	return String(data(id).get("name", id.to_upper()))


static func kind(id: String) -> String:
	return String(data(id).get("kind", MELEE))


static func is_melee(id: String) -> bool:
	return kind(id) == MELEE


static func is_ranged(id: String) -> bool:
	return kind(id) == RANGED


static func color(id: String) -> Color:
	return data(id).get("color", Color(0.85, 0.85, 0.9))


static func description(id: String) -> String:
	return String(data(id).get("desc", ""))


## Animasyon adının öneki: kılıç "attack" (attack1, attack2...), yumruk "punch", sapan "throw".
static func anim_prefix(id: String) -> String:
	return String(data(id).get("anim", "attack"))


static func max_level(id: String) -> int:
	return (data(id).get("levels", []) as Array).size()


static func clamp_level(id: String, level: int) -> int:
	return clampi(level, 1, maxi(max_level(id), 1))


## `level`. seviyenin tam girdisi (aralık dışı seviye en yakın seviyeye çekilir).
static func level_spec(id: String, level: int) -> Dictionary:
	var levels: Array = data(id).get("levels", [])
	if levels.is_empty():
		return {}
	return levels[clamp_level(id, level) - 1]


## Bu seviyeye ULAŞTIRAN yükseltmenin adı ("" = 1. seviye).
static func upgrade_name(id: String, level: int) -> String:
	return String(level_spec(id, level).get("name", ""))


static func upgrade_text(id: String, level: int) -> String:
	return String(level_spec(id, level).get("text", ""))


## `to_level` seviyesine çıkmanın taban bedeli (2..5). Geçersizse -1.
static func upgrade_cost(id: String, to_level: int) -> int:
	if not has(id) or to_level < 2 or to_level > max_level(id):
		return -1
	return UPGRADE_COSTS[mini(to_level - 2, UPGRADE_COSTS.size() - 1)]


## Dükkândan satın alma fiyatı (taban). 0 = satılmaz (başlangıç silahı).
static func unlock_price(id: String) -> int:
	return int(UNLOCK_PRICES.get(id, 0))


static func is_starter(id: String) -> bool:
	return id in start_owned()


# ---------------------------------------------------------------- yakın dövüş

## Yakın silahın `level`. seviyedeki kombosu: her vuruş {startup, active, recovery, dmg, size, reach, lunge, knock, weight}.
## Hız çarpanı hazırlık ve toparlanmayı kısaltır (vuruşun açık kalma süresi sabit); menzil, alan ve geri itme seviyeden gelir.
## `weight` vuruşun "ağırlığı"dır (durdurma ve sarsıntı gücü): verilmezse kombodaki sırası.
static func combo(id: String, level: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var d := data(id)
	if kind(id) != MELEE:
		return out
	var spec := level_spec(id, level)
	var dmgs: Array = spec.get("dmg", [])
	var speed := maxf(float(spec.get("speed", 1.0)), 0.1)
	var attacks: Array = d.get("attacks", [])
	for i in attacks.size():
		var a: Dictionary = attacks[i]
		out.append({
			"startup": float(a["startup"]) / speed,
			"active": float(a["active"]),
			"recovery": float(a["recovery"]) / speed,
			"dmg": float(dmgs[i]) if i < dmgs.size() else 1.0,
			"size": (a["size"] as Vector2) * float(spec.get("size", 1.0)),
			"reach": float(a["reach"]) * float(spec.get("reach", 1.0)),
			"lunge": float(a["lunge"]),
			"knock": float(spec.get("knock", 1.0)),
			"weight": float(a.get("weight", float(i))),
		})
	return out


## Kombodaki toplam hasar (ekranlarda "KOMBO 1·1·2 = 4").
static func combo_damage(id: String, level: int) -> int:
	var total := 0
	for a in combo(id, level):
		total += roundi(float(a["dmg"]))
	return total


# ---------------------------------------------------------------- menzilli

## Sapanın `level`. seviyedeki fırlatma ayarları:
## {damage, cooldown, speed, lifetime, pierce, count, spread, windup, recovery, radius}
static func shot(id: String, level: int) -> Dictionary:
	if kind(id) != RANGED:
		return {}
	var spec := level_spec(id, level)
	return {
		"damage": float(spec.get("dmg", 1.0)),
		"cooldown": float(spec.get("cooldown", 0.5)),
		"speed": SLING_SPEED,
		"lifetime": SLING_LIFETIME,
		"pierce": int(spec.get("pierce", 0)),
		"count": maxi(int(spec.get("count", 1)), 1),
		"spread": SLING_SPREAD,
		"windup": THROW_WINDUP,
		"recovery": THROW_RECOVERY,
		"radius": SLING_RADIUS,
	}


# ---------------------------------------------------------------- ekran metinleri

## Silahın o seviyedeki özet satırları (envanter ve dükkân ayrıntı panelinde).
static func stat_lines(id: String, level: int) -> Array[String]:
	var lines: Array[String] = []
	var spec := level_spec(id, level)
	if is_melee(id):
		var parts: Array[String] = []
		for a in combo(id, level):
			parts.append(str(roundi(float(a["dmg"]))))
		lines.append("KOMBO HASARI  %s  (TOPLAM %d)" % ["-".join(parts), combo_damage(id, level)])
		var reach := float(spec.get("reach", 1.0))
		if not is_equal_approx(reach, 1.0):
			lines.append("MENZİL  %+d%%" % roundi((reach - 1.0) * 100.0))
		var speed := float(spec.get("speed", 1.0))
		if not is_equal_approx(speed, 1.0):
			lines.append("HIZ  %+d%%" % roundi((speed - 1.0) * 100.0))
		var knock := float(spec.get("knock", 1.0))
		if not is_equal_approx(knock, 1.0):
			lines.append("GERİ İTME  %+d%%" % roundi((knock - 1.0) * 100.0))
	elif is_ranged(id):
		var s := shot(id, level)
		lines.append("%d TAŞ x %d HASAR" % [int(s["count"]), roundi(float(s["damage"]))])
		lines.append("BEKLEME  %.2f SN" % float(s["cooldown"]))
		if int(s["pierce"]) > 0:
			lines.append("DELER  %d DÜŞMAN" % int(s["pierce"]))
	return lines


## Seviye adı ("SEVİYE 3"; en üst seviyede "EN ÜST").
static func level_text(id: String, level: int) -> String:
	var l := clamp_level(id, level)
	return "SEVİYE %d" % l if l < max_level(id) else "SEVİYE %d  (EN ÜST)" % l


static var _icons := {}
## Gösterim eşyaları (silah:seviye): ekranlar her karede sorar, bir kez kurulur. Dönen nesne değiştirilmemeli.
static var _display_cache := {}


## Çizim listesindeki silah simgesi var mı (`item_weapon_<id>.png` ya da eski `assets/items/weapon_<id>.png`)?
static func has_icon(id: String) -> bool:
	return Art.has("item_weapon_" + id) or icon(id) != null


## Silah simgesini `rect` içine çizer (animasyonluysa `t` saniyedeki kare). Çizim yoksa false: çağıran yer tutucusunu çizer.
static func draw_icon(ci: CanvasItem, rect: Rect2, id: String, t: float = 0.0) -> bool:
	if Art.draw(ci, "item_weapon_" + id, rect, t):
		return true
	var tex := icon(id)
	if tex == null:
		return false
	ci.draw_texture_rect(tex, rect, false)
	return true


## ESKİ yer: `assets/items/weapon_<id>.png` (tek kare) varsa o, yoksa null.
static func icon(id: String) -> Texture2D:
	if _icons.has(id):
		return _icons[id]
	var path := "res://assets/items/weapon_%s.png" % id
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_icons[id] = tex
	return tex


## Envanter, dükkân ve HUD'un eşya çizen kodunu kullanabilmesi için silahı "eşya" gibi gösteren ayrıntı nesnesi.
## ItemDB'ye KONMAZ (havuzlara, ödüle ve dükkân rafına karışmaz); simge `assets/items/weapon_<id>.png` olabilir.
static func display_item(id: String, level: int = 1) -> ItemData:
	var l := clamp_level(id, level)
	var key := "%s:%d" % [id, l]
	if _display_cache.has(key):
		return _display_cache[key]
	var it := ItemData.new()
	it.id = "weapon_" + id
	it.display_name = String(data(id).get("name", id))
	it.slot = ItemData.Slot.WEAPON
	it.rarity = ItemData.Rarity.COMMON
	it.custom_color = color(id)
	it.rarity_text = level_text(id, l)
	it.glyph_text = GameFont.upper(String(data(id).get("name", id)).substr(0, 1))
	var text := description(id)
	var lines := stat_lines(id, l)
	if not lines.is_empty():
		text += "\n" + "\n".join(lines)
	it.description = text
	_display_cache[key] = it
	return it


## Dükkânda "yeni silah" teklifinin gösterim eşyası: silahın 1. seviye hâli, köşede "YENİ".
static func unlock_display(id: String) -> ItemData:
	var key := "unlock:" + id
	if _display_cache.has(key):
		return _display_cache[key]
	var base := display_item(id, 1)
	var it := ItemData.new()
	it.id = "weapon_buy_" + id
	it.display_name = base.display_name
	it.slot = ItemData.Slot.WEAPON
	it.rarity = ItemData.Rarity.COMMON
	it.custom_color = base.custom_color
	it.rarity_text = "YENİ SİLAH"
	it.glyph_text = base.glyph_text
	it.icon_id = "weapon_" + id
	it.badge = "YENİ"
	it.description = base.description
	_display_cache[key] = it
	return it


## Dükkânda yükseltme teklifinin gösterim eşyası: ad = yükseltmenin adı; açıklama = ne değiştiği, şimdiki ve yeni satırlar.
static func upgrade_display(id: String, to_level: int) -> ItemData:
	var l := clamp_level(id, to_level)
	var key := "up:%s:%d" % [id, l]
	if _display_cache.has(key):
		return _display_cache[key]
	var it := ItemData.new()
	it.id = "weapon_up_%s_%d" % [id, l]
	it.display_name = upgrade_name(id, l) if upgrade_name(id, l) != "" else display_name(id)
	it.slot = ItemData.Slot.WEAPON
	it.rarity = ItemData.Rarity.COMMON
	it.custom_color = color(id)
	it.rarity_text = "%s  %d > %d" % [display_name(id), l - 1, l]
	it.glyph_text = GameFont.upper(String(data(id).get("name", id)).substr(0, 1))
	it.badge = "+%d" % l
	it.icon_id = "weapon_" + id
	var text := upgrade_text(id, l)
	var now := stat_lines(id, l - 1)
	var then := stat_lines(id, l)
	if not now.is_empty():
		text += "\nŞİMDİ\n" + "\n".join(now) + "\nSONRA\n" + "\n".join(then)
	it.description = text
	_display_cache[key] = it
	return it
