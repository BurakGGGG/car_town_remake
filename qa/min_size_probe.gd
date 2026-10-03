extends SceneTree
## DENEY 1: Button alt sınıfında _get_minimum_size() geçersiz kılınınca Godot onu kullanıyor mu?
##   Ölçüldü (4.7.2): HAYIR — Button'ın C++ hesabı kazanıyor, sanal metot yok sayılıyor.
## DENEY 2: custom_minimum_size atanınca minimum_size_changed sinyali tetikleniyor mu? Tetikleniyorsa
##   bir taban, kendisinden SONRA yapılan `custom_minimum_size = Vector2(w, 0)` atamasına karşı
##   kendini onarabilir (UI kodunda bu atama çok yaygın ve çoğu add_child'dan sonra).
## Kullanım: godot-4 --headless --path . -s res://qa/min_size_probe.gd

class Tall extends Button:
	func _get_minimum_size() -> Vector2:
		return Vector2(0.0, 80.0)

class Floored extends Button:
	const FLOOR: float = 44.0
	func _ready() -> void:
		minimum_size_changed.connect(_heal)
		_heal()
	func _heal() -> void:
		if custom_minimum_size.y < FLOOR:
			custom_minimum_size.y = FLOOR

var _f: int = 0
var _floored: Floored

func _initialize() -> void:
	var plain: Button = Button.new()
	plain.text = "GÖREVLER"
	var tall: Tall = Tall.new()
	tall.text = "GÖREVLER"
	get_root().add_child(plain)
	get_root().add_child(tall)
	print("1) sanal metot: %s" % ("UYGULANIYOR" if tall.get_combined_minimum_size().y >= 80.0 else "YOK SAYILIYOR"))
	_floored = Floored.new()
	_floored.text = "GÖREVLER"
	get_root().add_child(_floored)

func _process(_d: float) -> bool:
	_f += 1
	if _f == 2:
		# _ready ÇALIŞTIKTAN SONRA atama: taban ancak sinyal yoluyla onarılabilir
		print("2) _ready sonrası yükseklik: %.0f  (_ready çalıştı: %s)" % [
			_floored.get_combined_minimum_size().y, _floored.is_node_ready()])
		_floored.custom_minimum_size = Vector2(300.0, 0.0)   # UI kodundaki tipik atama
		print("   custom_minimum_size=(300,0) atandı → hemen: %s" % _floored.custom_minimum_size)
	if _f == 4:
		print("   2 kare sonra: %s  birleşik en küçük: %s" % [
			_floored.custom_minimum_size, _floored.get_combined_minimum_size()])
		var ok: bool = _floored.custom_minimum_size.y >= 44.0 and _floored.custom_minimum_size.x >= 300.0
		print("SONUÇ: taban %s, genişlik %s" % [
			"KENDİNİ ONARIYOR" if _floored.custom_minimum_size.y >= 44.0 else "EZİLİYOR",
			"korunuyor" if _floored.custom_minimum_size.x >= 300.0 else "KAYBOLUYOR"])
		quit()
	return false
