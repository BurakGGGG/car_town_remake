class_name CollectionRewardScreen
extends RewardScreen
## SET TAMAMLANDI! — koleksiyon ödülü ekranı (2026-10-25, P1 koleksiyon; kullanıcı kararı: set tamamlanınca büyük ekran,
## setin araçlarının fotoğraflarıyla). CollectionRewards.rewarded: ödül hesaba geçmiştir, sayaçlar bekler (hold_reward);
## ekran oyun SAKİNLEŞİNCE açılır (SEVİYE ATLADIN'daki kural: kasa sonucu plakası kapanmadan araya girmez), o arada gelen
## ödüller TEK ekranda birleşir. Kartlar: tamamlanan set (araçların fotoğrafları, set adı, ödülü), kilometre taşı
## (N ARAÇ), TAM KOLEKSİYON'da KOLEKSİYONER çerçevesi (oyuncunun avatarıyla) + KOLEKSİYONER KUPASI (dekor resmi) +
## unvan. TOPLA'ya ya da boş yere dokununca kapanır, paralar sayaçlara uçar. Hud kurar.

const CHECK_SEC: float = 0.4
const CALM_SEC: float = 0.8
## Yan yana en çok bu kadar kart (en dar tuvalde 853 birim); fazla set tek "+N SET" kartında toplanır.
const MAX_CARDS: int = 5
## Set kartında yan yana araç fotoğrafı (kalanı köşede +N).
const SET_PHOTOS: int = 3

## Bekleyen (birleşmiş) ödül: {sets, milestones, money, gems, final}; boş → bekleyen yok.
var _pending: Dictionary = {}
var _shown_money: int = 0
var _shown_gems: int = 0
var _calm: float = 0.0
var _timer: Timer
var _subtitle: Label
var _collect: PlateButton


func _init(hud: Hud) -> void:
	_hud = hud
	name = "CollectionRewardScreen"


func _ready() -> void:
	super._ready()
	_subtitle = _label(&"HudOutlined", "")
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override(&"font_size", 13)
	_column.add_child(_subtitle)
	_column.move_child(_subtitle, _title.get_index() + 1)
	_timer = Timer.new()
	_timer.wait_time = CHECK_SEC
	_timer.timeout.connect(_tick)
	add_child(_timer)


## CollectionRewards.rewarded: {sets, milestones, money, gems, final}. Ödül hesapta; sayaçlar ekran kapanana dek bekler.
func add_reward(entry: Dictionary) -> void:
	var money: int = int(entry.get("money", 0))
	var gems: int = int(entry.get("gems", 0))
	if _hud:
		_hud.hold_reward(money, gems)
	if _pending.is_empty():
		_pending = {"sets": [], "milestones": [], "money": 0, "gems": 0, "final": false}
	for set_id: Variant in entry.get("sets", []):
		(_pending["sets"] as Array).append(StringName(set_id))
	for count: Variant in entry.get("milestones", []):
		(_pending["milestones"] as Array).append(int(count))
	_pending["money"] = int(_pending["money"]) + money
	_pending["gems"] = int(_pending["gems"]) + gems
	_pending["final"] = bool(_pending["final"]) or entry.get("final", false) == true
	_calm = 0.0
	_timer.start()


## Bekleyen ödül var mı (açılmayı bekliyor ya da ekranda)?
func is_pending() -> bool:
	return not _pending.is_empty() or visible


func _tick() -> void:
	if _pending.is_empty() or visible:
		return
	if not _game_calm():
		_calm = 0.0
		return
	_calm += CHECK_SEC
	if _calm >= CALM_SEC:
		_timer.stop()
		_open()


func _open() -> void:
	var entry: Dictionary = _pending
	_pending = {}
	var sets: Array = entry["sets"]
	var milestones: Array = entry["milestones"]
	milestones.sort()
	var final: bool = entry["final"]
	_shown_money = int(entry["money"])
	_shown_gems = int(entry["gems"])
	_set_amounts(_shown_money, _shown_gems)
	(_badge as _TrophyBadge).collector = final
	_badge.queue_redraw()
	if final:
		_title.text = Loc.t("TAM KOLEKSİYON!")
	elif sets.size() > 1:
		_title.text = Loc.t("%d SET TAMAMLANDI!") % sets.size()
	elif sets.size() == 1:
		_title.text = Loc.t("SET TAMAMLANDI!")
	else:
		_title.text = Loc.t("KOLEKSİYON BÜYÜYOR!")
	var ownership: VehicleOwnership = get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	_subtitle.text = Loc.t("KOLEKSİYON  %d / %d") % [CollectionRewards.found_count(ownership),
		CollectionRewards.total_count()]
	_divider_label.text = Loc.t("ÖDÜLLER")
	_clear_cards()
	var extra: Array[Control] = []
	var passed: Array[int] = []   # TAM KOLEKSİYON taşı kendi kartlarında
	for count: int in milestones:
		if not (final and count == CollectionRewards.final_milestone()):
			passed.append(count)
	if not passed.is_empty():
		extra.append(_milestone_card(passed))
	if final:
		extra.append_array(_final_cards())
	var room: int = maxi(MAX_CARDS - extra.size(), 1)
	var set_cards: int = sets.size() if sets.size() <= room else room - 1
	for i: int in set_cards:
		var set_entry: Dictionary = CrateCatalog.get_set(sets[i])
		if not set_entry.is_empty():
			_cards.add_child(_set_card(set_entry))
	if set_cards < sets.size():
		_cards.add_child(_more_sets_card(sets.slice(set_cards), set_cards == 0))
	for card: Control in extra:
		_cards.add_child(card)
	_divider.visible = _cards.get_child_count() > 0
	_present()


func _on_closing() -> void:
	_fly(_shown_money, _shown_gems)
	_shown_money = 0
	_shown_gems = 0


func _on_closed() -> void:
	if not _pending.is_empty():
		_timer.start()


# --- Kartlar -----------------------------------------------------------------

func _set_card(set_entry: Dictionary) -> Control:
	var cars: Array = set_entry["cars"]
	var reward: Dictionary = CollectionRewards.set_reward(set_entry)
	var amounts: PackedStringArray = PackedStringArray()
	if int(reward["money"]) > 0:
		amounts.append("+%s ₺" % Hud.format_thousands(int(reward["money"])))
	if int(reward["gems"]) > 0:
		amounts.append(Loc.t("+%d GEM") % int(reward["gems"]))
	return _card_from(Loc.t("SET TAMAM"), _car_strip(cars), Loc.t(String(set_entry["name"])),
		Loc.tn("%d ARAÇLIK SET", cars.size()) % cars.size(), "  ·  ".join(amounts))


## Sığmayan setler tek kartta: araç fotoğrafları (bir araç birkaç sette olabilir, bir kez), "+N SET DAHA"; hiçbir set
## ayrı kart almadıysa (TAM KOLEKSİYON'da yer kalmaz) "N SET".
func _more_sets_card(set_ids: Array, all_sets: bool) -> Control:
	var names: PackedStringArray = PackedStringArray()
	var cars: Array = []
	for set_id: Variant in set_ids:
		var set_entry: Dictionary = CrateCatalog.get_set(StringName(set_id))
		if set_entry.is_empty():
			continue
		names.append(Loc.t(String(set_entry["name"])))
		for car: StringName in set_entry["cars"]:
			if not cars.has(car):
				cars.append(car)
	var count: int = set_ids.size()
	var title: String = Loc.tn("%d SET", count) % count if all_sets else Loc.tn("+%d SET DAHA", count) % count
	return _card_from(Loc.t("SET TAMAM"), _car_strip(cars), title, " · ".join(names))


## Geçilen kilometre taşları tek kartta (bir araç birkaç taşı birden geçirebilir: hediye, eski kayıt).
func _milestone_card(counts: Array[int]) -> Control:
	var count: int = counts.back()
	var gems: int = 0
	for passed: int in counts:
		gems += int(CollectionRewards.MILESTONES.get(passed, 0))
	return _card_from(Loc.t("KİLOMETRE TAŞI"), _bubble(HudIcon.Kind.TROPHY, HudPalette.COIN_DARK),
		Loc.tn("%d ARAÇ", count) % count, Loc.t("KOLEKSİYONUNDA %d ARAÇ VAR") % count, Loc.t("+%d GEM") % gems)


## TAM KOLEKSİYON: çerçeve, kupa, unvan.
func _final_cards() -> Array[Control]:
	var frame: Dictionary = ProfileCatalog.frame(CollectionRewards.FINAL_FRAME)
	var trophy: Array[StringName] = [CollectionRewards.FINAL_DECOR]
	var count: int = CollectionRewards.final_milestone()
	return [
		_card_from(Loc.t("ÇERÇEVE"), _framed_avatar(CollectionRewards.FINAL_FRAME),
			Loc.t("%s ÇERÇEVE") % Loc.t(String(frame.get("name", ""))), Loc.t("PROFİLİNDE KULLANABİLİRSİN")),
		_card_from(Loc.t("DEKOR"), _decor_strip(trophy),
			Loc.t(String(GarageDecor.get_item(CollectionRewards.FINAL_DECOR).get("title", ""))),
			Loc.t("GARAJI DÜZENLE'DE YERLEŞTİR"), Loc.t("MAĞAZADA YOK")),
		_card_from(Loc.t("UNVAN"), _bubble(HudIcon.Kind.TROPHY, HudPalette.PLATE_SELECTED),
			"★ " + ProfileCatalog.honor_name(CollectionRewards.FINAL_HONOR), Loc.t("PROFİL KARTINDA GÖRÜNÜR"),
			Loc.tn("%d ARAÇ", count) % count + "  ·  " + Loc.t("+%d GEM") % int(CollectionRewards.MILESTONES[count])),
	]


## Setin ilk SET_PHOTOS aracının fotoğrafı yan yana (assets/cars/thumbs), kalanların sayısı köşede.
func _car_strip(cars: Array) -> Control:
	var holder: MarginContainer = MarginContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: StringName in [&"margin_top", &"margin_right"]:
		holder.add_theme_constant_override(side, 4)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 0)
	holder.add_child(row)
	for i: int in mini(cars.size(), SET_PHOTOS):
		var photo: TextureRect = _photo(ProfileCard.THUMB_DIR + String(cars[i]) + ".png")
		photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		photo.custom_minimum_size = Vector2(0.0, PIC_HEIGHT - 4.0)   # genişlik kartın: dar ekranda kartı büyütmesin
		photo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(photo)
	if cars.size() > SET_PHOTOS:
		var more: PanelContainer = PanelContainer.new()
		more.mouse_filter = Control.MOUSE_FILTER_IGNORE
		more.size_flags_horizontal = Control.SIZE_SHRINK_END
		more.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		more.add_theme_stylebox_override(&"panel", _rounded(HudPalette.INK, 9, 6.0, 1.0))
		var label: Label = _label(&"HudInkCaption", "+%d" % (cars.size() - SET_PHOTOS))
		label.add_theme_color_override(&"font_color", HudPalette.TEXT_LIGHT)
		more.add_child(label)
		holder.add_child(more)
	return holder


# --- Kurulum -----------------------------------------------------------------

func _make_badge() -> Control:
	return _TrophyBadge.new()


func _add_buttons(row: HBoxContainer) -> void:
	_collect = PlateButton.new()
	_collect.name = "CollectButton"
	_collect.theme_type_variation = &"HudPlateSmall"
	_collect.text = Loc.t("TOPLA")
	_collect.highlight = true
	_collect.focus_mode = Control.FOCUS_NONE
	_collect.custom_minimum_size = Vector2(220.0, 0.0)
	_collect.pressed.connect(close)
	row.add_child(_collect)


## Amber rozet (seviye rozetiyle aynı halkalar), içinde kupa; TAM KOLEKSİYON'da KOLEKSİYONER çerçevesinin lacivert-altını.
class _TrophyBadge extends Control:
	const NAVY: Color = Color("1F2A4A")
	const GOLD: Color = Color("F5BE4C")

	var collector: bool = false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var radius: float = minf(size.x, size.y) * 0.5
		var ring: Color = GOLD if collector else HudPalette.PLATE_SELECTED
		var fill: Color = NAVY if collector else HudPalette.PLATE
		draw_circle(center + Vector2(0.0, 3.0), radius, HudPalette.SHADOW, true, -1.0, true)
		draw_circle(center, radius, ring, true, -1.0, true)
		draw_circle(center, radius - 3.0, HudPalette.INK, true, -1.0, true)
		draw_circle(center, radius - 7.0, fill, true, -1.0, true)
		HudIcon.draw_icon(self, HudIcon.Kind.TROPHY, center + Vector2(0.0, 1.0), radius * 1.1,
			GOLD if collector else HudPalette.INK, fill)
