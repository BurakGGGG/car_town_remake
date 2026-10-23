extends SceneTree
## ÖDÜLLÜ REKLAM TEKLİFLERİ görsel QA (2026-10-23): MARKET ÜCRETSİZ ELMAS (+ geri sayım), OTO MANŞET ×2, SEVİYE ATLADIN
## ×2, GÖREVLER › GÜNLÜK (giriş ×2 + GÖREVİ DEĞİŞTİR), modifiye süre kısaltma, depo inşaatı kısaltma. Masaüstünde sahte
## reklam sağlayıcı (hep hazır).
## Kullanım: CT_NO_TUTORIAL=1 QA_SAVE=<kayıt> tools/qa_isolated.sh res://qa/ad_offers_shots.gd --resolution 1152x648 -- <klasör>
var _out: String = "/home/burak/Projects/ct_shots/ad_offers/"
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
	var ads: AdService = get_first_node_in_group("ads") as AdService
	ads.reset()
	ads.ensure_loaded()
	await wait(1.0)
	# MARKET
	hud.router.open(&"gem_store")
	await wait(1.2)
	await shot("market_free_gems")
	var free: AdOfferButton = hud.router.screen(&"gem_store").find_child("AdOffer_free_gems", true, false) as AdOfferButton
	if free:
		free.pressed.emit()
		await wait(1.5)
		await shot("market_reward")
		var popup: Node = hud.router.screen(&"gem_store").find_child("RewardPopup", true, false)
		if popup and popup.has_method(&"close"):
			popup.call(&"close")
		await wait(0.8)
		await shot("market_cooldown")
	hud.router.close_all()
	await wait(0.6)
	# OTO MANŞET
	ads.forget_last_ad()
	var away: OfflineEarnings = get_first_node_in_group("offline_earnings") as OfflineEarnings
	away.bank_money = 42500
	away.bank_minutes = 135.0
	away.bank_jobs = 18
	hud.news_flow.present()
	await wait(1.8)
	await shot("news_double")
	(hud.router.screen(&"news") as NewsScreen).close()
	await wait(1.8)
	# SEVİYE ATLADIN
	ads.forget_last_ad()
	hud.level_up_screen.add_level(31, 15500)
	hud.level_up_screen._open()
	await wait(1.4)
	await shot("levelup_double")
	hud.level_up_screen.close()
	await wait(0.8)
	# GÖREVLER › GÜNLÜK
	ads.forget_last_ad()
	hud.router.open(&"quests")
	await wait(0.6)
	hud.quest_screen._on_tab_pressed(MissionScreen.Tab.DAILY)
	await wait(0.6)
	await shot("missions_daily")
	hud.router.close_all()
	await wait(0.6)
	# MODİFİYE: süren takmada REKLAM İZLE −N DK
	var own: VehicleOwnership = get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	var mods: PerformanceModManager = get_first_node_in_group("performance_mods") as PerformanceModManager
	var car: StringName = own.owned_vehicle_ids()[0] if own.owned_count() > 0 else &""
	if car != &"":
		mods._jobs.append({"car": car, "category": &"motor", "stage": mini(mods.stage_of(car, &"motor") + 1, 5), "bay": 7,
			"start": mods.now(), "end": mods.now() + 2400.0})
		hud.router.open(&"garage")
		await wait(1.0)
		var garage: GarageScreen = hud.router.screen(&"garage") as GarageScreen
		garage.call(&"_on_vehicle_selected", car)
		await wait(0.6)
		garage.open_mods()
		await wait(1.2)
		var workshop: ModWorkshop = garage.get("_workshop") as ModWorkshop
		workshop.show_overview()
		await wait(0.4)
		workshop.open_category(&"motor")
		await wait(2.0)
		await shot("mods_time_skip")
		hud.router.close_all()
		await wait(0.8)
	# DEPOLARIM: inşaat sürerken
	var garages: CarGarageManager = get_first_node_in_group("car_garages") as CarGarageManager
	var depot: StringName = &""
	for id: StringName in CarGarageCatalog.ids():
		if not garages.is_owned(id):
			depot = id
			break
	if depot != &"":
		garages._building[depot] = garages.now() + 5 * 3600.0
		hud.router.open(&"car_garages")
		await wait(1.2)
		var screen: Node = hud.router.screen(&"car_garages")
		if screen.has_method(&"_select"):
			screen.call(&"_select", depot)
		await wait(1.0)
		await shot("depot_time_skip")
		hud.router.close_all()
	quit()
