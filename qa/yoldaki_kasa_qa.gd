extends SceneTree
## YOLDAKİ KASA QA (2026-10-17, kullanıcı kararı "kasa listeden açılsın"): garaj kasalarla dolar, yer kalmayınca
## alınan kasa "yolda" kalır → MAĞAZA sekmesinde rozet, mağazada YOLDAKİ KASALAR bölümü, yer yokken mağazadan
## alınan kasada mağaza kapanmaz; KASAYI AÇ → açılış sahnesi showroom platformunda (kareler), sonuç plakası, TAMAM →
## kasa kapanır, sıradaki gelir; açılış yarıda kapanırsa kasa yine kapanır; MAX_PENDING'de satın alma durur.
## Sistem: gameplay/crate_manager.gd, ui/hud/showroom_screen.gd, ui/hud/hud.gd (_refresh_shop_badge).
##   CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/yoldaki_kasa_qa.gd --display-driver x11 --resolution 1170x540
## Kareler: /home/burak/Projects/ct_shots/kasa_yolda/

const OUT: String = "/home/burak/Projects/ct_shots/kasa_yolda/"

var fails: int = 0
var hud: Hud
var router: UiRouter
var crates: CrateManager
var delivery: CrateDelivery
var own: VehicleOwnership
var pp: PlayerProgress
var showroom: ShowroomScreen


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func note(text: String) -> void:
	print("  ·    " + text)


func shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + file + ".png")


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await create_timer(4.0).timeout
	var world: Node = root.get_node("World")
	hud = world.get_node("HUD")
	router = hud.router
	showroom = hud.showroom
	crates = get_first_node_in_group("crates")
	delivery = get_first_node_in_group("crate_delivery")
	own = get_first_node_in_group("vehicle_ownership")
	pp = get_first_node_in_group("player_progress")
	var welcome: int = crates.welcome_uid()
	if welcome > 0 and not crates.open(welcome).is_empty():   # ilk araç (sahne oynatılmaz)
		crates.claim(welcome)
	pp.add_gems(5000)
	await frames(10)

	print("1) Garaj kasalarla dolar")
	var in_garage: int = 0
	while crates.undelivered().is_empty() and in_garage < CrateManager.MAX_PENDING:
		var uid: int = crates.buy(&"city_crate")
		if uid == 0:
			break
		if not crates.waiting_for_room(uid):
			in_garage += 1
		await create_timer(0.8).timeout   # geliş animasyonu
	var first: int = crates.undelivered()[0] if not crates.undelivered().is_empty() else 0
	check(first > 0, "garaj doldu, son kasa yolda (%d kasa garajda)" % in_garage)
	check(hud.shop_button.badge == 1, "MAĞAZA sekmesinde rozet: %d" % hud.shop_button.badge)
	check(crates.buy_block_reason(&"city_crate") == "", "yolda kasa satın almayı engellemiyor")
	await shot("01_rozet")

	print("2) Mağaza: YOLDAKİ KASALAR")
	router.open(&"showroom")
	await create_timer(0.8).timeout
	check(showroom.shown_pending() == first, "mağaza açılınca yoldaki kasa seçili")
	check(showroom._plates.has("pending:%d" % first), "YOLDAKİ KASALAR bölümünde")
	check(showroom._buy_button.text == Loc.t("KASAYI AÇ") and not showroom._buy_button.disabled, "düğme KASAYI AÇ")
	await shot("02_magaza_yoldaki")
	showroom._show_crate(&"city_crate")
	await frames(5)
	showroom._on_buy_pressed()
	await frames(5)
	var second: int = crates.undelivered()[1] if crates.undelivered().size() > 1 else 0
	check(second > 0 and showroom.visible and showroom.shown_pending() == second,
		"yer yokken mağazadan alınan kasa: mağaza açık kaldı, yeni kasa YOLDAKİ KASALAR'da seçili")
	check(hud.shop_button.badge == 2, "rozet 2: %d" % hud.shop_button.badge)
	await shot("03_yer_yokken_alindi")

	print("3) Mağazada açılış")
	var vehicle: StringName = crates.get_crate(second).get("vehicle", &"")
	var owned_before: bool = own.is_owned(vehicle)
	var t0: int = Time.get_ticks_msec()
	var worst: float = 0.0
	showroom._on_buy_pressed()
	check(crates.state_of(second) == CrateManager.State.REVEALED, "ödül verildi, REVEALED")
	check(own.is_owned(vehicle), "araç koleksiyonda (%s, önceden %s)" % [vehicle, "vardı" if owned_before else "yoktu"])
	check(hud._android_back_for_crate_panel(), "açılış sürerken Android GERİ yutuluyor")
	check(not showroom._list_group.visible and showroom._exit_button.disabled, "liste gizli, GERİ kilitli")
	var shots: Array[float] = [0.4, 1.4, 2.2, 3.0]
	var k: int = 0
	var last: int = Time.get_ticks_usec()
	while not showroom._reveal_done and Time.get_ticks_msec() - t0 < 15000:
		await process_frame
		var now: int = Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
		if k < shots.size() and Time.get_ticks_msec() - t0 >= int(shots[k] * 1000.0):
			await shot("04_acilis_%d" % k)
			k += 1
	note("sahne %.1f sn, en uzun kare %.0f ms" % [(Time.get_ticks_msec() - t0) / 1000.0, worst])
	check(showroom._reveal_done and showroom._buy_button.text == Loc.t("TAMAM"), "sonuç plakası, düğme TAMAM")
	await create_timer(0.8).timeout   # araç vitrine otursun
	await shot("05_sonuc")
	showroom._on_buy_pressed()   # TAMAM
	await frames(10)
	check(crates.state_of(second) == CrateManager.State.CLAIMED and not showroom.is_revealing(), "TAMAM: kasa kapandı")
	check(showroom.shown_pending() == first and showroom._list_group.visible, "sıradaki yoldaki kasa seçili, liste geri geldi")
	check(hud.shop_button.badge == 1, "rozet 1: %d" % hud.shop_button.badge)
	await shot("06_siradaki")

	print("4) Açılış yarıda kapanırsa")
	showroom._on_buy_pressed()
	await create_timer(0.7).timeout
	showroom.close()
	await create_timer(0.6).timeout
	check(crates.state_of(first) == CrateManager.State.CLAIMED and not showroom.visible, "mağaza kapandı, kasa kapatıldı (ödül zaten verildi)")
	check(showroom._model_slot.get_child_count() == 0, "platformda artık nesne yok")
	check(hud.shop_button.badge == 0, "rozet yok")
	router.open(&"showroom")
	await create_timer(0.8).timeout
	var pending_plates: int = 0
	for key: String in showroom._plates:
		if key.begins_with("pending:"):
			pending_plates += 1
	check(pending_plates == 0 and showroom.shown_crate() != &"", "yoldaki kasa yokken bölüm yok, mağaza kasası seçili")
	await shot("07_normal")
	router.close_all()
	await create_timer(0.5).timeout

	print("5) Üst sınır")
	while crates.pending_count() < CrateManager.MAX_PENDING:
		if crates.buy(&"city_crate") == 0:
			break
		await frames(2)
	check(crates.buy_block_reason(&"city_crate") == "full", "%d bekleyen kasada satın alma duruyor" % CrateManager.MAX_PENDING)
	router.open(&"showroom")
	await create_timer(0.8).timeout
	showroom._show_crate(&"city_crate")
	await frames(3)
	check(showroom._buy_button.disabled and showroom._buy_button.text == Loc.t("ÖNCE BEKLEYEN\nKASALARI AÇ"),
		"düğme: %s" % showroom._buy_button.text.replace("\n", " "))
	await shot("08_ust_sinir")
	print("SONUÇ: %d hata" % fails)
	quit(1 if fails > 0 else 0)
