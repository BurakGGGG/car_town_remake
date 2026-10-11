extends SceneTree
## HURDALIK AKIŞI QA: temiz kayıtla oyunu açar, 2. tamir alanını açar, HARİTA → yolculuk → hurdalık →
## yığın arama → araç plakası → PARÇALAR → HARİTA → şehre dönüş akışını GERÇEK dokunuşlarla oynar ve her
## adımda ekran görüntüsü alır.
## Kullanım: CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/junkyard_flow.gd --display-driver x11 \
##     --disable-vsync --resolution 1152x648
## Çıktı: ~/Projects/ct_shots/junkyard_flow/
const OUT: String = "/home/burak/Projects/ct_shots/junkyard_flow/"

var _hud: Hud
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
	print("QA kare %02d_%s" % [_shot_index, label])


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
	print("QA ZAMAN AŞIMI: %s" % label)
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


func _tap_control(control: Control) -> void:
	print("QA dokun: %s %s" % [control.name, control.get_global_rect()])
	await _tap(control.get_global_rect().get_center())


func _run() -> void:
	change_scene_to_file(String(ProjectSettings.get_setting("application/run/main_scene")))
	await _until(func() -> bool: return current_scene != null and current_scene.name != "LoadingScreen" \
		and root.get_node_or_null("LoadingScreen") == null, 30.0, "oyun yüklendi")
	_hud = current_scene.find_child("HUD", true, false) as Hud
	await _wait(2.0)
	var bays: RepairBayManager = get_first_node_in_group(&"repair_bays") as RepairBayManager
	var jy: JunkyardManager = get_first_node_in_group(&"junkyard") as JunkyardManager
	print("QA hurdalık açık mı (başta): %s" % jy.is_open())
	bays.load_state(2)
	bays.bays_changed.emit()
	await _wait(0.5)
	print("QA hurdalık açık mı (2 alan): %s, HARİTA görünür: %s" % [jy.is_open(), _hud.map_button.visible])
	await _shot("sehir_harita_plakasi")

	await _tap_control(_hud.map_button)
	await _wait(0.6)
	await _shot("harita")
	var map: MapScreen = _hud.map_screen
	await _tap_control(map.get("_pins")[&"junkyard"])
	await _wait(0.8)
	await _shot("yolculuk")
	await _until(func() -> bool: return _hud.junkyard_screen.visible, 5.0, "hurdalık açıldı")
	await _wait(1.5)
	await _shot("hurdalik")
	print("QA ziyaret: %d, sahadaki araçlar: %s" % [jy.visit_count(), jy.yard_cars()])

	var screen: JunkyardScreen = _hud.junkyard_screen
	var world: JunkyardWorld = screen.world()
	var pile_point: Vector2 = world.screen_point(world.pile_position(1) + Vector3.UP * 0.9)
	print("QA yığın 1 ekranda: %s" % pile_point)
	await _tap(pile_point)
	await _wait(0.5)
	await _shot("yigin_sallaniyor")
	await _wait(0.9)
	await _shot("yigin_sonuc")
	print("QA envanter: %s" % jy.inventory())
	await _wait(1.0)

	var car_point: Vector2 = world.screen_point(world.car_position(1) + Vector3.UP * 0.7)
	print("QA araç 1 ekranda: %s" % car_point)
	await _tap(car_point)
	await _wait(0.4)
	await _shot("arac_plakasi")
	await _tap_control(screen.get("_car_layer").find_child("*", true, false) as Control)
	await _wait(0.3)
	screen.get("_car_layer").hide()
	await _tap_control(screen.get("_parts_button"))
	await _wait(0.4)
	await _shot("parcalar")
	screen.get("_parts_layer").hide()

	# Kamera: sürükleme ile kaydır
	var drag_from: Vector2 = Vector2(700, 300)
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = drag_from
	press.global_position = drag_from
	root.push_input(press)
	for k: int in 20:
		var motion: InputEventMouseMotion = InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.position = drag_from + Vector2(k * 14.0, k * 4.0)
		motion.global_position = motion.position
		motion.relative = Vector2(14.0, 4.0)
		root.push_input(motion)
		await process_frame
	press = press.duplicate() as InputEventMouseButton
	press.pressed = false
	root.push_input(press)
	await _wait(0.5)
	await _shot("kaydirildi")

	await _tap_control(_find_button(screen, "HARİTA"))
	await _wait(0.6)
	await _shot("harita_hurdaliktan")
	await _tap_control(map.get("_pins")[&"city"])
	await _until(func() -> bool: return not map.visible, 5.0, "şehre dönüldü")
	await _wait(1.0)
	await _shot("sehre_donus")
	var quests: QuestManager = get_first_node_in_group(&"quests") as QuestManager
	print("QA görev junkyard_visit tamam: %s" % quests.is_complete(&"junkyard_visit"))
	quit(0)


func _find_button(node: Node, text: String) -> Control:
	for child: Node in node.find_children("*", "PlateButton", true, false):
		if (child as PlateButton).text == Loc.t(text):
			return child as Control
	return null
