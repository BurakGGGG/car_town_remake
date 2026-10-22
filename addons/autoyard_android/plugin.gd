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
	func _export_begin(_features: PackedStringArray, is_debug: bool, _path: String, _flags: int) -> void:
		var preset: EditorExportPreset = get_export_preset()
		var info: Dictionary = {
			"code": int(str(preset.get_or_env(&"version/code", ""))),
			"name": str(preset.get_or_env(&"version/name", "")),
			"package": str(preset.get_or_env(&"package/unique_name", "")),
		}
		add_file(AppInfo.FILE, JSON.stringify(info).to_utf8_buffer(), false)
		_set_profileable(is_debug)

	func _get_android_manifest_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
		var xml: String = ("<uses-feature android:name=\"android.hardware.camera\" android:required=\"false\" />\n"
			+ "<uses-feature android:name=\"android.hardware.camera.autofocus\" android:required=\"false\" />\n")
		if _appodeal():
			# Konum oyunun işlevi değil: reklam ağlarının getirdiği konum izinleri birleşik manifest'ten çıkarılır
			# (Appodeal belgesi; Play'de konum beyanı gerekmesin).
			for permission: String in ["android.permission.ACCESS_COARSE_LOCATION", "android.permission.ACCESS_FINE_LOCATION"]:
				xml += "<uses-permission android:name=\"%s\" tools:node=\"remove\" />\n" % permission
		return xml

	# REKLAM AĞI APPODEAL (2026-10-22): SDK + ağ adaptörleri Gradle bağımlılığı olarak gelir (eklenti AAR'ı yok; oyun
	# Java köprüsüyle konuşur, ads/appodeal_provider.gd). Liste ve depo AdConfig'te; ağ değişince ikisi de düşer.
	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return AdConfig.APPODEAL_DEPENDENCIES if _appodeal() else PackedStringArray()

	func _get_android_dependencies_maven_repos(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray([AdConfig.APPODEAL_MAVEN]) if _appodeal() else PackedStringArray()

	func _appodeal() -> bool:
		return AdConfig.NETWORK == AdConfig.Network.APPODEAL

	## Godot şablonu <profileable android:shell="true" android:enabled="true"> getirir: kabuktan profil araçlarının
	## uygulamaya bağlanmasına izin verir. Yayın derlemesinde kapatılır, hata ayıklamada açık kalır (performans ölçümü).
	## android/ git dışında: her dışa aktarmada derleme türüne göre yeniden yazılır.
	const PROFILEABLE_ON := "<profileable\n            android:shell=\"true\"\n            android:enabled=\"true\""
	const PROFILEABLE_OFF := "<profileable\n            android:shell=\"false\"\n            android:enabled=\"false\""

	func _set_profileable(on: bool) -> void:
		var manifest: String = "res://android/build/src/main/AndroidManifest.xml"
		if not FileAccess.file_exists(manifest):
			return
		var text: String = FileAccess.get_file_as_string(manifest)
		var want: String = PROFILEABLE_ON if on else PROFILEABLE_OFF
		var other: String = PROFILEABLE_OFF if on else PROFILEABLE_ON
		if text.contains(want) or not text.contains(other):
			if not text.contains(want):
				push_warning("AutoYardAndroid: şablon manifest'inde beklenen <profileable> yok, dokunulmadı")
			return
		var file: FileAccess = FileAccess.open(manifest, FileAccess.WRITE)
		file.store_string(text.replace(other, want))
		file.close()
