class_name AppGate
extends CanvasLayer
## UZAKTAN AYAR PENCERELERİ (AppConfig'in çocuğu, kökte; yükleme ekranının da üstünde):
##   GÜNCELLEME GEREKLİ  sürüm min_code'un altında: tam ekran, kapanmaz; GÜNCELLE mağazayı açar
##   BAKIMDAYIZ          maintenance: tam ekran, kapanmaz; TEKRAR DENE belgeyi yeniden okur (bakım bitince kapı söner)
##   YENİ SÜRÜM VAR      latest_code: GÜNCELLE / SONRA (sürüm başına bir kez)
##   DUYURU              notice: TAMAM (kimlik başına bir kez)
## Kapanmayan kapı hemen açılır (oyun dokunuş almaz). Kapatılabilir pencereler oyun SAKİNKEN açılır: yükleme / giriş
## ekranı yok, HUD'da açık ekran ya da ders yok (FounderRewardNotice ile aynı kural). Ekran TAMAMEN KODLA kurulur.

const LAYER: int = 130          # LoadingScreen 128'in üstü
const THEME_PATH: String = "res://ui/theme/hud_theme.tres"
const PANEL_WIDTH: float = 420.0
const CHECK_SEC: float = 0.5
## Oyun bu kadar sakin kalınca kapatılabilir pencere açılır.
const CALM_SEC: float = 2.0

var _config: AppConfig
var _root: Control
var _blocker: Control
var _blocker_kind: StringName = &""
var _dialog: Control
var _dialog_kind: StringName = &""
var _calm: float = 0.0
var _timer: Timer


func _init(config: AppConfig) -> void:
	name = "AppGate"
	layer = LAYER
	_config = config


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(THEME_PATH):
		_root.theme = load(THEME_PATH)
	add_child(_root)
	_timer = Timer.new()
	_timer.wait_time = CHECK_SEC
	_timer.timeout.connect(_tick)
	add_child(_timer)
	_timer.start()
	_config.changed.connect(_refresh_blocker)
	_refresh_blocker()


## Açık kapı türü (testler / QA): AppConfig.GATE_UPDATE, GATE_MAINTENANCE ya da boş.
func blocker_kind() -> StringName:
	return _blocker_kind


## Açık kapatılabilir pencere: &"soft_update", &"notice" ya da boş.
func dialog_kind() -> StringName:
	return _dialog_kind


# --- Kapanmayan kapı -----------------------------------------------------------------

func _refresh_blocker() -> void:
	var kind: StringName = _config.gate()
	if kind == _blocker_kind:
		return
	if _blocker:
		_blocker.queue_free()
		_blocker = null
	_blocker_kind = kind
	if kind == AppConfig.GATE_NONE:
		return
	_close_dialog()   # kapı her şeyin üstünde tek başına durur
	if kind == AppConfig.GATE_UPDATE:
		var text: String = _config.update_text()
		_blocker = _panel(Loc.t("GÜNCELLEME GEREKLİ"), Loc.t("Oyunun yeni bir sürümü çıktı!"),
			text if not text.is_empty() else Loc.t("Oynamaya devam etmek için oyunu güncellemen gerekiyor. İlerlemen kaybolmaz."),
			"", 0.88)
		_add_button(_blocker, Loc.t("GÜNCELLE"), HudIcon.Kind.CHECK, true, _config.open_store)
	else:
		var text: String = _config.maintenance_text()
		_blocker = _panel(Loc.t("BAKIMDAYIZ"), Loc.t("Garajı biraz topluyoruz."),
			text if not text.is_empty() else Loc.t("Kısa bir bakım yapıyoruz. Birazdan tekrar dene."),
			_until_text(_config.maintenance_until()), 0.88)
		_add_button(_blocker, Loc.t("TEKRAR DENE"), HudIcon.Kind.ROTATE, true, _retry)
	_present(_blocker)


func _retry() -> void:
	_config.refresh()


## "Tahmini dönüş: 14:30" (yerel saat) ya da boş.
static func _until_text(until: int) -> String:
	if until <= 0 or until <= int(Time.get_unix_time_from_system()):
		return ""
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var t: Dictionary = Time.get_datetime_dict_from_unix_time(until + bias)
	return Loc.t("Tahmini dönüş: %s") % ("%02d:%02d" % [int(t["hour"]), int(t["minute"])])


# --- Kapatılabilir pencereler --------------------------------------------------------

func _tick() -> void:
	if _blocker or _dialog:
		_calm = 0.0
		return
	var soft: bool = _config.soft_update()
	var notice: Dictionary = {} if soft else _config.pending_notice()
	if not soft and notice.is_empty():
		_calm = 0.0
		return
	if not _is_calm():
		_calm = 0.0
		return
	_calm += CHECK_SEC
	if _calm < CALM_SEC:
		return
	_calm = 0.0
	if soft:
		_open_soft_update()
	else:
		_open_notice(notice)


func _open_soft_update() -> void:
	var text: String = _config.update_text()
	_dialog_kind = &"soft_update"
	_dialog = _panel(Loc.t("YENİ SÜRÜM VAR"), Loc.t("Oyunun yeni bir sürümü çıktı!"),
		text if not text.is_empty() else Loc.t("Yeni sürümde düzeltmeler ve yenilikler var. Şimdi güncellemek ister misin?"),
		"", 0.45)
	_add_button(_dialog, Loc.t("GÜNCELLE"), HudIcon.Kind.CHECK, true, func() -> void:
		_config.dismiss_soft_update()
		_config.open_store()
		_close_dialog())
	_add_button(_dialog, Loc.t("SONRA"), HudIcon.Kind.NONE, false, func() -> void:
		_config.dismiss_soft_update()
		_close_dialog())
	_show_dialog()


func _open_notice(notice: Dictionary) -> void:
	var title: String = SaveSafe.s(notice.get("title", ""))
	_dialog_kind = &"notice"
	_dialog = _panel(Loc.t("DUYURU"), title, SaveSafe.s(notice.get("text", "")), "", 0.45)
	var id: String = SaveSafe.s(notice.get("id", ""))
	_add_button(_dialog, Loc.t("TAMAM"), HudIcon.Kind.CHECK, true, func() -> void:
		_config.mark_notice_seen(id)
		_close_dialog())
	_show_dialog()


func _show_dialog() -> void:
	_present(_dialog)


## Ekrana koyar; açılış animasyonu bir kare sonra (sütunun boyu belli olsun, pano ortasından büyüsün).
func _present(screen: Control) -> void:
	screen.modulate.a = 0.0
	_root.add_child(screen)
	await get_tree().process_frame
	if is_instance_valid(screen) and screen.is_inside_tree() and not screen.is_queued_for_deletion():
		PlateAnim.pop_in(screen, screen.get_meta(&"column") as Control)


func _close_dialog() -> void:
	if _dialog == null:
		return
	var dialog: Control = _dialog
	_dialog = null
	_dialog_kind = &""
	PlateAnim.pop_out(dialog, dialog.get_meta(&"column") as Control, dialog.queue_free)


## Yükleme / giriş ekranı yok, HUD'da açık ekran ya da ders yok.
func _is_calm() -> bool:
	var tree: SceneTree = get_tree()
	if tree.root.get_node_or_null("LoadingScreen") != null or tree.current_scene == null:
		return false
	var hud: Hud = tree.current_scene.find_child("HUD", true, false) as Hud
	if hud == null:
		return false
	var tutorial: TutorialDirector = hud.tutorial
	return hud.router.top().is_empty() and not (tutorial and tutorial.is_running()) \
		and not (hud.crate_panel and hud.crate_panel.visible)


# --- Yapı ----------------------------------------------------------------------------

## Tam ekran pencere: karartma + tabela + bilgi plakası; düğmeler _add_button ile sütuna eklenir.
func _panel(sign_text: String, heading: String, body: String, footer: String, dim_alpha: float) -> Control:
	var screen: Control = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_STOP   # açıkken oyuna dokunuş gitmez
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, dim_alpha)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(dim)

	# Düz ortalayıcı (FitScroll değil): kısa pano, HUD payı gerekmez; pencere kapanınca serbest bırakılır ve FitScroll'un
	# ertelenmiş yerleşim çağrısı serbest kalmış kaydırıcıyı yakalayıp hata basıyordu
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(center)
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Column"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 8)
	center.add_child(column)
	screen.set_meta(&"column", column)

	var sign: PlatePanel = PlatePanel.new()
	sign.theme_type_variation = &"HudCarPlate"
	sign.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var title: Label = _label(&"HudSignTitle", sign_text)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.add_child(title)
	column.add_child(sign)

	var info: PlatePanel = PlatePanel.new()
	info.theme_type_variation = &"HudCarPlate"
	info.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 6)
	info.add_child(box)
	if not heading.is_empty():
		var head: Label = _label(&"HudPlateTitle", heading)
		head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		head.custom_minimum_size = Vector2(PANEL_WIDTH - 24.0, 0.0)
		box.add_child(head)
	box.add_child(_wrapped(body))
	if not footer.is_empty():
		var hint: Label = _wrapped(footer)
		hint.modulate.a = 0.7
		box.add_child(hint)
	column.add_child(info)
	return screen


func _add_button(screen: Control, text: String, kind: HudIcon.Kind, primary: bool, on_pressed: Callable) -> void:
	var button: PlateButton = PlateButton.new()
	button.theme_type_variation = &"HudPlate" if primary else &"HudPlateSmall"
	button.text = text
	button.kind = kind
	button.highlight = primary
	button.custom_minimum_size = Vector2(PANEL_WIDTH, 54.0 if primary else 0.0)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_pressed)
	(screen.get_meta(&"column") as Control).add_child(button)


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
