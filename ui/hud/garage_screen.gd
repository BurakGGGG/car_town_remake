class_name GarageScreen
extends Control
## Tam ekran GARAJ görünümü — "yol mobilyası / plaka" dili.
## Kendi 3D garaj dünyası (SubViewport, tam ekran): asfalt zemin, güvenlik şeritleri, iki duvar,
## lift platformu ve ortada seçili aracın gerçek modeli. Üstünde plakalar: tabela, sol bilgi plakaları,
## sağ aksiyon plakaları, alt park yeri listesi, sol alt çıkış.
## Bu ekran ARAÇLAR sekmesidir: yalnızca araçlar. Garaj seviyesi / tamir hızı / düzenleme / detay /
## ustalık ana görünümün alt panelindedir (GaragePanel).
## Alt listede (CarGallery, OWNED kipi) YALNIZCA oyuncunun SAHİP OLDUĞU araçlar durur
## (VehicleOwnership); satın alınmamış araçlar burada da dünyada da görünmez. Gösterilecek araç
## artık dünyadaki park etmiş bir node değil, bir araç id'sidir: listeden gelen vehicle_selected
## sinyali önizlemeyi sürer. Root STOP: açıkken dünyaya tıklama ulaşmaz.
## Araç bilgisi (ad, yıl, durum, fiyat, sahne) CarCatalog'dan gelir.
##
## BOYA: sağ sütundaki BOYA plakası aksiyon plakalarının yerine BOYA ATÖLYESİ'ni (PaintPanel) açar.
## Renk önizlemesi yalnızca lifteki araca, paylaşılan görünümün bir KOPYASIYLA uygulanır; satın alma
## VehicleOwnership.purchase_paint'tedir ve paylaşılan görünümü değiştirir (lift, park etmiş araçlar ve
## thumbnail'ler kendiliğinden güncellenir).
##
## KOLEKSİYON: garaj açıldığında oyuncunun SAHİP OLDUĞU araçlar (VehicleOwnership) garajın zeminine
## fiziksel olarak park edilir; seçili araç lifte çıkar, park yeri boş kalır (aynı aracın iki modeli
## asla aynı anda yüklenmez). Park etmiş araca tıklamak onu lifte alır — seçim bu şekilde yapılır
## (CarHitbox ile aynı yöntem: StaticBody3D + input_ray_pickable + input_event; ama dünyadaki statik
## CarHitbox.selected_car'a dokunulmaz, yoksa RepairManager'ın hedefi bozulurdu).
## SATIŞ: sağdaki SAT plakası aksiyon plakalarının yerine onay plakasını açar (satış geri alınamaz);
## para ve sahiplik VehicleOwnership.sell_vehicle'dedir, tek araç satılamaz.
##
## Modeller yalnızca garaj AÇIKKEN yaşar: kapanışta hepsi serbest bırakılır, kapalıyken hiçbir araç
## modeli bellekte durmaz. Satın alınmayan araç hiç yüklenmez; oyuncu araçları trafiğe de çıkmaz.

signal action_selected(action: StringName, car: StringName)
## Bir pano isteniyor (&"garage_value" / &"mastery"): ekranı UiRouter açar, garaj altta açık kalır.
signal screen_requested(id: StringName)
## MODİFİYE kipinde YÜKSELT: satın alma ve ana dünyadaki sinematik HUD'dadır.
signal mod_upgrade_requested(vehicle_id: StringName, category: StringName)
signal closed

const SLIDE: float = 16.0
## Alt araç şeridinin kadraj kenarına bıraktığı pay (sahnedeki margin_bottom ile aynı).
const BOTTOM_MARGIN: float = 14.0

## Sol sütunun altında GARAJDAN ÇIK plakasına bırakılan pay — plaka ölçülemezse YEDEK
## (normalde _exit_reserve() gerçek plakadan hesaplar).
const EXIT_RESERVE: float = 96.0
## Sol sütunun sonu ile GARAJDAN ÇIK plakası arasındaki boşluk.
const EXIT_GAP: float = 8.0
## Sol sütunun kadraj üstünden payı.
const COLUMN_TOP: float = 16.0
const INFO_WIDTH: float = 196.0
## Yan sütunlar ile alt şerit arasında bırakılan dikey boşluk.
const SIDE_GAP: float = 6.0

## Alt araç şeridi: çok araçta satır kadrajı aştığı için kaydırma kabına alınır.
## %BottomCenter sahnede bottom-center'a tutturulmuş ama büyüme yönü uygulanmadığından
## (offsets 0,-14,1312,108) satır sağa ve aşağı taşıyordu: 9 araçta şerit 1312 px, kadraj 1152.
## Burada anchor'lar bottom-wide'a alınır (satır kadraj genişliğinde, aşağıdan yukarı büyür) ve
## CarList yatay kaydırmalı bir kaba taşınır: az araçta ortalı, çok araçta parmakla kaydırılır.
func _fix_car_list_layout() -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "CarListScroll"
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	TouchScroll.attach(scroll)
	var index: int = car_list.get_index()
	bottom_group.remove_child(car_list)
	scroll.add_child(car_list)
	# Şeridin solunda TÜM ARAÇLAR plakası (filtre / sıralama panosu): ikisi bir satırda, modifiye kipinde birlikte gizlenir
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "StripRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 6)
	row.add_child(_build_all_cars_button())
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(scroll)
	bottom_group.add_child(row)
	bottom_group.move_child(row, index)
	car_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # az araçta kabı doldurur
	car_list.alignment = BoxContainer.ALIGNMENT_CENTER          # ... ve ortalanır
	# Şerit yüksekliği plakalar kurulduktan SONRA belli olur: her minimum boy değişiminde
	# (ve kadraj değişiminde) yeniden yerleştirilir, kare sonuna ertelenerek.
	bottom_group.minimum_size_changed.connect(_place_car_list, CONNECT_DEFERRED)
	car_list.minimum_size_changed.connect(_place_car_list, CONNECT_DEFERRED)
	(bottom_group.get_parent() as Control).resized.connect(_place_car_list, CONNECT_DEFERRED)
	exit_group.resized.connect(_place_car_list, CONNECT_DEFERRED)
	# Sol sütunun genişliği kaydırma çubuğu göründükçe 8 px oynuyor: şerit onu takip etmeli.
	left_group.resized.connect(_place_car_list, CONNECT_DEFERRED)
	exit_group.minimum_size_changed.connect(_place_car_list, CONNECT_DEFERRED)
	# Sağ sütun (aksiyonlar / DETAY / SAT / BOYA panoları) boy değiştirince şeride binmesin diye yeniden yerleşir.
	right_group.minimum_size_changed.connect(_place_car_list, CONNECT_DEFERRED)
	_place_car_list.call_deferred()


## Şeridi kadrajın altına oturtur: tam genişlik, yüksekliği kendi minimumu kadar.
## Anchor + büyüme yönüne bırakılamıyor — offset'ler bir kez aşağı doğru büyüyünce
## (offset_bottom = +116) motor bir daha küçültmüyor ve şerit kadrajın altında kalıyordu.
## Bu yüzden rect doğrudan yazılır; kadraj değişince (resized) yeniden hesaplanır.
func _place_car_list() -> void:
	var area: Vector2 = bottom_group.get_parent_area_size()
	if area.y <= 0.0:
		return
	var height: float = maxf(bottom_group.get_combined_minimum_size().y,
		car_list.get_combined_minimum_size().y + BOTTOM_MARGIN)
	bottom_group.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	# Solda bilgi sütunu ve GARAJDAN ÇIK plakası duruyor: şerit ikisinin de sağından başlar.
	# Böylece sütun kadrajın altına kadar inebilir (değer plakası kırpılmaz) ve şerit hiçbir
	# şeyin üstüne binmez; sığmayan araçlar zaten yatay kaydırma ile geliyor.
	var strip_top: float = area.y - height
	var left_inset: float = 0.0
	for group: Control in [exit_group, left_group]:
		if group == left_group and is_modding() and COLUMN_TOP + _workshop.left_panel() \
				.get_combined_minimum_size().y <= strip_top - SIDE_GAP:
			continue   # modifiye: değer plakası rafın üstünde bitiyor, raf sola kadar uzayabilir
		if group and group.is_visible_in_tree():
			left_inset = maxf(left_inset, maxf(group.size.x, group.get_combined_minimum_size().x))
	if left_inset > 0.0:
		left_inset += 8.0
	# Sağ sütun şeridin üstüne sığmıyorsa (telefon tuvali, 480 birim) şerit onun SOLUNDA biter.
	var right_inset: float = _place_right_column(area, strip_top)
	bottom_group.offset_left = left_inset
	bottom_group.offset_top = strip_top
	bottom_group.offset_right = area.x - right_inset
	bottom_group.offset_bottom = area.y
	# Modifiye rafları içerikleri kadar geniştir; dar tuvalde (853 birim) kalan yere sığar, kartlar kaydırılır.
	if _workshop:
		_workshop.fit_trays(area.x - left_inset - right_inset - (16.0 if right_inset <= 0.0 else 8.0))
	# Kaydırma kabı kendi minimum genişliği yüzünden 8 px taşabiliyor: kırpılır, böylece
	# hiçbir plaka kadrajın dışına çizilmez.
	bottom_group.clip_contents = true
	# Açılış animasyonu hedef konumu bir kez yakalıyor; şerit sonradan yer değiştirirse
	# tween eski hedefe geri çekmesin diye hedef de tazelenir.
	if _group_targets.has(bottom_group):
		_group_targets[bottom_group] = bottom_group.position
	_apply_responsive_layout()   # sol sütun şeridin üstünde bitsin


## Sağ sütun dikey ORTADA durur (masaüstü, tablet); altı araç şeridine biniyorsa yukarı kayar, yine
## sığmıyorsa üste yaslanır ve şerit onun SOLUNDA biter (telefon tuvali: 6 aksiyon plakası 364 birim,
## şeritle birlikte 480'e sığmıyor — KOLEKSİYON plakası şeridin arkasında kalıyordu). Dönen değer şeridin
## sağdan bırakması gereken pay. Modifiye kipinde sütun _fit_mod_column'da üste sabit; burada yalnızca pay
## hesaplanır. Rect doğrudan yazılır (bkz. _place_car_list: anchor + büyüme yönü geri ortalamıyor).
func _place_right_column(area: Vector2, strip_top: float) -> float:
	if not right_group.visible:
		return 0.0
	var size: Vector2 = right_group.get_combined_minimum_size()
	var top: float = COLUMN_TOP
	if not is_modding():
		top = (area.y - size.y) * 0.5
		var lowest: float = strip_top - SIDE_GAP - size.y   # şeridin üstünde biten en alçak yer
		if top > lowest:
			top = maxf(lowest, COLUMN_TOP)
		right_group.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
		right_group.offset_left = area.x - size.x
		right_group.offset_top = top
		right_group.offset_right = area.x
		right_group.offset_bottom = top + size.y
		if _group_targets.has(right_group):
			_group_targets[right_group] = right_group.position
	if top + size.y > strip_top - SIDE_GAP * 0.5:
		return size.x + 8.0
	return 0.0


## Garaj zemininde SADECE liftteki araç durur. Sahip olunan diğer araçların zemine park
## edilmesi (kullanıcı kararı, 2026-09-27) kalabalık ve dağınık görünüyordu; araç değiştirme
## zaten alt şeritteki plakalardan yapılıyor. Park kodu duruyor, yalnızca kapalı.
const SHOW_PARKED_CARS: bool = false

## Park yerleri (garaj zemini, y=0). Park eden k. araç → PARK_SLOTS[k]; yerler içeriden dışarıya
## sıralıdır, böylece az araçta hepsi kadrajın ortasında toplanır. Konumlar izometrik kameranın
## gördüğü boş alana göre seçildi (duvarlar x=-1.3 / z=-1.3'te, dolap ve lastikler köşelerde);
## araçlar birbirine, lifte ve plakaların arkasına düşmeyecek şekilde yerleştirildi.
const PARK_SLOTS: Array[Vector3] = [
	Vector3(1.03, 0.0, 0.67),
	Vector3(1.75, 0.0, 0.10),
	Vector3(2.25, 0.0, 1.25),
	Vector3(1.20, 0.0, 1.84),
	Vector3(2.70, 0.0, 0.20),
	Vector3(0.11, 0.0, 1.59),
	Vector3(-1.00, 0.0, 0.60),
]
## Araç sayısı arttıkça kamera koleksiyonun ortasına kayar (sol/alt plakaların arkasında kalmasın).
const CAM_SHIFT: Vector3 = Vector3(0.78, 0.0, 0.78)
## Kamera araç sayısına göre açılır (hepsi kadraja sığsın; izometrik/ortografik stil korunur).
const CAM_SIZE_MIN: float = 2.0
const CAM_SIZE_MAX: float = 3.3
## Kamera 5. araçta tam genişliğe, kaydırma 3. araçta tam değerine ulaşır.
const CAM_FULL_AT: float = 4.0
const CAM_SHIFT_AT: float = 2.0

## Turntable hızı (derece/sn). 0 = sabit.
@export_range(0.0, 90.0, 1.0) var turntable_speed: float = 10.0

@onready var view: SubViewportContainer = %View
@onready var car_viewport: SubViewport = %CarViewport
@onready var preview_camera: Camera3D = %PreviewCamera
@onready var car_slot: Node3D = %CarSlot
@onready var overlay: Control = %Overlay
@onready var top_group: Control = %TopCenter
@onready var left_group: Control = %LeftCenter
@onready var right_group: Control = %RightCenter
@onready var bottom_group: Control = %BottomCenter
@onready var exit_group: Control = %BottomLeft
@onready var car_name_label: Label = %CarNameLabel
@onready var year_label: Label = %YearLabel
@onready var info_column: VBoxContainer = %InfoColumn
@onready var condition_gauge: XpLane = %ConditionGauge
@onready var condition_label: Label = %ConditionLabel
@onready var value_label: Label = %ValueLabel
@onready var detail_button: PlateButton = %DetailButton
@onready var repair_button: PlateButton = %RepairButton
@onready var sell_button: PlateButton = %SellButton
@onready var car_list: CarGallery = %CarList
@onready var exit_button: PlateButton = %ExitButton
@onready var action_column: VBoxContainer = %ActionColumn

## Kısa ekran kipi (telefon tuvali): ayrıntı satırları gizli.
var _compact: bool = false
var _info_scroll: ScrollContainer

var _actions: ButtonGroup = ButtonGroup.new()
## Gösterilen araç: CarCatalog id'si (dünya node adı değil).
var _shown_vehicle: StringName = &""
var _ownership: VehicleOwnership
var _preview: Node3D
var _preview_rig: CarRig  # önizleme aracına görünüm uygular / tekerlerini döndürür
## Garaj zeminindeki park etmiş araçlar: araç id → model kökü (lifteki araç burada YOKTUR).
var _parked: Dictionary = {}
var _collection: Node3D
var _listed: Array[StringName] = []   # koleksiyonun son kurulduğu sahiplik sırası
var _camera_home: Vector3             # kameranın tek araçlıkken durduğu yer
var _closing: bool = false
var _tweens: Array[Tween] = []
var _info_tween: Tween
var _group_targets: Dictionary = {}  # anchor'lı grup → hedef position (animasyon yarıda kesilirse geri koymak için)
var _paint_button: PlateButton
var _paint_panel: PaintPanel
## Satış onay plakası (sağ sütun, aksiyon plakalarının yerine açılır).
var _sell_panel: PlatePanel
var _sell_name: Label
var _sell_payout: Label
var _sell_confirm: PlateButton
var _detail_panel: PlatePanel
var _detail_name: Label
var _detail_overall: Label
var _detail_specs: Label   # gerçek fabrika verisi (performance bloğu): motor · çekiş / 0-100 · son hız
## Genel puanı oluşturan dört stat: [statü anahtarı, etiket].
const DETAIL_ROWS: Array = [
	["top_speed", "HIZ"], ["acceleration", "HIZLANMA"], ["reaction", "TEPKİ"], ["grip", "TUTUŞ"]]
var _detail_lanes: Dictionary = {}
## ARAÇLAR → MODİFİYE kipi (alt parça şeridi, sağda parça plakası, solda değerler).
var _workshop: ModWorkshop
## Sağ sütunun sahnedeki yerleşimi (modifiye kipinde üste sabitlenir, çıkınca geri konur).
var _right_layout: Dictionary = {}
var _detail_values: Dictionary = {}


func _ready() -> void:
	visible = false
	_actions.allow_unpress = true
	var actions: Dictionary = {detail_button: &"detail", repair_button: &"repair", sell_button: &"sell"}
	for button: PlateButton in actions:
		button.button_group = _actions
		button.toggled.connect(_on_action_toggled.bind(actions[button]))
	exit_button.pressed.connect(_on_exit_pressed)
	# Bu ekran ARAÇLAR sekmesidir; garajın kendisi (seviye, düzenleme, detay) ana görünümün alt
	# panelindedir (GaragePanel). Sahne dosyasındaki "GARAJ" yazıları burada değiştirilir.
	exit_button.text = Loc.t("GERİ")
	var title: Label = find_child("TitleLabel", true, false) as Label
	if title:
		title.text = Loc.t("ARAÇLAR")
	_set_wall_sign(Loc.t("ARAÇLAR"))
	car_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_release_render_target()   # garaj hiç açılmasa da tam ekran hedef ayrılıyordu
	car_viewport.physics_object_picking = true      # park etmiş araçlara tıklanabilsin
	view.mouse_filter = Control.MOUSE_FILTER_STOP   # tıklama SubViewport'a iletilsin (plakalar üstte)
	_collection = Node3D.new()
	_collection.name = "Collection"
	car_viewport.add_child(_collection)
	_camera_home = preview_camera.position
	set_process(false)
	car_list.mode = CarGallery.Mode.OWNED   # garaj listesi: yalnızca sahip olunan araçlar
	car_list.vehicle_selected.connect(_on_vehicle_selected)
	_fix_car_list_layout()
	# Sol sütun artık "ne alıyorum" satırlarını da taşıyor: aralık biraz daraltıldı, böylece
	# sütunun altı GARAJDAN ÇIK plakasına değmiyor (ölçüm: 611 → 597 px, buton üstü 607).
	info_column.add_theme_constant_override(&"separation", 4)
	_build_paint()
	_build_race_pick()
	_build_performance_button()
	_build_collection_button()
	_build_move()
	_build_waiting_note()
	_build_sell()
	_build_empty_panel()
	_build_garage_selector()
	car_list.source = _list_source
	_interior_view = GarageInteriorView.new()
	_interior_view.name = "InteriorView"
	add_child(_interior_view)
	_interior_view.car_tapped.connect(_on_interior_car_tapped)
	view.gui_input.connect(_on_view_gui_input)
	_build_detail()
	_wrap_info_column()
	_workshop = ModWorkshop.new()
	add_child(_workshop)
	_workshop.build(bottom_group, left_group, right_group)
	_workshop.upgrade_requested.connect(func(id: StringName, category: StringName) -> void:
		mod_upgrade_requested.emit(id, category))
	_workshop.gem_store_requested.connect(func() -> void: screen_requested.emit(&"gem_store"))
	_workshop.title_changed.connect(_set_title)
	_workshop.layout_changed.connect(func() -> void:
		_fit_mod_column.call_deferred()
		_place_car_list.call_deferred())
	_apply_responsive_layout()
	get_viewport().size_changed.connect(_apply_responsive_layout)


func _process(delta: float) -> void:
	if turntable_speed > 0.0 and not _closing:
		car_slot.rotate_y(deg_to_rad(turntable_speed) * delta)


# --- Ekrana uyum (telefon tuvali ~1040×480) ----------------------------------

## Sol sütun kaydırılabilir bir kapsayıcıya alınır: telefon tuvalinde (yükseklik 480) içerik
## GARAJDAN ÇIK plakasının altına taşıyordu. Masaüstünde (648) hiçbir şey değişmez: içerik sığar,
## kaydırma çubuğu görünmez.
func _wrap_info_column() -> void:
	var host: Control = left_group
	_info_scroll = ScrollContainer.new()
	_info_scroll.name = "InfoScroll"
	_info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_info_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_info_scroll.follow_focus = false
	_info_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	TouchScroll.attach(_info_scroll)
	host.remove_child(info_column)
	_info_scroll.add_child(info_column)
	host.add_child(_info_scroll)


## Sol sütunun yoğunluğu İÇERİĞE göre seçilir: GARAJDAN ÇIK'ın üstünde biten İLK kademe.
##   0 — tam
##   1 — "ne alıyorum" özetleri ve alan ipucu gizli, aralık sık (bölüm başlıkları durur)
##   2 — bölüm başlıkları da gizli
## Hiçbiri sığmazsa sütun kaydırılır (son çare). Gizlenen ayrıntılar dünyadaki satın alma
## plakasında tam hâliyle yazıyor.
##
## Eskiden kademe ekran yüksekliğine göre seçiliyordu (< 560), ama canvas_items + expand dikey
## tabanı her cihazda 648'de tuttuğu için hiç tetiklenmiyordu. Dokunma tabanıyla
## (PlateButton.MIN_PLATE_HEIGHT) düğmeler 25 → 44 birime çıkınca sütun 648'lik tuvalde 47 birim
## taştı ve GARAJ DEĞERİ kaydırmanın altına düştü (ölçüldü).
func _apply_responsive_layout() -> void:
	if _info_scroll == null:
		return
	var view_height: float = get_viewport_rect().size.y
	var available: float = maxf(view_height - COLUMN_TOP - _exit_reserve(), 120.0)
	var wanted: float = 0.0
	for level: int in 3:
		_set_density(level)
		wanted = info_column.get_combined_minimum_size().y
		if wanted <= available:
			break
	_info_scroll.custom_minimum_size = Vector2(INFO_WIDTH, minf(wanted, available))
	_place_left_column()


func _set_density(level: int) -> void:
	_compact = level >= 1
	info_column.add_theme_constant_override(&"separation", 2 if _compact else 4)


## GARAJDAN ÇIK plakasının kadrajdaki yüksekliği (kenar payı dahil) + araya bırakılan boşluk.
## Eskiden 96 birimlik sabitti, 25 birimlik düğmeye göre elle verilmişti.
func _exit_reserve() -> float:
	var host: Control = exit_button.get_parent() as Control if exit_button else null
	if host == null:
		return EXIT_RESERVE
	return host.get_combined_minimum_size().y + EXIT_GAP


## Sol sütunu üstten hizalar. Sahnede dikey ORTALI (%LeftCenter, anchor 0.5) olduğu için sütun
## uzadıkça altı araç şeridinin üstüne biniyordu; üstten hizalanınca aynı yerde başlar ama
## şeridin üstünde biter.
func _place_left_column() -> void:
	if is_modding():
		_fit_mod_column()
		return
	var height: float = _info_scroll.custom_minimum_size.y
	if height <= 0.0:
		return
	left_group.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	left_group.offset_left = 0.0
	left_group.offset_top = COLUMN_TOP
	left_group.offset_right = left_group.get_combined_minimum_size().x
	left_group.offset_bottom = COLUMN_TOP + height
	if _group_targets.has(left_group):
		_group_targets[left_group] = left_group.position


# --- Aç / kapa ---------------------------------------------------------------

func open() -> void:
	if visible:
		return
	_closing = false
	show()
	# Kalite / GPU'ya göre: MSAA (sahnede 2×) ve anahtar ışığın gölgesi (DÜŞÜK'te kapalı)
	car_viewport.msaa_3d = GameSettings.subviewport_msaa(Viewport.MSAA_2X)
	var key_light: DirectionalLight3D = car_viewport.get_node_or_null("KeyLight") as DirectionalLight3D
	if key_light:
		key_light.shadow_enabled = GameSettings.shadows_enabled()
	_claim_render_target()
	car_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_pick_garage_on_open()
	car_list.open()   # listeyi güncel sahiplikle kurar (yeni alınan araç burada belirir)
	_apply_garage_look()   # iç mekân + araçlar ÖNCE: gösterim lifte model yüklemek yerine park etmiş araca odaklanır
	# Gösterilecek araç: listede seçili olan, yoksa içinde bulunulan garajın ilk aracı (garaj boşsa boş garaj)
	var target: StringName = car_list.selected_vehicle()
	var here: Array[StringName] = _list_source()
	if target == &"" or not here.has(target):
		target = here[0] if not here.is_empty() else (&"" if _garage != &"" else _first_owned())
	_shown_vehicle = &""
	if target == &"":
		_show_empty()
	else:
		_show_vehicle(target, false)
	_refresh_title()
	_refresh_collection()
	_actions_clear()
	set_process(true)
	_enter_animation()


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	set_process(false)
	_kill_tweens()
	# Kısa çıkış: ortam ve plakalar söner, araç hafif küçülür
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_property(car_slot, "scale", Vector3.ONE * 0.9, 0.15)
	_tweens.append(tween)
	tween.finished.connect(_finish_close)


## İLK AÇILIŞ TAKILMASINI ÖNLER (drag / showroom'daki gibi): garaj sahnesi görünmeden bir kez küçük boyutta
## çizilir, shader'lar oyun yüklenirken derlenir. Ölçüldü (qa/open_repeat.gd): ilk açılış 45,7 ms, sonrakiler 23-30.
func prewarm() -> void:
	if visible:
		return
	view.stretch = false
	car_viewport.size = Vector2i(64, 36)
	car_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## ÇİZİM HEDEFİ kapalıyken VRAM'de tutulmaz (bkz. DragRaceScreen._release_render_target): `stretch` açıkken
## görüntü alanına boyut atanamadığı için kapanışta kapatılır, açılışta boyut kapsayıcıdan alınıp geri açılır.
func _release_render_target() -> void:
	view.stretch = false
	car_viewport.size = Vector2i(4, 4)


func _claim_render_target() -> void:
	if not view.stretch:
		car_viewport.size = Vector2i(view.size.max(Vector2.ONE))
		view.stretch = true


func _finish_close() -> void:
	_close_mods()
	_interior_view.exit()   # iç mekân ve park etmiş araçlar bellekte kalmasın
	_sell_panel.hide()
	_detail_panel.hide()
	_move_panel.hide()
	action_column.show()
	_paint_panel.close()   # önizleme bırakılır; yeniden açılışta aksiyon plakaları görünür
	car_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_release_render_target()
	car_list.close()
	_clear_collection()
	_clear_preview()   # garaj kapalıyken araç modeli bellekte durmasın (açılışta yeniden yüklenir)
	hide()
	modulate.a = 1.0
	car_slot.scale = Vector3.ONE
	_closing = false
	closed.emit()


## Giriş: ortam fade-in, plakalar kenarlardan yerine oturur, araç scale-up (0.2–0.3 s).
func _enter_animation() -> void:
	_kill_tweens()
	view.modulate.a = 0.0
	var env_tween: Tween = create_tween()
	env_tween.tween_property(view, "modulate:a", 1.0, 0.25)
	_tweens.append(env_tween)

	car_slot.scale = Vector3.ONE * 0.85
	var car_tween: Tween = create_tween()
	car_tween.tween_property(car_slot, "scale", Vector3.ONE, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.05)
	_tweens.append(car_tween)

	await get_tree().process_frame  # anchor'lı grupların konumları hesaplansın
	if not visible or _closing:
		return
	_place_car_list()   # hedefler yakalanmadan ÖNCE şerit ve sol sütun doğru yere otursun
	var groups: Array = [
		[top_group, Vector2(0.0, -SLIDE)],
		[left_group, Vector2(-SLIDE, 0.0)],
		[right_group, Vector2(SLIDE, 0.0)],
		[bottom_group, Vector2(0.0, SLIDE)],
		[exit_group, Vector2(0.0, SLIDE)],
	]
	_group_targets.clear()
	for i: int in groups.size():
		var group: Control = groups[i][0]
		var target: Vector2 = group.position
		_group_targets[group] = target
		group.position = target + groups[i][1]
		group.modulate.a = 0.0
		var tween: Tween = create_tween().set_parallel(true)
		tween.tween_property(group, "position", target, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(i * 0.03)
		tween.tween_property(group, "modulate:a", 1.0, 0.14).set_delay(i * 0.03)
		# Oturan grubun hedefi unutulur: _kill_tweens yalnızca YARIDA kalanı geri koyar. Eskiden hedef
		# kapanışa kadar tutuluyordu; arada DETAY / SAT panosu sütunun boyunu değiştirince kapanış sütunu
		# eski konuma yazıyor, bir sonraki açılışta sağ sütun 49 birim ekran dışında kalıyordu.
		tween.finished.connect(func() -> void: _group_targets.erase(group))
		_tweens.append(tween)


func _kill_tweens() -> void:
	for tween: Tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()
	view.modulate.a = 1.0
	for group: Control in [top_group, left_group, right_group, bottom_group, exit_group]:
		group.modulate.a = 1.0
		if _group_targets.has(group):
			group.position = _group_targets[group]
	_group_targets.clear()


# --- Araç bilgisi ------------------------------------------------------------

## ARAÇLAR sekmesinden gelindi: alt listedeki araç plakaları kısa bir amber vuruşla öne çıkar
## (ayrı bir "araçlarım" ekranı açmıyoruz — araçlar zaten fiziksel olarak burada park ediyor).
func focus_cars() -> void:
	if car_list == null:
		return
	var tween: Tween = create_tween()
	tween.tween_property(car_list, "modulate", HudPalette.PLATE_SELECTED, 0.18)
	tween.tween_property(car_list, "modulate", Color.WHITE, 0.35)
	_tweens.append(tween)


## Listeden araç seçildi.
func _on_vehicle_selected(vehicle_id: StringName) -> void:
	if visible and not _closing:
		_show_vehicle(vehicle_id, true)


## Verilen aracı (CarCatalog id) bilgi plakalarına ve lift üstündeki önizlemeye koyar.
func _show_vehicle(vehicle_id: StringName, animated: bool) -> void:
	if vehicle_id == &"" or vehicle_id == _shown_vehicle:
		return
	var entry: Dictionary = CarCatalog.get_entry(vehicle_id)
	if entry.is_empty():
		push_warning("GarageScreen: katalogda '%s' yok" % vehicle_id)
		return
	_shown_vehicle = vehicle_id
	car_list.select(vehicle_id)
	_refresh_collection()   # lifte çıkan aracın park yeri boşalır, eskisi yerine döner
	if not animated:
		_apply(entry)
		return
	# Bilgi plakaları kısa sürede solar, yeni değerlerle geri gelir; ekran geçişi yok
	if _info_tween and _info_tween.is_valid():
		_info_tween.kill()
	_info_tween = create_tween()
	_info_tween.tween_property(info_column, "modulate:a", 0.0, 0.12)
	_info_tween.tween_callback(_apply.bind(entry))
	_info_tween.tween_property(info_column, "modulate:a", 1.0, 0.12)


func _apply(entry: Dictionary) -> void:
	_leave_empty()
	car_name_label.text = String(entry["display_name"]).to_upper()
	year_label.text = str(entry["year"])
	condition_gauge.ratio = entry["condition"]
	condition_label.text = "%d%%" % roundi(float(entry["condition"]) * 100.0)
	value_label.text = Hud.format_thousands(entry["price"])
	if not _focus_interior(_shown_vehicle):
		_load_preview(entry["scene_path"])
	_refresh_detail()
	_actions_clear()
	_refresh_race_pick()
	# Restorasyon araçları boyanamaz (VehicleOwnership.is_paintable): BOYA plakası gizlenir, açık pano kapanır
	var paintable: bool = VehicleOwnership.is_paintable(_shown_vehicle)
	_paint_button.visible = GameFeatures.PAINT and paintable
	if _paint_panel.visible:
		if paintable:
			_paint_panel.set_vehicle(_shown_vehicle)   # yeni aracın rengi seçili, önizleme yok
		else:
			_paint_panel.close()   # closed sinyali aksiyon plakalarını geri getirir
	_move_panel.hide()
	_refresh_garage_actions()


## Lift üstündeki modeli serbest bırakır (garaj kapanışı / araç değişimi).
func _clear_preview() -> void:
	if _preview:
		_preview.queue_free()
		_preview = null
	_preview_rig = null
	_shown_vehicle = &""   # yeniden açılışta model tekrar yüklensin


## Seçili aracın mevcut .tscn modelini lift üstüne koyar (asset değişmez, sadece instance).
func _load_preview(scene_path: String) -> void:
	if _preview:
		_preview.queue_free()
		_preview = null
	var scene: PackedScene = load(scene_path)
	if scene == null:
		return
	_preview = scene.instantiate() as Node3D
	# .tscn köküne gömülü ölçek yok sayılır; yerine aracın GERÇEK boyutundan türeyen ölçek
	# uygulanır (Getz modeli 0,6 birim olduğu için eskiden lift üstünde de küçücük duruyordu).
	_preview.scale = Vector3.ONE * CarCatalog.model_scale_for_scene(scene_path)
	car_slot.add_child(_preview)
	# Aynı görünüm verisi: dünya aracı, bu önizleme ve thumbnail hepsi CarAppearance.get_for(yol) okur
	_preview_rig = CarRig.for_node(_preview)
	_preview_rig.apply(CarAppearance.get_for(scene_path))
	_preview_rig.set_lod_bias(CarRig.LOD_BIAS_GARAGE)  # garaj: tam detay (LOD0)
	_preview_rig.optimize(true)   # lifteki araç durur: parçalar materyal başına birleşir
	if visible and not _closing and _tweens.is_empty():
		car_slot.scale = Vector3.ONE * 0.92
		var tween: Tween = create_tween()
		tween.tween_property(car_slot, "scale", Vector3.ONE, 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Gösterilen aracın paylaşılan görünüm verisi (ileride özelleştirme UI'ı bunu değiştirecek;
## değişiklik önizlemeye ve thumbnail'e kendiliğinden yansır).
func get_current_appearance() -> CarAppearance:
	var entry: Dictionary = CarCatalog.get_entry(_shown_vehicle)
	return CarAppearance.get_for(entry["scene_path"]) if not entry.is_empty() else null


## Gösterilen araç (CarCatalog id).
func shown_vehicle() -> StringName:
	return _shown_vehicle


func _owner_node() -> VehicleOwnership:
	if _ownership == null:
		_ownership = get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership
		if _ownership and not _ownership.ownership_changed.is_connected(_on_ownership_changed):
			_ownership.ownership_changed.connect(_on_ownership_changed)
	return _ownership


## Yeni araç alındı / çıkarıldı: garaj açıksa koleksiyon ve garaj değeri anında güncellenir.
## Lifteki araç satıldıysa yerine sahip olunan ilk araç alınır (lift asla boş kalmaz).
func _on_ownership_changed() -> void:
	if not visible or _closing:
		return
	if _garage != &"":
		_refresh_collection()
		return   # GARAJLARIM: hangi aracın nerede durduğunu yerleşim sinyali söyler (_on_layout_changed)
	if _shown_vehicle != &"" and not _is_owned(_shown_vehicle):
		_shown_vehicle = &""
		_show_vehicle(_first_owned(), false)
	_refresh_collection()


# --- Koleksiyon: sahip olunan araçların garaj zeminindeki fiziksel kopyaları ----------

## Sahiplik listesine göre park etmiş araçları kurar/günceller. Lifteki araç park edilmez
## (aynı modelden iki kopya yüklenmez); onun park yeri boş kalır, seçim değişince geri gelir.
func _refresh_collection() -> void:
	var ownership: VehicleOwnership = _owner_node()
	var owned: Array[StringName] = ownership.owned_vehicle_ids() if ownership else ([_shown_vehicle] as Array[StringName])
	_listed = owned
	_refresh_all_cars_button(owned.size())
	if not SHOW_PARKED_CARS:
		_clear_collection()
		_fit_camera(1)   # kadraj tek araca göre: lift ortada, kamera yakın
		return
	# Artık sahip olunmayan ya da lifte çıkan araçları kaldır
	for id: StringName in _parked.keys():
		if not owned.has(id) or id == _shown_vehicle:
			var node: Node3D = _parked[id]
			if is_instance_valid(node):
				node.queue_free()
			_parked.erase(id)
	# Kalanları sırayla park yerlerine yerleştir (mevcut olanlar yalnızca yer değiştirir)
	var slot: int = 0
	for id: StringName in owned:
		if id == _shown_vehicle:
			continue
		if slot >= PARK_SLOTS.size():
			break   # kapasitenin üstü: fazla araç modeli yüklenmez (liste plakalarında görünür)
		if _parked.has(id):
			(_parked[id] as Node3D).position = PARK_SLOTS[slot]
		else:
			var node: Node3D = _spawn_parked(id, PARK_SLOTS[slot])
			if node:
				_parked[id] = node
		slot += 1
	_fit_camera(owned.size())


## Tek bir aracı park yerine koyar (mevcut sahne + CarRig yolu; yeni yükleme sistemi yok).
func _spawn_parked(vehicle_id: StringName, slot: Vector3) -> Node3D:
	var scene_path: String = CarCatalog.scene_path(vehicle_id)
	if scene_path == "":
		return null
	var scene: PackedScene = load(scene_path)
	if scene == null:
		push_warning("GarageScreen: '%s' sahnesi yüklenemedi" % vehicle_id)
		return null
	var car: Node3D = scene.instantiate() as Node3D
	car.name = String(vehicle_id)
	car.scale = Vector3.ONE * CarCatalog.model_scale(vehicle_id)   # lifteki araçla aynı kural
	car.position = slot
	_collection.add_child(car)
	var rig: CarRig = CarRig.for_node(car)
	rig.apply(CarAppearance.get_for(scene_path))
	rig.set_lod_bias(CarRig.LOD_BIAS_WORLD)   # park etmiş araçlar daha sade kademede (lift tam detay)
	rig.optimize(true)   # park: ~70 parça yerine materyal başına bir çizim
	_disable_shadows(car)   # gölgeyi yalnızca lifteki araç yazar: park başına ~100 çizim çağrısı düşer
	car.add_child(_pick_body(car, vehicle_id))
	return car


## Park etmiş araçların gölge yazmasını kapatır (gölge almaya devam ederler).
func _disable_shadows(car: Node3D) -> void:
	var stack: Array[Node] = [car]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is GeometryInstance3D:
			(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for child: Node in node.get_children():
			stack.append(child)


## Tıklama kutusu: modelin sınırlarından üretilir (CarHitbox ile aynı yöntem, ayrı seçim durumu).
func _pick_body(car: Node3D, vehicle_id: StringName) -> StaticBody3D:
	var bounds: AABB = _model_bounds(car)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "PickBody"
	body.input_ray_pickable = true
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(maxf(bounds.size.x, 0.2), maxf(bounds.size.y, 0.2), maxf(bounds.size.z, 0.2))
	shape.shape = box
	shape.position = bounds.get_center()
	body.add_child(shape)
	body.input_event.connect(_on_parked_input.bind(vehicle_id))
	return body


func _on_parked_input(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3,
		_shape: int, vehicle_id: StringName) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		_show_vehicle(vehicle_id, true)   # tıklanan araç lifte çıkar, bilgi plakaları güncellenir


func _clear_collection() -> void:
	for id: StringName in _parked:
		var node: Node3D = _parked[id]
		if is_instance_valid(node):
			node.queue_free()
	_parked.clear()
	_listed.clear()


## Araç sayısı arttıkça kamera açılır; hepsi kadraja sığar, izometrik açı değişmez.
func _fit_camera(count: int) -> void:
	if _interior_view and _interior_view.active:
		return   # iç mekân kamerası GarageInteriorView'da
	preview_camera.size = lerpf(CAM_SIZE_MIN, CAM_SIZE_MAX,
		clampf(float(count - 1) / CAM_FULL_AT, 0.0, 1.0))
	preview_camera.position = _camera_home + CAM_SHIFT * clampf(float(count - 1) / CAM_SHIFT_AT, 0.0, 1.0)


## Modelin tüm mesh'lerini kapsayan kutu (araç yerel uzayında).
func _model_bounds(car: Node3D) -> AABB:
	var merged: AABB = AABB()
	var first: bool = true
	var stack: Array[Node] = [car]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mesh_node: MeshInstance3D = node
			var box: AABB = car.global_transform.affine_inverse() * mesh_node.global_transform * mesh_node.get_aabb()
			merged = box if first else merged.merge(box)
			first = false
		for child: Node in node.get_children():
			stack.append(child)
	return merged if not first else AABB(Vector3(-0.3, 0.0, -0.5), Vector3(0.6, 0.5, 1.0))


func _is_owned(vehicle_id: StringName) -> bool:
	var ownership: VehicleOwnership = _owner_node()
	return ownership == null or ownership.is_owned(vehicle_id)


## Sahip olunan ilk araç (sahiplik yoksa katalogdaki ilk araca düşer).
func _first_owned() -> StringName:
	var ownership: VehicleOwnership = _owner_node()
	if ownership and ownership.owned_count() > 0:
		return ownership.owned_vehicle_ids()[0]
	var entries: Array[Dictionary] = CarCatalog.all()
	return entries[0]["id"] if not entries.is_empty() else &""


# --- Araç satışı -------------------------------------------------------------------

## Sağ sütuna satış onay plakası (SAT plakası basılınca aksiyon plakalarının yerine görünür).
func _build_sell() -> void:
	_sell_panel = PlatePanel.new()
	_sell_panel.name = "SellPanel"
	_sell_panel.theme_type_variation = &"HudCarPlate"
	_sell_panel.custom_minimum_size = Vector2(190.0, 0.0)
	_sell_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER   # içeriği kadar yer kaplasın
	_sell_panel.visible = false
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 4)
	var title: Label = Label.new()
	title.theme_type_variation = &"HudPlateTitle"
	title.text = Loc.t("ARACI SAT")
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sell_name = Label.new()
	_sell_name.theme_type_variation = &"HudInkCaption"
	_sell_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sell_payout = Label.new()
	_sell_payout.theme_type_variation = &"HudInkCaption"
	_sell_payout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sell_payout.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
	_sell_confirm = PlateButton.new()
	_sell_confirm.theme_type_variation = &"HudPlateSmall"
	_sell_confirm.text = Loc.t("ONAYLA")
	_sell_confirm.bolts = false
	_sell_confirm.focus_mode = Control.FOCUS_NONE
	_sell_confirm.pressed.connect(_on_sell_confirmed)
	var cancel: PlateButton = PlateButton.new()
	cancel.theme_type_variation = &"HudPlateSmall"
	cancel.text = Loc.t("VAZGEÇ")
	cancel.bolts = false
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.pressed.connect(_close_sell)
	box.add_child(title)
	box.add_child(_sell_name)
	box.add_child(_sell_payout)
	box.add_child(_sell_confirm)
	box.add_child(cancel)
	_sell_panel.add_child(box)
	right_group.add_child(_sell_panel)


## Onay plakasını açar: hangi araç, eline ne geçecek. Tek araç satılamaz (garaj boş kalmaz).
func _open_sell() -> void:
	var ownership: VehicleOwnership = _owner_node()
	if ownership == null or _shown_vehicle == &"":
		_actions_clear()
		return
	var entry: Dictionary = CarCatalog.get_entry(_shown_vehicle)
	_sell_name.text = String(entry.get("display_name", _shown_vehicle)).to_upper()
	if ownership.owned_count() <= 1:
		_sell_payout.text = Loc.t("TEK ARACINI SATAMAZSIN")
		_sell_confirm.disabled = true
	else:
		_sell_payout.text = "+%s ₺" % Hud.format_thousands(ownership.sell_price(_shown_vehicle))
		_sell_confirm.disabled = false
	_paint_panel.close()
	_move_panel.hide()
	action_column.hide()
	_sell_panel.show()


func _close_sell() -> void:
	_sell_panel.hide()
	action_column.show()
	_actions_clear()


func _on_sell_confirmed() -> void:
	var ownership: VehicleOwnership = _owner_node()
	if ownership == null:
		return
	ownership.sell_vehicle(_shown_vehicle)   # son araçsa hiçbir şey değişmez
	_close_sell()


# --- Araç detayı (genel puan) ------------------------------------------------------

## Sağ sütunda DETAY plakasının açtığı panel: GENEL puan (0-1000, kusursuz 300 m süresinden — DragRaceSim.overall_of),
## gerçek veri satırı ve dört stat çubuğu (ayrıntı; GENEL artık bunların toplamı değil).
func _build_detail() -> void:
	_detail_panel = PlatePanel.new()
	_detail_panel.name = "DetailPanel"
	_detail_panel.theme_type_variation = &"HudCarPlate"
	_detail_panel.custom_minimum_size = Vector2(190.0, 0.0)
	_detail_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_detail_panel.visible = false
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 4)
	_detail_name = Label.new()
	_detail_name.theme_type_variation = &"HudPlateTitle"
	_detail_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var caption: Label = Label.new()
	caption.theme_type_variation = &"HudInkCaption"
	caption.text = Loc.t("GENEL")
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_overall = Label.new()
	_detail_overall.theme_type_variation = &"HudInkValue"
	_detail_overall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_specs = Label.new()
	_detail_specs.theme_type_variation = &"HudInkCaption"
	_detail_specs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_specs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_specs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_detail_name)
	box.add_child(caption)
	box.add_child(_detail_overall)
	box.add_child(_detail_specs)
	for row: Array in DETAIL_ROWS:
		var key: String = row[0]
		var line: HBoxContainer = HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var title: Label = Label.new()
		title.theme_type_variation = &"HudInkCaption"
		title.text = Loc.t(String(row[1]))
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value: Label = Label.new()
		value.theme_type_variation = &"HudInkCaption"
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(title)
		line.add_child(value)
		var lane: XpLane = XpLane.new()
		lane.segments = 10
		box.add_child(line)
		box.add_child(lane)
		_detail_values[key] = value
		_detail_lanes[key] = lane
	var close_button: PlateButton = PlateButton.new()
	close_button.theme_type_variation = &"HudPlateSmall"
	close_button.text = Loc.t("KAPAT")
	close_button.bolts = false
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(_close_detail)
	box.add_child(close_button)
	_detail_panel.add_child(box)
	right_group.add_child(_detail_panel)


func _refresh_detail() -> void:
	if _detail_panel == null or _shown_vehicle == &"":
		return
	var entry: Dictionary = CarCatalog.get_entry(_shown_vehicle)
	var stats: Dictionary = DragRaceSim.stats_of(_shown_vehicle)
	_detail_name.text = String(entry.get("display_name", _shown_vehicle)).to_upper()
	_detail_overall.text = "%d / %d" % [PerformanceMods.overall(_shown_vehicle), DragRaceSim.OVERALL_MAX]
	_detail_specs.text = spec_text(entry)
	_detail_specs.visible = _detail_specs.text != ""
	for row: Array in DETAIL_ROWS:
		var key: String = row[0]
		var ratio: float = DragRaceSim.stat_ratio(key, float(stats.get(key, 0)))
		(_detail_lanes[key] as XpLane).ratio = ratio
		(_detail_values[key] as Label).text = str(roundi(ratio * 100.0))


## Gerçek fabrika verisinin iki satırlık özeti: "3.0 · ARKADAN İTİŞ" / "0-100 6,5 sn · 250 km/sa".
static func spec_text(entry: Dictionary) -> String:
	var perf: Dictionary = entry.get("performance", {})
	if perf.is_empty():
		return ""
	var drive: String = ""
	match StringName(String(perf.get("drivetrain", ""))):
		&"FWD": drive = Loc.t("ÖNDEN ÇEKİŞ")
		&"RWD": drive = Loc.t("ARKADAN İTİŞ")
		&"AWD": drive = Loc.t("4 ÇEKER")
	var engine: String = String(perf.get("engine", ""))
	if engine.to_lower() == "elektrik":
		engine = Loc.t("ELEKTRİK")
	var id: StringName = StringName(String(entry.get("id", "")))
	if int(perf.get("hp", 0)) > 0:
		var hp: int = roundi(float(PerformanceMods.stats(id)["hp"])) if PerformanceMods.is_modified(id) else int(perf["hp"])
		engine += Loc.t(" · %d HP") % hp
	var parts: PackedStringArray = PackedStringArray()
	for part: String in [engine, drive]:
		if part != "":
			parts.append(part)
	return " · ".join(parts) + "\n" + perf_line(entry)


## Tek satır: "0-100 6,5 sn · 250 km/sa" (yarış davet ekranı da kullanır). Veri yoksa boş. Oyuncunun
## modifiyeli aracında ölçülmüş değerler, iki ondalıkla ("0-100 9,72 sn · 210 km/sa").
static func perf_line(entry: Dictionary) -> String:
	var perf: Dictionary = entry.get("performance", {})
	if perf.is_empty():
		return ""
	var id: StringName = StringName(String(entry.get("id", "")))
	if PerformanceMods.is_modified(id):
		var stats: Dictionary = PerformanceMods.stats(id)
		return Loc.t("0-100 %s sn · %d km/sa") % [ModWorkshop.dec2(float(stats["zero_100"])),
			roundi(float(stats["top_speed"]))]
	return Loc.t("0-100 %s sn · %d km/sa") % [Loc.decimal(float(perf.get("zero_100", 0.0))), int(perf.get("top_speed", 0))]


func _open_detail() -> void:
	if _shown_vehicle == &"":
		_actions_clear()
		return
	_refresh_detail()
	_paint_panel.close()
	_sell_panel.hide()
	_move_panel.hide()
	action_column.hide()
	_detail_panel.show()


func _close_detail() -> void:
	_detail_panel.hide()
	action_column.show()
	_actions_clear()


# --- Boya atölyesi -------------------------------------------------------------

## Sağ sütuna BOYA plakası (mevcut aksiyon plakalarıyla aynı tip) ve onun açtığı panel.
func _build_paint() -> void:
	_paint_button = PlateButton.new()
	_paint_button.name = "PaintButton"
	_paint_button.theme_type_variation = &"HudPlate"
	_paint_button.kind = HudIcon.Kind.PAINT
	_paint_button.text = Loc.t("BOYA")
	_paint_button.custom_minimum_size = Vector2(86.0, 0.0)
	_paint_button.focus_mode = Control.FOCUS_NONE
	_paint_button.pressed.connect(_open_paint)
	# Boya özelliği kapalıyken plaka hiç görünmez (panonun kendisi kurulu kalır: altyapı bozulmaz)
	_paint_button.visible = GameFeatures.PAINT
	action_column.add_child(_paint_button)
	_paint_panel = PaintPanel.new()
	right_group.add_child(_paint_panel)
	_paint_panel.preview_requested.connect(_on_paint_preview)
	_paint_panel.preview_cleared.connect(_on_paint_preview_cleared)
	_paint_panel.closed.connect(func() -> void: action_column.show())


## Sağ sütuna YARIŞ ARACI plakası: lifteki aracı yarışa çıkan araç yapar (RaceManager
## VehicleOwnership.race_vehicle_id'yi okur). Zaten yarış aracıysa plaka pasif ve işaretli.
var _race_button: PlateButton


func _build_race_pick() -> void:
	_race_button = PlateButton.new()
	_race_button.name = "RacePickButton"
	_race_button.theme_type_variation = &"HudPlate"
	_race_button.kind = HudIcon.Kind.CAR
	_race_button.text = Loc.t("YARIŞ ARACI YAP")
	_race_button.custom_minimum_size = Vector2(86.0, 0.0)
	_race_button.focus_mode = Control.FOCUS_NONE
	_race_button.pressed.connect(func() -> void:
		var ownership: VehicleOwnership = _owner_node()
		if ownership and ownership.set_race_vehicle(_shown_vehicle):
			_refresh_race_pick())
	action_column.add_child(_race_button)


func _refresh_race_pick() -> void:
	if _race_button == null:
		return
	var ownership: VehicleOwnership = _owner_node()
	var is_racer: bool = ownership != null and ownership.race_vehicle_id() == _shown_vehicle
	_race_button.text = Loc.t("YARIŞ ARACI ✔") if is_racer else Loc.t("YARIŞ ARACI YAP")
	_race_button.disabled = is_racer or ownership == null


## Sağ sütuna MODİFİYE plakası: lifteki aracın performans modifiyesi (ModWorkshop) — alttaki araç şeridinin
## yerine parça kartları gelir, sağda seçilen parçanın plakası ve YÜKSELT. GERİ araç listesine döner.
func _build_performance_button() -> void:
	var button: PlateButton = PlateButton.new()
	button.name = "ModifyButton"
	button.theme_type_variation = &"HudPlate"
	button.kind = HudIcon.Kind.WRENCH
	button.text = Loc.t("MODİFİYE")
	button.custom_minimum_size = Vector2(86.0, 0.0)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(open_mods)
	action_column.add_child(button)


## MODİFİYE kipine geçer (lifteki araç sahip olunan bir araçsa).
func open_mods() -> void:
	if _shown_vehicle == &"" or not _is_owned(_shown_vehicle) or _workshop.is_active() \
			or _garage == CarGarageManager.WAITING:
		return   # bekleyen araç modifiyeye giremez (garajlar dolu)
	_kill_tweens()
	_set_selector_visible(false)   # giriş animasyonu sürerken eski hedef konum genişleyen sağ plakayı ekrandan iterdi
	_actions_clear()
	_paint_panel.close()
	_sell_panel.hide()
	_detail_panel.hide()
	action_column.hide()
	_info_scroll.hide()
	var strip: Control = bottom_group.get_node_or_null("StripRow") as Control
	if strip:
		strip.hide()
	_set_title(Loc.t("MODİFİYE"))
	_right_layout = {}
	for key: String in ["anchor_left", "anchor_top", "anchor_right", "anchor_bottom", "offset_left", "offset_top",
			"offset_right", "offset_bottom", "grow_horizontal", "grow_vertical"]:
		_right_layout[key] = right_group.get(key)
	_workshop.open(_shown_vehicle)
	_fit_mod_column.call_deferred()
	_place_car_list.call_deferred()


## Araç listesine döner.
func _close_mods() -> void:
	if _workshop == null or not _workshop.is_active():
		return
	_kill_tweens()
	_workshop.close()
	for key: String in _right_layout:   # sağ sütun sahnedeki (dikey ortalı) yerine
		right_group.set(key, _right_layout[key])
	_right_layout = {}
	action_column.show()
	_info_scroll.show()
	var strip: Control = bottom_group.get_node_or_null("StripRow") as Control
	if strip:
		strip.show()
	_refresh_title()
	_apply_responsive_layout()
	_place_car_list.call_deferred()


func is_modding() -> bool:
	return _workshop != null and _workshop.is_active()


## GERİ: modifiye kategorisindeyse genel bakışa, modifiye kipindeyse araç listesine, değilse garajdan çık.
func _on_exit_pressed() -> void:
	if is_modding() and _workshop.in_category():
		_workshop.show_overview()
	elif is_modding():
		_close_mods()
	else:
		close()


## Sol sütun modifiye kipinde değer plakasının boyunda.
func _fit_mod_column() -> void:
	if not is_modding():
		return
	left_group.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	left_group.offset_left = 0.0
	left_group.offset_top = COLUMN_TOP
	left_group.offset_right = left_group.get_combined_minimum_size().x
	left_group.offset_bottom = COLUMN_TOP + _workshop.left_panel().get_combined_minimum_size().y
	if _group_targets.has(left_group):
		_group_targets[left_group] = left_group.position
	# Sağ sütun üste sabit: dikey ortalıyken uzun parça plakası alttaki rafa biniyordu
	var right_size: Vector2 = right_group.get_combined_minimum_size()
	right_group.set_anchors_preset(Control.PRESET_TOP_RIGHT, false)
	right_group.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right_group.grow_vertical = Control.GROW_DIRECTION_END
	right_group.offset_right = 0.0
	right_group.offset_left = -right_size.x
	right_group.offset_top = COLUMN_TOP
	right_group.offset_bottom = COLUMN_TOP + right_size.y
	if _group_targets.has(right_group):
		_group_targets[right_group] = right_group.position


func _set_title(text: String) -> void:
	var title: Label = find_child("TitleLabel", true, false) as Label
	if title:
		title.text = text


## Sağ sütuna KOLEKSİYON plakası (koleksiyon panosu UiRouter'dadır).
func _build_collection_button() -> void:
	var button: PlateButton = PlateButton.new()
	button.name = "CollectionButton"
	button.theme_type_variation = &"HudPlate"
	button.kind = HudIcon.Kind.CAR
	button.text = Loc.t("KOLEKSİYON")
	button.custom_minimum_size = Vector2(86.0, 0.0)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void:
		_actions_clear()
		screen_requested.emit(&"collection"))
	action_column.add_child(button)


## Alt şeridin solundaki TÜM ARAÇLAR plakası: sınıf / nadirlik süzgeçli, sıralanabilir ızgara (AllCarsScreen, UiRouter).
var _all_cars_button: PlateButton


func _build_all_cars_button() -> PlateButton:
	_all_cars_button = PlateButton.new()
	_all_cars_button.name = "AllCarsButton"
	_all_cars_button.theme_type_variation = &"HudPlate"
	_all_cars_button.kind = HudIcon.Kind.GRID
	_all_cars_button.text = Loc.t("TÜM ARAÇLAR")
	_all_cars_button.custom_minimum_size = Vector2(96.0, 0.0)
	_all_cars_button.focus_mode = Control.FOCUS_NONE
	_all_cars_button.pressed.connect(func() -> void:
		_actions_clear()
		screen_requested.emit(&"all_cars"))
	return _all_cars_button


func _refresh_all_cars_button(count: int) -> void:
	if _all_cars_button:
		_all_cars_button.text = Loc.t("TÜM ARAÇLAR\n%d") % count


## TÜM ARAÇLAR panosundan seçildi: araç lifte çıkar, alt şerit onun plakasına kayar.
func show_vehicle(vehicle_id: StringName) -> void:
	if not visible or _closing or not _is_owned(vehicle_id):
		return
	var home: StringName = _garages().garage_of(vehicle_id) if _garages() and _garage != &"" else &""
	if home != &"" and home != _garage:
		_switch_garage(home, vehicle_id)
	else:
		car_list.select(vehicle_id)   # vehicle_selected → _show_vehicle
	var column: Control = car_list.get_node_or_null(NodePath(String(vehicle_id))) as Control
	var scroll: ScrollContainer = car_list.get_parent() as ScrollContainer
	if column and scroll:
		scroll.ensure_control_visible.call_deferred(column)


func _open_paint() -> void:
	if not GameFeatures.PAINT:
		return   # özellik kapalı: pano hiçbir yoldan açılmaz (plaka zaten gizli)
	if _shown_vehicle == &"" or not VehicleOwnership.is_paintable(_shown_vehicle) or _garage == CarGarageManager.WAITING:
		return
	_actions_clear()
	_move_panel.hide()
	action_column.hide()
	_paint_panel.open(_shown_vehicle)


## Yalnızca lifteki araç: paylaşılan görünümün kopyası, rengi değiştirilmiş (hiçbir şey kaydedilmez).
func _on_paint_preview(color: Color) -> void:
	var shared: CarAppearance = get_current_appearance()
	if _preview_rig == null or shared == null:
		return
	var preview: CarAppearance = shared.duplicate() as CarAppearance
	preview.body_color = color
	_preview_rig.apply(preview)


func _on_paint_preview_cleared() -> void:
	var shared: CarAppearance = get_current_appearance()
	if _preview_rig and shared:
		_preview_rig.apply(shared)


# --- Aksiyon plakaları -------------------------------------------------------

func _on_action_toggled(pressed: bool, action: StringName) -> void:
	if action == &"detail":
		if pressed:
			_open_detail()
		else:
			_close_detail()
		return
	if action == &"sell":
		if pressed:
			_open_sell()
		else:
			_sell_panel.hide()
			action_column.show()
		return
	if pressed:
		_sell_panel.hide()
		_detail_panel.hide()
		action_column.show()
		action_selected.emit(action, _shown_vehicle)


func _actions_clear() -> void:
	for button: PlateButton in [detail_button, repair_button, sell_button]:
		button.set_pressed_no_signal(false)


# --- GARAJLARIM: garaj seçici, TAŞI, bekleyen araç, boş garaj (docs/GARAJLAR_TASARIM.md §2–6) ------------------

## İçinde bulunulan garaj (CarGarageCatalog id ya da CarGarageManager.WAITING = bekleme otoparkı). Garaj yöneticisi
## yoksa (arkadaş garajı ziyareti) &"": eski tek garaj görünümü, alt şeritte bütün araçlar.
var _garage: StringName = &""
var _garage_manager: CarGarageManager
var _prev_garage: PlateButton
var _next_garage: PlateButton
var _title_hit: Button
var _move_button: PlateButton
var _move_panel: PlatePanel
var _move_list: VBoxContainer
var _waiting_note: PlatePanel
var _empty_panel: PlatePanel
var _empty: bool = false
var _interior_view: GarageInteriorView
var _look: Dictionary = {}     # duvar mesh adı → özgün materyal
var _tinted: Dictionary = {}   # "mesh|garaj" → renklendirilmiş kopya

## Faz 3'ün Blender garajları gelene kadar garajlar KUTU garajdır: bugünkü oda, duvarları garajın rengine boyanır.
const TINTED_MESHES: Array[String] = ["BackWall", "LeftWall", "BackBand", "LeftBand"]


func _garages() -> CarGarageManager:
	if _garage_manager == null and is_inside_tree():
		_garage_manager = get_tree().get_first_node_in_group("car_garages") as CarGarageManager
		if _garage_manager:
			_garage_manager.layout_changed.connect(_on_layout_changed)
			_garage_manager.garages_changed.connect(_refresh_title)
			_garage_manager.garages_changed.connect(_refresh_interior_levels)
	return _garage_manager


## İçinde bulunulan garaj.
func current_garage() -> StringName:
	return _garage


## Alt şeridin kaynağı: içinde bulunulan garajın araçları (yönetici yoksa sahip olunan hepsi).
func _list_source() -> Array[StringName]:
	var manager: CarGarageManager = _garages()
	if manager == null or _garage == &"":
		var ownership: VehicleOwnership = _owner_node()
		var all: Array[StringName] = []
		if ownership:
			all = ownership.owned_vehicle_ids()
		return all
	return manager.cars_in(_garage)


## Oklarla gezilen sıra: alınmış garajlar (merdiven sırasıyla) + bekleyen varsa BEKLEYENLER.
func _garage_cycle() -> Array[StringName]:
	var out: Array[StringName] = []
	var manager: CarGarageManager = _garages()
	if manager == null:
		return out
	out = manager.owned_garages()
	if not manager.waiting_ids().is_empty():
		out.append(CarGarageManager.WAITING)
	return out


## Açılışta: listede seçili aracın garajı; o yoksa son bakılan garaj (hâlâ geçerliyse); yoksa MAHALLE.
func _pick_garage_on_open() -> void:
	var manager: CarGarageManager = _garages()
	if manager == null:
		_garage = &""
		return
	var cycle: Array[StringName] = _garage_cycle()
	var home: StringName = manager.garage_of(car_list.selected_vehicle()) if car_list.selected_vehicle() != &"" else &""
	if home != &"":
		_garage = home
	elif not cycle.has(_garage):
		_garage = CarGarageCatalog.MAHALLE


## Başka garaja geçer; `focus` o garajdaysa lifte o çıkar, yoksa garajın ilk aracı (garaj boşsa boş garaj).
func _switch_garage(garage: StringName, focus: StringName = &"") -> void:
	_garage = garage
	_sell_panel.hide()
	_detail_panel.hide()
	_move_panel.hide()
	_paint_panel.close()
	_actions_clear()
	car_list.refresh()
	_apply_garage_look()   # iç mekân ve araçları önce (bkz. open)
	var cars: Array[StringName] = _list_source()
	var target: StringName = focus if cars.has(focus) else (cars[0] if not cars.is_empty() else &"")
	if target == &"":
		_show_empty()
	elif target == _shown_vehicle:
		car_list.select(target)
		_leave_empty()
		_refresh_garage_actions()
		_focus_interior(target)
	else:
		_show_vehicle(target, true)
	_refresh_title()
	_place_car_list.call_deferred()


func _step_garage(step: int) -> void:
	var cycle: Array[StringName] = _garage_cycle()
	if cycle.size() < 2 or is_modding():
		return
	_switch_garage(cycle[posmod(cycle.find(_garage) + step, cycle.size())])


## Yerleşim değişti (araç geldi / satıldı / taşındı, bekleyen garaja girdi, yer açıldı).
func _on_layout_changed() -> void:
	if not visible or _closing or _garage == &"":
		return
	var manager: CarGarageManager = _garages()
	if is_modding():
		car_list.refresh()
		return
	var cars: Array[StringName] = _list_source()
	if _shown_vehicle != &"" and not cars.has(_shown_vehicle):
		var home: StringName = manager.garage_of(_shown_vehicle)
		if home != &"":   # taşındı ya da bekleme otoparkından garaja girdi: araç izlenir
			_switch_garage(home, _shown_vehicle)
			return
	if _garage == CarGarageManager.WAITING and cars.is_empty():
		_switch_garage(CarGarageCatalog.MAHALLE)
		return
	car_list.refresh()
	_sync_interior_cars()
	if _shown_vehicle == &"" or not cars.has(_shown_vehicle):
		if cars.is_empty():
			_show_empty()
		else:
			_shown_vehicle = &""
			_show_vehicle(cars[0], false)
	_refresh_title()


# --- Başlık: ‹ GARAJ ADI  dolu/kapasite › ---------------------------------------------------------------

## Sahnedeki başlık plakası iki ok plakasının arasına alınır; plakanın kendisine basınca GARAJLARIM panosu açılır.
func _build_garage_selector() -> void:
	var sign: Control = get_node_or_null("%TitleSign") as Control
	if sign == null:
		return
	var host: Node = sign.get_parent()
	var index: int = sign.get_index()
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "GarageSelector"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 6)
	host.remove_child(sign)
	_prev_garage = _arrow_button("PrevGarage", "‹", -1)
	_next_garage = _arrow_button("NextGarage", "›", 1)
	row.add_child(_prev_garage)
	row.add_child(sign)
	row.add_child(_next_garage)
	host.add_child(row)
	host.move_child(row, index)
	_title_hit = Button.new()
	_title_hit.name = "GaragesHit"
	_title_hit.flat = true
	_title_hit.focus_mode = Control.FOCUS_NONE
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
		_title_hit.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_title_hit.pressed.connect(func() -> void:
		if _garages() and not is_modding():
			_actions_clear()
			screen_requested.emit(&"car_garages"))
	sign.add_child(_title_hit)
	_set_selector_visible(false)


func _arrow_button(node_name: String, glyph: String, step: int) -> PlateButton:
	var button: PlateButton = PlateButton.new()
	button.name = node_name
	button.theme_type_variation = &"HudPlateSmall"
	button.bolts = false
	button.text = glyph
	button.add_theme_font_size_override(&"font_size", 22)
	button.custom_minimum_size = Vector2(PlateButton.MIN_PLATE_HEIGHT, 0.0)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_step_garage.bind(step))
	return button


func _set_selector_visible(on: bool) -> void:
	var cycle_size: int = _garage_cycle().size() if on else 0
	if _prev_garage:
		_prev_garage.visible = cycle_size > 1
		_next_garage.visible = cycle_size > 1
	if _title_hit:
		_title_hit.visible = on and _garages() != null


func _refresh_title() -> void:
	if is_modding():
		return
	var manager: CarGarageManager = _garages()
	_set_selector_visible(manager != null and _garage != &"")
	if manager == null or _garage == &"":
		_set_title(Loc.t("ARAÇLAR"))
	elif _garage == CarGarageManager.WAITING:
		_set_title(Loc.t("BEKLEYENLER   %d") % manager.waiting_ids().size())
	else:
		_set_title("%s   %d/%d" % [CarGarageCatalog.display_name(_garage), manager.used(_garage), manager.capacity(_garage)])


## Duvar tabelası: garajın adı, tabela tahtasına (0,76 m) sığacak puntoda.
func _set_wall_sign(text: String) -> void:
	var wall_sign: Label3D = car_viewport.get_node_or_null("Environment/WallSignText") as Label3D
	if wall_sign == null:
		return
	if not wall_sign.has_meta(&"base_size"):
		wall_sign.set_meta(&"base_size", wall_sign.font_size)
	wall_sign.text = text
	# Punto gerçek font ölçüsünden (dil değişince uzunluk değişir). Hedef 300 px (tahtanın ~%80'i): tahtanın sağ
	# ucu telefonda aksiyon plakalarının arkasında kalıyor
	var font: Font = wall_sign.font if wall_sign.font else ThemeDB.fallback_font
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 96).x
	wall_sign.font_size = clampi(int(96.0 * 300.0 / maxf(width, 1.0)), 28, int(wall_sign.get_meta(&"base_size")))


## Pişmiş 3D iç mekânı olan garajlar (GarageInterior): MAHALLE ve BEKLEYENLER (çatı katı otopark). Ötekiler Faz 3
## sürerken KUTU garaj (aşağıda).
func _interior_id(garage: StringName) -> StringName:
	if garage == CarGarageManager.WAITING:
		return &"waiting"
	return garage if GarageInterior.has_scene(garage) else &""


## İç mekân kipine girer / çıkar; girildiyse araçlar park yerlerine konur. Eski oda ve lift gizlenir.
func _apply_interior() -> bool:
	var id: StringName = _interior_id(_garage) if _garage != &"" else &""
	if id == &"" or not visible:
		_interior_view.exit()
		return false
	var hide: Array[Node3D] = [car_slot]
	var room: Node3D = car_viewport.get_node_or_null("Environment") as Node3D
	if room:
		hide.append(room)
	if not _interior_view.enter(id, car_viewport, preview_camera, car_viewport.get_node_or_null("KeyLight") as DirectionalLight3D,
			hide):
		return false
	_refresh_interior_levels()
	_sync_interior_cars()
	return true


func _refresh_interior_levels() -> void:
	var manager: CarGarageManager = _garages()
	if not _interior_view.active or manager == null or not CarGarageCatalog.has(_garage):
		return
	var levels: Dictionary = {}
	for item: StringName in CarGarageCatalog.ITEMS:
		levels[item] = manager.item_level(_garage, item)
	levels[&"floor"] = manager.item_level(_garage, CarGarageCatalog.FLOOR)
	_interior_view.set_levels(levels)


## Park yerlerindeki araçlar: garajın yerleri; BEKLEYENLER'de en son gelen çekicinin kasasında, ötekiler sırayla.
func _sync_interior_cars() -> void:
	var manager: CarGarageManager = _garages()
	if not _interior_view.active or manager == null:
		return
	if _garage == CarGarageManager.WAITING:
		var waiting: Array[StringName] = manager.waiting_ids()
		var tow: StringName = waiting.pop_back() if not waiting.is_empty() else &""
		_interior_view.sync_cars(waiting, tow)
	else:
		_interior_view.sync_cars(manager.slots_of(_garage))


## İç mekândaysa kamera araca gider, BOYA önizlemesi park etmiş aracın görünüm sürücüsünü kullanır. Lift modeli
## yüklenmez (varsa serbest). İç mekânda değilse false.
func _focus_interior(vehicle_id: StringName) -> bool:
	if not _interior_view.active or not _interior_view.has_car(vehicle_id):
		return false
	if _preview:
		_preview.queue_free()
		_preview = null
	_preview_rig = _interior_view.rig_of(vehicle_id)
	_interior_view.focus(vehicle_id)
	return true


func _on_interior_car_tapped(vehicle_id: StringName) -> void:
	if is_modding() or _closing:
		return
	car_list.select(vehicle_id)   # vehicle_selected → _show_vehicle (alt şerit de eşlenir)
	if _shown_vehicle != vehicle_id:
		_show_vehicle(vehicle_id, true)


func _on_view_gui_input(event: InputEvent) -> void:
	if _interior_view.handle_input(event):
		view.accept_event()


## KUTU GARAJ görünümü: duvarlar garajın rengine boyanır, tabelada garajın adı (MAHALLE ve bekleyenler: özgün oda).
func _apply_garage_look() -> void:
	if _apply_interior():
		return
	var environment: Node = car_viewport.get_node_or_null("Environment")
	if environment == null:
		return
	var tinted: bool = CarGarageCatalog.has(_garage) and _garage != CarGarageCatalog.MAHALLE
	for mesh_name: String in TINTED_MESHES:
		var mesh: MeshInstance3D = environment.get_node_or_null(mesh_name) as MeshInstance3D
		if mesh == null:
			continue
		if not _look.has(mesh_name):
			_look[mesh_name] = mesh.material_override
		var base: StandardMaterial3D = _look[mesh_name] as StandardMaterial3D
		if not tinted or base == null:
			mesh.material_override = _look[mesh_name]
			continue
		var key: String = "%s|%s" % [mesh_name, _garage]
		if not _tinted.has(key):
			var copy: StandardMaterial3D = base.duplicate() as StandardMaterial3D
			copy.albedo_color = base.albedo_color * CarGarageCatalog.tint(_garage)
			_tinted[key] = copy
		mesh.material_override = _tinted[key]
	if _garage == CarGarageManager.WAITING:
		_set_wall_sign(Loc.t("BEKLEYENLER"))
	elif CarGarageCatalog.has(_garage):
		_set_wall_sign(CarGarageCatalog.display_name(_garage))
	else:
		_set_wall_sign(Loc.t("ARAÇLAR"))


# --- Aksiyonlar: bekleyen araç, TAŞI, boş garaj ---------------------------------------------------------

## Bekleyen araç yarışa / modifiyeye / boyaya giremez, taşınamaz (yer yok): yalnız DETAY, SAT, KOLEKSİYON.
func _refresh_garage_actions() -> void:
	var manager: CarGarageManager = _garages()
	var waiting: bool = manager != null and _garage == CarGarageManager.WAITING
	_waiting_note.visible = waiting and not _empty
	_race_button.visible = not waiting
	repair_button.visible = not waiting
	var modify: Control = action_column.get_node_or_null("ModifyButton") as Control
	if modify:
		modify.visible = not waiting
	_paint_button.visible = GameFeatures.PAINT and VehicleOwnership.is_paintable(_shown_vehicle) and not waiting
	_move_button.visible = manager != null and not waiting and manager.owned_garages().size() > 1


func _build_waiting_note() -> void:
	_waiting_note = _note_panel("WaitingNote", Loc.t("BEKLİYOR"),
		Loc.t("GARAJLAR DOLU. YER AÇILINCA KENDİLİĞİNDEN GİRER."), Loc.t("GARAJLARIM"))
	_waiting_note.visible = false
	action_column.add_child(_waiting_note)
	action_column.move_child(_waiting_note, 0)


func _build_empty_panel() -> void:
	_empty_panel = _note_panel("EmptyPanel", Loc.t("GARAJ BOŞ"),
		Loc.t("YENİ ARAÇLAR BOŞ YERİ OLAN EN ÜST GARAJA PARK EDER. BAŞKA GARAJDAN TAŞI İLE DE GETİREBİLİRSİN."),
		Loc.t("GARAJLARIM"))
	_empty_panel.visible = false
	right_group.add_child(_empty_panel)


## Başlık + açıklama + GARAJLARIM plakası.
func _note_panel(node_name: String, title_text: String, body_text: String, button_text: String) -> PlatePanel:
	var panel: PlatePanel = PlatePanel.new()
	panel.name = node_name
	panel.theme_type_variation = &"HudCarPlate"
	panel.custom_minimum_size = Vector2(190.0, 0.0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 4)
	var title: Label = Label.new()
	title.theme_type_variation = &"HudPlateTitle"
	title.text = title_text
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var body: Label = Label.new()
	body.theme_type_variation = &"HudInkCaption"
	body.text = body_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(170.0, 0.0)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var button: PlateButton = PlateButton.new()
	button.theme_type_variation = &"HudPlateSmall"
	button.text = button_text
	button.bolts = false
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void:
		_actions_clear()
		screen_requested.emit(&"car_garages"))
	box.add_child(title)
	box.add_child(body)
	box.add_child(button)
	panel.add_child(box)
	return panel


## Garaj boş: lift boş kalır, bilgi ve aksiyon plakalarının yerine GARAJ BOŞ notu.
func _show_empty() -> void:
	_empty = true
	_clear_preview()
	if _interior_view.active:
		_interior_view.overview()
	car_name_label.text = ""
	_info_scroll.hide()
	action_column.hide()
	_sell_panel.hide()
	_detail_panel.hide()
	_move_panel.hide()
	_waiting_note.hide()
	_empty_panel.show()


func _leave_empty() -> void:
	if not _empty:
		return
	_empty = false
	_empty_panel.hide()
	_info_scroll.show()
	action_column.show()
	_apply_responsive_layout()


func _build_move() -> void:
	_move_button = PlateButton.new()
	_move_button.name = "MoveButton"
	_move_button.theme_type_variation = &"HudPlate"
	_move_button.kind = HudIcon.Kind.BOX
	_move_button.text = Loc.t("TAŞI")
	_move_button.custom_minimum_size = Vector2(86.0, 0.0)
	_move_button.focus_mode = Control.FOCUS_NONE
	_move_button.visible = false
	_move_button.pressed.connect(_open_move)
	action_column.add_child(_move_button)
	_move_panel = PlatePanel.new()
	_move_panel.name = "MovePanel"
	_move_panel.theme_type_variation = &"HudCarPlate"
	_move_panel.custom_minimum_size = Vector2(190.0, 0.0)
	_move_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_move_panel.visible = false
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 4)
	var title: Label = Label.new()
	title.theme_type_variation = &"HudPlateTitle"
	title.text = Loc.t("BAŞKA GARAJA TAŞI")
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)
	_move_list = VBoxContainer.new()
	_move_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_move_list.add_theme_constant_override(&"separation", 4)
	box.add_child(_move_list)
	var cancel: PlateButton = PlateButton.new()
	cancel.theme_type_variation = &"HudPlateSmall"
	cancel.text = Loc.t("VAZGEÇ")
	cancel.bolts = false
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.pressed.connect(_close_move)
	box.add_child(cancel)
	_move_panel.add_child(box)
	right_group.add_child(_move_panel)


## Hedefler: öteki alınmış garajlar, doluluklarıyla. Dolu garaj basılamaz.
func _open_move() -> void:
	var manager: CarGarageManager = _garages()
	if manager == null or _shown_vehicle == &"":
		return
	for child: Node in _move_list.get_children():
		_move_list.remove_child(child)
		child.queue_free()
	for garage: StringName in manager.owned_garages():
		if garage == _garage:
			continue
		var full: bool = manager.used(garage) >= manager.capacity(garage)
		var button: PlateButton = PlateButton.new()
		button.name = "MoveTo_%s" % garage
		button.theme_type_variation = &"HudPlateSmall"
		button.bolts = false
		button.focus_mode = Control.FOCUS_NONE
		button.text = "%s\n%s" % [CarGarageCatalog.display_name(garage), Loc.t("DOLU") if full
			else "%d/%d" % [manager.used(garage), manager.capacity(garage)]]
		button.disabled = full
		button.pressed.connect(_on_move_picked.bind(garage))
		_move_list.add_child(button)
	_actions_clear()
	_paint_panel.close()
	_sell_panel.hide()
	_detail_panel.hide()
	action_column.hide()
	_move_panel.show()


func _close_move() -> void:
	_move_panel.hide()
	action_column.show()
	_actions_clear()


## Araç taşınır; yerleşim sinyali ekranı hedef garaja geçirir (araç izlenir).
func _on_move_picked(garage: StringName) -> void:
	var car: StringName = _shown_vehicle
	_close_move()
	var manager: CarGarageManager = _garages()
	if manager:
		manager.move(car, garage)


## GARAJLARIM'dan GİT / BEKLEYENLER: o garaja geçilir (alınmamış garaja, boş bekleme otoparkına geçilmez).
func go_to_garage(garage: StringName) -> void:
	var manager: CarGarageManager = _garages()
	if not visible or _closing or manager == null or is_modding():
		return
	if garage == CarGarageManager.WAITING and manager.waiting_ids().is_empty():
		return
	if garage != CarGarageManager.WAITING and not manager.is_owned(garage):
		return
	if garage != _garage:
		_switch_garage(garage)
