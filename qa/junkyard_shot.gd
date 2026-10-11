extends SceneTree
## HURDALIK GÖRÜNTÜSÜ: JunkyardWorld'ü tek başına kurar, birkaç yakınlıkta ekran görüntüsü alır.
## Kullanım: godot-4 --path . --display-driver x11 --disable-vsync --resolution 1280x720 \
##     -s res://qa/junkyard_shot.gd [-- contrast=1.25 tone=agx|linear tag=x]
## Çıktı: ~/Projects/ct_shots/junkyard/godot_<zoom><tag>.png
## İlk yakınlık (23,06) Blender render'ıyla (render.py, ortho 41, 1280×720) aynı kadrajdır: üst üste
## konup karşılaştırılabilir.

const OUT: String = "/home/burak/Projects/ct_shots/junkyard/"
const ZOOMS: Array[float] = [23.0625, 34.0, 12.0]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world: JunkyardWorld = JunkyardWorld.new()
	root.add_child(world)
	world.camera.make_current()
	var ids: Array[StringName] = [&"tofas_murat_124", &"vw_beetle_1967", &"chevrolet_bel_air_1956"]
	world.show_daily(ids)
	world.set_active(true)
	for i: int in world.piles.size():
		world.set_pile_ready(i, i % 2 == 0)
	var tag: String = ""
	for arg: String in OS.get_cmdline_user_args():
		var key: String = arg.get_slice("=", 0)
		var value: String = arg.get_slice("=", 1)
		match key:
			"tone":
				_env(world).tonemap_mode = Environment.TONE_MAPPER_LINEAR if value == "linear" \
					else Environment.TONE_MAPPER_AGX
			"contrast":
				_env(world).tonemap_agx_contrast = float(value)
			"tag":
				tag = "_" + value
	for zoom: float in ZOOMS:
		world.camera.size = zoom
		world.camera.set("_target_size", zoom)
		world.camera.pan_by_pixels(Vector2.ZERO)
		for k: int in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		var path: String = OUT + "godot_%d%s.png" % [int(zoom), tag]
		image.save_png(path)
		print("KAYIT ", path)
	quit(0)


func _env(world: Node) -> Environment:
	return (world.find_children("*", "WorldEnvironment", false, false)[0] as WorldEnvironment).environment
