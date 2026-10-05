class_name FeaturedFriends
extends RefCounted
## ÖNE ÇIKAN ARKADAŞLAR: herkesin listesinde duran, oyunla gelen iki garaj (Hay Day'deki Greg gibi).
## Sunucu gerekmez: garajlar res://gameplay/social/featured/*.json'dadır (açık garaj biçimi, PublicGarage),
## giriş yapmamış oyuncu da ve çevrimdışı da gezebilir. Çıkarılamazlar, istek / kod yoktur.
##
## Tasarım ve dışa aktarma: tools/featured/ (featured_designs.gd → build_featured.gd --export).
## Garajlar gerçek oyunda, oyunun kendi yerleşim kurallarıyla doğrulanarak üretilir; elle düzenlenmez.

const DIR: String = "res://gameplay/social/featured/"
## Listede görünme sırası.
const IDS: Array[String] = ["featured_emre", "featured_elif"]
## Kimlik öneki (gerçek UID'lerle karışmaz: Firebase UID'leri bu öneki taşımaz).
const PREFIX: String = "featured_"

static var _entries: Array[Dictionary] = []
static var _loaded: bool = false


static func is_featured(uid: String) -> bool:
	return uid.begins_with(PREFIX)


## {uid, name, level, value, featured: true, garage}; okunamayan dosya atlanır.
static func all() -> Array[Dictionary]:
	if not _loaded:
		_loaded = true
		for id: String in IDS:
			var entry: Dictionary = _load(id)
			if not entry.is_empty():
				_entries.append(entry)
	return _entries


static func get_entry(uid: String) -> Dictionary:
	for entry: Dictionary in all():
		if entry["uid"] == uid:
			return entry
	return {}


## Kendi kaydı diske yazılır, sonra garaja gidilir. Bulut yazması sürüyorsa beklenir (false).
static func visit(tree: SceneTree, uid: String) -> bool:
	var entry: Dictionary = get_entry(uid)
	if entry.is_empty() or tree == null:
		return false
	var cloud: CloudSaveManager = tree.get_first_node_in_group("cloud_save") as CloudSaveManager
	if cloud and cloud.is_busy():
		return false
	var save: SaveManager = tree.get_first_node_in_group("save_manager") as SaveManager
	if save:
		save.save_game()
	return GarageVisit.begin(tree, {
		"uid": uid, "name": entry["name"], "code": "", "level": entry["level"], "value": entry["value"],
		"garage": (entry["garage"] as Dictionary).duplicate(true),
	})


static func _load(id: String) -> Dictionary:
	var path: String = DIR + id + ".json"
	if not FileAccess.file_exists(path):
		push_error("FeaturedFriends: %s yok" % path)
		return {}
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not raw is Dictionary:
		push_error("FeaturedFriends: %s okunamadı" % path)
		return {}
	var data: Dictionary = raw
	var garage: Dictionary = PublicGarage.parse(JSON.stringify(data.get("garage", {})))
	if garage.is_empty():
		push_error("FeaturedFriends: %s garajı geçersiz" % path)
		return {}
	return {
		"uid": id,
		"name": SaveSafe.s(data.get("name", "")),
		"level": maxi(SaveSafe.i(data.get("level", 1)), 1),
		"value": SaveSafe.i(data.get("value", 0)),
		"featured": true,
		"garage": garage,
	}
