# Sprite rehberi

Kod hazır: PNG'leri `assets/` altına **listedeki adla** koyunca oyun **kendiliğinden** kullanır. Kod değiştirmen gerekmez.

Çizilecek her şeyin tam listesi (ad, kare boyutu, kare sayısı, süre, ne zaman oynar, "şart / isteğe bağlı", hangi pakette) tek yerde durur: **`art/art_manifest.gd`**. Doküman halini üretmek için:

```
godot --headless --path . res://tools/export_art_list.tscn -- /cikti/klasoru
```

## Nasıl çalışır

1. PNG'yi `assets/` altında **herhangi bir klasöre** koy (örn. `assets/sprites/sidera/sidera_walk.png`). Klasör önemsiz, **dosya adı** önemli. Aynı ad iki yerdeyse alfabetik ilk klasör kazanır.
2. Godot'u aç (yeni dosyaları kendisi içe aktarır) ve oyna.
3. Bir çizim yoksa oyun yedeğine ya da koddan çizilen yer tutucuya düşer; hiçbir şey bozulmaz. Çizimler tek tek, parça parça eklenebilir.

Ad kalıpları:

| Ne | Ad | Örnek |
|---|---|---|
| Karakter animasyonu | `<karakter>_<hareket>.png` | `sidera_walk.png`, `taurus_lunge.png`, `sagitta_shooting.png`, `umbra_windup.png` |
| Eşya / silah simgesi | `item_<id>.png` | `item_viper_fang.png`, `item_weapon_fist.png` |
| Efekt | `fx_<ad>.png` | `fx_sling_stone.png` |
| Arayüz | `ui_<ad>.png` | `ui_logo.png`, `ui_heart_full.png` |
| Dünya (tema başına) | `<tema>_<katman>.png` | `kat1_bg_far.png`, `lobi_floor.png` |

Hangi hareketin hangi dosya adına karşılık geldiği (örn. koddaki `run` hareketi `sidera_walk.png`) listede her satırda yazar.

## Çizim kuralları

- **Her animasyon yatay bir şerittir:** kareler yan yana, hepsi aynı boyutta. Karakter şeritlerinde kare genişliği = görüntü yüksekliği (kare kare; 96x96 önerilir, minyon 64x64). Diğer çizimlerde kare boyutu listede yazar (örn. eşya simgesi 64x64, 1-8 kare).
- **Yön:** Karakterler ve düşmanlar **sağa bakacak** şekilde çizilir. Oyun sola dönünce kendisi aynalar.
- **Hizalama:** Karakter karelerinde **alt orta nokta** ayaklardır (çarpışma kutusunun altı). Karakteri karenin altına yasla, ayaklar alt kenara değsin.
- **Çarpışma kutuları (bilgi için):** oyuncu 26x52, Taurus 34x54, Sagitta 30x50, Scorpius 30x52, Umbra 26x52, minyon 22x36 piksel. Çizim kutudan büyük olabilir (savurmalar, uzayan rapier), ama ayaklar hizalı kalmalı.
- **Piksel art:** Proje keskin (nearest) filtreleme kullanıyor, bulanıklaşmaz.
- **Hız (fps) ve döngü** listedeki süreye göre kodda ayarlı; kare sayın farklıysa sorun değil.
- **Saldırı animasyonları saldırının süresine otomatik uydurulur** (hızlanır/yavaşlar): silah seviyesi hızı artırınca da. Öneri: ilk ~%20 hazırlık, %20-%55 vuruş anı, kalanı toparlanma.
- **Animasyonu olmayan hareket yedeğine düşer:** örn. `sidera_punch3` yoksa `punch2` (o da yoksa `punch1`, sonra `attack1`), `sidera_throw_up` yoksa `throw`, `taurus_hurt` yoksa `idle`, `scorpius_vanish` yoksa `attack` oynar. Yedek zincirleri `ANIM_SPEC` tablolarındadır (`actors/player/player.gd`, `actors/enemies/*.gd`).

## Karakterler

Oyuncu **Sidera**, düşmanlar **Taurus**, **Sagitta**, **Scorpius**, patron **Umbra** (20 animasyon) ve Umbra'nın küçük **minyonu** (`umbra_minion_*`; Gölge Klonu da bunları kullanır, oyun mavimsi renk verir) için satırlar listededir. Sidera'nın silahları:

| Silah | Oynattığı animasyonlar |
|---|---|
| Kılıç | `sidera_attack1`, `sidera_attack2`, `sidera_attack3` |
| Yumruk | `sidera_punch1`, `sidera_punch2`, `sidera_punch3`, `sidera_punch4` |
| Sapan | `sidera_throw` (ileri), `sidera_throw_up` (yukarı), `sidera_throw_diag` (çapraz) + sapan taşı efekti `fx_sling_stone` |

Eski klasör yöntemi de hâlâ çalışır (listedeki adla bulunamazsa denenir): `assets/sprites/<karakter>/<koddaki hareket adı>.png`, örn. `assets/sprites/sidera/run.png`. Ya da numaralı tek kareler: `run_0.png`, `run_1.png`...

## Eşya ve silah simgeleri

`item_<id>.png` (animasyonlu şerit, 64x64 kareler; tek kare de olur). Envanter, dükkân, ödül menüsü ve ekranın altındaki silah kartları bunu kullanır. Silah simgeleri `item_weapon_sword.png`, `item_weapon_fist.png`, `item_weapon_sling.png`; dükkândaki silah yükseltme ve satın alma teklifleri de o silahın simgesini kullanır. Eski yer de çalışır: `assets/items/<id>.png` (tek kare).

Envanter ekranındaki karakter (ortadaki figür) `sidera_idle` karesini büyütüp gösterir; çizim yoksa yer tutucu kutu çizilir.

## Oyuna bağlı olanlar ve koddan çizilenler

Oyun şu çizimleri şu an kullanır: **tüm karakter animasyonları** (Sidera, düşmanlar, Umbra, minyon), **eşya ve silah simgeleri**, **ana menü, başlık, kayıt ve krediler ekranları** (`ui_menu_*`, `ui_logo`, `ui_slot_*`...), **lobi/dükkân** (`shop_counter`, `merchant_idle`, `shop_sign`), **Gölge ödül sunakları** ve **kat geçidi kapısı**, `fx_umbra_grab` ve `fx_sling_stone`.

Henüz koddan çizilen (çizim listede var ama oyuna bağlanması sırada olan) yerler: ekran göstergeleri (kalp, dash, altın, ritim ve zaman barı), envanter/dükkân/ödül çerçeveleri, dünya temaları (arka plan, zemin, platform, duvar), çoğu efekt (kılıç izi, vuruş kıvılcımı, parry halkası, mermiler, toz, doğuş sütunu...). Altın elmas uyarısı, mermiler, parry halkası, vuruş kıvılcımları, dürtüş izi ve kılıç izi şimdilik koddan çizilir.
