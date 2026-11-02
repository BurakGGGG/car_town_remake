class_name EngineBank
extends Resource
## PİŞMİŞ MOTOR SESİ (2026-11-02): bir aracın bütün motor sesleri tek dosyada — res://vehicles/sound/banks/<id>.res.
## MOTOR SES LABORATUVARI (ya da tools/engine_lab/bake_all.gd) EnginePreset'ten EngineSynth ile üretir ve QOA
## sıkıştırmalı kaydeder; oyun yalnız bunu yükler ve EngineVoice ile çalar (oyunda sentez yok).
##
## İçerik: devir katmanları (rpms) × {gaz açık (on), gaz kesik (off)} döngüleri, marş (rölantiye oturduğu an
## start_idle_at), kontak kapatma, 3 egzoz patlaması, blow-off, turbo ıslığı döngüsü; oynatıcının ihtiyaç duyduğu
## ayarlar `runtime` sözlüğünde (RUNTIME_KEYS).

const BANK_DIR: String = "res://vehicles/sound/banks/"
## Ön ayardan oynatıcıya taşınan alanlar (EngineVoice okur).
const RUNTIME_KEYS: Array[String] = ["idle_rpm", "redline_rpm", "turbo", "whistle_db", "spool_rpm", "spool_lag",
	"blowoff_db", "crackle", "crackle_db", "decel_pops", "pop_interval", "pop_rpm", "limiter_hz", "limiter_duty", "level_db",
	"layout"]
## Bütün bankaların ortak gürlük hedefi: kırmızı çizgideki gaz açık katmanın RMS'i (diğerleri ön ayarın düzey
## parametrelerine göre bunun altında).
const TARGET_RMS: float = 0.17
const POP_VARIANTS: int = 3

@export var vehicle_id: StringName = &""
## Laboratuvarda elle ayarlanmış ön ayardan mı pişti (yoksa otomatik).
@export var custom: bool = false
@export var rpms: PackedFloat32Array = PackedFloat32Array()
@export var on_loops: Array[AudioStreamWAV] = []
@export var off_loops: Array[AudioStreamWAV] = []
## Katmanların gürlüğü (dB, kırmızı çizgideki gaz açık katmana göre; ≤ 0): pişirmede tam bu düzeye oturtulur;
## oynatıcı dinamiği sıkıştırırken kullanır.
@export var on_db: PackedFloat32Array = PackedFloat32Array()
@export var off_db: PackedFloat32Array = PackedFloat32Array()
@export var start: AudioStreamWAV
@export var start_idle_at: float = 0.0
@export var stop: AudioStreamWAV
@export var pops: Array[AudioStreamWAV] = []
@export var blowoff: AudioStreamWAV
@export var whistle: AudioStreamWAV
@export var runtime: Dictionary = {}
## Pişirmede kullanılan ön ayarın tamamı (laboratuvar kıyas / geri dönüş için).
@export var preset: Dictionary = {}

static var _cache: Dictionary = {}


static func bank_path(id: StringName) -> String:
	return BANK_DIR + String(id) + ".res"


static func has_bank(id: StringName) -> bool:
	return ResourceLoader.exists(bank_path(id))


## Aracın pişmiş bankası (önbellekli); yoksa null.
static func for_vehicle(id: StringName) -> EngineBank:
	if _cache.has(id):
		return _cache[id]
	if not has_bank(id):
		return null
	var bank: EngineBank = load(bank_path(id)) as EngineBank
	if bank:
		_cache[id] = bank
	return bank


## Arka planda yükleme isteği (trafik aracı doğmadan önce): sonraki for_vehicle beklemeden döner.
static func prefetch(id: StringName) -> void:
	if _cache.has(id) or not has_bank(id):
		return
	ResourceLoader.load_threaded_request(bank_path(id), "", false, ResourceLoader.CACHE_MODE_REUSE)


static func forget(id: StringName) -> void:
	_cache.erase(id)


func is_electric() -> bool:
	return String(runtime.get("layout", "")) == "ev"


func idle_rpm() -> float:
	return float(runtime.get("idle_rpm", 800.0))


func redline_rpm() -> float:
	return float(runtime.get("redline_rpm", 6500.0))


func get_runtime(key: String, fallback: float) -> float:
	return float(runtime.get(key, fallback))


# --- Pişirme ----------------------------------------------------------------------------------------------------

## Ön ayardan bankayı üretir (sırayla). `compress`: QOA (oyun dosyası); false = PCM (laboratuvarda hızlı dinleme).
## Laboratuvar aynı işleri (jobs) iş parçacıklarına dağıtıp assemble() ile birleştirir.
static func build(id: StringName, source: Dictionary, compress: bool) -> EngineBank:
	var p: Dictionary = EnginePreset.sanitize(source)
	var jobs: Array = jobs_for(p)
	var results: Array = []
	for job: Array in jobs:
		results.append(run_job(p, job))
	return assemble(id, p, jobs, results, compress)


## Pişirme işleri: [tür, katman sırası]. Her iş bağımsız (iş parçacığında koşabilir; EngineSynth.prepare() önce).
static func jobs_for(p: Dictionary) -> Array:
	var jobs: Array = []
	for i: int in EngineSynth.layer_rpms(p).size():
		jobs.append(["on", i])
		jobs.append(["off", i])
	jobs.append(["start", 0])
	jobs.append(["stop", 0])
	jobs.append(["pops", 0])
	jobs.append(["turbo", 0])
	return jobs


static func run_job(p: Dictionary, job: Array) -> Variant:
	var index: int = job[1]
	match String(job[0]):
		"on":
			return EngineSynth.render_loop(p, EngineSynth.layer_rpms(p)[index], 1.0, 100 + index)
		"off":
			return EngineSynth.render_loop(p, EngineSynth.layer_rpms(p)[index], float(p["off_load"]), 200 + index)
		"start":
			return EngineSynth.render_start(p, 300)
		"stop":
			return EngineSynth.render_stop(p, 301)
		"pops":
			var pops: Array = []
			for v: int in POP_VARIANTS:
				pops.append(EngineSynth.render_pop(p, v))
			return pops
		"turbo":
			if float(p["turbo"]) <= 0.0:
				return []
			return [EngineSynth.render_blowoff(p), EngineSynth.render_whistle(p)]
	return null


## İş sonuçlarını bankaya dönüştürür: ortak ölçek (en gür gaz açık katmanı), son doyum, hedef gürlük, akışlar.
static func assemble(id: StringName, p: Dictionary, jobs: Array, results: Array, compress: bool) -> EngineBank:
	var bank: EngineBank = EngineBank.new()
	bank.vehicle_id = id
	bank.preset = p
	bank.rpms = EngineSynth.layer_rpms(p)
	var rate: int = int(p["rate"])
	var on_raw: Array[PackedFloat32Array] = []
	var off_raw: Array[PackedFloat32Array] = []
	on_raw.resize(bank.rpms.size())
	off_raw.resize(bank.rpms.size())
	var start_pair: Array = []
	var stop_raw: PackedFloat32Array = PackedFloat32Array()
	var pops: Array = []
	var turbo: Array = []
	for j: int in jobs.size():
		var job: Array = jobs[j]
		match String(job[0]):
			"on":
				on_raw[int(job[1])] = (results[j] as PackedFloat32Array).duplicate()
			"off":
				off_raw[int(job[1])] = (results[j] as PackedFloat32Array).duplicate()
			"start":
				start_pair = results[j]
			"stop":
				stop_raw = (results[j] as PackedFloat32Array).duplicate()
			"pops":
				pops = results[j]
			"turbo":
				turbo = results[j]
	# Son doyum: bütün katmanlar aynı ölçekle (doyum miktarı tutarlı). Sonra her katmanın gürlüğü ön ayarın DÜZEY
	# parametrelerine tam oturtulur: gaz açık = devirle yükselme eğrisi (kırmızı çizgide 0 dB), gaz kesik = aynı
	# devirde off_db kadar kısık. (Sentezin kendi düzey farkları burada ezilir: "gaz kesik düzeyi −7 dB" tam −7 dB.)
	var calib: float = EngineSynth.calibrate(on_raw)
	var idle: float = bank.rpms[0]
	var red: float = maxf(bank.rpms[bank.rpms.size() - 1], idle + 1.0)
	var slope: float = p["rpm_slope_db"]
	var off_level: float = p["off_db"]
	var off0_gain: float = 1.0
	for i: int in bank.rpms.size():
		var on_target: float = slope * (clampf((bank.rpms[i] - idle) / (red - idle), 0.0, 1.0) - 1.0)
		var off_target: float = on_target + off_level
		var on_layer: PackedFloat32Array = EngineSynth.finish(on_raw[i], p, calib)
		var off_layer: PackedFloat32Array = EngineSynth.finish(off_raw[i], p, calib)
		var off_gain: float = TARGET_RMS * db_to_linear(off_target) / maxf(EngineSynth.rms(off_layer), 1e-6)
		if i == 0:
			off0_gain = off_gain
		bank.on_db.append(on_target)
		bank.off_db.append(off_target)
		bank.on_loops.append(to_stream(_scale(on_layer, TARGET_RMS * db_to_linear(on_target) / maxf(EngineSynth.rms(on_layer), 1e-6)),
			rate, true, compress))
		bank.off_loops.append(to_stream(_scale(off_layer, off_gain), rate, true, compress))
	# Marş rölantiye oturarak biter, kapatma rölantiden başlar: ikisi de rölanti katmanının (gaz kesik, 0) ölçeğiyle
	var start_raw: PackedFloat32Array = (start_pair[0] as PackedFloat32Array).duplicate()
	bank.start = to_stream(_scale(EngineSynth.finish(start_raw, p, calib), off0_gain), rate, false, compress)
	bank.start_idle_at = float(start_pair[1])
	bank.stop = to_stream(_scale(EngineSynth.finish(stop_raw, p, calib), off0_gain), rate, false, compress)
	for pop: PackedFloat32Array in pops:
		bank.pops.append(to_stream(pop, rate, false, compress))
	if turbo.size() == 2:
		bank.blowoff = to_stream(turbo[0], rate, false, compress)
		bank.whistle = to_stream(turbo[1], rate, true, compress)
	for key: String in RUNTIME_KEYS:
		bank.runtime[key] = p[key]
	return bank


static func _scale(samples: PackedFloat32Array, gain: float) -> PackedFloat32Array:
	for i: int in samples.size():
		samples[i] = clampf(samples[i] * gain, -0.98, 0.98)
	return samples


## Bankayı res://vehicles/sound/banks/<id>.res olarak kaydeder.
func save_to_disk() -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BANK_DIR))
	var path: String = bank_path(vehicle_id)
	var err: Error = ResourceSaver.save(self, path, ResourceSaver.FLAG_COMPRESS)
	if err == OK:
		_cache[vehicle_id] = self
	return err


## Örneklerden AudioStreamWAV. Döngüde LoopedWav'ın kuralı: sona ilk iki örneğin kopyası eklenir, loop_end eski
## örnek sayısı (karıştırıcı loop_end örneğini ve bir sonrakini de okur — veri dışına taşmasın). `compress`: QOA
## (Godot'nun WAV içe aktarıcısıyla aynı kodlayıcı; AudioStreamWAV.load_from_buffer).
static func to_stream(samples: PackedFloat32Array, rate: int, loop: bool, compress: bool) -> AudioStreamWAV:
	var frames: int = samples.size()
	var data: PackedFloat32Array = samples.duplicate()
	if loop and frames > 2:
		data.append(samples[0])
		data.append(samples[1])
	var pcm: PackedByteArray = PackedByteArray()
	pcm.resize(data.size() * 2)
	for i: int in data.size():
		pcm.encode_s16(i * 2, int(clampf(data[i], -1.0, 1.0) * 32767.0))
	var wav: AudioStreamWAV
	if compress:
		wav = AudioStreamWAV.load_from_buffer(_riff(pcm, rate), {"compress/mode": 2, "edit/loop_mode": 1})
	else:
		wav = AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = rate
		wav.stereo = false
		wav.data = pcm
	if loop and frames > 2:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = frames
	else:
		wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return wav


## 16 bit tek kanal PCM için RIFF/WAVE baytları.
static func _riff(pcm: PackedByteArray, rate: int) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.append_array("RIFF".to_ascii_buffer())
	var head: PackedByteArray = PackedByteArray()
	head.resize(4)
	head.encode_u32(0, 36 + pcm.size())
	out.append_array(head)
	out.append_array("WAVEfmt ".to_ascii_buffer())
	var fmt: PackedByteArray = PackedByteArray()
	fmt.resize(20)
	fmt.encode_u32(0, 16)
	fmt.encode_u16(4, 1)          # PCM
	fmt.encode_u16(6, 1)          # tek kanal
	fmt.encode_u32(8, rate)
	fmt.encode_u32(12, rate * 2)  # bayt / sn
	fmt.encode_u16(16, 2)         # blok
	fmt.encode_u16(18, 16)        # bit
	out.append_array(fmt)
	out.append_array("data".to_ascii_buffer())
	var size: PackedByteArray = PackedByteArray()
	size.resize(4)
	size.encode_u32(0, pcm.size())
	out.append_array(size)
	out.append_array(pcm)
	return out


## Dinleme / QA: bir örnek dizisini 16 bit WAV dosyasına yazar.
static func write_wav(path: String, samples: PackedFloat32Array, rate: int) -> Error:
	var pcm: PackedByteArray = PackedByteArray()
	pcm.resize(samples.size() * 2)
	for i: int in samples.size():
		pcm.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(_riff(pcm, rate))
	return OK
