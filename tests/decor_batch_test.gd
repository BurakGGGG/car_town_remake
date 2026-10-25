extends SceneTree
## DEKOR TOPLU ÇİZİMİ (world/static_batch.gd): oyun görünümünde dekor birkaç çizim çağrısıyla çizilir, asıl parçalar
## çizimden çıkar (layers 0) ama seçilebilir kalır; düzenleme / zemin odağında toplu çizim kalkar, çıkınca geri gelir;
## düz renk materyali yalnızca varsayılan ayarlı, dokusuz, opak StandardMaterial3D'lerden seçilir. PENCERELİ (sahte
## işleyici mesh dizilerini okuyamaz).
##   tools/run_tests.sh decor_batch_test

const ITEMS: Array[StringName] = [&"bench", &"potted_plant", &"tool_cabinet", &"picnic_table", &"oil_drums",
	&"traffic_cones", &"tyre_rack", &"sofa"]

var fails: int = 0
var decor: DecorManager
var view: GarageDecorView


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
	_materials()
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(30)
	decor = get_first_node_in_group("decor")
	view = get_first_node_in_group("garage_decor_view")
	await _place()
	await _batch()
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)


func _materials() -> void:
	print("== 1) DÜZ RENK SEÇİMİ ==")
	var plain: StandardMaterial3D = StandardMaterial3D.new()
	plain.albedo_color = Color("C84B59")
	plain.roughness = 0.8
	plain.metallic = 0.2
	check(StaticBatch.is_flat(plain), "renk / pürüz / metal ayarlı düz materyal köşe rengine taşınır")
	var glowing: StandardMaterial3D = StandardMaterial3D.new()
	glowing.emission_enabled = true
	var textured: StandardMaterial3D = StandardMaterial3D.new()
	textured.albedo_texture = PlaceholderTexture2D.new()
	var clear: StandardMaterial3D = StandardMaterial3D.new()
	clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var unlit: StandardMaterial3D = StandardMaterial3D.new()
	unlit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var two_sided: StandardMaterial3D = StandardMaterial3D.new()
	two_sided.cull_mode = BaseMaterial3D.CULL_DISABLED
	var front: StandardMaterial3D = StandardMaterial3D.new()
	front.cull_mode = BaseMaterial3D.CULL_FRONT
	check(StaticBatch.is_flat(two_sided), "çift yüzlü düz renk de toplanır (ayıklamasız ayrı yüzeyde)")
	check(not StaticBatch.is_flat(glowing) and not StaticBatch.is_flat(textured) and not StaticBatch.is_flat(clear)
		and not StaticBatch.is_flat(unlit) and not StaticBatch.is_flat(front) and not StaticBatch.is_flat(ShaderMaterial.new())
		and not StaticBatch.is_flat(null), "ışık saçan / dokulu / saydam / ışıksız / ön yüzü ayıklanan / shader materyali seçilmez")


func _place() -> void:
	print("== 2) YERLEŞİM ==")
	for inst: Dictionary in decor.instances().duplicate():
		decor.remove_instance(inst["iid"])
	var owned: Dictionary = {}
	for id: StringName in ITEMS:
		owned[id] = 1
	decor.load_state({"owned": owned})
	await frames(2)
	var placed: int = 0
	for id: StringName in ITEMS:
		var done: bool = false
		for j: int in range(1, 24):
			for i: int in range(1, 30):
				if done:
					break
				var p: Vector2 = DecorGrid.CORNER - Vector2(float(i), float(j)) * DecorGrid.CELL
				var pos: Vector3 = Vector3(p.x, view.area().floor_y, p.y)
				if view.is_valid(id, pos, 0.0):
					done = decor.add_instance(id, pos, 0.0) != ""
		if done:
			placed += 1
	await frames(5)
	check(placed >= 6, "eşyalar garaja kondu (%d / %d)" % [placed, ITEMS.size()])


func _draws() -> float:
	await frames(10)
	var total: float = 0.0
	for i: int in 10:
		await process_frame
		total += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	return total / 10.0


func _batch() -> void:
	print("== 3) TOPLU ÇİZİM ==")
	var batch: StaticBatch = view.find_child("DecorBatch", true, false) as StaticBatch
	check(batch != null and batch.is_inside_tree() and batch.find_child("Flat", false, false) != null,
		"oyun görünümünde toplu çizim kurulu (düz renk mesh'i var)")
	var hidden: int = 0
	var total: int = 0
	for inst: Dictionary in decor.instances():
		var body: Node3D = view.body_of(inst["iid"])
		for node: Node in body.find_children("*", "MeshInstance3D", true, false):
			total += 1
			if (node as MeshInstance3D).layers == 0:
				hidden += 1
	check(total > 0 and hidden * 10 >= total * 8, "asıl parçaların çoğu çizimden çıktı (%d / %d)" % [hidden, total])
	var body: Node3D = view.body_of(decor.instances()[0]["iid"])
	var camera: Camera3D = root.get_viewport().get_camera_3d()
	var at: Vector2 = camera.unproject_position(GarageDecorView._tree_box(body).get_center())
	check(view.pick_all(camera, at).has(decor.instances()[0]["iid"]), "toplu çizimdeyken eşya dokunarak seçilir")
	var with_batch: float = await _draws()
	StaticBatch.enabled = false
	view.refresh()
	var without: float = await _draws()
	StaticBatch.enabled = true
	view.refresh()
	check(with_batch + 5.0 < without, "çizim çağrısı azaldı (%.0f → %.0f)" % [without, with_batch])

	view.set_editing(true)
	await frames(2)
	var restored: bool = view.find_child("DecorBatch", true, false) == null
	for node: Node in view.body_of(decor.instances()[0]["iid"]).find_children("*", "MeshInstance3D", true, false):
		restored = restored and (node as MeshInstance3D).layers != 0
	check(restored, "düzenleme modunda toplu çizim yok, asıl parçalar çiziliyor")
	view.set_editing(false)
	await frames(2)
	check(view.find_child("DecorBatch", true, false) != null, "düzenlemeden çıkınca toplu çizim geri")
	view.set_floor_focus(true)
	await frames(2)
	check(view.find_child("DecorBatch", true, false) == null, "zemin odağında (hayalet eşyalar) toplu çizim yok")
	view.set_floor_focus(false)
	await frames(2)
	check(view.find_child("DecorBatch", true, false) != null, "zemin odağından çıkınca toplu çizim geri")
