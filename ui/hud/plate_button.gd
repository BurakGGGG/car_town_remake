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
## icon_left: ikon ile yazı arası.
const ICON_LEFT_GAP: float = 7.0
## Cıvatalar yazının hizasında (üstte ikon yok) çizilen plakada yazının kenardan en az payı: cıvata x = 7
## (yarıçap 1,7). "HudPlate" teması 6 birim veriyor; plaka yazıya göre en dar boyundayken (HEPSİNİ TAK,
## EKSİKLERİ AL, İspanyolca uzun yazılar) cıvata ilk / son harfin üstüne biniyordu.
const BOLT_CLEAR: float = 13.0

@export var shape: Shape = Shape.PLATE:
	set(value):
		shape = value
		queue_redraw()

@export var kind: HudIcon.Kind = HudIcon.Kind.NONE:
	set(value):
		kind = value
		if is_inside_tree():
			_apply_styles()
		queue_redraw()

@export_range(8.0, 40.0, 1.0) var icon_size: float = 22.0:
	set(value):
		icon_size = value
		if is_inside_tree() and icon_left:
			_apply_styles()
		queue_redraw()

## İkon yazının SOLUNDA (yatay araç çubukları: GARAJI DÜZENLE). Kapalıyken (varsayılan) ikon yazının
## üstünde, temanın üst boşluğuna çizilir — küçük plakalarda o boşluk yok. Açıkken sol kenar payı ikon
## kadar genişler; stiller her yeniden kurulduğunda (highlight / kind) aynı pay yeniden eklenir.
@export var icon_left: bool = false:
	set(value):
		icon_left = value
		if is_inside_tree():
			_apply_styles()
		queue_redraw()

## Plakanın köşelerindeki cıvata noktaları.
@export var bolts: bool = true:
	set(value):
		bolts = value
		if is_inside_tree():
			_apply_styles()
		queue_redraw()

## Seçili/basılı plaka bu kadar piksel yukarı kalkar (temadaki expand_margin_top ile aynı olmalı).
@export var lift_when_pressed: float = 3.0

## Ayarlıysa ikon yerine plakaya küçük bir fotoğraf basılır (ehliyet fotoğrafı gibi).
@export var avatar: Texture2D:
	set(value):
		avatar = value
		if is_inside_tree():
			_apply_styles()
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
			_apply_styles()


## Sağ üst köşede kırmızı sayı rozeti (0 = yok; ör. MAĞAZA sekmesinde yoldaki kasa sayısı). Kayda girmez.
var badge: int = 0:
	set(value):
		badge = maxi(value, 0)
		queue_redraw()

## Taban nedeniyle büyüyen yuvarlak tabelada ikonun büyütme oranı (1 = değişmedi).
var _icon_scale: float = 1.0


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	_apply_styles()
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
	# Dokunma alanı EKRANDA MIN_TOUCH kalır: HUD boyutu küçükken (ata ölçeği < 1) yerel pay büyür
	var touch: float = MIN_TOUCH / maxf(get_global_transform().get_scale().x, 0.01)
	var slop: Vector2 = ((Vector2(touch, touch) - size) * 0.5).max(Vector2.ZERO)
	if slop == Vector2.ZERO or not own.grow_individual(slop.x, slop.y, slop.x, slop.y).has_point(point):
		return false
	# Kenar payları çakışınca (yan yana tabelalar, alt alta menü plakaları) nokta, görünür
	# dikdörtgeni EN YAKIN düğmenin olur; yoksa ağaçta sonra gelen hep kazanırdı ve plakalar
	# arasındaki boşluğa dokunmak aşağıdakini açardı. Dikdörtgenler ekrandaki (ölçekli) hâliyle.
	var at: Vector2 = get_global_transform() * point
	var mine: float = _distance(_on_screen(self), at)
	for node: Node in get_tree().get_nodes_in_group(GROUP):
		var other: Control = node as Control
		if other == self or not other.is_visible_in_tree():
			continue
		if _distance(_on_screen(other), at) < mine:
			return false
	return true


## get_global_rect ata ölçeğini (HUD boyutu) yok sayar; bu ölçekli dikdörtgeni verir.
static func _on_screen(control: Control) -> Rect2:
	return control.get_global_transform() * Rect2(Vector2.ZERO, control.size)


static func _distance(rect: Rect2, point: Vector2) -> float:
	var dx: float = maxf(maxf(rect.position.x - point.x, point.x - rect.end.x), 0.0)
	var dy: float = maxf(maxf(rect.position.y - point.y, point.y - rect.end.y), 0.0)
	return Vector2(dx, dy).length()


## Tema stilinin bu düğmeye özel kopyası, iki durumda:
##  - highlight: amber (seçili plaka rengi) zemin.
##  - İKONSUZ "HudPlate" plakası: bu varyasyon üstte ikon için ~26 birim ayırıyor (alt 8); ikon
##    yoksa yazı plakanın altına yapışıyordu (eğitim kartı BAŞLAYALIM, yarış sonucu düğmeleri — 2026-10-11
##    QA). Üst/alt pay eşitlenir, yazı ortalanır. Yalnızca oyunda (editörde .tscn'e yazılmasın).
func _apply_styles() -> void:
	# YALNIZCA "HudPlate": galeri / koleksiyon gibi kendi küçük resmini çizen varyasyonlar üst payı BİLEREK
	# büyük tutar (yazı resmin altında); onlara dokunulursa yazı resmin üstüne biner (2026-10-11 QA'da oldu).
	var side_icon: bool = icon_left and shape == Shape.PLATE and kind != HudIcon.Kind.NONE
	var center: bool = not Engine.is_editor_hint() and shape == Shape.PLATE \
		and theme_type_variation == &"HudPlate" and (side_icon or kind == HudIcon.Kind.NONE) and avatar == null
	# Cıvatalar yazı hizasında mı (üstte ikon yok): yazı onlardan BOLT_CLEAR kadar içeride başlar
	var mid_bolts: bool = not Engine.is_editor_hint() and bolts and shape == Shape.PLATE \
		and (side_icon or (kind == HudIcon.Kind.NONE and avatar == null))
	# Toplu: her ekleme / silme ayrı tema bildirimi ve boyut hesabı tetikliyordu (açılışta 167 düğme, ~25 ms)
	begin_bulk_theme_override()
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		if has_theme_stylebox_override(state):
			remove_theme_stylebox_override(state)
		var base: StyleBoxFlat = get_theme_stylebox(state) as StyleBoxFlat
		if base == null:
			continue
		var amber: bool = highlight and state != &"disabled"
		var lopsided: bool = center and base.content_margin_top - base.content_margin_bottom > 6.0
		var tight: bool = mid_bolts and (base.content_margin_right < BOLT_CLEAR \
			or base.content_margin_left < BOLT_CLEAR)
		if not amber and not lopsided and not side_icon and not tight:
			continue
		var box: StyleBoxFlat = base.duplicate() as StyleBoxFlat
		if tight:   # yandaki ikon da cıvatanın içinden başlar (aşağıda ikon payı bunun üstüne eklenir)
			box.content_margin_right = maxf(box.content_margin_right, BOLT_CLEAR)
			box.content_margin_left = maxf(box.content_margin_left, BOLT_CLEAR)
		if side_icon:
			box.content_margin_left += icon_size + ICON_LEFT_GAP
		if amber:
			box.bg_color = HudPalette.PLATE_SELECTED_HOVER if state == &"hover" else HudPalette.PLATE_SELECTED
			box.border_color = HudPalette.PLATE_SELECTED_EDGE
		if lopsided:
			var even: float = (base.content_margin_top + base.content_margin_bottom) * 0.5
			box.content_margin_top = even
			box.content_margin_bottom = even
		add_theme_stylebox_override(state, box)
	end_bulk_theme_override()
	queue_redraw()


func _draw() -> void:
	var mode: DrawMode = get_draw_mode()
	var pressed: bool = mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED
	var lift: float = lift_when_pressed if pressed else 0.0
	var ink: Color = _ink_for(mode)
	var bg: Color = _bg_for(mode)

	# Cıvatalar, ikon ve rozet dairesi TEK üçgen dizisinde (TriBatch): plaka başına 17 çizim çağrısı 3'e iner.
	var batch: TriBatch = TriBatch.new()
	if shape == Shape.ROUND:
		if kind != HudIcon.Kind.NONE:
			HudIcon.add_icon(batch, kind, size * 0.5 + Vector2(0.0, -1.0), icon_size * _icon_scale, ink, bg)
		_draw_badge(batch)
		return

	var has_icon: bool = kind != HudIcon.Kind.NONE or avatar != null
	var side_icon: bool = icon_left and kind != HudIcon.Kind.NONE
	if bolts:
		var bolt: Color = Color(ink, 0.45)
		var y: float = (7.0 if has_icon and not side_icon else size.y * 0.5) - lift
		batch.draw_circle(Vector2(7.0, y), 1.7, bolt, true, -1.0, true)
		batch.draw_circle(Vector2(size.x - 7.0, y), 1.7, bolt, true, -1.0, true)
	if side_icon:
		# Yazının hemen solunda, yazıyla aynı dikey ortada (kenar payları temadan)
		var sb: StyleBox = get_theme_stylebox(&"normal")
		var x: float = sb.content_margin_left - ICON_LEFT_GAP - icon_size * 0.5
		var cy: float = (sb.content_margin_top + size.y - sb.content_margin_bottom) * 0.5 - lift
		HudIcon.add_icon(batch, kind, Vector2(x, cy), icon_size, ink, bg)
	elif has_icon:
		# İkon, stylebox'ın üst content margin'inin ortasına oturur; yazı onun altında.
		var zone: float = get_theme_stylebox(&"normal").content_margin_top
		var center: Vector2 = Vector2(size.x * 0.5, zone * 0.5 + 3.0 - lift)
		if avatar:
			batch.flush(self)   # resim dizinin sırasını bozmasın: önce cıvatalar
			var side: float = icon_size + 2.0
			var rect: Rect2 = Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side))
			draw_texture_rect(avatar, rect, false)
			if avatar_frame:
				draw_rect(rect, ink, false, 1.5, true)
		else:
			HudIcon.add_icon(batch, kind, center, icon_size, ink, bg)
	_draw_badge(batch)


## Rozet köşenin biraz dışına taşar (GemShopButton'daki "!" rozetiyle aynı renkler). Daireler `batch`'e eklenir, dizi
## gönderilir, sonra rozet yazısı (yazı dokulu: diziye giremez).
func _draw_badge(batch: TriBatch) -> void:
	if badge <= 0:
		batch.flush(self)
		return
	var font: Font = get_theme_font(&"font")
	var text: String = str(badge) if badge < 10 else "9+"
	var center: Vector2 = Vector2(size.x - 3.0, 3.0)
	batch.draw_circle(center, 11.0, Color("A42E35"), true, -1.0, true)
	batch.draw_circle(center, 9.5, Color("E2474F"), true, -1.0, true)
	batch.flush(self)
	if font:
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14).x
		draw_string(font, center + Vector2(-w * 0.5, 5.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color.WHITE)


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
