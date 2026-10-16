class_name PhotoCapture
extends RefCounted
## FOTOĞRAF — ekran görüntüsüne logo basma ve JPEG'e çevirme (yalnızca Image işi, sahneye dokunmaz).
## Logo (assets/branding/autoyard_logo.png, saydam 2048×475) fotoğrafın SOL ALT köşesine, genişliğin
## LOGO_WIDTH kadarı boyunda basılır. Fotoğraf modu aynı oranları önizlemede de kullanır (logo
## çekilmeden önce ekranda nerede çıkacaksa orada görünür). Arka planda (WorkerThreadPool) çalışabilir:
## yalnızca verilen Image'lara dokunur.

const LOGO_PATH: String = "res://assets/branding/autoyard_logo.png"
## Logonun fotoğraf genişliğine oranı.
const LOGO_WIDTH: float = 0.24
## Logo bu yükseklik oranını aşmaz (dar / dikey kadrajda logo fotoğrafı kaplamasın).
const LOGO_MAX_HEIGHT: float = 0.16
## Kenar payı: fotoğraf yüksekliğine oranı.
const LOGO_MARGIN: float = 0.035
const JPEG_QUALITY: float = 0.92
const FILE_PREFIX: String = "AutoYard_"


## `size` boyutundaki fotoğrafta logonun dikdörtgeni (piksel ya da tuval birimi: oranlar aynı).
static func logo_rect(size: Vector2, logo_size: Vector2) -> Rect2:
	if size.x <= 0.0 or size.y <= 0.0 or logo_size.x <= 0.0 or logo_size.y <= 0.0:
		return Rect2()
	var width: float = size.x * LOGO_WIDTH
	var height: float = width * logo_size.y / logo_size.x
	if height > size.y * LOGO_MAX_HEIGHT:
		height = size.y * LOGO_MAX_HEIGHT
		width = height * logo_size.x / logo_size.y
	var margin: float = size.y * LOGO_MARGIN
	return Rect2(Vector2(margin, size.y - margin - height), Vector2(width, height))


## Fotoğrafa logoyu basar; yeni bir RGB8 Image döner (girdiler değişmez). Logo yoksa fotoğraf aynen kalır.
static func compose(shot: Image, logo: Image) -> Image:
	var out: Image = shot.duplicate() as Image
	if out.is_compressed():
		out.decompress()
	out.convert(Image.FORMAT_RGBA8)
	if logo != null and not logo.is_empty():
		var stamp: Image = logo.duplicate() as Image
		if stamp.is_compressed():
			stamp.decompress()
		stamp.convert(Image.FORMAT_RGBA8)
		var rect: Rect2 = logo_rect(Vector2(out.get_size()), Vector2(stamp.get_size()))
		var target: Vector2i = Vector2i(maxi(int(round(rect.size.x)), 1), maxi(int(round(rect.size.y)), 1))
		stamp.resize(target.x, target.y, Image.INTERPOLATE_LANCZOS)
		out.blend_rect(stamp, Rect2i(Vector2i.ZERO, target), Vector2i(int(round(rect.position.x)), int(round(rect.position.y))))
	out.convert(Image.FORMAT_RGB8)
	return out


## Logolu fotoğraf → JPEG baytları (boşsa kodlama başarısız).
static func render_jpeg(shot: Image, logo: Image) -> PackedByteArray:
	if shot == null or shot.is_empty():
		return PackedByteArray()
	return compose(shot, logo).save_jpg_to_buffer(JPEG_QUALITY)


## Son çekimin küçük resmi (fotoğraf modunun köşesindeki önizleme) — `width` piksel genişlikte.
static func thumbnail(shot: Image, width: int) -> Image:
	if shot == null or shot.is_empty() or width <= 0:
		return null
	var small: Image = shot.duplicate() as Image
	var height: int = maxi(int(round(float(width) * float(shot.get_height()) / float(shot.get_width()))), 1)
	small.resize(width, height, Image.INTERPOLATE_BILINEAR)
	return small


## AutoYard_20261016_153012.jpg — aynı saniyede ikinci çekim galeride üzerine yazmasın diye `serial` eklenir.
static func file_name(when: Dictionary, serial: int = 0) -> String:
	var stamp: String = "%04d%02d%02d_%02d%02d%02d" % [int(when.get("year", 0)), int(when.get("month", 0)),
		int(when.get("day", 0)), int(when.get("hour", 0)), int(when.get("minute", 0)), int(when.get("second", 0))]
	return FILE_PREFIX + stamp + ("_%d" % serial if serial > 0 else "") + ".jpg"


## Logo görseli (içe aktarma kayıpsız: get_image doğrudan okunur). Ana iş parçacığında çağrılmalı.
static func load_logo() -> Image:
	var texture: Texture2D = load(LOGO_PATH) as Texture2D
	return texture.get_image() if texture else null
