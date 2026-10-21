class_name ModerationWatch
extends Node
## MODERASYON (2026-10-21): yönetim panelinin oyuncu hakkındaki kararları — moderation/m_{uid} (yalnızca panel yazar,
## firestore.rules). Oyun giriş yapılınca, öne gelince (RESUME_SEC) ve CHECK_SEC'te bir okur:
##   ban {kind, reason, text, until, at}  SOSYAL: arkadaşlık / yarış / ziyaret / hediye / garaj yayını kapalı (kural sunucuda
##                                        zorlar; SocialManager.restricted_text oyuncuya söyler). TAM: oturum kapanır, misafir
##                                        olarak oynanır. İki türde de sebep + bitiş penceresi (BanNotice, kullanıcı kararı).
##   name + name_reset                    takma ad panelin verdiği ada döner (karar başına bir kez)
##   photo_reset                          profil fotoğrafı kaska döner (karar başına bir kez)
## Cihaz durumu user://moderation.json {uid: {name_reset, photo_reset, seen_ban}}: aynı karar ikinci kez uygulanmaz,
## sosyal yasak penceresi yasak başına bir kez çıkar (tam yasakta her girişte). Yasak bitince açık garaj yeniden yayınlanır.
## Oyun tek başına çevrimdışı oynanabildiği için yasak yalnızca çevrimiçi özellikleri kapatır (bilinçli).
## GarageSystem kurar; ziyarette yok. Firestore'a SocialManager'ın kuyruğuyla gider (read_moderation).

## Etkin yasak değişti (başladı / bitti / türü değişti).
signal ban_changed
## Yasak penceresi gösterilmeli (BanNotice): yeni sosyal yasak ya da tam yasak.
signal notice_requested(ban: Dictionary)

const FILE: String = "user://moderation.json"
const CHECK_SEC: float = 1800.0
const RESUME_SEC: float = 300.0
const KIND_SOCIAL: String = "social"
const KIND_FULL: String = "full"
## Panelin sebep anahtarları → oyuncuya gösterilen metin (Loc.t ile çevrilir).
const REASONS: Dictionary = {
	"name": "Uygunsuz takma ad",
	"photo": "Uygunsuz profil fotoğrafı",
	"cheat": "Hile",
	"harassment": "Taciz ya da hakaret",
	"spam": "Spam",
	"other": "Kural ihlali",
}

var _social: SocialManager
var _cloud: CloudSaveManager
var _profile: PlayerProfile
var _ban: Dictionary = {}
var _notice: Dictionary = {}   # gösterilmeyi bekleyen yasak (pencere sonradan kurulursa da kaçmasın: take_notice)
var _state: Dictionary = {}
var _busy: bool = false
var _last: float = -1.0e9
var _timer: Timer


func _ready() -> void:
	add_to_group("moderation")
	_state = _read()
	_timer = Timer.new()
	_timer.wait_time = CHECK_SEC
	_timer.timeout.connect(check)
	add_child(_timer)
	_timer.start()
	_connect.call_deferred()


func _connect() -> void:
	_social = get_tree().get_first_node_in_group("social") as SocialManager
	_cloud = get_tree().get_first_node_in_group("cloud_save") as CloudSaveManager
	_profile = get_tree().get_first_node_in_group("player_profile") as PlayerProfile
	if _cloud:
		_cloud.user_changed.connect(func(profile: Dictionary) -> void:
			if profile.is_empty():
				_notice = {}
				_set_ban({}))   # çıkış: yasak bu cihazda artık geçerli değil (misafir)
		# Girişin HEMEN ardından değil, bulut kararı verilince: kayıt yüklenirse sahne yeniden kurulur, eski sahnedeki
		# okumanın yanıtı ağaçtan çıkmış düğümlere düşerdi (yeni sahne açılışta kendisi okur). Tam yasaklı hesap OFFLINE kalır.
		_cloud.state_changed.connect(func(state: CloudSaveManager.State) -> void:
			if state in [CloudSaveManager.State.SYNCED, CloudSaveManager.State.OFFLINE, CloudSaveManager.State.ERROR]:
				check.call_deferred())
	check()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and Time.get_ticks_msec() / 1000.0 - _last > RESUME_SEC:
		check()


## Etkin yasak {kind, reason, text, until, at} ya da boş.
func ban() -> Dictionary:
	return _ban


func is_full_ban() -> bool:
	return SaveSafe.s(_ban.get("kind", "")) == KIND_FULL


## Moderasyon belgesini okur ve kararları uygular. Oturum açık olmalı (misafirin UID'si yok).
func check() -> void:
	if _busy or _social == null or _cloud == null or not _cloud.is_authenticated():
		return
	var uid: String = _cloud.get_uid()
	_busy = true
	_last = Time.get_ticks_msec() / 1000.0
	var result: Dictionary = await _social.read_moderation(uid)
	_busy = false
	if not is_inside_tree() or not bool(result.get("ok", false)) or not _cloud.is_authenticated() or uid != _cloud.get_uid():
		return   # sahne yenilendi, okunamadı ya da okurken hesap değişti: eldeki karar kalır
	apply_doc(uid, result.get("doc", {}))


## Belgeyi uygular (testler doğrudan çağırır).
func apply_doc(uid: String, doc: Dictionary) -> void:
	var mine: Dictionary = _state.get(uid, {}) if _state.get(uid) is Dictionary else {}
	var name_reset: int = SaveSafe.i(doc.get("name_reset", 0))
	if name_reset > SaveSafe.i(mine.get("name_reset", 0)):
		mine["name_reset"] = name_reset
		if _social:
			_social.adopt_moderated_name(SaveSafe.s(doc.get("name", "")))
			_social.notice.emit(Loc.t("Takma adın kurallara uymadığı için değiştirildi. PROFİL'den yeni bir ad seçebilirsin."))
	var photo_reset: int = SaveSafe.i(doc.get("photo_reset", 0))
	if photo_reset > SaveSafe.i(mine.get("photo_reset", 0)):
		mine["photo_reset"] = photo_reset
		if _profile:
			_profile.clear_photo_by_moderator()
		if _social:
			_social.notice.emit(Loc.t("Profil fotoğrafın kurallara uymadığı için kaldırıldı."))
	var ban_doc: Variant = doc.get("ban")
	var active: Dictionary = active_ban(ban_doc if ban_doc is Dictionary else {}, int(Time.get_unix_time_from_system()))
	if not active.is_empty():
		var at: int = SaveSafe.i(active.get("at", 0))
		if active["kind"] == KIND_FULL or at != SaveSafe.i(mine.get("seen_ban", 0)):
			mine["seen_ban"] = at
			_notice = active
			notice_requested.emit(active)
	_state[uid] = mine
	_write()
	_set_ban(active)


## Bekleyen yasak penceresini alır (BanNotice); bir kez döner.
func take_notice() -> Dictionary:
	var out: Dictionary = _notice
	_notice = {}
	return out


## Pencere kapandı: tam yasakta oturum kapanır (bulut kaydı zaten yazılamaz; cihazdaki ilerleme yedeklenir).
func acknowledge(shown: Dictionary) -> void:
	if SaveSafe.s(shown.get("kind", "")) == KIND_FULL and _cloud and _cloud.is_authenticated():
		_cloud.sign_out(true)


func _set_ban(active: Dictionary) -> void:
	var was: Dictionary = _ban
	_ban = active
	if _social:
		_social.restricted_text = restriction_text(active) if not active.is_empty() else ""
		if not was.is_empty() and active.is_empty() and _cloud and _cloud.is_authenticated():
			_social.force_republish()   # yasak bitti: panel yasakta açık garajı sildi
	if was != active:
		ban_changed.emit()


## Belgedeki yasak hâlâ geçerliyse temizlenmiş hâli, değilse boş. until 0 = kalıcı.
static func active_ban(raw: Dictionary, now: int) -> Dictionary:
	var kind: String = SaveSafe.s(raw.get("kind", ""))
	if kind != KIND_SOCIAL and kind != KIND_FULL:
		return {}
	var until: int = SaveSafe.i(raw.get("until", 0))
	if until > 0 and until <= now:
		return {}
	return {
		"kind": kind,
		"reason": SaveSafe.s(raw.get("reason", "other")),
		"text": SaveSafe.s(raw.get("text", "")).strip_edges().left(200),
		"until": until,
		"at": SaveSafe.i(raw.get("at", 0)),
	}


static func reason_text(ban: Dictionary) -> String:
	var key: String = SaveSafe.s(ban.get("reason", "other"))
	return Loc.t(String(REASONS.get(key, REASONS["other"])))


## "28 EKİM 2026 14:30" (yerel saat) ya da "Süresiz".
static func until_text(ban: Dictionary) -> String:
	var until: int = SaveSafe.i(ban.get("until", 0))
	if until <= 0:
		return Loc.t("Süresiz")
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var t: Dictionary = Time.get_datetime_dict_from_unix_time(until + bias)
	return "%s %02d:%02d" % [NewsDigest.date_text(t), int(t["hour"]), int(t["minute"])]


## Sosyal ekranlarda gösterilen kısa metin (SocialManager.restricted_text).
static func restriction_text(ban: Dictionary) -> String:
	return Loc.t("Hesabın sosyal özelliklerden kısıtlandı.\nSebep: %s · Bitiş: %s") % [reason_text(ban), until_text(ban)]


static func _read() -> Dictionary:
	if not FileAccess.file_exists(FILE):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	return parsed if parsed is Dictionary else {}


func _write() -> void:
	var file: FileAccess = FileAccess.open(FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_state))
