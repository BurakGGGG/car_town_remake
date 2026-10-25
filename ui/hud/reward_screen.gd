class_name RewardScreen
extends Control
## ÖDÜL EKRANI TABANI (2026-10-25): SEVİYE ATLADIN (LevelUpScreen) ve HEDİYEN GELDİ! (GiftScreen) aynı dilde — karartma,
## rozetin arkasında yavaşça dönen ışık hüzmeleri, büyük konturlu başlık, ₺ / GEM hapları, ince çizgili ara başlık
## (AÇILANLAR / İÇİNDEKİLER) ve resimli krem kartlar: müşteri balonu, depo fotoğrafı, dönen 3B kasa, araç fotoğrafı, profil
## çerçevesi (oyuncunun kendi avatarıyla), dekor küçük resimleri. Kartlar sırayla "pıt" diye yerine oturur. Seviye atlama
## ekranından ayrıldı (kullanıcı: "hediye ekranı da seviye atlama ekranındaki gibi olsun").
## Alt sınıf rozeti (_make_badge), düğmeleri (_add_buttons), kartların içeriğini (_card_from) ve açılış zamanını verir;
## _present ekranı gösterir, close kapatır (_on_closing / _on_closed kancaları). Boş yere dokununca da kapanır. Hud kurar
## (Root altında: CanvasLayer'a doğrudan eklenen Control temasız çizilir).

signal closed

## Açılır açılmaz gelen dokunuş pencereyi kapatmasın.
const TAP_GUARD: float = 0.6
const BADGE_SIZE: float = 74.0
const TITLE_SIZE: int = 24
const CARD_MAX_WIDTH: float = 196.0
const CARD_MIN_WIDTH: float = 124.0
const CARD_GAP: float = 12.0
const PIC_HEIGHT: float = 68.0
const DECOR_THUMBS: int = 3
const CARD_STAGGER: float = 0.12

var _hud: Hud
var _opened_at: int = 0
var _closing: bool = false

var _sfx: RewardSfx
var _thumbs: DecorThumbs
var _rays: _Rays
var _column: VBoxContainer
var _badge: Control
var _title: Label
var _money_chip: PanelContainer
var _money_label: Label
var _gem_chip: PanelContainer
var _gem_label: Label
var _divider: HBoxContainer
var _divider_label: Label
var _cards: HBoxContainer
var _buttons: HBoxContainer
## Dekor küçük resmi bekleyen TextureRect'ler: eşya id → Array[TextureRect].
var _thumb_slots: Dictionary = {}


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	resized.connect(_layout_cards)


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	_rays.stop()
	_on_closing()
	PlateAnim.pop_out(self, _column, func() -> void:
		hide()
		_clear_cards()
		_closing = false
		closed.emit()
		_on_closed())


# --- Alt sınıfın kancaları -----------------------------------------------------

## Başlığın üstündeki rozet (seviye sayısı, hediye kutusu).
func _make_badge() -> Control:
	return Control.new()


## Ekranın altındaki düğmeler (DEVAM ET, REKLAM İZLE, TOPLA...).
func _add_buttons(_row: HBoxContainer) -> void:
	pass


## Kapanış başladı (ör. paralar sayaçlara uçar).
func _on_closing() -> void:
	pass


## Ekran kapandı (ör. sıradaki pencere).
func _on_closed() -> void:
	pass


# --- Gösterim ------------------------------------------------------------------

## Kartlar eklendikten sonra: ekran HUD panolarının üstüne çıkar, açılır, ışık döner, kartlar sırayla oturur.
func _present() -> void:
	_layout_cards()
	get_parent().move_child(self, -1)   # HUD panolarının en üstünde
	_closing = false
	_opened_at = Time.get_ticks_msec()
	PlateAnim.pop_in(self, _column)
	_rays.start()
	_sfx.fanfare()
	var cards: Array[Node] = _cards.get_children()
	for i: int in cards.size():
		_animate_card(cards[i] as Control, 0.25 + float(i) * CARD_STAGGER, i)


## Ödül hapları: ₺ ve GEM (0 olan gizlenir).
func _set_amounts(money: int, gems: int) -> void:
	_money_label.text = "+%s ₺" % Hud.format_thousands(money)
	_money_chip.visible = money > 0
	_gem_label.text = Loc.t("+%d GEM") % gems
	_gem_chip.visible = gems > 0


# --- Kurulum -----------------------------------------------------------------

func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.06, 0.07, 0.09, 0.74)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_sfx = RewardSfx.new()
	add_child(_sfx)
	_thumbs = DecorThumbs.new()
	_thumbs.ready_for.connect(_on_thumb_ready)
	add_child(_thumbs)

	_rays = _Rays.new()
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rays.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_rays)

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	add_child(margin)
	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_column.add_theme_constant_override(&"separation", 5)
	margin.add_child(_column)

	_badge = _make_badge()
	_badge.custom_minimum_size = Vector2(BADGE_SIZE, BADGE_SIZE)
	_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_column.add_child(_badge)
	_rays.target = _badge

	_title = _label(&"HudOutlinedLarge", "")
	_title.add_theme_font_size_override(&"font_size", TITLE_SIZE)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(_title)

	var rewards: HBoxContainer = HBoxContainer.new()
	rewards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rewards.alignment = BoxContainer.ALIGNMENT_CENTER
	rewards.add_theme_constant_override(&"separation", 10)
	_column.add_child(rewards)
	_money_label = _label(&"HudOutlinedLarge", "")
	_money_chip = _chip(HudIcon.Kind.COIN, _money_label)
	rewards.add_child(_money_chip)
	_gem_label = _label(&"HudOutlinedLarge", "")
	_gem_chip = _chip(HudIcon.Kind.GEM, _gem_label)
	rewards.add_child(_gem_chip)

	_divider = HBoxContainer.new()
	_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_divider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_divider.add_theme_constant_override(&"separation", 10)
	_divider.add_child(_line())
	_divider_label = _label(&"HudOutlined", "")
	_divider.add_child(_divider_label)
	_divider.add_child(_line())
	_column.add_child(_divider)

	_cards = HBoxContainer.new()
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.add_theme_constant_override(&"separation", int(CARD_GAP))
	_column.add_child(_cards)

	_buttons = HBoxContainer.new()
	_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override(&"separation", 10)
	_column.add_child(_buttons)
	_add_buttons(_buttons)


func _gui_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if tapped and Time.get_ticks_msec() - _opened_at > int(TAP_GUARD * 1000.0):
		accept_event()
		close()


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Kart altındaki küçük yazı: dar kartta "…" ile kesilmek yerine en çok üç satıra sarılır (Fransızca "NOUVELLES PIÈCES
## POUR TA VOITURE DE COURSE" iki satıra sığmıyordu).
func _wrapped(variation: StringName, text: String) -> Label:
	var label: Label = _label(variation, text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = 3
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


func _rounded(color: Color, radius: int, pad_x: float, pad_y: float) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.content_margin_left = pad_x
	box.content_margin_right = pad_x
	box.content_margin_top = pad_y
	box.content_margin_bottom = pad_y
	return box


## Ödül hapı: koyu zemin üstünde ikon + konturlu sayı.
func _chip(kind: HudIcon.Kind, label: Label) -> PanelContainer:
	var chip: PanelContainer = PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box: StyleBoxFlat = _rounded(Color(0.08, 0.09, 0.1, 0.8), 16, 12.0, 3.0)
	box.content_margin_left = 5.0
	chip.add_theme_stylebox_override(&"panel", box)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 6)
	chip.add_child(row)
	var icon: HudIcon = HudIcon.new()
	icon.kind = kind
	icon.icon_size = 22.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	label.add_theme_font_size_override(&"font_size", 16)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	return chip


func _line() -> ColorRect:
	var line: ColorRect = ColorRect.new()
	line.color = Color(HudPalette.TEXT_LIGHT, 0.3)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.custom_minimum_size = Vector2(0.0, 2.0)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return line


# --- Kartlar -----------------------------------------------------------------

## Kart: sol üstte koyu etiket, resim alanı (picture), ad (dar kartta küçülür), açıklama ve isteğe bağlı turuncu not.
## alpha: kart solukluğu (SIRADAKİ kartlar).
func _card_from(tag: String, picture: Control, title: String, detail_text: String, need: String = "",
		alpha: float = 1.0) -> Control:
	var card: PlatePanel = PlatePanel.new()
	card.add_theme_stylebox_override(&"panel", _card_style())
	card.mouse_filter = Control.MOUSE_FILTER_STOP   # karta dokunmak pencereyi kapatmaz
	if alpha < 1.0:
		card.set_meta(&"alpha", alpha)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 4)
	card.add_child(box)
	var pic: PanelContainer = PanelContainer.new()
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.clip_contents = true
	pic.custom_minimum_size = Vector2(0.0, PIC_HEIGHT)
	pic.add_theme_stylebox_override(&"panel", _rounded(Color(HudPalette.INK, 0.08), 6, 0.0, 0.0))
	if picture:
		pic.add_child(picture)
	var name_label: Label = _label(&"HudInkValue", title)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	card.set_meta(&"name_label", name_label)   # dar kartta uzun tek sözcük küçülür (_fit_name)
	box.add_child(_tag(tag))
	box.add_child(pic)
	box.add_child(name_label)
	box.add_child(_wrapped(&"HudInkCaption", detail_text))
	if need != "":
		var need_label: Label = _wrapped(&"HudInkCaption", need)
		need_label.add_theme_color_override(&"font_color", HudPalette.PLATE_SELECTED_EDGE)
		box.add_child(need_label)
	return card


## HudCarPlate krem plakası, iç boşluğu dar (16:9'da beş kart yan yana sığsın, adlar kesilmesin).
func _card_style() -> StyleBoxFlat:
	var box: StyleBoxFlat = _rounded(HudPalette.PLATE, 8, 8.0, 7.0)
	box.content_margin_bottom = 10.0
	box.border_width_bottom = 4
	box.border_color = HudPalette.PLATE_EDGE
	box.shadow_color = HudPalette.SHADOW
	box.shadow_size = 5
	box.shadow_offset = Vector2(0.0, 3.0)
	return box


## Kartın sol üstündeki koyu etiket (YENİ MÜŞTERİ, YENİ DEPO...).
func _tag(text: String) -> PanelContainer:
	var tag: PanelContainer = PanelContainer.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tag.add_theme_stylebox_override(&"panel", _rounded(HudPalette.INK, 9, 8.0, 1.0))
	var label: Label = _label(&"HudInkCaption", text)
	label.add_theme_color_override(&"font_color", HudPalette.PLATE_SELECTED)
	label.add_theme_font_size_override(&"font_size", 9)
	tag.add_child(label)
	return tag


## Dünyadaki müşteri balonu gibi: beyaz daire, koyu halka, ortada ikon.
func _bubble(kind: HudIcon.Kind, ring: Color) -> Control:
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bubble: _Bubble = _Bubble.new()
	bubble.kind = kind
	bubble.ring = ring
	bubble.custom_minimum_size = Vector2(PIC_HEIGHT - 14.0, PIC_HEIGHT - 14.0)
	center.add_child(bubble)
	return center


## Oyuncunun kendi avatarı yeni çerçevesiyle (HUD'daki profil düğmesinin resmi).
func _framed_avatar(frame_id: String) -> Control:
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var avatar: AvatarView = AvatarView.new()
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar.custom_minimum_size = Vector2(PIC_HEIGHT - 8.0, PIC_HEIGHT - 8.0)
	var texture: Texture2D = _hud.profile_button.avatar
	var preset: bool = texture != null and texture.resource_path.begins_with("res://assets/ui/avatars/")
	avatar.show_avatar(texture, preset, frame_id)
	center.add_child(avatar)
	return center


func _photo(path: String) -> TextureRect:
	var photo: TextureRect = TextureRect.new()
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists(path):
		photo.texture = load(path) as Texture2D
	return photo


## İlk DECOR_THUMBS eşyanın küçük resmi (DecorThumbs tembel üretir) + kalanların sayısı köşede. Zemin karosu / duvar
## kaplamasının 3B resmi yok: dokunun kendisinden kare önizleme (dekor paletindeki gibi; seviye 2'de yalnız karo açılır,
## kart bomboş kalıyordu).
func _decor_strip(items: Array[StringName]) -> Control:
	var holder: MarginContainer = MarginContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: StringName in [&"margin_top", &"margin_right"]:
		holder.add_theme_constant_override(side, 4)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 0)
	holder.add_child(row)
	for i: int in mini(items.size(), DECOR_THUMBS):
		var id: StringName = items[i]
		if GarageDecor.is_pattern(id) or GarageDecor.is_surface(id):
			var swatch: _Swatch = _Swatch.new()
			swatch.texture = DecorTextures.swatch(id)
			swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
			swatch.custom_minimum_size = Vector2(0.0, PIC_HEIGHT - 4.0)
			swatch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(swatch)
			continue
		var thumb: TextureRect = TextureRect.new()
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.custom_minimum_size = Vector2(0.0, PIC_HEIGHT - 4.0)   # genişlik kartın: dar ekranda kartı büyütmesin
		thumb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		thumb.texture = DecorThumbs.fitted(id)
		if thumb.texture == null:
			if not _thumb_slots.has(id):
				_thumb_slots[id] = []
			(_thumb_slots[id] as Array).append(thumb)
			_thumbs.request(id)
		row.add_child(thumb)
	if items.size() > DECOR_THUMBS:
		var more: PanelContainer = PanelContainer.new()
		more.mouse_filter = Control.MOUSE_FILTER_IGNORE
		more.size_flags_horizontal = Control.SIZE_SHRINK_END   # köşede, resimlerin üstünde: genişliklerinden yemesin
		more.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		more.add_theme_stylebox_override(&"panel", _rounded(HudPalette.INK, 9, 6.0, 1.0))
		var label: Label = _label(&"HudInkCaption", "+%d" % (items.size() - DECOR_THUMBS))
		label.add_theme_color_override(&"font_color", HudPalette.TEXT_LIGHT)
		more.add_child(label)
		holder.add_child(more)
	return holder


func _on_thumb_ready(id: StringName) -> void:
	for thumb: Variant in _thumb_slots.get(id, []):
		if is_instance_valid(thumb):
			(thumb as TextureRect).texture = DecorThumbs.fitted(id)
	_thumb_slots.erase(id)


func _clear_cards() -> void:
	_thumb_slots.clear()
	for child: Node in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()


## Kart genişliği ekrana göre: en dar tuvalde (853) dört kart da sığsın.
func _layout_cards() -> void:
	if _cards == null:
		return
	var count: int = _cards.get_child_count()
	if count == 0:
		return
	var room: float = size.x - 28.0 - CARD_GAP * float(count - 1)
	var width: float = clampf(room / float(count), CARD_MIN_WIDTH, CARD_MAX_WIDTH)
	for child: Node in _cards.get_children():
		(child as Control).custom_minimum_size.x = width
		var name_label: Label = child.get_meta(&"name_label", null) as Label
		if name_label:
			_fit_name(name_label, width - 16.0)   # kartın iç payı (_card_style: yanlarda 8)
	_divider.custom_minimum_size.x = width * float(count) + CARD_GAP * float(count - 1)


## Kart başlığı sığmıyorsa yazı küçülür (en çok 9 punto; yine sığmazsa üç nokta). Almanca tek sözcük
## "BREMSENÜBERHOLUNG" (FREN REVİZYONU) en dar tuvalde 181 birimdi, kart 140: kesiliyordu.
func _fit_name(label: Label, width: float) -> void:
	label.remove_theme_font_size_override(&"font_size")
	var font: Font = label.get_theme_font(&"font")
	var base: int = label.get_theme_font_size(&"font_size")
	var size: int = base
	while size > 9 and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		size -= 1
	if size != base:
		label.add_theme_font_size_override(&"font_size", size)


## Kart sırayla "pıt" diye yerine oturur.
func _animate_card(card: Control, delay: float, index: int) -> void:
	var alpha: float = float(card.get_meta(&"alpha", 1.0))
	card.modulate.a = 0.0
	await get_tree().process_frame   # boyut hesaplansın (pivot ortada olsun)
	if not is_instance_valid(card):
		return
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2.ONE * 0.5
	var tween: Tween = card.create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(func() -> void: _sfx.tick(float(index + 1) / float(maxi(_cards.get_child_count(), 1))))
	tween.tween_property(card, "modulate:a", alpha, 0.1)
	tween.parallel().tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- Çizimler ------------------------------------------------------------------

## Zemin karosu / duvar kaplaması önizlemesi: dokudan kare, ince gölge ve çerçeve (dekor paletindeki kartla aynı dil).
class _Swatch extends Control:
	var texture: Texture2D

	func _draw() -> void:
		if texture == null:
			return
		var side: float = minf(size.x - 8.0, size.y - 8.0)
		if side <= 0.0:
			return
		var rect: Rect2 = Rect2(size * 0.5 - Vector2(side, side) * 0.5, Vector2(side, side))
		draw_rect(Rect2(rect.position + Vector2(2.0, 3.0), rect.size), HudPalette.SHADOW, true)
		draw_texture_rect(texture, rect, false)
		draw_rect(rect, Color(HudPalette.INK, 0.55), false, 1.5, true)


## Beyaz daire + renkli halka + ortada HudIcon (müşteri balonu, modifiye dişlisi, görev onayı).
class _Bubble extends Control:
	var kind: HudIcon.Kind = HudIcon.Kind.WRENCH
	var ring: Color = HudPalette.INK

	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var radius: float = minf(size.x, size.y) * 0.5 - 3.0
		draw_circle(center, radius, HudPalette.TEXT_LIGHT, true, -1.0, true)
		draw_arc(center, radius, 0.0, TAU, 40, ring, 4.0, true)
		HudIcon.draw_icon(self, kind, center, radius * 1.05, HudPalette.INK, HudPalette.TEXT_LIGHT)


## Rozetin arkasında yavaşça dönen sarı ışık hüzmeleri (RewardPopup'takinin rozete ortalanmışı).
class _Rays extends Control:
	const RAYS: int = 16
	const SPEED: float = 0.3

	var target: Control
	var _angle: float = 0.0

	func start() -> void:
		set_process(true)

	func stop() -> void:
		set_process(false)

	func _ready() -> void:
		set_process(false)

	func _process(delta: float) -> void:
		_angle = fmod(_angle + delta * SPEED, TAU)
		queue_redraw()

	func _draw() -> void:
		if target == null:
			return
		var center: Vector2 = target.get_global_rect().get_center() - get_global_rect().position
		var radius: float = size.y * 0.62
		var step: float = TAU / float(RAYS)
		var ray_color: Color = Color(HudPalette.COIN, 0.15)
		for i: int in RAYS:
			var a: float = _angle + step * float(i)
			draw_colored_polygon(PackedVector2Array([center,
				center + Vector2.from_angle(a) * radius,
				center + Vector2.from_angle(a + step * 0.45) * radius]), ray_color)
		draw_circle(center, radius * 0.32, Color(HudPalette.COIN, 0.1))


## Kasanın kendi 3B modeli, kartın içinde yavaşça döner (yalnızca pencere açıkken çizilir).
class _CratePreview extends SubViewportContainer:
	const SPIN: float = 0.6
	## Dünya kamerasıyla aynı bakış (DecorThumbs.VIEW_DIR).
	const VIEW_DIR: Vector3 = Vector3(0.6408563, 0.42261827, 0.6408563)

	var _entry: Dictionary
	var _pivot: Node3D

	func _init(entry: Dictionary) -> void:
		_entry = entry

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		stretch = true
		var viewport: SubViewport = SubViewport.new()
		viewport.transparent_bg = true
		viewport.own_world_3d = true
		viewport.msaa_3d = GameSettings.subviewport_msaa(Viewport.MSAA_4X)
		add_child(viewport)
		var camera: Camera3D = Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		var env: Environment = Environment.new()   # ortamsız SubViewport ışığı dünyaya sızdırıyordu (Compatibility)
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("D8CFBD")
		env.ambient_light_energy = 0.55
		camera.environment = env
		viewport.add_child(camera)
		var light: DirectionalLight3D = DirectionalLight3D.new()
		light.basis = Basis.looking_at(Vector3(-0.45, -1.0, -0.6).normalized(), Vector3.UP)
		light.light_color = Color("FFF3E0")
		light.light_energy = 1.05
		viewport.add_child(light)
		_pivot = Node3D.new()
		viewport.add_child(_pivot)
		var path: String = String(_entry.get("scene_path", ""))
		if path != "" and ResourceLoader.exists(path):
			var model: Node3D = (load(path) as PackedScene).instantiate() as Node3D
			if model:
				model.scale = Vector3.ONE * float(_entry.get("scale", 1.0))
				_pivot.add_child(model)
		var box: Vector3 = CrateCatalog.world_size()
		var extent: float = maxf((box.x + box.z) * 0.72, box.y * 1.15)
		camera.size = extent * 1.05
		var center: Vector3 = Vector3(0.0, box.y * 0.5, 0.0)
		camera.position = center + VIEW_DIR * 8.0
		camera.basis = Basis.looking_at(-VIEW_DIR, Vector3.UP)

	func _process(delta: float) -> void:
		if _pivot:
			_pivot.rotation.y = fmod(_pivot.rotation.y + delta * SPIN, TAU)
