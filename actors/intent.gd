class_name Intent
extends RefCounted
## Bir aktörün "ne yapmak istediği". Oyuncuda klavye/kontrolcüden, Rakip'te yapay zekadan,
## testlerde koddan doldurulur. Aynı hareket kodu hepsinde çalışır.

var move_x := 0.0
var jump_held := false
# Aşağıdakiler "bu karede basıldı" bilgisidir; her fizik karesinden sonra temizlenir.
var jump_pressed := false
var dash_pressed := false
var parry_pressed := false
var attack_pressed := false


func clear_edges() -> void:
	jump_pressed = false
	dash_pressed = false
	parry_pressed = false
	attack_pressed = false
