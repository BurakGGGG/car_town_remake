class_name CommunityLinks
extends Node
## TOPLULUK BAĞLANTILARI (2026-10-24) — MARKET › ÜCRETSİZ sekmesindeki takip ödülleri ve BİZİ DEĞERLENDİR penceresinin
## zamanlaması. GarageSystem kodla kurar ("community" grubu, SaveManager'dan ÖNCE); kayıt "community".
##
## TAKİP ÖDÜLÜ: Instagram / TikTok hesabımızı takip eden FOLLOW_GEMS gem alır, her hesap bir kez. Takip doğrulanamaz
## (iki platformun da herkese açık API'si yok): TAKİP ET bağlantıyı açar ve ödülü alınabilir yapar, oyuncu dönünce
## ÖDÜLÜ AL ile alır. "Açıldı" durumu da kayıtta: telefon oyunu arkada kapatırsa dönünce yeniden açmak gerekmez.
##
## DEĞERLENDİRME (kullanıcı kararı): Play politikası değerlendirme karşılığı ödülü YASAKLAR ("Don't offer rewards or
## incentives for ratings or reviews") → gem YOK. Oyuncu RATE_FIRST_DAY farklı günde oyuna girince sakin bir anda bir
## kez sorulur (Hud._arm_rate_prompt); SONRA → RATE_RETRY_DAYS oyun günü sonra yeniden, en çok RATE_MAX_ASKS kez.
## DEĞERLENDİR → Play mağaza sayfası, bir daha sorulmaz. Oyun günü GemRewards.play_days'tir (saat geri alınınca ilerlemez).
## Pencere "beğendin mi?" diye sormaz: Google memnun olanı ayıklayan soruyu da istemiyor.

## Durum / ödül değişti (MARKET kartları tazelensin).
signal changed

const FOLLOW_GEMS: int = 10
## Sıra MARKET'teki kart sırasıdır. `name` marka adı (çevrilmez), `art`: GemPackArt.Kind (kartın logosu).
const LINKS: Array[Dictionary] = [
	{"id": &"instagram", "name": "INSTAGRAM", "url": "https://www.instagram.com/autoyardgame",
		"art": GemPackArt.Kind.INSTAGRAM},
	{"id": &"tiktok", "name": "TIKTOK", "url": "https://www.tiktok.com/@autoyardgame", "art": GemPackArt.Kind.TIKTOK},
]
## Takip durumu: bağlantı hiç açılmadı / açıldı (ödül alınabilir) / ödül alındı.
enum Follow { NONE, OPENED, CLAIMED }

## Kaçıncı farklı oyun gününde ilk kez sorulur.
const RATE_FIRST_DAY: int = 3
## SONRA dendikten kaç oyun günü sonra yeniden sorulur.
const RATE_RETRY_DAYS: int = 4
const RATE_MAX_ASKS: int = 2

## Bağlantıyı açan (testler değiştirir; tarayıcı açılmasın).
var opener: Callable = func(url: String) -> void: OS.shell_open(url)

var _follow: Dictionary = {}   # id (String) → Follow
var _rate_asks: int = 0
var _rate_next: int = RATE_FIRST_DAY
var _rated: bool = false


func _ready() -> void:
	add_to_group("community")


# --- Takip ödülü ---------------------------------------------------------------------------

func follow_state(id: StringName) -> Follow:
	return _follow.get(String(id), Follow.NONE)


## Ödülü henüz alınmamış takip kartı sayısı (ÜCRETSİZ sekmesinin rozeti).
func unclaimed() -> int:
	var count: int = 0
	for link: Dictionary in LINKS:
		if follow_state(link["id"]) != Follow.CLAIMED:
			count += 1
	return count


## TAKİP ET: hesabın sayfasını açar; ödül ilk açılışta alınabilir olur.
func open_link(id: StringName) -> void:
	var link: Dictionary = _link(id)
	if link.is_empty():
		return
	opener.call(String(link["url"]))
	Telemetry.event(&"follow_open", {"network": String(id)})
	if follow_state(id) == Follow.NONE:
		_follow[String(id)] = Follow.OPENED
		_request_save()
		changed.emit()


## ÖDÜLÜ AL: bağlantı açıldıysa FOLLOW_GEMS gem verir (bir kez). Verilen gem (alınamıyorsa 0).
func claim(id: StringName) -> int:
	if follow_state(id) != Follow.OPENED:
		return 0
	var progress: PlayerProgress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress
	if progress == null:
		return 0
	_follow[String(id)] = Follow.CLAIMED
	progress.add_gems(FOLLOW_GEMS)
	Telemetry.event(&"follow_claim", {"network": String(id)})
	_request_save()
	changed.emit()
	return FOLLOW_GEMS


static func _link(id: StringName) -> Dictionary:
	for link: Dictionary in LINKS:
		if link["id"] == id:
			return link
	return {}


# --- Değerlendirme -------------------------------------------------------------------------

## Bu oyun gününde BİZİ DEĞERLENDİR sorulmalı mı? (sakin an / oturum süresi Hud'da)
func wants_rating(play_days: int) -> bool:
	return not _rated and _rate_asks < RATE_MAX_ASKS and play_days >= _rate_next


## Pencere açıldı: ne seçilirse seçilsin bu sayılır (SONRA → RATE_RETRY_DAYS gün sonra).
func mark_rating_asked(play_days: int) -> void:
	_rate_asks += 1
	_rate_next = play_days + RATE_RETRY_DAYS
	Telemetry.event(&"rate_prompt", {"ask": _rate_asks})
	_request_save()


## DEĞERLENDİR: Play mağaza sayfası (Android'de Play uygulaması); bir daha sorulmaz.
func rate_now() -> void:
	_rated = true
	Telemetry.event(&"rate_open")
	_request_save()
	var package: String = AppConfig.STORE_PACKAGE
	opener.call("market://details?id=" + package if OS.get_name() == "Android"
		else "https://play.google.com/store/apps/details?id=" + package)


func is_rated() -> bool:
	return _rated


# --- Kayıt (SaveManager) -------------------------------------------------------------------

func state() -> Dictionary:
	return {"follow": _follow.duplicate(), "rate": {"asks": _rate_asks, "next": _rate_next, "done": _rated}}


func load_state(data: Dictionary) -> void:
	_follow.clear()
	var follow: Dictionary = data.get("follow", {}) if data.get("follow") is Dictionary else {}
	for link: Dictionary in LINKS:
		var key: String = String(link["id"])
		var value: int = clampi(SaveSafe.i(follow.get(key, Follow.NONE)), Follow.NONE, Follow.CLAIMED)
		if value != Follow.NONE:
			_follow[key] = value
	var rate: Dictionary = data.get("rate", {}) if data.get("rate") is Dictionary else {}
	_rate_asks = clampi(SaveSafe.i(rate.get("asks", 0)), 0, RATE_MAX_ASKS)
	_rate_next = maxi(SaveSafe.i(rate.get("next", RATE_FIRST_DAY)), RATE_FIRST_DAY)
	_rated = SaveSafe.b(rate.get("done", false))
	changed.emit()


func reset() -> void:
	load_state({})


func _request_save() -> void:
	var save: SaveManager = get_tree().get_first_node_in_group("save_manager") as SaveManager if is_inside_tree() else null
	if save:
		save.request_save()
