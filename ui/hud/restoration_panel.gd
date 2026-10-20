class_name RestorationPanel
extends Control
## RESTORASYON PANOSU — garajdaki projeye dokununca açılır (UiRouter'da MODAL). Mantık JunkyardManager'da;
## burası yalnızca gösterir ve çağırır.
##   * İlerleme çubuğu + aşama (çıplak şasi / paslı araç / hazır).
##   * Parça satırları: takılan / gereken, envanterdeki adet; TAK (envanterden), eksiği gemle AL.
##   * HEPSİNİ TAK, EKSİKLERİ AL (tek ödeme), %100'de BİTİR (araç garaja girer), PROJEYİ BIRAK.
##   * Eksik parçayı ARKADAŞLARDAN İSTE (6 saatte bir; SocialManager.ask_part — Google girişi ve en az bir
##     arkadaş gerekir, yoksa düğme görünmez).
## GEM HARCAYAN ve PROJEYİ BIRAKAN her işlem önce onay ister (orijinaldeki onaysız "Buy All" en çok
## şikâyet edilen şeydi — docs/HURDALIK_ARASTIRMA.md). Gem yetmezse GEM MAĞAZASI önerilir.

signal closed
signal screen_requested(id: StringName)
## Proje bitti: araç garaja girdi (HUD kutlar).
signal project_finished(vehicle_id: StringName)

const PANEL_WIDTH: float = 540.0
const ICON_SIZE: float = 36.0
## Parça listesi kısa ekranda bundan kısa olmaz (iki satır); pano kadrajın üst / altında bu payı bırakır.
const ROWS_MIN_HEIGHT: float = 84.0
const FIT_MARGIN: float = 10.0

var vehicle_id: StringName = &""
var _column: VBoxContainer
var _title: Label
var _stage_label: Label
var _notice_label: Label
var _bar: ProgressStrip
var _rows: VBoxContainer
## Parça satırlarının kabı: kısa tuvalde (telefon, 480 birim) 6 satır + başlık + düğmeler ekrana sığmıyor,
## HEPSİNİ TAK / KAPAT ekranın altında kalıyordu. Satırlar kalan yüksekliğe sığar, gerisi parmakla kaydırılır.
var _rows_scroll: ScrollContainer
var _gem_label: Label
var _install_all: PlateButton
var _buy_all: PlateButton
var _finish: PlateButton
var _quit: PlateButton
var _confirm_layer: Control
var _confirm_label: Label
var _confirm_yes: PlateButton
var _confirm_action: Callable = Callable()
var _closing: bool = false


func _ready() -> void:
	name = "RestorationPanel"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func open() -> void:
	var jy: JunkyardManager = _jy()
	if jy and not jy.junkyard_changed.is_connected(_refresh):
		jy.junkyard_changed.connect(_refresh)
	var player: PlayerProgress = _player()
	if player and not player.gems_changed.is_connected(_on_gems):
		player.gems_changed.connect(_on_gems)
	var social: SocialManager = get_tree().get_first_node_in_group("social") as SocialManager
	if social and not social.notice.is_connected(_on_social_notice):
		social.notice.connect(_on_social_notice)
		social.changed.connect(_refresh)
	_notice_label.visible = false
	_confirm_layer.hide()
	_refresh()
	PlateAnim.pop_in(self, _column)


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	var jy: JunkyardManager = _jy()
	if jy and jy.junkyard_changed.is_connected(_refresh):
		jy.junkyard_changed.disconnect(_refresh)
	var player: PlayerProgress = _player()
	if player and player.gems_changed.is_connected(_on_gems):
		player.gems_changed.disconnect(_on_gems)
	var social: SocialManager = get_tree().get_first_node_in_group("social") as SocialManager
	if social and social.notice.is_connected(_on_social_notice):
		social.notice.disconnect(_on_social_notice)
		social.changed.disconnect(_refresh)
	PlateAnim.pop_out(self, _column, func() -> void:
		hide()
		_closing = false
		closed.emit())


# --- Kurulum -----------------------------------------------------------------------

func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center: CenterContainer = FitScroll.center_in(self)
	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override(&"separation", 6)
	center.add_child(_column)

	var head: PlatePanel = PlatePanel.new()
	head.theme_type_variation = &"HudCarPlate"
	head.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	var head_box: VBoxContainer = VBoxContainer.new()
	head_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head_box.add_theme_constant_override(&"separation", 3)
	_title = _label(&"HudPlateTitle", "")
	_stage_label = _label(&"HudInkCaption", "")
	_bar = ProgressStrip.new()
	_bar.custom_minimum_size = Vector2(0.0, 14.0)
	head_box.add_child(_title)
	head_box.add_child(_stage_label)
	head_box.add_child(_bar)
	_notice_label = _label(&"HudInkCaption", "")
	_notice_label.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
	_notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice_label.visible = false
	head_box.add_child(_notice_label)
	head.add_child(head_box)
	_column.add_child(head)

	var body: PlatePanel = PlatePanel.new()
	body.theme_type_variation = &"HudCarPlate"
	body.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	var body_box: VBoxContainer = VBoxContainer.new()
	body_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_box.add_theme_constant_override(&"separation", 4)
	var caption_row: HBoxContainer = HBoxContainer.new()
	caption_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_row.add_child(_label(&"HudInkCaption", Loc.t("PARÇALAR")))
	var spacer: Control = Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption_row.add_child(spacer)
	_gem_label = _label(&"HudInkCaption", "")
	caption_row.add_child(_gem_label)
	body_box.add_child(caption_row)
	_rows_scroll = ScrollContainer.new()
	_rows_scroll.name = "PartScroll"
	_rows_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rows_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_rows_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	body_box.add_child(_rows_scroll)
	_rows = VBoxContainer.new()
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.add_theme_constant_override(&"separation", 4)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.minimum_size_changed.connect(_fit_rows, CONNECT_DEFERRED)
	_rows_scroll.add_child(_rows)
	TouchScroll.attach(_rows_scroll)
	get_viewport().size_changed.connect(_fit_rows, CONNECT_DEFERRED)
	body.add_child(body_box)
	_column.add_child(body)

	var actions: HBoxContainer = HBoxContainer.new()
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override(&"separation", 8)
	_install_all = _button(Loc.t("HEPSİNİ TAK"), _on_install_all, &"HudPlate")
	_buy_all = _button("", _on_buy_all, &"HudPlate")
	_finish = _button(Loc.t("BİTİR"), _on_finish, &"HudPlate")
	_finish.highlight = true
	actions.add_child(_install_all)
	actions.add_child(_buy_all)
	actions.add_child(_finish)
	_column.add_child(actions)

	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override(&"separation", 8)
	_quit = _button(Loc.t("PROJEYİ BIRAK"), _on_quit)
	bottom.add_child(_quit)
	bottom.add_child(_button(Loc.t("KAPAT"), close))
	_column.add_child(bottom)
	_build_confirm()


## Onay katmanı: soru + EVET / VAZGEÇ (gem harcama, projeyi bırakma).
func _build_confirm() -> void:
	_confirm_layer = Control.new()
	_confirm_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_layer.visible = false
	add_child(_confirm_layer)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.35)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_layer.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_layer.add_child(center)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 6)
	center.add_child(column)
	var plate: PlatePanel = PlatePanel.new()
	plate.theme_type_variation = &"HudCarPlate"
	plate.custom_minimum_size = Vector2(PANEL_WIDTH * 0.8, 0.0)
	_confirm_label = _label(&"HudInkValue", "")
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	plate.add_child(_confirm_label)
	column.add_child(plate)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 8)
	_confirm_yes = _button(Loc.t("EVET"), func() -> void:
		_confirm_layer.hide()
		if _confirm_action.is_valid():
			_confirm_action.call(), &"HudPlate")
	row.add_child(_confirm_yes)
	row.add_child(_button(Loc.t("VAZGEÇ"), func() -> void: _confirm_layer.hide()))
	column.add_child(row)


func _ask(question: String, yes_text: String, action: Callable) -> void:
	_confirm_label.text = question
	_confirm_yes.text = yes_text
	_confirm_action = action
	_confirm_layer.show()


# --- Güncelleme ----------------------------------------------------------------------

func _refresh() -> void:
	var jy: JunkyardManager = _jy()
	if jy == null or vehicle_id == &"":
		return
	if not jy.has_project(vehicle_id):
		close()   # proje bitti / bırakıldı (başka yoldan)
		return
	var entry: Dictionary = CarCatalog.get_entry(vehicle_id)
	_title.text = String(entry.get("display_name", vehicle_id)).to_upper()
	var value: float = jy.progress(vehicle_id)
	var stage: String = Loc.t("HAZIR — BİTİR'E BAS") if value >= 1.0 else (Loc.t("PASLI KASA") \
		if value >= RestorationDisplay.STAGE_RUSTY else Loc.t("ÇIPLAK ŞASİ"))
	_stage_label.text = Loc.t("RESTORASYON  %%%d  ·  %s") % [int(floorf(value * 100.0)), stage]
	_bar.ratio = value
	_on_gems(_player().gems if _player() else 0)
	for child: Node in _rows.get_children():
		child.queue_free()
	var recipe: Dictionary = RestorationCatalog.recipe(vehicle_id)
	var any_installable: bool = false
	for part_id: StringName in recipe:
		var need: int = int(recipe[part_id])
		var done: int = jy.installed(vehicle_id, part_id)
		var missing: int = jy.missing(vehicle_id, part_id)
		var have: int = jy.part_count(part_id)
		if missing > 0 and have > 0:
			any_installable = true
		_rows.add_child(_part_row(part_id, need, done, missing, have, jy.missing_gem_cost(vehicle_id, part_id)))
	_install_all.disabled = not any_installable
	var total_cost: int = _cost_after_inventory(jy)
	_buy_all.visible = value < 1.0 and total_cost > 0
	_buy_all.text = Loc.t("EKSİKLERİ AL  %d GEM") % total_cost
	_finish.visible = value >= 1.0
	_install_all.visible = value < 1.0
	_quit.visible = value < 1.0


## Parça listesinin boyu: içerik kadar; pano ekrandan uzun olacaksa kalan yükseklik kadar (en az iki satır).
func _fit_rows() -> void:
	var rows: float = _rows.get_combined_minimum_size().y
	var others: float = _column.get_combined_minimum_size().y - _rows_scroll.custom_minimum_size.y
	var room: float = get_viewport_rect().size.y - FIT_MARGIN * 2.0 - others
	var height: float = floorf(clampf(room, minf(rows, ROWS_MIN_HEIGHT), rows))
	if not is_equal_approx(_rows_scroll.custom_minimum_size.y, height):
		_rows_scroll.custom_minimum_size.y = height


## Envanterdekiler takıldıktan sonra kalan eksiklerin gem bedeli (EKSİKLERİ AL önce envanteri kullanır).
func _cost_after_inventory(jy: JunkyardManager) -> int:
	var total: int = 0
	for part_id: StringName in RestorationCatalog.recipe(vehicle_id):
		var left: int = maxi(jy.missing(vehicle_id, part_id) - jy.part_count(part_id), 0)
		total += left * RestorationCatalog.part_gem_price(part_id)
	return total


func _part_row(part_id: StringName, need: int, done: int, missing: int, have: int, cost: int) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 8)
	var icon: PartIcon = PartIcon.new()
	icon.part_id = part_id
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.dim = missing > 0 and have == 0
	row.add_child(icon)
	var text: VBoxContainer = VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_constant_override(&"separation", -2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(_label(&"HudInkValue", "%s  %d/%d" % [Loc.t(RestorationCatalog.part_name(part_id)), done, need]))
	var jy: JunkyardManager = _jy()
	var asked: bool = jy != null and StringName(SaveSafe.s(jy.current_ask().get("part", ""))) == part_id
	var caption: String = Loc.t("TAMAM") if missing == 0 else Loc.t("ENVANTERDE %d") % have
	if asked and missing > 0:
		caption += Loc.t("  ·  ARKADAŞLARINDAN İSTENDİ")
	text.add_child(_label(&"HudInkCaption", caption))
	row.add_child(text)
	var social: SocialManager = get_tree().get_first_node_in_group("social") as SocialManager
	if missing > 0 and not asked and jy and jy.can_ask() and social and social.is_ready() and not social.friends.is_empty():
		var ask: PlateButton = _button(Loc.t("İSTE"), func() -> void: social.ask_part(part_id))
		ask.disabled = social.is_busy()
		row.add_child(ask)
	if missing > 0:
		if have > 0:
			row.add_child(_button(Loc.t("TAK"), func() -> void:
				var manager: JunkyardManager = _jy()
				if manager:
					manager.install(vehicle_id, part_id)))
		if cost > 0:
			row.add_child(_button(Loc.t("%d GEM") % cost, func() -> void:
				_buy_part(part_id, missing, cost)))
	return row


## İstek / hediye bildirimi panonun başlığında görünür (HUD'un plakası panonun arkasında kalır).
func _on_social_notice(text: String) -> void:
	_notice_label.text = text
	_notice_label.visible = true


func _on_gems(gems: int) -> void:
	_gem_label.text = Loc.t("GEM  %d") % gems


# --- Eylemler ------------------------------------------------------------------------

func _on_install_all() -> void:
	var jy: JunkyardManager = _jy()
	if jy:
		jy.install_all(vehicle_id)


func _buy_part(part_id: StringName, missing: int, cost: int) -> void:
	if not _can_pay(cost):
		return
	_ask(Loc.t("%d %s için %d GEM ödensin mi?") % [missing, Loc.t(RestorationCatalog.part_name(part_id)), cost],
		Loc.t("%d GEM ÖDE") % cost, func() -> void:
			var jy: JunkyardManager = _jy()
			if jy:
				jy.buy_missing(vehicle_id, part_id))


func _on_buy_all() -> void:
	var jy: JunkyardManager = _jy()
	if jy == null:
		return
	var cost: int = _cost_after_inventory(jy)
	if not _can_pay(cost):
		return
	_ask(Loc.t("Envanterdeki parçalar takılır, kalan eksikler için %d GEM ödenir. Onaylıyor musun?") % cost,
		Loc.t("%d GEM ÖDE") % cost, func() -> void:
			jy.buy_all_missing(vehicle_id))


## Gem yetmiyorsa mağaza önerilir (onay katmanından).
func _can_pay(cost: int) -> bool:
	var player: PlayerProgress = _player()
	if player and player.gems >= cost:
		return true
	_ask(Loc.t("GEM YETMİYOR\n%d GEM gerekiyor, %d GEM'in var.") % [cost, player.gems if player else 0],
		Loc.t("MARKET"), func() -> void: screen_requested.emit(&"gem_store"))
	return false


func _on_finish() -> void:
	var jy: JunkyardManager = _jy()
	if jy and jy.finish(vehicle_id):
		var id: StringName = vehicle_id
		close()
		project_finished.emit(id)


func _on_quit() -> void:
	_ask(Loc.t("Proje bırakılsın mı? Takılan parçalar envantere döner, tamir alanı boşalır."),
		Loc.t("BIRAK"), func() -> void:
			var jy: JunkyardManager = _jy()
			if jy:
				jy.quit(vehicle_id))


# --- Yardımcılar ----------------------------------------------------------------------

func _button(text: String, action: Callable, variation: StringName = &"HudPlateSmall") -> PlateButton:
	var button: PlateButton = PlateButton.new()
	button.theme_type_variation = variation
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(action)
	return button


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _jy() -> JunkyardManager:
	return get_tree().get_first_node_in_group("junkyard") as JunkyardManager if is_inside_tree() else null


func _player() -> PlayerProgress:
	return get_tree().get_first_node_in_group("player_progress") as PlayerProgress if is_inside_tree() else null


## İlerleme çubuğu: koyu yuva, amber dolgu.
class ProgressStrip:
	extends Control

	var ratio: float = 0.0:
		set(value):
			ratio = clampf(value, 0.0, 1.0)
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		draw_rect(r, Color("3A3D41"))
		if ratio > 0.0:
			draw_rect(Rect2(r.position, Vector2(r.size.x * ratio, r.size.y)), Color("F5BE4C"))
		draw_rect(r, Color("2F3236"), false, 2.0)
