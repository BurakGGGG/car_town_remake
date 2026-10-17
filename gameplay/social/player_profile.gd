class_name PlayerProfile
extends Node
## OYUNCU PROFİLİ: profil fotoğrafı, çerçeve, bayrak, garaj adı, vitrin aracı + engellenen oyuncular ve şikâyet
## edilip gizlenen fotoğraflar. GarageSystem kodla kurar (ziyaret kipinde yok); "player_profile" grubundan bulunur.
## Kayıt: SaveManager "profile" bölümü (eski kayıtta yoktur: varsayılanlar). Açık kısım (avatar tanımı, çerçeve,
## bayrak, garaj adı, vitrin aracı) SocialManager tarafından açık garaj belgesine yazılır (public_fields).
##
## FOTOĞRAF (kullanıcı kararı 2026-10-16): kaynak galeri / kamera / 12 hazır avatar / Google. Google fotoğrafı
## YALNIZCA oyuncu açarsa avatar olur (2026-10-17, gizlilik: önceden varsayılan açıktı ve herkese görünüyordu):
## profil düzenlemede GOOGLE düğmesi ya da "GOOGLE: AÇIK". Kayıtta "google_photo" anahtarı; eski "use_google"
## (varsayılanı true idi, oyuncu seçmeden yazılıyordu) okunmaz: herkes kapalı başlar.
##   avatar ""      → otomatik: Google fotoğrafı (oyuncu açtıysa ve inmişse), yoksa kask (ProfileCatalog.DEFAULT_PRESET)
##   avatar "pNN"   → hazır avatar
##   avatar "photo" → galeri / kamera fotoğrafı (user://profile/photo.jpg, 192 px JPEG)
## Yüklenen resim (fotoğraf ya da Google) arkadaşlara avatars/a_{uid} belgesiyle gider; tanım "img:<hash>".
## Fotoğraf yalnızca bu cihazda dosyadır: yeni cihazda SocialManager kendi avatar belgesinden geri yükler
## (restore_photo). Misafir fotoğraf seçemez (sosyal özellikler Google girişi ister).

## Profil değişti (kayıt + yayın + ekranlar).
signal changed
## Kendi avatar resmi değişti (HUD düğmesi, profil kartı).
signal avatar_changed

const DIR: String = "user://profile/"
const PHOTO_PATH: String = "user://profile/photo.jpg"
const GOOGLE_PATH: String = "user://profile/google.jpg"
const GOOGLE_META: String = "user://profile/google.json"
## Google fotoğrafı bu boyda istenir (URL'deki "=s96-c" değiştirilir).
const GOOGLE_SIZE: int = 256
const MAX_BLOCKED: int = 200
const MAX_HIDDEN: int = 200

var avatar: String = ""
var photo_hash: String = ""
var use_google: bool = false
var frame_id: String = ProfileCatalog.DEFAULT_FRAME
var frames_owned: Array[String] = []
var flag: String = ""
var title: String = ""
var showcase: StringName = &""
## Garajın toplam beğenisi (arkadaşlar ziyarette kalbe basar; SocialManager ziyaretçi başına günde bir sayar).
var likes: int = 0
## uid → takma ad (ENGELLENENLER listesinde gösterilir).
var blocked: Dictionary = {}
## uid → avatar hash: şikâyet edenin ekranında gizlenen fotoğraf (oyuncu fotoğrafını değiştirirse yenisi görünür).
var hidden: Dictionary = {}

var _photo_tex: Texture2D
var _google_tex: Texture2D
var _google: Dictionary = {}   # {uid, url, hash}
var _cloud: CloudSaveManager
var _http: HTTPRequest
var _pending_url: String = ""


func _ready() -> void:
	add_to_group("player_profile")
	_load_files()
	_connect_cloud.call_deferred()


# --- Kayıt -----------------------------------------------------------------------

func state() -> Dictionary:
	return {
		"avatar": avatar, "photo_hash": photo_hash, "google_photo": use_google, "frame": frame_id,
		"frames": frames_owned.duplicate(), "flag": flag, "title": title, "showcase": String(showcase),
		"blocked": blocked.duplicate(), "hidden": hidden.duplicate(), "likes": likes,
	}


func load_state(data: Dictionary) -> void:
	reset()
	var av: String = SaveSafe.s(data.get("avatar", ""))
	avatar = av if av == "photo" or ProfileCatalog.is_preset(av) else ""
	photo_hash = SaveSafe.s(data.get("photo_hash", ""))
	if not ProfileCatalog.is_hash(photo_hash):
		photo_hash = ""
	use_google = bool(data.get("google_photo", false))
	var owned: Variant = data.get("frames", [])
	if owned is Array:
		for id: Variant in owned:
			var frame: String = SaveSafe.s(id)
			if ProfileCatalog.is_frame(frame) and int(ProfileCatalog.frame(frame)["gems"]) > 0 and not frames_owned.has(frame):
				frames_owned.append(frame)
	var chosen: String = SaveSafe.s(data.get("frame", ProfileCatalog.DEFAULT_FRAME))
	frame_id = chosen if ProfileCatalog.is_frame(chosen) else ProfileCatalog.DEFAULT_FRAME
	var code: String = SaveSafe.s(data.get("flag", ""))
	flag = code if ProfileCatalog.is_flag(code) else ""
	var raw_title: String = ProfileCatalog.clean_title(SaveSafe.s(data.get("title", "")))
	title = raw_title if SocialNames.is_valid_title(raw_title) else ""
	var car: StringName = StringName(SaveSafe.s(data.get("showcase", "")))
	showcase = car if not CarCatalog.get_entry(car).is_empty() else &""
	likes = maxi(SaveSafe.i(data.get("likes", 0)), 0)
	for key: String in ["blocked", "hidden"]:
		var raw: Variant = data.get(key, {})
		if not raw is Dictionary:
			continue
		var target: Dictionary = blocked if key == "blocked" else hidden
		for uid: Variant in raw:
			if target.size() < (MAX_BLOCKED if key == "blocked" else MAX_HIDDEN):
				target[SaveSafe.s(uid)] = SaveSafe.s((raw as Dictionary)[uid])
	_photo_tex = _texture_from_file(PHOTO_PATH) if avatar == "photo" else null
	changed.emit()
	avatar_changed.emit()


func reset() -> void:
	avatar = ""
	photo_hash = ""
	use_google = false
	frame_id = ProfileCatalog.DEFAULT_FRAME
	frames_owned.clear()
	flag = ""
	title = ""
	showcase = &""
	likes = 0
	blocked.clear()
	hidden.clear()


# --- Kendi avatarım --------------------------------------------------------------

## Açık garaja yazılan avatar tanımı ("" / "pNN" / "img:<hash>").
func my_av() -> String:
	if avatar == "photo" and _photo_tex and not photo_hash.is_empty():
		return "img:" + photo_hash
	if ProfileCatalog.is_preset(avatar):
		return avatar
	if google_active():
		return "img:" + SaveSafe.s(_google.get("hash", ""))
	return ""


func my_texture() -> Texture2D:
	if avatar == "photo" and _photo_tex:
		return _photo_tex
	if ProfileCatalog.is_preset(avatar):
		return ProfileCatalog.preset_texture(avatar)
	if google_active():
		return _google_tex
	return ProfileCatalog.default_texture()


## Kendi resmim çizim mi (hazır avatar / kask): küçük boyda yüze yakın kırpılır.
func my_illustrated() -> bool:
	var av: String = my_av()
	return not av.begins_with("img:")


## avatars/a_{uid} belgesine yazılacak JPEG baytları (yüklenen resim yoksa boş).
func upload_bytes() -> PackedByteArray:
	var av: String = my_av()
	if not av.begins_with("img:"):
		return PackedByteArray()
	var path: String = PHOTO_PATH if avatar == "photo" else GOOGLE_PATH
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()


## Google fotoğrafı şu an avatar mı (seçim otomatik, izin açık, resim bu hesabın ve inmiş).
func google_active() -> bool:
	return avatar.is_empty() and use_google and _google_tex != null and _google_matches_account()


## Bu hesabın Google fotoğrafı var mı (profil düzenlemede GOOGLE seçeneği).
func has_google_photo() -> bool:
	return _google_tex != null and _google_matches_account()


func google_texture() -> Texture2D:
	return _google_tex if has_google_photo() else null


## Fotoğraf seçildi ama bu cihazda dosyası yok (yeni cihaz / yeniden kurulum): SocialManager geri yükler.
func needs_photo_restore() -> bool:
	return avatar == "photo" and not photo_hash.is_empty() and _photo_tex == null


# --- Seçimler --------------------------------------------------------------------

func set_preset(av: String) -> void:
	if not ProfileCatalog.is_preset(av) or avatar == av:
		return
	avatar = av
	_changed(true)


## Galeri / kamera görüntüsü (kırpılmış kare): kodlanır, cihazda saklanır, avatar olur.
func set_photo(image: Image) -> bool:
	if image == null or image.is_empty():
		return false
	var bytes: PackedByteArray = ProfileCatalog.encode_photo(image)
	if bytes.is_empty() or not _write_bytes(PHOTO_PATH, bytes):
		return false
	photo_hash = ProfileCatalog.hash_of(bytes)
	_photo_tex = _texture_from_bytes(bytes)
	avatar = "photo"
	_changed(true)
	return true


## Sunucudaki kendi avatar belgesinden fotoğrafı geri yükler (yalnızca hash kayıttakiyle aynıysa).
func restore_photo(bytes: PackedByteArray) -> bool:
	if not needs_photo_restore() or ProfileCatalog.hash_of(bytes) != photo_hash:
		return false
	if not _write_bytes(PHOTO_PATH, bytes):
		return false
	_photo_tex = _texture_from_bytes(bytes)
	avatar_changed.emit()
	return _photo_tex != null


## Otomatik (Google ya da kask): elle seçilen avatar / fotoğraf bırakılır.
func set_auto() -> void:
	if avatar.is_empty():
		return
	avatar = ""
	_changed(true)


func set_use_google(on: bool) -> void:
	if use_google == on:
		return
	use_google = on
	_changed(true)


## Çerçeve oyuncunun mu: seviyesi yetiyor ya da elmasla alınmış.
func frame_unlocked(id: String) -> bool:
	var entry: Dictionary = ProfileCatalog.frame(id)
	if entry.is_empty():
		return false
	if int(entry["gems"]) > 0:
		return frames_owned.has(id)
	return _level() >= int(entry["level"])


func set_frame(id: String) -> bool:
	if not frame_unlocked(id):
		return false
	if frame_id != id:
		frame_id = id
		_changed(false)
	return true


## Elmaslı çerçeveyi satın alır ve takar. Elmas yetmezse false.
func buy_frame(id: String) -> bool:
	var entry: Dictionary = ProfileCatalog.frame(id)
	var price: int = int(entry.get("gems", 0))
	if price <= 0 or frames_owned.has(id):
		return set_frame(id)
	var progress: PlayerProgress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress
	if progress == null or not progress.spend_gems(price):
		return false
	frames_owned.append(id)
	frame_id = id
	_changed(false)
	return true


func set_flag(code: String) -> void:
	var value: String = code if ProfileCatalog.is_flag(code) else ""
	if flag != value:
		flag = value
		_changed(false)


## Garaj adı; geçersizse (küfür / karakter) false ve değişmez.
func set_title(raw: String) -> bool:
	var value: String = ProfileCatalog.clean_title(raw)
	if not SocialNames.is_valid_title(value):
		return false
	if title != value:
		title = value
		_changed(false)
	return true


func set_showcase(vehicle_id: StringName) -> void:
	if vehicle_id != &"" and CarCatalog.get_entry(vehicle_id).is_empty():
		return
	if showcase != vehicle_id:
		showcase = vehicle_id
		_changed(false)


## Vitrin aracı: seçilen (hâlâ sahipse), yoksa yarış aracı.
func showcase_vehicle() -> StringName:
	var ownership: VehicleOwnership = get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	if ownership == null:
		return showcase
	if showcase != &"" and ownership.is_owned(showcase):
		return showcase
	return ownership.race_vehicle_id()


# --- Engelleme / gizleme ---------------------------------------------------------

func is_blocked(uid: String) -> bool:
	return blocked.has(uid)


func block(uid: String, name: String) -> void:
	if uid.is_empty() or FeaturedFriends.is_featured(uid):
		return
	blocked[uid] = name
	while blocked.size() > MAX_BLOCKED:
		blocked.erase(blocked.keys()[0])
	_changed(false)


func unblock(uid: String) -> void:
	if blocked.erase(uid):
		_changed(false)


## Şikâyet edilen fotoğraf bu oyuncunun ekranında gizlenir (aynı hash; yenisini yüklerse görünür).
func hide_photo(uid: String, hash: String) -> void:
	if uid.is_empty() or hash.is_empty():
		return
	hidden[uid] = hash
	while hidden.size() > MAX_HIDDEN:
		hidden.erase(hidden.keys()[0])
	_changed(false)


func is_hidden(uid: String, hash: String) -> bool:
	return not hash.is_empty() and SaveSafe.s(hidden.get(uid, "")) == hash


# --- Açık profil -----------------------------------------------------------------

## Açık garaj belgesine eklenen alanlar (firestore.rules isValidGarage ile aynı anahtarlar).
func public_fields() -> Dictionary:
	return {
		"av": my_av(),
		"frame": frame_id,
		"flag": flag,
		"title": title,
		"car": String(showcase_vehicle()),
		"stats": stats(),
	}


## Profil kartındaki istatistikler (kendi oyunumdan): yarış galibiyeti / sayısı, koleksiyon, en iyi 300 m.
func stats() -> Dictionary:
	var out: Dictionary = {"wins": 0, "races": 0, "cars": 0, "best": 0, "best_car": ""}
	var race: RaceManager = get_tree().get_first_node_in_group("race") as RaceManager
	if race:
		out["wins"] = race.wins()
		out["races"] = race.races()
		var best: Dictionary = race.overall_best()
		if not best.is_empty():
			out["best"] = int(round(float(best["time"]) * 1000.0))
			out["best_car"] = String(best["vehicle"])
	var ownership: VehicleOwnership = get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	if ownership:
		out["cars"] = ownership.discovered_count()
	if likes > 0:
		out["likes"] = likes   # yalnız varken: beğeni kuralı yüklenmeden önceki sunucu bu alanı reddederdi
	return out


## Bir arkadaş garajı beğendi (SocialManager ziyaretçi başına günde bir çağırır).
func add_like() -> void:
	likes += 1
	changed.emit()


# --- İç ---------------------------------------------------------------------------

func _changed(avatar_too: bool) -> void:
	changed.emit()
	if avatar_too:
		avatar_changed.emit()


func _level() -> int:
	var progress: PlayerProgress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress if is_inside_tree() else null
	return progress.level if progress else 1


func _load_files() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(GOOGLE_META)) if FileAccess.file_exists(GOOGLE_META) else null
	_google = raw if raw is Dictionary else {}
	_google_tex = _texture_from_file(GOOGLE_PATH) if not _google.is_empty() else null


# --- Google fotoğrafı -------------------------------------------------------------

func _connect_cloud() -> void:
	_cloud = get_tree().get_first_node_in_group("cloud_save") as CloudSaveManager
	if _cloud == null:
		return
	_cloud.user_changed.connect(_on_user_changed)
	_on_user_changed(_cloud.get_profile())


func _on_user_changed(profile: Dictionary) -> void:
	avatar_changed.emit()   # hesap değişti: başka hesabın Google fotoğrafı gösterilmez (_google_matches_account)
	var uid: String = SaveSafe.s(profile.get("uid", ""))
	var url: String = SaveSafe.s(profile.get("photo_url", ""))
	if uid.is_empty() or url.is_empty():
		return
	if url.contains("facebook.com") or url.contains("fbcdn") or url.contains("fbsbx"):
		return   # hesap Facebook'la açılmış: o fotoğraf adresi erişim jetonu ister (Google fotoğrafı seçeneği yalnız Google'da)
	if SaveSafe.s(_google.get("uid", "")) == uid and SaveSafe.s(_google.get("url", "")) == url and _google_tex:
		return
	_download_google(uid, url)


func _google_matches_account() -> bool:
	var uid: String = _cloud.get_uid() if _cloud else ""
	return not uid.is_empty() and SaveSafe.s(_google.get("uid", "")) == uid


## Google profil fotoğrafını indirir, 192 px JPEG'e çevirir, cihazda saklar.
func _download_google(uid: String, url: String) -> void:
	if _pending_url == url:
		return
	_pending_url = url
	if _http == null:
		_http = HTTPRequest.new()
		_http.timeout = 15.0
		add_child(_http)
	_http.cancel_request()
	var sized: String = url
	var at: int = url.rfind("=s")
	if at > 0:
		sized = url.substr(0, at) + "=s%d-c" % GOOGLE_SIZE
	if _http.request(sized) != OK:
		_pending_url = ""
		return
	var result: Array = await _http.request_completed
	_pending_url = ""
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS or int(result[1]) != 200:
		return
	var image: Image = ProfileCatalog.image_from_bytes(result[3] as PackedByteArray)
	if image == null:
		return
	var side: int = mini(image.get_width(), image.get_height())
	image = image.get_region(Rect2i((image.get_width() - side) / 2, (image.get_height() - side) / 2, side, side))
	var bytes: PackedByteArray = ProfileCatalog.encode_photo(image)
	if not _write_bytes(GOOGLE_PATH, bytes):
		return
	_google = {"uid": uid, "url": url, "hash": ProfileCatalog.hash_of(bytes)}
	var file: FileAccess = FileAccess.open(GOOGLE_META, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_google))
	_google_tex = _texture_from_bytes(bytes)
	_changed(true)


static func _write_bytes(path: String, bytes: PackedByteArray) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	return true


static func _texture_from_file(path: String) -> Texture2D:
	return _texture_from_bytes(FileAccess.get_file_as_bytes(path)) if FileAccess.file_exists(path) else null


static func _texture_from_bytes(bytes: PackedByteArray) -> Texture2D:
	var image: Image = ProfileCatalog.image_from_bytes(bytes)
	return ImageTexture.create_from_image(image) if image else null
