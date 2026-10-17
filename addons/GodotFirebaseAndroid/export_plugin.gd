@tool
extends EditorPlugin

var export_plugin : AndroidExportPlugin

# Firebase plugin lines to inject into Gradle files
const BUILD_GRADLE_PLUGIN_LINE := "id 'com.google.gms.google-services'"
const SETTINGS_GRADLE_PLUGIN_LINE := "id 'com.google.gms.google-services' version '4.4.2' apply false"

const DEPENDENCIES := [
	"com.google.firebase:firebase-auth:23.2.0",
	"com.google.android.gms:play-services-auth:21.3.0",
	"com.google.firebase:firebase-firestore:25.1.4",
	"com.google.firebase:firebase-database:21.0.0",
	"com.google.firebase:firebase-storage:21.0.1",
	# CarTownRemake eki (2026-10-17): telefon bildirimi (FCM). Eklentide mesajlaşma modülü yok; jeton oyundan
	# JavaClassWrapper ile alınır (gameplay/social/push_service.gd), bildirimi sunucu gönderir (firebase/functions).
	"com.google.firebase:firebase-messaging:24.1.0"
]

func _enter_tree():
	export_plugin = AndroidExportPlugin.new()
	add_export_plugin(export_plugin)

func _exit_tree():
	remove_export_plugin(export_plugin)
	export_plugin = null

# CarTownRemake değişikliği (upstream be573b1'den tek fark): projede autoload yok kuralı nedeniyle
# "Firebase" autoload'u eklenmez. Oyun plugin'e gameplay/cloud_save_manager.gd içinden
# Engine.get_singleton("GodotFirebaseAndroid") ile doğrudan bağlanır.
func _enable_plugin() -> void:
	pass

func _disable_plugin() -> void:
	_cleanup_gradle_files()

func _cleanup_gradle_files() -> void:
	_clean_line_from_file("res://android/build/build.gradle", BUILD_GRADLE_PLUGIN_LINE)
	_clean_line_from_file("res://android/build/settings.gradle", SETTINGS_GRADLE_PLUGIN_LINE)

func _clean_line_from_file(file_path: String, line_to_remove: String) -> void:
	if FileAccess.file_exists(file_path):
		var text := FileAccess.open(file_path, FileAccess.READ).get_as_text()
		text = text.replace(line_to_remove, "")
		var file := FileAccess.open(file_path, FileAccess.WRITE)
		file.store_string(text)
		file.close()


class AndroidExportPlugin extends EditorExportPlugin:
	var _plugin_name = "GodotFirebaseAndroid"
	
	func _export_begin(features: PackedStringArray, is_debug: bool, path: String, flags: int) -> void:
		if not features.has("android"):
			return
		_ensure_invite_link_alias()
		
		if (not get_option("gradle_build/use_gradle_build")) or (not FileAccess.file_exists("res://android/build/google-services.json")):
			_clean_line_from_file("res://android/build/build.gradle", BUILD_GRADLE_PLUGIN_LINE)
			_clean_line_from_file("res://android/build/settings.gradle", SETTINGS_GRADLE_PLUGIN_LINE)
			return
		
		# Modify build.gradle and settings.gradle
		_insert_line_if_missing("res://android/build/build.gradle", "id 'org.jetbrains.kotlin.android'", BUILD_GRADLE_PLUGIN_LINE)
		_insert_line_if_missing("res://android/build/settings.gradle", "id 'org.jetbrains.kotlin.android' version versions.kotlinVersion", SETTINGS_GRADLE_PLUGIN_LINE)

	# CarTownRemake eki (2026-10-17): ARKADAŞ DAVET LİNKİ — autoyard://davet/<jeton> oyunu açar (web sayfası /d/<jeton>
	# yönlendirir; oyun linki gameplay/social/invite_links.gd ile okur). Ana etkinlik dışa KAPALI (exported=false) ve
	# eklentilerin uygulama içeriği birleşik manifest'te etkinlikten ÖNCE geliyor (takma ad hedefinden önce gelirse uygulama
	# kurulmaz). Bu yüzden takma ad şablonun ANA manifest'ine, başlatıcı takma adının hemen ardına yazılır — her dışa
	# aktarımda denetlenir: android/ git'te değil, şablon yeniden kurulsa da geri gelir.
	const INVITE_ALIAS_MARK := "<!-- autoyard-invite-link -->"
	const INVITE_ALIAS := """
        <!-- autoyard-invite-link -->
        <activity-alias
            android:name=".InviteLink"
            android:targetActivity=".GodotApp"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="autoyard" android:host="davet" />
            </intent-filter>
        </activity-alias>"""

	func _ensure_invite_link_alias() -> void:
		var manifest := "res://android/build/src/main/AndroidManifest.xml"
		if not FileAccess.file_exists(manifest):
			return
		var text := FileAccess.get_file_as_string(manifest)
		if text.contains(INVITE_ALIAS_MARK):
			return
		var anchor := "</activity-alias>"
		var at := text.find(anchor)
		if at < 0:
			push_warning("Davet linki: şablon manifest'inde başlatıcı takma adı yok, link oyunu açamayacak")
			return
		text = text.insert(at + anchor.length(), INVITE_ALIAS)
		var file := FileAccess.open(manifest, FileAccess.WRITE)
		file.store_string(text)
		file.close()

	# CarTownRemake eki (2026-10-17): FOTOĞRAF MODU — Android 7–9'da (API ≤ 28) galeriye kaydetmek depolama izni ister.
	# Yalnızca o sürümler için bildirilir (maxSdkVersion): Android 10+ izin istemez ve listede görünmez. Oyun izni
	# girişte değil, ilk fotoğraf çekildikten sonra kaydederken ister (ui/hud/photo_mode.gd).
	func _get_android_manifest_element_contents(platform: EditorExportPlatform, debug: bool) -> String:
		return '<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28" />'

	func _insert_line_if_missing(file_path: String, after_line: String, insert_line: String) -> void:
		var text := FileAccess.open(file_path, FileAccess.READ).get_as_text()
		if text.contains(insert_line):
			return
		
		var lines := text.split("\n")
		var result := PackedStringArray()
		var inserted := false
		
		for line in lines:
			result.append(line)
			if not inserted and line.strip_edges() == after_line.strip_edges():
				var indent := ""
				for c in line:
					if c == " " or c == "\t":
						indent += c
					else:
						break
				result.append(indent + insert_line)
				inserted = true
		
		var file := FileAccess.open(file_path, FileAccess.WRITE)
		file.store_string("\n".join(result))
		file.close()

	func _clean_line_from_file(file_path: String, line_to_remove: String) -> void:
		if FileAccess.file_exists(file_path):
			var text := FileAccess.open(file_path, FileAccess.READ).get_as_text()
			text = text.replace(line_to_remove, "")
			var file := FileAccess.open(file_path, FileAccess.WRITE)
			file.store_string(text)
			file.close()

	func _supports_platform(platform):
		if platform is EditorExportPlatformAndroid:
			return true
		return false

	func _get_android_libraries(platform, debug):
		if debug:
			return PackedStringArray([_plugin_name + "/bin/debug/" + _plugin_name + "-debug.aar"])
		else:
			return PackedStringArray([_plugin_name + "/bin/release/" + _plugin_name + "-release.aar"])

	func _get_android_dependencies(platform, debug):
		if debug:
			return PackedStringArray(DEPENDENCIES)
		else:
			return PackedStringArray(DEPENDENCIES)

	func _get_name():
		return _plugin_name
