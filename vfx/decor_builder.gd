class_name DecorBuilder
## Dekorasyon eşyalarının 3D gövdelerini KODLA üretir (garaj iç mekânı ve showroom da böyle
## kuruldu: ayrı asset yok, stil tutarlı). Her eşya kendi Node3D'sini döndürür; yuvaya konulur.
##
## Ölçüler garaj odasına göre: lift (0,0) civarında, oda iç köşesi (-1.3, -1.3), araçlar ~1,0
## birim uzunluğunda. Eşyalar 0,25-0,60 birim aralığında tutuldu ki araca göre inandırıcı olsun.

const INK: Color = Color(0.13, 0.14, 0.16)


static func _material(color: Color, rough: float = 0.75, metal: float = 0.0,
		emission: Color = Color.BLACK) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	mat.metallic = metal
	if emission != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = 1.6
	return mat


static func _box(parent: Node3D, size: Vector3, position: Vector3, color: Color,
		rough: float = 0.75, metal: float = 0.0, emission: Color = Color.BLACK) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = position
	mesh.material_override = _material(color, rough, metal, emission)
	parent.add_child(mesh)
	return mesh


static func _cylinder(parent: Node3D, radius: float, height: float, position: Vector3,
		color: Color, rough: float = 0.8) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.radial_segments = 14
	mesh.mesh = cyl
	mesh.position = position
	mesh.material_override = _material(color, rough)
	parent.add_child(mesh)
	return mesh


## Blender'dan gelen modellerin klasörü. Bir eşyanın burada `<id>.glb` dosyası varsa KODLA
## üretim yerine o model yüklenir (tools/decor/*.py ile üretiliyor). Modeller METRE ölçeğinde
## çizilir; oyun ölçeğine çevirmek yerleştiren tarafın işidir (GarageDecorView.WORLD_SCALE'in
## metre karşılığı METER olarak burada).
const MODEL_DIR: String = "res://assets/decor/"
## Blender'da 1 birim = 1 metre. Oyunda araç 4,39 m = 0,6 birim → 1 m = 0,1367 birim.
const METER: float = 0.1367
## GarageDecorView'in her gövdeye uyguladığı ölçek (kodla üretilenler için); model yolunda
## telafi edilir. İkisi aynı yerde durmalı: değiştirirsen ikisini birden değiştir.
const PLACER_SCALE: float = 0.48


## Eşyanın model yolu: katalogda scene_path varsa o, yoksa assets/decor/<id>.glb geleneği.
static func model_path(id: StringName) -> String:
	var custom: String = GarageDecor.scene_path(id)
	return custom if custom != "" else MODEL_DIR + String(id) + ".glb"


## Bu eşyanın hazır modeli var mı?
static func has_model(id: StringName) -> bool:
	return ResourceLoader.exists(model_path(id))


# --- Yerleşime hazır gövde -----------------------------------------------------------

## id → {"offset": Vector3, "size": Vector3} (gövdenin KENDİ biriminde, WORLD_SCALE öncesi).
static var _norm: Dictionary = {}


## YERLEŞİME HAZIR gövde. Modellerin çoğunun orijini tabanında ya da ortasında DEĞİL (ölçüldü:
## tree_slim, water_tower, garage_sign 0,157 birim zemine gömülüyordu; foosball, vending,
## workbench 0,11–0,12). Burada her gövde bir kez ölçülür ve kaydırılır:
##   zemin eşyası → taban y = 0, iz merkezi (0, 0): zemine oturur, KENDİ ortası etrafında döner
##   duvar eşyası → dikey merkez y = 0, genişlik merkezi x = 0, ARKA yüz z = 0: duvara yaslanır
## Eşya başına elle değer yok; yeni bir model de aynı kuralla doğru oturur.
static func build_placeable(id: StringName) -> Node3D:
	var inner: Node3D = build(id)
	if inner == null:
		return null
	if not _norm.has(id):
		_norm[id] = _measure(inner, GarageDecor.placement(id) == GarageDecor.PLACE_WALL)
	var root: Node3D = Node3D.new()
	root.name = String(id)
	inner.position = (_norm[id] as Dictionary)["offset"]
	root.add_child(inner)
	return root


## Gövdenin kendi birimindeki boyutu (x genişlik, y yükseklik, z derinlik), WORLD_SCALE öncesi.
static func local_size(id: StringName) -> Vector3:
	if not _norm.has(id):
		var body: Node3D = build_placeable(id)
		if body == null:
			return Vector3.ZERO
		body.free()
	return (_norm[id] as Dictionary)["size"]


static func _measure(root: Node3D, wall: bool) -> Dictionary:
	var box: AABB = _local_bounds(root)
	var c: Vector3 = box.get_center()
	var offset: Vector3 = Vector3(-c.x, -c.y, -box.position.z) if wall \
			else Vector3(-c.x, -box.position.y, -c.z)
	return {"offset": offset, "size": box.size}


## Ağaç henüz sahnede değilken (global_transform yok) görünür geometrinin kök uzayındaki kutusu.
## Kutuyu değil 8 KÖŞEYİ dönüştürür: Transform3D * AABB döndürülmüş kutunun sınırını verip şişirir.
static func _local_bounds(root: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var pair: Array = stack.pop_back()
		var node: Node = pair[0]
		var xf: Transform3D = pair[1]
		for child: Node in node.get_children():
			if child is Node3D:
				stack.append([child, xf * (child as Node3D).transform])
		if not (node is VisualInstance3D) or node == root:
			continue
		var local: AABB = (node as VisualInstance3D).get_aabb()
		for i: int in 8:
			var p: Vector3 = xf * (local.position + Vector3(
				local.size.x if (i & 1) else 0.0, local.size.y if (i & 2) else 0.0,
				local.size.z if (i & 4) else 0.0))
			if first:
				out = AABB(p, Vector3.ZERO)
				first = false
			else:
				out = out.expand(p)
	return out


## Hazır modeli yükler; metre ölçeğinden oyun ölçeğine çevrilmiş halde döner.
static func _load_model(id: StringName) -> Node3D:
	var scene: PackedScene = load(model_path(id))
	if scene == null:
		return null
	var holder: Node3D = Node3D.new()
	holder.name = String(id)
	var model: Node3D = scene.instantiate() as Node3D
	# Yerleştiren taraf (GarageDecorView) her gövdeye WORLD_SCALE (0,48) uyguluyor; bu katsayı
	# kodla üretilen garaj-içi ölçüsü içindir. Model METRE ölçeğinde olduğu için burada onu
	# telafi ediyoruz: 0,1367 / 0,48 = 0,2848. Sonuçta model gerçek boyutunda görünür.
	model.scale = Vector3.ONE * (METER / PLACER_SCALE)
	holder.add_child(model)
	return holder


## Eşyanın gövdesi. Bilinmeyen id → null (arayüz onu atlar).
static func build(id: StringName) -> Node3D:
	if has_model(id):
		return _load_model(id)
	var root: Node3D = Node3D.new()
	root.name = String(id)
	match id:
		&"tool_cabinet": _tool_cabinet(root)
		&"tyre_rack": _tyre_rack(root)
		&"compressor": _compressor(root)
		&"tool_trolley": _tool_trolley(root)
		&"sofa": _sofa(root)
		&"coffee_table": _coffee_table(root)
		&"vending": _vending(root)
		&"neon_sign": _neon_sign(root)
		&"oil_drums": _oil_drums(root)
		&"pallet_stack": _pallet_stack(root)
		&"parts_shelf": _parts_shelf(root)
		&"jack_stand": _jack_stand(root)
		&"traffic_cones": _traffic_cones(root)
		&"barrier": _barrier(root)
		&"dumpster": _dumpster(root)
		&"container": _container(root)
		&"fuel_pump": _fuel_pump(root)
		&"bench": _bench(root)
		&"picnic_table": _picnic_table(root)
		&"potted_plant": _potted_plant(root)
		&"lamp_post": _lamp_post(root)
		&"flagpole": _flagpole(root)
		_:
			root.free()
			return null
	for child: Node in root.get_children():
		(child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return root


# --- ATÖLYE -------------------------------------------------------------------------

static func _tool_cabinet(root: Node3D) -> void:
	_box(root, Vector3(0.44, 0.40, 0.22), Vector3(0.0, 0.20, 0.0), Color("B8302C"), 0.55)
	_box(root, Vector3(0.46, 0.03, 0.24), Vector3(0.0, 0.415, 0.0), Color("2B2E33"), 0.5, 0.3)
	for i: int in 3:
		_box(root, Vector3(0.40, 0.012, 0.005), Vector3(0.0, 0.10 + float(i) * 0.10, 0.112),
			Color("E8E4DC"), 0.4, 0.4)


static func _tyre_rack(root: Node3D) -> void:
	_box(root, Vector3(0.40, 0.03, 0.26), Vector3(0.0, 0.015, 0.0), Color("55585E"), 0.6, 0.4)
	for i: int in 3:
		var tyre: MeshInstance3D = _cylinder(root, 0.115, 0.075,
			Vector3(0.0, 0.07 + float(i) * 0.08, 0.0), Color("1B1C1E"), 0.9)
		tyre.rotation_degrees = Vector3(0.0, 0.0, 0.0)
	for side: int in 2:
		_box(root, Vector3(0.025, 0.34, 0.025),
			Vector3(0.0, 0.17, -0.12 + float(side) * 0.24), Color("55585E"), 0.6, 0.4)


static func _compressor(root: Node3D) -> void:
	var tank: MeshInstance3D = _cylinder(root, 0.10, 0.42, Vector3(0.0, 0.23, 0.0), Color("2F6FA8"), 0.5)
	tank.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	tank.position = Vector3(0.0, 0.14, 0.0)
	for side: int in 2:
		_box(root, Vector3(0.05, 0.13, 0.05), Vector3(0.0, 0.065, -0.14 + float(side) * 0.28),
			Color("3A3D42"), 0.6, 0.3)
	_box(root, Vector3(0.14, 0.11, 0.12), Vector3(0.0, 0.31, 0.0), Color("3A3D42"), 0.5, 0.4)
	var hose: MeshInstance3D = _cylinder(root, 0.055, 0.04, Vector3(0.10, 0.31, 0.0), Color("1B1C1E"), 0.9)
	hose.rotation_degrees = Vector3(0.0, 0.0, 90.0)


static func _tool_trolley(root: Node3D) -> void:
	_box(root, Vector3(0.34, 0.30, 0.20), Vector3(0.0, 0.21, 0.0), Color("D2941F"), 0.55)
	_box(root, Vector3(0.38, 0.025, 0.24), Vector3(0.0, 0.372, 0.0), Color("2B2E33"), 0.45, 0.35)
	for i: int in 2:
		_box(root, Vector3(0.30, 0.012, 0.005), Vector3(0.0, 0.14 + float(i) * 0.10, 0.102),
			Color("2B2E33"), 0.4, 0.3)
	for x: int in 2:
		for z: int in 2:
			var wheel: MeshInstance3D = _cylinder(root, 0.03, 0.02,
				Vector3(-0.13 + float(x) * 0.26, 0.03, -0.07 + float(z) * 0.14), Color("1B1C1E"), 0.9)
			wheel.rotation_degrees = Vector3(0.0, 0.0, 90.0)


# --- YAŞAM ALANI --------------------------------------------------------------------

static func _sofa(root: Node3D) -> void:
	_box(root, Vector3(0.62, 0.14, 0.26), Vector3(0.0, 0.16, 0.0), Color("39506B"), 0.85)
	_box(root, Vector3(0.62, 0.26, 0.07), Vector3(0.0, 0.29, -0.095), Color("32475F"), 0.85)
	for side: int in 2:
		_box(root, Vector3(0.07, 0.20, 0.26), Vector3(-0.275 + float(side) * 0.55, 0.23, 0.0),
			Color("32475F"), 0.85)
	for x: int in 2:
		for z: int in 2:
			_box(root, Vector3(0.04, 0.09, 0.04),
				Vector3(-0.24 + float(x) * 0.48, 0.045, -0.09 + float(z) * 0.18), Color("2B2E33"), 0.6)


static func _coffee_table(root: Node3D) -> void:
	_box(root, Vector3(0.34, 0.03, 0.22), Vector3(0.0, 0.20, 0.0), Color("8A5F3C"), 0.6)
	for x: int in 2:
		for z: int in 2:
			_box(root, Vector3(0.025, 0.19, 0.025),
				Vector3(-0.14 + float(x) * 0.28, 0.095, -0.085 + float(z) * 0.17), Color("5E4128"), 0.7)
	_box(root, Vector3(0.14, 0.012, 0.10), Vector3(0.02, 0.222, 0.01), Color("E8E4DC"), 0.5)
	_box(root, Vector3(0.12, 0.010, 0.09), Vector3(-0.04, 0.232, -0.02), Color("C8CBD2"), 0.5)


static func _vending(root: Node3D) -> void:
	_box(root, Vector3(0.36, 0.72, 0.26), Vector3(0.0, 0.36, 0.0), Color("B8302C"), 0.5)
	# Işıklı vitrin
	_box(root, Vector3(0.26, 0.46, 0.015), Vector3(0.0, 0.44, 0.132),
		Color("F2E9C8"), 0.25, 0.0, Color(1.0, 0.92, 0.66))
	for row: int in 3:
		_box(root, Vector3(0.24, 0.010, 0.006), Vector3(0.0, 0.29 + float(row) * 0.13, 0.141),
			Color("3A3D42"), 0.5)
	_box(root, Vector3(0.26, 0.06, 0.02), Vector3(0.0, 0.135, 0.135), Color("2B2E33"), 0.6)
	_box(root, Vector3(0.38, 0.03, 0.28), Vector3(0.0, 0.015, 0.0), Color("2B2E33"), 0.6)


# --- DUVAR --------------------------------------------------------------------------

static func _neon_sign(root: Node3D) -> void:
	_box(root, Vector3(0.62, 0.26, 0.03), Vector3(0.0, 0.0, 0.0), Color("1B1C1E"), 0.6)
	_box(root, Vector3(0.56, 0.20, 0.012), Vector3(0.0, 0.0, 0.022),
		Color("2A1F2E"), 0.3, 0.0, Color(0.25, 0.08, 0.30))
	# Neon çubuklar: "GARAJ" hissi veren soyut şerit deseni
	for i: int in 4:
		_box(root, Vector3(0.055, 0.12, 0.010), Vector3(-0.18 + float(i) * 0.12, 0.01, 0.030),
			Color("FF4FA3"), 0.2, 0.0, Color(1.0, 0.28, 0.62))
	_box(root, Vector3(0.50, 0.018, 0.010), Vector3(0.0, -0.07, 0.030),
		Color("3FD8FF"), 0.2, 0.0, Color(0.25, 0.85, 1.0))


# --- YÜZEYLER (zemin / duvar kaplaması) ---------------------------------------------

## Zemin kaplamasının malzemesi (mevcut zemin mesh'inin material_override'ı değiştirilir).
static func floor_material(id: StringName) -> StandardMaterial3D:
	match id:
		&"floor_tile":
			var tile: StandardMaterial3D = _material(Color("C9CCD2"), 0.55)
			tile.uv1_scale = Vector3(24.0, 24.0, 1.0)
			return tile
		&"floor_epoxy":
			var epoxy: StandardMaterial3D = _material(Color("2E3A47"), 0.18, 0.15)
			return epoxy
		_:
			return null


## Duvar kaplamasının malzemesi.
static func wall_material(id: StringName) -> StandardMaterial3D:
	match id:
		&"wall_brick": return _material(Color("8C4A3A"), 0.85)
		&"wall_panel": return _material(Color("EDEAE3"), 0.45)
		_: return null


# --- ATÖLYE (ek) ---------------------------------------------------------------------

static func _oil_drums(root: Node3D) -> void:
	var colors: Array = [Color("B8302C"), Color("2F6FA8"), Color("D2941F")]
	var spots: Array = [Vector3(-0.10, 0.0, -0.06), Vector3(0.10, 0.0, -0.06), Vector3(0.0, 0.0, 0.10)]
	for i: int in 3:
		var drum: MeshInstance3D = _cylinder(root, 0.085, 0.30,
			(spots[i] as Vector3) + Vector3(0.0, 0.15, 0.0), colors[i], 0.55)
		# İki çember bandı: varil silindir gibi değil VARİL gibi okunsun
		for band: int in 2:
			_cylinder(root, 0.089, 0.014,
				(spots[i] as Vector3) + Vector3(0.0, 0.10 + float(band) * 0.10, 0.0),
				Color("2B2E33"), 0.6)


static func _pallet_stack(root: Node3D) -> void:
	for level: int in 4:
		var y: float = 0.03 + float(level) * 0.055
		_box(root, Vector3(0.40, 0.018, 0.34), Vector3(0.0, y, 0.0), Color("A97B4C"), 0.85)
		for beam: int in 3:
			_box(root, Vector3(0.05, 0.035, 0.34),
				Vector3(-0.16 + float(beam) * 0.16, y - 0.026, 0.0), Color("8A5F3C"), 0.85)


static func _parts_shelf(root: Node3D) -> void:
	for side: int in 2:
		_box(root, Vector3(0.035, 0.62, 0.035),
			Vector3(-0.23 + float(side) * 0.46, 0.31, 0.0), Color("55585E"), 0.6, 0.35)
	for level: int in 3:
		var y: float = 0.14 + float(level) * 0.22
		_box(root, Vector3(0.50, 0.022, 0.26), Vector3(0.0, y, 0.0), Color("6B6F76"), 0.6, 0.25)
		for crate: int in 2:
			_box(root, Vector3(0.16, 0.12, 0.18),
				Vector3(-0.12 + float(crate) * 0.24, y + 0.07, 0.0),
				Color("C96A2E") if crate == 0 else Color("3E5A7A"), 0.8)


static func _jack_stand(root: Node3D) -> void:
	_box(root, Vector3(0.26, 0.05, 0.22), Vector3(0.0, 0.025, 0.0), Color("B8302C"), 0.55)
	_box(root, Vector3(0.07, 0.16, 0.07), Vector3(0.0, 0.13, 0.0), Color("55585E"), 0.5, 0.4)
	_box(root, Vector3(0.16, 0.03, 0.14), Vector3(0.0, 0.22, 0.0), Color("2B2E33"), 0.5, 0.3)
	var handle: MeshInstance3D = _cylinder(root, 0.014, 0.30, Vector3(0.0, 0.16, -0.16), Color("2B2E33"), 0.6)
	handle.rotation_degrees = Vector3(58.0, 0.0, 0.0)


# --- AVLU ----------------------------------------------------------------------------

static func _traffic_cones(root: Node3D) -> void:
	for i: int in 3:
		var x: float = -0.16 + float(i) * 0.16
		var z: float = 0.05 if i == 1 else -0.05
		_box(root, Vector3(0.11, 0.015, 0.11), Vector3(x, 0.008, z), Color("E24A2C"), 0.7)
		var cone: MeshInstance3D = MeshInstance3D.new()
		var mesh: CylinderMesh = CylinderMesh.new()
		mesh.top_radius = 0.008
		mesh.bottom_radius = 0.045
		mesh.height = 0.18
		mesh.radial_segments = 10
		cone.mesh = mesh
		cone.position = Vector3(x, 0.10, z)
		cone.material_override = _material(Color("E24A2C"), 0.7)
		root.add_child(cone)
		_cylinder(root, 0.036, 0.028, Vector3(x, 0.12, z), Color("F2EFE6"), 0.6)


static func _barrier(root: Node3D) -> void:
	for side: int in 2:
		_box(root, Vector3(0.05, 0.22, 0.13), Vector3(-0.30 + float(side) * 0.60, 0.11, 0.0),
			Color("2B2E33"), 0.6)
	for stripe: int in 6:
		_box(root, Vector3(0.10, 0.14, 0.05), Vector3(-0.275 + float(stripe) * 0.11, 0.20, 0.0),
			Color("E24A2C") if stripe % 2 == 0 else Color("F2EFE6"), 0.7)


static func _dumpster(root: Node3D) -> void:
	_box(root, Vector3(0.52, 0.30, 0.30), Vector3(0.0, 0.19, 0.0), Color("2F6B45"), 0.75)
	_box(root, Vector3(0.54, 0.035, 0.32), Vector3(0.0, 0.352, 0.0), Color("255637"), 0.7)
	for x: int in 2:
		for z: int in 2:
			var wheel: MeshInstance3D = _cylinder(root, 0.035, 0.022,
				Vector3(-0.21 + float(x) * 0.42, 0.035, -0.11 + float(z) * 0.22), Color("1B1C1E"), 0.9)
			wheel.rotation_degrees = Vector3(0.0, 0.0, 90.0)


static func _container(root: Node3D) -> void:
	_box(root, Vector3(0.92, 0.42, 0.40), Vector3(0.0, 0.21, 0.0), Color("B85A2C"), 0.8)
	for rib: int in 9:
		_box(root, Vector3(0.025, 0.38, 0.415), Vector3(-0.40 + float(rib) * 0.10, 0.21, 0.0),
			Color("A34E24"), 0.8)
	_box(root, Vector3(0.94, 0.04, 0.42), Vector3(0.0, 0.43, 0.0), Color("8C4020"), 0.75)
	_box(root, Vector3(0.94, 0.04, 0.42), Vector3(0.0, 0.02, 0.0), Color("8C4020"), 0.75)


static func _fuel_pump(root: Node3D) -> void:
	_box(root, Vector3(0.30, 0.08, 0.26), Vector3(0.0, 0.04, 0.0), Color("2B2E33"), 0.7)
	_box(root, Vector3(0.24, 0.52, 0.20), Vector3(0.0, 0.34, 0.0), Color("D9453C"), 0.5)
	_box(root, Vector3(0.17, 0.13, 0.015), Vector3(0.0, 0.46, 0.105),
		Color("1B1C1E"), 0.3, 0.0, Color(0.15, 0.85, 0.45))
	_box(root, Vector3(0.20, 0.05, 0.02), Vector3(0.0, 0.60, 0.0), Color("F2EFE6"), 0.5)
	# Hortum ve tabanca
	var hose: MeshInstance3D = _cylinder(root, 0.012, 0.22, Vector3(0.13, 0.30, 0.07), Color("1B1C1E"), 0.9)
	hose.rotation_degrees = Vector3(18.0, 0.0, 22.0)
	_box(root, Vector3(0.045, 0.10, 0.04), Vector3(0.155, 0.20, 0.09), Color("55585E"), 0.5, 0.3)


# --- YAŞAM ALANI (ek) ----------------------------------------------------------------

static func _bench(root: Node3D) -> void:
	for slat: int in 3:
		_box(root, Vector3(0.56, 0.022, 0.055), Vector3(0.0, 0.17, -0.07 + float(slat) * 0.07),
			Color("A97B4C"), 0.8)
	for slat: int in 2:
		_box(root, Vector3(0.56, 0.055, 0.022), Vector3(0.0, 0.26 + float(slat) * 0.07, -0.10),
			Color("A97B4C"), 0.8)
	for side: int in 2:
		_box(root, Vector3(0.035, 0.17, 0.20), Vector3(-0.24 + float(side) * 0.48, 0.085, 0.0),
			Color("3A3D42"), 0.6, 0.3)


static func _picnic_table(root: Node3D) -> void:
	_box(root, Vector3(0.52, 0.03, 0.26), Vector3(0.0, 0.25, 0.0), Color("A97B4C"), 0.8)
	for side: int in 2:
		_box(root, Vector3(0.52, 0.025, 0.11), Vector3(0.0, 0.15, -0.23 + float(side) * 0.46),
			Color("8A5F3C"), 0.85)
		_box(root, Vector3(0.05, 0.25, 0.05), Vector3(-0.20 + float(side) * 0.40, 0.125, 0.0),
			Color("6E4B2E"), 0.85)


static func _potted_plant(root: Node3D) -> void:
	_cylinder(root, 0.10, 0.16, Vector3(0.0, 0.08, 0.0), Color("9C5A3C"), 0.8)
	_cylinder(root, 0.105, 0.03, Vector3(0.0, 0.155, 0.0), Color("8A4C31"), 0.8)
	var trunk: MeshInstance3D = _cylinder(root, 0.02, 0.16, Vector3(0.0, 0.24, 0.0), Color("6E4B2E"), 0.9)
	trunk.name = "Trunk"
	for i: int in 3:
		var leaf: MeshInstance3D = MeshInstance3D.new()
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 0.11 - float(i) * 0.02
		sphere.height = (0.11 - float(i) * 0.02) * 1.7
		sphere.radial_segments = 10
		sphere.rings = 6
		leaf.mesh = sphere
		leaf.position = Vector3(-0.05 + float(i) * 0.05, 0.34 + float(i) * 0.06, 0.02 - float(i) * 0.03)
		leaf.material_override = _material(Color("3F7A3A"), 0.9)
		root.add_child(leaf)


# --- AYDINLATMA / TABELA -------------------------------------------------------------

static func _lamp_post(root: Node3D) -> void:
	_cylinder(root, 0.055, 0.03, Vector3(0.0, 0.015, 0.0), Color("2B2E33"), 0.6)
	_cylinder(root, 0.022, 0.78, Vector3(0.0, 0.40, 0.0), Color("3A3D42"), 0.5, )
	_box(root, Vector3(0.20, 0.05, 0.14), Vector3(0.0, 0.80, 0.0), Color("2B2E33"), 0.5, 0.3)
	_box(root, Vector3(0.16, 0.02, 0.11), Vector3(0.0, 0.775, 0.0),
		Color("FFF3C4"), 0.2, 0.0, Color(1.0, 0.93, 0.70))


static func _flagpole(root: Node3D) -> void:
	_cylinder(root, 0.07, 0.035, Vector3(0.0, 0.018, 0.0), Color("C9CCD2"), 0.5, )
	_cylinder(root, 0.016, 0.95, Vector3(0.0, 0.49, 0.0), Color("E8EAEE"), 0.35)
	_box(root, Vector3(0.015, 0.20, 0.30), Vector3(0.0, 0.84, 0.15), Color("D9453C"), 0.8)
	_box(root, Vector3(0.016, 0.07, 0.30), Vector3(0.0, 0.90, 0.15), Color("F2EFE6"), 0.8)
