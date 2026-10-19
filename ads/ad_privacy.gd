class_name AdPrivacy
extends RefCounted
## REKLAM GİZLİLİĞİ — kişiselleştirilmiş reklam kararı (AppLovin; AdMob'da bu işi Google UMP yapıyordu).
##
## AdMob hesabı reddedildiği için Google'ın onay penceresi (UMP) kullanılamıyor (AppLovin'in UMP otomasyonu da
## AdMob panelinde yayınlanmış mesaj ister). Kural (2026-10-19):
##   AEA / BK / İsviçre → varsayılan KAPALI (kişiselleştirilmemiş reklam); oyuncu AYARLAR'dan açabilir (açık rıza).
##   Diğer ülkeler      → varsayılan AÇIK; oyuncu kapatabilir (ABD "satma" itirazı da bununla verilir).
##   Ülke bilinmiyorsa  → KAPALI (güvenli taraf).
## Ülke: önce AppLovin'in bir önceki başlatmada IP'den bildirdiği ülke (kayıtlı), yoksa cihaz dili ("tr_TR" → TR).
## AppLovin değerleri başlatmadan ÖNCE okur → karar her açılışta SDK başlatılmadan uygulanır.
##
## Dosya cihaza özeldir (user://ad_privacy.cfg), bulut kaydına girmez.

const PATH: String = "user://ad_privacy.cfg"

## Oyuncu seçimi: hiç seçmedi / kapattı / açtı.
enum Choice { UNSET = -1, OFF = 0, ON = 1 }

## AEA (AB 27 + İzlanda, Lihtenştayn, Norveç) + Birleşik Krallık + İsviçre.
const GDPR_COUNTRIES: Array[StringName] = [
	&"AT", &"BE", &"BG", &"HR", &"CY", &"CZ", &"DK", &"EE", &"FI", &"FR", &"DE", &"GR", &"HU", &"IE", &"IT", &"LV",
	&"LT", &"LU", &"MT", &"NL", &"PL", &"PT", &"RO", &"SK", &"SI", &"ES", &"SE", &"IS", &"LI", &"NO", &"GB", &"UK",
	&"CH",
]


static func is_gdpr_country(code: String) -> bool:
	return GDPR_COUNTRIES.has(StringName(clean_country(code)))


## İki harfli büyük ülke kodu; başka her şey "" (bilinmiyor → kişiselleştirme kapalı).
static func clean_country(code: String) -> String:
	var c: String = code.strip_edges().to_upper()
	if c.length() != 2:
		return ""
	for ch: String in c:
		if ch < "A" or ch > "Z":
			return ""
	return c


## Cihaz dilinden ülke: "tr_TR" → "TR", "en" → "" (bilinmiyor).
static func locale_country(locale: String) -> String:
	var parts: PackedStringArray = locale.replace("-", "_").split("_")
	for i: int in range(1, parts.size()):
		var c: String = clean_country(parts[i])
		if c != "":
			return c
	return ""


## Kararın dayandığı ülke: SDK'nın bildirdiği (kayıtlı) önce, yoksa cihaz dili.
static func region(cached_country: String, locale: String) -> String:
	var cached: String = clean_country(cached_country)
	return cached if cached != "" else locale_country(locale)


## Kişiselleştirilmiş reklam açık mı? Oyuncu seçtiyse o; seçmediyse ülkeye göre varsayılan.
static func personalized(choice: int, country: String) -> bool:
	if choice != Choice.UNSET:
		return choice == Choice.ON
	return country != "" and not is_gdpr_country(country)


# --- Cihaz dosyası ----------------------------------------------------------------

static func load_state() -> Dictionary:
	var cfg: ConfigFile = ConfigFile.new()
	var state: Dictionary = {"choice": Choice.UNSET, "country": ""}
	if cfg.load(PATH) != OK:
		return state
	var raw_choice: int = int(cfg.get_value("ads", "choice", Choice.UNSET))
	state["choice"] = raw_choice if raw_choice in [Choice.OFF, Choice.ON] else Choice.UNSET
	state["country"] = clean_country(str(cfg.get_value("ads", "country", "")))
	return state


static func save_state(state: Dictionary) -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("ads", "choice", int(state.get("choice", Choice.UNSET)))
	cfg.set_value("ads", "country", String(state.get("country", "")))
	if cfg.save(PATH) != OK:
		push_warning("AdPrivacy: %s yazılamadı" % PATH)


## Bu cihazda şu an kişiselleştirilmiş reklam açık mı (kayıt + cihaz dili)?
static func current() -> bool:
	var state: Dictionary = load_state()
	return personalized(state["choice"], region(state["country"], OS.get_locale()))
