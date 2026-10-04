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
## İşin açıldığı GARAJ seviyesi (fiziksel genişleme). Orta süreli işler bir bay'i uzun süre işgal
## ettiği için ikinci bay'in alınabilir olduğu garaj seviyesinden önce müşteri olarak gelmezler.
@export_range(1, 4) var min_garage_level: int = 1
## İşin açılması için AÇILMIŞ tamir alanı sayısı. Ölçüm (model simülasyonu): tek alanı olan oyuncu
## 300 sn'lik bir işi alırsa 5 dakika boyunca yapacak hiçbir şeyi kalmıyor; almazsa bekleme noktası
## kalıcı olarak tıkanıyor (müşterinin sabır sayacı yok). Uzun iş ancak başka alan varken gelir.
@export_range(1, 3) var min_bays: int = 1
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


## ARIZA KATALOĞU — süre (sn), ödül (₺), XP, seviye ve garaj şartı burada tanımlıdır.
##
## İKİ KADEME (Car Town'ın süre/kâr eğrisi):
##   KISA  (6–12 sn)  — bay zamanı başına EN İYİ kazanç (~1.000 ₺/dk); aktif oyuncunun ekmeği.
##   ORTA  (90–300 sn) — bay zamanı başına daha düşük (~350–400 ₺/dk) ama tek işte çok daha yüksek
##                        mutlak ödül ve XP. Bir bay'i uzun süre işgal eder → "alayım mı?" kararı.
## Oyuncu orta işi almak zorunda değildir: almazsa müşteri bekler, bir bekleme noktası dolu kalır.
static func defaults() -> Array[RepairType]:
	return [
		# --- KISA İŞLER (Seviye 1, garaj 1) ---
		_make(&"engine", Loc.t("MOTOR ARIZASI"), 10.0, 0, 150, 10, 1, &"WRENCH", 1.0, Loc.t("MOTOR")),
		_make(&"brakes", Loc.t("FREN ARIZASI"), 8.0, 0, 140, 9, 1, &"WRENCH", 1.0, Loc.t("FREN")),
		_make(&"tires", Loc.t("LASTİK ARIZASI"), 6.0, 0, 100, 7, 1, &"ROTATE", 1.0, Loc.t("LASTİK")),
		_make(&"body", Loc.t("KAPORTA HASARI"), 12.0, 0, 200, 14, 1, &"CAR", 1.0, Loc.t("KAPORTA")),
		# --- ORTA İŞLER (seviye + garaj şartı) ---
		_make(&"paint_job", Loc.t("BOYA İŞİ"), 90.0, 0, 600, 45, 5, &"CAR", 0.8, Loc.t("BOYA"), 2, 2),
		_make(&"upholstery", Loc.t("DÖŞEME"), 180.0, 0, 1150, 85, 8, &"WRENCH", 0.6, Loc.t("DÖŞEME"), 2, 2),
		_make(&"brake_overhaul", Loc.t("FREN REVİZYONU"), 300.0, 0, 1800, 140, 12, &"WRENCH", 0.5, Loc.t("REVİZYON"), 3, 3),
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


static func _make(p_id: StringName, p_title: String, p_duration: float, p_cost: int, p_reward: int, p_xp: int, p_level: int, p_icon: StringName, p_weight: float, p_short: String = "", p_garage: int = 1, p_bays: int = 1) -> RepairType:
	var t: RepairType = RepairType.new()
	t.short = p_short
	t.id = p_id
	t.title = p_title
	t.duration = p_duration
	t.cost = p_cost
	t.reward = p_reward
	t.xp = p_xp
	t.min_level = p_level
	t.min_garage_level = p_garage
	t.min_bays = p_bays
	t.icon = p_icon
	t.weight = p_weight
	return t
