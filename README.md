# Eclipse of Sidera

2D, hikayesiz aksiyon roguelite. Godot 4.4 (GDScript).

**Sidera** (yıldız) olarak oynarsın; gölgen **Umbra** peşinde. Isaac gibi eşya build'i kurarsın, Ultrakill gibi parry/dash ile agresif dövüşürsün. Her ödül odasında 2 eşya çıkar: birini alırsın, **seçmediğini Umbra alır** ve sana karşı kullanır. Umbra'nın saldırılarını parry'lersen eşyalarını geri çalarsın.

Düşmanlar burç adlıdır: **Taurus** (koşup vuran boğa goblin), **Sagitta** (yılan okçu), **Scorpius** (rapier'li akrep).

Tasarım ve yol haritası: [`docs/PLAN.md`](docs/PLAN.md)

## Çalıştırma

1. Godot 4.4.x indir (standart sürüm, .NET gerekmez).
2. Godot'ta **Import** ile bu klasördeki `project.godot` dosyasını aç.
3. Editörde `F5` (ya da sağ üstteki ▶) ile oynat. (Oyunun içindeki `F5` başka işe yarar, aşağıya bak.)

## Kontroller (şimdilik)

| Tuş | İşlev |
|---|---|
| A / D veya ← / → | Koş |
| Space / W | Zıpla |
| Shift | Dash |
| K | Parry |
| J | Saldırı |
| F3 | Debug paneli (parry penceresi, dash hızı vb. canlı ayar) |
| R | Yeniden başla (ölünce ya da istediğin an) |
| F4 | **Deneme modu (god)**: can düşmez, dash ve parry bekleme yok. Tekrar basınca kapanır, ölüp yeniden başlasan da açık kalır |
| I / Tab | **Envanter ekranı**: karakter, slotlar, çanta. Oyunu durdurur. Yön tuşları/WASD/fare ile gez; Enter/E/J ya da tıkla: tak, çıkar, ye. Esc kapatır |
| F5 | **Eşya menüsü (deneme)**: listeden eşya seçip envantere ekler. Enter/E/J ekle, T yalnız çantaya, G +50 altın, H canı doldur, B +1 bağışıklık kalbi, C hepsini sil |
| F6 | Geliştirici kısayolu: bulunduğun odayı hemen temizle (oda akışını denemek için) |

Altın uyarı = parry'lenebilir. Kırmızı uyarı = parry'lenemez, dash ile kaç.

## Durum

Aşama 0 ve 1 tamam: hareket, zıplama, dash (i-frame + şarj), 3'lü saldırı kombosu, parry (altın/kırmızı saldırı ayrımı, hitstop, ses), iki düşman tipi (Taurus, Sagitta) ve test arenası.
Ek olarak: vuruş flaşı + kıvılcım, yumuşak ekran sarsıntısı/kamera tepmesi, hasar/parry ekran flaşı, üst platformlara çıkabilen düşmanlar ve sprite/animasyon altyapısı.
Dinamik kamera (oyuncuyu yumuşak takip, baktığı yöne önden bakış, hafif zoom-in; dash'te açılır, kombo uzadıkça yaklaşır), fontlu hasar sayıları, 1 sn'lik kombo barı (COMBO yazısı + vuruş/parry/hasar sayaçları) ve ekranı kaplayan parry dalgası + yeni parry sesi.
Oyun artık **oda sistemiyle** açılıyor (`levels/run.tscn`): odalar sağa doğru dizilir; düşmanlar ışık sütunuyla dalga dalga doğar, hepsi ölünce kapı açılır, sağa geçince kapı arkandan kapanır. Her odanın yerleşimi (platformlar) ve dalgaları tohuma bağlıdır; her 3 odada renk teması değişir. Ölünce özet ekranı çıkar (R ile yeniden başla). Eski test arenası `levels/test_arena.tscn` olarak duruyor.
Gövdeler katı: dash düşmanın içinden geçmez (çarpıp durur), birbirinizin başına düşerseniz yana kayarsınız. Kamera yukarı/aşağı da çok az oynar (zıplarken yükselir, düşerken aşağı bakar, sert inişte çöker).
Vuruş sersemletmesi: kombo yediği sırada düşman saldıramaz (hazırlığı iptal olur). Altın (parry'lenebilir) saldırılar seyrek, kırmızılar (kaçılacak) çoğunlukta; altın saldırıda sarı elmas, kırmızıda sadece kırmızı parıltı var.
**Scorpius** (3. düşman): mesafe oyunu oynar: fazla yakınsan geri takla atar, rapier menzilinde çok kısa bir altın uyarıyla ışık hızında dürtüp hemen geri çekilir. Bazen sahte dürtüş yapar: erken parry'lersen arkana ışınlanıp sırtından vurur, sakin kalırsan boşa gider. Gerçek dürtüşü tam zamanında parry'lersen 1.5 sn sersemler (tek güvenli hasar fırsatı). 3. odanın 2. dalgasından itibaren dalgalara karışır.
**Eşya sistemi** (Aşama 3'ün büyük kısmı): slotlar (ayak 1, charm 3, kafa 2, cep 1, bilek 1, zırh 1) + 24 hücrelik çanta + envanter ekranı (`I`) ve deneme için `F5` eşya menüsü. 10 donanım (Ayna Tabanlı Çizmeler, Hafif Tüy Botlar, Engerek Dişi Kolyesi, Yıldız Tozu Broşu, Vampir Yadigarı, Antika Muhafız Kaskı, Gözcü Bandı, Çatlak El Aynası, Satürn'ün Kum Saati, Hırsızın Zinciri) ve 3 yemek (Kule Ekmeği, Fırınlanmış Tatlı Patates, Kozmik Yıldız Çorbası). Fazla iyileşme mavi **bağışıklık kalbi** olur (bağışıklık kalbi varken yemek yenmez). Düşmanlar altın düşürür (sayaç HUD'da; harcama yeri mağaza). **Refleks** statı parry penceresini ölçekler. Satürn'ün Kum Saati: iki saldırıyı birlikte parry'lersen zaman 1.5 sn durur.
Sıradaki: ödül mezatı (2 eşya, seçmediğin Umbra'ya), **her katın başında mağaza**, Umbra ve yeni düşmanlar (ör. zırhlı bir 4. düşman).

## Sprite eklemek

Çizimleri `assets/sprites/<karakter>/` klasörüne koymak yeterli, kod değişmez. İsimler, boyutlar ve hizalama kuralları: [`docs/SPRITES.md`](docs/SPRITES.md)

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
# envanter ekranı ve F5 menüsü için: res://tools/screenshots_menus.tscn
```

Betik derleme kontrolü (tüm `.gd` dosyalarını yükler, hata varsa listeler):

```
godot --headless --path . res://tools/check_scripts.tscn
```

Yeni `class_name` eklediysen önce `godot --headless --path . --import` çalıştır.

Geçici ses efektleri `tools/make_sfx.py` ile üretilir.

Kamera ayarları `fx/shake_camera.gd` dosyasının en üstündeki `@export` değişkenlerinde (zoom `base_zoom`, takip hızı `follow_speed`, öne bakış `look_ahead` vb.). Kombo süresi oyuncunun `combo_window` değeridir (`actors/player/player.gd`, varsayılan 1 sn).
