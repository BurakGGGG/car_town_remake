class_name LevelUpScreen
extends Control
## SEVİYE ATLADIN — seviye atlayınca ekranın ortasında büyük açılır (kullanıcı kararı 2026-10-21; tasarım tuvali
## "SEVİYE ATLADIN" sayfası, taslak A). Üstte seviye rozeti ve para + gem ödülü, altında AÇILANLAR kartları: yeni
## müşteri işi, depo (fotoğrafıyla), kasa (dönen 3B kasa), modifiye kademesi, görevler, profil çerçevesi (oyuncunun kendi
## avatarıyla), dekor (küçük resimler).
## O seviyede hiçbir şey açılmadıysa SIRADAKİ açılış seviyesi soluk kartlarla gösterilir. Eskiden 2,2 sn'lik
## bildirim plakasıydı. Açılanların tek kaynağı LevelUnlocks (sistemlerin kendi seviye kilitleri).
##
## Oyun SAKİNLEŞİNCE açılır (FounderRewardNotice'teki kural: pano yok, ders yok, kasa / restorasyon paneli yok,
## başka ödül penceresi yok); o arada atlanan seviyeler TEK ekranda birleşir. Hud kurar ve
## PlayerProgress.level_reward'ı add_level'a bağlar. DEVAM'a ya da kartların dışına dokununca kapanır.

signal closed

const CHECK_SEC: float = 0.4
## Oyun bu kadar sakin kalınca açılır (para toplama dokunuşunun hemen ardından araya girmesin).
const CALM_SEC: float = 0.8
## Açılır açılmaz gelen dokunuş pencereyi kapatmasın.
const TAP_GUARD: float = 0.6
const BADGE_SIZE: float = 74.0
const TITLE_SIZE: int = 24
const CARD_MAX_WIDTH: float = 196.0
const CARD_MIN_WIDTH: float = 124.0
const CARD_GAP: float = 12.0
const PIC_HEIGHT: float = 68.0
const DECOR_THUMBS: int = 3
const CARD_STAGGER: float = 0.12
## Henüz açılmamış (SIRADAKİ) kartların solukluğu.
const PREVIEW_ALPHA: float = 0.7

var _hud: Hud
## Bekleyen aralık: (from, to] seviyeleri; _to_level == 0 → bekleyen yok.
var _from_level: int = 0
var _to_level: int = 0
var _money: int = 0
## Ekrandaki seviye ödülü (₺): ödüllü reklamla bir kez ×2 (AdPolicy.LEVELUP_DOUBLE).
var _shown_money: int = 0
var _doubled: bool = false
var _double: AdOfferButton
var _gems: int = 0
var _calm: float = 0.0
var _opened_at: int = 0
var _closing: bool = false

var _timer: Timer
var _sfx: RewardSfx
var _thumbs: DecorThumbs
var _rays: _Rays
var _column: VBoxContainer
var _badge: _Badge
var _title: Label
var _money_chip: PanelContainer
var _money_label: Label
var _gem_chip: PanelContainer
var _gem_label: Label
var _divider: HBoxContainer
var _divider_label: Label
var _cards: HBoxContainer
var _continue: PlateButton
## Dekor küçük resmi bekleyen TextureRect'ler: eşya id → Array[TextureRect].
var _thumb_slots: Dictionary = {}
## Kırpılmış dekor küçük resimleri (_fitted_thumb): eşya id → Texture2D.
static var _fitted: Dictionary = {}


func _init(hud: Hud) -> void:
	_hud = hud
	name = "LevelUpScreen"


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_timer = Timer.new()
	_timer.wait_time = CHECK_SEC
	_timer.timeout.connect(_tick)
	add_child(_timer)
	resized.connect(_layout_cards)


## PlayerProgress.level_reward: seviye atlandı, ödülü verildi. Ekran sakin bir anda açılır.
func add_level(level: int, money: int, _text: String = "") -> void:
	if _to_level == 0:
		_from_level = level - 1
	_from_level = mini(_from_level, level - 1)
	_to_level = maxi(_to_level, level)
	_money += money
	_gems += int(PlayerProgress.reward_for(level)["gems"])
	_calm = 0.0
	_timer.start()


## Bekleyen seviye var mı (açılmayı bekliyor ya da ekranda)?
func is_pending() -> bool:
	return _to_level != 0 or visible


## Reklam izlendi: seviye ödülünün ₺'si bir kez daha verilir.
func _on_double() -> void:
	if _doubled or _shown_money <= 0:
		return
	_doubled = true
	var economy: EconomyManager = get_tree().get_first_node_in_group("economy") as EconomyManager
	if economy:
		economy.add_money(_shown_money)
	_money_label.text = "+%s ₺  ×2" % Hud.format_thousands(_shown_money * 2)
	_double.refresh()


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	_rays.stop()
	PlateAnim.pop_out(self, _column, func() -> void:
		hide()
		_clear_cards()
		_closing = false
		closed.emit()
		if _to_level != 0:
			_timer.start())


func _gui_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if tapped and Time.get_ticks_msec() - _opened_at > int(TAP_GUARD * 1000.0):
		accept_event()
		close()


func _tick() -> void:
	if _to_level == 0 or visible:
		return
	if not _is_calm():
		_calm = 0.0
		return
	_calm += CHECK_SEC
	if _calm >= CALM_SEC:
		_timer.stop()
		_open()


func _is_calm() -> bool:
	var tutorial: TutorialDirector = _hud.tutorial
	if not _hud.visible or not _hud.router.top().is_empty() or (tutorial and tutorial.is_running()):
		return false
	if (_hud.crate_panel and _hud.crate_panel.visible) or (_hud.restoration_result and _hud.restoration_result.visible):
		return false
	for child: Node in get_parent().get_children():   # posta / ön kayıt ödülü pencereleri de Root'ta
		if (child is RewardPopup or child is MailNotice) and (child as Control).visible:
			return false
	return get_tree().root.get_node_or_null("LoadingScreen") == null


func _open() -> void:
	var from_level: int = _from_level
	var to_level: int = _to_level
	_badge.set_level(to_level)
	_money_label.text = "+%s ₺" % Hud.format_thousands(_money)
	_money_chip.visible = _money > 0
	_shown_money = _money
	_doubled = false
	_double.reward_text = "+%s ₺" % Hud.format_thousands(_shown_money)
	_double.refresh()
	_gem_label.text = Loc.t("+%d GEM") % _gems
	_gem_chip.visible = _gems > 0
	_from_level = 0
	_to_level = 0
	_money = 0
	_gems = 0

	_clear_cards()
	var unlocks: Array[Dictionary] = LevelUnlocks.between(from_level, to_level)
	var preview: bool = unlocks.is_empty()
	if preview:
		var next: Dictionary = LevelUnlocks.next_after(to_level)
		if not next.is_empty():
			unlocks = next["unlocks"]
			_divider_label.text = Loc.t("SIRADAKİ: SEVİYE %d") % int(next["level"])
	else:
		_divider_label.text = Loc.t("AÇILANLAR")
	_divider.visible = not unlocks.is_empty()
	for entry: Dictionary in unlocks:
		var card: Control = _card(entry)
		if preview:
			card.set_meta(&"alpha", PREVIEW_ALPHA)
		_cards.add_child(card)
	_layout_cards()

	get_parent().move_child(self, -1)   # HUD panolarının en üstünde
	_closing = false
	_opened_at = Time.get_ticks_msec()
	PlateAnim.pop_in(self, _column)
	_rays.start()
	_sfx.fanfare()
	var cards: Array[Node] = _cards.get_children()
	for i: int in cards.size():
		_animate_card(cards[i] as Control, 0.25 + float(i) * CARD_STAGGER, i)


# --- Kurulum -----------------------------------------------------------------

func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.06, 0.07, 0.09, 0.74)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_sfx = RewardSfx.new()
	add_child(_sfx)
	_thumbs = DecorThumbs.new()
	_thumbs.ready_for.connect(_on_thumb_ready)
	add_child(_thumbs)

	_rays = _Rays.new()
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rays.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_rays)

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	add_child(margin)
	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_column.add_theme_constant_override(&"separation", 5)
	margin.add_child(_column)

	_badge = _Badge.new()
	_badge.custom_minimum_size = Vector2(BADGE_SIZE, BADGE_SIZE)
	_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_column.add_child(_badge)
	_rays.target = _badge

	_title = _label(&"HudOutlinedLarge", Loc.t("SEVİYE ATLADIN!"))
	_title.add_theme_font_size_override(&"font_size", TITLE_SIZE)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(_title)

	var rewards: HBoxContainer = HBoxContainer.new()
	rewards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rewards.alignment = BoxContainer.ALIGNMENT_CENTER
	rewards.add_theme_constant_override(&"separation", 10)
	_column.add_child(rewards)
	_money_label = _label(&"HudOutlinedLarge", "")
	_money_chip = _chip(HudIcon.Kind.COIN, _money_label)
	rewards.add_child(_money_chip)
	_gem_label = _label(&"HudOutlinedLarge", "")
	_gem_chip = _chip(HudIcon.Kind.GEM, _gem_label)
	rewards.add_child(_gem_chip)

	_divider = HBoxContainer.new()
	_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_divider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_divider.add_theme_constant_override(&"separation", 10)
	_divider.add_child(_line())
	_divider_label = _label(&"HudOutlined", "")
	_divider.add_child(_divider_label)
	_divider.add_child(_line())
	_column.add_child(_divider)

	_cards = HBoxContainer.new()
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.add_theme_constant_override(&"separation", int(CARD_GAP))
	_column.add_child(_cards)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", 10)
	_column.add_child(buttons)
	_continue = PlateButton.new()
	_continue.theme_type_variation = &"HudPlateSmall"
	_continue.text = Loc.t("DEVAM ET")
	_continue.highlight = true
	_continue.focus_mode = Control.FOCUS_NONE
	_continue.custom_minimum_size = Vector2(200.0, 0.0)
	_continue.pressed.connect(close)
	buttons.add_child(_continue)
	# Seviye ödülü ×2: oyuncu basarsa ödüllü reklam (kendiliğinden açılmaz)
	_double = AdOfferButton.new(AdPolicy.LEVELUP_DOUBLE)
	_double.custom_minimum_size = Vector2(200.0, 0.0)
	_double.condition = func() -> bool: return visible and not _closing and not _doubled and _shown_money > 0
	_double.rewarded.connect(_on_double)
	buttons.add_child(_double)


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Kart altındaki küçük yazı: dar kartta "…" ile kesilmek yerine en çok üç satıra sarılır (Fransızca "NOUVELLES PIÈCES
## POUR TA VOITURE DE COURSE" iki satıra sığmıyordu).
func _wrapped(variation: StringName, text: String) -> Label:
	var label: Label = _label(variation, text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = 3
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


func _rounded(color: Color, radius: int, pad_x: float, pad_y: float) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.content_margin_left = pad_x
	box.content_margin_right = pad_x
	box.content_margin_top = pad_y
	box.content_margin_bottom = pad_y
	return box


## Ödül hapı: koyu zemin üstünde ikon + konturlu sayı.
func _chip(kind: HudIcon.Kind, label: Label) -> PanelContainer:
	var chip: PanelContainer = PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box: StyleBoxFlat = _rounded(Color(0.08, 0.09, 0.1, 0.8), 16, 12.0, 3.0)
	box.content_margin_left = 5.0
	chip.add_theme_stylebox_override(&"panel", box)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 6)
	chip.add_child(row)
	var icon: HudIcon = HudIcon.new()
	icon.kind = kind
	icon.icon_size = 22.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	label.add_theme_font_size_override(&"font_size", 16)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	return chip


func _line() -> ColorRect:
	var line: ColorRect = ColorRect.new()
	line.color = Color(HudPalette.TEXT_LIGHT, 0.3)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.custom_minimum_size = Vector2(0.0, 2.0)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return line


# --- Kartlar -----------------------------------------------------------------

func _card(entry: Dictionary) -> Control:
	var card: PlatePanel = PlatePanel.new()
	card.add_theme_stylebox_override(&"panel", _card_style())
	card.mouse_filter = Control.MOUSE_FILTER_STOP   # karta dokunmak pencereyi kapatmaz
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 4)
	card.add_child(box)
	var pic: PanelContainer = PanelContainer.new()
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.clip_contents = true
	pic.custom_minimum_size = Vector2(0.0, PIC_HEIGHT)
	pic.add_theme_stylebox_override(&"panel", _rounded(Color(HudPalette.INK, 0.08), 6, 0.0, 0.0))
	var name_label: Label = _label(&"HudInkValue", "")
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	card.set_meta(&"name_label", name_label)   # dar kartta uzun tek sözcük küçülür (_fit_name)
	var detail: Label = _wrapped(&"HudInkCaption", "")
	var tag: String = ""
	var need: String = ""
	match int(entry["kind"]):
		LevelUnlocks.Kind.CUSTOMER:
			var type: RepairType = entry["type"]
			tag = Loc.t("YENİ MÜŞTERİ")
			pic.add_child(_bubble(HudIcon.Kind.WRENCH, HudPalette.INK))
			name_label.text = type.title
			detail.text = Loc.t("%s · +%s ₺") % [_duration(type.duration), Hud.format_thousands(type.reward)]
			if type.min_garage_level > 1 or type.min_bays > 1:
				need = Loc.t("GARAJ SV.%d + %d ALAN GEREKİR") % [type.min_garage_level, type.min_bays]
		LevelUnlocks.Kind.DEPOT:
			var garage: StringName = entry["id"]
			tag = Loc.t("YENİ DEPO")
			pic.add_child(_photo(CarGaragesScreen.card_path(garage)))
			name_label.text = CarGarageCatalog.display_name(garage)
			detail.text = Loc.t("%d PARK YERİ · %s ₺") % [CarGarageCatalog.capacity_at(garage, 1),
				Hud.format_thousands(CarGarageCatalog.price(garage))]
		LevelUnlocks.Kind.CRATE:
			var crate: Dictionary = CrateCatalog.get_entry(entry["id"])
			tag = Loc.t("YENİ KASA")
			pic.add_child(_CratePreview.new(crate))
			name_label.text = Loc.t(String(crate.get("display_name", "")))
			detail.text = Loc.t("SHOWROOM'DA · %d GEM") % CrateCatalog.sale_price(entry["id"])
		LevelUnlocks.Kind.MOD_TIER:
			var stage: int = int(entry["stage"])
			tag = Loc.t("MODİFİYE")
			pic.add_child(_bubble(HudIcon.Kind.GEAR, PerformanceMods.tier_color(stage)))
			name_label.text = Loc.t("%s KADEMESİ") % PerformanceMods.tier_name(stage)
			detail.text = Loc.t("YARIŞ ARACINA YENİ PARÇALAR")
		LevelUnlocks.Kind.MISSIONS:
			tag = Loc.t("YENİ")
			pic.add_child(_bubble(HudIcon.Kind.CHECK, HudPalette.INK))
			name_label.text = Loc.t("GÖREVLER")
			detail.text = Loc.t("GÜNLÜK VE HAFTALIK ÖDÜLLER")
		LevelUnlocks.Kind.FRAME:
			var frame: Dictionary = ProfileCatalog.frame(String(entry["id"]))
			tag = Loc.t("ÇERÇEVE")
			pic.add_child(_framed_avatar(String(entry["id"])))
			name_label.text = Loc.t("%s ÇERÇEVE") % Loc.t(String(frame.get("name", "")))
			detail.text = Loc.t("PROFİLİNDE KULLANABİLİRSİN")
		LevelUnlocks.Kind.DECOR:
			var items: Array[StringName] = entry["items"]
			tag = Loc.t("YENİ DEKOR")
			pic.add_child(_decor_strip(items))
			name_label.text = Loc.tn("%d YENİ EŞYA", items.size()) % items.size()
			var names: PackedStringArray = PackedStringArray()
			for i: int in mini(items.size(), 2):
				names.append(Loc.t(String(GarageDecor.get_item(items[i]).get("title", ""))))
			detail.text = " · ".join(names) + ("…" if items.size() > 2 else "")
	box.add_child(_tag(tag))
	box.add_child(pic)
	box.add_child(name_label)
	box.add_child(detail)
	if need != "":
		var need_label: Label = _wrapped(&"HudInkCaption", need)
		need_label.add_theme_color_override(&"font_color", HudPalette.PLATE_SELECTED_EDGE)
		box.add_child(need_label)
	return card


## HudCarPlate krem plakası, iç boşluğu dar (16:9'da beş kart yan yana sığsın, adlar kesilmesin).
func _card_style() -> StyleBoxFlat:
	var box: StyleBoxFlat = _rounded(HudPalette.PLATE, 8, 8.0, 7.0)
	box.content_margin_bottom = 10.0
	box.border_width_bottom = 4
	box.border_color = HudPalette.PLATE_EDGE
	box.shadow_color = HudPalette.SHADOW
	box.shadow_size = 5
	box.shadow_offset = Vector2(0.0, 3.0)
	return box


## Kartın sol üstündeki koyu etiket (YENİ MÜŞTERİ, YENİ DEPO...).
func _tag(text: String) -> PanelContainer:
	var tag: PanelContainer = PanelContainer.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tag.add_theme_stylebox_override(&"panel", _rounded(HudPalette.INK, 9, 8.0, 1.0))
	var label: Label = _label(&"HudInkCaption", text)
	label.add_theme_color_override(&"font_color", HudPalette.PLATE_SELECTED)
	label.add_theme_font_size_override(&"font_size", 9)
	tag.add_child(label)
	return tag


## Dünyadaki müşteri balonu gibi: beyaz daire, koyu halka, ortada ikon.
func _bubble(kind: HudIcon.Kind, ring: Color) -> Control:
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bubble: _Bubble = _Bubble.new()
	bubble.kind = kind
	bubble.ring = ring
	bubble.custom_minimum_size = Vector2(PIC_HEIGHT - 14.0, PIC_HEIGHT - 14.0)
	center.add_child(bubble)
	return center


## Oyuncunun kendi avatarı yeni çerçevesiyle (HUD'daki profil düğmesinin resmi).
func _framed_avatar(frame_id: String) -> Control:
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var avatar: AvatarView = AvatarView.new()
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar.custom_minimum_size = Vector2(PIC_HEIGHT - 8.0, PIC_HEIGHT - 8.0)
	var texture: Texture2D = _hud.profile_button.avatar
	var preset: bool = texture != null and texture.resource_path.begins_with("res://assets/ui/avatars/")
	avatar.show_avatar(texture, preset, frame_id)
	center.add_child(avatar)
	return center


func _photo(path: String) -> TextureRect:
	var photo: TextureRect = TextureRect.new()
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists(path):
		photo.texture = load(path) as Texture2D
	return photo


## İlk DECOR_THUMBS eşyanın küçük resmi (DecorThumbs tembel üretir) + kalanların sayısı köşede. Zemin karosu / duvar
## kaplamasının 3B resmi yok: dokunun kendisinden kare önizleme (dekor paletindeki gibi; seviye 2'de yalnız karo açılır,
## kart bomboş kalıyordu).
func _decor_strip(items: Array[StringName]) -> Control:
	var holder: MarginContainer = MarginContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: StringName in [&"margin_top", &"margin_right"]:
		holder.add_theme_constant_override(side, 4)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 0)
	holder.add_child(row)
	for i: int in mini(items.size(), DECOR_THUMBS):
		var id: StringName = items[i]
		if GarageDecor.is_pattern(id) or GarageDecor.is_surface(id):
			var swatch: _Swatch = _Swatch.new()
			swatch.texture = DecorTextures.swatch(id)
			swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
			swatch.custom_minimum_size = Vector2(0.0, PIC_HEIGHT - 4.0)
			swatch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(swatch)
			continue
		var thumb: TextureRect = TextureRect.new()
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.custom_minimum_size = Vector2(0.0, PIC_HEIGHT - 4.0)   # genişlik kartın: dar ekranda kartı büyütmesin
		thumb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		thumb.texture = _fitted_thumb(id)
		if thumb.texture == null:
			if not _thumb_slots.has(id):
				_thumb_slots[id] = []
			(_thumb_slots[id] as Array).append(thumb)
			_thumbs.request(id)
		row.add_child(thumb)
	if items.size() > DECOR_THUMBS:
		var more: PanelContainer = PanelContainer.new()
		more.mouse_filter = Control.MOUSE_FILTER_IGNORE
		more.size_flags_horizontal = Control.SIZE_SHRINK_END   # köşede, resimlerin üstünde: genişliklerinden yemesin
		more.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		more.add_theme_stylebox_override(&"panel", _rounded(HudPalette.INK, 9, 6.0, 1.0))
		var label: Label = _label(&"HudInkCaption", "+%d" % (items.size() - DECOR_THUMBS))
		label.add_theme_color_override(&"font_color", HudPalette.TEXT_LIGHT)
		more.add_child(label)
		holder.add_child(more)
	return holder


## DecorThumbs resmi, eşyanın çevresindeki saydam boşluk kırpılmış (kartta üç resim yan yana: 160x110 karede eşya
## alanın beşte biri kadardı, küçücük görünüyordu). Kırpılmış doku eşya başına bir kez üretilir.
static func _fitted_thumb(id: StringName) -> Texture2D:
	if _fitted.has(id):
		return _fitted[id]
	var source: Texture2D = DecorThumbs.cached(id)
	if source == null:
		return null
	var texture: Texture2D = source
	var image: Image = source.get_image()
	var used: Rect2i = image.get_used_rect() if image else Rect2i()
	if used.has_area():
		used = used.grow(2).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
		texture = ImageTexture.create_from_image(image.get_region(used))
	_fitted[id] = texture
	return texture


func _on_thumb_ready(id: StringName) -> void:
	for thumb: Variant in _thumb_slots.get(id, []):
		if is_instance_valid(thumb):
			(thumb as TextureRect).texture = _fitted_thumb(id)
	_thumb_slots.erase(id)


func _clear_cards() -> void:
	_thumb_slots.clear()
	for child: Node in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()


## Kart genişliği ekrana göre: en dar tuvalde (853) dört kart da sığsın.
func _layout_cards() -> void:
	if _cards == null:
		return
	var count: int = _cards.get_child_count()
	if count == 0:
		return
	var room: float = size.x - 28.0 - CARD_GAP * float(count - 1)
	var width: float = clampf(room / float(count), CARD_MIN_WIDTH, CARD_MAX_WIDTH)
	for child: Node in _cards.get_children():
		(child as Control).custom_minimum_size.x = width
		var name_label: Label = child.get_meta(&"name_label", null) as Label
		if name_label:
			_fit_name(name_label, width - 16.0)   # kartın iç payı (_card_style: yanlarda 8)
	_divider.custom_minimum_size.x = width * float(count) + CARD_GAP * float(count - 1)


## Kart başlığı sığmıyorsa yazı küçülür (en çok 9 punto; yine sığmazsa üç nokta). Almanca tek sözcük
## "BREMSENÜBERHOLUNG" (FREN REVİZYONU) en dar tuvalde 181 birimdi, kart 140: kesiliyordu.
func _fit_name(label: Label, width: float) -> void:
	label.remove_theme_font_size_override(&"font_size")
	var font: Font = label.get_theme_font(&"font")
	var base: int = label.get_theme_font_size(&"font_size")
	var size: int = base
	while size > 9 and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		size -= 1
	if size != base:
		label.add_theme_font_size_override(&"font_size", size)


## Kart sırayla "pıt" diye yerine oturur.
func _animate_card(card: Control, delay: float, index: int) -> void:
	var alpha: float = float(card.get_meta(&"alpha", 1.0))
	card.modulate.a = 0.0
	await get_tree().process_frame   # boyut hesaplansın (pivot ortada olsun)
	if not is_instance_valid(card):
		return
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2.ONE * 0.5
	var tween: Tween = card.create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(func() -> void: _sfx.tick(float(index + 1) / float(maxi(_cards.get_child_count(), 1))))
	tween.tween_property(card, "modulate:a", alpha, 0.1)
	tween.parallel().tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func _duration(seconds: float) -> String:
	return Loc.t("%d sn") % roundi(seconds) if seconds < 60.0 else ModWorkshop.duration_text(seconds)


# --- Çizimler ------------------------------------------------------------------

## Amber seviye rozeti: koyu halka, üstte küçük SEVİYE, ortada büyük sayı.
class _Badge extends Control:
	var _caption: Label
	var _number: Label

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var box: VBoxContainer = VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override(&"separation", 0)
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(box)
		_caption = _make(9)
		_caption.text = Loc.t("SEVİYE")
		box.add_child(_caption)
		_number = _make(28)
		box.add_child(_number)

	func set_level(level: int) -> void:
		_number.text = str(level)

	func _make(font_size: int) -> Label:
		var label: Label = Label.new()
		label.theme_type_variation = &"HudSignTitle"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override(&"font_size", font_size)
		label.add_theme_color_override(&"font_color", HudPalette.INK)
		return label

	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var radius: float = minf(size.x, size.y) * 0.5
		draw_circle(center + Vector2(0.0, 3.0), radius, HudPalette.SHADOW, true, -1.0, true)
		draw_circle(center, radius, HudPalette.PLATE_SELECTED, true, -1.0, true)
		draw_circle(center, radius - 3.0, HudPalette.INK, true, -1.0, true)
		draw_circle(center, radius - 7.0, HudPalette.PLATE_SELECTED, true, -1.0, true)


## Zemin karosu / duvar kaplaması önizlemesi: dokudan kare, ince gölge ve çerçeve (dekor paletindeki kartla aynı dil).
class _Swatch extends Control:
	var texture: Texture2D

	func _draw() -> void:
		if texture == null:
			return
		var side: float = minf(size.x - 8.0, size.y - 8.0)
		if side <= 0.0:
			return
		var rect: Rect2 = Rect2(size * 0.5 - Vector2(side, side) * 0.5, Vector2(side, side))
		draw_rect(Rect2(rect.position + Vector2(2.0, 3.0), rect.size), HudPalette.SHADOW, true)
		draw_texture_rect(texture, rect, false)
		draw_rect(rect, Color(HudPalette.INK, 0.55), false, 1.5, true)


## Beyaz daire + renkli halka + ortada HudIcon (müşteri balonu, modifiye dişlisi, görev onayı).
class _Bubble extends Control:
	var kind: HudIcon.Kind = HudIcon.Kind.WRENCH
	var ring: Color = HudPalette.INK

	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var radius: float = minf(size.x, size.y) * 0.5 - 3.0
		draw_circle(center, radius, HudPalette.TEXT_LIGHT, true, -1.0, true)
		draw_arc(center, radius, 0.0, TAU, 40, ring, 4.0, true)
		HudIcon.draw_icon(self, kind, center, radius * 1.05, HudPalette.INK, HudPalette.TEXT_LIGHT)


## Rozetin arkasında yavaşça dönen sarı ışık hüzmeleri (RewardPopup'takinin rozete ortalanmışı).
class _Rays extends Control:
	const RAYS: int = 16
	const SPEED: float = 0.3

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
		var radius: float = size.y * 0.62
		var step: float = TAU / float(RAYS)
		var ray_color: Color = Color(HudPalette.COIN, 0.15)
		for i: int in RAYS:
			var a: float = _angle + step * float(i)
			draw_colored_polygon(PackedVector2Array([center,
				center + Vector2.from_angle(a) * radius,
				center + Vector2.from_angle(a + step * 0.45) * radius]), ray_color)
		draw_circle(center, radius * 0.32, Color(HudPalette.COIN, 0.1))


## Kasanın kendi 3B modeli, kartın içinde yavaşça döner (yalnızca pencere açıkken çizilir).
class _CratePreview extends SubViewportContainer:
	const SPIN: float = 0.6
	## Dünya kamerasıyla aynı bakış (DecorThumbs.VIEW_DIR).
	const VIEW_DIR: Vector3 = Vector3(0.6408563, 0.42261827, 0.6408563)

	var _entry: Dictionary
	var _pivot: Node3D

	func _init(entry: Dictionary) -> void:
		_entry = entry

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		stretch = true
		var viewport: SubViewport = SubViewport.new()
		viewport.transparent_bg = true
		viewport.own_world_3d = true
		viewport.msaa_3d = GameSettings.subviewport_msaa(Viewport.MSAA_4X)
		add_child(viewport)
		var camera: Camera3D = Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		var env: Environment = Environment.new()   # ortamsız SubViewport ışığı dünyaya sızdırıyordu (Compatibility)
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("D8CFBD")
		env.ambient_light_energy = 0.55
		camera.environment = env
		viewport.add_child(camera)
		var light: DirectionalLight3D = DirectionalLight3D.new()
		light.basis = Basis.looking_at(Vector3(-0.45, -1.0, -0.6).normalized(), Vector3.UP)
		light.light_color = Color("FFF3E0")
		light.light_energy = 1.05
		viewport.add_child(light)
		_pivot = Node3D.new()
		viewport.add_child(_pivot)
		var path: String = String(_entry.get("scene_path", ""))
		if path != "" and ResourceLoader.exists(path):
			var model: Node3D = (load(path) as PackedScene).instantiate() as Node3D
			if model:
				model.scale = Vector3.ONE * float(_entry.get("scale", 1.0))
				_pivot.add_child(model)
		var box: Vector3 = CrateCatalog.world_size()
		var extent: float = maxf((box.x + box.z) * 0.72, box.y * 1.15)
		camera.size = extent * 1.05
		var center: Vector3 = Vector3(0.0, box.y * 0.5, 0.0)
		camera.position = center + VIEW_DIR * 8.0
		camera.basis = Basis.looking_at(-VIEW_DIR, Vector3.UP)

	func _process(delta: float) -> void:
		if _pivot:
			_pivot.rotation.y = fmod(_pivot.rotation.y + delta * SPIN, TAU)
