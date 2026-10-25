class_name LevelUpScreen
extends RewardScreen
## SEVİYE ATLADIN — seviye atlayınca ekranın ortasında büyük açılır (kullanıcı kararı 2026-10-21; tasarım tuvali
## "SEVİYE ATLADIN" sayfası, taslak A). Üstte seviye rozeti ve para + gem ödülü, altında AÇILANLAR kartları: yeni
## müşteri işi, depo (fotoğrafıyla), kasa (dönen 3B kasa), modifiye kademesi, görevler, profil çerçevesi (oyuncunun kendi
## avatarıyla), dekor (küçük resimler).
## O seviyede hiçbir şey açılmadıysa SIRADAKİ açılış seviyesi soluk kartlarla gösterilir. Eskiden 2,2 sn'lik
## bildirim plakasıydı. Açılanların tek kaynağı LevelUnlocks (sistemlerin kendi seviye kilitleri).
##
## Oyun SAKİNLEŞİNCE açılır (FounderRewardNotice'teki kural: pano yok, ders yok, kasa / restorasyon paneli yok,
## başka ödül penceresi yok); o arada atlanan seviyeler TEK ekranda birleşir. Hud kurar ve
## PlayerProgress.level_reward'ı add_level'a bağlar. DEVAM'a ya da kartların dışına dokununca kapanır. Görünüm
## (rozet, ışık, haplar, kartlar) RewardScreen tabanında: hediye ekranı (GiftScreen) da aynı dili kullanır.

const CHECK_SEC: float = 0.4
## Oyun bu kadar sakin kalınca açılır (para toplama dokunuşunun hemen ardından araya girmesin).
const CALM_SEC: float = 0.8
## Henüz açılmamış (SIRADAKİ) kartların solukluğu.
const PREVIEW_ALPHA: float = 0.7

## Bekleyen aralık: (from, to] seviyeleri; _to_level == 0 → bekleyen yok.
var _from_level: int = 0
var _to_level: int = 0
var _money: int = 0
## Ekrandaki seviye ödülü (₺): ödüllü reklamla bir kez ×2 (AdPolicy.LEVELUP_DOUBLE).
var _shown_money: int = 0
var _doubled: bool = false
var _double: AdOfferButton
var _gems: int = 0
var _calm: float = 0.0
var _timer: Timer
var _continue: PlateButton


func _init(hud: Hud) -> void:
	_hud = hud
	name = "LevelUpScreen"


func _ready() -> void:
	super._ready()
	_title.text = Loc.t("SEVİYE ATLADIN!")
	_timer = Timer.new()
	_timer.wait_time = CHECK_SEC
	_timer.timeout.connect(_tick)
	add_child(_timer)


## PlayerProgress.level_reward: seviye atlandı, ödülü verildi. Ekran sakin bir anda açılır.
func add_level(level: int, money: int, _text: String = "") -> void:
	if _to_level == 0:
		_from_level = level - 1
	_from_level = mini(_from_level, level - 1)
	_to_level = maxi(_to_level, level)
	_money += money
	_gems += int(PlayerProgress.reward_for(level)["gems"])
	_calm = 0.0
	_timer.start()


## Bekleyen seviye var mı (açılmayı bekliyor ya da ekranda)?
func is_pending() -> bool:
	return _to_level != 0 or visible


## Reklam izlendi: seviye ödülünün ₺'si bir kez daha verilir.
func _on_double() -> void:
	if _doubled or _shown_money <= 0:
		return
	_doubled = true
	var economy: EconomyManager = get_tree().get_first_node_in_group("economy") as EconomyManager
	if economy:
		economy.add_money(_shown_money)
	_money_label.text = "+%s ₺  ×2" % Hud.format_thousands(_shown_money * 2)
	_double.refresh()


func _on_closed() -> void:
	if _to_level != 0:
		_timer.start()


func _tick() -> void:
	if _to_level == 0 or visible:
		return
	if not _game_calm():
		_calm = 0.0
		return
	_calm += CHECK_SEC
	if _calm >= CALM_SEC:
		_timer.stop()
		_open()


func _open() -> void:
	var from_level: int = _from_level
	var to_level: int = _to_level
	(_badge as _Badge).set_level(to_level)
	_set_amounts(_money, _gems)
	_shown_money = _money
	_doubled = false
	_double.reward_text = "+%s ₺" % Hud.format_thousands(_shown_money)
	_double.refresh()
	_from_level = 0
	_to_level = 0
	_money = 0
	_gems = 0

	_clear_cards()
	var unlocks: Array[Dictionary] = LevelUnlocks.between(from_level, to_level)
	var preview: bool = unlocks.is_empty()
	if preview:
		var next: Dictionary = LevelUnlocks.next_after(to_level)
		if not next.is_empty():
			unlocks = next["unlocks"]
			_divider_label.text = Loc.t("SIRADAKİ: SEVİYE %d") % int(next["level"])
	else:
		_divider_label.text = Loc.t("AÇILANLAR")
	_divider.visible = not unlocks.is_empty()
	for entry: Dictionary in unlocks:
		_cards.add_child(_card(entry, PREVIEW_ALPHA if preview else 1.0))
	_present()
	_double.refresh()   # koşulu ekranın görünür olmasına bakar: yukarıdaki tazeleme ekran açılmadan yapıldı


# --- Kurulum -----------------------------------------------------------------

func _make_badge() -> Control:
	return _Badge.new()


func _add_buttons(row: HBoxContainer) -> void:
	_continue = PlateButton.new()
	_continue.theme_type_variation = &"HudPlateSmall"
	_continue.text = Loc.t("DEVAM ET")
	_continue.highlight = true
	_continue.focus_mode = Control.FOCUS_NONE
	_continue.custom_minimum_size = Vector2(200.0, 0.0)
	_continue.pressed.connect(close)
	row.add_child(_continue)
	# Seviye ödülü ×2: oyuncu basarsa ödüllü reklam (kendiliğinden açılmaz)
	_double = AdOfferButton.new(AdPolicy.LEVELUP_DOUBLE)
	_double.custom_minimum_size = Vector2(200.0, 0.0)
	_double.condition = func() -> bool: return visible and not _closing and not _doubled and _shown_money > 0
	_double.rewarded.connect(_on_double)
	row.add_child(_double)


# --- Kartlar -----------------------------------------------------------------

func _card(entry: Dictionary, alpha: float = 1.0) -> Control:
	var tag: String = ""
	var picture: Control = null
	var title: String = ""
	var detail: String = ""
	var need: String = ""
	match int(entry["kind"]):
		LevelUnlocks.Kind.CUSTOMER:
			var type: RepairType = entry["type"]
			tag = Loc.t("YENİ MÜŞTERİ")
			picture = _bubble(HudIcon.Kind.WRENCH, HudPalette.INK)
			title = type.title
			detail = Loc.t("%s · +%s ₺") % [_duration(type.duration), Hud.format_thousands(type.reward)]
			if type.min_garage_level > 1 or type.min_bays > 1:
				need = Loc.t("GARAJ SV.%d + %d ALAN GEREKİR") % [type.min_garage_level, type.min_bays]
		LevelUnlocks.Kind.DEPOT:
			var garage: StringName = entry["id"]
			tag = Loc.t("YENİ DEPO")
			picture = _photo(CarGaragesScreen.card_path(garage))
			title = CarGarageCatalog.display_name(garage)
			detail = Loc.t("%d PARK YERİ · %s ₺") % [CarGarageCatalog.capacity_at(garage, 1),
				Hud.format_thousands(CarGarageCatalog.price(garage))]
		LevelUnlocks.Kind.CRATE:
			var crate: Dictionary = CrateCatalog.get_entry(entry["id"])
			tag = Loc.t("YENİ KASA")
			picture = _CratePreview.new(crate)
			title = Loc.t(String(crate.get("display_name", "")))
			detail = Loc.t("SHOWROOM'DA · %d GEM") % CrateCatalog.sale_price(entry["id"])
		LevelUnlocks.Kind.MOD_TIER:
			var stage: int = int(entry["stage"])
			tag = Loc.t("MODİFİYE")
			picture = _bubble(HudIcon.Kind.GEAR, PerformanceMods.tier_color(stage))
			title = Loc.t("%s KADEMESİ") % PerformanceMods.tier_name(stage)
			detail = Loc.t("YARIŞ ARACINA YENİ PARÇALAR")
		LevelUnlocks.Kind.MISSIONS:
			tag = Loc.t("YENİ")
			picture = _bubble(HudIcon.Kind.CHECK, HudPalette.INK)
			title = Loc.t("GÖREVLER")
			detail = Loc.t("GÜNLÜK VE HAFTALIK ÖDÜLLER")
		LevelUnlocks.Kind.FRAME:
			var frame: Dictionary = ProfileCatalog.frame(String(entry["id"]))
			tag = Loc.t("ÇERÇEVE")
			picture = _framed_avatar(String(entry["id"]))
			title = Loc.t("%s ÇERÇEVE") % Loc.t(String(frame.get("name", "")))
			detail = Loc.t("PROFİLİNDE KULLANABİLİRSİN")
		LevelUnlocks.Kind.DECOR:
			var items: Array[StringName] = entry["items"]
			tag = Loc.t("YENİ DEKOR")
			picture = _decor_strip(items)
			title = Loc.tn("%d YENİ EŞYA", items.size()) % items.size()
			var names: PackedStringArray = PackedStringArray()
			for i: int in mini(items.size(), 2):
				names.append(Loc.t(String(GarageDecor.get_item(items[i]).get("title", ""))))
			detail = " · ".join(names) + ("…" if items.size() > 2 else "")
	return _card_from(tag, picture, title, detail, need, alpha)


static func _duration(seconds: float) -> String:
	return Loc.t("%d sn") % roundi(seconds) if seconds < 60.0 else ModWorkshop.duration_text(seconds)


# --- Çizimler ------------------------------------------------------------------

## Amber seviye rozeti: koyu halka, üstte küçük SEVİYE, ortada büyük sayı.
class _Badge extends Control:
	var _caption: Label
	var _number: Label

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var box: VBoxContainer = VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override(&"separation", 0)
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(box)
		_caption = _make(9)
		_caption.text = Loc.t("SEVİYE")
		box.add_child(_caption)
		_number = _make(28)
		box.add_child(_number)

	func set_level(level: int) -> void:
		_number.text = str(level)

	func _make(font_size: int) -> Label:
		var label: Label = Label.new()
		label.theme_type_variation = &"HudSignTitle"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override(&"font_size", font_size)
		label.add_theme_color_override(&"font_color", HudPalette.INK)
		return label

	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var radius: float = minf(size.x, size.y) * 0.5
		draw_circle(center + Vector2(0.0, 3.0), radius, HudPalette.SHADOW, true, -1.0, true)
		draw_circle(center, radius, HudPalette.PLATE_SELECTED, true, -1.0, true)
		draw_circle(center, radius - 3.0, HudPalette.INK, true, -1.0, true)
		draw_circle(center, radius - 7.0, HudPalette.PLATE_SELECTED, true, -1.0, true)
