extends SceneTree
## GERÇEK HUD'DA DOKUNMA ALANI TESTİ. PlateButton'ın görünmez kenar payı (MIN_TOUCH) çalışıyor mu?
##   1) GARAJI DÜZENLE plakasının (sütunun en altı) görünür kenarının 12 birim ALTINA dokun →
##      düzenleme ekranı açılmalı. (Önceden GÖREVLER'in altıydı; GÖREVLER'in altına GARAJI DÜZENLE
##      geldiğinden o nokta artık başka bir plakanın GÖRÜNÜR alanında — oraya dokunmak onu açar.)
##   2) Kamera ile ses tabelası arasındaki boşlukta, SESE daha yakın bir noktaya dokun →
##      yalnızca ses düğmesi basılmalı (en yakın kazanır; ağaçta sonra gelen değil)
##   2b) AYNASI: boşlukta KAMERAYA yakın nokta → yalnızca kamera (ağaç sırası sesi kayırdığı için
##       hakemliğin asıl kanıtı budur)
##   3) GARAJI DÜZENLE'nin 60 birim altına dokun → hiçbir plaka tetiklenmemeli (payın dışı, dünya)
## Taban çözünürlükte koşmalı (ölçek 1, pencere koordinatı = tuval koordinatı).
## Kullanım: godot-4 --path . --resolution 1152x648 -s res://qa/dokunma_testi.gd

var _f: int = 0
var _hud: Node
var _router: Node
var _quest: Control
var _edit: Control
var _camera: Control
var _sound: Control
var _presses: Dictionary = {"camera": 0, "sound": 0}
var _queue: Array[Array] = []   # [ad, nokta]
var _results: Array[String] = []
var _fails: int = 0
var _step: int = 0
var _phase: int = 0


func _process(_d: float) -> bool:
	_f += 1
	if _f == 2:
		change_scene_to_file("res://Main.tscn")
		return false
	if _f == 90:
		_hud = current_scene.find_child("HUD", true, false)
		_router = _hud.get("router")
		_quest = current_scene.find_child("QuestButton", true, false) as Control
		_edit = current_scene.find_child("EditGarageButton", true, false) as Control
		_camera = current_scene.find_child("CameraButton", true, false) as Control
		_sound = current_scene.find_child("SoundButton", true, false) as Control
		_camera.connect(&"pressed", func() -> void: _presses["camera"] += 1)
		_sound.connect(&"pressed", func() -> void: _presses["sound"] += 1)
		var q: Rect2 = _quest.get_global_rect()
		var e: Rect2 = _edit.get_global_rect()
		var c: Rect2 = _camera.get_global_rect()
		var s: Rect2 = _sound.get_global_rect()
		print("GÖREVLER %s | GARAJI DÜZENLE %s | kamera %s | ses %s" % [q, e, c, s])
		# 2) boşluk: kameranın sağ kenarı ile sesin sol kenarı arası, sese 1/4 yakın
		_queue = [
			["1_payda_duzenle", Vector2(e.get_center().x, e.end.y + 12.0)],
			["2_bosluk_ses", Vector2(lerpf(c.end.x, s.position.x, 0.75), s.get_center().y)],
			# AYNA: ağaç sırası sesi kayırır (sonra gelir, önce sorulur); kameraya yakın nokta yine de
			# kameranın olmalı. Asıl hakemlik kanıtı budur — 2_ tek başına sıra yüzünden de geçerdi.
			["2b_bosluk_kamera", Vector2(lerpf(c.end.x, s.position.x, 0.25), c.get_center().y)],
			["3_uzak", Vector2(e.get_center().x, e.end.y + 60.0)],
		]
		return false
	if _f < 100 or _f % 4 != 0:
		return false
	if _step >= _queue.size():
		for r: String in _results:
			print(r)
		print("SONUÇ: %s" % ("TÜMÜ GEÇTİ" if _fails == 0 else "%d HATA" % _fails))
		quit(0 if _fails == 0 else 1)
		return true
	var at: Vector2 = _queue[_step][1]
	match _phase:
		0:
			# Önceki durumun açtığı ekran KAPANMA animasyonu bitene kadar tam ekran perdesiyle
			# dokunuşu yakalıyor (ölçüldü: QuestScreen imlecin altındaydı) — görünmez olana dek bekle.
			_router.call("close_all")
			if _any_screen_visible():
				return false
			_presses = {"camera": 0, "sound": 0}
			_move(at)
		1:
			var hov: Control = get_root().gui_get_hovered_control()
			print("   imleç altı %s: %s" % [at, hov.get_path() if hov else "yok"])
			_button(at, true)
		2: _button(at, false)
		3:
			_check(_queue[_step][0], at)
			_step += 1
			_phase = -1
	_phase += 1
	return false


func _check(name: String, at: Vector2) -> void:
	var top: StringName = _router.call("top")
	var ok: bool = false
	var got: String = ""
	match name:
		"1_payda_duzenle":
			ok = top == &"garage_edit"
			got = "açık ekran=%s" % top
		"2_bosluk_ses":
			ok = _presses["sound"] == 1 and _presses["camera"] == 0
			got = "ses=%d kamera=%d" % [_presses["sound"], _presses["camera"]]
		"2b_bosluk_kamera":
			ok = _presses["camera"] == 1 and _presses["sound"] == 0
			got = "ses=%d kamera=%d" % [_presses["sound"], _presses["camera"]]
		"3_uzak":
			# Ölçüt: kenar payının DIŞINDA hiçbir sütun plakası tetiklenmemeli (orası dünya).
			ok = top != &"quests" and top != &"garage_edit" and _presses["sound"] == 0 and _presses["camera"] == 0
			got = "açık ekran='%s'" % top
	if not ok:
		_fails += 1
	_results.append("%-20s %s  (%s)  → %s" % [name, at, got, "OK" if ok else "HATA"])


func _any_screen_visible() -> bool:
	for id: StringName in [&"quests", &"garage_edit", &"garage", &"profile"]:
		var screen: Control = _router.call("screen", id)
		if screen and screen.visible:
			return true
	return false


func _move(at: Vector2) -> void:
	var m: InputEventMouseMotion = InputEventMouseMotion.new()
	m.position = at
	m.global_position = at
	Input.parse_input_event(m)


func _button(at: Vector2, down: bool) -> void:
	var e: InputEventMouseButton = InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	e.position = at
	e.global_position = at
	Input.parse_input_event(e)
