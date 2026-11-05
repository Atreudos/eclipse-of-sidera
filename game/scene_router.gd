class_name SceneRouter
extends RefCounted
## Sahne geçişleri tek yerden: ana menü, normal koşu, sınırsız mod, çıkış.
## Testler `hook` ve `quit_hook` ile geçişleri yakalar (test koşucusu sahnesi değişmesin / süreç kapanmasın).

const MENU := "res://ui/menu/main_menu.tscn"
const RUN := "res://levels/run.tscn"
const ENDLESS := "res://levels/endless.tscn"

## Dolu ise sahne değiştirmek yerine bu çağrılır: hook.call(sahne_yolu).
static var hook: Callable = Callable()
## Dolu ise oyundan çıkmak yerine bu çağrılır.
static var quit_hook: Callable = Callable()


## Kipin sahnesi.
static func scene_for(kind: int) -> String:
	return ENDLESS if kind == GameMode.Kind.ENDLESS else RUN


## Kipin sahnesi oyunda var mı? (Sınırsız mod sahnesi gelene kadar menüde "YAKINDA" görünür.)
static func can_play(kind: int) -> bool:
	return ResourceLoader.exists(scene_for(kind))


## Ana menüye döner. Açık kayıt oturumu kapanır, duraklatma ve yavaşlatma sıfırlanır.
static func go_menu(tree: SceneTree) -> void:
	_prepare(tree)
	GameState.end_session()
	_go(tree, MENU)


## Kipin oyun sahnesine geçer (oturum menüde `GameState.begin_session` ile kurulmuş olmalı).
static func go_game(tree: SceneTree, kind: int) -> void:
	_prepare(tree)
	_go(tree, scene_for(kind))


## Oyundan çıkar.
static func quit(tree: SceneTree) -> void:
	if quit_hook.is_valid():
		quit_hook.call()
		return
	tree.quit()


static func _prepare(tree: SceneTree) -> void:
	tree.paused = false
	Hitstop.reset()
	TimeStop.reset()


static func _go(tree: SceneTree, path: String) -> void:
	if hook.is_valid():
		hook.call(path)
		return
	tree.change_scene_to_file(path)
