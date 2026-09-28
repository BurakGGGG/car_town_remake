class_name DecorPanel
extends VBoxContainer
## AVLUYU DÜZENLE panosu — dünyada avluya dokununca açılan HUD panosu.
## Tamamen kodla kurulur (garaj/showroom ile aynı dil). Katalog GarageDecor'dan, satın alma
## DecorManager'dan geçer; bu pano ücret hesaplamaz, yalnızca gösterir.
##
## Etkileşim tek dokunuşluk: eşya SAHİP DEĞİLSE dokunmak SATIN ALIR, sahipse GARAJA KOYAR /
## GARAJDAN KALDIRIR. Yuva seçtirmiyoruz (sabit yuvalar, uygun ilk boş yuvaya oturur) —
## mobilde iki aşamalı yerleştirme arayüzü gereksiz sürtünme.

signal closed

const WIDTH: float = 214.0
const ROW_HEIGHT: float = 34.0
## Kadraj kenarına bırakılan pay.
const MARGIN: float = 22.0

var _decor: DecorManager
var _economy: EconomyManager
var _rows: Dictionary = {}          # eşya id → {button, title, state}
var _title_label: Label
var _summary_label: Label


func _ready() -> void:
	name = "DecorPanel"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", 8)
	_build()
	_connect_managers.call_deferred()


func open() -> void:
	show()
	refresh()
	_place.call_deferred()


## Pano sağ kenara, dikey ortalı oturur. (Anchor preset'i minimum boy hesaplanmadan çalışıp
## panoyu kadrajın dışına itiyordu — garaj şeridiyle aynı tuzak.)
func _place() -> void:
	var area: Vector2 = get_parent_area_size()
	if area.x <= 0.0:
		return
	var wanted: Vector2 = get_combined_minimum_size()
	set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	offset_left = area.x - wanted.x - MARGIN
	offset_top = maxf((area.y - wanted.y) * 0.5, MARGIN)
	offset_right = area.x - MARGIN
	offset_bottom = offset_top + wanted.y


func close() -> void:
	hide()
	closed.emit()


func _connect_managers() -> void:
	_decor = get_tree().get_first_node_in_group("decor") as DecorManager
	_economy = get_tree().get_first_node_in_group("economy") as EconomyManager
	if _decor and not _decor.placement_changed.is_connected(refresh):
		_decor.placement_changed.connect(refresh)
	if _economy and not _economy.money_changed.is_connected(_on_money_changed):
		_economy.money_changed.connect(_on_money_changed)
	refresh()


func _on_money_changed(_amount: int) -> void:
	refresh()


func _build() -> void:
	var plate: PlatePanel = PlatePanel.new()
	plate.theme_type_variation = &"HudCarPlate"
	plate.custom_minimum_size = Vector2(WIDTH, 0.0)
	add_child(plate)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 2)
	plate.add_child(column)

	_title_label = _label(&"HudInkTitle", "AVLUYU DÜZENLE")
	column.add_child(_title_label)
	_summary_label = _label(&"HudInkSmall", "")
	column.add_child(_summary_label)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.custom_minimum_size = Vector2(WIDTH - 18.0, 318.0)
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override(&"separation", 3)
	scroll.add_child(list)

	var last_kind: int = -1
	for item: Dictionary in GarageDecor.all():
		var kind: int = int(item["kind"])
		if kind != last_kind:
			last_kind = kind
			var header: Label = _label(&"HudInkSmall", GarageDecor.kind_title(kind))
			header.add_theme_constant_override(&"line_spacing", 0)
			list.add_child(header)
		_add_row(list, item)

	var back: PlateButton = PlateButton.new()
	back.theme_type_variation = &"HudPlate"
	back.kind = HudIcon.Kind.NONE
	back.text = "GERİ"
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(close)
	add_child(back)


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label


func _add_row(list: VBoxContainer, item: Dictionary) -> void:
	var button: PlateButton = PlateButton.new()
	button.theme_type_variation = &"HudPlate"
	button.kind = HudIcon.Kind.NONE
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_on_row_pressed.bind(StringName(item["id"])))
	list.add_child(button)
	_rows[StringName(item["id"])] = button


## Tek dokunuş: sahip değilse satın al, sahipse garaja koy / garajdan kaldır.
func _on_row_pressed(id: StringName) -> void:
	if _decor == null:
		return
	if not _decor.is_owned(id):
		_decor.purchase(id)
		return
	if _decor.is_placed(id):
		for slot: StringName in _decor.placements():
			if _decor.item_at(slot) == id:
				_decor.clear_slot(slot)
				return
	else:
		var kind: StringName = GarageDecor.slot_kind(id)
		var open: Array[StringName] = _decor.open_slots()
		for slot: StringName in open:
			if GarageDecor.slot_of(slot) == kind and _decor.item_at(slot) == &"":
				_decor.place(slot, id)
				return
		# Açık yuvaların hepsi dolu: ilkini bu eşyayla değiştir (oyuncu "koy" demiş oluyor)
		for slot: StringName in open:
			if GarageDecor.slot_of(slot) == kind:
				_decor.place(slot, id)
				return


func refresh() -> void:
	if _decor == null or _rows.is_empty():
		return
	var owned: int = _decor.owned_count()
	var open_count: int = 0
	for slot: StringName in _decor.open_slots():
		if GarageDecor.slot_of(slot) == GarageDecor.SLOT_FLOOR:
			open_count += 1
	_summary_label.text = "%d / %d eşya  ·  %d avlu yeri  ·  +%s ₺" % [owned,
		GarageDecor.all().size(), open_count, Hud.format_thousands(_decor.value())]
	for item: Dictionary in GarageDecor.all():
		var id: StringName = item["id"]
		var button: PlateButton = _rows[id]
		var title: String = String(item["title"])
		if not _decor.is_owned(id):
			if not _decor.is_unlocked(id):
				button.text = "%s\n%d. RÜTBE GEREKLİ" % [title, int(item["min_rank"])]
				button.disabled = true
			else:
				var affordable: bool = _economy == null or _economy.can_afford(int(item["price"]))
				button.text = "%s\n%s ₺" % [title, Hud.format_thousands(int(item["price"]))]
				button.disabled = not affordable
				if not affordable:
					button.text = "%s\n%s ₺ · PARA YETERSİZ" % [title,
						Hud.format_thousands(int(item["price"]))]
		else:
			button.disabled = false
			button.text = "%s\n%s" % [title, "GARAJDA · KALDIR" if _decor.is_placed(id) else "DEPODA · KOY"]
		button.highlight = _decor.is_owned(id) and _decor.is_placed(id)
