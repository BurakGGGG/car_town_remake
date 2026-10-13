class_name JunkyardTow
extends Node
## RESTORASYON BAŞLANGICI SAHNESİ — kapının önündeki oyuncu aracı sahaya girer, seçilen hurdaya halat
## bağlar ve onu çekerek kapıdan çıkar. Hurda garaja "ışınlanmasın": oyuncu işi kendi aracıyla
## götürdüğünü görsün. Yalnızca SUNUMDUR: proje JunkyardManager.start() ile sahne başlamadan
## kaydedilmiştir; sahne yarıda kesilirse (atla, ekran kapandı) hiçbir şey kaybolmaz.
##
## YOL (Blender metresi, X doğu / Y kuzey): kapı → meydanın GÜNEY şeridi (y 15,2) → hurdanın BATI
## boşluğundan kuzeye → hurdanın ARKASINDA (kuzey ucu) doğuya dönüp durur → halat → KUZEY şerit
## (y 24,5) → kapı → yol. Hurdalar burnu güneye, 8 m arayla durur (junkyard.py plaza); aradaki 5,8 m'lik
## boşluk araca yeter. Halat KUZEYDE bağlanır: güneyde (burun tarafı) bağlama anı kameradan bakınca
## su kulesinin / barakanın arkasında kalıyordu (QA ekran görüntüsü). Engeller (OBSTACLES)
## junkyard.py'deki yerlerinden; tests/junkyard_test.gd yolun hepsinden uzak durduğunu denetler.
##
## HURDA RÖMORK GİBİ İZLER: halatın bağlandığı uç aracın arka çekme noktasından halat boyundan fazla
## uzaklaşamaz; hurda o ucundan sürüklenen bir çubuk gibi döner (köşelerde içeri kesmesi doğal).
## Arkasından çekilen hurda geri geri gider (model açısı çekme yönünün tersi).
##
## Kullanım: new() → setup(...) → ağaca ekle → play(). Bitince (ya da skip()) `finished` yayılır ve düğüm
## kendini siler; hurda tutucusu da silinir, oyuncunun aracı kapıdaki yerine döner.

signal hitched
signal finished

const ENTRY_SPEED: float = 18.0    # m/s (oyun ölçeği: sahne kısa sürsün)
const EXIT_SPEED: float = 21.0
const HITCH_TIME: float = 1.0
const ROPE_THROW: float = 0.35     # halatın araçtan hurdaya uzanma süresi
const ROPE_HEIGHT: float = 0.45    # çekme noktalarının yerden yüksekliği
const ROPE_COLOR: Color = Color("2B2622")
const CAMERA_ZOOM: float = 15.0
const CAMERA_FOLLOW: float = 4.0   # takip yumuşaklığı (büyük = sıkı)
## Kamera araçla birlikte kapıdan çıkmaz: yola çıkınca burada kalır, araç ekrandan çıkıp gider.
const CAMERA_STOP_X: float = 66.0
const DUST_EVERY: float = 0.22     # çekilirken hurdanın arkasında toz (sn)
const WRECK_LENGTH: float = 4.2    # hurda varyantlarının boyu (junk_wrecks, gerçek metre)

## Yolu kesen her şey (Blender X, Y, yarıçap m): iş lambası direkleri, ateş varilleri, lastik yığınları,
## Cemo, motor bloğu (junkyard.py plaza / scatter_v3 / layout_v3).
const OBSTACLES: Array[Vector3] = [
	Vector3(22.5, 12.5, 0.2), Vector3(45.5, 12.5, 0.2), Vector3(22.5, 27.5, 0.2), Vector3(45.5, 27.5, 0.2),
	Vector3(20.5, 26.5, 0.5), Vector3(47.5, 13.5, 0.5), Vector3(47.5, 22.0, 0.5), Vector3(19.5, 13.0, 0.5),
	Vector3(35.6, 27.4, 0.4), Vector3(44.5, 9.0, 0.8),
]
const NORTH_LANE: float = 24.5
const SOUTH_LANE: float = 15.2
const GATE: Vector2 = Vector2(64.0, 21.0)

var _world: JunkyardWorld
var _car: Node3D           # tutucu (konum)
var _car_model: Node3D     # Y açısı
var _car_half: float = 2.1
var _wreck: Node3D         # tutucu (konum) — içinde hurda modeli + gölge lekesi
var _wreck_model: Node3D
var _entry: Array = []     # [noktalar (Godot), birikimli uzunluklar]
var _exit: Array = []
var _entry_time: float = 3.0
var _exit_time: float = 4.0
var _phase: StringName = &"idle"
var _time: float = 0.0
var _rope: MeshInstance3D
var _rope_length: float = 3.0
var _pull_dir: Vector3 = Vector3.BACK   # hurda merkezinden halatın bağlandığı uca (yatay birim)
var _pull_sign: float = 1.0             # +1: burnundan çekilir, -1: arkasından (model önü çekmenin tersi)
var _speed: float = 1.0
var _dust_clock: float = 0.0
var _camera_before: Dictionary = {}
var _focus: Vector3 = Vector3.ZERO


## world: hurdalık dünyası; wreck: JunkyardWorld.take_daily tutucusu; spot: hurdanın yeri (Blender X, Y).
## speed: oynatma hızı (ilk restorasyon 1; sonrakiler daha kısa).
func setup(world: JunkyardWorld, wreck: Node3D, spot: Vector2, speed: float = 1.0) -> void:
	_world = world
	_speed = maxf(speed, 0.1)
	if wreck == null:
		return
	_car = world.player_car()
	_car_model = world.player_car_model()
	_car_half = world.player_car_length() * 0.5
	_wreck = wreck
	for child: Node in wreck.get_children():
		if child is Node3D and not (child is MeshInstance3D and (child as MeshInstance3D).mesh is QuadMesh):
			_wreck_model = child
			break
	_entry = _polyline(entry_route(_car_spot(), spot))
	_exit = _polyline(exit_route(spot))
	_entry_time = clampf(_length(_entry) / ENTRY_SPEED, 2.4, 4.2)
	_exit_time = clampf(_length(_exit) / EXIT_SPEED, 3.2, 5.0)


func play() -> void:
	if _car == null or _car_model == null or _wreck == null or _wreck_model == null:
		_finish()
		return
	_camera_before = _world.camera.view_state()
	_focus = _car.global_position
	_pull_dir = _flat(_wreck_model.global_basis.z)
	_phase = &"enter"
	_time = 0.0


## Dokununca: sahne hemen biter (sonuç zaten kaydedilmiş).
func skip() -> void:
	if _phase != &"idle" and _phase != &"done":
		_finish()


func is_playing() -> bool:
	return _phase != &"idle" and _phase != &"done"


func _process(delta: float) -> void:
	if not is_playing():
		return
	_time += delta * _speed
	delta *= _speed
	match _phase:
		&"enter":
			var u: float = clampf(_time / _entry_time, 0.0, 1.0)
			_place_car(_entry, _length(_entry) * _ease_in_out(u))
			_follow(_car.global_position, delta)
			if u >= 1.0:
				_start_hitch()
		&"hitch":
			_update_rope(clampf(_time / ROPE_THROW, 0.0, 1.0))
			_follow((_car.global_position + _wreck.global_position) * 0.5, delta)
			if _time >= HITCH_TIME:
				_phase = &"exit"
				_time = 0.0
		&"exit":
			var u: float = clampf(_time / _exit_time, 0.0, 1.0)
			_place_car(_exit, _length(_exit) * pow(u, 1.6))   # yavaş kalkış, hızlanarak uzaklaşır
			_drag_wreck()
			_update_rope(1.0)
			_dust_clock -= delta
			if _dust_clock <= 0.0:
				_dust_clock = DUST_EVERY
				_world.dust(_wreck.global_position - _pull_dir * WRECK_LENGTH * 0.3, 0.8, 6)
			var mid: Vector3 = (_car.global_position + _wreck.global_position) * 0.5
			if mid.x < CAMERA_STOP_X:
				_follow(mid, delta)
			if u >= 1.0:
				_finish()


func _start_hitch() -> void:
	_phase = &"hitch"
	_time = 0.0
	_rope = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.07, 0.07, 1.0)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = ROPE_COLOR
	mesh.material = material
	_rope.mesh = mesh
	_rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(_rope)
	# Halat hurdanın araca yakın ucuna bağlanır
	var front: Vector3 = _flat(_wreck_model.global_basis.z)
	var hitch: Vector3 = _hitch_point()
	var to_front: float = hitch.distance_to(_wreck.global_position + front * WRECK_LENGTH * 0.5)
	var to_back: float = hitch.distance_to(_wreck.global_position - front * WRECK_LENGTH * 0.5)
	_pull_sign = 1.0 if to_front <= to_back else -1.0
	_pull_dir = front * _pull_sign
	_rope_length = maxf(_hitch_point().distance_to(_wreck_nose()), 2.0)
	_update_rope(0.0)
	_world.dust(_wreck.global_position, 1.2, 10)
	# Hurda halatı yiyince hafifçe silkinir
	var tween: Tween = create_tween()
	tween.tween_interval(ROPE_THROW)
	tween.tween_property(_wreck_model, "position:y", 0.12, 0.08)
	tween.tween_property(_wreck_model, "position:y", 0.0, 0.14).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	hitched.emit()


## Araç yol üzerinde `distance` metrede; önü yolun teğeti.
func _place_car(route: Array, distance: float) -> void:
	var pose: Array = _sample(route, distance)
	_car.global_position = pose[0]
	var dir: Vector3 = pose[1]
	_car_model.rotation.y = atan2(dir.x, dir.z)


## Römork: hurdanın bağlı ucu çekme noktasına halat boyundan uzaksa o uç oraya çekilir, gövde ucun
## arkasında kalır (ucundan sürüklenen çubuk).
func _drag_wreck() -> void:
	var hitch: Vector3 = _hitch_point()
	var nose: Vector3 = _wreck_nose()
	var flat_hitch: Vector3 = Vector3(hitch.x, 0.0, hitch.z)
	var flat_nose: Vector3 = Vector3(nose.x, 0.0, nose.z)
	if flat_nose.distance_to(flat_hitch) <= _rope_length:
		return
	var new_nose: Vector3 = flat_hitch + (flat_nose - flat_hitch).normalized() * _rope_length
	var center: Vector3 = Vector3(_wreck.global_position.x, 0.0, _wreck.global_position.z)
	_pull_dir = _flat(new_nose - center)
	_wreck.global_position = new_nose - _pull_dir * WRECK_LENGTH * 0.5
	var front: Vector3 = _pull_dir * _pull_sign
	_wreck_model.rotation.y = atan2(front.x, front.z)


func _hitch_point() -> Vector3:
	var back: Vector3 = _flat(_car_model.global_basis.z)
	return _car.global_position - back * (_car_half + 0.05) + Vector3.UP * ROPE_HEIGHT


## Hurdanın halat bağlanan ucu.
func _wreck_nose() -> Vector3:
	return _wreck.global_position + _pull_dir * WRECK_LENGTH * 0.5 + Vector3.UP * ROPE_HEIGHT


## Halat: araçtan hurdaya `reach` (0..1) kadar uzanan ince kutu.
func _update_rope(reach: float) -> void:
	if _rope == null:
		return
	var from: Vector3 = _hitch_point()
	var to: Vector3 = from.lerp(_wreck_nose(), reach)
	var length: float = from.distance_to(to)
	_rope.visible = length > 0.05
	if not _rope.visible:
		return
	_rope.global_transform = Transform3D(Basis.looking_at(to - from, Vector3.UP).scaled(Vector3(1.0, 1.0, length)),
		(from + to) * 0.5)


func _follow(target: Vector3, delta: float) -> void:
	_focus = _focus.lerp(target, 1.0 - exp(-CAMERA_FOLLOW * delta))
	_world.camera.follow(_focus, CAMERA_ZOOM)


func _finish() -> void:
	if _phase == &"done":
		return
	_phase = &"done"
	if _rope:
		_rope.queue_free()
	if is_instance_valid(_wreck):
		_wreck.queue_free()
	if is_instance_valid(_world):
		_world.park_player_car()
		if not _camera_before.is_empty():
			_world.camera.restore_view(_camera_before)
	finished.emit()
	queue_free()


# --- Yol ------------------------------------------------------------------------------

func _car_spot() -> Vector2:
	return Vector2(_car.global_position.x, -_car.global_position.z) if _car else JunkyardWorld.PLAYER_CAR_SPOT


## Kapıdan hurdanın arkasına (kontrol noktaları, Blender X, Y). Araç kapıya çapraz (güneybatıya) durur:
## doğrudan güney şeride iner, hurdanın batı boşluğundan kuzeye çıkıp kuzey şeritte doğuya döner.
static func entry_route(start: Vector2, spot: Vector2) -> PackedVector2Array:
	var x: float = spot.x
	var y: float = spot.y
	var points: PackedVector2Array = PackedVector2Array([start, Vector2(67.6, 20.1), Vector2(63.5, 20.4),
		Vector2(57.0, 19.0), Vector2(50.5, 16.6), Vector2(44.5, SOUTH_LANE + 0.1)])
	if x - 1.0 < 43.0:
		points.append(Vector2(x - 1.0, SOUTH_LANE))
	points.append_array(PackedVector2Array([Vector2(x - 3.2, SOUTH_LANE + 0.7), Vector2(x - 4.0, y - 1.6),
		Vector2(x - 4.0, y + 1.6), Vector2(x - 3.0, NORTH_LANE - 0.5), Vector2(x - 0.8, NORTH_LANE),
		hitch_spot(spot)]))
	return points


## Hurdanın arkasında durulacak yer: önü doğuya, arka tamponu hurdanın kuzey ucunun çaprazında.
static func hitch_spot(spot: Vector2) -> Vector2:
	return Vector2(spot.x + 2.4, NORTH_LANE)


## Hurdayı çekerek kuzey şeritten kapıya, oradan yoldan ekran dışına.
static func exit_route(spot: Vector2) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array([hitch_spot(spot), Vector2(spot.x + 7.0, NORTH_LANE)])
	if spot.x + 7.0 < 49.0:
		points.append(Vector2(50.0, NORTH_LANE))
	points.append_array(PackedVector2Array([Vector2(56.5, 23.8), Vector2(61.0, 22.0), Vector2(64.0, GATE.y),
		Vector2(70.0, 21.3), Vector2(84.0, 21.5), Vector2(108.0, 21.5)]))
	return points


## Catmull-Rom ile yumuşatılmış yol, Godot noktaları (y = 0) + birikimli uzunluklar.
static func _polyline(control: PackedVector2Array) -> Array:
	var points: PackedVector3Array = PackedVector3Array()
	var steps: int = 10
	for i: int in control.size() - 1:
		var p0: Vector2 = control[maxi(i - 1, 0)]
		var p1: Vector2 = control[i]
		var p2: Vector2 = control[i + 1]
		var p3: Vector2 = control[mini(i + 2, control.size() - 1)]
		for k: int in steps:
			var p: Vector2 = _catmull(p0, p1, p2, p3, float(k) / steps)
			points.append(JunkyardWorld.blender(p.x, p.y, 0.0))
	var last: Vector2 = control[control.size() - 1]
	points.append(JunkyardWorld.blender(last.x, last.y, 0.0))
	var lengths: PackedFloat32Array = PackedFloat32Array([0.0])
	for i: int in range(1, points.size()):
		lengths.append(lengths[i - 1] + points[i - 1].distance_to(points[i]))
	return [points, lengths]


static func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2: float = t * t
	var t3: float = t2 * t
	return 0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3)


static func _length(route: Array) -> float:
	var lengths: PackedFloat32Array = route[1]
	return lengths[lengths.size() - 1] if not lengths.is_empty() else 0.0


## [konum, yön] — yol üzerinde `distance` metre.
static func _sample(route: Array, distance: float) -> Array:
	var points: PackedVector3Array = route[0]
	var lengths: PackedFloat32Array = route[1]
	for i: int in range(1, points.size()):
		if lengths[i] >= distance or i == points.size() - 1:
			var seg: float = maxf(lengths[i] - lengths[i - 1], 0.0001)
			var t: float = clampf((distance - lengths[i - 1]) / seg, 0.0, 1.0)
			return [points[i - 1].lerp(points[i], t), (points[i] - points[i - 1]).normalized()]
	return [points[0], Vector3.BACK]


## Yoldaki noktalar (Blender X, Y) — test: engellere uzaklık.
static func sample_points(control: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var points: PackedVector3Array = _polyline(control)[0]
	for p: Vector3 in points:
		out.append(Vector2(p.x, -p.z))
	return out


static func _ease_in_out(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)


static func _flat(v: Vector3) -> Vector3:
	var f: Vector3 = Vector3(v.x, 0.0, v.z)
	return f.normalized() if f.length() > 0.0001 else Vector3.BACK
