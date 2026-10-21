extends SceneTree
## YASAK PENCERESİ görsel QA — sosyal (7 gün, açıklamalı) ve tam (kalıcı) yasak. Ağ yok: belge apply_doc ile verilir.
## Kullanım: tools/qa_isolated.sh res://qa/ban_notice_shots.gd --resolution 1170x540 -- <çıktı klasörü>
var _out: String = "/home/burak/Projects/ct_shots/ban/"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0].trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(_out)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ModerationWatch.FILE))
	_run.call_deferred()


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(_out + name + ".png")
	print("çekildi: ", _out + name + ".png")


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	for i: int in 90:
		await process_frame
	var mod: ModerationWatch = get_first_node_in_group("moderation") as ModerationWatch
	var notice: BanNotice = current_scene.find_child("BanNotice", true, false) as BanNotice
	var now: int = int(Time.get_unix_time_from_system())
	mod.apply_doc("qa_uid", {"ban": {"kind": "social", "reason": "name", "text": "Takma adında hakaret var.", "until": now + 7 * 86400, "at": now}})
	await create_timer(2.5).timeout
	await shot("social")
	(notice.find_child("OkButton", true, false) as PlateButton).pressed.emit()
	await create_timer(0.6).timeout
	mod.apply_doc("qa_uid2", {"ban": {"kind": "full", "reason": "cheat", "until": 0, "at": now + 1}})
	await create_timer(2.5).timeout
	await shot("full")
	quit()
