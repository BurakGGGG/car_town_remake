extends SceneTree
## ÖNCE/SONRA: aynı aracı iki kaynaktan yan yana çeker (üst sıra eski, alt sıra yeni değil —
## tek karede iki örnek). Kullanım: -- <eski_glb> <yeni_glb>
## Amaç: kaynaştırma + tanjant atmanın görsel bedeli var mı, yakın planda bakılsın.
const OUT: String = "/home/burak/Projects/ct_shots/kiyas/"
var _f: int = 0
var _paths: PackedStringArray

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_paths = OS.get_cmdline_user_args()
	var w: Node3D = Node3D.new()
	get_root().add_child(w)
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.22, 0.23, 0.25)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.92, 0.94, 0.98)
	e.ambient_light_energy = 1.0
	env.environment = e
	w.add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40.0, -120.0, 0.0)   # yalayan ışık: yüzey kırığı belli olur
	sun.light_energy = 1.3
	w.add_child(sun)
	for i: int in _paths.size():
		var car: Node3D = (load(_paths[i]) as PackedScene).instantiate()
		car.position = Vector3(float(i) * 0.62 - 0.31, 0.0, 0.0)
		car.rotation_degrees = Vector3(0.0, 208.0, 0.0)
		w.add_child(car)
	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = 1.30            # araç ~700 px: oyundakinin iki katı (en kötü durum)
	cam.position = Vector3(0.0, 0.57, 3.0)
	cam.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
	w.add_child(cam)

func _process(_d: float) -> bool:
	_f += 1
	if _f < 12:
		return false
	RenderingServer.force_draw()
	var name: String = _paths[_paths.size() - 1].get_file().get_basename()
	get_root().get_texture().get_image().save_png(OUT + "oncesonra_%s.png" % name)
	print("çekildi: %s" % (OUT + "oncesonra_%s.png" % name))
	quit(0)
	return true
