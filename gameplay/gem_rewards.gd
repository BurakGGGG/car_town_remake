class_name GemRewards
extends Node
## TEKRARLAYAN GEM KAYNAKLARI — günlük giriş serisi (GÜNLÜK GİRİŞ MERDİVENİ), tamir bahşişi ve ustalık yıldızı gemi. Tasarım ve
## simülasyon: docs/vehicle_crate_design_v2.md §3. GÜNLÜK / HAFTALIK GÖREVLER ve tamir kilometre taşları
## artık GÖREVLER sistemindedir (gameplay/missions/, docs/gorevler_tasarimi.md); bu sınıf gün / hafta
## SAATİNİN tek kaynağı olarak kalır (MissionManager buradan okur).
## Seviye gemi PlayerProgress.LEVEL_REWARDS'ta, keşif / koleksiyon / kopya gemi CrateManager'dadır.
## "gem_rewards" grubundan bulunur (GarageSystem kodla kurar). Gem PlayerProgress.add_gems ile verilir.
##
## YENİ SAYAÇ KURMAZ: tamir → RepairManager.repair_collected, ustalık → JobMastery.mastery_up.
##
## SAAT GÜVENLİĞİ (cihaz saati oyuncunun elinde, sunucu saati yok):
##   * Gün, yerel tarihin epoch'tan gün numarasıdır ve kayıtta yalnızca İLERİ gider. Saat geri
##     alınırsa (gün < kayıttaki gün) hiçbir günlük ödül verilmez, görevler sıfırlanmaz, sayaçlar
##     kayıttaki güne yazılmaya devam eder. Gerçek saat kayıttaki güne yetişene kadar yeni ödül yok.
##   * Saat ileri alınırsa yalnızca O GÜNÜN ödülü alınır (kaçırılan günler telafi edilmez) ve seri
##     bozulur (gün farkı 1 değilse seri 1'e döner). Geri dönülünce yukarıdaki kural kilitler:
##     ileri almanın kazancı, gerçek zamanda o günler kaybedilerek geri ödenir.
##
## GÜNLÜK GİRİŞ MERDİVENİ (2026-10-23, docs/GIRIS_MERDIVENI.md): eski 7 günlük giriş elmasının (10-10-15-10-15-10-40,
## girişte kendiliğinden) yerine 28 basamak (LoginLadder). Basamak = ardışık giriş serisi (bir gün kaçırılınca 1. güne
## dönülür — kullanıcı kararı). Ödül girişte VERİLMEZ: merdiven ekranında AL ile alınır (ladder_ready → HUD ekranı açar).
## Alınmadan gün dönerse o basamağın ödülü kendiliğinden verilir (kaybolmaz). 28. gün alınınca ay tamamlanır; sonraki
## merdiven bir sonraki ayın dekorlarını verir (tamamlanan ay sayısı kayıtta).
##   * Her ödül (giriş, görev, bonus, haftalık) kayıtta işaretlidir: aynı gün / hafta iki kez verilmez.
##     İşaretler gemle aynı kayıt dosyasındadır; eski bir kayda dönmek gemleri de geri alır.

signal reward_granted(amount: int, text: String)
## Seri değişti (UI tazelensin).
signal daily_changed
## Yeni güne geçildi (yalnızca ileri; MissionManager yeni görevleri kurar).
signal day_changed(day: int)
## Yeni giriş günü: merdivenin bugünkü basamağı alınabilir (HUD oyun sakinleşince merdiven ekranını açar).
signal ladder_ready(day: int)
## Merdiven ödülü verildi: LoginLadder.reward sözlüğü; "auto" true ise alınmadan gün döndüğü için kendiliğinden.
signal ladder_claimed(reward: Dictionary)
const TIP_EVERY: int = 50
const TIP_DAILY_CAP: int = 3
const MASTERY_STAR_GEMS: int = 3
## Saatin "geri alındı" sayılması için tolerans (sn).
const ROLLBACK_TOLERANCE: int = 600

## Test: -1 değilse sistem saati yerine bu unix zamanı kullanılır.
var test_now: int = -1

var _login_day: int = -1
## Bugünün giriş ödülünün reklamla ikiye katlandığı gün (-1 = hiç).
var _login_doubled_day: int = -1
var _streak: int = 0
## Oyunun açıldığı FARKLI gün sayısı (ardışık olması gerekmez; seri bozulunca sıfırlanmaz). BİZİ DEĞERLENDİR penceresi
## buna bakar (CommunityLinks).
var _play_days: int = 0
## MERDİVEN: ödülün alındığı giriş günü (-1 = hiç), alınan elmas / ₺ (×2 bunları bir kez daha verir), tamamlanan ay.
var _claimed_day: int = -1
var _claimed_gems: int = 0
var _claimed_money: int = 0
var _months: int = 0
var _max_seen: int = 0
var _day: int = -1
var _tip_day: int = -1
var _tip_count: int = 0
var _tip_carry: int = 0
var _repair_step: int = 0   # ESKİ tamir kilometre taşı sayısı (başarıma göç için; artık ödenmez)
var _clock_rolled_back: bool = false
var _timer: Timer


func _ready() -> void:
	add_to_group("gem_rewards")
	_timer = Timer.new()
	_timer.wait_time = 30.0
	_timer.timeout.connect(check_day)
	add_child(_timer)
	_timer.start()
	_connect.call_deferred()


func _connect() -> void:
	var repairs: RepairManager = get_tree().get_first_node_in_group("repair_manager") as RepairManager
	if repairs:
		repairs.repair_collected.connect(_on_repair_collected)
	var mastery: JobMastery = get_tree().get_first_node_in_group("job_mastery") as JobMastery
	if mastery:
		mastery.mastery_up.connect(func(_id: StringName, _stars: int) -> void:
			_grant(MASTERY_STAR_GEMS, Loc.t("USTALIK YILDIZI  +%d GEM") % MASTERY_STAR_GEMS))
	# Kayıt yüklemesi SaveManager'ın ertelenmiş kurulumunda olur; ilk gün kontrolü ondan sonra.
	get_tree().create_timer(1.0).timeout.connect(check_day)


# --- Saat ----------------------------------------------------------------------------

func now_unix() -> int:
	return test_now if test_now >= 0 else int(Time.get_unix_time_from_system())


## Yerel tarihin epoch'tan gün numarası.
func day_key(unix: int) -> int:
	var bias_min: int = int(Time.get_time_zone_from_system().get("bias", 0))
	return floori(float(unix + bias_min * 60) / 86400.0)


## Pazartesi başlayan hafta numarası (epoch günü 0 Perşembe'dir).
static func week_key(day: int) -> int:
	return floori(float(day + 3) / 7.0)


func is_clock_rolled_back() -> bool:
	return _clock_rolled_back


## Gün değişimini işler: giriş ödülü, görev sıfırlama, hafta sıfırlama. Tekrar çağrılması güvenlidir.
func check_day() -> void:
	var now: int = now_unix()
	_clock_rolled_back = now < _max_seen - ROLLBACK_TOLERANCE
	_max_seen = maxi(_max_seen, now)
	var today: int = day_key(now)
	if today > _day:   # yalnızca ileri: saat geri alınırsa gün ilerlemez
		_day = today
		day_changed.emit(today)
	if today > _login_day:
		if can_claim():
			_claim(true)   # önceki giriş günün basamağı alınmamıştı: kaybolmasın
		_streak = _streak + 1 if today == _login_day + 1 else 1
		_play_days += 1
		_login_day = today
		daily_changed.emit()
		ladder_ready.emit(ladder_day())
	_request_save()


func streak() -> int:
	return _streak


## Oyunun açıldığı farklı gün sayısı (bugün dahil).
func play_days() -> int:
	return _play_days


# --- Günlük giriş merdiveni ------------------------------------------------------------

## Merdivenin bugünkü basamağı (1..28): ardışık giriş serisinden.
func ladder_day() -> int:
	return (maxi(_streak, 1) - 1) % LoginLadder.DAYS + 1


## Kaçıncı merdiven (ay; 1'den): tamamlanan ay + 1. Bugün 28. gün alındıysa az önce biten ay.
func ladder_month() -> int:
	return _months + (0 if ladder_day() == LoginLadder.DAYS and not can_claim() else 1)


## Tamamlanan merdiven (ay) sayısı.
func months_done() -> int:
	return _months


## Bugünün (son giriş gününün) basamağı alınabilir mi.
func can_claim() -> bool:
	return _login_day >= 0 and _claimed_day != _login_day


## `day` basamağının ödülü (bu ay — `month` verilirse o ay —, oyuncunun şu anki geliriyle) — ekran önizlemesi için.
func ladder_reward(day: int, month: int = 0) -> Dictionary:
	return LoginLadder.reward(day, month if month > 0 else ladder_month(), _income())


## AL: bugünün basamağı verilir. Dönen: verilen ödül (alınacak yoksa boş).
func claim_ladder() -> Dictionary:
	return _claim(false) if can_claim() else {}


func _claim(auto: bool) -> Dictionary:
	var reward: Dictionary = LoginLadder.reward(ladder_day(), ladder_month(), _income())
	_claimed_day = _login_day
	var decor: StringName = reward["decor"]
	if decor != &"":
		var decor_manager: DecorManager = get_tree().get_first_node_in_group("decor") as DecorManager
		if decor_manager == null or not decor_manager.grant(decor, 1):
			# Eşya verilemedi (zaten sahip / yönetici yok): yerine o günün yedek elması
			reward["decor"] = &""
			reward["gems"] = int(reward["gems"]) + (LoginLadder.FALLBACK_MONTH_GEMS if bool(reward["month_end"]) \
				else LoginLadder.FALLBACK_WEEK_GEMS)
	_claimed_gems = int(reward["gems"])
	_claimed_money = int(reward["money"])
	_grant(_claimed_gems, "")   # bildirimi merdiven ekranı / HUD gösterir
	if _claimed_money > 0:
		var economy: EconomyManager = get_tree().get_first_node_in_group("economy") as EconomyManager
		if economy:
			economy.add_money(_claimed_money)
	if bool(reward["month_end"]):
		_months += 1
	reward["auto"] = auto
	ladder_claimed.emit(reward)
	daily_changed.emit()
	_request_save()
	return reward


## GÜNLÜK GİRİŞ ×2 (ödüllü reklam): bugün alınan basamağın elması / ₺'si bir kez daha (dekor ikiye katlanmaz).
## {"gems", "money"}; bugün alınmadıysa / zaten ikiye katlandıysa / katlanacak yoksa boş.
func ladder_double() -> Dictionary:
	if _claimed_day != _login_day or _login_doubled_day == _login_day or _login_day != day_key(now_unix()) \
			or (_claimed_gems <= 0 and _claimed_money <= 0):
		return {}
	return {"gems": _claimed_gems, "money": _claimed_money}


## Reklam ödülü: ladder_double kadar bir kez daha verilir. Dönen: verilen (boşsa verilmedi). announce false: bildirim
## yok (ödül penceresi gösteren ekran).
func double_ladder(announce: bool = true) -> Dictionary:
	var extra: Dictionary = ladder_double()
	if extra.is_empty():
		return {}
	_login_doubled_day = _login_day
	var gems: int = int(extra["gems"])
	var money: int = int(extra["money"])
	if money > 0:
		var economy: EconomyManager = get_tree().get_first_node_in_group("economy") as EconomyManager
		if economy:
			economy.add_money(money)
	var text: String = ""
	if announce:
		text = Loc.t("GÜNLÜK GİRİŞ ×2") + "\n" + (Loc.t("+%d GEM") % gems if gems > 0 else "+%s ₺" % Hud.format_thousands(money))
	if gems > 0:
		_grant(gems, text)
	elif announce:
		reward_granted.emit(0, text)
	daily_changed.emit()
	_request_save()
	return extra


## Oyuncunun aktif oyun geliri (₺/dk; merdivenin para ödülleri buna bağlı).
func _income() -> float:
	var offline: OfflineEarnings = get_tree().get_first_node_in_group("offline_earnings") as OfflineEarnings \
		if is_inside_tree() else null
	return offline.current_active_rate() if offline else LoginLadder.FALLBACK_INCOME


# --- Tamir: bahşiş ------------------------------------------------------

func _on_repair_collected(_car: Node3D, _reward: int, _xp: int) -> void:
	var today: int = maxi(day_key(now_unix()), _day)
	if today != _tip_day:
		_tip_day = today
		_tip_count = 0
	_tip_carry += 1
	if _tip_carry >= TIP_EVERY:
		_tip_carry -= TIP_EVERY
		if _tip_count < TIP_DAILY_CAP:
			_tip_count += 1
			_grant(1, "")   # bahşiş sessizdir (sık gelir); gem plakası artışı gösterir


## Eski kayıttaki ödenmiş tamir kilometre taşı sayısı (TAMİRCİ başarımına göç: MissionManager okur).
func legacy_repair_step() -> int:
	return _repair_step


# --- Kayıt ---------------------------------------------------------------------------------

func state() -> Dictionary:
	return {
		"login": {"day": _login_day, "streak": _streak, "doubled": _login_doubled_day, "claimed": _claimed_day,
			"cg": _claimed_gems, "cm": _claimed_money, "months": _months, "days": _play_days},
		"max_seen": _max_seen,
		"day": _day,
		"tips": {"day": _tip_day, "count": _tip_count, "carry": _tip_carry},
		"repair_step": _repair_step,
	}


func load_state(data: Dictionary) -> void:
	var login: Dictionary = data.get("login", {}) if data.get("login") is Dictionary else {}
	_login_day = SaveSafe.i(login.get("day", -1))
	_streak = maxi(SaveSafe.i(login.get("streak", 0)), 0)
	_login_doubled_day = SaveSafe.i(login.get("doubled", -1))
	# Merdiven alanları yoksa (eski kayıt: giriş elması girişte verilmişti) son giriş günü alınmış sayılır
	_claimed_day = SaveSafe.i(login.get("claimed", _login_day))
	_claimed_gems = maxi(SaveSafe.i(login.get("cg", 0)), 0)
	_claimed_money = maxi(SaveSafe.i(login.get("cm", 0)), 0)
	_months = maxi(SaveSafe.i(login.get("months", 0)), 0)
	_play_days = maxi(SaveSafe.i(login.get("days", 0)), 0)
	_max_seen = maxi(SaveSafe.i(data.get("max_seen", 0)), 0)
	# Eski kayıt: günlük görev bölümündeki gün (geriye dönük uyum); yeni kayıt "day" yazar
	var legacy: Dictionary = data.get("daily", {}) if data.get("daily") is Dictionary else {}
	_day = SaveSafe.i(data.get("day", legacy.get("day", -1)))
	var tips: Dictionary = data.get("tips", {}) if data.get("tips") is Dictionary else {}
	_tip_day = SaveSafe.i(tips.get("day", -1))
	_tip_count = clampi(SaveSafe.i(tips.get("count", 0)), 0, TIP_DAILY_CAP)
	_tip_carry = clampi(SaveSafe.i(tips.get("carry", 0)), 0, TIP_EVERY - 1)
	_repair_step = clampi(SaveSafe.i(data.get("repair_step", 0)), 0, 5)
	daily_changed.emit()


## Yeni oyun: seri ve görevler sıfırdan (ilk check_day bugünün basamağını açar).
func reset() -> void:
	load_state({})
	check_day.call_deferred()


# --- İç ----------------------------------------------------------------------------------

func _grant(amount: int, text: String) -> void:
	if amount <= 0:
		return
	var progress: PlayerProgress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress
	if progress:
		progress.add_gems(amount)
	reward_granted.emit(amount, text)


func _request_save() -> void:
	var save: Node = get_tree().get_first_node_in_group("save_manager")
	if save and save.has_method(&"request_save"):
		save.request_save()
