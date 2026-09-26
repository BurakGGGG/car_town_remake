class_name Hud
extends CanvasLayer
## Ana HUD — "yol mobilyası / plaka" dili.
## Sol üst: level tabelası + isim plakası + şerit XP + coin/gem.
## Sağ üst: yuvarlak tabela butonları (kamera / ses / ayarlar), kamera açılınca mini şerit.
## Alt: dört plaka (GARAJ / ARAÇLAR / MAĞAZA / PROFİL) ve seçilince açılan araç plakası.
## Araç satın alma artık alt menüde DEĞİL: haritadaki "CAR PARTS & SHOWROOM" binasına tıklanınca
## açılan ARABA GALERİSİ'ndedir (ShowroomScreen, HUD'un altına kodla eklenir ve "showroom" grubundan
## bulunur). ARAÇLAR plakası bu yüzden pasiftir (sekme seçer, mağaza açmaz); garaj listesi
## (CarGallery, OWNED kipi) GarageScreen'in içinde kalır. Showroom açıkken oyun HUD'u gizlenir,
## kapanınca aynen geri gelir — GarageScreen ile aynı davranış.
## PROFİL plakası ve isim plakası PLAYER tabelasını (LoginScreen, kodla eklenir) açar: Google girişi,
## profil / çıkış ve bulut kayıt seçimi. Google hesabıyla girilince isim plakasında hesabın adı yazar
## (CloudSaveManager, "cloud_save" grubu); çıkışta player_name'e döner.
## Sağ üstte tabelaların altında GÖREVLER plakası GÖREVLER tabelasını (QuestScreen, kodla eklenir) açar;
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
signal settings_pressed
signal sound_toggled(enabled: bool)
## direction: +1 yakınlaş, -1 uzaklaş
signal camera_zoom_requested(direction: int)
signal camera_rotate_requested

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
@onready var settings_button: PlateButton = %SettingsButton
@onready var camera_controls: VBoxContainer = %CameraControls
@onready var zoom_in_button: PlateButton = %ZoomInButton
@onready var zoom_out_button: PlateButton = %ZoomOutButton
@onready var rotate_button: PlateButton = %RotateButton

# Alt
@onready var car_info_panel: PlatePanel = %CarInfoPanel
@onready var car_name_label: Label = %CarNameLabel
@onready var car_stats_container: HBoxContainer = %CarStatsContainer
@onready var car_actions_container: HBoxContainer = %CarActionsContainer
@onready var garage_button: PlateButton = %GarageButton
@onready var cars_button: PlateButton = %CarsButton
@onready var shop_button: PlateButton = %ShopButton
@onready var profile_button: PlateButton = %ProfileButton
@onready var car_gallery: CarGallery = %CarGallery
@onready var garage_screen: GarageScreen = %GarageScreen
## Kodla kurulan tam ekran ARABA GALERİSİ (bina tıklamasıyla açılır).
var showroom: ShowroomScreen
## Kodla kurulan PLAYER tabelası (giriş / profil / kayıt seçimi).
var login_screen: LoginScreen
## Kodla kurulan GÖREVLER tabelası ve onu açan plaka.
var quest_screen: QuestScreen
var quest_button: PlateButton
var _quests: QuestManager
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
var _bay_plate: PlatePanel
var _bay_title: Label
var _bay_price: Label
var _bay_buy: PlateButton
var _bay_index: int = -1
var _plate_mode: StringName = &"bay"   # &"bay" ya da &"garage"
var _upgrades: GarageUpgradeManager
var _garage: Node
var _ownership: VehicleOwnership


func _ready() -> void:
	camera_controls.visible = false
	car_info_panel.visible = false
	car_gallery.visible = false

	_nav_ids = {
		garage_button: &"garage",
		cars_button: &"cars",
		shop_button: &"shop",
		profile_button: &"profile",
	}
	for button: PlateButton in _nav_ids:
		button.button_group = _nav_group
		button.toggled.connect(_on_nav_toggled.bind(button))
	garage_button.button_pressed = true
	garage_button.pressed.connect(_on_garage_button_pressed)
	garage_screen.closed.connect(_on_garage_closed)
	_build_showroom()
	_build_login_screen()
	_build_quests()

	name_plate.pressed.connect(_on_name_plate_pressed)
	profile_button.pressed.connect(_on_profile_button_pressed)
	camera_button.toggled.connect(_on_camera_toggled)
	sound_button.toggled.connect(_on_sound_toggled)
	settings_button.pressed.connect(_on_settings_pressed)
	zoom_in_button.pressed.connect(_on_zoom_in_pressed)
	zoom_out_button.pressed.connect(_on_zoom_out_pressed)
	rotate_button.pressed.connect(_on_rotate_pressed)

	set_player_name(player_name)
	set_level(level)
	set_xp_ratio(xp_ratio)
	set_coins(coins)
	set_gems(gems)

	_repair_panel = RepairPanel.new()
	_repair_panel.repair_pressed.connect(_on_repair_pressed)
	_repair_panel.collect_pressed.connect(_on_collect_pressed)
	car_stats_container.add_child(_repair_panel)
	_build_notice_plate()
	_build_bay_plate()
	_connect_gameplay.call_deferred()  # sahnedeki yöneticiler hazır olsun


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
	var out: String = ""
	var count: int = 0
	for i: int in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return ("-" + out) if value < 0 else out


# --- Tamir döngüsü bağlantısı ----------------------------------------------------

## Aynı anda en fazla bu kadar bildirim beklet (fazlası oyuncuyu geride bırakır).
const NOTICE_QUEUE_MAX: int = 4

var _notice_queue: Array[Dictionary] = []
var _notice_busy: bool = false
## Son bilinen garaj rütbesi (rütbe atlayınca bildirim gösterilir; GarageValue'nun sinyali yoktur).
var _garage_rank: int = 0


func _connect_gameplay() -> void:
	_economy = get_tree().get_first_node_in_group("economy") as EconomyManager
	if _economy:
		_economy.money_changed.connect(set_coins)
		_economy.money_changed.connect(func(_m: int) -> void: _refresh_repair_panel(false))  # bakiye → buton durumu
		set_coins(_economy.money)
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
	if _garage and _garage.has_signal(&"expand_clicked"):
		_garage.connect(&"expand_clicked", show_expansion_plate)
	if _upgrades:
		_upgrades.upgrade_purchased.connect(_on_upgrade_purchased)
	_bays = get_tree().get_first_node_in_group("repair_bays") as RepairBayManager
	if _bays:
		_bays.bay_clicked.connect(show_bay_plate)
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
	_refresh_quest_button()
	# Garaj rütbesi türetilmiştir: değeri büyütebilen her olaydan sonra bakılır
	_ownership = get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	if _ownership:
		_ownership.ownership_changed.connect(_check_garage_rank)
		_ownership.paint_changed.connect(func(_id: StringName, _c: Color) -> void: _check_garage_rank())
	if _upgrades:
		_upgrades.levels_changed.connect(_check_garage_rank)
	if _bays:
		_bays.bays_changed.connect(_check_garage_rank)
	_check_garage_rank()
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
		_repair_panel.set_info(state.repair_type)
		if state.phase == RepairState.Phase.REPAIRING:
			_repair_panel.show_repairing(state.repair_progress, state.remaining)
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


func _on_collect_pressed() -> void:
	if _repair_manager and _repair_target:
		_repair_manager.collect(_repair_target)


## PARA TOPLA: para + XP verildi → kısa ödül plakası; hedef bu araçsa plaka "TAMAMLANDI"ya geçer.
func _on_repair_collected(car: Node3D, reward: int, xp: int) -> void:
	_show_notice("+%s ₺   +%d XP" % [format_thousands(reward), xp], HudPalette.COIN_DARK)
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


## Dünyadaki kilitli tamir alanına tıklanınca açılan fiziksel satın alma plakası:
## "TAMİR ALANI 2 / 8.000 ₺ / [ALANI AÇ] [VAZGEÇ]". Yeni UI dili yok, mevcut plakalar.
func _build_bay_plate() -> void:
	_bay_plate = PlatePanel.new()
	_bay_plate.name = "BayPlate"
	_bay_plate.theme_type_variation = &"HudCarPlate"
	_bay_plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bay_plate.visible = false
	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: StringName in [&"margin_left", &"margin_right"]:
		margin.add_theme_constant_override(side, 16)
	for side: StringName in [&"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 8)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 4)
	_bay_title = Label.new()
	_bay_title.theme_type_variation = &"HudPlateTitle"
	_bay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bay_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bay_price = Label.new()
	_bay_price.theme_type_variation = &"HudInkValue"
	_bay_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bay_price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", 8)
	_bay_buy = PlateButton.new()
	_bay_buy.theme_type_variation = &"HudPlateSmall"
	_bay_buy.text = "ALANI AÇ"
	_bay_buy.bolts = false
	_bay_buy.focus_mode = Control.FOCUS_NONE
	_bay_buy.pressed.connect(_on_bay_buy_pressed)
	var cancel: PlateButton = PlateButton.new()
	cancel.theme_type_variation = &"HudPlateSmall"
	cancel.text = "VAZGEÇ"
	cancel.bolts = false
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.pressed.connect(hide_bay_plate)
	buttons.add_child(_bay_buy)
	buttons.add_child(cancel)
	box.add_child(_bay_title)
	box.add_child(_bay_price)
	box.add_child(buttons)
	margin.add_child(box)
	_bay_plate.add_child(margin)
	var column: Node = car_info_panel.get_parent()
	column.add_child(_bay_plate)
	column.move_child(_bay_plate, car_info_panel.get_index())


## Kilitli alana tıklandı: plaka alanın durumuna göre açılır.
func show_bay_plate(index: int) -> void:
	if _bays == null:
		return
	_bay_index = index
	_plate_mode = &"bay"
	_bay_buy.text = "ALANI AÇ"
	hide_car_info()
	_bay_title.text = "TAMİR ALANI %d" % (index + 1)
	var price: String = format_thousands(_bays.price(index))
	match _bays.status(index):
		RepairBayManager.Status.NEEDS_LEVEL:
			_bay_price.text = "TAMİR ALANI Sv.%d GEREKLİ" % _bays.required_level(index)
			_bay_buy.disabled = true
		RepairBayManager.Status.TOO_EXPENSIVE:
			_bay_price.text = "%s ₺  ·  PARA YETERSİZ" % price
			_bay_buy.disabled = true
		RepairBayManager.Status.OPEN:
			_bay_price.text = "AÇIK"
			_bay_buy.disabled = true
		_:
			_bay_price.text = "%s ₺" % price
			_bay_buy.disabled = false
	_bay_plate.show()


## Dünyadaki "GARAJI GENİŞLET" tabelasına tıklandı: garajın fiziksel seviyesini satın alma plakası.
## Bu, tamir alanı satın almadan AYRI bir işlemdir (garaj büyür, alan yine ayrıca açılır).
func show_expansion_plate() -> void:
	if _upgrades == null:
		return
	_plate_mode = &"garage"
	_bay_index = -1
	hide_car_info()
	var id: StringName = GarageUpgradeManager.GARAGE_ID
	_bay_title.text = "GARAJI GENİŞLET"
	if _upgrades.is_max(id):
		_bay_price.text = "MAKSİMUM"
		_bay_buy.disabled = true
	else:
		var cost: int = _upgrades.next_cost(id)
		var affordable: bool = _economy == null or _economy.can_afford(cost)
		_bay_price.text = "SEVİYE %d  ·  %s ₺%s" % [
			_upgrades.level(id) + 1, format_thousands(cost), "" if affordable else "  ·  PARA YETERSİZ"]
		_bay_buy.disabled = not affordable
	_bay_buy.text = "GENİŞLET"
	_bay_plate.show()


func hide_bay_plate() -> void:
	_bay_index = -1
	_plate_mode = &"bay"
	_bay_buy.text = "ALANI AÇ"
	_bay_plate.hide()


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
	_show_notice("GARAJ SEVİYE %d" % level, HudPalette.COIN_DARK)


func _on_bay_unlocked(index: int) -> void:
	hide_bay_plate()
	_show_notice("TAMİR ALANI %d AÇILDI" % (index + 1), HudPalette.COIN_DARK)


func _on_bay_purchase_failed(index: int, price: int) -> void:
	_show_notice("%s ₺ GEREKLİ" % format_thousands(price), HudPalette.INK)
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
func _on_level_reward(new_level: int, money: int, text: String) -> void:
	var line: String = "SEVİYE %d   +%s ₺" % [new_level, format_thousands(money)]
	if text != "":
		line += "\n%s" % text
	_show_notice(line, HudPalette.COIN_DARK, 2.2)


## İş ustalığı kademesi atlandı: hangi iş, kaçıncı yıldız, tek seferlik ödül.
func _on_mastery_up(job_id: StringName, stars: int) -> void:
	var title: String = job_id
	if _repair_manager:
		for type: RepairType in _repair_manager.repair_types:
			if type.id == job_id:
				title = type.title
				break
	var reward: int = JobMastery.STAR_REWARDS[clampi(stars - 1, 0, JobMastery.STAR_REWARDS.size() - 1)]
	_show_notice("%s USTALIK %d★\n+%s ₺" % [title, stars, format_thousands(reward)],
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
	_show_notice("GARAJ RÜTBESİ %d\n%s" % [rank, GarageValue.rank_name(rank)],
			HudPalette.COIN_DARK, 2.2)


## Showroom'dan araç satın alındı: kısa bildirim plakası (para düşüşünü zaten coin plakası gösterir).
func _on_vehicle_purchased(vehicle_id: StringName) -> void:
	var entry: Dictionary = CarCatalog.get_entry(vehicle_id)
	_show_notice("%s GARAJINDA" % String(entry.get("display_name", vehicle_id)).to_upper(), HudPalette.COIN_DARK)


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
		_repair_panel.show_repairing(progress, state.remaining if state else 0.0)


## Araç alandan çıktı: seçili başka bir arızalı aracın plakası TAMİR'i açar.
func _on_repair_slot_freed(_car: Node3D) -> void:
	_refresh_repair_panel(false)


func _on_repair_cancelled(_car: Node3D) -> void:
	_refresh_repair_panel(false)


# --- Buton olayları ----------------------------------------------------------

func _on_nav_toggled(pressed: bool, button: PlateButton) -> void:
	if pressed:
		nav_selected.emit(_nav_ids[button])
	# Başka sekmeye geçilince araç galerisi kapanır
	if button == cars_button and not pressed:
		car_gallery.close()   # ARAÇLAR pasif: mağaza showroom'a taşındı, burada yalnızca sekme kalır


## ARABA GALERİSİ: bina hitbox'ı açtığında oyun HUD'u gizlenir, GERİ ile aynen geri gelir.
func _build_showroom() -> void:
	showroom = ShowroomScreen.new()
	garage_screen.get_parent().add_child(showroom)   # temalı Root'un altına, en üste
	showroom.opened.connect(_on_showroom_opened)
	showroom.closed.connect(_on_showroom_closed)
	showroom.vehicle_purchased.connect(_on_vehicle_purchased)


## PLAYER tabelası temalı Root'un en üstünde durur (showroom'un da üstünde: kayıt seçimi her yerde görünür).
func _build_login_screen() -> void:
	login_screen = LoginScreen.new()
	garage_screen.get_parent().add_child(login_screen)


func _on_profile_button_pressed() -> void:
	login_screen.open()


## GÖREVLER plakası sağ üst tabela sırasının hemen altına (kamera kontrollerinin üstüne) eklenir.
func _build_quests() -> void:
	quest_button = PlateButton.new()
	quest_button.name = "QuestButton"
	quest_button.theme_type_variation = &"HudPlateSmall"
	quest_button.text = "GÖREVLER"
	quest_button.focus_mode = Control.FOCUS_NONE
	quest_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	quest_button.pressed.connect(_on_quest_button_pressed)
	var column: Node = camera_controls.get_parent()
	column.add_child(quest_button)
	column.move_child(quest_button, camera_controls.get_index())
	quest_screen = QuestScreen.new()
	garage_screen.get_parent().add_child(quest_screen)
	quest_screen.reward_claimed.connect(func(text: String) -> void: _show_notice(text, HudPalette.COIN_DARK))
	quest_screen.closed.connect(_refresh_quest_button)


func _on_quest_button_pressed() -> void:
	quest_screen.open()
	_refresh_quest_button()


## Alınabilir ödül varsa plaka amber olur ve sayıyı gösterir; hepsi bittiyse plaka gizlenir.
func _refresh_quest_button() -> void:
	if quest_button == null:
		return
	quest_button.visible = _quests != null and not _quests.all_done()
	var count: int = _quests.claimable_count() if _quests else 0
	quest_button.text = "GÖREVLER (%d)" % count if count > 0 else "GÖREVLER"
	quest_button.highlight = count > 0


func _on_quest_completed(quest_id: StringName) -> void:
	var entry: Dictionary = QuestCatalog.get_entry(quest_id)
	_show_notice("GÖREV TAMAMLANDI: %s" % String(entry.get("title", "")), HudPalette.COIN_DARK, 2.2)


func _on_showroom_opened() -> void:
	car_gallery.close()
	if garage_screen.visible:
		garage_screen.close()
	_set_gameplay_hud_visible(false)


func _on_showroom_closed() -> void:
	_set_gameplay_hud_visible(true)


## GARAJ plakası: tam ekran Garaj görünümünü açar; açıkken oyun HUD'unun tamamı gizlenir,
## GARAJDAN ÇIK ile aynen geri gelir.
func _on_garage_button_pressed() -> void:
	if garage_screen.visible:
		garage_screen.close()
		return
	car_gallery.close()
	_set_gameplay_hud_visible(false)
	garage_screen.open()


func _on_garage_closed() -> void:
	_set_gameplay_hud_visible(true)


func _set_gameplay_hud_visible(shown: bool) -> void:
	top_left.visible = shown
	top_right.visible = shown
	bottom.visible = shown


func _on_name_plate_pressed() -> void:
	select_nav_tab(&"profile")
	login_screen.open()


func _on_camera_toggled(pressed: bool) -> void:
	camera_controls.visible = pressed


func _on_sound_toggled(muted: bool) -> void:
	sound_button.kind = HudIcon.Kind.SPEAKER_OFF if muted else HudIcon.Kind.SPEAKER
	sound_toggled.emit(not muted)


func _on_settings_pressed() -> void:
	settings_pressed.emit()


func _on_zoom_in_pressed() -> void:
	camera_zoom_requested.emit(1)


func _on_zoom_out_pressed() -> void:
	camera_zoom_requested.emit(-1)


func _on_rotate_pressed() -> void:
	camera_rotate_requested.emit()
