class_name RaceResultScreen
extends Control
## YARIŞ SONUCU panosu — pistin üstüne açılır (UiRouter MODAL). Ödülü KENDİSİ vermez:
## parayı ve XP'yi RaceManager.finish_race() tek seferlik olarak yazar, bu ekran yalnızca gösterir.
## GARAJA DÖN plakası (ya da ESC) hem sonucu hem pisti kapatır. İlk yarış kaybedilince RÖVANŞ plakası: aynı rakiple
## TEK yeniden yarış (RaceManager.start_rematch; pisti HUD yeniden açar). Rövanş kaybedilirse plaka çıkmaz.
## ARKADAŞ RAKİP (RaceManager.rival_owner): sonucun altında arkadaşın fotoğrafı + "ELİF USTA'YI YENDİN!" / "ELİF USTA
## KAZANDI" (Türkçe ek Loc.accusative ile).
## HAFTALIK TABLO şeridi (2026-10-26, docs/LIDER_TABLOSU.md): koşu tabloya yazılınca (Leaderboard.submitted) sınıfın tablosundaki
## sıra "128. → 97. ↑31", haftalık en iyi süre ve bir üst ödül kademesine kalan fark + TABLO düğmesi. Misafire "HESAP AÇ,
## TABLOYA GİR". Etkinlik aracı yarışında / yazılamayınca şerit yok.

signal closed
## GARAJA DÖN: yarış modundan tamamen çıkılacak.
signal exit_requested
## Oyuncu "REKLAM İZLE" plakasına bastı (açık onay). Reklamı ve ödülü HUD yönetir; bu ekran yalnızca gösterir.
signal bonus_requested
## Oyuncu RÖVANŞ'a bastı.
signal rematch_requested
## HAFTALIK TABLO şeridinde TABLO'ya bastı (sınıf: şeridin sınıfı).
signal leaderboard_requested(cls: StringName)

const PLATE_WIDTH: float = 380.0

var _title: Label
var _reward: Label
var _times: Label
var _winner: Label
var _record: Label
var _bonus_button: PlateButton
var _rematch_button: PlateButton
var _head: Label
var _owner_row: HBoxContainer
var _owner_avatar: AvatarView
var _owner_text: Label
var _bonus_amount: int = 0
var _column: VBoxContainer
var _closing: bool = false
var _lb_strip: PanelContainer
var _lb_head: Label
var _lb_rank_row: HBoxContainer
var _lb_old: Label
var _lb_arrow: Label
var _lb_rank: Label
var _lb_badge: PanelContainer
var _lb_badge_text: Label
var _lb_sub: Label
var _lb_class: StringName = &""


func _ready() -> void:
	name = "RaceResultScreen"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


## Sonuç verileri dışarıdan gelir (yarış ekranı + RaceManager ödülü). `rematch` > 0: bu yarış rövanştı.
func show_result(won: bool, player_time: float, rival_time: float, money: int, xp: int,
		winner_id: StringName, rematch: int = 0) -> void:
	_head.text = Loc.t("YARIŞ BİTTİ") if rematch <= 0 else Loc.t("RÖVANŞ")
	var race: RaceManager = get_tree().get_first_node_in_group("race") as RaceManager if is_inside_tree() else null
	if race and race.is_revenge():
		_head.text = Loc.t("İNTİKAM")
	elif race and race.is_event_rival():
		_head.text = Loc.t("ETKİNLİK YARIŞI")
	offer_rematch(false)
	_title.text = Loc.t("KAZANDIN!") if won else Loc.t("KAYBETTİN")
	var parts: PackedStringArray = PackedStringArray()
	if money > 0:
		parts.append("+%s ₺" % Hud.format_thousands(money))
	if xp > 0:
		parts.append(Loc.t("+%d XP") % xp)
	_reward.text = "   ".join(parts) if not parts.is_empty() else Loc.t("ÖDÜL YOK")
	_times.text = Loc.t("SEN  %.2f sn        RAKİP  %.2f sn") % [player_time, rival_time]
	hide_bonus()
	show_leaderboard({})
	_winner.text = Loc.t("KAZANAN: %s") % String(CarCatalog.get_entry(winner_id).get("display_name", winner_id)).to_upper()
	_show_owner(won)


## Gerçek arkadaşı yenince eklenen +%20 (ödül satırına not düşülür; para zaten RaceManager'da eklendi).
func show_friend_bonus(amount: int) -> void:
	_reward.text = Loc.t("%s   (+%s ₺ ARKADAŞ BONUSU)") % [_reward.text, Hud.format_thousands(amount)]


## Etkinlik rakibinin özel ödülü (ilk galibiyette; ₺ / XP yukarıdaki toplamın içinde).
func show_event_bonus(text: String) -> void:
	_reward.text = Loc.t("%s\nETKİNLİK ÖDÜLÜ: %s") % [_reward.text, text]


## Arkadaş rakipse fotoğraf + sonuç cümlesi; isimsiz rakipte satır gizli.
func _show_owner(won: bool) -> void:
	var race: RaceManager = get_tree().get_first_node_in_group("race") as RaceManager if is_inside_tree() else null
	var owner: Dictionary = race.rival_owner() if race else {}
	_owner_row.visible = not owner.is_empty()
	if owner.is_empty():
		return
	var art: Dictionary = ProfileCard.avatar_for(get_tree(), owner)
	_owner_avatar.show_avatar(art.get("texture"), bool(art.get("illustrated", true)), SaveSafe.s(owner.get("frame", "")),
		SaveSafe.s(owner.get("flag", "")))
	var name: String = SaveSafe.s(owner.get("name", ""))
	_owner_text.text = Loc.t("%s YENDİN!") % Loc.upper(Loc.accusative(name)) if won \
		else Loc.t("%s KAZANDI") % Loc.upper(name)


## KİŞİSEL REKOR satırı: yeni rekorsa farkıyla birlikte amber, değilse mevcut rekor. Oyuncu hiç
## kalkmadıysa (koşu yok) satır gizlenir.
func show_record(finished: bool, is_new: bool, time: float, previous: float) -> void:
	_record.visible = finished
	if not finished:
		return
	if is_new and previous > 0.0:
		_record.text = Loc.t("YENİ REKOR!  %.2f sn  (−%.2f)") % [time, previous - time]
	elif is_new:
		_record.text = Loc.t("İLK REKOR  %.2f sn") % time
	else:
		_record.text = Loc.t("REKORUN  %.2f sn  (+%.2f)") % [previous, time - previous]
	_record.add_theme_color_override(&"font_color",
		HudPalette.COIN_DARK if is_new else HudPalette.INK_SOFT)


## HAFTALIK TABLO şeridi (Leaderboard.submitted bilgisi; boşsa / yazılamadıysa gizli).
func show_leaderboard(info: Dictionary) -> void:
	var cls: StringName = StringName(SaveSafe.s(info.get("cls", "")))
	_lb_strip.visible = cls != &"" and not bool(info.get("failed", false))
	if not _lb_strip.visible:
		return
	_lb_class = cls
	_lb_head.text = Loc.t("HAFTALIK TABLO · %s SINIFI") % cls
	if bool(info.get("guest", false)):
		_lb_rank_row.visible = false
		_lb_sub.text = Loc.t("HESAP AÇ, TABLOYA GİR")
		return
	var rank: int = int(info.get("rank", 0))
	var old_rank: int = int(info.get("old_rank", 0))
	var improved: bool = bool(info.get("improved", false))
	_lb_rank_row.visible = rank > 0
	_lb_rank.text = "%d." % rank
	var moved: bool = improved and old_rank > rank
	_lb_old.visible = moved
	_lb_arrow.visible = moved
	_lb_old.text = "%d." % old_rank
	_lb_badge.visible = improved and (moved or old_rank <= 0)
	_lb_badge_text.text = "↑ %d" % (old_rank - rank) if moved else Loc.t("YENİ")
	var lines: PackedStringArray = PackedStringArray()
	var best: String = LeaderboardScreen.time_text(float(info.get("best", 0.0)))
	lines.append(Loc.t("YENİ HAFTALIK EN İYİN %s sn") % best if improved else Loc.t("HAFTALIK EN İYİN %s sn") % best)
	var gap: String = LeaderboardScreen.time_text(float(info.get("gap", 0.0)))
	match StringName(SaveSafe.s(info.get("next_tier", ""))):
		&"top3":
			lines.append(Loc.t("İLK 3'E %s sn KALDI") % gap)
		&"p10":
			lines.append(Loc.t("İLK %%10'A %s sn KALDI") % gap)
		&"p50":
			lines.append(Loc.t("İLK %%50'YE %s sn KALDI") % gap)
	_lb_sub.text = "\n".join(lines)


## Ödüllü reklam teklifi: "REKLAM İZLE +X ₺". Yalnızca oyuncu basarsa reklam gösterilir.
func offer_bonus(amount: int) -> void:
	_bonus_amount = amount
	_bonus_button.text = Loc.t("REKLAM İZLE   +%s ₺") % Hud.format_thousands(amount)
	_bonus_button.disabled = false
	_bonus_button.visible = true


## Reklam bitti ama ödül hak edilmedi (erken kapatıldı): teklif tekrar basılabilir olsun.
func rearm_bonus() -> void:
	if _bonus_amount > 0:
		_bonus_button.disabled = false
		_bonus_button.visible = true


## Ödül verildi: teklif kapanır, ödül satırı bonusu gösterir.
func bonus_granted(amount: int) -> void:
	_bonus_button.visible = false
	_bonus_amount = 0
	_reward.text = Loc.t("%s   +%s ₺ BONUS") % [_reward.text, Hud.format_thousands(amount)]


## RÖVANŞ plakası: kaybedilen yarışta rakip beklerken görünür.
func offer_rematch(on: bool) -> void:
	_rematch_button.visible = on
	_rematch_button.disabled = not on


func hide_bonus() -> void:
	_bonus_amount = 0
	_bonus_button.visible = false


## Eğitim spot ışığı: &"column" (başlık + sonuç + düğmeler).
func tutorial_anchor(id: StringName) -> Control:
	return _column if id == &"column" else null


func open() -> void:
	PlateAnim.pop_in(self, _column)


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	PlateAnim.pop_out(self, _column, func() -> void:
		hide()
		_closing = false
		closed.emit())


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
	_head = _label(&"HudSignTitle", Loc.t("YARIŞ BİTTİ"))
	_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.add_child(_head)
	_column.add_child(sign)

	var plate: PlatePanel = PlatePanel.new()
	plate.theme_type_variation = &"HudCarPlate"
	plate.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 3)
	_title = _label(&"HudPlateTitle", "")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward = _label(&"HudInkValue", "")
	_reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
	_times = _label(&"HudInkCaption", "")
	_times.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_winner = _label(&"HudInkCaption", "")
	_winner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_record = _label(&"HudInkValue", "")
	_record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_record.visible = false
	_owner_row = HBoxContainer.new()
	_owner_row.name = "OwnerRow"
	_owner_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_owner_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_owner_row.add_theme_constant_override(&"separation", 8)
	_owner_row.visible = false
	_owner_avatar = AvatarView.new()
	_owner_avatar.custom_minimum_size = Vector2(46.0, 46.0)
	_owner_row.add_child(_owner_avatar)
	_owner_text = _label(&"HudInkValue", "")
	_owner_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_owner_row.add_child(_owner_text)
	for label: Control in [_title, _owner_row, _reward, _times, _record, _winner]:
		box.add_child(label)
	plate.add_child(box)
	_column.add_child(plate)
	_build_leaderboard_strip()

	_bonus_button = PlateButton.new()
	_bonus_button.name = "BonusButton"
	_bonus_button.theme_type_variation = &"HudPlate"
	_bonus_button.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	_bonus_button.focus_mode = Control.FOCUS_NONE
	_bonus_button.visible = false
	_bonus_button.pressed.connect(func() -> void:
		_bonus_button.disabled = true   # çift dokunuş: reklam bitene kadar pasif
		bonus_requested.emit())
	_column.add_child(_bonus_button)

	_rematch_button = PlateButton.new()
	_rematch_button.name = "RematchButton"
	_rematch_button.theme_type_variation = &"HudPlate"
	_rematch_button.text = Loc.t("RÖVANŞ")
	_rematch_button.kind = HudIcon.Kind.ROTATE
	_rematch_button.icon_left = true
	_rematch_button.icon_size = 20.0
	_rematch_button.highlight = true   # amber: kaybettikten sonra öne çıkan seçenek
	_rematch_button.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	_rematch_button.focus_mode = Control.FOCUS_NONE
	_rematch_button.visible = false
	_rematch_button.pressed.connect(func() -> void:
		_rematch_button.disabled = true   # çift dokunuş: pist yeniden açılana kadar pasif
		rematch_requested.emit())
	_column.add_child(_rematch_button)

	var exit_button: PlateButton = PlateButton.new()
	exit_button.name = "ExitButton"
	exit_button.theme_type_variation = &"HudPlate"
	exit_button.text = Loc.t("GARAJA DÖN")
	exit_button.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	exit_button.focus_mode = Control.FOCUS_NONE
	exit_button.pressed.connect(func() -> void: exit_requested.emit())
	_column.add_child(exit_button)


## Koyu zemin, amber kenar (tablonun ödül şeridiyle aynı dil): solda başlık / sıra / süre, sağda TABLO.
func _build_leaderboard_strip() -> void:
	_lb_strip = PanelContainer.new()
	_lb_strip.name = "LeaderboardStrip"
	_lb_strip.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	_lb_strip.visible = false
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = LeaderboardScreen.DARK
	style.border_color = HudPalette.PLATE_SELECTED
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12.0
	style.content_margin_right = 8.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 6.0
	_lb_strip.add_theme_stylebox_override(&"panel", style)
	_column.add_child(_lb_strip)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 10)
	_lb_strip.add_child(row)
	var text: VBoxContainer = VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override(&"separation", 0)
	row.add_child(text)
	_lb_head = _strip_label(11, HudPalette.PLATE_SELECTED)
	text.add_child(_lb_head)
	_lb_rank_row = HBoxContainer.new()
	_lb_rank_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lb_rank_row.add_theme_constant_override(&"separation", 6)
	text.add_child(_lb_rank_row)
	_lb_old = _strip_label(15, HudPalette.PLATE_EDGE)
	_lb_old.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_lb_rank_row.add_child(_lb_old)
	_lb_arrow = _strip_label(15, HudPalette.PLATE_SELECTED)
	_lb_arrow.text = "→"
	_lb_arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_lb_rank_row.add_child(_lb_arrow)
	_lb_rank = _strip_label(22, HudPalette.TEXT_LIGHT)
	_lb_rank_row.add_child(_lb_rank)
	_lb_badge = PanelContainer.new()
	_lb_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lb_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var badge: StyleBoxFlat = StyleBoxFlat.new()
	badge.bg_color = Color("2E7D32")
	badge.set_corner_radius_all(7)
	badge.content_margin_left = 6.0
	badge.content_margin_right = 6.0
	_lb_badge.add_theme_stylebox_override(&"panel", badge)
	_lb_badge_text = _strip_label(12, Color.WHITE)
	_lb_badge.add_child(_lb_badge_text)
	_lb_rank_row.add_child(_lb_badge)
	_lb_sub = _strip_label(10, HudPalette.SIDEWALK)
	_lb_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(_lb_sub)
	var button: PlateButton = PlateButton.new()
	button.name = "LeaderboardButton"
	button.theme_type_variation = &"HudPlateSmall"
	button.text = Loc.t("TABLO")
	button.highlight = true
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(func() -> void: leaderboard_requested.emit(_lb_class))
	row.add_child(button)


func _strip_label(font_size: int, color: Color) -> Label:
	var label: Label = _label(&"HudInkValue", "")
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	return label


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
