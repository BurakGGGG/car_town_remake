class_name ProfileCatalog
extends RefCounted
## PROFİL KATALOĞU — sabit veri: hazır avatarlar, çerçeveler, bayraklar. Oyuncunun seçimleri PlayerProfile'da.
##
## AVATAR TANIMI (açık garaj belgesindeki "av" alanı, Firestore kuralıyla aynı biçim):
##   ""            → seçim yok (varsayılan avatar: kask)
##   "p01".."p36"  → hazır avatar (oyunla gelir, indirme yok; kural p00–p99 kabul eder). Eski sürüm tanımadığı numarayı
##                   kask gösterir.
##   "img:<8 hex>" → yüklenmiş fotoğraf (galeri / kamera / Google). Resmin kendisi avatars/a_{uid} belgesinde;
##                   hash değişmedikçe arkadaşlar yeniden indirmez.
## Çizimler (hazır + Emre / Elif) tools/avatars/'dan üretilir: 512 tuvalde tam portre, küçük boyda yüze yakın
## kırpılır (AvatarView.tight). Fotoğraflar zaten kırpılmış gelir, onlar kırpılmaz.

const AVATAR_DIR: String = "res://assets/ui/avatars/"
const PRESET_COUNT: int = 36
## p29–p36 YÜZSÜZ SİMGE (direksiyon, piston…): tuvali dolduran çizim, küçük boyda yüze yakın kırpılmaz (AvatarView).
const ICON_FIRST: int = 29
## HAZIR AVATAR KİLİTLERİ (2026-11-01, kullanıcı kararı; docs/PROFIL_KISISELLESTIRME.md). Listede olmayan ücretsizdir
## (eski 12 + dört ülke portresi + direksiyon + İngiliz anahtarı: kimlik avatarları bilerek ücretsiz).
## "level": o seviyede açılır · "gems": elmasla alınır (100–300) · "wins": drag galibiyeti (RaceManager.wins, profil
## kartındaki sayı) · "repairs": yaşam boyu tamir (MissionManager "repairs").
const AVATAR_UNLOCKS: Dictionary = {
	"p23": {"level": 3}, "p21": {"level": 6}, "p31": {"level": 9}, "p22": {"level": 13}, "p13": {"level": 17},
	"p32": {"level": 22}, "p15": {"level": 28}, "p14": {"level": 35},
	"p33": {"gems": 100}, "p34": {"gems": 100}, "p35": {"gems": 150}, "p19": {"gems": 200}, "p20": {"gems": 250},
	"p17": {"gems": 300},
	"p18": {"wins": 100}, "p36": {"wins": 500}, "p16": {"repairs": 500}, "p24": {"repairs": 2000},
}
## Fotoğrafı olmayan / misafir oyuncu: kask (yüz göstermeyen hazır avatar).
const DEFAULT_PRESET: String = "p10"
## Yüklenen fotoğrafın kenarı (piksel) ve JPEG kalitesi. 192 px ≈ 10–14 KB; base64 ile Firestore belgesine sığar.
const PHOTO_SIZE: int = 192
const PHOTO_QUALITY: float = 0.82
## avatars/a_{uid}.img üst sınırı (karakter). Kuralla aynı (firestore.rules isValidAvatarDoc).
const PHOTO_B64_MAX: int = 40000
## Garaj adı (profilde takma adın altında). Kuralla aynı karakter kümesi; boş olabilir.
const TITLE_MAX: int = 20

## ÇERÇEVELER: seviyeyle açılanlar ("level") ve elmasla alınanlar ("gems", 100–1500; kullanıcı kararı 2026-10-16,
## 2026-11-01'de 13 → 28: araba kültürü, malzeme, taşan prestij — docs/PROFIL_KISISELLESTIRME.md). Dizideki sıra =
## seçicideki sıra (seviye, elmas, başarım, özel).
## "animated": AvatarView her karede yeniden çizer (yalnız görünürken). "exclusive": satılmaz, seviyeyle açılmaz; yalnız
## verilince (POSTA "frame") sahibinin olur ve seçicide yalnız sahibine görünür — ARKADAŞ DAVETİ ödülleri (2026-10-23).
## "wins": drag galibiyetiyle açılır (RaceManager.wins). "ring": halka kodla değil DETAYLI DOKUYLA çizilir
## (assets/ui/frames/ring_<kimlik>.png, tools/avatars/make_rings.py; kullanıcı "daha detaylı ve güzel" dedi, 2026-11-01);
## hareketli kısımları (ibre, parıltı, alev) AvatarView üstüne çizer. "back" / "front": halkanın dışına TAŞAN süs dokusu
## (assets/ui/frames/<ad>.png; avatarın arkasında / halkanın önünde), dairenin ORNAMENT_SCALE katı kareye çizilir.
const FRAMES: Array[Dictionary] = [
	{"id": "plate", "name": "PLAKA", "level": 1, "gems": 0},
	{"id": "hazard", "name": "İKAZ BANDI", "level": 3, "gems": 0, "ring": true},
	{"id": "bronze", "name": "BRONZ", "level": 5, "gems": 0},
	{"id": "tire", "name": "LASTİK", "level": 8, "gems": 0, "ring": true},
	{"id": "silver", "name": "GÜMÜŞ", "level": 10, "gems": 0},
	{"id": "wheel", "name": "DİREKSİYON", "level": 15, "gems": 0, "ring": true},
	{"id": "gold", "name": "ALTIN", "level": 20, "gems": 0},
	{"id": "stripe", "name": "YARIŞ ŞERİDİ", "level": 25, "gems": 0, "ring": true},
	{"id": "platinum", "name": "PLATİN", "level": 30, "gems": 0},
	{"id": "gauge", "name": "GÖSTERGE", "level": 40, "gems": 0, "animated": true, "ring": true},
	{"id": "laurel", "name": "DEFNE", "level": 60, "gems": 0, "front": "laurel_front", "ring": true},
	{"id": "crown", "name": "TAÇ", "level": 99, "gems": 0, "front": "crown_front", "ring": true},
	{"id": "checker", "name": "DAMA", "level": 1, "gems": 100},
	{"id": "wood", "name": "AHŞAP", "level": 1, "gems": 150, "ring": true},
	{"id": "carbon", "name": "KARBON", "level": 1, "gems": 200},
	{"id": "rust", "name": "PAS", "level": 1, "gems": 200, "ring": true},
	{"id": "copper", "name": "BAKIR", "level": 1, "gems": 300, "ring": true},
	{"id": "neon", "name": "NEON", "level": 1, "gems": 350, "animated": true},
	{"id": "chrome", "name": "KROM", "level": 1, "gems": 400, "animated": true, "ring": true},
	{"id": "flame", "name": "ALEV", "level": 1, "gems": 450, "animated": true},
	{"id": "velvet", "name": "KADİFE", "level": 1, "gems": 500, "ring": true},
	{"id": "rainbow", "name": "GÖKKUŞAĞI", "level": 1, "gems": 600, "animated": true},
	{"id": "winged", "name": "KANATLI TEKER", "level": 1, "gems": 900, "back": "winged_back", "ring": true},
	{"id": "flame_cup", "name": "ALEVLİ KUPA", "level": 1, "gems": 1500, "animated": true, "front": "flame_cup_front", "ring": true},
	{"id": "diamond_crown", "name": "ELMAS TAÇ", "level": 1, "gems": 0, "wins": 1000, "front": "diamond_crown_front", "ring": true},
	{"id": "inviter", "name": "DAVETÇİ", "level": 1, "gems": 0, "exclusive": true},
	{"id": "envoy", "name": "ELÇİ", "level": 1, "gems": 0, "exclusive": true},
	{"id": "collector", "name": "KOLEKSİYONER", "level": 1, "gems": 0, "exclusive": true},   # tam koleksiyon (CollectionRewards)
]
const FRAME_DIR: String = "res://assets/ui/frames/"
## Süs dokusunun avatar dairesine oranı: süs tuvali 512, daire (halka dahil) yarıçapı 160 (tools/avatars/make_frames.py).
const ORNAMENT_SCALE: float = 512.0 / 320.0
## Süsler daireden her yönde en çok %20 taşar (tuvalde 32..480): avatar kutusunun içinde daire bu kadar küçük çizilirse
## (AvatarView.ornament_room) süs kutuya sığar. HUD'da herkes için böyle (kullanıcı kararı 2026-11-01: "fotoğraf küçük
## olsun, prestij alan herkese sığsın; süsü olmayanın da küçük olsun").
const ORNAMENT_ROOM: float = 448.0 / 320.0
## Doku halkasının iç yarıçapı / dış yarıçap (make_rings.py: RI 212 / 256). Hareketli kısımlar bu banda hizalanır.
const RING_INNER: float = 212.0 / 256.0
## UNVANLAR (2026-10-25): kazanılınca profil kartında adın altında amber şerit; açık garajda "honor" (arkadaşlar da görür).
## Kimlik → ad (çeviri anahtarı). Yalnız verilir (CollectionRewards: tam koleksiyon).
const HONORS: Dictionary = {"collector": "KOLEKSİYONER"}
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


## Seçicideki sıra: önce ücretsizler (numara sırasıyla), sonra seviyeyle açılanlar, elmaslılar, başarımlar (her grup
## kendi eşiğine göre).
static func preset_ids_display() -> Array[String]:
	var ids: Array[String] = preset_ids()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ka: Array = _unlock_sort_key(a)
		var kb: Array = _unlock_sort_key(b)
		return ka < kb)
	return ids


static func _unlock_sort_key(id: String) -> Array:
	var rule: Dictionary = avatar_unlock(id)
	var n: int = int(id.substr(1))
	if rule.has("level"):
		return [1, int(rule["level"]), n]
	if rule.has("gems"):
		return [2, int(rule["gems"]), n]
	if rule.has("wins"):
		return [3, int(rule["wins"]), n]
	if rule.has("repairs"):
		return [4, int(rule["repairs"]), n]
	return [0, 0, n]


## Avatarın kilidi ({} = ücretsiz). Anahtarlar: level / gems / wins / repairs (biri).
static func avatar_unlock(id: String) -> Dictionary:
	return AVATAR_UNLOCKS.get(id, {})


static func avatar_price(id: String) -> int:
	return int(avatar_unlock(id).get("gems", 0))


## Seçicide kilitli avatarın altındaki kısa koşul ("SEVİYE 17", "300 GEM", "100 GALİBİYET", "500 TAMİR").
static func avatar_requirement(id: String) -> String:
	var rule: Dictionary = avatar_unlock(id)
	if rule.has("level"):
		return Loc.t("SEVİYE %d") % int(rule["level"])
	if rule.has("gems"):
		return Loc.t("%d GEM") % int(rule["gems"])
	if rule.has("wins"):
		return Loc.t("%d GALİBİYET") % int(rule["wins"])
	if rule.has("repairs"):
		return Loc.t("%d TAMİR") % int(rule["repairs"])
	return ""


## Yüzsüz simge avatar mı (p29–p36).
static func is_icon_preset(av: String) -> bool:
	return is_preset(av) and int(av.substr(1)) >= ICON_FIRST


## Doku yüzsüz simge avatarın resmi mi (AvatarView kırpmaz). Doku yolundan anlaşılır: çağıranların hepsi
## preset_texture ile yükler.
static func is_icon_texture(tex: Texture2D) -> bool:
	if tex == null:
		return false
	var file: String = tex.resource_path.get_file()
	if not file.begins_with("preset_") or not tex.resource_path.begins_with(AVATAR_DIR):
		return false
	var number: String = file.get_basename().substr(7)
	return number.is_valid_int() and int(number) >= ICON_FIRST


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

## Kimlik → kayıt (bir kez kurulur): hareketli çerçeveler her karede birkaç kez soruyordu, dizi taraması yerine sözlük.
static var _frame_index: Dictionary = {}


static func frame(id: String) -> Dictionary:
	if _frame_index.is_empty():
		for entry: Dictionary in FRAMES:
			_frame_index[entry["id"]] = entry
	return _frame_index.get(id, {})


static func is_frame(id: String) -> bool:
	return not frame(id).is_empty()


static func frame_animated(id: String) -> bool:
	return bool(frame(id).get("animated", false))


## Yalnız verilerek açılan çerçeve (satılmaz, seviyeyle açılmaz).
static func is_honor(id: String) -> bool:
	return HONORS.has(id)


static func honor_name(id: String) -> String:
	return Loc.t(String(HONORS.get(id, "")))


static func frame_exclusive(id: String) -> bool:
	return bool(frame(id).get("exclusive", false))


## Drag galibiyetiyle açılan çerçevenin eşiği (değilse 0).
static func frame_wins(id: String) -> int:
	return int(frame(id).get("wins", 0))


## Detaylı halka dokusu ("ring": true); yoksa null. Bir kez yüklenir.
static func frame_ring(id: String) -> Texture2D:
	if not bool(frame(id).get("ring", false)):
		return null
	return _cached_texture("ring_" + id)


## Taşan süs dokusu ("back" / "front"); yoksa null. Bir kez yüklenir.
static var _ornaments: Dictionary = {}


static func frame_ornament(id: String, layer: String) -> Texture2D:
	var name: String = String(frame(id).get(layer, ""))
	return null if name.is_empty() else _cached_texture(name)


static func _cached_texture(name: String) -> Texture2D:
	if not _ornaments.has(name):
		var path: String = FRAME_DIR + name + ".png"
		_ornaments[name] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _ornaments[name]


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
