class_name AdPolicy
extends RefCounted
## REKLAM KURALLARI — saf, durumsuz, test edilebilir. Hangi ödüllü teklif, ne zaman, kaç kez sunulur.
##
## AdMob politikası: ödüllü reklam yalnızca oyuncunun AÇIK onayıyla (bir plakaya basarak) gösterilir;
## reddetmek hiçbir şeyi engellemez. Buradaki sınırlar politika değil, oyun dengesi / oyuncu deneyimi içindir.
## Kullanıcı kararı (2026-10-23): YALNIZCA ödüllü reklam — ara reklam, banner, açılış reklamı ve kendiliğinden açılan
## "reklam izle" penceresi YOK; her teklif oyuncunun açtığı ekranda bir düğmedir. Elmas da verilir (MARKET ÜCRETSİZ
## ELMAS; eski "gem verilmez" kararı kalktı) ama sınırlı: günde en çok FREE_GEMS_AMOUNT × 5.
## Sınırlar yönetim panelinden (config/app.ads) değiştirilebilir: remote (normalize_remote) varsayılanların üstüne yazar.

## Teklif türleri. Yeni tür = buraya satır eklemek (başka kod değişmez).
const RACE_DOUBLE: StringName = &"race_double"        # yarış sonucu: ₺ ödülü ×2
const REPAIR_BOOST: StringName = &"repair_boost"      # uzun tamir: kalan süreyi kısalt
const LEVELUP_DOUBLE: StringName = &"levelup_double"  # SEVİYE ATLADIN: ₺ ödülü ×2
const FREE_GEMS: StringName = &"free_gems"            # MARKET › ÜCRETSİZ ELMAS: +FREE_GEMS_AMOUNT elmas
const OFFLINE_DOUBLE: StringName = &"offline_double"  # OTO MANŞET: sen yokken kazanılan ₺ ×2
const TIME_SKIP: StringName = &"time_skip"            # modifiye / depo inşası / iç yükseltme: kalan süre yarıya
const DAILY_DOUBLE: StringName = &"daily_double"      # günlük giriş elması ×2
const MISSION_REROLL: StringName = &"mission_reroll"  # beğenilmeyen günlük görevi değiştir
const JUNK_REFILL: StringName = &"junk_refill"        # hurdalıkta boş bir yığını hemen doldur
const EVENT_RACE: StringName = &"event_race"          # ETKİNLİK YARIŞI: bugün +1 hak (EventCar)

## daily_cap: o türden günde en çok · min_level: bu seviyeden önce teklif yok (ilk deneyim reklamsız).
## slot: hangi reklam yuvasından (AdConfig) gösterilir · cooldown_sec: aynı türden iki izleme arası bekleme (kayıtta,
## uygulama kapansa da sürer).
const RULES: Dictionary = {
	RACE_DOUBLE: {"daily_cap": 5, "min_level": 3, "slot": &"race"},
	REPAIR_BOOST: {"daily_cap": 8, "min_level": 5, "slot": &"repair"},
	LEVELUP_DOUBLE: {"daily_cap": 3, "min_level": 3, "slot": &"race"},
	FREE_GEMS: {"daily_cap": 5, "min_level": 3, "slot": &"race", "cooldown_sec": 180},
	OFFLINE_DOUBLE: {"daily_cap": 2, "min_level": 3, "slot": &"race"},
	TIME_SKIP: {"daily_cap": 8, "min_level": 3, "slot": &"repair"},
	DAILY_DOUBLE: {"daily_cap": 1, "min_level": 3, "slot": &"race"},
	MISSION_REROLL: {"daily_cap": 1, "min_level": 3, "slot": &"race"},
	JUNK_REFILL: {"daily_cap": 2, "min_level": 3, "slot": &"repair"},
	EVENT_RACE: {"daily_cap": 1, "min_level": 3, "slot": &"race"},
}

## Bütün türler toplamı günde en çok.
const TOTAL_DAILY_CAP: int = 20
## ÜCRETSİZ ELMAS: reklam başına elmas.
const FREE_GEMS_AMOUNT: int = 5
## SÜRE KISALTMA: kalan sürenin bu payı düşer, en çok TIME_SKIP_MAX sn; kalan bundan kısaysa teklif yok (iş başına bir).
const TIME_SKIP_SHARE: float = 0.5
const TIME_SKIP_MAX: float = 1800.0
const TIME_SKIP_MIN_LEFT: float = 120.0
## Panel ayarlarının sınırları (normalize_remote).
const REMOTE_CAP_MAX: int = 50
const REMOTE_TOTAL_MAX: int = 100
const REMOTE_GEMS_MAX: int = 50
const REMOTE_COOLDOWN_MAX: int = 3600

## Yönetim panelinin ayarı (config/app.ads, normalize edilmiş): {total_cap, free_gems, free_gems_cooldown, caps {tür: n}}.
## AdService AppConfig değişince yazar; boşsa varsayılanlar.
static var remote: Dictionary = {}
## İki reklam arası en az bekleme (oturum içi, ms). Hızlı üst üste teklif/istismar engeli.
const MIN_GAP_MS: int = 45_000

## Engel nedenleri (boş = uygun).
const OK: StringName = &""
const UNKNOWN_KIND: StringName = &"unknown_kind"
const LEVEL_LOW: StringName = &"level_low"
const DAILY_CAP: StringName = &"daily_cap"
const TOTAL_CAP: StringName = &"total_cap"
const TOO_SOON: StringName = &"too_soon"
const COOLDOWN: StringName = &"cooldown"


## Teklif türünün reklam yuvası (bilinmeyen tür → boş).
static func slot_of(kind: StringName) -> StringName:
	return StringName(RULES.get(kind, {}).get("slot", &""))


static func kinds() -> Array[StringName]:
	var out: Array[StringName] = []
	for k: Variant in RULES:
		out.append(StringName(k))
	return out


## state: {"day": int, "counts": {tür: int}, "last": {tür: unix sn}}. last_ad_ms: son reklamın bitiş zamanı (-1 = bu
## oturumda yok). now_unix: tür beklemesi için (0 = bekleme denetlenmez).
static func block_reason(kind: StringName, state: Dictionary, level: int, now_ms: int, last_ad_ms: int,
		now_unix: int = 0) -> StringName:
	if not RULES.has(kind):
		return UNKNOWN_KIND
	var rule: Dictionary = RULES[kind]
	if level < int(rule["min_level"]):
		return LEVEL_LOW
	var counts: Dictionary = state.get("counts", {})
	if int(counts.get(kind, 0)) >= daily_cap(kind):
		return DAILY_CAP
	if total_today(state) >= total_cap():
		return TOTAL_CAP
	if now_unix > 0 and cooldown_left(kind, state, now_unix) > 0:
		return COOLDOWN
	if last_ad_ms >= 0 and now_ms - last_ad_ms < MIN_GAP_MS:
		return TOO_SOON
	return OK


## Türün günlük sınırı (panel ayarı varsa o; 0 = tür kapalı).
static func daily_cap(kind: StringName) -> int:
	var caps: Dictionary = remote.get("caps", {})
	if caps.has(kind):
		return int(caps[kind])
	return int(RULES.get(kind, {}).get("daily_cap", 0))


static func total_cap() -> int:
	return int(remote.get("total_cap", TOTAL_DAILY_CAP))


## ÜCRETSİZ ELMAS reklam başına.
static func free_gems() -> int:
	return int(remote.get("free_gems", FREE_GEMS_AMOUNT))


## Türün iki izleme arası beklemesi (sn).
static func cooldown_sec(kind: StringName) -> int:
	if kind == FREE_GEMS and remote.has("free_gems_cooldown"):
		return int(remote["free_gems_cooldown"])
	return int(RULES.get(kind, {}).get("cooldown_sec", 0))


## Beklemenin bitmesine kalan sn (0 = izlenebilir).
static func cooldown_left(kind: StringName, state: Dictionary, now_unix: int) -> int:
	var wait: int = cooldown_sec(kind)
	var last: Dictionary = state.get("last", {})
	if wait <= 0 or not last.has(kind):
		return 0
	return maxi(int(last[kind]) + wait - now_unix, 0)


## SÜRE KISALTMA: bu kalan süreden kaç sn düşer (teklif yoksa 0).
static func time_cut(remaining: float) -> float:
	if remaining < TIME_SKIP_MIN_LEFT:
		return 0.0
	return minf(remaining * TIME_SKIP_SHARE, TIME_SKIP_MAX)


## Panelin ayarı (config/app.ads) → sınırlanmış sözlük. Bozuk alan atlanır (varsayılan kalır).
static func normalize_remote(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not raw is Dictionary:
		return out
	var r: Dictionary = raw
	if r.has("total_cap"):
		out["total_cap"] = clampi(SaveSafe.i(r["total_cap"]), 0, REMOTE_TOTAL_MAX)
	if r.has("free_gems"):
		out["free_gems"] = clampi(SaveSafe.i(r["free_gems"]), 1, REMOTE_GEMS_MAX)
	if r.has("free_gems_cooldown"):
		out["free_gems_cooldown"] = clampi(SaveSafe.i(r["free_gems_cooldown"]), 0, REMOTE_COOLDOWN_MAX)
	var caps: Dictionary = {}
	if r.get("caps") is Dictionary:
		for key: Variant in (r["caps"] as Dictionary):
			var kind: StringName = StringName(SaveSafe.s(key))
			if RULES.has(kind):
				caps[kind] = clampi(SaveSafe.i((r["caps"] as Dictionary)[key]), 0, REMOTE_CAP_MAX)
	if not caps.is_empty():
		out["caps"] = caps
	return out


static func total_today(state: Dictionary) -> int:
	var total: int = 0
	var counts: Dictionary = state.get("counts", {})
	for k: Variant in counts:
		total += maxi(int(counts[k]), 0)
	return total


## Yerel takvim günü numarası (epoch'tan beri). bias_minutes: Time.get_time_zone_from_system().bias.
static func day_number(unix_time: float, bias_minutes: int) -> int:
	return int(floorf((unix_time + float(bias_minutes) * 60.0) / 86400.0))


## Gün ilerlediyse sayaçlar sıfırlanır. Gün GERİ giderse (saat geri alındı) sayaçlara DOKUNULMAZ ve
## gün değeri korunur: saat oyunuyla günlük sınır sıfırlanamaz (GemRewards ile aynı ilke).
static func roll_day(state: Dictionary, today: int) -> Dictionary:
	var saved_day: int = int(state.get("day", -1))
	if today > saved_day:
		return {"day": today, "counts": {}, "last": (state.get("last", {}) as Dictionary).duplicate()}   # bekleme gece yarısını geçer
	return state
