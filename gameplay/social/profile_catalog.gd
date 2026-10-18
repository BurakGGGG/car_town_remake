class_name ProfileCatalog
extends RefCounted
## PROFİL KATALOĞU — sabit veri: hazır avatarlar, çerçeveler, bayraklar. Oyuncunun seçimleri PlayerProfile'da.
##
## AVATAR TANIMI (açık garaj belgesindeki "av" alanı, Firestore kuralıyla aynı biçim):
##   ""            → seçim yok (varsayılan avatar: kask)
##   "p01".."p12"  → hazır avatar (oyunla gelir, indirme yok)
##   "img:<8 hex>" → yüklenmiş fotoğraf (galeri / kamera / Google). Resmin kendisi avatars/a_{uid} belgesinde;
##                   hash değişmedikçe arkadaşlar yeniden indirmez.
## Çizimler (hazır + Emre / Elif) tools/avatars/'dan üretilir: 512 tuvalde tam portre, küçük boyda yüze yakın
## kırpılır (AvatarView.tight). Fotoğraflar zaten kırpılmış gelir, onlar kırpılmaz.

const AVATAR_DIR: String = "res://assets/ui/avatars/"
const PRESET_COUNT: int = 12
## Fotoğrafı olmayan / misafir oyuncu: kask (yüz göstermeyen hazır avatar).
const DEFAULT_PRESET: String = "p10"
## Yüklenen fotoğrafın kenarı (piksel) ve JPEG kalitesi. 192 px ≈ 10–14 KB; base64 ile Firestore belgesine sığar.
const PHOTO_SIZE: int = 192
const PHOTO_QUALITY: float = 0.82
## avatars/a_{uid}.img üst sınırı (karakter). Kuralla aynı (firestore.rules isValidAvatarDoc).
const PHOTO_B64_MAX: int = 40000
## Garaj adı (profilde takma adın altında). Kuralla aynı karakter kümesi; boş olabilir.
const TITLE_MAX: int = 20

## ÇERÇEVELER: seviyeyle açılanlar ("level") ve elmasla alınanlar ("gems", 100–600; kullanıcı kararı 2026-10-16).
## "animated": AvatarView her karede yeniden çizer (yalnız görünürken).
const FRAMES: Array[Dictionary] = [
	{"id": "plate", "name": "PLAKA", "level": 1, "gems": 0},
	{"id": "bronze", "name": "BRONZ", "level": 5, "gems": 0},
	{"id": "silver", "name": "GÜMÜŞ", "level": 10, "gems": 0},
	{"id": "gold", "name": "ALTIN", "level": 20, "gems": 0},
	{"id": "platinum", "name": "PLATİN", "level": 30, "gems": 0},
	{"id": "checker", "name": "DAMA", "level": 1, "gems": 100},
	{"id": "carbon", "name": "KARBON", "level": 1, "gems": 200},
	{"id": "neon", "name": "NEON", "level": 1, "gems": 350, "animated": true},
	{"id": "flame", "name": "ALEV", "level": 1, "gems": 450, "animated": true},
	{"id": "rainbow", "name": "GÖKKUŞAĞI", "level": 1, "gems": 600, "animated": true},
]
const DEFAULT_FRAME: String = "plate"

## BAYRAKLAR: kod → ad (FlagIcon hepsini kodla çizer; resim dosyası yok). Sıra = seçicideki sıra.
## Ülke adları gösterildiği yerde Loc.t ile çevrilir.
const FLAGS: Dictionary = {
	"TR": "TÜRKİYE", "AZ": "AZERBAYCAN", "DE": "ALMANYA", "NL": "HOLLANDA", "FR": "FRANSA", "GB": "BİRLEŞİK KRALLIK",
	"US": "ABD", "ES": "İSPANYA", "MX": "MEKSİKA", "AR": "ARJANTİN", "CO": "KOLOMBİYA", "CL": "ŞİLİ", "PE": "PERU",
	"VE": "VENEZUELA", "IT": "İTALYA", "RU": "RUSYA", "UA": "UKRAYNA", "BR": "BREZİLYA", "PT": "PORTEKİZ",
	"GR": "YUNANİSTAN", "BG": "BULGARİSTAN", "RO": "ROMANYA", "PL": "POLONYA", "AT": "AVUSTURYA", "BE": "BELÇİKA",
	"CH": "İSVİÇRE", "SE": "İSVEÇ", "NO": "NORVEÇ", "DK": "DANİMARKA", "FI": "FİNLANDİYA", "IE": "İRLANDA",
	"GE": "GÜRCİSTAN", "KZ": "KAZAKİSTAN", "UZ": "ÖZBEKİSTAN", "JP": "JAPONYA", "KR": "GÜNEY KORE", "CN": "ÇİN",
	"IN": "HİNDİSTAN", "ID": "ENDONEZYA", "SA": "SUUDİ ARABİSTAN", "AE": "BAE", "EG": "MISIR", "CA": "KANADA",
	"AU": "AVUSTRALYA",
}


# --- Avatarlar -------------------------------------------------------------------

static func preset_ids() -> Array[String]:
	var out: Array[String] = []
	for i: int in range(1, PRESET_COUNT + 1):
		out.append("p%02d" % i)
	return out


static func is_preset(av: String) -> bool:
	return av.length() == 3 and av.begins_with("p") and av.substr(1).is_valid_int() \
		and int(av.substr(1)) >= 1 and int(av.substr(1)) <= PRESET_COUNT


## "img:<8 hex>" mi; değilse boş, öyleyse hash.
static func image_hash(av: String) -> String:
	if not av.begins_with("img:"):
		return ""
	var hash: String = av.substr(4)
	return hash if is_hash(hash) else ""


static func is_hash(hash: String) -> bool:
	if hash.length() != 8:
		return false
	for c: String in hash:
		if not "0123456789abcdef".contains(c):
			return false
	return true


## Kuralın kabul ettiği biçim mi (boş da geçerli).
static func is_valid_av(av: String) -> bool:
	return av.is_empty() or is_preset(av) or not image_hash(av).is_empty()


static func preset_texture(av: String) -> Texture2D:
	var id: String = av if is_preset(av) else DEFAULT_PRESET
	return load(AVATAR_DIR + "preset_%s.png" % id.substr(1)) as Texture2D


static func default_texture() -> Texture2D:
	return preset_texture(DEFAULT_PRESET)


## Öne çıkan arkadaşın portresi (res://assets/ui/avatars/<kimlik>.png).
static func featured_texture(uid: String) -> Texture2D:
	var path: String = AVATAR_DIR + uid + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else default_texture()


## Fotoğraf baytlarının kısa özeti (avatar sürümü): değişince arkadaşlar yeniden indirir.
static func hash_of(bytes: PackedByteArray) -> String:
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode().substr(0, 8)


## Görüntüyü yüklenecek profil fotoğrafına çevirir: kare, PHOTO_SIZE, JPEG. Sınırı aşarsa kalite düşürülür.
static func encode_photo(image: Image) -> PackedByteArray:
	var img: Image = image.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGB8)
	if img.get_width() != PHOTO_SIZE or img.get_height() != PHOTO_SIZE:
		img.resize(PHOTO_SIZE, PHOTO_SIZE, Image.INTERPOLATE_LANCZOS)
	var quality: float = PHOTO_QUALITY
	var bytes: PackedByteArray = img.save_jpg_to_buffer(quality)
	while Marshalls.raw_to_base64(bytes).length() > PHOTO_B64_MAX and quality > 0.35:
		quality -= 0.1
		bytes = img.save_jpg_to_buffer(quality)
	return bytes


## Dosya / ağ baytlarından görüntü (biçim ilk baytlardan anlaşılır: PNG / JPEG / WebP). Okunamazsa null.
static func image_from_bytes(bytes: PackedByteArray) -> Image:
	if bytes.size() < 12:
		return null
	var image: Image = Image.new()
	var err: Error = ERR_FILE_UNRECOGNIZED
	if bytes[0] == 0x89 and bytes[1] == 0x50:
		err = image.load_png_from_buffer(bytes)
	elif bytes[0] == 0xFF and bytes[1] == 0xD8:
		err = image.load_jpg_from_buffer(bytes)
	elif bytes.slice(0, 4).get_string_from_ascii() == "RIFF" and bytes.slice(8, 12).get_string_from_ascii() == "WEBP":
		err = image.load_webp_from_buffer(bytes)
	return image if err == OK and not image.is_empty() else null


## BAŞKA OYUNCUNUN fotoğrafı (avatars belgesi / önbelleği). Oyun her zaman PHOTO_SIZE JPEG yükler; başka biçim ya da
## başlığında NET_PHOTO_MAX_SIDE'dan büyük boyut yazan dosya ÇÖZÜLMEDEN reddedilir: belgeyi oyunu atlayıp elle yazan
## biri 1 KB'lık JPEG'in başlığına 16000×16000 yazarsa motor ~800 MB ayırıyordu (fotoğrafı gören arkadaşın oyunu çöker).
const NET_PHOTO_MAX_SIDE: int = 512


static func image_from_net(bytes: PackedByteArray) -> Image:
	var size: Vector2i = jpeg_size(bytes)
	if size.x <= 0 or size.y <= 0 or size.x > NET_PHOTO_MAX_SIDE or size.y > NET_PHOTO_MAX_SIDE:
		return null
	return image_from_bytes(bytes)


## JPEG başlığındaki boyut (çerçeve başlığı SOFn); JPEG değilse ya da okunamazsa (0, 0). Çözmez, yalnızca bölümleri atlar.
static func jpeg_size(bytes: PackedByteArray) -> Vector2i:
	if bytes.size() < 4 or bytes[0] != 0xFF or bytes[1] != 0xD8:
		return Vector2i.ZERO
	var i: int = 2
	while i + 3 < bytes.size():
		if bytes[i] != 0xFF:
			return Vector2i.ZERO
		var marker: int = bytes[i + 1]
		if marker == 0xFF:
			i += 1   # dolgu baytı
			continue
		if marker == 0x01 or (marker >= 0xD0 and marker <= 0xD7):
			i += 2   # uzunluksuz işaretler
			continue
		if marker == 0xD9 or marker == 0xDA:
			return Vector2i.ZERO   # çerçeve başlığından önce görüntü verisi / son: bozuk
		var length: int = (bytes[i + 2] << 8) | bytes[i + 3]
		if length < 2:
			return Vector2i.ZERO
		if marker >= 0xC0 and marker <= 0xCF and marker != 0xC4 and marker != 0xC8 and marker != 0xCC:
			if i + 8 >= bytes.size():
				return Vector2i.ZERO
			return Vector2i((bytes[i + 7] << 8) | bytes[i + 8], (bytes[i + 5] << 8) | bytes[i + 6])
		i += 2 + length
	return Vector2i.ZERO


# --- Çerçeveler ------------------------------------------------------------------

static func frame(id: String) -> Dictionary:
	for entry: Dictionary in FRAMES:
		if entry["id"] == id:
			return entry
	return {}


static func is_frame(id: String) -> bool:
	return not frame(id).is_empty()


static func frame_animated(id: String) -> bool:
	return bool(frame(id).get("animated", false))


# --- Bayraklar -------------------------------------------------------------------

static func flag_codes() -> Array[String]:
	var out: Array[String] = []
	for code: String in FLAGS:
		out.append(code)
	return out


static func is_flag(code: String) -> bool:
	return FLAGS.has(code)


static func flag_name(code: String) -> String:
	return Loc.t(String(FLAGS.get(code, "")))


# --- Metin -----------------------------------------------------------------------

## Garaj adı: baş / son boşluk ve ardışık boşluk temizlenir, uzunsa kısaltılır. Karakter kümesi ve küfür
## süzgeci takma adla aynıdır (SocialNames.is_valid_title). Geçersizse null yerine "": çağıran reddeder.
## Yazıldığı gibi saklanır; gösterirken Loc.upper ile büyütülür (Türkçe i / ı doğru).
static func clean_title(raw: String) -> String:
	var title: String = SocialNames.clean_name(raw)
	if title.length() > TITLE_MAX:
		title = title.substr(0, TITLE_MAX).strip_edges()
	return title
