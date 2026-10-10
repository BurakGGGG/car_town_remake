class_name LoadingScreen
extends CanvasLayer
## YÜKLEME EKRANI — oyunun ilk sahnesi (project.godot run/main_scene). Main.tscn'yi ARKA PLANDA
## yükler (ResourceLoader.load_threaded_request): kodun derlenmesi ve sahnenin okunması bu ekran
## dururken olur, altta oyunun XP şeridi dilinde bir ilerleme çubuğu ve dönen ipuçları görünür.
##
## Sahne yüklenince Main kök viewport'a eklenir ve GEÇERLİ SAHNE yapılır (dil değişimi / bulut
## kaydı reload_current_scene ile doğrudan oyunu yeniden yükler, bu ekranı değil). Ekran HEMEN
## kapanmaz: oyunun ilk karesi ağırdır (dünya shader'ları derlenir, kayıt yüklenir, showroom / yarış
## ön ısıtılır — bkz. docs/OPTIMIZASYON_2026_10.md); o süre boyunca ekran üstte kalır, birkaç kare
## oturunca söner. Böylece arada siyah ekran ya da yarıda donmuş oyun görünmez.
##
## Arka plan görseli: LOADING_IMAGE (2400×1080, önemli içerik ortadaki 1920×1080'de, alttaki ~200
## piksel sakin — çubuk ve yazı orada). Dosya yoksa koyu düz zemin. Aynı görsel motorun açılış
## ekranına da (application/boot_splash/image) verilir: dokunuştan oyuna tek, kesintisiz ekran.
##
## Sahne dosyası elle yazılmaz: tools/make_loading_scene.gd üretir.

const MAIN_SCENE: String = "res://Main.tscn"
## Arka plan yüklemesinden ÖNCE ana iş parçacığında yüklenmesi gereken betikler (bkz. _ready).
const MAIN_THREAD_FIRST: Array[String] = ["res://ads/admob_provider.gd"]
const LOADING_IMAGE: String = "res://ui/loading/loading_bg.png"
const THEME_PATH: String = "res://ui/theme/hud_theme.tres"
## Görsel yokken zemin; motorun açılış ekranı rengiyle AYNI (geçiş fark edilmesin).
const BG_COLOR: Color = Color("1E2124")
## İpuçları bu aralıkla değişir (sn).
const TIP_INTERVAL: float = 3.4
## Main eklendikten sonra ekranın üstte kaldığı kare sayısı (ilk ağır kareler).
const SETTLE_FRAMES: int = 5
const FADE_TIME: float = 0.35

## Oyun yüklenirken gösterilen ipuçları (Türkçe = çeviri anahtarı). Oyunun gerçek kurallarıyla
## uyumlu olmalı: kural değişirse buradaki metin de değişir.
const TIPS: Array[String] = [
	"Vitesi ibre YEŞİL dilime girince at: kusursuz vites seni rekora taşır.",
	"Yarışta ışık yeşile dönmeden dokunursan hatalı çıkış yaparsın.",
	"Yeni tamir alanı açarak aynı anda birden çok aracı tamir edebilirsin.",
	"Garajını büyüttükçe daha çok müşteri gelir, ödüller artar.",
	"Aynı arızayı tamir ettikçe o işte ustalık yıldızı kazanırsın.",
	"Günlük ve haftalık görevleri tamamlayarak gem kazan.",
	"Kasalardan hangi aracın hangi oranla çıktığını kasa plakasında görebilirsin.",
	"Arkadaş kodunla arkadaşlarının garajlarını ziyaret edebilirsin.",
	"Garaj değerin araçlarından, geliştirmelerden ve tamir alanlarından oluşur; rütbeni belirler.",
	"Her araçla kişisel rekorunu kır: ilerleme çubuğundaki halka rekor temponu gösterir.",
]

var _bar: XpLane
var _status: Label
var _percent: Label
var _tip: Label
var _root: Control
var _shown: float = 0.0
var _elapsed: float = 0.0
var _tip_timer: float = 0.0
var _tip_index: int = 0
var _main: Node
var _settle: int = -1


func _ready() -> void:
	layer = 128   # oyunun HUD katmanlarının da üstünde
	_apply_language()
	FontFallback.install()   # ipuçlarında ₺ / → (bkz. sınıf)
	_build()
	# AdMob eklentisinin sınıfları yüklenirken `static var _plugin := _get_plugin(...)` çalışır;
	# masaüstü / düzenleyicide sahte reklam düğümünü KÖKE ekler — arka plan iş parçacığında bu
	# reddediliyordu (sahte reklamlar bozulurdu; Android'de get_singleton, sorun yok). Bu küçük zincir
	# önce ANA iş parçacığında yüklenir.
	for path: String in MAIN_THREAD_FIRST:
		if ResourceLoader.exists(path):
			load(path)
	var error: Error = ResourceLoader.load_threaded_request(MAIN_SCENE, "", false)
	if error != OK:
		push_warning("LoadingScreen: arka plan yüklemesi başlamadı (%d), doğrudan geçiliyor" % error)
		get_tree().change_scene_to_file.call_deferred(MAIN_SCENE)


## Dil: oyunun ayar dosyasındaki seçim, yoksa cihaz dili (GameSettings ile aynı kural).
func _apply_language() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	var language: String = ""
	if cfg.load(GameSettings.PATH) == OK:
		language = String(cfg.get_value("general", "language", ""))
	Loc.use(language if Loc.LANGUAGES.has(language) else Loc.device_language())


func _process(delta: float) -> void:
	_elapsed += delta
	_rotate_tip(delta)
	if _main != null:
		_finish_step()
		return
	var progress: Array = []
	match ResourceLoader.load_threaded_get_status(MAIN_SCENE, progress):
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			# Gerçek ilerleme iri adımlarla gelir (tek büyük betiğin derlenmesi uzun sürer): çubuk
			# geri gitmeden, gerçek değerin ve zamana göre yavaşlayan bir tahminin büyüğüne yürür,
			# yükleme bitmeden %90'ı geçmez.
			var real: float = float(progress[0]) if not progress.is_empty() else 0.0
			var estimate: float = 1.0 - exp(-_elapsed / 1.4)
			_show(minf(maxf(real, estimate), 1.0) * 0.9, delta)
		ResourceLoader.THREAD_LOAD_LOADED:
			_start_game(ResourceLoader.load_threaded_get(MAIN_SCENE) as PackedScene)
		_:
			push_warning("LoadingScreen: arka plan yüklemesi başarısız, doğrudan geçiliyor")
			set_process(false)
			get_tree().change_scene_to_file(MAIN_SCENE)


## Sahne hazır: oyun eklenir, geçerli sahne olur; ekran ilk ağır kareler boyunca üstte kalır.
func _start_game(scene: PackedScene) -> void:
	_show(0.95, 1.0)
	_status.text = Loc.t("HAZIRLANIYOR")
	if scene == null:
		set_process(false)
		get_tree().change_scene_to_file(MAIN_SCENE)
		return
	_main = scene.instantiate()
	var tree: SceneTree = get_tree()
	tree.root.add_child(_main)
	tree.current_scene = _main
	_settle = SETTLE_FRAMES


func _finish_step() -> void:
	if _settle < 0:
		return
	_settle -= 1
	if _settle > 0:
		return
	_settle = -1
	_show(1.0, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(queue_free)


func _show(value: float, delta: float) -> void:
	_shown = maxf(_shown, lerpf(_shown, value, clampf(delta * 6.0, 0.0, 1.0)))
	_bar.ratio = _shown
	_percent.text = Loc.percent(str(int(round(_shown * 100.0))))


func _rotate_tip(delta: float) -> void:
	_tip_timer += delta
	if _tip_timer < TIP_INTERVAL:
		return
	_tip_timer = 0.0
	_tip_index = (_tip_index + 1) % TIPS.size()
	_tip.text = Loc.t(TIPS[_tip_index])


# --- Kurulum ---------------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP   # yüklenirken dokunuş oyuna geçmesin
	if ResourceLoader.exists(THEME_PATH):
		_root.theme = load(THEME_PATH)
	add_child(_root)

	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = BG_COLOR
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(backdrop)
	if not ResourceLoader.exists(LOADING_IMAGE):
		# Görsel gelene kadar geçici: ortada oyunun adı (görsel eklenince kendiliğinden kalkar)
		var center: CenterContainer = CenterContainer.new()
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.offset_bottom = -120.0
		_root.add_child(center)
		var title: Label = _label(&"HudOutlined", String(ProjectSettings.get_setting("application/config/name", "")))
		title.add_theme_font_size_override(&"font_size", 64)
		title.add_theme_constant_override(&"outline_size", 14)
		center.add_child(title)
	if ResourceLoader.exists(LOADING_IMAGE):
		var art: TextureRect = TextureRect.new()
		art.texture = load(LOADING_IMAGE)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED   # ekranı doldurur, kenarlar kırpılır
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_root.add_child(art)

	# Alt şerit: ipucu, çubuk + durum / yüzde
	var bottom: MarginContainer = MarginContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	for side: String in ["left", "right"]:
		bottom.add_theme_constant_override("margin_" + side, 90)
	bottom.add_theme_constant_override(&"margin_bottom", 34)
	_root.add_child(bottom)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 12)
	bottom.add_child(column)

	_tip = _label(&"HudOutlinedLarge", Loc.t(TIPS[0]))
	_tip.add_theme_font_size_override(&"font_size", 19)
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.add_theme_constant_override(&"outline_size", 6)
	column.add_child(_tip)

	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 14)
	column.add_child(row)
	_status = _label(&"HudOutlined", Loc.t("YÜKLENİYOR"))
	_status.add_theme_font_size_override(&"font_size", 15)
	_status.add_theme_constant_override(&"outline_size", 5)
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_status)
	_bar = XpLane.new()
	_bar.segments = 16
	_bar.ratio = 0.0
	_bar.custom_minimum_size = Vector2(0.0, 14.0)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_bar)
	_percent = _label(&"HudOutlined", Loc.percent("0"))
	_percent.add_theme_font_size_override(&"font_size", 15)
	_percent.custom_minimum_size = Vector2(52.0, 0.0)
	_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_percent.add_theme_constant_override(&"outline_size", 5)
	_percent.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_percent)


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
