extends SceneTree
## TRAFİK KORNALARI DİNLEME DOSYALARI (traffic/traffic_engine.gd): her korna tipi × basış deseni ayrı WAV.
## Motor sesleri 2026-11-02'den beri aracın pişmiş bankası (EngineBank): dinlemek için MOTOR SES LABORATUVARI
## (tools/engine_lab.sh — "ŞEHİR SÜRÜŞÜ" / "YANINDAN GEÇİŞ") ya da qa/motor_sesi_dinle.gd.
##   godot-4 --headless --path . --script res://qa/trafik_sesleri_dinle.gd
## Çıktı: /home/burak/Projects/ct_shots/trafik_sesleri/korna_<tip>_<desen>.wav

const OUT: String = "/home/burak/Projects/ct_shots/trafik_sesleri/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var patterns: Array[String] = ["dit", "dit_dit", "uzun", "sabirsiz"]
	for horn: int in TrafficEngine.Horn.values():
		var streams: Array[AudioStreamWAV] = TrafficEngine.horn_streams(horn as TrafficEngine.Horn)
		for i: int in streams.size():
			var file: String = "korna_%s_%s.wav" % [String(TrafficEngine.Horn.keys()[horn]).to_lower(), patterns[i]]
			streams[i].save_to_wav(OUT + file)
	print("kornalar: %s" % OUT)
	quit()
