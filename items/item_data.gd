class_name ItemData
extends Resource
## Bir eşyanın verisi. Davranışı varsa `effect_script` (ItemEffect'ten türeyen betik) taşır;
## sadece sayısal etkisi olan eşyalar `mods` ile yetinir (betik gerekmez).
##
## Yeni eşya eklemek için: items/item_db.gd içindeki listeye bir satır, gerekirse items/effects/ altına bir betik.

enum Rarity { COMMON, RARE, EPIC, CURSED }

const RARITY_NAMES: Array[String] = ["YAYGIN", "NADİR", "EFSANEVİ", "LANETLİ"]
const RARITY_COLORS: Array[Color] = [
	Color(0.72, 0.8, 0.92),   # yaygın: soğuk gri-mavi
	Color(1.0, 0.84, 0.25),   # nadir: altın
	Color(0.82, 0.52, 1.0),   # efsanevi: mor
	Color(1.0, 0.36, 0.34),   # lanetli: kırmızı
]

## Kısa, değişmeyen kimlik (kayıt ve test için). Örn. "golden_tooth".
var id := ""
## Ekranda görünen ad.
var display_name := ""
## Ne yaptığını anlatan kısa açıklama (bedeli varsa onu da söyler).
var description := ""
## Etiketler: PARRY, DASH, MERMI, ALEV, BUZ, ZEHIR, CAN, RITIM, KARMA. Aynı etiketten 3 eşya = sinerji bonusu.
var tags: Array[String] = []
var rarity: Rarity = Rarity.COMMON
## false = "Sadece Oyuncu": Umbra'ya gitmez (Aşama 4).
var umbra_allowed := true
## Stat değişiklikleri: [[stat, ekleme, çarpım], ...] (Stats.add_modifier ile uygulanır).
var mods: Array = []
## Davranış betiği (ItemEffect'ten türer). Boşsa sadece `mods` uygulanır.
var effect_script: Script = null


func color() -> Color:
	return RARITY_COLORS[rarity]


func rarity_name() -> String:
	return RARITY_NAMES[rarity]


## Simge harfi: adın ilk harfi (yer tutucu; gerçek simge gelince değişir).
func glyph() -> String:
	return display_name.substr(0, 1).to_upper() if display_name != "" else "?"


func has_tag(tag: String) -> bool:
	return tag in tags
