class_name PurchasePlate
extends PlatePanel
## STANDART SATIN ALMA PLAKASI — garaj genişletme, tamir alanı ve araç satın alma AYNI görsel
## hiyerarşiyi kullansın diye tek bileşen:
##
##   BAŞLIK          (GARAJI GENİŞLET / TAMİR ALANI 2 / BMW E46)
##   alt başlık      (SEVİYE 2 / A SINIFI · 2003 · %85)
##   FİYAT           (12.000 ₺  ·  PARA YETERSİZ)
##   etki satırları  (ProgressionEffects'ten; elle yazılmaz)
##
## Buton plakanın DIŞINDADIR: her ekran kendi aksiyon plakasını (GENİŞLET / ALANI AÇ / SATIN AL)
## kendi yerleşimine koyar; ortak olan bilgi hiyerarşisidir.

const PLATE_WIDTH: float = 200.0

var _title: Label
var _subtitle: Label
var _price: Label
var _effects: Label


func _init(width: float = PLATE_WIDTH) -> void:
	theme_type_variation = &"HudCarPlate"
	custom_minimum_size = Vector2(width, 0.0)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 2)
	_title = _label(&"HudPlateTitle")
	_subtitle = _label(&"HudInkCaption")
	_price = _label(&"HudInkValue")
	_effects = _label(&"HudInkCaption")
	_effects.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
	_effects.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_title)
	box.add_child(_subtitle)
	box.add_child(_price)
	box.add_child(_effects)
	add_child(box)


## Tek giriş noktası: boş bırakılan satırlar gizlenir.
func set_content(title: String, subtitle: String, price: String, effects: PackedStringArray) -> void:
	_title.text = title
	_subtitle.text = subtitle
	_price.text = price
	_effects.text = "\n".join(effects)
	_subtitle.visible = subtitle != ""
	_price.visible = price != ""
	_effects.visible = not effects.is_empty()


## Ortalanmış yerleşim (dünyadaki plakalar) ya da sola dayalı (showroom bilgi plakası).
func set_centered(centered: bool) -> void:
	var align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	for label: Label in [_title, _subtitle, _price, _effects]:
		label.horizontal_alignment = align


func _label(variation: StringName) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
