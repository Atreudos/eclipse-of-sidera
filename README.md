# Eclipse of Sidera

2D, hikayesiz aksiyon roguelite. Godot 4.4 (GDScript).

**Sidera** (yıldız) olarak oynarsın; gölgen **Umbra** peşinde. Isaac gibi eşya build'i kurarsın, Ultrakill gibi parry/dash ile agresif dövüşürsün. Her ödül odasında 2 eşya çıkar: birini alırsın, **seçmediğini Umbra alır** ve sana karşı kullanır. Umbra'nın saldırılarını parry'lersen eşyalarını geri çalarsın.

Düşmanlar burç adlıdır: **Taurus** (koşup vuran boğa goblin), **Sagitta** (yılan okçu), **Scorpius** (rapier'li akrep). Kat 4'ten itibaren yenileri gelir (`actors/enemies/roster.gd`): **Aries** (zırhlı koç; önden vuruş zırha çarpar, duvara çarpınca sersemler), **Cancer** (kalkanlı yengeç; kıskacını parry'lersen kalkan kırılır), kat 7: **Gemini** (ikizler; biri ölünce diğeri öfkelenir), **Leo** (aslan; kükremesi düşmanları hızlandırır, vurursan iptal olur), kat 10: **Libra** (terazi; parry'lediğin altın küre ikiye bölünüp başka bir düşmana da gider), **Aquarius** (kova; zemine su döker, birikinti yavaşlatır). Sınırsız kipte dalga/3 ≈ kat olarak aynı sırayla karışırlar. **Not:** bunlar Godot'suz ortamda yazıldı, testleri (`burc_kadro`, `burc_dusmanlar`) çalıştır.

Tasarım ve yol haritası: [`docs/PLAN.md`](docs/PLAN.md)

## Çalıştırma

1. Godot 4.4.x indir (standart sürüm, .NET gerekmez).
2. Godot'ta **Import** ile bu klasördeki `project.godot` dosyasını aç.
3. Editörde `F5` (ya da sağ üstteki ▶) ile oynat: oyun **ana menüyle** açılır (OYNA, KREDİLER, ÇIKIŞ). Doğrudan koşuyu denemek için menüde `F8` (kayıtsız hızlı koşu) ya da editörde `levels/run.tscn` açıp `F6` ("Geçerli sahneyi çalıştır"). (Oyunun içindeki `F5` başka işe yarar, aşağıya bak.)

## Kontroller (şimdilik)

| Tuş | İşlev |
|---|---|
| A / D veya ← / → | Koş |
| Space | Zıpla (W artık zıplatmaz: nişan yönü için ayrıldı) |
| Shift | Dash |
| K | Parry |
| J | **Birinci silah** (yakın dövüş: kılıç ya da yumruk; basılı tutunca kombo sürer) |
| I | **İkinci silah** (başlangıçta Yumruk). Sapan oyunda kapalı: kodu duruyor (`WeaponDB.sling_enabled`), kullanılmıyor |
| F3 | Debug paneli (parry penceresi, dash hızı vb. canlı ayar) |
| R | Yeniden başla (ölünce ya da istediğin an) |
| F4 | **Deneme modu (god)**: can düşmez, dash ve parry bekleme yok. Tekrar basınca kapanır, ölüp yeniden başlasan da açık kalır |
| Tab | **Envanter ekranı**: karakter, slotlar, silahlar, çanta. Oyunu durdurur. Yön tuşları/WASD/fare ile gez; Enter/E/J ya da tıkla: tak, çıkar, ye; **silah kutusunda** Enter = elindeki sıradaki silaha geç. Esc kapatır |
| F5 | **Eşya menüsü (deneme)**: listeden eşya seçip envantere ekler. Enter/E/J ekle, T yalnız çantaya, G +50 altın, H canı doldur, B +1 bağışıklık kalbi, C hepsini sil, **Y yumruğu ver, U silahları bir seviye yükselt** |
| F6 | Geliştirici kısayolu: bulunduğun odayı hemen temizle (oda akışını denemek için) |
| F7 | Geliştirici kısayolu: bir sonraki katın lobisine geç (kararma olmadan) |
| Esc | **Duraklatma menüsü**: devam, yeniden başla, ana menü, oyundan çık (koşuyu kaybettirenler ikinci basışta onaylanır) |
| M | Ölüm ekranında: ana menüye dön |

Altın uyarı = parry'lenebilir. Kırmızı uyarı = parry'lenemez, dash ile kaç.

## Durum

Aşama 0 ve 1 tamam: hareket, zıplama, dash (i-frame + şarj), 3'lü saldırı kombosu, parry (altın/kırmızı saldırı ayrımı, hitstop, ses), iki düşman tipi (Taurus, Sagitta) ve test arenası.
Ek olarak: vuruş flaşı + kıvılcım, yumuşak ekran sarsıntısı/kamera tepmesi, hasar/parry ekran flaşı, üst platformlara çıkabilen düşmanlar ve sprite/animasyon altyapısı.
Dinamik kamera (oyuncuyu yumuşak takip, baktığı yöne önden bakış, hafif zoom-in; dash'te açılır, kombo uzadıkça yaklaşır), fontlu hasar sayıları, 1 sn'lik kombo barı (COMBO yazısı + vuruş/parry/hasar sayaçları) ve ekranı kaplayan parry dalgası + yeni parry sesi.
Oyun artık **oda sistemiyle** açılıyor (`levels/run.tscn`): odalar sağa doğru dizilir; düşmanlar ışık sütunuyla dalga dalga doğar, hepsi ölünce kapı açılır, sağa geçince kapı arkandan kapanır. Her odanın yerleşimi (platformlar) ve dalgaları tohuma bağlıdır; her 4 katta renk teması değişir. Ölünce özet ekranı çıkar (R ile yeniden başla). Eski test arenası `levels/test_arena.tscn` olarak duruyor.
Gövdeler katı: dash düşmanın içinden geçmez (çarpıp durur), birbirinizin başına düşerseniz yana kayarsınız. Kamera yukarı/aşağı da çok az oynar (zıplarken yükselir, düşerken aşağı bakar, sert inişte çöker).
Vuruş sersemletmesi: kombo yediği sırada düşman saldıramaz (hazırlığı iptal olur). Altın (parry'lenebilir) saldırılar seyrek, kırmızılar (kaçılacak) çoğunlukta; altın saldırıda sarı elmas, kırmızıda sadece kırmızı parıltı var.
**Scorpius** (3. düşman): mesafe oyunu oynar: fazla yakınsan geri takla atar, rapier menzilinde çok kısa bir altın uyarıyla ışık hızında dürtüp hemen geri çekilir. Bazen sahte dürtüş yapar: erken parry'lersen arkana ışınlanıp sırtından vurur, sakin kalırsan boşa gider. Gerçek dürtüşü tam zamanında parry'lersen 1.5 sn sersemler (tek güvenli hasar fırsatı). 3. odanın 2. dalgasından itibaren dalgalara karışır.
**Eşya sistemi** (Aşama 3'ün büyük kısmı): slotlar (ayak 1, charm 3, kafa 2, cep 1, bilek 1, zırh 1) + 24 hücrelik çanta + envanter ekranı (`I`) ve deneme için `F5` eşya menüsü. 10 donanım (Ayna Tabanlı Çizmeler, Hafif Tüy Botlar, Engerek Dişi Kolyesi, Yıldız Tozu Broşu, Vampir Yadigarı, Antika Muhafız Kaskı, Gözcü Bandı, Çatlak El Aynası, Satürn'ün Kum Saati, Hırsızın Zinciri) ve 3 yemek (Kule Ekmeği, Fırınlanmış Tatlı Patates, Kozmik Yıldız Çorbası). Fazla iyileşme mavi **bağışıklık kalbi** olur (bağışıklık kalbi varken yemek yenmez). Düşmanlar altın düşürür (sayaç HUD'da; harcama yeri mağaza). **Refleks** statı parry penceresini ölçekler. Satürn'ün Kum Saati: iki saldırıyı birlikte parry'lersen zaman 1.5 sn durur.
**Ana menü ve kayıt** (`ui/menu/`): başlık ekranı (OYNA / KREDİLER / ÇIKIŞ), 3 kayıt slotu (ad, zorluk, kaldığın yer, süre, rekorlar), yeni oyun sihirbazı (ad yaz + zorluk seç: EASY / NORMAL / DIFFICULT / IMMORTAL), kayıt menüsü (NORMAL ve SINIRSIZ kip için DEVAM / BAŞLA / YENİ KOŞU, zorluk değiştirme, kaydı silme), krediler ve oyun içi duraklatma menüsü. Klavye, fare ve kumandayla gezilir. Koşu her odaya girerken kendiliğinden kaydedilir (kayıt `user://saves/` altında, bozulursa yedeğe düşer). Zorluk düşman canını, hasarını, hızını, saldırı sıklığını ve **zekâsını** (sabır, ceza, önden hedefleme, kaçış, aldatma) ayarlar; tur ilerledikçe düşmanlar sınırsız ama yavaş güçlenir. Arka plan ve logo kodla çizilir; çizimlerin (`ui_menu_bg_far`, `ui_logo`...) `assets/` altına konunca otomatik onların yerine geçer (`art/art.gd`).
**Katlar** (`game/floor_plan.gd`, `levels/run.gd`): normal koşu **18 kat**tır; her kat **6 oda**: 1. oda **lobi** (düşman yok, tüccarın **dükkânı**: tezgâha yaklaşıp `E`, altınla eşya ve yemek al), 2-5. odalar savaş, 6. oda **Gölge** (Umbra) odası. Gölge yenilince sağdaki **kat geçidi** açılır; içine yürüyünce ekran kararır, "KAT n" kartı çıkar, yeni katın lobisi kurulur. 18. katın Gölge'sini yenmek koşuyu **zaferle** bitirir (kayıtta ZAFER sayısı tutulur). Düşman gücü katlar boyunca sürekli artar (`progress`: kat başına 4 savaş odası); dükkân rafı kat ilerledikçe pahalanır ve Nadir eşya sıklaşır, ama **Efsanevi/Lanetli eşya dükkâna hiç düşmez** (en değerli eşyalar Gölge ödülünden gelir; `items/shop_stock.gd`). Eski (sürümsüz) kayıtlar yeni yapıya aynı ilerlemeyle aktarılır. Eski "tek sonsuz şerit" davranışı yalnız testlerde (`floors_enabled = false`) kalıyor; asıl sonsuz kip ayrı bir mod olarak gelecek.
**Öğretici (kat 1)** (`game/tutorial.gd`, `levels/tutorial_guide.gd`, `ui/tutorial_hint.gd`): kat 1 oyunu öğretir. Lobide ekranın üstündeki panel tuş ikonlarıyla sırayla gösterir: **A/D koş → W/Space zıpla → Shift dash → J saldır (3 kez) → sağdaki kapıya ilerle** (sırası gelmeden yaptığın beceri atlanır). Savaş odaları elle yazılmıştır: düşmanlar **tek tek** gelir (ilk ikili yalnız 5. odada), yavaştır (hız düşük, uyarı ve toparlanma uzun) ve ilk derslerde **yalnız altın** saldırı yapar: oda 2 = Taurus ile parry, oda 3 = altın mermi (Sagitta) → **kırmızı** saldırı (dash dersi) → karışık, oda 4-5 = karışık ve ilk ikili. Altın uyarı çıkınca "K = PARRY" ipucu, kaçırınca "tekrar dene", parry sonrası "J = VUR", kırmızı uyarıda "SHIFT = DASH" (3 kez gösterilir ya da dash ile savuşturunca biter). Hepsi yapılınca (ya da kat 1 bitince) profile işlenir (`tutorial_done`) ve ipuçları bir daha çıkmaz; kat 1'in tek tek/yavaş akışı her koşuda kalır. Yeni profil açarak öğreticiyi yeniden görebilirsin.

**Gölge (Umbra) patronu** (`actors/enemies/umbra.gd`, `game/umbra_kit.gd`, `ui/boss_bar.gd`): her katın 6. odasında Umbra'yla dövüşülür. Umbra **her katta bir yeni yetenek** kazanır (öncekileri de korur); kat ilerledikçe canı ve hızı artar, hamle arası beklemesi kısalır, kırmızı (parry'lenemez) saldırı payı büyür. Ekranın üstünde **boss can barı** durur (adı, o katın yeni yeteneği, 18. katta yarı can çentiği); dövüş başında yeni yetenek duyurulur. Altın uyarı = parry'le, kırmızı uyarı = dash ile kaç (her hamle bu kurala uyar).

| Kat | Yeni yetenek | Kat | Yeni yetenek |
|---|---|---|---|
| 1 | **Bıçak** (yakın dövüş) | 10 | **Üçlü kombo** (sonuncusu kırmızı) |
| 2 | **Fırlatma** (altın bıçağı parry'lersen geri döner) | 11 | **Sürü** (çok minyon) |
| 3 | **Duvar tırmanışı** (tepeden atlar) | 12 | **Dönen bıçaklar** |
| 4 | **Minyon çağırma** | 13 | **Gizlenme** (neredeyse görünmez) |
| 5 | **Gölge adımı** (arkandan çıkar) | 14 | **Duvardan atış** (tepeden üç bıçak) |
| 6 | **Üçlü fırlatma** (yelpaze) | 15 | **İkinci nefes** (canı bitince bir kez kalkar) |
| 7 | **Yer darbesi** (şok dalgaları) | 16 | **Gölge klonu** (biri altın, biri kırmızı vurur) |
| 8 | **Zırh** (hazırlıkta yalnız parry bozar) | 17 | **Karşı duruş** (vurursan karşılık verir) |
| 9 | **Bıçak yağmuru** | 18 | **Gerçek dövüş** (hepsi bir arada, yarı canda 2. evre) |

Ayrıntılar: arka arkaya 3 sersemletme alırsa 1.5 sn zırhlanır (sonsuz sersemletme yok); parry'yi ıskalarsan hemen cezalandırır; seçmeyip bıraktığın eşyaların sayısal etkilerini (can, hasar, hız) kendine alır; kamera Gölge uzaktayken (örn. karşı duvarda asılıyken) açılıp ikinizi birden gösterir (`ShakeCamera` patron çerçevesi).

**Gölge ödülü: 2 eşyadan 1** (`game/reward_choice.gd`, `levels/reward_stand.gd`, `ui/reward_menu.gd`): 18. kat dışında Gölge yenilince odanın ortasında **iki sunak** yükselir, her birinin üstünde bir eşya süzülür. Yaklaşıp `E` → ödül menüsü (oyun durur): ←/→ ya da A/D gezin, `Enter`/`E`/`J` ya da seçiliye ikinci tıklama **alır**, `Esc` kapatır (sonra yine seçebilirsin). **Seçmediğin eşya Gölge'nin olur** ve sonraki katlarda sana karşı kullanılır (menü "bunu alırsan Gölge şunu alır" bedelini gösterir; "Sadece Oyuncu" eşyalar Gölge'ye gitmez, yok olur). **Kat geçidi seçim yapılana kadar kapalı** kalır; seçince açılır ve koşu bir sonraki katın lobisinden kaydedilir. Eşyalar, sahip olduğun ve Gölge'nin elindekiler dışından, aynı koşu tohumuyla hep aynı çift olarak gelir; Efsanevi eşya kat ilerledikçe sıklaşır (1. katta ağırlık 0,4 → 9. katta tam; `ItemDB.roll_pair`). Son katta (18) ödül yoktur, zafer vardır. Sunakların ve Gölge elinin çizimleri `altar_rise/idle/take/dim` ve `fx_umbra_grab` adlarıyla `assets/` altına konunca kendiliğinden kullanılır. Ekran görüntüsü: `res://tools/screenshots_reward.tscn`.

**Silahlar** (`items/weapon_db.gd`, `items/weapon_loadout.gd`, `combat/aiming.gd`, `combat/sling_stone.gd`, `ui/weapon_bar.gd`): Cuphead gibi birden çok saldırı türü. İki silah slotu vardır: **J** (birinci) ve **I** (ikinci); ekranın altında ortada iki **silah kartı** (tuş, ad, seviye, sapanın beklemesi) durur. Koşu **KILIÇ** (J) ve **SAPAN** (I) ile başlar; **YUMRUK** dükkândan alınır. Silahı istediğin slota envanter ekranından (`Tab`) takarsın (iki yakın silahı birlikte de taşıyabilirsin). Her silahın **5 seviyesi** vardır; seviye **dükkândan** satın alınır (her silah için raf teklifi: yükseltme ya da henüz yoksa yeni silah; kat başına silah başına tek yükseltme, fiyat kat zammıyla artar) ve her seviye kendi tam değerlerini taşır (tablo `WeaponDB.DATA`).

| Silah | Tür | Özellik |
|---|---|---|
| **KILIÇ** | yakın | Dengeli üçlü kombo, son vuruş ağır ve geniş. Seviyeler: hasar, menzil +%20, hız +%15, vuruş alanı + geri itme |
| **YUMRUK** | yakın | Çok hızlı **dörtlü** kombo, kısa menzil, son vuruş sert (öne atılır). Aynı yükseltme çizgisi |
| **SAPAN** | menzilli | Baktığın yöne (sağ/sol, **yukarı**, **çapraz**) taş fırlatır; taş parry'lenmez, duvara çarpınca durur, zaman durunca (Satürn'ün Kum Saati) bile uçar. Seviyeler: daha sık, 2 hasar, **delici** (iki düşmana vurur), **çift taş** |

**Süperteknolojik Nişangâh** (kafa, Nadir): sapan taşları menzildeki en yakın düşmana kendiliğinden yönelir (hareketini de hesaba katarak); yukarı/aşağı tuşuna basarsan nişanı sen yönetirsin. **Gölge** bu eşyayı alırsa fırlattığı bıçaklar sana doğru hafifçe yön değiştirir. Silahlar koşu kaydına işlenir (kaldığın yerden devam edince aynı silahlar, seviyeler ve slotlar gelir).

**Sınırsız kip** (`levels/endless.gd`): tek geniş arena (3000 px, 7 platform), bitmeyen dalgalar. Düşman sayısı `2.5 + 1.2 * dalga^0.8` (1. dalga 3, 10. dalga 10, 100. dalga 50) ve güçleri `EnemyScaling` ile büyür; ekranda aynı anda en çok 4..10 düşman olur (dalga parçalara bölünür). Scorpius 4. dalgada gelir, dalganın en çok %40'ı olur. 5/10/25/50/75/100. dalgalar bitince ortada dükkân açılır; hazır olunca arenanın sağ ucundaki ışık sütununa yürüyerek sonraki dalga başlar. Her 3. dalgada 1 can yenilenir. Koşu her dalga başında kaydedilir (menüden DEVAM), rekor "en iyi dalga" olarak tutulur. **Not:** bu bölüm Godot erişimi olmayan bir ortamda yazıldı; testleri (`sinirsiz_matematik`, `sinirsiz_akis`) ilk fırsatta çalıştır.

**Duvar sekmesi:** yalnız Reçineli Eldivenler (`resin_gloves`) takılıyken. Havada duvara doğru basılı tutarsan yavaş kayarsın; Space ile duvardan karşı yöne sekersin (kısa süre yatay girdi kilitli). Animasyonlar `sidera_wall_slide`, `sidera_wall_jump`. Testi `duvar_sekmesi`; **henüz çalıştırılmadı** (Godot yok).

Sıradaki: plan belgesi, sprite bağlama denetimi, son doğrulama.

**Yazı tipi**: oyun **Fraunces** (SIL OFL) kullanıyor: Times'ın klasik "Roman" serif iskeleti ama yumuşak/tombul, biraz çizgi film afişi gibi. Türkçe harflerin tamamı var (Ğ ğ Ş ş İ fontun kendi parçalarından eklendi). Tek yerden okunur: `ui/game_font.gd` `PATH` + proje ayarı `gui/theme/custom_font`; ayrıntı ve değiştirme adımları `assets/fonts/README.md`. Eski AGENTORANGE projeden çıkarıldı (lisansı belirsizdi; artık depoyu bu açıdan herkese açmak engel değil).

## Sprite eklemek

Çizimi `assets/` altında **herhangi bir klasöre** koymak yeterli, kod değişmez; **dosya adı** önemlidir (`sidera_walk.png`, `taurus_lunge.png`, `item_viper_fang.png`, `ui_logo.png`...). Tam liste (ad, boyut, kare sayısı, süre, ne zaman oynar) `art/art_manifest.gd` içindedir; doküman halini `tools/export_art_list.tscn` üretir. Kurallar: [`docs/SPRITES.md`](docs/SPRITES.md)

## Geliştirici notları

Otomatik testler (Godot kurulu olmadan editör açmaya gerek yok):

```
godot --headless --fixed-fps 60 --path . res://tests/test_runner.tscn
# sadece belirli testler (isim kalıplarını virgülle ayır):
godot --headless --fixed-fps 60 --path . res://tests/test_runner.tscn -- hitstop,animasyon
```

Ekran görüntüsü alma (sanal ekranla):

```
xvfb-run -a -s "-screen 0 1280x720x24" env LIBGL_ALWAYS_SOFTWARE=1 \
  godot --path . --rendering-driver opengl3 --fixed-fps 60 res://tools/screenshots.tscn -- /cikti/klasoru
# oda sistemi için: res://tools/screenshots_run.tscn
# envanter ekranı, F5 menüsü ve duraklatma menüsü için: res://tools/screenshots_menus.tscn
# ana menü ekranları için: res://tools/screenshots_main_menu.tscn
# katlar, dükkân, Gölge odası, kat geçidi, zafer için: res://tools/screenshots_floors.tscn
# öğretici ipucu paneli (lobi adımları, parry, kırmızı uyarı) için: res://tools/screenshots_tutorial.tscn
# Gölge dövüşü (can barı, uyarılar, duvar tırmanışı, yer darbesi, klon, 2. evre) için: res://tools/screenshots_umbra.tscn (~4 dk; 2. argüman bölüm süzer: kat1, kat7...)
# Gölge ödülü (sunaklar yükselirken/hazır, ödül menüsü, çanta dolu, seçim sonrası) için: res://tools/screenshots_reward.tscn (~2 dk; 2. argüman = kat)
```

Gerçek tuş girdileriyle uçtan uca duman testi (menü -> yeni kayıt -> oyun -> duraklatma -> ana menü -> devam; ekransız çalışır, betik hatalarını yakalar):

```
godot --headless --fixed-fps 60 --path . res://tools/e2e_flow.tscn
```

Betik derleme kontrolü (tüm `.gd` dosyalarını yükler, hata varsa listeler):

```
godot --headless --path . res://tools/check_scripts.tscn
```

Yeni `class_name` eklediysen önce `godot --headless --path . --import` çalıştır.

Geçici ses efektleri `tools/make_sfx.py` ile üretilir.

Kamera ayarları `fx/shake_camera.gd` dosyasının en üstündeki `@export` değişkenlerinde (zoom `base_zoom`, takip hızı `follow_speed`, öne bakış `look_ahead` vb.). Kombo süresi oyuncunun `combo_window` değeridir (`actors/player/player.gd`, varsayılan 1 sn).

## Hikâye altyapısı (testler Godot'ta henüz koşulmadı)
- `game/story.gd`: kayıtlı hikâye bayrakları (`SaveSlot.story`), koşul dili (`a,!b`, `a|b`).
- `game/dialogue.gd`: konuşma düğümleri (metin, seçenek, `set`, `if`); `ui/dialogue_menu.gd`: konuşma kutusu (E/Enter/Boşluk/J ilerler, Yukarı/Aşağı seçer, Esc kapatır).
- `levels/npc.gd` + `game/npc_talk.gd`: konuşulabilen karakterler; lobide Fener Bekçisi Mira. Çizim adı `npc_<id>_idle`.

## Ara oda, sandıklar, hikâye (testler Godot'ta henüz koşulmadı)
- Her lobide "ARA ODA" kapısı (`SideDoor`, E ile girilir). Kararma altında dünyanın solundaki `SideRoom`'a geçilir: perdeye göre bir karakter (Tellal / Kırık Ayna / Terazi Yaşlısı / Su Taşıyıcı / Umbra), çıkış kapısı. Düşman ve sandık yok.
- `Chest`: türler gold / item / heal / rich; para saçar (`Coin.drop`), eşya verir. Açılanlar `Chest.opened_ids`'te, koşuyla birlikte kaydedilir. Sandıklar savaş odalarına serpiştirilir (oda başına %65 bir, %25 ek ikinci; lobide %50). Ara odada sandık yok, yalnız karakter.
- `NpcTalk`: Mira her kat farklı anlatır (18 parça) ve perdeye göre cevap veren konular sunar; ara oda karakterlerinin her kat için konuşması ve altın hediyeleri (`gold` + `gold_flag`) vardır.
- Testler: `hikaye_metni`, `ara_oda`, `ara_oda_gecis`.

## Demo / deneme tuşları
- **F8**: yaratık çağırma menüsü (11 yaratık, Enter ile önüne çağırır, menü açık kalır). **K** ya da **F6**: odadaki herkesi öldür ve odayı temizle. F5: eşya menüsü, F7: sonraki kat.
- Yengeç/Koç önden-arkadan ayrımı artık saldıranın konumuna bakar (dibine girince hitbox arkaya taşsa da önden sayılır).

## Bulmaca odaları (testler Godot'ta henüz koşulmadı)
- Kat 1 hariç Hangi odanın bulmaca olduğu `game/story_floors.gd`'te statik yazılı (0-2 bulmaca/kat; kat 1 öğretici) (sıra 2) **düşmansız bir bulmaca odasıdır**: lobi, savaş, **bulmaca**, savaş, savaş, Gölge. Kapı bulmaca çözülünce açılır. Tür kata göre seçilir (`PuzzleLogic.kinds_for`), tohuma bağlı sabittir (`RunController.puzzle_kind_of`). 180 sn takılırsan kilit gevşer (ödül ve kırıntı yok).
- Türler: **parry** (kule altın mermi atar, parry'le, mermi kuleye döner ve kristali yakar), **stars** (gösterilen yıldız sırasını kılıçla tekrarla), **simon / yıldız yankısı** (sıra tek tek büyür), **balance** (iki kule, iki kristal aynı anda yanık), **parkur** (platformlardaki 6 basınç plakasına süre dolmadan bas), **mix** (parry + yıldız sırası birlikte).
- Çözünce kilitli ödül sandığı açılır ve ilk kez çözülen katta **Yıldız Kırıntısı** kazanılır (`Story` bayrağı `shard_f<kat>`, sayaç `shards`; Mira sorulunca sayıyı söyler).
- Yerleşimler: `bulmaca_duz` (2000 px düz), `bulmaca_parkur` (2400 px, 6 platform). Savaş havuzunda yoktur. Test: `bulmaca`.

## Hikâye zenginleştirme (testler Godot'ta henüz koşulmadı)
- **Gölge'nin kat sonu sözleri:** her Gölge yenilgisinden sonra (kat 1-17) kısa bir konuşma açılır (`NpcTalk.umbra_after`). `RunController.story_enabled = false` ile kapatılır (testler kapatır).
- **Üç son** (`NpcTalk.ending_dialogue`, son kat Gölge'sinden sonra, zafer ekranından önce): "Seni yendim" (`ending=yen`), "Seni de götürüyorum" (`ending=tutulma`) ve 17 Yıldız Kırıntısının hepsi toplandıysa seçimsiz gizli son (`ending=birlikte`). Bayraklar `Story`'de, kayıt dosyasında kalır.
- **Mira ikinci sayfa:** "Düşmanlar hakkında?" (her perde için oynanış ipucu), "Bulmaca odaları?" (her türün nasıl çözüldüğü), "Yıldız kırıntıları" (sayıyı söyler).
- Test: `hikaye_son`.


## Undertale tarzı etkileşim
- `Prop` (levels/prop.gd): odalarda E ile bakılan esprili eşyalar, `TEXTS` sözlüğünden satır.
- Q = iptal (konuşmada yazıyı bitirir / `"cancel": true` seçeneğini seçer), E = onay.
- `StoryFloors.SLIME_FLOORS` lobilerinde slime: "Dokunmak ister misin?" -> +10 DOPAMİN (`Story` bayrağı `dopamin`).
- Etiketsiz kapılar (`StoryFloors.SECRETS`): savaş odasında yazısız kapı, oda temizlenince girilir. `key` = parkur (fırlatıcı) sonunda anahtar, alınmadan odanın kapısı açılmaz; `treasure` = iki sandıklı oda. İp sallanması / çöken platform henüz yok.
- Su baskını (`FloodEvent`, `StoryFloors.FLOOD_FLOORS` = kat 4; olay çizelgesi: her olay hikâyede bir kez — kat 4 sonu su baskını, kat 5 lobisi slime, kat 9 yazı-tura, kat 13 anket): Gölge ödülü alınınca su yükselir, geçit basamakların tepesine taşınır; su tepenin altında durur. Sonraki kat lobisinde slime olayı. Çukur çizimi henüz yok: geçit kapısı olarak görünür.
- **Etkileşim hakemi** (`game/interact.gd`): Npc, Prop, Chest, SideDoor ve ShopStand `interactables` grubuna girer; birden çok alandaysan YALNIZ yatayda en yakın (ve `can_interact()` olan) çalışır ve "E" ipucunu o gösterir. Açılmış sandık sırayı çalmaz. Yeni etkileşimli nesne eklerken: gruba gir, `in_range` ve `can_interact()` sun, E işleyicisine `Interact.is_best(self)` ekle.
- **Lobi** 2100 px (dükkân x=1000). Soldan sağa: başlangıç, olay karakteri/slime (x=330), Mira (580), dükkân (1000), sandık (1230, %50), esprili eşyalar, ara oda kapısı (1890).
- **Esprili eşya** (`Prop`): lobide 2, kat 2+ savaş odalarında 1 (kat 1'de yok: öğretici bozulmasın), her savaş odasının sağ kapısına görünmez "bak" alanı (`Prop.attach`). Türün ilk bakışında +1 DOPAMİN. Her tür koddan çizilmiş siluet gösterir; `prop_<tür>` çizimi gelirse o kullanılır.
- **Olay çizelgesi** (`game/story_floors.gd`): kat 4 sonu su baskını (çukur geçidi) → kat 5 lobisi slime; kat 7 sonu altın yağmuru (`GoldRainEvent`); kat 3 lobisi Kule Kemancısı (sessiz parça, 3 altın bahşiş); kat 9 lobisi Umbra'nın yazı-turası; kat 12 lobisi Kuru Balıkçı (çorba = 2 can); kat 10 sonu taş yağışı (`RockfallEvent`, zeminde kırmızı uyarı, altında kalırsan 1 can); kat 11 sonu ışıkların sönmesi (`BlackoutEvent`, yalnız çevren görünür, karanlıkta 3 antika para); kat 13 lobisi Bozuk Asansör anketi; kat 15 lobisi Umbra'nın doğum günü (pasta = tam can, konfeti). Kat sonu olayları `StoryFloors.END_EVENTS` + `RunController.start_end_event()` ile; Gölge ödülü alınınca başlar. Kat adları (`FLOOR_TITLES`) kat kartında altyazı.
- **Efektler**: `AmbientFx` (her odada kata göre toz / kıvılcım / yağmur / kül; `THEMES`), `DustFx` (iniş, zıplama, dash tozu), `ConfettiFx` (konuşma düğümünde `fx: "confetti"`). Hepsi CPUParticles2D. Testi `yeni_olaylar`; **henüz çalıştırılmadı**.
- **Konuşma kapanırken** E basışı konuşmayı yeniden açmasın diye `GameMenu.close()` etkileşimi birkaç fizik karesi kilitler (`Interact.block()/blocked()`). Lobideki etiketli "ARA ODA" kapısı kapalı (`RunController.lobby_side_door`); gizli etiketsiz kapılar sürüyor.
- **Gizli konuşma odaları** (`StoryFloors.SECRETS` değeri `"talk:<npc>"`): kat 3 Nöbetçi Kedi (sev: +1 can, +10 dopamin), kat 8 Kira Faresi (5 öde, 12 kazan), kat 11 Kayıp Eşya Memuru. Karakterler `game/npc_extra.gd` içinde.
- **Konuşma düğümü anahtarları** (`DialogueMenu`): `gold`/`gold_flag`, `dopamin`/`dopamin_flag`/`dopamin_repeat`, `heal`/`heal_flag`, `sfx`, `set_before` (düğüme GİRİNCE bayrak; Esc ile erken çıkış ödülü tekrar kazandırmasın diye), seçenekte `cancel` (Q), `pay` + `fail`.
- Yeni testler: `etkilesim_hakemi`, `olay_cizelgesi`, `konusma_dugumleri`, `parkur_ogeleri`.
