class_name GarageScreen
extends Control
## Tam ekran GARAJ görünümü — "yol mobilyası / plaka" dili.
## Kendi 3D garaj dünyası (SubViewport, tam ekran): asfalt zemin, güvenlik şeritleri, iki duvar,
## lift platformu ve ortada seçili aracın gerçek modeli. Üstünde plakalar: tabela, sol bilgi plakaları,
## sağ aksiyon plakaları, alt park yeri listesi, sol alt çıkış.
## Sol plaka sütununun altında GELİŞTİRME plakaları vardır (TAMİR HIZI / TAMİR ALANI): seviye, sıradaki
## ücret ve YÜKSELT plakası. Satın alma GarageUpgradeManager üzerinden yapılır (para EconomyManager'dan
## düşer); bakiye yetmezse plaka kapalıdır, maksimumda "MAKSİMUM" yazar. Başka ekonomi/mantık yok.
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
## Modeller yalnızca garaj AÇIKKEN yaşar: kapanışta hepsi serbest bırakılır, kapalıyken hiçbir araç
## modeli bellekte durmaz. Satın alınmayan araç hiç yüklenmez; oyuncu araçları trafiğe de çıkmaz.

signal action_selected(action: StringName, car: StringName)
signal closed

const SLIDE: float = 16.0

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

## Geliştirme plakaları: id → {plate, level, cost, button}
var _upgrade_rows: Dictionary = {}
var _upgrades: GarageUpgradeManager
var _economy: EconomyManager

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


func _ready() -> void:
	visible = false
	_actions.allow_unpress = true
	var actions: Dictionary = {detail_button: &"detail", repair_button: &"repair", sell_button: &"sell"}
	for button: PlateButton in actions:
		button.button_group = _actions
		button.toggled.connect(_on_action_toggled.bind(actions[button]))
	exit_button.pressed.connect(close)
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
	_build_upgrade_plates()
	_build_paint()
	_connect_upgrades.call_deferred()


func _process(delta: float) -> void:
	if turntable_speed > 0.0 and not _closing:
		car_slot.rotate_y(deg_to_rad(turntable_speed) * delta)


func _unhandled_input(event: InputEvent) -> void:
	if visible and not _closing and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


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
	_refresh_upgrades()
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
	_actions_clear()
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
	# .tscn köküne gömülü ölçekleri yok say (Getz 0.6): dört modelin native boyu ~1 birim,
	# lift üstünde hepsi aynı ölçekte görünsün
	_preview.scale = Vector3.ONE
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


## Yeni araç alındı / çıkarıldı: garaj açıksa koleksiyon anında güncellenir.
func _on_ownership_changed() -> void:
	if visible and not _closing:
		_refresh_collection()


# --- Koleksiyon: sahip olunan araçların garaj zeminindeki fiziksel kopyaları ----------

## Sahiplik listesine göre park etmiş araçları kurar/günceller. Lifteki araç park edilmez
## (aynı modelden iki kopya yüklenmez); onun park yeri boş kalır, seçim değişince geri gelir.
func _refresh_collection() -> void:
	var ownership: VehicleOwnership = _owner_node()
	var owned: Array[StringName] = ownership.owned_vehicle_ids() if ownership else ([_shown_vehicle] as Array[StringName])
	_listed = owned
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
	car.scale = Vector3.ONE        # wrapper .tscn ölçekleri yok sayılır (lifteki araçla aynı kural)
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
	preview_camera.size = lerpf(CAM_SIZE_MIN, CAM_SIZE_MAX, clampf(float(count - 1) / CAM_FULL_AT, 0.0, 1.0))
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


# --- Geliştirmeler (TAMİR HIZI / TAMİR ALANI) ------------------------------------

## Sol sütunun altına iki geliştirme plakası kurar (mevcut plaka dili; yeni UI tasarımı yok).
func _build_upgrade_plates() -> void:
	var caption: Label = Label.new()
	caption.text = "GELİŞTİRMELER"
	caption.theme_type_variation = &"HudOutlined"   # dünya üstünde: konturlu yazı (plaka arkası yok)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.custom_minimum_size = Vector2(0.0, 20.0)   # plakanın altına girmesin
	caption.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	info_column.add_child(caption)
	for id: StringName in [GarageUpgradeManager.SPEED_ID, GarageUpgradeManager.CAPACITY_ID]:
		var plate: PlatePanel = PlatePanel.new()
		plate.theme_type_variation = &"HudCarPlate"
		plate.custom_minimum_size = Vector2(190.0, 0.0)
		var row: HBoxContainer = HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override(&"separation", 8)
		var texts: VBoxContainer = VBoxContainer.new()
		texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override(&"separation", 0)
		var title: Label = Label.new()
		title.theme_type_variation = &"HudPlateTitle"
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var level: Label = Label.new()
		level.theme_type_variation = &"HudInkCaption"
		level.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texts.add_child(title)
		texts.add_child(level)
		row.add_child(texts)
		var button: PlateButton = PlateButton.new()
		button.theme_type_variation = &"HudPlateSmall"
		button.kind = HudIcon.Kind.NONE   # iki satırlı metinle ikon çakışıyor; tutar zaten yazıda
		button.bolts = false
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(76.0, 0.0)
		button.pressed.connect(_on_upgrade_pressed.bind(id))
		row.add_child(button)
		plate.add_child(row)
		info_column.add_child(plate)
		_upgrade_rows[id] = {"title": title, "level": level, "button": button}


func _connect_upgrades() -> void:
	_upgrades = get_tree().get_first_node_in_group("garage_upgrades") as GarageUpgradeManager
	_economy = get_tree().get_first_node_in_group("economy") as EconomyManager
	if _upgrades:
		_upgrades.upgrade_purchased.connect(func(_id: StringName, _level: int) -> void: _refresh_upgrades())
	if _economy:
		_economy.money_changed.connect(func(_m: int) -> void: _refresh_upgrades())
	_refresh_upgrades()


func _on_upgrade_pressed(id: StringName) -> void:
	if _upgrades:
		_upgrades.buy(id)   # bakiye yetmezse hiçbir şey değişmez; plakalar sinyalle tazelenir
	_refresh_upgrades()


## Plakaları güncel seviye / ücret / bakiye durumuna göre yazar.
func _refresh_upgrades() -> void:
	for id: StringName in _upgrade_rows:
		var row: Dictionary = _upgrade_rows[id]
		var title: Label = row["title"]
		var level: Label = row["level"]
		var button: PlateButton = row["button"]
		if _upgrades == null:
			title.text = "—"
			level.text = ""
			button.disabled = true
			continue
		var upgrade: GarageUpgrade = _upgrades.get_upgrade(id)
		title.text = upgrade.display_name
		level.text = "Seviye %d/%d" % [upgrade.current_level, upgrade.max_level]
		if upgrade.is_max():
			button.text = "MAKSİMUM"
			button.disabled = true
			continue
		var cost: int = upgrade.next_cost()
		button.text = "YÜKSELT\n%s ₺" % Hud.format_thousands(cost)
		button.disabled = _economy != null and not _economy.can_afford(cost)


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
	action_column.add_child(_paint_button)
	_paint_panel = PaintPanel.new()
	right_group.add_child(_paint_panel)
	_paint_panel.preview_requested.connect(_on_paint_preview)
	_paint_panel.preview_cleared.connect(_on_paint_preview_cleared)
	_paint_panel.closed.connect(func() -> void: action_column.show())


func _open_paint() -> void:
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
	if pressed:
		action_selected.emit(action, _shown_vehicle)


func _actions_clear() -> void:
	for button: PlateButton in [detail_button, repair_button, sell_button]:
		button.set_pressed_no_signal(false)
