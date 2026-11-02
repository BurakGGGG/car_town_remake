extends SceneTree
## DİNO ATÖLYESİ QA: DynoView'u kendi SubViewport'unda açar (garaj ekranı olmadan), marş + DİNO KOŞUSU çalıştırır,
## üç kameradan kare alır, ölçümleri yazar.
##   godot-4 --path . --resolution 1152x648 -s res://qa/dino_qa.gd -- <çıktı_klasörü> [<araç_id>]
const DEFAULT_OUT: String = "/home/burak/Projects/ct_shots/dino/oyun/"

var _out: String = DEFAULT_OUT
var _viewport: SubViewport
var _view: DynoView


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0].path_join("")
	DirAccess.make_dir_recursive_absolute(_out)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var holder: SubViewportContainer = SubViewportContainer.new()
	holder.stretch = true
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(holder)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.size = Vector2i(1152, 648)
	holder.add_child(_viewport)
	var camera: Camera3D = Camera3D.new()
	_viewport.add_child(camera)
	camera.current = true
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.name = "KeyLight"
	_viewport.add_child(key)
	_view = DynoView.new()
	root.add_child(_view)
	_run.call_deferred(StringName(args[1]) if args.size() > 1 else &"toyota_supra", camera, key)


func _run(id: StringName, camera: Camera3D, key: DirectionalLight3D) -> void:
	var ok: bool = _view.enter(id, _viewport, camera, key, [])
	print("enter: ", ok)
	if not ok:
		quit(1)
		return
	await _wait(1.0)
	await _shot("1_genel_kapali")
	await _wait(3.0)   # motor kendiliğinden çalışır
	print("motor: ", _view.sim.running, "  devir ", _view.sim.rpm)
	_view.pull_measured.connect(func(peak: float, record: bool) -> void: print("ÖLÇÜM ", peak, " rekor ", record))
	_view.set_throttle(1.0)
	await _wait(1.0)
	await _shot("2_genel_gaz")
	_view.set_throttle(0.0)
	await _wait(2.5)
	_view.exit()
	quit()


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	_viewport.get_texture().get_image().save_png(_out + name + ".png")
