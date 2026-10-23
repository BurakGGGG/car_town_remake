class_name AudioCache
extends RefCounted
## KODLA ÜRETİLEN SESLERİN DİSK ÖNBELLEĞİ (2026-10-23, optimizasyon turu): şehir ortam sesi (uğultu, kuş, korna, motor
## bankası), polis sireni, gazete / para / trafik sesleri her açılışta arka planda sentezleniyordu — masaüstünde tek
## iş parçacığında ~1,3 sn, telefonda birkaç katı (pil, ısınma, yükleme sırasında çekirdek yarışı). Artık SÜRÜM BAŞINA
## bir kez üretilip user://audio_cache/ altına yazılır; sonraki açılışlar aynı PCM baytlarını okur (ses bayt bayt aynı).
##
## Anahtar = paketin sürüm kodu (AppInfo) + motor sürümü: güncelleme gelince sesler bir kez yeniden üretilir, eski
## dosyalar silinir. Geliştirme sürümünde (editör / masaüstü / testler, sürüm kodu 0) KAPALI: sentez kodu değişince
## bayat ses çalınmasın. Testler `force` ile açar (tests/audio_cache_test.gd). İş parçacığından çağrılabilir.

const DIR: String = "user://audio_cache/"
## Testler: sürüm kodu olmadan da önbelleği kullan.
static var force: bool = false

static var _lock: Mutex = Mutex.new()


## `build`'in döndürdüğü değeri (AudioStreamWAV, dizileri / sözlükleri) önbellekten verir; yoksa üretip yazar.
static func fetch(name: String, build: Callable) -> Variant:
	var key: String = _cache_key()
	if key.is_empty():
		return build.call()
	var path: String = DIR + "%s-%s.bin" % [name, key]
	if FileAccess.file_exists(path):
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		var stored: Variant = bytes_to_var(bytes) if not bytes.is_empty() else null
		if stored is Dictionary and (stored as Dictionary).get("v") == 1:
			return _decode((stored as Dictionary)["data"])
	var value: Variant = build.call()
	_write(name, path, var_to_bytes({"v": 1, "data": _encode(value)}))
	return value


static func _cache_key() -> String:
	var code: int = AppInfo.version_code()
	if code <= 0 and not force:
		return ""
	var engine: Dictionary = Engine.get_version_info()
	return "c%d-g%d.%d.%d" % [code, int(engine["major"]), int(engine["minor"]), int(engine["patch"])]


## Geçici dosyaya yazıp yerine koyar (yarım dosya kalmaz); aynı adın eski sürüm dosyaları silinir.
static func _write(name: String, path: String, bytes: PackedByteArray) -> void:
	_lock.lock()
	DirAccess.make_dir_recursive_absolute(DIR)
	var tmp: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if file:
		file.store_buffer(bytes)
		file.close()
		DirAccess.rename_absolute(tmp, path)
		for old: String in DirAccess.get_files_at(DIR):
			if old.begins_with(name + "-") and DIR + old != path:
				DirAccess.remove_absolute(DIR + old)
	_lock.unlock()


## AudioStreamWAV → düz sözlük (biçim + PCM baytları); diziler türüyle (Array[AudioStreamWAV]) korunur.
static func _encode(value: Variant) -> Variant:
	if value is AudioStreamWAV:
		var wav: AudioStreamWAV = value
		return {"wav": [wav.format, wav.mix_rate, wav.stereo, wav.loop_mode, wav.loop_begin, wav.loop_end, wav.data]}
	if value is Array:
		var list: Array = value
		var out: Array = []
		for item: Variant in list:
			out.append(_encode(item))
		return {"array": out, "typed": list.is_typed() and list.get_typed_class_name() == &"AudioStreamWAV"}
	if value is Dictionary:
		var out: Dictionary = {}
		for k: Variant in value:
			out[k] = _encode(value[k])
		return {"dict": out}
	return {"value": value}


static func _decode(value: Variant) -> Variant:
	var box: Dictionary = value
	if box.has("wav"):
		var f: Array = box["wav"]
		var wav: AudioStreamWAV = AudioStreamWAV.new()
		wav.format = f[0]
		wav.mix_rate = f[1]
		wav.stereo = f[2]
		wav.loop_mode = f[3]
		wav.loop_begin = f[4]
		wav.loop_end = f[5]
		wav.data = f[6]
		return wav
	if box.has("array"):
		var out: Array = Array([], TYPE_OBJECT, &"AudioStreamWAV", null) if box["typed"] else []
		for item: Variant in box["array"]:
			out.append(_decode(item))
		return out
	if box.has("dict"):
		var out: Dictionary = {}
		var src: Dictionary = box["dict"]
		for k: Variant in src:
			out[k] = _decode(src[k])
		return out
	return box["value"]
