# Left Behind

2D, hikayesiz aksiyon roguelite. Godot 4.4 (GDScript).

Isaac gibi eşya build'i kurarsın, Ultrakill gibi parry/dash ile agresif dövüşürsün. Her ödül odasında 2 eşya çıkar: birini alırsın, **seçmediğini Rakip alır** ve sana karşı kullanır. Rakip'in saldırılarını parry'lersen eşyalarını geri çalarsın.

Tasarım ve yol haritası: [`docs/PLAN.md`](docs/PLAN.md)

## Çalıştırma

1. Godot 4.4.x indir (standart sürüm, .NET gerekmez).
2. Godot'ta **Import** ile bu klasördeki `project.godot` dosyasını aç.
3. `F5` ile oynat.

## Kontroller (şimdilik)

| Tuş | İşlev |
|---|---|
| A / D veya ← / → | Koş |
| Space / W | Zıpla |
| Shift | Dash |
| K | Parry |
| J | Saldırı |
| F3 | Debug paneli (parry penceresi, dash hızı vb. canlı ayar) |
| R | Arenayı yeniden başlat |

Altın uyarı = parry'lenebilir. Kırmızı uyarı = parry'lenemez, dash ile kaç.

## Durum

Aşama 0 ve 1 tamam: hareket, zıplama, dash (i-frame + şarj), 3'lü saldırı kombosu, parry (altın/kırmızı saldırı ayrımı, hitstop, ses), iki düşman tipi (Teklifçi, Ateşçi) ve test arenası.
Ek olarak: vuruş flaşı + kıvılcım, yumuşak ekran sarsıntısı/kamera tepmesi, hasar/parry ekran flaşı, üst platformlara çıkabilen düşmanlar ve sprite/animasyon altyapısı.
Dinamik kamera (oyuncuyu yumuşak takip, baktığı yöne önden bakış, hafif zoom-in; dash'te açılır, kombo uzadıkça yaklaşır), fontlu hasar sayıları, 1 sn'lik kombo barı (COMBO yazısı + vuruş/parry/hasar sayaçları) ve ekranı kaplayan parry dalgası + yeni parry sesi.
Sıradaki: Aşama 2 (agresiflik metresi, oda sistemi, daha fazla düşman).

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
```

Geçici ses efektleri `tools/make_sfx.py` ile üretilir.

Kamera ayarları `fx/shake_camera.gd` dosyasının en üstündeki `@export` değişkenlerinde (zoom `base_zoom`, takip hızı `follow_speed`, öne bakış `look_ahead` vb.). Kombo süresi oyuncunun `combo_window` değeridir (`actors/player/player.gd`, varsayılan 1 sn).
