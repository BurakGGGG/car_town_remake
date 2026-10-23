extends SceneTree
## GARAJI DÜZENLE → YÜKSELTMELER (2026-10-23): GARAJ plakası düzenleyiciyi açar; YÜKSELTMELER modunda garaj seviyesi /
## tamir hızı / tamir alanı kartları, karta dokununca satın alma plakası, SATIN AL seviyeyi / alanı artırır; DETAY ve
## USTALIK PROFİL'de. Çalıştırma: tools/run_tests.sh garage_upgrades_test

var fails: int = 0


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(12)
	var hud: Hud = main.find_child("HUD", true, false)
	var eco: EconomyManager = get_first_node_in_group("economy")
	var upgrades: GarageUpgradeManager = get_first_node_in_group("garage_upgrades")
	var bays: RepairBayManager = get_first_node_in_group("repair_bays")

	print("== GARAJ PLAKASI ==")
	check(hud.garage_button.text == Loc.t("GARAJI DÜZENLE"), "alt sıradaki ilk plaka GARAJI DÜZENLE")
	check(not hud.profile_button.is_visible_in_tree(), "PROFİL plakası yok")
	check(hud.quest_button.get_parent() == hud.garage_button.get_parent() and hud.friends_button.get_parent() == hud.garage_button.get_parent(),
		"GÖREVLER ve ARKADAŞLAR alt sırada")
	hud.garage_button.pressed.emit()
	await frames(4)
	check(hud.router.top() == &"garage_edit", "GARAJI DÜZENLE → düzenleme ekranı")
	var edit: GarageEditScreen = hud.garage_edit_screen

	print("== YÜKSELTMELER ==")
	edit.call("_on_upgrades_pressed")
	await frames(2)
	var cards: Dictionary = edit.get("_upgrade_cards")
	check(cards.size() == 3 and cards.has(&"garage") and cards.has(&"speed") and cards.has(&"bay"), "üç kart: garaj, tamir hızı, tamir alanı")
	check((edit.get("_upgrade_button") as PlateButton).highlight, "YÜKSELTMELER modu vurgulu")
	eco.add_money(10_000_000)
	await frames(1)
	var level: int = upgrades.garage_level()
	(cards[&"garage"] as PlateButton).pressed.emit()
	await frames(1)
	var group: Control = edit.get("_upgrade_group")
	var plate: PurchasePlate = edit.get("_upgrade_plate")
	check(group.visible and plate._title.text == Loc.t("GARAJI GENİŞLET"), "garaj kartı → GARAJI GENİŞLET plakası")
	check(plate._effects.text.contains(Loc.t("DAHA SIK MÜŞTERİ").split(" ")[0]) or plate._effects.text != "", "plakada ne kazandırdığı yazar")
	(edit.get("_upgrade_buy") as PlateButton).pressed.emit()
	await frames(3)
	check(upgrades.garage_level() == level + 1 and not group.visible, "SATIN AL → garaj seviyesi arttı, plaka kapandı")
	check((cards[&"garage"] as PlateButton).text.contains(Loc.t("GARAJ SV.%d") % (level + 1)), "kart yeni seviyeyi yazar")
	var speed: int = upgrades.level(GarageUpgradeManager.SPEED_ID)
	if not upgrades.is_max(GarageUpgradeManager.SPEED_ID):
		(cards[&"speed"] as PlateButton).pressed.emit()
		await frames(1)
		(edit.get("_upgrade_buy") as PlateButton).pressed.emit()
		await frames(2)
		check(upgrades.level(GarageUpgradeManager.SPEED_ID) == speed + 1, "TAMİR HIZI yükseldi")
	var open_bays: int = bays.unlocked_count()
	while bays.unlocked_count() < bays.bay_count() and bays.status(bays.unlocked_count()) == RepairBayManager.Status.NEEDS_LEVEL \
			and not upgrades.is_max(GarageUpgradeManager.GARAGE_ID):
		upgrades.buy(GarageUpgradeManager.GARAGE_ID)
		await frames(2)
	if bays.unlocked_count() < bays.bay_count():
		(cards[&"bay"] as PlateButton).pressed.emit()
		await frames(1)
		var can: bool = not (edit.get("_upgrade_buy") as PlateButton).disabled
		(edit.get("_upgrade_buy") as PlateButton).pressed.emit()
		await frames(3)
		check(not can or bays.unlocked_count() == open_bays + 1, "TAMİR ALANI satın alındı (yer varsa)")
	edit.call("_on_mode_pressed", &"items")
	await frames(2)
	check(not edit.get("_upgrades_open") and not group.visible, "EŞYALAR'a geçince yükseltmeler kapanır")
	hud.router.close_all()
	await frames(3)

	print("== DETAY / USTALIK PROFİL'DE ==")
	hud.router.open(&"profile")
	await frames(3)
	var profile: ProfileScreen = hud.profile_screen
	check(profile.get("_value_button") != null and profile.get("_mastery_button") != null, "PROFİL'de garaj değeri (detay) ve ustalık plakaları")
	(profile.get("_mastery_button") as PlateButton).pressed.emit()
	await frames(3)
	check(hud.mastery_screen.visible, "PROFİL → USTALIK")
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
