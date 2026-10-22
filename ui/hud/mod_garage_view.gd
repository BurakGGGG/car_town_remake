class_name ModGarageView
extends Node
## MODİFİYE GARAJI (kullanıcı isteği 2026-10-22: "depolar gibi bir modifiye garajı, aşırı lüks"; taslak A SİYAH & ALTIN)
## — ARAÇLAR → MODİFİYE açılınca araç eski kutu odadan / depodaki park yerinden bu odaya, ortadaki döner tablaya geçer.
## Oda Blender'da kurulup ışığı pişirilmiş sahne (tools/garages/modgarage.py, GarageInterior &"modgarage").
##
## KAMERA kategoriye göre parçaya süzülür (ModWorkshop.focus_changed → focus): MOTOR kaput, TURBO egzoz, HAVA AKIŞI ön
## tampon, ŞANZIMAN yan, LASTİK & JANT ön teker, GÖVDE tam profil. Kamera hep odanın güneydoğu yarısında kalır; parçayı
## kameraya TABLA çevirir (her çekim: aracın kameraya bakan yerel açısı `face`). Genel bakışta tabla yavaşça döner,
## parmakla çevrilebilir. Kamera varınca kısa bir gösteri: ışık süpürmesi + gaz sesi / alev / teker dönüşü / hava çizgileri.
##
## YANSIMA: tablanın üstü (TableTop) yarı saydam parlak siyah; altında aracın tablaya göre aynalanmış kopyası durur
## (zeminde tablanın altı delik). Aynalı kopya ayrı ışık katmanında (MIRROR_LAYER) aynalı anahtar ışıkla aydınlanır, iki
## koyu disk derinlere indikçe karartır. Tek araç olduğu için telefonda ucuz.
##
## GarageInteriorView gibi: girişte ödünç aldığı düğümlerin (kamera, anahtar ışık, gizlenen oda) ayarlarını saklar, exit()
## geri koyar. Depo iç mekânı açıksa GarageScreen onu askıya alır (GarageInteriorView.suspend).

const GARAGE: StringName = &"modgarage"
## Aynalı araç bu görsel katmanda: yalnız aynalı anahtar ışık onu aydınlatır.
const MIRROR_LAYER: int = 1 << 9
## Kameranın odadaki yönü (dünya açısı, derece): odanın güneydoğusu, kuzey / batı duvarlarına bakar.
const HOME_AZIMUTH: float = 40.0
## Çekimler. face: aracın kameraya bakan yerel açısı (0 = burun, 90 = yan, 180 = arka); az: kameranın HOME_AZIMUTH'tan
## sapması; el: yükseklik açısı; dist: uzaklık (araç boyu katı); fov: dikey görüş; at: hedef (aracın sınır kutusunda
## oran: x yan, y yükseklik, z boy; 0,5 = orta); spin: varınca tabla dönüşü (derece/sn).
const SHOTS: Dictionary = {
	&"": {"face": 30.0, "az": 0.0, "el": 12.0, "dist": 1.9, "fov": 44.0, "at": Vector3(0.5, 0.5, 0.5), "spin": 9.0},
	&"motor": {"face": 18.0, "az": -10.0, "el": 30.0, "dist": 1.9, "fov": 36.0, "at": Vector3(0.5, 0.82, 0.8)},
	&"turbo": {"face": 158.0, "az": 8.0, "el": 11.0, "dist": 1.7, "fov": 36.0, "at": Vector3(0.5, 0.3, 0.02)},
	&"air": {"face": -14.0, "az": 0.0, "el": 7.0, "dist": 1.7, "fov": 38.0, "at": Vector3(0.5, 0.32, 0.98)},
	&"gear": {"face": 96.0, "az": 0.0, "el": 8.0, "dist": 2.6, "fov": 38.0, "at": Vector3(0.5, 0.32, 0.5)},
	&"tire": {"face": 64.0, "az": 10.0, "el": 5.0, "dist": 1.2, "fov": 36.0, "at": Vector3(0.5, 0.3, 0.8)},
	&"body": {"face": 90.0, "az": 0.0, "el": 10.0, "dist": 2.8, "fov": 40.0, "at": Vector3(0.5, 0.48, 0.5), "spin": 14.0},
}
## Hedefin ekrandaki yeri (NDC, + sağ / yukarı): plakaların arasında kalan görünür pencerenin ortası. Genel bakışta solda
## değerler, sağda öneri, altta kategori rafı; kategori ekranında solda geniş dinamometre, sağda parça plakası, altta
## kademe rafı (pencere ~ yatayda %40–73, dikeyde %10–55).
const FRAME_OVERVIEW: Vector2 = Vector2(0.0, 0.26)
const FRAME_CATEGORY: Vector2 = Vector2(0.13, 0.3)
## Kamera tablanın merkezinden yatayda en çok bu kadar uzaklaşır (Blender metresi): ötesinde duvar dibi eşyaları var
## (güneydoğuda fanuslar ve saksılar ~8,5 m, doğuda salon ~8,8 m).
const SAFE_RADIUS: float = 7.0
## Kamera duvara takılınca görüş açısı en çok buna genişler (derece).
const MAX_FOV: float = 70.0
const MOVE_TIME: float = 1.15
## Gösteri kamera yolun bu kadarını alınca başlar.
const SHOW_AT: float = 0.72
const DRAG_YAW: float = 0.35        # parmakla çevirme (derece / piksel)
const DRAG_RESUME: float = 2.5      # bırakınca kendiliğinden dönmeye bu kadar sonra devam (sn)

var active: bool = false
var interior: GarageInterior
var vehicle_id: StringName = &""
var category: StringName = &""

var _root: Node
var _camera: Camera3D
var _key: DirectionalLight3D
var _hidden: Array[Node3D] = []
var _saved: Dictionary = {}
var _stage: Node3D                  # odanın dışındaki her şey (aynalı ışık, efektler) buraya
var _pivot: Node3D                  # döner tabla: araç bunun çocuğu
var _car: Node3D
var _rig: CarRig
var _mirror: Node3D
var _mirror_rig: CarRig
var _mirror_key: DirectionalLight3D
var _bounds: AABB = AABB(Vector3(-0.25, 0.0, -0.5), Vector3(0.5, 0.35, 1.0))
var _wheels_local: Array[Vector3] = []   # ön tekerler, aracın yerel uzayında
var _exhaust_local: Vector3 = Vector3.ZERO
var _has_exhaust: bool = false
var _plane_y: float = 0.0           # tabla üstünün dünya yüksekliği
var _room: AABB
var _fx: DragFx
var _sweep: OmniLight3D
var _lights: Array[Light3D] = []
var _streaks: Array[MeshInstance3D] = []
var _engine: AudioStreamPlayer
var _pop: AudioStreamPlayer
var _whoosh: AudioStreamPlayer
var _engine_pitch: float = 1.0
var _engine_db: float = 0.0
var _engine_tween: Tween
# tabla
var _base_yaw: float = 0.0          # Car işaretçisinin açısı (derece)
var _yaw: float = 0.0
var _yaw_from: float = 0.0
var _yaw_to: float = 0.0
var _spin: float = 0.0
var _drag_hold: float = 0.0
# kamera
var _from: Dictionary = {}
var _to: Dictionary = {}
var _cam: Dictionary = {}
var _t: float = 1.0
var _show_pending: bool = false
var _generation: int = 0
var _wheel_speed: float = 0.0
# girdi
var _dragging: bool = false
var _last_pos: Vector2


func _ready() -> void:
	set_process(false)


## Kipi açar: oda `root`a kurulur, `vehicle` döner tablaya konur, `hide` düğümleri (eski oda) gizlenir. Sahne yoksa false.
func enter(vehicle: StringName, root: Node, camera: Camera3D, key_light: DirectionalLight3D, hide: Array[Node3D]) -> bool:
	exit()
	var created: GarageInterior = GarageInterior.create(GARAGE)
	if created == null:
		return false
	interior = created
	vehicle_id = vehicle
	_root = root
	_camera = camera
	_key = key_light
	_saved = {
		"projection": camera.projection, "size": camera.size, "fov": camera.fov, "keep_aspect": camera.keep_aspect,
		"transform": camera.transform, "environment": camera.environment, "near": camera.near, "far": camera.far,
		"v_offset": camera.v_offset, "h_offset": camera.h_offset,
		"key_transform": key_light.transform if key_light else Transform3D(), "key_color": key_light.light_color if key_light else Color.WHITE,
		"key_energy": key_light.light_energy if key_light else 1.0, "key_shadow": key_light.shadow_enabled if key_light else false,
		"key_mask": key_light.light_cull_mask if key_light else 0xFFFFFFFF,
	}
	_hidden.clear()
	for node: Node3D in hide:
		if node and node.visible:
			node.visible = false
			_hidden.append(node)
	root.add_child(interior)
	_stage = Node3D.new()
	_stage.name = "ModStage"
	root.add_child(_stage)
	_configure()
	if not _spawn_car():
		exit()
		return false
	_build_effects()
	active = true
	category = &"__"   # ilk focus her zaman uygulanır
	set_process(true)
	focus(&"", false)
	return true


func exit() -> void:
	if not active and interior == null:
		return
	active = false
	set_process(false)
	_generation += 1
	_dragging = false
	_wheel_speed = 0.0
	_car = null
	_rig = null
	_mirror = null
	_mirror_rig = null
	_fx = null
	_sweep = null
	_pivot = null
	_mirror_key = null
	_engine = null
	_engine_tween = null
	_pop = null
	_whoosh = null
	_lights.clear()
	_streaks.clear()
	for node: Node in [_stage, interior]:
		if is_instance_valid(node):
			if node.get_parent():
				node.get_parent().remove_child(node)
			node.queue_free()
	_stage = null
	interior = null
	for node: Node3D in _hidden:
		if is_instance_valid(node):
			node.visible = true
	_hidden.clear()
	if is_instance_valid(_camera) and not _saved.is_empty():
		for key: String in ["projection", "size", "fov", "keep_aspect", "transform", "environment", "near", "far", "v_offset",
				"h_offset"]:
			_camera.set(key, _saved[key])
	if is_instance_valid(_key) and not _saved.is_empty():
		_key.transform = _saved["key_transform"]
		_key.light_color = _saved["key_color"]
		_key.light_energy = _saved["key_energy"]
		_key.shadow_enabled = _saved["key_shadow"]
		_key.light_cull_mask = _saved["key_mask"]
	_saved.clear()


## Kategoriye göre çekim (&"" = genel bakış). `animated` false: kamera ve tabla oraya hemen konur.
func focus(next: StringName, animated: bool = true) -> void:
	if not active:
		return
	if not SHOTS.has(next):
		next = &""
	if next == category:
		return
	category = next
	_generation += 1
	var shot: Dictionary = SHOTS[next]
	_spin = 0.0
	_yaw_from = _yaw
	# tabla, çekimin istediği yüzü kameraya çevirir: en kısa yoldan, genel bakışta bulunduğu yerden
	var goal: float = HOME_AZIMUTH + float(shot["az"]) - float(shot["face"]) - _base_yaw
	_yaw_to = _yaw + wrapf(goal - _yaw, -180.0, 180.0)
	if next == &"":
		_yaw_to = _yaw   # genel bakış: tabla olduğu yerden dönmeyi sürdürür
	_to = _shot_params(next)
	_from = _cam.duplicate() if not _cam.is_empty() else _to.duplicate()
	_t = 0.0 if animated else 1.0
	_show_pending = animated and next != &""
	_streaks_visible(false)
	if animated:
		_play_whoosh(next)
	if not animated:
		_yaw = _yaw_to
		_cam = _to.duplicate()
		_spin = float(shot.get("spin", 0.0))
		_apply()


## Genel bakışta parmakla / fareyle tablayı çevirir. Olayı kullandıysa true.
func handle_input(event: InputEvent) -> bool:
	if not active or category != &"":
		return false
	var pressed: bool = false
	var released: bool = false
	var motion: Vector2 = Vector2.ZERO
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		pressed = touch.pressed and touch.index == 0
		released = not touch.pressed and touch.index == 0
		_last_pos = touch.position
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		if drag.index == 0:
			motion = drag.relative
	elif event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.button_index == MOUSE_BUTTON_LEFT:
			pressed = button.pressed
			released = not button.pressed
	elif event is InputEventMouseMotion and _dragging:
		motion = (event as InputEventMouseMotion).relative
	if pressed:
		_dragging = true
		return true
	if released:
		_dragging = false
		_drag_hold = DRAG_RESUME
		return true
	if _dragging and motion != Vector2.ZERO:
		_yaw += motion.x * DRAG_YAW
		_yaw_to = _yaw
		_drag_hold = DRAG_RESUME
		return true
	return false


func _process(delta: float) -> void:
	var shot: Dictionary = SHOTS[category]
	if _t < 1.0:
		_t = minf(_t + delta / MOVE_TIME, 1.0)
		var k: float = _ease(_t)
		_yaw = lerpf(_yaw_from, _yaw_to, k)
		_cam = _lerp_params(_from, _to, k)
		if _show_pending and _t >= SHOW_AT:
			_show_pending = false
			_show(category, _generation)
		if _t >= 1.0:
			_spin = float(shot.get("spin", 0.0))
	elif not _dragging:
		_drag_hold = maxf(_drag_hold - delta, 0.0)
		if _drag_hold <= 0.0:
			_yaw += _spin * delta
			_yaw_to = _yaw
	if _wheel_speed != 0.0:
		for rig: CarRig in [_rig, _mirror_rig]:
			if rig:
				rig.spin_wheels(_wheel_speed * delta)
	_apply()


# --- Kurulum ------------------------------------------------------------------------------------------

func _configure() -> void:
	var setup: Dictionary = interior.setup()
	var b: Rect2 = setup["bounds"]
	var a: Vector3 = interior.blender_point(Vector3(b.position.x, b.position.y, 0.25))
	var c: Vector3 = interior.blender_point(Vector3(b.end.x, b.end.y, float(setup.get("height", 4.6))))
	_room = AABB(a.min(c), (c - a).abs())
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.near = 0.02
	_camera.far = 60.0
	_camera.h_offset = 0.0
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = setup["background"]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = setup["ambient"]
	env.ambient_light_energy = float(setup["ambient_energy"])
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR   # oda pişmiş ekran değeri: ikinci kez bükülmesin
	_camera.environment = env
	var key_dir: Vector3 = GarageInterior.blender_dir(setup["key_dir"])
	if _key:
		_key.global_basis = Basis.looking_at(key_dir, Vector3.UP)
		_key.light_color = setup["key_color"]
		_key.light_energy = float(setup["key_energy"])
		_key.shadow_enabled = false
		_key.light_cull_mask = 0xFFFFFFFF & ~MIRROR_LAYER
	# aynalı anahtar ışık: yön dikeyde ters (aynadaki araç aşağıdan değil yukarıdan aydınlanmış görünsün)
	_mirror_key = DirectionalLight3D.new()
	_mirror_key.name = "MirrorKey"
	_mirror_key.light_color = setup["key_color"]
	_mirror_key.light_energy = float(setup["key_energy"]) * 0.8
	_mirror_key.light_cull_mask = MIRROR_LAYER
	_stage.add_child(_mirror_key)
	_mirror_key.global_basis = Basis.looking_at(Vector3(key_dir.x, -key_dir.y, key_dir.z), Vector3.UP)
	# boyaya altın parıltı: tavandaki halka ışığın iki yanından sıcak nokta ışıklar (aynalı kopyaya değmez)
	var center: Vector3 = interior.marker("Car").origin
	for offset: Vector3 in [Vector3(-0.55, 0.9, 0.35), Vector3(0.6, 0.85, -0.4), Vector3(0.2, 0.7, 0.75)]:
		var light: OmniLight3D = OmniLight3D.new()
		light.light_color = Color(1.0, 0.82, 0.58)
		light.light_energy = 0.9
		light.omni_range = 1.8
		light.light_cull_mask = 0xFFFFFFFF & ~MIRROR_LAYER
		_stage.add_child(light)
		light.global_position = center + offset
		_lights.append(light)


func _spawn_car() -> bool:
	var scene_path: String = CarCatalog.scene_path(vehicle_id)
	var scene: PackedScene = load(scene_path) as PackedScene if scene_path != "" else null
	if scene == null:
		return false
	var at: Transform3D = interior.marker("Car")
	_plane_y = at.origin.y
	_base_yaw = rad_to_deg(atan2(at.basis.z.x, at.basis.z.z))
	_yaw = 0.0
	_pivot = Node3D.new()
	_pivot.name = "Turntable"
	_stage.add_child(_pivot)
	_pivot.global_position = at.origin
	_car = scene.instantiate() as Node3D
	_car.name = String(vehicle_id)
	_pivot.add_child(_car)
	_car.scale = Vector3.ONE * CarCatalog.model_scale(vehicle_id)
	_rig = CarRig.for_node(_car)
	_rig.apply(CarAppearance.get_for(scene_path))
	_rig.set_lod_bias(CarRig.LOD_BIAS_GARAGE)
	_rig.optimize(false)   # tekerler ayrı: LASTİK & JANT gösterisinde döner
	_no_shadows(_car)
	_apply()   # sınırlar dünya dönüşümüyle ölçülür
	_bounds = _local_bounds(_car)
	_measure_parts()
	_car.add_child(_contact_shadow())
	_mirror = scene.instantiate() as Node3D
	_mirror.name = "Mirror"
	_stage.add_child(_mirror)
	_mirror_rig = CarRig.for_node(_mirror)
	_mirror_rig.apply(CarAppearance.get_for(scene_path))
	_mirror_rig.set_lod_bias(CarRig.LOD_BIAS_WORLD)
	_mirror_rig.optimize(false)
	_no_shadows(_mirror)
	for node: Node in _mirror.find_children("*", "VisualInstance3D", true, false):
		(node as VisualInstance3D).layers = MIRROR_LAYER
	_dress_table()
	return true


## TableTop yarı saydam parlak siyah (altındaki aynalı araç = yansıma), altında derinleştikçe karartan iki disk.
func _dress_table() -> void:
	var top: MeshInstance3D = interior.part("TableTop") as MeshInstance3D
	if top == null:
		return
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = _table_shader()
	material.render_priority = 1
	for s: int in top.mesh.get_surface_count():
		top.set_surface_override_material(s, material)
	var radius: float = top.get_aabb().size.x * 0.5 * interior.scale.x * 0.995
	for i: int in 2:
		var disc: MeshInstance3D = MeshInstance3D.new()
		var mesh: CylinderMesh = CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		mesh.height = 0.002
		mesh.radial_segments = 48
		mesh.rings = 1
		disc.mesh = mesh
		var dark: StandardMaterial3D = StandardMaterial3D.new()
		dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dark.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		dark.albedo_color = Color(0.0, 0.0, 0.0, 0.22 + 0.22 * i)
		disc.material_override = dark
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_stage.add_child(disc)
		disc.global_position = Vector3(_pivot.global_position.x, _plane_y - _car_height() * (0.18 + 0.32 * i),
			_pivot.global_position.z)


static var _table_shader_cache: Shader


static func _table_shader() -> Shader:
	if _table_shader_cache == null:
		_table_shader_cache = Shader.new()
		_table_shader_cache.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
// Döner tablanın üstü: pişmiş köşe rengi (siyah disk + altın halka) + kenarda sıcak parıltı. Disk yarı saydam: altındaki
// aynalı araç yansıma olarak görünür; altın halka opak.
uniform float base_alpha = 0.55;
void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float lum = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	ALBEDO = COLOR.rgb + vec3(0.32, 0.24, 0.12) * fres;
	ALPHA = clamp(max(base_alpha + fres * 0.22, smoothstep(0.06, 0.16, lum)), 0.0, 1.0);
}
"""
	return _table_shader_cache


func _build_effects() -> void:
	var length: float = _car_length()
	_fx = DragFx.new(length)
	_pivot.add_child(_fx)
	# DragFx alevi kendi yerelinde (0, 0,12k, -0,6k); egzozun tabla uzayındaki yerine kaydırılır
	var exhaust: Vector3 = _pivot.to_local(_car.to_global(_exhaust_local))
	_fx.position = exhaust - Vector3(0.0, 0.12 * length, -0.6 * length)
	_sweep = OmniLight3D.new()
	_sweep.name = "Sweep"
	_sweep.light_color = Color(1.0, 0.93, 0.8)
	_sweep.light_energy = 0.0
	_sweep.omni_range = length * 0.45
	_sweep.light_cull_mask = 0xFFFFFFFF & ~MIRROR_LAYER
	_pivot.add_child(_sweep)
	var streak_material: StandardMaterial3D = StandardMaterial3D.new()
	streak_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	streak_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	streak_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	streak_material.albedo_color = Color(0.75, 0.88, 1.0, 0.0)
	for i: int in 7:
		var streak: MeshInstance3D = MeshInstance3D.new()
		var mesh: CylinderMesh = CylinderMesh.new()
		mesh.top_radius = length * 0.0035
		mesh.bottom_radius = length * 0.0035
		mesh.height = length * (0.22 + 0.05 * (i % 3))
		mesh.radial_segments = 4
		mesh.rings = 1
		streak.mesh = mesh
		streak.material_override = streak_material.duplicate()
		streak.rotation_degrees = Vector3(90.0, 0.0, 0.0)   # boyuna (Z) uzanır
		streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		streak.visible = false
		_car.add_child(streak)
		_streaks.append(streak)
	_engine = _player()
	var engine: Array = RaceAudio.engine_for(PerformanceMods.performance_ratio(vehicle_id), DragRaceSim.is_electric(vehicle_id))
	_engine.stream = engine[0]
	_engine_pitch = engine[1]
	_engine_db = engine[2]
	_pop = _player()
	_pop.stream = RaceAudio.pop_stream()
	_whoosh = _player()
	_whoosh.stream = _whoosh_stream()


func _player() -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = GameSettings.SFX_BUS
	_stage.add_child(player)
	return player


## Ön tekerler ve egzoz, aracın yerel uzayında (kamera ve efektler buna göre).
func _measure_parts() -> void:
	_wheels_local.clear()
	var inverse: Transform3D = _car.global_transform.affine_inverse()
	for wheel: Dictionary in _rig.wheel_points():
		if wheel["front"]:
			_wheels_local.append(inverse * (wheel["position"] as Vector3))
	var merged: AABB = AABB()
	_has_exhaust = false
	for mesh: MeshInstance3D in _rig.get_meshes(&"exhaust"):
		var box: AABB = inverse * (mesh.global_transform * mesh.get_aabb())
		merged = box if not _has_exhaust else merged.merge(box)
		_has_exhaust = true
	var b: AABB = _bounds
	_exhaust_local = merged.get_center() if _has_exhaust else Vector3(b.get_center().x, b.position.y + b.size.y * 0.25,
		b.position.z + b.size.z * 0.03)


# --- Kamera ------------------------------------------------------------------------------------------

## Çekimin kamera değerleri: hedef aracın yerel uzayında (tabla dönerken araçla birlikte döner), açılar dünyada.
func _shot_params(which: StringName) -> Dictionary:
	var shot: Dictionary = SHOTS[which]
	var at: Vector3 = shot["at"]
	var b: AABB = _bounds
	var local: Vector3 = b.position + b.size * at
	if which == &"tire" and not _wheels_local.is_empty():
		var side: float = signf(sin(deg_to_rad(float(shot["face"]))))
		var best: Vector3 = _wheels_local[0]
		for wheel: Vector3 in _wheels_local:
			if signf(wheel.x - b.get_center().x) == side:
				best = wheel
		local = best
	elif which == &"turbo":
		local = _exhaust_local + Vector3(0.0, b.size.y * 0.04, 0.0)
	return {"az": HOME_AZIMUTH + float(shot["az"]), "el": float(shot["el"]), "dist": float(shot["dist"]) * _car_length(),
		"frame": FRAME_OVERVIEW if which == &"" else FRAME_CATEGORY,
		"fov": float(shot["fov"]), "at": local}


func _lerp_params(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var arc: float = sin(k * PI) * 5.0   # yükseklik yolun ortasında kabarır: kamera düz çizgi yerine yay çizer
	return {"az": lerpf(a["az"], b["az"], k), "el": lerpf(a["el"], b["el"], k) + arc,
		"dist": lerpf(a["dist"], b["dist"], k), "fov": lerpf(a["fov"], b["fov"], k),
		"frame": (a["frame"] as Vector2).lerp(b["frame"], k),
		"at": (a["at"] as Vector3).lerp(b["at"], k)}


func _apply() -> void:
	if not is_instance_valid(_pivot):
		return
	_pivot.rotation_degrees = Vector3(0.0, _base_yaw + _yaw, 0.0)
	if is_instance_valid(_mirror) and is_instance_valid(_car):
		# tablanın üstündeki düzleme göre ayna: y → 2·düzlem − y
		var reflect: Transform3D = Transform3D(Basis.from_scale(Vector3(1.0, -1.0, 1.0)), Vector3(0.0, 2.0 * _plane_y, 0.0))
		_mirror.global_transform = reflect * _car.global_transform
	if _cam.is_empty() or not is_instance_valid(_camera) or not is_instance_valid(_car):
		return
	var target: Vector3 = _car.to_global(_cam["at"])
	var az: float = deg_to_rad(float(_cam["az"]))
	var el: float = deg_to_rad(float(_cam["el"]))
	var dir: Vector3 = Vector3(sin(az) * cos(el), sin(el), cos(az) * cos(el))
	var wanted: float = float(_cam["dist"])
	var dist: float = _inside(target, dir, wanted)   # odanın içinde kalsın (köşe kolonuna girmesin)
	var position: Vector3 = target + dir * dist
	# duvara takıldıysa açı genişler: parça ekranda aynı boyda kalır (yakından geniş açı)
	var fov: float = float(_cam["fov"])
	if dist < wanted:
		fov = minf(rad_to_deg(2.0 * atan(tan(deg_to_rad(fov * 0.5)) * wanted / dist)), MAX_FOV)
	_camera.fov = fov
	_camera.global_position = position
	_camera.look_at(target, Vector3.UP)
	# hedef görünür pencerenin ortasına: kamera kendi düzleminde kayar (bakış yönü aynı)
	var frame: Vector2 = _cam["frame"]
	var half_v: float = dist * tan(deg_to_rad(_camera.fov * 0.5))
	var aspect: float = _camera.get_viewport().get_visible_rect().size.aspect() if _camera.get_viewport() else 16.0 / 9.0
	_camera.v_offset = -frame.y * half_v
	_camera.h_offset = -frame.x * half_v * aspect   # kamera sola kayar: hedef ekranda sağa


## Hedeften `dir` yönünde en çok ne kadar gidilebilir: oda kutusunun ve tablanın çevresindeki eşyasız dairenin (SAFE_RADIUS,
## duvar dibindeki salon / fanus / saksılara girmesin) içinde kalarak.
func _inside(target: Vector3, dir: Vector3, dist: float) -> float:
	var limit: float = dist
	var flat: Vector2 = Vector2(dir.x, dir.z)
	var a: float = flat.length_squared()
	if a > 0.000001:
		var center: Vector3 = _pivot.global_position
		var from: Vector2 = Vector2(target.x - center.x, target.z - center.z)
		var radius: float = SAFE_RADIUS * GarageInterior.METER
		var b: float = 2.0 * from.dot(flat)
		var c: float = from.length_squared() - radius * radius
		var disc: float = b * b - 4.0 * a * c
		if disc >= 0.0:
			limit = minf(limit, (-b + sqrt(disc)) / (2.0 * a))
	for axis: int in 3:
		var d: float = dir[axis]
		if absf(d) < 0.00001:
			continue
		var bound: float = _room.end[axis] if d > 0.0 else _room.position[axis]
		var t: float = (bound - target[axis]) / d
		if t >= 0.0:
			limit = minf(limit, t)
	return maxf(limit, 0.05)


static func _ease(t: float) -> float:
	return t * t * (3.0 - 2.0 * t) if t < 1.0 else 1.0


# --- Gösteri ----------------------------------------------------------------------------------------

## Kamera parçaya varırken: ışık süpürmesi + kategorinin sesi / efekti. `generation` değiştiyse (başka kategori) iptal.
func _show(which: StringName, generation: int) -> void:
	var b: AABB = _bounds
	match which:
		&"motor":
			_sweep_over(Vector3(b.position.x - 0.1 * b.size.x, b.end.y, b.position.z + b.size.z * 0.82),
				Vector3(b.end.x + 0.1 * b.size.x, b.end.y, b.position.z + b.size.z * 0.6), generation)
			_rev(6800.0, 1.4, generation)
		&"turbo":
			_rev(7200.0, 1.0, generation)
			await _wait(0.42, generation)
			if not _alive(generation):
				return
			_fx.flame(1.0)
			_pop.volume_db = -5.0
			_pop.pitch_scale = 0.85
			_pop.play()
			_play_whoosh(&"turbo")   # blow-off: tiz tıslama
			await _wait(0.28, generation)
			if _alive(generation):
				_fx.flame(0.7)
				_pop.pitch_scale = 1.05
				_pop.play()
		&"air":
			_airflow(generation)
		&"gear":
			_rev(5200.0, 0.55, generation)
			await _wait(0.42, generation)
			if not _alive(generation):
				return
			_pop.volume_db = -11.0
			_pop.pitch_scale = 0.62
			_pop.play()
			_rev(6200.0, 0.7, generation)
			_sweep_over(Vector3(b.end.x + 0.05, b.position.y + b.size.y * 0.35, b.position.z),
				Vector3(b.end.x + 0.05, b.position.y + b.size.y * 0.35, b.end.z), generation)
		&"tire":
			_wheel_speed = 0.0
			var tween: Tween = _pivot.create_tween()   # tabla serbest kalınca (çıkış) durur
			tween.tween_property(self, "_wheel_speed", 1100.0, 0.5).set_ease(Tween.EASE_IN)
			tween.tween_property(self, "_wheel_speed", 0.0, 1.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			_fx.set_smoke(0.7)
			_rev(5800.0, 1.3, generation)
			await _wait(0.9, generation)
			if is_instance_valid(_fx):
				_fx.set_smoke(0.0)
		&"body":
			_sweep_over(Vector3(b.end.x + 0.05, b.end.y, b.position.z), Vector3(b.end.x + 0.05, b.end.y * 0.9, b.end.z), generation)
			_rev(4800.0, 1.0, generation)


func _alive(generation: int) -> bool:
	return active and generation == _generation


func _wait(seconds: float, generation: int) -> void:
	if not _alive(generation) or not is_inside_tree():
		return
	await get_tree().create_timer(seconds).timeout


## Işık süpürmesi: sıcak nokta ışık iki yerel nokta arasında kayar, parlayıp söner (boyada akan parıltı).
func _sweep_over(from_local: Vector3, to_local: Vector3, generation: int) -> void:
	if not is_instance_valid(_sweep):
		return
	var a: Vector3 = _pivot.to_local(_car.to_global(from_local))
	var b: Vector3 = _pivot.to_local(_car.to_global(to_local))
	var sweep: OmniLight3D = _sweep
	sweep.create_tween().tween_method(func(t: float) -> void:
		if is_instance_valid(sweep):
			sweep.position = a.lerp(b, t)
			sweep.light_energy = sin(t * PI) * 3.2, 0.0, 1.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Gaz: motor döngüsü devirle tizleşir, tepeye çıkıp rölantiye iner (drag yarışının motor tınısı).
func _rev(peak_rpm: float, seconds: float, generation: int) -> void:
	if _engine == null or _engine.stream == null or not _alive(generation):
		return
	var idle: float = clampf(900.0 / RaceAudio.BASE_RPM * _engine_pitch, 0.28, 4.0)
	var peak: float = clampf(peak_rpm / RaceAudio.BASE_RPM * _engine_pitch, 0.28, 4.0)
	if not _engine.playing:
		_engine.pitch_scale = idle
		_engine.volume_db = -30.0
		_engine.play()
	if _engine_tween:
		_engine_tween.kill()
	var engine: AudioStreamPlayer = _engine
	_engine_tween = engine.create_tween()
	_engine_tween.tween_property(engine, "pitch_scale", peak, seconds * 0.32).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_engine_tween.parallel().tween_property(engine, "volume_db", -9.0 + _engine_db, seconds * 0.2)
	_engine_tween.tween_property(engine, "pitch_scale", idle, seconds * 0.68).set_ease(Tween.EASE_IN_OUT)
	_engine_tween.parallel().tween_property(engine, "volume_db", -34.0, seconds * 0.68).set_ease(Tween.EASE_IN)
	_engine_tween.tween_callback(func() -> void:
		if is_instance_valid(engine):
			engine.stop())


## HAVA AKIŞI: ön tamponun önünden girişlere akan ince ışık çizgileri (üç dalga).
func _airflow(generation: int) -> void:
	var b: AABB = _bounds
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = 77
	for wave: int in 3:
		for i: int in _streaks.size():
			if not _alive(generation):
				return
			var streak: MeshInstance3D = _streaks[i]
			var x: float = lerpf(b.position.x + b.size.x * 0.15, b.end.x - b.size.x * 0.15, (float(i) + 0.5) / _streaks.size())
			var y: float = b.position.y + b.size.y * r.randf_range(0.18, 0.5)
			var start: Vector3 = Vector3(x, y, b.end.z + b.size.z * 0.55)
			var end: Vector3 = Vector3(x, y, b.end.z + b.size.z * 0.02)
			streak.position = start
			streak.visible = true
			var material: StandardMaterial3D = streak.material_override as StandardMaterial3D
			material.albedo_color.a = 0.0
			var tween: Tween = streak.create_tween().set_parallel(true)
			var delay: float = r.randf_range(0.0, 0.25)
			tween.tween_property(streak, "position", end, 0.55).set_delay(delay).set_ease(Tween.EASE_IN)
			tween.tween_property(material, "albedo_color:a", 0.85, 0.2).set_delay(delay)
			tween.chain().tween_property(material, "albedo_color:a", 0.0, 0.15)
		_play_whoosh(&"air")
		await _wait(0.6, generation)


func _streaks_visible(on: bool) -> void:
	for streak: MeshInstance3D in _streaks:
		if is_instance_valid(streak):
			streak.visible = on


func _play_whoosh(which: StringName) -> void:
	if _whoosh == null:
		return
	_whoosh.pitch_scale = 1.7 if which == &"turbo" else (1.25 if which == &"air" else 0.8)
	_whoosh.volume_db = -9.0 if which == &"turbo" else -19.0
	_whoosh.play()


static var _whoosh_cache: AudioStreamWAV


## Kısa hava sesi: süzülmüş gürültü, yumuşak giriş / sönüş (kamera geçişi, hava akışı; tiz çalınınca turbo tıslaması).
static func _whoosh_stream() -> AudioStreamWAV:
	if _whoosh_cache:
		return _whoosh_cache
	var rate: int = 22050
	var count: int = int(rate * 0.5)
	var data: PackedByteArray = PackedByteArray()
	data.resize(count * 2)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4242
	var low: float = 0.0
	var band: float = 0.0
	for i: int in count:
		var t: float = float(i) / count
		var envelope: float = smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(0.35, 1.0, t))
		var noise: float = rng.randf_range(-1.0, 1.0)
		low += (noise - low) * 0.18     # alçak geçiren
		band += (low - band) * 0.05     # en alçağı çıkar: bant
		var sample: float = clampf((low - band) * 2.2 * envelope, -1.0, 1.0)
		data.encode_s16(i * 2, int(sample * 32000.0))
	_whoosh_cache = AudioStreamWAV.new()
	_whoosh_cache.format = AudioStreamWAV.FORMAT_16_BITS
	_whoosh_cache.mix_rate = rate
	_whoosh_cache.stereo = false
	_whoosh_cache.data = data
	return _whoosh_cache


# --- Yardımcılar ------------------------------------------------------------------------------------

func _car_length() -> float:
	return _bounds.size.z * (_car.scale.z if is_instance_valid(_car) else 1.0)


func _car_height() -> float:
	return _bounds.size.y * (_car.scale.y if is_instance_valid(_car) else 1.0)


## Modelin kendi uzayındaki sınırları (ölçek öncesi), KÖŞE NOKTALARINDAN: bazı modellerde (Tripo) parça düğümleri dönük
## ve dönük kutunun kutusu gerçeğin katları çıkıyordu (BMW E60: genişlik 1,34 → kamera geri çekilip köşe kolonuna
## giriyor, ekran simsiyah). Hız için her 4. köşe; gizli parçalar sayılmaz.
func _local_bounds(car: Node3D) -> AABB:
	var inverse: Transform3D = car.global_transform.affine_inverse()
	var low: Vector3 = Vector3.INF
	var high: Vector3 = -Vector3.INF
	for node: Node in car.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var xf: Transform3D = inverse * mi.global_transform
		for surface: int in mi.mesh.get_surface_count():
			var verts: PackedVector3Array = mi.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for i: int in range(0, verts.size(), 4):
				var p: Vector3 = xf * verts[i]
				low = low.min(p)
				high = high.max(p)
	if low.x > high.x:
		return AABB(Vector3(-0.25, 0.0, -0.5), Vector3(0.5, 0.35, 1.0))
	return AABB(low, high - low)


static func _no_shadows(car: Node3D) -> void:
	for node: Node in car.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static var _shadow_texture: GradientTexture2D


## Tablanın üstünde aracın altında yumuşak temas gölgesi (çarpımlı; yansımanın da üstünde).
func _contact_shadow() -> MeshInstance3D:
	if _shadow_texture == null:
		var g: Gradient = Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
		g.colors = PackedColorArray([Color(0.25, 0.25, 0.25), Color(0.55, 0.55, 0.55), Color(1, 1, 1)])
		_shadow_texture = GradientTexture2D.new()
		_shadow_texture.gradient = g
		_shadow_texture.fill = GradientTexture2D.FILL_RADIAL
		_shadow_texture.fill_from = Vector2(0.5, 0.5)
		_shadow_texture.fill_to = Vector2(1.0, 0.5)
		_shadow_texture.width = 128
		_shadow_texture.height = 128
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(_bounds.size.x * 1.3, _bounds.size.z * 1.12)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "ContactShadow"
	mi.mesh = quad
	mi.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	mi.position = Vector3(_bounds.get_center().x, _bounds.position.y + 0.004, _bounds.get_center().z)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = _shadow_texture
	material.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.render_priority = 3
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
