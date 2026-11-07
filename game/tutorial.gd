class_name Tutorial
extends RefCounted
## Kat 1 öğreticisi. İki parçası var:
##
##  1) MÜFREDAT (her zaman): kat 1'in savaş odaları elle yazılmıştır. Düşmanlar TEK TEK gelir (her dalga tek düşman; ilk ikili
##     yalnız son odada), yavaştır, ilk derslerde yalnız ALTIN (parry'lenebilir) saldırı yapar; sonra KIRMIZI (dash) gelir,
##     sonra karışık. Kat 2'den itibaren normal dalgalar başlar.
##  2) İPUÇLARI (profilde `tutorial_done` yokken): ekrandaki tuş ipuçları (TutorialGuide + TutorialHint). Lobide hareket
##     (A/D), zıplama (W/Space), dash (Shift), saldırı (J); savaşta parry (K) ve kırmızı işarette dash.
##
## Bu sınıf yalnız VERİdir (müfredat, ipucu metinleri); akışı TutorialGuide yürütür.

const TAURUS := preload("res://actors/enemies/taurus.tscn")
const SAGITTA := preload("res://actors/enemies/sagitta.tscn")

## Dersin saldırı rengi: karışık (normal), yalnız altın (parry dersi), yalnız kırmızı (dash dersi).
enum Style { MIXED, GOLD, RED }
## Dersin temposu.
enum Pace { SLOW, MILD, NORMAL }

## Tempo çarpanları (ayarın üstüne biner): hız, uyarı süresi, bekleme, toparlanma (düşmanın açık kaldığı süre), sersemleme.
const PACE_SLOW := {"speed": 0.75, "telegraph": 1.6, "cooldown": 1.5, "recover": 1.25, "stun": 1.2}
const PACE_MILD := {"speed": 0.9, "telegraph": 1.25, "cooldown": 1.2, "recover": 1.1, "stun": 1.1}

# İpucu kimlikleri
const STEP_MOVE := "move"
const STEP_JUMP := "jump"
const STEP_DASH := "dash"
const STEP_ATTACK := "attack"
const STEP_GO := "go"
const STEP_PARRY := "parry"
const STEP_PARRY_SHOT := "parry_shot"
const STEP_PARRY_MISS := "parry_miss"
const STEP_STRIKE := "strike"
const STEP_RED := "red"

## Lobideki ipuçları, sırayla.
const LOBBY_STEPS := [STEP_MOVE, STEP_JUMP, STEP_DASH, STEP_ATTACK, STEP_GO]
## Öğreticinin tamamlanması için yapılması gerekenler (ipucu kimlikleri).
const REQUIRED := [STEP_MOVE, STEP_JUMP, STEP_DASH, STEP_ATTACK, STEP_PARRY, STEP_RED]

## Saldırı adımının istediği vuruş sayısı (3'lü kombo).
const ATTACKS_NEEDED := 3

const RED_TEXT := Color(1.0, 0.42, 0.42)
const GREEN := Color(0.45, 1.0, 0.6)


# ---------------------------------------------------------------- müfredat

## Bu oda öğretici müfredatını kullanır mı? (kat 1'in savaş odaları)
static func applies(loc: Dictionary) -> bool:
	return int(loc.get("floor", 0)) == 1 and int(loc.get("kind", -1)) == FloorPlan.Kind.COMBAT


static func _lesson(enemies: Array, style: int, pace: int) -> Dictionary:
	return {"enemies": enemies, "style": style, "pace": pace}


## Kat 1'in `slot`. odasının (1..4 = 2..5. oda) dersleri; her ders bir dalgadır.
static func lessons(slot: int) -> Array:
	match slot:
		1:  # PARRY: tek Taurus, yavaş, yalnız altın; iki kez (tekrar)
			return [_lesson([TAURUS], Style.GOLD, Pace.SLOW), _lesson([TAURUS], Style.GOLD, Pace.SLOW)]
		2:  # MERMİ (altın) -> KIRMIZI (dash) -> karışık
			return [_lesson([SAGITTA], Style.GOLD, Pace.SLOW), _lesson([TAURUS], Style.RED, Pace.SLOW), _lesson([SAGITTA], Style.MIXED, Pace.MILD)]
		3:  # Karışık ama hâlâ tek tek
			return [_lesson([TAURUS], Style.MIXED, Pace.MILD), _lesson([SAGITTA], Style.MIXED, Pace.MILD), _lesson([TAURUS], Style.MIXED, Pace.MILD)]
		4:  # İlk ikili, sonra normal tempoya geçiş (Gölge'den önceki sınav)
			return [_lesson([TAURUS, SAGITTA], Style.MIXED, Pace.MILD), _lesson([TAURUS], Style.MIXED, Pace.NORMAL), _lesson([TAURUS, SAGITTA], Style.MIXED, Pace.NORMAL)]
	return []


## Odanın dalgaları (her dalga bir PackedScene dizisi).
static func waves(slot: int) -> Array:
	var out: Array = []
	for l: Dictionary in lessons(slot):
		out.append((l["enemies"] as Array).duplicate())
	return out


## Her dalganın düşman ayarı: odanın ayarı (`base`) + dersin temposu ve saldırı rengi.
static func wave_tunings(slot: int, base: EnemyTuning) -> Array:
	var out: Array = []
	for l: Dictionary in lessons(slot):
		out.append(lesson_tuning(base, int(l["style"]), int(l["pace"])))
	return out


static func lesson_tuning(base: EnemyTuning, style: int, pace: int) -> EnemyTuning:
	var t := base.copy()
	var p := pace_table(pace)
	if not p.is_empty():
		t.speed *= float(p["speed"])
		t.telegraph *= float(p["telegraph"])
		t.cooldown *= float(p["cooldown"])
		t.recover *= float(p["recover"])
		t.stun *= float(p["stun"])
	t.gold_only = style == Style.GOLD
	t.red_only = style == Style.RED
	return t


static func pace_table(pace: int) -> Dictionary:
	match pace:
		Pace.SLOW:
			return PACE_SLOW
		Pace.MILD:
			return PACE_MILD
	return {}


# ---------------------------------------------------------------- kayıt

## Bu profilde ipuçları gösterilsin mi? Kayıtsız oturumda (hızlı koşu, geliştirme) her zaman.
static func hints_wanted(slot: SaveSlot) -> bool:
	return slot == null or not slot.tutorial_done


## Öğreticiyi bu profilde tamamlandı say ve kaydet.
static func mark_done(slot: SaveSlot) -> void:
	if slot == null or slot.tutorial_done:
		return
	slot.tutorial_done = true
	SaveStore.save_slot(slot)


# ---------------------------------------------------------------- ipucu içeriği

static func _t(text: String, color: Color = Color.WHITE) -> Dictionary:
	return {"t": text, "c": color}


## Tuş ikonu: harf/sözcük ("A", "SPACE", "SHIFT") ya da ok ("LEFT", "RIGHT", "UP", "DOWN").
static func _k(label: String) -> Dictionary:
	return {"k": label}


## Saldırı işareti ikonu: "gold" (altın elmas) ya da "red" (kırmızı daire).
static func _i(kind: String) -> Dictionary:
	return {"i": kind}


static func _row(parts: Array, size: int = 28, dim: bool = false) -> Dictionary:
	return {"parts": parts, "size": size, "dim": dim}


## Bir ipucunun içeriği: {"id", "title", "rows": [{"parts": [...], "size", "dim"}]}. `n`: sayaçlı ipuçlarında ilerleme.
static func hint(id: String, n: int = 0) -> Dictionary:
	match id:
		STEP_MOVE:
			return {"id": id, "title": "HAREKET", "rows": [
				_row([_k("A"), _k("D"), _t("   KOŞ")]),
				_row([_t("OK TUŞLARI DA ÇALIŞIR")], 15, true)]}
		STEP_JUMP:
			return {"id": id, "title": "ZIPLAMA", "rows": [
				_row([_k("W"), _t("  YA DA  "), _k("SPACE"), _t("   ZIPLA")]),
				_row([_t("HAVADAYKEN TEKRAR BAS: ÇİFT ZIPLAMA")], 15, true)]}
		STEP_DASH:
			return {"id": id, "title": "DASH", "rows": [
				_row([_k("SHIFT"), _t("   DASH")]),
				_row([_t("DASH SIRASINDA DOKUNULMAZSIN  (2 ŞARJ)")], 15, true)]}
		STEP_ATTACK:
			return {"id": id, "title": "SALDIRI", "rows": [
				_row([_k("J"), _t("   SALDIR  "), _t("%d/%d" % [mini(n, ATTACKS_NEEDED), ATTACKS_NEEDED], GameFont.YELLOW)]),
				_row([_t("ARKA ARKAYA BAS: 3'LÜ KOMBO")], 15, true)]}
		STEP_GO:
			return {"id": id, "title": "İLERLE", "rows": [
				_row([_t("SAĞDAKİ KAPIYA GİT   "), _k("D")]),
				_row([_t("TEZGÂHTA E: DÜKKÂN  (ALTIN LAZIM)")], 15, true)]}
		STEP_PARRY:
			return {"id": id, "title": "PARRY", "rows": [
				_row([_i("gold"), _t("  ALTIN İŞARET   ", GameFont.YELLOW), _k("K"), _t("   PARRY")]),
				_row([_t("SALDIRI DEĞMEDEN HEMEN ÖNCE BAS: DÜŞMAN SERSEMLER")], 15, true)]}
		STEP_PARRY_SHOT:
			return {"id": id, "title": "PARRY", "rows": [
				_row([_i("gold"), _t("  ALTIN MERMİ   ", GameFont.YELLOW), _k("K"), _t("   PARRY")]),
				_row([_t("MERMİ GERİ DÖNER VE ÇOK DAHA FAZLA VURUR")], 15, true)]}
		STEP_PARRY_MISS:
			return {"id": id, "title": "PARRY", "rows": [
				_row([_t("KAÇIRDIN", RED_TEXT), _t("   TEKRAR DENE")]),
				_row([_t("SALDIRI YAKLAŞIRKEN BAS, ERKEN BASMA")], 15, true)]}
		STEP_STRIKE:
			return {"id": id, "title": "SERSEMLEDİ", "rows": [
				_row([_k("J"), _t("   VUR!", GameFont.YELLOW)]),
				_row([_t("PARRY SONRASI İLK VURUŞUN İKİ KAT GÜÇLÜ")], 15, true)]}
		STEP_RED:
			return {"id": id, "title": "KIRMIZI İŞARET", "rows": [
				_row([_i("red"), _t("  PARRY'LENEMEZ  ", RED_TEXT), _k("SHIFT"), _t("  DASH")]),
				_row([_t("SALDIRI GELİRKEN DASH'LE: DOKUNULMAZSIN")], 15, true)]}
	return {}

