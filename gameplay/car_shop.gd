class_name CarShop
extends Node
## ARAÇ MAĞAZASI — showroom'un ARAÇLAR sekmesi (2026-11-02, kullanıcı kararları; docs/ARAC_MAGAZASI.md).
## Mağaza kasalarının havuzundaki araçlar (hurdalık klasikleri, başlangıç aracı ve polis satılmaz) iki yoldan alınır:
##   GEM → hemen: gem düşer, araç sahipliğe girer (VehicleOwnership.grant_purchased → YERLEŞTİR akışı).
##   ₺   → SİPARİŞ: para hemen düşer, araç `delivery_hours` (24) saatte teslim edilir. Her ödüllü reklam
##         (AdPolicy.CAR_DELIVERY) `ad_cut_hours` (8) saat kısaltır: 3 reklam = hemen. Süre oyun kapalıyken de akar.
## YALNIZ GEM araçlarda ₺ fiyatı yoktur (vehicles/car_shop.json: "tl" yok). Seviye kilidi: cars.json min_level.
## Aynı anda birden çok sipariş olabilir; siparişteki araç ikinci kez alınamaz. Sipariş beklerken araç başka yoldan
## (kasa, hediye) gelirse teslimde ₺ iade edilir.
## FİYAT: vehicles/car_shop.json "cars" (onaylanan tablo); listede olmayan yeni kasa aracı formülle (car_shop.json
## _readme). Canlı etkinlik araç indirimi (LiveEvent "cars") iki fiyata da uygulanır.
## SAAT: OfflineEarnings.now() (Google'ın HTTPS Date başlığına bağlı güvenilir saat; yoksa cihaz saati).
## Kayıt: SaveManager "car_shop" {orders: [{id, price, ordered_at, ready_at, ads}]}. GarageSystem kodla kurar
## (arkadaş ziyaretinde kurulmaz).

## Siparişler değişti (yeni sipariş, reklamla kısalma, teslim, kayıttan yükleme).
signal changed
## Gemle alındı (araç sahiplikte).
signal bought(vehicle_id: StringName)
## ₺ siparişi verildi.
signal ordered(vehicle_id: StringName)
## Sipariş teslim edildi (araç sahiplikte).
signal delivered(vehicle_id: StringName)
## Sipariş teslim edilemedi (araç bu arada başka yoldan geldi): ₺ iade edildi.
signal refunded(vehicle_id: StringName, amount: int)

const DATA_PATH: String = "res://vehicles/car_shop.json"

enum State {
	AVAILABLE,     ## satın alınabilir (fiyat / bakiye ayrıca)
	OWNED,         ## zaten sende
	ORDERED,       ## ₺ siparişi yolda
	LOCKED,        ## oyuncu seviyesi yetmiyor
	NOT_FOR_SALE,  ## mağazada yok (hurdalık, başlangıç aracı, polis, katalogda yok)
}

## Satın alma engeli (boş = alınabilir).
const OK: StringName = &""
const BLOCK_NOT_FOR_SALE: StringName = &"not_for_sale"
const BLOCK_OWNED: StringName = &"owned"
const BLOCK_ORDERED: StringName = &"ordered"
const BLOCK_LEVEL: StringName = &"level"
const BLOCK_GEM_ONLY: StringName = &"gem_only"
const BLOCK_MONEY: StringName = &"money"
const BLOCK_GEMS: StringName = &"gems"

static var _data: Dictionary = {}
static var _ids_cache: Array[StringName] = []

## Testler için "şimdi" (unix sn); 0 = gerçek saat.
var test_now: int = 0

var _orders: Array[Dictionary] = []
var _timer: Timer


func _ready() -> void:
	name = "CarShop"
	add_to_group("car_shop")
	_timer = Timer.new()
	_timer.name = "DeliveryTimer"
	_timer.wait_time = 1.0
	_timer.timeout.connect(check_deliveries)
	add_child(_timer)
	_sync_timer()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and is_inside_tree():
		check_deliveries.call_deferred()


# --- Katalog ve fiyat (durumsuz) ------------------------------------------------------------

static func load_from(path: String = DATA_PATH) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("CarShop: '%s' açılamadı (%d)" % [path, FileAccess.get_open_error()])
		_data = {"cars": {}}
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_data = parsed if parsed is Dictionary else {"cars": {}}
	_ids_cache.clear()
	return parsed is Dictionary


static func _ensure_loaded() -> void:
	if _data.is_empty():
		load_from()


static func _num(key: String, fallback: float) -> float:
	_ensure_loaded()
	return SaveSafe.f(_data.get(key, fallback))


## Mağazadaki araçlar, kasa sırasıyla (ŞEHİR → SÜPER), kasa içinde seviye ve değere göre.
static func ids() -> Array[StringName]:
	_ensure_loaded()
	if not _ids_cache.is_empty():
		return _ids_cache
	for crate: Dictionary in CrateCatalog.all():
		var pool: Array[StringName] = []
		for id: StringName in CrateCatalog.pool(crate["id"]):
			if is_for_sale(id):
				pool.append(id)
		pool.sort_custom(func(a: StringName, b: StringName) -> bool:
			var la: int = required_level(a)
			var lb: int = required_level(b)
			return la < lb if la != lb else value_of(a) < value_of(b))
		_ids_cache.append_array(pool)
	return _ids_cache


## Mağazada satılıyor mu: bir mağaza kasasının havuzunda ve edinilebilir.
static func is_for_sale(vehicle_id: StringName) -> bool:
	return CrateCatalog.crate_of(vehicle_id) != &"" and CarCatalog.is_obtainable(vehicle_id)


## Aracın ailesi (çıktığı kasa: süzgeç çipleri).
static func family_of(vehicle_id: StringName) -> StringName:
	return CrateCatalog.crate_of(vehicle_id)


static func value_of(vehicle_id: StringName) -> int:
	return int(CarCatalog.get_entry(vehicle_id).get("price", 0))


static func required_level(vehicle_id: StringName) -> int:
	return int(CarCatalog.get_entry(vehicle_id).get("min_level", 1))


static func _entry(vehicle_id: StringName) -> Dictionary:
	_ensure_loaded()
	var cars: Dictionary = _data.get("cars", {}) if _data.get("cars") is Dictionary else {}
	return cars.get(String(vehicle_id), {}) if cars.get(String(vehicle_id)) is Dictionary else {}


## Yalnız gemle mi satılıyor.
static func is_gem_only(vehicle_id: StringName) -> bool:
	if not is_for_sale(vehicle_id):
		return false
	var entry: Dictionary = _entry(vehicle_id)
	if not entry.is_empty():
		return not entry.has("tl")
	var crates: Array = _data.get("gem_only_crates", []) if _data.get("gem_only_crates") is Array else []
	return crates.has(String(family_of(vehicle_id)))


static func _markup(vehicle_id: StringName) -> float:
	var table: Dictionary = _data.get("markup", {}) if _data.get("markup") is Dictionary else {}
	return SaveSafe.f(table.get(String(CrateCatalog.rarity_of(vehicle_id)), 1.0))


## İndirimsiz ₺ fiyatı (yalnız gem ya da satılmıyorsa 0).
static func base_tl_price(vehicle_id: StringName) -> int:
	if not is_for_sale(vehicle_id) or is_gem_only(vehicle_id):
		return 0
	var entry: Dictionary = _entry(vehicle_id)
	if entry.has("tl"):
		return maxi(SaveSafe.i(entry["tl"]), 0)
	var step: float = maxf(_num("tl_round", 1000.0), 1.0)
	return int(round(float(value_of(vehicle_id)) * _markup(vehicle_id) / step) * step)


## İndirimsiz gem fiyatı (satılmıyorsa 0).
static func base_gem_price(vehicle_id: StringName) -> int:
	if not is_for_sale(vehicle_id):
		return 0
	var entry: Dictionary = _entry(vehicle_id)
	if entry.has("gem"):
		return maxi(SaveSafe.i(entry["gem"]), 0)
	if is_gem_only(vehicle_id):
		var step_only: float = maxf(_num("gem_only_round", 50.0), 1.0)
		var raw: float = float(value_of(vehicle_id)) * _markup(vehicle_id) / maxf(_num("gem_only_rate", 500.0), 1.0)
		return maxi(int(round(raw / step_only) * step_only), int(step_only))
	var step: float = maxf(_num("gem_round", 5.0), 1.0)
	var rate: float = float(maxi(required_level(vehicle_id), 1)) * maxf(_num("gem_level_rate", 100.0), 1.0)
	return maxi(int(ceilf(float(base_tl_price(vehicle_id)) / rate / step) * step), int(step))


## Satış fiyatları: canlı etkinlik araç indirimi düşülmüş.
static func tl_price(vehicle_id: StringName) -> int:
	return LiveEvent.sale_price(&"cars", base_tl_price(vehicle_id))


static func gem_price(vehicle_id: StringName) -> int:
	return LiveEvent.sale_price(&"cars", base_gem_price(vehicle_id))


static func delivery_seconds() -> int:
	return int(_num("delivery_hours", 24.0) * 3600.0)


static func ad_cut_seconds() -> int:
	return int(_num("ad_cut_hours", 8.0) * 3600.0)


# --- Durum ---------------------------------------------------------------------------------

func state_of(vehicle_id: StringName) -> State:
	if not is_for_sale(vehicle_id):
		return State.NOT_FOR_SALE
	var ownership: VehicleOwnership = _ownership()
	if ownership and ownership.is_owned(vehicle_id):
		return State.OWNED
	if is_ordered(vehicle_id):
		return State.ORDERED
	if _player_level() < required_level(vehicle_id):
		return State.LOCKED
	return State.AVAILABLE


## Gemle alma engeli (boş = alınabilir).
func gem_block(vehicle_id: StringName) -> StringName:
	var reason: StringName = _state_block(vehicle_id)
	if reason != OK:
		return reason
	var progress: PlayerProgress = _progress()
	if progress and not progress.can_afford_gems(gem_price(vehicle_id)):
		return BLOCK_GEMS
	return OK


## ₺ ile sipariş engeli (boş = verilebilir).
func money_block(vehicle_id: StringName) -> StringName:
	var reason: StringName = _state_block(vehicle_id)
	if reason != OK:
		return reason
	if is_gem_only(vehicle_id):
		return BLOCK_GEM_ONLY
	var economy: EconomyManager = _economy()
	if economy and not economy.can_afford(tl_price(vehicle_id)):
		return BLOCK_MONEY
	return OK


func _state_block(vehicle_id: StringName) -> StringName:
	match state_of(vehicle_id):
		State.NOT_FOR_SALE:
			return BLOCK_NOT_FOR_SALE
		State.OWNED:
			return BLOCK_OWNED
		State.ORDERED:
			return BLOCK_ORDERED
		State.LOCKED:
			return BLOCK_LEVEL
	return OK


# --- Satın alma ------------------------------------------------------------------------------

## GEM → hemen. Engel varsa hiçbir şey değişmez (false).
func buy_with_gems(vehicle_id: StringName) -> bool:
	if gem_block(vehicle_id) != OK:
		return false
	var ownership: VehicleOwnership = _ownership()
	var progress: PlayerProgress = _progress()
	if ownership == null or progress == null or not progress.spend_gems(gem_price(vehicle_id)):
		return false
	ownership.grant_purchased(vehicle_id)
	bought.emit(vehicle_id)
	changed.emit()
	_save_now()
	return true


## ₺ → sipariş (teslim delivery_seconds sonra). Engel varsa hiçbir şey değişmez (false).
func order_with_money(vehicle_id: StringName) -> bool:
	if money_block(vehicle_id) != OK:
		return false
	var price: int = tl_price(vehicle_id)
	var economy: EconomyManager = _economy()
	if economy == null or not economy.spend_money(price):
		return false
	var at: int = now()
	_orders.append({"id": vehicle_id, "price": price, "ordered_at": at, "ready_at": at + delivery_seconds(), "ads": 0})
	_sync_timer()
	ordered.emit(vehicle_id)
	changed.emit()
	_save_now()
	return true


# --- Siparişler -------------------------------------------------------------------------------

func orders() -> Array[Dictionary]:
	return _orders


func order_count() -> int:
	return _orders.size()


func is_ordered(vehicle_id: StringName) -> bool:
	return not order_of(vehicle_id).is_empty()


func order_of(vehicle_id: StringName) -> Dictionary:
	for order: Dictionary in _orders:
		if order["id"] == vehicle_id:
			return order
	return {}


## Siparişin teslimine kalan süre (sn; sipariş yoksa 0).
func time_left(vehicle_id: StringName) -> int:
	var order: Dictionary = order_of(vehicle_id)
	return maxi(int(order["ready_at"]) - now(), 0) if not order.is_empty() else 0


## Bir reklamın bu siparişten keseceği süre (sn): en çok ad_cut_seconds, kalan kadar.
func ad_cut_for(vehicle_id: StringName) -> int:
	return mini(ad_cut_seconds(), time_left(vehicle_id))


## Ödüllü reklam izlendi: sipariş ad_cut_seconds kısalır; süre biterse araç hemen teslim edilir (true: kısaldı).
func cut_with_ad(vehicle_id: StringName) -> bool:
	var order: Dictionary = order_of(vehicle_id)
	if order.is_empty():
		return false
	order["ready_at"] = int(order["ready_at"]) - ad_cut_seconds()
	order["ads"] = int(order.get("ads", 0)) + 1
	changed.emit()
	if int(order["ready_at"]) <= now():
		check_deliveries()
	else:
		_save_now()
	return true


## Süresi dolan siparişleri teslim eder (zamanlayıcı, uygulama dönüşü, kayıttan yükleme, reklam).
func check_deliveries() -> void:
	if _orders.is_empty():
		_sync_timer()
		return
	var at: int = now()
	var due: Array[Dictionary] = []
	for order: Dictionary in _orders:
		if int(order["ready_at"]) <= at:
			due.append(order)
	if due.is_empty():
		return
	for order: Dictionary in due:
		_orders.erase(order)
		_deliver(order)
	_sync_timer()
	changed.emit()
	_save_now()


func _deliver(order: Dictionary) -> void:
	var id: StringName = order["id"]
	var ownership: VehicleOwnership = _ownership()
	if ownership and ownership.grant_purchased(id):
		delivered.emit(id)
		return
	# Araç bu arada kasadan / hediyeden geldi (ya da katalogdan kalktı): ödenen ₺ geri verilir
	var economy: EconomyManager = _economy()
	var amount: int = int(order.get("price", 0))
	if economy and amount > 0:
		economy.add_money(amount)
	refunded.emit(id, amount)


func _sync_timer() -> void:
	if _timer == null:
		return
	if _orders.is_empty():
		_timer.stop()
	elif _timer.is_stopped() and is_inside_tree():
		_timer.start()


# --- Saat ----------------------------------------------------------------------------------

## Güvenilir "şimdi" (unix sn): OfflineEarnings'in sunucu saatine bağlı sayacı, yoksa cihaz saati.
func now() -> int:
	if test_now > 0:
		return test_now
	var away: OfflineEarnings = get_tree().get_first_node_in_group("offline_earnings") as OfflineEarnings \
			if is_inside_tree() else null
	return away.now() if away else int(Time.get_unix_time_from_system())


# --- Kayıt ---------------------------------------------------------------------------------

func state() -> Dictionary:
	var out: Array = []
	for order: Dictionary in _orders:
		out.append({"id": String(order["id"]), "price": int(order["price"]), "ordered_at": int(order["ordered_at"]),
			"ready_at": int(order["ready_at"]), "ads": int(order.get("ads", 0))})
	return {"orders": out}


func load_state(data: Dictionary) -> void:
	_orders.clear()
	var seen: Dictionary = {}
	var raw_orders: Variant = data.get("orders", [])
	for raw: Variant in raw_orders if raw_orders is Array else []:
		if not raw is Dictionary:
			continue
		var entry: Dictionary = raw
		var id: StringName = StringName(SaveSafe.s(entry.get("id", "")))
		if seen.has(id) or CarCatalog.get_entry(id).is_empty():
			continue   # bozuk / tekrarlı / katalogdan kalkmış sipariş atılır
		seen[id] = true
		var ordered_at: int = maxi(SaveSafe.i(entry.get("ordered_at", 0)), 0)
		# Teslim en geç sipariş + delivery_seconds: elle yazılmış uzak bir tarih aracı sonsuza kilitlemesin
		var ready_at: int = clampi(SaveSafe.i(entry.get("ready_at", 0)), 0, ordered_at + delivery_seconds())
		_orders.append({"id": id, "price": maxi(SaveSafe.i(entry.get("price", 0)), 0), "ordered_at": ordered_at,
			"ready_at": ready_at, "ads": clampi(SaveSafe.i(entry.get("ads", 0)), 0, 99)})
	_sync_timer()
	changed.emit()
	if is_inside_tree():
		check_deliveries.call_deferred()   # kapalıyken süresi dolanlar açılışta gelir


func reset() -> void:
	load_state({})


## Para / gem el değiştirdi: kayıt hemen yazılır (uygulama şimdi kapansa da ödeme ve sipariş birlikte kalır).
func _save_now() -> void:
	var save: SaveManager = get_tree().get_first_node_in_group("save_manager") as SaveManager if is_inside_tree() else null
	if save:
		save.save_game()


func _ownership() -> VehicleOwnership:
	return get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership if is_inside_tree() else null


func _economy() -> EconomyManager:
	return get_tree().get_first_node_in_group("economy") as EconomyManager if is_inside_tree() else null


func _progress() -> PlayerProgress:
	return get_tree().get_first_node_in_group("player_progress") as PlayerProgress if is_inside_tree() else null


func _player_level() -> int:
	var progress: PlayerProgress = _progress()
	return progress.level if progress else 1
