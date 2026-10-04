class_name CrateVisual
extends Node3D
## DÜNYADAKİ BÜYÜK ARAÇ TESLİMAT KASASI — tek bir kasanın görünümü ve açılış animasyonu.
## Ekonomi / RNG bilmez: sonucu CrateManager belirler, bu node yalnızca gösterir.
##
## MODEL: vehicles/crates.json'daki kasanın "scene_path"i doluysa o sahne (.glb / .tscn) TEMBEL
## yüklenir (yalnızca bu kasa dünyaya konduğunda). Boşsa ya da yüklenemezse kodla kurulan yer
## tutucu kasa kullanılır — yeni görsel asset yoktur. Gerçek model sözleşmesi (crates.json _readme):
##   * kök Node3D, orijin zeminde ve kasanın ortasında, uzun kenar yerel +X boyunca;
##   * dış ölçü CrateCatalog.world_size() (farklıysa kasanın "scale" alanı);
##   * İSTEĞE BAĞLI AnimationPlayer + "open" animasyonu → açılışta o oynar;
##   * İSTEĞE BAĞLI Marker3D "VehicleAnchor" → aracın belireceği nokta (yoksa kasanın tabanı).
## Model değişince ekonomi / kayıt / açılış akışı kodu DEĞİŞMEZ: CrateDelivery yalnızca
## play_open() ve vehicle_anchor() çağırır.

## Kasaya dokunuldu (CrateDelivery dinler).
signal clicked

const PALLET_H: float = 0.04
const WALL_T: float = 0.022
const OPEN_ANIMATION: StringName = &"open"

var crate_id: StringName = &""
var uid: int = 0

var _size: Vector3 = CrateCatalog.DEFAULT_WORLD_SIZE
var _model: Node3D            # yüklenen gerçek model (varsa)
var _lid: Node3D
var _hinges: Array[Node3D] = []   # yan kapakların alt kenar menteşeleri
var _hinge_axes: Array[Vector3] = []
var _straps: Array[Node3D] = []
var _tag: Node3D
var _body: StaticBody3D


## Kasayı kurar (ağaca eklenmeden önce çağrılır).
func setup(p_crate_id: StringName, p_uid: int) -> void:
	crate_id = p_crate_id
	uid = p_uid
	name = "Crate_%d" % uid
	_size = CrateCatalog.world_size()
	var entry: Dictionary = CrateCatalog.get_entry(crate_id)
	var path: String = String(entry.get("scene_path", ""))
	if path != "" and ResourceLoader.exists(path):
		var scene: PackedScene = load(path) as PackedScene
		if scene:
			_model = scene.instantiate() as Node3D
	if _model:
		_model.name = "Model"
		_model.scale = Vector3.ONE * float(entry.get("scale", 1.0))
		add_child(_model)
	else:
		_build_placeholder(entry)
	_build_tag(entry)
	_build_click_body()


## Dış ölçü (yerel eksenlerde).
func size() -> Vector3:
	return _size


## Aracın kasanın içinde belireceği yerel nokta.
func vehicle_anchor() -> Vector3:
	var marker: Node3D = find_child("VehicleAnchor", true, false) as Node3D
	if marker:
		return to_local(marker.global_position)
	return Vector3(0.0, PALLET_H, 0.0)


## Dokunma etiketi (açılış sırasında gizlenir).
func set_tag_visible(shown: bool) -> void:
	if _tag:
		_tag.visible = shown


## Kasanın gelişi: yukarıdan iner, hafif sekerek yere oturur.
func play_arrival() -> void:
	var rest: Vector3 = position
	position = rest + Vector3(0.0, 1.1, 0.0)
	scale = Vector3.ONE * 0.9
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position", rest, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished


## AÇILIŞ: kilitler/kayışlar düşer, kapak kalkar, yan paneller dışa açılır. Gerçek modelde "open"
## animasyonu varsa o oynar. Bitince döner.
func play_open() -> void:
	set_tag_visible(false)
	var player: AnimationPlayer = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _model and player and player.has_animation(OPEN_ANIMATION):
		player.play(OPEN_ANIMATION)
		await player.animation_finished
		return
	if _model:
		# Animasyonsuz gerçek model: kısa bir sarsıntı ve hafif büyüme, sonra model gizlenir.
		var shake: Tween = create_tween()
		shake.tween_property(_model, "scale", _model.scale * 1.06, 0.18)
		shake.tween_property(_model, "scale", _model.scale * 0.01, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		await shake.finished
		return
	var tween: Tween = create_tween()
	# 1) kayışlar / kilitler
	tween.set_parallel(true)
	for strap: Node3D in _straps:
		tween.tween_property(strap, "scale", Vector3(1.0, 0.01, 1.0), 0.18)
	tween.set_parallel(false)
	# 2) kapak kalkar ve yana kayar
	tween.tween_property(_lid, "position", _lid.position + Vector3(0.0, 0.16, 0.0), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property(_lid, "position", _lid.position + Vector3(-_size.x * 0.75, -_size.y + 0.02, 0.0), 0.35).set_delay(0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_lid, "rotation", Vector3(0.0, 0.0, 0.5), 0.35).set_delay(0.22)
	tween.set_parallel(false)
	# 3) yan paneller dışa doğru yere yatar
	tween.set_parallel(true)
	for i: int in _hinges.size():
		tween.tween_property(_hinges[i], "rotation", _hinge_axes[i] * deg_to_rad(90.0), 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await tween.finished


## Açılıştan sonra boş kasa: parçalar küçülüp kaybolur.
func play_vanish() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector3(1.0, 0.01, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tween.finished


# --- Yer tutucu model ---------------------------------------------------------------

## Kodla kurulan stilize ahşap/metal araç taşıma kasası: palet, köşe dikmeleri, dört yan panel
## (alt kenardan menteşeli), kapak, metal kayışlar ve kasa etiketi. Kasanın rengi crates.json'dan.
func _build_placeholder(entry: Dictionary) -> void:
	var tint: Color = entry.get("color", Color("A08060"))
	var wood: StandardMaterial3D = _mat(tint, 0.85, 0.0)
	var trim: StandardMaterial3D = _mat(tint.darkened(0.45), 0.8, 0.0)
	var metal: StandardMaterial3D = _mat(Color("6E7479"), 0.45, 0.6)
	var sx: float = _size.x
	var sy: float = _size.y
	var sz: float = _size.z
	# Palet
	_box(self, "Pallet", Vector3(sx + 0.03, PALLET_H, sz + 0.03), Vector3(0.0, PALLET_H * 0.5, 0.0), trim)
	var wall_h: float = sy - PALLET_H - 0.03
	# Yan paneller: menteşe alt kenarda, panel onun çocuğu. Dışa yatması için dönüş ekseni.
	var sides: Array = [
		[Vector3(0.0, PALLET_H, sz * 0.5), Vector3(sx, wall_h, WALL_T), Vector3(0.0, 0.0, -WALL_T * 0.5), Vector3(1.0, 0.0, 0.0)],
		[Vector3(0.0, PALLET_H, -sz * 0.5), Vector3(sx, wall_h, WALL_T), Vector3(0.0, 0.0, WALL_T * 0.5), Vector3(-1.0, 0.0, 0.0)],
		[Vector3(sx * 0.5, PALLET_H, 0.0), Vector3(WALL_T, wall_h, sz - WALL_T * 2.0), Vector3(-WALL_T * 0.5, 0.0, 0.0), Vector3(0.0, 0.0, -1.0)],
		[Vector3(-sx * 0.5, PALLET_H, 0.0), Vector3(WALL_T, wall_h, sz - WALL_T * 2.0), Vector3(WALL_T * 0.5, 0.0, 0.0), Vector3(0.0, 0.0, 1.0)],
	]
	for i: int in sides.size():
		var hinge: Node3D = Node3D.new()
		hinge.name = "Hinge%d" % i
		hinge.position = sides[i][0]
		add_child(hinge)
		var panel_size: Vector3 = sides[i][1]
		var offset: Vector3 = sides[i][2]
		_box(hinge, "Panel", panel_size, offset + Vector3(0.0, wall_h * 0.5, 0.0), wood)
		# Panel üstünde yatay çıtalar (kasa hissi): üst ve alt kenar
		var batten: Vector3 = Vector3(panel_size.x + 0.004, 0.035, panel_size.z + 0.006)
		_no_shadow(_box(hinge, "BattenTop", batten, offset + Vector3(0.0, wall_h - 0.02, 0.0), trim))
		_no_shadow(_box(hinge, "BattenLow", batten, offset + Vector3(0.0, 0.02, 0.0), trim))
		_hinges.append(hinge)
		_hinge_axes.append(sides[i][3])
	# Köşe dikmeleri kapağa bağlı değil, panellerle birlikte açılmaz: kapakla beraber kalkar
	_lid = Node3D.new()
	_lid.name = "Lid"
	_lid.position = Vector3(0.0, sy - 0.03, 0.0)
	add_child(_lid)
	_box(_lid, "LidBoard", Vector3(sx + 0.03, 0.03, sz + 0.03), Vector3(0.0, 0.015, 0.0), wood)
	for cx: float in [-1.0, 1.0]:
		for cz: float in [-1.0, 1.0]:
			_no_shadow(_box(_lid, "Post", Vector3(0.04, sy - PALLET_H, 0.04),
				Vector3(cx * (sx * 0.5 + 0.005), -(sy - PALLET_H) * 0.5 + 0.03, cz * (sz * 0.5 + 0.005)), trim))
	# Metal kayışlar (kapağın üstünden iki yana): açılışta düşerler
	for fx: float in [-0.3, 0.3]:
		var strap: Node3D = Node3D.new()
		strap.name = "Strap"
		strap.position = Vector3(fx * sx, sy - 0.03, 0.0)
		add_child(strap)
		_no_shadow(_box(strap, "Band", Vector3(0.03, 0.012, sz + 0.05), Vector3(0.0, 0.036, 0.0), metal))
		_no_shadow(_box(strap, "Lock", Vector3(0.05, 0.06, 0.02), Vector3(0.0, -0.02, sz * 0.5 + 0.02), metal))
		_straps.append(strap)


## Küçük detay parçaları gölge çizmez: gövde, paneller ve kapak gölgeyi zaten veriyor; kasa başına
## ~12 gölge çizim çağrısı kazanılır (QA: 6 kasa +289 çizim çağrısıydı).
static func _no_shadow(node: MeshInstance3D) -> void:
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Kasanın üstünde havada duran krem plaka ("GARAJI GENİŞLET" tabelasıyla aynı dil): kasa adı + AÇ.
## Dünya-UI katmanındadır: garaj düzenleme odağında gizlenir.
func _build_tag(entry: Dictionary) -> void:
	var tag_root: Node3D = Node3D.new()
	tag_root.name = "Tag"
	tag_root.position = Vector3(0.0, _size.y + 0.17, 0.0)
	add_child(tag_root)
	var board: MeshInstance3D = MeshInstance3D.new()
	board.name = "Board"
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.4, 0.15)
	board.mesh = quad
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("F3E8CF")
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test = true
	mat.render_priority = 1
	board.material_override = mat
	board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	board.layers = WorldCamera.LAYER_WORLD_UI
	tag_root.add_child(board)
	var label: Label3D = Label3D.new()
	label.name = "Text"
	label.text = Loc.t("%s\nDOKUN · AÇ") % Loc.t(String(entry.get("display_name", Loc.t("KASA"))))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 2
	label.pixel_size = 0.00105
	label.font_size = 48
	label.outline_size = 0
	label.modulate = Color("2F3236")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.layers = WorldCamera.LAYER_WORLD_UI
	tag_root.add_child(label)
	_tag = tag_root


func _build_click_body() -> void:
	_body = StaticBody3D.new()
	_body.name = "ClickBody"
	_body.input_ray_pickable = true
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = _size + Vector3(0.06, 0.12, 0.06)   # mobilde rahat dokunma payı
	shape.shape = box
	shape.position = Vector3(0.0, _size.y * 0.5, 0.0)
	_body.add_child(shape)
	_body.input_event.connect(_on_input)
	add_child(_body)


## Açılış sırasında tekrar tıklanmasın.
func set_clickable(on: bool) -> void:
	if _body:
		_body.input_ray_pickable = on


func _on_input(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		clicked.emit()
		get_viewport().set_input_as_handled()


func _box(parent: Node3D, node_name: String, box_size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = box_size
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	parent.add_child(node)
	return node


static func _mat(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m
