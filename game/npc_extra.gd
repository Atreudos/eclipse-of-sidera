class_name NpcExtra
extends RefCounted
## Ek konuşma karakterleri (Undertale tarzı, tek seferlik küçük sahneler): ara odalardaki gizli konuşma odaları ve lobi olayları.
## Her konuşma bir kez tamamlanınca bayrak (`ev_<id>`) kurulur; sonra kısa bir "bitti" düğümüne gider.
## Düğüm anahtarları (DialogueMenu): gold/gold_flag, dopamin/dopamin_flag/dopamin_repeat, heal/heal_flag, sfx;
## seçenek anahtarları: cancel (Q), pay (altın öder), fail (yetmezse düğüm).

const IDS := ["kedi", "fare", "memur", "asansor"]


static func has(id: String) -> bool:
	return id in IDS


static func dialogue(id: String) -> Dictionary:
	match id:
		"kedi":
			return _kedi()
		"fare":
			return _fare()
		"memur":
			return _memur()
		"asansor":
			return _asansor()
	return Dialogue.linear("", ["..."])


static func _yes_no(yes: String, no: String, yes_text: String = "Evet", no_text: String = "Hayır") -> Array:
	return [{"text": yes_text, "next": yes}, {"text": no_text, "next": no, "cancel": true}]


## Nöbetçi Kedi: sevilmek ister.
static func _kedi() -> Dictionary:
	var done := Story.has("ev_kedi")
	return {"speaker": "Nöbetçi Kedi", "start": "done" if done else "a", "nodes": {
		"a": {"text": "*Miyav.* (Bu kedi odanın nöbetçisi. Nöbet ücreti: sevilmek.)", "next": "b"},
		"b": {"text": "Kediyi sevmek ister misin?", "choices": _yes_no("yes", "no", "Sev", "Sevme")},
		"yes": {"text": "*Kediyi sevdin. Kedi mırıldadı. Kule bir an daha az soğuktu.*", "sfx": "heal", "heal": 1, "heal_flag": "hl_kedi", "dopamin": 10, "dopamin_flag": "dp_kedi", "dopamin_repeat": false, "set_before": "ev_kedi", "next": "end"},
		"no": {"text": "*Kedi esneyip arkasını döndü. Kimse kırılmadı. (Kedi biraz kırıldı.)*", "next": "end"},
		"done": {"text": "*Kedi uyuyor. Dokunursan uyanır. Dokunmazsan da uyanır. Kedi bu.*", "next": "end"},
	}}


## Kira Faresi: odanın sahibi olduğunu iddia eder.
static func _fare() -> Dictionary:
	var done := Story.has("ev_fare")
	return {"speaker": "Kira Faresi", "start": "done" if done else "a", "nodes": {
		"a": {"text": "*Gözlüklü küçük bir fare. Önünde 'KİRA' yazan koca bir defter.*", "next": "b"},
		"b": {"text": "Merhaba! Bu oda bana ait. Kira zamanı: 5 altın. Ödemek ister misin?", "choices": [
			{"text": "Öde (5 altın)", "pay": 5, "next": "paid", "fail": "poor"},
			{"text": "Ödemem", "next": "no", "cancel": true}]},
		"paid": {"text": "Harika! Yatırım getirisi: 12 altın. Fare iş bilir.", "gold": 12, "gold_flag": "gd_fare", "dopamin": 5, "dopamin_flag": "dp_fare", "dopamin_repeat": false, "set_before": "ev_fare", "next": "end"},
		"poor": {"text": "Cebin boş mu? Peki, borç asılı kalsın. Ben de sana asılı kalırım.", "next": "end"},
		"no": {"text": "*Fare defterine bir şey karaladı. Sanırım artık adın 'Kötü Kiracı'.*", "next": "end"},
		"done": {"text": "*Fare altınlarını sayıyor. 'Yalnız çalışıyorum,' diyor, 'kuleye sormayın.'*", "next": "end"},
	}}


## Kayıp Eşya Memuru: ne kaybettiğini sorar.
static func _memur() -> Dictionary:
	var done := Story.has("ev_memur")
	return {"speaker": "Kayıp Eşya Memuru", "start": "done" if done else "a", "nodes": {
		"a": {"text": "*Kayıp Eşya Bürosu. Sırada 0 kişi var. Memur uyuyor.*", "next": "b"},
		"b": {"text": "Hıh? Ha, müşteri! Bir şey mi kaybettin?", "choices": [
			{"text": "Kılıcımı", "next": "sword"},
			{"text": "Hafızamı", "next": "memory"},
			{"text": "Hiçbir şey", "next": "none", "cancel": true}]},
		"sword": {"text": "Kılıç mı... Bir gölge getirmişti, evet. Ama gölgelere iade yapmayız. Şunu al, avuntu ödülü.", "gold": 10, "gold_flag": "gd_memur", "dopamin": 3, "dopamin_flag": "dp_memur", "dopamin_repeat": false, "set_before": "ev_memur", "next": "end"},
		"memory": {"text": "Hafıza mı? Bu bürodan çıkan her şey bir noktada unutulur. (Bu bir 'hayır'.) Ama formu doldurdun, tebrikler.", "gold": 5, "gold_flag": "gd_memur", "dopamin": 5, "dopamin_flag": "dp_memur", "dopamin_repeat": false, "set_before": "ev_memur", "next": "end"},
		"none": {"text": "Harika. Kayıp olmayan en iyi kayıptır. *Memur tekrar uyudu.*", "next": "end"},
		"done": {"text": "*Memur horluyor. Masasında 'Hafızanı Bul' kitapçığı açık duruyor.*", "next": "end"},
	}}


## Bozuk Asansör (kat 13 lobisi): anket yapar.
static func _asansor() -> Dictionary:
	var done := Story.has("ev_anket")
	return {"speaker": "Bozuk Asansör", "start": "done" if done else "a", "nodes": {
		"a": {"text": "*BİP.* Bu asansör arızalı. Arıza sebebi: sen. Çıkmadan önce kısa bir anket.", "next": "b"},
		"b": {"text": "Kuleyi nasıl buldun?", "choices": [
			{"text": "Çok yüksek", "next": "r"},
			{"text": "Çok karanlık", "next": "r"},
			{"text": "Ben bu anketi sevdim", "next": "r"},
			{"text": "Cevap vermeyeceğim", "next": "no", "cancel": true}]},
		"r": {"text": "*BİP BOP.* Teşekkürler! Cevabın Umbra'ya iletildi. Merak etme, o da cevaplamadı.", "set_before": "ev_anket", "next": "r2"},
		"r2": {"text": "*Asansör sana '1 ücretsiz iç çekiş' kuponu verdi. Yanında 20 altın da çıktı.*", "gold": 20, "gold_flag": "gd_anket", "dopamin": 3, "dopamin_flag": "dp_anket", "dopamin_repeat": false, "next": "end"},
		"no": {"text": "*BİP.* Anlaşıldı. 'Cevapsız' da bir cevaptır.", "next": "end"},
		"done": {"text": "*BİP.* Anket sonuçları: herkes yorgun. Asansör de.", "next": "end"},
	}}
