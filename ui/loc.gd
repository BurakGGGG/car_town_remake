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
## Büyük harf: Türkçe seçiliyken i → İ, ı → I (String.to_upper "i"yi "I" yapar: "elif" → "ELIF" olurdu).
## Oyuncunun yazdığı ad / garaj adı gibi metinler için; çeviri anahtarları zaten büyük harfle yazılı.
static func upper(text: String) -> String:
	if current() == "tr":
		text = text.replace("i", "İ").replace("ı", "I")
	return text.to_upper()


## Belirtme hâli (-ı / -i / -u / -ü): Türkçede "Elif Usta" → "Elif Usta'yı", "Bob" → "Bob'u", "Usta1234" → "Usta1234'ü"
## (sayı okunuşuna göre: dört → ü). Son ünlü uyumu; ünlüyle biten adda kaynaştırma "y". Diğer dillerde ad olduğu gibi.
static func accusative(name: String) -> String:
	if current() != "tr" or name.strip_edges().is_empty():
		return name
	var text: String = name.strip_edges()
	var last: String = ""
	for i: int in range(text.length() - 1, -1, -1):
		var c: String = text[i]
		if c.is_valid_int() or "aeıioöuüAEIİOÖUÜ".contains(c) or c.to_lower() != c.to_upper():
			last = c
			break
	if last.is_empty():
		return name
	var harmony: String = ""
	var vowel_end: bool = false
	if last.is_valid_int():
		var spoken: Array = _number_ending(text)
		harmony = spoken[0]
		vowel_end = spoken[1]
	else:
		for i: int in range(text.length() - 1, -1, -1):
			var v: String = text[i]
			var found: String = ""
			if "aıAI".contains(v):
				found = "ı"
			elif "eiEİ".contains(v):
				found = "i"
			elif "ouOU".contains(v):
				found = "u"
			elif "öüÖÜ".contains(v):
				found = "ü"
			if not found.is_empty():
				harmony = found
				break
		vowel_end = "aeıioöuüAEIİOÖUÜ".contains(last)
	if harmony.is_empty():
		harmony = "i"
	return text + "'" + ("y" if vowel_end else "") + harmony


## Sondaki sayının okunuşunun son hecesi: [ek ünlüsü, ünlüyle mi bitiyor]. "1234" → dört (ü), "10" → on (u),
## "20" → yirmi (yi), "300" → yüz (ü), "5000" → bin (i), "0" → sıfır (ı).
static func _number_ending(text: String) -> Array:
	var digits: String = ""
	for i: int in range(text.length() - 1, -1, -1):
		if not text[i].is_valid_int():
			break
		digits = text[i] + digits
	var number: String = digits.lstrip("0")
	if number.is_empty():
		return ["ı", false]   # sıfır
	var zeros: int = number.length() - number.rstrip("0").length()
	var lead: int = int(number.rstrip("0").right(1))
	match zeros:
		0:   # bir, iki, üç, dört, beş, altı, yedi, sekiz, dokuz
			return [["", "i", "i", "ü", "ü", "i", "ı", "i", "i", "u"][lead], lead in [2, 6, 7]]
		1:   # on, yirmi, otuz, kırk, elli, altmış, yetmiş, seksen, doksan
			return [["", "u", "i", "u", "ı", "i", "ı", "i", "i", "ı"][lead], lead in [2, 5]]
		2:
			return ["ü", false]   # yüz
	return ["u", false] if zeros >= 6 else ["i", false]   # milyon / bin


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
