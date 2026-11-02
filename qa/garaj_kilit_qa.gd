extends SceneTree
## 3. / 4. GARAJ OYUNCU SEVİYESİ KİLİDİ (2026-11-02) görsel denetimi, telefon tuvalinde (pencere 1152x648, ölçek 1,35 =
## 853x480): GARAJI DÜZENLE › YÜKSELTMELER'de kilitli garaj kartı + plakası (seviye 14, para yetiyor), sonra seviye
## 14 → 15 atlayınca SEVİYE ATLADIN'daki "GARAJ SEVİYE 3 · GENİŞLETME AÇILDI" kartı.
## Kullanım: CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/garaj_kilit_qa.gd --resolution 1152x648

const OUT: String = "/home/burak/Projects/ct_shots/garaj_kilit/"

var _fails: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		_fails += 1


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(3)
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute(OUT)
	get_root().get_texture().get_image().save_png(OUT + name + ".png")
	print("  kare: " + OUT + name + ".png")


func _run() -> void:
	root.content_scale_factor = 1.35
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(60)
	var hud: Hud = main.find_child("HUD", true, false)
	var progress: PlayerProgress = get_first_node_in_group("player_progress")
	var economy: EconomyManager = get_first_node_in_group("economy")
	var upgrades: GarageUpgradeManager = get_first_node_in_group("garage_upgrades")
	progress.level = 14
	economy.set_money(2_000_000)
	upgrades.apply_levels({GarageUpgradeManager.GARAGE_ID: 2, GarageUpgradeManager.SPEED_ID: 5})
	await _frames(20)

	print("== YÜKSELTMELER: kilitli 3. garaj ==")
	hud.router.open(&"garage_edit")
	await _frames(40)
	var edit: GarageEditScreen = hud.garage_edit_screen
	edit.call("_on_upgrades_pressed")
	await _frames(10)
	var cards: Dictionary = edit.get("_upgrade_cards")
	var card: PlateButton = cards[&"garage"]
	_check(card.text.contains(Loc.t("SEVİYE %d GEREKLİ") % 15), "kart: %s" % card.text.replace("\n", " / "))
	card.pressed.emit()
	await _frames(5)
	var plate: PurchasePlate = edit.get("_upgrade_plate")
	_check((edit.get("_upgrade_buy") as PlateButton).disabled, "plaka: GENİŞLET kapalı (%s)" % plate._price.text)
	await _shot("1_kilitli_garaj_plakasi")
	hud.router.close_all()
	await _frames(20)

	print("== SEVİYE 14 → 15: SEVİYE ATLADIN ==")
	progress.add_xp(progress.xp_to_next() - progress.xp)
	await _frames(90)
	_check(progress.level == 15, "seviye 15")
	_check(hud.level_up_screen != null and hud.level_up_screen.visible, "SEVİYE ATLADIN açık")
	await _shot("2_seviye_15_garaj_karti")
	print("SONUC: fails=%d" % _fails)
	quit(1 if _fails > 0 else 0)
