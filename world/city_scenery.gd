class_name CityScenery
extends Node3D
## ŞEHİR PEYZAJI — kaldırımlar, çimen, çitler, parklar ve ağaçlar (WorldDressing kurar; sahne düzenlenmez).
##
## Car Town'un sokak dilinden alındı: krem, YÜKSELTİLMİŞ kaldırımlar (yola bakan yüzde koyu bordür,
## üstte levha derzleri), kaldırımın arkasında koyu yeşil kutu çitler, dokulu parlak çimen, yuvarlak
## ağaç kümeleri. Garaja DOKUNULMAZ: garajın en büyük hali (4. seviye: x −8,2…−0,2, z −6,2…−0,2)
## ve showroom parseli boş bırakılır; kaldırımlar eski genişliklerinde (0,2) kalır.
##
## Maliyet: aynı türden her şey tek MultiMesh (ağaç türü başına parça sayısı kadar çizim çağrısı).
## Yerleşim sabit tohumla üretilir: her açılışta aynı harita.

const WALK_WIDTH: float = 0.2
const WALK_TOP: float = 0.02
const CURB_WIDTH: float = 0.035
const JOINT_STEP: float = 0.2
const ROAD_LOW: float = 0.0
const ROAD_HIGH: float = 1.2
## Kaldırım kolları: [eksen, yol kenarı (kaldırımın yola değen çizgisi), dışa yön, başlangıç, bitiş].
## Eksen 0: doğu-batı yolu boyunca (x değişir), kaldırım z'de; eksen 1: kuzey-güney yolu boyunca.
## Kavşak köşesi yarıçapları (Car Town'daki gibi yuvarlak köşe; kaldırım çeyrek daire çizer).
## Kuzeybatı (garaj) ve kuzeydoğu (showroom parseli) köşede küçük: garaja / parsele taşmasın.
const R_NW: float = 0.2
const R_NE: float = 0.2
const R_SW: float = 0.55
const R_SE: float = 0.55
const WALKS: Array[Array] = [
	[0, ROAD_LOW, -1.0, -11.6, -R_NW], [0, ROAD_HIGH, 1.0, -11.6, -R_SW],
	[0, ROAD_LOW, -1.0, 1.2 + R_NE, 9.7], [0, ROAD_HIGH, 1.0, 1.2 + R_SE, 9.7],
	[1, ROAD_LOW, -1.0, -10.0, -R_NW], [1, ROAD_HIGH, 1.0, -10.0, -R_NE],
	[1, ROAD_LOW, -1.0, 1.2 + R_SW, 11.2], [1, ROAD_HIGH, 1.0, 1.2 + R_SE, 11.2],
]
## Köşeler: [köşe noktası (yol kenarlarının kesişimi), çimen tarafı x yönü, z yönü, yarıçap].
const CORNERS: Array[Array] = [
	[Vector2(0.0, 0.0), -1.0, -1.0, R_NW], [Vector2(1.2, 0.0), 1.0, -1.0, R_NE],
	[Vector2(0.0, 1.2), -1.0, 1.0, R_SW], [Vector2(1.2, 1.2), 1.0, 1.0, R_SE],
]
const ARC_SEGMENTS: int = 12
## Boş kalacak alanlar (x0, z0, x1, z1): garajın en büyük hali + pay, showroom parseli, yollar.
const KEEP_OUT: Array[Rect2] = [
	Rect2(-8.6, -6.6, 8.6, 6.6),
	Rect2(1.3, -6.3, 7.6, 6.2),
]
const PAVER: Color = Color("EADFC4")
const CURB: Color = Color("B9A47A")
const JOINT: Color = Color("CDBB93")
const HEDGE: Color = Color("4A8F3C")
const PATH: Color = Color("DCCDA6")
const WATER: Color = Color("5CB6DE")
## Bitkiler: tools/world/vegetation.py (Blender) — dolgun yumrulu taçlar, iki ton yeşil.
const VEG_TREE_A: String = "res://assets/world/veg_tree_a.glb"
const VEG_TREE_B: String = "res://assets/world/veg_tree_b.glb"
const VEG_PINE: String = "res://assets/world/veg_pine.glb"
const VEG_BUSH: String = "res://assets/world/veg_bush.glb"

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _trees: Dictionary = {}   # dekor id → Array[Transform3D] (bank, çiçek tarhı)
var _models: Dictionary = {}  # bitki GLB yolu → Array[Transform3D]


func _ready() -> void:
	name = "CityScenery"
	_rng.seed = 20260929
	_retire_old_sidewalks()
	_build_sidewalks()
	_dress_grass()
	_build_parks()
	_flush_trees()


# --- Kaldırımlar -------------------------------------------------------------------------------

## Sahnedeki düz krem CSG şeritler gizlenir (Main.tscn'de duruyor); yerlerine yükseltilmiş kaldırım gelir.
func _retire_old_sidewalks() -> void:
	var scene: Node = get_tree().current_scene
	for road: String in ["RoadLeft", "RoadLeft2", "RoadRight", "RoadRight2"]:
		var node: Node = scene.get_node_or_null(road)
		if node == null:
			continue
		for child: Node in node.get_children():
			if child is CSGShape3D and String(child.name).begins_with("Sidewalk"):
				(child as CSGShape3D).visible = false


func _build_sidewalks() -> void:
	var slabs: Array[Transform3D] = []
	var curbs: Array[Transform3D] = []
	var joints: Array[Transform3D] = []
	for walk: Array in WALKS:
		var axis: int = walk[0]
		var edge: float = walk[1]
		var out: float = walk[2]
		var a: float = walk[3]
		var b: float = walk[4]
		var length: float = b - a
		var mid: float = (a + b) * 0.5
		var across: float = edge + out * WALK_WIDTH * 0.5
		slabs.append(_strip(axis, mid, across, length, WALK_WIDTH))
		curbs.append(_strip(axis, mid, edge + out * CURB_WIDTH * 0.5, length, CURB_WIDTH))
		var at: float = ceilf(a / JOINT_STEP) * JOINT_STEP
		while at < b - 0.01:
			joints.append(_strip(axis, at, across, 0.008, WALK_WIDTH - CURB_WIDTH * 2.0))
			at += JOINT_STEP
	_build_corners()
	_multi("Sidewalks", _box_mesh(Vector3(1.0, 0.03, 1.0), Vector3(0.0, WALK_TOP - 0.015, 0.0), PAVER), slabs, false)
	_multi("Curbs", _box_mesh(Vector3(1.0, 0.034, 1.0), Vector3(0.0, WALK_TOP - 0.015, 0.0), CURB), curbs, false)
	_multi("Joints", _box_mesh(Vector3(1.0, 0.002, 1.0), Vector3(0.0, WALK_TOP + 0.001, 0.0), JOINT), joints, false)


## Yuvarlak kavşak köşeleri: kaldırım ve bordür çeyrek daire çizer; yol kenarı ile yay arasında
## kalan köşe asfaltla doldurulur (düz yol levhaları o köşeyi kapsamıyor).
func _build_corners() -> void:
	var walk: SurfaceTool = SurfaceTool.new()
	var curb: SurfaceTool = SurfaceTool.new()
	var fill: SurfaceTool = SurfaceTool.new()
	for st: SurfaceTool in [walk, curb, fill]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for corner: Array in CORNERS:
		var k: Vector2 = corner[0]
		var sx: float = corner[1]
		var sz: float = corner[2]
		var r: float = corner[3]
		var center: Vector2 = k + Vector2(sx, sz) * r
		var a0: float = atan2(-sz, 0.0)
		var a1: float = atan2(0.0, -sx)
		var sweep: float = wrapf(a1 - a0, -PI, PI)
		_ring(walk, center, maxf(r - WALK_WIDTH, 0.0), r, a0, sweep, -0.005, WALK_TOP)
		_ring(curb, center, r - CURB_WIDTH, r, a0, sweep, -0.005, WALK_TOP + 0.002)
		# Asfalt dolgu: köşe noktasından yaya yelpaze
		for i: int in ARC_SEGMENTS:
			var p0: Vector2 = center + Vector2.from_angle(a0 + sweep * i / ARC_SEGMENTS) * r
			var p1: Vector2 = center + Vector2.from_angle(a0 + sweep * (i + 1) / ARC_SEGMENTS) * r
			_tri(fill, Vector3(k.x, 0.0005, k.y), Vector3(p1.x, 0.0005, p1.y), Vector3(p0.x, 0.0005, p0.y))
	for pair: Array in [[walk, PAVER, "CornerWalks"], [curb, CURB, "CornerCurbs"], [fill, Color(0.2667, 0.2667, 0.2667), "CornerFill"]]:
		var st: SurfaceTool = pair[0]
		var material: Material = _flat(pair[1])
		st.set_material(material)
		var node: MeshInstance3D = MeshInstance3D.new()
		node.name = pair[2]
		node.mesh = st.commit()
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)


## Halka dilimi (üst yüz + iç ve dış yan yüz), XZ düzleminde, y0..y1 kalınlığında.
func _ring(st: SurfaceTool, c: Vector2, r_in: float, r_out: float, a0: float, sweep: float, y0: float, y1: float) -> void:
	for i: int in ARC_SEGMENTS:
		var d0: Vector2 = Vector2.from_angle(a0 + sweep * i / ARC_SEGMENTS)
		var d1: Vector2 = Vector2.from_angle(a0 + sweep * (i + 1) / ARC_SEGMENTS)
		var o0: Vector2 = c + d0 * r_out
		var o1: Vector2 = c + d1 * r_out
		var i0: Vector2 = c + d0 * r_in
		var i1: Vector2 = c + d1 * r_in
		var out_n: Vector3 = Vector3((d0 + d1).x, 0.0, (d0 + d1).y).normalized()
		_quad(st, Vector3(i0.x, y1, i0.y), Vector3(o0.x, y1, o0.y), Vector3(o1.x, y1, o1.y), Vector3(i1.x, y1, i1.y), Vector3.UP)
		_quad(st, Vector3(o0.x, y1, o0.y), Vector3(o0.x, y0, o0.y), Vector3(o1.x, y0, o1.y), Vector3(o1.x, y1, o1.y), out_n)
		_quad(st, Vector3(i1.x, y1, i1.y), Vector3(i1.x, y0, i1.y), Vector3(i0.x, y0, i0.y), Vector3(i0.x, y1, i0.y), -out_n)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	_tri(st, a, b, c, normal)
	_tri(st, a, c, d, normal)


## Üçgen, verilen normalle. Sarmal yönü normale göre düzeltilir (Godot'da ön yüz saat yönünde; ters
## sarılan yüz iki yüzlü malzemede arkadan aydınlanıp simsiyah görünür — ayna köşelerde olduğu gibi).
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3 = Vector3.UP) -> void:
	if (b - a).cross(c - a).dot(normal) > 0.0:
		var t: Vector3 = b
		b = c
		c = t
	for v: Vector3 in [a, b, c]:
		st.set_normal(normal)
		st.add_vertex(v)


func _flat(color: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Birim kutuyu kola göre ölçekleyen dönüşüm: `along` boyunca uzunluk, `across` konumunda genişlik.
func _strip(axis: int, along: float, across: float, length: float, width: float) -> Transform3D:
	if axis == 0:
		return Transform3D(Basis.from_scale(Vector3(length, 1.0, width)), Vector3(along, 0.0, across))
	return Transform3D(Basis.from_scale(Vector3(width, 1.0, length)), Vector3(across, 0.0, along))


# --- Çimen -------------------------------------------------------------------------------------

func _dress_grass() -> void:
	var grass: GeometryInstance3D = get_tree().current_scene.get_node_or_null("GrassArea") as GeometryInstance3D
	if grass == null:
		return
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = preload("res://vfx/grass.gdshader")
	grass.material_override = material


# --- Parklar ve ağaçlar ------------------------------------------------------------------------

func _build_parks() -> void:
	var hedges: Array[Transform3D] = []
	# Car Town'daki gibi kaldırımın arkasında kutu çitler: garajın ve showroom'un olmadığı kenarlarda,
	# araya giriş boşlukları bırakarak.
	_hedge_line(hedges, 0, 1.5, -10.8, -0.5, [-6.2, -3.1])          # güneybatı, yol boyu
	_hedge_line(hedges, 1, -0.5, 1.6, 10.4, [4.6, 8.0])            # güneybatı, kuzey-güney yolu boyu
	_hedge_line(hedges, 0, 1.5, 1.7, 8.8, [5.0])                   # güneydoğu, yol boyu
	_hedge_line(hedges, 1, 1.7, 1.6, 10.4, [5.4, 8.6])             # güneydoğu, kuzey-güney yolu boyu
	_multi("Hedges", _box_mesh(Vector3(1.0, 0.1, 0.13), Vector3(0.0, 0.05 - 0.1, 0.0), HEDGE), hedges, true)

	# Güneybatı parkı: yürüyüş yolu, gölet, bank, çiçek tarhları, ağaç kümeleri
	var paths: Array[Transform3D] = []
	paths.append(Transform3D(Basis.from_scale(Vector3(8.6, 1.0, 0.28)), Vector3(-5.2, 0.0, 5.2)))
	paths.append(Transform3D(Basis.from_scale(Vector3(0.28, 1.0, 3.4)), Vector3(-4.65, 0.0, 3.3)))
	paths.append(Transform3D(Basis.from_scale(Vector3(0.28, 1.0, 5.0)), Vector3(-1.6, 0.0, 7.6)))
	paths.append(Transform3D(Basis.from_scale(Vector3(4.0, 1.0, 0.28)), Vector3(4.9, 0.0, 6.0)))
	paths.append(Transform3D(Basis.from_scale(Vector3(0.28, 1.0, 4.2)), Vector3(3.6, 0.0, 3.8)))
	_multi("Paths", _box_mesh(Vector3(1.0, 0.012, 1.0), Vector3(0.0, -0.1, 0.0), PATH), paths, false)
	_pond(Vector3(-7.4, 0.0, 7.6), 1.25)
	_pond(Vector3(6.4, 0.0, 8.4), 0.9)

	var beds: Array[Transform3D] = []
	for p: Vector3 in [Vector3(-5.2, 0, 4.4), Vector3(-3.0, 0, 6.1), Vector3(-8.8, 0, 3.4), Vector3(4.9, 0, 5.1),
			Vector3(2.6, 0, 7.8), Vector3(-0.9, 0, 3.0)]:
		beds.append(_prop(p, _rng.randf_range(0.0, 180.0), 1.6))
	_trees[&"flower_bed"] = beds
	var benches: Array[Transform3D] = []
	for pair: Array in [[Vector3(-6.6, 0, 5.55), 0.0], [Vector3(-3.4, 0, 5.55), 0.0], [Vector3(-1.25, 0, 8.2), -90.0],
			[Vector3(4.3, 0, 6.35), 0.0], [Vector3(-7.4, 0, 6.05), 180.0]]:
		benches.append(_prop(pair[0], pair[1], 1.3))
	_trees[&"bench"] = benches

	# Ağaçlar: kümeler halinde, boş kalması gereken yerlerden ve yollardan uzak
	var regions: Array[Rect2] = [
		Rect2(-10.8, 1.7, 10.2, 8.8),   # güneybatı (park)
		Rect2(1.7, 1.7, 7.2, 8.8),      # güneydoğu
		Rect2(-10.8, -9.2, 2.1, 9.0),   # garajın batısı (4. seviyenin ötesi)
		Rect2(-8.6, -9.2, 8.3, 2.4),    # garajın kuzeyi
		Rect2(1.4, -9.2, 7.5, 2.8),     # showroom'un kuzeyi
	]
	# Kümeler: bir ana ağaç, çevresinde 1–3 küçük ağaç, eteklerinde çalılar. Dış kenar bölgelerinde
	# (garajın ve showroom'un arkası) kümelerin yarısı çam grubu. Tek tek serpilmiş ağaçlar amatör
	# duruyordu (telefonda denendi).
	var placed: Array[Vector2] = []
	for i: int in regions.size():
		var region: Rect2 = regions[i]
		var edge_region: bool = i >= 2
		var clusters: int = int(region.get_area() * 0.13) + 1
		var tries: int = 0
		var made: int = 0
		while made < clusters and tries < clusters * 40:
			tries += 1
			var c: Vector2 = Vector2(_rng.randf_range(region.position.x, region.end.x),
				_rng.randf_range(region.position.y, region.end.y))
			if not _free_for_tree(c, placed):
				continue
			made += 1
			if edge_region and _rng.randf() < 0.5:
				_cluster_pines(c, placed)
			else:
				_cluster_round(c, placed)


func _cluster_round(c: Vector2, placed: Array[Vector2]) -> void:
	placed.append(c)
	_model(VEG_TREE_A, c, _rng.randf_range(0.95, 1.2))
	var n: int = _rng.randi_range(1, 3)
	for k: int in n:
		var a: float = _rng.randf() * TAU
		var p: Vector2 = c + Vector2(cos(a), sin(a)) * _rng.randf_range(0.55, 0.8)
		if _free_for_tree(p, placed):
			placed.append(p)
			_model(VEG_TREE_B, p, _rng.randf_range(0.8, 1.05))
	_bushes_around(c, _rng.randi_range(2, 4), placed)


func _cluster_pines(c: Vector2, placed: Array[Vector2]) -> void:
	for k: int in _rng.randi_range(2, 4):
		var p: Vector2 = c + (Vector2.ZERO if k == 0 else Vector2(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.6, 0.6)))
		if k == 0 or _free_for_tree(p, placed):
			placed.append(p)
			_model(VEG_PINE, p, _rng.randf_range(0.8, 1.25))
	_bushes_around(c, _rng.randi_range(1, 2), placed)


func _bushes_around(c: Vector2, n: int, placed: Array[Vector2]) -> void:
	for k: int in n:
		var a: float = _rng.randf() * TAU
		var p: Vector2 = c + Vector2(cos(a), sin(a)) * _rng.randf_range(0.35, 0.7)
		if _free_for_bush(p):
			_model(VEG_BUSH, p, _rng.randf_range(0.8, 1.3))


func _free_for_bush(p: Vector2) -> bool:
	for rect: Rect2 in KEEP_OUT:
		if rect.grow(0.1).has_point(p):
			return false
	return absf(p.y - 0.6) >= 1.05 and absf(p.x - 0.6) >= 1.05


## Blender'da kurulan bitki modeli (metre) çimen yüzeyine, gerçek ölçüde × `size`.
func _model(path: String, p: Vector2, size: float) -> void:
	if not _models.has(path):
		_models[path] = [] as Array[Transform3D]
	var basis: Basis = Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * DecorBuilder.METER * size)
	(_models[path] as Array).append(Transform3D(basis, Vector3(p.x, -0.105, p.y)))


func _free_for_tree(p: Vector2, placed: Array[Vector2]) -> bool:
	for rect: Rect2 in KEEP_OUT:
		if rect.grow(0.25).has_point(p):
			return false
	# Yollar + kaldırım + çit şeridi
	if absf(p.y - 0.6) < 1.5 or absf(p.x - 0.6) < 1.5:
		return false
	# Yürüyüş yolları ve göletler
	for r: Rect2 in [Rect2(-9.8, 4.8, 9.2, 0.8), Rect2(-5.1, 1.5, 0.9, 3.6), Rect2(-2.05, 5.0, 0.9, 5.4),
			Rect2(2.7, 5.6, 4.6, 0.8), Rect2(3.15, 1.6, 0.9, 4.4)]:
		if r.has_point(p):
			return false
	for pond: Vector3 in [Vector3(-7.4, 1.25, 7.6), Vector3(6.4, 0.9, 8.4)]:
		if p.distance_to(Vector2(pond.x, pond.z)) < pond.y + 0.5:
			return false
	for q: Vector2 in placed:
		if p.distance_to(q) < 0.62:
			return false
	return true


func _hedge_line(out: Array[Transform3D], axis: int, across: float, a: float, b: float, gaps: Array) -> void:
	var at: float = a
	while at < b:
		var seg_end: float = minf(at + 1.0, b)
		var blocked: bool = false
		for g: float in gaps:
			if absf((at + seg_end) * 0.5 - g) < 0.55:
				blocked = true
		if not blocked and seg_end - at > 0.3:
			var mid: float = (at + seg_end) * 0.5
			var length: float = seg_end - at - 0.04
			if axis == 0:
				out.append(Transform3D(Basis.from_scale(Vector3(length, 1.0, 1.0)), Vector3(mid, 0.0, across)))
			else:
				out.append(Transform3D(Basis(Vector3.UP, PI * 0.5).scaled(Vector3(1.0, 1.0, length)),
					Vector3(across, 0.0, mid)))
		at = seg_end


func _pond(center: Vector3, radius: float) -> void:
	var rim: CylinderMesh = CylinderMesh.new()
	rim.top_radius = radius + 0.08
	rim.bottom_radius = radius + 0.08
	rim.height = 0.03
	rim.radial_segments = 32
	var rim_mat: StandardMaterial3D = StandardMaterial3D.new()
	rim_mat.albedo_color = PATH
	rim.material = rim_mat
	var rim_node: MeshInstance3D = MeshInstance3D.new()
	rim_node.mesh = rim
	rim_node.position = center + Vector3(0.0, -0.095, 0.0)
	add_child(rim_node)
	var water: CylinderMesh = CylinderMesh.new()
	water.top_radius = radius
	water.bottom_radius = radius
	water.height = 0.03
	water.radial_segments = 32
	var water_mat: StandardMaterial3D = StandardMaterial3D.new()
	water_mat.albedo_color = WATER
	water_mat.roughness = 0.15
	water_mat.metallic_specular = 0.8
	water.material = water_mat
	var water_node: MeshInstance3D = MeshInstance3D.new()
	water_node.mesh = water
	water_node.position = center + Vector3(0.0, -0.088, 0.0)
	water_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water_node)


## Dekor modeli dönüşümü: çimen yüzeyinde (y −0,105), gerçek ölçüde × `size`.
func _prop(pos: Vector3, yaw: float, size: float) -> Transform3D:
	var basis: Basis = Basis(Vector3.UP, deg_to_rad(yaw)).scaled(Vector3.ONE * GarageDecorView.WORLD_SCALE * size)
	return Transform3D(basis, Vector3(pos.x, -0.105, pos.z))


## Bitki ve dekor modellerini parça başına tek MultiMesh olarak kurar.
func _flush_trees() -> void:
	for path: String in _models:
		var packed: PackedScene = load(path) as PackedScene
		if packed:
			var scene: Node3D = packed.instantiate() as Node3D
			_multi_from(scene, String(path.get_file().get_basename()), _models[path])
			scene.free()
	for id: StringName in _trees:
		var body: Node3D = DecorBuilder.build_placeable(id)
		if body:
			_multi_from(body, String(id), _trees[id])
			body.free()


func _multi_from(root: Node3D, label: String, transforms: Array) -> void:
	if transforms.is_empty():
		return
	var stack: Array = [[root, Transform3D.IDENTITY]]
	var index: int = 0
	while not stack.is_empty():
		var pair: Array = stack.pop_back()
		var node: Node = pair[0]
		var xf: Transform3D = pair[1]
		for child: Node in node.get_children():
			if child is Node3D:
				stack.append([child, xf * (child as Node3D).transform])
		var part: MeshInstance3D = node as MeshInstance3D
		if part == null or part.mesh == null:
			continue
		var mesh: Mesh = part.mesh
		if part.material_override:
			mesh = mesh.duplicate() as Mesh
			for s: int in mesh.get_surface_count():
				mesh.surface_set_material(s, part.material_override)
		var list: Array[Transform3D] = []
		for t: Transform3D in transforms:
			list.append(t * xf)
		_multi("%s_%d" % [label, index], mesh, list, true)
		index += 1


# --- Yardımcılar -------------------------------------------------------------------------------

func _box_mesh(size: Vector3, offset: Vector3, color: Color) -> Mesh:
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	box.material = material
	# Kutunun merkezini `offset`e kaydırmak için yüzeyi taşı (MultiMesh örnek ölçeği y'yi bozmasın)
	var arrays: Array = box.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i: int in verts.size():
		verts[i] += offset
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return mesh


func _multi(label: String, mesh: Mesh, transforms: Array, shadows: bool) -> void:
	var multi: MultiMesh = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for i: int in transforms.size():
		multi.set_instance_transform(i, transforms[i])
	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = multi
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
