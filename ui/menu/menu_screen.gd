class_name MenuScreen
extends RefCounted
## Ana menünün bir ekranı (başlık, kayıt slotları, yeni oyun, krediler...). MainMenu bir ekran YIĞINI tutar:
## en üstteki ekran görünür ve girişi alır. Ekran yalnızca kendi durumunu ve çizimini bilir; geçişleri `menu` ile yapar.
##
## Giriş sabit "eylemlere" çevrilir (klavye, fare, kumanda hepsi aynı yola girer):
##   "up" "down" "left" "right" "accept" "back" "delete" "backspace"
## Yazı yazılırken (`wants_text`) harfler `on_char`'a gider, WASD gezinmez.

## Gölge dairenin (tutulma) istenen yeri: x, y, yarıçap. Başlık ekranında büyük ve ortada, diğerlerinde köşede küçüktür.
const ECLIPSE_TITLE := Vector3(640.0, 238.0, 124.0)
const ECLIPSE_SIDE := Vector3(1170.0, 72.0, 44.0)

## Bu ekranın sahibi menü (yığına konunca atanır).
var menu: MainMenu


## Testler ve bağlantılar için ekranın adı.
func screen_id() -> String:
	return ""


## Ekran yığına girdi.
func on_enter() -> void:
	pass


## Üstündeki ekran kapandı, bu ekran yeniden göründü (veriyi tazele).
func on_resume() -> void:
	pass


func wants_text() -> bool:
	return false


func on_action(_action: String) -> void:
	pass


func on_char(_ch: String) -> void:
	pass


func on_hover(_pos: Vector2) -> void:
	pass


func on_click(_pos: Vector2) -> void:
	pass


func on_tick(_dt: float) -> void:
	pass


func draw(_ci: CanvasItem, _t: float) -> void:
	pass


## Alt satırdaki tuş ipucu (boşsa çizilmez).
func hint() -> String:
	return ""


func eclipse() -> Vector3:
	return ECLIPSE_SIDE
