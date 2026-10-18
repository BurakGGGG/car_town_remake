extends SceneTree
## DEKOR DENETİMİ: her yerleştirilebilir eşya oyunun kurucusuyla (DecorBuilder.build_placeable) kurulur ve iki açıdan
## çizilir: oyun kamerasının açısı (önden, güneydoğu, ~25° yukarıdan) ve tam tersi (arkadan). Parçası yerinden
## kaymış / havada / gövdeden taşmış eşyalar (2026-10-18: neon_garage, motorcycle, dog_house) gözle buradan bulunur.
## Çıktı: ~/Projects/ct_shots/dekor_denetim/<id>_a.png (ön) ve <id>_b.png (arka); tablo için tools/decor/denetim_tablo.py.
## Kullanım (PENCERELİ — başsızda çizim yok):
##   godot-4 --path . --display-driver x11 --resolution 640x360 --script res://qa/dekor_denetim.gd [-- <id> ...]

const OUT_DIR: String = "/home/burak/Projects/ct_shots/dekor_denetim/"
const SIZE: Vector2i = Vector2i(320, 320)
## Oyun kamerasının bakış yönünün tersi (Main.tscn MainCamera basis z): hedeften kameraya.
const VIEW_FRONT: Vector3 = Vector3(0.6408563, 0.42261827, 0.6408563)

var _vp: SubViewport
var _cam: Camera3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_setup()
	var only: PackedStringArray = OS.get_cmdline_user_args()
	var ids: Array[StringName] = []
	for entry: Dictionary in GarageDecor.all():
		var id: StringName = StringName(String(entry.get("id", "")))
		if not GarageDecor.is_placeable(id) or GarageDecor.is_vehicle(id):
			continue
		if not only.is_empty() and not only.has(String(id)):
			continue
		ids.append(id)
	var list: Array[String] = []
	for id: StringName in ids:
		var node: Node3D = DecorBuilder.build_placeable(id)
		if node == null:
			print("KURULAMADI ", id)
			continue
		_vp.add_child(node)
		await process_frame
		var box: AABB = DecorBuilder._local_bounds(node)
		for side: String in ["a", "b"]:
			var dir: Vector3 = VIEW_FRONT if side == "a" else Vector3(-VIEW_FRONT.x, VIEW_FRONT.y, -VIEW_FRONT.z)
			_frame(box, dir.normalized())
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			_vp.get_texture().get_image().save_png(OUT_DIR + String(id) + "_" + side + ".png")
		list.append("%s\t%s\t%.3f %.3f %.3f" % [id, GarageDecor.placement(id), box.size.x, box.size.y, box.size.z])
		node.queue_free()
		await process_frame
	var file: FileAccess = FileAccess.open(OUT_DIR + "liste.tsv", FileAccess.WRITE)
	file.store_string("\n".join(list) + "\n")
	print("DEKOR DENETİMİ: %d eşya → %s" % [list.size(), OUT_DIR])
	quit()


func _setup() -> void:
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.56, 0.6, 0.64)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.75, 0.78)
	env.ambient_light_energy = 0.7
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = env
	_vp.add_child(world_env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	sun.light_energy = 1.1
	_vp.add_child(sun)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_vp.add_child(_cam)
	_cam.current = true


## Kamera eşyayı tam kadraja alır (ortografik; boyut kutunun en büyük kenarına göre).
func _frame(box: AABB, dir: Vector3) -> void:
	var center: Vector3 = box.get_center()
	var extent: float = maxf(box.size.length(), 0.05)
	_cam.size = extent * 1.15
	_cam.near = 0.01
	_cam.far = extent * 20.0
	_cam.global_position = center + dir * extent * 4.0
	_cam.look_at(center, Vector3.UP)
