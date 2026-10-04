extends SceneTree
## KAYDIRMA TESTİ (qa/kaydirma_tarama.gd'nin test hali): iki yol da denenir — fare tut-çek (masaüstü) ve
## telefon yolu (dokunmadan türetilen olaylar, sürüklemeyi kabın kendisi yapar). Her kaydırılabilir alan kaymalı.
## KAYDIRMA TARAMASI: ekranları açar, içeriği taşan (kaydırılabilir) her ScrollContainer'da tutup çekme
## (fare sol tuşu) dener ve kaydırmanın gerçekten gerçekleştiğini ölçer. Telefonda parmak sürüklemesini
## kabın kendisi işler; masaüstünde aynı hareketi TouchScroll sağlar (ui/touch_scroll.gd).
## Kullanım: godot-4 --path . --resolution 1040x480 --script res://qa/kaydirma_tarama.gd [-- telefon]
var _results: Array[String] = []
## "telefon": dokunmatik ekran gibi davran (olaylar dokunmadan türetilmiş sayılır, sürüklemeyi kabın kendisi yapar)
var _phone_path: bool = false
var _fails: int = 0
func frames(n: int) -> void:
	for i: int in n:
		await process_frame
func _initialize() -> void:
	_run.call_deferred()
func _mouse(pos: Vector2, pressed: bool) -> void:
	var e: InputEventMouseButton = InputEventMouseButton.new()
	e.device = InputEvent.DEVICE_ID_EMULATION if _phone_path else 0
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = pos
	e.global_position = pos
	e.pressed = pressed
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(e)
func _move(pos: Vector2, rel: Vector2) -> void:
	var e: InputEventMouseMotion = InputEventMouseMotion.new()
	e.device = InputEvent.DEVICE_ID_EMULATION if _phone_path else 0
	e.position = pos
	e.global_position = pos
	e.relative = rel
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)
func _probe(tag: String, root_node: Node) -> void:
	for node: Node in root_node.find_children("*", "ScrollContainer", true, false):
		var scroll: ScrollContainer = node
		if not scroll.is_visible_in_tree():
			continue
		var horizontal: bool = scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
		var bar: ScrollBar = scroll.get_h_scroll_bar() if horizontal else scroll.get_v_scroll_bar()
		var room: float = bar.max_value - bar.page
		if room < 8.0:
			continue   # içerik sığıyor: kaydırılacak bir şey yok
		var rect: Rect2 = scroll.get_global_rect()
		# görünür alanın kesiti (ekran dışını sayma)
		rect = rect.intersection(get_root().get_visible_rect())
		var start: Vector2 = rect.get_center()
		var step: Vector2 = Vector2(-18, 0) if horizontal else Vector2(0, -18)
		if horizontal:
			scroll.scroll_horizontal = 0
		else:
			scroll.scroll_vertical = 0
		await frames(2)
		_mouse(start, true)
		await frames(1)
		var p: Vector2 = start
		for i: int in 6:
			p += step
			_move(p, step)
			await frames(1)
		_mouse(p, false)
		await frames(2)
		var value: int = scroll.scroll_horizontal if horizontal else scroll.scroll_vertical
		var ok: bool = value > 20
		if not ok:
			_fails += 1
		print(("  OK   " if ok else "  FAIL ") + "%s %s %s (%s)" % [tag, String(scroll.name), "telefon" if _phone_path else "fare", value])
		_results.append("%s  %-6s %-28s taşan %4.0f  sürükleme → %d" % ["OK  " if ok else "FAIL", tag, String(scroll.name), room, value])
func _run() -> void:
	Input.use_accumulated_input = false   # sentetik hareket olayları birleştirilmesin (kararlı ölçüm)
	if DisplayServer.window_get_size().y < 600:
		get_root().content_scale_factor = 1.35
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(90)
	var hud: Hud = main.find_child("HUD", true, false)
	var pp: PlayerProgress = get_first_node_in_group("player_progress")
	pp.load_state(12, 0, 300)
	var own: VehicleOwnership = get_first_node_in_group("vehicle_ownership")
	for entry: Dictionary in CarCatalog.all():
		own.add_vehicle(entry["id"])   # araç şeridi taşsın
	var mm: MissionManager = get_first_node_in_group("missions")
	mm.ensure_current()
	for phone: bool in [false, true]:
		_phone_path = phone
		Input.emulate_touch_from_mouse = phone   # telefon yolu: DisplayServer dokunmatik sayar, kap kendi sürükler
		await _all_screens(hud)
	print("RESULT fails=%d" % _fails)
	quit(1 if _fails > 0 else 0)


func _all_screens(hud: Hud) -> void:
	for id: StringName in [&"quests", &"garage", &"showroom", &"collection", &"settings", &"garage_edit", &"garage_value", &"mastery", &"profile"]:
		hud.router.close_all()
		await frames(8)
		hud.router.open(id)
		await frames(25)
		await _probe(String(id), hud.router.screen(id))
		if id == &"quests":
			for tab: int in [1, 2]:
				hud.quest_screen._on_tab_pressed(tab)
				await frames(10)
				await _probe("quests/%d" % tab, hud.quest_screen)
