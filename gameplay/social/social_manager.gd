class_name SocialManager
extends Node
## ARKADAŞLIK: takma ad + arkadaş kodu, istek / kabul, arkadaş listesi, herkese açık garaj ve ziyaret.
## GarageSystem kodla kurar (sahne dosyası düzenlenmez); arayanlar "social" grubundan bulur.
## Firebase'e CloudSaveManager gibi doğrudan eklentinin singleton'ı üzerinden bağlanır. Oturum
## CloudSaveManager'ındır: Google hesabıyla giriş yapılmamışsa (misafir) sosyal özellik kapalıdır.
##
## FIRESTORE (kurallar: firebase/firestore.rules)
##   garages/g_{uid}              {name, code, level, value, garage_json, updated_at}  herkese açık garaj
##   codes/{KOD}                  {uid}                     arkadaş kodu → oyuncu (bir kez alınır)
##   users/{alıcı}/inbox/r_{gön}  {name, code, at}          gelen istek (gönderen yazar)
##   users/{gön}/outbox/o_{alıcı} {name, code, at}          giden istek (gönderenin bekleyen listesi)
##   users/{a}/friends/f_{b}      {since}                   arkadaşlık; iki belgeyi de KABUL EDEN yazar
## Belge kimlikleri hiçbir zaman çıplak UID değildir: eklenti sonuçları yalnızca belge kimliğiyle
## bildirir (koleksiyon yok) ve CloudSaveManager kendi sonucunu "kimlik == UID" diye tanır. Önek iki
## sistemin yanıtlarını ayırır. Bu node'un istekleri SIRAYLA gider (aynı anda tek istek), sonuç
## kimlik + istek türüyle eşlenir; koleksiyon listesinin sonucunda kimlik yoktur.
##
## GARAJ YAYINI: profil varken her local kayıttan PUBLISH_DEBOUNCE sn sonra açık garaj (PublicGarage)
## değiştiyse yazılır. Yalnızca bulut kaydı SYNCED iken: kayıt seçimi (CONFLICT) sürerken cihazdaki
## kayıt henüz bu hesabın olmayabilir.
##
## Cihazda tutulan: user://social.json = {uid, name, code, published}. Başka cihazda / yeniden kurulumda
## profil garages/g_{uid}'den geri okunur.

## Profil / listeler / durum değişti (ekran yenilensin).
signal changed
## Oyuncuya gösterilecek kısa mesaj.
signal notice(text: String)

enum State {
	UNAVAILABLE,  ## eklenti yok (PC / editör)
	SIGNED_OUT,   ## Google girişi yok (misafir) ya da bulut kaydı henüz hazır değil
	LOADING,      ## profil okunuyor / oluşturuluyor
	NO_PROFILE,   ## giriş var, takma ad + kod henüz seçilmedi
	READY,        ## profil hazır
	OFFLINE,      ## sunucuya ulaşılamadı (tekrar denenebilir)
}

const PLUGIN_NAME: String = "GodotFirebaseAndroid"
const META_PATH: String = "user://social.json"
const NOT_FOUND_ERROR: String = "Document does not exist"
const REQUEST_TIMEOUT: float = 12.0
## Local kayıttan sonra açık garajı yazmadan önce beklenen süre (sn); aradaki kayıtlar birleşir.
const PUBLISH_DEBOUNCE: float = 20.0
## Listeler bu süreden yeniyse ekran açılınca yeniden okunmaz (okuma kotası).
const REFRESH_MIN_INTERVAL: float = 30.0
const MAX_FRIENDS: int = 100
## Kod çakışırsa (sunucu reddeder) en fazla bu kadar yeni kod denenir.
const CODE_ATTEMPTS: int = 6

const GARAGES: String = "garages"
const CODES: String = "codes"

## Eşleşme için bekleyen isteğin sonucu (iç kullanım).
signal _op_result(result: Dictionary)
signal _op_slot_free

## Testler kısaltır.
var publish_delay: float = PUBLISH_DEBOUNCE
var request_timeout: float = REQUEST_TIMEOUT
var friends: Array[Dictionary] = []   ## {uid, name, code, level, value}
var incoming: Array[Dictionary] = []  ## {uid, name, code, at}
var outgoing: Array[Dictionary] = []  ## {uid, name, code, at}

var _fb: Object
var _cloud: CloudSaveManager
var _save: SaveManager
var _state: State = State.UNAVAILABLE
var _uid: String = ""
var _meta: Dictionary = {}
var _op_busy: bool = false
var _current: Dictionary = {}         # {kind, id} — yanıtı beklenen istek
var _busy: int = 0                    # oyuncunun başlattığı süren işlem sayısı (butonlar kilitlenir)
var _refreshed_at: float = -1000.0
var _op_timer: Timer
var _publish_timer: Timer


func _ready() -> void:
	add_to_group("social")
	_op_timer = _make_timer(REQUEST_TIMEOUT, _on_op_timeout)
	_publish_timer = _make_timer(PUBLISH_DEBOUNCE, _on_publish_timeout)
	if Engine.has_singleton(PLUGIN_NAME):
		_fb = Engine.get_singleton(PLUGIN_NAME)
	_setup.call_deferred()


## Testler sahte Firebase verir (eklenti yokken). _ready'den önce çağrılmalı.
func use_firebase(fb: Object) -> void:
	_fb = fb


func _setup() -> void:
	if _fb == null:
		_set_state(State.UNAVAILABLE)
		return
	_fb.connect("firestore_get_task_completed", _on_get_completed)
	_fb.connect("firestore_write_task_completed", _on_write_completed)
	_fb.connect("firestore_delete_task_completed", _on_delete_completed)
	_save = get_tree().get_first_node_in_group("save_manager") as SaveManager
	_cloud = get_tree().get_first_node_in_group("cloud_save") as CloudSaveManager
	if _save:
		_save.game_saved.connect(_on_local_saved)
	if _cloud:
		_cloud.state_changed.connect(func(_s: CloudSaveManager.State) -> void: _sync_session())
	_set_state(State.SIGNED_OUT)
	_sync_session()


# --- Dış API ---------------------------------------------------------------------

func get_state() -> State:
	return _state


func is_ready() -> bool:
	return _state == State.READY


## Oyuncunun başlattığı bir işlem sürüyor mu (butonlar kilitli).
func is_busy() -> bool:
	return _busy > 0 or _state == State.LOADING


func my_name() -> String:
	return SaveSafe.s(_meta.get("name", ""))


func my_code() -> String:
	return SaveSafe.s(_meta.get("code", ""))


func is_friend(uid: String) -> bool:
	return _index_of(friends, uid) >= 0


## Profil oluşturur: takma ad + yeni arkadaş kodu, ardından açık garaj yayınlanır.
func create_profile(raw_name: String) -> bool:
	var name: String = SocialNames.clean_name(raw_name)
	if not _check_name(name) or _state != State.NO_PROFILE:
		return false
	_set_state(State.LOADING)
	_busy += 1
	var code: String = my_code() if SaveSafe.s(_meta.get("uid", "")) == _uid else ""
	if code.is_empty():
		code = await _claim_code()
	var ok: bool = false
	if not code.is_empty():
		_meta = {"uid": _uid, "code": code, "name": ""}
		_write_meta()
		ok = await _publish(name)
	_busy -= 1
	if ok:
		_meta["name"] = name
		_write_meta()
		_set_state(State.READY)
		notice.emit(Loc.t("Profilin hazır! Kodunu arkadaşlarınla paylaş."))
	else:
		_set_state(State.NO_PROFILE)
		notice.emit(Loc.t("Profil oluşturulamadı. İnternet bağlantını kontrol edip tekrar dene."))
	return ok


## Takma adı değiştirir (açık garaj yeni adla yazılır).
func rename(raw_name: String) -> bool:
	var name: String = SocialNames.clean_name(raw_name)
	if not is_ready() or not _check_name(name):
		return false
	if name == my_name():
		return true
	_busy += 1
	changed.emit()
	var ok: bool = await _publish(name)
	_busy -= 1
	if ok:
		_meta["name"] = name
		_write_meta()
		notice.emit(Loc.t("Takma adın değişti."))
	else:
		notice.emit(Loc.t("Takma ad değiştirilemedi. Tekrar dene."))
	changed.emit()
	return ok


## Arkadaş listesi + gelen / giden istekler sunucudan okunur. force değilse kısa aralıkla tekrar okunmaz.
func refresh(force: bool = false) -> void:
	if not is_ready() or _busy > 0:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if not force and now - _refreshed_at < REFRESH_MIN_INTERVAL:
		return
	_busy += 1
	changed.emit()
	var ok: bool = await _load_lists()
	_busy -= 1
	if ok:
		_refreshed_at = now
	else:
		notice.emit(Loc.t("Arkadaş listesi yüklenemedi. İnternet bağlantını kontrol et."))
	changed.emit()


## Koda arkadaşlık isteği gönderir. Karşı taraf zaten istek göndermişse doğrudan kabul edilir.
func send_request(raw_code: String) -> bool:
	if not is_ready() or _busy > 0:
		return false
	var code: String = SocialNames.normalize_code(raw_code)
	if not SocialNames.is_valid_code(code):
		notice.emit(Loc.t("Kod 6 karakter olmalı (ör. AY-7K2Q4M)."))
		return false
	if code == my_code():
		notice.emit(Loc.t("Bu senin kendi kodun."))
		return false
	if friends.size() >= MAX_FRIENDS:
		notice.emit(Loc.t("Arkadaş listen dolu."))
		return false
	_busy += 1
	changed.emit()
	var ok: bool = await _send_request(code)
	_busy -= 1
	changed.emit()
	return ok


func accept(uid: String) -> bool:
	if _index_of(incoming, uid) < 0 or _busy > 0:
		return false
	_busy += 1
	changed.emit()
	var ok: bool = await _accept(uid)
	_busy -= 1
	changed.emit()
	return ok


func reject(uid: String) -> bool:
	var at: int = _index_of(incoming, uid)
	if at < 0 or _busy > 0:
		return false
	_busy += 1
	changed.emit()
	var ok: bool = _ok(await _call(&"delete", _inbox_of(_uid), "r_" + uid))
	if ok:
		await _call(&"delete", _outbox_of(uid), "o_" + _uid)
		incoming.remove_at(at)
	_busy -= 1
	changed.emit()
	return ok


## Gönderilmiş isteği geri çeker.
func cancel(uid: String) -> bool:
	var at: int = _index_of(outgoing, uid)
	if at < 0 or _busy > 0:
		return false
	_busy += 1
	changed.emit()
	var ok: bool = _ok(await _call(&"delete", _inbox_of(uid), "r_" + _uid))
	if ok:
		await _call(&"delete", _outbox_of(_uid), "o_" + uid)
		outgoing.remove_at(at)
	_busy -= 1
	changed.emit()
	return ok


func remove_friend(uid: String) -> bool:
	var at: int = _index_of(friends, uid)
	if at < 0 or _busy > 0:
		return false
	_busy += 1
	changed.emit()
	var ok: bool = _ok(await _call(&"delete", _friends_of(_uid), "f_" + uid))
	if ok:
		await _call(&"delete", _friends_of(uid), "f_" + _uid)   # karşı tarafın listesi (kural izin verir)
		friends.remove_at(at)
	_busy -= 1
	changed.emit()
	return ok


## Oyuncunun açık garajını okur ve ziyaret modunu açar. Başarısızsa false (mesaj notice ile).
func visit(uid: String) -> bool:
	if not is_ready() or _busy > 0:
		return false
	if _cloud and _cloud.is_busy():
		notice.emit(Loc.t("Kayıt buluta yazılıyor, birazdan tekrar dene."))
		return false
	_busy += 1
	changed.emit()
	var result: Dictionary = await _call(&"get", GARAGES, "g_" + uid)
	_busy -= 1
	changed.emit()
	if not _ok(result):
		notice.emit(Loc.t("Garaj açılamadı. İnternet bağlantını kontrol et.") if not _not_found(result)
			else Loc.t("Bu oyuncunun garajı bulunamadı."))
		return false
	var doc: Dictionary = result.get("data", {}) if result.get("data") is Dictionary else {}
	var garage: Dictionary = PublicGarage.parse(SaveSafe.s(doc.get("garage_json", "")))
	if garage.is_empty():
		notice.emit(Loc.t("Bu garaj oyunun daha yeni bir sürümüyle kaydedilmiş. Oyunu güncelle."))
		return false
	if _save:
		_save.save_game()   # kendi garajın donmadan önce son durum diskte olsun
	return GarageVisit.begin(get_tree(), {
		"uid": uid,
		"name": SaveSafe.s(doc.get("name", "")),
		"code": SaveSafe.s(doc.get("code", "")),
		"level": SaveSafe.i(doc.get("level", 1)),
		"value": SaveSafe.i(doc.get("value", 0)),
		"garage": garage,
	})


## HESAP SİLME: bu oyuncunun bütün sosyal belgeleri silinir (arkadaşlıklar iki taraftan, istekler,
## açık garaj, kod). Auth kullanıcısı silinmeden ÖNCE çağrılmalı (sonra yetki kalmaz).
## Herhangi bir silme başarısızsa false; çağıran hesabı silmeyi durdurur.
func delete_all() -> bool:
	if _fb == null or _uid.is_empty():
		return true
	_publish_timer.stop()
	_busy += 1
	var ok: bool = true
	var lists: Array[Dictionary] = [
		await _call(&"list", _friends_of(_uid)), await _call(&"list", _inbox_of(_uid)),
		await _call(&"list", _outbox_of(_uid)),
	]
	for r: Dictionary in lists:
		ok = ok and _ok(r)
	if ok:
		for doc_id: String in _ids(lists[0]):
			var other: String = doc_id.trim_prefix("f_")
			await _call(&"delete", _friends_of(other), "f_" + _uid)
			ok = _ok(await _call(&"delete", _friends_of(_uid), doc_id)) and ok
		for doc_id: String in _ids(lists[1]):
			await _call(&"delete", _outbox_of(doc_id.trim_prefix("r_")), "o_" + _uid)
			ok = _ok(await _call(&"delete", _inbox_of(_uid), doc_id)) and ok
		for doc_id: String in _ids(lists[2]):
			await _call(&"delete", _inbox_of(doc_id.trim_prefix("o_")), "r_" + _uid)
			ok = _ok(await _call(&"delete", _outbox_of(_uid), doc_id)) and ok
		ok = _ok(await _call(&"delete", GARAGES, "g_" + _uid)) and ok
		var code: String = my_code()
		if not code.is_empty():
			var r: Dictionary = await _call(&"delete", CODES, code)
			ok = (_ok(r) or _permission_denied(r)) and ok   # kod başkasınınsa (eski meta) sorun değil
	_busy -= 1
	if ok:
		_meta = {}
		DirAccess.remove_absolute(ProjectSettings.globalize_path(META_PATH))
		friends.clear()
		incoming.clear()
		outgoing.clear()
		_uid = ""   # hesap siliniyor: sonraki kayıtlar artık yayınlanmaz
		_set_state(State.SIGNED_OUT)
	return ok


# --- Oturum ----------------------------------------------------------------------

## Bulut kaydının durumuna göre sosyal oturumu açar / kapatır.
func _sync_session() -> void:
	var uid: String = _cloud.get_uid() if _cloud and _cloud.is_authenticated() else ""
	var synced: bool = _cloud != null and _cloud.get_state() == CloudSaveManager.State.SYNCED
	if uid.is_empty():
		if _uid != "" or _state != State.SIGNED_OUT:
			_uid = ""
			friends.clear()
			incoming.clear()
			outgoing.clear()
			_publish_timer.stop()
			_set_state(State.SIGNED_OUT)
		return
	if uid == _uid or not synced:
		return
	_uid = uid
	_start_session()


func _start_session() -> void:
	_meta = _read_json(META_PATH)
	if SaveSafe.s(_meta.get("uid", "")) == _uid and not my_code().is_empty() and not my_name().is_empty():
		_set_state(State.READY)
		_request_publish()   # bu cihazda değişmiş olabilir
		refresh(true)   # gelen istek sayısı HUD plakasında ekran açılmadan da görünsün
		return
	# Bu cihazda profil yok: başka cihazda / önceki kurulumda oluşturulmuş olabilir
	_set_state(State.LOADING)
	var result: Dictionary = await _call(&"get", GARAGES, "g_" + _uid)
	if _ok(result):
		var doc: Dictionary = result.get("data", {}) if result.get("data") is Dictionary else {}
		_meta = {"uid": _uid, "name": SaveSafe.s(doc.get("name", "")), "code": SaveSafe.s(doc.get("code", "")),
			"published": SaveSafe.s(doc.get("garage_json", ""))}
		_write_meta()
		_set_state(State.READY)
		_request_publish()
		refresh(true)
	elif _not_found(result):
		_set_state(State.NO_PROFILE)
	else:
		_set_state(State.OFFLINE)


## OFFLINE'dan yeniden dener (ekran açılınca).
func retry() -> void:
	if _state == State.OFFLINE and not _uid.is_empty():
		_start_session()


# --- Garaj yayını ----------------------------------------------------------------

func _on_local_saved() -> void:
	_request_publish()


func _request_publish() -> void:
	if is_ready():
		_publish_timer.start(publish_delay)


func _on_publish_timeout() -> void:
	if not is_ready():
		return
	if _busy > 0:
		_request_publish()   # oyuncunun işlemi bitince
		return
	if _cloud and _cloud.get_state() != CloudSaveManager.State.SYNCED:
		return   # kayıt seçimi / çevrimdışı: bulut senkronu bitince yeni bir kayıt gelir
	var garage_json: String = _garage_json()
	if garage_json == SaveSafe.s(_meta.get("published", "")):
		return
	await _publish(my_name())


## Açık garajı (ve adı / kodu) yazar. Başarılıysa yayınlanan JSON cihazda hatırlanır.
func _publish(name: String) -> bool:
	if _save == null:
		return false
	var garage_json: String = _garage_json()
	if garage_json.length() > PublicGarage.MAX_JSON:
		push_warning("SocialManager: açık garaj çok büyük (%d), yayınlanmadı" % garage_json.length())
		return false
	var garage: Dictionary = JSON.parse_string(garage_json)
	var result: Dictionary = await _call(&"set", GARAGES, "g_" + _uid, {
		"name": name,
		"code": my_code(),
		"level": PublicGarage.level_of(garage),
		"value": GarageValue.compute(get_tree()),
		"garage_json": garage_json,
		"updated_at": _now(),
	})
	if not _ok(result):
		return false
	_meta["published"] = garage_json
	_write_meta()
	return true


func _garage_json() -> String:
	return PublicGarage.to_json(PublicGarage.from_snapshot(_save.snapshot())) if _save else ""


## Boşta bir kod bulup alır (codes/{KOD} = {uid}). Alınamazsa boş.
func _claim_code() -> String:
	for i: int in CODE_ATTEMPTS:
		var code: String = SocialNames.random_code()
		var result: Dictionary = await _call(&"set", CODES, code, {"uid": _uid})
		if _ok(result):
			return code
		if not _permission_denied(result):
			return ""   # çevrimdışı vb.: yeni kod denemek boşuna
	return ""


# --- İstek / liste ---------------------------------------------------------------

func _send_request(code: String) -> bool:
	var found: Dictionary = await _call(&"get", CODES, code)
	if not _ok(found):
		notice.emit(Loc.t("Bu kodla bir oyuncu bulunamadı.") if _not_found(found)
			else Loc.t("İstek gönderilemedi. İnternet bağlantını kontrol et."))
		return false
	var data: Dictionary = found.get("data", {}) if found.get("data") is Dictionary else {}
	var uid: String = SaveSafe.s(data.get("uid", ""))
	if uid.is_empty() or uid == _uid:
		notice.emit(Loc.t("Bu senin kendi kodun.") if uid == _uid else Loc.t("Bu kodla bir oyuncu bulunamadı."))
		return false
	if is_friend(uid):
		notice.emit(Loc.t("Zaten arkadaşsınız."))
		return false
	if _index_of(outgoing, uid) >= 0:
		notice.emit(Loc.t("Bu oyuncuya zaten istek gönderdin."))
		return false
	if _index_of(incoming, uid) >= 0:
		return await _accept(uid)   # o da istek göndermiş: doğrudan arkadaş olunur
	var garage: Dictionary = await _call(&"get", GARAGES, "g_" + uid)
	if not _ok(garage):
		notice.emit(Loc.t("Bu kodla bir oyuncu bulunamadı.") if _not_found(garage)
			else Loc.t("İstek gönderilemedi. İnternet bağlantını kontrol et."))
		return false
	var their: Dictionary = garage.get("data", {}) if garage.get("data") is Dictionary else {}
	var at: int = _now()
	var mine: Dictionary = {"name": my_name(), "code": my_code(), "at": at}
	var theirs: Dictionary = {"name": SaveSafe.s(their.get("name", "")), "code": code, "at": at}
	if not _ok(await _call(&"set", _inbox_of(uid), "r_" + _uid, mine)):
		notice.emit(Loc.t("İstek gönderilemedi. İnternet bağlantını kontrol et."))
		return false
	await _call(&"set", _outbox_of(_uid), "o_" + uid, theirs)   # yalnızca bekleyen listesi için
	var entry: Dictionary = theirs.duplicate()
	entry["uid"] = uid
	outgoing.append(entry)
	notice.emit(Loc.t("%s oyuncusuna istek gönderildi.") % theirs["name"])
	return true


## Arkadaşlığı kurar: iki belgeyi de kabul eden (bu oyuncu) yazar, sonra istek kayıtları silinir.
func _accept(uid: String) -> bool:
	var at: int = _index_of(incoming, uid)
	var since: Dictionary = {"since": _now()}
	var ok: bool = _ok(await _call(&"set", _friends_of(_uid), "f_" + uid, since)) \
		and _ok(await _call(&"set", _friends_of(uid), "f_" + _uid, since))
	if not ok:
		notice.emit(Loc.t("İstek kabul edilemedi. Tekrar dene."))
		return false
	await _call(&"delete", _inbox_of(_uid), "r_" + uid)
	await _call(&"delete", _outbox_of(uid), "o_" + _uid)   # karşı tarafın bekleyen listesi
	var entry: Dictionary = incoming[at]
	incoming.remove_at(at)
	var friend: Dictionary = await _friend_entry(uid, entry)
	if not friend.is_empty():
		friends.append(friend)
	notice.emit(Loc.t("%s artık arkadaşın!") % SaveSafe.s(entry.get("name", "")))
	return true


func _load_lists() -> bool:
	var friend_list: Dictionary = await _call(&"list", _friends_of(_uid))
	var inbox: Dictionary = await _call(&"list", _inbox_of(_uid))
	var outbox: Dictionary = await _call(&"list", _outbox_of(_uid))
	if not (_ok(friend_list) and _ok(inbox) and _ok(outbox)):
		return false
	incoming = _requests(inbox, "r_")
	outgoing = _requests(outbox, "o_")
	var loaded: Array[Dictionary] = []
	for doc_id: String in _ids(friend_list):
		var uid: String = doc_id.trim_prefix("f_")
		var entry: Dictionary = await _friend_entry(uid, {})
		if entry.is_empty():
			# Arkadaş hesabını silmiş: kendi listemizden de düşer
			await _call(&"delete", _friends_of(_uid), doc_id)
			continue
		loaded.append(entry)
	loaded.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["level"]) > int(b["level"]))
	friends = loaded
	return true


## Arkadaşın güncel adı / seviyesi açık garajından. Garaj yoksa (hesap silinmiş) boş; okunamazsa
## eldeki bilgiyle döner.
func _friend_entry(uid: String, fallback: Dictionary) -> Dictionary:
	var result: Dictionary = await _call(&"get", GARAGES, "g_" + uid)
	if _not_found(result):
		return {}
	var doc: Dictionary = result.get("data", {}) if _ok(result) and result.get("data") is Dictionary else fallback
	return {
		"uid": uid,
		"name": SaveSafe.s(doc.get("name", fallback.get("name", ""))),
		"code": SaveSafe.s(doc.get("code", fallback.get("code", ""))),
		"level": maxi(SaveSafe.i(doc.get("level", 1)), 1),
		"value": SaveSafe.i(doc.get("value", 0)),
	}


func _requests(result: Dictionary, prefix: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var data: Dictionary = result.get("data", {}) if result.get("data") is Dictionary else {}
	for doc_id: Variant in data:
		var doc: Dictionary = data[doc_id] if data[doc_id] is Dictionary else {}
		var id: String = SaveSafe.s(doc_id)
		if not id.begins_with(prefix):
			continue
		out.append({"uid": id.trim_prefix(prefix), "name": SaveSafe.s(doc.get("name", "")),
			"code": SaveSafe.s(doc.get("code", "")), "at": SaveSafe.i(doc.get("at", 0))})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["at"]) > int(b["at"]))
	return out


# --- Firestore istek kuyruğu ------------------------------------------------------

## Tek istek: sırası gelince gönderilir, sonucu (ya da zaman aşımı) beklenir.
## kind: &"get" / &"set" / &"delete" / &"list" (list: id yok, sonuç data = {belge_kimliği: veri}).
func _call(kind: StringName, collection: String, id: String = "", data: Dictionary = {}) -> Dictionary:
	if _fb == null:
		return {"status": false, "error": "unavailable"}
	while _op_busy:
		await _op_slot_free
	_op_busy = true
	_current = {"kind": kind, "id": id}
	_op_timer.start(request_timeout)
	match kind:
		&"get":
			_fb.firestoreGetDocument(collection, id)
		&"set":
			_fb.firestoreSetDocument(collection, id, data, false)
		&"delete":
			_fb.firestoreDeleteDocument(collection, id)
		&"list":
			_fb.firestoreGetDocumentsInCollection(collection)
	var result: Dictionary = await _op_result
	_op_busy = false
	_op_slot_free.emit()
	return result


func _on_get_completed(result: Dictionary) -> void:
	if _current.is_empty():
		return
	match _current["kind"]:
		&"get":
			if SaveSafe.s(result.get("docID", "")) == _current["id"]:
				_finish(result)
		&"list":
			if not result.has("docID"):   # koleksiyon sonucu kimliksizdir (bulut kaydınınki kimlikli)
				_finish(result)


func _on_write_completed(result: Dictionary) -> void:
	if not _current.is_empty() and _current["kind"] == &"set" and SaveSafe.s(result.get("docID", "")) == _current["id"]:
		_finish(result)


func _on_delete_completed(result: Dictionary) -> void:
	if not _current.is_empty() and _current["kind"] == &"delete" and SaveSafe.s(result.get("docID", "")) == _current["id"]:
		_finish(result)


func _on_op_timeout() -> void:
	if not _current.is_empty():
		_finish({"status": false, "error": "timeout"})


func _finish(result: Dictionary) -> void:
	_current = {}
	_op_timer.stop()
	_op_result.emit(result)


# --- Yardımcılar -----------------------------------------------------------------

func _check_name(name: String) -> bool:
	if name.length() < SocialNames.NAME_MIN or name.length() > SocialNames.NAME_MAX:
		notice.emit(Loc.t("Takma ad %d–%d karakter olmalı.") % [SocialNames.NAME_MIN, SocialNames.NAME_MAX])
		return false
	if not SocialNames.is_valid_name(name):
		notice.emit(Loc.t("Bu takma ad kullanılamaz. Harf, rakam, boşluk ve . _ - kullanabilirsin."))
		return false
	return true


func _set_state(value: State) -> void:
	if _state == value:
		return
	_state = value
	changed.emit()


static func _friends_of(uid: String) -> String:
	return "users/%s/friends" % uid


static func _inbox_of(uid: String) -> String:
	return "users/%s/inbox" % uid


static func _outbox_of(uid: String) -> String:
	return "users/%s/outbox" % uid


static func _ok(result: Dictionary) -> bool:
	return bool(result.get("status", false))


static func _not_found(result: Dictionary) -> bool:
	return SaveSafe.s(result.get("error", "")) == NOT_FOUND_ERROR


## Kural reddi (kod alınmış vb.). Eklenti hata metnini olduğu gibi verir.
static func _permission_denied(result: Dictionary) -> bool:
	return SaveSafe.s(result.get("error", "")).to_upper().contains("PERMISSION")


## Liste sonucundaki belge kimlikleri.
static func _ids(result: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var data: Variant = result.get("data", {})
	if data is Dictionary:
		for key: Variant in data:
			out.append(SaveSafe.s(key))
	return out


static func _index_of(list: Array[Dictionary], uid: String) -> int:
	for i: int in list.size():
		if SaveSafe.s(list[i].get("uid", "")) == uid:
			return i
	return -1


static func _now() -> int:
	return int(Time.get_unix_time_from_system())


func _write_meta() -> void:
	var file: FileAccess = FileAccess.open(META_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_meta))


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _make_timer(wait: float, callback: Callable) -> Timer:
	var timer: Timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = wait
	timer.timeout.connect(callback)
	add_child(timer)
	return timer
