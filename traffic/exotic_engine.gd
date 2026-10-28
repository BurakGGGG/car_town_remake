class_name ExoticEngine
extends AudioStreamPlayer3D
## EGZOTİK ARACIN MOTORU (2026-10-17, kullanıcı: "bu egzotik araçlara trafikte motor uğultusu ekle"). Şehirden ara sıra
## geçen süper aracın (CarCatalog.is_exotic, TrafficManager doğurur) motor sesi. CityAmbience her egzotik araca bir
## tane kurar ve her fizik karesinde aracın konumu + hızıyla besler; Ambience bus'ında çalar (garaj / mağaza / yarış
## ekranında susar, pano açıkken kısılır), 3B: uzaklık kısar ve boğar, ekranın sağı sağ kulak.
##
## Ses dosyası yok — RaceAudio'nun ateşleme darbesi yöntemiyle KODLA üretilen döngü (CityAmbience'ın arka plan
## sentezinde), silindir sayısına göre üç tını: düz altı (911 GT3, hırıltılı), V8 (488 Pista, dolgun), V10 (Huracán,
## tiz çığlık). Sayı cars.json performance.engine metninden ("5.2 V10" → 10; sayı yazmıyorsa 6).
## Sürüş: hız → sanal vites + devir (perde); gaz verirken (hızlanma) vites yüksek devirde atar ve ses gürleşir, sabit
## hızda erken atar (sakin uğultu), yavaşlarken kısılır, kırmızıda rölanti; uzun bekleyişte (yarış daveti) rölanti de söner.

const MIX_RATE: int = 22050
## Döngü 2000 d/dk'da üretilir: krank 33,3 Hz → 0,6 sn'de 20 tur, ateşleme (silindir/2 × krank) 60 / 80 / 100 darbe.
## Her bileşen döngüde tam tur sayısında: dikiş yok. Perde = devir / BASE_RPM.
const BASE_RPM: float = 2000.0
const LOOP_SECONDS: float = 0.6

## Silindir → [darbe rezonansı, 2. harmonik, darbe sönümü, yanma gürültüsü, gövde, silindir farkı, perde payı]
const PROFILES: Dictionary = {
	6: [3.3, 0.45, 4.2, 0.15, 0.30, 0.14, 1.0],    # düz altı: metalik hırıltı
	8: [2.6, 0.30, 4.8, 0.12, 0.42, 0.18, 1.0],    # V8: dolgun, hafif "burble"
	10: [2.4, 0.55, 3.8, 0.10, 0.30, 0.10, 1.06],  # V10: tiz, düzgün çığlık
}

## Düzey (dB, Ambience bus'ında, kaynak dinleyiciden unit_size uzaktayken). Lastik sesi -19: motor ondan belirgin.
const ENGINE_DB: float = -12.0
## Gaz verirken bu kadar gür, yavaşlarken (gaz kesik) bu kadar kısık; rölantide bu kadar kısık.
const LOAD_DB: float = 4.0
const OVERRUN_DB: float = -6.0
const IDLE_DB: float = -7.0
## Bu kadar duran aracın rölantisi de söner (yarış daveti yol kenarında oyuncuyu beklerken uğuldamasın).
const IDLE_SILENCE: float = 6.0
const SILENT_DB: float = -50.0
## Motor sesi lastikten uzağa taşınır.
const UNIT_SIZE: float = 3.5
const MAX_DISTANCE: float = 28.0

## Devir: rölanti, gaz altında vites atma, sabit hızda vites atma, vites küçültme.
const IDLE_RPM: float = 950.0
const LOAD_SHIFT_RPM: float = 4300.0
const CRUISE_SHIFT_RPM: float = 2700.0
const DOWNSHIFT_RPM: float = 1500.0
## Vites oranları: devir = hız (birim/sn) × oran. Trafik 0,55–0,9 birim/sn: 1. viteste 0,3'te atar, 3.'de seyreder.
const GEAR_RATIOS: Array[float] = [14000.0, 7200.0, 4600.0, 3500.0]
## Hızlanma (birim/sn²) bu değerde "tam gaz" sayılır.
const FULL_THROTTLE: float = 0.45

var _gear: int = 0
var _rpm: float = IDLE_RPM
var _last_speed: float = 0.0
var _throttle: float = 0.0
var _still: float = 0.0
var _trim: float = 1.0


## Tını: cars.json performance.engine'deki silindir sayısına en yakın profil ("5.2 V10" → 10, "3.9 V8" → 8, V12 → 10);
## sayı yazmıyorsa 6 (GT3'ün düz altısı).
static func cylinders_of(vehicle_id: StringName) -> int:
	var performance: Variant = CarCatalog.get_entry(vehicle_id).get("performance", {})
	var engine: String = String((performance as Dictionary).get("engine", "")) if performance is Dictionary else ""
	var regex: RegEx = RegEx.create_from_string("[VW](\\d+)")
	var found: RegExMatch = regex.search(engine.to_upper())
	var count: int = int(found.get_string(1)) if found else 6
	return 10 if count >= 10 else (8 if count >= 8 else 6)


## Kurulum: `stream` CityAmbience bankasındaki döngü; `trim` araç başına küçük perde farkı.
func setup(stream_value: AudioStream, cylinders: int, trim: float, bus_name: StringName) -> void:
	name = "ExoticEngine"
	stream = stream_value
	bus = bus_name
	unit_size = UNIT_SIZE
	max_distance = MAX_DISTANCE
	_trim = trim * float((PROFILES.get(cylinders, PROFILES[6]) as Array)[6])
	volume_db = SILENT_DB
	pitch_scale = _pitch()


## Her fizik karesi: aracın (yumuşatılmış) hızı. Devir, perde ve düzey buradan.
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
	pitch_scale = _pitch()
	var target_db: float = ENGINE_DB + 2.5 * clampf((_rpm - IDLE_RPM) / (LOAD_SHIFT_RPM - IDLE_RPM), 0.0, 1.0)
	if not moving:
		target_db = ENGINE_DB + IDLE_DB if _still < IDLE_SILENCE else SILENT_DB
	elif _throttle > 0.0:
		target_db += LOAD_DB * _throttle
	else:
		target_db += OVERRUN_DB * -_throttle   # gaz kesik (yavaşlıyor): kısılır
	volume_db = move_toward(volume_db, target_db, (80.0 if target_db > volume_db else 25.0) * delta)   # kalkış hemen duyulur
	var silent: bool = volume_db <= SILENT_DB + 0.5
	if silent != stream_paused:
		stream_paused = silent


## Vites: gaz altında yüksek devirde, sabit hızda erken büyür; devir düşünce küçülür.
func _shift(speed: float) -> void:
	var rpm_now: float = speed * GEAR_RATIOS[_gear]
	var up_at: float = LOAD_SHIFT_RPM if _throttle > 0.25 else CRUISE_SHIFT_RPM
	if _gear < GEAR_RATIOS.size() - 1 and rpm_now > up_at \
			and speed * GEAR_RATIOS[_gear + 1] > DOWNSHIFT_RPM:
		_gear += 1
	elif _gear > 0 and rpm_now < DOWNSHIFT_RPM:
		_gear -= 1


func _pitch() -> float:
	return clampf(_rpm / BASE_RPM * _trim, 0.3, 2.6)


## Şu anki vites ve devir (QA).
func gear() -> int:
	return _gear


func rpm() -> float:
	return _rpm


# --- Sentez (CityAmbience arka plan iş parçacığında) ------------------------------------------------

## Motor döngüsü: her ateşlemede sönen bir rezonans darbesi (silindirler arası farkla), yarı ateşleme frekansında
## gövde uğultusu, darbeye bağlı yanma gürültüsü; yumuşak doyum + iki geçişli alçak geçiren (ikinci geçiş birincinin
## bitiş durumundan başlar → döngü dikişsiz). RaceAudio._make_engine ile aynı yol, silindir sayısı parametreli.
static func make_stream(cylinders: int) -> AudioStreamWAV:
	var p: Array = PROFILES.get(cylinders, PROFILES[6])
	var resonance: float = p[0]
	var harmonic: float = p[1]
	var decay: float = p[2]
	var noise: float = p[3]
	var body_gain: float = p[4]
	var spread: float = p[5]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 6100 + cylinders
	var fire_hz: float = BASE_RPM / 60.0 * float(cylinders) * 0.5
	var count: int = int(LOOP_SECONDS * float(MIX_RATE))
	var pulses: int = int(round(LOOP_SECONDS * fire_hz))
	var cylinder: PackedFloat32Array = PackedFloat32Array()
	for c: int in cylinders:
		cylinder.append(1.0 - spread * rng.randf())
	var pulse_gain: PackedFloat32Array = PackedFloat32Array()
	for k: int in pulses:
		pulse_gain.append(cylinder[k % cylinders] * rng.randf_range(0.92, 1.06))
	var raw: PackedFloat32Array = PackedFloat32Array()
	raw.resize(count)
	for i: int in count:
		var t: float = float(i) / float(MIX_RATE)
		var cycle_pos: float = t * fire_hz
		var k: int = int(cycle_pos) % pulses
		var phase: float = cycle_pos - floorf(cycle_pos)
		var ring: float = sin(TAU * phase * resonance) + harmonic * sin(TAU * phase * resonance * 2.0)
		var pulse: float = exp(-phase * decay) * ring * pulse_gain[k]
		var body: float = body_gain * sin(TAU * t * fire_hz * 0.5)
		var grit: float = rng.randf_range(-1.0, 1.0) * noise * exp(-phase * 3.0)
		raw[i] = tanh(1.6 * (pulse + body + grit))
	var state: float = 0.0
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(count)
	for _pass: int in 2:
		for i: int in count:
			state += (raw[i] - state) * 0.3
			out[i] = state
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(count * 2)
	for i: int in count:
		bytes.encode_s16(i * 2, int(clampf(out[i] * 0.75, -1.0, 1.0) * 32767.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.data = bytes
	LoopedWav.loop_forward(wav)
	return wav
