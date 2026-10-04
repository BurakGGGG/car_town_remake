extends SceneTree
## DOKUNMATİK KAYDIRMA — çubuk yok, parmakla sürükleme, bırakınca ataletle akış, kart yakalama.
## Çalıştırma: tools/run_tests.sh touch_scroll_test (pencereli)

var fails: int = 0


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


## Masaüstünde kaplar dokunmatik sürüklemeyi yalnızca fareden dokunma türetilirse işler
## (telefonda gerçek dokunmatik ekran bunu kendiliğinden sağlar): fare olayları Input'a verilir.
func _touch(pos: Vector2, pressed: bool, device: int = 0) -> void:
	var e: InputEventMouseButton = InputEventMouseButton.new()
	e.device = device
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = pos
	e.global_position = pos
	e.pressed = pressed
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(e)


func _drag(pos: Vector2, rel: Vector2, device: int = 0) -> void:
	var e: InputEventMouseMotion = InputEventMouseMotion.new()
	e.device = device
	e.position = pos
	e.global_position = pos
	e.relative = rel
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)


func _initialize() -> void:
	_run.call_deferred()


func _make(horizontal: bool, snap: bool) -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(100, 50)
	scroll.size = Vector2(300, 300)
	if horizontal:
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	else:
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	TouchScroll.attach(scroll, snap)
	var box: BoxContainer = HBoxContainer.new() if horizontal else VBoxContainer.new()
	scroll.add_child(box)
	for i: int in 30:
		var button: PlateButton = PlateButton.new()
		button.text = "KART %d" % i
		button.custom_minimum_size = Vector2(120, 60) if horizontal else Vector2(200, 60)
		box.add_child(button)
	root.add_child(scroll)
	return scroll


func _swipe(scroll: ScrollContainer, horizontal: bool) -> void:
	var start: Vector2 = scroll.position + Vector2(150, 150)
	var step: Vector2 = Vector2(-20, 0) if horizontal else Vector2(0, -20)
	_touch(start, true)
	await frames(1)
	var pos: Vector2 = start
	for i: int in 8:
		pos += step
		_drag(pos, step)
		await frames(1)
	_touch(pos, false)


func _run() -> void:
	Input.use_accumulated_input = false   # sentetik hareket olayları birleştirilmesin (kararlı ölçüm)
	# Fare TUT-ÇEK (masaüstü): kabın kendi sürüklemesi kapalı, TouchScroll fareyi parmak gibi işler
	Input.emulate_touch_from_mouse = false
	await frames(3)
	print("== dikey liste ==")
	var v: ScrollContainer = _make(false, false)
	await frames(20)   # pencere ve yerleşim otursun: ilk sürükleme tam koşuda bazen boşa gidiyordu
	check(v.get_v_scroll_bar().modulate.a >= 0.0 and v.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER, "kaydırma çubuğu gizli (kaydırma açık)")
	var button: Button = v.find_children("*", "Button", true, false)[0]
	check(button.mouse_filter == Control.MOUSE_FILTER_PASS, "kartlar PASS (sürükleme kaba ulaşır)")
	await _swipe(v, false)
	var at_release: int = v.scroll_vertical
	check(at_release > 40, "parmakla sürükleyince kaydı (%d)" % at_release)
	await frames(20)
	check(v.scroll_vertical > at_release + 20, "bırakınca ataletle akmaya devam etti (%d → %d)" % [at_release, v.scroll_vertical])
	var settled: int = v.scroll_vertical
	await frames(240)
	var final_v: int = v.scroll_vertical
	await frames(10)
	check(v.scroll_vertical == final_v and final_v >= settled, "akış sonunda durdu (%d)" % final_v)
	v.queue_free()

	print("== yatay şerit (kart yakalama) ==")
	var h: ScrollContainer = _make(true, true)
	await frames(3)
	await _swipe(h, true)
	await frames(60)
	var snapped: int = h.scroll_horizontal
	var pitch: int = 120 + h.get_child(1).get_theme_constant("separation")
	check(snapped > 0, "yatay kaydı (%d)" % snapped)
	check(snapped % pitch == 0,
		"bırakınca bir kartın başına oturdu (%d, adım %d)" % [snapped, pitch])
	h.queue_free()

	print("== sürükleme kartı basmaz, kısa dokunuş basar ==")
	var list: ScrollContainer = _make(false, false)
	await frames(3)
	var first: Button = list.find_children("*", "Button", true, false)[0]
	var presses: Array[int] = [0]
	first.pressed.connect(func() -> void: presses[0] += 1)
	var on_card: Vector2 = first.get_global_rect().get_center()
	_touch(on_card, true)
	await frames(1)
	var p: Vector2 = on_card
	for i: int in 6:
		p += Vector2(0, -15)
		_drag(p, Vector2(0, -15))
		await frames(1)
	_touch(p, false)
	await frames(3)
	check(presses[0] == 0 and list.scroll_vertical > 0, "kartın üstünden başlayan sürükleme kaydırdı, kart basılmadı")
	await frames(60)
	var before: int = list.scroll_vertical
	var tap_at: Vector2 = list.get_global_rect().get_center()
	var tapped: Button = null
	for b: Node in list.find_children("*", "Button", true, false):
		if (b as Button).get_global_rect().has_point(tap_at):
			tapped = b
	check(tapped != null, "listenin ortasında bir kart var")
	var taps: Array[int] = [0]
	tapped.pressed.connect(func() -> void: taps[0] += 1)
	_touch(tap_at, true)
	await frames(1)
	_touch(tap_at, false)
	await frames(3)
	check(taps[0] == 1 and absi(list.scroll_vertical - before) <= 2, "kısa dokunuş kartı bastı, liste kaymadı (basış %d, kayma %d)" % [taps[0], list.scroll_vertical - before])

	print("== mobil öncelik: dokunmadan türetilen fare olayları çift kaydırmaz ==")
	list.scroll_vertical = 0
	await frames(2)
	var start: Vector2 = list.position + Vector2(150, 150)
	_touch(start, true, InputEvent.DEVICE_ID_EMULATION)
	var q: Vector2 = start
	for i: int in 6:
		q += Vector2(0, -20)
		_drag(q, Vector2(0, -20), InputEvent.DEVICE_ID_EMULATION)
		await frames(1)
	_touch(q, false, InputEvent.DEVICE_ID_EMULATION)
	await frames(3)
	check(list.scroll_vertical == 0, "türetilmiş (telefon) fare olayı TouchScroll'u sürüklemiyor: parmağı kabın kendisi işler")
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
