class_name RepairFx
extends Node3D
## TAMİR SAHNESİ — lifteki araçta arızaya göre canlı iş efektleri, bitişte parıltı, para toplanınca
## araçtan fışkıran altın paralar. Yalnızca GÖRSEL; süre / ödül RepairManager'dadır.
##
## Arızaya göre iş (her 0,45-1,1 sn'de bir "vuruş"):
##   fren / fren revizyonu → tekerde taşlama kıvılcımı + turuncu ışık çakması
##   lastik                → teker hızla döner (havalı tabanca) + kıvılcım
##   motor                 → kaputtan gri duman, arada kıvılcım
##   kaporta               → yan yüzeyde mavi-beyaz KAYNAK ışığı ve kıvılcımı
##   boya işi              → aracın kendi renginde sprey sisi, yan boyunca
##   döşeme                → kabinden kumaş tozu
## Dünyada durur (aracın ölçekli ağacına girmez) ve her kare aracın yerini izler: lift kalkarken
## efektler araçla birlikte yükselir. RepairFxDirector kurar / kaldırır.

var _car: Node3D
var _job: StringName = &""
var _bounds: AABB = AABB(Vector3(-0.15, 0.0, -0.3), Vector3(0.3, 0.25, 0.6))
var _working: bool = false
var _timer: float = 0.3
var _spin_left: float = 0.0
var _rig: CarRig
var _paint: Color = Color(0.92, 0.94, 0.98)
## Aracın burnu bu düğümün +z'sinde mi (1) yoksa −z'sinde mi (−1)? Trafik aracının kökünde burun −z,
## modelin kendisinde +z: tahmin edilmez, farların konumundan ölçülür.
var _front: float = -1.0

var _sparks: CPUParticles3D
var _smoke: CPUParticles3D
var _light: OmniLight3D
var _flicker: float = 0.0
var _flicker_color: Color = Color.WHITE


## `job`: arıza id'si (RepairType.id).
func setup(car: Node3D, job: StringName) -> void:
	name = "RepairFx"
	_car = car
	_job = job
	var model: Node3D = _model_of(car)
	_bounds = _local_bounds(car, model)
	_rig = _find_rig(car)
	if _rig and _rig.get_applied():
		_paint = _rig.get_applied().body_color
	_front = _front_sign(car, model, _rig)
	# Ölçüler garajın NORMAL kamera uzaklığına göre (araç ekranda ~110 px): ilk denemedeki yarı
	# boyutlu kıvılcım / duman bu uzaklıktan seçilmiyordu (QA karesi).
	_sparks = _emitter(28, 0.55, CrateRevealFx.soft_texture(), 0.045, true)
	_sparks.explosiveness = 0.35   # anlık nokta değil, kısa bir akıntı
	_sparks.spread = 50.0
	_sparks.gravity = Vector3(0.0, -2.8, 0.0)
	_sparks.initial_velocity_min = 0.8
	_sparks.initial_velocity_max = 1.7
	_sparks.scale_amount_min = 0.6
	_sparks.scale_amount_max = 1.2
	_smoke = _emitter(14, 1.3, DragRaceScreen.puff_texture(), 0.17, false)
	_smoke.explosiveness = 0.5
	_smoke.spread = 35.0
	_smoke.gravity = Vector3(0.0, 0.3, 0.0)
	_smoke.initial_velocity_min = 0.12
	_smoke.initial_velocity_max = 0.35
	_smoke.scale_amount_min = 0.7
	_smoke.scale_amount_max = 1.7
	_light = OmniLight3D.new()
	_light.omni_range = 0.75
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	add_child(_light)
	_working = true


func _process(delta: float) -> void:
	if not is_instance_valid(_car):
		queue_free()
		return
	global_transform = _car.global_transform.orthonormalized()
	if _flicker > 0.0:
		_flicker -= delta
		# Kaynak / taşlama ışığı: düzensiz çakar
		_light.light_energy = randf_range(0.9, 3.0) if _flicker > 0.0 else 0.0
	if _spin_left > 0.0 and _rig:
		_spin_left -= delta
		_rig.spin_wheels(delta * 1400.0)
	if not _working:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(0.3, 0.75)
		_hit()


## İş bitti: efektler durur, araçtan yıldız parıltısı + yerde halka; araç hazır.
func complete() -> void:
	_working = false
	_flicker = 0.0
	_light.light_energy = 0.0
	var stars: CPUParticles3D = _emitter(40, 1.0, CrateRevealFx.soft_texture(), 0.08, true)
	stars.position = _point(0.0, 0.6, 0.0)
	stars.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	stars.emission_box_extents = _bounds.size * 0.4
	stars.explosiveness = 0.9
	stars.direction = Vector3.UP
	stars.spread = 70.0
	stars.gravity = Vector3(0.0, -0.4, 0.0)
	stars.initial_velocity_min = 0.5
	stars.initial_velocity_max = 1.1
	stars.scale_amount_min = 0.6
	stars.scale_amount_max = 1.5
	stars.color_ramp = CrateRevealFx.fade_ramp(Color(1.0, 0.93, 0.62), 0.55)
	stars.restart()
	_ring(Color(1.0, 0.85, 0.45))
	_light.light_color = Color(1.0, 0.9, 0.6)
	var tween: Tween = create_tween()
	tween.tween_property(_light, "light_energy", 3.0, 0.08)
	tween.tween_property(_light, "light_energy", 0.0, 0.5)


## Para toplandı: araçtan dönen altın paralar fışkırır, yere düşüp söner; sonra düğüm kalkar.
## Araç hemen yola ışınlandığı için konum ÇAĞRI ANINDA sabitlenir (aracı artık izlemez).
func coins(amount: int) -> void:
	_working = false
	set_process(false)
	_light.light_energy = 0.0
	var origin: Vector3 = to_global(_point(0.0, 0.7, 0.0))
	var floor_y: float = to_global(_point(0.0, 0.0, 0.0)).y - 0.02
	var count: int = clampi(int(float(amount) / 40.0), 8, 16)
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.055
	mesh.bottom_radius = 0.055
	mesh.height = 0.012
	mesh.radial_segments = 12
	var gold: StandardMaterial3D = StandardMaterial3D.new()
	# Garaj ışığında metalik altın kahverengi görünüyordu (QA karesi): parlak, kendinden ışıklı.
	gold.albedo_color = Color("FFD24A")
	gold.metallic = 0.25
	gold.roughness = 0.35
	gold.emission_enabled = true
	gold.emission = Color("F5BE4C")
	gold.emission_energy_multiplier = 0.9
	var last: Tween = null
	for i: int in count:
		var coin: MeshInstance3D = MeshInstance3D.new()
		coin.mesh = mesh
		coin.material_override = gold
		coin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		get_parent().add_child(coin)
		coin.global_position = origin
		coin.rotation = Vector3(PI * 0.5, randf() * TAU, 0.0)
		var angle: float = randf() * TAU
		var reach: float = randf_range(0.25, 0.6)
		var land: Vector3 = origin + Vector3(cos(angle) * reach, 0.0, sin(angle) * reach)
		land.y = floor_y
		var peak: float = origin.y + randf_range(0.4, 0.7)
		var up_time: float = randf_range(0.28, 0.36)
		var delay: float = 0.025 * float(i)
		var tween: Tween = coin.create_tween()
		tween.set_parallel(true)
		tween.tween_property(coin, "global_position:x", land.x, up_time * 2.2).set_delay(delay)
		tween.tween_property(coin, "global_position:z", land.z, up_time * 2.2).set_delay(delay)
		tween.tween_property(coin, "global_position:y", peak, up_time).set_delay(delay) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(coin, "rotation:x", PI * 0.5 + TAU * 3.0, up_time * 2.2).set_delay(delay)
		tween.tween_property(coin, "global_position:y", land.y, up_time * 1.2).set_delay(delay + up_time) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tween.tween_property(coin, "scale", Vector3.ONE * 0.01, 0.25).set_delay(delay + up_time * 2.2 + 0.25)
		tween.chain().tween_callback(coin.queue_free)
		last = tween
	_ring(Color(1.0, 0.8, 0.35))
	if last:
		await last.finished
	queue_free()


## İş iptal / araç gitti: sessizce kalk.
func stop() -> void:
	queue_free()


# --- İş vuruşları ---------------------------------------------------------------------

func _hit() -> void:
	match _job:
		&"brakes", &"brake_overhaul":
			_spark_at(_wheel(), Color(1.0, 0.72, 0.28), true)
		&"tires":
			_spin_left = 0.45
			if randf() < 0.6:
				_spark_at(_wheel(), Color(1.0, 0.8, 0.4), false)
		&"engine":
			_puff(_point(randf_range(-0.3, 0.3), 0.85, 0.72 * _front), Color(0.86, 0.87, 0.88, 0.5))
			if randf() < 0.45:
				_spark_at(_point(randf_range(-0.4, 0.4), 0.7, 0.8 * _front), Color(1.0, 0.75, 0.3), false)
		&"body":
			var side: float = 1.0 if randf() < 0.5 else -1.0
			_spark_at(_point(side, randf_range(0.3, 0.6), randf_range(-0.6, 0.6)), Color(0.75, 0.88, 1.0), true)
		&"paint_job":
			var side_x: float = 1.05 if randf() < 0.5 else -1.05
			_puff(_point(side_x, randf_range(0.35, 0.7), randf_range(-0.7, 0.7)), Color(_paint, 0.5))
		&"upholstery":
			_puff(_point(randf_range(-0.3, 0.3), 1.0, randf_range(-0.2, 0.2)), Color(0.9, 0.86, 0.78, 0.45))
		_:
			_spark_at(_wheel(), Color(1.0, 0.8, 0.4), false)


func _spark_at(local: Vector3, color: Color, flash: bool) -> void:
	_sparks.position = local
	# Kıvılcım dışa doğru (aracın merkezinden uzağa) ve hafif yukarı fışkırır
	var outward: Vector3 = Vector3(local.x - _bounds.get_center().x, 0.0, local.z - _bounds.get_center().z)
	_sparks.direction = (outward.normalized() + Vector3(0.0, 0.8, 0.0)).normalized()
	_sparks.color_ramp = CrateRevealFx.fade_ramp(color.lightened(0.2), 0.3)
	_sparks.restart()
	if flash:
		_light.position = local
		_light.light_color = color
		_flicker = 0.28


func _puff(local: Vector3, color: Color) -> void:
	_smoke.position = local
	_smoke.direction = Vector3.UP
	_smoke.color_ramp = CrateRevealFx.fade_ramp(color, 0.25)
	_smoke.restart()


## Yerde genişleyen halka (bitiş / para).
func _ring(color: Color) -> void:
	var ring: MeshInstance3D = MeshInstance3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE
	quad.orientation = PlaneMesh.FACE_Y
	ring.mesh = quad
	var material: StandardMaterial3D = CrateRevealFx.additive(CrateRevealFx.ring_texture())
	material.albedo_color = Color(color, 0.9)
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	ring.top_level = true
	ring.global_position = to_global(_point(0.0, 0.0, 0.0)) + Vector3(0.0, 0.01, 0.0)
	ring.scale = Vector3.ONE * 0.3
	var size: float = maxf(_bounds.size.x, _bounds.size.z) * 2.2
	var tween: Tween = ring.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * size, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(ring.queue_free)


# --- Geometri -------------------------------------------------------------------------

## Aracın yerel kutusunda normalize nokta: x/z -1..1 (yan / boy, +z burun), y 0..1 (taban → tavan).
## Döndürülen nokta bu düğümün (aracın ölçeksiz dönüşü) uzayındadır.
func _point(nx: float, ny: float, nz: float) -> Vector3:
	var c: Vector3 = _bounds.get_center()
	var h: Vector3 = _bounds.size * 0.5
	return Vector3(c.x + nx * h.x, _bounds.position.y + ny * _bounds.size.y, c.z + nz * h.z)


## Rastgele bir teker hizası (köşeye yakın, alçak).
func _wheel() -> Vector3:
	var sx: float = 1.0 if randf() < 0.5 else -1.0
	var sz: float = 1.0 if randf() < 0.5 else -1.0
	return _point(sx * 0.95, 0.22, sz * 0.62)


## Burun yönü: far meshlerinin bu düğümün uzayındaki ortalama z'si; rig yoksa modelin +z'si
## (tüm araç modelleri +z'ye bakar — DragRaceScreen._spawn_car'da ölçülmüş).
func _front_sign(car: Node3D, model: Node3D, rig: CarRig) -> float:
	var frame: Transform3D = car.global_transform.orthonormalized().affine_inverse()
	if rig == null or not rig.has_role(&"headlights"):
		var nose: Vector3 = frame.basis * model.global_transform.basis.z
		return 1.0 if nose.z >= 0.0 else -1.0
	var sum: float = 0.0
	for mesh: MeshInstance3D in rig.get_meshes(&"headlights"):
		sum += (frame * mesh.global_transform * mesh.get_aabb().get_center()).z
	return 1.0 if sum > 0.0 else -1.0


## Aracın VAR OLAN rig'i (trafik aracında model bir alt düğümdedir). CarRig.for_node yoksa yeni rig
## kurup kayıt defterine eklediği için burada yalnızca meta'sı olan düğüm aranır; yoksa null.
static func _find_rig(car: Node3D) -> CarRig:
	var stack: Array[Node] = [car]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node.has_meta(CarRig.META_KEY):
			return node.get_meta(CarRig.META_KEY) as CarRig
		stack.append_array(node.get_children())
	return null


## Aracın görsel modeli: trafik aracının kökünde model bir alt düğümdür; yanında "TAMİR" balonu,
## seçim halkası ve tıklama kutusu da durur — onlar ölçüye girerse kutu balon hizasına kadar uzuyor,
## efektler aracın üstünde havada çıkıyordu (ölçüldü: yükseklik 0,56).
static func _model_of(car: Node3D) -> Node3D:
	for child: Node in car.get_children():
		if child is MeshInstance3D or child is CollisionObject3D or child is RepairFx:
			continue
		if child is Node3D and not child.find_children("*", "MeshInstance3D", true, false).is_empty():
			return child
	return car


## Model mesh'lerinin kutusu, aracın ÖLÇEKSİZ dönüş uzayında (dünya birimi).
static func _local_bounds(car: Node3D, model: Node3D) -> AABB:
	var frame: Transform3D = car.global_transform.orthonormalized().affine_inverse()
	var merged: AABB = AABB()
	var first: bool = true
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		if not mi.is_visible_in_tree():
			continue
		var box: AABB = frame * mi.global_transform * mi.get_aabb()
		merged = box if first else merged.merge(box)
		first = false
	return merged if not first else AABB(Vector3(-0.15, 0.0, -0.3), Vector3(0.3, 0.25, 0.6))


func _emitter(amount: int, lifetime: float, texture: Texture2D, size: float, additive: bool) -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(size, size)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.albedo_texture = texture
	if additive:
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	quad.material = material
	p.mesh = quad
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.emitting = false
	p.local_coords = false
	add_child(p)
	return p
