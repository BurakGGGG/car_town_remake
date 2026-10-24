class_name RatePrompt
extends Control
## BİZİ DEĞERLENDİR (2026-10-24, kullanıcı kararı): oyuncu birkaç farklı günde oyuna girdikten sonra Play Store'da
## değerlendirmeye çağıran pencere. ÖDÜLSÜZ: Play politikası değerlendirme karşılığı ödülü yasaklar. Ne zaman açılacağı
## CommunityLinks'te (RATE_FIRST_DAY / RATE_RETRY_DAYS / RATE_MAX_ASKS), sakin anı Hud seçer (Hud._arm_rate_prompt).
## DEĞERLENDİR → mağaza sayfası, bir daha sorulmaz; SONRA → kapanır, birkaç gün sonra en çok bir kez daha.
## "Beğendin mi?" diye sormaz (Google memnun olanı ayıklayan soruyu istemiyor). UiRouter MODAL "rate_prompt";
## ekran TAMAMEN KODLA kurulur.

signal opened
signal closed

const PANEL_WIDTH: float = 400.0

var _community: CommunityLinks
var _root: VBoxContainer
var _closing: bool = false


func _ready() -> void:
	name = "RatePrompt"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # açıkken dünyaya tıklama gitmez
	_build()


func open() -> void:
	if visible:
		return
	_community = get_tree().get_first_node_in_group("community") as CommunityLinks
	var rewards: GemRewards = get_tree().get_first_node_in_group("gem_rewards") as GemRewards
	if _community and rewards:
		_community.mark_rating_asked(rewards.play_days())   # gösterildi: ne seçilirse seçilsin sayılır
	PlateAnim.pop_in(self, _root)
	opened.emit()


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	PlateAnim.pop_out(self, _root, func() -> void:
		hide()
		_closing = false
		closed.emit())


func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center: CenterContainer = FitScroll.center_in(self)
	center.name = "Center"
	_root = VBoxContainer.new()
	_root.name = "Column"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_theme_constant_override(&"separation", 8)
	center.add_child(_root)

	var sign: PlatePanel = PlatePanel.new()
	sign.theme_type_variation = &"HudCarPlate"
	sign.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var title: Label = _label(&"HudSignTitle", Loc.t("BİZİ DEĞERLENDİR"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.add_child(title)
	_root.add_child(sign)

	var info: PlatePanel = PlatePanel.new()
	info.theme_type_variation = &"HudCarPlate"
	info.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 6)
	info.add_child(box)
	box.add_child(_label(&"HudPlateTitle", Loc.t("Birkaç gündür garajdasın!")))
	box.add_child(_wrapped(Loc.t("Auto Yard hakkındaki düşünceni Play Store'da yazar mısın? Her yorumu okuyoruz, oyunu sizin önerilerinizle geliştiriyoruz.")))
	_root.add_child(info)

	var rate: PlateButton = PlateButton.new()
	rate.name = "RateButton"
	rate.theme_type_variation = &"HudPlate"
	rate.kind = HudIcon.Kind.CHECK
	rate.text = Loc.t("DEĞERLENDİR")
	rate.highlight = true
	rate.custom_minimum_size = Vector2(PANEL_WIDTH, 54.0)
	rate.focus_mode = Control.FOCUS_NONE
	rate.pressed.connect(_on_rate)
	_root.add_child(rate)

	var later: PlateButton = PlateButton.new()
	later.name = "LaterButton"
	later.theme_type_variation = &"HudPlateSmall"
	later.text = Loc.t("SONRA")
	later.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	later.focus_mode = Control.FOCUS_NONE
	later.pressed.connect(close)
	_root.add_child(later)


func _on_rate() -> void:
	if _community:
		_community.rate_now()
	close()


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _wrapped(text: String) -> Label:
	var label: Label = _label(&"HudInkCaption", text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(PANEL_WIDTH - 24.0, 0.0)
	return label
