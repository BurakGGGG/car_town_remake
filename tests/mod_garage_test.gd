extends SceneTree
## MODİFİYE GARAJI (ModGarageView, kullanıcı isteği 2026-10-22): oda kurulur, araç döner tablada, aynalı kopya tablanın
## altında; her kategoride kamera odanın ve tablanın çevresindeki eşyasız dairenin içinde kalır, hedefe bakar; çıkışta
## ödünç alınan kamera / ışık / gizlenen düğümler eski hâline döner. Dönük parçalı modelde (BMW E60) sınır kutusu gerçek
## boyda ölçülür (eskiden 3 kat geniş çıkıyor, kamera köşe kolonuna girip ekran simsiyah kalıyordu).
## Çalıştırma: tools/run_tests.sh mod_garage_test
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
	assert(not OS.get_user_data_dir().ends_with("/AUTO YARD") and not OS.get_user_data_dir().ends_with("/CarTownRemake"))
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(853, 480)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.0
	viewport.add_child(camera)
	camera.position = Vector3(6.4, 4.6, 6.4)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	viewport.add_child(key)
	var old_room: Node3D = Node3D.new()
	viewport.add_child(old_room)
	var view: ModGarageView = ModGarageView.new()
	root.add_child(view)
	await frames(1)
	var camera_before: Transform3D = camera.transform

	print("== 1) Giriş ==")
	check(GarageInterior.has_scene(ModGarageView.GARAGE), "modifiye garajı sahnesi var (assets/garages/modgarage)")
	check(view.enter(&"tofas_sahin", viewport, camera, key, [old_room]), "kipe girildi")
	await frames(2)
	check(view.active and view.interior != null and not old_room.visible, "oda kuruldu, eski oda gizli")
	var car: Node3D = view.get("_car")
	var mirror: Node3D = view.get("_mirror")
	check(is_instance_valid(car) and is_instance_valid(mirror), "araç ve aynalı kopyası var")
	var plane_y: float = view.get("_plane_y")
	check(is_instance_valid(mirror) and mirror.global_transform.basis.determinant() < 0.0
		and absf((mirror.global_position.y + car.global_position.y) * 0.5 - plane_y) < 0.001,
		"kopya tablanın üstüne göre aynalı (y ekseni ters, düzlem ortada)")
	check(camera.projection == Camera3D.PROJECTION_PERSPECTIVE and (key.light_cull_mask & ModGarageView.MIRROR_LAYER) == 0,
		"perspektif kamera; anahtar ışık aynalı kopyayı aydınlatmaz")
	var top: MeshInstance3D = view.interior.part("TableTop") as MeshInstance3D
	check(top != null and top.get_surface_override_material(0) is ShaderMaterial, "tablanın üstü yarı saydam yansıma malzemesiyle")
	var top_y: float = (top.global_transform * top.get_aabb()).end.y if top else INF
	check(absf(car.global_position.y - top_y) < 0.0005 and absf(plane_y - top_y) < 0.0005,
		"araç tablanın görünen üstünde (kök %.4f, tabla %.4f): lastiklerin altı tablaya gömülmez" % [car.global_position.y, top_y])

	print("== 2) Kategoriler: kamera odada ve hedefe bakıyor ==")
	var room: AABB = view.get("_room")
	var pivot: Node3D = view.get("_pivot")
	var limit: float = ModGarageView.SAFE_RADIUS * GarageInterior.METER + 0.001
	for category: StringName in [&"", &"motor", &"turbo", &"air", &"gear", &"tire", &"body"]:
		view.focus(category, false)
		await frames(1)
		var p: Vector3 = camera.global_position
		var flat: float = Vector2(p.x - pivot.global_position.x, p.z - pivot.global_position.z).length()
		var target: Vector3 = car.to_global((view.get("_cam") as Dictionary)["at"])
		var facing: float = (-camera.global_basis.z).dot((target - p).normalized())
		check(room.grow(0.001).has_point(p) and flat <= limit and facing > 0.99 and camera.fov <= ModGarageView.MAX_FOV + 0.01,
			"%s: kamera odada (merkezden %.2f ≤ %.2f), hedefe bakıyor (%.3f), görüş %.0f°" % [
				category if category != &"" else &"genel", flat, limit, facing, camera.fov])
	view.focus(&"tire", false)
	var wheel_target: Vector3 = (view.get("_cam") as Dictionary)["at"]
	var bounds: AABB = view.get("_bounds")
	check(wheel_target.z > bounds.get_center().z, "LASTİK & JANT çekimi ön tekere bakar")
	view.focus(&"", true)
	await create_timer(ModGarageView.MOVE_TIME + 0.1).timeout   # kamera genel bakışa vardı
	var yaw0: float = view.get("_yaw")
	await create_timer(0.5).timeout
	check(not is_equal_approx(float(view.get("_yaw")), yaw0), "genel bakışta tabla kendiliğinden döner")

	print("== 3) Çıkış ==")
	view.exit()
	await frames(2)
	check(not view.active and old_room.visible, "kip kapandı, eski oda geri geldi")
	check(camera.transform.is_equal_approx(camera_before) and camera.projection == Camera3D.PROJECTION_ORTHOGONAL
		and key.light_cull_mask == 0xFFFFFFFF, "kamera ve anahtar ışık eski ayarında")
	check(not is_instance_valid(car) or not car.is_inside_tree(), "araç ve oda serbest bırakıldı")

	print("== 4) Dönük parçalı model: gerçek sınır ==")
	check(view.enter(&"bmw_e60", viewport, camera, key, [old_room]), "BMW E60 ile girildi")
	await frames(2)
	var e60: AABB = view.get("_bounds")
	check(e60.size.x < 0.6 and e60.size.z < 1.15, "E60 sınırı gerçek boyda (genişlik %.2f, boy %.2f; eskiden 1,34 / 1,39)" % [
		e60.size.x, e60.size.z])
	view.focus(&"", false)
	await frames(1)
	var flat_e60: float = Vector2(camera.global_position.x - (view.get("_pivot") as Node3D).global_position.x,
		camera.global_position.z - (view.get("_pivot") as Node3D).global_position.z).length()
	check(flat_e60 <= limit, "kamera köşe kolonuna girmiyor (merkezden %.2f)" % flat_e60)
	view.exit()
	await frames(2)

	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
