class_name GarageEditScreen
extends Control
## GARAJI DÜZENLE — düzenleme modunun arayüzü (dünya tarafı: world/garage_editor.gd).
##
## Router'a YER (PLACE) olarak kayıtlıdır: açılınca oyun HUD'u gizlenir (alt sekmeler, görevler,
## profil yanlışlıkla açılmasın), ESC / BİTİR normal oyuna döndürür. Ekran TAM ÇERÇEVEDİR ama
## kendisi tıklama almaz (mouse_filter IGNORE): yalnızca plakaları alır, geri kalan dokunuşlar
## garaja (düzenleyiciye) gider — garaj görünür kalır, ayrı bir önizleme sahnesi yoktur.
##
## Düzen (fiziksel plakalar, ekranı kaplamadan):
##   üst orta  : GARAJI DÜZENLE başlığı + tek satır bilgi
##   sağ üst   : IZGARA · GERİ AL · BİTİR
##   alt       : kategori sekmeleri, altında eşya şeridi (depo adedi / fiyat / rütbe kilidi);
##               açık sekmeye yeniden dokunmak şeridi katlar, garajın tamamı görünür
##   alt üstü  : seçim / hayalet denetim çubuğu (döndür · depoya kaldır / yerleştir · vazgeç);
##               araç açıkken araç çubuğu (zemin: fırça · dikdörtgen · kova · damlalık · silgi,
##               duvar: ör · sök)
## Kategoriler katalogdaki GERÇEK türlerden gelir (GarageDecor.categories()).
## Dekorasyon v2: ZEMİN sekmesinde desen kartına dokunmak boyama aracını, DUVAR ÖR'de parça kartı
## örme aracını, DUVAR KAPLAMASI'nda kaplama kartı kaplama aracını açar; başka sekmeye geçmek eşya
## düzenine döndürür.

signal closed

const MARGIN: float = 14.0
## Garajdaki araç şeridinin plakasıyla aynı genişlik (104 birimde KOMPRESÖR kelime ortasından kırılıyordu).
const CARD_WIDTH: float = 124.0
const THUMB_TOP: float = 8.0
const THUMB_AREA: Vector2 = Vector2(108.0, 60.0)
## Denetim / araç çubuğu için kamera bandında ayrılan yükseklik (plaka satırı + aralık).
const BAR_RESERVE: float = 58.0

var _editor: GarageEditor
var _decor: DecorManager
var _economy: EconomyManager
var _thumbs: DecorThumbs

var _top: VBoxContainer
var _bottom: VBoxContainer
var _title: Label
var _info: Label
var _notice: Label
var _notice_tween: Tween
var _snap_button: PlateButton
var _undo_button: PlateButton
var _done_button: PlateButton
var _tabs: HBoxContainer
var _tab_scroll: ScrollContainer
var _tab_group: ButtonGroup = ButtonGroup.new()
var _tab_buttons: Dictionary = {}   # kind → PlateButton
var _strip_panel: PlatePanel
var _strip: HBoxContainer
var _scroll: ScrollContainer
var _cards: Dictionary = {}         # id → PlateButton
var _kind: int = -1
var _confirm_buy: StringName = &""  # iki dokunuşlu satın alma: ilk dokunuş fiyatı sorar

var _bar: HBoxContainer
var _rot_left: PlateButton
var _rot_right: PlateButton
var _delete_button: PlateButton
var _place_button: PlateButton
var _cancel_button: PlateButton
## Araç çubuğu düğmeleri: kip → PlateButton (zemin ve duvar kipleri).
var _tool_buttons: Dictionary = {}


func _ready() -> void:
	name = "GarageEditScreen"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_thumbs = DecorThumbs.new()
	add_child(_thumbs)
	_thumbs.ready_for.connect(_on_thumb_ready)
	_build()


# --- Aç / kapa ---------------------------------------------------------------------------

func open() -> void:
	_bind()
	visible = true
	if _kind < 0 or not _tab_buttons.has(_kind):
		_kind = _first_useful_kind()
	_select_tab(_kind)   # önce şerit dolsun: bandın alt sınırı kartların yüksekliğine bağlı
	if _editor:
		_editor.activate(_view_band())
	_refresh()


func close() -> void:
	if not visible:
		return
	if _editor:
		_editor.deactivate()
	visible = false
	_confirm_buy = &""
	closed.emit()


func _bind() -> void:
	if _editor == null:
		_editor = get_tree().get_first_node_in_group("garage_editor") as GarageEditor
		if _editor:
			_editor.state_changed.connect(_refresh)
			_editor.tool_changed.connect(_refresh_cards)
			_editor.selection_changed.connect(func(_iid: String) -> void: _refresh())
			_editor.placing_changed.connect(func(_item: StringName) -> void: _refresh())
			_editor.notice.connect(_show_notice)
	if _decor == null:
		_decor = get_tree().get_first_node_in_group("decor") as DecorManager
		if _decor:
			_decor.placement_changed.connect(_refresh_cards)
			_decor.purchase_failed.connect(func(_id: StringName, _p: int) -> void: _show_notice("PARA YETERSİZ"))
	if _economy == null:
		_economy = get_tree().get_first_node_in_group("economy") as EconomyManager
		if _economy:
			_economy.money_changed.connect(func(_m: int) -> void: _refresh_cards())


## Eğitim spot ışığının gösterdiği parçalar: &"bottom" (sekmeler + eşya şeridi), &"strip" (eşya
## şeridi), &"tabs" (kategori sekmeleri), &"place" (YERLEŞTİR), &"done" (BİTİR).
func tutorial_anchor(id: StringName) -> Control:
	match id:
		&"bottom":
			return _bottom
		&"strip":
			return _strip_panel
		&"tabs":
			return _tab_scroll
		&"place":
			return _place_button if _place_button.is_visible_in_tree() else null
		&"done":
			return _done_button
	return null


# --- Kurulum -----------------------------------------------------------------------------

func _build() -> void:
	# Üst orta: başlık + bilgi + bildirim
	var top: VBoxContainer = VBoxContainer.new()
	_top = top
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.offset_top = MARGIN
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	top.add_theme_constant_override(&"separation", 4)
	add_child(top)
	var title_plate: PlatePanel = PlatePanel.new()
	title_plate.theme_type_variation = &"HudCarPlate"
	title_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top.add_child(title_plate)
	_title = _label(&"HudPlateTitle", Loc.t("GARAJI DÜZENLE"))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_plate.add_child(_title)
	_info = _label(&"HudOutlined", "")
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_info)
	_notice = _label(&"HudOutlined", "")
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.modulate.a = 0.0
	top.add_child(_notice)

	# Sağ üst: ızgara · geri al · bitir
	var corner: HBoxContainer = HBoxContainer.new()
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corner.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	corner.offset_top = MARGIN
	corner.offset_right = -MARGIN
	corner.add_theme_constant_override(&"separation", 8)
	add_child(corner)
	_snap_button = _plate(Loc.t("IZGARA"), &"HudPlateSmall")
	_snap_button.toggle_mode = true
	_snap_button.button_pressed = true
	_snap_button.toggled.connect(func(on: bool) -> void:
		if _editor:
			_editor.set_snap(on))
	corner.add_child(_snap_button)
	_undo_button = _plate(Loc.t("GERİ AL"), &"HudPlateSmall")
	_undo_button.pressed.connect(func() -> void:
		if _editor:
			_editor.undo())
	corner.add_child(_undo_button)
	_done_button = _plate(Loc.t("BİTİR"), &"HudPlate")
	_done_button.highlight = true
	_done_button.pressed.connect(close)
	corner.add_child(_done_button)

	# Alt: sekmeler + eşya şeridi
	var bottom: VBoxContainer = VBoxContainer.new()
	_bottom = bottom
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_left = MARGIN
	bottom.offset_right = -MARGIN
	bottom.offset_bottom = -MARGIN * 0.5
	bottom.add_theme_constant_override(&"separation", 4)
	add_child(bottom)
	# Seçim / hayalet denetim çubuğu: sekmelerin hemen üstünde, ortada. Önce seçili eşyanın
	# üstünde yüzüyordu ama yakındaki eşyaları örtüyordu — gerçek oynanış testinde sehpaya dokunmak
	# isteyen dokunuş, komşu tabelanın çubuğundaki DEPOYA KALDIR'a gitti. Kamera garajı ekranın üst
	# kısmına sığdırdığı için bu bant hiçbir eşyanın üstüne binmez ve başparmağın ulaştığı yerdedir.
	# Alt grup aşağıdan yukarı büyüdüğü için çubuk açılıp kapanınca sekmeler yerinden oynamaz.
	var bar_row: MarginContainer = MarginContainer.new()
	bar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bar_row.add_theme_constant_override(&"margin_bottom", 6)
	bottom.add_child(bar_row)
	_bar = HBoxContainer.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_theme_constant_override(&"separation", 6)
	_bar.visible = false
	bar_row.add_child(_bar)
	# Sekmeler kayan şeritte: dekorasyon v2 ile 9 sekme oldu, telefonda (770 birim genişlik) sığmıyordu
	var tab_scroll: ScrollContainer = ScrollContainer.new()
	tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	bottom.add_child(tab_scroll)
	TouchScroll.attach(tab_scroll)
	_tabs = HBoxContainer.new()
	_tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tabs.add_theme_constant_override(&"separation", 6)
	tab_scroll.add_child(_tabs)
	_tab_scroll = tab_scroll
	_strip_panel = PlatePanel.new()
	_strip_panel.theme_type_variation = &"HudCarPlate"
	# Şeritteki dokunuş dünyaya sızmasın (kamera kaymasın, arkadaki eşya seçilmesin): kartlar
	# PASS olduğu için olay buraya kadar çıkar ve burada durur.
	_strip_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	bottom.add_child(_strip_panel)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_strip_panel.add_child(_scroll)
	TouchScroll.attach(_scroll, true)   # kaydırınca akar, bırakınca en yakın eşya kartına oturur
	_strip = HBoxContainer.new()
	_strip.add_theme_constant_override(&"separation", 6)
	_scroll.add_child(_strip)
	for kind: int in GarageDecor.categories():
		var tab: PlateButton = _plate(GarageDecor.kind_title(kind), &"HudPlateSmall")
		tab.toggle_mode = true
		tab.button_group = _tab_group
		tab.pressed.connect(_on_tab_pressed.bind(kind))
		_tabs.add_child(tab)
		_tab_buttons[kind] = tab
	# SERGİ sekmesi: sahip olunan araçlar (katalogda değil, VehicleOwnership'ten gelir)
	var car_tab: PlateButton = _plate(Loc.t("ARAÇLAR"), &"HudPlateSmall")
	car_tab.toggle_mode = true
	car_tab.button_group = _tab_group
	car_tab.pressed.connect(_on_tab_pressed.bind(GarageDecor.Kind.VEHICLE))
	_tabs.add_child(car_tab)
	_tab_buttons[GarageDecor.Kind.VEHICLE] = car_tab

	_rot_left = _sign_button(true)
	_rot_left.pressed.connect(func() -> void:
		if _editor:
			_editor.rotate_selected(-1))
	_bar.add_child(_rot_left)
	_rot_right = _sign_button(false)
	_rot_right.pressed.connect(func() -> void:
		if _editor:
			_editor.rotate_selected(1))
	_bar.add_child(_rot_right)
	_place_button = _plate(Loc.t("YERLEŞTİR"), &"HudPlateSmall")
	_place_button.highlight = true
	_place_button.pressed.connect(func() -> void:
		if _editor:
			_editor.confirm_ghost())
	_bar.add_child(_place_button)
	_cancel_button = _plate(Loc.t("VAZGEÇ"), &"HudPlateSmall")
	_cancel_button.pressed.connect(func() -> void:
		if _editor:
			_editor.cancel_ghost())
	_bar.add_child(_cancel_button)
	_delete_button = _plate(Loc.t("DEPOYA KALDIR"), &"HudPlateSmall")
	_delete_button.pressed.connect(func() -> void:
		if _editor:
			_editor.delete_selected())
	_bar.add_child(_delete_button)
	# Araç çubuğu: aynı satırda, araç açıkken eşya düğmelerinin yerine görünür
	var modes: Array = [[&"brush", "FIRÇA"], [&"rect", "DİKDÖRTGEN"], [&"fill", "KOVA"], [&"pick", "DAMLALIK"],
		[&"erase", "SİLGİ"], [&"build", "ÖR"], [&"remove", "SÖK"]]
	for pair: Array in modes:
		var mode: StringName = pair[0]
		var button: PlateButton = _plate(Loc.t(String(pair[1])), &"HudPlateSmall")
		button.toggle_mode = true
		button.pressed.connect(_on_tool_mode.bind(mode))
		_bar.add_child(button)
		_tool_buttons[mode] = button


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _plate(text: String, variation: StringName) -> PlateButton:
	var button: PlateButton = PlateButton.new()
	button.theme_type_variation = variation
	button.kind = HudIcon.Kind.NONE
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	return button


## Yuvarlak döndürme tabelası; sola dönen ikon aynalanır (ikon setinde tek yönlü DÖNDÜR var).
func _sign_button(left: bool) -> PlateButton:
	var button: PlateButton = PlateButton.new()
	button.theme_type_variation = &"HudSign"
	button.shape = PlateButton.Shape.ROUND
	button.kind = HudIcon.Kind.NONE
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(48.0, 48.0)
	button.tooltip_text = Loc.t("SOLA DÖNDÜR (Shift+R)") if left else Loc.t("SAĞA DÖNDÜR (R)")
	button.draw.connect(func() -> void:
		var ink: Color = button.get_theme_color(&"font_color")
		var center: Vector2 = button.size * 0.5
		button.draw_set_transform(center, 0.0, Vector2(-1.0 if left else 1.0, 1.0))
		HudIcon.draw_icon(button, HudIcon.Kind.ROTATE, Vector2.ZERO, 24.0, ink, Color(0.0, 0.0, 0.0, 0.0))
		button.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE))
	return button


# --- Sekmeler ve kartlar -----------------------------------------------------------------

func _first_useful_kind() -> int:
	# Oyuncunun deposunda bir eşya varsa onun kategorisi; yoksa ilk EŞYA kategorisi (zemin / duvar /
	# kaplama araç sekmeleri açılışta seçilmez: düzenleyici eşya düzeninde açılır)
	if _decor:
		for kind: int in GarageDecor.categories():
			for item: Dictionary in GarageDecor.items_in(kind):
				if GarageDecor.is_placeable(item["id"]) and _decor.available_of(item["id"]) > 0:
					return kind
	for kind: int in GarageDecor.categories():
		if not _is_tool_kind(kind):
			return kind
	return GarageDecor.categories()[0]


static func _is_tool_kind(kind: int) -> bool:
	return kind == GarageDecor.Kind.FLOOR_PATTERN or kind == GarageDecor.Kind.WALL_PIECE \
		or kind == GarageDecor.Kind.FLOOR_SURFACE or kind == GarageDecor.Kind.WALL_SURFACE


func _on_tab_pressed(kind: int) -> void:
	if kind == _kind and _strip_panel.visible:
		# Açık sekmeye yeniden dokunmak şeridi katlar: garaj açılan boşluğa yeniden sığdırılır (telefonda
		# boyarken / duvar örerken garaj büyür; desen değiştirmek için sekmeye yeniden dokunulur)
		_strip_panel.visible = false
		_tab_buttons[kind].set_pressed_no_signal(false)
		_reframe_later()
		return
	var was_hidden: bool = not _strip_panel.visible
	_select_tab(kind)
	if was_hidden:
		_reframe_later()


## Düzen oturduktan sonra (bir kare) kamera bandı yeniden ölçülür.
func _reframe_later() -> void:
	if _editor == null:
		return
	await get_tree().process_frame
	if visible:
		_editor.reframe(_view_band())


func _select_tab(kind: int) -> void:
	if _editor and _kind != kind:
		_editor.end_tool()   # başka sekme: eşya düzenine dönülür (araç kartına dokununca yeniden açılır)
	_kind = kind
	_confirm_buy = &""
	_strip_panel.visible = true
	for k: int in _tab_buttons:
		(_tab_buttons[k] as PlateButton).set_pressed_no_signal(k == kind)
	if _tab_scroll and _tab_buttons.has(kind) and is_inside_tree():
		_tab_scroll.ensure_control_visible.call_deferred(_tab_buttons[kind])
	for child: Node in _strip.get_children():
		child.queue_free()
	_cards.clear()
	if kind == GarageDecor.Kind.FLOOR_SURFACE or kind == GarageDecor.Kind.WALL_SURFACE:
		_add_card(&"")   # varsayılan kaplamaya dönüş (duvar kaplaması: kaplamasız duvar)
	if kind == GarageDecor.Kind.VEHICLE:
		var ownership: VehicleOwnership = get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership
		if ownership:
			for vehicle: StringName in ownership.owned_vehicle_ids():
				_add_card(GarageDecor.vehicle_item_id(vehicle))
	else:
		for item: Dictionary in GarageDecor.items_in(kind):
			_add_card(item["id"])
	_scroll.scroll_horizontal = 0
	_refresh_cards()


## Kart: üstte küçük resim, altta ad + durum. id "" = kaplamada VARSAYILAN.
func _add_card(id: StringName) -> void:
	var card: PlateButton = PlateButton.new()
	card.theme_type_variation = &"HudGalleryPlate"
	card.kind = HudIcon.Kind.NONE
	card.bolts = false
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0.0)
	card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# PASS: parmakla sürükleme kaydırma kabına ulaşsın. STOP'ta şerit parmakla hiç kaymıyordu
	# (ölçüldü: 12 kartlık şeritte 240 birim sürükleme → STOP 0, PASS 884 kaydırma); kaydırma
	# başlayınca kabın gönderdiği NOTIFICATION_SCROLL_BEGIN kartın basışını iptal eder, yani
	# kaydırırken yanlışlıkla satın alma olmaz. Kısa dokunuş yine kartı basar.
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.draw.connect(_draw_card.bind(card, id))
	card.pressed.connect(_on_card_pressed.bind(id))
	_strip.add_child(card)
	_cards[id] = card


func _draw_card(card: PlateButton, id: StringName) -> void:
	var area: Rect2 = Rect2(Vector2((card.size.x - THUMB_AREA.x) * 0.5, THUMB_TOP), THUMB_AREA)
	if id == &"":
		var ink: Color = Color(card.get_theme_color(&"font_color"), 0.35)
		card.draw_rect(area.grow(-10.0), ink, false, 2.0, true)
		return
	if GarageDecor.is_pattern(id) or GarageDecor.is_surface(id):
		# Desen / kaplama: dokunun kendisinden kare önizleme (3B küçük resim yok)
		var side: float = minf(area.size.x, area.size.y) - 6.0
		var sw: Rect2 = Rect2(area.get_center() - Vector2(side, side) * 0.5, Vector2(side, side))
		card.draw_texture_rect(DecorTextures.swatch(id), sw, false)
		card.draw_rect(sw, Color(card.get_theme_color(&"font_color"), 0.45), false, 1.5, true)
		return
	var texture: Texture2D = DecorThumbs.cached(id)
	if texture:
		var s: Vector2 = texture.get_size()
		var k: float = minf(area.size.x / s.x, area.size.y / s.y)
		var drawn: Vector2 = s * k
		card.draw_texture_rect(texture, Rect2(area.get_center() - drawn * 0.5, drawn), false)
	else:
		card.draw_rect(area.grow(-14.0), Color(card.get_theme_color(&"font_color"), 0.12), true)
		_thumbs.request(id)


func _on_thumb_ready(id: StringName) -> void:
	var card: PlateButton = _cards.get(id)
	if card and is_instance_valid(card):
		card.queue_redraw()


func _on_card_pressed(id: StringName) -> void:
	if _editor == null or _decor == null:
		return
	if GarageDecor.is_pattern(id):
		if not _decor.is_unlocked(id):
			_show_notice(Loc.t("%d. RÜTBEDE AÇILIR") % int(GarageDecor.get_item(id).get("min_rank", 1)))
			return
		_editor.begin_paint(id)
		_refresh_cards()
		return
	if GarageDecor.is_wall_piece(id):
		if not _decor.is_unlocked(id):
			_show_notice(Loc.t("%d. RÜTBEDE AÇILIR") % int(GarageDecor.get_item(id).get("min_rank", 1)))
			return
		_editor.begin_walls(id)
		_refresh_cards()
		return
	if _kind == GarageDecor.Kind.WALL_SURFACE and (id == &"" or GarageDecor.is_surface(id)):
		# Duvar kaplaması: sahipse (ya da varsayılansa) kaplama aracı açılır, değilse iki dokunuşta alınır
		if id == &"" or _decor.is_owned(id) or _buy(id):
			_confirm_buy = &""
			_editor.begin_finish(id)
		_refresh_cards()
		return
	# Kaplama: sahipse uygula, değilse iki dokunuşta satın al + uygula
	if id == &"" or GarageDecor.is_surface(id):
		var slot: StringName = DecorManager.SURFACE_FLOOR if _kind == GarageDecor.Kind.FLOOR_SURFACE \
				else DecorManager.SURFACE_WALL
		if id == &"" or _decor.is_owned(id):
			_editor.apply_surface(slot, id)
			_confirm_buy = &""
		elif _buy(id):
			_editor.apply_surface(slot, id)
		_refresh_cards()
		return
	if GarageDecor.is_vehicle(id):
		if _decor.available_of(id) > 0:
			_editor.begin_place(id)
		else:
			_show_notice(Loc.t("ZATEN SERGİLENİYOR — GARAJDAN SEÇİP TAŞI"))
		return
	if _decor.available_of(id) > 0:
		_confirm_buy = &""
		_editor.begin_place(id)
	elif _buy(id):
		_editor.begin_place(id)
	_refresh_cards()


## İki dokunuşlu satın alma: ilk dokunuş kartı "SATIN AL?" durumuna getirir, ikincisi alır.
## (Tek dokunuşta alım, 120.000 ₺'lik bayrak direğini kazayla aldırıyordu.)
func _buy(id: StringName) -> bool:
	if not _decor.can_purchase(id):
		if not _decor.is_unlocked(id):
			_show_notice(Loc.t("%d. RÜTBEDE AÇILIR") % int(GarageDecor.get_item(id).get("min_rank", 1)))
		elif GarageDecor.is_surface(id) and _decor.is_owned(id):
			pass
		else:
			_show_notice(Loc.t("PARA YETERSİZ"))
		return false
	if _confirm_buy != id:
		_confirm_buy = id
		_show_notice(Loc.t("SATIN ALMAK İÇİN TEKRAR DOKUN"))
		return false
	_confirm_buy = &""
	return _decor.purchase(id)


func _refresh_cards() -> void:
	if _decor == null:
		return
	for id: StringName in _cards:
		var card: PlateButton = _cards[id]
		if not is_instance_valid(card):
			continue
		if id == &"":
			card.text = Loc.t("VARSAYILAN")
			card.button_pressed = _editor != null and _editor.tool == GarageEditor.Tool.FINISH and _editor.finish_id == &""
			card.disabled = false
			continue
		var item: Dictionary = GarageDecor.get_item(id)
		var title: String = Loc.t(String(item.get("title", id)))
		var status: String
		if GarageDecor.is_pattern(id):
			status = _price_status(id) if not _decor.is_unlocked(id) \
				else Loc.t("%s ₺ / KARO") % Hud.format_thousands(_decor.price_of(id))
			card.text = "%s\n%s" % [title, status]
			_fit_card(card)
			card.disabled = not _decor.is_unlocked(id)
			card.button_pressed = _editor != null and _editor.tool == GarageEditor.Tool.PAINT \
				and _editor.paint_pattern == id and _editor.paint_mode != &"erase"
			card.queue_redraw()
			continue
		if GarageDecor.is_wall_piece(id):
			status = Loc.t("DEPODA %d") % _decor.available_of(id) if _decor.available_of(id) > 0 \
				else _price_status(id)
			card.text = "%s\n%s" % [title, status]
			_fit_card(card)
			card.disabled = not _decor.is_unlocked(id)
			card.button_pressed = _editor != null and _editor.tool == GarageEditor.Tool.WALL \
				and _editor.wall_piece == id and _editor.wall_mode == &"build"
			card.queue_redraw()
			continue
		if GarageDecor.is_surface(id) and _kind == GarageDecor.Kind.WALL_SURFACE:
			if _decor.is_owned(id):
				status = Loc.t("DIŞ DUVARDA") if _decor.surface(DecorManager.SURFACE_WALL) == id else Loc.t("SAHİPSİN")
			else:
				status = _price_status(id)
			if _confirm_buy == id:
				status = Loc.t("SATIN AL? %s ₺") % Hud.format_thousands(_decor.price_of(id))
			card.text = "%s\n%s" % [title, status]
			_fit_card(card)
			card.disabled = not _decor.is_unlocked(id)
			card.button_pressed = _confirm_buy == id or (_editor != null \
				and _editor.tool == GarageEditor.Tool.FINISH and _editor.finish_id == id)
			card.queue_redraw()
			continue
		if GarageDecor.is_vehicle(id):
			card.text = "%s\n%s" % [title, Loc.t("SERGİLE") if _decor.available_of(id) > 0 else Loc.t("SERGİLENİYOR")]
			_fit_card(card)
			card.disabled = false
			card.queue_redraw()
			continue
		if GarageDecor.is_surface(id):
			var slot2: StringName = DecorManager.surface_slot_of(id)
			if _decor.is_owned(id):
				status = Loc.t("KULLANILIYOR") if _decor.surface(slot2) == id else Loc.t("UYGULA")
			else:
				status = _price_status(id)
		elif _decor.available_of(id) > 0:
			status = Loc.t("DEPODA %d") % _decor.available_of(id)
		else:
			status = _price_status(id)
		if _confirm_buy == id:
			status = Loc.t("SATIN AL? %s ₺") % Hud.format_thousands(_decor.price_of(id))
		card.text = "%s\n%s" % [title, status]
		_fit_card(card)
		card.disabled = not _decor.is_unlocked(id)
		card.button_pressed = _confirm_buy == id or (GarageDecor.is_surface(id) \
				and _decor.surface(DecorManager.surface_slot_of(id)) == id)
		card.queue_redraw()


## Kart, en uzun SÖZCÜĞÜ bölmeden sığacak kadar genişler (İspanyolca "HERRAMIENTAS" gibi uzun sözcükler
## dar kartta harf harf bölünüyordu). Türkçe adlar zaten sığar: kart genişliği değişmez.
func _fit_card(card: PlateButton) -> void:
	var font: Font = card.get_theme_font(&"font")
	var size: int = card.get_theme_font_size(&"font_size")
	var widest: float = 0.0
	for word: String in card.text.replace("\n", " ").split(" ", false):
		widest = maxf(widest, font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	var margin: float = 24.0
	card.custom_minimum_size.x = maxf(CARD_WIDTH, ceilf(widest + margin))


func _price_status(id: StringName) -> String:
	if not _decor.is_unlocked(id):
		return Loc.t("%d. RÜTBE") % int(GarageDecor.get_item(id).get("min_rank", 1))
	return "%s ₺" % Hud.format_thousands(_decor.price_of(id))


# --- Durum ---------------------------------------------------------------------------------

func _refresh() -> void:
	if not visible or _editor == null:
		return
	_undo_button.disabled = not _editor.can_undo()
	_snap_button.set_pressed_no_signal(_editor.snap_enabled)
	if _editor.tool != GarageEditor.Tool.OBJECT:
		_refresh_tool()
		_refresh_cards()
		return
	for mode: StringName in _tool_buttons:
		(_tool_buttons[mode] as PlateButton).visible = false
	var placing: bool = _editor.is_placing()
	var selected: String = _editor.selected()
	var wall: bool = false
	if placing:
		var item: StringName = _editor.placing_item()
		wall = GarageDecor.placement(item) == GarageDecor.PLACE_WALL
		_info.text = Loc.t("%s · SÜRÜKLE, BIRAKINCA YERLEŞİR") % Loc.t(String(GarageDecor.get_item(item).get("title", "")))
		_place_button.disabled = not _editor.ghost_valid()
	elif _editor.selected_is_bay():
		_info.text = Loc.t("TAMİR ALANI %d · SÜRÜKLE: TAŞI, ↻: DÖNDÜR") % (GarageDecorView.bay_index_of(selected) + 1)
	elif selected != "":
		var inst: Dictionary = _decor.instance(selected)
		var item2: StringName = inst.get("item", &"")
		wall = GarageDecor.placement(item2) == GarageDecor.PLACE_WALL
		_info.text = Loc.t("%s · SÜRÜKLE: TAŞI") % Loc.t(String(GarageDecor.get_item(item2).get("title", "")))
	else:
		_info.text = Loc.t("EŞYAYA DOKUN: SEÇ  ·  AŞAĞIDAN EŞYA SEÇ: EKLE")
	_rot_left.visible = not wall
	_rot_right.visible = not wall
	_place_button.visible = placing
	_cancel_button.visible = placing
	_delete_button.visible = not placing and selected != "" and not _editor.selected_is_bay()
	_bar.visible = placing or selected != ""
	_refresh_cards()


## Araç açıkken: bilgi satırı ve araç çubuğu (eşya düğmeleri gizli).
func _refresh_tool() -> void:
	for button: PlateButton in [_rot_left, _rot_right, _place_button, _cancel_button, _delete_button]:
		button.visible = false
	var paint: bool = _editor.tool == GarageEditor.Tool.PAINT
	var wall: bool = _editor.tool == GarageEditor.Tool.WALL
	for mode: StringName in _tool_buttons:
		var button: PlateButton = _tool_buttons[mode]
		var visible_now: bool = (paint and GarageEditor.PAINT_MODES.has(mode)) or (wall and GarageEditor.WALL_MODES.has(mode))
		button.visible = visible_now
		var on: bool = (paint and _editor.paint_mode == mode) or (wall and _editor.wall_mode == mode)
		button.set_pressed_no_signal(on)
		button.highlight = on
	_bar.visible = paint or wall
	var cost: int = _editor.stroke_preview_cost()
	var cost_text: String = "  ·  %s ₺" % Hud.format_thousands(cost) if cost > 0 else ""
	match _editor.tool:
		GarageEditor.Tool.PAINT:
			var title: String = Loc.t(String(GarageDecor.get_item(_editor.paint_pattern).get("title", "")))
			match _editor.paint_mode:
				&"erase": _info.text = Loc.t("SİLGİ · SÜRÜKLE: KAROYU SİL (ÜCRETSİZ)")
				&"pick": _info.text = Loc.t("DAMLALIK · KAROYA DOKUN: DESENİNİ AL")
				&"rect": _info.text = Loc.t("%s · SÜRÜKLE: ALANI DOLDUR") % title + cost_text
				&"fill": _info.text = Loc.t("%s · DOKUN: ODAYI DOLDUR") % title
				_: _info.text = Loc.t("%s · SÜRÜKLE: BOYA (%s ₺ / KARO)") % [title,
					Hud.format_thousands(_decor.tile_price(_editor.paint_pattern))]
		GarageEditor.Tool.WALL:
			var piece: String = Loc.t(String(GarageDecor.get_item(_editor.wall_piece).get("title", "")))
			_info.text = Loc.t("%s · ÇİZGİ BOYUNCA SÜRÜKLE: ÖR") % piece + cost_text if _editor.wall_mode == &"build" \
				else Loc.t("DUVARA DOKUN YA DA SÜRÜKLE: SÖK")
		GarageEditor.Tool.FINISH:
			var finish: String = Loc.t(String(GarageDecor.get_item(_editor.finish_id).get("title", ""))) \
				if _editor.finish_id != &"" else Loc.t("VARSAYILAN")
			_info.text = Loc.t("%s · DUVARA DOKUN: KAPLA") % finish


func _on_tool_mode(mode: StringName) -> void:
	if _editor == null:
		return
	if GarageEditor.PAINT_MODES.has(mode):
		if _editor.paint_pattern == &"" and mode != &"erase" and mode != &"pick":
			_show_notice(Loc.t("ÖNCE BİR DESEN SEÇ"))
		_editor.set_paint_mode(mode)
	else:
		_editor.set_wall_mode(mode)


## Ekranın arayüzsüz dikey bandı (0..1): üstte başlık grubunun, altta sekmeler + şerit + denetim
## çubuğunun ALTINDA/ÜSTÜNDE kalan kısım. Kamera garajı bu banda sığdırır; böylece çubuk ya da
## sekmeler garajın ön köşesindeki eşyanın üstüne binmez (telefon oranında 0.64 sabiti çubuğun
## altına düşüyordu). Çubuk açılışta gizli olduğu için yüksekliği ayrıca eklenir.
func _view_band() -> Vector2:
	var height: float = maxf(get_viewport_rect().size.y, 1.0)
	var top: float = _top.get_combined_minimum_size().y + MARGIN
	var bottom: float = _bottom.get_combined_minimum_size().y + MARGIN
	if not _bar.visible:
		# Çubuk açılışta gizli ve düğmeleri de gizli olduğu için ölçüsü ~0 çıkıyordu: araç çubuğu açılınca
		# garajın ön köşesinin üstüne biniyor, oradaki dokunuşlar düğmelere gidiyordu (telefonda boyama
		# hiç yapılamadı). Bir plaka satırı kadar yer her zaman ayrılır.
		bottom += maxf(_bar.get_combined_minimum_size().y, BAR_RESERVE)
	return Vector2(top / height, 1.0 - bottom / height)


func _show_notice(text: String) -> void:
	_notice.text = text
	if _notice_tween:
		_notice_tween.kill()
	_notice.modulate.a = 1.0
	_notice_tween = create_tween()
	_notice_tween.tween_interval(1.6)
	_notice_tween.tween_property(_notice, "modulate:a", 0.0, 0.4)
