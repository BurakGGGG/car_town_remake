class_name AppInfo
extends RefCounted
## Uygulamanın sürüm kodu / adı (Play'in versionCode / versionName'i). ZORUNLU GÜNCELLEME (AppConfig.min_code) ve bulut
## kaydının özeti (players.stats.build) bunu kullanır. Değer dışa aktarma anında export_presets'ten okunup pakete
## res://build_info.json olarak gömülür (addons/autoyard_android: AutoYardAndroidExport._export_begin); sürüm iki
## yerde elle tutulmaz. Editör / masaüstü / testlerde dosya yoktur: kod 0 = geliştirme sürümü, güncelleme istenmez.

const FILE: String = "res://build_info.json"
## Play paket adı (export_presets package/unique_name); geliştirme sürümünde dosya yoktur, bu kullanılır.
const DEFAULT_PACKAGE: String = "com.autoyard.app"

## Testler sürümü taklit eder (0'dan büyükse dosyanın yerine geçer).
static var override_code: int = 0

static var _loaded: bool = false
static var _code: int = 0
static var _name: String = ""
static var _package: String = ""


static func version_code() -> int:
	if override_code > 0:
		return override_code
	_load()
	return _code


static func version_name() -> String:
	_load()
	return _name if not _name.is_empty() else "dev"


## Play paket adı (satın alma doğrulaması sunucuya bununla sorar).
static func package_name() -> String:
	_load()
	return _package if not _package.is_empty() else DEFAULT_PACKAGE


## Geliştirme sürümü mü (paket dışa aktarılmamış).
static func is_dev_build() -> bool:
	return version_code() <= 0


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(FILE):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	if parsed is Dictionary:
		_code = SaveSafe.i((parsed as Dictionary).get("code", 0))
		_name = SaveSafe.s((parsed as Dictionary).get("name", ""))
		_package = SaveSafe.s((parsed as Dictionary).get("package", ""))
