class_name ShowroomScreen
extends Control
## MAĞAZA — tam ekran showroom (alt sekmedeki MAĞAZA ile aynı yer). Haritadaki "CAR PARTS & SHOWROOM" binasına tıklayınca açılır
## (shop_hitbox.gd).
##
## İKİ SEKME (2026-11-02, kullanıcı: "hem kasa hem araba ayrı kısımlar olsun"; B taslağı, docs/ARAC_MAGAZASI.md).
## KASALAR | ARAÇLAR anahtarı sol üstte GERİ'nin yanında (sekme yeri taslağı C); MAĞAZA tabelası yok.
## KASALAR — KASA SİSTEMİ (docs/vehicle_crate_design_v2.md): sol listede ARAÇ TESLİMAT KASALARI (gem ile) durur;
## seçilen kasanın modeli platformda döner, sağ plakada fiyatı, seviye şartı ve havuzundaki HER aracın gerçek
## olasılığı yazar. Satın alınan kasa garajın teslimat alanına FİZİKSEL olarak gelir (CrateManager +
## CrateDelivery); showroom kapanır, kamera kasaya gider.
## ARAÇLAR — ARAÇ MAĞAZASI (CarShop): altta koyu rafta süzgeç çipleri (YOLDA · TÜMÜ · kasa aileleri · GERİ AL) ve
## araç kartları; sağda plaka + iki ödeme düğmesi (₺ → 24 saatte teslim, GEM → hemen; yalnız gem araçta tek düğme),
## siparişteki araçta ödüllü reklam düğmesi (−8 saat). Kadraj aracı rafın üstüne ve plakanın soluna kaydırır.
## GERİ AL çipi: mağazada olmayan, satılmış araçları (başlangıç aracı gibi) ₺ ile hemen geri satar.
##
## YOLDAKİ KASALAR (2026-10-17, kullanıcı kararı "kasa listeden açılsın"): garajda yer bulamayan kasa listenin
## başındaki bu bölüme girer (alt sekmedeki MAĞAZA rozeti sayısını gösterir). Yer yokken alınan kasada showroom
## kapanmaz, kasa bu bölümde seçili gelir. KASAYI AÇ: ödül CrateManager.open()'da verilip kaydedilir, açılış
## sahnesi (gerilim → patlama → araç dönerek yükselir) bu platformda oynar — CrateDelivery'nin statik
## yardımcıları ve CratePanel'in plaka metinleriyle (garajdaki açılışla aynı). TAMAM'da kasa kapanır (claim).
## Sahne sürerken liste gizlenir, GERİ kilitlenir; showroom yine de kapanırsa kasa kapatılır (ödül zaten verildi).
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
## (purchase_vehicle), mağaza fiyatı / siparişi CarShop, para EconomyManager, kalıcılık SaveManager. Burada yeni
## satın alma / ekonomi mantığı YOKTUR. Önizleme yalnızca görseldir: TrafficManager'a, RepairManager'a, CarHitbox'a
## ve dünyaya hiç girmez; ekran kapanınca model serbest bırakılır.

signal opened
signal closed
signal vehicle_purchased(vehicle_id: StringName)
## ARAÇ MAĞAZASI: ₺ siparişi verildi (araç 24 saatte gelir; HUD bildirir).
signal vehicle_ordered(vehicle_id: StringName)
## Kasa satın alındı (HUD showroom'u kapatıp kamerayı teslimat alanına götürür).
signal crate_purchased(uid: int)
## Başka bir pano istendi (KOLEKSİYON).
signal screen_requested(id: StringName)

const LIST_WIDTH: float = 188.0
const INFO_WIDTH: float = 290.0   # kasa oran satırları (✔ yüzde · model · nadirlik) tek satıra sığsın; en uzunu
# "✔ %5,8  CHEVALIER CAMARGO SS · EPİK"; plakanın iç payı 32 px (2026-11-01 ad değişikliği: 264 → 290)
const SLIDE: float = 18.0
## ARAÇLAR rafı kartı (küçük resim + ad + fiyat / durum); küçük resim alanı dekor kartlarıyla aynı.
const CARD_WIDTH: float = 124.0
const CARD_HEIGHT: float = 104.0
const THUMB_TOP: float = 6.0
const THUMB_AREA: Vector2 = Vector2(104.0, 58.0)
const THUMB_DIR: String = "res://assets/cars/thumbs/"
## ARAÇLAR'da araç rafın üstünde, bilgi plakasının solunda görünsün: kadraj ekranın bu payı kadar kayar (x sola,
## y yukarı) ve biraz uzaklaşır (kullanıcı 2026-11-02: "araca biraz daha yer ayır, gözüksün").
const CARS_VIEW_SHIFT: Vector2 = Vector2(0.17, 0.15)
const CARS_ZOOM: float = 1.12
## Ödeme düğmesinde ikinci dokunuş (EMİN MİSİN?) bu kadar beklenir (ms).
const CONFIRM_MS: int = 3500
const PAY_CASH: StringName = &"cash"
const PAY_GEM: StringName = &"gem"
## Süzgeç çipleri: kasa aileleri dışında.
const CHIP_ALL: StringName = &"all"
const CHIP_ORDERS: StringName = &"orders"
const CHIP_BUYBACK: StringName = &"buyback"

enum Tab { CRATES, CARS }

## Son açık sekme (oturum boyunca hatırlanır).
static var _last_tab: int = Tab.CRATES
## Küçük resim önbelleği: araç id → doku (fabrika görünümü, assets/cars/thumbs).
static var _thumbs: Dictionary = {}

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
var _key_light: DirectionalLight3D
var _display_root: Node3D                  # 360° dönüş bunu döndürür
var _model_slot: Node3D                    # modeli platforma oturtan kaydırma
var _platform: MeshInstance3D              # üst tabla (açık gri)
var _platform_base: MeshInstance3D         # koyu metal kaide
var _platform_rim: MeshInstance3D          # ince amber ışık bandı
var _blob: MeshInstance3D                  # araç altı yumuşak gölge

var _title_group: PanelContainer            # KASALAR / ARAÇLAR anahtarı (GERİ'nin yanında)
var _side_group: HBoxContainer
var _tab_group: ButtonGroup = ButtonGroup.new()
var _tab_crates: PlateButton
var _tab_cars: PlateButton
var _tab: Tab = Tab.CRATES
var _tray: PanelContainer
var _chip_box: HBoxContainer
var _chips: Dictionary = {}                # süzgeç id → PlateButton
var _chip_group: ButtonGroup = ButtonGroup.new()
var _family: StringName = &""              # seçili süzgeç (kasa id / CHIP_*)
var _tray_count: Label
var _card_scroll: ScrollContainer
var _card_strip: HBoxContainer
var _cards: Dictionary = {}                # araç id → PlateButton
var _card_group: ButtonGroup = ButtonGroup.new()
var _car_buttons: HBoxContainer
var _cash_button: PlateButton
var _gem_button: PlateButton
var _ad_button: AdOfferButton
var _confirm: StringName = &""             # ikinci dokunuşu bekleyen ödeme (PAY_*)
var _confirm_at: int = 0
var _view_shift: Vector2 = Vector2.ZERO    # kadraj kayması (ekran payı; ARAÇLAR'da CARS_VIEW_SHIFT)
var _tick: float = 0.0
var _open_on_car: StringName = &""
var _open_cars: bool = false
var _collection_button: PlateButton
var _list_group: VBoxContainer
var _info_group: VBoxContainer
var _exit_group: HBoxContainer
var _list_box: VBoxContainer
var _info_plate: PurchasePlate
var _buy_button: PlateButton
var _exit_button: PlateButton

var _plates: Dictionary = {}               # "crate:<id>" / "car:<id>" → PlateButton
var _shown_crate: StringName = &""         # platformdaki kasa (araç gösteriliyorsa &"")
var _shown_pending: int = 0                # platformdaki YOLDAKİ kasanın uid'i (0 = yok)
var _reveal_uid: int = 0                   # bu platformda açılan kasa (sahne + sonuç plakası boyunca)
var _reveal_done: bool = false             # sonuç plakası gösteriliyor: düğme TAMAM
var _reveal_fx: CrateRevealFx
var _fit: Dictionary = {}                  # platform / kamera kadrajı (yumuşak geçiş için son değerler)
var _fit_tween: Tween
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

## open_on_crate: bir sonraki açılışta gösterilecek kasa.
var _open_on: StringName = &""

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
	_viewport.msaa_3d = GameSettings.subviewport_msaa(Viewport.MSAA_2X)
	_key_light.shadow_enabled = GameSettings.shadows_enabled()
	_claim_render_target()
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_rebuild_list()
	_zoom = 1.0
	_zoom_target = 1.0
	_spin_velocity = 0.0
	_idle_time = AUTO_RESUME
	_display_root.rotation = Vector3(0.0, deg_to_rad(-38.0), 0.0)   # showroom açılış kadrajı: 3/4
	var target: StringName = _shown_crate if _shown_crate != &"" else _first_crate()
	var asked: StringName = _open_on
	_open_on = &""
	_shown_crate = &""
	_shown_vehicle = &""
	_shown_pending = 0
	_confirm = &""
	# Sekme: ARAÇLAR'a çağrıldıysa o; kasa istendiyse ya da yolda kasa varsa KASALAR; değilse son açık sekme
	var tab: int = _last_tab
	if asked != &"" or _first_pending() > 0:
		tab = Tab.CRATES
	if _open_cars:
		tab = Tab.CARS
	_open_cars = false
	if tab == Tab.CARS:
		_set_tab(Tab.CARS)
	else:
		_apply_tab_chrome(Tab.CRATES)
		# Yolda kasa varsa önce o (alt sekmedeki rozet buraya getirir); ETKİNLİK panosundan gelindiyse etkinliğin kasası
		if asked != &"" and CrateCatalog.exists(asked):
			_show_crate(asked)
		elif _first_pending() > 0:
			_show_pending(_first_pending())
		else:
			_show_crate(target)
	_view_shift = _shift_target()
	_apply_camera()
	set_process(true)
	opened.emit()
	_enter_animation()


## Bir sonraki açılış bu kasada (ETKİNLİK panosu: etkinlik kasası).
func open_on_crate(crate_id: StringName) -> void:
	_open_on = crate_id


## Bir sonraki açılış ARAÇLAR sekmesinde (verilirse o araç seçili; HUD: "aracın yolda" bildirimi).
func open_on_car(vehicle_id: StringName = &"") -> void:
	_open_cars = true
	_open_on_car = vehicle_id


## Açık sekme (testler / HUD).
func current_tab() -> Tab:
	return _tab


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


## ÇİZİM HEDEFİ: kapalıyken VRAM'de tutulmaz. Kapsayıcı `stretch` açıkken görüntü alanına elle boyut
## atanamıyor (Godot yok sayıp uyarı basıyordu): eskiden kapanıştaki "4×4" küçültme HİÇ ÇALIŞMIYORDU ve
## tam ekran hedef (renk + derinlik, MSAA'lı) kapalı ekranda bellekte kalıyordu (2026-10-11 QA).
## Kapanışta / ön ısıtmada `stretch` kapatılır; açılışta boyut kapsayıcıdan alınıp geri açılır.
func _release_render_target(size: Vector2i = Vector2i(4, 4)) -> void:
	var box: SubViewportContainer = _viewport.get_parent() as SubViewportContainer
	if box:
		box.stretch = false
	_viewport.size = size


func _claim_render_target() -> void:
	var box: SubViewportContainer = _viewport.get_parent() as SubViewportContainer
	if box and not box.stretch:
		_viewport.size = Vector2i(box.size.max(Vector2.ONE))
		box.stretch = true


func _finish_close() -> void:
	if _reveal_uid > 0:
		_end_reveal()   # sahne yarıda kaldı: ödül zaten verildi, kasa kapanır
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_release_render_target()
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


## Platformdaki yoldaki kasanın uid'i (0 = yok).
func shown_pending() -> int:
	return _shown_pending


## Bu platformda kasa açılıyor mu (sahne ya da sonuç plakası)? HUD Android GERİ'yi bu sürede yutar.
func is_revealing() -> bool:
	return _reveal_uid > 0


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
	_viewport.msaa_3d = GameSettings.subviewport_msaa(Viewport.MSAA_2X)   # açılışta yeniden bakılır
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
	key.shadow_enabled = GameSettings.shadows_enabled()   # DÜŞÜK kalitede gölge yok (açılışta yeniden bakılır)
	key.directional_shadow_max_distance = 14.0
	_key_light = key
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
	# Salonun sabit kutuları (duvar, cam, tavan, koltuk, tabela...) toplu çizilir (StaticBatch): onlarca çizim çağrısı birkaç
	# taneye iner. Dönen platform, araç altı gölge ve saydam zemin parıltısı ayrı kalır.
	var statics: Array[Node3D] = []
	for child: Node in env_root.get_children():
		if child is GeometryInstance3D and child not in [_platform, _platform_base, _platform_rim, _blob]:
			statics.append(child as Node3D)
	var batch: StaticBatch = StaticBatch.build(statics, env_root, "RoomBatch")
	if batch:
		env_root.add_child(batch)


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
	title.text = Loc.t("CAR PARTS")
	title.font_size = 128
	title.pixel_size = 0.0042
	title.modulate = Color("2F3236")
	title.position = Vector3(SIGN_X, 1.52, WALL_Z + 0.27)
	env_root.add_child(title)
	var subtitle: Label3D = Label3D.new()
	subtitle.name = "SignSubtitle"
	subtitle.text = Loc.t("AUTOMOTIVE  ·  SHOWROOM")
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
	# Yerleşim tamamen container'larla (2026-11-02 B taslağı): tepe satırı (solda GERİ, ortada tabela + KASALAR /
	# ARAÇLAR sekmesi, sağda KOLEKSİYON), orta satır (sol kasa listesi | sağ bilgi), alt satır (ARAÇLAR rafı).
	# Mutlak konum yok; ekran oranı değişse de plakalar yerinde kalır.
	var overlay: MarginContainer = MarginContainer.new()
	overlay.name = "Overlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: StringName in [&"margin_left", &"margin_right"]:
		overlay.add_theme_constant_override(side, 16)
	for side: StringName in [&"margin_top", &"margin_bottom"]:
		overlay.add_theme_constant_override(side, 12)
	add_child(overlay)

	var rows: VBoxContainer = VBoxContainer.new()
	rows.name = "Rows"
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override(&"separation", 8)
	overlay.add_child(rows)

	# Üst: solda GERİ + KASALAR / ARAÇLAR anahtarı, sağda KOLEKSİYON (2026-11-02 sekme yeri taslağı C, kullanıcı
	# seçti: MAĞAZA tabelası kalktı, sekmeler GERİ'ye bitişik koyu zeminli ikili anahtar)
	var top: HBoxContainer = _row(rows, "TopRow", Control.SIZE_SHRINK_BEGIN)
	_exit_group = HBoxContainer.new()
	_exit_group.name = "BackGroup"
	_exit_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_exit_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_exit_group.add_theme_constant_override(&"separation", 8)
	top.add_child(_exit_group)
	_exit_button = PlateButton.new()
	_exit_button.name = "ExitButton"
	_exit_button.theme_type_variation = &"HudPlateSmall"
	_exit_button.text = Loc.t("GERİ")
	_exit_button.focus_mode = Control.FOCUS_NONE
	_exit_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER   # anahtarın ortasına hizalı
	_exit_button.pressed.connect(close)
	_exit_group.add_child(_exit_button)

	_title_group = PanelContainer.new()
	_title_group.name = "TabSwitch"
	_title_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_group.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var backing: StyleBoxFlat = StyleBoxFlat.new()
	backing.bg_color = Color(HudPalette.LANE_TRACK, 0.94)
	backing.set_corner_radius_all(10)
	backing.set_content_margin_all(4.0)
	backing.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
	backing.shadow_size = 6
	backing.shadow_offset = Vector2(0.0, 3.0)
	backing.anti_aliasing = true
	_title_group.add_theme_stylebox_override(&"panel", backing)
	_exit_group.add_child(_title_group)
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.name = "Tabs"
	tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tabs.add_theme_constant_override(&"separation", 4)
	_title_group.add_child(tabs)
	_tab_crates = _tab_plate("TabCrates", Loc.t("KASALAR"), HudIcon.Kind.BOX, Tab.CRATES)
	_tab_cars = _tab_plate("TabCars", Loc.t("ARAÇLAR"), HudIcon.Kind.CAR, Tab.CARS)
	tabs.add_child(_tab_crates)
	tabs.add_child(_tab_cars)

	_side_group = HBoxContainer.new()
	_side_group.name = "SideGroup"
	_side_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_side_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side_group.alignment = BoxContainer.ALIGNMENT_END
	top.add_child(_side_group)
	var collection: PlateButton = PlateButton.new()
	collection.name = "CollectionButton"
	collection.theme_type_variation = &"HudPlateSmall"
	collection.kind = HudIcon.Kind.CAR
	collection.icon_left = true
	collection.text = Loc.t("KOLEKSİYON")
	collection.focus_mode = Control.FOCUS_NONE
	collection.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	collection.pressed.connect(func() -> void: screen_requested.emit(&"collection"))
	_side_group.add_child(collection)
	_collection_button = collection

	# Orta: solda kasa plakaları (KASALAR), sağda bilgi + satın alma
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
	# Başlık listenin DIŞINDA: kasalar kayarken yerinde durur (kullanıcı 2026-10-20). Liste başlık kadar kısaldı,
	# sütunun toplam boyu aynı kaldı.
	_list_group.add_child(_section_label(Loc.t("ARAÇ KASALARI")))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "List"
	scroll.custom_minimum_size = Vector2(LIST_WIDTH, 240.0)
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

	# ARAÇLAR: iki ödeme yolu yan yana (₺ → 24 saatte teslim, GEM → hemen); siparişteyken reklamla kısaltma
	_car_buttons = HBoxContainer.new()
	_car_buttons.name = "CarButtons"
	_car_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_car_buttons.custom_minimum_size = Vector2(INFO_WIDTH, 0.0)
	_car_buttons.add_theme_constant_override(&"separation", 8)
	_car_buttons.visible = false
	_info_group.add_child(_car_buttons)
	_cash_button = _pay_button("CashButton", HudIcon.Kind.COIN)
	_cash_button.pressed.connect(_on_pay_pressed.bind(PAY_CASH))
	_gem_button = _pay_button("GemButton", HudIcon.Kind.GEM)
	_gem_button.pressed.connect(_on_pay_pressed.bind(PAY_GEM))
	_car_buttons.add_child(_cash_button)
	_car_buttons.add_child(_gem_button)
	_ad_button = AdOfferButton.new(AdPolicy.CAR_DELIVERY, "", true)
	_ad_button.custom_minimum_size = Vector2(INFO_WIDTH, 48.0)
	_ad_button.condition = func() -> bool:
		return visible and _tab == Tab.CARS and _shown_vehicle != &"" and _shop() != null \
			and _shop().is_ordered(_shown_vehicle)
	_ad_button.reward_fn = func() -> String:
		var shop: CarShop = _shop()
		if shop == null:
			return ""
		var cut: int = shop.ad_cut_for(_shown_vehicle)
		return Loc.t("−%d SA") % ceili(cut / 3600.0) if cut >= 3600 else AdOfferButton.cut_text(float(cut))
	_ad_button.rewarded.connect(_on_delivery_ad)
	_info_group.add_child(_ad_button)

	# Alt: ARAÇLAR rafı (koyu raf; ARAÇLAR ekranındaki ve modifiye rafıyla aynı dil): süzgeç çipleri + araç kartları
	_tray = PanelContainer.new()
	_tray.name = "CarTray"
	_tray.add_theme_stylebox_override(&"panel", GarageScreen._tray_style(12))
	_tray.mouse_filter = Control.MOUSE_FILTER_STOP   # rafa dokunuş araç döndürmesin
	_tray.size_flags_vertical = Control.SIZE_SHRINK_END
	_tray.visible = false
	rows.add_child(_tray)
	var tray_box: VBoxContainer = VBoxContainer.new()
	tray_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray_box.add_theme_constant_override(&"separation", 6)
	_tray.add_child(tray_box)
	var head: HBoxContainer = HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override(&"separation", 8)
	tray_box.add_child(head)
	var chip_scroll: ScrollContainer = ScrollContainer.new()
	chip_scroll.name = "Chips"
	chip_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	chip_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	chip_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	TouchScroll.attach(chip_scroll)
	head.add_child(chip_scroll)
	_chip_box = HBoxContainer.new()
	_chip_box.add_theme_constant_override(&"separation", 6)
	chip_scroll.add_child(_chip_box)
	_tray_count = _label(&"HudOutlined", "")
	_tray_count.add_theme_font_size_override(&"font_size", 13)
	_tray_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_tray_count)
	_card_scroll = ScrollContainer.new()
	_card_scroll.name = "Cards"
	_card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_card_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	TouchScroll.attach(_card_scroll, true)   # kaydırınca akar, bırakınca en yakın karta oturur
	tray_box.add_child(_card_scroll)
	_card_strip = HBoxContainer.new()
	_card_strip.name = "Strip"
	_card_strip.add_theme_constant_override(&"separation", 6)
	_card_scroll.add_child(_card_strip)


## Üstteki KASALAR / ARAÇLAR sekmesi.
func _tab_plate(node_name: String, text: String, icon: HudIcon.Kind, tab: Tab) -> PlateButton:
	var plate: PlateButton = PlateButton.new()
	plate.name = node_name
	plate.theme_type_variation = &"HudPlateSmall"
	plate.kind = icon
	plate.icon_left = true
	plate.text = text
	plate.toggle_mode = true
	plate.button_group = _tab_group
	plate.bolts = false   # ikili anahtarın iki yarısı: vidasız, koyu zemine bitişik
	plate.focus_mode = Control.FOCUS_NONE
	plate.custom_minimum_size = Vector2(124.0, 0.0)
	plate.toggled.connect(func(pressed: bool) -> void:
		if pressed:
			_set_tab(tab))
	return plate


## ARAÇLAR ödeme düğmesi (₺ / GEM): yarım genişlik, ikon solda, iki satır.
func _pay_button(node_name: String, icon: HudIcon.Kind) -> PlateButton:
	var button: PlateButton = PlateButton.new()
	button.name = node_name
	button.theme_type_variation = &"HudPlate"
	button.kind = icon
	button.icon_left = true
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0.0, 50.0)
	return button


## Bilgi plakası orta satıra sığsın: kısa ekranda uzun oran listesinin yazısı küçülür (PurchasePlate.fit_height).
## Oda = ekran − kenar payları (2 × 16) − üst ve alt satır − satır aralıkları (2 × 8); plakanın altında 8 + SATIN AL.
func _fit_info() -> void:
	if _info_plate == null or not is_inside_tree():
		return
	var top: float = maxf(_title_group.get_combined_minimum_size().y, _exit_group.get_combined_minimum_size().y)
	var bottom: float = _tray.get_combined_minimum_size().y + 8.0 if _tray.visible else 0.0
	var room: float = get_viewport_rect().size.y - 24.0 - top - 8.0 - bottom
	for control: Control in [_buy_button, _car_buttons, _ad_button]:
		if control.visible:
			room -= 8.0 + control.get_combined_minimum_size().y
	_info_plate.fit_height(room)


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
	var shop: CarShop = _shop()
	if shop:
		shop.changed.connect(_on_shop_changed)


func _first_crate() -> StringName:
	var entries: Array[Dictionary] = CrateCatalog.all()
	return entries[0]["id"] if not entries.is_empty() else &""


## Kasalar + (varsa) GERİ AL bölümü. Keşfedilmiş araç listesi değiştiği için her açılışta kurulur.
func _rebuild_list() -> void:
	for child: Node in _list_box.get_children():
		child.queue_free()
	_plates.clear()
	var pending: Array[int] = _crates.undelivered() if _crates else []
	if not pending.is_empty():
		_list_box.add_child(_section_label(Loc.t("YOLDAKİ KASALAR")))
		for uid: int in pending:
			var crate_id: StringName = _crates.get_crate(uid).get("crate", &"")
			var name_text: String = Loc.t(String(CrateCatalog.get_entry(crate_id).get("display_name", Loc.t("KASA"))))
			var pending_plate: PlateButton = _list_plate("pending:%d" % uid, Loc.t("%s\nAÇ") % name_text, HudIcon.Kind.BOX)
			pending_plate.highlight = true
			pending_plate.toggled.connect(func(pressed: bool) -> void:
				if pressed:
					_show_pending(uid))
	var sale: int = LiveEvent.sale_percent(&"crates")
	for crate: Dictionary in CrateCatalog.all():
		var id: StringName = crate["id"]
		var label: String = Loc.t("%s\n%d GEM") % [Loc.t(String(crate["display_name"])), CrateCatalog.sale_price(id)]
		if sale > 0:   # canlı etkinlik indirimi
			label += "  " + sale_tag(sale)
		var boosted: bool = not LiveEvent.crate_boost(id).is_empty()
		if boosted:   # ETKİNLİK KASASI: seçili araçların şansı artmış
			label = "★ " + label
		var plate: PlateButton = _list_plate("crate:%s" % id, label, HudIcon.Kind.GEM)
		plate.highlight = boosted
		plate.toggled.connect(func(pressed: bool) -> void:
			if pressed:
				_show_crate(id))
	# Satılmış araçların GERİ AL'ı ARAÇLAR sekmesine taşındı (süzgeç çipi; mağaza araçları orada satılır)
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
	# Liste başlığı plakanın değil KOYU showroom duvarının üstünde durur: koyu mürekkep (HudPlateTitle) orada
	# zor okunuyordu (2026-10-11 QA karesi) → dünya üstü yazılar gibi konturlu açık yazı.
	var label: Label = _label(&"HudOutlined", text)
	label.add_theme_font_size_override(&"font_size", 15)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


## Seçili kasayı platforma ve bilgi plakasına koyar.
func _show_crate(crate_id: StringName) -> void:
	if _reveal_uid > 0 or crate_id == &"" or (crate_id == _shown_crate and _shown_vehicle == &"" and _shown_pending == 0):
		return
	if not CrateCatalog.exists(crate_id):
		push_warning("ShowroomScreen: '%s' kasası yok" % crate_id)
		return
	_shown_crate = crate_id
	_shown_vehicle = &""
	_shown_pending = 0
	var plate: PlateButton = _plates.get("crate:%s" % crate_id)
	if plate:
		plate.set_pressed_no_signal(true)
	_load_crate_preview(crate_id)
	_refresh_state()


## GERİ AL listesindeki (keşfedilmiş, satılmış) aracı platforma koyar. Aynı anda tek model yüklenir.
func _show_vehicle(vehicle_id: StringName) -> void:
	if _reveal_uid > 0 or vehicle_id == &"" or vehicle_id == _shown_vehicle:
		return
	var entry: Dictionary = CarCatalog.get_entry(vehicle_id)
	if entry.is_empty():
		push_warning("ShowroomScreen: katalogda '%s' yok" % vehicle_id)
		return
	_shown_vehicle = vehicle_id
	_shown_crate = &""
	_shown_pending = 0
	_confirm = &""
	var card: PlateButton = _cards.get(vehicle_id)
	if card:
		card.set_pressed_no_signal(true)
	_load_preview(entry["scene_path"])
	_refresh_state()


func _refresh_state() -> void:
	if _reveal_uid > 0:
		return   # açılış sahnesi plakayı kendisi yazar (ödül gem / sahiplik sinyalleri burayı çağırır)
	if _tab == Tab.CARS:
		_refresh_cards()
		if _shown_vehicle != &"" and CarShop.is_for_sale(_shown_vehicle):
			_refresh_shop_car()
		elif _shown_vehicle != &"":
			_refresh_vehicle()
		return
	if _shown_pending > 0:
		_refresh_pending()
	elif _shown_crate != &"":
		_refresh_crate()
	elif _shown_vehicle != &"":
		_refresh_vehicle()


# --- Yoldaki kasa: burada açılır -----------------------------------------------------

func _first_pending() -> int:
	var pending: Array[int] = _crates.undelivered() if _crates else []
	return pending[0] if not pending.is_empty() else 0


## Yoldaki kasayı platforma koyar (içerik gizli). Aracın modeli şimdiden arka planda yüklenir: AÇ'ta beklenmesin.
func _show_pending(uid: int) -> void:
	if _reveal_uid > 0 or _crates == null or not _crates.waiting_for_room(uid):
		return
	var crate: Dictionary = _crates.get_crate(uid)
	_shown_pending = uid
	_shown_crate = &""
	_shown_vehicle = &""
	_press_plate("pending:%d" % uid)
	_load_crate_preview(crate["crate"])
	CrateDelivery.prefetch_vehicle(crate.get("vehicle", &""))
	_refresh_state()


## Sıradaki yoldaki kasa, yoksa ilk mağaza kasası.
func _show_default() -> void:
	var next: int = _first_pending()
	if next > 0:
		_show_pending(next)
		return
	_shown_pending = 0
	_shown_crate = &""
	_show_crate(_first_crate())


func _press_plate(key: String) -> void:
	var plate: PlateButton = _plates.get(key)
	if plate:
		plate.set_pressed_no_signal(true)


## Yoldaki kasa plakası: garajdaki kasaya dokununca çıkan soru plakasıyla aynı metin (olasılıklar, içerik gizli).
func _refresh_pending() -> void:
	if _crates == null or not _crates.waiting_for_room(_shown_pending):
		# Bu arada garaja indi (yer açıldı) ya da açıldı: liste tazelenir
		_shown_pending = 0
		_rebuild_list()
		_show_default()
		return
	var content: Dictionary = CratePanel.prompt_content(_crates.get_crate(_shown_pending).get("crate", &""))
	_info_plate.set_content(content["title"], Loc.t("YOLDA  ·  GARAJDA YER YOK"), content["headline"], content["lines"])
	_buy_button.kind = HudIcon.Kind.BOX
	_buy_button.text = Loc.t("KASAYI AÇ")
	_buy_button.disabled = false


## KASAYI AÇ: ödül verilir + kaydedilir (CrateManager.open), sonra sahne platformda oynar.
func _open_pending(uid: int) -> void:
	var crate: CrateVisual = _preview as CrateVisual
	if _crates == null or crate == null or _reveal_uid > 0:
		return
	# Bayrak open()'dan ÖNCE: open() kasalar / gem / sahiplik sinyallerini yayar, _refresh_state listeyi tazeleyip
	# platformdaki kasayı (sahnesi oynayacak olanı) sıradakiyle değiştiriyordu (QA: kasa kıpırdamadı)
	_reveal_uid = uid
	var result: Dictionary = _crates.open(uid)
	if result.is_empty():
		_reveal_uid = 0
		_rebuild_list()
		_show_default()
		return
	_reveal_done = false
	_shown_pending = 0
	_set_reveal_chrome(true)
	_info_plate.set_content(Loc.t(String(CrateCatalog.get_entry(result["crate"]).get("display_name", Loc.t("KASA")))),
		Loc.t("AÇILIYOR…"), "???", PackedStringArray())
	_buy_button.text = Loc.t("AÇILIYOR…")
	_buy_button.disabled = true
	_play_reveal(uid, crate, result)


## Garajdaki açılışın aynısı (gerilim → patlama → araç dönerek yükselip platforma iner); sonra boş kasa çöker,
## araç vitrinde kalır ve sonuç plakası gelir. Her beklemeden sonra showroom'un kapanıp kapanmadığına bakılır.
func _play_reveal(uid: int, crate: CrateVisual, result: Dictionary) -> void:
	var style: Array = CrateDelivery.reveal_style(result)
	var rank: int = style[0]
	CrateDelivery.prefetch_vehicle(result["vehicle"])
	_spin_velocity = 0.0
	var fx: CrateRevealFx = CrateDelivery.reveal_effects(_model_slot, crate, style[1], rank, PLATFORM_HEIGHT)
	_reveal_fx = fx
	fx.suspense(CrateVisual.suspense_time(rank))
	crate.burst_open.connect(fx.burst, CONNECT_ONE_SHOT)
	crate.lid_vanished.connect(fx.poof, CONNECT_ONE_SHOT)
	await crate.play_open(rank)
	if _reveal_uid != uid:
		return
	var car: Node3D = await CrateDelivery.make_vehicle(_model_slot, result["vehicle"])
	if _reveal_uid != uid:
		if is_instance_valid(car):
			car.queue_free()
		return
	if car:
		# Burun kasanın uzun ekseni (yerel +X) boyunca: model önü +Z
		car.rotation.y = crate.rotation.y + PI * 0.5
		car.global_position = crate.to_global(crate.vehicle_anchor()) - Vector3(0.0, 0.02, 0.0)
		await CrateDelivery.rise(car, fx, rank, PLATFORM_HEIGHT)
		if _reveal_uid != uid:
			return
		# Boş kasa çöker, ışıklar söner; araç platformun ortasına oturur ve vitrin dönüşü sürer
		var vanish: Tween = crate.create_tween()
		vanish.tween_property(crate, "scale", Vector3(1.0, 0.01, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		vanish.tween_callback(crate.queue_free)
		fx.fade_out(0.6)
		_preview = car
		_fit_to_platform(0.6, true)
	_show_reveal_result(result)


func _show_reveal_result(result: Dictionary) -> void:
	_reveal_done = true
	_idle_time = 0.0
	var content: Dictionary = CratePanel.result_content(result)
	_info_plate.set_content(content["title"], content["subtitle"], content["headline"], content["lines"])
	_buy_button.kind = HudIcon.Kind.CHECK
	_buy_button.text = Loc.t("TAMAM")
	_buy_button.disabled = false


## TAMAM: kasa kapanır (CLAIMED), liste tazelenir; sıradaki yoldaki kasa ya da mağaza kasası gelir.
func _finish_reveal() -> void:
	_end_reveal()
	_rebuild_list()
	_show_default()


func _end_reveal() -> void:
	var uid: int = _reveal_uid
	_reveal_uid = 0
	_reveal_done = false
	if is_instance_valid(_reveal_fx):
		_reveal_fx.queue_free()
	_reveal_fx = null
	_set_reveal_chrome(false)
	if _crates and uid > 0:
		_crates.claim(uid)


## Sahne sürerken liste gizlenir, GERİ / KOLEKSİYON kilitlenir (yarıda kapatılıp ödül görülmeden geçilmesin).
func _set_reveal_chrome(on: bool) -> void:
	_list_group.visible = not on
	_exit_button.disabled = on
	_collection_button.disabled = on
	_tab_crates.disabled = on
	_tab_cars.disabled = on


## Kasa plakası: fiyat, seviye şartı ve havuzdaki her aracın GERÇEK olasılığı (açık oranlar).
func _refresh_crate() -> void:
	var entry: Dictionary = CrateCatalog.get_entry(_shown_crate)
	var lines: PackedStringArray = PackedStringArray()
	var price: int = CrateCatalog.sale_price(_shown_crate)
	var sale: int = LiveEvent.sale_percent(&"crates")
	if sale > 0:
		lines.append(Loc.t("ETKİNLİK İNDİRİMİ %s · %d → %d GEM") % [sale_tag(sale), CrateCatalog.price(_shown_crate), price])
	var boost: Dictionary = LiveEvent.crate_boost(_shown_crate)
	if not boost.is_empty():
		lines.append(Loc.t("★ ETKİNLİK KASASI: işaretli araçların şansı ×%s") % Loc.decimal(float(boost.values()[0]), 1)
			.trim_suffix(",0").trim_suffix(".0"))
	for row: Dictionary in CrateCatalog.odds(_shown_crate):
		var car: Dictionary = CarCatalog.get_entry(row["id"])
		var mark: String = "✔ " if _ownership and _ownership.is_owned(row["id"]) else ""
		if float(row.get("boost", 1.0)) > 1.0:
			mark = "★ " + mark
		lines.append("%s%s  %s · %s" % [mark, Loc.percent(Loc.decimal(float(row["chance"]) * 100.0)),
			String(car.get("display_name", row["id"])).to_upper(), CrateCatalog.rarity_label(row["rarity"])])
	if _progress and _progress.gems < price:
		lines.append(Loc.t("GEM: GÜNLÜK GİRİŞ · GÖREVLER · SEVİYE · USTALIK"))   # gem nereden gelir (QA: anlatılmıyordu)
	_info_plate.set_content(Loc.t(String(entry["display_name"])),
		Loc.t("ARAÇ TESLİMAT KASASI  ·  SV %d+") % int(entry["min_level"]), Loc.t("%d GEM") % price, lines)
	_fit_info()
	_buy_button.kind = HudIcon.Kind.GEM
	var reason: String = _crates.buy_block_reason(_shown_crate) if _crates else "unknown"
	if _closing_after_buy:
		reason = "busy"
	match reason:
		"":
			_buy_button.text = Loc.t("SATIN AL\n%d GEM") % price
			_buy_button.disabled = false
		"level":
			_buy_button.text = Loc.t("SEVİYE %d\nGEREKLİ") % int(entry["min_level"])
			_buy_button.disabled = true
		"gems":
			# Gem yetmiyor: plaka GEM MAĞAZASI'nı açar (mağaza bu cihazda yoksa eski "yetersiz" hali)
			_buy_button.text = Loc.t("GEM YETERSİZ\nGEM AL") if _gem_store_available() else Loc.t("%d GEM\nGEM YETERSİZ") % price
			_buy_button.disabled = not _gem_store_available()
		"full":
			_buy_button.text = Loc.t("ÖNCE BEKLEYEN\nKASALARI AÇ")
			_buy_button.disabled = true
		_:
			_buy_button.text = Loc.t("%d GEM") % price
			_buy_button.disabled = true


## İndirim etiketi: "−%30" (dile göre yüzde biçimi).
static func sale_tag(percent: int) -> String:
	return "−" + Loc.percent(str(percent))


func _gem_store_available() -> bool:
	var purchases: PurchaseManager = get_tree().get_first_node_in_group("purchases") as PurchaseManager
	return purchases != null and purchases.is_available()


## GERİ AL plakası: keşfedilmiş aracın ₺ fiyatı (VehicleOwnership.status kararı).
func _refresh_vehicle() -> void:
	_buy_button.visible = true
	_car_buttons.visible = false
	var entry: Dictionary = CarCatalog.get_entry(_shown_vehicle)
	var price: int = _ownership.buy_price(_shown_vehicle) if _ownership else int(entry.get("price", 0))
	var lines: PackedStringArray = ProgressionEffects.vehicle_lines(get_tree(), _shown_vehicle)
	var sale: int = LiveEvent.sale_percent(&"cars")
	if sale > 0:
		lines.insert(0, Loc.t("ETKİNLİK İNDİRİMİ %s · %s → %s ₺") % [sale_tag(sale),
			Hud.format_thousands(int(entry.get("price", 0))), Hud.format_thousands(price)])
	_info_plate.set_content(
		"%s %s" % [String(entry.get("brand", "")).to_upper(), String(entry.get("model", "")).to_upper()],
		ProgressionEffects.vehicle_subtitle(_shown_vehicle),
		"%s ₺" % Hud.format_thousands(price), lines)
	_buy_button.kind = HudIcon.Kind.COIN
	if _ownership == null:
		_buy_button.text = Hud.format_thousands(price)   # düğmede para simgesi var
		_buy_button.disabled = true
		return
	match _ownership.status(_shown_vehicle):
		VehicleOwnership.Status.OWNED:
			_buy_button.text = Loc.t("SAHİPSİN")
			_buy_button.disabled = true
		VehicleOwnership.Status.TOO_EXPENSIVE:
			_buy_button.text = Hud.coinless(Loc.t("%s ₺\nPARA YETERSİZ") % Hud.format_thousands(price))
			_buy_button.disabled = true
		VehicleOwnership.Status.UNDISCOVERED:
			_buy_button.text = Loc.t("KASADAN ÇIKAR")
			_buy_button.disabled = true
		_:
			_buy_button.text = Hud.coinless(Loc.t("GERİ AL\n%s ₺") % Hud.format_thousands(price))
			_buy_button.disabled = false


func _on_buy_pressed() -> void:
	# Çift dokunuş: satın alma showroom'u kapatır; kapanış animasyonu sırasında (ya da aynı karede
	# ikinci basışta) ikinci bir kasa alınmasın.
	if _closing or not visible:
		return
	if _reveal_uid > 0:
		if _reveal_done:
			_finish_reveal()
		return
	if _shown_pending > 0:
		_open_pending(_shown_pending)
		return
	if _shown_crate != &"":
		if _crates == null:
			return
		if _crates.buy_block_reason(_shown_crate) == "gems":
			screen_requested.emit(&"gem_store")
			return
		var uid: int = _crates.buy(_shown_crate)   # gem + sonuç + kayıt CrateManager'da
		if uid > 0 and _crates.waiting_for_room(uid):
			# Teslimat aynı çağrıda denendi, garajda yer yok: showroom kapanmaz, kasa YOLDAKİ KASALAR'da seçili gelir
			_rebuild_list()
			_show_pending(uid)
			return
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
		if _tab == Tab.CARS:
			_rebuild_tray(_shown_vehicle)
	_refresh_state()


# --- ARAÇLAR sekmesi: araç mağazası (2026-11-02, B taslağı) ------------------------------------
# Raf: süzgeç çipleri (TÜMÜ · kasa aileleri · YOLDA · GERİ AL) + araç kartları. Sağdaki plaka fiyatı ve durumu yazar;
# iki ödeme düğmesi: ₺ (sipariş, 24 saatte teslim) ve GEM (hemen). Yalnız gem araçta ₺ düğmesi yoktur. Siparişteki
# araçta ödüllü reklam düğmesi teslimi 8 saat öne çeker. Para / sipariş / teslim mantığı CarShop'tadır.

func _shop() -> CarShop:
	return get_tree().get_first_node_in_group("car_shop") as CarShop if is_inside_tree() else null


func _shift_target() -> Vector2:
	return CARS_VIEW_SHIFT if _tab == Tab.CARS else Vector2.ZERO


## Sekme düğmeleri, görünürlük ve kadraj (içerik seçmez).
func _apply_tab_chrome(tab: Tab) -> void:
	_tab = tab
	_last_tab = tab
	(_tab_crates if tab == Tab.CRATES else _tab_cars).set_pressed_no_signal(true)
	# Küçük plakanın basılı hâli normalinden zor ayrılıyor: açık sekme amber vurguyla belli olur
	_tab_crates.highlight = tab == Tab.CRATES
	_tab_cars.highlight = tab == Tab.CARS
	var cars: bool = tab == Tab.CARS
	_list_group.visible = not cars
	_tray.visible = cars
	_buy_button.visible = not cars
	_car_buttons.visible = cars
	_confirm = &""
	_zoom_target = CARS_ZOOM if cars else 1.0
	_ad_button.refresh()


func _set_tab(tab: Tab) -> void:
	if _reveal_uid > 0:
		return
	_apply_tab_chrome(tab)
	if tab == Tab.CARS:
		var focus: StringName = _open_on_car
		_open_on_car = &""
		_rebuild_tray(focus)
	else:
		_shown_vehicle = &""
		_show_default()
	_fit_info()


## Raf baştan: çipler + seçili süzgecin kartları. `focus`: seçilecek araç (verilmezse süzgecin ilk alınabilir aracı).
func _rebuild_tray(focus: StringName = &"") -> void:
	_rebuild_chips()
	var family: StringName = _family
	if focus != &"":
		family = CarShop.family_of(focus) if CarShop.is_for_sale(focus) else CHIP_BUYBACK
	if family == &"" or not _chips.has(family):
		family = _default_family()
	_select_family(family, focus)


func _rebuild_chips() -> void:
	for child: Node in _chip_box.get_children():
		child.queue_free()
	_chips.clear()
	_chip_group = ButtonGroup.new()
	var shop: CarShop = _shop()
	if shop and shop.order_count() > 0:
		var orders: PlateButton = _add_chip(CHIP_ORDERS, Loc.t("YOLDA"))
		orders.badge = shop.order_count()
	_add_chip(CHIP_ALL, Loc.t("TÜMÜ"))
	for crate: Dictionary in CrateCatalog.all():
		_add_chip(crate["id"], Loc.t(String(crate.get("short_name", crate["id"]))))
	if not _buyback_ids().is_empty():
		_add_chip(CHIP_BUYBACK, Loc.tc("GERİ AL", "showroom"))


func _add_chip(id: StringName, text: String) -> PlateButton:
	var chip: PlateButton = PlateButton.new()
	chip.name = "Chip_" + String(id)
	chip.theme_type_variation = &"HudPlateSmall"
	chip.text = text
	chip.toggle_mode = true
	chip.button_group = _chip_group
	chip.bolts = false
	chip.focus_mode = Control.FOCUS_NONE
	chip.mouse_filter = Control.MOUSE_FILTER_PASS   # çip şeridi parmakla kaysın
	chip.toggled.connect(func(pressed: bool) -> void:
		if pressed:
			_select_family(id))
	_chip_box.add_child(chip)
	_chips[id] = chip
	return chip


## Açılışta seçili süzgeç: yolda sipariş varsa YOLDA, yoksa oyuncunun seviyesinin açtığı en üst kasa ailesi.
func _default_family() -> StringName:
	var shop: CarShop = _shop()
	if shop and shop.order_count() > 0:
		return CHIP_ORDERS
	var level: int = _progress.level if _progress else 1
	var best: StringName = &""
	for crate: Dictionary in CrateCatalog.all():
		if best == &"" or CrateCatalog.min_level(crate["id"]) <= level:
			best = crate["id"]
	return best if best != &"" else CHIP_ALL


func _family_ids(family: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	match family:
		CHIP_ALL:
			out.assign(CarShop.ids())
		CHIP_BUYBACK:
			out = _buyback_ids()
		CHIP_ORDERS:
			var shop: CarShop = _shop()
			for order: Dictionary in shop.orders() if shop else []:
				out.append(order["id"])
		_:
			for id: StringName in CarShop.ids():
				if CarShop.family_of(id) == family:
					out.append(id)
	return out


## Satılmış (keşfedilmiş) ama mağazada olmayan araçlar: eski GERİ AL (değer fiyatına, hemen). Hurdalık aracı
## burada da alınmaz (yalnız yeniden restore edilir).
func _buyback_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	if _ownership == null:
		return out
	for id: StringName in _ownership.discovered_ids():
		if not _ownership.is_owned(id) and not RestorationCatalog.is_restoration(id) and not CarShop.is_for_sale(id):
			out.append(id)
	return out


func _select_family(family: StringName, focus: StringName = &"") -> void:
	_family = family
	for key: StringName in _chips:   # seçili çip amber (basılı küçük plaka normalinden zor ayrılıyor)
		var each: PlateButton = _chips[key]
		each.highlight = key == family
		if key == family:
			each.set_pressed_no_signal(true)
	for child: Node in _card_strip.get_children():
		child.queue_free()
	_cards.clear()
	_card_group = ButtonGroup.new()
	var ids: Array[StringName] = _family_ids(family)
	for id: StringName in ids:
		_add_car_card(id)
	_refresh_cards()
	var pick: StringName = focus if ids.has(focus) else _default_car(ids)
	if pick == &"":
		return
	if pick == _shown_vehicle:
		(_cards[pick] as PlateButton).set_pressed_no_signal(true)
		_refresh_state()
	else:
		_show_vehicle(pick)
	_scroll_to_card.call_deferred(pick)


## Süzgecin ilk alınabilir aracı; yoksa ilk yoldaki; yoksa ilk araç.
func _default_car(ids: Array[StringName]) -> StringName:
	var shop: CarShop = _shop()
	if shop:
		for state: int in [CarShop.State.AVAILABLE, CarShop.State.ORDERED]:
			for id: StringName in ids:
				if shop.state_of(id) == state:
					return id
	return ids[0] if not ids.is_empty() else &""


## Kartlar yerleştikten sonra (iki kare) seçili karta kaydırır; hemen kaydırınca boyutsuz kartlarla yanlış yere gidiyordu.
func _scroll_to_card(id: StringName) -> void:
	for i: int in 2:
		await get_tree().process_frame
		if not is_inside_tree():
			return
	var card: PlateButton = _cards.get(id)
	if card and is_instance_valid(card) and _card_scroll:
		_card_scroll.ensure_control_visible(card)


func _add_car_card(id: StringName) -> void:
	var card: PlateButton = PlateButton.new()
	card.name = "Car_" + String(id)
	card.theme_type_variation = &"HudGalleryPlate"
	card.kind = HudIcon.Kind.NONE
	card.bolts = false
	card.toggle_mode = true
	card.button_group = _card_group
	card.focus_mode = Control.FOCUS_NONE
	card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	# PASS: parmakla sürükleme rafı kaydırsın (dokunuş yine kartı seçer; GARAJI DÜZENLE şeridiyle aynı)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.draw.connect(_draw_car_card.bind(card, id))
	card.toggled.connect(func(pressed: bool) -> void:
		if pressed:
			_show_vehicle(id))
	_card_strip.add_child(card)
	_cards[id] = card


## Kart yazıları (ad + fiyat / durum) ve raf sayacı; çizimler (kilit, YOLDA, sende) yeniden.
func _refresh_cards() -> void:
	var owned: int = 0
	for id: StringName in _cards:
		var card: PlateButton = _cards[id]
		if not is_instance_valid(card):
			continue
		card.text = _card_status(id)   # ad sağdaki plakada (yazı en az 14 punto: ad karta sığmıyordu)
		card.queue_redraw()
		if _ownership and _ownership.is_owned(id):
			owned += 1
	if _tray_count:
		_tray_count.text = Loc.t("%d / %d SENDE") % [owned, _cards.size()] if _family != CHIP_ORDERS \
				and _family != CHIP_BUYBACK else ""


func _card_status(id: StringName) -> String:
	var shop: CarShop = _shop()
	if not CarShop.is_for_sale(id) or shop == null:
		return "%s ₺" % Hud.format_thousands(_ownership.buy_price(id) if _ownership else 0)
	match shop.state_of(id):
		CarShop.State.OWNED:
			return Loc.t("SAHİPSİN")
		CarShop.State.ORDERED:   # YOLDA etiketi küçük resmin köşesinde; burada yalnız kalan süre
			var left: int = shop.time_left(id)
			return Loc.t("%d sa") % ceili(left / 3600.0) if left >= 3600 else Loc.t("%d dk") % maxi(ceili(left / 60.0), 1)
		CarShop.State.LOCKED:
			return Loc.t("SEVİYE %d") % CarShop.required_level(id)
	if CarShop.is_gem_only(id):
		return Loc.t("%s GEM") % Hud.format_thousands(CarShop.gem_price(id))
	return "%s ₺" % Hud.format_thousands(CarShop.tl_price(id))


func _draw_car_card(card: PlateButton, id: StringName) -> void:
	var area: Rect2 = Rect2(Vector2((card.size.x - THUMB_AREA.x) * 0.5, THUMB_TOP), THUMB_AREA)
	var shop: CarShop = _shop()
	var state: int = shop.state_of(id) if shop else CarShop.State.NOT_FOR_SALE
	if CarShop.is_gem_only(id):
		# YALNIZ GEM: dekordaki LÜKS kartla aynı dil (koyu vitrin zemini, altın çerçeve, köşede elmas)
		var back: StyleBoxFlat = StyleBoxFlat.new()
		back.bg_color = GarageEditScreen.LUXURY_BACK
		back.set_corner_radius_all(8)
		back.anti_aliasing = true
		card.draw_style_box(back, area.grow(3.0))
		var rim: StyleBoxFlat = StyleBoxFlat.new()
		rim.draw_center = false
		rim.border_color = GarageEditScreen.LUXURY_GOLD
		rim.set_border_width_all(3)
		rim.set_corner_radius_all(9)
		rim.anti_aliasing = true
		card.draw_style_box(rim, Rect2(Vector2(3.0, 3.0), card.size - Vector2(6.0, 6.0)))
	var texture: Texture2D = _thumb_of(id)
	var dim: bool = state == CarShop.State.LOCKED or state == CarShop.State.OWNED
	if texture:
		var s: Vector2 = texture.get_size()
		var k: float = minf(area.size.x / s.x, area.size.y / s.y)
		var drawn: Vector2 = s * k
		card.draw_texture_rect(texture, Rect2(area.get_center() - drawn * 0.5, drawn), false,
			Color(1.0, 1.0, 1.0, 0.45) if dim else Color.WHITE)
	if CarShop.is_gem_only(id):
		HudIcon.draw_icon(card, HudIcon.Kind.GEM, area.position + Vector2(10.0, 10.0), 16.0, HudPalette.GEM,
			GarageEditScreen.LUXURY_BACK)
	match state:
		CarShop.State.LOCKED:
			var center: Vector2 = area.get_center()
			card.draw_circle(center, 15.0, Color(HudPalette.PLATE, 0.94), true, -1.0, true)
			card.draw_arc(center, 15.0, 0.0, TAU, 28, Color(HudPalette.INK, 0.35), 1.5, true)
			HudIcon.draw_icon(card, HudIcon.Kind.LOCK, center, 18.0, HudPalette.INK, HudPalette.PLATE)
		CarShop.State.OWNED:
			var mark: Vector2 = Vector2(area.end.x - 6.0, area.position.y + 6.0)
			card.draw_circle(mark, 11.0, HudPalette.GRASS, true, -1.0, true)
			HudIcon.draw_icon(card, HudIcon.Kind.CHECK, mark, 14.0, HudPalette.TEXT_LIGHT, HudPalette.GRASS)
		CarShop.State.ORDERED:
			_draw_chip(card, area, Loc.t("YOLDA"), HudPalette.COIN_DARK)


## Kartın sol üstünde küçük renkli etiket (YOLDA).
func _draw_chip(card: PlateButton, area: Rect2, text: String, color: Color) -> void:
	var font: Font = card.get_theme_font(&"font")
	var font_size: int = 10
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 12.0
	var chip: Rect2 = Rect2(area.position + Vector2(-4.0, -3.0), Vector2(width, 18.0))
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(6)
	box.anti_aliasing = true
	card.draw_style_box(box, chip)
	card.draw_string(font, chip.position + Vector2(6.0, 13.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
		HudPalette.TEXT_LIGHT)


## Fabrika görünümündeki küçük resim (önceden çizilmiş; boyalı hâl değil: mağaza fabrika aracını satar).
static func _thumb_of(id: StringName) -> Texture2D:
	if _thumbs.has(id):
		return _thumbs[id]
	var path: String = THUMB_DIR + String(id) + ".png"
	var texture: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_thumbs[id] = texture
	return texture


## Mağaza aracının plakası ve ödeme düğmeleri.
func _refresh_shop_car() -> void:
	var id: StringName = _shown_vehicle
	var shop: CarShop = _shop()
	if shop == null:
		return
	var entry: Dictionary = CarCatalog.get_entry(id)
	var state: int = shop.state_of(id)
	var gem_only: bool = CarShop.is_gem_only(id)
	var tl: int = CarShop.tl_price(id)
	var gems: int = CarShop.gem_price(id)
	var subtitle: String = "%s  ·  %s" % [CrateCatalog.rarity_label(CrateCatalog.rarity_of(id)),
		ProgressionEffects.vehicle_subtitle(id)]
	var price: String = Loc.t("%s GEM") % Hud.format_thousands(gems) if gem_only \
		else Loc.t("%s ₺  ·  %s GEM") % [Hud.format_thousands(tl), Hud.format_thousands(gems)]
	var lines: PackedStringArray = PackedStringArray()
	var sale: int = LiveEvent.sale_percent(&"cars")
	if sale > 0 and state == CarShop.State.AVAILABLE:
		lines.append(Loc.t("ETKİNLİK İNDİRİMİ %s") % sale_tag(sale))
	match state:
		CarShop.State.OWNED:
			price = Loc.t("SAHİPSİN")
		CarShop.State.ORDERED:
			price = Loc.t("YOLDA  ·  %s") % _clock(shop.time_left(id))
			lines.append(Loc.t("SÜRE BİTİNCE GARAJINA GELİR"))
			lines.append(Loc.t("HER REKLAM %d SAAT KISALTIR") % int(CarShop.ad_cut_seconds() / 3600))
		CarShop.State.LOCKED:
			lines.append(Loc.t("SEVİYE %d GEREKLİ (şu an %d)") % [CarShop.required_level(id),
				_progress.level if _progress else 1])
		_:
			# ₺ / gem yolları düğmelerde yazar ("24 SAATTE GELİR", "HEMEN GELİR"); burada yalnız gem şartı
			if gem_only:
				lines.append(Loc.t("YALNIZ GEMLE SATILIR · HEMEN GELİR"))
	lines.append(Loc.t("GARAJ DEĞERİ +%s ₺") % Hud.format_thousands(CarShop.value_of(id)))
	_info_plate.set_content("%s %s" % [String(entry.get("brand", "")).to_upper(), String(entry.get("model", "")).to_upper()],
		subtitle, price, lines)
	_write_pay_buttons(id, state)
	_ad_button.refresh()
	_fit_info()


func _write_pay_buttons(id: StringName, state: int) -> void:
	var shop: CarShop = _shop()
	var gem_only: bool = CarShop.is_gem_only(id)
	_buy_button.visible = false
	_car_buttons.visible = state != CarShop.State.ORDERED
	_cash_button.highlight = false
	_gem_button.highlight = false
	match state:
		CarShop.State.OWNED:
			_cash_button.visible = true
			_cash_button.kind = HudIcon.Kind.CHECK
			_cash_button.text = Loc.t("SAHİPSİN")
			_cash_button.disabled = true
			_gem_button.visible = false
			return
		CarShop.State.LOCKED:
			_cash_button.visible = true
			_cash_button.kind = HudIcon.Kind.LOCK
			_cash_button.text = Loc.t("SEVİYE %d\nGEREKLİ") % CarShop.required_level(id)
			_cash_button.disabled = true
			_gem_button.visible = false
			return
		CarShop.State.ORDERED:
			return
	_cash_button.kind = HudIcon.Kind.COIN
	_cash_button.visible = not gem_only
	if not gem_only:
		var tl: String = Hud.format_thousands(CarShop.tl_price(id))
		if shop.money_block(id) == CarShop.BLOCK_MONEY:
			_cash_button.text = Hud.coinless(Loc.t("%s ₺\nPARA YETERSİZ") % tl)   # düğmede para simgesi var
			_cash_button.disabled = true
		elif _confirm == PAY_CASH:
			_cash_button.text = Hud.coinless(Loc.t("EMİN MİSİN?\n%s ₺") % tl)
			_cash_button.highlight = true
			_cash_button.disabled = false
		else:
			_cash_button.text = Hud.coinless(Loc.t("%s ₺\n%d SAATTE GELİR") % [tl, int(CarShop.delivery_seconds() / 3600)])
			_cash_button.disabled = false
	_gem_button.visible = true
	var gems: int = CarShop.gem_price(id)
	var gem_text: String = Hud.format_thousands(gems)
	if shop.gem_block(id) == CarShop.BLOCK_GEMS:
		# Gem yetmiyor: düğme GEM MAĞAZASI'nı açar (mağaza bu cihazda yoksa kapalı)
		_gem_button.text = Loc.t("GEM YETERSİZ\nGEM AL") if _gem_store_available() \
			else Loc.t("%s GEM\nGEM YETERSİZ") % gem_text
		_gem_button.disabled = not _gem_store_available()
	elif _confirm == PAY_GEM:
		_gem_button.text = Loc.t("EMİN MİSİN?\n%s GEM") % gem_text
		_gem_button.highlight = true
		_gem_button.disabled = false
	else:
		_gem_button.text = Loc.t("%s GEM\nHEMEN GELİR") % gem_text
		_gem_button.disabled = false


## Ödeme: ilk dokunuş EMİN MİSİN? sorar (büyük tutar yanlışlıkla gitmesin), ikinci dokunuş öder.
func _on_pay_pressed(pay: StringName) -> void:
	var shop: CarShop = _shop()
	var id: StringName = _shown_vehicle
	if _closing or shop == null or id == &"" or _tab != Tab.CARS:
		return
	if pay == PAY_GEM and shop.gem_block(id) == CarShop.BLOCK_GEMS:
		if _gem_store_available():
			screen_requested.emit(&"gem_store")
		return
	if _confirm != pay or Time.get_ticks_msec() - _confirm_at > CONFIRM_MS:
		_confirm = pay
		_confirm_at = Time.get_ticks_msec()
		_refresh_state()
		return
	_confirm = &""
	if pay == PAY_GEM:
		if shop.buy_with_gems(id):
			vehicle_purchased.emit(id)
	elif shop.order_with_money(id):
		vehicle_ordered.emit(id)
	_refresh_state()


## Ödüllü reklam izlendi: sipariş 8 saat öne; süre biterse araç hemen gelir (CarShop teslim eder).
func _on_delivery_ad() -> void:
	var shop: CarShop = _shop()
	if shop and _shown_vehicle != &"":
		shop.cut_with_ad(_shown_vehicle)
	_refresh_state()


## Sipariş eklendi / teslim edildi / reklamla kısaldı: YOLDA çipi ve kartlar tazelenir.
func _on_shop_changed() -> void:
	if not visible or _tab != Tab.CARS or _reveal_uid > 0:
		return
	var shop: CarShop = _shop()
	var has_orders_chip: bool = _chips.has(CHIP_ORDERS)
	if shop and (shop.order_count() > 0) != has_orders_chip:
		_rebuild_tray(_shown_vehicle)   # YOLDA çipi geldi / gitti
	else:
		var chip: PlateButton = _chips.get(CHIP_ORDERS)
		if chip and shop:
			chip.badge = shop.order_count()
		if _family == CHIP_ORDERS:
			_select_family(CHIP_ORDERS, _shown_vehicle)
	_refresh_state()


## Saniyelik: siparişin geri sayımı, EMİN MİSİN?'in süresi.
func _on_second() -> void:
	if _confirm != &"" and Time.get_ticks_msec() - _confirm_at > CONFIRM_MS:
		_confirm = &""
		_refresh_state()
		return
	var shop: CarShop = _shop()
	if shop and shop.order_count() > 0:
		_refresh_state()


## "16:23:05" (saat:dk:sn).
static func _clock(seconds: int) -> String:
	var s: int = maxi(seconds, 0)
	return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]


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
	_preview_rig.optimize(true)   # vitrin aracı tekeriyle döner (kök dönüşü): parçalar birleşir
	_fit_to_platform()


## Modeli platformun üstüne oturtur, platformu ve kamerayı aracın boyutuna göre ayarlar. `duration` > 0: önceki
## kadrajdan yumuşak geçiş (kasadan çıkan araç vitrine oturunca). `in_slot`: sınırlar ModelSlot uzayında ölçülür —
## kasadan çıkan araç slotun ortasında değil, döndürülmüş ve dünya ölçeğinde durur.
func _fit_to_platform(duration: float = 0.0, in_slot: bool = false) -> void:
	var bounds: AABB = _model_bounds(_preview, _model_slot if in_slot else null)
	var center: Vector3 = bounds.get_center()
	var radius: float = maxf(maxf(bounds.size.x, bounds.size.z) * 0.5, 0.25)
	# Kamera kadrajı: aracın küre yarıçapı görüş açısına sığsın (araç içine girmez)
	var sphere: float = maxf(bounds.size.length() * 0.5, 0.3)
	var target: Dictionary = {
		"slot": Vector3(-center.x, PLATFORM_HEIGHT - bounds.position.y, -center.z),
		"radius": radius,
		"distance": sphere / sin(deg_to_rad(CAM_FOV) * 0.5) * 1.34,   # araç ön planda, mekân arkada dursun
		# Bakış noktası araçtan biraz yukarıda: araç alt-ortada kalsın, üstte duvar/tabela/tavan görünsün
		"focus": Vector3(0.0, PLATFORM_HEIGHT + bounds.size.y * 0.45 + 0.24, 0.0),
	}
	if _fit_tween and _fit_tween.is_valid():
		_fit_tween.kill()   # yeni model geldi: yarım kalan geçiş eski kadrajı geri yazmasın
	if duration <= 0.0 or _fit.is_empty():
		_apply_fit(target)
		return
	var from: Dictionary = _fit.duplicate()
	var tween: Tween = create_tween()
	_fit_tween = tween
	tween.tween_method(func(t: float) -> void:
		_apply_fit({"slot": (from["slot"] as Vector3).lerp(target["slot"], t),
			"radius": lerpf(from["radius"], target["radius"], t),
			"distance": lerpf(from["distance"], target["distance"], t),
			"focus": (from["focus"] as Vector3).lerp(target["focus"], t)}),
		0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tweens.append(tween)


func _apply_fit(fit: Dictionary) -> void:
	_fit = fit
	_model_slot.position = fit["slot"]
	var radius: float = fit["radius"]
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
	_base_distance = fit["distance"]
	_focus = fit["focus"]
	_apply_camera()


## Modelin sınırları `space` uzayında (verilmezse modelin kendi uzayında).
func _model_bounds(car: Node3D, space: Node3D = null) -> AABB:
	var merged: AABB = AABB()
	var first: bool = true
	var inverse: Transform3D = (space if space else car).global_transform.affine_inverse()
	var stack: Array[Node] = [car]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mesh_node: MeshInstance3D = node
			var box: AABB = inverse * mesh_node.global_transform * mesh_node.get_aabb()
			merged = box if first else merged.merge(box)
			first = false
		for child: Node in node.get_children():
			stack.append(child)
	return merged if not first else AABB(Vector3(-0.5, 0.0, -0.5), Vector3.ONE)


func _free_model() -> void:
	# Slotta yalnızca önizleme olur; açılış sahnesinde kasa + çıkan araç + efektler de burada (yarıda kalırsa hepsi gider)
	for child: Node in _model_slot.get_children():
		child.queue_free()
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
	var distance: float = _base_distance * _zoom
	_camera.position = _focus + dir * distance
	_camera.look_at_from_position(_camera.position, _focus, Vector3.UP)
	# Kadraj kayması (ARAÇLAR): kamera kendi düzleminde kayar, araç ekranın o payı kadar sola / yukarı gider
	var size: Vector2 = Vector2(_viewport.size) if _viewport else Vector2(16.0, 9.0)
	var half_height: float = distance * tan(deg_to_rad(CAM_FOV) * 0.5)
	_camera.h_offset = _view_shift.x * 2.0 * half_height * (size.x / maxf(size.y, 1.0))
	_camera.v_offset = -_view_shift.y * 2.0 * half_height


func _process(delta: float) -> void:
	if _closing:
		return
	# Sürüklemeden kalan hız sönerek biter, sonra otomatik dönüş devreye girer (açılış sahnesinde durur)
	if not _dragging and not (_reveal_uid > 0 and not _reveal_done):
		_idle_time += delta
		if absf(_spin_velocity) > 0.0001:
			_display_root.rotate_y(_spin_velocity * delta)
			_spin_velocity = lerpf(_spin_velocity, 0.0, 1.0 - exp(-SPIN_DAMPING * delta))
		elif _idle_time >= AUTO_RESUME:
			_display_root.rotate_y(deg_to_rad(AUTO_SPEED) * delta)
	var shift: Vector2 = _shift_target()
	if absf(_zoom_target - _zoom) > 0.0005 or not _view_shift.is_equal_approx(shift):
		_zoom = lerpf(_zoom, _zoom_target, 1.0 - exp(-ZOOM_SMOOTH * delta))
		_view_shift = _view_shift.lerp(shift, 1.0 - exp(-ZOOM_SMOOTH * delta))
		_apply_camera()
	if _tab == Tab.CARS:
		_tick += delta
		if _tick >= 1.0:
			_tick = 0.0
			_on_second()


func _gui_input(event: InputEvent) -> void:
	if _closing or (_reveal_uid > 0 and not _reveal_done):
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
		[_exit_group, Vector2(0.0, -SLIDE)],   # anahtar (_title_group) GERİ'yle birlikte kayar
		[_side_group, Vector2(0.0, -SLIDE)],
		[_list_group, Vector2(-SLIDE, 0.0)],
		[_info_group, Vector2(SLIDE, 0.0)],
		[_tray, Vector2(0.0, SLIDE)],
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
	for group: Control in [_title_group, _exit_group, _side_group, _list_group, _info_group, _tray]:
		group.modulate.a = 1.0
		if _group_targets.has(group):
			group.position = _group_targets[group]
	_group_targets.clear()


## İLK AÇILIŞ TAKILMASINI ÖNLER: sahne görünmeden bir kez küçük boyutta çizilir — shader derleme
## ve doku yükleme ilk açılışta değil oyun yüklenirken olur (GL Compatibility shader'ları ilk
## kullanımda derler; ölçüldü: ilk açılışta bir kare 151 ms, sonrakilerde 17 ms). Hud çağırır.
func prewarm() -> void:
	if visible or _viewport == null:
		return
	_release_render_target(Vector2i(64, 36))
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
