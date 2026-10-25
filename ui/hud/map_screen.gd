class_name MapScreen
extends Control
## HARİTA — mekânlar arası ulaşım (docs/HURDALIK_TASARIM.md §1). UiRouter'da PLACE.
## Görsel Blender'da render edilir (tools/world/map_render.py → assets/ui/map/world_map.png); mekân
## simgeleri ve rota burada KODLA çizilir, konumları aynı betiğin yazdığı world_map.json'dan gelir
## (görsel yeniden render edilince konumlar da güncellenir).
##
## Akış: mekâna dokun → rota animasyonu + "YOL TARİFİ HESAPLANIYOR" kartı (orijinaldeki "Calculating
## Route!") → travel_requested. Kart, hedef mekânın yüklenme takılmasını da örter.
## Harita 16:9'dur; başka oranlı ekranda kenarlardan kırpılır (ekranı kaplar). Kırpma mekân simgelerini
## ekran dışına itecekse (4:3 tablet, katlanabilir iç ekran: HURDALIK simgesi sol kenarın dışındaydı) harita
## simgeler sığana kadar küçülür; altta açılan bandı deniz rengi doldurur (bkz. _layout_board).
## YAKINDA mekânları (SOON: OTO ŞOV, LİMAN — 2026-10-23): görselde gri maket, simgesi gri ve altında YAKINDA;
## dokununca yalnız "yakında açılıyor" kartı çıkar, yolculuk yok.
## DRAG PİSTİ (2026-10-26, docs/LIDER_TABLOSU.md): şehrin kuzeybatısındaki pist; dokununca HAFTALIK DRAG TABLOSU açılır
## (leaderboard_requested, yolculuk yok). Altında oyuncunun bu haftaki sırası (yarış aracının sınıfında) ya da
## "HAFTALIK TABLO".

signal closed
## Yolculuk başladı: hedef mekânın varlıkları arka planda yüklenmeye başlasın (varışta takılma olmasın).
signal travel_started(place: StringName)
## Yolculuk bitti: hedef mekân açılsın. &"city" → şehre dönüş, &"junkyard" → hurdalık.
signal travel_requested(place: StringName)
## DRAG PİSTİ simgesine dokunuldu: haftalık drag tablosu açılsın.
signal leaderboard_requested

const MAP_TEXTURE: String = "res://assets/ui/map/world_map.png"
const MAP_DATA: String = "res://assets/ui/map/world_map.json"
const TRAVEL_TIME: float = 1.6
const ROUTE_COLOR: Color = Color("F5BE4C")
const ROUTE_EDGE: Color = Color("8A5420")
const TRAVELLER_VIEW_SIZE: Vector2i = Vector2i(192, 192)
## Harita render kamerasının dikeyden eğimi (tools/world/map_render.py camera_light, "tilt"). Yolculuk
## aracı aynı açıdan görülür: yatay yolda yandan, dikey yolda önden / arkadan; harita gibi diorama durur.
const MAP_TILT_DEG: float = 50.0
## Harita görselinin en/boy oranı (world_map.png 1920×1080).
const MAP_ASPECT: float = 16.0 / 9.0
## Mekân simgesinin ekran kenarına bıraktığı en az pay.
const PIN_EDGE: float = 10.0
## Henüz açılmayan mekânlar (haritada görünür, gidilmez).
const SOON: Array[StringName] = [&"meet", &"port"]
const SOON_TINT: Color = Color(0.72, 0.72, 0.74, 0.95)
## Yolculuğu olmayan, tablo açan nokta.
const DRAG: StringName = &"drag"

var current: StringName = &"city"
## Haritanın kendisi (16:9). Kaplama ölçeğiyle ortalanır; simgeler sığmıyorsa küçülür (_layout_board).
var _board: Control
## Harita resmi İLK AÇILIŞTA yüklenir: 1920×1080 kayıpsız, 8 MB VRAM ve açılışta ~40 ms (masaüstü). Haritayı
## yalnızca hurdalık görevine gelen oyuncu görür; eskiden her açılışta kuruluyordu.
var _map_image: TextureRect
var _route_layer: RouteLayer
var _pins: Dictionary = {}       # place → PlateButton
var _hints: Dictionary = {}      # place → Label (kilit / "BURADASIN")
var _places: Dictionary = {}     # place → Vector2 (0..1)
var _route: PackedVector2Array = PackedVector2Array()
var _card: PlatePanel
var _card_label: Label
var _travelling: bool = false
var _traveller_marker: Control
var _traveller_texture: TextureRect
var _traveller_viewport: SubViewport
var _traveller_stage: Node3D
var _traveller_car: Node3D
var _traveller_pivot: Node3D     # araç bunun altında, kasa ortası pivotta: dönünce kadrajdan kaymaz
var _traveller_yaw: float = INF  # son render edilen açı (INF: henüz render yok)
var _traveller_vehicle_id: StringName = &""


func _ready() -> void:
	name = "MapScreen"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_load_data()
	_build()


func open() -> void:
	if _map_image.texture == null:
		_map_image.texture = load(MAP_TEXTURE) as Texture2D
	_travelling = false
	_card.hide()
	_route_layer.progress = 0.0
	_route_layer.reverse = false
	_prepare_traveller()
	_refresh()
	show()
	_layout_board.call_deferred()   # durum satırları (ölçü) yeni yazıldı


func close() -> void:
	if not visible:
		return
	hide()
	closed.emit()


# --- Kurulum -----------------------------------------------------------------------

func _load_data() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MAP_DATA))
	if not (data is Dictionary):
		push_error("MapScreen: %s okunamadı" % MAP_DATA)
		return
	var places: Dictionary = (data as Dictionary).get("places", {})
	for key: String in places:
		var p: Array = places[key]
		_places[StringName(key)] = Vector2(float(p[0]), float(p[1]))
	for p: Variant in (data as Dictionary).get("route", []):
		_route.append(Vector2(float(p[0]), float(p[1])))


func _build() -> void:
	var sea: ColorRect = ColorRect.new()   # küçülen haritanın altında açılan bant: görselin alt kenarındaki deniz
	sea.color = Color("71ADC8")
	sea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sea.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sea)
	_board = Control.new()
	_board.name = "Board"
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_board)
	resized.connect(_layout_board)
	var image: TextureRect = TextureRect.new()
	_map_image = image
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board.add_child(image)
	_route_layer = RouteLayer.new()
	_route_layer.points = _route
	_route_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board.add_child(_route_layer)
	_build_traveller()
	_add_pin(&"city", Loc.t("ŞEHİR"), HudIcon.Kind.GARAGE)
	_add_pin(&"junkyard", Loc.t("HURDALIK"), HudIcon.Kind.WRENCH)
	_add_pin(&"meet", Loc.t("OTO ŞOV"), HudIcon.Kind.FRIENDS)
	_add_pin(&"port", Loc.t("LİMAN"), HudIcon.Kind.BOX)
	_add_pin(DRAG, Loc.t("DRAG PİSTİ"), HudIcon.Kind.FLAG)

	var top: MarginContainer = _margin(14, 12, 14, 0)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(top)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(row)
	var sign: PlatePanel = PlatePanel.new()
	sign.theme_type_variation = &"HudCarPlate"
	sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title_box: VBoxContainer = VBoxContainer.new()
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_box.add_theme_constant_override(&"separation", 0)
	title_box.add_child(_label(&"HudSignTitle", Loc.t("HARİTA")))
	title_box.add_child(_label(&"HudInkCaption", Loc.t("Gitmek istediğin yere dokun")))
	sign.add_child(title_box)
	row.add_child(sign)
	var spacer: Control = Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var close_button: PlateButton = PlateButton.new()
	close_button.theme_type_variation = &"HudPlateSmall"
	close_button.text = Loc.t("KAPAT")
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_button.pressed.connect(func() -> void:
		if not _travelling:
			close())
	row.add_child(close_button)

	var bottom: MarginContainer = _margin(0, 0, 0, 26)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(bottom)
	_card = PlatePanel.new()
	_card.theme_type_variation = &"HudCarPlate"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.visible = false
	var inner: MarginContainer = _margin(22, 8, 22, 8)
	_card_label = _label(&"HudInkValue", "")
	_card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(_card_label)
	_card.add_child(inner)
	bottom.add_child(_card)


## Mekân simgesi: plaka düğme noktanın ÜSTÜNDE durur (alt ortası noktada), altında durum satırı.
func _add_pin(place: StringName, title: String, icon: HudIcon.Kind) -> void:
	if not _places.has(place):
		return
	var at: Vector2 = _places[place]
	var pin: VBoxContainer = VBoxContainer.new()
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pin.add_theme_constant_override(&"separation", 2)
	pin.anchor_left = at.x
	pin.anchor_right = at.x
	pin.anchor_top = at.y
	pin.anchor_bottom = at.y
	pin.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var button: PlateButton = PlateButton.new()
	button.theme_type_variation = &"HudPlate"
	button.kind = icon
	button.text = title
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(_on_pin.bind(place))
	pin.add_child(button)
	var hint: Label = _label(&"HudInkCaption", "")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override(&"font_color", HudPalette.TEXT_LIGHT)
	hint.add_theme_color_override(&"font_outline_color", HudPalette.TEXT_OUTLINE)
	hint.add_theme_constant_override(&"outline_size", 6)
	pin.add_child(hint)
	_board.add_child(pin)
	_pins[place] = button
	_hints[place] = hint


## Harita ekranı KAPLAR (kenarlardan kırpılır); kırpma bir mekân simgesini (plaka + durum satırı) ekran
## dışına itecekse harita, simgelerin hepsi kenar payıyla sığana kadar küçülür (en çok ekrana sığacak kadar).
func _layout_board() -> void:
	var view: Vector2 = size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	var cover: float = maxf(view.x / MAP_ASPECT, view.y)   # harita yüksekliği
	var contain: float = minf(view.x / MAP_ASPECT, view.y)
	var height: float = cover
	for place: StringName in _pins:
		var at: Vector2 = _places[place]
		var half: float = (_pins[place] as Control).get_parent().get_combined_minimum_size().x * 0.5 + PIN_EDGE
		var offset: float = absf(at.x - 0.5)   # merkezden uzaklık (harita genişliği oranı)
		if offset > 0.001:
			# simge merkezi kadraj ortasından offset·genişlik uzakta: kenar payıyla sığmalı
			height = minf(height, (view.x * 0.5 - half) / (offset * MAP_ASPECT))
	height = clampf(height, contain, cover)
	var board: Vector2 = Vector2(height * MAP_ASPECT, height)
	# Yatayda ortalı; küçülünce ÜSTE yaslanır: açılan bant altta kalır ve görselin alt kenarındaki denizle
	# (düz renk 71ADC8) birleşir — ortalanınca üstte kumun üstünde gök mavisi bir şerit kalıyordu.
	_board.position = Vector2((view.x - board.x) * 0.5, minf((view.y - board.y) * 0.5, 0.0)).round()
	_board.size = board.round()


func _refresh() -> void:
	var open_yard: bool = _yard_open()
	for place: StringName in _pins:
		var button: PlateButton = _pins[place]
		var hint: Label = _hints[place]
		button.highlight = place == current
		if SOON.has(place):
			hint.text = Loc.t("YAKINDA")
			button.modulate = SOON_TINT
			continue
		if place == DRAG:
			hint.text = Loc.t("HAFTALIK TABLO")
			_refresh_drag_rank()
			continue
		if place == current:
			hint.text = Loc.t("BURADASIN")
		elif place == &"junkyard" and not open_yard:
			hint.text = Loc.t("2. TAMİR ALANINI AÇ")
		else:
			hint.text = Loc.t("GİT")
		button.modulate = Color(1, 1, 1, 0.75) if place == &"junkyard" and not open_yard else Color.WHITE


# --- Yolculuk ------------------------------------------------------------------------

func _on_pin(place: StringName) -> void:
	if _travelling:
		return
	if place == DRAG:
		leaderboard_requested.emit()
		return
	if place == current:
		close()
		return
	if SOON.has(place):
		_flash_card(Loc.t("%s YAKINDA AÇILIYOR") % (_pins[place] as PlateButton).text)
		return
	if place == &"junkyard" and not _yard_open():
		_flash_card(Loc.t("HURDALIK, 2. TAMİR ALANINI AÇINCA YOLA ÇIKAR"))
		return
	_travelling = true
	_route_layer.reverse = place == &"city"   # rota şehirden hurdalığa kayıtlı
	_route_layer.progress = 0.0
	_card_label.text = Loc.t("YOL TARİFİ HESAPLANIYOR")
	_card.show()
	travel_started.emit(place)
	var tween: Tween = create_tween()
	tween.tween_property(_route_layer, "progress", 1.0, TRAVEL_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_callback(func() -> void:
		_card_label.text = Loc.t("HURDALIĞA GİDİLİYOR") if place == &"junkyard" else Loc.t("ŞEHRE DÖNÜLÜYOR")).set_delay(TRAVEL_TIME * 0.45)
	tween.tween_interval(0.15)
	tween.tween_callback(func() -> void:
		_travelling = false
		travel_requested.emit(place))


## DRAG PİSTİ satırı: oyuncunun bu hafta yarış aracının sınıfında bir süresi varsa tablodaki sırası ("SEN 41.").
## Özet ağdan gelir (önbellekte varsa hemen); gelmezse "HAFTALIK TABLO" kalır.
func _refresh_drag_rank() -> void:
	var board: Leaderboard = get_tree().get_first_node_in_group("leaderboard") as Leaderboard
	var ownership: VehicleOwnership = get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	if board == null or ownership == null or not _hints.has(DRAG):
		return
	var cls: StringName = Leaderboard.class_of(ownership.race_vehicle_id())
	var wk: int = Leaderboard.current_week()
	var best: float = board.my_best(wk, cls)
	if cls == &"" or best <= 0.0:
		return
	var summary: Dictionary = await board.summary(wk, cls)
	if summary.is_empty():
		return   # ağ yok / tablo boş: "1." yazmasın
	var rank: Dictionary = Leaderboard.rank_in(summary, best)
	if not rank.is_empty():   # önbellekten gelirse open() daha show() demeden yazılır
		(_hints[DRAG] as Label).text = Loc.t("%s SINIFI · SEN %d.") % [cls, int(rank["rank"])]


func _flash_card(text: String) -> void:
	_card_label.text = text
	_card.show()
	var tween: Tween = create_tween()
	tween.tween_interval(2.0)
	tween.tween_callback(func() -> void:
		if not _travelling:
			_card.hide())


func _yard_open() -> bool:
	var jy: JunkyardManager = get_tree().get_first_node_in_group("junkyard") as JunkyardManager
	return jy != null and jy.is_open()


## Rota ucundaki arac, oyuncunun garajda sectigi yaris aracinin gercek modelidir.
## Ayri viewport, harita dunyasinin 3B kamera ve isiklariyla paylasim yapmaz.
func _build_traveller() -> void:
	_traveller_marker = Control.new()
	_traveller_marker.name = "TravelCar"
	_traveller_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_traveller_marker.visible = false
	_board.add_child(_traveller_marker)
	_route_layer.traveller = _traveller_marker
	_route_layer.heading_changed.connect(_turn_traveller)

	_traveller_texture = TextureRect.new()
	_traveller_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_traveller_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_traveller_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_traveller_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_traveller_marker.add_child(_traveller_texture)

	_traveller_viewport = SubViewport.new()
	_traveller_viewport.size = TRAVELLER_VIEW_SIZE
	_traveller_viewport.transparent_bg = true
	_traveller_viewport.own_world_3d = true
	_traveller_viewport.msaa_3d = GameSettings.subviewport_msaa(Viewport.MSAA_4X)
	_traveller_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_traveller_viewport)
	_traveller_texture.texture = _traveller_viewport.get_texture()

	_traveller_stage = Node3D.new()
	_traveller_viewport.add_child(_traveller_stage)
	_traveller_pivot = Node3D.new()
	_traveller_stage.add_child(_traveller_pivot)
	# Harita kamerasının eşi: ortografik, kuzeye (-Z) bakar, yataydan (90 - eğim)° aşağı. Araç bu sabit
	# kameranın önünde DÖNER; resmi döndürmek arkadan çekilmiş aracı yan yatırıyordu.
	var camera: Camera3D = Camera3D.new()
	camera.name = "TravelCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.rotation = Vector3(-deg_to_rad(90.0 - MAP_TILT_DEG), 0.0, 0.0)
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("D7E1E7")
	environment.ambient_light_energy = 0.85
	camera.environment = environment
	_traveller_stage.add_child(camera)
	# Haritadaki güneşin yönü (map_render.py MapSun: X 48°, Z -35°, Blender → Godot eksenleri)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.basis = Basis.looking_at(Vector3(0.426, -0.669, -0.609).normalized(), Vector3.UP)
	light.light_color = Color("FFF5DB")
	light.light_energy = 1.15
	_traveller_stage.add_child(light)


func _prepare_traveller() -> void:
	var ownership: VehicleOwnership = get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	var vehicle_id: StringName = ownership.race_vehicle_id() if ownership else RaceManager.FALLBACK_VEHICLE
	if vehicle_id == &"":
		vehicle_id = RaceManager.FALLBACK_VEHICLE
	if vehicle_id == _traveller_vehicle_id and is_instance_valid(_traveller_car):
		return
	_traveller_vehicle_id = vehicle_id
	if is_instance_valid(_traveller_car):
		_traveller_car.get_parent().remove_child(_traveller_car)
		_traveller_car.queue_free()
		_traveller_car = null
	var path: String = CarCatalog.scene_path(vehicle_id)
	var scene: PackedScene = load(path) as PackedScene if path != "" else null
	if scene == null:
		push_warning("MapScreen: yolculuk araci yuklenemedi (%s)" % vehicle_id)
		return
	_traveller_car = scene.instantiate() as Node3D
	_traveller_pivot.rotation = Vector3.ZERO
	_traveller_pivot.add_child(_traveller_car)
	var rig: CarRig = CarRig.new(_traveller_car)
	rig.apply(CarAppearance.get_for(path))
	rig.set_lod_bias(CarRig.LOD_BIAS_WORLD)
	for mesh: GeometryInstance3D in _traveller_car.find_children("*", "GeometryInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bounds: AABB = _model_bounds(_traveller_car)
	var center: Vector3 = bounds.get_center()
	_traveller_car.position = Vector3(-center.x, 0.0, -center.z)
	var camera: Camera3D = _traveller_stage.get_node_or_null("TravelCamera") as Camera3D
	if camera:
		# Kadraj her açıda sığsın: ölçü taban köşegeni (araç hangi yöne dönerse dönsün en uzun boyu)
		var diagonal: float = maxf(Vector2(bounds.size.x, bounds.size.z).length(), 0.2)
		camera.size = diagonal * 1.08
		camera.position = Vector3(0.0, center.y, 0.0) + camera.basis.z * (diagonal * 4.0)
		camera.far = diagonal * 8.0
	_traveller_yaw = INF   # yeni araç: ilk yönde mutlaka render edilsin


## Rota ucunun ekrandaki yönünü aracın 3B açısına çevirir. Harita eğik bakıldığı için ekrandaki dikey
## mesafe yerde 1 / cos(eğim) kat uzundur. Model önü +Z; kamera -Z'ye baktığından ekran aşağısı +Z.
## Viewport yalnızca açı değişince bir kez çizilir (yolculuk boyunca ~birkaç düzine kare, 192 px).
func _turn_traveller(direction: Vector2) -> void:
	if not is_instance_valid(_traveller_car):
		return
	var ground: Vector2 = Vector2(direction.x, direction.y / cos(deg_to_rad(MAP_TILT_DEG)))
	var yaw: float = atan2(ground.x, ground.y)
	if is_finite(_traveller_yaw) and absf(angle_difference(_traveller_yaw, yaw)) < deg_to_rad(1.0):
		return
	_traveller_yaw = yaw
	_traveller_pivot.rotation.y = yaw
	_traveller_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _model_bounds(car: Node3D) -> AABB:
	var merged: AABB = AABB()
	var first: bool = true
	var stack: Array[Node] = [car]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mesh: MeshInstance3D = node
			var box: AABB = mesh.global_transform * mesh.get_aabb()
			merged = box if first else merged.merge(box)
			first = false
		for child: Node in node.get_children():
			stack.append(child)
	return merged if not first else AABB(Vector3(-0.5, 0.0, -0.5), Vector3.ONE)


# --- Yardımcılar ----------------------------------------------------------------------

func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override(&"margin_left", left)
	margin.add_theme_constant_override(&"margin_top", top)
	margin.add_theme_constant_override(&"margin_right", right)
	margin.add_theme_constant_override(&"margin_bottom", bottom)
	return margin


## Rotanın `progress` (0..1) kadarlık kesik çizgileri: {"spans": [p0, p1, p0, p1, ...], "head": uç nokta}.
## Çizgiler yolun BAŞINDAN ölçülen uzunluğa göre dizilir (animasyonda kaymaz). Adımlar TAMSAYI çizgi
## indeksiyle atılır: eskiden kalan uzunluk fmod ile hesaplanıyordu, kayan nokta hatası adımı sıfıra
## yaklaştırınca döngü bitmiyor, oyun yolculuğun ortasında donuyordu (2026-10-11, kullanıcı bildirdi).
static func dashes(path: PackedVector2Array, progress: float, dash: float) -> Dictionary:
	var spans: PackedVector2Array = PackedVector2Array()
	if path.size() < 2 or dash <= 0.0:
		return {"spans": spans, "head": path[0] if path.size() > 0 else Vector2.ZERO}
	var total: float = 0.0
	for i: int in path.size() - 1:
		total += path[i].distance_to(path[i + 1])
	var limit: float = total * clampf(progress, 0.0, 1.0)
	var walked: float = 0.0
	var head: Vector2 = path[0]
	for i: int in path.size() - 1:
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var seg: float = a.distance_to(b)
		if seg <= 0.0:
			continue
		var end: float = minf(walked + seg, limit)
		# Bu parçaya düşen çizgiler: k. çizgi [k·dash, (k+1)·dash) aralığı, çift k çizili
		var first: int = floori(walked / dash)
		var last: int = floori(end / dash)
		for k: int in range(first, last + 1):
			if k % 2 != 0:
				continue
			var s0: float = maxf(float(k) * dash, walked)
			var s1: float = minf(float(k + 1) * dash, end)
			if s1 > s0:
				spans.append(a.lerp(b, (s0 - walked) / seg))
				spans.append(a.lerp(b, (s1 - walked) / seg))
		head = a.lerp(b, (end - walked) / seg)
		walked += seg
		if walked >= limit:
			break
	return {"spans": spans, "head": head}


## Rota ucunun konumu ve aracın baktığı yön. Kesik çizgiden ayrı tutulur ki araç,
## çizgilerin boşluklarında da kesintisiz ve doğru açıyla ilerlesin. Yön, ucun biraz gerisi ile biraz
## ilerisi arasından ölçülür: rota kırık çizgi olduğundan parça yönü köşelerde araç birden dönüyordu.
static func route_pose(path: PackedVector2Array, progress: float) -> Dictionary:
	if path.is_empty():
		return {"head": Vector2.ZERO, "direction": Vector2.UP}
	if path.size() == 1:
		return {"head": path[0], "direction": Vector2.UP}
	var total: float = 0.0
	for i: int in path.size() - 1:
		total += path[i].distance_to(path[i + 1])
	var limit: float = total * clampf(progress, 0.0, 1.0)
	var window: float = total * 0.03
	var head: Vector2 = _route_point(path, limit)
	var direction: Vector2 = _route_point(path, minf(limit + window, total)) \
		- _route_point(path, maxf(limit - window, 0.0))
	if direction.length() <= 0.0:
		direction = path[path.size() - 1] - path[0]
	return {"head": head, "direction": direction.normalized() if direction.length() > 0.0 else Vector2.UP}


## Rota başından `distance` uzunluk ilerideki nokta (uçlarda kırpılır).
static func _route_point(path: PackedVector2Array, distance: float) -> Vector2:
	var walked: float = 0.0
	for i: int in path.size() - 1:
		var segment: float = path[i].distance_to(path[i + 1])
		if segment > 0.0 and walked + segment >= distance:
			return path[i].lerp(path[i + 1], clampf((distance - walked) / segment, 0.0, 1.0))
		walked += segment
	return path[path.size() - 1]


## Rota: kesik çizgili sarı yol + üstünde ilerleyen araç işareti. Noktalar haritaya oranlı (0..1).
class RouteLayer:
	extends Control

	## Araç işaretinin ekrandaki gidiş yönü (birim vektör); MapScreen 3B aracı buna göre döndürür.
	signal heading_changed(direction: Vector2)

	var points: PackedVector2Array = PackedVector2Array()
	var reverse: bool = false
	var traveller: Control
	var progress: float = 0.0:
		set(value):
			progress = value
			_update_traveller()
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(_update_traveller)

	func _update_traveller() -> void:
		if traveller == null:
			return
		traveller.visible = progress > 0.0 and points.size() >= 2
		if not traveller.visible or size.x <= 0.0 or size.y <= 0.0:
			return
		var path: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in points:
			path.append(point * size)
		if reverse:
			path.reverse()
		var pose: Dictionary = MapScreen.route_pose(path, progress)
		var marker_size: float = clampf(size.x * 0.06, 44.0, 72.0)
		traveller.size = Vector2.ONE * marker_size
		traveller.position = (pose["head"] as Vector2) - traveller.size * 0.5
		heading_changed.emit(pose["direction"] as Vector2)

	func _draw() -> void:
		if points.size() < 2 or progress <= 0.0:
			return
		var path: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in points:
			path.append(p * size)
		if reverse:
			path.reverse()
		var width: float = maxf(size.x * 0.005, 3.0)
		var route: Dictionary = MapScreen.dashes(path, progress, maxf(size.x * 0.012, 6.0))
		var spans: PackedVector2Array = route["spans"]
		for k: int in range(0, spans.size(), 2):
			draw_line(spans[k], spans[k + 1], Color("8A5420"), width + 3.0, true)
			draw_line(spans[k], spans[k + 1], Color("F5BE4C"), width, true)
