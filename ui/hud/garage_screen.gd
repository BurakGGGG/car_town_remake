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
	bottom_group.add_child(scroll)
	bottom_group.move_child(scroll, index)
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
	var left_inset: float = 0.0
	for group: Control in [exit_group, left_group]:
		if group and group.is_visible_in_tree():
			left_inset = maxf(left_inset, maxf(group.size.x, group.get_combined_minimum_size().x))
	if left_inset > 0.0:
		left_inset += 8.0
	bottom_group.offset_left = left_inset
	bottom_group.offset_top = area.y - height
	bottom_group.offset_right = area.x
	bottom_group.offset_bottom = area.y
	# Kaydırma kabı kendi minimum genişliği yüzünden 8 px taşabiliyor: kırpılır, böylece
	# hiçbir plaka kadrajın dışına çizilmez.
	bottom_group.clip_contents = true
	# Açılış animasyonu hedef konumu bir kez yakalıyor; şerit sonradan yer değiştirirse
	# tween eski hedefe geri çekmesin diye hedef de tazelenir.
	if _group_targets.has(bottom_group):
		_group_targets[bottom_group] = bottom_group.position
	_apply_responsive_layout()   # sol sütun şeridin üstünde bitsin


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
## Genel puanı oluşturan dört stat: [statü anahtarı, etiket].
const DETAIL_ROWS: Array = [
	["top_speed", "HIZ"], ["acceleration", "HIZLANMA"], ["reaction", "TEPKİ"], ["grip", "TUTUŞ"]]
var _detail_lanes: Dictionary = {}
var _detail_values: Dictionary = {}


func _ready() -> void:
	visible = false
	_actions.allow_unpress = true
	var actions: Dictionary = {detail_button: &"detail", repair_button: &"repair", sell_button: &"sell"}
	for button: PlateButton in actions:
		button.button_group = _actions
		button.toggled.connect(_on_action_toggled.bind(actions[button]))
	exit_button.pressed.connect(close)
	# Bu ekran ARAÇLAR sekmesidir; garajın kendisi (seviye, düzenleme, detay) ana görünümün alt
	# panelindedir (GaragePanel). Sahne dosyasındaki "GARAJ" yazıları burada değiştirilir.
	exit_button.text = "GERİ"
	var title: Label = find_child("TitleLabel", true, false) as Label
	if title:
		title.text = "ARAÇLAR"
	var wall_sign: Label3D = car_viewport.get_node_or_null("Environment/WallSignText") as Label3D
	if wall_sign:
		wall_sign.text = "ARAÇLAR"
	car_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
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
	_build_collection_button()
	_build_sell()
	_build_detail()
	_wrap_info_column()
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
	car_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	car_list.open()   # listeyi güncel sahiplikle kurar (yeni alınan araç burada belirir)
	# Gösterilecek araç: listede seçili olan, yoksa sahip olunan ilk araç
	var target: StringName = car_list.selected_vehicle()
	if target == &"" or not _is_owned(target):
		target = _first_owned()
	_shown_vehicle = &""
	_show_vehicle(target, false)
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


func _finish_close() -> void:
	_sell_panel.hide()
	_detail_panel.hide()
	action_column.show()
	_paint_panel.close()   # önizleme bırakılır; yeniden açılışta aksiyon plakaları görünür
	car_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
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
	car_name_label.text = String(entry["display_name"]).to_upper()
	year_label.text = str(entry["year"])
	condition_gauge.ratio = entry["condition"]
	condition_label.text = "%d%%" % roundi(float(entry["condition"]) * 100.0)
	value_label.text = Hud.format_thousands(entry["price"])
	_load_preview(entry["scene_path"])
	_refresh_detail()
	_actions_clear()
	_refresh_race_pick()
	if _paint_panel.visible:
		_paint_panel.set_vehicle(_shown_vehicle)   # yeni aracın rengi seçili, önizleme yok


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
	title.text = "ARACI SAT"
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
	_sell_confirm.text = "ONAYLA"
	_sell_confirm.bolts = false
	_sell_confirm.focus_mode = Control.FOCUS_NONE
	_sell_confirm.pressed.connect(_on_sell_confirmed)
	var cancel: PlateButton = PlateButton.new()
	cancel.theme_type_variation = &"HudPlateSmall"
	cancel.text = "VAZGEÇ"
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
		_sell_payout.text = "TEK ARACINI SATAMAZSIN"
		_sell_confirm.disabled = true
	else:
		_sell_payout.text = "+%s ₺" % Hud.format_thousands(ownership.sell_price(_shown_vehicle))
		_sell_confirm.disabled = false
	_paint_panel.close()
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

## Sağ sütunda DETAY plakasının açtığı panel: GENEL puan (0-1000) ve onu oluşturan dört stat.
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
	caption.text = "GENEL"
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_overall = Label.new()
	_detail_overall.theme_type_variation = &"HudInkValue"
	_detail_overall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_detail_name)
	box.add_child(caption)
	box.add_child(_detail_overall)
	for row: Array in DETAIL_ROWS:
		var key: String = row[0]
		var line: HBoxContainer = HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var title: Label = Label.new()
		title.theme_type_variation = &"HudInkCaption"
		title.text = row[1]
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
	close_button.text = "KAPAT"
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
	_detail_overall.text = "%d / %d" % [DragRaceSim.overall_of(_shown_vehicle), DragRaceSim.OVERALL_MAX]
	for row: Array in DETAIL_ROWS:
		var key: String = row[0]
		var ratio: float = DragRaceSim.stat_ratio(key, float(stats.get(key, 0)))
		(_detail_lanes[key] as XpLane).ratio = ratio
		(_detail_values[key] as Label).text = str(roundi(ratio * 100.0))


func _open_detail() -> void:
	if _shown_vehicle == &"":
		_actions_clear()
		return
	_refresh_detail()
	_paint_panel.close()
	_sell_panel.hide()
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
	_paint_button.text = "BOYA"
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
	_race_button.text = "YARIŞ ARACI YAP"
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
	_race_button.text = "YARIŞ ARACI ✔" if is_racer else "YARIŞ ARACI YAP"
	_race_button.disabled = is_racer or ownership == null


## Sağ sütuna KOLEKSİYON plakası (koleksiyon panosu UiRouter'dadır).
func _build_collection_button() -> void:
	var button: PlateButton = PlateButton.new()
	button.name = "CollectionButton"
	button.theme_type_variation = &"HudPlate"
	button.kind = HudIcon.Kind.CAR
	button.text = "KOLEKSİYON"
	button.custom_minimum_size = Vector2(86.0, 0.0)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void:
		_actions_clear()
		screen_requested.emit(&"collection"))
	action_column.add_child(button)


func _open_paint() -> void:
	if not GameFeatures.PAINT:
		return   # özellik kapalı: pano hiçbir yoldan açılmaz (plaka zaten gizli)
	if _shown_vehicle == &"":
		return
	_actions_clear()
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
