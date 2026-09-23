class_name GarageUpgradeManager
extends Node
## Garaj geliştirmeleri (TAMİR HIZI / TAMİR ALANI): seviyeler burada tutulur, satın alma burada yapılır.
## Sahnede World/Gameplay/GarageUpgradeManager olarak durur; arayanlar "garage_upgrades" grubundan bulur
## (autoload yok — proje kuralı).
##
## Para: yalnızca EconomyManager. Satın alma yetersiz bakiyede HİÇBİR ŞEYİ değiştirmez (para da seviye de).
## Oyun etkileri veri odaklıdır (GarageUpgrade.effects):
##   repair_speed_multiplier() → RepairManager tamir süresini bununla çarpar (RepairType.duration sabit kalır)
##   repair_capacity()         → RepairManager aynı anda kaç CarSpot kullanacağını buradan öğrenir
## Kayıt sistemi geldiğinde yazılacak/okunacak tek şey seviyelerdir (levels()/apply_levels()).

## Bir geliştirme satın alındı (yeni seviyesiyle).
signal upgrade_purchased(id: StringName, level: int)
## Satın alma başarısız (yetersiz bakiye ya da maksimum seviye).
signal purchase_failed(id: StringName, cost: int)

const SPEED_ID: StringName = &"repair_speed"
const CAPACITY_ID: StringName = &"repair_capacity"

## Geliştirme kataloğu; boşsa GarageUpgrade.defaults().
@export var upgrades: Array[GarageUpgrade] = []

var _by_id: Dictionary = {}


func _ready() -> void:
	add_to_group("garage_upgrades")
	if upgrades.is_empty():
		upgrades = GarageUpgrade.defaults()
	else:
		# Sahnede verilen kaynaklar paylaşılmasın: her oyun kendi kopyasıyla ilerlesin
		var copies: Array[GarageUpgrade] = []
		for u: GarageUpgrade in upgrades:
			copies.append(u.duplicate())
		upgrades = copies
	for u: GarageUpgrade in upgrades:
		_by_id[u.id] = u


# --- Sorgu ---------------------------------------------------------------------

func get_upgrade(id: StringName) -> GarageUpgrade:
	return _by_id.get(id)


func level(id: StringName) -> int:
	var u: GarageUpgrade = get_upgrade(id)
	return u.current_level if u else 1


func max_level(id: StringName) -> int:
	var u: GarageUpgrade = get_upgrade(id)
	return u.max_level if u else 1


## Sıradaki seviyenin ücreti (maksimumdaysa 0).
func next_cost(id: StringName) -> int:
	var u: GarageUpgrade = get_upgrade(id)
	return u.next_cost() if u else 0


func is_max(id: StringName) -> bool:
	var u: GarageUpgrade = get_upgrade(id)
	return u == null or u.is_max()


## Satın alınabilir mi: maksimum değil ve bakiye yetiyor.
func can_buy(id: StringName) -> bool:
	var u: GarageUpgrade = get_upgrade(id)
	if u == null or u.is_max():
		return false
	var economy: EconomyManager = _economy()
	return economy == null or economy.can_afford(u.next_cost())


## Satın alma: bakiye yeterliyse ücret düşer, seviye artar ve upgrade_purchased yayılır (true).
## Yetersiz bakiye / maksimum seviyede hiçbir şey değişmez (false).
func buy(id: StringName) -> bool:
	var u: GarageUpgrade = get_upgrade(id)
	if u == null or u.is_max():
		if u:
			purchase_failed.emit(id, 0)
		return false
	var cost: int = u.next_cost()
	var economy: EconomyManager = _economy()
	if economy and not economy.spend_money(cost):
		purchase_failed.emit(id, cost)
		return false
	u.current_level += 1
	upgrade_purchased.emit(id, u.current_level)
	return true


# --- Oyun etkileri ---------------------------------------------------------------

## Tamir süresi çarpanı: Lv1 1.0, Lv2 0.9, Lv3 0.8, Lv4 0.7, Lv5 0.6.
func repair_speed_multiplier() -> float:
	var u: GarageUpgrade = get_upgrade(SPEED_ID)
	return u.value() if u else 1.0


## Aynı anda tamir edilebilen araç sayısı (kullanılabilir CarSpot sayısıyla sınırlanır).
func repair_capacity() -> int:
	var u: GarageUpgrade = get_upgrade(CAPACITY_ID)
	return maxi(int(round(u.value())), 1) if u else 1


# --- Kayıt (ileride) --------------------------------------------------------------

## id → seviye (kayıt için).
func levels() -> Dictionary:
	var out: Dictionary = {}
	for u: GarageUpgrade in upgrades:
		out[u.id] = u.current_level
	return out


## Kayıttan seviyeleri uygular (geçersiz değer seviye 1'e çekilir; UI çağıran tarafından tazelenir).
func apply_levels(data: Dictionary) -> void:
	for u: GarageUpgrade in upgrades:
		if not data.has(u.id):
			continue
		var value: int = int(data[u.id])
		u.current_level = clampi(value, 1, u.max_level) if value >= 1 and value <= u.max_level else 1


## Yeni oyun: tüm geliştirmeler 1. seviyeye döner.
func reset() -> void:
	for u: GarageUpgrade in upgrades:
		u.current_level = 1


func _economy() -> EconomyManager:
	return get_tree().get_first_node_in_group("economy") as EconomyManager
