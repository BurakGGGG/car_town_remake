class_name GemShopButton
extends PlateButton
## HUD'un MARKET düğmesi (eski adı GEM AL) — sağ üstte, kamera / ayar tabelalarının dilinde YUVARLAK ve YAZISIZ tabela
## (2026-10-23, kullanıcı: "market butonunu yuvarlak yap, market yazmasın"; önceki gün krem plakaydı): içinde 2B elmas +
## altın çizimi (biraz taşar), birkaç saniyede bir "nefes alma" büyümesi. Başlangıç paketi alınmadıysa sağ üstte kırmızı
## "!" rozeti. Yanında GÜNLÜK GİRİŞ tabelası durur. Kodla kurulur (Hud._setup_gem_store); basınca `pressed` → mağaza.

const PULSE_EVERY: float = 4.0
## Çizimin tabela çapına oranı (1'den büyük: kenardan biraz taşar, yükselen ikon dili).
const ART_RATIO: float = 1.04

## Sağ üstte rozet gösterilsin mi (tek seferlik paket hâlâ alınabilir).
var show_badge: bool = false:
	set(value):
		show_badge = value
		_overlay.animate()

var _art: TextureRect
var _overlay: _Overlay
var _t: float = 0.0
var _next_pulse: float = 1.5


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
	_art.texture = load("res://ui/hud/art/nav/market.svg") as Texture2D
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_art)
	_overlay = _Overlay.new()
	_overlay.owner_button = self
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)


func _ready() -> void:
	super._ready()
	resized.connect(_layout)
	_layout()


## Çizim tabelanın ortasında, çapın ART_RATIO katı; nabız tabelanın ortasından büyür.
func _layout() -> void:
	pivot_offset = size * 0.5
	_art.size = size * ART_RATIO
	_art.position = (size - _art.size) * 0.5 + Vector2(0.0, -1.0)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	_overlay.animate()
	if _t >= _next_pulse:
		_next_pulse = _t + PULSE_EVERY
		var tween: Tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.08, 1.08), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Üst katman: sağ üstteki "!" rozeti. Çizimin ÜSTÜNDE; rozet nabzı alt öğenin ölçeğiyle oynar (her karede yeni çizim yok).
class _Overlay:
	extends Control
	var owner_button: GemShopButton
	var _disc: _Shape
	var _mark: _Shape

	func _ready() -> void:
		_disc = _Shape.new(_Shape.DISC)
		_mark = _Shape.new(_Shape.MARK)
		_mark.font = get_theme_default_font()
		for shape: _Shape in [_disc, _mark]:
			add_child(shape)
		resized.connect(_layout)
		_layout()

	func _layout() -> void:
		_disc.position = Vector2(size.x - 3.0, 3.0)
		_mark.position = _disc.position
		animate()

	## Rozet dairesi nabız atar, "!" sabit boyda kalır.
	func animate() -> void:
		if _disc == null:
			return
		var t: float = owner_button._t
		var badge: bool = owner_button.show_badge
		_disc.visible = badge
		_mark.visible = badge
		if badge:
			var pulse: float = 1.0 + 0.12 * maxf(sin(t * 5.0), 0.0)
			_disc.scale = Vector2(pulse, pulse)


## Üst katmanın bir kez çizilen parçası.
class _Shape:
	extends Node2D
	const DISC: int = 1
	const MARK: int = 2
	var what: int
	var font: Font

	func _init(what_value: int) -> void:
		what = what_value

	func _draw() -> void:
		match what:
			DISC:
				draw_circle(Vector2.ZERO, 10.0, Color("A42E35"), true, -1.0, true)
				draw_circle(Vector2.ZERO, 8.5, Color("E2474F"), true, -1.0, true)
			MARK:
				if font == null:
					return
				var w2: float = font.get_string_size("!", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14).x
				draw_string(font, Vector2(-w2 * 0.5, 5.0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color.WHITE)
