class_name ModWorkshop
extends Node
## ARAÇLAR → MODİFİYE: garaj ekranının (GarageScreen) modifiye kipi. Lifteki araç yerinde kalır; ekranın
##   ALTINDA  araç şeridinin yerine 6 parça kartı (kategori başına sıradaki parçanın 3D ikonu — Blender'da çizildi,
##            tools/parts/part_icons.py —, kategori adı, takılı kademe çentikleri),
##   SAĞDA    seçilen parçanın plakası: kademe, ad, büyük ikon, takınca ne değişeceği (önce → sonra), takma süresi
##            ve YÜKSELT (fiyat ya da neden alınamadığı),
##   SOLDA    aracın güncel değerleri (0-100, son hız, güç, 300 m, GENEL, sınıf) ve süren takma.
## YÜKSELT → upgrade_requested: satın alma ve ana dünyadaki sinematik (araç tamir alanının liftine çıkar) HUD'dadır.
## Mantık yoktur: PerformanceModManager ve PerformanceMods okunur. Kodla kurulur (GarageScreen._ready).

signal upgrade_requested(vehicle_id: StringName, category: StringName)

const CARD_WIDTH: float = 118.0
const CARD_HEIGHT: float = 124.0
const ICON_AREA: float = 84.0
const NOTCH: Vector2 = Vector2(14.0, 5.0)
const ICON_TOP: float = 9.0
const PANEL_WIDTH: float = 214.0
const STATS_WIDTH: float = 196.0
## Pano açıkken sayaç / durumlar bu aralıkla tazelenir (sn).
const TICK: float = 0.5

var vehicle_id: StringName = &""
var category: StringName = &"motor"

## Kurulan kontroller (GarageScreen bunları kendi gruplarında gösterir / gizler).
var strip: ScrollContainer
var detail: PlatePanel
var stats: PlatePanel

var _cards: Dictionary = {}   # kategori → PlateButton
var _group: ButtonGroup = ButtonGroup.new()
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
var _active: bool = false
var _tick: float = 0.0


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
	strip = _build_strip()
	bottom.add_child(strip)
	stats = _build_stats()
	left.add_child(stats)
	detail = _build_detail()
	right.add_child(detail)
	for control: Control in [strip, stats, detail]:
		control.visible = false


func is_active() -> bool:
	return _active


func open(id: StringName) -> void:
	vehicle_id = id
	_active = true
	for control: Control in [strip, stats, detail]:
		control.visible = true
	# Varsayılan seçim: henüz tamamlanmamış ilk kategori
	category = PerformanceMods.CATEGORIES[0]
	for c: StringName in PerformanceMods.CATEGORIES:
		if PerformanceMods.stage_of(vehicle_id, c) < PerformanceMods.STAGES:
			category = c
			break
	for c: StringName in _cards:   # set_pressed_no_signal grubu güncellemez: önceki seçim elle bırakılır
		(_cards[c] as PlateButton).set_pressed_no_signal(c == category)
	refresh()
	set_process(true)


func close() -> void:
	_active = false
	set_process(false)
	for control: Control in [strip, stats, detail]:
		if control:
			control.visible = false


func _process(delta: float) -> void:
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		_refresh_job()


# --- Kurulum ------------------------------------------------------------------------------------

func _build_strip() -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "ModPartScroll"
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	TouchScroll.attach(scroll)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "ModPartList"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 8)
	scroll.add_child(row)
	for c: StringName in PerformanceMods.CATEGORIES:
		var card: PlateButton = PlateButton.new()
		card.name = "Part_%s" % c
		card.kind = HudIcon.Kind.NONE
		card.bolts = false
		card.lift_when_pressed = 3.0
		card.toggle_mode = true
		card.button_group = _group
		card.theme_type_variation = &"HudGalleryPlate"
		card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
		card.focus_mode = Control.FOCUS_NONE
		card.draw.connect(_draw_card.bind(card, c))
		# İkon ayrı bir düğüm: plakanın draw'ında çizilen doku seçili olmayan kartlarda beyaz kutu çıkıyordu
		var icon: TextureRect = TextureRect.new()
		icon.name = "Icon"
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2((CARD_WIDTH - ICON_AREA) * 0.5, ICON_TOP)
		icon.size = Vector2(ICON_AREA, ICON_AREA)
		card.add_child(icon)
		card.toggled.connect(func(pressed: bool) -> void:
			icon.position.y = ICON_TOP - (card.lift_when_pressed if pressed else 0.0)
			if pressed:
				category = c
				_refresh_detail())
		row.add_child(card)
		_cards[c] = card
	return scroll


func _build_stats() -> PlatePanel:
	var panel: PlatePanel = PlatePanel.new()
	panel.name = "ModStats"
	panel.theme_type_variation = &"HudCarPlate"
	panel.custom_minimum_size = Vector2(STATS_WIDTH, 0.0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 2)
	panel.add_child(box)
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


func _build_detail() -> PlatePanel:
	var panel: PlatePanel = PlatePanel.new()
	panel.name = "ModDetail"
	panel.theme_type_variation = &"HudCarPlate"
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 2)
	panel.add_child(box)
	_category_label = _label(&"HudInkCaption", "")
	_tier = _label(&"HudInkCaption", "")
	_part = _label(&"HudPlateTitle", "")
	_part.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(0.0, 92.0)
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
	_buy.pressed.connect(func() -> void: upgrade_requested.emit(vehicle_id, category))
	for node: Control in [_category_label, _tier, _part, _icon, _lines, _time, _price, _buy]:
		box.add_child(node)
	return panel


# --- İçerik ---------------------------------------------------------------------------------------

func refresh() -> void:
	if not _active or vehicle_id == &"":
		return
	var now: Dictionary = PerformanceMods.stats(vehicle_id)
	(_stat_values["class"] as Label).text = String(now["class"])
	(_stat_values["zero_100"] as Label).text = Loc.t("%s sn") % dec2(float(now["zero_100"]))
	(_stat_values["top_speed"] as Label).text = Loc.t("%d km/sa") % roundi(float(now["top_speed"]))
	(_stat_values["hp"] as Label).text = Loc.t("%d bg") % roundi(float(now["hp"]))
	(_stat_values["time_300"] as Label).text = Loc.t("%s sn") % dec2(float(now["time_300"]))
	(_stat_values["overall"] as Label).text = str(int(now["overall"]))
	for c: StringName in _cards:
		var card: PlateButton = _cards[c]
		var stage: int = PerformanceMods.stage_of(vehicle_id, c)
		var icon: TextureRect = card.get_node("Icon") as TextureRect
		icon.texture = PerformanceMods.part_icon(vehicle_id, c, mini(stage + 1, PerformanceMods.STAGES))
		icon.modulate = Color(1.0, 1.0, 1.0, 0.5) if stage >= PerformanceMods.STAGES else Color.WHITE
		icon.position.y = ICON_TOP - (card.lift_when_pressed if card.button_pressed else 0.0)
		card.queue_redraw()
	_refresh_detail()
	_refresh_job()


func _refresh_detail() -> void:
	if not _active or vehicle_id == &"":
		return
	var stage: int = PerformanceMods.stage_of(vehicle_id, category)
	var next: int = mini(stage + 1, PerformanceMods.STAGES)
	_category_label.text = PerformanceMods.category_name(vehicle_id, category)
	_icon.texture = PerformanceMods.part_icon(vehicle_id, category, next)
	if stage >= PerformanceMods.STAGES:
		_tier.text = Loc.t("TAMAMLANDI")
		_tier.add_theme_color_override(&"font_color", PerformanceMods.tier_color(PerformanceMods.STAGES).darkened(0.3))
		_part.text = PerformanceMods.part_name(vehicle_id, category, PerformanceMods.STAGES)
		_lines.text = Loc.t("Bu kategoride en üst kademe takılı.")
		_time.text = ""
		_price.text = ""
		_buy.text = Loc.t("EFSANE ✔")
		_buy.disabled = true
		return
	_tier.text = PerformanceMods.tier_name(next)
	_tier.add_theme_color_override(&"font_color", PerformanceMods.tier_color(next).darkened(0.3))
	_part.text = PerformanceMods.part_name(vehicle_id, category, next)
	var now: Dictionary = PerformanceMods.stats(vehicle_id)
	var after: Dictionary = PerformanceMods.preview(vehicle_id, category)
	var lines: PackedStringArray = PackedStringArray()
	lines.append(Loc.t("0-100  %s → %s sn") % [dec2(float(now["zero_100"])), dec2(float(after["zero_100"]))])
	match category:
		&"motor", &"turbo", &"air":
			lines.append(Loc.t("GÜÇ  %d → %d bg") % [roundi(float(now["hp"])), roundi(float(after["hp"]))])
			if float(after["zero_100"]) > float(now["zero_100"]) - 0.005:
				lines.append(Loc.t("Güç patinaja gidiyor: önce LASTİK"))
		&"gear":
			lines.append(Loc.t("SON HIZ  %d → %d km/sa") % [roundi(float(now["top_speed"])), roundi(float(after["top_speed"]))])
		_:
			lines.append(Loc.t("300 m  %s → %s sn") % [dec2(float(now["time_300"])), dec2(float(after["time_300"]))])
	if String(after["class"]) != String(now["class"]):
		lines.append(Loc.t("%s → %s SINIFI!") % [now["class"], after["class"]])
	_lines.text = "\n".join(lines)
	_time.text = Loc.t("⏱ %s · 1 tamir alanı") % duration_text(PerformanceMods.install_time(next))
	_refresh_buy()


## YÜKSELT plakası: fiyat ya da neden alınamadığı (süren takmada kalan süre).
func _refresh_buy() -> void:
	var mods: PerformanceModManager = _mods()
	var stage: int = PerformanceMods.stage_of(vehicle_id, category) + 1
	if stage > PerformanceMods.STAGES:
		return
	var status: int = mods.status(vehicle_id, category) if mods else PerformanceModManager.Status.NOT_OWNED
	_buy.disabled = status != PerformanceModManager.Status.BUYABLE
	_buy.highlight = status == PerformanceModManager.Status.BUYABLE
	match status:
		PerformanceModManager.Status.NEEDS_LEVEL:
			_buy.text = Loc.t("SEVİYE %d GEREKLİ") % PerformanceMods.required_level(stage)
		PerformanceModManager.Status.INSTALLING:
			_buy.text = Loc.t("PARÇA TAKILIYOR")
		PerformanceModManager.Status.NO_BAY:
			_buy.text = Loc.t("TAMİR ALANI DOLU")
		PerformanceModManager.Status.NOT_OWNED:
			_buy.text = Loc.t("SENİN DEĞİL")
		_:
			_buy.text = Loc.t("YÜKSELT")
	_price.text = "%s ₺" % Hud.format_thousands(PerformanceMods.price(vehicle_id, category, stage))


## Süren takma: sol plakadaki durum satırı + YÜKSELT plakası.
func _refresh_job() -> void:
	if not _active or _status == null:
		return
	var mods: PerformanceModManager = _mods()
	if mods == null or not mods.has_job(vehicle_id):
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
	_refresh_buy()


## Parça kartı: üstte kademe renginde şerit, ortada sıradaki parçanın ikonu, altta takılı kademe çentikleri.
## Kategori adı da burada çizilir (plakanın yazısı boş: HudGalleryPlate'in yazı payı ikona göre küçük).
func _draw_card(card: PlateButton, c: StringName) -> void:
	if vehicle_id == &"":
		return
	var lift: float = 3.0 if card.button_pressed else 0.0
	var w: float = card.size.x
	var stage: int = PerformanceMods.stage_of(vehicle_id, c)
	var next: int = mini(stage + 1, PerformanceMods.STAGES)
	var done: bool = stage >= PerformanceMods.STAGES
	var color: Color = PerformanceMods.tier_color(next)
	card.draw_rect(Rect2(8.0, 5.0 - lift, w - 16.0, 4.0), color if not done else HudPalette.COIN)
	var area: Rect2 = Rect2((w - ICON_AREA) * 0.5, ICON_TOP - lift, ICON_AREA, ICON_AREA)
	var total: float = PerformanceMods.STAGES * NOTCH.x + (PerformanceMods.STAGES - 1) * 3.0
	var x: float = (w - total) * 0.5
	var y: float = area.end.y + 1.0
	for i: int in PerformanceMods.STAGES:
		var tier: Color = PerformanceMods.tier_color(i + 1)
		var rect: Rect2 = Rect2(x + i * (NOTCH.x + 3.0), y, NOTCH.x, NOTCH.y)
		card.draw_rect(rect, tier if i < stage else Color(tier, 0.2))
		card.draw_rect(rect, tier.darkened(0.35), false, 1.0)
	var font: Font = card.get_theme_font(&"font")
	var font_size: int = maxi(card.get_theme_font_size(&"font_size"), 11)
	card.draw_string(font, Vector2(4.0, y + NOTCH.y + 6.0 + font_size), PerformanceMods.category_name(vehicle_id, c),
		HORIZONTAL_ALIGNMENT_CENTER, w - 8.0, font_size, card.get_theme_color(&"font_color"))
	var mods: PerformanceModManager = _mods()
	if mods and mods.has_job(vehicle_id) and mods.job_of(vehicle_id)["category"] == c:
		HudIcon.draw_icon(card, HudIcon.Kind.WRENCH, Vector2(w - 16.0, 22.0 - lift), 16.0, HudPalette.COIN_DARK,
			Color(0.0, 0.0, 0.0, 0.0))


# --- Yardımcılar ---------------------------------------------------------------------------------

## İki ondalık, dile göre ayraç ("9,72").
static func dec2(value: float) -> String:
	var text: String = "%.2f" % value
	return text if Loc.current() == "en" else text.replace(".", ",")


## "2 dk" / "1 sa 30 dk".
static func duration_text(seconds: float) -> String:
	var minutes: int = roundi(seconds / 60.0)
	if minutes < 60:
		return Loc.t("%d dk") % minutes
	var h: int = minutes / 60
	var m: int = minutes % 60
	return Loc.t("%d sa") % h if m == 0 else Loc.t("%d sa %d dk") % [h, m]


func _mods() -> PerformanceModManager:
	return get_tree().get_first_node_in_group("performance_mods") as PerformanceModManager if is_inside_tree() else null


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
