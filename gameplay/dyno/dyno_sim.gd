class_name DynoSim
extends RefCounted
## DİNAMOMETRE FİZİĞİ (2026-11-02, kullanıcı: "gaz verme ekranı… C dinamometre olsun"). Araç dino atölyesinde
## merdanelerin üstünde: motor yarış fiziğinin künyesiyle (DragRaceSim.EngineSpec; modifiyeli: PerformanceMods.spec_for)
## çalışır. Kullanıcı kararları: vites yok, START yok, DİNO KOŞUSU düğmesi yok — oyuncu yalnız gaz verir.
##
## Yük dinosu gibi: devir pedalı izler (bas → HOLD_RISE ile çıkar, bırak → HOLD_FALL ile iner); motor ölçüm vitesinde
## (oranı 1'e en yakın), merdane frenle devre bağlı döner, rölantide debriyaj açık (merdane durur). Viteste ataletle çekiş
## rölantiden kesiciye 9–16 sn, bırakınca rölantiye 19–30 sn sürüyordu (ölçüldü: qa/dino_his_olcum.gd) — çok ağır.
## Yalnız ÇEKEN aks döner (katalog drivetrain: FWD ön, RWD arka, AWD ikisi).
##
## Ölçüm: anlık güç / tork, oyunun GÖSTERGE ölçeğinde (PerformanceMods.power_curve "scale": fabrika tepe gücü = katalog
## beygiri; modifiye takınca artar). Tam gaz (≥ 0,95) basılıyken eğri kaydedilir; rölanti yakınından kesiciye varan çekiş
## bir ÖLÇÜM sayılır (pulls artar) — tepe güç en iyi ölçüm adayıdır.

## GAZ VERME: devrin pedala yürüyüşü, yükselme / düşme (d/dk/sn, kırmızı − rölanti aralığı başına).
const HOLD_RISE: float = 1.2
const HOLD_FALL: float = 0.85
## Debriyaj: rölantide açık (merdane durur), rölanti + rölanti × bu payda tam kavrar.
const HOLD_ENGAGE: float = 0.6
## Ölçüm sayılan çekiş en geç bu devir payında başlamalı (rölanti … kırmızı aralığında).
const PULL_START_MAX: float = 0.45
## Ölçümden ölçüme fark (hava, ısınma): ±bu pay.
const PULL_JITTER: float = 0.008
## Merdane yarıçapı (m, dino atölyesi).
const DRUM_RADIUS: float = 0.55

var vehicle_id: StringName = &""
var spec: DragRaceSim.EngineSpec
var electric: bool = false
## Çeken akslar (katalog drivetrain).
var drives_front: bool = false
var drives_rear: bool = true
## Gösterge ölçeği (fabrika tepe gücü = katalog beygiri).
var hp_scale: float = 1.0
var catalog_hp: float = 0.0
## Ölçüm vitesi (oranı 1'e en yakın).
var gear: int = 1

var running: bool = false        # kontak açık
var throttle: float = 0.0        # oyuncunun girdisi (0–1)
var rpm: float = 0.0
var speed: float = 0.0           # merdane yüzey hızı (m/sn)
var limiter: bool = false
var power_hp: float = 0.0        # anlık (gösterge ölçeği)
var torque_nm: float = 0.0
var drum_angle: float = 0.0      # çeken aksın merdane dönüş açısı (radyan) — görsel
var wheel_angle: float = 0.0     # çeken aksın teker dönüş açısı (radyan) — görsel

## Son tam gaz çekişin eğrisi: (devir, bg) ve (devir, Nm).
var curve_power: PackedVector2Array = PackedVector2Array()
var curve_torque: PackedVector2Array = PackedVector2Array()
var peak_hp: float = 0.0
var peak_hp_rpm: float = 0.0
var peak_torque: float = 0.0
var peak_torque_rpm: float = 0.0
## Tamamlanan ölçüm çekişi sayısı (rölanti yakınından kesiciye tam gaz).
var pulls: int = 0

var _jitter: float = 1.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _recording: bool = false
var _pull_counted: bool = false


func _init(id: StringName) -> void:
	vehicle_id = id
	_rng.randomize()
	spec = PerformanceMods.spec_for(id)
	electric = DragRaceSim.is_electric(id)
	var curve: Dictionary = PerformanceMods.power_curve(id, PerformanceMods.build_of(id))
	hp_scale = float(curve["scale"])
	var perf: Dictionary = CarCatalog.get_entry(id).get("performance", {})
	catalog_hp = float(perf.get("hp", 0))
	match String(perf.get("drivetrain", "RWD")):
		"FWD":
			drives_front = true
			drives_rear = false
		"AWD":
			drives_front = true
			drives_rear = true
	gear = measure_gear()


## Ölçüm vitesi: oranı 1'e en yakın (dinolar 1:1 vitesde çeker).
func measure_gear() -> int:
	var best: int = 1
	var best_err: float = INF
	for i: int in spec.gear_count():
		var err: float = absf(spec.gear_ratios[i] - 1.0)
		if err < best_err:
			best_err = err
			best = i + 1
	return best


func start_engine() -> void:
	running = true
	rpm = _idle()


func stop_engine() -> void:
	running = false
	throttle = 0.0


func step(delta: float) -> void:
	if delta <= 0.0:
		return
	var t: float = throttle if running else 0.0
	var span: float = spec.redline_rpm - spec.idle_rpm
	var idle: float = _idle()
	if running:
		var goal: float = lerpf(idle, spec.redline_rpm * 1.01, t)
		rpm = move_toward(rpm, goal, span * (HOLD_RISE if goal > rpm else HOLD_FALL) * delta)
	else:
		rpm = move_toward(rpm, 0.0, span * 1.6 * delta)
	var engage: float = 1.0 if electric else clampf((rpm - idle) / maxf(idle * HOLD_ENGAGE, 1.0), 0.0, 1.0)
	speed = _speed_for(rpm) * engage if running else 0.0
	limiter = running and rpm >= spec.redline_rpm * 0.995 and t > 0.5
	# Ölçüm (gösterge ölçeği): tork motor milinde, gazla orantılı. Kesicide okunan değer kırmızı çizgidekidir (kesici
	# torku keser, gösterge sıçrar: pedal dipteyken "57 bg" görünüyordu)
	var frac: float = DragRaceSim.torque_fraction(minf(rpm, spec.redline_rpm - 1.0), spec) if running else 0.0
	torque_nm = frac * spec.peak_torque_nm * hp_scale * t * _jitter
	power_hp = torque_nm * rpm / 7121.0
	drum_angle = fposmod(drum_angle + speed / DRUM_RADIUS * delta, TAU)
	wheel_angle = fposmod(wheel_angle + speed / maxf(spec.wheel_radius, 0.1) * delta, TAU)
	_record(t)


func kmh() -> float:
	return speed * 3.6


## Devir göstergesinin payı (0 rölanti … 1 kırmızı) — devir ışıkları.
func rpm_ratio() -> float:
	return clampf((rpm - spec.idle_rpm) / maxf(spec.redline_rpm - spec.idle_rpm, 1.0), 0.0, 1.0)


func _idle() -> float:
	return spec.idle_rpm if not electric else 0.0


func _speed_for(target_rpm: float) -> float:
	var ratio: float = spec.gear_ratios[clampi(gear - 1, 0, spec.gear_count() - 1)]
	return target_rpm / (60.0 * spec.final_drive * ratio) * TAU * spec.wheel_radius


## Tam gaz çekiş kaydı: gaz ≥ 0,95 basılınca yeni eğri başlar, devir yükseldikçe ileri yürür; kesiciye varınca çekiş
## rölanti yakınından başladıysa bir ölçüm sayılır. Gaz bırakılınca kayıt biter, eğri kalır.
func _record(t: float) -> void:
	var pulling: bool = running and t >= 0.95
	if pulling and not _recording:
		_clear_curve()
		_jitter = 1.0 + _rng.randf_range(-PULL_JITTER, PULL_JITTER)
		_pull_counted = false
	_recording = pulling
	if not _recording:
		return
	if rpm >= spec.redline_rpm * 0.999:
		var floor_rpm: float = lerpf(_idle(), spec.redline_rpm, PULL_START_MAX)
		if not _pull_counted and not curve_power.is_empty() and curve_power[0].x <= floor_rpm:
			_pull_counted = true
			pulls += 1
		return
	if not curve_power.is_empty() and rpm <= curve_power[curve_power.size() - 1].x + 25.0:
		return   # yalnız artan devir (eğri ileri yürür)
	curve_power.append(Vector2(rpm, power_hp))
	curve_torque.append(Vector2(rpm, torque_nm))
	if power_hp > peak_hp:
		peak_hp = power_hp
		peak_hp_rpm = rpm
	if torque_nm > peak_torque:
		peak_torque = torque_nm
		peak_torque_rpm = rpm


func _clear_curve() -> void:
	curve_power = PackedVector2Array()
	curve_torque = PackedVector2Array()
	peak_hp = 0.0
	peak_hp_rpm = 0.0
	peak_torque = 0.0
	peak_torque_rpm = 0.0
