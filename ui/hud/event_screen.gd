class_name EventScreen
extends Control
## ETKİNLİK PANOSU — taslak B "ARACA GİDEN YOL" (kullanıcı 2026-10-26: "B iyi ama arka plan daha bulanık olsun ve yolun
## çizimi daha cool olsun"; tuval https://claude.ai/artifact/EZb11w5LLrPHQA2Wso8Lst). Etkinlik tabelasına (EventBanner)
## ya da garajdaki ödünç araca dokununca açılır. Arka plan bulanık oyun ekranı (vfx/screen_blur.gdshader). Üstte başlık +
## geri sayım, altında modül çipleri (dokununca oraya: MAĞAZA / KASA / GÖREVLER / ÖZEL RAKİP / DEKOR). Ortada EventRoad:
## etkinlik görevleri pistin durakları, finişte etkinlik aracı (ÖDÜNÇ; görevler bitince oyuncunun — EventCar). Altta
## ETKİNLİK YARIŞI (günde 3 hak) + reklamla +1 HAK ve TAKVİM şeridi (süren + yaklaşan etkinlikler; yaklaşanın aracı
## başlamadan reveal_days gün önce görünür, öncesinde siluet). Görevsiz etkinlikte yol yerine eski modül satırları. Etkinlik
## yokken yaklaşan etkinlik varsa yalnız takvim açılır (tabelanın YAKINDA hâli). Mantık yok: LiveEvent / MissionManager /
## EventCar / RaceManager okunur, düğmeler action_requested ile HUD'a gider. Kodla kurulur.

signal opened
signal closed
## kind: &"showroom" (arg: kasa ya da &""), &"decor", &"missions", &"race" (özel rakip), &"car_race" (etkinlik aracı).
signal action_requested(kind: StringName, arg: StringName)

const BLUR_SHADER: Shader = preload("res://vfx/screen_blur.gdshader")
## Görevsiz etkinliğin modül satırları (eski pano).
const PLATE_WIDTH: float = 480.0
const BANNER_HEIGHT: float = 104.0
const CARD_W: float = 128.0
const CARD_H: float = 58.0
const THUMB: Vector2 = Vector2(78.0, 49.0)
const FADE_TIME: float = 0.25

var _bg: ColorRect
var _blur: ShaderMaterial
var _column: VBoxContainer
var _sign: PlatePanel
var _title: Label
var _clock: Label
var _chips: HBoxContainer
var _road: EventRoad
var _list_scroll: ScrollContainer
var _body: VBoxContainer
var _bottom: HBoxContainer
var _race: PlateButton
var _ad: AdOfferButton
var _calendar_box: VBoxContainer
var _calendar: HBoxContainer
var _calendar_label: Label
var _tick: Timer
var _closing: bool = false
var _shown_key: String = ""
var _calendar_only: bool = false


func _ready() -> void:
	name = "EventScreen"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func open() -> void:
	_calendar_only = LiveEvent.current().is_empty()
	_shown_key = ""
	_refresh()
	if visible:
		return
	PlateAnim.pop_in(self, _column)
	_blur.set_shader_parameter(&"strength", 0.0)
	create_tween().tween_method(func(v: float) -> void: _blur.set_shader_parameter(&"strength", v), 0.0, 1.0, FADE_TIME)
	_tick.start()
	opened.emit()


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	_tick.stop()
	create_tween().tween_method(func(v: float) -> void: _blur.set_shader_parameter(&"strength", v), 1.0, 0.0, FADE_TIME)
	PlateAnim.pop_out(self, _column, func() -> void:
		hide()
		_closing = false
		closed.emit())


## Takvimde gösterilecek bir şey var mı (süren ya da yaklaşan etkinlik).
static func has_calendar() -> bool:
	return not LiveEvent.upcoming().is_empty()


# --- Kurulum -----------------------------------------------------------------

func _build() -> void:
	_bg = ColorRect.new()
	_bg.name = "Blur"
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_blur = ShaderMaterial.new()
	_blur.shader = BLUR_SHADER
	_bg.material = _blur
	add_child(_bg)

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: StringName in [&"margin_left", &"margin_right"]:
		margin.add_theme_constant_override(side, 14)
	margin.add_theme_constant_override(&"margin_top", 8)
	margin.add_theme_constant_override(&"margin_bottom", 10)
	add_child(margin)
	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override(&"separation", 6)
	margin.add_child(_column)

	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(top)
	var left: Control = Control.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(left)
	_sign = PlatePanel.new()
	_sign.theme_type_variation = &"HudCarPlate"
	var sign_box: VBoxContainer = VBoxContainer.new()
	sign_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sign_box.add_theme_constant_override(&"separation", 0)
	_title = _label(&"HudSignTitle", Loc.t("CANLI ETKİNLİK"))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_box.add_child(_title)
	_clock = _label(&"HudInkCaption", "")
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_box.add_child(_clock)
	_sign.add_child(sign_box)
	top.add_child(_sign)
	var right: HBoxContainer = HBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_END
	top.add_child(right)
	var close_button: PlateButton = PlateButton.new()
	close_button.name = "CloseButton"
	close_button.theme_type_variation = &"HudSign"   # sağ üst tabelalarla aynı beyaz yuvarlak
	close_button.shape = PlateButton.Shape.ROUND
	close_button.kind = HudIcon.Kind.CROSS
	close_button.icon_size = 18.0
	close_button.bolts = false
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_button.pressed.connect(close)
	right.add_child(close_button)

	_chips = HBoxContainer.new()
	_chips.name = "Chips"
	_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chips.alignment = BoxContainer.ALIGNMENT_CENTER
	_chips.add_theme_constant_override(&"separation", 6)
	_column.add_child(_chips)

	_road = EventRoad.new()
	_road.name = "Road"
	_road.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_road.claim_requested.connect(_on_claim)
	_column.add_child(_road)

	_list_scroll = ScrollContainer.new()
	_list_scroll.name = "BodyScroll"
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_list_scroll.custom_minimum_size.x = PLATE_WIDTH
	_column.add_child(_list_scroll)
	TouchScroll.attach(_list_scroll)
	_body = VBoxContainer.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL   # kaydırma kutusunu doldurur: yalnız-takvim kartları ortalanır
	_body.add_theme_constant_override(&"separation", 8)
	_list_scroll.add_child(_body)

	_bottom = HBoxContainer.new()
	_bottom.name = "Bottom"
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom.add_theme_constant_override(&"separation", 8)
	_column.add_child(_bottom)
	_race = PlateButton.new()
	_race.name = "Action_car_race"
	_race.theme_type_variation = &"HudPlateSmall"
	_race.kind = HudIcon.Kind.FLAG
	_race.icon_left = true
	_race.highlight = true
	_race.focus_mode = Control.FOCUS_NONE
	_race.custom_minimum_size = Vector2(250.0, 52.0)
	_race.size_flags_vertical = Control.SIZE_SHRINK_END
	_race.pressed.connect(func() -> void: action_requested.emit(&"car_race", &""))
	_bottom.add_child(_race)
	_ad = AdOfferButton.new(AdPolicy.EVENT_RACE, Loc.t("+1 HAK"))
	_ad.name = "EventRaceAd"
	_ad.custom_minimum_size = Vector2(150.0, 52.0)
	_ad.size_flags_vertical = Control.SIZE_SHRINK_END
	_ad.condition = func() -> bool:
		var car: EventCar = _event_car()
		return visible and not _closing and car != null and car.can_add_try()
	_ad.rewarded.connect(func() -> void:
		var car: EventCar = _event_car()
		if car:
			car.add_try()
		_shown_key = ""
		_refresh())
	_bottom.add_child(_ad)
	_calendar_box = VBoxContainer.new()
	_calendar_box.name = "Calendar"
	_calendar_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_calendar_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_calendar_box.add_theme_constant_override(&"separation", 3)
	_calendar_label = _label(&"HudOutlined", Loc.t("TAKVİM"))
	_calendar_label.add_theme_font_size_override(&"font_size", 12)
	_calendar_box.add_child(_calendar_label)
	_calendar = HBoxContainer.new()
	_calendar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_calendar.add_theme_constant_override(&"separation", 6)
	_calendar_box.add_child(_calendar)
	_bottom.add_child(_calendar_box)

	_tick = Timer.new()
	_tick.wait_time = 1.0
	_tick.timeout.connect(_refresh)
	add_child(_tick)


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _event_car() -> EventCar:
	return get_tree().get_first_node_in_group("event_car") as EventCar if is_inside_tree() else null


# --- İçerik ------------------------------------------------------------------

## Her saniye: geri sayım ve hak; etkinlik / ilerleme / takvim değiştiyse yeniden kurulur. Gösterilecek bir şey
## kalmadıysa (etkinlik bitti, takvim boş) pano kapanır.
func _refresh() -> void:
	var event: Dictionary = LiveEvent.current()
	var upcoming: Array[Dictionary] = LiveEvent.upcoming()
	if not _calendar_only and event.is_empty():
		_calendar_only = true   # etkinlik pano açıkken bitti: takvime döner
	if _calendar_only and not event.is_empty():
		_calendar_only = false
	if event.is_empty() and upcoming.is_empty():
		if visible:
			close()
		return
	if _calendar_only:
		_clock.text = Loc.t("ŞİMDİ VE YAKLAŞANLAR")
	else:
		_clock.text = Loc.t("BİTİŞE %s") % EventBanner.countdown(LiveEvent.seconds_left())
	var key: String = str([event.hash(), _missions_key(), _race_key(), _car_key(), upcoming.hash(),
		LivePacks.is_mounted(LiveEvent.pack_id()), _calendar_only])
	if key == _shown_key:
		return
	_shown_key = key
	if _calendar_only:
		_fill_calendar_only(upcoming)
	else:
		_fill(event, upcoming)


func _fill(event: Dictionary, upcoming: Array[Dictionary]) -> void:
	var title: String = SaveSafe.s(event.get("title", ""))
	_title.text = Loc.upper(title) if not title.is_empty() else Loc.t("CANLI ETKİNLİK")
	_chips.visible = true
	_fill_chips(event)
	var missions: MissionManager = get_tree().get_first_node_in_group("missions") as MissionManager
	var tasks: Array[Dictionary] = missions.event_tasks() if missions else ([] as Array[Dictionary])
	var road: bool = not tasks.is_empty()
	_road.visible = road
	_list_scroll.visible = not road
	if road:
		_road.setup(_stops(tasks), _finish(event))
	else:
		_fill_list(event)
	var car: EventCar = _event_car()
	var has_car: bool = car != null and car.active()
	_race.visible = has_car
	if has_car:
		var left: int = car.tries_left()
		_race.text = Loc.t("ETKİNLİK YARIŞI · %d / %d HAK") % [left, car.tries_total()]
		_race.disabled = left <= 0
	_ad.refresh()
	_fill_calendar(upcoming.slice(0, _calendar_room()), CARD_W, CARD_H)
	_calendar_box.visible = _calendar.get_child_count() > 0


## Alt satırda yarış / reklam düğmelerinden kalan yere sığan takvim kartı sayısı (dar tuvalde 853: 2–3).
func _calendar_room() -> int:
	var width: float = get_viewport_rect().size.x - 28.0
	var separation: float = float(_bottom.get_theme_constant(&"separation"))
	for button: Control in [_race, _ad]:
		if button.visible:
			width -= button.get_combined_minimum_size().x + separation
	var gap: float = float(_calendar.get_theme_constant(&"separation"))
	return maxi(int((width + gap) / (CARD_W + gap)), 1)


func _fill_calendar_only(upcoming: Array[Dictionary]) -> void:
	_title.text = Loc.t("ETKİNLİK TAKVİMİ")
	_chips.visible = false
	_road.visible = false
	_list_scroll.visible = true
	for child: Node in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(center)
	var cards: HBoxContainer = HBoxContainer.new()
	cards.name = "CalendarCards"
	cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cards.add_theme_constant_override(&"separation", 8)
	for entry: Dictionary in upcoming:
		cards.add_child(_card(entry, 150.0, 132.0, true))
	center.add_child(cards)
	_race.visible = false
	_ad.refresh()
	_calendar_box.visible = false


## Modül çipleri: süs (PARA ×2) ya da oraya götüren küçük plaka (Action_<tür>: testler ve HUD aynı adla bulur).
func _fill_chips(event: Dictionary) -> void:
	for child: Node in _chips.get_children():
		_chips.remove_child(child)
		child.queue_free()
	var money: float = float(event["money_mult"])
	var xp: float = float(event["xp_mult"])
	if money > 1.0:
		_chips.add_child(_chip(Loc.t("PARA ×%s") % _mult(money)))
	if xp > 1.0:
		_chips.add_child(_chip(Loc.t("XP ×%s") % _mult(xp)))
	var sale: Dictionary = event["sale"]
	if not sale.is_empty():
		var best: int = 0
		for kind: StringName in sale:
			best = maxi(best, int(sale[kind]))
		var go_decor: bool = not sale.has(&"crates") and not sale.has(&"cars") and sale.has(&"decor")
		_chips.add_child(_chip_button(Loc.t("İNDİRİM %s") % ShowroomScreen.sale_tag(best), &"decor" if go_decor else &"showroom"))
	var boost: Dictionary = event["crate_boost"]
	if not boost.is_empty():
		_chips.add_child(_chip_button(Loc.t("ETKİNLİK KASASI"), &"showroom", boost["crate"]))
	if not (event["missions"] as Array).is_empty():
		_chips.add_child(_chip_button(Loc.t("GÖREVLER"), &"missions"))
	var rival: Dictionary = event["rival"]
	if not rival.is_empty():
		var who: String = String(rival["name"]) if not String(rival["name"]).is_empty() else Loc.t("ETKİNLİK RAKİBİ")
		_chips.add_child(_chip_button(Loc.t("ÖZEL RAKİP · %s") % Loc.upper(who), &"race"))
	if not String(event["pack"]).is_empty() and LivePacks.is_mounted(LiveEvent.pack_id()):
		_chips.add_child(_chip_button(Loc.t("YENİ EŞYALAR"), &"decor"))


func _chip(text: String) -> PanelContainer:
	var chip: PanelContainer = PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color("2D2A26")
	box.border_color = HudPalette.PLATE_SELECTED
	box.set_border_width_all(2)
	box.set_corner_radius_all(12)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 2.0
	box.content_margin_bottom = 3.0
	chip.add_theme_stylebox_override(&"panel", box)
	var label: Label = _label(&"HudInkValue", text)
	label.add_theme_color_override(&"font_color", HudPalette.TEXT_LIGHT)
	label.add_theme_font_size_override(&"font_size", 12)
	chip.add_child(label)
	return chip


func _chip_button(text: String, kind: StringName, arg: StringName = &"") -> PlateButton:
	var button: PlateButton = PlateButton.new()
	button.name = "Action_%s" % kind
	button.theme_type_variation = &"HudPlateSmall"
	button.text = text
	button.highlight = kind == &"race"
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(func() -> void: action_requested.emit(kind, arg))
	return button


## Görevler pistin durakları için: metin, ilerleme, durum, ödül.
func _stops(tasks: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for task: Dictionary in tasks:
		var done: bool = bool(task["done"])
		var claimed: bool = bool(task["claimed"])
		var reward: String = LiveEvent.reward_text(task)
		out.append({"id": String(task["id"]), "text": LiveEvent.mission_text(task["metric"], int(task["target"])),
			"progress": int(task["progress"]), "target": int(task["target"]), "done": done, "claimed": claimed,
			"ready": done and not claimed and not reward.is_empty() and MissionManager._event_reward_ready(task),
			"reward": reward})
	return out


## Finiş: etkinlik aracı (ödünç / kazanıldı / zaten vardı) ya da araçsız etkinlikte kupa.
func _finish(event: Dictionary) -> Dictionary:
	var car: Dictionary = event.get("car", {})
	if car.is_empty():
		return {"car": &"", "state": &"reward", "note": Loc.t("GÖREVLERİ BİTİR")}
	var vehicle: StringName = car["id"]
	var name_text: String = String(CarCatalog.get_entry(vehicle).get("display_name", vehicle)).to_upper()
	var event_car: EventCar = _event_car()
	if event_car and event_car.is_won():
		return {"car": vehicle, "name": name_text, "state": &"won", "note": Loc.t("✔ ARAÇ SENİN!")}
	if event_car and event_car.owns_car():
		var parts: PackedStringArray = PackedStringArray()
		if int(car["owned_gems"]) > 0:
			parts.append(Loc.t("+%d GEM") % int(car["owned_gems"]))
		if StringName(car["owned_crate"]) != &"":
			parts.append(Loc.t("+1 KASA"))
		return {"car": vehicle, "name": name_text, "state": &"owned",
			"note": Loc.t("ZATEN SENDE · %s") % " ".join(parts) if not parts.is_empty() else Loc.t("ZATEN SENDE")}
	return {"car": vehicle, "name": name_text, "state": &"loan", "note": Loc.t("FİNİŞTE ARAÇ SENİN")}


func _on_claim(mission_id: String) -> void:
	var missions: MissionManager = get_tree().get_first_node_in_group("missions") as MissionManager
	if missions and missions.claim_event(mission_id):
		_shown_key = ""
		_refresh()


# --- Takvim ----------------------------------------------------------------------

func _fill_calendar(upcoming: Array[Dictionary], width: float, height: float) -> void:
	for child: Node in _calendar.get_children():
		_calendar.remove_child(child)
		child.queue_free()
	for entry: Dictionary in upcoming:
		_calendar.add_child(_card(entry, width, height, false))


## Takvim kartı: tarih / ŞİMDİ, başlık, (görünürse) aracın resmi; aracı henüz açıklanmamışsa siluet.
func _card(entry: Dictionary, width: float, height: float, tall: bool) -> PanelContainer:
	var active: bool = bool(entry["active"])
	var card: PanelContainer = PanelContainer.new()
	card.name = "Card_%s" % String(entry["id"])
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size = Vector2(width, height)
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = HudPalette.COIN if active else HudPalette.PLATE
	box.set_corner_radius_all(8)
	box.border_width_bottom = 3
	box.border_color = HudPalette.PLATE_SELECTED_EDGE if active else HudPalette.PLATE_EDGE
	box.content_margin_left = 7.0
	box.content_margin_right = 5.0
	box.content_margin_top = 3.0
	box.content_margin_bottom = 4.0
	card.add_theme_stylebox_override(&"panel", box)
	var layout: BoxContainer = VBoxContainer.new() if tall else HBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_theme_constant_override(&"separation", 2)
	card.add_child(layout)
	var texts: VBoxContainer = VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override(&"separation", 0)
	layout.add_child(texts)
	var when: String
	if active:
		when = Loc.t("ŞİMDİ · %s") % EventBanner.countdown(int(entry["end"]) - LiveEvent.now())
	else:
		when = day_text(int(entry["start"]))
	var date: Label = _label(&"HudInkCaption", when)
	date.add_theme_font_size_override(&"font_size", 9)
	texts.add_child(date)
	var title_text: String = String(entry["title"])
	var title: Label = _label(&"HudInkValue", Loc.upper(title_text) if not title_text.is_empty() else Loc.t("CANLI ETKİNLİK"))
	title.add_theme_font_size_override(&"font_size", 11)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD   # sözcük ortasından bölünmesin ("AMERİ KAN")
	title.max_lines_visible = 2
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.custom_minimum_size.x = 60.0
	texts.add_child(title)
	if tall:
		var parts: PackedStringArray = entry["parts"]
		var detail: Label = _label(&"HudInkCaption", " · ".join(parts.slice(0, 3)))
		detail.add_theme_font_size_override(&"font_size", 9)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texts.add_child(detail)
	var car: StringName = entry["car"]
	if car != &"" or bool(entry["car_hidden"]):
		var photo: TextureRect = TextureRect.new()
		photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		photo.custom_minimum_size = THUMB * (1.6 if tall else 1.0)
		photo.size_flags_vertical = Control.SIZE_SHRINK_END
		photo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if tall else Control.SIZE_SHRINK_END
		if car != &"":
			var path: String = ProfileCard.THUMB_DIR + String(car) + ".png"
			if ResourceLoader.exists(path):
				photo.texture = load(path) as Texture2D
		else:
			photo.texture = load(ProfileCard.THUMB_DIR + "porsche_gt3.png") as Texture2D
			photo.modulate = Color(0.0, 0.0, 0.0, 0.45)   # açıklanmamış araç: siluet
		layout.add_child(photo)
		if tall:
			var caption: Label = _label(&"HudInkCaption", String(CarCatalog.get_entry(car).get("display_name", car)).to_upper()
				if car != &"" else Loc.t("ARAÇ YAKINDA AÇIKLANACAK"))
			caption.add_theme_font_size_override(&"font_size", 9)
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			layout.add_child(caption)
	return card


## "4 KASIM" (yerel saat; gün-ay sırası dilden: DE "4. NOVEMBER").
static func day_text(unix: int) -> String:
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var date: Dictionary = Time.get_datetime_dict_from_unix_time(unix + bias)
	var months: Array[String] = [Loc.t("OCAK"), Loc.t("ŞUBAT"), Loc.t("MART"), Loc.t("NİSAN"), Loc.t("MAYIS"),
		Loc.t("HAZİRAN"), Loc.t("TEMMUZ"), Loc.t("AĞUSTOS"), Loc.t("EYLÜL"), Loc.t("EKİM"), Loc.t("KASIM"), Loc.t("ARALIK")]
	return Loc.t("%d %s") % [int(date["day"]), months[clampi(int(date["month"]), 1, 12) - 1]]


# --- Görevsiz etkinlik: modül satırları (eski pano) ------------------------------------

func _fill_list(event: Dictionary) -> void:
	for child: Node in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	var art: Texture2D = LivePacks.banner(LiveEvent.pack_id())
	if art:
		var banner: TextureRect = TextureRect.new()
		banner.name = "Banner"
		banner.texture = art
		banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		banner.custom_minimum_size = Vector2(PLATE_WIDTH, BANNER_HEIGHT)
		banner.clip_contents = true
		banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_body.add_child(banner)
	var text: String = SaveSafe.s(event.get("text", ""))
	if not text.is_empty():
		_body.add_child(_row("", text, "", &""))
	var money: float = float(event["money_mult"])
	var xp: float = float(event["xp_mult"])
	if money > 1.0 or xp > 1.0:
		var parts: PackedStringArray = PackedStringArray()
		if money > 1.0:
			parts.append(Loc.t("PARA ×%s") % _mult(money))
		if xp > 1.0:
			parts.append(Loc.t("XP ×%s") % _mult(xp))
		_body.add_child(_row(" · ".join(parts), Loc.t("Tamir ve yarış ödülleri etkinlik süresince artıyor."), "", &""))
	var sale: Dictionary = event["sale"]
	if not sale.is_empty():
		var parts: PackedStringArray = PackedStringArray()
		var names: Dictionary = {&"crates": "KASALAR", &"cars": "GERİ AL", &"decor": "DEKOR", &"mods": "MODİFİYE"}
		for kind: StringName in LiveEvent.SALE_KINDS:
			if sale.has(kind):
				parts.append("%s %s" % [Loc.t(names[kind]), ShowroomScreen.sale_tag(int(sale[kind]))])
		var go_decor: bool = not sale.has(&"crates") and not sale.has(&"cars") and sale.has(&"decor")
		_body.add_child(_row(Loc.t("İNDİRİM"), " · ".join(parts), Loc.t("DEKORA GİT") if go_decor else Loc.t("MAĞAZAYA GİT"),
			&"decor" if go_decor else &"showroom"))
	var boost: Dictionary = event["crate_boost"]
	if not boost.is_empty():
		var cars: PackedStringArray = PackedStringArray()
		for car: StringName in boost["cars"]:
			cars.append(String(CarCatalog.get_entry(car).get("display_name", car)).to_upper())
		var crate_name: String = Loc.t(String(CrateCatalog.get_entry(boost["crate"]).get("display_name", "")))
		_body.add_child(_row(Loc.t("ETKİNLİK KASASI · %s") % crate_name,
			Loc.t("%s çıkma şansı ×%s") % [", ".join(cars), _mult(float(boost["mult"]))], Loc.t("KASAYA GİT"),
			&"showroom", boost["crate"]))
	var rival: Dictionary = event["rival"]
	if not rival.is_empty():
		var race: RaceManager = get_tree().get_first_node_in_group("race") as RaceManager
		var car: String = String(CarCatalog.get_entry(rival["car"]).get("display_name", rival["car"])).to_upper()
		var who: String = String(rival["name"]) if not String(rival["name"]).is_empty() else Loc.t("ETKİNLİK RAKİBİ")
		var reward: String = LiveEvent.reward_text(rival)
		var taken: bool = race != null and race.event_reward_taken()
		var detail: String = Loc.t("%s · %d. KADEME MODİFİYE") % [car, int(rival["stage"])] if int(rival["stage"]) > 0 else car
		if not reward.is_empty():
			detail += "\n" + (Loc.t("ÖZEL ÖDÜL ALINDI") if taken else Loc.t("İLK GALİBİYETE: %s") % reward)
		_body.add_child(_row(Loc.t("ÖZEL RAKİP · %s") % Loc.upper(who), detail, Loc.t("YARIŞ"), &"race"))
	var pack_id: String = LiveEvent.pack_id()
	if not pack_id.is_empty():
		var items: int = 0
		for item: Variant in LivePacks.manifest(pack_id).get("decor", []):
			if item is Dictionary and bool((item as Dictionary).get("event_only", false)):
				items += 1
		if not LivePacks.is_mounted(pack_id):
			_body.add_child(_row(Loc.t("YENİ EŞYALAR"), Loc.t("Etkinlik içeriği iniyor…"), "", &""))
		elif items > 0:
			_body.add_child(_row(Loc.t("YENİ EŞYALAR"), Loc.t("%d etkinlik eşyası yalnızca etkinlik süresince satışta.") % items,
				Loc.t("DEKORA GİT"), &"decor"))


## Modül satırı: başlık + açıklama, sağda (varsa) düğme.
func _row(title: String, text: String, button_text: String, kind: StringName, arg: StringName = &"") -> PlatePanel:
	var plate: PlatePanel = PlatePanel.new()
	plate.theme_type_variation = &"HudCarPlate"
	plate.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 10)
	plate.add_child(row)
	var texts: VBoxContainer = VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override(&"separation", 2)
	if not title.is_empty():
		texts.add_child(_label(&"HudPlateTitle", title))
	var caption: Label = _label(&"HudInkCaption", text)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.custom_minimum_size = Vector2(PLATE_WIDTH - (160.0 if not button_text.is_empty() else 40.0), 0.0)
	texts.add_child(caption)
	row.add_child(texts)
	if not button_text.is_empty():
		var button: PlateButton = PlateButton.new()
		button.name = "Action_%s" % kind
		button.theme_type_variation = &"HudPlateSmall"
		button.text = button_text
		button.highlight = kind == &"race"
		button.custom_minimum_size = Vector2(110.0, 0.0)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void: action_requested.emit(kind, arg))
		row.add_child(button)
	return plate


static func _mult(value: float) -> String:
	return Loc.decimal(value, 1).trim_suffix(",0").trim_suffix(".0")


func _missions_key() -> String:
	var missions: MissionManager = get_tree().get_first_node_in_group("missions") as MissionManager
	if missions == null:
		return ""
	var done: int = 0
	for task: Dictionary in missions.event_tasks():
		done += int(task["progress"]) + (1000 if bool(task["claimed"]) else 0)
	return "%d:%d" % [done, missions.claimable_event()]


func _race_key() -> bool:
	var race: RaceManager = get_tree().get_first_node_in_group("race") as RaceManager
	return race != null and race.event_reward_taken()


func _car_key() -> String:
	var car: EventCar = _event_car()
	return str(car.state()) + str(car.owns_car()) if car else ""
