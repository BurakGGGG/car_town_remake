class_name LevelUnlocks
extends RefCounted
## SEVİYE ATLAYINCA AÇILANLAR — seviye atlama ekranının (LevelUpScreen) tek veri kaynağı. Elle liste YAZILMAZ:
## her şey sistemlerin kendi seviye kilidinden okunur (RepairType.min_level, CarGarageCatalog.required_level,
## CrateCatalog.min_level, PerformanceMods.required_level, MissionCatalog.MIN_LEVEL, ProfileCatalog.FRAMES "level",
## GarageDecor.required_level).
## Bir kilit başka seviyeye kayınca ekran kendiliğinden uyar.

enum Kind { CUSTOMER, DEPOT, CRATE, MOD_TIER, MISSIONS, FRAME, DECOR }

const MAX_LEVEL: int = 99


## (from_level, to_level] aralığında açılanlar, ekrandaki sırayla. Her kayıt {"kind": Kind, "id": StringName,
## "level": int} ve türe özgü alanlar: CUSTOMER "type" (RepairType), MOD_TIER "stage" (int), DECOR "items"
## (Array[StringName], pahalıdan ucuza; bütün dekor TEK kayıtta toplanır, "level" en yükseğidir).
static func between(from_level: int, to_level: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for type: RepairType in RepairType.defaults():
		if _in_range(type.min_level, from_level, to_level):
			out.append({"kind": Kind.CUSTOMER, "id": type.id, "level": type.min_level, "type": type})
	for garage: StringName in CarGarageCatalog.ids():
		var garage_level: int = CarGarageCatalog.required_level(garage)
		if _in_range(garage_level, from_level, to_level):
			out.append({"kind": Kind.DEPOT, "id": garage, "level": garage_level})
	for crate: Dictionary in CrateCatalog.all():
		if _in_range(int(crate["min_level"]), from_level, to_level):
			out.append({"kind": Kind.CRATE, "id": StringName(crate["id"]), "level": int(crate["min_level"])})
	for stage: int in range(1, PerformanceMods.STAGES + 1):
		if _in_range(PerformanceMods.required_level(stage), from_level, to_level):
			out.append({"kind": Kind.MOD_TIER, "id": StringName("stage_%d" % stage),
				"level": PerformanceMods.required_level(stage), "stage": stage})
	if _in_range(MissionCatalog.MIN_LEVEL, from_level, to_level):
		out.append({"kind": Kind.MISSIONS, "id": &"missions", "level": MissionCatalog.MIN_LEVEL})
	for frame: Dictionary in ProfileCatalog.FRAMES:   # elmasla alınanlar ve yalnız verilenler seviyeyle açılmaz
		if int(frame["gems"]) == 0 and not frame.get("exclusive", false) and _in_range(int(frame["level"]), from_level, to_level):
			out.append({"kind": Kind.FRAME, "id": StringName(frame["id"]), "level": int(frame["level"])})
	var decor: Array[Dictionary] = []
	for item: Dictionary in GarageDecor.all():
		if _in_range(int(item["min_level"]), from_level, to_level):
			decor.append(item)
	if not decor.is_empty():
		decor.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			# Önce garaja konan eşyalar (kaplama / karo deseninin 3B küçük resmi yok), sonra pahalıdan ucuza: kartın
			# küçük resimlerinde en gösterişli üç eşya görünür
			var a_placed: bool = GarageDecor.is_placeable(a["id"])
			if a_placed != GarageDecor.is_placeable(b["id"]):
				return a_placed
			return int(a["price"]) > int(b["price"]))
		var ids: Array[StringName] = []
		var top: int = 0
		for item: Dictionary in decor:
			ids.append(item["id"])
			top = maxi(top, int(item["min_level"]))
		out.append({"kind": Kind.DECOR, "id": &"decor", "level": top, "items": ids})
	return out


## `level`'den sonra bir şey açılan İLK seviye ve o seviyede açılanlar: {"level": int, "unlocks": Array}.
## Artık hiçbir şey açılmıyorsa boş sözlük.
static func next_after(level: int) -> Dictionary:
	var ahead: Array[Dictionary] = between(level, MAX_LEVEL)
	if ahead.is_empty():
		return {}
	var first: int = MAX_LEVEL
	for entry: Dictionary in ahead:
		if int(entry["kind"]) != Kind.DECOR:
			first = mini(first, int(entry["level"]))
	for item: StringName in _decor_items(ahead):
		first = mini(first, GarageDecor.required_level(item))
	return {"level": first, "unlocks": between(first - 1, first)}


static func _decor_items(entries: Array[Dictionary]) -> Array[StringName]:
	for entry: Dictionary in entries:
		if int(entry["kind"]) == Kind.DECOR:
			return entry["items"]
	return []


static func _in_range(level: int, from_level: int, to_level: int) -> bool:
	return level > from_level and level <= to_level
