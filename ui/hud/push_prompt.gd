class_name PushPrompt
extends Control
## BİLDİRİM ÖNERİSİ (2026-10-17, kullanıcı kararı): telefonun bildirim izni oyun açılışında DEĞİL, İLK YARIŞTAN
## SONRA istenir ve önce bu pencere neden istendiğini anlatır. 2026-10-21'den beri GENEL bildirim: hediye, yarış ve
## duyuru (misafir de açar; hesaba bağlı türler girişten sonra gelir).
## 2026-11-04 YENİDEN TASARIM (kullanıcı kararı: taslak B "telefon önizlemesi"): solda telefon kilit ekranında örnek
## bildirimler sırayla belirir (oyuncu neye izin verdiğini görür), sağda başlık, açıklama, "+20 GEM" etiketi (ödül
## alınmadıysa), BİLDİRİMLERİ AÇ, ŞİMDİ DEĞİL ve "sonra AYARLAR'dan açabilirsin" notu. Açana 20 gem
## (CommunityLinks.claim_push_reward; Hud bildirim açılınca verir ve ödül penceresini gösterir).
## AÇ → PushService.enable() (Android 13+ izin penceresi + jeton; pencere artık çıkmıyorsa telefonun bildirim ayarı);
## ŞİMDİ DEĞİL → kapanır. İki durumda da bu öneri sürümü bu cihazda bir daha sorulmaz; oyuncu AYARLAR → SES VE
## BİLDİRİMLER'den açıp kapatabilir. HUD açar (UiRouter MODAL "push_prompt", Hud._tick_push_prompt). TAMAMEN KODLA kurulur.

signal opened
signal closed

## Sağ sütun genişliği ve telefonun boyu (HUD birimi).
const TEXT_WIDTH: float = 310.0
const PHONE_SIZE: Vector2 = Vector2(158.0, 278.0)
const PHONE_TILT: float = -3.0
## Örnek bildirimlerin sırayla belirme aralığı, bekleme ve yeniden başlama (sn).
const NOTE_STAGGER: float = 0.9
const NOTE_HOLD: float = 3.2
const PHONE_BODY: Color = Color("1B1E26")
const PHONE_SCREEN: Color = Color("33415E")
const NOTE_BG: Color = Color(1.0, 1.0, 1.0, 0.94)
const NOTE_HEAD: Color = Color("6B6F78")
const PILL_TEXT: Color = Color("F3E8CF")
const APP_ICON: String = "res://assets/branding/launcher_192.png"

var _push: PushService
var _root: Control
var _ok: PlateButton
var _later: PlateButton
var _pill: PanelContainer
var _pill_amount: Label
var _clock: Label
var _notes: Array[Control] = []
var _note_tween: Tween
var _closing: bool = false


func _ready() -> void:
	name = "PushPrompt"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # açıkken dünyaya tıklama gitmez
	_build()


func open() -> void:
	if visible:
		return
	_push = get_tree().get_first_node_in_group("push") as PushService
	var reask: bool = _push != null and _push.wants_reask()
	if _push:
		_push.mark_asked()   # gösterildi: ne seçilirse seçilsin bu sürüm bir daha sorulmaz
	var community: CommunityLinks = get_tree().get_first_node_in_group("community") as CommunityLinks
	_pill.visible = community != null and community.push_reward_open()
	_pill_amount.text = Loc.t("+%d GEM") % CommunityLinks.PUSH_GEMS
	var now: Dictionary = Time.get_datetime_dict_from_system()
	_clock.text = "%02d:%02d" % [int(now.get("hour", 9)), int(now.get("minute", 41))]
	_ok.disabled = false
	_ok.text = Loc.t("BİLDİRİMLERİ AÇ")
	_later.disabled = false
	Telemetry.event(&"push_prompt_show", {"reask": reask, "reward": _pill.visible})
	PlateAnim.pop_in(self, _root)
	_play_notes()
	opened.emit()


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	PlateAnim.pop_out(self, _root, func() -> void:
		hide()
		if _note_tween:
			_note_tween.kill()
		_closing = false
		closed.emit())


func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center: CenterContainer = FitScroll.center_in(self)
	center.name = "Center"
	var card: PlatePanel = PlatePanel.new()
	card.name = "Card"
	card.theme_type_variation = &"HudCarPlate"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(card)
	_root = card
	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	for side: String in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	card.add_child(margin)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 26)
	margin.add_child(row)
	row.add_child(_build_phone())
	row.add_child(_build_text())


# --- Telefon (örnek bildirimler) ---------------------------------------------------------

func _build_phone() -> Control:
	# Kapsayıcılar çocuğun dönüşünü sıfırlar (fit_child_in_rect): eğik telefon kapsayıcı OLMAYAN bir tutucuda durur,
	# tutucu telefonun en küçük boyunu alır (yerleşim ona göre), telefon kendi boyunu tutucudan alır.
	var holder: Control = Control.new()
	holder.name = "Phone"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var body: PanelContainer = PanelContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.custom_minimum_size = PHONE_SIZE
	body.add_theme_stylebox_override(&"panel", _box(PHONE_BODY, 24, 7))
	body.rotation_degrees = PHONE_TILT
	holder.add_child(body)
	var fit: Callable = func() -> void:
		var need: Vector2 = body.get_combined_minimum_size()
		holder.custom_minimum_size = need
		body.size = need
		body.pivot_offset = need * 0.5
	body.minimum_size_changed.connect(fit)
	fit.call_deferred()
	var screen: PanelContainer = PanelContainer.new()
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_theme_stylebox_override(&"panel", _box(PHONE_SCREEN, 18, 7))
	body.add_child(screen)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 6)
	screen.add_child(column)
	var notch: ColorRect = ColorRect.new()
	notch.color = PHONE_BODY
	notch.custom_minimum_size = Vector2(34.0, 8.0)
	notch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	notch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(notch)
	_clock = Label.new()
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock.add_theme_font_size_override(&"font_size", 34)
	_clock.add_theme_color_override(&"font_color", Color.WHITE)
	_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_clock)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0.0, 4.0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(gap)
	var icon: Texture2D = load(APP_ICON) as Texture2D
	_notes.clear()
	_notes.append(_note(icon, Loc.tc("şimdi", "bildirim"), Loc.t("Garajına hediye geldi! Almak için dokun")))
	_notes.append(_note(icon, Loc.t("5 dk önce"), Loc.t("%s yarışta aracını yendi! İntikam almak için dokun") % Loc.t("Emre")))
	_notes.append(_note(icon, Loc.t("1 sa önce"), Loc.t("Hafta sonu etkinliği başladı: ÇİFTE PARA!")))
	for note: Control in _notes:
		column.add_child(note)
	return holder


func _note(icon: Texture2D, when: String, text: String) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override(&"panel", _box(NOTE_BG, 9, 6))
	panel.resized.connect(func() -> void: panel.pivot_offset = Vector2(panel.size.x * 0.5, 0.0))
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 5)
	panel.add_child(row)
	var art: TextureRect = TextureRect.new()
	art.texture = icon
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = Vector2(20.0, 20.0)
	art.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(art)
	var lines: VBoxContainer = VBoxContainer.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_theme_constant_override(&"separation", 0)
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lines)
	var head: Label = Label.new()
	head.text = "AUTO YARD · " + when
	head.add_theme_font_size_override(&"font_size", 7)
	head.add_theme_color_override(&"font_color", NOTE_HEAD)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(head)
	var body: Label = Label.new()
	body.text = text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(PHONE_SIZE.x - 58.0, 0.0)
	body.add_theme_font_size_override(&"font_size", 8)
	body.add_theme_color_override(&"font_color", PHONE_BODY)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(body)
	return panel


## Bildirimler sırayla belirir (saydam + küçük → tam), bekler, birlikte söner, yeniden başlar. Yalnız saydamlık ve
## ölçek oynar: kapsayıcı yerleşimi bozulmaz.
func _play_notes() -> void:
	if _note_tween:
		_note_tween.kill()
	for note: Control in _notes:
		note.modulate.a = 0.0
		note.scale = Vector2(0.9, 0.9)
	_note_tween = create_tween().set_loops()
	for i: int in _notes.size():
		var note: Control = _notes[i]
		_note_tween.tween_interval(NOTE_STAGGER if i > 0 else 0.35)
		_note_tween.tween_property(note, ^"modulate:a", 1.0, 0.25)
		_note_tween.parallel().tween_property(note, ^"scale", Vector2.ONE, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_note_tween.tween_interval(NOTE_HOLD)
	for i: int in _notes.size():   # ilki beklemeden SONRA, diğerleri onunla birlikte söner
		(_note_tween.parallel() if i > 0 else _note_tween).tween_property(_notes[i], ^"modulate:a", 0.0, 0.35)
	_note_tween.tween_callback(func() -> void:
		for note: Control in _notes:
			note.scale = Vector2(0.9, 0.9))


# --- Sağ sütun ---------------------------------------------------------------------------

func _build_text() -> Control:
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Text"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 9)
	column.custom_minimum_size = Vector2(TEXT_WIDTH, 0.0)

	var title: Label = _label(&"HudPlateTitle", Loc.t("Haberin olsun!"))
	title.add_theme_font_size_override(&"font_size", 25)
	column.add_child(title)
	var info: Label = _label(&"HudInkCaption", Loc.t("Hediye geldiğinde, bir arkadaşın seni yarışta yendiğinde ve yeni etkinlik başladığında telefonuna kısa bir haber gelsin."))
	info.add_theme_font_size_override(&"font_size", 12)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(TEXT_WIDTH, 0.0)
	column.add_child(info)

	_pill = PanelContainer.new()
	_pill.name = "RewardPill"
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var pill_box: StyleBoxFlat = _box(HudPalette.INK, 16, 4)
	pill_box.content_margin_left = 6.0
	pill_box.content_margin_right = 12.0
	_pill.add_theme_stylebox_override(&"panel", pill_box)
	var pill_row: HBoxContainer = HBoxContainer.new()
	pill_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill_row.add_theme_constant_override(&"separation", 6)
	_pill.add_child(pill_row)
	var gem: HudIcon = HudIcon.new()
	gem.kind = HudIcon.Kind.GEM
	gem.icon_size = 20.0
	gem.custom_minimum_size = Vector2(24.0, 24.0)
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill_row.add_child(gem)
	_pill_amount = Label.new()
	_pill_amount.add_theme_font_size_override(&"font_size", 16)
	_pill_amount.add_theme_color_override(&"font_color", HudPalette.PLATE_SELECTED)
	_pill_amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pill_amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill_row.add_child(_pill_amount)
	var pill_note: Label = Label.new()
	pill_note.text = Loc.t("açınca hemen hesabında")
	pill_note.add_theme_font_size_override(&"font_size", 10)
	pill_note.add_theme_color_override(&"font_color", PILL_TEXT)
	pill_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pill_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill_row.add_child(pill_note)
	column.add_child(_pill)

	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0.0, 2.0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(gap)

	_ok = PlateButton.new()
	_ok.name = "OkButton"
	_ok.theme_type_variation = &"HudPlate"
	_ok.kind = HudIcon.Kind.BELL
	_ok.icon_left = true
	_ok.highlight = true
	_ok.custom_minimum_size = Vector2(TEXT_WIDTH, 50.0)
	_ok.focus_mode = Control.FOCUS_NONE
	_ok.pressed.connect(_on_ok)
	column.add_child(_ok)

	_later = PlateButton.new()
	_later.name = "LaterButton"
	_later.theme_type_variation = &"HudPlateSmall"
	_later.text = Loc.t("ŞİMDİ DEĞİL")
	_later.custom_minimum_size = Vector2(TEXT_WIDTH, 0.0)
	_later.focus_mode = Control.FOCUS_NONE
	_later.pressed.connect(_on_later)
	column.add_child(_later)

	var hint_row: HBoxContainer = HBoxContainer.new()
	hint_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_row.add_theme_constant_override(&"separation", 5)
	var gear: HudIcon = HudIcon.new()
	gear.kind = HudIcon.Kind.GEAR
	gear.icon_size = 12.0
	gear.color = HudPalette.INK_SOFT
	gear.custom_minimum_size = Vector2(14.0, 14.0)
	gear.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	gear.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_row.add_child(gear)
	var hint: Label = _label(&"HudInkCaption", Loc.t("İstersen sonra AYARLAR > SES VE BİLDİRİMLER'den de açabilirsin."))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(TEXT_WIDTH - 20.0, 0.0)
	hint.modulate.a = 0.85
	hint_row.add_child(hint)
	column.add_child(hint_row)
	return column


## AÇ: telefonun izin penceresi (Android 13+) + jeton; pencere artık çıkmıyorsa telefonun bildirim ayarı açılır.
## Sonucu PushService HUD bildirimiyle söyler; açıldıysa ödül penceresini Hud gösterir.
func _on_ok() -> void:
	Telemetry.event(&"push_prompt_choice", {"choice": "open"})
	if _push == null or _push.is_busy():
		close()
		return
	_ok.disabled = true
	_later.disabled = true
	_ok.text = Loc.t("BİR SANİYE…")
	await _push.enable()
	close()


func _on_later() -> void:
	Telemetry.event(&"push_prompt_choice", {"choice": "later"})
	close()


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


static func _box(color: Color, radius: int, pad: float) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(pad)
	box.anti_aliasing = true
	return box
