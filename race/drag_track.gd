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

## Yarışın koşulduğu görsel uzunluk: DragRaceSim'in 300 metresi GERÇEK ÖLÇEKTE. Araç 1,2 birim
## (≈ 4,5 m) olduğundan 1 m ≈ 0,267 birim → 300 m ≈ 80 birim. Eskiden 22 birimdi: pist araca göre
## 3,6 kat kısaydı, 200 km/s'te araç saniyede ~3 boy ilerliyordu (gerçekte ~12) ve yarış "yavaş"
## hissettiriyordu (kapalı test geri bildirimi). Süreler ve fizik değişmedi; yalnızca ekrandaki akış.
const TRACK_LENGTH: float = 80.0
## HIZ SINIFINA GÖRE ÖLÇEK: aynı 300 m, hızlı araçla yarışırken daha UZUN pist olarak çizilir
## (1,0 → 1,6). Süreler ve sonuç değişmez; yalnızca dünyanın ekranda akış hızı. Fizik farkı
## (Şahin 135, 488 Pista 173 km/sa) tek başına görünmüyordu: "Tofaşla da Lambo ile de aynı" (test).
const SCALE_MIN: float = 1.0
const SCALE_MAX: float = 1.6
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
## Bitişten sonraki pay: araçlar çizgiyi geçip frenleyerek durur (DragRaceScreen.OVERRUN_BRAKE).
const RUN_OUT: float = 26.0

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
## Bu yarışın görsel pist uzunluğu (TRACK_LENGTH × ölçek) ve bitiş payı.
var length: float = TRACK_LENGTH
var run_out: float = RUN_OUT
var _total_length: float = TRACK_LENGTH + RUN_IN + RUN_OUT
var _center_z: float = (TRACK_LENGTH + RUN_OUT - RUN_IN) * 0.5


func _ready() -> void:
	name = "DragTrack"
	_build()


## Oyuncu aracının görsel ölçeği (1,0 … SCALE_MAX): hızlanma statından. Ekonomi araçları 1,0'da
## kalır (gerçek ölçek), süper sporlar dünyayı 1,6 kat hızlı akıtır.
static func scale_for(vehicle_id: StringName) -> float:
	var accel: float = float(DragRaceSim.stats_of(vehicle_id).get("acceleration", 50))
	return lerpf(SCALE_MIN, SCALE_MAX, clampf((accel - 60.0) / 38.0, 0.0, 1.0))


## Pisti bu ölçekte yeniden kurar (ölçek değişmediyse bir şey yapmaz).
func set_scale_factor(factor: float) -> void:
	var wanted: float = TRACK_LENGTH * factor
	if is_equal_approx(wanted, length):
		return
	length = wanted
	run_out = RUN_OUT * factor
	_total_length = length + RUN_IN + run_out
	_center_z = (length + run_out - RUN_IN) * 0.5
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_lamps.clear()
	_ready_lamps.clear()
	_build()


func _build() -> void:
	_build_ground()
	_build_asphalt()
	_build_start_grid()
	_build_run_in()
	_build_distance_posts()
	_build_finish()
	_build_barriers()
	_build_scenery()
	_build_start_tree()
	_build_sponsor_boards()
	_build_distance_boards()
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
			_box(Vector3(0.14, 0.115, 9.0), Vector3(x, -0.043, 4.2), TIRE_DARK)


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
				Vector3(-ASPHALT_WIDTH * 0.5 + cell * (float(i) + 0.5), -0.03, length + float(row) * 0.24),
				TIRE_DARK if dark else LINE_WHITE)
	# FINISH tabelası: iki direk + krem plaka + damalı şerit
	# Kapı yüksekliği yakın kadraja göre: eskiden tabela kadrajın üstünde kalıyordu.
	for side: int in [-1, 1]:
		_box(Vector3(0.12, 1.50, 0.12), Vector3((ASPHALT_WIDTH * 0.5 + 0.35) * float(side), 0.75, length + 0.1), STEEL)
	# Tabela: tek dokulu pano (FINISH yazısı + damalı şerit görselin içinde). Dosya yoksa
	# krem plaka + damalı bloklar yedeği devreye girer.
	var banner_width: float = ASPHALT_WIDTH + 0.9
	if ResourceLoader.exists(BANNER_TEXTURE):
		_billboard(BANNER_TEXTURE, Vector2(banner_width, banner_width * 0.2),
			Vector3(0.0, 1.25, length + 0.06), 0.0)
	else:
		_box(Vector3(banner_width, 0.44, 0.10), Vector3(0.0, 1.44, length + 0.1), Color("F3E8CF"))
		for i: int in 14:
			_box(Vector3(0.24, 0.12, 0.12),
				Vector3(-ASPHALT_WIDTH * 0.5 - 0.3 + float(i) * 0.28, 1.18, length + 0.1),
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
	var tire_count: int = int((length + 4.0) / 1.1)
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
	# Pist uzadığı için çevre TEKRARLANIR: tek parça tribün / pit duvarı yarışın ilk saniyesinde
	# kadrajdan çıkıp geri kalan 70 birimi boş bırakıyordu.
	# Pit duvarı (sağ taraf) + sponsor plakaları — 18 birimde bir 9 birimlik duvar
	var pit_x: float = -(ASPHALT_WIDTH * 0.5 + 3.2)
	var segment: float = 18.0
	var z: float = 3.0
	while z < length:
		_box(Vector3(0.3, 0.7, 9.0), Vector3(pit_x, 0.35, z), Color("D8D2C4"))
		for i: int in 4:
			_box(Vector3(0.05, 0.34, 1.5), Vector3(pit_x + 0.16, 0.42, z - 2.8 + float(i) * 2.2),
				LINE_AMBER if i % 2 == 0 else Color("F3E8CF"))
		z += segment
	# Tribün (sol taraf): dokulu pano (yoksa kademeli kutu yedeği). Korkuluğun hemen ardında:
	# kadrajda bariyerin üstünden görünür ama araçları kapatmaz. Pist boyunca 20'şer birim döşenir.
	var stand_z: float = 6.0
	while stand_z < length + 12.0:
		if ResourceLoader.exists(STAND_TEXTURE):
			_billboard(STAND_TEXTURE, Vector2(20.0, 2.2),
				Vector3(ASPHALT_WIDTH * 0.5 + 1.9, 0.85, stand_z), -90.0)
		else:
			for i: int in 3:
				_box(Vector3(1.0, 0.34 + float(i) * 0.30, 19.0),
					Vector3(ASPHALT_WIDTH * 0.5 + 3.4 + float(i) * 1.0, (0.34 + float(i) * 0.30) * 0.5,
						stand_z), Color("B9B3A4") if i % 2 == 0 else Color("CFC9BA"))
		stand_z += 20.0
	_build_floodlights()
	# Uzakta depo / sanayi siluetleri (düşük detay, sadece hacim)
	var far: Array = [
		[Vector3(6.0, 2.2, 4.0), Vector3(11.0, 1.1, length + 6.0), Color("AEB6BC")],
		[Vector3(4.5, 1.6, 3.2), Vector3(6.0, 0.8, length + 9.0), Color("C2C8CD")],
		[Vector3(7.0, 2.6, 4.5), Vector3(-10.0, 1.3, length + 7.5), Color("B6BEC4")],
		[Vector3(3.2, 1.4, 3.0), Vector3(-6.0, 0.7, -RUN_IN - 3.0), Color("BFC6CB")],
	]
	for item: Array in far:
		_box(item[0], item[1], item[2])
	# Ağaç kütleleri (tek koni): tek MultiMesh, pist boyunca 6 birimde bir
	var trees: MultiMesh = MultiMesh.new()
	trees.transform_format = MultiMesh.TRANSFORM_3D
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.55
	cone.height = 1.5
	cone.radial_segments = 8
	trees.mesh = cone
	var tree_count: int = int((_total_length + 8.0) / 6.0)
	trees.instance_count = tree_count
	for i: int in tree_count:
		trees.set_instance_transform(i, Transform3D(Basis.IDENTITY,
			Vector3(ASPHALT_WIDTH * 0.5 + 7.5, 0.75, -RUN_IN + float(i) * 6.0)))
	_multi(trees, Color("55772F"))


## Projektör kuleleri: tribünün ardında, yüksek ve ince — yarış sırasında kadrajın üst şeridinde
## düzenli aralıkla akarak hızı okutur. Direkler ve başlıklar ikişer MultiMesh.
func _build_floodlights() -> void:
	var count: int = int((length + 10.0) / 12.0) + 1
	var poles: MultiMesh = MultiMesh.new()
	poles.transform_format = MultiMesh.TRANSFORM_3D
	var pole: BoxMesh = BoxMesh.new()
	pole.size = Vector3(0.12, 3.6, 0.12)
	poles.mesh = pole
	poles.instance_count = count
	var heads: MultiMesh = MultiMesh.new()
	heads.transform_format = MultiMesh.TRANSFORM_3D
	var head: BoxMesh = BoxMesh.new()
	head.size = Vector3(0.18, 0.42, 0.8)
	heads.mesh = head
	heads.instance_count = count
	var x: float = ASPHALT_WIDTH * 0.5 + 3.6
	for i: int in count:
		var z: float = -4.0 + float(i) * 12.0
		poles.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(x, 1.8, z)))
		heads.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(x - 0.08, 3.6, z)))
	_multi(poles, STEEL)
	var lamp_material: StandardMaterial3D = _material(Color("FFF4D6"))
	lamp_material.emission_enabled = true
	lamp_material.emission = Color("FFE7A8")
	lamp_material.emission_energy_multiplier = 1.4
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.multimesh = heads
	instance.material_override = lamp_material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


## Sponsor panoları: beton duvarın İÇ yüzüne asılı renkli levhalar. Kameraya en yakın şey bunlar
## (ön planda, sol altta): yarışta hızla akarak "hız hissi"nin asıl kaynağı olurlar.
func _build_sponsor_boards() -> void:
	var colors: Array[Color] = [LINE_AMBER, Color("EFE7D6"), Color("D9533A"), Color("3E6E9E")]
	var spacing: float = 2.8
	var count: int = int(_total_length / spacing)
	var start_z: float = _center_z - _total_length * 0.5 + 1.0
	for tone: int in colors.size():
		var boards: MultiMesh = MultiMesh.new()
		boards.transform_format = MultiMesh.TRANSFORM_3D
		var board: BoxMesh = BoxMesh.new()
		board.size = Vector3(0.03, 0.26, 1.7)
		boards.mesh = board
		var transforms: Array[Transform3D] = []
		for i: int in count:
			for s: int in 2:
				if (i * 2 + s) % colors.size() != tone:
					continue
				var side: float = 1.0 if s == 0 else -1.0
				var x: float = (ASPHALT_WIDTH * 0.5 + 1.05 - 0.145) * side
				transforms.append(Transform3D(Basis.IDENTITY,
					Vector3(x, 0.24, start_z + float(i) * spacing)))
		boards.instance_count = transforms.size()
		for i: int in transforms.size():
			boards.set_instance_transform(i, transforms[i])
		_multi(boards, colors[tone])


## Mesafe levhaları (100 m · 200 m): oyuncu yarışın neresinde olduğunu pistte de görsün.
func _build_distance_boards() -> void:
	for meters: int in [100, 200]:
		var z: float = length * float(meters) / DragRaceSim.DISTANCE
		var x: float = ASPHALT_WIDTH * 0.5 + 0.82
		_box(Vector3(0.08, 0.9, 0.08), Vector3(x, 0.45, z), STEEL)
		_box(Vector3(0.06, 0.42, 0.9), Vector3(x, 1.02, z), Color("F3E8CF"))
		var label: Label3D = Label3D.new()
		label.text = "%d m" % meters
		label.font_size = 64
		label.pixel_size = 0.0045
		label.modulate = Color("2F3236")
		label.outline_size = 0
		label.position = Vector3(x - 0.04, 1.02, z)
		label.rotation_degrees = Vector3(0.0, -90.0, 0.0)
		add_child(label)


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
