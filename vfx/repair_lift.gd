class_name RepairLift
extends Node3D
## TAMİR ALANININ LİFTİ: CarSpot'un çocuğu olarak kodla kurulur (sahne dosyası düzenlenmez), böylece
## alan taşınınca / döndürülünce / kilitlenince lift de onunla gider. İki yürüme yolu (rampa), altında
## iki makas kol ve zemin rayları. Araç tamire alınınca lift KALKAR (araç üstünde), tamir bitince İNER.
##
## Yerel uzay CarSpot'unkidir: alan 0,5 (x) × 0,7 (z), araç burnu +z. Parçaların hepsi bu kutunun
## içinde kalır (GarageDecorView engel / seçim ölçüsü CarSpot'un kutusundan okunur).
## Animasyon yalnızca hareket sürerken Tween ile işler; kare başına iş yok.

## Lift tamamen kalkmış durumdaki ek yükseklik (dünya birimi; araç boyu ~0,6).
const RAISE_HEIGHT: float = 0.15
## Alçak durumda yürüme yolunun üst yüzü (CarSpot'un orijininden): araç bu kotta durur.
const REST_TOP: float = 0.034
const RAISE_TIME: float = 1.0
const LOWER_TIME: float = 0.9

## Makas kolun uzunluğu (sabit); yatay açıklık yüksekliğe göre değişir.
const ARM_LENGTH: float = 0.36
const ARM_X: float = 0.15
const RUNWAY_WIDTH: float = 0.15
const RUNWAY_LENGTH: float = 0.66
const RUNWAY_THICK: float = 0.016

const STEEL: Color = Color(0.36, 0.39, 0.43)
const DARK: Color = Color(0.17, 0.18, 0.2)
const SAFETY: Color = Color(0.96, 0.74, 0.18)

var _height: float = 0.0
var _platform: Node3D
var _arms: Array[Node3D] = []     # [yan0 A, yan0 B, yan1 A, yan1 B]
var _tween: Tween
var _car: Node3D
var _base_y: float = 0.0   # aracın lifte çıkmadan önceki Y kotu (trafiğe dönerken geri verilir)
var _ram: MeshInstance3D


func _ready() -> void:
	name = "Lift"
	_build()
	_apply()


## Lift yüksekliği (0 = alçakta, 1 = tamamen kalkmış).
func raised_fraction() -> float:
	return _height / RAISE_HEIGHT


func is_moving() -> bool:
	return _tween != null and _tween.is_running()


## Aracın dünya Y kotu (şu anki lift yüksekliğinde, yürüme yolunun üstü).
func car_y() -> float:
	return global_position.y + REST_TOP + _height


## Aracı lifte oturtur ve kaldırır. Araç lift bitince serbest bırakılır (lower).
func raise(car: Node3D) -> void:
	if _car != car:
		_base_y = car.global_position.y
	_car = car
	_go(RAISE_HEIGHT, RAISE_TIME)


## Lifti indirir; araç inerken onunla gider ve alçak liftte kalır (release'e kadar).
func lower() -> void:
	_go(0.0, LOWER_TIME)


## Araç alanda mı (lift bir araca bağlı)?
func has_car() -> bool:
	return _car != null and is_instance_valid(_car)


## Araç alandan ayrılıyor (para toplandı): eski kotuna iner, lift alçak konuma geçer.
func release() -> void:
	if has_car():
		_car.global_position.y = _base_y
	reset()


## Anında alçak konuma (kayıt yükleme, araç ortadan kalktı).
func reset() -> void:
	if _tween:
		_tween.kill()
	_height = 0.0
	_car = null
	_apply()


func _go(target: float, time: float) -> void:
	if _tween:
		_tween.kill()
	var duration: float = time * absf(target - _height) / RAISE_HEIGHT
	if duration <= 0.001:
		_set_height(target)
		return
	_tween = create_tween()
	_tween.tween_method(_set_height, _height, target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _set_height(h: float) -> void:
	_height = h
	_apply()


## Parçaları ve (varsa) aracı yüksekliğe göre yerleştirir.
func _apply() -> void:
	if _platform == null:
		return
	var h: float = _height
	_platform.position.y = REST_TOP - RUNWAY_THICK + h
	# Makas kollar: iki uç alt rayda (y≈0), iki uç yürüme yolunun altında; yatay açıklık = √(L²−H²)
	var rise: float = _platform.position.y - 0.012   # alt kol ucu ile yol altı arası
	var run: float = sqrt(maxf(ARM_LENGTH * ARM_LENGTH - rise * rise, 0.0001))
	var angle: float = atan2(rise, run)
	for i: int in _arms.size():
		var arm: Node3D = _arms[i]
		var side: float = -1.0 if i % 2 == 0 else 1.0
		# kol merkezi: yol altı ile alt ray arasının ortası
		arm.position = Vector3(arm.position.x, 0.012 + rise * 0.5, 0.0)
		arm.rotation = Vector3(side * angle, 0.0, 0.0)
	if _ram:
		_ram.scale.y = h + 0.008
		_ram.position.y = 0.012 + (h + 0.008) * 0.5
	if has_car():
		_car.global_position.y = car_y()


func _mat(color: Color, rough: float = 0.6, metal: float = 0.4) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


func _box(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.name = node_name
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh


func _build() -> void:
	var steel: StandardMaterial3D = _mat(STEEL)
	var dark: StandardMaterial3D = _mat(DARK, 0.8, 0.2)
	var safety: StandardMaterial3D = _mat(SAFETY, 0.5, 0.15)
	# Zemin rayları (alçak; yerde)
	for x: float in [-ARM_X, ARM_X]:
		_box(self, "Rail", Vector3(RUNWAY_WIDTH + 0.02, 0.012, 0.64), Vector3(x, 0.006, 0.0), dark)
	# Yürüme yolları + yan çıta (sarı/siyah uyarı dili)
	_platform = Node3D.new()
	_platform.name = "Platform"
	add_child(_platform)
	for x: float in [-ARM_X, ARM_X]:
		_box(_platform, "Runway", Vector3(RUNWAY_WIDTH, RUNWAY_THICK, RUNWAY_LENGTH), Vector3(x, RUNWAY_THICK * 0.5, 0.0), steel)
		for edge: float in [-1.0, 1.0]:
			_box(_platform, "Edge", Vector3(0.012, RUNWAY_THICK + 0.004, RUNWAY_LENGTH), 
				Vector3(x + edge * (RUNWAY_WIDTH * 0.5 - 0.006), RUNWAY_THICK * 0.5 + 0.002, 0.0), safety)
	# Yolları bağlayan enine kirişler (önde ve arkada)
	for z: float in [-0.27, 0.0, 0.27]:
		_box(_platform, "Cross", Vector3(ARM_X * 2.0, 0.012, 0.03), Vector3(0.0, -0.002, z), dark)
	# Makas kollar (her yanda çapraz iki kol)
	for x: float in [-ARM_X, ARM_X]:
		for k: int in 2:
			var arm: Node3D = Node3D.new()
			arm.name = "Arm"
			arm.position = Vector3(x, 0.02, 0.0)
			add_child(arm)
			_box(arm, "Bar", Vector3(0.022, 0.012, ARM_LENGTH), Vector3.ZERO, steel)
			_arms.append(arm)
	# Hidrolik piston (ortada, yüksekliğe göre uzar)
	var ram_mesh: CylinderMesh = CylinderMesh.new()
	ram_mesh.top_radius = 0.016
	ram_mesh.bottom_radius = 0.016
	ram_mesh.height = 1.0
	_ram = MeshInstance3D.new()
	_ram.name = "Ram"
	_ram.mesh = ram_mesh
	_ram.material_override = _mat(Color(0.75, 0.78, 0.82), 0.25, 0.9)
	_ram.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ram.scale = Vector3(1.0, 0.008, 1.0)
	add_child(_ram)
