class_name CrateDelivery
extends Node3D
## KASA TESLİMAT ALANI — satın alınan büyük araç kasalarını garaj zemininde BOŞ bir teslimat
## noktasına koyar, dokunulunca açılış sahnesini oynatır ve aracı dünyada fiziksel olarak çıkarır.
## "crate_delivery" grubundan bulunur; GarageSystem kodla kurar (sahne dosyası değişmez).
##
## DEKORASYON DEĞİLDİR: kasalar DecorManager'a hiç girmez, Garage Editor onları seçemez/taşıyamaz.
## İki sistem yalnızca YER konusunda konuşur: kasa, dekor eşyalarının / tamir alanlarının /
## genişletme tabelasının üstüne konmaz (teslimat noktası bunlardan boş seçilir), dekor da kasanın
## üstüne konamaz (GarageDecorView kasa izlerini engel sayar — occupied_rects()).
##
## TESLİMAT NOKTASI: garaj zemini ızgarasında aday noktalar taranır, kasa izi (iki yön) zemine sığan,
## hiçbir şeye değmeyen ve garajın ARKA-SOL köşesine en yakın nokta seçilir. İzometrik kamera tam bu
## köşeye bakar (iki iç duvarın birleştiği yer); ön-sağdaki havada asılı "GARAJI GENİŞLET" tabelası
## girişe yakın konan kasanın önüne biniyordu (QA ekran görüntüsü). Yer yoksa kasa
## PURCHASED ("yolda") kalır; dekor / garaj değişince yeniden denenir. Nokta kasayla birlikte
## kaydedilir: yeniden açılışta kasa aynı yerde durur.
##
## Açılış sahnesi yalnızca SUNUMDUR: ödül CrateManager.open() ile, sahne başlamadan verilip
## kaydedilmiştir. Gerçek kasa modeli / animasyonu geldiğinde bu dosya değişmez (CrateVisual).

signal crate_clicked(uid: int)
## Kasa açıldı, araç dünyada göründü: HUD sonuç plakasını gösterir.
signal reveal_ready(uid: int, result: Dictionary)
## Açılış sahnesi bitti ve kasa kaldırıldı.
signal reveal_finished(uid: int)
## Satın alınan kasa için garajda yer yok (HUD uyarısı).
signal delivery_blocked(uid: int)

## Aday noktalar arasındaki adım (dünya birimi).
const SCAN_STEP: float = 0.05
## Kasa ile çevresi arasındaki boşluk.
const GAP: float = 0.03
## Garaj girişi (sağ-ön köşe, garaj büyüse de sabit): araç kasadan bu yöne doğru çıkar.
const ENTRY: Vector2 = Vector2(-0.2, -0.2)
## Açılışta araç kasadan bu kadar dışarı çıkar (uzun eksen boyunca).
const ROLL_OUT: float = 0.3
## Açılış sahnesinde kameranın inebileceği en yakın ortografik boy (oyuncu sınırı WorldCamera.min_zoom).
const REVEAL_ZOOM: float = 1.35
## Dünyadaki araç ölçeği (TrafficManager.model_scale ile aynı bağlam).
const VEHICLE_SCALE: float = 0.6

var _manager: CrateManager
var _view: GarageDecorView
var _visuals: Dictionary = {}     # uid → CrateVisual
var _revealing: Dictionary = {}   # uid → {"car": Node3D, "light": OmniLight3D}
var _finishing: Dictionary = {}   # uid → kapanış animasyonu sürüyor
var _focus_on_arrival: int = 0
var _camera_state: Dictionary = {}


func _ready() -> void:
	name = "CrateDelivery"
	add_to_group("crate_delivery")
	_connect.call_deferred()


func _connect() -> void:
	_manager = get_tree().get_first_node_in_group("crates") as CrateManager
	_view = get_tree().get_first_node_in_group("garage_decor_view") as GarageDecorView
	if _manager == null:
		return
	_manager.crates_changed.connect(_sync)
	var decor: DecorManager = get_tree().get_first_node_in_group("decor") as DecorManager
	if decor:
		decor.placement_changed.connect(_retry_undelivered)
	var garage: Node = get_tree().get_first_node_in_group("garage_system")
	if garage and garage.has_signal(&"level_changed"):
		garage.connect(&"level_changed", func(_l: int) -> void: _retry_undelivered.call_deferred())
	_sync()


# --- Sorgu ---------------------------------------------------------------------------

## Dünyadaki kasaların zemin izleri (dekor yerleşimi bunları engel sayar).
func occupied_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for uid: int in _visuals:
		var v: CrateVisual = _visuals[uid]
		if is_instance_valid(v):
			out.append(_rect_of(Vector2(v.position.x, v.position.z), v.rotation_degrees.y))
	return out


func visual_of(uid: int) -> CrateVisual:
	var v: CrateVisual = _visuals.get(uid)
	return v if is_instance_valid(v) else null


func is_revealing() -> bool:
	return not _revealing.is_empty()


## Satın almadan sonra kamera bu kasaya gitsin (kasa teslim edilince).
func focus_on_arrival(uid: int) -> void:
	_focus_on_arrival = uid
	var v: CrateVisual = visual_of(uid)
	if v:
		_frame(v)


# --- Eşitleme ------------------------------------------------------------------------

func _sync() -> void:
	if _manager == null:
		return
	var alive: Dictionary = {}
	var changed: bool = false
	for c: Dictionary in _manager.crates():
		var uid: int = int(c["uid"])
		alive[uid] = true
		var st: int = int(c["state"])
		if st == CrateManager.State.PURCHASED:
			continue
		if not _visuals.has(uid) and st < CrateManager.State.REVEALED:
			var pos: Vector2 = c["pos"]
			_spawn(uid, c["crate"], pos, float(c["yaw"]), st == CrateManager.State.DELIVERED)
			changed = true
	for uid: int in _visuals.keys():
		if not alive.has(uid) and not _revealing.has(uid):
			var v: Node = _visuals[uid]
			if is_instance_valid(v):
				v.queue_free()
			_visuals.erase(uid)
			changed = true
	if changed:
		_refresh_view()
	_retry_undelivered()


## Yer bekleyen kasalar için teslimat noktası arar.
func _retry_undelivered() -> void:
	if _manager == null:
		return
	for uid: int in _manager.undelivered():
		var c: Dictionary = _manager.get_crate(uid)
		var slot: Dictionary = find_slot()
		if slot.is_empty():
			delivery_blocked.emit(uid)
			return
		_spawn(uid, c["crate"], slot["pos"], float(slot["yaw"]), true)
		_refresh_view()
		_manager.mark_delivered(uid, slot["pos"], float(slot["yaw"]))


func _spawn(uid: int, crate_id: StringName, pos: Vector2, yaw: float, arriving: bool) -> void:
	var v: CrateVisual = CrateVisual.new()
	v.setup(crate_id, uid)
	v.position = Vector3(pos.x, _floor_y(), pos.y)
	v.rotation_degrees.y = yaw
	add_child(v)
	_visuals[uid] = v
	v.clicked.connect(func() -> void:
		if not is_revealing():
			_prefetch_vehicle(uid)
			crate_clicked.emit(uid))
	if arriving:
		_arrive(v, uid)
	elif uid == _focus_on_arrival:
		_frame(v)


func _arrive(v: CrateVisual, uid: int) -> void:
	if uid == _focus_on_arrival:
		_frame(v)
	await v.play_arrival()
	if _manager:
		_manager.mark_waiting(uid)


# --- Teslimat noktası --------------------------------------------------------------------

## Boş teslimat noktası: {"pos": Vector2, "yaw": float} ya da boş sözlük.
func find_slot() -> Dictionary:
	var area: DecorArea = _view.area() if _view else null
	if area == null or not area.floor_rect.has_area():
		return {}
	var decor: DecorManager = get_tree().get_first_node_in_group("decor") as DecorManager
	var decor_polys: Array[PackedVector2Array] = []
	if decor and _view:
		for inst: Dictionary in decor.instances():
			if GarageDecor.placement(inst["item"]) == GarageDecor.PLACE_WALL:
				continue
			decor_polys.append(_view.footprint(inst["item"], inst["pos"], float((inst["rot"] as Vector3).y)))
	var taken: Array[Rect2] = occupied_rects()
	var r: Rect2 = area.floor_rect
	var preferred: Vector2 = r.position   # arka-sol köşe (kameranın baktığı iç köşe)
	# Arka-sol köşeden dışa doğru ÇAPRAZ halkalar (i + j = d): ilk halkada bulunan boş yer seçilir.
	# Eskiden tüm zemin taranıyordu; seviye 4 garajda ~38.000 aday → buy() 74 ms sürüyordu (QA ölçümü).
	var nx: int = int(r.size.x / SCAN_STEP) + 1
	var nz: int = int(r.size.y / SCAN_STEP) + 1
	for d: int in nx + nz - 1:
		var best: Dictionary = {}
		var best_score: float = INF
		for i: int in range(maxi(0, d - (nz - 1)), mini(d, nx - 1) + 1):
			var center: Vector2 = r.position + Vector2(i, d - i) * SCAN_STEP
			for yaw: float in [0.0, 90.0]:
				if _free(area, _rect_of(center, yaw), decor_polys, taken):
					var score: float = center.distance_to(preferred)
					if score < best_score:
						best_score = score
						best = {"pos": center, "yaw": yaw}
		if not best.is_empty():
			return best
	return {}


func _free(area: DecorArea, rect: Rect2, decor_polys: Array[PackedVector2Array], taken: Array[Rect2]) -> bool:
	var grown: Rect2 = rect.grow(GAP)
	var poly: PackedVector2Array = DecorArea.rect_corners(rect)
	if not area.inside_floor(poly):
		return false
	var grown_poly: PackedVector2Array = DecorArea.rect_corners(grown)
	for obstacle: Rect2 in area.obstacles:
		if obstacle.intersects(grown):
			return false
	for wall: Rect2 in area.wall_rects:   # iç duvarlar (dekorasyon v2): kasa duvarın içine inmesin
		if wall.intersects(grown):
			return false
	for other: Rect2 in taken:
		if other.intersects(grown):
			return false
	for p: PackedVector2Array in decor_polys:
		if DecorArea.overlaps(grown_poly, p):
			return false
	return true


func _rect_of(center: Vector2, yaw: float) -> Rect2:
	var s: Vector3 = CrateCatalog.world_size()
	var ext: Vector2 = Vector2(s.x, s.z) if absf(fmod(yaw, 180.0)) < 45.0 else Vector2(s.z, s.x)
	return Rect2(center - ext * 0.5, ext)


func _floor_y() -> float:
	var area: DecorArea = _view.area() if _view else null
	return area.floor_y if area else 0.01


## Dekor görünümünün engelleri kasalarla güncellensin (dekor kasanın üstüne konamasın).
## Kasa izleri kendi engellerimize de girer; teslimat taraması taken listesiyle ayrıca bakar.
func _refresh_view() -> void:
	if _view and _view.is_inside_tree():
		_view.refresh()


# --- Açılış sahnesi ------------------------------------------------------------------------

## Kasaya dokunulunca (AÇ plakası okunurken) aracın modeli arka planda yüklenmeye başlar: açılışta
## modelin kurulumu kareyi 60 ms kilitliyordu (QA ölçümü). Yalnızca o kasanın aracı, içerik gösterilmez.
func _prefetch_vehicle(uid: int) -> void:
	var path: String = CarCatalog.scene_path(_manager.get_crate(uid).get("vehicle", &"")) if _manager else ""
	if path != "" and not ResourceLoader.has_cached(path) \
			and ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(path)


## AÇ: ödül verilir + kaydedilir (CrateManager.open), sonra sahne oynar. Açılamıyorsa false.
func open_crate(uid: int) -> bool:
	var v: CrateVisual = visual_of(uid)
	if _manager == null or v == null or is_revealing() or not _manager.can_open(uid):
		return false
	var result: Dictionary = _manager.open(uid)
	if result.is_empty():
		return false
	_revealing[uid] = {}
	_play_reveal(uid, v, result)
	return true


## AÇILIŞ SAHNESİ: gerilim (kasa zıplar, ışık sızar) → patlama (kapak fırlar, şok dalgası, konfeti;
## nadirlikle ışık sütunu / hüzmeler) → araç kasadan DÖNEREK yükselir, tozla yere iner → kasadan çıkar.
## Nadirlik ne kadar yüksekse gerilim o kadar uzun, patlama o kadar büyük.
func _play_reveal(uid: int, v: CrateVisual, result: Dictionary) -> void:
	v.set_clickable(false)
	_camera_state = _frame(v, true)
	var vehicle: StringName = result["vehicle"]
	var scene_path: String = CarCatalog.scene_path(vehicle)
	var rarity: StringName = StringName(result["rarity"])
	var rank: int = CrateCatalog.rarity_rank(rarity)
	# Araç modeli (dokunulunca başlamadıysa) açılış animasyonu sırasında arka planda yüklenir
	_prefetch_vehicle(uid)
	var fx: CrateRevealFx = _effects(v, CrateCatalog.rarity_color(rarity), rank)
	_revealing[uid] = {"fx": fx}
	fx.suspense(CrateVisual.suspense_time(rank))
	v.burst_open.connect(fx.burst, CONNECT_ONE_SHOT)
	v.lid_vanished.connect(fx.poof, CONNECT_ONE_SHOT)
	await v.play_open(rank)
	var car: Node3D = await _spawn_vehicle(v, vehicle, scene_path)
	_revealing[uid] = {"car": car, "fx": fx}
	if car:
		await _rise(v, car, fx, rank)
		await _roll_out(v, car)
	reveal_ready.emit(uid, result)


## Sonuç plakası kapatıldı: araç garaja gider (küçülerek kaybolur), boş kasa kalkar, kasa CLAIMED.
func finish_reveal(uid: int) -> void:
	# Çift TAMAM: kapanış animasyonu sürerken ikinci çağrı ikinci bir kapanış başlatmasın
	if not _revealing.has(uid) or _finishing.has(uid):
		return
	_finishing[uid] = true
	var data: Dictionary = _revealing[uid]
	var v: CrateVisual = visual_of(uid)
	var tween: Tween = create_tween().set_parallel(true)
	var car: Node3D = data.get("car")
	if is_instance_valid(car):
		tween.tween_property(car, "scale", car.scale * 0.01, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	var fx: CrateRevealFx = data.get("fx")
	if is_instance_valid(fx):
		fx.fade_out(0.35)
	if v:
		tween.tween_property(v, "scale", Vector3(1.0, 0.01, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tween.finished
	for node: Variant in [car, fx, v]:
		if is_instance_valid(node):
			(node as Node).queue_free()
	_visuals.erase(uid)
	_revealing.erase(uid)
	_finishing.erase(uid)
	_restore_camera()
	# Önce dekor görünümünün engelleri tazelenir (açılan kasanın izi kalksın), SONRA claim: claim
	# yol bekleyen kasaların teslimatını yeniden dener; sıra tersken boşalan yer hâlâ dolu görünüyor,
	# "yolda" kasa hiç gelmiyordu (QA oyuncu testi, uid 5 PURCHASED'da kaldı).
	_refresh_view()
	if _manager:
		_manager.claim(uid)
	reveal_finished.emit(uid)


func _spawn_vehicle(v: CrateVisual, vehicle: StringName, scene_path: String) -> Node3D:
	if scene_path == "":
		return null
	while ResourceLoader.load_threaded_get_status(scene_path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	var scene: PackedScene = null
	if ResourceLoader.load_threaded_get_status(scene_path) == ResourceLoader.THREAD_LOAD_LOADED:
		scene = ResourceLoader.load_threaded_get(scene_path) as PackedScene
	if scene == null:
		scene = load(scene_path) as PackedScene   # önbellekte zaten var (daha önce yüklenmiş araç)
	if scene == null:
		push_warning("CrateDelivery: '%s' yüklenemedi" % scene_path)
		return null
	var car: Node3D = scene.instantiate() as Node3D
	car.name = "RevealedVehicle"
	car.scale = Vector3.ONE * VEHICLE_SCALE * CarCatalog.model_scale(vehicle)
	add_child(car)
	var rig: CarRig = CarRig.for_node(car)
	rig.apply(CarAppearance.get_for(scene_path))
	rig.optimize(true)   # açılan araç tekerini döndürmez: parçalar materyal başına birleşir
	# Aracın uzun ekseni kasanın uzun ekseniyle hizalanır (kasanın uzun kenarı yerel +X)
	var bounds: AABB = _bounds(car)
	var car_along_z: bool = bounds.size.z > bounds.size.x
	car.rotation_degrees.y = v.rotation_degrees.y + (90.0 if car_along_z else 0.0)
	var anchor: Vector3 = v.to_global(v.vehicle_anchor())
	car.global_position = anchor - Vector3(0.0, 0.02, 0.0)
	return car


## Araç kasadan uzun ekseni boyunca yavaşça çıkar, hafif yükselir ve zemine oturur.
func _roll_out(v: CrateVisual, car: Node3D) -> void:
	var out_dir: Vector3 = v.global_transform.basis.x.normalized()
	# Kasanın girişe bakan tarafına doğru çıksın
	var to_entry: Vector3 = Vector3(ENTRY.x, 0.0, ENTRY.y) - v.global_position
	if out_dir.dot(to_entry) < 0.0:
		out_dir = -out_dir
	var start: Vector3 = car.global_position
	var target: Vector3 = start + out_dir * ROLL_OUT
	target.y = _floor_y()
	var tween: Tween = create_tween()
	tween.tween_property(car, "global_position", start + Vector3(0.0, 0.07, 0.0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(car, "global_position", target + Vector3(0.0, 0.04, 0.0), 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(car, "global_position", target, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await tween.finished


## VİTRİN DÖNÜŞÜ: araç kasanın içinden küçükten büyüyerek yükselir, havada bir tur döner, kısa
## süre asılı kalır ve tozla yere iner (seker). Son açısı kasaya hizalı açıdır.
func _rise(v: CrateVisual, car: Node3D, fx: CrateRevealFx, rank: int) -> void:
	var rest: Vector3 = car.global_position
	var final_scale: Vector3 = car.scale
	var final_yaw: float = car.rotation.y
	var lift: float = 0.22 + 0.03 * float(rank)
	var spin_time: float = 0.85 + 0.1 * float(rank)
	car.scale = final_scale * 0.05
	car.rotation.y = final_yaw - TAU
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(car, "scale", final_scale, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(car, "global_position", rest + Vector3(0.0, lift, 0.0), spin_time * 0.6) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(car, "rotation:y", final_yaw, spin_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_interval(0.12 + 0.05 * float(rank))
	tween.tween_property(car, "global_position", rest, 0.32).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	# İlk temas anında toz (düşüşün ~%30'unda tekerler yere değer)
	tween.parallel().tween_callback(fx.dust.bind(Vector3(rest.x, _floor_y(), rest.z))).set_delay(0.1)
	await tween.finished


## Açılış efektleri (nadirlik renginde ışık, kıvılcım, konfeti…). Kasanın open_effect sahnesi
## varsa ışığa eklenir.
func _effects(v: CrateVisual, color: Color, rank: int) -> CrateRevealFx:
	var fx: CrateRevealFx = CrateRevealFx.new()
	fx.setup(color, rank)
	add_child(fx)
	fx.global_position = Vector3(v.global_position.x, _floor_y(), v.global_position.z)
	var light: OmniLight3D = fx.light()
	var effect_path: String = String(CrateCatalog.get_entry(v.crate_id).get("open_effect", ""))
	if effect_path != "" and ResourceLoader.exists(effect_path):
		var effect: PackedScene = load(effect_path) as PackedScene
		if effect:
			var node: Node3D = effect.instantiate() as Node3D
			if node:
				light.add_child(node)
	return fx


# --- Kamera --------------------------------------------------------------------------------

## `cinematic`: açılış sahnesi — oyuncu sınırından yakın çekim (restore_view ile geri dönülür).
## Gelişte kamera geri dönmediği için orada oyuncu sınırında kalınır.
func _frame(v: CrateVisual, cinematic: bool = false) -> Dictionary:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not (camera is WorldCamera):
		return {}
	var s: Vector3 = v.size()
	var world: WorldCamera = camera as WorldCamera
	if cinematic:
		# AÇILIŞ: sinematik yakın çekim — kasa + yükselen araç sıkı bir kutuda, ekranın üst %60'ında
		# (sonuç plakası altta). Eski geniş kutu ve %36'lık bantla gereken boy 2,33 çıkıyordu: kamera
		# oyuncu sınırının (2,2) altına hiç inemiyordu. Bitince restore_view ile geri dönülür.
		var tight: AABB = AABB(v.global_position - Vector3(s.x * 0.75, 0.0, s.x * 0.75),
			Vector3(s.x * 1.5, s.y * 1.7, s.x * 1.5))
		return world.frame_box(tight, 0.06, 0.6, 0.05, REVEAL_ZOOM)
	var box: AABB = AABB(v.global_position - Vector3(s.x, 0.0, s.x) * 0.9, Vector3(s.x * 1.8, s.y * 2.2, s.x * 1.8))
	# Kasa ekranın ÜST yarısında: alt-ortadaki plaka ve bildirimler kasayı örtmesin
	return world.frame_box(box, 0.08, 0.44)


func _restore_camera() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera is WorldCamera and not _camera_state.is_empty():
		(camera as WorldCamera).restore_view(_camera_state)
	_camera_state = {}


static func _bounds(root: Node3D) -> AABB:
	var merged: AABB = AABB()
	var first: bool = true
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mi: MeshInstance3D = node
			var box: AABB = root.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
			box = AABB(box.position * root.scale, box.size * root.scale)
			merged = box if first else merged.merge(box)
			first = false
		for child: Node in node.get_children():
			stack.append(child)
	return merged
