extends SceneTree
## RESTORASYON AŞAMALARI QA: temiz kayıtla garajda bir restorasyon projesi başlatır, kamerayı tamir alanına
## yaklaştırır ve üç aşamanın (çıplak şasi / paslı araç / temiz araç) + proje panosunun görüntüsünü alır.
## Kullanım: CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/restoration_stages.gd --display-driver x11 \
##     --disable-vsync --resolution 1152x648 [-- <araç_id>]
## Çıktı: ~/Projects/ct_shots/restoration/
const OUT: String = "/home/burak/Projects/ct_shots/restoration/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func _wait(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + label + ".png")
	print("QA kare ", label)


func _run() -> void:
	change_scene_to_file(String(ProjectSettings.get_setting("application/run/main_scene")))
	var until: int = Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < until and (current_scene == null or current_scene.name == "LoadingScreen" \
			or root.get_node_or_null("LoadingScreen") != null):
		await process_frame
	await _wait(1.5)
	var id: StringName = StringName(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 \
		else &"vw_beetle_1967"
	var jy: JunkyardManager = get_first_node_in_group(&"junkyard") as JunkyardManager
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	for part_id: StringName in RestorationCatalog.recipe(id):
		jy.add_parts(part_id, RestorationCatalog.required(id, part_id), &"debug")
	print("QA başlat: ", jy.start(id), " alan ", jy.bay_of(id))
	await _wait(1.6)   # lift kalksın
	var bays: RestorationBays = get_first_node_in_group(&"restoration_bays") as RestorationBays
	var display: RestorationDisplay = bays.display_of(id)
	var camera: WorldCamera = current_scene.get_viewport().get_camera_3d() as WorldCamera
	var at: Vector3 = display.global_position
	camera.frame_box(AABB(at - Vector3(0.7, 0.0, 0.7), Vector3(1.4, 0.7, 1.4)), 0.2, 0.8, 0.1, 1.2)
	await _wait(0.8)
	await _shot("1_sasi")
	# Parça türlerinin yarısı takılır (~%50: paslı araç aşaması)
	var parts: Array = RestorationCatalog.recipe(id).keys()
	for k: int in int(ceil(parts.size() * 0.5)):
		jy.install(id, parts[k])
	print("QA ilerleme: ", jy.progress(id))
	await _wait(0.4)
	await _shot("2_pasli")
	hud.restoration_panel.vehicle_id = id
	hud.router.open(&"restoration")
	await _wait(0.6)
	await _shot("3_pano")
	hud.router.close_all()
	jy.install_all(id)
	await _wait(0.5)
	await _shot("4_temiz")
	quit(0)
