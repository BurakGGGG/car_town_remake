class_name CollectionScreen
extends Control
## KOLEKSİYON tabelası — 16 aracın hepsi kasalarına göre gruplu: sahip olunanlar, keşfedilmiş ama
## satılmış olanlar ve henüz keşfedilmemişler (siluet). Her kartta nadirlik, sınıf, kasa kaynağı,
## o kasadaki gerçek olasılık ve kopya yıldızları; altta koleksiyon setleri.
## Ekran TAMAMEN KODLA kurulur (.tscn yok); mantık yoktur — VehicleOwnership ve CrateCatalog okunur.
##
## Yeni görsel asset yok: siluet, aracın mevcut küçük render'ının (CarGallery önbelleği) siyaha
## boyanmış hâlidir; nadirlik çerçevesi StyleBoxFlat, Legendary'nin parlaması bir tween'dir.

signal closed

const CARD_SIZE: Vector2 = Vector2(150.0, 124.0)
const THUMB_SIZE: Vector2 = Vector2(112.0, 62.0)
const COLUMNS: int = 5
const PLATE_WIDTH: float = 820.0

var _title: Label
var _grid_box: VBoxContainer
var _sets_box: VBoxContainer
var _column: VBoxContainer
var _thumb_host: CarGallery
var _thumbs: Dictionary = {}   # araç id → {"rect": TextureRect, "silhouette": bool}
var _pulses: Array[Tween] = []
var _closing: bool = false


func _ready() -> void:
	name = "CollectionScreen"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	# Küçük render'ları mevcut galeri üreticisi çizer (ayrı bir render sistemi yok)
	_thumb_host = CarGallery.new()
	_thumb_host.name = "ThumbnailHost"
	_thumb_host.mode = CarGallery.Mode.OWNED
	_thumb_host.visible = false
	add_child(_thumb_host)
	_thumb_host.thumbnails_rendered.connect(_apply_thumbnails)


func open() -> void:
	_rebuild()
	PlateAnim.pop_in(self, _column)


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	_stop_pulses()
	PlateAnim.pop_out(self, _column, func() -> void:
		hide()
		_closing = false
		closed.emit())


# --- Kurulum -------------------------------------------------------------------------

func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 16)
	add_child(margin)

	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_column.add_theme_constant_override(&"separation", 6)
	margin.add_child(_column)

	var sign: PlatePanel = PlatePanel.new()
	sign.theme_type_variation = &"HudCarPlate"
	sign.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_title = _label(&"HudSignTitle", Loc.t("KOLEKSİYON"))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.add_child(_title)
	_column.add_child(sign)

	var body: PlatePanel = PlatePanel.new()
	body.theme_type_variation = &"HudCarPlate"
	body.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	TouchScroll.attach(scroll)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var inner: VBoxContainer = VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override(&"separation", 10)
	scroll.add_child(inner)
	_grid_box = VBoxContainer.new()
	_grid_box.add_theme_constant_override(&"separation", 6)
	inner.add_child(_grid_box)
	_sets_box = VBoxContainer.new()
	_sets_box.add_theme_constant_override(&"separation", 2)
	inner.add_child(_sets_box)
	_column.add_child(body)

	var close_button: PlateButton = PlateButton.new()
	close_button.theme_type_variation = &"HudPlateSmall"
	close_button.text = Loc.t("KAPAT")
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.custom_minimum_size = Vector2(220.0, 0.0)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close)
	_column.add_child(close_button)


# --- İçerik ---------------------------------------------------------------------------

func _rebuild() -> void:
	_stop_pulses()
	_thumbs.clear()
	for child: Node in _grid_box.get_children():
		child.queue_free()
	for child: Node in _sets_box.get_children():
		child.queue_free()
	var own: VehicleOwnership = get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	var total: int = CarCatalog.size()
	var found: int = own.discovered_count() if own else 0
	_title.text = Loc.t("KOLEKSİYON   %d / %d") % [found, total]

	# Başlangıç aracı ve kasalar, kasa sırasıyla
	var groups: Array[Dictionary] = []
	var starters: Array[StringName] = []
	for entry: Dictionary in CarCatalog.all():
		if CrateCatalog.crate_of(entry["id"]) == &"":
			starters.append(entry["id"])
	if not starters.is_empty():
		groups.append({"title": Loc.t("BAŞLANGIÇ"), "crate": &"", "cars": starters})
	for crate: Dictionary in CrateCatalog.all():
		groups.append({"title": Loc.t(String(crate["display_name"])), "crate": crate["id"], "cars": crate["pool"]})

	var last_missing: StringName = _last_missing(own)
	for group: Dictionary in groups:
		var cars: Array = group["cars"]
		var have: int = 0
		for id: StringName in cars:
			if own and own.is_discovered(id):
				have += 1
		var header: Label = _label(&"HudPlateTitle", "%s   %d / %d" % [group["title"], have, cars.size()])
		_grid_box.add_child(header)
		var grid: GridContainer = GridContainer.new()
		grid.columns = COLUMNS
		grid.add_theme_constant_override(&"h_separation", 6)
		grid.add_theme_constant_override(&"v_separation", 6)
		for id: StringName in cars:
			grid.add_child(_card(id, own, id == last_missing))
		_grid_box.add_child(grid)

	_sets_box.add_child(_label(&"HudPlateTitle", Loc.t("KOLEKSİYON SETLERİ")))
	for set_entry: Dictionary in CrateCatalog.sets():
		var cars: Array = set_entry["cars"]
		var have: int = 0
		var names: PackedStringArray = PackedStringArray()
		for id: StringName in cars:
			var known: bool = own != null and own.is_discovered(id)
			if known:
				have += 1
			names.append(String(CarCatalog.get_entry(id).get("display_name", id)).to_upper() if known else "???")
		var done: bool = have == cars.size()
		var line: Label = _label(&"HudInkCaption", "%s %s   %d / %d   ·   %s" % [
			"✔" if done else "•", Loc.t(String(set_entry["name"])), have, cars.size(), "  ".join(names)])
		if done:
			line.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
		_sets_box.add_child(line)
	_apply_thumbnails()


## Koleksiyonda eksik tek araç kaldıysa o (son parça kartı öne çıkar).
func _last_missing(own: VehicleOwnership) -> StringName:
	if own == null:
		return &""
	var missing: Array[StringName] = []
	for entry: Dictionary in CarCatalog.all():
		if not own.is_discovered(entry["id"]):
			missing.append(entry["id"])
	return missing[0] if missing.size() == 1 else &""


func _card(id: StringName, own: VehicleOwnership, last_piece: bool) -> Control:
	var entry: Dictionary = CarCatalog.get_entry(id)
	var rarity: StringName = CrateCatalog.rarity_of(id)
	var color: Color = CrateCatalog.rarity_color(rarity)
	var owned: bool = own != null and own.is_owned(id)
	var known: bool = own != null and own.is_discovered(id)

	var frame: PanelContainer = PanelContainer.new()
	frame.custom_minimum_size = CARD_SIZE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("F3E8CF") if known else Color("D9CFBA")
	style.set_corner_radius_all(6)
	var border: int = 2
	match rarity:
		&"epic":
			border = 3
		&"legendary":
			border = 4
	if last_piece:
		border = 5
	style.set_border_width_all(border)
	style.border_color = color
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	frame.add_theme_stylebox_override(&"panel", style)

	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 0)
	frame.add_child(box)

	var rarity_label: Label = _label(&"HudInkCaption", Loc.t("%s  ·  %s SINIFI") % [
		CrateCatalog.rarity_label(rarity), String(entry.get("class", "?"))])
	rarity_label.add_theme_color_override(&"font_color", color.darkened(0.15))
	box.add_child(rarity_label)

	var thumb: TextureRect = TextureRect.new()
	thumb.custom_minimum_size = THUMB_SIZE
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not known:
		thumb.modulate = Color(0.0, 0.0, 0.0, 0.8)   # siluet: aynı render, tamamen siyah (renk sızmaz)
	box.add_child(thumb)
	_thumbs[id] = {"rect": thumb}
	if _thumb_host and _thumb_host.is_inside_tree():
		_thumb_host.request_thumbnail(id)

	var name_text: String = String(entry.get("display_name", id)).to_upper() if known else "???"
	box.add_child(_label(&"HudInkValue", name_text))

	var info: String
	if owned:
		var stars: int = own.stars(id)
		info = Loc.t("GARAJINDA") if stars == 0 else "%s  ×%d" % ["★".repeat(stars) + "☆".repeat(5 - stars), own.duplicate_count(id) + 1]
	elif known:
		info = Loc.t("SATILDI · SHOWROOM'DA GERİ AL")
	else:
		var crate: StringName = CrateCatalog.crate_of(id)
		info = "%s  ·  %s" % [Loc.t(String(CrateCatalog.get_entry(crate).get("short_name", ""))), Loc.percent(_percent(_chance(crate, id)))] if crate != &"" else Loc.t("BAŞLANGIÇ ARACI")
	if last_piece:
		info = Loc.t("SON PARÇA  ·  ") + info
	box.add_child(_label(&"HudInkCaption", info))

	if rarity == &"legendary" or last_piece:
		var pulse: Tween = create_tween().set_loops()
		pulse.tween_property(style, "border_color", color.lightened(0.45), 0.7).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(style, "border_color", color, 0.7).set_trans(Tween.TRANS_SINE)
		_pulses.append(pulse)
	return frame


func _apply_thumbnails() -> void:
	for id: StringName in _thumbs:
		var rect: TextureRect = _thumbs[id]["rect"]
		if is_instance_valid(rect) and rect.texture == null:
			rect.texture = CarGallery.cached_thumbnail(id)


static func _chance(crate: StringName, vehicle: StringName) -> float:
	for row: Dictionary in CrateCatalog.odds(crate):
		if row["id"] == vehicle:
			return float(row["chance"])
	return 0.0


## 0.0508 → "5,1"
static func _percent(chance: float) -> String:
	return Loc.decimal(chance * 100.0)


func _stop_pulses() -> void:
	for tween: Tween in _pulses:
		if tween and tween.is_valid():
			tween.kill()
	_pulses.clear()


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
