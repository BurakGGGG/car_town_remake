class_name EngineSynth
extends RefCounted
## MOTOR SESİ SENTEZİ (2026-11-02). EnginePreset sözlüğünden ses üretir; EngineBank pişirirken, MOTOR SES
## LABORATUVARI dinletirken kullanır (oyun pişmiş bankayı çalar, burayı çağırmaz).
##
## Eski yöntemden farkı (sesler "yapay ve hepsi aynı" idi): tek döngünün perdesini değiştirmek yerine HER DEVİRDE
## ayrı üretilir. Darbe krank açısında tarif edilir (devirle kısalır) ama manifold / boru / susturucu rezonansları Hz'de
## SABİT kalır → devir artınca tını gerçek motordaki gibi değişir ("sincap" sesi yok).
##
## ZİNCİR (içten yanmalı):
##   1. ATEŞLEME  — dizilimin ateşleme açıları (geometry), krank açısı devir eğrisiyle ilerler; her ateşleme bir olay:
##                  silindir farkı, yanma düzensizliği, kam dalgalanması, tekleme, zamanlama titremesi, taraf etkileşimi.
##   2. DARBE     — egzoz basınç darbesi (ani yükselme + sönme, pulse_deg krank açısı boyunca) silindirin manifold
##                  gecikmesiyle kendi tarafının (bank) tamponuna eklenir; manifolddan iki ters yansıma (header_refl).
##   3. KOLEKTÖR  — taraf başına doyum (darbelerin çarpışması), X-boru karışımı.
##   4. BORU      — taraf başına sönümlü yansımalı gecikme hattı (egzoz borusu rezonansı), iki taraf farklı boyda.
##   5. AKIŞ      — darbe zarfıyla değişen gürültü: hırıltı (tiz) + yanma gürültüsü (orta).
##   6. SUSTURUCU — alçak geçiren (açıklık, tını), oda uğultusu (tepe), bas rafı, alt kesim.
##   7. EK        — emme (gürültü + ton), blok çınlaması, supap tıkırtısı, dizel tıkırtısı, kompresör / dişli vınlaması.
##   8. DÜZEY     — devirle yükselme, gaz kesik kısıklığı; son doyum finish()'te (bankanın ortak ölçeğiyle).
## Elektrik: kalın motor gövdesi + fütüristik akor + yol / rüzgâr + süzülmüş vınlama (motor, redüktör, invertör); ayrıntı _render_ev.

## Egzoz gazında ses hızı (m/sn, ~400 °C).
const C_GAS: float = 500.0
const SHAPE_SIZE: int = 512
const NOISE_SIZE: int = 65536
## Döngü uzunluğu: ~8 motor çevrimi, şu sınırlar içinde (sn).
const LOOP_MIN: float = 0.45
const LOOP_MAX: float = 1.1
## Döngü dikişi: sonu başına bu kadar çapraz geçer (sn).
const LOOP_FADE: float = 0.06
## Döngüden önce atılan ısınma (süzgeç / boru durumları otursun).
const WARMUP: float = 0.25

static var _noise: PackedFloat32Array = PackedFloat32Array()
## Bant sınırlı testere dalgası (20 harmonik, 1/k): elektrikli aracın akor uğultusu.
const SAW_SIZE: int = 2048
static var _saw: PackedFloat32Array = PackedFloat32Array()


# --- Dizilim ----------------------------------------------------------------------------------------------------

## Ateşleme düzeni: {cycle (krank °), angles (ateşleme sırasıyla °), banks (her ateşlemenin egzoz tarafı), nbanks}.
static func geometry(layout: String) -> Dictionary:
	match layout:
		"i1":
			return _geo(720.0, [0.0], [0])
		"i2":
			return _geo(720.0, [0.0, 360.0], [0, 0])
		"i3":
			return _geo(720.0, _even(3, 720.0), [0, 0, 0])
		"i5":
			return _geo(720.0, _even(5, 720.0), [0, 0, 0, 0, 0])
		"i6":
			return _geo(720.0, _even(6, 720.0), [0, 0, 0, 0, 0, 0])
		"v6_60":
			return _geo(720.0, _even(6, 720.0), _alternate(6))
		"v6_90":
			return _geo(720.0, [0.0, 90.0, 240.0, 330.0, 480.0, 570.0], _alternate(6))
		"v8_cross":
			# GM sırası 1-8-4-3-6-5-7-2: tek numaralılar sol, çiftler sağ → her taraf düzensiz aralık ("gurultu")
			return _geo(720.0, _even(8, 720.0), [0, 1, 1, 0, 1, 0, 0, 1])
		"v8_flat":
			return _geo(720.0, _even(8, 720.0), _alternate(8))
		"v10":
			return _geo(720.0, _even(10, 720.0), _alternate(10))
		"v12", "w12":
			return _geo(720.0, _even(12, 720.0), _alternate(12))
		"w16":
			return _geo(720.0, _even(16, 720.0), _alternate(16))
		"b4":
			# VW 1-4-3-2: 1-2 sağ, 3-4 sol
			return _geo(720.0, _even(4, 720.0), [0, 1, 1, 0])
		"b6":
			return _geo(720.0, _even(6, 720.0), _alternate(6))
		"r2":
			# Wankel: her rotor eksantrik milinin her turunda bir kez ateşler
			return _geo(360.0, [0.0, 180.0], [0, 0])
		"r3":
			return _geo(360.0, [0.0, 120.0, 240.0], [0, 0, 0])
	return _geo(720.0, _even(4, 720.0), [0, 0, 0, 0])


static func _even(count: int, cycle: float) -> Array:
	var out: Array = []
	for i: int in count:
		out.append(cycle * float(i) / float(count))
	return out


static func _alternate(count: int) -> Array:
	var out: Array = []
	for i: int in count:
		out.append(i % 2)
	return out


static func _geo(cycle: float, angles: Array, banks: Array) -> Dictionary:
	var nbanks: int = 1
	for b: int in banks:
		nbanks = maxi(nbanks, b + 1)
	return {"cycle": cycle, "angles": PackedFloat32Array(angles), "banks": PackedInt32Array(banks), "nbanks": nbanks}


## Bir motor çevriminin süresi (sn): pistonlu 720°, Wankel 360°; elektrikte bir tur.
static func cycle_seconds(preset: Dictionary, rpm: float) -> float:
	var cycle: float = 360.0 if preset["layout"] == "ev" else float(geometry(preset["layout"])["cycle"])
	return cycle / 360.0 * 60.0 / maxf(rpm, 60.0)


## Devir katmanları: rölantiden kırmızı çizgiye geometrik aralıklı (elektrikte en alt 400 d/dk).
static func layer_rpms(preset: Dictionary) -> PackedFloat32Array:
	var count: int = int(preset["layers"])
	var low: float = maxf(float(preset["idle_rpm"]), 400.0)
	var high: float = maxf(float(preset["redline_rpm"]), low * 1.5)
	var out: PackedFloat32Array = PackedFloat32Array()
	for i: int in count:
		out.append(low * pow(high / low, float(i) / float(count - 1)))
	return out


# --- Döngü ve eğri ----------------------------------------------------------------------------------------------

## Sabit devir ve yükte dikişsiz döngü (doğrusal, son doyumsuz: finish() ile tamamlanır).
static func render_loop(preset: Dictionary, rpm: float, load: float, seed_value: int) -> PackedFloat32Array:
	var rate: int = int(preset["rate"])
	var cycle_s: float = cycle_seconds(preset, rpm)
	var cycles: int = maxi(1, roundi(clampf(8.0 * cycle_s, LOOP_MIN, LOOP_MAX) / cycle_s))
	var n: int = roundi(float(cycles) * cycle_s * float(rate))
	var fade: int = mini(int(LOOP_FADE * float(rate)), n / 3)
	var pre: int = int(WARMUP * float(rate))
	var total: int = pre + n + fade
	var rpm_curve: PackedFloat32Array = PackedFloat32Array()
	rpm_curve.resize(total)
	rpm_curve.fill(rpm)
	var load_curve: PackedFloat32Array = PackedFloat32Array()
	load_curve.resize(total)
	load_curve.fill(load)
	var raw: PackedFloat32Array = _render(preset, rpm_curve, load_curve, seed_value, float(n) / float(rate))
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	for i: int in n:
		out[i] = raw[pre + i]
	# Dikiş: başlangıç, döngü sonunun devamından kendine geçer → son örnekten ilk örneğe kesintisiz
	for i: int in fade:
		var w: float = sin(0.5 * PI * float(i) / float(fade))
		w *= w
		out[i] = raw[pre + i] * w + raw[pre + n + i] * (1.0 - w)
	return out


## Zamanla değişen devir / yük (marş, kontak kapatma); eğriler örnek başına.
static func render_curve(preset: Dictionary, rpm_curve: PackedFloat32Array, load_curve: PackedFloat32Array,
		seed_value: int) -> PackedFloat32Array:
	return _render(preset, rpm_curve, load_curve, seed_value, 0.0)


## Son doyum + ölçek: `calib` bankanın ortak ölçeği (calibrate). Bütün katmanlar aynı ölçekle → göreli düzey korunur.
static func finish(samples: PackedFloat32Array, preset: Dictionary, calib: float) -> PackedFloat32Array:
	var drive: float = float(preset["drive"])
	var k: float = calib * drive
	var post: float = 1.0 / drive
	for i: int in samples.size():
		samples[i] = tanh(samples[i] * k) * post
	return samples


## Ortak ölçek: en gür katmanın RMS'i son doyumdan önce 0,35 olsun.
static func calibrate(layers: Array) -> float:
	var top: float = 0.0
	for layer: PackedFloat32Array in layers:
		top = maxf(top, rms(layer))
	return 0.35 / maxf(top, 1e-6)


static func rms(samples: PackedFloat32Array) -> float:
	if samples.is_empty():
		return 0.0
	var acc: float = 0.0
	for s: float in samples:
		acc += s * s
	return sqrt(acc / float(samples.size()))


# --- Çekirdek ---------------------------------------------------------------------------------------------------

## `loop_seconds` > 0: sabit devirli döngü — devirden bağımsız tonlar (kompresör / dişli / invertör) döngüde tam tur
## olacak şekilde yuvarlanır.
static func _render(p: Dictionary, rpm_c: PackedFloat32Array, load_c: PackedFloat32Array, seed_value: int,
		loop_seconds: float) -> PackedFloat32Array:
	_ensure_noise()
	if p["layout"] == "ev":
		return _render_ev(p, rpm_c, load_c, seed_value, loop_seconds)
	var rate: float = float(p["rate"])
	var n: int = rpm_c.size()
	var geo: Dictionary = geometry(p["layout"])
	var cycle: float = geo["cycle"]
	var angles: PackedFloat32Array = geo["angles"]
	var fire_bank: PackedInt32Array = geo["banks"]
	var nbanks: int = geo["nbanks"]
	var ncyl: int = angles.size()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 17
	var idle: float = maxf(float(p["idle_rpm"]), 400.0)

	# Motorun SABİT özellikleri (bütün katmanlarda aynı motor): silindir gücü, manifold boyu
	var srng: RandomNumberGenerator = RandomNumberGenerator.new()
	srng.seed = 1000 + int(p["seed"])
	var cyl_gain: PackedFloat32Array = PackedFloat32Array()
	var head_delay: PackedFloat32Array = PackedFloat32Array()
	var imbalance: float = p["imbalance"]
	var header_len: float = p["header_len"]
	var header_spread: float = p["header_spread"]
	for c: int in ncyl:
		cyl_gain.append(1.0 - imbalance * srng.randf())
		var length: float = header_len * (1.0 + header_spread * srng.randf_range(-1.0, 1.0))
		head_delay.append(maxf(length, 0.05) / C_GAS * rate)
	# Taraf etkileşimi: aynı tarafa önceki darbeden bu yana geçen açı / ortalama → sık gelen darbe zayıf, seyrek güçlü
	var bank_gain: PackedFloat32Array = PackedFloat32Array()
	var bank_inter: float = p["bank_inter"]
	for k: int in ncyl:
		var same: int = 0
		for j: int in ncyl:
			same += 1 if fire_bank[j] == fire_bank[k] else 0
		var gap: float = cycle
		for step: int in range(1, ncyl + 1):
			var j: int = (k - step + ncyl) % ncyl
			if fire_bank[j] == fire_bank[k]:
				gap = fposmod(angles[k] - angles[j], cycle)
				gap = cycle if gap <= 0.0 else gap
				break
		var ratio: float = gap / (cycle / float(same))
		bank_gain.append(clampf(1.0 + bank_inter * 0.75 * (ratio - 1.0), 0.25, 1.9))

	# 1. ATEŞLEME olayları
	var ev_t: PackedFloat32Array = PackedFloat32Array()
	var ev_k: PackedInt32Array = PackedInt32Array()
	var ev_rpm: PackedFloat32Array = PackedFloat32Array()
	var ev_load: PackedFloat32Array = PackedFloat32Array()
	var theta: float = rng.randf() * cycle
	var k_next: int = 0
	var base: float = 0.0
	while k_next < ncyl and angles[k_next] < theta:
		k_next += 1
	if k_next == ncyl:
		k_next = 0
		base = cycle
	var next_angle: float = angles[k_next] + base
	for i: int in n:
		var dth: float = rpm_c[i] * 6.0 / rate
		theta += dth
		while theta >= next_angle:
			ev_t.append(float(i) - (theta - next_angle) / maxf(dth, 1e-6))
			ev_k.append(k_next)
			ev_rpm.append(rpm_c[i])
			ev_load.append(load_c[i])
			k_next += 1
			if k_next == ncyl:
				k_next = 0
				base += cycle
			next_angle = angles[k_next] + base

	# 2. DARBELER → taraf tamponları (manifold gecikmesi + iki ters yansıma)
	var banks: Array[PackedFloat32Array] = []
	for b: int in nbanks:
		var buf: PackedFloat32Array = PackedFloat32Array()
		buf.resize(n)
		buf.fill(0.0)
		banks.append(buf)
	var intake: PackedFloat32Array = PackedFloat32Array()
	intake.resize(n)
	intake.fill(0.0)
	var ticks: PackedFloat32Array = PackedFloat32Array()
	ticks.resize(n)
	ticks.fill(0.0)
	var knocks: PackedFloat32Array = PackedFloat32Array()
	knocks.resize(n)
	knocks.fill(0.0)
	var shapes: Array[PackedFloat32Array] = []
	for bucket: int in 5:
		shapes.append(_pulse_shape(float(p["sharpness"]) * lerpf(0.55, 1.0, float(bucket) / 4.0)))
	var soft_shape: PackedFloat32Array = _pulse_shape(0.15)
	var pulse_deg: float = p["pulse_deg"]
	var comb_var: float = p["comb_var"]
	var jitter: float = p["jitter"]
	var lope: float = p["lope"]
	var misfire: float = p["misfire"]
	var refl: float = p["header_refl"]
	var knock_on: bool = float(p["knock_db"]) > -59.0
	var valve_on: bool = float(p["valve_db"]) > -59.0
	var noise_ofs: int = rng.randi() % NOISE_SIZE
	var lope_phase: float = rng.randf() * TAU
	for e: int in ev_t.size():
		var k: int = ev_k[e]
		var e_rpm: float = ev_rpm[e]
		var e_load: float = ev_load[e]
		var fire_gap: float = cycle / float(ncyl) / (e_rpm * 6.0) * rate   # ortalama ateşleme aralığı (örnek)
		var lope_w: float = lope * clampf(1.0 - (e_rpm - idle) / (idle * 1.3), 0.0, 1.0)
		var gain: float = cyl_gain[k] * bank_gain[k] * (0.1 + 0.9 * e_load)
		gain *= maxf(0.05, 1.0 + comb_var * (1.0 + 1.2 * (1.0 - e_load)) * _gauss(rng))
		if lope_w > 0.0:
			# Kam örtüşmesi: rölantide bazı çevrimler zayıf (yavaş dalga + rastgele) → "lop-lop"
			lope_phase += 0.37 + rng.randf() * 0.2
			gain *= 1.0 - lope_w * (0.45 + 0.45 * sin(lope_phase)) * rng.randf()
		if rng.randf() < misfire * pow(1.0 - e_load, 2.0):
			gain *= 0.12
		var t: float = ev_t[e] + (jitter * 0.03 + lope_w * 0.05) * fire_gap * _gauss(rng)
		var length: float = pulse_deg / (e_rpm * 6.0) * rate
		var shape: PackedFloat32Array = shapes[clampi(roundi(e_load * 4.0), 0, 4)]
		var b: int = fire_bank[k]
		var at: float = t + head_delay[k]
		_add_pulse(banks[b], shape, at, length, gain)
		var echo: float = -refl
		for r: int in 2:
			at += 2.0 * head_delay[k]
			_add_pulse(banks[b], shape, at, length, gain * echo)
			echo *= -refl * 0.8
		# Emme: yarım çevrim önce açılan emme supabı (yumuşak darbe)
		_add_pulse(intake, soft_shape, t - cycle * 0.5 / (e_rpm * 6.0) * rate, length * 1.3, 0.3 + 0.7 * e_load)
		if valve_on:
			_add_burst(ticks, t + fire_gap * 0.31, 0.0008 * rate, 0.6 + 0.4 * rng.randf(), noise_ofs + e * 97)
			_add_burst(ticks, t + fire_gap * 0.77, 0.0008 * rate, 0.4 + 0.4 * rng.randf(), noise_ofs + e * 131)
		if knock_on:
			_add_burst(knocks, t + 0.0005 * rate, 0.0028 * rate, gain * (1.25 - 0.55 * e_load), noise_ofs + e * 53)

	# Ham darbe toplamı: akış gürültüsünün zarfı ve blok çınlamasının kaynağı
	var raw_sum: PackedFloat32Array = PackedFloat32Array()
	raw_sum.resize(n)
	raw_sum.fill(0.0)
	for b: int in nbanks:
		var buf: PackedFloat32Array = banks[b]
		for i: int in n:
			raw_sum[i] += buf[i]

	var load_avg: float = 0.0
	for i: int in range(0, n, 64):
		load_avg += load_c[i]
	load_avg /= float(ceili(float(n) / 64.0))

	# 3–6. KOLEKTÖR, BORU, AKIŞ, SUSTURUCU
	var out: PackedFloat32Array = _exhaust(banks, raw_sum, p, load_avg, noise_ofs)

	# 7. EK katmanlar
	var intake_gain: float = db_to_linear(float(p["intake_db"])) * 2.5
	if intake_gain > 0.004:
		var hiss: PackedFloat32Array = PackedFloat32Array()
		hiss.resize(n)
		for i: int in n:
			hiss[i] = intake[i] * (0.35 + _noise[(noise_ofs + 7919 + i) & (NOISE_SIZE - 1)])
		hiss = _biquad(hiss, _bq_bandpass(float(p["intake_hz"]), float(p["intake_q"]), rate))
		for i: int in n:
			out[i] += hiss[i] * intake_gain * (0.25 + 0.75 * load_c[i])
	var block_gain: float = db_to_linear(float(p["block_db"])) * 6.0
	if block_gain > 0.004:
		var ring: PackedFloat32Array = PackedFloat32Array()
		ring.resize(n)
		var last: float = 0.0
		for i: int in n:
			ring[i] = raw_sum[i] - last   # geçişler (keskin kenar) çınlatır
			last = raw_sum[i]
		ring = _biquad(ring, _bq_bandpass(float(p["block_hz"]), 5.0, rate))
		for i: int in n:
			out[i] += ring[i] * block_gain
	if valve_on:
		ticks = _biquad(ticks, _bq_highpass(3500.0, 0.7, rate))
		var valve_gain: float = db_to_linear(float(p["valve_db"])) * 1.5
		for i: int in n:
			out[i] += ticks[i] * valve_gain
	if knock_on:
		knocks = _biquad(knocks, _bq_bandpass(2700.0, 1.1, rate))
		var knock_gain: float = db_to_linear(float(p["knock_db"])) * 2.0
		for i: int in n:
			out[i] += knocks[i] * knock_gain
	_add_whine(out, rpm_c, load_c, float(p["sc_ratio"]), db_to_linear(float(p["sc_db"])) * 0.4, 0.35, rate,
		loop_seconds, rng.randf())
	_add_whine(out, rpm_c, load_c, float(p["gear_order"]), db_to_linear(float(p["gear_db"])) * 0.4, 0.15, rate,
		loop_seconds, rng.randf())

	# 8. DÜZEY: devirle yükselme + gaz kesik kısıklığı (eğri boyunca 64 örnekte bir hesaplanır)
	_apply_level(out, p, rpm_c, load_c, idle)
	return out


## Bir taraf tamponuna darbe ekler (kesirli başlangıç; şekil tablosu doğrusal aradeğerle).
static func _add_pulse(buf: PackedFloat32Array, shape: PackedFloat32Array, start: float, length: float,
		gain: float) -> void:
	var n: int = buf.size()
	var first: int = maxi(ceili(start), 0)
	var last: int = mini(int(start + length), n - 1)
	if last < first:
		return
	var scale: float = float(SHAPE_SIZE - 1) / length
	for j: int in range(first, last + 1):
		var pos: float = (float(j) - start) * scale
		var a: int = int(pos)
		if a >= SHAPE_SIZE - 1:
			break
		buf[j] += gain * lerpf(shape[a], shape[a + 1], pos - float(a))


## Kısa gürültü patlaması (supap tıkı, dizel tıkırtısı): üstel sönümlü.
static func _add_burst(buf: PackedFloat32Array, start: float, length: float, gain: float, noise_at: int) -> void:
	var n: int = buf.size()
	var first: int = maxi(ceili(start), 0)
	var span: int = int(length * 3.0)
	for j: int in range(first, mini(first + span, n)):
		var x: float = float(j - first) / length
		buf[j] += gain * exp(-x) * _noise[(noise_at + j) & (NOISE_SIZE - 1)]


## Darbe şekli: ani yükselme (sertlik), üstel sönme, son çeyrekte yumuşak kapanış; tepe 1.
static func _pulse_shape(sharpness: float) -> PackedFloat32Array:
	var attack: float = lerpf(0.14, 0.004, clampf(sharpness, 0.0, 1.0))
	var decay: float = lerpf(0.38, 0.17, clampf(sharpness, 0.0, 1.0))
	var table: PackedFloat32Array = PackedFloat32Array()
	table.resize(SHAPE_SIZE)
	var top: float = 1e-6
	for i: int in SHAPE_SIZE:
		var x: float = float(i) / float(SHAPE_SIZE - 1)
		var v: float = (1.0 - exp(-x / attack)) * exp(-x / decay)
		if x > 0.72:
			v *= 0.5 + 0.5 * cos(PI * (x - 0.72) / 0.28)
		table[i] = v
		top = maxf(top, v)
	for i: int in SHAPE_SIZE:
		table[i] /= top
	return table


## 3–6. kolektör doyumu, X-boru, boru rezonansı (taraf başına), akış gürültüsü, susturucu.
static func _exhaust(banks: Array[PackedFloat32Array], raw_sum: PackedFloat32Array, p: Dictionary, load_avg: float,
		noise_ofs: int) -> PackedFloat32Array:
	var rate: float = float(p["rate"])
	var n: int = raw_sum.size()
	var nbanks: int = banks.size()
	var drive: float = p["collector_drive"]
	for b: int in nbanks:
		var buf: PackedFloat32Array = banks[b]
		for i: int in n:
			buf[i] = tanh(buf[i] * drive) / drive
		banks[b] = buf
	if nbanks == 2:
		var mix: float = float(p["crossover"]) * 0.5
		var left: PackedFloat32Array = banks[0]
		var right: PackedFloat32Array = banks[1]
		for i: int in n:
			var l: float = left[i]
			var r: float = right[i]
			left[i] = l * (1.0 - mix) + r * mix
			right[i] = r * (1.0 - mix) + l * mix
		banks[0] = left
		banks[1] = right
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	out.fill(0.0)
	var feedback: float = -float(p["pipe_reso"])
	var damp: float = 1.0 - float(p["pipe_damp"]) * 0.85
	for b: int in nbanks:
		var side: float = 0.0 if nbanks == 1 else (-1.0 if b == 0 else 1.0)
		var length: float = float(p["pipe_len"]) * (1.0 + float(p["bank_offset"]) * side)
		var delay: int = maxi(1, roundi(2.0 * length / C_GAS * rate))
		var x: PackedFloat32Array = banks[b]
		var y: PackedFloat32Array = PackedFloat32Array()
		y.resize(n)
		var lp: float = 0.0
		for i: int in n:
			var back: float = y[i - delay] if i >= delay else 0.0
			lp += (back - lp) * damp
			y[i] = x[i] + feedback * lp
		for i: int in n:
			out[i] += y[i]
	# AKIŞ: darbe zarfı × gürültü
	var rasp: float = p["rasp"]
	var flow: float = p["flow_noise"]
	if rasp > 0.0 or flow > 0.0:
		var top: float = 1e-6
		for i: int in n:
			top = maxf(top, absf(raw_sum[i]))
		var hi: PackedFloat32Array = PackedFloat32Array()
		hi.resize(n)
		var mid: PackedFloat32Array = PackedFloat32Array()
		mid.resize(n)
		for i: int in n:
			var env: float = absf(raw_sum[i]) / top
			hi[i] = env * _noise[(noise_ofs + i) & (NOISE_SIZE - 1)]
			mid[i] = env * _noise[(noise_ofs + 33331 + i) & (NOISE_SIZE - 1)]
		hi = _biquad(hi, _bq_highpass(1900.0, 0.7, rate))
		mid = _biquad(mid, _bq_bandpass(650.0, 0.6, rate))
		var level: float = rms(out) * 3.0
		for i: int in n:
			out[i] += (hi[i] * rasp * 1.4 + mid[i] * flow) * level
	# SUSTURUCU (gaz kesikte daha kapalı)
	var cut: float = float(p["muffler_cut"]) * lerpf(float(p["off_muffle"]), 1.0, clampf(load_avg * 1.6, 0.0, 1.0))
	cut *= 1.0 - 0.25 * float(p["turbo"])   # turbo egzozu boğar
	out = _biquad(out, _bq_lowpass(cut, float(p["muffler_q"]), rate))
	out = _biquad(out, _bq_peak(float(p["chamber_hz"]), 1.6, float(p["chamber_db"]), rate))
	out = _biquad(out, _bq_lowshelf(110.0, float(p["bass_db"]), rate))
	out = _biquad(out, _bq_highpass(float(p["hp_hz"]), 0.71, rate))
	return out


## Devre kilitli vınlama (kompresör, düz dişli): `order` × krank frekansı, üç harmonik; yükle güçlenir.
static func _add_whine(out: PackedFloat32Array, rpm_c: PackedFloat32Array, load_c: PackedFloat32Array, order: float,
		gain: float, floor_gain: float, rate: float, loop_seconds: float, phase0: float) -> void:
	if gain < 0.0011:
		return
	var n: int = out.size()
	var phase: float = phase0
	var quant: bool = loop_seconds > 0.0
	for i: int in n:
		var f: float = rpm_c[i] / 60.0 * order
		if quant:
			f = roundf(f * loop_seconds) / loop_seconds
		phase = fposmod(phase + f / rate, 1.0)
		var v: float = sin(TAU * phase) * _band_safe(f, rate) + 0.35 * sin(TAU * 2.0 * phase) * _band_safe(2.0 * f, rate) \
			+ 0.15 * sin(TAU * 3.0 * phase) * _band_safe(3.0 * f, rate)
		out[i] += v * gain * (floor_gain + (1.0 - floor_gain) * load_c[i])


static func _apply_level(out: PackedFloat32Array, p: Dictionary, rpm_c: PackedFloat32Array,
		load_c: PackedFloat32Array, idle: float) -> void:
	var red: float = maxf(float(p["redline_rpm"]), idle + 100.0)
	var slope: float = p["rpm_slope_db"]
	var off_db: float = p["off_db"]
	var off_load: float = p["off_load"]
	var n: int = out.size()
	var gain: float = 1.0
	for i: int in n:
		if i % 64 == 0:
			var r: float = clampf((rpm_c[i] - idle) / (red - idle), 0.0, 1.0)
			var l: float = clampf((load_c[i] - off_load) / maxf(1.0 - off_load, 0.01), 0.0, 1.0)
			gain = db_to_linear(slope * (r - 1.0) + off_db * (1.0 - l))
		out[i] *= gain


# --- Elektrik ---------------------------------------------------------------------------------------------------

## ELEKTRİK (2026-11-02 ikinci tur, kullanıcı: "elektrikliler aşırı ince"). Devirle yükselen tonlar `ev_pitch` ile
## ölçeklenir; altta sese ağırlık veren katmanlar:
##   GÖVDE    — elektriksel frekans (devir × kutup × ev_pitch) ve 2. / 3. harmoniği: kalın motor uğultusu.
##   AKOR     — fütüristik sürüş sesi: kök + beşli + oktav, her biri iki hafif akort farklı testere (dalga tablosu),
##              sıcak alçak geçiren; kök devirle 1 → 3,5 kat.
##   YOL      — hızla açılan, hızla parlaklaşan süzülmüş gürültü (lastik + rüzgâr).
##   VINLAMA  — motorun 6. / 12. mertebesi + redüktör dişlisi + sabit invertör tonu; hepsi `ev_tone_hz` ile süzülür
##              (iki geçiş: tiz uçlar keskinleşmesin).
static func _render_ev(p: Dictionary, rpm_c: PackedFloat32Array, load_c: PackedFloat32Array, seed_value: int,
		loop_seconds: float) -> PackedFloat32Array:
	_ensure_saw()
	var rate: float = float(p["rate"])
	var n: int = rpm_c.size()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 23
	var k: float = p["ev_pitch"]
	var poles: float = float(p["ev_poles"])
	var teeth: float = float(p["ev_gear_teeth"])
	var red: float = maxf(float(p["redline_rpm"]), 1000.0)
	var body_gain: float = db_to_linear(float(p["ev_body_db"]))
	var drone_gain: float = db_to_linear(float(p["ev_drone_db"])) if float(p["ev_drone_db"]) > -59.0 else 0.0
	var road_gain: float = db_to_linear(float(p["ev_road_db"])) if float(p["ev_road_db"]) > -59.0 else 0.0
	var whine: float = db_to_linear(float(p["ev_whine_db"]))
	var gear: float = db_to_linear(float(p["ev_gear_db"]))
	var carrier: float = db_to_linear(float(p["ev_carrier_db"]))
	var drone_root: float = p["ev_drone_hz"]
	var fc: float = p["ev_carrier_hz"]
	var quant: bool = loop_seconds > 0.0
	if quant:
		fc = roundf(fc * loop_seconds) / loop_seconds
	var noise_ofs: int = rng.randi() % NOISE_SIZE
	var body_phase: float = rng.randf()
	var whine_phase: float = rng.randf()
	var gear_phase: float = rng.randf()
	var carrier_phase: float = rng.randf()
	## Akor: [oran, akort farkı] — kök, beşli, oktav × iki ses
	var voices: PackedFloat32Array = PackedFloat32Array([1.0, 0.997, 1.5, 1.504, 2.0, 2.006])
	var voice_amp: PackedFloat32Array = PackedFloat32Array([1.0, 1.0, 0.55, 0.55, 0.4, 0.4])
	var drone_phase: PackedFloat32Array = PackedFloat32Array()
	for v: int in voices.size():
		drone_phase.append(rng.randf())
	var low: PackedFloat32Array = PackedFloat32Array()
	low.resize(n)
	var drone: PackedFloat32Array = PackedFloat32Array()
	drone.resize(n)
	var hi: PackedFloat32Array = PackedFloat32Array()
	hi.resize(n)
	var road_state: float = 0.0
	var road_state2: float = 0.0
	for i: int in n:
		var rot: float = rpm_c[i] / 60.0
		var l: float = load_c[i]
		var norm: float = clampf(rpm_c[i] / red, 0.0, 1.0)
		var fade_in: float = clampf(rpm_c[i] / 900.0, 0.0, 1.0)
		# GÖVDE
		var fb: float = rot * poles * k
		if quant:
			fb = roundf(fb * loop_seconds) / loop_seconds
		body_phase = fposmod(body_phase + fb / rate, 1.0)
		var body: float = sin(TAU * body_phase) * 0.6 + sin(TAU * 2.0 * body_phase) * 0.8 * _band_safe(2.0 * fb, rate) \
			+ sin(TAU * 3.0 * body_phase) * 0.35 * _band_safe(3.0 * fb, rate)
		low[i] = body * body_gain * (0.5 + 0.5 * l) * fade_in
		# AKOR
		if drone_gain > 0.0:
			var root: float = drone_root * (1.0 + 2.5 * norm)
			var d: float = 0.0
			for v: int in voices.size():
				var f: float = root * voices[v]
				if quant:
					f = roundf(f * loop_seconds) / loop_seconds
				drone_phase[v] = fposmod(drone_phase[v] + f / rate, 1.0)
				var pos: float = drone_phase[v] * float(SAW_SIZE)
				var a: int = int(pos) % SAW_SIZE   # 32 bitte faz 1,0'a yuvarlanabilir
				d += voice_amp[v] * lerpf(_saw[a], _saw[(a + 1) % SAW_SIZE], pos - floorf(pos))
			drone[i] = d * drone_gain * (0.45 + 0.55 * l) * (0.4 + 0.6 * fade_in)
		# YOL
		if road_gain > 0.0:
			var cut: float = 0.03 + 0.09 * norm
			road_state += (_noise[(noise_ofs + i) & (NOISE_SIZE - 1)] - road_state) * cut
			road_state2 += (road_state - road_state2) * cut
			low[i] += road_state2 * 3.0 * road_gain * norm
		# VINLAMA (süzülecek)
		var fw: float = rot * poles * k * 6.0
		var fg: float = rot * teeth * k
		if quant:
			fw = roundf(fw * loop_seconds) / loop_seconds
			fg = roundf(fg * loop_seconds) / loop_seconds
		whine_phase = fposmod(whine_phase + fw / rate, 1.0)
		gear_phase = fposmod(gear_phase + fg / rate, 1.0)
		carrier_phase = fposmod(carrier_phase + fc / rate, 1.0)
		var w: float = (sin(TAU * whine_phase) * _band_safe(fw, rate)
			+ 0.4 * sin(TAU * 2.0 * whine_phase) * _band_safe(2.0 * fw, rate)) * whine
		w += (sin(TAU * gear_phase) * _band_safe(fg, rate) + 0.3 * sin(TAU * 2.0 * gear_phase) * _band_safe(2.0 * fg, rate)) * gear
		hi[i] = w * (0.3 + 0.7 * l) * fade_in + sin(TAU * carrier_phase) * carrier * (0.25 + 0.75 * l) * _band_safe(fc, rate)
	var tone: float = p["ev_tone_hz"]
	hi = _biquad(hi, _bq_lowpass(tone, 0.71, rate))
	hi = _biquad(hi, _bq_lowpass(tone * 1.2, 0.71, rate))
	if drone_gain > 0.0:
		drone = _biquad(drone, _bq_lowpass(minf(tone * 0.5, 1400.0), 1.3, rate))
	low = _biquad(low, _bq_highpass(float(p["hp_hz"]), 0.71, rate))
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	for i: int in n:
		out[i] = low[i] + drone[i] + hi[i]
	_apply_level(out, p, rpm_c, load_c, 0.0)
	return out


# --- Tek seferlik sesler ----------------------------------------------------------------------------------------

## MARŞ: marş motoru motoru çevirir (sıkıştırma darbeleri, devir dalgalanır), motor yakalar, devir fırlar, rölantiye
## oturur. [örnekler (doğrusal), rölantiye oturduğu an (sn)]. Elektrikte kısa "hazır" vınlaması.
static func render_start(p: Dictionary, seed_value: int) -> Array:
	var rate: float = float(p["rate"])
	var idle: float = maxf(float(p["idle_rpm"]), 400.0)
	if p["layout"] == "ev":
		var ev_len: int = int(0.9 * rate)
		var ev_rpm: PackedFloat32Array = PackedFloat32Array()
		var ev_load: PackedFloat32Array = PackedFloat32Array()
		for i: int in ev_len:
			var t: float = float(i) / rate
			ev_rpm.append(2600.0 * sin(PI * clampf(t / 0.8, 0.0, 1.0)))
			ev_load.append(0.35)
		var ev: PackedFloat32Array = _render(p, ev_rpm, ev_load, seed_value, 0.0)
		return [_fade_edges(ev, rate, 0.01, 0.1), 0.9]
	var crank_s: float = p["crank_s"]
	var crank_rpm: float = p["crank_rpm"]
	var flare: float = idle * float(p["flare"])
	var catch_s: float = 0.28
	var settle_s: float = 1.1
	var tail_s: float = 0.4
	var total_s: float = 0.08 + crank_s + catch_s + settle_s + tail_s
	var n: int = int(total_s * rate)
	var rpm_c: PackedFloat32Array = PackedFloat32Array()
	rpm_c.resize(n)
	var load_c: PackedFloat32Array = PackedFloat32Array()
	load_c.resize(n)
	var off_load: float = p["off_load"]
	var cylinders: float = float((geometry(p["layout"])["angles"] as PackedFloat32Array).size())
	var t_catch: float = 0.08 + crank_s
	for i: int in n:
		var t: float = float(i) / rate
		if t < 0.08:
			rpm_c[i] = crank_rpm * t / 0.08
			load_c[i] = 0.0
		elif t < t_catch:
			# Her sıkıştırmada marş yavaşlar: ateşleme frekansında devir dalgası
			var wobble: float = sin(TAU * (t - 0.08) * crank_rpm / 120.0 * cylinders)
			rpm_c[i] = crank_rpm * (1.0 + 0.16 * wobble)
			load_c[i] = 0.0
		elif t < t_catch + catch_s:
			var x: float = (t - t_catch) / catch_s
			rpm_c[i] = lerpf(crank_rpm, flare, 1.0 - pow(1.0 - x, 2.0))
			load_c[i] = 0.85
		else:
			var x: float = (t - t_catch - catch_s) / settle_s
			rpm_c[i] = idle + (flare - idle) * exp(-4.0 * x)
			load_c[i] = lerpf(0.5, off_load, clampf(x * 1.8, 0.0, 1.0))
	var out: PackedFloat32Array = _render(p, rpm_c, load_c, seed_value, 0.0)
	# Marş motoru: dişli frekansında vızıltı (komütatör harmonikleri) + dişli gürültüsü, çevirme boyunca
	_ensure_noise()
	var starter: float = db_to_linear(float(p["starter_db"])) * rms(out) * 4.0
	var phase: float = 0.0
	var buzz: PackedFloat32Array = PackedFloat32Array()
	buzz.resize(n)
	for i: int in n:
		var t: float = float(i) / rate
		var env: float = clampf(t / 0.04, 0.0, 1.0) * clampf((t_catch + 0.06 - t) / 0.06, 0.0, 1.0)
		if env <= 0.0:
			buzz[i] = 0.0
			continue
		phase = fposmod(phase + rpm_c[i] / 60.0 * 11.0 / rate, 1.0)
		var v: float = 0.0
		for h: int in range(1, 9):
			v += sin(TAU * phase * float(h)) / float(h)
		v += 0.6 * _noise[i & (NOISE_SIZE - 1)] * (0.5 + 0.5 * sin(TAU * phase))
		buzz[i] = v * env
	buzz = _biquad(buzz, _bq_bandpass(520.0, 0.8, rate))
	for i: int in n:
		out[i] += buzz[i] * starter
	# Kuyruk (rölantide) söner: oynatıcı aynı anda rölanti döngüsünü açar → dikişsiz geçiş
	return [_fade_edges(out, rate, 0.005, tail_s * 0.9), total_s - tail_s]


## KONTAK KAPATMA: devir rölantiden düşer, son birkaç sıkıştırma, sus.
static func render_stop(p: Dictionary, seed_value: int) -> PackedFloat32Array:
	var rate: float = float(p["rate"])
	var idle: float = maxf(float(p["idle_rpm"]), 400.0)
	var ev: bool = p["layout"] == "ev"
	var span: float = 0.9 if ev else 0.55
	var n: int = int((span + 0.15) * rate)
	var rpm_c: PackedFloat32Array = PackedFloat32Array()
	rpm_c.resize(n)
	var load_c: PackedFloat32Array = PackedFloat32Array()
	load_c.resize(n)
	var start_rpm: float = 1800.0 if ev else idle
	for i: int in n:
		var x: float = clampf(float(i) / rate / span, 0.0, 1.0)
		rpm_c[i] = maxf(start_rpm * (1.0 - x * x), 60.0)
		load_c[i] = float(p["off_load"]) * (1.0 - x) if not ev else 0.2
	var out: PackedFloat32Array = _render(p, rpm_c, load_c, seed_value, 0.0)
	return _fade_edges(out, rate, 0.02, 0.15)


## EGZOZ PATLAMASI: keskin darbe + kalın "güm", aracın kendi borusu ve (daha açık) susturucusundan geçer.
static func render_pop(p: Dictionary, variant: int) -> PackedFloat32Array:
	_ensure_noise()
	var rate: float = float(p["rate"])
	var n: int = int(0.22 * rate)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4400 + variant * 31 + int(p["seed"])
	var tone: float = p["pop_tone"]
	var src: PackedFloat32Array = PackedFloat32Array()
	src.resize(n)
	var thump_hz: float = lerpf(55.0, 110.0, tone) * rng.randf_range(0.85, 1.15)
	var crack_decay: float = lerpf(0.004, 0.0015, tone) * rate
	var ofs: int = rng.randi() % NOISE_SIZE
	for i: int in n:
		var t: float = float(i) / rate
		var crack: float = _noise[(ofs + i) & (NOISE_SIZE - 1)] * exp(-float(i) / crack_decay) * 1.6
		var thump: float = sin(TAU * thump_hz * t) * exp(-t * 26.0) * (1.0 - tone * 0.5)
		var spike: float = exp(-float(i) / (0.0006 * rate)) * 2.5
		src[i] = crack + thump + spike
	var geo: Dictionary = geometry(p["layout"])
	var banks: Array[PackedFloat32Array] = []
	for b: int in int(geo["nbanks"]):
		banks.append(src.duplicate())
	var open: Dictionary = p.duplicate()
	open["muffler_cut"] = minf(float(p["muffler_cut"]) * lerpf(1.6, 4.0, tone), rate * 0.45)
	open["turbo"] = 0.0
	open["rasp"] = 0.0
	open["flow_noise"] = 0.0
	var out: PackedFloat32Array = _exhaust(banks, src, open, 1.0, ofs)
	return _normalize(_fade_edges(out, rate, 0.0005, 0.04), 0.9)


## BLOW-OFF: basınç boşaltma — süzülmüş gürültü, perdesi düşen bant; "flutter" türünde ~20 Hz kesik kesik.
static func render_blowoff(p: Dictionary) -> PackedFloat32Array:
	_ensure_noise()
	var rate: float = float(p["rate"])
	var flutter: bool = p["blowoff_kind"] == "flutter"
	var seconds: float = 0.55 if flutter else 0.45
	var n: int = int(seconds * rate)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var x1: float = 0.0
	var x2: float = 0.0
	var y1: float = 0.0
	var y2: float = 0.0
	var c: PackedFloat32Array = PackedFloat32Array()
	for i: int in n:
		var t: float = float(i) / rate
		if i % 32 == 0:
			var f: float = lerpf(3600.0, 1500.0, clampf(t / seconds, 0.0, 1.0)) if not flutter else lerpf(1400.0, 700.0, t / seconds)
			c = _bq_bandpass(f, 1.6 if not flutter else 2.2, rate)
		var xi: float = _noise[(i * 3) & (NOISE_SIZE - 1)]
		var yi: float = c[0] * xi + c[1] * x1 + c[2] * x2 - c[3] * y1 - c[4] * y2
		x2 = x1
		x1 = xi
		y2 = y1
		y1 = yi
		var env: float = clampf(t / 0.012, 0.0, 1.0) * exp(-t * (5.0 if not flutter else 4.0))
		if flutter:
			var rate_hz: float = lerpf(24.0, 14.0, t / seconds)
			env *= pow(maxf(0.0, sin(TAU * rate_hz * t)), 2.0)
		out[i] = yi * env
	return _normalize(_fade_edges(out, rate, 0.002, 0.05), 0.85)


## TURBO ISLIĞI döngüsü (oyunda perdesi basınçla 0,35–1,0 arası oynar): ton + 2. harmonik + dar bant gürültü.
static func render_whistle(p: Dictionary) -> PackedFloat32Array:
	_ensure_noise()
	var rate: float = float(p["rate"])
	var seconds: float = 0.5
	var n: int = int(seconds * rate)
	var f: float = roundf(float(p["whistle_hz"]) * seconds) / seconds
	var noise: PackedFloat32Array = PackedFloat32Array()
	noise.resize(n + n)
	for i: int in n + n:
		noise[i] = _noise[(i * 5 + 11) & (NOISE_SIZE - 1)]
	noise = _biquad(noise, _bq_bandpass(f, 12.0, rate))
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var fade: int = int(0.05 * rate)
	for i: int in n:
		var t: float = float(i) / rate
		var hiss: float = noise[n + i]
		if i < fade:   # gürültü döngü dikişi
			var w: float = float(i) / float(fade)
			hiss = noise[n + i] * w + noise[i] * (1.0 - w)
		var h2: float = sin(TAU * 2.0 * f * t) * 0.12 if 2.0 * f < rate * 0.45 else 0.0
		out[i] = sin(TAU * f * t) * 0.7 + h2 + hiss * 2.5
	return _normalize(out, 0.8)


# --- Yardımcılar ------------------------------------------------------------------------------------------------

## İş parçacıklarından önce ana iş parçacığında bir kez çağrılmalı (paylaşılan gürültü / dalga tabloları).
static func prepare() -> void:
	_ensure_noise()
	_ensure_saw()


static func _ensure_saw() -> void:
	if _saw.size() == SAW_SIZE:
		return
	var table: PackedFloat32Array = PackedFloat32Array()
	table.resize(SAW_SIZE)
	var top: float = 1e-6
	for i: int in SAW_SIZE:
		var x: float = TAU * float(i) / float(SAW_SIZE)
		var v: float = 0.0
		for h: int in range(1, 21):
			v += sin(x * float(h)) / float(h)
		table[i] = v
		top = maxf(top, absf(v))
	for i: int in SAW_SIZE:
		table[i] /= top
	_saw = table


static func _ensure_noise() -> void:
	if _noise.size() == NOISE_SIZE:
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 90210
	var table: PackedFloat32Array = PackedFloat32Array()
	table.resize(NOISE_SIZE)
	for i: int in NOISE_SIZE:
		table[i] = rng.randf_range(-1.0, 1.0)
	_noise = table


## Nyquist'e yaklaşan tonu yumuşakça kısar (0,38–0,45 × örnekleme): katlanma (aliasing) olmasın, çıt da olmasın.
static func _band_safe(f: float, rate: float) -> float:
	return clampf((0.45 * rate - f) / (0.07 * rate), 0.0, 1.0)


static func _gauss(rng: RandomNumberGenerator) -> float:
	return (rng.randf() + rng.randf() + rng.randf() - 1.5) * 1.15


static func _fade_edges(samples: PackedFloat32Array, rate: float, fade_in: float, fade_out: float) -> PackedFloat32Array:
	var n: int = samples.size()
	var a: int = mini(int(fade_in * rate), n)
	for i: int in a:
		samples[i] *= float(i) / float(a)
	var b: int = mini(int(fade_out * rate), n)
	for i: int in b:
		samples[n - 1 - i] *= float(i) / float(b)
	return samples


static func _normalize(samples: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var top: float = 1e-6
	for s: float in samples:
		top = maxf(top, absf(s))
	var g: float = peak / top
	for i: int in samples.size():
		samples[i] *= g
	return samples


## Biquad (RBJ): [b0, b1, b2, a1, a2] (a0'a bölünmüş).
static func _biquad(x: PackedFloat32Array, c: PackedFloat32Array) -> PackedFloat32Array:
	var b0: float = c[0]
	var b1: float = c[1]
	var b2: float = c[2]
	var a1: float = c[3]
	var a2: float = c[4]
	var x1: float = 0.0
	var x2: float = 0.0
	var y1: float = 0.0
	var y2: float = 0.0
	for i: int in x.size():
		var xi: float = x[i]
		var yi: float = b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = xi
		y2 = y1
		y1 = yi
		x[i] = yi
	return x


static func _bq(b0: float, b1: float, b2: float, a0: float, a1: float, a2: float) -> PackedFloat32Array:
	return PackedFloat32Array([b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0])


static func _w0(f: float, rate: float) -> float:
	return TAU * clampf(f, 5.0, rate * 0.45) / rate


static func _bq_lowpass(f: float, q: float, rate: float) -> PackedFloat32Array:
	var w: float = _w0(f, rate)
	var alpha: float = sin(w) / (2.0 * q)
	var c: float = cos(w)
	return _bq((1.0 - c) * 0.5, 1.0 - c, (1.0 - c) * 0.5, 1.0 + alpha, -2.0 * c, 1.0 - alpha)


static func _bq_highpass(f: float, q: float, rate: float) -> PackedFloat32Array:
	var w: float = _w0(f, rate)
	var alpha: float = sin(w) / (2.0 * q)
	var c: float = cos(w)
	return _bq((1.0 + c) * 0.5, -(1.0 + c), (1.0 + c) * 0.5, 1.0 + alpha, -2.0 * c, 1.0 - alpha)


static func _bq_bandpass(f: float, q: float, rate: float) -> PackedFloat32Array:
	var w: float = _w0(f, rate)
	var alpha: float = sin(w) / (2.0 * q)
	var c: float = cos(w)
	return _bq(alpha, 0.0, -alpha, 1.0 + alpha, -2.0 * c, 1.0 - alpha)


static func _bq_peak(f: float, q: float, gain_db: float, rate: float) -> PackedFloat32Array:
	var w: float = _w0(f, rate)
	var alpha: float = sin(w) / (2.0 * q)
	var c: float = cos(w)
	var a: float = pow(10.0, gain_db / 40.0)
	return _bq(1.0 + alpha * a, -2.0 * c, 1.0 - alpha * a, 1.0 + alpha / a, -2.0 * c, 1.0 - alpha / a)


static func _bq_lowshelf(f: float, gain_db: float, rate: float) -> PackedFloat32Array:
	var w: float = _w0(f, rate)
	var c: float = cos(w)
	var a: float = pow(10.0, gain_db / 40.0)
	var alpha: float = sin(w) * 0.5 * sqrt(2.0)
	var sa: float = 2.0 * sqrt(a) * alpha
	return _bq(a * ((a + 1.0) - (a - 1.0) * c + sa), 2.0 * a * ((a - 1.0) - (a + 1.0) * c),
		a * ((a + 1.0) - (a - 1.0) * c - sa), (a + 1.0) + (a - 1.0) * c + sa, -2.0 * ((a - 1.0) + (a + 1.0) * c),
		(a + 1.0) + (a - 1.0) * c - sa)
