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
var _level: Label
var _garage_row: HBoxContainer
var _garage_label: Label
var _stats: Dictionary = {}   # anahtar → değer etiketi
var _best_caption: Label
var _thumb: TextureRect
var _car_name: Label
var _person: Dictionary = {}


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
	_stats["cars"].text = "%d / %d" % [SaveSafe.i(stats.get("cars", 0)), VehicleOwnership.collection_ids().size()]
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


## "UÇAK HANGARI · 5 GARAJ · 64 YER" (özet boşsa ""). Dar sütun (≈240 birim): tek boşluklu ayraç, kısa birim.
static func garage_text(summary: Dictionary) -> String:
	var own: Array = summary.get("own", []) if summary.get("own") is Array else []
	if own.is_empty():
		return ""
	var top: StringName = StringName(SaveSafe.s(own[own.size() - 1]))
	var cap: int = SaveSafe.i(summary.get("cap", 0))
	return " · ".join(PackedStringArray([Loc.upper(CarGarageCatalog.display_name(top)),
		Loc.tn("%d GARAJ", own.size()) % own.size(), Loc.tn("%d YER", cap) % cap]))


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
