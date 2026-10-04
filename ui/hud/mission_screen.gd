class_name MissionScreen
extends Control
## GÖREVLER tabelası: GÜNLÜK · HAFTALIK · BAŞARIMLAR (+ başlangıç zinciri bitene kadar REHBER).
## Tasarım: docs/gorevler_tasarimi.md §9. Ekran TAMAMEN KODLA kurulur (.tscn yok); HUD onu temalı Root'un
## altına ekler. Mantık burada değil: görevler MissionManager'da ("missions" grubu), rehber zinciri
## QuestManager'da ("quests" grubu); bu ekran yalnızca gösterir ve ÖDÜLÜ AL'ı onlara iletir.
## Kısa ekranda (480 birim) başlık, sekmeler ve KAPAT sabit kalır; yalnızca gövde kaydırılır (çubuksuz,
## dokunmatik: TouchScroll). Oyunu engellemez: KAPAT ile oyun sürer.

signal opened
signal closed
## Ödül alındı (HUD kısa bildirim gösterir).
signal reward_claimed(text: String)

enum Tab { DAILY, WEEKLY, ACHIEVEMENTS, GUIDE }

const PLATE_WIDTH: float = 480.0
const TIER_NAMES: Array[String] = ["KOLAY", "ORTA", "ZOR"]

var _missions: MissionManager
var _quests: QuestManager
var _tab: int = Tab.DAILY
var _tabs: Dictionary = {}
var _tab_group: ButtonGroup = ButtonGroup.new()
var _column: VBoxContainer
var _sign: PlatePanel
var _tab_row: HBoxContainer
var _footer: HBoxContainer
var _claim_all: PlateButton
var _close_button: PlateButton
var _body_scroll: ScrollContainer
var _body: VBoxContainer
var _countdown: Label
var _closing: bool = false
var _tick: Timer


func _ready() -> void:
	name = "MissionScreen"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # açıkken dünyaya tıklama gitmez
	_build()
	_connect.call_deferred()


func open() -> void:
	_select_default_tab()
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
	var title: Label = _label(&"HudSignTitle", Loc.t("GÖREVLER"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sign.add_child(title)
	_column.add_child(_sign)

	_tab_row = HBoxContainer.new()
	_tab_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_tab_row.add_theme_constant_override(&"separation", 6)
	_column.add_child(_tab_row)
	for entry: Array in [[Tab.DAILY, Loc.t("GÜNLÜK")], [Tab.WEEKLY, Loc.t("HAFTALIK")], [Tab.ACHIEVEMENTS, Loc.t("BAŞARIMLAR")], [Tab.GUIDE, Loc.t("REHBER")]]:
		var tab: PlateButton = PlateButton.new()
		tab.theme_type_variation = &"HudPlateSmall"
		tab.text = entry[1]
		tab.toggle_mode = true
		tab.button_group = _tab_group
		tab.focus_mode = Control.FOCUS_NONE
		tab.bolts = false
		tab.pressed.connect(_on_tab_pressed.bind(int(entry[0])))
		_tab_row.add_child(tab)
		_tabs[int(entry[0])] = tab

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
	_footer.add_theme_constant_override(&"separation", 8)
	_footer.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	_column.add_child(_footer)
	_claim_all = PlateButton.new()
	_claim_all.theme_type_variation = &"HudPlateSmall"
	_claim_all.text = Loc.t("HEPSİNİ AL")
	_claim_all.focus_mode = Control.FOCUS_NONE
	_claim_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_claim_all.pressed.connect(_on_claim_all)
	_footer.add_child(_claim_all)
	_close_button = PlateButton.new()
	_close_button.theme_type_variation = &"HudPlateSmall"
	_close_button.text = Loc.t("KAPAT")
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_close_button.pressed.connect(close)
	_footer.add_child(_close_button)

	_tick = Timer.new()
	_tick.wait_time = 1.0
	_tick.timeout.connect(_update_countdown)
	add_child(_tick)
	get_viewport().size_changed.connect(_fit_body)


func _connect() -> void:
	_missions = get_tree().get_first_node_in_group("missions") as MissionManager
	_quests = get_tree().get_first_node_in_group("quests") as QuestManager
	if _missions:
		_missions.missions_changed.connect(_refresh)
	if _quests:
		_quests.quests_changed.connect(_refresh)


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


# --- Sekmeler ----------------------------------------------------------------

func _guide_active() -> bool:
	return _quests != null and not _quests.all_done()


## Açılışta: ödülü alınabilir ilk sekme; yoksa GÜNLÜK (görevler kilitliyse REHBER).
func _select_default_tab() -> void:
	var pick: int = Tab.DAILY
	if _guide_active() and (_missions == null or not _missions.is_unlocked()):
		pick = Tab.GUIDE   # yeni oyuncu: günlük / haftalık henüz kilitli, rehber zinciri yol gösterir
	elif _missions and _missions.claimable_daily() > 0:
		pick = Tab.DAILY
	elif _missions and _missions.claimable_weekly() > 0:
		pick = Tab.WEEKLY
	elif _missions and _missions.claimable_achievements() > 0:
		pick = Tab.ACHIEVEMENTS
	elif _guide_active() and _quests.claimable_count() > 0:
		pick = Tab.GUIDE
	_set_tab(pick)


func _set_tab(tab: int) -> void:
	_tab = tab
	(_tabs[tab] as PlateButton).set_pressed_no_signal(true)


func _on_tab_pressed(tab: int) -> void:
	_tab = tab
	_body_scroll.scroll_vertical = 0
	_refresh()


# --- Gövde ------------------------------------------------------------------------

func _refresh() -> void:
	if _body == null:
		return
	(_tabs[Tab.GUIDE] as PlateButton).visible = _guide_active()
	if _tab == Tab.GUIDE and not _guide_active():
		_set_tab(Tab.DAILY)
	_badge(Tab.DAILY, _missions.claimable_daily() if _missions else 0)
	_badge(Tab.WEEKLY, _missions.claimable_weekly() if _missions else 0)
	_badge(Tab.ACHIEVEMENTS, _missions.claimable_achievements() if _missions else 0)
	_badge(Tab.GUIDE, _quests.claimable_count() if _quests else 0)
	for child: Node in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_countdown = null
	match _tab:
		Tab.DAILY:
			_render_daily()
		Tab.WEEKLY:
			_render_weekly()
		Tab.ACHIEVEMENTS:
			_render_achievements()
		Tab.GUIDE:
			_render_guide()
	_claim_all.visible = _tab != Tab.GUIDE and _claimable_in_tab() > 0
	_claim_all.highlight = _claim_all.visible
	_fit_body.call_deferred()
	if not get_tree().process_frame.is_connected(_fit_body):
		get_tree().process_frame.connect(_fit_body, CONNECT_ONE_SHOT)


func _badge(tab: int, count: int) -> void:
	var button: PlateButton = _tabs[tab]
	var base: String = [Loc.t("GÜNLÜK"), Loc.t("HAFTALIK"), Loc.t("BAŞARIMLAR"), Loc.t("REHBER")][tab]
	button.text = "%s (%d)" % [base, count] if count > 0 else base
	button.highlight = count > 0


func _claimable_in_tab() -> int:
	if _missions == null:
		return 0
	match _tab:
		Tab.DAILY: return _missions.claimable_daily()
		Tab.WEEKLY: return _missions.claimable_weekly()
		Tab.ACHIEVEMENTS: return _missions.claimable_achievements()
	return 0


func _on_claim_all() -> void:
	if _missions == null:
		return
	match _tab:
		Tab.DAILY: _missions.claim_all_daily()
		Tab.WEEKLY: _missions.claim_all_weekly()
		Tab.ACHIEVEMENTS: _missions.claim_all_achievements()


## Gövde ekrandan uzunsa kaydırma alanı, sabit parçalar (başlık, sekmeler, alt düğmeler) düştükten
## sonra kalan yüksekliğe kısılır: KAPAT hep görünür kalır.
func _fit_body() -> void:
	if _body_scroll == null or _sign == null:
		return
	var separation: float = float(_column.get_theme_constant(&"separation"))
	var fixed: float = _sign.get_combined_minimum_size().y + _tab_row.get_combined_minimum_size().y \
			+ _footer.get_combined_minimum_size().y + separation * 3.0 + 12.0
	var available: float = get_viewport_rect().size.y - fixed
	var wanted: float = _body.get_combined_minimum_size().y
	_body_scroll.custom_minimum_size = Vector2(PLATE_WIDTH, minf(wanted, available))


# --- GÜNLÜK ----------------------------------------------------------------------------

func _render_daily() -> void:
	if _missions == null:
		return
	if not _missions.is_unlocked():
		_body.add_child(_note(Loc.t("GÜNLÜK GÖREVLER SEVİYE %d'TE AÇILIR") % MissionCatalog.MIN_LEVEL,
			Loc.t("Önce REHBER görevlerini tamamla: tamir yap, garajını büyüt.")))
		return
	var tasks: Array[Dictionary] = _missions.daily_tasks()
	for i: int in tasks.size():
		_body.add_child(_task_plate(tasks[i], false, i))
	_body.add_child(_bonus_plate(
		Loc.t("BÜTÜN GÖREVLER"), Loc.t("+%d GEM") % MissionCatalog.DAILY_BONUS_GEMS,
		_missions.daily_all_done(), _missions.daily_bonus_claimed(), _missions.claim_daily_bonus,
		"%d / %d" % [_done_count(tasks), tasks.size()]))
	_countdown = _label(&"HudInkCaption", "")
	_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(_countdown)
	_update_countdown()


# --- HAFTALIK --------------------------------------------------------------------------

func _render_weekly() -> void:
	if _missions == null:
		return
	if not _missions.is_unlocked():
		_body.add_child(_note(Loc.t("HAFTALIK GÖREVLER SEVİYE %d'TE AÇILIR") % MissionCatalog.MIN_LEVEL,
			Loc.t("Günlük görevlerin tamamlayıcısı: hafta boyunca uğraşacağın 5 zor görev.")))
		return
	var tasks: Array[Dictionary] = _missions.weekly_tasks()
	for i: int in tasks.size():
		_body.add_child(_task_plate(tasks[i], true, i))
	_body.add_child(_bonus_plate(
		Loc.t("BÜYÜK ÖDÜL"), Loc.t("+%d GEM  +1 KASA") % MissionCatalog.WEEKLY_BONUS_GEMS,
		_missions.weekly_all_done(), _missions.weekly_final_claimed(), _missions.claim_weekly_bonus,
		"%d / %d" % [_done_count(tasks), tasks.size()]))
	_countdown = _label(&"HudInkCaption", "")
	_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(_countdown)
	_update_countdown()


static func _done_count(tasks: Array[Dictionary]) -> int:
	var n: int = 0
	for task: Dictionary in tasks:
		if bool(task.get("done", false)):
			n += 1
	return n


## Tek görev plakası: başlık (kademe), ilerleme şeridi + sayı, ödül; sağda ÖDÜLÜ AL / DEVAM / ALINDI.
func _task_plate(task: Dictionary, weekly: bool, index: int) -> PlatePanel:
	var target: int = int(task["target"])
	var value: int = _missions.progress_of(task, weekly)
	var done: bool = bool(task.get("done", false))
	var claimed: bool = bool(task.get("claimed", false))
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
	texts.add_child(_label(&"HudPlateTitle", MissionCatalog.text_of(task["id"], target)))
	var gauge_row: HBoxContainer = HBoxContainer.new()
	gauge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gauge_row.add_theme_constant_override(&"separation", 8)
	var gauge: XpLane = XpLane.new()
	gauge.custom_minimum_size = Vector2(150.0, 8.0)
	gauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gauge.segments = 10
	gauge.ratio = float(value) / float(maxi(target, 1))
	gauge_row.add_child(gauge)
	gauge_row.add_child(_label(&"HudInkCaption", "%s / %s" % [Hud.format_thousands(value), Hud.format_thousands(target)]))
	texts.add_child(gauge_row)
	var reward: Label = _label(&"HudInkCaption", _reward_text(task, weekly))
	reward.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
	texts.add_child(reward)
	row.add_child(texts)
	var button: PlateButton = _claim_button(done, claimed)
	button.pressed.connect(func() -> void:
		if weekly:
			_claimed(_missions.claim_weekly(index))
		else:
			_claimed(_missions.claim_daily(index)))
	row.add_child(button)
	return plate


func _reward_text(task: Dictionary, weekly: bool) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if int(task.get("money", 0)) > 0:
		parts.append("+%s ₺" % Hud.format_thousands(int(task["money"])))
	if int(task.get("gems", 0)) > 0:
		parts.append(Loc.t("+%d GEM") % int(task["gems"]))
	if int(task.get("xp", 0)) > 0:
		parts.append(Loc.t("+%d XP") % int(task["xp"]))
	var prefix: String = "" if weekly else "%s  ·  " % Loc.t(TIER_NAMES[clampi(int(task.get("tier", 0)), 0, 2)])
	return prefix + "   ".join(parts)


func _claim_button(done: bool, claimed: bool) -> PlateButton:
	var button: PlateButton = PlateButton.new()
	button.theme_type_variation = &"HudPlateSmall"
	button.text = Loc.t("ALINDI") if claimed else (Loc.t("ÖDÜLÜ AL") if done else Loc.t("DEVAM"))
	button.disabled = claimed or not done
	button.highlight = done and not claimed
	button.custom_minimum_size = Vector2(100.0, 0.0)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	return button


## "Hepsi tamam" şeridi (günlük bonus / haftalık büyük ödül).
func _bonus_plate(title: String, reward: String, ready: bool, claimed: bool, claim: Callable, progress: String) -> PlatePanel:
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
	texts.add_child(_label(&"HudPlateTitle", "%s   ·   %s" % [title, progress]))
	var gem_label: Label = _label(&"HudInkCaption", reward)
	gem_label.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
	texts.add_child(gem_label)
	row.add_child(texts)
	var button: PlateButton = _claim_button(ready, claimed)
	button.pressed.connect(func() -> void: _claimed(claim.call()))
	row.add_child(button)
	return plate


func _note(title: String, text: String) -> PlatePanel:
	var plate: PlatePanel = PlatePanel.new()
	plate.theme_type_variation = &"HudCarPlate"
	plate.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_label(&"HudPlateTitle", title))
	var caption: Label = _label(&"HudInkCaption", text)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.custom_minimum_size = Vector2(PLATE_WIDTH - 40.0, 0.0)
	box.add_child(caption)
	plate.add_child(box)
	return plate


func _claimed(ok: Variant) -> void:
	if bool(ok):
		_refresh()


## Yenilenmeye kalan süre (günlük: gece yarısı, haftalık: Pazartesi 00:00).
func _update_countdown() -> void:
	if _countdown == null or not is_instance_valid(_countdown) or _missions == null:
		return
	var seconds: int = _missions.seconds_to_week_reset() if _tab == Tab.WEEKLY else _missions.seconds_to_reset()
	var hours: int = seconds / 3600
	var minutes: int = (seconds % 3600) / 60
	if _tab == Tab.WEEKLY:
		_countdown.text = Loc.t("HAFTALIK GÖREVLER %d GÜN %02d SAAT SONRA YENİLENİR") % [hours / 24, hours % 24]
	else:
		_countdown.text = Loc.t("GÜNLÜK GÖREVLER %02d:%02d SONRA YENİLENİR") % [hours, minutes]


# --- BAŞARIMLAR -----------------------------------------------------------------------

func _render_achievements() -> void:
	if _missions == null:
		return
	var total: int = _missions.value_of(&"ach_stars")
	_body.add_child(_label(&"HudInkCaption", Loc.t("TOPLAM %d BAŞARIM YILDIZI") % total))
	for line: Dictionary in _missions.achievements():
		_body.add_child(_achievement_plate(line))


func _achievement_plate(line: Dictionary) -> PlatePanel:
	var tiers: Array = line["tiers"]
	var reached: int = _missions.stars_reached(line)
	var claimed: int = _missions.stars_claimed(line)
	var value: int = _missions.value_of(line["metric"])
	var complete: bool = reached >= tiers.size()
	var next_index: int = mini(reached, tiers.size() - 1)
	var threshold: int = int(tiers[next_index])
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
	var stars: String = "★".repeat(reached) + "☆".repeat(tiers.size() - reached)
	texts.add_child(_label(&"HudPlateTitle", "%s   %s" % [Loc.t(String(line["title"])), stars]))
	var line_text: String = Loc.tn(String(line["text"]), threshold)
	var text: Label = _label(&"HudInkCaption", line_text % Hud.format_thousands(threshold) if line_text.contains("%s") else line_text)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(250.0, 0.0)
	texts.add_child(text)
	var gauge_row: HBoxContainer = HBoxContainer.new()
	gauge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gauge_row.add_theme_constant_override(&"separation", 8)
	var gauge: XpLane = XpLane.new()
	gauge.custom_minimum_size = Vector2(150.0, 8.0)
	gauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gauge.segments = 10
	gauge.ratio = 1.0 if complete else float(mini(value, threshold)) / float(maxi(threshold, 1))
	gauge_row.add_child(gauge)
	gauge_row.add_child(_label(&"HudInkCaption", "%s / %s" % [Hud.format_thousands(mini(value, threshold)), Hud.format_thousands(threshold)]))
	texts.add_child(gauge_row)
	var star_index: int = mini(claimed, tiers.size() - 1)
	var reward: Label = _label(&"HudInkCaption", Loc.t("%d. YILDIZ  ·  +%d GEM   +%s ₺   +%d XP") % [
		star_index + 1, MissionCatalog.ach_gems(line, star_index), Hud.format_thousands(MissionCatalog.ach_money(line, star_index)),
		MissionCatalog.ach_xp(line, star_index)] if claimed < tiers.size() else Loc.t("TÜM YILDIZLAR ALINDI"))
	reward.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
	texts.add_child(reward)
	row.add_child(texts)
	var ready: bool = claimed < reached
	var button: PlateButton = _claim_button(ready, claimed >= tiers.size())
	button.pressed.connect(func() -> void: _claimed(_missions.claim_achievement(line["id"])))
	row.add_child(button)
	return plate


# --- REHBER (başlangıç zinciri) ------------------------------------------------------

func _render_guide() -> void:
	if _quests == null:
		return
	for entry: Dictionary in _quests.active_quests():
		_body.add_child(_guide_plate(entry))


func _guide_plate(entry: Dictionary) -> PlatePanel:
	var quest_id: StringName = entry["id"]
	var target: int = int(entry["target"])
	var value: int = _quests.progress(quest_id)
	var done: bool = _quests.is_complete(quest_id)
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
	texts.add_child(_label(&"HudPlateTitle", Loc.t(String(entry["title"]))))
	texts.add_child(_label(&"HudInkCaption", Loc.t(String(entry["text"]))))
	var gauge_row: HBoxContainer = HBoxContainer.new()
	gauge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gauge_row.add_theme_constant_override(&"separation", 8)
	var gauge: XpLane = XpLane.new()
	gauge.custom_minimum_size = Vector2(150.0, 8.0)
	gauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gauge.segments = 10
	gauge.ratio = float(value) / float(maxi(target, 1))
	gauge_row.add_child(gauge)
	gauge_row.add_child(_label(&"HudInkCaption", _count_text(entry, value)))
	texts.add_child(gauge_row)
	var reward: Label = _label(&"HudInkCaption", _guide_reward_text(entry))
	reward.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
	texts.add_child(reward)
	row.add_child(texts)
	var button: PlateButton = _claim_button(done, false)
	button.pressed.connect(func() -> void:
		if _quests.claim(quest_id):
			reward_claimed.emit(_guide_reward_text(entry))
		_refresh())
	row.add_child(button)
	return plate


static func _count_text(entry: Dictionary, value: int) -> String:
	var target: int = int(entry["target"])
	if int(entry["type"]) == QuestCatalog.Type.REPAIR_MONEY:
		return "%s / %s ₺" % [Hud.format_thousands(value), Hud.format_thousands(target)]
	return "%d / %d" % [value, target]


static func _guide_reward_text(entry: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if int(entry.get("xp", 0)) > 0:
		parts.append(Loc.t("+%d XP") % int(entry["xp"]))
	if int(entry.get("gems", 0)) > 0:
		parts.append(Loc.t("+%d GEM") % int(entry["gems"]))
	if int(entry.get("money", 0)) > 0:
		parts.append("+%s ₺" % Hud.format_thousands(int(entry["money"])))
	if StringName(entry.get("crate", &"")) != &"":
		parts.append("+1 %s" % Loc.t(String(CrateCatalog.get_entry(entry["crate"]).get("display_name", Loc.t("KASA")))))
	return "   ".join(parts)
