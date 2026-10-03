class_name RepairBayManager
extends Node
## TAMİR ALANLARI: garajdaki hangi CarSpot'un açık olduğunun TEK kaynağı.
## Sahnede World/Gameplay/RepairBayManager olarak durur; arayanlar "repair_bays" grubundan bulur
## (autoload yok — proje kuralı).
##
## SATIN ALMA: alanlar GARAJ panelinden (GaragePanel) sırayla satın alınır; garaj seviyesi yalnızca
## alanın alınabilir olduğu eşiktir (alan N için garaj Sv.N). Satın alınan alan dünyada ilk boş
## yere konur ve garaj düzenleyicisinde dekor gibi taşınır / döndürülür. Dünyada kilit, bariyer ya da
## fiyat plakası yoktur. Kullanılabilir kapasite = SATIN ALINMIŞ alan sayısı (RepairManager.capacity()
## bunu okur), böylece açılmamış CarSpot'a hiçbir araç gönderilmez.
##
## Para yalnızca EconomyManager'dan geçer, kalıcılık SaveManager'ındır (bu node yalnızca
## request_save çağırır).
##
## Kare başına iş yapmaz (_process yok).

## Alan açıldı (0 tabanlı indeks).
signal bay_unlocked(index: int)
## Satın alma olmadı: seviye yetmiyor, zaten açık ya da bakiye yetersiz.
signal purchase_failed(index: int, price: int)
## Açık alan listesi değişti (satın alma, kayıttan yükleme, yeni oyun).
signal bays_changed
## Satın almada garajda alana boş yer bulunamadı (para düşmez).
signal no_room(index: int)
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
var _positions: Array[Vector2] = DEFAULT_POSITIONS.duplicate()
var _yaws: Array[float] = [DEFAULT_YAW, DEFAULT_YAW, DEFAULT_YAW]


func _ready() -> void:
	add_to_group("repair_bays")
	_unlocked = starting_bays
	_connect.call_deferred()


func _connect() -> void:
	_refresh_world()


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


## Bu alanı satın almak için gereken GARAJ SEVİYESİ (0. alan → Sv.1, 1. alan → Sv.2 ...).
func required_level(index: int) -> int:
	return index + 1


## Alan dünyada var mı (satın alınmış mı)? Satın alınmamış alan dünyada hiç görünmez.
func is_bay_revealed(index: int) -> bool:
	return is_bay_unlocked(index)


## Dünyada duran (satın alınmış) alanların CarSpot node'ları: garaj düzenleyicisi hepsini engel
## sayar (üstüne eşya konamaz).
func revealed_spots() -> Array[Node3D]:
	var out: Array[Node3D] = []
	var spots: Array[Node3D] = _spots()
	for i: int in spots.size():
		if is_bay_unlocked(i) and is_instance_valid(spots[i]):
			out.append(spots[i])
	return out


## UI'ın tek karar noktası.
func status(index: int) -> Status:
	if is_bay_unlocked(index):
		return Status.OPEN
	if index != unlocked_count():
		return Status.NEEDS_LEVEL   # sıradaki alan değil: önce öncekini al
	var upgrades: GarageUpgradeManager = _upgrades()
	if upgrades and upgrades.garage_level() < required_level(index):
		return Status.NEEDS_LEVEL   # garaj yeterince büyük değil
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
	# Önce yer: garajda boş yer yoksa para düşmez
	var view: GarageDecorView = get_tree().get_first_node_in_group("garage_decor_view") as GarageDecorView
	var spot: Dictionary = view.find_bay_spot(index) if view else {"pos": DEFAULT_POSITIONS[mini(index, DEFAULT_POSITIONS.size() - 1)], "yaw": DEFAULT_YAW}
	if spot.is_empty():
		no_room.emit(index)
		return false
	var economy: EconomyManager = _economy()
	if economy and not economy.spend_money(price(index)):   # bakiye yetmezse para değişmez
		purchase_failed.emit(index, price(index))
		return false
	_positions[index] = spot["pos"]
	_yaws[index] = fposmod(float(spot["yaw"]), 360.0)
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


## Alanın CarSpot düğümü.
func bay_node(index: int) -> Node3D:
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
	if index < 0 or index >= spots.size() or not is_instance_valid(spots[index]):
		return
	var node: Node3D = spots[index]
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
		spot.visible = open
		if spot.get_node_or_null("Lift") == null:
			spot.add_child(RepairLift.new())   # alan = lift (CarSpot'un çocuğu: alanla birlikte taşınır)
		if i < _positions.size():
			apply_layout(i)


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
