class_name GarageVisit
extends RefCounted
## ARKADAŞ GARAJI ZİYARETİ. Oyuncunun kendi sahnesi DONDURULUR: ağaçtan çıkarılır ama bellekte kalır
## (süren tamirler, bekleyen müşteriler, kamera aynen durur; ağaç dışındaki düğümler işlenmez,
## zamanlayıcılar ve tween'ler bekler). Yerine Main.tscn'nin yeni bir kopyası ZİYARET KİPİNDE açılır:
##   - SaveManager.visit_mode: arkadaşın açık garajını (PublicGarage) yükler, HİÇBİR ŞEY KAYDETMEZ
##   - HUD ve CloudSaveManager çıkarılır (Firebase sinyallerine bağlanmaz, ekran / satın alma yok)
##   - GarageSystem kasa / görev / reklam / sosyal / düzenleyici kurmaz (is_visiting)
##   - üstte VisitBar: kimin garajı + GARAJIMA DÖN
## Dönüşte ziyaret sahnesi silinir, kendi sahne aynı düğümleriyle geri takılır (_ready yeniden çalışmaz).
##
## Gruplar ağaca bağlıdır: kendi sahne ağaç dışındayken get_first_node_in_group yalnızca ziyaret
## sahnesinin yöneticilerini bulur. Statik durum (seçili araç) iki geçişte de sıfırlanır.

const MAIN_SCENE: String = "res://Main.tscn"
const CarHitboxScript: GDScript = preload("res://car_hitbox.gd")

static var _home: Node = null
static var _info: Dictionary = {}


static func is_visiting() -> bool:
	return not _info.is_empty()


## {uid, name, code, level, value, garage}
static func info() -> Dictionary:
	return _info


## Ziyaret edilen garaj (kayıt biçiminde açık garaj sözlüğü).
static func garage() -> Dictionary:
	return _info.get("garage", {}) if _info.get("garage") is Dictionary else {}


## Kendi sahneyi dondurup arkadaşın garajını açar.
static func begin(tree: SceneTree, visit_info: Dictionary) -> bool:
	if is_visiting() or tree == null or tree.current_scene == null:
		return false
	if not visit_info.get("garage") is Dictionary or (visit_info["garage"] as Dictionary).is_empty():
		return false
	_info = visit_info.duplicate(true)
	var scene: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	if not _prepare(scene):
		# Kaydı kapatılamayan bir ziyaret sahnesi kendi kaydının üzerine yazabilirdi: hiç açılmaz
		push_error("GarageVisit: ziyaret sahnesinde SaveManager bulunamadı, ziyaret iptal")
		scene.free()
		_info = {}
		return false
	var home: Node = tree.current_scene
	CarHitboxScript.set(&"selected_car", null)
	tree.root.remove_child(home)
	_home = home
	tree.root.add_child(scene)
	tree.current_scene = scene
	return true


## Ziyaret sahnesini kapatıp kendi sahneye döner.
static func end(tree: SceneTree) -> void:
	if not is_visiting() or tree == null:
		return
	var visit_scene: Node = tree.current_scene
	CarHitboxScript.set(&"selected_car", null)
	if visit_scene:
		tree.root.remove_child(visit_scene)
		visit_scene.queue_free()
	_info = {}
	if _home:
		tree.root.add_child(_home)
		tree.current_scene = _home
		_restore_camera(_home)
	_home = null


## Ziyaret sahnesi ağaca girmeden: kaydı kapat, HUD'u ve bulut kaydını çıkar, ziyaret çubuğunu ekle.
## Kaydı kapatılacak SaveManager bulunamazsa false.
static func _prepare(scene: Node) -> bool:
	var removed: Array[Node] = []
	var saves: int = 0
	for node: Node in scene.find_children("*", "", true, false):
		if node is SaveManager:
			(node as SaveManager).visit_mode = true
			saves += 1
		elif node is CloudSaveManager or node is Hud:
			removed.append(node)
	# Döngüden SONRA: HUD silinince çocukları da gider, listede kalanlar geçersiz olurdu
	for node: Node in removed:
		node.get_parent().remove_child(node)
		node.free()
	scene.add_child(VisitBar.new())
	return saves > 0


## Kendi sahnenin kamerası yeniden geçerli olsun (ziyaret kamerası silindi).
static func _restore_camera(home: Node) -> void:
	for node: Node in home.find_children("*", "Camera3D", true, false):
		var camera: Camera3D = node as Camera3D
		if camera.current:
			camera.make_current()
			return
