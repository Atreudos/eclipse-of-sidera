class_name ItemData
extends Resource
## Bir eşyanın verisi. Davranışı varsa `effect_script` (ItemEffect'ten türeyen betik) taşır;
## sadece sayısal etkisi olan eşyalar `mods` ile yetinir (betik gerekmez).
##
## Yeni eşya eklemek için: items/item_db.gd içindeki listeye bir satır, gerekirse items/effects/ altına bir betik.

enum Rarity { COMMON, RARE, EPIC, CURSED }

## Eşyanın takıldığı yer. FOOD takılmaz: çantada durur ve yenir.
enum Slot { FEET, CHARM, HEAD, POCKET, WRIST, ARMOR, FOOD }

const RARITY_NAMES: Array[String] = ["YAYGIN", "NADİR", "EFSANEVİ", "LANETLİ"]
const RARITY_COLORS: Array[Color] = [
	Color(0.72, 0.8, 0.92),   # yaygın: soğuk gri-mavi
	Color(1.0, 0.84, 0.25),   # nadir: altın
	Color(0.82, 0.52, 1.0),   # efsanevi: mor
	Color(1.0, 0.36, 0.34),   # lanetli: kırmızı
]

## Ekranda görünen slot adları (Slot sırasıyla).
const SLOT_NAMES: Array[String] = ["AYAK", "CHARM", "KAFA", "CEP", "BİLEK", "ZIRH", "YEMEK"]

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
## Etiketler: PARRY, DASH, MERMI, ALEV, BUZ, ZEHIR, CAN, RITIM, KARMA. Aynı etiketten 3 eşya = sinerji bonusu.
var tags: Array[String] = []
var rarity: Rarity = Rarity.COMMON
var slot: Slot = Slot.CHARM
## Mağaza fiyatı (altın). Mağaza kat başlarında gelecek; şimdilik sadece veri.
var price := 0
## false = "Sadece Oyuncu": Umbra'ya gitmez (Aşama 4). Yemekler ve altın Umbra'ya gitmez.
var umbra_allowed := true
## Yemek: iyileştirdiği kalp sayısı. `heal_all` ise canı tamamen doldurur (iyileşme miktarı = en çok can).
var heal := 0
var heal_all := false
## Stat değişiklikleri: [[stat, ekleme, çarpım], ...] (Stats.add_modifier ile uygulanır).
var mods: Array = []
## Davranış betiği (ItemEffect'ten türer). Boşsa sadece `mods` uygulanır.
var effect_script: Script = null


func color() -> Color:
	return RARITY_COLORS[rarity]


func rarity_name() -> String:
	return RARITY_NAMES[rarity]


func slot_name() -> String:
	return SLOT_NAMES[slot]


func is_food() -> bool:
	return slot == Slot.FOOD


func is_equippable() -> bool:
	return slot != Slot.FOOD


## Yemeğin verdiği iyileşme (kalp). Çorba gibi "tam doldur" yemekler en çok canı verir.
func heal_amount(max_health: int) -> int:
	return max_health if heal_all else heal


## Simge harfi: adın ilk harfi (yer tutucu; gerçek simge gelince değişir).
func glyph() -> String:
	return GameFont.upper(display_name.substr(0, 1)) if display_name != "" else "?"


## Ekranda büyük harfle yazılan ad ("KULE EKMEĞİ").
func upper_name() -> String:
	return GameFont.upper(display_name)


func has_tag(tag: String) -> bool:
	return tag in tags
