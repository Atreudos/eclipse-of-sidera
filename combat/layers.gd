class_name Layers
extends RefCounted
## Fizik katmanları (project.godot > layer_names ile aynı sıra). Değerler bit maskesidir.

const WORLD := 1
const PLAYER := 2
const ENEMY := 4
const PLAYER_HURT := 8
const ENEMY_HURT := 16
const PLAYER_HIT := 32
const ENEMY_HIT := 64
## Tek yönlü platformlar. Mermiler bunları görmez (içinden geçer); oyuncu ve düşmanlar basar.
const PLATFORM := 128
