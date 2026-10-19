class_name NewsScreen
extends Control
## OTO MANŞET — oyuna girişte "sen yokken neler oldu" gazetesi (2026-10-17, kullanıcıyla soru-cevapla karar):
## renkli magazin gazetesi (kırmızı başlık bandı, kalın manşet, renkli fotoğraflar), esprili magazin dili, tek sayfa,
## YALNIZ TAMAM düğmesi (intikam / gönder / kabul ARKADAŞLAR'dan yapılır). Önce gazeteci çocuğun bisiklet zili çalar,
## gazete MASAYA FIRLATILMIŞ gibi yandan kayarak gelir, "pat" diye düşer ve birkaç derece yamuk kalır.
## İçerik NewsDigest'ten: manşet (en çarpıcı haber + büyük fotoğraf), sütunlar, alttaki KISA KISA şeridi.
## Kullanım: prepare(ham haberler, sayı) → UiRouter MODAL "news" open(). Sol üst HUD açıkken gizlenir (tam sayfa).
## Ekran TAMAMEN KODLA kurulur (.tscn yok). Sesler: NewsSfx.

signal opened
signal closed

const PAPER: Color = Color("FBF6EA")
const PAPER_EDGE: Color = Color("D5C8AA")
const RED: Color = Color("D7342A")
const RED_DARK: Color = Color("9C2117")
const INK: Color = Color("1F2023")
const INK_SOFT: Color = Color("4F535A")
const RULE: Color = Color("1F2023", 0.85)
const DIM_ALPHA: float = 0.5

## Tasarım genişliği: yazı boyları bu genişliğe göre ölçeklenir (853x480 telefonda sayfa ~800 birim).
const BASE_WIDTH: float = 800.0
const MAX_WIDTH: float = 1000.0
## Sayfanın en/boy sınırı: geniş ekranda sayfa uzayıp yayvanlaşmasın (masa görünsün).
const MAX_ASPECT: float = 1.78
const SIDE_MARGIN: float = 28.0
const COLUMNS: int = 3

## Fırlatma ritmi: zil çalar, THROW_DELAY sonra gazete gelir; DROP_TIME'da masaya değer (pat), THROW_TIME'da durur.
const THROW_DELAY: float = 0.32
const DROP_TIME: float = 0.24
const THROW_TIME: float = 0.5
const START_TILT: float = 26.0
const START_SCALE: float = 1.3
## Durduğu yamukluk (derece, işareti rastgele): "masaya atılmış" hissi; büyük olursa yazı okunmaz.
const TILT_MIN: float = 1.1
const TILT_MAX: float = 2.0
const CLOSE_TIME: float = 0.3
const NBSP: String = "\u00A0"

var _issue: Dictionary = {}
var _number: int = 1
var _seed: int = 0
var _tilt: float = 0.0
var _scale: float = 1.0   # yazı ölçeği (genişlikten)
var _fit: float = 1.0     # sayfa ekrana sığmazsa küçültme
var _closing: bool = false
var _tween: Tween

var _dim: ColorRect
var _slot: Control
var _paper: PanelContainer
var _column: VBoxContainer
var _ok: PlateButton
var _sfx: NewsSfx
var _briefs: Label
var _brief_list: PackedStringArray = PackedStringArray()
var _money_photo: Control   # kazanç haberinin fotoğrafı: TAMAM'da paralar buradan sayaca uçar
var _money_from: Vector2 = Vector2.ZERO

var _masthead_font: FontVariation
var _headline_font: FontVariation
var _bold_font: FontVariation
var _italic_font: FontVariation


func _ready() -> void:
	name = "NewsScreen"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # açıkken dünyaya dokunuş gitmez
	_sfx = NewsSfx.new()
	add_child(_sfx)
	_make_fonts()
	_build()


## Gazeteyi hazırlar (açmaz). `raw` NewsDigest ham haberleri, `number` gazetenin sayısı (kalıp seçimi de buna bağlı).
## Haber yoksa false: gazete açılmamalı (kullanıcı kararı: boş gazete çıkmaz).
func prepare(raw: Array[Dictionary], number: int) -> bool:
	_number = maxi(number, 1)
	_seed = _number
	_issue = NewsDigest.compose(raw, COLUMNS)
	if _issue.is_empty():
		return false
	_layout()
	_fill()
	return true


func has_issue() -> bool:
	return not _issue.is_empty()


## Paraların uçuşa başlayacağı yer (tuval koordinatı): kapanırken kazanç fotoğrafının ortası, yoksa ekranın ortası.
func money_origin() -> Vector2:
	return _money_from if _money_from != Vector2.ZERO else get_viewport_rect().size * 0.5


func open() -> void:
	if visible or _issue.is_empty():
		return
	_closing = false
	_ok.disabled = true
	show()
	modulate.a = 1.0
	_dim.color.a = 0.0
	_paper.modulate.a = 1.0
	_tilt = randf_range(TILT_MIN, TILT_MAX) * (-1.0 if randf() < 0.5 else 1.0)
	_place_off_screen(Vector2(1.15, 0.4), START_TILT)
	_sfx.bell()
	opened.emit()
	_throw_in.call_deferred()


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	_ok.disabled = true
	_money_from = Hud.screen_rect(_money_photo).get_center() if is_instance_valid(_money_photo) else Vector2.ZERO
	_sfx.rustle()
	if _tween:
		_tween.kill()
	var view: Vector2 = get_viewport_rect().size
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_paper, "position", Vector2(-view.x * 1.1, -view.y * 0.12), CLOSE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(_paper, "rotation", deg_to_rad(-16.0), CLOSE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(_dim, "color:a", 0.0, CLOSE_TIME)
	_tween.chain().tween_callback(func() -> void:
		hide()
		_closing = false
		closed.emit())


## Fırlatma: zil çalarken bekler, sonra gazete yandan dönerek kayar; büyüklüğü (havadan düşüş) önce biter — masaya
## değdiği an "pat" + hafif ezilme, kayma biraz daha sürer ve hışırtıyla durur. TAMAM ancak durunca basılır.
func _throw_in() -> void:
	for i: int in 2:
		await get_tree().process_frame   # sarılan yazıların boyu yerleşsin (sığdırma ölçümü doğru olsun)
	if not visible or _closing:
		return
	_fit_briefs()
	_measure_fit()
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_dim, "color:a", DIM_ALPHA, 0.25)
	_tween.tween_property(_paper, "position", Vector2.ZERO, THROW_TIME).set_delay(THROW_DELAY) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_paper, "rotation", deg_to_rad(_tilt), THROW_TIME).set_delay(THROW_DELAY) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_paper, "scale", Vector2.ONE * _fit, DROP_TIME).set_delay(THROW_DELAY) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_on_landed).set_delay(THROW_DELAY + DROP_TIME)
	_tween.tween_callback(_sfx.rustle).set_delay(THROW_DELAY + DROP_TIME + 0.08)
	_tween.tween_callback(func() -> void: _ok.disabled = false).set_delay(THROW_DELAY + THROW_TIME)


## Masaya değdi: pat + sayfa bir an ezilip yerine oturur.
func _on_landed() -> void:
	_sfx.slap()
	var bump: Tween = create_tween()
	bump.tween_property(_paper, "scale", Vector2(1.012, 0.985) * _fit, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bump.tween_property(_paper, "scale", Vector2.ONE * _fit, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Sayfa ekranın dışında, `at` ekran boyuna oranla kaydırılmış, `tilt` derece dönük ve havada (büyük).
func _place_off_screen(at: Vector2, tilt: float) -> void:
	var view: Vector2 = get_viewport_rect().size
	_paper.position = view * at
	_paper.rotation = deg_to_rad(tilt)
	_paper.scale = Vector2.ONE * START_SCALE * _fit


## KISA KISA iki satıra sığmazsa sondaki (en önemsiz) haberler düşer, yerine "+N HABER DAHA" yazar (kullanıcı kararı:
## gazete tek sayfa, taşan en önemsizler düşer).
func _fit_briefs() -> void:
	if _briefs == null or _brief_list.size() < 2:
		return
	var shown: PackedStringArray = _brief_list.duplicate()
	while shown.size() > 1 and _briefs.get_line_count() > _briefs.max_lines_visible:
		shown.remove_at(shown.size() - 1)
		var more: int = _brief_list.size() - shown.size()
		var parts: PackedStringArray = shown.duplicate()
		parts.append((Loc.tn("+%d HABER DAHA", more) % more).replace(" ", NBSP))
		_briefs.text = _join_briefs(parts)


## Haberler arası "  •  ": satır yalnızca noktadan ÖNCE kırılabilir (nokta satır sonunda asılı kalmasın, haberin
## ortası bölünmesin — haberlerin kendi boşlukları bölünmez boşluk).
static func _join_briefs(list: PackedStringArray) -> String:
	return ("  •" + NBSP).join(list)


## Sayfa (yamukluğuyla birlikte) ekrana sığmıyorsa küçültülür: kalabalık gazete kısa ekranda kesilmesin.
func _measure_fit() -> void:
	var view: Vector2 = get_viewport_rect().size
	var page: Vector2 = _paper.get_combined_minimum_size()
	var tilt: float = deg_to_rad(TILT_MAX)
	var extent: Vector2 = Vector2(page.x * cos(tilt) + page.y * sin(tilt), page.x * sin(tilt) + page.y * cos(tilt))
	var room: Vector2 = view - Vector2(16.0, 16.0)
	_fit = minf(1.0, minf(room.x / maxf(extent.x, 1.0), room.y / maxf(extent.y, 1.0)))


# --- Kurulum ---------------------------------------------------------------------------------------

func _make_fonts() -> void:
	_masthead_font = FontVariation.new()
	_masthead_font.variation_embolden = 1.25
	_masthead_font.variation_transform = Transform2D(Vector2(1.0, 0.2), Vector2(0.0, 1.0), Vector2.ZERO)   # eğik (belgedeki italik örneği)
	_masthead_font.spacing_glyph = 1
	_headline_font = FontVariation.new()
	_headline_font.variation_embolden = 1.0
	_bold_font = FontVariation.new()
	_bold_font.variation_embolden = 0.7
	_italic_font = FontVariation.new()
	_italic_font.variation_embolden = 0.35
	_italic_font.variation_transform = Transform2D(Vector2(1.0, 0.18), Vector2(0.0, 1.0), Vector2.ZERO)


func _build() -> void:
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = Color(0.0, 0.0, 0.0, 0.0)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	# Yuva sayfanın yerini tutar: ekranın ortasına çapalı, iki yöne büyür (CenterContainer sayfa ekrandan uzunken kendisi
	# uzayıp sayfayı aşağı itiyordu; sığdırma küçültmesi ortadan yapılır). Sayfa yuvanın içinde serbest (kapsayıcı değil):
	# fırlatma animasyonu konumunu oynatırken kapsayıcı yeniden dizip yerine "ışınlamasın".
	_slot = Control.new()
	_slot.name = "Slot"
	_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_slot.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_slot.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_slot)

	_paper = PanelContainer.new()
	_paper.name = "Paper"
	_paper.mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = PAPER_EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	style.shadow_size = 16
	style.shadow_offset = Vector2(5.0, 9.0)
	_paper.add_theme_stylebox_override(&"panel", style)
	_paper.minimum_size_changed.connect(_sync_slot)
	_slot.add_child(_paper)

	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.add_child(_column)

	_ok = PlateButton.new()
	_ok.name = "OkButton"
	_ok.theme_type_variation = &"HudPlate"
	_ok.text = Loc.t("TAMAM")
	_ok.kind = HudIcon.Kind.CHECK
	_ok.icon_left = true
	_ok.highlight = true
	_ok.focus_mode = Control.FOCUS_NONE
	_ok.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ok.pressed.connect(close)


## Sayfa ölçüleri ve yazı ölçeği ekran boyundan (açılışta bir kez).
func _layout() -> void:
	var view: Vector2 = get_viewport_rect().size
	var width: float = minf(minf(view.x - SIDE_MARGIN * 2.0, view.y * MAX_ASPECT), MAX_WIDTH)
	_scale = clampf(width / BASE_WIDTH, 0.88, 1.2)
	_paper.custom_minimum_size = Vector2(width, 0.0)
	var style: StyleBoxFlat = _paper.get_theme_stylebox(&"panel") as StyleBoxFlat
	style.content_margin_left = 14.0 * _scale
	style.content_margin_right = 14.0 * _scale
	style.content_margin_top = 12.0 * _scale
	style.content_margin_bottom = 10.0 * _scale
	_column.add_theme_constant_override(&"separation", int(6.0 * _scale))
	_ok.custom_minimum_size = Vector2(150.0 * _scale, 0.0)


func _sync_slot() -> void:
	var page: Vector2 = _paper.get_combined_minimum_size()
	_slot.custom_minimum_size = page
	_paper.size = page
	_paper.pivot_offset = page * 0.5


## Gazeteyi baştan dizer: başlık bandı, tarih satırı, manşet, sütunlar, KISA KISA + TAMAM.
func _fill() -> void:
	_money_photo = null
	_money_from = Vector2.ZERO
	if _ok.get_parent():
		_ok.get_parent().remove_child(_ok)
	for child: Node in _column.get_children():
		_column.remove_child(child)
		child.queue_free()
	_column.add_child(_masthead())
	_column.add_child(_checker())
	_column.add_child(_dateline())
	_column.add_child(_rule(2.0))
	_column.add_child(_lead(_issue["headline"]))
	var columns: Array = _issue["columns"]
	if not columns.is_empty():
		_column.add_child(_rule(1.0))
		_column.add_child(_columns(columns))
	_column.add_child(_rule(2.0))
	_column.add_child(_footer(_issue["briefs"]))
	_sync_slot()


func _masthead() -> PanelContainer:
	var band: PanelContainer = PanelContainer.new()
	band.name = "Masthead"
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = RED
	style.border_color = RED_DARK
	style.border_width_bottom = 3
	style.set_corner_radius_all(2)
	style.content_margin_left = 14.0 * _scale
	style.content_margin_right = 12.0 * _scale
	style.content_margin_top = 2.0 * _scale
	style.content_margin_bottom = 4.0 * _scale
	band.add_theme_stylebox_override(&"panel", style)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(row)

	var left: VBoxContainer = VBoxContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_theme_constant_override(&"separation", int(-6.0 * _scale))
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var title: Label = _text(Loc.t("OTO MANŞET"), _masthead_font, 40, Color.WHITE)
	title.add_theme_color_override(&"font_shadow_color", RED_DARK)
	title.add_theme_constant_override(&"shadow_offset_x", 3)
	title.add_theme_constant_override(&"shadow_offset_y", 3)
	left.add_child(title)
	left.add_child(_text(Loc.t("MAHALLENİN EN HIZLI GAZETESİ"), _italic_font, 10, Color(1.0, 1.0, 1.0, 0.85)))

	var right: VBoxContainer = VBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override(&"separation", 0)
	row.add_child(right)
	for line: String in [Loc.t("SAYI %d") % _number, NewsDigest.date_text(Time.get_date_dict_from_system()),
			Loc.t("FİYATI: 1 CIVATA")]:
		var label: Label = _text(line, _bold_font, 10, Color(1.0, 1.0, 1.0, 0.92))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		right.add_child(label)
	return band


## Başlık bandının altında yarış bayrağı deseni.
func _checker() -> Control:
	var strip: _Checker = _Checker.new()
	strip.custom_minimum_size = Vector2(0.0, roundf(6.0 * _scale))
	return strip


func _dateline() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left: Label = _text(Loc.t("SEN YOKKEN NELER OLDU?"), _bold_font, 11, INK)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var count: int = 1 + (_issue["columns"] as Array).size() + (_issue["briefs"] as Array).size()
	row.add_child(_text(Loc.tn("%d HABER", count) % count, _bold_font, 11, INK_SOFT))
	return row


## MANŞET: solda bölüm etiketi + kocaman başlık + açıklama, sağda fotoğraf ve altı yazısı.
func _lead(item: Dictionary) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Lead"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", int(14.0 * _scale))

	var text: VBoxContainer = VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override(&"separation", int(4.0 * _scale))
	row.add_child(text)
	text.add_child(_tag(NewsDigest.section(item), 11))
	var title: Label = _wrapped(NewsDigest.title(item, _seed), _headline_font, 27, INK)
	title.name = "Headline"
	title.add_theme_constant_override(&"line_spacing", int(-4.0 * _scale))
	text.add_child(title)
	text.add_child(_wrapped(NewsDigest.deck(item), _bold_font, 13, INK_SOFT))

	var photo: VBoxContainer = VBoxContainer.new()
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo.add_theme_constant_override(&"separation", int(3.0 * _scale))
	row.add_child(photo)
	photo.add_child(_photo(item, Vector2(232.0, 136.0) * _scale, true))
	var caption: Label = _text(NewsDigest.caption(item), _italic_font, 10, INK_SOFT)
	caption.custom_minimum_size = Vector2(232.0 * _scale, 0.0)
	caption.clip_text = true
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	photo.add_child(caption)
	return row


## Sütunlar: ince dikey çizgilerle ayrılmış, eşit genişlikte; her birinde bölüm etiketi, küçük fotoğraf + başlık, açıklama.
func _columns(items: Array) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Columns"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", int(10.0 * _scale))
	for i: int in items.size():
		if i > 0:
			var line: ColorRect = ColorRect.new()
			line.color = Color(INK, 0.3)
			line.custom_minimum_size = Vector2(1.0, 0.0)
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(line)
		var item: Dictionary = items[i]
		var box: VBoxContainer = VBoxContainer.new()
		box.name = "Story%d" % i
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.size_flags_stretch_ratio = 1.0
		box.add_theme_constant_override(&"separation", int(3.0 * _scale))
		row.add_child(box)
		box.add_child(_text(NewsDigest.section(item), _bold_font, 9, RED))
		var head: HBoxContainer = HBoxContainer.new()
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_theme_constant_override(&"separation", int(7.0 * _scale))
		box.add_child(head)
		var thumb: Control = _photo(item, Vector2(46.0, 46.0) * _scale, false)
		thumb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		head.add_child(thumb)
		var title: Label = _wrapped(NewsDigest.title(item, _seed + i + 1), _headline_font, 14, INK)
		title.add_theme_constant_override(&"line_spacing", int(-2.0 * _scale))
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(title)
		var body: Label = _wrapped(NewsDigest.deck(item), null, 11, INK_SOFT)
		body.max_lines_visible = 3
		box.add_child(body)
	return row


## Alt şerit: KISA KISA etiketi + küçük haberler (yoksa gazetenin sloganı) + TAMAM.
func _footer(briefs: Array) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Footer"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", int(10.0 * _scale))
	_brief_list = PackedStringArray()
	for item: Variant in briefs:
		_brief_list.append(NewsDigest.brief(item as Dictionary).replace(" ", NBSP))
	var news: Label
	_briefs = null
	if _brief_list.is_empty():
		news = _text(Loc.t("Yarın yine buradayız. Gazeteni kaçırma!"), _italic_font, 11, INK_SOFT)
	else:
		var tag: Control = _tag(Loc.t("KISA KISA"), 10)
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(tag)
		news = _wrapped(_join_briefs(_brief_list), _bold_font, 11, INK)
		news.max_lines_visible = 2
		_briefs = news
	news.name = "Briefs"
	news.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	news.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(news)
	row.add_child(_ok)
	return row


## Fotoğraf: beyaz kenarlı baskı. Büyük (manşet) ya da küçük (sütun); içerik haberin türünden.
func _photo(item: Dictionary, area: Vector2, large: bool) -> Control:
	var frame: PanelContainer = PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.border_color = Color(INK, 0.25)
	style.set_border_width_all(1)
	style.set_content_margin_all(4.0 * _scale if large else 2.0)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.16)
	style.shadow_size = 3 if large else 1
	style.shadow_offset = Vector2(1.0, 2.0)
	frame.add_theme_stylebox_override(&"panel", style)
	var stack: MarginContainer = MarginContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.custom_minimum_size = area
	stack.clip_contents = true
	frame.add_child(stack)

	var kind: StringName = StringName(item.get("kind", &""))
	var people: Array = item.get("people", [])
	var backdrop: _Backdrop = _Backdrop.new()
	backdrop.warm = kind == NewsDigest.EARNINGS
	stack.add_child(backdrop)
	match kind:
		NewsDigest.EARNINGS:
			stack.add_child(_MoneyPile.new())
			_money_photo = frame
		NewsDigest.RACE_LOST, NewsDigest.RACE_WON, NewsDigest.MOD_READY:
			if large or people.is_empty():
				stack.add_child(_car_picture(StringName(item.get("car", &""))))
			if not people.is_empty():
				var avatar: AvatarView = _avatar(people[0] as Dictionary, (54.0 * _scale) if large else area.y - 4.0)
				if large:
					_corner(stack, avatar, 6.0 * _scale)
				else:
					_centered(stack, avatar)
		NewsDigest.GIFT, NewsDigest.ASK, NewsDigest.PILES:
			var parts: Array[StringName] = []
			if kind == NewsDigest.PILES:
				parts = [&"bolt", &"gear", &"spark_plug"]
			elif kind == NewsDigest.ASK:
				parts = [StringName(item.get("part", &"bolt"))]
			else:
				for part: Variant in (item.get("parts", {}) as Dictionary):
					parts.append(StringName(part))
			if large or people.is_empty():
				_centered(stack, _part_row(parts.slice(0, 3), area.y * (0.62 if large else 0.8)))
			if not people.is_empty():
				var avatar: AvatarView = _avatar(people[0] as Dictionary, (54.0 * _scale) if large else area.y - 4.0)
				if large:
					_corner(stack, avatar, 6.0 * _scale)
				else:
					_centered(stack, avatar)
		NewsDigest.GARAGE_BUILT, NewsDigest.GARAGE_UPGRADED, NewsDigest.FRIEND_GARAGE:
			if large or people.is_empty():
				var garage_icon: HudIcon = HudIcon.new()
				garage_icon.kind = HudIcon.Kind.GARAGE
				garage_icon.icon_size = area.y * (0.55 if large else 0.5)
				garage_icon.custom_minimum_size = Vector2.ONE * area.y * (0.65 if large else 0.6)
				_centered(stack, garage_icon)
			if not people.is_empty():
				var avatar: AvatarView = _avatar(people[0] as Dictionary, (54.0 * _scale) if large else area.y - 4.0)
				if large:
					_corner(stack, avatar, 6.0 * _scale)
				else:
					_centered(stack, avatar)
		NewsDigest.VISIT, NewsDigest.FRIEND_NEW, NewsDigest.FRIEND_REQUEST:
			var group: HBoxContainer = HBoxContainer.new()
			group.mouse_filter = Control.MOUSE_FILTER_IGNORE
			group.add_theme_constant_override(&"separation", int(-12.0 * _scale) if large else 0)
			var shown: int = mini(people.size(), 3 if large else 1)
			for i: int in shown:
				group.add_child(_avatar(people[i] as Dictionary, (84.0 * _scale) if large else area.y - 4.0))
			_centered(stack, group)
			if kind == NewsDigest.VISIT and int(item.get("likes", 0)) > 0:
				var heart: _Heart = _Heart.new()
				heart.custom_minimum_size = Vector2.ONE * (36.0 * _scale if large else 18.0)
				_corner(stack, heart, 4.0, true)
		_:
			var icon: HudIcon = HudIcon.new()
			icon.kind = HudIcon.Kind.CHECK
			icon.icon_size = area.y * 0.5
			icon.custom_minimum_size = Vector2.ONE * area.y * 0.6
			_centered(stack, icon)
	return frame


func _car_picture(car_id: StringName) -> TextureRect:
	var picture: TextureRect = TextureRect.new()
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var path: String = ProfileCard.THUMB_DIR + String(car_id) + ".png"
	if car_id != &"" and not CarCatalog.get_entry(car_id).is_empty() and ResourceLoader.exists(path):
		picture.texture = load(path) as Texture2D
	return picture


func _avatar(person: Dictionary, diameter: float) -> AvatarView:
	var avatar: AvatarView = AvatarView.new()
	avatar.custom_minimum_size = Vector2.ONE * diameter
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art: Dictionary = ProfileCard.avatar_for(get_tree(), person)
	avatar.show_avatar(art.get("texture"), bool(art.get("illustrated", true)), String(person.get("frame", "")),
		String(person.get("flag", "")) if diameter >= 40.0 else "")
	return avatar


func _part_row(parts: Array[StringName], icon: float) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", int(-icon * 0.15))
	for part: StringName in parts:
		var view: PartIcon = PartIcon.new()
		view.part_id = part
		view.custom_minimum_size = Vector2.ONE * (icon if parts.size() == 1 else icon * 0.78)
		row.add_child(view)
	return row


## `child` yığının ortasında (kendi boyunda).
func _centered(stack: Control, child: Control) -> void:
	child.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	child.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stack.add_child(child)


## `child` yığının sol alt (right: sağ üst) köşesinde, `pad` kadar içeride.
func _corner(stack: Control, child: Control, pad: float, right: bool = false) -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override(&"margin_" + side, int(pad))
	child.size_flags_horizontal = Control.SIZE_SHRINK_END if right else Control.SIZE_SHRINK_BEGIN
	child.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if right else Control.SIZE_SHRINK_END
	margin.add_child(child)
	stack.add_child(margin)


## Kırmızı zeminli küçük bölüm etiketi (SON DAKİKA, EKONOMİ…).
func _tag(text: String, font_size: int) -> Control:
	var holder: HBoxContainer = HBoxContainer.new()   # etiket satırı boyunca uzamasın
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tag: PanelContainer = PanelContainer.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = RED
	style.set_corner_radius_all(2)
	style.content_margin_left = 6.0 * _scale
	style.content_margin_right = 6.0 * _scale
	style.content_margin_top = 1.0
	style.content_margin_bottom = 1.0
	tag.add_theme_stylebox_override(&"panel", style)
	tag.add_child(_text(text, _bold_font, font_size, Color.WHITE))
	holder.add_child(tag)
	return holder


## Ana çizgi (kalın) ya da ara çizgi (ince).
func _rule(thickness: float) -> ColorRect:
	var line: ColorRect = ColorRect.new()
	line.color = RULE if thickness > 1.0 else Color(INK, 0.35)
	line.custom_minimum_size = Vector2(0.0, maxf(1.0, roundf(thickness * _scale)))
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _text(text: String, font: Font, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font:
		label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", int(roundf(font_size * _scale)))
	label.add_theme_color_override(&"font_color", color)
	return label


func _wrapped(text: String, font: Font, font_size: int, color: Color) -> Label:
	var label: Label = _text(text, font, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(60.0, 0.0)   # sarılan yazı kapsayıcıdan genişlik alır (0 genişlikte harf harf dökülmesin)
	return label


# --- Çizimler -----------------------------------------------------------------------------------------

## Yarış bayrağı deseni: iki sıra siyah-beyaz kare.
class _Checker extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var cell: float = size.y * 0.5
		if cell <= 0.0:
			return
		var columns: int = ceili(size.x / cell)
		for row: int in 2:
			for col: int in columns:
				if (row + col) % 2 == 0:
					draw_rect(Rect2(col * cell, row * cell, minf(cell, size.x - col * cell), cell), INK)


## Fotoğraf zemini: stüdyo gibi yukarıdan aşağı açılan renk + zeminde yumuşak gölge. `warm`: para fotoğrafı (sarı
## ışık hüzmeleri).
class _Backdrop extends Control:
	var warm: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var top: Color = Color("FFE7A6") if warm else Color("CFE3EC")
		var bottom: Color = Color("F7C25A") if warm else Color("EEF2EA")
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)]),
			PackedColorArray([top, top, bottom, bottom]))
		if warm:
			var center: Vector2 = Vector2(size.x * 0.5, size.y * 0.62)
			var radius: float = size.length()
			for i: int in 12:
				var a: float = TAU / 12.0 * float(i)
				draw_colored_polygon(PackedVector2Array([center, center + Vector2.from_angle(a) * radius,
					center + Vector2.from_angle(a + TAU / 24.0) * radius]), Color(1.0, 1.0, 1.0, 0.22))
		else:
			var floor_y: float = size.y * 0.82
			draw_set_transform(Vector2(size.x * 0.5, floor_y), 0.0, Vector2(1.0, 0.18))
			draw_circle(Vector2.ZERO, size.x * 0.36, Color(0.0, 0.0, 0.0, 0.1))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Para fotoğrafı: üst üste yığılmış altınlar (HudIcon'un para ikonu, her biri hafif dönük).
class _MoneyPile extends Control:
	const ROWS: Array[int] = [6, 5, 4, 3, 2]

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var coin: float = minf(size.y * 0.3, size.x * 0.13)
		var base_y: float = size.y * 0.86 - coin * 0.5
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 77
		for r: int in ROWS.size():
			var count: int = ROWS[r]
			var y: float = base_y - float(r) * coin * 0.42
			for i: int in count:
				var x: float = size.x * 0.5 + (float(i) - float(count - 1) * 0.5) * coin * 0.72
				draw_set_transform(Vector2(x, y) + Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0)),
					rng.randf_range(-0.35, 0.35), Vector2.ONE)
				HudIcon.draw_icon(self, HudIcon.Kind.COIN, Vector2.ZERO, coin, HudPalette.INK, HudPalette.PLATE)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Beğeni kalbi (yazı tipinde ❤ yok: sistem yazı tipi taranmasın diye kodla çizilir).
class _Heart extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s: float = minf(size.x, size.y)
		var c: Vector2 = size * 0.5
		var points: PackedVector2Array = PackedVector2Array()
		for i: int in 40:
			var t: float = TAU * float(i) / 40.0
			# klasik kalp eğrisi, [-1, 1] kareye ölçekli
			var x: float = 16.0 * pow(sin(t), 3.0)
			var y: float = -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
			points.append(c + Vector2(x, y + 2.0) / 17.0 * s * 0.5)
		var outline: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in points:
			outline.append(c + (p - c) * 1.18)
		draw_colored_polygon(outline, Color.WHITE)
		draw_colored_polygon(points, RED)
		draw_circle(c + Vector2(-0.2, -0.18) * s, s * 0.08, Color(1.0, 1.0, 1.0, 0.6))
