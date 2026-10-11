class_name MapScreen
extends Control
## HARİTA — mekânlar arası ulaşım (docs/HURDALIK_TASARIM.md §1). UiRouter'da PLACE.
## Görsel Blender'da render edilir (tools/world/map_render.py → assets/ui/map/world_map.png); mekân
## simgeleri ve rota burada KODLA çizilir, konumları aynı betiğin yazdığı world_map.json'dan gelir
## (görsel yeniden render edilince konumlar da güncellenir).
##
## Akış: mekâna dokun → rota animasyonu + "YOL TARİFİ HESAPLANIYOR" kartı (orijinaldeki "Calculating
## Route!") → travel_requested. Kart, hedef mekânın yüklenme takılmasını da örter.
## Harita 16:9'dur; başka oranlı ekranda kenarlardan kırpılır (simgeler ortaya yakın, kırpılmaz).

signal closed
## Yolculuk başladı: hedef mekânın varlıkları arka planda yüklenmeye başlasın (varışta takılma olmasın).
signal travel_started(place: StringName)
## Yolculuk bitti: hedef mekân açılsın. &"city" → şehre dönüş, &"junkyard" → hurdalık.
signal travel_requested(place: StringName)

const MAP_TEXTURE: String = "res://assets/ui/map/world_map.png"
const MAP_DATA: String = "res://assets/ui/map/world_map.json"
const TRAVEL_TIME: float = 1.6
const ROUTE_COLOR: Color = Color("F5BE4C")
const ROUTE_EDGE: Color = Color("8A5420")

var current: StringName = &"city"
var _board: Control
var _route_layer: RouteLayer
var _pins: Dictionary = {}       # place → PlateButton
var _hints: Dictionary = {}      # place → Label (kilit / "BURADASIN")
var _places: Dictionary = {}     # place → Vector2 (0..1)
var _route: PackedVector2Array = PackedVector2Array()
var _card: PlatePanel
var _card_label: Label
var _travelling: bool = false


func _ready() -> void:
	name = "MapScreen"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_load_data()
	_build()


func open() -> void:
	_travelling = false
	_card.hide()
	_route_layer.progress = 0.0
	_route_layer.reverse = false
	_refresh()
	show()


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
	var sea: ColorRect = ColorRect.new()   # kırpılan kenarların arkası (haritanın deniz / gök rengi)
	sea.color = Color("BFE3F2")
	sea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sea.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sea)
	var aspect: AspectRatioContainer = AspectRatioContainer.new()
	aspect.ratio = 16.0 / 9.0
	aspect.stretch_mode = AspectRatioContainer.STRETCH_COVER
	aspect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aspect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(aspect)
	_board = Control.new()
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aspect.add_child(_board)
	var image: TextureRect = TextureRect.new()
	image.texture = load(MAP_TEXTURE) as Texture2D
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board.add_child(image)
	_route_layer = RouteLayer.new()
	_route_layer.points = _route
	_route_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board.add_child(_route_layer)
	_add_pin(&"city", Loc.t("ŞEHİR"), HudIcon.Kind.GARAGE)
	_add_pin(&"junkyard", Loc.t("HURDALIK"), HudIcon.Kind.WRENCH)

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


func _refresh() -> void:
	var open_yard: bool = _yard_open()
	for place: StringName in _pins:
		var button: PlateButton = _pins[place]
		var hint: Label = _hints[place]
		button.highlight = place == current
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
	if place == current:
		close()
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


## Rota: kesik çizgili sarı yol + üstünde ilerleyen araç işareti. Noktalar haritaya oranlı (0..1).
class RouteLayer:
	extends Control

	var points: PackedVector2Array = PackedVector2Array()
	var reverse: bool = false
	var progress: float = 0.0:
		set(value):
			progress = value
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

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
		var head: Vector2 = route["head"]
		draw_circle(head, width * 2.6, Color("2F3236"), true, -1.0, true)
		draw_circle(head, width * 1.9, Color("F5BE4C"), true, -1.0, true)
