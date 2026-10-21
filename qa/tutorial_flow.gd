extends SceneTree
## EĞİTİM AKIŞI QA: temiz kayıtla oyunu açar, Rıza Usta'nın derslerini GERÇEK dokunuşlarla (spot ışığı
## deliğinin ortasına fare olayı) oynar ve her adımda ekran görüntüsü alır. Delik dışına dokunuşun
## dünyaya geçmediğini de dener.
## Kullanım: tools/qa_isolated.sh res://qa/tutorial_flow.gd --resolution 1152x648 [-- basics|all|garages [en|es]]
##   garages: İLK TAMİR'den sonra öteki dersler bitmiş sayılır, garajlar dolana dek araç eklenir, GARAJ DERSİ oynanır.
const OUT: String = "/home/burak/Projects/ct_shots/tutorial/"

var _director: TutorialDirector
var _hud: Hud
var _shot_index: int = 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for file: String in DirAccess.get_files_at(OUT):
		DirAccess.remove_absolute(OUT + file)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 1:   # ikinci bağımsız değişken: dil (en / es)
		var cfg: ConfigFile = ConfigFile.new()
		cfg.load(GameSettings.PATH)
		cfg.set_value("general", "language", args[1])
		cfg.save(GameSettings.PATH)
	_run.call_deferred()


func _shot(label: String) -> void:
	RenderingServer.force_draw()
	_shot_index += 1
	root.get_texture().get_image().save_png(OUT + "%02d_%s.png" % [_shot_index, label])
	print("QA kare %02d_%s" % [_shot_index, label])


func _wait(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


## Koşul doğru olana dek bekler (en çok `limit` sn). Doğru olduysa true.
func _until(condition: Callable, limit: float, label: String) -> bool:
	var until: int = Time.get_ticks_msec() + int(limit * 1000.0)
	while Time.get_ticks_msec() < until:
		if bool(condition.call()):
			return true
		await process_frame
	print("QA ZAMAN AŞIMI: %s" % label)
	return false


func _tap(point: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		root.push_input(event)
		await process_frame
		await process_frame


func _close_reward() -> void:
	var popup: RewardPopup = _director.get("_reward_popup")
	await _wait(0.6)
	await _tap((popup.get("_ok_button") as Control).get_global_rect().get_center())


func _hole() -> Rect2:
	return _director.overlay.get("_target") if _director.overlay.get("_has_target") else Rect2()


func _tap_hole() -> void:
	var rect: Rect2 = _hole()
	print("QA dokun: delik %s" % rect)
	await _tap(rect.get_center())


## Kartın düğmesi: ilk dokunuş yazıyı bitirir, ikincisi basar.
func _tap_action() -> void:
	var action: PlateButton = _director.overlay.card.get("_action")
	await _tap(action.get_global_rect().get_center())
	await _tap(action.get_global_rect().get_center())


func _step_title() -> String:
	var card: CoachCard = _director.overlay.card
	return (card.get("_title") as Label).text if card.visible else "(kart yok)"


func _state() -> String:
	return "%s/%s #%d «%s»" % [_director.get("_state"), _director.get("_chapter"), _director.get("_index"), _step_title()]


func _run() -> void:
	change_scene_to_file(String(ProjectSettings.get_setting("application/run/main_scene")))
	await _until(func() -> bool: return current_scene != null and current_scene.name != "LoadingScreen" \
		and root.get_node_or_null("LoadingScreen") == null, 30.0, "oyun yüklendi")
	_hud = current_scene.find_child("HUD", true, false) as Hud
	_director = _hud.tutorial
	var which: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "all"
	await _basics()
	if which == "basics":
		quit(0)
		return
	if which == "garages" or which == "garajdolu":
		await _garages_chapter(which == "garajdolu")
		quit(0)
		return
	await _race_chapter()
	await _vehicles_chapter()
	await _decor_chapter()
	print("QA BİTTİ: biten dersler %d / 4" % (root.get_tree().get_first_node_in_group("tutorial") as TutorialManager).done_count())
	quit(0)


func _basics() -> void:
	await _until(func() -> bool: return _director.overlay.chapter_open(), 12.0, "hoş geldin kartı")
	await _wait(1.2)
	_shot("hosgeldin")
	await _tap((_director.overlay.chapter.get("_primary") as Control).get_global_rect().get_center())
	await _wait(0.6)
	print("QA ", _state())
	# HOŞ GELDİN KUTUSU: kutuya dokun → AÇ → açılış sahnesi → AL, İLK ARACIN! → TAMAM
	if await _until(func() -> bool: return _step_title() == Loc.t("HOŞ GELDİN HEDİYESİ"), 4.0, "hediye adımı"):
		await _wait(1.2)
		_shot("hediye_kutusu")
		await _tap_hole()
		await _until(func() -> bool: return _step_title() == Loc.t("KUTUYU AÇ"), 5.0, "kutuyu aç")
		await _wait(0.8)
		_shot("hediye_ac")
		await _tap_hole()
		await _wait(1.2)
		_shot("hediye_acilis")
		await _until(func() -> bool: return _step_title() == Loc.t("AL, İLK ARACIN!"), 20.0, "ilk araç")
		await _wait(1.5)
		_shot("hediye_ilk_arac")
		await _tap((_hud.crate_panel.find_child("CrateAction", true, false) as Control).get_global_rect().get_center())
		await _wait(1.2)
		var own: VehicleOwnership = root.get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership
		print("QA hediye sonrası araçlar: ", own.owned_vehicle_ids(), "  ", _state())
		# İlk araç YERLEŞTİR sorulmadan garaja: düzenleme kipi araç parmakta → YERLEŞTİR → BİTİR
		if await _until(func() -> bool: return _step_title() == Loc.t("GARAJINA KOY"), 6.0, "garajına koy"):
			await _wait(1.4)
			_shot("ilk_arac_garaja")
			await _tap_hole()
			await _until(func() -> bool: return _step_title() == Loc.t("BİTİR"), 5.0, "bitir")
			await _wait(1.2)
			_shot("ilk_arac_bitir")
			await _tap_hole()
			await _wait(1.0)
			var garages: CarGarageManager = root.get_tree().get_first_node_in_group("car_garages") as CarGarageManager
			print("QA ilk araç yeri: ", garages.garage_of(own.owned_vehicle_ids()[0]), "  ", _state())
	_shot("musteri_bekleniyor")
	await _until(func() -> bool: return _step_title() == Loc.t("İLK MÜŞTERİN"), 40.0, "müşteri adımı")
	await _wait(1.0)
	_shot("musteri")
	# Delik DIŞINA dokunuş dünyaya geçmemeli (araç seçilmez, adım değişmez)
	await _tap(Vector2(40.0, 600.0))
	print("QA delik dışı dokunuş sonrası: ", _state())
	await _tap_hole()
	await _until(func() -> bool: return _step_title() == Loc.t("TAMİRE AL"), 5.0, "TAMİRE AL adımı")
	await _wait(0.8)
	_shot("tamire_al")
	await _tap_hole()
	await _until(func() -> bool: return _step_title() == Loc.t("TAMİR SÜRÜYOR"), 5.0, "tamir sürüyor")
	await _wait(0.8)
	_shot("tamir_suruyor")
	await _until(func() -> bool: return _step_title() == Loc.t("PARANI TOPLA"), 90.0, "para topla")
	await _wait(1.0)
	_shot("para_topla_arac")
	await _tap_hole()
	await _wait(0.8)
	if _step_title() == Loc.t("PARANI TOPLA"):
		_shot("para_topla_dugme")
		await _tap_hole()
	await _until(func() -> bool: return _step_title() == Loc.t("İLK KAZANCIN!"), 5.0, "kazanç")
	await _wait(1.6)
	_shot("kazanc")
	for i: int in 3:
		var action: PlateButton = _director.overlay.card.get("_action")
		await _tap(action.get_global_rect().get_center())   # yazı akarken ilk dokunuş metni tamamlar
		await _tap(action.get_global_rect().get_center())
		await _wait(1.4)
		_shot("ileri_%d" % i)
	await _until(func() -> bool: return _director.get("_state") == &"complete", 4.0, "ders tamam")
	await _wait(1.2)
	_shot("ders_tamam")
	await _until(func() -> bool: return (_director.get("_reward_popup") as Control).visible, 5.0, "ödül")
	await _wait(1.5)
	_shot("odul")
	await _close_reward()
	await _wait(1.5)
	_shot("odul_ucus")
	print("QA ilk ders sonrası: ", _state())


func _race_chapter() -> void:
	var race: RaceManager = root.get_tree().get_first_node_in_group("race") as RaceManager
	race.request_challenge_now()
	await _until(func() -> bool: return _director.get("_chapter") == TutorialManager.RACE, 20.0, "yarış dersi")
	await _wait(1.2)
	_shot("yaris_kart")
	await _tap((_director.overlay.chapter.get("_primary") as Control).get_global_rect().get_center())
	await _wait(1.0)
	_shot("yaris_rakip")
	await _tap_hole()
	await _until(func() -> bool: return _step_title() == Loc.t("DAVETİ KABUL ET"), 5.0, "davet")
	await _wait(0.8)
	_shot("yaris_davet")
	await _tap_hole()
	await _until(func() -> bool: return _step_title() == Loc.t("DRAG NASIL OYNANIR?"), 6.0, "kurallar")
	await _wait(1.5)
	_shot("yaris_kurallar")
	for i: int in 3:
		var action: PlateButton = _director.overlay.card.get("_action")
		await _tap(action.get_global_rect().get_center())
		await _tap(action.get_global_rect().get_center())
		await _wait(1.3)
		_shot("yaris_kural_%d" % i)
	# Canlı yarış: oyuncu adına dokun (kalkış + vitesler)
	var screen: DragRaceScreen = _hud.drag_race_screen
	await _wait(3.5)
	_shot("yaris_canli")
	var taps: int = 0
	while _hud.router.top() != &"race_result" and taps < 400:
		var hot: bool = screen.get("_shift_hot")
		var phase: int = screen.get("_phase")
		if phase == DragRaceScreen.Phase.RUNNING and (hot or not (screen.get("_player") as DragRaceSim.Runner).running):
			screen.tap()
			taps += 1
			await _wait(0.25)
		await process_frame
	await _until(func() -> bool: return _step_title() == Loc.t("YARIŞ BİTTİ!"), 15.0, "sonuç")
	await _wait(1.6)
	_shot("yaris_sonuc")
	var action_button: PlateButton = _director.overlay.card.get("_action")
	await _tap(action_button.get_global_rect().get_center())
	await _tap(action_button.get_global_rect().get_center())
	await _wait(1.0)
	_shot("yaris_garaja_don")
	await _tap_hole()
	await _until(func() -> bool: return _director.get("_state") == &"complete", 5.0, "yarış tamam")
	await _wait(1.2)
	_shot("yaris_tamam")
	await _until(func() -> bool: return (_director.get("_reward_popup") as Control).visible, 5.0, "ödül")
	await _wait(0.6)
	await _close_reward()
	await _wait(1.0)
	print("QA yarış dersi sonrası: ", _state())


func _vehicles_chapter() -> void:
	var player: PlayerProgress = root.get_tree().get_first_node_in_group("player_progress") as PlayerProgress
	while player.level < 2:
		player.add_xp(player.xp_to_next())
		await process_frame
	var director_wait: float = 0.0
	await _until(func() -> bool: return _director.get("_chapter") == TutorialManager.VEHICLES, 20.0, "araç dersi")
	await _wait(1.2)
	_shot("arac_kart")
	await _tap((_director.overlay.chapter.get("_primary") as Control).get_global_rect().get_center())
	await _wait(1.0)
	_shot("arac_gorevler")
	await _tap_hole()
	await _until(func() -> bool: return _step_title() == Loc.t("ÖDÜLÜ AL"), 5.0, "ödülü al")
	await _wait(1.0)
	_shot("arac_odulu_al")
	await _tap_hole()
	await _until(func() -> bool: return _step_title() == Loc.t("KASAYA DOKUN") or _step_title() == Loc.t("KASA YOLDA"), 6.0, "kasa")
	await _wait(1.0)
	_shot("arac_kasa_yolda")
	await _until(func() -> bool: return _step_title() == Loc.t("KASAYA DOKUN"), 25.0, "kasaya dokun")
	await _wait(1.2)
	_shot("arac_kasaya_dokun")
	await _tap_hole()
	await _until(func() -> bool: return _step_title() == Loc.t("KASAYI AÇ"), 5.0, "kasayı aç")
	await _wait(0.8)
	_shot("arac_kasayi_ac")
	await _tap_hole()
	await _until(func() -> bool: return _step_title() == Loc.t("YENİ ARACIN!"), 20.0, "yeni araç")
	await _until(func() -> bool: return _hole().size != Vector2.ZERO, 20.0, "sonuç düğmesi")
	await _wait(1.0)
	_shot("arac_yeni")
	await _tap_hole()
	await _until(func() -> bool: return _step_title() == Loc.t("ARAÇLARIN"), 8.0, "araçların")
	await _wait(1.0)
	_shot("arac_araclar")
	await _tap_hole()
	await _until(func() -> bool: return _step_title() == Loc.t("YARIŞ ARACI"), 6.0, "yarış aracı")
	await _wait(1.6)
	_shot("arac_yaris_araci")
	for i: int in 2:
		var action: PlateButton = _director.overlay.card.get("_action")
		await _tap(action.get_global_rect().get_center())
		await _tap(action.get_global_rect().get_center())
		await _wait(1.4)
		_shot("arac_ileri_%d" % i)
	await _until(func() -> bool: return (_director.get("_reward_popup") as Control).visible, 6.0, "ödül")
	await _wait(0.6)
	await _close_reward()
	await _wait(1.0)
	print("QA araç dersi sonrası: ", _state(), director_wait)


## DEPO DERSİ: öteki dersler bitmiş sayılır, otoparka iki araç düşene dek araç eklenir; ders gerçek dokunuşlarla oynanır
## (ARAÇLAR → aracın yeri → OTOPARK → sıradaki depo → SATIN AL / GARAJIM / GARAJ DEĞERİ kartları → ödül).
## `full`: garaj zemini araçlarla doldurulur, sonra gelen araç sığmaz → ders "GARAJIN DOLDU!" ile açılmalı ve ARAÇLAR o
## araçla açılmalı (kullanıcı kararı 2026-10-20).
func _garages_chapter(full: bool = false) -> void:
	var manager: TutorialManager = root.get_tree().get_first_node_in_group("tutorial") as TutorialManager
	for id: StringName in [TutorialManager.VEHICLES, TutorialManager.RACE, TutorialManager.DECOR, TutorialManager.JUNKYARD]:
		manager.mark_done(id)
	if full:
		await _garage_full_start(manager)
		return
	# İlk dersin hoş geldin aracı için YERLEŞTİR açılır (oyunda da böyle): TAMAM ile otoparkta bırakılır, eklenecek
	# araçlar soru açmasın
	_hud.placement_prompts = false
	(_hud.get("_placement_queue") as Array).clear()
	await _until(func() -> bool: return _hud.router.top() == &"car_placement", 3.0, "yerleştir")
	if _hud.router.top() == &"car_placement":
		_shot("garaj_yerlestir")
		await _tap((_hud.car_placement_screen.find_child("Keep", true, false) as Control).get_global_rect().get_center())
		await _wait(0.8)
	var own: VehicleOwnership = root.get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	var garages: CarGarageManager = root.get_tree().get_first_node_in_group("car_garages") as CarGarageManager
	for entry: Dictionary in CarCatalog.all():
		if garages.waiting_ids().size() >= 2:
			break
		var id: StringName = entry["id"]
		if not own.is_owned(id):
			own.add_vehicle(id)
	await _until(func() -> bool: return _director.get("_chapter") == TutorialManager.GARAGES, 30.0, "garaj dersi")
	await _wait(1.2)
	_shot("garaj_kart")
	await _tap((_director.overlay.chapter.get("_primary") as Control).get_global_rect().get_center())
	await _until(func() -> bool: return _step_title() == Loc.t("OTOPARKTASIN"), 5.0, "otoparktasın")
	await _wait(1.0)
	_shot("garaj_araclar")
	await _tap_hole()
	await _garages_rest(manager)


## DEPO DERSİ'nin ARAÇLAR'dan sonrası (iki giriş de buraya bağlanır).
func _garages_rest(manager: TutorialManager) -> void:
	await _until(func() -> bool: return _step_title() == Loc.t("NEREDE DURUYOR?"), 6.0, "nerede duruyor")
	await _wait(1.6)
	_shot("garaj_adi")
	await _tap_hole()
	await _until(func() -> bool: return _step_title() == Loc.t("OTOPARK"), 6.0, "otopark")
	await _wait(1.2)
	_shot("garaj_otopark")
	await _tap_action()
	await _until(func() -> bool: return _step_title() == Loc.t("DEPOLAR"), 6.0, "depolar")
	await _wait(1.4)
	_shot("garaj_depolar")
	await _tap_hole()
	for title: String in ["SATIN AL", "GARAJIM", "GARAJ DEĞERİ"]:
		await _until(func() -> bool: return _step_title() == Loc.t(title), 6.0, title)
		await _wait(1.2)
		_shot("garaj_" + title.to_lower().replace(" ", "_"))
		await _tap_action()
	await _until(func() -> bool: return (_director.get("_reward_popup") as Control).visible, 8.0, "ödül")
	await _wait(0.6)
	_shot("garaj_odul")
	await _close_reward()
	await _wait(1.0)
	print("QA garaj dersi sonrası: %s · bitti: %s" % [_state(), manager.is_done(TutorialManager.GARAGES)])



## Garaj dolu girişi: zemin dolana dek araç sergilenir, sığmayan araç gelince ders "GARAJIN DOLDU!" ile açılır.
func _garage_full_start(manager: TutorialManager) -> void:
	_hud.placement_prompts = false
	(_hud.get("_placement_queue") as Array).clear()
	var own: VehicleOwnership = root.get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	var garages: CarGarageManager = root.get_tree().get_first_node_in_group("car_garages") as CarGarageManager
	var view: GarageDecorView = root.get_tree().get_first_node_in_group("garage_decor_view") as GarageDecorView
	var extra: StringName = &""
	for entry: Dictionary in CarCatalog.all():
		var id: StringName = entry["id"]
		if own.is_owned(id) or not CarCatalog.is_obtainable(id):
			continue
		if not view.has_room_for(GarageDecor.vehicle_item_id(id)):
			extra = id
			break
		own.add_vehicle(id)
		view.place_free(GarageDecor.vehicle_item_id(id))
	print("QA garaj dolu: sergide %d araç, otoparkta %d, sığmayan %s" % [garages.home_ids().size(),
		garages.waiting_ids().size(), extra])
	_hud.placement_prompts = true
	own.add_vehicle(extra)
	await _until(func() -> bool: return _director.get("_chapter") == TutorialManager.GARAGES, 30.0, "garaj dolu dersi")
	await _wait(1.2)
	_shot("garajdolu_kart")
	var chapter_title: Label = _director.overlay.chapter.get("_title") as Label
	print("QA kart başlığı: ", chapter_title.text if chapter_title else "?")
	await _tap((_director.overlay.chapter.get("_primary") as Control).get_global_rect().get_center())
	await _until(func() -> bool: return _step_title() == Loc.t("YENİ ARACIN NEREDE?"), 5.0, "yeni aracın nerede")
	await _wait(1.0)
	_shot("garajdolu_araclar")
	await _tap_hole()
	await _until(func() -> bool: return _hud.router.current_place() == &"garage", 5.0, "ARAÇLAR açıldı")
	await _wait(1.2)
	print("QA ARAÇLAR'da gösterilen: %s (sığmayan %s, yeri %s)" % [_hud.garage_screen.get("_shown_vehicle"), extra,
		garages.garage_of(extra)])
	await _garages_rest(manager)

func _decor_chapter() -> void:
	var player: PlayerProgress = root.get_tree().get_first_node_in_group("player_progress") as PlayerProgress
	while player.level < 3:
		player.add_xp(player.xp_to_next())
		await process_frame
	(root.get_tree().get_first_node_in_group("economy") as EconomyManager).add_money(20000)
	await _until(func() -> bool: return _director.get("_chapter") == TutorialManager.DECOR, 25.0, "dekor dersi")
	await _wait(1.2)
	_shot("dekor_kart")
	await _tap((_director.overlay.chapter.get("_primary") as Control).get_global_rect().get_center())
	await _wait(1.0)
	_shot("dekor_garaj")
	await _tap_hole()
	await _until(func() -> bool: return _step_title() == Loc.t("DÜZENLE"), 5.0, "düzenle")
	await _wait(0.8)
	_shot("dekor_duzenle")
	await _tap_hole()
	await _until(func() -> bool: return _step_title() == Loc.t("BİR EŞYA SEÇ"), 6.0, "eşya seç")
	await _wait(1.5)
	_shot("dekor_esya_sec")
	var editor: GarageEditor = root.get_tree().get_first_node_in_group("garage_editor") as GarageEditor
	var decor: DecorManager = root.get_tree().get_first_node_in_group("decor") as DecorManager
	print("QA satın alma: ", decor.purchase(&"traffic_cones"), " yerleştirme: ", editor.begin_place(&"traffic_cones"))
	await _until(func() -> bool: return _step_title() == Loc.t("YERLEŞTİR"), 5.0, "yerleştir")
	await _wait(1.2)
	_shot("dekor_yerlestir")
	await _tap_hole()
	await _until(func() -> bool: return _step_title() == Loc.t("HARİKA OLDU!"), 5.0, "harika")
	await _wait(1.6)
	_shot("dekor_harika")
	var action: PlateButton = _director.overlay.card.get("_action")
	await _tap(action.get_global_rect().get_center())
	await _tap(action.get_global_rect().get_center())
	await _wait(1.0)
	_shot("dekor_bitir")
	await _tap_hole()
	await _until(func() -> bool: return _director.get("_state") == &"complete", 5.0, "dekor tamam")
	await _wait(1.2)
	_shot("dekor_tamam")
	await _until(func() -> bool: return (_director.get("_reward_popup") as Control).visible, 5.0, "ödül")
	await _wait(0.6)
	await _close_reward()
	await _wait(1.0)
	print("QA dekor dersi sonrası: ", _state())
