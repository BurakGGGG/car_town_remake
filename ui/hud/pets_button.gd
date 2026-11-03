class_name PetsButton
extends PlateButton
## HUD'un HAYVANLAR tabelası (2026-11-03, kullanıcı kararı taslak "B · Sağ üstte pati tabelası"): sağ üst ikinci sırada,
## GÜNLÜK GİRİŞ takviminin SOLUNDA; kamera / takvim / MARKET dilinde yuvarlak ve yazısız, içinde turuncu pati çizimi
## (ui/hud/art/nav/pets.svg). Yalnız ilk kedi geldikten sonra görünür (sv5). HAYVANLAR ekranı hiç açılmadıysa sağ üstte
## kırmızı "!" rozeti. Kodla kurulur (Hud._setup_gem_store); basınca `pressed` → HAYVANLAR ekranı.

## Çizimin tabela çapına oranı (MARKET'teki gibi kenara yakın).
const ART_RATIO: float = 0.86

## Sağ üstte "!" rozeti.
var show_badge: bool = false:
	set(value):
		show_badge = value
		if _mark:
			_mark.visible = value

var _art: TextureRect
var _mark: _Mark


func _init() -> void:
	shape = Shape.ROUND
	kind = HudIcon.Kind.NONE
	bolts = false
	lift_when_pressed = 0.0
	theme_type_variation = &"HudSign"
	focus_mode = Control.FOCUS_NONE
	clip_contents = false
	text = ""
	_art = TextureRect.new()
	_art.texture = load("res://ui/hud/art/nav/pets.svg") as Texture2D
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_art)
	_mark = _Mark.new()
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mark.visible = false
	add_child(_mark)


func _ready() -> void:
	super._ready()
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	_art.size = size * ART_RATIO
	_art.position = (size - _art.size) * 0.5 + Vector2(0.0, -1.0)
	var r: float = size.x * 0.17
	_mark.size = Vector2(r, r) * 2.0
	_mark.position = Vector2(size.x - r * 1.55, -r * 0.45)


## Kırmızı daire + beyaz "!" (MARKET rozetinin dili).
class _Mark:
	extends Control

	func _draw() -> void:
		var r: float = size.x * 0.5
		var c: Vector2 = size * 0.5
		draw_circle(c, r, Color.WHITE)
		draw_circle(c, r - 2.0, Color("E0453A"))
		var bar: float = maxf(r * 0.24, 2.0)
		draw_rect(Rect2(c.x - bar * 0.5, c.y - r * 0.55, bar, r * 0.72), Color.WHITE)
		draw_circle(Vector2(c.x, c.y + r * 0.42), bar * 0.6, Color.WHITE)
