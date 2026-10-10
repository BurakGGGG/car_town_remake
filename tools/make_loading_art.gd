extends SceneTree
## YÜKLEME EKRANI GÖRSELİNİ OYUNUN KENDİ VARLIKLARIYLA ÇİZER → ui/loading/loading_bg.png (2400×1080).
## Sahne: koyu garaj iç mekânı, makaslı tamir liftinde başlangıç aracı (Tofaş Şahin), takım dolabı,
## kompresör, variller, lastikler, parlayan teslimat kasası, drag çıkış ışığı ve damalı bayrak; tavandan
## sarkan iki lamba; üstte "AUTO YARD" plakası (oyunun krem plaka dili); altta ~200 px sakin şerit
## (yükleme çubuğu ve ipuçları orada). 2× boyutta çizilip küçültülür (kenar yumuşatma).
## Kullanım: godot-4 --path . --resolution 960x432 -s res://tools/make_loading_art.gd [-- önizleme]
## "önizleme" verilirse yarım çözünürlükte ~/Projects/ct_shots/loading_art_preview.png yazar.
## Sonra açılış ekranına bağlamak için: godot-4 --headless --path . -s res://tools/make_loading_scene.gd

const OUT: String = "res://ui/loading/loading_bg.png"
## Oyunun logosu (saydam PNG). Varsa üstte o kullanılır; yoksa krem plaka tabela (Sign) çizilir.
const LOGO: String = "res://assets/branding/autoyard_logo.png"
const PREVIEW: String = "/home/burak/Projects/ct_shots/loading_art_preview.png"
const FINAL_SIZE: Vector2i = Vector2i(2400, 1080)
const BG: Color = Color("1E2124")
const AMBER: Color = Color("F5BE4C")
const CREAM: Color = Color("F3E8CF")
const CREAM_EDGE: Color = Color("B9A67C")
const INK: Color = Color("2F3236")
## Kameranın açısı (izometrik): düz quad'lar bu dönüşle kameraya bakar.
const FACE_CAMERA: Vector3 = Vector3(-30.0, 45.0, 0.0)
## Işıma noktaları (dünya konumu, dünya boyu, renk): 3D quad değil, 2D katmanda katkılı sprite olarak
## çizilir. GL Compatibility gölgeli ışıklı sahnede katkılı quad'ın doku saydamlığını kaybedip onu
## KARE çiziyordu (ışık katmanını ayırmak da çözmedi).
var _glows: Array[Array] = []

var _viewport: SubViewport
var _world: Node3D
var _scale: int = 2


## Asılı plaka: krem zemin, koyu kenar, amber iç çizgi, dört cıvata, koyu yazı (oyunun plaka dili).
class Sign extends Control:
	var title: String = "AUTO YARD"
	var font: Font
	var font_size: int = 200
	var unit: float = 1.0

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		var shadow: StyleBoxFlat = StyleBoxFlat.new()
		shadow.bg_color = Color(0, 0, 0, 0.35)
		shadow.set_corner_radius_all(int(22 * unit))
		draw_style_box(shadow, Rect2(r.position + Vector2(0, 10 * unit), r.size))
		var plate: StyleBoxFlat = StyleBoxFlat.new()
		plate.bg_color = CREAM
		plate.border_color = CREAM_EDGE
		plate.set_border_width_all(int(5 * unit))
		plate.border_width_bottom = int(11 * unit)
		plate.set_corner_radius_all(int(22 * unit))
		draw_style_box(plate, r)
		var inner: StyleBoxFlat = StyleBoxFlat.new()
		inner.draw_center = false
		inner.border_color = AMBER
		inner.set_border_width_all(int(4 * unit))
		inner.set_corner_radius_all(int(12 * unit))
		draw_style_box(inner, r.grow(-22 * unit))
		for corner: Vector2 in [Vector2(40, 40), Vector2(size.x / unit - 40, 40), Vector2(40, size.y / unit - 48),
				Vector2(size.x / unit - 40, size.y / unit - 48)]:
			draw_circle(corner * unit, 11 * unit, Color(INK, 0.55))
			draw_circle(corner * unit, 7 * unit, Color("CFC6B2"))
			draw_line((corner + Vector2(-5, -5)) * unit, (corner + Vector2(5, 5)) * unit, Color(INK, 0.6), 2.5 * unit)
		# Yazı: iki sözcük, arada amber altıgen somun
		var words: PackedStringArray = title.split(" ")
		var gap: float = 110 * unit
		var widths: Array[float] = []
		var total: float = gap * float(words.size() - 1)
		for word: String in words:
			var w: float = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			widths.append(w)
			total += w
		var x: float = (size.x - total) * 0.5
		var baseline: float = size.y * 0.5 + font.get_ascent(font_size) * 0.36 - 4 * unit
		for i: int in words.size():
			draw_string(font, Vector2(x + 5 * unit, baseline + 7 * unit), words[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("D8B66A"))
			draw_string(font, Vector2(x, baseline), words[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, INK)
			x += widths[i]
			if i < words.size() - 1:
				_hex_nut(Vector2(x + gap * 0.5, size.y * 0.5 - 4 * unit), 26 * unit)
				x += gap

	func _hex_nut(center: Vector2, radius: float) -> void:
		var points: PackedVector2Array = PackedVector2Array()
		for k: int in 6:
			var a: float = TAU * float(k) / 6.0
			points.append(center + Vector2(cos(a), sin(a)) * radius)
		draw_colored_polygon(points, AMBER)
		draw_polyline(points + PackedVector2Array([points[0]]), Color("B27A1C"), 3.0 * unit, true)
		draw_circle(center, radius * 0.42, INK)
		draw_circle(center, radius * 0.26, AMBER)


func _initialize() -> void:
	var preview: bool = OS.get_cmdline_user_args().has("önizleme")
	_scale = 1 if preview else 2
	_run.call_deferred(preview)


func _run(preview: bool) -> void:
	var size: Vector2i = FINAL_SIZE * _scale
	_viewport = SubViewport.new()
	_viewport.size = size
	_viewport.own_world_3d = true
	_viewport.transparent_bg = false
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.positional_shadow_atlas_size = 4096
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_world = Node3D.new()
	_viewport.add_child(_world)
	_build_environment()
	_build_room()
	_build_props()
	_build_overlay(Vector2(size))
	for i: int in 90:   # lift kalkışı, kasa gelişi, parçacıklar otursun
		await process_frame
	_seat_car_on_lift()
	if preview:
		_report_overlaps()
	for i: int in 4:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	var image: Image = _viewport.get_texture().get_image()
	if _scale != 1:
		image.resize(FINAL_SIZE.x, FINAL_SIZE.y, Image.INTERPOLATE_LANCZOS)
	var target: String = PREVIEW if preview else ProjectSettings.globalize_path(OUT)
	image.save_png(target)
	print("KAYDEDİLDİ ", target, " ", image.get_size())
	quit(0)


# --- Ortam ----------------------------------------------------------------------------

func _build_environment() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = BG
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("8C98A8")
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.6
	e.glow_bloom = 0.08
	env.environment = e
	_world.add_child(env)
	# Soğuk, zayıf dolgu ışığı (şekiller okunur); asıl ışık lambalardan
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-60.0, -30.0, 0.0)
	fill.light_color = Color("A9B8CC")
	fill.light_energy = 0.32
	fill.shadow_enabled = true
	_world.add_child(fill)
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.rotation_degrees = Vector3(-30.0, 45.0, 0.0)   # oyunun izometrik açısı
	camera.size = 1.62
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	# Odak sahnenin biraz altında: üstte tabela, altta sakin şerit için yer kalsın
	camera.position = Vector3(0.0, 0.42, -0.1) + camera.basis.z * 12.0
	camera.far = 40.0
	_world.add_child(camera)


## Koyu karo zemin + iki arka duvar (sağdakinde sarma kepenk) + duvar dibinde süpürgelik.
## Duvarlar yakın (WALL): garaj dolu, sıkı bir atölye gibi görünsün.
const WALL: float = 1.2


func _build_room() -> void:
	var floor_mat: StandardMaterial3D = _mat(Color("2A2E33"), 0.9)
	floor_mat.albedo_texture = _tile_texture()
	floor_mat.uv1_scale = Vector3(7.0, 7.0, 1.0)
	_box(Vector3(6.0, 0.05, 6.0), Vector3(0.0, -0.025, 0.0), floor_mat)
	var wall: StandardMaterial3D = _mat(Color("30353C"), 0.95)
	_box(Vector3(0.08, 1.3, 6.0), Vector3(-WALL - 0.04, 0.65, 0.0), wall)     # sol arka duvar
	_box(Vector3(6.0, 1.3, 0.08), Vector3(0.0, 0.65, -WALL - 0.04), wall)     # sağ arka duvar
	var trim: StandardMaterial3D = _mat(Color("3E444C"), 0.8)
	_box(Vector3(0.06, 0.07, 6.0), Vector3(-WALL + 0.03, 0.035, 0.0), trim)
	_box(Vector3(6.0, 0.07, 0.06), Vector3(0.0, 0.035, -WALL + 0.03), trim)
	# Sarma kepenk: sağ arka duvarda, yatay çıtalar
	var shutter: StandardMaterial3D = _mat(Color("4A5058"), 0.6, 0.4)
	for i: int in 12:
		_box(Vector3(0.95, 0.05, 0.03), Vector3(0.05, 0.08 + float(i) * 0.062, -WALL + 0.005), shutter)
	_box(Vector3(1.08, 0.1, 0.08), Vector3(0.05, 0.84, -WALL + 0.02), _mat(Color("2B2F35"), 0.7))


var _bay_car: Node3D
var _bay_lift: RepairLift


func _build_props() -> void:
	# Ortada: makaslı tamir lifti + üstünde Tofaş Şahin (oyunun tamir alanı), önü kameraya
	var bay: Node3D = Node3D.new()
	bay.position = Vector3(-0.05, 0.0, 0.1)
	bay.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	bay.scale = Vector3.ONE * 1.35
	bay.name = "lift"
	bay.set_meta(&"zemin_esyasi", true)
	_world.add_child(bay)
	_bay_lift = RepairLift.new()
	bay.add_child(_bay_lift)
	_bay_car = _car(&"tofas_sahin")
	_bay_car.scale = Vector3.ONE * 0.6 * CarCatalog.model_scale(&"tofas_sahin")
	bay.add_child(_bay_car)
	_bay_lift.raise(_bay_car)
	var w: float = WALL
	# Sol duvar boyunca: tezgâh, takım dolabı; duvarda alet panosu, raf, lamba, poster
	_decor(&"workbench", Vector3(-w + 0.16, 0.0, 0.0), 90.0, 1.45)
	_decor(&"tool_cabinet", Vector3(-w + 0.16, 0.0, -0.62), 90.0, 1.5)
	_decor(&"tyre_rack", Vector3(-w + 0.2, 0.0, 0.55), 90.0, 1.35)
	_wall(&"pegboard", Vector3(-w, 0.52, 0.02), 90.0, 1.4)
	_wall(&"wall_shelf", Vector3(-w, 0.82, -0.6), 90.0, 1.4)
	_wall(&"wall_lamp", Vector3(-w, 0.95, 0.45), 90.0, 1.3)
	_wall(&"poster_vintage", Vector3(-w, 0.62, 0.72), 90.0, 1.3)
	_wall(&"extinguisher_wall", Vector3(-w, 0.35, 1.1), 90.0, 1.3)
	_wall(&"neon_bolt", Vector3(-w, 0.98, 1.05), 90.0, 1.3)
	_wall_banner(Vector3(-w + 0.005, 0.95, -0.15))
	# Sağ duvar boyunca: kompresör, alet arabası, palet; duvarda lamba, tabela, saat
	_decor(&"compressor", Vector3(-0.7, 0.0, -w + 0.2), 0.0, 1.45)
	_decor(&"tool_trolley", Vector3(-1.0, 0.0, -w + 0.2), 0.0, 1.3)
	_decor(&"pallet_stack", Vector3(0.96, 0.0, -w + 0.22), 0.0, 1.3)
	_wall(&"sign_service", Vector3(-0.62, 0.72, -w), 0.0, 1.3)
	_wall(&"wall_clock", Vector3(0.62, 1.02, -w), 0.0, 1.2)
	_wall(&"neon_open", Vector3(1.32, 0.95, -w), 0.0, 1.35)
	_wall(&"tyre_hanger", Vector3(1.75, 0.55, -w), 0.0, 1.35)
	_wall(&"wall_lamp", Vector3(-0.25, 0.98, -w), 0.0, 1.3)
	# Ön sol zemin: variller, lastik yığını, kriko
	_decor(&"oil_drums", Vector3(-0.85, 0.0, 0.95), 90.0, 1.3)
	_decor(&"tyre_pile", Vector3(-0.42, 0.0, 1.0), 0.0, 1.4)
	_decor(&"jerry_cans", Vector3(-0.98, 0.0, 1.22), 90.0, 1.3)
	# Sağ: parlayan teslimat kasası (kepengin önünde)
	var crate: CrateVisual = CrateVisual.new()
	crate.setup(&"city_crate", 0)
	crate.set_tag_visible(false)
	crate.position = Vector3(0.55, 0.0, -0.62)
	crate.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	crate.scale = Vector3.ONE * 0.92
	crate.name = "kasa"
	crate.set_meta(&"zemin_esyasi", true)
	_world.add_child(crate)
	_crate_glow(crate.position, 0.92)
	# Liftin solunda, geride: drag çıkış ışığı (pano sağa, araca doğru bakar); önde koniler
	_start_tree(Vector3(-0.75, 0.0, 0.45), 0.58)
	_decor(&"traffic_cones", Vector3(1.05, 0.0, 0.12), 30.0, 1.15)
	_decor(&"parts_shelf", Vector3(1.3, 0.0, -w + 0.2), 0.0, 1.35)
	# Tavandan sarkan iki lamba: aracın ve kasanın üstünde sıcak koniler
	_hanging_lamp(Vector3(-0.05, 1.45, 0.1), 2.3)
	_hanging_lamp(Vector3(0.55, 1.4, -0.62), 0.85)


## Önizlemede zemin eşyalarının yerdeki izdüşümleri (XZ) karşılaştırılır; iç içe geçenler yazdırılır
## (gözle fark edilmeyen çakışmalar: palet kasanın, alet arabası dolabın içindeydi).
func _report_overlaps() -> void:
	var props: Array[Node3D] = []
	for child: Node in _world.get_children():
		if child.has_meta(&"zemin_esyasi"):
			props.append(child)
	var boxes: Array[Rect2] = []
	for prop: Node3D in props:
		var merged: Rect2 = Rect2()
		var first: bool = true
		for node: Node in prop.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = node
			if not mi.is_visible_in_tree() or mi.mesh == null:
				continue
			var box: AABB = mi.global_transform * mi.get_aabb()
			var flat: Rect2 = Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
			merged = flat if first else merged.merge(flat)
			first = false
		boxes.append(merged)
		print("İZ %-14s x %.2f..%.2f  z %.2f..%.2f" % [prop.name, merged.position.x, merged.end.x, merged.position.y, merged.end.y])
	for i: int in props.size():
		for j: int in range(i + 1, props.size()):
			var cut: Rect2 = boxes[i].intersection(boxes[j])
			if cut.get_area() > 0.0004:
				print("ÇAKIŞMA %s ↔ %s (%.2f × %.2f)" % [props[i].name, props[j].name, cut.size.x, cut.size.y])


## Liftteki aracın tekerleri raylara tam otursun: lift kalkışı bittikten sonra aracın en alt noktası
## ölçülür ve liftin ray üstüne hizalanır (modelin kökü teker altında değil; teker raya gömülüyordu).
func _seat_car_on_lift() -> void:
	if _bay_car == null or _bay_lift == null:
		return
	var lowest: float = INF
	for node: Node in _bay_car.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var box: AABB = mi.global_transform * mi.get_aabb()
		lowest = minf(lowest, box.position.y)
	if lowest == INF:
		return
	# Ray üst yüzeyi doğrudan ray meshlerinden ölçülür: lift sahnede ölçekli, car_y() ölçeksiz yerel
	# değerle hesaplıyor (teker yine gömülüyordu).
	var runway_top: float = -INF
	var platform: Node3D = _bay_lift.get("_platform")
	for node: Node in platform.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		runway_top = maxf(runway_top, (mi.global_transform * mi.get_aabb()).end.y)
	_bay_car.global_position.y += runway_top - lowest


func _car(id: StringName) -> Node3D:
	var car: Node3D = (load(CarCatalog.scene_path(id)) as PackedScene).instantiate()
	var rig: CarRig = CarRig.for_node(car)
	rig.apply(CarAppearance.get_for(CarCatalog.scene_path(id)))
	rig.set_lod_bias(CarRig.LOD_BIAS_GARAGE)
	return car


func _decor(id: StringName, pos: Vector3, yaw: float, size_scale: float) -> void:
	var body: Node3D = DecorBuilder.build_placeable(id)
	if body == null:
		return
	body.position = pos
	body.rotation_degrees = Vector3(0.0, yaw, 0.0)
	body.scale = Vector3.ONE * GarageDecorView.WORLD_SCALE * size_scale
	body.name = String(id)
	body.set_meta(&"zemin_esyasi", true)
	_world.add_child(body)


## Kasanın içinden sızan amber ışık: iç ışık, kasanın üstünde yumuşak bir ışıma halesi ve havada
## süzülen küçük ışık zerreleri (eski keskin ışın şeritleri "amatör" duruyordu).
func _crate_glow(at: Vector3, k: float) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = AMBER
	light.light_energy = 0.95
	light.omni_range = 1.0
	light.position = at + Vector3(0.0, 0.55 * k, 0.0)
	_world.add_child(light)
	_glows.append([at + Vector3(0.0, 0.42 * k, 0.0), 1.15 * k, Color(AMBER.lightened(0.25), 0.34)])
	# Süzülen zerreler: elle dağıtılmış (rastgele değil: her çizimde aynı görsel)
	var motes: Array[Vector4] = [   # x, y, z (kasa uzayında), boy
		Vector4(-0.18, 0.62, 0.05, 0.05), Vector4(0.12, 0.74, -0.08, 0.035), Vector4(0.25, 0.58, 0.1, 0.04),
		Vector4(-0.05, 0.88, 0.02, 0.03), Vector4(0.2, 0.95, -0.02, 0.025), Vector4(-0.26, 0.82, -0.06, 0.03),
		Vector4(0.02, 1.05, 0.06, 0.022), Vector4(-0.14, 1.12, -0.04, 0.02)]
	for m: Vector4 in motes:
		_glows.append([at + Vector3(m.x, m.y, m.z) * k, m.w * k * 1.8, Color(1.0, 0.88, 0.55, 0.85)])


## Drag çıkış ışığı ("christmas tree"): koyu kaide ve direk, üstte iki şerit sütunlu lamba panosu.
## Her sütunda: iki küçük beyaz STAGE lambası, üç amber, bir yeşil (yanık), bir kırmızı (sönük).
## Lambalar yuvalı (koyu siperlik + parlayan mercek). Nokta ışık yok: panoyu
## ve direği renge boyuyordu.
func _start_tree(at: Vector3, k: float, yaw: float = 100.0) -> void:
	var tree: Node3D = Node3D.new()
	tree.position = at
	# 100°: pano sağa (araca) bakar ama kameradan hâlâ görünür (135° tam yandan, çizgi gibi kalır)
	tree.rotation_degrees = Vector3(0.0, yaw, 0.0)
	tree.scale = Vector3.ONE * k
	tree.name = "cikis_isigi"
	tree.set_meta(&"zemin_esyasi", true)
	_world.add_child(tree)
	var dark: StandardMaterial3D = _mat(Color("23262A"), 0.55, 0.3)
	var metal: StandardMaterial3D = _mat(Color("5B6168"), 0.4, 0.7)
	_part(tree, Vector3(0.3, 0.05, 0.3), Vector3(0.0, 0.025, 0.0), metal)                  # kaide
	_part(tree, Vector3(0.05, 0.62, 0.05), Vector3(0.0, 0.33, 0.0), metal)                  # direk
	_part(tree, Vector3(0.3, 0.6, 0.06), Vector3(0.0, 0.94, 0.0), dark)                     # pano
	_part(tree, Vector3(0.34, 0.035, 0.08), Vector3(0.0, 1.255, 0.0), _mat(AMBER, 0.5))     # üst şerit
	_part(tree, Vector3(0.02, 0.56, 0.065), Vector3(0.0, 0.94, 0.0), metal)                 # orta ayırıcı
	var green: Color = Color("5FD36A")
	var rows: Array = [   # [y, renk, yarıçap, yanık mı]
		[1.2, Color("F4F1E6"), 0.018, true], [1.16, Color("F4F1E6"), 0.018, true],
		[1.1, AMBER, 0.032, true], [1.02, AMBER, 0.032, true], [0.94, AMBER, 0.032, true],
		[0.86, green, 0.034, true], [0.77, Color("E2483D"), 0.032, false]]
	for column: float in [-0.075, 0.075]:
		for row: Array in rows:
			var color: Color = row[1]
			var radius: float = row[2]
			var lit: bool = row[3]
			var hood: MeshInstance3D = MeshInstance3D.new()    # siperlik
			var cyl: CylinderMesh = CylinderMesh.new()
			cyl.top_radius = radius * 1.35
			cyl.bottom_radius = radius * 1.35
			cyl.height = 0.03
			cyl.radial_segments = 16
			hood.mesh = cyl
			hood.material_override = dark
			hood.rotation_degrees = Vector3(90.0, 0.0, 0.0)
			hood.position = Vector3(column, row[0], 0.04)
			tree.add_child(hood)
			var lens: MeshInstance3D = MeshInstance3D.new()     # mercek
			var sphere: SphereMesh = SphereMesh.new()
			sphere.radius = radius
			sphere.height = radius * 2.0
			sphere.radial_segments = 16
			sphere.rings = 8
			lens.mesh = sphere
			var m: StandardMaterial3D = _mat(color if lit else color.darkened(0.6), 0.25)
			if lit:
				m.emission_enabled = true
				m.emission = color
				m.emission_energy_multiplier = 0.75 if color == green else 0.45
			lens.material_override = m
			lens.position = Vector3(column, row[0], 0.05)
			tree.add_child(lens)
			if lit:   # mercek halesi: 2D katmanda katkılı ışıma (bkz. _glows)
				_glows.append([tree.transform * lens.position, radius * k * 6.0, Color(color.lightened(0.15), 0.75)])


func _part(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> void:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	mesh.material_override = material
	parent.add_child(mesh)


## Sol duvara asılı damalı pankart (drag yarışı göndermesi): duvara yaslı, +X'e bakar.
func _wall_banner(at: Vector3) -> void:
	var cloth: StandardMaterial3D = _mat(Color.WHITE, 0.85)
	cloth.albedo_texture = _checker_texture()
	var banner: MeshInstance3D = MeshInstance3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.5, 0.34)
	banner.mesh = quad
	banner.material_override = cloth
	banner.position = at
	banner.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	_world.add_child(banner)
	_box(Vector3(0.03, 0.03, 0.58), at + Vector3(0.01, 0.185, 0.0), _mat(Color("7A8088"), 0.4, 0.6))


## Duvar eşyası (oyunun dekorundan): `yaw` 90 = sol duvar (odaya +X), 0 = sağ duvar (+Z).
func _wall(id: StringName, at: Vector3, yaw: float, size_scale: float) -> void:
	var body: Node3D = DecorBuilder.build_placeable(id)
	if body == null:
		print("eşya yok: ", id)
		return
	body.position = at
	body.rotation_degrees = Vector3(0.0, yaw, 0.0)
	body.scale = Vector3.ONE * GarageDecorView.WORLD_SCALE * size_scale
	_world.add_child(body)


func _wall_decor(id: StringName, at: Vector3, size_scale: float) -> void:
	var body: Node3D = DecorBuilder.build_placeable(id)
	if body == null:
		return
	body.position = at
	body.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	body.scale = Vector3.ONE * GarageDecorView.WORLD_SCALE * size_scale
	_world.add_child(body)


func _hanging_lamp(at: Vector3, energy: float) -> void:
	var dark: StandardMaterial3D = _mat(Color("25282C"), 0.6)
	_box(Vector3(0.01, 0.6, 0.01), at + Vector3(0, 0.3, 0), dark)
	var shade: MeshInstance3D = MeshInstance3D.new()
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.03
	cone.bottom_radius = 0.13
	cone.height = 0.12
	shade.mesh = cone
	shade.material_override = dark
	shade.position = at
	_world.add_child(shade)
	var bulb: MeshInstance3D = MeshInstance3D.new()
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = 0.11
	disc.bottom_radius = 0.11
	disc.height = 0.01
	bulb.mesh = disc
	var glow: StandardMaterial3D = _mat(Color("FFE7A8"), 0.4)
	glow.emission_enabled = true
	glow.emission = Color("FFD98A")
	glow.emission_energy_multiplier = 3.0
	bulb.material_override = glow
	bulb.position = at + Vector3(0, -0.062, 0)
	_world.add_child(bulb)
	# Görünür ışık konisi (sisli atölye havası): saydam, eklemeli, aşağı doğru sönen
	var beam: MeshInstance3D = MeshInstance3D.new()
	var cone_mesh: CylinderMesh = CylinderMesh.new()
	cone_mesh.top_radius = 0.1
	cone_mesh.bottom_radius = 0.75
	cone_mesh.height = at.y - 0.08
	cone_mesh.cap_top = false
	cone_mesh.cap_bottom = false
	cone_mesh.radial_segments = 24
	beam.mesh = cone_mesh
	# Normal karışım, tek yüz, çok düşük opaklık: eklemeli + çift yüz + ışıma koniyi dolu beyaza
	# çeviriyordu (önizleme karesi).
	var beam_mat: StandardMaterial3D = StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.albedo_texture = _beam_fade_texture()
	beam_mat.albedo_color = Color("FFE2B0", 0.11)
	beam_mat.cull_mode = BaseMaterial3D.CULL_BACK
	beam_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	beam.material_override = beam_mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position = Vector3(at.x, (at.y - 0.08) * 0.5, at.z)
	_world.add_child(beam)
	var spot: SpotLight3D = SpotLight3D.new()
	spot.light_color = Color("FFD9A0")
	spot.light_energy = energy
	spot.spot_range = 3.5
	spot.spot_angle = 34.0
	spot.spot_attenuation = 0.8
	spot.shadow_enabled = true
	spot.position = at + Vector3(0, -0.08, 0)
	spot.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_world.add_child(spot)


# --- 2D katman: tabela, alt şerit, kenar karartma ------------------------------------------

func _build_overlay(size: Vector2) -> void:
	var unit: float = float(_scale)
	var layer: Control = Control.new()
	layer.size = size
	layer.theme = load("res://ui/theme/hud_theme.tres")
	_viewport.add_child(layer)
	# Işıma noktaları: dünya konumu ekrana izdüşürülür (ortografik: piksel/birim = yükseklik/size)
	var camera: Camera3D = _viewport.get_camera_3d()
	var px_per_unit: float = size.y / camera.size
	var glow_texture: ImageTexture = _glow_texture()
	var add_blend: CanvasItemMaterial = CanvasItemMaterial.new()
	add_blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for glow: Array in _glows:
		var sprite: TextureRect = TextureRect.new()
		sprite.texture = glow_texture
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_SCALE
		sprite.material = add_blend
		sprite.modulate = glow[2]
		var side: float = float(glow[1]) * px_per_unit
		sprite.size = Vector2(side, side)
		sprite.position = camera.unproject_position(glow[0]) - sprite.size * 0.5
		layer.add_child(sprite)
	# Kenar karartma (vinyet) + alttaki sakin şerit: aşağı doğru zemin rengine erir
	var vignette: TextureRect = TextureRect.new()
	vignette.texture = _vignette_texture()
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.size = size
	layer.add_child(vignette)
	var fade: TextureRect = TextureRect.new()
	fade.texture = _fade_texture()
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.position = Vector2(0.0, size.y * 0.66)
	fade.size = Vector2(size.x, size.y * 0.34)
	layer.add_child(fade)
	if ResourceLoader.exists(LOGO):
		# Logo: üstte ortada, ekran genişliğinin ~%55'i (güvenli alanın içinde)
		var logo: TextureRect = TextureRect.new()
		logo.texture = load(LOGO)
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var logo_size: Vector2 = Vector2(1320.0, 1320.0 * 475.0 / 2048.0) * unit
		logo.size = logo_size
		logo.position = Vector2((size.x - logo_size.x) * 0.5, 26.0 * unit)
		layer.add_child(logo)
		return
	# Asılı tabela (logo yoksa): iki zincir + plaka
	var sign_size: Vector2 = Vector2(820.0, 170.0) * unit
	var sign_pos: Vector2 = Vector2((size.x - sign_size.x) * 0.5, 50.0 * unit)
	for side: float in [0.16, 0.84]:
		var chain: ColorRect = ColorRect.new()
		chain.color = Color("15171A")
		chain.position = Vector2(sign_pos.x + sign_size.x * side - 2.0 * unit, 0.0)
		chain.size = Vector2(4.0 * unit, sign_pos.y + 12.0 * unit)
		layer.add_child(chain)
	var sign: Sign = Sign.new()
	sign.font = ThemeDB.fallback_font
	var bold: FontVariation = FontVariation.new()
	bold.base_font = ThemeDB.fallback_font
	bold.variation_embolden = 1.2
	sign.font = bold
	sign.font_size = int(96 * unit)
	sign.unit = unit
	sign.position = sign_pos
	sign.size = sign_size
	layer.add_child(sign)


# --- Yardımcılar ------------------------------------------------------------------------

func _box(size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	mesh.material_override = material
	_world.add_child(mesh)
	return mesh


func _mat(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m


func _tile_texture() -> ImageTexture:
	var image: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1))
	for i: int in 64:
		for edge: int in [0, 63]:
			image.set_pixel(i, edge, Color(0.78, 0.8, 0.84))
			image.set_pixel(edge, i, Color(0.78, 0.8, 0.84))
	return ImageTexture.create_from_image(image)


func _checker_texture() -> ImageTexture:
	var image: Image = Image.create(64, 96, false, Image.FORMAT_RGBA8)
	for y: int in 96:
		for x: int in 64:
			var dark: bool = (x / 16 + y / 16) % 2 == 0
			image.set_pixel(x, y, Color(0.12, 0.12, 0.13) if dark else Color(0.93, 0.92, 0.88))
	return ImageTexture.create_from_image(image)


## Yumuşak ışık noktası: merkezde opak, kenara doğru sönen (piksel piksel; gecikmeli üretilen
## GradientTexture2D'ye bağlı kalınmaz — tek karelik render'da hazır olmayabiliyor).
func _glow_texture() -> ImageTexture:
	var image: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y: int in 64:
		for x: int in 64:
			var d: float = Vector2(float(x) - 31.5, float(y) - 31.5).length() / 32.0
			image.set_pixel(x, y, Color(1, 1, 1, pow(clampf(1.0 - d, 0.0, 1.0), 1.8)))
	return ImageTexture.create_from_image(image)


## Kasa ışını: yanlara ve yukarı doğru yumuşakça sönen hüzme (keskin kenar yok).
func _ray_texture() -> ImageTexture:
	var image: Image = Image.create(32, 128, false, Image.FORMAT_RGBA8)
	for y: int in 128:
		for x: int in 32:
			var across: float = 1.0 - absf(float(x) - 15.5) / 16.0
			var along: float = float(y) / 127.0   # üst 0 → alt 1 (alt parlak)
			image.set_pixel(x, y, Color(1, 1, 1, pow(across, 2.2) * along * along))
	return ImageTexture.create_from_image(image)


## Işık konisi: üstte parlak, aşağı doğru saydamlaşan dikey gradyan (silindir UV'si üstten aşağı).
func _beam_fade_texture() -> GradientTexture2D:
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0.15))
	var t: GradientTexture2D = GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0.5, 0.0)
	t.fill_to = Vector2(0.5, 1.0)
	t.width = 8
	t.height = 64
	return t


func _vignette_texture() -> GradientTexture2D:
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(BG, 0.0))
	g.set_color(1, Color(BG, 0.85))
	g.add_point(0.55, Color(BG, 0.0))
	var t: GradientTexture2D = GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.42)
	t.fill_to = Vector2(1.08, 0.42)
	t.width = 512
	t.height = 256
	return t


func _fade_texture() -> GradientTexture2D:
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(BG, 0.0))
	g.set_color(1, Color(BG, 1.0))
	g.add_point(0.55, Color(BG, 0.92))
	var t: GradientTexture2D = GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0.5, 0.0)
	t.fill_to = Vector2(0.5, 1.0)
	t.width = 8
	t.height = 256
	return t
