class_name GarageInteriorView
extends Node
## GARAJLARIM 3D iç mekân görünümü — garaj ekranının (GarageScreen) pişmiş iç mekânlı garajlardaki kipi
## (docs/GARAJLAR_TASARIM.md §6–7). GarageInterior'u (ortam) verilen 3B köke kurar, araçları park yerlerine koyar,
## perspektif kamerayı sürer: parmakla kaydır, iki parmak / tekerlekle yakınlaştır, araca dokun → odaklan.
##
## Ortam IŞIKSIZ (pişmiş ekran değerleri): ton eşleme DOĞRUSAL kalmalı, yoksa renkler ikinci kez bükülür. Araçlar
## anahtar ışık + ortam ışığıyla çizilir; gölge yok (ışıksız zemin gölge almaz): her aracın altında yumuşak temas
## gölgesi (çarpımlı) var. Seçili aracın altında sarı halka.
##
## Girdiğinde ödünç aldığı düğümlerin (kamera, anahtar ışık, eski garaj odası) ayarlarını saklar; exit() geri koyar.
## Modeller yalnız bu kip açıkken yaşar.

## Araca dokunuldu (sürükleme değil).
signal car_tapped(vehicle_id: StringName)

const TAP_MOVE: float = 14.0         # bu kadar pikselden fazla kayan dokunuş sürüklemedir
const TAP_TIME: float = 0.4
const ZOOM_MIN: float = 0.42         # varsayılan uzaklığın oranı
const ZOOM_MAX: float = 1.12
## Odakta garajın kendisi de görünsün: 0,58'de seçili araç ekranı dolduruyordu (telefon, 2026-10-19)
const FOCUS_ZOOM: float = 0.78
## Hedef ekranın biraz üstünde dursun: alt araç şeridi görünümün alt üçte birini örtüyor (uzaklığın oranı)
const FRAME_LIFT: float = 0.11
## Genel görünüm (boş garaj / bekleyenler): telefon tuvali önizlemeden dar, kenarlar plakaların altında kalıyor
const OVERVIEW_ZOOM: float = 1.1
const FOLLOW: float = 9.0            # kameranın hedefe yetişme hızı (1/sn)
## Kameraya en yakın bu kadar araç olağan detayda; ötekiler en kaba LOD'da (kullanıcı kararı 2026-10-19: HANGAR sv.3'te
## 24 araç 1,61 M üçgendi). Odaktaki araç her zaman tam detay.
const NEAR_CARS: int = 6
const LOD_BIAS_FAR: float = 0.0      # 0 = en kaba kademe (GeometryInstance3D.lod_bias)
const DETAIL_INTERVAL: float = 0.25  # yakın araçlar bu aralıkla yeniden seçilir (sn)

var active: bool = false
var interior: GarageInterior

var _root: Node
var _camera: Camera3D
var _key: DirectionalLight3D
var _hidden: Array[Node3D] = []
var _saved: Dictionary = {}
var _cars_root: Node3D
var _cars: Dictionary = {}           # araç id → Node3D
var _slot_of: Dictionary = {}        # araç id → park yeri (-1 = çekici)
var _ring: MeshInstance3D
var _sign: NameSign
var _focused: StringName = &""
var _bias: Dictionary = {}           # araç id → uygulanmış LOD katsayısı
var _detail_wait: float = 0.0
# kamera
var _dir: Vector3 = Vector3.BACK
var _dist0: float = 1.0
var _target: Vector3
var _dist: float = 1.0
var _goal_target: Vector3
var _goal_dist: float = 1.0
var _lift: float = 0.0               # FRAME_LIFT'in ne kadarı (odakta 1, genel görünümde 0)
var _goal_lift: float = 0.0
var _home_target: Vector3
var _bounds: Rect2                   # dünya XZ (x, z)
var _pitch_sin: float = 0.5
# girdi
var _touches: Dictionary = {}        # dokunma indeksi → konum
var _press_pos: Vector2
var _press_time: int = 0
var _dragged: bool = false
var _mouse_down: bool = false
var _pinch_dist: float = 0.0
var _pinch_center: Vector2


func _ready() -> void:
	set_process(false)


## Kipi açar: `garage` için iç mekân `root`a kurulur, `hide` düğümleri (eski oda) gizlenir. Sahne yoksa false.
func enter(garage: StringName, root: Node, camera: Camera3D, key_light: DirectionalLight3D, hide: Array[Node3D]) -> bool:
	if active and interior and interior.garage == garage:
		return true
	exit()
	var created: GarageInterior = GarageInterior.create(garage)
	if created == null:
		return false
	interior = created
	_root = root
	_camera = camera
	_key = key_light
	_saved = {
		"projection": camera.projection, "size": camera.size, "fov": camera.fov, "keep_aspect": camera.keep_aspect,
		"transform": camera.transform, "environment": camera.environment, "near": camera.near, "far": camera.far,
		"v_offset": camera.v_offset, "h_offset": camera.h_offset,
		"key_transform": key_light.transform if key_light else Transform3D(), "key_color": key_light.light_color if key_light else Color.WHITE,
		"key_energy": key_light.light_energy if key_light else 1.0, "key_shadow": key_light.shadow_enabled if key_light else false,
	}
	_hidden.clear()
	for node: Node3D in hide:
		if node and node.visible:
			node.visible = false
			_hidden.append(node)
	root.add_child(interior)
	_cars_root = Node3D.new()
	_cars_root.name = "InteriorCars"
	root.add_child(_cars_root)
	_build_ring()
	_configure()
	active = true
	set_process(true)
	return true


## Kipten çıkar: modeller serbest, ödünç düğümler eski hâline.
func exit() -> void:
	if not active:
		return
	active = false
	set_process(false)
	_touches.clear()
	_mouse_down = false
	_focused = &""
	_sign = null   # iç mekânın çocuğu: onunla serbest
	_cars.clear()
	_slot_of.clear()
	_bias.clear()
	# Önce ağaçtan ayrılır: yalnız queue_free'de eski kök bir kare daha ağaçta kalıyor, aynı karede kurulan yeni iç mekânla
	# birlikte çiziliyor ve adı çakışıyordu ("InteriorCars" yerine "@Node3D@1717").
	for node: Node in [_cars_root, interior]:
		if is_instance_valid(node):
			if node.get_parent():
				node.get_parent().remove_child(node)
			node.queue_free()
	interior = null
	for node: Node3D in _hidden:
		if is_instance_valid(node):
			node.visible = true
	_hidden.clear()
	if is_instance_valid(_camera) and not _saved.is_empty():
		_camera.projection = _saved["projection"]
		_camera.size = _saved["size"]
		_camera.fov = _saved["fov"]
		_camera.keep_aspect = _saved["keep_aspect"]
		_camera.transform = _saved["transform"]
		_camera.environment = _saved["environment"]
		_camera.near = _saved["near"]
		_camera.far = _saved["far"]
		_camera.v_offset = _saved["v_offset"]
		_camera.h_offset = _saved["h_offset"]
	if is_instance_valid(_key) and not _saved.is_empty():
		_key.transform = _saved["key_transform"]
		_key.light_color = _saved["key_color"]
		_key.light_energy = _saved["key_energy"]
		_key.shadow_enabled = _saved["key_shadow"]
	_saved.clear()


## Modifiye garajı açıkken (ModGarageView aynı kökü ve kamerayı kullanır): iç mekân ve araçlar gizlenir, kamera sürülmez.
## Kamera / ışık ayarlarını ModGarageView çıkarken geri koyar.
func suspend(on: bool) -> void:
	if not active:
		return
	for node: Node3D in [interior, _cars_root]:
		if is_instance_valid(node):
			node.visible = not on
	_touches.clear()
	_mouse_down = false
	set_process(not on)


func set_levels(levels: Dictionary) -> void:
	if active:
		interior.set_levels(levels)


## Araçları park yerlerine koyar: slots[i] = i. yerin aracı (&"" boş). tow: çekici kasasındaki araç (çatı katı).
## Yerinde aynı araç duruyorsa yeniden yüklenmez.
func sync_cars(slots: Array[StringName], tow: StringName = &"") -> void:
	if not active:
		return
	var wanted: Dictionary = {}
	var count: int = interior.slot_count()
	for i: int in mini(slots.size(), count):
		if slots[i] != &"":
			wanted[slots[i]] = i
	if tow != &"" and interior.has_tow():
		wanted[tow] = -1
	for id: StringName in _cars.keys():
		if not wanted.has(id) or int(wanted[id]) != int(_slot_of.get(id, -2)):
			(_cars[id] as Node3D).queue_free()
			_cars.erase(id)
			_slot_of.erase(id)
			_bias.erase(id)
	for id: StringName in wanted:
		if _cars.has(id):
			continue
		var index: int = wanted[id]
		var car: Node3D = _spawn(id, interior.tow_transform() if index < 0 else interior.slot_transform(index))
		if car:
			_cars[id] = car
			_slot_of[id] = index
			_bias[id] = CarRig.LOD_BIAS_WORLD
	if _focused != &"" and not _cars.has(_focused):
		_focused = &""
	_place_ring()
	_update_detail()


## İSİM TABELASI (NameSign): iç mekânın tabela yerine (GarageInterior.sign_anchor) kurulur; boş yazı tabelayı kaldırır.
## Tabela iç mekânın çocuğudur: ölçeği (METER) metreyi oyun birimine çevirir.
func set_sign(data: Dictionary) -> void:
	if not active:
		return
	var anchor: Dictionary = interior.sign_anchor()
	if anchor.is_empty():
		return
	if _sign == null or not is_instance_valid(_sign):
		_sign = NameSign.new()
		_sign.name = "NameSign"
		interior.add_child(_sign)
		var p: Vector3 = anchor["pos"]
		_sign.position = Vector3(p.x, p.z, -p.y)
		_sign.rotation.y = deg_to_rad(float(anchor.get("yaw", 0.0)))
	_sign.build(data, float(anchor["width"]), float(anchor["height"]), float(anchor.get("posts", 0.0)))


func name_sign() -> NameSign:
	return _sign if is_instance_valid(_sign) else null


func has_car(vehicle_id: StringName) -> bool:
	return _cars.has(vehicle_id)


## Aracın görünüm sürücüsü (BOYA önizlemesi bunu kullanır).
func rig_of(vehicle_id: StringName) -> CarRig:
	var car: Node3D = _cars.get(vehicle_id) as Node3D
	return CarRig.for_node(car) if car else null


## Kamera araca gider ve yaklaşır; seçim halkası altına geçer.
func focus(vehicle_id: StringName, animated: bool = true) -> void:
	_focused = vehicle_id
	_place_ring()
	var car: Node3D = _cars.get(vehicle_id) as Node3D
	if car == null:
		_update_detail()
		return
	_goal_target = _clamp_target(car.global_position)
	_goal_dist = _dist0 * FOCUS_ZOOM
	_goal_lift = 1.0
	if not animated:
		_target = _goal_target
		_dist = _goal_dist
		_lift = _goal_lift
		_apply_camera()
	_update_detail()


## Seçimsiz genel görünüm (garaj boş / bekleyenler).
func overview(animated: bool = true) -> void:
	_focused = &""
	_place_ring()
	_goal_target = _home_target
	_goal_dist = _dist0 * OVERVIEW_ZOOM
	_goal_lift = 0.0
	if not animated:
		_target = _goal_target
		_dist = _goal_dist
		_lift = _goal_lift
		_apply_camera()
	_update_detail()


## Detay kademeleri: odaktaki araç tam (LOD0; 10 araçta hepsi LOD0'dayken 842 bin üçgen, ölçüldü), kameranın VARACAĞI
## konuma en yakın NEAR_CARS araç dünya kademesinde, kalanlar en kaba LOD'da. Yalnız değişen araca dokunulur.
func _update_detail() -> void:
	_detail_wait = DETAIL_INTERVAL
	if not active:
		return
	var eye: Vector3 = _goal_target + _dir * _goal_dist
	var order: Array = _cars.keys()
	order.sort_custom(func(a: StringName, b: StringName) -> bool:
		return (_cars[a] as Node3D).global_position.distance_squared_to(eye) \
			< (_cars[b] as Node3D).global_position.distance_squared_to(eye))
	for i: int in order.size():
		var id: StringName = order[i]
		var bias: float = CarRig.LOD_BIAS_GARAGE if id == _focused \
			else (CarRig.LOD_BIAS_WORLD if i < NEAR_CARS else LOD_BIAS_FAR)
		if is_equal_approx(float(_bias.get(id, -1.0)), bias):
			continue
		var rig: CarRig = rig_of(id)
		if rig:
			rig.set_lod_bias(bias)
			_bias[id] = bias


func _process(delta: float) -> void:
	var k: float = 1.0 - exp(-FOLLOW * delta)
	_target = _target.lerp(_goal_target, k)
	_dist = lerpf(_dist, _goal_dist, k)
	_lift = lerpf(_lift, _goal_lift, k)
	_apply_camera()
	_detail_wait -= delta
	if _detail_wait <= 0.0:
		_update_detail()
	if _ring and _ring.visible:
		var pulse: float = 0.75 + 0.25 * sin(Time.get_ticks_msec() / 260.0)
		(_ring.material_override as StandardMaterial3D).albedo_color = Color(pulse, pulse, pulse)


# --- Kurulum ------------------------------------------------------------------------------------

func _configure() -> void:
	var setup: Dictionary = interior.setup()
	var cam: Vector3 = interior.blender_point(setup["camera"])
	var target: Vector3 = interior.blender_point(setup["target"])
	_dir = (cam - target).normalized()
	_dist0 = cam.distance_to(target)
	_pitch_sin = maxf(_dir.y, 0.2)
	_home_target = target
	_target = target
	_goal_target = target
	_dist = _dist0 * OVERVIEW_ZOOM
	_goal_dist = _dist
	_lift = 0.0
	_goal_lift = 0.0
	var b: Rect2 = setup["bounds"]
	var a: Vector3 = interior.blender_point(Vector3(b.position.x, b.position.y, 0.0))
	var c: Vector3 = interior.blender_point(Vector3(b.end.x, b.end.y, 0.0))
	_bounds = Rect2(Vector2(minf(a.x, c.x), minf(a.z, c.z)), Vector2(absf(c.x - a.x), absf(c.z - a.z)))
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.fov = float(setup["fov"])
	_camera.near = 0.05
	_camera.far = 120.0
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = setup["background"]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = setup["ambient"]
	env.ambient_light_energy = float(setup["ambient_energy"])
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR   # ortam pişmiş ekran değeri: ikinci kez bükülmesin
	_camera.environment = env
	if _key:
		var d: Vector3 = GarageInterior.blender_dir(setup["key_dir"])
		_key.global_basis = Basis.looking_at(d, Vector3.UP if absf(d.y) < 0.99 else Vector3.FORWARD)
		_key.light_color = setup["key_color"]
		_key.light_energy = float(setup["key_energy"])
		_key.shadow_enabled = false
	_apply_camera()


func _apply_camera() -> void:
	if not is_instance_valid(_camera):
		return
	_camera.global_position = _target + _dir * _dist
	_camera.look_at(_target, Vector3.UP)
	_camera.v_offset = -_dist * FRAME_LIFT * _lift


func _clamp_target(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, _bounds.position.x, _bounds.end.x), _home_target.y,
		clampf(p.z, _bounds.position.y, _bounds.end.y))


# --- Araçlar ------------------------------------------------------------------------------------

func _spawn(vehicle_id: StringName, at: Transform3D) -> Node3D:
	var scene_path: String = CarCatalog.scene_path(vehicle_id)
	var scene: PackedScene = load(scene_path) as PackedScene if scene_path != "" else null
	if scene == null:
		return null
	var car: Node3D = scene.instantiate() as Node3D
	car.name = String(vehicle_id)
	_cars_root.add_child(car)
	car.global_transform = Transform3D(at.basis, at.origin)
	car.scale = Vector3.ONE * CarCatalog.model_scale(vehicle_id)
	var rig: CarRig = CarRig.for_node(car)
	rig.apply(CarAppearance.get_for(scene_path))
	rig.set_lod_bias(CarRig.LOD_BIAS_WORLD)   # park: ekrandaki boyuna göre sadeleşir; yalnız odaktaki tam detay (focus)
	rig.optimize(true)
	for node: Node in car.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bounds: AABB = _local_bounds(car)
	car.add_child(_contact_shadow(bounds))
	car.add_child(_pick_body(bounds, vehicle_id))
	car.set_meta(&"bounds", bounds)
	return car


## Modelin kendi uzayındaki sınırları (ölçek öncesi).
func _local_bounds(car: Node3D) -> AABB:
	var merged: AABB = AABB()
	var first: bool = true
	var inverse: Transform3D = car.global_transform.affine_inverse()
	for node: Node in car.find_children("*", "VisualInstance3D", true, false):
		var vi: VisualInstance3D = node as VisualInstance3D
		var box: AABB = inverse * (vi.global_transform * vi.get_aabb())
		merged = box if first else merged.merge(box)
		first = false
	return merged if not first else AABB(Vector3(-0.25, 0.0, -0.5), Vector3(0.5, 0.35, 1.0))


static var _shadow_texture: GradientTexture2D
static var _ring_texture: GradientTexture2D


func _contact_shadow(bounds: AABB) -> MeshInstance3D:
	if _shadow_texture == null:
		var g: Gradient = Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		g.colors = PackedColorArray([Color(0.42, 0.42, 0.42), Color(0.62, 0.62, 0.62), Color(1, 1, 1)])
		_shadow_texture = GradientTexture2D.new()
		_shadow_texture.gradient = g
		_shadow_texture.fill = GradientTexture2D.FILL_RADIAL
		_shadow_texture.fill_from = Vector2(0.5, 0.5)
		_shadow_texture.fill_to = Vector2(1.0, 0.5)
		_shadow_texture.width = 128
		_shadow_texture.height = 128
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(bounds.size.x * 1.35, bounds.size.z * 1.18)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "ContactShadow"
	mi.mesh = quad
	mi.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	mi.position = Vector3(bounds.get_center().x, bounds.position.y + 0.004, bounds.get_center().z)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = _shadow_texture
	material.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.render_priority = 2
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _pick_body(bounds: AABB, vehicle_id: StringName) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "PickBody"
	body.set_meta(&"vehicle_id", vehicle_id)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = bounds.size.max(Vector3.ONE * 0.2)
	shape.shape = box
	shape.position = bounds.get_center()
	body.add_child(shape)
	return body


func _build_ring() -> void:
	if _ring_texture == null:
		var g: Gradient = Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.8, 0.88, 0.95, 1.0])
		g.colors = PackedColorArray([Color(0, 0, 0), Color(0, 0, 0), Color(1.0, 0.75, 0.25), Color(0, 0, 0), Color(0, 0, 0)])
		_ring_texture = GradientTexture2D.new()
		_ring_texture.gradient = g
		_ring_texture.fill = GradientTexture2D.FILL_RADIAL
		_ring_texture.fill_from = Vector2(0.5, 0.5)
		_ring_texture.fill_to = Vector2(1.0, 0.5)
		_ring_texture.width = 256
		_ring_texture.height = 256
	_ring = MeshInstance3D.new()
	_ring.name = "SelectionRing"
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE
	_ring.mesh = quad
	_ring.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = _ring_texture
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.render_priority = 3
	_ring.material_override = material
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	_cars_root.add_child(_ring)


func _place_ring() -> void:
	if _ring == null:
		return
	var car: Node3D = _cars.get(_focused) as Node3D
	_ring.visible = car != null
	if car == null:
		return
	var bounds: AABB = car.get_meta(&"bounds", AABB())
	var s: float = car.scale.x
	var length: float = maxf(bounds.size.z, bounds.size.x) * s * 1.25
	_ring.global_position = car.global_transform * Vector3(bounds.get_center().x, bounds.position.y + 0.006, bounds.get_center().z)
	_ring.scale = Vector3(length, length, 1.0)
	_ring.global_rotation = Vector3(deg_to_rad(-90.0), car.global_rotation.y, 0.0)


# --- Girdi --------------------------------------------------------------------------------------

## Görünüm kabının girdisi (konumlar görünüm pikseli). İşlendiyse true.
func handle_input(event: InputEvent) -> bool:
	if not active:
		return false
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			_touches[touch.index] = touch.position
			if _touches.size() == 1:
				_begin_press(touch.position)
			else:
				_dragged = true
				_begin_pinch()
		else:
			_touches.erase(touch.index)
			if _touches.is_empty():
				_end_press(touch.position)
			else:
				_begin_pinch()
		return true
	if event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		_touches[drag.index] = drag.position
		if _touches.size() >= 2:
			_update_pinch()
		else:
			_drag(drag.position, drag.relative)
		return true
	if event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		var mb: InputEventMouseButton = event
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_zoom(0.9)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom(1.1)
			MOUSE_BUTTON_LEFT:
				_mouse_down = mb.pressed
				if mb.pressed:
					_begin_press(mb.position)
				else:
					_end_press(mb.position)
		return true
	if event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION and _mouse_down:
		var motion: InputEventMouseMotion = event
		_drag(motion.position, motion.relative)
		return true
	if event is InputEventMagnifyGesture:
		_zoom(1.0 / maxf((event as InputEventMagnifyGesture).factor, 0.01))
		return true
	if event is InputEventPanGesture:
		_pan((event as InputEventPanGesture).delta * -8.0)
		return true
	return false


func _begin_press(pos: Vector2) -> void:
	_press_pos = pos
	_press_time = Time.get_ticks_msec()
	_dragged = false


func _end_press(pos: Vector2) -> void:
	if _dragged or pos.distance_to(_press_pos) > TAP_MOVE or Time.get_ticks_msec() - _press_time > int(TAP_TIME * 1000.0):
		return
	var id: StringName = car_at(pos)
	if id != &"":
		car_tapped.emit(id)


func _drag(pos: Vector2, relative: Vector2) -> void:
	if not _dragged and pos.distance_to(_press_pos) <= TAP_MOVE:
		return
	_dragged = true
	_pan(relative)


## Ekrandaki kayma (piksel) → zeminde hedef kayması: parmağın altındaki nokta parmakla gelir.
func _pan(relative: Vector2) -> void:
	var height: float = maxf(_camera.get_viewport().get_visible_rect().size.y, 1.0)
	var scale: float = 2.0 * _dist * tan(deg_to_rad(_camera.fov) * 0.5) / height
	var right: Vector3 = _camera.global_basis.x
	right.y = 0.0
	var forward: Vector3 = -_camera.global_basis.z
	forward.y = 0.0
	right = right.normalized()
	forward = forward.normalized()
	var move: Vector3 = -right * relative.x * scale + forward * relative.y * scale / _pitch_sin
	_goal_target = _clamp_target(_goal_target + move)
	_target = _clamp_target(_target + move)


func _zoom(factor: float) -> void:
	_goal_dist = clampf(_goal_dist * factor, _dist0 * ZOOM_MIN, _dist0 * ZOOM_MAX)


func _begin_pinch() -> void:
	var points: Array = _touches.values()
	if points.size() < 2:
		return
	_pinch_dist = (points[0] as Vector2).distance_to(points[1])
	_pinch_center = ((points[0] as Vector2) + (points[1] as Vector2)) * 0.5


func _update_pinch() -> void:
	var points: Array = _touches.values()
	var d: float = (points[0] as Vector2).distance_to(points[1])
	var center: Vector2 = ((points[0] as Vector2) + (points[1] as Vector2)) * 0.5
	if _pinch_dist > 1.0 and d > 1.0:
		_zoom(_pinch_dist / d)
	_pan(center - _pinch_center)
	_pinch_dist = d
	_pinch_center = center


## Ekran noktasının altındaki araç (yoksa &"").
func car_at(pos: Vector2) -> StringName:
	if not is_instance_valid(_camera):
		return &""
	var from: Vector3 = _camera.project_ray_origin(pos)
	var to: Vector3 = from + _camera.project_ray_normal(pos) * 200.0
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	var hit: Dictionary = interior.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return &""
	var node: Node = hit["collider"] as Node
	return StringName(node.get_meta(&"vehicle_id", &"")) if node else &""
