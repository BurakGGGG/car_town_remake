class_name PetActor
extends Node3D
## GARAJ DOSTLARI — garajdaki kedinin GÖRÜNÜMÜ: model (assets/pets/tekir.glb), animasyon, göz kapakları (kapalı göz
## dokusuna geçiş + göz kırpma), dokunma alanı ve temas gölgesi. Nereye gideceğine PetWorld karar verir.
##
## Eksenler: düğümün −Z'si kedinin İLERİSİ (glb'de baş +Z'deydi; model 180° çevrilmiş bir pivotun altında).
## Ölçek gerçek boy: model metre, garajda 1 m = 1 / CarCatalog.REFERENCE_LENGTH_M birim (4,39 m'lik araç 1 birim).
## Klipler tools/pets/tekir_anim.py + tekir_clips.py'den gelir (30 kare/sn); burada yalnız adla çalınır.

## Kediye dokunuldu (görünmez, büyütülmüş alan: kedi garaj kamerasında çok küçük).
signal tapped
## Döngüsüz klip bitti.
signal clip_finished(clip: StringName)

const SCENE_PATH: String = "res://assets/pets/tekir.glb"
const EYES_CLOSED: Texture2D = preload("res://assets/pets/tekir_eyes_closed.jpg")
## Boy çarpanı. Garajın kendisi (araçlar, dekor) ŞEHİR ölçeğinde: 1 m = 0,6 / 4,39 birim (DecorBuilder.METER). Kedi
## önce 1 m = 1 / 4,39 ile (garaj içi araç bağlamı) kurulmuştu → arabalara göre ~1,7 kat iriydi. Kullanıcı kararı
## (2026-10-31, karşılaştırma ct_shots/pets/olcek): "arada" — kedi ×0,8 (gerçek orandan ~1,33 kat iri, garaj
## kamerasında görünür kalsın), kedi eşyaları ×1,25 (props_v10_kedi.py SCALE).
const SIZE: float = 0.8
const METER: float = SIZE / CarCatalog.REFERENCE_LENGTH_M
## Yürüme döngüsünde gövdenin aldığı yol (m) / döngü süresi (sn) — tekir_anim.WALK_STRIDE / WALK_FRAMES.
const WALK_SPEED_M: float = 0.26
## Döngülü klipler (glb'de döngü bilgisi yok, burada işaretlenir).
const LOOPS: Array[StringName] = [&"idle", &"walk", &"sit_idle", &"loaf", &"doze", &"sleep", &"eat", &"play_crouch",
	&"jump_air"]
## Gözlerin KAPALI çalındığı klipler (uyku, sevilme, kaşınma, yalanma).
const EYES_SHUT: Array[StringName] = [&"sleep", &"doze", &"doze_down", &"pet", &"scratch", &"groom"]
const BLEND: float = 0.22
## Dokunma alanı (model metresi): kedinin ~2 katı — garaj kamerasında kedi 20–30 piksel.
const HIT_SIZE: Vector3 = Vector3(0.625, 0.625, 1.0)   # ×0,8 küçülen kedide dünyadaki boyu aynı kalsın

var _player: AnimationPlayer
var _mesh: MeshInstance3D
var _mat: BaseMaterial3D
var _open_tex: Texture2D
var _clip: StringName = &""
var _eyes_shut_forced: bool = false
var _blink_left: float = 3.0
var _blinking: float = 0.0
var _shadow: MeshInstance3D
var _hit: StaticBody3D
var _skel: Skeleton3D
var _head_bone: int = -1
var _acc_nodes: Dictionary = {}       # aksesuar kimliği (StringName) → MeshInstance3D


func _ready() -> void:
	scale = Vector3.ONE * METER
	var pivot: Node3D = Node3D.new()
	pivot.name = "Pivot"
	pivot.rotation_degrees.y = 180.0
	add_child(pivot)
	var scene: PackedScene = load(SCENE_PATH) as PackedScene
	var model: Node3D = scene.instantiate() as Node3D
	pivot.add_child(model)
	_player = model.find_children("*", "AnimationPlayer", true, false).front() as AnimationPlayer
	for clip: StringName in LOOPS:
		if _player.has_animation(clip):
			_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_player.animation_finished.connect(_on_finished)
	_skel = model.find_children("*", "Skeleton3D", true, false).front() as Skeleton3D
	_head_bone = _skel.find_bone("head") if _skel else -1
	_mesh = model.find_children("*", "MeshInstance3D", true, false).front() as MeshInstance3D
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var src: Material = _mesh.get_active_material(0)
	if src is BaseMaterial3D:
		_mat = (src as BaseMaterial3D).duplicate() as BaseMaterial3D
		_open_tex = _mat.albedo_texture
		_mesh.material_override = _mat
	_build_shadow()
	_build_hitbox()
	play(&"idle")


func _process(delta: float) -> void:
	# Göz kırpma: açıkken 2,5–6 sn'de bir 0,13 sn kapanır
	if _eyes_shut_forced or EYES_SHUT.has(_clip):
		return
	if _blinking > 0.0:
		_blinking -= delta
		if _blinking <= 0.0:
			_apply_eyes(false)
		return
	_blink_left -= delta
	if _blink_left <= 0.0:
		_blink_left = randf_range(2.5, 6.0)
		_blinking = 0.13
		_apply_eyes(true)


# --- Animasyon ------------------------------------------------------------------------------

## Klibi çalar (aynı klip zaten çalıyorsa yeniden başlatmaz). speed: oynatma hızı (yürüyüşte ilerleme hızıyla eşleşir).
func play(clip: StringName, blend: float = BLEND, speed: float = 1.0) -> void:
	if _player == null or not _player.has_animation(clip):
		push_warning("PetActor: klip yok: %s" % clip)
		return
	if _clip == clip and _player.is_playing():
		_player.speed_scale = speed
		return
	_clip = clip
	_player.play(clip, blend)
	_player.speed_scale = speed
	_apply_eyes(_eyes_shut_forced or EYES_SHUT.has(clip))


## Yüzün ortası (dünya): baş kemiğinin kökünden burna doğru ~4 cm (yakın kamerada kalpler / olta bunu hedefler).
func head_point() -> Vector3:
	if _skel == null or _head_bone < 0:
		return global_position + Vector3(0.0, 0.3 * METER, 0.0)
	var t: Transform3D = _skel.global_transform * _skel.get_bone_global_pose(_head_bone)
	return t.origin + t.basis.y * 0.04


func current_clip() -> StringName:
	return _clip


func clip_length(clip: StringName) -> float:
	return _player.get_animation(clip).length if _player and _player.has_animation(clip) else 0.0


func has_clip(clip: StringName) -> bool:
	return _player != null and _player.has_animation(clip)


## Garajda yürürken ilerleme hızı (birim/sn) — klibin kendi adımıyla eşleşir (ayak kaymaz).
func walk_speed(speed_scale: float = 1.0) -> float:
	return WALK_SPEED_M * METER * speed_scale


func _on_finished(clip: StringName) -> void:
	clip_finished.emit(clip)


# --- Aksesuarlar --------------------------------------------------------------------------------

## Takılı aksesuarları verilen listeye eşitler. Her biri assets/pets/acc/<id>.glb: kedinin iskeletiyle aynı adlı
## kemiklere DERİLENMİŞ (tasma / bandana boyunla bükülür, kasket / kask başa sabit). Ağının kendi iskeleti atılır,
## ağ kedinin Skeleton3D'sine taşınır; deri bağları adla çözülür (içe aktarma: skins/use_named_skins).
func set_accessories(ids: Array[StringName]) -> void:
	if _skel == null:
		return
	for id: StringName in _acc_nodes.keys():
		if not ids.has(id):
			var old: Node = _acc_nodes[id]
			if is_instance_valid(old):
				old.queue_free()
			_acc_nodes.erase(id)
	for id: StringName in ids:
		if _acc_nodes.has(id):
			continue
		var mesh: MeshInstance3D = _load_accessory(id)
		if mesh:
			_acc_nodes[id] = mesh


func worn_accessories() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in _acc_nodes:
		out.append(id)
	return out


func _load_accessory(id: StringName) -> MeshInstance3D:
	var path: String = "res://assets/pets/acc/%s.glb" % id
	if not ResourceLoader.exists(path):
		push_warning("PetActor: aksesuar modeli yok: %s" % path)
		return null
	var root: Node = (load(path) as PackedScene).instantiate()
	var found: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if found.is_empty():
		root.free()
		return null
	var mesh: MeshInstance3D = found.front() as MeshInstance3D
	var local: Transform3D = mesh.transform    # kendi iskeletine göre (kedinin ağıyla aynı uzay)
	mesh.get_parent().remove_child(mesh)
	mesh.owner = null
	root.free()
	mesh.name = "Acc_%s" % id
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_skel.add_child(mesh)
	mesh.transform = local
	mesh.skeleton = NodePath("..")
	return mesh


# --- Gözler ----------------------------------------------------------------------------------

## Gözleri zorla kapalı tut (ör. yakın kamerada sevilirken klip dışı da).
func set_eyes_shut(on: bool) -> void:
	_eyes_shut_forced = on
	_apply_eyes(on or EYES_SHUT.has(_clip))


func _apply_eyes(shut: bool) -> void:
	if _mat:
		_mat.albedo_texture = EYES_CLOSED if shut else _open_tex


# --- Dokunma alanı ve gölge -----------------------------------------------------------------------

func _build_hitbox() -> void:
	_hit = StaticBody3D.new()
	_hit.name = "PetHit"
	_hit.input_ray_pickable = true
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = HIT_SIZE
	shape.shape = box
	shape.position = Vector3(0.0, HIT_SIZE.y * 0.5, 0.0)
	_hit.add_child(shape)
	_hit.input_event.connect(_on_hit_input)
	add_child(_hit)


func _on_hit_input(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape: int) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var editor: GarageEditor = get_tree().get_first_node_in_group("garage_editor") as GarageEditor
		if editor and editor.active:
			return   # garaj düzenlenirken kedi seçilmez
		get_viewport().set_input_as_handled()
		tapped.emit()


## Temas gölgesi: altında yumuşak, saydam elips (gölge pişirmesine girmeyen hareketli kedi zemine otursun).
func _build_shadow() -> void:
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.38))
	grad.set_color(1, Color(0, 0, 0, 0.0))
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.render_priority = -1
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.34, 0.66)
	quad.orientation = PlaneMesh.FACE_Y
	quad.material = mat
	_shadow = MeshInstance3D.new()
	_shadow.name = "ContactShadow"
	_shadow.mesh = quad
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow.position = Vector3(0.0, 0.004, 0.0)
	add_child(_shadow)


## GARAJI DÜZENLE açıkken kedi görünmez, dokunma kutusu kapalı (düzenleyicinin dokunuşlarını yutmasın).
func set_hidden(on: bool) -> void:
	visible = not on
	if _hit:
		_hit.input_ray_pickable = not on
		for c: Node in _hit.get_children():
			if c is CollisionShape3D:
				(c as CollisionShape3D).disabled = on


## Gölgenin boyu/şekli duruma göre (yatarken daha geniş/kısa, havadayken küçülür).
func set_shadow(scale_xz: Vector2, visible_on: bool = true) -> void:
	if _shadow:
		_shadow.visible = visible_on
		_shadow.scale = Vector3(scale_xz.x, 1.0, scale_xz.y)
