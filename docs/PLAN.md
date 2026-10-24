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
Eşya listesini oyun tasarımcısı kendisi hazırlayacak; eşya içeriği ondan gelene kadar sadece altyapı var (`items/`).

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
- Kalp tabanlı (Isaac gibi, 3-5 kalp başlangıç). Yarım kalp yok, sade.
- Can toparlama: sadece agresiflik kademesi "Ateşli" ve üstü iken parry'den küçük şans + mağaza.

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
- **Etiket (tag) sistemi:** her eşyanın 1-3 etiketi var: `PARRY`, `DASH`, `MERMI`, `ALEV`, `BUZ`, `ZEHIR`, `CAN`, `RITIM`, `KARMA`.
- **Sinerji:** aynı etiketten 3 eşya = küçük bonus (Isaac'taki set mantığı).
- **Nadirlik:** Yaygın / Nadir / Efsanevi / **Lanetli** (güçlü ama bedeli var).
- **Umbra etiketi:** `Sadece Oyuncu` / `Umbra Dahil`.

### 7.2 Örnek eşyalar (başlangıç seti)

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

### 7.3 İlginç sinerji örnekleri
- *Yankılı Mermi + Faiz* = parry'de ekranı dolduran mermi yağmuru.
- *Cam Kalp + Altın Diş* = tek vuruşta ölüm riskiyle "ritim ustası" build'i.
- *Hırsız Eldiveni + Aç Kapı* = Umbra çok güçlü ama sen onu hızla soyuyorsun.

---

## 8. Run Yapısı

### 8.1 Kat yapısı (5 kat)
Her kat: 4-5 savaş odası + 1 ödül/mağaza + 1 Umbra pusu + 1 boss odası (kat sonu mini-boss, 5. katta final).

### 8.2 Oda tipleri
- **Savaş:** düşman dalgaları, bitince ödül.
- **Mezat (ödül):** 2 eşya, seç.
- **Mağaza:** altınla eşya satın alma, can yenileme, eşya silme (Umbra'ya giden havuzdan).
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
│   ├── hud/ (can, dash, ritim metresi)
│   ├── auction_screen.tscn   # 2 eşya seçim ekranı
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
- [ ] Agresiflik (ritim) metresi
- [x] Oda sistemi (5 yerleşim, sağa doğru odalar, kapı, dalgalar, doğuş işareti, ölüm özeti)
- [ ] Can sistemi + ölüm/yeniden başlama
- [ ] 3 düşman ailesi

### Aşama 3: Eşya sistemi (hafta 3)
- [ ] ItemData + modifier + EventBus
- [ ] Mezat ekranı (2 eşya seç)
- [ ] 10 eşya
- [ ] Etiket sinerji bonusu

### Aşama 4: UMBRA (hafta 4)  ← oyunu farklı kılan
- [ ] Seçilmeyen eşya Umbra envanterine gider
- [ ] Umbra pusu dövüşü (ActorBase ile)
- [ ] Umbra eşya saldırıları (altın renkli)
- [ ] Parry ile eşya çalma
- [ ] "Sadece Oyuncu" etiketi

### Aşama 5: İçerik (hafta 5-6)
- [ ] 5 kat, boss'lar, mağaza, gizli odalar
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
