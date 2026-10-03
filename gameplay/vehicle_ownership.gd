class_name VehicleOwnership
extends Node
## Oyuncunun SAHİP OLDUĞU araçların TEK kaynağı — yalnızca araç id'leri (CarCatalog id'si).
## Sahnede World/Gameplay/VehicleOwnership olarak durur; arayanlar "vehicle_ownership" grubundan
## bulur (autoload yok — proje kuralı).
##
## Araç bilgisi (ad, fiyat, sahne, renk) burada TEKRARLANMAZ: hepsi CarCatalog'dan okunur.
## Para burada tutulmaz: satın alma EconomyManager.spend_money üzerinden geçer, yetersiz bakiyede
## ne para ne de sahiplik değişir. Kalıcılık SaveManager'ındır (bu node yalnızca request_save çağırır).
##
## NPC TRAFİKTEN TAMAMEN BAĞIMSIZDIR: TrafficManager katalogdaki traffic=true araçları kullanmaya
## devam eder, sahiplik onu hiç ilgilendirmez. Bir araç hem oyuncunun olabilir hem trafikte çıkabilir.
## Satın alınan araç dünyaya park edilmez; garajda görünür (MVP).
##
## KOLEKSİYON (kasa sistemi, docs/vehicle_crate_design_v2.md): araçlar artık TESLİMAT KASASINDAN
## çıkar (CrateManager). Burada üç ek durum tutulur:
##   _discovered — oyuncunun EN AZ BİR KEZ sahip olduğu araçlar. Satılan araç keşfedilmiş kalır.
##                 Showroom yalnızca bunları geri satar (purchase_vehicle = GERİ ALMA).
##   _dups       — araç başına kaç KOPYA çekildi. Kopya ikinci bir araç ÜRETMEZ (sahiplik bir
##                 kümedir, garaj değeri şişmez); yalnızca aracın yıldızını ilerletir.
##   _race_vehicle — yarışa çıkan araç (seçilmemişse / satılmışsa başlangıç aracına ya da ilk araca düşer).
##
## Kare başına iş yapmaz (_process yok): her şey sinyalle olur.
##
## BOYA: sahip olunan her aracın gövde rengi de burada tutulur (yalnızca fabrika dışı renkler).
## Renkler PaintCatalog'dan gelir; standart renk ₺ (EconomyManager), özel renk gem (PlayerProgress)
## ile alınır. Renk, aracın paylaşılan görünümüne (CarAppearance.get_for) yazılır; garaj lifti, park
## etmiş araçlar ve thumbnail'ler kendiliğinden güncellenir. NPC trafiği kendi görünüm kopyasını
## kullandığı için oyuncunun boyası trafikteki aynı model araçları ETKİLEMEZ.

## Araç satın alındı (para düşmüş, sahiplik eklenmiş).
signal vehicle_purchased(vehicle_id: StringName)
## Satın alma olmadı: zaten sahip, katalogda yok ya da bakiye yetersiz (UI uyarısı için).
signal purchase_failed(vehicle_id: StringName, price: int)
## Sahip olunan araç listesi değişti (satın alma, ekleme, çıkarma, kayıttan yükleme).
## Araç satıldı (eline geçen ₺ ile birlikte).
signal vehicle_sold(vehicle_id: StringName, payout: int)

signal ownership_changed
## Araç koleksiyona İLK KEZ girdi (kasadan ya da başlangıçta).
signal vehicle_discovered(vehicle_id: StringName)
## Aynı aracın kopyası çekildi: yeni kopya sayısı ve yıldız.
signal duplicate_added(vehicle_id: StringName, count: int, stars: int)
## Yarış aracı değişti.
signal race_vehicle_changed(vehicle_id: StringName)
## Aracın boyası değişti (satın alma, fabrika rengine dönüş, kayıttan yükleme).
signal paint_changed(vehicle_id: StringName, color: Color)
## Ücretli bir boya satın alındı (görevler bunu sayar; kayıttan yükleme ve fabrika rengine dönüş yaymaz).
signal paint_purchased(vehicle_id: StringName, paint_id: StringName)
## Boya alınamadı: araç sahipte değil, renk katalogda yok / zaten bu renk ya da bakiye yetersiz.
signal paint_failed(vehicle_id: StringName, paint_id: StringName)

## Araç UI'ında gösterilecek durum.
enum Status {
	OWNED,          ## zaten oyuncunun
	PURCHASABLE,    ## satın alınabilir (bakiye yeter)
	TOO_EXPENSIVE,  ## bakiye yetersiz
	LOCKED_LEVEL,   ## oyuncu seviyesi yetmiyor (cars.json min_level)
	LOCKED_RANK,    ## garaj değeri rütbesi yetmiyor (cars.json min_garage_rank) — kasa sisteminde kullanılmaz
	UNKNOWN,        ## katalogda yok
	UNDISCOVERED,   ## hiç keşfedilmedi: showroom'da satılmaz, yalnızca kasadan çıkar
}

## Kopya → yıldız eşikleri (kümülatif kopya sayısı): 1 kopya ★1, 3 ★2, 6 ★3, 10 ★4, 15 ★5.
const STAR_THRESHOLDS: Array[int] = [1, 3, 6, 10, 15]

## Yeni oyunda ücretsiz verilen araç (tek ayar noktası).
@export var starting_vehicle_id: StringName = &"tofas_sahin"
## Açılışta başlangıç aracını ücretsiz ver (kayıt yüklenirse kayıttaki liste geçerlidir).
@export var grant_starting_vehicle: bool = true

var _owned: Array[StringName] = []
var _paint: Dictionary = {}   # araç id → Color (yalnızca fabrika dışı renkler)
var _discovered: Array[StringName] = []
var _dups: Dictionary = {}    # araç id → kopya sayısı
var _race_vehicle: StringName = &""


func _ready() -> void:
	add_to_group("vehicle_ownership")
	if grant_starting_vehicle and _owned.is_empty():
		_grant_starting()


# --- Sorgu ---------------------------------------------------------------------

func is_owned(vehicle_id: StringName) -> bool:
	return _owned.has(vehicle_id)


## Sahip olunan araç id'leri, alınma sırasıyla (kopya — dışarıdan değiştirilemez).
func owned_vehicle_ids() -> Array[StringName]:
	return _owned.duplicate()


func owned_count() -> int:
	return _owned.size()


## Katalogdaki fiyat (araç yoksa 0). Fiyat başka hiçbir yerde tanımlanmaz.
func price(vehicle_id: StringName) -> int:
	return int(CarCatalog.get_entry(vehicle_id).get("price", 0))


## Satın alınabilir mi: katalogda var, sahip değil ve bakiye yetiyor.
func can_purchase(vehicle_id: StringName) -> bool:
	return status(vehicle_id) == Status.PURCHASABLE


## UI için tek karar noktası (SAHİPSİN / SATIN AL / PARA YETERSİZ / SEVİYE / RÜTBE).
## Car Town prensibi: pahalı araçlar yalnızca PARAYLA değil İLERLEMEYLE de açılır — oyuncu seviyesi
## (ustalık) ve garaj değeri rütbesi (garajın büyüklüğü). Kilit sırası: seviye → rütbe → para.
func status(vehicle_id: StringName) -> Status:
	var entry: Dictionary = CarCatalog.get_entry(vehicle_id)
	if entry.is_empty():
		return Status.UNKNOWN
	if is_owned(vehicle_id):
		return Status.OWNED
	# Kasa sistemi: keşfedilmemiş araç satılmaz. Keşfedilmiş araç (bir kez sahip olunmuş) seviye /
	# rütbe kilidine bakmadan GERİ ALINIR — oyuncu onu zaten açmıştı.
	if not is_discovered(vehicle_id):
		return Status.UNDISCOVERED
	var economy: EconomyManager = _economy()
	if economy and not economy.can_afford(price(vehicle_id)):
		return Status.TOO_EXPENSIVE
	return Status.PURCHASABLE


# --- Sahiplik ------------------------------------------------------------------

## GERİ ALMA (showroom) — tek merkez: katalogdan bul → keşfedilmiş mi → sahip değil mi → fiyat →
## bakiye → parayı düş → sahipliğe ekle → sinyal → kayıt. Herhangi bir adım başarısızsa hiçbir şey
## değişmez ve false döner. Hiç keşfedilmemiş araç burada ALINAMAZ (araçlar kasadan çıkar).
func purchase_vehicle(vehicle_id: StringName) -> bool:
	var entry: Dictionary = CarCatalog.get_entry(vehicle_id)
	if entry.is_empty():
		push_warning("VehicleOwnership: katalogda '%s' yok" % vehicle_id)
		purchase_failed.emit(vehicle_id, 0)
		return false
	var gate: Status = status(vehicle_id)
	if gate != Status.PURCHASABLE and gate != Status.TOO_EXPENSIVE:
		purchase_failed.emit(vehicle_id, int(entry["price"]))
		return false
	var cost: int = int(entry["price"])
	var economy: EconomyManager = _economy()
	if economy and not economy.spend_money(cost):   # bakiye yetmezse para değişmez
		purchase_failed.emit(vehicle_id, cost)
		return false
	_owned.append(vehicle_id)
	_discover(vehicle_id)
	vehicle_purchased.emit(vehicle_id)
	ownership_changed.emit()
	_request_save()
	return true


## Ücretsiz ekleme (kasa sonucu, başlangıç aracı, ödül). Para düşmez. Araç keşfedilmiş sayılır.
func add_vehicle(vehicle_id: StringName) -> bool:
	if is_owned(vehicle_id):
		return false
	if CarCatalog.get_entry(vehicle_id).is_empty():
		push_warning("VehicleOwnership: katalogda '%s' yok" % vehicle_id)
		return false
	_owned.append(vehicle_id)
	_discover(vehicle_id)
	ownership_changed.emit()
	_request_save()
	return true


## Satış oranı: aracın katalog fiyatının bu kadarı geri döner. Car Town'ın "Recycling" prensibi:
## yanlış alımın bedeli var ama araç tamamen çöpe gitmiyor. %40 seçildi çünkü daha yükseği
## "al-sat" ile ekonomi sömürüsüne, daha düşüğü satışı tamamen anlamsız hale getiriyordu.
const SELL_RATIO: float = 0.4


## Bu aracın açılması için gereken oyuncu seviyesi (UI yazısı için).
func required_level(vehicle_id: StringName) -> int:
	return int(CarCatalog.get_entry(vehicle_id).get("min_level", 1))


## Bu aracın açılması için gereken garaj değeri rütbesi (UI yazısı için).
func required_rank(vehicle_id: StringName) -> int:
	return int(CarCatalog.get_entry(vehicle_id).get("min_garage_rank", 1))


## Bu aracı satarsan eline geçecek ₺.
func sell_price(vehicle_id: StringName) -> int:
	return int(round(float(price(vehicle_id)) * SELL_RATIO))


## Aracı satar: ücret eklenir, boyası silinir, sahiplikten çıkar. Son araç satılamaz (false).
func sell_vehicle(vehicle_id: StringName) -> bool:
	if not is_owned(vehicle_id) or _owned.size() <= 1:
		return false
	var payout: int = sell_price(vehicle_id)
	if not remove_vehicle(vehicle_id):   # boyayı da temizler, fabrika rengini geri yazar
		return false
	var economy: EconomyManager = _economy()
	if economy:
		economy.add_money(payout)
	vehicle_sold.emit(vehicle_id, payout)
	return true


## Sahiplikten çıkarır (satış vb.). Son araç çıkarılamaz: garaj hiç boş kalmaz.
func remove_vehicle(vehicle_id: StringName) -> bool:
	if not is_owned(vehicle_id) or _owned.size() <= 1:
		return false
	var was_racing: bool = race_vehicle_id() == vehicle_id
	_owned.erase(vehicle_id)
	if _paint.erase(vehicle_id):
		_apply_paint(vehicle_id)
	ownership_changed.emit()
	if was_racing:
		race_vehicle_changed.emit(race_vehicle_id())
	_request_save()
	return true


# --- Kayıt ----------------------------------------------------------------------

## Kayıttan liste: katalogda olmayan id'ler atılır, liste boş kalırsa başlangıç aracı verilir.
func load_state(ids: Array) -> void:
	_owned.clear()
	for raw: Variant in ids:
		var id: StringName = StringName(SaveSafe.s(raw))
		if _owned.has(id):
			continue
		if CarCatalog.get_entry(id).is_empty():
			push_warning("VehicleOwnership: kayıttaki '%s' katalogda yok, atlandı" % id)
			continue
		_owned.append(id)
	if _owned.is_empty():
		_grant_starting()
	ownership_changed.emit()


## Yeni oyun: yalnızca ücretsiz başlangıç aracı, fabrika renkleri.
func reset() -> void:
	_owned.clear()
	_discovered.clear()
	_dups.clear()
	_race_vehicle = &""
	_grant_starting()
	_paint.clear()
	_apply_all_paint()
	ownership_changed.emit()


# --- Koleksiyon: keşif, kopya, yıldız ------------------------------------------------

func is_discovered(vehicle_id: StringName) -> bool:
	return _discovered.has(vehicle_id)


## Keşfedilmiş araçlar, keşif sırasıyla (kopya).
func discovered_ids() -> Array[StringName]:
	return _discovered.duplicate()


func discovered_count() -> int:
	return _discovered.size()


## Bu araçtan kaç kopya çekildi (ilk çekiliş sayılmaz).
func duplicate_count(vehicle_id: StringName) -> int:
	return int(_dups.get(vehicle_id, 0))


## 0–5 yıldız (kopya sayısından türetilir).
func stars(vehicle_id: StringName) -> int:
	return stars_for(duplicate_count(vehicle_id))


static func stars_for(dup_count: int) -> int:
	var result: int = 0
	for threshold: int in STAR_THRESHOLDS:
		if dup_count >= threshold:
			result += 1
	return result


## KOPYA: yalnızca sayaç ve yıldız ilerler; ikinci bir araç oluşmaz, garaj değeri değişmez.
## Araç o an sahipte değilse (satılmışsa) kopya sayılmaz — çağıran add_vehicle kullanmalı.
func add_duplicate(vehicle_id: StringName) -> int:
	if not is_owned(vehicle_id):
		return stars(vehicle_id)
	_dups[vehicle_id] = duplicate_count(vehicle_id) + 1
	duplicate_added.emit(vehicle_id, duplicate_count(vehicle_id), stars(vehicle_id))
	_request_save()
	return stars(vehicle_id)


func _discover(vehicle_id: StringName) -> void:
	if _discovered.has(vehicle_id):
		return
	_discovered.append(vehicle_id)
	vehicle_discovered.emit(vehicle_id)


## Kayıt için: {"discovered": [...], "dups": {id: n}, "race": id}.
func collection_state() -> Dictionary:
	var discovered: Array = []
	for id: StringName in _discovered:
		discovered.append(String(id))
	var dups: Dictionary = {}
	for id: StringName in _dups:
		dups[String(id)] = int(_dups[id])
	return {"discovered": discovered, "dups": dups, "race": String(_race_vehicle)}


## Kayıttan koleksiyon (load_state'ten SONRA çağrılır). Eski kayıtlarda alan yoksa sahip olunan
## araçlar keşfedilmiş sayılır. Katalogda olmayan id'ler atlanır, kopya sayıları negatif olamaz.
func load_collection(data: Dictionary) -> void:
	_discovered.clear()
	_dups.clear()
	var discovered: Variant = data.get("discovered", [])
	if discovered is Array:
		for raw: Variant in discovered:
			var id: StringName = StringName(SaveSafe.s(raw))
			if not CarCatalog.get_entry(id).is_empty() and not _discovered.has(id):
				_discovered.append(id)
	for id: StringName in _owned:   # sahip olunan her araç keşfedilmiştir (eski kayıtlar dahil)
		if not _discovered.has(id):
			_discovered.append(id)
	var dups: Variant = data.get("dups", {})
	if dups is Dictionary:
		for raw: Variant in dups:
			var id: StringName = StringName(SaveSafe.s(raw))
			if _discovered.has(id):
				_dups[id] = maxi(SaveSafe.i((dups as Dictionary)[raw]), 0)
	var race: StringName = StringName(SaveSafe.s(data.get("race", "")))
	_race_vehicle = race if is_owned(race) else &""
	race_vehicle_changed.emit(race_vehicle_id())


# --- Yarış aracı ---------------------------------------------------------------------

## Yarışa çıkan araç: seçili araç sahipteyse o; değilse başlangıç aracı, o da yoksa ilk araç.
func race_vehicle_id() -> StringName:
	if _race_vehicle != &"" and is_owned(_race_vehicle):
		return _race_vehicle
	if is_owned(starting_vehicle_id):
		return starting_vehicle_id
	return _owned[0] if not _owned.is_empty() else &""


func set_race_vehicle(vehicle_id: StringName) -> bool:
	if not is_owned(vehicle_id):
		return false
	if _race_vehicle == vehicle_id:
		return true
	_race_vehicle = vehicle_id
	race_vehicle_changed.emit(vehicle_id)
	_request_save()
	return true


# --- Boya -------------------------------------------------------------------------

## Aracın güncel gövde rengi (boyanmadıysa katalogdaki fabrika rengi).
func paint_color(vehicle_id: StringName) -> Color:
	return _paint.get(vehicle_id, _factory_color(vehicle_id))


## Bu renk alınabilir mi: araç sahipte, renk katalogda, araç zaten bu renkte değil, bakiye yetiyor.
func can_purchase_paint(vehicle_id: StringName, paint_id: StringName) -> bool:
	if not is_owned(vehicle_id):
		return false
	if paint_id == PaintCatalog.FACTORY_ID:
		return _paint.has(vehicle_id)
	var entry: Dictionary = PaintCatalog.get_entry(paint_id)
	if entry.is_empty() or (entry["color"] as Color).is_equal_approx(paint_color(vehicle_id)):
		return false
	return _can_pay(entry)


## BOYA — tek merkez: sahip mi → renk katalogda mı → zaten bu renk mi → ücret (₺ ya da gem) →
## renk → görünüm → sinyal → kayıt. Herhangi bir adım başarısızsa HİÇBİR ŞEY değişmez (false).
## FACTORY_ID ücretsizdir ve aracı katalogdaki fabrika rengine döndürür.
func purchase_paint(vehicle_id: StringName, paint_id: StringName) -> bool:
	if not is_owned(vehicle_id):
		paint_failed.emit(vehicle_id, paint_id)
		return false
	if paint_id == PaintCatalog.FACTORY_ID:
		if not _paint.erase(vehicle_id):
			paint_failed.emit(vehicle_id, paint_id)
			return false
	else:
		var entry: Dictionary = PaintCatalog.get_entry(paint_id)
		if entry.is_empty() or (entry["color"] as Color).is_equal_approx(paint_color(vehicle_id)) or not _pay(entry):
			paint_failed.emit(vehicle_id, paint_id)
			return false
		_paint[vehicle_id] = entry["color"]
	_apply_paint(vehicle_id)
	paint_changed.emit(vehicle_id, paint_color(vehicle_id))
	if paint_id != PaintCatalog.FACTORY_ID:
		paint_purchased.emit(vehicle_id, paint_id)
	_request_save()
	return true


## Kayıt için: araç id → "rrggbb" (yalnızca boyanmış araçlar).
func paint_state() -> Dictionary:
	var out: Dictionary = {}
	for id: StringName in _paint:
		out[String(id)] = (_paint[id] as Color).to_html(false)
	return out


## Kayıttan boyalar: sahip olunmayan / katalogda olmayan araçlar ve geçersiz renkler atlanır.
func load_paint(data: Dictionary) -> void:
	_paint.clear()
	for key: Variant in data:
		var id: StringName = StringName(SaveSafe.s(key))
		var hex: String = SaveSafe.s(data[key])
		if not is_owned(id) or not Color.html_is_valid(hex):
			push_warning("VehicleOwnership: kayıttaki boya atlandı (%s: %s)" % [id, hex])
			continue
		_paint[id] = Color.html(hex)
	_apply_all_paint()


func _factory_color(vehicle_id: StringName) -> Color:
	return CarCatalog.default_color_for(CarCatalog.scene_path(vehicle_id))


## Rengi aracın paylaşılan görünümüne yazar (değişince CarRig canlı instance'ları günceller).
func _apply_paint(vehicle_id: StringName) -> void:
	var scene: String = CarCatalog.scene_path(vehicle_id)
	if scene == "":
		return
	var appearance: CarAppearance = CarAppearance.get_for(scene)
	var color: Color = paint_color(vehicle_id)
	if not appearance.body_color.is_equal_approx(color):
		appearance.body_color = color


func _apply_all_paint() -> void:
	for entry: Dictionary in CarCatalog.all():
		_apply_paint(entry["id"])
		if _paint.has(entry["id"]):
			paint_changed.emit(entry["id"], _paint[entry["id"]])


func _can_pay(entry: Dictionary) -> bool:
	var cost: int = int(entry["price"])
	if int(entry["currency"]) == PaintCatalog.Currency.GEMS:
		var progress: PlayerProgress = _progress()
		return progress == null or progress.can_afford_gems(cost)
	var economy: EconomyManager = _economy()
	return economy == null or economy.can_afford(cost)


func _pay(entry: Dictionary) -> bool:
	var cost: int = int(entry["price"])
	if int(entry["currency"]) == PaintCatalog.Currency.GEMS:
		var progress: PlayerProgress = _progress()
		return progress == null or progress.spend_gems(cost)
	var economy: EconomyManager = _economy()
	return economy == null or economy.spend_money(cost)


func _progress() -> PlayerProgress:
	return get_tree().get_first_node_in_group("player_progress") as PlayerProgress


func _grant_starting() -> void:
	if CarCatalog.get_entry(starting_vehicle_id).is_empty():
		push_error("VehicleOwnership: başlangıç aracı '%s' katalogda yok" % starting_vehicle_id)
		return
	_owned.append(starting_vehicle_id)
	_discover(starting_vehicle_id)


func _economy() -> EconomyManager:
	return get_tree().get_first_node_in_group("economy") as EconomyManager


## Kayıt varsa gecikmeli (debounce) yazmasını ister; yoksa sessizce geçer.
func _request_save() -> void:
	var save: Node = get_tree().get_first_node_in_group("save_manager")
	if save and save.has_method(&"request_save"):
		save.request_save()
