extends ItemEffect
## Vampir Yadigarı: başarılı her parry sana +3 can yeniler (en çok maksimum cana kadar).
## Gölge alırsa (Umbra dövüşü): seni parry'lerse kendine +1 can çeker.

const HEAL := 3


func on_acquire() -> void:
	listen(EventBus.parry_success, _on_parry)


func _on_parry(actor: Node, _hitbox: Node) -> void:
	if actor == owner:
		owner.heal(HEAL)
