extends SceneTree
## Taslak arka planı: ana garaj HUD'u, açılıştaki geçici plakalar (rütbe vb.) kaybolduktan sonra tek kare.
## Mobil ölçek (1,35) ekran_tarama.gd ile aynı. Çıktı ~/Projects/ct_shots/taslak_arka/<etiket>.png
## Kullanım: QA_SAVE=<kayıt> CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/hud_bg_shot.gd --resolution 1440x648 -- p20x9
const OUT: String = "/home/burak/Projects/ct_shots/taslak_arka/"


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		print("QA HATA: süre doldu")
		quit(2))
	get_root().content_scale_factor = 1.35
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func _wait(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var tag: String = args[0] if args.size() > 0 else "hud"
	change_scene_to_file(String(ProjectSettings.get_setting("application/run/main_scene")))
	var until: int = Time.get_ticks_msec() + 40000
	while Time.get_ticks_msec() < until and (current_scene == null or current_scene.name == "LoadingScreen" \
			or current_scene.find_child("HUD", true, false) == null):
		await process_frame
	var away: OfflineEarnings = get_first_node_in_group("offline_earnings") as OfflineEarnings
	if away:
		away.told_first = true
		away.told_full = true
	await _wait(2.0)
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	hud.router.close_all()
	await _wait(12.0)
	hud.router.close_all()
	await _wait(1.0)
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(OUT + tag + ".png")
	print("QA kare ", tag)
	quit(0)
