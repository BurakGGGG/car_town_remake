class_name EventBanner
extends Control
## CANLI ETKİNLİK TABELASI (kullanıcı kararı 2026-10-21, taslak B): ekranın üst ortasında koyu, amber kenarlı tabela —
## "×2 · HAFTA SONU ETKİNLİĞİ · ÇİFTE PARA · ÇİFTE XP · 23:41:05". Etkinlik AppConfig.active_event'ten (config/app.event,
## yönetim paneli); süresi bitince kendiliğinden söner. Yalnızca şehirdeyken görünür (açık ekran, ders, kasa panosu,
## ziyaret yok). Dokununca ETKİNLİK PANOSU açılır (EventScreen: modüller ve düğmeleri). Ana satır etkinliğin modüllerini
## özetler (ÇİFTE PARA · KASALAR −%30 · ÖZEL RAKİP …); rozet çarpan (×2), yoksa en büyük indirim, yoksa ★.
## Hud kurar (temalı kök). Kodla kurulur.

const TICK_SEC: float = 1.0
## Tabelanın genişliği: dar tuvalde (853) sol üst / sağ üst kümelere değmesin.
const MAX_WIDTH: float = 460.0
const MIN_WIDTH: float = 340.0
const SIDE_RESERVE: float = 250.0
const DARK: Color = Color("2D2A26")

var _hud: Hud
var _plate: PanelContainer
var _chip: Label
var _title: Label
var _main: Label
var _clock: Label
var _event_id: String = ""
var _event_key: int = 0
## Ana satırın parçaları (ÇİFTE PARA, İNDİRİM −%30 …): sığmayanlar "+2" olur (_fit_main).
var _parts: PackedStringArray = PackedStringArray()
var _timer: Timer


func _init(hud: Hud) -> void:
	name = "EventBanner"
	_hud = hud


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_build()
	_timer = Timer.new()
	_timer.wait_time = TICK_SEC
	_timer.timeout.connect(_tick)
	add_child(_timer)
	_timer.start()
	get_viewport().size_changed.connect(_fit)
	_fit()
	_tick()


## Görünen etkinliğin kimliği (testler): boşsa tabela kapalı.
func event_id() -> String:
	return _event_id if visible else ""


func _tick() -> void:
	var config: AppConfig = AppConfig.of(get_tree())
	var event: Dictionary = config.active_event() if config else {}
	var tutorial: TutorialDirector = _hud.tutorial
	var calm: bool = _hud.router.top().is_empty() and not (tutorial and tutorial.is_running()) \
		and not (_hud.crate_panel and _hud.crate_panel.visible) and not GarageVisit.is_visiting()
	visible = not event.is_empty() and calm
	if event.is_empty():
		_event_id = ""
		_event_key = 0
		return
	if event.hash() != _event_key:   # panel etkinliği sürerken düzeltebilir: kimlik aynı, modüller değişmiş olabilir
		_event_key = event.hash()
		_event_id = SaveSafe.s(event["id"])
		_fill(event)
	_clock.text = countdown(int(event["end"]) - int(Time.get_unix_time_from_system()))


func _fill(event: Dictionary) -> void:
	var money: float = float(event["money_mult"])
	var xp: float = float(event["xp_mult"])
	var sale: Dictionary = event["sale"]
	var best_sale: int = 0
	for kind: StringName in sale:
		best_sale = maxi(best_sale, int(sale[kind]))
	if money > 1.0 or xp > 1.0:
		_chip.text = "×" + Loc.decimal(maxf(money, xp), 1).trim_suffix(",0").trim_suffix(".0")
	elif best_sale > 0:
		_chip.text = ShowroomScreen.sale_tag(best_sale)
	else:
		_chip.text = "★"
	var title: String = SaveSafe.s(event.get("title", ""))
	_title.text = Loc.upper(title) if not title.is_empty() else Loc.t("CANLI ETKİNLİK")
	var parts: PackedStringArray = PackedStringArray()
	if money > 1.0:
		parts.append(Loc.t("ÇİFTE PARA") if is_equal_approx(money, 2.0) else Loc.t("PARA ×%s") % Loc.decimal(money, 1))
	if xp > 1.0:
		parts.append(Loc.t("ÇİFTE XP") if is_equal_approx(xp, 2.0) else Loc.t("XP ×%s") % Loc.decimal(xp, 1))
	if best_sale > 0:
		parts.append(Loc.t("İNDİRİM %s") % ShowroomScreen.sale_tag(best_sale))
	if not (event["crate_boost"] as Dictionary).is_empty():
		parts.append(Loc.t("ETKİNLİK KASASI"))
	if not (event["missions"] as Array).is_empty():
		parts.append(Loc.t("GÖREVLER"))
	if not (event["rival"] as Dictionary).is_empty():
		parts.append(Loc.t("ÖZEL RAKİP"))
	if not String(event["pack"]).is_empty():
		parts.append(Loc.t("YENİ EŞYALAR"))
	_parts = parts
	_fit_main()
	_fit_main.call_deferred()   # ilk dolumda satırın genişliği yerleşimden sonra belli olur


## Ana satıra sığdığı kadar parça; kalanı "+N" (dokununca pano hepsini gösterir).
func _fit_main() -> void:
	var width: float = _main.size.x
	_main.text = " · ".join(_parts)
	if width <= 0.0 or _parts.size() <= 1:
		return
	var font: Font = _main.get_theme_font(&"font")
	var font_size: int = _main.get_theme_font_size(&"font_size")
	for n: int in range(_parts.size(), 0, -1):
		var text: String = " · ".join(_parts.slice(0, n))
		if n < _parts.size():
			text += " · +%d" % (_parts.size() - n)
		if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width:
			_main.text = text
			return
	_main.text = _parts[0]


## Kalan süre: 24 saatten azsa "23:41:05", çoksa "2g 04s".
static func countdown(seconds: int) -> String:
	var s: int = maxi(seconds, 0)
	if s >= 86400:
		return Loc.t("%dg %02ds") % [s / 86400, (s % 86400) / 3600]
	return "%02d:%02d:%02d" % [s / 3600, (s % 3600) / 60, s % 60]


func _fit() -> void:
	var width: float = clampf(get_viewport_rect().size.x - SIDE_RESERVE * 2.0, MIN_WIDTH, MAX_WIDTH)
	_plate.custom_minimum_size.x = width
	offset_left = -width * 0.5
	offset_right = width * 0.5


func _gui_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if not tapped:
		return
	accept_event()
	_hud.router.open(&"event")   # ETKİNLİK PANOSU


func _build() -> void:
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 0)
	column.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	column.offset_top = 10.0
	add_child(column)

	_plate = PanelContainer.new()
	_plate.name = "Plate"
	_plate.mouse_filter = Control.MOUSE_FILTER_STOP
	_plate.gui_input.connect(_gui_input)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = DARK
	style.border_color = HudPalette.PLATE_SELECTED
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.shadow_color = HudPalette.SHADOW
	style.shadow_offset = Vector2(0.0, 4.0)
	style.shadow_size = 2
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	_plate.add_theme_stylebox_override(&"panel", style)
	column.add_child(_plate)

	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 12)
	_plate.add_child(row)

	var chip_box: PanelContainer = PanelContainer.new()
	chip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip_box.add_theme_stylebox_override(&"panel", _chip_style(HudPalette.PLATE_SELECTED))
	_chip = _label(22, DARK)
	chip_box.add_child(_chip)
	row.add_child(chip_box)

	var texts: VBoxContainer = VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override(&"separation", -2)
	_title = _label(11, HudPalette.PLATE_SELECTED)
	texts.add_child(_title)
	_main = _label(17, HudPalette.TEXT_LIGHT)
	_main.clip_text = true
	_main.resized.connect(_fit_main)
	texts.add_child(_main)
	row.add_child(texts)

	var clock_box: PanelContainer = PanelContainer.new()
	clock_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clock_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	clock_box.add_theme_stylebox_override(&"panel", _chip_style(HudPalette.PLATE))
	_clock = _label(16, DARK)
	clock_box.add_child(_clock)
	row.add_child(clock_box)

	# Tabelayı taşıyan kısa direk (yol tabelası dili)
	var stem: ColorRect = ColorRect.new()
	stem.color = DARK
	stem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stem.custom_minimum_size = Vector2(8.0, 10.0)
	stem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(stem)


func _chip_style(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	style.content_margin_left = 9.0
	style.content_margin_right = 9.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	return style


func _label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = &"HudSignTitle"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_constant_override(&"outline_size", 0)
	return label
