class_name LeaderboardScreen
extends Control
## HAFTALIK DRAG TABLOSU — taslak B "podyum + liste", satırlarda A'nın İZLE düğmesi (kullanıcı 2026-10-26; tuval
## https://claude.ai/artifact/JawMeeZcKSp29o7oT5Hf9e, docs/LIDER_TABLOSU.md). Arka plan bulanık (vfx/screen_blur.gdshader).
## Üstte başlık + Pazartesi sıfırlanma geri sayımı, altında liste seçici DÜNYA / ÜLKEM / ARKADAŞLAR. Solda sınıf rayı
## (D C B A S). Ortada ilk 3 PODYUMDA (avatar + bayrak, ad + seviye, süre, aracın resmi, basamak, İZLE). Sağda 4. sıradan
## liste (avatar + bayrak, ad + seviye, araç + boya + modifiye kademesi, süre, İZLE) ve altta sabit KENDİ SATIRIN
## (misafirde HESAP AÇ). En altta ödül kademeleri (İLK 3 / İLK %10 / İLK %50, elmas + kasa) ve oyuncunun yeri.
## Veriler Leaderboard'dan (oturumsuz REST: misafir de görür). İZLE → watch_requested (HUD koşuyu indirip pisti izleme
## kipinde açar; yalnız izlenir). Kodla kurulur.

signal opened
signal closed
## İZLE: {wk, cls, uid, name, car, time}.
signal watch_requested(entry: Dictionary)
## Misafir: HESAP AÇ.
signal account_requested

const BLUR_SHADER: Shader = preload("res://vfx/screen_blur.gdshader")
const FADE_TIME: float = 0.25
const DARK: Color = Color("2D2A26")
const SILVER: Color = Color("D9DCE1")
const SILVER_EDGE: Color = Color("9AA0A8")
const BRONZE: Color = Color("C98A4B")
const BRONZE_EDGE: Color = Color("8A5A2B")
const LEVEL_BLUE: Color = Color("2F6FB3")
## Podyum basamağının yüksekliği (sıraya göre).
const STEP_HEIGHT: Dictionary = {1: 52.0, 2: 36.0, 3: 26.0}
const PODIUM_CAR: Vector2 = Vector2(96.0, 60.0)
const ROW_CAR: Vector2 = Vector2(46.0, 29.0)

var _blur: ShaderMaterial
var _column: VBoxContainer
var _title: Label
var _clock: Label
var _scopes: HBoxContainer
var _rail: VBoxContainer
var _podium: HBoxContainer
var _list: VBoxContainer
var _list_scroll: ScrollContainer
var _own: PanelContainer
var _status: Label
var _tiers: Array[Label] = []   # kademe başına bir etiket (İLK 3 · İLK %10 · İLK %50): uzun dilde tek satır taşıyordu
var _bar: _TierBar
var _bar_caption: Label
var _tick: Timer
var _closing: bool = false
var _cls: StringName = &"A"
var _scope: StringName = &"world"
var _gen: int = 0
var _wk: int = 0
## Yönlendirici açmadan önce verilirse tablo o sınıfla açılır (yarış sonucundan: koşulan sınıf; izlemeden dönüş).
var next_class: StringName = &""


func _ready() -> void:
	name = "LeaderboardScreen"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


## cls: açılacak sınıf (boşsa oyuncunun yarış aracının sınıfı).
func open(cls: StringName = &"") -> void:
	if cls == &"" and next_class != &"":
		cls = next_class
	next_class = &""
	if cls == &"":
		var race: RaceManager = get_tree().get_first_node_in_group("race") as RaceManager
		cls = Leaderboard.class_of(race.player_vehicle_id()) if race else &"D"
	_cls = cls if Leaderboard.CLASSES.has(cls) else &"D"
	_scope = &"world"
	_refresh_controls()
	_load()
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


func selected_class() -> StringName:
	return _cls


func selected_scope() -> StringName:
	return _scope


# --- Kurulum -----------------------------------------------------------------

func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.name = "Blur"
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_blur = ShaderMaterial.new()
	_blur.shader = BLUR_SHADER
	bg.material = _blur
	add_child(bg)

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: StringName in [&"margin_left", &"margin_right"]:
		margin.add_theme_constant_override(side, 12)
	margin.add_theme_constant_override(&"margin_top", 8)
	margin.add_theme_constant_override(&"margin_bottom", 8)
	add_child(margin)
	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override(&"separation", 5)
	margin.add_child(_column)

	# Başlık + kapat
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(top)
	var left: Control = Control.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(left)
	var sign: PlatePanel = PlatePanel.new()
	sign.theme_type_variation = &"HudCarPlate"
	var sign_box: VBoxContainer = VBoxContainer.new()
	sign_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sign_box.add_theme_constant_override(&"separation", 0)
	_title = _label(&"HudSignTitle", "")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_box.add_child(_title)
	_clock = _label(&"HudInkCaption", "")
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_box.add_child(_clock)
	sign.add_child(sign_box)
	top.add_child(sign)
	var right: HBoxContainer = HBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_END
	top.add_child(right)
	var close_button: PlateButton = PlateButton.new()
	close_button.name = "CloseButton"
	close_button.theme_type_variation = &"HudSign"
	close_button.shape = PlateButton.Shape.ROUND
	close_button.kind = HudIcon.Kind.CROSS
	close_button.icon_size = 18.0
	close_button.bolts = false
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_button.pressed.connect(close)
	right.add_child(close_button)

	# Liste seçici
	_scopes = HBoxContainer.new()
	_scopes.name = "Scopes"
	_scopes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scopes.alignment = BoxContainer.ALIGNMENT_CENTER
	_scopes.add_theme_constant_override(&"separation", 6)
	_column.add_child(_scopes)
	for scope: Array in [[&"world", "DÜNYA"], [&"country", "ÜLKEM"], [&"friends", "ARKADAŞLAR"]]:
		var button: PlateButton = PlateButton.new()
		button.name = "Scope_%s" % scope[0]
		button.theme_type_variation = &"HudPlateSmall"
		button.text = Loc.t(scope[1])
		button.focus_mode = Control.FOCUS_NONE
		var id: StringName = scope[0]
		button.pressed.connect(func() -> void: _set_scope(id))
		_scopes.add_child(button)

	# Ray + podyum + liste
	var main: HBoxContainer = HBoxContainer.new()
	main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override(&"separation", 8)
	_column.add_child(main)
	_rail = VBoxContainer.new()
	_rail.name = "Classes"
	_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rail.alignment = BoxContainer.ALIGNMENT_CENTER
	_rail.add_theme_constant_override(&"separation", 5)
	main.add_child(_rail)
	var rail_title: Label = _label(&"HudOutlined", Loc.t("SINIF"))
	rail_title.add_theme_font_size_override(&"font_size", 11)
	rail_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rail.add_child(rail_title)
	for cls: StringName in Leaderboard.CLASSES:
		var plate: PlateButton = PlateButton.new()
		plate.name = "Class_%s" % cls
		plate.theme_type_variation = &"HudPlateSmall"
		plate.text = String(cls)
		plate.focus_mode = Control.FOCUS_NONE
		plate.custom_minimum_size = Vector2(52.0, 0.0)
		var id: StringName = cls
		plate.pressed.connect(func() -> void: _set_class(id))
		_rail.add_child(plate)

	var stage: VBoxContainer = VBoxContainer.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_stretch_ratio = 0.8
	main.add_child(stage)
	_status = _label(&"HudOutlined", "")
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.visible = false
	stage.add_child(_status)
	_podium = HBoxContainer.new()
	_podium.name = "Podium"
	_podium.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_podium.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_podium.alignment = BoxContainer.ALIGNMENT_CENTER
	_podium.add_theme_constant_override(&"separation", 4)
	stage.add_child(_podium)

	var board: PlatePanel = PlatePanel.new()
	board.theme_type_variation = &"HudCarPlate"
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_stretch_ratio = 1.15
	main.add_child(board)
	var board_box: VBoxContainer = VBoxContainer.new()
	board_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_box.add_theme_constant_override(&"separation", 4)
	board.add_child(board_box)
	_list_scroll = ScrollContainer.new()
	_list_scroll.name = "List"
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	board_box.add_child(_list_scroll)
	TouchScroll.attach(_list_scroll)
	_list = VBoxContainer.new()
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 3)
	_list_scroll.add_child(_list)
	_own = PanelContainer.new()
	_own.name = "OwnRow"
	_own.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_box.add_child(_own)

	# Ödül kademeleri
	var strip: PanelContainer = PanelContainer.new()
	strip.name = "Tiers"
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var strip_box: StyleBoxFlat = StyleBoxFlat.new()
	strip_box.bg_color = DARK
	strip_box.border_color = HudPalette.PLATE_SELECTED
	strip_box.set_border_width_all(2)
	strip_box.set_corner_radius_all(10)
	strip_box.content_margin_left = 10.0
	strip_box.content_margin_right = 10.0
	strip_box.content_margin_top = 4.0
	strip_box.content_margin_bottom = 5.0
	strip.add_theme_stylebox_override(&"panel", strip_box)
	_column.add_child(strip)
	var strip_col: VBoxContainer = VBoxContainer.new()
	strip_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip_col.add_theme_constant_override(&"separation", 2)
	strip.add_child(strip_col)
	var tier_row: HBoxContainer = HBoxContainer.new()
	tier_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tier_row.add_theme_constant_override(&"separation", 12)
	strip_col.add_child(tier_row)
	for i: int in Leaderboard.TIERS.size():
		var tier_label: Label = _light(11)
		tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tier_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tier_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS   # sığmazsa kısalır, şeridi genişletmez
		tier_row.add_child(tier_label)
		_tiers.append(tier_label)
	_bar = _TierBar.new()
	_bar.custom_minimum_size = Vector2(0.0, 12.0)
	strip_col.add_child(_bar)
	_bar_caption = _light(10)
	_bar_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	strip_col.add_child(_bar_caption)

	_tick = Timer.new()
	_tick.wait_time = 1.0
	_tick.timeout.connect(_update_clock)
	add_child(_tick)


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Koyu zemin üstünde açık yazı.
func _light(font_size: int, color: Color = HudPalette.TEXT_LIGHT) -> Label:
	var label: Label = _label(&"HudInkValue", "")
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	return label


func _ink(text: String, font_size: int, color: Color = HudPalette.INK) -> Label:
	var label: Label = _label(&"HudInkValue", text)
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	return label


func _pill(text: String, bg: Color, fg: Color, font_size: int = 9) -> PanelContainer:
	var pill: PanelContainer = PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(6)
	box.content_margin_left = 5.0
	box.content_margin_right = 5.0
	pill.add_theme_stylebox_override(&"panel", box)
	pill.add_child(_ink(text, font_size, fg))
	return pill


# --- Durum ---------------------------------------------------------------------

func _set_class(cls: StringName) -> void:
	if cls == _cls:
		return
	_cls = cls
	_refresh_controls()
	_load()


func _set_scope(scope: StringName) -> void:
	if scope == _scope:
		return
	_scope = scope
	_refresh_controls()
	_load()


func _refresh_controls() -> void:
	_wk = Leaderboard.current_week()
	_title.text = Loc.t("HAFTANIN EN HIZLILARI · %s SINIFI") % _cls
	for child: Node in _rail.get_children():
		if child is PlateButton:
			(child as PlateButton).highlight = child.name == "Class_%s" % _cls
	for child: Node in _scopes.get_children():
		(child as PlateButton).highlight = child.name == "Scope_%s" % _scope
	_update_clock()


func _update_clock() -> void:
	_clock.text = Loc.t("PAZARTESİ 00:00'DA SIFIRLANIR · %s") % EventBanner.countdown(Leaderboard.week_end(_wk) - Leaderboard.now())
	if Leaderboard.current_week() != _wk and visible:
		_refresh_controls()   # hafta döndü (ekran açıkken Pazartesi oldu)
		_load()


# --- İçerik --------------------------------------------------------------------

func _load() -> void:
	_gen += 1
	var gen: int = _gen
	var board: Leaderboard = get_tree().get_first_node_in_group("leaderboard") as Leaderboard if is_inside_tree() else null
	_show_status(Loc.t("YÜKLENİYOR…"))
	if board == null:
		_show_status(Loc.t("Tablo şu an açılamadı."))
		return
	var profile: PlayerProfile = get_tree().get_first_node_in_group("player_profile") as PlayerProfile
	var entries: Array[Dictionary] = []
	var summary: Dictionary = {}
	match _scope:
		&"friends":
			entries = await board.friends_entries(_wk, _cls)
		&"country":
			var cc: String = profile.flag if profile else ""
			if cc.is_empty():
				if gen == _gen:
					_fill([], {}, board)
					_show_status(Loc.t("Ülke tablosu için PROFİL'den bayrağını seç."))
				return
			summary = await board.summary(_wk, _cls, cc)
		_:
			summary = await board.summary(_wk, _cls)
	if gen != _gen or not is_inside_tree():
		return   # bu arada sınıf / liste değişti
	if _scope != &"friends":
		for raw: Variant in summary.get("top", []):
			if raw is Dictionary and float((raw as Dictionary).get("time", 0.0)) > 0.0:
				entries.append(raw)
	_fill(entries, summary, board)
	_show_status("" if not entries.is_empty() else Loc.t("Bu hafta bu sınıfta henüz kimse yok. İlk sen ol!"))


func _show_status(text: String) -> void:
	_status.text = text
	_status.visible = not text.is_empty()


func _fill(entries: Array[Dictionary], summary: Dictionary, board: Leaderboard) -> void:
	for child: Node in _podium.get_children():
		_podium.remove_child(child)
		child.queue_free()
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for child: Node in _own.get_children():
		_own.remove_child(child)
		child.queue_free()
	if not entries.is_empty():
		for rank: int in [2, 1, 3]:   # podyum sırası: 2 · 1 · 3
			_podium.add_child(_podium_column(entries[rank - 1] if entries.size() >= rank else {}, rank))
	for i: int in range(3, entries.size()):
		_list.add_child(_row(entries[i], i + 1))
	_fill_own(entries, summary, board)
	_fit_width.call_deferred()


## Uzun dilde (WATCH / REPLAY) satırlar tabloyu ekrandan taşırıyordu (kapat düğmesi dışarıda kalıyordu): sığmazsa
## listenin İZLE düğmeleri yalnız ▶ olur (podyumdakiler yazılı kalır). Türkçe telefon tuvalinde yazılı sığar.
func _fit_width() -> void:
	if not is_inside_tree() or _list.get_child_count() == 0:
		return
	var room: float = size.x - 24.0   # kenar payları (_build: 12 + 12)
	if _column.get_combined_minimum_size().x <= room:
		return
	for button: Node in _list.find_children("Watch_*", "PlateButton", true, false):
		(button as PlateButton).text = ""


## Oyuncunun satırı: sırası (dünya / ülke: özetin kovalarından; arkadaş: listedeki yeri) ya da misafirde HESAP AÇ.
func _fill_own(entries: Array[Dictionary], summary: Dictionary, board: Leaderboard) -> void:
	var social: SocialManager = get_tree().get_first_node_in_group("social") as SocialManager
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = HudPalette.COIN
	style.set_corner_radius_all(8)
	style.border_width_bottom = 3
	style.border_color = HudPalette.PLATE_SELECTED_EDGE
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	_own.add_theme_stylebox_override(&"panel", style)
	if social == null or social.uid().is_empty():
		var join: PlateButton = PlateButton.new()
		join.name = "AccountButton"
		join.theme_type_variation = &"HudPlateSmall"
		join.text = Loc.t("HESAP AÇ, TABLOYA GİR")
		join.highlight = true
		join.focus_mode = Control.FOCUS_NONE
		join.pressed.connect(func() -> void: account_requested.emit())
		_own.add_child(join)
		_set_bar(-1.0, Loc.t("Misafirken tabloyu görürsün; girmek için hesap aç."))
		return
	var best: float = board.my_best(_wk, _cls)
	if best <= 0.0:
		_own.add_child(_ink(Loc.t("BU HAFTA %s SINIFINDA SÜREN YOK · BİR DRAG YARIŞI YAP") % _cls, 11))
		_set_bar(-1.0, Loc.t("Her drag yarışın sayılır; tabloda haftanın en iyi süren durur."))
		return
	var rank: int = 0
	var count: int = 0
	if _scope == &"friends":
		for i: int in entries.size():
			if SaveSafe.s(entries[i].get("uid", "")) == social.uid():
				rank = i + 1
		count = entries.size()
	else:
		var r: Dictionary = Leaderboard.rank_in(summary, best)
		rank = int(r.get("rank", 0))
		count = int(r.get("count", 0))
	var progress: PlayerProgress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress
	var me: Dictionary = {"uid": ProfileCard.ME, "name": Loc.t("SEN"), "time": best,
		"car": String(board.my_best_car(_wk, _cls)), "level": progress.level if progress else 0,
		"flag": (get_tree().get_first_node_in_group("player_profile") as PlayerProfile).flag}
	for entry: Dictionary in entries:
		if SaveSafe.s(entry.get("uid", "")) == social.uid():
			me = entry.duplicate()
			me["name"] = Loc.t("SEN")
			me["uid"] = ProfileCard.ME
	_own.add_child(_row_box(me, rank, true))
	if _scope == &"friends":
		_set_bar(-1.0, Loc.t("Ödüller DÜNYA tablosuna göre verilir."))
		return
	var pct: float = float(rank) / float(maxi(count, 1))
	var tier: StringName = Leaderboard.tier_of(rank, count)
	var caption: String = Loc.t("SEN: %d. · İLK %%%d") % [rank, maxi(ceili(pct * 100.0), 1)]
	if tier != &"":
		caption += "  ·  " + Loc.t("ŞU AN ÖDÜL KADEMESİNDESİN")
	_set_bar(pct, caption)


func _set_bar(pct: float, caption: String) -> void:
	_bar.marker = pct
	_bar.queue_redraw()
	_bar_caption.text = caption
	for i: int in Leaderboard.TIERS.size():
		var tier: StringName = Leaderboard.TIERS[i]
		_tiers[i].text = _tier_name(tier) + " · " + _reward_text(Leaderboard.reward_of(tier))


static func _tier_name(tier: StringName) -> String:
	match tier:
		&"top3":
			return Loc.t("İLK 3")
		&"p10":
			return Loc.t("İLK %10")
	return Loc.t("İLK %50")


static func _reward_text(reward: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if int(reward.get("gems", 0)) > 0:
		parts.append(Loc.t("+%d GEM") % int(reward["gems"]))
	var crate: StringName = StringName(SaveSafe.s(reward.get("crate", "")))
	if crate != &"":
		parts.append(Loc.t(String(CrateCatalog.get_entry(crate).get("display_name", "KASA"))))
	return " + ".join(parts)


# --- Satır / podyum ------------------------------------------------------------

func _row(entry: Dictionary, rank: int) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Row_%d" % rank
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("EADFC4")
	style.set_corner_radius_all(7)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	panel.add_theme_stylebox_override(&"panel", style)
	panel.add_child(_row_box(entry, rank, false))
	return panel


## Satır içeriği: sıra · avatar(+bayrak) · ad + seviye / araç + boya + kademe · araç resmi · süre · İZLE.
func _row_box(entry: Dictionary, rank: int, own: bool) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 6)
	var rank_label: Label = _ink(("%d." % rank) if rank > 0 else "—", 13)
	rank_label.custom_minimum_size.x = 34.0
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(rank_label)
	row.add_child(_avatar(entry, 28.0))
	var texts: VBoxContainer = VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override(&"separation", -1)
	row.add_child(texts)
	# Ad tek başına satırında (dar listede kırpılmasın); altında boya · seviye · modifiye kademesi
	var name_label: Label = _ink(_display_name(entry), 12)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(name_label)
	var car: StringName = StringName(SaveSafe.s(entry.get("car", "")))
	var car_row: HBoxContainer = HBoxContainer.new()
	car_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	car_row.add_theme_constant_override(&"separation", 4)
	texts.add_child(car_row)
	if int(entry.get("level", 0)) > 0:
		car_row.add_child(_pill(Loc.t("SV %d") % int(entry["level"]), LEVEL_BLUE, Color.WHITE, 8))
	if car != &"":
		var paint: String = SaveSafe.s(entry.get("paint", ""))
		if Color.html_is_valid(paint):
			var dot: _Dot = _Dot.new()
			dot.color = Color.html(paint)
			dot.custom_minimum_size = Vector2(9.0, 9.0)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			car_row.add_child(dot)
		var stage: int = int(entry.get("stage", 0))
		car_row.add_child(_pill(Loc.t("KADEME %d") % stage if stage > 0 else Loc.t("FABRİKA"), HudPalette.INK,
			HudPalette.PLATE_SELECTED, 8))
		row.add_child(_car_photo(car, ROW_CAR))
	var time_label: Label = _ink(time_text(float(entry.get("time", 0.0))), 14)
	time_label.custom_minimum_size.x = 46.0
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(time_label)
	if not own:
		row.add_child(_watch_button(entry))
	else:
		var gap: Control = Control.new()
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gap.custom_minimum_size.x = 70.0
		row.add_child(gap)
	return row


func _podium_column(entry: Dictionary, rank: int) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Podium_%d" % rank
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_END
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override(&"separation", 1)
	var empty: bool = entry.is_empty()
	if rank == 1:
		var crown: _Crown = _Crown.new()
		crown.custom_minimum_size = Vector2(0.0, 14.0)
		column.add_child(crown)
	if not empty:
		var avatar: Control = _avatar(entry, 42.0 if rank == 1 else 34.0)
		avatar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(avatar)
		var name_label: Label = _label(&"HudOutlined", _display_name(entry))
		name_label.add_theme_font_size_override(&"font_size", 12 if rank == 1 else 11)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		column.add_child(name_label)
		var time_pill: PanelContainer = _pill(time_text(float(entry.get("time", 0.0))) + " sn",
			HudPalette.COIN if rank == 1 else DARK, HudPalette.INK if rank == 1 else HudPalette.TEXT_LIGHT, 11)
		time_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(time_pill)
		column.add_child(_car_photo(StringName(SaveSafe.s(entry.get("car", ""))), PODIUM_CAR))
	var step: _Step = _Step.new()
	step.rank = rank
	step.custom_minimum_size = Vector2(0.0, STEP_HEIGHT[rank])
	column.add_child(step)
	if not empty:
		var watch: PlateButton = _watch_button(entry)
		watch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(watch)
	return column


func _watch_button(entry: Dictionary) -> PlateButton:
	var button: PlateButton = PlateButton.new()
	button.name = "Watch_%s" % SaveSafe.s(entry.get("uid", ""))
	button.theme_type_variation = &"HudPlateSmall"
	button.kind = HudIcon.Kind.PLAY
	button.icon_left = true
	button.bolts = false   # dar listede yer kaplamasın (taslak A'nın küçük İZLE düğmesi)
	button.text = Loc.t("İZLE")
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var info: Dictionary = {"wk": _wk, "cls": _cls, "uid": SaveSafe.s(entry.get("uid", "")), "name": _display_name(entry),
		"car": SaveSafe.s(entry.get("car", "")), "time": float(entry.get("time", 0.0))}
	button.pressed.connect(func() -> void: watch_requested.emit(info))
	return button


func _avatar(entry: Dictionary, size_px: float) -> AvatarView:
	var view: AvatarView = AvatarView.new()
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.custom_minimum_size = Vector2(size_px, size_px)
	view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var look: Dictionary = ProfileCard.avatar_for(get_tree(), entry)
	view.show_avatar(look.get("texture"), bool(look.get("illustrated", true)), ProfileCatalog.DEFAULT_FRAME,
		SaveSafe.s(entry.get("flag", "")))
	return view


func _car_photo(car: StringName, box: Vector2) -> TextureRect:
	var photo: TextureRect = TextureRect.new()
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	photo.custom_minimum_size = box
	photo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	photo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var path: String = ProfileCard.THUMB_DIR + String(car) + ".png"
	if car != &"" and ResourceLoader.exists(path):
		photo.texture = load(path) as Texture2D
	return photo


static func _display_name(entry: Dictionary) -> String:
	var text: String = SaveSafe.s(entry.get("name", "")).strip_edges()
	return text if not text.is_empty() else Loc.t("USTA")


## "9,81" / "10,10" (iki hane, dilin ondalık ayracıyla; Loc.decimal sondaki sıfırı atıyordu: "10,1").
static func time_text(time: float) -> String:
	if time <= 0.0:
		return "—"
	var text: String = "%.2f" % time
	return text if Loc.current() == "en" else text.replace(".", ",")


# --- Çizimler ------------------------------------------------------------------------

## Podyum basamağı: altın / gümüş / bronz blok, ortada sıra numarası.
class _Step extends Control:
	var rank: int = 1

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var face: Color = HudPalette.COIN if rank == 1 else (LeaderboardScreen.SILVER if rank == 2 else LeaderboardScreen.BRONZE)
		var edge: Color = HudPalette.COIN_DARK if rank == 1 else (LeaderboardScreen.SILVER_EDGE if rank == 2 else LeaderboardScreen.BRONZE_EDGE)
		var rect: Rect2 = Rect2(Vector2(4.0, 0.0), Vector2(size.x - 8.0, size.y))
		draw_rect(Rect2(rect.position + Vector2(0.0, 3.0), rect.size), HudPalette.SHADOW)
		draw_rect(rect, face)
		draw_rect(Rect2(rect.position.x, rect.end.y - 5.0, rect.size.x, 5.0), edge)
		var font: Font = get_theme_default_font()
		var text: String = str(rank)
		var font_size: int = 26 if rank == 1 else 20
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, Vector2(rect.get_center().x - w * 0.5, rect.position.y + minf(rect.size.y - 8.0, font_size + 4.0)),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, HudPalette.INK)


## Birincinin tacı.
class _Crown extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c: float = size.x * 0.5
		var h: float = size.y
		var points: PackedVector2Array = PackedVector2Array([
			Vector2(c - 13.0, h), Vector2(c - 15.0, h * 0.25), Vector2(c - 7.0, h * 0.6), Vector2(c, 0.0),
			Vector2(c + 7.0, h * 0.6), Vector2(c + 15.0, h * 0.25), Vector2(c + 13.0, h)])
		draw_colored_polygon(points, HudPalette.COIN)
		points.append(points[0])
		draw_polyline(points, HudPalette.INK, 1.5, true)


## Boya noktası.
class _Dot extends Control:
	var color: Color = Color.WHITE

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r: float = minf(size.x, size.y) * 0.5
		draw_circle(size * 0.5, r, HudPalette.INK, true, -1.0, true)
		draw_circle(size * 0.5, r - 1.5, color, true, -1.0, true)


## Ödül kademeleri çubuğu: İLK %10 ve İLK %50 çizgileri, oyuncunun yeri (marker 0–1; <0 = yok).
class _TierBar extends Control:
	var marker: float = -1.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var rect: Rect2 = Rect2(Vector2(0.0, size.y * 0.5 - 4.0), Vector2(size.x, 8.0))
		draw_rect(rect, Color(HudPalette.TEXT_LIGHT, 0.15))
		draw_rect(Rect2(rect.position, Vector2(rect.size.x * 0.1, rect.size.y)), Color(HudPalette.COIN, 0.9))
		draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.1, 0.0), Vector2(rect.size.x * 0.4, rect.size.y)),
			Color(HudPalette.COIN, 0.35))
		for at: float in [0.1, 0.5]:
			draw_rect(Rect2(rect.position.x + rect.size.x * at - 1.0, rect.position.y - 2.0, 2.0, rect.size.y + 4.0),
				HudPalette.TEXT_LIGHT)
		if marker >= 0.0:
			var x: float = rect.position.x + rect.size.x * clampf(marker, 0.0, 1.0)
			draw_circle(Vector2(x, rect.get_center().y), 6.0, HudPalette.PLATE_SELECTED, true, -1.0, true)
			draw_circle(Vector2(x, rect.get_center().y), 4.0, Color.WHITE, true, -1.0, true)
