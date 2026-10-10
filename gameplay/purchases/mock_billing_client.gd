class_name MockBillingClient
extends BillingClient
## SAHTE GOOGLE PLAY — masaüstü geliştirme ve testler için. Eklentinin (GodotGooglePlayBilling 3.3.0)
## sözlük biçimlerini taklit eder: aynı sinyaller, aynı anahtarlar, sonuçlar bir sonraki karede gelir.
## Gerçek para yoktur; `outcome` bir sonraki satın almanın sonucunu belirler.

enum Outcome { PURCHASED, CANCELED, PENDING, ERROR }

## Bir sonraki purchase() çağrısının sonucu.
var outcome: Outcome = Outcome.PURCHASED
## false → consume_purchase hata döner (yeniden deneme yolunu test etmek için).
var consume_ok: bool = true
## Test: tüketilmemiş satın almalar (query_purchases bunları döner, Play gibi).
var owned: Array[Dictionary] = []
## Test: bağlantı kurulsun mu.
var connect_ok: bool = true

var _ready_state: bool = false
var _queried: bool = false
var _serial: int = 0


func _init() -> void:
	pass   # eklenti tekiline bağlanmaz


func start_connection() -> void:
	_emit_later(func() -> void:
		if connect_ok:
			_ready_state = true
			connected.emit()
		else:
			connect_error.emit(BillingResponseCode.BILLING_UNAVAILABLE, "mock: kapalı"))


func end_connection() -> void:
	_ready_state = false


func is_ready() -> bool:
	return _ready_state


func get_connection_state() -> int:
	return ConnectionState.CONNECTED if _ready_state else ConnectionState.DISCONNECTED


func query_product_details(product_list: PackedStringArray, _product_type: ProductType) -> void:
	var details: Array = []
	for id: String in product_list:
		var entry: Dictionary = GemProducts.get_entry(StringName(id))
		if entry.is_empty():
			continue
		var micros: int = int(round(float(entry["usd"]) * 1_000_000.0))
		details.append({
			"product_id": id, "title": id, "name": id, "description": "", "product_type": "inapp",
			"one_time_purchase_offer_details_list": [{
				"price_amount_micros": micros, "price_currency_code": "USD",
				"formatted_price": "$%.2f" % float(entry["usd"]), "full_price_micros": micros,
				"purchase_option_id": "", "offer_id": "", "offer_token": "", "offer_tags": [],
			}],
			"subscription_offer_details": null,
		})
	_queried = true
	_emit_later(func() -> void:
		query_product_details_response.emit({"response_code": BillingResponseCode.OK, "debug_message": "",
			"product_details": details, "unfetched_products": []}))


func query_purchases(_product_type: ProductType, _include_suspended_subs: bool = false) -> void:
	var list: Array = owned.duplicate(true)
	_emit_later(func() -> void:
		query_purchases_response.emit({"response_code": BillingResponseCode.OK, "debug_message": "", "purchases": list}))


func purchase(product_id: String, _purchase_option_id: String = "", _offer_id: String = "", _is_offer_personalized: bool = false) -> Dictionary:
	if not _ready_state or not _queried:
		return {"response_code": BillingResponseCode.DEVELOPER_ERROR, "debug_message": "mock: hazır değil"}
	match outcome:
		Outcome.CANCELED:
			_emit_later(func() -> void:
				on_purchase_updated.emit({"response_code": BillingResponseCode.USER_CANCELED, "debug_message": "mock: iptal"}))
		Outcome.ERROR:
			_emit_later(func() -> void:
				on_purchase_updated.emit({"response_code": BillingResponseCode.ERROR, "debug_message": "mock: hata"}))
		_:
			var p: Dictionary = make_purchase(product_id, outcome == Outcome.PENDING)
			owned.append(p)
			_emit_later(func() -> void:
				on_purchase_updated.emit({"response_code": BillingResponseCode.OK, "debug_message": "", "purchases": [p.duplicate(true)]}))
	return {"response_code": BillingResponseCode.OK, "debug_message": ""}


func consume_purchase(purchase_token: String) -> void:
	var ok: bool = consume_ok
	if ok:
		var kept: Array[Dictionary] = []
		for p: Dictionary in owned:
			if p["purchase_token"] != purchase_token:
				kept.append(p)
		owned = kept
	_emit_later(func() -> void:
		consume_purchase_response.emit({"response_code": BillingResponseCode.OK if ok else BillingResponseCode.ERROR,
			"debug_message": "", "token": purchase_token}))


func acknowledge_purchase(purchase_token: String) -> void:
	_emit_later(func() -> void:
		acknowledge_purchase_response.emit({"response_code": BillingResponseCode.OK, "debug_message": "", "token": purchase_token}))


## Bekleyen (PENDING) satın almayı tamamlanmış yapar ve Play gibi on_purchase_updated yayar.
func complete_pending(purchase_token: String) -> void:
	for p: Dictionary in owned:
		if p["purchase_token"] == purchase_token:
			p["purchase_state"] = PurchaseState.PURCHASED
			var copy: Dictionary = p.duplicate(true)
			_emit_later(func() -> void:
				on_purchase_updated.emit({"response_code": BillingResponseCode.OK, "debug_message": "", "purchases": [copy]}))


func make_purchase(product_id: String, pending: bool = false) -> Dictionary:
	_serial += 1
	return {
		"order_id": "" if pending else "GPA.MOCK-%04d" % _serial,
		"purchase_token": "mock-token-%d-%d" % [Time.get_ticks_usec(), _serial],
		"package_name": "com.autoyard.app",
		"purchase_state": PurchaseState.PENDING if pending else PurchaseState.PURCHASED,
		"purchase_time": int(Time.get_unix_time_from_system() * 1000.0),
		"original_json": "", "is_acknowledged": false, "is_auto_renewing": false, "is_suspended": false,
		"quantity": 1, "signature": "", "product_ids": PackedStringArray([product_id]),
	}


func _emit_later(callable: Callable) -> void:
	callable.call_deferred()
