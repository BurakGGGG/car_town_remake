extends SceneTree
## ŞEHİR GÖLGESİ (vfx/world_shadow.gd, vfx/car_shadow.gd): harita pişer ve zeminler onu okur; yol / kaldırım gibi düz
## renkli zeminler gölge alan shader'a çevrilir; trafik araçları kendi gölgesini taşır ve haritaya girmez; dekor değişince
## yalnız garaj bölgesi yeniden pişer ve sonuç bütün haritanın yeniden pişirilmesiyle aynıdır; harita diske önbelleğe
## yazılır. PENCERELİ (sahte işleyici çizmez).
##   tools/run_tests.sh world_shadow_test

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


func _wait_bake(shadow: WorldShadow) -> void:
	for i: int in 120:
		await process_frame
		if not shadow.get("_baking") and shadow.get("_timer") == null:
			return


func _run() -> void:
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(240)   # trafik doğsun
	var shadow: WorldShadow = main.find_child("WorldShadow", true, false) as WorldShadow
	check(shadow != null, "şehirde WorldShadow var")
	if shadow == null:
		_finish()
		return
	await _wait_bake(shadow)

	print("== 1) HARİTA VE ALICILAR ==")
	var image: Image = shadow.get("_image") as Image
	check(image != null and image.get_format() == Image.FORMAT_R8 and image.get_width() == WorldShadow.MAP_SIZE,
		"harita tek kanal %d²" % WorldShadow.MAP_SIZE)
	var lit: int = 0
	if image:
		for y: int in range(0, image.get_height(), 8):
			for x: int in range(0, image.get_width(), 8):
				if image.get_pixel(x, y).r > 0.5:
					lit += 1
	check(lit > 50, "haritada gölge var (%d örnek nokta)" % lit)
	var road: MeshInstance3D = main.get_node_or_null("RoadRight") as MeshInstance3D
	var road_mat: ShaderMaterial = (road.material_override if road and road.material_override else (road.get_active_material(0) if road else null)) as ShaderMaterial
	check(road_mat != null and road_mat.shader == WorldShadow.GROUND_SHADER
		and (road_mat.get_shader_parameter("world_shadow_tint") as Vector4).w > 0.0, "yol gölge alan zemin shader'ında")
	var grass: CSGShape3D = main.get_node_or_null("GrassArea") as CSGShape3D
	var grass_mat: ShaderMaterial = grass.material_override as ShaderMaterial if grass else null
	check(grass_mat != null and grass_mat.get_shader_parameter("world_shadow_map") == shadow.texture(), "çimen haritayı okuyor")

	print("== 2) HAREKETLİ ARAÇLAR ==")
	var traffic: Array[Node] = main.find_children("*", "TrafficVehicle", true, false)
	var with_shadow: int = 0
	for vehicle: Node in traffic:
		if vehicle.get_node_or_null("CarShadow") != null and vehicle.is_in_group(WorldShadow.DYNAMIC_GROUP):
			with_shadow += 1
	check(traffic.size() > 0 and with_shadow == traffic.size(), "trafik araçlarının kendi gölgesi var, haritaya girmiyor (%d / %d)" % [with_shadow, traffic.size()])

	print("== 3) BÖLGE PİŞİRMESİ ==")
	var decor: DecorManager = get_first_node_in_group("decor") as DecorManager
	var view: GarageDecorView = get_first_node_in_group("garage_decor_view") as GarageDecorView
	decor.load_state({"owned": {&"tool_cabinet": 1, &"oil_drums": 1}})
	await frames(2)
	var placed: int = 0
	for j: int in range(2, 20):
		for i: int in range(2, 24):
			if placed >= 2:
				break
			var p: Vector2 = DecorGrid.CORNER - Vector2(float(i), float(j)) * DecorGrid.CELL * 2.0
			var id: StringName = &"tool_cabinet" if placed == 0 else &"oil_drums"
			var pos: Vector3 = Vector3(p.x, view.area().floor_y, p.y)
			if view.is_valid(id, pos, 0.0) and decor.add_instance(id, pos, 0.0) != "":
				placed += 1
	await frames(2)
	await _wait_bake(shadow)
	var stats: Dictionary = shadow.last_stats
	check(stats.has("region"), "dekor değişince yalnız garaj bölgesi pişti (%s)" % [stats.get("region", "bütün harita")])
	print("  ·    bölge pişirmesi: ana iş parçacığı %.1f ms (bekleme karesiyle %.1f), %s" % [float(stats.get("work_ms", 0.0)),
		float(stats.get("ms", 0.0)), stats.get("region", "")])
	var regional: Image = (shadow.get("_image") as Image).duplicate() as Image
	DirAccess.remove_absolute(WorldShadow.CACHE_PATH)   # önbellekten yüklenmesin: gerçekten pişsin
	shadow.request_bake(0.0)
	await frames(2)
	await _wait_bake(shadow)
	var full: Image = shadow.get("_image") as Image
	var differing: int = 0
	for y: int in full.get_height():
		for x: int in full.get_width():
			if absf(full.get_pixel(x, y).r - regional.get_pixel(x, y).r) > 0.2:
				differing += 1
	check(differing < 200, "bölge sonucu bütün haritanın yeniden pişirilmesiyle aynı (%d farklı piksel)" % differing)
	print("  ·    bütün harita: ana iş parçacığı %.1f ms (bekleme karesiyle %.1f)" % [
		float(shadow.last_stats.get("work_ms", 0.0)), float(shadow.last_stats.get("ms", 0.0))])

	print("== 4) ÖNBELLEK ==")
	await create_timer(WorldShadow.CACHE_SAVE_DELAY + 0.5).timeout   # yazma ertelenir
	check(FileAccess.file_exists(WorldShadow.CACHE_PATH), "harita diske yazıldı")
	var reload: bool = shadow.call("_load_cache", shadow.call("_signature", (main.get_node("Sun") as Node3D).global_transform.basis.z.normalized(),
		WorldShadow.MAP_SIZE), WorldShadow.MAP_SIZE)
	check(reload, "aynı durumda önbellekten yüklenir")
	_finish()


func _finish() -> void:
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
