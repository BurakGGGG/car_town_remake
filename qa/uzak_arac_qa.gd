extends SceneTree
## UZAK ARAÇ GÖRÜNÜMÜ — şehri oyunun kendi kamerasıyla en uzak zoom'da çeker ve trafikteki her aracı ayrı PNG'ye kırpar
## (zoom out'ta renk / doku bozulması teşhisi). HUD gizli, time_scale ile trafik hızlanır, aynı model bir kez kaydedilir.
##   tools/qa_isolated.sh res://qa/uzak_arac_qa.gd --display-driver x11 --resolution 1152x648 -- [zoom 5.0] [sure 120] [ad x]
## Çıktı: /home/burak/Projects/ct_shots/uzak/<ad>/genel.png + <araç_id>.png

const OUT: String = "/home/burak/Projects/ct_shots/uzak/"


func _initialize() -> void:
	_run.call_deferred()


func _arg(name: String, fallback: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var at: int = args.find(name)
	return args[at + 1] if at >= 0 and at + 1 < args.size() else fallback


func _run() -> void:
	var zoom: float = float(_arg("zoom", "5.0"))
	var seconds: float = float(_arg("sure", "120"))
	var dir: String = OUT + _arg("ad", "oyun_z%s" % _arg("zoom", "5.0")) + "/"
	DirAccess.make_dir_recursive_absolute(dir)
	change_scene_to_file("res://Main.tscn")
	for i: int in 120:
		await process_frame
	var hud: CanvasLayer = current_scene.find_child("HUD", true, false) as CanvasLayer
	if hud:
		hud.visible = false
	var camera: WorldCamera = root.get_camera_3d() as WorldCamera
	camera.follow(Vector3(0.6, 0.0, 0.6), zoom)
	Engine.time_scale = 3.0
	var traffic: TrafficManager = get_first_node_in_group(&"traffic") as TrafficManager
	var seen: Dictionary = {}
	var start: int = Time.get_ticks_msec()
	var shot_general: bool = false
	while float(Time.get_ticks_msec() - start) / 1000.0 < seconds / Engine.time_scale:
		for i: int in 20:
			await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		if not shot_general and float(Time.get_ticks_msec() - start) > 4000.0:
			img.save_png(dir + "genel.png")
			shot_general = true
		var vehicles: Array = traffic.vehicles if traffic else []
		for v: TrafficVehicle in vehicles:
			if seen.has(v.vehicle_id) or v.model == null or not is_instance_valid(v.model):
				continue
			if v.rig == null or not v.rig.is_merged():
				continue
			var box: AABB = AABB()
			var first: bool = true
			for m: MeshInstance3D in v.model.find_children("*", "MeshInstance3D", true, false):
				if not m.is_visible_in_tree() or m.mesh == null:
					continue
				var b: AABB = m.global_transform * m.get_aabb()
				box = b if first else box.merge(b)
				first = false
			if first:
				continue
			var r: Rect2 = Rect2()
			var behind: bool = false
			for i: int in 8:
				var p: Vector3 = box.position + Vector3(box.size.x if (i & 1) else 0.0, box.size.y if (i & 2) else 0.0, box.size.z if (i & 4) else 0.0)
				if camera.is_position_behind(p):
					behind = true
				var sp: Vector2 = camera.unproject_position(p)
				r = Rect2(sp, Vector2.ZERO) if i == 0 else r.expand(sp)
			var screen: Rect2 = Rect2(Vector2.ZERO, Vector2(img.get_size()))
			if behind or not screen.grow(-8).encloses(r):
				continue
			seen[v.vehicle_id] = true
			img.get_region(Rect2i(r.grow(4).intersection(screen))).save_png(dir + String(v.vehicle_id) + ".png")
	print("uzak_arac_qa: %d model → %s" % [seen.size(), dir])
	quit(0)
