@tool
class_name CityPreview
extends Node3D
## ŞEHİR ÖNİZLEMESİ (yalnız editör) — oyunun kodla kurduğu şehri (WorldDressing: yol uzantıları, showroom binası, peyzaj,
## kavşak çizgileri, trafik lambaları, billboard) editörün 3B görünümünde gösterir. GarageSystem'in Inspector'ındaki
## "City Preview" kutusu açar / kapatır; "Şehir önizlemesini yenile" düğmesi baştan pişirir.
##
## Oyun kodu editörde ÇALIŞMAZ: ayrı bir Godot süreci (tools/world/bake_city_preview.gd) sahneyi betiklerinden arındırıp
## yalnız WorldDressing'i kurar, sonucu FILE'a yazar; burada o dosya gösterilir. Kaynaklar (world/, assets/world/,
## Main.tscn) değişince önizleme açılırken kendiliğinden yeniden pişer.
## Önizleme sahneye KAYDEDİLMEZ (sahibi yok), seçilip düzenlenemez: değişiklik koddan yapılır.
## Oyunun sahne düğümlerinde yaptığı değişiklikler (gizlenen eski CSG showroom / kavşak çizgileri / yerleştirme ızgarası,
## çimen materyali) burada da uygulanır; kaydederken (NOTIFICATION_EDITOR_PRE_SAVE) geri alınır, Main.tscn'e yazılmaz.
## Kayda bağlı olanlar (garajın içi, araçlar, trafik) yok: onları oyun çalışırken Sahne panelinin Remote sekmesi gösterir.

## Signal: pişirme bitti (başarılı mı).
signal baked(ok: bool)

const FILE: String = "res://.godot/editor_preview/sehir.scn"
const BAKER: String = "res://tools/world/bake_city_preview.gd"
## Önizlemeyi belirleyen kaynaklar: özet bunlardan (biri değişince önizleme eskimiş sayılır).
const SOURCE_DIRS: PackedStringArray = ["res://world/", "res://assets/world/"]
const SOURCE_FILES: PackedStringArray = ["res://Main.tscn", "res://garage_system.gd", BAKER]

var _scene_root: Node
var _content: Node3D
var _applied: Array = []   # [düğüm, özellik, önceki değer, önizleme değeri]
var _pid: int = -1


## Kaynak dosyaların özeti (pişirme anındakiyle karşılaştırılır).
static func source_hash() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for dir: String in SOURCE_DIRS:
		var files: PackedStringArray = DirAccess.get_files_at(dir)
		files.sort()
		for file: String in files:
			if file.ends_with(".gd") or file.ends_with(".glb") or file.ends_with(".png") or file.ends_with(".gdshader"):
				parts.append(file + FileAccess.get_md5(dir + file))
	for file: String in SOURCE_FILES:
		parts.append(file + FileAccess.get_md5(file))
	return "".join(parts).md5_text()


## Önizlemeyi gösterir; dosya yoksa ya da eskimişse (veya `rebuild`) önce pişirir. `scene_root`: Main.tscn kökü.
func show_preview(scene_root: Node, rebuild: bool = false) -> void:
	_scene_root = scene_root
	if not rebuild and _load():
		return
	_bake()


func _load() -> bool:
	if not FileAccess.file_exists(FILE):
		return false
	var packed: PackedScene = ResourceLoader.load(FILE, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if packed == null:
		return false
	var content: Node3D = packed.instantiate() as Node3D
	if content == null:
		return false
	if String(content.get_meta(&"source_hash", "")) != source_hash():
		content.free()
		return false
	_clear()
	_content = content
	add_child(_content)
	_apply(_content.get_meta(&"overrides", []) as Array)
	return true


## Ayrı bir Godot süreci pişirir (gerçek çizici gerekir: 64x64 pencere açılır, betik onu hemen küçültür; birkaç saniye).
func _bake() -> void:
	if _pid > 0 and OS.is_process_running(_pid):
		return
	var args: PackedStringArray = PackedStringArray(["--path", ProjectSettings.globalize_path("res://"),
		"--resolution", "64x64", "--script", BAKER])
	_pid = OS.create_process(OS.get_executable_path(), args)
	if _pid <= 0:
		push_warning("Şehir önizlemesi: pişirme süreci başlatılamadı")
		baked.emit(false)
		return
	print("Şehir önizlemesi pişiriliyor…")
	_poll()


func _poll() -> void:
	if not is_inside_tree():
		return
	if OS.is_process_running(_pid):
		get_tree().create_timer(0.3).timeout.connect(_poll, CONNECT_ONE_SHOT)
		return
	_pid = -1
	var ok: bool = _load()
	if ok:
		print("Şehir önizlemesi hazır")
	else:
		push_warning("Şehir önizlemesi pişirilemedi (Çıktı panelinde ayrıntı yok; elle: %s)" % BAKER)
	baked.emit(ok)


# --- Sahne düğümlerindeki değişiklikler (kaydedilmez) ------------------------------------------------

func _apply(overrides: Array) -> void:
	_restore()
	if _scene_root == null:
		return
	for entry: Array in overrides:
		var node: Node = _scene_root.get_node_or_null(entry[0] as NodePath)
		if node == null:
			continue
		var property: StringName = entry[1]
		_applied.append([node, property, node.get(property), entry[2]])
		node.set(property, entry[2])


func _restore() -> void:
	for entry: Array in _applied:
		if is_instance_valid(entry[0]):
			(entry[0] as Node).set(entry[1], entry[2])
	_applied.clear()


func _reapply() -> void:
	for entry: Array in _applied:
		if is_instance_valid(entry[0]):
			(entry[0] as Node).set(entry[1], entry[3])


func _clear() -> void:
	_restore()
	if is_instance_valid(_content):
		_content.queue_free()
	_content = null


## Önizlemeyi kapatır: sahne düğümleri özgün hâline döner, düğüm silinir.
func dispose() -> void:
	_clear()
	queue_free()


func _put_back() -> void:
	for entry: Array in _applied:
		if is_instance_valid(entry[0]):
			(entry[0] as Node).set(entry[1], entry[2])


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_EDITOR_PRE_SAVE:
			_put_back()   # kaydedilen sahnede özgün değerler olsun
		NOTIFICATION_EDITOR_POST_SAVE:
			_reapply()
		NOTIFICATION_EXIT_TREE:
			_put_back()   # sekme değişti / önizleme kapandı: sahne özgün hâlinde ağaçtan çıkar
		NOTIFICATION_ENTER_TREE:
			_reapply()    # sekmeye dönüldü
			if _pid > 0:
				_poll()   # sekme değişirken pişirme sürüyordu
