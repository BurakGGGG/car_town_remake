class_name Hud
extends CanvasLayer
## Ana HUD — "yol mobilyası / plaka" dili.
## Sol üst: level tabelası + isim plakası + şerit XP + coin/gem.
## Sağ üst: yuvarlak tabela butonları (kamera / ses / AYARLAR dişlisi). Kamera tabelası altında küçük KAMERA
## kutusunu açar (CameraMenu, yazısız yuvarlak tabelalar: fotoğraf · HUD'u gizle · sinema | uzaklaş · yakınlaş ·
## ortala); modlar PhotoMode'dadır.
## Alt: plakalar (GARAJI DÜZENLE / DEPOLARIM / SHOWROOM / GÖREVLER / ARKADAŞLAR / HARİTA) ve seçilince açılan
## araç plakası. PROFİL plakası gizli (2026-10-23: sol üstteki avatar profili açar); GÖREVLER ve ARKADAŞLAR sağ üstten
## alt sıraya indi; ARAÇLAR plakası (cars_button) DEPOLARIM panosunu açar, depoya dokununca araçlar GarageScreen'de.
## Araç satın alma artık alt menüde DEĞİL: haritadaki "CAR PARTS & SHOWROOM" binasına tıklanınca
## açılan MAĞAZA ekranındadır (ShowroomScreen, HUD'un altına kodla eklenir ve "showroom" grubundan
## bulunur). Garaj listesi (CarGallery, OWNED kipi) GarageScreen'in içinde kalır. Showroom açıkken oyun HUD'u gizlenir,
## kapanınca aynen geri gelir — GarageScreen ile aynı davranış.
## PROFİL plakası ve isim plakası PLAYER tabelasını (LoginScreen, kodla eklenir) açar: Google girişi,
## profil / çıkış ve bulut kayıt seçimi. Google hesabıyla girilince isim plakasında hesabın adı yazar
## (CloudSaveManager, "cloud_save" grubu); çıkışta player_name'e döner.
## Alt sıradaki GÖREVLER plakası GÖREVLER tabelasını (MissionScreen: günlük / haftalık / başarım, kodla eklenir) açar;
## alınabilir ödül sayısı plakanın rozetindedir. Sağ üstte tabelaların altında MARKET (ve otoparkta araç varken OTOPARK)
## kalır. Görev tamamlanınca / ödül alınınca kısa bildirim plakası çıkar (QuestManager, "quests" grubu).
## HUD BOYUTU (AYARLAR, GameSettings.hud_scale): sol üst / sağ üst / alt şerit kümeleri kendi sabit köşelerinden
## ölçeklenir (dünya plakaları alt şeritte olduğu için onlarla birlikte); panolar ve tam ekranlar değişmez.
## Sadece görsel katman: değerler setter'larla gelir, butonlar sinyal olarak dışarı verilir.
## Oyun mantığı burada değil: tamir döngüsü için sahnedeki RepairManager ("repair_manager" grubu),
## para için EconomyManager ("economy" grubu) ve XP/seviye için PlayerProgress ("player_progress"
## grubu) bulunur, sinyalleri araç plakasına / sayaçlara
## yansıtılır; TAMİRE AL plakası RepairManager.start_repair'i çağırır. Tamiri biten aracın parası ₺ balonuna (ya da
## araca) dokununca doğrudan toplanır (car_hitbox → RepairManager.collect); plaka açılmaz.
## Ödül geri bildirimi ("+150 ₺  +7 XP") araç plakasının üstünde beliren küçük bir plakayla verilir
## (aynı yerine oturma animasyonu, sonra söner). Bunlar yoksa (ör. önizleme sahnesi) HUD eskisi gibi
## bağımsız çalışır.

signal nav_selected(id: StringName)
signal sound_toggled(enabled: bool)
## direction: +1 yakınlaş, -1 uzaklaş
signal camera_zoom_requested(direction: int)
## KAMERA MENÜSÜ → ORTALA: dünya kamerası açılıştaki görünüme döner.
signal camera_recenter_requested

## Araç bilgi plakası: seçili trafik aracı için tamir içeriğini (RepairPanel) gösterir.
## false yapılırsa show_car_info() plakayı açmaz (eski davranış).
@export var car_info_enabled: bool = true

@export_group("Başlangıç Değerleri (test)")
@export var player_name: String = "Player"
@export_range(1, 99) var level: int = 1
@export_range(0.0, 1.0, 0.01) var xp_ratio: float = 0.35
## Sahnede EconomyManager yoksa (önizleme sahnesi) gösterilecek para.
@export var coins: int = 5000
@export var gems: int = 40

# Sol üst
@onready var level_label: Label = %LevelLabel
@onready var name_plate: PlateButton = %NamePlate
@onready var xp_lane: XpLane = %XpLane
@onready var coin_label: Label = %CoinLabel
@onready var gem_label: Label = %GemLabel

# Sağ üst
@onready var camera_button: PlateButton = %CameraButton
@onready var sound_button: PlateButton = %SoundButton
@onready var camera_controls: VBoxContainer = %CameraControls
@onready var zoom_in_button: PlateButton = %ZoomInButton
@onready var zoom_out_button: PlateButton = %ZoomOutButton

# Alt
@onready var car_info_panel: PlatePanel = %CarInfoPanel
@onready var car_name_label: Label = %CarNameLabel
@onready var car_stats_container: HBoxContainer = %CarStatsContainer
@onready var car_actions_container: HBoxContainer = %CarActionsContainer
@onready var garage_button: PlateButton = %GarageButton
@onready var cars_button: PlateButton = %CarsButton
@onready var shop_button: PlateButton = %ShopButton
@onready var profile_button: PlateButton = %ProfileButton
@onready var garage_screen: GarageScreen = %GarageScreen
## Kodla kurulan tam ekran MAĞAZA / showroom (bina tıklamasıyla ya da MAĞAZA sekmesiyle açılır).
var showroom: ShowroomScreen
## Kodla kurulan PLAYER tabelası (giriş / profil / kayıt seçimi).
var login_screen: LoginScreen
## İlk yarıştan sonra bir kez: "Seni kim yendi, ilk sen duy!" → TAMAM → bildirim izni (PushPrompt).
var push_prompt: PushPrompt
## Oyuna girişte "sen yokken neler oldu" gazetesi (OTO MANŞET, NewsScreen) ve ne zaman açılacağı (NewsFlow).
var news_screen: NewsScreen
var news_flow: NewsFlow
## Arkadaşın davet linki açılınca: davet edenin profil kartı + ARKADAŞ EKLE (InviteScreen, InviteLinks).
var invite_screen: InviteScreen
## Kodla kurulan AYARLAR tabelası ve onu açan dişli tabela (sağ üst).
var settings_screen: SettingsScreen
var settings_button: PlateButton
## Sağ üstte MARKET'in yanındaki GÜNLÜK GİRİŞ merdiveni tabelası (_setup_gem_store) ve merdiven panosu.
var login_ladder_button: LoginLadderButton
var login_ladder_screen: LoginLadderScreen
## Kamera tabelasının altında açılan menü ve onun açtığı FOTOĞRAF / HUD GİZLİ / SİNEMA katmanı.
var camera_menu: CameraMenu
var photo_mode: PhotoMode
## Kodla kurulan GÖREVLER tabelası ve onu açan plaka (alt sırada).
var quest_screen: MissionScreen
## ETKİNLİK PANOSU: canlı etkinlik tabelasına dokununca (modüller ve düğmeleri).
var event_screen: EventScreen
var quest_button: PlateButton
## Kodla kurulan ARKADAŞLAR tabelası ve onu açan plaka (alt sırada, GÖREVLER'in yanında).
var friends_screen: FriendsScreen
var friends_button: PlateButton
## OTOPARK SAYACI: otoparkta araç varken sağ üst sütunda P plakası (docs/GARAJLAR_TASARIM.md §10, depo isteği).
var lot_button: ParkingBadge
## PROFİL (2026-10-16): sol üstte kendi avatarın; arkadaş kartı, profil düzenleme, fotoğraf kırpma, kamera alt panoları.
var avatar_button: AvatarButton
const AVATAR_BUTTON_SIZE: float = 76.0
## Seviye rozeti avatarın sağ altına, dışına doğru taşar (kullanıcı: "level avatarı kapatıyor, küçült, sağ alta al").
const LEVEL_BADGE_SIZE: float = 26.0
const LEVEL_BADGE_OVERHANG: float = 8.0
const LEVEL_BADGE_FONT: int = 12
## Bu panolar açıkken sol üst HUD gizlenir (geniş düzenleme panosu ona yer açarken sağdan taşıyordu; gazete tam sayfa;
## arkadaş kartı 853 birimlik telefonda bloğun sağına itilince 47 birim taşıyordu — ekran taraması 2026-10-17).
const HUD_FREE_SCREENS: Array[StringName] = [&"profile_edit", &"avatar_crop", &"avatar_camera", &"news", &"friend_card"]
var _top_left_hidden_for_edit: bool = false
var friend_card_screen: FriendCardScreen
var profile_edit_screen: ProfileEditScreen
var avatar_cropper: AvatarCropper
var camera_capture: CameraCapture
var _social: SocialManager
var _quests: QuestManager
var _missions: MissionManager
@onready var top_left: MarginContainer = %TopLeft
@onready var top_right: MarginContainer = %TopRight
@onready var bottom: MarginContainer = %Bottom

## Oyun HUD'unun ölçeği (AYARLAR → HUD BOYUTU); 1.0 = tasarım boyu.
var hud_scale: float = 1.0
## Alt şerit büyük HUD'da üst kümelere yetişirse (853 birimlik telefon, %120, kasa sorusu + bildirim: bildirim
## MARKET'in üstüne biniyordu — ekran taraması 2026-10-22) yalnız o an bu tabana kadar küçülür.
const BOTTOM_FIT_MIN: float = 0.8
const BOTTOM_FIT_GAP: float = 6.0
const BOTTOM_FIT_STEP: float = 0.02
var _settings: GameSettings
var _nav_group: ButtonGroup = ButtonGroup.new()
var _nav_ids: Dictionary = {}
var _car_tween: Tween

# Tamir döngüsü (sahnede varsa)
var _repair_panel: RepairPanel
var _repair_manager: RepairManager
var _player_progress: PlayerProgress
## Para toplama ve elmasla bitirme sesleri.
var _sfx: HudSfx
## Ödül penceresi: sayaçların gerçek değeri, pencere kapanana dek bekletilen kısım ve sayma animasyonları.
var _coin_value: int = 0
var _gem_value: int = 0
var _coin_hold: int = 0
var _gem_hold: int = 0
var _counter_tweens: Dictionary = {}
var _economy: EconomyManager
var _repair_target: Node3D
var _notice_plate: PlatePanel
var _notice_label: Label
var _notice_tween: Tween
var _notice_action: Callable = Callable()

# Tamir alanı satın alma plakası (dünyadaki kilitli alana tıklanınca)
var _bays: RepairBayManager
## Satın alma plakası (PurchasePlate) ve aksiyon satırı; ikisi birlikte _bay_group içinde.
var _bay_group: VBoxContainer
var _bay_plate: PurchasePlate
var _bay_buy: PlateButton
var _bay_index: int = -1
var _plate_mode: StringName = &"bay"   # &"bay" ya da &"garage"
var _upgrades: GarageUpgradeManager
var _garage: Node
var _ownership: VehicleOwnership
## Tüm tam ekranların TEK yönlendiricisi (aynı anda bir yer + en fazla bir pano).
var router: UiRouter
var profile_screen: ProfileScreen
## Drag yarışı ekranları (davet panosu → pist → sonuç panosu).
var race_challenge_screen: RaceChallengeScreen
var drag_race_screen: DragRaceScreen
var race_result_screen: RaceResultScreen
## SÜPER ARABA TANITIMI'nın sonu: "BİR GÜN SENİN DE OLACAK!" (tanıtım yarışı kaybedilip GARAJA DÖN'e basılınca).
var supercar_tease_screen: SupercarTeaseScreen
## Ön ısıtma bitti mi (_warm_up). Yükleme ekranı bu olmadan kalkmaz: ilk kullanım takılmaları oyuna taşınmasın.
var warmed_up: bool = false
var _race: RaceManager
var mastery_screen: MasteryScreen
## Avlu dekorasyonu panosu (dünyada avluya dokununca açılır).
var garage_edit_screen: GarageEditScreen
var garage_value_screen: GarageValueScreen
## KOLEKSİYON tabelası (showroom ve garaj ekranından açılır).
var collection_screen: CollectionScreen
## TÜM ARAÇLAR panosu (garajın alt şeridinden açılır: sınıf / nadirlik süzgeci, sıralama).
var all_cars_screen: AllCarsScreen
## GARAJLARIM panosu (garaj ekranının başlığından) ve garajın İÇ YÜKSELTMELER alt panosu.
var car_garages_screen: CarGaragesScreen
## YERLEŞTİR: yeni aracın yeri (GARAJIMA KOY / depo / otopark). Sıra _queue_placement'ta.
var car_placement_screen: CarPlacementScreen
var _placement_queue: Array[StringName] = []
var _placement_timer: Timer
var car_garage_upgrade_screen: CarGarageUpgradeScreen
var junkyard_screen: JunkyardScreen
var restoration_panel: RestorationPanel
var map_screen: MapScreen
var map_button: PlateButton
var gem_store_screen: GemStoreScreen
## Dünyadaki teslimat kasasının AÇ / sonuç plakası.
var crate_panel: CratePanel
var restoration_result: RestorationResult
## SEVİYE ATLADIN ekranı: seviye atlayınca oyun sakinleşince büyük açılır (açılan müşteri / depo / kasa / dekor).
var level_up_screen: LevelUpScreen
## Garajdaki eşyaya basılı tutmak düzenleyiciyi o eşya tutulmuş açar.
var decor_hold: DecorHoldGesture
## SERGİ PLAKASI: ana garajda sergilenen araca dokununca (docs/GARAJLAR_TASARIM.md §10).
var exhibit_plate: ExhibitPlate
## RÖVANŞ: sonuç panosu pisti yeniden açmak için kapanıyor (closed → _on_race_exit çıkış yapmasın).
var _rematch_pending: bool = false
var _new_tiers: Array[StringName] = []   # teslim töreni sürerken açılan restorasyon sınıfları
var _crates: CrateManager
var _delivery: CrateDelivery
var _welcome_timer: Timer
var _welcome_nudges: int = 0
var _blocked_notified: Dictionary = {}   # yer bulamayan kasa uid → uyarıldı mı
## Alt sekme → açtığı ekran.
var _nav_screens: Dictionary = {}
## EĞİTİM: Rıza Usta'nın ders katmanı (temalı kökün en üstünde) ve dersleri oynatan yönetmen.
var tutorial_overlay: TutorialOverlay
var tutorial: TutorialDirector


func _ready() -> void:
	FontFallback.install()   # ₺ ★ → … için paketli yedek yazı tipi (sistem taraması yok; bkz. sınıf)
	camera_controls.visible = false
	car_info_panel.visible = false

	_nav_ids = {
		garage_button: &"garage",
		cars_button: &"cars",
		shop_button: &"shop",
		profile_button: &"profile",
	}
	# GARAJ plakası GARAJI DÜZENLE'yi açar (_on_nav_pressed; yükseltmeler oranın YÜKSELTMELER modunda). ARAÇLAR plakası
	# DEPOLARIM'ı açar (2026-10-23; depoya dokununca o deponun araçları GarageScreen'de), SHOWROOM mağazayı, PROFİL (gizli
	# plaka; sol üst avatar) ilerleme panosunu açar.
	_nav_screens = {
		cars_button: &"car_garages",
		shop_button: &"showroom",
		profile_button: &"profile",
	}
	for button: PlateButton in _nav_ids:
		button.button_group = _nav_group
		button.toggled.connect(_on_nav_toggled.bind(button))
		button.pressed.connect(_on_nav_pressed.bind(button))
	_sync_nav_tab.call_deferred(&"")   # açılışta hiçbir sekme sarı değil (GARAJ yalnızca paneli açıkken)
	# GARAJ plakası artık GARAJI DÜZENLE'yi açar (2026-10-23; eski alt paneldeki GENİŞLET / TAMİR HIZI / TAMİR ALANI
	# düzenleme ekranının YÜKSELTMELER modunda, DETAY / USTALIK PROFİL'de)
	garage_button.text = Loc.t("GARAJI DÜZENLE")
	cars_button.text = Loc.t("DEPOLARIM")   # 2026-10-23: ARAÇLAR plakası DEPOLARIM'ı açar
	_build_router()
	_build_showroom()
	_build_login_screen()
	_build_push_prompt()
	_build_news()
	_build_invites()
	_build_settings()
	_build_camera_menu()
	_build_quests()
	_build_friends()
	_build_lot_counter.call_deferred()   # depo yöneticisi kodla kuruluyor (GarageSystem): bir kare sonra
	_build_progress_screens()
	_build_profile_screens()
	_build_race_screens()
	_build_junkyard_screens()
	_register_screens()

	name_plate.pressed.connect(_on_name_plate_pressed)
	profile_button.pressed.connect(_on_profile_button_pressed)
	camera_button.toggled.connect(_on_camera_toggled)
	sound_button.toggled.connect(_on_sound_toggled)
	# Oyunda henüz ses/müzik varlığı yok: hiçbir şeyi susturmayan düğme yanıltıcı olur. Ses eklenince
	# AUDIO_AVAILABLE true yapılır ve sound_toggled bir bus'a bağlanır.
	sound_button.visible = AUDIO_AVAILABLE
	zoom_in_button.pressed.connect(_on_zoom_in_pressed)
	zoom_out_button.pressed.connect(_on_zoom_out_pressed)

	set_player_name(player_name)
	set_level(level)
	set_xp_ratio(xp_ratio)
	set_coins(coins)
	set_gems(gems)

	_repair_panel = RepairPanel.new()
	_repair_panel.repair_pressed.connect(_on_repair_pressed)
	_repair_panel.collect_pressed.connect(_on_collect_pressed)
	_repair_panel.boost_pressed.connect(_on_repair_boost_pressed)
	_repair_panel.gem_finish_pressed.connect(_on_gem_finish_pressed)
	car_stats_container.add_child(_repair_panel)
	_build_notice_plate()
	_build_bay_plate()
	_build_crate_panel()
	_build_tutorial()
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	top_left.resized.connect(_sync_modal_hud, CONNECT_DEFERRED)   # pano payı blokla birlikte değişsin
	# Alt sütun dizildikten sonra (bildirim / kasa sorusu açılıp kapanınca) ve üst bloklar değişince sığdırılır
	(car_info_panel.get_parent() as Container).sort_children.connect(_fit_bottom)
	top_left.resized.connect(_fit_bottom, CONNECT_DEFERRED)
	top_right.resized.connect(_fit_bottom, CONNECT_DEFERRED)
	get_viewport().size_changed.connect(_fit_bottom, CONNECT_DEFERRED)
	_connect_gameplay.call_deferred()  # sahnedeki yöneticiler hazır olsun


## MOBİL GÜVENLİ ALAN — çentikli / yuvarlak köşeli telefonlarda (20:9) kenar plakaları ekran
## dışında kalmasın diye kenar boşlukları güvenli alana göre büyütülür. Masaüstünde hiçbir şey
## değişmez: yalnızca mobil derlemede uygulanır ve pencere ölçeği (viewport/pencere) hesaba katılır.
func _apply_safe_area() -> void:
	if not OS.has_feature("mobile"):
		return
	# Kümeler ölçeklendiği için pay yerel birime çevrilir: küçük HUD'da da düğmeler kesik alana girmesin
	var insets: PackedInt32Array = safe_area_insets(get_viewport())
	var inset_left: int = ceili(insets[0] / hud_scale)
	var inset_top: int = ceili(insets[1] / hud_scale)
	var inset_right: int = ceili(insets[2] / hud_scale)
	var inset_bottom: int = ceili(insets[3] / hud_scale)
	top_left.add_theme_constant_override(&"margin_left", 10 + inset_left)
	top_left.add_theme_constant_override(&"margin_top", 10 + inset_top)
	top_right.add_theme_constant_override(&"margin_right", 10 + inset_right)
	top_right.add_theme_constant_override(&"margin_top", 10 + inset_top)
	bottom.add_theme_constant_override(&"margin_bottom", 10 + inset_bottom)


## Güvenli alanın kenar payları tuval biriminde [sol, üst, sağ, alt]; masaüstünde hepsi 0.
## Tam ekran katmanlar da (fotoğraf modu) aynı payı kullanır.
static func safe_area_insets(viewport: Viewport) -> PackedInt32Array:
	var insets: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	if not OS.has_feature("mobile"):
		return insets
	var window: Vector2i = DisplayServer.window_get_size()
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	if window.x <= 0 or window.y <= 0:
		return insets
	var scale: Vector2 = viewport.get_visible_rect().size / Vector2(window)
	insets[0] = int(round(float(maxi(safe.position.x, 0)) * scale.x))
	insets[1] = int(round(float(maxi(safe.position.y, 0)) * scale.y))
	insets[2] = int(round(float(maxi(window.x - safe.end.x, 0)) * scale.x))
	insets[3] = int(round(float(maxi(window.y - safe.end.y, 0)) * scale.y))
	return insets


# --- Dış API -----------------------------------------------------------------

## HUD BOYUTU: üç küme kendi sabit noktasından büyür / küçülür (sol üst köşe, sağ üst köşe, alt orta).
func set_hud_scale(value: float) -> void:
	hud_scale = clampf(value, 0.5, 2.0)
	top_right.pivot_offset_ratio = Vector2(1.0, 0.0)
	bottom.pivot_offset_ratio = Vector2(0.5, 1.0)
	for cluster: Control in [top_left, top_right, bottom]:
		cluster.scale = Vector2(hud_scale, hud_scale)
	_apply_safe_area()
	_fit_car_info()
	_sync_modal_hud()
	_fit_bottom()


## Alt şeridin ölçeği: HUD boyutunda sığıyorsa o, sütunun bir öğesi sol üst / sağ üst bloğa yetişiyorsa
## sığana kadar küçülür (en çok BOTTOM_FIT_MIN). Sütun alt ortadan ölçeklendiği için öğenin ekran yeri hesaplanır.
func _fit_bottom() -> void:
	if not is_node_ready():
		return
	var fit: float = hud_scale
	var blocks: Array[Rect2] = []
	for cluster: Control in [top_left, top_right]:
		if cluster.is_visible_in_tree():
			blocks.append(screen_rect(cluster).grow(BOTTOM_FIT_GAP))
	var column: Control = car_info_panel.get_parent() as Control
	if bottom.is_visible_in_tree() and not blocks.is_empty():
		var pivot_local: Vector2 = bottom.get_combined_pivot_offset()
		var pivot: Vector2 = bottom.get_global_transform() * pivot_local
		var lowest: float = minf(hud_scale, BOTTOM_FIT_MIN)
		while fit > lowest and _bottom_hits(column, blocks, pivot, pivot_local, fit):
			fit = maxf(fit - BOTTOM_FIT_STEP, lowest)
	if not bottom.scale.is_equal_approx(Vector2(fit, fit)):
		bottom.scale = Vector2(fit, fit)


func _bottom_hits(column: Control, blocks: Array[Rect2], pivot: Vector2, pivot_local: Vector2, fit: float) -> bool:
	for child: Node in column.get_children():
		var item: Control = child as Control
		if item == null or not item.visible:
			continue
		var local: Rect2 = Rect2(column.position + item.position, item.size)
		var rect: Rect2 = Rect2(pivot + (local.position - pivot_local) * fit, local.size * fit)
		for block: Rect2 in blocks:
			if rect.intersects(block):
				return true
	return false


## Bir HUD öğesinin EKRANDAKİ dikdörtgeni (HUD boyutu ölçeği dahil; get_global_rect ölçeği yok sayar).
static func screen_rect(control: Control) -> Rect2:
	return control.get_global_transform() * Rect2(Vector2.ZERO, control.size)


func set_player_name(value: String) -> void:
	name_plate.text = value.to_upper()


func set_level(value: int) -> void:
	level_label.text = str(value)


## 0.0 - 1.0 arası; bir sonraki level'a ilerleme.
func set_xp_ratio(value: float) -> void:
	xp_lane.ratio = value


func set_coins(value: int) -> void:
	_coin_value = value
	_show_counter(coin_label, _coin_value - _coin_hold)


func set_gems(value: int) -> void:
	_gem_value = value
	_show_counter(gem_label, _gem_value - _gem_hold)


## ÖDÜL PENCERESİ: ödül hesaba geçmiş olsa da sayaçlar ESKİ değerde bekler (pencere açıkken);
## paralar uçup sayaca varınca land_reward ile sayarak artar. Bkz. RewardPopup.
func hold_reward(money: int, gems_amount: int) -> void:
	_coin_hold += maxi(money, 0)
	_gem_hold += maxi(gems_amount, 0)
	_show_counter(coin_label, _coin_value - _coin_hold)
	_show_counter(gem_label, _gem_value - _gem_hold)


func land_reward(money: int, gems_amount: int) -> void:
	if money > 0:
		_coin_hold = maxi(_coin_hold - money, 0)
		_count_counter(coin_label, _coin_value - _coin_hold)
	if gems_amount > 0:
		_gem_hold = maxi(_gem_hold - gems_amount, 0)
		_count_counter(gem_label, _gem_value - _gem_hold)


## Uçan ödülün hedefi: sayacın ikonu (CoinBox / GemBox'ta yazının önündeki ikon).
func counter_target(label: Label) -> Control:
	var icon: Control = label.get_parent().get_child(0) as Control
	return icon if icon else label


## Uçan para / gem sayaca değdi: sayaç kısa bir "pıt" yapar.
func pulse_counter(label: Label) -> void:
	label.pivot_offset = Vector2(0.0, label.size.y * 0.5)
	var tween: Tween = label.create_tween()
	tween.tween_property(label, "scale", Vector2.ONE * 1.25, 0.05)
	tween.tween_property(label, "scale", Vector2.ONE, 0.12)


func _show_counter(label: Label, value: int) -> void:
	var running: Tween = _counter_tweens.get(label) as Tween
	if running and running.is_valid():
		running.kill()
	label.set_meta(&"shown", value)
	label.text = format_thousands(value)


func _count_counter(label: Label, value: int) -> void:
	var from: int = int(label.get_meta(&"shown", value))
	_show_counter(label, from)
	var tween: Tween = label.create_tween()
	tween.tween_method(func(v: float) -> void:
		label.set_meta(&"shown", int(round(v)))
		label.text = format_thousands(int(round(v))), float(from), float(value), 0.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_counter_tweens[label] = tween
	pulse_counter(label)


## Avatar PROFİL plakasında kask yerine görünür; null verilirse kaska döner.
func set_avatar(texture: Texture2D) -> void:
	profile_button.avatar = texture


func select_nav_tab(id: StringName) -> void:
	for button: PlateButton in _nav_ids:
		if _nav_ids[button] == id:
			button.button_pressed = true
			return


## Araç plakasını kısa bir "yerine oturma" animasyonuyla açar (car_info_enabled false ise hiçbir şey göstermez).
func show_car_info(car_name: String) -> void:
	if exhibit_plate:
		exhibit_plate.hide_plate()   # dünyada tek plaka: müşteri / tamir aracı plakası sergi plakasını kapatır
	car_name_label.text = car_name
	if not car_info_enabled:
		return
	_fit_car_info.call_deferred()   # içerik (arıza satırı) bu karede yazılıyor
	if _car_tween:
		_car_tween.kill()
	car_info_panel.modulate.a = 0.0
	car_info_panel.show()
	await get_tree().process_frame  # container boyutu hesaplansın
	car_info_panel.pivot_offset = Vector2(car_info_panel.size.x * 0.5, car_info_panel.size.y)
	car_info_panel.scale = Vector2(0.85, 0.85)
	_car_tween = create_tween().set_parallel(true)
	_car_tween.tween_property(car_info_panel, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_car_tween.tween_property(car_info_panel, "modulate:a", 1.0, 0.12)


func hide_car_info() -> void:
	if _car_tween:
		_car_tween.kill()
	car_info_panel.hide()


## Araç plakası ekrana sığmazsa (dar tuval, 853 birim: arıza satırı "FREN REVİZYONU · 180 sn · +2.070 ₺
## (690 ₺/dk) · +140 XP · USTALIK 0/5" tek satırda plakayı 850 birime çıkarıyordu) sıkışık kipe geçer:
## araç adı ve arıza satırı ikişer satır. Sığdığı sürece eski tek satırlık görünüm kalır.
func _fit_car_info() -> void:
	if not car_info_panel.visible:
		return
	var room: float = get_viewport().get_visible_rect().size.x / hud_scale - 24.0   # plaka ölçekli çizilir
	_set_car_info_compact(false)
	if car_info_panel.get_combined_minimum_size().x > room:
		_set_car_info_compact(true)


func _set_car_info_compact(on: bool) -> void:
	car_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if on else TextServer.AUTOWRAP_OFF
	car_name_label.custom_minimum_size.x = CAR_NAME_COMPACT_WIDTH if on else 0.0
	if _repair_panel:
		_repair_panel.compact = on


## 12500 -> "12.500"
static func format_thousands(value: int) -> String:
	var digits: String = str(absi(value))
	var separator: String = "."   # TR / ES / DE: 1.000 · EN: 1,000 · FR: 1 000 (bölünmez boşluk)
	match Loc.current():
		"en": separator = ","
		"fr": separator = "\u00a0"
	var out: String = ""
	var count: int = 0
	for i: int in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = separator + out
	return ("-" + out) if value < 0 else out


# --- Tamir döngüsü bağlantısı ----------------------------------------------------

## Sıkışık araç plakasında araç adının genişliği (iki satıra kırılır).
const CAR_NAME_COMPACT_WIDTH: float = 130.0
## Aynı anda en fazla bu kadar bildirim beklet (fazlası oyuncuyu geride bırakır).
const NOTICE_QUEUE_MAX: int = 4
## HOŞ GELDİN KUTUSU hatırlatması: ilk bakış (sn), sonraki bakışlar (sn), oturum başına en çok kaç kez.
const WELCOME_NUDGE_FIRST: float = 6.0
const WELCOME_NUDGE_REPEAT: float = 45.0
const WELCOME_NUDGES: int = 3

## Ses sistemi (müzik/SFX varlıkları + bus) bağlı mı? Şimdilik yok: SES düğmesi gizli kalır.
const AUDIO_AVAILABLE: bool = false

var _notice_queue: Array[Dictionary] = []
var _notice_busy: bool = false
## Son bilinen garaj rütbesi (rütbe atlayınca bildirim gösterilir; GarageValue'nun sinyali yoktur).
var _garage_rank: int = 0
## Yarış sonucunda teklif edilen ödüllü reklam bonusu (₺). 0 = teklif yok / verildi.
var _race_bonus_amount: int = 0
## Günlük giriş ×2 reklamı giriş bildiriminden başlatıldı (ödül HUD'da verilir; GÖREVLER düğmesi kendisi verir).
var _ads_bound: AdService = null
## Süre kısaltma reklamı izlenirken kısaltılacak araç.
var _boost_car: Node3D = null
## Seçili parça takılan oyuncu aracı (araç plakası onu gösteriyor); yoksa &"".
var _mod_target: StringName = &""


## TEST DERLEMESİ KISAYOLU (yalnızca debug derlemede): sol üstteki paraya TEST_MONEY_HOLD saniye
## basılı tutmak kasaya TEST_MONEY ekler. Testçi telefonda dekor / garaj denemek için para biriktirmek
## zorunda kalmasın. Sürüm derlemesinde (export-release) OS.is_debug_build() false: hiç kurulmaz.
const TEST_MONEY: int = 10_000_000
const TEST_MONEY_HOLD: float = 1.5


func _setup_test_money() -> void:
	if not OS.is_debug_build():
		return
	var box: Control = coin_label.get_parent() as Control
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	var presses: Array[int] = [0]   # her basış/bırakış sayacı artırır: bırakılan basış zamanlayıcıyı iptal eder
	box.gui_input.connect(func(event: InputEvent) -> void:
		var mb: InputEventMouseButton = event as InputEventMouseButton   # dokunuş fareye çevrilir
		if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		presses[0] += 1
		if not mb.pressed:
			return
		var token: int = presses[0]
		get_tree().create_timer(TEST_MONEY_HOLD).timeout.connect(func() -> void:
			if presses[0] == token and _economy:
				_economy.add_money(TEST_MONEY)
				_show_notice(Loc.t("TEST: +%s ₺") % format_thousands(TEST_MONEY), HudPalette.COIN_DARK, 2.0)))


func _connect_gameplay() -> void:
	_settings = get_tree().get_first_node_in_group("settings") as GameSettings
	if _settings:
		_settings.settings_changed.connect(func() -> void: set_hud_scale(_settings.hud_scale()))
		set_hud_scale(_settings.hud_scale())
	_economy = get_tree().get_first_node_in_group("economy") as EconomyManager
	if _economy:
		_economy.money_changed.connect(set_coins)
		_economy.money_changed.connect(func(_m: int) -> void: _refresh_repair_panel(false))  # bakiye → buton durumu
		set_coins(_economy.money)
		_setup_test_money()
	_player_progress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress
	if _player_progress:
		_player_progress.level_up.connect(func(_l: int) -> void: _refresh_repair_panel(false))
		_player_progress.gems_changed.connect(set_gems)
		_player_progress.xp_changed.connect(_on_xp_changed)
		level_up_screen = LevelUpScreen.new(self)
		get_node("Root").add_child(level_up_screen)   # Root temayı taşır (krem plaka, konturlu yazı)
		_player_progress.level_reward.connect(level_up_screen.add_level)
		set_gems(_player_progress.gems)
		_on_xp_changed(_player_progress.level, _player_progress.xp, _player_progress.xp_to_next())
	_upgrades = get_tree().get_first_node_in_group("garage_upgrades") as GarageUpgradeManager
	_garage = get_tree().get_first_node_in_group("garage_system")
	if _upgrades:
		_upgrades.upgrade_purchased.connect(_on_upgrade_purchased)
	_bays = get_tree().get_first_node_in_group("repair_bays") as RepairBayManager
	if _bays:
		_bays.no_room.connect(func(_i: int) -> void:
			if router.top() != &"garage_edit":   # düzenleme ekranı kendisi söyler
				_show_notice(Loc.t("TAMİR ALANI İÇİN YER YOK\nBİR EŞYAYI TAŞI"), HudPalette.INK, 2.4))
		_bays.bay_unlocked.connect(_on_bay_unlocked)
		_bays.purchase_failed.connect(_on_bay_purchase_failed)
	_sfx = HudSfx.new()
	add_child(_sfx)
	_repair_manager = get_tree().get_first_node_in_group("repair_manager") as RepairManager
	if _repair_manager:
		_repair_manager.gem_finished.connect(func(_car: Node3D) -> void: _sfx.gem_skip())
		_repair_manager.target_changed.connect(_on_repair_target_changed)
		_repair_manager.repair_started.connect(_on_repair_started)
		_repair_manager.repair_slot_freed.connect(_on_repair_slot_freed)
		_repair_manager.repair_progress.connect(_on_repair_progress)
		_repair_manager.repair_ready.connect(_on_repair_ready)
		_repair_manager.repair_collected.connect(_on_repair_collected)
		_repair_manager.repair_cancelled.connect(_on_repair_cancelled)
		_repair_manager.customer_marked.connect(_on_customer_changed)
		_repair_manager.customer_stopped.connect(_on_customer_changed)
		_repair_manager.customer_left.connect(func(car: Node3D) -> void:
			_on_customer_changed(car)
			_show_notice(Loc.t("MÜŞTERİ BEKLEMEKTEN SIKILIP GİTTİ"), HudPalette.INK, 2.0))
	var mastery: JobMastery = get_tree().get_first_node_in_group("job_mastery") as JobMastery
	if mastery:
		mastery.mastery_up.connect(_on_mastery_up)
	_quests = get_tree().get_first_node_in_group("quests") as QuestManager
	if _quests:
		_quests.quests_changed.connect(_refresh_quest_button)
		_quests.quest_completed.connect(_on_quest_completed)
	var restoration_bays: RestorationBays = get_tree().get_first_node_in_group("restoration_bays") as RestorationBays
	if restoration_bays:
		restoration_bays.project_selected.connect(func(id: StringName) -> void:
			if router.place_open():
				return
			restoration_panel.vehicle_id = id
			router.open(&"restoration"))
		# TESLİM TÖRENİ: efektler bitince sonuç plakası; GARAJA AL → araç alandan çıkar
		restoration_bays.finale_ready.connect(func(id: StringName) -> void:
			hide_bay_plate()
			hide_car_info()
			restoration_result.show_result(id, _new_tiers)
			_new_tiers = [])
		restoration_result.done_pressed.connect(restoration_bays.drive_away)
		restoration_bays.finale_finished.connect(func(id: StringName) -> void:
			if restoration_result.visible and restoration_result.vehicle_id == id:
				restoration_result.hide_panel())   # tören atlandı (kayıt değişti)
	# DEPOLARIM: otoparktan depoya geçen araçlar, otopark faturası, inşaat ve iç yükseltme bitti. Otoparka giren yeni
	# aracın yerini YERLEŞTİR sorar (bildirim yok)
	var car_garages: CarGarageManager = get_tree().get_first_node_in_group("car_garages") as CarGarageManager
	if car_garages:
		car_garages.gem_finished.connect(func(_garage: StringName) -> void: _sfx.gem_skip())
		car_garages.waiting_parked.connect(func(ids: Array[StringName]) -> void:
			var text: String = Loc.t("%s OTOPARKTAN DEPOYA GEÇTİ") % _car_name(ids[0]) if ids.size() == 1 \
				else Loc.t("%d ARAÇ OTOPARKTAN DEPOYA GEÇTİ") % ids.size()
			_show_notice(text, HudPalette.COIN_DARK, 2.2))
		car_garages.fee_charged.connect(func(amount: int, cars: int, _periods: int) -> void:
			_show_notice(Loc.t("OTOPARK FATURASI: %d ARAÇ · −%s ₺") % [cars, Hud.format_thousands(amount)],
				HudPalette.DANGER, 2.8))
		car_garages.build_finished.connect(func(garage: StringName) -> void:
			_show_notice(Loc.t("%s HAZIR!") % CarGarageCatalog.display_name(garage), HudPalette.COIN_DARK, 2.4))
		car_garages.upgrade_finished.connect(func(garage: StringName, item: StringName, level: int) -> void:
			_show_notice(Loc.t("%s · %s %d. SEVİYE") % [CarGarageCatalog.display_name(garage),
				CarGarageCatalog.item_name(item), level], HudPalette.COIN_DARK, 2.2))
	# PERFORMANS MODİFİYESİ: takma bitti / parça takıldı / süren takmaya dokunuldu
	var mods: PerformanceModManager = get_tree().get_first_node_in_group("performance_mods") as PerformanceModManager
	if mods:
		mods.gem_finished.connect(func(_id: StringName) -> void: _sfx.gem_skip())
		mods.install_ready.connect(func(id: StringName) -> void:
			_show_notice(Loc.t("PARÇA HAZIR: %s\nTAMİR ALANINDAKİ ARACA DOKUN") % _car_name(id), HudPalette.COIN_DARK, 2.4))
		mods.install_completed.connect(func(id: StringName, category: StringName, stage: int, old_class: String,
				new_class: String) -> void:
			var text: String = Loc.t("TAKILDI: %s · %s") % [PerformanceMods.category_name(id, category),
				PerformanceMods.part_name(id, category, stage)]
			if new_class != old_class:
				text += "\n" + Loc.t("%s → %s SINIFI!") % [old_class, new_class]
			_show_notice(text, HudPalette.COIN_DARK, 2.6))
	var mod_bays: PerformanceBays = get_tree().get_first_node_in_group("performance_bays") as PerformanceBays
	if mod_bays and mods:
		# Parça takılan araca dokunuldu: araç plakasında kalan süre + ELMASLA BİTİR
		mod_bays.job_selected.connect(func(id: StringName) -> void:
			if router.top() != &"" or mods.job_of(id).is_empty():
				return
			hide_bay_plate()
			_mod_target = id
			show_car_info(_car_name(id))
			_refresh_mod_plate())
		mod_bays.job_deselected.connect(func(id: StringName) -> void:
			if _mod_target == id:
				_mod_target = &""
				if _repair_target == null:
					hide_car_info())
		mods.jobs_changed.connect(func() -> void:
			if _mod_target != &"" and not mods.has_job(_mod_target):
				_mod_target = &""   # parça takıldı / araç satıldı
				if _repair_target == null:
					hide_car_info())
		var mod_tick: Timer = Timer.new()
		mod_tick.wait_time = 0.25
		mod_tick.autostart = true
		mod_tick.timeout.connect(_refresh_mod_plate)
		add_child(mod_tick)
	# EŞYAYA BASILI TUT → TAŞI: düzenleyici o eşya parmağın altında tutulmuş açılır
	if get_tree().get_first_node_in_group("garage_editor"):
		decor_hold = DecorHoldGesture.new()
		add_child(decor_hold)
		decor_hold.allowed = func() -> bool:
			return router.top() == &"" and not (tutorial and tutorial.is_running())
		decor_hold.held.connect(func(iid: String, at: Vector2) -> void:
			if router.top() != &"":
				return
			hide_bay_plate()
			hide_car_info()
			exhibit_plate.hide_plate(false)
			garage_edit_screen.grab_on_open(iid, at)
			router.open(&"garage_edit"))
		# Sergideki araca kısa dokunuş: kamera yaklaşır, SERGİ PLAKASI açılır (başka eşyaya dokunuş plakayı kapatır)
		decor_hold.tapped.connect(func(iid: String, _at: Vector2) -> void:
			var decor: DecorManager = get_tree().get_first_node_in_group("decor") as DecorManager
			var item: StringName = StringName(decor.instance(iid).get("item", &"")) if decor else &""
			if GarageDecor.is_vehicle(item):
				show_exhibit(GarageDecor.vehicle_of(item))
			else:
				exhibit_plate.hide_plate())
	exhibit_plate = ExhibitPlate.new()
	get_node("Root").add_child(exhibit_plate)
	exhibit_plate.notice_requested.connect(func(text: String, color: Color) -> void: _show_notice(text, color, 2.4))
	exhibit_plate.mods_requested.connect(func(id: StringName) -> void:
		garage_screen.open_home_mods(id)
		router.open(&"garage"))
	var junkyard: JunkyardManager = get_tree().get_first_node_in_group("junkyard") as JunkyardManager
	if junkyard:
		junkyard.parts_gained.connect(func(part_id: StringName, amount: int, source: StringName) -> void:
			if source == &"repair":
				_show_notice(Loc.t("HURDALIK PARÇASI  +%d %s") % [amount, Loc.t(RestorationCatalog.part_name(part_id))],
					HudPalette.COIN_DARK, 2.0))
		junkyard.tier_unlocked.connect(func(tier_id: StringName) -> void: _new_tiers.append(tier_id))
		junkyard.opened.connect(func() -> void:
			_show_notice(Loc.t("HURDALIK AÇILDI\nHARİTA'DAN NECATİ'YE GİT"), HudPalette.COIN_DARK, 2.6))
	_missions = get_tree().get_first_node_in_group("missions") as MissionManager
	if _missions:
		_missions.missions_changed.connect(_refresh_quest_button)
		_missions.task_completed.connect(func(_kind: StringName, text: String) -> void:
			_show_notice(text, HudPalette.COIN_DARK, 2.0))
		_missions.reward_granted.connect(func(text: String) -> void:
			_show_notice(text, HudPalette.COIN_DARK, 2.2))
	_refresh_quest_button()
	# Garaj rütbesi türetilmiştir: değeri büyütebilen her olaydan sonra bakılır
	_race = get_tree().get_first_node_in_group("race") as RaceManager
	if _race:
		_race.challenge_clicked.connect(_on_challenge_clicked)
		_race.race_finished.connect(_on_race_reward)
	_ownership = get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	if _ownership:
		_ownership.ownership_changed.connect(_check_garage_rank)
		_ownership.vehicle_added.connect(_queue_placement)
		_ownership.paint_changed.connect(func(_id: StringName, _c: Color) -> void: _check_garage_rank())
	if _upgrades:
		_upgrades.levels_changed.connect(_check_garage_rank)
	if _bays:
		_bays.bays_changed.connect(_check_garage_rank)
	_check_garage_rank()
	_connect_crates()
	_connect_social()
	var cloud: CloudSaveManager = get_tree().get_first_node_in_group("cloud_save") as CloudSaveManager
	if cloud:
		cloud.user_changed.connect(_on_cloud_user_changed)
		_on_cloud_user_changed(cloud.get_profile())


## Google hesabının adı isim plakasına; çıkışta / misafirde player_name.
func _on_cloud_user_changed(profile: Dictionary) -> void:
	var display_name: String = String(profile.get("display_name", "")).strip_edges()
	set_player_name(display_name if not display_name.is_empty() else player_name)


func _on_xp_changed(new_level: int, current_xp: int, xp_to_next: int) -> void:
	set_level(new_level)
	set_xp_ratio(float(current_xp) / float(maxi(xp_to_next, 1)))


## Seçili tamir edilebilir araç değişti (null = plaka kapanır).
func _on_repair_target_changed(car: Node3D) -> void:
	_repair_target = car
	if car != null:
		_mod_target = &""   # plaka müşteri aracına geçti
	if car != null:
		hide_bay_plate()
	if car == null:
		hide_car_info()
		return
	var entry: Dictionary = CarCatalog.find_by_scene((car as TrafficVehicle).model.scene_file_path)
	show_car_info(String(entry.get("display_name", car.name)))
	_refresh_repair_panel(false)


## Plakayı hedef aracın durumuna göre kurar (sürmekte olan tamir, tamamlanmış, arızalı, meşgul).
func _refresh_repair_panel(celebrate: bool) -> void:
	if _repair_manager == null or not is_instance_valid(_repair_target):
		return
	var vehicle: TrafficVehicle = _repair_target as TrafficVehicle
	var state: RepairState = _repair_manager.get_state(vehicle)
	if state:
		_repair_panel.set_info(state.repair_type, state.repair_reward)   # ödül işin kendi çarpanıyla
		if state.phase == RepairState.Phase.REPAIRING:
			_repair_panel.show_repairing(state.repair_progress, state.remaining, _boost_offer(vehicle),
				_repair_manager.gem_skip_cost(vehicle))
		else:
			_repair_panel.show_ready()
	elif vehicle.repair_status == TrafficVehicle.RepairStatus.REPAIRED:
		_repair_panel.show_repaired(celebrate)  # ödül metni son set_info'dan (tamir edilen arıza)
	elif vehicle.is_customer():
		# Yol kenarında bekleyen müşteri: arızası plakada görünür (seçim yok), TAMİRE AL onu tamir eder
		_repair_panel.set_player_state(_player_progress.level if _player_progress else 1, _economy.money if _economy else 0)
		_repair_panel.set_issue(vehicle.fault)
		_repair_panel.show_damaged(_repair_manager.is_busy())
	else:
		_repair_panel.show_normal()
	_fit_car_info.call_deferred()


func _on_repair_pressed(_type: RepairType) -> void:
	if _repair_manager and _repair_target:
		_repair_manager.start_repair(_repair_target)  # iş aracın kendi arızasıdır
		_refresh_repair_panel(false)  # başladıysa "TAMİR EDİLİYOR", başlamadıysa güncel kilit/bakiye durumu


## Süren işte "REKLAM İZLE (süre yarıya iner)" sunulabilir mi: uzun iş, daha önce kısaltılmamış,
## reklam politikası uygun ve hazır reklam var.
func _boost_offer(car: Node3D) -> bool:
	var ads: AdService = _ads_service()
	return ads != null and _repair_manager != null and _repair_manager.can_boost(car) \
			and ads.can_offer(AdPolicy.REPAIR_BOOST)


func _on_repair_boost_pressed() -> void:
	var ads: AdService = _ads_service()
	if ads == null or _repair_target == null or not _repair_manager.can_boost(_repair_target):
		_refresh_repair_panel(false)
		return
	if ads.is_busy():
		return   # bir reklam zaten gösteriliyor (çift dokunuş): bekleyen kısaltmayı bozma
	if ads.show_rewarded(AdPolicy.REPAIR_BOOST):
		_boost_car = _repair_target
	_refresh_repair_panel(false)


func _on_collect_pressed() -> void:
	if _repair_manager and _repair_target:
		_repair_manager.collect(_repair_target)


## PARA TOPLA: para + XP verildi → kısa ödül plakası; hedef bu araçsa plaka "TAMAMLANDI"ya geçer.
func _on_repair_collected(car: Node3D, reward: int, xp: int) -> void:
	_sfx.collect()
	_show_notice(Loc.t("+%s ₺   +%d XP") % [format_thousands(reward), xp], HudPalette.COIN_DARK)
	if car == _repair_target:
		_refresh_repair_panel(true)


## Kısa geri bildirim plakası: araç plakasının üstünde, aynı yerine oturma animasyonu; sonra söner.
func _build_notice_plate() -> void:
	_notice_plate = PlatePanel.new()
	_notice_plate.name = "NoticePlate"
	_notice_plate.theme_type_variation = &"HudCarPlate"
	_notice_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice_plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_notice_plate.visible = false
	_notice_plate.gui_input.connect(_on_notice_input)
	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override(&"margin_left", 18)
	margin.add_theme_constant_override(&"margin_right", 18)
	margin.add_theme_constant_override(&"margin_top", 6)
	margin.add_theme_constant_override(&"margin_bottom", 6)
	_notice_label = Label.new()
	_notice_label.theme_type_variation = &"HudInkValue"
	_notice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	margin.add_child(_notice_label)
	_notice_plate.add_child(margin)
	var column: Node = car_info_panel.get_parent()
	column.add_child(_notice_plate)
	column.move_child(_notice_plate, car_info_panel.get_index())


## Dünyadaki kilitli tamir alanına / genişletme tabelasına tıklanınca açılan SATIN ALMA plakası.
## Üç satın almanın (garaj seviyesi, tamir alanı, araç) hepsi aynı hiyerarşiyi kullanır:
## BAŞLIK / alt başlık / FİYAT / etki satırları / aksiyon plakası — bkz. PurchasePlate.
func _build_bay_plate() -> void:
	_bay_group = VBoxContainer.new()
	_bay_group.name = "PurchaseGroup"
	_bay_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bay_group.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bay_group.add_theme_constant_override(&"separation", 6)
	_bay_group.visible = false
	_bay_plate = PurchasePlate.new(230.0)
	_bay_plate.set_centered(true)
	_bay_group.add_child(_bay_plate)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", 8)
	_bay_buy = PlateButton.new()
	_bay_buy.theme_type_variation = &"HudPlateSmall"
	_bay_buy.text = Loc.t("SATIN AL")
	_bay_buy.bolts = false
	_bay_buy.focus_mode = Control.FOCUS_NONE
	_bay_buy.pressed.connect(_on_bay_buy_pressed)
	var cancel: PlateButton = PlateButton.new()
	cancel.theme_type_variation = &"HudPlateSmall"
	cancel.text = Loc.t("VAZGEÇ")
	cancel.bolts = false
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.pressed.connect(hide_bay_plate)
	buttons.add_child(_bay_buy)
	buttons.add_child(cancel)
	_bay_group.add_child(buttons)
	var column: Node = car_info_panel.get_parent()
	column.add_child(_bay_group)
	column.move_child(_bay_group, car_info_panel.get_index())


## GARAJ panelindeki TAMİR ALANI düğmesi: plaka alanın durumuna göre açılır.
func show_bay_plate(index: int) -> void:
	if exhibit_plate:
		exhibit_plate.hide_plate()
	if _bays == null:
		return
	_bay_index = index
	_plate_mode = &"bay"
	_bay_buy.text = Loc.t("SATIN AL")
	hide_car_info()
	var price: String = "%s ₺" % format_thousands(_bays.price(index))
	var status: RepairBayManager.Status = _bays.status(index)
	var effects: PackedStringArray = ProgressionEffects.bay_lines(get_tree(), index)
	match status:
		RepairBayManager.Status.NEEDS_LEVEL:
			# Alanı ortaya çıkaran şey GARAJ seviyesidir (eski metin "TAMİR ALANI Sv." diyordu:
			# o geliştirme artık yok, oyuncuyu yanlış yere yönlendiriyordu)
			price = Loc.t("ÖNCE GARAJI SEVİYE %d'E GENİŞLET") % _bays.required_level(index)
			_bay_buy.disabled = true
		RepairBayManager.Status.TOO_EXPENSIVE:
			price += Loc.t("  ·  PARA YETERSİZ")
			_bay_buy.disabled = true
		RepairBayManager.Status.OPEN:
			price = Loc.t("AÇIK")
			effects = PackedStringArray()
			_bay_buy.disabled = true
		_:
			_bay_buy.disabled = false
	_bay_plate.set_content(Loc.t("TAMİR ALANI %d") % (index + 1), "", price, effects)
	_bay_group.show()


## Dünyadaki "GARAJI GENİŞLET" tabelasına tıklandı: garajın fiziksel seviyesini satın alma plakası.
## Bu, tamir alanı satın almadan AYRI bir işlemdir (garaj büyür, alan yine ayrıca açılır).
func show_expansion_plate() -> void:
	if _upgrades == null:
		return
	_plate_mode = &"garage"
	_bay_index = -1
	hide_car_info()
	var id: StringName = GarageUpgradeManager.GARAGE_ID
	var next_level: int = _upgrades.level(id) + 1
	var subtitle: String = Loc.t("SEVİYE %d") % next_level
	var price: String = Loc.t("MAKSİMUM")
	var effects: PackedStringArray = PackedStringArray()
	if _upgrades.is_max(id):
		subtitle = Loc.t("SEVİYE %d") % _upgrades.level(id)
		_bay_buy.disabled = true
	else:
		var cost: int = _upgrades.next_cost(id)
		var affordable: bool = _economy == null or _economy.can_afford(cost)
		price = "%s ₺%s" % [format_thousands(cost), "" if affordable else Loc.t("  ·  PARA YETERSİZ")]
		effects = ProgressionEffects.garage_level_lines(get_tree(), next_level)
		_bay_buy.disabled = not affordable
	_bay_plate.set_content(Loc.t("GARAJI GENİŞLET"), subtitle, price, effects)
	_bay_buy.text = Loc.t("GENİŞLET")
	_bay_group.show()


func hide_bay_plate() -> void:
	_bay_index = -1
	_plate_mode = &"bay"
	_bay_buy.text = Loc.t("SATIN AL")
	_bay_group.hide()


func _on_bay_buy_pressed() -> void:
	if _plate_mode == &"garage":
		if _upgrades:
			_upgrades.buy(GarageUpgradeManager.GARAGE_ID)   # bakiye yetmezse hiçbir şey değişmez
		return
	if _bays and _bay_index >= 0:
		_bays.purchase(_bay_index)   # para/seviye uygun değilse hiçbir şey değişmez


## Garaj genişledi: plaka kapanır, kısa bildirim çıkar (yeni tamir alanı kilitli olarak belirir).
func _on_upgrade_purchased(id: StringName, level: int) -> void:
	if id != GarageUpgradeManager.GARAGE_ID or router.top() == &"garage_edit":
		return   # düzenleme ekranındaki YÜKSELTMELER kendi bildirimini gösterir
	hide_bay_plate()
	_show_notice(Loc.t("GARAJ SEVİYE %d") % level, HudPalette.COIN_DARK)


func _on_bay_unlocked(index: int) -> void:
	hide_bay_plate()
	if router.top() == &"garage_edit":
		return   # YÜKSELTMELER'den alındı: bildirim düzenleme ekranında
	_show_notice(Loc.t("TAMİR ALANI %d AÇILDI\nGARAJI DÜZENLE'DEN TAŞIYABİLİRSİN") % (index + 1), HudPalette.COIN_DARK, 2.4)


func _on_bay_purchase_failed(index: int, price: int) -> void:
	_show_notice(Loc.t("%s ₺ GEREKLİ") % format_thousands(price), HudPalette.INK)
	if _bay_plate.visible:
		show_bay_plate(index)   # plaka güncel durumu göstersin


## ARAÇLAR → MODİFİYE → YÜKSELT: parça alınır, garaj kapanır, oyun ana dünyaya döner ve araç tamir
## alanına girip liftle kalkar (PerformanceBays.present: kamera alana gider, sonra eski yerine döner).
## Alınamazsa (para / alan / seviye) garaj açık kalır, plaka nedeni zaten gösteriyor.
func _on_mod_upgrade(vehicle_id: StringName, category: StringName) -> void:
	var mods: PerformanceModManager = get_tree().get_first_node_in_group("performance_mods") as PerformanceModManager
	var mod_bays: PerformanceBays = get_tree().get_first_node_in_group("performance_bays") as PerformanceBays
	if mods == null or not mods.purchase(vehicle_id, category):
		return
	router.close_all()
	await get_tree().create_timer(0.3).timeout   # garajın kapanış geçişi
	hide_bay_plate()
	hide_car_info()
	if mod_bays:
		mod_bays.present(vehicle_id)


## Tamir alanında parça takılan araç plakası (seçiliyken her 0,25 sn): başlık, şerit, kalan süre, ELMASLA BİTİR.
func _refresh_mod_plate() -> void:
	if _mod_target == &"":
		return
	var mods: PerformanceModManager = get_tree().get_first_node_in_group("performance_mods") as PerformanceModManager
	if mods == null or not mods.has_job(_mod_target):
		return
	var job: Dictionary = mods.job_of(_mod_target)
	var title: String = Loc.t("%s TAKILIYOR") % PerformanceMods.part_name(_mod_target, job["category"], int(job["stage"]))
	_repair_panel.show_mod(title, mods.progress(_mod_target), mods.remaining(_mod_target),
		mods.gem_skip_cost(_mod_target))


## ELMASLA BİTİR onaylandı: seçili araç parça takılan oyuncu aracıysa takma, değilse uzun tamir biter.
## Elmas yetmiyorsa mağaza açılır.
func _on_gem_finish_pressed() -> void:
	var player: PlayerProgress = _player_progress
	if _mod_target != &"":
		var mods: PerformanceModManager = get_tree().get_first_node_in_group("performance_mods") as PerformanceModManager
		if mods == null:
			return
		var id: StringName = _mod_target
		var cost: int = mods.gem_skip_cost(id)
		if player == null or not player.can_afford_gems(cost):
			_gem_shortage(cost)
			return
		if mods.finish_with_gems(id):
			(load("res://car_hitbox.gd") as GDScript).set(&"selected_car", null)   # plaka kapanır (job_deselected)
		return
	if _repair_manager == null or _repair_target == null:
		return
	var repair_cost: int = _repair_manager.gem_skip_cost(_repair_target)
	if player == null or not player.can_afford_gems(repair_cost):
		_gem_shortage(repair_cost)
		return
	_repair_manager.finish_with_gems(_repair_target)
	_refresh_repair_panel(false)


func _gem_shortage(cost: int) -> void:
	_show_notice(Loc.t("GEM YETMİYOR\n%d GEM gerekiyor, %d GEM'in var.") % [cost,
		_player_progress.gems if _player_progress else 0], HudPalette.INK, 2.4)
	router.open(&"gem_store")


func _car_name(vehicle_id: StringName) -> String:
	return String(CarCatalog.get_entry(vehicle_id).get("display_name", vehicle_id)).to_upper()


## Bildirim plakası SIRAYLA gösterir: ödül toplamak seviye atlatabilir, seviye ustalık kademesi
## açabilir — aynı karede gelen bildirimler birbirini silmesin diye kuyruğa girer.
## `action` verilirse plaka görünürken basılabilir: dokunuş eylemi çalıştırır, plaka hemen kapanır.
func _show_notice(text: String, color: Color, hold: float = 1.6, action: Callable = Callable()) -> void:
	if _notice_plate == null:
		return
	_notice_queue.append({"text": text, "color": color, "hold": hold, "action": action})
	if _notice_queue.size() > NOTICE_QUEUE_MAX:
		_notice_queue.pop_front()   # taşarsa en eskisi düşer (oyuncu güncel olanı görsün)
	if not _notice_busy:
		_drain_notices()


func _drain_notices() -> void:
	_notice_busy = true
	while not _notice_queue.is_empty():
		var notice: Dictionary = _notice_queue.pop_front()
		await _play_notice(String(notice["text"]), notice["color"], float(notice["hold"]), notice["action"])
	_notice_busy = false


func _play_notice(text: String, color: Color, hold: float, action: Callable = Callable()) -> void:
	_notice_action = action
	_notice_plate.mouse_filter = Control.MOUSE_FILTER_STOP if action.is_valid() else Control.MOUSE_FILTER_IGNORE
	_notice_label.text = text
	_notice_label.add_theme_color_override(&"font_color", color)
	_notice_plate.modulate.a = 0.0
	_notice_plate.show()
	await get_tree().process_frame  # container boyutu hesaplansın
	_notice_plate.pivot_offset = Vector2(_notice_plate.size.x * 0.5, _notice_plate.size.y)
	_notice_plate.scale = Vector2(0.85, 0.85)
	_notice_tween = create_tween()
	_notice_tween.set_parallel(true)
	_notice_tween.tween_property(_notice_plate, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_notice_tween.tween_property(_notice_plate, "modulate:a", 1.0, 0.12)
	_notice_tween.set_parallel(false)
	_notice_tween.tween_interval(hold)
	_notice_tween.tween_property(_notice_plate, "modulate:a", 0.0, 0.25)
	_notice_tween.tween_callback(_notice_plate.hide)
	await _notice_tween.finished
	_notice_action = Callable()
	_notice_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Basılabilir bildirim: eylemi bir kez çalıştırır; tween sona sarılır (kuyruk finished'ı bekliyor, kill takardı).
func _on_notice_input(event: InputEvent) -> void:
	var press: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if not press or not _notice_action.is_valid():
		return
	_notice_plate.accept_event()
	var action: Callable = _notice_action
	_notice_action = Callable()
	_notice_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _notice_tween and _notice_tween.is_valid():
		_notice_tween.custom_step(60.0)
	action.call()


## Yarış ödülü kasaya girdi: kısa bildirim plakası (para plakası zaten değişimi gösterir).
func _on_race_reward(won: bool, money: int, xp: int) -> void:
	var line: String = Loc.t("YARIŞ KAZANILDI") if won else Loc.t("YARIŞ KAYBEDİLDİ")
	var parts: PackedStringArray = PackedStringArray()
	if money > 0:
		parts.append("+%s ₺" % format_thousands(money))
	if xp > 0:
		parts.append(Loc.t("+%d XP") % xp)
	if not parts.is_empty():
		line += "\n%s" % "   ".join(parts)
	_show_notice(line, HudPalette.COIN_DARK, 2.2)


## İş ustalığı kademesi atlandı: hangi iş, kaçıncı yıldız, tek seferlik ödül.
func _on_mastery_up(job_id: StringName, stars: int) -> void:
	var mastery: JobMastery = get_tree().get_first_node_in_group("job_mastery") as JobMastery
	if mastery == null:
		return
	var type: RepairType = mastery.type_of(job_id)
	_show_notice(Loc.t("%s USTALIK %d★\n+%s ₺   ÖDÜL +%%%d") % [
		type.title if type else String(job_id), stars,
		format_thousands(mastery.star_payout(job_id, stars)),
		roundi(JobMastery.REWARD_BONUS_PER_STAR * float(stars) * 100.0)],
		HudPalette.COIN_DARK, 2.2)


## Garaj rütbesi değişti mi diye bakar (GarageValue türetilmiştir, sinyali yoktur).
func _check_garage_rank() -> void:
	var rank: int = GarageValue.current_rank(get_tree())
	if _garage_rank == 0:
		_garage_rank = rank
		return
	if rank <= _garage_rank:
		return
	_garage_rank = rank
	_show_notice(Loc.t("GARAJ RÜTBESİ %d\n%s") % [rank, GarageValue.rank_name(rank)],
			HudPalette.COIN_DARK, 2.2)


## Rakibin balonuna dokunuldu: davet panosu açılır (aynı anda başka panel açık kalmaz).
func _on_challenge_clicked(_vehicle: Node3D) -> void:
	router.open(&"race_challenge")


## YARIŞ plakası: pist açılır (PLACE — garaj/showroom kapanır, oyun HUD'u gizlenir).
func _on_race_accepted() -> void:
	if _race:
		_race.set_racing(true)
	router.open(&"drag_race")


## Yarış bitti: ödül BİR KEZ RaceManager'da yazılır, sonuç panosu yalnızca gösterir.
func _on_race_completed(won: bool, player_time: float, rival_time: float) -> void:
	var reward: Dictionary = {"money": 0, "xp": 0}
	var rival: StringName = _race.rival_id() if _race else &""
	var player_id: StringName = _race.player_vehicle_id() if _race else &""
	var rematch: int = _race.rematch_count() if _race else 0
	if _race:
		reward = _race.finish_race(won)
	_arm_push_prompt()
	race_result_screen.show_result(won, player_time, rival_time,
		int(reward["money"]), int(reward["xp"]), player_id if won else rival, rematch)
	if int(reward.get("friend_bonus", 0)) > 0:
		race_result_screen.show_friend_bonus(int(reward["friend_bonus"]))
	if reward.get("event_bonus") is Dictionary:
		race_result_screen.show_event_bonus(LiveEvent.reward_text(reward["event_bonus"]))
	race_result_screen.offer_rematch(not won and _race != null and _race.can_rematch())
	var record: Dictionary = drag_race_screen.record_result()
	race_result_screen.show_record(bool(record["finished"]), bool(record["new"]),
		float(record["time"]), float(record["previous"]))
	# ÖDÜLLÜ REKLAM: yalnızca para kazanıldıysa ve politika + hazır reklam uygunsa teklif edilir (açık onay).
	_race_bonus_amount = 0
	var ads: AdService = _ads_service()
	if ads and int(reward["money"]) > 0 and ads.can_offer(AdPolicy.RACE_DOUBLE):
		_race_bonus_amount = int(reward["money"])
		race_result_screen.offer_bonus(_race_bonus_amount)
	router.open(&"race_result")


## GÜNLÜK GİRİŞ MERDİVENİ: tabela (gün numarası, alınabilir rozeti) her değişimde tazelenir; alınmadan gün dönüp
## kendiliğinden verilen basamak bildirimle söylenir (ekranda AL'a basılan ödülü pencere gösterir).
func _refresh_login_ladder() -> void:
	var gem_rewards: GemRewards = get_tree().get_first_node_in_group("gem_rewards") as GemRewards
	if gem_rewards == null or login_ladder_button == null:
		return
	login_ladder_button.day = gem_rewards.ladder_day()
	login_ladder_button.ready_to_claim = gem_rewards.can_claim()


func _on_ladder_claimed(reward: Dictionary) -> void:
	if not bool(reward.get("auto", false)):
		return
	var parts: PackedStringArray = PackedStringArray()
	if int(reward["money"]) > 0:
		parts.append("+%s ₺" % format_thousands(int(reward["money"])))
	if int(reward["gems"]) > 0:
		parts.append(Loc.t("+%d GEM") % int(reward["gems"]))
	if reward["decor"] != &"":
		parts.append(Loc.t(String(GarageDecor.get_item(reward["decor"]).get("title", ""))))
	_show_notice(Loc.t("DÜNKÜ GİRİŞ ÖDÜLÜ ALINDI") + "\n" + "   ".join(parts), HudPalette.INK, 2.6)


## Reklam servisini bulur ve sinyallerini BİR kez bağlar. Servis sahneye HUD'dan sonra kurulabildiği için
## bağlantı kurulumda değil ilk kullanımda yapılır (ödül sinyalinin kaçırılması = reklam izlenip ödül verilmemesi olurdu).
func _ads_service() -> AdService:
	var ads: AdService = get_tree().get_first_node_in_group("ads") as AdService
	if ads != null and ads != _ads_bound:
		ads.reward_earned.connect(_on_ad_reward_earned)
		ads.ad_finished.connect(_on_ad_finished)
		_ads_bound = ads
	return ads


## Yarış bonusu: oyuncu REKLAM İZLE'ye bastı.
func _on_race_bonus_requested() -> void:
	var ads: AdService = _ads_service()
	if ads == null or _race_bonus_amount <= 0 or not ads.show_rewarded(AdPolicy.RACE_DOUBLE):
		race_result_screen.rearm_bonus()   # gösterilemedi: oyuncu tekrar deneyebilir ya da çıkabilir


## Reklam ödülü hak edildi (AdService bunu bir gösterimde en çok BİR kez yayar). Bonus = yarış parası kadar.
func _on_ad_reward_earned(kind: StringName) -> void:
	if kind == AdPolicy.REPAIR_BOOST:
		if is_instance_valid(_boost_car) and _repair_manager != null:
			_repair_manager.boost_repair(_boost_car)   # tek sefer: RepairState.boosted
		_boost_car = null
		_refresh_repair_panel(false)
		return
	if kind != AdPolicy.RACE_DOUBLE or _race_bonus_amount <= 0 or _economy == null:
		return
	var amount: int = _race_bonus_amount
	_race_bonus_amount = 0   # aynı yarış için ikinci bonus yok
	_economy.add_money(amount)
	race_result_screen.bonus_granted(amount)


func _on_ad_finished(kind: StringName, rewarded: bool) -> void:
	if kind == AdPolicy.REPAIR_BOOST:
		_boost_car = null
		_refresh_repair_panel(false)
		return
	if kind == AdPolicy.RACE_DOUBLE and not rewarded:
		var ads: AdService = _ads_service()
		if ads and _race_bonus_amount > 0 and ads.block_reason(AdPolicy.RACE_DOUBLE) == AdPolicy.OK:
			race_result_screen.rearm_bonus()
		else:
			race_result_screen.hide_bonus()


## RÖVANŞ: aynı rakiple yeniden yarış. Sonuç panosu kapanır (kapanış animasyonu bitince closed → _on_race_exit
## gelir; bayrak onu "yarıştan çık" yerine "pisti yeniden aç" yapar), pist sıfırdan kurulur.
func _on_race_rematch() -> void:
	if _race == null or not _race.start_rematch():
		race_result_screen.offer_rematch(false)
		return
	_race_bonus_amount = 0
	race_result_screen.hide_bonus()
	_rematch_pending = true
	if router.top() == &"race_result":
		router.back()
	else:
		_on_race_exit()


## GARAJA DÖN: sonuç ve pist kapanır, oyuncu dünyaya döner (rövanş bekleyen rakip yola döner).
func _on_race_exit() -> void:
	if _rematch_pending:   # sonuç panosu rövanş için kapandı: pist aynı rakiple baştan
		_rematch_pending = false
		if router.is_open(&"drag_race"):
			drag_race_screen.open()
			return
	_race_bonus_amount = 0
	if _race:
		_race.end_race_session()
		_race.set_racing(false)
	if router.is_open(&"drag_race") or router.is_open(&"race_result"):
		router.close_all()
	if _race and _race.take_showcase_tease():
		router.open.call_deferred(&"supercar_tease")   # tanıtım yarışı kaybedildi: dünyaya dönünce hedef ekranı


## Showroom'dan araç satın alındı: kısa bildirim plakası (para düşüşünü zaten coin plakası gösterir).
func _on_vehicle_purchased(vehicle_id: StringName) -> void:
	var entry: Dictionary = CarCatalog.get_entry(vehicle_id)
	_show_notice(Loc.t("%s GARAJINDA") % String(entry.get("display_name", vehicle_id)).to_upper(), HudPalette.COIN_DARK)


## Seçili aracın müşteri durumu değişti (tamir istedi / durdu): plaka güncellenir.
func _on_customer_changed(car: Node3D) -> void:
	if car == _repair_target:
		_refresh_repair_panel(false)


func _on_repair_started(car: Node3D) -> void:
	if car == _repair_target:
		_refresh_repair_panel(false)


## Tamir bitti: para aracın üstündeki ₺ balonundan DOĞRUDAN toplanır (car_hitbox), plakada PARA TOPLA adımı
## yok. Bu aracın plakası açıksa seçim kaldırılır, plaka kapanır; oyuncu balona dokunur.
func _on_repair_ready(car: Node3D) -> void:
	if car == _repair_target:
		(load("res://car_hitbox.gd") as GDScript).call(&"clear_selection", get_tree())


func _on_repair_progress(car: Node3D, progress: float) -> void:
	if car == _repair_target:
		var state: RepairState = _repair_manager.get_state(car)
		_repair_panel.show_repairing(progress, state.remaining if state else 0.0, _boost_offer(car),
			_repair_manager.gem_skip_cost(car))


## Araç alandan çıktı: seçili başka bir arızalı aracın plakası TAMİR'i açar.
func _on_repair_slot_freed(_car: Node3D) -> void:
	_refresh_repair_panel(false)


func _on_repair_cancelled(_car: Node3D) -> void:
	_refresh_repair_panel(false)


# --- Buton olayları ----------------------------------------------------------

func _on_nav_toggled(pressed: bool, button: PlateButton) -> void:
	if pressed:
		nav_selected.emit(_nav_ids[button])


## Sekmeye basıldı: ilgili ekranı açar. Açık olan sekmeye tekrar basmak onu kapatır (geri döner).
func _on_nav_pressed(button: PlateButton) -> void:
	if button == garage_button:
		router.open(&"garage_edit")   # GARAJI DÜZENLE (yükseltmeler de orada: YÜKSELTMELER modu)
		return
	var id: StringName = _nav_screens.get(button, &"")
	if id == &"":
		return
	if router.is_open(id) and router.top() == id:
		router.back()
		return
	router.open(id)


func _build_router() -> void:
	router = UiRouter.new()
	router.name = "UiRouter"
	add_child(router)
	router.stack_changed.connect(_on_ui_stack_changed)
	# Kök viewport sahne yenilemesinden sağ çıkar: dil değişimi / bulut kaydı AYARLAR açıkken sahneyi yeniden
	# kurunca disable_3d açık kalıyor, dünya bir ekran açılıp kapanana dek gri görünüyordu.
	_sync_world_rendering()
	router.exit_hint_requested.connect(func() -> void:
		_show_notice(Loc.t("Çıkmak için tekrar GERİ'ye bas"), Color(1.0, 0.9, 0.5), 1.8))
	router.back_override = _android_back_for_crate_panel


## Android GERİ, kasa panosu açıkken: "hazır" panosu kapanır (kasa beklemeye döner); sonuç panosu
## ödülü gösterir, GERİ ile geçilemez (yanlışlıkla kapatıp ödülü görmemeyi önler).
func _android_back_for_crate_panel() -> bool:
	if showroom and showroom.visible and showroom.is_revealing():
		return true   # yoldaki kasa mağazada açılıyor: sonuç plakası TAMAM ile kapanır
	if friends_screen and friends_screen.close_popup():
		return true   # ARKADAŞLAR'ın KODLA EKLE penceresi önce kapanır
	if crate_panel == null or not crate_panel.visible:
		return false
	if crate_panel.mode() == &"prompt":
		crate_panel.dismiss()
	return true


## İlerleme panoları HUD'a ait: hem garajdan hem PROFİL'den açılabilsinler (daha önce yalnızca
## garaj ekranının çocuklarıydı, dışarıdan erişilemiyorlardı).
func _build_progress_screens() -> void:
	var host: Node = garage_screen.get_parent()
	garage_value_screen = GarageValueScreen.new()
	host.add_child(garage_value_screen)
	mastery_screen = MasteryScreen.new()
	host.add_child(mastery_screen)
	# GARAJI DÜZENLE: dünya garajının üstünde, kendisi tıklama almayan tam çerçeve arayüz
	garage_edit_screen = GarageEditScreen.new()
	host.add_child(garage_edit_screen)
	profile_screen = ProfileScreen.new()
	host.add_child(profile_screen)
	collection_screen = CollectionScreen.new()
	host.add_child(collection_screen)
	all_cars_screen = AllCarsScreen.new()
	all_cars_screen.current_vehicle = garage_screen.shown_vehicle
	all_cars_screen.current_garage = garage_screen.current_garage
	host.add_child(all_cars_screen)
	all_cars_screen.vehicle_chosen.connect(garage_screen.show_vehicle)
	car_garages_screen = CarGaragesScreen.new()
	# Dünyadan açılan panoda BURADASIN yok (ARAÇLAR kapalıyken eski "bakılan yer" geçersiz)
	car_garages_screen.current_garage = func() -> StringName:
		return garage_screen.current_garage() if garage_screen.visible else &""
	host.add_child(car_garages_screen)
	car_garage_upgrade_screen = CarGarageUpgradeScreen.new()
	host.add_child(car_garage_upgrade_screen)
	car_garages_screen.garage_chosen.connect(_on_garage_chosen)
	garage_screen.home_vehicle_chosen.connect(func(id: StringName) -> void:
		router.close_all()
		get_tree().create_timer(0.3).timeout.connect(show_exhibit.bind(id)))   # ekran kapanış geçişinden sonra
	car_garages_screen.upgrades_requested.connect(func(garage: StringName) -> void:
		car_garage_upgrade_screen.garage = garage
		router.open(&"car_garage_upgrades"))
	car_garages_screen.gem_store_requested.connect(func() -> void: router.open(&"gem_store"))
	car_placement_screen = CarPlacementScreen.new()
	host.add_child(car_placement_screen)
	car_placement_screen.home_requested.connect(_place_at_home)
	car_garage_upgrade_screen.gem_store_requested.connect(func() -> void: router.open(&"gem_store"))
	gem_store_screen = GemStoreScreen.new()
	gem_store_screen.hud = self
	host.add_child(gem_store_screen)
	profile_screen.screen_requested.connect(func(id: StringName) -> void: router.open(id))
	garage_screen.screen_requested.connect(func(id: StringName) -> void: router.open(id))
	garage_edit_screen.screen_requested.connect(func(id: StringName) -> void: router.open(id))   # LÜKS: elmas yetmedi
	garage_screen.mod_upgrade_requested.connect(_on_mod_upgrade)
	garage_screen.home_requested.connect(_place_at_home)


## YARIŞ: davet panosu (MODAL) → pist (PLACE) → sonuç panosu (MODAL). Ekranlar kendi navigasyonunu
## taşımaz; akışı burası kurar, UiRouter uygular.
func _build_race_screens() -> void:
	var host: Node = garage_screen.get_parent()
	race_challenge_screen = RaceChallengeScreen.new()
	host.add_child(race_challenge_screen)
	drag_race_screen = DragRaceScreen.new()
	host.add_child(drag_race_screen)
	race_result_screen = RaceResultScreen.new()
	host.add_child(race_result_screen)
	supercar_tease_screen = SupercarTeaseScreen.new()
	host.add_child(supercar_tease_screen)
	race_challenge_screen.race_accepted.connect(_on_race_accepted)
	drag_race_screen.race_completed.connect(_on_race_completed)
	race_result_screen.exit_requested.connect(_on_race_exit)
	race_result_screen.closed.connect(_on_race_exit)
	race_result_screen.bonus_requested.connect(_on_race_bonus_requested)
	race_result_screen.rematch_requested.connect(_on_race_rematch)


## HARİTA + HURDALIK (docs/HURDALIK_TASARIM.md §1): ikisi de PLACE. Şehirden HARİTA plakası (alt
## sekme sırasının sonunda) haritayı açar; harita yolculuğu bitince hedef mekân açılır. Hurdalıkta HARİTA
## plakası haritayı "buradasın: hurdalık" olarak açar; harita kapatılırsa (yolculuksuz) hurdalığa dönülür.
func _build_junkyard_screens() -> void:
	var host: Node = garage_screen.get_parent()
	map_screen = MapScreen.new()
	host.add_child(map_screen)
	junkyard_screen = JunkyardScreen.new()
	host.add_child(junkyard_screen)
	restoration_panel = RestorationPanel.new()
	host.add_child(restoration_panel)
	restoration_panel.screen_requested.connect(func(id: StringName) -> void: router.open(id))
	restoration_panel.closed.connect(func() -> void:
		var bays: RestorationBays = get_tree().get_first_node_in_group("restoration_bays") as RestorationBays
		if bays:
			bays.clear_selection())
	# BİTİR: duyuruyu teslim töreni yapar (RestorationBays → RestorationFinale → RestorationResult)
	map_screen.travel_requested.connect(_on_map_travel)
	map_screen.travel_started.connect(func(place: StringName) -> void:
		if place == &"junkyard":
			var junkyard: JunkyardManager = get_tree().get_first_node_in_group("junkyard") as JunkyardManager
			var daily: Array[StringName] = []
			if junkyard:
				daily = junkyard.yard_cars()
			JunkyardWorld.preload_assets(daily))
	map_screen.closed.connect(_on_map_closed)
	junkyard_screen.map_requested.connect(func() -> void: _open_map(&"junkyard"))
	junkyard_screen.collection_requested.connect(func() -> void: router.open(&"collection"))
	map_button = PlateButton.new()
	map_button.name = "MapButton"
	map_button.custom_minimum_size = garage_button.custom_minimum_size
	map_button.theme_type_variation = &"HudPlate"
	map_button.kind = HudIcon.Kind.MAP
	map_button.text = Loc.t("HARİTA")
	map_button.focus_mode = Control.FOCUS_NONE
	map_button.pressed.connect(func() -> void: _open_map(&"city"))   # HEP görünür (2026-10-23; eskiden hurdalık açılınca)
	garage_button.get_parent().add_child(map_button)


var _map_travelled: bool = false


func _open_map(from: StringName) -> void:
	map_screen.current = from
	_map_travelled = false
	router.open(&"map")


func _on_map_travel(place: StringName) -> void:
	_map_travelled = true
	if place == &"junkyard":
		router.open(&"junkyard")
		var junkyard: JunkyardManager = get_tree().get_first_node_in_group("junkyard") as JunkyardManager
		if junkyard:
			junkyard.record_visit()
	else:
		router.close_all()


## Harita yolculuksuz kapandı (KAPAT / GERİ): hurdalıktan açıldıysa hurdalığa dönülür.
func _on_map_closed() -> void:
	if _map_travelled or map_screen.current != &"junkyard":
		return
	_map_travelled = true   # tekrar girme (router.open aşağıda haritayı da kapatır)
	router.open.call_deferred(&"junkyard")


func _register_screens() -> void:
	router.register(&"garage", garage_screen, UiRouter.Kind.PLACE)
	router.register(&"showroom", showroom, UiRouter.Kind.PLACE)
	router.register(&"quests", quest_screen, UiRouter.Kind.MODAL)
	router.register(&"mastery", mastery_screen, UiRouter.Kind.MODAL)
	# YER (PLACE): oyun HUD'u gizlenir — düzenlerken alt sekmeler / görevler yanlışlıkla açılmasın
	router.register(&"garage_edit", garage_edit_screen, UiRouter.Kind.PLACE)
	router.register(&"garage_value", garage_value_screen, UiRouter.Kind.MODAL)
	router.register(&"profile", profile_screen, UiRouter.Kind.MODAL)
	router.register(&"account", login_screen, UiRouter.Kind.MODAL)
	router.register(&"push_prompt", push_prompt, UiRouter.Kind.MODAL)
	router.register(&"news", news_screen, UiRouter.Kind.MODAL)
	router.register(&"invite", invite_screen, UiRouter.Kind.MODAL)
	router.register(&"settings", settings_screen, UiRouter.Kind.PLACE)   # tam ekran: oyun arkada görünmez
	router.register(&"race_challenge", race_challenge_screen, UiRouter.Kind.MODAL)
	router.register(&"drag_race", drag_race_screen, UiRouter.Kind.PLACE)
	router.register(&"race_result", race_result_screen, UiRouter.Kind.MODAL)
	router.register(&"supercar_tease", supercar_tease_screen, UiRouter.Kind.MODAL)
	router.register(&"collection", collection_screen, UiRouter.Kind.MODAL)
	router.register(&"all_cars", all_cars_screen, UiRouter.Kind.MODAL)
	router.register(&"car_garages", car_garages_screen, UiRouter.Kind.MODAL)
	router.register(&"car_placement", car_placement_screen, UiRouter.Kind.MODAL)
	router.register(&"car_garage_upgrades", car_garage_upgrade_screen, UiRouter.Kind.SUB)
	router.register(&"friends", friends_screen, UiRouter.Kind.MODAL)
	router.register(&"gem_store", gem_store_screen, UiRouter.Kind.MODAL)
	router.register(&"map", map_screen, UiRouter.Kind.PLACE)
	router.register(&"junkyard", junkyard_screen, UiRouter.Kind.PLACE)
	router.register(&"restoration", restoration_panel, UiRouter.Kind.MODAL)
	router.register(&"photo", photo_mode, UiRouter.Kind.PLACE)   # HUD'suz dünya: fotoğraf / HUD gizli / sinema
	# ALT PANOLAR: altlarındaki panoyu kapatmadan açılır (kart → liste, düzenleme → profil, kırpma → düzenleme)
	router.register(&"friend_card", friend_card_screen, UiRouter.Kind.SUB)
	router.register(&"profile_edit", profile_edit_screen, UiRouter.Kind.SUB)
	router.register(&"avatar_crop", avatar_cropper, UiRouter.Kind.SUB)
	router.register(&"avatar_camera", camera_capture, UiRouter.Kind.SUB)
	# 3D ekranların shader'ları ve dünya efektleri oyun yüklenirken derlensin (ilk açılış takılmasız) — bkz. _warm_up
	_warm_up.call_deferred()


## ÖN ISITMA: pist / showroom / garaj ekranı gizlice bir kez küçük çizilir, dünya efektleri (ilk tamirin yazılı balonu,
## kıvılcım / duman, polis / dörtlü ışıkları; WorldPrewarm) zeminin altında birkaç kare çizilir — shader'lar oyun
## yüklenirken derlenir. Her adım AYRI karede (2026-10-23): eskiden hepsi dünyanın ilk çizimiyle aynı karedeydi, o kare
## masaüstünde 1,3 sn sürüyor ve yükleme ekranı (slaytlar, ipucu, çubuk) donuyordu. Şimdi aralarda yükleme ekranı çizilir.
func _warm_up() -> void:
	var tree: SceneTree = get_tree()
	for step: Callable in [drag_race_screen.prewarm, showroom.prewarm, garage_screen.prewarm, WorldPrewarm.run.bind(tree)]:
		await tree.process_frame   # her karede tek adım: o karenin çiziminde yalnız onun shader'ları derlenir
		step.call()
	await tree.process_frame
	warmed_up = true


## Yığın değişti: oyun HUD'u yalnızca bir YER (garaj/showroom) açıkken gizlenir; panolar
## (görevler, ustalık, rütbe, profil, hesap) HUD'un üstünde durur.
func _on_ui_stack_changed(top: StringName, place_open: bool) -> void:
	_set_gameplay_hud_visible(not place_open)
	if top != &"" and exhibit_plate:
		exhibit_plate.hide_plate()
	garage_screen.set_covered(router.current_place() == &"garage" and top != &"garage")
	_sync_modal_hud()
	_sync_world_rendering()
	if top != &"":
		camera_button.button_pressed = false   # kamera menüsü bir ekranın altında açık kalmasın
		hide_bay_plate()   # dünya plakası bir ekranın altında asılı kalmasın
		hide_car_info()
		if crate_panel and crate_panel.mode() == &"prompt":
			crate_panel.hide_panel()
		if restoration_result and restoration_result.visible:
			restoration_result.confirm()   # bir ekran açıldı: araç garaja gider, alan boşalır
	_sync_nav_tab(router.current_place())
	_refresh_quest_button()


## DÜNYAYI TAMAMEN ÖRTEN yerler: açıkken ana görünümün 3D çizimi kapanır (ekranların kendi 3D
## sahneleri ayrı SubViewport'larda, etkilenmez). Ölçüldü (dekorlu garaj): showroom / garaj / yarış
## açıkken arkadaki şehir ~500 çizim çağrısı ve ~600k üçgen harcıyordu — hiç görünmediği hâlde.
## Dekorasyon düzenleyici dünyayı arka planda gösterdiği için listede YOK.
const WORLD_COVERING_PLACES: Array[StringName] = [&"garage", &"showroom", &"settings", &"drag_race", &"map",
	&"junkyard"]
## Açılış geçişi bitmeden dünya kapanırsa arkada siyah parlama görünür: bu kadar beklenir.
const WORLD_HIDE_DELAY: float = 0.4

var _world_hide_timer: SceneTreeTimer


func _sync_world_rendering() -> void:
	var covered: bool = WORLD_COVERING_PLACES.has(router.current_place())
	var viewport: Viewport = get_viewport()
	if not covered:
		viewport.disable_3d = false   # kapanış geçişi dünyanın üstünde oynar: hemen aç
		_world_hide_timer = null
		return
	if viewport.disable_3d or _world_hide_timer != null:
		return
	_world_hide_timer = get_tree().create_timer(WORLD_HIDE_DELAY)
	_world_hide_timer.timeout.connect(func() -> void:
		_world_hide_timer = null
		if WORLD_COVERING_PLACES.has(router.current_place()):
			get_viewport().disable_3d = true)


## Alt sekme yalnızca AÇIK olanı sarı gösterir: DEPOLARIM panosu (ya da oradan açılan depo ekranı) / MAĞAZA ekranı ya
## da PROFİL panosu (GARAJI DÜZENLE açılınca oyun HUD'u gizli). Hiçbiri açık değilse hiçbir sekme sarı değildir.
func _sync_nav_tab(place: StringName) -> void:
	var target: PlateButton = null
	match place:
		&"showroom":
			target = shop_button
		&"garage":
			target = cars_button
		&"":
			if router and router.top() == &"car_garages":
				target = cars_button
			elif router and router.top() in [&"profile", &"account", &"profile_edit", &"avatar_crop", &"avatar_camera"]:
				target = profile_button
	# ButtonGroup set_pressed_no_signal ile diğerlerini bırakmıyor: iki sekme birden amber kalıyordu.
	for button: PlateButton in _nav_ids:
		button.set_pressed_no_signal(button == target)


# --- Eğitim -----------------------------------------------------------------------------

## Ders katmanı bütün ekranların (showroom, yarış, düzenleyici) üstünde olmalı: temalı köke EN SON eklenir.
## GİRİŞ ÖNERİSİ (YEDEK): giriş artık ilk açılışta yükleme ekranında sorulur (LoginGate) ve seçim
## login_prompt_seen yazar; bu öneri yalnızca o ekran hiç gösterilmediyse (yükleme yedek yoldan geçtiyse)
## gelir. Koşul: ilk ders (İLK TAMİR) bitti — eğitim atlandıysa / yoksa LOGIN_PROMPT_LEVEL — ve oyuncu
## boşta (açık ekran, ders, kasa panosu yok) en az LOGIN_PROMPT_IDLE saniye. Bir kez gösterildi mi
## (cloud_sync.json) tekrar gelmez.
const LOGIN_PROMPT_LEVEL: int = 2
const LOGIN_PROMPT_IDLE: float = 3.0
var _login_idle: float = 0.0


func _setup_login_prompt() -> void:
	var cloud: CloudSaveManager = get_tree().get_first_node_in_group("cloud_save") as CloudSaveManager
	if cloud == null or not cloud.should_prompt_login():
		return   # masaüstü / zaten giriş yapılmış / daha önce önerilmiş
	var timer: Timer = Timer.new()
	timer.name = "LoginPromptTimer"
	timer.wait_time = 1.0
	add_child(timer)
	timer.timeout.connect(_tick_login_prompt.bind(cloud, timer))
	timer.start()


func _tick_login_prompt(cloud: CloudSaveManager, timer: Timer) -> void:
	if not cloud.should_prompt_login():
		timer.queue_free()
		return
	if not _login_prompt_ready() or not router.top().is_empty() or (tutorial and tutorial.is_running()) \
			or (crate_panel and crate_panel.visible) or (restoration_result and restoration_result.visible) \
			or get_tree().root.get_node_or_null("LoadingScreen") != null:   # ilk açılış giriş ekranı (LoginGate) açık
		_login_idle = 0.0
		return
	_login_idle += timer.wait_time
	if _login_idle < LOGIN_PROMPT_IDLE:
		return
	timer.queue_free()
	router.open(&"account")
	login_screen.show_prompt()


func _login_prompt_ready() -> bool:
	var manager: TutorialManager = get_tree().get_first_node_in_group("tutorial") as TutorialManager
	if manager and manager.is_done(TutorialManager.BASICS):
		return true
	return _player_progress != null and _player_progress.level >= LOGIN_PROMPT_LEVEL


func _build_tutorial() -> void:
	tutorial_overlay = TutorialOverlay.new()
	garage_screen.get_parent().add_child(tutorial_overlay)
	tutorial = TutorialDirector.new()
	tutorial.hud = self
	tutorial.overlay = tutorial_overlay
	add_child(tutorial)


# --- Araç teslimat kasaları ---------------------------------------------------------------

## Kasa plakası tamir alanı plakasıyla aynı sütunda (alt-orta) durur.
func _build_crate_panel() -> void:
	crate_panel = CratePanel.new()
	var column: Node = car_info_panel.get_parent()
	column.add_child(crate_panel)
	column.move_child(crate_panel, car_info_panel.get_index())
	crate_panel.open_pressed.connect(_on_crate_open_pressed)
	crate_panel.done_pressed.connect(_on_crate_done_pressed)
	restoration_result = RestorationResult.new()
	column.add_child(restoration_result)
	column.move_child(restoration_result, crate_panel.get_index())


func _connect_crates() -> void:
	_crates = get_tree().get_first_node_in_group("crates") as CrateManager
	_delivery = get_tree().get_first_node_in_group("crate_delivery") as CrateDelivery
	if _crates:
		_crates.crate_added.connect(_on_crate_added)
		# MAĞAZA sekmesinin rozeti: garajda yer bulamayan ("yolda") kasa sayısı — mağazanın YOLDAKİ KASALAR bölümü
		_crates.crates_changed.connect(_refresh_shop_badge)
		_refresh_shop_badge()
	if _delivery:
		_delivery.crate_clicked.connect(_on_crate_clicked)
		_delivery.reveal_ready.connect(_on_crate_revealed)
		_delivery.delivery_blocked.connect(_on_crate_blocked)
	if _crates and _delivery and not GarageVisit.is_visiting():
		_welcome_timer = Timer.new()
		_welcome_timer.name = "WelcomeNudge"
		_welcome_timer.wait_time = WELCOME_NUDGE_FIRST
		_welcome_timer.timeout.connect(_nudge_welcome)
		add_child(_welcome_timer)
		_welcome_timer.start()
	var gem_rewards: GemRewards = get_tree().get_first_node_in_group("gem_rewards") as GemRewards
	if gem_rewards:
		gem_rewards.reward_granted.connect(func(_amount: int, text: String) -> void:
			if text != "":
				_show_notice(text, HudPalette.INK, 1.8))
		# GÜNLÜK GİRİŞ MERDİVENİ: pano (sakin anda kendiliğinden açılır) + sağ üstteki tabela (_setup_gem_store kurar)
		login_ladder_screen = LoginLadderScreen.new(self)
		garage_screen.get_parent().add_child(login_ladder_screen)
		router.register(&"login_ladder", login_ladder_screen, UiRouter.Kind.MODAL)
		gem_rewards.ladder_ready.connect(login_ladder_screen.request_auto)
		gem_rewards.ladder_claimed.connect(_on_ladder_claimed)
		gem_rewards.daily_changed.connect(_refresh_login_ladder)
		quest_screen.login_ladder_requested.connect(func() -> void: router.open(&"login_ladder"))
	_setup_gem_store()
	_refresh_login_ladder()
	_setup_login_prompt.call_deferred()   # CloudSaveManager kendi kaydını (cloud_sync.json) okusun


## GEM MAĞAZASI: sol üstteki gem sayacına dokunmak mağazayı açar. Mağaza kapalıyken tamamlanan ödeme
## (Play'de bekleyen ödeme sonradan onaylandı) bildirimle duyurulur; açıkken mağaza kendi penceresini açar.
func _setup_gem_store() -> void:
	var purchases: PurchaseManager = get_tree().get_first_node_in_group("purchases") as PurchaseManager
	if purchases == null:
		return   # arkadaş garajı ziyareti: mağaza yok
	var box: Control = gem_label.get_parent() as Control
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.gui_input.connect(func(event: InputEvent) -> void:
		var mb: InputEventMouseButton = event as InputEventMouseButton   # dokunuş fareye çevrilir
		if mb and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			router.open(&"gem_store"))
	# İKİNCİ TABELA SIRASI: sağ üstte tabelaların (ve açıksa kamera kutusunun) hemen altında, sağa yaslı — GÜNLÜK GİRİŞ ·
	# MARKET. İkisi de kamera / ayar gibi yuvarlak ve yazısız (2026-10-23, kullanıcı: "market butonunu yuvarlak yap, market
	# yazmasın, yanına günlük giriş merdiveni butonu yap"; MARKET önceki gün krem plakaydı).
	var sign_row: HBoxContainer = camera_button.get_parent() as HBoxContainer
	var shop_row: HBoxContainer = HBoxContainer.new()
	shop_row.name = "ShopRow"
	shop_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_row.alignment = BoxContainer.ALIGNMENT_END
	shop_row.add_theme_constant_override(&"separation", sign_row.get_theme_constant(&"separation"))
	var column: Node = camera_menu.get_parent()
	column.add_child(shop_row)
	column.move_child(shop_row, camera_menu.get_index() + 1)
	login_ladder_button = LoginLadderButton.new()
	login_ladder_button.name = "LoginLadderButton"
	login_ladder_button.custom_minimum_size = camera_button.custom_minimum_size
	login_ladder_button.visible = login_ladder_screen != null
	login_ladder_button.pressed.connect(func() -> void: router.open(&"login_ladder"))
	shop_row.add_child(login_ladder_button)
	var shop_button: GemShopButton = GemShopButton.new()
	shop_button.name = "GemShopButton"
	shop_button.custom_minimum_size = camera_button.custom_minimum_size
	shop_row.add_child(shop_button)
	shop_button.pressed.connect(func() -> void: router.open(&"gem_store"))
	var refresh_badge: Callable = func() -> void:
		shop_button.show_badge = purchases.is_available() and purchases.block_reason(GemProducts.STARTER) != "owned"
	purchases.products_changed.connect(refresh_badge)
	refresh_badge.call()
	purchases.gems_purchased.connect(func(_id: StringName, gems: int) -> void:
		if router.top() != &"gem_store":
			_show_notice(Loc.t("SATIN ALMA TAMAMLANDI\n+%d GEM") % gems, HudPalette.GEM_DARK, 2.4))
	# İADE: Play'de iade edilen satın almanın gemi düşüldü (PurchaseManager.apply_refunds)
	purchases.refund_applied.connect(func(_id: StringName, taken: int, _missing: int) -> void:
		if taken > 0:
			_show_notice(Loc.t("İADE EDİLEN SATIN ALMA\n−%d GEM GERİ ALINDI") % taken, HudPalette.INK, 3.0))
	add_child(FounderRewardNotice.new(self, purchases))   # ön kayıt ödülü: oyun sakinleşince ödül penceresi
	# CANLI ETKİNLİK tabelası (üst orta): POSTA / yasak pencerelerinden ÖNCE eklenir, onlar üstünde kalsın
	garage_screen.get_parent().add_child(EventBanner.new(self))
	event_screen = EventScreen.new()
	garage_screen.get_parent().add_child(event_screen)
	router.register(&"event", event_screen, UiRouter.Kind.MODAL)
	event_screen.action_requested.connect(_on_event_action)
	var mail: MailService = get_tree().get_first_node_in_group("mail") as MailService
	if mail:
		garage_screen.get_parent().add_child(MailNotice.new(self, mail))   # yönetim panelinin hediyeleri (temalı kök)
	var moderation: ModerationWatch = get_tree().get_first_node_in_group("moderation") as ModerationWatch
	if moderation:
		garage_screen.get_parent().add_child(BanNotice.new(self, moderation))   # yasak: sebep + bitiş penceresi


## Showroom'dan kasa alındı: showroom kapanır, kamera garajın teslimat alanına, kasanın gelişine gider.
func _on_crate_purchased(uid: int) -> void:
	router.close_all()
	if _delivery:
		_delivery.focus_on_arrival(uid)
	var crate: Dictionary = _crates.get_crate(uid) if _crates else {}
	_show_notice(Loc.t("%s GARAJINA GELİYOR") % Loc.t(String(CrateCatalog.get_entry(crate.get("crate", &"")).get("display_name", Loc.t("KASA")))),
		HudPalette.COIN_DARK, 1.8)


## Görev ödülü kasa (İLK KASA): görev panosu açıkken ödül alınır ve kasa panonun ARKASINDA garaja
## iniyordu — oyuncu fark etmiyordu. Pano kapanır, kamera kasaya gider, ne yapacağı söylenir.
func _on_crate_added(uid: int) -> void:
	var crate: Dictionary = _crates.get_crate(uid) if _crates else {}
	if not String(crate.get("source", "")).begins_with("quest"):
		return   # showroom satın alması _on_crate_purchased'da
	router.close_all()
	_announce_quest_crate.call_deferred(uid)   # teslimat crate_added'den SONRA denenir (crates_changed)


func _announce_quest_crate(uid: int) -> void:
	if _crates and _crates.waiting_for_room(uid):
		return   # garajda yer yok: "yolda" bildirimi (_on_crate_blocked) MAĞAZA'yı gösterdi
	if _delivery:
		_delivery.focus_on_arrival(uid)
	_show_notice(Loc.t("İLK ARAÇ KASAN GARAJINA GELDİ\nKASAYA DOKUN VE AÇ"), HudPalette.COIN_DARK, 3.0)


## DEPOLARIM → GİT / GARAJIM: ARAÇLAR açıksa o yere geçer; dünyadan açılmışsa ARAÇLAR o yerde açılır. GARAJIM = dünyaya dön.
func _on_garage_chosen(garage: StringName) -> void:
	if garage == CarGarageManager.HOME:
		router.close_all()
		return
	if router.current_place() == &"garage":
		garage_screen.go_to_garage(garage)
		return
	garage_screen.open_on(garage)
	router.open(&"garage")


## SERGİ PLAKASI'nı açar (yalnız dünyada; araç sergide değilse açılmaz).
func show_exhibit(vehicle_id: StringName) -> void:
	if router.top() != &"" or exhibit_plate == null:
		return
	hide_bay_plate()
	hide_car_info()
	exhibit_plate.show_for(vehicle_id)


## YERLEŞTİR sırası (docs/GARAJLAR_TASARIM.md §10): yeni araç (kasa, galeri, hurdalık, ödül) ekran boşken tek tek
## sorulur. Beklerken araç varsayılan yerindedir (boş yeri olan en üst depo, yoksa otopark): hiçbir şey kaybolmaz.
## Arayüzü kodla süren testler (CT_NO_TUTORIAL=1, tools/run_tests.sh) soruları kapatır: koddan eklenen araçlar
## panoyu açıp ekranın üstüne çıkmasın. Panoyu sınayan test `placement_prompts = true` verir.
var placement_prompts: bool = not TutorialDirector.disabled_by_env()
## Oyuncunun İLK aracı (hoş geldin kutusu): YERLEŞTİR sorulmaz, düzenleme kipi araç parmakta açılır (kullanıcı kararı
## 2026-10-20). İLK TAMİR dersi bunu kendi adımında açar (place_first_car); ders yoksa _try_placement.
var first_car: StringName = &""
## GARAJIM sergisine sığmayan yeni araç, DEPO DERSİ henüz yapılmadıysa: ders bununla başlar ("GARAJIN DOLDU!").
var garage_full_vehicle: StringName = &""


func _queue_placement(vehicle_id: StringName) -> void:
	if not placement_prompts or GarageVisit.is_visiting() or car_placement_screen == null \
			or get_tree().get_first_node_in_group("car_garages") == null:
		return
	if _ownership.owned_count() == 1:
		first_car = vehicle_id
	if not _placement_queue.has(vehicle_id):
		_placement_queue.append(vehicle_id)
	if _placement_timer == null:
		_placement_timer = Timer.new()
		_placement_timer.name = "PlacementTimer"
		_placement_timer.wait_time = 0.4
		_placement_timer.timeout.connect(_try_placement)
		add_child(_placement_timer)
	if _placement_timer.is_stopped():
		_placement_timer.start()


## Boştayken açar: yalnız bir YER (ya da hiçbir şey) açık; pano, kasa / araç açılışı, ders, restorasyon töreni yok.
func _try_placement() -> void:
	var garages: CarGarageManager = get_tree().get_first_node_in_group("car_garages") as CarGarageManager
	_placement_queue = _placement_queue.filter(func(id: StringName) -> bool:   # beklerken satılan / sergilenen atılır
		return _ownership != null and _ownership.is_owned(id) \
			and (garages == null or garages.garage_of(id) != CarGarageManager.HOME))
	if _placement_queue.is_empty():
		_placement_timer.stop()
		return
	var top: StringName = router.top()
	if (top != &"" and top != router.current_place()) or crate_panel.visible or (_delivery and _delivery.is_revealing()) \
			or (showroom and showroom.visible and showroom.is_revealing()) or (tutorial and tutorial.is_running()) \
			or get_tree().root.get_node_or_null("LoadingScreen") != null:
		return
	var restoration: RestorationBays = get_tree().get_first_node_in_group("restoration_bays") as RestorationBays
	if restoration and restoration.is_celebrating():
		return
	var vehicle: StringName = _placement_queue.pop_front()
	if vehicle == first_car and place_first_car():
		return
	if not fits_home(vehicle):
		_on_garage_full(vehicle)
		return
	car_placement_screen.vehicle_id = vehicle
	router.open(&"car_placement")


## GARAJIMA KOY: düzenleme kipi aracı parmakta açar (vazgeçerse araç varsayılan yerinde kalır).
## Garaja sığmıyorsa (ARAÇLAR → SERGİLE) düzenleme açılmaz: araç parmakta kalıp hiçbir yere konamazdı.
func _place_at_home(vehicle_id: StringName) -> void:
	if not fits_home(vehicle_id):
		_show_notice(Loc.t("GARAJINDA YER YOK\nEŞYALARI TAŞI YA DA GARAJI BÜYÜT"), HudPalette.DANGER, 2.6)
		return
	garage_edit_screen.place_on_open(GarageDecor.vehicle_item_id(vehicle_id))
	router.open(&"garage_edit")


## İlk aracı garaja koydurur (düzenleme kipi, araç parmakta). Bekleyen ilk araç yoksa / sergideyse / sığmıyorsa false.
func place_first_car() -> bool:
	if not has_first_car():
		first_car = &""
		return false
	var vehicle: StringName = first_car
	first_car = &""
	_placement_queue.erase(vehicle)
	_place_at_home(vehicle)
	return true


func has_first_car() -> bool:
	var garages: CarGarageManager = get_tree().get_first_node_in_group("car_garages") as CarGarageManager
	return first_car != &"" and _ownership != null and _ownership.is_owned(first_car) and garages != null \
		and garages.garage_of(first_car) != CarGarageManager.HOME and fits_home(first_car)


## Araç GARAJIM sergisine (ana garajın zemini) sığıyor mu. Görünüm yoksa sorun sayılmaz (YERLEŞTİR karar verir).
func fits_home(vehicle_id: StringName) -> bool:
	var view: GarageDecorView = get_tree().get_first_node_in_group("garage_decor_view") as GarageDecorView
	return view == null or view.has_room_for(GarageDecor.vehicle_item_id(vehicle_id))


## Yeni araç GARAJIM'a sığmadı (kullanıcı kararı 2026-10-20): YERLEŞTİR sorulmaz, araç varsayılan yerinde kalır (boş
## yeri olan depo, yoksa otopark). DEPO DERSİ yapılmadıysa ders başlar (Rıza Usta → DEPOLARIM); yapıldıysa kısa
## bildirim, dokununca aracın deposu / otoparkı o araçla açılır.
func _on_garage_full(vehicle_id: StringName) -> void:
	var lessons: TutorialManager = get_tree().get_first_node_in_group("tutorial") as TutorialManager
	if tutorial and lessons and not lessons.is_done(TutorialManager.GARAGES):
		garage_full_vehicle = vehicle_id
		return
	var garages: CarGarageManager = get_tree().get_first_node_in_group("car_garages") as CarGarageManager
	var place: StringName = garages.garage_of(vehicle_id) if garages else CarGarageManager.WAITING
	var where: String = CarGarageCatalog.display_name(place) if CarGarageCatalog.has(place) else Loc.t("OTOPARK")
	var title: String = String(CarCatalog.get_entry(vehicle_id).get("display_name", vehicle_id)).to_upper()
	_show_notice("%s → %s\n%s" % [title, where, Loc.t("GARAJINDA YER YOK · GÖRMEK İÇİN DOKUN")],
		HudPalette.DANGER if place == CarGarageManager.WAITING else HudPalette.INK, 4.0, _open_cars_on.bind(vehicle_id))


## Aracın deposunu / otoparkını açar (araç lifte).
func _open_cars_on(vehicle_id: StringName) -> void:
	if _ownership == null or not _ownership.is_owned(vehicle_id):
		return
	var place: StringName = router.current_place()
	if router.top() != place:
		return   # üstte pano var
	if place == &"garage":
		garage_screen.show_vehicle(vehicle_id)
		return
	if place != &"":
		return   # düzenleme / yarış / hurdalık: oyuncunun işi bölünmez
	garage_screen.open_on_vehicle(vehicle_id)
	router.open(&"garage")
	garage_screen.focus_cars()


## HOŞ GELDİN KUTUSU hatırlatması: kutuyu eğitim göstermiyorsa (ders atlandı / kapalı / bitti) oyuncu boştayken
## kamera kutuya gider ve ne yapacağı söylenir. Eğitim çalışırken, ekran açıkken ya da kutu açılırken beklenir;
## oturum başına en çok WELCOME_NUDGES kez, kutu açılınca durur.
func _nudge_welcome() -> void:
	var uid: int = _crates.welcome_uid() if _crates else 0
	if uid == 0:
		_welcome_timer.stop()
		return
	if (tutorial and tutorial.is_running()) or router.top() != &"" or crate_panel.visible or _delivery.is_revealing() \
			or _delivery.visual_of(uid) == null or not _crates.can_open(uid) \
			or get_tree().root.get_node_or_null("LoadingScreen") != null:
		return   # bir sonraki turda yeniden bakılır
	_welcome_nudges += 1
	_delivery.focus_on_arrival(uid)
	_show_notice(Loc.t("HOŞ GELDİN HEDİYEN GARAJINDA\nKUTUYA DOKUN VE AÇ"), HudPalette.COIN_DARK, 3.0)
	if _welcome_nudges >= WELCOME_NUDGES:
		_welcome_timer.stop()
	else:
		_welcome_timer.start(WELCOME_NUDGE_REPEAT)


## Dünyadaki kasaya dokunuldu: içerik GİZLİ soru plakası.
func _on_crate_clicked(uid: int) -> void:
	if router.top() != &"" or _crates == null or not _crates.can_open(uid):
		return
	hide_bay_plate()
	hide_car_info()
	crate_panel.show_prompt(uid, _crates.get_crate(uid).get("crate", &""))


func _on_crate_open_pressed(uid: int) -> void:
	if _delivery == null or not _delivery.open_crate(uid):
		_show_notice(Loc.t("KASA ŞU AN AÇILAMIYOR"), HudPalette.INK, 1.4)


func _on_crate_revealed(uid: int, result: Dictionary) -> void:
	crate_panel.show_result(uid, result)


func _on_crate_done_pressed(uid: int) -> void:
	if _delivery:
		_delivery.finish_reveal(uid)


## Garajda yer yok: kasa "yolda" kalır ve MAĞAZA'dan açılır (kullanıcı kararı). Mağaza açıkken bildirim yok —
## yer yokken alınan kasa orada YOLDAKİ KASALAR'da seçili gelir.
func _on_crate_blocked(uid: int) -> void:
	_refresh_shop_badge()
	if _blocked_notified.has(uid) or (showroom and showroom.visible):
		_blocked_notified[uid] = true
		return
	_blocked_notified[uid] = true
	_show_notice(Loc.t("KASA YOLDA: GARAJDA YER YOK\nSHOWROOM'DAN AÇABİLİRSİN"), HudPalette.INK, 2.6)


func _refresh_shop_badge() -> void:
	shop_button.badge = _crates.undelivered().size() if _crates and not GarageVisit.is_visiting() else 0


## MAĞAZA ekranı: bina hitbox'ı ya da MAĞAZA sekmesi açar, oyun HUD'u gizlenir, GERİ ile döner.
func _build_showroom() -> void:
	showroom = ShowroomScreen.new()
	garage_screen.get_parent().add_child(showroom)   # temalı Root'un altına, en üste
	showroom.vehicle_purchased.connect(_on_vehicle_purchased)
	showroom.crate_purchased.connect(_on_crate_purchased)
	showroom.screen_requested.connect(func(id: StringName) -> void: router.open(id))


## PLAYER tabelası temalı Root'un en üstünde durur (showroom'un da üstünde: kayıt seçimi her yerde görünür).
## AYARLAR: dişli tabela sağ üst tabela sırasının sonuna (kameranın yanına) kodla eklenir.
func _build_settings() -> void:
	settings_screen = SettingsScreen.new()
	garage_screen.get_parent().add_child(settings_screen)
	# AYARLAR tam ekran ve opak bir YER: üstünde açılan panolar (OYUN HESABI → hesap panosu) ondan SONRA
	# çizilmeli. Hesap panosu daha önce kurulduğu için arkada kalıyordu (açılıyor ama görünmüyordu).
	settings_screen.get_parent().move_child(settings_screen, login_screen.get_index())
	settings_screen.screen_requested.connect(func(id: StringName) -> void: router.open(id))
	settings_button = PlateButton.new()
	settings_button.name = "SettingsButton"
	settings_button.theme_type_variation = camera_button.theme_type_variation
	settings_button.shape = PlateButton.Shape.ROUND
	settings_button.kind = HudIcon.Kind.GEAR
	settings_button.icon_size = camera_button.icon_size
	settings_button.custom_minimum_size = camera_button.custom_minimum_size
	settings_button.bolts = false
	settings_button.lift_when_pressed = 0.0
	settings_button.focus_mode = Control.FOCUS_NONE
	settings_button.pressed.connect(func() -> void: router.open(&"settings"))
	camera_button.get_parent().add_child(settings_button)


## KAMERA KUTUSU: tabela sırasının hemen altına girer (GÖREVLER / ARKADAŞLAR açıkken bir sıra aşağı kayar).
## Sahnedeki yakınlaştırma tabelaları (eski kamera şeridi) kutuya taşınır; boş kalan şerit gizli kalır.
## Tabela sırası sağa yaslanır: kutu sütunu genişletince kamera / dişli yerinden kaymasın (sola yaslıyken kayıyordu).
func _build_camera_menu() -> void:
	camera_menu = CameraMenu.new()
	camera_menu.anchor_button = camera_button
	var sign_row: HBoxContainer = camera_button.get_parent() as HBoxContainer
	sign_row.alignment = BoxContainer.ALIGNMENT_END
	var column: Node = sign_row.get_parent()
	column.add_child(camera_menu)
	column.move_child(camera_menu, sign_row.get_index() + 1)
	camera_menu.adopt_zoom_buttons(zoom_out_button, zoom_in_button)
	camera_menu.dismissed.connect(func() -> void: camera_button.button_pressed = false)
	camera_menu.photo_requested.connect(open_photo_mode.bind(PhotoMode.Mode.PHOTO))
	camera_menu.hide_hud_requested.connect(open_photo_mode.bind(PhotoMode.Mode.CLEAN))
	camera_menu.cinema_requested.connect(open_photo_mode.bind(PhotoMode.Mode.CINEMA))
	camera_menu.recenter_requested.connect(camera_recenter_requested.emit)
	photo_mode = PhotoMode.new()
	garage_screen.get_parent().add_child(photo_mode)


## FOTOĞRAF / HUD GİZLİ / SİNEMA katmanını açar (UiRouter "photo"; GERİ ya da katmanın düğmesi kapatır).
func open_photo_mode(mode: PhotoMode.Mode) -> void:
	camera_button.button_pressed = false
	if router.is_open(&"photo"):
		return
	photo_mode.mode = mode
	router.open(&"photo")


func _build_login_screen() -> void:
	login_screen = LoginScreen.new()
	garage_screen.get_parent().add_child(login_screen)


## ARKADAŞ DAVETİ: link açılınca (InviteLinks) oyuncu boşta kalınca (açık ekran / ders / yükleme yok, ziyarette
## değil) davet ekranı açılır. Giriş ya da takma ad için ayrıldıysa oturum hazır olunca BİR kez daha açılır (misafir
## kalırsa ısrar etmez). Google girişi sahneyi yeniler: bekleyen davet (InviteLinks.pending) yeni HUD'da da açılır.
var _invite_links: InviteLinks
var _invite_wanted: bool = false
var _invite_after_session: bool = false


func _build_invites() -> void:
	invite_screen = InviteScreen.new()
	garage_screen.get_parent().add_child(invite_screen)
	invite_screen.screen_requested.connect(func(id: StringName) -> void:
		_invite_after_session = true
		router.open(id))
	_invite_links = InviteLinks.new()
	add_child(_invite_links)
	_invite_links.invite_opened.connect(func(_token: String) -> void: _invite_wanted = true)
	_invite_wanted = not InviteLinks.pending.is_empty()
	var timer: Timer = Timer.new()
	timer.name = "InviteTimer"
	timer.wait_time = 0.5
	add_child(timer)
	timer.timeout.connect(_tick_invite)
	timer.start()


func _tick_invite() -> void:
	var token: String = InviteLinks.pending
	if token.is_empty() or invite_screen.visible or not router.top().is_empty() or (tutorial and tutorial.is_running()) \
			or get_tree().root.get_node_or_null("LoadingScreen") != null or GarageVisit.is_visiting():
		return
	var social: SocialManager = get_tree().get_first_node_in_group("social") as SocialManager
	if not _invite_wanted and not (_invite_after_session and social != null and social.is_ready()):
		return
	_invite_wanted = false
	_invite_after_session = false
	router.open(&"invite")
	invite_screen.show_token(token)


func _build_push_prompt() -> void:
	push_prompt = PushPrompt.new()
	garage_screen.get_parent().add_child(push_prompt)


func _build_news() -> void:
	news_screen = NewsScreen.new()
	garage_screen.get_parent().add_child(news_screen)
	news_flow = NewsFlow.new()
	news_flow.hud = self
	news_flow.screen = news_screen
	add_child(news_flow)


## YARIŞ BİLDİRİMİ ÖNERİSİ (kullanıcı kararı): izin oyun açılışında değil İLK YARIŞTAN SONRA istenir — o an oyuncu ne
## için olduğunu bilir. Yarış bitince kurulur; oyuncu sonuç / rövanş ekranlarından şehre dönüp PUSH_PROMPT_IDLE sn boşta
## kalınca (açık ekran, ders, kasa / restorasyon plakası yok) öneri açılır. Bildirim açılamıyorsa (misafir / PC) kurulmaz:
## giriş yapan oyuncuya bir sonraki yarıştan sonra sorulur. Bu cihazda bir kez (PushService.should_ask).
const PUSH_PROMPT_IDLE: float = 1.5
var _push_prompt_timer: Timer
var _push_prompt_idle: float = 0.0


func _arm_push_prompt() -> void:
	var push: PushService = get_tree().get_first_node_in_group("push") as PushService
	if push == null or not push.should_ask() or is_instance_valid(_push_prompt_timer) or GarageVisit.is_visiting():
		return
	_push_prompt_idle = 0.0
	_push_prompt_timer = Timer.new()
	_push_prompt_timer.name = "PushPromptTimer"
	_push_prompt_timer.wait_time = 0.5
	add_child(_push_prompt_timer)
	_push_prompt_timer.timeout.connect(_tick_push_prompt.bind(push))
	_push_prompt_timer.start()


func _tick_push_prompt(push: PushService) -> void:
	if not push.should_ask():
		_push_prompt_timer.queue_free()
		return
	if not router.top().is_empty() or (tutorial and tutorial.is_running()) or (crate_panel and crate_panel.visible) \
			or (restoration_result and restoration_result.visible) or get_tree().root.get_node_or_null("LoadingScreen") != null:
		_push_prompt_idle = 0.0
		return
	_push_prompt_idle += _push_prompt_timer.wait_time
	if _push_prompt_idle < PUSH_PROMPT_IDLE:
		return
	_push_prompt_timer.queue_free()
	router.open(&"push_prompt")


func _on_profile_button_pressed() -> void:
	router.open(&"profile")


## GÖREVLER ve ARKADAŞLAR plakaları alt sıraya (NavRow) PROFİL'in yerine eklenir (2026-10-23, kullanıcı: "görevler ve
## arkadaşlar alt bara insin, profil kalksın"); PROFİL plakası gizlenir — sol üstteki avatar profili açar. Düğme nesnesi
## kalır (avatar dokusu, sekme eşlemesi). HARİTA plakası (hikâyeyle görünür) sonra eklenir, sıranın sonunda durur.
func _nav_plate(plate_name: String, label: String, icon: HudIcon.Kind) -> PlateButton:
	var plate: PlateButton = PlateButton.new()
	plate.name = plate_name
	plate.custom_minimum_size = garage_button.custom_minimum_size
	plate.theme_type_variation = &"HudPlate"
	plate.kind = icon
	plate.text = label
	plate.focus_mode = Control.FOCUS_NONE
	var row: Node = garage_button.get_parent()
	row.add_child(plate)
	row.move_child(plate, profile_button.get_index())
	return plate


func _build_quests() -> void:
	profile_button.visible = false
	quest_button = _nav_plate("QuestButton", Loc.t("GÖREVLER"), HudIcon.Kind.TASKS)
	quest_button.pressed.connect(_on_quest_button_pressed)
	quest_screen = MissionScreen.new()
	garage_screen.get_parent().add_child(quest_screen)
	quest_screen.attach_hud(self)


func _build_friends() -> void:
	friends_button = _nav_plate("FriendsButton", Loc.t("ARKADAŞLAR"), HudIcon.Kind.FRIENDS)
	friends_button.pressed.connect(func() -> void: router.open(&"friends"))
	friends_screen = FriendsScreen.new()
	garage_screen.get_parent().add_child(friends_screen)
	friends_screen.screen_requested.connect(func(id: StringName) -> void: router.open(id))
	friend_card_screen = FriendCardScreen.new()
	garage_screen.get_parent().add_child(friend_card_screen)
	friend_card_screen.screen_requested.connect(func(id: StringName) -> void: router.open(id))
	friends_screen.person_requested.connect(func(uid: String) -> void:
		if friend_card_screen.show_for(uid):
			router.open(&"friend_card"))
	friends_screen.revenge_requested.connect(_start_revenge)


## OTOPARK SAYACI: sağ üst sütunun sonunda (MARKET'in altında) ParkingBadge (P tabelası, OTOPARK, günlük ücret, araç sayısı
## balonda); dokununca DEPOLARIM OTOPARK basamağıyla açılır. Otopark boşken ve ziyarette görünmez.
func _build_lot_counter() -> void:
	var garages: CarGarageManager = get_tree().get_first_node_in_group("car_garages") as CarGarageManager
	if garages == null:
		return
	lot_button = ParkingBadge.new()   # mavi P tabelası + OTOPARK + günlük ücret, araç sayısı köşe balonunda
	lot_button.name = "LotButton"
	lot_button.pressed.connect(func() -> void:
		router.open(&"car_garages")
		car_garages_screen.select(CarGarageManager.WAITING))
	camera_controls.get_parent().add_child(lot_button)
	garages.layout_changed.connect(_refresh_lot_counter)
	garages.garages_changed.connect(_refresh_lot_counter)
	_refresh_lot_counter()


func _refresh_lot_counter() -> void:
	var garages: CarGarageManager = get_tree().get_first_node_in_group("car_garages") as CarGarageManager
	if lot_button == null or garages == null:
		return
	var cars: int = garages.waiting_ids().size()
	lot_button.visible = cars > 0 and not GarageVisit.is_visiting()
	lot_button.set_state(cars, garages.daily_fee())


## ETKİNLİK PANOSU düğmeleri: mağaza (etkinlik kasası seçili), dekor, ETKİNLİK görevleri, özel rakip yarışı.
func _on_event_action(kind: StringName, arg: StringName) -> void:
	match kind:
		&"showroom":
			if arg != &"":
				showroom.open_on_crate(arg)
			router.open(&"showroom")
		&"decor":
			router.open(&"garage_edit")
		&"missions":
			quest_screen.open_on_event()
			router.open(&"quests")
		&"race":
			start_event_race()


## ÖZEL RAKİP: canlı etkinliğin rakibine karşı pist doğrudan açılır (yoldaki davet kapanır; RaceManager.start_event_rival).
func start_event_race() -> bool:
	if _race == null or not _race.start_event_rival():
		return false
	router.close_all()
	_race.set_racing(true)
	router.open(&"drag_race")
	return true


## İNTİKAM AL (yarış haberi): arkadaşın senin aracını yendiği aracına karşı pist doğrudan açılır. Haber kullanılınca
## silinir (bir kez). Yoldaki davet varsa kapanır (RaceManager.start_revenge).
func _start_revenge(uid: String) -> void:
	if _social == null or _race == null:
		return
	var event: Dictionary = _social.race_event(uid)
	var owner: Dictionary = _social.revenge_owner(uid)
	if event.is_empty() or not _race.start_revenge(owner, event["car"]):
		return
	_social.dismiss_event(uid)
	router.close_all()
	_race.set_racing(true)
	router.open(&"drag_race")


## PROFİL: sol üstteki avatar düğmesi (seviye rozetinin solunda; dokununca PROFİL), profil düzenleme ve
## fotoğraf alt panoları. Avatar / çerçeve PlayerProfile değişince güncellenir.
func _build_profile_screens() -> void:
	var host: Node = garage_screen.get_parent()
	avatar_cropper = AvatarCropper.new()
	host.add_child(avatar_cropper)
	camera_capture = CameraCapture.new()
	host.add_child(camera_capture)
	profile_edit_screen = ProfileEditScreen.new()
	host.add_child(profile_edit_screen)
	profile_edit_screen.cropper = avatar_cropper
	profile_edit_screen.camera = camera_capture
	profile_edit_screen.screen_requested.connect(func(id: StringName) -> void: router.open(id))
	# Kırpıcı ve kamera düzenleme ekranının ÜSTÜNDE çizilsin (aynı ebeveyn: sonra eklenen üstte)
	host.move_child(avatar_cropper, -1)
	host.move_child(camera_capture, -1)

	# Avatar + seviye rozeti üst üste: ortak kap avatardan LEVEL_BADGE_OVERHANG büyük; avatar sol üste, seviye
	# (sahnedeki LevelSign) sağ alt köşeye yaslanır → rozet avatarın kenarından dışarı taşar, yüzü kapatmaz. Rozet
	# ayrı dursaydı sol üst blok genişler, dar tuvalde panolar ona yer açarken sağdan taşıyordu (2026-10-16 taraması).
	var level_sign: Control = level_label.get_parent() as Control
	var row: Node = level_sign.get_parent()   # TopLeft/PlayerRow
	var slot: MarginContainer = MarginContainer.new()
	slot.name = "AvatarSlot"
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for side: String in ["left", "top", "right", "bottom"]:
		slot.add_theme_constant_override("margin_" + side, 0)
	row.add_child(slot)
	row.move_child(slot, level_sign.get_index())
	slot.custom_minimum_size = Vector2.ONE * (AVATAR_BUTTON_SIZE + LEVEL_BADGE_OVERHANG)
	avatar_button = AvatarButton.new()
	avatar_button.name = "AvatarButton"
	avatar_button.diameter = AVATAR_BUTTON_SIZE
	avatar_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	avatar_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	avatar_button.view.flag_left = true   # sağ alt köşe seviye rozetinin: bayrak sola (üst üste biniyorlardı)
	avatar_button.pressed.connect(_on_name_plate_pressed)
	slot.add_child(avatar_button)
	level_sign.reparent(slot, false)
	level_sign.custom_minimum_size = Vector2(LEVEL_BADGE_SIZE, LEVEL_BADGE_SIZE)
	level_sign.size_flags_horizontal = Control.SIZE_SHRINK_END
	level_sign.size_flags_vertical = Control.SIZE_SHRINK_END
	level_label.add_theme_font_size_override(&"font_size", LEVEL_BADGE_FONT)
	level_sign.set_meta(&"qa_badge", true)   # ekran taraması: avatarın köşesine bilerek biner
	_connect_profile.call_deferred()


func _connect_profile() -> void:
	var profile: PlayerProfile = get_tree().get_first_node_in_group("player_profile") as PlayerProfile
	if profile == null:
		avatar_button.show_avatar(ProfileCatalog.default_texture(), true)
		return
	var update: Callable = func() -> void:
		avatar_button.show_avatar(profile.my_texture(), profile.my_illustrated(), profile.frame_id, profile.flag)
	profile.changed.connect(update)
	profile.avatar_changed.connect(update)
	update.call()


func _connect_social() -> void:
	_social = get_tree().get_first_node_in_group("social") as SocialManager
	if _social:
		_social.changed.connect(_refresh_friends_button)
		# Hurdalık hediyesi / isteği gibi bildirimler ARKADAŞLAR ekranı dışında da görünsün (ekran açıkken
		# kendi yazı satırında gösteriyor)
		_social.notice.connect(func(text: String) -> void:
			if not router.top() in [&"friends", &"friend_card", &"profile_edit", &"junkyard", &"restoration", &"invite"]:   # onlar kendisi gösterir
				_show_notice(text, HudPalette.COIN_DARK, 2.4))
		# YARIŞ HABERİ: arkadaş senin aracına karşı yarıştı (ARKADAŞLAR ekranında İNTİKAM AL)
		_social.race_news.connect(func(event: Dictionary) -> void:
			if not (news_flow and news_flow.is_gathering()):   # girişte toplanan haberler gazetede (OTO MANŞET)
				_show_notice(FriendsScreen.event_notice(event), HudPalette.COIN_DARK, 3.2))
	_refresh_friends_button()


## Gelen istek + yarış haberi sayısı ARKADAŞLAR plakasının rozetinde (alt sırada sekme gibi durur: amber = seçili olurdu).
func _refresh_friends_button() -> void:
	if friends_button == null:
		return
	friends_button.text = Loc.t("ARKADAŞLAR")
	friends_button.badge = (_social.incoming.size() + _social.race_events.size()) if _social else 0
	friends_button.highlight = false


func _on_quest_button_pressed() -> void:
	router.open(&"quests")
	_refresh_quest_button()


## Alınabilir ödül (günlük + haftalık + başarım + rehber) sayısı GÖREVLER plakasının rozetinde.
func _refresh_quest_button() -> void:
	if quest_button == null:
		return
	quest_button.visible = true
	var count: int = (_quests.claimable_count() if _quests else 0) + (_missions.claimable_count() if _missions else 0)
	quest_button.text = Loc.t("GÖREVLER")
	quest_button.badge = count
	quest_button.highlight = false


func _on_quest_completed(quest_id: StringName) -> void:
	var entry: Dictionary = QuestCatalog.get_entry(quest_id)
	_show_notice(Loc.t("GÖREV TAMAMLANDI: %s") % Loc.t(String(entry.get("title", ""))), HudPalette.COIN_DARK, 2.2)


func _set_gameplay_hud_visible(shown: bool) -> void:
	top_left.visible = shown
	top_right.visible = shown
	bottom.visible = shown


## PANO AÇIKKEN HUD: dünyanın üstünde bir pano (görevler, profil, gem mağazası...) açıkken sağ üst sütun ve alt
## sekmeler panonun karartmasının altında zaten basılamaz; dar tuvalde (853 birim) panonun iki yanından taşıp
## üstüne biniyormuş gibi görünüyorlardı. Gizlenirler. Sol üst (seviye, para — ödüllerin uçtuğu sayaçlar)
## kalır; panolar ona binmesin diye bloğun yeri FitScroll'a payı olarak verilir.
func _sync_modal_hud() -> void:
	if router == null:
		return
	var place_open: bool = router.place_open()
	var modal: bool = router.top() != &"" and not place_open
	top_right.visible = not place_open and not modal
	garage_button.get_parent().visible = not modal   # alt sekmeler (NavRow)
	var editing: bool = router.top() in HUD_FREE_SCREENS
	if editing and top_left.visible:
		top_left.hide()
		_top_left_hidden_for_edit = true
	elif not editing and _top_left_hidden_for_edit:
		_top_left_hidden_for_edit = false
		top_left.show()
	FitScroll.set_reserve(get_tree(), screen_rect(top_left) if modal and top_left.visible else Rect2())


func _on_name_plate_pressed() -> void:
	select_nav_tab(&"profile")
	router.open(&"profile")


func _on_camera_toggled(pressed: bool) -> void:
	if pressed:
		camera_menu.open()
	else:
		camera_menu.close()


func _on_sound_toggled(muted: bool) -> void:
	sound_button.kind = HudIcon.Kind.SPEAKER_OFF if muted else HudIcon.Kind.SPEAKER
	sound_toggled.emit(not muted)


func _on_zoom_in_pressed() -> void:
	camera_zoom_requested.emit(1)


func _on_zoom_out_pressed() -> void:
	camera_zoom_requested.emit(-1)
