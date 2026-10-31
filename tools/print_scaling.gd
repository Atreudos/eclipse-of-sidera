extends Node
## Geliştirici aracı: zorluk x tur ölçeklemesi tablosunu yazdırır (denge ayarı ve belgeler için).
## Çalıştır:  godot --headless --path . res://tools/print_scaling.tscn

const STEPS := [0, 5, 10, 25, 50, 75, 100, 1000, 100000]


func _ready() -> void:
	for level in Difficulty.count():
		print("\n== %s ==" % Difficulty.name_of(level))
		for n in STEPS:
			print(EnemyScaling.tuning(level, n).summary())
	print("\nOrnek: Taurus (can 4, hasar 1/2) ve Sagitta (can 3)")
	for level in Difficulty.count():
		for n in [0, 25, 100]:
			var t := EnemyScaling.tuning(level, n)
			print("%-9s tur %3d: Taurus can %d  hasar %d/%d  | Sagitta can %d  | Scorpius can %d" % [
				Difficulty.name_of(level), n, t.scale_hp(4), t.scale_damage(1), t.scale_damage(2), t.scale_hp(3), t.scale_hp(3)])
	get_tree().quit(0)
