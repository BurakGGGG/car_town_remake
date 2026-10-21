class_name PushPrompt
extends Control
## BİLDİRİM ÖNERİSİ (2026-10-17, kullanıcı kararı): telefonun bildirim izni oyun açılışında DEĞİL, İLK YARIŞTAN
## SONRA istenir ve önce bu pencere neden istendiğini anlatır. 2026-10-21'den beri GENEL bildirim: hediye, yarış ve
## duyuru (misafir de açar; hesaba bağlı türler girişten sonra gelir). TAMAM → PushService.enable() (Android 13+ izin penceresi
## + jeton); ŞİMDİ DEĞİL → kapanır. İki durumda da bu cihazda bir daha sorulmaz; oyuncu AYARLAR → SES VE BİLDİRİMLER'den
## açıp kapatabilir. HUD açar (UiRouter MODAL "push_prompt", Hud._tick_push_prompt). Ekran TAMAMEN KODLA kurulur.

signal opened
signal closed

const PANEL_WIDTH: float = 400.0

var _push: PushService
var _root: VBoxContainer
var _ok: PlateButton
var _later: PlateButton
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
	if _push:
		_push.mark_asked()   # gösterildi: ne seçilirse seçilsin bir daha sorulmaz
	_ok.disabled = false
	_ok.text = Loc.t("TAMAM")
	_later.disabled = false
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
	var title: Label = _label(&"HudSignTitle", Loc.t("BİLDİRİMLER"))
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
	box.add_child(_label(&"HudPlateTitle", Loc.t("Hiçbir şeyi kaçırma!")))
	box.add_child(_wrapped(Loc.t("Garajına hediye geldiğinde, bir arkadaşın seni yarışta yendiğinde ve yeni etkinlikler başladığında telefonuna kısa bir haber gelsin.")))
	var hint: Label = _wrapped(Loc.t("İstediğin zaman AYARLAR > SES VE BİLDİRİMLER'den kapatabilirsin."))
	hint.modulate.a = 0.7
	box.add_child(hint)
	_root.add_child(info)

	_ok = PlateButton.new()
	_ok.name = "OkButton"
	_ok.theme_type_variation = &"HudPlate"
	_ok.kind = HudIcon.Kind.CHECK
	_ok.highlight = true
	_ok.custom_minimum_size = Vector2(PANEL_WIDTH, 54.0)
	_ok.focus_mode = Control.FOCUS_NONE
	_ok.pressed.connect(_on_ok)
	_root.add_child(_ok)

	_later = PlateButton.new()
	_later.name = "LaterButton"
	_later.theme_type_variation = &"HudPlateSmall"
	_later.text = Loc.t("ŞİMDİ DEĞİL")
	_later.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	_later.focus_mode = Control.FOCUS_NONE
	_later.pressed.connect(close)
	_root.add_child(_later)


## TAMAM: telefonun izin penceresi (Android 13+) + jeton. Sonucu PushService HUD bildirimiyle söyler.
func _on_ok() -> void:
	if _push == null or _push.is_busy():
		close()
		return
	_ok.disabled = true
	_later.disabled = true
	_ok.text = Loc.t("BİR SANİYE…")
	await _push.enable()
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
