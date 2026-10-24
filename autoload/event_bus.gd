extends Node
## Global sinyal merkezi. Sistemler birbirine doğrudan bağlanmak yerine buradan haberleşir.
## Eşyalar (Aşama 3) bu sinyallere abone olarak çalışacak.

@warning_ignore("unused_signal")
signal parry_success(actor: Node, hitbox: Node)
@warning_ignore("unused_signal")
signal parry_failed(actor: Node)
@warning_ignore("unused_signal")
signal dash_used(actor: Node)
@warning_ignore("unused_signal")
signal damage_dealt(target: Node, amount: int, source: Node)
@warning_ignore("unused_signal")
signal actor_died(actor: Node)
@warning_ignore("unused_signal")
signal enemy_died(enemy: Node)
@warning_ignore("unused_signal")
signal screen_shake(strength: float, duration: float)
## Kamerayı bir yöne iter (yay gibi geri döner). Vuruşun yönünü hissettirir.
@warning_ignore("unused_signal")
signal camera_kick(direction: Vector2, strength: float)
## Kameranın kısa süre yakınlaşıp geri dönmesi (parry vb.). amount: 0.03 = %3.
@warning_ignore("unused_signal")
signal camera_punch(amount: float)
## Tüm ekranı kısa süre boyar (hasar = kırmızı, parry = altın). alpha: en parlak anındaki opaklık.
@warning_ignore("unused_signal")
signal screen_flash(color: Color, alpha: float, duration: float)
## Oyuncu yeni bir odaya girdi (kapı arkasından kapandı). index: 0'dan başlar.
@warning_ignore("unused_signal")
signal room_entered(index: int)
## Odadaki son düşman öldü, sağdaki kapı açıldı.
@warning_ignore("unused_signal")
signal room_cleared(index: int)
## Kombo her vuruş/parry'de güncellenir; süre dolunca biter (sayaçlar sıfırlanır).
@warning_ignore("unused_signal")
signal combo_updated(hits: int, parries: int, damage: int)
@warning_ignore("unused_signal")
signal combo_ended(hits: int, parries: int, damage: int)
## Oyuncu bir saldırıyı dash'in dokunulmazlık karelerinde savuşturdu (agresiflik ödülü).
@warning_ignore("unused_signal")
signal dodge_success(actor: Node, hitbox: Node)
## Bir aktör can kazandı.
@warning_ignore("unused_signal")
signal healed(actor: Node, amount: int)
## Ritim (agresiflik) metresi değeri değişti.
@warning_ignore("unused_signal")
signal rhythm_changed(value: float, tier: int)
## Ritim kademesi değişti (0 Soğuk, 1 Isınmış, 2 Ateşli, 3 Coşkulu).
@warning_ignore("unused_signal")
signal rhythm_tier_changed(tier: int, previous: int)
## Oyuncu bir eşya aldı.
@warning_ignore("unused_signal")
signal item_acquired(actor: Node, item: ItemData)
## Seçilmeyen eşya Umbra'ya gitti.
@warning_ignore("unused_signal")
signal item_left_behind(item: ItemData)
