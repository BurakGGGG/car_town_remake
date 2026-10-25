extends SceneTree
## KEPENK (bakım / güncelleme) yükleme ekranında görsel denetim (2026-10-25): gerçek yükleme ekranı (run/main_scene) açılır,
## uzaktan ayar ağsız verilir; oyun (Main) kepenk kalkmadan KURULMAMALI. Kip (betik argümanı): bakim | guncelle | yeni_surum
##   tools/qa_isolated.sh res://qa/kepenk_qa.gd --resolution 1440x648 --display-driver x11 -- bakim
## Telefon tuvali: content_scale 1,35 (1440x648 → 1067x480; 1152x648 → 853x480). Kareler ~/Projects/ct_shots/kepenk/.

const OUT: String = "/home/burak/Projects/ct_shots/kepenk/"

var fails: int = 0
var prefix: String = ""


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + prefix + file + ".png")


func until(cond: Callable, limit: float) -> bool:
	var end: int = Time.get_ticks_msec() + int(limit * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _initialize() -> void:
	if not OS.get_cmdline_user_args().has("masaustu"):
		get_root().content_scale_factor = 1.35
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var mode: String = args[0] if not args.is_empty() and args[0] != "masaustu" else "bakim"
	AppInfo.override_code = 10   # geliştirme sürümü (kod 0) kapıya takılmaz
	var config: AppConfig = AppConfig.new(false)
	config.name = AppConfig.NODE_NAME
	config.url = ""   # ağ yok: belge apply ile
	root.add_child(config)
	change_scene_to_file(String(ProjectSettings.get_setting("application/run/main_scene")))
	await process_frame
	await process_frame   # yükleme ekranı dili ayarladı: belge (cihazdaki ya da ilk cevap) şimdi gelir
	var now: int = int(Time.get_unix_time_from_system())
	var text: Dictionary = {"tr": "15 yeni araç ve hurdalıkta yeni parçalar geldi!", "en": "15 new cars and new junkyard parts!"}
	match mode:
		"bakim":
			config.apply({"maintenance": true, "maintenance_until": now + 42 * 60,
				"maintenance_text": {"tr": "Yeni garaj geliyor! Birkaç dakika içinde döneceğiz.", "en": "A new garage is coming! We'll be back in a few minutes."}})
		"guncelle":
			config.apply({"min_code": 11, "update_text": text})
		_:
			config.apply({"latest_code": 11, "update_text": text})
	await create_timer(1.0).timeout
	var canvas: Vector2 = root.get_visible_rect().size
	prefix = "%dx%d_%s_%s_" % [roundi(canvas.x), roundi(canvas.y), Loc.current(), mode]
	await shot("01_acilis")
	var loading: Node = root.get_node_or_null("LoadingScreen")
	check(loading != null, "yükleme ekranı açık")
	await until(func() -> bool: return loading != null and bool(loading.get("at_gate")), 25.0)
	await create_timer(1.0).timeout
	check(bool(loading.get("at_gate")), "yükleme ekranı kapıda bekliyor")
	check(root.get_node_or_null("World") == null, "oyun (Main) kurulmadı")
	var gate: AppGate = config.get_node("AppGate") as AppGate
	var shutter: GateShutter = gate.find_children("*", "GateShutter", true, false).back() as GateShutter
	check(shutter != null and shutter.is_visible_in_tree(), "kepenk ekranda")
	await shot("02_kepenk")
	match mode:
		"bakim":
			config.apply({})   # bakım bitti (TEKRAR DENE / kendiliğinden yoklama aynı yolu izler)
			await create_timer(0.25).timeout
			await shot("03_kepenk_kalkiyor")
			check(await until(func() -> bool: return root.get_node_or_null("World") != null, 25.0), "bakım bitince oyun kuruldu")
		"guncelle":
			await create_timer(3.0).timeout
			check(root.get_node_or_null("World") == null, "zorunlu güncellemede oyun hiç kurulmaz")
		_:
			for node: Node in shutter.find_children("*", "PlateButton", true, false):
				if (node as PlateButton).text == Loc.t("SONRA"):
					(node as PlateButton).pressed.emit()
			check(await until(func() -> bool: return root.get_node_or_null("World") != null, 25.0), "SONRA: oyun kuruldu")
	await create_timer(2.5).timeout
	await shot("04_sonra")
	AppInfo.override_code = 0
	print("SONUC: fails=%d" % fails)
	quit(1 if fails > 0 else 0)
