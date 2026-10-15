class_name LuxurySparkles
extends MultiMeshInstance3D
## LÜKS EŞYA IŞILTILARI — garajdaki elmasla alınmış eşyaların (GarageDecor.is_gem_item) üstünde ara ara
## parlayan küçük yıldızlar. Uzak oyun kamerasında "bu pahalı" okunsun diye. Bütün yıldızlar TEK MultiMesh'tir
## (tek çizim çağrısı; garajın çizim bütçesi dar), animasyon tamamen shader'da (kare başına betik işi yok).
## GarageDecorView.refresh() yıldızları gövdelerin güncel kutularına yeniden dağıtır; düzenlerken gizlidir.

const SHADER: Shader = preload("res://vfx/luxury_sparkle.gdshader")
## Eşya başına yıldız (büyük eşyada bir fazlası).
const PER_ITEM: int = 2
const BIG_ITEM: float = 0.30
## Yıldızın en büyük yarıçapı (dünya birimi; araç ~0,6). Kutunun boyuna göre biraz büyür.
const STAR_SIZE: float = 0.034

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	name = "LuxurySparkles"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rng.seed = 7
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _star_mesh()
	multimesh = mm
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = SHADER
	material_override = material


## Yıldızları verilen dünya kutularına (eşya başına bir AABB) dağıtır: üst yarıda, öne yakın noktalar.
func place(boxes: Array[AABB]) -> void:
	var points: Array[Vector3] = []
	var sizes: Array[float] = []
	for box: AABB in boxes:
		var count: int = PER_ITEM + (1 if maxf(box.size.x, box.size.z) > BIG_ITEM else 0)
		for k: int in count:
			var p: Vector3 = box.position + Vector3(_rng.randf_range(0.15, 0.85) * box.size.x,
				_rng.randf_range(0.45, 1.0) * box.size.y, _rng.randf_range(0.5, 1.0) * box.size.z)
			points.append(p)
			sizes.append(STAR_SIZE * clampf(0.7 + box.size.length() * 0.8, 0.8, 1.6))
	var mm: MultiMesh = multimesh
	mm.instance_count = points.size()
	for i: int in points.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, to_local(points[i])))
		mm.set_instance_custom_data(i, Color(_rng.randf(), sizes[i], 0.0, 0.0))
	visible = points.size() > 0


## Dört köşeli yıldız (XY düzleminde, yarıçap 1): ince uzun dört ışın, ortada küçük gövde.
static func _star_mesh() -> ArrayMesh:
	var verts: PackedVector3Array = PackedVector3Array()
	var center: Vector3 = Vector3.ZERO
	var tips: Array[Vector3] = [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, -1, 0)]
	var waist: float = 0.16
	for k: int in tips.size():
		var tip: Vector3 = tips[k]
		var side: Vector3 = Vector3(-tip.y, tip.x, 0.0) * waist
		verts.append_array([center + side, tip, center])
		verts.append_array([center, tip, center - side])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
