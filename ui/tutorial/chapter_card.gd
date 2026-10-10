class_name ChapterCard
extends Control
## DERS KARTI — tam ekran sinematik geçiş. İki kipi var:
##   intro    : "USTALIK DERSİ 2/4" + büyük ikon tabelası + başlık + alt yazı + BAŞLA / SONRA.
##              Üstte ve altta yandan kayarak gelen sarı-siyah ikaz şeritleri, arkada dönen ışık.
##   complete : "TAMAMLANDI" damgası yukarıdan çarparak iner (tok ses, sarsıntı, konfeti); dokununca
##              ya da kısa süre sonra kendiliğinden kapanır.
## Kodla kurulur (.tscn yok); TutorialOverlay sahibidir.

## Kullanıcının seçimi: &"start", &"later", &"skip_all" ya da complete kipinde &"done".
signal chosen(id: StringName)

enum Icon { WRENCH, FLAG, CAR, BRUSH }

const TITLE_SIZE: int = 50
const COMPLETE_HOLD: float = 2.2
const LOGO_PATH: String = "res://assets/branding/autoyard_logo.png"

var sfx: TutorialSfx

var _backdrop: ColorRect
var _rays: _Rays
var _tape_top: _Tape
var _tape_bottom: _Tape
var _column: VBoxContainer
var _logo: TextureRect
var _caption: Label
var _sign: _Sign
var _title: Label
var _subtitle: Label
var _buttons: HBoxContainer
var _primary: PlateButton
var _secondary: PlateButton
var _stamp: _Stamp
var _confetti: _Confetti
var _mode: StringName = &""
var _opened_at: int = 0
var _closing: bool = false


func _ready() -> void:
	name = "ChapterCard"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


## info: caption, title, subtitle, icon (Icon), primary, secondary (boşsa gizli), logo (bool).
func show_intro(info: Dictionary) -> void:
	_mode = &"intro"
	_closing = false
	_caption.text = String(info.get("caption", ""))
	_title.text = String(info.get("title", ""))
	_subtitle.text = String(info.get("subtitle", ""))
	_subtitle.visible = _subtitle.text != ""
	_sign.icon = int(info.get("icon", Icon.WRENCH))
	_sign.visible = true
	_logo.visible = bool(info.get("logo", false)) and _logo.texture != null
	_primary.text = String(info.get("primary", Loc.t("BAŞLA")))
	_secondary.text = String(info.get("secondary", ""))
	_secondary.visible = _secondary.text != ""
	_secondary.set_meta(&"choice", info.get("secondary_choice", &"later"))
	_buttons.visible = true
	_stamp.visible = false
	_open()


## Ders bitti: damga + konfeti. title ders adıdır (damganın altında yazar).
func show_complete(title: String) -> void:
	_mode = &"complete"
	_closing = false
	_caption.text = Loc.t("DERS TAMAM")
	_title.text = title
	_subtitle.visible = false
	_logo.visible = false
	_sign.visible = false
	_buttons.visible = false
	_stamp.visible = true
	_stamp.modulate.a = 0.0
	_open()
	var tween: Tween = create_tween()
	tween.tween_interval(0.45)
	tween.tween_callback(_slam_stamp)
	tween.tween_interval(COMPLETE_HOLD)
	tween.tween_callback(func() -> void:
		if _mode == &"complete":
			_choose(&"done"))


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.22)
	tween.tween_property(_tape_top, "position:x", -size.x * 1.2, 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.tween_property(_tape_bottom, "position:x", size.x * 1.2, 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(func() -> void:
		hide()
		_rays.set_process(false)
		_closing = false)


func _gui_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if not tapped:
		return
	accept_event()
	# Tamamlandı kartı dokununca geçer (damga indikten sonra)
	if _mode == &"complete" and Time.get_ticks_msec() - _opened_at > 900:
		_choose(&"done")


func _choose(id: StringName) -> void:
	if _closing:
		return
	_mode = &""
	chosen.emit(id)
	close()


# --- Açılış koreografisi --------------------------------------------------------------

func _open() -> void:
	show()
	move_to_front()
	modulate.a = 1.0
	_opened_at = Time.get_ticks_msec()
	_rays.set_process(true)
	if sfx:
		sfx.play(&"whoosh")
	_backdrop.modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_backdrop, "modulate:a", 1.0, 0.25)
	# İkaz şeritleri iki yandan kayarak gelir (ortalarından eğik)
	for tape: _Tape in [_tape_top, _tape_bottom]:
		tape.pivot_offset = tape.size * 0.5
	_tape_top.position.x = -size.x * 1.2
	_tape_bottom.position.x = size.x * 1.2
	tween.tween_property(_tape_top, "position:x", -size.x * 0.1, 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(_tape_bottom, "position:x", -size.x * 0.1, 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).set_delay(0.06)
	# Sütun öğeleri sırayla yerine oturur
	var items: Array[Control] = [_logo, _caption, _sign, _title, _subtitle, _buttons]
	var delay: float = 0.18
	for item: Control in items:
		if not item.visible:
			continue
		item.modulate.a = 0.0
		tween.tween_property(item, "modulate:a", 1.0, 0.18).set_delay(delay)
		delay += 0.09
	await get_tree().process_frame   # boyutlar kesinleşsin (pivot ortada olsun)
	if not visible:
		return
	if _sign.visible:
		_sign.pivot_offset = _sign.size * 0.5
		_sign.scale = Vector2.ONE * 0.2
		_sign.rotation = -0.8
		var pop: Tween = create_tween().set_parallel(true)
		pop.tween_property(_sign, "scale", Vector2.ONE, 0.45).set_delay(0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop.tween_property(_sign, "rotation", 0.0, 0.45).set_delay(0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_title.pivot_offset = _title.size * 0.5
	_title.scale = Vector2.ONE * 1.7
	var slam: Tween = create_tween()
	slam.tween_interval(0.34)
	slam.tween_callback(func() -> void:
		if sfx:
			sfx.play(&"pop", 0.8))
	slam.tween_property(_title, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	if _buttons.visible:
		_buttons.pivot_offset = _buttons.size * 0.5
		_buttons.scale = Vector2.ONE * 0.8
		var buttons: Tween = create_tween()
		buttons.tween_interval(0.62)
		buttons.tween_property(_buttons, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _slam_stamp() -> void:
	_stamp.pivot_offset = _stamp.size * 0.5
	_stamp.scale = Vector2.ONE * 2.8
	_stamp.rotation = -0.05
	_stamp.modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_stamp, "modulate:a", 1.0, 0.1)
	tween.tween_property(_stamp, "scale", Vector2.ONE, 0.17).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_stamp, "rotation", -0.2, 0.17)
	tween.set_parallel(false)
	tween.tween_callback(func() -> void:
		if sfx:
			sfx.play(&"stamp")
		_confetti.burst(_stamp.get_global_rect().get_center() - global_position)
		_shake(_column, 9.0))


## Kısa sarsıntı (damga çarpınca).
func _shake(node: Control, strength: float) -> void:
	var origin: Vector2 = node.position
	var tween: Tween = create_tween()
	for i: int in 6:
		var k: float = 1.0 - float(i) / 6.0
		tween.tween_property(node, "position", origin + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength * k, 0.035)
	tween.tween_property(node, "position", origin, 0.04)


# --- Kurulum ------------------------------------------------------------------------

func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.03, 0.04, 0.07, 0.78)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)
	_rays = _Rays.new()
	_rays.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_rays)
	_tape_top = _make_tape(0.13, -1.0)
	_tape_bottom = _make_tape(0.87, 1.0)

	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_column.add_theme_constant_override(&"separation", 6)
	center.add_child(_column)

	_logo = TextureRect.new()
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.custom_minimum_size = Vector2(300.0, 70.0)
	_logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if ResourceLoader.exists(LOGO_PATH):
		_logo.texture = load(LOGO_PATH) as Texture2D
	_column.add_child(_logo)
	_caption = _label(18, HudPalette.PLATE_SELECTED, 5)
	_column.add_child(_caption)
	_sign = _Sign.new()
	_sign.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_column.add_child(_sign)
	_stamp = _Stamp.new()
	_stamp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_stamp.visible = false
	_column.add_child(_stamp)
	_title = _label(TITLE_SIZE, HudPalette.TEXT_LIGHT, 12)
	_column.add_child(_title)
	_subtitle = _label(19, HudPalette.TEXT_LIGHT, 5)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.custom_minimum_size = Vector2(520.0, 0.0)
	_column.add_child(_subtitle)

	_buttons = HBoxContainer.new()
	_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override(&"separation", 12)
	_column.add_child(_buttons)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0.0, 6.0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(gap)
	_column.move_child(gap, _buttons.get_index())
	_primary = PlateButton.new()
	_primary.theme_type_variation = &"HudPlate"
	_primary.highlight = true
	_primary.focus_mode = Control.FOCUS_NONE
	_primary.custom_minimum_size = Vector2(190.0, 54.0)
	_primary.pressed.connect(func() -> void: _choose(&"start"))
	_buttons.add_child(_primary)
	_secondary = PlateButton.new()
	_secondary.theme_type_variation = &"HudPlateSmall"
	_secondary.focus_mode = Control.FOCUS_NONE
	_secondary.custom_minimum_size = Vector2(150.0, 0.0)
	_secondary.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_secondary.pressed.connect(func() -> void: _choose(StringName(_secondary.get_meta(&"choice", &"later"))))
	_buttons.add_child(_secondary)

	_confetti = _Confetti.new()
	_confetti.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_confetti)


## İkaz şeridi: ekran genişliğinin 1,2 katı, hafif eğik; yükseklik oranı `anchor_y`.
func _make_tape(anchor_y: float, direction: float) -> _Tape:
	var tape: _Tape = _Tape.new()
	tape.direction = direction
	tape.anchor_left = 0.0
	tape.anchor_right = 1.2
	tape.anchor_top = anchor_y
	tape.anchor_bottom = anchor_y
	tape.offset_top = -_Tape.HEIGHT * 0.5
	tape.offset_bottom = _Tape.HEIGHT * 0.5
	tape.rotation = -0.05
	add_child(tape)
	return tape


func _label(font_size: int, color: Color, outline: int) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = &"HudOutlined"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_constant_override(&"outline_size", outline)
	return label


## Sarı-siyah ikaz şeridi: çizgiler sürekli kayar (inşaat bandı gibi).
class _Tape extends Control:
	const HEIGHT: float = 34.0
	const STRIPE: float = 26.0
	const SPEED: float = 40.0

	var direction: float = 1.0
	var _offset: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		_offset = fmod(_offset + delta * SPEED * direction, STRIPE * 2.0)
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2(0.0, 4.0), size), Color(0.0, 0.0, 0.0, 0.35))
		draw_rect(Rect2(Vector2.ZERO, size), HudPalette.PLATE_SELECTED)
		var x: float = -STRIPE * 2.0 + _offset
		while x < size.x + STRIPE:
			draw_colored_polygon(PackedVector2Array([Vector2(x, size.y), Vector2(x + STRIPE, 0.0),
				Vector2(x + STRIPE * 2.0, 0.0), Vector2(x + STRIPE, size.y)]), HudPalette.INK)
			x += STRIPE * 2.0
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 3.0)), Color(1.0, 1.0, 1.0, 0.25))


## Arkada yavaş dönen amber ışık hüzmeleri.
class _Rays extends Control:
	const RAYS: int = 16

	var _angle: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(false)

	func _process(delta: float) -> void:
		_angle = fmod(_angle + delta * 0.25, TAU)
		queue_redraw()

	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var radius: float = size.length() * 0.6
		var step: float = TAU / float(RAYS)
		for i: int in RAYS:
			var a: float = _angle + step * float(i)
			draw_colored_polygon(PackedVector2Array([center, center + Vector2.from_angle(a) * radius,
				center + Vector2.from_angle(a + step * 0.45) * radius]), Color(HudPalette.COIN, 0.07))
		draw_circle(center, minf(size.x, size.y) * 0.32, Color(HudPalette.COIN, 0.06))


## Dersin ikon tabelası: büyük yuvarlak amber tabela, içinde ders ikonu.
class _Sign extends Control:
	const RADIUS: float = 50.0

	var icon: int = 0:
		set(value):
			icon = value
			queue_redraw()

	func _init() -> void:
		custom_minimum_size = Vector2(RADIUS * 2.0 + 16.0, RADIUS * 2.0 + 16.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		draw_circle(c + Vector2(0.0, 5.0), RADIUS + 4.0, Color(0.0, 0.0, 0.0, 0.35))
		draw_circle(c, RADIUS + 4.0, HudPalette.PLATE_SELECTED_EDGE)
		draw_circle(c, RADIUS, HudPalette.PLATE_SELECTED)
		draw_arc(c, RADIUS - 7.0, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.45), 2.5, true)
		match icon:
			Icon.FLAG:
				_flag(c)
			Icon.CAR:
				HudIcon.draw_icon(self, HudIcon.Kind.CAR, c, 62.0, HudPalette.INK, HudPalette.PLATE_SELECTED)
			Icon.BRUSH:
				HudIcon.draw_icon(self, HudIcon.Kind.PAINT, c, 58.0, HudPalette.INK, HudPalette.PLATE_SELECTED)
			_:
				HudIcon.draw_icon(self, HudIcon.Kind.WRENCH, c, 58.0, HudPalette.INK, HudPalette.PLATE_SELECTED)

	## Damalı yarış bayrağı (direk + dalgalı 4x3 kare).
	func _flag(c: Vector2) -> void:
		var origin: Vector2 = c + Vector2(-20.0, -22.0)
		draw_rect(Rect2(origin + Vector2(-5.0, -2.0), Vector2(5.0, 52.0)), HudPalette.INK)
		var cell: float = 10.0
		for row: int in 3:
			for col: int in 4:
				var wave: float = sin(float(col) * 1.1) * 3.0
				var p: Vector2 = origin + Vector2(float(col) * cell, float(row) * cell + wave)
				var dark: bool = (row + col) % 2 == 0
				draw_colored_polygon(PackedVector2Array([p, p + Vector2(cell, sin(float(col + 1) * 1.1) * 3.0 - wave),
					p + Vector2(cell, cell + sin(float(col + 1) * 1.1) * 3.0 - wave), p + Vector2(0.0, cell)]),
					HudPalette.INK if dark else HudPalette.SIGN)


## DERS TAMAM damgası: kalın kırmızı çerçeveli eğik yazı (hafif aşınmış mürekkep).
class _Stamp extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(330.0, 104.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var ink: Color = Color("D2452F")
		var rect: Rect2 = Rect2(Vector2(8.0, 8.0), size - Vector2(16.0, 16.0))
		draw_rect(rect, ink, false, 7.0)
		draw_rect(rect.grow(-11.0), Color(ink, 0.8), false, 2.5)
		var font: Font = get_theme_default_font()
		var text: String = Loc.t("TAMAMLANDI")
		var font_size: int = 40
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var baseline: Vector2 = Vector2((size.x - width) * 0.5, size.y * 0.5 + font_size * 0.36)
		draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
		# Aşınma: birkaç açık renk leke (gerçek mürekkep damgası gibi)
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 5
		for i: int in 18:
			draw_circle(Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y)),
				rng.randf_range(1.0, 3.0), Color(1.0, 0.96, 0.9, 0.35))


## Konfeti: damga çarpınca saçılan renkli kâğıtlar (yerçekimi + savrulma), bitince durur.
class _Confetti extends Control:
	const COUNT: int = 90
	const GRAVITY: float = 820.0
	const COLORS: Array[Color] = [HudPalette.PLATE_SELECTED, HudPalette.GEM, HudPalette.DANGER, HudPalette.SIGN,
		HudPalette.GRASS]

	var _pieces: Array[Dictionary] = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(false)

	func burst(origin: Vector2) -> void:
		_pieces.clear()
		for i: int in COUNT:
			var angle: float = randf_range(-PI * 0.95, -PI * 0.05)
			_pieces.append({
				"pos": origin + Vector2(randf_range(-60.0, 60.0), randf_range(-10.0, 10.0)),
				"vel": Vector2.from_angle(angle) * randf_range(260.0, 720.0),
				"rot": randf() * TAU, "spin": randf_range(-9.0, 9.0),
				"size": Vector2(randf_range(6.0, 11.0), randf_range(3.0, 6.0)),
				"color": COLORS[i % COLORS.size()], "flip": randf() * TAU})
		set_process(true)

	func _process(delta: float) -> void:
		var alive: bool = false
		for p: Dictionary in _pieces:
			var vel: Vector2 = p["vel"]
			vel.y += GRAVITY * delta
			vel.x *= 1.0 - 1.2 * delta
			p["vel"] = vel
			p["pos"] = (p["pos"] as Vector2) + vel * delta
			p["rot"] = float(p["rot"]) + float(p["spin"]) * delta
			p["flip"] = float(p["flip"]) + delta * 8.0
			if (p["pos"] as Vector2).y < size.y + 20.0:
				alive = true
		queue_redraw()
		if not alive:
			_pieces.clear()
			set_process(false)

	func _draw() -> void:
		for p: Dictionary in _pieces:
			var piece_size: Vector2 = p["size"]
			piece_size.y *= absf(cos(float(p["flip"])))   # dönen kâğıt: daralıp genişler
			draw_set_transform(p["pos"], float(p["rot"]), Vector2.ONE)
			draw_rect(Rect2(-piece_size * 0.5, piece_size), p["color"])
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
