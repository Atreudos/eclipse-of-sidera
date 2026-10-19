class_name Hurtbox
extends Area2D
## Hasar alan alan. Sahibi (parent) bir ActorBase olmalı.

@export_enum("player", "enemy") var faction: String = "player"


func _ready() -> void:
	collision_layer = Layers.PLAYER_HURT if faction == "player" else Layers.ENEMY_HURT
	collision_mask = 0
	monitoring = false  # pasif: hitbox'lar bizi bulur


## true döner = hasar işlendi.
func receive_hit(hitbox: Hitbox) -> bool:
	var actor := get_parent() as ActorBase
	if actor == null:
		return false
	return actor.on_hit_by(hitbox)
