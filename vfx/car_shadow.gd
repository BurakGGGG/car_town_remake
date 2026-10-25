class_name CarShadow
extends MeshInstance3D
## HAREKETLİ ARACIN GÖLGESİ (2026-10-25) — trafik / müşteri araçları ve liftteki gösterim araçları pişmiş şehir
## gölgesine (WorldShadow) giremez: haritayı her karede yeniden çizmek pahalı. Her araç kendi gölgesini taşır: altında
## düz bir dörtgen, shader'da güneş yönüne süpürülmüş iki kutu (vfx/car_shadow.gdshader). Yön ve renk pişmiş
## gölgeyle aynıdır; araç dönünce gölge doğru tarafta kalır. Maliyet: araç başına bir küçük saydam çizim.
##
## Sahibi WorldShadow.DYNAMIC_GROUP'a girer (haritaya ikinci kez çizilmesin). Yalnız şehrin dünyasında kurulur.

const SHADER: Shader = preload("res://vfx/car_shadow.gdshader")
const GROUP: StringName = &"car_shadow"
## Zeminden yükseklik: yol çizgilerinin / işaretlerin üstünde, lastiklerin altında kalsın.
const LIFT: float = 0.004
## Kutu modelin dış kutusundan biraz dar (yuvarlak kaporta, ayna payı).
const INSET: float = 0.9

var _material: ShaderMaterial
var _box: AABB


## `model` sahibin doğrudan çocuğu olmalı (TrafficVehicle.model, PerformanceBayDisplay.model...).
static func attach(holder: Node3D, model: Node3D) -> CarShadow:
	var shadow: CarShadow = CarShadow.new()
	shadow.name = "CarShadow"
	shadow._box = _bounds(model)
	shadow.visible = model.visible
	model.visibility_changed.connect(func() -> void:   # gizli araç (restorasyon 0. aşama) gölge düşürmez
		if is_instance_valid(shadow):
			shadow.visible = model.visible)
	holder.add_to_group(WorldShadow.DYNAMIC_GROUP)
	holder.add_child(shadow)
	return shadow


func _ready() -> void:
	add_to_group(GROUP)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var scene: Node = get_tree().current_scene
	var sun: DirectionalLight3D = scene.get_node_or_null("Sun") as DirectionalLight3D if scene else null
	if sun == null or sun.get_world_3d() != get_world_3d() or _box.size == Vector3.ZERO:
		queue_free()   # şehrin dışında (ekranların kendi dünyaları): gölgesi pişmiş ya da kendi ışığıyla
		return
	var to_sun: Vector3 = sun.global_transform.basis.z.normalized()
	var shift: Vector3 = Vector3(-to_sun.x, 0.0, -to_sun.z) / maxf(to_sun.y, 0.2)
	var half: Vector2 = Vector2(_box.size.x, _box.size.z) * 0.5 * INSET
	var center: Vector2 = Vector2(_box.get_center().x, _box.get_center().z)
	var reach: float = _box.end.y * shift.length()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = (half + Vector2(reach, reach)) * 2.0 + Vector2(0.06, 0.06)
	mesh = plane
	position = Vector3(center.x, LIFT, center.y)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("half_size", half)
	_material.set_shader_parameter("center", Vector2.ZERO)
	_material.set_shader_parameter("height", _box.end.y)
	_material.set_shader_parameter("sun_shift", shift)
	_material.set_shader_parameter("base_y", (get_parent() as Node3D).global_position.y)
	var world_shadow: WorldShadow = get_tree().get_first_node_in_group(WorldShadow.GROUP) as WorldShadow
	apply_tint(world_shadow.tint_value() if world_shadow else WorldShadow.default_tint())
	material_override = _material


func apply_tint(value: Vector4) -> void:
	if _material:
		_material.set_shader_parameter("tint", value)


## Modelin, sahibine göre (modelin kendi dönüşümü dahil) dış kutusu; sahne ağacında olması gerekmez.
static func _bounds(model: Node3D) -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	var stack: Array = [[model, model.transform]]
	while not stack.is_empty():
		var pair: Array = stack.pop_back()
		var node: Node = pair[0]
		var xform: Transform3D = pair[1]
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi and mi.mesh and mi.visible:
			var part: AABB = xform * mi.get_aabb()
			box = part if first else box.merge(part)
			first = false
		for child: Node in node.get_children():
			if child is Node3D:
				stack.append([child, xform * (child as Node3D).transform])
	return box
