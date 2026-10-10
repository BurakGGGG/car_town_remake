extends SceneTree
## YÜKLEME EKRANI SAHNESİNİ ÜRETİR ve oyunun ilk sahnesi yapar (sahne dosyası elle yazılmaz).
##   1) ui/loading/loading_screen.tscn: kök CanvasLayer + LoadingScreen betiği (arayüz kodla kurulur)
##   2) project.godot: run/main_scene → bu sahne; motorun açılış ekranı yükleme ekranının zemin
##      rengiyle aynı (görsel varsa o görsel, ekranı doldurarak) — dokunuştan oyuna tek ekran.
## Kullanım: godot-4 --headless --path . -s res://tools/make_loading_scene.gd
## Görsel (ui/loading/loading_bg.png) sonradan eklenince BU BETİK YENİDEN ÇALIŞTIRILIR (açılış ekranı
## görselini ayarlamak için).

const SCENE_PATH: String = "res://ui/loading/loading_screen.tscn"
const SCRIPT_PATH: String = "res://ui/loading/loading_screen.gd"


func _initialize() -> void:
	var node: CanvasLayer = CanvasLayer.new()
	node.name = "LoadingScreen"
	node.set_script(load(SCRIPT_PATH))
	var packed: PackedScene = PackedScene.new()
	if packed.pack(node) != OK:
		_fail("sahne paketlenemedi")
		return
	if ResourceSaver.save(packed, SCENE_PATH) != OK:
		_fail("sahne kaydedilemedi")
		return
	node.free()
	var uid: int = ResourceLoader.get_resource_uid(SCENE_PATH)
	var main_scene: String = ResourceUID.id_to_text(uid) if uid != ResourceUID.INVALID_ID else SCENE_PATH

	var image: String = "res://ui/loading/loading_bg.png"   # LoadingScreen.LOADING_IMAGE ile aynı
	var settings: Dictionary = {
		"application/run/main_scene": main_scene,
		"application/boot_splash/bg_color": Color("1E2124"),
		"application/boot_splash/show_image": ResourceLoader.exists(image),
	}
	if ResourceLoader.exists(image):
		settings["application/boot_splash/image"] = image
		# 4 = Cover: ekranı doldurur, kenarları kırpar — yükleme ekranındaki TextureRect ile aynı
		# yerleşim (geçiş fark edilmez). 4.7'de eski "fullsize" ayarı yok.
		settings["application/boot_splash/stretch_mode"] = 4
		settings["application/boot_splash/use_filter"] = true
	for key: String in settings:
		if not ProjectSettings.has_setting(key):
			push_warning("ayar anahtarı bulunamadı (yine de yazılıyor): " + key)
		ProjectSettings.set_setting(key, settings[key])
	if ProjectSettings.has_setting("application/boot_splash/fullsize"):
		ProjectSettings.clear("application/boot_splash/fullsize")
	if ProjectSettings.save() != OK:
		_fail("project.godot kaydedilemedi")
		return
	print("TAMAM: %s → ana sahne %s, açılış görseli: %s" % [SCENE_PATH, main_scene, ResourceLoader.exists(image)])
	quit(0)


func _fail(message: String) -> void:
	printerr("make_loading_scene: " + message)
	quit(1)
