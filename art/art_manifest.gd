class_name ArtManifest
extends RefCounted
## Çizilecek HER ŞEYİN listesi (tek kaynak). Çizimler PNG olarak `assets/` altına konur; oyun dosyayı ADIYLA bulur
## (hangi klasörde durduğu önemli değil) ve kullanır. Dosya yoksa şimdiki yer tutucu görünmeye devam eder.
## Bu liste hem çizere verilen dokümanı (tools/export_art_list.tscn) hem de eksik/yanlış boyutlu dosya denetimini
## (tools/check_assets.tscn) besler. Yeni bir çizim istiyorsan buraya bir satır eklemen yeter.
##
## Satır alanları:
##   file     dosya adı, uzantısız ("sidera_walk" -> sidera_walk.png). Tüm listede benzersiz.
##   section  dokümandaki bölüm, group = bölüm içindeki tablo başlığı
##   owner    karakter satırlarında karakterin adı ("sidera"), anim = oyun içindeki animasyon adı ("run")
##   desc     ne zaman/nerede görünür
##   w, h     tek karenin boyutu (piksel). Şeritte kare sayısı = görüntü genişliği / w
##   frames   önerilen kare sayısı (metin: "4-6", "1" = durağan, "1-8" = isteğe bağlı hareketli)
##   loop     döngü mü, dur = tek seferlikte toplam süre, döngülüde bir tur süresi (sn)
##   anchor   hizalama (karakterlerde ayaklar = karenin alt ortası)
##   pack     çizim paketi (PACKS), core = o paketin olmazsa olmazı

const FEET := "ayaklar (karenin alt orta noktası)"
const CENTER := "merkez"
const GROUND := "alt orta (yere basar)"
const NONE := "—"
## Karakter karesi (Sidera, Taurus, Sagitta, Scorpius, Umbra): hepsi aynı tuvalde çizilir.
const CHAR_SIZE := Vector2i(96, 96)
const MERCHANT_SIZE := Vector2i(128, 128)

## Bölümler: dokümanda sırayla başlık olurlar.
const SECTIONS: Array[Dictionary] = [
	{"id": "sidera", "title": "Sidera (oyuncu)"},
	{"id": "dusman", "title": "Düşmanlar: Taurus, Sagitta, Scorpius"},
	{"id": "umbra", "title": "Umbra (gölge)"},
	{"id": "efekt", "title": "Saldırı ve efekt çizimleri"},
	{"id": "dunya", "title": "Dünya: arka planlar, zemin, platform, kapı"},
	{"id": "lobi", "title": "Lobi ve dükkân"},
	{"id": "sunak", "title": "Ödül sunağı (eşya seçme yeri)"},
	{"id": "esya", "title": "Eşya ikonları, paralar, yemekler"},
	{"id": "arayuz", "title": "Arayüz: ekran göstergeleri, envanter, dükkân"},
	{"id": "menu", "title": "Ana menü, kayıt ekranları, ölüm ve geçişler"},
]

## Çizim paketleri: çizere hangi sırayla verileceği. Önce 1. paket, oynanabilir çekirdek.
const PACKS := {
	1: "Paket 1: Oynanabilir çekirdek (Sidera, Taurus, Sagitta, temel efektler, para)",
	2: "Paket 2: Kat 1 ortamı ve ekran göstergeleri",
	3: "Paket 3: Scorpius",
	4: "Paket 4: Eşyalar, envanter ve duvar sekmesi",
	5: "Paket 5: Ana menü ve kayıt ekranları",
	6: "Paket 6: Lobi, dükkân ve ödül sunağı",
	7: "Paket 7: Kat 2-5 ortamları",
	8: "Paket 8: Umbra",
	9: "Paket 9: Ölüm ekranı ve geçişler",
}

## Temalar: her tema için aynı 8 dünya çizimi istenir (adın başına tema adı gelir: kat1_bg_far, lobi_floor ...).
## Sonsuz moddaki arena kat1...kat5 temalarını sırayla kullanır (10 dalgada bir değişir).
const THEMES: Array[Dictionary] = [
	{"id": "kat1", "label": "Kat 1", "pack": 2, "mood": "Giriş kulesi: koyu mor taş, altın ışık çizgileri (şimdiki ilk palet)."},
	{"id": "kat2", "label": "Kat 2", "pack": 7, "mood": "Soğuk su altı hissi: koyu turkuaz taş, turkuaz ışık."},
	{"id": "kat3", "label": "Kat 3", "pack": 7, "mood": "Kızgın, kor: koyu kırmızı taş, turuncu ışık."},
	{"id": "kat4", "label": "Kat 4", "pack": 7, "mood": "Gece gökyüzü: lacivert taş, mavi-menekşe ışık."},
	{"id": "kat5", "label": "Kat 5", "pack": 7, "mood": "Tutulma katı: simsiyah, beyaz-altın halka (son kat; Umbra'nın yeri)."},
	{"id": "lobi", "label": "Lobi", "pack": 6, "mood": "Güvenli oda: sıcak, loş, mum ışığı; her katın ilk odası (düşman yok)."},
]

static var _entries: Array[Dictionary] = []
static var _by_file: Dictionary = {}


static func entries() -> Array[Dictionary]:
	if _entries.is_empty():
		_build()
	return _entries


static func find(file: String) -> Dictionary:
	entries()
	return _by_file.get(file, {})


static func has_file(file: String) -> bool:
	entries()
	return _by_file.has(file)


## Bir bölümdeki tabloların başlıkları (sıralı, tekrarsız).
static func groups_of(section: String) -> Array[String]:
	var out: Array[String] = []
	for e in entries():
		if e["section"] == section and not (e["group"] in out):
			out.append(e["group"])
	return out


static func in_group(section: String, group: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in entries():
		if e["section"] == section and e["group"] == group:
			out.append(e)
	return out


## Bir karakterin (owner) oyun içi animasyon adı -> manifest satırı.
static func owner_anims(owner: String) -> Dictionary:
	var out := {}
	for e in entries():
		if e.get("owner", "") == owner and e.has("anim"):
			out[e["anim"]] = e
	return out


## Karakterin bir animasyonunun dosya adı. Satır yoksa "<owner>_<anim>".
static func file_for(owner: String, anim: String) -> String:
	var e: Dictionary = owner_anims(owner).get(anim, {})
	return String(e["file"]) if not e.is_empty() else "%s_%s" % [owner, anim]


static func count_in_pack(pack: int) -> int:
	var n := 0
	for e in entries():
		if int(e["pack"]) == pack:
			n += 1
	return n


# ---------------------------------------------------------------- veri

static func _build() -> void:
	_entries.clear()
	_by_file.clear()
	_sidera()
	_enemies()
	_umbra()
	_effects()
	_world()
	_lobby()
	_altar()
	_items()
	_hud()
	_inventory_ui()
	_shop_ui()
	_menus()


static func _make(section: String, group: String, file: String, desc: String, size: Vector2i, frames: String, loop: bool, dur: float, anchor: String, pack: int, core: bool) -> Dictionary:
	var e := {
		"file": file, "section": section, "group": group, "desc": desc, "w": size.x, "h": size.y,
		"frames": frames, "loop": loop, "dur": dur, "anchor": anchor, "pack": pack, "core": core,
	}
	_entries.append(e)
	_by_file[file] = e
	return e


## Tek satır ekler (karakter olmayanlar).
static func _add(section: String, group: String, file: String, desc: String, w: int, h: int, frames: String, loop: bool, dur: float, anchor: String, pack: int, core: bool = true) -> Dictionary:
	return _make(section, group, file, desc, Vector2i(w, h), frames, loop, dur, anchor, pack, core)


## Karakter animasyonları. Satır: [anim, dosya_eki, açıklama, kare, döngü, süre, core, paket].
static func _chars(section: String, group: String, owner: String, size: Vector2i, rows: Array) -> void:
	for r: Array in rows:
		var e := _make(section, group, "%s_%s" % [owner, r[1]], String(r[2]), size, String(r[3]), bool(r[4]), float(r[5]), FEET, int(r[7]), bool(r[6]))
		e["owner"] = owner
		e["anim"] = String(r[0])


static func _sidera() -> void:
	_chars("sidera", "Sidera: temel hareket ve dövüş", "sidera", CHAR_SIZE, [
		["idle", "idle", "Duruyor (nefes alıyor, pelerin/saç hafifçe oynar)", "4-6", true, 0.7, true, 1],
		["run", "walk", "Yürüyor / koşuyor (tek animasyon)", "6-8", true, 0.6, true, 1],
		["jump", "jump", "Havada yükseliyor", "2-3", false, 0.25, true, 1],
		["fall", "fall", "Havada düşüyor", "2", true, 0.2, true, 1],
		["dash", "dash", "Dash: kısa, hızlı atılış", "3-4", false, 0.16, true, 1],
		["attack1", "attack1", "1. kombo vuruşu: hazırlık, vuruş, toparlanma", "4-6", false, 0.28, true, 1],
		["attack2", "attack2", "2. kombo vuruşu: 1. ile ters yönde", "4-6", false, 0.28, true, 1],
		["attack3", "attack3", "3. ağır vuruş: daha büyük, daha uzun", "5-8", false, 0.45, true, 1],
		["parry", "parry", "Parry duruşu: kılıcı kaldırıyor (etkili pencere 0.12 sn)", "2-3", false, 0.12, true, 1],
		["parry_fail", "parry_fail", "Parry'yi kaçırınca toparlanma", "3", false, 0.35, true, 1],
		["hurt", "hurt", "Hasar yedi", "2", false, 0.22, true, 1],
		["death", "death", "Ölüm (son karede kalır)", "5-8", false, 0.8, true, 1],
		["double_jump", "double_jump", "Havada ikinci zıplama (takla ya da tur)", "4", false, 0.3, false, 1],
		["land", "land", "Sert inişte çömelme", "3", false, 0.15, false, 1],
	])
	_chars("sidera", "Sidera: eşyalarla ve yerlerle ilgili hareketler", "sidera", CHAR_SIZE, [
		["wall_slide", "wall_slide", "Duvara tutunmuş, aşağı kayıyor (Reçineli Eldivenler eşyası)", "3-4", true, 0.4, true, 4],
		["wall_jump", "wall_jump", "Duvardan itip sıçrıyor (Reçineli Eldivenler eşyası)", "3", false, 0.2, true, 4],
		["eat", "eat", "Yemek yiyor (envanter ekranındaki karakterde oynar)", "6", false, 0.6, false, 4],
		["interact", "interact", "Dükkânda ya da sunakta eşyaya uzanıyor", "4", false, 0.4, false, 6],
		["appear", "appear", "Kata ilk girişte beliriyor", "6", false, 0.6, false, 6],
		["ascend", "ascend", "Kat geçidinden yukarı çıkıyor", "6", false, 0.6, false, 6],
	])


static func _enemies() -> void:
	_chars("dusman", "Taurus (boğa goblin)", "taurus", CHAR_SIZE, [
		["idle", "idle", "Bekliyor", "4", true, 0.5, true, 1],
		["run", "walk", "Yürüyor / koşuyor", "6", true, 0.6, true, 1],
		["jump", "jump", "Platforma zıplıyor", "2", false, 0.3, true, 1],
		["fall", "fall", "Düşüyor", "2", true, 0.2, true, 1],
		["telegraph", "windup", "Atılma hazırlığı: geriye çömelir (0.55 sn). Üstüne altın ya da kırmızı uyarı biner", "4", false, 0.55, true, 1],
		["attack", "lunge", "Atılma: boynuzlarıyla ileri hamle", "3-4", false, 0.28, true, 1],
		["recover", "recover", "Atılma sonrası toparlanma, soluklanma (oyuncunun vurma fırsatı)", "3", false, 0.85, true, 1],
		["stun", "stunned", "Parry sonrası sersemleme (süre boyunca döner)", "2-4", true, 0.5, true, 1],
		["hurt", "hurt", "Vurulunca", "2", false, 0.2, true, 1],
		["death", "death", "Ölüm (bitince söner)", "5-7", false, 0.7, true, 1],
		["spawn", "spawn", "Işık sütunundan beliriş", "5", false, 0.4, false, 1],
	])
	_chars("dusman", "Sagitta (yılan okçu)", "sagitta", CHAR_SIZE, [
		["idle", "idle", "Bekliyor", "4", true, 0.5, true, 1],
		["run", "walk", "Mesafe ayarlıyor: yavaş ileri/geri adımlar", "6", true, 0.6, true, 1],
		["telegraph", "aim", "Nişan alıyor, ok hazırlığı (0.45 sn). Üstüne altın ya da kırmızı uyarı biner", "4", false, 0.45, true, 1],
		["attack", "shooting", "Ateş ediyor (ateş sonrası kısa toparlanmayı da içerir)", "3-4", false, 0.35, true, 1],
		["stun", "stunned", "Parry sonrası sersemleme (süre boyunca döner)", "2-4", true, 0.5, true, 1],
		["hurt", "hurt", "Vurulunca", "2", false, 0.2, true, 1],
		["death", "death", "Ölüm (bitince söner)", "5-7", false, 0.7, true, 1],
		["spawn", "spawn", "Işık sütunundan beliriş", "5", false, 0.4, false, 1],
	])
	_chars("dusman", "Scorpius (akrep, rapier)", "scorpius", CHAR_SIZE, [
		["idle", "idle", "Bekliyor", "4", true, 0.5, true, 3],
		["run", "walk", "Yürüyor, mesafeyi koruyor", "6", true, 0.6, true, 3],
		["jump", "jump", "Platforma zıplıyor", "2", false, 0.3, true, 3],
		["fall", "fall", "Düşüyor", "2", true, 0.2, true, 3],
		["telegraph", "windup", "Dürtüş hazırlığı: rapier geriye çekilir (kısa altın uyarı)", "3-4", false, 0.34, true, 3],
		["attack", "thrust", "Dürtüş: rapier öne uzanır (uzun çizgiyi efekt çizer, burada kol uzanışı yeter)", "3-4", false, 0.12, true, 3],
		["backflip", "backflip", "Fazla yaklaşınca geriye takla", "5-6", false, 0.42, true, 3],
		["retreat", "retreat", "Dürtüşten sonra geriye süzülüş", "3-4", false, 0.34, true, 3],
		["vanish", "vanish", "Sahte hamleye kanınca kaybolma", "2-3", false, 0.1, true, 3],
		["stab_telegraph", "stab_windup", "Rakibin arkasında kısa hazırlık (kırmızı uyarı)", "2-3", false, 0.2, true, 3],
		["stab", "stab", "Sırttan vuruş", "2-3", false, 0.1, true, 3],
		["stun", "stunned", "Gerçek dürtüş parry'lenince 1.5 sn sersemleme (döner)", "2-4", true, 0.5, true, 3],
		["hurt", "hurt", "Vurulunca", "2", false, 0.2, true, 3],
		["death", "death", "Ölüm (bitince söner)", "5-7", false, 0.7, true, 3],
		["spawn", "spawn", "Işık sütunundan beliriş", "5", false, 0.4, false, 3],
	])


## Umbra: Sidera ile aynı hareket seti (gölge hali: koyu, mor-siyah ton) + kendine özgü iki animasyon.
static func _umbra() -> void:
	var rows: Array = []
	for e in _entries:
		if e.get("owner", "") == "sidera" and bool(e["core"]) and int(e["pack"]) == 1:
			var suffix := String(e["file"]).trim_prefix("sidera_")
			rows.append([e["anim"], suffix, e["desc"], e["frames"], e["loop"], e["dur"], true, 8])
	_chars("umbra", "Umbra: Sidera ile aynı hareketler (gölge hali)", "umbra", CHAR_SIZE, rows)
	_chars("umbra", "Umbra: kendine özgü hareketler", "umbra", CHAR_SIZE, [
		["appear", "appear", "Pusuda beliriş: gölgeden çıkış", "6", false, 0.7, true, 8],
		["revive", "revive", "Çatlak El Aynası ile 2. evreye geçiş: tam canla dirilir", "8", false, 1.0, true, 8],
		["wall_slide", "wall_slide", "Duvara tutunmuş kayıyor (Umbra Reçineli Eldivenleri aldıysa)", "3-4", true, 0.4, false, 8],
		["wall_jump", "wall_jump", "Duvardan sıçrıyor (Umbra Reçineli Eldivenleri aldıysa)", "3", false, 0.2, false, 8],
		["double_jump", "double_jump", "Havada ikinci zıplama", "4", false, 0.3, false, 8],
	])


static func _effects() -> void:
	const S := "efekt"
	var g := "Dövüş efektleri"
	_add(S, g, "fx_slash1", "1. kılıç izi (iz SAĞA doğru uzanır, oyun yöne göre çevirir)", 128, 96, "4-5", false, 0.14, "sol orta (Sidera'nın göğsü)", 1)
	_add(S, g, "fx_slash2", "2. kılıç izi (1. ile ters yönlü yay)", 128, 96, "4-5", false, 0.14, "sol orta (Sidera'nın göğsü)", 1)
	_add(S, g, "fx_slash3", "3. ağır vuruşun izi (daha büyük)", 192, 128, "5-6", false, 0.2, "sol orta (Sidera'nın göğsü)", 1)
	_add(S, g, "fx_hit_spark", "Vuruş kıvılcımı (her isabette). Sağa doğru savrulur, oyun yöne göre çevirir", 64, 64, "5", false, 0.2, CENTER, 1)
	_add(S, g, "fx_parry_flash", "Başarılı parry patlaması (altın-beyaz)", 160, 160, "6", false, 0.3, "merkez (parry noktası)", 1)
	_add(S, g, "fx_parry_zone", "Parry bölgesi halkası (parry penceresi boyunca Sidera'nın etrafında). Oyun yarıçapa göre ölçekler", 128, 128, "3", true, 0.2, "merkez (Sidera)", 1, false)
	_add(S, g, "fx_enemy_death", "Düşman ölümü: toz / ruh patlaması", 128, 128, "7", false, 0.4, CENTER, 1, false)
	_add(S, g, "fx_stun_stars", "Sersemleyen düşmanın başında dönen yıldızlar: şimdi vur!", 64, 32, "6", true, 0.5, "alt orta (düşmanın başı)", 1, false)
	g = "Uyarı sembolleri ve mermiler"
	_add(S, g, "fx_tell_gold", "Altın uyarı sembolü: parry'lenebilir saldırı geliyor (düşmanın başının üstünde)", 48, 48, "4", true, 0.3, "merkez (başın üstü)", 1)
	_add(S, g, "fx_tell_red", "Kırmızı uyarı parıltısı: parry'lenemez, kaç! Düşmanın gövdesine biner", 96, 96, "4", true, 0.3, "merkez (düşmanın gövdesi)", 1)
	_add(S, g, "fx_projectile_red", "Kırmızı mermi (parry'lenemez). Sağa doğru uçar", 32, 32, "4", true, 0.25, CENTER, 1)
	_add(S, g, "fx_projectile_gold", "Altın mermi (parry'lenebilir). Sağa doğru uçar", 32, 32, "4", true, 0.25, CENTER, 1)
	_add(S, g, "fx_projectile_parried", "Parry'lenip geri dönen mermi (turkuaz-mavi)", 32, 32, "4", true, 0.25, CENTER, 1, false)
	_add(S, g, "fx_projectile_hit", "Mermi isabet edince / sönünce patlama", 64, 64, "5", false, 0.2, CENTER, 1, false)
	g = "Hareket ve toz"
	_add(S, g, "fx_dust_dash", "Dash tozu (ayak dibinde)", 64, 32, "4", false, 0.25, GROUND, 1, false)
	_add(S, g, "fx_dust_land", "İniş tozu", 96, 32, "5", false, 0.3, GROUND, 1, false)
	_add(S, g, "fx_dust_jump", "Zıplama tozu", 64, 32, "4", false, 0.25, GROUND, 1, false)
	_add(S, g, "fx_wall_dust", "Duvarda kayarken toz (döngü)", 48, 64, "4", true, 0.3, "üst orta (Sidera'nın eli duvarda)", 4)
	_add(S, g, "fx_wall_kick", "Duvardan sıçrama patlaması", 96, 96, "5", false, 0.25, CENTER, 4)
	_add(S, g, "fx_coin_sparkle", "Para toplanınca küçük parıltı", 48, 48, "5", false, 0.25, CENTER, 1, false)
	g = "Doğuş"
	_add(S, g, "fx_spawn_pillar", "Düşman doğmadan önce yerden yükselen ışık sütunu", 64, 192, "8", false, 0.55, GROUND, 2)
	_add(S, g, "fx_spawn_ring", "Doğuş işaretinin yerdeki halkası", 128, 48, "6", false, 0.55, GROUND, 2, false)
	g = "Scorpius efektleri"
	_add(S, g, "fx_thrust_trail", "Scorpius dürtüş izi: ince, uzun, parlak çizgi (SAĞA doğru uzar)", 192, 32, "4", false, 0.12, "sol orta (rapier ucunun çıktığı yer)", 3)
	_add(S, g, "fx_vanish_puff", "Scorpius kaybolma / beliriş dumanı (mor)", 96, 96, "6", false, 0.3, CENTER, 3)
	g = "Eşya ve durum efektleri"
	_add(S, g, "fx_poison_drip", "Zehirli düşmanın üstünde damlayan zehir (Engerek Dişi)", 64, 64, "6", true, 0.6, "merkez (düşmanın gövdesi)", 4, false)
	_add(S, g, "fx_heal", "İyileşme: yükselen artılar", 64, 96, "6", false, 0.5, "alt orta (Sidera)", 4, false)
	_add(S, g, "fx_immunity_gain", "Bağışıklık kalbi kazanma parıltısı (mavi)", 128, 128, "6", false, 0.4, "merkez (Sidera)", 4, false)
	_add(S, g, "fx_immunity_hit", "Bağışıklık kalbi hasarı emdi (mavi kalkan kırılması)", 128, 128, "6", false, 0.35, "merkez (Sidera)", 4, false)
	_add(S, g, "fx_mirror_crack", "Çatlak El Aynası kırılıyor ve seni kurtarıyor", 192, 192, "8", false, 0.5, "merkez (Sidera)", 4, false)
	_add(S, g, "fx_timestop_ring", "Zaman durmuşken Sidera'nın etrafındaki saat halkası (mavi-gri)", 128, 128, "8", true, 1.0, "merkez (Sidera)", 4, false)
	_add(S, g, "fx_timestop_burst", "Zamanın durduğu an: saat çarkı patlaması (mavi-gri)", 256, 256, "8", false, 0.4, "merkez (Sidera)", 4, false)
	g = "Lobi, dükkân ve sunak efektleri"
	_add(S, g, "fx_item_pickup", "Eşya alınınca ya da satın alınınca ışık patlaması", 160, 160, "8", false, 0.4, CENTER, 6, false)
	_add(S, g, "fx_umbra_grab", "Umbra'nın gölge eli sunakta seçilmeyen eşyayı alıyor", 256, 256, "10", false, 0.8, "alt orta (sunak)", 6, false)


static func _world() -> void:
	const S := "dunya"
	var g := "Tüm temalarda aynı olan çizimler (kapı)"
	var d := _add(S, g, "door_slab_locked", "Kapı levhası, kilitli: kırmızı ışık çizgisi. Dikeyde tekrarlanır", 36, 128, "1-4", true, 0.6, "üst orta", 2)
	d["tile"] = "y"
	d = _add(S, g, "door_slab_sealed", "Kapı levhası, arkanda kalan kapı: soluk. Dikeyde tekrarlanır", 36, 128, "1", false, 0.0, "üst orta", 2, false)
	d["tile"] = "y"
	d = _add(S, g, "door_frame_locked", "Kapı çerçevesi, kilitli: iki yan sütun (orta 36 piksel boş). Dikeyde tekrarlanır", 60, 128, "1-4", true, 0.6, "üst orta", 2)
	d["tile"] = "y"
	d = _add(S, g, "door_frame_open", "Kapı çerçevesi, açık: altın ışık. Dikeyde tekrarlanır", 60, 128, "1-4", true, 0.6, "üst orta", 2)
	d["tile"] = "y"
	d = _add(S, g, "door_frame_sealed", "Kapı çerçevesi, mühürlü: soluk. Dikeyde tekrarlanır", 60, 128, "1", false, 0.0, "üst orta", 2, false)
	d["tile"] = "y"
	_add(S, g, "door_arrows", "Açık kapının yanında sağa akan oklar: ilerle", 96, 40, "4", true, 0.5, "sol orta", 2, false)
	for t in THEMES:
		var id: String = t["id"]
		var gt := "%s: %s" % [t["label"], t["mood"]]
		var p: int = t["pack"]
		var far := _add(S, gt, id + "_bg_far", "En uzak katman: gökyüzü, uzak silüetler. Yer çizgisi görüntünün 640. pikselinde. Yatayda dikişsiz tekrarlanır", 1280, 900, "1-8", true, 2.0, "üst sol", p)
		far["tile"] = "x"
		var mid := _add(S, gt, id + "_bg_mid", "Orta katman: sütunlar, yapılar. Yer çizgisi 640. pikselde. Yatayda dikişsiz tekrarlanır", 1280, 900, "1-8", true, 2.0, "üst sol", p)
		mid["tile"] = "x"
		var near := _add(S, gt, id + "_bg_near", "Ön katman: karakterin ARKASINDA kalan yakın şeyler (sütun, asma, toz). Yatayda dikişsiz tekrarlanır", 1280, 900, "1-8", true, 2.0, "üst sol", p, false)
		near["tile"] = "x"
		var fl := _add(S, gt, id + "_floor", "Zemin dokusu. Üst kenar = yer yüzeyi. Yatayda dikişsiz tekrarlanır", 128, 260, "1-4", true, 1.0, "üst kenar = yer yüzeyi", p)
		fl["tile"] = "x"
		_add(S, gt, id + "_platform_left", "Tek yönlü platformun sol ucu (üst kenar = yüzey)", 24, 32, "1", false, 0.0, "üst sol", p)
		var pm := _add(S, gt, id + "_platform_mid", "Platformun orta parçası. Yatayda tekrarlanır", 32, 32, "1", false, 0.0, "üst sol", p)
		pm["tile"] = "x"
		_add(S, gt, id + "_platform_right", "Platformun sağ ucu", 24, 32, "1", false, 0.0, "üst sağ", p)
		var wl := _add(S, gt, id + "_wall", "Duvar: ilk odanın solunda ve sonsuz modun iki ucunda durur. Duvara tutunup sekilebilir. Dikeyde tekrarlanır", 80, 256, "1-4", true, 1.0, "üst sol", p, false)
		wl["tile"] = "y"


static func _lobby() -> void:
	const S := "lobi"
	_chars(S, "Tüccar (dükkâncı)", "merchant", MERCHANT_SIZE, [
		["idle", "idle", "Dükkâncı bekliyor", "6", true, 0.8, true, 6],
		["talk", "talk", "Konuşuyor (dükkân ekranı açıkken döner)", "6", true, 0.7, true, 6],
		["buy", "buy", "Satış yapıldı, memnun", "4", false, 0.5, true, 6],
		["deny", "deny", "Altının yetmedi, başını sallıyor", "4", false, 0.5, true, 6],
		["greet", "greet", "Sidera yaklaşınca selam veriyor", "5", false, 0.6, false, 6],
	])
	var g := "Lobi ve dükkân nesneleri"
	_add(S, g, "shop_counter", "Tezgâh (tüccarın önünde; mum ya da lamba hafifçe oynar)", 256, 128, "6", true, 0.9, GROUND, 6)
	_add(S, g, "shop_stand", "Satılan eşyanın durduğu stand, dolu hali (eşya ikonu üstünde süzülür)", 96, 128, "6", true, 0.9, GROUND, 6)
	_add(S, g, "shop_stand_empty", "Satılınca boş kalan stand", 96, 128, "1-4", true, 0.6, GROUND, 6)
	_add(S, g, "shop_sign", "Dükkân tabelası (hafifçe sallanır)", 160, 80, "4", true, 1.0, "üst orta", 6, false)
	_add(S, g, "price_tag", "Fiyat etiketi zemini (rakamı oyun yazar)", 80, 32, "1", false, 0.0, CENTER, 6)
	_add(S, g, "exit_closed", "Kat geçidi, kapalı (merdiven / kapak / geçit; teması sen belirle). Sonsuz modda dalga geçidi olarak da kullanılır", 128, 192, "4", true, 0.8, GROUND, 6)
	_add(S, g, "exit_opening", "Kat geçidi açılıyor", 128, 192, "8", false, 0.7, GROUND, 6)
	_add(S, g, "exit_open", "Kat geçidi açık, bekliyor", 128, 192, "6", true, 0.8, GROUND, 6)


static func _altar() -> void:
	const S := "sunak"
	var g := "Ödül sunağı"
	_add(S, g, "altar_rise", "Oda temizlenince sunak yerden yükselir", 128, 128, "8", false, 0.7, GROUND, 6)
	_add(S, g, "altar_idle", "Sunak bekliyor (üstünde eşya süzülür, hafif parıltı)", 128, 128, "6", true, 0.9, GROUND, 6)
	_add(S, g, "altar_take", "Seçilen sunak: ışık patlar", 128, 128, "6", false, 0.5, GROUND, 6)
	_add(S, g, "altar_dim", "Seçilmeyen sunak: kararır, eşyayı Umbra alır", 128, 128, "6", false, 0.8, GROUND, 6)


static func _items() -> void:
	const S := "esya"
	_add(S, "Paralar", "coin_small", "Küçük para (1 altın). Dönüyor", 16, 16, "6", true, 0.5, CENTER, 1)
	_add(S, "Paralar", "coin_antique", "Antika para (3 altın). Daha büyük ve bronz, dönüyor", 20, 20, "6", true, 0.5, CENTER, 1)
	for it in ItemDB.all():
		var kind := "yemek" if it.is_food() else it.slot_name().to_lower()
		var group := "Yemekler" if it.is_food() else "Takılan eşyalar"
		var e := _add(S, group, "item_" + it.id, "%s (%s)" % [it.display_name, kind], 64, 64, "1-8", true, 1.0, CENTER, 4)
		e["item_id"] = it.id


static func _hud() -> void:
	const S := "arayuz"
	var g := "Oyun ekranı göstergeleri (HUD)"
	_add(S, g, "ui_heart_full", "Dolu kalp (hafifçe atabilir)", 32, 32, "1-4", true, 0.8, NONE, 2)
	_add(S, g, "ui_heart_empty", "Boş kalp", 32, 32, "1", false, 0.0, NONE, 2)
	_add(S, g, "ui_heart_immunity", "Bağışıklık kalbi (mavi)", 32, 32, "1-4", true, 0.8, NONE, 2)
	_add(S, g, "ui_heart_break", "Kalp kırılıyor (can kaybı)", 48, 48, "6", false, 0.3, NONE, 2, false)
	_add(S, g, "ui_heart_gain", "Kalp doluyor (can kazanımı)", 48, 48, "6", false, 0.3, NONE, 2, false)
	_add(S, g, "ui_dash_full", "Dash şarjı, dolu", 48, 20, "1", false, 0.0, NONE, 2)
	_add(S, g, "ui_dash_empty", "Dash şarjı, boş", 48, 20, "1", false, 0.0, NONE, 2)
	_add(S, g, "ui_dash_charging", "Dash şarjı doluyor", 48, 20, "6", true, 0.6, NONE, 2, false)
	_add(S, g, "ui_coin_icon", "Altın sayacının yanındaki para simgesi", 28, 28, "1-6", true, 0.5, NONE, 2)
	_add(S, g, "ui_rhythm_bg", "Ritim çubuğunun çerçevesi (4 kademeli çubuk bunun içinde durur)", 240, 32, "1", false, 0.0, NONE, 2, false)
	_add(S, g, "ui_rhythm_fill_1", "Ritim dolgusu: SOĞUK kademesi (52x12'lik parça, yan yana dizilir)", 52, 12, "1", false, 0.0, NONE, 2, false)
	_add(S, g, "ui_rhythm_fill_2", "Ritim dolgusu: ISINMIŞ kademesi", 52, 12, "1", false, 0.0, NONE, 2, false)
	_add(S, g, "ui_rhythm_fill_3", "Ritim dolgusu: ATEŞLİ kademesi (parlayabilir)", 52, 12, "1-4", true, 0.4, NONE, 2, false)
	_add(S, g, "ui_rhythm_fill_4", "Ritim dolgusu: COŞKULU kademesi (parlayabilir)", 52, 12, "1-4", true, 0.3, NONE, 2, false)
	_add(S, g, "ui_timestop_bar_bg", "Zaman durdu çubuğunun çerçevesi", 280, 16, "1", false, 0.0, NONE, 4, false)
	_add(S, g, "ui_timestop_bar_fill", "Zaman durdu çubuğunun dolgusu (mavi-gri)", 272, 8, "1", false, 0.0, NONE, 4, false)
	_add(S, g, "ui_go_arrow", "Oda temizlenince sağ kenarda İLERLE oku (sağa akar)", 64, 64, "4", true, 0.5, NONE, 2, false)
	_add(S, g, "ui_announce_band", "Duyuru yazısının (ODA 3, DALGA 2, YENİ DÜŞMAN...) arkasındaki bant", 560, 56, "1", false, 0.0, NONE, 2, false)
	_add(S, g, "ui_room_banner", "ODA / KAT / DALGA yazısının çerçevesi (sağ üst)", 240, 72, "1", false, 0.0, NONE, 2, false)


static func _inventory_ui() -> void:
	const S := "arayuz"
	var g := "Envanter ekranı (I / Tab)"
	_add(S, g, "ui_inv_panel", "Pencere çerçevesi (9 dilim: köşeler 24 pikselden büyük olmasın, ortası boş/doku)", 96, 96, "1", false, 0.0, NONE, 4).merge({"nine": 24})
	_add(S, g, "ui_detail_panel", "Eşya ayrıntı paneli çerçevesi (9 dilim)", 96, 96, "1", false, 0.0, NONE, 4).merge({"nine": 24})
	_add(S, g, "ui_inv_title", "ENVANTER başlık yazısı (isteğe bağlı; yoksa yazı tipi kullanılır)", 320, 64, "1", false, 0.0, NONE, 4, false)
	_add(S, g, "ui_inv_cell", "Boş eşya kutusu", 64, 64, "1", false, 0.0, NONE, 4)
	_add(S, g, "ui_inv_cursor", "Seçim imleci (kutunun köşelerini saran, hafifçe atan çerçeve)", 76, 76, "4", true, 0.6, NONE, 4)
	_add(S, g, "ui_slot_head", "Boş KAFA slotu silüeti (soluk)", 48, 48, "1", false, 0.0, NONE, 4)
	_add(S, g, "ui_slot_charm", "Boş CHARM slotu silüeti", 48, 48, "1", false, 0.0, NONE, 4)
	_add(S, g, "ui_slot_armor", "Boş ZIRH slotu silüeti", 48, 48, "1", false, 0.0, NONE, 4)
	_add(S, g, "ui_slot_wrist", "Boş BİLEK slotu silüeti", 48, 48, "1", false, 0.0, NONE, 4)
	_add(S, g, "ui_slot_pocket", "Boş CEP slotu silüeti", 48, 48, "1", false, 0.0, NONE, 4)
	_add(S, g, "ui_slot_feet", "Boş AYAK slotu silüeti", 48, 48, "1", false, 0.0, NONE, 4)
	_add(S, g, "ui_rarity_common", "YAYGIN eşya çerçevesi (kutunun üstüne biner)", 64, 64, "1", false, 0.0, NONE, 4)
	_add(S, g, "ui_rarity_rare", "NADİR eşya çerçevesi (altın)", 64, 64, "1-4", true, 0.8, NONE, 4)
	_add(S, g, "ui_rarity_epic", "EFSANEVİ eşya çerçevesi (mor, parlayabilir)", 64, 64, "1-6", true, 0.8, NONE, 4)
	_add(S, g, "ui_rarity_cursed", "LANETLİ eşya çerçevesi (kırmızı, parlayabilir)", 64, 64, "1-6", true, 0.8, NONE, 4, false)
	_add(S, g, "ui_inv_doll_bg", "Karakterin arkasındaki aura / sahne (hareketli olabilir)", 320, 320, "1-8", true, 1.2, NONE, 4, false)


static func _shop_ui() -> void:
	const S := "arayuz"
	var g := "Dükkân ve ödül ekranı"
	_add(S, g, "ui_shop_panel", "Dükkân penceresi çerçevesi (9 dilim)", 96, 96, "1", false, 0.0, NONE, 6).merge({"nine": 24})
	_add(S, g, "ui_shop_title", "DÜKKÂN başlık yazısı (isteğe bağlı)", 320, 64, "1", false, 0.0, NONE, 6, false)
	_add(S, g, "ui_shop_card", "Satılan eşyanın kartı (ikon, ad ve fiyat üstüne yazılır)", 200, 260, "1", false, 0.0, NONE, 6)
	_add(S, g, "ui_shop_card_focus", "Seçili kart (parlıyor)", 216, 276, "1-4", true, 0.6, NONE, 6)
	_add(S, g, "ui_sold_stamp", "SATILDI damgası", 96, 40, "1", false, 0.0, NONE, 6)
	_add(S, g, "ui_reward_title", "BİRİNİ SEÇ başlık yazısı (isteğe bağlı)", 480, 72, "1", false, 0.0, NONE, 6, false)
	_add(S, g, "ui_reward_card", "Ödül kartı (eşya ikonu, ad, açıklama üstüne yazılır)", 260, 380, "1", false, 0.0, NONE, 6)
	_add(S, g, "ui_reward_card_focus", "Seçili ödül kartı (parlıyor)", 276, 396, "1-4", true, 0.6, NONE, 6)
	_add(S, g, "ui_reward_shadow_box", "GÖLGE ALIRSA kutusunun zemini (9 dilim; karanlık / mor tonlu)", 96, 96, "1", false, 0.0, NONE, 6).merge({"nine": 24})
	_add(S, g, "ui_umbra_icon", "Umbra'yı simgeleyen küçük ikon (gölge alırsa satırında)", 48, 48, "1-4", true, 0.8, NONE, 6, false)


static func _menus() -> void:
	const S := "menu"
	var g := "Ana menü"
	_add(S, g, "ui_logo", "Eclipse of Sidera logosu (hareketli olabilir)", 640, 240, "1-8", true, 1.2, NONE, 5)
	_add(S, g, "ui_menu_bg_far", "Ana menü arka planı, uzak katman (hareketli olabilir)", 1280, 720, "1-8", true, 2.0, NONE, 5)
	_add(S, g, "ui_menu_bg_mid", "Ana menü arka planı, orta katman", 1280, 720, "1-8", true, 2.0, NONE, 5, false)
	_add(S, g, "ui_menu_bg_near", "Ana menü arka planı, ön katman", 1280, 720, "1-8", true, 2.0, NONE, 5, false)
	_add(S, g, "ui_menu_button_normal", "Menü düğmesi, normal (yazıyı oyun yazar)", 320, 64, "1", false, 0.0, NONE, 5)
	_add(S, g, "ui_menu_button_focus", "Menü düğmesi, seçili", 320, 64, "1-4", true, 0.6, NONE, 5)
	_add(S, g, "ui_menu_button_pressed", "Menü düğmesi, basılı", 320, 64, "1", false, 0.0, NONE, 5, false)
	_add(S, g, "ui_arrow_left", "Seçim oku, sol (zorluk/mod seçerken)", 32, 32, "1-4", true, 0.5, NONE, 5, false)
	_add(S, g, "ui_arrow_right", "Seçim oku, sağ", 32, 32, "1-4", true, 0.5, NONE, 5, false)
	_add(S, g, "ui_credits_bg", "Krediler arka planı (hareketli olabilir)", 1280, 720, "1-8", true, 3.0, NONE, 5, false)
	_add(S, g, "ui_pause_panel", "Duraklatma menüsü çerçevesi (9 dilim)", 96, 96, "1", false, 0.0, NONE, 5, false).merge({"nine": 24})
	_add(S, g, "ui_confirm_panel", "Onay penceresi çerçevesi, örn. kaydı silmek (9 dilim)", 96, 96, "1", false, 0.0, NONE, 5, false).merge({"nine": 24})
	g = "Kayıt ekranı (3 slot) ve yeni oyun"
	_add(S, g, "ui_slot_card", "Kayıt slotu kartı: dolu ve boş slotlar bunu kullanır (9 dilim, yazıyı oyun yazar)", 480, 140, "1", false, 0.0, NONE, 5).merge({"nine": 24})
	_add(S, g, "ui_slot_card_focus", "Seçili slot kartı (parlıyor)", 496, 156, "1-4", true, 0.6, NONE, 5)
	_add(S, g, "ui_slot_new_icon", "Boş slotta YENİ OYUN artı simgesi", 64, 64, "1-4", true, 0.8, NONE, 5, false)
	_add(S, g, "ui_slot_delete_icon", "Slotu silme simgesi (çöp / mühür)", 48, 48, "1", false, 0.0, NONE, 5, false)
	_add(S, g, "ui_text_field", "İsim yazma kutusu (9 dilim)", 360, 56, "1", false, 0.0, NONE, 5, false).merge({"nine": 16})
	_add(S, g, "ui_text_cursor", "Yazı imleci (yanıp söner)", 8, 40, "2", true, 0.8, NONE, 5, false)
	_add(S, g, "ui_diff_easy", "KOLAY zorluk amblemi (hareketli olabilir)", 96, 96, "1-6", true, 1.0, NONE, 5)
	_add(S, g, "ui_diff_normal", "NORMAL zorluk amblemi", 96, 96, "1-6", true, 1.0, NONE, 5)
	_add(S, g, "ui_diff_hard", "ZOR zorluk amblemi", 96, 96, "1-6", true, 1.0, NONE, 5)
	_add(S, g, "ui_diff_immortal", "ÖLÜMSÜZ zorluk amblemi (en zoru)", 96, 96, "1-6", true, 1.0, NONE, 5)
	_add(S, g, "ui_mode_normal", "NORMAL MOD (katlar) amblemi", 128, 128, "1-6", true, 1.0, NONE, 5)
	_add(S, g, "ui_mode_endless", "SONSUZ MOD (dalgalar) amblemi", 128, 128, "1-6", true, 1.0, NONE, 5)
	g = "Ölüm ekranı ve geçişler"
	_add(S, g, "ui_death_overlay", "Ölünce ekranı kaplayan karartma / kenar efekti", 1280, 720, "1-8", true, 1.5, NONE, 9, false)
	_add(S, g, "ui_death_title", "ÖLDÜN başlık grafiği (isteğe bağlı; yoksa yazı tipi kullanılır)", 640, 160, "1-8", false, 0.8, NONE, 9, false)
	_add(S, g, "ui_summary_panel", "Ölüm özeti paneli (9 dilim)", 96, 96, "1", false, 0.0, NONE, 9, false).merge({"nine": 24})
	_add(S, g, "ui_floor_title_card", "Yeni kata girerken KAT n başlık kartı zemini", 640, 160, "1-8", false, 1.2, NONE, 9, false)
	_add(S, g, "ui_transition_wipe", "Kat geçişi perdesi (ekranı kaplar, sonra açılır)", 1280, 720, "8-12", false, 0.8, NONE, 9, false)
	_add(S, g, "ui_icon", "Oyun ikonu (uygulama simgesi)", 256, 256, "1", false, 0.0, NONE, 9)
