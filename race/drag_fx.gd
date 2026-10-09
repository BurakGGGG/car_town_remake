class_name DragFx
extends Node3D
## Bir yarış aracının efektleri: EGZOZ ALEVİ (vites anında patlar) ve PATİNAJ DUMANI (kalkışta
## lastikler kayarken pistte geride kalan duman). Yalnızca GÖRSEL; ne zaman tetikleneceğine
## DragRaceScreen karar verir.
##
## Aracın çocuğu DEĞİLDİR (araç ölçeklenmiş, dönüyor): pist dünyasında durur, her kare
## `follow()` ile aracın konumuna taşınır. Alev yerel koordinatta kalır (egzoza yapışık), duman
## dünya koordinatında: araç ilerledikçe arkasında iz bırakır.
##
## Mobil bütçe: iki CPUParticles3D, quad + yumuşak radyal maske, gölgesiz, ışıksız.

## Araç ölçeğinde arka tampon ve arka teker hizası (modeller boyu 1,0'e normalize, +Z'ye bakıyor).
const REAR_Z: float = -0.60
const WHEEL_Z: float = -0.40
const WHEEL_SPREAD: float = 0.27

var _flame: CPUParticles3D
var _smoke: CPUParticles3D


func _init(scale_factor: float) -> void:
	name = "DragFx"
	_flame = _make_flame(scale_factor)
	add_child(_flame)
	_smoke = _make_smoke(scale_factor)
	add_child(_smoke)


func follow(car: Node3D) -> void:
	if is_instance_valid(car):
		position = car.position


## Egzoz alevi: `strength` 0-1 (kusursuz vites büyük ve parlak, kötü vites küçük öksürük).
func flame(strength: float) -> void:
	var s: float = clampf(strength, 0.0, 1.0)
	_flame.amount = 6 + int(round(s * 8.0))
	_flame.scale_amount_min = lerpf(0.45, 0.8, s)
	_flame.scale_amount_max = lerpf(0.8, 1.45, s)
	_flame.initial_velocity_max = lerpf(1.6, 3.4, s)
	_flame.restart()


## Patinaj dumanı: yoğunluk 0 → kapalı. Duman dünyada kalır (araç kaçarken bulut geride).
func set_smoke(intensity: float) -> void:
	var on: bool = intensity > 0.05
	if on != _smoke.emitting:
		_smoke.emitting = on
	if on:
		_smoke.speed_scale = lerpf(0.7, 1.2, clampf(intensity, 0.0, 1.0))


func _make_flame(k: float) -> CPUParticles3D:
	var flame: CPUParticles3D = CPUParticles3D.new()
	flame.name = "Flame"
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.20, 0.20) * k
	var material: StandardMaterial3D = _additive(DragRaceScreen.puff_texture())
	quad.material = material
	flame.mesh = quad
	flame.local_coords = true
	flame.one_shot = true
	flame.emitting = false
	flame.amount = 10
	flame.lifetime = 0.17
	flame.explosiveness = 0.92
	flame.position = Vector3(0.0, 0.12 * k, REAR_Z * k)
	flame.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	flame.emission_box_extents = Vector3(0.13 * k, 0.01, 0.01)
	flame.direction = Vector3(0.0, 0.08, -1.0)
	flame.spread = 12.0
	flame.gravity = Vector3.ZERO
	flame.initial_velocity_min = 1.0
	flame.initial_velocity_max = 2.6
	flame.damping_min = 6.0
	flame.damping_max = 9.0
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(1.0, 0.97, 0.80, 1.0))
	ramp.set_color(1, Color(0.95, 0.25, 0.05, 0.0))
	ramp.add_point(0.35, Color(1.0, 0.70, 0.18, 0.95))
	flame.color_ramp = ramp
	var shrink: Curve = Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.35))
	flame.scale_amount_curve = shrink
	return flame


func _make_smoke(k: float) -> CPUParticles3D:
	var smoke: CPUParticles3D = CPUParticles3D.new()
	smoke.name = "TireSmoke"
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.42, 0.42) * k
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = DragRaceScreen.puff_texture()
	quad.material = material
	smoke.mesh = quad
	smoke.local_coords = false
	smoke.emitting = false
	smoke.amount = 36
	smoke.lifetime = 1.5
	smoke.position = Vector3(0.0, 0.06 * k, WHEEL_Z * k)
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	smoke.emission_box_extents = Vector3(WHEEL_SPREAD * k, 0.02, 0.06)
	smoke.direction = Vector3(0.0, 0.5, -1.0)
	smoke.spread = 40.0
	smoke.gravity = Vector3(0.0, 0.35, 0.0)
	smoke.initial_velocity_min = 0.4
	smoke.initial_velocity_max = 1.1
	smoke.damping_min = 0.6
	smoke.damping_max = 1.2
	smoke.angle_min = -180.0
	smoke.angle_max = 180.0
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(0.95, 0.94, 0.91, 0.0))
	ramp.set_color(1, Color(0.90, 0.89, 0.86, 0.0))
	ramp.add_point(0.12, Color(0.96, 0.95, 0.92, 0.62))
	smoke.color_ramp = ramp
	var grow: Curve = Curve.new()
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(1.0, 1.0))
	smoke.scale_amount_curve = grow
	smoke.scale_amount_min = 0.9
	smoke.scale_amount_max = 1.9
	return smoke


static func _additive(texture: Texture2D) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = texture
	return material
