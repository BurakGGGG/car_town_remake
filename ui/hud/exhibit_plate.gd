class_name ExhibitPlate
extends Control
## SERGİ PLAKASI — ana garajda sergilenen araca dünyada dokununca (ya da TÜM ARAÇLAR'dan seçilince) açılır
## (docs/GARAJLAR_TASARIM.md §10, 2026-10-20): kamera araca yaklaşır, altta plaka: ad · sınıf · değer, YARIŞA SEÇ,
## MODİFİYE (garaj ekranı geçici lift görünümünde açılır), DEPOYA TAŞI (boş yeri olan depolar; depolar doluysa
## otopark), SAT (iki dokunuş). Ayrı bir "GARAJIM" ekranı yok: sergideki araç dünyada kendi yerinde görünür.
## HUD kurar; bir ekran / pano açılınca ya da başka bir dünya plakası açılınca kapanır. Kodla kurulur (.tscn yok).

## MODİFİYE: HUD garaj ekranını bu araçla, modifiye kipinde açar.
signal mods_requested(vehicle_id: StringName)
## Kısa bildirim (taşındı, satıldı, son araç satılamaz).
signal notice_requested(text: String, color: Color)

## Kameranın araca yaklaşırken kadrajladığı kare (dünya birimi) ve oyuncu sınırından yakın çekim (WorldCamera.min_zoom 2,2).
const ZOOM_SPAN: float = 1.1
const ZOOM_CLOSEST: float = 1.5
## SAT'ın onay penceresi (ms).
const CONFIRM_MS: int = 3000

var vehicle_id: StringName = &""

var _column: VBoxContainer
var _panel: PlatePanel
var _name: Label
var _info: Label
var _actions: HBoxContainer
var _targets: HBoxContainer
var _race: PlateButton
var _sell: PlateButton
var _sell_armed_until: int = 0
var _view_before: Dictionary = {}


func _ready() -> void:
	name = "ExhibitPlate"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


## Plakayı araç için açar ve kamerayı ona yaklaştırır. Araç sergide değilse açılmaz (false).
func show_for(id: StringName) -> bool:
	var body: Node3D = _body_of(id)
	if body == null:
		return false
	vehicle_id = id
	_sell_armed_until = 0
	_show_actions()
	_refresh()
	# Parçası takılan araç liftte, sergisi gizli (GarageDecorView._apply_away): kamera boş sergi yerine lifteki araca gider
	var target: Node3D = body
	var mod_bays: PerformanceBays = get_tree().get_first_node_in_group("performance_bays") as PerformanceBays
	var on_lift: PerformanceBayDisplay = mod_bays.display_of(id) if mod_bays else null
	if not body.visible and on_lift != null and is_instance_valid(on_lift):
		target = on_lift
	var camera: WorldCamera = get_viewport().get_camera_3d() as WorldCamera
	if camera:
		var c: Vector3 = target.global_position
		var before: Dictionary = camera.frame_box(AABB(Vector3(c.x - ZOOM_SPAN * 0.5, 0.0, c.z - ZOOM_SPAN * 0.5),
			Vector3(ZOOM_SPAN, 0.5, ZOOM_SPAN)), 0.10, 0.56, 0.05, ZOOM_CLOSEST)
		if _view_before.is_empty():   # plaka açıkken başka araca geçilirse ilk görünüme dönülür
			_view_before = before
	PlateAnim.pop_in(self, _column)
	return true


## Kapatır; kamera plaka açılmadan önceki görünüme döner (restore = false: ekran açılıyor, kamera kalsın).
func hide_plate(restore: bool = true) -> void:
	if not visible:
		_view_before = {}
		return
	hide()
	var camera: WorldCamera = get_viewport().get_camera_3d() as WorldCamera
	if restore and camera and not _view_before.is_empty():
		camera.restore_view(_view_before)
	_view_before = {}
	vehicle_id = &""


# --- Kurulum -------------------------------------------------------------------------

func _build() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override(&"margin_left", 16)
	margin.add_theme_constant_override(&"margin_right", 16)
	margin.add_theme_constant_override(&"margin_bottom", 92)   # alt sekmelerin üstünde
	add_child(margin)
	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.alignment = BoxContainer.ALIGNMENT_END
	margin.add_child(_column)

	_panel = PlatePanel.new()
	_panel.name = "Panel"
	_panel.theme_type_variation = &"HudCarPlate"
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 8)
	_panel.add_child(box)

	var head: HBoxContainer = HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override(&"separation", 12)
	var words: VBoxContainer = VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override(&"separation", 0)
	var caption: Label = _label(&"HudInkCaption", Loc.t("GARAJINDA SERGİDE"))
	caption.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
	words.add_child(caption)
	_name = _label(&"HudPlateTitle", "")
	words.add_child(_name)
	_info = _label(&"HudInkCaption", "")
	words.add_child(_info)
	head.add_child(words)
	var close: PlateButton = PlateButton.new()
	close.name = "Close"
	close.theme_type_variation = &"HudSign"
	close.shape = PlateButton.Shape.ROUND
	close.kind = HudIcon.Kind.CROSS
	close.icon_size = 14.0
	close.custom_minimum_size = Vector2(32.0, 32.0)
	close.bolts = false
	close.lift_when_pressed = 0.0
	close.focus_mode = Control.FOCUS_NONE
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(hide_plate)
	head.add_child(close)
	box.add_child(head)

	_actions = HBoxContainer.new()
	_actions.name = "Actions"
	_actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_actions.add_theme_constant_override(&"separation", 8)
	_race = _plate("Race", HudIcon.Kind.FLAG, "", _on_race)
	var mods: PlateButton = _plate("Mods", HudIcon.Kind.WRENCH, Loc.t("MODİFİYE"), func() -> void:
		var id: StringName = vehicle_id
		hide_plate(false)
		mods_requested.emit(id))
	mods.highlight = true
	var move: PlateButton = _plate("Move", HudIcon.Kind.BOX, Loc.t("DEPOYA TAŞI"), _show_targets)
	_sell = _plate("Sell", HudIcon.Kind.COIN, Loc.t("SAT"), _on_sell)
	for button: PlateButton in [_race, mods, move, _sell]:
		_actions.add_child(button)
	box.add_child(_actions)

	_targets = HBoxContainer.new()
	_targets.name = "Targets"
	_targets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_targets.add_theme_constant_override(&"separation", 8)
	_targets.visible = false
	box.add_child(_targets)
	_column.add_child(_panel)


func _plate(node_name: String, kind: HudIcon.Kind, text: String, action: Callable) -> PlateButton:
	var button: PlateButton = PlateButton.new()
	button.name = node_name
	button.theme_type_variation = &"HudPlateSmall"
	button.kind = kind
	button.icon_left = true
	button.icon_size = 16.0
	button.bolts = false
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	return button


# --- İçerik ---------------------------------------------------------------------------

func _refresh() -> void:
	var entry: Dictionary = CarCatalog.get_entry(vehicle_id)
	_name.text = String(entry.get("display_name", vehicle_id)).to_upper()
	_info.text = Loc.t("%s SINIFI · %s ₺") % [PerformanceMods.class_of(vehicle_id),
		Hud.format_thousands(int(entry.get("price", 0)))]
	var ownership: VehicleOwnership = _ownership()
	var racer: bool = ownership != null and ownership.race_vehicle_id() == vehicle_id
	_race.text = Loc.t("YARIŞ ARACI") if racer else Loc.t("YARIŞA SEÇ")
	if _race.highlight != racer:
		_race.highlight = racer
	var armed: bool = Time.get_ticks_msec() < _sell_armed_until
	_sell.text = Loc.t("ONAYLA: +%s ₺") % Hud.format_thousands(ownership.sell_price(vehicle_id)) \
		if armed and ownership else Loc.t("SAT")


func _on_race() -> void:
	var ownership: VehicleOwnership = _ownership()
	if ownership and ownership.set_race_vehicle(vehicle_id):
		_refresh()


## İlk dokunuş onay ister (geri alınamaz), ikincisi satar. Son araç satılamaz.
func _on_sell() -> void:
	var ownership: VehicleOwnership = _ownership()
	if ownership == null:
		return
	if Time.get_ticks_msec() >= _sell_armed_until:
		_sell_armed_until = Time.get_ticks_msec() + CONFIRM_MS
		_refresh()
		get_tree().create_timer(float(CONFIRM_MS) / 1000.0).timeout.connect(func() -> void:
			if visible:
				_refresh())
		return
	var name_text: String = _name.text
	var payout: int = ownership.sell_price(vehicle_id)
	if not ownership.sell_vehicle(vehicle_id):
		notice_requested.emit(Loc.t("TEK ARACINI SATAMAZSIN"), HudPalette.DANGER)
		_sell_armed_until = 0
		_refresh()
		return
	hide_plate()
	notice_requested.emit(Loc.t("%s SATILDI · +%s ₺") % [name_text, Hud.format_thousands(payout)], HudPalette.COIN_DARK)


## DEPOYA TAŞI: eylemlerin yerine hedefler (boş yeri olan depolar; depolar doluysa otopark) + VAZGEÇ.
func _show_targets() -> void:
	var manager: CarGarageManager = get_tree().get_first_node_in_group("car_garages") as CarGarageManager
	if manager == null:
		return
	for child: Node in _targets.get_children():
		_targets.remove_child(child)
		child.queue_free()
	for target: StringName in manager.move_targets(vehicle_id):
		var text: String = Loc.t("OTOPARK\nGÜNLÜK %s ₺") % Hud.format_thousands(CarGarageManager.fee_of(vehicle_id)) \
			if target == CarGarageManager.WAITING \
			else "%s\n%d/%d" % [CarGarageCatalog.display_name(target), manager.used(target), manager.capacity(target)]
		var button: PlateButton = _plate("To_%s" % target, HudIcon.Kind.CAR if target == CarGarageManager.WAITING
			else HudIcon.Kind.BOX, text, _on_target.bind(target))
		_targets.add_child(button)
	_targets.add_child(_plate("Back", HudIcon.Kind.NONE, Loc.t("VAZGEÇ"), _show_actions))
	_actions.visible = false
	_targets.visible = true


func _show_actions() -> void:
	_targets.visible = false
	_actions.visible = true


func _on_target(target: StringName) -> void:
	var manager: CarGarageManager = get_tree().get_first_node_in_group("car_garages") as CarGarageManager
	var name_text: String = _name.text
	if manager == null or not manager.move(vehicle_id, target):
		_show_actions()
		return
	hide_plate()
	var place: String = Loc.t("OTOPARK") if target == CarGarageManager.WAITING else CarGarageCatalog.display_name(target)
	notice_requested.emit(Loc.t("%s → %s") % [name_text, place], HudPalette.COIN_DARK)


## Aracın dünyadaki sergi modeli (DecorManager örneği → GarageDecorView gövdesi); sergide değilse null.
func _body_of(id: StringName) -> Node3D:
	var decor: DecorManager = get_tree().get_first_node_in_group("decor") as DecorManager
	var view: GarageDecorView = get_tree().get_first_node_in_group("garage_decor_view") as GarageDecorView
	if decor == null or view == null:
		return null
	var item: StringName = GarageDecor.vehicle_item_id(id)
	for inst: Dictionary in decor.instances():
		if inst["item"] == item:
			return view.body_of(String(inst["iid"]))
	return null


func _ownership() -> VehicleOwnership:
	return get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
