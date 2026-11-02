extends SceneTree
## MOTOR SES LABORATUVARI QA: laboratuvarı açar, sesin üretilmesini bekler, gaz patlatır, kalkış + vites ve yanından
## geçiş senaryolarını çalıştırır, ekran görüntüsü alır, akış sayısını ve süreleri yazar.
##   godot-4 --path . -s res://qa/motor_lab_qa.gd -- <çıktı_klasörü> [<araç_id>]
const LabUI = preload("res://tools/engine_lab/engine_lab_ui.gd")
const LabSim = preload("res://tools/engine_lab/lab_sim.gd")

var _out: String = "/home/burak/Projects/ct_shots/motor_lab/"
var _ui: Control


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0].path_join("")
	DirAccess.make_dir_recursive_absolute(_out)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var screen: Rect2i = DisplayServer.screen_get_usable_rect()
	DisplayServer.window_set_size(Vector2i(mini(1600, screen.size.x - 40), mini(960, screen.size.y - 60)))
	_ui = LabUI.new()
	root.add_child(_ui)
	_run.call_deferred(StringName(args[1]) if args.size() > 1 else &"")


func _run(id: StringName) -> void:
	if id != &"":
		_ui.call("_load_car", id)
	await _wait(2.0)
	_shot("01_acilis")
	_ui.call("_play_script", LabSim.blip())
	await _wait(0.5)
	_shot("02_gaz")
	_ui.call("_play_script", LabSim.launch())
	await _wait(5.0)
	_shot("03_kalkis")
	print("akış: ", (_ui.get("_voice") as EngineVoice).active_streams(), "  devir: ", _ui.get("_sim").get("rpm"))
	_ui.call("_on_pass")
	await _wait(3.5)
	_shot("04_gecis")
	await _wait(6.0)
	# Parametre değiştir → yeniden üretim süresi
	_ui.call("_set_param", "muffler_cut", 3000.0, true)
	await _wait(2.0)
	print("bilgi: ", (_ui.get("_info") as Label).text)
	await _shot("05_param")
	quit()


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _shot(name: String) -> void:
	await process_frame
	var image: Image = root.get_texture().get_image()
	image.save_png(_out + name + ".png")
