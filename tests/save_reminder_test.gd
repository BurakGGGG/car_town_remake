extends SceneTree
## HESABA KAYDET HATIRLATMASI (2026-10-28, kullanıcı kararı: taslak B + C) — oyunun içinde, Firebase eklentisi olmadan
## (SaveReminder.force_guest: misafir sayılır):
##   B kart: sv5'te sakin anda bir kez açılır, oyuncunun seviye / para / elmasını gösterir, SONRA kapatır ve o eşikte bir
##     daha gelmez; sv10'da yeniden; açık pano / ders varken açılmaz; GOOGLE / E-POSTA hesap panosunu açar; hesaplı oyuncuya
##     hiç açılmaz; kayıt eşikleri saklar; güncellemeyle sv12'de ilk kez gören tek kart görür.
##   C şerit: misafirken MARKET'te her sekmede görünür, HESABA KAYDET hesap panosunu açar; misafir değilse yok.
## Hediyenin buluta eşitlenince verilmesi login_flow_test'te (sahte Firebase).
##   tools/run_tests.sh save_reminder_test

var fails: int = 0
var hud: Hud
var reminder: SaveReminder
var progress: PlayerProgress


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func seconds(t: float) -> void:
	await create_timer(t).timeout


func g(group: StringName) -> Node:
	return get_first_node_in_group(group)


func _initialize() -> void:
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(12)
	hud = main.find_child("HUD", true, false) as Hud
	reminder = g(&"save_reminder") as SaveReminder
	progress = g(&"player_progress") as PlayerProgress
	hud.save_prompt_session = 0.0   # oturumun ilk dakikası beklenmez
	hud.router.close_all()
	await _not_guest()
	await _card()
	await _strip()
	print("SONUC: fails=%d" % fails)
	quit(1 if fails > 0 else 0)


## Masaüstünde eklenti yok: misafir sayılmaz (hesapla giriş yok) → kart ve şerit çıkmaz.
func _not_guest() -> void:
	print("== Hesapla giriş olmayan yerde (PC) hiç çıkmaz ==")
	check(reminder != null and not reminder.is_guest(), "SaveReminder kuruldu, PC'de misafir sayılmıyor")
	progress.load_state(6, 0, 40)
	await seconds(2.4)
	check(hud.router.top() != &"save_reminder" and not hud.save_reminder_card.visible, "sv6 ama giriş yok: kart açılmadı")


func _card() -> void:
	print("== B: sv5 kartı ==")
	SaveReminder.force_guest = true
	reminder.reset()
	progress.load_state(4, 0, 40)
	await seconds(2.4)
	check(not hud.save_reminder_card.visible, "sv4: kart yok")
	hud.router.open(&"quests")
	progress.load_state(5, 0, 40)
	await seconds(2.4)
	check(not hud.save_reminder_card.visible and hud.router.top() == &"quests", "sv5 ama GÖREVLER açık: kart beklemede")
	hud.router.close_all()
	await seconds(2.4)
	check(hud.router.top() == &"save_reminder" and hud.save_reminder_card.visible, "pano kapanıp sakin kalınca kart açıldı")
	var texts: String = _texts(hud.save_reminder_card)
	check(texts.contains("SEVİYE 5") and texts.contains("40 GEM") and texts.contains("+%d GEM" % SaveReminder.BONUS_GEMS),
		"oyuncunun seviyesi, elması ve hediye yazıyor")
	var later: PlateButton = hud.save_reminder_card.find_child("LaterButton", true, false) as PlateButton
	later.pressed.emit()
	await seconds(0.8)
	check(not hud.save_reminder_card.visible and hud.router.top() == &"", "SONRA kapattı")
	await seconds(2.4)
	check(not hud.save_reminder_card.visible and reminder.due(5) == 0, "sv5 eşiği bir daha gelmez")
	check((reminder.state()["shown"] as Array) == [5], "kayıtta gösterilen eşik: [5]")

	print("== B: sv10 kartı, GOOGLE → hesap panosu ==")
	progress.load_state(10, 0, 40)
	await seconds(2.4)
	check(hud.save_reminder_card.visible, "sv10'da kart yeniden açıldı")
	var google: PlateButton = hud.save_reminder_card.find_child("GoogleButton", true, false) as PlateButton
	google.pressed.emit()
	await seconds(0.8)
	check(not hud.save_reminder_card.visible and hud.router.top() == &"account", "GOOGLE: kart kapandı, hesap panosu açıldı")
	hud.router.close_all()
	await seconds(0.4)
	check((reminder.state()["shown"] as Array) == [5, 10] and reminder.due(12) == 0, "iki eşik de gösterildi")

	print("== B: güncellemeyle sv12'de ilk kez gören misafir tek kart görür ==")
	reminder.reset()
	progress.load_state(12, 0, 40)
	await seconds(2.4)
	check(hud.save_reminder_card.visible, "kart açıldı")
	var email: PlateButton = hud.save_reminder_card.find_child("EmailButton", true, false) as PlateButton
	email.pressed.emit()
	await seconds(0.8)
	check(hud.router.top() == &"account", "E-POSTA: hesap panosu açıldı")
	hud.router.close_all()
	await seconds(2.4)
	check(not hud.save_reminder_card.visible and (reminder.state()["shown"] as Array) == [5, 10], "ikinci kart yok, iki eşik kapandı")

	print("== B: kayıt ==")
	var saved: Dictionary = reminder.state()
	reminder.reset()
	check(reminder.due(12) == 10, "sıfırlanınca yeniden gösterilir")
	reminder.load_state(saved)
	check(reminder.due(12) == 0 and not reminder.bonus_claimed(), "kayıttan yüklenince eşikler kapalı, hediye alınmamış")
	reminder.load_state({"shown": [5, 99, "x"], "bonus": "evet"})
	check((reminder.state()["shown"] as Array) == [5], "bozuk kayıt ayıklanır")
	var gems: int = progress.gems
	check(reminder.claim_bonus() == SaveReminder.BONUS_GEMS and progress.gems == gems + SaveReminder.BONUS_GEMS
		and reminder.claim_bonus() == 0, "hediye bir kez verilir")


func _strip() -> void:
	print("== C: MARKET şeridi ==")
	SaveReminder.force_guest = true
	hud.router.open(&"gem_store")
	await seconds(0.8)
	var strip: Control = hud.gem_store_screen.find_child("GuestStrip", true, false) as Control
	check(strip != null and strip.visible, "misafir: şerit görünür")
	for tab: StringName in [GemStoreScreen.TAB_FREE, GemStoreScreen.TAB_CASH, GemStoreScreen.TAB_CODE]:
		hud.gem_store_screen._select_tab(tab)
		await frames(2)
		check(strip.visible, "%s sekmesinde de şerit duruyor" % tab)
	hud.gem_store_screen._select_tab(GemStoreScreen.TAB_GEMS)
	var button: PlateButton = strip.find_child("SaveAccountButton", true, false) as PlateButton
	button.pressed.emit()
	await seconds(0.8)
	check(hud.router.top() == &"account" and not hud.gem_store_screen.visible, "HESABA KAYDET: MARKET kapandı, hesap panosu açıldı")
	hud.router.close_all()
	await seconds(0.6)
	SaveReminder.force_guest = false
	hud.router.open(&"gem_store")
	await seconds(0.8)
	check(not strip.visible, "misafir değil: şerit yok")
	hud.router.close_all()
	await seconds(0.4)


## Kontrolün altındaki bütün Label / Button yazıları.
func _texts(node: Node) -> String:
	var out: String = ""
	if node is Label:
		out += (node as Label).text + "\n"
	elif node is Button:
		out += (node as Button).text + "\n"
	for child: Node in node.get_children():
		out += _texts(child)
	return out
