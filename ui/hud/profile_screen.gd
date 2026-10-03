class_name ProfileScreen
extends Control
## PROFİL / İLERLEME panosu — oyuncunun bütün ilerleme eksenleri TEK yerde:
## seviye + XP, garaj değeri + rütbe, iş ustalığı, görevler ve hesap.
##
## Neden: garaj değeri, ustalık ve görevler daha önce birbirinden kopuk üç ayrı ekrandı; oyuncu
## "ne kadar ilerledim?" sorusunun cevabını tek bir yerde bulamıyordu. Bu pano onları özetler ve
## ayrıntı ekranlarına yönlendirir (veriyi KENDİSİ hesaplamaz: PlayerProgress / GarageValue /
## JobMastery / QuestManager tek kaynaktır).
##
## Tamamen kodla kurulur (.tscn yok) ve "yol mobilyası / plaka" dilini kullanır: satırlar plaka,
## yönlendirmeler plaka buton. Generic kart / dashboard yok.

signal closed
## Bir ayrıntı ekranı istendi (UiRouter bu id'yi açar).
signal screen_requested(id: StringName)

const PLATE_WIDTH: float = 460.0

var _level_title: Label
var _level_lane: XpLane
var _level_caption: Label
var _value_button: PlateButton
var _mastery_button: PlateButton
var _quest_button: PlateButton
var _account_button: PlateButton
var _column: VBoxContainer
var _closing: bool = false


func _ready() -> void:
	name = "ProfileScreen"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func open() -> void:
	_refresh()
	PlateAnim.pop_in(self, _column)


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	PlateAnim.pop_out(self, _column, func() -> void:
		hide()
		_closing = false
		closed.emit())


# --- Kurulum ---------------------------------------------------------------------

func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center: CenterContainer = FitScroll.center_in(self)

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 6)
	center.add_child(column)
	_column = column

	var sign: PlatePanel = PlatePanel.new()
	sign.theme_type_variation = &"HudCarPlate"
	sign.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var title: Label = _label(&"HudSignTitle", "İLERLEME")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.add_child(title)
	column.add_child(sign)

	# SEVİYE — şerit göstergeli plaka (tıklanmaz, özet)
	var level_plate: PlatePanel = PlatePanel.new()
	level_plate.theme_type_variation = &"HudCarPlate"
	level_plate.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	var level_box: VBoxContainer = VBoxContainer.new()
	level_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_box.add_theme_constant_override(&"separation", 2)
	_level_title = _label(&"HudPlateTitle", "SEVİYE 1")
	_level_lane = XpLane.new()
	_level_lane.segments = 10
	_level_lane.custom_minimum_size = Vector2(PLATE_WIDTH - 40.0, 9.0)
	_level_caption = _label(&"HudInkCaption", "")
	level_box.add_child(_level_title)
	level_box.add_child(_level_lane)
	level_box.add_child(_level_caption)
	level_plate.add_child(level_box)
	column.add_child(level_plate)

	# Ayrıntı ekranlarına giden plakalar (tek satır: başlık + güncel değer)
	_value_button = _nav_plate(column, &"garage_value")
	_mastery_button = _nav_plate(column, &"mastery")
	_quest_button = _nav_plate(column, &"quests")
	_account_button = _nav_plate(column, &"account")

	var close_button: PlateButton = PlateButton.new()
	close_button.theme_type_variation = &"HudPlateSmall"
	close_button.text = "KAPAT"
	close_button.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close)
	column.add_child(close_button)


func _nav_plate(column: VBoxContainer, id: StringName) -> PlateButton:
	var button: PlateButton = PlateButton.new()
	button.theme_type_variation = &"HudCarPlate"
	button.kind = HudIcon.Kind.NONE
	button.bolts = false
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	button.pressed.connect(func() -> void: screen_requested.emit(id))
	column.add_child(button)
	return button


# --- Güncelleme -------------------------------------------------------------------

func _refresh() -> void:
	var tree: SceneTree = get_tree()
	var progress: PlayerProgress = tree.get_first_node_in_group("player_progress") as PlayerProgress
	if progress:
		_level_title.text = "SEVİYE %d" % progress.level
		_level_lane.ratio = progress.xp_ratio()
		_level_caption.text = "%s / %s XP  ·  SONRAKİ SEVİYEDE +%s ₺" % [
			Hud.format_thousands(progress.xp), Hud.format_thousands(progress.xp_to_next()),
			Hud.format_thousands(int(PlayerProgress.reward_for(progress.level + 1)["money"]))]

	var value: int = GarageValue.compute(tree)
	var rank: int = GarageValue.rank(value)
	_value_button.text = "GARAJ DEĞERİ        %s ₺  ·  %d. RÜTBE" % [Hud.format_thousands(value), rank]

	var mastery: JobMastery = tree.get_first_node_in_group("job_mastery") as JobMastery
	var stars: int = mastery.total_stars() if mastery else 0
	var mastered: int = mastery.mastered_jobs().size() if mastery else 0
	_mastery_button.text = "USTALIK             %d ★%s" % [
		stars, "  ·  %d İŞTE USTA" % mastered if mastered > 0 else ""]

	var quests: QuestManager = tree.get_first_node_in_group("quests") as QuestManager
	if quests:
		var claimed: int = quests.state().get("claimed", []).size()
		var claimable: int = quests.claimable_count()
		_quest_button.text = "GÖREVLER            %d / %d%s" % [
			claimed, QuestCatalog.all().size(),
			"  ·  %d ÖDÜL HAZIR" % claimable if claimable > 0 else ""]
		_quest_button.highlight = claimable > 0
	else:
		_quest_button.text = "GÖREVLER"

	var cloud: Node = tree.get_first_node_in_group("cloud_save")
	var who: String = ""
	if cloud and cloud.has_method(&"get_profile"):
		who = String((cloud.call(&"get_profile") as Dictionary).get("display_name", ""))
	_account_button.text = "HESAP               %s" % (who.to_upper() if who != "" else "OTURUM AÇ")


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
