class_name Leaderboard
extends Node
## HAFTALIK DRAG LİDER TABLOSU — oyun tarafı (2026-10-26; docs/LIDER_TABLOSU.md, kullanıcı kararları). Her drag yarışı
## sayılır: yarış bitince (RaceManager.run_recorded) oyuncunun o haftaki, o sınıftaki EN İYİ 300 m süresi
## lb_runs/{wk}_{cls}_{uid}'e yazılır — yalnız hesaplıysa (SocialManager oturumu), etkinlik aracıyla değilse ve bu haftanın
## o sınıftaki en iyisiyse. Sınıf, aracın katalog sınıfıdır (D C B A S). Hafta Pazartesi 00:00 Türkiye'de döner (week_of).
## Sıralamayı sunucu (functions lbRun) özet belgelere işler: lb/{wk}_{cls} (dünya) ve lb/{wk}_{cls}_{ÜLKE} = {count, hist,
## top}. Oyun onları OTURUMSUZ REST ile okur (misafir de görür; eklenti sorgu yapamaz). Arkadaş listesi arkadaşların kendi
## kayıtlarından (tek tek okuma). Oyuncunun sırası özetteki süre kovalarından (hist) hesaplanır: rank_in.
## Tablodaki koşu YALNIZ İZLENİR: run (Recording.to_dict JSON'u) indirilir, DragRaceScreen kayıttan oynatır.
## Yazılan en iyi süreler cihazda user://leaderboard.json'da tutulur (yeni cihazda ilk yarışta sunucudaki kayıttan öğrenilir).
## GarageSystem kurar (ziyarette yok), "leaderboard" grubundan bulunur.

## Özetler / kendi en iyilerim değişti (ekran tazelenir).
signal changed
## Yarıştan sonra (sonuç ekranının şeridi): {cls, wk, time, best, improved, old_rank, rank, count, pct, guest, failed}.
signal submitted(info: Dictionary)

const BASE_URL: String = "https://firestore.googleapis.com/v1/projects/car-town-remake/databases/(default)/documents/"
const RUNS: String = "lb_runs"
const SUMMARIES: String = "lb"
const CLASSES: Array[StringName] = [&"D", &"C", &"B", &"A", &"S"]
## Türkiye saati (UTC+3, yaz saati yok): hafta Pazartesi 00:00'da döner.
const TZ_OFFSET: int = 10800
## Süre kovası: floor(süre × BUCKETS_PER_SEC) (sunucuyla aynı).
const BUCKETS_PER_SEC: float = 20.0
const FRESH_SEC: float = 60.0
const TIMEOUT_SEC: float = 10.0
const FILE: String = "user://leaderboard.json"
const NAME_MAX: int = 16
## Ödül kademeleri (sunucu lbWeekly ile aynı): ilk 3, ilk %10, ilk %50. Tutarlar config/app.leaderboard.rewards'tan.
const TIERS: Array[StringName] = [&"top3", &"p10", &"p50"]
const DEFAULT_REWARDS: Dictionary = {
	&"top3": {"gems": 150, "crate": "super_crate"},
	&"p10": {"gems": 50, "crate": "sport_crate"},
	&"p50": {"gems": 15, "crate": ""},
}

## Testler: -1 değilse cihaz saati yerine bu unix zamanı.
static var test_now: int = -1

## REST kökü; testler "" verir (ağa çıkılmaz, inject ile beslenir).
var base_url: String = BASE_URL
var _best: Dictionary = {}    # "wk_cls" → {t: bu cihazdan yazılmış / öğrenilmiş en iyi süre, car}
var _cache: Dictionary = {}   # belge yolu → {at, data}
var _race: RaceManager


func _ready() -> void:
	add_to_group("leaderboard")
	_best = _read()
	_connect.call_deferred()


func _connect() -> void:
	_race = get_tree().get_first_node_in_group("race") as RaceManager
	if _race:
		_race.run_recorded.connect(_on_run_recorded)


# --- Hafta / sınıf ---------------------------------------------------------------

static func now() -> int:
	return test_now if test_now >= 0 else int(Time.get_unix_time_from_system())


## Pazartesi'den başlayan hafta numarası (Türkiye saati). Unix 0 bir Perşembe: +3 gün Pazartesi hizası.
static func week_of(unix: int) -> int:
	var day: int = floori(float(unix + TZ_OFFSET) / 86400.0)
	return floori(float(day + 3) / 7.0)


static func current_week() -> int:
	return week_of(now())


## Haftanın bitişi (sonraki Pazartesi 00:00 TR) — sıfırlanma geri sayımı.
static func week_end(wk: int) -> int:
	return (wk * 7 - 3 + 7) * 86400 - TZ_OFFSET


## Aracın tablo sınıfı (katalog sınıfı); bilinmiyorsa &"".
static func class_of(car: StringName) -> StringName:
	var cls: StringName = StringName(String(CarCatalog.get_entry(car).get("class", "")))
	return cls if CLASSES.has(cls) else &""


static func doc_id(wk: int, cls: StringName, uid: String) -> String:
	return "%d_%s_%s" % [wk, cls, uid]


static func summary_id(wk: int, cls: StringName, cc: String = "") -> String:
	return "%d_%s" % [wk, cls] + ("_" + cc if not cc.is_empty() else "")


# --- Sıra ---------------------------------------------------------------------------

## Özette bu sürenin sırası: daha hızlı kovalardaki kayıtlar + 1 (aynı kovadakiler eşit sayılır). count: tablodaki kayıt
## (oyuncu henüz yoksa +1). pct: sıra / kayıt (0–1). Süre ≤ 0 ya da özet boşsa {}.
static func rank_in(summary: Dictionary, time: float, already_in: bool = true) -> Dictionary:
	if time <= 0.0:
		return {}
	var hist: Dictionary = summary.get("hist", {}) if summary.get("hist") is Dictionary else {}
	var mine: int = floori(time * BUCKETS_PER_SEC)
	var faster: int = 0
	for key: Variant in hist:
		if String(key).to_int() < mine:
			faster += maxi(SaveSafe.i(hist[key]), 0)
	var count: int = maxi(SaveSafe.i(summary.get("count", 0)), faster + 1)
	if not already_in:
		count += 1
	return {"rank": faster + 1, "count": count, "pct": float(faster + 1) / float(maxi(count, 1))}


## Bir üst ödül kademesine ne kadar kaldı: {tier: hedef kademe, gap: sn} (zaten İLK 3'teyse / süre yoksa {}). Hedef
## sıra R için R. kişiden hızlı olmak gerekir: R özetin `top` listesindeyse onun süresi kesin, değilse süre kovalarından
## (hist) bulunur: daha hızlı kovalardaki kayıt R − 1'i aşmayan en geç kovanın üst sınırı (kova çözünürlüğü 0,05 sn).
static func chase(summary: Dictionary, time: float, rank: int, count: int) -> Dictionary:
	if time <= 0.0 or rank <= 0 or count <= 0:
		return {}
	var target: StringName = &""
	var needed: int = 0
	match tier_of(rank, count):
		&"top3":
			return {}
		&"p10":
			target = &"top3"
			needed = 3
		&"p50":
			target = &"p10"
			needed = maxi(ceili(float(count) * 0.10), 3)
		_:
			target = &"p50"
			needed = maxi(ceili(float(count) * 0.50), 3)
	var top: Array = summary.get("top", []) if summary.get("top") is Array else []
	var goal: float = -1.0
	if needed <= top.size() and top[needed - 1] is Dictionary:
		goal = float((top[needed - 1] as Dictionary).get("time", -1.0))
	else:
		var hist: Dictionary = summary.get("hist", {}) if summary.get("hist") is Dictionary else {}
		var counts: Dictionary = {}   # kova → kayıt
		for key: Variant in hist:
			counts[String(key).to_int()] = maxi(SaveSafe.i(hist[key]), 0)
		var keys: Array = counts.keys()
		keys.sort()
		var faster: int = 0
		for key: Variant in keys:
			if faster > needed - 1:
				break
			goal = float(int(key) + 1) / BUCKETS_PER_SEC   # bu kovaya girmek R − 1'den fazlasının arkasında bırakmaz
			faster += int(counts[key])
	if goal <= 0.0 or goal >= time:
		return {}
	return {"tier": target, "gap": time - goal}


## Bu sıranın ödül kademesi (&"top3" / &"p10" / &"p50" / &"").
static func tier_of(rank: int, count: int) -> StringName:
	if rank <= 0 or count <= 0:
		return &""
	if rank <= 3:
		return &"top3"
	if rank <= ceili(float(count) * 0.10):
		return &"p10"
	if rank <= ceili(float(count) * 0.50):
		return &"p50"
	return &""


## Kademenin ödülü {gems, crate} (config/app.leaderboard.rewards; yoksa varsayılan).
static func reward_of(tier: StringName) -> Dictionary:
	var config: AppConfig = AppConfig.current()
	var rewards: Variant = config.config().get("leaderboard", {}).get("rewards", {}) \
		if config and config.config().get("leaderboard") is Dictionary else {}
	var raw: Variant = (rewards as Dictionary).get(String(tier)) if rewards is Dictionary else null
	var base: Dictionary = DEFAULT_REWARDS.get(tier, {})
	if not raw is Dictionary:
		return base
	var crate: StringName = StringName(SaveSafe.s((raw as Dictionary).get("crate", "")))
	return {"gems": clampi(SaveSafe.i((raw as Dictionary).get("gems", base.get("gems", 0))), 0, 1000),
		"crate": String(crate) if CrateCatalog.exists(crate) and not CrateCatalog.is_gift(crate) else ""}


# --- Okuma (oturumsuz REST) -----------------------------------------------------------

func summary(wk: int, cls: StringName, cc: String = "", max_age: float = FRESH_SEC) -> Dictionary:
	return await _fetch(SUMMARIES + "/" + summary_id(wk, cls, cc), max_age)


func run_of(wk: int, cls: StringName, uid: String, max_age: float = FRESH_SEC) -> Dictionary:
	return await _fetch(RUNS + "/" + doc_id(wk, cls, uid), max_age)


## ARKADAŞLAR listesi: arkadaşların (ve oyuncunun) bu haftaki kayıtları, süreye göre (top satırı biçiminde).
func friends_entries(wk: int, cls: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var social: SocialManager = get_tree().get_first_node_in_group("social") as SocialManager
	if social == null:
		return out
	var uids: Array[String] = []
	for friend: Dictionary in social.friends:
		uids.append(SaveSafe.s(friend.get("uid", "")))
	if not social.uid().is_empty():
		uids.append(social.uid())
	for uid: String in uids:
		if uid.is_empty():
			continue
		var entry: Dictionary = await run_of(wk, cls, uid)
		if not entry.is_empty() and float(entry.get("time", 0.0)) > 0.0:
			entry.erase("run")
			out.append(entry)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["time"]) < float(b["time"]))
	return out


## İZLE: tablodaki koşunun kaydı (indirilemezse / bozuksa null).
func recording_of(wk: int, cls: StringName, uid: String) -> DragRaceSim.Recording:
	var entry: Dictionary = await run_of(wk, cls, uid, 3600.0)
	var parsed: Variant = JSON.parse_string(SaveSafe.s(entry.get("run", "")))
	return DragRaceSim.Recording.from_dict(parsed) if parsed is Dictionary else null


## Bu cihazda bilinen en iyi sürem (yoksa -1).
func my_best(wk: int, cls: StringName) -> float:
	var entry: Variant = _best.get("%d_%s" % [wk, cls])
	return float((entry as Dictionary).get("t", -1.0)) if entry is Dictionary else -1.0


## En iyi sürenin aracı (yoksa &"").
func my_best_car(wk: int, cls: StringName) -> StringName:
	var entry: Variant = _best.get("%d_%s" % [wk, cls])
	return StringName(SaveSafe.s((entry as Dictionary).get("car", ""))) if entry is Dictionary else &""


## Testler / önbellek: belgenin içeriğini elle verir.
func inject(path: String, data: Dictionary) -> void:
	_cache[path] = {"at": _seconds(), "data": data}


func _fetch(path: String, max_age: float) -> Dictionary:
	var cached: Variant = _cache.get(path)
	if cached is Dictionary and (base_url.is_empty() or _seconds() - float(cached["at"]) < max_age):
		return cached["data"]
	if base_url.is_empty() or not is_inside_tree():
		return {}
	var http: HTTPRequest = HTTPRequest.new()
	http.timeout = TIMEOUT_SEC
	add_child(http)
	if http.request(base_url + path) != OK:
		http.queue_free()
		return cached["data"] if cached is Dictionary else {}
	var result: Array = await http.request_completed
	http.queue_free()
	var data: Dictionary = {}
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS or (int(result[1]) != 200 and int(result[1]) != 404):
		return cached["data"] if cached is Dictionary else {}   # ağ yok: eldeki kalır
	if int(result[1]) == 200:
		var parsed: Variant = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
		if parsed is Dictionary:
			var fields: Variant = (parsed as Dictionary).get("fields", {})
			data = AppConfig.decode_fields(fields if fields is Dictionary else {})
	_cache[path] = {"at": _seconds(), "data": data}
	return data


# --- Yazma ----------------------------------------------------------------------------------

## Yarış bitti (RaceManager.run_recorded): haftalık en iyiyse tabloya yazılır; sonuç `submitted` ile duyurulur.
func _on_run_recorded(recording: DragRaceSim.Recording) -> void:
	await submit(recording)


func submit(recording: DragRaceSim.Recording) -> Dictionary:
	if recording == null or recording.time <= 0.0:
		return {}
	var cls: StringName = class_of(recording.vehicle_id)
	if cls == &"":
		return {}
	var wk: int = current_week()
	var info: Dictionary = {"cls": cls, "wk": wk, "time": recording.time, "improved": false, "guest": false, "failed": false}
	var social: SocialManager = get_tree().get_first_node_in_group("social") as SocialManager
	if social == null or social.uid().is_empty() or not social.is_ready():
		info["guest"] = true
		submitted.emit(info)
		return info
	var key: String = "%d_%s" % [wk, cls]
	if not _best.has(key):   # bu cihazda ilk: sunucudaki kayıttan öğren (yeni cihaz / yeniden kurulum)
		var mine: Dictionary = await run_of(wk, cls, social.uid(), 0.0)
		if float(mine.get("time", 0.0)) > 0.0:
			_best[key] = {"t": float(mine["time"]), "car": SaveSafe.s(mine.get("car", ""))}
	var old: float = my_best(wk, cls)
	var table: Dictionary = await summary(wk, cls, "", 0.0)
	var old_rank: Dictionary = rank_in(table, old) if old > 0.0 else {}
	var improved: bool = old <= 0.0 or recording.time < old - 0.00005
	var best: float = recording.time if improved else old
	if improved:
		if await social.write_lb_run(doc_id(wk, cls, social.uid()), _doc(recording, cls, wk, social)):
			_best[key] = {"t": recording.time, "car": String(recording.vehicle_id)}
			_write()
			changed.emit()
		else:
			info["failed"] = true
			best = old
	var rank: Dictionary = rank_in(table, best, old > 0.0)
	info.merge({"improved": improved and not bool(info["failed"]), "best": best,
		"old_rank": int(old_rank.get("rank", 0)), "rank": int(rank.get("rank", 0)),
		"count": int(rank.get("count", 0)), "pct": float(rank.get("pct", 0.0))}, true)
	var next: Dictionary = chase(table, best, int(info["rank"]), int(info["count"]))
	info["next_tier"] = next.get("tier", &"")
	info["gap"] = float(next.get("gap", 0.0))
	submitted.emit(info)
	return info


func _doc(recording: DragRaceSim.Recording, cls: StringName, wk: int, social: SocialManager) -> Dictionary:
	var tree: SceneTree = get_tree()
	var profile: PlayerProfile = tree.get_first_node_in_group("player_profile") as PlayerProfile
	var progress: PlayerProgress = tree.get_first_node_in_group("player_progress") as PlayerProgress
	var ownership: VehicleOwnership = tree.get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	var paint: String = ""
	if ownership:
		var painted: Dictionary = ownership.paint_state()
		var hex: String = SaveSafe.s(painted.get(String(recording.vehicle_id), ""))
		paint = "#" + hex.to_upper() if hex.length() == 6 else ""
	var stage: int = 0
	for category: Variant in recording.build:
		stage = maxi(stage, SaveSafe.i(recording.build[category]))
	return {
		"uid": social.uid(), "wk": wk, "cls": String(cls), "time": snappedf(recording.time, 0.0001),
		"car": String(recording.vehicle_id), "paint": paint, "stage": clampi(stage, 0, PerformanceMods.STAGES),
		"level": clampi(progress.level if progress else 1, 1, 99), "name": social.my_name().left(NAME_MAX),
		"av": profile.my_av() if profile else "", "flag": profile.flag if profile else "",
		"run": JSON.stringify(recording.to_dict()), "at": now(),
	}


# --- Cihaz durumu ---------------------------------------------------------------------------

func _seconds() -> float:
	return Time.get_ticks_msec() / 1000.0


func _read() -> Dictionary:
	if not FileAccess.file_exists(FILE):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	var out: Dictionary = {}
	if parsed is Dictionary:
		var current: int = current_week()
		for key: Variant in parsed:
			var wk: int = String(key).get_slice("_", 0).to_int()
			if wk >= current - 1 and parsed[key] is Dictionary:   # eski haftalar atılır
				out[String(key)] = {"t": SaveSafe.f((parsed[key] as Dictionary).get("t", -1.0)),
					"car": SaveSafe.s((parsed[key] as Dictionary).get("car", ""))}
	return out


func _write() -> void:
	var file: FileAccess = FileAccess.open(FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_best))
