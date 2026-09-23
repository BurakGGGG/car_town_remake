class_name RepairType
extends Resource
## Bir ARIZA TÜRÜ tanımı — yalnızca VERİ (araç modelinin değil, müşteri olayının özelliği).
## Mantık RepairManager'da, tek bir işin anlık durumu RepairState'te, aracın o anki arızası
## TrafficVehicle.fault'ta tutulur.
## ARIZA KATALOĞU TEK YERDEDİR: defaults(). Süre/ödül/XP değerlerini oradan (ya da sahnede
## RepairManager.repair_types dizisinden) değiştir; başka hiçbir yerde sabit yoktur.
##   MOTOR   10 sn  +150 ₺      FREN    8 sn  +140 ₺
##   LASTİK   6 sn  +100 ₺      KAPORTA 12 sn +200 ₺
## cost/min_level alanları ileriki ekonomi/seviye sistemi için durur; ilk sürümde tümü 0 / 1.

@export var id: StringName = &"engine"
## Plakada görünen ad.
@export var title: String = "MOTOR ARIZASI"
## Tamir süresi (sn).
@export_range(0.5, 600.0, 0.5) var duration: float = 10.0
## Tamamlanınca verilen para.
@export_range(0, 100000) var reward: int = 250
## Tamamlanınca verilen XP.
@export_range(0, 10000) var xp: int = 10
## İşe başlarken ödenen maliyet (coin).
@export_range(0, 100000) var cost: int = 100
## İşin açıldığı oyuncu seviyesi.
@export_range(1, 99) var min_level: int = 1
## Plaka ikonu (HudIcon.Kind adı: WRENCH, CAR, ROTATE, ...).
@export var icon: StringName = &"WRENCH"
## Küçük seçim plakası başlığı; boşsa title'ın ilk kelimesi.
@export var short: String = ""
## Müşteri arızası seçiminde ağırlık (0 = müşteri olarak gelmez).
@export_range(0.0, 10.0, 0.1) var weight: float = 1.0
## Arıza şiddeti aralığı: müşteri oluşurken bu aralıkta bir değer çekilir (RepairState.severity).
## İlk sürümde süreyi/ödülü ETKİLEMEZ; upgrade/ekonomi sistemi geldiğinde çarpan olarak kullanılacak.
@export_range(0.1, 3.0, 0.05) var severity_min: float = 0.8
@export_range(0.1, 3.0, 0.05) var severity_max: float = 1.2


## Kısa plaka başlığı: short doluysa o, yoksa title'ın ilk kelimesi ("MOTOR ARIZASI" → "MOTOR").
func short_title() -> String:
	return short if short != "" else title.split(" ")[0]


## ARIZA KATALOĞU — 4 tür. Süre (sn), ödül (₺) ve XP burada tanımlıdır.
static func defaults() -> Array[RepairType]:
	return [
		_make(&"engine", "MOTOR ARIZASI", 10.0, 0, 150, 10, 1, &"WRENCH", 1.0, "MOTOR"),
		_make(&"brakes", "FREN ARIZASI", 8.0, 0, 140, 9, 1, &"WRENCH", 1.0, "FREN"),
		_make(&"tires", "LASTİK ARIZASI", 6.0, 0, 100, 7, 1, &"ROTATE", 1.0, "LASTİK"),
		_make(&"body", "KAPORTA HASARI", 12.0, 0, 200, 14, 1, &"CAR", 1.0, "KAPORTA"),
	]


## Katalogdan id ile arıza (yoksa null).
static func by_id(id: StringName) -> RepairType:
	for t: RepairType in defaults():
		if t.id == id:
			return t
	return null


## Geriye dönük: ilk (motor) iş.
static func engine() -> RepairType:
	return defaults()[0]


static func _make(p_id: StringName, p_title: String, p_duration: float, p_cost: int, p_reward: int, p_xp: int, p_level: int, p_icon: StringName, p_weight: float, p_short: String = "") -> RepairType:
	var t: RepairType = RepairType.new()
	t.short = p_short
	t.id = p_id
	t.title = p_title
	t.duration = p_duration
	t.cost = p_cost
	t.reward = p_reward
	t.xp = p_xp
	t.min_level = p_level
	t.icon = p_icon
	t.weight = p_weight
	return t
