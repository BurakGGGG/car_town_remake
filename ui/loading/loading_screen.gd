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
## İLK AÇILIŞ: çubuk dolunca ekran sönmez; çubuk ve ipucu söner, yerine hesap seçenekleri gelir
## (LoginGate — FACEBOOK / GOOGLE / E-POSTA / misafir). Seçim yapılınca ekran söner. Ekran kökte durdukça
## oyunun açılış akışları (ders, gazete, kasa hatırlatması) bekler.
##
## Görseller 2400×1080 (önemli içerik ortadaki 1920×1080'de, alttaki ~200 piksel sakin — çubuk ve yazı orada); hiç
## görsel yoksa koyu düz zemin. LOADING_IMAGE (Tofaş'lı garaj) motorun açılış ekranının görselidir
## (application/boot_splash/image) — yükleme ekranında yalnız slayt dosyası hiç yoksa görünür.
## SLAYTLAR (2026-10-23, kullanıcı: "hep aynı drag fotosu gelmesin, rastgele gelsin; yükleniyor barı gelir gelmez yeni
## foto gelsin, sadece açılışta Tofaş"): çubuk göründüğü İLK karede rastgele bir SLIDES görseli vardır (açılış ekranı
## dururken, ilk kareden önce yüklenir), ekran açık kaldıkça (giriş seçenekleri dahil) her SLIDE_HOLD'da rastgele
## sıradaki yumuşak geçişle gelir — torba usulü: hepsi gösterilmeden tekrar yok, art arda aynısı yok; LOADING_IMAGE
## dönmez. Eskiden açılış ekranındaki görsel 3,6 sn daha dururdu, PC'de oyun 2,3 sn'de açıldığı için ikinci foto hiç
## görünmüyordu. Çok hızlı açılışta ekran ilk foto en az FIRST_MIN_VIEW görünmeden kalkmaz. Bellekte en çok iki görsel
## durur, sıradaki KENDİ iş parçacığında yüklenir (bkz. _rotate_slide). Yavaş telefon benzetimiyle ölçüm:
## qa/yukleme_slayt_zaman.gd. Slaytlar tools/make_loading_scenes.gd ile çizilir (aynı yerleşim).
##
## UZAKTAN AYAR KAPISI (2026-10-25, kullanıcı: "bakım ve güncelleme ekranı yükleme ekranında, hiç oyuna giremeden gelsin"):
## Main yüklenince oyun KURULMADAN önce config/app'in bu açılıştaki ilk cevabı beklenir (en çok CONFIG_WAIT; ağ yoksa
## cihazdaki son belge geçerli — uçak moduyla atlatılamaz). Zorunlu güncelleme / bakım ya da YENİ SÜRÜM VAR varsa ekran
## burada bekler (at_gate): çubuk ve ipucu söner, AppGate'in kepengi slaytın üstüne iner. Bakım bitince kepenk kalkar ve oyun
## kurulur; YENİ SÜRÜM VAR'da SONRA denince devam edilir.
##
## Sahne dosyası elle yazılmaz: tools/make_loading_scene.gd üretir.

const MAIN_SCENE: String = "res://Main.tscn"
## Arka plan yüklemesinden ÖNCE ana iş parçacığında yüklenmesi gereken betikler (bkz. _ready).
const MAIN_THREAD_FIRST: Array[String] = ["res://ads/admob_provider.gd"]
const LOADING_IMAGE: String = "res://ui/loading/loading_bg.png"
## Yükleme ekranında rastgele sırayla dönen görseller. Dosyası olmayan atlanır (hiçbiri yoksa LOADING_IMAGE durur).
const SLIDES: Array[String] = [
	"res://ui/loading/slides/drag.png",
	"res://ui/loading/slides/showroom.png",
	"res://ui/loading/slides/hurdalik.png",
	"res://ui/loading/slides/kovalamaca.png",
]
## Her görsel bu kadar durur, sonra sıradakine SLIDE_FADE sürede geçilir (sn). Oyun ilk fotodan önce hazırsa ekran ilk
## foto en az FIRST_MIN_VIEW görünene kadar açık kalır.
const SLIDE_HOLD: float = 3.0
## Çubuğun zamana göre tahmini (gerçek ilerleme iri adımlarla gelir): 1 - e^(-t / bu). 1,4 idi — uzun (telefon) yüklemede
## çubuk 4. saniyede %83'e varıp sonra %89'da takılı kalıyordu; şimdi 3 sn ≈ %40, 9 sn ≈ %80.
const ESTIMATE_TIME: float = 3.5
const SLIDE_FADE: float = 0.7
const FIRST_MIN_VIEW: float = 1.0
const THEME_PATH: String = "res://ui/theme/hud_theme.tres"
## Görsel yokken zemin; motorun açılış ekranı rengiyle AYNI (geçiş fark edilmesin).
const BG_COLOR: Color = Color("1E2124")
## İpuçları bu aralıkla değişir (sn); değişim kısa bir solup belirmeyle (TIP_FADE her yön).
const TIP_INTERVAL: float = 2.4
const TIP_FADE: float = 0.12
## Main eklendikten sonra ekranın üstte kaldığı kare sayısı (ilk ağır kareler); ardından HUD'un ön ısıtması (Hud._warm_up,
## birkaç kareye yayılır) beklenir — en çok WARMUP_MAX_WAIT (sn).
const SETTLE_FRAMES: int = 5
const WARMUP_MAX_WAIT: float = 8.0
const FADE_TIME: float = 0.35
## Çubuk %100'de bu kadar durur, sonra giriş seçeneklerine yer açmak için söner (sn).
const GATE_HOLD: float = 0.2
const GATE_SWAP_TIME: float = 0.25
## Main yüklendikten sonra uzaktan ayarın ilk cevabı en çok bu kadar beklenir (sn); gelmezse cihazdaki son belge karar verir.
const CONFIG_WAIT: float = 4.0

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
	"Kişisel rekorunu kır: ilerleme çubuğundaki halka rekor temponu gösterir.",
	"Yarışı kaybedersen aynı rakiple bir kez ücretsiz rövanş yapabilirsin.",
	"Bekleyen müşterilerin sabrı sınırlı: onları çok bekletirsen vazgeçip giderler.",
	"Sen yokken de garajın çalışır: döndüğünde birikmiş kazancın seni bekler.",
	"Hurdalıkta yığınları arayıp parça topla, klasik araçları restore ederek garajına kat.",
]

var _bar: XpLane
var _status: Label
var _percent: Label
var _tip: Label
var _root: Control
var _bottom: MarginContainer
var _shown: float = 0.0
var _elapsed: float = 0.0
var _tip_timer: float = 0.0
var _tip_index: int = 0
var _main: Node
var _settle: int = -1
var _gate_open: bool = false
## Oyun kurulmadan uzaktan ayar kapısında bekleniyor (kepenk açık): AppGate YENİ SÜRÜM VAR'ı burada açar.
var at_gate: bool = false
var _loaded_at: float = -1.0     # Main'in arka plan yüklemesinin bittiği an (_elapsed)
var _art: TextureRect            # görünen görsel
var _art_next: TextureRect       # üstünde belirerek gelen sıradaki
var _slides: Array[String] = []  # var olan SLIDES
var _queue: Array[String] = []   # sıradaki görseller (karışık torba; boşalınca yeniden karılır)
var _current: String = ""        # ekrandaki görsel
var _slide_timer: float = 0.0
var _slide_fading: bool = false
var _next_texture: Texture2D     # sıradaki slayt: beklemenin yarısında yüklenir, sonunda belirir
var _slide_loader: Thread        # sıradaki slaydı yükleyen iş parçacığı (yalnız yükleme sürerken var)
var _leave_pending: bool = false # oyun hazır, ilk foto FIRST_MIN_VIEW dolmadı
var _leaving: bool = false       # ekran sönüyor: yeni slayt geçişi başlamaz

## YAVAŞ TELEFON BENZETİMİ (yalnız QA, qa/yukleme_slayt_zaman.gd; oyunda 0): arka plan yüklemesi en az bu kadar sürmüş
## sayılır (sn) ve oyunun kurulduğu kare bu kadar uzatılır (ms, ana iş parçacığı bekler — telefondaki ilk ağır kare).
static var simulate_load_seconds: float = 0.0
static var simulate_heavy_frame_ms: int = 0
var _main_at: float = -1.0       # Main'in eklendiği an (_elapsed)


func _ready() -> void:
	layer = 128   # oyunun HUD katmanlarının da üstünde
	LaunchReset.run_once()   # test döneminden kalan cihaz kaydı, oyun kurulmadan bir kez (bkz. sınıf)
	_apply_language()
	FontFallback.install()   # ipuçlarında ₺ / → (bkz. sınıf)
	_build()
	# UZAKTAN AYAR: zorunlu güncelleme / bakım kapısı yükleme sürerken de açılabilsin (kökte kalır, sahneden bağımsız)
	AppConfig.ensure(get_tree())
	# İÇERİK PAKETLERİ: cihazda saklananlar kayıt okunmadan ÖNCE bağlanır (paketten alınmış eşyalar katalogda olsun)
	LivePacks.mount_cached()
	# AdMob eklentisinin sınıfları yüklenirken `static var _plugin := _get_plugin(...)` çalışır;
	# masaüstü / düzenleyicide sahte reklam düğümünü KÖKE ekler — arka plan iş parçacığında bu
	# reddediliyordu (sahte reklamlar bozulurdu; Android'de get_singleton, sorun yok). Bu küçük zincir
	# önce ANA iş parçacığında yüklenir. Yalnız ağ AdMob iken: başka ağda AdService bu betiği hiç yüklemez, eklenti
	# kapalıyken (Appodeal) Android'de her açılışta "Native plugin not found" hataları basıyordu (2026-10-23).
	if AdConfig.NETWORK == AdConfig.Network.ADMOB:
		for path: String in MAIN_THREAD_FIRST:
			if ResourceLoader.exists(path):
				load(path)
	# REKLAM: SDK başlatma + ilk ödüllü reklamın yüklenmesi Main yüklenirken başlar (OTO MANŞET ×2 açılışta hazır olsun);
	# AdService kurulunca devralır (AdBoot).
	AdBoot.start_early()
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
	_rotate_slide(delta)
	if _gate_open:
		return
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
			var estimate: float = 1.0 - exp(-_elapsed / ESTIMATE_TIME)
			_show(minf(maxf(real, estimate), 1.0) * 0.9, delta)
		ResourceLoader.THREAD_LOAD_LOADED:
			if _elapsed < simulate_load_seconds:
				_show(minf(1.0 - exp(-_elapsed / ESTIMATE_TIME), 1.0) * 0.9, delta)   # benzetim: yükleme sürüyormuş gibi
				return
			if _hold_at_gate():
				return
			_start_game(ResourceLoader.load_threaded_get(MAIN_SCENE) as PackedScene)
		_:
			push_warning("LoadingScreen: arka plan yüklemesi başarısız, doğrudan geçiliyor")
			set_process(false)
			get_tree().change_scene_to_file(MAIN_SCENE)


## Oyun kurulmadan önce: uzaktan ayarın ilk cevabı beklenir; kapı (güncelleme / bakım) ya da YENİ SÜRÜM VAR varsa beklenir.
## Bekleme başlayınca çubuk ve ipucu söner (kepenk iner), bitince geri gelir. true = bekle.
func _hold_at_gate() -> bool:
	var config: AppConfig = AppConfig.of(get_tree())
	if config == null:
		return false
	if _loaded_at < 0.0:
		_loaded_at = _elapsed
	if not config.is_answered() and _elapsed - _loaded_at < CONFIG_WAIT:
		return true   # cevap bekleniyor: çubuk %90'da durur
	var gate: AppGate = config.get_node_or_null("AppGate") as AppGate
	var hold: bool = config.gate() != AppConfig.GATE_NONE or config.soft_update() \
		or (gate != null and gate.dialog_kind() != &"")
	if hold != at_gate:
		at_gate = hold
		var tween: Tween = create_tween()
		tween.tween_property(_bottom, "modulate:a", 0.0 if hold else 1.0, GATE_SWAP_TIME)
	return hold


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
	# Çökme raporunda iz: bu karenin çiziminde şehrin malzemeleri ilk kez derlenir (2026-10-31: PowerVR sürücüsü açılışta
	# shader derlerken çöktü, bu karede mi ön ısıtmada mı belli değildi). Telemetry düğümü Main'le kurulur, iz sırada
	# bekleyip çizimden önce gider.
	Telemetry.breadcrumb("açılış: oyun sahnesi kuruldu (şehrin ilk 3B karesi)")
	tree.root.add_child(_main)
	tree.current_scene = _main
	_settle = SETTLE_FRAMES
	_main_at = _elapsed
	if simulate_heavy_frame_ms > 0:
		OS.delay_msec(simulate_heavy_frame_ms)


func _warmed_up() -> bool:
	var hud: Node = _main.get_node_or_null(^"HUD") if is_instance_valid(_main) else null
	return hud == null or not ("warmed_up" in hud) or bool(hud.get("warmed_up"))


func _finish_step() -> void:
	if _leave_pending:
		if _elapsed >= FIRST_MIN_VIEW:
			_leave_pending = false
			_fade_out()
		return
	if _settle < 0:
		return
	if _settle > 0:
		_settle -= 1
		return
	if not _warmed_up() and _elapsed - _main_at < WARMUP_MAX_WAIT:
		return   # HUD'un ön ısıtması sürüyor (adımlar ayrı karelerde; aralarda bu ekran çizilir)
	_settle = -1
	_show(1.0, 1.0)
	if LoginGate.wanted(get_tree()):
		_open_login_gate()
		return
	if _elapsed >= FIRST_MIN_VIEW:
		_fade_out()
	else:
		_leave_pending = true   # çok hızlı açılış: ilk foto bir an görünüp kaybolmasın


func _fade_out() -> void:
	_leaving = true
	var tween: Tween = create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(queue_free)


## İlk açılış: dolu çubuk ve ipucu söner, yerlerine giriş seçenekleri gelir; seçimden sonra ekran söner.
func _open_login_gate() -> void:
	_gate_open = true   # süreç açık kalır: slaytlar giriş seçenekleri beklerken de döner
	var tween: Tween = create_tween()
	tween.tween_interval(GATE_HOLD)
	tween.tween_property(_bottom, "modulate:a", 0.0, GATE_SWAP_TIME)
	var gate: LoginGate = LoginGate.new()
	gate.finished.connect(_fade_out)
	_root.add_child(gate)


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
	var tween: Tween = create_tween()
	tween.tween_property(_tip, "modulate:a", 0.0, TIP_FADE)
	tween.tween_callback(func() -> void: _tip.text = Loc.t(TIPS[_tip_index]))
	tween.tween_property(_tip, "modulate:a", 1.0, TIP_FADE)


## Slayt: görsel SLIDE_HOLD durur; yarısında sıradaki KENDİ iş parçacığımızda yüklenmeye başlar, hazırsa sonunda
## üstünde belirir. ResourceLoader.load_threaded_request KULLANILMAZ: oyunun sahnesiyle aynı düşük öncelikli iş havuzunu
## paylaşır (4 çekirdekli telefonda tek iş parçacığı), sahne yüklenirken sıradaki görsel hiç hazır olmuyor, slaytlar
## ancak yükleme bitince (giriş ekranında) dönüyordu — yavaş cihazda oyuncu yükleme boyunca aynı görsele bakıyordu
## (kullanıcı 2026-10-20). Ana iş parçacığında yüklemek de olmazdı: görsel başına ~25 ms (masaüstü), telefonda çubuk takılır.
func _rotate_slide(delta: float) -> void:
	if _slides.size() < 2 or _slide_fading or _leaving:
		return
	_slide_timer += delta
	if _slide_timer >= SLIDE_HOLD * 0.5 and _next_texture == null and _slide_loader == null:
		_slide_loader = Thread.new()
		_slide_loader.start(_load_slide.bind(_next_slide()))
	if _slide_loader != null and not _slide_loader.is_alive():
		var path: String = _next_slide()
		_next_texture = _slide_loader.wait_to_finish() as Texture2D
		_slide_loader = null
		if _next_texture == null:
			push_warning("LoadingScreen: slayt yüklenemedi, atlanıyor: %s" % path)
			_slides.erase(path)
			_queue.erase(path)
			return
	if _slide_timer < SLIDE_HOLD or _next_texture == null:
		return
	_slide_fading = true
	_art_next.texture = _next_texture
	_next_texture = null
	_art_next.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(_art_next, "modulate:a", 1.0, SLIDE_FADE).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(_end_slide_fade)


func _end_slide_fade() -> void:
	_art.texture = _art_next.texture   # önceki görsel bırakılır: bellekte en çok iki görsel
	_art_next.texture = null
	_art_next.modulate.a = 0.0
	_current = _next_slide()
	_queue.pop_front()
	_slide_timer = 0.0
	_slide_fading = false


## Sıradaki görsel (torbanın başı). Torba boşalınca karılarak yeniden dolar; yeni torba ekrandakiyle başlamaz.
func _next_slide() -> String:
	if _queue.is_empty():
		_queue = _slides.duplicate()
		_queue.shuffle()
		if _queue.size() > 1 and _queue[0] == _current:
			_queue.push_back(_queue.pop_front())
	return _queue[0]


## İş parçacığında çalışır: yalnızca görseli yükler (sahneye dokunmaz).
static func _load_slide(path: String) -> Texture2D:
	return ResourceLoader.load(path) as Texture2D


## Ekran kapanırken süren slayt yüklemesi beklenir (iş parçacığı yarıda bırakılamaz).
func _exit_tree() -> void:
	if _slide_loader != null:
		_slide_loader.wait_to_finish()
		_slide_loader = null


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
	for path: String in SLIDES:
		if ResourceLoader.exists(path):
			_slides.append(path)
	# İlk kareden ÖNCE (motorun açılış ekranı hâlâ görünürken) rastgele bir slayt: çubuk onunla birlikte belirir
	var first: Texture2D = null
	if not _slides.is_empty():
		_current = _next_slide()
		_queue.pop_front()
		first = load(_current) as Texture2D
	if first == null and ResourceLoader.exists(LOADING_IMAGE):
		first = load(LOADING_IMAGE) as Texture2D
	if first != null:
		_art = _art_rect()
		_art.texture = first
		_root.add_child(_art)
		_art_next = _art_rect()
		_art_next.modulate.a = 0.0
		_root.add_child(_art_next)

	# Alt şerit: ipucu, çubuk + durum / yüzde
	_bottom = MarginContainer.new()
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	for side: String in ["left", "right"]:
		_bottom.add_theme_constant_override("margin_" + side, 90)
	_bottom.add_theme_constant_override(&"margin_bottom", 34)
	_root.add_child(_bottom)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 12)
	_bottom.add_child(column)

	_tip_index = randi() % TIPS.size()   # her açılış başka ipucuyla başlar (açılış çoğu zaman birkaç saniye)
	_tip = _label(&"HudOutlinedLarge", Loc.t(TIPS[_tip_index]))
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


func _art_rect() -> TextureRect:
	var art: TextureRect = TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED   # ekranı doldurur, kenarlar kırpılır
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return art


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
