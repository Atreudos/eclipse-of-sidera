# Fontlar

## FrauncesTR-SemiBold.ttf (oyunun yazı tipi)

- Asıl yazı tipi: **Fraunces** (Undercase Type, "The Fraunces Project Authors"), SemiBold ağırlığı. Lisans: **SIL Open Font License 1.1**
  (`Fraunces-OFL.txt`). Oyunda gömülü kullanılabilir, dağıtılabilir; yalnızca tek başına satılamaz ve lisans metni yanında durmalı.
- Neden: Times'ın klasik "Roman" serif iskeleti ama yumuşak, tombul ve biraz çizgi film afişi gibi. Çok ciddi değil, Times New Roman kadar sıkıcı da değil.
- Bu dosya **değiştirilmiş** bir kopyadır (OFL buna izin verir; adı "Fraunces TR" yapıldı): Latin alt kümesinde olmayan **Ğ ğ Ş ş İ**
  harfleri fontun kendi parçalarından (S/s + kedil, I + "i"nin noktası, G/g + özel çizilmiş breve) üretilip eklendi. Başka bir şey değişmedi.
  Türkçe karakterlerin hepsi var (ç ğ ı ö ş ü Ç Ğ İ Ö Ş Ü Â â), ayrıca `· × — – %` da var. Ok işaretleri (← →) yok; `GameFont._prep` bunları `<` `>` yapar.
- Font tek yerden okunuyor: `ui/game_font.gd` içindeki `PATH`; ayrıca proje ayarı `gui/theme/custom_font` (Label gibi hazır kontroller için).
- Fontu başka bir dosyayla değiştirmek istersen: dosyayı bu klasöre koy, `PATH` ve `custom_font`u güncelle, `godot --headless --path . --import` çalıştır.
- Krediler ekranında (`ui/menu/credits_screen.gd`) font satırı var.

### Eski font

Önceki yazı tipi AGENTORANGE (Jakob Fischer, pizzadude.dk) "yazarın izni olmadan dağıtma" notu taşıyordu; **projeden çıkarıldı**
(depo geçmişinde duruyor). Depoyu herkese açmak istersen geçmişi de temizlemen gerekir; yeni font bu açıdan sorunsuzdur.
