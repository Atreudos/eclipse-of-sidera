class_name NpcTalk
extends RefCounted
## Konuşulan karakterlerin tanımları ve konuşma metinleri.
## Mira her lobide (kat kat ilerleyen ana hikâye + sorulabilir konular); ara odalardaki karakterler perdeye göre değişir.

const NPCS := {
	"mira": {"name": "Mira", "title": "Fener Bekçisi", "tint": Color(1.0, 0.8, 0.4)},
	"tellal": {"name": "Tellal", "title": "Haberci", "tint": Color(0.9, 0.55, 0.35)},
	"ayna": {"name": "Kırık Ayna", "title": "Umbra'nın Sesi", "tint": Color(0.6, 0.85, 1.0)},
	"terazi": {"name": "Terazi Yaşlısı", "title": "Tartıcı", "tint": Color(0.75, 0.8, 0.5)},
	"su": {"name": "Su Taşıyıcı", "title": "Geçmişin Bekçisi", "tint": Color(0.4, 0.7, 1.0)},
	"umbra": {"name": "Umbra", "title": "Gölge", "tint": Color(0.75, 0.5, 1.0)},
}


static func ids() -> Array:
	return NPCS.keys()


static func display_name(id: String) -> String:
	return str((NPCS.get(id, {}) as Dictionary).get("name", id))


static func tint(id: String) -> Color:
	return (NPCS.get(id, {}) as Dictionary).get("tint", Color(0.6, 0.7, 1.0))


## Perde (0-4): kat 1-4, 5-8, 9-12, 13-16, 17-18.
static func act_of(floor_no: int) -> int:
	return clampi((maxi(floor_no, 1) - 1) / 4, 0, 4)


## Bu katın ara odasındaki karakter.
static func pocket_npc(floor_no: int) -> String:
	return ["tellal", "ayna", "terazi", "su", "umbra"][act_of(floor_no)]


## Karakterin şu anki konuşması (kata ve bayraklara göre).
static func dialogue(id: String, floor_no: int = 1) -> Dictionary:
	if id == "mira":
		return _mira(floor_no)
	if POCKET.has(id):
		return _pocket(id, floor_no)
	return Dialogue.linear(display_name(id), ["..."])


# ---------------------------------------------------------------- Mira

## Katın ana hikâye anlatımı (ilk konuşmada tam anlatılır; sonra sorulabilecek konulara geçilir).
const MIRA_BEATS := {
	1: ["Bir ışık daha. Aylardır kimse bu kadar yukarı çıkamadı.", "Ben Mira, bu kulenin fener bekçisiyim. On sekiz kat, on sekiz fener. Hepsi yanık kalırsa gökyüzü ayakta durur.", "Hiçbir şey hatırlamıyorsun, değil mi? Merak etme. Kule hatırlatır."],
	2: ["Gölgeyi yendin ama yok etmedin. Gölgeler yok olmaz, sadece geri çekilir.", "Fark ettin mi? Seçmediğin eşya ona gidiyor. Kule bunu böyle istiyor, ben değil."],
	3: ["Her fener bir burcu ayakta tutar. Boğa, Yay, Akrep. Fenerler sönünce burçlar yozlaşıp kuleyi dolaşır.", "Düşman sandığın şeyler aslında bekçiydi. Işık gidince akılları da gitti."],
	4: ["Koç ve Yengeç bu katta uyandı. İkisi eskiden kapıları korurdu.", "Ben de bir zamanlar fenerleri yakanlardandım. İlk çıkışında sen de bizdendin, Sidera."],
	5: ["Aynalar katına geldin. Burada herkes kendini arar.", "Kırık Ayna'yı görürsen dinle. Umbra'nın sesini taşır. Yalan söylemez, ama her şeyi de söylemez."],
	6: ["Aynalarda kendini değil, bıraktıklarını görürsün. İlk çıkışında kılıcını burada bıraktın.", "Hatırlamıyorsun. Ama kılıcın seni hatırlıyor."],
	7: ["İkizler ve Aslan bu katta uyanıyor. İkizler hep birlikte doğdu; biri ölünce öbürü deliriyor.", "Aslan ise kükreyince herkesi coşturur. Önce onu sustur."],
	8: ["Dördüncü fener yarı kırık. Gölge bu katın sonunda sana ilk kez konuşacak.", "Kulak ver, kaçma. Kaçtıkça yankısı büyür."],
	9: ["Terazi katı. Burada her şeyin bir bedeli var; altının da, sözün de, pişmanlığın da.", "Terazi ve Kova yozlaştı. Mermiler dengesini yitirdi. Parry'le, dengeyi sen geri ver."],
	10: ["Terazi Yaşlısı aldığınla bıraktığını tartar. İkisinin farkı sensin, der.", "Bence haklı. Aldıklarına bak, ama bıraktıklarını da say."],
	11: ["Umbra'nın kullandığı eşyaları fark ettin mi? Hepsi senin vazgeçtiklerin.", "O seni yenmek için değil, geri alınmak için savaşıyor. Bu fark sandığından önemli."],
	12: ["Üçüncü perde bitiyor. Aşağıda bırakılanlar çoğaldı; Umbra hiç olmadığı kadar güçlü.", "Ama sen de güçlendin. Terazi bunu da tartar."],
	13: ["Su katı. Geçmiş burada akar; tutmaya çalışma, boğulursun.", "Su Taşıyıcı sana bir şey gösterecek. Hazır ol, acıtır."],
	14: ["Bugün Su Taşıyıcı kovasında bir el gösterecek. Küçük bir el.", "O, ilk bıraktığın şey. Sana söylemedim çünkü kendin bulmalıydın."],
	15: ["Şimdi hatırlıyorsun, gözlerin durulmuş.", "Bu kuleye geri dönme isteğini bırakmak için çıktın. O istek Umbra'nın çekirdeği oldu."],
	16: ["Bir kat kaldı sayılır, sonra tutulma.", "Arkana bakma. Ama bil ki arkanda kimse yok değil; ben hep buradayım."],
	17: ["Tutulma başladı. Fenerlerin hepsi titriyor.", "Bu katta kendi gölgenle yüzleşeceksin. Yenmek mi, kabul etmek mi, bırakmak mı? Karar senin."],
	18: ["Son fener. Buraya kadar geldin, Sidera.", "Hangi yolu seçersen seç, bir bedeli var. Ben hep burada olacağım. Şimdi git, ışığı yak."],
}

## Sorulabilen konular: [soru, [perde 0..4 cevapları]]
const MIRA_TOPICS := {
	"kule": ["Kule hakkında anlat.", [
		"Sidera Kulesi göğe uzanır. On sekiz katın her biri bir fener taşır.",
		"Aynalar katları kuleye sonradan eklendi. Yansımalar kuleyi derinleştirir.",
		"Terazi katı kulenin ortasıdır. Her ağırlık buradan dağılır.",
		"Su kulenin temelinden yükselir; yukarı çıktıkça katlar suya batar.",
		"Tutulma katlarında kule gökyüzüne değer. Gölge ve ışık burada eşitlenir.",
	]],
	"umbra": ["Umbra kim?", [
		"Senin bıraktıklarından doğdu. Seçmediğin her eşya ona yol olur.",
		"Seni izlerken öğreniyor. Her katta yeni bir şey öğreniyor.",
		"İntikam peşinde değil. Sadece geri alınmak istiyor.",
		"Korkunun biçimi o. Senin korkun, onun gücü.",
		"Onu yenmek de kabul etmek de bir seçim. Hangisi cesaret, sen bilirsin.",
	]],
	"ben": ["Ben kimim?", [
		"Sen Sidera'sın. Fener çırağı. Başka bir şey hatırlamıyorsan bu yeter.",
		"Sen çok kez çıktın. Her çıkışta biraz daha hatırlarsın.",
		"Sen almayı da bırakmayı da öğrendin. Terazi bunu görür.",
		"Sen geçmişinden kaçan değil, ona yürüyensin.",
		"Sen Sidera'sın; ışık sensin, gölge de sensin.",
	]],
}


static func _mira(floor_no: int) -> Dictionary:
	var act := act_of(floor_no)
	var beat_key := "mira_beat_%d" % floor_no
	var nodes := {}
	var start := "hub"
	var beat: Array = MIRA_BEATS.get(clampi(floor_no, 1, 18), ["..."])
	if not Story.has(beat_key):
		start = "b0"
		for i in beat.size():
			var n := {"text": str(beat[i]), "next": ("b%d" % (i + 1)) if i + 1 < beat.size() else "hub"}
			if i + 1 == beat.size():
				n["set"] = "%s,mira_met" % beat_key
			nodes["b%d" % i] = n
	var hub_text := "Başka bir şey öğrenmek ister misin?" if start == "b0" else "Hâlâ buradasın. Bir şey mi soracaktın?"
	var choices: Array = []
	for key in MIRA_TOPICS:
		var topic: Array = MIRA_TOPICS[key]
		choices.append({"text": str(topic[0]), "next": "t_" + key})
		nodes["t_" + key] = {"text": str((topic[1] as Array)[act]), "next": "hub"}
	if Story.has("shards"):
		choices.append({"text": "Yıldız kırıntıları nedir?", "next": "t_shards"})
		nodes["t_shards"] = {"text": "Bulmaca odalarındaki parıltılar, sönen fenerlerden dökülen ışık. Şu ana kadar %d tane buldun. On sekizini de toplarsan kule seni bırakır, birlikte çıkarsınız." % int(Story.get_flag("shards", 0)), "next": "hub"}
	choices.append({"text": "Hoşça kal.", "next": "end"})
	nodes["hub"] = {"text": hub_text, "choices": choices}
	return {"speaker": "Mira", "start": start, "nodes": nodes}


# ---------------------------------------------------------------- Ara oda karakterleri

## id -> kat -> {"lines": [...], "ask": [[soru, cevap], ...], "gold": n}
const POCKET := {
	"tellal": {
		1: {"lines": ["Ooo, bir misafir! Ben Tellal. Kulenin haberlerini duyururum, para karşılığı bazen susarım da.", "Bu ara odalar kuleden kaçak yapılmış. Fenerler yanarken kimse buraya bakmaz, ama armağanlar hâlâ burada duruyor.", "Dövüştüğün odalarda sandık görürsen dokun. Kimseye söylemem."],
			"ask": [["Burası neresi?", "Kulenin yan koridoru. Her kat bir tane saklar. Savaşın dışında soluklanmak için."], ["Sandıklar nerede?", "Savaş odalarına serpilmiş. Altın, yiyecek, bazen unutulmuş bir eşya. Kimin olduğunu sorma, artık senin."]]},
		2: {"lines": ["Yine sen! Bu kez daha yorgun görünüyorsun. Çay yok ama haber var.", "Aşağıda bir gölgenin fener söndürdüğü dedikodusu dolaşıyor. Sana benziyormuş."],
			"ask": [["Hangi gölge?", "Umbra derler. Ama bence adı o değil. Adı olmayan şeye isim koymak kolay."], ["Fenerleri kim yakıyor?", "Eskiden çıraklar. Şimdi Mira tek başına. Ona saygı göster."]]},
		3: {"lines": ["Bak kimin geldiğine! Sana bir borcum var: bir sürü sözünü satmışım.", "Al, bu kadarı yeter. Kule hepimize bir şey borçlu."], "gold": 8,
			"ask": [["Neyi sattın?", "Biraz fener hikâyesi, biraz senin adın. Pişmanım. Altınla telafi."], ["Tüccar kim?", "Dükkâncı mı? Konuşmaz. Ama bırakılan eşyaları toplar. Kimin eşyası olduğunu sorma."]]},
		4: {"lines": ["Dördüncü kat. İlk kez bu kadar yükseldin. Ben burada kalıyorum; yukarısı benim işim değil.", "Mira'ya selam söyle. Gölgeye dikkat et: o seni yendikçe değil, sen yendikçe güçleniyor.", "Yolun açık olsun, Sidera."], "gold": 12,
			"ask": [["Neden yukarı çıkmıyorsun?", "Herkesin çıkacağı kat başkadır. Benimki burası."]]},
	},
	"ayna": {
		5: {"lines": ["Duyuyor musun? Ben aynayım. Kırığım. Ama kırık olan sadece yüzeyim.", "Seni izliyorum. Bir de başkası seni izliyor. Beni dinlersen onu tanırsın."],
			"ask": [["Kimin sesisin?", "Bir gölgenin. Senden kopan yarının. Adını biliyorsun."], ["Neden kırıksın?", "Çünkü çok kez baktın ve hep başka birini gördün."]]},
		6: {"lines": ["Bugün gözlerin daha net. Hatırlıyorsun, değil mi? Kılıcını ilk burada bıraktın.", "O kılıç şimdi onda. Al, aynanın arkasında kalmıştı."], "gold": 10,
			"ask": [["Kılıç mı?", "İlk çıkışında burada bıraktın, ağırdı. Onu o aldı."], ["Ona ne olacak?", "Sen seçeceksin. Yenmek ya da kabul etmek."]]},
		7: {"lines": ["İkizler. Gördün mü onları? Biri öbürünü kaybedince öfkeleniyor. Kayıp insanı öfkeli yapar.", "Umbra da bir kayıp. Sen kaybettiğin için o var."],
			"ask": [["Umbra neden güçleniyor?", "Her bıraktığında biraz daha doluyor. Vazgeçtiklerin onun gücü."], ["Nasıl durdururum?", "Bırakmayarak. Ya da bırakmanın bedelini bilerek."]]},
		8: {"lines": ["Sonunda konuşacak, bu katın sonunda. Dinle, kaçma.", "Ben sadece yansımayım. O senin geri kalanın.", "Kırık aynada bile yüzün görünüyor, fark ettin mi?"], "gold": 15,
			"ask": [["Ne diyecek?", "Beni de götür, diyecek. Hep aynı şeyi der. Ama bu sefer ciddi."]]},
	},
	"terazi": {
		9: {"lines": ["Terazi katına hoş geldin evlat. Burada her şey tartılır: altın da, söz de, pişmanlık da."],
			"ask": [["Neyi tartıyorsun?", "Aldığınla bıraktığını. İkisinin farkı sensin."], ["Terazi düşmanlar neden öyle?", "Terazi bozuldu, mermiler dengesini yitirdi. Parry'le, dengeyi geri ver."]]},
		10: {"lines": ["Bugün terazim eğri. Bir kefede aldıkların, öbüründe bıraktıkların. Hangisini ağır görüyorsun?"], "gold": 10,
			"ask": [["Bıraktıklarım.", "Dürüst cevap. Bıraktıkların seni daha çok yorar."], ["Aldıklarım.", "Güzel. Ama aldığın her şey bir başkasının kaybıdır. Unutma."]]},
		11: {"lines": ["Umbra'nın kullandığı eşyaları fark ettin mi? Hepsi senin seçmediğin eşyalar.", "Adil mi dersin? Terazi bunu tartamadı. Sen tart."],
			"ask": [["Adil değil.", "Belki. Ama seçmek bırakmaktır. Ağırlık hep var."], ["Adil.", "O zaman bedelini ödemeye hazırsın."]]},
		12: {"lines": ["Üçüncü perde bitiyor. Terazi sana son kez soruyor: eksilen mi çok, artan mı?", "Al şunu, tartının payı."], "gold": 20,
			"ask": [["Ne yapacağım?", "Yürümeye devam. Ağırlık yürüyenin omzunda hafifler."]]},
	},
	"su": {
		13: {"lines": ["Su akar, geçmiş de. Ben Su Taşıyıcı. Kovama her şeyi doldururum: gözyaşını, yağmuru, unutuşu."],
			"ask": [["Kovada ne var?", "Senin unuttukların. Bir yudum ister misin? Hatırlamak acıtır."], ["Kova neden taşıyor?", "Kule yükseldikçe su da yükselir. Biri taşımalı."]]},
		14: {"lines": ["Bugün sana bir şey göstereceğim. Kovaya bak. Bir el görüyor musun? Küçük bir el.", "O, ilk bıraktığın şeydi. Geri dönme isteği."],
			"ask": [["Geri dönme isteği mi?", "En ağırı. Herkes bir şey bırakır ama bunu bırakmak zordur."], ["Kimin eli?", "Senin. Çıraklığının ilk günü."]]},
		15: {"lines": ["Şimdi hatırlıyorsun, belli. Gözlerin durulmuş. Umbra'nın çekirdeği o istek.", "Onu yenersen istek ölür. Kabul edersen birleşirsiniz."], "gold": 15,
			"ask": [["Hangisi doğru?", "Doğru yok, sadece bedel. İkisi de sensin."], ["Mira biliyor muydu?", "Her çıkışında. Sana söylemedi, çünkü kendin bulmalıydın."]]},
		16: {"lines": ["Bir kat daha var, sonra tutulma. Kovamı doldurdum, bu sana yetsin.", "Suya bak ve kendini gör. Gölge ve ışık aynı sudadır."], "gold": 25,
			"ask": [["Tutulma nedir?", "Işıkla gölgenin aynı yerde durması. Ya birbirini yer, ya birbirine karışır."]]},
	},
	"umbra": {
		17: {"lines": ["Gelmişsin. Burada kavga yok. Bu oda ikimizin de değil, o yüzden güvenli.", "Sana bir şey söylemek istedim. Sana kızgın değilim. Hiç olmadım.", "Ben sadece unutulmak istemedim."],
			"ask": [["Neden bana saldırıyorsun?", "Beni görmen için başka yolum yoktu."], ["Seni yenersem ne olur?", "Ben sönerim, sen yalnız kalırsın. Ama fenerler yanar."]]},
		18: {"lines": ["Son oda. Birazdan karşılaşacağız.", "Hangi yolu seçersen seç, bil ki bu kuleyi çıkan ilk kişi sensin, ben değil. Çünkü bırakmak da çıkmaktır.", "Hazır olduğunda gel."], "gold": 30,
			"ask": [["Barışabilir miyiz?", "Belki. Seçim sende. Tutulma bunun için var."]]},
	},
}


static func _pocket(id: String, floor_no: int) -> Dictionary:
	var by_floor: Dictionary = POCKET[id]
	var f := floor_no
	if not by_floor.has(f):
		var keys: Array = by_floor.keys()
		keys.sort()
		f = keys[0]
		for k in keys:
			if int(k) <= floor_no:
				f = k
	var spec: Dictionary = by_floor[f]
	var lines: Array = spec["lines"]
	var asks: Array = spec.get("ask", [])
	var nodes := {}
	var talked := "talk_%s_%d" % [id, f]
	var heard := Story.has(talked)
	var start := "hub" if heard else "n0"
	var after := "hub" if not asks.is_empty() else "end"
	for i in lines.size():
		var n := {"text": str(lines[i]), "next": ("n%d" % (i + 1)) if i + 1 < lines.size() else after}
		if i + 1 == lines.size():
			n["set"] = talked
			if int(spec.get("gold", 0)) > 0:
				n["gold"] = int(spec["gold"])
				n["gold_flag"] = "gift_%s_%d" % [id, f]
		nodes["n%d" % i] = n
	if not asks.is_empty():
		var choices: Array = []
		for i in asks.size():
			var a: Array = asks[i]
			choices.append({"text": str(a[0]), "next": "a%d" % i})
			nodes["a%d" % i] = {"text": str(a[1]), "next": "hub"}
		choices.append({"text": "Hoşça kal.", "next": "end"})
		nodes["hub"] = {"text": "Başka bir şey?" if not heard else "Yine mi geldin? Sor bakalım.", "choices": choices}
	return {"speaker": display_name(id), "start": start, "nodes": nodes}
