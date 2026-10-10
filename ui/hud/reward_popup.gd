class_name RewardPopup
extends Control
## ÖDÜL PENCERESİ — görev ödülü alınınca (ÖDÜLÜ AL / HEPSİNİ AL) ekranın ortasına çıkar ve
## kazanılanın TOPLAMINI büyük yazar: para, gem, XP, kasa. Sayılar sıfırdan sayarak artar, arkada
## dönen ışık hüzmesi var: oyuncu ne kazandığını kaçırmasın. TAMAM'a ya da boş yere dokununca kapanır.
## Kapanınca paralar ve gemler pencereden sol üstteki sayaçlara UÇAR; sayaçlar (Hud.hold_reward ile
## eski değerde bekletilmişti) paralar varınca sayarak artar. Sesler: RewardSfx.
## Kodla kurulur (.tscn yok); sahibi (MissionScreen) onu tam ekran son çocuk olarak ekler.

signal closed

const COUNT_TIME: float = 0.9
const ROW_STAGGER: float = 0.14
## Açılır açılmaz gelen dokunuş (ÖDÜLÜ AL'ın devamı) pencereyi kapatmasın.
const TAP_GUARD: float = 0.45
const AMOUNT_SIZE: int = 40
const TITLE_SIZE: int = 30
## Uçuş: önce pencereden dışarı saçılır, sonra kavisle sayaca gider.
const FLY_SPREAD_TIME: float = 0.2
const FLY_TIME: float = 0.5
const FLY_STAGGER: float = 0.05
const FLY_ICON: float = 30.0

## Sayaçların sahibi (MissionScreen.attach_hud verir). Yoksa uçuş olmaz, pencere yalnızca kapanır.
var hud: Hud

var _column: VBoxContainer
var _burst: _Burst
var _title: Label
var _subtitle: Label
var _rows: VBoxContainer
var _ok_button: PlateButton
var _opened_at: int = 0
var _closing: bool = false
var _sfx: RewardSfx
var _coin_icon: HudIcon
var _gem_icon: HudIcon
## Pencere açıkken HUD sayacında bekletilen, kapanınca uçacak miktar.
var _pending_money: int = 0
var _pending_gems: int = 0


func _ready() -> void:
	name = "RewardPopup"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


## summary: money, gems, xp (int), crates (Array: kasa adları), count (alınan ödül sayısı).
func show_rewards(summary: Dictionary) -> void:
	var count: int = int(summary.get("count", 1))
	_title.text = Loc.t("ÖDÜLLER TOPLANDI!") if count > 1 else Loc.t("ÖDÜL KAZANDIN!")
	_subtitle.text = Loc.t("%d ÖDÜLÜN TOPLAMI") % count if count > 1 else ""
	_subtitle.visible = count > 1
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var rows: Array[Control] = []
	_coin_icon = null
	_gem_icon = null
	if int(summary.get("money", 0)) > 0:
		rows.append(_amount_row(HudIcon.Kind.COIN, int(summary["money"]),
			func(v: int) -> String: return "+%s ₺" % Hud.format_thousands(v), HudPalette.COIN_DARK))
	if int(summary.get("gems", 0)) > 0:
		var gem_format: String = Loc.t("+%d GEM")
		rows.append(_amount_row(HudIcon.Kind.GEM, int(summary["gems"]),
			func(v: int) -> String: return gem_format % v, HudPalette.GEM_DARK))
	if int(summary.get("xp", 0)) > 0:
		var xp_format: String = Loc.t("+%d XP")
		rows.append(_amount_row(HudIcon.Kind.NONE, int(summary["xp"]),
			func(v: int) -> String: return xp_format % v, HudPalette.INK))
	for crate_name: Variant in summary.get("crates", []):
		rows.append(_text_row("+1 %s" % String(crate_name)))
	if rows.is_empty():
		return
	for row: Control in rows:
		_rows.add_child(row)
	var money: int = int(summary.get("money", 0))
	var gems: int = int(summary.get("gems", 0))
	if hud:
		hud.hold_reward(money, gems)   # ödül hesapta; sayaç paralar varana dek eski değeri gösterir
		_pending_money += money
		_pending_gems += gems
	_sfx.fanfare()
	_closing = false
	_opened_at = Time.get_ticks_msec()
	PlateAnim.pop_in(self, _column)
	_burst.start()
	for i: int in rows.size():
		_animate_row(rows[i], float(i) * ROW_STAGGER)


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	_fly_rewards()
	PlateAnim.pop_out(self, _column, func() -> void:
		hide()
		_burst.stop()
		_closing = false
		closed.emit())


func _gui_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if tapped and Time.get_ticks_msec() - _opened_at > int(TAP_GUARD * 1000.0):
		accept_event()
		close()


# --- Kurulum -----------------------------------------------------------------

func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_sfx = RewardSfx.new()
	add_child(_sfx)

	_burst = _Burst.new()
	_burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_burst.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_burst)

	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override(&"separation", 10)
	center.add_child(_column)

	var plate: PlatePanel = PlatePanel.new()
	plate.theme_type_variation = &"HudCarPlate"
	plate.custom_minimum_size = Vector2(340.0, 0.0)
	_column.add_child(plate)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 6)
	plate.add_child(box)
	_title = _label(&"HudSignTitle", "")
	_title.add_theme_font_size_override(&"font_size", TITLE_SIZE)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_subtitle = _label(&"HudInkCaption", "")
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_subtitle)
	_rows = VBoxContainer.new()
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.add_theme_constant_override(&"separation", 4)
	box.add_child(_rows)

	_ok_button = PlateButton.new()
	_ok_button.theme_type_variation = &"HudPlateSmall"
	_ok_button.text = Loc.t("TAMAM")
	_ok_button.highlight = true
	_ok_button.focus_mode = Control.FOCUS_NONE
	_ok_button.custom_minimum_size = Vector2(160.0, 0.0)
	_ok_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_ok_button.pressed.connect(close)
	_column.add_child(_ok_button)


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Büyük satır: ikon + "+12.500 ₺" (sayı animasyonla sıfırdan artar). format: int → gösterilen metin.
func _amount_row(kind: HudIcon.Kind, amount: int, format: Callable, color: Color) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 12)
	if kind != HudIcon.Kind.NONE:
		var icon: HudIcon = HudIcon.new()
		icon.kind = kind
		icon.icon_size = 40.0
		icon.custom_minimum_size = Vector2(44.0, 44.0)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		if kind == HudIcon.Kind.COIN:
			_coin_icon = icon
		elif kind == HudIcon.Kind.GEM:
			_gem_icon = icon
	var value: Label = _label(&"HudSignTitle", format.call(0))
	value.add_theme_font_size_override(&"font_size", AMOUNT_SIZE)
	value.add_theme_color_override(&"font_color", color)
	value.set_meta(&"amount", amount)
	value.set_meta(&"format", format)
	row.add_child(value)
	row.set_meta(&"value_label", value)
	return row


func _text_row(text: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var label: Label = _label(&"HudSignTitle", text)
	label.add_theme_font_size_override(&"font_size", TITLE_SIZE)
	label.add_theme_color_override(&"font_color", HudPalette.PLATE_SELECTED_EDGE)
	row.add_child(label)
	return row


## Satır sırayla yerine "pıt" diye oturur, sonra sayısı sayılarak artar.
func _animate_row(row: Control, delay: float) -> void:
	row.modulate.a = 0.0
	await get_tree().process_frame   # boyut hesaplansın (pivot ortada olsun)
	if not is_instance_valid(row):
		return
	row.pivot_offset = row.size * 0.5
	row.scale = Vector2.ONE * 0.4
	var tween: Tween = row.create_tween()
	tween.tween_interval(delay)
	tween.tween_property(row, "modulate:a", 1.0, 0.1)
	tween.parallel().tween_property(row, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if row.has_meta(&"value_label"):
		var value: Label = row.get_meta(&"value_label")
		var amount: int = int(value.get_meta(&"amount"))
		var format: Callable = value.get_meta(&"format")
		tween.tween_method(func(v: float) -> void:
			var shown: String = format.call(int(round(v)))
			if shown != value.text:
				_sfx.tick(v / float(maxi(amount, 1)))
			value.text = shown, 0.0, float(amount), COUNT_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(row, "scale", Vector2.ONE * 1.12, 0.08)
		tween.tween_property(row, "scale", Vector2.ONE, 0.14)


# --- Sayaca uçuş ---------------------------------------------------------------

func _fly_rewards() -> void:
	var money: int = _pending_money
	var gems: int = _pending_gems
	_pending_money = 0
	_pending_gems = 0
	if hud == null:
		return
	var center: Vector2 = get_global_rect().get_center()
	if money > 0:
		var from: Vector2 = _coin_icon.get_global_rect().get_center() if is_instance_valid(_coin_icon) else center
		_fly(HudIcon.Kind.COIN, from, hud.coin_label, clampi(int(log(float(money)) / log(10.0) * 2.0) + 2, 6, 14),
			func() -> void: hud.land_reward(money, 0), _sfx.coin)
	if gems > 0:
		var from: Vector2 = _gem_icon.get_global_rect().get_center() if is_instance_valid(_gem_icon) else center
		_fly(HudIcon.Kind.GEM, from, hud.gem_label, clampi(gems / 10 + 3, 3, 8),
			func() -> void: hud.land_reward(0, gems), _sfx.gem)


## count ikon `from`dan saçılır, sırayla `label`ın ikonuna kavisle uçar; her biri değince ses + sayaç
## "pıt"; SONUNCUSU değince on_landed (sayaç sayarak artar). İkonlar HUD katmanına eklenir:
## pencere ve görev tabelası kapanırken uçuş sürer.
func _fly(kind: HudIcon.Kind, from: Vector2, label: Label, count: int, on_landed: Callable, sound: Callable) -> void:
	var target_node: Control = hud.counter_target(label)
	for i: int in count:
		var icon: HudIcon = HudIcon.new()
		icon.kind = kind
		icon.icon_size = FLY_ICON
		icon.size = Vector2.ONE * FLY_ICON
		icon.pivot_offset = icon.size * 0.5
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.add_child(icon)
		var half: Vector2 = icon.size * 0.5
		icon.global_position = from - half
		var spread: Vector2 = from + Vector2.from_angle(randf() * TAU) * randf_range(50.0, 110.0)
		var last: bool = i == count - 1
		var index: int = i
		var tween: Tween = icon.create_tween()
		tween.tween_property(icon, "global_position", spread - half, FLY_SPREAD_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_interval(float(i) * FLY_STAGGER)
		tween.tween_method(func(t: float) -> void:
			# hedef her karede okunur: ekran boyutu değişse de sayaca varır
			var to: Vector2 = target_node.get_global_rect().get_center() if is_instance_valid(target_node) else spread
			var control: Vector2 = Vector2(lerpf(spread.x, to.x, 0.25), minf(spread.y, to.y) - 80.0)
			icon.global_position = spread.lerp(control, t).lerp(control.lerp(to, t), t) - half
			icon.scale = Vector2.ONE * lerpf(1.15, 0.6, t), 0.0, 1.0, FLY_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_callback(func() -> void:
			sound.call(index)
			hud.pulse_counter(label)
			if last:
				on_landed.call()
			icon.queue_free())


## Pencerenin arkasında yavaşça dönen sarı ışık hüzmeleri.
class _Burst extends Control:
	const RAYS: int = 14
	const SPEED: float = 0.35

	var _angle: float = 0.0

	func start() -> void:
		set_process(true)

	func stop() -> void:
		set_process(false)

	func _ready() -> void:
		set_process(false)

	func _process(delta: float) -> void:
		_angle = fmod(_angle + delta * SPEED, TAU)
		queue_redraw()

	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var radius: float = size.length() * 0.5
		var step: float = TAU / float(RAYS)
		var ray_color: Color = Color(HudPalette.COIN, 0.16)
		for i: int in RAYS:
			var a: float = _angle + step * float(i)
			draw_colored_polygon(PackedVector2Array([center,
				center + Vector2.from_angle(a) * radius,
				center + Vector2.from_angle(a + step * 0.5) * radius]), ray_color)
		draw_circle(center, minf(size.x, size.y) * 0.3, Color(HudPalette.COIN, 0.12))
