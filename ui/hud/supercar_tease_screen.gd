class_name SupercarTeaseScreen
extends Control
## "BİR GÜN SENİN DE OLACAK!" — SÜPER ARABA TANITIMI'nın sonu (2026-10-23, kullanıcı: "3. dragında süper araç gelsin,
## ezici üstünlükle yensin, sonra ileride senin de araçların böyle olacak ekranı gelsin"; kurallar RaceManager'da).
## Tanıtım yarışı kaybedilip GARAJA DÖN'e basılınca Hud açar (UiRouter'da MODAL "supercar_tease"). Solda döner tablada
## yavaşça dönen beyaz hiper araç (kendi SubViewport'u, açıkken kurulur, kapanınca silinir), sağda adı, gerçek değerleri
## (BG · 0-100 · son hız), kısa teselli + hedef yazısı ve aracın çıktığı kasa ile seviyesi; arkada dönen altın ışınlar.
## HEDEFİM BU! (ya da GERİ) kapatır.

signal closed

const STAGE_SPIN: float = 0.45
## Araç sahnesi kamerası: hafif yukarıdan, üç çeyrek önden (vitrin açısı).
const STAGE_VIEW: Vector3 = Vector3(0.62, 0.36, 0.7)
const TITLE_SIZE: int = 26

var vehicle_id: StringName = RaceManager.SHOWCASE_CAR
var color: Color = RaceManager.SHOWCASE_COLOR

var _column: VBoxContainer
var _rays: _Rays
var _stage_slot: Control
var _stage: SubViewportContainer
var _pivot: Node3D
var _name: Label
var _chips: HBoxContainer
var _source: Label
var _button: PlateButton
var _sfx: RewardSfx
var _closing: bool = false


func _ready() -> void:
	name = "SupercarTeaseScreen"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	set_process(false)


func open() -> void:
	_closing = false
	_fill()
	_build_stage()
	show()
	PlateAnim.pop_in(self, _column)
	_rays.start()
	_sfx.fanfare()
	set_process(true)


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	_rays.stop()
	PlateAnim.pop_out(self, _column, func() -> void:
		hide()
		set_process(false)
		_free_stage()
		_closing = false
		closed.emit())


func _process(delta: float) -> void:
	if is_instance_valid(_pivot):
		_pivot.rotation.y = fmod(_pivot.rotation.y + delta * STAGE_SPIN, TAU)


# --- Kurulum -----------------------------------------------------------------

func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.04, 0.05, 0.07, 0.88)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_sfx = RewardSfx.new()
	add_child(_sfx)
	_rays = _Rays.new()
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rays.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_rays)

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 16)
	add_child(margin)
	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_column.add_theme_constant_override(&"separation", 6)
	margin.add_child(_column)

	var tag: PanelContainer = _pill(Loc.t("SÜPER ARABA"), HudPalette.PLATE_SELECTED, HudPalette.INK)
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_column.add_child(tag)
	var title: Label = _label(&"HudOutlinedLarge", Loc.t("BİR GÜN SENİN DE OLACAK!"))
	title.add_theme_font_size_override(&"font_size", TITLE_SIZE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(title)

	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 14)
	_column.add_child(row)
	# Araç sahnesi bu yuvaya kurulur (açılışta); ışınlar onun ortasından yayılır
	_stage_slot = Control.new()
	_stage_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage_slot.size_flags_stretch_ratio = 1.25
	_stage_slot.custom_minimum_size = Vector2(0.0, 270.0)
	row.add_child(_stage_slot)
	_rays.target = _stage_slot

	var info: VBoxContainer = VBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override(&"separation", 8)
	row.add_child(info)
	_name = _label(&"HudOutlinedLarge", "")
	_name.add_theme_font_size_override(&"font_size", 20)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_name)
	_chips = HBoxContainer.new()
	_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chips.add_theme_constant_override(&"separation", 6)
	info.add_child(_chips)
	var text: Label = _label(&"HudOutlined", Loc.t("Bugün seni geçti ama yolun daha başında. Tamir et, para biriktir, garajını büyüt: bir gün böyle bir araba da senin garajında duracak."))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(220.0, 0.0)
	info.add_child(text)
	_source = _label(&"HudOutlined", "")
	_source.add_theme_color_override(&"font_color", HudPalette.PLATE_SELECTED)
	info.add_child(_source)
	_button = PlateButton.new()
	_button.theme_type_variation = &"HudPlateSmall"
	_button.text = Loc.t("HEDEFİM BU!")
	_button.highlight = true
	_button.focus_mode = Control.FOCUS_NONE
	_button.custom_minimum_size = Vector2(200.0, 0.0)
	_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_button.pressed.connect(close)
	info.add_child(_button)


## Araca göre yazılar: adı, gerçek değerleri, çıktığı kasa ve seviyesi (kasada yoksa satır gizli).
func _fill() -> void:
	var entry: Dictionary = CarCatalog.get_entry(vehicle_id)
	_name.text = String(entry.get("display_name", vehicle_id)).to_upper()
	for child: Node in _chips.get_children():
		child.queue_free()
	var perf: Dictionary = entry.get("performance", {}) if entry.get("performance") is Dictionary else {}
	if int(perf.get("hp", 0)) > 0:
		_chips.add_child(_pill(Loc.t("%d BG") % int(perf["hp"]), Color(0.08, 0.09, 0.1, 0.85), HudPalette.TEXT_LIGHT))
	if float(perf.get("zero_100", 0.0)) > 0.0:
		_chips.add_child(_pill(Loc.t("0-100: %s SN") % Loc.decimal(float(perf["zero_100"])), Color(0.08, 0.09, 0.1, 0.85),
			HudPalette.TEXT_LIGHT))
	if int(perf.get("top_speed", 0)) > 0:
		_chips.add_child(_pill(Loc.t("%d KM/SA") % int(perf["top_speed"]), Color(0.08, 0.09, 0.1, 0.85), HudPalette.TEXT_LIGHT))
	var crate: StringName = CrateCatalog.crate_of(vehicle_id)
	_source.visible = crate != &""
	if crate != &"":
		_source.text = Loc.t("%s · SEVİYE %d") % [Loc.t(String(CrateCatalog.get_entry(crate).get("display_name", ""))),
			CrateCatalog.min_level(crate)]


## Döner tablada araç: kendi dünyası, ortam ışığı ve iki ışık (Compatibility: ortamsız SubViewport ışığı dünyaya sızar).
func _build_stage() -> void:
	_free_stage()
	_stage = SubViewportContainer.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.stretch = true
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage_slot.add_child(_stage)
	var viewport: SubViewport = SubViewport.new()
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = GameSettings.subviewport_msaa(Viewport.MSAA_4X)
	_stage.add_child(viewport)
	var camera: Camera3D = Camera3D.new()
	camera.fov = 26.0
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("D8D4CC")
	env.ambient_light_energy = 0.6
	camera.environment = env
	viewport.add_child(camera)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.basis = Basis.looking_at(Vector3(-0.5, -1.0, -0.45).normalized(), Vector3.UP)
	key.light_color = Color("FFF3E0")
	key.light_energy = 1.1
	viewport.add_child(key)
	var rim: DirectionalLight3D = DirectionalLight3D.new()
	rim.basis = Basis.looking_at(Vector3(0.6, -0.4, 0.8).normalized(), Vector3.UP)
	rim.light_color = Color("FFD9A0")
	rim.light_energy = 0.45
	viewport.add_child(rim)
	_pivot = Node3D.new()
	viewport.add_child(_pivot)
	var path: String = CarCatalog.scene_path(vehicle_id)
	var car: Node3D = null
	if path != "" and ResourceLoader.exists(path):
		car = (load(path) as PackedScene).instantiate() as Node3D
	if car == null:
		return
	car.scale = Vector3.ONE * CarCatalog.model_scale(vehicle_id)
	_pivot.add_child(car)
	var rig: CarRig = CarRig.for_node(car)
	if rig:
		var look: CarAppearance = CarAppearance.new()
		look.body_color = color
		rig.apply(look)
	var bounds: AABB = _bounds(car)
	car.position -= Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)   # tabla ortasında, zeminde
	var radius: float = maxf(bounds.size.x, bounds.size.z) * 0.62
	var table: MeshInstance3D = MeshInstance3D.new()
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius * 1.04
	disc.height = radius * 0.08
	disc.radial_segments = 48
	var table_mat: StandardMaterial3D = StandardMaterial3D.new()
	table_mat.albedo_color = Color("1C1E22")
	table_mat.roughness = 0.75
	disc.material = table_mat
	table.mesh = disc
	table.position.y = -disc.height * 0.5
	_pivot.add_child(table)
	var ring: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = radius * 0.995
	torus.outer_radius = radius * 1.025
	var ring_mat: StandardMaterial3D = StandardMaterial3D.new()
	ring_mat.albedo_color = HudPalette.PLATE_SELECTED
	ring_mat.emission_enabled = true
	ring_mat.emission = HudPalette.PLATE_SELECTED
	ring_mat.emission_energy_multiplier = 0.25
	torus.material = ring_mat
	ring.mesh = torus
	ring.position.y = 0.005
	_pivot.add_child(ring)
	# Kadraj: tabla + araç görünsün (boy / en oranına göre uzaklık)
	var height: float = bounds.size.y
	var focus: Vector3 = Vector3(0.0, height * 0.3, 0.0)
	var reach: float = maxf(radius * 1.62, height * 2.8)
	camera.position = focus + STAGE_VIEW.normalized() * reach / (2.0 * tan(deg_to_rad(camera.fov) * 0.5))
	camera.look_at(focus, Vector3.UP)
	_pivot.rotation.y = -0.5


func _free_stage() -> void:
	if is_instance_valid(_stage):
		_stage.queue_free()
	_stage = null
	_pivot = null


static func _bounds(root: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	var inverse: Transform3D = root.get_parent_node_3d().global_transform.affine_inverse()   # tabla (pivot) uzayı
	for node: Node in root.find_children("*", "VisualInstance3D", true, false):
		var visual: VisualInstance3D = node as VisualInstance3D
		var box: AABB = inverse * visual.global_transform * visual.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Yuvarlak köşeli hap: renkli zemin + yazı (etiket, değer hapları).
func _pill(text: String, fill: Color, ink: Color) -> PanelContainer:
	var pill: PanelContainer = PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(12)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 2.0
	box.content_margin_bottom = 2.0
	pill.add_theme_stylebox_override(&"panel", box)
	var label: Label = _label(&"HudInkCaption", text)
	label.add_theme_color_override(&"font_color", ink)
	pill.add_child(label)
	return pill


## Araç sahnesinin arkasında yavaşça dönen altın ışık hüzmeleri (LevelUpScreen'dekinin eşi, hedefe ortalanır).
class _Rays extends Control:
	const RAYS: int = 18
	const SPEED: float = 0.25

	var target: Control
	var _angle: float = 0.0

	func start() -> void:
		set_process(true)

	func stop() -> void:
		set_process(false)

	func _ready() -> void:
		set_process(false)

	func _process(delta: float) -> void:
		_angle = fmod(_angle + delta * SPEED, TAU)
		queue_redraw()

	func _draw() -> void:
		if target == null:
			return
		var center: Vector2 = target.get_global_rect().get_center() - get_global_rect().position
		var radius: float = target.size.length() * 0.62
		var step: float = TAU / float(RAYS)
		var ray_color: Color = Color(HudPalette.COIN, 0.07)
		for i: int in RAYS:
			var a: float = _angle + step * float(i)
			draw_colored_polygon(PackedVector2Array([center,
				center + Vector2.from_angle(a) * radius,
				center + Vector2.from_angle(a + step * 0.45) * radius]), ray_color)
