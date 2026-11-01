class_name SaveSlot
extends RefCounted
## Bir kayıt slotu: oyuncunun adı, zorluk, tarihler, rekorlar ve her kipte yarım kalmış koşu.
##
## Roguelite mantığı: slot bir PROFİLdir. Rekorlar kalır, ölünce koşu silinir. Koşu her oda/dalga başında kendiliğinden
## kaydedilir; "devam"da o odanın başından (aynı tohum, aynı eşyalar, aynı can) sürer.
## Dosyaya JSON olarak yazılır (SaveStore); bu sınıf yalnızca veriyi ve doğrulamayı bilir.

const VERSION := 1
const NAME_MAX := 12
const DEFAULT_NAME := "SIDERA"
## İsimde harf (Türkçe dahil), rakam ve bunlar kullanılabilir (oyun yazı tipinin çizebildikleri).
const NAME_PUNCT := "-_.'"
const TURKISH_LETTERS := "çğıöşüÇĞİÖŞÜ"

var index := 0
var name := DEFAULT_NAME
var difficulty: int = Difficulty.DEFAULT
## Unix saniyesi (UTC).
var created := 0
var last_played := 0
var playtime := 0.0
var records: Dictionary = default_records()
## Kip anahtarı ("normal"/"endless") -> yarım kalmış koşunun anlık görüntüsü (RunSnapshot).
var runs: Dictionary = {}
## Ana dosya bozuktu, yedekten okundu (menü bir uyarı gösterebilir).
var recovered := false


static func default_records() -> Dictionary:
	return {"runs": 0, "deaths": 0, "kills": 0, "best_floor": 0, "best_room": 0, "best_wave": 0, "best_combo": 0}


static func now() -> int:
	return int(Time.get_unix_time_from_system())


## Yeni oyun: `raw_name` temizlenir, zorluk geçerli aralığa çekilir.
static func create(slot_index: int, raw_name: String, level: int) -> SaveSlot:
	var s := SaveSlot.new()
	s.index = slot_index
	s.name = clean_name(raw_name)
	s.difficulty = Difficulty.clamp_level(level)
	s.created = now()
	s.last_played = s.created
	return s


# ---------------------------------------------------------------- isim

## Yazı tipinin çizebildiği karakterler: A-Z, a-z, 0-9, Türkçe harfler, - _ . ' ve boşluk.
static func name_char_ok(ch: String) -> bool:
	if ch.length() != 1:
		return false
	var c := ch.unicode_at(0)
	if (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122):
		return true
	return TURKISH_LETTERS.contains(ch) or NAME_PUNCT.contains(ch)


## Dışarıdan gelen ismi temizler: geçersiz karakterler atılır, boşluklar sadeleşir, en çok NAME_MAX karakter.
## Boş kalırsa varsayılan isim.
static func clean_name(raw: String) -> String:
	var out := ""
	var after_space := true  # baştaki boşlukları at
	for i in raw.length():
		var ch := raw.substr(i, 1)
		if ch == " " or ch == "\t":
			if not after_space:
				out += " "
			after_space = true
		elif name_char_ok(ch):
			out += ch
			after_space = false
		if out.length() >= NAME_MAX:
			break
	out = out.strip_edges()
	return out if out != "" else DEFAULT_NAME


# ---------------------------------------------------------------- koşular

func has_run(mode: int) -> bool:
	return runs.has(GameMode.key_of(mode))


## Kaydedilmiş koşunun KOPYASI (yoksa boş sözlük).
func run_of(mode: int) -> Dictionary:
	var r: Variant = runs.get(GameMode.key_of(mode))
	return (r as Dictionary).duplicate(true) if r is Dictionary else {}


func set_run(mode: int, snapshot: Dictionary) -> void:
	runs[GameMode.key_of(mode)] = snapshot.duplicate(true)


func clear_run(mode: int) -> void:
	runs.erase(GameMode.key_of(mode))


## Bir koşu bitti (öldün ya da bitirdin): rekorlar güncellenir, yarım koşu silinir.
## `stats`: kills, best_combo, floor, room (kat içi 0'dan), wave.
func record_run(mode: int, stats: Dictionary, died: bool = true) -> void:
	records["runs"] = int(records["runs"]) + 1
	if died:
		records["deaths"] = int(records["deaths"]) + 1
	records["kills"] = int(records["kills"]) + maxi(_int(stats.get("kills", 0)), 0)
	records["best_combo"] = maxi(int(records["best_combo"]), _int(stats.get("best_combo", 0)))
	if mode == GameMode.Kind.ENDLESS:
		records["best_wave"] = maxi(int(records["best_wave"]), _int(stats.get("wave", 0)))
	else:
		var f := maxi(_int(stats.get("floor", 1)), 1)
		var r := maxi(_int(stats.get("room", 0)), 0) + 1
		var bf := int(records["best_floor"])
		if f > bf or (f == bf and r > int(records["best_room"])):
			records["best_floor"] = f
			records["best_room"] = r
	clear_run(mode)


func touch() -> void:
	last_played = now()


# ---------------------------------------------------------------- görünüm metinleri

## "Kaldığımız yer": yarım koşu yoksa boş.
func progress_text(mode: int) -> String:
	if not has_run(mode):
		return ""
	var r: Dictionary = runs[GameMode.key_of(mode)]
	if mode == GameMode.Kind.ENDLESS:
		return "DALGA %d" % maxi(_int(r.get("wave", 1)), 1)
	return "KAT %d  ODA %d" % [maxi(_int(r.get("floor", 1)), 1), maxi(_int(r.get("room", 0)) + 1, 1)]


## Rekor satırı: henüz yoksa boş.
func best_text(mode: int) -> String:
	if mode == GameMode.Kind.ENDLESS:
		var w := int(records["best_wave"])
		return "" if w <= 0 else "EN İYİ DALGA %d" % w
	var f := int(records["best_floor"])
	return "" if f <= 0 else "EN İYİ KAT %d  ODA %d" % [f, int(records["best_room"])]


static func format_playtime(seconds: float) -> String:
	var t := int(maxf(seconds, 0.0))
	var h := t / 3600
	var m := (t % 3600) / 60
	var s := t % 60
	return "%d:%02d:%02d" % [h, m, s] if h > 0 else "%d:%02d" % [m, s]


## Yerel saatle gg.aa.yyyy; tarih yoksa "-".
static func format_date(unix: int) -> String:
	if unix <= 0:
		return "-"
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var dt := Time.get_datetime_dict_from_unix_time(unix + bias)
	return "%02d.%02d.%04d" % [int(dt["day"]), int(dt["month"]), int(dt["year"])]


# ---------------------------------------------------------------- dosya biçimi

func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"name": name,
		"difficulty": Difficulty.key_of(difficulty),
		"created": created,
		"last_played": last_played,
		"playtime": snappedf(playtime, 0.1),
		"records": records.duplicate(),
		"runs": runs.duplicate(true),
	}


## Dosyadan okunan veriyi doğrular (bozuk/eksik alanlar güvenli değerlere çekilir). Okunamazsa null.
static func from_dict(data: Variant, slot_index: int) -> SaveSlot:
	if not (data is Dictionary):
		return null
	var d: Dictionary = data
	if _int(d.get("version", VERSION), VERSION) > VERSION:
		return null  # gelecekteki sürümün dosyası: bu oyun anlayamaz
	var s := SaveSlot.new()
	s.index = slot_index
	s.name = clean_name(str(d.get("name", DEFAULT_NAME)))
	s.difficulty = Difficulty.from_key(str(d.get("difficulty", "")), Difficulty.DEFAULT)
	s.created = maxi(_int(d.get("created", 0)), 0)
	s.last_played = maxi(_int(d.get("last_played", s.created)), 0)
	s.playtime = maxf(_num(d.get("playtime", 0.0)), 0.0)
	var rec: Variant = d.get("records", {})
	if rec is Dictionary:
		for k in s.records.keys():
			s.records[k] = maxi(_int((rec as Dictionary).get(k, 0)), 0)
	var rn: Variant = d.get("runs", {})
	if rn is Dictionary:
		for mode in GameMode.count():
			var key := GameMode.key_of(mode)
			var r: Variant = (rn as Dictionary).get(key)
			if r is Dictionary and _run_ok(r as Dictionary):
				s.runs[key] = (r as Dictionary).duplicate(true)
	return s


## Yarım koşu en azından tohum ve oyuncu bölümünü taşımalı.
static func _run_ok(r: Dictionary) -> bool:
	return r.has("seed") and r.get("player") is Dictionary


static func _int(v: Variant, fallback: int = 0) -> int:
	if v is int:
		return v
	if v is float:
		return int(v) if is_finite(v) else fallback
	if v is String and (v as String).is_valid_int():
		return (v as String).to_int()
	return fallback


static func _num(v: Variant, fallback: float = 0.0) -> float:
	if v is int:
		return float(v)
	if v is float:
		return v if is_finite(v) else fallback
	if v is String and (v as String).is_valid_float():
		return (v as String).to_float()
	return fallback
