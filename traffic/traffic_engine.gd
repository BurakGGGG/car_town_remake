class_name TrafficEngine
extends AudioStreamPlayer3D
## TRAFİK ARACININ MOTORU (2026-10-20, kullanıcı: "araç seslerini çeşitlendir ve daha da güzel olsun"). Egzotik olmayan
## her trafik aracının motor sesi; egzotikler ExoticEngine'de kalır. CityAmbience her araca bir tane kurar, her fizik
## karesinde konum + hızla besler; Ambience bus'ında çalar (dünyayı örten ekranlarda susar, pano açıkken kısılır).
##
## TİP (kind_of, cars.json'dan): elektrik / hibrit, dizel, dizel kamyonet, V8, altı silindir, eski karbüratörlü (2000
## öncesi küçük motor), büyük / turbo benzinli, küçük benzinli. Her tipin kendi döngüsü (sentez: ExoticEngine'in
## ateşleme darbesi yöntemi + dizelde tıkırtı, eskide hırıltı, V8'de düzensiz "burble"; elektrikte vınlama), kendi devir
## aralığı ve vites atma noktaları, kendi düzeyi ve kornası (horn_kind).
## "Kafa ağrıtmasın": düzeyler lastik sesine yakın; aynı anda yalnız dinleyiciye en yakın CityAmbience.ENGINE_VOICES
## araç duyulur (audible), kırmızıda rölanti kısık, uzun bekleyen (yol kenarındaki müşteri) motoru susar.

enum Kind { SMALL, FAMILY, SIX, V8, DIESEL, VAN, CLASSIC, ELECTRIC }

const MIX_RATE: int = 22050
## Döngü 2000 d/dk'da üretilir (ExoticEngine ile aynı): her bileşen döngüde tam tur sayısında, dikiş yok.
const BASE_RPM: float = 2000.0
const LOOP_SECONDS: float = 0.6

## Ses tasarımı: [silindir, darbe rezonansı, 2. harmonik, darbe sönümü, yanma gürültüsü, gövde, silindir farkı,
## dizel tıkırtısı, egzoz hırıltısı, süzgeç (büyük = parlak), doyum]
const VOICES: Dictionary = {
	Kind.SMALL: [4, 3.6, 0.35, 5.0, 0.10, 0.25, 0.10, 0.0, 0.0, 0.32, 1.4],     # vızıltılı küçük dört
	Kind.FAMILY: [4, 3.0, 0.30, 4.6, 0.10, 0.36, 0.10, 0.0, 0.0, 0.27, 1.5],    # dolgun, sakin dört
	Kind.SIX: [6, 2.8, 0.35, 4.4, 0.08, 0.32, 0.08, 0.0, 0.0, 0.27, 1.5],       # pürüzsüz altı
	Kind.V8: [8, 2.2, 0.30, 4.8, 0.14, 0.52, 0.0, 0.0, 0.0, 0.21, 1.9],         # kalın, düzensiz "burble"
	Kind.DIESEL: [4, 2.4, 0.25, 6.0, 0.08, 0.40, 0.08, 0.55, 0.0, 0.42, 1.5],   # tıkırtılı dizel
	Kind.VAN: [4, 2.0, 0.25, 5.5, 0.08, 0.52, 0.10, 0.45, 0.0, 0.36, 1.6],      # iri dizel kamyonet
	Kind.CLASSIC: [4, 3.8, 0.45, 3.6, 0.20, 0.30, 0.30, 0.0, 0.55, 0.36, 2.0],  # hırıltılı eski karbüratör
}
## V8'in düzensiz ateşleme sırası (çapraz krank): darbe güçleri sırayla — "burble" buradan.
const V8_PATTERN: Array[float] = [1.0, 0.72, 0.95, 1.0, 0.68, 0.98, 0.8, 0.7]

## Sürüş: [düzey dB (ölçüldü: motorlar çevre sesini ~3 dB artırır, lastikle aynı düzeyde), rölanti, gazda vites atma, sabit hızda vites atma, vites küçültme, perde payı, unit_size]
const DRIVES: Dictionary = {
	Kind.SMALL: [-31.0, 850.0, 3800.0, 2500.0, 1400.0, 1.0, 2.8],
	Kind.FAMILY: [-30.0, 800.0, 3400.0, 2200.0, 1300.0, 1.0, 2.8],
	Kind.SIX: [-29.0, 750.0, 3500.0, 2100.0, 1250.0, 1.0, 3.0],
	Kind.V8: [-25.0, 700.0, 3200.0, 1900.0, 1200.0, 1.0, 3.5],
	Kind.DIESEL: [-30.0, 780.0, 2800.0, 1800.0, 1150.0, 1.0, 2.8],
	Kind.VAN: [-28.0, 720.0, 2600.0, 1700.0, 1100.0, 0.86, 3.2],
	Kind.CLASSIC: [-28.0, 950.0, 4000.0, 2900.0, 1600.0, 1.0, 3.0],
	Kind.ELECTRIC: [-34.0, 0.0, 0.0, 0.0, 0.0, 1.0, 2.5],
}
## Vites oranları: devir = hız (birim/sn) × oran (ExoticEngine ile aynı ölçek; trafik 0,55–0,9 birim/sn).
const GEAR_RATIOS: Array[float] = [13000.0, 7000.0, 4600.0, 3500.0]
## Elektrik: tek oran (vites yok); hız → vınlama perdesi.
const ELECTRIC_RATIO: float = 3000.0

## Gazda bu kadar gür, gaz kesikken bu kadar kısık, rölantide bu kadar kısık (dB, tipin düzeyine göre).
const LOAD_DB: float = 3.0
const OVERRUN_DB: float = -5.0
const IDLE_DB: float = -8.0
## Bu kadar duran aracın motoru söner (yol kenarındaki müşteri, uzun kırmızı); duyulmayan (uzak) motor da söner.
const IDLE_SILENCE: float = 12.0
const SILENT_DB: float = -50.0
const MAX_DISTANCE: float = 26.0
## Hızlanma (birim/sn²) bu değerde "tam gaz".
const FULL_THROTTLE: float = 0.45

## Katalogdaki motor metninde (büyük harfe çevrilmiş) yakıt işaretleri. StringName: oyuncu metni değil (i18n çıkarıcı
## düz dizgeleri çeviri sanar).
const ELECTRIC_TOKENS: Array[StringName] = [&"ELEKTR", &"HİBRİT", &"HIBRIT"]
const DIESEL_TOKENS: Array[StringName] = [&"TDI", &"CDI", &"CRDI", &"DİZEL", &"DIZEL", &"ECOBLUE", &"JTD", &"DCI", &"HDI"]

## Korna karakteri (CityAmbience bankası tip başına korna takımı üretir): ince tek ton, klasik çift ton, kalın çift ton,
## kamyonet, eski "mıık", elektrikli (temiz).
enum Horn { SMALL, CLASSIC_DUAL, DEEP, VAN, OLD, CLEAN }

var kind: Kind = Kind.SMALL
var _gear: int = 0
var _rpm: float = 0.0
var _last_speed: float = 0.0
var _throttle: float = 0.0
var _still: float = 0.0
var _trim: float = 1.0


## Aracın motor tipi (cars.json: performance.engine metni, yıl, kategori).
static func kind_of(vehicle_id: StringName) -> Kind:
	var entry: Dictionary = CarCatalog.get_entry(vehicle_id)
	var performance: Variant = entry.get("performance", {})
	var engine: String = String((performance as Dictionary).get("engine", "")).to_upper() if performance is Dictionary else ""
	var category: String = String(entry.get("category", ""))
	for token: StringName in ELECTRIC_TOKENS:
		if engine.contains(String(token)):
			return Kind.ELECTRIC
	var diesel: bool = false
	for token: StringName in DIESEL_TOKENS:
		diesel = diesel or engine.contains(String(token))
	if diesel:
		return Kind.VAN if category == "van" else Kind.DIESEL
	var litres: float = 0.0
	var number: RegExMatch = RegEx.create_from_string("(\\d+(?:\\.\\d+)?)").search(engine)
	if number:
		litres = float(number.get_string(1))
	if engine.contains("V8") or engine.contains("V10") or engine.contains("V12") or engine.contains("W1") or litres >= 5.0:
		return Kind.V8
	if engine.contains("V6") or litres >= 2.8:
		return Kind.SIX
	if int(entry.get("year", 2010)) < 2000 and litres <= 1.8:
		return Kind.CLASSIC
	if litres >= 1.8:
		return Kind.FAMILY
	return Kind.SMALL


## Motor tipinin kornası.
static func horn_kind(engine_kind: Kind) -> Horn:
	match engine_kind:
		Kind.SMALL:
			return Horn.SMALL
		Kind.V8, Kind.SIX:
			return Horn.DEEP
		Kind.VAN:
			return Horn.VAN
		Kind.CLASSIC:
			return Horn.OLD
		Kind.ELECTRIC:
			return Horn.CLEAN
	return Horn.CLASSIC_DUAL


## Kurulum: `stream` CityAmbience bankasındaki tip döngüsü; `trim` araç başına küçük perde farkı.
func setup(stream_value: AudioStream, engine_kind: Kind, trim: float, bus_name: StringName) -> void:
	name = "TrafficEngine"
	kind = engine_kind
	stream = stream_value
	bus = bus_name
	var spec: Array = DRIVES[kind]
	unit_size = float(spec[6])
	max_distance = MAX_DISTANCE
	_trim = trim * float(spec[5])
	_rpm = float(spec[1])
	volume_db = SILENT_DB
	pitch_scale = _pitch()


## Her fizik karesi: aracın (yumuşatılmış) hızı; `running` false = kontak kapalı (yol kenarında bekleyen müşteri,
## tamirdeki); `audible` false = dinleyiciye uzak (ses kanalı yakındaki araçlara kalır). İkisi de yavaşça susturur.
func drive(speed: float, delta: float, running: bool = true, audible: bool = true) -> void:
	if delta <= 0.0:
		return
	var spec: Array = DRIVES[kind]
	var accel: float = (speed - _last_speed) / delta
	_last_speed = speed
	_throttle = lerpf(_throttle, clampf(accel / FULL_THROTTLE, -1.0, 1.0), 1.0 - exp(-8.0 * delta))
	var moving: bool = speed > 0.03
	_still = 0.0 if moving else _still + delta
	var idle_rpm: float = float(spec[1])
	var target_rpm: float
	if kind == Kind.ELECTRIC:
		target_rpm = speed * ELECTRIC_RATIO
	else:
		_shift(speed, spec)
		target_rpm = maxf(speed * GEAR_RATIOS[_gear], idle_rpm) if moving else idle_rpm
	_rpm = move_toward(_rpm, target_rpm, (8000.0 if target_rpm > _rpm else 12000.0) * delta)
	pitch_scale = _pitch()
	var base_db: float = float(spec[0])
	var load_span: float = maxf(float(spec[2]) - idle_rpm, 1.0) if kind != Kind.ELECTRIC else ELECTRIC_RATIO
	var target_db: float = base_db + 2.0 * clampf((_rpm - idle_rpm) / load_span, 0.0, 1.0)
	if not running or not audible:
		target_db = SILENT_DB
	elif not moving:
		# Elektrikli dururken sessizdir; yanmalı kırmızıda rölantide kısık, uzun bekleyişte söner
		target_db = SILENT_DB if kind == Kind.ELECTRIC or _still > IDLE_SILENCE else base_db + IDLE_DB
	elif _throttle > 0.0:
		target_db += LOAD_DB * _throttle
	else:
		target_db += OVERRUN_DB * -_throttle
	volume_db = move_toward(volume_db, target_db, (70.0 if target_db > volume_db else 22.0) * delta)
	var silent: bool = volume_db <= SILENT_DB + 0.5
	if silent != stream_paused:
		stream_paused = silent


func _shift(speed: float, spec: Array) -> void:
	var rpm_now: float = speed * GEAR_RATIOS[_gear]
	var up_at: float = float(spec[2]) if _throttle > 0.25 else float(spec[3])
	var down_at: float = float(spec[4])
	if _gear < GEAR_RATIOS.size() - 1 and rpm_now > up_at and speed * GEAR_RATIOS[_gear + 1] > down_at:
		_gear += 1
	elif _gear > 0 and rpm_now < down_at:
		_gear -= 1


func _pitch() -> float:
	if kind == Kind.ELECTRIC:
		return clampf(0.35 + _rpm / BASE_RPM * 0.6 * _trim, 0.3, 2.2)
	return clampf(_rpm / BASE_RPM * _trim, 0.3, 2.6)


## Şu anki vites ve devir (QA / test).
func gear() -> int:
	return _gear


func rpm() -> float:
	return _rpm


# --- Sentez (CityAmbience arka plan iş parçacığında) ------------------------------------------------

## Tipin motor döngüsü (BASE_RPM'de LOOP_SECONDS).
static func make_stream(engine_kind: Kind) -> AudioStreamWAV:
	if engine_kind == Kind.ELECTRIC:
		return _wav(_electric())
	return _wav(_combustion(engine_kind))


## İçten yanmalı: her ateşlemede sönen rezonans darbesi (silindirler arası farkla), yarı ateşleme frekansında gövde,
## yanma gürültüsü; dizelde her darbenin başında sert tıkırtı (tiz, çok kısa), eskide uzun egzoz hırıltısı; yumuşak
## doyum + iki geçişli alçak geçiren (ikinci geçiş birincinin bitiş durumundan: dikişsiz).
static func _combustion(engine_kind: Kind) -> PackedFloat32Array:
	var p: Array = VOICES[engine_kind]
	var cylinders: int = p[0]
	var resonance: float = p[1]
	var harmonic: float = p[2]
	var decay: float = p[3]
	var noise: float = p[4]
	var body_gain: float = p[5]
	var spread: float = p[6]
	var knock: float = p[7]
	var rasp: float = p[8]
	var smooth: float = p[9]
	var drive: float = p[10]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7300 + int(engine_kind)
	var fire_hz: float = BASE_RPM / 60.0 * float(cylinders) * 0.5
	var count: int = int(LOOP_SECONDS * float(MIX_RATE))
	var pulses: int = int(round(LOOP_SECONDS * fire_hz))
	var cylinder: PackedFloat32Array = PackedFloat32Array()
	for c: int in cylinders:
		cylinder.append(V8_PATTERN[c % V8_PATTERN.size()] if engine_kind == Kind.V8 else 1.0 - spread * rng.randf())
	var pulse_gain: PackedFloat32Array = PackedFloat32Array()
	for k: int in pulses:
		pulse_gain.append(cylinder[k % cylinders] * rng.randf_range(1.0 - 0.06 - spread * 0.3, 1.06))
	var raw: PackedFloat32Array = PackedFloat32Array()
	raw.resize(count)
	var click: float = 0.0
	for i: int in count:
		var t: float = float(i) / float(MIX_RATE)
		var cycle_pos: float = t * fire_hz
		var k: int = int(cycle_pos) % pulses
		var phase: float = cycle_pos - floorf(cycle_pos)
		var ring: float = sin(TAU * phase * resonance) + harmonic * sin(TAU * phase * resonance * 2.0)
		var pulse: float = exp(-phase * decay) * ring * pulse_gain[k]
		var body: float = body_gain * sin(TAU * t * fire_hz * 0.5)
		var white: float = rng.randf_range(-1.0, 1.0)
		var grit: float = white * noise * exp(-phase * 3.0)
		# Dizel tıkırtısı: farkı alınmış gürültü (tiz) darbenin ilk ~2 ms'sinde
		click = white - click * 0.2
		var clatter: float = knock * click * exp(-phase * 45.0) * pulse_gain[k]
		var growl: float = rasp * white * exp(-phase * 1.4) * (0.6 + 0.4 * sin(TAU * phase))
		raw[i] = tanh(drive * (pulse + body + grit + growl)) + clatter * 0.6
	var state: float = 0.0
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(count)
	for _pass: int in 2:
		for i: int in count:
			state += (raw[i] - state) * smooth
			out[i] = state
	return out


## Elektrik: invertör vınlaması (iki ton + çok hafif üst ton) + motor uğultusu + yumuşak yol hışırtısı. Tonlar döngüde
## tam tur (333,3 / 1000 / 1666,7 Hz; 0,6 sn'de 200 / 600 / 1000 tur).
static func _electric() -> PackedFloat32Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7399
	var count: int = int(LOOP_SECONDS * float(MIX_RATE))
	var raw: PackedFloat32Array = PackedFloat32Array()
	raw.resize(count)
	for i: int in count:
		var t: float = float(i) / float(MIX_RATE)
		var shimmer: float = 1.0 + 0.08 * sin(TAU * 5.0 * t / LOOP_SECONDS)
		raw[i] = 0.55 * sin(TAU * 333.3333 * t) + 0.22 * sin(TAU * 1000.0 * t) * shimmer \
			+ 0.07 * sin(TAU * 1666.6667 * t) + 0.3 * sin(TAU * 166.6667 * t) + rng.randf_range(-0.12, 0.12)
	var state: float = 0.0
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(count)
	for _pass: int in 2:
		for i: int in count:
			state += (raw[i] - state) * 0.5
			out[i] = state
	return out


static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var top: float = 0.0001
	for s: float in samples:
		top = maxf(top, absf(s))
	var gain: float = 0.75 / top
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i] * gain, -1.0, 1.0) * 32767.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.data = bytes
	LoopedWav.loop_forward(wav)
	return wav


# --- Korna (CityAmbience arka plan sentezinde) ---------------------------------------------------

## Korna karakteri: [tonlar (Hz), vızıltı (diyafram pürüzü), rezonans tepesi (Hz), parlaklık (yüksek harmonik payı)]
const HORNS: Dictionary = {
	Horn.SMALL: [[505.0], 0.18, 2600.0, 0.9],
	Horn.CLASSIC_DUAL: [[415.0, 520.0], 0.15, 2300.0, 0.8],
	Horn.DEEP: [[350.0, 440.0], 0.12, 1900.0, 0.75],
	Horn.VAN: [[300.0, 375.0], 0.16, 1700.0, 0.7],
	Horn.OLD: [[365.0], 0.42, 1500.0, 1.0],
	Horn.CLEAN: [[470.0, 590.0], 0.05, 2400.0, 0.55],
}
## Basış desenleri: [[başlangıç sn, süre sn], …] — dıt, dıt-dıt, uzun, sabırsız.
const HORN_TAP: int = 0
const HORN_DOUBLE: int = 1
const HORN_LONG: int = 2
const HORN_ANGRY: int = 3
const HORN_PATTERNS: Array = [
	[[0.0, 0.11]],
	[[0.0, 0.1], [0.17, 0.14]],
	[[0.0, 0.5]],
	[[0.0, 0.08], [0.13, 0.08], [0.26, 0.34]],
]
const HORN_TABLE: int = 512


## Kornanın dört basış deseni (HORN_PATTERNS sırasıyla).
static func horn_streams(horn: Horn) -> Array[AudioStreamWAV]:
	var spec: Array = HORNS[horn]
	var tables: Array[PackedFloat32Array] = []
	for tone: float in spec[0]:
		tables.append(_horn_cycle(tone, float(spec[2]), float(spec[3])))
	var out: Array[AudioStreamWAV] = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 8100 + int(horn)
	for pattern: Array in HORN_PATTERNS:
		out.append(_horn_render(pattern, spec[0], tables, float(spec[1]), rng))
	return out


## Bir periyotluk dalga tablosu: harmonik dizisi (1/k^0.9), rezonans tepesine yakın harmonikler güçlü (borunun "ağzı").
static func _horn_cycle(tone: float, formant: float, bright: float) -> PackedFloat32Array:
	var table: PackedFloat32Array = PackedFloat32Array()
	table.resize(HORN_TABLE)
	var harmonics: int = clampi(int(5200.0 / tone), 1, 16)
	for i: int in HORN_TABLE:
		var x: float = TAU * float(i) / float(HORN_TABLE)
		var v: float = 0.0
		for k: int in range(1, harmonics + 1):
			var f: float = tone * float(k)
			var peak: float = exp(-pow((f - formant) / 650.0, 2.0))
			v += sin(x * float(k)) * (pow(float(k), -0.9) * lerpf(1.0, 0.35, 1.0 - bright) + 0.9 * peak)
		table[i] = v
	return table


## Desen boyunca tablolar çalınır: basışta perde %4 aşağıdan oturur ("vaa"), diyafram vızıltısı (ana tonda genlik
## pürüzü), yumuşak atak / bırakış, hafif doyum, telefonda cızırtı olmasın diye tiz kısılır.
static func _horn_render(pattern: Array, tones: Array, tables: Array[PackedFloat32Array], buzz: float,
		rng: RandomNumberGenerator) -> AudioStreamWAV:
	var total: float = 0.0
	for beep: Array in pattern:
		total = maxf(total, float(beep[0]) + float(beep[1]))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int((total + 0.06) * MIX_RATE))
	for beep: Array in pattern:
		var start: int = int(float(beep[0]) * MIX_RATE)
		var dur: float = float(beep[1])
		var length: int = int(dur * MIX_RATE)
		var phases: PackedFloat32Array = PackedFloat32Array()
		for t_index: int in tones.size():
			phases.append(rng.randf())
		var rough: float = 0.0
		for i: int in length:
			var t: float = float(i) / float(MIX_RATE)
			var env: float = minf(t / 0.008, 1.0) * clampf((dur - t) / 0.04, 0.0, 1.0)
			var bend: float = 1.0 - 0.04 * exp(-t / 0.018)
			rough += 0.2 * (rng.randf_range(-1.0, 1.0) - rough)
			var v: float = 0.0
			for n: int in tones.size():
				phases[n] = fmod(phases[n] + float(tones[n]) * bend / float(MIX_RATE), 1.0)
				var pos: float = phases[n] * float(HORN_TABLE)
				var a: int = int(pos)
				var table: PackedFloat32Array = tables[n]
				v += lerpf(table[a % HORN_TABLE], table[(a + 1) % HORN_TABLE], pos - float(a))
			v *= 1.0 + buzz * rough * 2.0 * sin(TAU * phases[0])
			samples[start + i] += tanh(v * 0.45) * env
	var state: float = 0.0
	for i: int in samples.size():
		state += (samples[i] - state) * 0.62
		samples[i] = state
	var top: float = 0.0001
	for s: float in samples:
		top = maxf(top, absf(s))
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i] * 0.8 / top, -1.0, 1.0) * 32767.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.data = bytes
	return wav
