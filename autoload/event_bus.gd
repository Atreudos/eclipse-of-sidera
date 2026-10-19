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
