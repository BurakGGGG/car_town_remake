class_name EventScreen
extends Control
## ETKİNLİK PANOSU (2026-10-23): canlı etkinlik tabelasına (EventBanner) dokununca açılır. Başlık + geri sayım, içerik
## paketinin afişi (varsa), panelin açıklaması ve etkinliğin her modülü için bir satır — ne olduğu ve oraya götüren düğme:
##   ÇİFTE PARA / XP · İNDİRİM (→ showroom / dekor) · ETKİNLİK KASASI (→ o kasa) · GÖREVLER (→ GÖREVLER / ETKİNLİK sekmesi)
##   · ÖZEL RAKİP (→ pist doğrudan açılır) · YENİ EŞYALAR (→ garajı düzenle)
## Mantık yok: veriler LiveEvent / MissionManager / RaceManager'dan, düğmeler action_requested ile HUD'a gider. Kodla kurulur.

signal opened
signal closed
## kind: &"showroom" (arg: kasa ya da &""), &"decor", &"missions", &"race".
signal action_requested(kind: StringName, arg: StringName)

const PLATE_WIDTH: float = 480.0
const BANNER_HEIGHT: float = 104.0

var _column: VBoxContainer
var _sign: PlatePanel
var _title: Label
var _clock: Label
var _body_scroll: ScrollContainer
var _body: VBoxContainer
var _footer: HBoxContainer
var _tick: Timer
var _closing: bool = false
var _shown_key: String = ""


func _ready() -> void:
	name = "EventScreen"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func open() -> void:
	_shown_key = ""
	_refresh()
	if visible:
		return
	PlateAnim.pop_in(self, _column)
	_tick.start()
	opened.emit()


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	_tick.stop()
	PlateAnim.pop_out(self, _column, func() -> void:
		hide()
		_closing = false
		closed.emit())


# --- Kurulum -----------------------------------------------------------------

func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center: CenterContainer = FitScroll.center_in(self)
	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override(&"separation", 8)
	center.add_child(_column)

	_sign = PlatePanel.new()
	_sign.theme_type_variation = &"HudCarPlate"
	_sign.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
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
	_column.add_child(_sign)

	_body_scroll = ScrollContainer.new()
	_body_scroll.name = "BodyScroll"
	_body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_column.add_child(_body_scroll)
	TouchScroll.attach(_body_scroll)
	_body = VBoxContainer.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_theme_constant_override(&"separation", 8)
	_body_scroll.add_child(_body)

	_footer = HBoxContainer.new()
	_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_footer.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	_column.add_child(_footer)
	var close_button: PlateButton = PlateButton.new()
	close_button.name = "CloseButton"
	close_button.theme_type_variation = &"HudPlateSmall"
	close_button.text = Loc.t("KAPAT")
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button.pressed.connect(close)
	_footer.add_child(close_button)

	_tick = Timer.new()
	_tick.wait_time = 1.0
	_tick.timeout.connect(_refresh)
	add_child(_tick)
	get_viewport().size_changed.connect(_fit_body)


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


# --- İçerik ------------------------------------------------------------------

## Her saniye: geri sayım; etkinlik ya da ilerleme değiştiyse satırlar yeniden kurulur. Etkinlik bittiyse pano kapanır.
func _refresh() -> void:
	var event: Dictionary = LiveEvent.current()
	if event.is_empty():
		if visible:
			close()
		return
	_clock.text = Loc.t("BİTİŞE %s") % EventBanner.countdown(LiveEvent.seconds_left())
	var key: String = str([event.hash(), _missions_key(), _race_key(), LivePacks.is_mounted(LiveEvent.pack_id())])
	if key == _shown_key:
		return
	_shown_key = key
	var title: String = SaveSafe.s(event.get("title", ""))
	_title.text = Loc.upper(title) if not title.is_empty() else Loc.t("CANLI ETKİNLİK")
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
	_add_modules(event)
	_fit_body.call_deferred()


func _add_modules(event: Dictionary) -> void:
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
	var missions: MissionManager = get_tree().get_first_node_in_group("missions") as MissionManager
	var tasks: Array[Dictionary] = missions.event_tasks() if missions else []
	if not tasks.is_empty():
		var done: int = 0
		for task: Dictionary in tasks:
			if bool(task["done"]):
				done += 1
		var ready: int = missions.claimable_event()
		_body.add_child(_row(Loc.t("ETKİNLİK GÖREVLERİ · %d / %d") % [done, tasks.size()],
			Loc.t("%d ödül hazır") % ready if ready > 0 else Loc.t("Görevleri bitir, ödülleri topla."),
			Loc.t("GÖREVLER"), &"missions"))
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
		button.highlight = kind == &"race" or kind == &"missions"
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


## Gövde ekrandan uzunsa kaydırılır; başlık ve KAPAT hep görünür (GÖREVLER panosuyla aynı kural).
func _fit_body() -> void:
	if _body_scroll == null or not is_inside_tree():
		return
	var separation: float = float(_column.get_theme_constant(&"separation"))
	var fixed: float = _sign.get_combined_minimum_size().y + _footer.get_combined_minimum_size().y + separation * 2.0 + 12.0
	var available: float = get_viewport_rect().size.y - fixed
	_body_scroll.custom_minimum_size = Vector2(PLATE_WIDTH, minf(_body.get_combined_minimum_size().y, available))
