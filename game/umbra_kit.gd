class_name UmbraKit
extends RefCounted
## Gölge'nin (Umbra) yetenek merdiveni ve güç ölçeklemesi. Saf fonksiyonlar: sahne yok; testler, plan ve README aynı sayıları kullanır.
##
## Her katın sonunda Gölge'yle dövüşülür. Her kat Gölge YENİ BİR YETENEK kazanır, öncekileri korur (18 kat = 18 yetenek).
## Yetenek ya bir HAMLE'dir (bıçak, fırlatma, minyon...) ya da bir PASİF'tir (zırh, ikinci nefes, gerçek dövüş).
## Gölge her katta daha canlı, daha hızlı, daha az bekleyen ve daha çok kırmızı saldırı yapan biridir.
## 18. kat "gerçek dövüş"tür: bütün yetenekler + ikinci evre (yarı canda öfkelenir).
##
##   Kat  Yetenek            Kat  Yetenek            Kat  Yetenek
##    1   Bıçak               7   Yer darbesi        13   Gizlenme
##    2   Fırlatma            8   Zırh (pasif)       14   Duvardan atış
##    3   Duvar tırmanışı     9   Bıçak yağmuru      15   İkinci nefes (pasif)
##    4   Minyon çağırma     10   Üçlü kombo         16   Gölge klonu
##    5   Gölge adımı        11   Sürü               17   Karşı duruş
##    6   Üçlü fırlatma      12   Dönen bıçaklar     18   Gerçek dövüş (pasif)

## Gölge'nin hamleleri. NONE = hamle yok (yürür/kollar). WIND = soluklanma/öfke kükremesi (seçilmez, zorlanır).
enum Move { NONE, KNIFE, THROW, CLIMB, MINIONS, BLINK, FAN, SLAM, RAIN, COMBO, SWARM, ORBIT, CLOAK, VOLLEY, CLONE, COUNTER, WIND }

const FLOOR_COUNT := FloorPlan.FLOOR_COUNT

## Yetenek merdiveni: dizinin i. elemanı (i + 1). katta kazanılan YENİ yetenektir. "move" hamle, "passive" pasif (biri doludur).
const LADDER := [
	{"id": "knife", "name": "BIÇAK", "move": Move.KNIFE, "text": "Yakın dövüş bıçağı: altın (parry'le) ya da kırmızı (kaç) darbe."},
	{"id": "throw", "name": "FIRLATMA", "move": Move.THROW, "text": "Bıçak fırlatır. Altın bıçağı parry'lersen ona geri döner."},
	{"id": "climb", "name": "DUVAR TIRMANIŞI", "move": Move.CLIMB, "text": "Duvara tırmanır, tepeden üstüne atlar."},
	{"id": "minions", "name": "MİNYON ÇAĞIRMA", "move": Move.MINIONS, "text": "Küçük gölge minyonlar çağırır."},
	{"id": "blink", "name": "GÖLGE ADIMI", "move": Move.BLINK, "text": "Kaybolur, arkandan çıkıp vurur."},
	{"id": "fan", "name": "ÜÇLÜ FIRLATMA", "move": Move.FAN, "text": "Üç bıçağı yelpaze gibi fırlatır."},
	{"id": "slam", "name": "YER DARBESİ", "move": Move.SLAM, "text": "Zıplayıp çakılır; yerde şok dalgaları koşar (zıpla ya da dash)."},
	{"id": "armor", "name": "ZIRH", "passive": "armor", "text": "Saldırı hazırlarken vurmak onu bölmez; yalnız parry bozar."},
	{"id": "rain", "name": "BIÇAK YAĞMURU", "move": Move.RAIN, "text": "Gökten işaretli yerlere bıçak yağdırır."},
	{"id": "combo", "name": "ÜÇLÜ KOMBO", "move": Move.COMBO, "text": "Arka arkaya üç darbe; sonuncusu hep kırmızıdır."},
	{"id": "swarm", "name": "SÜRÜ", "move": Move.SWARM, "text": "Bir seferde çok daha fazla minyon çağırır."},
	{"id": "orbit", "name": "DÖNEN BIÇAKLAR", "move": Move.ORBIT, "text": "Etrafında dönen bıçaklarla üstüne yürür (parry'lersen kırılır)."},
	{"id": "cloak", "name": "GİZLENME", "move": Move.CLOAK, "text": "Neredeyse görünmez olup sessizce yaklaşır."},
	{"id": "volley", "name": "DUVARDAN ATIŞ", "move": Move.VOLLEY, "text": "Duvara tırmanıp tepeden üç bıçak yağdırır."},
	{"id": "second_wind", "name": "İKİNCİ NEFES", "passive": "second_wind", "text": "Canı bitince bir kez daha kalkar ve öfkelenir."},
	{"id": "clone", "name": "GÖLGE KLONU", "move": Move.CLONE, "text": "Karşı yanında bir klon belirir; biri altın, biri kırmızı vurur."},
	{"id": "counter", "name": "KARŞI DURUŞ", "move": Move.COUNTER, "text": "Savunmaya geçer: vurursan karşılık verir, beklersen parry fırsatı."},
	{"id": "real", "name": "GERÇEK DÖVÜŞ", "passive": "real", "text": "Her şey bir arada; yarı canda ikinci evre başlar."},
]

## Hamle başına seçimlik kilit (sn): aynı büyük hamle üst üste gelmesin. Gölge'nin bekleme çarpanıyla kısalır.
const LOCKOUT := {
	Move.KNIFE: 0.0, Move.THROW: 1.6, Move.CLIMB: 7.0, Move.MINIONS: 15.0, Move.BLINK: 5.0, Move.FAN: 4.5,
	Move.SLAM: 6.5, Move.RAIN: 10.0, Move.COMBO: 3.5, Move.SWARM: 19.0, Move.ORBIT: 11.0, Move.CLOAK: 11.0,
	Move.VOLLEY: 8.5, Move.CLONE: 12.0, Move.COUNTER: 13.0, Move.WIND: 0.0,
}

## Hamle adları (hata ayıklama ve belge için).
const MOVE_NAMES := {
	Move.NONE: "—", Move.KNIFE: "BIÇAK", Move.THROW: "FIRLATMA", Move.CLIMB: "DUVAR TIRMANIŞI", Move.MINIONS: "MİNYON",
	Move.BLINK: "GÖLGE ADIMI", Move.FAN: "ÜÇLÜ FIRLATMA", Move.SLAM: "YER DARBESİ", Move.RAIN: "BIÇAK YAĞMURU",
	Move.COMBO: "KOMBO", Move.SWARM: "SÜRÜ", Move.ORBIT: "DÖNEN BIÇAKLAR", Move.CLOAK: "GİZLENME",
	Move.VOLLEY: "DUVARDAN ATIŞ", Move.CLONE: "KLON", Move.COUNTER: "KARŞI DURUŞ", Move.WIND: "SOLUKLANMA",
}

## Umbra'nın (seçilmeyip kalan) eşyalardan uygulayabildiği stat'lar: yalnız sayısal etkiler (can, hasar, hız, alınan hasar).
const ITEM_STATS: Array[String] = ["max_health", "attack_damage", "move_speed", "damage_taken"]
## Eşyadan gelen her +1 azami can, Gölge'nin canına bu oranda eklenir (kalp, Gölge'nin ölçeğinde küçük bir şeydir).
const ITEM_HP_PER_POINT := 0.06


static func clamp_floor(floor_no: int) -> int:
	return clampi(floor_no, 1, FLOOR_COUNT)


## Katın YENİ yeteneği (LADDER girdisi).
static func ability(floor_no: int) -> Dictionary:
	return LADDER[clamp_floor(floor_no) - 1]


static func ability_name(floor_no: int) -> String:
	return str(ability(floor_no)["name"])


static func ability_text(floor_no: int) -> String:
	return str(ability(floor_no)["text"])


## O katta Gölge'nin yapabildiği hamleler (o ve önceki katların yetenekleri).
static func moves_for(floor_no: int) -> Array:
	var out: Array = []
	for i in clamp_floor(floor_no):
		var m := int((LADDER[i] as Dictionary).get("move", Move.NONE))
		if m != Move.NONE:
			out.append(m)
	return out


## O katta açık pasifler ("armor", "second_wind", "real").
static func passives_for(floor_no: int) -> Array:
	var out: Array = []
	for i in clamp_floor(floor_no):
		var p := str((LADDER[i] as Dictionary).get("passive", ""))
		if p != "":
			out.append(p)
	return out


static func has_passive(floor_no: int, passive: String) -> bool:
	return passive in passives_for(floor_no)


## Hamlenin ilk açıldığı kat (0 = hiç).
static func floor_of_move(m: int) -> int:
	for i in LADDER.size():
		if int((LADDER[i] as Dictionary).get("move", Move.NONE)) == m:
			return i + 1
	return 0


# ---------------------------------------------------------------- ölçekleme (kat başına)

## Gölge'nin kat çarpanları. Düşman ölçeklemesine (EnemyScaling: can, hasar...) EK olarak uygulanır.
static func hp_mult(floor_no: int) -> float:
	return 1.0 + 0.07 * float(clamp_floor(floor_no) - 1)


static func hp_for(floor_no: int, base_hp: int) -> int:
	return maxi(1, roundi(float(base_hp) * hp_mult(floor_no)))


static func speed_mult(floor_no: int) -> float:
	return 1.0 + 0.012 * float(clamp_floor(floor_no) - 1)


## Hamleler arası bekleme çarpanı: 1. katta 1.0, 18. katta 0.55.
static func wait_mult(floor_no: int) -> float:
	return lerpf(1.0, 0.55, float(clamp_floor(floor_no) - 1) / float(FLOOR_COUNT - 1))


## Kırmızı (parry'lenemez) saldırı payına eklenen: 0 -> 0.15.
static func red_bonus(floor_no: int) -> float:
	return 0.15 * float(clamp_floor(floor_no) - 1) / float(FLOOR_COUNT - 1)


## Bir minyon çağrısında kaç minyon gelir (sürü +2).
static func minion_count(floor_no: int, swarm: bool) -> int:
	var f := clamp_floor(floor_no)
	return 2 + maxi(f - 4, 0) / 5 + (2 if swarm else 0)


## Aynı anda sahnede en çok kaç minyon olabilir.
static func minion_cap(floor_no: int) -> int:
	return 4 + clamp_floor(floor_no) / 6


## Bıçak yağmurunda bıçak sayısı.
static func rain_count(floor_no: int) -> int:
	return 5 + clamp_floor(floor_no) / 6


## Dönen bıçak sayısı.
static func orbit_count(floor_no: int) -> int:
	return 2 + clamp_floor(floor_no) / 9


## Gölge'nin bir katın bütün sayıları tek pakette.
static func spec(floor_no: int) -> Dictionary:
	var f := clamp_floor(floor_no)
	var passives := passives_for(f)
	return {
		"floor": f,
		"name": ability_name(f),
		"moves": moves_for(f),
		"passives": passives,
		"hp": hp_mult(f),
		"speed": speed_mult(f),
		"wait": wait_mult(f),
		"red": red_bonus(f),
		"minions": minion_count(f, false),
		"swarm": minion_count(f, true),
		"minion_cap": minion_cap(f),
		"rain": rain_count(f),
		"orbit": orbit_count(f),
		"armor": "armor" in passives,
		"second_wind": "second_wind" in passives,
		"real": "real" in passives,
	}


# ---------------------------------------------------------------- hamle seçimi

## Hamlenin o anki ağırlığı. `ctx`: dx (yatay uzaklık), level (aynı yükseklik mi), hp (0..1), minions, proj (havadaki bıçak sayısı),
## phase (1/2), last (son hamle), force_melee (poise kırıldı: yakınsa yakın dövüş), wall (kaçacağı duvara uzaklık).
static func weight(m: int, ctx: Dictionary) -> float:
	var dx: float = float(ctx.get("dx", 300.0))
	var level: bool = bool(ctx.get("level", true))
	var hp: float = float(ctx.get("hp", 1.0))
	var minions: int = int(ctx.get("minions", 0))
	var proj: int = int(ctx.get("proj", 0))
	var phase: int = int(ctx.get("phase", 1))
	var near := dx <= 240.0 and level
	var w := 0.0
	match m:
		Move.KNIFE:
			if near:
				w = 10.0
			elif dx <= 340.0 and level:
				w = 4.0
		Move.COMBO:
			if near:
				w = 6.0 + (3.0 if phase >= 2 else 0.0)
		Move.THROW:
			if proj <= 1:
				w = 6.0 if dx >= 170.0 else 1.5
				if not level:
					w += 3.0
		Move.FAN:
			if proj <= 1 and dx >= 200.0:
				w = 5.0
		Move.CLIMB:
			w = 4.0 if dx >= 150.0 else 1.0
			if not level:
				w += 1.5
			if float(ctx.get("wall", 0.0)) > 850.0:
				w *= 0.2  # duvar çok uzakta: kaçarken zaman kaybeder
		Move.VOLLEY:
			w = 4.0 if dx >= 250.0 else 1.0
			if float(ctx.get("wall", 0.0)) > 850.0:
				w *= 0.2
		Move.MINIONS:
			if minions == 0 and hp <= 0.95:
				w = 5.0
		Move.SWARM:
			if minions == 0 and hp <= 0.8:
				w = 6.0
		Move.BLINK:
			w = 5.0 if dx >= 140.0 else 2.0
		Move.SLAM:
			if dx >= 120.0 and dx <= 520.0:
				w = 5.0
			else:
				w = 1.0
		Move.RAIN:
			w = 4.0
		Move.ORBIT:
			w = 4.0 if dx >= 120.0 else 2.0
		Move.CLOAK:
			if dx >= 220.0:
				w = 4.0
		Move.CLONE:
			if dx <= 520.0:
				w = 4.0
		Move.COUNTER:
			if near and proj == 0:
				w = 4.0
	if bool(ctx.get("force_melee", false)):
		if m == Move.KNIFE or m == Move.COMBO:
			w *= 3.0
		else:
			w *= 0.25
	if m == int(ctx.get("last", Move.NONE)):
		w *= 0.35
	return w


## Ağırlıklara göre bir hamle seçer. `lock`: hamle -> kalan kilit (sn); kilitli olanlar seçilmez. Hiçbiri uygun değilse NONE.
static func pick(moves: Array, ctx: Dictionary, lock: Dictionary, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	var ws: Array[float] = []
	for m: int in moves:
		var w := 0.0
		if float(lock.get(m, 0.0)) <= 0.0:
			w = weight(m, ctx)
		ws.append(w)
		total += w
	if total <= 0.0:
		return Move.NONE
	var r := rng.randf() * total
	for i in moves.size():
		r -= ws[i]
		if r <= 0.0 and ws[i] > 0.0:
			return int(moves[i])
	for i in range(moves.size() - 1, -1, -1):
		if ws[i] > 0.0:
			return int(moves[i])
	return Move.NONE


static func lockout(m: int) -> float:
	return float(LOCKOUT.get(m, 0.0))


static func move_name(m: int) -> String:
	return str(MOVE_NAMES.get(m, "?"))


# ---------------------------------------------------------------- Umbra'nın eşyaları

## Umbra'ya kalmış bir eşyanın Gölge'ye uygulanabilen stat modifier'ları ([[stat, ekleme, çarpım], ...]).
static func usable_mods(item: ItemData) -> Array:
	var out: Array = []
	if item == null or not item.umbra_allowed:
		return out
	for m in item.mods:
		var mod: Array = m
		if mod.size() >= 3 and str(mod[0]) in ITEM_STATS:
			out.append(mod)
	return out
