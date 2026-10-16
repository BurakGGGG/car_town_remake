class_name PoliceLights
extends RefCounted
## POLİS TAVAN IŞIKLARI — CarPartMap "police_lights" rolündeki parçalar (tavan çubuğu, ızgara flaşörü) çakar.
## CarRig kurar ve görünüm her uygulandığında lens materyalini parçalara takar; başka hiçbir yerde kod yok:
## trafik, garaj, showroom, kasa ve drag pisti aynı rig'i kullandığı için ışıklar her yerde kendiliğinden çakar.
##
## Maliyet: kare başı betik YOK — çakma GPU saatiyle (TIME) shader'da hesaplanır (police_beacon.gdshaderinc).
## Lens parçaları parça birleştirmeye (CarRig.optimize) girmez: yan ayrımı parçanın kendi yerel uzayında yapılır
## (birleşik mesh başka uzayda olurdu). Polis aracı başına +1 lens + 1 hale çizim çağrısı (Vito'da 4 parça +1).
## Dinamik ışık (OmniLight) bilerek YOK: GL Compatibility'de ışık nesne başına ek geçiştir, telefonda pahalı.
##
## Görünüm: lens = dokunun kırmızı / mavi texel'leri ışır (renk dokudan); hale = haritadaki "beacons" noktalarında
## kameraya dönük toplamalı parlama, aynı yarının lensiyle aynı karede yanar.

const LENS_SHADER: Shader = preload("res://vehicles/police_lights.gdshader")
const HALO_SHADER: Shader = preload("res://vehicles/police_beacon_halo.gdshader")

## FLASH: çakar (varsayılan) · LIT: iki yarı sürekli yanık, hale yok (küçük resim) · OFF: sönük
enum Mode { FLASH, LIT, OFF }

## Hale mesh'i araç tipi başına bir kez kurulur, instance'lar paylaşır.
static var _halo_meshes: Dictionary = {}

var _materials: Array[ShaderMaterial] = []   # lens materyalleri (farklı parça dönüşümü başına bir tane)
var _by_mesh: Dictionary = {}                # MeshInstance3D → lens materyali
var _halo: MeshInstance3D
var _halo_material: ShaderMaterial
var _mode: Mode = Mode.FLASH


func _init(root: Node3D, scene_path: String, meshes: Array[MeshInstance3D], albedo: Texture2D, beacons: Array) -> void:
	var phase: float = randf()   # her polis aracı kendi ritminde
	for mesh: MeshInstance3D in meshes:
		var plane: Vector4 = side_plane(mesh.transform)
		var material: ShaderMaterial = null
		for existing: ShaderMaterial in _materials:
			if (existing.get_shader_parameter(&"side_plane") as Vector4).is_equal_approx(plane):
				material = existing
				break
		if material == null:
			material = ShaderMaterial.new()
			material.shader = LENS_SHADER
			if albedo:
				material.set_shader_parameter(&"albedo_tex", albedo)
			material.set_shader_parameter(&"side_plane", plane)
			material.set_shader_parameter(&"phase", phase)
			_materials.append(material)
		_by_mesh[mesh] = material
	if beacons.is_empty():
		return
	_halo_material = ShaderMaterial.new()
	_halo_material.shader = HALO_SHADER
	_halo_material.set_shader_parameter(&"phase", phase)
	_halo = MeshInstance3D.new()
	_halo.name = "PoliceBeacons"
	_halo.mesh = halo_mesh(scene_path, beacons)
	_halo.material_override = _halo_material
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(_halo)


## Parçanın yerel uzayındaki köşeden ARAÇ uzayındaki x'i veren düzlem: x = dot(v, xyz) + w (dönüşümün X satırı).
static func side_plane(xf: Transform3D) -> Vector4:
	return Vector4(xf.basis.x.x, xf.basis.y.x, xf.basis.z.x, xf.origin.x)


## Haritadaki "beacons" noktalarından tek mesh: hale başına bir dörtgen, dört köşe de merkezde (açılış shader'da).
static func halo_mesh(scene_path: String, beacons: Array) -> ArrayMesh:
	if _halo_meshes.has(scene_path):
		return _halo_meshes[scene_path]
	var verts: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var sides: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()
	var box: AABB = AABB()
	for i: int in beacons.size():
		var beacon: Dictionary = beacons[i]
		var p: Array = beacon["pos"]
		var center: Vector3 = Vector3(p[0], p[1], p[2])
		box = AABB(center, Vector3.ZERO) if i == 0 else box.expand(center)
		var base: int = verts.size()
		for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			verts.append(center)
			uvs.append(corner)
			sides.append(Vector2(float(beacon.get("side", 1)), 0.0))
			colors.append(beacon.get("color", Color.WHITE))
		indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = sides
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# Köşeler merkezde toplandığı için kendi kutusu yassı. Küçük pay: araç kutusunu tüm mesh'lerden ölçen
	# ekranlar (garaj, showroom, tamir efekti) haleyi de sayar — pay büyürse araç kutusu şişer.
	mesh.custom_aabb = box.grow(0.01)
	_halo_meshes[scene_path] = mesh
	return mesh


## Lens materyalini parçalara takar (CarRig her görünüm uygulamasında çağırır).
func apply() -> void:
	for mesh: MeshInstance3D in _by_mesh:
		if is_instance_valid(mesh):
			mesh.set_surface_override_material(0, _by_mesh[mesh])


func meshes() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	out.assign(_by_mesh.keys())
	return out


func get_mode() -> Mode:
	return _mode


func set_mode(mode: Mode) -> void:
	_mode = mode
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter(&"mode", int(mode))
	if _halo_material:
		_halo_material.set_shader_parameter(&"mode", int(mode))
	if is_instance_valid(_halo):
		_halo.visible = mode == Mode.FLASH


## Shader ön ısıtması (WorldPrewarm): iki materyal görünmez bir yerde birkaç kare çizilsin, ilk polis aracı
## trafiğe girdiğinde derleme takılması olmasın.
static func prewarm_nodes() -> Array[Node3D]:
	var lens: MeshInstance3D = MeshInstance3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.01, 0.01)
	lens.mesh = quad
	var lens_material: ShaderMaterial = ShaderMaterial.new()
	lens_material.shader = LENS_SHADER
	lens.material_override = lens_material
	var halo: MeshInstance3D = MeshInstance3D.new()
	halo.mesh = halo_mesh("_prewarm", [{"pos": [0.0, 0.0, 0.0], "color": Color.BLACK, "side": 1}])
	var halo_material: ShaderMaterial = ShaderMaterial.new()
	halo_material.shader = HALO_SHADER
	halo_material.set_shader_parameter(&"mode", int(Mode.LIT))
	halo.material_override = halo_material
	return [lens, halo]
