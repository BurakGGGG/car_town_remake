class_name DragRaceScreen
extends Control
## DRAG PİSTİ — ayrı bir gameplay modu (UiRouter'da PLACE): garaj dünyası arkada durur, bu ekran
## kendi SubViewport'unda kendi 3D pistini kurar (showroom ekranıyla aynı yöntem; .tscn yok).
##
## OYUNCU ARACI SÜRMEZ — Car Town mantığı: çıkışta bir dokunuş (tepki), sonra her viteste bir
## dokunuş. Model `DragRaceSim.Runner`: iki araç da CANLI adımlanır (süre önceden hesaplanmaz),
## yani ekranda gördüğün şey sonucun ta kendisidir. Rakip YEŞİL IŞIKTA kendi kalkar; oyuncu geç
## dokunursa aracı çizgide bekler — tepki cezası fizikseldir, formül değil.
##
## Akış: hazırlık → 3 · 2 · 1 · GO! → vitesler → bitiş → sonuç panosu (RaceResultScreen).

signal closed
## Yarış bitti: sonuç panosu için (kazandı mı, oyuncu süresi, rakip süresi).
signal race_completed(won: bool, player_time: float, rival_time: float)

enum Phase { READY, COUNTDOWN, RUNNING, DONE }

## Pistin görsel uzunluğu ve şeritleri DragTrack'ten gelir (tek kaynak).
const TRACK_LENGTH: float = DragTrack.TRACK_LENGTH
const LANE_OFFSET: float = DragTrack.LANE_OFFSET
## Araç ölçeği: şehirdeki trafik ölçeği (0,6) pistte araçları küçük bırakıyordu.
const CAR_SCALE: float = 1.2
## Geri sayım adımı (3 · 2 · 1 · GO).
const COUNTDOWN_STEP: float = 0.8
## Kamera: ortografik izometrik (pitch -25°, yaw 135° → yol sol üstten sağ alta akar), YAKIN.
const CAM_ANGLE: Vector3 = Vector3(-25.0, -45.0, 0.0)
const CAM_SIZE: float = 4.6
## Telefon tuvalinde (kısa ekran) biraz geniş kadraj: çıkış lambası ve araçlar birlikte sığsın.
const CAM_SIZE_COMPACT: float = 4.9
## Tekerlek yarıçapı (model uzayı) — kat edilen yola göre dönüş hesabı için.
const WHEEL_RADIUS: float = 0.1
## Kalkışta kameranın kısa süreli yaklaşması (ortografik size bu oranda daralır).
const CAM_PUNCH: float = 0.07
const CAM_DISTANCE: float = 12.0
## Odak araçların biraz ÖNÜNE alınır: ileride pistin devamı ve finish yönü görünür.
const CAM_LOOK_AHEAD: float = 0.30
## Bitişe yaklaşırken eklenen ileri bakış (FINISH kapısı görünsün).
const CAM_LOOK_AHEAD_END: float = 0.55
## KADRAJ (ekran uzayında): kamerayı sağa/aşağı kaydırmak içeriği sola/yukarı taşır. Araçlar
## yatayda ortalansın, alttaki vites ve dokunma plakalarının üstünde kalsın diye ayarlandı.
const CAM_PAN_RIGHT: float = 0.30
const CAM_PAN_UP: float = 0.12
const CAM_PAN_UP_COMPACT: float = 0.0
## Bu yüksekliğin altındaki tuval "telefon" sayılır (garaj ekranıyla aynı eşik).
const COMPACT_HEIGHT: float = 560.0
## İKİ ARAÇ DA HER ZAMAN KADRAJDA: gerçek fark yumuşatılarak ekrana taşınır.
const MAX_VISUAL_GAP: float = 0.92
const GAP_SOFT: float = 6.0
## BİTİŞ SONRASI: araçlar çizgide durmaz, hızlarıyla geçip frenleyerek durur (gerçek drag'de
## paraşüt/fren pisti). Kamera çizgide kalır; sonuç, araçlar kadrajdan geçerken gelir.
const OVERRUN_BRAKE: float = 16.0          # m/s² (≈ 60 m/s'den ~110 m'de durur: pist payına sığar)
## İki araç da geçtikten sonra sonuç panosuna kadar bekleme (kazanan görüntüsü).
const FINISH_HOLD: float = 2.2
## Biri geçtiği halde diğeri geçmediyse en çok bu kadar beklenir.
const FINISH_HOLD_MAX: float = 6.0
## Oyuncu hiç kalkmadıysa (rakip bitirdi) sonuç daha çabuk gelir.
const FINISH_HOLD_IDLE: float = 2.0
## Çıkış lambası renkleri DragTrack'tedir.
## Yarış telemetrisini ekrana basar (devir, vites, hız, kalite). Yayında KAPALI olmalı;
## `DRAG_DEBUG=1` ortam değişkeni ya da `--drag-debug` ile açılır.
static func debug_enabled() -> bool:
	return OS.get_environment("DRAG_DEBUG") == "1" or OS.has_feature("editor") \
		and OS.get_cmdline_user_args().has("--drag-debug")

## Vites kümesi (alt sağ köşe) ölçüleri — telefonda biraz küçülür.
const DIAL_SIZE: float = 172.0
const DIAL_SIZE_COMPACT: float = 150.0
const TAP_SIZE: float = 96.0
const TAP_SIZE_COMPACT: float = 86.0
const CAPTION_WIDTH: float = 206.0
const CAPTION_WIDTH_COMPACT: float = 184.0
## Köşeden içeri pay: küme kenara yapışmasın (hale de taşabilsin).
const CORNER_MARGIN: Vector2 = Vector2(52.0, 46.0)
const CORNER_MARGIN_COMPACT: Vector2 = Vector2(38.0, 34.0)

var _viewport: SubViewport
var _camera: Camera3D
var _player_car: Node3D
var _rival_car: Node3D
var _player_rig: CarRig
var _rival_rig: CarRig
var _player_distance: float = 0.0
var _rival_distance: float = 0.0
## Bitiş çizgisinden sonra kat edilen yol (metre) ve o andaki hız (m/s).
var _player_over: float = 0.0
var _rival_over: float = 0.0
var _player_over_speed: float = -1.0
var _rival_over_speed: float = -1.0
## İlk aracın çizgiyi geçtiği yarış zamanı (-1: henüz kimse geçmedi).
var _first_finish_time: float = -1.0
## Kalkış anı efektleri: kamera darbesi (ortografik size kısa süre daralır) ve lastik dumanı.
var _punch: float = 0.0
var _smoke: Array[CPUParticles3D] = []
var _world: Node3D
var _track: DragTrack

var _phase: Phase = Phase.READY
var _time: float = 0.0
var _countdown: float = 0.0
## Canlı koşucular: ekran bunları adımlar, araçların yerini de bunlardan okur.
var _player: DragRaceSim.Runner
var _rival: DragRaceSim.Runner
var _player_id: StringName = &""
var _rival_id: StringName = &""
var _tap_delay: float = -1.0
## Hatalı çıkışta oyuncunun aracı bu ana kadar çizgide tutulur (fiziksel ceza).
var _hold_until: float = 0.0
## Rakip AI'si: [hedef devir, sınırda oyalanma süresi] + sayaçlar.
## Rakibin bu vites için hedeflediği devir (AI aynı fiziği kullanır, yalnızca isabeti değişir).
var _rival_target: float = 0.0
## Rakibin hedef kalkış devri.
var _rival_launch_target: float = 0.0
## Hata ayıklama katmanı (yalnızca DRAG_DEBUG açıkken).
var _debug_label: Label
var _rival_skill: float = 0.5
## Vites penceresinin İÇİNDE miyiz (kadran yanar, plaka amber olur)?
var _shift_hot: bool = false
## Pencere dışındayken gösterilecek normal yazı (pencere içinde "ŞİMDİ!" yazar).
var _shift_status: String = ""
var _rng := RandomNumberGenerator.new()

var _status_label: Label
var _sign: PlatePanel
var _sign_tween: Tween
var _last_step: int = -1
var _shift_dial: ShiftDial
var _caption_plate: PlatePanel
var _corner: MarginContainer
var _shift_caption: Label
var _tap_button: PlateButton
var _column: VBoxContainer


func _ready() -> void:
	name = "DragRaceScreen"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.randomize()
	_build()
	set_process(false)


# --- Aç / kapa ---------------------------------------------------------------------

func open() -> void:
	var race: RaceManager = get_tree().get_first_node_in_group("race") as RaceManager
	_player_id = race.player_vehicle_id() if race else RaceManager.FALLBACK_VEHICLE
	_rival_id = race.rival_id() if race else &""
	if _rival_id == &"":
		# Ekran bir davet olmadan açıldıysa (menüden / hata ayıklama) rakip boş kalıyordu:
		# rakip aracı hiç doğmuyor, pistte tek araç kalıyordu. Sınıfa uygun bir rakip seçilir.
		_rival_id = race.rival_id_for(_player_id) if race else _player_id
	if _rival_id == &"":
		_rival_id = _player_id
	_phase = Phase.READY
	_time = 0.0
	_countdown = 3.0 * COUNTDOWN_STEP
	_tap_delay = -1.0
	_hold_until = 0.0
	_player = DragRaceSim.Runner.new()
	_player.setup(_player_id, _rng)
	_rival = DragRaceSim.Runner.new()
	_rival.setup(_rival_id, _rng)
	# Rakibin becerisi SINIFINDAN gelir: D çok hata yapar, A neredeyse kusursuz. Hile yok —
	# aynı Runner, aynı fizik, yalnızca hedeflediği devir sapar.
	_rival_skill = DragRaceSim.class_skill(_rival_id)
	_rival_launch_target = DragRaceSim.ai_launch_rpm(_rival.spec, _rival_skill, _rng)
	_rival.rpm = _rival.spec.idle_rpm
	_rival_target = DragRaceSim.ai_shift_target(_rival.spec, 0, _rival_skill, _rng)
	_load_cars()
	_column.visible = true
	if _sign:
		_sign.visible = true
	_punch = 0.0
	_player_distance = DragTrack.START_Z
	_rival_distance = DragTrack.START_Z
	_player_over = 0.0
	_rival_over = 0.0
	_player_over_speed = -1.0
	_rival_over_speed = -1.0
	_first_finish_time = -1.0
	_place_camera(0.0)   # önceki yarıştan kalan kadraj (bitiş çizgisi) sıfırlanır
	_status_label.text = Loc.t("HAZIR OL")
	_last_step = -1
	_track.set_lights(4)   # hepsi sönük
	_shift_dial.ratio = 0.0
	_shift_dial.zone_start = DragRaceSim.GAUGE_GREEN_START
	_shift_dial.zone_end = DragRaceSim.GAUGE_GREEN_END
	_shift_dial.redline = DragRaceSim.GAUGE_RED_START
	_shift_dial.ratio = DragRaceSim.launch_gauge(_player.rpm, _player.spec)
	_shift_dial.flash = false
	_shift_dial.over = false
	_shift_hot = false
	_shift_dial.hot = false
	_set_status(Loc.t("YEŞİLDE DOKUN"))
	_tap_button.text = Loc.t("DOKUN")
	_tap_button.disabled = false
	_tap_button.highlight = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_apply_compact_ui()
	show()
	set_process(true)


## Telefon tuvalinde alt plakalar küçülür: araçların üstüne binmesinler.
func _apply_compact_ui() -> void:
	var compact: bool = get_viewport_rect().size.y < COMPACT_HEIGHT
	var dial: float = DIAL_SIZE_COMPACT if compact else DIAL_SIZE
	var tap: float = TAP_SIZE_COMPACT if compact else TAP_SIZE
	_shift_dial.custom_minimum_size = Vector2(dial, dial)
	_tap_button.custom_minimum_size = Vector2(tap, tap)
	_shift_caption.custom_minimum_size = Vector2(
		CAPTION_WIDTH_COMPACT if compact else CAPTION_WIDTH, 0.0)
	var margin: Vector2 = CORNER_MARGIN_COMPACT if compact else CORNER_MARGIN
	_corner.add_theme_constant_override(&"margin_right", int(margin.x))
	_corner.add_theme_constant_override(&"margin_bottom", int(margin.y))


func close() -> void:
	if not visible:
		return
	set_process(false)
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.size = Vector2i(4, 4)   # render hedefi VRAM'de asılı kalmasın (kapsayıcı açılışta büyütür)
	_free_cars()   # yarış modelleri pistte asılı kalmasın
	hide()
	closed.emit()


## Yarış sırasında EKRANIN HER YERİ dokunma alanıdır: plakayı ıskalamak yarışı kaybettirmesin.
## DOKUN plakasına basıldığında olay orada tüketilir, bu yüzden çift sayılmaz.
func _gui_input(event: InputEvent) -> void:
	if not visible or _phase == Phase.DONE:
		return
	var touch: bool = event is InputEventScreenTouch
	var click: bool = event is InputEventMouseButton \
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	if not touch and not click:
		return
	var pressed: bool = (event as InputEventScreenTouch).pressed if touch \
		else (event as InputEventMouseButton).pressed
	if pressed:
		tap()
	accept_event()


func shift_count() -> int:
	return _player.good_shifts if _player else 0


## Koşu özeti (test ve sonuç panosu için) — canlı koşucudan türetilir.
func player_run() -> DragRaceSim.Run:
	return _summary(_player)


func rival_run() -> DragRaceSim.Run:
	return _summary(_rival)


func _summary(runner: DragRaceSim.Runner) -> DragRaceSim.Run:
	if runner == null or runner.finish_time < 0.0:
		return null
	var run: DragRaceSim.Run = DragRaceSim.Run.of(runner, runner.reaction)
	run.false_start = runner.false_start
	return run


## Test / dokunma girişi: tek dokunuş (çıkış ya da vites).
func tap() -> void:
	match _phase:
		Phase.COUNTDOWN:
			if _tap_delay < 0.0:
				# GO'dan ÖNCE dokunuldu → hatalı çıkış: araç GO'dan sonra da bir süre çizgide
				# tutulur (gerçek drag'de kırmızı ışık; burada oyuncuyu elemeyen fiziksel ceza).
				_tap_delay = -1.0
				_false_start()
		Phase.RUNNING:
			if not _player.running:
				# GO'dan sonraki İLK dokunuş TEPKİdir (vites değil): araç orada kalkar, yani
				# gecikme doğrudan mesafeye yansır.
				_launch_player(_time)
			elif _player.finish_time < 0.0:
				_register_shift()
		_:
			pass


# --- Kurulum -----------------------------------------------------------------------

func _build() -> void:
	_viewport_container()
	var overlay: Control = Control.new()
	overlay.name = "Overlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# Üst: durum tabelası (3 · 2 · 1 · GO)
	var top: MarginContainer = MarginContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.add_theme_constant_override(&"margin_top", 18)
	top.add_theme_constant_override(&"margin_left", 26)
	overlay.add_child(top)
	# Durum tabelası sola alınır: ortadaki çıkış lambasının üstüne binmesin.
	var sign: PlatePanel = PlatePanel.new()
	sign.theme_type_variation = &"HudCarPlate"
	sign.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_sign = sign
	_status_label = _label(&"HudSignTitle", Loc.t("HAZIR OL"))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.add_child(_status_label)
	top.add_child(sign)

	# Alt SAĞ KÖŞE: vites kümesi. Eskiden ekranın ortasında geniş bir plaka vardı; hem pistin
	# ortasını kapatıyordu hem de yatay telefonda başparmağın uzağındaydı. Şimdi kadran + yuvarlak
	# tabela butonu köşede, durum yazısı onların üstünde.
	var bottom: MarginContainer = MarginContainer.new()
	bottom.name = "ShiftCorner"
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_corner = bottom
	overlay.add_child(bottom)

	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override(&"separation", 5)
	bottom.add_child(_column)

	_caption_plate = PlatePanel.new()
	var caption_plate: PlatePanel = _caption_plate
	caption_plate.theme_type_variation = &"HudCarPlate"
	caption_plate.size_flags_horizontal = Control.SIZE_SHRINK_END
	_shift_caption = _label(&"HudInkValue", Loc.t("YEŞİLDE DOKUN"))
	_shift_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shift_caption.custom_minimum_size = Vector2(CAPTION_WIDTH, 0.0)
	caption_plate.add_child(_shift_caption)
	_column.add_child(caption_plate)

	var gauge_row: HBoxContainer = HBoxContainer.new()
	gauge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gauge_row.alignment = BoxContainer.ALIGNMENT_END
	gauge_row.add_theme_constant_override(&"separation", 20)   # hale butona değmesin
	_shift_dial = ShiftDial.new()
	_shift_dial.custom_minimum_size = Vector2(DIAL_SIZE, DIAL_SIZE)
	_shift_dial.size_flags_vertical = Control.SIZE_SHRINK_END
	# Yuvarlak tabela butonu: başparmağın altında; ideal devirde amber yanar.
	_tap_button = PlateButton.new()
	_tap_button.name = "TapButton"
	_tap_button.theme_type_variation = &"HudSign"
	_tap_button.shape = PlateButton.Shape.ROUND
	_tap_button.kind = HudIcon.Kind.NONE
	_tap_button.text = Loc.t("DOKUN")
	_tap_button.custom_minimum_size = Vector2(TAP_SIZE, TAP_SIZE)
	_tap_button.size_flags_vertical = Control.SIZE_SHRINK_END
	_tap_button.focus_mode = Control.FOCUS_NONE
	_tap_button.pressed.connect(tap)
	gauge_row.add_child(_shift_dial)
	gauge_row.add_child(_tap_button)
	_column.add_child(gauge_row)


func _viewport_container() -> void:
	var container: SubViewportContainer = SubViewportContainer.new()
	container.name = "TrackView"
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(container)
	_viewport = SubViewport.new()
	_viewport.name = "TrackViewport"
	_viewport.transparent_bg = false
	_viewport.own_world_3d = true   # pist KENDİ dünyasında: şehir sahnesi buraya sızmaz
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	container.add_child(_viewport)
	_world = Node3D.new()
	_world.name = "Track"
	_viewport.add_child(_world)
	_build_track()


## PİST — dekor ayrı bir sahnededir (race/drag_track.gd): burada yalnızca dünya, ışık ve kamera
## kurulur. Pist şehir dünyasıyla HİÇBİR bağı olmayan kendi World3D'sinde yaşar.
func _build_track() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = DragTrack.sky()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("CBD9E2")
	environment.ambient_light_energy = 1.0
	env.environment = environment
	_world.add_child(env)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -50.0, 0.0)   # kamera yönüyle birlikte döndü
	sun.light_energy = 1.05
	sun.shadow_enabled = false
	_world.add_child(sun)

	_track = DragTrack.new()
	_world.add_child(_track)

	_camera = Camera3D.new()
	_camera.name = "RaceCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	# GENİŞLİĞE kilitli: `size` artık YATAY açıklıktır. Yükseklik kilitliyken telefonun geniş
	# tuvali araçları küçültüyordu (ekran genişliğinin %10'u); artık araç boyu tuvalden bağımsız.
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.size = CAM_SIZE
	_world.add_child(_camera)
	_place_camera(0.0)
	_build_debug()


# --- Araçlar -----------------------------------------------------------------------

func _load_cars() -> void:
	_free_cars()
	# Oyuncu -X şeridinde: bu kamerada oyuncunun aracı ekranda ÖNDE, sol altta görünür
	# (kullanıcı isteği: "sol alttaki araç bizim olacak").
	_player_car = _spawn_car(_player_id, -LANE_OFFSET, false)
	_rival_car = _spawn_car(_rival_id, LANE_OFFSET, true)
	_place_cars()   # araçlar çıkış gridine otursun (kamera açılışta doğru yeri göstersin)


## Araçlar KENDİ görünümleriyle çıkar: rakibin gövdesi boyanmaz (ileride modifiyeli NPC'ler
## kendi renk/parça setleriyle gelecek; burada zorla renk değiştirmek onları bozardı).
func _spawn_car(vehicle_id: StringName, lane_x: float, _rival: bool) -> Node3D:
	var path: String = CarCatalog.scene_path(vehicle_id)
	if path == "":
		return null
	var scene: PackedScene = load(path)
	if scene == null:
		return null
	var car: Node3D = scene.instantiate() as Node3D
	car.position = Vector3(lane_x, 0.0, DragTrack.START_Z)
	# Modeller ZATEN +Z'ye bakıyor (farlar +0,42..+0,47, stoplar -0,43..-0,47 — yedi araçta da
	# ölçüldü) ve yarış +Z yönünde koşuluyor: buradaki 180° dönüş araçları geri geri koşturuyordu
	# (duman da bu yüzden burundan çıkıyordu). Ek dönüş YOK.
	car.scale = Vector3.ONE * CAR_SCALE * CarCatalog.model_scale(vehicle_id)
	_world.add_child(car)
	# Görünüm (boya) paylaşılan CarAppearance'tan; pistte gölge yok (mobil maliyet)
	var rig: CarRig = CarRig.for_node(car)
	if rig:
		rig.apply(CarAppearance.get_for(path))
		rig.set_lod_bias(CarRig.LOD_BIAS_WORLD)
	if _rival:
		_rival_rig = rig
	else:
		_player_rig = rig
	for child: Node in car.find_children("*", "GeometryInstance3D", true, false):
		(child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return car


func _free_cars() -> void:
	for car: Node3D in [_player_car, _rival_car]:
		if is_instance_valid(car):
			car.queue_free()
	for puff: CPUParticles3D in _smoke:
		if is_instance_valid(puff):
			puff.queue_free()
	_smoke.clear()
	_player_car = null
	_rival_car = null
	_player_rig = null
	_rival_rig = null


## Duman maskesi: ortada opak, kenarda saydam radyal gradyan (64×64, kodla üretilir).
static func _puff_texture() -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	gradient.add_point(0.55, Color(1.0, 1.0, 1.0, 0.75))
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture


## Kalkış dumanı: tek seferlik, ucuz (quad + CPUParticles3D), yumuşak radyal maske.
func _spawn_smoke(car: Node3D) -> void:
	if not is_instance_valid(car):
		return
	var puff: CPUParticles3D = CPUParticles3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.40, 0.40)
	puff.mesh = quad
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = Color(0.93, 0.92, 0.89, 0.55)
	# Yumuşak yuvarlak duman: düz quad keskin kare gibi görünüyordu, radyal gradyan maskesi
	material.albedo_texture = _puff_texture()
	puff.mesh.material = material
	puff.amount = 16
	puff.lifetime = 1.3
	puff.one_shot = true
	puff.explosiveness = 0.7
	puff.direction = Vector3(0.0, 0.25, -1.0)
	puff.spread = 28.0
	puff.initial_velocity_min = 0.8
	puff.initial_velocity_max = 1.6
	puff.gravity = Vector3(0.0, 0.25, 0.0)
	puff.scale_amount_min = 0.5
	puff.scale_amount_max = 1.5
	# Arka tampon: modelin -Z ucu (yerel -0,5) × ölçek = -0,6; duman onun hemen gerisinden çıkar.
	puff.position = car.position + Vector3(0.0, 0.10 * CAR_SCALE, -0.58 * CAR_SCALE)
	_world.add_child(puff)
	puff.emitting = true
	_smoke.append(puff)


# --- Yarış akışı -------------------------------------------------------------------

func _process(delta: float) -> void:
	if _phase == Phase.READY or _phase == Phase.COUNTDOWN:
		# GERİ SAYIM: oyuncu gazla uğraşmaz (kullanıcı kararı). Motor kalkış devrinde HAZIR
		# bekler, ibre yeşil dilime oturur — "yeşil yanınca dokun" mesajı böylece görselleşir.
		# Kalkış fiziği (debriyaj kayması, patinaj) modelde duruyor; yalnızca devri oyuncu
		# ayarlamıyor. Rakip kendi becerisine göre farklı devirde kalkmaya devam eder.
		_player.rev(delta, _player.spec.launch_rpm)
		_rival.rev(delta, _rival_launch_rpm())
		_shift_dial.ratio = DragRaceSim.launch_gauge(_player.rpm, _player.spec)
		var ready: bool = _phase == Phase.COUNTDOWN and _countdown <= COUNTDOWN_STEP
		_set_hot(ready)
		_shift_caption.text = Loc.t("YEŞİLDE DOKUN") if ready else Loc.t("HAZIR OL")
		_shift_dial.over = false
	match _phase:
		Phase.READY:
			_countdown -= delta
			if _countdown <= 0.0:
				_phase = Phase.COUNTDOWN
				_countdown = 3.0 * COUNTDOWN_STEP
		Phase.COUNTDOWN:
			_countdown -= delta
			var step: int = int(ceil(_countdown / COUNTDOWN_STEP))
			if step != _last_step:
				_last_step = step
				_pop_sign()
			_status_label.text = str(maxi(step, 1))
			_track.set_lights(maxi(step, 1))
			if _countdown <= 0.0:
				_status_label.text = Loc.t("GO!")
				_track.set_lights(0)
				_pop_sign()
				_set_status(Loc.t("ŞİMDİ DOKUN"))
				_time = 0.0
				_phase = Phase.RUNNING
				# RAKİP YEŞİLDE KENDİ KALKAR: oyuncu dokunmasa da yarış başlar.
				_rival.reaction = clampf(lerpf(DragRaceSim.REACTION_WORST,
					DragRaceSim.REACTION_PERFECT, _rival_skill) + _rng.randf_range(-0.06, 0.06),
					0.05, DragRaceSim.REACTION_WORST)
				_tap_button.text = Loc.t("VİTES")
		Phase.RUNNING:
			if _shift_hot:
				# Yuvarlak tabela da nabız atsın: efekt tek bir yerde kalmasın
				_tap_button.pivot_offset = _tap_button.size * 0.5
				_tap_button.scale = Vector2.ONE * (1.0 + 0.055 * _shift_dial.pulse())
			_time += delta
			if not _rival.running:
				_rival.rev(delta, _rival_launch_rpm())
				if _time >= _rival.reaction:
					_rival.launch()
					_spawn_smoke(_rival_car)
			if not _player.running and _hold_until > 0.0 and _time >= _hold_until:
				_launch_player(_time)   # hatalı çıkış cezası doldu, araç kalkıyor
			# Dokunulmazsa araç KALKMAZ: yeşili kaçırmak oyuncunun hatası, oyun onun yerine
			# başlatmaz (rakip gider, oyuncu geç kalkarsa yarışı kaybeder).
			_advance(delta)
		Phase.DONE:
			pass


## Oyuncunun kalkışı: araç TAM O ANDA hareketlenir, yani gecikme doğrudan mesafeye yansır.
func _launch_player(at_time: float) -> void:
	if _player.running:
		return
	# Araç kalkış devrinde hazır bekler: oyuncunun kalkıştaki becerisi TEPKİ süresidir,
	# devir ayarlamak değil (kullanıcı kararı). Debriyaj kayması ve patinaj yine modelden.
	_player.rpm = _player.spec.launch_rpm
	_player.reaction = maxf(at_time, 0.0)
	_player.launch()
	_punch = 1.0
	_spawn_smoke(_player_car)
	_status_label.text = Loc.t("GİT!")
	_set_status(Loc.t("VİTES  1 / %d") % (_player.gear_count() - 1))
	_tap_button.text = Loc.t("VİTES")


## Hatalı çıkış: yeşilden önce dokunuldu. Araç yeşilden sonra da ceza kadar çizgide bekler.
func _false_start() -> void:
	_player.false_start = true
	_hold_until = DragRaceSim.FALSE_START_PENALTY
	_status_label.text = Loc.t("HATALI ÇIKIŞ")
	_set_status(Loc.t("HATALI ÇIKIŞ"))


## Canlı adım: iki koşucu da ilerler, rakip kendi vitesini atar, kadran oyuncunun devrini gösterir.
func _advance(delta: float) -> void:
	_player.step(delta, _time)
	_rival.step(delta, _time)
	_drive_rival(delta)

	# Kadran: ibre motor devrinin YAY KARŞILIĞI (yeşil dilim = iyi vites, sağdaki kırmızı = geç
	# kaldın, en sağ = devir sınırı; ibre oradan öteye geçmez).
	_shift_dial.ratio = _player.gauge()
	if _shift_dial.flash and not _player.in_shift_window():
		_shift_dial.flash = false   # önceki vitesin parlaması yeni tura taşınmasın
	var can_shift: bool = _player.running and _player.gear < _player.top_gear()
	var over: bool = can_shift and _player.is_red()
	if over != _shift_dial.over:
		_shift_dial.over = over
		if over:
			_set_hot(false)
			_set_status(Loc.t("DEVİR SINIRI!  VİTES AT"))
		else:
			_set_status(Loc.t("VİTES  %d / %d") % [_player.gear + 1, _player.gear_count()])
	var in_window: bool = can_shift and not over and _player.in_shift_window()
	_set_hot(in_window)
	if in_window:
		# Pencerenin ORTASI kusursuz: oyuncu "hazır" ile "şimdi" arasındaki farkı görsün,
		# yoksa pencereye girer girmez basıp hep İYİ alıyor (kusursuza hiç ulaşamıyordu).
		var optimal: float = _player.spec.shift_rpm[_player.gear]
		var perfect: bool = absf(_player.rpm - optimal) / maxf(optimal, 1.0) \
			<= DragRaceSim.PERFECT_BAND
		_shift_caption.text = Loc.t("ŞİMDİ!") if perfect else Loc.t("HAZIRLAN")
		_shift_dial.flash = false
	if _debug_label:
		_update_debug()

	_place_cars(delta)
	_punch = maxf(_punch - delta * 2.2, 0.0)
	_place_camera(_time)
	_advance_overrun(delta)
	if _should_finish():
		_finish()
	elif _time > 40.0:
		_finish()   # güvenlik: kilitlenmiş bir koşu ekranı sonsuza kadar açık tutmasın


## Çizgiyi geçen araç hızıyla yoluna devam eder ve frenler; ilk geçiş anı kaydedilir.
func _advance_overrun(delta: float) -> void:
	if _first_finish_time < 0.0 and (_player.finish_time >= 0.0 or _rival.finish_time >= 0.0):
		_first_finish_time = _time
		_set_status(Loc.t("BİTİŞ!"))
		_tap_button.disabled = true
		_set_hot(false)
	if _player.finish_time >= 0.0:
		if _player_over_speed < 0.0:
			_player_over_speed = _player.speed
			_status_label.text = Loc.t("BİTİRDİN!")
		_player_over += _player_over_speed * delta
		_player_over_speed = maxf(_player_over_speed - OVERRUN_BRAKE * delta, 0.0)
	if _rival.finish_time >= 0.0:
		if _rival_over_speed < 0.0:
			_rival_over_speed = _rival.speed
		_rival_over += _rival_over_speed * delta
		_rival_over_speed = maxf(_rival_over_speed - OVERRUN_BRAKE * delta, 0.0)


## Sonuç ne zaman gelir: iki araç da geçip kısa bir "kazanan" görüntüsü bekledikten sonra.
func _should_finish() -> bool:
	if _first_finish_time < 0.0:
		return false
	var elapsed: float = _time - _first_finish_time
	var both: bool = _player.finish_time >= 0.0 and _rival.finish_time >= 0.0
	if both:
		var last: float = maxf(_player.finish_time, _rival.finish_time)
		return _time - last >= FINISH_HOLD
	if not _player.running:
		return elapsed >= FINISH_HOLD_IDLE   # oyuncu hiç kalkmadı
	return elapsed >= FINISH_HOLD_MAX


## HATA AYIKLAMA KATMANI (DRAG_DEBUG=1): simülasyonun ham durumu. UI'nin fiziği gerçekten
## yansıttığını gözle doğrulamak için; yayında hiç kurulmaz.
func _build_debug() -> void:
	if not DragRaceScreen.debug_enabled():
		return
	_debug_label = Label.new()
	_debug_label.name = "DragDebug"
	_debug_label.add_theme_color_override(&"font_color", Color(0.85, 1.0, 0.7))
	_debug_label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.85))
	_debug_label.add_theme_constant_override(&"outline_size", 4)
	_debug_label.position = Vector2(18.0, 78.0)
	_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_debug_label)


func _update_debug() -> void:
	var p: DragRaceSim.Runner = _player
	var r: DragRaceSim.Runner = _rival
	_debug_label.text = Loc.t("OYUNCU %s\n  devir %5.0f / %.0f   vites %d/%d   %6.1f km/s  %5.1f m\n  %s%s%s%s  isabet %d (kusursuz %d)  sınır %.2f sn  patinaj %.2f sn\nRAKİP  %s  devir %5.0f  vites %d  %6.1f km/s  %5.1f m  hedef %.0f") % [
		p.vehicle_id, p.rpm, p.spec.redline_rpm, p.gear + 1, p.gear_count(), p.speed_kmh(), p.distance,
		Loc.t("GEÇİŞ ") if p.shifting else "", Loc.t("PATİNAJ ") if p.wheelspin else "",
		Loc.t("SINIR ") if p.limiter else "", Loc.t("DEBRİYAJ ") if p.clutch > 0.0 else "",
		p.good_shifts, p.perfect_shifts, p.limiter_time, p.spin_time,
		r.vehicle_id, r.rpm, r.gear + 1, r.speed_kmh(), r.distance, _rival_target]


## Rakibin hedeflediği kalkış devri (açılışta seçildi; geri sayım boyunca oraya yükselir).
func _rival_launch_rpm() -> float:
	return _rival_launch_target


## Rakip sürücü: kendi planına göre vites atar (iyi sürücü tepede, kötü sürücü erken ya da
## devir sınırında oyalanarak). Oyuncunun dokunuşuyla aynı `shift()` çağrısını kullanır.
func _drive_rival(_delta: float) -> void:
	if not _rival.running or _rival.shifting or _rival.gear >= _rival.top_gear():
		return
	if _rival.rpm < _rival_target:
		return
	if _rival.shift() < 0:
		return
	_rival_target = DragRaceSim.ai_shift_target(_rival.spec, _rival.gear, _rival_skill, _rng)


## İDEAL DEVİR BİLDİRİMİ: ibre amber pencereye girince kadran yanar, yuvarlak tabela amber olur
## ve yazı "ŞİMDİ!" der. Pencereden çıkınca üçü de eski hâline döner.
func _set_hot(value: bool) -> void:
	if value == _shift_hot:
		return
	_shift_hot = value
	_shift_dial.hot = value
	_tap_button.highlight = value
	_caption_plate.modulate = Color(1.0, 0.90, 0.66) if value else Color.WHITE
	_shift_caption.text = Loc.t("ŞİMDİ!") if value else _shift_status
	if not value:
		_tap_button.scale = Vector2.ONE


## Yazıyı hem gösterir hem de "ŞİMDİ!" bittiğinde geri dönülecek metin olarak saklar.
func _set_status(text: String) -> void:
	_shift_status = text
	if not _shift_hot:
		_shift_caption.text = text


## Oyuncunun vitesi: kaliteyi MODEL söyler (0 = erken/bocalar, 1 = tam zamanında,
## 2 = devir sınırından). Süre buradan türemez; araç bir sonraki viteste kendi hızlanır.
func _register_shift() -> void:
	var quality: int = _player.shift()
	if quality < 0:
		return
	_set_hot(false)
	_shift_dial.over = false
	_shift_dial.flash = quality == DragRaceSim.Shift.PERFECT
	var shifts: int = _player.gear_count() - 1
	match quality:
		DragRaceSim.Shift.PERFECT:
			_set_status(Loc.t("KUSURSUZ!  %d / %d") % [_player.good_shifts, shifts])
		DragRaceSim.Shift.GOOD:
			_set_status(Loc.t("İYİ VİTES  %d / %d") % [_player.good_shifts, shifts])
		DragRaceSim.Shift.LATE:
			_set_status(Loc.t("GEÇ KALDIN  ·  DEVİR YÜKSEK"))
		DragRaceSim.Shift.REDLINE:
			_set_status(Loc.t("SINIRDA ATTIN  ·  ZAMAN KAYBI"))
		DragRaceSim.Shift.MISS:
			_set_status(Loc.t("IŞKA  ·  DEVİR ÇOK DÜŞTÜ"))
		_:
			_set_status(Loc.t("ERKEN ATTIN  ·  DEVİR DÜŞTÜ"))
	if _player.gear >= _player.top_gear():
		_tap_button.disabled = true
		_set_status(Loc.t("SON VİTES  ·  %d / %d İSABET") % [_player.good_shifts, shifts])


## Oyuncunun aracı KENDİ ilerlemesine göre durur; rakip ona göre çizilir. (Eskiden ikisi de iki
## aracın ORTALAMASI etrafında çiziliyordu: rakip yeşilde kalkınca oyuncunun duran aracı da ileri
## kayıyor, rakip hiç kalkmamış gibi görünüyordu — kullanıcı bunu "ben başlamadan bot başlamıyor"
## diye bildirdi.) Aradaki gerçek fark yine yumuşatılır (bkz. MAX_VISUAL_GAP), böylece kopan
## yarışta bile iki araç kadrajda kalır.
func _place_cars(delta: float = 0.0) -> void:
	var base: float = DragTrack.START_Z + _player_track_z()
	_move_car(_player_car, _player_rig, base, delta, true)
	_move_car(_rival_car, _rival_rig, base + _visual_gap(), delta, false)


## Aracı yerine koyar, tekerleklerini kat ettiği yola göre döndürür ve kalkışta hafifçe çömeltir.
func _move_car(car: Node3D, rig: CarRig, target_z: float, delta: float, is_player: bool) -> void:
	if not is_instance_valid(car):
		return
	var previous: float = _player_distance if is_player else _rival_distance
	var moved: float = target_z - previous
	car.position.z = target_z
	if is_player:
		_player_distance = target_z
	else:
		_rival_distance = target_z
	if rig and delta > 0.0 and moved > 0.0:
		rig.spin_wheels(rad_to_deg(moved / (WHEEL_RADIUS * CAR_SCALE)))
	# Kalkış çömelmesi: hızlanırken burun hafif yukarı, sonra düzelir
	var squat: float = clampf(moved / maxf(delta, 0.0001) * 0.06, 0.0, 1.0) if delta > 0.0 else 0.0
	car.rotation.x = lerpf(car.rotation.x, deg_to_rad(-1.6) * squat, 0.18)


## Oyuncunun pistteki yeri (dünya birimi, START_Z'den): bitişten sonra da ilerlemeye devam eder.
func _player_track_z() -> float:
	if _player == null:
		return 0.0
	return _player.progress() * TRACK_LENGTH \
		+ _player_over * (TRACK_LENGTH / DragRaceSim.DISTANCE)


## İki aracın ortalama ilerlemesi (0-1) — doğrudan canlı koşuculardan.
func _track_center() -> float:
	if _player == null or _rival == null:
		return 0.0
	return (_player.progress() + _rival.progress()) * 0.5


## Rakibin ekranda oyuncuya göre farkı (dünya birimi): rakip ÖNDEYSE artı. Gerçek metre farkı
## tanh ile yumuşatılır, böylece kopan yarışta bile iki araç kadrajda kalır.
func _visual_gap() -> float:
	if _player == null or _rival == null:
		return 0.0
	var rival_total: float = _rival.distance + _rival_over
	var player_total: float = _player.distance + _player_over
	return MAX_VISUAL_GAP * tanh((rival_total - player_total) / GAP_SOFT)


## Kamera izometrik açıyı koruyarak İKİ ARACIN ORTASINI takip eder; açı ne olursa olsun konum
## açıdan türetildiği için kamera her zaman odağa bakar.
func _place_camera(_t: float) -> void:
	# Kamera araçların ÇİZİLDİĞİ iki noktanın ortasını izler: oyuncu geride kalırsa ekranda da
	# geride kalır ama iki araç da kadrajda durur.
	var player_z: float = _player_track_z()
	# Kamera bitiş çizgisinde KALIR: araçlar çizgiyi geçip kadrajdan ilerler.
	var center_z: float = minf(player_z + _visual_gap() * 0.5, TRACK_LENGTH)
	# Yarış ilerledikçe kamera biraz daha ileriyi gösterir: son bölümde FINISH kapısı kadraja girer.
	var progress: float = clampf(center_z / TRACK_LENGTH, 0.0, 1.0)
	var look: float = CAM_LOOK_AHEAD + CAM_LOOK_AHEAD_END * progress * progress
	var focus: Vector3 = Vector3(0.25, 0.25, DragTrack.START_Z + center_z + look)
	var basis: Basis = Basis.from_euler(Vector3(
		deg_to_rad(CAM_ANGLE.x), deg_to_rad(CAM_ANGLE.y), deg_to_rad(CAM_ANGLE.z)))
	_camera.basis = basis
	# Kısa tuvalde (telefon, yükseklik 480) alt plakalar araçlara yaklaşıyor: kadraj biraz daha
	# yukarı alınır. Masaüstünde (648) değer değişmez.
	var pan_up: float = CAM_PAN_UP
	var compact: bool = get_viewport_rect().size.y < COMPACT_HEIGHT
	if compact:
		pan_up = CAM_PAN_UP_COMPACT
	_camera.size = (CAM_SIZE_COMPACT if compact else CAM_SIZE) * (1.0 - CAM_PUNCH * _punch)
	_camera.position = focus + basis.z * CAM_DISTANCE \
		+ basis.x * CAM_PAN_RIGHT + basis.y * pan_up


func _finish() -> void:
	_phase = Phase.DONE
	_tap_button.disabled = true
	# Sonuç panosu açılırken pist HUD'u kapanır: sonuç tek yerde yazsın (üstteki tabela da gider).
	_column.visible = false
	if _sign:
		_sign.visible = false
	var player_time: float = _player.finish_time if _player.finish_time >= 0.0 else _time
	var rival_time: float = _rival.finish_time if _rival.finish_time >= 0.0 else _time
	var won: bool = player_time <= rival_time
	_status_label.text = Loc.t("KAZANDIN!") if won else Loc.t("KAYBETTİN")
	race_completed.emit(won, player_time, rival_time)


## Tabela vuruşu: sayı değişince plaka kısaca büyüyüp yerine oturur (geri sayım hissi).
func _pop_sign() -> void:
	if _sign == null:
		return
	if _sign_tween and _sign_tween.is_valid():
		_sign_tween.kill()
	_sign.pivot_offset = _sign.size * 0.5
	_sign.scale = Vector2(1.22, 1.22)
	_sign_tween = create_tween()
	_sign_tween.tween_property(_sign, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
