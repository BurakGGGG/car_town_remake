class_name SkidMarks
extends MeshInstance3D
## DRIFT LASTİK İZLERİ (2026-11-02, DriftEvent): kayan arka lastiklerin yola bıraktığı siyah kauçuk şeritleri. YAVAŞÇA
## SİLİNİR (kullanıcı: "lastik izleri yavaşça silinsin"): her nokta çizildiği anı taşır (UV2.x), önce çizilen önce solar —
## FADE_FROM sn sonra solmaya başlar, FADE_TO sn'de kaybolur (yumuşak eğri); son nokta da kaybolunca düğüm kendini siler.
## Solarken mesh değişmez, yalnızca shader'ın `now` değeri ilerler.
## MALİYET: iki mesh (iki çizim): KAPANMIŞ şeritler (şerit her savruluşta kapanır, ~50–150 nokta) çocuk düğümde, yalnız bir
## şerit kapanınca kurulur; BÜYÜYEN (açık, en çok dört) şeritler bu düğümde iki karede bir kurulur ve bunların da yalnız son
## birkaç parçası yeniden hesaplanır (_build_strip artımlı).
## Yükseklik: yol çizgilerinin (0,0016) üstünde, araç gölgesinin (0,004) altında.

const SHADER: Shader = preload("res://vfx/skid_marks.gdshader")
const WIDTH: float = 0.042
const LIFT: float = 0.0028
## Yeni nokta en az bu kadar ilerleyince eklenir; şerit başına en çok MAX_POINTS (sonrası yeni şerit).
const MIN_STEP: float = 0.03
const MAX_POINTS: int = 900
## Bir noktanın çizildikten sonra solmaya başladığı ve tamamen kaybolduğu an (sn).
const FADE_FROM: float = 6.0
const FADE_TO: float = 70.0

## Şeritler: {"points": PackedVector3Array, "alpha": PackedFloat32Array}
var _strips: Array[Dictionary] = []
var _open: Dictionary = {}     # teker anahtarı → açık şeridin sırası
var _dirty: bool = false
var _closed_dirty: bool = false
var _closed: MeshInstance3D
var _frame: int = 0
var _material: ShaderMaterial
var _released: bool = false
var _time: float = 0.0
var _last_birth: float = 0.0


func _init() -> void:
	name = "SkidMarks"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("fade_from", FADE_FROM)
	_material.set_shader_parameter("fade_to", FADE_TO)
	material_override = _material
	mesh = ArrayMesh.new()
	custom_aabb = AABB(Vector3(-14.0, -0.1, -14.0), Vector3(28.0, 0.3, 28.0))
	_closed = MeshInstance3D.new()
	_closed.name = "Closed"
	_closed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_closed.material_override = _material
	_closed.mesh = ArrayMesh.new()
	_closed.custom_aabb = custom_aabb
	add_child(_closed)


## Tekerin yerdeki noktası (`key` tekeri ayırır) ve kayma şiddeti (0–1). Şiddet düşükse şerit kapanır (iz kesilir).
func add(key: int, at: Vector3, strength: float) -> void:
	if strength < 0.06:
		_close(key)
		return
	var index: int = int(_open.get(key, -1))
	if index >= 0 and (_strips[index]["points"] as PackedVector3Array).size() >= MAX_POINTS:
		_close(key)
		index = -1
	var point: Vector3 = Vector3(at.x, LIFT, at.z)
	if index < 0:
		_strips.append({"points": PackedVector3Array([point]), "alpha": PackedFloat32Array([0.0]),
			"birth": PackedFloat32Array([_time])})
		_open[key] = _strips.size() - 1
		return
	var strip: Dictionary = _strips[index]
	var points: PackedVector3Array = strip["points"]
	if points[points.size() - 1].distance_to(point) < MIN_STEP:
		return
	# Paketli diziler değerle taşınır: büyütülen kopya sözlüğe geri yazılmalı
	points.append(point)
	strip["points"] = points
	var alpha: PackedFloat32Array = strip["alpha"]
	alpha.append(clampf(strength, 0.0, 1.0))
	strip["alpha"] = alpha
	var birth: PackedFloat32Array = strip["birth"]
	birth.append(_time)
	strip["birth"] = birth
	_last_birth = _time
	_dirty = true


## Tekerin açık şeridi kapanır (durağan mesh'e geçer).
func _close(key: int) -> void:
	if _open.has(key):
		_open.erase(key)
		_closed_dirty = true
		_dirty = true


## Gösteri bitti: bütün şeritler kapanır; son nokta da solunca düğüm kendini siler.
func release() -> void:
	for key: Variant in _open.keys():
		_close(int(key))
	_released = true


func point_count() -> int:
	var n: int = 0
	for strip: Dictionary in _strips:
		n += (strip["points"] as PackedVector3Array).size()
	return n


func _process(delta: float) -> void:
	_frame += 1
	_time += delta
	if _closed_dirty:
		_closed_dirty = false
		_fill(_closed.mesh as ArrayMesh, false)
	if _dirty and (_frame % 2 == 0 or _released):
		_dirty = false
		_fill(mesh as ArrayMesh, true)
	_material.set_shader_parameter("now", _time)
	if _released and _time > _last_birth + FADE_TO:
		queue_free()


## Açık (`open` = true) ya da kapanmış şeritleri tek yüzeyde toplar (dizinsiz üçgen listesi: birleştirme yalnızca
## paketli dizi eklemesi). Şeridin üçgenleri yalnız nokta sayısı değişince yeniden hesaplanır.
func _fill(target: ArrayMesh, open: bool) -> void:
	var open_index: Dictionary = {}
	for index: Variant in _open.values():
		open_index[int(index)] = true
	var vertices: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var uvs: PackedVector2Array = PackedVector2Array()
	var births: PackedVector2Array = PackedVector2Array()
	for k: int in _strips.size():
		if open_index.has(k) != open:
			continue
		var strip: Dictionary = _strips[k]
		if (strip["points"] as PackedVector3Array).size() < 2:
			continue
		if int(strip.get("built", 0)) != (strip["points"] as PackedVector3Array).size():
			_build_strip(strip)
		vertices.append_array(strip["v"])
		colors.append_array(strip["c"])
		uvs.append_array(strip["uv"])
		births.append_array(strip["uv2"])
	target.clear_surfaces()
	if vertices.is_empty():
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = births
	target.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


## Bir şeridin üçgenleri (her parça iki üçgen: sol / sağ kenar), rengi ve UV'si; şeridin içine yazılır. ARTIMLI: önceki
## kurulumdan bu yana eklenen noktalarla birlikte yalnız son TAIL parça yeniden hesaplanır (uçtaki incelme ve son noktanın
## yönü yeni noktayla değişir); öncesi önbellekte kalır.
const TAIL: int = 5


static func _build_strip(strip: Dictionary) -> void:
	var points: PackedVector3Array = strip["points"]
	var alpha: PackedFloat32Array = strip["alpha"]
	var birth: PackedFloat32Array = strip["birth"]
	var n: int = points.size()
	var built: int = int(strip.get("built", 0))
	var from: int = maxi(built - 1 - TAIL, 0)   # bu parçadan (from → from+1) itibaren yeniden
	var vertices: PackedVector3Array = strip.get("v", PackedVector3Array())
	var colors: PackedColorArray = strip.get("c", PackedColorArray())
	var uvs: PackedVector2Array = strip.get("uv", PackedVector2Array())
	var births: PackedVector2Array = strip.get("uv2", PackedVector2Array())
	vertices.resize(from * 6)
	colors.resize(from * 6)
	uvs.resize(from * 6)
	births.resize(from * 6)
	var along: PackedFloat32Array = strip.get("along", PackedFloat32Array([0.0]))
	along.resize(maxi(from + 1, 1))
	for i: int in range(along.size(), n):
		along.append(along[i - 1] + points[i].distance_to(points[i - 1]))
	var prev_left: Vector3 = Vector3.ZERO
	var prev_right: Vector3 = Vector3.ZERO
	var prev_shade: Color = Color.WHITE
	for i: int in range(from, n):
		var a: Vector3 = points[maxi(i - 1, 0)]
		var b: Vector3 = points[mini(i + 1, n - 1)]
		var dir: Vector3 = Vector3(b.x - a.x, 0.0, b.z - a.z)
		dir = dir.normalized() if dir.length_squared() > 0.000001 else Vector3.FORWARD
		var side: Vector3 = Vector3(-dir.z, 0.0, dir.x) * WIDTH * 0.5
		# Uçlar incelir: şerit birden başlayıp bitmesin
		var ends: float = minf(smoothstep(0.0, 4.0, float(i)), smoothstep(0.0, 4.0, float(n - 1 - i)))
		var left: Vector3 = points[i] - side
		var right: Vector3 = points[i] + side
		var shade: Color = Color(1.0, 1.0, 1.0, alpha[i] * ends)
		if i > from:
			var j: int = i - 1
			vertices.append_array(PackedVector3Array([prev_left, prev_right, left, prev_right, right, left]))
			colors.append_array(PackedColorArray([prev_shade, prev_shade, shade, prev_shade, shade, shade]))
			uvs.append_array(PackedVector2Array([Vector2(0.0, along[j]), Vector2(1.0, along[j]), Vector2(0.0, along[i]),
				Vector2(1.0, along[j]), Vector2(1.0, along[i]), Vector2(0.0, along[i])]))
			var bj: Vector2 = Vector2(birth[j], 0.0)
			var bi: Vector2 = Vector2(birth[i], 0.0)
			births.append_array(PackedVector2Array([bj, bj, bi, bj, bi, bi]))
		prev_left = left
		prev_right = right
		prev_shade = shade
	strip["v"] = vertices
	strip["c"] = colors
	strip["uv"] = uvs
	strip["uv2"] = births
	strip["along"] = along
	strip["built"] = n
