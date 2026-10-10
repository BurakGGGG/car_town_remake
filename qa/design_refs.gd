extends SceneTree
## TASARIM REFERANSLARI: oyundaki gerçek varlıkların saydam zeminli, oyunun izometrik açısından
## tek tek render'ları (yükleme ekranı / mağaza görseli gibi tanıtım görselleri için referans).
## Kullanım: godot-4 --path . --resolution 1024x1024 -s res://qa/design_refs.gd
## Çıktı: ~/Projects/ct_shots/design_refs/<ad>.png

const OUT: String = "/home/burak/Projects/ct_shots/design_refs/"
const CARS: Array[StringName] = [&"tofas_sahin", &"bmw_e46", &"lambo_huracan"]
const DECOR: Array[StringName] = [&"tool_cabinet", &"tyre_rack", &"compressor", &"tool_trolley",
	&"workbench", &"oil_drums", &"tyre_pile", &"jack_stand", &"traffic_cones", &"neon_garage",
	&"garage_sign", &"car_lift", &"tyre_hanger"]
const CRATES: Array[String] = ["city_crate", "family_crate", "sport_crate", "prestige_crate", "super_crate"]

var _stage: Node3D
var _camera: Camera3D


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func _run() -> void:
	root.transparent_bg = true
	_stage = Node3D.new()
	root.add_child(_stage)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("D7DFE6")
	env.environment.ambient_light_energy = 0.75
	root.add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	root.add_child(sun)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.rotation_degrees = Vector3(-30.0, 45.0, 0.0)   # oyunun izometrik açısı
	root.add_child(_camera)
	_camera.make_current()

	for id: StringName in CARS:
		await _render(String(id), _car(id))
	for id: StringName in DECOR:
		await _render("dekor_" + String(id), DecorBuilder.build_placeable(id))
	for id: String in CRATES:
		var crate: CrateVisual = CrateVisual.new()
		crate.setup(StringName(id), 0)
		crate.set_tag_visible(false)
		await _render("kasa_" + id, crate)
	await _render("lift_ve_sahin", _lift_with_car())
	quit(0)


func _car(id: StringName) -> Node3D:
	var car: Node3D = (load(CarCatalog.scene_path(id)) as PackedScene).instantiate()
	car.scale = Vector3.ONE * CarCatalog.model_scale(id)
	var rig: CarRig = CarRig.for_node(car)
	rig.apply(CarAppearance.get_for(CarCatalog.scene_path(id)))
	rig.set_lod_bias(CarRig.LOD_BIAS_GARAGE)
	return car


## Tamir lifti (oyunda tamir alanının kendisi) ve üstünde başlangıç aracı, lift kalkık.
func _lift_with_car() -> Node3D:
	var holder: Node3D = Node3D.new()
	var lift: RepairLift = RepairLift.new()
	holder.add_child(lift)
	var car: Node3D = _car(&"tofas_sahin")
	car.scale *= 0.6   # trafik / tamir alanı ölçeği
	holder.add_child(car)
	lift.raise(car)
	return holder


func _render(name: String, node: Node3D) -> void:
	if node == null:
		print("ATLANDI ", name)
		return
	_stage.add_child(node)
	for i: int in 70:   # lift / kasa gibi kurulum animasyonları otursun
		await process_frame
	var box: AABB = _bounds(node)
	var center: Vector3 = box.get_center()
	var radius: float = box.size.length() * 0.5
	_camera.size = radius * 2.15
	_camera.position = center + _camera.global_transform.basis.z * (radius * 4.0 + 2.0)
	_camera.near = 0.01
	_camera.far = radius * 10.0 + 10.0
	for i: int in 4:
		await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("KAYDEDİLDİ ", name)
	node.queue_free()
	await process_frame


static func _bounds(root_node: Node3D) -> AABB:
	var merged: AABB = AABB()
	var first: bool = true
	for node: Node in root_node.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var box: AABB = mi.global_transform * mi.get_aabb()
		merged = box if first else merged.merge(box)
		first = false
	return merged
