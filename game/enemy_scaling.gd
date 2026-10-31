class_name EnemyScaling
extends RefCounted
## Tur ölçeklemesi: aynı düşman, tur ilerledikçe güçlenir ve akıllanır (1. turdaki Taurus ile 100000. turdaki Taurus aynı değildir).
##
## İLERLEME `n`: Normal modda şimdiye kadar girilen oda sayısı, Sınırsız modda dalga numarası - 1 (0 = ilk tur).
## Zorluk seviyesi (Difficulty) başlangıç ayarını, tur ilerlemesi bunun üstüne bindirilen büyümeyi verir.
##
## İki türlü büyüme vardır:
##
##  1) SINIRSIZ ama yavaş: can, hasar, altın. Çok büyük turlarda da fark vardır (n'ye zorluğun "growth" çarpanı uygulanır).
##        can    = 1 + 0.08 · n^0.9
##        hasar  = 1 + 0.25 · log2(1 + n / 25)
##        altın  = 1 + 0.03 · n^0.8
##     n = 0: 1 / 1 / 1;  n = 25: 2.5 / 1.25 / 1.4;  n = 100: 6.0 / 1.58 / 2.2;  n = 100000: 2530 / 4.0 / 301
##
##  2) DOYUMLU: hız, bekleme, uyarı, açık kalma, sersemletme, kırmızı saldırı payı, zekâ. Bir sınıra yaklaşır ama onu geçmez,
##     çünkü insan tepkisi sınırlıdır (uyarı süresi sıfıra inemez):
##        p     = 1 - 0.5^(n / ai_half)          (0'dan 1'e; ai_half turda yarıya varır)
##        değer = başlangıç + (sınır - başlangıç) · p
##     Immortal'da ai_half 25, Easy'de 90: Immortal düşman çok daha çabuk "olgunlaşır".

## Sayıların taşmasını ve NaN üretmesini önleyen üst sınır.
const MAX_PROGRESS := 1000000000

# Sınırsız büyüme katsayıları
const HP_COEF := 0.08
const HP_POWER := 0.9
const DAMAGE_COEF := 0.25
const DAMAGE_SPAN := 25.0
const GOLD_COEF := 0.03
const GOLD_POWER := 0.8

# Doygunluk sınırları (p = 1): çarpanlar profille ÇARPILIR, "ADD" olanlar profille TOPLANIR.
const LIMIT_SPEED := 1.25
const LIMIT_COOLDOWN := 0.55
const LIMIT_TELEGRAPH := 0.8
const LIMIT_RECOVER := 0.65
const LIMIT_STUN := 0.75
const LIMIT_REACH := 1.15
const LIMIT_KITE := 1.15
const ADD_RED := 0.2
const ADD_BRAIN := 0.3
const ADD_FEINT := 0.15

# Hiçbir zorluk/tur bileşiminin inemeyeceği alt sınırlar (oyun haksız hale gelmesin)
const MIN_COOLDOWN := 0.25
const MIN_RECOVER := 0.4
const MIN_STUN := 0.4
const MAX_RED_SHARE := 0.95


static func clamp_progress(n: int) -> int:
	return clampi(n, 0, MAX_PROGRESS)


## Doygunluk ilerlemesi (0..1).
static func ai_progress(n: int, half: float) -> float:
	return 1.0 - pow(0.5, float(clamp_progress(n)) / maxf(half, 1.0))


static func hp_scale(n: int, growth: float = 1.0) -> float:
	return 1.0 + HP_COEF * pow(float(clamp_progress(n)) * growth, HP_POWER)


static func damage_scale(n: int, growth: float = 1.0) -> float:
	return 1.0 + DAMAGE_COEF * log(1.0 + float(clamp_progress(n)) * growth / DAMAGE_SPAN) / log(2.0)


static func gold_scale(n: int, growth: float = 1.0) -> float:
	return 1.0 + GOLD_COEF * pow(float(clamp_progress(n)) * growth, GOLD_POWER)


## Zorluk seviyesi + tur ilerlemesinden düşman ayar paketi.
static func tuning(level: int, n: int) -> EnemyTuning:
	var prof := Difficulty.profile(level)
	var growth: float = prof["growth"]
	var p := ai_progress(n, prof["ai_half"])
	var t := EnemyTuning.new()
	t.level = Difficulty.clamp_level(level)
	t.progress = clamp_progress(n)
	t.hp = float(prof["hp"]) * hp_scale(n, growth)
	t.damage = float(prof["damage"]) * damage_scale(n, growth)
	t.gold = float(prof["gold"]) * gold_scale(n, growth)
	t.speed = float(prof["speed"]) * lerpf(1.0, LIMIT_SPEED, p)
	t.cooldown = maxf(float(prof["cooldown"]) * lerpf(1.0, LIMIT_COOLDOWN, p), MIN_COOLDOWN)
	t.telegraph = float(prof["telegraph"]) * lerpf(1.0, LIMIT_TELEGRAPH, p)
	t.recover = maxf(float(prof["recover"]) * lerpf(1.0, LIMIT_RECOVER, p), MIN_RECOVER)
	t.stun = maxf(float(prof["stun"]) * lerpf(1.0, LIMIT_STUN, p), MIN_STUN)
	t.red = minf(float(prof["red"]) + ADD_RED * p, MAX_RED_SHARE)
	t.reach = float(prof["reach"]) * lerpf(1.0, LIMIT_REACH, p)
	t.kite = float(prof["kite"]) * lerpf(1.0, LIMIT_KITE, p)
	t.patience = clampf(float(prof["patience"]) + ADD_BRAIN * p, 0.0, 1.0)
	t.punish = clampf(float(prof["punish"]) + ADD_BRAIN * p, 0.0, 1.0)
	t.lead = clampf(float(prof["lead"]) + ADD_BRAIN * p, 0.0, 1.0)
	t.feint = float(prof["feint"]) + ADD_FEINT * p
	return t
