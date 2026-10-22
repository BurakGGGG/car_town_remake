class_name PurchasePlate
extends PlatePanel
## STANDART SATIN ALMA PLAKASI — garaj genişletme, tamir alanı ve araç satın alma AYNI görsel
## hiyerarşiyi kullansın diye tek bileşen:
##
##   BAŞLIK          (GARAJI GENİŞLET / TAMİR ALANI 2 / BAVARIA CLUB 46)
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


## Plaka `max_total` yüksekliği aşıyorsa etki satırlarının yazısı küçülür (en çok `min_size`). Satır sayısı yazı
## genişliğinden hesaplanır: yerleşim beklenmez. Showroom: uzun oran listesi (SÜPER KASA, Almanca) kısa ekranda
## orta satırı uzatıp GERİ'yi ekran dışına itiyordu (853×480).
func fit_height(max_total: float, min_size: int = 8) -> void:
	_effects.remove_theme_font_size_override(&"font_size")
	if not _effects.visible or not is_inside_tree():
		return
	var box: StyleBox = get_theme_stylebox(&"panel")
	var margins: Vector2 = box.get_minimum_size() if box else Vector2.ZERO
	var fixed: float = margins.y
	for label: Label in [_title, _subtitle, _price]:
		if label.visible:
			fixed += label.get_combined_minimum_size().y + 2.0
	var width: float = maxf(custom_minimum_size.x - margins.x, 1.0)
	var font: Font = _effects.get_theme_font(&"font")
	var base: int = _effects.get_theme_font_size(&"font_size")
	var size: int = base
	while size > min_size and fixed + _effects_height(font, size, width) > max_total:
		size -= 1
	if size != base:
		_effects.add_theme_font_size_override(&"font_size", size)


func _effects_height(font: Font, font_size: int, width: float) -> float:
	var lines: int = 0
	for line: String in _effects.text.split("\n"):
		lines += maxi(1, ceili(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x / width))
	return float(lines) * (font.get_height(font_size) + float(_effects.get_theme_constant(&"line_spacing")))


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
