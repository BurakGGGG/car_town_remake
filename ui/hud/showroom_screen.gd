class_name ShowroomScreen
extends Control
## MAĞAZA — tam ekran showroom (alt sekmedeki MAĞAZA ile aynı yer). Haritadaki "CAR PARTS & SHOWROOM" binasına tıklayınca açılır
## (shop_hitbox.gd).
##
## KASA SİSTEMİ (docs/vehicle_crate_design_v2.md): burada artık ARAÇ SATILMAZ. Sol listede dört
## ARAÇ TESLİMAT KASASI (ŞEHİR / AİLE / SPOR / PRESTİJ, gem ile) durur; seçilen kasanın modeli
## platformda döner, sağ plakada fiyatı, seviye şartı ve havuzundaki HER aracın gerçek olasılığı
## yazar. Satın alınan kasa garajın teslimat alanına FİZİKSEL olarak gelir (CrateManager +
## CrateDelivery); showroom kapanır, kamera kasaya gider. Listenin altındaki GERİ AL bölümü yalnızca
## daha önce keşfedilmiş ama satılmış araçları ₺ ile geri satar.
##
## Garaj ekranının çalışan düzenini örnek alır ama daha lüks bir mekân kurar: kendi 3D dünyası
## (SubViewport), koyu showroom zemini, ışıklı sergi platformu, spot ışıklar, cam/ahşap/metal duvar
## detayları ve merkezde TEK araç. Plakalar (krem zemin, koyu alt kenar, vida, kalın yazı) mevcut
## tema varyasyonlarından gelir — yeni generic kart tasarımı yoktur.
##
## Sergilenen araç VehicleDisplayRoot altında durur: 360° dönüş bu kökü döndürür, modelin kendi
## parçalarına dokunulmaz. Parmakla/fare ile yatay sürükleme döndürür, bırakınca kısa süre sonra
## otomatik dönüş devam eder; tekerlek / pinch yakınlaştırır (kamera araca giremez).
##
## Backend aynen mevcut sistemlerdir: araç verisi CarCatalog, sahiplik VehicleOwnership
## (purchase_vehicle), para EconomyManager, kalıcılık SaveManager. Burada yeni satın alma / ekonomi
## mantığı YOKTUR. Önizleme yalnızca görseldir: TrafficManager'a, RepairManager'a, CarHitbox'a
## ve dünyaya hiç girmez; ekran kapanınca model serbest bırakılır.

signal opened
signal closed
signal vehicle_purchased(vehicle_id: StringName)
## Kasa satın alındı (HUD showroom'u kapatıp kamerayı teslimat alanına götürür).
signal crate_purchased(uid: int)
## Başka bir pano istendi (KOLEKSİYON).
signal screen_requested(id: StringName)

const TITLE: String = "MAĞAZA"
const LIST_WIDTH: float = 188.0
const INFO_WIDTH: float = 250.0   # kasa oran satırları (nadirlik · model · yüzde) tek satıra sığsın
const SLIDE: float = 18.0

# --- 3D sahne ölçüleri (araç ~1 birim uzunlukta) ---
const PLATFORM_HEIGHT: float = 0.08
const WALL_Z: float = -7.0        # arka duvar: araçtan uzakta (derinlik hissi)
const WALL_X: float = -13.5      # sol duvar (kadrajın dışında; cam cepheyi kapatmasın)
const CEILING_Y: float = 2.9      # yüksek tavan (kadrajın üst kenarında görünür)
const SIGN_X: float = -3.4        # kameranın tam karşısına gelen duvar noktası

# --- Kamera ---
const CAM_FOV: float = 42.0       # geniş kadraj: mekân aracın arkasında açılsın
const CAM_AZIMUTH: float = 26.0   # derece (araç döndüğü için sabit)
const CAM_ELEVATION: float = 9.0
const ZOOM_MIN: float = 0.62
const ZOOM_MAX: float = 1.55
const ZOOM_STEP: float = 0.09
const ZOOM_SMOOTH: float = 12.0

# --- Dönüş ---
const DRAG_TO_RAD: float = 0.0085          # piksel → radyan
const AUTO_SPEED: float = 11.0             # derece/sn
const AUTO_RESUME: float = 1.1             # elini çektikten kaç sn sonra kendi döner
const SPIN_DAMPING: float = 5.0            # sürükleme bırakılınca kalan hızın sönümü

var _view: SubViewportContainer
var _viewport: SubViewport
var _camera: Camera3D
var _display_root: Node3D                  # 360° dönüş bunu döndürür
var _model_slot: Node3D                    # modeli platforma oturtan kaydırma
var _platform: MeshInstance3D              # üst tabla (açık gri)
var _platform_base: MeshInstance3D         # koyu metal kaide
var _platform_rim: MeshInstance3D          # ince amber ışık bandı
var _blob: MeshInstance3D                  # araç altı yumuşak gölge

var _title_group: HBoxContainer
var _list_group: VBoxContainer
var _info_group: VBoxContainer
var _exit_group: HBoxContainer
var _list_box: VBoxContainer
var _info_plate: PurchasePlate
var _buy_button: PlateButton
var _exit_button: PlateButton

var _plates: Dictionary = {}               # "crate:<id>" / "car:<id>" → PlateButton
var _shown_crate: StringName = &""         # platformdaki kasa (araç gösteriliyorsa &"")
var _closing_after_buy: bool = false       # satın alındı, showroom kapanıyor: buton kilitli kalır
var _crates: CrateManager
var _progress: PlayerProgress
var _group: ButtonGroup = ButtonGroup.new()
var _shown_vehicle: StringName = &""
var _preview: Node3D
var _preview_rig: CarRig

var _ownership: VehicleOwnership
var _economy: EconomyManager

var _zoom: float = 1.0
var _zoom_target: float = 1.0
var _base_distance: float = 3.0
var _focus: Vector3 = Vector3(0.0, 0.3, 0.0)
var _dragging: bool = false
var _spin_velocity: float = 0.0            # radyan/sn (sürüklemeden kalan)
var _idle_time: float = 0.0
var _touches: Dictionary = {}
var _pinch_start_dist: float = 0.0
var _pinch_start_zoom: float = 1.0

var _closing: bool = false
var _tweens: Array[Tween] = []
var _group_targets: Dictionary = {}


func _ready() -> void:
	name = "ShowroomScreen"
	add_to_group("showroom")
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # açıkken dünyaya tıklama / kamera sürükleme gitmez
	_build_viewport()
	_build_overlay()
	set_process(false)
	_connect_managers.call_deferred()


# --- Aç / kapa ---------------------------------------------------------------

func open() -> void:
	if visible:
		return
	_closing = false
	_closing_after_buy = false
	show()
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_rebuild_list()
	_zoom = 1.0
	_zoom_target = 1.0
	_spin_velocity = 0.0
	_idle_time = AUTO_RESUME
	_display_root.rotation = Vector3(0.0, deg_to_rad(-38.0), 0.0)   # showroom açılış kadrajı: 3/4
	var target: StringName = _shown_crate if _shown_crate != &"" else _first_crate()
	_shown_crate = &""
	_shown_vehicle = &""
	_show_crate(target)
	set_process(true)
	opened.emit()
	_enter_animation()


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	set_process(false)
	_kill_tweens()
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.16)
	tween.tween_property(_display_root, "scale", Vector3.ONE * 0.92, 0.16)
	_tweens.append(tween)
	tween.finished.connect(_finish_close)


func _finish_close() -> void:
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_clear_preview()        # showroom kapalıyken araç modeli bellekte durmaz
	hide()
	modulate.a = 1.0
	_display_root.scale = Vector3.ONE
	_closing = false
	closed.emit()


## Gösterilen araç (GERİ AL listesinden; kasa gösteriliyorsa &"").
func shown_vehicle() -> StringName:
	return _shown_vehicle


## Gösterilen kasa (araç gösteriliyorsa &"").
func shown_crate() -> StringName:
	return _shown_crate


# --- 3D showroom --------------------------------------------------------------

func _build_viewport() -> void:
	_view = SubViewportContainer.new()
	_view.name = "View"
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.stretch = true
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE   # tıklama/sürükleme bu Control'e düşsün
	add_child(_view)

	_viewport = SubViewport.new()
	_viewport.name = "ShowroomViewport"
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_view.add_child(_viewport)

	_camera = Camera3D.new()
	_camera.name = "ShowroomCamera"
	_camera.fov = CAM_FOV
	_camera.near = 0.05
	_camera.far = 60.0
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0E1014")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("39404C")
	env.ambient_light_energy = 0.58
	_camera.environment = env
	_viewport.add_child(_camera)

	_build_lights()
	_build_environment()

	_display_root = Node3D.new()
	_display_root.name = "VehicleDisplayRoot"
	_viewport.add_child(_display_root)
	_model_slot = Node3D.new()
	_model_slot.name = "ModelSlot"
	_display_root.add_child(_model_slot)
	_apply_camera()


func _build_lights() -> void:
	# KEY: aracın ön/yan hatlarını çıkaran ana ışık; gölgeyi bu verir.
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.name = "KeyLight"
	key.light_color = Color("FFEFD6")
	key.light_energy = 0.9
	key.light_specular = 0.35            # cam yüzeyler patlamasın
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 14.0
	key.basis = Basis.looking_at(Vector3(-0.55, -1.0, -0.45).normalized(), Vector3.UP)
	_viewport.add_child(key)

	# FILL: karşı taraftan yumuşak dolgu (gölgesiz, soğuğa çalan)
	var fill: SpotLight3D = SpotLight3D.new()
	fill.name = "Spot0"
	fill.light_color = Color("D9E4F5")
	fill.light_energy = 1.9
	fill.light_specular = 0.2
	fill.spot_range = 8.0
	fill.spot_angle = 38.0
	fill.spot_attenuation = 1.6
	fill.position = Vector3(2.4, 2.6, 1.4)
	fill.look_at_from_position(fill.position, Vector3(0.0, 0.3, 0.0), Vector3.UP)
	_viewport.add_child(fill)

	# TOP: tavandan aracın üstüne düşen sıcak ışık havuzu
	var top: SpotLight3D = SpotLight3D.new()
	top.name = "Spot1"
	top.light_color = Color("FFE3B0")
	top.light_energy = 3.6
	top.light_specular = 0.3
	top.spot_range = 6.5
	top.spot_angle = 30.0
	top.spot_attenuation = 1.2
	top.position = Vector3(-0.5, CEILING_Y - 0.5, 0.4)
	top.look_at_from_position(top.position, Vector3(0.0, 0.2, 0.0), Vector3.UP)
	_viewport.add_child(top)

	# RIM: arkadan gelen kenar ışığı — araç koyu zeminden ayrılsın
	var rim: OmniLight3D = OmniLight3D.new()
	rim.name = "RimLight"
	rim.light_color = Color("FFD9A0")
	rim.light_energy = 2.6
	rim.light_specular = 0.4
	rim.omni_range = 4.0
	rim.position = Vector3(-1.4, 1.0, -2.2)
	_viewport.add_child(rim)


## Showroom mimarisi: zemin, sergi platformu, katmanlı arka duvar, cam cephe, tavan ve dekor.
## Hepsi primitive mesh + StandardMaterial3D; ağır post-process / reflection yok.
func _build_environment() -> void:
	var env_root: Node3D = Node3D.new()
	env_root.name = "Environment"
	_viewport.add_child(env_root)
	_build_floor(env_root)
	_build_platform(env_root)
	_build_back_wall(env_root)
	_build_glass_facade(env_root)
	_build_outside(env_root)
	_build_ceiling(env_root)
	_build_decor(env_root)


# --- Zemin ---------------------------------------------------------------------

func _build_floor(env_root: Node3D) -> void:
	# Büyük cilalı taş plakalar: desen dokudan gelir (tek çizim), parlaklık malzemeden
	var floor_mesh: PlaneMesh = PlaneMesh.new()
	floor_mesh.size = Vector2(26.0, 13.4)   # cam cephede biter; ötesi dış dünya
	var floor_mat: StandardMaterial3D = _material(Color("2A2E35"), 0.22, 0.30)
	floor_mat.albedo_texture = _tile_texture(Color("3A4049"), Color("23272E"), 4)
	floor_mat.uv1_scale = Vector3(11.0, 11.0, 1.0)
	env_root.add_child(_mesh("Floor", floor_mesh, floor_mat, Vector3(-2.0, 0.0, -0.3)))

	# Sergi alanı: zeminde daha açık, ince derzli bir daire
	var inlay: CylinderMesh = CylinderMesh.new()
	inlay.top_radius = 3.4
	inlay.bottom_radius = 3.4
	inlay.height = 0.01
	var inlay_mat: StandardMaterial3D = _material(Color("454B55"), 0.18, 0.35)
	inlay_mat.albedo_texture = _tile_texture(Color("4E555F"), Color("343943"), 3)
	inlay_mat.uv1_scale = Vector3(3.0, 3.0, 1.0)
	env_root.add_child(_mesh("FloorInlay", inlay, inlay_mat, Vector3(0.0, 0.005, 0.0)))

	# Zemin parlaması (yansıma hissi) — ek harman, ucuz
	var glow: PlaneMesh = PlaneMesh.new()
	glow.size = Vector2(6.0, 6.0)
	var glow_mat: StandardMaterial3D = StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow_mat.albedo_texture = _radial_texture(Color(1.0, 0.84, 0.58, 0.13))
	glow_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	env_root.add_child(_mesh("FloorGlow", glow, glow_mat, Vector3(0.0, 0.012, 0.0)))


# --- Sergi platformu ------------------------------------------------------------

func _build_platform(env_root: Node3D) -> void:
	# Koyu metal kaide + açık gri tabla + ince amber ışık bandı (yarıçaplar araca göre ayarlanır)
	var base: CylinderMesh = CylinderMesh.new()
	base.top_radius = 1.0
	base.bottom_radius = 1.03
	base.height = PLATFORM_HEIGHT
	_platform_base = _mesh("PlatformBase", base, _material(Color("1D2026"), 0.35, 0.75),
		Vector3(0.0, PLATFORM_HEIGHT * 0.5, 0.0))
	env_root.add_child(_platform_base)

	var top: CylinderMesh = CylinderMesh.new()
	top.top_radius = 0.94
	top.bottom_radius = 0.94
	top.height = 0.02
	_platform = _mesh("PlatformTop", top, _material(Color("6E747E"), 0.30, 0.25),
		Vector3(0.0, PLATFORM_HEIGHT + 0.005, 0.0))
	env_root.add_child(_platform)

	var rim: TorusMesh = TorusMesh.new()
	rim.inner_radius = 0.97
	rim.outer_radius = 1.0
	var rim_mat: StandardMaterial3D = _material(Color("F5BE4C"), 0.4, 0.1)
	rim_mat.emission_enabled = true
	rim_mat.emission = Color("F5BE4C")
	rim_mat.emission_energy_multiplier = 0.7
	_platform_rim = _mesh("PlatformRim", rim, rim_mat, Vector3(0.0, PLATFORM_HEIGHT * 0.62, 0.0))
	env_root.add_child(_platform_rim)

	# Araç altı yumuşak gölge
	var blob_mesh: PlaneMesh = PlaneMesh.new()
	blob_mesh.size = Vector2(1.7, 1.7)
	var blob_mat: StandardMaterial3D = StandardMaterial3D.new()
	blob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blob_mat.albedo_texture = _radial_texture(Color(0.0, 0.0, 0.0, 0.5))
	blob_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_blob = _mesh("ContactShadow", blob_mesh, blob_mat, Vector3(0.0, PLATFORM_HEIGHT + 0.02, 0.0))
	env_root.add_child(_blob)


# --- Arka duvar (katmanlı) ------------------------------------------------------

func _build_back_wall(env_root: Node3D) -> void:
	# 1) Koyu taşıyıcı duvar
	var wall: BoxMesh = BoxMesh.new()
	wall.size = Vector3(7.4, CEILING_Y, 0.2)
	env_root.add_child(_mesh("BackWall", wall, _material(Color("1A1D22"), 0.8, 0.05),
		Vector3(SIGN_X, CEILING_Y * 0.5, WALL_Z)))

	# 2) Kameranın karşısındaki bölüm: dikey ahşap panel (doku ile çıtalı)
	var wood_panel: BoxMesh = BoxMesh.new()
	wood_panel.size = Vector3(7.0, 2.3, 0.12)
	var wood_mat: StandardMaterial3D = _material(Color("6E4524"), 0.6, 0.0)
	wood_mat.albedo_texture = _stripe_texture(Color("7C4F27"), Color("5A3619"), 8)
	wood_mat.uv1_scale = Vector3(4.0, 1.0, 1.0)
	env_root.add_child(_mesh("WoodPanel", wood_panel, wood_mat,
		Vector3(SIGN_X, 1.15, WALL_Z + 0.16)))

	# 3) Metal çıtalar (ahşabı üstten/alttan keser)
	var trim_mat: StandardMaterial3D = _material(Color("A7AEB8"), 0.25, 0.85)
	for y: float in [0.06, 2.24]:
		var trim: BoxMesh = BoxMesh.new()
		trim.size = Vector3(7.0, 0.09, 0.16)
		env_root.add_child(_mesh("WoodTrim%d" % int(y * 100), trim, trim_mat,
			Vector3(SIGN_X, y, WALL_Z + 0.19)))

	# 4) Işıklı tabela paneli: arkadan aydınlatılmış krem plaka
	var backlit: BoxMesh = BoxMesh.new()
	backlit.size = Vector3(4.2, 1.05, 0.06)
	var backlit_mat: StandardMaterial3D = _material(Color("F3E8CF"), 0.55, 0.0)
	backlit_mat.emission_enabled = true
	backlit_mat.emission = Color("FFF3DC")
	backlit_mat.emission_energy_multiplier = 0.55
	env_root.add_child(_mesh("SignPanel", backlit, backlit_mat, Vector3(SIGN_X, 1.34, WALL_Z + 0.23)))
	var sign_edge: BoxMesh = BoxMesh.new()
	sign_edge.size = Vector3(4.44, 1.26, 0.04)
	env_root.add_child(_mesh("SignFrame", sign_edge, _material(Color("2A2E36"), 0.35, 0.7),
		Vector3(SIGN_X, 1.34, WALL_Z + 0.21)))

	var title: Label3D = Label3D.new()
	title.name = "SignTitle"
	title.text = "CAR PARTS"
	title.font_size = 128
	title.pixel_size = 0.0042
	title.modulate = Color("2F3236")
	title.position = Vector3(SIGN_X, 1.52, WALL_Z + 0.27)
	env_root.add_child(title)
	var subtitle: Label3D = Label3D.new()
	subtitle.name = "SignSubtitle"
	subtitle.text = "AUTOMOTIVE  ·  SHOWROOM"
	subtitle.font_size = 96
	subtitle.pixel_size = 0.0021
	subtitle.modulate = Color("8A5A2B")
	subtitle.position = Vector3(SIGN_X, 1.08, WALL_Z + 0.27)
	env_root.add_child(subtitle)


# --- Cam cephe ------------------------------------------------------------------

func _build_glass_facade(env_root: Node3D) -> void:
	var glass_mat: StandardMaterial3D = _material(Color("9FC4D8", 0.19), 0.06, 0.4)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.emission_enabled = true
	glass_mat.emission = Color("BBD7E8")
	glass_mat.emission_energy_multiplier = 0.1
	var frame_mat: StandardMaterial3D = _material(Color("31363F"), 0.3, 0.8)

	# Arka duvarın iki yanında cam bölmeler (ahşap panelin solunda ve sağında)
	var spans: Array[Vector2] = [Vector2(-13.0, SIGN_X - 3.7), Vector2(SIGN_X + 3.7, 5.0)]
	for span: Vector2 in spans:
		var width: float = span.y - span.x
		var panes: int = maxi(int(width / 2.4), 1)
		var step: float = width / panes
		for i: int in panes:
			var x: float = span.x + step * (i + 0.5)
			var pane: BoxMesh = BoxMesh.new()
			pane.size = Vector3(step - 0.12, 2.1, 0.05)
			env_root.add_child(_mesh("Glass%.0f" % (x * 10.0), pane, glass_mat,
				Vector3(x, 1.25, WALL_Z + 0.14)))
			var mullion: BoxMesh = BoxMesh.new()
			mullion.size = Vector3(0.1, 2.3, 0.12)
			env_root.add_child(_mesh("Mullion%.0f" % (x * 10.0), mullion, frame_mat,
				Vector3(x - step * 0.5, 1.2, WALL_Z + 0.16)))
		# Cam cephenin üst ve alt metal çerçevesi
		for y: float in [0.1, 2.38]:
			var rail: BoxMesh = BoxMesh.new()
			rail.size = Vector3(width, 0.16, 0.18)
			env_root.add_child(_mesh("Rail%.0f%.0f" % [span.x, y * 10.0], rail, frame_mat,
				Vector3(span.x + width * 0.5, y, WALL_Z + 0.16)))

	# Sol duvar: kadrajın kenarını kapatan koyu panel (tek mesh; ahşap bant kameradan görünmüyor)
	var side: BoxMesh = BoxMesh.new()
	side.size = Vector3(0.2, CEILING_Y, 13.4)
	env_root.add_child(_mesh("LeftWall", side, _material(Color("171A1F"), 0.8, 0.05),
		Vector3(WALL_X, CEILING_Y * 0.5, -0.3)))


# --- Camın arkası (dış dünya ipucu) ---------------------------------------------

func _build_outside(env_root: Node3D) -> void:
	# Dışarısı gündüz: showroom içi koyu olduğu için dış yüzeyler hafif emissive
	var grass: PlaneMesh = PlaneMesh.new()
	grass.size = Vector2(60.0, 26.0)
	env_root.add_child(_mesh("OutsideGrass", grass, _daylight(Color("83B24F")),
		Vector3(0.0, -0.02, WALL_Z - 13.0)))
	var road: BoxMesh = BoxMesh.new()
	road.size = Vector3(60.0, 0.06, 4.5)
	env_root.add_child(_mesh("OutsideRoad", road, _daylight(Color("4C4C4C")),
		Vector3(0.0, 0.0, WALL_Z - 6.5)))
	var walk: BoxMesh = BoxMesh.new()
	walk.size = Vector3(60.0, 0.1, 1.6)
	env_root.add_child(_mesh("OutsideWalk", walk, _daylight(Color("E2D1AB")),
		Vector3(0.0, 0.02, WALL_Z - 3.4)))
	# Uzakta birkaç basit bina ve ağaç: şehir hissi (düşük poligon, 6 mesh)
	var building_mat: StandardMaterial3D = _daylight(Color("9A9CA4"))
	var i: int = 0
	for spec: Vector3 in [Vector3(-1.0, 5.5, 3.6), Vector3(8.0, 3.2, 2.6)]:
		var building: BoxMesh = BoxMesh.new()
		building.size = Vector3(spec.z, spec.y, spec.z)
		env_root.add_child(_mesh("OutsideBuilding%d" % i, building, building_mat,
			Vector3(spec.x, spec.y * 0.5, WALL_Z - 15.0)))
		i += 1
	for x: float in [-5.0, 3.5]:
		var trunk: CylinderMesh = CylinderMesh.new()
		trunk.top_radius = 0.12
		trunk.bottom_radius = 0.16
		trunk.height = 1.1
		env_root.add_child(_mesh("TreeTrunk%.0f" % x, trunk, _daylight(Color("6B4A2A")),
			Vector3(x, 0.55, WALL_Z - 9.5)))
		var crown: SphereMesh = SphereMesh.new()
		crown.radius = 0.85
		crown.height = 1.5
		env_root.add_child(_mesh("TreeCrown%.0f" % x, crown, _daylight(Color("5E8F3A")),
			Vector3(x, 1.6, WALL_Z - 9.5)))


# --- Tavan ----------------------------------------------------------------------

func _build_ceiling(env_root: Node3D) -> void:
	var ceiling: PlaneMesh = PlaneMesh.new()
	ceiling.size = Vector2(26.0, 13.4)
	var ceiling_mesh: MeshInstance3D = _mesh("Ceiling", ceiling, _material(Color("15181D"), 0.9, 0.0),
		Vector3(-2.0, CEILING_Y, -0.3))
	ceiling_mesh.rotation_degrees = Vector3(180.0, 0.0, 0.0)   # yüzey aşağı baksın
	env_root.add_child(ceiling_mesh)

	# LED şeritleri: aracın üstünden arkaya uzanan ince ışık hatları
	var led_mat: StandardMaterial3D = _material(Color("FFF3DC"), 0.5, 0.0)
	led_mat.emission_enabled = true
	led_mat.emission = Color("FFF3DC")
	led_mat.emission_energy_multiplier = 1.4
	for x: float in [-6.2, -3.4, -0.6]:
		var led: BoxMesh = BoxMesh.new()
		led.size = Vector3(0.14, 0.05, 12.4)
		env_root.add_child(_mesh("Led%.0f" % x, led, led_mat, Vector3(x, CEILING_Y - 0.06, -0.4)))

	# Metal kirişler
	var beam_mat: StandardMaterial3D = _material(Color("2B3038"), 0.4, 0.7)
	for z: float in [0.0, -4.0]:
		var beam: BoxMesh = BoxMesh.new()
		beam.size = Vector3(20.0, 0.22, 0.3)
		env_root.add_child(_mesh("Beam%.0f" % z, beam, beam_mat, Vector3(-2.0, CEILING_Y - 0.16, z)))

	# Showroom spot gövdeleri (ışık kaynakları ayrı; bunlar dekor)
	var can_mat: StandardMaterial3D = _material(Color("23272E"), 0.35, 0.7)
	var lens_mat: StandardMaterial3D = _material(Color("FFE3B0"), 0.4, 0.0)
	lens_mat.emission_enabled = true
	lens_mat.emission = Color("FFE3B0")
	lens_mat.emission_energy_multiplier = 1.6
	for spot_pos: Vector3 in [Vector3(-2.2, 0.0, 0.2), Vector3(-4.6, 0.0, -2.0),
			Vector3(-0.6, 0.0, -2.4)]:
		var can: CylinderMesh = CylinderMesh.new()
		can.top_radius = 0.1
		can.bottom_radius = 0.14
		can.height = 0.26
		env_root.add_child(_mesh("SpotCan%.0f%.0f" % [spot_pos.x * 10.0, spot_pos.z * 10.0], can, can_mat,
			Vector3(spot_pos.x, CEILING_Y - 0.28, spot_pos.z)))
		var lens: CylinderMesh = CylinderMesh.new()
		lens.top_radius = 0.12
		lens.bottom_radius = 0.12
		lens.height = 0.03
		env_root.add_child(_mesh("SpotLens%.0f%.0f" % [spot_pos.x * 10.0, spot_pos.z * 10.0], lens, lens_mat,
			Vector3(spot_pos.x, CEILING_Y - 0.42, spot_pos.z)))


# --- Dekor ve bekleme alanı ------------------------------------------------------

func _build_decor(env_root: Node3D) -> void:
	# Bekleme alanı: iki koltuk + alçak masa (araçtan uzakta, duvarın önünde)
	var seat_mat: StandardMaterial3D = _material(Color("3A3F49"), 0.65, 0.05)
	var wood_mat: StandardMaterial3D = _material(Color("7C4F27"), 0.55, 0.0)
	var lounge: Vector3 = Vector3(-4.5, 0.0, -3.5)
	var i: int = 0
	for offset: Vector3 in [Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.3)]:
		var seat: BoxMesh = BoxMesh.new()
		seat.size = Vector3(0.9, 0.16, 0.85)
		env_root.add_child(_mesh("SeatBase%d" % i, seat, seat_mat, lounge + offset + Vector3(0.0, 0.42, 0.0)))
		var back: BoxMesh = BoxMesh.new()
		back.size = Vector3(0.16, 0.6, 0.85)
		env_root.add_child(_mesh("SeatBack%d" % i, back, seat_mat, lounge + offset + Vector3(-0.38, 0.62, 0.0)))
		var legs: BoxMesh = BoxMesh.new()
		legs.size = Vector3(0.7, 0.34, 0.6)
		env_root.add_child(_mesh("SeatLegs%d" % i, legs, _material(Color("22262D"), 0.4, 0.6),
			lounge + offset + Vector3(0.0, 0.17, 0.0)))
		i += 1
	var table: CylinderMesh = CylinderMesh.new()
	table.top_radius = 0.42
	table.bottom_radius = 0.42
	table.height = 0.06
	env_root.add_child(_mesh("TableTop", table, wood_mat, lounge + Vector3(1.1, 0.44, 0.65)))
	var table_leg: CylinderMesh = CylinderMesh.new()
	table_leg.top_radius = 0.07
	table_leg.bottom_radius = 0.16
	table_leg.height = 0.42
	env_root.add_child(_mesh("TableLeg", table_leg, _material(Color("22262D"), 0.4, 0.6),
		lounge + Vector3(1.1, 0.21, 0.65)))

	# Saksı bitkileri (iki adet, aracın arkasında ve yanında)
	for pot_pos: Vector3 in [Vector3(-5.7, 0.0, -4.6), Vector3(-0.4, 0.0, -5.9)]:
		var pot: CylinderMesh = CylinderMesh.new()
		pot.top_radius = 0.26
		pot.bottom_radius = 0.19
		pot.height = 0.44
		env_root.add_child(_mesh("Pot%.0f" % pot_pos.x, pot, _material(Color("30353D"), 0.5, 0.35),
			pot_pos + Vector3(0.0, 0.25, 0.0)))
		var leaves: SphereMesh = SphereMesh.new()
		leaves.radius = 0.38
		leaves.height = 0.86
		env_root.add_child(_mesh("Plant%.0f" % pot_pos.x, leaves, _material(Color("4E7A35"), 0.85, 0.0),
			pot_pos + Vector3(0.0, 0.76, 0.0)))

	# Katalog standı
	var stand: BoxMesh = BoxMesh.new()
	stand.size = Vector3(0.5, 0.06, 0.36)
	env_root.add_child(_mesh("StandTop", stand, wood_mat, Vector3(-3.3, 0.9, -3.1)))
	var stand_leg: BoxMesh = BoxMesh.new()
	stand_leg.size = Vector3(0.1, 0.9, 0.1)
	env_root.add_child(_mesh("StandLeg", stand_leg, _material(Color("22262D"), 0.4, 0.6),
		Vector3(-3.3, 0.45, -3.1)))

	# Duvara asılı otomotiv posteri (krem plaka + amber şerit)
	var poster: BoxMesh = BoxMesh.new()
	poster.size = Vector3(1.1, 1.5, 0.05)
	env_root.add_child(_mesh("Poster", poster, _material(Color("E7DCC4"), 0.7, 0.0),
		Vector3(SIGN_X + 3.4, 1.3, WALL_Z + 0.2)))
	var poster_band: BoxMesh = BoxMesh.new()
	poster_band.size = Vector3(1.1, 0.22, 0.06)
	var band_mat: StandardMaterial3D = _material(Color("F5BE4C"), 0.5, 0.1)
	band_mat.emission_enabled = true
	band_mat.emission = Color("F5BE4C")
	band_mat.emission_energy_multiplier = 0.3
	env_root.add_child(_mesh("PosterBand", poster_band, band_mat,
		Vector3(SIGN_X + 3.4, 0.82, WALL_Z + 0.23)))


## Küçük yardımcı: adlandırılmış MeshInstance3D.
func _mesh(node_name: String, mesh: Mesh, material: Material, position: Vector3) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	# Mekân gölge YAZMAZ (yalnızca alır): gölge geçişinde sadece araç çizilir — çizim çağrısı yarıya iner
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


## Cam cephenin arkasındaki gündüz yüzeyleri: içerideki koyu ışıkta sönmesin diye hafif emissive.
func _daylight(color: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = _material(color, 0.9, 0.0)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.55
	return mat


func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat


## Merkezden kenara sönen radyal degrade (gölge / parlama için; doku dosyası gerektirmez).
func _radial_texture(center: Color) -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, center)
	gradient.set_color(1, Color(center.r, center.g, center.b, 0.0))
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	return texture


## Büyük zemin plakaları: açık yüzey + ince derz çizgileri (128², tek çizim, ~64 KB).
func _tile_texture(face: Color, grout: Color, cells: int) -> ImageTexture:
	var size: int = 128
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGB8)
	image.fill(face)
	var step: int = size / cells
	for i: int in cells:
		for k: int in size:
			image.set_pixel(i * step, k, grout)
			image.set_pixel(k, i * step, grout)
			image.set_pixel(mini(i * step + 1, size - 1), k, grout)
			image.set_pixel(k, mini(i * step + 1, size - 1), grout)
	return ImageTexture.create_from_image(image)


## Dikey ahşap çıta dokusu (panel yüzeyleri için).
func _stripe_texture(light: Color, dark: Color, stripes: int) -> ImageTexture:
	var size: int = 64
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGB8)
	var step: int = maxi(size / stripes, 2)
	for x: int in size:
		var edge: bool = (x % step) < 2
		for y: int in size:
			image.set_pixel(x, y, dark if edge else light)
	return ImageTexture.create_from_image(image)


# --- Plakalar (overlay) ---------------------------------------------------------

func _build_overlay() -> void:
	# Yerleşim tamamen container'larla: tepe satırı (tabela), orta satır (sol liste | sağ bilgi),
	# alt satır (çıkış). Mutlak konum yok; ekran oranı değişse de plakalar yerinde kalır.
	var overlay: MarginContainer = MarginContainer.new()
	overlay.name = "Overlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		overlay.add_theme_constant_override(side, 16)
	add_child(overlay)

	var rows: VBoxContainer = VBoxContainer.new()
	rows.name = "Rows"
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override(&"separation", 8)
	overlay.add_child(rows)

	# Üst: büyük tabela
	_title_group = _row(rows, "TopRow", Control.SIZE_SHRINK_BEGIN)
	(_title_group as HBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	var sign: PlatePanel = PlatePanel.new()
	sign.theme_type_variation = &"HudCarPlate"
	sign.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var title: Label = _label(&"HudSignTitle", TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.add_child(title)
	_title_group.add_child(sign)
	var collection: PlateButton = PlateButton.new()
	collection.name = "CollectionButton"
	collection.theme_type_variation = &"HudPlateSmall"
	collection.kind = HudIcon.Kind.CAR
	collection.text = "KOLEKSİYON"
	collection.focus_mode = Control.FOCUS_NONE
	collection.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	collection.pressed.connect(func() -> void: screen_requested.emit(&"collection"))
	_title_group.add_child(collection)

	# Orta: solda araç plakaları, sağda bilgi + satın alma
	var middle: HBoxContainer = HBoxContainer.new()
	middle.name = "MiddleRow"
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(middle)

	_list_group = VBoxContainer.new()
	_list_group.name = "ListGroup"
	_list_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list_group.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	middle.add_child(_list_group)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "List"
	scroll.custom_minimum_size = Vector2(LIST_WIDTH, 316.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	TouchScroll.attach(scroll)
	_list_box = VBoxContainer.new()
	_list_box.name = "Plates"
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override(&"separation", 6)
	scroll.add_child(_list_box)
	_list_group.add_child(scroll)

	var spacer: Control = Control.new()
	spacer.name = "Spacer"
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(spacer)

	_info_group = VBoxContainer.new()
	_info_group.name = "InfoGroup"
	_info_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_group.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_info_group.add_theme_constant_override(&"separation", 8)
	middle.add_child(_info_group)

	# Araç bilgisi de diğer satın almalarla AYNI plakadır (PurchasePlate): başlık / alt başlık /
	# fiyat / etki satırları. Böylece garaj genişletme, tamir alanı ve araç aynı dili konuşur.
	_info_plate = PurchasePlate.new(INFO_WIDTH)
	_info_group.add_child(_info_plate)

	_buy_button = PlateButton.new()
	_buy_button.name = "BuyButton"
	_buy_button.theme_type_variation = &"HudPlate"
	_buy_button.kind = HudIcon.Kind.COIN
	_buy_button.custom_minimum_size = Vector2(INFO_WIDTH, 54.0)
	_buy_button.focus_mode = Control.FOCUS_NONE
	_buy_button.pressed.connect(_on_buy_pressed)
	_info_group.add_child(_buy_button)

	# Alt: çıkış
	_exit_group = _row(rows, "BottomRow", Control.SIZE_SHRINK_END)
	_exit_button = PlateButton.new()
	_exit_button.name = "ExitButton"
	_exit_button.theme_type_variation = &"HudPlateSmall"
	_exit_button.text = "GERİ"
	_exit_button.focus_mode = Control.FOCUS_NONE
	_exit_button.pressed.connect(close)
	_exit_group.add_child(_exit_button)
	var exit_spacer: Control = Control.new()
	exit_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	exit_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_exit_group.add_child(exit_spacer)


## Dikeyde tek satır (tıklamayı geçirir; içindeki plakalar kendi boyutunda kalır).
func _row(parent: Control, row_name: String, vertical_flags: int) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = row_name
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_vertical = vertical_flags as Control.SizeFlags
	row.add_theme_constant_override(&"separation", 8)
	parent.add_child(row)
	return row


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


# --- Kasa listesi, geri alma ve bilgi -------------------------------------------------

func _connect_managers() -> void:
	_ownership = get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	_economy = get_tree().get_first_node_in_group("economy") as EconomyManager
	_crates = get_tree().get_first_node_in_group("crates") as CrateManager
	_progress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress
	if _ownership:
		_ownership.ownership_changed.connect(_refresh_state)
	if _economy:
		_economy.money_changed.connect(func(_m: int) -> void: _refresh_state())
	if _progress:
		_progress.gems_changed.connect(func(_g: int) -> void: _refresh_state())
		_progress.level_up.connect(func(_l: int) -> void: _refresh_state())
	if _crates:
		_crates.crates_changed.connect(_refresh_state)


func _first_crate() -> StringName:
	var entries: Array[Dictionary] = CrateCatalog.all()
	return entries[0]["id"] if not entries.is_empty() else &""


## Kasalar + (varsa) GERİ AL bölümü. Keşfedilmiş araç listesi değiştiği için her açılışta kurulur.
func _rebuild_list() -> void:
	for child: Node in _list_box.get_children():
		child.queue_free()
	_plates.clear()
	_list_box.add_child(_section_label("ARAÇ KASALARI"))
	for crate: Dictionary in CrateCatalog.all():
		var id: StringName = crate["id"]
		var plate: PlateButton = _list_plate("crate:%s" % id, "%s\n%d GEM" % [crate["display_name"], crate["price_gems"]], HudIcon.Kind.GEM)
		plate.toggled.connect(func(pressed: bool) -> void:
			if pressed:
				_show_crate(id))
	var buyback: Array[StringName] = []
	if _ownership:
		for id: StringName in _ownership.discovered_ids():
			if not _ownership.is_owned(id):
				buyback.append(id)
	if not buyback.is_empty():
		_list_box.add_child(_section_label("GERİ AL"))
		for id: StringName in buyback:
			var plate: PlateButton = _list_plate("car:%s" % id, CarCatalog.label(CarCatalog.get_entry(id)), HudIcon.Kind.CAR)
			plate.toggled.connect(func(pressed: bool) -> void:
				if pressed:
					_show_vehicle(id))
	_group.allow_unpress = false


func _list_plate(key: String, text: String, icon: HudIcon.Kind) -> PlateButton:
	var plate: PlateButton = PlateButton.new()
	plate.name = key.replace(":", "_")
	plate.text = text
	plate.theme_type_variation = &"HudPlate"
	plate.kind = icon
	plate.toggle_mode = true
	plate.button_group = _group
	plate.focus_mode = Control.FOCUS_NONE
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plate.custom_minimum_size = Vector2(LIST_WIDTH - 16.0, 46.0)
	_list_box.add_child(plate)
	_plates[key] = plate
	return plate


func _section_label(text: String) -> Label:
	var label: Label = _label(&"HudPlateTitle", text)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


## Seçili kasayı platforma ve bilgi plakasına koyar.
func _show_crate(crate_id: StringName) -> void:
	if crate_id == &"" or (crate_id == _shown_crate and _shown_vehicle == &""):
		return
	if not CrateCatalog.exists(crate_id):
		push_warning("ShowroomScreen: '%s' kasası yok" % crate_id)
		return
	_shown_crate = crate_id
	_shown_vehicle = &""
	var plate: PlateButton = _plates.get("crate:%s" % crate_id)
	if plate:
		plate.set_pressed_no_signal(true)
	_load_crate_preview(crate_id)
	_refresh_state()


## GERİ AL listesindeki (keşfedilmiş, satılmış) aracı platforma koyar. Aynı anda tek model yüklenir.
func _show_vehicle(vehicle_id: StringName) -> void:
	if vehicle_id == &"" or vehicle_id == _shown_vehicle:
		return
	var entry: Dictionary = CarCatalog.get_entry(vehicle_id)
	if entry.is_empty():
		push_warning("ShowroomScreen: katalogda '%s' yok" % vehicle_id)
		return
	_shown_vehicle = vehicle_id
	_shown_crate = &""
	var plate: PlateButton = _plates.get("car:%s" % vehicle_id)
	if plate:
		plate.set_pressed_no_signal(true)
	_load_preview(entry["scene_path"])
	_refresh_state()


func _refresh_state() -> void:
	if _shown_crate != &"":
		_refresh_crate()
	elif _shown_vehicle != &"":
		_refresh_vehicle()


## Kasa plakası: fiyat, seviye şartı ve havuzdaki her aracın GERÇEK olasılığı (açık oranlar).
func _refresh_crate() -> void:
	var entry: Dictionary = CrateCatalog.get_entry(_shown_crate)
	var lines: PackedStringArray = PackedStringArray()
	for row: Dictionary in CrateCatalog.odds(_shown_crate):
		var car: Dictionary = CarCatalog.get_entry(row["id"])
		var mark: String = "✔ " if _ownership and _ownership.is_owned(row["id"]) else ""
		lines.append("%s%%%s  %s  ·  %s" % [mark, ("%.1f" % (float(row["chance"]) * 100.0)).replace(".", ","),
			String(car.get("display_name", row["id"])).to_upper(), CrateCatalog.rarity_label(row["rarity"])])
	var price: int = int(entry["price_gems"])
	if _progress and _progress.gems < price:
		lines.append("GEM: GÜNLÜK GİRİŞ · GÖREVLER · SEVİYE · USTALIK")   # gem nereden gelir (QA: anlatılmıyordu)
	_info_plate.set_content(String(entry["display_name"]),
		"ARAÇ TESLİMAT KASASI  ·  SV %d+" % int(entry["min_level"]), "%d GEM" % price, lines)
	_buy_button.kind = HudIcon.Kind.GEM
	var reason: String = _crates.buy_block_reason(_shown_crate) if _crates else "unknown"
	if _closing_after_buy:
		reason = "busy"
	match reason:
		"":
			_buy_button.text = "SATIN AL\n%d GEM" % price
			_buy_button.disabled = false
		"level":
			_buy_button.text = "SEVİYE %d\nGEREKLİ" % int(entry["min_level"])
			_buy_button.disabled = true
		"gems":
			_buy_button.text = "%d GEM\nGEM YETERSİZ" % price
			_buy_button.disabled = true
		"full":
			_buy_button.text = "ÖNCE GARAJDAKİ\nKASALARI AÇ"
			_buy_button.disabled = true
		_:
			_buy_button.text = "%d GEM" % price
			_buy_button.disabled = true


## GERİ AL plakası: keşfedilmiş aracın ₺ fiyatı (VehicleOwnership.status kararı).
func _refresh_vehicle() -> void:
	var entry: Dictionary = CarCatalog.get_entry(_shown_vehicle)
	var price: int = int(entry.get("price", 0))
	_info_plate.set_content(
		"%s %s" % [String(entry.get("brand", "")).to_upper(), String(entry.get("model", "")).to_upper()],
		ProgressionEffects.vehicle_subtitle(_shown_vehicle),
		"%s ₺" % Hud.format_thousands(price),
		ProgressionEffects.vehicle_lines(get_tree(), _shown_vehicle))
	_buy_button.kind = HudIcon.Kind.COIN
	if _ownership == null:
		_buy_button.text = "%s ₺" % Hud.format_thousands(price)
		_buy_button.disabled = true
		return
	match _ownership.status(_shown_vehicle):
		VehicleOwnership.Status.OWNED:
			_buy_button.text = "SAHİPSİN"
			_buy_button.disabled = true
		VehicleOwnership.Status.TOO_EXPENSIVE:
			_buy_button.text = "%s ₺\nPARA YETERSİZ" % Hud.format_thousands(price)
			_buy_button.disabled = true
		VehicleOwnership.Status.UNDISCOVERED:
			_buy_button.text = "KASADAN ÇIKAR"
			_buy_button.disabled = true
		_:
			_buy_button.text = "GERİ AL\n%s ₺" % Hud.format_thousands(price)
			_buy_button.disabled = false


func _on_buy_pressed() -> void:
	# Çift dokunuş: satın alma showroom'u kapatır; kapanış animasyonu sırasında (ya da aynı karede
	# ikinci basışta) ikinci bir kasa alınmasın.
	if _closing or not visible:
		return
	if _shown_crate != &"":
		if _crates == null:
			return
		var uid: int = _crates.buy(_shown_crate)   # gem + sonuç + kayıt CrateManager'da
		if uid > 0:
			_buy_button.disabled = true
			_closing_after_buy = true
			crate_purchased.emit(uid)
			return
		_refresh_state()
		return
	if _ownership == null or _shown_vehicle == &"":
		return
	# Para, sahiplik ve kayıt zinciri VehicleOwnership'in içinde: burada yeni mantık yok
	if _ownership.purchase_vehicle(_shown_vehicle):
		vehicle_purchased.emit(_shown_vehicle)
		_rebuild_list()
	_refresh_state()


# --- Önizleme modeli --------------------------------------------------------------

## Kasanın dünyadaki modelinin (ya da yer tutucusunun) aynısını platforma koyar. Model tembel
## yüklenir; showroom kapanınca serbest kalır.
func _load_crate_preview(crate_id: StringName) -> void:
	_free_model()
	var crate: CrateVisual = CrateVisual.new()
	crate.setup(crate_id, 0)
	crate.set_tag_visible(false)
	crate.set_clickable(false)
	_preview = crate
	_model_slot.add_child(crate)
	_fit_to_platform()

## Seçili aracın mevcut .tscn modelini sergi platformuna koyar; öncekini serbest bırakır.
func _load_preview(scene_path: String) -> void:
	_free_model()
	var scene: PackedScene = load(scene_path)
	if scene == null:
		push_warning("ShowroomScreen: '%s' yüklenemedi" % scene_path)
		return
	_preview = scene.instantiate() as Node3D
	# Gerçek boyuttan türeyen ölçek (garajdaki, trafikteki ve dragdeki ile AYNI oran); platform ve
	# kamera zaten modele göre uyarlanıyor (_fit_to_platform), o yüzden taşma olmuyor.
	_preview.scale = Vector3.ONE * CarCatalog.model_scale_for_scene(scene_path)
	_model_slot.add_child(_preview)
	_preview_rig = CarRig.for_node(_preview)
	_preview_rig.apply(CarAppearance.get_for(scene_path))
	_preview_rig.set_lod_bias(CarRig.LOD_BIAS_GARAGE)   # showroom: tam detay
	_fit_to_platform()


## Modeli platformun üstüne oturtur, platformu ve kamerayı aracın boyutuna göre ayarlar.
func _fit_to_platform() -> void:
	var bounds: AABB = _model_bounds(_preview)
	var center: Vector3 = bounds.get_center()
	_model_slot.position = Vector3(-center.x, PLATFORM_HEIGHT - bounds.position.y, -center.z)
	var radius: float = maxf(maxf(bounds.size.x, bounds.size.z) * 0.5, 0.25)
	var platform_radius: float = radius * 1.12
	var base: CylinderMesh = _platform_base.mesh
	base.top_radius = platform_radius
	base.bottom_radius = platform_radius + 0.04
	var top: CylinderMesh = _platform.mesh
	top.top_radius = platform_radius - 0.05
	top.bottom_radius = platform_radius - 0.05
	var rim: TorusMesh = _platform_rim.mesh
	rim.inner_radius = platform_radius - 0.012
	rim.outer_radius = platform_radius + 0.014
	var blob: PlaneMesh = _blob.mesh
	blob.size = Vector2(radius * 2.5, radius * 2.5)
	# Kamera kadrajı: aracın küre yarıçapı görüş açısına sığsın (araç içine girmez)
	var sphere: float = maxf(bounds.size.length() * 0.5, 0.3)
	_base_distance = sphere / sin(deg_to_rad(CAM_FOV) * 0.5) * 1.34   # araç ön planda, mekân arkada dursun
	# Bakış noktası araçtan biraz yukarıda: araç alt-ortada kalsın, üstte duvar/tabela/tavan görünsün
	_focus = Vector3(0.0, PLATFORM_HEIGHT + bounds.size.y * 0.45 + 0.24, 0.0)
	_apply_camera()


func _model_bounds(car: Node3D) -> AABB:
	var merged: AABB = AABB()
	var first: bool = true
	var stack: Array[Node] = [car]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mesh_node: MeshInstance3D = node
			var box: AABB = car.global_transform.affine_inverse() * mesh_node.global_transform * mesh_node.get_aabb()
			merged = box if first else merged.merge(box)
			first = false
		for child: Node in node.get_children():
			stack.append(child)
	return merged if not first else AABB(Vector3(-0.5, 0.0, -0.5), Vector3.ONE)


func _free_model() -> void:
	if _preview:
		_preview.queue_free()
		_preview = null
	_preview_rig = null


func _clear_preview() -> void:
	_free_model()
	_display_root.rotation = Vector3.ZERO


# --- Kamera, dönüş, zoom ----------------------------------------------------------

func _apply_camera() -> void:
	var azimuth: float = deg_to_rad(CAM_AZIMUTH)
	var elevation: float = deg_to_rad(CAM_ELEVATION)
	var dir: Vector3 = Vector3(sin(azimuth) * cos(elevation), sin(elevation), cos(azimuth) * cos(elevation))
	_camera.position = _focus + dir * (_base_distance * _zoom)
	_camera.look_at_from_position(_camera.position, _focus, Vector3.UP)


func _process(delta: float) -> void:
	if _closing:
		return
	# Sürüklemeden kalan hız sönerek biter, sonra otomatik dönüş devreye girer
	if not _dragging:
		_idle_time += delta
		if absf(_spin_velocity) > 0.0001:
			_display_root.rotate_y(_spin_velocity * delta)
			_spin_velocity = lerpf(_spin_velocity, 0.0, 1.0 - exp(-SPIN_DAMPING * delta))
		elif _idle_time >= AUTO_RESUME:
			_display_root.rotate_y(deg_to_rad(AUTO_SPEED) * delta)
	if absf(_zoom_target - _zoom) > 0.0005:
		_zoom = lerpf(_zoom, _zoom_target, 1.0 - exp(-ZOOM_SMOOTH * delta))
		_apply_camera()


func _gui_input(event: InputEvent) -> void:
	if _closing:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_by(-ZOOM_STEP)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_by(ZOOM_STEP)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed and _touches.is_empty()
			if not mb.pressed:
				_idle_time = 0.0
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if _dragging and _touches.is_empty() and mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_rotate_by_pixels(mm.relative.x, mm.relative.x / maxf(get_process_delta_time(), 0.001))
	elif event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.pressed:
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
			_idle_time = 0.0
		_dragging = _touches.size() == 1
		if _touches.size() == 2:
			_pinch_start_dist = _touch_distance()
			_pinch_start_zoom = _zoom_target
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event
		_touches[sd.index] = sd.position
		if _touches.size() >= 2:
			if _pinch_start_dist > 1.0:
				# Parmaklar açılınca yaklaş (mesafe azalır)
				_zoom_target = clampf(_pinch_start_zoom * (_pinch_start_dist / maxf(_touch_distance(), 1.0)), ZOOM_MIN, ZOOM_MAX)
		else:
			_rotate_by_pixels(sd.relative.x, sd.velocity.x)


## Yatay sürükleme → Y ekseni dönüşü (modelin kendi transform'u değişmez).
func _rotate_by_pixels(pixels: float, velocity_px: float) -> void:
	_display_root.rotate_y(-pixels * DRAG_TO_RAD)
	_spin_velocity = clampf(-velocity_px * DRAG_TO_RAD, -6.0, 6.0)
	_idle_time = 0.0


func _zoom_by(amount: float) -> void:
	_zoom_target = clampf(_zoom_target + amount, ZOOM_MIN, ZOOM_MAX)


func _touch_distance() -> float:
	var positions: Array = _touches.values()
	return (positions[0] as Vector2).distance_to(positions[1]) if positions.size() >= 2 else 0.0


# --- Giriş animasyonu ---------------------------------------------------------------

## Kısa ve sade: ortam solarak gelir, araç büyür, plakalar kenarlardan yerine oturur (~0.25 sn).
func _enter_animation() -> void:
	_kill_tweens()
	_view.modulate.a = 0.0
	var env_tween: Tween = create_tween()
	env_tween.tween_property(_view, "modulate:a", 1.0, 0.25)
	_tweens.append(env_tween)

	_display_root.scale = Vector3.ONE * 0.88
	var car_tween: Tween = create_tween()
	car_tween.tween_property(_display_root, "scale", Vector3.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.04)
	_tweens.append(car_tween)

	await get_tree().process_frame
	if not visible or _closing:
		return
	var groups: Array = [
		[_title_group, Vector2(0.0, -SLIDE)],
		[_list_group, Vector2(-SLIDE, 0.0)],
		[_info_group, Vector2(SLIDE, 0.0)],
		[_exit_group, Vector2(0.0, SLIDE)],
	]
	_group_targets.clear()
	for i: int in groups.size():
		var group: Control = groups[i][0]
		var target: Vector2 = group.position
		_group_targets[group] = target
		group.position = target + groups[i][1]
		group.modulate.a = 0.0
		var tween: Tween = create_tween().set_parallel(true)
		tween.tween_property(group, "position", target, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(i * 0.03)
		tween.tween_property(group, "modulate:a", 1.0, 0.14).set_delay(i * 0.03)
		_tweens.append(tween)


func _kill_tweens() -> void:
	for tween: Tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()
	_view.modulate.a = 1.0
	for group: Control in [_title_group, _list_group, _info_group, _exit_group]:
		group.modulate.a = 1.0
		if _group_targets.has(group):
			group.position = _group_targets[group]
	_group_targets.clear()
