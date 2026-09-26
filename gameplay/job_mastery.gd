class_name JobMastery
extends Node
## İŞ USTALIĞI — her arıza türü için ayrı ayrı "kaç kez yaptın" sayacı ve 5 yıldızlık kademe.
## Car Town'ın Job Mastery prensibi: aynı işi tekrar tekrar yapmak zamanla daha çok XP getirsin ve
## her kademede tek seferlik bir ödül düşsün. Böylece 4 arızanın tekrarı anlamlı bir hedefe bağlanır.
##
## Sahnede World/Gameplay/JobMastery olarak durur; arayanlar "job_mastery" grubundan bulur
## (autoload yok — proje kuralı). Kare başına iş yapmaz.
##
## AKIŞ: RepairManager.collect() → xp_multiplier(id) ile XP çarpılır → record(id) sayacı artırır.
## Kademe atlanınca tek seferlik ₺ ödülü EconomyManager'dan verilir ve mastery_up yayılır.
## Kalıcılık SaveManager'ındır (state / load_state / reset).

## Bir arıza türü yıldız atladı.
signal mastery_up(job_id: StringName, stars: int)
## Sayaç değişti (UI tazelemesi için).
signal mastery_changed(job_id: StringName, count: int)

## Yıldız eşikleri: 1★ 10 iş, 2★ 50, 3★ 150, 4★ 400, 5★ 1000.
const STAR_THRESHOLDS: Array[int] = [10, 50, 150, 400, 1000]
## Kademe başına TEK SEFERLİK ₺ ödülü.
const STAR_REWARDS: Array[int] = [1000, 3000, 8000, 20000, 50000]
## Yıldız başına XP bonusu (%10): 5 yıldızda +%50.
const XP_BONUS_PER_STAR: float = 0.10

var _counts: Dictionary = {}   # arıza id → tamamlanan iş sayısı


func _ready() -> void:
	add_to_group("job_mastery")


# --- Sorgu ---------------------------------------------------------------------

func count(job_id: StringName) -> int:
	return int(_counts.get(job_id, 0))


## 0–5 arası yıldız.
func stars(job_id: StringName) -> int:
	var done: int = count(job_id)
	var result: int = 0
	for threshold: int in STAR_THRESHOLDS:
		if done >= threshold:
			result += 1
	return result


## Sıradaki yıldız için gereken iş sayısı (5 yıldızdaysa 0).
func next_threshold(job_id: StringName) -> int:
	var current: int = stars(job_id)
	return 0 if current >= STAR_THRESHOLDS.size() else STAR_THRESHOLDS[current]


## Bu arızadan kazanılan XP çarpanı (1.0 … 1.5).
func xp_multiplier(job_id: StringName) -> float:
	return 1.0 + XP_BONUS_PER_STAR * float(stars(job_id))


## Tüm arızalarda toplanan yıldız (uzun vadeli hedef göstergesi).
func total_stars() -> int:
	var total: int = 0
	for id: StringName in _counts:
		total += stars(id)
	return total


# --- Kayıt akışı ----------------------------------------------------------------

## Bir iş tamamlandı: sayacı artırır, yıldız atlandıysa tek seferlik ödülü verir.
func record(job_id: StringName) -> void:
	if job_id == &"":
		return
	var before: int = stars(job_id)
	_counts[job_id] = count(job_id) + 1
	var after: int = stars(job_id)
	mastery_changed.emit(job_id, count(job_id))
	if after > before:
		var economy: EconomyManager = get_tree().get_first_node_in_group("economy") as EconomyManager
		if economy:
			economy.add_money(STAR_REWARDS[mini(after - 1, STAR_REWARDS.size() - 1)])
		mastery_up.emit(job_id, after)
	_request_save()


# --- Kalıcılık ------------------------------------------------------------------

## Kayda yazılacak: {arıza id → sayaç}.
func state() -> Dictionary:
	var out: Dictionary = {}
	for id: StringName in _counts:
		out[String(id)] = int(_counts[id])
	return out


func load_state(data: Dictionary) -> void:
	_counts.clear()
	for key: String in data:
		_counts[StringName(key)] = maxi(int(data[key]), 0)


func reset() -> void:
	_counts.clear()


func _request_save() -> void:
	var save: Node = get_tree().get_first_node_in_group("save_manager")
	if save and save.has_method(&"request_save"):
		save.request_save()
