extends SceneTree
## GÖRÜNÜM LABORATUVARI — şehrin ışık / gölge ön ayarlarını aynı kadrajlarda karşılaştırır (HUD gizli).
##   QA_SAVE=~/Projects/ct_shots/bench_saves/featured.json CT_NO_TUTORIAL=1 \
##   tools/qa_isolated.sh res://qa/gorunum_lab.gd --display-driver x11 --disable-vsync --resolution 1440x810 \
##   -- <ön_ayar> [<ön_ayar> ...]
## Görüntüler: /home/burak/Projects/ct_shots/gorunum/<ön_ayar>_<kadraj>.png

const OUT: String = "/home/burak/Projects/ct_shots/gorunum/"
## Kadrajlar: ad → [odak, zoom]. "acilis" kameranın açılıştaki hâli.
## QA_TOPLUSUZ=1: toplu çizim kapalı; QA_UZAKSIZ=1: araçların uzak kademesi (CarFarLod) kapalı.
const VIEWS: Dictionary = {
	"garaj": [Vector3(-2.6, 0.0, -2.2), 2.6],
	"garaj_yakin": [Vector3(-2.6, 0.0, -2.2), 2.2],   # en yakın zoom (WorldCamera.min_zoom): sergi araçları en büyük
	"showroom": [Vector3(2.4, 0.0, -0.8), 3.6],
	"park": [Vector3(-2.5, 0.0, 3.5), 3.2],
}


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	WorldShadow.debug_dir = OUT
	StaticBatch.enabled = not OS.has_environment("QA_TOPLUSUZ")   # toplu çizim (şehir + dekor) baştan kapalı
	CarFarLod.enabled = not OS.has_environment("QA_UZAKSIZ")   # araçların uzak kademesi baştan kapalı
	_run.call_deferred()


func _shot(name: String) -> void:
	await frames(4)
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("kaydedildi: ", OUT + name + ".png")


func _run() -> void:
	var presets: PackedStringArray = OS.get_cmdline_user_args()
	if presets.is_empty():
		presets = PackedStringArray(["once"])
	change_scene_to_file("res://Main.tscn")
	await frames(150)
	var hud: CanvasLayer = current_scene.find_child("HUD", true, false) as CanvasLayer
	if hud:
		hud.visible = false
	var camera: WorldCamera = root.get_camera_3d() as WorldCamera
	var home: Dictionary = camera.view_state()
	var shadow: WorldShadow = current_scene.find_child("WorldShadow", true, false) as WorldShadow
	if shadow:
		print("gölge: ", shadow.last_stats)
		if shadow.texture():
			shadow.texture().get_image().save_png(OUT + "_harita.png")
	for index: int in presets.size():
		var preset: String = presets[index]
		var tag: String = preset if presets.count(preset) == 1 else "%s~%d" % [preset, index]
		_apply(preset)
		if shadow:
			shadow.request_bake(0.0)   # güneş yönü değiştiyse harita yeniden pişsin
			await frames(20)
		camera.restore_view(home)
		await frames(40)
		await _shot(tag + "_acilis")
		if hud:
			hud.visible = true
			await frames(10)
			await _shot(tag + "_oyun")
			hud.visible = false
		for view: String in VIEWS:
			var v: Array = VIEWS[view]
			camera.follow(v[0], v[1])
			await frames(40)
			await _shot(tag + "_" + view)
	quit(0)


func _sun() -> DirectionalLight3D:
	return current_scene.get_node("Sun") as DirectionalLight3D


func _env() -> Environment:
	return current_scene.get_world_3d().environment


func _apply(preset: String) -> void:
	var sun: DirectionalLight3D = _sun()
	var env: Environment = _env()
	for part: String in preset.split("+"):
		match part:
			"once":
				_shadow_strength(0.0)
			"pisgolge":
				_shadow_strength(1.0)
			"toplusuz", "toplu":   # dekor toplu çizimi kapalı / açık (world/static_batch.gd)
				StaticBatch.enabled = part == "toplu"
				(get_first_node_in_group("garage_decor_view") as GarageDecorView).refresh()
			"golge":
				sun.shadow_enabled = true
				sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
				sun.directional_shadow_max_distance = 30.0
				sun.shadow_blur = 1.5
				sun.shadow_opacity = 0.55
			"isik":
				sun.light_color = Color("FFF1DC")
				sun.light_energy = 1.25
				env.ambient_light_color = Color("B9CCE0")
				env.ambient_light_energy = 0.8
			_ when part.begins_with("yon"):   # güneşin geldiği yön: 0 = güney, 90 = doğu (eskisi ~36)
				var r: Vector3 = sun.global_rotation_degrees
				sun.global_rotation_degrees = Vector3(r.x, float(part.substr(3)), 0.0)
			_ when part.begins_with("yuk"):   # güneşin yüksekliği (derece; eskisi ~48,6)
				var r: Vector3 = sun.global_rotation_degrees
				sun.global_rotation_degrees = Vector3(-float(part.substr(3)), r.y, 0.0)
			"agx":
				env.tonemap_mode = Environment.TONE_MAPPER_AGX
				env.tonemap_exposure = 1.25
			"filmic":
				env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
				env.tonemap_exposure = 1.2
			"canli":
				env.adjustment_enabled = true
				env.adjustment_contrast = 1.08
				env.adjustment_saturation = 1.15
			_:
				push_warning("bilinmeyen ön ayar: " + part)


func _shadow_strength(value: float) -> void:
	var shadow: WorldShadow = current_scene.find_child("WorldShadow", true, false) as WorldShadow
	if shadow:
		shadow.strength = value
