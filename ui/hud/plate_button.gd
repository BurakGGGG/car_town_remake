@tool
class_name PlateButton
extends Button
## Plaka (PLATE) veya yuvarlak tabela (ROUND) butonu.
## Zemin/kalınlık/gölge temadaki StyleBox'tan gelir; ikon, cıvatalar ve
## basılıyken "kalkma" kayması burada çizilir. Yazı Button'ın kendi text'i.

enum Shape { PLATE, ROUND }

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

## Dikkat çeken plaka (ör. alınabilir ödül): temadaki stilin kopyası amber (seçili plaka rengi) olur.
## Her varyasyonda çalışır; tema dosyası değişmez.
@export var highlight: bool = false:
	set(value):
		highlight = value
		if is_inside_tree():
			_apply_highlight()


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	if highlight:
		_apply_highlight()


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
			HudIcon.draw_icon(self, kind, size * 0.5 + Vector2(0.0, -1.0), icon_size, ink, bg)
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
