extends SceneTree
## KOLEKSİYON ödülleri görsel denetimi (2026-10-25): telefon tuvalinde (1152x648 + content_scale 1,35 = 853x480; geniş
## 1440x648 → 1067x480) SET TAMAMLANDI! ekranı ve KOLEKSİYON panosu (kilometre taşı şeridi, set satırları). Kip (betik
## argümanı): set (tek set) | coklu (birkaç set + 10 araç taşı) | tam (TAM KOLEKSİYON) | pano (yarım koleksiyonla pano).
##   tools/qa_isolated.sh res://qa/koleksiyon_qa.gd --resolution 1152x648 --display-driver x11 -- set
## Kareler ~/Projects/ct_shots/koleksiyon/.

const OUT: String = "/home/burak/Projects/ct_shots/koleksiyon/"

var fails: int = 0
var prefix: String = ""


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + prefix + file + ".png")


func _initialize() -> void:
	if not OS.get_cmdline_user_args().has("masaustu"):
		get_root().content_scale_factor = 1.35
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func _add(ownership: VehicleOwnership, cars: Array) -> void:
	for car: Variant in cars:
		ownership.add_vehicle(StringName(car))


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var mode: String = args[0] if not args.is_empty() and args[0] != "masaustu" else "set"
	change_scene_to_file("res://Main.tscn")
	await create_timer(4.0).timeout
	var canvas: Vector2 = root.get_visible_rect().size
	prefix = "%dx%d_%s_%s_" % [roundi(canvas.x), roundi(canvas.y), Loc.current(), mode]
	var hud: Hud = root.get_node("World/HUD") as Hud
	var ownership: VehicleOwnership = get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	hud.router.close_all()
	match mode:
		"coklu":
			_add(ownership, CrateCatalog.get_set(&"bavyera")["cars"])
			_add(ownership, CrateCatalog.get_set(&"kore_hatti")["cars"])
			_add(ownership, CrateCatalog.get_set(&"ralli_efsaneleri")["cars"])
		"tam":
			for entry: Dictionary in CarCatalog.all():
				ownership.add_vehicle(StringName(String(entry["id"])))
		"pano":
			_add(ownership, CrateCatalog.get_set(&"yerli_klasikler")["cars"])
			_add(ownership, CrateCatalog.get_set(&"bavyera")["cars"])
			_add(ownership, (CrateCatalog.get_set(&"ralli_efsaneleri")["cars"] as Array).slice(0, 4))
			_add(ownership, (CrateCatalog.get_set(&"premium")["cars"] as Array).slice(0, 5))
		_:
			_add(ownership, CrateCatalog.get_set(&"yerli_klasikler")["cars"])
	var screen: CollectionRewardScreen = hud.collection_reward_screen
	await create_timer(2.6).timeout   # sakin an + kartlar sırayla oturur
	check(screen.visible, "SET TAMAMLANDI! açık")
	var cards: HBoxContainer = screen.get("_cards")
	var view: Rect2 = root.get_visible_rect()
	check(view.encloses(cards.get_global_rect().grow(-1.0)), "kartlar ekrana sığıyor (%s / %s)" % [cards.get_global_rect(), view])
	await shot("01_odul")
	(screen.find_child("CollectButton", true, false) as PlateButton).pressed.emit()
	await create_timer(0.5).timeout
	await shot("02_topla")
	await create_timer(2.0).timeout
	hud.router.open(&"collection")
	await create_timer(2.5).timeout   # bölümler kare kare kurulur, küçük resimler
	await shot("03_pano_ust")
	var panel: CollectionScreen = hud.collection_screen
	var scroll: ScrollContainer = panel.find_children("*", "ScrollContainer", true, false)[0] as ScrollContainer
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await create_timer(0.5).timeout
	await shot("04_pano_setler")
	print("SONUC: fails=%d" % fails)
	quit(1 if fails > 0 else 0)
