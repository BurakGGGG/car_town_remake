class_name HazardLights
extends MeshInstance3D
## DÖRTLÜLER (2026-10-20, kullanıcı: "araçlar bazı yerlerde durup dörtlü yaksınlar, 3–5 saniye sonra devam etsinler,
## nadir olarak"; "far çizgilerinde olsun lamba"). Farların ve stopların üstünde (bkz. corners) yanıp sönen sarı hale. Polis halesiyle aynı yöntem (PoliceLights): tek mesh, kameraya dönük, toplamalı,
## yanıp sönme shader'da (kare başı betik yok). Dinamik ışık yok (GL Compatibility'de ışık nesne başına ek geçiştir).
## TrafficVehicle ilk dörtlüde kurar (araç modelinin çocuğu: araçla döner ve ölçeklenir); mesh araç tipi başına bir kez.

const SHADER: Shader = preload("res://vehicles/hazard_halo.gdshader")
## Lamba noktası: aracın ön / arka bu payı (boyun oranı) içindeki noktalar sayılır (yan sinyal dışarıda); ortadan bu
## kadar (genişliğin oranı) uzak olmalı (üçüncü stop / plaka lambası dışarıda). Gövde kutusu yedeğinde köşe payları.
const LAMP_DEPTH: float = 0.2
const SIDE_GAP: float = 0.12
## İki yanın lamba ortaları bundan fazla ayrışırsa (araç uzayı) biri eksik eşlenmiştir.
const MISMATCH: float = 0.025
const BOX_INSET_X: float = 0.13
const BOX_LAMP_HEIGHT: float = 0.42
## Yanıp sönme (Hz; gerçek dörtlü dakikada ~60–120 kez).
const BLINK_RATE: float = 1.45

static var _meshes: Dictionary = {}   # sahne yolu → ArrayMesh

var _material: ShaderMaterial


## Modelin altına kurar (görünmez başlar). `scene_path` mesh önbelleğinin anahtarı.
static func attach(model: Node3D, rig: CarRig, scene_path: String) -> HazardLights:
	var lights: HazardLights = HazardLights.new()
	lights.name = "HazardLights"
	if not _meshes.has(scene_path):
		_meshes[scene_path] = halo_mesh(corners(model, rig))
	lights.mesh = _meshes[scene_path]
	lights._material = ShaderMaterial.new()
	lights._material.shader = SHADER
	lights._material.set_shader_parameter(&"rate", BLINK_RATE)
	lights.material_override = lights._material
	lights.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lights.visible = false
	model.add_child(lights)
	return lights


func set_on(on: bool) -> void:
	if on and not visible:
		# Shader TIME motor açılışından beri (3600 sn'de başa döner): ilk yanış hemen gelsin
		var now: float = fmod(Time.get_ticks_msec() / 1000.0, 3600.0)
		_material.set_shader_parameter(&"phase", -fmod(now * BLINK_RATE, 1.0))
	visible = on


func is_on() -> bool:
	return visible


## Dört nokta (model uzayında): ön sol, ön sağ (farların üstünde), arka sol, arka sağ (stopların üstünde).
## Sıra: CarPartMap'te elle ölçülmüş "hazards" ({front: [x, y], rear: [x, y]}, x aynalanır, z gövdenin ön / arka yüzü) → lamba parçalarının
## köşe noktaları (her yanın kutusunun ortası, lambanın ön / arka yüzünde; ortadaki üçüncü stop ve yan sinyaller
## dışarıda) → gövde kutusunun ön / arka yüzü (kenardan içeride, lamba yüksekliğinde).
static func corners(model: Node3D, rig: CarRig) -> PackedVector3Array:
	var body: AABB = _bounds(model, _all_meshes(model))
	var manual: Dictionary = {}
	if rig and CarPartMap.has_map(rig.scene_path):
		manual = CarPartMap.get_map(rig.scene_path).get("hazards", {})
	var out: PackedVector3Array = PackedVector3Array()
	for front: bool in [true, false]:
		var key: String = "front" if front else "rear"
		if manual.has(key):
			var p: Array = manual[key]
			var face: float = float(p[2]) if p.size() > 2 else (body.end.z if front else body.position.z)
			out.append(Vector3(-absf(float(p[0])), float(p[1]), face))
			out.append(Vector3(absf(float(p[0])), float(p[1]), face))
			continue
		var sides: PackedVector3Array = _lamp_sides(model, _role(rig, &"headlights" if front else &"taillights"), body, front)
		if sides.size() == 2:
			out.append_array(sides)
			continue
		var y: float = body.position.y + body.size.y * BOX_LAMP_HEIGHT
		var inset: float = body.size.x * BOX_INSET_X
		var z: float = body.end.z if front else body.position.z
		out.append(Vector3(body.position.x + inset, y, z))
		out.append(Vector3(body.end.x - inset, y, z))
	return out


## Lambanın iki yanı: her parçanın aracın ön (arka) LAMP_DEPTH payındaki, ortadan SIDE_GAP uzaktaki noktaları sola /
## sağa ayrılır; her yanda en geniş (önden görünen alanı en büyük) parça seçilir — asıl far / stop ünitesi (haritada
## aynı role eklenmiş tampon sinyali, sis lambası, reflektör küçük kalır). Nokta: kutusunun ortası, z lambanın en ön /
## en arka yüzü. Bir yan eksikse ya da iki yan tutarsızsa büyük yan aynalanır; hiç parça yoksa boş.
static func _lamp_sides(model: Node3D, meshes: Array[MeshInstance3D], body: AABB, front: bool) -> PackedVector3Array:
	var center: float = body.get_center().x
	var reach: float = body.size.z * LAMP_DEPTH
	var gap: float = body.size.x * SIDE_GAP
	var boxes: Array[AABB] = [AABB(), AABB()]
	var found: Array[bool] = [false, false]
	for mesh: MeshInstance3D in meshes:
		var part: Array[AABB] = [AABB(), AABB()]
		var has: Array[bool] = [false, false]
		for point: Vector3 in _points(model, [mesh] as Array[MeshInstance3D]):
			if (front and point.z < body.end.z - reach) or (not front and point.z > body.position.z + reach):
				continue
			if absf(point.x - center) < gap:
				continue   # ortadaki üçüncü stop / plaka lambası
			var side: int = 0 if point.x < center else 1
			part[side] = part[side].expand(point) if has[side] else AABB(point, Vector3.ZERO)
			has[side] = true
		for side: int in 2:
			if has[side] and (not found[side] or _face(part[side]) > _face(boxes[side])):
				boxes[side] = part[side]
				found[side] = true
	if not found[0] and not found[1]:
		return PackedVector3Array()
	if found[0] and found[1]:
		var a: Vector3 = boxes[0].get_center()
		var b: Vector3 = boxes[1].get_center()
		if absf(absf(a.x - center) - absf(b.x - center)) > MISMATCH or absf(a.y - b.y) > MISMATCH:
			found[1 if _face(boxes[0]) >= _face(boxes[1]) else 0] = false
	for side: int in 2:
		if not found[side]:
			var other: AABB = boxes[1 - side]
			boxes[side] = AABB(Vector3(2.0 * center - other.end.x, other.position.y, other.position.z), other.size)
	var out: PackedVector3Array = PackedVector3Array()
	for side: int in 2:
		var box: AABB = boxes[side]
		var c: Vector3 = box.get_center()
		out.append(Vector3(c.x, c.y, box.end.z if front else box.position.z))
	return out


## Önden görünen alan (genişlik × yükseklik).
static func _face(box: AABB) -> float:
	return box.size.x * box.size.y


## Parçaların köşe noktaları (model uzayında; ağaçta olması gerekmez).
static func _points(model: Node3D, meshes: Array[MeshInstance3D]) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for mesh: MeshInstance3D in meshes:
		if mesh == null or mesh.mesh == null:
			continue
		var xf: Transform3D = _to_model(model, mesh)
		for surface: int in mesh.mesh.get_surface_count():
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array:
				out.append(xf * vertex)
	return out


static func _to_model(model: Node3D, node: Node) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	while node != null and node != model:
		if node is Node3D:
			xf = (node as Node3D).transform * xf
		node = node.get_parent()
	return xf


static func _role(rig: CarRig, role: StringName) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if rig:
		out = rig.get_meshes(role)
	return out


## Gövdenin mesh'leri (haleler hariç: polis halesi "PoliceBeacons", dörtlü).
static func _all_meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for child: Node in node.get_children():
		if child is HazardLights or child.name == &"PoliceBeacons":
			continue
		if child is MeshInstance3D and (child as MeshInstance3D).mesh:
			out.append(child)
		out.append_array(_all_meshes(child))
	return out


## Parçaların modele göre kutusu (sahne ağacında olması gerekmez: dönüşümler ebeveyn zincirinden).
static func _bounds(model: Node3D, meshes: Array[MeshInstance3D]) -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	for mesh: MeshInstance3D in meshes:
		if mesh == null or mesh.mesh == null:
			continue
		var part: AABB = _to_model(model, mesh) * mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box


## Köşelerden tek mesh: hale başına bir dörtgen, dört köşesi de merkezde (açılış shader'da). NORMAL lambanın baktığı
## yön (ilk iki nokta ön +Z, sonrakiler arka −Z): kameradan uzağa bakan lamba görünmez (gövdenin dışında havada parlamasın).
static func halo_mesh(points: PackedVector3Array) -> ArrayMesh:
	var verts: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var box: AABB = AABB()
	for i: int in points.size():
		box = AABB(points[i], Vector3.ZERO) if i == 0 else box.expand(points[i])
		var base: int = verts.size()
		var facing: Vector3 = Vector3.BACK if i < 2 else Vector3.FORWARD   # ilk ikisi ön (+Z), sonrakiler arka (−Z)
		for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			verts.append(points[i])
			uvs.append(corner)
			normals.append(facing)
		indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = box.grow(0.01)
	return mesh


## Shader ön ısıtması (WorldPrewarm): ilk dörtlüde derleme takılması olmasın.
static func prewarm_nodes() -> Array[Node3D]:
	var halo: MeshInstance3D = MeshInstance3D.new()
	halo.mesh = halo_mesh(PackedVector3Array([Vector3.ZERO]))
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter(&"duty", 1.0)
	halo.material_override = material
	return [halo]
