class_name JobMastery
extends Node
## İŞ USTALIĞI — her arıza türü için ayrı ayrı "kaç kez yaptın" sayacı ve 5 yıldızlık kademe.
## Car Town'ın Job Mastery prensibi: aynı işi tekrar tekrar yapmak zamanla daha çok XP getirsin ve
## her kademede tek seferlik bir ödül düşsün. Böylece 4 arızanın tekrarı anlamlı bir hedefe bağlanır.
##
## Sahnede World/Gameplay/JobMastery olarak durur; arayanlar "job_mastery" grubundan bulur
## (autoload yok — proje kuralı). Kare başına iş yapmaz.
##
## AKIŞ: iş BAŞLARKEN reward_multiplier(id) ödül çarpanına girer; iş TOPLANIRKEN xp_multiplier(id)
## ile XP çarpılır ve record(id) sayacı artırır. Kademe atlanınca tek seferlik ₺ ödülü
## EconomyManager'dan verilir ve mastery_up yayılır.
##
## KAYIT: yalnızca sayaçlar saklanır ({arıza id → sayı}), yıldızlar/bonuslar hep sayaçtan TÜRETİLİR.
## Bu yüzden eşik tablosu değiştiğinde kayıt şeması değişmez ve v7 kayıtlar olduğu gibi çalışır
## (yeni eşiklerle yıldızlar yeniden hesaplanır; geçmişe dönük kademe ödemesi YAPILMAZ).

## Bir arıza türü yıldız atladı.
signal mastery_up(job_id: StringName, stars: int)
## Sayaç değişti (UI tazelemesi için).
signal mastery_changed(job_id: StringName, count: int)

## TEMEL yıldız eşikleri (kısa işler için): 1★ 10 iş, 2★ 40, 3★ 120, 4★ 300, 5★ 750.
const BASE_THRESHOLDS: Array[int] = [10, 40, 120, 300, 750]
## TEK SEFERLİK ödül = arızanın ödülü × bu çarpan × arızanın ağırlığı.
## (İlk kademede ~10 işlik kazancın %80'i kadar; üst kademelerde pay düşer: 80 → 60 → 50 → 47 → 40.)
const STAR_PAYOUT: Array[float] = [8.0, 18.0, 40.0, 85.0, 180.0]
## Yıldız başına XP bonusu (%10): 5 yıldızda +%50.
const XP_BONUS_PER_STAR: float = 0.10
## Yıldız başına KALICI ödül bonusu (%2): 5 yıldızda +%10. Küçük tutuldu — ekonomiyi bozmadan
## "bu işi artık daha iyi yapıyorum" hissini versin diye (0-10 saatlik projeksiyonda +%3,4 gelir).
const REWARD_BONUS_PER_STAR: float = 0.02

var _counts: Dictionary = {}   # arıza id → tamamlanan iş sayısı
var _types: Dictionary = {}    # arıza id → RepairType (eşik hesabı için, tembel önbellek)


func _ready() -> void:
	add_to_group("job_mastery")


# --- Sorgu ---------------------------------------------------------------------

func count(job_id: StringName) -> int:
	return int(_counts.get(job_id, 0))


## BU ARIZANIN yıldız eşikleri. Eşikler arızanın SIKLIĞINA (RepairType.weight) göre ölçeklenir:
## bütün arızalarda bir yıldız KABACA AYNI OYUN SÜRESİNİ alsın diye. Ölçülen akışta (garaj 3, 3 alan)
## saatte ~35 kısa iş, ~28 boya, ~21 döşeme, ~17 revizyon geliyor; ağırlıkla ölçeklenen eşikler
## hepsinde 1. yıldızı ~18 dakikaya getirir. Ayrı bir alan eklenmedi: ağırlık zaten sıklığın kendisi.
func thresholds(job_id: StringName) -> Array[int]:
	var scale: float = weight_of(job_id)
	var out: Array[int] = []
	for base: int in BASE_THRESHOLDS:
		out.append(maxi(int(round(float(base) * scale)), 1))
	return out


## 0–5 arası yıldız.
func stars(job_id: StringName) -> int:
	var done: int = count(job_id)
	var result: int = 0
	for threshold: int in thresholds(job_id):
		if done >= threshold:
			result += 1
	return result


## Sıradaki yıldız için gereken iş sayısı (5 yıldızdaysa 0).
func next_threshold(job_id: StringName) -> int:
	var current: int = stars(job_id)
	var list: Array[int] = thresholds(job_id)
	return 0 if current >= list.size() else list[current]


## Bu arızanın kademe ödülü (₺): arızanın ödülü × kademe çarpanı × sıklık ağırlığı.
func star_payout(job_id: StringName, star: int) -> int:
	var type: RepairType = type_of(job_id)
	if type == null or star < 1:
		return 0
	var mult: float = STAR_PAYOUT[clampi(star - 1, 0, STAR_PAYOUT.size() - 1)]
	return int(round(float(type.reward) * mult * weight_of(job_id)))


## Kalıcı ödül çarpanı (1.0 … 1.10).
func reward_multiplier(job_id: StringName) -> float:
	return 1.0 + REWARD_BONUS_PER_STAR * float(stars(job_id))


## 5 yıldıza ulaşmış arızalar (fiziksel "usta" işaretleri bunlara bakacak).
func mastered_jobs() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in _counts:
		if stars(id) >= BASE_THRESHOLDS.size():
			out.append(id)
	return out


## Arızanın kataloğu (sahnedeki RepairManager, yoksa varsayılan katalog).
func type_of(job_id: StringName) -> RepairType:
	if _types.is_empty():
		var repairs: RepairManager = get_tree().get_first_node_in_group("repair_manager") as RepairManager
		var list: Array[RepairType] = repairs.repair_types if repairs and not repairs.repair_types.is_empty() else RepairType.defaults()
		for type: RepairType in list:
			_types[type.id] = type
	return _types.get(job_id, null)


func weight_of(job_id: StringName) -> float:
	var type: RepairType = type_of(job_id)
	return maxf(type.weight, 0.05) if type else 1.0


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
			economy.add_money(star_payout(job_id, after))
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
		_counts[StringName(key)] = maxi(SaveSafe.i(data[key]), 0)


func reset() -> void:
	_counts.clear()


func _request_save() -> void:
	var save: Node = get_tree().get_first_node_in_group("save_manager")
	if save and save.has_method(&"request_save"):
		save.request_save()
