class_name Intent
extends RefCounted
## Bir aktörün "ne yapmak istediği". Oyuncuda klavye/kontrolcüden, Umbra'da yapay zekadan,
## testlerde koddan doldurulur. Aynı hareket kodu hepsinde çalışır.

var move_x := 0.0
var jump_held := false
# Aşağıdakiler "bu karede basıldı" bilgisidir; her fizik karesinden sonra temizlenir.
var jump_pressed := false
var dash_pressed := false
var parry_pressed := false
var attack_pressed := false
## İkinci silah slotu (I): bu karede basıldı.
var attack2_pressed := false
var interact_pressed := false
## Silah tuşları basılı tutuluyor (menzilli silah basılı tutunca bekleme biter bitmez tekrar fırlatır).
var attack_held := false
var attack2_held := false
## Dikey nişan: -1 yukarı (W / ↑), +1 aşağı (S / ↓), 0 yok. Sapan yönünü belirler.
var aim_y := 0.0


func clear_edges() -> void:
	jump_pressed = false
	dash_pressed = false
	parry_pressed = false
	attack_pressed = false
	attack2_pressed = false
	interact_pressed = false
