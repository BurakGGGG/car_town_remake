class_name ReferralTab
extends VBoxContainer
## ARKADAŞLAR › DAVET ET sekmesi (2026-10-23, kullanıcının seçtiği taslak A; docs/ARKADAS_DAVET.md):
##   üst satır: kural ("arkadaşın 3. seviyeye ulaşınca bir ödül açılır…") + sayaç "4 / 10"
##   ödül yolu: 9 basamak kartı (alındı ✓ · AL (postası bekliyor) · SIRADAKİ · kilitli) + altında yol, Şahin sayaç kadar
##              ilerler; sağda koyu altın 10. basamak (EFSANEVİ ARAÇ; hak varsa ARACINI SEÇ)
##   alt: ARKADAŞINI ÇAĞIR (davet kodun + KOPYALA + DAVET LİNKİ PAYLAŞ) · DAVET ETTİKLERİN (KATILDI / N. ÖDÜL HAZIR /
##        SEVİYE x / 3). Kimse yoksa yeni hesapta "SENİ BİR ARKADAŞIN MI ÇAĞIRDI?" kod girişi.
## Ödüller POSTA'dır (MailService): basamağın AL'ı o postayı alır (HUD → MailNotice.claim_now). FriendsScreen kurar;
## mantık ReferralManager'da. Kodla kurulur.

## DAVET LİNKİ PAYLAŞ (FriendsScreen paylaşır: link + kod).
signal share_requested
## Basamağın postası alınsın (posta kimliği, ör. "ref_4").
signal claim_requested(mail_id: String)
## Efsanevi araç seçimi açılsın.
signal pick_requested
## Kısa bildirim (FriendsScreen'in bildirim satırı).
signal notice(text: String)

const FINAL_WIDTH: float = 168.0
const COMPACT_FINAL_WIDTH: float = 124.0
const TILE_HEIGHT: float = 92.0
const COMPACT_TILE_HEIGHT: float = 72.0
const ROAD_HEIGHT: float = 28.0
const ROW_HEIGHT: float = 34.0
const DONE_BG: Color = Color("E9DDC2")
const LOCKED_BG: Color = Color("E6DAC0")
const OK_GREEN: Color = Color("2E8B47")
const OK_GREEN_BG: Color = Color("DDF1E2")
const WAIT_AMBER: Color = Color("8A5A0E")
const DARK_PLATE: Color = Color("2E2A25")

var _referral: ReferralManager
var _social: SocialManager
var _mail: MailService
var _compact: bool = false
var _intro: Label
var _counter: Label
var _counter_bar: ProgressBar
var _tiles: HBoxContainer
var _road: _Road
var _final: PanelContainer
var _code_label: Label
var _share: PlateButton
var _steps: HBoxContainer
var _list_title: Label
var _list: VBoxContainer
var _list_scroll: ScrollContainer
var _code_edit: LineEdit
var _code_notice: Label
var _submitting: bool = false


func _ready() -> void:
	name = "ReferralTab"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override(&"separation", 8)
	_build()


## FriendsScreen açılırken / sekme seçilince: kısa ekran düzeni ve yeniden çizim.
func refresh(compact: bool) -> void:
	_compact = compact
	add_theme_constant_override(&"separation", 5 if compact else 8)
	if _referral == null:
		_referral = get_tree().get_first_node_in_group("referral") as ReferralManager
		_social = get_tree().get_first_node_in_group("social") as SocialManager
		_mail = get_tree().get_first_node_in_group("mail") as MailService
	var count: int = _referral.count if _referral else 0
	var reached: int = mini(count, ReferralRewards.max_tier())
	_intro.text = Loc.t("Arkadaşın oyuna girip %d. seviyeye ulaşınca bir ödül açılır. %d. arkadaşta EFSANEVİ ARACINI SEÇ!") \
		% [ReferralRewards.QUALIFY_LEVEL, ReferralRewards.max_tier()]
	_counter.text = "%d / %d" % [reached, ReferralRewards.max_tier()]
	_counter_bar.value = float(reached) / float(ReferralRewards.max_tier()) * 100.0
	_tiles.add_theme_constant_override(&"separation", 5 if compact else 8)
	_build_tiles(reached)
	_road.reached = reached
	_road.queue_redraw()
	_build_final(reached)
	_code_label.text = SocialNames.display_code(_social.my_code()) if _social else ""
	_steps.visible = not compact
	_build_list()


# --- Kurulum ---------------------------------------------------------------------

func _build() -> void:
	var top: HBoxContainer = _hbox(12)
	_intro = _label(&"HudInkValue", "")
	_intro.name = "Intro"
	_intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_intro.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_intro)
	var pill: PanelContainer = _pill(HudPalette.INK)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pill_row: HBoxContainer = _hbox(8)
	pill.add_child(pill_row)
	_counter = _label(&"HudPlateTitle", "")
	_counter.name = "Counter"
	_counter.add_theme_color_override(&"font_color", HudPalette.PLATE_SELECTED)
	pill_row.add_child(_counter)
	_counter_bar = ProgressBar.new()
	_counter_bar.show_percentage = false
	_counter_bar.custom_minimum_size = Vector2(110.0, 9.0)
	_counter_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_counter_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_bg: StyleBoxFlat = StyleBoxFlat.new()
	bar_bg.bg_color = Color("5E5245")
	bar_bg.set_corner_radius_all(5)
	var bar_fill: StyleBoxFlat = StyleBoxFlat.new()
	bar_fill.bg_color = HudPalette.PLATE_SELECTED
	bar_fill.set_corner_radius_all(5)
	_counter_bar.add_theme_stylebox_override(&"background", bar_bg)
	_counter_bar.add_theme_stylebox_override(&"fill", bar_fill)
	pill_row.add_child(_counter_bar)
	top.add_child(pill)
	add_child(top)

	var road_row: HBoxContainer = _hbox(12)
	add_child(road_row)
	var road_column: VBoxContainer = VBoxContainer.new()
	road_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	road_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	road_column.add_theme_constant_override(&"separation", 4)
	road_row.add_child(road_column)
	_tiles = _hbox(8)
	_tiles.name = "Tiles"
	road_column.add_child(_tiles)
	_road = _Road.new()
	_road.name = "Road"
	_road.custom_minimum_size = Vector2(0.0, ROAD_HEIGHT)
	_road.tiles = _tiles
	road_column.add_child(_road)
	_tiles.sort_children.connect(_road.queue_redraw)   # basamak ortaları kartlar yerleşince belli olur
	_final = PanelContainer.new()
	_final.name = "FinalTile"
	_final.mouse_filter = Control.MOUSE_FILTER_IGNORE
	road_row.add_child(_final)

	var bottom: HBoxContainer = _hbox(12)
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(bottom)
	bottom.add_child(_share_card())
	bottom.add_child(_list_card())


func _share_card() -> PanelContainer:
	var card: PanelContainer = _card()
	card.name = "ShareCard"
	card.size_flags_stretch_ratio = 1.15
	var box: VBoxContainer = card.get_child(0)
	var head: HBoxContainer = _hbox(10)
	head.add_child(_label(&"HudPlateTitle", Loc.t("ARKADAŞINI ÇAĞIR")))
	var sub: Label = _label(&"HudInkCaption", Loc.t("Linkle de kodla da gelebilir. Gelen arkadaşın da hediye alır."))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(sub)
	box.add_child(head)
	var code_row: HBoxContainer = _hbox(10)
	var caption: Label = _label(&"HudInkCaption", Loc.t("DAVET KODUN"))
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	code_row.add_child(caption)
	var code_box: PanelContainer = PanelContainer.new()
	code_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var code_style: StyleBoxFlat = StyleBoxFlat.new()
	code_style.bg_color = Color.WHITE
	code_style.border_color = HudPalette.PLATE_SELECTED_EDGE
	code_style.set_border_width_all(2)
	code_style.set_corner_radius_all(8)
	code_style.content_margin_left = 14.0
	code_style.content_margin_right = 14.0
	code_box.add_theme_stylebox_override(&"panel", code_style)
	_code_label = _label(&"HudPlateTitle", "")
	_code_label.name = "MyCode"
	_code_label.add_theme_font_size_override(&"font_size", 24)
	code_box.add_child(_code_label)
	code_row.add_child(code_box)
	code_row.add_child(_button(Loc.t("KOPYALA"), _on_copy))
	box.add_child(code_row)
	_steps = _how_it_works()
	box.add_child(_steps)
	box.add_child(_spacer(true))
	_share = PlateButton.new()
	_share.name = "ShareButton"
	_share.theme_type_variation = &"HudPlate"
	_share.text = Loc.t("DAVET LİNKİ PAYLAŞ")
	_share.kind = HudIcon.Kind.FRIENDS
	_share.icon_left = true
	_share.highlight = true
	_share.focus_mode = Control.FOCUS_NONE
	_share.pressed.connect(func() -> void: share_requested.emit())
	box.add_child(_share)
	return card


## NASIL ÇALIŞIR: üç adım (paylaş → arkadaşın girer → 3. seviyede ödülün gelir). Kısa ekranda gizlenir.
func _how_it_works() -> HBoxContainer:
	var row: HBoxContainer = _hbox(6)
	row.name = "Steps"
	var texts: Array[String] = [Loc.t("Linkini ya da kodunu paylaş"), Loc.t("Arkadaşın oyunu indirip hesabıyla girer"),
		Loc.t("%d. seviyeye ulaşınca ödülün gelir") % ReferralRewards.QUALIFY_LEVEL]
	for i: int in texts.size():
		var step: HBoxContainer = _hbox(6)
		step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var number: PanelContainer = _pill(HudPalette.PLATE_SELECTED)
		number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		number.add_child(_label(&"HudInkCaption", str(i + 1)))
		step.add_child(number)
		var text: Label = _label(&"HudInkCaption", texts[i])
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		step.add_child(text)
		row.add_child(step)
	return row


func _list_card() -> PanelContainer:
	var card: PanelContainer = _card()
	card.name = "InvitedCard"
	var box: VBoxContainer = card.get_child(0)
	_list_title = _label(&"HudPlateTitle", "")
	box.add_child(_list_title)
	_list_scroll = ScrollContainer.new()
	_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_list_scroll)
	_list = VBoxContainer.new()
	_list.name = "Invited"
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 2)
	_list_scroll.add_child(_list)
	TouchScroll.attach(_list_scroll)
	return card


# --- Ödül yolu -------------------------------------------------------------------

func _build_tiles(reached: int) -> void:
	_clear(_tiles)
	var ready: Array[int] = []
	if _referral:
		ready = _referral.ready_tiers()
	for n: int in range(1, ReferralRewards.max_tier()):
		_tiles.add_child(_tile(n, reached, ready.has(n)))


## n. basamak kartı. Durum: hazır (postası bekliyor: AL) · alındı (✓) · sıradaki · kilitli.
func _tile(n: int, reached: int, ready: bool) -> PanelContainer:
	var entry: Dictionary = ReferralRewards.tier(n)
	var done: bool = n <= reached and not ready
	var next: bool = n == reached + 1
	var tile: PanelContainer = PanelContainer.new()
	tile.name = "Tile%d" % n
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.custom_minimum_size = Vector2(0.0, COMPACT_TILE_HEIGHT if _compact else TILE_HEIGHT)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.set_corner_radius_all(10)
	style.set_content_margin_all(4.0)
	if ready:
		style.bg_color = HudPalette.PLATE_HOVER
		style.border_color = HudPalette.PLATE_SELECTED
		style.set_border_width_all(3)
		style.shadow_color = Color(HudPalette.PLATE_SELECTED, 0.8)
		style.shadow_size = 8
	elif done:
		style.bg_color = DONE_BG
		style.border_color = HudPalette.PLATE_EDGE
		style.set_border_width_all(1)
	elif next:
		style.bg_color = HudPalette.PLATE_HOVER
		style.border_color = HudPalette.PLATE_SELECTED_EDGE
		style.set_border_width_all(2)
	else:
		style.bg_color = LOCKED_BG
		style.border_color = Color(HudPalette.PLATE_EDGE, 0.6)
		style.set_border_width_all(1)
	tile.add_theme_stylebox_override(&"panel", style)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 1)
	tile.add_child(box)
	var head: HBoxContainer = _hbox(2)
	var number: Label = _label(&"HudInkCaption", str(n))
	number.add_theme_color_override(&"font_color", HudPalette.INK if (ready or next) else HudPalette.INK_SOFT)
	head.add_child(number)
	head.add_child(_spacer())
	if done:
		head.add_child(_icon(HudIcon.Kind.CHECK, 14.0, OK_GREEN))
	elif not ready and not next:
		head.add_child(_icon(HudIcon.Kind.LOCK, 12.0, HudPalette.PLATE_EDGE))
	elif next and not ready:
		var tag: Label = _label(&"HudInkCaption", Loc.t("SIRADAKİ"))
		tag.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
		tag.add_theme_font_size_override(&"font_size", 10)
		head.add_child(tag)
	box.add_child(head)
	var faded: float = 1.0 if (ready or next) else (0.7 if done else 0.55)
	var icon: HudIcon = _icon(_tile_icon(entry), 18.0 if _compact else 24.0, HudPalette.INK)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.modulate.a = faded
	box.add_child(icon)
	var value: Label = _label(&"HudInkCaption", _tile_text(entry))
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.add_theme_font_size_override(&"font_size", 10 if _compact else 11)
	value.modulate.a = faded
	value.max_lines_visible = 3
	box.add_child(value)
	if ready:
		# Basamağın tamamı dokunulur; AL küçük altın etiket (düğme olsaydı uzun dillerde ("ABHOLEN") basamağı genişletiyordu)
		var take_tag: PanelContainer = _pill(HudPalette.PLATE_SELECTED)
		var take_label: Label = _label(&"HudInkCaption", Loc.t("AL"))
		take_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		take_label.add_theme_font_size_override(&"font_size", 10)
		take_tag.add_child(take_label)
		box.add_child(take_tag)
		var take: Button = Button.new()
		take.name = "Take%d" % n
		take.flat = true
		take.focus_mode = Control.FOCUS_NONE
		for state: StringName in [&"normal", &"hover", &"focus", &"disabled"]:
			take.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		var pressed: StyleBoxFlat = StyleBoxFlat.new()
		pressed.bg_color = Color(HudPalette.INK, 0.08)
		pressed.set_corner_radius_all(8)
		for state: StringName in [&"pressed", &"hover_pressed"]:
			take.add_theme_stylebox_override(state, pressed)
		take.pressed.connect(func() -> void: claim_requested.emit("ref_%d" % n))
		tile.add_child(take)   # PanelContainer bütün çocuklarını aynı alana yerleştirir: basamağın üstünü kaplar
	return tile


static func _tile_icon(entry: Dictionary) -> HudIcon.Kind:
	if entry.has("choice"):
		return HudIcon.Kind.CAR
	if entry.has("decor") or entry.has("frame"):
		return HudIcon.Kind.CHAIR
	if entry.has("crates"):
		return HudIcon.Kind.BOX
	if entry.has("money_min"):
		return HudIcon.Kind.COIN
	return HudIcon.Kind.GEM


func _tile_text(entry: Dictionary) -> String:
	if int(entry.get("gems", 0)) > 0:
		return "+%d" % int(entry["gems"])   # elmas simgesi üstünde: "GEM" yazısı dar basamakta iki satıra bölünüyordu
	if int(entry.get("money_min", 0)) > 0:
		return "%s ₺" % Hud.format_thousands(MailService.income_money(get_tree(), int(entry["money_min"])))
	for crate: Variant in (entry.get("crates", {}) as Dictionary):
		return MailService.crate_name(StringName(crate))
	if entry.has("decor"):
		return Loc.t("TABELA + ÇERÇEVE")
	return ""


## 10. basamak: koyu altın kart, efsanevi araç resmi; hak varsa ARACINI SEÇ, postası bekliyorsa AL.
func _build_final(reached: int) -> void:
	_clear(_final)
	var total: int = ReferralRewards.max_tier()
	_final.custom_minimum_size = Vector2(COMPACT_FINAL_WIDTH if _compact else FINAL_WIDTH, 0.0)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = DARK_PLATE
	style.border_color = HudPalette.PLATE_SELECTED
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(6.0)
	style.shadow_color = Color(HudPalette.PLATE_SELECTED, 0.35 if reached >= total - 1 else 0.15)
	style.shadow_size = 6
	_final.add_theme_stylebox_override(&"panel", style)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 0)
	_final.add_child(box)
	var head: Label = _label(&"HudInkCaption", Loc.t("%d. ARKADAŞ · BÜYÜK ÖDÜL") % total)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_color_override(&"font_color", HudPalette.PLATE_SELECTED)
	head.add_theme_font_size_override(&"font_size", 11)
	box.add_child(head)
	var thumb: TextureRect = TextureRect.new()
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	thumb.custom_minimum_size = Vector2(0.0, 46.0 if _compact else 64.0)
	var pool: Array[StringName] = CrateCatalog.pool(ReferralRewards.LEGENDARY_CRATE)
	var shown: StringName = &"lambo_huracan" if pool.has(&"lambo_huracan") else (pool[0] if not pool.is_empty() else &"")
	var path: String = ProfileCard.THUMB_DIR + String(shown) + ".png"
	if shown != &"" and ResourceLoader.exists(path):
		thumb.texture = load(path) as Texture2D
	box.add_child(thumb)
	var name_label: Label = _label(&"HudInkValue", Loc.t("EFSANEVİ ARAÇ"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override(&"font_color", HudPalette.TEXT_LIGHT)
	box.add_child(name_label)
	var ready: bool = _referral != null and _referral.ready_tiers().has(total)
	var rights: int = _referral.car_choices if _referral else 0
	if ready:
		var take: PlateButton = _button(Loc.t("AL"), func() -> void: claim_requested.emit("ref_%d" % total), true)
		take.name = "Take%d" % total
		box.add_child(take)
	elif rights > 0:
		var pick: PlateButton = _button(Loc.t("ARACINI SEÇ"), func() -> void: pick_requested.emit(), true)
		pick.name = "PickButton"
		box.add_child(pick)
	else:
		var caption: Label = _label(&"HudInkCaption", Loc.t("SEN SEÇERSİN + %s") % MailService.frame_name(ReferralRewards.FRAME_ENVOY)
			if reached < total else Loc.t("ALINDI"))
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.add_theme_color_override(&"font_color", Color("EBD9A8"))
		caption.add_theme_font_size_override(&"font_size", 10)
		box.add_child(caption)


# --- Davet ettiklerin ------------------------------------------------------------

func _build_list() -> void:
	_clear(_list)
	var invited: Array[Dictionary] = []
	if _referral:
		invited = _referral.invited
	_list_title.text = Loc.t("DAVET ETTİKLERİN %d") % invited.size() if not invited.is_empty() else Loc.t("DAVET ETTİKLERİN")
	_code_edit = null
	if invited.is_empty():
		if _referral and _referral.can_enter_code():
			_add_code_entry()
		else:
			var empty: Label = _label(&"HudInkCaption",
				Loc.t("Henüz kimseyi davet etmedin. Linkini paylaş; arkadaşın %d. seviyeye ulaşınca ilk ödülün gelir.")
				% ReferralRewards.QUALIFY_LEVEL)
			empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_list.add_child(empty)
		return
	var ready: Array[int] = _referral.ready_tiers()
	for entry: Dictionary in invited:
		_list.add_child(_row(entry, ready))


func _row(entry: Dictionary, ready: Array[int]) -> HBoxContainer:
	var uid: String = SaveSafe.s(entry["uid"])
	var person: Dictionary = _friend(uid)
	var row: HBoxContainer = _hbox(10)
	row.name = "Invited_" + uid
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	var avatar: AvatarView = AvatarView.new()
	avatar.custom_minimum_size = Vector2(30.0, 30.0)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art: Dictionary = ProfileCard.avatar_for(get_tree(), person)
	avatar.show_avatar(art.get("texture"), bool(art.get("illustrated", true)), SaveSafe.s(person.get("frame", "")), "")
	row.add_child(avatar)
	var name_text: String = SaveSafe.s(person.get("name", ""))
	var name_label: Label = _label(&"HudInkValue", name_text if not name_text.is_empty() else Loc.t("YENİ OYUNCU"))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(name_label)
	var tier: int = int(entry.get("tier", 0))
	if entry["state"] == "qualified" and tier > 0 and ready.has(tier):
		row.add_child(_status(Loc.t("%d. ÖDÜL HAZIR") % tier, HudPalette.INK, HudPalette.PLATE_SELECTED))
	elif entry["state"] == "qualified":
		row.add_child(_status(Loc.t("KATILDI"), OK_GREEN, OK_GREEN_BG))
	else:
		var level: int = int(person.get("level", 1))
		row.add_child(_status(Loc.t("SEVİYE %d / %d") % [mini(level, ReferralRewards.QUALIFY_LEVEL), ReferralRewards.QUALIFY_LEVEL],
			WAIT_AMBER, Color(HudPalette.PLATE_SELECTED, 0.25)))
	return row


## Yeni hesap, kimse davet edilmemiş: "Seni bir arkadaşın mı çağırdı?" + kod + GİR.
func _add_code_entry() -> void:
	var ask: Label = _label(&"HudInkValue", Loc.t("SENİ BİR ARKADAŞIN MI ÇAĞIRDI?"))
	ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ask.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_child(ask)
	var hint: Label = _label(&"HudInkCaption", Loc.t("Davet kodunu yaz, ikiniz de hediye kazanın (ilk %d gün).") % ReferralRewards.JOIN_DAYS)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_child(hint)
	var line: HBoxContainer = _hbox(8)
	_code_edit = LineEdit.new()
	_code_edit.name = "ReferralCodeEdit"
	_code_edit.placeholder_text = Loc.t("Davet kodu (AY-…)")
	_code_edit.max_length = 9
	_code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_edit.custom_minimum_size = Vector2(0.0, PlateButton.MIN_PLATE_HEIGHT)
	_code_edit.add_theme_color_override(&"font_color", HudPalette.INK)
	_code_edit.add_theme_color_override(&"font_placeholder_color", HudPalette.INK_SOFT)
	_code_edit.add_theme_font_size_override(&"font_size", 18)
	for style_name: StringName in [&"normal", &"focus"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color.WHITE
		style.border_color = HudPalette.PLATE_SELECTED_EDGE if style_name == &"focus" else HudPalette.PLATE_EDGE
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		style.content_margin_left = 10.0
		_code_edit.add_theme_stylebox_override(style_name, style)
	_code_edit.text_submitted.connect(func(_t: String) -> void: _on_submit())
	line.add_child(_code_edit)
	var submit: PlateButton = _button(Loc.t("GİR"), _on_submit, true)
	submit.name = "ReferralCodeSubmit"
	line.add_child(submit)
	_list.add_child(line)
	_code_notice = _label(&"HudInkCaption", "")
	_code_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_code_notice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_notice.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
	_list.add_child(_code_notice)


func _on_submit() -> void:
	if _referral == null or _code_edit == null or _submitting or _code_edit.text.strip_edges().is_empty():
		return
	_submitting = true
	var edit: LineEdit = _code_edit
	var result: String = await _referral.submit_code(edit.text)
	_submitting = false
	var text: String = ReferralManager.status_text(result)
	if is_instance_valid(_code_notice) and _code_notice.is_inside_tree():
		_code_notice.text = text
	notice.emit(text)


func _on_copy() -> void:
	if _social == null:
		return
	DisplayServer.clipboard_set(SocialNames.display_code(_social.my_code()))
	notice.emit(Loc.t("Kodun kopyalandı."))


## Arkadaş listesindeki kişi (davet edilen otomatik arkadaş olur); yoksa boş.
func _friend(uid: String) -> Dictionary:
	if _social:
		for entry: Dictionary in _social.friends:
			if SaveSafe.s(entry.get("uid", "")) == uid:
				return entry
	return {"uid": uid}


# --- Parçalar --------------------------------------------------------------------

func _card() -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = HudPalette.PLATE_HOVER
	style.border_color = Color(HudPalette.PLATE_EDGE, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10.0)
	card.add_theme_stylebox_override(&"panel", style)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 6)
	card.add_child(box)
	return card


func _pill(color: Color) -> PanelContainer:
	var pill: PanelContainer = PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(14)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	pill.add_theme_stylebox_override(&"panel", style)
	return pill


func _status(text: String, ink: Color, bg: Color) -> PanelContainer:
	var pill: PanelContainer = _pill(bg)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var label: Label = _label(&"HudInkCaption", text)
	label.add_theme_color_override(&"font_color", ink)
	pill.add_child(label)
	return pill


func _icon(kind: HudIcon.Kind, icon_size: float, color: Color) -> HudIcon:
	var icon: HudIcon = HudIcon.new()
	icon.kind = kind
	icon.icon_size = icon_size
	icon.color = color
	icon.custom_minimum_size = Vector2(icon_size + 4.0, icon_size + 4.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _button(text: String, callback: Callable, accent: bool = false) -> PlateButton:
	var button: PlateButton = PlateButton.new()
	button.theme_type_variation = &"HudPlateSmall"
	button.text = text
	button.bolts = false
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.highlight = accent
	button.pressed.connect(callback)
	return button


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _hbox(separation: int) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", separation)
	return row


func _spacer(vertical: bool = false) -> Control:
	var spacer: Control = Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if vertical:
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spacer


func _clear(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()


## Basamakların altındaki yol: koyu şerit, ulaşılan basamağa kadar altın, her basamağın ortasında nokta; Şahin
## ulaşılan basamağın altında durur. Basamak ortaları kartlardan okunur (aynı genişlikte kutu).
class _Road:
	extends Control

	const CAR_PATH: String = "res://assets/cars/thumbs/tofas_sahin.png"
	var tiles: HBoxContainer
	var reached: int = 0
	var _car: Texture2D

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if ResourceLoader.exists(CAR_PATH):
			_car = load(CAR_PATH) as Texture2D

	func _draw() -> void:
		var bar: Rect2 = Rect2(Vector2(0.0, size.y * 0.5 - 6.0), Vector2(size.x, 12.0))
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color("4B4641")
		style.set_corner_radius_all(6)
		style.draw(get_canvas_item(), bar)
		var centers: Array[float] = []
		for tile: Node in tiles.get_children():
			var control: Control = tile as Control
			centers.append(control.position.x + control.size.x * 0.5)
		var progress: float = 0.0
		if reached > 0 and not centers.is_empty():
			progress = size.x if reached >= centers.size() + 1 else centers[mini(reached, centers.size()) - 1]
			var fill: StyleBoxFlat = StyleBoxFlat.new()
			fill.bg_color = HudPalette.PLATE_SELECTED
			fill.set_corner_radius_all(6)
			fill.draw(get_canvas_item(), Rect2(bar.position, Vector2(progress, bar.size.y)))
		for i: int in centers.size():
			var done: bool = i < reached
			draw_circle(Vector2(centers[i], size.y * 0.5), 3.5, HudPalette.INK if done else Color("8A7F70"))
		if _car:
			var car_size: Vector2 = Vector2(64.0, 40.0)
			var x: float = clampf(progress - car_size.x * 0.5, 0.0, size.x - car_size.x)
			draw_texture_rect(_car, Rect2(Vector2(x, size.y * 0.5 - car_size.y * 0.62), car_size), false)
