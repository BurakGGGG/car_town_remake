extends SceneTree
## CANLI OYUN görsel QA — üst ortadaki etkinlik tabelası, ETKİNLİK PANOSU (bütün modüller + örnek paketin afişi), GÖREVLER ›
## ETKİNLİK, showroom'da etkinlik kasası / indirim, dekor mağazası etiketleri ve MARKET › KOD GİR (kupon). Ağ yok: etkinlik
## apply ile verilir, örnek içerik paketi (tools/live_pack/content/ornek_kis) çalışırken kurulup bağlanır.
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
	var base: String = LivePackBuilder.CONTENT + "ornek_kis"
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(base.path_join("pack.json")))
	var built: Dictionary = LivePackBuilder.build("ornek_kis", source, base, ProjectSettings.globalize_path("user://ornek_kis.pck"))
	print("örnek paket: ", built["ok"], " ", built["error"])
	LivePacks.mount("ornek_kis", "user://ornek_kis.pck")
	config.apply({"event": {"id": "qa", "title": {"tr": "Kış etkinliği", "en": "Winter event", "de": "Winter-Event"},
		"text": {"tr": "Hafta sonu boyunca çifte para, indirimli kasalar ve Kral Rıza'nın meydan okuması!",
			"en": "Double money, discounted crates and King Rıza's challenge all weekend!"},
		"money_mult": 2.0, "xp_mult": 2.0, "start": now - 60, "end": now + 23 * 3600 + 41 * 60 + 5,
		"sale": {"crates": 30, "decor": 20}, "crate_boost": {"crate": "city_crate", "cars": ["ford_focus", "opel_corsa"], "mult": 3},
		"missions": [{"id": "m1", "metric": "repairs", "target": 40, "money": 15000},
			{"id": "m2", "metric": "race_wins", "target": 3, "gems": 20},
			{"id": "m3", "metric": "event_rival_wins", "target": 1, "crate": "city_crate", "decor": "kis_cami"}],
		"rival": {"car": "ford_focus", "stage": 3, "name": "Kral Rıza", "paint": "#2255ff", "money": 10000, "gems": 25},
		"pack": "ornek_kis"}})
	var missions: MissionManager = get_first_node_in_group("missions") as MissionManager
	missions.ensure_current()
	missions.count(&"repairs", 26)
	await create_timer(2.0).timeout
	await shot("event_banner")
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	hud.router.open(&"event")
	await create_timer(1.0).timeout
	await shot("event_panel")
	hud.quest_screen.open_on_event()
	hud.router.open(&"quests")
	await create_timer(1.0).timeout
	await shot("event_missions")
	hud.router.close_all()
	await create_timer(0.5).timeout
	hud.showroom.open_on_crate(&"city_crate")
	hud.router.open(&"showroom")
	await create_timer(2.0).timeout
	await shot("event_showroom")
	hud.router.close_all()
	await create_timer(0.8).timeout
	hud.router.open(&"garage_edit")
	await create_timer(1.5).timeout
	var edit: Node = hud.router.screen(&"garage_edit")
	edit.call(&"_on_tab_pressed", GarageDecor.Kind.PLANT)   # BİTKİ: örnek paketin kış çamı burada
	await create_timer(1.5).timeout
	await shot("event_decor")
	hud.router.close_all()
	await create_timer(0.8).timeout
	hud.router.open(&"gem_store")
	await create_timer(0.8).timeout
	(hud.router.screen(&"gem_store") as GemStoreScreen)._on_tab_pressed(GemStoreScreen.TAB_CODE)
	await create_timer(0.6).timeout
	await shot("market_code")
	quit()
