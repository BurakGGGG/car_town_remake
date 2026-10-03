class_name DecorManager
extends Node
## GARAJ DEKORASYONU — DEPO (sahiplik) ve YERLEŞİM durumu. Tek kaynak.
##
## Car Town'daki mağaza / depo ayrımı: satın alınan eşya DEPOYA girer; garaja konan her kopya
## ayrı bir ÖRNEKTİR (kimlik, konum, dönüş, ölçek). Silinen örnek yok olmaz, depoya döner:
##   sahip 3 sandalye · yerleşik 2 · depoda 1 → biri silinince yerleşik 1 · depoda 2.
## Kaplamalar (zemin / duvar) yerleştirilmez, UYGULANIR: her türden tek seçim.
##
## Bu sınıf GEOMETRİ BİLMEZ: konumun geçerliliğini (garaj sınırı, çakışma, duvar) düzenleyici
## world/decor_area.gd ile sınar. Burada yalnızca tutarlılık korunur (sahip olunandan fazlası
## yerleşemez, yinelenen örnek kimliği yüklenmez, katalogda olmayan eşya atlanır).
##
## Garaj değeri: sahip olunan HER KOPYA katalog `value` kadar katkı yapar (kural değişmedi;
## eskiden eşya başına tek kopya alınabiliyordu). Katalog: gameplay/garage_decor.gd.
## Kayıt: SaveManager v9 "decor" (v8'in yuva biçimi yüklenirken taşınır, bkz. _migrate_v8).

signal purchased(id: StringName)
signal purchase_failed(id: StringName, price: int)
## Herhangi bir yerleşim / kaplama değişikliği (görünüm ve otomatik kayıt dinler).
signal placement_changed()

## Bir eşyadan en çok kaç kopya sahiplenilebilir (kayıt dosyası akıl dışı büyümesin).
const MAX_COPIES: int = 99
const SURFACE_FLOOR: StringName = &"floor"
const SURFACE_WALL: StringName = &"wall"

## Eşya id → sahip olunan kopya sayısı.
var _owned: Dictionary = {}
## Garajdaki örnekler: {"iid": String, "item": StringName, "pos": Vector3, "rot": Vector3 (derece),
## "scale": Vector3}.
var _instances: Array[Dictionary] = []
## &"floor" / &"wall" → uygulanan kaplama id'si.
var _surfaces: Dictionary = {}
var _next_iid: int = 1


func _ready() -> void:
	add_to_group("decor")


func _economy() -> EconomyManager:
	return get_tree().get_first_node_in_group("economy") as EconomyManager


# --- Depo ------------------------------------------------------------------------------

func is_owned(id: StringName) -> bool:
	return owned_of(id) > 0


func owned_of(id: StringName) -> int:
	return int(_owned.get(id, 0))


## Garajda duran kopya sayısı (kaplamalar için: uygulanıyorsa 1).
func placed_of(id: StringName) -> int:
	if GarageDecor.is_surface(id):
		return 1 if _surfaces.values().has(id) else 0
	var n: int = 0
	for inst: Dictionary in _instances:
		if inst["item"] == id:
			n += 1
	return n


## Depoda bekleyen (yerleştirilebilir) kopya sayısı.
func available_of(id: StringName) -> int:
	if GarageDecor.is_surface(id):
		return owned_of(id)   # kaplama "yerleşmez": sahipse her zaman uygulanabilir
	return maxi(owned_of(id) - placed_of(id), 0)


## Sahip olunan farklı eşya sayısı.
func owned_count() -> int:
	return _owned.size()


## Sahip olunan toplam kopya.
func owned_total() -> int:
	var n: int = 0
	for id: StringName in _owned:
		n += int(_owned[id])
	return n


func owned_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(_owned.keys())
	return out


## Garaj rütbesi kilidi açıldı mı?
func is_unlocked(id: StringName) -> bool:
	var item: Dictionary = GarageDecor.get_item(id)
	if item.is_empty():
		return false
	return GarageValue.current_rank(get_tree()) >= int(item.get("min_rank", 1))


## Satın alınabilir mi? Kaplama bir kez alınır; eşyadan birden çok kopya alınabilir.
func can_purchase(id: StringName) -> bool:
	if not GarageDecor.exists(id) or not is_unlocked(id):
		return false
	if GarageDecor.is_surface(id) and is_owned(id):
		return false
	if owned_of(id) >= MAX_COPIES:
		return false
	var economy: EconomyManager = _economy()
	return economy == null or economy.can_afford(price_of(id))


func price_of(id: StringName) -> int:
	return int(GarageDecor.get_item(id).get("price", 0))


## Garaj değerine katkı: sahip olunan her kopya (garajda olsun olmasın, Car Town "Item Storage").
func value() -> int:
	var total: int = 0
	for id: StringName in _owned:
		total += int(GarageDecor.get_item(id).get("value", 0)) * int(_owned[id])
	return total


## Bir kopya satın alır: para düşer, kopya DEPOYA girer (yerleştirmek düzenleyicinin işi).
func purchase(id: StringName) -> bool:
	if not can_purchase(id):
		purchase_failed.emit(id, price_of(id))
		return false
	var economy: EconomyManager = _economy()
	if economy and not economy.spend_money(price_of(id)):
		purchase_failed.emit(id, price_of(id))
		return false
	_owned[id] = owned_of(id) + 1
	purchased.emit(id)
	placement_changed.emit()
	return true


# --- Yerleşim --------------------------------------------------------------------------

func instances() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for inst: Dictionary in _instances:
		out.append(inst.duplicate())
	return out


func instance(iid: String) -> Dictionary:
	var i: int = _index_of(iid)
	return _instances[i].duplicate() if i >= 0 else {}


func instance_count() -> int:
	return _instances.size()


## Depodaki bir kopyayı garaja koyar. `iid` verilirse o kimlikle (geri al'ın silineni aynı
## kimlikle geri getirmesi için). Başarısızsa "" döner.
func add_instance(item: StringName, pos: Vector3, yaw: float, iid: String = "") -> String:
	if not GarageDecor.exists(item) or GarageDecor.is_surface(item):
		return ""
	if available_of(item) <= 0 or not _finite(pos) or not is_finite(yaw):
		return ""
	if iid == "":
		iid = _new_iid()
	elif _index_of(iid) >= 0:
		return ""   # aynı kimlikte iki örnek olamaz
	_instances.append({"iid": iid, "item": item, "pos": pos, "rot": Vector3(0.0, _wrap(yaw), 0.0),
		"scale": Vector3.ONE})
	placement_changed.emit()
	return iid


func move_instance(iid: String, pos: Vector3) -> bool:
	var i: int = _index_of(iid)
	if i < 0 or not _finite(pos):
		return false
	_instances[i]["pos"] = pos
	placement_changed.emit()
	return true


## Mutlak yön (derece, Y ekseni etrafında).
func rotate_instance(iid: String, yaw: float) -> bool:
	var i: int = _index_of(iid)
	if i < 0 or not is_finite(yaw):
		return false
	_instances[i]["rot"] = Vector3(0.0, _wrap(yaw), 0.0)
	placement_changed.emit()
	return true


## Konum + yön birlikte (taşıma sırasında duvar eşyası duvar değiştirince ikisi birden değişir).
func set_transform(iid: String, pos: Vector3, yaw: float) -> bool:
	var i: int = _index_of(iid)
	if i < 0 or not _finite(pos) or not is_finite(yaw):
		return false
	_instances[i]["pos"] = pos
	_instances[i]["rot"] = Vector3(0.0, _wrap(yaw), 0.0)
	placement_changed.emit()
	return true


## Örneği garajdan kaldırır: kopya DEPOYA döner (sahiplik değişmez). Silinen kaydı döndürür.
func remove_instance(iid: String) -> Dictionary:
	var i: int = _index_of(iid)
	if i < 0:
		return {}
	var removed: Dictionary = _instances[i]
	_instances.remove_at(i)
	placement_changed.emit()
	return removed.duplicate()


# --- Kaplamalar ------------------------------------------------------------------------

func surface(slot: StringName) -> StringName:
	return _surfaces.get(slot, &"")


## Sahip olunan kaplamayı uygular (zemin ya da duvar, kataloğa göre). id = "" → varsayılana döner.
func apply_surface(slot: StringName, id: StringName) -> bool:
	if slot != SURFACE_FLOOR and slot != SURFACE_WALL:
		return false
	if id == &"":
		_surfaces.erase(slot)
		placement_changed.emit()
		return true
	if not is_owned(id) or surface_slot_of(id) != slot:
		return false
	_surfaces[slot] = id
	placement_changed.emit()
	return true


## Kaplamanın hangi yüzeye gittiği.
static func surface_slot_of(id: StringName) -> StringName:
	match int(GarageDecor.get_item(id).get("kind", -1)):
		GarageDecor.Kind.FLOOR_SURFACE: return SURFACE_FLOOR
		GarageDecor.Kind.WALL_SURFACE: return SURFACE_WALL
		_: return &""


# --- Kayıt -----------------------------------------------------------------------------

## v9 biçimi. Konum / dönüş / ölçek {x, y, z} sözlüğü olarak yazılır (JSON'da okunur kalsın).
func state() -> Dictionary:
	var owned: Dictionary = {}
	for id: StringName in _owned:
		owned[String(id)] = int(_owned[id])
	var list: Array = []
	for inst: Dictionary in _instances:
		list.append({
			"instance_id": inst["iid"],
			"catalog_id": String(inst["item"]),
			"position": _vec_out(inst["pos"]),
			"rotation": _vec_out(inst["rot"]),
			"scale": _vec_out(inst["scale"]),
		})
	var surfaces: Dictionary = {}
	for slot: StringName in _surfaces:
		surfaces[String(slot)] = String(_surfaces[slot])
	return {"owned": owned, "instances": list, "surfaces": surfaces, "next_instance": _next_iid}


## v9 ya da v8 kaydını yükler. Bozuk parçalar atlanır, oyun bozulmaz.
func load_state(data: Dictionary) -> void:
	_owned.clear()
	_instances.clear()
	_surfaces.clear()
	_next_iid = 1
	if data.get("owned") is Array:
		data = _migrate_v8(data)   # v8: sahiplik dizi, yerleşim yuva → eşya
	var owned: Variant = data.get("owned", {})
	if owned is Dictionary:
		for raw: Variant in (owned as Dictionary):
			var id: StringName = StringName(SaveSafe.s(raw))
			if not GarageDecor.exists(id):
				push_warning("DecorManager: kayıttaki '%s' katalogda yok, atlandı" % id)
				continue
			var n: int = clampi(SaveSafe.i((owned as Dictionary)[raw]), 0, MAX_COPIES)
			if GarageDecor.is_surface(id):
				n = mini(n, 1)
			if n > 0:
				_owned[id] = n
	var list: Variant = data.get("instances", [])
	if list is Array:
		for raw: Variant in (list as Array):
			_load_instance(raw)
	var surfaces: Variant = data.get("surfaces", {})
	if surfaces is Dictionary:
		for raw_slot: Variant in (surfaces as Dictionary):
			var slot: StringName = StringName(SaveSafe.s(raw_slot))
			var id: StringName = StringName(SaveSafe.s((surfaces as Dictionary)[raw_slot]))
			if is_owned(id) and surface_slot_of(id) == slot:
				_surfaces[slot] = id
	_next_iid = maxi(SaveSafe.i(data.get("next_instance", 1)), _max_iid_number() + 1)
	placement_changed.emit()


func reset() -> void:
	_owned.clear()
	_instances.clear()
	_surfaces.clear()
	_next_iid = 1
	placement_changed.emit()


func _load_instance(raw: Variant) -> void:
	if not (raw is Dictionary):
		return
	var rec: Dictionary = raw
	var item: StringName = StringName(SaveSafe.s(rec.get("catalog_id", "")))
	var iid: String = SaveSafe.s(rec.get("instance_id", ""))
	if iid == "" or _index_of(iid) >= 0:
		push_warning("DecorManager: kimliksiz ya da yinelenen örnek atlandı (%s)" % iid)
		return
	if not GarageDecor.exists(item) or GarageDecor.is_surface(item):
		return
	if available_of(item) <= 0:
		push_warning("DecorManager: '%s' sahip olunandan fazla yerleştirilmiş, fazlası atlandı" % item)
		return
	var pos: Vector3 = _vec_in(rec.get("position"), Vector3.INF)
	var rot: Vector3 = _vec_in(rec.get("rotation"), Vector3.ZERO)
	var scale: Vector3 = _vec_in(rec.get("scale"), Vector3.ONE)
	if not _finite(pos) or not _finite(rot) or not _finite(scale):
		return
	_instances.append({"iid": iid, "item": item, "pos": pos, "rot": Vector3(0.0, _wrap(rot.y), 0.0),
		"scale": scale})


## v8 → v9: sahiplik dizisi → adetler; "yuva → eşya" → gerçek konumlu örnekler. Yalnızca O ANKİ
## garaj seviyesinde açık olan yuvalardaki eşyalar yerleşir (v8'de öbürleri zaten görünmüyordu,
## "depoda" bekliyordu). Konum eski yerleştiricinin hesabıyla aynı: yuva noktası, avlu köşesinden
## kurulan 0,175'lik ızgaranın göz ortasına oturtulur; duvar eşyası arka duvara asılır.
func _migrate_v8(old: Dictionary) -> Dictionary:
	var owned: Dictionary = {}
	for raw: Variant in (old.get("owned", []) as Array):
		owned[String(raw)] = 1
	var level: int = _garage_level()
	var lot: Rect2 = _legacy_lot(level)
	var instances: Array = []
	var surfaces: Dictionary = {}
	var n: int = 1
	var placed: Variant = old.get("placed", {})
	if placed is Dictionary:
		for raw_slot: Variant in (placed as Dictionary):
			var slot: StringName = StringName(String(raw_slot))
			var item: String = String((placed as Dictionary)[raw_slot])
			var kind: StringName = DecorLegacySlots.kind_of(slot)
			if kind == DecorLegacySlots.SLOT_FLOOR_SURFACE:
				surfaces[String(SURFACE_FLOOR)] = item
				continue
			if kind == DecorLegacySlots.SLOT_WALL_SURFACE:
				surfaces[String(SURFACE_WALL)] = item
				continue
			if DecorLegacySlots.level_of(slot) > level:
				continue
			var pos: Vector3
			var yaw: float
			if kind == DecorLegacySlots.SLOT_FLOOR and DecorLegacySlots.FLOOR_SLOTS.has(slot):
				var p: Vector3 = DecorLegacySlots.FLOOR_SLOTS[slot]
				var cell: float = DecorLegacySlots.LEGACY_CELL
				pos = Vector3(lot.position.x + (floorf((p.x - lot.position.x) / cell) + 0.5) * cell, 0.0,
					lot.position.y + (floorf((p.z - lot.position.y) / cell) + 0.5) * cell)
				yaw = float(DecorLegacySlots.FLOOR_SLOT_YAW[slot])
			elif kind == DecorLegacySlots.SLOT_WALL and DecorLegacySlots.WALL_SLOTS.has(slot):
				# Görünüm duvar eşyasını her yüklemede GÜNCEL arka duvara yeniden oturtur;
				# burada yalnızca duvar boyunca konum (x) önemli.
				pos = Vector3((DecorLegacySlots.WALL_SLOTS[slot] as Vector3).x, 0.0, lot.position.y)
				yaw = 0.0
			else:
				continue
			instances.append({"instance_id": "dec_%03d" % n, "catalog_id": item,
				"position": _vec_out(pos), "rotation": _vec_out(Vector3(0.0, yaw, 0.0)),
				"scale": _vec_out(Vector3.ONE)})
			n += 1
	return {"owned": owned, "instances": instances, "surfaces": surfaces, "next_instance": n}


func _garage_level() -> int:
	var upgrades: GarageUpgradeManager = get_tree().get_first_node_in_group("garage_upgrades") \
			as GarageUpgradeManager if is_inside_tree() else null
	return upgrades.garage_level() if upgrades else 1


## v8'in avlu dikdörtgeni (garage_system.gd'nin seviye ölçüleri; eski GarageDecorView.lot_rect).
static func _legacy_lot(level: int) -> Rect2:
	var widths: Array[float] = [2.0, 4.0, 6.0, 8.0]
	var depths: Array[float] = [1.5, 3.0, 4.5, 6.0]
	var i: int = clampi(level - 1, 0, widths.size() - 1)
	return Rect2(Vector2(-0.2 - widths[i], -0.2 - depths[i]), Vector2(widths[i], depths[i]))


func _new_iid() -> String:
	while _index_of("dec_%03d" % _next_iid) >= 0:
		_next_iid += 1
	var iid: String = "dec_%03d" % _next_iid
	_next_iid += 1
	return iid


func _max_iid_number() -> int:
	var best: int = 0
	for inst: Dictionary in _instances:
		var text: String = String(inst["iid"])
		if text.begins_with("dec_") and text.substr(4).is_valid_int():
			best = maxi(best, int(text.substr(4)))
	return best


func _index_of(iid: String) -> int:
	for i: int in _instances.size():
		if _instances[i]["iid"] == iid:
			return i
	return -1


static func _wrap(yaw: float) -> float:
	return fposmod(yaw, 360.0)


static func _finite(v: Vector3) -> bool:
	return is_finite(v.x) and is_finite(v.y) and is_finite(v.z)


static func _vec_out(v: Vector3) -> Dictionary:
	return {"x": snappedf(v.x, 0.0001), "y": snappedf(v.y, 0.0001), "z": snappedf(v.z, 0.0001)}


static func _vec_in(raw: Variant, fallback: Vector3) -> Vector3:
	if not (raw is Dictionary):
		return fallback
	var d: Dictionary = raw
	if not (d.has("x") and d.has("y") and d.has("z")):
		return fallback
	return Vector3(float(d["x"]), float(d["y"]), float(d["z"]))
