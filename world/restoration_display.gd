class_name RestorationDisplay
extends Node3D
## GARAJDAKİ RESTORASYON PROJESİ — tamir alanının liftinde duran araç, üç aşama (docs/HURDALIK_TASARIM.md §4):
##   0  %0–33   çıplak demir şasi (assets/world/restoration_chassis.glb, tools/world/export_chassis.py)
##   1  %34–99  aracın kendisi, PASLI (vfx/rust_overlay.gdshader) ve tekerleksiz, şasinin üstünde.
##              İlerledikçe pas azalır (parçalar takıldıkça araç toparlanıyor).
##   2  %100    temiz, parlak araç (kendi tekerleriyle) + kıvılcım: BİTİR'i bekler
## CarSpot'un çocuğudur: alan taşınınca / döndürülünce birlikte gider (RepairLift gibi). Seçim mevcut
## CarHitbox ile (TrafficVehicle'daki kurulumun aynısı); RestorationBays seçimi izler.

const CHASSIS_SCENE: String = "res://assets/world/restoration_chassis.glb"
const CHASSIS_LENGTH: float = 4.22   # şasinin gerçek boyu (m), aracın boyuna göre ölçeklenir
const RUST_SHADER: Shader = preload("res://vfx/rust_overlay.gdshader")
const CarHitboxScript: GDScript = preload("res://car_hitbox.gd")
## Şehirde araç ölçeği (TrafficManager.model_scale): lifteki müşteri araçlarıyla aynı boy.
const CITY_SCALE: float = 0.6
const STAGE_RUSTY: float = 0.34
const BUBBLE_GAP: float = 0.04

var vehicle_id: StringName = &""
var bay: int = -1
var stage: int = -1
var progress: float = 0.0
var model: Node3D
var rig: CarRig
var chassis: Node3D
var _box: AABB = AABB(Vector3(-0.15, 0.0, -0.3), Vector3(0.3, 0.25, 0.6))
var _rust: ShaderMaterial
var _bubble: CarBubble


## Kurulum (ağaca eklenmeden önce çağrılır).
func setup(id: StringName, bay_index: int, start_progress: float) -> void:
	vehicle_id = id
	bay = bay_index
	progress = start_progress
	name = "Restoration_%s" % id


func _ready() -> void:
	var path: String = CarCatalog.scene_path(vehicle_id)
	if path != "":
		model = (load(path) as PackedScene).instantiate() as Node3D
		model.scale = Vector3.ONE * CITY_SCALE * CarCatalog.model_scale(vehicle_id)
		add_child(model)
		rig = CarRig.new(model)
		rig.apply(CarAppearance.get_for(path))
		rig.set_lod_bias(CarRig.LOD_BIAS_NPC)
		_box = _model_box()
	_build_chassis()
	_add_hitbox()
	_bubble = CarBubble.new()
	_bubble.position = Vector3(0.0, _box.end.y + BUBBLE_GAP + CarBubble.HEIGHT * 0.5, 0.0)
	add_child(_bubble)
	set_progress(progress, false)


## İlerleme değişti: aşama ve pas miktarı güncellenir. celebrate: %100'e yeni ulaşıldıysa kıvılcım.
func set_progress(value: float, celebrate: bool = true) -> void:
	progress = clampf(value, 0.0, 1.0)
	var next: int = 2 if progress >= 1.0 else (1 if progress >= STAGE_RUSTY else 0)
	if next != stage:
		stage = next
		_apply_stage()
		if stage == 2 and celebrate:
			_sparkle()
	if _rust:
		# %34'te yoğun pas (aracın rengi aralardan görünür), %99'da hafif
		_rust.set_shader_parameter(&"amount", lerpf(0.65, 0.2, inverse_lerp(STAGE_RUSTY, 1.0, progress)))
	if _bubble:
		if stage == 2:
			_bubble.show_text(Loc.t("HAZIR"), CarBubble.GLYPH_WRENCH)
		else:
			_bubble.show_text("%%%d" % int(floorf(progress * 100.0)), CarBubble.GLYPH_WRENCH)


func _apply_stage() -> void:
	if model:
		model.visible = stage >= 1
	if rig:
		rig.set_wheels_visible(stage == 2)
	if chassis:
		chassis.visible = stage < 2
	_set_rust(stage == 1)


func _set_rust(on: bool) -> void:
	if model == null:
		return
	if on and _rust == null:
		_rust = ShaderMaterial.new()
		_rust.shader = RUST_SHADER
		_rust.set_shader_parameter(&"base_y", global_position.y + _box.position.y)
		_rust.set_shader_parameter(&"height", _box.size.y)
		_rust.set_shader_parameter(&"density", 22.0)
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_overlay = _rust if on else null


func _build_chassis() -> void:
	if not ResourceLoader.exists(CHASSIS_SCENE):
		return
	chassis = (load(CHASSIS_SCENE) as PackedScene).instantiate() as Node3D
	# Şasi aracın boyuna oturur (gerçek oran korunur), aracın kutusunun ortasında
	var s: float = _box.size.z * 0.92 / CHASSIS_LENGTH
	chassis.scale = Vector3.ONE * s
	chassis.position = Vector3(_box.get_center().x, 0.0, _box.get_center().z)
	add_child(chassis)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.7
	material.metallic = 0.25
	for node: Node in chassis.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i: int in mi.mesh.get_surface_count():
			mi.set_surface_override_material(i, material)


## Aracın kutusu (bu düğümün uzayında): şasi ölçüsü, seçim kutusu, balon yüksekliği.
func _model_box() -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		var local: Transform3D = global_transform.affine_inverse() * mi.global_transform if is_inside_tree() \
			else model.transform * mi.transform
		var b: AABB = local * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box if not first else _box


## Seçim: TrafficVehicle._add_hitbox ile aynı (SelectionRing önce eklenmeli: car_hitbox _ready'de arar).
func _add_hitbox() -> void:
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.name = "SelectionRing"
	ring.position = Vector3(0.0, _box.size.y, 0.0)
	ring.visible = false
	add_child(ring)
	var hitbox: StaticBody3D = StaticBody3D.new()
	hitbox.name = "CarHitbox"
	hitbox.set_script(CarHitboxScript)
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = _box.size
	shape.shape = box_shape
	shape.position = _box.get_center()
	hitbox.add_child(shape)
	add_child(hitbox)


## %100: aracın üstünde kısa kıvılcım yağmuru.
func _sparkle() -> void:
	var sparks: CPUParticles3D = CPUParticles3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.025, 0.025)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	quad.material = material
	sparks.mesh = quad
	sparks.one_shot = true
	sparks.amount = 40
	sparks.lifetime = 1.2
	sparks.explosiveness = 0.9
	sparks.direction = Vector3.UP
	sparks.spread = 60.0
	sparks.initial_velocity_min = 0.4
	sparks.initial_velocity_max = 0.9
	sparks.gravity = Vector3(0.0, -1.2, 0.0)
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color("FFE08A"))
	ramp.set_color(1, Color(1.0, 0.75, 0.3, 0.0))
	sparks.color_ramp = ramp
	sparks.position = Vector3(0.0, _box.end.y, 0.0)
	add_child(sparks)
	sparks.emitting = true
	sparks.finished.connect(sparks.queue_free)
