extends SceneTree
## GÜNLÜK GİRİŞ MERDİVENİ QA: oyunu açar, merdiveni istenen güne kurar (seri = gün, bugün alınmadı), sağ üstteki tabelayı,
## panoyu, AL sonrası ödül penceresini ve alınmış hâli (×2 + yarın geri sayımı) kareler. Kaydı değiştirir: yalıtılmış
## klasörde çalıştırın.
## Kullanım: CT_NO_TUTORIAL=1 QA_SAVE=<kayıt> tools/qa_isolated.sh res://qa/giris_merdiveni_shots.gd --resolution 1280x720 \
##   [-- <gün> <çıktı_klasörü>]
const DEFAULT_OUT: String = "/home/burak/Projects/ct_shots/giris_merdiveni/"

var _out: String = DEFAULT_OUT
var _day: int = 9


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_day = int(args[0])
	if args.size() > 1:
		_out = args[1].path_join("")
	DirAccess.make_dir_recursive_absolute(_out)
	for file: String in DirAccess.get_files_at(_out):
		DirAccess.remove_absolute(_out + file)
	_run.call_deferred()


func _wait(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _shot(label: String) -> void:
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(_out + label + ".png")
	print("QA kare ", label)


func _run() -> void:
	change_scene_to_file(String(ProjectSettings.get_setting("application/run/main_scene")))
	var until: int = Time.get_ticks_msec() + 40000
	while Time.get_ticks_msec() < until and (current_scene == null or current_scene.name == "LoadingScreen" \
			or root.get_node_or_null("LoadingScreen") != null):
		await process_frame
	await _wait(2.0)
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	var gem: GemRewards = get_first_node_in_group("gem_rewards") as GemRewards
	var today: int = gem.day_key(gem.now_unix())
	gem.load_state({"login": {"day": today, "streak": _day, "claimed": today - 1, "months": 0}, "day": today,
		"max_seen": gem.now_unix()})
	await _wait(0.6)
	_shot("1_tabela")
	hud.router.open(&"login_ladder")
	await _wait(2.5)
	print("QA fps (pano açık): %d" % Engine.get_frames_per_second())
	var f0: int = Engine.get_process_frames()
	var t0: int = Time.get_ticks_msec()
	await _wait(1.0)
	print("QA 1 sn'de kare: %d (%d ms)" % [Engine.get_process_frames() - f0, Time.get_ticks_msec() - t0])
	_shot("2_merdiven")
	var screen: LoginLadderScreen = hud.login_ladder_screen
	(screen.get("_claim") as PlateButton).pressed.emit()
	await _wait(3.0)
	_shot("3_odul")
	(screen.get("_reward_popup") as RewardPopup).close()
	await _wait(1.6)
	_shot("4_alindi")
	hud.router.back()
	await _wait(1.0)
	_shot("5_tabela_alindi")
	quit(0)
