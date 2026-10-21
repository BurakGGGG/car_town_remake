class_name DecorHoldGesture
extends Control
## GARAJDAKİ EŞYAYA BASILI TUT → TAŞI. Oyun modunda bir dekor eşyasına parmak HOLD_TIME kadar
## kıpırdamadan basılı kalırsa düzenleme modu o eşya parmağın ALTINDA TUTULMUŞ olarak açılır
## (HUD → GarageEditScreen.grab_on_open → GarageEditor.grab): parmak kalkmadan sürüklenir, bırakınca
## yeni yerine konur. Eskiden eşyayı taşımak için GARAJ → DÜZENLE → eşyaya dokun → sürükle gerekiyordu.
##
## Parmağın çevresinde dolan halka ne olacağını önceden söyler (kısa dokunuşta hiç görünmez).
## Olaylar TÜKETİLMEZ: kısa dokunuş, kamera kaydırma ve iki parmak yakınlaştırma eskisi gibi çalışır;
## kaydırma ya da ikinci parmak basılı tutmayı iptal eder. Parmağın altında araç (müşteri, tamirdeki
## araç, restorasyon) varsa başlamaz: o dokunuş aracındır. Ziyarette HUD olmadığı için hiç kurulmaz.

signal held(iid: String, at: Vector2)
## Kısa dokunuş (basılı tutma dolmadan, kaydırmadan bırakıldı): HUD sergideki araca dokunulduysa SERGİ PLAKASI'nı açar.
signal tapped(iid: String, at: Vector2)

const HOLD_TIME: float = 0.55
## Kısa dokunuşta halka hiç görünmesin (tıklama gibi basışlar ~0,1 sn).
const RING_DELAY: float = 0.12
## Bu kadar kayan parmak kamerayı kaydırıyordur: basılı tutma iptal (tuval birimi).
const MOVE_SLOP: float = 10.0
const RING_RADIUS: float = 30.0
const RING_WIDTH: float = 6.0

## HUD: başka ekran / eğitim açıkken false döner (halka hiç başlamaz).
var allowed: Callable = Callable()

var _iid: String = ""
var _at: Vector2 = Vector2.ZERO
var _time: float = 0.0
var _touches: Dictionary = {}   # ekrandaki parmaklar (indeks → true)


func _ready() -> void:
	name = "DecorHoldGesture"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(false)


func is_holding() -> bool:
	return _iid != ""


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.pressed:
			_touches[st.index] = true
		else:
			_touches.erase(st.index)
		if _touches.size() >= 2:
			_cancel()   # ikinci parmak: yakınlaştırma
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb: InputEventMouseButton = event
		if mb.pressed:
			_start(mb.position)
		else:
			var iid: String = _iid
			var at: Vector2 = _at
			_cancel()
			if iid != "":
				tapped.emit(iid, at)
	elif event is InputEventMouseMotion and _iid != "":
		if (event as InputEventMouseMotion).position.distance_to(_at) > MOVE_SLOP:
			_cancel()   # kamera kaydırılıyor


func _start(at: Vector2) -> void:
	_cancel()
	if allowed.is_valid() and not bool(allowed.call()):
		return
	var editor: GarageEditor = get_tree().get_first_node_in_group("garage_editor") as GarageEditor
	var view: GarageDecorView = get_tree().get_first_node_in_group("garage_decor_view") as GarageDecorView
	var camera: Camera3D = get_viewport().get_camera_3d()
	if editor == null or editor.active or view == null or camera == null or _hits_vehicle(camera, at):
		return
	for iid: String in view.pick_all(camera, at):
		if GarageDecorView.bay_index_of(iid) < 0:   # tamir alanı değil, eşya
			_iid = iid
			break
	if _iid == "":
		return
	_at = at
	_time = 0.0
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if _time >= HOLD_TIME:
		var iid: String = _iid
		var at: Vector2 = _at
		_cancel()
		held.emit(iid, at)


func _cancel() -> void:
	if _iid == "" and not is_processing():
		return
	_iid = ""
	_time = 0.0
	set_process(false)
	queue_redraw()


## Parmağın altında araç kutusu var mı (fizik ışını; müşteri / tamirdeki / restorasyondaki araç).
func _hits_vehicle(camera: Camera3D, at: Vector2) -> bool:
	var world: World3D = camera.get_world_3d()
	if world == null:
		return false
	var origin: Vector3 = camera.project_ray_origin(at)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin,
		origin + camera.project_ray_normal(at) * 1000.0)
	query.collide_with_areas = true
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	var collider: Node = hit.get("collider") as Node
	return collider != null and collider.is_in_group("car_hitboxes")


## Dolan halka: koyu gölge, soluk iz, üstünde amber ilerleme.
func _draw() -> void:
	if _iid == "" or _time < RING_DELAY:
		return
	var t: float = clampf((_time - RING_DELAY) / (HOLD_TIME - RING_DELAY), 0.0, 1.0)
	var p: Vector2 = get_global_transform_with_canvas().affine_inverse() * _at
	draw_circle(p, RING_RADIUS + RING_WIDTH, Color(0.0, 0.0, 0.0, 0.22 * t + 0.08), true, -1.0, true)
	draw_arc(p, RING_RADIUS, 0.0, TAU, 48, Color(HudPalette.TEXT_LIGHT, 0.45), RING_WIDTH, true)
	draw_arc(p, RING_RADIUS, -PI * 0.5, -PI * 0.5 + TAU * t, 48, HudPalette.COIN, RING_WIDTH, true)
