extends SceneTree
## CANLI OYUN görsel QA — üst ortadaki etkinlik tabelası ve MARKET › KOD GİR (kupon). Ağ yok: etkinlik apply ile verilir.
## Kullanım: tools/qa_isolated.sh res://qa/live_ops_shots.gd --resolution 1404x648 -- <çıktı klasörü>
var _out: String = "/home/burak/Projects/ct_shots/live_ops/"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0].trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(_out)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(AppConfig.FILE))
	_run.call_deferred()


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(_out + name + ".png")
	print("çekildi: ", _out + name + ".png")


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	for i: int in 90:
		await process_frame
	var crates: CrateManager = get_first_node_in_group("crates") as CrateManager
	var welcome: int = crates.welcome_uid()
	if welcome > 0 and not crates.open(welcome).is_empty():
		crates.claim(welcome)
	var config: AppConfig = AppConfig.new()
	config.name = AppConfig.NODE_NAME
	config.url = ""
	root.add_child(config)
	var now: int = int(Time.get_unix_time_from_system())
	config.apply({"event": {"id": "qa", "title": {"tr": "Hafta sonu etkinliği", "en": "Weekend event", "de": "Wochenend-Event"},
		"money_mult": 2.0, "xp_mult": 2.0, "start": now - 60, "end": now + 23 * 3600 + 41 * 60 + 5}})
	await create_timer(2.0).timeout
	await shot("event_banner")
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	hud.router.open(&"gem_store")
	await create_timer(0.8).timeout
	(hud.router.screen(&"gem_store") as GemStoreScreen)._on_tab_pressed(GemStoreScreen.TAB_CODE)
	await create_timer(0.6).timeout
	await shot("market_code")
	quit()
