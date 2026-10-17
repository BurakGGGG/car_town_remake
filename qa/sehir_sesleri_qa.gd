extends SceneTree
## ŞEHİR SESLERİ QA (traffic/city_ambience.gd): oyunu açar, varsayılan görünümde SECONDS sn bekler; olayları
## (kuş cümlesi, korna, uzak cıyaklama, lastik sesi çalan araç sayısı) döker, ekran açılınca susup kapanınca geri
## geldiğini denetler ve Master çıkışını WAV'a kaydeder (dinlemek için — oyunda duyulduğu gibi).
##   CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/sehir_sesleri_qa.gd --display-driver x11 --resolution 1170x540 \
##     --audio-driver Dummy
## Çıktı: /home/burak/Projects/ct_shots/cevre/oyun_kaydi.wav (müzik dahil her şey), cevre_yalniz.wav (yalnız şehir
## sesleri, efekt düzeyi uygulanmadan önce)

const OUT: String = "/home/burak/Projects/ct_shots/cevre/"
const SECONDS: float = 75.0

var fails: int = 0


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func _run() -> void:
	var master: int = AudioServer.get_bus_index(&"Master")
	var record: AudioEffectRecord = AudioEffectRecord.new()
	AudioServer.add_bus_effect(master, record)
	change_scene_to_file("res://Main.tscn")
	await create_timer(1.0).timeout
	record.set_recording_active(true)
	var traffic: TrafficManager = get_first_node_in_group("traffic") as TrafficManager
	var ambience: CityAmbience = traffic.ambience if traffic else null
	check(ambience != null, "şehir sesleri kuruldu")
	if ambience == null:
		quit(1)
		return
	var ambience_record: AudioEffectRecord = AudioEffectRecord.new()
	AudioServer.add_bus_effect(AudioServer.get_bus_index(CityAmbience.BUS), ambience_record)
	ambience_record.set_recording_active(true)
	var hud: Hud = root.get_node("World/HUD") as Hud
	var t0: int = Time.get_ticks_msec()
	var started_at: float = -1.0
	var birds: int = 0
	var horns: int = 0
	var squeals: int = 0
	var max_rolling: int = 0
	var was: Dictionary = {}
	var forced_squeal: bool = false
	while (Time.get_ticks_msec() - t0) / 1000.0 < SECONDS:
		await process_frame
		var now: float = (Time.get_ticks_msec() - t0) / 1000.0
		if started_at < 0.0 and ambience.is_running():
			started_at = now
			print("  ·    sesler %.1f sn'de başladı" % now)
		if not forced_squeal and now > 30.0:
			forced_squeal = true
			ambience._squeal_timer = 0.0   # uzak cıyaklama da kayda girsin (normalde 60–140 sn'de bir)
		max_rolling = maxi(max_rolling, ambience.rolling_count())
		for player: AudioStreamPlayer3D in ambience._birds + [ambience._horn, ambience._squeal]:
			var playing: bool = player.playing
			if playing and not was.get(player, false):
				var what: String = String(player.name)
				if what.begins_with("Bird"):
					birds += 1
				elif what == "Horn":
					horns += 1
				else:
					squeals += 1
				print("  ·    %5.1f sn  %-7s %s  uzaklık %.1f" % [now, what, (player.stream as AudioStreamWAV).resource_name,
					player.global_position.distance_to(ambience._listener.global_position)])
			was[player] = playing
	check(started_at >= 0.0 and started_at < 8.0, "sesler açılıştan kısa süre sonra başladı")
	check(birds >= 3, "kuşlar ötüyor (%d cümle / %.0f sn)" % [birds, SECONDS])
	check(horns >= 1 and horns <= 5, "ara sıra korna (%d)" % horns)
	check(squeals >= 1, "uzak cıyaklama (%d)" % squeals)
	check(max_rolling >= 1, "yoldaki araçların lastik sesi (en çok %d araç birden)" % max_rolling)
	check(absf(ambience.bus_db()) < 0.5, "dünya görünürken tam düzey (%.1f dB)" % ambience.bus_db())
	record.set_recording_active(false)
	ambience_record.set_recording_active(false)
	var alone: AudioStreamWAV = ambience_record.get_recording()
	if alone:
		alone.save_to_wav(OUT + "cevre_yalniz.wav")
	var recording: AudioStreamWAV = record.get_recording()
	if recording:
		recording.save_to_wav(OUT + "oyun_kaydi.wav")
		print("  ·    kayıt %.1f sn → %soyun_kaydi.wav" % [recording.get_length(), OUT])
	hud.router.open(&"showroom")
	await create_timer(3.5).timeout
	check(ambience.bus_db() <= CityAmbience.SILENT_DB + 0.5, "mağaza açıkken sessiz (%.1f dB)" % ambience.bus_db())
	hud.router.open(&"quests")
	hud.router.close_all()
	await create_timer(0.2).timeout
	hud.router.open(&"quests")
	await create_timer(3.5).timeout
	check(absf(ambience.bus_db() - CityAmbience.PANEL_DB) < 0.5, "pano açıkken kısık (%.1f dB)" % ambience.bus_db())
	hud.router.close_all()
	await create_timer(1.0).timeout
	check(ambience.bus_db() > CityAmbience.PANEL_DB, "pano kapanınca geri geliyor (%.1f dB)" % ambience.bus_db())
	print("SONUÇ: %d hata" % fails)
	quit(1 if fails > 0 else 0)
