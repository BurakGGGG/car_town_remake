class_name ProfileScreen
extends Control
## PROFİL panosu — en üstte oyuncunun PROFİL KARTI (fotoğraf, çerçeve, bayrak, garaj adı, istatistikler, vitrin
## aracı; DÜZENLE → profile_edit, misafirde GİRİŞ YAP → account), altında bütün ilerleme eksenleri:
## seviye + XP, garaj değeri + rütbe, iş ustalığı, görevler ve hesap (2x2 plaka: 480 birimlik ekrana sığar).
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

const PLATE_WIDTH: float = ProfileCard.CARD_WIDTH
const NAV_WIDTH: float = (PLATE_WIDTH - 6.0) * 0.5

var _card: ProfileCard
var _edit_button: PlateButton
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
	_connect_profile.call_deferred()


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
	var title: Label = _label(&"HudSignTitle", Loc.t("PROFİL"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.add_child(title)
	column.add_child(sign)

	_card = ProfileCard.new()
	_card.name = "Card"
	column.add_child(_card)
	_edit_button = PlateButton.new()
	_edit_button.name = "EditButton"
	_edit_button.theme_type_variation = &"HudPlateSmall"
	_edit_button.highlight = true
	_edit_button.bolts = false
	_edit_button.focus_mode = Control.FOCUS_NONE
	_edit_button.pressed.connect(_on_edit_pressed)
	_card.actions.add_child(_edit_button)

	# SEVİYE — şerit göstergeli plaka (tıklanmaz, özet)
	var level_plate: PlatePanel = PlatePanel.new()
	level_plate.theme_type_variation = &"HudCarPlate"
	level_plate.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	var level_box: VBoxContainer = VBoxContainer.new()
	level_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_box.add_theme_constant_override(&"separation", 2)
	_level_title = _label(&"HudPlateTitle", Loc.t("SEVİYE 1"))
	_level_lane = XpLane.new()
	_level_lane.segments = 10
	_level_lane.custom_minimum_size = Vector2(PLATE_WIDTH - 40.0, 9.0)
	_level_caption = _label(&"HudInkCaption", "")
	level_box.add_child(_level_title)
	level_box.add_child(_level_lane)
	level_box.add_child(_level_caption)
	level_plate.add_child(level_box)
	column.add_child(level_plate)

	# Ayrıntı ekranlarına giden plakalar (2x2: başlık + güncel değer)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override(&"h_separation", 6)
	grid.add_theme_constant_override(&"v_separation", 6)
	column.add_child(grid)
	_value_button = _nav_plate(grid, &"garage_value")
	_mastery_button = _nav_plate(grid, &"mastery")
	_quest_button = _nav_plate(grid, &"quests")
	_account_button = _nav_plate(grid, &"account")

	var close_button: PlateButton = PlateButton.new()
	close_button.theme_type_variation = &"HudPlateSmall"
	close_button.text = Loc.t("KAPAT")
	close_button.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close)
	column.add_child(close_button)


## Profil düzenlemeden dönünce / avatar inince kart güncellenir.
func _connect_profile() -> void:
	var refresh: Callable = func() -> void:
		if visible:
			_refresh()
	var profile: PlayerProfile = get_tree().get_first_node_in_group("player_profile") as PlayerProfile
	if profile:
		profile.changed.connect(refresh)
		profile.avatar_changed.connect(refresh)
	var social: SocialManager = get_tree().get_first_node_in_group("social") as SocialManager
	if social:
		social.changed.connect(refresh)


func _nav_plate(column: Container, id: StringName) -> PlateButton:
	var button: PlateButton = PlateButton.new()
	# HudCarPlate bir PANEL stilidir (yalnız "panel" kutusu): düğmede normal / hover / vurgu kutuları tanımsız
	# kalıp Godot'un koyu yarı saydam varsayılanına düşüyordu; vurgulu satırda beyaz yazı amber üstündeydi.
	button.theme_type_variation = &"HudPlateSmall"
	button.kind = HudIcon.Kind.NONE
	button.bolts = false
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(NAV_WIDTH, 0.0)
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.pressed.connect(func() -> void: screen_requested.emit(id))
	column.add_child(button)
	return button


# --- Güncelleme -------------------------------------------------------------------

func _refresh() -> void:
	var tree: SceneTree = get_tree()
	_card.show_person(ProfileCard.me(tree))
	_edit_button.text = Loc.t("DÜZENLE") if can_edit(tree) else Loc.t("GİRİŞ YAP")
	var progress: PlayerProgress = tree.get_first_node_in_group("player_progress") as PlayerProgress
	if progress:
		_level_title.text = Loc.t("SEVİYE %d") % progress.level
		_level_lane.ratio = progress.xp_ratio()
		_level_caption.text = Loc.t("%s / %s XP  ·  SONRAKİ SEVİYEDE +%s ₺") % [
			Hud.format_thousands(progress.xp), Hud.format_thousands(progress.xp_to_next()),
			Hud.format_thousands(int(PlayerProgress.reward_for(progress.level + 1)["money"]))]

	var value: int = GarageValue.compute(tree)
	var rank: int = GarageValue.rank(value)
	_value_button.text = Loc.t("GARAJ  %s ₺") % Hud.format_thousands(value)
	_value_button.tooltip_text = Loc.t("%d. RÜTBE") % rank

	var mastery: JobMastery = tree.get_first_node_in_group("job_mastery") as JobMastery
	var stars: int = mastery.total_stars() if mastery else 0
	var mastered: int = mastery.mastered_jobs().size() if mastery else 0
	_mastery_button.text = Loc.t("USTALIK  %d ★%s") % [
		stars, Loc.t("  ·  %d İŞTE USTA") % mastered if mastered > 0 else ""]

	var quests: QuestManager = tree.get_first_node_in_group("quests") as QuestManager
	if quests:
		var claimed: int = quests.state().get("claimed", []).size()
		var claimable: int = quests.claimable_count()
		_quest_button.text = Loc.t("GÖREVLER  %d / %d") % [claimed, QuestCatalog.all().size()] \
			+ ("  (%d)" % claimable if claimable > 0 else "")
		_quest_button.highlight = claimable > 0
	else:
		_quest_button.text = Loc.t("GÖREVLER")

	var cloud: Node = tree.get_first_node_in_group("cloud_save")
	var who: String = ""
	if cloud and cloud.has_method(&"get_profile"):
		who = String((cloud.call(&"get_profile") as Dictionary).get("display_name", ""))
	_account_button.text = Loc.t("HESAP  %s") % (Loc.upper(who) if who != "" else Loc.t("OTURUM AÇ"))


## Profil düzenlenebilir mi: Google girişi gerekir (kullanıcı kararı: misafir fotoğraf seçemez). Eklentisiz
## masaüstü / editör sürümünde (UNAVAILABLE) yerel olarak düzenlenebilir: geliştirme ve QA.
static func can_edit(tree: SceneTree) -> bool:
	var social: SocialManager = tree.get_first_node_in_group("social") as SocialManager
	return social != null and social.get_state() != SocialManager.State.SIGNED_OUT


func _on_edit_pressed() -> void:
	screen_requested.emit(&"profile_edit" if can_edit(get_tree()) else &"account")


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
