class_name DecorManager
extends Node
## GARAJ DEKORASYONU — sahiplik ve yerleştirme durumu (tek kaynak).
##
## Satın alma kalıcı SAHİPLİKTİR: para gider, eşya bir daha alınmaz ve garaj değerine katkısı
## yuvaya konsa da konmasa da sayılır (Car Town'daki "Item Storage" mantığı). Yuvalar yalnızca
## görsel düzenlemedir; alınan eşya uygun boş yuva varsa oraya kendiliğinden yerleşir.
##
## Katalog: gameplay/garage_decor.gd · Kayıt: SaveManager v8 ("decor")

signal purchased(id: StringName)
signal purchase_failed(id: StringName, price: int)
signal placement_changed()

## Sahip olunan eşya id'leri.
var _owned: Array[StringName] = []
## Yuva adı → eşya id'si (boş yuva sözlükte yoktur).
var _placed: Dictionary = {}


func _ready() -> void:
	add_to_group("decor")


func _economy() -> EconomyManager:
	return get_tree().get_first_node_in_group("economy") as EconomyManager


func is_owned(id: StringName) -> bool:
	return _owned.has(id)


func owned_ids() -> Array[StringName]:
	return _owned.duplicate()


func owned_count() -> int:
	return _owned.size()


## Yuvadaki eşya (boşsa &"").
func item_at(slot: StringName) -> StringName:
	return _placed.get(slot, &"")


func placements() -> Dictionary:
	return _placed.duplicate()


## Bu eşya şu an bir yuvada mı?
func is_placed(id: StringName) -> bool:
	for slot: StringName in _placed:
		if _placed[slot] == id:
			return true
	return false


## Garaj rütbesi kilidi açıldı mı?
func is_unlocked(id: StringName) -> bool:
	var item: Dictionary = GarageDecor.get_item(id)
	if item.is_empty():
		return false
	return GarageValue.current_rank(get_tree()) >= int(item.get("min_rank", 1))


## Satın alınabilir mi (sahip değil, rütbe yeter, para yeter)?
func can_purchase(id: StringName) -> bool:
	if is_owned(id) or not is_unlocked(id):
		return false
	var economy: EconomyManager = _economy()
	return economy == null or economy.can_afford(price_of(id))


func price_of(id: StringName) -> int:
	return int(GarageDecor.get_item(id).get("price", 0))


## Garaj değerine katkı (sahip olunan tüm eşyalar).
func value() -> int:
	var total: int = 0
	for id: StringName in _owned:
		total += int(GarageDecor.get_item(id).get("value", 0))
	return total


## Satın alır: para düşer, sahiplenilir ve uygun BOŞ yuva varsa oraya yerleşir.
func purchase(id: StringName) -> bool:
	if not GarageDecor.exists(id) or is_owned(id) or not is_unlocked(id):
		purchase_failed.emit(id, price_of(id))
		return false
	var economy: EconomyManager = _economy()
	var price: int = price_of(id)
	if economy and not economy.spend_money(price):
		purchase_failed.emit(id, price)
		return false
	_owned.append(id)
	_auto_place(id)
	purchased.emit(id)
	placement_changed.emit()
	return true


## Eşyayı yuvaya koyar. Eşya başka yuvadaysa oradan alınır; yuvada başka eşya varsa o depoya gider.
func place(slot: StringName, id: StringName) -> bool:
	if not _placed.has(slot) and not _slot_exists(slot):
		return false
	if id == &"":
		_placed.erase(slot)
		placement_changed.emit()
		return true
	if not is_owned(id) or GarageDecor.slot_kind(id) != GarageDecor.slot_of(slot):
		return false
	for other: StringName in _placed.keys():
		if _placed[other] == id:
			_placed.erase(other)
	_placed[slot] = id
	placement_changed.emit()
	return true


func clear_slot(slot: StringName) -> void:
	if _placed.has(slot):
		_placed.erase(slot)
		placement_changed.emit()


## Şu anki garaj seviyesinde açık olan yuvalar (avlu büyüdükçe artar).
func open_slots() -> Array[StringName]:
	var upgrades: GarageUpgradeManager = get_tree().get_first_node_in_group("garage_upgrades") as GarageUpgradeManager
	var level: int = upgrades.garage_level() if upgrades else 1
	return GarageDecor.slots_for_level(level)


## Alınan eşyayı ilk BOŞ uygun yuvaya koyar (yoksa depoda kalır).
func _auto_place(id: StringName) -> void:
	if is_placed(id):
		return   # zaten bir yuvada: ikinci kopya oluşmasın
	var kind: StringName = GarageDecor.slot_kind(id)
	for slot: StringName in open_slots():
		if GarageDecor.slot_of(slot) == kind and not _placed.has(slot):
			_placed[slot] = id
			return


func _slot_exists(slot: StringName) -> bool:
	return GarageDecor.slots().has(slot)


# --- Kayıt --------------------------------------------------------------------------

func state() -> Dictionary:
	var placed: Dictionary = {}
	for slot: StringName in _placed:
		placed[String(slot)] = String(_placed[slot])
	var owned: Array[String] = []
	for id: StringName in _owned:
		owned.append(String(id))
	return {"owned": owned, "placed": placed}


func load_state(data: Dictionary) -> void:
	_owned.clear()
	_placed.clear()
	for raw: Variant in data.get("owned", []):
		var id: StringName = StringName(String(raw))
		if GarageDecor.exists(id) and not _owned.has(id):
			_owned.append(id)
		elif not GarageDecor.exists(id):
			push_warning("DecorManager: kayıttaki '%s' katalogda yok, atlandı" % id)
	var placed: Variant = data.get("placed", {})
	if placed is Dictionary:
		for raw_slot: Variant in (placed as Dictionary):
			var slot: StringName = StringName(String(raw_slot))
			var id: StringName = StringName(String((placed as Dictionary)[raw_slot]))
			# Bozuk kayıt oyunu bozmasın: yuva/eşya yoksa ya da eşya o yuvaya girmiyorsa atlanır.
			if _slot_exists(slot) and _owned.has(id) \
					and GarageDecor.slot_kind(id) == GarageDecor.slot_of(slot):
				_placed[slot] = id
	placement_changed.emit()


func reset() -> void:
	_owned.clear()
	_placed.clear()
	placement_changed.emit()
