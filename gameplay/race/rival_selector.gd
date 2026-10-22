class_name RivalSelector
extends RefCounted
## KOŞU SEÇİCİ (docs/KOSU_ESLESTIRME.md): rakibin HANGİ koşusunun geleceğini oyuncunun kazanma şansına göre seçer.
## Koşular gerçektir — arkadaşın kendi koşusu ya da yapay zekânın aynı fizikle koşusu (RivalPool); ayarlanan yalnızca
## seçimdir. Rakip ARAÇ oyuncununkiyle aynı olmak zorunda değil (RaceManager.rival_window); karşılaştırılan SÜRELERDİR:
## oyuncunun kendi aracıyla tipik süresi ile rakip koşunun süresi.
##
## KAZANMA ŞANSI: oyuncunun süre örnekleri (samples_for) üzerinde yumuşatılmış "kaç koşumda bu süreyi geçerdim" oranı.
## Örnekler: aynı araç + aynı modifiyeyle en az MIN_SAMPLES koşu varsa doğrudan onların süreleri; yoksa öbür koşuların
## kusursuz süreye ORANI bu aracın kusursuz süresine uygulanır (araç değişse, modifiye gelse de beceri taşınır); hiç koşu
## yoksa yeni oyuncu varsayımı (PRIOR_RATIOS).
##
## ZORLUK KOLU — başlangıç kuralı (kullanıcı kararı): yarışların çoğu DENGELİ, ~üçte biri KOLAY, ara sıra ZOR; üst üste
## iki kayıptan sonra KOLAY (seri kırıcı); üç ZOR üst üste gelmez. Faz 2'de öğrenen sistem ağırlıkları oyuncuya göre
## kaydırır, korkuluklar kalır.

enum Arm { EASY, EVEN, HARD }

## Kolun hedeflediği kazanma şansı.
const TARGET: Dictionary = {Arm.EASY: 0.75, Arm.EVEN: 0.5, Arm.HARD: 0.30}
## Başlangıç kuralının ağırlıkları (toplam 1): ZOR en çok %25 korkuluğunun çok altında.
const START_WEIGHTS: Dictionary = {Arm.EVEN: 0.55, Arm.EASY: 0.33, Arm.HARD: 0.12}
## Koşu hedefe bu kadar yakınsa "tutar". Arkadaşın tutan koşusu yoksa yine arkadaş gelir, koşularından hedefe en yakını
## (kullanıcı kararı: arkadaş oranı korunur, şans hedeften sapabilir); yalnız seri kırıcıda tutmayan arkadaş gelmez.
## Yapay zekâ rakibinin aracı tutan havuzlardan seçilir.
const TOLERANCE: float = 0.15
const MIN_SAMPLES: int = 5
const MAX_SAMPLES: int = 20
## Yumuşatma bandı (sn): en az BANDWIDTH_MIN, örneklerin sapmasıyla genişler (az koşuda keskin 0 / 1 çıkmasın).
const BANDWIDTH_MIN: float = 0.04
const BANDWIDTH_SPREAD: float = 0.35
## Hiç koşusu olmayan oyuncu: süre / aracın kusursuz süresi (tepki dahil; acemi, kalkışı ve vitesleri kaçırır).
const PRIOR_RATIOS: Array[float] = [1.02, 1.03, 1.04, 1.05, 1.07, 1.10]


## Sıradaki yarışın kolu. `history`: son yarışlar, en yenisi sonda ({"w": kazandı mı, "a": kol}).
static func choose_arm(history: Array, rng: RandomNumberGenerator) -> int:
	var n: int = history.size()
	if streak_breaker(history):
		return Arm.EASY
	var roll: float = rng.randf()
	var arm: int = Arm.EVEN
	var total: float = 0.0
	for candidate: int in [Arm.EVEN, Arm.EASY, Arm.HARD]:
		total += float(START_WEIGHTS[candidate])
		if roll < total:
			arm = candidate
			break
	if arm == Arm.HARD and n >= 2 and _arm_of(history[n - 1]) == Arm.HARD and _arm_of(history[n - 2]) == Arm.HARD:
		arm = Arm.EVEN
	return arm


## Seri kırıcı: son iki yarış kaybedildi → sıradaki KOLAY olmalı (arkadaşın kolay koşusu yoksa yapay zekâ gelir).
static func streak_breaker(history: Array) -> bool:
	var n: int = history.size()
	return n >= 2 and not _won(history[n - 1]) and not _won(history[n - 2])


static func target_of(arm: int) -> float:
	return float(TARGET.get(arm, TARGET[Arm.EVEN]))


## Oyuncunun bu rakip süresini geçme olasılığı (0-1; eşitlik oyuncunundur).
static func win_chance(samples: PackedFloat64Array, rival_time: float) -> float:
	if samples.is_empty():
		return 0.5
	var mean: float = 0.0
	for x: float in samples:
		mean += x
	mean /= float(samples.size())
	var spread: float = 0.0
	for x: float in samples:
		spread += (x - mean) * (x - mean)
	var band: float = maxf(BANDWIDTH_MIN, BANDWIDTH_SPREAD * sqrt(spread / float(samples.size())))
	var sum: float = 0.0
	for x: float in samples:
		sum += 1.0 / (1.0 + exp(-1.702 * (rival_time - x) / band))   # normal dağılımın lojistik yaklaşığı
	return sum / float(samples.size())


## Hedef şansa en yakın sürenin sırası (-1: liste boş).
static func closest(times: PackedFloat64Array, samples: PackedFloat64Array, target: float) -> int:
	var best: int = -1
	var best_gap: float = INF
	for i: int in times.size():
		var gap: float = absf(win_chance(samples, times[i]) - target)
		if gap < best_gap:
			best_gap = gap
			best = i
	return best


static func fits(chance: float, target: float) -> bool:
	return absf(chance - target) <= TOLERANCE


## Oyuncunun `player_id` + `build` ile süre örnekleri (sn). `runs`: araç id (String) → koşu sözlükleri (eskiden yeniye,
## DragRaceSim.Recording.to_dict biçimi; RaceManager saklar).
static func samples_for(player_id: StringName, build: Dictionary, runs: Dictionary) -> PackedFloat64Array:
	var key: String = PerformanceMods.build_key(PerformanceMods.normalized(build))
	var own: PackedFloat64Array = PackedFloat64Array()
	var others: Array[Dictionary] = []   # {at, ratio}
	for car: Variant in runs:
		var id: StringName = StringName(SaveSafe.s(car))
		var list: Variant = runs[car]
		if not list is Array:
			continue
		for raw: Variant in list:
			if not raw is Dictionary:
				continue
			var time: float = SaveSafe.f((raw as Dictionary).get("t", -1.0))
			if time <= 0.0:
				continue
			var mods: Dictionary = PerformanceMods.normalized((raw as Dictionary).get("b", {}) \
				if (raw as Dictionary).get("b") is Dictionary else {})
			if id == player_id and PerformanceMods.build_key(mods) == key:
				own.append(time)
				continue
			var perfect: float = perfect_time(id, mods)
			if perfect > 0.0:
				others.append({"at": SaveSafe.i((raw as Dictionary).get("at", 0)), "ratio": time / perfect})
	if own.size() > MAX_SAMPLES:
		own = own.slice(own.size() - MAX_SAMPLES)
	if own.size() >= MIN_SAMPLES:
		return own
	var mine: float = perfect_time(player_id, build)
	others.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["at"]) > int(b["at"]))
	var out: PackedFloat64Array = own
	for entry: Dictionary in others:
		if out.size() >= MAX_SAMPLES:
			break
		out.append(float(entry["ratio"]) * mine)
	var i: int = 0
	while out.size() < MIN_SAMPLES:
		out.append(PRIOR_RATIOS[i % PRIOR_RATIOS.size()] * mine)
		i += 1
	return out


## Aracın bu modifiyelerle kusursuz 300 m süresi (sn; tepkisiz).
static func perfect_time(vehicle_id: StringName, build: Dictionary) -> float:
	return float(PerformanceMods.measure(vehicle_id, build)["t300"])


static func _won(entry: Variant) -> bool:
	return entry is Dictionary and bool((entry as Dictionary).get("w", false))


static func _arm_of(entry: Variant) -> int:
	return SaveSafe.i((entry as Dictionary).get("a", -1)) if entry is Dictionary else -1
