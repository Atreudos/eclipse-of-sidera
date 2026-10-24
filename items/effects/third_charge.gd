extends ItemEffect
## Üçüncü Şarj: +1 dash şarjı (stat modifier'ı ItemDB'de). Yeni şarj hemen dolu gelir.


func on_acquire() -> void:
	owner.dash_charges += 1
	owner.dash_charges_changed.emit(owner.dash_charges, owner.stats.int_value("dash_charges"))


func on_remove() -> void:
	owner.dash_charges = mini(owner.dash_charges, owner.stats.int_value("dash_charges"))
	owner.dash_charges_changed.emit(owner.dash_charges, owner.stats.int_value("dash_charges"))
