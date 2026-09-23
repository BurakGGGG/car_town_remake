class_name CarGallery
extends HBoxContainer
## ARAÇLAR listesi: her araç için ayrı bir krem plaka sütunu (mevcut plaka dili; kart yok).
## Sütun: aracın gerçek modelinin küçük render'ı + MARKA/MODEL plakası (PlateButton); MAĞAZA
## kipinde altına "YIL · DURUM" satırı ve fiyat / durum plakası eklenir.
##
## İki kip vardır; kipi ebeveyn kurar (sahne değişikliği gerekmez, plakalar bir kare sonra kurulur):
##   Mode.OWNED — Garajın alt listesi: YALNIZCA oyuncunun sahip olduğu araçlar, satın alma yok.
##   Mode.SHOP  — kataloğun tamamı + "125.000 ₺ / SATIN AL" plakası. Araç satın alma ARABA
##                GALERİSİ'ne (ShowroomScreen) taşındığı için şu anda kullanılmıyor; kip yerinde
##                duruyor ama HUD hiçbir galeriyi bu kiple açmıyor.
##
## Seçim artık dünyadaki park etmiş araçlara bağlı DEĞİLDİR (satın alınmamış araçlar dünyada
## durmaz): plakaya basılınca vehicle_selected(id) yayılır, garaj önizlemesini o sinyal sürer.
## Satın alma VehicleOwnership.purchase_vehicle üzerinden geçer (para EconomyManager'dan düşer).
##
## Küçük render'lar tembel üretilir: plaka ilk çizildiğinde kuyruğa girer, kare başına en çok
## THUMBS_PER_FRAME araç render edilir, model render sonrası serbest bırakılır. Böylece yüzlerce
## araçlık katalogda bile aynı anda yalnızca birkaç 3D instance yaşar; sonuç tüm galeriler için
## ortak önbellekte (araç id → doku) tutulur.

## Listeden bir araç seçildi (garaj önizlemesi bunu dinler).
signal vehicle_selected(vehicle_id: StringName)
## Bir araç satın alındı (plakadan).
signal vehicle_purchased(vehicle_id: StringName)

enum Mode {
	SHOP,   ## katalogdaki tüm araçlar + satın alma plakası
	OWNED,  ## yalnızca sahip olunan araçlar (garaj listesi)
}

const PLATE_WIDTH: float = 124.0
const THUMB_TOP: float = 4.0
const THUMB_SIZE: Vector2i = Vector2i(176, 110)  # render çözünürlüğü (plakada 112x70'e çizilir)
const LIFT: float = 3.0  # HudGalleryPlate basılı stilindeki expand_margin_top ile aynı
const THUMBS_PER_FRAME: int = 2   # kuyruktan bir seferde render edilen araç sayısı
const PREWARM_THUMBNAILS: int = 8  # açılışta önden üretilen ilk N araç (galeri açılınca hazır olsun)

## Araç id → küçük render (tüm galeri örnekleri paylaşır, bir kez üretilir).
static var _thumbnails: Dictionary = {}
static var _queue: Array[StringName] = []
static var _queued: Dictionary = {}          # id → true (kuyrukta ya da render ediliyor)
static var _pumping: bool = false
static var _appearance_hooked: Dictionary = {}  # scene yolu → true (changed sinyali bağlandı)

## Hangi araçlar listelenecek (ebeveyn _ready'sinde kurulur; kurulum bir kare ertelenmiştir).
var mode: Mode = Mode.SHOP

var _plates: Array[PlateButton] = []
var _columns: Array[VBoxContainer] = []
var _actions: Dictionary = {}     # id → PlateButton (yalnızca SHOP)
var _ids: Array[StringName] = []  # listelenen araçlar, sırayla
var _selected: StringName = &""
var _group: ButtonGroup = ButtonGroup.new()
var _tweens: Array[Tween] = []
var _ownership: VehicleOwnership
var _economy: EconomyManager
var _built: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", 8)
	_group.allow_unpress = false  # listede her zaman bir araç seçilidir
	_connect_managers.call_deferred()   # ebeveyn kipi kursun, yöneticiler hazır olsun


# --- Dış API ---------------------------------------------------------------------

func open() -> void:
	_rebuild_if_needed()   # plakalar ilk açılışta kurulur (açılmayan galeri hiç kurulmaz)
	_prewarm_thumbnails()
	show()
	_refresh_actions()
	_pop_in()


func close() -> void:
	_kill_tweens()
	hide()


## Listede seçili araç (yoksa boş).
func selected_vehicle() -> StringName:
	return _selected


## Verilen aracı seçer (listede yoksa hiçbir şey yapmaz).
func select(vehicle_id: StringName) -> void:
	if vehicle_id == &"" or not _ids.has(vehicle_id):
		return
	for plate: PlateButton in _plates:
		plate.set_pressed_no_signal(plate.get_meta(&"vehicle_id") == vehicle_id)
	_selected = vehicle_id
	vehicle_selected.emit(vehicle_id)


# --- Kurulum ---------------------------------------------------------------------

func _connect_managers() -> void:
	_ownership = get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	_economy = get_tree().get_first_node_in_group("economy") as EconomyManager
	if _ownership:
		_ownership.ownership_changed.connect(_on_ownership_changed)
	if _economy:
		_economy.money_changed.connect(func(_m: int) -> void: _refresh_actions())


## Kipe göre listelenecek araç kayıtları.
func _entries() -> Array[Dictionary]:
	if mode == Mode.SHOP or _ownership == null:
		return CarCatalog.all()
	var out: Array[Dictionary] = []
	for id: StringName in _ownership.owned_vehicle_ids():
		var entry: Dictionary = CarCatalog.get_entry(id)
		if not entry.is_empty():
			out.append(entry)
	return out


## Liste değiştiyse plakaları yeniden kurar (garajda araç satın alınınca yeni plaka belirir).
func _rebuild_if_needed() -> void:
	var entries: Array[Dictionary] = _entries()
	var ids: Array[StringName] = []
	for entry: Dictionary in entries:
		ids.append(entry["id"])
	if _built and ids == _ids:
		return
	_kill_tweens()
	for column: VBoxContainer in _columns:
		remove_child(column)   # adlar hemen serbest kalsın: yeni sütun aynı araç adını alabilsin
		column.queue_free()
	_columns.clear()
	_plates.clear()
	_actions.clear()
	_ids = ids
	_built = true
	for entry: Dictionary in entries:
		_build_column(entry)
	# Seçili araç listeden çıktıysa ilk araca dön
	if not _ids.has(_selected):
		_selected = _ids[0] if not _ids.is_empty() else &""
	for plate: PlateButton in _plates:
		plate.set_pressed_no_signal(plate.get_meta(&"vehicle_id") == _selected)
	_refresh_actions()


func _build_column(entry: Dictionary) -> void:
	var id: StringName = entry["id"]
	var column: VBoxContainer = VBoxContainer.new()
	column.name = String(id)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	column.add_theme_constant_override(&"separation", 3)

	var plate: PlateButton = PlateButton.new()
	plate.name = "Plate"
	plate.text = CarCatalog.label(entry)
	plate.kind = HudIcon.Kind.NONE
	plate.bolts = false  # cıvatalar ve park yeri burada çizilir
	plate.lift_when_pressed = LIFT
	plate.toggle_mode = true
	plate.button_group = _group
	plate.theme_type_variation = &"HudGalleryPlate"
	plate.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	plate.focus_mode = Control.FOCUS_NONE
	plate.set_meta(&"vehicle_id", id)
	plate.draw.connect(_draw_preview.bind(plate, entry))
	plate.toggled.connect(_on_plate_toggled.bind(id))
	column.add_child(plate)

	if mode == Mode.SHOP:
		# YIL · DURUM — katalogdaki mevcut veriler (yeni metadata yok). Garaj kipinde eklenmez:
		# orada yıl/durum zaten sol bilgi plakalarında yazar, alt liste eskisi gibi yalnız plakadır.
		var caption: Label = Label.new()
		caption.name = "Caption"
		caption.theme_type_variation = &"HudOutlined"   # dünya üstünde okunsun diye konturlu
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.text = "%d · %%%d" % [int(entry["year"]), roundi(float(entry["condition"]) * 100.0)]
		column.add_child(caption)

		var action: PlateButton = PlateButton.new()
		action.name = "Action"
		action.theme_type_variation = &"HudPlateSmall"
		action.kind = HudIcon.Kind.NONE
		action.bolts = false
		action.focus_mode = Control.FOCUS_NONE
		action.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
		action.pressed.connect(_on_buy_pressed.bind(id))
		column.add_child(action)
		_actions[id] = action

	add_child(column)
	_columns.append(column)
	_plates.append(plate)


## Plakalar sırayla küçükten yerine oturur.
func _pop_in() -> void:
	await get_tree().process_frame  # container ölçüleri hesaplansın
	if not visible:
		return
	_kill_tweens()
	for i: int in _columns.size():
		var column: VBoxContainer = _columns[i]
		column.pivot_offset = column.size * 0.5
		column.scale = Vector2(0.7, 0.7)
		column.modulate.a = 0.0
		var tween: Tween = create_tween().set_parallel(true)
		tween.tween_property(column, "scale", Vector2.ONE, 0.2) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(i * 0.04)
		tween.tween_property(column, "modulate:a", 1.0, 0.12).set_delay(i * 0.04)
		_tweens.append(tween)


func _kill_tweens() -> void:
	for tween: Tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()
	for column: VBoxContainer in _columns:
		if is_instance_valid(column):
			column.scale = Vector2.ONE
			column.modulate.a = 1.0


# --- Seçim ve satın alma ---------------------------------------------------------

func _on_plate_toggled(pressed: bool, vehicle_id: StringName) -> void:
	if not pressed:
		return
	_selected = vehicle_id
	vehicle_selected.emit(vehicle_id)


func _on_buy_pressed(vehicle_id: StringName) -> void:
	if _ownership == null:
		return
	if _ownership.purchase_vehicle(vehicle_id):   # bakiye yetmezse hiçbir şey değişmez
		vehicle_purchased.emit(vehicle_id)
	_refresh_actions()


func _on_ownership_changed() -> void:
	if not _built:
		return   # hiç açılmamış galeri kurulmaz; açıldığında güncel listeyle kurulur
	_rebuild_if_needed()   # OWNED kipinde yeni araç listeye girer
	_refresh_actions()


## Satın alma plakalarını sahiplik ve bakiyeye göre yazar (SHOP kipi).
func _refresh_actions() -> void:
	for id: StringName in _actions:
		var action: PlateButton = _actions[id]
		if not is_instance_valid(action):
			continue
		if _ownership == null:
			# Sahnede sahiplik yok (ör. HUD önizleme sahnesi): yalnızca fiyat, satın alma kapalı
			action.text = "%s ₺" % Hud.format_thousands(int(CarCatalog.get_entry(id).get("price", 0)))
			action.disabled = true
			continue
		match _ownership.status(id):
			VehicleOwnership.Status.OWNED:
				action.text = "SAHİPSİN"
				action.disabled = true
			VehicleOwnership.Status.TOO_EXPENSIVE:
				action.text = "%s ₺\nPARA YETERSİZ" % Hud.format_thousands(_ownership.price(id))
				action.disabled = true
			_:
				action.text = "%s ₺\nSATIN AL" % Hud.format_thousands(_ownership.price(id))
				action.disabled = false


# --- Küçük render'lar ------------------------------------------------------------

## Açılışta ilk birkaç aracı önden üretir; gerisi plaka ilk çizildiğinde kuyruğa girer.
func _prewarm_thumbnails() -> void:
	if DisplayServer.get_name() == "headless":
		return
	for i: int in mini(PREWARM_THUMBNAILS, _ids.size()):
		_request_thumbnail(_ids[i])


## Aracı render kuyruğuna alır (zaten varsa / kuyruktaysa hiçbir şey yapmaz) ve kuyruğu çalıştırır.
func _request_thumbnail(id: StringName) -> void:
	if _thumbnails.has(id) or _queued.has(id) or DisplayServer.get_name() == "headless":
		return
	_queued[id] = true
	_queue.append(id)
	if not _pumping:
		_pumping = true
		_pump_queue.call_deferred()


## Kuyruğu boşalana kadar kare başına THUMBS_PER_FRAME araç render eder.
func _pump_queue() -> void:
	# Kuyruk kare sonundaki ertelenmiş çağrıdan başlar; ilk render'ı bir sonraki kareye bırak ki
	# yeni eklenen node'ların dönüşümleri (ör. wrapper .tscn kök ölçeği) sunucuya işlenmiş olsun.
	await get_tree().process_frame
	while not _queue.is_empty():
		if not is_inside_tree():
			_pumping = false  # başka bir galeri örneği bir sonraki istekte devralır
			return
		var batch: Array[StringName] = []
		while batch.size() < THUMBS_PER_FRAME and not _queue.is_empty():
			batch.append(_queue.pop_front())
		await _render_thumbnails(batch)
		for id: StringName in batch:
			_queued.erase(id)
	_pumping = false


## Verilen araçlar için geçici birer SubViewport kurar, bir kare render edip görüntüyü önbelleğe
## alır; model ve viewport ardından serbest bırakılır.
func _render_thumbnails(ids: Array[StringName]) -> void:
	var jobs: Array[Dictionary] = []
	var dir: Vector3 = Vector3(0.6408563, 0.42261827, 0.6408563)  # dünya kamerasıyla aynı açı
	for id: StringName in ids:
		var entry: Dictionary = CarCatalog.get_entry(id)
		if entry.is_empty():
			continue
		var scene_path: String = entry["scene_path"]
		var scene: PackedScene = load(scene_path)
		if scene == null:
			push_warning("CarGallery: '%s' sahnesi yüklenemedi (%s)" % [id, scene_path])
			continue
		var viewport: SubViewport = SubViewport.new()
		viewport.size = THUMB_SIZE
		viewport.transparent_bg = true
		viewport.own_world_3d = true
		viewport.msaa_3d = Viewport.MSAA_4X
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED  # kurulum bitince tek kare

		var camera: Camera3D = Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		var env: Environment = Environment.new()
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("D8CFBD")
		env.ambient_light_energy = 0.5
		camera.environment = env
		viewport.add_child(camera)

		var light: DirectionalLight3D = DirectionalLight3D.new()
		light.basis = Basis.looking_at(Vector3(-0.45, -1.0, -0.6).normalized(), Vector3.UP)
		light.light_color = Color("FFF3E0")
		light.light_energy = 1.05
		viewport.add_child(light)

		var car: Node3D = scene.instantiate() as Node3D
		viewport.add_child(car)
		add_child(viewport)
		# Thumbnail de aynı görünüm verisini kullanır; değişince bu araç yeniden render edilir
		var appearance: CarAppearance = CarAppearance.get_for(scene_path)
		CarRig.new(car).apply(appearance)
		if not _appearance_hooked.has(scene_path):
			_appearance_hooked[scene_path] = true
			appearance.changed.connect(_on_appearance_changed.bind(id))
		# Her araç kendi boyutuna göre kadrajlanır (küçük modeller de plakayı doldurur)
		var bounds: AABB = _model_bounds(car)
		var target: Vector3 = bounds.get_center()
		camera.size = maxf(maxf(bounds.size.x, bounds.size.z), 0.2) * 0.82
		camera.position = target + dir * 6.0
		camera.basis = Basis.looking_at(-dir, Vector3.UP)
		# Ertelenmiş çağrıdan (kare sonu) geliyor olabiliriz: kamera dönüşümünü hemen sunucuya gönder,
		# sonra tek karelik render'ı aç; yoksa ilk çizim eski (birim) kamera dönüşümüyle yapılabilir.
		camera.force_update_transform()
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		jobs.append({"id": id, "viewport": viewport})

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	for job: Dictionary in jobs:
		var viewport: SubViewport = job["viewport"]
		if not is_instance_valid(viewport):
			continue
		var image: Image = viewport.get_texture().get_image()
		if image and not image.is_empty():
			_thumbnails[job["id"]] = ImageTexture.create_from_image(image)
		viewport.queue_free()
	if is_inside_tree():
		for plate: PlateButton in _plates:
			plate.queue_redraw()


func _on_appearance_changed(id: StringName) -> void:
	if not is_inside_tree():
		return
	_thumbnails.erase(id)
	_request_thumbnail(id)


## Modelin tüm MeshInstance3D'lerini kapsayan kutu — viewport dünya uzayında
## (araç orijinde; .tscn köküne gömülü ölçekler de hesaba katılmış olur).
func _model_bounds(car: Node3D) -> AABB:
	var merged: AABB = AABB()
	var first: bool = true
	var stack: Array[Node] = [car]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mesh_node: MeshInstance3D = node
			var world_box: AABB = mesh_node.global_transform * mesh_node.get_aabb()
			merged = world_box if first else merged.merge(world_box)
			first = false
		for child: Node in node.get_children():
			stack.append(child)
	return merged if not first else AABB(Vector3(-0.5, 0.0, -0.5), Vector3.ONE)


# --- Çizim: cıvatalar + zemin gölgesi + araç render'ı -----------------------------

func _draw_preview(plate: PlateButton, entry: Dictionary) -> void:
	var lift: float = LIFT if plate.button_pressed else 0.0
	var ink: Color = plate.get_theme_color(&"font_color")
	var w: float = plate.size.x

	var bolt: Color = Color(ink, 0.45)
	plate.draw_circle(Vector2(7.0, 7.0 - lift), 1.7, bolt, true, -1.0, true)
	plate.draw_circle(Vector2(w - 7.0, 7.0 - lift), 1.7, bolt, true, -1.0, true)

	var area: Rect2 = Rect2(6.0, THUMB_TOP - lift, w - 12.0, (w - 12.0) * THUMB_SIZE.y / THUMB_SIZE.x)

	# Aracın altında basık zemin gölgesi
	var shadow_center: Vector2 = Vector2(area.get_center().x, area.end.y - 12.0)
	plate.draw_set_transform(shadow_center, 0.0, Vector2(1.0, 0.28))
	plate.draw_circle(Vector2.ZERO, area.size.x * 0.36, Color(ink, 0.2), true, -1.0, true)
	plate.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var id: StringName = entry["id"]
	var thumbnail: Texture2D = _thumbnails.get(id)
	if thumbnail:
		plate.draw_texture_rect(thumbnail, area, false)
	else:
		# Render henüz yoksa (veya headless) araç silueti; görünür plaka render'ını ister
		HudIcon.draw_icon(plate, HudIcon.Kind.CAR, area.get_center(), 40.0, entry["plate_color"], Color(0.0, 0.0, 0.0, 0.0))
		_request_thumbnail(id)
