class_name DriftSmoke
extends MultiMeshInstance3D
## DRIFT DUMANI (2026-11-02, DriftEvent): kayan arka lastiklerden çıkan kalın, yavaş açılan beyaz duman. Bütün topaklar
## TEK MultiMesh'tir (tek çizim çağrısı). Üretim hızı kaymanın şiddetiyle orantılı (CPUParticles3D'nin yoğunluğu
## çalışırken ayarlanamıyordu).
##
## Topak: lastiğin yerinde küçük ve yoğun doğar, aracın hızının bir kısmını ve tekerin geriye fırlattığı hızı alır,
## yavaşlar, büyür, hafifçe yükselir, rüzgârla kayar, söner. Büyüdükçe merkezi yükselir: kameraya dönük dörtgen yola
## gömülüp düz bir çizgiyle kesilmesin. Yoğunluk kaliteye göre (GameSettings: düşük %50, orta %80; topaklar biraz iri).
##
## MALİYET: hareket tamamen shader'da (vfx/drift_smoke.gdshader) doğuş verisinden hesaplanır; işlemci topağı yalnız
## doğarken halka tampondaki yerine bir kez yazar, her karede tek bir shader değeri (`now`) ilerletir. Son topak da
## sönünce düğüm uyur (_process kapalı).

const SHADER: Shader = preload("res://vfx/drift_smoke.gdshader")
const CAPACITY: int = 260
## Teker başına saniyede topak (tam kaymada) ve ömür (sn).
const RATE: float = 18.0
const LIFE: Vector2 = Vector2(2.4, 3.6)
## Boy (birim): sonunda (aralık); doğarkenki boy shader'da (size_start).
const SIZE_END: Vector2 = Vector2(0.85, 1.3)
## Hareket: aracın hızından alınan pay, tekerin geriye / yana fırlatması, rastgele saçılma (sönüm / kaldırma / rüzgâr
## shader'da).
const INHERIT: float = 0.32
const KICK: float = 0.5
const SPREAD: float = 0.16
## Ton (beyaza yakın, topaktan topağa biraz gri).
const TONE: Vector2 = Vector2(0.9, 0.99)

var density: float = 1.0
var _material: ShaderMaterial
var _next: int = 0
var _time: float = 0.0
var _death: PackedFloat32Array = PackedFloat32Array()   # topağın söneceği an
var _last_death: float = -1.0
var _carry: Dictionary = {}   # yayıcı anahtarı → biriken kesirli topak
var _size_boost: float = 1.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	name = "DriftSmoke"
	top_level = true   # örnek dönüşümleri dünya verisi: düğüm dönüşümü karışmasın
	_rng.randomize()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	quad.material = _material
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = CAPACITY
	multimesh = mm
	# Topaklar haritanın her yerinde olabilir (sınır kutusu örneklerden hesaplanmıyor: kırpılmasın)
	custom_aabb = AABB(Vector3(-14.0, -1.0, -14.0), Vector3(28.0, 6.0, 28.0))
	_death.resize(CAPACITY)
	_death.fill(-1.0)
	var empty: Transform3D = Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)
	for i: int in CAPACITY:
		mm.set_instance_transform(i, empty)   # ömür 0: görünmez
		mm.set_instance_color(i, Color.WHITE)
		mm.set_instance_custom_data(i, Color(0.0, 0.0, 0.0, 0.0))
	match GameSettings.active_quality():
		GameSettings.Quality.LOW:
			density = 0.5
			_size_boost = 1.15
		GameSettings.Quality.MEDIUM:
			density = 0.8
			_size_boost = 1.07
	set_process(false)


## Bir yayıcıdan (teker) bu karede topak üretir. `key`: yayıcıyı ayırır (kesirli birikim), `at`: lastiğin yerdeki
## noktası, `car_velocity`: aracın hızı (birim/sn), `back`: tekerin topağı fırlattığı yön (gövdenin arkası + yanı),
## `strength`: 0–1 kayma şiddeti.
func emit(key: int, at: Vector3, car_velocity: Vector3, back: Vector3, strength: float, delta: float) -> void:
	if strength <= 0.02:
		_carry.erase(key)
		return
	var count: float = float(_carry.get(key, _rng.randf())) + RATE * density * strength * delta
	while count >= 1.0:
		count -= 1.0
		_spawn(at, car_velocity, back, strength)
	_carry[key] = count


func _spawn(at: Vector3, car_velocity: Vector3, back: Vector3, strength: float) -> void:
	var i: int = _next
	_next = (_next + 1) % CAPACITY
	var jitter: Vector3 = Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0)) * 0.05
	var origin: Vector3 = Vector3(at.x, 0.06, at.z) + jitter
	var velocity: Vector3 = car_velocity * INHERIT + back * KICK * _rng.randf_range(0.6, 1.2) \
		+ Vector3(_rng.randf_range(-SPREAD, SPREAD), _rng.randf_range(0.04, 0.16), _rng.randf_range(-SPREAD, SPREAD))
	var life: float = _rng.randf_range(LIFE.x, LIFE.y) * lerpf(0.75, 1.0, strength)
	var size: float = _rng.randf_range(SIZE_END.x, SIZE_END.y) * lerpf(0.8, 1.0, strength) * _size_boost
	var shape: Vector3 = Vector3(size, life, _rng.randf() * TAU)
	var extra: Vector3 = Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf(), 0.0)
	multimesh.set_instance_transform(i, Transform3D(Basis(velocity, shape, extra), origin))
	var tone: float = _rng.randf_range(TONE.x, TONE.y)
	multimesh.set_instance_color(i, Color(tone, tone, tone * 0.995, 1.0))
	multimesh.set_instance_custom_data(i, Color(_time, 0.0, 0.0, 0.0))
	_death[i] = _time + life
	_last_death = maxf(_last_death, _time + life)
	if not is_processing():
		_material.set_shader_parameter("now", _time)
		set_process(true)


## Canlı topak var mı (yoksa düğüm uyur).
func is_active() -> bool:
	return _time <= _last_death


## Şu an canlı topak sayısı (QA / test).
func alive_count() -> int:
	var n: int = 0
	for i: int in CAPACITY:
		if _death[i] > _time:
			n += 1
	return n


func clear() -> void:
	_death.fill(-1.0)
	_last_death = -1.0
	_carry.clear()
	var empty: Transform3D = Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)
	for i: int in CAPACITY:
		multimesh.set_instance_transform(i, empty)
	set_process(false)


func _process(delta: float) -> void:
	_time += delta
	_material.set_shader_parameter("now", _time)
	if _time > _last_death:
		set_process(false)   # son topak da söndü: uyu (sonraki emit uyandırır)
