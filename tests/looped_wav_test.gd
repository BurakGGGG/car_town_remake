extends SceneTree
## DÖNGÜLÜ SESLERDE TAŞMA YOK (2026-10-28): Godot 4.7 döngüde loop_end karesini de okur; loop_end = kare sayısı
## telefonda ses iş parçacığını çökertiyordu (Crashlytics SIGSEGV, AudioStreamPlaybackWAV::_mix_internal). Kodla
## üretilen bütün döngülü sesler (şehir ortamı, siren, trafik / egzotik / yarış motoru) için: loop_end verinin İÇİNDE
## ve o kare döngü başının kopyası (dikiş korunur).
## Çalıştırma: tools/run_tests.sh looped_wav_test

var fails: int = 0


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


## Döngülü sesin okunan son karesi (loop_end) verinin içinde ve loop_begin karesiyle aynı mı.
func _sealed(wav: AudioStreamWAV) -> bool:
	var frame_bytes: int = 4 if wav.stereo else 2
	var frames: int = wav.data.size() / frame_bytes
	if wav.format != AudioStreamWAV.FORMAT_16_BITS or wav.loop_end >= frames or wav.loop_end <= wav.loop_begin:
		return false
	var a: int = wav.loop_begin * frame_bytes
	var b: int = wav.loop_end * frame_bytes
	return wav.data.slice(a, a + frame_bytes) == wav.data.slice(b, b + frame_bytes)


## Ağaçtaki (sözlük / dizi) bütün AudioStreamWAV'lar.
func _collect(value: Variant, out: Array[AudioStreamWAV]) -> void:
	if value is AudioStreamWAV:
		out.append(value)
	elif value is Array:
		for item: Variant in value:
			_collect(item, out)
	elif value is Dictionary:
		for k: Variant in value:
			_collect(value[k], out)


func _run() -> void:
	print("== LoopedWav ==")
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(8)
	for i: int in 4:
		bytes.encode_s16(i * 2, (i + 1) * 1000)
	wav.data = bytes
	LoopedWav.loop_forward(wav)
	check(wav.loop_mode == AudioStreamWAV.LOOP_FORWARD and wav.loop_begin == 0 and wav.loop_end == 4
		and wav.data.size() == 10 and wav.data.decode_s16(8) == 1000, "mono: 4 kare → 5 kare, loop_end 4 = ilk karenin kopyası")
	var stereo: AudioStreamWAV = AudioStreamWAV.new()
	stereo.format = AudioStreamWAV.FORMAT_16_BITS
	stereo.stereo = true
	stereo.data = bytes
	LoopedWav.loop_forward(stereo)
	check(stereo.loop_end == 2 and stereo.data.size() == 12 and stereo.data.slice(8, 12) == bytes.slice(0, 4),
		"stereo: 2 kare → 3 kare, son kare ilk karenin kopyası")

	print("== oyunun döngülü sesleri ==")
	var sources: Dictionary = {}
	var bank: Array[AudioStreamWAV] = []
	_collect(CityAmbience._build_bank(), bank)
	sources["şehir ortamı"] = bank
	var sirens: Array[AudioStreamWAV] = []
	for kind: int in PoliceSiren.Kind.values():
		sirens.append(PoliceSiren._synth(kind))
	sources["siren"] = sirens
	var traffic: Array[AudioStreamWAV] = []
	for kind: int in TrafficEngine.Kind.values():
		traffic.append(TrafficEngine.make_stream(kind as TrafficEngine.Kind))
	sources["trafik motoru"] = traffic
	var exotic: Array[AudioStreamWAV] = []
	for cylinders: int in [6, 8, 10]:
		exotic.append(ExoticEngine.make_stream(cylinders))
	sources["egzotik motor"] = exotic
	var race: Array[AudioStreamWAV] = []
	for character: int in RaceAudio.CHARACTERS.size():
		race.append(RaceAudio._engine(character))
	sources["yarış motoru"] = race
	var total: int = 0
	for name: String in sources:
		var looped: int = 0
		var bad: int = 0
		for stream: AudioStreamWAV in sources[name]:
			if stream.loop_mode == AudioStreamWAV.LOOP_DISABLED:
				continue
			looped += 1
			if not _sealed(stream):
				bad += 1
		total += looped
		check(looped > 0 and bad == 0, "%s: %d döngülü ses, loop_end verinin içinde ve dikiş korunmuş (bozuk %d)"
			% [name, looped, bad])
	check(total >= 15, "denetlenen döngülü ses sayısı makul (%d)" % total)

	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
