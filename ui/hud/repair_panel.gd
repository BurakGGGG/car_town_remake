class_name RepairPanel
extends HBoxContainer
## Araç bilgi plakasının (HUD %CarInfoPanel) içine yerleşen tamir içeriği — "plaka" dili:
## solda iş seçim plakaları (küçük plakalar: "MOTOR / 10 sn"; müşterinin istediği iş amber/basılı,
## kilitli işler soluk) ve seçili işin satırı (maliyet → ödül, XP, kilit/bakiye notu); sağda
## TAMİR ET plakası ve ödül satırı.
## Yol kenarında bekleyen müşteri: ARIZA plakası (müşteriye atanmış arıza: MOTOR / FREN / LASTİK /
## KAPORTA, süresiyle birlikte) + TAMİRE AL (CarSpot doluysa "TAMİR ALANI DOLU", kapalı). Arıza
## seçilmez; müşteriyle birlikte gelir ve TAMİRE AL o arızayı tamir eder.
## Tamir sürerken: anahtar ikonu + "TAMİR EDİLİYOR", şerit ilerleme çizgisi (XpLane) ve kalan süre.
## Sayaç bitince: "TAMİR HAZIR" + PARA TOPLA plakası (para ikonu), altında "+150 ₺ +7 XP" — ödül
## toplanınca verilir. Toplanınca: onay işareti + "TAMİR TAMAMLANDI", "+150 ₺  +7 XP".
## Yalnızca görsel: durumu HUD verir, TAMİRE AL basılınca repair_pressed, PARA TOPLA basılınca
## collect_pressed yayılır.

## Müşterinin arızası için TAMİRE AL basıldı.
signal repair_pressed(type: RepairType)
## PARA TOPLA basıldı (ödül hazır).
signal collect_pressed
## "REKLAM İZLE" (süre kısaltma) basıldı — açık onay; reklamı HUD yönetir.
signal boost_pressed

enum Mode { DAMAGED, BUSY, REPAIRING, READY, REPAIRED, NORMAL }

const BUTTON_WIDTH: float = 86.0
const JOB_PLATE_WIDTH: float = 66.0

var _mode: Mode = Mode.DAMAGED
var _reward: int = 0
var _xp: int = 0
var _cost: int = 0

# Sol: bilgi alanı (durumlara göre biri görünür)
var _damaged_box: VBoxContainer
var _issue_row: HBoxContainer
var _issue_plate: PlateButton              # arıza adı + süresi (bilgi plakası; tıklanmaz)
var _issue_type: RepairType
var _job_caption: Label
## Kilit / bakiye notları için oyuncu durumu (HUD set_player_state ile verir).
var _player_level: int = 1
var _player_coins: int = 0
var _normal_label: Label
var _ready_box: HBoxContainer
var _repairing_box: VBoxContainer
var _lane: XpLane
var _time_label: Label
var _done_box: VBoxContainer
var _done_value: Label
# Sağ: aksiyon
var _action_box: VBoxContainer
var _button: PlateButton
var _reward_label: Label
var _pop_tween: Tween


## Küçük çizili ikon (anahtar / onay işareti) — metin fontuna bağımlı emoji yok.
class InkIcon extends Control:
	var kind: HudIcon.Kind = HudIcon.Kind.NONE
	var check: bool = false
	func _init(icon_kind: HudIcon.Kind, is_check: bool = false) -> void:
		kind = icon_kind
		check = is_check
		custom_minimum_size = Vector2(16.0, 16.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c: Vector2 = size * 0.5
		if check:
			var pts: PackedVector2Array = PackedVector2Array([c + Vector2(-5.0, 0.0), c + Vector2(-1.5, 3.5), c + Vector2(5.0, -4.0)])
			draw_polyline(pts, HudPalette.INK, 2.2, true)
		else:
			HudIcon.draw_icon(self, kind, c, 13.0, HudPalette.INK, Color(0.0, 0.0, 0.0, 0.0))


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", 14)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alignment = BoxContainer.ALIGNMENT_BEGIN

	# --- Sol: iş seçim plakaları + seçili iş satırı
	_damaged_box = VBoxContainer.new()
	_damaged_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damaged_box.add_theme_constant_override(&"separation", 3)
	_issue_row = HBoxContainer.new()
	_issue_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_issue_row.add_theme_constant_override(&"separation", 6)
	_issue_row.add_child(_make_label(Loc.t("ARIZA"), &"HudInkCaption"))
	_issue_plate = PlateButton.new()
	_issue_plate.theme_type_variation = &"HudPlateSmall"
	_issue_plate.kind = HudIcon.Kind.WRENCH
	_issue_plate.icon_size = 13.0
	_issue_plate.bolts = false
	_issue_plate.disabled = true           # bilgi plakası: arıza müşteriden gelir, seçilmez
	_issue_plate.focus_mode = Control.FOCUS_NONE
	_issue_plate.custom_minimum_size = Vector2(JOB_PLATE_WIDTH, 0.0)
	_issue_row.add_child(_issue_plate)
	_damaged_box.add_child(_issue_row)
	_job_caption = _make_label("", &"HudInkCaption")
	_damaged_box.add_child(_job_caption)
	_normal_label = _make_label(Loc.t("Arıza yok"), &"HudInkValue")
	_normal_label.visible = false
	_damaged_box.add_child(_normal_label)
	add_child(_damaged_box)

	# --- Sol: TAMİR HAZIR (ödül toplanmayı bekliyor)
	_ready_box = HBoxContainer.new()
	_ready_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ready_box.add_theme_constant_override(&"separation", 4)
	_ready_box.add_child(InkIcon.new(HudIcon.Kind.NONE, true))
	_ready_box.add_child(_make_label(Loc.t("TAMİR HAZIR"), &"HudInkValue"))
	_ready_box.visible = false
	add_child(_ready_box)

	# --- Sol: TAMİR EDİLİYOR + şerit + süre
	_repairing_box = VBoxContainer.new()
	_repairing_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_repairing_box.add_theme_constant_override(&"separation", 3)
	var head: HBoxContainer = HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override(&"separation", 4)
	head.add_child(InkIcon.new(HudIcon.Kind.WRENCH))
	head.add_child(_make_label(Loc.t("TAMİR EDİLİYOR"), &"HudInkValue"))
	_repairing_box.add_child(head)
	var lane_row: HBoxContainer = HBoxContainer.new()
	lane_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lane_row.add_theme_constant_override(&"separation", 8)
	_lane = XpLane.new()
	_lane.segments = 10
	_lane.custom_minimum_size = Vector2(120.0, 10.0)
	_lane.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lane_row.add_child(_lane)
	_time_label = _make_label("8.0 sn", &"HudInkCaption")
	_time_label.custom_minimum_size = Vector2(40.0, 0.0)
	lane_row.add_child(_time_label)
	_repairing_box.add_child(lane_row)
	_repairing_box.visible = false
	add_child(_repairing_box)

	# --- Sol: TAMİR TAMAMLANDI + ödül özeti
	_done_box = VBoxContainer.new()
	_done_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_done_box.add_theme_constant_override(&"separation", 3)
	var done_head: HBoxContainer = HBoxContainer.new()
	done_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	done_head.add_theme_constant_override(&"separation", 4)
	done_head.add_child(InkIcon.new(HudIcon.Kind.NONE, true))
	done_head.add_child(_make_label(Loc.t("TAMİR TAMAMLANDI"), &"HudInkValue"))
	_done_box.add_child(done_head)
	_done_value = _make_label(Loc.t("+750 ₺   +35 XP"), &"HudInkValue")
	_done_value.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
	_done_box.add_child(_done_value)
	_done_box.visible = false
	add_child(_done_box)

	# --- Sağ: TAMİR plakası + ödül
	_action_box = VBoxContainer.new()
	_action_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_box.add_theme_constant_override(&"separation", 3)
	_action_box.size_flags_horizontal = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND
	_button = PlateButton.new()
	_button.text = Loc.t("TAMİRE AL")
	_button.kind = HudIcon.Kind.WRENCH
	_button.theme_type_variation = &"HudPlate"
	_button.custom_minimum_size = Vector2(BUTTON_WIDTH, 0.0)
	_button.focus_mode = Control.FOCUS_NONE
	_button.pressed.connect(_on_button_pressed)
	_action_box.add_child(_button)
	_reward_label = _make_label(Loc.t("Ödül: 750 ₺"), &"HudInkCaption")
	_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_box.add_child(_reward_label)
	add_child(_action_box)


# --- Dış API -----------------------------------------------------------------

## Sağdaki eylem plakası (TAMİRE AL / PARA TOPLA): eğitim spot ışığı bunu gösterir.
func action_button() -> PlateButton:
	return _button


## Aktif/tamamlanmış iş bilgisi (ilerleme ve TAMAMLANDI metinleri bu işe göre).
## Ödül / XP satırı. SÜREN bir iş için ödül RepairState'te İŞ BAŞLARKEN sabitlenmiştir (garaj o
## sırada büyüse bile kasaya giren değişmez), bu yüzden çağıran gerçek tutarı verebilir; verilmezse
## güncel çarpanlarla (garaj seviyesi + ustalık) hesaplanır.
func set_info(type: RepairType, fixed_reward: int = -1) -> void:
	if type == null:
		return
	_reward = fixed_reward if fixed_reward >= 0 else effective_reward(type)
	_xp = effective_xp(type)
	_cost = type.cost
	_reward_label.text = Loc.t("Ödül: %s ₺") % Hud.format_thousands(_reward)
	_done_value.text = Loc.t("+%s ₺   +%d XP") % [Hud.format_thousands(_reward), _xp]


## Plakada yazan ile kasaya giren aynı olsun: ödül garaj seviyesinin müşteri çarpanıyla
## (RepairManager.reward_multiplier) VE iş ustalığının kalıcı bonusuyla, XP ustalığın XP çarpanıyla büyür.
func effective_reward(type: RepairType) -> int:
	var repairs: RepairManager = get_tree().get_first_node_in_group("repair_manager") as RepairManager
	var mastery: JobMastery = get_tree().get_first_node_in_group("job_mastery") as JobMastery
	return int(round(float(type.reward)
			* (repairs.reward_multiplier() if repairs else 1.0)
			* (mastery.reward_multiplier(type.id) if mastery else 1.0)))


## İşin GERÇEK süresi (tamir hızı geliştirmesi uygulanmış).
func effective_duration(type: RepairType) -> float:
	var upgrades: GarageUpgradeManager = get_tree().get_first_node_in_group("garage_upgrades") as GarageUpgradeManager
	return type.duration * (upgrades.repair_speed_multiplier() if upgrades else 1.0)


## ALAN ZAMANI BAŞINA kazanç (₺/dk). Oyuncunun kısa/uzun iş kararını verebilmesi için tek anlamlı
## ölçü budur: uzun işler saniye başına daha az getirir ama boştaki alanı doldurur (QA §7).
func rate_per_minute(type: RepairType) -> int:
	return int(round(float(effective_reward(type)) * 60.0 / maxf(effective_duration(type), 0.001)))


func effective_xp(type: RepairType) -> int:
	var mastery: JobMastery = get_tree().get_first_node_in_group("job_mastery") as JobMastery
	return int(round(float(type.xp) * (mastery.xp_multiplier(type.id) if mastery else 1.0)))


## Müşterinin arızasını gösterir (plakada kısa ad + süre, satırda tam ad / süre / ödül / XP).
func set_issue(type: RepairType) -> void:
	_issue_type = type
	if type == null:
		_issue_plate.text = "—"
		_job_caption.text = ""
		return
	_issue_plate.text = Loc.t("%s\n%d sn") % [type.short_title(), int(type.duration)]
	_issue_plate.kind = _icon_of(type)
	set_info(type)


func get_issue_type() -> RepairType:
	return _issue_type


## Kilit ve bakiye notları için oyuncu durumu (seviye / coin).
func set_player_state(level: int, coins: int) -> void:
	_player_level = level
	_player_coins = coins


## RepairType.icon adını HudIcon.Kind'a çevirir (bilinmeyen ad → anahtar).
static func _icon_of(type: RepairType) -> HudIcon.Kind:
	match type.icon:
		&"CAR": return HudIcon.Kind.CAR
		&"ROTATE": return HudIcon.Kind.ROTATE
		&"COIN": return HudIcon.Kind.COIN
		_: return HudIcon.Kind.WRENCH


## Yol kenarında bekleyen müşteri; busy = CarSpot başka araçla dolu (buton kapalı, müşteri beklemeye devam).
func show_damaged(busy: bool) -> void:
	_set_mode(Mode.BUSY if busy else Mode.DAMAGED)
	_issue_row.visible = true
	_job_caption.visible = true
	_normal_label.visible = false
	_button.text = Loc.t("TAMİRE AL")
	_button.kind = HudIcon.Kind.WRENCH
	_apply_selection_state()


## Sayaç bitti, ödül toplanmayı bekliyor: PARA TOPLA plakası.
func show_ready() -> void:
	if _mode == Mode.READY:
		return
	_set_mode(Mode.READY)
	_button.disabled = false
	_button.text = Loc.t("PARA TOPLA")
	_button.kind = HudIcon.Kind.COIN
	_reward_label.text = Loc.t("+%s ₺  +%d XP") % [Hud.format_thousands(_reward), _xp]
	_pop(_action_box)


## boost_available: ödüllü reklamla kalan süre yarıya indirilebilir → buton "REKLAM İZLE" olur.
func show_repairing(progress: float, remaining: float, boost_available: bool = false) -> void:
	if _mode != Mode.REPAIRING:
		_set_mode(Mode.REPAIRING)
	if boost_available:
		_button.disabled = false
		_button.text = Loc.t("REKLAM İZLE")
		_button.kind = HudIcon.Kind.NONE
		_reward_label.text = Loc.t("Süre yarıya iner")
	else:
		_button.disabled = true
		_button.text = Loc.t("TAMİRE AL")
		_button.kind = HudIcon.Kind.WRENCH
		_reward_label.text = Loc.t("Ödül: %s ₺") % Hud.format_thousands(_reward)
	_lane.ratio = progress
	_time_label.text = "%.1f sn" % remaining


## Tamamlanmış araç; celebrate = az önce bitti (kısa geri bildirim animasyonu).
func show_repaired(celebrate: bool) -> void:
	_set_mode(Mode.REPAIRED)
	if celebrate:
		_pop(_done_box)


## Arızası olmayan araç (müşteri değil ya da süresi dolmuş).
func show_normal() -> void:
	_set_mode(Mode.NORMAL)
	_issue_row.visible = false
	_job_caption.visible = false
	_normal_label.visible = true
	_button.disabled = true
	_button.text = Loc.t("TAMİRE AL")
	_button.kind = HudIcon.Kind.WRENCH
	_reward_label.text = Loc.t("Müşteri değil")


# --- İç -----------------------------------------------------------------------

func _set_mode(mode: Mode) -> void:
	_mode = mode
	_damaged_box.visible = mode == Mode.DAMAGED or mode == Mode.BUSY or mode == Mode.NORMAL
	_ready_box.visible = mode == Mode.READY
	_repairing_box.visible = mode == Mode.REPAIRING
	_done_box.visible = mode == Mode.REPAIRED
	_action_box.visible = mode != Mode.REPAIRED


func _on_button_pressed() -> void:
	if _mode == Mode.READY:
		collect_pressed.emit()
	elif _mode == Mode.REPAIRING:
		_button.disabled = true   # çift dokunuş: reklam bitene kadar pasif
		boost_pressed.emit()
	else:
		repair_pressed.emit(_issue_type)


## Arızaya göre satır metni ve TAMİRE AL butonu (alan dolu / kilit / bakiye).
func _apply_selection_state() -> void:
	var t: RepairType = _issue_type
	if t == null:
		_button.disabled = true
		_job_caption.text = ""
		return
	# BİLGİ SIRASI (sabit): süre → maliyet → ödül (₺/dk ile) → XP → ustalık. Tek satırda toplanır;
	# aynı sayı sağdaki ödül satırında TEKRARLANMAZ (orası yalnızca engel varsa konuşur).
	var parts: PackedStringArray = PackedStringArray()
	parts.append("%d sn" % int(round(effective_duration(t))))
	if t.cost > 0:
		parts.append("-%s ₺" % Hud.format_thousands(t.cost))
	parts.append(Loc.t("+%s ₺ (%s ₺/dk)") % [
		Hud.format_thousands(effective_reward(t)), Hud.format_thousands(rate_per_minute(t))])
	parts.append(Loc.t("+%d XP") % effective_xp(t))
	var line: String = "%s   ·   %s" % [t.title, "  ·  ".join(parts)]
	line += _mastery_text(t)
	var busy: bool = _mode == Mode.BUSY
	var unlocked: bool = t.min_level <= _player_level
	var affordable: bool = t.cost <= _player_coins
	_job_caption.text = line
	_button.disabled = busy or not unlocked or not affordable
	if busy:
		_reward_label.text = Loc.t("TAMİR ALANI DOLU")
	elif not unlocked:
		_reward_label.text = Loc.t("SEVİYE %d'DE AÇILIR") % t.min_level
	elif not affordable:
		_reward_label.text = Loc.t("YETERSİZ BAKİYE")
	else:
		_reward_label.text = ""


func _pop(target: Control) -> void:
	if _pop_tween and _pop_tween.is_valid():
		_pop_tween.kill()
	target.pivot_offset = Vector2(0.0, target.size.y * 0.5)
	target.scale = Vector2(0.85, 0.85)
	_pop_tween = create_tween()
	_pop_tween.tween_property(target, "scale", Vector2.ONE, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)



## "  ·  USTALIK ★★ 62/150" — iş ustalığı görünür olsun; yıldız yoksa yalnızca sayaç.
func _mastery_text(type: RepairType) -> String:
	var mastery: JobMastery = get_tree().get_first_node_in_group("job_mastery") as JobMastery
	if mastery == null:
		return ""
	var stars: int = mastery.stars(type.id)
	var next: int = mastery.next_threshold(type.id)
	var text: String = Loc.t("  ·  USTALIK %s") % ("★".repeat(stars) if stars > 0 else "")
	return text + (Loc.t("USTA") if next == 0 else " %d/%d" % [mastery.count(type.id), next])


func _make_label(text: String, variation: StringName) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label
