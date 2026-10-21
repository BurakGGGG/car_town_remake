class_name ParkingBadge
extends PlateButton
## OTOPARK SAYACI rozeti (sağ üst sütun, ARKADAŞLAR'ın altında): solda mavi "P" otopark tabelası, yanında OTOPARK ve
## altında küçük kırmızı günlük ücret; araç sayısı sağ üst köşede kırmızı balon (PlateButton.badge). Eskiden tek
## satırlık kırmızı yazıydı ("OTOPARK 3 · −5.050 ₺/GÜN") ve hata mesajı gibi duruyordu (kullanıcı 2026-10-20).
## Hud._build_lot_counter kurar; dokununca DEPOLARIM otopark basamağıyla açılır.

const SIGN: float = 26.0
const SIGN_BLUE: Color = Color("2463C7")
## Tabela ile yazı arası, plaka kenar payı (cıvata x = 7: yazı ondan uzak).
const GAP: float = 8.0
const PAD_X: float = 15.0
const TITLE_SIZE: int = 14
const FEE_SIZE: int = 12

var _title: String = ""
var _fee: String = ""


func _init() -> void:
	theme_type_variation = &"HudPlateSmall"
	text = ""
	focus_mode = Control.FOCUS_NONE
	size_flags_horizontal = Control.SIZE_SHRINK_END


func _ready() -> void:
	super()
	_title = Loc.t("OTOPARK")


## Araç sayısı (köşe balonu) ve günlük toplam ücret.
func set_state(cars: int, daily_fee: int) -> void:
	badge = cars
	_fee = Loc.t("−%s ₺ / GÜN") % Hud.format_thousands(daily_fee)
	_fit()
	queue_redraw()


func _fit() -> void:
	var font: Font = get_theme_font(&"font")
	if font == null:
		return
	var text_w: float = maxf(font.get_string_size(_title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TITLE_SIZE).x,
		font.get_string_size(_fee, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FEE_SIZE).x)
	custom_minimum_size = Vector2(ceilf(PAD_X * 2.0 + SIGN + GAP + text_w), MIN_PLATE_HEIGHT)


func _draw() -> void:
	super()   # cıvatalar + sayı balonu
	var mode: DrawMode = get_draw_mode()
	var lift: float = lift_when_pressed if mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED else 0.0
	var cy: float = size.y * 0.5 - lift
	var font: Font = get_theme_font(&"font")
	# Mavi otopark tabelası: beyaz çerçeve, ortada kalın P
	var sign_rect: Rect2 = Rect2(Vector2(PAD_X, cy - SIGN * 0.5), Vector2(SIGN, SIGN))
	var plate: StyleBoxFlat = StyleBoxFlat.new()
	plate.bg_color = SIGN_BLUE
	plate.border_color = Color.WHITE
	plate.set_border_width_all(2)
	plate.set_corner_radius_all(5)
	plate.anti_aliasing = true
	plate.shadow_color = Color(0.0, 0.0, 0.0, 0.25)
	plate.shadow_size = 1
	plate.shadow_offset = Vector2(0.0, 1.0)
	draw_style_box(plate, sign_rect)
	if font == null:
		return
	var p_size: int = 19
	var p_w: float = font.get_string_size("P", HORIZONTAL_ALIGNMENT_LEFT, -1.0, p_size).x
	draw_string(font, Vector2(sign_rect.get_center().x - p_w * 0.5, cy + p_size * 0.36), "P",
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, p_size, Color.WHITE)
	# OTOPARK (plaka mürekkebi) ve altında ücret (kırmızı, küçük)
	var x: float = PAD_X + SIGN + GAP
	draw_string(font, Vector2(x, cy - 2.0), _title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TITLE_SIZE, _ink_for(mode))
	draw_string(font, Vector2(x, cy + 13.0), _fee, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FEE_SIZE, HudPalette.DANGER)
