extends SceneTree
## 16 ARAÇ KASA ÇIKIŞ KONTROLÜ — her aracı kasadan GERÇEKTEN çıkarır (satın alınmış kasanın sonucu
## o araca sabitlenir, sonra normal açılış akışı oynar) ve ölçer:
##   * model = katalogdaki scene_path, ölçek = trafik bağlamı × CarCatalog.model_scale,
##   * zemin teması: tekerlek (wheel/tire/rim rolleri) alt kotu ile garaj zemini arasındaki fark,
##   * gövde zemine girmiş mi (tüm mesh'lerin alt kotu),
##   * uzun eksen kasa uzun ekseniyle hizalı mı, katalog adı/nadirliği sonuç plakasıyla aynı mı.
## Yakın plan görüntü: /home/burak/Projects/ct_shots/crate/vehicles/<id>.png
## Çalıştırma: godot-4 --path . --resolution 1170x540 -s res://qa/crate_vehicle_check.gd (override.cfg ile)

const OUT: String = "/home/burak/Projects/ct_shots/crate/vehicles/"
## Tekerlek temas toleransı (dünya birimi; araç boyu ~0,6): 4 mm üstü "havada", -4 mm altı "gömülü".
const TOL: float = 0.004

var fails: int = 0


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func _init() -> void:
	_run()


func world_bounds(root: Node3D, name_filter: Array[String]) -> AABB:
	var merged: AABB = AABB()
	var first: bool = true
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D and (node as MeshInstance3D).visible:
			var mi: MeshInstance3D = node
			var matches: bool = name_filter.is_empty()
			for f: String in name_filter:
				if String(mi.name).to_lower().contains(f) or String(mi.get_meta(&"car_role", "")).contains(f):
					matches = true
			if matches:
				var box: AABB = mi.global_transform * mi.get_aabb()
				merged = box if first else merged.merge(box)
				first = false
		for child: Node in node.get_children():
			stack.append(child)
	return merged if not first else AABB()


## CarRig'in dönen tekerlek grupları (CarRig._wheel_groups[i]["meshes"]); yoksa tires/rims rolleri.
func wheel_nodes(car: Node3D) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var rig: CarRig = CarRig.for_node(car)
	for group: Dictionary in rig._wheel_groups:
		for n: Variant in group.get("meshes", []):
			if n is MeshInstance3D and not out.has(n):
				out.append(n)
	if out.is_empty():
		for role: StringName in [&"tires", &"rims", &"wheels"]:
			for n: MeshInstance3D in rig.get_meshes(role):
				if not out.has(n):
					out.append(n)
	return out


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	await process_frame
	change_scene_to_file("res://Main.tscn")
	await create_timer(3.0).timeout
	var save: SaveManager = get_first_node_in_group("save_manager")
	save.new_game()
	await create_timer(0.8).timeout
	var crates: CrateManager = get_first_node_in_group("crates")
	var delivery: CrateDelivery = get_first_node_in_group("crate_delivery")
	var view: GarageDecorView = get_first_node_in_group("garage_decor_view")
	var camera: WorldCamera = get_root().get_camera_3d() as WorldCamera
	var floor_y: float = view.area().floor_y
	print("zemin y = %.4f" % floor_y)
	print("araç | kasa | nadirlik | ölçek (beklenen) | tekerlek alt − zemin | gövde alt − zemin | hizalı | plaka")
	for entry: Dictionary in CarCatalog.all():
		var id: StringName = entry["id"]
		var crate_id: StringName = CrateCatalog.crate_of(id)
		if crate_id == &"":
			crate_id = &"city_crate"   # başlangıç aracı (Şahin) kasada yok; çıkış görünümü yine ölçülür
		var uid: int = crates.grant_free(crate_id, "qa")
		crates._find(uid)["vehicle"] = id   # QA: sonucu bu araca sabitle (akışın geri kalanı normal)
		var t: float = 0.0
		while not crates.can_open(uid) and t < 4.0:
			await create_timer(0.1).timeout
			t += 0.1
		var got: Array = []
		var cb: Callable = func(u: int, r: Dictionary) -> void: got.append(r)
		delivery.reveal_ready.connect(cb)
		delivery.open_crate(uid)
		t = 0.0
		while got.is_empty() and t < 8.0:
			await create_timer(0.1).timeout
			t += 0.1
		delivery.reveal_ready.disconnect(cb)
		var car: Node3D = delivery.find_child("RevealedVehicle", true, false) as Node3D
		if car == null or got.is_empty():
			check(false, "%s: araç çıkmadı" % id)
			continue
		await create_timer(0.3).timeout
		var expected_scale: float = CrateDelivery.VEHICLE_SCALE * CarCatalog.model_scale(id)
		var body: AABB = world_bounds(car, [])
		var wheels: Array[MeshInstance3D] = wheel_nodes(car)
		var wheel_bottom: float = INF
		for w: MeshInstance3D in wheels:
			wheel_bottom = minf(wheel_bottom, (w.global_transform * w.get_aabb()).position.y)
		var crate_v: CrateVisual = delivery.visual_of(uid)
		var crate_long_x: bool = true
		if crate_v:
			crate_long_x = absf(fmod(crate_v.rotation_degrees.y, 180.0)) < 45.0
		var car_long_x: bool = body.size.x > body.size.z
		var aligned: bool = crate_long_x == car_long_x
		var plate_ok: bool = got[0]["vehicle"] == id and StringName(got[0]["rarity"]) == StringName(entry["rarity"])
		var wheel_gap: float = wheel_bottom - floor_y if wheel_bottom < INF else NAN
		var body_gap: float = body.position.y - floor_y
		print("%s | %s | %s | %.3f (%.3f) | %s | %+.4f | %s | %s" % [id, crate_id, entry["rarity"], car.scale.x, expected_scale,
			("%+.4f" % wheel_gap) if wheel_bottom < INF else "tekerlek yok", body_gap, aligned, plate_ok])
		check(is_equal_approx(car.scale.x, expected_scale), "%s: ölçek trafik bağlamıyla aynı" % id)
		check(wheel_bottom < INF and absf(wheel_gap) <= TOL, "%s: tekerlekler zemine oturuyor (%s)" % [id, ("%+.4f" % wheel_gap) if wheel_bottom < INF else "?"])
		check(body_gap >= -TOL, "%s: gövde zemine gömülmüyor (%+.4f)" % [id, body_gap])
		check(aligned, "%s: araç kasanın uzun ekseniyle hizalı" % id)
		check(plate_ok, "%s: sonuç = katalog (ad, nadirlik %s)" % [id, entry["rarity"]])
		# Yakın plan
		if camera:
			var c: Vector3 = body.get_center()
			camera.frame_box(AABB(Vector3(c.x - 0.45, floor_y, c.z - 0.45), Vector3(0.9, 0.45, 0.9)), 0.15, 0.85)
			await create_timer(0.7).timeout
			await RenderingServer.frame_post_draw
			get_root().get_texture().get_image().save_png(OUT + String(id) + ".png")
		delivery.finish_reveal(uid)
		await create_timer(0.9).timeout
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
