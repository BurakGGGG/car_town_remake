class_name TrafficLights
extends Node3D
## TRAFİK LAMBALARI — showroom önündeki kavşak (WorldDressing kurar, sahne düzenlenmez).
##
## Her kola gelen trafiğe bakan bir lamba kafası: batı / doğu / güney kollarında şeridin SAĞ köşesindeki direkte;
## kuzeyden gelen şeridin kafası KARŞI köşede (güneydoğu direğinde sırt sırta ikinci kafa) — kuzeybatı köşesi garajın
## köşesi, oraya dikilen direk kameradan garajın (liftin) üstüne biniyordu, yüzü de hiç görünmüyordu. Eksen başına
## (0 = doğu-batı, 1 = kuzey-güney) tek ışık: YEŞİL → SARI → TÜM KIRMIZI → karşı eksen YEŞİL … Araçlar
## kavşağa yalnızca kendi eksenleri yeşilken girer (TrafficManager.request_crossing → allows). İzni yeşilde
## almış araç sarıda da geçer; sarıda ve kırmızıda yeni izin verilmez, araç giriş çizgisinde bekler.
## Kovalamaca araçları ışığa uymaz (kendi yolunu PoliceChase verir).
## Yaya geçitleri ve dur çizgileri IntersectionMarkings'te; bekleyen araç burnunu dur çizgisine göre ayarlar
## (TrafficVehicle._stop_point — çoğu çizgiye fazla yanaşmaz, bazısı daha geride, azı yaya geçidinin üstünde).
##
## Kamera kavşağa güneydoğudan bakar: doğuya ve güneye bakan iki kafanın yüzü görünür (iki eksenin rengi de
## okunur), diğerlerinin arkası. Maliyet: direkler + kafalar tek gövde, ışıklar eksen × renk başına bir
## gövde (açık / sönük malzeme değişir) — 7 çizim çağrısı, ışık kaynağı yok.

enum Phase { GREEN, YELLOW, ALL_RED }

const GREEN_TIME: float = 7.0
const YELLOW_TIME: float = 1.8
const ALL_RED_TIME: float = 1.2
const COLORS: Array[StringName] = [&"red", &"yellow", &"green"]
## [direk konumu (x, z), [[kafanın baktığı yön (derece, +Z'den), eksen], ...]] — yol kenarları 0 / 1,2, kaldırım
## 0,2; köşe yarıçapları CityScenery (kuzey 0,2 · güney 0,55) — direk düz kaldırımda, köşe kavsinin hemen dışında.
const POLES: Array[Array] = [
	[Vector2(-0.70, 1.31), [[-90.0, 0]]],            # güneybatı: batıdan gelen (doğuya giden), batıya bakar
	[Vector2(1.55, -0.11), [[90.0, 0]]],             # kuzeydoğu: doğudan gelen, doğuya bakar
	[Vector2(1.31, 1.90), [[0.0, 1], [180.0, 1]]],   # güneydoğu: güneyden gelen (güneye bakar) + kuzeyden gelen (karşı köşe)
]
## Kafa direğin önüne takılır: sırt sırta iki kafa birbirinin camını örtmesin.
const HEAD_OFFSET: float = 0.035
const GROUND: float = 0.02          # kaldırım üstü
const POLE_HEIGHT: float = 0.5
const POLE_RADIUS: float = 0.013
const HEAD_SIZE: Vector3 = Vector3(0.075, 0.21, 0.055)
const PLATE_SIZE: Vector3 = Vector3(0.105, 0.245, 0.008)
const LAMP_RADIUS: float = 0.024
const LAMP_STEP: float = 0.064
const INK: Color = Color("2F3236")
const AMBER: Color = Color("F5BE4C")
const STEEL: Color = Color("5A5E64")
const LIT: Dictionary = {&"red": Color("FF3B2F"), &"yellow": Color("FFC21A"), &"green": Color("2EE66B")}
const DARK: Dictionary = {&"red": Color("4A1E1C"), &"yellow": Color("4A3A16"), &"green": Color("173A24")}

## Yeşil yanan eksen (YEŞİL / SARI fazında); TÜM KIRMIZI'da bir sonraki yeşil eksen.
var green_axis: int = 0
var phase: Phase = Phase.GREEN
var _timer: float = GREEN_TIME
var _lamps: Dictionary = {}       # "eksen:renk" → MeshInstance3D
var _materials: Dictionary = {}   # "renk:açık|sönük" → malzeme
var _traffic: TrafficManager


func _init(traffic: TrafficManager = null) -> void:
	name = "TrafficLights"
	_traffic = traffic


func _ready() -> void:
	_build()
	_paint()
	if _traffic:
		_traffic.lights = self


func _exit_tree() -> void:
	if _traffic and is_instance_valid(_traffic) and _traffic.lights == self:
		_traffic.lights = null


func _process(delta: float) -> void:
	advance(delta)


## Bu eksenden kavşağa YENİ araç girebilir mi (yalnızca kendi yeşilinde).
func allows(axis: int) -> bool:
	return phase == Phase.GREEN and axis == green_axis


## Eksenin şu anki rengi: &"green" / &"yellow" / &"red".
func light_of(axis: int) -> StringName:
	if axis != green_axis or phase == Phase.ALL_RED:
		return &"red"
	return &"green" if phase == Phase.GREEN else &"yellow"


## Fazı ve yeşil ekseni doğrudan kurar, fazın süresi baştan başlar (testler / QA). Yalnızca `phase`'i değiştirmek
## sayacı eski fazda bırakır: advance() beklenen anda geçmez, lambalar da boyanmaz.
func set_phase(value: Phase, axis: int) -> void:
	phase = value
	green_axis = clampi(axis, 0, 1)
	match value:
		Phase.GREEN:
			_timer = GREEN_TIME
		Phase.YELLOW:
			_timer = YELLOW_TIME
		_:
			_timer = ALL_RED_TIME
	_paint()


## Zamanı ilerletir (testler de kullanır); faz değişince lambalar boyanır.
func advance(delta: float) -> void:
	_timer -= delta
	while _timer <= 0.0:
		match phase:
			Phase.GREEN:
				phase = Phase.YELLOW
				_timer += YELLOW_TIME
			Phase.YELLOW:
				phase = Phase.ALL_RED
				_timer += ALL_RED_TIME
			Phase.ALL_RED:
				phase = Phase.GREEN
				green_axis = 1 - green_axis
				_timer += GREEN_TIME
		_paint()


## Kavşak giriş noktasından dur çizgisinin ARKA kenarına mesafe: bekleyen aracın burnu buraya hizalanır.
func stop_gap(entry: Node3D) -> float:
	return IntersectionMarkings.stop_gap(entry.global_position)


## Bu lambanın yanan rengi (görsel denetim / testler): eksen + renk → yanıyor mu.
func is_lit(axis: int, color: StringName) -> bool:
	var lamp: MeshInstance3D = _lamps.get("%d:%s" % [axis, color])
	return lamp != null and lamp.material_override == _material(color, true)


# --- Kurulum ----------------------------------------------------------------------------------

func _build() -> void:
	var body: StreetMesh = StreetMesh.new()
	var lamps: Dictionary = {}   # "eksen:renk" → StreetMesh
	for pole: Array in POLES:
		var at: Vector2 = pole[0]
		var foot: Transform3D = Transform3D(Basis(), Vector3(at.x, GROUND, at.y))
		body.cylinder(POLE_RADIUS * 1.9, 0.03, foot.translated_local(Vector3(0.0, 0.015, 0.0)), INK, 10)   # ayak
		body.cylinder(POLE_RADIUS, POLE_HEIGHT, foot.translated_local(Vector3(0.0, POLE_HEIGHT * 0.5, 0.0)), STEEL, 8)
		for spec: Array in pole[1]:
			_head(body, lamps, Transform3D(Basis(Vector3.UP, deg_to_rad(float(spec[0]))), foot.origin), int(spec[1]))
	var poles: MeshInstance3D = MeshInstance3D.new()
	poles.name = "Poles"
	poles.mesh = body.commit()
	poles.material_override = StreetMesh.material()
	add_child(poles)
	for key: String in lamps:
		var lamp: MeshInstance3D = MeshInstance3D.new()
		lamp.name = "Lamp_" + key.replace(":", "_")
		lamp.mesh = (lamps[key] as StreetMesh).commit()
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(lamp)
		_lamps[key] = lamp


## Lamba kafası: kehribar arka levha, koyu gövde, üç lamba (kırmızı üstte) ve siperlikleri. `base` direğin dibinde,
## +Z kafanın baktığı yön; camlar eksen × renk gövdelerine eklenir.
func _head(body: StreetMesh, lamps: Dictionary, base: Transform3D, axis: int) -> void:
	var head: Transform3D = base.translated_local(Vector3(0.0, POLE_HEIGHT + HEAD_SIZE.y * 0.5 - 0.02, HEAD_OFFSET))
	body.box(PLATE_SIZE, head.translated_local(Vector3(0.0, 0.0, -HEAD_SIZE.z * 0.5 - PLATE_SIZE.z * 0.5)), AMBER)
	body.box(HEAD_SIZE, head, INK)
	for i: int in COLORS.size():
		var y: float = LAMP_STEP * float(1 - i)
		# Siperlik: lambanın üstünde öne çıkan ince levha
		body.box(Vector3(LAMP_RADIUS * 2.3, 0.006, 0.03), head.translated_local(Vector3(0.0, y + LAMP_RADIUS + 0.003,
			HEAD_SIZE.z * 0.5 + 0.015)), INK)
		var key: String = "%d:%s" % [axis, COLORS[i]]
		if not lamps.has(key):
			lamps[key] = StreetMesh.new()
		(lamps[key] as StreetMesh).disc(LAMP_RADIUS, head.translated_local(Vector3(0.0, y, HEAD_SIZE.z * 0.5 + 0.002)), Color.WHITE)


func _paint() -> void:
	for axis: int in 2:
		var on: StringName = light_of(axis)
		for color: StringName in COLORS:
			var lamp: MeshInstance3D = _lamps.get("%d:%s" % [axis, color])
			if lamp:
				lamp.material_override = _material(color, color == on)


## Yanan lamba: gölgesiz (ışıktan bağımsız parlak); sönük: koyu cam.
func _material(color: StringName, lit: bool) -> StandardMaterial3D:
	var key: String = "%s:%s" % [color, "on" if lit else "off"]
	if not _materials.has(key):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = LIT[color] if lit else DARK[color]
		_materials[key] = m
	return _materials[key]
