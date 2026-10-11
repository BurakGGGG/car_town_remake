extends SceneTree
## NECATİ'NİN DERSİ QA: Rıza Usta'nın dersleri bitmiş, hurdalığı açık bir oyuncuyla hurdalığa girer;
## dersi GERÇEK dokunuşlarla (spot ışığı deliğine fare olayı) oynar ve her adımda ekran görüntüsü alır.
## Kullanım: tools/qa_isolated.sh res://qa/junkyard_lesson.gd --display-driver x11 --disable-vsync \
##     --resolution 1152x648
## Çıktı: ~/Projects/ct_shots/junkyard_lesson/
const OUT: String = "/home/burak/Projects/ct_shots/junkyard_lesson/"

var _hud: Hud
var _director: TutorialDirector
var _shot_index: int = 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for file: String in DirAccess.get_files_at(OUT):
		DirAccess.remove_absolute(OUT + file)
	_run.call_deferred()


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	_shot_index += 1
	root.get_texture().get_image().save_png(OUT + "%02d_%s.png" % [_shot_index, label])
	print("QA kare %02d_%s  [%s]" % [_shot_index, label, _state()])


func _state() -> String:
	return "%s/%s #%d" % [_director.get("_state"), _director.get("_chapter"), _director.get("_index")]


func _wait(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _until(condition: Callable, limit: float, label: String) -> bool:
	var until: int = Time.get_ticks_msec() + int(limit * 1000.0)
	while Time.get_ticks_msec() < until:
		if bool(condition.call()):
			return true
		await process_frame
	print("QA ZAMAN AŞIMI: %s  [%s]" % [label, _state()])
	return false


func _tap(point: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		root.push_input(event)
		await process_frame
		await process_frame


func _tap_hole() -> void:
	var rect: Rect2 = _director.overlay.get("_target") if _director.overlay.get("_has_target") else Rect2()
	print("QA delik: %s" % rect)
	await _tap(rect.get_center())


func _run() -> void:
	change_scene_to_file(String(ProjectSettings.get_setting("application/run/main_scene")))
	await _until(func() -> bool: return current_scene != null and current_scene.name != "LoadingScreen" \
		and root.get_node_or_null("LoadingScreen") == null, 30.0, "oyun yüklendi")
	_hud = current_scene.find_child("HUD", true, false) as Hud
	_director = _hud.tutorial
	var manager: TutorialManager = get_first_node_in_group(&"tutorial") as TutorialManager
	for id: StringName in TutorialManager.ALL:
		manager.mark_done(id)
	(get_first_node_in_group(&"repair_bays") as RepairBayManager).load_state(2)
	await _wait(1.0)
	_hud.router.open(&"junkyard")
	await _until(func() -> bool: return _director.get("_state") == &"intro", 20.0, "ders kartı")
	await _wait(0.6)
	await _shot("giris")
	var screen: JunkyardScreen = _hud.junkyard_screen
	var viewport: SubViewport = screen.get("_viewport")
	print("QA görüntü alanı %s, kapsayıcı %s, kamera size %.1f" % [viewport.size, (screen.get("_container") as Control).size, screen.world().camera.size])
	for i: int in screen.world().piles.size():
		print("QA yığın %d ekranda %s" % [i, screen.world().screen_point(screen.world().pile_position(i))])
	await _tap(_find_button(_director.overlay, "BAŞLA").get_global_rect().get_center())
	await _wait(1.2)
	await _shot("necati_hosgeldin")
	_director.call("_on_action")
	await _wait(1.2)
	await _shot("cemo_yigin")
	await _tap_hole()
	await _until(func() -> bool: return int(_director.get("_index")) >= 2, 4.0, "yığın arandı")
	await _wait(1.2)
	await _shot("cemo_parcalar")
	_director.call("_on_action")
	await _wait(1.2)
	await _shot("necati_araclar")
	await _tap_hole()
	await _until(func() -> bool: return int(_director.get("_index")) >= 4, 4.0, "araç plakası")
	await _wait(1.2)
	await _shot("necati_restore")
	_director.call("_on_action")
	await _wait(1.2)
	await _shot("necati_kapanis")
	_director.call("_on_action")
	await _wait(1.0)
	await _shot("damga")
	quit(0)


func _find_button(node: Node, text: String) -> Control:
	for child: Node in node.find_children("*", "Button", true, false):
		if (child as Button).text == Loc.t(text) and (child as Control).is_visible_in_tree():
			return child as Control
	return null
