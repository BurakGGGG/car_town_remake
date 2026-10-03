class_name RepairBayManager
extends Node
## TAMİR ALANLARI: garajdaki hangi CarSpot'un açık olduğunun TEK kaynağı.
## Sahnede World/Gameplay/RepairBayManager olarak durur; arayanlar "repair_bays" grubundan bulur
## (autoload yok — proje kuralı).
##
## İKİ AŞAMALI AÇILIŞ:
##   1) GARAJ SEVİYESİ (GarageUpgradeManager `garage_level`) garajı FİZİKSEL olarak büyütür ve
##      yeni bölümde bir sonraki tamir alanını ORTAYA ÇIKARIR — kilitli olarak. Seviye almak alanı açmaz.
##   2) Oyuncu o alanın kendi ücretini öder (BAY_PRICES) → alan açılır ve kapasite artar.
## Kullanılabilir kapasite = SATIN ALINMIŞ alan sayısı (RepairManager.capacity() bunu okur),
## böylece kilitli ya da henüz inşa edilmemiş CarSpot'a hiçbir araç gönderilmez.
## Garaj seviyesinin altındaki alanlar dünyada hiç görünmez (ne CarSpot ne kilit).
##
## Para yalnızca EconomyManager'dan geçer, kalıcılık SaveManager'ındır (bu node yalnızca
## request_save çağırır). Kilitli alanlar dünyada fiziksel olarak görünür: koyu zemin, sarı bariyer,
## asma kilit ve krem fiyat plakası (hepsi primitive mesh — yeni asset yok). Kilitli alana tıklamak
## bay_clicked yayar; satın alma plakasını HUD gösterir.
##
## Kare başına iş yapmaz (_process yok).

## Alan açıldı (0 tabanlı indeks).
signal bay_unlocked(index: int)
## Satın alma olmadı: seviye yetmiyor, zaten açık ya da bakiye yetersiz.
signal purchase_failed(index: int, price: int)
## Açık alan listesi değişti (satın alma, kayıttan yükleme, yeni oyun).
signal bays_changed
## Dünyadaki kilitli alana tıklandı (HUD satın alma plakasını açar).
signal bay_clicked(index: int)
## Bir alanın yeri / yönü değişti (garaj düzenleyicisi, kayıttan yükleme, yeni oyun).
signal layout_changed

## Alan ücretleri (1., 2., 3. alan). İlk alan ücretsizdir. Fiyatın tek tanımlandığı yer burasıdır.
const BAY_PRICES: Array[int] = [0, 5000, 12000]

## Tamir alanının zemin izi (x, z; yön 0°'de) — CarSpot ve kilitli alan görseli bu ölçüdedir.
const BAY_SIZE: Vector2 = Vector2(0.5, 0.7)
## Varsayılan yerler (dünya x, z) ve yön. Her alan, KENDİ seviyesinde ilk kez ortaya çıkan zemin
## şeridine düşer (Sv.1 → x -0,2..-2,2; Sv.2 → -3,6'ya kadar; Sv.3 → -4,6'ya kadar): garaj
## büyümeden o bölgeye eşya konamayacağı için ortaya çıkan alan hiçbir şeyin üstüne binmez.
## Oyuncu bunları garaj düzenleyicisinde taşır; kayıtta yalnızca değişenler değil hepsi durur.
const DEFAULT_POSITIONS: Array[Vector2] = [Vector2(-1.72, -1.05), Vector2(-3.1, -1.05), Vector2(-4.05, -1.05)]
const DEFAULT_YAW: float = 90.0

enum Status {
	OPEN,           ## açık, kullanımda
	BUYABLE,        ## seviye yeterli, bakiye yeterli → satın alınabilir
	TOO_EXPENSIVE,  ## seviye yeterli ama bakiye yetersiz
	NEEDS_LEVEL,    ## önce GARAJ SEVİYESİ yükselmeli (fiziksel genişleme alanı ortaya çıkarır)
}

## Başlangıçta açık alan sayısı (yeni oyun).
@export_range(1, 3) var starting_bays: int = 1

var _unlocked: int = 1
var _locks: Dictionary = {}   # indeks → kilitli alan görselinin kökü (Node3D)
var _positions: Array[Vector2] = DEFAULT_POSITIONS.duplicate()
var _yaws: Array[float] = [DEFAULT_YAW, DEFAULT_YAW, DEFAULT_YAW]


func _ready() -> void:
	add_to_group("repair_bays")
	_unlocked = starting_bays
	_connect.call_deferred()


## Seviye ya da bakiye değişince dünyadaki kilitli alan plakaları güncellenir (kare başına iş yok).
func _connect() -> void:
	var upgrades: GarageUpgradeManager = _upgrades()
	if upgrades:
		# Garaj büyüyünce (ya da kayıt yüklenince) yeni alan kilitli olarak ortaya çıkar
		upgrades.levels_changed.connect(_refresh_world)
	var economy: EconomyManager = _economy()
	if economy:
		economy.money_changed.connect(func(_m: int) -> void: _refresh_lock_texts())
	_refresh_world()


func _refresh_lock_texts() -> void:
	for index: int in _locks:
		_update_lock_text(index)


# --- Sorgu ---------------------------------------------------------------------

## Sahnedeki toplam alan sayısı (RepairManager'ın CarSpot listesi).
func bay_count() -> int:
	return _spots().size()


func unlocked_count() -> int:
	return clampi(_unlocked, 1, maxi(bay_count(), 1))


func is_bay_unlocked(index: int) -> bool:
	return index >= 0 and index < unlocked_count()


## Açık alanların CarSpot node'ları (sırayla).
func get_unlocked_bays() -> Array[Node3D]:
	var out: Array[Node3D] = []
	var spots: Array[Node3D] = _spots()
	for i: int in mini(unlocked_count(), spots.size()):
		out.append(spots[i])
	return out


## Bu alanın ücreti (ilk alan 0).
func price(index: int) -> int:
	return BAY_PRICES[index] if index >= 0 and index < BAY_PRICES.size() else 0


## Bu alanın ortaya çıkması için gereken GARAJ SEVİYESİ (0. alan → Sv.1, 1. alan → Sv.2 ...).
func required_level(index: int) -> int:
	return index + 1


## Bu alan garajın şu anki fiziksel seviyesinde inşa edilmiş mi (görünür mü)?
func is_bay_revealed(index: int) -> bool:
	var upgrades: GarageUpgradeManager = _upgrades()
	var level: int = upgrades.garage_level() if upgrades else bay_count()
	return index < level


## Dünyada İNŞA EDİLMİŞ alanların CarSpot node'ları (açık ya da kilitli). Kilitli alan da ileride
## araç alacağı için garaj düzenleyicisi hepsini engel sayar (üstüne eşya konamaz).
func revealed_spots() -> Array[Node3D]:
	var out: Array[Node3D] = []
	var spots: Array[Node3D] = _spots()
	for i: int in spots.size():
		if is_bay_revealed(i) and is_instance_valid(spots[i]):
			out.append(spots[i])
	return out


## UI'ın tek karar noktası.
func status(index: int) -> Status:
	if is_bay_unlocked(index):
		return Status.OPEN
	if not is_bay_revealed(index):
		return Status.NEEDS_LEVEL   # garaj bu kadar büyük değil: alan henüz inşa edilmedi
	if index != unlocked_count():
		return Status.NEEDS_LEVEL   # sıradaki alan değil: önce öncekini aç
	var economy: EconomyManager = _economy()
	if economy and not economy.can_afford(price(index)):
		return Status.TOO_EXPENSIVE
	return Status.BUYABLE


func can_purchase(index: int) -> bool:
	return status(index) == Status.BUYABLE


# --- Satın alma ------------------------------------------------------------------

## Alanı açar: seviye uygun ve bakiye yeterliyse ücret düşer, alan açılır (true).
## Herhangi bir adım tutmazsa hiçbir şey değişmez (false).
func purchase(index: int) -> bool:
	if index < 0 or index >= bay_count():
		return false
	if not can_purchase(index):
		purchase_failed.emit(index, price(index))
		return false
	var economy: EconomyManager = _economy()
	if economy and not economy.spend_money(price(index)):   # bakiye yetmezse para değişmez
		purchase_failed.emit(index, price(index))
		return false
	_unlocked = index + 1
	_refresh_world()
	bay_unlocked.emit(index)
	bays_changed.emit()
	_request_save()
	return true


# --- Kayıt ------------------------------------------------------------------------

## Alanın lifti (CarSpot'un çocuğu); yoksa null.
func lift(index: int) -> RepairLift:
	var spots: Array[Node3D] = _spots()
	if index < 0 or index >= spots.size() or not is_instance_valid(spots[index]):
		return null
	return spots[index].get_node_or_null("Lift") as RepairLift


## Araç tamire alınırken: araç lifte oturur ve lift kalkar. Araç Y kotu liftin işidir.
func raise_lift(index: int, car: Node3D) -> void:
	var l: RepairLift = lift(index)
	if l == null:
		return
	l.raise(car)                        # önce eski kotu hatırlar
	car.global_position.y = l.car_y()   # alçak liftin yürüme yoluna otur


## Tamir bitince (ya da araç iş sırasında çekilirse): lift iner.
func lower_lift(index: int) -> void:
	var l: RepairLift = lift(index)
	if l:
		l.lower()


## Araç alandan ayrılırken (para toplandı / iş iptal): lift alçak konuma, araç eski kotuna.
func release_lift(index: int) -> void:
	var l: RepairLift = lift(index)
	if l:
		l.release()


## Kayda yazılacak değer: açık alan sayısı.
func state() -> int:
	return unlocked_count()


## Kayıttan açık alan sayısı (aralık dışı değerler kırpılır).
func load_state(count: int) -> void:
	_unlocked = clampi(count, 1, maxi(bay_count(), 1))
	_refresh_world()
	bays_changed.emit()


## Yeni oyun: yalnızca ilk alan, alanlar varsayılan yerinde.
func reset() -> void:
	_unlocked = starting_bays
	_positions = DEFAULT_POSITIONS.duplicate()
	_yaws = [DEFAULT_YAW, DEFAULT_YAW, DEFAULT_YAW]
	_refresh_world()
	bays_changed.emit()


# --- Yerleşim (taşınabilir alanlar) -------------------------------------------------

## Alanın merkezi (dünya x, z).
func bay_position(index: int) -> Vector2:
	return _positions[index] if index >= 0 and index < _positions.size() else Vector2.ZERO


## Alanın yönü (derece, Y ekseni).
func bay_yaw(index: int) -> float:
	return _yaws[index] if index >= 0 and index < _yaws.size() else DEFAULT_YAW


## Dünyada şu an görünen düğüm: açık alanda CarSpot, kilitli alanda kilit görseli.
func bay_node(index: int) -> Node3D:
	if _locks.has(index) and is_instance_valid(_locks[index]):
		return _locks[index]
	var spots: Array[Node3D] = _spots()
	return spots[index] if index >= 0 and index < spots.size() and is_instance_valid(spots[index]) else null


## Yeri kalıcı olarak değiştirir (geçerlilik denetimi çağıranındır: GarageDecorView.is_bay_valid).
func set_layout(index: int, pos: Vector2, yaw: float) -> void:
	if index < 0 or index >= _positions.size():
		return
	_positions[index] = pos
	_yaws[index] = fposmod(yaw, 360.0)
	apply_layout(index)
	layout_changed.emit()
	_request_save()


## Alanın görselini kayıtlı yerine koyar (sürükleme iptalinde de bununla geri döner).
func apply_layout(index: int) -> void:
	preview_layout(index, bay_position(index), bay_yaw(index))


## Kaydetmeden yalnızca görseli taşır (sürüklerken canlı önizleme).
func preview_layout(index: int, pos: Vector2, yaw: float) -> void:
	var spots: Array[Node3D] = _spots()
	var targets: Array[Node3D] = []
	if index >= 0 and index < spots.size() and is_instance_valid(spots[index]):
		targets.append(spots[index])
	if _locks.has(index) and is_instance_valid(_locks[index]):
		targets.append(_locks[index])
	for node: Node3D in targets:
		var y: float = node.global_position.y
		node.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), Vector3(pos.x, y, pos.y))


## Kayıt: her alan için {x, z, yaw}.
func layout_state() -> Array:
	var out: Array = []
	for i: int in _positions.size():
		out.append({"x": _positions[i].x, "z": _positions[i].y, "yaw": _yaws[i]})
	return out


## Kayıttan yerler; eksik / bozuk giriş varsayılanda kalır (eski kayıtta hiç yoktur).
func load_layout(data: Variant) -> void:
	_positions = DEFAULT_POSITIONS.duplicate()
	_yaws = [DEFAULT_YAW, DEFAULT_YAW, DEFAULT_YAW]
	if data is Array:
		for i: int in mini((data as Array).size(), _positions.size()):
			var entry: Variant = (data as Array)[i]
			if not (entry is Dictionary):
				continue
			var d: Dictionary = entry
			var x: float = SaveSafe.f(d.get("x", _positions[i].x))
			var z: float = SaveSafe.f(d.get("z", _positions[i].y))
			if absf(x) > 50.0 or absf(z) > 50.0:
				continue
			_positions[i] = Vector2(x, z)
			_yaws[i] = fposmod(SaveSafe.f(d.get("yaw", DEFAULT_YAW)), 360.0)
	_refresh_world()
	layout_changed.emit()


# --- Dünya görselleri -------------------------------------------------------------

## Açık alanlarda CarSpot görünür, kilitli alanlarda kilitli bölüm görünür.
func _refresh_world() -> void:
	var spots: Array[Node3D] = _spots()
	for i: int in spots.size():
		var spot: Node3D = spots[i]
		if not is_instance_valid(spot):
			continue
		var open: bool = is_bay_unlocked(i)
		var revealed: bool = is_bay_revealed(i)
		spot.visible = open
		if spot.get_node_or_null("Lift") == null:
			spot.add_child(RepairLift.new())   # alan = lift (CarSpot'un çocuğu: alanla birlikte taşınır)
		# Kilit görseli yalnızca "inşa edilmiş ama satın alınmamış" alanlarda durur
		if (open or not revealed) and _locks.has(i):
			(_locks[i] as Node3D).queue_free()
			_locks.erase(i)
		elif not open and revealed and not _locks.has(i):
			_locks[i] = _build_lock(i, spot)
		if _locks.has(i):
			_update_lock_text(i)
		if i < _positions.size():
			apply_layout(i)


## Kilitli alan: koyu zemin + sarı bariyer + asma kilit + krem fiyat plakası + tıklama kutusu.
func _build_lock(index: int, spot: Node3D) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "LockedBay%d" % (index + 1)
	spot.get_parent().add_child(root)
	root.global_transform = spot.global_transform

	var plot: MeshInstance3D = _mesh("Plot", _box(Vector3(0.5, 0.004, 0.7)),
		_material(Color("32363C"), 0.9, 0.0), Vector3(0.0, 0.002, 0.0))
	root.add_child(plot)
	# Bariyer çıtaları (sarı/siyah şerit dili)
	for z: float in [-0.3, 0.3]:
		root.add_child(_mesh("Bar%.0f" % (z * 10.0), _box(Vector3(0.5, 0.02, 0.035)),
			_material(Color("F5BE4C"), 0.5, 0.2), Vector3(0.0, 0.012, z)))

	# Asma kilit (gövde + halka)
	var lock_mat: StandardMaterial3D = _material(Color("F5BE4C"), 0.35, 0.6)
	root.add_child(_mesh("LockBody", _box(Vector3(0.07, 0.055, 0.035)), lock_mat, Vector3(0.0, 0.10, 0.0)))
	var shackle: TorusMesh = TorusMesh.new()
	shackle.inner_radius = 0.018
	shackle.outer_radius = 0.028
	shackle.rings = 12
	shackle.ring_segments = 8
	var arc: MeshInstance3D = _mesh("LockShackle", shackle, _material(Color("C9CDD4"), 0.3, 0.8),
		Vector3(0.0, 0.142, 0.0))
	arc.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	root.add_child(arc)

	# Fiyat plakası (krem zemin + koyu yazı, kameraya dönük)
	var plate_mat: StandardMaterial3D = _material(Color("F3E8CF"), 0.8, 0.0)
	plate_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	plate_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.56, 0.19)
	# Fiyat plakası ve yazısı dünya plakası katmanında: garaj düzenlenirken görünmez (garajın
	# içinde, eşyaların önünde yüzüyordu). Asma kilit ve bariyer zeminde kalır.
	var plate: MeshInstance3D = _mesh("Plate", quad, plate_mat, Vector3(0.0, 0.30, 0.0))
	plate.layers = WorldCamera.LAYER_WORLD_UI
	root.add_child(plate)

	var label: Label3D = Label3D.new()
	label.name = "PlateText"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 2
	label.pixel_size = 0.00105
	label.font_size = 48
	label.outline_size = 0
	label.modulate = Color("2F3236")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector3(0.0, 0.30, 0.0)
	label.layers = WorldCamera.LAYER_WORLD_UI
	root.add_child(label)

	# Tıklama kutusu (car_hitbox / shop_hitbox ile aynı yöntem)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "ClickBody"
	body.input_ray_pickable = true
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.5, 0.42, 0.7)
	shape.shape = box
	shape.position = Vector3(0.0, 0.21, 0.0)
	body.add_child(shape)
	body.input_event.connect(_on_lock_input.bind(index))
	root.add_child(body)
	return root


## Plaka yazısı bakiyeye/seviyeye göre güncellenir.
func _update_lock_text(index: int) -> void:
	var root: Node3D = _locks.get(index)
	if root == null or not is_instance_valid(root):
		return
	var label: Label3D = root.get_node_or_null("PlateText")
	if label == null:
		return
	var title: String = "TAMİR ALANI %d" % (index + 1)
	match status(index):
		Status.NEEDS_LEVEL:
			label.text = "%s\nGARAJ Sv.%d GEREKLİ" % [title, required_level(index)]
		Status.TOO_EXPENSIVE:
			label.text = "%s\n%s ₺" % [title, Hud.format_thousands(price(index))]
		_:
			label.text = "%s\n%s ₺  ·  AÇ" % [title, Hud.format_thousands(price(index))]


func _on_lock_input(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3,
		_shape: int, index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		bay_clicked.emit(index)
		get_viewport().set_input_as_handled()


func _mesh(node_name: String, mesh: Mesh, material: Material, position: Vector3) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


func _box(size: Vector3) -> BoxMesh:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return mesh


func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat


# --- Bağlantılar -------------------------------------------------------------------

## Alan listesi RepairManager'ındır (tek kaynak); burada kopyası tutulmaz.
func _spots() -> Array[Node3D]:
	var manager: RepairManager = get_tree().get_first_node_in_group("repair_manager") as RepairManager
	return manager.repair_car_spots if manager else ([] as Array[Node3D])


func _upgrades() -> GarageUpgradeManager:
	return get_tree().get_first_node_in_group("garage_upgrades") as GarageUpgradeManager


func _economy() -> EconomyManager:
	return get_tree().get_first_node_in_group("economy") as EconomyManager


func _request_save() -> void:
	var save: Node = get_tree().get_first_node_in_group("save_manager")
	if save and save.has_method(&"request_save"):
		save.request_save()
