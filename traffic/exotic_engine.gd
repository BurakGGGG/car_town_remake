class_name ExoticEngine
extends AudioStreamPlayer3D
## EGZOTİK ARACIN MOTORU (2026-10-17; 2026-11-02 yeni ses). Şehirden ara sıra geçen süper aracın (CarCatalog.is_exotic,
## TrafficManager doğurur) motor sesi. CityAmbience her egzotik araca bir tane kurar ve her fizik karesinde aracın
## konumu + hızıyla besler; Ambience bus'ında çalar (garaj / mağaza / yarış ekranında susar, pano açıkken kısılır),
## 3B: uzaklık kısar ve boğar, ekranın sağı sağ kulak.
##
## SES (2026-11-02): aracın KENDİ pişmiş motor sesi (EngineBank, MOTOR SES LABORATUVARI) EngineVoice ile — tam kalite
## (gaz açık / kesik birlikte), dinamik DYNAMICS kadar: ışıktan kalkışta (TrafficVehicle.LAUNCH_CHANCE) gerçekten
## gürler, gaz kesince bankanın patlamaları / blow-off'u gelir. Eskiden silindir sayısına göre 3 döngüden biriydi.
## Sürüş: hız → sanal vites + devir; gaz verirken (hızlanma) vites yüksek devirde atar, sabit hızda erken atar (sakin
## uğultu), yavaşlarken gaz kesik, kırmızıda rölanti; uzun bekleyişte (yarış daveti) rölanti de söner.
## 2026-11-02 (kullanıcı: "yavaşken kulağa güzel gelmiyor"): yavaşken düşük devirde, hafif gazda boğuk kalıyordu → vitesler
## daha geç büyür / daha erken küçülür (seyir ~2300–3800 d/dk), seyir gazı biraz açık; araç ara sıra gazlar
## (TrafficVehicle.SURGE_*) ve şehir trafiğinden hızlıdır (TrafficManager.EXOTIC_PACE).

## Düzey (dB, Ambience bus'ında, kaynak dinleyiciden unit_size uzaktayken). Lastik sesi -19: motor ondan belirgin.
## Bankanın EN GÜR katmanına göre; seyir ve rölanti bunun altında (bankadan, DYNAMICS ile sıkıştırılmış).
const ENGINE_DB: float = -2.0
const DYNAMICS: float = 0.65
const CRUISE_THROTTLE: float = 0.32
## Bu kadar duran aracın rölantisi de söner (yarış daveti yol kenarında oyuncuyu beklerken uğuldamasın).
const IDLE_SILENCE: float = 6.0
const SILENT_DB: float = -50.0
## Motor sesi lastikten uzağa taşınır.
const UNIT_SIZE: float = 3.5
const MAX_DISTANCE: float = 28.0

## Devir: rölanti, gaz altında vites atma, sabit hızda vites atma, vites küçültme.
const IDLE_RPM: float = 950.0
const LOAD_SHIFT_RPM: float = 5600.0
const CRUISE_SHIFT_RPM: float = 3800.0
const DOWNSHIFT_RPM: float = 2300.0
## Vites oranları: devir = hız (birim/sn) × oran. Süper araç seyri ~0,7–1,2 birim/sn (EXOTIC_PACE): 3.–4. viteste
## ~3000–4000 d/dk; gazlamada (1,55) 3.'te ~5600'e çıkıp atar; ışıktan kalkışta (2,0) 4.'de ~7000.
const GEAR_RATIOS: Array[float] = [14000.0, 7200.0, 4600.0, 3500.0]
## Hızlanma (birim/sn²) bu değerde "tam gaz" sayılır.
const FULL_THROTTLE: float = 0.45

var voice: EngineVoice
var _gear: int = 0
var _rpm: float = IDLE_RPM
var _last_speed: float = 0.0
var _throttle: float = 0.0
var _still: float = 0.0


## Kurulum: aracın pişmiş motor sesi.
func setup(bank: EngineBank, bus_name: StringName) -> void:
	name = "ExoticEngine"
	bus = bus_name
	unit_size = UNIT_SIZE
	max_distance = MAX_DISTANCE
	volume_db = SILENT_DB
	voice = EngineVoice.new(self, bank)
	voice.dynamics = DYNAMICS


## Her fizik karesi: aracın (yumuşatılmış) hızı. Devir ve gaz buradan; ses EngineVoice'ta.
func drive(speed: float, delta: float) -> void:
	if delta <= 0.0:
		return
	var accel: float = (speed - _last_speed) / delta
	_last_speed = speed
	_throttle = lerpf(_throttle, clampf(accel / FULL_THROTTLE, -1.0, 1.0), 1.0 - exp(-8.0 * delta))
	var moving: bool = speed > 0.03
	_still = 0.0 if moving else _still + delta
	_shift(speed)
	var target_rpm: float = maxf(speed * GEAR_RATIOS[_gear], IDLE_RPM) if moving else IDLE_RPM
	_rpm = move_toward(_rpm, target_rpm, (9000.0 if target_rpm > _rpm else 14000.0) * delta)
	var target_db: float = ENGINE_DB if moving or _still < IDLE_SILENCE else SILENT_DB
	volume_db = move_toward(volume_db, target_db, (80.0 if target_db > volume_db else 25.0) * delta)
	var silent: bool = volume_db <= SILENT_DB + 0.5
	if silent != stream_paused:
		stream_paused = silent
	if not silent and voice:
		voice.update(delta, _rpm, load_now(moving), false)


## Sese giden gaz: dururken 0 (rölanti), seyirde hafif, hızlanırken artar (kalkışta tam), yavaşlarken kesik.
func load_now(moving: bool) -> float:
	if not moving:
		return 0.0
	return clampf(CRUISE_THROTTLE + _throttle, 0.0, 1.0)


## Vites: gaz altında yüksek devirde, sabit hızda erken büyür; devir düşünce küçülür.
func _shift(speed: float) -> void:
	var rpm_now: float = speed * GEAR_RATIOS[_gear]
	var up_at: float = LOAD_SHIFT_RPM if _throttle > 0.25 else CRUISE_SHIFT_RPM
	if _gear < GEAR_RATIOS.size() - 1 and rpm_now > up_at \
			and speed * GEAR_RATIOS[_gear + 1] > DOWNSHIFT_RPM:
		_gear += 1
	elif _gear > 0 and rpm_now < DOWNSHIFT_RPM:
		_gear -= 1


## Şu anki vites ve devir (QA).
func gear() -> int:
	return _gear


func rpm() -> float:
	return _rpm
