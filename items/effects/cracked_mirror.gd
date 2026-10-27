extends ItemEffect
## Çatlak El Aynası: canın sıfıra inen ölümcül darbeyi engeller, seni 1 canla kurtarır ve 2 sn ölümsüz yapar.
## Tek kullanımlıktır: kullanılınca kırılır (slottan düşer), yeniden takıp sıfırlanamaz.
## Gölge alırsa (Umbra dövüşü): canı sıfırlanınca 2. evresine geçer, tam canla dirilir.

const SURVIVE_HP := 1
const INVULN_TIME := 2.0


func on_acquire() -> void:
	owner.death_savers.append(_save)


func on_remove() -> void:
	owner.death_savers.erase(_save)


func _save() -> bool:
	owner.health = SURVIVE_HP
	owner.grant_invulnerability(INVULN_TIME)
	owner.velocity = Vector2(0.0, -260.0)
	owner.flash(Color(1.0, 1.0, 1.0), 0.4)
	RingFx.spawn(owner.get_parent(), owner.global_position, Color(0.75, 0.9, 1.0, 0.95), 14.0, 120.0, 0.45)
	RingFx.spawn(owner.get_parent(), owner.global_position, Color(1.0, 1.0, 1.0, 0.8), 8.0, 70.0, 0.3)
	EventBus.screen_flash.emit(Color(0.85, 0.95, 1.0), 0.5, 0.4)
	EventBus.screen_shake.emit(8.0, 0.3)
	Sfx.play("mirror_crack")
	EventBus.item_consumed.emit(owner, data)
	if owner.inventory != null:
		owner.inventory.destroy(data)  # kırıldı
	return true
