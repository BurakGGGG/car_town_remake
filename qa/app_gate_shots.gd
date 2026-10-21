extends SceneTree
## UZAKTAN AYAR PENCERELERİ görsel QA — GÜNCELLEME GEREKLİ, BAKIMDAYIZ, YENİ SÜRÜM VAR, DUYURU (oyunun üstünde).
## Telefon oranı (20:9) için 1404x648. Ağ kullanılmaz: belge apply() ile verilir.
## Kullanım: tools/qa_isolated.sh res://qa/app_gate_shots.gd --resolution 1404x648 -- <çıktı klasörü>
var _out: String = "/home/burak/Projects/ct_shots/app_gate/"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0].trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(_out)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(AppConfig.FILE))
	_run.call_deferred()


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(_out + name + ".png")
	print("çekildi: ", _out + name + ".png")


func _run() -> void:
	await frames(2)
	change_scene_to_file("res://Main.tscn")
	await frames(90)
	var config: AppConfig = AppConfig.new()
	config.name = AppConfig.NODE_NAME
	config.url = ""
	root.add_child(config)
	AppInfo.override_code = 10
	await frames(10)
	config.apply({"min_code": 11})
	await frames(40)
	await shot("update")
	config.apply({"maintenance": true, "maintenance_until": int(Time.get_unix_time_from_system()) + 5400,
		"maintenance_text": {"tr": "Yeni garaj geliyor! Birkaç dakika içinde döneceğiz."}})
	await frames(40)
	await shot("maintenance")
	config.apply({"latest_code": 12, "update_text": {"tr": "15 yeni araç ve hurdalıkta yeni parçalar geldi!"}})
	await create_timer(AppGate.CALM_SEC + 1.5).timeout
	await frames(30)
	await shot("soft_update")
	config.dismiss_soft_update()
	var gate: AppGate = config.get_node("AppGate") as AppGate
	for node: Node in gate.find_children("*", "PlateButton", true, false):
		if (node as PlateButton).text == Loc.t("SONRA"):
			(node as PlateButton).pressed.emit()
	await frames(20)
	config.apply({"latest_code": 12, "notice": {"id": "qa1", "title": {"tr": "Hafta sonu etkinliği!"},
		"text": {"tr": "Cumartesi ve pazar tüm tamirlerden çifte para kazan. Garajında görüşürüz!"}}})
	await create_timer(AppGate.CALM_SEC + 1.5).timeout
	await frames(30)
	await shot("notice")
	for node: Node in gate.find_children("*", "PlateButton", true, false):
		if (node as PlateButton).text == Loc.t("TAMAM"):
			(node as PlateButton).pressed.emit()
	config.apply({})
	await frames(20)
	# POSTA: yönetim panelinden hediye (sahte belge, ağ yok)
	var service: MailService = get_first_node_in_group("mail") as MailService
	var crate: String = String(CrateCatalog.all()[0]["id"])
	service._pending = [MailService.normalize("qa_mail", {"from": "AUTO YARD", "title": {"tr": "Açılış hediyesi!"},
		"text": {"tr": "AUTO YARD'a hoş geldin usta! Garajın için küçük bir hediye bıraktık."},
		"money": 25000, "gems": 100, "crates": {crate: 1}, "decor": {"tool_cabinet": 2}})]
	service.arrived.emit()
	await create_timer(3.0).timeout
	await frames(20)
	await shot("mail")
	var notice: MailNotice = current_scene.find_child("MailNotice", true, false) as MailNotice
	(notice.find_child("TakeButton", true, false) as PlateButton).pressed.emit()
	await create_timer(1.6).timeout
	await shot("mail_reward")
	AppInfo.override_code = 0
	quit()
