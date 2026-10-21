class_name NameSignPanel
extends PlatePanel
## İSİM TABELASI panosu (ARAÇLAR ekranı, otopark / depo iç mekânında sağ üstteki TABELA tabelası): yazı, stil, harf
## rengi. Her değişiklik önizlenir (3B tabela hemen değişir); KAYDET yazar, VAZGEÇ eskisine döner, KALDIR tabelayı söker.
## Yazının denetimi CarGarageManager.set_sign'da (NameSign.clean_text): reddedilirse pano açık kalır, uyarı yazar.

signal previewed(data: Dictionary)
signal save_requested(data: Dictionary)
signal cancelled

var _data: Dictionary = NameSign.empty_data()
var _had_sign: bool = false
var _edit: LineEdit
var _styles: HFlowContainer
var _colors: HFlowContainer
var _error: Label
var _remove: PlateButton


func _init() -> void:
	name = "NameSignPanel"
	theme_type_variation = &"HudCarPlate"
	custom_minimum_size = Vector2(212.0, 0.0)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	visible = false
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 5)
	box.add_child(_label(&"HudPlateTitle", Loc.t("İSİM TABELASI")))
	_edit = LineEdit.new()
	_edit.name = "SignText"
	_edit.placeholder_text = Loc.t("YAZINI YAZ")
	_edit.max_length = NameSign.MAX_CHARS
	_edit.custom_minimum_size = Vector2(0.0, 38.0)
	_edit.add_theme_color_override(&"font_color", HudPalette.INK)
	_edit.add_theme_color_override(&"font_placeholder_color", HudPalette.INK_SOFT)
	_edit.add_theme_color_override(&"caret_color", HudPalette.INK)
	_edit.add_theme_font_size_override(&"font_size", 18)
	for state: StringName in [&"normal", &"focus"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = HudPalette.PLATE_HOVER
		style.border_color = HudPalette.PLATE_SELECTED_EDGE if state == &"focus" else HudPalette.PLATE_EDGE
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		style.content_margin_left = 8.0
		style.content_margin_right = 8.0
		_edit.add_theme_stylebox_override(state, style)
	_edit.text_changed.connect(func(text: String) -> void:
		_data["t"] = text
		_error.hide()
		previewed.emit(_data.duplicate()))
	_edit.text_submitted.connect(func(_text: String) -> void: _edit.release_focus())
	box.add_child(_edit)
	box.add_child(_label(&"HudInkCaption", Loc.t("STİL")))
	_styles = HFlowContainer.new()
	_styles.name = "Styles"
	_styles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_styles.add_theme_constant_override(&"h_separation", 4)
	_styles.add_theme_constant_override(&"v_separation", 4)
	for i: int in NameSign.STYLES.size():
		var button: PlateButton = PlateButton.new()
		button.name = "Style_%d" % i
		button.theme_type_variation = &"HudPlateSmall"
		button.bolts = false
		button.focus_mode = Control.FOCUS_NONE
		button.text = NameSign.style_name(i)
		button.add_theme_font_size_override(&"font_size", 12)
		button.pressed.connect(_pick_style.bind(i))
		_styles.add_child(button)
	box.add_child(_styles)
	box.add_child(_label(&"HudInkCaption", Loc.t("HARF RENGİ")))
	_colors = HFlowContainer.new()
	_colors.name = "Colors"
	_colors.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colors.add_theme_constant_override(&"h_separation", 4)
	_colors.add_theme_constant_override(&"v_separation", 4)
	for i: int in NameSign.COLORS.size():
		var swatch: _Swatch = _Swatch.new()
		swatch.name = "Color_%d" % i
		swatch.pressed.connect(_pick_color.bind(i))
		_colors.add_child(swatch)
	box.add_child(_colors)
	_error = _label(&"HudInkCaption", Loc.t("BU YAZI KULLANILAMAZ"))
	_error.add_theme_color_override(&"font_color", HudPalette.DANGER)
	_error.hide()
	box.add_child(_error)
	var save: PlateButton = _button("SaveButton", Loc.t("KAYDET"))
	save.highlight = true
	save.pressed.connect(func() -> void:
		_edit.release_focus()
		save_requested.emit(_data.duplicate()))
	box.add_child(save)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 4)
	_remove = _button("RemoveButton", Loc.t("KALDIR"))
	_remove.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_remove.pressed.connect(func() -> void:
		_edit.release_focus()
		var cleared: Dictionary = _data.duplicate()
		cleared["t"] = ""
		save_requested.emit(cleared))
	row.add_child(_remove)
	var cancel: PlateButton = _button("CancelButton", Loc.t("VAZGEÇ"))
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(func() -> void:
		_edit.release_focus()
		cancelled.emit())
	row.add_child(cancel)
	box.add_child(row)
	add_child(box)


## Panoyu `data` ile açar; yazı yoksa `suggestion` (profildeki garaj adı) önerilir — önizlenir ama kaydedilmez.
func open(data: Dictionary, suggestion: String = "") -> void:
	_data = NameSign.sanitize(data)
	_had_sign = not String(_data["t"]).is_empty()
	if not _had_sign and not suggestion.is_empty():
		_data["t"] = NameSign.clean_text(suggestion)
	_edit.text = String(_data["t"])
	_error.hide()
	_remove.visible = _had_sign
	_refresh()
	show()
	previewed.emit(_data.duplicate())


## Kayıt reddedildi (süzgeç): uyarı, pano açık kalır.
func show_error() -> void:
	_error.show()


func data() -> Dictionary:
	return _data.duplicate()


func _pick_style(style: int) -> void:
	_data["s"] = style
	_refresh()
	previewed.emit(_data.duplicate())


func _pick_color(index: int) -> void:
	_data["c"] = index
	_refresh()
	previewed.emit(_data.duplicate())


func _refresh() -> void:
	for i: int in _styles.get_child_count():
		(_styles.get_child(i) as PlateButton).highlight = i == int(_data["s"])
	for i: int in _colors.get_child_count():
		var probe: Dictionary = {"s": _data["s"], "c": i}
		var swatch: _Swatch = _colors.get_child(i) as _Swatch
		swatch.color = NameSign.ink_of(probe)
		swatch.tile = NameSign.STYLES[int(_data["s"])]["tile"]
		swatch.selected = i == int(_data["c"])


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(node_name: String, text: String) -> PlateButton:
	var button: PlateButton = PlateButton.new()
	button.name = node_name
	button.theme_type_variation = &"HudPlateSmall"
	button.bolts = false
	button.focus_mode = Control.FOCUS_NONE
	button.text = text
	return button


## Renk karesi: stilin karosu üstünde harf rengi (seçiliyse amber çerçeve).
class _Swatch:
	extends Button

	var color: Color = Color.WHITE:
		set(value):
			color = value
			queue_redraw()
	var tile: Color = HudPalette.PLATE:
		set(value):
			tile = value
			queue_redraw()
	var selected: bool = false:
		set(value):
			selected = value
			queue_redraw()

	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(20.0, 20.0)
		for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, size).grow(-1.0)
		draw_rect(r, tile)
		draw_rect(r.grow(-4.0), color)
		draw_rect(r, HudPalette.PLATE_SELECTED_EDGE if selected else Color(HudPalette.INK, 0.35), false,
			3.0 if selected else 1.0)
