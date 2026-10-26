class_name LbRecordsScreen
extends Control
## TABLO DERECELERİ listesi (taslak A'nın TÜMÜ'sü, kullanıcı 2026-10-26): bir oyuncunun haftalık drag tablosunda ilk 100'e
## girdiği haftalar (Leaderboard.history_of; sunucu ödenen haftada yalnız ilk 100'ün koşusunu ve derecesini tutar). Satır:
## madalya (1–3 altın / gümüş / bronz, İLK %10 amber, diğerleri mavi) · sınıf · hafta + kaç oyuncu arasında · kademe · araç
## · süre · İZLE. İZLE → watch_requested (HUD koşuyu indirip pisti izleme kipinde açar, bitince bu listeye döner).
## Profil kartının ve arkadaş kartının üstüne ALT PANO (UiRouter SUB &"lb_records") olarak açılır.

signal closed
## İZLE: {wk, cls, uid, name, car, time}.
signal watch_requested(info: Dictionary)

const BLUR_SHADER: Shader = preload("res://vfx/screen_blur.gdshader")
const FADE_TIME: float = 0.25
const ROW_CAR: Vector2 = Vector2(52.0, 32.0)
const MEDAL: float = 34.0

## İzlemeden dönünce yeniden açılacak ana pano (&"profile" / &"friends"); HUD açarken verir.
var origin: StringName = &""

var _blur: ShaderMaterial
var _column: VBoxContainer
var _title: Label
var _summary: Label
var _list: VBoxContainer
var _closing: bool = false
var _uid: String = ""
var _name: String = ""


func _ready() -> void:
	name = "LbRecordsScreen"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


## Gösterilecek kişi ve dereceleri (router.open'dan önce): {uid, name, recs}.
func show_records(info: Dictionary) -> void:
	_uid = SaveSafe.s(info.get("uid", ""))
	_name = SaveSafe.s(info.get("name", ""))
	var recs: Array[Dictionary] = []
	for rec: Variant in info.get("recs", []):
		if rec is Dictionary:
			recs.append(rec)
	_title.text = Loc.t("%s · TABLO DERECELERİ") % (Loc.upper(_name) if not _name.is_empty() else Loc.t("USTA"))
	var summary: Dictionary = Leaderboard.history_summary(recs)
	var parts: PackedStringArray = [Loc.t("%d KEZ İLK 100") % int(summary["count"])]
	if int(summary["top3"]) > 0:
		parts.append(Loc.t("%d KEZ İLK 3") % int(summary["top3"]))
	if not (summary["best"] as Dictionary).is_empty():
		parts.append(Loc.t("EN İYİSİ %d.") % int(summary["best"]["rank"]))
	_summary.text = " · ".join(parts)
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for rec: Dictionary in recs:
		_list.add_child(_row(rec))


func open() -> void:
	if visible:
		return
	PlateAnim.pop_in(self, _column)
	_blur.set_shader_parameter(&"strength", 0.0)
	create_tween().tween_method(func(v: float) -> void: _blur.set_shader_parameter(&"strength", v), 0.0, 1.0, FADE_TIME)


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	create_tween().tween_method(func(v: float) -> void: _blur.set_shader_parameter(&"strength", v), 1.0, 0.0, FADE_TIME)
	PlateAnim.pop_out(self, _column, func() -> void:
		hide()
		_closing = false
		closed.emit())


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
		margin.add_theme_constant_override(side, 60)
	margin.add_theme_constant_override(&"margin_top", 10)
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
	var sign: PlatePanel = PlatePanel.new()
	sign.theme_type_variation = &"HudCarPlate"
	var sign_box: VBoxContainer = VBoxContainer.new()
	sign_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sign_box.add_theme_constant_override(&"separation", 0)
	_title = _label(&"HudSignTitle", "")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_box.add_child(_title)
	_summary = _label(&"HudInkCaption", "")
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_box.add_child(_summary)
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

	var board: PlatePanel = PlatePanel.new()
	board.theme_type_variation = &"HudCarPlate"
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_column.add_child(board)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "List"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	board.add_child(scroll)
	TouchScroll.attach(scroll)
	_list = VBoxContainer.new()
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 4)
	scroll.add_child(_list)

	var foot: Label = _label(&"HudOutlined", Loc.t("Yalnız ilk 100'e girilen haftalar saklanır."))
	foot.add_theme_font_size_override(&"font_size", 11)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(foot)


## Satır: madalya · sınıf · hafta / kaç oyuncu arasında · kademe · araç · süre · İZLE.
func _row(rec: Dictionary) -> PanelContainer:
	var wk: int = int(rec["wk"])
	var cls: StringName = rec["cls"]
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Record_%d_%s" % [wk, cls]
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("EADFC4")
	style.set_corner_radius_all(7)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	panel.add_theme_stylebox_override(&"panel", style)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 8)
	panel.add_child(row)
	row.add_child(_medal(int(rec["rank"]), StringName(rec["tier"])))
	row.add_child(_pill(String(cls), HudPalette.PLATE_SELECTED, HudPalette.INK, 11))
	var texts: VBoxContainer = VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override(&"separation", -2)
	row.add_child(texts)
	texts.add_child(_ink(Leaderboard.week_text(wk), 13, HudPalette.INK))
	texts.add_child(_ink(Loc.t("%d OYUNCU ARASINDA") % int(rec["count"]), 10, HudPalette.INK_SOFT))
	row.add_child(_pill(_tier_text(StringName(rec["tier"])), LeaderboardScreen.DARK, HudPalette.PLATE_SELECTED, 9))
	var photo: TextureRect = TextureRect.new()
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	photo.custom_minimum_size = ROW_CAR
	photo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var path: String = ProfileCard.THUMB_DIR + String(rec["car"]) + ".png"
	if rec["car"] != &"" and ResourceLoader.exists(path):
		photo.texture = load(path) as Texture2D
	row.add_child(photo)
	var time_label: Label = _ink(LeaderboardScreen.time_text(float(rec["time"])), 14, HudPalette.INK)
	time_label.custom_minimum_size.x = 48.0
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(time_label)
	var watch: PlateButton = PlateButton.new()
	watch.name = "Watch_%d_%s" % [wk, cls]
	watch.theme_type_variation = &"HudPlateSmall"
	watch.kind = HudIcon.Kind.PLAY
	watch.icon_left = true
	watch.bolts = false
	watch.text = Loc.t("İZLE")
	watch.focus_mode = Control.FOCUS_NONE
	watch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var info: Dictionary = {"wk": wk, "cls": cls, "uid": _uid, "name": _name, "car": String(rec["car"]),
		"time": float(rec["time"])}
	watch.pressed.connect(func() -> void: watch_requested.emit(info))
	row.add_child(watch)
	return panel


## Sıra rozeti: 1 altın · 2 gümüş · 3 bronz · İLK %10 koyu-amber · diğerleri mavi.
func _medal(rank: int, tier: StringName) -> PanelContainer:
	var fill: Color = LeaderboardScreen.LEVEL_BLUE
	var edge: Color = Color("1F4F85")
	var ink: Color = Color.WHITE
	match rank:
		1:
			fill = HudPalette.PLATE_SELECTED
			edge = HudPalette.PLATE_SELECTED_EDGE
			ink = HudPalette.INK
		2:
			fill = LeaderboardScreen.SILVER
			edge = LeaderboardScreen.SILVER_EDGE
			ink = HudPalette.INK
		3:
			fill = LeaderboardScreen.BRONZE
			edge = LeaderboardScreen.BRONZE_EDGE
			ink = HudPalette.INK
		_:
			if tier == &"p10":
				fill = LeaderboardScreen.DARK
				edge = HudPalette.PLATE_SELECTED
				ink = HudPalette.PLATE_SELECTED
	var medal: PanelContainer = PanelContainer.new()
	medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	medal.custom_minimum_size = Vector2(MEDAL, MEDAL)
	medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(3)
	box.set_corner_radius_all(int(MEDAL * 0.5))
	medal.add_theme_stylebox_override(&"panel", box)
	var label: Label = _ink(str(rank), 14 if rank < 100 else 11, ink)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	medal.add_child(label)
	return medal


static func _tier_text(tier: StringName) -> String:
	match tier:
		&"top3":
			return Loc.t("İLK 3")
		&"p10":
			return Loc.t("İLK %10")
		&"p50":
			return Loc.t("İLK %50")
	return Loc.t("İLK 100")


func _pill(text: String, bg: Color, fg: Color, font_size: int) -> PanelContainer:
	var pill: PanelContainer = PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(5)
	box.content_margin_left = 5.0
	box.content_margin_right = 5.0
	pill.add_theme_stylebox_override(&"panel", box)
	pill.add_child(_ink(text, font_size, fg))
	return pill


func _ink(text: String, font_size: int, color: Color) -> Label:
	var label: Label = _label(&"HudInkValue", text)
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	return label


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
