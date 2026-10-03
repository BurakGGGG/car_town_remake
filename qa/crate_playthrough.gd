extends SceneTree
## KASA SİSTEMİ — GERÇEK OYUNCU AKIŞI QA. Oyunu yeni kayıtla açar ve bir oyuncu gibi oynar:
## müşteri al → tamir → para topla → seviye → İLK KASA görevi → garaja gelen kasaya GERÇEK fare
## tıklaması → AÇ → araç çıkışı → koleksiyon → yarış aracı seçimi → rakip → showroom'dan kasa (çift
## dokunuş, yetersiz gem, 4 kasa türü) → kopya → sat / geri al → düzenleme modunda tıklama → dokunmatik.
## İki süreç: "play" (kasayı AÇMADAN çıkar, içeriği dosyaya yazar) ve "resume" (uygulama yeniden
## açılmış gibi: kasa duruyor mu, içerik aynı mı, açılınca aynı araç mı).
##
## Çalıştırma (override.cfg ile yalıtılmış kayıt, pencereli):
##   godot-4 --path . --resolution 1170x540 -s res://qa/crate_playthrough.gd -- play
##   godot-4 --path . --resolution 1170x540 -s res://qa/crate_playthrough.gd -- resume
## Görüntüler: /home/burak/Projects/ct_shots/crate/play/

const OUT: String = "/home/burak/Projects/ct_shots/crate/play/"
const HANDOFF: String = "user://qa_crate_handoff.json"

var fails: int = 0
var hud: Hud
var router: UiRouter
var crates: CrateManager
var delivery: CrateDelivery
var own: VehicleOwnership
var pp: PlayerProgress
var eco: EconomyManager
var quests: QuestManager
var race: RaceManager
var rm: RepairManager
var traffic: TrafficManager
var _t0: int = 0


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func note(text: String) -> void:
	print("  ·    " + text)


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "play"
	DirAccess.make_dir_recursive_absolute(OUT)
	if mode == "resume":
		_resume()
	else:
		_play()


func bind() -> void:
	var w: Node = root.get_node("World")
	hud = w.get_node("HUD")
	router = hud.router
	crates = get_first_node_in_group("crates")
	delivery = get_first_node_in_group("crate_delivery")
	own = get_first_node_in_group("vehicle_ownership")
	pp = get_first_node_in_group("player_progress")
	eco = get_first_node_in_group("economy")
	quests = get_first_node_in_group("quests")
	race = get_first_node_in_group("race")
	rm = get_first_node_in_group("repair_manager")
	traffic = w.get_node("Traffic")


## Dünyadaki bir noktaya GERÇEK fare tıklaması (bas + bırak), kameranın ekran izdüşümünden.
func click_world(pos: Vector3, touch: bool = false) -> void:
	var cam: Camera3D = root.get_camera_3d()
	# İzdüşüm görüntü alanı koordinatıdır (1404×648); olay PENCERE koordinatı ister (canvas_items ölçeği)
	var screen: Vector2 = root.get_final_transform() * cam.unproject_position(pos)
	if touch:
		for pressed: bool in [true, false]:
			var t: InputEventScreenTouch = InputEventScreenTouch.new()
			t.index = 0
			t.position = screen
			t.pressed = pressed
			Input.parse_input_event(t)
			await frames(2)
		return
	for pressed: bool in [true, false]:
		var e: InputEventMouseButton = InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.position = screen
		e.global_position = screen
		e.pressed = pressed
		Input.parse_input_event(e)
		await frames(2)


func crate_point(uid: int) -> Vector3:
	var v: CrateVisual = delivery.visual_of(uid)
	return v.global_position + Vector3(0.0, v.size().y * 0.6, 0.0) if v else Vector3.ZERO


## Oyuncu gibi tamir: bekleyen müşteriyi al, biten işi topla (sim_progress ile aynı karar).
func play_repairs(seconds: float, stop: Callable = Callable()) -> void:
	var end: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		for v: TrafficVehicle in traffic.vehicles:
			if v.is_waiting():
				rm.start_repair(v)
			elif v.mode == TrafficVehicle.Mode.REWARD_WAITING:
				rm.collect(v)
		if stop.is_valid() and bool(stop.call()):
			return
		await process_frame


func game_minutes() -> float:
	return (Time.get_ticks_msec() - _t0) / 1000.0 * Engine.time_scale / 60.0


func wait_result(seconds: float) -> bool:
	var t: float = 0.0
	while hud.crate_panel.mode() != &"result" and t < seconds:
		await create_timer(0.1).timeout
		t += 0.1
	return hud.crate_panel.mode() == &"result"


## Kasaya gerçek tıklama. Yan yana kasalar ekranda üst üste binebilir: tıklama öndekini seçer (doğru
## davranış). Dönen "uid" tıklamanın GERÇEKTEN seçtiği kasadır; içerik o kasanın kaydından okunur.
func open_via_click(uid: int, label: String) -> Dictionary:
	await click_world(crate_point(uid))
	await frames(3)
	check(hud.crate_panel.mode() == &"prompt", "%s: kasaya GERÇEK tıklama AÇ plakasını açtı" % label)
	if hud.crate_panel.uid() != uid:
		note("%s: tıklama öndeki kasayı seçti (uid %d → %d)" % [label, uid, hud.crate_panel.uid()])
		uid = hud.crate_panel.uid()
	var rolled: StringName = crates.get_crate(uid).get("vehicle", &"")
	var shown_title: String = hud.crate_panel._plate._title.text
	check(not shown_title.contains(String(CarCatalog.get_entry(rolled).get("display_name", "?")).to_upper()), "%s: içerik açılmadan gösterilmiyor ('%s')" % [label, shown_title])
	hud.crate_panel._action.pressed.emit()   # AÇ
	var ok: bool = await wait_result(10.0)
	check(ok, "%s: açılış sahnesi bitti, sonuç plakası" % label)
	return {"vehicle": rolled, "uid": uid}


# ===========================================================================================

func _play() -> void:
	await process_frame
	change_scene_to_file("res://Main.tscn")
	await create_timer(3.0).timeout
	bind()
	var save: SaveManager = get_first_node_in_group("save_manager")
	save.new_game()
	await create_timer(1.0).timeout
	_t0 = Time.get_ticks_msec()

	print("== 1) BAŞLANGIÇ ==")
	check(own.owned_vehicle_ids() == [&"tofas_sahin"], "ilk araç Tofaş Şahin")
	check(race.player_vehicle_id() == &"tofas_sahin", "ilk yarış aracı Şahin")
	note("başlangıç: %d ₺, %d gem, sv %d" % [eco.money, pp.gems, pp.level])
	router.open(&"quests")
	await create_timer(0.6).timeout
	var active: Array = quests.active_quests().map(func(e: Dictionary) -> String: return String(e["title"]))
	note("aktif görevler: %s" % [active])
	check(active.has("İLK KASA"), "ilk görev ekranında İLK KASA görünüyor")
	await shot("01_gorevler_baslangic")
	router.close_all()
	await create_timer(0.4).timeout
	router.open(&"showroom")
	await create_timer(1.2).timeout
	var car_plates: int = 0
	for key: String in hud.showroom._plates:
		if key.begins_with("car:"):
			car_plates += 1
	check(car_plates == 0 and hud.showroom.shown_crate() == &"city_crate", "showroom'da doğrudan araç satışı yok, kasalar var")
	await shot("02_showroom_ilk")
	router.close_all()
	await create_timer(0.4).timeout

	print("== 2) OYNA: TAMİR → XP / ₺ / GEM → SEVİYE 2 ==")
	Engine.time_scale = 6.0
	Engine.max_physics_steps_per_frame = 64
	var gems_start: int = pp.gems
	await play_repairs(120.0, func() -> bool: return pp.level >= 2)
	Engine.time_scale = 1.0
	note("seviye 2: %.1f oyun dakikası, %d tamir sayacı, %d ₺, %d gem (başta %d)" % [
		game_minutes(), quests.progress(&"apprentice"), eco.money, pp.gems, gems_start])
	check(pp.level >= 2, "oynayarak seviye 2'ye çıkıldı")
	check(pp.gems == gems_start + PlayerProgress.reward_for(2)["gems"], "seviye gemi +5 geldi (%d → %d)" % [gems_start, pp.gems])

	print("== 3) İLK KASA ÖDÜLÜ → GARAJA GELİR ==")
	router.open(&"quests")
	await create_timer(0.6).timeout
	hud.quest_screen._on_claim_pressed(&"first_crate")
	await create_timer(0.3).timeout
	check(not hud.quest_screen.visible, "ödül alınınca görev panosu kapandı (kasa arkada kalmıyor)")
	check(crates.pending_count() == 1, "garaja 1 kasa geldi")
	var first_uid: int = crates.crates()[0]["uid"]
	await create_timer(1.0).timeout
	check(crates.can_open(first_uid) and delivery.visual_of(first_uid) != null, "büyük kasa garajda, açılabilir")
	await shot("03_ilk_kasa_geldi")

	print("== 4) KASAYA TIKLA → AÇ → ARAÇ ==")
	var gv_before: int = GarageValue.vehicles_value(self)
	var r1: Dictionary = await open_via_click(first_uid, "ilk kasa")
	var first_car: StringName = r1["vehicle"]
	var car: Node3D = delivery.find_child("RevealedVehicle", true, false) as Node3D
	check(car != null, "araç 3D dünyada kasadan çıktı")
	var title: String = hud.crate_panel._plate._title.text
	var subtitle: String = hud.crate_panel._plate._subtitle.text
	var entry: Dictionary = CarCatalog.get_entry(first_car)
	check(title == String(entry["display_name"]).to_upper() and subtitle.begins_with(CrateCatalog.rarity_label(entry["rarity"])),
		"sonuç plakası doğru: %s / %s" % [title, subtitle])
	check(own.is_owned(first_car) and GarageValue.vehicles_value(self) == gv_before + int(entry["price"]), "koleksiyon + garaj değeri (+%d)" % int(entry["price"]))
	await shot("04_arac_cikti")
	hud.crate_panel._action.pressed.emit()   # TAMAM
	hud.crate_panel._action.pressed.emit()   # çift TAMAM
	await create_timer(1.0).timeout
	check(delivery.visual_of(first_uid) == null and crates.state_of(first_uid) == CrateManager.State.CLAIMED, "kasa kaldırıldı (çift TAMAM sorun çıkarmadı)")

	print("== 5) KOLEKSİYON ==")
	router.open(&"collection")
	await create_timer(1.6).timeout
	check(hud.collection_screen._title.text.contains("2 / 16"), "koleksiyon 2 / 16: %s" % hud.collection_screen._title.text)
	await shot("05_koleksiyon")
	router.close_all()
	await create_timer(0.4).timeout

	print("== 6) YARIŞ: SEÇİLİ ARAÇ ==")
	router.open(&"garage")
	await create_timer(1.2).timeout
	hud.garage_screen._show_vehicle(first_car, false)
	await create_timer(0.4).timeout
	hud.garage_screen._race_button.pressed.emit()
	await frames(2)
	check(race.player_vehicle_id() == first_car and hud.garage_screen._race_button.text.contains("✔"), "garajdan yarış aracı seçildi: %s" % first_car)
	await shot("06_yaris_araci")
	router.close_all()
	await create_timer(0.4).timeout
	var order: Array[String] = ["D", "C", "B", "A"]
	var pc: int = order.find(String(entry["class"]))
	var rival_ok: bool = true
	for i: int in 20:
		var rid: StringName = race.rival_id_for(race.player_vehicle_id())
		var rc: int = order.find(String(CarCatalog.get_entry(rid)["class"]))
		rival_ok = rival_ok and (rc == pc or rc == pc + 1)
	check(rival_ok, "rakipler oyuncunun sınıfından ya da bir üstünden (%s)" % entry["class"])
	if race.request_challenge_now():
		await frames(3)
		hud._on_challenge_clicked(race.challenger())
		await create_timer(0.8).timeout
		await shot("06b_yaris_daveti")
		router.close_all()
		race.release_challenger()
		await create_timer(0.4).timeout

	print("== 7) SHOWROOM: KASA SATIN ALMA ==")
	pp.load_state(pp.level, pp.xp, 20)
	router.open(&"showroom")
	await create_timer(1.2).timeout
	check(hud.showroom._buy_button.disabled and hud.showroom._buy_button.text.contains("GEM YETERSİZ"), "20 gemde ŞEHİR alınamıyor: %s" % hud.showroom._buy_button.text.replace("\n", " "))
	hud.showroom._on_buy_pressed()
	check(crates.pending_count() == 0 and pp.gems == 20, "yetersiz gemde hiçbir şey değişmedi")
	await shot("07_gem_yetersiz")
	pp.load_state(pp.level, pp.xp, 100)
	hud.showroom._refresh_state()
	hud.showroom._on_buy_pressed()
	hud.showroom._on_buy_pressed()   # çift dokunuş, aynı kare
	await frames(2)
	hud.showroom._on_buy_pressed()   # kapanış animasyonu sırasında üçüncü
	check(crates.pending_count() == 1 and pp.gems == 70, "çift/üçlü dokunuş tek kasa aldı (gem %d)" % pp.gems)
	await create_timer(0.6).timeout
	check(not hud.showroom.visible, "satın alınca showroom kapandı, garaja dönüldü")
	await create_timer(1.0).timeout
	await shot("07b_kasa_siparis_garaja")
	var qa_uid: int = crates.crates().back()["uid"]
	check(quests.progress(&"crate_order") == 1 or quests.is_claimed(&"crate_order") or not quests.is_active(&"crate_order"),
		"KASA SİPARİŞİ görevi saydı (aktifse)")

	print("== 8) HER KASA TÜRÜ: DOĞRU GEM ==")
	pp.load_state(20, 0, 30 + 50 + 80 + 120)
	for c: Dictionary in CrateCatalog.all():
		router.open(&"showroom")
		await create_timer(1.0).timeout
		hud.showroom._show_crate(c["id"])
		await create_timer(0.3).timeout
		var before: int = pp.gems
		var blocked: bool = crates.buy_block_reason(c["id"]) == "full"
		hud.showroom._on_buy_pressed()
		await create_timer(0.6).timeout
		if blocked:
			check(pp.gems == before and hud.showroom._buy_button.disabled and hud.showroom._buy_button.text.contains("KASALARI AÇ"),
				"%s: garaj dolu ('yolda' kasa var) → satın alma engellendi, gem düşmedi" % c["short_name"])
			router.close_all()
			await create_timer(0.4).timeout
		else:
			check(before - pp.gems == int(c["price_gems"]), "%s: %d gem düştü" % [c["short_name"], before - pp.gems])
	await create_timer(1.5).timeout
	var in_world: int = delivery.occupied_rects().size()
	note("bekleyen %d kasa, dünyada %d, yolda %d (garaj seviye 1)" % [crates.pending_count(), in_world, crates.undelivered().size()])
	await shot("08_bes_kasa")

	print("== 9) DÜZENLEME MODUNDA KASAYA TIKLAMA ==")
	router.open(&"garage_edit")
	await create_timer(1.2).timeout
	await click_world(crate_point(qa_uid))
	await frames(3)
	check(hud.crate_panel.mode() == &"", "düzenleme modunda kasa AÇ plakası açılmıyor")
	check((get_first_node_in_group("decor") as DecorManager).instance_count() == 0, "kasalar dekor sistemine girmedi")
	await shot("09_duzenleme_modu")
	router.close_all()
	await create_timer(1.0).timeout

	print("== 10) DOKUNMATİK ==")
	await click_world(crate_point(qa_uid), true)
	await frames(3)
	check(hud.crate_panel.mode() == &"prompt", "dokunmatik dokunuş kasayı seçti")
	hud.crate_panel._cancel.pressed.emit()
	await frames(2)

	print("== 11) KOPYA (sonuç test için sahip olunan araca sabitlendi) ==")
	var dup_uid: int = crates.undelivered()[0] if not crates.undelivered().is_empty() else -1
	var target_uid: int = qa_uid
	for c: Dictionary in crates.crates():
		if crates.can_open(int(c["uid"])) and int(c["uid"]) != qa_uid:
			target_uid = int(c["uid"])
			break
	crates._find(target_uid)["vehicle"] = first_car
	var count_before: int = own.owned_count()
	var disc_before: int = own.discovered_count()
	var gv2: int = GarageValue.vehicles_value(self)
	var gems2: int = pp.gems
	await open_via_click(target_uid, "kopya kasa")
	check(hud.crate_panel._plate._price.text.begins_with("KOPYA"), "sonuç plakası KOPYA diyor: %s" % hud.crate_panel._plate._price.text)
	check(own.owned_count() == count_before and own.discovered_count() == disc_before, "kopya yeni araç/keşif sayılmadı")
	check(GarageValue.vehicles_value(self) == gv2, "garaj değeri kopyayla değişmedi")
	check(pp.gems == gems2 + int(CrateManager.DUP_SCRAP[entry["rarity"]]) and own.stars(first_car) == 1, "★1 ve +%d gem hurda" % int(CrateManager.DUP_SCRAP[entry["rarity"]]))
	await shot("11_kopya")
	hud.crate_panel._action.pressed.emit()
	await create_timer(1.0).timeout
	if dup_uid > 0:
		await create_timer(1.0).timeout
		check(crates.state_of(dup_uid) >= CrateManager.State.DELIVERED and delivery.visual_of(dup_uid) != null,
			"yolda bekleyen kasa (uid %d) yer boşalınca garaja geldi (durum %d)" % [dup_uid, crates.state_of(dup_uid)])

	print("== 12) LEGENDARY AÇILIŞI (sonuç sabitlendi) ==")
	var leg_uid: int = -1
	for c: Dictionary in crates.crates():
		if crates.can_open(int(c["uid"])) and int(c["uid"]) != qa_uid:
			leg_uid = int(c["uid"])
			break
	if leg_uid > 0:
		crates._find(leg_uid)["vehicle"] = &"bmw_e60"
		await open_via_click(leg_uid, "legendary kasa")
		await create_timer(0.2).timeout
		await shot("12_legendary")
		hud.crate_panel._action.pressed.emit()
		await create_timer(1.0).timeout

	print("== 13) SAT → KOLEKSİYONDA KEŞFEDİLMİŞ → SHOWROOM'DAN GERİ AL ==")
	var sell_id: StringName = &"bmw_e60" if own.is_owned(&"bmw_e60") else first_car
	own.set_race_vehicle(&"tofas_sahin")
	router.open(&"garage")
	await create_timer(1.2).timeout
	hud.garage_screen._show_vehicle(sell_id, false)
	await create_timer(0.3).timeout
	hud.garage_screen._open_sell()
	hud.garage_screen._on_sell_confirmed()
	await create_timer(0.3).timeout
	check(not own.is_owned(sell_id) and own.is_discovered(sell_id), "%s satıldı, keşfedilmiş kaldı" % sell_id)
	router.close_all()
	await create_timer(0.4).timeout
	router.open(&"collection")
	await create_timer(1.2).timeout
	await shot("13_koleksiyon_satilmis")
	router.close_all()
	await create_timer(0.4).timeout
	eco.set_money(500000)
	router.open(&"showroom")
	await create_timer(1.2).timeout
	check(hud.showroom._plates.has("car:%s" % sell_id), "showroom GERİ AL listesinde %s var" % sell_id)
	check(not hud.showroom._plates.has("car:volvo_s60") or own.is_discovered(&"volvo_s60"), "hiç keşfedilmemiş araç listede yok")
	hud.showroom._show_vehicle(sell_id)
	await create_timer(0.6).timeout
	await shot("13b_showroom_geri_al")
	hud.showroom._on_buy_pressed()
	await create_timer(0.3).timeout
	check(own.is_owned(sell_id), "showroom'dan geri alındı")
	router.close_all()
	await create_timer(0.4).timeout

	print("== 14) UYGULAMAYI KAPAT: AÇILMAMIŞ KASA + İÇERİĞİ ==")
	var pending: Array = []
	for c: Dictionary in crates.crates():
		pending.append({"uid": int(c["uid"]), "vehicle": String(c["vehicle"]), "state": int(c["state"]),
			"pos": [c["pos"].x, c["pos"].y] if c["pos"] is Vector2 else null})
	var handoff: Dictionary = {"pending": pending, "gems": pp.gems, "owned": Array(own.owned_vehicle_ids()).map(func(x: StringName) -> String: return String(x)),
		"discovered": own.discovered_count(), "race": String(race.player_vehicle_id()), "stars": own.stars(first_car), "first_car": String(first_car)}
	var f: FileAccess = FileAccess.open(HANDOFF, FileAccess.WRITE)
	f.store_string(JSON.stringify(handoff))
	f.close()
	note("kapanıyor: %d kasa bekliyor, gem %d" % [pending.size(), pp.gems])
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)


# ===========================================================================================

func _resume() -> void:
	await process_frame
	change_scene_to_file("res://Main.tscn")
	await create_timer(3.5).timeout
	bind()
	var handoff: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HANDOFF))
	print("== 15) UYGULAMA YENİDEN AÇILDI ==")
	check(pp.gems == int(handoff["gems"]), "gem aynı (%d), aynı gün giriş ödülü tekrar verilmedi" % pp.gems)
	check(own.discovered_count() == int(handoff["discovered"]) and own.owned_count() == (handoff["owned"] as Array).size(), "koleksiyon ve sahiplik aynı")
	check(String(race.player_vehicle_id()) == String(handoff["race"]), "yarış aracı aynı")
	check(own.stars(StringName(handoff["first_car"])) == int(handoff["stars"]), "yıldız aynı")
	var all_same: bool = true
	for p: Variant in handoff["pending"]:
		var c: Dictionary = crates.get_crate(int(p["uid"]))
		var same: bool = not c.is_empty() and String(c["vehicle"]) == String(p["vehicle"])
		if p["pos"] != null and c.get("pos") is Vector2:
			same = same and (c["pos"] as Vector2).is_equal_approx(Vector2(float(p["pos"][0]), float(p["pos"][1])))
		all_same = all_same and same
	check(all_same and crates.pending_count() == (handoff["pending"] as Array).size(), "%d kasa aynı yerde, içerikleri değişmedi" % crates.pending_count())
	await create_timer(1.5).timeout
	await shot("15_yeniden_acilis")
	var uid: int = -1
	var expected: String = ""
	for p: Variant in handoff["pending"]:
		if crates.can_open(int(p["uid"])):
			uid = int(p["uid"])
			expected = String(p["vehicle"])
			break
	if uid > 0:
		var opened: Dictionary = await open_via_click(uid, "yeniden açılıştan sonra")
		uid = int(opened["uid"])
		for p: Variant in handoff["pending"]:
			if int(p["uid"]) == uid:
				expected = String(p["vehicle"])   # kapanmadan ÖNCE diske yazılmış içerik
		check(String(hud.crate_panel._plate._title.text) == String(CarCatalog.get_entry(StringName(expected))["display_name"]).to_upper(),
			"açılınca kapanmadan önce belirlenen araç çıktı: %s" % expected)
		await shot("16_ayni_arac")
		hud.crate_panel._action.pressed.emit()
		await create_timer(1.0).timeout
		check(not crates.can_open(uid) and not delivery.open_crate(uid), "açılmış kasa ikinci kez açılamıyor")
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
