class_name PhotoPicker
extends RefCounted
## GALERİDEN FOTOĞRAF SEÇ: Android'de sistemin kendi seçicisi (DisplayServer yerel dosya penceresi, MIME süzgeci
## image/*; depolama izni GEREKMEZ — seçilen dosyaya tek seferlik erişim verilir). Masaüstünde Godot FileDialog.
## Sonuç: callback(image: Image) — vazgeçildi / okunamadıysa null ve `error` metni (oyuncuya gösterilir).
## Görüntü baytlardan okunur (ProfileCatalog.image_from_bytes: PNG / JPEG / WebP); HEIC gibi biçimler açılmaz.

const FILTER_EXTENSIONS: String = "*.png, *.jpg, *.jpeg, *.webp"
const FILTER_MIME: String = "image/png, image/jpeg, image/webp"


## `host`: masaüstü penceresinin ekleneceği düğüm. callback(image: Image, error: String).
static func pick(host: Node, callback: Callable) -> void:
	var filters: PackedStringArray = PackedStringArray(["%s ; %s ; %s" % [FILTER_EXTENSIONS, Loc.t("Resim dosyaları"), FILTER_MIME]])
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE) and OS.has_feature("android"):
		var err: Error = DisplayServer.file_dialog_show(Loc.t("Profil fotoğrafı seç"), "", "", false,
			DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, filters,
			func(status: bool, paths: PackedStringArray, _filter: int) -> void:
				_finish(callback, status, paths))
		if err != OK:
			callback.call(null, Loc.t("Galeri açılamadı."))
		return
	var dialog: FileDialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE)
	dialog.filters = PackedStringArray(["%s ; %s" % [FILTER_EXTENSIONS, Loc.t("Resim dosyaları")]])
	dialog.title = Loc.t("Profil fotoğrafı seç")
	dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	host.add_child(dialog)
	var done: Array[bool] = [false]
	dialog.file_selected.connect(func(path: String) -> void:
		done[0] = true
		_finish(callback, true, PackedStringArray([path]))
		dialog.queue_free())
	dialog.canceled.connect(func() -> void:
		if not done[0]:
			callback.call(null, "")
		dialog.queue_free())
	dialog.popup_centered_ratio(0.8)


static func _finish(callback: Callable, status: bool, paths: PackedStringArray) -> void:
	if not status or paths.is_empty():
		callback.call(null, "")   # vazgeçildi: mesaj yok
		return
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(paths[0])
	if bytes.is_empty():
		callback.call(null, Loc.t("Fotoğraf okunamadı."))
		return
	var image: Image = ProfileCatalog.image_from_bytes(bytes)
	if image == null:
		callback.call(null, Loc.t("Bu fotoğraf biçimi açılamadı. JPEG ya da PNG seç."))
		return
	callback.call(image, "")
