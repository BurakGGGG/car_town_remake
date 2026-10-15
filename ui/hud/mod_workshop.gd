class_name ModWorkshop
extends Node
## ARAÇLAR → MODİFİYE: garaj ekranının (GarageScreen) modifiye kipi. Lifteki araç yerinde döner. İki seviye
## (CSR2 / Forza / NFS'teki gibi: kategori → o kategorinin bütün parçaları, kazanç önceden görünür):
##
## GENEL BAKIŞ
##   ALTTA  6 kategori kartı: sıradaki parçanın 3D ikonu (Blender — tools/parts/part_icons.py), kategori adı, takılı
##          kademe çentikleri, sıradaki parçanın 0-100 kazancı ("−0,18 sn"), bu araçta ₺ başına en çok kazandıranda
##          ÖNERİLEN rozeti. Karta dokunmak kategoriye girer.
##   SOLDA  aracın değerleri (sınıf, 0-100, son hız, güç, 300 m, GENEL) ve süren takma.
##   SAĞDA  ÖNERİLEN plakası (kategori, parça, kazanç, İNCELE).
## KATEGORİ (ör. MOTOR)
##   ALTTA  5 kademe kartı merdiven gibi: kademe rengi, ikon, ad, o kademenin 0-100 kazancı, durum (✔ TAKILI ·
##          fiyat · SEVİYE kilidi · TAKILIYOR 4:05).
##   SOLDA  DİNAMOMETRE (ModDyno): fabrikadan FULL'e değer çubukları, seçilen kademenin yeşil kazancı, kategorinin
##          potansiyeli; MOTOR / TURBO / HAVA'da güç eğrisi; altında teknik satır (tork, vites geçişi, tutuş, ağırlık).
##   SAĞDA  seçilen parçanın plakası: kademe, ad, ne yaptığı (fizik), süre, fiyat, YÜKSELT / HEMEN BİTİR / TAK.
##   GERİ   genel bakışa döner (GarageScreen._on_exit_pressed).
## Önizlemeler simülasyonla ölçülür (PerformanceMods.measure, ~5 ms): ölçülmemiş yapılar kare başına bir tane
## hesaplanır, kartlar o sırada "…" gösterir (telefonda dokunuş takılmasın).
## YÜKSELT → upgrade_requested: satın alma ve ana dünyadaki sinematik HUD'dadır. Mantık yoktur.

signal upgrade_requested(vehicle_id: StringName, category: StringName)
## Elmas yetmedi: garaj elmas mağazasını açar.
signal gem_store_requested
## Başlık tabelası (MODİFİYE / MOTOR ...).
signal title_changed(text: String)
## Sol / alt panellerin boyu değişti (seviye değişti): garaj yerleşimi tazelesin.
signal layout_changed

enum View { OVERVIEW, CATEGORY }

const CARD_WIDTH: float = 118.0
const CARD_HEIGHT: float = 136.0
const ICON_AREA: float = 76.0
const NOTCH: Vector2 = Vector2(14.0, 5.0)
const ICON_TOP: float = 28.0
const STAGE_WIDTH: float = 136.0
const STAGE_HEIGHT: float = 166.0
const STAGE_ICON: float = 60.0
const STAGE_BAND: float = 17.0
const PANEL_WIDTH: float = 214.0
const STATS_WIDTH: float = 196.0
const DYNO_WIDTH: float = 296.0
const GAIN: Color = Color("3FA45F")
## Parça rafı: kartların oturduğu koyu, yuvarlak köşeli şerit (zeminin çizgileri kartların arasından görünmesin).
const TRAY_COLOR: Color = Color(0.11, 0.12, 0.14, 0.84)
## Pano açıkken sayaç / durumlar bu aralıkla tazelenir (sn).
const TICK: float = 0.5

var vehicle_id: StringName = &""
var category: StringName = &"motor"
## Kategori ekranında seçili kademe (1..5).
var selected_stage: int = 1
var view: View = View.OVERVIEW

## Kurulan kontroller (GarageScreen bunları kendi gruplarında gösterir / gizler).
var strip: PanelContainer
var stage_strip: PanelContainer
var detail: PlatePanel
var advice: PlatePanel
var stats: PlatePanel
var dyno_panel: PlatePanel

var _cards: Dictionary = {}    # kategori → PlateButton
var _stages: Array[PlateButton] = []
var _stage_group: ButtonGroup = ButtonGroup.new()
var _stat_values: Dictionary = {}
var _status: Label
var _tier: Label
var _part: Label
var _category_label: Label
var _icon: TextureRect
var _lines: Label
var _time: Label
var _price: Label
var _buy: PlateButton
var _dyno: ModDyno
var _dyno_title: Label
var _tech: Label
var _advice_title: Label
var _advice_icon: TextureRect
var _advice_text: Label
var _advice_button: PlateButton
var _active: bool = false
var _gem_armed_until: int = 0   # ELMASLA BİTİR onayı (Time.get_ticks_msec)
var _tick: float = 0.0
var _warm_generation: int = 0
var _recommended: StringName = &""
var _strip_header: Label
var _stage_header: Label
var _stage_hint: Label


func _ready() -> void:
	name = "ModWorkshop"
	set_process(false)
	_connect.call_deferred()


func _connect() -> void:
	var mods: PerformanceModManager = _mods()
	if mods:
		mods.jobs_changed.connect(refresh)
		mods.mods_changed.connect(func(_id: StringName) -> void: refresh())
	var economy: EconomyManager = get_tree().get_first_node_in_group("economy") as EconomyManager
	if economy:
		economy.money_changed.connect(func(_m: int) -> void: refresh())


## Kontrolleri kurar ve verilen gruplara ekler (hepsi gizli başlar).
func build(bottom: Control, left: Control, right: Control) -> void:
	_strip_header = _tray_label(Loc.t("PARÇA KATEGORİLERİ"), 1.0)
	strip = _tray(_build_strip(), _strip_header, _tray_label(Loc.t("Dokun, içine gir"), 0.6))
	bottom.add_child(strip)
	_stage_header = _tray_label("", 1.0)
	_stage_hint = _tray_label(Loc.t("Kademeler sırayla takılır"), 0.6)
	stage_strip = _tray(_build_stage_strip(), _stage_header, _stage_hint)
	bottom.add_child(stage_strip)
	stats = _build_stats()
	left.add_child(stats)
	dyno_panel = _build_dyno()
	left.add_child(dyno_panel)
	detail = _build_detail()
	right.add_child(detail)
	advice = _build_advice()
	right.add_child(advice)
	_show_controls()


func is_active() -> bool:
	return _active


func in_category() -> bool:
	return _active and view == View.CATEGORY


## Sol sütunda görünen panel (garaj yerleşimi boyunu buna göre verir).
func left_panel() -> Control:
	return dyno_panel if view == View.CATEGORY else stats


func open(id: StringName) -> void:
	vehicle_id = id
	_active = true
	view = View.OVERVIEW
	_show_controls()
	title_changed.emit(Loc.t("MODİFİYE"))
	refresh()
	_warm()
	set_process(true)


func close() -> void:
	_active = false
	_warm_generation += 1
	set_process(false)
	_show_controls()


## Kategoriye girer: 5 kademe merdiveni + dinamometre. Varsayılan seçim sıradaki kademe.
func open_category(c: StringName) -> void:
	if not _active:
		return
	category = c
	view = View.CATEGORY
	selected_stage = mini(PerformanceMods.stage_of(vehicle_id, c) + 1, PerformanceMods.STAGES)
	for i: int in _stages.size():
		_stages[i].set_pressed_no_signal(i + 1 == selected_stage)
	_show_controls()
	title_changed.emit(PerformanceMods.category_name(vehicle_id, c))
	refresh()
	_warm()
	layout_changed.emit()


## Kategoriden genel bakışa döner.
func show_overview() -> void:
	if not _active:
		return
	view = View.OVERVIEW
	_show_controls()
	title_changed.emit(Loc.t("MODİFİYE"))
	refresh()
	_warm()
	layout_changed.emit()


func _show_controls() -> void:
	if strip == null:
		return
	var overview: bool = _active and view == View.OVERVIEW
	var inside: bool = _active and view == View.CATEGORY
	strip.visible = overview
	stats.visible = overview
	advice.visible = overview and _recommended != &""
	stage_strip.visible = inside
	dyno_panel.visible = inside
	detail.visible = inside


func _process(delta: float) -> void:
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		_refresh_job()


# --- Ölçüm ısıtma -------------------------------------------------------------------------------

## Görünen önizlemelerin yapıları: genel bakışta her kategorinin sıradaki kademesi, kategoride o kategorinin
## 0..5 kademeleri; ayrıca fabrika ve FULL (çubuk ölçeği).
func _needed_builds() -> Array[Dictionary]:
	var build: Dictionary = PerformanceMods.build_of(vehicle_id)
	var out: Array[Dictionary] = [build, {}, _full_build()]
	if view == View.OVERVIEW:
		for c: StringName in PerformanceMods.CATEGORIES:
			var next: int = PerformanceMods.stage_of(vehicle_id, c) + 1
			if next <= PerformanceMods.STAGES:
				out.append(PerformanceMods.with_stage(build, c, next))
	else:
		for s: int in range(0, PerformanceMods.STAGES + 1):
			out.append(PerformanceMods.with_stage(build, category, s))
	return out


## Ölçülmemiş yapıları kare başına bir tane ölçer, bitince tazeler.
func _warm() -> void:
	_warm_generation += 1
	var generation: int = _warm_generation
	var measured_any: bool = false
	for b: Dictionary in _needed_builds():
		if PerformanceMods.is_measured(vehicle_id, b):
			continue
		await get_tree().process_frame
		if generation != _warm_generation or not _active:
			return
		PerformanceMods.measure(vehicle_id, b)
		measured_any = true
	if measured_any and generation == _warm_generation:
		refresh()


func _ready_for(builds: Array[Dictionary]) -> bool:
	for b: Dictionary in builds:
		if not PerformanceMods.is_measured(vehicle_id, b):
			return false
	return true


func _full_build() -> Dictionary:
	var full: Dictionary = {}
	for c: StringName in PerformanceMods.CATEGORIES:
		full[c] = PerformanceMods.STAGES
	return full


# --- Kurulum ------------------------------------------------------------------------------------

## Raf: koyu yuvarlak şerit, üstte başlık satırı (sol: ne, sağ: ipucu), altında kaydırılabilir kart sırası.
func _tray(scroll: ScrollContainer, title: Label, hint: Label) -> PanelContainer:
	var tray: PanelContainer = PanelContainer.new()
	tray.name = scroll.name.replace("Scroll", "Tray")
	tray.mouse_filter = Control.MOUSE_FILTER_PASS
	tray.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = TRAY_COLOR
	style.set_corner_radius_all(14)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 10.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.25)
	style.shadow_size = 6
	tray.add_theme_stylebox_override(&"panel", style)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 6)
	var head: HBoxContainer = HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(hint)
	column.add_child(head)
	column.add_child(scroll)
	tray.add_child(column)
	return tray


func _tray_label(text: String, alpha: float) -> Label:
	var label: Label = _label(&"HudInkCaption", text)
	label.add_theme_color_override(&"font_color", Color(HudPalette.TEXT_LIGHT, alpha))
	return label


func _build_strip() -> ScrollContainer:
	var scroll: ScrollContainer = _scroll("ModPartScroll")
	var row: HBoxContainer = scroll.get_node("Row") as HBoxContainer
	for c: StringName in PerformanceMods.CATEGORIES:
		var card: PlateButton = _plate_card("Part_%s" % c, Vector2(CARD_WIDTH, CARD_HEIGHT))
		card.draw.connect(_draw_card.bind(card, c))
		card.add_child(_icon_rect(Vector2((CARD_WIDTH - ICON_AREA) * 0.5, ICON_TOP), ICON_AREA))
		card.pressed.connect(open_category.bind(c))
		row.add_child(card)
		_cards[c] = card
	return scroll


func _build_stage_strip() -> ScrollContainer:
	var scroll: ScrollContainer = _scroll("ModStageScroll")
	var row: HBoxContainer = scroll.get_node("Row") as HBoxContainer
	for s: int in range(1, PerformanceMods.STAGES + 1):
		var card: PlateButton = _plate_card("Stage_%d" % s, Vector2(STAGE_WIDTH, STAGE_HEIGHT))
		card.toggle_mode = true
		card.button_group = _stage_group
		card.draw.connect(_draw_stage.bind(card, s))
		var icon: TextureRect = _icon_rect(Vector2((STAGE_WIDTH - STAGE_ICON) * 0.5, STAGE_BAND + 4.0), STAGE_ICON)
		card.add_child(icon)
		card.toggled.connect(func(pressed: bool) -> void:
			icon.position.y = STAGE_BAND + 4.0 - (card.lift_when_pressed if pressed else 0.0)
			if pressed:
				selected_stage = s
				_gem_armed_until = 0
				_refresh_category())
		row.add_child(card)
		_stages.append(card)
	return scroll


func _build_stats() -> PlatePanel:
	var panel: PlatePanel = _panel("ModStats", STATS_WIDTH)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var box: VBoxContainer = panel.get_node("Box") as VBoxContainer
	box.add_child(_label(&"HudPlateTitle", Loc.t("PERFORMANS")))
	for row: Array in [["class", "SINIF"], ["zero_100", "0-100"], ["top_speed", "SON HIZ"], ["hp", "GÜÇ"],
			["time_300", "300 m"], ["overall", "GENEL"]]:
		var line: HBoxContainer = HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var caption: Label = _label(&"HudInkCaption", Loc.t(String(row[1])))
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value: Label = _label(&"HudInkCaption", "")
		value.add_theme_color_override(&"font_color", HudPalette.INK)
		line.add_child(caption)
		line.add_child(value)
		box.add_child(line)
		_stat_values[row[0]] = value
	_status = _label(&"HudInkCaption", "")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
	box.add_child(_status)
	return panel


func _build_dyno() -> PlatePanel:
	var panel: PlatePanel = _panel("ModDyno", DYNO_WIDTH + 24.0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var box: VBoxContainer = panel.get_node("Box") as VBoxContainer
	box.add_theme_constant_override(&"separation", 4)
	_dyno_title = _label(&"HudPlateTitle", Loc.t("DİNAMOMETRE"))
	box.add_child(_dyno_title)
	_dyno = ModDyno.new()
	_dyno.custom_minimum_size.x = DYNO_WIDTH
	box.add_child(_dyno)
	_tech = _label(&"HudInkCaption", "")
	_tech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tech.custom_minimum_size.x = DYNO_WIDTH
	box.add_child(_tech)
	return panel


func _build_detail() -> PlatePanel:
	var panel: PlatePanel = _panel("ModDetail", PANEL_WIDTH)
	var box: VBoxContainer = panel.get_node("Box") as VBoxContainer
	_category_label = _label(&"HudInkCaption", "")
	_tier = _label(&"HudInkCaption", "")
	_part = _label(&"HudPlateTitle", "")
	_part.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(0.0, 76.0)
	_icon.visible = false   # seçili kademe kartında ikon zaten var (telefonda plaka merdivene binmesin)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines = _label(&"HudInkCaption", "")
	_lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_time = _label(&"HudInkCaption", "")
	_price = _label(&"HudInkValue", "")
	_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_price.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
	_buy = PlateButton.new()
	_buy.name = "UpgradeButton"
	_buy.theme_type_variation = &"HudPlate"
	_buy.kind = HudIcon.Kind.WRENCH
	_buy.icon_left = true
	_buy.highlight = true
	_buy.focus_mode = Control.FOCUS_NONE
	_buy.pressed.connect(_on_buy_pressed)
	for node: Control in [_category_label, _tier, _part, _icon, _lines, _time, _price, _buy]:
		box.add_child(node)
	return panel


func _build_advice() -> PlatePanel:
	var panel: PlatePanel = _panel("ModAdvice", PANEL_WIDTH)
	var box: VBoxContainer = panel.get_node("Box") as VBoxContainer
	var head: Label = _label(&"HudInkCaption", Loc.t("★ BU ARAÇ İÇİN ÖNERİLEN"))
	head.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
	_advice_title = _label(&"HudPlateTitle", "")
	_advice_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_advice_icon = TextureRect.new()
	_advice_icon.custom_minimum_size = Vector2(0.0, 70.0)
	_advice_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_advice_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_advice_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_advice_text = _label(&"HudInkCaption", "")
	_advice_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_advice_button = PlateButton.new()
	_advice_button.name = "AdviceButton"
	_advice_button.theme_type_variation = &"HudPlateSmall"
	_advice_button.bolts = false
	_advice_button.focus_mode = Control.FOCUS_NONE
	_advice_button.text = Loc.t("İNCELE")
	_advice_button.pressed.connect(func() -> void:
		if _recommended != &"":
			open_category(_recommended))
	for node: Control in [head, _advice_title, _advice_icon, _advice_text, _advice_button]:
		box.add_child(node)
	return panel


# --- İçerik ---------------------------------------------------------------------------------------

func refresh() -> void:
	if not _active or vehicle_id == &"":
		return
	if view == View.OVERVIEW:
		_refresh_overview()
	else:
		_refresh_category()
	_refresh_job()


func _refresh_overview() -> void:
	var now: Dictionary = PerformanceMods.stats(vehicle_id)
	(_stat_values["class"] as Label).text = String(now["class"])
	(_stat_values["zero_100"] as Label).text = Loc.t("%s sn") % dec2(float(now["zero_100"]))
	(_stat_values["top_speed"] as Label).text = Loc.t("%d km/sa") % roundi(float(now["top_speed"]))
	(_stat_values["hp"] as Label).text = Loc.t("%d bg") % roundi(float(now["hp"]))
	(_stat_values["time_300"] as Label).text = Loc.t("%s sn") % dec2(float(now["time_300"]))
	(_stat_values["overall"] as Label).text = str(int(now["overall"]))
	_recommended = PerformanceMods.recommend(vehicle_id) if _ready_for(_needed_builds()) else &""
	for c: StringName in _cards:
		var card: PlateButton = _cards[c]
		var stage: int = PerformanceMods.stage_of(vehicle_id, c)
		var icon: TextureRect = card.get_node("Icon") as TextureRect
		icon.texture = PerformanceMods.part_icon(vehicle_id, c, mini(stage + 1, PerformanceMods.STAGES))
		icon.modulate = Color(1.0, 1.0, 1.0, 0.5) if stage >= PerformanceMods.STAGES else Color.WHITE
		card.queue_redraw()
	_refresh_advice()
	_show_controls()


func _refresh_advice() -> void:
	if _recommended == &"":
		return
	var c: StringName = _recommended
	var stage: int = PerformanceMods.stage_of(vehicle_id, c) + 1
	_advice_title.text = "%s · %s" % [PerformanceMods.category_name(vehicle_id, c), PerformanceMods.part_name(vehicle_id, c, stage)]
	_advice_icon.texture = PerformanceMods.part_icon(vehicle_id, c, stage)
	var gain: Dictionary = _gain(c, stage)
	_advice_text.text = Loc.t("0-100 %s sn · 300 m %s sn\n%s ₺ başına en çok kazanç") % [
		_signed(-float(gain["zero_100"])), _signed(-float(gain["time_300"])),
		Hud.format_thousands(PerformanceMods.price(vehicle_id, c, stage))]


## Kategori ekranı: kademe kartları, dinamometre, parça plakası.
func _refresh_category() -> void:
	if view != View.CATEGORY:
		return
	for i: int in _stages.size():
		var card: PlateButton = _stages[i]
		var s: int = i + 1
		var icon: TextureRect = card.get_node("Icon") as TextureRect
		icon.texture = PerformanceMods.part_icon(vehicle_id, category, s)
		icon.modulate = Color(0.8, 0.8, 0.8, 0.5) if s > PerformanceMods.stage_of(vehicle_id, category) + 1 \
			else Color.WHITE
		card.queue_redraw()
	_stage_header.text = Loc.t("%s  ·  %d / %d TAKILI") % [PerformanceMods.category_name(vehicle_id, category),
		PerformanceMods.stage_of(vehicle_id, category), PerformanceMods.STAGES]
	_refresh_dyno()
	_refresh_detail()


## Seçilen kademenin dinamometresi: şu an → o kademeye kadar takılınca (takılı bir kademe seçildiyse onun katkısı).
func _refresh_dyno() -> void:
	var build: Dictionary = PerformanceMods.build_of(vehicle_id)
	var current: int = PerformanceMods.stage_of(vehicle_id, category)
	var from_build: Dictionary = build if selected_stage > current \
		else PerformanceMods.with_stage(build, category, selected_stage - 1)
	var to_build: Dictionary = PerformanceMods.with_stage(build, category, selected_stage)
	var cap_build: Dictionary = PerformanceMods.with_stage(build, category, PerformanceMods.STAGES)
	_dyno_title.text = Loc.t("DİNAMOMETRE · %s") % PerformanceMods.tier_name(selected_stage)
	if not _ready_for([from_build, to_build, cap_build, {}, _full_build()]):
		_dyno.set_data({})
		_tech.text = Loc.t("Ölçülüyor…")
		return
	var floor_ratio: float = PerformanceMods.display_floor(vehicle_id)
	var a: Dictionary = PerformanceMods.stats_with(vehicle_id, from_build, floor_ratio)
	var b: Dictionary = PerformanceMods.stats_with(vehicle_id, to_build, minf(floor_ratio, float(a["zero_100_ratio"])))
	var cap: Dictionary = PerformanceMods.stats_with(vehicle_id, cap_build, float(b["zero_100_ratio"]))
	var stock: Dictionary = PerformanceMods.stats_with(vehicle_id, {})
	var full: Dictionary = PerformanceMods.stats_with(vehicle_id, _full_build())
	var rows: Array = []
	for spec: Array in [["zero_100", "0-100", true, "sn"], ["top_speed", "SON HIZ", false, "km/sa"],
			["hp", "GÜÇ", false, "bg"], ["time_300", "300 m", true, "sn"]]:
		var key: String = spec[0]
		var lower: bool = spec[2]
		var f: Callable = func(v: float) -> float:
			var span: float = float(full[key]) - float(stock[key])
			return (v - float(stock[key])) / span if absf(span) > 0.0001 else 0.0
		var text: Callable = func(v: float) -> String:
			return dec2(v) if lower else str(roundi(v))
		var diff: float = float(b[key]) - float(a[key])
		var delta: String = ""
		if lower and absf(diff) >= 0.005:
			delta = _signed(diff)
		elif not lower and roundi(float(b[key])) != roundi(float(a[key])):
			delta = "+%d" % (roundi(float(b[key])) - roundi(float(a[key])))
		rows.append({"label": Loc.t(String(spec[1])), "now": text.call(float(a[key])), "after": text.call(float(b[key])),
			"delta": delta, "better": true, "frac_now": f.call(float(a[key])), "frac_after": f.call(float(b[key])),
			"frac_cap": f.call(float(cap[key]))})
	var data: Dictionary = {"rows": rows, "accent": PerformanceMods.tier_color(PerformanceMods.STAGES)}
	if category in [&"motor", &"turbo", &"air"]:
		var curve_a: Dictionary = PerformanceMods.power_curve(vehicle_id, from_build)
		var curve_b: Dictionary = PerformanceMods.power_curve(vehicle_id, to_build)
		data["curve_now"] = curve_a["points"]
		data["curve_after"] = curve_b["points"]
		data["peak_after"] = curve_b["peak"]
		data["peak_rpm_after"] = curve_b["peak_rpm"]
	_dyno.set_data(data)
	_tech.text = _tech_line(from_build, to_build)
	if category in [&"motor", &"turbo", &"air"] and float(a["zero_100"]) - float(b["zero_100"]) < 0.005:
		_tech.text += "\n" + Loc.t("Güç patinaja gidiyor: önce LASTİK")
	if String(b["class"]) != String(a["class"]):
		_tech.text += "\n" + Loc.t("%s → %s SINIFI!") % [a["class"], b["class"]]


## Kategoriye özgü teknik satır (önce → sonra).
func _tech_line(from_build: Dictionary, to_build: Dictionary) -> String:
	var a: Dictionary = PerformanceMods.tech(vehicle_id, from_build)
	var b: Dictionary = PerformanceMods.tech(vehicle_id, to_build)
	match category:
		&"motor", &"turbo":
			return Loc.t("TORK  %d → %d Nm\nDEVİR SINIRI  %s d/dk") % [roundi(float(a["torque"])), roundi(float(b["torque"])),
				Hud.format_thousands(roundi(float(b["redline"]) / 100.0) * 100)]
		&"air":
			return Loc.t("DEVİR SINIRI  %s → %s d/dk\nTORK  %d → %d Nm") % [
				Hud.format_thousands(roundi(float(a["redline"]) / 100.0) * 100),
				Hud.format_thousands(roundi(float(b["redline"]) / 100.0) * 100), roundi(float(a["torque"])), roundi(float(b["torque"]))]
		&"gear":
			return Loc.t("VİTES GEÇİŞİ  %d → %d ms (kusursuz vites)") % [roundi(float(a["shift_ms"])), roundi(float(b["shift_ms"]))]
		&"tire":
			var spin: String = ""
			if float(a["spin"]) >= 0.0 and float(b["spin"]) >= 0.0:
				spin = Loc.t("\nKALKIŞ PATİNAJI  %s → %s sn") % [dec2(float(a["spin"])), dec2(float(b["spin"]))]
				if float(a["spin"]) < 0.01:
					spin += "\n" + Loc.t("Patinaj yok: lastik yalnız hafif jantla kazandırır")
				elif float(b["spin"]) < 0.01:
					spin += "\n" + Loc.t("Patinaj bitiyor!")
			return Loc.t("TUTUŞ  +%%%d → +%%%d") % [roundi(float(a["grip"])), roundi(float(b["grip"]))] + spin
		_:
			return Loc.t("AĞIRLIK  %s → %s kg\nHAVA DİRENCİ  %%%d") % [
				Hud.format_thousands(roundi(float(a["mass"]))), Hud.format_thousands(roundi(float(b["mass"]))),
				roundi(float(b["drag"]))]


func _refresh_detail() -> void:
	if not _active or vehicle_id == &"" or view != View.CATEGORY:
		return
	var s: int = selected_stage
	_category_label.text = PerformanceMods.category_name(vehicle_id, category)
	_icon.texture = PerformanceMods.part_icon(vehicle_id, category, s)
	_tier.text = PerformanceMods.tier_name(s)
	_tier.add_theme_color_override(&"font_color", PerformanceMods.tier_color(s).darkened(0.3))
	_part.text = PerformanceMods.part_name(vehicle_id, category, s)
	_lines.text = PerformanceMods.effect_text(vehicle_id, category, s).replace(" · ", "\n")
	_time.text = Loc.t("⏱ %s · 1 tamir alanı · SEVİYE %d") % [duration_text(PerformanceMods.install_time(s)),
		PerformanceMods.required_level(s)]
	_refresh_buy()


## YÜKSELT plakası. Seçilen kademe: takılıysa TAKILI; sıradakiyse fiyat ya da neden alınamadığı (bu kategorinin
## parçası takılıyorsa ELMASLA BİTİR, süresi dolduysa TAK); daha ilerisiyse "ÖNCE <kademe>".
func _refresh_buy() -> void:
	var mods: PerformanceModManager = _mods()
	var current: int = PerformanceMods.stage_of(vehicle_id, category)
	var s: int = selected_stage
	_buy.kind = HudIcon.Kind.WRENCH
	_price.text = "%s ₺" % Hud.format_thousands(PerformanceMods.price(vehicle_id, category, s))
	if s <= current:
		_buy.disabled = true
		_buy.highlight = false
		_buy.text = Loc.t("TAKILI ✔")
		_price.text = ""
		return
	var job: Dictionary = mods.job_of(vehicle_id) if mods else {}
	if not job.is_empty() and job["category"] == category and int(job["stage"]) == s:
		_buy.disabled = false
		if mods.is_ready(vehicle_id):
			_buy.highlight = true
			_buy.text = Loc.t("TAK")
			_price.text = Loc.t("Parça hazır")
			return
		var armed: bool = Time.get_ticks_msec() < _gem_armed_until
		_buy.kind = HudIcon.Kind.GEM
		_buy.highlight = armed
		_buy.text = Loc.t("ONAYLA") if armed else Loc.t("HEMEN BİTİR")
		_price.text = Loc.t("%d GEM") % mods.gem_skip_cost(vehicle_id)
		return
	if s > current + 1:
		_buy.disabled = true
		_buy.highlight = false
		_buy.text = Loc.t("ÖNCE %s") % PerformanceMods.tier_name(current + 1)
		return
	var status: int = mods.status(vehicle_id, category) if mods else PerformanceModManager.Status.NOT_OWNED
	_buy.disabled = status != PerformanceModManager.Status.BUYABLE
	_buy.highlight = status == PerformanceModManager.Status.BUYABLE
	match status:
		PerformanceModManager.Status.NEEDS_LEVEL:
			_buy.text = Loc.t("SEVİYE %d GEREKLİ") % PerformanceMods.required_level(s)
		PerformanceModManager.Status.INSTALLING:
			_buy.text = Loc.t("PARÇA TAKILIYOR")
		PerformanceModManager.Status.NO_BAY:
			_buy.text = Loc.t("TAMİR ALANI DOLU")
		PerformanceModManager.Status.NOT_OWNED:
			_buy.text = Loc.t("SENİN DEĞİL")
		_:
			_buy.text = Loc.t("YÜKSELT")


func _on_buy_pressed() -> void:
	var mods: PerformanceModManager = _mods()
	var job: Dictionary = mods.job_of(vehicle_id) if mods else {}
	if job.is_empty() or job["category"] != category:
		upgrade_requested.emit(vehicle_id, category)
		return
	if mods.is_ready(vehicle_id):
		mods.collect(vehicle_id)
		return
	if Time.get_ticks_msec() >= _gem_armed_until:
		_gem_armed_until = Time.get_ticks_msec() + int(GemSkip.CONFIRM_TIME * 1000.0)   # ilk dokunuş: onay
		_refresh_buy()
		return
	_gem_armed_until = 0
	var cost: int = mods.gem_skip_cost(vehicle_id)
	var player: PlayerProgress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress
	if player == null or not player.can_afford_gems(cost):
		_refresh_buy()
		gem_store_requested.emit()
		return
	mods.finish_with_gems(vehicle_id)


## Süren takma: sol plakadaki durum satırı, YÜKSELT plakası, kademe kartlarındaki sayaç.
func _refresh_job() -> void:
	if not _active or _status == null:
		return
	var mods: PerformanceModManager = _mods()
	var has_job: bool = mods != null and mods.has_job(vehicle_id)
	if view == View.CATEGORY:
		if has_job:
			for card: PlateButton in _stages:
				card.queue_redraw()
		_refresh_buy()
	if not has_job:
		_status.text = ""
		_status.visible = false
		return
	var job: Dictionary = mods.job_of(vehicle_id)
	var what: String = PerformanceMods.part_name(vehicle_id, job["category"], int(job["stage"]))
	_status.visible = true
	if mods.is_ready(vehicle_id):
		_status.text = Loc.t("%s HAZIR\nTamir alanındaki araca dokun") % what
	else:
		_status.text = Loc.t("TAKILIYOR: %s\n%s kaldı") % [what, PerformanceBayDisplay.countdown(mods.remaining(vehicle_id))]


# --- Çizim --------------------------------------------------------------------------------------

## Kategori kartı: üstte kademe şeridi, ikon, çentikler, ad; sıradaki parçanın 0-100 kazancı; ÖNERİLEN rozeti.
func _draw_card(card: PlateButton, c: StringName) -> void:
	if vehicle_id == &"":
		return
	var w: float = card.size.x
	var stage: int = PerformanceMods.stage_of(vehicle_id, c)
	var next: int = mini(stage + 1, PerformanceMods.STAGES)
	var done: bool = stage >= PerformanceMods.STAGES
	card.draw_rect(Rect2(8.0, 5.0, w - 16.0, 4.0), PerformanceMods.tier_color(next) if not done else HudPalette.COIN)
	var y: float = ICON_TOP + ICON_AREA + 1.0
	_draw_notches(card, stage, Vector2(w * 0.5, y))
	var font: Font = card.get_theme_font(&"font")
	var font_size: int = maxi(card.get_theme_font_size(&"font_size"), 11)
	card.draw_string(font, Vector2(4.0, y + NOTCH.y + 6.0 + font_size), PerformanceMods.category_name(vehicle_id, c),
		HORIZONTAL_ALIGNMENT_CENTER, w - 8.0, font_size, card.get_theme_color(&"font_color"))
	# Çip sırası (ikonun üstünde: ikon ayrı düğüm, üstüne çizilen her şeyi örter)
	if not done:
		var gain: Dictionary = _gain(c, next)
		var text: String = (_signed(-float(gain["zero_100"])) + Loc.t(" sn")) if not gain.is_empty() else "…"
		_pill(card, Vector2(7.0, 12.0), text, GAIN, 10)
	else:
		_pill(card, Vector2(7.0, 12.0), Loc.t("TAMAM"), HudPalette.COIN_DARK, 10)
	if c == _recommended:   # ÖNERİLEN: yıldız + amber çerçeve
		_pill(card, Vector2(w - 7.0, 12.0), "★", HudPalette.COIN_DARK, 10, true)
		var frame: StyleBoxFlat = StyleBoxFlat.new()
		frame.draw_center = false
		frame.border_color = HudPalette.COIN
		frame.set_border_width_all(3)
		frame.set_corner_radius_all(6)
		card.draw_style_box(frame, Rect2(Vector2.ZERO, card.size))
	var mods: PerformanceModManager = _mods()
	if mods and mods.has_job(vehicle_id) and mods.job_of(vehicle_id)["category"] == c:
		HudIcon.draw_icon(card, HudIcon.Kind.WRENCH, Vector2(w - 14.0, ICON_TOP + ICON_AREA - 8.0), 16.0, HudPalette.COIN_DARK,
			Color(0.0, 0.0, 0.0, 0.0))


## Kademe kartı (merdiven basamağı): kademe bandı + adı, ikon, parça adı, o kademenin 0-100 katkısı, durum.
func _draw_stage(card: PlateButton, s: int) -> void:
	if vehicle_id == &"" or view != View.CATEGORY:
		return
	var lift: float = card.lift_when_pressed if card.button_pressed else 0.0
	var w: float = card.size.x
	var font: Font = card.get_theme_font(&"font")
	var ink: Color = card.get_theme_color(&"font_color")
	var current: int = PerformanceMods.stage_of(vehicle_id, category)
	var installed: bool = s <= current
	var ahead: bool = s > current + 1   # henüz sırası gelmemiş: soluk (kart opak kalır)
	var color: Color = PerformanceMods.tier_color(s)
	if ahead:
		color = color.lerp(Color(0.62, 0.62, 0.62), 0.5)
		ink = HudPalette.INK_SOFT
	# Kademe bandı
	var band: Rect2 = Rect2(5.0, 4.0 - lift, w - 10.0, STAGE_BAND)
	card.draw_rect(band, color)
	card.draw_string(font, Vector2(band.position.x, band.position.y + 13.0), PerformanceMods.tier_name(s),
		HORIZONTAL_ALIGNMENT_CENTER, band.size.x, 11, HudPalette.TEXT_LIGHT)
	# Parça adı (iki satıra kadar)
	var name_y: float = STAGE_BAND + 4.0 + STAGE_ICON + 4.0 - lift
	card.draw_multiline_string(font, Vector2(6.0, name_y + 11.0), PerformanceMods.part_name(vehicle_id, category, s),
		HORIZONTAL_ALIGNMENT_CENTER, w - 12.0, 11, 2, ink)
	# 0-100 katkısı
	var gain: Dictionary = _gain(category, s, true)
	var chip: String = (_signed(-float(gain["zero_100"])) + Loc.t(" sn")) if not gain.is_empty() else "…"
	_pill(card, Vector2(w * 0.5, name_y + 33.0), chip, GAIN.lerp(Color(0.6, 0.6, 0.6), 0.45) if ahead else GAIN, 10,
		false, true)
	# Durum
	var status: String = ""
	var status_color: Color = ink
	var mods: PerformanceModManager = _mods()
	var job: Dictionary = mods.job_of(vehicle_id) if mods else {}
	if installed:
		status = Loc.t("✔ TAKILI")
		status_color = GAIN.darkened(0.3)
	elif not job.is_empty() and job["category"] == category and int(job["stage"]) == s:
		status = Loc.t("HAZIR") if mods.is_ready(vehicle_id) else "⏱ " + PerformanceBayDisplay.countdown(mods.remaining(vehicle_id))
		status_color = HudPalette.COIN_DARK
	elif _player_level() < PerformanceMods.required_level(s):
		status = Loc.t("SEVİYE %d") % PerformanceMods.required_level(s)
		status_color = HudPalette.INK_SOFT
		HudIcon.draw_icon(card, HudIcon.Kind.LOCK, Vector2(w - 15.0, STAGE_BAND + 14.0 - lift), 14.0, HudPalette.INK_SOFT,
			Color(0.0, 0.0, 0.0, 0.0))
	else:
		status = "%s ₺" % Hud.format_thousands(PerformanceMods.price(vehicle_id, category, s))
		status_color = HudPalette.COIN_DARK
	card.draw_string(font, Vector2(4.0, STAGE_HEIGHT - 9.0 - lift), status, HORIZONTAL_ALIGNMENT_CENTER, w - 8.0, 11,
		status_color)
	if installed:   # onay rozeti
		var badge: Vector2 = Vector2(w - 14.0, STAGE_BAND + 14.0 - lift)
		card.draw_circle(badge, 8.0, GAIN, true, -1.0, true)
		card.draw_polyline(PackedVector2Array([badge + Vector2(-4.0, 0.0), badge + Vector2(-1.0, 3.0),
			badge + Vector2(4.0, -3.0)]), HudPalette.TEXT_LIGHT, 2.0, true)
	if s == current + 1 and job.is_empty() and not card.button_pressed:   # sıradaki: kademe renginde ince çerçeve
		var frame: StyleBoxFlat = StyleBoxFlat.new()
		frame.draw_center = false
		frame.border_color = color
		frame.set_border_width_all(2)
		frame.set_corner_radius_all(6)
		card.draw_style_box(frame, Rect2(Vector2(0.0, -lift), card.size))


func _draw_notches(card: Control, stage: int, center_top: Vector2) -> void:
	var total: float = PerformanceMods.STAGES * NOTCH.x + (PerformanceMods.STAGES - 1) * 3.0
	var x: float = center_top.x - total * 0.5
	for i: int in PerformanceMods.STAGES:
		var tier: Color = PerformanceMods.tier_color(i + 1)
		var rect: Rect2 = Rect2(x + i * (NOTCH.x + 3.0), center_top.y, NOTCH.x, NOTCH.y)
		card.draw_rect(rect, tier if i < stage else Color(tier, 0.2))
		card.draw_rect(rect, tier.darkened(0.35), false, 1.0)


## Yuvarlatılmış etiket. right_align: x sağ kenardır; center: x ortadır.
func _pill(card: Control, at: Vector2, text: String, color: Color, font_size: int, right_align: bool = false,
		center: bool = false) -> void:
	var font: Font = card.get_theme_font(&"font", &"Label")
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 10.0
	var x: float = at.x - width if right_align else (at.x - width * 0.5 if center else at.x)
	var rect: Rect2 = Rect2(x, at.y, width, float(font_size) + 6.0)
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(rect.size.y * 0.5))
	box.anti_aliasing = true
	card.draw_style_box(box, rect)
	card.draw_string(font, Vector2(rect.position.x + 5.0, rect.position.y + float(font_size) + 1.5), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, HudPalette.TEXT_LIGHT)


## Bir kademenin kazancı (0-100 ve 300 m, sn; pozitif = hızlandı). incremental: o kademe, bir öncekine göre
## (öteki kategoriler şimdiki haliyle); değilse şimdiki yapıdan o kademeye. Ölçülmemişse boş.
func _gain(c: StringName, s: int, incremental: bool = false) -> Dictionary:
	var build: Dictionary = PerformanceMods.build_of(vehicle_id)
	var from_build: Dictionary = PerformanceMods.with_stage(build, c, s - 1) if incremental else build
	var to_build: Dictionary = PerformanceMods.with_stage(build, c, s)
	if not _ready_for([from_build, to_build]):
		return {}
	var a: Dictionary = PerformanceMods.stats_with(vehicle_id, from_build)
	var b: Dictionary = PerformanceMods.stats_with(vehicle_id, to_build, float(a["zero_100_ratio"]))
	return {"zero_100": float(a["zero_100"]) - float(b["zero_100"]), "time_300": float(a["time_300"]) - float(b["time_300"])}


# --- Yardımcılar ---------------------------------------------------------------------------------

## İki ondalık, dile göre ayraç ("9,72").
static func dec2(value: float) -> String:
	var text: String = "%.2f" % value
	return text if Loc.current() == "en" else text.replace(".", ",")


## İşaretli iki ondalık: "−0,18" / "+0,05".
static func _signed(value: float) -> String:
	return ("−" if value < 0.0 else "+") + dec2(absf(value))


## "2 dk" / "1 sa 30 dk".
static func duration_text(seconds: float) -> String:
	var minutes: int = roundi(seconds / 60.0)
	if minutes < 60:
		return Loc.t("%d dk") % minutes
	var h: int = minutes / 60
	var m: int = minutes % 60
	return Loc.t("%d sa") % h if m == 0 else Loc.t("%d sa %d dk") % [h, m]


func _player_level() -> int:
	var progress_node: PlayerProgress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress \
		if is_inside_tree() else null
	return progress_node.level if progress_node else 99


func _mods() -> PerformanceModManager:
	return get_tree().get_first_node_in_group("performance_mods") as PerformanceModManager if is_inside_tree() else null


func _scroll(scroll_name: String) -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = scroll_name
	# Yatay kaydırılır ama genişliği fit_trays verir: içerik sığıyorsa raf içeriği kadardır ve ortalanır
	# (kaydırılabilir kap yatayda içeriğe göre boyut almaz), dar tuvalde (853 birim: 16:9 telefon, tablet;
	# 6 kart 778 birim) kalan yere sığar ve kartlar parmakla kaydırılır. Eskiden kaydırma kapalıydı ("en dar
	# ekran 1152") ve raf ekranın sağından 74-121 birim taşıyordu.
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Row"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 10)
	scroll.add_child(row)
	TouchScroll.attach(scroll)
	return scroll


## Rafları verilen genişliğe (garajın alt bandı; yan sütunlar düşülmüş) sığdırır: sığan raf içeriği kadar,
## sığmayanın kartları kaydırılır.
func fit_trays(available: float) -> void:
	for tray: PanelContainer in [strip, stage_strip]:
		if tray == null:
			continue
		var scroll: ScrollContainer = tray.find_child("Mod*Scroll", true, false) as ScrollContainer
		var row: Control = scroll.get_node("Row") as Control if scroll else null
		if row == null:
			continue
		var padding: float = tray.get_theme_stylebox(&"panel").get_minimum_size().x
		var width: float = floorf(minf(row.get_combined_minimum_size().x, maxf(available - padding, CARD_WIDTH)))
		if not is_equal_approx(scroll.custom_minimum_size.x, width):
			scroll.custom_minimum_size.x = width


func _plate_card(card_name: String, card_size: Vector2) -> PlateButton:
	var card: PlateButton = PlateButton.new()
	card.name = card_name
	card.kind = HudIcon.Kind.NONE
	card.bolts = false
	card.lift_when_pressed = 3.0
	card.theme_type_variation = &"HudGalleryPlate"
	card.custom_minimum_size = card_size
	card.focus_mode = Control.FOCUS_NONE
	return card


## İkon ayrı bir düğüm: plakanın draw'ında çizilen doku seçili olmayan kartlarda beyaz kutu çıkıyordu.
func _icon_rect(at: Vector2, side: float) -> TextureRect:
	var icon: TextureRect = TextureRect.new()
	icon.name = "Icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = at
	icon.size = Vector2(side, side)
	return icon


func _panel(panel_name: String, width: float) -> PlatePanel:
	var panel: PlatePanel = PlatePanel.new()
	panel.name = panel_name
	panel.theme_type_variation = &"HudCarPlate"
	panel.custom_minimum_size = Vector2(width, 0.0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "Box"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 2)
	panel.add_child(box)
	return panel


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
