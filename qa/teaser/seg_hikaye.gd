extends RefCounted
## 0–7 sn. (A) 0–3 GİZEM: karanlıkta paslı Lancia Delta Integrale, farlar titreyip yanar, kamera fardan
## geriye çekilip aracı ortaya çıkarır. (B) 3–7 BUL. TAMİR ET.: atölye ışıkları patlar, hızlı kesmeler —
## sökme (parçalar dağılır), teker değişimi, taşlama (pas kor halkayla silinir), toplama, tarayıcı kapı
## (pas arkadan öne silinir), kahraman çekimi.
const D = preload("res://qa/teaser/teaser.gd")
const ID: StringName = &"lancia_delta_integrale"
## Kesme anları (global saniye) — ses bandı (soundtrack.py) aynı listeyi kullanır.
const CUT_B: float = 3.0
const CUTS: Array[float] = [3.0, 3.533, 4.067, 4.6, 5.133, 6.2]   # 112,5 BPM vuruşları (0,533 sn)

var d: D
var world: Node3D
var env: Environment
var cam: Camera3D
var car: Node3D
var rig: CarRig
var box: AABB
var center: Vector3
var heads: Array[Vector3] = []
var head_lights: Array[SpotLight3D] = []
var beams: Array[MeshInstance3D] = []
var flares: Array[MeshInstance3D] = []
var lamp_twins: Array[MeshInstance3D] = []
var lamp_points: Array[Vector3] = []
var beam_mats: Array[ShaderMaterial] = []
var rust_mats: Array[ShaderMaterial] = []
var head_mat: StandardMaterial3D
var parts: Array[MeshInstance3D] = []
var part_base: Array[Transform3D] = []
var part_dir: Array[Vector3] = []
var part_spin: Array[Vector3] = []
var wheel_fl: Array[MeshInstance3D] = []
var wheel_center: Vector3
var rim_light: DirectionalLight3D
var work_lights: Array[Light3D] = []
var platform_ring: StandardMaterial3D
var platform: Node3D
var dust: CPUParticles3D
var sparks_a: CPUParticles3D
var sparks_b: CPUParticles3D
var sparks_scan: Array[CPUParticles3D] = []
var gate: Node3D
var gate_mat: StandardMaterial3D
var glint: OmniLight3D
var bulb: OmniLight3D
var t_title_story: Label
var t_bul: Label
var t_tamir: Label
var _prev_t: float = -1.0
var _repainted: bool = false


func run(director: D) -> void:
	d = director
	world = Node3D.new()
	d.vp.add_child(world)
	env = d.make_env(world, Color(0.004, 0.005, 0.009), Color(0.35, 0.42, 0.6), 0.05, 1.1)
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.035, 0.05)
	env.fog_density = 0.08
	env.fog_sky_affect = 0.0
	cam = Camera3D.new()
	cam.fov = 52.0
	cam.near = 0.02
	cam.far = 60.0
	world.add_child(cam)
	cam.make_current()
	_build_floor()
	_build_platform()
	car = d.spawn_car(ID, world, 1.2)
	rig = D.rig_of(car)
	await d.frames(3)
	box = D.car_box(car)
	center = box.get_center()
	_build_rust()
	_build_headlights()
	_collect_parts()
	_build_lights()
	_build_fx()
	_build_titles()
	await d.frames(5)
	await d.record(tick)


# --- Kurulum ------------------------------------------------------------------------------------

func _build_floor() -> void:
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(40.0, 40.0)
	floor_mesh.mesh = plane
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_texture = load("res://race/art/asphalt_dark.png")
	m.uv1_scale = Vector3(26.0, 26.0, 1.0)
	m.albedo_color = Color(0.3, 0.29, 0.28)
	m.roughness = 0.42
	m.metallic_specular = 0.7
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	floor_mesh.material_override = m
	world.add_child(floor_mesh)


## Atölye platformu: koyu metal disk + marka mavisi ışıklı halka (B'de yanar).
func _build_platform() -> void:
	platform = Node3D.new()
	world.add_child(platform)
	var disc: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 1.05
	cyl.bottom_radius = 1.08
	cyl.height = 0.03
	cyl.radial_segments = 96
	disc.mesh = cyl
	disc.position.y = -0.012
	var dm: StandardMaterial3D = StandardMaterial3D.new()
	dm.albedo_color = Color(0.11, 0.115, 0.125)
	dm.metallic = 0.6
	dm.roughness = 0.35
	disc.material_override = dm
	platform.add_child(disc)
	var ring: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 1.035
	torus.outer_radius = 1.07
	torus.rings = 96
	ring.mesh = torus
	ring.scale = Vector3(1.0, 0.3, 1.0)
	ring.position.y = 0.005
	platform_ring = StandardMaterial3D.new()
	platform_ring.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	platform_ring.albedo_color = Color.BLACK
	ring.material_override = platform_ring
	platform.add_child(ring)


func _build_rust() -> void:
	var shader: Shader = preload("res://qa/teaser/rust_teaser.gdshader")
	var heavy: ShaderMaterial = _rust_mat(shader, 0.95)
	var light: ShaderMaterial = _rust_mat(shader, 0.55)
	var skip: Array[MeshInstance3D] = rig.get_meshes(&"headlights") + rig.get_meshes(&"taillights")
	var soft: Array[MeshInstance3D] = rig.get_meshes(&"glass") + rig.get_meshes(&"tires") + rig.get_meshes(&"wheels")
	for node: Node in car.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		if skip.has(mi):
			continue
		mi.material_overlay = light if soft.has(mi) else heavy


func _rust_mat(shader: Shader, amount: float) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter(&"amount", amount)
	m.set_shader_parameter(&"base_y", box.position.y)
	m.set_shader_parameter(&"height", box.size.y)
	m.set_shader_parameter(&"density", 19.0)
	rust_mats.append(m)
	return m


func _set_rust(key: StringName, value: Variant) -> void:
	for m: ShaderMaterial in rust_mats:
		m.set_shader_parameter(key, value)


func _build_headlights() -> void:
	var app: CarAppearance = D.appearance_of(car)
	app.headlights_enabled = true
	rig.apply(app)
	var lamps: Array[MeshInstance3D] = rig.get_meshes(&"headlights")
	head_mat = lamps[0].get_surface_override_material(0) as StandardMaterial3D
	# Yuvarlak farlar: sol çift ayrı parça (CarPartMap headlights 37/38); sağ çift gövde dokusunda →
	# sol çiftin aynası, aynı ışıyan materyalle tam üstüne konur.
	head_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mirror: Transform3D = Transform3D(Basis.from_scale(Vector3(-1.0, 1.0, 1.0)), Vector3(2.0 * center.x, 0.0, 0.0))
	var side_l: Vector3 = Vector3.ZERO
	var side_r: Vector3 = Vector3.ZERO
	for lamp: MeshInstance3D in lamps:
		var twin: MeshInstance3D = MeshInstance3D.new()
		twin.mesh = lamp.mesh
		twin.material_override = head_mat
		world.add_child(twin)
		twin.global_transform = mirror * lamp.global_transform
		twin.global_position += Vector3(0.0, 0.0, 0.002)
		lamp_twins.append(twin)
		var c: Vector3 = (lamp.global_transform * lamp.get_aabb()).get_center()
		var m: Vector3 = Vector3(2.0 * center.x - c.x, c.y, c.z)
		lamp_points.append(c)
		lamp_points.append(m)
		side_l += c
		side_r += m
	heads.append(side_l / float(lamps.size()))
	heads.append(side_r / float(lamps.size()))
	for p: Vector3 in lamp_points:
		var flare: MeshInstance3D = D.make_glow_sprite(Color(1.0, 0.92, 0.8) * 0.7, 0.11)
		world.add_child(flare)
		flare.global_position = p + Vector3(0.0, 0.0, 0.02)
		flares.append(flare)
	var beam_shader: Shader = preload("res://qa/teaser/beam.gdshader")
	for h: Vector3 in heads:
		var spot: SpotLight3D = SpotLight3D.new()
		spot.light_color = Color(1.0, 0.88, 0.68)
		spot.spot_range = 7.0
		spot.spot_angle = 24.0
		spot.spot_attenuation = 1.6
		spot.light_energy = 0.0
		spot.shadow_enabled = true
		world.add_child(spot)
		spot.global_position = h + Vector3(0.0, 0.0, 0.02)
		spot.look_at(h + Vector3(0.0, -0.09, 1.0), Vector3.UP)
		head_lights.append(spot)
		var holder: Node3D = Node3D.new()
		world.add_child(holder)
		holder.global_position = h + Vector3(0.0, 0.0, 0.015)
		var dir: Vector3 = Vector3(0.0, -0.07, 1.0).normalized()
		holder.global_basis = Basis.looking_at(dir) * Basis(Vector3.RIGHT, PI * 0.5)
		var cone: MeshInstance3D = MeshInstance3D.new()
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.top_radius = 0.035
		cyl.bottom_radius = 0.75
		cyl.height = 3.2
		cyl.radial_segments = 32
		cyl.cap_top = false
		cyl.cap_bottom = false
		cone.mesh = cyl
		cone.position = Vector3(0.0, -1.6, 0.0)
		var bm: ShaderMaterial = ShaderMaterial.new()
		bm.shader = beam_shader
		bm.set_shader_parameter(&"intensity", 0.0)
		cone.material_override = bm
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(cone)
		beams.append(cone)
		beam_mats.append(bm)


func _collect_parts() -> void:
	for node: Node in car.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		if not mi.visible:
			continue
		parts.append(mi)
		part_base.append(mi.global_transform)
		var c: Vector3 = (mi.global_transform * mi.get_aabb()).get_center()
		var dir: Vector3 = c - center
		dir.y = maxf(dir.y, 0.0) * 1.6 + 0.25
		part_dir.append(dir.normalized() * randf_range(0.28, 0.5))
		part_spin.append(Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 0.9)
	# Sol ön teker grubu (+X tarafı, ön = +Z): kameraya en yakın teker
	var wheel_roles: Array[MeshInstance3D] = rig.get_meshes(&"wheels") + rig.get_meshes(&"tires") + rig.get_meshes(&"rims")
	var acc: Vector3 = Vector3.ZERO
	for mi: MeshInstance3D in wheel_roles:
		var c: Vector3 = (mi.global_transform * mi.get_aabb()).get_center()
		if c.x > center.x and c.z > center.z:
			wheel_fl.append(mi)
			acc += c
	wheel_center = acc / maxf(1.0, float(wheel_fl.size()))


func _build_lights() -> void:
	rim_light = DirectionalLight3D.new()
	rim_light.light_color = Color(0.45, 0.6, 1.0)
	rim_light.light_energy = 0.0
	rim_light.shadow_enabled = true
	world.add_child(rim_light)
	rim_light.rotation_degrees = Vector3(-30.0, 180.0 + 25.0, 0.0)
	var key: SpotLight3D = SpotLight3D.new()
	key.light_color = Color(0.92, 0.95, 1.0)
	key.spot_range = 8.0
	key.spot_angle = 48.0
	key.shadow_enabled = true
	world.add_child(key)
	key.global_position = Vector3(0.3, 2.6, 0.4)
	key.look_at(Vector3(0.0, 0.0, 0.0), Vector3.FORWARD)
	work_lights.append(key)
	var fill_b: OmniLight3D = OmniLight3D.new()
	fill_b.light_color = Color(0.35, 0.55, 1.0)
	fill_b.omni_range = 4.0
	world.add_child(fill_b)
	fill_b.global_position = Vector3(1.6, 0.5, -0.8)
	work_lights.append(fill_b)
	var fill_g: OmniLight3D = OmniLight3D.new()
	fill_g.light_color = Color(1.0, 0.75, 0.35)
	fill_g.omni_range = 4.0
	world.add_child(fill_g)
	fill_g.global_position = Vector3(-1.6, 0.6, 1.0)
	work_lights.append(fill_g)
	for l: Light3D in work_lights:
		l.light_energy = 0.0
	# Tepede sallanan çıplak ampul (A): titrer, paslı kaputu ve tavanı karanlıktan çıkarır
	bulb = OmniLight3D.new()
	bulb.light_color = Color(1.0, 0.72, 0.42)
	bulb.omni_range = 2.4
	bulb.omni_attenuation = 1.4
	bulb.shadow_enabled = true
	bulb.light_energy = 0.0
	world.add_child(bulb)
	glint = OmniLight3D.new()
	glint.light_color = Color(1.0, 0.97, 0.9)
	glint.omni_range = 0.7
	glint.light_energy = 0.0
	world.add_child(glint)


func _build_fx() -> void:
	dust = CPUParticles3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.0035, 0.0035)
	var dm: StandardMaterial3D = StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dm.albedo_color = Color(1.0, 0.85, 0.65, 0.35)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = dm
	dust.mesh = quad
	dust.amount = 220
	dust.lifetime = 6.0
	dust.preprocess = 6.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(0.6, 0.3, 1.0)
	dust.position = Vector3(center.x, 0.3, box.end.z + 1.0)
	dust.direction = Vector3(0.3, 0.2, -0.2)
	dust.spread = 180.0
	dust.initial_velocity_min = 0.005
	dust.initial_velocity_max = 0.03
	dust.gravity = Vector3(0.0, -0.002, 0.0)
	dust.scale_amount_min = 0.5
	dust.scale_amount_max = 1.6
	world.add_child(dust)
	sparks_a = D.make_sparks(Color(1.0, 0.6, 0.2), 140, 2.4)
	world.add_child(sparks_a)
	sparks_b = D.make_sparks(Color(1.0, 0.7, 0.3), 90, 1.8)
	world.add_child(sparks_b)
	# Tarayıcı kapı: aracı çevreleyen ışıklı çerçeve, arkadan öne geçer
	gate = Node3D.new()
	world.add_child(gate)
	gate_mat = StandardMaterial3D.new()
	gate_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gate_mat.albedo_color = Color(0.5, 0.8, 1.0) * 3.0
	var half_w: float = box.size.x * 0.5 + 0.12
	var top: float = box.end.y + 0.1
	for bar: Array in [[Vector3(-half_w, top * 0.5, 0.0), Vector3(0.012, top, 0.012)],
			[Vector3(half_w, top * 0.5, 0.0), Vector3(0.012, top, 0.012)],
			[Vector3(0.0, top, 0.0), Vector3(half_w * 2.0 + 0.012, 0.012, 0.012)],
			[Vector3(0.0, 0.004, 0.0), Vector3(half_w * 2.0, 0.006, 0.02)]]:
		var b: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = bar[1]
		b.mesh = bm
		b.position = bar[0]
		b.material_override = gate_mat
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gate.add_child(b)
	gate.position = Vector3(center.x, 0.0, -10.0)
	for side: float in [-1.0, 1.0]:
		var s: CPUParticles3D = D.make_sparks(Color(0.6, 0.85, 1.0), 60, 1.2)
		s.position = Vector3(side * half_w, top * 0.6, 0.0)
		s.direction = Vector3(side, 0.4, 0.0)
		s.spread = 50.0
		gate.add_child(s)
		sparks_scan.append(s)


func _build_titles() -> void:
	t_title_story = d.make_title("Her arabanın\nbir hikâyesi vardır.", 96, 0.2, 400, Color(0.95, 0.93, 0.9), 2)
	t_bul = d.make_title("BUL.", 150, 0.14, 900, Color.WHITE)
	t_tamir = d.make_title("TAMİR ET.", 150, 0.215, 900, D.BRAND_GOLD)


# --- Kare -----------------------------------------------------------------------------------------

func tick(t: float) -> void:
	d.reset_post()
	if t < CUT_B:
		_tick_story(t)
	else:
		_tick_repair(t)
	_prev_t = t


func _crossed(at: float, t: float) -> bool:
	return _prev_t < at and t >= at


## Farların parlaklığı 0..1 (A'da titreyerek yanar, A sonunda söner).
func _headlight_level(t: float) -> float:
	if t < CUT_B:
		if t < 0.35:
			return 0.0
		if t < 0.42:
			return 0.7
		if t < 0.52:
			return 0.05
		if t < 0.58:
			return 0.9
		if t < 0.63:
			return 0.2
		if t > 2.86:
			return 0.0
		return 1.0
	return 1.0 if t >= CUTS[5] else 0.0


func _apply_headlights(level: float, beam_k: float) -> void:
	head_mat.emission_energy_multiplier = 1.4 * level
	for s: SpotLight3D in head_lights:
		s.light_energy = 3.2 * level
	for m: ShaderMaterial in beam_mats:
		m.set_shader_parameter(&"intensity", 0.32 * level * beam_k)
	for tw: MeshInstance3D in lamp_twins:
		tw.visible = level > 0.01
	for f: MeshInstance3D in flares:
		f.visible = level > 0.01
		f.scale = Vector3.ONE * (0.6 + 0.4 * level)


func _tick_story(t: float) -> void:
	var lvl: float = _headlight_level(t)
	_apply_headlights(lvl, 1.0)
	for m: ShaderMaterial in beam_mats:
		m.set_shader_parameter(&"drift", t * 0.35)
	rim_light.light_energy = 0.22 * D.smooth(D.span(t, 0.4, 1.6))
	env.ambient_light_energy = 0.05
	var flick: float = 1.0
	for cut: Vector2 in [Vector2(1.32, 1.38), Vector2(1.45, 1.49), Vector2(2.21, 2.26)]:
		if t >= cut.x and t < cut.y:
			flick = 0.15
	bulb.light_energy = 1.5 * D.smooth(D.span(t, 0.7, 1.3)) * flick * (1.0 - D.span(t, 2.86, 2.9))
	bulb.global_position = Vector3(center.x - 0.25 + sin(t * 1.7) * 0.06, 0.95, center.z + 0.05 + cos(t * 1.3) * 0.04)
	platform.visible = false
	gate.visible = false
	dust.visible = true
	# Rölanti titreşimi
	car.position = Vector3(0.0, sin(t * 75.0) * 0.0012 * lvl, 0.0)
	car.rotation.z = sin(t * 61.0) * 0.0018 * lvl
	# Kamera: farın dibinden geriye çekilip aracı ortaya çıkarır
	var h: Vector3 = heads[0]
	var k: float = D.smooth(D.span(t, 0.3, 3.0))
	var start: Vector3 = h + Vector3(0.1, 0.015, 0.2)
	var finish: Vector3 = Vector3(center.x + 0.6, 0.3, box.end.z + 1.3)
	var pos: Vector3 = start.lerp(finish, k)
	var look: Vector3 = h.lerp(center + Vector3(0.0, 0.0, 0.2), D.smooth(D.span(t, 0.3, 2.6)))
	D.look_cam(cam, pos + D.shake(t, 0.003), look, -5.0 * (1.0 - k))
	cam.fov = lerpf(38.0, 44.0, k)
	# Son işleme: siyahtan açılış, sonda siyaha düşüş
	d.set_post(&"black", 1.0 - D.smooth(D.span(t, 0.25, 1.1)) + D.smooth(D.span(t, 2.86, 2.98)))
	d.set_post(&"vignette", 0.75)
	d.set_post(&"grain", 0.07)
	d.set_post(&"tint", Vector3(0.95, 1.0, 1.08))
	# Yazı: yavaş belirir, hafifçe yaklaşır
	var a: float = D.smooth(D.span(t, 0.9, 1.6)) * (1.0 - D.smooth(D.span(t, 2.6, 2.9)))
	t_title_story.modulate.a = a
	t_title_story.scale = Vector2.ONE * lerpf(0.96, 1.02, D.span(t, 0.9, 2.9))
	t_bul.modulate.a = 0.0
	t_tamir.modulate.a = 0.0


func _tick_repair(t: float) -> void:
	dust.visible = false
	platform.visible = true
	t_title_story.modulate.a = 0.0
	env.fog_enabled = false
	env.ambient_light_energy = 0.35
	env.background_color = Color(0.012, 0.016, 0.03)
	rim_light.light_energy = 0.9
	bulb.light_energy = 0.0
	(work_lights[0] as Light3D).light_energy = 3.2
	(work_lights[1] as Light3D).light_energy = 1.6
	(work_lights[2] as Light3D).light_energy = 1.2
	platform_ring.albedo_color = D.BRAND_BLUE * 2.6
	car.position = Vector3.ZERO
	car.rotation = Vector3.ZERO
	_apply_headlights(_headlight_level(t), 0.0)
	gate.visible = false
	glint.light_energy = 0.0
	_reset_parts()
	var shot: int = 0
	for i: int in CUTS.size():
		if t >= CUTS[i]:
			shot = i
	var s0: float = CUTS[shot]
	var s1: float = CUTS[shot + 1] if shot + 1 < CUTS.size() else 7.0
	var k: float = D.span(t, s0, s1)
	# Her kesmede flaş + renk sapması darbesi
	d.set_post(&"white", D.pulse(t, s0, 0.12) * (0.85 if shot == 0 else 0.45))
	d.set_post(&"aberration", 2.0 + D.pulse(t, s0, 0.2) * 9.0)
	d.set_post(&"vignette", 0.5)
	match shot:
		0:
			_shot_disassemble(t, k)
		1:
			_shot_wheel(t, k)
		2:
			_shot_grind(t, k)
		3:
			_shot_assemble(t, k)
		4:
			_shot_scan(t, k)
		5:
			_shot_hero(t, k)
	# Yazılar: BUL. (3,05) ve TAMİR ET. (3,55) darbeyle gelir, 6,85'te söner
	_punch(t_bul, t, 3.02, 6.85)
	_punch(t_tamir, t, 3.553, 6.85)


func _punch(label: Label, t: float, at: float, out_at: float) -> void:
	if t < at:
		label.modulate.a = 0.0
		return
	var k: float = D.span(t, at, at + 0.16)
	label.modulate.a = D.ease_out(k, 2.0) * (1.0 - D.span(t, out_at, out_at + 0.12))
	var s: float = lerpf(1.7, 1.0, D.ease_out(k, 4.0)) + D.pulse(t, at + 0.16, 0.12) * 0.06
	label.scale = Vector2.ONE * s
	label.rotation = deg_to_rad(lerpf(-6.0, 0.0, D.ease_out(k, 3.0)))


func _reset_parts() -> void:
	for i: int in parts.size():
		parts[i].global_transform = part_base[i]


func _explode(amount: float) -> void:
	for i: int in parts.size():
		var base: Transform3D = part_base[i]
		var c: Vector3 = (base * parts[i].get_aabb()).get_center()
		var rot: Basis = Basis.from_euler(part_spin[i] * amount)
		var moved: Transform3D = Transform3D(rot, Vector3.ZERO) * Transform3D(base.basis, base.origin - c)
		moved.origin += c + part_dir[i] * amount
		parts[i].global_transform = moved


func _burst(p: CPUParticles3D, at: Vector3, dir: Vector3, t: float, when: float) -> void:
	if _crossed(when, t):
		p.global_position = at
		p.direction = dir
		p.one_shot = false
		p.explosiveness = 0.0
		p.restart()
		p.emitting = true


## B1 3,00–3,53 — SÖKME: üç çeyrek yüksek açı, parçalar ağır çekimde dağılır, kıvılcım.
func _shot_disassemble(t: float, k: float) -> void:
	_set_rust(&"amount", 0.95)
	_set_rust(&"wipe_z", 100.0)
	_set_rust(&"wipe_dir", 1.0)
	_set_rust(&"clean_radius", 0.0)
	_explode(D.ease_out(k, 2.5) * 0.85)
	var ang: float = deg_to_rad(lerpf(35.0, 55.0, k))
	var pos: Vector3 = center + Vector3(sin(ang) * 1.9, 1.05, cos(ang) * 1.9)
	D.look_cam(cam, pos + D.shake(t, 0.01, 2.0), center + Vector3(0.0, 0.05, 0.0))
	cam.fov = 50.0
	_burst(sparks_a, center + Vector3(0.0, box.size.y * 0.5, 0.0), Vector3.UP, t, CUTS[0] + 0.02)
	if t > CUTS[0] + 0.4:
		sparks_a.emitting = false


## B2 3,53–4,07 — TEKER: paslı teker fırlar, yenisi dönerek oturur.
func _shot_wheel(t: float, k: float) -> void:
	_set_rust(&"amount", 0.95)
	var cam_pos: Vector3 = wheel_center + Vector3(0.55, 0.05, 0.42)
	D.look_cam(cam, cam_pos.lerp(wheel_center + Vector3(0.48, 0.04, 0.3), k) + D.shake(t, 0.004, 2.0),
		wheel_center + Vector3(0.0, 0.01, -0.02))
	cam.fov = 42.0
	# Yeni teker yarım vuruşta (k = 0,5) oturur
	var out_k: float = D.ease_in(D.span(k, 0.0, 0.2), 2.0)
	var in_k: float = D.ease_out(D.span(k, 0.26, 0.5), 3.0)
	var offset: float
	var spin: float
	var clean: bool = k >= 0.23
	if not clean:
		offset = out_k * 0.9
		spin = -out_k * 6.0
	else:
		offset = (1.0 - in_k) * 0.9
		spin = (1.0 - in_k) * 14.0
	for mi: MeshInstance3D in wheel_fl:
		var base: Transform3D = part_base[parts.find(mi)]
		var rot: Basis = Basis(Vector3.RIGHT, spin)
		var moved: Transform3D = Transform3D(rot, Vector3.ZERO) * Transform3D(base.basis, base.origin - wheel_center)
		moved.origin += wheel_center + Vector3(offset, 0.0, 0.0)
		mi.global_transform = moved
		mi.material_overlay = null if clean else rust_mats[1]
	_burst(sparks_b, wheel_center + Vector3(0.06, 0.0, 0.0), Vector3(1.0, 0.6, 0.0), t, CUTS[1] + 0.5 * (CUTS[2] - CUTS[1]))
	d.set_post(&"white", maxf(D.pulse(t, CUTS[1], 0.12) * 0.45, D.pulse(t, CUTS[1] + 0.5 * (CUTS[2] - CUTS[1]), 0.1) * 0.5))


## B3 4,07–4,60 — TAŞLAMA: kapıda pas kor halkayla silinir, kıvılcım yağar.
func _shot_grind(t: float, k: float) -> void:
	for mi: MeshInstance3D in wheel_fl:
		mi.material_overlay = rust_mats[1]
	_set_rust(&"amount", 0.95)
	var at: Vector3 = Vector3(box.end.x - 0.01, center.y + 0.02, center.z + 0.05)
	_set_rust(&"clean_center", at)
	_set_rust(&"clean_radius", D.ease_out(k, 1.6) * 0.28)
	var pos: Vector3 = at + Vector3(0.55, 0.16, 0.35).lerp(Vector3(0.45, 0.1, 0.18), k)
	D.look_cam(cam, pos + D.shake(t, 0.012, 3.0), at + Vector3(0.0, -0.01, 0.0), 6.0)
	cam.fov = 44.0
	if _crossed(CUTS[2], t):
		sparks_a.amount = 200
		sparks_a.global_position = at + Vector3(0.02, 0.0, 0.0)
		sparks_a.direction = Vector3(0.6, 0.5, 0.6)
		sparks_a.restart()
		sparks_a.emitting = true


## B4 4,60–5,13 — TOPLAMA: parçalar yukarıdan çarparak yerine oturur.
func _shot_assemble(t: float, k: float) -> void:
	sparks_a.emitting = false
	_set_rust(&"clean_radius", 0.0)
	_set_rust(&"amount", 0.8)
	var land: float = 0.5   # yarım vuruş
	_explode(1.0 - D.ease_in(D.span(k, 0.0, land), 2.4))
	var ang: float = deg_to_rad(lerpf(-40.0, -20.0, k))
	var impact: float = CUTS[3] + land * (CUTS[4] - CUTS[3])
	var pos: Vector3 = center + Vector3(sin(ang) * 1.5, 1.5, cos(ang) * 1.5)
	D.look_cam(cam, pos + D.shake(t, 0.03 * D.pulse(t, impact, 0.25), 3.0), center)
	cam.fov = 48.0
	_burst(sparks_b, Vector3(center.x, 0.02, center.z), Vector3.UP, t, impact)
	d.set_post(&"white", maxf(D.pulse(t, CUTS[3], 0.1) * 0.4, D.pulse(t, impact, 0.14) * 0.7))
	if t >= impact and not _repainted:
		_repaint()


## Boyayı parlatır (renk fabrika rengi kalır; toplama darbesinde, pasın altında).
func _repaint() -> void:
	_repainted = true
	for role: StringName in [&"body", &"mirrors"]:
		for mi: MeshInstance3D in rig.get_meshes(role):
			var m: Material = mi.get_surface_override_material(0)
			if m is ShaderMaterial:
				(m as ShaderMaterial).set_shader_parameter(&"roughness", 0.22)
				(m as ShaderMaterial).set_shader_parameter(&"metallic", 0.3)


## B5 5,13–6,00 — TARAMA: ışıklı kapı arkadan öne geçer, arkasında pas yok; kamera hızla döner.
func _shot_scan(t: float, k: float) -> void:
	_set_rust(&"amount", 0.9)
	var z0: float = box.position.z - 0.08
	var z1: float = box.end.z + 0.08
	var wipe: float = lerpf(z0, z1, D.smooth(D.span(k, 0.08, 0.92)))
	_set_rust(&"wipe_z", wipe)
	_set_rust(&"wipe_dir", -1.0)   # kapı arkadan öne gider: geride kalan (z < kapı) temiz
	gate.visible = true
	gate.position = Vector3(center.x, 0.0, wipe)
	gate_mat.albedo_color = Color(0.45, 0.75, 1.0) * (3.0 + sin(t * 40.0) * 0.6)
	for s: CPUParticles3D in sparks_scan:
		s.emitting = k > 0.05 and k < 0.95
	var ang: float = deg_to_rad(lerpf(110.0, 20.0, D.smooth(k)))
	var r: float = lerpf(1.7, 1.5, k)
	var pos: Vector3 = center + Vector3(sin(ang) * r, lerpf(0.45, 0.3, k), cos(ang) * r)
	D.look_cam(cam, pos, center + Vector3(0.0, -0.03, 0.0))
	cam.fov = 50.0
	d.set_post(&"aberration", 3.0 + D.pulse(t, CUTS[4], 0.2) * 9.0)


## B6 6,00–7,00 — KAHRAMAN: temiz Integrale (fabrika rengi), farlar yanık, alçak ön çeyrek, parıltı süpürmesi.
func _shot_hero(t: float, k: float) -> void:
	if not _repainted:
		_repaint()
	_set_rust(&"amount", 0.0)
	for s: CPUParticles3D in sparks_scan:
		s.emitting = false
	_apply_headlights(1.0, 0.25)
	var ang: float = deg_to_rad(lerpf(28.0, 38.0, k))
	var r: float = lerpf(1.6, 1.3, D.smooth(k))
	var pos: Vector3 = center + Vector3(sin(ang) * r, lerpf(0.12, 0.16, k), cos(ang) * r)
	D.look_cam(cam, pos, center + Vector3(0.0, 0.0, 0.05), -3.0)
	cam.fov = 46.0
	glint.light_energy = 2.5 * sin(PI * D.span(k, 0.15, 0.85))
	glint.global_position = Vector3(box.end.x + 0.15, box.end.y * 0.8, lerpf(box.position.z, box.end.z, D.span(k, 0.15, 0.85)))
	d.set_post(&"vignette", 0.55)
