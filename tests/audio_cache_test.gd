extends SceneTree
## SES ÖNBELLEĞİ (AudioCache, 2026-10-23): geliştirme sürümünde kapalı; açıkken ilk çağrı sentezler ve yazar, ikinci
## çağrı diskten okur — her ses (biçim, örnekleme, döngü, PCM baytları) ve dizi türleri (Array[AudioStreamWAV]) aynı.
## Çalıştırma: tools/run_tests.sh audio_cache_test

var fails: int = 0


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


## Derin eşitlik: AudioStreamWAV alan alan, diziler türüyle, sözlükler anahtarıyla.
func same(a: Variant, b: Variant) -> bool:
	if a is AudioStreamWAV and b is AudioStreamWAV:
		var x: AudioStreamWAV = a
		var y: AudioStreamWAV = b
		return x.format == y.format and x.mix_rate == y.mix_rate and x.stereo == y.stereo and x.loop_mode == y.loop_mode \
			and x.loop_begin == y.loop_begin and x.loop_end == y.loop_end and x.data == y.data
	if a is Array and b is Array:
		var p: Array = a
		var q: Array = b
		if p.size() != q.size() or p.is_typed() != q.is_typed() or p.get_typed_class_name() != q.get_typed_class_name():
			return false
		for i: int in p.size():
			if not same(p[i], q[i]):
				return false
		return true
	if a is Dictionary and b is Dictionary:
		if (a as Dictionary).size() != (b as Dictionary).size():
			return false
		for k: Variant in a:
			if not (b as Dictionary).has(k) or not same(a[k], b[k]):
				return false
		return true
	return typeof(a) == typeof(b) and a == b


func _clear() -> void:
	if DirAccess.dir_exists_absolute(AudioCache.DIR):
		for f: String in DirAccess.get_files_at(AudioCache.DIR):
			DirAccess.remove_absolute(AudioCache.DIR + f)


func _run() -> void:
	_clear()
	print("== GELİŞTİRME SÜRÜMÜ ==")
	check(AppInfo.version_code() == 0, "testte sürüm kodu 0 (geliştirme)")
	var direct: Variant = AudioCache.fetch("deneme", func() -> int: return 7)
	check(direct == 7 and not DirAccess.dir_exists_absolute(AudioCache.DIR) or DirAccess.get_files_at(AudioCache.DIR).is_empty(),
		"önbellek kapalı: değer üretilir, dosya yazılmaz")

	print("== AÇIK (force) ==")
	AudioCache.force = true
	var sources: Dictionary = {
		"city_ambience": func() -> Variant: return CityAmbience._build_bank(),
		"siren_0": func() -> Variant: return PoliceSiren._synth(0),
		"siren_1": func() -> Variant: return PoliceSiren._synth(1),
	}
	for name: String in sources:
		var built: Variant = (sources[name] as Callable).call()
		var calls: Array[int] = [0]
		var counting: Callable = func() -> Variant:
			calls[0] += 1
			return (sources[name] as Callable).call()
		var first: Variant = AudioCache.fetch(name, counting)
		var second: Variant = AudioCache.fetch(name, counting)
		check(calls[0] == 1, "%s: ikinci çağrı diskten (sentez %d kez)" % [name, calls[0]])
		check(same(built, first) and same(built, second), "%s: okunan ses bayt bayt aynı" % name)
	# Gerçek giriş noktaları (statik değişkenleri dolduran sentezler) önbellekten de aynı sonucu verir
	NewsSfx._synthesize()
	var bell: AudioStreamWAV = NewsSfx._bell_stream
	NewsSfx._synthesize()
	check(bell != null and same(bell, NewsSfx._bell_stream) and bell != NewsSfx._bell_stream, "gazete sesleri: diskten aynı")
	HudSfx._synthesize()
	var coin: AudioStreamWAV = HudSfx._collect_stream
	HudSfx._synthesize()
	check(coin != null and same(coin, HudSfx._collect_stream), "para sesleri: diskten aynı")
	TrafficSfx._synthesize()
	var honks: Array[AudioStreamWAV] = TrafficSfx._honk_streams
	TrafficSfx._synthesize()
	check(honks.size() == 2 and same(honks, TrafficSfx._honk_streams) and TrafficSfx._honk_streams.is_typed(),
		"trafik kornaları: diskten aynı, dizi türü korunur")
	var bank: Dictionary = AudioCache.fetch("city_ambience", func() -> Variant: return {})
	check((bank["birds"] as Array).size() > 0 and ((bank["birds"] as Array)[0] as Array).is_typed(), "kuş varyantları Array[AudioStreamWAV]")

	print("== SÜRÜM DEĞİŞİNCE ==")
	var stale: String = AudioCache.DIR + "news_sfx-c1-g0.0.0.bin"
	var f: FileAccess = FileAccess.open(stale, FileAccess.WRITE)
	f.store_string("eski")
	f.close()
	for name: String in DirAccess.get_files_at(AudioCache.DIR):
		if name.begins_with("news_sfx-") and AudioCache.DIR + name != stale:
			DirAccess.remove_absolute(AudioCache.DIR + name)   # güncel dosya yok: yeniden yazılır, eskisi temizlenir
	NewsSfx._synthesize()
	check(not FileAccess.file_exists(stale), "eski sürümün dosyası yeni yazımda silinir")
	var bad: String = ""
	for name: String in DirAccess.get_files_at(AudioCache.DIR):
		if name.ends_with(".tmp"):
			bad = name
	check(bad.is_empty(), "yarım (.tmp) dosya kalmaz")
	AudioCache.force = false
	_clear()
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
