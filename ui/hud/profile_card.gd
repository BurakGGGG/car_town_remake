class_name ProfileCard
extends PlatePanel
## PROFİL KARTI (plaka): avatar + çerçeve + bayrak, takma ad, garaj adı, seviye / garaj değeri, yarış /
## koleksiyon / en iyi 300 m ve vitrin aracı. Kendi profil ekranın (ProfileScreen), arkadaş kartı
## (FriendCardScreen) ve ileride yarış davet / sonuç panoları aynı kartı kullanır. Kodla kurulur.
##
## KİŞİ SÖZLÜĞÜ (show_person): {uid, name, level, value, av, frame, flag, title, car, stats{wins, races, cars, best,
## best_car}, featured, garages{own, cap}}. `garages` (GARAJLARIM özeti, PublicGarage.car_garage_summary) yoksa garaj
## şeridi gizlenir (eski sürümdeki arkadaş, öne çıkan garajlar). SocialManager arkadaş girdileri, FeaturedFriends.all() ve me() aynı biçimdedir.
## `actions`: kartın sağ altındaki boş sütun; ekran kendi düğmesini (DÜZENLE) koyar.
## TABLO DERECELERİ şeridi (taslak A, kullanıcı 2026-10-26): kişinin haftalık drag tablosunda ilk 100'e girdiği haftalar
## (Leaderboard.history_of, lb_hist/{uid}) varsa istatistiklerin altında koyu şerit: en iyi derece + sınıf + hafta, kaç kez
## ilk 100 / ilk 3. Şeridin TAMAMI dokunulur ("TÜMÜ ›"; kendi profilinde bilgi sütunu dar: plaka düğme yazıları kesiyordu)
## → records_requested (DERECELER listesi). Derecesi yoksa / öne çıkan kişide / listeyi açan ekran yoksa görünmez.

## TÜMÜ: {uid (sunucudaki kimlik), name, recs}.
signal records_requested(info: Dictionary)

const CARD_WIDTH: float = 500.0
const AVATAR_SIZE: float = 116.0
const THUMB_SIZE: Vector2 = Vector2(112.0, 70.0)
const THUMB_DIR: String = "res://assets/cars/thumbs/"
## Kendi kartımın kimliği (avatar PlayerProfile'dan çizilir).
const ME: String = "me"

var actions: VBoxContainer

var _avatar: AvatarView
var _name: Label
var _flag: FlagIcon
var _title: Label
var _honor: PanelContainer   # unvan şeridi (KOLEKSİYONER): ProfileCatalog.HONORS
var _level: Label
var _garage_row: HBoxContainer
var _garage_label: Label
var _stats: Dictionary = {}   # anahtar → değer etiketi
var _best_caption: Label
var _thumb: TextureRect
var _car_name: Label
var _person: Dictionary = {}
var _records: PanelContainer
var _rec_rank: Label
var _rec_class: Label
var _rec_week: Label
var _rec_counts: Label
var _recs: Array[Dictionary] = []
var _rec_uid: String = ""
var _rec_gen: int = 0


func _init() -> void:
	theme_type_variation = &"HudCarPlate"
	custom_minimum_size = Vector2(CARD_WIDTH, 0.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 12)
	add_child(row)

	_avatar = AvatarView.new()
	_avatar.custom_minimum_size = Vector2(AVATAR_SIZE, AVATAR_SIZE)
	_avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_avatar)

	var info: VBoxContainer = VBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override(&"separation", 2)
	row.add_child(info)
	var name_row: HBoxContainer = HBoxContainer.new()
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_theme_constant_override(&"separation", 8)
	_name = _label(&"HudPlateTitle", "")
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.clip_text = true
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_name)
	_flag = FlagIcon.new()
	_flag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(_flag)
	info.add_child(name_row)
	_honor = PanelContainer.new()
	_honor.name = "Honor"
	_honor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_honor.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var honor_box: StyleBoxFlat = StyleBoxFlat.new()
	honor_box.bg_color = HudPalette.PLATE_SELECTED
	honor_box.set_corner_radius_all(5)
	honor_box.content_margin_left = 7.0
	honor_box.content_margin_right = 7.0
	honor_box.content_margin_top = 1.0
	honor_box.content_margin_bottom = 1.0
	_honor.add_theme_stylebox_override(&"panel", honor_box)
	var honor_label: Label = _label(&"HudInkCaption", "")
	honor_label.add_theme_font_size_override(&"font_size", 11)
	_honor.add_child(honor_label)
	_honor.visible = false
	info.add_child(_honor)
	_title = _label(&"HudInkCaption", "")
	_title.add_theme_color_override(&"font_color", HudPalette.PLATE_SELECTED_EDGE)
	info.add_child(_title)
	_level = _label(&"HudInkCaption", "")
	info.add_child(_level)
	# GARAJLARIM rozeti: en üst garaj + garaj sayısı + toplam park yeri (kullanıcı kararı 2026-10-19)
	_garage_row = HBoxContainer.new()
	_garage_row.name = "GarageRow"
	_garage_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_garage_row.add_theme_constant_override(&"separation", 5)
	var garage_icon: HudIcon = HudIcon.new()
	garage_icon.kind = HudIcon.Kind.GARAGE
	garage_icon.icon_size = 14.0
	garage_icon.color = HudPalette.COIN_DARK
	garage_icon.custom_minimum_size = Vector2(16.0, 16.0)
	garage_icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_garage_row.add_child(garage_icon)
	# Uzun dillerde (EN/ES "NEIGHBORHOOD GARAGE · …" ≈ 280 > 239 birim) ikinci satıra kayar: bilgi kesilmez
	_garage_label = _label(&"HudInkCaption", "")
	_garage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_garage_label.max_lines_visible = 2
	_garage_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_garage_row.add_child(_garage_label)
	_garage_row.visible = false
	info.add_child(_garage_row)

	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override(&"h_separation", 14)
	grid.add_theme_constant_override(&"v_separation", 0)
	for key: String in ["races", "cars", "best", "likes"]:
		var caption: String = {"races": Loc.t("YARIŞ"), "cars": Loc.t("KOLEKSİYON"), "best": Loc.t("EN İYİ 300 M"),
			"likes": Loc.t("BEĞENİ")}[key]
		grid.add_child(_label(&"HudInkCaption", caption))
	for key: String in ["races", "cars", "best", "likes"]:
		var value: Label = _label(&"HudInkValue", "–")
		grid.add_child(value)
		_stats[key] = value
	info.add_child(grid)
	_best_caption = _label(&"HudInkCaption", "")
	info.add_child(_best_caption)
	_build_records(info)

	var side: VBoxContainer = VBoxContainer.new()
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_theme_constant_override(&"separation", 2)
	row.add_child(side)
	side.add_child(_label(&"HudInkCaption", Loc.t("VİTRİN")))
	_thumb = TextureRect.new()
	_thumb.custom_minimum_size = THUMB_SIZE
	_thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_child(_thumb)
	_car_name = _label(&"HudInkCaption", "")
	_car_name.custom_minimum_size = Vector2(THUMB_SIZE.x, 0.0)
	_car_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_car_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_car_name.clip_text = true
	side.add_child(_car_name)
	actions = VBoxContainer.new()
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.size_flags_vertical = Control.SIZE_EXPAND_FILL
	actions.alignment = BoxContainer.ALIGNMENT_END
	side.add_child(actions)


## Koyu şerit (tablo ekranının ödül şeridi dili): kupa · başlık / en iyi derece / sayılar · TÜMÜ.
func _build_records(parent: Control) -> void:
	_records = PanelContainer.new()
	_records.name = "LbRecords"
	_records.mouse_filter = Control.MOUSE_FILTER_STOP
	_records.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_records.visible = false
	_records.gui_input.connect(func(event: InputEvent) -> void:
		var tap: InputEventMouseButton = event as InputEventMouseButton
		if tap and tap.button_index == MOUSE_BUTTON_LEFT and not tap.pressed:
			request_records())
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = LeaderboardScreen.DARK
	style.border_color = HudPalette.PLATE_SELECTED
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	style.content_margin_left = 8.0
	style.content_margin_right = 6.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 4.0
	_records.add_theme_stylebox_override(&"panel", style)
	parent.add_child(_records)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 7)
	_records.add_child(row)
	var trophy: HudIcon = HudIcon.new()
	trophy.kind = HudIcon.Kind.TROPHY
	trophy.color = HudPalette.COIN
	trophy.icon_size = 22.0
	trophy.custom_minimum_size = Vector2(24.0, 24.0)
	trophy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(trophy)
	var texts: VBoxContainer = VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override(&"separation", -2)
	row.add_child(texts)
	texts.add_child(_dark_label(Loc.t("TABLO DERECELERİ"), 10, HudPalette.PLATE_SELECTED))
	var best: HBoxContainer = HBoxContainer.new()
	best.mouse_filter = Control.MOUSE_FILTER_IGNORE
	best.add_theme_constant_override(&"separation", 5)
	texts.add_child(best)
	_rec_rank = _dark_label("", 18, HudPalette.TEXT_LIGHT)
	best.add_child(_rec_rank)
	var pill: PanelContainer = PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pill_box: StyleBoxFlat = StyleBoxFlat.new()
	pill_box.bg_color = HudPalette.PLATE_SELECTED
	pill_box.set_corner_radius_all(4)
	pill_box.content_margin_left = 4.0
	pill_box.content_margin_right = 4.0
	pill.add_theme_stylebox_override(&"panel", pill_box)
	_rec_class = _dark_label("", 10, HudPalette.INK)
	pill.add_child(_rec_class)
	best.add_child(pill)
	_rec_week = _dark_label("", 10, HudPalette.SIDEWALK)
	_rec_week.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_rec_week.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_rec_week.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	best.add_child(_rec_week)
	_rec_counts = _dark_label("", 10, HudPalette.SIDEWALK)
	_rec_counts.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(_rec_counts)
	var all: Label = _dark_label(Loc.t("TÜMÜ ›"), 11, HudPalette.PLATE_SELECTED)
	all.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(all)


## DERECELER listesi istenir (şeride dokunuş; testler de çağırır).
func request_records() -> void:
	if _recs.is_empty():
		return
	records_requested.emit({"uid": _rec_uid, "name": _name.text, "recs": _recs.duplicate()})


## Kişinin dereceleri sunucudan (öne çıkan kişide yok). Kişi bu arada değiştiyse eski cevap atılır.
func _load_records(entry: Dictionary) -> void:
	_rec_gen += 1
	var gen: int = _rec_gen
	_records.visible = false
	_recs = []
	var uid: String = SaveSafe.s(entry.get("uid", ""))
	if uid == ME:
		var social: SocialManager = get_tree().get_first_node_in_group("social") as SocialManager
		uid = social.uid() if social else ""
	_rec_uid = uid if not FeaturedFriends.is_featured(uid) else ""
	var board: Leaderboard = get_tree().get_first_node_in_group("leaderboard") as Leaderboard
	if _rec_uid.is_empty() or board == null or records_requested.get_connections().is_empty():
		return   # listeyi açan ekran yok (davet kartı): şerit de yok
	var recs: Array[Dictionary] = await board.history_of(_rec_uid)
	if gen != _rec_gen or recs.is_empty():
		return
	_recs = recs
	var summary: Dictionary = Leaderboard.history_summary(recs)
	var best: Dictionary = summary["best"]
	_rec_rank.text = "%d." % int(best["rank"])
	_rec_class.text = String(best["cls"])
	_rec_week.text = Leaderboard.week_text(int(best["wk"]))
	var counts: String = Loc.t("%d KEZ İLK 100") % int(summary["count"])
	if int(summary["top3"]) > 0:
		counts += " · " + Loc.t("%d KEZ İLK 3") % int(summary["top3"])
	_rec_counts.text = counts
	_records.visible = true


func _dark_label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = _label(&"HudInkValue", text)
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	return label


## Gösterilen kişi (son show_person).
func person() -> Dictionary:
	return _person


func show_person(entry: Dictionary) -> void:
	_person = entry
	var art: Dictionary = avatar_for(get_tree(), entry) if is_inside_tree() else {}
	_avatar.show_avatar(art.get("texture"), bool(art.get("illustrated", true)), SaveSafe.s(entry.get("frame", "")))
	var name: String = SaveSafe.s(entry.get("name", ""))
	_name.text = Loc.upper(name) if not name.is_empty() else Loc.t("OYUNCU")
	_flag.code = SaveSafe.s(entry.get("flag", ""))
	var honor: String = SaveSafe.s(entry.get("honor", ""))
	(_honor.get_child(0) as Label).text = "★ " + ProfileCatalog.honor_name(honor) if ProfileCatalog.is_honor(honor) else ""
	_honor.visible = ProfileCatalog.is_honor(honor)
	var title: String = SaveSafe.s(entry.get("title", ""))
	_title.text = title   # yazıldığı gibi: Türkçe büyük harf İngilizce adı "RACİNG" yapıyordu
	_title.visible = not title.is_empty()
	var level_text: String = Loc.t("SEVİYE %d") % maxi(SaveSafe.i(entry.get("level", 1)), 1)
	var value: int = SaveSafe.i(entry.get("value", 0))
	if value > 0:
		level_text += Loc.t("  ·  GARAJ %s ₺") % Hud.format_thousands(value)
	if bool(entry.get("featured", false)):
		level_text += Loc.t("  ·  AUTO YARD USTASI")
	_level.text = level_text
	var garages: Dictionary = entry.get("garages", {}) if entry.get("garages") is Dictionary else {}
	_garage_label.text = garage_text(garages)
	_garage_row.visible = not _garage_label.text.is_empty()
	var stats: Dictionary = entry.get("stats", {}) if entry.get("stats") is Dictionary else {}
	var races: int = SaveSafe.i(stats.get("races", 0))
	var wins: int = SaveSafe.i(stats.get("wins", 0))
	_stats["races"].text = Loc.t("%d GALİBİYET") % wins if races > 0 else "–"
	_stats["cars"].text = "%d / %d" % [SaveSafe.i(stats.get("cars", 0)), CollectionRewards.total_count()]
	var best: int = SaveSafe.i(stats.get("best", 0))
	_stats["best"].text = Loc.t("%s sn") % Loc.decimal(best / 1000.0, 2) if best > 0 else "–"
	var likes: int = SaveSafe.i(stats.get("likes", 0))
	_stats["likes"].text = Hud.format_thousands(likes) if likes > 0 else "–"
	var best_car: Dictionary = CarCatalog.get_entry(StringName(SaveSafe.s(stats.get("best_car", ""))))
	var caption: PackedStringArray = PackedStringArray()
	if races > 0:
		caption.append(Loc.t("%d YARIŞ · %s KAZANMA") % [races, Loc.percent(str(roundi(100.0 * wins / races)))])
	if best > 0 and not best_car.is_empty():
		caption.append(Loc.t("REKOR: %s") % String(best_car.get("display_name", "")).to_upper())
	_best_caption.text = "  ·  ".join(caption)
	_best_caption.visible = not caption.is_empty()
	var car_id: String = SaveSafe.s(entry.get("car", ""))
	var car: Dictionary = CarCatalog.get_entry(StringName(car_id))
	var thumb_path: String = THUMB_DIR + car_id + ".png"
	_thumb.texture = load(thumb_path) as Texture2D if not car.is_empty() and ResourceLoader.exists(thumb_path) else null
	_car_name.text = CarCatalog.label(car) if not car.is_empty() else Loc.t("SEÇİLMEDİ")
	if is_inside_tree():
		_load_records(entry)


## "UÇAK HANGARI · 5 GARAJ · 64 YER" (özet boşsa ""). Dar sütun (≈240 birim): tek boşluklu ayraç, kısa birim.
static func garage_text(summary: Dictionary) -> String:
	var own: Array = summary.get("own", []) if summary.get("own") is Array else []
	if own.is_empty():
		return ""
	var top: StringName = StringName(SaveSafe.s(own[own.size() - 1]))
	var cap: int = SaveSafe.i(summary.get("cap", 0))
	return " · ".join(PackedStringArray([Loc.upper(CarGarageCatalog.display_name(top)),
		Loc.tn("%d DEPO", own.size()) % own.size(), Loc.tn("%d YER", cap) % cap]))


## Avatar resmi: kendi kartım PlayerProfile'dan, öne çıkanlar oyunla gelen portreden, diğerleri SocialManager
## önbelleğinden (henüz inmediyse kask; inince SocialManager.avatar_ready).
static func avatar_for(tree: SceneTree, entry: Dictionary) -> Dictionary:
	var uid: String = SaveSafe.s(entry.get("uid", ""))
	if uid == ME:
		var profile: PlayerProfile = tree.get_first_node_in_group("player_profile") as PlayerProfile
		if profile:
			return {"texture": profile.my_texture(), "illustrated": profile.my_illustrated()}
		return {"texture": ProfileCatalog.default_texture(), "illustrated": true}
	if FeaturedFriends.is_featured(uid):
		return {"texture": ProfileCatalog.featured_texture(uid), "illustrated": true}
	var social: SocialManager = tree.get_first_node_in_group("social") as SocialManager
	if social:
		return social.avatar_of(uid, SaveSafe.s(entry.get("av", "")))
	return {"texture": ProfileCatalog.default_texture(), "illustrated": true}


## Kendi kartımın kişi sözlüğü (yerel durumdan; sunucuya gitmez).
static func me(tree: SceneTree) -> Dictionary:
	var out: Dictionary = {"uid": ME, "name": "", "level": 1, "value": GarageValue.compute(tree)}
	var social: SocialManager = tree.get_first_node_in_group("social") as SocialManager
	if social and not social.my_name().is_empty():
		out["name"] = social.my_name()
	else:
		var cloud: CloudSaveManager = tree.get_first_node_in_group("cloud_save") as CloudSaveManager
		if cloud:
			out["name"] = SaveSafe.s(cloud.get_profile().get("display_name", ""))
	var progress: PlayerProgress = tree.get_first_node_in_group("player_progress") as PlayerProgress
	if progress:
		out["level"] = progress.level
	var profile: PlayerProfile = tree.get_first_node_in_group("player_profile") as PlayerProfile
	if profile:
		out.merge(profile.public_fields())
	var garages: CarGarageManager = tree.get_first_node_in_group("car_garages") as CarGarageManager
	if garages:
		out["garages"] = garages.public_summary()
	return out


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
