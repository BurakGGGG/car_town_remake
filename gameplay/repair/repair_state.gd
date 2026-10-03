class_name RepairState
extends RefCounted
## Tek bir tamir işinin çalışma zamanı durumu: hangi araç, hangi arıza, hangi aşama, ne kadar ilerledi.
## Değerler RepairType'tan okunur; burada yalnızca akış (aşama, geçen süre, bayraklar) tutulur.
## Aşamalar: REPAIRING (araç CarSpot'ta, sayaç işliyor) → REWARD_WAITING (bitti; ödül PARA TOPLA'yı
## bekliyor, araç CarSpot'ta kalır). Ödül toplanınca iş biter (RepairManager durumu bırakır).

enum Phase { REPAIRING, REWARD_WAITING }

var car: Node3D            # TrafficVehicle (tamir edilen araç)
var repair_type: RepairType   # arıza türü: süre, ödül ve XP buradan gelir
## Arıza şiddeti (RepairType.severity_min..max). İlk sürümde süreyi/ödülü ETKİLEMEZ; upgrade sistemi
## geldiğinde çarpan olarak kullanılacak (veri yapısında hazır dursun).
var severity: float = 1.0
## Bu işin kullandığı CarSpot indeksi (RepairManager.repair_car_spots).
var bay_index: int = 0
## Süre çarpanı: garaj "tamir hızı" geliştirmesinden gelir (Lv1 1.0 … Lv5 0.6). İş BAŞLARKEN sabitlenir,
## sonra alınan geliştirme süren işi kısaltmaz. RepairType.duration hiç değişmez.
var duration_scale: float = 1.0
## Ödül çarpanı: garaj seviyesi yükseldikçe daha değerli müşteriler gelir (RepairManager.SUPPLY).
## İş BAŞLARKEN sabitlenir; RepairType.reward hiç değişmez.
var reward_scale: float = 1.0
var phase: Phase = Phase.REPAIRING
var elapsed: float = 0.0
var is_repairing: bool = false
var is_completed: bool = false   # sayaç bitti
var is_collected: bool = false   # ödül alındı
## Ödüllü reklamla süre kısaltıldı mı? Bir iş EN ÇOK BİR kez kısaltılır.
var boosted: bool = false


func _init(target: Node3D, type: RepairType, issue_severity: float = 1.0) -> void:
	car = target
	repair_type = type
	severity = issue_severity


var repair_duration: float:
	get: return repair_type.duration * duration_scale

var repair_reward: int:
	get: return int(round(float(repair_type.reward) * reward_scale))

var repair_xp: int:
	get: return repair_type.xp

## 0.0 – 1.0
var repair_progress: float:
	get: return clampf(elapsed / maxf(repair_duration, 0.001), 0.0, 1.0)

## Kalan süre (sn), en az 0.
var remaining: float:
	get: return maxf(repair_duration - elapsed, 0.0)


func start() -> void:
	elapsed = 0.0
	is_repairing = true
	is_completed = false
	phase = Phase.REPAIRING


## Kalan sürenin `fraction` kadarını siler (0.5 = yarıya indirir). Yalnızca süren ve daha önce kısaltılmamış iş.
## Ödül / XP değişmez; yalnızca bekleme kısalır. Dönen: kısaltma uygulandı mı.
func boost(fraction: float) -> bool:
	if not is_repairing or boosted:
		return false
	boosted = true
	elapsed += remaining * clampf(fraction, 0.0, 1.0)
	return true


## Süreyi ilerletir; bu çağrıda tamamlandıysa true döner (aşama REWARD_WAITING: ödül toplanmayı bekler).
func advance(delta: float) -> bool:
	if not is_repairing:
		return false
	elapsed += delta
	if elapsed >= repair_duration:
		elapsed = repair_duration
		is_repairing = false
		is_completed = true
		phase = Phase.REWARD_WAITING
		return true
	return false
