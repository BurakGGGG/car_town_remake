class_name AppGate
extends CanvasLayer
## UZAKTAN AYAR PENCERELERİ (AppConfig'in çocuğu, kökte; yükleme ekranının da üstünde):
##   GÜNCELLEME GEREKLİ  sürüm min_code'un altında: tam ekran, kapanmaz; GÜNCELLE mağazayı açar
##   BAKIMDAYIZ          maintenance: tam ekran, kapanmaz; TEKRAR DENE belgeyi yeniden okur (bakım bitince kapı söner)
##   YENİ SÜRÜM VAR      latest_code: GÜNCELLE / SONRA (sürüm başına bir kez)
## DUYURU (notice) 2026-10-25'ten beri pencere değil: HABERLER kutusunda bir haber (Inbox).
## Kapanmayan kapı hemen açılır (oyun dokunuş almaz). Kapatılabilir pencereler oyun SAKİNKEN açılır: HUD'da açık ekran
## ya da ders yok (FounderRewardNotice ile aynı kural) ya da yükleme ekranı kapıda bekliyor (LoadingScreen.at_gate).
## GÖRÜNÜM (2026-10-25, kullanıcı seçimi): garaj KEPENGİ (GateShutter) — yükleme ekranında slaytın üstüne, oyunda dünyanın
## üstüne iner. Yükleme ekranı config'in ilk cevabını bekler, kapı varsa oyunu KURMADAN burada durur (kullanıcı: "hiç oyuna
## giremeden gelsin"). Bakımda POLL_SEC'te bir belge kendiliğinden yeniden okunur: bakım bitince kepenk kalkar, oyun açılır.

const LAYER: int = 130          # LoadingScreen 128'in üstü
const THEME_PATH: String = "res://ui/theme/hud_theme.tres"
const CHECK_SEC: float = 0.5
## Bakım kepengi açıkken belge bu aralıkla kendiliğinden yeniden okunur (sn).
const POLL_SEC: float = 45.0
## TEKRAR DENE'ye basınca düğme bu kadar "KONTROL EDİLİYOR…" der (sn).
const RETRY_FEEDBACK_SEC: float = 1.6
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
var _poll: Timer
var _retry_button: PlateButton


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
	_poll = Timer.new()
	_poll.wait_time = POLL_SEC
	_poll.timeout.connect(_on_poll)
	add_child(_poll)
	_config.changed.connect(_refresh_blocker)
	_refresh_blocker()


## Açık kapı türü (testler / QA): AppConfig.GATE_UPDATE, GATE_MAINTENANCE ya da boş.
func blocker_kind() -> StringName:
	return _blocker_kind


## Açık kapatılabilir pencere: &"soft_update" ya da boş.
func dialog_kind() -> StringName:
	return _dialog_kind


# --- Kapanmayan kapı -----------------------------------------------------------------

func _refresh_blocker() -> void:
	var kind: StringName = _config.gate()
	if kind == _blocker_kind:
		return
	if _blocker:
		(_blocker as GateShutter).leave()   # kepenk kalkar, sonra serbest kalır
		_blocker = null
	_retry_button = null
	_poll.stop()
	_blocker_kind = kind
	if kind == AppConfig.GATE_NONE:
		return
	_close_dialog()   # kapı her şeyin üstünde tek başına durur
	var shutter: GateShutter
	if kind == AppConfig.GATE_UPDATE:
		var text: String = _config.update_text()
		shutter = GateShutter.new(GateShutter.Mode.UPDATE, Loc.t("GÜNCELLEME GEREKLİ"), Loc.t("YENİ SÜRÜM GELDİ!"),
			text if not text.is_empty() else Loc.t("Oynamaya devam etmek için oyunu güncellemen gerekiyor. İlerlemen kaybolmaz."),
			"", Loc.t("Sürümün %s · mağaza açılır, güncelleyip geri dön") % AppInfo.version_name())
		shutter.add_button(Loc.t("GÜNCELLE"), true, _config.open_store)
	else:
		var text: String = _config.maintenance_text()
		shutter = GateShutter.new(GateShutter.Mode.MAINTENANCE, "", Loc.t("BAKIMDAYIZ"),
			text if not text.is_empty() else Loc.t("Kısa bir bakım yapıyoruz. Birazdan tekrar dene."),
			until_text(_config.maintenance_until()), Loc.t("Bakım bitince oyun kendiliğinden açılır"))
		_retry_button = shutter.add_button(Loc.t("TEKRAR DENE"), true, _retry)
		_poll.start()
	_blocker = shutter
	_root.add_child(shutter)


func _retry() -> void:
	_config.refresh()
	if _retry_button == null:
		return
	var button: PlateButton = _retry_button
	button.text = Loc.t("KONTROL EDİLİYOR…")
	button.disabled = true
	await get_tree().create_timer(RETRY_FEEDBACK_SEC).timeout
	if is_instance_valid(button):
		button.text = Loc.t("TEKRAR DENE")
		button.disabled = false


## Bakım kepengi açıkken: belge yeniden okunur (bakım bitince kepenk kendiliğinden kalkar), tahmini dönüş tazelenir.
func _on_poll() -> void:
	_config.refresh()
	if _blocker and _blocker_kind == AppConfig.GATE_MAINTENANCE:
		(_blocker as GateShutter).set_chip(until_text(_config.maintenance_until()))


## "TAHMİNİ DÖNÜŞ 14:30 · YAKLAŞIK 42 DK" (yerel saat) ya da boş.
static func until_text(until: int) -> String:
	var now: int = int(Time.get_unix_time_from_system())
	if until <= 0 or until <= now:
		return ""
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var t: Dictionary = Time.get_datetime_dict_from_unix_time(until + bias)
	var minutes: int = ceili((until - now) / 60.0)
	var left: String = Loc.t("YAKLAŞIK %d DK") % minutes if minutes < 90 else Loc.t("YAKLAŞIK %d SA") % roundi(minutes / 60.0)
	return Loc.t("TAHMİNİ DÖNÜŞ %s") % ("%02d:%02d" % [int(t["hour"]), int(t["minute"])]) + "  ·  " + left


# --- Kapatılabilir pencereler --------------------------------------------------------

func _tick() -> void:
	if _blocker or _dialog:
		_calm = 0.0
		return
	var loading: bool = _at_loading_gate()
	if not _config.soft_update() or not (loading or _is_calm()):
		_calm = 0.0
		return
	_calm += CHECK_SEC
	if _calm < (CHECK_SEC if loading else CALM_SEC):   # yükleme ekranı kapıda bekliyorsa hemen
		return
	_calm = 0.0
	_open_soft_update()


func _open_soft_update() -> void:
	var text: String = _config.update_text()
	_dialog_kind = &"soft_update"
	var shutter: GateShutter = GateShutter.new(GateShutter.Mode.UPDATE, Loc.t("YENİ SÜRÜM VAR"), Loc.t("YENİ SÜRÜM GELDİ!"),
		text if not text.is_empty() else Loc.t("Yeni sürümde düzeltmeler ve yenilikler var. Şimdi güncellemek ister misin?"),
		"", Loc.t("Sürümün %s") % AppInfo.version_name())
	shutter.add_button(Loc.t("GÜNCELLE"), true, func() -> void:
		_config.dismiss_soft_update()
		_config.open_store()
		_close_dialog())
	shutter.add_button(Loc.t("SONRA"), false, func() -> void:
		_config.dismiss_soft_update()
		_close_dialog())
	_dialog = shutter
	_root.add_child(shutter)


func _close_dialog() -> void:
	if _dialog == null:
		return
	var dialog: GateShutter = _dialog as GateShutter
	_dialog = null
	_dialog_kind = &""
	dialog.leave()


## Yükleme ekranı oyunu kurmadan kapıda bekliyor (LoadingScreen.at_gate): YENİ SÜRÜM VAR orada açılır.
func _at_loading_gate() -> bool:
	var loading: Node = get_tree().root.get_node_or_null("LoadingScreen")
	return loading != null and bool(loading.get("at_gate"))


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
