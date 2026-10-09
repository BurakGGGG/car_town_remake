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
	list.queue_free()
	await _phone_section()
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)


# --- TELEFON YOLU: gerçek ScreenTouch / ScreenDrag olayları ----------------------------------

func _screen_touch(pos: Vector2, pressed: bool) -> void:
	var e: InputEventScreenTouch = InputEventScreenTouch.new()
	e.index = 0
	e.position = pos
	e.pressed = pressed
	Input.parse_input_event(e)


func _screen_drag(pos: Vector2, rel: Vector2) -> void:
	var e: InputEventScreenDrag = InputEventScreenDrag.new()
	e.index = 0
	e.position = pos
	e.relative = rel
	e.screen_relative = rel
	Input.parse_input_event(e)


func _finger_swipe(start: Vector2, step: Vector2, steps: int = 8) -> Vector2:
	_screen_touch(start, true)
	await frames(2)
	var pos: Vector2 = start
	for i: int in steps:
		pos += step
		_screen_drag(pos, step)
		await frames(1)
	_screen_touch(pos, false)
	await frames(3)
	return pos


func _phone_section() -> void:
	print("== telefon: kart olayı kaba AKTARMASA da parmakla kayar ==")
	# Telefonda kasa düğmesinin üstünden başlayan kaydırma kaymıyordu (yalnızca düğmeler arası
	# boşlukta kayıyordu). Burada kartlar olayı kaba aktarmaz (STOP): kabın yerleşik sürüklemesi
	# ÇALIŞAMAZ; kaydırma yalnızca TouchScroll'un kendi parmak izlemesiyle olabilir.
	var list: ScrollContainer = _make(false, false)
	await frames(3)
	var cards: Array[Node] = list.find_children("*", "Button", true, false)
	for card: Node in cards:
		(card as Control).mouse_filter = Control.MOUSE_FILTER_STOP
	await frames(2)
	var first: Button = cards[0]
	var presses: Array[int] = [0]
	first.pressed.connect(func() -> void: presses[0] += 1)
	await _finger_swipe(first.get_global_rect().get_center(), Vector2(0, -20))
	check(list.scroll_vertical > 100, "kartın üstünden parmakla kaydı, aktarım olmadan (%d)" % list.scroll_vertical)
	check(presses[0] == 0, "kaydırma sonrası kart BASILMADI")
	await frames(90)
	var settled: int = list.scroll_vertical
	await frames(10)
	check(list.scroll_vertical == settled, "atalet bitti, liste durdu (%d)" % settled)

	print("== telefon: kısa dokunuş hâlâ basar ==")
	var center: Vector2 = list.get_global_rect().get_center()
	var tapped: Button = null
	for b: Node in cards:
		if (b as Button).get_global_rect().has_point(center):
			tapped = b
	var taps: Array[int] = [0]
	tapped.pressed.connect(func() -> void: taps[0] += 1)
	var before: int = list.scroll_vertical
	_screen_touch(center, true)
	await frames(2)
	_screen_drag(center + Vector2(0, 3), Vector2(0, 3))   # parmak hiç tam durmaz: ölü bölge içinde titreme
	await frames(1)
	_screen_touch(center + Vector2(0, 3), false)
	await frames(3)
	check(taps[0] == 1, "titreyen kısa dokunuş kartı bastı (%d)" % taps[0])
	check(absi(list.scroll_vertical - before) <= 1, "kısa dokunuş listeyi kaydırmadı")

	print("== telefon: art arda kaydırmalar (durum asılı kalmaz) ==")
	list.scroll_vertical = 0
	await frames(2)
	await _finger_swipe(first.get_global_rect().get_center(), Vector2(0, -15), 6)
	var once: int = list.scroll_vertical
	await frames(90)
	await _finger_swipe(list.get_global_rect().get_center(), Vector2(0, -15), 6)
	check(once > 50 and list.scroll_vertical > once + 50, "ikinci kaydırma da çalıştı (%d → %d)" % [once, list.scroll_vertical])

	print("== telefon: üstte açık pencere varken kap kaymaz ==")
	list.scroll_vertical = 0
	await frames(2)
	var cover: ColorRect = ColorRect.new()
	cover.color = Color(0, 0, 0, 0.3)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	cover.position = Vector2.ZERO
	cover.size = Vector2(800, 600)
	root.add_child(cover)
	await frames(2)
	await _finger_swipe(list.get_global_rect().get_center(), Vector2(0, -20))
	await frames(30)
	check(list.scroll_vertical == 0, "örtülü kap parmağı sahiplenmedi (%d)" % list.scroll_vertical)
	cover.queue_free()
	list.queue_free()

	print("== telefon: yatay şerit (kart yakalama) aktarımsız ==")
	var strip: ScrollContainer = _make(true, true)
	await frames(3)
	var strip_cards: Array[Node] = strip.find_children("*", "Button", true, false)
	for card: Node in strip_cards:
		(card as Control).mouse_filter = Control.MOUSE_FILTER_STOP
	await _finger_swipe((strip_cards[0] as Control).get_global_rect().get_center(), Vector2(-20, 0))
	await frames(60)
	var pitch: int = 120 + strip.get_child(1).get_theme_constant("separation")
	check(strip.scroll_horizontal > 0 and strip.scroll_horizontal % pitch == 0,
		"şerit kaydı ve karta oturdu (%d, adım %d)" % [strip.scroll_horizontal, pitch])
	strip.queue_free()
