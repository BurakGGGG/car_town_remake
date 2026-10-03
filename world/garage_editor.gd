class_name GarageEditor
extends Node
## GARAJ DÜZENLEME MODU — dünya tarafı: girdi, hayalet, seçim işareti, geri al.
## Arayüzü ui/hud/garage_edit_screen.gd; veri DecorManager, geometri GarageDecorView/DecorArea.
##
## GİRDİ YALITIMI. Düzenleme açıkken ana görünümün FİZİK TIKLAMASI kapatılır: araç, müşteri,
## genişletme tabelası, tamir alanı, mağaza binası tıklamalarının hepsi o yoldan geçer (ölçüldü:
## car_hitbox / shop_hitbox / garage_system / repair_bay_manager hepsi input_event). Oyun HUD'u da
## router bu ekranı YER (PLACE) olarak açtığı için gizlenir. Düzenleyici kök düğümün SON çocuğudur:
## Godot _unhandled_input'u ağaçtaki son düğümden başlatır, böylece eşya sürüklerken olayları
## kameradan ÖNCE alıp tüketir — eşya sürüklenirken kamera kaymaz. Boş zemini sürüklemek ise
## kameraya kalır (pan), iki parmak yakınlaştırır; eşyayı döndürmek yalnızca düğmeyle / R ile.
##
## ODAK. Düzenlerken yalnızca garaj önde kalır (telefonda denendi: yarış rakibinin balonu ve tamirdeki
## araç eşyaların önünü kapatıyordu): garajın dışı bulanık / soluk / koyu (GarageFocus), araç
## balonları ve kilitli alan plakaları gizli (WorldCamera.LAYER_WORLD_UI), araçlar gizli. BİTİR hepsini
## geri getirir.

signal selection_changed(iid: String)
signal placing_changed(item: StringName)
## Geri al yığını, ızgara ya da seçimin durumu değişti (arayüz yeniler).
signal state_changed
## Kısa bildirim ("BURAYA SIĞMIYOR" gibi).
signal notice(text: String)

## Geri alınabilecek son işlem sayısı.
const HISTORY: int = 10
## Tamir alanı bu kadar derecelik adımlarla döner (araç 90° park eder).
const BAY_ROTATION_STEP: float = 90.0
## Basış sürükleme sayılmadan önce gidilmesi gereken mesafe (tuval birimi).
const DRAG_THRESHOLD: float = 8.0
## Sürüklenen eşya zeminden bu kadar kalkar (tutulduğu belli olsun).
const LIFT: float = 0.012
## Hayaletin saydamlığı (GeometryInstance3D.transparency: 0 opak, 1 görünmez).
const GHOST_FADE: float = 0.4
## Yeni eşyaya boş yer ararken merkezden en çok kaç ızgara adımı uzaklaşılır.
const FREE_SPOT_RINGS: int = 24
## Bu kadar yakına (tuval birimi) yeniden dokunmak "aynı nokta" sayılır: arkadaki eşyaya geçer.
const CYCLE_RADIUS: float = 16.0
## Dönünce yerine sığmayan eşya en çok bu kadar adım kaydırılır (daha uzağı "kendiliğinden
## taşındı" gibi görünür).
const NUDGE_RINGS: int = 2
## Düzenlerken kamera normalden (2.2) daha fazla yaklaşabilir: telefonda garajın tamamı
## sığdırılınca bir trafik konisi ~25 tuval birimi (≈3 mm) kalıyor; yakınlaşıp rahat tutulsun.
const EDIT_MIN_ZOOM: float = 1.5
## Geçersiz konumun rengi — neon değil, soluk kiremit.
const INVALID_TINT: Color = Color(0.86, 0.32, 0.26, 0.5)
const MARKER_COLOR: Color = Color(0.98, 0.71, 0.18)
const MARKER_BAD: Color = Color(0.86, 0.32, 0.26)

var active: bool = false
var snap_enabled: bool = true

var _view: GarageDecorView
var _decor: DecorManager
var _selected: String = ""
var _history: Array[Dictionary] = []
var _saved_picking: bool = true
var _saved_view: Dictionary = {}
var _saved_min_zoom: float = -1.0

## Hayalet (yeni eşya): düğüm, eşya, konum, yön.
var _ghost: Node3D
var _ghost_item: StringName = &""
var _ghost_pos: Vector3
var _ghost_yaw: float = 0.0

## Basış / sürükleme durumu.
var _press_at: Vector2 = Vector2.ZERO
var _press_target: String = ""      # "" boş zemin, "ghost" hayalet, yoksa örnek kimliği
var _pressing: bool = false
var _dragging: bool = false
var _grab: Vector2 = Vector2.ZERO    # tutulan nokta ile eşya merkezi arası (X/Z)
var _drag_from: Vector3
var _drag_yaw: float = 0.0
var _drag_pos: Vector3
var _drag_ok: bool = true
var _drag_yaw_live: float = 0.0
## Aynı noktaya art arda dokunuş: altındaki eşyalar (önden arkaya) ve son dokunuşun yeri.
var _press_cycle: Array[String] = []
var _last_tap_at: Vector2 = Vector2.INF
## Ekrandaki parmaklar (indeks → true). Sayaç yerine küme: kaçan bir bırakma olayı kaydırmasın.
var _touch_ids: Dictionary = {}

var _focus: GarageFocus
var _traffic: TrafficManager
## Düzenleme süresince gizlenen araçlar (BİTİR'de geri gösterilir).
var _hidden_vehicles: Array[TrafficVehicle] = []

var _marker: Node3D
var _bays: RepairBayManager
## Sürüklenen tamir alanının canlı konumu / yönü ve geçerliliği.
var _bay_pos: Vector2 = Vector2.ZERO
var _bay_yaw: float = 0.0
var _bay_ok: bool = true
var _marker_mat: StandardMaterial3D
var _marker_xray: StandardMaterial3D
var _invalid_mat: StandardMaterial3D


func _ready() -> void:
	name = "GarageEditor"
	add_to_group("garage_editor")
	set_process_unhandled_input(false)
	_invalid_mat = StandardMaterial3D.new()
	_invalid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_invalid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_invalid_mat.albedo_color = INVALID_TINT
	_invalid_mat.no_depth_test = false
	_marker_mat = StandardMaterial3D.new()
	_marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_mat.albedo_color = MARKER_COLOR
	# Öndeki eşyaların örttüğü kısım soluk görünsün: arkada kalmış seçili eşyanın yeri belli olur
	# (aynı noktaya yeniden dokunarak arkadaki eşya seçildiğinde çerçevesi yine görünür).
	_marker_xray = StandardMaterial3D.new()
	_marker_xray.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_xray.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marker_xray.no_depth_test = true
	_marker_xray.render_priority = 1
	_marker_xray.albedo_color = Color(MARKER_COLOR, 0.35)
	_marker_mat.next_pass = _marker_xray
	_focus = GarageFocus.new()
	add_child(_focus)
	set_process(false)


func _bind() -> bool:
	if _view == null:
		_view = get_tree().get_first_node_in_group("garage_decor_view") as GarageDecorView
	if _decor == null:
		_decor = get_tree().get_first_node_in_group("decor") as DecorManager
	if _bays == null:
		_bays = get_tree().get_first_node_in_group("repair_bays") as RepairBayManager
	return _view != null and _decor != null


# --- Mod -------------------------------------------------------------------------------

## band: ekranın arayüzsüz dikey aralığı (0..1, üst/alt); garaj bu banda sığdırılır.
func activate(band: Vector2 = Vector2(0.14, 0.64)) -> void:
	if active or not _bind():
		return
	active = true
	# Kök düğümün en sonuna geç: _unhandled_input'u kameradan ve araç kutularından ÖNCE alırız.
	var parent: Node = get_parent()
	if parent:
		parent.move_child(self, -1)
	_saved_picking = get_viewport().physics_object_picking
	get_viewport().physics_object_picking = false
	# Düzenlemeye girerken seçili aracın zemin halkası açık kalmasın.
	for hitbox: Node in get_tree().get_nodes_in_group("car_hitboxes"):
		var ring: Node = hitbox.get_parent().get_node_or_null("SelectionRing")
		if ring is Node3D:
			(ring as Node3D).visible = false
	_view.set_editing(true)
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera is WorldCamera:
		_saved_min_zoom = (camera as WorldCamera).min_zoom
		(camera as WorldCamera).min_zoom = minf(_saved_min_zoom, EDIT_MIN_ZOOM)
	_frame_garage(band)
	_focus.show_focus(_view)
	if camera is WorldCamera:
		(camera as WorldCamera).set_world_ui_visible(false)
	if _traffic == null or not is_instance_valid(_traffic):
		_traffic = _find_traffic(get_tree().current_scene)   # bir kez: sahne ağacını dolaşır
	_hide_vehicles()
	_touch_ids.clear()
	set_process_unhandled_input(true)
	set_process(true)
	state_changed.emit()


func deactivate() -> void:
	if not active:
		return
	cancel_ghost()
	_end_drag(false)
	select("")
	active = false
	_pressing = false
	_touch_ids.clear()
	set_process_unhandled_input(false)
	set_process(false)
	get_viewport().physics_object_picking = _saved_picking
	if _view:
		_view.set_editing(false)
	_focus.hide_focus()
	_restore_vehicles()
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera is WorldCamera:
		(camera as WorldCamera).set_world_ui_visible(true)
	if camera is WorldCamera and _saved_min_zoom > 0.0:
		(camera as WorldCamera).min_zoom = _saved_min_zoom
		_saved_min_zoom = -1.0
	if camera and camera.has_method("restore_view") and not _saved_view.is_empty():
		camera.call("restore_view", _saved_view)   # düzenlemeden önceki görünüme dön
	_saved_view = {}
	_history.clear()
	var save: SaveManager = get_tree().get_first_node_in_group("save_manager") as SaveManager
	if save:
		save.save_game()   # BİTİR: düzen hemen diske yazılır (otomatik kaydın gecikmesini bekleme)
	state_changed.emit()


func _process(_delta: float) -> void:
	_hide_vehicles()   # düzenlerken yeni doğan / gelen araç da gizlensin


## Araçlar düzenlerken gizlenir. Tamir alanındakiler (CarSpot) garajın İÇİNDE durup arkalarındaki
## eşyaları örtüyordu; yoldakiler de garajın ön köşesinde odak efektinin içinde net kalıp dikkat
## dağıtıyordu (yarış rakibi duruş noktasında tam köşede bekliyor). Tamir alanı zaten yasak alan
## olarak görünür; araç mantığı (trafik, tamir sayacı, ödül, davet) çalışmaya devam eder.
func _hide_vehicles() -> void:
	if _traffic == null or not is_instance_valid(_traffic):
		return
	for vehicle: TrafficVehicle in _traffic.vehicles:
		if is_instance_valid(vehicle) and vehicle.visible:
			vehicle.visible = false
			_hidden_vehicles.append(vehicle)


func _restore_vehicles() -> void:
	for vehicle: TrafficVehicle in _hidden_vehicles:
		if is_instance_valid(vehicle):
			vehicle.visible = true
	_hidden_vehicles.clear()


func _find_traffic(node: Node) -> TrafficManager:
	if node == null:
		return null
	if node is TrafficManager:
		return node
	for child: Node in node.get_children():
		var found: TrafficManager = _find_traffic(child)
		if found:
			return found
	return null


## Kamerayı garaja odaklar: zemin + duvar yüksekliği, arayüzün bıraktığı banda sığsın.
func _frame_garage(band: Vector2) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null or not camera.has_method("frame_box"):
		return
	var a: DecorArea = _view.area()
	var box: AABB = AABB(Vector3(a.floor_rect.position.x, a.floor_y, a.floor_rect.position.y),
		Vector3(a.floor_rect.size.x, a.wall_top - a.floor_y, a.floor_rect.size.y))
	_saved_view = camera.call("frame_box", box, band.x, band.y)


func set_snap(on: bool) -> void:
	snap_enabled = on
	state_changed.emit()


## Izgara adımı: görünen ızgaranın YARISI (bkz. DecorArea.snap). Kapalıyken serbest.
func snap_step() -> float:
	return _view.grid_cell() * 0.5 if snap_enabled and _view else 0.0


# --- Seçim -----------------------------------------------------------------------------

func selected() -> String:
	return _selected


func select(iid: String) -> void:
	if iid == _selected:
		return
	_selected = iid
	_update_marker()
	selection_changed.emit(iid)
	state_changed.emit()


## Seçili şey bir tamir alanı mı? ("bay:N" kimliği)
func selected_is_bay() -> bool:
	return GarageDecorView.bay_index_of(_selected) >= 0


func placing_item() -> StringName:
	return _ghost_item


func is_placing() -> bool:
	return _ghost != null


# --- Hayalet (yeni eşya) ---------------------------------------------------------------

## Depodaki bir kopyayı yerleştirmeye başlar: hayalet görünür alanın ortasına en yakın geçerli
## yere konur (yer yoksa ortada kırmızı bekler). Dokunarak / sürükleyerek taşınır, ✓ ile konur.
func begin_place(item: StringName) -> bool:
	if not active or not _bind() or _decor.available_of(item) <= 0 or GarageDecor.is_surface(item):
		return false
	cancel_ghost()
	select("")
	_ghost = _view.make_body(item)
	if _ghost == null:
		return false
	_ghost_item = item
	_ghost.name = "DecorGhost"
	_view.add_child(_ghost)
	_set_fade(_ghost, GHOST_FADE)
	var start: Vector2 = _screen_center_ground()
	_ghost_yaw = 0.0
	var spot: Dictionary = _free_spot(item, start, _ghost_yaw)
	_ghost_pos = spot["pos"]
	_ghost_yaw = spot["yaw"]
	_refresh_ghost()
	if not bool(spot["ok"]):
		notice.emit("YER YOK — SÜRÜKLEYİP BOŞ BİR YERE TAŞI")
	placing_changed.emit(item)
	state_changed.emit()
	return true


## Hayaleti yerleştirir (geçerliyse). Başarılıysa yeni örnek seçili olur.
func confirm_ghost() -> bool:
	if _ghost == null:
		return false
	if not _view.is_valid(_ghost_item, _ghost_pos, _ghost_yaw):
		notice.emit("BURAYA SIĞMIYOR")
		return false
	var iid: String = _decor.add_instance(_ghost_item, _ghost_pos, _ghost_yaw)
	if iid == "":
		return false
	_push({"type": "place", "iid": iid})
	var item: StringName = _ghost_item
	cancel_ghost()
	select(iid)
	placing_changed.emit(&"")
	notice.emit("%s YERLEŞTİ" % String(GarageDecor.get_item(item).get("title", "")))
	return true


func cancel_ghost() -> void:
	if _ghost and is_instance_valid(_ghost):
		_ghost.queue_free()
	var had: bool = _ghost != null
	_ghost = null
	_ghost_item = &""
	if had:
		_update_marker()
		placing_changed.emit(&"")
		state_changed.emit()


# --- İşlemler (hepsi geri alınabilir) ---------------------------------------------------

## Seçili eşyayı (ya da hayaleti) adım kadar döndürür. yön: +1 saat yönü, -1 ters.
func rotate_selected(direction: int) -> bool:
	if _ghost:
		if GarageDecor.placement(_ghost_item) == GarageDecor.PLACE_WALL:
			return false
		_ghost_yaw = fposmod(_ghost_yaw - direction * GarageDecor.rotation_step(_ghost_item), 360.0)
		_refresh_ghost()
		return true
	if _selected == "":
		return false
	var bay: int = GarageDecorView.bay_index_of(_selected)
	if bay >= 0:
		if not _bind():
			return false
		var turned: float = fposmod(_bays.bay_yaw(bay) - direction * BAY_ROTATION_STEP, 360.0)
		if not move_bay(bay, _bays.bay_position(bay), turned):
			notice.emit("DÖNÜNCE SIĞMIYOR")
			return false
		return true
	var inst: Dictionary = _decor.instance(_selected)
	var item: StringName = inst["item"]
	if GarageDecor.placement(item) == GarageDecor.PLACE_WALL:
		notice.emit("DUVAR EŞYASI DUVARA GÖRE DURUR")
		return false
	var from: float = float((inst["rot"] as Vector3).y)
	var to: float = fposmod(from - direction * GarageDecor.rotation_step(item), 360.0)
	if _view.is_valid(item, inst["pos"], to, _selected):
		_decor.rotate_instance(_selected, to)
		_push({"type": "rotate", "iid": _selected, "from": from, "to": to})
		_update_marker()
		return true
	# Yerinde dönünce duvara / komşuya giriyor: en çok NUDGE_RINGS göz öteye kayarak dönebiliyorsa
	# öyle döner (tek geri al adımı). Görsel QA'da duvara ya da komşuya yaslı her uzun eşyanın
	# dönüşü reddediliyordu; oyuncu önce elle çekip sonra döndürmek zorunda kalıyordu.
	var spot: Vector3 = _nudge(item, inst["pos"], to, _selected)
	if spot == Vector3.INF:
		notice.emit("DÖNÜNCE SIĞMIYOR")
		return false
	return move_to(_selected, spot, to)


## Örneği yeni konuma (ve yöne) taşır: geçerliyse kaydedilir ve geri alınabilir. Sürükle-bırak
## bırakıldığında bunu çağırır. Duvar eşyasında yön, konumun asıldığı duvardan gelir.
func move_to(iid: String, pos: Vector3, yaw: float) -> bool:
	var inst: Dictionary = _decor.instance(iid) if _bind() else {}
	if inst.is_empty():
		return false
	var from: Vector3 = inst["pos"]
	var from_yaw: float = float((inst["rot"] as Vector3).y)
	if pos.is_equal_approx(from) and is_equal_approx(fposmod(yaw, 360.0), from_yaw):
		return false
	if not _view.is_valid(inst["item"], pos, yaw, iid):
		return false
	_decor.set_transform(iid, pos, yaw)
	_push({"type": "move", "iid": iid, "from": from, "from_yaw": from_yaw, "to": pos, "to_yaw": yaw})
	_update_marker()
	return true


## Tamir alanını yeni yere taşır / döndürür: geçerliyse kaydedilir ve geri alınabilir.
func move_bay(index: int, pos: Vector2, yaw: float) -> bool:
	if not _bind() or index < 0 or index >= _bays.bay_count():
		return false
	var from: Vector2 = _bays.bay_position(index)
	var from_yaw: float = _bays.bay_yaw(index)
	if pos.is_equal_approx(from) and is_equal_approx(fposmod(yaw, 360.0), from_yaw):
		return false
	if not _view.is_bay_valid(index, pos, yaw):
		return false
	_bays.set_layout(index, pos, yaw)
	_push({"type": "bay", "index": index, "from": from, "from_yaw": from_yaw, "to": pos, "to_yaw": yaw})
	_update_marker()
	return true


## Seçili eşyayı garajdan kaldırır; kopya DEPOYA döner.
func delete_selected() -> bool:
	if _ghost:
		cancel_ghost()
		return true
	if _selected == "":
		return false
	if selected_is_bay():
		notice.emit("TAMİR ALANI KALDIRILAMAZ — TAŞIYABİLİRSİN")
		return false
	var record: Dictionary = _decor.remove_instance(_selected)
	if record.is_empty():
		return false
	_push({"type": "delete", "record": record})
	select("")
	notice.emit("DEPOYA KALDIRILDI")
	return true


## Kaplamayı uygular (zemin / duvar). id = "" varsayılana döner.
func apply_surface(slot: StringName, id: StringName) -> bool:
	var from: StringName = _decor.surface(slot)
	if from == id:
		return false
	if not _decor.apply_surface(slot, id):
		return false
	_push({"type": "surface", "slot": slot, "from": from, "to": id})
	return true


func can_undo() -> bool:
	return not _history.is_empty()


## Son işlemi geri alır (yerleştir, taşı, döndür, sil, kaplama).
func undo() -> bool:
	if _history.is_empty():
		return false
	var op: Dictionary = _history.pop_back()
	match String(op["type"]):
		"place":
			_decor.remove_instance(op["iid"])
			if _selected == op["iid"]:
				select("")
		"move":
			_decor.set_transform(op["iid"], op["from"], float(op["from_yaw"]))
		"rotate":
			_decor.rotate_instance(op["iid"], float(op["from"]))
		"delete":
			var rec: Dictionary = op["record"]
			var iid: String = _decor.add_instance(rec["item"], rec["pos"], float((rec["rot"] as Vector3).y),
				rec["iid"])
			if iid != "":
				select(iid)
		"surface":
			_decor.apply_surface(op["slot"], op["from"])
		"bay":
			_bays.set_layout(int(op["index"]), op["from"], float(op["from_yaw"]))
	_update_marker()
	state_changed.emit()
	return true


func history_size() -> int:
	return _history.size()


func _push(op: Dictionary) -> void:
	_history.append(op)
	while _history.size() > HISTORY:
		_history.pop_front()
	state_changed.emit()


# --- Girdi -----------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.pressed:
			_touch_ids[st.index] = true
		else:
			_touch_ids.erase(st.index)
		if _touch_ids.size() >= 2 and _pressing:
			# İkinci parmak: hareket artık KAMERANIN (pinch). Sürüklenen eşya geldiği yerde kalır
			# (geçerliyse kaydedilir, değilse eski yerine döner); hayalet hayalet olarak bekler.
			# Basış bırakılır — parmaklardan biri kalkınca kalan parmak eşyayı yeniden kapmasın.
			_end_drag(_press_target != "ghost")
			_pressing = false
		return   # tüketilmez: iki parmak kamerayı yakınlaştırır
	if event is InputEventKey:
		_key(event as InputEventKey)
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return   # tekerlek / orta tuş kameraya
		if mb.pressed:
			_on_press(mb.position)
		else:
			_on_release(mb.position)
		return
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if not _pressing or not (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) or _touch_ids.size() >= 2:
			return
		if _press_target == "":
			return   # boş zemin sürükleniyor: kamera kaydırır
		if not _dragging and mm.position.distance_to(_press_at) > DRAG_THRESHOLD:
			_begin_drag()
		if _dragging:
			_drag_to(mm.position)
		# Eşyaya basılıyken hareket, sürükleme eşiği aşılmadan önce de kameraya gitmez: kamera
		# kendi göremediği bu basışı eski bir basış noktasına göre sürükleme sanıp birkaç piksel
		# kayıyordu (mobil testte yavaş parmakla ölçüldü).
		get_viewport().set_input_as_handled()


func _on_press(at: Vector2) -> void:
	_pressing = true
	_dragging = false
	_press_at = at
	var camera: Camera3D = get_viewport().get_camera_3d()
	_press_target = ""
	_press_cycle.clear()
	if _ghost and camera and _hits(camera, at, _ghost):
		_press_target = "ghost"
	elif camera:
		var under: Array[String] = _view.pick_all(camera, at)
		# Aynı noktaya yeniden basış ve seçili eşya bu noktanın altında: seçim korunur (sürüklenirse
		# o taşınır), dokunma olarak biterse sıradaki (arkadaki) eşyaya geçilir. Başka yere basış
		# her zaman en öndekini seçer.
		if _selected in under and at.distance_to(_last_tap_at) <= CYCLE_RADIUS:
			_press_cycle = under
			_press_target = _selected
		elif not under.is_empty():
			_press_target = under[0]
	if _press_target != "":
		if _press_target != "ghost":
			select(_press_target)
		get_viewport().set_input_as_handled()   # eşyaya basıldı: kamera sürüklemesin


func _on_release(at: Vector2) -> void:
	if not _pressing:
		return
	_pressing = false
	if _dragging:
		_end_drag(true)
		_last_tap_at = Vector2.INF
		get_viewport().set_input_as_handled()
		return
	if _press_target != "":
		get_viewport().set_input_as_handled()
		if _press_cycle.size() > 1:
			select(_press_cycle[(_press_cycle.find(_selected) + 1) % _press_cycle.size()])
		_last_tap_at = at
		return   # eşyaya dokunma: seçildi (basışta) ya da arkadakine geçildi
	if at.distance_to(_press_at) > DRAG_THRESHOLD:
		return   # boş zemin sürüklendi: kamera kaydı, dokunma değil
	# Boş zemine DOKUNMA: hayalet varsa oraya gelir, yoksa seçim kalkar
	_last_tap_at = Vector2.INF
	var camera: Camera3D = get_viewport().get_camera_3d()
	if _ghost and camera:
		var ground: Vector2 = _view.ground_point(camera, at)
		if ground != Vector2.INF:
			var p: Dictionary = _view.place_point(_ghost_item, ground, _ghost_yaw, snap_step())
			_ghost_pos = p["pos"]
			_ghost_yaw = p["yaw"]
			_refresh_ghost()
	else:
		select("")


func _key(key: InputEventKey) -> void:
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_R:
			rotate_selected(-1 if key.shift_pressed else 1)
			get_viewport().set_input_as_handled()
		KEY_DELETE, KEY_BACKSPACE:
			delete_selected()
			get_viewport().set_input_as_handled()
		KEY_Z:
			if key.ctrl_pressed or key.meta_pressed:
				undo()
				get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER:
			if _ghost:
				confirm_ghost()
				get_viewport().set_input_as_handled()


func _begin_drag() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	var ground: Vector2 = _view.ground_point(camera, _press_at)
	if ground == Vector2.INF:
		return
	_dragging = true
	if _press_target == "ghost":
		_grab = Vector2(_ghost_pos.x, _ghost_pos.z) - ground
		return
	var bay: int = GarageDecorView.bay_index_of(_press_target)
	if bay >= 0 and _bind():
		_bay_pos = _bays.bay_position(bay)
		_bay_yaw = _bays.bay_yaw(bay)
		_bay_ok = true
		_grab = _bay_pos - ground
		return
	var inst: Dictionary = _decor.instance(_press_target)
	if inst.is_empty():
		_dragging = false
		return
	_drag_from = inst["pos"]
	_drag_yaw = float((inst["rot"] as Vector3).y)
	_drag_pos = _drag_from
	_drag_ok = true
	var world: Vector3 = _view.body_of(_press_target).global_position if _view.body_of(_press_target) else _drag_from
	_grab = Vector2(world.x, world.z) - ground
	_set_fade(_view.body_of(_press_target), 0.15)


func _drag_to(at: Vector2) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	var ground: Vector2 = _view.ground_point(camera, at)
	if ground == Vector2.INF:
		return
	if _press_target == "ghost":
		var p: Dictionary = _view.place_point(_ghost_item, ground + _grab, _ghost_yaw, snap_step())
		_ghost_pos = p["pos"]
		_ghost_yaw = p["yaw"]
		_refresh_ghost()
		return
	var bay: int = GarageDecorView.bay_index_of(_press_target)
	if bay >= 0:
		_bay_pos = _view.area().snap(ground + _grab, snap_step())
		_bay_ok = _view.is_bay_valid(bay, _bay_pos, _bay_yaw)
		_bays.preview_layout(bay, _bay_pos, _bay_yaw)
		_update_marker(Vector3(_bay_pos.x, 0.0, _bay_pos.y), _bay_yaw, _bay_ok)
		return
	var inst: Dictionary = _decor.instance(_press_target)
	var item: StringName = inst["item"]
	var p2: Dictionary = _view.place_point(item, ground + _grab, _drag_yaw, snap_step())
	_drag_pos = p2["pos"]
	var yaw: float = p2["yaw"]
	_drag_ok = _view.is_valid(item, _drag_pos, yaw, _press_target)
	var body: Node3D = _view.body_of(_press_target)
	if body:
		body.transform = _view.transform_for(item, _drag_pos, yaw)
		body.position.y += LIFT if GarageDecor.placement(item) != GarageDecor.PLACE_WALL else 0.0
		_set_tint(body, not _drag_ok)
	_drag_yaw_live = yaw
	_update_marker(_drag_pos, yaw, _drag_ok)



## Sürüklemeyi bitirir. commit: geçerliyse yeni konum kaydedilir, değilse eski yerine döner.
func _end_drag(commit: bool) -> void:
	if not _dragging:
		return
	_dragging = false
	if _press_target == "ghost":
		if commit and _view.is_valid(_ghost_item, _ghost_pos, _ghost_yaw):
			confirm_ghost()   # bırak = yerleştir
		return
	var bay: int = GarageDecorView.bay_index_of(_press_target)
	if bay >= 0:
		if not (commit and _bay_ok and move_bay(bay, _bay_pos, _bay_yaw)):
			if commit and not _bay_ok:
				notice.emit("BURAYA SIĞMIYOR — ESKİ YERİNE DÖNDÜ")
			_bays.apply_layout(bay)   # görseli kayıtlı yerine geri koy
		_update_marker()
		return
	var iid: String = _press_target
	var body: Node3D = _view.body_of(iid)
	if body:
		_set_fade(body, 0.0)
		_set_tint(body, false)
	if not (commit and _drag_ok and move_to(iid, _drag_pos, _drag_yaw_live)):
		if commit and not _drag_ok:
			notice.emit("BURAYA SIĞMIYOR — ESKİ YERİNE DÖNDÜ")
		_view.refresh()   # gövdeyi kayıtlı yerine geri koy
	_update_marker()


# --- Görsel ----------------------------------------------------------------------------

func _refresh_ghost() -> void:
	if _ghost == null:
		return
	_ghost.transform = _view.transform_for(_ghost_item, _ghost_pos, _ghost_yaw)
	var ok: bool = _view.is_valid(_ghost_item, _ghost_pos, _ghost_yaw)
	_set_tint(_ghost, not ok)
	_update_marker(_ghost_pos, _ghost_yaw, ok, _ghost_item)
	state_changed.emit()


## Hayalet şu an geçerli bir yerde mi?
func ghost_valid() -> bool:
	return _ghost != null and _view.is_valid(_ghost_item, _ghost_pos, _ghost_yaw)


## Seçim işareti: izin çevresinde ince kehribar çerçeve (zeminde ya da duvarda). Parlak 3B
## tutamaç yok — Car Town'daki gibi sade.
func _update_marker(pos: Variant = null, yaw: float = 0.0, ok: bool = true, item: StringName = &"") -> void:
	if _marker and is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null
	if not active or _view == null:
		return
	var bay: int = GarageDecorView.bay_index_of(_press_target if pos != null else _selected)
	if bay >= 0 and _ghost == null and _bind():
		var at: Vector2 = Vector2(pos.x, pos.z) if pos != null else _bays.bay_position(bay)
		var turn: float = yaw if pos != null else _bays.bay_yaw(bay)
		_marker_mat.albedo_color = MARKER_COLOR if ok else MARKER_BAD
		_marker_xray.albedo_color = Color(_marker_mat.albedo_color, 0.35)
		_marker = Node3D.new()
		_marker.name = "SelectionMarker"
		_view.add_child(_marker)
		_marker.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(turn)),
			Vector3(at.x, _view.area().floor_y + 0.004, at.y))
		_frame(RepairBayManager.BAY_SIZE + Vector2(0.03, 0.03), false)
		return
	if pos == null:
		if _ghost:
			pos = _ghost_pos
			yaw = _ghost_yaw
			item = _ghost_item
			ok = _view.is_valid(_ghost_item, _ghost_pos, _ghost_yaw)
		elif _selected != "":
			var inst: Dictionary = _decor.instance(_selected)
			if inst.is_empty():
				return
			item = inst["item"]
			pos = inst["pos"]
			yaw = float((inst["rot"] as Vector3).y)
		else:
			return
	elif item == &"":
		item = _decor.instance(_press_target).get("item", &"") if _press_target not in ["", "ghost"] else _ghost_item
	if item == &"":
		return
	_marker_mat.albedo_color = MARKER_COLOR if ok else MARKER_BAD
	_marker_xray.albedo_color = Color(_marker_mat.albedo_color, 0.35)
	_marker = Node3D.new()
	_marker.name = "SelectionMarker"
	_view.add_child(_marker)
	if GarageDecor.placement(item) == GarageDecor.PLACE_WALL:
		var p: Vector3 = _view.area().reattach_wall(pos, yaw, _view.wall_width(item))
		var size: Vector3 = DecorBuilder.local_size(item) * GarageDecorView.WORLD_SCALE
		_marker.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), p + Vector3(0.0, 0.0, 0.0))
		_frame(Vector2(size.x + 0.02, size.y + 0.02), true)
		return
	var fp: Vector2 = _view.footprint_size(item)
	_marker.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)),
		Vector3((pos as Vector3).x, _view.area().floor_y + 0.004, (pos as Vector3).z))
	_frame(fp + Vector2(0.03, 0.03), false)


## İnce dikdörtgen çerçeve (4 çubuk). vertical: duvar düzleminde (x-y), yoksa zeminde (x-z).
func _frame(size: Vector2, vertical: bool) -> void:
	var t: float = 0.008
	var bars: Array[Array] = []
	if vertical:
		bars = [[Vector3(0.0, size.y * 0.5, 0.004), Vector3(size.x, t, t)],
			[Vector3(0.0, -size.y * 0.5, 0.004), Vector3(size.x, t, t)],
			[Vector3(size.x * 0.5, 0.0, 0.004), Vector3(t, size.y, t)],
			[Vector3(-size.x * 0.5, 0.0, 0.004), Vector3(t, size.y, t)]]
	else:
		bars = [[Vector3(0.0, 0.0, size.y * 0.5), Vector3(size.x, t * 0.5, t)],
			[Vector3(0.0, 0.0, -size.y * 0.5), Vector3(size.x, t * 0.5, t)],
			[Vector3(size.x * 0.5, 0.0, 0.0), Vector3(t, t * 0.5, size.y)],
			[Vector3(-size.x * 0.5, 0.0, 0.0), Vector3(t, t * 0.5, size.y)]]
	for bar: Array in bars:
		var mesh: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = bar[1]
		mesh.mesh = box
		mesh.position = bar[0]
		mesh.material_override = _marker_mat
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_marker.add_child(mesh)


static func _set_fade(node: Node, fade: float) -> void:
	if node == null:
		return
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is GeometryInstance3D:
			(n as GeometryInstance3D).transparency = fade


func _set_tint(node: Node, bad: bool) -> void:
	if node == null:
		return
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is GeometryInstance3D:
			(n as GeometryInstance3D).material_overlay = _invalid_mat if bad else null


# --- Yardımcılar -----------------------------------------------------------------------

func _hits(camera: Camera3D, at: Vector2, node: Node3D) -> bool:
	var box: AABB = GarageDecorView._tree_box(node)
	var grow: Vector3 = (Vector3.ONE * GarageDecorView.MIN_PICK - box.size).max(Vector3.ZERO) * 0.5
	box = AABB(box.position - grow, box.size + grow * 2.0)
	return GarageDecorView._ray_box(camera.project_ray_origin(at), camera.project_ray_normal(at), box) < INF


## Ekranın ortasının zemindeki karşılığı (garaj dışındaysa garajın ortası).
func _screen_center_ground() -> Vector2:
	var camera: Camera3D = get_viewport().get_camera_3d()
	var rect: Rect2 = _view.area().floor_rect
	if camera == null:
		return rect.get_center()
	var p: Vector2 = _view.ground_point(camera, get_viewport().get_visible_rect().size * 0.5)
	if p == Vector2.INF or not rect.has_point(p):
		return rect.get_center()
	return p


## `pos` çevresinde, NUDGE_RINGS adıma kadar, bu yönde geçerli olan EN YAKIN konum (yoksa INF).
func _nudge(item: StringName, pos: Vector3, yaw: float, ignore: String) -> Vector3:
	var step: float = maxf(snap_step(), _view.grid_cell() * 0.5)
	var best: Vector3 = Vector3.INF
	var best_d: float = INF
	for dx: int in range(-NUDGE_RINGS, NUDGE_RINGS + 1):
		for dz: int in range(-NUDGE_RINGS, NUDGE_RINGS + 1):
			var p: Vector3 = pos + Vector3(dx * step, 0.0, dz * step)
			var d: float = Vector2(dx, dz).length()
			if d > 0.0 and d < best_d and _view.is_valid(item, p, yaw, ignore):
				best = p
				best_d = d
	return best


## `near` çevresinde, ızgara adımlarıyla genişleyen halkalarda ilk GEÇERLİ yer.
## Dönüş: {"pos", "yaw", "ok"} — bulunamazsa ok=false ve konum `near`.
func _free_spot(item: StringName, near: Vector2, yaw: float) -> Dictionary:
	var step: float = maxf(_view.grid_cell() * 0.5, 0.05)
	var first: Dictionary = _view.place_point(item, near, yaw, step)
	if _view.is_valid(item, first["pos"], first["yaw"]):
		return {"pos": first["pos"], "yaw": first["yaw"], "ok": true}
	# Arama merkezden en çok FREE_SPOT_RINGS adım uzaklaşır: dolu 8×6 bir garajda bütün alanı
	# taramak (~34 bin konum × her örnekle çakışma) bir kare takılması yapardı.
	for r: int in range(1, FREE_SPOT_RINGS + 1):
		for dx: int in range(-r, r + 1):
			for dz: int in [-r, r] if absi(dx) != r else range(-r, r + 1):
				var p: Dictionary = _view.place_point(item, near + Vector2(dx, dz) * step, yaw, step)
				if _view.is_valid(item, p["pos"], p["yaw"]):
					return {"pos": p["pos"], "yaw": p["yaw"], "ok": true}
	return {"pos": first["pos"], "yaw": first["yaw"], "ok": false}
