extends SceneTree
## İSABET ALANI DENEYİ: Control._has_point() ile genişletilen alan gerçekten tıklama alıyor mu?
##   K) KONTROL — düğmenin tam ortası (almazsa simülasyon bozuktur, sonuç geçersiz)
##   A) düğmenin görsel dikdörtgeninin DIŞINDA ama genişletilmiş alanın İÇİNDE
##   B) aynı ama üst Control'ün (kapsayıcı) dikdörtgeninin de dışında
##   C) genişletilmiş alanın da dışında (tıklama ALMAMALI)
## Kullanım (pencereli — başsızda GUI girdisi işlenmiyor):
##   godot-4 --path . --resolution 640x480 -s res://qa/hit_area_probe.gd

class Wide extends Button:
	var slop: float = 20.0
	func _has_point(p: Vector2) -> bool:
		return Rect2(Vector2(-slop, -slop), size + Vector2(slop, slop) * 2.0).has_point(p)

const CASES: Array[Array] = [
	["K", Vector2(150, 120), 1],   # düğme ortası
	["A", Vector2(150, 95), 1],    # düğmenin 5 px üstü
	["B", Vector2(150, 85), 1],    # 15 px üstü: kapsayıcının da dışında
	["C", Vector2(150, 70), 0],    # 30 px üstü: genişletilmiş alanın da dışında
]

var _hits: Dictionary = {}
var _frame: int = 0
var _i: int = 0
var _phase: int = 0


func _initialize() -> void:
	var root: Control = Control.new()
	root.size = Vector2(400, 300)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_root().add_child(root)
	var holder: Control = Control.new()
	holder.position = Vector2(100, 100)
	holder.size = Vector2(100, 40)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)
	var btn: Wide = Wide.new()
	btn.size = Vector2(100, 40)
	holder.add_child(btn)
	btn.pressed.connect(func() -> void: _hits[CASES[_i][0]] = int(_hits.get(CASES[_i][0], 0)) + 1)


func _send(at: Vector2, down: bool) -> void:
	var e: InputEventMouseButton = InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	e.position = at
	e.global_position = at
	Input.parse_input_event(e)


func _move(at: Vector2) -> void:
	var m: InputEventMouseMotion = InputEventMouseMotion.new()
	m.position = at
	m.global_position = at
	Input.parse_input_event(m)


func _process(_d: float) -> bool:
	_frame += 1
	if _frame < 10 or _frame % 3 != 0:
		return false
	if _i >= CASES.size():
		var ok: bool = true
		for c: Array in CASES:
			var got: int = int(_hits.get(c[0], 0))
			ok = ok and got == c[2]
			print("%s  tıklama=%d  beklenen=%d  %s" % [c[0], got, c[2], "OK" if got == c[2] else "HATA"])
		print("SONUÇ: %s" % ("genişletilmiş isabet alanı ÇALIŞIYOR" if ok else "beklenenle uyuşmuyor"))
		quit()
		return true
	var at: Vector2 = CASES[_i][1]
	match _phase:
		0: _move(at)
		1: _send(at, true)
		2: _send(at, false)
		3:
			# pressed sinyali bırakmada gelir ve olay BİR SONRAKİ karede işlenir; sayaç bırakmayla
			# aynı karede ilerlerse her tıklama bir sonraki duruma yazılıyordu (ölçüldü).
			_i += 1
			_phase = -1
	_phase += 1
	return false
