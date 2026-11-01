class_name JunkyardPostcard
extends Control
## HURDALIK KARTPOSTALI — günün aracına dokununca açılan, ÇİFT YÜZLÜ eski kartpostal (JunkyardScreen'in araç panosu).
##   * ÖN YÜZ: aracın RESTORE EDİLMİŞ hâli, kademesinin manzarasında; sararmış, hafif kırışık, ortadan katlanmış
##     eski bir fotoğraf (resim önceden pişirilir: tools/postcards/build.sh → assets/ui/postcards/<id>.jpg).
##     Üstünde el yazısı not, retro harflerle modelin adı, pul (sınıf + yıl) ve Hurdacı Necati damgası.
##   * ARKA YÜZ: solda Necati'nin el yazısıyla notu ve imzası, sağda adres satırlarına yazılmış gibi GEREKEN
##     PARÇALAR (eldeki / gereken). Sağ alttaki kıvrık köşe (ÇEVİR) iki yüz arasında döndürür.
## Kart sabit TASARIM boyunda (SIZE, tuval birimi) kurulur; ekrana sığdırma `fit` ölçeğiyle yapılır, içerik
## konteynerlerle yerleşir. Yazı tipleri: Caveat (el yazısı) + Alfa Slab One (retro başlık), ikisi de SIL OFL
## (ui/theme/fonts/OFL_*.txt). Kağıt (kesik köşeli çokgen) ve gölge burada çizilir; kırışık, kenar kararması ve kıvrık
## köşe ortak bir saydam katmandır (kirisik.png, arka yüzde aynalı).

## Yüz değişti (ÇEVİR köşesi ya da flip()); JunkyardScreen alttaki düğmenin adını günceller.
signal face_changed(back: bool)

const SIZE: Vector2 = Vector2(637.0, 370.0)      # oran 860:500 (fotoğraf 1242x702 + kağıt kenarı)
const BORDER: float = 12.0                        # kağıt kenarı (16/860)
const CUT: float = 22.0                           # kesik köşe (30/860): fotoğrafa değmez
const PHOTO_DIR: String = "res://assets/ui/postcards/"
const OVERLAY_PATH: String = "res://assets/ui/postcards/kirisik.png"
const HAND_FONT_PATH: String = "res://ui/theme/fonts/Caveat-Variable.ttf"
const SLAB_FONT_PATH: String = "res://ui/theme/fonts/AlfaSlabOne-Regular.ttf"
const FRONT_ANGLE: float = -1.5
const BACK_ANGLE: float = 1.5

const PAPER_FRONT: Color = Color("EADCBA")
const PAPER_BACK: Color = Color("EFE2C2")
const CREAM: Color = Color("FBF0D8")
const TITLE_FILL: Color = Color("E9B54E")
const TITLE_EDGE: Color = Color("3B3026")
const INK_BLUE: Color = Color("2E4A86")          # dolma kalem
const INK_DONE: Color = Color("2F7A3A")          # parça tamam
const MUTED: Color = Color("7D725F")             # basılı küçük yazı
const RULE: Color = Color("CBB68C")              # adres satırı
const POST_INK: Color = Color("3A2E22")          # damga mürekkebi
const TIER_STAMP: Dictionary = {&"basic": Color("B85C44"), &"classic": Color("3E6E86"), &"race": Color("3B5E44")}

## Necati'nin notları (araca göre sabit seçilir). Ad geçmez: Türkçe ekler (Miruna'yı / Böcük'ü) araçtan araca değişir.
const NOTES: Array[String] = [
	"Evlat,\nBunu ilk gördüğümde aklım gitmişti. Pasını sök, motorunu toparla, gerisi sabır.\nGarajında yeniden parlasın!",
	"Evlat,\nBu araba gençliğimde mahallenin gözdesiydi. Doğru parçaları bulursan o günlere döner.\nŞimdiden eline sağlık!",
	"Evlat,\nYıllardır bu sahada sahibini bekliyor. Parçalarını tamamla, gerisini o halleder.\nYolun açık olsun!",
	"Evlat,\nHurda deme sakın, bu kaportanın altında bir klasik uyuyor. Sabırla toparla, pişman olmazsın.\nKolay gelsin!",
]
const NOTE_WIDTH: float = 236.0
const NOTE_HEIGHT: float = 214.0   # notun sığması gereken yükseklik (uzun dillerde yazı küçülür)
const TITLE_MAX: int = 64
const TITLE_RESERVE: float = 192.0   # başlığın sağında pul + damga + dalgalı çizgilere kalan pay

static var _hand_cache: Dictionary = {}   # kalınlık → FontVariation

## Ekrana sığdırma ölçeği (JunkyardScreen verir). Döndürme / açılış animasyonları bunun üstüne çarpılır.
var fit: float = 1.0:
	set(value):
		fit = value
		_apply_scale()

var _back: bool = false
var _squash: float = 1.0   # çevirirken yatay daralma (1 → 0 → 1)
var _pop: float = 1.0      # açılışta hafif büyükten oturma
var _tween: Tween
var _front_face: Control
var _back_face: Control
var _photo: TextureRect
var _hand_line: Label
var _title: Label
var _caption: Label
var _front_stamp: Stamp
var _back_stamp: Stamp
var _front_mark: Postmark
var _back_mark: Postmark
var _back_caption: Label
var _note: Label
var _signature: Label
var _hint: Label
var _back_class: Label
var _back_tier: Label
var _parts_grid: GridContainer
var _spaced: FontVariation


## Karta dokunup (kaydırmadan) bırakmak kartı çevirir; bu kadar kayma (tasarım birimi) hâlâ dokunuştur.
const TAP_SLOP: float = 14.0

## "İŞ ALINDI" mührü vurulurken kart çevrilmez (JunkyardScreen._stamp).
var locked: bool = false
var _press_at: Vector2 = Vector2.ZERO
var _pressing: bool = false


static func photo_path(id: StringName) -> String:
	return PHOTO_DIR + String(id) + ".jpg"


static func hand_font(weight: int) -> FontVariation:
	if _hand_cache.has(weight):
		return _hand_cache[weight]
	var font: FontVariation = FontVariation.new()
	font.base_font = load(HAND_FONT_PATH) as FontFile
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	_hand_cache[weight] = font
	return font


## Kartpostalın büyük başlığı: model adı; çok kısa modelde (MV, 44, RS 30) marka da yazılır.
static func title_for(brand: String, model: String) -> String:
	var letters: int = 0
	for i: int in model.length():
		var c: String = model[i]
		if c.to_upper() != c.to_lower():
			letters += 1
	return model if letters >= 3 else ("%s %s" % [brand, model]).strip_edges()


## Not aracın kimliğine göre sabit seçilir (her açılışta aynı not).
static func note_for(id: StringName) -> String:
	return NOTES[absi(hash(String(id))) % NOTES.size()]


func _ready() -> void:
	size = SIZE
	pivot_offset = SIZE * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP   # karta dokunmak karartmaya geçip panoyu kapatmasın
	_spaced = FontVariation.new()
	_spaced.base_font = get_theme_font(&"font", &"HudInkCaption")
	_spaced.spacing_glyph = 2
	_build_front()
	_build_back()
	rotation = deg_to_rad(FRONT_ANGLE)


# --- İçerik ----------------------------------------------------------------------------------------

## Kartı araca göre doldurur. `have`: parça → eldeki adet; `free_bay`: garajda boş tamir alanı var mı.
func show_car(id: StringName, have: Dictionary, free_bay: bool) -> void:
	var entry: Dictionary = CarCatalog.get_entry(id)
	var plan: Dictionary = RestorationCatalog.get_entry(id)
	var brand: String = String(entry.get("brand", "")).to_upper()
	var model: String = String(entry.get("model", plan.get("name", id))).to_upper()
	var year: int = int(plan.get("year", 0))
	var car_class: String = String(entry.get("class", plan.get("class", "?")))
	var class_text: String = Loc.t("%s SINIFI") % car_class
	var tier_id: StringName = RestorationCatalog.tier_of(id)
	var tier_name: String = Loc.t(String(RestorationCatalog.tier(tier_id).get("name", "")))

	# Ön yüz
	var path: String = photo_path(id)
	_photo.texture = load(path) as Texture2D if ResourceLoader.exists(path) else _fallback_photo(id)
	_hand_line.text = Loc.t("Toparlarsan böyle olur!")
	var title: String = title_for(brand, model)
	_title.text = title
	_fit_title(title)
	_caption.text = "  ·  ".join(PackedStringArray([str(year), class_text]) if title.begins_with(brand) and brand != "" \
		else PackedStringArray([brand, str(year), class_text]))
	var thumb: Texture2D = _thumbnail(id)
	var stamp_color: Color = TIER_STAMP.get(tier_id, TIER_STAMP[&"classic"])
	for stamp: Stamp in [_front_stamp, _back_stamp]:
		stamp.setup(thumb, class_text, str(year), stamp_color)
	for mark: Postmark in [_front_mark, _back_mark]:
		mark.setup(Loc.t("HURDACI NECATİ · HURDALIK ·"), str(year))

	# Arka yüz
	_back_caption.text = ("%s %s  ·  %d" % [brand, model, year]).strip_edges()
	_note.text = Loc.t(note_for(id))
	_fit_note()
	_signature.text = Loc.t("— Hurdacı Necati")
	_back_class.text = class_text
	_back_tier.text = tier_name
	_hint.text = Loc.t("Garajda bir tamir alanına yerleşir. Parçaları orada takarsın.") if free_bay \
		else Loc.t("BOŞ TAMİR ALANI YOK — önce bir tamir işini bitir.")
	_hint.add_theme_color_override(&"font_color", HudPalette.INK_SOFT if free_bay else HudPalette.DANGER)
	for child: Node in _parts_grid.get_children():
		child.queue_free()
	var recipe: Dictionary = RestorationCatalog.recipe(id)
	for part_id: StringName in recipe:
		var need: int = int(recipe[part_id])
		_parts_grid.add_child(_part_line(part_id, mini(int(have.get(part_id, 0)), need), need))


## Kart ön yüzü dönük, düz açıyla açılır: hafif büyükten oturur, yamuk düşer (masaya atılmış gibi).
func toss_in() -> void:
	_set_back(false)
	if _tween:
		_tween.kill()
	_squash = 1.0
	modulate.a = 0.0
	rotation = deg_to_rad(FRONT_ANGLE - 5.0)
	_set_pop(1.07)
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, 0.12)
	_tween.tween_method(_set_pop, 1.07, 1.0, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "rotation", deg_to_rad(FRONT_ANGLE), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func is_back() -> bool:
	return _back


## Kartın herhangi bir yerine (fotoğraf / arka yüz) dokunmak da çevirir — yalnız köşe ya da alttaki düğme değil.
func _gui_input(event: InputEvent) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press == null or press.button_index != MOUSE_BUTTON_LEFT:
		return
	if press.pressed:
		_pressing = true
		_press_at = press.position
	elif _pressing:
		_pressing = false
		if not locked and press.position.distance_to(_press_at) < TAP_SLOP:
			flip()
	accept_event()


## Kartı çevirir: yatayda daralır, öteki yüz görünür, açılır.
func flip() -> void:
	if _tween:
		_tween.kill()
	modulate.a = 1.0   # açılış animasyonu yarıda kesildiyse kart soluk / büyük kalmasın
	_set_pop(1.0)
	var to_back: bool = not _back
	_tween = create_tween()
	_tween.tween_method(_set_squash, _squash, 0.0, 0.11).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(self, "rotation", 0.0, 0.11)
	_tween.tween_callback(func() -> void: _set_back(to_back))
	_tween.tween_method(_set_squash, 0.0, 1.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "rotation", deg_to_rad(BACK_ANGLE if to_back else FRONT_ANGLE), 0.14)


## "İŞ ALINDI" mührü vurulurken kart sarsılır (konum yerleşimden gelir; sonunda geri yazılır).
func shake() -> void:
	var origin: Vector2 = position
	var tween: Tween = create_tween()
	for k: int in 4:
		var push: float = 9.0 * (1.0 - k / 4.0) * (1.0 if k % 2 == 0 else -1.0)
		tween.tween_property(self, "position", origin + Vector2(push, push * 0.4), 0.04)
	tween.tween_property(self, "position", origin, 0.05)


func _set_back(back: bool) -> void:
	_back = back
	_front_face.visible = not back
	_back_face.visible = back
	queue_redraw()
	face_changed.emit(back)


func _set_squash(value: float) -> void:
	_squash = value
	_apply_scale()


func _set_pop(value: float) -> void:
	_pop = value
	_apply_scale()


func _apply_scale() -> void:
	scale = Vector2(fit * _pop * maxf(_squash, 0.001), fit * _pop)


# --- Çizim: gölge + kesik köşeli kağıt ------------------------------------------------------------

func _draw() -> void:
	var paper: PackedVector2Array = _paper_polygon()
	# yumuşak gölge: kat kat genişleyen, aşağı kaymış saydam kopyalar
	for i: int in 6:
		var grow: float = 1.5 + i * 2.2
		var shadow: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in paper:
			shadow.append(SIZE * 0.5 + (p - SIZE * 0.5) * (1.0 + grow / SIZE.x) + Vector2(0.0, 7.0 + i * 1.2))
		draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.07))
	draw_colored_polygon(paper, PAPER_BACK if _back else PAPER_FRONT)


## Ön yüzde sol üst, arkada (aynı köşe arkadan bakınca) sağ üst kesik.
func _paper_polygon() -> PackedVector2Array:
	var w: float = SIZE.x
	var h: float = SIZE.y
	if _back:
		return PackedVector2Array([Vector2(0.0, 0.0), Vector2(w - CUT, 0.0), Vector2(w, CUT), Vector2(w, h), Vector2(0.0, h)])
	return PackedVector2Array([Vector2(CUT, 0.0), Vector2(w, 0.0), Vector2(w, h), Vector2(0.0, h), Vector2(0.0, CUT)])


# --- Kurulum: ön yüz -------------------------------------------------------------------------------

func _build_front() -> void:
	_front_face = _face()
	var frame: MarginContainer = _margin(BORDER, BORDER, BORDER, BORDER)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_front_face.add_child(frame)
	var photo_box: Control = Control.new()
	photo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo_box.clip_contents = true
	frame.add_child(photo_box)
	_photo = TextureRect.new()
	_photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	photo_box.add_child(_photo)

	# Sol üst: el yazısı not + retro başlık + basılı alt satır (eski baskı: hafif soluk)
	var letters_margin: MarginContainer = _margin(16.0, 8.0, 0.0, 0.0)
	letters_margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	letters_margin.set_meta(&"qa_badge", true)   # fotoğrafın üstüne bilerek basılı (ekran taraması)
	photo_box.add_child(letters_margin)
	var letters: VBoxContainer = VBoxContainer.new()
	letters.mouse_filter = Control.MOUSE_FILTER_IGNORE
	letters.add_theme_constant_override(&"separation", -6)
	letters.modulate = Color(1.0, 0.96, 0.88, 0.94)
	letters_margin.add_child(letters)
	_hand_line = _text(hand_font(700), 26, CREAM)
	_shadowed(_hand_line, Color(0.16, 0.1, 0.04, 0.55), Vector2(0.0, 2.0), 3)
	letters.add_child(_hand_line)
	_title = _text(load(SLAB_FONT_PATH) as Font, TITLE_MAX, TITLE_FILL)
	_title.add_theme_color_override(&"font_outline_color", TITLE_EDGE)
	_title.add_theme_constant_override(&"outline_size", 5)
	_shadowed(_title, TITLE_EDGE, Vector2(0.0, 4.0), 5)
	letters.add_child(_title)
	_caption = _text(_spaced, 12, CREAM)
	_shadowed(_caption, Color(0.16, 0.1, 0.04, 0.6), Vector2(0.0, 1.0), 2)
	letters.add_child(_caption)

	_front_stamp = Stamp.new()
	_corner(_front_stamp, Vector2(77.0, 95.0), Vector2(15.0, 13.0))
	_front_stamp.rotation = deg_to_rad(3.0)
	_front_stamp.set_meta(&"qa_badge", true)
	photo_box.add_child(_front_stamp)
	_front_mark = Postmark.new()
	_front_mark.waves = true
	_corner(_front_mark, Vector2(86.0, 86.0), Vector2(62.0, 47.0))
	_front_mark.set_meta(&"qa_badge", true)
	photo_box.add_child(_front_mark)

	_front_face.add_child(_overlay(false))
	_front_face.add_child(_flip_corner())


# --- Kurulum: arka yüz -----------------------------------------------------------------------------

func _build_back() -> void:
	_back_face = _face()
	_back_face.visible = false
	var pad: MarginContainer = _margin(25.0, 22.0, 25.0, 22.0)
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_back_face.add_child(pad)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 14)
	pad.add_child(row)

	# Sol: Necati'nin notu
	var left: VBoxContainer = VBoxContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.custom_minimum_size = Vector2(NOTE_WIDTH, 0.0)
	left.add_theme_constant_override(&"separation", 2)
	row.add_child(left)
	_back_caption = _text(_spaced, 10, MUTED)
	left.add_child(_back_caption)
	_note = _text(hand_font(600), 23, INK_BLUE)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(NOTE_WIDTH, 0.0)
	_note.add_theme_constant_override(&"line_spacing", -4)
	left.add_child(_note)
	_signature = _text(hand_font(700), 24, INK_BLUE)
	_signature.size_flags_horizontal = Control.SIZE_SHRINK_END
	_signature.rotation = deg_to_rad(-3.0)
	left.add_child(_signature)
	var push: Control = Control.new()
	push.mouse_filter = Control.MOUSE_FILTER_IGNORE
	push.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(push)
	_hint = _text(null, 10, HudPalette.INK_SOFT)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(NOTE_WIDTH, 0.0)
	left.add_child(_hint)

	var divider: ColorRect = ColorRect.new()
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.color = RULE
	divider.custom_minimum_size = Vector2(1.5, 0.0)
	row.add_child(divider)

	# Sağ: pul, sınıf, adres satırlarında parçalar
	var right: VBoxContainer = VBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override(&"separation", 2)
	row.add_child(right)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.custom_minimum_size = Vector2(0.0, 100.0)
	right.add_child(top)
	var info: VBoxContainer = VBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override(&"separation", 2)
	top.add_child(info)
	info.add_child(_text(_spaced, 9, MUTED, Loc.t("KARTPOSTAL")))
	_back_class = _text(null, 10, HudPalette.INK_SOFT)
	info.add_child(_back_class)
	_back_tier = _text(null, 10, HudPalette.INK_SOFT)
	_back_tier.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # uzun dilde (MEISTER · RENNWAGEN) damgaya girmesin
	info.add_child(_back_tier)
	var mark_room: Control = Control.new()   # damganın yeri: yazı altına girmesin
	mark_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark_room.custom_minimum_size = Vector2(66.0, 0.0)
	top.add_child(mark_room)
	_back_stamp = Stamp.new()
	_back_stamp.custom_minimum_size = Vector2(77.0, 95.0)
	_back_stamp.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_back_stamp.rotation = deg_to_rad(-2.0)
	top.add_child(_back_stamp)
	right.add_child(_text(_spaced, 9, MUTED, Loc.t("GEREKEN PARÇALAR")))
	_parts_grid = GridContainer.new()
	_parts_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_parts_grid.columns = 2
	_parts_grid.add_theme_constant_override(&"h_separation", 12)
	_parts_grid.add_theme_constant_override(&"v_separation", 0)
	right.add_child(_parts_grid)

	_back_mark = Postmark.new()
	_corner(_back_mark, Vector2(86.0, 86.0), Vector2(72.0, 34.0))
	_back_mark.set_meta(&"qa_badge", true)
	_back_face.add_child(_back_mark)
	_back_face.add_child(_overlay(true))
	_back_face.add_child(_flip_corner())


## Adres satırı: ikon, parça adı, el yazısıyla eldeki/gereken; altında çizgi.
func _part_line(part_id: StringName, have: int, need: int) -> Control:
	var cell: VBoxContainer = VBoxContainer.new()
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_theme_constant_override(&"separation", 1)
	var line: HBoxContainer = HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.custom_minimum_size = Vector2(0.0, 40.0)
	line.alignment = BoxContainer.ALIGNMENT_END
	line.add_theme_constant_override(&"separation", 6)
	cell.add_child(line)
	var icon: PartIcon = PartIcon.new()
	icon.part_id = part_id
	icon.custom_minimum_size = Vector2(24.0, 24.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_END
	line.add_child(icon)
	var label: Label = _text(null, 10, HudPalette.INK, Loc.t(RestorationCatalog.part_name(part_id)))
	label.size_flags_vertical = Control.SIZE_SHRINK_END
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # uzun ad (FIBRE DE VERRE) iki satıra iner
	label.custom_minimum_size = Vector2(40.0, 0.0)
	line.add_child(label)
	var count: Label = _text(hand_font(700), 22, INK_DONE if have >= need else INK_BLUE, "%d/%d" % [have, need])
	count.size_flags_vertical = Control.SIZE_SHRINK_END
	line.add_child(count)
	var rule: ColorRect = ColorRect.new()
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.color = RULE
	rule.custom_minimum_size = Vector2(0.0, 1.5)
	cell.add_child(rule)
	return cell


# --- Yardımcılar -----------------------------------------------------------------------------------

func _face() -> Control:
	var face: Control = Control.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(face)
	return face


## Kırışık / kenar / kıvrık köşe katmanı; arka yüzde aynalı.
func _overlay(mirrored: bool) -> TextureRect:
	var layer: TextureRect = TextureRect.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_SCALE
	layer.flip_h = mirrored
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists(OVERLAY_PATH):
		layer.texture = load(OVERLAY_PATH) as Texture2D
	return layer


func _flip_corner() -> FlipCorner:
	var corner: FlipCorner = FlipCorner.new()
	corner.label = Loc.t("ÇEVİR")
	corner.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	corner.offset_left = -126.0
	corner.offset_top = -55.0
	corner.offset_right = 0.0
	corner.offset_bottom = 0.0
	corner.pressed.connect(flip)
	corner.set_meta(&"qa_badge", true)   # kartın köşesine bilerek biner
	return corner


## Sağ üst köşeye sabitlenen çizim (pul / damga): `inset` sağdan ve üstten uzaklık.
func _corner(control: Control, box: Vector2, inset: Vector2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	control.offset_left = -inset.x - box.x
	control.offset_right = -inset.x
	control.offset_top = inset.y
	control.offset_bottom = inset.y + box.y
	control.pivot_offset = box * 0.5


func _fit_title(title: String) -> void:
	var font: Font = _title.get_theme_font(&"font")
	var room: float = SIZE.x - BORDER * 2.0 - 16.0 - TITLE_RESERVE   # sol pay + pul, damga ve dalgaları
	var width: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_MAX).x
	_title.add_theme_font_size_override(&"font_size", TITLE_MAX if width <= room else maxi(int(TITLE_MAX * room / width), 30))


## Uzun dillerde (DE / FR) not sığmazsa el yazısı küçülür.
func _fit_note() -> void:
	var font: Font = _note.get_theme_font(&"font")
	var font_size: int = 23
	while font_size > 16:
		var height: float = font.get_multiline_string_size(_note.text, HORIZONTAL_ALIGNMENT_LEFT, NOTE_WIDTH, font_size).y
		if height <= NOTE_HEIGHT:
			break
		font_size -= 1
	_note.add_theme_font_size_override(&"font_size", font_size)


## Resmi pişirilmemiş araç (yeni eklenmiş, build.sh koşulmamış): küçük resmi kart zemininde gösterilir.
func _fallback_photo(id: StringName) -> Texture2D:
	return _thumbnail(id)


func _thumbnail(id: StringName) -> Texture2D:
	var path: String = ProfileCard.THUMB_DIR + String(id) + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _text(font: Font, font_size: int, color: Color, text: String = "") -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.theme_type_variation = &"HudInkCaption"
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # metin Loc.t'den geçti ya da özel ad
	if font:
		label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_constant_override(&"outline_size", 0)
	label.text = text
	return label


func _shadowed(label: Label, color: Color, offset: Vector2, outline: int) -> void:
	label.add_theme_color_override(&"font_shadow_color", color)
	label.add_theme_constant_override(&"shadow_offset_x", int(offset.x))
	label.add_theme_constant_override(&"shadow_offset_y", int(offset.y))
	label.add_theme_constant_override(&"shadow_outline_size", outline)


func _margin(left: float, top: float, right: float, bottom: float) -> MarginContainer:
	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override(&"margin_left", int(left))
	margin.add_theme_constant_override(&"margin_top", int(top))
	margin.add_theme_constant_override(&"margin_right", int(right))
	margin.add_theme_constant_override(&"margin_bottom", int(bottom))
	return margin


# --- Çizim parçaları -------------------------------------------------------------------------------

## Tırtıklı kenarlı pul: kademe rengi zemin, aracın küçük resmi, üstte sınıf, altta yıl. Eski: hafif sepya.
class Stamp extends Control:
	const PAPER: Color = Color("F1E6CA")
	const NOTCH: float = 3.2
	var _thumb: Texture2D
	var _top: String = ""
	var _bottom: String = ""
	var _color: Color = Color("3E6E86")

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		modulate = Color(1.0, 0.95, 0.84)

	func setup(thumb: Texture2D, top: String, bottom: String, color: Color) -> void:
		_thumb = thumb
		_top = top
		_bottom = bottom
		_color = color
		queue_redraw()

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		draw_colored_polygon(_scalloped(w, h), PAPER)
		var inner: Rect2 = Rect2(Vector2(5.0, 5.0), size - Vector2(10.0, 10.0))
		draw_rect(inner, _color)
		var font: Font = get_theme_font(&"font", &"HudInkCaption")
		var light: Color = Color("FBF0D8")
		_centered(font, _top, inner.position.y + 13.0, 8, light)
		_centered(font, _bottom, inner.end.y - 5.0, 9, Color("E9B54E"))
		if _thumb:
			var area: Rect2 = Rect2(inner.position + Vector2(3.0, 17.0), Vector2(inner.size.x - 6.0, inner.size.y - 36.0))
			var t: Vector2 = _thumb.get_size()
			var k: float = minf(area.size.x / t.x, area.size.y / t.y)
			var drawn: Vector2 = t * k
			draw_texture_rect(_thumb, Rect2(area.get_center() - drawn * 0.5, drawn), false)

	func _centered(font: Font, text: String, baseline: float, font_size: int, color: Color) -> void:
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, Vector2((size.x - width) * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

	## Kenarları yarım daire oyuklu dikdörtgen (içbükey çokgen; çizici üçgenler).
	func _scalloped(w: float, h: float) -> PackedVector2Array:
		var points: PackedVector2Array = PackedVector2Array()
		var corners: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(w, 0.0), Vector2(w, h), Vector2(0.0, h)]
		for side: int in 4:
			var a: Vector2 = corners[side]
			var b: Vector2 = corners[(side + 1) % 4]
			var length: float = a.distance_to(b)
			var dir: Vector2 = (b - a) / length
			var inward: Vector2 = Vector2(-dir.y, dir.x)
			var count: int = maxi(int(length / (NOTCH * 3.2)), 2)
			var step: float = length / count
			points.append(a)
			for i: int in count:
				var center: Vector2 = a + dir * (step * (i + 0.5))
				for k: int in 7:   # yarım daire oyuk (içe doğru)
					var angle: float = PI * k / 6.0
					points.append(center - dir * cos(angle) * NOTCH + inward * sin(angle) * NOTCH)
		return points


## Yuvarlak damga: dış ve iç halka, halka boyunca yazı, ortada yıl; ön yüzde solunda dalgalı çizgiler.
class Postmark extends Control:
	const INK: Color = Color(0.227, 0.18, 0.133, 0.55)
	var waves: bool = false
	var _ring: String = ""
	var _center: String = ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func setup(ring: String, center: String) -> void:
		_ring = ring
		_center = center
		queue_redraw()

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.5 - 2.0
		draw_arc(c, r, 0.0, TAU, 64, INK, 2.0, true)
		draw_arc(c, r * 0.64, 0.0, TAU, 48, Color(INK, 0.45), 1.2, true)
		var font: Font = get_theme_font(&"font", &"HudInkCaption")
		var ring_size: int = 7
		var ring_r: float = r * 0.82
		var total: float = 0.0
		for i: int in _ring.length():
			total += font.get_char_size(_ring.unicode_at(i), ring_size).x
		var spread: float = minf(total / ring_r, TAU * 0.97)   # yazının kapladığı açı
		var angle: float = -PI * 0.5 - spread * 0.5
		var scale_k: float = spread / maxf(total / ring_r, 0.001)
		for i: int in _ring.length():
			var advance: float = font.get_char_size(_ring.unicode_at(i), ring_size).x * scale_k
			var mid: float = angle + advance * 0.5 / ring_r
			draw_set_transform(c + Vector2(cos(mid), sin(mid)) * ring_r, mid + PI * 0.5)
			draw_char(font, Vector2(-advance * 0.5, ring_size * 0.35), _ring[i], ring_size, Color(INK, 0.9))
			angle += advance / ring_r
		draw_set_transform(Vector2.ZERO)
		var year_size: int = 12
		var width: float = font.get_string_size(_center, HORIZONTAL_ALIGNMENT_LEFT, -1, year_size).x
		draw_string(font, c + Vector2(-width * 0.5, year_size * 0.35), _center, HORIZONTAL_ALIGNMENT_LEFT, -1, year_size, Color(INK, 0.95))
		if waves:
			for k: int in 3:
				var points: PackedVector2Array = PackedVector2Array()
				var y: float = c.y + (k - 1) * 10.0
				for s: int in 25:
					var x: float = c.x - r - 34.0 + s * 1.4
					points.append(Vector2(x, y + sin(s * 0.55) * 2.2))
				draw_polyline(points, Color(INK, 0.75), 1.5, true)


## Sağ alt kıvrık köşe: kağıdın arkası görünür, üstünde ↻ ÇEVİR. Dokununca kart döner.
class FlipCorner extends Button:
	var label: String = ""

	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_STOP
		for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"focus"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var fold: PackedVector2Array = PackedVector2Array([Vector2(w, 0.0), Vector2(w, h), Vector2(0.0, h)])
		# kıvrımın gölgesi, sonra arka yüz kağıdı (alt köşeye doğru açılan)
		draw_colored_polygon(PackedVector2Array([Vector2(w, -4.0), Vector2(w, h), Vector2(-8.0, h)]), Color(0.16, 0.1, 0.04, 0.22))
		draw_polygon(fold, PackedColorArray([Color("E6D6B0"), Color("D6C39A"), Color("CDB98F")]))
		draw_line(Vector2(0.0, h), Vector2(w, 0.0), Color(0.45, 0.35, 0.2, 0.6), 1.2, true)
		var font: Font = get_theme_font(&"font", &"HudInkCaption")
		var font_size: int = 11
		var text: String = "↻ " + label
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var ink: Color = HudPalette.INK if not button_pressed and not is_hovered() else Color(HudPalette.INK, 0.75)
		draw_string(font, Vector2(w - width - 9.0, h - 9.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
