class_name GallerySaver
extends RefCounted
## GALERİYE KAYDET — fotoğraf modunun çektiği JPEG'i cihazın fotoğraflarına yazar.
##
## Android: eklenti yok; Godot'nun yerleşik JavaClassWrapper + AndroidRuntime köprüsüyle MediaStore'a
## eklenir (ContentResolver.insert + openOutputStream). Android 10+ (API 29) izin İSTEMEZ, dosya
## "Pictures/Auto Yard" klasörüne düşer ve galeride hemen görünür. Android 7–9'da MediaStore'a yazmak
## WRITE_EXTERNAL_STORAGE ister: dışa aktarma eklentisi bu izni manifeste yalnızca API ≤ 28 için ekler
## (maxSdkVersion=28; yeni sürümlerde izin listesinde görünmez). Fotoğraf modu izni ilk çekimden sonra ister.
## Masaüstü: sistemin Resimler klasörü / Auto Yard (bulunamazsa user://photos). Testler `override_dir` verir.

const FOLDER: String = "Auto Yard"
const MIME: String = "image/jpeg"
const LEGACY_PERMISSION: String = "android.permission.WRITE_EXTERNAL_STORAGE"
## MediaStore.RELATIVE_PATH bu sürümden itibaren var (Android 10).
const SCOPED_STORAGE_SDK: int = 29

## Doluysa fotoğraflar platformdan bağımsız buraya yazılır (testler, QA).
static var override_dir: String = ""


## Kaydeder. {"ok": bool, "where": kullanıcıya gösterilecek konum, "error": neden} döner.
static func save_jpeg(bytes: PackedByteArray, file_name: String) -> Dictionary:
	if bytes.is_empty():
		return {"ok": false, "where": "", "error": "empty"}
	if override_dir.is_empty() and OS.get_name() == "Android":
		return _save_android(bytes, file_name)
	return _save_file(bytes, file_name)


## Android 7–9'da galeriye yazmadan önce depolama izni gerekiyor mu (henüz verilmemişse)?
static func needs_legacy_permission() -> bool:
	if not override_dir.is_empty() or OS.get_name() != "Android":
		return false
	if android_sdk() >= SCOPED_STORAGE_SDK:
		return false
	return not OS.get_granted_permissions().has(LEGACY_PERMISSION)


## Cihazın API düzeyi (Build.VERSION.SDK_INT); Android değilse 0.
static func android_sdk() -> int:
	if OS.get_name() != "Android":
		return 0
	var version: JavaClass = JavaClassWrapper.wrap("android.os.Build$VERSION")
	var sdk: Variant = version.get("SDK_INT") if version else null
	if sdk is int:
		return int(sdk)
	# Köprü sabiti vermezse sürüm adından tahmin: "10" → 29, "8.1.0" → 27 (yalnızca eşik için yeterli)
	return SCOPED_STORAGE_SDK if OS.get_version().get_slice(".", 0).to_int() >= 10 else SCOPED_STORAGE_SDK - 1


static func _save_file(bytes: PackedByteArray, file_name: String) -> Dictionary:
	var dir: String = override_dir
	if dir.is_empty():
		var pictures: String = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
		dir = pictures.path_join(FOLDER) if not pictures.is_empty() else ""
	if dir.is_empty() or DirAccess.make_dir_recursive_absolute(dir) != OK:
		dir = ProjectSettings.globalize_path("user://photos")
		DirAccess.make_dir_recursive_absolute(dir)
	var path: String = dir.path_join(file_name)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "where": "", "error": error_string(FileAccess.get_open_error())}
	file.store_buffer(bytes)
	file.close()
	return {"ok": true, "where": path, "error": ""}


static func _save_android(bytes: PackedByteArray, file_name: String) -> Dictionary:
	if not Engine.has_singleton("AndroidRuntime"):
		return {"ok": false, "where": "", "error": "no AndroidRuntime"}
	var runtime: Object = Engine.get_singleton("AndroidRuntime")
	var activity: Object = runtime.call("getActivity")
	if activity == null:
		return {"ok": false, "where": "", "error": "no activity"}
	var sdk: int = android_sdk()
	var values: Object = JavaClassWrapper.wrap("android.content.ContentValues").call("ContentValues")
	values.call("put", "_display_name", file_name)   # MediaStore.MediaColumns.DISPLAY_NAME
	values.call("put", "mime_type", MIME)
	if sdk >= SCOPED_STORAGE_SDK:
		values.call("put", "relative_path", "Pictures/" + FOLDER)
	var media: JavaClass = JavaClassWrapper.wrap("android.provider.MediaStore$Images$Media")
	var collection: Object = media.call("getContentUri", "external")
	var resolver: Object = activity.call("getContentResolver")
	if _java_failed() or collection == null or resolver == null:
		return {"ok": false, "where": "", "error": "resolver"}
	var uri: Object = resolver.call("insert", collection, values)
	if _java_failed() or uri == null:
		return {"ok": false, "where": "", "error": "insert"}   # Android 7–9: izin yok
	var stream: Object = resolver.call("openOutputStream", uri)
	if _java_failed() or stream == null:
		resolver.call("delete", uri, "", PackedStringArray())   # boş kayıt galeride kalmasın (köprü null String eşleştirmez)
		return {"ok": false, "where": "", "error": "open"}
	stream.call("write", bytes)
	var write_failed: bool = _java_failed()
	stream.call("close")
	if write_failed or _java_failed():
		resolver.call("delete", uri, "", PackedStringArray())
		return {"ok": false, "where": "", "error": "write"}
	return {"ok": true, "where": "Pictures/" + FOLDER, "error": ""}


## Son Java çağrısı istisna attıysa günlüğe yazar ve true döner.
static func _java_failed() -> bool:
	var exception: JavaObject = JavaClassWrapper.get_exception()
	if exception == null:
		return false
	push_warning("GallerySaver: %s" % str(exception.call("toString")))
	return true
