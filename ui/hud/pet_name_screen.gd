class_name PetNameScreen
extends Control
## GARAJ DOSTLARI — kediye AD KOYMA ekranı (kullanıcı kararı 2026-10-31: taslak "Ad 2 · Altın künye"). Kırmızı tasmaya
## asılı altın künyenin üstünde yazılan ad canlı görünür; altında ad alanı, rastgele ad zarı ve TAMAM. Telefon klavyesi
## alt yarıyı kapladığı için her şey ekranın ÜST yarısındadır. UiRouter'da MODAL "pet_name" (yakın kameranın üstüne açılır).
##   mandatory = true  → geliş sinematiği: ad ZORUNLU, kapatılamaz (GERİ yok, Android GERİ'si de kapatmaz)
##   mandatory = false → yakın kameradaki kartın kalemi: adı değiştirir, GERİ ile vazgeçilir
## Ad süzgeci SocialNames'tir (uygunsuz kök / kelime, harf kümesi); 2–14 karakter.
## ÜCRET (2026-11-03): her hayvanın ilk adı ücretsiz, sonrası PetManager.RENAME_GEMS. Açan taraf cost_gems'i verir;
## ücretliyse TAMAM "DEĞİŞTİR · 100" (elmas simgesi) olur, elmas yetmezse ad değişmez, MARKET açılır. Elması
## PetManager.rename düşer (burada yalnız gösterim ve ön denetim).

signal closed
## Geçerli ad onaylandı (PetManager.adopt çağıran taraftadır).
signal named(pet_name: String)

const NAME_MIN: int = 2
const NAME_RE: String = "^[A-Za-z0-9ÇĞİÖŞÜçğıöşüÂâÎîÛû ._-]+$"
## Rastgele ad zarı (TR sokak kedisi adları; dile göre değişmez — ad oyuncunundur).
const SUGGESTIONS: PackedStringArray = ["Tekir", "Sarman", "Paşa", "Duman", "Bıdık", "Zeytin", "Pamuk", "Karamel",
	"Fıstık", "Boncuk", "Limon", "Şeker", "Maviş", "Minnoş", "Tarçın", "Çakıl"]

var mandatory: bool = true
var start_name: String = ""
## Boş değilse başlık bu (HAYVANLAR ekranında yeni alınan kedi: "Yeni kedine ad ver"); bir açılışlık, kapanınca silinir.
var title_text: String = ""
## Bu ad değişikliğinin elmas ücreti (0 = ücretsiz ilk ad); bir açılışlık.
var cost_gems: int = 0
var _cost: int = 0

var _column: VBoxContainer
var _tag: _Tag
var _title: Label
var _subtitle: Label
var _edit: LineEdit
var _dice: PlateButton
var _ok: PlateButton
var _back: PlateButton
var _error: Label


func _ready() -> void:
	name = "PetNameScreen"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func open() -> void:
	_title.text = title_text if title_text != "" else \
		(Loc.t("Garajına bir kedi yerleşti!") if mandatory else Loc.t("Adını değiştir"))
	title_text = ""
	_cost = cost_gems
	cost_gems = 0
	_subtitle.text = Loc.t("Künyesine adını yaz.") + "\n" + (Loc.t("Ad değiştirmek %d GEM.") % _cost if _cost > 0
		else Loc.t("İlk ad ücretsiz, sonra değiştirmek %d GEM.") % PetManager.RENAME_GEMS)
	_ok.kind = HudIcon.Kind.GEM if _cost > 0 else HudIcon.Kind.NONE
	_ok.icon_left = true
	_ok.icon_size = 16.0
	_ok.text = Loc.t("DEĞİŞTİR · %d") % _cost if _cost > 0 else Loc.t("TAMAM")
	_back.visible = not mandatory
	_edit.text = start_name
	_error.text = ""
	_on_text_changed(_edit.text)
	show()
	PlateAnim.pop_in(self, _column)
	_edit.grab_focus.call_deferred()


## Gelişte ad zorunlu: GERİ / ESC kapatmaz (UiRouter.back sorar).
func blocks_back() -> bool:
	return visible and mandatory


func close() -> void:
	if not visible:
		return
	_edit.release_focus()
	PlateAnim.pop_out(self, _column, func() -> void:
		hide()
		closed.emit())



# --- Kurulum ------------------------------------------------------------------------------------

func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.04, 0.05, 0.07, 0.25)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 18)
	add_child(margin)
	var split: HBoxContainer = HBoxContainer.new()
	split.mouse_filter = Control.MOUSE_FILTER_IGNORE
	split.add_theme_constant_override(&"separation", 24)
	margin.add_child(split)
	# Sol: tasma + künye + ad satırı (ekranın üst yarısı)
	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override(&"separation", 8)
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.size_flags_stretch_ratio = 1.1
	split.add_child(_column)
	_tag = _Tag.new()
	_tag.custom_minimum_size = Vector2(0.0, 196.0)
	_column.add_child(_tag)
	var row: PanelContainer = PanelContainer.new()
	row.add_theme_stylebox_override(&"panel", PetCloseupScreen.plate_box())
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	_column.add_child(row)
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 8)
	row.add_child(line)
	_edit = LineEdit.new()
	_edit.max_length = PetManager.NAME_MAX
	_edit.placeholder_text = Loc.t("Ad yaz…")
	_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit.custom_minimum_size = Vector2(0.0, 48.0)
	_edit.add_theme_font_size_override(&"font_size", 22)
	_edit.add_theme_color_override(&"font_color", HudPalette.INK)
	_edit.add_theme_color_override(&"font_placeholder_color", HudPalette.INK_SOFT)
	_edit.add_theme_color_override(&"caret_color", HudPalette.INK)
	var field: StyleBoxFlat = StyleBoxFlat.new()
	field.bg_color = Color("FFFDF6")
	field.border_color = HudPalette.INK
	field.set_border_width_all(3)
	field.set_corner_radius_all(8)
	field.content_margin_left = 12.0
	field.content_margin_right = 12.0
	_edit.add_theme_stylebox_override(&"normal", field)
	_edit.add_theme_stylebox_override(&"focus", field)
	_edit.text_changed.connect(_on_text_changed)
	_edit.text_submitted.connect(func(_t: String) -> void: _confirm())
	line.add_child(_edit)
	_dice = PlateButton.new()
	_dice.theme_type_variation = &"HudPlateSmall"
	_dice.text = Loc.t("ZAR")
	_dice.tooltip_text = Loc.t("Rastgele ad")
	_dice.focus_mode = Control.FOCUS_NONE
	_dice.pressed.connect(_roll)
	line.add_child(_dice)
	_ok = PlateButton.new()
	_ok.theme_type_variation = &"HudPlateSmall"
	_ok.text = Loc.t("TAMAM")
	_ok.highlight = true
	_ok.focus_mode = Control.FOCUS_NONE
	_ok.pressed.connect(_confirm)
	line.add_child(_ok)
	_error = Label.new()
	_error.theme_type_variation = &"HudOutlined"
	_error.add_theme_color_override(&"font_color", Color("FFB4A8"))
	_error.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_error)
	# Sağ: başlık ve (ad değiştirirken) GERİ
	var right: VBoxContainer = VBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override(&"separation", 4)
	split.add_child(right)
	_back = PlateButton.new()
	_back.shape = PlateButton.Shape.ROUND
	_back.theme_type_variation = &"HudSign"
	_back.kind = HudIcon.Kind.CROSS
	_back.size_flags_horizontal = Control.SIZE_SHRINK_END
	_back.focus_mode = Control.FOCUS_NONE
	_back.pressed.connect(close)
	right.add_child(_back)
	_title = Label.new()
	_title.theme_type_variation = &"HudOutlinedLarge"
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_title)
	_subtitle = Label.new()
	_subtitle.theme_type_variation = &"HudOutlined"
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_subtitle)


# --- Ad ------------------------------------------------------------------------------------------

static func clean(raw: String) -> String:
	return SocialNames.clean_name(raw).substr(0, PetManager.NAME_MAX)


## Geçerliyse "" , değilse oyuncuya gösterilecek neden.
static func problem(raw: String) -> String:
	var name_text: String = clean(raw)
	if name_text.length() < NAME_MIN:
		return Loc.t("Ad en az 2 harf olmalı")
	if RegEx.create_from_string(NAME_RE).search(name_text) == null:
		return Loc.t("Adda yalnız harf ve rakam olabilir")
	if SocialNames.is_blocked(name_text):
		return Loc.t("Bu ad uygun değil")
	return ""


func _on_text_changed(text: String) -> void:
	_tag.set_name_text(clean(text))
	_ok.disabled = clean(text).length() < NAME_MIN
	_error.text = ""


func _roll() -> void:
	var current: String = clean(_edit.text)
	var pick: String = current
	while pick == current:
		pick = SUGGESTIONS[randi() % SUGGESTIONS.size()]
	_edit.text = pick
	_edit.caret_column = pick.length()
	_on_text_changed(pick)


func _confirm() -> void:
	var why: String = problem(_edit.text)
	if not why.is_empty():
		_error.text = why
		return
	if _cost > 0 and clean(_edit.text) != clean(start_name):
		var player: PlayerProgress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress
		if player == null or not player.can_afford_gems(_cost):
			_error.text = Loc.t("GEM YETMİYOR\n%d GEM gerekiyor, %d GEM'in var.") % [_cost, player.gems if player else 0]
			var router: UiRouter = get_tree().get_first_node_in_group("ui_router") as UiRouter
			if router:
				router.open(&"gem_store")   # MODAL: ad ekranı kapanır, altındaki ekran (yakın kamera / HAYVANLAR) kalır
			return
	named.emit(clean(_edit.text))
	close()


## Tasma yayı + altın künye (adı canlı yazar). Yalnız çizim, dokunmaz.
class _Tag extends Control:
	var _name: String = ""

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_name_text(text: String) -> void:
		_name = text
		queue_redraw()

	func _draw() -> void:
		var w: float = size.x
		var center_x: float = minf(w * 0.5, 300.0)
		# Tasma: üstten sarkan kırmızı yay
		var pts: PackedVector2Array = PackedVector2Array()
		for i: int in 33:
			var u: float = float(i) / 32.0
			var x: float = lerpf(center_x - 260.0, center_x + 260.0, u)
			pts.append(Vector2(x, -10.0 + 70.0 * 4.0 * u * (1.0 - u)))
		draw_polyline(pts, HudPalette.INK, 30.0, true)
		draw_polyline(pts, Color("C8463A"), 22.0, true)
		# Halka + künye
		var ring_c: Vector2 = Vector2(center_x, 64.0)
		draw_arc(ring_c, 11.0, 0.0, TAU, 24, HudPalette.INK, 6.0, true)
		draw_arc(ring_c, 11.0, 0.0, TAU, 24, Color("E2B341"), 2.5, true)
		var tag_c: Vector2 = Vector2(center_x, 64.0 + 11.0 + 62.0)
		draw_circle(tag_c + Vector2(0.0, 6.0), 64.0, HudPalette.SHADOW, true, -1.0, true)
		draw_circle(tag_c, 64.0, HudPalette.INK, true, -1.0, true)
		draw_circle(tag_c, 60.0, Color("B27A1C"), true, -1.0, true)
		draw_circle(tag_c + Vector2(0.0, -3.0), 57.0, Color("E2B341"), true, -1.0, true)
		draw_arc(tag_c + Vector2(0.0, -3.0), 50.0, PI * 1.1, PI * 1.9, 20, Color("F5D985"), 4.0, true)
		var font: Font = get_theme_default_font()
		var small: int = 11
		var caption: String = Loc.t("GARAJIN KEDİSİ")
		var cw: float = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x
		draw_string(font, tag_c + Vector2(-cw * 0.5, -22.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, small, Color("7A5414"))
		var text: String = _name.to_upper() if not _name.is_empty() else "…"
		var size_px: int = 32
		var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		while tw > 104.0 and size_px > 14:
			size_px -= 2
			tw = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		draw_string(font, tag_c + Vector2(-tw * 0.5, 14.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color("5C3E0E"))
