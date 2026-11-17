class_name ItemData
extends Resource
## Bir eşyanın verisi. Davranışı varsa `effect_script` (ItemEffect'ten türeyen betik) taşır;
## sadece sayısal etkisi olan eşyalar `mods` ile yetinir (betik gerekmez).
##
## Yeni eşya eklemek için: items/item_db.gd içindeki listeye bir satır, gerekirse items/effects/ altına bir betik.

enum Rarity { COMMON, RARE, EPIC, CURSED }

## Eşyanın takıldığı yer. FOOD takılmaz: çantada durur ve yenir.
## WEAPON yalnız silahların ekranlarda "eşya" gibi gösterilmesi içindir (WeaponDB.display_item); gerçek eşya değildir, takılmaz.
enum Slot { FEET, CHARM, HEAD, POCKET, WRIST, ARMOR, FOOD, WEAPON }

const RARITY_NAMES: Array[String] = ["YAYGIN", "NADİR", "EFSANEVİ", "LANETLİ"]
const RARITY_COLORS: Array[Color] = [
	Color(0.72, 0.8, 0.92),   # yaygın: soğuk gri-mavi
	Color(1.0, 0.84, 0.25),   # nadir: altın
	Color(0.82, 0.52, 1.0),   # efsanevi: mor
	Color(1.0, 0.36, 0.34),   # lanetli: kırmızı
]

## Ekranda görünen slot adları (Slot sırasıyla).
const SLOT_NAMES: Array[String] = ["AYAK", "CHARM", "KAFA", "CEP", "BİLEK", "ZIRH", "YEMEK", "SİLAH"]

## Her slottan en çok kaç eşya takılabilir. (Sayıları buradan değiştir; envanter ekranı kendiliğinden uyar.)
## Ekranda gösterim sırası da budur.
const SLOT_CAPACITY := {
	Slot.HEAD: 2,
	Slot.CHARM: 3,
	Slot.ARMOR: 1,
	Slot.WRIST: 1,
	Slot.POCKET: 1,
	Slot.FEET: 1,
}

## Kısa, değişmeyen kimlik (kayıt ve test için). Örn. "vampire_relic".
var id := ""
## Ekranda görünen ad.
var display_name := ""
## Ne yaptığını anlatan kısa açıklama (bedeli varsa onu da söyler).
var description := ""
## "Gölge alırsa": Umbra bu eşyayı alırsa sana karşı ne yapar (Umbra dövüşünde uygulanacak). Boşsa gösterilmez.
var shadow_text := ""
## Etiketler: PARRY, DASH, MERMI, ALEV, BUZ, ZEHIR, CAN, RITIM, KARMA, ZAMAN, ALTIN, HAREKET, SAVUNMA. Aynı etiketten 3 eşya = sinerji bonusu.
var tags: Array[String] = []
var rarity: Rarity = Rarity.COMMON
var slot: Slot = Slot.CHARM
## Mağaza fiyatı (altın). Mağaza kat başlarında gelecek; şimdilik sadece veri.
var price := 0
## false = "Sadece Oyuncu": Umbra'ya gitmez (Aşama 4). Yemekler ve altın Umbra'ya gitmez.
var umbra_allowed := true
## Alfa > 0 ise nadirlik rengi yerine bu renk kullanılır (silahlar için).
var custom_color := Color(0.0, 0.0, 0.0, 0.0)
## Doluysa nadirlik adının yerine bu yazılır (silahlarda "SEVİYE 3").
var rarity_text := ""
## Doluysa kutudaki büyük harfin yerine bu yazılır (silah yükseltmelerinde silahın baş harfi).
var glyph_text := ""
## Doluysa simge dosyası `assets/items/<icon_id>.png` aranır (yoksa `<id>.png`): silah yükseltme ve satın alma teklifleri silahın simgesini kullanır.
var icon_id := ""
## Doluysa kutunun sol üst köşesine küçük yazılır ("+2" = yükseltme, "YENİ" = yeni silah).
var badge := ""
## Yemek: iyileştirdiği kalp sayısı. `heal_all` ise canı tamamen doldurur (iyileşme miktarı = en çok can).
var heal := 0
var heal_all := false
## Stat değişiklikleri: [[stat, ekleme, çarpım], ...] (Stats.add_modifier ile uygulanır).
var mods: Array = []
## Davranış betiği (ItemEffect'ten türer). Boşsa sadece `mods` uygulanır.
var effect_script: Script = null


static var _icon_cache := {}


## Çizim listesindeki dosya adı: `item_<id>` (animasyonlu şerit; `assets/` altında nerede durursa durur, bkz. Art).
## Silah yükseltme ve satın alma teklifleri `icon_id` ile silahın simgesini (`item_weapon_<silah>`) kullanır.
func art_name() -> String:
	return "item_" + (icon_id if icon_id != "" else id)


## ESKİ yer: assets/items/<id>.png (tek kare) varsa o, yoksa null. Çizim listesindeki animasyonlu şerit (`art_name()`) ondan önce denenir.
## İkisi de yoksa ekranlarda yer tutucu olarak adın ilk harfi çizilir.
func icon() -> Texture2D:
	var key := icon_id if icon_id != "" else id
	if _icon_cache.has(key):
		return _icon_cache[key]
	var path := "res://assets/items/%s.png" % key
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_icon_cache[key] = tex
	return tex


func color() -> Color:
	if custom_color.a > 0.0:
		return custom_color
	return RARITY_COLORS[rarity]


func rarity_name() -> String:
	return rarity_text if rarity_text != "" else RARITY_NAMES[rarity]


func slot_name() -> String:
	return SLOT_NAMES[slot]


func is_food() -> bool:
	return slot == Slot.FOOD


func is_equippable() -> bool:
	return slot != Slot.FOOD and slot != Slot.WEAPON


## Yemeğin verdiği iyileşme (kalp). Çorba gibi "tam doldur" yemekler en çok canı verir.
func heal_amount(max_health: int) -> int:
	return max_health if heal_all else heal


## Simge harfi: adın ilk harfi (yer tutucu; gerçek simge gelince değişir).
func glyph() -> String:
	if glyph_text != "":
		return glyph_text
	return GameFont.upper(display_name.substr(0, 1)) if display_name != "" else "?"


## Ekranda büyük harfle yazılan ad ("KULE EKMEĞİ").
func upper_name() -> String:
	return GameFont.upper(display_name)


func has_tag(tag: String) -> bool:
	return tag in tags
