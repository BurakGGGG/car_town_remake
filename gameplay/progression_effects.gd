class_name ProgressionEffects
## SATIN ALMANIN NE İŞE YARADIĞINI ANLATAN METİNLER — tek kaynak.
##
## QA bulgusu (docs/QA_REVIEW.md §7): garaj genişletmenin ve tamir alanı açmanın ölçülen etkisi
## büyük (garaj 2 → +%25 müşteri, alan 2 → gelir ~2 katı) ama plakalarda YALNIZCA fiyat yazıyordu;
## oyuncu neye para verdiğini göremiyordu.
##
## Buradaki satırlar ELLE YAZILMAZ: hepsi çalışan sistemlerden okunur —
##   RepairManager.SUPPLY (müşteri aralığı / bekleme noktası / ödül çarpanı / trafik),
##   RepairBayManager (hangi seviyede hangi alan ortaya çıkar, fiyatı),
##   RepairType (min_garage_level / min_bays ile açılan işler).
## Böylece tablo değiştiğinde metin kendiliğinden doğru kalır (hardcoded yanlış bilgi olmaz).
##
## Node değildir, durum tutmaz: yalnızca statik sorgu + biçimlendirme.

## Bir sonraki GARAJ SEVİYESİNİN getirdikleri (en fazla 5 satır).
static func garage_level_lines(tree: SceneTree, next_level: int) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var supply: Array[Dictionary] = RepairManager.SUPPLY
	var to: int = clampi(next_level - 1, 0, supply.size() - 1)
	var from: int = clampi(next_level - 2, 0, supply.size() - 1)
	if to == from:
		return lines
	var faster: float = float(supply[from]["interval"]) / maxf(float(supply[to]["interval"]), 0.01)
	if faster > 1.01:
		lines.append("+%%%d DAHA SIK MÜŞTERİ" % roundi((faster - 1.0) * 100.0))
	var spots: int = int(supply[to]["spots"]) - int(supply[from]["spots"])
	if spots > 0:
		lines.append("+%d BEKLEME NOKTASI" % spots)
	var richer: float = float(supply[to]["reward"]) / maxf(float(supply[from]["reward"]), 0.01)
	if richer > 1.01:
		lines.append("+%%%d DAHA DEĞERLİ MÜŞTERİ" % roundi((richer - 1.0) * 100.0))
	var bays: RepairBayManager = tree.get_first_node_in_group("repair_bays") as RepairBayManager
	if bays:
		for index: int in RepairBayManager.BAY_PRICES.size():
			if bays.required_level(index) == next_level:
				lines.append("%d. TAMİR ALANI ALINABİLİR (%s ₺)" % [index + 1, Hud.format_thousands(bays.price(index))])
	# "YENİ İŞ" yalnızca garaj seviyesi SON kilitse yazılır: işin ayrıca alan şartı varsa (min_bays)
	# onu o alanın plakası duyurur — yoksa oyuncuya tutulmayacak bir söz verilmiş olur.
	var bay_count: int = bays.unlocked_count() if bays else 1
	for type: RepairType in _types(tree):
		if type.min_garage_level == next_level and type.min_bays <= bay_count:
			lines.append("YENİ İŞ: %s" % type.title)
	return lines


## Bir TAMİR ALANININ getirdikleri.
static func bay_lines(tree: SceneTree, index: int) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("+1 EŞZAMANLI TAMİR")
	for type: RepairType in _types(tree):
		if type.min_bays == index + 1:
			lines.append("%s AÇILIR (%d sn · %s ₺)" % [
				type.title, int(type.duration), Hud.format_thousands(type.reward)])
	return lines


## ARAÇ satın alma plakasının etki satırları: garaj değerine katkı ve (kilitliyse) gereken şart.
## Var olmayan bir etki YAZILMAZ (ör. "müşteri kalitesi" henüz uygulanmadı — bkz. docs/PHASE2).
static func vehicle_lines(tree: SceneTree, vehicle_id: StringName) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var entry: Dictionary = CarCatalog.get_entry(vehicle_id)
	if entry.is_empty():
		return lines
	var ownership: VehicleOwnership = tree.get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	if ownership and ownership.is_owned(vehicle_id):
		lines.append("GARAJINDA  ·  SATIŞ %s ₺" % Hud.format_thousands(ownership.sell_price(vehicle_id)))
		return lines
	lines.append("GARAJ DEĞERİ +%s ₺" % Hud.format_thousands(int(entry.get("price", 0))))
	if ownership == null:
		return lines
	match ownership.status(vehicle_id):
		VehicleOwnership.Status.LOCKED_LEVEL:
			var progress: PlayerProgress = tree.get_first_node_in_group("player_progress") as PlayerProgress
			lines.append("SEVİYE %d GEREKLİ (şu an %d)" % [
				ownership.required_level(vehicle_id), progress.level if progress else 1])
		VehicleOwnership.Status.LOCKED_RANK:
			lines.append("GARAJ RÜTBESİ %d GEREKLİ (şu an %d)" % [
				ownership.required_rank(vehicle_id), GarageValue.current_rank(tree)])
		VehicleOwnership.Status.TOO_EXPENSIVE:
			var economy: EconomyManager = tree.get_first_node_in_group("economy") as EconomyManager
			if economy:
				lines.append("%s ₺ DAHA GEREKLİ" % Hud.format_thousands(
					maxi(int(entry.get("price", 0)) - economy.money, 0)))
	return lines


## Araç plakasının alt başlığı: "A SINIFI · 2003 · %85".
static func vehicle_subtitle(vehicle_id: StringName) -> String:
	var entry: Dictionary = CarCatalog.get_entry(vehicle_id)
	if entry.is_empty():
		return ""
	var parts: PackedStringArray = PackedStringArray()
	if String(entry.get("class", "")) != "":
		parts.append("%s SINIFI" % String(entry["class"]))
	parts.append(str(int(entry.get("year", 0))))
	parts.append("%%%d" % roundi(float(entry.get("condition", 1.0)) * 100.0))
	return "  ·  ".join(parts)


## Garaj ekranının dar plakaları için TEK SATIRLIK özet (en çok iki etki, " · " ile).
static func upgrade_summary(tree: SceneTree, id: StringName, next_level: int) -> String:
	if id == GarageUpgradeManager.SPEED_ID:
		var upgrades: GarageUpgradeManager = tree.get_first_node_in_group("garage_upgrades") as GarageUpgradeManager
		var upgrade: GarageUpgrade = upgrades.get_upgrade(id) if upgrades else null
		if upgrade == null:
			return ""
		var now: float = upgrade.value_at(next_level - 1)
		var next: float = upgrade.value_at(next_level)
		if now <= 0.0 or next >= now:
			return ""
		return "-%%%d TAMİR SÜRESİ" % roundi((1.0 - next / now) * 100.0)
	var lines: PackedStringArray = garage_level_lines(tree, next_level)
	if lines.is_empty():
		return ""
	# Alan/iş açan satır varsa o öne alınır: oyuncu için en somut kazanç odur
	var ordered: PackedStringArray = PackedStringArray()
	for line: String in lines:
		if line.contains("AÇILIR") or line.begins_with("YENİ İŞ"):
			ordered.append(line)
	for line: String in lines:
		if not ordered.has(line):
			ordered.append(line)
	return ordered[0]   # dar sütun: en somut TEK etki (ayrıntı dünyadaki plakada)


## Dar sütun için alan özeti: "2. ALAN → BOYA İŞİ, DÖŞEME" (iş yoksa eşzamanlılık satırı).
static func bay_summary(tree: SceneTree, index: int) -> String:
	var jobs: PackedStringArray = PackedStringArray()
	for type: RepairType in _types(tree):
		if type.min_bays == index + 1:
			jobs.append(type.short_title())
	if jobs.is_empty():
		return "%d. ALAN → +1 EŞZAMANLI TAMİR" % (index + 1)
	return "%d. ALAN → %s AÇILIR" % [index + 1, ", ".join(jobs)]


## Arıza kataloğu: sahnedeki RepairManager'ın listesi, yoksa varsayılan katalog.
static func _types(tree: SceneTree) -> Array[RepairType]:
	var repairs: RepairManager = tree.get_first_node_in_group("repair_manager") as RepairManager
	if repairs and not repairs.repair_types.is_empty():
		return repairs.repair_types
	return RepairType.defaults()
