class_name CratePanel
extends VBoxContainer
## Dünyadaki teslimat kasasının plakası (HUD'un alt sütununda, tamir alanı plakasıyla aynı yerde).
## İki kip: SORU — kasaya dokunulunca "ŞEHİR KASASI · içinde ne var? · AÇ / VAZGEÇ";
## SONUÇ — açılış sahnesinden sonra aracın adı, nadirliği ve ne olduğu (yeni / kopya ★ / geri geldi).
## Mantık yok: AÇ ve TAMAM sinyalleri HUD üzerinden CrateDelivery'ye gider. Kasanın içindeki araç
## soru kipinde ASLA gösterilmez.

signal open_pressed(uid: int)
signal dismissed(uid: int)
signal done_pressed(uid: int)

const WIDTH: float = 250.0

var _uid: int = 0
var _plate: PurchasePlate
var _action: PlateButton
var _cancel: PlateButton
var _mode: StringName = &""
var _glow: Tween


func _ready() -> void:
	name = "CratePanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_theme_constant_override(&"separation", 6)
	visible = false
	_plate = PurchasePlate.new(WIDTH)
	_plate.set_centered(true)
	add_child(_plate)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", 8)
	_action = PlateButton.new()
	_action.name = "CrateAction"
	_action.theme_type_variation = &"HudPlateSmall"
	_action.bolts = false
	_action.focus_mode = Control.FOCUS_NONE
	_action.pressed.connect(_on_action)
	_cancel = PlateButton.new()
	_cancel.name = "CrateCancel"
	_cancel.theme_type_variation = &"HudPlateSmall"
	_cancel.text = "VAZGEÇ"
	_cancel.bolts = false
	_cancel.focus_mode = Control.FOCUS_NONE
	_cancel.pressed.connect(func() -> void:
		hide_panel()
		dismissed.emit(_uid))
	buttons.add_child(_action)
	buttons.add_child(_cancel)
	add_child(buttons)


func uid() -> int:
	return _uid


func mode() -> StringName:
	return _mode if visible else &""


## SORU kipi: hangi kasa, açılsın mı? (içerik gizli)
func show_prompt(uid_value: int, crate_id: StringName) -> void:
	_uid = uid_value
	_mode = &"prompt"
	_stop_glow()
	var entry: Dictionary = CrateCatalog.get_entry(crate_id)
	var odds: Dictionary = CrateCatalog.rarity_odds(crate_id)
	var lines: PackedStringArray = PackedStringArray()
	for rarity: StringName in CrateCatalog.RARITY_ORDER:
		if odds.has(rarity):
			lines.append("%s  %%%s" % [CrateCatalog.rarity_label(rarity), ("%.1f" % (float(odds[rarity]) * 100.0)).replace(".", ",")])
	_plate.set_content(String(entry.get("display_name", "KASA")), "İÇİNDE BİR ARAÇ VAR", "???", lines)
	_action.text = "AÇ"
	_action.disabled = false
	_cancel.visible = true
	show()


## SONUÇ kipi: araç dünyada göründükten sonra.
func show_result(uid_value: int, result: Dictionary) -> void:
	_uid = uid_value
	_mode = &"result"
	var vehicle: StringName = result["vehicle"]
	var entry: Dictionary = CarCatalog.get_entry(vehicle)
	var rarity: StringName = result["rarity"]
	var lines: PackedStringArray = PackedStringArray()
	var headline: String
	if bool(result["duplicate"]):
		var stars: int = int(result["stars"])
		headline = "KOPYA  %s" % ("★".repeat(stars) + "☆".repeat(5 - stars))
		lines.append("ARAÇ YILDIZI İLERLEDİ")
	elif bool(result["reacquired"]):
		headline = "GARAJINA GERİ DÖNDÜ"
	else:
		headline = "YENİ!  KOLEKSİYONA EKLENDİ"
	if int(result["gems"]) > 0:
		lines.append("+%d GEM" % int(result["gems"]))
	_plate.set_content(String(entry.get("display_name", vehicle)).to_upper(),
		"%s  ·  %s SINIFI" % [CrateCatalog.rarity_label(rarity), String(entry.get("class", "?"))],
		headline, lines)
	_action.text = "TAMAM"
	_action.disabled = false
	_cancel.visible = false
	show()
	_start_glow(CrateCatalog.rarity_color(rarity), rarity == &"legendary" or rarity == &"epic")


## "Sonra" düğmesiyle aynı davranış (Android GERİ için).
func dismiss() -> void:
	if _mode != &"prompt":
		return
	hide_panel()
	dismissed.emit(_uid)


func hide_panel() -> void:
	_stop_glow()
	_mode = &""
	hide()


func _on_action() -> void:
	if _mode == &"prompt":
		_action.disabled = true
		hide_panel()
		open_pressed.emit(_uid)
	elif _mode == &"result":
		hide_panel()
		done_pressed.emit(_uid)


## Nadirlik rengi plakanın çerçevesinde nabız gibi atar (Epic / Legendary). Yeni asset yok.
func _start_glow(color: Color, strong: bool) -> void:
	_stop_glow()
	modulate = Color.WHITE
	if not strong:
		return
	_glow = create_tween().set_loops()
	_glow.tween_property(self, "modulate", Color.WHITE.lerp(color, 0.35), 0.5).set_trans(Tween.TRANS_SINE)
	_glow.tween_property(self, "modulate", Color.WHITE, 0.5).set_trans(Tween.TRANS_SINE)


func _stop_glow() -> void:
	if _glow and _glow.is_valid():
		_glow.kill()
	_glow = null
	modulate = Color.WHITE
