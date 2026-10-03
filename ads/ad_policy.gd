class_name AdPolicy
extends RefCounted
## REKLAM KURALLARI — saf, durumsuz, test edilebilir. Hangi ödüllü teklif, ne zaman, kaç kez sunulur.
##
## AdMob politikası: ödüllü reklam yalnızca oyuncunun AÇIK onayıyla (bir plakaya basarak) gösterilir;
## reddetmek hiçbir şeyi engellemez. Buradaki sınırlar politika değil, oyun dengesi / oyuncu deneyimi içindir.
## Ödül YALNIZCA para (₺) ve süre kısaltmadır — gem verilmez (kasa dengesi korunur).

## Teklif türleri. Yeni tür = buraya satır eklemek (başka kod değişmez).
const RACE_DOUBLE: StringName = &"race_double"        # yarış sonucu: ₺ ödülü ×2
const REPAIR_BOOST: StringName = &"repair_boost"      # uzun tamir: kalan süreyi kısalt
const LEVELUP_DOUBLE: StringName = &"levelup_double"  # seviye atlama ₺ ödülü ×2

## daily_cap: o türden günde en çok · min_level: bu seviyeden önce teklif yok (ilk deneyim reklamsız).
## slot: hangi reklam yuvasından (AdConfig) gösterilir.
const RULES: Dictionary = {
	RACE_DOUBLE: {"daily_cap": 5, "min_level": 3, "slot": &"race"},
	REPAIR_BOOST: {"daily_cap": 8, "min_level": 5, "slot": &"repair"},
	LEVELUP_DOUBLE: {"daily_cap": 3, "min_level": 3, "slot": &"race"},
}

## Bütün türler toplamı günde en çok.
const TOTAL_DAILY_CAP: int = 12
## İki reklam arası en az bekleme (oturum içi, ms). Hızlı üst üste teklif/istismar engeli.
const MIN_GAP_MS: int = 45_000

## Engel nedenleri (boş = uygun).
const OK: StringName = &""
const UNKNOWN_KIND: StringName = &"unknown_kind"
const LEVEL_LOW: StringName = &"level_low"
const DAILY_CAP: StringName = &"daily_cap"
const TOTAL_CAP: StringName = &"total_cap"
const TOO_SOON: StringName = &"too_soon"


## Teklif türünün reklam yuvası (bilinmeyen tür → boş).
static func slot_of(kind: StringName) -> StringName:
	return StringName(RULES.get(kind, {}).get("slot", &""))


static func kinds() -> Array[StringName]:
	var out: Array[StringName] = []
	for k: Variant in RULES:
		out.append(StringName(k))
	return out


## state: {"day": int, "counts": {tür: int}}. last_ad_ms: son reklamın bitiş zamanı (-1 = bu oturumda yok).
static func block_reason(kind: StringName, state: Dictionary, level: int, now_ms: int, last_ad_ms: int) -> StringName:
	if not RULES.has(kind):
		return UNKNOWN_KIND
	var rule: Dictionary = RULES[kind]
	if level < int(rule["min_level"]):
		return LEVEL_LOW
	var counts: Dictionary = state.get("counts", {})
	if int(counts.get(kind, 0)) >= int(rule["daily_cap"]):
		return DAILY_CAP
	if total_today(state) >= TOTAL_DAILY_CAP:
		return TOTAL_CAP
	if last_ad_ms >= 0 and now_ms - last_ad_ms < MIN_GAP_MS:
		return TOO_SOON
	return OK


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
		return {"day": today, "counts": {}}
	return state
