class_name RestorationFinale
extends Node3D
## RESTORASYON TESLİMİ — %100 proje BİTİR'lenince liftteki araç için kutlama; araç garaja "ışınlanmasın".
## Yalnızca SUNUMDUR: araç JunkyardManager.finish() ile tören başlamadan garaja kaydedilmiştir.
##
## Akış (kasa açılışının diliyle, CrateRevealFx en yüksek kademede, altın renkte):
##   1. GERİLİM   kamera alana yaklaşır; araç bembeyaz parlamaya başlar, titrer, aralardan kıvılcım sızar.
##   2. PATLAMA   şok dalgası, konfeti, ışık sütunu, dönen hüzmeler; parlama söner (cila bitti).
##   3. VİTRİN    araç liftin üstünde yükselip bir tur döner, tozla iner → `revealed` (HUD sonuç plakası).
##   4. GARAJA AL drive_away(): lift iner, araç burnunun yönünde alandan çıkıp küçülerek garaja gider,
##                lift serbest kalır, kamera eski yerine döner → `finished`, düğüm kendini siler.
## RestorationBays kurar ve görünümü (RestorationDisplay) ona devreder; alan tören bitene kadar dolu sayılır.

signal revealed
signal finished

const GOLD: Color = Color("F5BE4C")
const FX_RANK: int = 3            # CrateRevealFx kademesi: efsanevi (sütun + hüzmeler)
const SUSPENSE_TIME: float = 1.2
const SPIN_TIME: float = 1.1
const RISE: float = 0.2           # dünya birimi (araç boyu ~0,6)
const GLOW_PEAK: float = 0.75     # cila parlamasının en parlak anı (ekleme karışımı)
const DRIVE_DISTANCE: float = 0.55
const DRIVE_TIME: float = 0.6
const REVEAL_ZOOM: float = 1.35   # CrateDelivery.REVEAL_ZOOM ile aynı yakın çekim

var _display: RestorationDisplay
var _fx: CrateRevealFx
var _glow: StandardMaterial3D
var _camera_state: Dictionary = {}
var _state: StringName = &"idle"


func is_revealed() -> bool:
	return _state == &"revealed"


func bay() -> int:
	return _display.bay if is_instance_valid(_display) else -1


func play(display: RestorationDisplay) -> void:
	_display = display
	_state = &"playing"
	display.begin_finale()
	_camera_state = _frame()
	_fx = CrateRevealFx.new()
	_fx.setup(GOLD, FX_RANK)
	add_child(_fx)
	_fx.global_position = display.global_position
	_fx.suspense(SUSPENSE_TIME)
	_set_glow(0.0)
	var model: Node3D = display.model
	var tween: Tween = create_tween()
	tween.tween_method(_set_glow, 0.0, GLOW_PEAK, SUSPENSE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Titreme: gerilim büyüdükçe sıklaşır
	var shake: Tween = create_tween()
	for k: int in 10:
		var a: float = deg_to_rad(0.6 + 0.12 * k) * (1.0 if k % 2 == 0 else -1.0)
		shake.tween_property(model, "rotation:z", a, SUSPENSE_TIME / 10.0)
	shake.tween_property(model, "rotation:z", 0.0, 0.05)
	await tween.finished
	if not is_instance_valid(_display):
		return
	_burst()


func _burst() -> void:
	_fx.burst()
	var model: Node3D = _display.model
	var rest: Vector3 = model.position
	var yaw: float = model.rotation.y
	model.rotation.y = yaw - TAU
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_glow, GLOW_PEAK, 0.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(model, "position:y", rest.y + RISE / maxf(_display.scale.y, 0.001), SPIN_TIME * 0.55) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(model, "rotation:y", yaw, SPIN_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_interval(0.15)
	tween.tween_property(model, "position:y", rest.y, 0.32).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_callback(func() -> void:
		if is_instance_valid(_display) and is_instance_valid(_fx):
			_fx.dust(_display.global_position)).set_delay(0.1)
	await tween.finished
	if not is_instance_valid(_display):
		return
	_clear_glow()
	_state = &"revealed"
	revealed.emit()


## GARAJA AL: lift iner, araç alandan çıkıp küçülerek kaybolur.
func drive_away() -> void:
	if _state != &"revealed":
		return
	_state = &"leaving"
	var bays: RepairBayManager = _bay_manager()
	var index: int = bay()
	_fade_fx()
	if bays:
		bays.lower_lift(index)
		await get_tree().create_timer(RepairLift.LOWER_TIME).timeout
	if not is_instance_valid(_display):
		_end(bays, index)
		return
	var forward: Vector3 = _display.global_basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.001 else Vector3.BACK
	var tween: Tween = create_tween()
	tween.tween_property(_display, "global_position", _display.global_position + forward * DRIVE_DISTANCE, DRIVE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_display, "scale", _display.scale * 0.01, DRIVE_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tween.finished
	_end(bays, index)


## Tören hemen biter (kayıt değişti: yeni oyun / yükleme; test): araç kalkar, lift ve kamera döner.
func skip() -> void:
	if _state == &"done":
		return
	_end(_bay_manager(), bay())


## Efektler söner ve kalkar (ışık sütunu daralınca ince bir çizgi olarak havada kalıyordu).
func _fade_fx() -> void:
	var fx: CrateRevealFx = _fx
	_fx = null
	if not is_instance_valid(fx):
		return
	await fx.fade_out(0.45)
	if is_instance_valid(fx):
		fx.queue_free()


func _end(bays: RepairBayManager, index: int) -> void:
	if _state == &"done":
		return
	if bays:
		bays.release_lift(index)
	if is_instance_valid(_display):
		_display.queue_free()
	_restore_camera()
	_state = &"done"
	finished.emit()
	queue_free()


# --- Cila parlaması --------------------------------------------------------------------

## Aracın bütün yüzeylerine eklenen beyaz parıltı (ekleme karışımı; 0 = yok).
func _set_glow(amount: float) -> void:
	if not is_instance_valid(_display) or _display.model == null:
		return
	if _glow == null:
		_glow = StandardMaterial3D.new()
		_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		for node: Node in _display.model.find_children("*", "MeshInstance3D", true, false):
			(node as MeshInstance3D).material_overlay = _glow
	_glow.albedo_color = Color(1.0, 0.95, 0.82, amount)


func _clear_glow() -> void:
	if _glow == null or not is_instance_valid(_display) or _display.model == null:
		return
	for node: Node in _display.model.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		if mesh.material_overlay == _glow:
			mesh.material_overlay = null
	_glow = null


# --- Kamera --------------------------------------------------------------------------------

## Sinematik yakın çekim (kasa açılışıyla aynı): araç + yükselişi ekranın üst %60'ında, sonuç plakası altta.
func _frame() -> Dictionary:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not (camera is WorldCamera) or not is_instance_valid(_display):
		return {}
	var box: AABB = _display.world_box()
	var reach: float = maxf(box.size.x, box.size.z) * 0.75
	var center: Vector3 = box.get_center()
	var tight: AABB = AABB(Vector3(center.x - reach, box.position.y, center.z - reach),
		Vector3(reach * 2.0, box.size.y * 1.8, reach * 2.0))
	return (camera as WorldCamera).frame_box(tight, 0.06, 0.6, 0.05, REVEAL_ZOOM)


func _restore_camera() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera is WorldCamera and not _camera_state.is_empty():
		(camera as WorldCamera).restore_view(_camera_state)
	_camera_state = {}


func _bay_manager() -> RepairBayManager:
	return get_tree().get_first_node_in_group("repair_bays") as RepairBayManager if is_inside_tree() else null
