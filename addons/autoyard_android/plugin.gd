@tool
extends EditorPlugin
## Android manifestine oyunun kendi eklemelerini yazar.
##
## CAMERA izni (profil fotoğrafı, export_presets: permissions/camera) Play'de
## android.hardware.camera + autofocus özelliklerini ZORUNLU sayar → arka kamerası
## olmayan tablet/Chromebook'lar "desteklenmeyen cihaz" olur. Kamera isteğe bağlı
## (camera_capture.gd akış yoksa "Kamera bulunamadı" der, galeri/avatar kalır), bu
## yüzden ikisi required="false" olarak açıkça bildirilir.

var _export_plugin: AutoYardAndroidExport


func _enter_tree() -> void:
	_export_plugin = AutoYardAndroidExport.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null


class AutoYardAndroidExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "AutoYardAndroid"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	## Sürüm kodu / adı pakete gömülür (AppInfo okur): zorunlu güncelleme ve bulut özeti sürümü export_presets'ten
	## alır, ikinci bir yerde elle tutulmaz.
	func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
		var preset: EditorExportPreset = get_export_preset()
		var info: Dictionary = {
			"code": int(str(preset.get_or_env(&"version/code", ""))),
			"name": str(preset.get_or_env(&"version/name", "")),
		}
		add_file(AppInfo.FILE, JSON.stringify(info).to_utf8_buffer(), false)

	func _get_android_manifest_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
		return ("<uses-feature android:name=\"android.hardware.camera\" android:required=\"false\" />\n"
			+ "<uses-feature android:name=\"android.hardware.camera.autofocus\" android:required=\"false\" />\n")
