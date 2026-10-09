extends SceneTree
## TELEFON KAYDIRMA YOLU ÖLÇÜMÜ: gerçek InputEventScreenTouch / ScreenDrag olayları verilir; fare
## olaylarını Godot türetir (emulate_mouse_from_touch) — telefondaki zincirin aynısı. Her kaydırmalı
## ekranda iki ölçüm: parmak KARTIN ÜSTÜNDE başlar / kartların ARASINDA başlar.
## Kullanım: tools/qa_isolated.sh res://qa/touch_scroll_probe.gd --resolution 1152x648
## YALNIZCA 1152x648: başka pencere boyunda tuval ölçeklenir, sentetik dokunuş PENCERE pikseli sayılır
## ve hedefi ıskalar (1040x480 denemesinde dekorasyon şeridi yanlışlıkla "kaymıyor" ölçüldü).

var _hud: Hud


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _touch(pos: Vector2, pressed: bool) -> void:
	var e: InputEventScreenTouch = InputEventScreenTouch.new()
	e.index = 0
	e.position = pos
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag(pos: Vector2, rel: Vector2) -> void:
	var e: InputEventScreenDrag = InputEventScreenDrag.new()
	e.index = 0
	e.position = pos
	e.relative = rel
	e.screen_relative = rel
	e.velocity = rel * 60.0
	Input.parse_input_event(e)


## Parmak hareketi biçimi: hold = basıp bekleme karesi, count/scale = adım sayısı ve boyu,
## jitter = kaydırmadan önce titreme (gerçek parmak hiç tam durmaz).
var hold: int = 2
var count: int = 8
var step_scale: float = 1.0
var jitter: bool = false


## Parmak `start`'tan `step` yönünde sürüklenir; kabın kayma miktarı döner.
func _swipe(scroll: ScrollContainer, start: Vector2, step: Vector2) -> int:
	var horizontal: bool = absf(step.x) > absf(step.y)
	var before: int = scroll.scroll_horizontal if horizontal else scroll.scroll_vertical
	_touch(start, true)
	await _frames(hold)
	var pos: Vector2 = start
	if jitter:
		for offset: Vector2 in [Vector2(1, 1), Vector2(-1, 2), Vector2(2, -1), Vector2(0, 1)]:
			pos += offset
			_drag(pos, offset)
			await _frames(1)
	for i: int in count:
		pos += step * step_scale
		_drag(pos, step * step_scale)
		await _frames(1)
	var after: int = scroll.scroll_horizontal if horizontal else scroll.scroll_vertical
	_touch(pos, false)
	await _frames(40)
	# Bir sonraki ölçüm temiz başlasın
	if horizontal:
		scroll.scroll_horizontal = 0
	else:
		scroll.scroll_vertical = 0
	await _frames(5)
	return absi(after - before)


## Kabın içindeki ilk görünür düğmenin ortası ve iki düğme arasındaki boşluk (ya da düğmesiz bir yer).
func _points(scroll: ScrollContainer) -> Array:
	var rect: Rect2 = scroll.get_global_rect()
	var buttons: Array[Control] = []
	for node: Node in scroll.find_children("*", "BaseButton", true, false):
		var b: Control = node as Control
		if b.is_visible_in_tree() and rect.encloses(b.get_global_rect().grow(-2.0)):
			buttons.append(b)
	if buttons.is_empty():
		return [rect.get_center(), null]   # düğmesiz liste (koleksiyon kartları panel): ortasından
	var on: Vector2 = buttons[0].get_global_rect().get_center()
	var gap: Variant = null
	if buttons.size() > 1:
		var a: Rect2 = buttons[0].get_global_rect()
		var b: Rect2 = buttons[1].get_global_rect()
		if b.position.y > a.end.y + 2.0:
			gap = Vector2(a.get_center().x, (a.end.y + b.position.y) * 0.5)
		elif b.position.x > a.end.x + 2.0:
			gap = Vector2((a.end.x + b.position.x) * 0.5, a.get_center().y)
	return [on, gap]


func _measure(label: String, scroll: ScrollContainer) -> void:
	await _frames(10)
	if scroll == null or not scroll.is_visible_in_tree():
		print("%-28s kap görünmüyor" % label)
		return
	var horizontal: bool = scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED
	var bar: ScrollBar = scroll.get_h_scroll_bar() if horizontal else scroll.get_v_scroll_bar()
	var room: float = bar.max_value - bar.page
	var step: Vector2 = Vector2(-22, 0) if horizontal else Vector2(0, -22)
	var points: Array = _points(scroll)
	var on_card: int = -1
	var in_gap: int = -1
	if points[0] != null:
		on_card = await _swipe(scroll, points[0], step)
	if points[1] != null:
		in_gap = await _swipe(scroll, points[1], step)
	print("%-28s kaydırma payı %4.0f | KART ÜSTÜ %4d | ARA %4d" % [label, room, on_card, in_gap])


func _run() -> void:
	Input.use_accumulated_input = false
	Input.emulate_touch_from_mouse = true   # masaüstünde is_touchscreen_available() → true (telefon gibi)
	change_scene_to_file("res://Main.tscn")
	await _frames(90)
	_hud = current_scene.find_child("HUD", true, false) as Hud
	var router: UiRouter = _hud.router
	print("touchscreen: %s  mouse_from_touch: %s" % [DisplayServer.is_touchscreen_available(),
		ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch")])
	var cases: Array = [
		["hızlı (eski ölçüm)", 2, 8, 1.0, false, false],
		["basılı tut 20 kare", 20, 8, 1.0, false, false],
		["yavaş 4px x 40", 2, 40, 0.18, false, false],
		["titreme + kaydır", 2, 8, 1.0, true, false],
		["birikmiş girdi AÇIK", 2, 8, 1.0, false, true],
		["hepsi (gerçek parmak)", 12, 40, 0.18, true, true],
	]
	router.open(&"showroom")
	await _frames(30)
	var list: ScrollContainer = router.screen(&"showroom").find_child("List", true, false) as ScrollContainer
	for c: Array in cases:
		hold = c[1]
		count = c[2]
		step_scale = c[3]
		jitter = c[4]
		Input.use_accumulated_input = c[5]
		await _measure("showroom: " + String(c[0]), list)
	Input.use_accumulated_input = false
	router.close_all()
	await _frames(20)
	hold = 6
	count = 30
	step_scale = 0.25
	jitter = true
	# Her ekranda: kartın üstünden / kartlar arasından (kapsayıcının yerleşik aktarımı BOZUK olsa
	# bile: kaptaki düğmeler STOP yapılır — telefonda gözlenen durum).
	for id: StringName in [&"showroom", &"garage", &"collection", &"garage_edit", &"settings", &"quests"]:
		router.open(id)
		await _frames(30)
		for node: Node in router.screen(id).find_children("*", "ScrollContainer", true, false):
			var scroll: ScrollContainer = node as ScrollContainer
			if not scroll.is_visible_in_tree():
				continue
			for b: Node in scroll.find_children("*", "Control", true, false):
				if b is BaseButton or b is PanelContainer:
					(b as Control).mouse_filter = Control.MOUSE_FILTER_STOP
			await _measure("%s/%s (aktarımsız)" % [id, scroll.name], scroll)
		router.close_all()
		await _frames(20)
	quit(0)
