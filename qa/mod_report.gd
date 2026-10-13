extends SceneTree
## PERFORMANS MODİFİYESİ — TASARIM ÖLÇÜMÜ (docs/PERFORMANS_MODIFIYE_TASARIM.md).
## Her yükseltmeyi DragRaceSim künyesine FİZİKSEL değer olarak uygular (tork, devir, vites oranı, vites
## geçiş süresi, tutuş, dönen kütle, kütle, hava direnci) ve kataloğun bütün araçlarında kusursuz sürüşle
## ölçer: 0-100, 300 m, bitiş hızı, patinaj, devir sınırı. Oyun koduna dokunmaz: künyenin KOPYASI üzerinde
## çalışır, fizik adımı oyundakinin aynısıdır (DragRaceSim.Runner).
## Kullanım: godot-4 --headless --path . -s res://qa/mod_report.gd -- [tablo|kademe <araç>|json <yol>]

const STAGES: int = 5
## 0-100 tek hızda ölçülmez: vites geçişi tam 100 km/sa'ya denk gelirse süre 0,1+ sn sıçrar ve bir
## yükseltme 0-100'ü "kötüleştirmiş" görünür. Karşılaştırma hızının %50–%100 bandındaki varış
## anlarının ortalaması alınır; vites geçişinin etkisi sürekli olur.
const REF_BAND: int = 26
const CATS: Array[String] = ["motor", "turbo", "air", "gear", "tire", "body"]

## --- Kademe tabloları: BİRİKİMLİ değer, indeks 0 = fabrika, 1..5 = SOKAK · SPOR · YARIŞ · PRO · EFSANE ---
## MOTOR: tork (bütün devir bandında). İlk kademe en hissedilir (yazılım), sonrakiler azalan.
const MOTOR_TORQUE: Array[float] = [0.0, 0.012, 0.021, 0.029, 0.036, 0.042]
## TURBO: tork + tepe tork devri yukarı (gecikme: kalkışta az, üst devirde çok verir).
const TURBO_TORQUE: Array[float] = [0.0, 0.009, 0.020, 0.031, 0.043, 0.054]
const TURBO_LAG: Array[float] = [0.0, 0.010, 0.020, 0.030, 0.040, 0.050]
## HAVA AKIŞI: az tork + devir sınırı ve tepe güç devri yukarı (motor yükseğe nefes alır).
const AIR_TORQUE: Array[float] = [0.0, 0.003, 0.006, 0.009, 0.012, 0.015]
const AIR_REV: Array[float] = [0.0, 0.008, 0.016, 0.024, 0.032, 0.040]
## ŞANZIMAN: vites geçiş süresi çarpanı · hafif volan (dönen kütle) · yakın oranlı alt vitesler ·
## yarış kutusunun son vitesi (güçlenen araç sınıra dayanmasın) · gösterilen son hıza katkı.
const GEAR_SHIFT: Array[float] = [1.0, 0.90, 0.86, 0.82, 0.76, 0.62]
const GEAR_INERTIA: Array[float] = [0.0, 0.0, 0.0, 0.010, 0.010, 0.010]
const GEAR_LOW: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.030, 0.040]
const GEAR_RACE_TOP: Array[float] = [0.0, 0.02, 0.04, 0.06, 0.08, 0.10]
const GEAR_TOP_DISPLAY: Array[float] = [0.0, 0.008, 0.016, 0.024, 0.040, 0.050]
## LASTİK & JANT: tutuş (patinaj yapan araçta büyük) · hafif jant = dönen kütle (her araçta küçük).
const TIRE_GRIP: Array[float] = [0.0, 0.03, 0.06, 0.09, 0.12, 0.15]
const TIRE_INERTIA: Array[float] = [0.0, 0.0, 0.007, 0.011, 0.015, 0.018]
## GÖVDE: kütle · (ön alan × Cd).
const BODY_MASS: Array[float] = [0.0, 0.007, 0.014, 0.021, 0.028, 0.035]
const BODY_DRAG: Array[float] = [0.0, 0.0, 0.008, 0.016, 0.024, 0.035]

## --- Motor profilleri: aynı parçaya farklı tepki (katalogdaki motor adından + yıldan çıkar) ---
## Çarpanlar kademe tablolarının ARTIŞINA uygulanır (1 = tablo; lag/rev için de).
const PROFILES: Dictionary = {
	"turbo_benzin": {"motor": 1.25, "turbo": 1.20, "lag": 0.6, "air": 0.9, "rev": 1.0},
	"turbo_dizel": {"motor": 1.50, "turbo": 1.30, "lag": 0.6, "air": 0.6, "rev": 0.4},
	"atmosferik": {"motor": 1.00, "turbo": 1.00, "lag": 1.5, "air": 1.25, "rev": 1.2},
	"klasik": {"motor": 1.10, "turbo": 1.00, "lag": 0.0, "air": 1.30, "rev": 1.0},
	"dizel": {"motor": 1.00, "turbo": 1.30, "lag": 1.5, "air": 0.6, "rev": 0.4},
	"elektrik": {"motor": 1.30, "turbo": 1.00, "lag": 0.0, "air": 0.5, "rev": 0.0},
}


static func profile_of(id: StringName) -> String:
	var entry: Dictionary = CarCatalog.get_entry(id)
	var engine: String = String(entry.get("performance", {}).get("engine", "")).to_lower()
	var year: int = int(entry.get("year", 2000))
	if engine.begins_with("elektrik"):
		return "elektrik"
	var turbo: bool = engine.contains("turbo") or engine.contains("tsi") or engine.contains("tfsi") \
		or engine.ends_with("t") or engine.contains("biturbo")
	var diesel: bool = engine.contains("tdi") or engine.contains("crdi") or engine.contains("dizel")
	if diesel:
		return "turbo_dizel" if engine.contains("tdi") or engine.contains("crdi") else "dizel"
	if turbo:
		return "turbo_benzin"
	return "klasik" if year < 1980 else "atmosferik"


## Vites geçişini kısaltan koşucu (ŞANZIMAN): fizik adımı oyundakiyle aynı.
class ModRunner extends DragRaceSim.Runner:
	var shift_scale: float = 1.0

	func shift() -> int:
		var q: int = super.shift()
		if q >= 0:
			_shift_left *= shift_scale
		return q


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "tablo"
	if mode == "kademe":
		_print_stages(StringName(args[1]))
		quit()
		return
	var rows: Array[Dictionary] = []
	for entry: Dictionary in CarCatalog.all():
		rows.append(_car_report(entry["id"]))
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["stock"]["t300"] < b["stock"]["t300"])
	if mode == "json":
		var file: FileAccess = FileAccess.open(args[1], FileAccess.WRITE)
		file.store_string(JSON.stringify(rows, " "))
		file.close()
		print("yazıldı: ", args[1])
	else:
		_print_table(rows)
	quit()


## Bir aracın fabrika, kategori başına (kademe 1..5), full ve kombinasyon ölçümleri.
func _car_report(id: StringName) -> Dictionary:
	var entry: Dictionary = CarCatalog.get_entry(id)
	var perf: Dictionary = entry.get("performance", {})
	var base: DragRaceSim.EngineSpec = DragRaceSim.spec_of(id)
	var vref: float = _reference_speed(base)
	var stock: Dictionary = _measure(base, {}, vref)
	var out: Dictionary = {"id": String(id), "class": entry.get("class", "?"), "drive": perf.get("drivetrain", "?"),
		"profile": profile_of(id), "real_0_100": float(perf.get("zero_100", 0.0)),
		"real_top": float(perf.get("top_speed", 0.0)), "hp": int(perf.get("hp", 0)), "price": int(entry.get("price", 0)),
		"vref": vref * 3.6, "stock": stock, "cats": {}}
	for cat: String in CATS:
		var stages: Array = []
		for s: int in range(1, STAGES + 1):
			stages.append(_measure(base, {cat: s}, vref))
		out["cats"][cat] = stages
	var full: Dictionary = {}
	for cat: String in CATS:
		full[cat] = STAGES
	out["full"] = _measure(base, full, vref)
	var power: Dictionary = {"motor": STAGES, "turbo": STAGES, "air": STAGES}
	out["power_only"] = _measure(base, power, vref)
	var power_tire: Dictionary = power.duplicate()
	power_tire["tire"] = STAGES
	out["power_tire"] = _measure(base, power_tire, vref)
	return out


## 0-100 karşılaştırma hızı: 100 km/sa (PACE'li simülasyonda 100), aracın ulaşamadığı yerde fabrika
## tepe hızının %75'i (Fiat 500'ün gerçek son hızı 95 km/sa: 0-100'ü hiç yok). Gösterilen 0-100 =
## katalogdaki gerçek 0-100 × (modifiyeli / fabrika) bu hıza varış süresi oranı.
func _reference_speed(base: DragRaceSim.EngineSpec) -> float:
	var runner: ModRunner = ModRunner.new()
	runner.setup_spec(base, null)
	runner.rpm = base.launch_rpm
	runner.launch()
	var t: float = 0.0
	var vmax: float = 0.0
	while t < 120.0:
		t += DragRaceSim.STEP
		runner.finish_time = -1.0
		runner.distance = 0.0
		runner.step(DragRaceSim.STEP, t)
		vmax = maxf(vmax, runner.speed)
		if runner.speed >= 100.0 / 3.6:
			return 100.0 / 3.6
		if runner.gear < runner.top_gear() and not runner.shifting and runner.rpm >= base.shift_rpm[runner.gear]:
			runner.shift()
	return vmax * 0.75


## REF_BAND hızın i'incisi: karşılaştırma hızının %50'si … %100'ü.
func _band_fraction(i: int) -> float:
	return 0.5 + 0.5 * float(i) / float(REF_BAND - 1)


## Künyenin modifiyeli kopyası.
func _apply(base: DragRaceSim.EngineSpec, build: Dictionary) -> DragRaceSim.EngineSpec:
	var s: DragRaceSim.EngineSpec = DragRaceSim.EngineSpec.new()
	s.vehicle_id = base.vehicle_id
	s.idle_rpm = base.idle_rpm
	s.redline_rpm = base.redline_rpm
	s.peak_torque_rpm = base.peak_torque_rpm
	s.peak_power_rpm = base.peak_power_rpm
	s.peak_torque_nm = base.peak_torque_nm
	s.final_drive = base.final_drive
	s.wheel_radius = base.wheel_radius
	s.mass = base.mass
	s.frontal_area = base.frontal_area
	s.grip_mu = base.grip_mu
	s.drive_share = base.drive_share
	s.gear_ratios = base.gear_ratios.duplicate()
	s.race_top_kmh = base.race_top_kmh
	var p: Dictionary = PROFILES[profile_of(base.vehicle_id)]
	var m: int = int(build.get("motor", 0))
	var t: int = int(build.get("turbo", 0))
	var a: int = int(build.get("air", 0))
	var g: int = int(build.get("gear", 0))
	var l: int = int(build.get("tire", 0))
	var b: int = int(build.get("body", 0))
	s.peak_torque_nm *= (1.0 + MOTOR_TORQUE[m] * float(p["motor"])) * (1.0 + TURBO_TORQUE[t] * float(p["turbo"])) \
		* (1.0 + AIR_TORQUE[a] * float(p["air"]))
	s.peak_torque_rpm *= 1.0 + TURBO_LAG[t] * float(p["lag"])
	var rev: float = 1.0 + AIR_REV[a] * float(p["rev"])
	s.redline_rpm *= rev
	s.peak_power_rpm *= rev
	s.peak_torque_rpm = minf(s.peak_torque_rpm, s.peak_power_rpm * 0.92)
	s.launch_rpm = s.peak_torque_rpm * 1.08
	# Dönen kütle (hafif jant, hafif volan): ivmeye giren kütle azalır, çekişi belirleyen ağırlık aynı kalır
	# → kütle düşer, tutuş katsayısı aynı oranda yükselir (çekiş kuvveti değişmez).
	var inertia: float = 1.0 - TIRE_INERTIA[l] - GEAR_INERTIA[g]
	s.mass *= (1.0 - BODY_MASS[b]) * inertia
	s.grip_mu *= (1.0 + TIRE_GRIP[l]) / inertia
	s.frontal_area *= 1.0 - BODY_DRAG[b]
	if g > 0:
		var accel: float = clampf(float(DragRaceSim.stats_of(base.vehicle_id)["acceleration"]) / 100.0, 0.1, 1.0)
		s.build_gears(base.gear_count(), base.race_top_kmh * (1.0 + GEAR_RACE_TOP[g]), accel)
		# Yakın oranlı kutu: alt vitesler kısalır (birinci en çok), son vites aynı
		var n: int = s.gear_count()
		for i: int in n - 1:
			s.gear_ratios[i] *= 1.0 + GEAR_LOW[g] * (1.0 - float(i) / float(n - 1))
	s.shift_rpm = PackedFloat32Array()
	for i: int in s.gear_count():
		s.shift_rpm.append(s.solve_shift_rpm(i))
	return s


## Kusursuz kalkış + kusursuz vitesler: karşılaştırma hızına varış, 300 m ve bitiş hızı.
func _measure(base: DragRaceSim.EngineSpec, build: Dictionary, vref: float) -> Dictionary:
	var spec: DragRaceSim.EngineSpec = _apply(base, build) if not build.is_empty() else base
	var runner: ModRunner = ModRunner.new()
	runner.setup_spec(spec, null)
	runner.shift_scale = GEAR_SHIFT[int(build.get("gear", 0))]
	runner.rpm = spec.launch_rpm
	runner.launch()
	var t: float = 0.0
	var tref: float = -1.0
	var band: PackedFloat32Array = PackedFloat32Array()   # REF_BAND hızlarına varış anları
	var prev_speed: float = 0.0
	var t300: float = -1.0
	var trap: float = 0.0
	var spin: float = 0.0
	var limiter: float = 0.0
	while (t300 < 0.0 or tref < 0.0) and t < 120.0:
		t += DragRaceSim.STEP
		runner.step(DragRaceSim.STEP, t)
		while band.size() < REF_BAND and runner.speed >= vref * _band_fraction(band.size()):
			var target: float = vref * _band_fraction(band.size())
			var k: float = clampf((target - prev_speed) / maxf(runner.speed - prev_speed, 0.0001), 0.0, 1.0)
			band.append(t - DragRaceSim.STEP * (1.0 - k))
		prev_speed = runner.speed
		if tref < 0.0 and band.size() == REF_BAND:
			var sum: float = 0.0
			for x: float in band:
				sum += x
			tref = sum / float(REF_BAND)
		if t300 < 0.0 and runner.finish_time >= 0.0:
			t300 = runner.finish_time
			trap = runner.speed * 3.6
			spin = runner.spin_time
			limiter = runner.limiter_time
		if runner.finish_time >= 0.0:
			runner.finish_time = -1.0   # 300 m'de durma: yavaş araç karşılaştırma hızına sonra ulaşır
			runner.distance = 0.0
		if runner.gear < runner.top_gear() and not runner.shifting and runner.rpm >= spec.shift_rpm[runner.gear]:
			runner.shift()
	# Gösterge: güç = tepe tork × tepe güç devri; son hız ∝ (güç / hava direnci)^(1/3) × kutu
	var power_ratio: float = spec.peak_torque_nm * spec.peak_power_rpm / (base.peak_torque_nm * base.peak_power_rpm)
	var drag_ratio: float = spec.frontal_area / base.frontal_area
	var top_factor: float = pow(power_ratio / drag_ratio, 1.0 / 3.0) * (1.0 + GEAR_TOP_DISPLAY[int(build.get("gear", 0))])
	return {"tref": tref, "t300": t300, "trap": trap, "spin": spin, "limiter": limiter, "power": power_ratio,
		"top": top_factor}


func _pct(after: float, before: float) -> float:
	return (after / before - 1.0) * 100.0


func _print_table(rows: Array[Dictionary]) -> void:
	print("araç                   sn çkş  profil        0-100  300m  pat | FULL 0-100 (%%)    300m(%%)  sonhız  güç | motor turbo hava şanz lastik gövde [300m %%, EFSANE] | güç→+lastik")
	for r: Dictionary in rows:
		var st: Dictionary = r["stock"]
		var fu: Dictionary = r["full"]
		var real: float = float(r["real_0_100"])
		var line: String = "%-22s %-2s %-4s %-12s %5.1f %6.2f %4.2f | %5.1f (%5.1f) %6.2f(%5.1f) %+5.1f %+5.1f |" % [
			r["id"], r["class"], r["drive"], r["profile"], real, st["t300"], st["spin"],
			real * fu["tref"] / st["tref"], _pct(fu["tref"], st["tref"]), fu["t300"], _pct(fu["t300"], st["t300"]),
			(fu["top"] - 1.0) * 100.0, (fu["power"] - 1.0) * 100.0]
		for cat: String in CATS:
			line += " %5.1f" % _pct(r["cats"][cat][STAGES - 1]["t300"], st["t300"])
		line += " | %5.1f" % _pct(r["power_tire"]["t300"], r["power_only"]["t300"])
		print(line)


## Tek araç, kategori × kademe: gösterilecek 0-100 / son hız / beygir.
func _print_stages(id: StringName) -> void:
	var r: Dictionary = _car_report(id)
	var st: Dictionary = r["stock"]
	var real: float = float(r["real_0_100"])
	var top: float = float(r["real_top"])
	var hp: int = int(r["hp"])
	print("%s (%s, %s, %s): fabrika 0-100 %.1f · son hız %.0f · %d bg · 300 m %.2f" % [id, r["class"], r["drive"],
		r["profile"], real, top, hp, st["t300"]])
	for cat: String in CATS:
		var line: String = "  %-6s" % cat
		for s: int in STAGES:
			var m: Dictionary = r["cats"][cat][s]
			line += " | %4.2f sn %3.0f km/s %3.0f bg %5.2f" % [real * m["tref"] / st["tref"], top * m["top"], hp * m["power"], m["t300"]]
		print(line)
	var fu: Dictionary = r["full"]
	print("  FULL   | %4.2f sn %3.0f km/s %3.0f bg %5.2f" % [real * fu["tref"] / st["tref"], top * fu["top"], hp * fu["power"], fu["t300"]])
