# Sprite rehberi

Kod hazır: PNG'leri doğru klasöre, doğru isimle koyunca oyun **kendiliğinden** kullanır. Kod değiştirmen gerekmez.

## Nasıl çalışır

1. PNG'leri `assets/sprites/<karakter>/` klasörüne at (`sidera`, `taurus`, `sagitta`, `scorpius`).
2. Godot'u aç (yeni dosyaları kendisi içe aktarır) ve oyna.
3. Bir animasyonun PNG'si yoksa yedeğine düşer (aşağıdaki tablolarda "yedek" sütunu). Klasörde hiç PNG yoksa şimdiki renkli kutular görünür.

Her animasyon için iki biçimden **biri** kabul edilir:

| Biçim | Örnek |
|---|---|
| Yatay şerit (kareler yan yana) | `run.png` (6 kare, 64x64 ise 384x64) |
| Numaralı tek kareler | `run_0.png`, `run_1.png`, `run_2.png` ... |

## Çizim kuralları

- **Aynı animasyondaki tüm kareler aynı boyutta olmalı.** Şeritte kare genişliği = görüntü yüksekliği (kare kare). Kare kare değilse bana söyle, kare genişliğini kodda ayarlarım.
- **Yön:** Karakterler **sağa bakacak** şekilde çizilir. Oyun sola dönünce kendisi aynalar (düşmanlar da sağa bakacak şekilde çizilir).
- **Hizalama:** Karenin **alt orta noktası** karakterin ayakları olur (çarpışma kutusunun altı). Karakteri karenin altına yasla, ayaklar alt kenara değsin.
- **Boyut önerisi:** Çarpışma kutuları: oyuncu 26x52, Taurus 34x54, Sagitta 30x50, Scorpius 30x52 piksel. Kare olarak 64x64 rahat eder (karakter ortada, başın üstünde birkaç piksel boşluk). Kılıç savurması gibi geniş hareketler için 96x96 da olur, ama hepsi aynı boyutta olmalı.
- **Piksel art:** Proje keskin (nearest) filtreleme kullanıyor, bulanıklaşmaz.
- **Hız (fps) ve döngü** kodda ayarlı, kare sayın farklıysa sorun değil. Hızları sonra birlikte ince ayar yaparız.
- **Saldırı animasyonları** saldırının süresine otomatik uydurulur (hızlanır/yavaşlar). Öneri: ilk ~%20 hazırlık, %20-%55 vuruş anı, kalanı toparlanma.

## Sidera (oyuncu): `assets/sprites/sidera/`

| Dosya | Ne zaman oynar | Döngü | Önerilen kare | Yedek |
|---|---|---|---|---|
| `idle` | duruyor | evet | 4-6 | (yok, temel) |
| `run` | koşuyor | evet | 6-8 | idle |
| `jump` | havada yükseliyor | hayır | 2-3 | idle |
| `fall` | havada düşüyor | evet | 2 | jump |
| `dash` | dash (0.16 sn) | hayır | 3-4 | run |
| `attack1` | 1. kombo vuruşu (~0.28 sn) | hayır | 4-6 | idle |
| `attack2` | 2. kombo vuruşu (~0.28 sn) | hayır | 4-6 | attack1 |
| `attack3` | 3. ağır vuruş (~0.45 sn) | hayır | 5-8 | attack2 |
| `parry` | parry penceresi (0.12 sn) | hayır | 2-3 | idle |
| `parry_fail` | parry'yi kaçırınca toparlanma (0.35 sn) | hayır | 3 | idle |
| `hurt` | hasar alınca (0.22 sn) | hayır | 2 | idle |
| `death` | ölüm (son karede kalır) | hayır | 5-8 | hurt |

## Düşmanlar: `assets/sprites/taurus/` (Taurus) ve `assets/sprites/sagitta/` (Sagitta)

İkisi de aynı isimleri kullanır, her düşmanın kendi klasörü olur. Scorpius da aynı tabloyu kullanır, ayrıca ek animasyonları vardır (aşağıda).

| Dosya | Ne zaman oynar | Döngü | Önerilen kare | Yedek |
|---|---|---|---|---|
| `idle` | bekliyor | evet | 4 | (yok, temel) |
| `run` | yürüyor | evet | 6 | idle |
| `jump` | zıplıyor (Taurus platforma çıkarken) | hayır | 2 | idle |
| `fall` | düşüyor | evet | 2 | jump |
| `telegraph` | saldırı hazırlığı (Taurus 0.55 sn, Sagitta 0.45 sn) | hayır | 4 | idle |
| `attack` | atılma (0.28 sn) veya ateş etme (0.35 sn) | hayır | 3-4 | telegraph |
| `recover` | atılma sonrası toparlanma (0.85 sn) | hayır | 3 | idle |
| `stun` | parry sonrası sersemleme | evet | 2-4 | hurt |
| `hurt` | vurulunca | hayır | 2 | idle |
| `death` | ölüm (bitince söner) | hayır | 5-7 | hurt |

## Scorpius ek animasyonları: `assets/sprites/scorpius/`

Yukarıdaki düşman tablosundaki isimlerin hepsi geçerlidir (`idle`, `run` = yürüyüş, `jump`, `fall`, `telegraph` = dürtüş hazırlığı, `attack` = dürtüş, `recover`, `stun`, `hurt`, `death`). Bunlara ek olarak:

| Dosya | Ne zaman oynar | Döngü | Önerilen kare | Yedek |
|---|---|---|---|---|
| `backflip` | rakip fazla yaklaşınca geriye takla/sıçrayış (0.42 sn) | hayır | 5-6 | jump |
| `retreat` | dürtüşten hemen sonra geriye süzülüş (0.34 sn) | hayır | 3-4 | run |
| `vanish` | sahte hamleye kanınca kaybolma (0.1 sn) | hayır | 2-3 | attack |
| `stab_telegraph` | rakibin arkasında kısa hazırlık (0.2 sn) | hayır | 2-3 | telegraph |
| `stab` | sırttan vuruş (0.1 sn) | hayır | 2-3 | attack |

`attack` karesi **uzun bir rapier uzanışı** olmalı: dürtüş çizgisi karakterin önünde yaklaşık 112 piksel uzar. Karenin 96x96 veya daha geniş olması iyi olur.

## Eşya simgeleri: `assets/items/`

Her eşyanın simgesi `assets/items/<eşya_id>.png` olarak konur (tek kare, kare olması önerilir; envanter kutusuna sığdırılır, ~64x64 uygun). Dosya varsa envanter ekranı ve F5 menüsü onu kendiliğinden kullanır, yoksa eşyanın baş harfi (yer tutucu) görünür. Kod değişmez.

| Dosya adı | Eşya |
|---|---|
| `mirror_boots.png` | Ayna Tabanlı Çizmeler |
| `feather_boots.png` | Hafif Tüy Botlar |
| `viper_fang.png` | Engerek Dişi Kolyesi |
| `stardust_brooch.png` | Yıldız Tozu Broşu |
| `vampire_relic.png` | Vampir Yadigarı |
| `guardian_helm.png` | Antika Muhafız Kaskı |
| `watcher_band.png` | Gözcü Bandı |
| `cracked_mirror.png` | Çatlak El Aynası |
| `saturn_hourglass.png` | Satürn'ün Kum Saati |
| `thief_chain.png` | Hırsızın Zinciri |
| `tower_bread.png` | Kule Ekmeği |
| `baked_sweet_potato.png` | Fırınlanmış Tatlı Patates |
| `cosmic_star_soup.png` | Kozmik Yıldız Çorbası |

Envanter ekranındaki karakter (ortadaki figür) `assets/sprites/sidera/idle` karesini 3 kat büyütüp gösterir; PNG yoksa yer tutucu kutu çizilir.

## Koddan çizilenler (şimdilik)

Altın elmas uyarısı (sadece parry'lenebilir saldırılarda; kırmızı saldırıda sembol yok, sadece kırmızı parıltı), mermiler, parry halkası, vuruş kıvılcımları, dürtüş izi ve kılıç izi koddan çiziliyor. İstersen bunları da sonra PNG'ye çeviririz.
