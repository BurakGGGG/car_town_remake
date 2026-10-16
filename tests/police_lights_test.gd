extends SceneTree
## POLİS TAVAN IŞIKLARI (vehicles/police_lights.gd): yalnızca police_lights rolü olan araçta kurulur; lens materyali
## o parçalara takılır ve görünüm yeniden uygulanınca da kalır; yan düzlemi parçanın ARAÇ uzayındaki x'ini verir;
## hale mesh'i haritadaki her nokta için bir dörtgen; lens parçaları birleştirmeye girmez; kip değişimi iki
## materyale de gider; polis araçları boyanmaz (trafikte de fabrika renginde).
## Kullanım: tools/run_tests.sh police_lights_test

const POLICE: Array[StringName] = [&"police_vito", &"police_bentley"]

var fails: int = 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("  OK   ", what)
	else:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== katalog ==")
	var with_lights: Array[StringName] = []
	for entry: Dictionary in CarCatalog.all():
		if not (CarPartMap.get_map(entry["scene_path"]).get("police_lights", []) as Array).is_empty():
			with_lights.append(entry["id"])
	check(with_lights == POLICE, "ışık rolü yalnızca iki polis aracında %s" % [with_lights])
	for id: StringName in POLICE:
		check(not VehicleOwnership.is_paintable(id), "%s boyanmaz (kaplama)" % id)
		check(not (CarPartMap.get_map(CarCatalog.scene_path(id)).get("beacons", []) as Array).is_empty(), "%s: hale noktaları var" % id)
	check(VehicleOwnership.is_paintable(&"togg_t10x") and VehicleOwnership.is_paintable(&"tofas_sahin"), "normal araçlar boyanır")

	print("== yan düzlemi ==")
	var xf: Transform3D = Transform3D(Basis(Vector3.UP, 0.4).scaled(Vector3(1.7, 1.7, 1.7)), Vector3(0.3, -0.1, 0.2))
	var plane: Vector4 = PoliceLights.side_plane(xf)
	var worst: float = 0.0
	for v: Vector3 in [Vector3(0.1, 0.2, -0.3), Vector3(-0.25, 0.05, 0.4), Vector3(0.0, 0.0, 0.0)]:
		worst = maxf(worst, absf(Vector3(plane.x, plane.y, plane.z).dot(v) + plane.w - (xf * v).x))
	check(worst < 1e-5, "side_plane köşenin araç uzayındaki x'ini verir (hata %.2e)" % worst)

	print("== rig ==")
	for id: StringName in POLICE:
		var car: Node3D = (load(CarCatalog.scene_path(id)) as PackedScene).instantiate()
		root.add_child(car)
		var rig: CarRig = CarRig.new(car)
		var appearance: CarAppearance = CarAppearance.get_for(car.scene_file_path)
		rig.apply(appearance)
		var lights: Array[MeshInstance3D] = rig.get_meshes(&"police_lights")
		check(rig.has_police_lights() and not lights.is_empty(), "%s: ışık sistemi kuruldu (%d parça)" % [id, lights.size()])
		var lens_ok: bool = true
		for mesh: MeshInstance3D in lights:
			var material: ShaderMaterial = mesh.get_surface_override_material(0) as ShaderMaterial
			lens_ok = lens_ok and material != null and material.shader == PoliceLights.LENS_SHADER
		check(lens_ok, "%s: lens materyali bütün ışık parçalarında" % id)
		rig.apply(appearance)   # görünüm yeniden uygulanınca da kalmalı
		var still: ShaderMaterial = lights[0].get_surface_override_material(0) as ShaderMaterial
		check(still != null and still.shader == PoliceLights.LENS_SHADER, "%s: yeniden uygulamada lens korunuyor" % id)
		var halo: MeshInstance3D = car.find_child("PoliceBeacons", false, false) as MeshInstance3D
		var beacons: Array = CarPartMap.get_map(car.scene_file_path).get("beacons", [])
		check(halo != null and halo.mesh.surface_get_array_len(0) == beacons.size() * 4,
			"%s: hale mesh'i nokta başına bir dörtgen (%d nokta)" % [id, beacons.size()])
		check(halo != null and halo.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s: hale gölge yapmaz" % id)
		# Kip: lens ve hale materyallerine gider, LIT'te hale gizlenir
		rig.set_police_lights(PoliceLights.Mode.LIT)
		check(int(still.get_shader_parameter(&"mode")) == PoliceLights.Mode.LIT and not halo.visible
			and int((halo.material_override as ShaderMaterial).get_shader_parameter(&"mode")) == PoliceLights.Mode.LIT,
			"%s: LIT kipi lens + haleye gitti, hale gizli" % id)
		rig.set_police_lights(PoliceLights.Mode.FLASH)
		check(halo.visible, "%s: FLASH kipinde hale görünür" % id)
		# Aynı fazda çakmalı: lens ve hale aynı phase
		check(is_equal_approx(float(still.get_shader_parameter(&"phase")),
			float((halo.material_override as ShaderMaterial).get_shader_parameter(&"phase"))), "%s: lens ve hale aynı fazda" % id)
		# Birleştirme: lens parçaları birleşik mesh'e girmez, görünür kalır
		rig.optimize(true)
		for i: int in 240:
			if rig.is_merged():
				break
			await process_frame
		var apart: bool = rig.is_merged()
		for mesh: MeshInstance3D in lights:
			apart = apart and mesh.visible
		check(apart, "%s: parçalar birleşti, ışık parçaları ayrı ve görünür" % id)
		car.free()

	print("== polis olmayan araç ==")
	var plain: Node3D = (load(CarCatalog.scene_path(&"togg_t10x")) as PackedScene).instantiate()
	root.add_child(plain)
	var plain_rig: CarRig = CarRig.new(plain)
	plain_rig.apply(CarAppearance.get_for(plain.scene_file_path))
	plain_rig.set_police_lights(PoliceLights.Mode.LIT)   # etkisiz olmalı, hata vermemeli
	check(not plain_rig.has_police_lights() and plain.find_child("PoliceBeacons", false, false) == null, "Togg'da ışık sistemi yok")
	plain.free()

	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
