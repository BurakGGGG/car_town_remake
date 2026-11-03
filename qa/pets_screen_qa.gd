extends SceneTree
## HAYVANLAR ekranı QA (2026-11-03, taslak "Ekran C"): HUD'daki pati tabelası (ünlemli), ekran, beyaz kedi alma (ONAYLA →
## ad ekranı), siyah kedi (garaj dolu → evde), GARAJ DOLU uyarısı, eve gönder / garaja çıkar, köpek (YAKINDA), garajda iki
## kedi. Mobil ölçek 1,35 (ekran_tarama.gd gibi). Kareler ~/Projects/ct_shots/pets/hayvanlar/<etiket>_NN_*.png
## Kullanım: QA_SAVE=<kayıt> CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/pets_screen_qa.gd --resolution 1440x648 -- p20x9
const OUT: String = "/home/burak/Projects/ct_shots/pets/hayvanlar/"

var _tag: String = "qa"
var _n: int = 0


func _initialize() -> void:
	create_timer(200.0).timeout.connect(func() -> void:
		print("QA HATA: süre doldu")
		quit(2))
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_tag = args[0] if args.size() > 0 else "qa"
	get_root().content_scale_factor = 1.35
	DirAccess.make_dir_recursive_absolute(OUT)
	for f: String in DirAccess.get_files_at(OUT):
		if f.begins_with(_tag + "_"):
			DirAccess.remove_absolute(OUT + f)
	_run.call_deferred()


func _shot(label: String) -> void:
	RenderingServer.force_draw()
	_n += 1
	root.get_texture().get_image().save_png(OUT + "%s_%02d_%s.png" % [_tag, _n, label])
	print("QA kare %s_%02d_%s" % [_tag, _n, label])


func _wait(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _until(cond: Callable, limit: float) -> bool:
	var until: int = Time.get_ticks_msec() + int(limit * 1000.0)
	while Time.get_ticks_msec() < until:
		if cond.call():
			return true
		await process_frame
	return false


func _run() -> void:
	change_scene_to_file(String(ProjectSettings.get_setting("application/run/main_scene")))
	await _until(func() -> bool: return current_scene != null and current_scene.name != "LoadingScreen" \
		and current_scene.find_child("HUD", true, false) != null, 60.0)
	var away: OfflineEarnings = get_first_node_in_group("offline_earnings") as OfflineEarnings
	if away:
		away.told_first = true
		away.told_full = true
	await _wait(3.0)
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	hud.router.close_all()
	var pets: PetManager = get_first_node_in_group("pets") as PetManager
	var progress: PlayerProgress = get_first_node_in_group("player_progress") as PlayerProgress
	pets.reset()
	pets.adopt("Paşa")
	pets.load_state({"adopted": true, "name": "Paşa", "friendship": 35, "accessories": ["collar_red", "race_jacket"],
		"equipped": {"neck": "collar_red", "body": "race_jacket"}})
	progress.load_state(maxi(progress.level, 6), 0, 1000)
	await _wait(1.5)
	hud.router.close_all()
	await _wait(0.5)
	_shot("hud_pati_tabelasi")
	var screen: PetsScreen = hud.pets_screen
	hud.router.open(&"pets")
	await _wait(0.8)
	_shot("ekran_pasa")
	screen._rename()   # Paşa'nın adı gelişte verildi: değiştirmek ücretli
	await _wait(0.8)
	_shot("ad_degistir_ucretli")
	hud.router.back()
	await _wait(0.6)
	screen.select(&"white")
	await _wait(0.3)
	_shot("beyaz_satin_al")
	screen._on_primary()
	await _wait(0.3)
	_shot("beyaz_onayla")
	screen._on_primary()
	await _wait(0.8)
	_shot("ad_ekrani")
	print("QA ad ekranı açık: ", hud.router.is_open(&"pet_name"), " HAYVANLAR açık: ", hud.router.is_open(&"pets"))
	hud.router.back()
	await _wait(0.8)
	_shot("beyaz_alindi")
	screen.select(&"black")
	screen._on_primary()
	await _wait(0.2)
	screen._on_primary()
	await _wait(0.8)
	print("QA siyah (gem yetmedi?) market: ", hud.router.is_open(&"gem_store"))
	_shot("siyah_gem_yetmiyor_market")
	if hud.router.is_open(&"gem_store"):
		hud.router.back()
		await _wait(0.6)
	progress.load_state(progress.level, progress.xp, 2000)
	screen._on_primary()
	await _wait(0.2)
	screen._on_primary()
	await _wait(0.8)
	if hud.router.is_open(&"pet_name"):
		hud.router.back()
		await _wait(0.6)
	_shot("siyah_evde")
	screen._on_primary()
	await _wait(0.4)
	_shot("garaj_dolu_uyarisi")
	screen.select(&"dog")
	await _wait(0.3)
	_shot("kopek_yakinda")
	screen.select(&"orange")
	screen._on_primary()   # Paşa eve
	await _wait(0.4)
	screen.select(&"black")
	screen._on_primary()   # siyah garaja
	await _wait(0.5)
	_shot("siyah_garajda")
	hud.router.back()
	await _wait(3.0)
	_shot("garajda_iki_kedi")
	print("QA garajdakiler: ", pets.out_pets(), " adlar: ", pets.out_pets().map(func(u: String) -> String: return pets.name_of(u)))
	quit(0)
