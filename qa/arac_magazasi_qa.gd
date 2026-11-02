extends SceneTree
## ARAÇ MAĞAZASI görsel denetimi (2026-11-02): showroom ARAÇLAR sekmesi telefon tuvalinde (pencere 1152x648 / 1440x648,
## ölçek 1,35 = 853x480 / 1067x480). Kareler: KASALAR, ARAÇLAR (₺ + gem), yalnız gem araç, yoldaki sipariş (reklam
## teklifi), kilitli araç. Araç rafın üstünde ve bilgi plakasının solunda görünmeli; plaka + düğmeler orta satıra
## sığmalı. Kullanım: CT_NO_TUTORIAL=1 QA_LANG=tr tools/qa_isolated.sh res://qa/arac_magazasi_qa.gd --resolution 1152x648

const OUT: String = "/home/burak/Projects/ct_shots/arac_magazasi/"

var _fails: int = 0
var _tag: String = ""


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
	await _frames(20)
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute(OUT)
	var path: String = OUT + "%s_%s.png" % [_tag, name]
	get_root().get_texture().get_image().save_png(path)
	print("  kare: " + path)


## Bilgi grubu ve raf ekrana sığıyor, birbirine binmiyor mu.
func _fits(showroom: ShowroomScreen, label: String) -> void:
	var screen: Rect2 = Rect2(Vector2.ZERO, get_root().get_visible_rect().size)
	var info: Control = showroom.get("_info_group")
	var tray: Control = showroom.get("_tray")
	var info_rect: Rect2 = info.get_global_rect()
	var ok: bool = screen.encloses(info_rect.grow(-1.0))
	if tray.visible:
		var tray_rect: Rect2 = tray.get_global_rect()
		ok = ok and screen.encloses(tray_rect.grow(-1.0)) and info_rect.end.y <= tray_rect.position.y + 1.0
	_check(ok, "%s: bilgi %s, raf %s, ekran %s" % [label, info_rect, tray.get_global_rect() if tray.visible else "-", screen.size])


func _run() -> void:
	root.content_scale_factor = 1.35
	_tag = "%dx%d_%s" % [get_root().size.x, get_root().size.y, OS.get_environment("QA_LANG") if OS.get_environment("QA_LANG") != "" else "tr"]
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(60)
	var hud: Hud = main.find_child("HUD", true, false)
	var progress: PlayerProgress = get_first_node_in_group("player_progress")
	var shop: CarShop = get_first_node_in_group("car_shop")
	progress.level = 16
	progress.add_gems(300)
	(get_first_node_in_group("economy") as EconomyManager).set_money(420_000)
	await _frames(10)
	hud.router.open(&"showroom")
	await _frames(60)
	var showroom: ShowroomScreen = hud.showroom
	_fits(showroom, "KASALAR")
	await _shot("1_kasalar")
	(showroom.get("_tab_cars") as PlateButton).button_pressed = true
	await _frames(40)
	var cards: Dictionary = showroom.get("_cards")
	(cards[&"honda_civic"] as PlateButton).button_pressed = true
	await _frames(40)
	_fits(showroom, "ARAÇLAR")
	await _shot("2_araclar")
	(cards[&"toyota_ae86"] as PlateButton).button_pressed = true
	await _frames(30)
	var cash: PlateButton = showroom.get("_cash_button")
	cash.pressed.emit()
	await _frames(4)
	await _shot("3_emin_misin")
	cash.pressed.emit()
	await _frames(30)
	_check(shop.is_ordered(&"toyota_ae86"), "TRUENZO sipariş edildi")
	_fits(showroom, "YOLDA")
	await _shot("4_yolda")
	progress.level = 30
	progress.add_gems(2000)
	(showroom.get("_chips")[&"prestige_crate"] as PlateButton).button_pressed = true
	await _frames(20)
	cards = showroom.get("_cards")
	(cards[&"mercedes_g"] as PlateButton).button_pressed = true
	await _frames(40)
	_fits(showroom, "YALNIZ GEM")
	await _shot("5_yalniz_gem")
	(showroom.get("_chips")[&"super_crate"] as PlateButton).button_pressed = true
	await _frames(40)
	await _shot("6_kilitli")
	print("SONUC: fails=%d" % _fails)
	quit(1 if _fails > 0 else 0)
