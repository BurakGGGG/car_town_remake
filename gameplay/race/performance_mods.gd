class_name PerformanceMods
extends RefCounted
## PERFORMANS MODİFİYESİ — MODEL (docs/PERFORMANS_MODIFIYE_TASARIM.md). Sahneden bağımsız saf hesap.
## 6 kategori × 5 kademe. Her parça DragRaceSim künyesinde FİZİKSEL bir değeri değiştirir (tork, devir sınırı,
## turbo gecikmesi, vites oranı, vites geçiş süresi, lastik tutuşu, dönen kütle, kütle, hava direnci); süreler
## kusursuz sürüşle ÖLÇÜLÜR, elle yazılmaz. Aynı parçaya her araç farklı tepki verir: motor tipine göre 6 profil.
##
## Oyuncunun araç başına yapısı (kategori → kademe) PerformanceModManager'dadır (kayıt, satın alma, takma);
## buradaki statik kopyası yarışın oyuncu künyesini kurmak içindir (set_build). Rakipler HER ZAMAN fabrika
## künyesiyle koşar (DragRaceSim.spec_of): oyuncu Passat'ını yükseltince rakip Passat değişmez.
## Ölçüm aracı: qa/mod_report.gd (bütün araçlar × bütün kademeler tablosu).

const STAGES: int = 5
const CATEGORIES: Array[StringName] = [&"motor", &"turbo", &"air", &"gear", &"tire", &"body"]

## --- Kademeler: ad, renk (nadirlik dili), oyuncu seviyesi kilidi, takma süresi (sn) ---
const TIER_NAMES: Array[String] = ["SOKAK", "SPOR", "YARIŞ", "PRO", "EFSANE"]
const TIER_COLORS: Array[Color] = [Color("A3A8AE"), Color("4FB477"), Color("3D8BFD"), Color("A066E8"), Color("F5BE4C")]
const TIER_LEVEL: Array[int] = [3, 5, 8, 12, 16]
## Her kademe bir tamir alanını (CarSpot) bu süre boyunca kaplar: alan doluyken müşteri alınamaz.
const INSTALL_TIME: Array[float] = [120.0, 360.0, 1200.0, 2700.0, 5400.0]

## --- Fiyat: max(taban, araç fiyatı × oran) × kategori ağırlığı, 50 ₺'ye yuvarlanır (full ≈ 2 × araç) ---
const PRICE_RATE: Array[float] = [0.015, 0.03, 0.05, 0.09, 0.15]
const PRICE_FLOOR: Array[int] = [400, 800, 1300, 2000, 3200]
const PRICE_WEIGHT: Dictionary = {&"motor": 1.2, &"turbo": 1.2, &"air": 0.8, &"gear": 1.0, &"tire": 0.8, &"body": 1.0}

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
const TIRE_INERTIA: Array[float] = [0.0, 0.003, 0.007, 0.011, 0.015, 0.018]
## GÖVDE: kütle · (ön alan × Cd).
const BODY_MASS: Array[float] = [0.0, 0.007, 0.014, 0.021, 0.028, 0.035]
const BODY_DRAG: Array[float] = [0.0, 0.0, 0.008, 0.016, 0.024, 0.035]

## --- Motor profilleri: aynı parçaya farklı tepki (katalogdaki motor adından + yıldan çıkar) ---
## Çarpanlar kademe tablolarının ARTIŞINA uygulanır (1 = tablo).
const PROFILES: Dictionary = {
	&"turbo_benzin": {"motor": 1.25, "turbo": 1.20, "lag": 0.6, "air": 0.9, "rev": 1.0},
	&"turbo_dizel": {"motor": 1.50, "turbo": 1.30, "lag": 0.6, "air": 0.6, "rev": 0.4},
	&"atmosferik": {"motor": 1.00, "turbo": 1.00, "lag": 1.5, "air": 1.25, "rev": 1.2},
	&"klasik": {"motor": 1.10, "turbo": 1.00, "lag": 0.0, "air": 1.30, "rev": 1.0},
	&"dizel": {"motor": 1.00, "turbo": 1.30, "lag": 1.5, "air": 0.6, "rev": 0.4},
	&"elektrik": {"motor": 1.30, "turbo": 1.00, "lag": 0.0, "air": 0.5, "rev": 0.0},
}

## --- Adlar (Loc.t ile çevrilir). Profil kendi adını verirse o kullanılır ---
const CATEGORY_NAMES: Dictionary = {
	&"motor": "MOTOR", &"turbo": "TURBO", &"air": "HAVA AKIŞI", &"gear": "ŞANZIMAN", &"tire": "LASTİK & JANT",
	&"body": "GÖVDE",
}
const PROFILE_CATEGORY_NAMES: Dictionary = {
	&"klasik": {&"turbo": "KOMPRESÖR", &"air": "KARBÜRATÖR & EGZOZ"},
	&"elektrik": {&"turbo": "BATARYA", &"air": "SOĞUTMA"},
}
const PART_NAMES: Dictionary = {
	&"motor": ["Stage 1 Yazılım", "Spor Eksantrik", "Dövme Piston", "Stroker Krank", "Yarış Bloğu"],
	&"turbo": ["Turbo Yükseltme", "Büyük İntercooler", "Hibrit Türbin", "Büyük Turbo", "Twin-Turbo"],
	&"air": ["Spor Hava Filtresi", "Soğuk Hava Emişi", "Downpipe", "Paslanmaz Manifold", "Titanyum Yarış Egzozu"],
	&"gear": ["Kısa Vites Kolu", "Spor Debriyaj", "Hafif Volan", "Yakın Oranlı Kutu", "Sıralı Yarış Şanzımanı"],
	&"tire": ["Spor Lastik", "Hafif Jant & Yarı Slik", "Dövme Jant & Drag Radial", "Magnezyum Jant & Slik",
		"Karbon Jant & Pro Drag Slik"],
	&"body": ["Hafif Akü", "Karbon Kaput", "Kova Koltuk & İç Söküm", "Karbon Panel & Spoiler", "Tam Karbon Gövde"],
}
const PROFILE_PART_NAMES: Dictionary = {
	&"klasik": {
		&"motor": ["Elektronik Ateşleme", "Spor Eksantrik", "Dövme Piston", "Stroker Krank", "Yarış Bloğu"],
		&"turbo": ["Kompresör Kiti", "Büyük Kasnak", "Intercooler", "Roots Kompresör", "Twin-Screw Kompresör"],
		&"air": ["Spor Hava Filtresi", "Çift Karbüratör", "Weber Karbüratör", "Yarış Manifoldu", "Enjeksiyon Dönüşümü"],
	},
	&"elektrik": {
		&"motor": ["Performans Yazılımı", "Spor İnvertör", "SiC İnvertör", "Karbon Sargılı Rotor", "Yarış Motoru"],
		&"turbo": ["Yüksek Deşarj Modu", "Hızlı Hücre Paketi", "Yarış Hücreleri", "Süperkapasitör Destek",
			"Yarış Bataryası"],
		&"air": ["Spor Radyatör", "Batarya Ön Isıtma", "Sıvı Soğutmalı Kablo", "Yarış Soğutma Devresi",
			"Kriyo Soğutma"],
	},
	&"atmosferik": {&"turbo": ["Turbo Kiti", "Büyük İntercooler", "Hibrit Türbin", "Büyük Turbo", "Twin-Turbo"]},
	&"dizel": {&"turbo": ["Turbo Kiti", "Büyük İntercooler", "Hibrit Türbin", "Büyük Turbo", "Twin-Turbo"]},
}

## Parça ikonları (ui/hud/art/parts/<id>.png; tools/parts/part_icons.py Blender'da çizer). Profil kendi
## parçalarını satıyorsa (klasik kompresör / karbüratör, elektrik batarya / soğutma) onların ikonu.
const ICON_DIR: String = "res://ui/hud/art/parts/"
const PART_ICONS: Dictionary = {
	&"motor": ["motor_ecu", "motor_cam", "motor_piston", "motor_crank", "motor_block"],
	&"turbo": ["turbo_small", "turbo_intercooler", "turbo_wheel", "turbo_big", "turbo_twin"],
	&"air": ["air_filter", "air_cold", "air_downpipe", "air_header", "air_exhaust"],
	&"gear": ["gear_shifter", "gear_clutch", "gear_flywheel", "gear_set", "gear_sequential"],
	&"tire": ["tire_sport", "tire_semi", "tire_radial", "tire_slick", "tire_pro"],
	&"body": ["body_battery", "body_hood", "body_seat", "body_spoiler", "body_shell"],
}
const PROFILE_PART_ICONS: Dictionary = {
	&"klasik": {
		&"motor": ["classic_ignition", "motor_cam", "motor_piston", "motor_crank", "motor_block"],
		&"turbo": ["classic_sc_kit", "classic_pulley", "turbo_intercooler", "classic_roots", "classic_screw"],
		&"air": ["classic_cleaner", "classic_twin_carb", "classic_weber", "air_header", "classic_fi"],
	},
	&"elektrik": {
		&"motor": ["ev_software", "ev_inverter", "ev_sic", "ev_rotor", "ev_motor"],
		&"turbo": ["ev_discharge", "ev_cells", "ev_pouch", "ev_supercap", "ev_pack"],
		&"air": ["ev_radiator", "ev_preheat", "ev_cable", "ev_race_cool", "ev_cryo"],
	},
}

## 0-100 tek hızda ölçülmez: vites geçişi tam 100 km/sa'ya denk gelirse süre 0,1+ sn sıçrar ve bir yükseltme
## 0-100'ü "kötüleştirmiş" görünür (Camaro MOTOR: 4,0 → 4,15). Karşılaştırma hızının %50–%100 bandındaki
## REF_BAND hıza varış anlarının ortalaması alınır; vites geçişinin etkisi sürekli olur.
const REF_BAND: int = 26
const SINGLE_LIMIT: float = 120.0
## Sınıflar en hızlıdan en yavaşa; eşik = sınıfın en yavaş FABRİKA aracının kusursuz 300 m süresi.
const CLASSES: Array[String] = ["S", "A", "B", "C", "D"]

## Oyuncunun yapıları: araç id → {kategori: kademe} (PerformanceModManager yazar).
static var _builds: Dictionary = {}
## Gösterilen 0-100'ün tabanı (oran): bir kademe göstergeyi asla kötüleştirmez (bkz. display_floor).
static var _floors: Dictionary = {}
static var _measures: Dictionary = {}     # "id|yapı" → ölçüm
static var _specs: Dictionary = {}        # "id|yapı" → EngineSpec
static var _vref: Dictionary = {}         # id → karşılaştırma hızı (m/sn)
static var _thresholds: Dictionary = {}   # sınıf → 300 m eşiği


# --- Oyuncu yapısı ---------------------------------------------------------------------

static func set_build(vehicle_id: StringName, build: Dictionary) -> void:
	var clean: Dictionary = normalized(build)
	if clean.is_empty():
		_builds.erase(vehicle_id)
	else:
		_builds[vehicle_id] = clean


static func build_of(vehicle_id: StringName) -> Dictionary:
	return (_builds.get(vehicle_id, {}) as Dictionary).duplicate()


static func stage_of(vehicle_id: StringName, category: StringName) -> int:
	return int((_builds.get(vehicle_id, {}) as Dictionary).get(category, 0))


static func is_modified(vehicle_id: StringName) -> bool:
	return _builds.has(vehicle_id)


## Takılan parça sayısı (0-30).
static func installed_count(vehicle_id: StringName) -> int:
	var total: int = 0
	for value: Variant in (_builds.get(vehicle_id, {}) as Dictionary).values():
		total += int(value)
	return total


static func set_display_floor(vehicle_id: StringName, ratio: float) -> void:
	if ratio >= 1.0 or ratio <= 0.0:
		_floors.erase(vehicle_id)
	else:
		_floors[vehicle_id] = ratio


static func display_floor(vehicle_id: StringName) -> float:
	return float(_floors.get(vehicle_id, 1.0))


## Bütün oyuncu verisi silinir (yeni oyun / kayıt yükleme / test). Ölçüm önbelleği kalır (fizik değişmedi).
static func clear() -> void:
	_builds.clear()
	_floors.clear()


## Katalog / fizik değişti (bake aracı, test): ölçümler de silinir.
static func clear_cache() -> void:
	_measures.clear()
	_specs.clear()
	_vref.clear()
	_thresholds.clear()


## Yalnızca bilinen kategoriler, 1..STAGES aralığında; 0 olanlar atılır.
static func normalized(build: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for category: StringName in CATEGORIES:
		var stage: int = clampi(SaveSafe.i(build.get(category, build.get(String(category), 0))), 0, STAGES)   # arkadaş verisi: tür güvenli
		if stage > 0:
			out[category] = stage
	return out


static func build_key(build: Dictionary) -> String:
	var key: String = ""
	for category: StringName in CATEGORIES:
		key += str(int(build.get(category, 0)))
	return key


## Yapıya bir kategoride bir kademe eklenmiş hali.
static func with_stage(build: Dictionary, category: StringName, stage: int) -> Dictionary:
	var next: Dictionary = build.duplicate()
	next[category] = stage
	return normalized(next)


# --- Künye ---------------------------------------------------------------------------------

## Oyuncu aracının yarış künyesi (yapısız araçta fabrika künyesinin kendisi).
static func spec_for(vehicle_id: StringName) -> DragRaceSim.EngineSpec:
	return spec_with(vehicle_id, _builds.get(vehicle_id, {}))


static func spec_with(vehicle_id: StringName, build: Dictionary) -> DragRaceSim.EngineSpec:
	var clean: Dictionary = normalized(build)
	if clean.is_empty():
		return DragRaceSim.spec_of(vehicle_id)
	var key: String = String(vehicle_id) + "|" + build_key(clean)
	if not _specs.has(key):
		_specs[key] = apply(DragRaceSim.spec_of(vehicle_id), clean)
	return _specs[key]


## Künyenin modifiyeli KOPYASI (fabrika künyesi değişmez).
static func apply(base: DragRaceSim.EngineSpec, build: Dictionary) -> DragRaceSim.EngineSpec:
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
	var m: int = int(build.get(&"motor", 0))
	var t: int = int(build.get(&"turbo", 0))
	var a: int = int(build.get(&"air", 0))
	var g: int = int(build.get(&"gear", 0))
	var l: int = int(build.get(&"tire", 0))
	var b: int = int(build.get(&"body", 0))
	s.peak_torque_nm *= (1.0 + MOTOR_TORQUE[m] * float(p["motor"])) * (1.0 + TURBO_TORQUE[t] * float(p["turbo"])) \
		* (1.0 + AIR_TORQUE[a] * float(p["air"]))
	s.peak_torque_rpm *= 1.0 + TURBO_LAG[t] * float(p["lag"])
	var rev: float = 1.0 + AIR_REV[a] * float(p["rev"])
	s.redline_rpm *= rev
	s.peak_power_rpm *= rev
	s.peak_torque_rpm = minf(s.peak_torque_rpm, s.peak_power_rpm * 0.92)
	s.launch_rpm = s.peak_torque_rpm * 1.08   # EngineSpec.derive ile aynı kural
	# Dönen kütle (hafif jant, hafif volan): ivmeye giren kütle azalır, çekişi belirleyen ağırlık aynı kalır
	# → kütle düşer, tutuş katsayısı aynı oranda yükselir (çekiş kuvveti değişmez).
	var inertia: float = 1.0 - TIRE_INERTIA[l] - GEAR_INERTIA[g]
	s.mass *= (1.0 - BODY_MASS[b]) * inertia
	s.grip_mu *= (1.0 + TIRE_GRIP[l]) / inertia
	s.frontal_area *= 1.0 - BODY_DRAG[b]
	s.shift_time_scale = GEAR_SHIFT[g]
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


## Motor profili: katalogdaki motor adı + yıl.
static func profile_of(vehicle_id: StringName) -> StringName:
	var entry: Dictionary = CarCatalog.get_entry(vehicle_id)
	var engine: String = String(entry.get("performance", {}).get("engine", "")).to_lower()
	var year: int = int(entry.get("year", 2000))
	if engine.begins_with("elektrik"):
		return &"elektrik"
	if engine.contains("tdi") or engine.contains("crdi"):
		return &"turbo_dizel"
	if engine.contains("dizel"):
		return &"dizel"
	if engine.contains("turbo") or engine.contains("tsi") or engine.contains("tfsi") or engine.ends_with("t"):
		return &"turbo_benzin"
	return &"klasik" if year < 1980 else &"atmosferik"


# --- Adlar, fiyat, kilit -------------------------------------------------------------------

static func category_name(vehicle_id: StringName, category: StringName) -> String:
	var own: Dictionary = PROFILE_CATEGORY_NAMES.get(profile_of(vehicle_id), {})
	return Loc.t(String(own.get(category, CATEGORY_NAMES.get(category, String(category)))))


## Kademenin parça adı (stage 1..5).
static func part_name(vehicle_id: StringName, category: StringName, stage: int) -> String:
	var own: Dictionary = PROFILE_PART_NAMES.get(profile_of(vehicle_id), {})
	var names: Array = own.get(category, PART_NAMES.get(category, []))
	var i: int = clampi(stage, 1, STAGES) - 1
	return Loc.t(String(names[i])) if i < names.size() else ""


## Kademenin parça ikonu (yoksa null).
static func part_icon(vehicle_id: StringName, category: StringName, stage: int) -> Texture2D:
	var own: Dictionary = PROFILE_PART_ICONS.get(profile_of(vehicle_id), {})
	var ids: Array = own.get(category, PART_ICONS.get(category, []))
	var i: int = clampi(stage, 1, STAGES) - 1
	if i >= ids.size():
		return null
	var path: String = ICON_DIR + String(ids[i]) + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


static func tier_name(stage: int) -> String:
	return Loc.t(TIER_NAMES[clampi(stage, 1, STAGES) - 1])


static func tier_color(stage: int) -> Color:
	return TIER_COLORS[clampi(stage, 1, STAGES) - 1]


## Bu kademenin parçasının fiyatı (₺).
static func price(vehicle_id: StringName, category: StringName, stage: int) -> int:
	var i: int = clampi(stage, 1, STAGES) - 1
	var car_price: float = float(CarCatalog.get_entry(vehicle_id).get("price", 0))
	var raw: float = maxf(float(PRICE_FLOOR[i]), car_price * PRICE_RATE[i]) * float(PRICE_WEIGHT.get(category, 1.0))
	return int(roundf(raw / 50.0)) * 50


static func install_time(stage: int) -> float:
	return INSTALL_TIME[clampi(stage, 1, STAGES) - 1]


static func required_level(stage: int) -> int:
	return TIER_LEVEL[clampi(stage, 1, STAGES) - 1]


# --- Ölçüm ve gösterge -------------------------------------------------------------------------

## Kusursuz kalkış + kusursuz vitesler: karşılaştırma süresi (bant ortalaması) ve 300 m.
static func measure(vehicle_id: StringName, build: Dictionary) -> Dictionary:
	var clean: Dictionary = normalized(build)
	var key: String = String(vehicle_id) + "|" + build_key(clean)
	if _measures.has(key):
		return _measures[key]
	var spec: DragRaceSim.EngineSpec = spec_with(vehicle_id, clean)
	var vref: float = _reference_speed(vehicle_id)
	var runner: DragRaceSim.Runner = DragRaceSim.Runner.new()
	runner.setup_spec(spec, null)
	runner.rpm = spec.launch_rpm
	runner.launch()
	var t: float = 0.0
	var tref: float = -1.0
	var band_sum: float = 0.0
	var band_count: int = 0
	var prev_speed: float = 0.0
	var t300: float = -1.0
	var spin: float = 0.0
	while (t300 < 0.0 or tref < 0.0) and t < SINGLE_LIMIT:
		t += DragRaceSim.STEP
		runner.step(DragRaceSim.STEP, t)
		while band_count < REF_BAND and runner.speed >= vref * _band_fraction(band_count):
			var target: float = vref * _band_fraction(band_count)
			var k: float = clampf((target - prev_speed) / maxf(runner.speed - prev_speed, 0.0001), 0.0, 1.0)
			band_sum += t - DragRaceSim.STEP * (1.0 - k)
			band_count += 1
		prev_speed = runner.speed
		if tref < 0.0 and band_count == REF_BAND:
			tref = band_sum / float(REF_BAND)
		if t300 < 0.0 and runner.finish_time >= 0.0:
			t300 = runner.finish_time
			spin = runner.spin_time
		if runner.finish_time >= 0.0:
			runner.finish_time = -1.0   # 300 m'de durma: yavaş araç karşılaştırma hızına sonra ulaşır
			runner.distance = 0.0
		if runner.gear < runner.top_gear() and not runner.shifting and runner.rpm >= spec.shift_rpm[runner.gear]:
			runner.shift()
	var base: DragRaceSim.EngineSpec = DragRaceSim.spec_of(vehicle_id)
	var power: float = spec.peak_torque_nm * spec.peak_power_rpm / (base.peak_torque_nm * base.peak_power_rpm)
	var drag: float = spec.frontal_area / base.frontal_area
	var top: float = pow(power / drag, 1.0 / 3.0) * (1.0 + GEAR_TOP_DISPLAY[int(clean.get(&"gear", 0))])
	var out: Dictionary = {"tref": maxf(tref, 0.001), "t300": t300 if t300 > 0.0 else SINGLE_LIMIT, "spin": spin,
		"power": power,
		"top": top}
	_measures[key] = out
	return out


## Bu yapı ölçülmüş mü (önbellekte)? Arayüz ölçülmemiş önizlemeleri kare kare hesaplar (telefonda takılmasın).
static func is_measured(vehicle_id: StringName, build: Dictionary) -> bool:
	return _measures.has(String(vehicle_id) + "|" + build_key(normalized(build)))


## Fabrikaya göre gösterilen 0-100 oranı, ölçülen haliyle (taban uygulanmamış).
static func zero_100_ratio(vehicle_id: StringName, build: Dictionary) -> float:
	return float(measure(vehicle_id, build)["tref"]) / float(measure(vehicle_id, {})["tref"])


## EKRANDAKİ DEĞERLER. 0-100 / son hız / beygir gerçek katalog değerinin ölçülmüş oranla çarpımı; 300 m,
## GENEL ve sınıf oyunun gerçek yarış sonucu. floor_ratio: gösterilen 0-100 oranı bunun üstüne çıkmaz
## (gösterge asla kötüleşmez — zaten patinaj yapan araçta fazladan güç bant ortalamasında ≤0,005 sn
## kaybettirebilir; fiziksel olarak doğru ama "para verdim kötüleşti" hissi yanlış).
static func stats_with(vehicle_id: StringName, build: Dictionary, floor_ratio: float = 1.0) -> Dictionary:
	var perf: Dictionary = CarCatalog.get_entry(vehicle_id).get("performance", {})
	var m: Dictionary = measure(vehicle_id, build)
	var ratio: float = minf(zero_100_ratio(vehicle_id, build), floor_ratio)
	var t300: float = float(m["t300"])
	return {
		"zero_100": float(perf.get("zero_100", 0.0)) * ratio,
		"zero_100_ratio": ratio,
		"top_speed": float(perf.get("top_speed", 0.0)) * float(m["top"]),
		"hp": float(perf.get("hp", 0)) * float(m["power"]),
		"time_300": t300,
		"overall": DragRaceSim.overall_from_time(t300),
		"class": class_for(vehicle_id, t300),
	}


## Oyuncu aracının güncel değerleri (yapı + gösterge tabanı).
static func stats(vehicle_id: StringName) -> Dictionary:
	return stats_with(vehicle_id, _builds.get(vehicle_id, {}), display_floor(vehicle_id))


## Bir kategoriye sıradaki kademe takılınca değerler (önce → sonra önizlemesi). Gösterge kötüleşmez.
static func preview(vehicle_id: StringName, category: StringName) -> Dictionary:
	var current: Dictionary = stats(vehicle_id)
	var stage: int = stage_of(vehicle_id, category)
	if stage >= STAGES:
		return current
	var next: Dictionary = with_stage(_builds.get(vehicle_id, {}), category, stage + 1)
	return stats_with(vehicle_id, next, float(current["zero_100_ratio"]))


## Yarış sunumunun (egzoz alevi, motor sesi, pist akışı) performans oranı: modifiyeli 0-100'den.
static func performance_ratio(vehicle_id: StringName) -> float:
	if not _builds.has(vehicle_id):
		return DragRaceSim.performance_ratio(vehicle_id)
	var zero_100: float = float(stats(vehicle_id)["zero_100"])
	return DragRaceSim.performance_ratio_of(zero_100) if zero_100 > 0.0 else DragRaceSim.performance_ratio(vehicle_id)


## --- Parça plakası: etkinin tarifi, teknik değerler, güç eğrisi, öneri ---

## Kademenin ÖNCEKİ kademeye göre fiziksel etkisi, bu aracın motor profiliyle ("Tork +%1,5 · bütün devir bandı").
static func effect_text(vehicle_id: StringName, category: StringName, stage: int) -> String:
	var p: Dictionary = PROFILES[profile_of(vehicle_id)]
	var s: int = clampi(stage, 1, STAGES)
	var d: Callable = func(table: Array[float], scale: float = 1.0) -> float:
		return (table[s] - table[s - 1]) * scale * 100.0
	var pct: Callable = func(value: float) -> String:
		return ("%.1f" % absf(value)).replace(".", ",") if Loc.current() != "en" else "%.1f" % absf(value)
	var parts: PackedStringArray = PackedStringArray()
	match category:
		&"motor":
			parts.append(Loc.t("Tork +%%%s") % pct.call(d.call(MOTOR_TORQUE, float(p["motor"]))))
			parts.append(Loc.t("bütün devir bandı"))
		&"turbo":
			parts.append(Loc.t("Tork +%%%s") % pct.call(d.call(TURBO_TORQUE, float(p["turbo"]))))
			if float(p["lag"]) > 0.0:
				parts.append(Loc.t("tepe tork %%%s yukarı (gecikme)") % pct.call(d.call(TURBO_LAG, float(p["lag"]))))
		&"air":
			if float(p["rev"]) > 0.0:
				parts.append(Loc.t("Devir sınırı +%%%s") % pct.call(d.call(AIR_REV, float(p["rev"]))))
			parts.append(Loc.t("tork +%%%s") % pct.call(d.call(AIR_TORQUE, float(p["air"]))))
		&"gear":
			parts.append(Loc.t("Vites geçişi −%d ms") % roundi(85.0 * (GEAR_SHIFT[s - 1] - GEAR_SHIFT[s])))
			parts.append(Loc.t("son vites +%%%s") % pct.call(d.call(GEAR_RACE_TOP)))
			if GEAR_INERTIA[s] > GEAR_INERTIA[s - 1]:
				parts.append(Loc.t("hafif volan"))
			if GEAR_LOW[s] > GEAR_LOW[s - 1]:
				parts.append(Loc.t("kısa alt vitesler"))
		&"tire":
			parts.append(Loc.t("Tutuş +%%%s") % pct.call(d.call(TIRE_GRIP)))
			if TIRE_INERTIA[s] > TIRE_INERTIA[s - 1]:
				parts.append(Loc.t("dönen kütle −%%%s") % pct.call(d.call(TIRE_INERTIA)))
		&"body":
			parts.append(Loc.t("Ağırlık −%%%s") % pct.call(d.call(BODY_MASS)))
			if BODY_DRAG[s] > BODY_DRAG[s - 1]:
				parts.append(Loc.t("hava direnci −%%%s") % pct.call(d.call(BODY_DRAG)))
	return " · ".join(parts)


## Parça plakasının teknik satırları (bu yapıyla): tork / devir sınırı (gösterge ölçeğinde), vites geçişi (ms),
## tutuş (fabrikaya göre %), ağırlık (kg), hava direnci (%), kalkış patinajı (sn).
static func tech(vehicle_id: StringName, build: Dictionary) -> Dictionary:
	var base: DragRaceSim.EngineSpec = DragRaceSim.spec_of(vehicle_id)
	var spec: DragRaceSim.EngineSpec = spec_with(vehicle_id, build)
	var clean: Dictionary = normalized(build)
	var b: int = int(clean.get(&"body", 0))
	var curve: Dictionary = power_curve(vehicle_id, clean)
	return {
		"torque": spec.peak_torque_nm * float(curve["scale"]),
		"redline": spec.redline_rpm,
		"shift_ms": 85.0 * spec.shift_time_scale,
		"grip": (spec.grip_mu / base.grip_mu - 1.0) * 100.0,
		"mass": base.mass * (1.0 - BODY_MASS[b]),
		"drag": (spec.frontal_area / base.frontal_area - 1.0) * 100.0,
		"spin": float(measure(vehicle_id, clean).get("spin", 0.0)) if is_measured(vehicle_id, clean) else -1.0,
	}


## GÜÇ EĞRİSİ (dinamometre): devir → beygir, gösterge ölçeğinde (fabrika tepe gücü = katalog beygiri).
## {"points": PackedVector2Array (rpm, bg), "peak": bg, "peak_rpm": rpm, "scale": tork ölçeği}
static func power_curve(vehicle_id: StringName, build: Dictionary, samples: int = 40) -> Dictionary:
	var base: DragRaceSim.EngineSpec = DragRaceSim.spec_of(vehicle_id)
	var spec: DragRaceSim.EngineSpec = spec_with(vehicle_id, build)
	var catalog_hp: float = float(CarCatalog.get_entry(vehicle_id).get("performance", {}).get("hp", 0))
	var stock_peak: float = 0.0
	for i: int in samples:
		var rpm: float = lerpf(base.idle_rpm, base.redline_rpm, float(i) / float(samples - 1))
		stock_peak = maxf(stock_peak, DragRaceSim.torque_fraction(rpm, base) * base.peak_torque_nm * rpm / 7121.0)
	var scale: float = catalog_hp / stock_peak if catalog_hp > 0.0 and stock_peak > 0.0 else 1.0
	var points: PackedVector2Array = PackedVector2Array()
	var peak: float = 0.0
	var peak_rpm: float = 0.0
	for i: int in samples:
		var rpm: float = lerpf(spec.idle_rpm, spec.redline_rpm * 0.999, float(i) / float(samples - 1))
		var hp: float = DragRaceSim.torque_fraction(rpm, spec) * spec.peak_torque_nm * rpm / 7121.0 * scale
		points.append(Vector2(rpm, hp))
		if hp > peak:
			peak = hp
			peak_rpm = rpm
	return {"points": points, "peak": peak, "peak_rpm": peak_rpm, "scale": scale}


## ÖNERİLEN: sıradaki kademesi alınabilecek kategoriler arasında ₺ başına en çok 300 m kazandıran (yarışın
## kendisi). Ölçülmemiş yapı varsa ölçer — çağıran ölçümleri önceden ısıtmalıdır (is_measured).
static func recommend(vehicle_id: StringName) -> StringName:
	var build: Dictionary = _builds.get(vehicle_id, {})
	var now: float = float(measure(vehicle_id, build)["t300"])
	var best: StringName = &""
	var best_value: float = 0.0
	for category: StringName in CATEGORIES:
		var stage: int = stage_of(vehicle_id, category) + 1
		if stage > STAGES:
			continue
		var gain: float = now - float(measure(vehicle_id, with_stage(build, category, stage))["t300"])
		var value: float = gain / float(maxi(price(vehicle_id, category, stage), 1))
		if value > best_value:
			best_value = value
			best = category
	return best


## Oyuncu aracının kusursuz 300 m süresi (rakip havuzu ve GENEL bunu kullanır).
static func time_300(vehicle_id: StringName) -> float:
	if not _builds.has(vehicle_id):
		return DragRaceSim.base_time(vehicle_id)
	return float(measure(vehicle_id, _builds[vehicle_id])["t300"])


static func overall(vehicle_id: StringName) -> int:
	return DragRaceSim.overall_from_time(time_300(vehicle_id))


## Oyuncu aracının sınıfı: modifiyeli 300 m süresinin yetiştiği en yüksek sınıf (katalog sınıfının altına inmez).
static func class_of(vehicle_id: StringName) -> String:
	return class_for(vehicle_id, time_300(vehicle_id))


static func class_for(vehicle_id: StringName, t300: float) -> String:
	var own: String = String(CarCatalog.get_entry(vehicle_id).get("class", "D"))
	var own_rank: int = maxi(CLASSES.find(own), 0)
	var thresholds: Dictionary = class_thresholds()
	for i: int in CLASSES.size() - 1:
		if i < own_rank and t300 <= float(thresholds.get(CLASSES[i], 0.0)) + 0.0001:
			return CLASSES[i]
	return own


## Sınıf eşikleri: sınıfın en yavaş fabrika aracının kusursuz 300 m süresi. Yeni araç eklenince kendiliğinden kayar.
static func class_thresholds() -> Dictionary:
	if _thresholds.is_empty():
		for entry: Dictionary in CarCatalog.all():
			var klass: String = String(entry.get("class", ""))
			var t: float = DragRaceSim.base_time(entry["id"])
			if CLASSES.has(klass) and t > float(_thresholds.get(klass, 0.0)):
				_thresholds[klass] = t
	return _thresholds


## 0-100 karşılaştırma hızı: 100 km/sa; aracın ona hiç ya da çok geç vardığı yerde fabrika tepe hızının %75'i
## (Fiat 500'ün gerçek son hızı 95 km/sa). Fabrika künyesinden, araç başına bir kez.
static func _reference_speed(vehicle_id: StringName) -> float:
	if _vref.has(vehicle_id):
		return _vref[vehicle_id]
	var base: DragRaceSim.EngineSpec = DragRaceSim.spec_of(vehicle_id)
	var runner: DragRaceSim.Runner = DragRaceSim.Runner.new()
	runner.setup_spec(base, null)
	runner.rpm = base.launch_rpm
	runner.launch()
	var t: float = 0.0
	var vmax: float = 0.0
	var found: float = -1.0
	while t < SINGLE_LIMIT:
		t += DragRaceSim.STEP
		runner.finish_time = -1.0
		runner.distance = 0.0
		runner.step(DragRaceSim.STEP, t)
		vmax = maxf(vmax, runner.speed)
		if runner.speed >= 100.0 / 3.6:
			found = 100.0 / 3.6
			break
		if runner.gear < runner.top_gear() and not runner.shifting and runner.rpm >= base.shift_rpm[runner.gear]:
			runner.shift()
	_vref[vehicle_id] = found if found > 0.0 else vmax * 0.75
	return _vref[vehicle_id]


static func _band_fraction(i: int) -> float:
	return 0.5 + 0.5 * float(i) / float(REF_BAND - 1)
