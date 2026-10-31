class_name EnemyTuning
extends RefCounted
## Bir düşmana doğarken uygulanan ayar paketi: zorluk seviyesi (Difficulty) ile tur ilerlemesinin (EnemyScaling) birleşimi.
## Varsayılan değerler "etkisiz"dir: ayar verilmeyen düşman (ya da NORMAL seviyede 0. tur) eskisi gibi davranır.
## Düşmanlar kendi sayılarını burada tanımlı yardımcılarla ölçekler; her düşmanın kendi alt sınırları vardır
## (uyarı süresi insan tepkisinin altına inmez, bekleme sıfıra düşmez).

var level := Difficulty.DEFAULT
## Tur ilerlemesi (0 = ilk tur).
var progress := 0

# Güç
var hp := 1.0
var damage := 1.0
var speed := 1.0
var gold := 1.0
# Zamanlama
var cooldown := 1.0
var telegraph := 1.0
var recover := 1.0
var stun := 1.0
# Karar ("zekâ")
var red := 0.0
var reach := 1.0
var kite := 1.0
var patience := 0.0
var punish := 0.0
var lead := 0.0
var feint := 0.0


func scale_hp(base: int) -> int:
	return maxi(1, roundi(float(base) * hp))


## Hasar tam sayıdır (kalp): çarpan yuvarlanır, en az 1. 0 ve altı (hasarsız saldırı) olduğu gibi kalır.
func scale_damage(base: int) -> int:
	if base <= 0:
		return base
	return maxi(1, roundi(float(base) * damage))


## Düşen altın: 0 kalır, aksi halde en az 1.
func scale_gold(base: int) -> int:
	if base <= 0:
		return 0
	return maxi(1, roundi(float(base) * gold))


func wait(base: float) -> float:
	return base * cooldown


## Uyarı süresi: çarpanla kısalır ama `floor_time`'ın (ya da orijinalin, hangisi küçükse) altına inmez.
func warn(base: float, floor_time: float) -> float:
	return maxf(base * telegraph, minf(floor_time, base))


func open_time(base: float, floor_time: float) -> float:
	return maxf(base * recover, minf(floor_time, base))


func stun_time(base: float, floor_time: float) -> float:
	return maxf(base * stun, minf(floor_time, base))


func is_identity() -> bool:
	return is_equal_approx(hp, 1.0) and is_equal_approx(damage, 1.0) and is_equal_approx(speed, 1.0) \
		and is_equal_approx(gold, 1.0) and is_equal_approx(cooldown, 1.0) and is_equal_approx(telegraph, 1.0) \
		and is_equal_approx(recover, 1.0) and is_equal_approx(stun, 1.0) and is_zero_approx(red) \
		and is_equal_approx(reach, 1.0) and is_equal_approx(kite, 1.0) and is_zero_approx(patience) \
		and is_zero_approx(punish) and is_zero_approx(lead) and is_zero_approx(feint)


## Hata ayıklama / belge için tek satırlık özet.
func summary() -> String:
	return "%s tur %d: can x%.2f hasar x%.2f hız x%.2f altın x%.2f | bekleme x%.2f uyarı x%.2f açık x%.2f sersem x%.2f | kırmızı %+.2f menzil x%.2f kaçış x%.2f | sabır %.2f ceza %.2f önden %.2f sahte %+.2f" % [
		Difficulty.name_of(level), progress, hp, damage, speed, gold, cooldown, telegraph, recover, stun,
		red, reach, kite, patience, punish, lead, feint]
