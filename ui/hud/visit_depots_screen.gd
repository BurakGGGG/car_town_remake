class_name VisitDepotsScreen
extends Control
## ARKADAŞIN DEPOLARI — ziyarette (GarageVisit) arkadaşın depolarını gezdirir (kullanıcı kararı 2026-10-20: depo alma
## isteği / prestij). Salt okunur: arkadaşın açık garajındaki yerleşim (PublicGarage.depot_layout) pişmiş 3B iç mekânda
## (GarageInteriorView), arkadaşın araçları ve boyalarıyla (ziyaret sahnesi onun boyalarını yükler). ‹ › depolar arası,
## parmakla kaydır / yakınlaştır, araca dokun → adı. KAPAT ziyarete döner. VisitBar kurar; kodla kurulur (.tscn yok).

signal closed

var _layout: Dictionary = {}
var _ids: Array[StringName] = []
var _index: int = 0
var _container: SubViewportContainer
var _viewport: SubViewport
var _camera: Camera3D
var _key: DirectionalLight3D
var _view: GarageInteriorView
var _title: Label
var _car_label: Label
var _prev: PlateButton
var _next: PlateButton


func _ready() -> void:
	name = "VisitDepotsScreen"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


## Arkadaşın gezilebilir depoları (pişmiş iç mekânı olan alınmış depolar) var mı.
static func available() -> bool:
	return not _depots(PublicGarage.depot_layout(GarageVisit.garage())).is_empty()


func open() -> void:
	_layout = PublicGarage.depot_layout(GarageVisit.garage())
	_ids = _depots(_layout)
	if _ids.is_empty():
		return
	_index = 0
	show()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_show_depot()


func close() -> void:
	if not visible:
		return
	_view.exit()
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	hide()
	closed.emit()


static func _depots(layout: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in CarGarageCatalog.ids():
		if layout.has(String(id)) and GarageInterior.has_scene(id):
			out.append(id)
	return out


# --- Kurulum -------------------------------------------------------------------------

func _build() -> void:
	_container = SubViewportContainer.new()
	_container.name = "View"
	_container.stretch = true
	_container.mouse_filter = Control.MOUSE_FILTER_STOP
	_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_container)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.physics_object_picking = true   # araca dokun
	_viewport.msaa_3d = GameSettings.subviewport_msaa(Viewport.MSAA_2X)
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_container.add_child(_viewport)
	_camera = Camera3D.new()
	_viewport.add_child(_camera)
	_camera.current = true
	_key = DirectionalLight3D.new()
	_viewport.add_child(_key)
	_view = GarageInteriorView.new()
	add_child(_view)
	_view.car_tapped.connect(_on_car_tapped)
	_container.gui_input.connect(func(event: InputEvent) -> void:
		if _view.handle_input(event):
			_container.accept_event())

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: StringName in [&"margin_left", &"margin_right"]:
		margin.add_theme_constant_override(side, 16)
	margin.add_theme_constant_override(&"margin_top", 96)   # üstte ziyaret tabelası
	margin.add_theme_constant_override(&"margin_bottom", 16)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	var head: HBoxContainer = HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override(&"separation", 6)
	_prev = _arrow("Prev", "‹", -1)
	head.add_child(_prev)
	var sign: PlatePanel = PlatePanel.new()
	sign.theme_type_variation = &"HudCarPlate"
	var words: VBoxContainer = VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_theme_constant_override(&"separation", 0)
	var caption: Label = _label(&"HudInkCaption", Loc.t("ARKADAŞIN DEPOLARI"))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.add_child(caption)
	_title = _label(&"HudSignTitle", "")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.add_child(_title)
	sign.add_child(words)
	head.add_child(sign)
	_next = _arrow("Next", "›", 1)
	head.add_child(_next)
	column.add_child(head)

	var fill: Control = Control.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(fill)

	var foot: HBoxContainer = HBoxContainer.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override(&"separation", 10)
	_car_label = _label(&"HudOutlinedLarge", "")
	_car_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(_car_label)
	var back: PlateButton = PlateButton.new()
	back.name = "Close"
	back.theme_type_variation = &"HudPlateSmall"
	back.text = Loc.t("KAPAT")
	back.bolts = false
	back.focus_mode = Control.FOCUS_NONE
	back.custom_minimum_size = Vector2(180.0, 0.0)
	back.pressed.connect(close)
	foot.add_child(back)
	column.add_child(foot)


func _arrow(node_name: String, glyph: String, step: int) -> PlateButton:
	var button: PlateButton = PlateButton.new()
	button.name = node_name
	button.theme_type_variation = &"HudPlateSmall"
	button.bolts = false
	button.text = glyph
	button.add_theme_font_size_override(&"font_size", 22)
	button.custom_minimum_size = Vector2(PlateButton.MIN_PLATE_HEIGHT, 0.0)
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(func() -> void:
		_index = posmod(_index + step, _ids.size())
		_show_depot())
	return button


# --- İçerik ---------------------------------------------------------------------------

func _show_depot() -> void:
	var id: StringName = _ids[_index]
	var row: Dictionary = _layout[String(id)]
	var slots: Array[StringName] = []
	for car: Variant in row.get("slots", []):
		slots.append(StringName(String(car)))
	var levels: Dictionary = {}
	for item: StringName in CarGarageCatalog.ITEMS:
		levels[item] = int((row.get("levels", {}) as Dictionary).get(String(item), 1))
	if not _view.enter(id, _viewport, _camera, _key, []):
		return
	_view.set_levels(levels)
	_view.sync_cars(slots)
	_view.overview(false)
	var used: int = slots.filter(func(car: StringName) -> bool: return car != &"").size()
	_title.text = "%s   %d/%d" % [CarGarageCatalog.display_name(id), used, slots.size()]
	_car_label.text = ""
	_prev.visible = _ids.size() > 1
	_next.visible = _ids.size() > 1


func _on_car_tapped(vehicle_id: StringName) -> void:
	_view.focus(vehicle_id)
	_car_label.text = String(CarCatalog.get_entry(vehicle_id).get("display_name", vehicle_id)).to_upper()


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
