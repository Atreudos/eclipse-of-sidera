extends ItemEffect
## Aç Kapı (lanetli): hasar x2 (ItemDB'de), bedeli: Umbra her pusuda bir eşya fazla taşır (GameState).


func on_acquire() -> void:
	GameState.umbra_extra_carry += 1


func on_remove() -> void:
	GameState.umbra_extra_carry = maxi(GameState.umbra_extra_carry - 1, 0)
