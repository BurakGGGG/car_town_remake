class_name DragTrack
extends Node3D
## DRAG PİSTİ DEKORU — yalnızca GÖRSEL. Yarış mantığı (süre, vites, ödül) DragRaceSim /
## RaceManager'dadır; bu sahne onları hiç bilmez, yalnızca "burası özel bir drag pisti" der.
##
## Şehir yolundan ayrıştıran şeyler: koyu kömür asfalt + lastik izleri, iki belirgin şerit ve
## start gridi, çakıl apron, lastik/beton bariyerler, korkuluk, pit duvarı, tribün, uzakta depo
## siluetleri, damalı FINISH çizgisi ve tabelası, stilize "christmas tree" çıkış ışığı.
##
## Mobil bütçe: hepsi primitive mesh (BoxMesh/CylinderMesh), gölge KAPALI, ışık tek yönlü.
## Tekrarlayan bariyerler tek MultiMesh'te toplanır (yüzlerce çizim çağrısı olmaz).

## Yarışın koşulduğu görsel uzunluk (DragRaceSim'in 150 m'sinin temsili).
const TRACK_LENGTH: float = 22.0
## Şeritlerin merkez ekseninden uzaklığı (araçlar buraya oturur).
const LANE_OFFSET: float = 0.56
## Asfalt genişliği ve pistin başlangıçtan geriye / bitişten ileriye uzantısı.
const ASPHALT_WIDTH: float = 3.2
const RUN_IN: float = 8.0
## Araçların çıkışta durduğu yer — araç MERKEZİ. Tüm modeller boyu 1,0'e normalize edilmiş ve
## +Z'ye bakıyor (ölçüldü), yani burun merkezin 0,5 × CAR_SCALE (1,2) = 0,6 önündedir: merkez
## -0,60'ta olunca **burun tam çıkış çizgisinin (z = 0) üstünde** durur. Bonus: yarış bitince
## (merkez START_Z + TRACK_LENGTH) burun da tam bitiş çizgisine oturur.
const START_Z: float = -0.60
const RUN_OUT: float = 10.0

# Palet — oyunun dili: koyu kontur, krem plaka, amber vurgu
const ASPHALT_DARK: Color = Color("24272B")
const ASPHALT_LANE: Color = Color("2C3035")
const LINE_WHITE: Color = Color("EFEDE4")
const LINE_AMBER: Color = Color("F5BE4C")
const GRAVEL: Color = Color("4A4741")
const CONCRETE: Color = Color("9A958A")
const TIRE_DARK: Color = Color("1C1E21")
const STEEL: Color = Color("6E7379")
const GRASS_FAR: Color = Color("6E9445")

## Asset yolları — dosya yoksa düz renk / kutu yedekleri devreye girer.
const ASPHALT_TEXTURE: String = "res://race/art/asphalt_dark.png"
const CONCRETE_TEXTURE: String = "res://race/art/barrier_concrete.png"
const TIRE_TEXTURE: String = "res://race/art/tire_barrier.png"
const BANNER_TEXTURE: String = "res://race/art/finish_banner.png"
const STAND_TEXTURE: String = "res://race/art/grandstand.png"

const LAMP_OFF: Color = Color("3A3D42")
const LAMP_AMBER: Color = Color("F5BE4C")
const LAMP_GREEN: Color = Color("5FD36A")

var _lamps: Array[MeshInstance3D] = []
var _ready_lamps: Array[MeshInstance3D] = []
var _total_length: float = TRACK_LENGTH + RUN_IN + RUN_OUT
var _center_z: float = (TRACK_LENGTH + RUN_OUT - RUN_IN) * 0.5


func _ready() -> void:
	name = "DragTrack"
	_build_ground()
	_build_asphalt()
	_build_start_grid()
	_build_run_in()
	_build_distance_posts()
	_build_finish()
	_build_barriers()
	_build_scenery()
	_build_start_tree()
	set_lights(4)


## Çıkış ışığı: 4 = sönük (hazırlık), 3/2/1 = amberler sırayla yanar, 0 = GO (amber söner, yeşil yanar).
func set_lights(step: int) -> void:
	for i: int in _lamps.size():
		var green: bool = i == _lamps.size() - 1
		var lit: bool = (green and step == 0) or (not green and step <= 3 and step >= 1 and i < 3 - step + 1)
		var color: Color = LAMP_GREEN if green else LAMP_AMBER
		_paint_lamp(_lamps[i], color if lit else LAMP_OFF, lit)
	for lamp: MeshInstance3D in _ready_lamps:
		_paint_lamp(lamp, LAMP_AMBER if step <= 3 else LAMP_OFF, step <= 3)


func _paint_lamp(lamp: MeshInstance3D, color: Color, lit: bool) -> void:
	var material: StandardMaterial3D = lamp.material_override
	material.albedo_color = color
	material.emission_enabled = lit
	material.emission = color
	material.emission_energy_multiplier = 1.8 if lit else 0.0


# --- Zemin ve asfalt ----------------------------------------------------------------

## Gökyüzü: düz renk yerine yumuşak gradyan (ufuk çizgisi belirsin, mobilde bedava).
static func sky() -> Sky:
	var material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	material.sky_top_color = Color("6E93B5")
	material.sky_horizon_color = Color("BBD0DC")
	material.ground_bottom_color = Color("4A4741")
	material.ground_horizon_color = Color("8C9A9E")
	material.sun_angle_max = 24.0
	var value: Sky = Sky.new()
	value.sky_material = material
	return value


func _build_ground() -> void:
	# Çakıl apron (pistin iki yanı) — şehir çimi yerine yarış alanı zemini.
	# Düz gri boşluk yerine asfalt dokusunun iri ölçekli, açık tonlu hâli: kadrajın kenarlarında
	# zemin "boş" görünmüyor (doku yoksa düz GRAVEL rengi kalır).
	var apron: MeshInstance3D = _plane(Vector2(26.0, _total_length + 24.0),
		Vector3(0.0, -0.12, _center_z), GRAVEL)
	apron.material_override = _textured(ASPHALT_TEXTURE, GRAVEL, Vector2(9.0, 14.0), false,
		Color(0.96, 0.94, 0.88))
	# Uzakta düşük ton çim şeridi (ufuk boş kalmasın)
	_plane(Vector2(70.0, 26.0), Vector3(0.0, -0.14, _center_z + _total_length * 0.5 + 16.0), GRASS_FAR)
	_plane(Vector2(70.0, 26.0), Vector3(0.0, -0.14, _center_z - _total_length * 0.5 - 16.0), GRASS_FAR)


func _build_asphalt() -> void:
	# Koyu kömür asfalt + iki şerit tonu (şehir yolundan ayrışsın)
	var road: MeshInstance3D = _box(Vector3(ASPHALT_WIDTH, 0.10, _total_length),
		Vector3(0.0, -0.05, _center_z), ASPHALT_DARK)
	# Asfalt dokusu: 2 birimde bir tekrar (dikişsiz); dosya yoksa düz koyu renk kalır
	var uv: Vector2 = Vector2(ASPHALT_WIDTH * 0.5, _total_length * 0.5)
	# Doku kendi başına açık gri; koyu asfalt tonuna indirilir (şehir yolundan ayrışsın).
	road.material_override = _textured(ASPHALT_TEXTURE, ASPHALT_DARK, uv, false, Color(0.46, 0.47, 0.50))
	# Şerit kutuları asfalt kutusunun ÜSTÜNDE durur; doku yalnızca tabana verilirse görünmez
	# kalıyordu. Aynı doku, bir tık açık tonla.
	var lane_material: StandardMaterial3D = _textured(ASPHALT_TEXTURE, ASPHALT_LANE,
		Vector2(uv.x * 0.5, uv.y), false, Color(0.54, 0.55, 0.58))
	for side: int in [-1, 1]:
		var lane: MeshInstance3D = _box(Vector3(ASPHALT_WIDTH * 0.5 - 0.06, 0.11, _total_length),
			Vector3((ASPHALT_WIDTH * 0.25 + 0.03) * float(side), -0.045, _center_z), ASPHALT_LANE)
		lane.material_override = lane_material
	# Orta ayırıcı ve dış pist çizgileri (kesiksiz — şehir yolundaki kesikli çizgi YOK)
	_box(Vector3(0.10, 0.12, _total_length), Vector3(0.0, -0.04, _center_z), LINE_WHITE)
	for side: int in [-1, 1]:
		_box(Vector3(0.07, 0.12, _total_length),
			Vector3((ASPHALT_WIDTH * 0.5 - 0.10) * float(side), -0.04, _center_z), LINE_WHITE)

	# Kerb: düz amber şerit yerine amber/krem bloklar (yarış pisti dili)
	var kerb_len: float = 1.1
	var kerb_count: int = int(_total_length / kerb_len)
	for tone: int in 2:
		var kerb: MultiMesh = MultiMesh.new()
		kerb.transform_format = MultiMesh.TRANSFORM_3D
		var block: BoxMesh = BoxMesh.new()
		block.size = Vector3(0.22, 0.13, kerb_len * 0.5)
		kerb.mesh = block
		kerb.instance_count = kerb_count
		var index: int = 0
		for i: int in kerb_count:
			var z: float = _center_z - _total_length * 0.5 + kerb_len * (float(i) + 0.5)
			var side: float = 1.0 if (i + tone) % 2 == 0 else -1.0
			kerb.set_instance_transform(index, Transform3D(Basis.IDENTITY,
				Vector3((ASPHALT_WIDTH * 0.5 + 0.13) * side, -0.04,
					z + (0.0 if tone == 0 else kerb_len * 0.5))))
			index += 1
		_multi(kerb, LINE_AMBER if tone == 0 else Color("EFE7D6"))

	# Kalkış lastik izleri: start çizgisinden ileriye doğru kısa koyu şeritler
	for side: int in [-1, 1]:
		for i: int in 2:
			var x: float = LANE_OFFSET * float(side) + (0.16 if i == 0 else -0.16)
			_box(Vector3(0.14, 0.115, 5.0), Vector3(x, -0.043, 2.2), TIRE_DARK)


# --- Start / finish -----------------------------------------------------------------

## START GRID: kalın çıkış çizgisi + her şerit için aracın etrafını saran grid karesi.
## Kareler aracın DURDUĞU yere (START_Z) göre hizalanır; amber ok aracın ÖNÜNDE durur.
func _build_start_grid() -> void:
	_box(Vector3(ASPHALT_WIDTH, 0.13, 0.20), Vector3(0.0, -0.035, 0.0), LINE_WHITE)
	for side: int in [-1, 1]:
		var x: float = LANE_OFFSET * float(side)
		# Kare çizgiye göre kurulur (aracın boyuna göre değil): ön kenar çizginin 8 cm önünde,
		# arka kenar 1,50 geride — araç (boyu 1,2) karenin içinde, burnu çizgide durur.
		var box_z: float = -0.71
		_box(Vector3(0.05, 0.13, 1.58), Vector3(x - 0.50, -0.035, box_z), LINE_WHITE)
		_box(Vector3(0.05, 0.13, 1.58), Vector3(x + 0.50, -0.035, box_z), LINE_WHITE)
		_box(Vector3(1.00, 0.13, 0.05), Vector3(x, -0.035, box_z - 0.79), LINE_WHITE)
		# Şerit numarası yerine amber ok: aracın önünde, gidiş yönünü gösterir
		_box(Vector3(0.42, 0.135, 0.08), Vector3(x, -0.03, 0.42), LINE_AMBER)


## Mesafe direkleri: hız hissini artırır (araçlar geçtikçe akar). Tek MultiMesh.
func _build_distance_posts() -> void:
	var post: MultiMesh = MultiMesh.new()
	post.transform_format = MultiMesh.TRANSFORM_3D
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.07, 0.36, 0.07)
	post.mesh = box
	var count: int = int(_total_length / 3.0)
	post.instance_count = count * 2
	for i: int in count:
		var z: float = _center_z - _total_length * 0.5 + 1.5 + float(i) * 3.0
		for s_i: int in 2:
			var x: float = (ASPHALT_WIDTH * 0.5 + 0.82) * (1.0 if s_i == 0 else -1.0)
			post.set_instance_transform(i * 2 + s_i, Transform3D(Basis.IDENTITY, Vector3(x, 0.18, z)))
	_multi(post, Color("E6E2D6"))


## ÇIKIŞ ÖNCESİ ALAN: ısınma (burnout) kutusu, hakem kulübesi ve koniler — boş asfalt kalmasın.
func _build_run_in() -> void:
	# Isınma (burnout) izleri: yalnızca asfalttan biraz açık tarama şeritleri — beyaz çerçeve YOK,
	# çünkü çıkış gridiyle karışıyordu. Gridin epey gerisinde durur.
	for side: int in [-1, 1]:
		var x: float = LANE_OFFSET * float(side)
		for i: int in 6:
			_box(Vector3(1.08, 0.105, 0.06), Vector3(x, -0.042, -5.0 - float(i) * 0.32),
				ASPHALT_LANE.lightened(0.12))
	# Hakem kulübesi: gridin gerisinde, pist kenarında
	var booth_x: float = -(ASPHALT_WIDTH * 0.5 + 1.9)
	_box(Vector3(0.9, 0.9, 1.1), Vector3(booth_x, 0.45, -5.4), Color("CFC9BA"))
	_box(Vector3(1.05, 0.10, 1.25), Vector3(booth_x, 0.95, -5.4), Color("F3E8CF"))
	_box(Vector3(0.92, 0.10, 0.06), Vector3(booth_x, 0.72, -5.96), LINE_AMBER)
	# Koniler: ısınma alanının kenarında, kadrajın dışına doğru
	var cones: MultiMesh = MultiMesh.new()
	cones.transform_format = MultiMesh.TRANSFORM_3D
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.02
	cone.bottom_radius = 0.10
	cone.height = 0.24
	cone.radial_segments = 8
	cones.mesh = cone
	cones.instance_count = 6
	for i: int in 6:
		var z: float = -4.4 - float(i % 3) * 1.3
		var x: float = (ASPHALT_WIDTH * 0.5 - 0.22) * (1.0 if i < 3 else -1.0)
		cones.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(x, 0.12, z)))
	_multi(cones, Color("E4632F"))


func _build_finish() -> void:
	# Damalı bitiş çizgisi (iki sıra dama)
	var cells: int = 12
	var cell: float = ASPHALT_WIDTH / float(cells)
	for row: int in 2:
		for i: int in cells:
			var dark: bool = (i + row) % 2 == 0
			_box(Vector3(cell, 0.14, 0.24),
				Vector3(-ASPHALT_WIDTH * 0.5 + cell * (float(i) + 0.5), -0.03, TRACK_LENGTH + float(row) * 0.24),
				TIRE_DARK if dark else LINE_WHITE)
	# FINISH tabelası: iki direk + krem plaka + damalı şerit
	# Kapı yüksekliği yakın kadraja göre: eskiden tabela kadrajın üstünde kalıyordu.
	for side: int in [-1, 1]:
		_box(Vector3(0.12, 1.50, 0.12), Vector3((ASPHALT_WIDTH * 0.5 + 0.35) * float(side), 0.75, TRACK_LENGTH + 0.1), STEEL)
	# Tabela: tek dokulu pano (FINISH yazısı + damalı şerit görselin içinde). Dosya yoksa
	# krem plaka + damalı bloklar yedeği devreye girer.
	var banner_width: float = ASPHALT_WIDTH + 0.9
	if ResourceLoader.exists(BANNER_TEXTURE):
		_billboard(BANNER_TEXTURE, Vector2(banner_width, banner_width * 0.2),
			Vector3(0.0, 1.25, TRACK_LENGTH + 0.06), 0.0)
	else:
		_box(Vector3(banner_width, 0.44, 0.10), Vector3(0.0, 1.44, TRACK_LENGTH + 0.1), Color("F3E8CF"))
		for i: int in 14:
			_box(Vector3(0.24, 0.12, 0.12),
				Vector3(-ASPHALT_WIDTH * 0.5 - 0.3 + float(i) * 0.28, 1.18, TRACK_LENGTH + 0.1),
				TIRE_DARK if i % 2 == 0 else LINE_WHITE)


# --- Bariyerler (tek MultiMesh: çizim çağrısı patlamasın) ----------------------------

func _build_barriers() -> void:
	var start_z: float = _center_z - _total_length * 0.5
	var count: int = int(_total_length / 1.4)
	# Beton bariyer duvarı (iki yan)
	var wall: MultiMesh = MultiMesh.new()
	wall.transform_format = MultiMesh.TRANSFORM_3D
	var wall_box: BoxMesh = BoxMesh.new()
	wall_box.size = Vector3(0.26, 0.42, 1.3)
	wall.mesh = wall_box
	wall.instance_count = count * 2
	for i: int in count:
		var z: float = start_z + 0.7 + float(i) * 1.4
		for s: int in 2:
			var x: float = (ASPHALT_WIDTH * 0.5 + 1.05) * (1.0 if s == 0 else -1.0)
			wall.set_instance_transform(i * 2 + s, Transform3D(Basis.IDENTITY, Vector3(x, 0.21, z)))
	_multi(wall, CONCRETE, CONCRETE_TEXTURE, Vector2(1.0, 0.34))

	# Lastik bariyerleri (yalnızca start-finish arası, amber/koyu ikili)
	var tires: MultiMesh = MultiMesh.new()
	tires.transform_format = MultiMesh.TRANSFORM_3D
	var tire_mesh: CylinderMesh = CylinderMesh.new()
	tire_mesh.top_radius = 0.17
	tire_mesh.bottom_radius = 0.17
	tire_mesh.height = 0.2
	tire_mesh.radial_segments = 10
	tires.mesh = tire_mesh
	var tire_count: int = int((TRACK_LENGTH + 4.0) / 1.1)
	tires.instance_count = tire_count * 2
	for i: int in tire_count:
		var z: float = -2.0 + float(i) * 1.1
		for s: int in 2:
			var x: float = (ASPHALT_WIDTH * 0.5 + 1.45) * (1.0 if s == 0 else -1.0)
			tires.set_instance_transform(i * 2 + s, Transform3D(Basis.IDENTITY, Vector3(x, 0.1, z)))
	_multi(tires, TIRE_DARK, TIRE_TEXTURE, Vector2(0.5, 0.25))

	# Korkuluk: ince metal şerit (iki yan, tek uzun kutu)
	for side: int in [-1, 1]:
		_box(Vector3(0.08, 0.14, _total_length),
			Vector3((ASPHALT_WIDTH * 0.5 + 1.85) * float(side), 0.52, _center_z), STEEL)


# --- Çevre: pit duvarı, tribün, depo siluetleri --------------------------------------

func _build_scenery() -> void:
	# Pit duvarı (sağ taraf) + sponsor plakaları
	_box(Vector3(0.3, 0.7, 9.0), Vector3(-(ASPHALT_WIDTH * 0.5 + 3.2), 0.35, 3.0), Color("D8D2C4"))
	for i: int in 4:
		_box(Vector3(0.05, 0.34, 1.5), Vector3(-(ASPHALT_WIDTH * 0.5 + 3.04), 0.42, 0.2 + float(i) * 2.2),
			LINE_AMBER if i % 2 == 0 else Color("F3E8CF"))
	# Tribün (sol taraf): dokulu pano (yoksa kademeli kutu yedeği)
	if ResourceLoader.exists(STAND_TEXTURE):
		# Korkuluğun (x = yarım genişlik + 1,85) hemen ardında: kadrajda bariyerin üstünden
		# görünür ama araçları kapatmaz. Daha uzaktayken kadrajın üst kenarında kesiliyordu.
		# Pistin çoğu boyunca uzanır: kamera ilerlerken kalabalık kadrajın üst şeridinde akar.
		_billboard(STAND_TEXTURE, Vector2(20.0, 2.2),
			Vector3(ASPHALT_WIDTH * 0.5 + 1.9, 0.85, 6.0), -90.0)
	else:
		for i: int in 3:
			_box(Vector3(1.0, 0.34 + float(i) * 0.30, 7.0),
				Vector3(ASPHALT_WIDTH * 0.5 + 3.4 + float(i) * 1.0, (0.34 + float(i) * 0.30) * 0.5, 4.0),
				Color("B9B3A4") if i % 2 == 0 else Color("CFC9BA"))
	# Uzakta depo / sanayi siluetleri (düşük detay, sadece hacim)
	var far: Array = [
		[Vector3(6.0, 2.2, 4.0), Vector3(11.0, 1.1, TRACK_LENGTH + 6.0), Color("AEB6BC")],
		[Vector3(4.5, 1.6, 3.2), Vector3(6.0, 0.8, TRACK_LENGTH + 9.0), Color("C2C8CD")],
		[Vector3(7.0, 2.6, 4.5), Vector3(-10.0, 1.3, TRACK_LENGTH + 7.5), Color("B6BEC4")],
		[Vector3(3.2, 1.4, 3.0), Vector3(-6.0, 0.7, -RUN_IN - 3.0), Color("BFC6CB")],
	]
	for item: Array in far:
		_box(item[0], item[1], item[2])
	# Birkaç çalı/ağaç kütlesi (basit kutu + küre değil: tek koni)
	for i: int in 5:
		var z: float = -RUN_IN + float(i) * 6.0
		var tree: MeshInstance3D = MeshInstance3D.new()
		var cone: CylinderMesh = CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.55
		cone.height = 1.5
		cone.radial_segments = 8
		tree.mesh = cone
		tree.position = Vector3(ASPHALT_WIDTH * 0.5 + 7.5, 0.75, z)
		tree.material_override = _material(Color("55772F"))
		tree.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(tree)


# --- Çıkış ışığı (stilize christmas tree) --------------------------------------------

## Pistin TAM ORTASINA — iki şeridin arasına, çıkış çizgisinin hemen gerisine kurulur. Direk ince
## ve şeritler arası boşluğa oturur; araçları kapatmaz, ikisinin arasında yükselir.
func _build_start_tree() -> void:
	# Gerçek pistlerde fikstür iki şeridin tam ortasındadır; bu kamerada (araçların önünden,
	# -X tarafından bakılıyor) ortadaki direk OYUNCUNUN aracının tam önüne düşüp gövdeyi
	# ikiye bölüyordu (ölçüldü: oyuncu ekranda x=503, fikstür x≈400 ve önünde). Fikstür
	# şeritlerin UZAK kenarına alındı: kameraya göre araçların ARKASINDA kalır, ışıklar
	# okunur, hiçbir aracı kapatmaz.
	var z: float = 0.10
	var x: float = LANE_OFFSET + 0.59
	# Yakın kadrajda (araçlar ekran genişliğinin ~%23'ü) uzun direk kadrajın üstünden taşıyordu:
	# fikstür %14 kısaltıldı, ışık sırası olduğu gibi duruyor.
	_box(Vector3(0.32, 0.08, 0.32), Vector3(x, 0.02, z), Color("2F3236"))        # kaide
	_box(Vector3(0.07, 0.38, 0.07), Vector3(x, 0.20, z), Color("3A3D42"))        # direk
	_box(Vector3(0.22, 0.74, 0.13), Vector3(x, 0.76, z), Color("2F3236"))        # pano
	_box(Vector3(0.30, 0.08, 0.17), Vector3(x, 1.16, z), Color("F3E8CF"))        # üst plaka
	# Üstte iki küçük "hazır" lambası, altında üç amber ve en altta yeşil
	# Lambalar panonun KAMERAYA bakan yüzünde (+Z): kamera araçların önünde durduğu için
	# sürücü tarafına asılan lambalar panonun arkasında kalıyordu.
	for i: int in 2:
		_lamp(Vector3(x - 0.055 + float(i) * 0.11, 1.06, z + 0.055), 0.032, LAMP_OFF, true)
	for i: int in 4:
		_lamps.append(_lamp(Vector3(x, 0.96 - float(i) * 0.155, z + 0.075), 0.062, LAMP_OFF, false))


func _lamp(position: Vector3, radius: float, color: Color, small: bool) -> MeshInstance3D:
	var lamp: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 10
	sphere.rings = 6
	lamp.mesh = sphere
	lamp.position = position
	lamp.material_override = _material(color)
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lamp)
	if small:
		_ready_lamps.append(lamp)
	return lamp


# --- Yardımcılar ---------------------------------------------------------------------

func _box(size: Vector3, position: Vector3, color: Color) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = position
	mesh.material_override = _material(color)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	return mesh


func _plane(size: Vector2, position: Vector3, color: Color) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = size
	mesh.mesh = plane
	mesh.position = position
	mesh.material_override = _material(color)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	return mesh


func _multi(multimesh: MultiMesh, color: Color, texture: String = "",
		uv_scale: Vector2 = Vector2.ONE) -> void:
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = _textured(texture, color, uv_scale) if texture != "" else _material(color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	return material


## DOKULU malzeme. Dosya yoksa düz `color`'a düşer: eksik asset hiçbir şeyi bozmaz.
## Doku VARSA albedo rengi BEYAZ olur — yoksa görselin kendi rengi (beton grisi, kırmızı/beyaz
## lastikler) yedek renkle çarpılıp kahverengi/siyah bir hâl alıyordu. `tint` ile hafif ton verilir.
func _textured(path: String, color: Color, uv_scale: Vector2 = Vector2.ONE,
		alpha: bool = false, tint: Color = Color.WHITE) -> StandardMaterial3D:
	var material: StandardMaterial3D = _material(color)
	if not ResourceLoader.exists(path):
		return material
	material.albedo_color = tint
	material.albedo_texture = load(path)
	material.uv1_scale = Vector3(uv_scale.x, uv_scale.y, 1.0)
	if alpha:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.4
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## Dokulu dikey pano (tabela, tribün): tek quad, gölgesiz.
func _billboard(path: String, size: Vector2, position: Vector3, yaw: float) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = size
	mesh.mesh = quad
	mesh.position = position
	mesh.rotation_degrees = Vector3(0.0, yaw, 0.0)
	mesh.material_override = _textured(path, Color.WHITE, Vector2.ONE, true)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	return mesh
