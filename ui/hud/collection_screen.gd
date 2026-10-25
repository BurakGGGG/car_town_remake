class_name CollectionScreen
extends Control
## KOLEKSİYON tabelası — edinilebilir bütün araçlar (kasalar + hurdalık klasikleri) kasalarına / restorasyon kademelerine
## göre gruplu: sahip olunanlar, keşfedilmiş ama satılmış olanlar ve henüz keşfedilmemişler (siluet). Her kartta nadirlik,
## sınıf, kasa kaynağı, o kasadaki gerçek olasılık ve kopya yıldızları. Üstte kilometre taşı şeridi (10 / 20 / 35 / 50 / 72
## araç, ödülleri), altta koleksiyon setleri (ilerleme, ödül ya da ALINDI). Ödülleri CollectionRewards öder (2026-10-25).
## Ekran TAMAMEN KODLA kurulur (.tscn yok); mantık yoktur — VehicleOwnership, CrateCatalog ve CollectionRewards okunur.
##
## Yeni görsel asset yok: siluet, aracın mevcut küçük render'ının (CarGallery önbelleği) siyaha
## boyanmış hâlidir; nadirlik çerçevesi StyleBoxFlat, Legendary'nin parlaması bir tween'dir.

signal closed

const CARD_SIZE: Vector2 = Vector2(150.0, 124.0)
const THUMB_SIZE: Vector2 = Vector2(112.0, 62.0)
## Geniş tuvalde 5 sütun; dar tuvalde (853 birim: 16:9 telefon, tablet) sığdığı kadar (en az 2) — eskiden
## sabit 5 sütun / 820 birimlik plaka ekranın sağından 44 birim taşıyordu.
const MAX_COLUMNS: int = 5
const MIN_COLUMNS: int = 2
const CARD_GAP: float = 6.0
const PLATE_WIDTH: float = 820.0
## Ekran kenarı payı (sütunun MarginContainer'ı ile aynı).
const EDGE: float = 16.0
## Restorasyon (hurdalık) kartlarının çerçevesi: pas / bakır tonu (kasa nadirlik renklerinden ayrışsın).
const RESTORATION_COLOR: Color = Color("B5652A")
## İlk açılışta hemen kurulan bölüm sayısı (kalanı kare başına bir bölüm).
const GROUPS_FIRST: int = 2
## Set satırları geniş plakada iki sütun.
const SET_COLUMNS: int = 2
const SET_ROW_MIN: float = 330.0
## Set satırının sağındaki ödül sütunu (en uzunu "+280.000").
const REWARD_COLUMN: float = 84.0

var _title: Label
var _body: PlatePanel
var _grids: Array[GridContainer] = []
var _grid_box: VBoxContainer
var _sets_box: VBoxContainer
var _sets_grid: GridContainer
var _track: _MilestoneTrack
var _column: VBoxContainer
var _thumb_host: CarGallery
var _thumbs: Dictionary = {}   # araç id → {"rect": TextureRect, "silhouette": bool}
var _pulses: Array[Tween] = []
var _closing: bool = false
## Kurulu içeriğin özeti (dil + her aracın sahiplik / yıldız / kopya / keşif durumu): değişmediyse açılışta 72 kart
## yeniden kurulmaz (ilk açılış masaüstünde ~55 ms, sonrakiler aynı işi tekrar ediyordu).
var _built_key: String = ""
## Kurulum kuşağı: kademeli eklenen bölümler eski kuruluma eklenmesin.
var _build_gen: int = 0


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
	get_viewport().size_changed.connect(_fit_width)


func open() -> void:
	var key: String = _content_key()
	if key != _built_key:
		_rebuild()
		_built_key = key
	else:
		for tween: Tween in _pulses:
			if tween and tween.is_valid():
				tween.play()
		_apply_thumbnails()
	PlateAnim.pop_in(self, _column)


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	for tween: Tween in _pulses:   # kartlar bir sonraki açılışa kalır: nabız durur, silinmez
		if tween and tween.is_valid():
			tween.pause()
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
		margin.add_theme_constant_override(side, int(EDGE))
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
	_body = body
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
	_track = _MilestoneTrack.new()
	_track.custom_minimum_size = Vector2(0.0, 52.0)
	inner.add_child(_track)
	_grid_box = VBoxContainer.new()
	_grid_box.add_theme_constant_override(&"separation", 6)
	inner.add_child(_grid_box)
	_sets_box = VBoxContainer.new()
	_sets_box.add_theme_constant_override(&"separation", 4)
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
	_grids.clear()
	for child: Node in _grid_box.get_children():
		child.queue_free()
	for child: Node in _sets_box.get_children():
		child.queue_free()
	var own: VehicleOwnership = get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	var rewards: CollectionRewards = get_tree().get_first_node_in_group("collection_rewards") as CollectionRewards
	var found: int = CollectionRewards.found_count(own)
	_title.text = Loc.t("KOLEKSİYON   %d / %d") % [found, CollectionRewards.total_count()]
	_track.setup(found, rewards)

	# Başlangıç aracı ve kasalar, kasa sırasıyla
	var groups: Array[Dictionary] = []
	var starters: Array[StringName] = []
	for id: StringName in VehicleOwnership.collection_ids():
		if CrateCatalog.crate_of(id) == &"":
			starters.append(id)
	if not starters.is_empty():
		groups.append({"title": Loc.t("BAŞLANGIÇ"), "crate": &"", "cars": starters})
	for crate: Dictionary in CrateCatalog.all():
		groups.append({"title": Loc.t(String(crate["display_name"])), "crate": crate["id"], "cars": crate["pool"]})
	# HURDALIK: restorasyon araçları ayrı bölümlerde (kasa koleksiyonu sayacına girmez), kademe sırasıyla
	for tier: Dictionary in RestorationCatalog.tiers():
		var tier_cars: Array[StringName] = []
		for entry: Dictionary in RestorationCatalog.cars(tier["id"]):
			tier_cars.append(entry["id"])
		if not tier_cars.is_empty():
			groups.append({"title": Loc.t(String(tier["name"])), "crate": &"", "cars": tier_cars})

	var last_missing: StringName = _last_missing(own)
	_build_gen += 1
	for i: int in mini(GROUPS_FIRST, groups.size()):
		_add_group(groups[i], own, last_missing)
	if groups.size() > GROUPS_FIRST:
		_add_groups_later(groups.slice(GROUPS_FIRST), own, last_missing, _build_gen)

	_sets_box.add_child(_label(&"HudPlateTitle", Loc.t("KOLEKSİYON SETLERİ")))
	_sets_grid = GridContainer.new()
	_sets_grid.add_theme_constant_override(&"h_separation", int(CARD_GAP))
	_sets_grid.add_theme_constant_override(&"v_separation", int(CARD_GAP))
	_sets_box.add_child(_sets_grid)
	for set_entry: Dictionary in CrateCatalog.sets():
		_sets_grid.add_child(_set_row(set_entry, own, rewards))
	_fit_width()
	_apply_thumbnails()


func _content_key() -> String:
	var own: VehicleOwnership = get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	if own == null:
		return ""
	var parts: PackedStringArray = [TranslationServer.get_locale()]
	var ids: Array[StringName] = VehicleOwnership.collection_ids()
	for tier: Dictionary in RestorationCatalog.tiers():
		for entry: Dictionary in RestorationCatalog.cars(tier["id"]):
			ids.append(entry["id"])
	for id: StringName in ids:
		parts.append("%d%d%d" % [int(own.is_owned(id)) + 2 * int(own.is_discovered(id)), own.stars(id), own.duplicate_count(id)])
	var rewards: CollectionRewards = get_tree().get_first_node_in_group("collection_rewards") as CollectionRewards
	if rewards:
		parts.append(JSON.stringify(rewards.state()))
	return "|".join(parts)


## İlk açılışta ilk GROUPS_FIRST bölüm hemen kurulur, kalanı kare başına bir bölüm (72 kart tek karede ~30 ms'ydi).
func _add_groups_later(groups: Array[Dictionary], own: VehicleOwnership, last_missing: StringName, gen: int) -> void:
	for group: Dictionary in groups:
		await get_tree().process_frame
		if gen != _build_gen or not is_inside_tree():
			return
		_add_group(group, own, last_missing)
		_fit_width()
		_apply_thumbnails()


func _add_group(group: Dictionary, own: VehicleOwnership, last_missing: StringName) -> void:
	var cars: Array = group["cars"]
	var have: int = 0
	for id: StringName in cars:
		if own and own.is_discovered(id):
			have += 1
	var header: Label = _label(&"HudPlateTitle", "%s   %d / %d" % [group["title"], have, cars.size()])
	_grid_box.add_child(header)
	var grid: GridContainer = GridContainer.new()
	grid.add_theme_constant_override(&"h_separation", int(CARD_GAP))
	grid.add_theme_constant_override(&"v_separation", int(CARD_GAP))
	for id: StringName in cars:
		grid.add_child(_card(id, own, id == last_missing))
	_grid_box.add_child(grid)
	_grids.append(grid)


## Plaka ve sütun sayısı kadraja göre: geniş tuvalde 820 birim / 5 sütun, dar tuvalde sığdığı kadar.
func _fit_width() -> void:
	if _body == null:
		return
	var style: StyleBox = _body.get_theme_stylebox(&"panel")
	var padding: float = style.get_minimum_size().x if style else 0.0
	var room: float = get_viewport_rect().size.x - EDGE * 2.0
	var inner: float = minf(PLATE_WIDTH, room) - padding
	var columns: int = clampi(int((inner + CARD_GAP) / (CARD_SIZE.x + CARD_GAP)), MIN_COLUMNS, MAX_COLUMNS)
	for grid: GridContainer in _grids:
		if is_instance_valid(grid):
			grid.columns = columns
	if is_instance_valid(_sets_grid):
		_sets_grid.columns = SET_COLUMNS if inner >= SET_ROW_MIN * float(SET_COLUMNS) + CARD_GAP else 1
		for row: Node in _sets_grid.get_children():
			(row as Control).custom_minimum_size.x = (inner - CARD_GAP * float(_sets_grid.columns - 1)) \
				/ float(_sets_grid.columns) - 1.0
	_body.custom_minimum_size.x = minf(PLATE_WIDTH, room)


## Koleksiyonda eksik tek araç kaldıysa o (son parça kartı öne çıkar).
func _last_missing(own: VehicleOwnership) -> StringName:
	if own == null:
		return &""
	var missing: Array[StringName] = []
	for id: StringName in VehicleOwnership.collection_ids():
		if not own.is_discovered(id):
			missing.append(id)
	return missing[0] if missing.size() == 1 else &""


func _card(id: StringName, own: VehicleOwnership, last_piece: bool) -> Control:
	var entry: Dictionary = CarCatalog.get_entry(id)
	var restoration: bool = RestorationCatalog.is_restoration(id)
	var rarity: StringName = CrateCatalog.rarity_of(id)
	var color: Color = RESTORATION_COLOR if restoration else CrateCatalog.rarity_color(rarity)
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

	var rarity_label: Label = _label(&"HudInkCaption", Loc.t("RESTORASYON  ·  %s SINIFI") % String(entry.get("class", "?"))
		if restoration else Loc.t("%s  ·  %s SINIFI") % [CrateCatalog.rarity_label(rarity), String(entry.get("class", "?"))])
	rarity_label.add_theme_color_override(&"font_color", color.darkened(0.15))
	_wrap(rarity_label)
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
	box.add_child(_wrap(_label(&"HudInkValue", name_text)))

	var info: String
	if owned:
		var stars: int = own.stars(id)
		info = Loc.t("GARAJINDA") if stars == 0 else "%s  ×%d" % ["★".repeat(stars) + "☆".repeat(5 - stars), own.duplicate_count(id) + 1]
	elif restoration:
		info = Loc.t("SATILDI · HURDALIKTA YENİDEN RESTORE ET") if known else Loc.t("HURDALIKTA RESTORE ET")
	elif known:
		info = Loc.t("SATILDI · SHOWROOM'DA GERİ AL")
	else:
		var crate: StringName = CrateCatalog.crate_of(id)
		info = "%s  ·  %s" % [Loc.t(String(CrateCatalog.get_entry(crate).get("short_name", ""))), Loc.percent(_percent(_chance(crate, id)))] if crate != &"" else Loc.t("BAŞLANGIÇ ARACI")
	if last_piece:
		info = Loc.t("SON PARÇA  ·  ") + info
	box.add_child(_wrap(_label(&"HudInkCaption", info)))

	if (rarity == &"legendary" and not restoration) or last_piece:
		var pulse: Tween = create_tween().set_loops()
		pulse.tween_property(style, "border_color", color.lightened(0.45), 0.7).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(style, "border_color", color, 0.7).set_trans(Tween.TRANS_SINE)
		_pulses.append(pulse)
	return frame


## Set satırı: ad + ilerleme, çubuk, araç adları (bilinmeyen ???), sağda ödül (₺ / GEM) ya da ALINDI.
func _set_row(set_entry: Dictionary, own: VehicleOwnership, rewards: CollectionRewards) -> Control:
	var cars: Array = set_entry["cars"]
	var have: int = 0
	var names: PackedStringArray = PackedStringArray()
	for id: StringName in cars:
		var known: bool = own != null and own.is_discovered(id)
		if known:
			have += 1
		names.append(String(CarCatalog.get_entry(id).get("display_name", id)).to_upper() if known else "???")
	var done: bool = have == cars.size()
	var paid: bool = rewards != null and rewards.is_set_paid(set_entry["id"])

	var row: PanelContainer = PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("FBF1D6") if done else Color("EADFC4")
	style.set_corner_radius_all(6)
	style.set_border_width_all(2 if done else 1)
	style.border_color = HudPalette.PLATE_SELECTED_EDGE if done else HudPalette.PLATE_EDGE
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 6.0
	row.add_theme_stylebox_override(&"panel", style)
	var line: HBoxContainer = HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override(&"separation", 8)
	row.add_child(line)

	var left: VBoxContainer = VBoxContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override(&"separation", 2)
	line.add_child(left)
	var head: Label = _label(&"HudInkValue", "%s   %d / %d" % [Loc.t(String(set_entry["name"])), have, cars.size()])
	head.clip_text = true
	head.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	left.add_child(head)
	var bar: _Bar = _Bar.new()
	bar.value = float(have) / float(maxi(cars.size(), 1))
	bar.custom_minimum_size = Vector2(0.0, 6.0)
	left.add_child(bar)
	left.add_child(_wrap(_label(&"HudInkCaption", "  ".join(names))))

	var right: VBoxContainer = VBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.custom_minimum_size.x = REWARD_COLUMN   # çubuklar her satırda aynı boyda
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override(&"separation", 1)
	line.add_child(right)
	if paid:
		var got: Label = _label(&"HudInkValue", Loc.t("✔ ALINDI"))
		got.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
		right.add_child(got)
	else:
		var reward: Dictionary = CollectionRewards.set_reward(set_entry)
		right.add_child(_amount(HudIcon.Kind.COIN, Hud.format_thousands(int(reward["money"]))))
		right.add_child(_amount(HudIcon.Kind.GEM, str(int(reward["gems"]))))
	return row


## Ödül satırı: küçük ikon + sayı.
func _amount(kind: HudIcon.Kind, text: String) -> HBoxContainer:
	var box: HBoxContainer = HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_theme_constant_override(&"separation", 3)
	var icon: HudIcon = HudIcon.new()
	icon.kind = kind
	icon.icon_size = 14.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	box.add_child(_label(&"HudInkCaption", "+" + text))
	return box


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


## Kart yazısı kartı genişletmesin (ızgarada bütün sütun genişliyor, plaka taşıyordu): sarar.
func _wrap(label: Label) -> Label:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Set ilerleme çubuğu: koyu zemin, altın dolgu.
class _Bar extends Control:
	var value: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var rect: Rect2 = Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color(HudPalette.INK, 0.18), true)
		if value > 0.0:
			draw_rect(Rect2(rect.position, Vector2(size.x * clampf(value, 0.0, 1.0), size.y)),
				HudPalette.COIN if value < 1.0 else HudPalette.COIN_DARK, true)


## KİLOMETRE TAŞLARI şeridi: 10 / 20 / 35 / 50 / 72 araç eşit aralıklı duraklar, keşfedilen sayıya göre dolan yol; durağın
## altında ödülü (+GEM, sonda KUPA) ya da alındıysa onay. Yazılar temanın yazı tipiyle çizilir.
class _MilestoneTrack extends Control:
	const RADIUS: float = 13.0
	const LINE_Y: float = 16.0
	const SIDE: float = 22.0

	var _found: int = 0
	var _counts: Array[int] = []
	var _paid: Array[bool] = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func setup(found: int, rewards: CollectionRewards) -> void:
		_found = found
		_counts = CollectionRewards.milestone_list()
		_paid.clear()
		for count: int in _counts:
			_paid.append(rewards != null and rewards.is_milestone_paid(count))
		queue_redraw()

	func _stop_x(index: int) -> float:
		return SIDE + (size.x - SIDE * 2.0) * float(index + 1) / float(_counts.size())

	func _draw() -> void:
		if _counts.is_empty():
			return
		var font: Font = get_theme_default_font()
		var start: Vector2 = Vector2(SIDE * 0.5, LINE_Y)
		var end: Vector2 = Vector2(_stop_x(_counts.size() - 1), LINE_Y)
		draw_line(start, end, Color(HudPalette.INK, 0.2), 6.0, true)
		# Dolan yol: iki durak arasında doğrusal
		var fill_x: float = start.x
		var prev_count: int = 0
		var prev_x: float = start.x
		for i: int in _counts.size():
			var x: float = _stop_x(i)
			if _found >= _counts[i]:
				fill_x = x
			else:
				if _found > prev_count:
					fill_x = lerpf(prev_x, x, float(_found - prev_count) / float(_counts[i] - prev_count))
				break
			prev_count = _counts[i]
			prev_x = x
		if fill_x > start.x:
			draw_line(start, Vector2(fill_x, LINE_Y), HudPalette.COIN, 6.0, true)
		for i: int in _counts.size():
			var center: Vector2 = Vector2(_stop_x(i), LINE_Y)
			var reached: bool = _found >= _counts[i]
			var last: bool = i == _counts.size() - 1
			var radius: float = RADIUS + (3.0 if last else 0.0)
			draw_circle(center + Vector2(0.0, 2.0), radius, HudPalette.SHADOW, true, -1.0, true)
			draw_circle(center, radius, HudPalette.INK, true, -1.0, true)
			draw_circle(center, radius - 2.5, HudPalette.COIN if reached else HudPalette.PLATE, true, -1.0, true)
			var number: String = str(_counts[i])
			var number_size: int = 12
			var text_w: float = font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, number_size).x
			draw_string(font, center + Vector2(-text_w * 0.5, number_size * 0.36), number, HORIZONTAL_ALIGNMENT_LEFT, -1,
				number_size, HudPalette.INK)
			var caption: String
			if _paid[i]:
				caption = Loc.t("✔ ALINDI")
			elif last:
				caption = Loc.t("KUPA + %d GEM") % int(CollectionRewards.MILESTONES[_counts[i]])
			else:
				caption = Loc.t("+%d GEM") % int(CollectionRewards.MILESTONES[_counts[i]])
			var caption_w: float = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
			var caption_x: float = clampf(center.x - caption_w * 0.5, 0.0, maxf(size.x - caption_w, 0.0))
			draw_string(font, Vector2(caption_x, LINE_Y + radius + 14.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
				HudPalette.COIN_DARK if _paid[i] else HudPalette.INK_SOFT)
