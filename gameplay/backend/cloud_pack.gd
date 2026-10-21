class_name CloudPack
extends RefCounted
## BULUT METNİ SIKIŞTIRMA: kayıt (players.save_json) ve açık garaj (garages.garage_json) Firestore'a gzip + base64
## olarak yazılır ("gz1:" önekiyle). Dekorlu bir kayıt düz JSON'da 17 KB'ı geçiyordu (kural sınırı 20 KB: aşınca yazma
## reddedilir, oyun sessizce OFFLINE kalır); sıkışınca ~3 KB. Okuma iki biçimi de kabul eder: önek yoksa metin düz
## JSON'dur (eski belge, testler, oyunla gelen garajlar). Eski sürüm sıkışık kaydı okuyamaz → ERROR'a düşer, bulut
## korunur (üzerine yazmaz). Yönetim paneli (firebase/admin) aynı biçimi Node zlib.gunzipSync ile açar.

const PREFIX: String = "gz1:"
## Açılmış metnin üst sınırı: 20 KB'lık bir belge sıkıştırma bombasıyla yüzlerce MB'a açılmasın.
const MAX_PLAIN: int = 1 << 20


static func pack(text: String) -> String:
	if text.is_empty():
		return ""
	return PREFIX + Marshalls.raw_to_base64(text.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))


## Sıkışık metni açar; önek yoksa metni olduğu gibi döndürür. Bozuksa ya da sınırı aşıyorsa boş.
static func unpack(text: String) -> String:
	if not text.begins_with(PREFIX):
		return text
	var raw: PackedByteArray = Marshalls.base64_to_raw(text.substr(PREFIX.length()))
	if raw.is_empty():
		return ""
	var plain: PackedByteArray = raw.decompress_dynamic(MAX_PLAIN, FileAccess.COMPRESSION_GZIP)
	if plain.size() >= MAX_PLAIN:
		return ""
	return plain.get_string_from_utf8()
