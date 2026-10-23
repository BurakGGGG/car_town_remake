extends SceneTree
## YÜKLEME SLAYTLARI ZAMANLAMASI: yükleme ekranında hangi görselin ne zaman belirdiğini, ne kadar göründüğünü ve ekranın ne
## zaman kalktığını ölçer; her görsel tam belirince ve ekran kalkmadan hemen önce kare alır.
## YAVAŞ TELEFON BENZETİMİ: `-- <yakma_ms>` her karede ana iş parçacığını o kadar meşgul eder (bekleme değil, işlemci
## yakar); `taskset -c 0` ile tek çekirdekte çalıştırılınca arka plan yüklemesi de aynı çekirdeği paylaşır — zayıf
## telefondaki gibi yükleme uzar, kareler seyrekleşir.
## Ayrıca `<yükleme_sn> <ağır_kare_ms>`: arka plan yüklemesi en az o kadar sürmüş sayılır, oyunun kurulduğu kare o kadar
## uzar (LoadingScreen.simulate_*; telefonda ölçülmemiş varsayım — örn. 9 sn yükleme + 3 sn ilk ağır kare).
## Kullanım: QA_SAVE=<kayıt> CT_NO_TUTORIAL=1 [taskset -c 0] tools/qa_isolated.sh res://qa/yukleme_slayt_zaman.gd \
##   --display-driver x11 --resolution 1152x648 -- <yakma_ms> <etiket> [<yükleme_sn> <ağır_kare_ms>]
const OUT: String = "/home/burak/Projects/ct_shots/yukleme_zaman/"

var _burn_ms: int = 0
var _label: String = "normal"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_burn_ms = int(args[0])
	if args.size() > 1:
		_label = args[1]
	if args.size() > 3:
		LoadingScreen.simulate_load_seconds = float(args[2])
		LoadingScreen.simulate_heavy_frame_ms = int(args[3])
	DirAccess.make_dir_recursive_absolute(OUT + _label)
	for file: String in DirAccess.get_files_at(OUT + _label):
		DirAccess.remove_absolute(OUT + _label + "/" + file)
	_run.call_deferred()


func _screen() -> LoadingScreen:
	var node: Node = root.get_node_or_null("LoadingScreen")
	if node == null and current_scene is LoadingScreen:
		node = current_scene
	return node as LoadingScreen


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png(OUT + _label + "/" + name + ".png")


func _run() -> void:
	var t0: int = Time.get_ticks_msec()
	change_scene_to_file(String(ProjectSettings.get_setting("application/run/main_scene")))
	var shown: Array[Dictionary] = []   # {"image", "at"}: görselin TAM belirdiği an
	var last_image: String = ""
	var fade_started: float = -1.0
	var frames: int = 0
	var worst: float = 0.0
	var last_us: int = Time.get_ticks_usec()
	var seen_screen: bool = false
	var events: PackedStringArray = PackedStringArray()
	var next_ready: bool = false
	while Time.get_ticks_msec() - t0 < 60000:
		await process_frame
		frames += 1
		var now_us: int = Time.get_ticks_usec()
		var frame_ms: float = (now_us - last_us) / 1000.0
		worst = maxf(worst, frame_ms)
		last_us = now_us
		var at: float = (Time.get_ticks_msec() - t0) / 1000.0
		if frame_ms > 150.0 + _burn_ms:
			events.append("%.2f: %d ms kare" % [at, roundi(frame_ms)])
		var screen: LoadingScreen = _screen()
		if screen == null:
			if seen_screen:
				break
			continue
		seen_screen = true
		var art: TextureRect = screen.get("_art")
		var image: String = art.texture.resource_path.get_file().get_basename() if art and art.texture else "-"
		if image != last_image:
			shown.append({"image": image, "at": at})
			last_image = image
			_shot("%02d_%s_%.1fs" % [shown.size(), image, at])
		if (screen.get("_next_texture") != null) != next_ready:
			next_ready = not next_ready
			if next_ready:
				events.append("%.2f: sıradaki görsel hazır (slayt sayacı %.2f sn)" % [at, float(screen.get("_slide_timer"))])
		if screen.get("_main") != null and not events.has("oyun eklendi"):
			events.append("oyun eklendi")
			events.append("%.2f: ↑ Main sahneye eklendi" % at)
		if bool(screen.get("_slide_fading")) and fade_started < 0.0:
			events.append("%.2f: geçiş başladı" % at)
			fade_started = at
		elif not bool(screen.get("_slide_fading")):
			fade_started = -1.0
		if _burn_ms > 0:   # yavaş telefon: ana iş parçacığı her karede meşgul
			var until: int = Time.get_ticks_usec() + _burn_ms * 1000
			while Time.get_ticks_usec() < until:
				pass
	var gone: float = (Time.get_ticks_msec() - t0) / 1000.0
	print("== %s (kare başı %d ms yakma) ==" % [_label, _burn_ms])
	print("YÜKLEME EKRANI KALKTI: %.2f sn, %d kare, en uzun kare %.0f ms" % [gone, frames, worst])
	for line: String in events:
		if line != "oyun eklendi":
			print("  · " + line)
	for i: int in shown.size():
		var until_at: float = float(shown[i + 1]["at"]) if i + 1 < shown.size() else gone
		print("  %d. %-12s tam belirdi %.2f sn → %.2f sn göründü" % [i + 1, shown[i]["image"], shown[i]["at"],
			until_at - float(shown[i]["at"])])
	quit()
