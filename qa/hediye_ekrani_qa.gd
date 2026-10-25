extends SceneTree
## HEDİYEN GELDİ! ekranı görsel denetimi (2026-10-25): telefon tuvalinde (1152x648 + content_scale 1,35 = 853x480; geniş
## 1440x648 → 1067x480) HABERLER'den AL → hediye ekranı. Kip (betik argümanı): dolu (₺ + elmas + araç + kasa + dekor +
## çerçeve) | arac (yalnız araç) | var (zaten olan araç → satış değeri).
##   tools/qa_isolated.sh res://qa/hediye_ekrani_qa.gd --resolution 1152x648 --display-driver x11 -- dolu
## Kareler ~/Projects/ct_shots/hediye_ekrani/.

const OUT: String = "/home/burak/Projects/ct_shots/hediye_ekrani/"

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


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var mode: String = args[0] if not args.is_empty() and args[0] != "masaustu" else "dolu"
	change_scene_to_file("res://Main.tscn")
	await create_timer(4.0).timeout
	var canvas: Vector2 = root.get_visible_rect().size
	prefix = "%dx%d_%s_%s_" % [roundi(canvas.x), roundi(canvas.y), Loc.current(), mode]
	var hud: Hud = root.get_node("World/HUD") as Hud
	var mail: MailService = get_first_node_in_group("mail") as MailService
	var ownership: VehicleOwnership = get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	var car: StringName = &"bugatti_chiron" if CarCatalog.is_obtainable(&"bugatti_chiron") else &"ford_focus"
	var crate: String = String(CrateCatalog.all()[0]["id"])
	var doc: Dictionary = {"title": {"tr": "HAFTA SONU HEDİYESİ", "en": "WEEKEND GIFT"}, "from": "AUTO YARD",
		"text": {"tr": "Garajına küçük bir sürpriz bıraktık!", "en": "A little surprise for your garage!"},
		"at": int(Time.get_unix_time_from_system()) - 7200}
	match mode:
		"arac":
			doc["cars"] = {String(car): 1}
		"var":
			ownership.add_vehicle(car)
			doc["cars"] = {String(car): 1}
		_:
			doc.merge({"money": 25000, "gems": 100, "cars": {String(car): 1}, "crates": {crate: 1},
				"decor": {"tool_cabinet": 2}, "frame": "inviter"}, true)
	mail._pending = [MailService.normalize("qa_gift", doc)]
	mail.arrived.emit()
	await create_timer(0.6).timeout
	hud.router.open(&"inbox")
	await create_timer(0.8).timeout
	await shot("01_kutu")
	(hud.inbox_screen.find_child("ActionButton", true, false) as PlateButton).pressed.emit()
	await create_timer(1.6).timeout   # kartlar sırayla oturur
	var gift: GiftScreen = hud.mail_notice.gift_screen()
	check(gift != null and gift.visible, "HEDİYEN GELDİ! açık")
	var column: Control = gift.get("_column")
	var cards: HBoxContainer = gift.get("_cards")
	var view: Rect2 = root.get_visible_rect()
	check(view.encloses(cards.get_global_rect().grow(-1.0)), "kartlar ekrana sığıyor (%s / %s)" % [cards.get_global_rect(), view])
	check(column != null, "sütun")
	await shot("02_hediye_ekrani")
	(gift.find_child("CollectButton", true, false) as PlateButton).pressed.emit()
	await create_timer(0.5).timeout
	await shot("03_topla")
	check(ownership.is_owned(car), "araç garajda")
	print("SONUC: fails=%d" % fails)
	quit(1 if fails > 0 else 0)
