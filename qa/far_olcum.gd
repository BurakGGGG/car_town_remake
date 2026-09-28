extends SceneTree
## FAR OKUNURLUĞU — objektif ölçüm.
##
## Soru: lamba, yanındaki kaportadan ekranda ne kadar ayrışıyor? Sabit bir dikdörtgenden
## ölçmek yanıltıcı (ızgara ve tampon da giriyor), bu yüzden her araç İKİ KEZ çekilir:
##   1) normal görünüm
##   2) MASKE: far parçaları macenta, kalan her şey siyah
## Sonra maske ile normal çekim çakıştırılıp lamba piksellerinin ortalama parlaklığı, lambayı
## çevreleyen kaporta piksellerinin ortalamasıyla karşılaştırılır. Fark ne kadar büyükse lamba
## o kadar okunur — ve bu ölçü araç rengine bağlı değil (koyu araçta lamba PARLAK, açık araçta
## KOYU olarak ayrışır; mutlak fark ikisini de yakalar).
##
## Kullanım: godot-4 --path . -s res://qa/far_olcum.gd
## Çıktı: ct_shots/far/<araç>.png (normal) ve <araç>_maske.png; özet qa/far_olcum.py ile.

const OUT: String = "/home/burak/Projects/ct_shots/far/"

var _ids: PackedStringArray = PackedStringArray()
var _i: int = 0
var _frame: int = 0
var _mask_pass: bool = false
var _world: Node3D
var _car: Node3D


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for entry: Dictionary in CarCatalog.all():
		_ids.append(String(entry["id"]))
	_world = Node3D.new()
	get_root().add_child(_world)
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.0, 0.0, 0.0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.92, 0.94, 0.98)
	e.ambient_light_energy = 1.0
	env.environment = e
	_world.add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, 8.0, 0.0)
	sun.light_energy = 1.2
	_world.add_child(sun)
	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = 0.60                      # aracın ön yüzü kadrajı doldursun
	cam.position = Vector3(0.0, 0.18, 2.0)
	_world.add_child(cam)


func _process(_d: float) -> bool:
	_frame += 1
	if _frame % 6 != 0:
		return false
	if _car == null:
		if _i >= _ids.size():
			print("çekildi: %d araç" % _ids.size())
			quit(0)
			return true
		_build(_ids[_i], false)
		return false
	RenderingServer.force_draw()
	var id: String = _ids[_i]
	var suffix: String = "_maske" if _mask_pass else ""
	get_root().get_texture().get_image().save_png("%s%s%s.png" % [OUT, id, suffix])
	if _mask_pass:
		_i += 1
		_mask_pass = false
		_free_car()
		if _i < _ids.size():
			_build(_ids[_i], false)
	else:
		_mask_pass = true
		_paint_mask()
	return false


func _free_car() -> void:
	if _car:
		_car.queue_free()
		_car = null


func _build(id: String, _mask: bool) -> void:
	_free_car()
	var path: String = CarCatalog.scene_path(StringName(id))
	_car = (load(path) as PackedScene).instantiate()
	_car.rotation_degrees = Vector3(0.0, 0.0, 0.0)
	_car.scale = Vector3.ONE * CarCatalog.model_scale(StringName(id))
	_world.add_child(_car)
	var rig: CarRig = CarRig.for_node(_car)
	rig.apply(CarAppearance.get_for(path))


## Far parçalarını macenta, kalan her şeyi siyah yapar (rol maskesi).
func _paint_mask() -> void:
	var rig: CarRig = CarRig.for_node(_car)
	var black: StandardMaterial3D = StandardMaterial3D.new()
	black.albedo_color = Color.BLACK
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var pink: StandardMaterial3D = StandardMaterial3D.new()
	pink.albedo_color = Color(1.0, 0.0, 1.0)
	pink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for mesh: MeshInstance3D in _car.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = black
	var parts: Dictionary = rig.get("_parts")   # rol → Array[MeshInstance3D]
	for mesh: MeshInstance3D in parts.get(&"headlights", []):
		mesh.material_override = pink
