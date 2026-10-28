class_name SaveReminder
extends Node
## HESABA KAYDET HATIRLATMASI (2026-10-28, kullanıcı kararı: taslak B + C). Oyuncuların ~%62'si misafir: ilerlemesi
## yalnız telefonda durur, telefon değişir ya da oyun silinirse gider (misafirken alınan gem de). İki yer:
##   B — seviye THRESHOLDS'a (5, 10) varınca sakin bir anda BİR KEZ kart (SaveReminderCard; sakin anı Hud seçer).
##       Kartı görmüş misafir sonra hangi yoldan olursa olsun hesaba girip kaydı buluta eşitlenince BONUS_GEMS gem alır
##       (kayıt başına bir kez). Hesabın bulut kaydı seçilirse (KAYIT SEÇ → BULUT) o kayıt gelir, hediye yok.
##   C — misafirken MARKET'te uyarı şeridi (GemStoreScreen); HESABA KAYDET hesap panosunu açar.
## Kart ve şerit yalnız hesapla girişin olduğu yerde (Android: CloudSaveManager.is_available) çıkar; masaüstü / test
## `force_guest` ya da CT_SAVE_REMINDER=1 ile zorlar. GarageSystem kodla kurar ("save_reminder" grubu, SaveManager'dan
## ÖNCE); kayıt "save_reminder" (eski kayıtta yok: hiç gösterilmemiş, hediye alınmamış). İlerleme sayılmaz.

## Hediye hesaba geçti (Hud duyurur).
signal bonus_granted(gems: int)

const THRESHOLDS: Array[int] = [5, 10]
const BONUS_GEMS: int = 20
const FORCE_ENV: String = "CT_SAVE_REMINDER"
## Testler / ekran taraması: Firebase eklentisi olmadan da misafir sayılır.
static var force_guest: bool = false

var _shown: Array[int] = []
var _bonus: bool = false
var _cloud: CloudSaveManager


func _ready() -> void:
	add_to_group("save_reminder")
	_bind_cloud.call_deferred()


func _bind_cloud() -> void:
	if not is_inside_tree():
		return
	_cloud = get_tree().get_first_node_in_group("cloud_save") as CloudSaveManager
	if _cloud:
		_cloud.state_changed.connect(func(_state: CloudSaveManager.State) -> void: _check_bonus())
	_check_bonus()


## Hesapla giriş bu cihazda mümkün ve oturum yok.
func is_guest() -> bool:
	if force_guest or OS.get_environment(FORCE_ENV) == "1":
		return true
	return _cloud != null and _cloud.is_available() and not _cloud.is_authenticated()


## Bu seviyede gösterilmesi gereken eşik (yoksa 0): misafir değilse ya da eşik gösterildiyse 0.
func due(level: int) -> int:
	if not is_guest():
		return 0
	var out: int = 0
	for threshold: int in THRESHOLDS:
		if level >= threshold and not _shown.has(threshold):
			out = threshold
	return out


## Kart açıldı: bu seviyeye kadarki eşikler gösterilmiş sayılır (güncellemeyle sv12'de ilk kez gören oyuncuya tek kart).
func mark_shown(level: int) -> void:
	for threshold: int in THRESHOLDS:
		if level >= threshold and not _shown.has(threshold):
			_shown.append(threshold)
	Telemetry.event(&"save_prompt_show", {"level": level})
	_request_save()


func was_shown() -> bool:
	return not _shown.is_empty()


func bonus_claimed() -> bool:
	return _bonus


## Kaydı hesabın bulutuyla eşit (SYNCED): kartı görmüş oyuncuya hediye.
func _check_bonus() -> void:
	if _cloud and _cloud.is_authenticated() and _cloud.get_state() == CloudSaveManager.State.SYNCED:
		claim_bonus()


## Kartı görmüş misafirin kaydı hesaba geçti: BONUS_GEMS gem (bir kez). Verilen gem (verilmediyse 0).
func claim_bonus() -> int:
	if _bonus or _shown.is_empty() or not is_inside_tree():
		return 0
	var progress: PlayerProgress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress
	if progress == null:
		return 0
	_bonus = true
	progress.add_gems(BONUS_GEMS)
	Telemetry.event(&"save_bonus")
	_request_save()
	bonus_granted.emit(BONUS_GEMS)
	return BONUS_GEMS


# --- Kayıt (SaveManager) -------------------------------------------------------------------

func state() -> Dictionary:
	return {"shown": _shown.duplicate(), "bonus": _bonus}


func load_state(data: Dictionary) -> void:
	_shown.clear()
	var shown: Array = data.get("shown", []) if data.get("shown") is Array else []
	for value: Variant in shown:
		var threshold: int = SaveSafe.i(value)
		if THRESHOLDS.has(threshold) and not _shown.has(threshold):
			_shown.append(threshold)
	_bonus = SaveSafe.b(data.get("bonus", false))
	_check_bonus.call_deferred()   # misafir kaydı hesaba yeni geçtiyse (KAYIT SEÇ → BU CİHAZ) hediye


func reset() -> void:
	load_state({})


func _request_save() -> void:
	var save: SaveManager = get_tree().get_first_node_in_group("save_manager") as SaveManager if is_inside_tree() else null
	if save:
		save.request_save()
