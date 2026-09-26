class_name GarageValue
## GARAJ DEĞERİ — oyuncunun garajına yaptığı toplam yatırımın ₺ karşılığı ve 10 basamaklı rütbesi.
## Car Town'ın "Garage Value" prensibi: XP'den ve paradan BAĞIMSIZ, uzun vadeli prestij ekseni.
##
## TÜRETİLMİŞ DEĞERDİR: hiçbir yerde saklanmaz, kayda yazılmaz, sinyali yoktur — her sorulduğunda
## mevcut manager'lardan hesaplanır (deterministik). Bu yüzden Node değil, statik yardımcıdır:
## sahneye node eklemez, save şemasını büyütmez, iki kaynak arasında tutarsızlık doğmaz.
##
## Değer = sahip olunan araçların katalog fiyatı + garaj geliştirmelerine ödenen + açılan tamir
## alanlarına ödenen + boyanan araç başına sabit katkı (+ ileride dekor eşyaları).
## Rütbe pahalı araçları kilitler (CarCatalog "min_garage_rank"), böylece "önce koleksiyonunu
## büyüt, sonra pahalı aracı al" hedefi doğar.

## Rütbe eşikleri (₺). 8. rütbe "her şeye sahip olmak" seviyesidir; 9–10 ileride gelecek
## dekor / ustalık plakaları için ayrılmıştır (bkz. docs/GDD.md).
const THRESHOLDS: Array[int] = [
	0,        # 1
	110000,   # 2
	150000,   # 3
	200000,   # 4
	260000,   # 5
	320000,   # 6
	380000,   # 7
	440000,   # 8
	550000,   # 9
	700000,   # 10
]

const RANK_NAMES: Array[String] = [
	"DERME ÇATMA GARAJ",
	"VASAT GARAJ",
	"MÜTEVAZI GARAJ",
	"GÖZE ÇARPAN GARAJ",
	"İYİ GARAJ",
	"ETKİLEYİCİ GARAJ",
	"SAYGIN GARAJ",
	"HARİKA GARAJ",
	"GÖZ KORKUTAN GARAJ",
	"EFSANE GARAJ",
]

## Boyanan her aracın garaj değerine katkısı (boya bedeli gemle ödendiği için sabit karşılık).
const PAINT_VALUE: int = 2000


## Garajın toplam değeri (₺).
static func compute(tree: SceneTree) -> int:
	return vehicles_value(tree) + upgrades_value(tree) + bays_value(tree) + paint_value(tree)


## Sahip olunan araçların katalog fiyatı toplamı.
static func vehicles_value(tree: SceneTree) -> int:
	var ownership: VehicleOwnership = tree.get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	if ownership == null:
		return 0
	var total: int = 0
	for id: StringName in ownership.owned_vehicle_ids():
		total += int(CarCatalog.get_entry(id).get("price", 0))
	return total


## Garaj geliştirmelerine bugüne kadar ödenen toplam (mevcut seviyeye kadarki ücretlerin toplamı).
static func upgrades_value(tree: SceneTree) -> int:
	var upgrades: GarageUpgradeManager = tree.get_first_node_in_group("garage_upgrades") as GarageUpgradeManager
	if upgrades == null:
		return 0
	var total: int = 0
	for upgrade: GarageUpgrade in upgrades.upgrades:
		for i: int in mini(upgrade.current_level - 1, upgrade.costs.size()):
			total += upgrade.costs[i]
	return total


## Açılan tamir alanlarına ödenen toplam.
static func bays_value(tree: SceneTree) -> int:
	var bays: RepairBayManager = tree.get_first_node_in_group("repair_bays") as RepairBayManager
	if bays == null:
		return 0
	var total: int = 0
	for i: int in bays.unlocked_count():
		total += bays.price(i)
	return total


## Boyanmış araç başına sabit katkı (özelleştirme de garajın değerine yazılır).
static func paint_value(tree: SceneTree) -> int:
	var ownership: VehicleOwnership = tree.get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	return ownership.paint_state().size() * PAINT_VALUE if ownership else 0


## 1–10 arası rütbe.
static func rank(value: int) -> int:
	var result: int = 1
	for i: int in THRESHOLDS.size():
		if value >= THRESHOLDS[i]:
			result = i + 1
	return result


static func rank_name(rank_index: int) -> String:
	return RANK_NAMES[clampi(rank_index - 1, 0, RANK_NAMES.size() - 1)]


## Bir sonraki rütbe için gereken değer (en üst rütbedeyse 0).
static func next_threshold(value: int) -> int:
	var current: int = rank(value)
	return 0 if current >= THRESHOLDS.size() else THRESHOLDS[current]


## Mevcut rütbe içindeki ilerleme (0–1; en üst rütbede 1).
static func rank_ratio(value: int) -> float:
	var current: int = rank(value)
	if current >= THRESHOLDS.size():
		return 1.0
	var low: int = THRESHOLDS[current - 1]
	var high: int = THRESHOLDS[current]
	return clampf(float(value - low) / float(maxi(high - low, 1)), 0.0, 1.0)


## Sahnedeki güncel değerin rütbesi (kısayol).
static func current_rank(tree: SceneTree) -> int:
	return rank(compute(tree))
