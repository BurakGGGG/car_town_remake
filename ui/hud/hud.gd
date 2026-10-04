class_name Hud
extends CanvasLayer
## Ana HUD — "yol mobilyası / plaka" dili.
## Sol üst: level tabelası + isim plakası + şerit XP + coin/gem.
## Sağ üst: yuvarlak tabela butonları (kamera / ses / AYARLAR dişlisi), kamera açılınca mini şerit.
## Alt: dört plaka (GARAJ / ARAÇLAR / MAĞAZA / PROFİL) ve seçilince açılan araç plakası.
## Araç satın alma artık alt menüde DEĞİL: haritadaki "CAR PARTS & SHOWROOM" binasına tıklanınca
## açılan MAĞAZA ekranındadır (ShowroomScreen, HUD'un altına kodla eklenir ve "showroom" grubundan
## bulunur). ARAÇLAR plakası bu yüzden pasiftir (sekme seçer, mağaza açmaz); garaj listesi
## (CarGallery, OWNED kipi) GarageScreen'in içinde kalır. Showroom açıkken oyun HUD'u gizlenir,
## kapanınca aynen geri gelir — GarageScreen ile aynı davranış.
## PROFİL plakası ve isim plakası PLAYER tabelasını (LoginScreen, kodla eklenir) açar: Google girişi,
## profil / çıkış ve bulut kayıt seçimi. Google hesabıyla girilince isim plakasında hesabın adı yazar
## (CloudSaveManager, "cloud_save" grubu); çıkışta player_name'e döner.
## Sağ üstte tabelaların altında GÖREVLER plakası GÖREVLER tabelasını (MissionScreen: günlük / haftalık / başarım, kodla eklenir) açar;
## alınabilir ödül varken plaka amber olur ve sayıyı gösterir. Görev tamamlanınca / ödül alınınca kısa
## bildirim plakası çıkar (QuestManager, "quests" grubu).
## Sadece görsel katman: değerler setter'larla gelir, butonlar sinyal olarak dışarı verilir.
## Oyun mantığı burada değil: tamir döngüsü için sahnedeki RepairManager ("repair_manager" grubu),
## para için EconomyManager ("economy" grubu) ve XP/seviye için PlayerProgress ("player_progress"
## grubu) bulunur, sinyalleri araç plakasına / sayaçlara
## yansıtılır; TAMİRE AL plakası RepairManager.start_repair'i, PARA TOPLA plakası collect'i çağırır.
## Ödül geri bildirimi ("+150 ₺  +7 XP") araç plakasının üstünde beliren küçük bir plakayla verilir
## (aynı yerine oturma animasyonu, sonra söner). Bunlar yoksa (ör. önizleme sahnesi) HUD eskisi gibi
## bağımsız çalışır.

signal nav_selected(id: StringName)
signal sound_toggled(enabled: bool)
## direction: +1 yakınlaş, -1 uzaklaş
signal camera_zoom_requested(direction: int)

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
## Kodla kurulan AYARLAR tabelası ve onu açan dişli tabela (sağ üst).
var settings_screen: SettingsScreen
var settings_button: PlateButton
## Kodla kurulan GÖREVLER tabelası ve onu açan plaka.
var quest_screen: MissionScreen
var quest_button: PlateButton
var _quests: QuestManager
var _missions: MissionManager
@onready var top_left: MarginContainer = %TopLeft
@onready var top_right: MarginContainer = %TopRight
@onready var bottom: MarginContainer = %Bottom

var _nav_group: ButtonGroup = ButtonGroup.new()
var _nav_ids: Dictionary = {}
var _car_tween: Tween

# Tamir döngüsü (sahnede varsa)
var _repair_panel: RepairPanel
var _repair_manager: RepairManager
var _player_progress: PlayerProgress
var _economy: EconomyManager
var _repair_target: Node3D
var _notice_plate: PlatePanel
var _notice_label: Label
var _notice_tween: Tween

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
var _race: RaceManager
var mastery_screen: MasteryScreen
## Avlu dekorasyonu panosu (dünyada avluya dokununca açılır).
var garage_edit_screen: GarageEditScreen
## GARAJ panelindeki DÜZENLE düğmesi (GaragePanel.edit_button).
var edit_button: PlateButton
var garage_panel: GaragePanel
var _garage_panel_open: bool = false
var garage_value_screen: GarageValueScreen
## KOLEKSİYON tabelası (showroom ve garaj ekranından açılır).
var collection_screen: CollectionScreen
## Dünyadaki teslimat kasasının AÇ / sonuç plakası.
var crate_panel: CratePanel
var _crates: CrateManager
var _delivery: CrateDelivery
var _blocked_notified: Dictionary = {}   # yer bulamayan kasa uid → uyarıldı mı
## Alt sekme → açtığı ekran.
var _nav_screens: Dictionary = {}


func _ready() -> void:
	camera_controls.visible = false
	car_info_panel.visible = false

	_nav_ids = {
		garage_button: &"garage",
		cars_button: &"cars",
		shop_button: &"shop",
		profile_button: &"profile",
	}
	# GARAJ sekmesi ekran AÇMAZ: ana görünüme (dünya garajı) döner ve alt paneli (GaragePanel:
	# genişlet / tamir hızı / düzenle / detay / ustalık) gösterir. ARAÇLAR yalnızca araçları
	# (GarageScreen), MAĞAZA showroom'u, PROFİL ilerleme panosunu açar.
	_nav_screens = {
		cars_button: &"garage",
		shop_button: &"showroom",
		profile_button: &"profile",
	}
	for button: PlateButton in _nav_ids:
		button.button_group = _nav_group
		button.toggled.connect(_on_nav_toggled.bind(button))
		button.pressed.connect(_on_nav_pressed.bind(button))
	garage_button.button_pressed = true
	_build_garage_panel()
	_build_router()
	_build_showroom()
	_build_login_screen()
	_build_settings()
	_build_quests()
	_build_progress_screens()
	_build_race_screens()
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
	car_stats_container.add_child(_repair_panel)
	_build_notice_plate()
	_build_bay_plate()
	_build_crate_panel()
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	_connect_gameplay.call_deferred()  # sahnedeki yöneticiler hazır olsun


## MOBİL GÜVENLİ ALAN — çentikli / yuvarlak köşeli telefonlarda (20:9) kenar plakaları ekran
## dışında kalmasın diye kenar boşlukları güvenli alana göre büyütülür. Masaüstünde hiçbir şey
## değişmez: yalnızca mobil derlemede uygulanır ve pencere ölçeği (viewport/pencere) hesaba katılır.
func _apply_safe_area() -> void:
	if not OS.has_feature("mobile"):
		return
	var window: Vector2i = DisplayServer.window_get_size()
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	if window.x <= 0 or window.y <= 0:
		return
	var scale: Vector2 = get_viewport().get_visible_rect().size / Vector2(window)
	var inset_left: int = int(round(float(maxi(safe.position.x, 0)) * scale.x))
	var inset_top: int = int(round(float(maxi(safe.position.y, 0)) * scale.y))
	var inset_right: int = int(round(float(maxi(window.x - safe.end.x, 0)) * scale.x))
	var inset_bottom: int = int(round(float(maxi(window.y - safe.end.y, 0)) * scale.y))
	top_left.add_theme_constant_override(&"margin_left", 10 + inset_left)
	top_left.add_theme_constant_override(&"margin_top", 10 + inset_top)
	top_right.add_theme_constant_override(&"margin_right", 10 + inset_right)
	top_right.add_theme_constant_override(&"margin_top", 10 + inset_top)
	bottom.add_theme_constant_override(&"margin_bottom", 10 + inset_bottom)


# --- Dış API -----------------------------------------------------------------

func set_player_name(value: String) -> void:
	name_plate.text = value.to_upper()


func set_level(value: int) -> void:
	level_label.text = str(value)


## 0.0 - 1.0 arası; bir sonraki level'a ilerleme.
func set_xp_ratio(value: float) -> void:
	xp_lane.ratio = value


func set_coins(value: int) -> void:
	coin_label.text = format_thousands(value)


func set_gems(value: int) -> void:
	gem_label.text = format_thousands(value)


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
	car_name_label.text = car_name
	if not car_info_enabled:
		return
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


## 12500 -> "12.500"
static func format_thousands(value: int) -> String:
	var digits: String = str(absi(value))
	var separator: String = "," if Loc.current() == "en" else "."   # TR / ES: 1.000 · EN: 1,000
	var out: String = ""
	var count: int = 0
	for i: int in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = separator + out
	return ("-" + out) if value < 0 else out


# --- Tamir döngüsü bağlantısı ----------------------------------------------------

## Aynı anda en fazla bu kadar bildirim beklet (fazlası oyuncuyu geride bırakır).
const NOTICE_QUEUE_MAX: int = 4

## Ses sistemi (müzik/SFX varlıkları + bus) bağlı mı? Şimdilik yok: SES düğmesi gizli kalır.
const AUDIO_AVAILABLE: bool = false

var _notice_queue: Array[Dictionary] = []
var _notice_busy: bool = false
## Son bilinen garaj rütbesi (rütbe atlayınca bildirim gösterilir; GarageValue'nun sinyali yoktur).
var _garage_rank: int = 0
## Yarış sonucunda teklif edilen ödüllü reklam bonusu (₺). 0 = teklif yok / verildi.
var _race_bonus_amount: int = 0
var _ads_bound: AdService = null
## Süre kısaltma reklamı izlenirken kısaltılacak araç.
var _boost_car: Node3D = null


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
		_player_progress.level_reward.connect(_on_level_reward)
		set_gems(_player_progress.gems)
		_on_xp_changed(_player_progress.level, _player_progress.xp, _player_progress.xp_to_next())
	_upgrades = get_tree().get_first_node_in_group("garage_upgrades") as GarageUpgradeManager
	_garage = get_tree().get_first_node_in_group("garage_system")
	if _upgrades:
		_upgrades.upgrade_purchased.connect(_on_upgrade_purchased)
	_bays = get_tree().get_first_node_in_group("repair_bays") as RepairBayManager
	if _bays:
		_bays.no_room.connect(func(_i: int) -> void:
			_show_notice(Loc.t("TAMİR ALANI İÇİN YER YOK\nBİR EŞYAYI TAŞI"), HudPalette.INK, 2.4))
		_bays.bay_unlocked.connect(_on_bay_unlocked)
		_bays.purchase_failed.connect(_on_bay_purchase_failed)
	_repair_manager = get_tree().get_first_node_in_group("repair_manager") as RepairManager
	if _repair_manager:
		_repair_manager.target_changed.connect(_on_repair_target_changed)
		_repair_manager.repair_started.connect(_on_repair_started)
		_repair_manager.repair_slot_freed.connect(_on_repair_slot_freed)
		_repair_manager.repair_progress.connect(_on_repair_progress)
		_repair_manager.repair_ready.connect(_on_repair_started)
		_repair_manager.repair_collected.connect(_on_repair_collected)
		_repair_manager.repair_cancelled.connect(_on_repair_cancelled)
		_repair_manager.customer_marked.connect(_on_customer_changed)
		_repair_manager.customer_stopped.connect(_on_customer_changed)
	var mastery: JobMastery = get_tree().get_first_node_in_group("job_mastery") as JobMastery
	if mastery:
		mastery.mastery_up.connect(_on_mastery_up)
	_quests = get_tree().get_first_node_in_group("quests") as QuestManager
	if _quests:
		_quests.quests_changed.connect(_refresh_quest_button)
		_quests.quest_completed.connect(_on_quest_completed)
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
		_ownership.paint_changed.connect(func(_id: StringName, _c: Color) -> void: _check_garage_rank())
	if _upgrades:
		_upgrades.levels_changed.connect(_check_garage_rank)
	if _bays:
		_bays.bays_changed.connect(_check_garage_rank)
	_check_garage_rank()
	_connect_crates()
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
			_repair_panel.show_repairing(state.repair_progress, state.remaining, _boost_offer(vehicle))
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
	if id != GarageUpgradeManager.GARAGE_ID:
		return
	hide_bay_plate()
	_show_notice(Loc.t("GARAJ SEVİYE %d") % level, HudPalette.COIN_DARK)


func _on_bay_unlocked(index: int) -> void:
	hide_bay_plate()
	_show_notice(Loc.t("TAMİR ALANI %d AÇILDI\nGARAJI DÜZENLE'DEN TAŞIYABİLİRSİN") % (index + 1), HudPalette.COIN_DARK, 2.4)


func _on_bay_purchase_failed(index: int, price: int) -> void:
	_show_notice(Loc.t("%s ₺ GEREKLİ") % format_thousands(price), HudPalette.INK)
	if _bay_plate.visible:
		show_bay_plate(index)   # plaka güncel durumu göstersin


## Bildirim plakası SIRAYLA gösterir: ödül toplamak seviye atlatabilir, seviye ustalık kademesi
## açabilir — aynı karede gelen bildirimler birbirini silmesin diye kuyruğa girer.
func _show_notice(text: String, color: Color, hold: float = 1.6) -> void:
	if _notice_plate == null:
		return
	_notice_queue.append({"text": text, "color": color, "hold": hold})
	if _notice_queue.size() > NOTICE_QUEUE_MAX:
		_notice_queue.pop_front()   # taşarsa en eskisi düşer (oyuncu güncel olanı görsün)
	if not _notice_busy:
		_drain_notices()


func _drain_notices() -> void:
	_notice_busy = true
	while not _notice_queue.is_empty():
		var notice: Dictionary = _notice_queue.pop_front()
		await _play_notice(String(notice["text"]), notice["color"], float(notice["hold"]))
	_notice_busy = false


func _play_notice(text: String, color: Color, hold: float) -> void:
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


## Seviye atlandı: para ödülü ve (varsa) açılan içerik plakada duyurulur.
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


func _on_level_reward(new_level: int, money: int, text: String) -> void:
	var line: String = Loc.t("SEVİYE %d   +%s ₺   +%d GEM") % [new_level, format_thousands(money),
		int(PlayerProgress.reward_for(new_level)["gems"])]
	if text != "":
		line += "\n%s" % text
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
	if _race:
		reward = _race.finish_race(won)
	race_result_screen.show_result(won, player_time, rival_time,
		int(reward["money"]), int(reward["xp"]), player_id if won else rival)
	# ÖDÜLLÜ REKLAM: yalnızca para kazanıldıysa ve politika + hazır reklam uygunsa teklif edilir (açık onay).
	_race_bonus_amount = 0
	var ads: AdService = _ads_service()
	if ads and int(reward["money"]) > 0 and ads.can_offer(AdPolicy.RACE_DOUBLE):
		_race_bonus_amount = int(reward["money"])
		race_result_screen.offer_bonus(_race_bonus_amount)
	router.open(&"race_result")


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


## GARAJA DÖN: sonuç ve pist kapanır, oyuncu dünyaya döner.
func _on_race_exit() -> void:
	_race_bonus_amount = 0
	if _race:
		_race.set_racing(false)
	if router.is_open(&"drag_race") or router.is_open(&"race_result"):
		router.close_all()


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


func _on_repair_progress(car: Node3D, progress: float) -> void:
	if car == _repair_target:
		var state: RepairState = _repair_manager.get_state(car)
		_repair_panel.show_repairing(progress, state.remaining if state else 0.0, _boost_offer(car))


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
		# GARAJ: açık yer / pano kapanır ve GARAJ paneli açılır; panel açıkken tekrar basmak kapatır.
		var in_world: bool = router.top() == &""
		router.close_all()
		_garage_panel_open = not (in_world and _garage_panel_open)
		_sync_garage_panel()
		return
	_garage_panel_open = false   # başka sekme: panel kapanır
	_sync_garage_panel()
	var id: StringName = _nav_screens.get(button, &"")
	if id == &"":
		return
	if router.is_open(id) and router.top() == id:
		router.back()
		return
	router.open(id)
	if button == cars_button and id == &"garage":
		garage_screen.focus_cars()   # ARAÇLAR sekmesi: garajdaki araç listesini öne çıkarır


## GARAJ sekmesinin alt paneli: sekme satırının (NavRow) hemen üstüne kodla eklenir (sahne düzenlenmez).
func _build_garage_panel() -> void:
	garage_panel = GaragePanel.new()
	var nav_row: Node = garage_button.get_parent()
	var column: Node = nav_row.get_parent()
	column.add_child(garage_panel)
	column.move_child(garage_panel, nav_row.get_index())
	edit_button = garage_panel.edit_button
	garage_panel.expand_requested.connect(show_expansion_plate)
	garage_panel.bay_requested.connect(show_bay_plate)
	garage_panel.edit_requested.connect(func() -> void: router.open(&"garage_edit"))
	garage_panel.value_requested.connect(func() -> void: router.open(&"garage_value"))
	garage_panel.mastery_requested.connect(func() -> void: router.open(&"mastery"))
	_sync_garage_panel()


## Panel varsayılan KAPALI: yalnızca GARAJ sekmesine basınca açılır; bir yer (araçlar, mağaza,
## düzenleme) açılınca ya da başka sekmeye basınca kapanır.
func _sync_garage_panel() -> void:
	if garage_panel:
		garage_panel.visible = _garage_panel_open and (router == null or not router.place_open())


func _build_router() -> void:
	router = UiRouter.new()
	router.name = "UiRouter"
	add_child(router)
	router.stack_changed.connect(_on_ui_stack_changed)
	router.exit_hint_requested.connect(func() -> void:
		_show_notice(Loc.t("Çıkmak için tekrar GERİ'ye bas"), Color(1.0, 0.9, 0.5), 1.8))
	router.back_override = _android_back_for_crate_panel


## Android GERİ, kasa panosu açıkken: "hazır" panosu kapanır (kasa beklemeye döner); sonuç panosu
## ödülü gösterir, GERİ ile geçilemez (yanlışlıkla kapatıp ödülü görmemeyi önler).
func _android_back_for_crate_panel() -> bool:
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
	profile_screen.screen_requested.connect(func(id: StringName) -> void: router.open(id))
	garage_screen.screen_requested.connect(func(id: StringName) -> void: router.open(id))


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
	race_challenge_screen.race_accepted.connect(_on_race_accepted)
	drag_race_screen.race_completed.connect(_on_race_completed)
	race_result_screen.exit_requested.connect(_on_race_exit)
	race_result_screen.closed.connect(_on_race_exit)
	race_result_screen.bonus_requested.connect(_on_race_bonus_requested)


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
	router.register(&"settings", settings_screen, UiRouter.Kind.PLACE)   # tam ekran: oyun arkada görünmez
	router.register(&"race_challenge", race_challenge_screen, UiRouter.Kind.MODAL)
	router.register(&"drag_race", drag_race_screen, UiRouter.Kind.PLACE)
	router.register(&"race_result", race_result_screen, UiRouter.Kind.MODAL)
	router.register(&"collection", collection_screen, UiRouter.Kind.MODAL)


## Yığın değişti: oyun HUD'u yalnızca bir YER (garaj/showroom) açıkken gizlenir; panolar
## (görevler, ustalık, rütbe, profil, hesap) HUD'un üstünde durur.
func _on_ui_stack_changed(top: StringName, place_open: bool) -> void:
	_set_gameplay_hud_visible(not place_open)
	if place_open:
		_garage_panel_open = false
	if top != &"":
		hide_bay_plate()   # dünya plakası bir ekranın altında asılı kalmasın
		hide_car_info()
		if crate_panel and crate_panel.mode() == &"prompt":
			crate_panel.hide_panel()
	_sync_nav_tab(router.current_place())
	_refresh_quest_button()


## Alt sekme, açık olan yeri gösterir (hiçbir yer açık değilse GARAJ sekmesi işaretli kalır).
func _sync_nav_tab(place: StringName) -> void:
	var target: PlateButton = garage_button
	match place:
		&"showroom":
			target = shop_button
		&"garage":
			target = cars_button
	# ButtonGroup set_pressed_no_signal ile diğerlerini bırakmıyor: iki sekme birden amber kalıyordu.
	for button: PlateButton in _nav_ids:
		button.set_pressed_no_signal(button == target)
	_sync_garage_panel()


# --- Araç teslimat kasaları ---------------------------------------------------------------

## Kasa plakası tamir alanı plakasıyla aynı sütunda (alt-orta) durur.
func _build_crate_panel() -> void:
	crate_panel = CratePanel.new()
	var column: Node = car_info_panel.get_parent()
	column.add_child(crate_panel)
	column.move_child(crate_panel, car_info_panel.get_index())
	crate_panel.open_pressed.connect(_on_crate_open_pressed)
	crate_panel.done_pressed.connect(_on_crate_done_pressed)


func _connect_crates() -> void:
	_crates = get_tree().get_first_node_in_group("crates") as CrateManager
	_delivery = get_tree().get_first_node_in_group("crate_delivery") as CrateDelivery
	if _crates:
		_crates.crate_added.connect(_on_crate_added)
	if _delivery:
		_delivery.crate_clicked.connect(_on_crate_clicked)
		_delivery.reveal_ready.connect(_on_crate_revealed)
		_delivery.delivery_blocked.connect(_on_crate_blocked)
	var gem_rewards: GemRewards = get_tree().get_first_node_in_group("gem_rewards") as GemRewards
	if gem_rewards:
		gem_rewards.reward_granted.connect(func(_amount: int, text: String) -> void:
			if text != "":
				_show_notice(text, HudPalette.INK, 1.8))


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
	if _delivery:
		_delivery.focus_on_arrival(uid)
	_show_notice(Loc.t("İLK ARAÇ KASAN GARAJINA GELDİ\nKASAYA DOKUN VE AÇ"), HudPalette.COIN_DARK, 3.0)


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


func _on_crate_blocked(uid: int) -> void:
	if _blocked_notified.has(uid):
		return
	_blocked_notified[uid] = true
	# Yeri dolduran dekor mu kasalar mı: yanlış yönlendirme olmasın (QA: dekorsuz garajda "dekoru kaldır" diyordu)
	var decor: DecorManager = get_tree().get_first_node_in_group("decor") as DecorManager
	var hint: String = Loc.t("BİRAZ DEKORASYONU KALDIR") if decor and decor.instance_count() > 0 else Loc.t("ÖNCE GARAJDAKİ BİR KASAYI AÇ")
	_show_notice(Loc.t("KASA YOLDA: GARAJDA YER YOK\n%s") % hint, HudPalette.INK, 2.4)


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


func _build_login_screen() -> void:
	login_screen = LoginScreen.new()
	garage_screen.get_parent().add_child(login_screen)


func _on_profile_button_pressed() -> void:
	router.open(&"profile")


## GÖREVLER plakası sağ üst tabela sırasının hemen altına (kamera kontrollerinin üstüne) eklenir.
func _build_quests() -> void:
	quest_button = PlateButton.new()
	quest_button.name = "QuestButton"
	quest_button.theme_type_variation = &"HudPlateSmall"
	quest_button.text = Loc.t("GÖREVLER")
	quest_button.focus_mode = Control.FOCUS_NONE
	quest_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	quest_button.pressed.connect(_on_quest_button_pressed)
	var column: Node = camera_controls.get_parent()
	column.add_child(quest_button)
	column.move_child(quest_button, camera_controls.get_index())
	quest_screen = MissionScreen.new()
	garage_screen.get_parent().add_child(quest_screen)
	quest_screen.reward_claimed.connect(func(text: String) -> void: _show_notice(text, HudPalette.COIN_DARK))


func _on_quest_button_pressed() -> void:
	router.open(&"quests")
	_refresh_quest_button()


## Alınabilir ödül (günlük + haftalık + başarım + rehber) varsa plaka amber olur ve sayıyı gösterir.
func _refresh_quest_button() -> void:
	if quest_button == null:
		return
	quest_button.visible = true
	var count: int = (_quests.claimable_count() if _quests else 0) + (_missions.claimable_count() if _missions else 0)
	quest_button.text = Loc.t("GÖREVLER (%d)") % count if count > 0 else Loc.t("GÖREVLER")
	quest_button.highlight = count > 0


func _on_quest_completed(quest_id: StringName) -> void:
	var entry: Dictionary = QuestCatalog.get_entry(quest_id)
	_show_notice(Loc.t("GÖREV TAMAMLANDI: %s") % Loc.t(String(entry.get("title", ""))), HudPalette.COIN_DARK, 2.2)


func _set_gameplay_hud_visible(shown: bool) -> void:
	top_left.visible = shown
	top_right.visible = shown
	bottom.visible = shown


func _on_name_plate_pressed() -> void:
	select_nav_tab(&"profile")
	router.open(&"profile")


func _on_camera_toggled(pressed: bool) -> void:
	camera_controls.visible = pressed


func _on_sound_toggled(muted: bool) -> void:
	sound_button.kind = HudIcon.Kind.SPEAKER_OFF if muted else HudIcon.Kind.SPEAKER
	sound_toggled.emit(not muted)


func _on_zoom_in_pressed() -> void:
	camera_zoom_requested.emit(1)


func _on_zoom_out_pressed() -> void:
	camera_zoom_requested.emit(-1)


