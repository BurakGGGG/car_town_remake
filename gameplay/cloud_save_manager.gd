class_name CloudSaveManager
extends Node
## Google girişi (Firebase Auth) + bulut kaydı (Firestore players/{uid}).
## Sahnede World/Gameplay/CloudSaveManager olarak durur; arayanlar "cloud_save" grubundan bulur
## (autoload yok — proje kuralı). Firebase'e Android plugininin Engine singleton'ı
## ("GodotFirebaseAndroid") üzerinden doğrudan bağlanır; plugin yoksa (PC / editör) UNAVAILABLE
## durumunda kalır ve oyun yalnızca local kayıtla çalışır.
##
## KAYIT MODELİ YOKTUR: buluta giden veri SaveManager.snapshot_json()'dur (user://savegame.json ile
## aynı sözlük), buluttan gelen SaveManager.apply_snapshot() ile uygulanır. Local kayıt her zaman
## SaveManager'ındır; bu node yalnızca onu buluta taşır.
##
## Firestore dokümanı: players/{uid} = {profile: {display_name, email, photo_url}, save_version,
## save_json, updated_at}. Kayıt tek bir JSON string'i olarak durur: plugin Godot dizilerini Firestore'un
## kabul etmediği Java dizisi olarak gönderdiği için iç içe alan yazılamaz; format da böylece birebir
## local dosyayla aynı kalır. Token / şifre / credential hiçbir yere yazılmaz (Firebase Auth yönetir).
##
## Akış: açılışta giriş yoksa sessizce anonim oturum açılır (buluta yazmaz). GOOGLE İLE GİRİŞ anonim
## hesabı Google'a bağlar (UID aynı kalır); Google hesabı başka UID'e zaten bağlıysa normal Google
## girişine düşer. Google oturumu açılınca bulut kaydı okunur ve karar verilir:
##   bulut yok                  → local yüklenir (local başka hesabınsa o hesabın ilerlemesi yüklenmez)
##   aynıysa                    → bir şey yapılmaz
##   local'de ilerleme yok       → bulut yüklenir (cloud_sync.json kalmış olsa bile: boş kayıt buluta yazılmaz)
##   bu cihaz bu hesapla senkronsa (cloud_sync.json) → yalnızca değişen taraf diğerine yazılır,
##                                ikisi de değiştiyse oyuncuya sorulur
##   ikisinde de ilerleme var    → conflict_found: oyuncu seçer, OTOMATİK SEÇİM YOKTUR
## Üzerine yazılan taraf önce user:// altına yedeklenir (para / araç / XP sessizce kaybolmaz).
## Sonrasında her local kayıt (SaveManager.game_saved) UPLOAD_DEBOUNCE saniyelik tek bir yazmada
## birleşir. İnternet / Firebase hatası oyunu durdurmaz: OFFLINE'a geçilir, RETRY_INTERVAL'de bir
## (ve uygulama öne gelince) yeniden denenir.

## Durum değişti (UI metni / butonları için).
signal state_changed(state: State)
## Oturum değişti; profil {uid, display_name, email, photo_url} ya da çıkışta boş sözlük.
signal user_changed(profile: Dictionary)
## İki tarafta da farklı ilerleme var: resolve_conflict ile oyuncunun seçimi bildirilmeli.
## Özetler: {money: int, level: int, vehicles: PackedStringArray}
signal conflict_found(local_summary: Dictionary, cloud_summary: Dictionary)
## Oyuncuya gösterilecek kısa hata / bilgi metni.
signal notice(text: String)

enum State {
	UNAVAILABLE,  ## plugin yok (PC / editör): yalnızca local kayıt
	SIGNED_OUT,   ## misafir (anonim ya da hiç oturum yok): yalnızca local kayıt
	SIGNING_IN,   ## Google hesap seçimi / bağlama sürüyor
	SYNCING,      ## bulut kaydı okunuyor / karar veriliyor
	CONFLICT,     ## oyuncunun seçimi bekleniyor, buluta yazılmıyor
	SYNCED,       ## Google oturumu açık, bulut güncel ya da yazılıyor
	OFFLINE,      ## Google oturumu açık ama bulut erişilemiyor: local'le devam, sonra tekrar denenir
	ERROR,        ## bulut kaydı bu sürümle okunamıyor: bulut korunur, yazılmaz
}

const PLUGIN_NAME: String = "GodotFirebaseAndroid"
const COLLECTION: String = "players"
## Plugin'in "doküman yok" hata metni (Firestore.kt getDocument).
const NOT_FOUND_ERROR: String = "Document does not exist"
## Local kayıttan sonra buluta yazmadan önce beklenen süre (sn); aradaki kayıtlar tek yazmada birleşir.
const UPLOAD_DEBOUNCE: float = 1.5
## Firestore okuma / yazma yanıt vermezse vazgeçme süresi (sn).
const REQUEST_TIMEOUT: float = 12.0
## OFFLINE'dayken yeniden deneme aralığı (sn).
const RETRY_INTERVAL: float = 30.0
## Bu cihazın hangi hesapla, hangi kayıt üzerinde anlaştığı (+ giriş ekranı gösterildi mi).
const META_PATH: String = "user://cloud_sync.json"
## Bulut local'in üstüne yazılmadan önceki local kayıt.
const LOCAL_BACKUP_PATH: String = "user://savegame.before_cloud.json"
## Local bulutun üstüne yazılmadan önceki bulut kaydı.
const CLOUD_BACKUP_PATH: String = "user://cloud_backup.json"

enum Op { NONE, ANONYMOUS, GOOGLE, LINK, GET, SET, SIGN_OUT }

var _fb: Object
var _save: SaveManager
var _state: State = State.UNAVAILABLE
var _op: Op = Op.NONE
var _user: Dictionary = {}          # getCurrentUser(): uid, name, email, photoUrl, isAnonymous
var _meta: Dictionary = {}          # uid, synced_json, login_prompt_seen
var _cloud_exists: bool = false
var _conflict_cloud_json: String = ""
var _uploading_json: String = ""
var _dirty: bool = false            # buluta gitmemiş local değişiklik var
var _applying: bool = false         # buluttan yükleme sırasındaki local kayıt tekrar yüklenmesin
var _signing_out: bool = false
var _op_timer: Timer
var _upload_timer: Timer
var _retry_timer: Timer


func _ready() -> void:
	add_to_group("cloud_save")
	_op_timer = _make_timer(REQUEST_TIMEOUT, _on_op_timeout)
	_upload_timer = _make_timer(UPLOAD_DEBOUNCE, _on_upload_timeout)
	_retry_timer = _make_timer(RETRY_INTERVAL, _on_retry_timeout)
	_meta = _read_json(META_PATH)
	if Engine.has_singleton(PLUGIN_NAME):
		_fb = Engine.get_singleton(PLUGIN_NAME)
		_fb.connect("auth_success", _on_auth_success)
		_fb.connect("auth_failure", _on_auth_failure)
		_fb.connect("link_with_google_success", _on_link_success)
		_fb.connect("link_with_google_failure", _on_link_failure)
		_fb.connect("sign_out_success", _on_sign_out_result)
		_fb.connect("firestore_get_task_completed", _on_get_completed)
		_fb.connect("firestore_write_task_completed", _on_write_completed)
	_setup.call_deferred()


func _setup() -> void:
	await get_tree().process_frame   # SaveManager local kaydı yüklemiş olsun
	_save = get_tree().get_first_node_in_group("save_manager") as SaveManager
	if _save == null:
		push_error("CloudSaveManager: SaveManager bulunamadı, bulut kaydı kapalı")
		return
	_save.game_saved.connect(_on_local_saved)
	if _fb == null:
		_set_state(State.UNAVAILABLE)
		return
	if _fb.isSignedIn():
		_user = _fb.getCurrentUser()
		if is_authenticated():
			user_changed.emit(get_profile())
			_begin_sync()
			return
	_set_state(State.SIGNED_OUT)
	_sign_in_anonymously()


func _notification(what: int) -> void:
	# Uygulama öne geldi: internet geri gelmiş olabilir
	if what == NOTIFICATION_APPLICATION_RESUMED and _state == State.OFFLINE:
		_on_retry_timeout()


# --- Dış API ---------------------------------------------------------------------

func is_available() -> bool:
	return _fb != null


func get_state() -> State:
	return _state


## Google hesabıyla oturum açık mı (anonim oturum sayılmaz).
func is_authenticated() -> bool:
	return not _user.is_empty() and not _user.has("error") and not bool(_user.get("isAnonymous", true))


func get_uid() -> String:
	return _str(_user.get("uid")) if is_authenticated() else ""


## {uid, display_name, email, photo_url}; oturum yoksa boş.
func get_profile() -> Dictionary:
	if not is_authenticated():
		return {}
	return {
		"uid": get_uid(),
		"display_name": _str(_user.get("name")),
		"email": _str(_user.get("email")),
		"photo_url": _str(_user.get("photoUrl")),
	}


## Son okumada bulutta kayıt vardı mı.
func has_cloud_save() -> bool:
	return _cloud_exists


## GOOGLE İLE GİRİŞ: anonim oturum varsa Google'a bağlanır (UID korunur), yoksa doğrudan giriş.
func sign_in() -> void:
	if _fb == null:
		notice.emit("Google girişi yalnızca Android sürümünde")
		return
	if is_authenticated() or _op in [Op.GOOGLE, Op.LINK, Op.SIGN_OUT]:
		return
	_set_state(State.SIGNING_IN)
	var current: Dictionary = _fb.getCurrentUser() if _fb.isSignedIn() else {}
	if bool(current.get("isAnonymous", false)):
		_op = Op.LINK
		_fb.linkAnonymousWithGoogle()
	else:
		_op = Op.GOOGLE
		_fb.signInWithGoogle()


## ÇIKIŞ YAP: bekleyen değişiklik önce buluta yazılmaya çalışılır; local kayıt silinmez.
func sign_out() -> void:
	if _fb == null or not is_authenticated() or _signing_out:
		return
	_signing_out = true
	_upload_timer.stop()
	if _state == State.SYNCED and _local_differs_from_synced() and _op == Op.NONE:
		_upload_now()   # yazma bitince (başarılı / başarısız) _finish_sign_out
	elif _op != Op.SET:
		_finish_sign_out()


## Local kaydı hemen buluta yazar (debounce'suz).
func upload_save() -> void:
	_upload_timer.stop()
	_request_upload_now()


## Bulut kaydını yeniden okuyup karar akışını çalıştırır.
func download_save() -> void:
	if is_authenticated() and _op == Op.NONE and _state != State.CONFLICT:
		_begin_sync()


## Çakışmada oyuncunun seçimi: true → bulut kaydı bu cihaza, false → bu cihazdaki kayıt buluta.
## Üzerine yazılan taraf önce yedeklenir.
func resolve_conflict(use_cloud: bool) -> void:
	if _state != State.CONFLICT:
		return
	var cloud_json: String = _conflict_cloud_json
	_conflict_cloud_json = ""
	if use_cloud:
		_apply_cloud(cloud_json)
	else:
		_write_text(CLOUD_BACKUP_PATH, cloud_json)
		_set_state(State.SYNCING)
		_upload_now()


## Açılışta giriş ekranı bir kez gösterilsin mi (Android, misafir, daha önce gösterilmemiş).
func should_prompt_login() -> bool:
	return _fb != null and not is_authenticated() and not bool(_meta.get("login_prompt_seen", false))


func mark_login_prompt_seen() -> void:
	_meta["login_prompt_seen"] = true
	_write_json(META_PATH, _meta)


# --- Auth -------------------------------------------------------------------------

func _sign_in_anonymously() -> void:
	if _fb == null or _fb.isSignedIn() or _op != Op.NONE:
		return
	_op = Op.ANONYMOUS
	_fb.signInAnonymously()


func _on_auth_success(user: Dictionary) -> void:
	match _op:
		Op.ANONYMOUS:
			_op = Op.NONE
			_user = user
		Op.GOOGLE:
			# Google'a basıldığında süren sessiz anonim girişin geç gelen yanıtı Google girişi sayılmaz
			if bool(user.get("isAnonymous", false)):
				return
			_op = Op.NONE
			_on_google_user(user)


func _on_auth_failure(message: String) -> void:
	match _op:
		Op.ANONYMOUS:
			_op = Op.NONE   # çevrimdışı: misafir local'le devam eder, Google girişi yine denenebilir
		Op.GOOGLE:
			_op = Op.NONE
			push_warning("CloudSaveManager: Google girişi başarısız: %s" % message)
			_set_state(State.SIGNED_OUT)
			if not _is_cancel(message):
				notice.emit("Google girişi yapılamadı")
		Op.SIGN_OUT:
			_op = Op.NONE
			push_warning("CloudSaveManager: çıkış başarısız: %s" % message)


func _on_link_success(user: Dictionary) -> void:
	if _op != Op.LINK:
		return
	_op = Op.NONE
	_on_google_user(user)


## Google hesabı başka bir UID'e zaten bağlıysa (başka cihazda oynanmış) bağlama başarısız olur:
## o hesaba normal giriş yapılır, kayıtlar karşılaştırılır. Vazgeçmede misafir kalınır.
func _on_link_failure(message: String) -> void:
	if _op != Op.LINK:
		return
	if _is_cancel(message):
		_op = Op.NONE
		_set_state(State.SIGNED_OUT)
		return
	push_warning("CloudSaveManager: anonim hesap bağlanamadı (%s), Google girişi deneniyor" % message)
	_op = Op.GOOGLE
	_fb.signInWithGoogle()


func _on_google_user(user: Dictionary) -> void:
	_user = user
	if not is_authenticated():
		_set_state(State.SIGNED_OUT)
		return
	mark_login_prompt_seen()
	user_changed.emit(get_profile())
	_begin_sync()


func _finish_sign_out() -> void:
	_op = Op.SIGN_OUT
	_fb.signOut()


func _on_sign_out_result(success: bool) -> void:
	if _op != Op.SIGN_OUT:
		return
	_op = Op.NONE
	_signing_out = false
	if not success:
		notice.emit("Çıkış yapılamadı")
		return
	# local kayıt ve cloud_sync.json korunur: local bu hesabın ilerlemesi olarak kalır
	_user = {}
	_cloud_exists = false
	_dirty = false
	_retry_timer.stop()
	_upload_timer.stop()
	_op_timer.stop()
	user_changed.emit({})
	_set_state(State.SIGNED_OUT)
	_sign_in_anonymously()


# --- Senkron ----------------------------------------------------------------------

func _begin_sync() -> void:
	_retry_timer.stop()
	_set_state(State.SYNCING)
	_op = Op.GET
	_op_timer.start(REQUEST_TIMEOUT)
	_fb.firestoreGetDocument(COLLECTION, get_uid())


func _on_get_completed(result: Dictionary) -> void:
	if _op != Op.GET or _str(result.get("docID")) != get_uid():
		return
	_op = Op.NONE
	_op_timer.stop()
	if bool(result.get("status", false)):
		var data: Variant = result.get("data")
		var doc: Dictionary = data if data is Dictionary else {}
		_decide(_str(doc.get("save_json")))
	elif _str(result.get("error")) == NOT_FOUND_ERROR:
		_decide("")
	else:
		_go_offline(_str(result.get("error")))


## Bulut / local karşılaştırması. cloud_json boşsa bulutta kayıt yok.
func _decide(cloud_json: String) -> void:
	_cloud_exists = not cloud_json.is_empty()
	var uid: String = get_uid()
	var local_json: String = _save.snapshot_json()
	var owner: String = _str(_meta.get("uid"))
	var synced: String = _str(_meta.get("synced_json"))
	var local_is_other_account: bool = not owner.is_empty() and owner != uid

	if not _cloud_exists:
		if local_is_other_account:
			# local başka bir Google hesabının ilerlemesi: bu hesaba taşınmaz, yeni oyun başlar
			_write_text(LOCAL_BACKUP_PATH, local_json)
			_applying = true
			_save.new_game()
			_applying = false
		_upload_now()
		return
	if _parse_cloud(cloud_json).is_empty():
		push_error("CloudSaveManager: bulut kaydı okunamadı (bozuk ya da daha yeni sürüm), bulut korunuyor")
		_set_state(State.ERROR)
		notice.emit("Bulut kaydı bu sürümle açılamıyor")
		return
	if cloud_json == local_json:
		_mark_synced(cloud_json)
		return
	if not _save.has_progress():
		# Bu cihazda ilerleme yok (yeni kurulum / local kayıt silinmiş ya da taşınmış, cloud_sync.json
		# kalmış olsa bile): başlangıç kaydı asla bulutun üstüne yazılmaz, bulut gelir
		_apply_cloud(cloud_json)
		return
	if owner == uid:
		if local_json == synced:
			_apply_cloud(cloud_json)   # yalnızca bulut değişmiş (başka cihaz)
			return
		if cloud_json == synced:
			_upload_now()               # yalnızca bu cihaz değişmiş
			return
	elif local_is_other_account:
		_apply_cloud(cloud_json)
		return
	_conflict_cloud_json = cloud_json
	_set_state(State.CONFLICT)
	conflict_found.emit(_summary(_save.snapshot()), _summary(_parse_cloud(cloud_json)))


func _apply_cloud(cloud_json: String) -> void:
	var data: Dictionary = _parse_cloud(cloud_json)
	if _save.has_progress():
		_write_text(LOCAL_BACKUP_PATH, _save.snapshot_json())
	_applying = true
	var ok: bool = _save.apply_snapshot(data)
	_applying = false
	if not ok:
		_set_state(State.ERROR)
		return
	_mark_synced(cloud_json)
	# Katalogda olmayan araç vb. ayıklandıysa local artık farklıdır: temiz hali buluta yazılır
	if _save.snapshot_json() != cloud_json:
		_request_upload()


func _mark_synced(json: String) -> void:
	_meta["uid"] = get_uid()
	_meta["synced_json"] = json
	_write_json(META_PATH, _meta)
	_cloud_exists = true
	_set_state(State.SYNCED)


# --- Yükleme ------------------------------------------------------------------------

func _on_local_saved() -> void:
	if _applying or not is_authenticated():
		return
	_dirty = true
	_request_upload()


## Debounce: UPLOAD_DEBOUNCE içinde gelen kayıtlar tek bir Firestore yazmasında birleşir.
func _request_upload() -> void:
	if _state == State.SYNCED:
		_upload_timer.start(UPLOAD_DEBOUNCE)


func _on_upload_timeout() -> void:
	_request_upload_now()


func _request_upload_now() -> void:
	if _state != State.SYNCED or not is_authenticated():
		return
	if _op != Op.NONE:
		_dirty = true   # süren işlem bitince yazılır
		return
	if not _local_differs_from_synced():
		_dirty = false
		return
	_upload_now()


func _upload_now() -> void:
	_dirty = false
	_uploading_json = _save.snapshot_json()
	var profile: Dictionary = get_profile()
	profile.erase("uid")
	_op = Op.SET
	_op_timer.start(REQUEST_TIMEOUT)
	_fb.firestoreSetDocument(COLLECTION, get_uid(), {
		"profile": profile,
		"save_version": SaveManager.SAVE_VERSION,
		"save_json": _uploading_json,
		"updated_at": int(Time.get_unix_time_from_system()),
	}, false)


func _on_write_completed(result: Dictionary) -> void:
	if _op != Op.SET or _str(result.get("docID")) != get_uid():
		return
	_op = Op.NONE
	_op_timer.stop()
	if bool(result.get("status", false)):
		_mark_synced(_uploading_json)
		if _signing_out:
			_finish_sign_out()
		elif _dirty:
			_request_upload()
	else:
		_go_offline(_str(result.get("error")))


func _local_differs_from_synced() -> bool:
	return _str(_meta.get("uid")) != get_uid() or _save.snapshot_json() != _str(_meta.get("synced_json"))


# --- Hata / tekrar deneme ----------------------------------------------------------------

func _go_offline(reason: String) -> void:
	push_warning("CloudSaveManager: bulut erişilemiyor (%s), local kayıtla devam" % reason)
	_op = Op.NONE
	_dirty = true
	if _signing_out:
		_finish_sign_out()   # çıkış internet yüzünden takılmaz; local kayıt zaten duruyor
		return
	_set_state(State.OFFLINE)
	_retry_timer.start(RETRY_INTERVAL)


func _on_op_timeout() -> void:
	if _op == Op.GET or _op == Op.SET:
		_go_offline("zaman aşımı")


## Tekrar deneme her zaman okuma + karar akışıdır: arada başka cihaz yazmışsa üstüne yazılmaz.
func _on_retry_timeout() -> void:
	if is_authenticated() and _op == Op.NONE and _state == State.OFFLINE:
		_begin_sync()


# --- Yardımcılar ----------------------------------------------------------------------

func _set_state(value: State) -> void:
	if _state == value:
		return
	_state = value
	state_changed.emit(value)


func _parse_cloud(cloud_json: String) -> Dictionary:
	if cloud_json.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(cloud_json)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return _save.validate(parsed)


## Seçim ekranı özeti: para, seviye, araç adları (CarCatalog'dan).
func _summary(data: Dictionary) -> Dictionary:
	var economy: Dictionary = data.get("economy", {}) if data.get("economy") is Dictionary else {}
	var progress: Dictionary = data.get("progress", {}) if data.get("progress") is Dictionary else {}
	var vehicles: Dictionary = data.get("vehicles", {}) if data.get("vehicles") is Dictionary else {}
	var names: PackedStringArray = PackedStringArray()
	var owned: Variant = vehicles.get("owned", [])
	if owned is Array:
		for id: Variant in owned:
			var entry: Dictionary = CarCatalog.get_entry(StringName(str(id)))
			names.append(str(entry.get("display_name", str(id))))
	return {
		"money": int(economy.get("money", 0)),
		"level": int(progress.get("level", 1)),
		"vehicles": names,
	}


## Google hesap seçiminden vazgeçildi mi (GoogleSignInStatusCodes 12501 / CommonStatusCodes 16).
func _is_cancel(message: String) -> bool:
	return message.begins_with("12501") or message.begins_with("16:") or message.to_lower().contains("cancel")


func _make_timer(wait: float, callback: Callable) -> Timer:
	var timer: Timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = wait
	timer.timeout.connect(callback)
	add_child(timer)
	return timer


## Plugin null değerleri Godot null'u olarak gelir; str(null) "<null>" olmasın.
static func _str(value: Variant) -> String:
	return "" if value == null else str(value)


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func _write_json(path: String, data: Dictionary) -> void:
	_write_text(path, JSON.stringify(data, "\t"))


static func _write_text(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("CloudSaveManager: yazılamadı (%s): %d" % [path, FileAccess.get_open_error()])
		return
	file.store_string(text)
	file.close()
