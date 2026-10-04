@tool
class_name PlateButton
extends Button
## Plaka (PLATE) veya yuvarlak tabela (ROUND) butonu.
## Zemin/kalınlık/gölge temadaki StyleBox'tan gelir; ikon, cıvatalar ve
## basılıyken "kalkma" kayması burada çizilir. Yazı Button'ın kendi text'i.

enum Shape { PLATE, ROUND }

## --- MOBİL TABANLARI ----------------------------------------------------------------------------
## Ölçüler tuval birimindedir (taban 1152×648; dikey 648 birim her cihazda ekran yüksekliği).
## Oyuncunun telefonunda (Samsung A24, 6,5″, ~396 dpi) 1 birim ≈ 0,67 dp ≈ 0,107 mm — yani
## tuval dp'den YOĞUN: eski 25 birimlik plakalar 2,7 mm, Android'in 48 dp önerisi 71 birim.
##
## Tema görünümün kaynağıdır; bunlar yalnızca TABAN: eşiğin altındakini yükseltir, üstündekine
## dokunmaz. YALNIZCA OYUN SIRASINDA uygulanır — PlateButton @tool olduğu için editörde atanan
## her özellik sahne kaydedilince .tscn'e yazılır (sahne dosyaları koddan değişmemeli).
## Süs olarak kullanılan plakalar (mouse_filter = IGNORE) muaftır.

## Yazı plakasının (PLATE) en küçük görünür yüksekliği: 25 → 44 birim (2,7 → 4,7 mm).
const MIN_PLATE_HEIGHT: float = 44.0
## Yuvarlak tabelanın (ROUND) en küçük çapı: 32 → 48 birim. İkon aynı oranda büyür.
const MIN_SIGN_SIZE: float = 48.0
## Plaka yazısının en küçük puntosu. Temada 10–11 (telefonda ~7 sp).
const MIN_FONT_SIZE: int = 14
## Dokunma alanının en küçük kenarı: Android'in 48 dp önerisi bu telefonda ~71 birim. Görünür
## plakadan büyükse fazlası GÖRÜNMEZ bir kenar payı olur (_has_point) — plaka şişmez.
const MIN_TOUCH: float = 72.0
## Kenar payları çakışınca hakem: bu gruptaki düğmelerden görünür dikdörtgeni en yakın olan alır.
const GROUP: StringName = &"plate_buttons"

@export var shape: Shape = Shape.PLATE:
	set(value):
		shape = value
		queue_redraw()

@export var kind: HudIcon.Kind = HudIcon.Kind.NONE:
	set(value):
		kind = value
		queue_redraw()

@export_range(8.0, 40.0, 1.0) var icon_size: float = 22.0:
	set(value):
		icon_size = value
		queue_redraw()

## Plakanın köşelerindeki cıvata noktaları.
@export var bolts: bool = true:
	set(value):
		bolts = value
		queue_redraw()

## Seçili/basılı plaka bu kadar piksel yukarı kalkar (temadaki expand_margin_top ile aynı olmalı).
@export var lift_when_pressed: float = 3.0

## Ayarlıysa ikon yerine plakaya küçük bir fotoğraf basılır (ehliyet fotoğrafı gibi).
@export var avatar: Texture2D:
	set(value):
		avatar = value
		queue_redraw()

## Fotoğrafın çevresine ince çerçeve çizilir; marka logosu (Google "G") çerçevesiz kalmalı.
@export var avatar_frame: bool = true:
	set(value):
		avatar_frame = value
		queue_redraw()

## Dikkat çeken plaka (ör. alınabilir ödül): temadaki stilin kopyası amber (seçili plaka rengi) olur.
## Her varyasyonda çalışır; tema dosyası değişmez.
@export var highlight: bool = false:
	set(value):
		highlight = value
		if is_inside_tree():
			_apply_highlight()


## Taban nedeniyle büyüyen yuvarlak tabelada ikonun büyütme oranı (1 = değişmedi).
var _icon_scale: float = 1.0


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	if highlight:
		_apply_highlight()
	if Engine.is_editor_hint() or mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return
	add_to_group(GROUP)
	if shape == Shape.PLATE and get_theme_font_size(&"font_size") < MIN_FONT_SIZE:
		add_theme_font_size_override(&"font_size", MIN_FONT_SIZE)
	if shape == Shape.ROUND and custom_minimum_size.y > 0.0 and custom_minimum_size.y < MIN_SIGN_SIZE:
		_icon_scale = MIN_SIGN_SIZE / custom_minimum_size.y
	# UI kodunun çoğu `custom_minimum_size = Vector2(genişlik, 0)` atamasını düğmeyi ağaca
	# ekledikten SONRA yapıyor; taban bir kez konup bırakılsa yüksekliği sıfırlanırdı. Sinyal
	# her atamada (ertelenmiş) geldiği için taban kendini onarır — ölçüldü: qa/min_size_probe.gd.
	# Sanal _get_minimum_size() burada işe yaramaz: Button'ın C++ hesabı onu yok sayıyor (ölçüldü).
	minimum_size_changed.connect(_heal_min_size)
	_heal_min_size()


func _heal_min_size() -> void:
	var least: Vector2 = Vector2(MIN_SIGN_SIZE, MIN_SIGN_SIZE) if shape == Shape.ROUND \
			else Vector2(0.0, MIN_PLATE_HEIGHT)
	var want: Vector2 = custom_minimum_size.max(least)
	if want != custom_minimum_size:
		custom_minimum_size = want


## Görünür plakadan küçük dokunma hedefi için görünmez kenar payı. Godot bu metodu hem fare hem
## (fareye çevrilen) dokunma için kullanır; kapsayıcının dışına taşan pay da tıklama alır —
## ölçüldü: qa/hit_area_probe.gd.
func _has_point(point: Vector2) -> bool:
	var own: Rect2 = Rect2(Vector2.ZERO, size)
	if own.has_point(point):
		return true
	if Engine.is_editor_hint() or not is_in_group(GROUP):
		return false
	var slop: Vector2 = ((Vector2(MIN_TOUCH, MIN_TOUCH) - size) * 0.5).max(Vector2.ZERO)
	if slop == Vector2.ZERO or not own.grow_individual(slop.x, slop.y, slop.x, slop.y).has_point(point):
		return false
	# Kenar payları çakışınca (yan yana tabelalar, alt alta menü plakaları) nokta, görünür
	# dikdörtgeni EN YAKIN düğmenin olur; yoksa ağaçta sonra gelen hep kazanırdı ve plakalar
	# arasındaki boşluğa dokunmak aşağıdakini açardı.
	var at: Vector2 = get_global_transform() * point
	var mine: float = _distance(get_global_rect(), at)
	for node: Node in get_tree().get_nodes_in_group(GROUP):
		var other: Control = node as Control
		if other == self or not other.is_visible_in_tree():
			continue
		if _distance(other.get_global_rect(), at) < mine:
			return false
	return true


static func _distance(rect: Rect2, point: Vector2) -> float:
	var dx: float = maxf(maxf(rect.position.x - point.x, point.x - rect.end.x), 0.0)
	var dy: float = maxf(maxf(rect.position.y - point.y, point.y - rect.end.y), 0.0)
	return Vector2(dx, dy).length()


func _apply_highlight() -> void:
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed"]:
		remove_theme_stylebox_override(state)
		if not highlight:
			continue
		var base: StyleBox = get_theme_stylebox(state)
		if base is StyleBoxFlat:
			var amber: StyleBoxFlat = base.duplicate() as StyleBoxFlat
			amber.bg_color = HudPalette.PLATE_SELECTED_HOVER if state == &"hover" else HudPalette.PLATE_SELECTED
			amber.border_color = HudPalette.PLATE_SELECTED_EDGE
			add_theme_stylebox_override(state, amber)
	queue_redraw()


func _draw() -> void:
	var mode: DrawMode = get_draw_mode()
	var pressed: bool = mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED
	var lift: float = lift_when_pressed if pressed else 0.0
	var ink: Color = _ink_for(mode)
	var bg: Color = _bg_for(mode)

	if shape == Shape.ROUND:
		if kind != HudIcon.Kind.NONE:
			HudIcon.draw_icon(self, kind, size * 0.5 + Vector2(0.0, -1.0), icon_size * _icon_scale, ink, bg)
		return

	var has_icon: bool = kind != HudIcon.Kind.NONE or avatar != null
	if bolts:
		var bolt: Color = Color(ink, 0.45)
		var y: float = (7.0 if has_icon else size.y * 0.5) - lift
		draw_circle(Vector2(7.0, y), 1.7, bolt, true, -1.0, true)
		draw_circle(Vector2(size.x - 7.0, y), 1.7, bolt, true, -1.0, true)
	if has_icon:
		# İkon, stylebox'ın üst content margin'inin ortasına oturur; yazı onun altında.
		var zone: float = get_theme_stylebox(&"normal").content_margin_top
		var center: Vector2 = Vector2(size.x * 0.5, zone * 0.5 + 3.0 - lift)
		if avatar:
			var side: float = icon_size + 2.0
			var rect: Rect2 = Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side))
			draw_texture_rect(avatar, rect, false)
			if avatar_frame:
				draw_rect(rect, ink, false, 1.5, true)
		else:
			HudIcon.draw_icon(self, kind, center, icon_size, ink, bg)


func _ink_for(mode: DrawMode) -> Color:
	match mode:
		DRAW_HOVER:
			return get_theme_color(&"font_hover_color")
		DRAW_PRESSED:
			return get_theme_color(&"font_pressed_color")
		DRAW_HOVER_PRESSED:
			return get_theme_color(&"font_hover_pressed_color")
		DRAW_DISABLED:
			return get_theme_color(&"font_disabled_color")
		_:
			return get_theme_color(&"font_color")


func _bg_for(mode: DrawMode) -> Color:
	var style_name: StringName = &"normal"
	match mode:
		DRAW_HOVER:
			style_name = &"hover"
		DRAW_PRESSED:
			style_name = &"pressed"
		DRAW_HOVER_PRESSED:
			style_name = &"hover_pressed"
		DRAW_DISABLED:
			style_name = &"disabled"
	var sb: StyleBox = get_theme_stylebox(style_name)
	if sb is StyleBoxFlat:
		return (sb as StyleBoxFlat).bg_color
	return Color(0.0, 0.0, 0.0, 0.0)
