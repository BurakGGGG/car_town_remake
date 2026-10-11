class_name JunkyardScreen
extends Control
## HURDALIK EKRANI — UiRouter'da PLACE. Hurdalık ayrı bir haritadır (docs/HURDALIK_TASARIM.md): kendi
## SubViewport'unda kendi 3D dünyası (JunkyardWorld) kurulur, şehir arkada çizilmez (Hud
## WORLD_COVERING_PLACES). Ekran TAMAMEN KODLA kurulur (.tscn yok); mantık JunkyardManager'dadır.
##
## Oyuncu ne yapar:
##   * Sahada gezer: tek parmak kaydırır, iki parmak yakınlaştırır (şehir kamerasının aynısı, WorldCamera).
##   * Sarı halkalı yığına dokunur → yığın sallanır, toz kalkar (~1 sn) → bulunan parçalar PARÇALAR
##     plakasına uçar ya da "Bir şey çıkmadı". Halkası olmayan yığın boş: dolmasına kalan süre söylenir.
##   * Günün araçlarından birine dokunur → bilgi plakası (ad, yıl, sınıf, parça reçetesi) + RESTORE ET:
##     araç garajda bir tamir alanına yerleşir (JunkyardManager.start) ve sahadan kalkar.
##   * Alt plakalar: PARÇALAR (envanter), HARİTA (şehre dönüş), KOLEKSİYON, yenilenme sayacı.
##
## Dünya AÇILIŞTA kurulur, KAPANIŞTA silinir: sahne + zemin dokusu kapalı ekranda bellekte durmasın
## (telefon). Yükleme süresini HARİTA ekranının yol kartı örter.

signal closed
## HARİTA plakası: harita ekranı açılsın (şehre dönüş oradan).
signal map_requested
## KOLEKSİYON plakası.
signal collection_requested

## Sürükleme sayılmayan en büyük parmak kayması (tuval birimi): altı dokunuştur.
const TAP_SLOP: float = 12.0
const PANEL_WIDTH: float = 460.0
const ICON_SIZE: float = 40.0
const FLY_TIME: float = 0.6
const NOTICE_HOLD: float = 1.8

var _container: SubViewportContainer
var _viewport: SubViewport
var _world: JunkyardWorld
var _overlay: Control
var _parts_button: PlateButton
var _yard_label: Label
var _pile_label: Label
var _notice_plate: PlatePanel
var _notice_label: Label
var _notice_tween: Tween
var _car_layer: Control
var _car_title: Label
var _car_info: Label
var _car_recipe: HBoxContainer
var _car_hint: Label
var _car_start: PlateButton
var _parts_layer: Control
var _parts_grid: GridContainer
var _clock: Timer
var _selected_car: int = -1
var _busy_pile: int = -1
var _press_pos: Vector2 = Vector2.ZERO
var _pressed: bool = false
var _moved: bool = false
var _touches: int = 0
## Eğitim çapaları: dünyadaki yığın / aracın ekrandaki yerini izleyen görünmez Control'ler (spot ışığı
## hedefi; TutorialDirector Control hedefini her karede okur).
var _anchors: Dictionary = {}       # &"pile" | &"car" → Control
var _anchor_index: Dictionary = {}  # &"pile" | &"car" → izlenen indeks


func _ready() -> void:
	name = "JunkyardScreen"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	set_process(false)


# --- Aç / kapa ---------------------------------------------------------------------

func open() -> void:
	if _world == null:
		_world = JunkyardWorld.new()
		_viewport.add_child(_world)
		_world.camera.make_current()
	_world.set_active(true)
	_viewport.msaa_3d = GameSettings.subviewport_msaa(Viewport.MSAA_2X)
	_claim_render_target()
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_car_layer.hide()
	_parts_layer.hide()
	_notice_plate.hide()
	_busy_pile = -1
	var jy: JunkyardManager = _jy()
	if jy and not jy.yard_changed.is_connected(_refresh_yard):
		jy.yard_changed.connect(_refresh_yard)
		jy.junkyard_changed.connect(_refresh_parts_button)
	_refresh_yard()
	_refresh_parts_button()
	_tick()
	_clock.start()
	show()
	set_process(true)
	GameMusic.junkyard(get_tree(), true)


func close() -> void:
	if not visible:
		return
	_clock.stop()
	set_process(false)
	GameMusic.junkyard(get_tree(), false)
	_anchor_index.clear()
	var jy: JunkyardManager = _jy()
	if jy and jy.yard_changed.is_connected(_refresh_yard):
		jy.yard_changed.disconnect(_refresh_yard)
		jy.junkyard_changed.disconnect(_refresh_parts_button)
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_release_render_target()
	if _world:
		_world.queue_free()   # sahne + doku bellekte kalmasın
		_world = null
	hide()
	closed.emit()


## Kapsayıcı stretch açıkken görüntü alanına boyut atanamıyor (DragRaceScreen'deki açıklama): kapalıyken
## stretch kapatılır ve hedef küçültülür, açılışta geri alınır.
func _release_render_target() -> void:
	_container.stretch = false
	_viewport.size = Vector2i(4, 4)


func _claim_render_target() -> void:
	if not _container.stretch:
		_viewport.size = Vector2i(_container.size.max(Vector2.ONE))
		_container.stretch = true


func world() -> JunkyardWorld:
	return _world


# --- Kurulum -----------------------------------------------------------------------

func _build() -> void:
	_container = SubViewportContainer.new()
	_container.name = "YardView"
	_container.stretch = true
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_container)
	_viewport = SubViewport.new()
	_viewport.name = "YardViewport"
	_viewport.own_world_3d = true   # hurdalık KENDİ dünyasında: şehir buraya sızmaz
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_container.add_child(_viewport)

	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	_build_title()
	_build_bottom()
	_build_notice()
	_build_car_panel()
	_build_parts_panel()

	_clock = Timer.new()
	_clock.wait_time = 1.0
	_clock.timeout.connect(_tick)
	add_child(_clock)


func _build_title() -> void:
	var margin: MarginContainer = _margin(14, 12, 14, 0)
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_overlay.add_child(margin)
	var sign: PlatePanel = PlatePanel.new()
	sign.theme_type_variation = &"HudCarPlate"
	sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 0)
	box.add_child(_label(&"HudSignTitle", Loc.t("HURDALIK")))
	box.add_child(_label(&"HudInkCaption", Loc.t("Hurdacı Necati'nin sahası")))
	sign.add_child(box)
	margin.add_child(sign)


func _build_bottom() -> void:
	var margin: MarginContainer = _margin(12, 0, 12, 12)
	margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	margin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_overlay.add_child(margin)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 8)
	margin.add_child(row)
	_parts_button = _plate_button(Loc.t("PARÇALAR"), _toggle_parts)
	row.add_child(_parts_button)
	row.add_child(_plate_button(Loc.t("HARİTA"), func() -> void: map_requested.emit()))
	row.add_child(_plate_button(Loc.t("KOLEKSİYON"), func() -> void: collection_requested.emit()))
	var timer_plate: PlatePanel = PlatePanel.new()
	timer_plate.theme_type_variation = &"HudCarPlate"
	timer_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var timer_box: VBoxContainer = VBoxContainer.new()
	timer_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_box.add_theme_constant_override(&"separation", 0)
	_yard_label = _label(&"HudInkCaption", "")
	_pile_label = _label(&"HudInkCaption", "")
	timer_box.add_child(_yard_label)
	timer_box.add_child(_pile_label)
	timer_plate.add_child(timer_box)
	row.add_child(timer_plate)


func _build_notice() -> void:
	var margin: MarginContainer = _margin(0, 86, 0, 0)
	margin.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	margin.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_overlay.add_child(margin)
	_notice_plate = PlatePanel.new()
	_notice_plate.theme_type_variation = &"HudCarPlate"
	_notice_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice_plate.visible = false
	var inner: MarginContainer = _margin(18, 6, 18, 6)
	_notice_label = _label(&"HudInkValue", "")
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(_notice_label)
	_notice_plate.add_child(inner)
	margin.add_child(_notice_plate)


## Günün aracının bilgi plakası: ad, yıl · sınıf, parça reçetesi, RESTORE ET.
func _build_car_panel() -> void:
	_car_layer = _modal_layer()
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_car_layer.add_child(center)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 6)
	center.add_child(column)
	var plate: PlatePanel = PlatePanel.new()
	plate.theme_type_variation = &"HudCarPlate"
	plate.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	plate.mouse_filter = Control.MOUSE_FILTER_STOP
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 4)
	_car_title = _label(&"HudPlateTitle", "")
	_car_info = _label(&"HudInkCaption", "")
	box.add_child(_car_title)
	box.add_child(_car_info)
	box.add_child(_label(&"HudInkCaption", Loc.t("GEREKEN PARÇALAR")))
	_car_recipe = HBoxContainer.new()
	_car_recipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_car_recipe.add_theme_constant_override(&"separation", 10)
	box.add_child(_car_recipe)
	_car_hint = _label(&"HudInkCaption", "")
	_car_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_car_hint)
	plate.add_child(box)
	column.add_child(plate)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", 8)
	_car_start = _plate_button(Loc.t("RESTORE ET"), _start_selected, &"HudPlate")
	_car_start.custom_minimum_size = Vector2(PANEL_WIDTH * 0.5 - 4.0, 0.0)
	var cancel: PlateButton = _plate_button(Loc.t("KAPAT"), func() -> void: _car_layer.hide())
	cancel.custom_minimum_size = Vector2(PANEL_WIDTH * 0.5 - 4.0, 0.0)
	buttons.add_child(_car_start)
	buttons.add_child(cancel)
	column.add_child(buttons)


## PARÇALAR: envanterdeki dokuz parça türü, adetleriyle.
func _build_parts_panel() -> void:
	_parts_layer = _modal_layer()
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_parts_layer.add_child(center)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 6)
	center.add_child(column)
	var plate: PlatePanel = PlatePanel.new()
	plate.theme_type_variation = &"HudCarPlate"
	plate.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	plate.mouse_filter = Control.MOUSE_FILTER_STOP
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 6)
	box.add_child(_label(&"HudPlateTitle", Loc.t("PARÇALAR")))
	_parts_grid = GridContainer.new()
	_parts_grid.columns = 3
	_parts_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_parts_grid.add_theme_constant_override(&"h_separation", 14)
	_parts_grid.add_theme_constant_override(&"v_separation", 6)
	box.add_child(_parts_grid)
	box.add_child(_label(&"HudInkCaption", Loc.t("Yığınları ara, tamir işlerinden ve arkadaşlarından parça topla.")))
	plate.add_child(box)
	column.add_child(plate)
	var close_button: PlateButton = _plate_button(Loc.t("KAPAT"), func() -> void: _parts_layer.hide())
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(close_button)


## Yarı saydam karartma + üstünde pano. Karartmaya dokunmak panoyu kapatır.
func _modal_layer() -> Control:
	var layer: Control = Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.visible = false
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.4)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			layer.hide())
	layer.add_child(dim)
	_overlay.add_child(layer)
	return layer


# --- Girdi: kamera + dokunuş -------------------------------------------------------

## Bütün girdiler hurdalığın görüntü alanına iletilir (kamera kaydırma / yakınlaştırma orada:
## WorldCamera). Burada yalnız DOKUNUŞ ayıklanır: basıp kaydırmadan bırakmak → yığın / araç seçimi.
func _gui_input(event: InputEvent) -> void:
	if _world == null:
		return
	_viewport.push_input(event, true)
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		_touches = maxi(_touches + (1 if st.pressed else -1), 0)
		if _touches > 1:
			_moved = true   # iki parmak: yakınlaştırma, dokunuş değil
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb: InputEventMouseButton = event
		if mb.pressed:
			_pressed = true
			_moved = _touches > 1
			_press_pos = mb.position
		elif _pressed:
			_pressed = false
			if not _moved:
				_tap(mb.position)
	elif event is InputEventMouseMotion and _pressed:
		if (event as InputEventMouseMotion).position.distance_to(_press_pos) > TAP_SLOP:
			_moved = true
	accept_event()


func _tap(at: Vector2) -> void:
	var hit: Dictionary = _world.pick(at)
	if hit.is_empty():
		return
	match hit["kind"]:
		&"pile":
			_search(int(hit["index"]))
		&"car":
			_show_car(int(hit["index"]))


# --- Yığın arama ---------------------------------------------------------------------

func _search(index: int) -> void:
	var jy: JunkyardManager = _jy()
	if jy == null or _busy_pile >= 0:
		return
	if not jy.pile_ready(index):
		_notice(Loc.t("BU YIĞIN BOŞ\n%s SONRA DOLAR") % _clock_text(jy.pile_seconds_left(index)), HudPalette.INK)
		return
	_busy_pile = index
	_world.set_pile_ready(index, false)
	_world.shake_pile(index, func() -> void:
		_busy_pile = -1
		if _world == null:
			return
		var result: Dictionary = jy.search_pile(index)
		var parts: Dictionary = result["parts"]
		if parts.is_empty():
			_notice(Loc.t("BİR ŞEY ÇIKMADI"), HudPalette.INK_SOFT)
			return
		var lines: PackedStringArray = PackedStringArray()
		for part_id: StringName in parts:
			lines.append("+%d %s" % [int(parts[part_id]), RestorationCatalog.part_name(part_id)])
		_notice("  ·  ".join(lines), HudPalette.COIN_DARK)
		_fly_parts(parts, _world.screen_point(_world.pile_position(index) + Vector3.UP * 1.2)))


## Bulunan parçaların ikonları yığından PARÇALAR plakasına uçar.
func _fly_parts(parts: Dictionary, from: Vector2) -> void:
	var target: Vector2 = _parts_button.get_global_rect().get_center()
	var k: int = 0
	for part_id: StringName in parts:
		for n: int in mini(int(parts[part_id]), 3):
			var icon: PartIcon = PartIcon.new()
			icon.part_id = part_id
			icon.size = Vector2(ICON_SIZE, ICON_SIZE)
			icon.position = from - icon.size * 0.5 + Vector2(k * 18.0 - 9.0, 0.0)
			icon.pivot_offset = icon.size * 0.5
			_overlay.add_child(icon)
			var tween: Tween = icon.create_tween()
			tween.tween_property(icon, "position:y", icon.position.y - 40.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_interval(0.08 * k)
			tween.set_parallel(true)
			tween.tween_property(icon, "position", target - icon.size * 0.5, FLY_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			tween.tween_property(icon, "scale", Vector2(0.6, 0.6), FLY_TIME)
			tween.set_parallel(false)
			tween.tween_callback(func() -> void:
				icon.queue_free()
				_pulse(_parts_button))
			k += 1


func _pulse(control: Control) -> void:
	control.pivot_offset = control.size * 0.5
	var tween: Tween = control.create_tween()
	tween.tween_property(control, "scale", Vector2(1.12, 1.12), 0.08)
	tween.tween_property(control, "scale", Vector2.ONE, 0.14)


# --- Günün araçları ------------------------------------------------------------------

func _show_car(index: int) -> void:
	var jy: JunkyardManager = _jy()
	if jy == null:
		return
	var cars: Array[StringName] = jy.yard_cars()
	if index < 0 or index >= cars.size() or cars[index] == &"":
		return
	_selected_car = index
	var id: StringName = cars[index]
	var entry: Dictionary = CarCatalog.get_entry(id)
	var plan: Dictionary = RestorationCatalog.get_entry(id)
	_car_title.text = String(entry.get("display_name", plan.get("name", id))).to_upper()
	var tier: Dictionary = RestorationCatalog.tier(RestorationCatalog.tier_of(id))
	_car_info.text = Loc.t("%d  ·  %s SINIFI  ·  %s") % [int(plan.get("year", 0)),
		String(entry.get("class", plan.get("class", "?"))), Loc.t(String(tier.get("name", "")))]
	for child: Node in _car_recipe.get_children():
		child.queue_free()
	var recipe: Dictionary = RestorationCatalog.recipe(id)
	for part_id: StringName in recipe:
		var cell: VBoxContainer = VBoxContainer.new()
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_theme_constant_override(&"separation", 0)
		var icon: PartIcon = PartIcon.new()
		icon.part_id = part_id
		icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		cell.add_child(icon)
		var have: int = jy.part_count(part_id)
		var count: Label = _label(&"HudInkCaption", "%d/%d" % [mini(have, int(recipe[part_id])), int(recipe[part_id])])
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(count)
		_car_recipe.add_child(cell)
	var free_bay: bool = jy.can_start(id)
	_car_start.disabled = not free_bay
	_car_hint.text = Loc.t("Garajda bir tamir alanına yerleşir. Parçaları orada takarsın.") if free_bay \
		else Loc.t("BOŞ TAMİR ALANI YOK — önce bir tamir işini bitir.")
	_parts_layer.hide()
	_car_layer.show()


func _start_selected() -> void:
	var jy: JunkyardManager = _jy()
	if jy == null or _selected_car < 0:
		return
	var cars: Array[StringName] = jy.yard_cars()
	if _selected_car >= cars.size() or cars[_selected_car] == &"":
		_car_layer.hide()
		return
	var id: StringName = cars[_selected_car]
	if jy.start(id):
		_car_layer.hide()
		_notice(Loc.t("%s GARAJA YOLA ÇIKTI") % _car_title.text, HudPalette.COIN_DARK, 2.2)


# --- Güncelleme ----------------------------------------------------------------------

func _refresh_yard() -> void:
	var jy: JunkyardManager = _jy()
	if jy == null or _world == null:
		return
	_world.show_daily(jy.yard_cars())
	for i: int in _world.piles.size():
		_world.set_pile_ready(i, i < jy.pile_count() and jy.pile_ready(i) and i != _busy_pile)
		_world.piles[i].visible = i < jy.pile_count()


func _refresh_parts_button() -> void:
	var jy: JunkyardManager = _jy()
	var total: int = jy.total_parts() if jy else 0
	_parts_button.text = Loc.t("PARÇALAR (%d)") % total if total > 0 else Loc.t("PARÇALAR")
	if _parts_layer.visible:
		_fill_parts()


func _toggle_parts() -> void:
	if _parts_layer.visible:
		_parts_layer.hide()
		return
	_car_layer.hide()
	_fill_parts()
	_parts_layer.show()


func _fill_parts() -> void:
	var jy: JunkyardManager = _jy()
	for child: Node in _parts_grid.get_children():
		child.queue_free()
	for part_id: StringName in RestorationCatalog.part_ids():
		var cell: HBoxContainer = HBoxContainer.new()
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_theme_constant_override(&"separation", 6)
		var icon: PartIcon = PartIcon.new()
		icon.part_id = part_id
		icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		var n: int = jy.part_count(part_id) if jy else 0
		icon.dim = n == 0
		cell.add_child(icon)
		var text: VBoxContainer = VBoxContainer.new()
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_theme_constant_override(&"separation", -2)
		text.add_child(_label(&"HudInkCaption", RestorationCatalog.part_name(part_id)))
		text.add_child(_label(&"HudInkValue", "× %d" % n))
		cell.add_child(text)
		_parts_grid.add_child(cell)


## Saniyelik sayaç: sahanın yenilenmesi, yığınların dolması. Gün döndüyse saha yeniden çekilir.
func _tick() -> void:
	var jy: JunkyardManager = _jy()
	if jy == null:
		return
	_yard_label.text = Loc.t("YENİ ARAÇLAR  %s") % _clock_text(jy.seconds_to_yard_refresh())
	var ready_count: int = jy.ready_pile_count()
	if ready_count > 0:
		_pile_label.text = Loc.t("ARANABİLİR YIĞIN  %d") % ready_count
	else:
		_pile_label.text = Loc.t("YIĞIN DOLUYOR  %s") % _clock_text(jy.next_pile_seconds())
	if _world:
		var cars: Array[StringName] = jy.yard_cars()   # gün döndüyse burada yeniden çekilir (yard_changed)
		if cars != _world.daily_ids():
			_world.show_daily(cars)
		for i: int in mini(_world.piles.size(), jy.pile_count()):
			if i != _busy_pile:
				_world.set_pile_ready(i, jy.pile_ready(i))


# --- Eğitim çapaları ------------------------------------------------------------------

## Necati'nin dersinin spot ışığı hedefleri: &"pile" (ekranın ortasına en yakın dolu yığın), &"car"
## (ortaya en yakın günün aracı), &"parts" (PARÇALAR), &"restore" (RESTORE ET), &"car_panel".
func tutorial_anchor(id: StringName) -> Control:
	match id:
		&"parts":
			return _parts_button
		&"restore":
			return _car_start if _car_layer.visible else null
		&"car_panel":
			return _car_layer if _car_layer.visible else null
		&"pile", &"car":
			if _world == null:
				return null
			if not _anchor_index.has(id) or not _anchor_valid(id, int(_anchor_index[id])):
				_anchor_index[id] = _nearest(id)
			if int(_anchor_index[id]) < 0:
				return null
			if not _anchors.has(id):
				var anchor: Control = Control.new()
				anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
				anchor.size = Vector2(130.0, 130.0)
				_overlay.add_child(anchor)
				_anchors[id] = anchor
			_place_anchor(id)
			return _anchors[id]
	return null


## Çapalar dünya noktasını izler (kamera kayınca / yaklaşınca).
func _process(_delta: float) -> void:
	for id: StringName in _anchors:
		if _anchor_index.has(id):
			_place_anchor(id)


func _place_anchor(id: StringName) -> void:
	var anchor: Control = _anchors.get(id) as Control
	var index: int = int(_anchor_index.get(id, -1))
	if anchor == null or index < 0 or _world == null:
		return
	var world_point: Vector3 = _world.pile_position(index) + Vector3.UP * 0.9 if id == &"pile" \
		else _world.car_position(index) + Vector3.UP * 0.6
	anchor.position = _world.screen_point(world_point) - anchor.size * 0.5


func _anchor_valid(id: StringName, index: int) -> bool:
	var jy: JunkyardManager = _jy()
	if jy == null or index < 0:
		return false
	if id == &"pile":
		return jy.pile_ready(index) or index == _busy_pile
	var cars: Array[StringName] = jy.yard_cars()
	return index < cars.size() and cars[index] != &""


func _nearest(id: StringName) -> int:
	var center: Vector2 = _viewport.get_visible_rect().size * 0.5
	var best: int = -1
	var best_d: float = INF
	var count: int = _world.piles.size() if id == &"pile" else _world.spots.size()
	for i: int in count:
		if not _anchor_valid(id, i):
			continue
		var p: Vector3 = _world.pile_position(i) if id == &"pile" else _world.car_position(i)
		var d: float = _world.screen_point(p).distance_to(center)
		if d < best_d:
			best_d = d
			best = i
	return best


# --- Yardımcılar ----------------------------------------------------------------------

func _notice(text: String, color: Color, hold: float = NOTICE_HOLD) -> void:
	_notice_label.text = text
	_notice_label.add_theme_color_override(&"font_color", color)
	if _notice_tween:
		_notice_tween.kill()
	_notice_plate.modulate.a = 0.0
	_notice_plate.show()
	_notice_tween = create_tween()
	_notice_tween.tween_property(_notice_plate, "modulate:a", 1.0, 0.12)
	_notice_tween.tween_interval(hold)
	_notice_tween.tween_property(_notice_plate, "modulate:a", 0.0, 0.25)
	_notice_tween.tween_callback(_notice_plate.hide)


static func _clock_text(seconds: int) -> String:
	var s: int = maxi(seconds, 0)
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s % 3600) / 60, s % 60]
	return "%02d:%02d" % [s / 60, s % 60]


func _plate_button(text: String, action: Callable, variation: StringName = &"HudPlateSmall") -> PlateButton:
	var button: PlateButton = PlateButton.new()
	button.theme_type_variation = variation
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	return button


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


func _jy() -> JunkyardManager:
	return get_tree().get_first_node_in_group("junkyard") as JunkyardManager if is_inside_tree() else null
