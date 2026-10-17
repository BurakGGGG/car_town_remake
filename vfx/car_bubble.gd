class_name CarBubble
extends MeshInstance3D
## Aracın üstünde duran world-space plaka balonu (HUD plaka dili): kameraya dönük küçük krem plaka
## (vfx/customer_bubble.gdshader — billboard + hafif salınım shader'da), solda çizili işaret
## (anahtar ya da ₺ madeni para), istenirse sağda kısa yazı (Label3D, billboard). Ekrana sabit UI
## değildir; aracın çocuğu olduğu için onunla birlikte durur/taşınır. Gizli başlar.
## Kullanım: show_wrench() (yalnızca 🔧 — yol kenarında bekleyen müşteri; arıza adı araç üstünde
## YAZMAZ, araca/balona tıklayınca HUD plakasında görünür), show_text("TAMİR", GLYPH_WRENCH) (CarSpot'ta),
## show_text("+150 ₺", GLYPH_COIN) (para hazır), show_glyph(GLYPH_FLAG) (yalnızca damalı bayrak —
## drag yarışı daveti), hide_bubble(). Plaka genişliği metne göre büyür.

enum { GLYPH_WRENCH = 0, GLYPH_COIN = 1, GLYPH_FLAG = 2, GLYPH_AVATAR = 3 }

const SHADER: Shader = preload("res://vfx/customer_bubble.gdshader")
const HEIGHT: float = 0.17                     # plaka yüksekliği (dünya birimi)
const WIDTH_ICON: float = 0.22                 # yalnızca işaret
const WIDTH_TEXT: float = 0.38                 # işaret + kısa yazı ("TAMİR") için alt sınır
const WIDTH_MAX: float = 0.88                  # uzun arıza adlarında üst sınır ("KAPORTA HASARI")
const WIDTH_AVATAR: float = 0.33               # arkadaş rakip: fotoğraf + damalı bayrak
## Balondaki fotoğrafın dokusu (kare piksel): uzaktan küçük görünür, 256 px'lik resim örneklenirken titrerdi.
const AVATAR_PIXELS: int = 96
const PAD: float = 0.05                        # yazının sağındaki boşluk
const ICON_SLOT: float = 0.18                  # sol kenardaki işaret alanı
const TEXT_PIXEL: float = 0.0013
const CHAR_WIDTH: float = 0.045                # büyük harf ortalama genişliği (dünya birimi, TEXT_PIXEL'de)
const INK: Color = Color("2F3236")             # HudPalette.INK

## Fotoğraf dokusu önbelleği: kaynak doku RID + kırpım → küçültülmüş doku (aynı arkadaş tekrar gelince yeniden işlenmez).
static var _avatar_cache: Dictionary = {}

var _quad: QuadMesh
var _material: ShaderMaterial
var _label: Label3D


func _init() -> void:
	name = "CarBubble"
	_quad = QuadMesh.new()
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_quad.material = _material
	mesh = _quad
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_label = Label3D.new()
	_label.name = "Text"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.render_priority = 2
	_label.pixel_size = TEXT_PIXEL
	_label.font_size = 52
	_label.outline_size = 0
	_label.modulate = INK
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.visible = false
	add_child(_label)
	visible = false
	# Dünya plakası katmanı: garaj düzenlenirken kamera bu katmanı göstermez (WorldCamera).
	layers = WorldCamera.LAYER_WORLD_UI
	_label.layers = WorldCamera.LAYER_WORLD_UI


## Yalnızca anahtar işareti (müşteri tamir istiyor).
func show_wrench() -> void:
	show_glyph(GLYPH_WRENCH)


## Yalnızca işaret, yazısız (dar plaka) — ör. yarış daveti: sadece damalı bayrak.
func show_glyph(glyph: int) -> void:
	_apply(glyph, "")


## İşaret + kısa yazı ("TAMİR", "+150 ₺").
func show_text(text: String, glyph: int) -> void:
	_apply(glyph, text)


## Arkadaş rakip: yuvarlak fotoğraf + damalı bayrak (yazısız). `illustrated`: çizim (hazır avatar / Emre / Elif) →
## yüze yakın kırpılır (AvatarView.TIGHT_REGION ile aynı).
func show_avatar(texture: Texture2D, illustrated: bool) -> void:
	var small: Texture2D = _avatar_texture(texture, illustrated)
	if small == null:
		show_glyph(GLYPH_FLAG)
		return
	_material.set_shader_parameter(&"avatar_tex", small)
	_label.visible = false
	_quad.size = Vector2(WIDTH_AVATAR, HEIGHT)
	_material.set_shader_parameter(&"aspect", WIDTH_AVATAR / HEIGHT)
	_material.set_shader_parameter(&"glyph", GLYPH_AVATAR)
	_material.set_shader_parameter(&"glyph_offset", 0.0)
	visible = true


static func _avatar_texture(texture: Texture2D, illustrated: bool) -> Texture2D:
	if texture == null:
		return null
	# Dosyadan gelen doku (hazır avatar / Emre / Elif) yoluyla anılır: kimse tutmazsa bellekten düşüp yeniden yüklenince
	# kimliği değişir. İndirilen fotoğrafın yolu yoktur, onun dokusu SocialManager önbelleğinde yaşar.
	var key: String = "%s|%s" % [texture.resource_path if not texture.resource_path.is_empty()
		else str(texture.get_rid().get_id()), illustrated]
	if _avatar_cache.has(key):
		return _avatar_cache[key]
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return null
	image = image.duplicate() as Image
	if image.is_compressed():
		image.decompress()
	if illustrated:
		var r: Rect2 = AvatarView.TIGHT_REGION
		var size: Vector2 = Vector2(image.get_size())
		image = image.get_region(Rect2i(Vector2i((r.position * size).round()), Vector2i((r.size * size).round())))
	image.resize(AVATAR_PIXELS, AVATAR_PIXELS, Image.INTERPOLATE_LANCZOS)
	if _avatar_cache.size() > 24:
		_avatar_cache.clear()
	var out: ImageTexture = ImageTexture.create_from_image(image)
	_avatar_cache[key] = out
	return out


func hide_bubble() -> void:
	visible = false


## Plakanın o anki dünya boyutu (tıklama kutusunu buna göre ayarlamak için).
func plate_size() -> Vector2:
	return _quad.size


func _apply(glyph: int, text: String) -> void:
	_label.text = text
	_label.visible = text != ""
	var width: float = WIDTH_ICON
	if text != "":
		# Plaka genişliği yazı uzunluğundan hesaplanır: kısa "TAMİR" de, uzun "KAPORTA HASARI" da
		# işaretin sağına sığar. (Label3D ölçüsü aynı karede güncellenmediği için harf genişliği sabiti.)
		width = clampf(ICON_SLOT + text.length() * CHAR_WIDTH + PAD, WIDTH_TEXT, WIDTH_MAX)
	_quad.size = Vector2(width, HEIGHT)
	var aspect: float = width / HEIGHT
	_material.set_shader_parameter(&"aspect", aspect)
	_material.set_shader_parameter(&"glyph", glyph)
	# Shader uzayı: plaka yüksekliği 1 birim, x ±aspect/2. İşaret sol kenara yaslanır, yazı onun sağından
	# başlar (sola hizalı) — plaka genişlese de ikisi yerinde kalır.
	var icon_x: float = -(aspect * 0.5) + ICON_SLOT / HEIGHT * 0.5
	_material.set_shader_parameter(&"glyph_offset", icon_x if text != "" else 0.0)
	_label.offset = Vector2((icon_x + ICON_SLOT / HEIGHT * 0.55) * HEIGHT / TEXT_PIXEL, 3.0)
	visible = true
