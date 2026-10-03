extends SceneTree
## Dünya nesnesi tıklama denemesi: aynı fare enjeksiyonuyla genişletme tabelası ve teslimat kasası.
## Işının ilk çarptığı gövdeyi de yazar (neyin tıklamayı yuttuğunu bulmak için).

func _init() -> void:
	_run()


func click(viewport_pos: Vector2) -> void:
	# Kamera izdüşümü görüntü alanı koordinatıdır; olay pencere koordinatı ister (canvas_items ölçeği)
	var pos: Vector2 = root.get_final_transform() * viewport_pos
	for pressed: bool in [true, false]:
		var e: InputEventMouseButton = InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.position = pos
		e.global_position = pos
		e.pressed = pressed
		Input.parse_input_event(e)
		for i: int in 3:
			await physics_frame
			await process_frame


func ray_hit(cam: Camera3D, pos: Vector2) -> String:
	var from: Vector3 = cam.project_ray_origin(pos)
	var to: Vector3 = from + cam.project_ray_normal(pos) * 100.0
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	q.collide_with_areas = true
	var hit: Dictionary = cam.get_world_3d().direct_space_state.intersect_ray(q)
	return str(hit.get("collider").get_path()) if hit.has("collider") else "(hiçbiri)"


func _run() -> void:
	await process_frame
	change_scene_to_file("res://Main.tscn")
	await create_timer(3.0).timeout
	var save: SaveManager = get_first_node_in_group("save_manager")
	save.new_game()
	await create_timer(1.0).timeout
	var hud: Hud = root.get_node("World/HUD")
	var garage: Node = get_first_node_in_group("garage_system")
	var cam: Camera3D = root.get_camera_3d()
	print("viewport %s  pencere %s  picking %s" % [root.get_visible_rect().size, DisplayServer.window_get_size(), root.physics_object_picking])
	var got: Array = []
	garage.connect(&"expand_clicked", func() -> void: got.append("sign"))
	var sign: Node3D = garage.get("_sign")
	var sp: Vector2 = cam.unproject_position(sign.global_position + Vector3(0, 0.38, 0))
	print("tabela ekran %s ışın: %s" % [sp, ray_hit(cam, sp)])
	await click(sp)
	print("tabela tıklandı mı: %s" % [got])
	var crates: CrateManager = get_first_node_in_group("crates")
	var delivery: CrateDelivery = get_first_node_in_group("crate_delivery")
	var uid: int = crates.grant_free(&"city_crate", "qa")
	await create_timer(1.5).timeout
	var v: CrateVisual = delivery.visual_of(uid)
	delivery.crate_clicked.connect(func(u: int) -> void: got.append("crate%d" % u))
	var cp: Vector2 = cam.unproject_position(v.global_position + Vector3(0, v.size().y * 0.6, 0))
	print("kasa ekran %s ışın: %s  pickable %s" % [cp, ray_hit(cam, cp), v.get_node("ClickBody").input_ray_pickable])
	await click(cp)
	print("kasa tıklandı mı: %s  panel=%s" % [got, hud.crate_panel.mode()])
	quit()
