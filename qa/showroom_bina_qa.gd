extends SceneTree
## YENİ SHOWROOM BİNASI QA — gerçek tıklamayla showroom ekranı açılıyor mu (tıklama kutusu yeni binaya
## uyduruldu), eski CSG galeri gizli mi, binanın çizim maliyeti ne kadar (aynı karede açık / kapalı).
##   godot-4 --path . --resolution 1152x648 -s res://qa/showroom_bina_qa.gd

var fails: int = 0


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await frames(80)
	(get_first_node_in_group("save_manager") as SaveManager).new_game()
	await frames(10)
	var dressing: Node3D = current_scene.get_node_or_null("WorldDressing") as Node3D
	check(dressing != null, "WorldDressing sahnede")
	var showroom: Node3D = dressing.get_node_or_null("Showroom") as Node3D if dressing else null
	check(showroom != null, "yeni showroom binası kurulu")
	var gallery: Node = current_scene.get_node("GrassArea/Gallery")
	var hidden: bool = true
	for child: Node in gallery.get_children():
		if child is CSGShape3D and (child as CSGShape3D).visible:
			hidden = false
	check(hidden, "eski CSG galerinin görselleri gizli")

	# Kamera binaya: salonun ortasına gerçek fare tıklaması
	var camera: WorldCamera = get_root().get_camera_3d() as WorldCamera
	camera.set("_focus", Vector3(4.6, 0.0, -2.8))
	camera.call("_apply_focus")
	await frames(20)
	var hall: Vector3 = WorldDressing.LOT_ORIGIN + Vector3(28.0, 4.0, -22.0) * WorldDressing.METER
	var at: Vector2 = camera.unproject_position(hall)
	var k: float = float(DisplayServer.window_get_size().y) / get_root().get_visible_rect().size.y
	for down: bool in [true, false]:
		var e: InputEventMouseButton = InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = at * k
		e.global_position = at * k
		Input.parse_input_event(e)
		await frames(3)
	await frames(30)
	var router: UiRouter = current_scene.find_child("HUD", true, false).get("router")
	check(router.top() == &"showroom", "binaya tıklayınca showroom ekranı açıldı (%s)" % router.top())
	router.close_all()
	await frames(40)

	# Çizim maliyeti: aynı görünümde bina açık / kapalı
	camera.set("_focus", Vector3.ZERO)
	camera.call("_apply_focus")
	await frames(20)
	var with_building: int = await _draw_calls()
	showroom.visible = false
	for label: Node in dressing.get_children():
		if label is Label3D:
			(label as Label3D).visible = false
	var without: int = await _draw_calls()
	showroom.visible = true
	print("   varsayılan görünüm çizim çağrısı: bina açık %d, kapalı %d (fark %d)" % [with_building, without,
		with_building - without])
	check(with_building - without <= 70, "bina en çok 70 çizim çağrısı ekliyor (%d)" % (with_building - without))
	print("RESULT fails=%d" % fails)
	quit(0 if fails == 0 else 1)


func _draw_calls() -> int:
	await frames(5)
	var total: int = 0
	for i: int in 5:
		await RenderingServer.frame_post_draw
		total += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		RenderingServer.force_draw()
	return total / 5
