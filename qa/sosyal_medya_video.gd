extends SceneTree
## Sosyal medya oyun içi klipleri (Movie Maker ile kaydedilir; ilerlemiş oyuncu kurulur, yalıtılmış kayıt).
##   tools/qa_isolated.sh res://qa/sosyal_medya_video.gd --resolution 1920x1080 --write-movie <x.avi> \
##       --fixed-fps 30 -- <dunya|garaj|drag|kasa|dekor> [saniye]
const OWNED: Array[StringName] = [&"bmw_e60", &"hyundai_getz", &"skoda_kamiq", &"vw_golf_7", &"volvo_s60", &"audi_a3",
	&"honda_civic", &"porsche_gt3", &"mercedes_cls", &"ford_mustang_1967"]
const DECOR: Array[StringName] = [&"workbench", &"engine_block", &"motorcycle", &"sofa", &"coffee_table",
	&"deck_chair", &"warning_sign", &"wall_clock", &"wall_poster", &"neon_garage"]
var hud: Hud
var router: UiRouter
var traffic: TrafficManager
var rm: RepairManager
var own: VehicleOwnership
var _mode: String = ""
var _secs: float = 20.0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_mode = args[0]
	if args.size() > 1:
		_secs = float(args[1])
	Engine.max_fps = 0
	_run.call_deferred()


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _setup() -> void:
	await frames(2)
	change_scene_to_file("res://Main.tscn")
	await frames(70)
	hud = current_scene.find_child("HUD", true, false) as Hud
	router = hud.router
	traffic = current_scene.find_child("Traffic", true, false) as TrafficManager
	rm = get_first_node_in_group("repair_manager") as RepairManager
	own = get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	for id: StringName in OWNED:
		own.add_vehicle(id)
	(get_first_node_in_group("economy") as EconomyManager).set_money(86400)
	(get_first_node_in_group("garage_upgrades") as GarageUpgradeManager).apply_levels({GarageUpgradeManager.GARAGE_ID: 3})
	(get_first_node_in_group("repair_bays") as RepairBayManager).load_state(3)
	await frames(20)


func _click_world(pos: Vector3) -> void:
	var cam: Camera3D = root.get_camera_3d()
	var screen: Vector2 = root.get_final_transform() * cam.unproject_position(pos)
	for pressed: bool in [true, false]:
		var e: InputEventMouseButton = InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.position = screen
		e.global_position = screen
		e.pressed = pressed
		Input.parse_input_event(e)
		await frames(2)


func _auto_repair(seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		for v: TrafficVehicle in traffic.vehicles:
			if v.is_waiting():
				rm.start_repair(v)
			elif v.mode == TrafficVehicle.Mode.REWARD_WAITING:
				rm.collect(v)
		await process_frame
		t += 1.0 / 30.0


func _run() -> void:
	await _setup()
	match _mode:
		"dunya":
			Engine.time_scale = 1.6
			await _auto_repair(_secs)
		"garaj":
			router.open(&"garage")
			await frames(60)
			var gallery: CarGallery = hud.garage_screen.car_list
			for id: StringName in [&"tofas_sahin", &"porsche_gt3", &"mercedes_cls", &"ford_mustang_1967", &"vw_golf_7", &"bmw_e60"]:
				if gallery:
					gallery.select(id)
				await frames(int(_secs * 30.0 / 6.0))
		"drag":
			own.set_race_vehicle(&"porsche_gt3")
			router.open(&"drag_race")
			await frames(30)
			var drag: Node = hud.drag_race_screen
			var launched: bool = false
			var t: float = 0.0
			while t < 40.0 and int(drag.get("_phase")) != 3:
				await process_frame
				t += 1.0 / 30.0
				var p: DragRaceSim.Runner = drag.get("_player")
				var phase: int = int(drag.get("_phase"))
				if phase == 2:
					if not launched:
						launched = true
						drag.call("tap")
					else:
						var caption: Label = drag.get("_shift_caption")
						if bool(drag.get("_shift_hot")) and caption and caption.text == "ŞİMDİ!":
							drag.call("tap")
			await frames(120)
		"kasa":
			var crates: CrateManager = get_first_node_in_group("crates") as CrateManager
			var delivery: CrateDelivery = get_first_node_in_group("crate_delivery") as CrateDelivery
			var uid: int = crates.grant_free(&"city_crate", "qa")
			await frames(90)
			var v: CrateVisual = delivery.visual_of(uid)
			await _click_world(v.global_position + Vector3(0.0, v.size().y * 0.6, 0.0))
			await frames(30)
			hud.crate_panel._action.pressed.emit()
			var t: float = 0.0
			while hud.crate_panel.mode() != &"result" and t < 15.0:
				await process_frame
				t += 1.0 / 30.0
			await frames(150)
		"dekor":
			var decor: DecorManager = get_first_node_in_group("decor") as DecorManager
			var owned: Dictionary = {"floor_tile": 1, "wall_brick": 1}
			for id: StringName in DECOR:
				owned[String(id)] = 1
			decor.load_state({"owned": owned})
			router.open(&"garage_edit")
			await frames(40)
			var editor: GarageEditor = get_first_node_in_group("garage_editor") as GarageEditor
			var view: GarageDecorView = get_first_node_in_group("garage_decor_view") as GarageDecorView
			var r: Rect2 = view.area().floor_rect
			var slots: Array[Vector2] = []
			for row: int in 3:
				for col: int in 4:
					slots.append(Vector2(r.position.x + r.size.x * (0.16 + 0.22 * col), r.position.y + r.size.y * (0.30 + 0.30 * row)))
			slots.shuffle()
			editor.apply_surface(DecorManager.SURFACE_FLOOR, &"floor_tile")
			await frames(20)
			editor.apply_surface(DecorManager.SURFACE_WALL, &"wall_brick")
			await frames(20)
			for id: StringName in DECOR:
				if not (editor.begin_place(id) and editor.confirm_ghost()):
					continue
				if GarageDecor.placement(id) != GarageDecor.PLACE_WALL:
					var pos: Vector3 = view.place_point(id, slots.pop_back(), 0.0, editor.snap_step())["pos"]
					editor.move_to(editor.selected(), pos, 0.0)
				await frames(24)
			editor.select("")
			await frames(60)
	quit(0)
