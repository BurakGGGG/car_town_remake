class_name ReferralManager
extends Node
## ARKADAŞ DAVETİ (2026-10-23, docs/ARKADAS_DAVET.md) — oyun tarafı; doğrulama ve ödül SUNUCUDA
## (firebase/functions/referral.js). GarageSystem kodla kurar ("referral" grubu); ziyarette yok.
##
## DAVET EDİLEN (yeni oyuncu): davet kodunu üç yoldan alır — Play yükleme kaynağı, davet linki (InviteLinks `?r=`) ya da
## elle (submit_code). Kod CİHAZDA bekler (META_PATH; misafirken de): hesapla girilince (sosyal oturum açılınca)
## users/{uid}/referral/ref_claim = {code, src, dev, at} yazılır ve sunucunun sonucu beklenir. ok → `joined` (karşılama),
## hoş geldin hediyesi POSTA'dan gelir, davet eden arkadaş listesine düşer. Cihazdaki kod bir kez kullanılır (sonuç ne
## olursa olsun). Oyuncu QUALIFY_LEVEL'a ulaşınca ref_lvl3 yazılır → sunucu davet edenin sayacını artırır.
## DAVET EDEN: her hesap oturum açınca bu cihazın özetini ref_owner'a yazar (kendi telefonunda ikinci hesapla kendini
## davet edemesin; telefon değişince güncellenir). load_progress() sayacı ve davet ettiklerini okur (ARKADAŞLAR › DAVET ET).
## Basamak ödülleri POSTA ile gelir; efsanevi araç SEÇME HAKKI burada, kayıtta durur (car_choices → choose_car).
##
## Cihaz özeti (dev): ANDROID_ID'nin (Android 8+: uygulama imzası + kullanıcı başına sabit, yeniden kurulumda değişmez)
## SHA-256'sı; ham kimlik hiçbir yere yazılmaz. Android dışında kurulum başına rastgele kimlik.
## Kayıt ("referral"): {status, referrer, lvl3, owner, car_choices}. Cihaz dosyası: {pending: {code, src, at}, done, install}.
## Masaüstü / QA: `-- --ref=<KOD>`.

## Sayaç / liste / durum / seçim hakkı değişti (ekran yenilensin).
signal changed
## Bu hesabın daveti kabul edildi (karşılama ekranı). `referrer`: davet edenin UID'si.
signal joined(referrer: String)

const META_PATH: String = "user://referral.json"
const ARG: String = "--ref="
const SOURCES: Array[String] = ["play", "link", "code"]
## users/{uid}/referral altındaki belgeler (kuralla aynı adlar).
const CLAIM: String = "ref_claim"
const LVL3: String = "ref_lvl3"
const OWNER: String = "ref_owner"
## Sunucunun sonucunu bekleme: POLL_SEC aralıkla POLL_TRIES kez.
const POLL_SEC: float = 0.75
const POLL_TRIES: int = 20
## Sayaç bu süreden yeniyse ekran açılınca yeniden okunmaz (okuma kotası).
const REFRESH_MIN_SEC: float = 30.0
## Sunucunun kesin sonuçları (bunlardan biri gelince cihazdaki kod kullanılmış sayılır).
const FINAL: Array[String] = ["ok", "no_code", "self", "old_account", "device_used", "banned", "already", "invalid"]
const DEVICE_SALT: String = "autoyard-ref|"

## Bu hesabın davet talebinin sonucu ("" = talep yok / bilinmiyor; kayıtta).
var status: String = ""
## Bu hesabı davet edenin UID'si (status ok ise).
var referrer: String = ""
## Seviye işareti sunucuya yazıldı (kayıtta).
var lvl3_sent: bool = false
## Kullanılmamış efsanevi araç seçme hakları (10. davet ödülü; kayıtta).
var car_choices: int = 0
## DAVET EDEN: sunucudaki sayaç ve liste (load_progress).
var joined_total: int = 0
var count: int = 0
var invited: Array[Dictionary] = []   ## {uid, at, state: joined | qualified, tier, src}, ilk davet önde
## Testler cihazı değiştirir (boşsa gerçek cihaz).
var device_override: String = ""

var _owner_dev: String = ""          # ref_owner'a son yazılan özet (kayıtta)
var _social: SocialManager
var _progress: PlayerProgress
var _session_uid: String = ""
var _running: bool = false
var _rerun: bool = false
var _loaded_at: float = -1.0e9


func _ready() -> void:
	add_to_group("referral")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(ARG):
			remember(arg.trim_prefix(ARG), "link")
	# Play yükleme kaynağı (yalnız Android, ilk açılışlarda): davet sayfasından Play'e gelenin kodu
	InstallReferrer.check(func(code: String) -> void:
		if is_inside_tree():
			receive(code, "play")
		else:
			remember(code, "play"))
	_connect.call_deferred()


func _connect() -> void:
	_social = get_tree().get_first_node_in_group("social") as SocialManager
	_progress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress
	if _social:
		_social.changed.connect(_on_social_changed)
	if _progress:
		_progress.level_up.connect(func(_level: int) -> void: _kick())
	if OS.is_debug_build() and OS.get_name() == "Android":
		print("ReferralManager: cihaz özeti %s… (%s), bekleyen kod %s" % [device_hash().left(8),
			"android_id" if device_override.is_empty() and not _android_id().is_empty() else "kurulum kimliği",
			pending_code().get("code", "yok")])
	_on_social_changed()


# --- Davet edilen ------------------------------------------------------------------

## Kodu cihazda bekletir (ilk gelen kaynak kazanır; cihazın kodu kullanıldıysa yok sayılır). Geçerliyse true.
static func remember(raw_code: String, src: String) -> bool:
	var code: String = SocialNames.normalize_code(raw_code)
	if not SocialNames.is_valid_code(code) or not SOURCES.has(src):
		return false
	var meta: Dictionary = _read_meta()
	if SaveSafe.b(meta.get("done", false)) or not _pending_of(meta).is_empty():
		return false
	meta["pending"] = {"code": code, "src": src, "at": int(Time.get_unix_time_from_system())}
	_write_meta(meta)
	if OS.is_debug_build():
		print("ReferralManager: davet kodu bekliyor (%s, %s)" % [code, src])
	return true


## Link / Play kaynağından gelen kod: bekletir ve oturum açıksa hemen talep eder.
func receive(raw_code: String, src: String) -> void:
	if remember(raw_code, src):
		_kick()


## Cihazda bekleyen kod (yoksa boş): {code, src, at}.
static func pending_code() -> Dictionary:
	return _pending_of(_read_meta())


## Elle kod girme alanı gösterilsin mi: bu hesabın davet talebi yok ve cihazda bekleyen kod yok. Hesabın yaşını sunucu
## denetler (ReferralRewards.JOIN_DAYS gün).
func can_enter_code() -> bool:
	return status.is_empty() and pending_code().is_empty()


## Elle girilen davet kodu. Dönüş: sunucunun sonucu (FINAL) ya da invalid · self · already · signin · offline · timeout.
## Misafirse kod cihazda bekler ("signin"): hesapla girince talep edilir.
func submit_code(raw: String) -> String:
	var code: String = SocialNames.normalize_code(raw)
	if not SocialNames.is_valid_code(code):
		return "invalid"
	if _social == null or _social.uid().is_empty():
		return "signin" if remember(code, "code") else "already"
	if code == _social.my_code():
		return "self"
	if not status.is_empty():
		return "already"
	var result: String = await _send_claim(code, "code")
	if FINAL.has(result):
		_mark_done()
	return result


## Oyuncuya gösterilen sonuç metni.
static func status_text(result: String) -> String:
	match result:
		"ok":
			return Loc.t("Davet kabul edildi! Hoş geldin hediyen POSTA'da.")
		"no_code", "invalid":
			return Loc.t("Böyle bir davet kodu yok. Harfleri kontrol et.")
		"self":
			return Loc.t("Kendi davet kodunu kullanamazsın.")
		"old_account":
			return Loc.t("Davet kodu yalnız yeni oyuncular içindir (ilk %d gün).") % ReferralRewards.JOIN_DAYS
		"device_used":
			return Loc.t("Bu telefondan daha önce davetle gelinmiş.")
		"banned":
			return Loc.t("Bu davet kodu şu an kullanılamıyor.")
		"already":
			return Loc.t("Zaten bir arkadaşının davetiyle geldin.")
		"signin":
			return Loc.t("Kodu kaydettik. Hesabınla girince davet sayılacak.")
	return Loc.t("Davet kontrol edilemedi. İnternet bağlantını kontrol edip tekrar dene.")


# --- Davet eden --------------------------------------------------------------------

## Sayacı ve davet edilenleri okur (oturum yoksa ya da son okuma yeniyse okumaz). Başarılıysa true.
func load_progress(force: bool = false) -> bool:
	if _social == null or _social.uid().is_empty():
		return false
	var now: float = Time.get_ticks_msec() / 1000.0
	if not force and now - _loaded_at < REFRESH_MIN_SEC:
		return true
	var uid: String = _social.uid()
	var result: Dictionary = await _social.read_referrals()
	if not is_inside_tree() or not bool(result.get("ok", false)) or uid != _social.uid():
		return false
	_loaded_at = now
	var stats: Dictionary = result.get("stats", {})
	joined_total = maxi(SaveSafe.i(stats.get("joined", 0)), 0)
	count = maxi(SaveSafe.i(stats.get("count", 0)), 0)
	invited.clear()
	var docs: Dictionary = result.get("invited", {})
	for key: Variant in docs:
		var id: String = SaveSafe.s(key)
		var doc: Dictionary = docs[key] if docs[key] is Dictionary else {}
		if not id.begins_with("f_"):
			continue
		invited.append({"uid": id.substr(2), "at": SaveSafe.i(doc.get("at", 0)), "tier": SaveSafe.i(doc.get("tier", 0)),
			"state": "qualified" if SaveSafe.s(doc.get("state", "")) == "qualified" else "joined",
			"src": SaveSafe.s(doc.get("src", ""))})
	invited.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["at"]) < int(b["at"]))
	changed.emit()
	return true


## Davet merdiveninde kaçıncı basamaktayız (alınmış basamak sayısı, en çok ReferralRewards.max_tier()).
func tiers_reached() -> int:
	return mini(count, ReferralRewards.max_tier())


## Postası gelmiş ama alınmamış basamaklar (DAVET ET'te AL; MailService'in bekleyen postalarından).
func ready_tiers() -> Array[int]:
	var out: Array[int] = []
	var mail: MailService = get_tree().get_first_node_in_group("mail") as MailService if is_inside_tree() else null
	if mail:
		for entry: Dictionary in mail.pending():
			if entry.get("ref_kind", "") == "tier" and int(entry.get("ref_tier", 0)) > 0:
				out.append(int(entry["ref_tier"]))
	return out


## ARKADAŞLAR rozetine eklenen sayı: alınmayı bekleyen basamaklar + kullanılmamış efsanevi araç seçimi.
func attention() -> int:
	return ready_tiers().size() + car_choices


# --- Efsanevi araç seçimi (10. basamak) -----------------------------------------------

## POSTA (MailService): seçim hakkı verildi.
func add_car_choice() -> void:
	car_choices += 1
	_request_save()
	changed.emit()


## Seçilebilecek araçlar (SÜPER KASA havuzunda sahip olunmayanlar).
func car_pool() -> Array[StringName]:
	return ReferralRewards.car_pool(get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership)


## Seçilen aracı verir, hakkı düşer. Hak yoksa ya da araç havuzda değilse false.
func choose_car(id: StringName) -> bool:
	var ownership: VehicleOwnership = get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	if car_choices <= 0 or ownership == null or not car_pool().has(id) or not ownership.add_vehicle(id):
		return false
	car_choices -= 1
	_request_save()
	changed.emit()
	return true


## Havuzdaki her araca zaten sahipse seçim yerine elmas (ReferralRewards.LEGENDARY_FALLBACK_GEMS). Verildiyse true.
func take_fallback() -> bool:
	if car_choices <= 0 or not car_pool().is_empty() or _progress == null:
		return false
	_progress.add_gems(ReferralRewards.LEGENDARY_FALLBACK_GEMS)
	car_choices -= 1
	_request_save()
	changed.emit()
	return true


# --- Oturum -----------------------------------------------------------------------

func _on_social_changed() -> void:
	var uid: String = _social.uid() if _social else ""
	if uid == _session_uid:
		return
	_session_uid = uid
	invited.clear()
	joined_total = 0
	count = 0
	_loaded_at = -1.0e9
	_kick()


## Oturum işleri (sıralı; çalışırken gelen istek bitince bir kez daha çalışır).
func _kick() -> void:
	if _social == null or _social.uid().is_empty():
		return
	if _running:
		_rerun = true
		return
	_running = true
	while true:
		_rerun = false
		var uid: String = _social.uid()
		await _register_owner()
		if is_inside_tree() and uid == _social.uid():
			await _claim_pending()
		if is_inside_tree() and uid == _social.uid():
			await _check_level()
		if not _rerun or not is_inside_tree():
			break
	_running = false


func _register_owner() -> void:
	var dev: String = device_hash()
	if dev == _owner_dev:
		return
	var result: Dictionary = await _social.write_referral(OWNER, {"dev": dev, "at": _now()})
	if SocialManager._ok(result):
		_owner_dev = dev
		_request_save()


func _claim_pending() -> void:
	var pending: Dictionary = pending_code()
	if pending.is_empty():
		return
	if not status.is_empty() or SaveSafe.s(pending.get("code", "")) == _social.my_code():
		_mark_done()   # bu hesap zaten davetle gelmiş / kendi kodu: cihazdaki kod düşer
		return
	var result: String = await _send_claim(SaveSafe.s(pending["code"]), SaveSafe.s(pending.get("src", "link")))
	if FINAL.has(result):
		_mark_done()


## Talebi yazar ve sonucu bekler. Belge zaten varsa (bu hesap daha önce talep etmiş) önceki sonuç okunur.
func _send_claim(code: String, src: String) -> String:
	var uid: String = _social.uid()
	var write: Dictionary = await _social.write_referral(CLAIM, {"code": code, "src": src, "dev": device_hash(), "at": _now()})
	var existed: bool = false
	if not SocialManager._ok(write):
		if not SocialManager._permission_denied(write):
			return "offline"
		existed = true
	for i: int in POLL_TRIES:
		if not is_inside_tree() or uid != _social.uid():
			return "offline"
		var read: Dictionary = await _social.read_referral(CLAIM)
		var doc: Dictionary = read.get("doc", {})
		var result: String = SaveSafe.s(doc.get("status", ""))
		if not result.is_empty():
			_apply_claim(result, SaveSafe.s(doc.get("referrer", "")))
			return result
		if existed and bool(read.get("ok", false)) and doc.is_empty():
			return "invalid"   # kural reddetti ama belge yok: biçim / yasak
		await get_tree().create_timer(POLL_SEC).timeout
	return "timeout"


func _apply_claim(result: String, from: String) -> void:
	status = result
	referrer = from if result == "ok" else ""
	_request_save()
	changed.emit()
	if result != "ok":
		return
	var mail: MailService = get_tree().get_first_node_in_group("mail") as MailService
	if mail:
		mail.poll()   # hoş geldin hediyesi (posta o an okunuyorsa poll boşa düşer: biraz sonra bir kez daha)
		get_tree().create_timer(3.0).timeout.connect(mail.poll)
	_social.refresh(true)   # davet eden artık arkadaş
	joined.emit(referrer)


func _check_level() -> void:
	if status != "ok" or lvl3_sent or _progress == null or _progress.level < ReferralRewards.QUALIFY_LEVEL:
		return
	var result: Dictionary = await _social.write_referral(LVL3, {"at": _now()})
	# İzin reddi: belge zaten var (başka cihazda yazıldı) — işaret gitmiş sayılır
	if SocialManager._ok(result) or SocialManager._permission_denied(result):
		lvl3_sent = true
		_request_save()


# --- Cihaz ------------------------------------------------------------------------

## Bu cihazın özeti (64 onaltılık karakter).
func device_hash() -> String:
	var raw: String = device_override if not device_override.is_empty() else _android_id()
	if raw.is_empty():
		raw = "install:" + _install_id()
	return (DEVICE_SALT + raw).sha256_text()


static func _android_id() -> String:
	if OS.get_name() != "Android" or not Engine.has_singleton("AndroidRuntime"):
		return ""
	var activity: Object = Engine.get_singleton("AndroidRuntime").call("getActivity")
	var secure: JavaClass = JavaClassWrapper.wrap("android.provider.Settings$Secure")
	if activity == null or secure == null:
		return ""
	var resolver: Object = activity.call("getContentResolver")
	var id: Variant = secure.call("getString", resolver, "android_id") if resolver else null
	var exception: JavaObject = JavaClassWrapper.get_exception()
	if exception != null:
		push_warning("ReferralManager: %s" % str(exception.call("toString")))
		return ""
	return id if id is String else ""


## Android dışında kurulum başına rastgele kimlik (cihaz dosyasında).
static func _install_id() -> String:
	var meta: Dictionary = _read_meta()
	var id: String = SaveSafe.s(meta.get("install", ""))
	if id.length() != 32:
		var bytes: PackedByteArray = Crypto.new().generate_random_bytes(16)
		id = bytes.hex_encode()
		meta["install"] = id
		_write_meta(meta)
	return id


func _mark_done() -> void:
	var meta: Dictionary = _read_meta()
	meta["done"] = true
	meta.erase("pending")
	_write_meta(meta)


static func _pending_of(meta: Dictionary) -> Dictionary:
	var pending: Variant = meta.get("pending", {})
	if not pending is Dictionary or not SocialNames.is_valid_code(SaveSafe.s((pending as Dictionary).get("code", ""))):
		return {}
	return pending


static func _read_meta() -> Dictionary:
	if not FileAccess.file_exists(META_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
	return parsed if parsed is Dictionary else {}


static func _write_meta(meta: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(META_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(meta))


static func _now() -> int:
	return int(Time.get_unix_time_from_system())


func _request_save() -> void:
	var save: SaveManager = get_tree().get_first_node_in_group("save_manager") as SaveManager if is_inside_tree() else null
	if save:
		save.request_save()


# --- Kayıt (SaveManager) -------------------------------------------------------------

func state() -> Dictionary:
	return {"status": status, "referrer": referrer, "lvl3": lvl3_sent, "owner": _owner_dev, "car_choices": car_choices}


func load_state(data: Dictionary) -> void:
	var loaded: String = SaveSafe.s(data.get("status", ""))
	status = loaded if FINAL.has(loaded) else ""
	referrer = SaveSafe.s(data.get("referrer", "")) if status == "ok" else ""
	lvl3_sent = SaveSafe.b(data.get("lvl3", false))
	var owner: String = SaveSafe.s(data.get("owner", ""))
	_owner_dev = owner if owner.length() == 64 else ""
	car_choices = clampi(SaveSafe.i(data.get("car_choices", 0)), 0, 10)
	changed.emit()


func reset() -> void:
	load_state({})
