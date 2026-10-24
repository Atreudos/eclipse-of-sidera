extends ItemEffect
## Hayalet Adım: dash sırasında düşman gövdelerinin içinden geçilir (oyuncu tarafı: Player.dash_ghost).


func on_acquire() -> void:
	owner.dash_ghost = true


func on_remove() -> void:
	owner.dash_ghost = false
