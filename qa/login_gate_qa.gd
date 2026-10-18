extends SceneTree
## İLK AÇILIŞ GİRİŞ EKRANI (LoginGate): yükleme çubuğu dolunca giriş seçenekleri gelir mi, düğmeler
## tuvale sığıyor mu, yazılar düğmeye sığıyor mu, ekran açıkken ders başlamıyor mu, E-POSTA penceresi (adres → kod;
## sunucu sahte: kod gönderildi / yanlış kod), FACEBOOK ("üzerinde çalışıyoruz"), GOOGLE (PC'de eklenti yok → uyarı),
## MİSAFİR onay penceresi (GERİ DÖN → seçenekler; DEVAM ET → oyun), misafirden sonra ekran kalkıp seçim kaydediliyor mu.
## Görüntüler ~/Projects/ct_shots/login_gate/<etiket>_*.png.
## PC'de ekran yalnız CT_LOGIN_GATE=1 ile açılır:
##   CT_LOGIN_GATE=1 QA_LANG=tr tools/qa_isolated.sh res://qa/login_gate_qa.gd --display-driver x11 \
##       --resolution 1152x648 -- p16x9 mobil
## mobil: tuval ölçeği 1,35 (telefon); masaustu: 1.
const OUT: String = "/home/burak/Projects/ct_shots/login_gate/"
const BUTTONS: Array[String] = ["FacebookButton", "GoogleButton", "EmailButton", "GuestButton"]

var _tag: String = "qa"
var _problems: int = 0


## E-posta penceresi için sahte eklenti (PC'de yok): kod adımını görmek yeter, girişe gidilmez.
class StubPlugin extends Object:
	func signInWithCustomToken(_token: String) -> void:
		pass


## Sahte Cloud Function: kod hep "gönderilir", doğrulamada kod yanlış.
static func _fake_function(fn_name: String, _data: Dictionary) -> Dictionary:
	if fn_name == "emailCodeSend":
		return {"resend_after": 60}
	return {"error": "wrong_code", "attempts_left": 4}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_tag = args[0]
	if args.size() < 2 or args[1] != "masaustu":
		get_root().content_scale_factor = 1.35
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("  TAMAM " if ok else "  SORUN ") + what)
	if not ok:
		_problems += 1


func _shot(name: String) -> void:
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(OUT + _tag + "_" + name + ".png")


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame


func _until(condition: Callable, seconds: float) -> bool:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		if condition.call():
			return true
		await process_frame
	return false


## Denetimin (ya da penceredeki her düğmenin) tuvalin içinde olduğu.
func _check_fits(control: Control, canvas: Rect2, what: String) -> void:
	if control == null:
		_check(false, "%s yok" % what)
		return
	for button: Node in [control] + control.find_children("*", "Button", true, false):
		var rect: Rect2 = (button as Control).get_global_rect()
		if (button as Control).is_visible_in_tree() and rect.size.x > 0.0:
			_check(canvas.encloses(rect), "%s: %s tuvalde %s" % [what, button.name, rect])


func _gate() -> Control:
	var loading: Node = root.get_node_or_null("LoadingScreen")
	return loading.find_child("LoginGate", true, false) as Control if loading else null


func _run() -> void:
	change_scene_to_file(String(ProjectSettings.get_setting("application/run/main_scene")))
	var appeared: bool = await _until(func() -> bool: return _gate() != null, 40.0)
	_check(appeared, "yükleme bitince giriş ekranı geldi")
	if not appeared:
		quit(1)
		return
	await _frames(60)   # düğmeler belirsin
	_shot("1_kapi")
	var gate: Control = _gate()
	var canvas: Rect2 = Rect2(Vector2.ZERO, root.get_visible_rect().size)
	print("  tuval: %s" % canvas.size)
	var rects: Array[Rect2] = []
	for button_name: String in BUTTONS:
		var button: Button = gate.find_child(button_name, true, false) as Button
		_check(button != null, "%s var" % button_name)
		if button == null:
			continue
		var rect: Rect2 = button.get_global_rect()
		rects.append(rect)
		_check(canvas.encloses(rect), "%s tuvalde %s" % [button_name, rect])
		_check(not button.disabled, "%s basılabilir" % button_name)
		var labels: Array[Node] = button.find_children("*", "Label", true, false)
		var label: Label = labels[0] as Label if not labels.is_empty() else null
		if label:
			var font: Font = label.get_theme_font(&"font")
			var font_size: int = label.get_theme_font_size(&"font_size")
			var widest: float = 0.0
			for word: String in label.text.split(" ", false):
				widest = maxf(widest, font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
			_check(widest <= label.size.x + 0.5, "%s yazı sözcükleri sığıyor (%.0f / %.0f)" % [button_name, widest, label.size.x])
			_check(label.get_line_count() <= 2 and label.get_minimum_size().y <= button.size.y,
				"%s yazı %d satır, boy %.0f / %.0f: \"%s\"" % [button_name, label.get_line_count(),
				label.get_minimum_size().y, button.size.y, label.text.replace("\n", " ")])
	for i: int in rects.size():
		for j: int in range(i + 1, rects.size()):
			_check(not rects[i].intersects(rects[j]), "düğme %d ile %d çakışmıyor" % [i, j])

	var tutorial: TutorialDirector = null
	var hud: Node = current_scene.find_child("HUD", true, false) if current_scene else null
	if hud:
		tutorial = hud.get(&"tutorial") as TutorialDirector
	_check(tutorial == null or not tutorial.is_running(), "giriş ekranı açıkken ders başlamadı")

	var status: Label = gate.find_child("Status", true, false) as Label
	var cloud: CloudSaveManager = get_first_node_in_group("cloud_save") as CloudSaveManager
	var stub: StubPlugin = StubPlugin.new()
	cloud._fb = stub
	cloud._call_function = _fake_function
	(gate.find_child("EmailButton", true, false) as Button).pressed.emit()
	await _frames(20)
	var panel: Control = gate.find_child("EmailCodePanel", true, false) as Control
	_check(panel != null and panel.visible, "E-POSTA → kod penceresi açıldı")
	if panel:
		_check_fits(panel, canvas, "e-posta penceresi")
		_shot("2_eposta")
		var edit: LineEdit = panel.find_child("Input", true, false) as LineEdit
		var primary: Button = panel.find_child("PrimaryButton", true, false) as Button
		edit.text = "yanlis-adres"
		primary.pressed.emit()
		await _frames(6)
		_shot("2b_eposta_hatali")
		edit.text = "oyuncu@example.com"
		primary.pressed.emit()
		await _frames(10)
		_check(edit.max_length == 6 and edit.text.is_empty(), "kod gönderildi → 6 haneli kod adımı")
		_shot("2c_kod")
		edit.text = "123456"
		edit.text_changed.emit("123456")   # 6 hane dolunca kendiliğinden doğrulanır
		await _frames(10)
		_shot("2d_kod_yanlis")
		_check_fits(panel, canvas, "kod penceresi")
		(panel.find_child("BackButton", true, false) as Button).pressed.emit()   # E-POSTAYI DEĞİŞTİR
		await _frames(4)
		(panel.find_child("BackButton", true, false) as Button).pressed.emit()   # VAZGEÇ
		await _frames(6)
	_check(gate.find_child("EmailCodePanel", true, false) == null and (gate.find_child("EmailButton", true, false) as Control).is_visible_in_tree(),
		"VAZGEÇ → pencere kapandı, seçenekler geri geldi")
	cloud._fb = null
	stub.free()
	(gate.find_child("FacebookButton", true, false) as Button).pressed.emit()
	await _frames(10)
	var facebook: Button = gate.find_child("FacebookButton", true, false) as Button
	_check(not facebook.disabled and status.text == Loc.t("Facebook girişi üzerinde çalışıyoruz, çok yakında!"),
		"FACEBOOK (Meta onayı bekleniyor) → \"%s\"" % status.text)
	_shot("2e_facebook")
	(gate.find_child("GoogleButton", true, false) as Button).pressed.emit()
	await _frames(10)
	var google: Button = gate.find_child("GoogleButton", true, false) as Button
	_check(not google.disabled and status.visible, "GOOGLE (PC, eklenti yok) → düğmeler geri geldi, \"%s\"" % status.text)
	_check(root.get_node_or_null("LoadingScreen") != null, "GOOGLE başarısızken ekran yerinde")
	_shot("3_google_pc")

	(gate.find_child("GuestButton", true, false) as Button).pressed.emit()
	await _frames(20)
	var confirm: Control = gate.find_child("GuestConfirm", true, false) as Control
	_check(confirm != null and root.get_node_or_null("LoadingScreen") != null, "MİSAFİR → önce onay penceresi, ekran yerinde")
	if confirm:
		_check_fits(confirm.find_child("BackButton", true, false) as Control, canvas, "misafir onayı GERİ DÖN")
		_check_fits(confirm.find_child("GuestConfirmButton", true, false) as Control, canvas, "misafir onayı DEVAM ET")
		_shot("3b_misafir_onay")
		(confirm.find_child("BackButton", true, false) as Button).pressed.emit()
		await _frames(6)
		_check(gate.find_child("GuestConfirm", true, false) == null and root.get_node_or_null("LoadingScreen") != null,
			"GERİ DÖN → seçeneklere dönüldü")
		(gate.find_child("GuestButton", true, false) as Button).pressed.emit()
		await _frames(10)
		confirm = gate.find_child("GuestConfirm", true, false) as Control
		(confirm.find_child("GuestConfirmButton", true, false) as Button).pressed.emit()
	var gone: bool = await _until(func() -> bool: return root.get_node_or_null("LoadingScreen") == null, 3.0)
	_check(gone, "MİSAFİR → yükleme ekranı kalktı")
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(CloudSaveManager.META_PATH))
	_check(meta is Dictionary and bool(meta.get("login_prompt_seen", false)), "seçim kaydedildi (login_prompt_seen)")
	await _frames(30)
	_shot("4_oyun")
	print("TOPLAM SORUN: %d" % _problems)
	quit(0 if _problems == 0 else 1)
