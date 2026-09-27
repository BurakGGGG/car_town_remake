class_name DragRaceSim
## DRAG YARIŞI 2.0 — GERÇEK ŞANZIMAN MODELİ (sahneden bağımsız saf hesap; ekran onu yalnızca
## ÇİZER). Tasarımın gerekçesi ve kaynakları: docs/drag_racing_2_design.md
##
## MODEL
##   tekerlek_devri = hız / (2π·r) · 60
##   motor_devri    = tekerlek_devri · diferansiyel · oran[vites]     (idle…redline arası)
##   tork           = tork_eğrisi(devir) · tepe_tork                   (Nm)
##   kuvvet         = tork · oran · diferansiyel · verim / r           (N)
##   direnç         = ½·ρ·Cd·A·v² + Crr·m·g
##   ivme           = (kuvvet − direnç) / kütle
## Çekiş limiti aşılırsa PATİNAJ: fazla kuvvet boşa gider, motor devri hızdan ayrılır.
##
## VİTES gerçek bir olaydır: `shift_time` boyunca çekiş kesilir, sonra motor devri YENİ oranla
## hesaplanır — düşüş oran farkının sonucudur, sabit bir katsayı DEĞİL. Kalite yalnızca geçiş
## süresini ve devrin nereye düştüğünü belirler; "iyi vites bonusu" gibi bir ivme çarpanı YOKTUR.
##
## Araç verisi cars.json'daki "race" bloğundan + sınıf/kategori/ölçülerden TÜRETİLİR
## (`EngineSpec.derive`); hiçbir yerde araç id'si elle yazılmaz.

## Yarış mesafesi (m).
const DISTANCE: float = 300.0
## Bir aracın olabileceği en fazla vites sayısı (UI ve test döngüleri için üst sınır).
const GEARS: int = 6
const SHIFTS: int = GEARS - 1

## KADRAN SANATI (ui/hud/art/dial_band.png) ile BİREBİR: yay -165°..-15° arası çizilmiş, yeşil
## dilim %46-54'te, sağdaki kırmızı %75'te başlıyor. Bu üç sayı ÖLÇÜLDÜ. Motor devri bu yaya
## PARÇALI olarak eşlenir: her aracın KENDİ optimum vites devri yeşil dilime denk gelir, yani
## kadran "şu an vites at" göstergesidir — doğrusal bir devirölçer değil (bkz. tasarım notu J).
const GAUGE_GREEN_START: float = 0.46
const GAUGE_GREEN_END: float = 0.54
const GAUGE_RED_START: float = 0.75

## Vites kalitesi.
enum Shift { MISS, EARLY, GOOD, PERFECT, LATE, REDLINE }
## Kalite pencereleri (optimum devre göre oran): |Δ| ≤ PERFECT → kusursuz, ≤ GOOD → iyi.
const PERFECT_BAND: float = 0.025
const GOOD_BAND: float = 0.075
## Bu kadar erken atmak "ıskalama"dır (optimumun bu oranı altı).
const MISS_BAND: float = 0.30
## Geçiş süreleri (sn) — tek fiziksel ceza budur.
const SHIFT_TIME: Dictionary = {
	Shift.PERFECT: 0.085, Shift.GOOD: 0.110, Shift.EARLY: 0.155,
	Shift.LATE: 0.150, Shift.REDLINE: 0.185, Shift.MISS: 0.215,
}

## Kalkış. Optimum devir bandı tepe torkun etrafındadır; altı bocalar, üstü patinaj yapar.
const LAUNCH_PERFECT_BAND: float = 0.06   # optimumun ±%6'sı kusursuz
const LAUNCH_GOOD_BAND: float = 0.16
## Bog: debriyaj kavrarken düşük devirde motorun verebildiği tork oranı (en kötü hâl).
const BOG_FLOOR: float = 0.45
## Debriyaj kayması bu kadar sürer (sn): motor devri bu sürede tekerlek devrine yaklaşır.
const CLUTCH_SLIP: float = 1.80
## Hatalı çıkış (GO'dan önce dokunma) cezası (sn).
const FALSE_START_PENALTY: float = 0.60
## Tepki: kusursuz ve en kötü dokunuş (sn).
const REACTION_PERFECT: float = 0.15
const REACTION_WORST: float = 0.55
## Stat kaynaklı sapma (± oran) — yalnızca canlılık; rng verilmezse 0.
const VARIANCE: float = 0.012
## Başsız benzetim adımı (sn). Sabit adım = deterministik sonuç.
const STEP: float = 1.0 / 120.0

## Fizik sabitleri.
const AIR_DENSITY: float = 1.225
const DRAG_CD: float = 0.32
const ROLL_CRR: float = 0.014
const GRAVITY: float = 9.81
const DRIVETRAIN_EFF: float = 0.88
## Limitçi: devir sınırındayken kalan tork oranı.
const LIMITER_TORQUE: float = 0.12
## Patinajda aktarılan kuvvetin çekiş limitine oranı (dinamik sürtünme statiğin altında).
const SPIN_GRIP: float = 0.78


## Bir aracın motor + şanzıman künyesi. Katalog statlarından TÜRETİLİR.
class EngineSpec:
	var vehicle_id: StringName
	var idle_rpm: float = 850.0
	var redline_rpm: float = 6500.0
	var peak_torque_rpm: float = 3800.0
	var peak_power_rpm: float = 5700.0
	var peak_torque_nm: float = 200.0
	var launch_rpm: float = 4000.0        # optimum kalkış devri
	var gear_ratios: PackedFloat32Array = PackedFloat32Array()
	var final_drive: float = 3.90
	var wheel_radius: float = 0.31        # m
	var mass: float = 1200.0              # kg
	var frontal_area: float = 2.10        # m²
	var grip_mu: float = 1.05
	## Her vites için OPTİMUM vites devri (son vitese ait değer yoktur).
	var shift_rpm: PackedFloat32Array = PackedFloat32Array()

	func gear_count() -> int:
		return gear_ratios.size()

	## Bu vites ve hızda motor devri (debriyaj kavramışken).
	func rpm_at(speed: float, gear: int) -> float:
		var ratio: float = gear_ratios[clampi(gear, 0, gear_ratios.size() - 1)]
		var wheel_rps: float = speed / (TAU * wheel_radius)
		return wheel_rps * 60.0 * final_drive * ratio

	## Bu devir ve viteste tekerlekteki itme kuvveti (N).
	func force_at(rpm: float, gear: int) -> float:
		var ratio: float = gear_ratios[clampi(gear, 0, gear_ratios.size() - 1)]
		return DragRaceSim.torque_fraction(rpm, self) * peak_torque_nm * ratio \
			* final_drive * DragRaceSim.DRIVETRAIN_EFF / wheel_radius

	## Bu viteste hangi devirde vites atılmalı: bir üst viteste aynı hızda üretilen kuvvet,
	## bu vitestekine EŞİTLENDİĞİ devir (klasik ideal upshift noktası).
	func solve_shift_rpm(gear: int) -> float:
		if gear >= gear_count() - 1:
			return redline_rpm
		var k: float = gear_ratios[gear + 1] / gear_ratios[gear]   # < 1
		var best: float = redline_rpm
		var steps: int = 80
		var previous: float = 1.0
		for i: int in steps + 1:
			var rpm: float = lerpf(peak_torque_rpm * 0.75, redline_rpm, float(i) / float(steps))
			var here: float = DragRaceSim.torque_fraction(rpm, self) * gear_ratios[gear]
			var there: float = DragRaceSim.torque_fraction(rpm * k, self) * gear_ratios[gear + 1]
			var diff: float = here - there
			if i > 0 and previous > 0.0 and diff <= 0.0:
				best = rpm
				break
			previous = diff
		return clampf(best, peak_torque_rpm, redline_rpm)


	## Katalog statlarından künye üretir. Araç id'sine göre elle değer YOKTUR: her şey
	## sınıf / kategori / ölçü / yarış statlarından çıkar.
	static func derive(id: StringName) -> EngineSpec:
		var spec: EngineSpec = EngineSpec.new()
		spec.vehicle_id = id
		var entry: Dictionary = CarCatalog.get_entry(id)
		var stats: Dictionary = DragRaceSim.stats_of(id)
		var accel: float = clampf(float(stats["acceleration"]) / 100.0, 0.1, 1.0)
		var top_kmh: float = maxf(float(stats["top_speed"]), 80.0)
		var grip: float = clampf(float(stats["grip"]) / 100.0, 0.1, 1.0)
		var year: int = int(entry.get("year", 2005))
		var dims: Dictionary = entry.get("real_dimensions", {})
		var length: float = float(dims.get("length_m", 4.3))
		var width: float = float(dims.get("width_m", 1.75))
		var height: float = float(dims.get("height_m", 1.45))
		var category: String = String(entry.get("category", "sedan"))

		# Kütle: boy/genişlik + SUV payı. (Getz 3,83 m → ~1.010 kg, E60 4,84 m → ~1.410 kg.)
		spec.mass = 780.0 + (length - 3.5) * 400.0 + (width - 1.6) * 260.0
		if category == "suv":
			spec.mass += 150.0
		spec.frontal_area = width * height * 0.84

		# Devir sınırı: modern ve hızlanan araçlar daha yükseğe döner.
		var modern: float = clampf((float(year) - 1990.0) / 30.0, 0.0, 1.0)
		spec.redline_rpm = 5000.0 + accel * 1900.0 + modern * 500.0
		spec.idle_rpm = 780.0 + modern * 120.0
		spec.peak_torque_rpm = spec.redline_rpm * lerpf(0.52, 0.62, accel)
		spec.peak_power_rpm = spec.redline_rpm * 0.88
		spec.launch_rpm = spec.peak_torque_rpm * 1.08

		# Tekerlek yarıçapı boyla birlikte büyür (185/65 R15 ≈ 0,30 m, 225/45 R17 ≈ 0,32 m).
		spec.wheel_radius = 0.285 + (length - 3.8) * 0.022
		spec.grip_mu = lerpf(0.88, 1.22, grip)

		# Vites sayısı: eski/küçük araçlar 5, modern/güçlüler 6.
		var gears: int = 6 if accel >= 0.80 else 5
		# Son vites: tepe GÜÇ devrinde katalog son hızına ulaşacak şekilde çözülür.
		var top_ms: float = top_kmh / 3.6
		var wheel_rps_top: float = top_ms / (TAU * spec.wheel_radius)
		spec.final_drive = lerpf(4.25, 3.55, clampf((length - 3.8) / 1.0, 0.0, 1.0))
		var top_ratio: float = spec.peak_power_rpm / 60.0 / maxf(wheel_rps_top * spec.final_drive, 0.01)
		# Birinci vites: tutuşu zayıf araçta daha kısa (patinaj), güçlüde daha uzun.
		var first_ratio: float = lerpf(3.05, 3.75, accel)
		spec.gear_ratios = PackedFloat32Array()
		var spread: float = pow(top_ratio / first_ratio, 1.0 / float(gears - 1))
		for g: int in gears:
			# Geometrik dizi, ama alt kademeler biraz daha SIK (gerçek kutular böyle).
			var t: float = float(g) / float(gears - 1)
			var ratio: float = first_ratio * pow(spread, float(g)) * lerpf(1.0, 1.04, t * (1.0 - t) * 4.0)
			spec.gear_ratios.append(ratio)

		# Tepe tork: hedeflenen 0-100 süresine göre ölçeklenir (stat 30 → 14 sn, 100 → 6,2 sn).
		var target_0_100: float = lerpf(15.5, 6.0, accel)
		var v100: float = 100.0 / 3.6
		var avg_ratio: float = (spec.gear_ratios[0] + spec.gear_ratios[mini(2, gears - 1)]) * 0.5
		var needed_force: float = spec.mass * v100 / target_0_100 * 1.55   # ortalama tork payı
		spec.peak_torque_nm = needed_force * spec.wheel_radius \
			/ maxf(avg_ratio * spec.final_drive * DragRaceSim.DRIVETRAIN_EFF, 0.01)

		spec.shift_rpm = PackedFloat32Array()
		for g: int in gears:
			spec.shift_rpm.append(spec.solve_shift_rpm(g))
		return spec


## Künye önbelleği: aynı araç için tek kez türetilir (yarış başında ayırma yapılmaz).
static var _specs: Dictionary = {}

static func spec_of(vehicle_id: StringName) -> EngineSpec:
	if not _specs.has(vehicle_id):
		_specs[vehicle_id] = EngineSpec.derive(vehicle_id)
	return _specs[vehicle_id]


## TORK EĞRİSİ (0-1). Üç kırılım: rölanti → tepe tork (1,0) → tepe güç (0,80) → sınır (0,55).
## Tepe gücün üstündeki SERT düşüş oyunun kalbi: ideal vites noktası bu yüzden devir sınırının
## ALTINDA kalır (yoksa "hep sınıra daya" tek doğru strateji olurdu ve zamanlama anlamsızlaşırdı).
## Gerçek motorlar da tepe gücün ötesinde torku hızla kaybeder.
const TORQUE_AT_POWER_PEAK: float = 0.80
const TORQUE_AT_REDLINE: float = 0.55

static func torque_fraction(rpm: float, spec: EngineSpec) -> float:
	if rpm >= spec.redline_rpm:
		return LIMITER_TORQUE
	var idle: float = spec.idle_rpm
	var peak: float = spec.peak_torque_rpm
	if rpm <= idle:
		return 0.30
	if rpm <= peak:
		return lerpf(0.30, 1.0, smoothstep(idle, peak, rpm))
	if rpm <= spec.peak_power_rpm:
		return lerpf(1.0, TORQUE_AT_POWER_PEAK,
			(rpm - peak) / maxf(spec.peak_power_rpm - peak, 1.0))
	return lerpf(TORQUE_AT_POWER_PEAK, TORQUE_AT_REDLINE,
		(rpm - spec.peak_power_rpm) / maxf(spec.redline_rpm - spec.peak_power_rpm, 1.0))


## Bir aracın canlı koşusu. Ekrandaki oyuncu, ekrandaki rakip ve başsız testler AYNI adımı
## çalıştırır — ekranda gördüğün şey sonucun ta kendisidir.
class Runner:
	var vehicle_id: StringName
	var spec: EngineSpec

	## --- Fiziksel durum ---
	var gear: int = 0
	var speed: float = 0.0            # m/sn
	var distance: float = 0.0         # m
	var rpm: float = 0.0              # GERÇEK motor devri (d/dk)
	var running: bool = false
	var time: float = 0.0             # kalkıştan beri
	var finish_time: float = -1.0     # yarış saatine göre (-1 = bitmedi)

	## --- Durum bayrakları ---
	var limiter: bool = false         # devir sınırında
	var shifting: bool = false        # debriyaj ayrık (vites geçişi)
	var wheelspin: bool = false       # çekiş limiti aşıldı
	var clutch: float = 0.0           # kalan debriyaj kayması (sn)

	## --- Ölçümler (sonuç ekranı / debug / test) ---
	var launch_rpm: float = 0.0
	var launch_quality: int = Shift.GOOD
	var good_shifts: int = 0          # PERFECT + GOOD
	var bad_shifts: int = 0
	var perfect_shifts: int = 0
	var shift_log: PackedInt32Array = PackedInt32Array()
	var limiter_time: float = 0.0
	var spin_time: float = 0.0
	var max_rpm: float = 0.0
	var rpm_sum: float = 0.0
	var rpm_samples: int = 0
	var reaction: float = 0.0
	var false_start: bool = false

	var _shift_left: float = 0.0      # kalan geçiş süresi
	var _jitter: float = 1.0          # koşuya özgü milimetrik sapma
	var _bog: float = 1.0             # kalkış devri düşükse debriyaj kayarken tork payı

	func setup(id: StringName, rng: RandomNumberGenerator) -> void:
		vehicle_id = id
		spec = DragRaceSim.spec_of(id)
		gear = 0
		speed = 0.0
		distance = 0.0
		rpm = spec.idle_rpm
		running = false
		time = 0.0
		finish_time = -1.0
		limiter = false
		shifting = false
		wheelspin = false
		clutch = 0.0
		good_shifts = 0
		bad_shifts = 0
		perfect_shifts = 0
		shift_log = PackedInt32Array()
		limiter_time = 0.0
		spin_time = 0.0
		max_rpm = 0.0
		rpm_sum = 0.0
		rpm_samples = 0
		_shift_left = 0.0
		_jitter = 1.0
		_bog = 1.0
		launch_rpm = spec.launch_rpm
		launch_quality = Shift.PERFECT
		if rng:
			# Canlılık: aynı araç her koşuda milimetrik farklı çeker (sonucu belirlemez).
			_jitter = 1.0 + rng.randf_range(-DragRaceSim.VARIANCE, DragRaceSim.VARIANCE)

	func gear_count() -> int:
		return spec.gear_count()

	func top_gear() -> int:
		return spec.gear_count() - 1

	## Geri sayım sırasında oyuncu/AI gazı tutar: devir serbestçe yükselir/düşer (debriyaj açık).
	func rev(delta: float, target: float) -> void:
		if running:
			return
		var goal: float = clampf(target, spec.idle_rpm, spec.redline_rpm)
		var rate: float = (spec.redline_rpm - spec.idle_rpm) * 2.4   # d/dk per sn
		rpm = move_toward(rpm, goal, rate * delta)
		max_rpm = maxf(max_rpm, rpm)

	## Kalkış: o anki devirle debriyaj kavrar. Devir bandın altındaysa bog, üstündeyse patinaj.
	func launch() -> void:
		if running:
			return
		running = true
		launch_rpm = rpm
		var optimal: float = spec.launch_rpm
		var offset: float = (rpm - optimal) / maxf(optimal, 1.0)
		var magnitude: float = absf(offset)
		if magnitude <= DragRaceSim.LAUNCH_PERFECT_BAND:
			launch_quality = Shift.PERFECT
		elif magnitude <= DragRaceSim.LAUNCH_GOOD_BAND:
			launch_quality = Shift.GOOD
		elif offset < 0.0:
			launch_quality = Shift.EARLY     # bog: devir çok düşük
		else:
			launch_quality = Shift.LATE      # patinaj: devir çok yüksek
		_bog = 1.0
		if offset < 0.0:
			# BOG: motor bandın altında kavradı; ceza YALNIZCA debriyaj kayarken uygulanır.
			_bog = lerpf(1.0, DragRaceSim.BOG_FLOOR, clampf(magnitude / 0.55, 0.0, 1.0))
		clutch = DragRaceSim.CLUTCH_SLIP

	## Vites atar. Dönen: Shift.* kalitesi, -1 = mümkün değil.
	func shift() -> int:
		# Debriyaj kalkışta hâlâ kayıyorsa vites atılamaz: motor devri yüksek tutulduğu için
		# aksi hâlde araç daha 0 km/h'teyken üst vitese geçiyordu (yüksek devirli kalkışta
		# ölçülen hata: 300 m 28 sn).
		if not running or shifting or clutch > 0.0 or gear >= top_gear():
			return -1
		var optimal: float = spec.shift_rpm[gear]
		var offset: float = (rpm - optimal) / maxf(optimal, 1.0)
		var magnitude: float = absf(offset)
		var quality: int = Shift.GOOD
		if rpm >= spec.redline_rpm - 1.0:
			quality = Shift.REDLINE
		elif offset < -DragRaceSim.MISS_BAND:
			quality = Shift.MISS
		elif magnitude <= DragRaceSim.PERFECT_BAND:
			quality = Shift.PERFECT
		elif magnitude <= DragRaceSim.GOOD_BAND:
			quality = Shift.GOOD
		elif offset < 0.0:
			quality = Shift.EARLY
		else:
			quality = Shift.LATE
		if quality == Shift.PERFECT:
			perfect_shifts += 1
			good_shifts += 1
		elif quality == Shift.GOOD:
			good_shifts += 1
		else:
			bad_shifts += 1
		shift_log.append(quality)
		gear += 1
		shifting = true
		limiter = false
		_shift_left = float(DragRaceSim.SHIFT_TIME[quality])
		return quality

	## Bir fizik adımı. `race_time` yarış saatidir (bitiş anını kaydetmek için).
	func step(delta: float, race_time: float) -> void:
		if not running or finish_time >= 0.0 or delta <= 0.0:
			return
		time += delta

		# 1) Geçiş süresi: debriyaj ayrık, çekiş yok.
		var driving: bool = true
		if shifting:
			_shift_left -= delta
			driving = false
			if _shift_left <= 0.0:
				shifting = false

		# 2) Motor devri: debriyaj kavradıysa hızdan türer. KALKIŞTA debriyaj kayar: motor
		# kalkış devrinde tutunur (hafifçe düşerek), tekerlek devri ona YETİŞİNCE kilitlenir —
		# gerçek drag kalkışı böyledir ve kalkış devrini anlamlı kılan şey budur.
		var geared: float = spec.rpm_at(speed, gear)
		if clutch > 0.0:
			clutch = maxf(clutch - delta, 0.0)
			var held: float = launch_rpm * lerpf(1.0, 0.88,
				1.0 - clutch / DragRaceSim.CLUTCH_SLIP)
			if geared >= held:
				clutch = 0.0          # tekerlek yetişti: debriyaj kilitlendi
				rpm = geared
			else:
				rpm = held
		elif shifting:
			# Geçişte motor serbest: devir hafifçe düşer (gaz kesik).
			rpm = move_toward(rpm, geared, (spec.redline_rpm - spec.idle_rpm) * 1.6 * delta)
		else:
			rpm = geared
		rpm = clampf(rpm, spec.idle_rpm, spec.redline_rpm)
		limiter = not shifting and geared >= spec.redline_rpm
		if limiter:
			limiter_time += delta

		# 3) Kuvvetler
		var force: float = 0.0
		if driving:
			force = spec.force_at(rpm, gear) * _jitter
			if clutch > 0.0:
				force *= _bog
			# Çekiş limiti: aşılırsa patinaj, fazlası boşa gider.
			var traction: float = spec.grip_mu * spec.mass * DragRaceSim.GRAVITY * 0.62
			wheelspin = force > traction
			if wheelspin:
				force = traction * DragRaceSim.SPIN_GRIP
				spin_time += delta
		else:
			wheelspin = false
		var drag: float = 0.5 * DragRaceSim.AIR_DENSITY * DragRaceSim.DRAG_CD \
			* spec.frontal_area * speed * speed
		var roll: float = DragRaceSim.ROLL_CRR * spec.mass * DragRaceSim.GRAVITY
		var accel: float = (force - drag - roll) / spec.mass
		speed = maxf(speed + accel * delta, 0.0)
		distance += speed * delta

		# Devir, adımın SONUNDAKİ hızla yeniden hesaplanır: ekranda gösterilen devir ile
		# gösterilen hız aynı ana aittir (yoksa bir adımlık gecikme kalıyordu).
		if clutch <= 0.0 and not shifting:
			rpm = clampf(spec.rpm_at(speed, gear), spec.idle_rpm, spec.redline_rpm)
			limiter = spec.rpm_at(speed, gear) >= spec.redline_rpm
		max_rpm = maxf(max_rpm, rpm)
		rpm_sum += rpm
		rpm_samples += 1
		if distance >= DragRaceSim.DISTANCE:
			distance = DragRaceSim.DISTANCE
			finish_time = race_time

	## Kadran oranı (0-1): KENDİ optimum vites devri yeşil dilime denk gelecek şekilde eşlenir.
	func gauge() -> float:
		return DragRaceSim.gauge_for(rpm, spec, gear)

	func is_red() -> bool:
		return rpm >= spec.redline_rpm * 0.985

	## Bu viteste vites atma penceresinde miyiz (kadran yeşilde)?
	func in_shift_window() -> bool:
		if gear >= top_gear():
			return false
		var optimal: float = spec.shift_rpm[gear]
		return absf(rpm - optimal) / maxf(optimal, 1.0) <= DragRaceSim.GOOD_BAND

	func progress() -> float:
		return clampf(distance / DragRaceSim.DISTANCE, 0.0, 1.0)

	func speed_kmh() -> float:
		return speed * 3.6

	func average_rpm() -> float:
		return rpm_sum / maxf(float(rpm_samples), 1.0)


## Tek bir koşunun özeti (sonuç ekranı, debug ve testler).
class Run:
	var vehicle_id: StringName
	var time: float = 0.0
	var reaction: float = 0.0
	var shifts: int = 0            # isabetli (PERFECT + GOOD)
	var bad_shifts: int = 0
	var perfect_shifts: int = 0
	var limiter_time: float = 0.0
	var spin_time: float = 0.0
	var launch_rpm: float = 0.0
	var launch_quality: int = Shift.GOOD
	var max_rpm: float = 0.0
	var average_rpm: float = 0.0
	var top_speed: float = 0.0
	var false_start: bool = false
	var shift_log: PackedInt32Array = PackedInt32Array()

	static func of(runner: Runner, reaction_time: float) -> Run:
		var run: Run = Run.new()
		run.vehicle_id = runner.vehicle_id
		run.time = runner.finish_time
		run.reaction = reaction_time
		run.shifts = runner.good_shifts
		run.bad_shifts = runner.bad_shifts
		run.perfect_shifts = runner.perfect_shifts
		run.limiter_time = runner.limiter_time
		run.spin_time = runner.spin_time
		run.launch_rpm = runner.launch_rpm
		run.launch_quality = runner.launch_quality
		run.max_rpm = runner.max_rpm
		run.average_rpm = runner.average_rpm()
		run.top_speed = runner.speed_kmh()
		run.shift_log = runner.shift_log
		return run


## Motor devrini KADRAN yayına eşler. Parçalı: rölanti → yayın başı, bu VİTESİN optimum devri →
## yeşil dilimin ortası, devir sınırı → yayın sonu. Böylece yeşil dilim her araçta gerçekten
## "şimdi at" demektir. Son viteste atılacak vites yoktur: devir sınıra göre doğrusal gösterilir.
static func gauge_for(rpm: float, spec: EngineSpec, gear: int) -> float:
	var idle: float = spec.idle_rpm
	var red: float = spec.redline_rpm
	var value: float = clampf(rpm, idle, red)
	if gear >= spec.gear_count() - 1:
		return clampf((value - idle) / maxf(red - idle, 1.0), 0.0, 1.0)
	var optimal: float = spec.shift_rpm[clampi(gear, 0, spec.shift_rpm.size() - 1)]
	var low: float = optimal * (1.0 - GOOD_BAND)
	var high: float = optimal * (1.0 + GOOD_BAND)
	if value <= low:
		return (value - idle) / maxf(low - idle, 1.0) * GAUGE_GREEN_START
	if value <= high:
		return lerpf(GAUGE_GREEN_START, GAUGE_GREEN_END, (value - low) / maxf(high - low, 1.0))
	return lerpf(GAUGE_GREEN_END, 1.0, clampf((value - high) / maxf(red - high, 1.0), 0.0, 1.0))


## Kalkış kadranı: optimum kalkış devri yeşil dilime denk gelir (geri sayım sırasında kullanılır).
static func launch_gauge(rpm: float, spec: EngineSpec) -> float:
	var optimal: float = spec.launch_rpm
	var low: float = optimal * (1.0 - LAUNCH_GOOD_BAND)
	var high: float = optimal * (1.0 + LAUNCH_GOOD_BAND)
	var value: float = clampf(rpm, spec.idle_rpm, spec.redline_rpm)
	if value <= low:
		return (value - spec.idle_rpm) / maxf(low - spec.idle_rpm, 1.0) * GAUGE_GREEN_START
	if value <= high:
		return lerpf(GAUGE_GREEN_START, GAUGE_GREEN_END, (value - low) / maxf(high - low, 1.0))
	return lerpf(GAUGE_GREEN_END, 1.0,
		clampf((value - high) / maxf(spec.redline_rpm - high, 1.0), 0.0, 1.0))


## Kalite adı (UI ve rapor).
static func shift_name(quality: int) -> String:
	match quality:
		Shift.PERFECT: return "KUSURSUZ"
		Shift.GOOD: return "İYİ"
		Shift.EARLY: return "ERKEN"
		Shift.LATE: return "GEÇ"
		Shift.REDLINE: return "DEVİR SINIRI"
		_: return "IŞKA"


## Aracın yarış statları (cars.json "race" bloğu; kayıt yoksa güvenli varsayılan).
static func stats_of(vehicle_id: StringName) -> Dictionary:
	var entry: Dictionary = CarCatalog.get_entry(vehicle_id)
	var stats: Variant = entry.get("race", null)
	return stats if stats is Dictionary and not (stats as Dictionary).is_empty() else CarCatalog.RACE_STATS


## Statların tek sayılık özeti (rakip seçimi ve UI sıralaması için).
static func power_of(vehicle_id: StringName) -> float:
	var stats: Dictionary = stats_of(vehicle_id)
	return float(stats["top_speed"]) * 0.4 + float(stats["acceleration"]) * 0.45 + float(stats["grip"]) * 0.15


## İdeal süre (kusursuz kalkış + kusursuz vitesler, tepki yok).
static func base_time(vehicle_id: StringName) -> float:
	return drive(vehicle_id, 0.0, 1.0, 1.0, null).time


## Rakibin koşusu (başsız): tepkisi ve vites isabeti statlarından türer.
static func run_rival(vehicle_id: StringName, rng: RandomNumberGenerator) -> Run:
	var skill: float = skill_of(vehicle_id)
	var reaction: float = lerpf(REACTION_WORST, REACTION_PERFECT, skill)
	if rng:
		reaction += rng.randf_range(-0.06, 0.06)
	return drive(vehicle_id, maxf(reaction, 0.05), skill, skill, rng)


## Oyuncunun koşusu (başsız — "ne olurdu" hesapları ve testler için).
static func run_player(vehicle_id: StringName, tap_delay: float, accuracy: float,
		rng: RandomNumberGenerator) -> Run:
	var false_start: bool = tap_delay < 0.0
	var reaction: float = FALSE_START_PENALTY if false_start else clampf(tap_delay, 0.0, REACTION_WORST)
	var run: Run = drive(vehicle_id, reaction, accuracy, accuracy, rng)
	run.false_start = false_start
	return run


## Sürücü becerisi (0-1) — `reaction` statından.
static func skill_of(vehicle_id: StringName) -> float:
	return clampf(float(stats_of(vehicle_id)["reaction"]) / 100.0, 0.0, 1.0)


## Sınıfa göre AI beceri payı: D daha çok hata yapar, A neredeyse kusursuz.
static func class_skill(vehicle_id: StringName) -> float:
	var klass: String = String(CarCatalog.get_entry(vehicle_id).get("class", "C"))
	var base: float = {"D": 0.35, "C": 0.55, "B": 0.75, "A": 0.90}.get(klass, 0.55)
	return clampf(base * 0.7 + skill_of(vehicle_id) * 0.3, 0.0, 1.0)


## AI'nin bu viteste hedefleyeceği devir: becerisi arttıkça optimuma yaklaşır. Hata YÖNÜ de
## rastgeledir (bazen erken, bazen sınıra kadar bekler) — AI hile yapmaz, aynı fiziğe tabidir.
static func ai_shift_target(spec: EngineSpec, gear: int, skill: float,
		rng: RandomNumberGenerator) -> float:
	var optimal: float = spec.shift_rpm[clampi(gear, 0, spec.shift_rpm.size() - 1)]
	# Beceri 1 → ±%1, beceri 0 → ±%18 sapma.
	var spread: float = lerpf(0.18, 0.01, skill)
	# rng yoksa (deterministik testler) sapma rastgele değil SİSTEMATİK olur: zayıf sürücü
	# erken atar. Böylece beceri, rastgelelik olmadan da süreye yansır.
	var offset: float = rng.randf_range(-spread, spread) if rng else -spread * 0.6
	return clampf(optimal * (1.0 + offset), spec.idle_rpm, spec.redline_rpm)


## AI'nin kalkış devri: becerisi arttıkça optimuma yaklaşır.
static func ai_launch_rpm(spec: EngineSpec, skill: float, rng: RandomNumberGenerator) -> float:
	var spread: float = lerpf(0.30, 0.03, skill)
	var offset: float = rng.randf_range(-spread, spread) if rng else -spread * 0.6
	return clampf(spec.launch_rpm * (1.0 + offset), spec.idle_rpm, spec.redline_rpm)


## BAŞSIZ SÜRÜŞ — testlerin, rakibin ve dengeleme araçlarının ortak koşusu.
## `launch_skill` ve `shift_skill` 0-1: 1 = kusursuz. `shift_targets` verilirse vites devirleri
## doğrudan oradan okunur (shift pattern testleri ve optimum arama bunu kullanır).
static func drive(vehicle_id: StringName, reaction: float, launch_skill: float,
		shift_skill: float, rng: RandomNumberGenerator,
		shift_targets: PackedFloat32Array = PackedFloat32Array()) -> Run:
	var spec: EngineSpec = spec_of(vehicle_id)
	var runner: Runner = Runner.new()
	runner.setup(vehicle_id, rng)
	runner.reaction = reaction
	# Kalkış devrine yüksel, sonra kavra.
	runner.rpm = ai_launch_rpm(spec, clampf(launch_skill, 0.0, 1.0), rng)
	runner.launch()
	var race_time: float = reaction
	var target: float = _target_for(spec, 0, shift_skill, rng, shift_targets)
	var guard: int = 0
	while runner.finish_time < 0.0 and guard < 120000:
		guard += 1
		race_time += STEP
		runner.step(STEP, race_time)
		if runner.gear < runner.top_gear() and not runner.shifting and runner.rpm >= target:
			if runner.shift() >= 0:
				target = _target_for(spec, runner.gear, shift_skill, rng, shift_targets)
	return Run.of(runner, reaction)


static func _target_for(spec: EngineSpec, gear: int, skill: float, rng: RandomNumberGenerator,
		targets: PackedFloat32Array) -> float:
	if gear >= spec.gear_count() - 1:
		return INF
	if gear < targets.size():
		return targets[gear]
	return ai_shift_target(spec, gear, clampf(skill, 0.0, 1.0), rng)
