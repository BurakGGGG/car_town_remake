class_name VisitBar
extends CanvasLayer
## ARKADAŞ GARAJI ziyaretinde ekranın üstündeki tabela: kimin garajı (ad, seviye, garaj değeri) ve
## GARAJIMA DÖN. Ziyaret sahnesinde HUD yoktur; tek arayüz budur. Kodla kurulur (GarageVisit ekler).
## Android geri tuşu da kendi garaja döndürür.

const HUD_THEME: Theme = preload("res://ui/theme/hud_theme.tres")
const PANEL_WIDTH: float = 360.0

var _back: PlateButton


func _ready() -> void:
	name = "VisitBar"
	layer = 10
	add_to_group("visit_bar")
	var root: Control = Control.new()
	root.name = "Root"
	root.theme = HUD_THEME
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top"]:
		margin.add_theme_constant_override(side, 16)
	root.add_child(margin)

	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 10)
	margin.add_child(row)

	var info: Dictionary = GarageVisit.info()
	var plate: PlatePanel = PlatePanel.new()
	plate.theme_type_variation = &"HudCarPlate"
	plate.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 0)
	plate.add_child(box)
	box.add_child(_label(&"HudInkCaption", Loc.t("ARKADAŞ GARAJI")))
	var title: Label = _label(&"HudPlateTitle", SaveSafe.s(info.get("name", "")))
	title.name = "VisitName"
	box.add_child(title)
	box.add_child(_label(&"HudInkCaption", Loc.t("SEVİYE %d  ·  GARAJ DEĞERİ %s ₺") % [
		maxi(SaveSafe.i(info.get("level", 1)), 1), Hud.format_thousands(SaveSafe.i(info.get("value", 0)))]))
	row.add_child(plate)

	_back = PlateButton.new()
	_back.name = "BackHomeButton"
	_back.theme_type_variation = &"HudPlate"
	_back.kind = HudIcon.Kind.GARAGE
	_back.text = Loc.t("GARAJIMA DÖN")
	_back.focus_mode = Control.FOCUS_NONE
	_back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_back.pressed.connect(_go_home)
	row.add_child(_back)
	_frame_garage.call_deferred()


## Ziyaret açılınca garajın TAMAMI görünsün (büyük garaj varsayılan yakınlıkta ekrana sığmaz).
## Üstte bu tabelanın altı, altta ekran kenarı payı bırakılır.
func _frame_garage() -> void:
	for i: int in 3:
		await get_tree().process_frame   # garaj seviyesi ve dekor yüklensin
	var camera: WorldCamera = get_viewport().get_camera_3d() as WorldCamera
	var view: GarageDecorView = get_tree().get_first_node_in_group("garage_decor_view") as GarageDecorView
	if camera == null or view == null:
		return
	var lot: Rect2 = view.lot_rect()
	camera.frame_box(AABB(Vector3(lot.position.x, 0.0, lot.position.y), Vector3(lot.size.x, 0.45, lot.size.y)),
		0.17, 0.97, 0.03)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_home()


func _go_home() -> void:
	GarageVisit.end.call_deferred(get_tree())


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
