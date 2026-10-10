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
## Açılış anı: kapak fırladı (efekt patlaması bu anda başlar).
signal burst_open
## Kapak tepede kayboluyor (dünya konumu): efekt orada parıltıyla patlar.
signal lid_vanished(at: Vector3)

const PALLET_H: float = 0.04
const WALL_T: float = 0.022
const OPEN_ANIMATION: StringName = &"open"
## Gerçek modelin parça adları (tools/crates/make_crates.py): kapak + dört menteşe ve açılış ekseni.
## Modelin kendi animasyonu Blender'dan parça başına ayrı eylem olarak geliyor (open_Lid,
## open_Hinge_xn…), tek bir "open" yok — açılış bu parçalara KODLA oynatılır (ölçüldü: eksenler
## dışa aktarılan son karelerle aynı: xn +Z, xp −Z, yn +X, yp −X etrafında 90°).
const MODEL_HINGES: Dictionary = {
	"Hinge_xn": Vector3(0.0, 0.0, 1.0), "Hinge_xp": Vector3(0.0, 0.0, -1.0),
	"Hinge_yn": Vector3(1.0, 0.0, 0.0), "Hinge_yp": Vector3(-1.0, 0.0, 0.0),
}
## Gerilim: zıplama sayısı nadirlikle artar (sıradan 2 … efsanevi 5).
const SUSPENSE_HOPS: int = 2

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


## Gerilimin süresi (sn): CrateDelivery ışığı bu sürede büyütür.
static func suspense_time(rank: int) -> float:
	var total: float = 0.0
	for i: int in SUSPENSE_HOPS + rank:
		total += _hop_time(i)
	return total + 0.12


static func _hop_time(i: int) -> float:
	return maxf(0.30 - 0.04 * float(i), 0.16)


## AÇILIŞ: önce GERİLİM (giderek şiddetlenen sarsıntılı zıplamalar, `rank` = nadirlik sırası),
## sonra kapak dönerek havaya fırlar ve yana düşer, yan paneller yere çarpar (`burst_open` bu anda).
## Gerçek modelde tek bir "open" animasyonu varsa (model sözleşmesi) o oynar. Bitince döner.
func play_open(rank: int = 0) -> void:
	set_tag_visible(false)
	var player: AnimationPlayer = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _model and player and player.has_animation(OPEN_ANIMATION):
		await _suspense(rank)
		burst_open.emit()
		player.play(OPEN_ANIMATION)
		await player.animation_finished
		return
	var lid: Node3D = _lid
	var hinges: Array[Node3D] = _hinges
	var axes: Array[Vector3] = _hinge_axes
	if _model:
		lid = _model.find_child("Lid", true, false) as Node3D
		hinges = []
		axes = []
		for hinge_name: String in MODEL_HINGES:
			var hinge: Node3D = _model.find_child(hinge_name, true, false) as Node3D
			if hinge:
				hinges.append(hinge)
				axes.append(MODEL_HINGES[hinge_name])
	if lid != null and not hinges.is_empty():
		await _suspense(rank)
		await _blow_open(lid, hinges, axes, rank)
		return
	if _model:
		# Parçasız / animasyonsuz gerçek model: gerilim, sonra model büyüyüp gizlenir.
		await _suspense(rank)
		burst_open.emit()
		var shake: Tween = create_tween()
		shake.tween_property(_model, "scale", _model.scale * 1.06, 0.18)
		shake.tween_property(_model, "scale", _model.scale * 0.01, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		await shake.finished
		return
	await _suspense(rank)
	burst_open.emit()


## GERİLİM: kasa zıplar ve sallanır; her zıplama bir öncekinden yüksek ve hızlı (içeride bir şey
## kıpırdıyor). Kök düğüm hareket eder; bitince tam yerine döner.
func _suspense(rank: int) -> void:
	var rest_position: Vector3 = position
	var rest_rotation: Vector3 = rotation
	var hops: int = SUSPENSE_HOPS + rank
	for strap: Node3D in _straps:
		create_tween().tween_property(strap, "scale", Vector3(1.0, 0.01, 1.0), 0.18)
	for i: int in hops:
		var t: float = _hop_time(i)
		var power: float = 1.0 + 0.45 * float(i)
		var side: float = 1.0 if i % 2 == 0 else -1.0
		# chain(): paralel modda yeni grubun İLK adımı önceki grupla aynı anda başlamasın
		# (yoksa iniş çıkışı ezer; kapak havada asılı kalıyordu — QA karesi).
		var tween: Tween = create_tween().set_parallel(true)
		tween.tween_property(self, "position:y", rest_position.y + 0.022 * power, t * 0.45) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "rotation", rest_rotation + Vector3(0.025 * side * power, 0.0, 0.04 * side * power), t * 0.45)
		tween.tween_property(self, "scale", Vector3(0.97, 1.05, 0.97), t * 0.45)
		tween.chain().tween_property(self, "position:y", rest_position.y, t * 0.55) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "rotation", rest_rotation, t * 0.55)
		tween.tween_property(self, "scale", Vector3(1.04, 0.95, 1.04), t * 0.55)
		await tween.finished
	# Son bir sıkışma: patlamadan hemen önce kasa çöker gibi olur
	var squash: Tween = create_tween()
	squash.tween_property(self, "scale", Vector3(1.08, 0.88, 1.08), 0.09)
	await squash.finished
	position = rest_position
	rotation = rest_rotation


## PATLAMA: kasa geri esner, kapak dönerek havaya fırlar ve tepede parıltıyla kaybolur; yan
## paneller sekerek yere çarpar. `burst_open` kapak fırladığı anda yayınlanır.
func _blow_open(lid: Node3D, hinges: Array[Node3D], axes: Array[Vector3], rank: int) -> void:
	var stretch: Tween = create_tween()
	stretch.tween_property(self, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	burst_open.emit()
	# Kapak dönerek havaya fırlar ve tepede küçülüp kaybolur (yere DÜŞMEZ: kasa garajın arka
	# köşesinde durduğu için yana düşen kapak duvarın dışına, yola saplanıyordu — QA karesi).
	var start: Vector3 = lid.position
	var up: float = 0.42 + 0.06 * float(rank)
	var flight: Tween = create_tween().set_parallel(true)
	flight.tween_property(lid, "position:y", start.y + up, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flight.tween_property(lid, "position:x", start.x - _size.x * 0.25, 0.34)
	flight.tween_property(lid, "rotation", Vector3(TAU * 0.75, 0.6, 0.45), 0.55)
	flight.chain().tween_callback(func() -> void: lid_vanished.emit(lid.global_position))
	flight.tween_property(lid, "scale", lid.scale * 0.01, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	# Panellerin çarpması kapak havadayken başlar
	var panels: Tween = create_tween()
	panels.set_parallel(true)
	for i: int in hinges.size():
		panels.tween_property(hinges[i], "rotation", axes[i] * deg_to_rad(90.0), 0.5) \
			.set_delay(0.06 + 0.03 * float(i)).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await flight.finished
	if panels.is_running():
		await panels.finished


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
