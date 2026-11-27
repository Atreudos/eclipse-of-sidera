class_name StoryFloors
extends RefCounted
## Hikaye kipinin STATİK kat senaryosu: herkes aynı yoldan gider. Hangi savaş odası (sıra 1-4) bulmaca olur,
## hangi katlarda "yumuşak iniş" (slime) olayı var burada yazılı. Tohuma bağlı değildir.
## Kat 1 öğretici müfredattır: bulmaca yok.

## kat -> {oda sırası: bulmaca türü}. Bazı katlarda 2 bulmaca, bazılarında 1, bazılarında hiç yok.
const PUZZLES := {
	2: {3: "parry"},
	3: {2: "stars"},
	4: {},
	5: {2: "simon", 4: "parkur"},
	6: {3: "stars"},
	7: {},
	8: {2: "parry", 4: "simon"},
	9: {3: "balance"},
	10: {},
	11: {2: "stars"},
	12: {1: "simon", 3: "parkur"},
	13: {4: "balance"},
	14: {},
	15: {2: "stars", 4: "simon"},
	16: {3: "mix"},
	17: {2: "parkur"},
	18: {},
}

## Savaş odalarındaki ETİKETSİZ kapılar: kat -> {oda sırası: tür}. "key" = anahtar parkuru (anahtar alınmadan odanın kapısı açılmaz),
## "treasure" = hazine odası. Kapı oda temizlenince kullanılabilir.
const SECRETS := {
	2: {1: "treasure"},
	4: {2: "key"},
	6: {1: "treasure"},
	7: {3: "key"},
	9: {1: "key"},
	10: {2: "treasure"},
	12: {4: "treasure"},
	14: {3: "key"},
	16: {1: "key"},
	17: {4: "treasure"},
	3: {1: "talk:kedi"},
	8: {3: "talk:fare"},
	11: {3: "talk:memur"},
}

## Bu katların lobisine "çukurdan düşüp" gelinir: yumuşak bir slime'ın üstüne inersin.
const SLIME_FLOORS := [5]


static func puzzle_kind(floor_no: int, slot: int) -> String:
	var d: Dictionary = PUZZLES.get(floor_no, {})
	return str(d.get(slot, ""))


static func puzzle_count(floor_no: int) -> int:
	return (PUZZLES.get(floor_no, {}) as Dictionary).size()


static func secret_kind(floor_no: int, slot: int) -> String:
	var d: Dictionary = SECRETS.get(floor_no, {})
	return str(d.get(slot, ""))


## OLAY ÇİZELGESİ: her olay hikâyede BİR KEZ olur. Kat 4'ün sonunda su baskını -> kat 5'in lobisinde slime; kat 9 lobisinde yazı-tura; kat 13 lobisinde anket.
## Bu katların Gölge odasında ödül seçilince su yükselmeye başlar; geçit tepeye taşınır. (Sonraki kat = slime katı.)
const FLOOD_FLOORS := [4]

## Başka kat sonu olayları (Gölge ödülü alınınca başlar): kat -> tür. "gold_rain" altın yağmuru, "rockfall" taş yağışı,
## "blackout" ışıkların sönmesi. Su baskını ayrıca FLOOD_FLOORS'tadır; `end_event()` ikisini birleştirir.
const END_EVENTS := {7: "gold_rain", 10: "rockfall", 11: "blackout"}


## Lobide gerçekleşen tek seferlik olaylar: kat -> olay kimliği.
const LOBBY_EVENTS := {9: "yazi_tura", 13: "anket", 15: "dogum"}
## Olayı yürüten karakter (lobide durur).
const EVENT_NPC := {"yazi_tura": "umbra", "anket": "asansor", "dogum": "umbra"}

## Kat adları (kat kartında altyazı).
const FLOOR_TITLES := [
	"Kulenin Dibi", "İlk Fener", "Boğa'nın Avlusu", "Kapı Bekçileri", "Aynalar Katı", "Bırakılan Kılıç",
	"İkizler ve Aslan", "Yarım Fener", "Terazi Katı", "Tartıcı'nın Odası", "Geri Alınanlar", "Üçüncü Perde",
	"Su Katı", "Küçük El", "Durulan Gözler", "Son Soluk", "Tutulma", "Son Fener",
]


static func floor_title(floor_no: int) -> String:
	return str(FLOOR_TITLES[clampi(floor_no, 1, FLOOR_TITLES.size()) - 1])


static func event_npc(ev: String) -> String:
	return str(EVENT_NPC.get(ev, ""))



static func lobby_event(floor_no: int) -> String:
	return str(LOBBY_EVENTS.get(floor_no, ""))


## Lobi olayının konuşması. Bir kez oynanır; sonra kısa bir veda.
static func event_dialogue(id: String) -> Dictionary:
	var flag := "ev_" + id
	var done := Story.has(flag)
	match id:
		"yazi_tura":
			return {"speaker": "Umbra", "start": "done" if done else "a", "nodes": {
				"a": {"text": "*Umbra bir bozuk para fırlatıp yakaladı.* Yazı mı, tura mı? Kazanan kulenin sırrını öğrenir.", "choices": [
					{"text": "Yazı", "next": "yazi"}, {"text": "Tura", "next": "tura"}, {"text": "Bozuk paraya güvenmem", "next": "no", "cancel": true}]},
				"yazi": {"text": "*Para havada döndü. Tura geldi.* Üzgünüm. Aslında iki yüzü de tura.", "next": "yazi2", "set_before": flag},
				"yazi2": {"text": "*Kaybettin ama çok güzel kaybettin.*", "dopamin": 5, "dopamin_flag": "dp_" + id, "dopamin_repeat": false, "next": "end"},
				"tura": {"text": "*Para havada döndü. Tura geldi.* ...Hile yok, yemin ederim. Al şunu.", "next": "tura2", "set_before": flag},
				"tura2": {"text": "*Umbra sana bir avuç altın verdi, gözünü kaçırarak.*", "gold": 30, "gold_flag": "gd_" + id, "dopamin": 5, "dopamin_flag": "dp_" + id, "dopamin_repeat": false, "next": "end"},
				"no": {"text": "Akıllıca. Ben de güvenmem.", "next": "end"},
				"done": {"text": "*Umbra bozuk parayı alnına dayamış, derin derin düşünüyor.*", "next": "end"},
			}}
		"anket":
			return NpcExtra.dialogue("asansor")
		"dogum":
			return {"speaker": "Umbra", "start": "done" if done else "a", "nodes": {
				"a": {"text": "*Umbra başında kâğıttan bir külahla köşede oturuyor.* Bugün doğum günüm. Bilmiyordum, az önce hesapladım.", "next": "b"},
				"b": {"text": "Gölgelerin doğum günü olmaz derler. Ama ben bir kat önce seni yenemediğim günü sayıyorum. Pasta ister misin?", "choices": [
					{"text": "Evet, pasta!", "next": "yes"}, {"text": "Mumları sen üfle", "next": "blow"}, {"text": "Şimdi değil", "next": "no", "cancel": true}]},
				"yes": {"text": "*Umbra bir dilim pasta uzattı. Pasta biraz karanlık tadında ama güzel.* Dilek tutmayı unutma.", "fx": "confetti", "sfx": "heal", "heal": 99, "heal_flag": "hl_" + id, "dopamin": 8, "dopamin_flag": "dp_" + id, "dopamin_repeat": false, "next": "wish", "set_before": flag},
				"blow": {"text": "*Umbra mumları üfledi. Mumlar yandı, Umbra söndü, sonra yine yandı.* Tamam, tamam. Pasta senin.", "next": "yes"},
				"wish": {"text": "*Umbra kısık sesle: 'Keşke bu kuleden ikimiz de çıksak.' ...Bunu duymadın.*", "next": "end"},
				"no": {"text": "Peki. Pasta bekler. Pastalar sabırlıdır, ben değilim.", "next": "end"},
				"done": {"text": "*Umbra külahını çıkarmış. Pastadan geriye bir tabak ve utangaç bir çatal kalmış.*", "next": "end"},
			}}
	return Dialogue.linear("", ["..."])


static func has_flood(floor_no: int) -> bool:
	return floor_no in FLOOD_FLOORS


## Katın sonunda gerçekleşen olay: "flood", "gold_rain", "rockfall", "blackout" ya da "" (yok).
static func end_event(floor_no: int) -> String:
	if floor_no in FLOOD_FLOORS:
		return "flood"
	return str(END_EVENTS.get(floor_no, ""))


static func has_slime(floor_no: int) -> bool:
	return floor_no in SLIME_FLOORS


## Slime konuşması. Dokunduysan ikinci kez başka laf eder.
static func slime_dialogue(floor_no: int) -> Dictionary:
	var key := "slime_f%d" % floor_no
	var again := Story.has(key)
	var nodes := {
		"a0": {"text": "*Neden geldiği bilinmeyen büyük bir slime.*", "next": "a1"},
		"a1": {"text": "Dokunmak istiyor musun?", "choices": [
			{"text": "Evet", "next": "yes"},
			{"text": "Hayır", "next": "no", "cancel": true},
		]},
		"yes": {"text": "*dokundun, eğlenceliydi*", "sfx": "heal", "dopamin": 10, "dopamin_flag": key, "next": "end"},
		"no": {"text": "*Slime anlayışla titredi. Biraz kırılmış gibi.*", "next": "end"},
		"b0": {"text": "*Slime seni tanıyor. Bir daha dokunursan bu ilişki garipleşir.*", "next": "b1"},
		"b1": {"text": "Yine de dokunmak istiyor musun?", "choices": [
			{"text": "Evet", "next": "yes"},
			{"text": "Hayır", "next": "no", "cancel": true},
		]},
	}
	return {"speaker": "Slime", "start": "b0" if again else "a0", "nodes": nodes}
