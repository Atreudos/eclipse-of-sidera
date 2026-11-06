class_name FloorPlan
extends RefCounted
## Kat planı (saf fonksiyonlar, sahne yok). Normal kipte koşu 18 KATtan oluşur; her kat 6 odadır:
##
##   1. LOBİ (düşman yok: hazırlık + dükkân) -> 2-5. SAVAŞ odaları -> 6. GÖLGE (Umbra) odası -> kat geçidi -> sonraki katın lobisi
##
## Odalar koşu boyunca 0'dan numaralanır (`index`): kat 1'in lobisi 0, ilk savaş odası 1 ... Gölge odası 5, kat 2'nin lobisi 6 ...
## Aynı tohum = aynı koşu için oda içeriği yalnız bu numaraya bağlıdır.
## Her katın şeridi x = 0'dan yeniden başlar (kat geçidinden sonra eski kat silinir).
## Düşman gücü `progress` ile büyür: bu odadan önceki savaş odası sayısı (kat başına 4).
##
## `floors = false`: kat ve lobi yok; odalar tek sonsuz şeritte akar, numara = sıra (testler ve geliştirme; eski davranış).

enum Kind { LOBBY, COMBAT, BOSS }

## Katın oda sayısı (lobi + savaş + Gölge) ve toplam kat. Değiştirirsen her şey (kayıt, HUD, testler) kendiliğinden uyar.
const ROOMS_PER_FLOOR := 6
const COMBAT_ROOMS := ROOMS_PER_FLOOR - 2
const FLOOR_COUNT := 18
## Kat teması (çizim adlarının başı: kat1_bg_far ...): her 4 katta bir değişir; son iki kat tutulma (kat5).
const THEMES: Array[String] = ["kat1", "kat2", "kat3", "kat4", "kat5"]
const FLOORS_PER_THEME := 4
const LOBBY_THEME := "lobi"


## Katın savaş odası sayısı (lobi ve Gölge odası hariç).
static func combat_rooms(_floor_no: int = 1) -> int:
	return COMBAT_ROOMS


## Katın toplam oda sayısı (lobi + savaş + Gölge).
static func slots_in_floor(_floor_no: int = 1) -> int:
	return ROOMS_PER_FLOOR


## Katın lobisinin oda numarası.
static func first_index_of(floor_no: int) -> int:
	return (maxi(floor_no, 1) - 1) * ROOMS_PER_FLOOR


## Kat `floor_no`, katın içindeki sıra `slot` (0 = lobi) -> oda numarası. Sıra katın içine kırpılır.
static func index_of(floor_no: int, slot: int) -> int:
	return first_index_of(floor_no) + clampi(slot, 0, ROOMS_PER_FLOOR - 1)


## Son kat mı? (Son katın Gölge'si "gerçek dövüş"tür; yenilince koşu biter.)
static func is_final_floor(floor_no: int) -> bool:
	return floor_no >= FLOOR_COUNT


## Katın teması ("kat1" ...).
static func theme_of(floor_no: int) -> String:
	return THEMES[mini((maxi(floor_no, 1) - 1) / FLOORS_PER_THEME, THEMES.size() - 1)]


## Oda numarasının yeri. Anahtarlar:
##   floor     kat (1'den)
##   slot      katın içindeki sıra (0'dan)
##   kind      Kind.LOBBY / Kind.COMBAT / Kind.BOSS   (kapalıyken hep COMBAT)
##   first     katın ilk odasının oda numarası
##   number    ekranda görünen oda numarası (1'den; kat içinde 1..6)
##   progress  bu odadan ÖNCE girilen savaş odası sayısı (EnemyScaling `n`; lobide sonraki odanınkiyle, Gölge'de kat sonununkiyle aynı)
##   last      katın son odası mı (kat geçidi burada)
static func locate(index: int, floors: bool = true) -> Dictionary:
	var i := maxi(index, 0)
	if not floors:
		return {"floor": 1, "slot": i, "kind": Kind.COMBAT, "first": 0, "number": i + 1, "progress": i, "last": false}
	var f := i / ROOMS_PER_FLOOR + 1
	var slot := i % ROOMS_PER_FLOOR
	var kind := Kind.COMBAT
	if slot == 0:
		kind = Kind.LOBBY
	elif slot == ROOMS_PER_FLOOR - 1:
		kind = Kind.BOSS
	return {
		"floor": f,
		"slot": slot,
		"kind": kind,
		"first": (f - 1) * ROOMS_PER_FLOOR,
		"number": slot + 1,
		"progress": (f - 1) * COMBAT_ROOMS + clampi(slot - 1, 0, COMBAT_ROOMS),
		"last": slot == ROOMS_PER_FLOOR - 1,
	}


## Oda adı: "LOBİ", "GÖLGE" ya da "ODA 3".
static func room_label(loc: Dictionary) -> String:
	match int(loc["kind"]):
		Kind.LOBBY:
			return "LOBİ"
		Kind.BOSS:
			return "GÖLGE"
	return "ODA %d" % int(loc["number"])
