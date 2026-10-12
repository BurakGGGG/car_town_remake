extends SceneTree
## ARAÇLAR → DETAY TABLETTE — panel ekrana sığıyor mu? Mobil ölçekle (content_scale_factor 1,35) açar,
## araç ekranında DETAY panelini açar, panelin ve sağ sütunun ekrana göre yerini yazar, görüntü alır.
##   godot-4 --path . --resolution 1024x768 -s res://qa/tablet_detay.gd -- 4x3    (override.cfg ile)
##   godot-4 --path . --resolution 1280x800 -s res://qa/tablet_detay.gd -- 16x10

const OUT: String = "/home/burak/Projects/ct_shots/tablet_detay/"


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var tag: String = args[0] if args.size() > 0 else "ekran"
	if args.size() > 1:
		Loc.use(args[1])
		tag += "_" + args[1]
	get_root().content_scale_factor = 1.35   # telefon / tablet ölçeği (project.godot scale.mobile)
	change_scene_to_file("res://Main.tscn")
	await frames(90)
	var hud: Node = current_scene.find_child("HUD", true, false)
	var router: UiRouter = hud.get("router")
	router.open(&"garage")
	await frames(30)
	var screen: Control = router.screen(&"garage") as Control
	screen.call("_open_detail")
	await frames(20)
	var visible_rect: Rect2 = get_root().get_visible_rect()
	var panel: Control = screen.find_child("DetailPanel", true, false) as Control
	var worst: Rect2 = Rect2()
	var worst_id: StringName = &""
	var bad: int = 0
	for entry: Dictionary in CarCatalog.all():
		var id: StringName = StringName(String(entry["id"]))
		screen.set("_shown_vehicle", id)
		screen.call("_refresh_detail")
		await frames(3)
		var r: Rect2 = panel.get_global_rect()
		if r.size.y * r.size.x > worst.size.y * worst.size.x:
			worst = r
			worst_id = id
		if not visible_rect.encloses(r):
			bad += 1
			print("   TAŞIYOR %-22s %s" % [id, r])
	print("%s · tuval %s · %d araç · en büyük panel %s %s · taşan %d" % [tag, visible_rect.size,
		CarCatalog.size(), worst_id, worst, bad])
	screen.set("_shown_vehicle", worst_id)
	screen.call("_refresh_detail")
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(OUT + tag + ".png")
	quit(0 if bad == 0 else 1)
