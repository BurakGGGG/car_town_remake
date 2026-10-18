extends SceneTree
## PLAYER (hesap) ekranı görüntüleri: misafir (Google + Facebook + E-posta düğmeleri; Facebook "üzerinde çalışıyoruz"),
## Facebook hesabı (GOOGLE'I BAĞLA), iki yolu bağlı hesap, hesap silme onayı, e-postayla açılmış hesap (E-POSTA HESABI,
## silme onayı, silmede kod penceresi). PC'de eklenti olmadığından durumlar CloudSaveManager'a doğrudan yazılır (yalnızca görünüm).
## Kullanım: QA_LANG=tr tools/qa_isolated.sh res://qa/login_screen_qa.gd --display-driver x11 --resolution 1152x648 -- p16x9
## Görüntüler ~/Projects/ct_shots/login_screen/<etiket>_*.png.
const OUT: String = "/home/burak/Projects/ct_shots/login_screen/"

var _tag: String = "qa"


class StubPlugin extends Object:
	func signInWithCustomToken(_token: String) -> void:
		pass


static func _fake_function(_fn_name: String, _data: Dictionary) -> Dictionary:
	return {"resend_after": 60}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_tag = args[0]
	get_root().content_scale_factor = 1.35
	_run.call_deferred()


func _shot(name: String) -> void:
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(OUT + _tag + "_" + name + ".png")


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await _frames(90)
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	var cloud: CloudSaveManager = get_first_node_in_group("cloud_save") as CloudSaveManager
	var screen: LoginScreen = hud.login_screen
	cloud._set_state(CloudSaveManager.State.SIGNED_OUT)
	hud.router.open(&"account")
	await _frames(20)
	var facebook: Button = screen.find_child("FacebookButton", true, false) as Button
	var email: Button = screen.find_child("EmailButton", true, false) as Button
	var canvas: Rect2 = root.get_visible_rect()
	print("  misafir: Facebook düğmesi görünür=%s, E-posta görünür=%s, tuvalde=%s" % [facebook.is_visible_in_tree(),
		email.is_visible_in_tree(), canvas.encloses(email.get_global_rect())])
	_shot("1_misafir")
	facebook.pressed.emit()
	await _frames(6)
	print("  Facebook'a basınca: \"%s\"" % screen._notice.text)
	_shot("1b_facebook_yakinda")
	cloud._user = {"uid": "f_1", "isAnonymous": false, "name": "Fiona Yılmaz", "email": "fiona@example.com", "provider": "facebook.com",
		"providers": "facebook.com"}
	cloud._set_state(CloudSaveManager.State.SYNCED)
	screen._refresh()
	await _frames(10)
	var link: Button = screen.find_child("LinkButton", true, false) as Button
	print("  facebook hesabı: başlık=%s, Facebook düğmesi görünür=%s, bağlama=%s \"%s\"" % [screen._account_caption.text,
		facebook.is_visible_in_tree(), link.is_visible_in_tree(), link.text])
	_shot("2_facebook_hesabi")
	cloud._user["providers"] = "google.com,facebook.com"
	screen._refresh()
	await _frames(10)
	print("  iki yol bağlı: başlık=%s, bağlama düğmesi görünür=%s" % [screen._account_caption.text, link.is_visible_in_tree()])
	_shot("2b_iki_yol")
	cloud._user["providers"] = "facebook.com"
	screen._on_delete_pressed()
	await _frames(10)
	_shot("3_silme_onayi")
	screen._on_secondary_pressed()

	# E-postayla açılmış hesap: giriş yolu bağlı değil, bu cihazda kodla girildi
	cloud._user = {"uid": "e_1", "isAnonymous": false, "name": null, "email": "eda@example.com", "provider": "", "providers": ""}
	cloud._meta["provider"] = CloudSaveManager.PROVIDER_EMAIL
	screen._refresh()
	await _frames(10)
	print("  e-posta hesabı: başlık=%s, bağlama=%s \"%s\"" % [screen._account_caption.text, link.is_visible_in_tree(), link.text])
	_shot("4_eposta_hesabi")
	screen._on_delete_pressed()
	await _frames(10)
	_shot("4b_eposta_silme_onayi")
	var stub: StubPlugin = StubPlugin.new()
	cloud._fb = stub
	cloud._call_function = _fake_function
	cloud._op = CloudSaveManager.Op.REAUTH
	cloud._sign_in_provider = CloudSaveManager.PROVIDER_EMAIL
	cloud._set_state(CloudSaveManager.State.DELETING)
	cloud.email_reauth_needed.emit("eda@example.com")
	await _frames(20)
	var panel: Control = screen.find_child("EmailCodePanel", true, false) as Control
	print("  silmede kod penceresi açık=%s" % (panel != null and panel.is_visible_in_tree()))
	_shot("4c_eposta_silme_kodu")
	cloud._fb = null
	stub.free()
	quit(0)
