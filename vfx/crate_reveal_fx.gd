class_name CrateRevealFx
extends Node3D
## KASA AÇILIŞ EFEKTLERİ — nadirliğe göre büyüyen sahne: gerilimde aralıklardan sızan ışık ve
## kıvılcım, açılışta parlama + yerde şok dalgası + konfeti; epikte ışık sütunu, efsanevide dönen
## ışık hüzmeleri; araç inince toz. Yalnızca GÖRSEL: ödülü CrateManager çoktan vermiştir.
##
## CrateDelivery kasanın konumunda kurar ve sahne boyunca tutar; sonuç plakası kapanınca fade_out().
## Mobil bütçe: CPUParticles3D + quad/silindir, gölgesiz, tek OmniLight; dokular kodla üretilir.

## Kasanın yaklaşık yüksekliği (dünya birimi, CrateCatalog.world_size().y).
const CRATE_H: float = 0.38

var _color: Color = Color.WHITE
var _rank: int = 0
var _light: OmniLight3D
var _leak: CPUParticles3D
var _pieces: Array[Node3D] = []   # sönerken küçülecek parçalar (sütun, hüzmeler)
var _rays: Node3D

static var _ring_texture: GradientTexture2D
static var _soft_texture: GradientTexture2D
static var _beam_texture: GradientTexture2D


## `rank`: CrateCatalog.rarity_rank (0 sıradan … 3 efsanevi).
func setup(color: Color, rank: int) -> void:
	name = "CrateRevealFx"
	_color = color
	_rank = rank
	_light = OmniLight3D.new()
	_light.name = "RevealLight"
	_light.light_color = color
	_light.omni_range = 1.0 + 0.15 * float(rank)
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	_light.position = Vector3(0.0, CRATE_H * 0.6, 0.0)
	add_child(_light)


## Işık kaynağı (open_effect sahnesi buna eklenir).
func light() -> OmniLight3D:
	return _light


## GERİLİM: kasanın içinden ışık büyür, aralıklardan nadirlik renginde kıvılcım sızar.
func suspense(duration: float) -> void:
	_leak = _particles(18 + 8 * _rank, 0.7, soft_texture(), 0.035)
	_leak.position = Vector3(0.0, CRATE_H * 0.5, 0.0)
	_leak.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_leak.emission_box_extents = Vector3(0.36, CRATE_H * 0.45, 0.23)
	_leak.direction = Vector3.UP
	_leak.spread = 35.0
	_leak.gravity = Vector3(0.0, 0.4, 0.0)
	_leak.initial_velocity_min = 0.15
	_leak.initial_velocity_max = 0.45
	_leak.color_ramp = fade_ramp(_color.lightened(0.35))
	_leak.emitting = true
	var tween: Tween = create_tween()
	tween.tween_property(_light, "light_energy", 1.4 + 0.4 * float(_rank), duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## AÇILIŞ ANI: parlama, şok dalgası, konfeti; nadirliğe göre ışık sütunu ve dönen hüzmeler.
func burst() -> void:
	if _leak:
		_leak.emitting = false
	var peak: float = 6.0 + 1.5 * float(_rank)
	var tween: Tween = create_tween()
	tween.tween_property(_light, "light_energy", peak, 0.08)
	tween.tween_property(_light, "light_energy", 1.6 + 0.5 * float(_rank), 0.7) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_shockwave(0.0, 1.0)
	if _rank >= 2:
		_shockwave(0.12, 0.7)
	_confetti()
	_sparks()
	if _rank >= 2:
		_pillar()
	if _rank >= 3:
		_build_rays()


## Kapak havada kayboldu: o noktada küçük parıltı patlaması.
func poof(at: Vector3) -> void:
	var stars: CPUParticles3D = _particles(16 + 4 * _rank, 0.55, soft_texture(), 0.04)
	stars.global_position = at
	stars.one_shot = true
	stars.explosiveness = 1.0
	stars.spread = 180.0
	stars.gravity = Vector3(0.0, -0.6, 0.0)
	stars.initial_velocity_min = 0.4
	stars.initial_velocity_max = 0.9
	stars.color_ramp = fade_ramp(Color(1.0, 0.95, 0.75).lerp(_color, 0.35), 0.4)
	stars.emitting = true


## Araç yere indi: tekerlerin altından toz bulutu.
func dust(at: Vector3) -> void:
	var puff: CPUParticles3D = _particles(14, 0.9, DragRaceScreen.puff_texture(), 0.16)
	puff.global_position = at + Vector3(0.0, 0.02, 0.0)
	puff.one_shot = true
	puff.explosiveness = 0.9
	puff.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	puff.emission_ring_axis = Vector3.UP
	puff.emission_ring_radius = 0.22
	puff.emission_ring_inner_radius = 0.12
	puff.emission_ring_height = 0.01
	puff.direction = Vector3(0.0, 0.2, 0.0)
	puff.spread = 90.0
	puff.flatness = 0.8
	puff.gravity = Vector3(0.0, 0.05, 0.0)
	puff.initial_velocity_min = 0.25
	puff.initial_velocity_max = 0.55
	puff.damping_min = 0.6
	puff.damping_max = 1.0
	puff.color_ramp = fade_ramp(Color(0.86, 0.83, 0.78, 0.6))
	puff.emitting = true


## Sonuç plakası kapandı: her şey söner (CrateDelivery sonra serbest bırakır).
func fade_out(duration: float) -> void:
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_light, "light_energy", 0.0, duration)
	for piece: Node3D in _pieces:
		if is_instance_valid(piece):
			tween.tween_property(piece, "scale", Vector3(0.01, piece.scale.y, 0.01), duration) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tween.finished


func _process(delta: float) -> void:
	if is_instance_valid(_rays):
		_rays.rotate_y(delta * 0.9)


# --- Parçalar --------------------------------------------------------------------------

## Yerde genişleyen parlak halka.
func _shockwave(delay: float, strength: float) -> void:
	var ring: MeshInstance3D = MeshInstance3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE
	quad.orientation = PlaneMesh.FACE_Y
	ring.mesh = quad
	var material: StandardMaterial3D = additive(ring_texture())
	material.albedo_color = Color(_color.lightened(0.3), strength)
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = Vector3(0.0, 0.015, 0.0)
	ring.scale = Vector3.ONE * 0.2
	add_child(ring)
	var size: float = 1.6 + 0.35 * float(_rank)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * size, 0.55).set_delay(delay) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.55).set_delay(delay) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(ring.queue_free)


## Konfeti: nadirlik rengi + altın + beyaz; yukarı fışkırır, dönerek yavaşça düşer.
func _confetti() -> void:
	var count: int = 26 + 14 * _rank
	var confetti: CPUParticles3D = _particles(count, 1.9, null, 0.028, false)
	confetti.position = Vector3(0.0, CRATE_H * 0.8, 0.0)
	confetti.one_shot = true
	confetti.explosiveness = 0.95
	confetti.direction = Vector3.UP
	confetti.spread = 50.0
	confetti.gravity = Vector3(0.0, -1.1, 0.0)
	confetti.initial_velocity_min = 1.1
	confetti.initial_velocity_max = 1.9 + 0.2 * float(_rank)
	confetti.damping_min = 0.9
	confetti.damping_max = 1.6
	confetti.angular_velocity_min = -540.0
	confetti.angular_velocity_max = 540.0
	confetti.scale_amount_min = 0.7
	confetti.scale_amount_max = 1.3
	var palette: Gradient = Gradient.new()
	palette.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	palette.set_color(0, _color)
	palette.set_color(1, Color("FFF6E5"))
	palette.add_point(0.4, Color("F5BE4C"))
	palette.add_point(0.7, _color.lightened(0.3))
	confetti.color_initial_ramp = palette
	confetti.color_ramp = fade_ramp(Color.WHITE, 0.75)
	confetti.emitting = true


## Açılışta kenarlardan sıçrayan parlak kıvılcımlar (yerçekimiyle düşer).
func _sparks() -> void:
	var sparks: CPUParticles3D = _particles(20 + 8 * _rank, 0.65, soft_texture(), 0.03)
	sparks.position = Vector3(0.0, CRATE_H * 0.7, 0.0)
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.direction = Vector3.UP
	sparks.spread = 80.0
	sparks.gravity = Vector3(0.0, -3.0, 0.0)
	sparks.initial_velocity_min = 1.0
	sparks.initial_velocity_max = 2.2
	sparks.color_ramp = fade_ramp(Color(1.0, 0.92, 0.6).lerp(_color, 0.3))
	sparks.emitting = true


## EPİK+: kasadan göğe yükselen ışık sütunu (alta doğru parlak, uca doğru saydam).
func _pillar() -> void:
	var pillar: MeshInstance3D = MeshInstance3D.new()
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = 0.26
	cylinder.bottom_radius = 0.3
	cylinder.height = 3.0
	cylinder.radial_segments = 16
	cylinder.cap_top = false
	cylinder.cap_bottom = false
	pillar.mesh = cylinder
	var material: StandardMaterial3D = additive(beam_texture())
	material.albedo_color = Color(_color.lightened(0.2), 0.75)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	pillar.material_override = material
	pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pillar.position = Vector3(0.0, 1.5, 0.0)
	pillar.scale = Vector3(0.05, 1.0, 0.05)
	add_child(pillar)
	_pieces.append(pillar)
	var tween: Tween = create_tween()
	tween.tween_property(pillar, "scale", Vector3(1.15, 1.0, 1.15), 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(pillar, "scale", Vector3(0.75, 1.0, 0.75), 0.8)


## EFSANEVİ: kasanın üstünde yavaşça dönen ışık hüzmeleri (yelpaze).
func _build_rays() -> void:
	_rays = Node3D.new()
	_rays.name = "Rays"
	_rays.position = Vector3(0.0, CRATE_H * 0.9, 0.0)
	add_child(_rays)
	_pieces.append(_rays)
	var count: int = 8
	for i: int in count:
		var ray: MeshInstance3D = MeshInstance3D.new()
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2(0.09, 1.3)
		quad.center_offset = Vector3(0.0, 0.65, 0.0)
		ray.mesh = quad
		var material: StandardMaterial3D = additive(beam_texture())
		material.albedo_color = Color(_color.lightened(0.4), 0.55)
		material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		ray.material_override = material
		ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Dışa ve hafif yukarı yatık yelpaze
		ray.rotation = Vector3(0.0, TAU * float(i) / float(count), 0.0)
		ray.rotate_object_local(Vector3.RIGHT, deg_to_rad(58.0))
		_rays.add_child(ray)
	_rays.scale = Vector3.ONE * 0.05
	var tween: Tween = create_tween()
	tween.tween_property(_rays, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- Yardımcılar -----------------------------------------------------------------------

func _particles(amount: int, lifetime: float, texture: Texture2D, size: float,
		billboard: bool = true) -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(size, size)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if billboard:
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	if texture:
		material.albedo_texture = texture
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if texture != DragRaceScreen.puff_texture() \
			else BaseMaterial3D.BLEND_MODE_MIX
	quad.material = material
	p.mesh = quad
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.emitting = false
	add_child(p)
	return p


static func additive(texture: Texture2D) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_texture = texture
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## Ömür boyunca renk: tam görünür başlar, sonda söner.
static func fade_ramp(color: Color, hold: float = 0.5) -> Gradient:
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color, 0.0))
	ramp.add_point(hold, color)
	return ramp


## Yumuşak nokta (kıvılcım / ışık zerresi).
static func soft_texture() -> GradientTexture2D:
	if _soft_texture == null:
		_soft_texture = _radial([[0.0, Color(1, 1, 1, 1)], [0.35, Color(1, 1, 1, 0.8)], [1.0, Color(1, 1, 1, 0)]])
	return _soft_texture


## Şok dalgası: içi boş, kenarı parlak halka.
static func ring_texture() -> GradientTexture2D:
	if _ring_texture == null:
		_ring_texture = _radial([[0.0, Color(1, 1, 1, 0)], [0.62, Color(1, 1, 1, 0)],
			[0.82, Color(1, 1, 1, 1)], [1.0, Color(1, 1, 1, 0)]])
	return _ring_texture


## Işık sütunu / hüzme: altta parlak, yukarı doğru saydamlaşan dikey gradyan.
static func beam_texture() -> GradientTexture2D:
	if _beam_texture == null:
		var gradient: Gradient = Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 0))
		gradient.set_color(1, Color(1, 1, 1, 0.9))
		var texture: GradientTexture2D = GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill_from = Vector2(0.5, 0.0)
		texture.fill_to = Vector2(0.5, 1.0)
		texture.width = 8
		texture.height = 64
		_beam_texture = texture
	return _beam_texture


static func _radial(stops: Array) -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array()
	gradient.colors = PackedColorArray()
	for stop: Array in stops:
		gradient.add_point(float(stop[0]), stop[1])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture
