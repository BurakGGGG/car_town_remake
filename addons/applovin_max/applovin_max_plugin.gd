@tool
extends EditorPlugin
## AppLovin MAX — v2 dışa aktarma sarmalayıcısı (AUTO YARD, 2026-10-19).
##
## Resmi eklenti (AppLovin/AppLovin-MAX-Godot 1.2.0, MIT) Android tarafını Godot 4.2'de kullanımdan kalkan v1
## biçimiyle (.gdap + res://android/plugins/) dağıtıyor; android/ klasörü git'te değil, şablon yeniden kurulunca
## kaybolurdu. Bu yüzden aynı AAR burada EditorExportPlugin ile eklenir. AAR'ın manifest'i hâlâ v1 adını
## taşır (org.godotengine.plugin.v1.AppLovinMAX); Godot 4.7.2 çalışma zamanı v1 adlı eklentiyi uyarıyla yükler.
##
## Resmi .gdap AppLovin SDK'sını hiç eklemiyor (AAR'da compileOnly) → SDK sürümü burada sabitlenir.
## Resmi sürümden farklar: AppLovinMAX.gd'de test cihazı kimlikleri Java'ya HİÇ geçirilmiyordu (resmi hata #62)
## ve dizi parametreleri PackedStringArray olarak gönderiliyor (Java String[] bekler).

const AAR: String = "applovin_max/bin/AppLovin-MAX-Godot-Plugin.aar"
const DEPENDENCIES: PackedStringArray = [
	"com.applovin:applovin-sdk:13.6.4",
]

var _export_plugin: AndroidExportPlugin


func _enter_tree() -> void:
	_export_plugin = AndroidExportPlugin.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null


class AndroidExportPlugin extends EditorExportPlugin:
	func _get_name() -> String:
		return "AppLovinMAX"


	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid


	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray([AAR])


	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return DEPENDENCIES
