class_name UiRouter
extends Node
## EKRAN YÖNLENDİRİCİ — hangi ekranın açık olduğunun TEK kaynağı.
##
## Neden var: ekranlar (garaj, showroom, görevler, ustalık, rütbe merdiveni, profil, hesap) daha önce
## kendi açma/kapama mantığını taşıyordu; bu yüzden showroom + görevler + tamir plakası aynı anda
## açık kalabiliyor, ESC iki ekranı birden kapatabiliyordu. Artık hepsi buradan geçer.
##
## İKİ TÜR EKRAN:
##   PLACE — oyuncunun GİTTİĞİ yer (garaj, showroom). Tam ekrandır, oyun HUD'unu gizler.
##           Aynı anda yalnızca bir PLACE açık olur; yenisi açılınca eskisi kapanır.
##   MODAL — bir yerin ÜSTÜNE açılan pano (görevler, ustalık, garaj değeri, profil, hesap).
##           Üstünde durduğu PLACE kapanmaz: kapatılınca oyuncu geldiği yere döner.
## Yığın en fazla 2 derindir (PLACE + MODAL): "panel üstüne panel" çöplüğü oluşamaz.
##
## Ekran sözleşmesi: open() / close() metotları ve closed sinyali. Ekran kendi KAPAT plakasıyla
## kapandığında closed sinyali yığını temizler; ESC ise buradan yönetilir (ekranlar artık
## ui_cancel dinlemez, yoksa iki kapanış üst üste binerdi).

## Yığının tepesi değişti. top = &"" ise hiçbir ekran açık değildir.
signal stack_changed(top: StringName, place_open: bool)

enum Kind { PLACE, MODAL }

var _screens: Dictionary = {}   # id → {"node": Control, "kind": Kind}
var _stack: Array[StringName] = []


func _ready() -> void:
	add_to_group("ui_router")
	process_mode = Node.PROCESS_MODE_ALWAYS


## Ekranı kaydeder. Ekranın open() / close() metotları ve closed sinyali olmalıdır.
func register(id: StringName, screen: Control, kind: Kind = Kind.MODAL) -> void:
	_screens[id] = {"node": screen, "kind": kind}
	if screen.has_signal(&"closed") and not screen.is_connected(&"closed", _on_screen_closed):
		screen.connect(&"closed", _on_screen_closed.bind(id))


## Ekranı açar. PLACE ise açık PLACE'in yerine geçer, MODAL ise açık MODAL'in yerine geçer.
func open(id: StringName) -> void:
	if not _screens.has(id):
		push_warning("UiRouter: '%s' kayıtlı değil" % id)
		return
	if top() == id:
		return
	var kind: Kind = _screens[id]["kind"]
	if kind == Kind.PLACE:
		_close_all_silent()
	elif not _stack.is_empty() and _kind_of(_stack.back()) == Kind.MODAL:
		_close_silent(_stack.pop_back())
	_stack.append(id)
	(_screens[id]["node"] as Control).call(&"open")
	_emit()


## Tepedeki ekranı kapatır (ESC / GERİ). Alttaki PLACE açık kalır.
func back() -> void:
	if _stack.is_empty():
		return
	_close_silent(_stack.pop_back())
	_emit()


## Her şeyi kapatır (ör. oyun akışına dönmek gerektiğinde).
func close_all() -> void:
	if _stack.is_empty():
		return
	_close_all_silent()
	_emit()


func top() -> StringName:
	return _stack.back() if not _stack.is_empty() else &""


func is_open(id: StringName) -> bool:
	return _stack.has(id)


## Açık bir PLACE var mı (oyun HUD'u gizlenmeli mi)?
func place_open() -> bool:
	for id: StringName in _stack:
		if _kind_of(id) == Kind.PLACE:
			return true
	return false


## Açık PLACE'in id'si (yoksa boş).
func current_place() -> StringName:
	for id: StringName in _stack:
		if _kind_of(id) == Kind.PLACE:
			return id
	return &""


func screen(id: StringName) -> Control:
	return _screens[id]["node"] if _screens.has(id) else null


func _unhandled_input(event: InputEvent) -> void:
	if not _stack.is_empty() and event.is_action_pressed(&"ui_cancel"):
		back()
		get_viewport().set_input_as_handled()


## Ekran kendi butonuyla kapandı: yığından düşür (tekrar close() çağırmadan).
func _on_screen_closed(id: StringName) -> void:
	if not _stack.has(id):
		return
	_stack.erase(id)
	_emit()


func _close_silent(id: StringName) -> void:
	var node: Control = _screens[id]["node"]
	if node.visible:
		node.call(&"close")


func _close_all_silent() -> void:
	while not _stack.is_empty():
		_close_silent(_stack.pop_back())


func _kind_of(id: StringName) -> Kind:
	return _screens[id]["kind"] if _screens.has(id) else Kind.MODAL


func _emit() -> void:
	stack_changed.emit(top(), place_open())
