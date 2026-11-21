class_name EnemyRoster
extends RefCounted
## Düşman kadrosu: hangi kattan itibaren hangi "burç" düşmanları dalgalara karışır.
## Taurus ve Sagitta hep vardır; Scorpius kendi kuralıyla gelir (RunController.scorpius_in_wave); bu sınıf YENİ düşmanları ekler.
##
##   kat 4+   Aries (zırhlı koç) + Cancer (kalkanlı yengeç)
##   kat 7+   Gemini (ikizler)   + Leo (aslan, kükreme)
##   kat 10+  Libra (terazi)     + Aquarius (kova, su)
##
## Bir katta ilk kez açılan çift, o katın ilk dalgasında garanti çıkar (oyuncu yeni düşmanı hemen tanısın).

const ARIES := preload("res://actors/enemies/aries.tscn")
const CANCER := preload("res://actors/enemies/cancer.tscn")
const GEMINI := preload("res://actors/enemies/gemini.tscn")
const LEO := preload("res://actors/enemies/leo.tscn")
const LIBRA := preload("res://actors/enemies/libra.tscn")
const AQUARIUS := preload("res://actors/enemies/aquarius.tscn")
const SCORPIUS_PATH := "res://actors/enemies/scorpius.tscn"

## [açıldığı kat, [sahneler]]
const UNLOCKS := [
	[4, [ARIES, CANCER]],
	[7, [GEMINI, LEO]],
	[10, [LIBRA, AQUARIUS]],
]


## `floor_no`'da açık olan yeni düşman sahneleri.
static func pool(floor_no: int) -> Array:
	var out: Array = []
	for u: Array in UNLOCKS:
		if floor_no >= int(u[0]):
			out.append_array(u[1])
	return out


## `floor_no` tam bu katta açılan çift (yoksa boş).
static func newest(floor_no: int) -> Array:
	for u: Array in UNLOCKS:
		if floor_no == int(u[0]):
			return (u[1] as Array).duplicate()
	return []


## Bir dalgadaki yeni düşman sayısı: 4. katta 1, her 3 katta +1; dalganın en çok üçte biri.
static func count_in_wave(floor_no: int, enemy_count: int) -> int:
	if floor_no < int(UNLOCKS[0][0]) or enemy_count < 3:
		return 0
	return clampi(1 + (floor_no - int(UNLOCKS[0][0])) / 3, 1, enemy_count / 3)


## `wave` (sahne dizisi) içindeki Scorpius olmayan yuvaların bir kısmını yeni düşmanlarla değiştirir (yerinde).
## Gemini iki yuva tutar (ikiz çift). `first_wave`: katın ilk dalgası mı (yeni çift garanti çıkar).
static func apply(wave: Array, floor_no: int, rng: RandomNumberGenerator, first_wave: bool) -> void:
	var want := count_in_wave(floor_no, wave.size())
	var pl := pool(floor_no)
	if want <= 0 or pl.is_empty():
		return
	var slots: Array = []
	for i in wave.size():
		var sc := wave[i] as PackedScene
		if sc == null or sc.resource_path != SCORPIUS_PATH:
			slots.append(i)
	for i in range(slots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = slots[i]
		slots[i] = slots[j]
		slots[j] = tmp
	var fresh := newest(floor_no) if first_wave else []
	var placed := 0
	while placed < want and not slots.is_empty():
		var choose: Array = fresh if not fresh.is_empty() else pl
		var scene: PackedScene = choose[rng.randi_range(0, choose.size() - 1)]
		if scene == GEMINI and slots.size() < 2:
			scene = ARIES if floor_no >= 4 else scene
		if scene == GEMINI:
			wave[slots.pop_back()] = GEMINI
			wave[slots.pop_back()] = GEMINI
			placed += 2
		else:
			wave[slots.pop_back()] = scene
			placed += 1
		if not fresh.is_empty():
			fresh.erase(scene)
