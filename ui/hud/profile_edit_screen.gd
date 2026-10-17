class_name ProfileEditScreen
extends Control
## PROFİLİ DÜZENLE (UiRouter alt pano &"profile_edit", PROFİL kartındaki DÜZENLE'den). Solda canlı önizleme,
## sağda sekmeler:
##   FOTOĞRAF — GALERİ / KAMERA / GOOGLE + 12 hazır avatar + "Google fotoğrafını kullan" anahtarı
##   ÇERÇEVE  — seviyeyle açılanlar ve elmaslılar (100–600 GEM; ilk dokunuş fiyatı söyler, ikincisi alır)
##   BAYRAK   — 44 piksel bayrak (FlagIcon) + YOK
##   VİTRİN   — sahip olunan araçlardan biri (profil kartında görünür)
##   İSİM     — takma ad (SocialManager.rename) ve garaj adı
## Veri PlayerProfile'da; bu ekran yalnızca gösterir ve seçimi iletir. Kapanınca açık profil hemen yayınlanır
## (SocialManager.publish_now). Galeri / kamera görüntüsü önce kırpıcıya (AvatarCropper, &"avatar_crop") gider;
## kamera ayrı alt panodur (CameraCapture, &"avatar_camera"). İkisini de HUD kurar ve buraya verir.

signal closed
signal screen_requested(id: StringName)

enum Tab { PHOTO, FRAME, FLAG, CAR, NAME }

const PREVIEW_WIDTH: float = 176.0
const BODY_WIDTH: float = 476.0
const BODY_HEIGHT: float = 262.0

var cropper: AvatarCropper:
	set(value):
		cropper = value
		if cropper and not cropper.cropped.is_connected(_on_cropped):
			cropper.cropped.connect(_on_cropped)
var camera: CameraCapture:
	set(value):
		camera = value
		if camera and not camera.captured.is_connected(_on_captured):
			camera.captured.connect(_on_captured)

var _profile: PlayerProfile
var _social: SocialManager
var _column: VBoxContainer
var _preview: AvatarView
var _preview_name: Label
var _preview_flag: FlagIcon
var _preview_title: Label
var _tabs: Dictionary = {}
var _tab_group: ButtonGroup = ButtonGroup.new()
var _body: VBoxContainer
var _scroll: ScrollContainer
var _notice: Label
var _tab: Tab = Tab.PHOTO
var _confirm_frame: String = ""
var _name_edit: LineEdit
var _title_edit: LineEdit
var _closing: bool = false
## Açılış / kapanış sayacı: kapanış animasyonu sürerken yeniden açılırsa eski kapanış (gizle + closed) iptal olur.
var _gen: int = 0


func _ready() -> void:
	name = "ProfileEditScreen"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_connect.call_deferred()


func open() -> void:
	_confirm_frame = ""
	_notice.text = ""
	_gen += 1
	_closing = false
	PlateAnim.pop_in(self, _column)
	_select_tab(_tab)


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	if _social:
		_social.publish_now()   # arkadaşlar yeni profili hemen görsün
	_gen += 1
	var gen: int = _gen
	PlateAnim.pop_out(self, _column, func() -> void:
		if gen != _gen:
			return
		hide()
		_closing = false
		closed.emit())


# --- Kurulum ---------------------------------------------------------------------

func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center: CenterContainer = FitScroll.center_in(self)
	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override(&"separation", 8)
	center.add_child(_column)

	var sign: PlatePanel = PlatePanel.new()
	sign.theme_type_variation = &"HudCarPlate"
	sign.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var title: Label = _label(&"HudSignTitle", Loc.t("PROFİLİ DÜZENLE"))
	sign.add_child(title)
	_column.add_child(sign)

	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 8)
	_column.add_child(row)

	# Önizleme
	var left: PlatePanel = PlatePanel.new()
	left.theme_type_variation = &"HudCarPlate"
	left.custom_minimum_size = Vector2(PREVIEW_WIDTH, 0.0)
	row.add_child(left)
	var left_box: VBoxContainer = VBoxContainer.new()
	left_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_box.alignment = BoxContainer.ALIGNMENT_CENTER
	left_box.add_theme_constant_override(&"separation", 4)
	left.add_child(left_box)
	_preview = AvatarView.new()
	_preview.name = "Preview"
	_preview.custom_minimum_size = Vector2(140.0, 140.0)
	_preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left_box.add_child(_preview)
	var name_row: HBoxContainer = HBoxContainer.new()
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_theme_constant_override(&"separation", 6)
	_preview_name = _label(&"HudInkValue", "")
	_preview_name.custom_minimum_size = Vector2(PREVIEW_WIDTH - 60.0, 0.0)
	_preview_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_name.clip_text = true
	_preview_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_row.add_child(_preview_name)
	_preview_flag = FlagIcon.new()
	_preview_flag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(_preview_flag)
	left_box.add_child(name_row)
	_preview_title = _label(&"HudInkCaption", "")
	_preview_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_title.add_theme_color_override(&"font_color", HudPalette.PLATE_SELECTED_EDGE)
	left_box.add_child(_preview_title)

	# Sekmeler + içerik
	var right: PlatePanel = PlatePanel.new()
	right.theme_type_variation = &"HudCarPlate"
	row.add_child(right)
	var right_box: VBoxContainer = VBoxContainer.new()
	right_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_box.add_theme_constant_override(&"separation", 6)
	right.add_child(right_box)
	var tab_row: HBoxContainer = HBoxContainer.new()
	tab_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab_row.add_theme_constant_override(&"separation", 4)
	right_box.add_child(tab_row)
	for entry: Array in [[Tab.PHOTO, Loc.t("FOTOĞRAF")], [Tab.FRAME, Loc.t("ÇERÇEVE")], [Tab.FLAG, Loc.t("BAYRAK")],
			[Tab.CAR, Loc.t("VİTRİN")], [Tab.NAME, Loc.t("İSİM")]]:
		var tab: PlateButton = PlateButton.new()
		tab.name = "Tab%d" % int(entry[0])
		tab.theme_type_variation = &"HudPlateSmall"
		tab.text = entry[1]
		tab.toggle_mode = true
		tab.button_group = _tab_group
		tab.bolts = false
		tab.focus_mode = Control.FOCUS_NONE
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(_select_tab.bind(int(entry[0])))
		tab_row.add_child(tab)
		_tabs[int(entry[0])] = tab
	_scroll = ScrollContainer.new()
	_scroll.name = "BodyScroll"
	_scroll.custom_minimum_size = Vector2(BODY_WIDTH, BODY_HEIGHT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	right_box.add_child(_scroll)
	TouchScroll.attach(_scroll)
	_body = VBoxContainer.new()
	_body.name = "Body"
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override(&"separation", 8)
	_scroll.add_child(_body)
	_notice = _label(&"HudInkCaption", "")
	_notice.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.custom_minimum_size = Vector2(BODY_WIDTH, 0.0)
	right_box.add_child(_notice)

	var done: PlateButton = PlateButton.new()
	done.name = "DoneButton"
	done.theme_type_variation = &"HudPlateSmall"
	done.text = Loc.t("TAMAM")
	done.highlight = true
	done.focus_mode = Control.FOCUS_NONE
	done.custom_minimum_size = Vector2(PREVIEW_WIDTH + BODY_WIDTH + 30.0, 0.0)
	done.pressed.connect(close)
	_column.add_child(done)


func _connect() -> void:
	_profile = get_tree().get_first_node_in_group("player_profile") as PlayerProfile
	_social = get_tree().get_first_node_in_group("social") as SocialManager
	if _profile:
		_profile.changed.connect(_refresh)
		_profile.avatar_changed.connect(_refresh)
	if _social:
		_social.notice.connect(func(text: String) -> void:
			if visible:
				_notice.text = text)
		_social.changed.connect(func() -> void:
			if visible and _tab == Tab.NAME:
				_refresh_preview())


# --- Görünüm ---------------------------------------------------------------------

func _select_tab(tab: int) -> void:
	_tab = tab as Tab
	(_tabs[tab] as PlateButton).set_pressed_no_signal(true)
	_confirm_frame = ""
	_refresh()
	_scroll.scroll_vertical = 0


func _refresh() -> void:
	if not visible or _profile == null:
		return
	_refresh_preview()
	for child: Node in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	match _tab:
		Tab.PHOTO:
			_build_photo()
		Tab.FRAME:
			_build_frames()
		Tab.FLAG:
			_build_flags()
		Tab.CAR:
			_build_cars()
		Tab.NAME:
			_build_names()


func _refresh_preview() -> void:
	_preview.show_avatar(_profile.my_texture(), _profile.my_illustrated(), _profile.frame_id)
	var me: Dictionary = ProfileCard.me(get_tree())
	var name: String = SaveSafe.s(me.get("name", ""))
	_preview_name.text = Loc.upper(name) if not name.is_empty() else Loc.t("OYUNCU")
	_preview_flag.code = _profile.flag
	_preview_title.text = _profile.title


# --- FOTOĞRAF --------------------------------------------------------------------

func _build_photo() -> void:
	var sources: HBoxContainer = _row()
	var gallery: PlateButton = _button(Loc.t("GALERİ"), _on_gallery)
	gallery.name = "GalleryButton"
	sources.add_child(gallery)
	var cam: PlateButton = _button(Loc.t("KAMERA"), func() -> void: screen_requested.emit(&"avatar_camera"))
	cam.name = "CameraButton"
	cam.kind = HudIcon.Kind.CAMERA
	cam.icon_left = true
	sources.add_child(cam)
	var google: PlateButton = _button(Loc.t("GOOGLE"), _on_google, not _profile.has_google_photo())
	google.name = "GoogleButton"
	google.highlight = _profile.google_active()
	sources.add_child(google)
	_body.add_child(sources)
	if _profile.avatar == "photo":
		var own: HBoxContainer = _row()
		own.add_child(_label(&"HudInkCaption", Loc.t("Kendi fotoğrafını kullanıyorsun.")))
		own.add_child(_button(Loc.t("KALDIR"), func() -> void: _profile.set_auto()))
		_body.add_child(own)

	_body.add_child(_label(&"HudInkCaption", Loc.t("HAZIR AVATARLAR")))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 6
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override(&"h_separation", 14)
	grid.add_theme_constant_override(&"v_separation", 10)
	for id: String in ProfileCatalog.preset_ids():
		var pick: AvatarButton = AvatarButton.new()
		pick.name = "Preset_" + id
		pick.diameter = 62.0
		pick.toggle_mode = true
		pick.button_pressed = _profile.avatar == id
		pick.show_avatar(ProfileCatalog.preset_texture(id), true)
		pick.pressed.connect(func() -> void: _profile.set_preset(id))
		grid.add_child(pick)
	_body.add_child(grid)

	var google_row: HBoxContainer = _row()
	var caption: Label = _label(&"HudInkCaption", Loc.t("Fotoğraf seçmezsen Google fotoğrafın görünsün mü?"))
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	google_row.add_child(caption)
	var toggle: PlateButton = _button(Loc.t("GOOGLE: AÇIK") if _profile.use_google else Loc.t("GOOGLE: KAPALI"),
		func() -> void: _profile.set_use_google(not _profile.use_google))
	toggle.name = "GoogleToggle"
	toggle.custom_minimum_size = Vector2(150.0, 0.0)
	toggle.highlight = _profile.use_google
	google_row.add_child(toggle)
	_body.add_child(google_row)


func _on_gallery() -> void:
	_notice.text = ""
	PhotoPicker.pick(self, func(image: Image, error: String) -> void:
		if image == null:
			_notice.text = error
			return
		_crop(image))


func _on_google() -> void:
	_profile.set_use_google(true)
	_profile.set_auto()


## Kamera kapandıktan SONRA gelir (CameraCapture): kırpıcı açıldığında kamera yığından düşmüş olur.
func _on_captured(image: Image) -> void:
	_crop(image)


func _crop(image: Image) -> void:
	if cropper == null:
		_profile.set_photo(image)
		return
	cropper.set_image(image)
	screen_requested.emit(&"avatar_crop")


func _on_cropped(image: Image) -> void:
	if not _profile.set_photo(image):
		_notice.text = Loc.t("Fotoğraf kaydedilemedi.")


# --- ÇERÇEVE ---------------------------------------------------------------------

func _build_frames() -> void:
	var progress: PlayerProgress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress
	if progress:
		_body.add_child(_label(&"HudInkCaption", Loc.t("ELMASIN: %s GEM") % Hud.format_thousands(progress.gems)))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 5
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override(&"h_separation", 10)
	grid.add_theme_constant_override(&"v_separation", 6)
	var tex: Texture2D = _profile.my_texture()
	var illustrated: bool = _profile.my_illustrated()
	for entry: Dictionary in ProfileCatalog.FRAMES:
		var id: String = entry["id"]
		var cell: VBoxContainer = VBoxContainer.new()
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_theme_constant_override(&"separation", 0)
		var pick: AvatarButton = AvatarButton.new()
		pick.name = "Frame_" + id
		pick.diameter = 64.0
		pick.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		pick.toggle_mode = true
		pick.button_pressed = _profile.frame_id == id
		pick.show_avatar(tex, illustrated, id)
		pick.pressed.connect(_on_frame_pressed.bind(id))
		cell.add_child(pick)
		var label: Label = _label(&"HudInkValue", Loc.t(String(entry["name"])))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.custom_minimum_size = Vector2(84.0, 0.0)
		cell.add_child(label)
		var state: Label = _label(&"HudInkCaption", _frame_state(entry))
		state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if _confirm_frame == id:
			state.add_theme_color_override(&"font_color", HudPalette.DANGER)
		cell.add_child(state)
		grid.add_child(cell)
	_body.add_child(grid)


func _frame_state(entry: Dictionary) -> String:
	var id: String = entry["id"]
	if _profile.frame_id == id:
		return Loc.t("TAKILI")
	if _profile.frame_unlocked(id):
		return Loc.t("SEÇ")
	if int(entry["gems"]) > 0:
		return Loc.t("AL? %d GEM") % int(entry["gems"]) if _confirm_frame == id else Loc.t("%d GEM") % int(entry["gems"])
	return Loc.t("SEVİYE %d") % int(entry["level"])


func _on_frame_pressed(id: String) -> void:
	var entry: Dictionary = ProfileCatalog.frame(id)
	_notice.text = ""
	if _profile.frame_unlocked(id):
		_confirm_frame = ""
		_profile.set_frame(id)
		return
	var price: int = int(entry["gems"])
	if price <= 0:
		_notice.text = Loc.t("%s çerçevesi %d. seviyede açılır.") % [Loc.t(String(entry["name"])), int(entry["level"])]
		_refresh()
		return
	if _confirm_frame != id:
		_confirm_frame = id
		_notice.text = Loc.t("%s çerçevesi %d GEM. Almak için tekrar dokun.") % [Loc.t(String(entry["name"])), price]
		_refresh()
		return
	_confirm_frame = ""
	if not _profile.buy_frame(id):
		_notice.text = Loc.t("GEM YETERSİZ · %d GEM GEREKİYOR") % price
		_refresh()


# --- BAYRAK ----------------------------------------------------------------------

func _build_flags() -> void:
	var chosen: String = _profile.flag
	_body.add_child(_label(&"HudInkValue", ProfileCatalog.flag_name(chosen) if not chosen.is_empty() else Loc.t("BAYRAK SEÇİLMEDİ")))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 8
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override(&"h_separation", 8)
	grid.add_theme_constant_override(&"v_separation", 4)
	var none: _FlagButton = _FlagButton.new("", chosen.is_empty())
	none.name = "Flag_none"
	none.pressed.connect(func() -> void: _profile.set_flag(""))
	grid.add_child(none)
	for code: String in ProfileCatalog.flag_codes():
		var pick: _FlagButton = _FlagButton.new(code, chosen == code)
		pick.name = "Flag_" + code
		pick.tooltip_text = ProfileCatalog.flag_name(code)
		pick.pressed.connect(func() -> void: _profile.set_flag(code))
		grid.add_child(pick)
	_body.add_child(grid)


# --- VİTRİN ----------------------------------------------------------------------

func _build_cars() -> void:
	var ownership: VehicleOwnership = get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	var ids: Array[StringName] = []
	if ownership:
		for id: StringName in ownership.owned_vehicle_ids():
			if not ids.has(id):
				ids.append(id)
	if ids.is_empty():
		_body.add_child(_label(&"HudInkCaption", Loc.t("Henüz aracın yok. İlk aracın hoş geldin kutusunda!")))
		return
	_body.add_child(_label(&"HudInkCaption", Loc.t("Profil kartında görünecek aracı seç.")))
	var current: StringName = _profile.showcase_vehicle()
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override(&"h_separation", 8)
	grid.add_theme_constant_override(&"v_separation", 6)
	for id: StringName in ids:
		var cell: VBoxContainer = VBoxContainer.new()
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_theme_constant_override(&"separation", 0)
		var pick: _ThumbButton = _ThumbButton.new(id, id == current)
		pick.name = "Car_" + String(id)
		pick.pressed.connect(func() -> void: _profile.set_showcase(id))
		cell.add_child(pick)
		var label: Label = _label(&"HudInkCaption", CarCatalog.label(CarCatalog.get_entry(id)))
		label.custom_minimum_size = Vector2(_ThumbButton.SIZE.x, 0.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		cell.add_child(label)
		grid.add_child(cell)
	_body.add_child(grid)


# --- İSİM ------------------------------------------------------------------------

func _build_names() -> void:
	_body.add_child(_label(&"HudInkCaption", Loc.t("TAKMA AD")))
	if _social and _social.is_ready():
		var name_row: HBoxContainer = _row()
		_name_edit = _line_edit(Loc.t("Takma ad"), SocialNames.NAME_MAX)
		_name_edit.name = "NameEdit"
		_name_edit.text = _social.my_name()
		name_row.add_child(_name_edit)
		name_row.add_child(_button(Loc.t("DEĞİŞTİR"), func() -> void: _social.rename(_name_edit.text), _social.is_busy()))
		_body.add_child(name_row)
	else:
		var hint: Label = _label(&"HudInkCaption", Loc.t("Takma adını ARKADAŞLAR ekranında oluşturabilirsin."))
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.add_child(hint)
	_body.add_child(_label(&"HudInkCaption", Loc.t("GARAJ ADI")))
	var title_row: HBoxContainer = _row()
	_title_edit = _line_edit(Loc.t("ör. Gece Garajı"), ProfileCatalog.TITLE_MAX)
	_title_edit.name = "TitleEdit"
	_title_edit.text = _profile.title
	_title_edit.text_submitted.connect(func(_t: String) -> void: _save_title())
	title_row.add_child(_title_edit)
	title_row.add_child(_button(Loc.t("KAYDET"), _save_title))
	_body.add_child(title_row)
	var note: Label = _label(&"HudInkCaption", Loc.t("Arkadaşların profil kartında takma adının altında görür. Harf, rakam, boşluk ve . _ - kullanabilirsin."))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(BODY_WIDTH - 20.0, 0.0)
	_body.add_child(note)


func _save_title() -> void:
	if _profile.set_title(_title_edit.text):
		_notice.text = Loc.t("Garaj adın kaydedildi.")
	else:
		_notice.text = Loc.t("Bu ad kullanılamaz. Harf, rakam, boşluk ve . _ - kullanabilirsin.")


# --- Parçalar --------------------------------------------------------------------

func _row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 6)
	return row


func _button(text: String, callback: Callable, disabled: bool = false) -> PlateButton:
	var button: PlateButton = PlateButton.new()
	button.theme_type_variation = &"HudPlateSmall"
	button.text = text
	button.bolts = false
	button.disabled = disabled
	button.custom_minimum_size = Vector2(112.0, 0.0)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	return button


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _line_edit(placeholder: String, max_length: int) -> LineEdit:
	var edit: LineEdit = LineEdit.new()
	edit.placeholder_text = placeholder
	edit.max_length = max_length
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.custom_minimum_size = Vector2(0.0, 44.0)
	edit.add_theme_color_override(&"font_color", HudPalette.INK)
	edit.add_theme_color_override(&"font_placeholder_color", HudPalette.INK_SOFT)
	edit.add_theme_color_override(&"caret_color", HudPalette.INK)
	edit.add_theme_font_size_override(&"font_size", 20)
	for style_name: StringName in [&"normal", &"focus"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = HudPalette.PLATE_HOVER
		style.border_color = HudPalette.PLATE_SELECTED_EDGE if style_name == &"focus" else HudPalette.PLATE_EDGE
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		style.content_margin_left = 10.0
		style.content_margin_right = 10.0
		edit.add_theme_stylebox_override(style_name, style)
	return edit


## Bayrak seçimi: piksel bayrak (FlagIcon) ya da YOK; seçiliyse amber çerçeve.
class _FlagButton:
	extends Button

	var _selected: bool = false

	func _init(code: String, selected: bool) -> void:
		_selected = selected
		flat = true
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(46.0, 32.0)
		for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		if code.is_empty():
			text = Loc.t("YOK")
			add_theme_color_override(&"font_color", HudPalette.INK_SOFT)
			add_theme_font_size_override(&"font_size", 13)
		else:
			var flag: FlagIcon = FlagIcon.new()
			flag.code = code
			flag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			add_child(flag)

	func _draw() -> void:
		if _selected:
			draw_rect(Rect2(Vector2.ZERO, size).grow(1.0), HudPalette.PLATE_SELECTED_EDGE, false, 3.0)


## Vitrin aracı seçimi: aracın küçük resmi (assets/cars/thumbs), seçiliyse amber çerçeve.
class _ThumbButton:
	extends Button

	const SIZE: Vector2 = Vector2(104.0, 66.0)
	var _selected: bool = false
	var _tex: Texture2D

	func _init(id: StringName, selected: bool) -> void:
		_selected = selected
		flat = true
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = SIZE
		for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		var path: String = ProfileCard.THUMB_DIR + String(id) + ".png"
		_tex = load(path) as Texture2D if ResourceLoader.exists(path) else null

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		draw_rect(r, HudPalette.PLATE_HOVER)
		if _tex:
			var k: float = minf(size.x / _tex.get_width(), size.y / _tex.get_height())
			var s: Vector2 = Vector2(_tex.get_size()) * k
			draw_texture_rect(_tex, Rect2((size - s) * 0.5, s), false)
		draw_rect(r, HudPalette.PLATE_SELECTED_EDGE if _selected else HudPalette.PLATE_EDGE, false, 3.0 if _selected else 1.5)
