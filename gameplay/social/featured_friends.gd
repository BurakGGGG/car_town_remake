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
## Öne çıkan garaj JSON'unun üst sınırı (açık garajlarınki PublicGarage.MAX_JSON).
const FEATURED_MAX_JSON: int = 60000
## PROFİL (2026-10-16): portre res://assets/ui/avatars/<kimlik>.png (tools/avatars/src/*.svg), çerçeve, bayrak,
## garaj adı, vitrin aracı, yarış sayıları. Koleksiyon "hepsi": Emre ve Elif yarışta her araca sahiptir (kullanıcı
## kararı; garajları değişmez). En iyi 300 m, en iyi aracının fabrika süresinden hesaplanır.
const PROFILES: Dictionary = {
	"featured_emre": {"frame": "neon", "flag": "TR", "title": "Gece Garajı", "car": "lambo_huracan",
		"wins": 412, "races": 498, "best_car": "lambo_huracan"},
	"featured_elif": {"frame": "rainbow", "flag": "TR", "title": "Pamuk Garaj", "car": "fiat_500_1965",
		"wins": 287, "races": 401, "best_car": "vw_golf_7"},
}

## YARIŞ RAKİBİ (2026-10-16): Emre ve Elif yarışta HER araca sahiptir; hangisinin geleceği aracın karakterine
## göre (kullanıcı kararı: havalı / spor / süper / premium → Emre, tatlı / şehir / aile → Elif). Listede olmayan
## (yeni eklenen) araç sınıfına göre: S / A → Emre, diğerleri → Elif.
## 2026-10-20: sekizinci partinin 15 aracı aynı kurala göre eklendi (Emre 8 süper / premium / spor, Elif 7 aile /
## şehir / ticari).
const EMRE_CARS: Array[String] = ["bmw_e46", "bmw_e60", "mercedes_cls", "mercedes_s400", "audi_rs6", "audi_a3",
	"porsche_gt3", "lambo_huracan", "ferrari_488_pista", "chevrolet_camaro", "alfa_romeo_159", "seat_leon",
	"honda_civic", "vw_golf_7", "togg_t10f",
	"bugatti_chiron", "bugatti_veyron", "ferrari_laferrari", "porsche_taycan", "mercedes_g", "audi_a6", "bmw_f30",
	"cupra_formentor"]
const ELIF_CARS: Array[String] = ["tofas_sahin", "renault_toros", "hyundai_era", "hyundai_getz", "hyundai_accent_blue",
	"renault_fluence", "vw_passat_b55", "ford_focus", "opel_corsa", "skoda_kamiq", "vw_beetle", "togg_t10x",
	"tesla_model_y", "volvo_s60",
	"toyota_corolla", "renault_megane_4", "vw_passat_b8", "skoda_superb", "chery_tiggo_8", "ford_transit",
	"mercedes_sprinter"]

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


## Bu aracı yarışa Emre mi Elif mi getirir (kimlik).
static func owner_for_car(vehicle_id: StringName) -> String:
	var id: String = String(vehicle_id)
	if EMRE_CARS.has(id):
		return "featured_emre"
	if ELIF_CARS.has(id):
		return "featured_elif"
	var car_class: String = String(CarCatalog.get_entry(vehicle_id).get("class", "D"))
	return "featured_emre" if car_class in ["S", "A"] else "featured_elif"


## Yarış rakibi sahibi sözlüğü (RaceManager.rival_owner biçimi): fabrika rengi, modifiyesiz.
static func rival_owner(uid: String) -> Dictionary:
	var entry: Dictionary = get_entry(uid)
	if entry.is_empty():
		return {}
	return {"uid": uid, "name": entry["name"], "av": "", "frame": entry["frame"], "flag": entry["flag"],
		"featured": true, "paint": "", "build": {}}


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
	var missions: MissionManager = tree.get_first_node_in_group("missions") as MissionManager
	if missions:
		missions.count(&"garage_visits", 1)   # etkinlik görevi "ARKADAŞ GARAJI ZİYARET ET" (kayıttan önce)
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
	# Oyunla gelir, sunucuya yazılmaz: Firestore'un 20 KB sınırı yerine geniş bir güvenlik sınırı
	var garage: Dictionary = PublicGarage.parse(JSON.stringify(data.get("garage", {})), FEATURED_MAX_JSON)
	if garage.is_empty():
		push_error("FeaturedFriends: %s garajı geçersiz" % path)
		return {}
	var profile: Dictionary = PROFILES.get(id, {})
	var best_car: String = SaveSafe.s(profile.get("best_car", ""))
	return {
		"uid": id,
		"name": SaveSafe.s(data.get("name", "")),
		"level": maxi(SaveSafe.i(data.get("level", 1)), 1),
		"value": SaveSafe.i(data.get("value", 0)),
		"featured": true,
		"garage": garage,
		"av": "",
		"frame": SaveSafe.s(profile.get("frame", ProfileCatalog.DEFAULT_FRAME)),
		"flag": SaveSafe.s(profile.get("flag", "")),
		"title": SaveSafe.s(profile.get("title", "")),
		"car": SaveSafe.s(profile.get("car", "")),
		"stats": {
			"wins": SaveSafe.i(profile.get("wins", 0)),
			"races": SaveSafe.i(profile.get("races", 0)),
			"cars": CollectionRewards.total_count(),
			"best": int(round(DragRaceSim.base_time(StringName(best_car)) * 1000.0)) if not best_car.is_empty() else 0,
			"best_car": best_car,
		},
	}
