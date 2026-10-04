class_name Loc
## DİL DESTEĞİ — Türkçe / İngilizce / İspanyolca.
##
## Kaynak dil TÜRKÇE'dir: çeviri anahtarı (msgid) Türkçe metnin KENDİSİdir; böylece kodda ayrı anahtar
## tablosu tutulmaz ve Türkçe oyun hiçbir çeviri dosyası olmadan çalışır. Çeviriler locale/en.json ve
## locale/es.json'dadır ({"Türkçe metin": "çeviri"}); açılışta Translation nesnelerine yüklenir.
##
## KULLANIM: oyuncuya görünen her metin Loc.t("…") ile geçer; biçimli metinlerde ÖNCE çevir, SONRA
## biçimle: Loc.t("%s TAMİR YAP") % hedef. Veri dosyalarından / sabit kataloglardan gelen metin
## gösterildiği yerde Loc.t ile çevrilir. Yeni metin eklenince: python3 tools/i18n/extract.py →
## locale/strings.json güncellenir → tools/i18n/check.py eksik çevirileri listeler.
## Dil değişimi sahneyi yeniden kurar (GameSettings.set_language): açık ekranların hepsi yeni dille kurulur.

const LANGUAGES: Array[String] = ["tr", "en", "es"]
## Dil adları kendi dillerinde yazılır ve ÇEVRİLMEZ (seçim düğmeleri).
const NAMES: Dictionary = {"tr": "TÜRKÇE", "en": "ENGLISH", "es": "ESPAÑOL"}
const DIR: String = "res://locale/"

static var _translations: Dictionary = {}   # dil → Translation (bir kez okunur)


## Metni geçerli dile çevirir (çevirisi yoksa olduğu gibi döner).
static func t(text: String) -> String:
	return String(TranslationServer.translate(text))


## Dili ayarlar. Sunucuda YALNIZCA seçili dilin çevirisi durur: Godot çevirisi olmayan dilde proje
## yedek diline (İngilizce) düşer — tüm çeviriler yüklü kalsaydı Türkçe seçiliyken metinler İngilizce
## çıkardı. Türkçe seçilince hiçbir çeviri yüklü olmaz, metinler kaynak (Türkçe) haliyle görünür.
static func use(language: String) -> void:
	var lang: String = language if LANGUAGES.has(language) else "en"
	TranslationServer.clear()
	if lang != "tr":
		var translation: Translation = _translation(lang)
		if translation:
			TranslationServer.add_translation(translation)
	TranslationServer.set_locale(lang)


static func current() -> String:
	var lang: String = TranslationServer.get_locale().substr(0, 2)
	return lang if LANGUAGES.has(lang) else "tr"


## Sayıya bağlı metin: n == 1 ise önce tekil biçim aranır (anahtar "<metin>|1"; Türkçede tekil/çoğul
## ayrımı olmadığı için yalnızca çevirilerde bulunur), yoksa normal çeviri. "OPEN 1 CRATE" / "OPEN 3 CRATES".
static func tn(text: String, n: int) -> String:
	if n == 1:
		var singular: String = t(text + "|1")
		if singular != text + "|1":
			return singular
	return t(text)


## Bağlamlı çeviri: aynı Türkçe sözcük farklı yerde farklı anlama geliyorsa ("AÇIK": alan açık = OPEN,
## ayar açık = ON). Anahtar "<metin>|<bağlam>" yalnızca çevirilerde bulunur; yoksa normal çeviri.
static func tc(text: String, context: String) -> String:
	var key: String = text + "|" + context
	var translated: String = t(key)
	return translated if translated != key else t(text)


## Yüzde: TR "%25" · EN "25%" · ES "25 %". `value` biçimlenmiş sayı metnidir.
static func percent(value: String) -> String:
	match current():
		"en": return value + "%"
		"es": return value + " %"
	return "%" + value


## Ondalıklı sayı: TR / ES virgül, EN nokta.
static func decimal(value: float, digits: int = 1) -> String:
	var text: String = String.num(value, digits)
	if not text.contains("."):
		text += "." + "0".repeat(digits)
	return text if current() == "en" else text.replace(".", ",")


## Cihaz dili desteklenenlerden biriyse o, değilse İngilizce.
static func device_language() -> String:
	var lang: String = OS.get_locale_language()
	return lang if LANGUAGES.has(lang) else "en"


static func _translation(lang: String) -> Translation:
	if _translations.has(lang):
		return _translations[lang]
	var path: String = DIR + lang + ".json"
	if not FileAccess.file_exists(path):
		push_warning("Loc: %s yok" % path)
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary):
		push_warning("Loc: %s bozuk" % path)
		return null
	var translation: Translation = Translation.new()
	translation.locale = lang
	for key: Variant in (data as Dictionary):
		var value: String = String((data as Dictionary)[key])
		if value != "":
			translation.add_message(String(key), value)
	_translations[lang] = translation
	return translation
