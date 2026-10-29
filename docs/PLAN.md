# ECLIPSE OF SIDERA: Tasarım Dokümanı ve Proje Planı

> Motor: Godot 4.x (GDScript). Tür: 2D, hikayesiz, aksiyon roguelite. İlham: Isaac, Brotato, Balatro, Dead Cells, Ultrakill, Cuphead.

---

## 0. Adlar

| Ne | Ad | Anlamı |
|---|---|---|
| Oyun | **Eclipse of Sidera** | "Sidera'nın tutulması": yıldızın gölgeyle örtülmesi |
| Oyuncu karakteri | **Sidera** | Latince "yıldızlar" |
| Gölge / rakip | **Umbra** | Latince "gölge"; tutulmada gölgenin en karanlık bölgesi. Seçmediğin eşyaları alıp sana karşı kullanır |
| 1. düşman | **Taurus** (Boğa) | Üstüne koşarak vuran boynuzlu goblin, mahzen kıyafetli |
| 2. düşman | **Sagitta** (Yay, ok) | Yılan görünümlü dişi okçu; ok atar |
| 3. düşman | **Scorpius** (Akrep) | İki rapier'li vur-kaç dövüşçüsü, mesafe oyunu |

Düşman adları burçlardan gelir; yeni düşmanlar da bu çizgide adlandırılır. Kod ve sprite klasörleri bu adları kullanır (`taurus`, `sagitta`, `scorpius`, `sidera`).
Eşya listesini oyun tasarımcısı kendisi yazdı: 10 donanım + 3 yemek (bölüm 7.3). Yeni eşyalar da ondan gelir; koda eklemek `items/item_db.gd` içinde tek bir `_add({...})` bloğudur.

---

## 1. Vizyon

**Tek cümle:** Isaac gibi eşya build'i kurarsın, Ultrakill gibi parry/dash ile agresif dövüşürsün; ama seçmediğin her eşyayı **Umbra** alır ve sana karşı kullanır.

**Tasarım sütunları**
1. **Her seçim bir bedel.** Eşya almak güç, eşya bırakmak risk.
2. **Parry = ekonomi.** Parry sadece savunma değil, build büyütmenin yoludur.
3. **Agresiflik ödüllendirilir.** Bekleyen oyuncu zayıflar.
4. **Az içerikle çok çeşitlilik.** Her eşya hem oyuncuya hem Umbra'ya içerik olur.
5. **Kapsam küçük.** Tek kişi + Claude ile bitirilebilir olmalı.

**Hedef his:** "Bir daha deneyeyim, bu sefer o eşyayı bırakmayacağım."

---

## 2. Tema (öneri, değiştirilebilir)

> **Güncel:** Oyunun adı *Eclipse of Sidera*; düşmanlar burç/takımyıldız adı taşıyor. Aşağıdaki "Kara Mezat" metni eski öneri; tema kararı Açık Sorular'da duruyor.

**Kara Mezat:** Yeraltında, kat kat inilen bir açık artırma kulesi. Her kat bir salon. Salonlarda eşyalar sergileniyor. Sen "alıcı"sın, Umbra ise karşı teklifçi. Hikaye yok; sadece estetik ve atmosfer.

- **Görsel:** Siluet ağırlıklı, 2 ana renk + 1 vurgu rengi (altın = parry'lenebilir tehlike).
- **Ses:** Gerilimli, ritmik, düşük tempolu elektronik/org karışımı. Parry sesi çok tatmin edici olmalı (en önemli ses efekti).
- **UI:** Eşya seçimi bir "mezat sehpası" gibi görünür: iki eşya, ortada çekiç.

Alternatif temalar (istenirse): Hayalet pazar, çöl kervansarayı, uzay hurdalığı, mahkeme salonu.

---

## 3. Çekirdek Döngü

```
Oda gir → Düşmanları temizle (dash/parry/saldır) → 2 eşya çıkar
→ Birini al, diğeri Umbra'ya gider → Sonraki oda
→ 3 katta bir: Umbra pususu (Umbra, bıraktığın eşyalarla gelir)
→ Kat sonu: Boss (run boyunca toplanan her şeyin toplamı)
```

**Run uzunluğu hedefi:** 20-30 dakika. 5 kat, kat başı ~4-5 oda + 1 pusu + 1 boss.

---

## 4. Oyuncu Mekanikleri

### 4.1 Hareket
- Koşma + zıplama (platform değil, ağırlıklı **arena** hissi; zıplama kısa ve kontrollü).
- Havada 1 ekstra zıplama (eşyayla çoğaltılabilir).
- Duvara tutunma YOK (kapsamı küçük tut).

### 4.2 Dash
- 2 şarj. Şarj geri gelme: ~1.2 sn veya düşman öldürünce anında 1 şarj.
- İ-frame: ilk ~0.15 sn dokunulmazlık.
- Dash yönü: son basılan yön (yoksa baktığın yön).

### 4.3 Parry (oyunun kalbi)
- Tek tuş. Parry penceresi: **~0.12 sn (60 FPS'te ~7 kare)**.
- Kaçırırsan: ~0.35 sn "toparlanma" (bu sürede parry yok, hasar alırsın).
- **Parry'lenebilir her saldırı altın renkli** (mermi, yakın dövüş vuruşu, Umbra'nın eşya saldırıları).
- **Başarılı parry:**
  - Mini hitstop (~0.06 sn) + ekran sarsıntısı + keskin ses.
  - Mermiyse: geri döner (hasarı artar).
  - Yakın saldırıysa: düşman sersemler (~0.6 sn).
  - Sonraki vuruş x2 hasar (kısa süreli).
  - Agresiflik metresi dolar.
  - **Parry zinciri:** başarılı bir parry'den sonraki 0.3 sn içinde değen diğer altın saldırılar da parry'lenir (aynı anda gelen iki saldırıyı tek tuşla karşılarsın). Satürn'ün Kum Saati bunu tetikler (bkz. 7.3).
  - Umbra'nın eşya saldırısıysa: **eşya çalma ilerlemesi** kazanılır (bkz. 5.4).
- **Parry'lenemez (kırmızı) saldırılar:** kaçman (dash) gerekir. Bu denge Cuphead pembe/normal ayrımı gibi çalışır.

### 4.4 Saldırı
- Ana silah: hızlı yakın dövüş (3'lü kombo) + menzilli zayıf alternatif (cooldown'lu).
- Silahlar run başında seçilmez; eşyalar silahı değiştirir (basit tutmak için tek taban silah + modifikasyonlar).

### 4.5 Agresiflik Metresi ("Ritim")
Ultrakill'in stil sistemi ilhamlı, kan yok.
- Doldurma: vuruş, parry, dash içinden öldürme, combo.
- Azalma: ~2 sn hiçbir şey yapmazsan düşer.
- Kademeler (4): Soğuk → Isınmış → Ateşli → Coşkulu.
- Etkiler: hasar bonusu, can toparlama, eşya etkileri kademeye bağlanabilir.
- Hasar alınca bir kademe düşer (can kaybı yanında ek ceza).

### 4.6 Can sistemi
- Kalp tabanlı (Isaac gibi). Başlangıç **4 kalp**; üst sınır eşyalarla artar, HUD en çok 12 kalp gösterir. Yarım kalp yok, sade.
- Can toparlama: agresiflik kademesi "Ateşli" ve üstü iken parry'den küçük şans, yemekler, Vampir Yadigarı (parry = +3 can) ve mağaza.
- Ölünce özet ekranı çıkar, `R` ile yeniden başlanır.
- **Deneme modu (`F4`):** can düşmez, dash ve parry bekleme yok; HUD'da rozet çıkar. Oyunu geçemeden bir şeyi denemek için.

### 4.7 Bağışıklık kalbi ve yemek
Tasarımcının kuralları (kod: `Player.try_eat`, `Player.set_immunity`):
1. **Fazla iyileşme bağışıklık kalbine döner.** Canına sığmayan kısım mavi **bağışıklık kalbi** olur.
2. **Bağışıklık kalbi hasarı önce kendine alır;** artan hasar canı götürür.
3. **Suistimal engeli:** bağışıklık kalbi varken (dükkândan da, envanterden de) **kesinlikle yemek yenmez** ("BAĞIŞIKLIK KALBİ VARKEN YEMEK YENMEZ").
4. Can zaten doluysa da yemek yenmez ("CANIN ZATEN DOLU"; `Player.ALLOW_EAT_AT_FULL` ile değişir). Ölüyken ya da yemek olmayan eşya için de ret mesajı çıkar.

Yemekler slotsuzdur: çantada durur, envanter ekranında yenir. Umbra'ya gitmez, ödül çiftinde çıkmaz (mağazada satılır).

| Yemek | Etki | Fiyat |
|---|---|---|
| Kule Ekmeği | +1 kalp | 6 |
| Fırınlanmış Tatlı Patates | +2 kalp; canına sığmayan kısım bağışıklık kalbi olur | 12 |
| Kozmik Yıldız Çorbası | Canı tamamen doldurur (iyileşme miktarı = en çok can); sığmayan kısım bağışıklık kalbi olur | 24 |

### 4.8 Refleks (tepki hızı)
`reflex` statı parry penceresini çarpar: **etkin pencere = parry_window x refleks** (taban 0.12 sn, refleks 1.0 = normal, en az 0.25'e iner). Refleksi artıran/azaltan eşyalar ve geçici durumlar için hazır altyapı: durumlar (`Player.apply_status`) süreli stat değişikliği verir (ör. "Yorgun": refleks x0.8) ve HUD'da satır olarak görünür. Envanter ekranında REFLEKS ve etkin PARRY süresi yazar.

### 4.9 Altın
- Düşmanlar ölünce para saçar: **küçük para = 1 altın**, **antika para = 3 altın** (Hırsızın Zinciri antika para düşürtür).
- Düşman başına miktar: Taurus 2-4, Sagitta 2-3, Scorpius 3-5 (düşman sahnesinde `gold_min` / `gold_max`).
- Para zıplar, 110 px'e yaklaşınca sana çekilir, 26 px'te toplanır. Oda temizlenince kalan paralar yarım saniye sonra sana uçar.
- Sayaç HUD'da ve envanter ekranında görünür.
- Harcama yeri: **mağaza** (bölüm 8). Her eşyanın `price` alanı hazır.

---

## 5. RAKİP SİSTEMİ (oyunu özel yapan şey)

### 5.1 Temel kural
Her ödül odasında **2 eşya** sunulur. Birini seçersin; **diğeri Umbra'nın envanterine gider.**

### 5.2 Umbra kimdir?
- Senin gölgen gibi: aynı hareket seti (dash, parry benzeri blok) ama **kendi eşyalarıyla** saldırır.
- Görünüşü, aldığı eşyalara göre değişir (ateş eşyası alırsa kıvılcımlı, buz alırsa donuk).
- Konuşmaz, hikayesi yok.

### 5.3 Umbra ne zaman çıkar?
- **Pusu (3 odada bir):** rastgele bir odada belirir. Önceden uyarı: ekranda "Umbra yaklaşıyor" işareti, ses ipucu.
- **Mini-boss gibi:** can değeri, Umbra'nın envanter büyüklüğüne göre ölçeklenir ama sınırlıdır (adil kalmalı).
- **Final boss:** Umbra'nın tüm envanteriyle ve ek bir "Mezatçı" fazıyla.

### 5.4 Eşya çalma (parry ödülü)
- Umbra'nın eşya kaynaklı saldırıları altın renkli → parry'lenebilir.
- Her başarılı parry bir **"Çalma Sayacı"** doldurur (örn. 3 parry = 1 eşya).
- Sayaç dolunca o dövüş sonunda Umbra'nın eşyalarından **birini** seçip alabilirsin (rastgele değil, seçmeli; ödül hissi için).
- Alternatif zorluk ayarı: çalınan eşya sadece o dövüş boyunca ya da kalıcı.

### 5.5 Denge kuralları (kritik)
- Umbra'ya giden eşyalardan bazıları **"Sadece Oyuncu"** etiketli (Umbra'ya gitmez). Çok güçlü/saçma sinerjileri olanlar.
- Umbra'nın maksimum aktif eşya sayısı: 6. Fazlası "depoda bekler", pusuda rastgele 6'sı seçilir.
- Umbra'nın hasarı oyuncunun hasarına göre ölçeklenir (adaptif tavan).
- Umbra'ya giden eşya **bir kez** "kara listeye" alınabilir (Kara Kalem eşyası).

### 5.6 Karar gerilimi örnekleri
- "Bu eşya çok güçlü ama Umbra'ya giden buz eşyasıyla ateş build'im söner mi?"
- "Parry build'im için bu eşya şart ama diğeri Umbra'ya giderse parry'lenemez mermiler atar..."

---

## 6. Düşman Aileleri (tek tür değil)

Her ailenin **kendine özgü parry biçimi** var; böylece oyun tekrar etmiyor.

| Aile | Rol | Saldırı | Parry etkisi |
|---|---|---|---|
| **Taurus'lar** | Temel yakın dövüş | Atılıp vurma (çoğu kırmızı, ara sıra altın) | Altın atılma parry'lenirse sersemler |
| **Sagitta'lar** | Menzilli | Mermi desenleri (çoğu kırmızı, ara sıra altın) | Altın mermi geri döner |
| **Kasacılar** | Tank | Yavaş, ağır; kırmızı (parry'lenemez) darbeler arasında tek altın vuruş | Parry'lenirse zırhı kırılır |
| **Scorpius'lar** | Vur-kaç, mesafe oyunu | Kısa altın telgrafla düz rapier dürtüşü; sahte dürtüş + sırttan vuruş | Sahte hamlede erken parry = ceza, gerçek dürtüşü tam zamanında parry = 1.5 sn sersemleme |
| **Müzayedeciler (destek)** | Diğerlerini güçlendirir | Alan etkisi | Parry yerine öncelikli hedef (önce öldür) |
| **Elitler** | Mini-boss | Ailenin gelişmiş hali + 1 özel mekanik | Parry zinciri gerektirir |

**Yüksekliğe (üst platformlara) cevap, aileye göre FARKLI:**

| Aile | Oyuncu yukarıdaki platformdayken |
|---|---|
| Taurus | Platformun altına yürür, zıplayıp çıkar; oyuncu aşağıdaysa kenardan iner. Başka yükseklikteyken saldırı başlatmaz. |
| Sagitta | Çıkmaz. Olduğu yerden yukarıya ateş eder (mermiler platformlardan geçer). |
| Kasacı (Aşama 2) | Çıkamaz (ağır). Yüksekteki oyuncuya yaylı kasa fırlatır. |
| Scorpius | Kılıç mesafesini korur; oyuncu yukarıdaysa Taurus gibi zıplayıp platforma çıkar. |
| Müzayedeci | Havada süzülür, platform sorunu yok. |

**Toplam hedef (MVP):** 4 aile x 1-2 çeşit = 6-8 düşman. Genişletme sonra.

---

## 7. Eşya Sistemi

### 7.1 Eşya mimarisi
- **Etiket (tag) sistemi:** her eşyanın 1-3 etiketi var: `PARRY`, `DASH`, `MERMI`, `ALEV`, `BUZ`, `ZEHIR`, `CAN`, `RITIM`, `KARMA`, `ZAMAN`, `ALTIN`, `HAREKET`, `SAVUNMA`.
- **Sinerji:** aynı etiketten 3 eşya = küçük bonus (Isaac'taki set mantığı). Şimdilik PARRY, DASH, RITIM, CAN, ALEV, BUZ için tanımlı (`ItemDB.SYNERGIES`); ekranda envanterin altında görünür.
- **Nadirlik:** Yaygın / Nadir / Efsanevi / **Lanetli** (güçlü ama bedeli var).
- **Umbra etiketi:** `Sadece Oyuncu` / `Umbra Dahil`.

### 7.2 Slotlar, çanta ve envanter ekranı

Eşyalar slotlara takılır; sayılar tek yerden okunur (`ItemData.SLOT_CAPACITY`), değiştirince ekran kendiliğinden uyar.

| Slot | Kapasite | Not |
|---|---|---|
| Ayak | 1 | ayakkabı, bot |
| Charm (kolye) | 3 | |
| Kafa | 2 | bandana, şapka, kask |
| Cep | 1 | |
| Bilek | 1 | sayı sonra değişebilir |
| Zırh | 1 | henüz eşya yok |
| Yemek | - | takılmaz; çantada durur, yenir |

- **Çanta:** 24 hücre. Takılmamış eşyalar ve yemekler burada durur; aynı eşyanın kopyaları tek hücrede yığılır.
- **Envanter ekranı (`I` ya da `Tab`)**: oyunu durdurur. Ortada karakter, çevresinde slotlar, sağda çanta, en sağda seçili eşyanın ayrıntısı (ad, nadirlik, slot, açıklama, **GÖLGE ALIRSA** metni, etiket, fiyat). Çantanın altında can/bağışıklık, altın, refleks, parry süresi, dash, hız ve aktif sinerjiler. Yön tuşları / WASD / fare ile gezilir; `Enter`, `E`, `J` ya da tıklama: çantadaki eşyayı tak, takılıyı çıkar, yemeği ye. `Esc`, `I`, `Tab` ya da panel dışına tıklama kapatır.
- Tek kapasiteli slot doluysa yeni eşya takılırken **eskisiyle yer değiştirir** (eski çantaya döner). Çok kapasiteli slot doluysa önce biri elle çıkarılır. Çanta doluysa "ÇANTA DOLU" der.
- Görünüm geçici: çizimler gelince yenilenecek, mantık aynı kalır. Eşya simgeleri `assets/items/<eşya_id>.png` olarak konunca otomatik kullanılır (yoksa harf yer tutucu).
- **Eşya menüsü (`F5`, deneme için):** tüm eşyaları slot sırasıyla listeler; `Enter`/`E`/`J`/tıklama envantere ekler (slotta yer varsa hemen takar), `T` yalnız çantaya koyar, `G` +50 altın, `H` canı doldurur, `B` +1 bağışıklık kalbi, `C` her şeyi siler. Ödül seçme mekaniği sonra gelecek; bu menü o zamana kadar test içindir ve her zaman açılabilir.

### 7.3 Güncel eşya listesi (tasarımcının listesi)

| Slot | Eşya | Etki | Gölge alırsa | Nadirlik | Fiyat |
|---|---|---|---|---|---|
| Ayak | **Ayna Tabanlı Çizmeler** | +1 ekstra dash hakkı | Gölge de son savaşta sana karşı fazladan 1 dash atabilir | Nadir | 55 |
| Ayak | **Hafif Tüy Botlar** | Yürüme hızı %20 artar | Gölge de seninle birebir aynı hızda yürür | Yaygın | 30 |
| Charm | **Engerek Dişi Kolyesi** | Parry'lediğin düşmana zehir verir (saniyede 2 hasar, 1.5 sn) | O da seni parrylerse saniyede 2 hasar veren zehir bırakır | Nadir | 50 |
| Charm | **Yıldız Tozu Broşu** | Saldırıların düşmanı geri iter (geri itme 2 kat) | Gölge de sana vurduğunda seni aynı mesafede geri iter | Yaygın | 30 |
| Charm | **Vampir Yadigarı** | Başarılı her parry +3 can yeniler | Gölge parryleyince kendine +1 can çeker | Efsanevi | 95 |
| Kafa | **Antika Muhafız Kaskı** | Aldığın hasar %15 azalır | Gölge de senden %15 daha az hasar alır | Yaygın | 35 |
| Kafa | **Gözcü Bandı** | Parry penceresi +0.1 sn | Gölgenin de parry penceresi +0.1 sn genişler | Yaygın | 35 |
| Cep | **Çatlak El Aynası** | Can sıfıra inince ölümcül darbeyi engeller, 1 canla kurtarır, 2 sn ölümsüz yapar; tek kullanımlık, kırılır | Gölge son savaşta canı sıfırlanınca 2. evresine geçer, tam canla dirilir | Nadir | 60 |
| Cep | **Satürn'ün Kum Saati** | İki saldırıyı aynı anda parry'lersen zaman 1.5 sn durur; yalnız sen hareket edersin | (yazılacak) | Efsanevi | 120 |
| Bilek | **Hırsızın Zinciri** | Parry'lediğin düşman fazladan antika para düşürür | (yazılacak) | Nadir | 50 |
| Yemek | Kule Ekmeği, Fırınlanmış Tatlı Patates, Kozmik Yıldız Çorbası | bkz. 4.7 | - | - | 6 / 12 / 24 |

**Satürn'ün Kum Saati:** zaman duran 1.5 sn boyunca düşmanlar, mermiler, doğuş işaretleri ve oda sayaçları donar (düşmanlar buz mavisi görünür); sen, paralar ve efektler akmaya devam edersin. Donmuş düşmana vurabilirsin: hasar işlenir, geri itme ve sersemlik zaman akınca uygulanır. İki parry'nin 0.35 sn içinde gelmesi yeter (parry zinciri sayesinde aynı anda gelen iki saldırı bunu tetikler).

**"Gölge alırsa" metinleri** Umbra dövüşü (Aşama 4) yazılırken uygulanacak; şimdilik envanterde ve F5 menüsünde okunur. Eski yer tutucu eşyalar koddan kaldırıldı, yerine bu liste geldi.

### 7.4 Kodlanırken yapılan varsayımlar (değiştirmek istersen söyle)
- Bilek ve zırh kapasitesi 1 (listede sayı yoktu).
- Can doluyken yemek yenmez; bağışıklık kalbi varken zaten yenmez.
- Vampir Yadigarı +3 can yeniler (en çok max cana kadar); Engerek Dişi zehri 1.5 sn sürer.
- Kum Saati cep slotunda; Çatlak El Aynası ile aynı slotu paylaşır (ikisinden biri).
- Antika Muhafız Kaskı %15'i tam sayı hasarda kesir biriktirerek uygular (yaklaşık her 7 hasar puanında 1 puan silinir).
- Çatlak El Aynası kullanılınca kırılır ve envanterden silinir (yeniden takılamaz).
- Düşman altın miktarları ve küçük/antika para değerleri (1 / 3) ilk denge tahminidir.
- `F5` menüsü ve `F4` deneme modu her zaman açık; sürüm çıkarken kapatılacak.

### 7.5 Fikir havuzu (eski öneriler, kodda yok)

**Parry:**
1. **Yankılı Mermi:** Parry'lediğin mermi 3'e bölünür.
2. **Altın Diş:** Parry penceresi +0.04 sn.
3. **Ters Tepki:** Parry'de çevrendeki tüm mermiler yön değiştirir.
4. **Soğukkanlı:** Parry sonrası 1 sn dash şarjı sonsuz.

**Dash:**
5. **Faiz:** Her dash hasar biriktirir, parry'de hepsi patlar.
6. **Hayalet Adım:** Dash sırasında düşmanların içinden geçersin.
7. **Üçüncü Şarj:** +1 dash şarjı, ama dash mesafesi kısalır.

**Ritim:**
8. **Kıpırdama:** Agresiflik düşüşü yavaşlar, kademe artışı zorlaşır.
9. **Coşku:** "Coşkulu" kademede tüm hasar +%50, ama hasar alınca anında en dibe düşer.

**Umbra odaklı:**
10. **Kara Kalem:** Umbra'ya gidecek 1 eşyayı sil (pahalı, nadir).
11. **Hayalet Cüzdan:** Umbra'nın aldığı eşyayı görürsün.
12. **Sahte Kilit:** Seçmediğin eşya Umbra'ya gitmez, ama bir sonraki katta lanetli halini bulursun.
13. **Hırsız Eldiveni:** Çalma sayacı 3 yerine 2 parry'de dolar.

**Element:**
14. **Kıvılcım:** Vuruşlar alev bırakır. 15. **Don:** Parry'lenen düşman donar. 16. **Zehir Damlası:** Zehir birikir, dash'te patlar.

**Lanetli (risk/ödül):**
17. **Aç Kapı:** +%100 hasar, ama Umbra her pusuda +1 eşya fazla taşır.
18. **Cam Kalp:** Can 1'e düşer, parry penceresi iki katı.
19. **Son Teklif:** Boss dövüşünde x3 hasar, ama normal odalarda -%30.

**Hedef:** MVP 20 eşya, 1.0'da 60+.

### 7.6 İlginç sinerji örnekleri (fikir)
- *Yankılı Mermi + Faiz* = parry'de ekranı dolduran mermi yağmuru.
- *Cam Kalp + Altın Diş* = tek vuruşta ölüm riskiyle "ritim ustası" build'i.
- *Hırsız Eldiveni + Aç Kapı* = Umbra çok güçlü ama sen onu hızla soyuyorsun.

---

## 8. Run Yapısı

### 8.1 Kat yapısı (5 kat)
Her kat **bir mağaza ile başlar**, sonra 4-5 savaş odası + 1 ödül odası + 1 Umbra pusu + 1 boss odası (kat sonu mini-boss, 5. katta final).

> **UNUTMA: Mağaza her katın BAŞINDA olacak** (tasarımcı notu: "katların başında market/dükkan sistemi olacak"). Altın sistemi (düşmanlar para düşürür, HUD sayacı) ve her eşyanın `price` alanı hazır; mağaza odası ve ekranı henüz yapılmadı. Satacakları: eşyalar, yemekler (Ekmek 6, Tatlı Patates 12, Çorba 24), sonra can yenileme ve eşya silme.

### 8.2 Oda tipleri
- **Savaş:** düşman dalgaları, bitince ödül.
- **Mezat (ödül):** 2 eşya, seç.
- **Mağaza (her katın başında):** altınla eşya ve yemek satın alma, can yenileme, eşya silme (Umbra'ya giden havuzdan). Bağışıklık kalbi varken dükkândan da yemek yenmez (bkz. 4.7).
- **Pusu:** Umbra dövüşü (parry ile eşya çalma fırsatı).
- **Gizli oda:** riskli ödül (lanetli eşya).
- **Dinlenme:** küçük can yenileme.

### 8.3 Zorluk eğrisi
- Kat başına düşman sayısı ve hız artışı.
- Umbra, 3. katta ilk, 5. katta final olarak çıkar.
- Run başarısızlığında ne kaybedilir: her şey (roguelite standardı). Kalıcı ilerleme: bkz. 9.

---

## 9. Meta İlerleme (run'lar arası)

- **Koleksiyon:** keşfedilen eşyalar listede açılır (eşya havuzu zamanla büyür).
- **Başlangıç seçenekleri:** her karakter/"alıcı" farklı başlangıç eşyası ve pasifi (örn. Parry Ustası, Dash Hırsızı, Cam Top).
- **Zorluk modları:** "Umbra Daha Acımasız" gibi isteğe bağlı kurallar.
- **İstatistik ekranı:** en çok çalınan eşya, en uzun parry zinciri.

---

## 10. Teknik Mimari (Godot 4)

### 10.1 Klasör yapısı
```
res://
├── project.godot
├── autoload/
│   ├── game_state.gd         # run durumu, kat, oda sayacı
│   ├── event_bus.gd          # sinyaller (parry_success, enemy_died...)
│   ├── item_database.gd      # tüm eşya Resource'larını yükler
│   ├── umbra_manager.gd      # Umbra envanteri ve pusu mantığı
│   └── audio_manager.gd
├── actors/
│   ├── actor_base.gd         # Player ve Umbra ortak: sağlık, hasar, modifier
│   ├── player/
│   │   ├── player.tscn / player.gd
│   │   ├── state_machine.gd
│   │   └── states/ (idle, run, jump, dash, attack, parry, hurt)
│   ├── umbra/
│   │   └── umbra.tscn / umbra.gd   # actor_base'i kullanır
│   └── enemies/
│       ├── enemy_base.gd
│       └── (taurus, sagitta, scorpius, vault, auctioneer)
├── combat/
│   ├── hitbox.gd / hurtbox.gd
│   ├── parry_system.gd       # pencere, altın saldırı işaretleme
│   ├── projectile.gd         # parry'lenebilir/lenemez tipi
│   └── hitstop.gd
├── items/
│   ├── item_data.gd          # Resource: ad, etiketler, nadirlik, umbra_dahil
│   ├── effects/              # her eşyanın etkisi (script)
│   └── data/                 # .tres dosyaları
├── rooms/
│   ├── room_base.tscn
│   ├── room_generator.gd
│   └── templates/
├── ui/
│   ├── hud.gd, run_overlay.gd   # kalpler (+bağışıklık), altın, ritim, durum satırları
│   ├── game_menu.gd             # oyunu durduran menülerin ortak tabanı
│   ├── inventory_screen.gd      # envanter ekranı (I / Tab)
│   ├── dev_menu.gd              # F5 eşya (deneme) menüsü
│   ├── item_view.gd             # ortak çizimler: eşya kutusu, ayrıntı paneli
│   ├── auction_screen.tscn      # (yapılacak) 2 eşya seçim ekranı
│   └── menus/
└── assets/ (sprites, sfx, music, fonts)
```

### 10.2 Önemli teknik kararlar

**1. Eşya = Resource + Efekt scripti.**
`ItemData` (Resource): `id, name, tags[], rarity, rival_allowed, effect_script`.
Eşyalar `.tres` olarak veri; davranış `effect_script` içinde.

**2. Modifier sistemi (Isaac mantığı).**
Hasar, hız, parry penceresi gibi değerler tek bir `Stats` sınıfından geçer; eşyalar bu değerlere **ekleme/çarpma modifier'ı** ekler. Böylece yüzlerce eşya birbirini bozmadan üst üste biner.

**3. Olay tabanlı eşya etkileri.**
Eşyalar `EventBus` sinyallerine bağlanır (`on_parry_success`, `on_dash`, `on_hit`, `on_kill`). Yeni eşya = yeni dinleyici. Çekirdek koda dokunulmaz.

**4. Player ve Rival aynı `ActorBase`.**
Aynı eşya scriptleri iki tarafta çalışır; sadece "sahip" değişir (`owner_actor`). Bu, projenin en büyük kısayolu.

**5. Parry teknik detayı.**
- Parry state'i başlayınca `parry_window_timer` (0.12 sn) çalışır.
- Altın saldırılar `parryable = true` taşır; hitbox çarpışırken `parry_system` kontrol eder.
- Başarıda: `EventBus.parry_success.emit(attacker, projectile)` → hitstop, ses, eşya etkileri.

**6. Hitstop.**
`Engine.time_scale` kısa süre 0.05'e çekilip geri alınır (veya sadece ilgili node'lar duraklatılır; daha kontrollü).

**7. Oda üretimi.**
Önce elle yapılmış 10-15 oda şablonu, rastgele seçim + düşman dalgası verisi. Prosedürel üretim sonra.

**8. Kayıt sistemi.**
Meta ilerleme için `ConfigFile` veya JSON (basit). Run içi kayıt MVP'de yok.

### 10.3 Araçlar
- Godot 4.3+ , GDScript.
- Sprite: Aseprite veya ücretsiz asset paketleri (placeholder önce).
- Ses: sfxr/jsfxr ile geçici sesler.
- Sürüm kontrolü: Git (GitHub'da özel repo).

---

## 11. Yol Haritası

### Aşama 0: Hazırlık (1 gün)
- [x] Godot projesi + klasör yapısı + Git
- [x] Placeholder sprite'lar (renkli kareler yeterli)

### Aşama 1: Oyuncu hissi (hafta 1)  ← EN ÖNEMLİ
- [x] Hareket + zıplama
- [x] Dash (i-frame, şarj)
- [x] Hitbox/Hurtbox sistemi
- [x] Temel saldırı kombosu
- [x] **Parry** (pencere, altın saldırı, hitstop, ses)
- [x] 1 test düşmanı + altın mermi

**Çıkış kriteri:** Sadece bu arenada parry yapmak bile eğlenceli mi? Değilse Aşama 2'ye geçme.

### Aşama 2: Çekirdek döngü (hafta 2)
- [x] Agresiflik (ritim) metresi
- [x] Oda sistemi (5 yerleşim, sağa doğru odalar, kapı, dalgalar, doğuş işareti, ölüm özeti)
- [x] Can sistemi + ölüm/yeniden başlama (+ bağışıklık kalbi)
- [x] 3 düşman (Taurus, Sagitta, Scorpius)
- [x] Altın: düşmanlar para düşürür, sayaç HUD'da

### Aşama 3: Eşya sistemi (hafta 3)
- [x] ItemData + modifier + EventBus
- [x] Slotlar + çanta + envanter ekranı (I / Tab) + F5 eşya menüsü
- [x] 10 eşya + 3 yemek (tasarımcının listesi), refleks statı, zaman durdurma
- [x] Etiket sinerji bonusu
- [ ] Mezat ekranı (2 eşya seç; `ItemDB.roll_pair` hazır, seçme mekaniği sonra)
- [ ] **Mağaza: her katın başında** (altın + `price` hazır; oda/ekran yapılacak)

### Aşama 4: UMBRA (hafta 4)  ← oyunu farklı kılan
- [ ] Seçilmeyen eşya Umbra envanterine gider
- [ ] Umbra pusu dövüşü (ActorBase ile)
- [ ] Umbra eşya saldırıları (altın renkli)
- [ ] Parry ile eşya çalma
- [ ] "Sadece Oyuncu" etiketi

### Aşama 5: İçerik (hafta 5-6)
- [ ] 5 kat, boss'lar, gizli odalar (mağaza Aşama 3'te: her katın başı)
- [ ] 20+ eşya, 6-8 düşman
- [ ] Lanetli eşyalar

### Aşama 6: Cila (hafta 7-8)
- [ ] Gerçek sprite/animasyon, ses, müzik
- [ ] Ekran sarsıntısı, partikül, juice
- [ ] Meta ilerleme + ana menü
- [ ] Denge turları

### Aşama 7: Yayın
- [ ] Itch.io demo, geri bildirim, düzeltme

---

## 12. Riskler ve Önlemler

| Risk | Önlem |
|---|---|
| Parry hissi kötü olur | Aşama 1'de takıl, ince ayar yap; pencere/hitstop değerleri `export` değişkeni olsun |
| Umbra dengesiz çıkar | Ölçekleme tavanı, "Sadece Oyuncu" etiketi, test modu (Umbra envanterini elle ayarla) |
| Eşya sinerjileri oyunu bozar | Modifier sistemi, üst sınırlar (örn. parry penceresi max 0.25 sn) |
| Kapsam şişer | Her aşamanın "çıkış kriteri" var; çalışmıyorsa genişletme |
| Sanat işi yavaşlatır | Aşama 5'e kadar placeholder; stil: siluet + 2 renk |

---

## 13. Açık Sorular (karar bekleyen)

1. Tema: **Kara Mezat** olarak devam mı, başka bir tema mı?
2. Çalınan eşya **kalıcı mı**, yalnızca o dövüş boyunca mı?
3. Başlangıçta tek karakter mi, birden fazla "alıcı" mı?
4. ~~Oyun adı~~ → **Eclipse of Sidera** (karar verildi).
5. Hedef platform: sadece PC mi, web (itch.io) de mi?

---

## 14. Sonraki Adım

Aşama 0 ve 1'i birlikte başlatalım: Godot projesi iskeleti, oyuncu hareketi, dash ve parry sistemi.
