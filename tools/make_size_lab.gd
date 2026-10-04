extends SceneTree
## ARAÇ BOYUT LABORATUVARI sahnesini üretir: tüm araçlar boş bir zeminde yan yana durur; editörde
## her aracın Scale değerini elle ayarlarsın, sonra o değerler cars.json "model_scale"ine yazılır
## (garaj, drag, trafik, showroom hepsi bağlam çarpanı × bu değeri kullanır: tek kaynak).
##
## Bir araç düğümünün Scale'i = o aracın model_scale'i. Bağlam çarpanları:
##   garaj ekranı / showroom ×1,0 · trafik / dünya ×0,6 · drag yarışı ×1,2.
## Referans: 1 birimlik yeşil cetvel (garaj ekranındaki "araç ~1 birim" ölçüsü) ve 2 m'lik gerçek
## uzunluk işaretleri YOK — gerçek boyut cars.json real_dimensions'ta; burası göz kararı ayar içindir.
##
## Kullanım: godot-4 --headless --path . -s res://tools/make_size_lab.gd
## Çıktı: res://tools/size_lab.tscn (yeniden üretilince ELLE ayarlanan ölçekler SIFIRLANIR: bu betiği
## yalnızca baştan kurmak için çalıştır; ayarlı sahneyi okumak için tools/read_size_lab.gd).

const OUT: String = "res://tools/size_lab.tscn"
const COLUMNS: int = 4
const SPACING_X: float = 1.8
const SPACING_Z: float = 2.2


func _initialize() -> void:
	var root: Node3D = Node3D.new()
	root.name = "SizeLab"

	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	floor_mesh.name = "Floor"
	var plane: PlaneMesh = PlaneMesh.new()
	var rows: int = ceili(float(CarCatalog.all().size()) / float(COLUMNS))   # zemin araç sayısıyla büyür
	plane.size = Vector2(COLUMNS * SPACING_X + 2.0, float(rows) * SPACING_Z + 2.0)
	floor_mesh.mesh = plane
	var floor_mat: StandardMaterial3D = StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.55, 0.57, 0.6)
	floor_mesh.material_override = floor_mat
	floor_mesh.position = Vector3((COLUMNS - 1) * SPACING_X * 0.5, -0.001, float(rows - 1) * 0.5 * SPACING_Z)
	root.add_child(floor_mesh)
	floor_mesh.owner = root

	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.name = "Sun"
	light.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	root.add_child(light)
	light.owner = root

	# 1 birimlik cetvel: garaj ekranında araç ~1 birimdir
	var ruler: MeshInstance3D = MeshInstance3D.new()
	ruler.name = "Ruler_1_birim"
	var bar: BoxMesh = BoxMesh.new()
	bar.size = Vector3(1.0, 0.02, 0.05)
	ruler.mesh = bar
	var ruler_mat: StandardMaterial3D = StandardMaterial3D.new()
	ruler_mat.albedo_color = Color(0.2, 0.75, 0.3)
	ruler.material_override = ruler_mat
	ruler.position = Vector3(-1.2, 0.01, -1.0)
	root.add_child(ruler)
	ruler.owner = root

	var i: int = 0
	for entry: Dictionary in CarCatalog.all():
		var id: String = String(entry["id"])
		var scene: PackedScene = load(String(entry["scene_path"]))
		if scene == null:
			push_warning("size_lab: %s sahnesi yüklenemedi" % id)
			continue
		var car: Node3D = scene.instantiate() as Node3D
		car.name = id
		car.scale = Vector3.ONE * float(entry.get("model_scale", 1.0))
		car.position = Vector3((i % COLUMNS) * SPACING_X, 0.0, int(i / COLUMNS) * SPACING_Z)
		root.add_child(car)
		car.owner = root
		var label: Label3D = Label3D.new()
		label.name = "Label_" + id
		label.text = "%s\n%.4f" % [String(entry.get("display_name", id)), float(entry.get("model_scale", 1.0))]
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = 0.0025
		label.font_size = 48
		label.position = Vector3(car.position.x, 0.02, car.position.z + 0.85)
		root.add_child(label)
		label.owner = root
		i += 1

	# Yeniden üretimde sahnenin UID'si korunur (pack + save yeni dosyaya UID yazmıyor).
	var old_uid: int = ResourceLoader.get_resource_uid(OUT) if ResourceLoader.exists(OUT) else ResourceUID.INVALID_ID
	var packed: PackedScene = PackedScene.new()
	var err: int = packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, OUT)
	if err == OK and old_uid != ResourceUID.INVALID_ID:
		err = ResourceSaver.set_uid(OUT, old_uid)
	print("size_lab: %d araç, kayıt %s (hata kodu %d)" % [i, OUT, err])
	quit(0 if err == OK else 1)
