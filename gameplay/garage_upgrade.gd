class_name GarageUpgrade
extends Resource
## Bir garaj geliştirmesinin TANIMI ve o anki seviyesi — yalnızca VERİ.
## Satın alma mantığı GarageUpgradeManager'da, para EconomyManager'da.
##
## Seviye 1'den başlar. `costs[i]` = (i+1) → (i+2) seviyesine yükseltme ücretidir; dolayısıyla
## max_level = costs.size() + 1. `effects[i]` = (i+1). seviyedeki oyun etkisidir:
##   repair_speed → süre çarpanı (1.0, 0.9, 0.8, 0.7, 0.6)
##   garage_level → garajın FİZİKSEL seviyesi (1..4). Zemin/duvar boyutunu GarageSystem büyütür ve
##                  her seviye bir sonraki TAMİR ALANINI ortaya çıkarır — ama alanı açmaz:
##                  alanın kendi ücreti RepairBayManager'da ödenir (iki ayrı satın alma).
## NOT: eski "repair_capacity" geliştirmesi kaldırıldı; kapasite artık satın alınmış alan sayısıdır
## (GarageUpgradeManager.repair_capacity() bunu RepairBayManager'dan okur).
## Katalog tek yerde: defaults(). Maliyet/etki değiştirmek için orası yeter.

@export var id: StringName = &"repair_speed"
@export var display_name: String = "TAMİR HIZI"
## Plaka ikonu (HudIcon.Kind adı).
@export var icon: StringName = &"WRENCH"
## Kısa açıklama (garaj plakasının alt satırı).
@export var description: String = ""
@export_range(1, 20) var current_level: int = 1
## Sıradaki seviyelerin ücretleri (₺): costs[0] = Lv1 → Lv2.
@export var costs: PackedInt32Array = PackedInt32Array()
## Her seviyenin oyun etkisi (effects[0] = Lv1).
@export var effects: PackedFloat32Array = PackedFloat32Array()


var max_level: int:
	get: return costs.size() + 1


func is_max() -> bool:
	return current_level >= max_level


## Bir sonraki seviyenin ücreti (maksimumdaysa 0).
func next_cost() -> int:
	return 0 if is_max() else costs[current_level - 1]


## Şu anki seviyenin oyun etkisi (tanımsızsa 1.0).
func value() -> float:
	if effects.is_empty():
		return 1.0
	return effects[clampi(current_level - 1, 0, effects.size() - 1)]


## Verilen seviyenin etkisi (UI'da "sonraki seviye" göstermek için).
func value_at(level: int) -> float:
	if effects.is_empty():
		return 1.0
	return effects[clampi(level - 1, 0, effects.size() - 1)]


## GELİŞTİRME KATALOĞU — ilk sürümde iki geliştirme.
static func defaults() -> Array[GarageUpgrade]:
	return [
		_make(&"repair_speed", "TAMİR HIZI", &"WRENCH", "Tamir süresi",
			PackedInt32Array([1000, 2000, 3500, 5000]), PackedFloat32Array([1.0, 0.9, 0.8, 0.7, 0.6])),
		_make(&"garage_level", "GARAJ SEVİYESİ", &"GARAGE", "Garaj alanı",
			PackedInt32Array([36000, 90000, 180000]), PackedFloat32Array([1.0, 2.0, 3.0, 4.0])),
	]


static func _make(p_id: StringName, p_name: String, p_icon: StringName, p_desc: String,
		p_costs: PackedInt32Array, p_effects: PackedFloat32Array) -> GarageUpgrade:
	var u: GarageUpgrade = GarageUpgrade.new()
	u.id = p_id
	u.display_name = p_name
	u.icon = p_icon
	u.description = p_desc
	u.costs = p_costs
	u.effects = p_effects
	u.current_level = 1
	return u
