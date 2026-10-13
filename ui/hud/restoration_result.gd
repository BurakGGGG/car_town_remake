class_name RestorationResult
extends VBoxContainer
## RESTORASYON SONUÇ PLAKASI — teslim töreninin sonunda (RestorationFinale `revealed`), kasa sonuç
## plakasıyla aynı yerde (HUD alt sütunu) ve aynı bileşenle (PurchasePlate):
##   ARACIN ADI · yıl · sınıf · HURDADAN KLASİĞE! · koleksiyon sayısı · (varsa) açılan yeni sınıf
## Plakaya "TAMAMLANDI" mührü vurulur (hurdalıktaki "İŞ ALINDI"nın eşi: işe başlarken alınan söz tutuldu).
## GARAJA AL → done_pressed: araç alandan çıkıp garaja gider. Mantık yok; HUD RestorationBays'e iletir.

signal done_pressed(vehicle_id: StringName)

const WIDTH: float = 260.0

var vehicle_id: StringName = &""
var _plate: PurchasePlate
var _action: PlateButton
var _glow: Tween
var _stamp: Control


func _ready() -> void:
	name = "RestorationResult"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_theme_constant_override(&"separation", 6)
	visible = false
	_plate = PurchasePlate.new(WIDTH)
	_plate.set_centered(true)
	add_child(_plate)
	_action = PlateButton.new()
	_action.name = "RestorationDone"
	_action.theme_type_variation = &"HudPlateSmall"
	_action.text = Loc.t("GARAJA AL")
	_action.bolts = false
	_action.focus_mode = Control.FOCUS_NONE
	_action.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_action.pressed.connect(confirm)
	add_child(_action)


## `new_tiers`: bu bitişle açılan restorasyon sınıfları (JunkyardManager.tier_unlocked).
func show_result(id: StringName, new_tiers: Array[StringName] = []) -> void:
	vehicle_id = id
	var entry: Dictionary = CarCatalog.get_entry(id)
	var plan: Dictionary = RestorationCatalog.get_entry(id)
	var lines: PackedStringArray = PackedStringArray()
	var jy: JunkyardManager = get_tree().get_first_node_in_group("junkyard") as JunkyardManager if is_inside_tree() else null
	if jy:
		lines.append(Loc.t("KOLEKSİYON  %d / %d") % [jy.completed_ids().size(), RestorationCatalog.cars().size()])
	for tier_id: StringName in new_tiers:
		lines.append(Loc.t("YENİ SINIF AÇILDI: %s") % Loc.t(String(RestorationCatalog.tier(tier_id).get("name", tier_id))))
	lines.append(Loc.t("Garajına eklendi, artık senin!"))
	_plate.set_content(String(entry.get("display_name", plan.get("name", id))).to_upper(),
		Loc.t("%d  ·  %s SINIFI") % [int(plan.get("year", 0)), String(entry.get("class", plan.get("class", "?")))],
		Loc.t("HURDADAN KLASİĞE!"), lines)
	_action.disabled = false
	show()
	_pop_in()
	_start_glow()
	_stamp_plate()


func hide_panel() -> void:
	_stop_glow()
	if is_instance_valid(_stamp):
		_stamp.queue_free()
	_stamp = null
	hide()


## GARAJA AL (düğme ya da başka bir ekran açıldı).
func confirm() -> void:
	if not visible:
		return
	_action.disabled = true
	var id: StringName = vehicle_id
	hide_panel()
	done_pressed.emit(id)


## Plaka aşağıdan büyüyerek gelir.
func _pop_in() -> void:
	pivot_offset = size * 0.5
	scale = Vector2(0.6, 0.6)
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## "TAMAMLANDI" mührü plakanın sağ üstüne iner (büyükten küçüğe, eğik), plaka sarsılır.
func _stamp_plate() -> void:
	# Plaka yeni göründü: sütun yerleşimi oturana kadar beklenir (yoksa konum eski yerinden okunuyor,
	# mühür ekranın altına düşüyordu — QA ekran görüntüsü)
	for k: int in 2:
		await get_tree().process_frame
	if not visible or is_instance_valid(_stamp):
		return
	var stamp: PanelContainer = PanelContainer.new()
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.top_level = true   # kapsayıcı yerleşimine girmez; plakanın üstünde serbest durur
	var frame: StyleBoxFlat = StyleBoxFlat.new()
	frame.bg_color = Color(HudPalette.PLATE, 0.0)
	frame.border_color = HudPalette.COIN_DARK
	frame.set_border_width_all(4)
	frame.set_corner_radius_all(7)
	frame.set_content_margin_all(6.0)
	frame.content_margin_left = 14.0
	frame.content_margin_right = 14.0
	stamp.add_theme_stylebox_override(&"panel", frame)
	var label: Label = Label.new()
	label.theme_type_variation = &"HudInkValue"
	label.text = Loc.t("TAMAMLANDI")
	label.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.add_child(label)
	_plate.add_child(stamp)
	_stamp = stamp
	stamp.reset_size()
	var rect: Rect2 = _plate.get_global_rect()
	stamp.global_position = Vector2(rect.end.x - stamp.size.x * 0.62, rect.position.y - stamp.size.y * 0.8)
	stamp.pivot_offset = stamp.size * 0.5
	stamp.rotation = deg_to_rad(-10.0)
	stamp.scale = Vector2(2.4, 2.4)
	stamp.modulate.a = 0.0
	var tween: Tween = stamp.create_tween()
	tween.tween_interval(0.25)
	tween.tween_property(stamp, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(stamp, "modulate:a", 1.0, 0.1)
	tween.tween_callback(_thud)


## Mührün darbesi: plaka bir an aşağı basılır.
func _thud() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.04, 0.95), 0.05)
	tween.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Altın çerçeve nabız gibi atar (kasa sonucundaki efsanevi parıltının eşi).
func _start_glow() -> void:
	_stop_glow()
	_glow = create_tween().set_loops()
	_glow.tween_property(_plate, "modulate", Color.WHITE.lerp(HudPalette.COIN, 0.35), 0.5).set_trans(Tween.TRANS_SINE)
	_glow.tween_property(_plate, "modulate", Color.WHITE, 0.5).set_trans(Tween.TRANS_SINE)


func _stop_glow() -> void:
	if _glow and _glow.is_valid():
		_glow.kill()
	_glow = null
	if _plate:
		_plate.modulate = Color.WHITE
