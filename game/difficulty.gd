class_name Difficulty
extends RefCounted
## Zorluk seviyeleri: EASY / NORMAL / DIFFICULT / IMMORTAL.
##
## Her seviye bir PROFİL'dir: düşmanın gücünü (can, hasar, hız) ve "zekâsını" ayarlayan sayılar:
## ne kadar sık saldırır (cooldown), saldırısını ne kadar önceden belli eder (uyarı), saldırıdan sonra ne kadar açık kalır,
## oyuncudan ne zaman uzaklaşır (kaçış), parry'ye erken basanı bekletir mi, parry'yi ıskalayanı hemen cezalandırır mı,
## hareket eden oyuncuyu önden hedefler mi.
##
## NORMAL = oyunun asıl ayarı (çarpanlar 1, zekâ ekleri 0): tur 0'daki Normal düşman, ölçekleme olmayan düşmanla birebir aynıdır.
## Tur ilerledikçe düşmanlar ayrıca güçlenir: bkz. EnemyScaling (ilk turdaki Taurus ile 100000. turdaki Taurus aynı değildir).
##
## Anahtarlar (hepsi çarpan; "+" ile işaretliler toplanan değerdir):
##   hp, damage, speed, gold      güç: can, hasar, hız (yürüme/atılma/mermi), düşen altın
##   cooldown                     saldırılar arası bekleme (küçük = daha sık saldırır)
##   telegraph                    uyarı süresi (küçük = tepki süren azalır; her düşmanın insan tepkisi alt sınırı vardır)
##   recover, stun                saldırı sonrası açık kalma ve parry sersemletmesi süresi (küçük = daha az fırsat)
##   red+                         kırmızı (parry'lenemez) saldırı payına eklenen
##   reach                        saldırıya girişme mesafesi
##   kite                         geri çekilme/kaçış eşiği (büyük = sen yaklaşmadan uzaklaşır)
##   patience+, punish+, lead+    zekâ (0..1): erken parry'yi bekletme, iskalanan parry'yi cezalandırma, önden hedefleme
##   feint+                       Scorpius'un sahte saldırı şansına eklenen
##   growth, ai_half              tur ölçeklemesi: güç artışının hızı; zekânın yarıya varma süresi (tur)

enum Level { EASY, NORMAL, HARD, IMMORTAL }

const DEFAULT := Level.NORMAL
## Menüde görünen adlar.
const NAMES := ["EASY", "NORMAL", "DIFFICULT", "IMMORTAL"]
## Kayıt dosyasındaki anahtarlar (adlar değişse de kayıtlar bozulmasın).
const KEYS := ["easy", "normal", "difficult", "immortal"]
const BLURBS := [
	"Düşmanlar daha yavaş ve daha az canlıdır. Saldırılar uzun uyarır, çoğu parry'lenebilir. Öğrenmek için.",
	"Oyunun asıl ayarı.",
	"Düşmanlar daha çevik, daha çok kırmızı saldırı yapar. Erken parry'ye basanı bekletir, ıskalayanı hemen cezalandırır.",
	"Düşmanlar seni okur: hareketini önden hedefler, sen yaklaşmadan uzaklaşır, her açığına saldırır. Kolay bırakmaz.",
]

## Çarpanı büyüdükçe oyunu ZORLAŞTIRAN anahtarlar.
const HARDER_UP := ["hp", "damage", "speed", "gold", "red", "reach", "kite", "patience", "punish", "lead", "feint", "growth"]
## Çarpanı küçüldükçe oyunu zorlaştıran anahtarlar (bekleme, uyarı, açık kalma, sersemletme süreleri).
const HARDER_DOWN := ["cooldown", "telegraph", "recover", "stun", "ai_half"]

const PROFILES := [
	{ # EASY
		"hp": 0.75, "damage": 0.5, "speed": 0.9, "gold": 1.0,
		"cooldown": 1.35, "telegraph": 1.25, "recover": 1.25, "stun": 1.3,
		"red": -0.25, "reach": 0.9, "kite": 0.85,
		"patience": 0.0, "punish": 0.0, "lead": 0.0, "feint": -0.15,
		"growth": 0.75, "ai_half": 90.0,
	},
	{ # NORMAL
		"hp": 1.0, "damage": 1.0, "speed": 1.0, "gold": 1.0,
		"cooldown": 1.0, "telegraph": 1.0, "recover": 1.0, "stun": 1.0,
		"red": 0.0, "reach": 1.0, "kite": 1.0,
		"patience": 0.0, "punish": 0.0, "lead": 0.0, "feint": 0.0,
		"growth": 1.0, "ai_half": 60.0,
	},
	{ # DIFFICULT
		"hp": 1.35, "damage": 1.0, "speed": 1.1, "gold": 1.2,
		"cooldown": 0.8, "telegraph": 0.9, "recover": 0.85, "stun": 0.85,
		"red": 0.1, "reach": 1.1, "kite": 1.12,
		"patience": 0.35, "punish": 0.5, "lead": 0.5, "feint": 0.1,
		"growth": 1.2, "ai_half": 40.0,
	},
	{ # IMMORTAL
		"hp": 1.8, "damage": 1.25, "speed": 1.2, "gold": 1.5,
		"cooldown": 0.6, "telegraph": 0.8, "recover": 0.7, "stun": 0.7,
		"red": 0.2, "reach": 1.2, "kite": 1.25,
		"patience": 0.7, "punish": 1.0, "lead": 1.0, "feint": 0.2,
		"growth": 1.5, "ai_half": 25.0,
	},
]


static func count() -> int:
	return PROFILES.size()


## Geçersiz değeri en yakın geçerli seviyeye çeker (bozuk kayıt, eski sürüm).
static func clamp_level(level: int) -> int:
	return clampi(level, 0, PROFILES.size() - 1)


static func profile(level: int) -> Dictionary:
	return PROFILES[clamp_level(level)]


static func name_of(level: int) -> String:
	return NAMES[clamp_level(level)]


static func key_of(level: int) -> String:
	return KEYS[clamp_level(level)]


static func blurb_of(level: int) -> String:
	return BLURBS[clamp_level(level)]


## Kayıt anahtarından seviye ("immortal" -> IMMORTAL). Tanınmazsa `fallback`.
static func from_key(key: String, fallback: int = DEFAULT) -> int:
	var i := KEYS.find(key)
	return i if i >= 0 else fallback
