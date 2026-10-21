class_name BanNotice
extends Control
## YASAK PENCERESİ (kullanıcı kararı 2026-10-21: sebep ve bitiş tarihiyle uyarı). ModerationWatch.notice_requested ile
## açılır, oyun sakinken (ekran / ders / kasa panosu / yükleme yok). SOSYAL: oynamaya devam, arkadaşlık · yarış · ziyaret ·
## hediye kapalı. TAM: TAMAM'dan sonra oturum kapanır (misafir). İTİRAZ ET sitenin iletişim sayfasını açar.
## Hud kurar (_setup_gem_store, temalı kök). Ekran TAMAMEN KODLA kurulur.

const PANEL_WIDTH: float = 440.0
const CHECK_SEC: float = 0.5
const CALM_SEC: float = 1.0

var _hud: Hud
var _watch: ModerationWatch
var _column: VBoxContainer
var _box: VBoxContainer
var _title: Label
var _ok: PlateButton
var _pending: Dictionary = {}
var _shown: Dictionary = {}
var _calm: float = 0.0
var _timer: Timer
var _closing: bool = false


func _init(hud: Hud, watch: ModerationWatch) -> void:
	name = "BanNotice"
	_hud = hud
	_watch = watch


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_timer = Timer.new()
	_timer.wait_time = CHECK_SEC
	_timer.timeout.connect(_tick)
	add_child(_timer)
	_watch.notice_requested.connect(func(_ban: Dictionary) -> void: _take())
	_take()   # pencere kurulmadan gelen yasak da gösterilsin


func _take() -> void:
	var ban: Dictionary = _watch.take_notice()
	if ban.is_empty():
		return
	_pending = ban
	_calm = 0.0
	_timer.start()


## Açık pencerenin yasağı (testler): boşsa kapalı.
func shown() -> Dictionary:
	return _shown


func _tick() -> void:
	if visible or _pending.is_empty():
		return
	var tutorial: TutorialDirector = _hud.tutorial
	var calm: bool = _hud.router.top().is_empty() and not (tutorial and tutorial.is_running()) \
		and not (_hud.crate_panel and _hud.crate_panel.visible) \
		and get_tree().root.get_node_or_null("LoadingScreen") == null
	_calm = _calm + CHECK_SEC if calm else 0.0
	if _calm < CALM_SEC:
		return
	_timer.stop()
	_open(_pending)
	_pending = {}


func _open(ban: Dictionary) -> void:
	_shown = ban
	var full: bool = SaveSafe.s(ban.get("kind", "")) == ModerationWatch.KIND_FULL
	_title.text = Loc.t("HESABIN ASKIYA ALINDI") if full else Loc.t("SOSYAL ÖZELLİKLER KISITLANDI")
	for child: Node in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	_box.add_child(_label(&"HudPlateTitle", Loc.t("Sebep: %s") % ModerationWatch.reason_text(ban)))
	var text: String = SaveSafe.s(ban.get("text", ""))
	if not text.is_empty():
		_box.add_child(_wrapped(text))
	_box.add_child(_wrapped(Loc.t("Bitiş: %s") % ModerationWatch.until_text(ban)))
	_box.add_child(_wrapped(Loc.t("Bu hesapla çevrimiçi özellikler kapalı. Oturumun kapatılacak; misafir olarak oynamaya devam edebilirsin. İlerlemen hesabında saklı kalır.")
		if full else Loc.t("Oynamaya devam edebilirsin; bu sürede arkadaşlık, yarış, garaj ziyareti ve hediye kapalı.")))
	var hint: Label = _wrapped(Loc.t("Bir yanlışlık olduğunu düşünüyorsan bize yaz: %s") % Loc.site_url("contact", false))
	hint.modulate.a = 0.7
	_box.add_child(hint)
	_ok.disabled = false
	_closing = false
	modulate.a = 0.0
	show()
	await get_tree().process_frame
	PlateAnim.pop_in(self, _column)


func _close() -> void:
	if _closing:
		return
	_closing = true
	var ban: Dictionary = _shown
	PlateAnim.pop_out(self, _column, func() -> void:
		hide()
		_closing = false
		_shown = {}
		_watch.acknowledge(ban))


func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center: CenterContainer = FitScroll.center_in(self)
	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override(&"separation", 8)
	center.add_child(_column)

	var sign: PlatePanel = PlatePanel.new()
	sign.theme_type_variation = &"HudCarPlate"
	sign.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_title = _label(&"HudSignTitle", "")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.add_child(_title)
	_column.add_child(sign)

	var info: PlatePanel = PlatePanel.new()
	info.theme_type_variation = &"HudCarPlate"
	info.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	_box = VBoxContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override(&"separation", 6)
	info.add_child(_box)
	_column.add_child(info)

	_ok = PlateButton.new()
	_ok.name = "OkButton"
	_ok.theme_type_variation = &"HudPlate"
	_ok.text = Loc.t("TAMAM")
	_ok.kind = HudIcon.Kind.CHECK
	_ok.highlight = true
	_ok.custom_minimum_size = Vector2(PANEL_WIDTH, 54.0)
	_ok.focus_mode = Control.FOCUS_NONE
	_ok.pressed.connect(_close)
	_column.add_child(_ok)

	var appeal: PlateButton = PlateButton.new()
	appeal.name = "AppealButton"
	appeal.theme_type_variation = &"HudPlateSmall"
	appeal.text = Loc.t("İTİRAZ ET")
	appeal.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	appeal.focus_mode = Control.FOCUS_NONE
	appeal.pressed.connect(func() -> void: OS.shell_open(Loc.site_url("contact")))
	_column.add_child(appeal)


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
