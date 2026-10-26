extends SceneTree
## REKLAM YÜKLENİYOR görsel QA (2026-10-26): reklam yüklenmemişken teklif düğmeleri gizlenmez, pasif "REKLAM YÜKLENİYOR"
## der — OTO MANŞET ×2, yarış sonucu ×2, tamir kısaltma plakası, GÖREVLER › GÜNLÜK (sade GÖREVİ DEĞİŞTİR), MARKET.
## Sahte sağlayıcının yüklemesi düşürülür (load_ok = false). Uzun dilde de bakılmalı (QA_LANG=fr / de).
## Kullanım: CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/ad_loading_shots.gd --resolution 1152x648 -- <klasör>
var _out: String = "/home/burak/Projects/ct_shots/ad_loading/"
var hud: Hud


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0].trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(_out + name + ".png")
	print("çekildi: ", _out + name + ".png")


func wait(t: float) -> void:
	await create_timer(t).timeout


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	for i: int in 90:
		await process_frame
	hud = current_scene.find_child("HUD", true, false) as Hud
	(get_first_node_in_group("player_progress") as PlayerProgress).load_state(8, 0, 50)
	var ads: AdService = get_first_node_in_group("ads") as AdService
	ads.reset()
	ads.forget_last_ad()
	var mock: MockAdProvider = ads.provider() as MockAdProvider
	mock.load_ok = false
	mock._loaded.clear()
	await wait(0.5)
	# OTO MANŞET
	var away: OfflineEarnings = get_first_node_in_group("offline_earnings") as OfflineEarnings
	away.bank_money = 42500
	away.bank_minutes = 135.0
	away.bank_jobs = 18
	away.told_first = true   # Rıza Usta'nın gazete sonrası açıklaması sonraki görüntüleri örtmesin
	away.told_full = true
	hud.news_flow.present()
	await wait(1.8)
	await shot("news_loading")
	(hud.router.screen(&"news") as NewsScreen).close()
	await wait(1.8)
	# YARIŞ SONUCU
	hud._on_race_completed(true, 9.0, 10.0)
	await wait(1.2)
	await shot("race_loading")
	hud._on_race_exit()
	await wait(1.0)
	# TAMİR PLAKASI
	var types: Array[RepairType] = RepairType.defaults()
	hud.show_car_info("WULF KOMBI 04")
	hud._repair_panel.set_info(types[types.size() - 1], 4800)
	hud._repair_panel.show_repairing(0.42, 754.0, false, 14, true)
	await wait(0.8)
	await shot("repair_loading")
	hud.hide_car_info()
	await wait(0.5)
	# GÖREVLER › GÜNLÜK
	hud.router.open(&"quests")
	await wait(0.6)
	hud.quest_screen._on_tab_pressed(MissionScreen.Tab.DAILY)
	await wait(1.2)
	await shot("missions_loading")
	hud.router.close_all()
	await wait(0.6)
	# MARKET › ÜCRETSİZ
	hud.router.open(&"gem_store")
	await wait(1.4)
	await shot("market_loading")
	hud.router.close_all()
	quit()
