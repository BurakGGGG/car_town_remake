class_name RaceChallengeScreen
extends Control
## YARIŞ DAVETİ panosu — yoldan gelen rakibin 🏁 balonuna dokununca açılır.
## İki araç yan yana: oyuncunun aracı ve rakip; statlar cars.json'daki "race" bloğundan
## (DragRaceSim.stats_of) gelir, ödül RaceManager'dan — UI'da hardcode sayı yoktur.
## Plaka dili: her araç bir PlatePanel, aksiyonlar plaka buton. UiRouter bunu MODAL olarak açar.
## ARKADAŞ RAKİP (RaceManager.rival_owner): başlık "ELİF USTA YARIŞMAK İSTİYOR!", rakip plakasında arkadaşın fotoğrafı +
## adı; arkadaşın aracı modifiyeliyse sınıf / GENEL / 0-100 modifiyeli değerlerle (rakip yarışa öyle çıkar).

signal closed
## YARIŞ plakasına basıldı.
signal race_accepted

const PLATE_WIDTH: float = 210.0

var _player_plate: PlatePanel
var _rival_plate: PlatePanel
var _player_labels: Dictionary = {}
var _rival_labels: Dictionary = {}
var _reward_label: Label
var _column: VBoxContainer
var _title: Label
var _closing: bool = false


func _ready() -> void:
	name = "RaceChallengeScreen"
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

	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override(&"separation", 6)
	center.add_child(_column)

	var sign: PlatePanel = PlatePanel.new()
	sign.theme_type_variation = &"HudCarPlate"
	sign.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Soru doğrudan panoda: oyuncu "ne istiyor bu araç?" diye düşünmesin
	_title = _label(&"HudSignTitle", Loc.t("YARIŞMAK İSTER MİSİN?"))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.add_child(_title)
	_column.add_child(sign)

	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 8)
	_player_plate = _car_plate(row, Loc.t("SENİN ARACIN"), _player_labels)
	_rival_plate = _car_plate(row, Loc.t("RAKİP"), _rival_labels)
	_column.add_child(row)

	var reward_plate: PlatePanel = PlatePanel.new()
	reward_plate.theme_type_variation = &"HudCarPlate"
	reward_plate.custom_minimum_size = Vector2(PLATE_WIDTH * 2.0 + 8.0, 0.0)
	_reward_label = _label(&"HudInkValue", "")
	_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_label.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
	reward_plate.add_child(_reward_label)
	_column.add_child(reward_plate)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", 8)
	var accept: PlateButton = PlateButton.new()
	accept.name = "AcceptButton"
	accept.theme_type_variation = &"HudPlate"
	accept.kind = HudIcon.Kind.NONE
	accept.text = Loc.t("YARIŞ")
	accept.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	accept.focus_mode = Control.FOCUS_NONE
	accept.pressed.connect(func() -> void: race_accepted.emit())
	var cancel: PlateButton = PlateButton.new()
	cancel.theme_type_variation = &"HudPlateSmall"
	cancel.text = Loc.t("VAZGEÇ")
	cancel.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.pressed.connect(close)
	buttons.add_child(accept)
	buttons.add_child(cancel)
	_column.add_child(buttons)


func _car_plate(row: HBoxContainer, caption: String, labels: Dictionary) -> PlatePanel:
	var plate: PlatePanel = PlatePanel.new()
	plate.theme_type_variation = &"HudCarPlate"
	plate.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 1)
	labels["caption"] = _label(&"HudInkCaption", caption)
	# Arkadaş rakipte: fotoğraf + ad satırı (isimsiz rakipte ve oyuncunun plakasında gizli)
	var owner_row: HBoxContainer = HBoxContainer.new()
	owner_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner_row.add_theme_constant_override(&"separation", 6)
	owner_row.visible = false
	var avatar: AvatarView = AvatarView.new()
	avatar.custom_minimum_size = Vector2(42.0, 42.0)
	owner_row.add_child(avatar)
	var owner_name: Label = _label(&"HudInkValue", "")
	owner_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	owner_name.clip_text = true
	owner_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	owner_name.custom_minimum_size = Vector2(PLATE_WIDTH - 80.0, 0.0)
	owner_row.add_child(owner_name)
	box.add_child(owner_row)
	labels["owner_row"] = owner_row
	labels["avatar"] = avatar
	labels["owner_name"] = owner_name
	labels["name"] = _label(&"HudPlateTitle", "")
	labels["class"] = _label(&"HudInkCaption", "")
	labels["overall"] = _label(&"HudInkCaption", "")
	labels["perf"] = _label(&"HudInkCaption", "")   # gerçek veri: 0-100 · son hız
	for key: String in ["caption", "name", "class", "overall", "perf"]:
		box.add_child(labels[key])
	plate.add_child(box)
	row.add_child(plate)
	return plate


# --- Güncelleme -------------------------------------------------------------------

func _refresh() -> void:
	var race: RaceManager = get_tree().get_first_node_in_group("race") as RaceManager
	if race == null:
		return
	var player_id: StringName = race.player_vehicle_id()
	var rival: StringName = race.rival_id()
	_fill(_player_labels, player_id, true)
	_fill(_rival_labels, rival, false, race.rival_build())
	var owner: Dictionary = race.rival_owner()
	var row: HBoxContainer = _rival_labels["owner_row"]
	row.visible = not owner.is_empty()
	(_rival_labels["caption"] as Label).visible = owner.is_empty()
	_title.text = Loc.t("YARIŞMAK İSTER MİSİN?")
	if not owner.is_empty():
		var art: Dictionary = ProfileCard.avatar_for(get_tree(), owner)
		(_rival_labels["avatar"] as AvatarView).show_avatar(art.get("texture"), bool(art.get("illustrated", true)),
			SaveSafe.s(owner.get("frame", "")), SaveSafe.s(owner.get("flag", "")))
		var name: String = Loc.upper(SaveSafe.s(owner.get("name", "")))
		(_rival_labels["owner_name"] as Label).text = name
		_title.text = Loc.t("%s YARIŞMAK İSTİYOR!") % name
	var reward: Dictionary = race.reward_for(rival, true)
	var loss: Dictionary = race.reward_for(rival, false)
	var money: int = int(reward["money"])
	if race.friend_bonus_available():   # gerçek arkadaş: kazanınca +%20 (bugün bu arkadaştan alınmadıysa)
		money += int(round(float(money) * RaceManager.FRIEND_BONUS))
	_reward_label.text = Loc.t("KAZANIRSAN  +%s ₺  ·  +%d XP\nKAYBEDERSEN  +%d XP") % [
		Hud.format_thousands(money), int(reward["xp"]), int(loss["xp"])]
	if race.friend_bonus_available():
		_reward_label.text += "\n" + Loc.t("ARKADAŞ BONUSU +%s DAHİL") % Loc.percent(str(roundi(RaceManager.FRIEND_BONUS * 100.0)))


## player: oyuncunun aracı modifiyeli değerlerle (sınıf, GENEL, 0-100); rakip fabrika — arkadaşın aracıysa onun
## modifiyeleriyle (`build`).
func _fill(labels: Dictionary, vehicle_id: StringName, player: bool, build: Dictionary = {}) -> void:
	var entry: Dictionary = CarCatalog.get_entry(vehicle_id)
	if not player and not build.is_empty():
		var stats: Dictionary = PerformanceMods.stats_with(vehicle_id, build)
		(labels["name"] as Label).text = String(entry.get("display_name", vehicle_id)).to_upper()
		(labels["class"] as Label).text = Loc.t("%s SINIFI") % String(stats["class"]) + Loc.t("  ·  MODİFİYELİ")
		(labels["overall"] as Label).text = Loc.t("GENEL  %d") % int(stats["overall"])
		(labels["perf"] as Label).text = Loc.t("0-100 %s sn · %d km/sa") % [ModWorkshop.dec2(float(stats["zero_100"])),
			roundi(float(stats["top_speed"]))]
		(labels["perf"] as Label).visible = true
		return
	var modified: bool = player and PerformanceMods.is_modified(vehicle_id)
	(labels["name"] as Label).text = String(entry.get("display_name", vehicle_id)).to_upper()
	(labels["class"] as Label).text = Loc.t("%s SINIFI") % (PerformanceMods.class_of(vehicle_id) if modified
		else String(entry.get("class", "?")))
	(labels["overall"] as Label).text = Loc.t("GENEL  %d") % (PerformanceMods.overall(vehicle_id) if modified
		else DragRaceSim.overall_of(vehicle_id))
	(labels["perf"] as Label).text = GarageScreen.perf_line(entry) if player else _stock_perf_line(entry)
	(labels["perf"] as Label).visible = (labels["perf"] as Label).text != ""


## Rakibin fabrika değerleri (oyuncu aynı modeli modifiyelemiş olsa da rakip fabrikadır).
static func _stock_perf_line(entry: Dictionary) -> String:
	var perf: Dictionary = entry.get("performance", {})
	if perf.is_empty():
		return ""
	return Loc.t("0-100 %s sn · %d km/sa") % [Loc.decimal(float(perf.get("zero_100", 0.0))), int(perf.get("top_speed", 0))]


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
