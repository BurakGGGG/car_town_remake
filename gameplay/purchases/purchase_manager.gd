class_name PurchaseManager
extends Node
## GERÇEK PARAYLA GEM SATIŞI — oyunun Google Play Billing'le konuştuğu TEK nokta ("purchases" grubu;
## autoload yok, GarageSystem kodla kurar). Ürünler GemProducts'ta, hepsi tüketilebilir. ÖN KAYIT ÖDÜLÜ de
## Play'den bir "satın alma" olarak gelir (FounderReward): satılmaz, aynı sözleşmeyle verilip tüketilir.
##
## ÖDEME SÖZLEŞMESİ (sıra bozulmaz):
##   Play "PURCHASED" der → SUNUCU DOĞRULAR (iapVerify) → gem eklenir + defterine yazılır → kayıt HEMEN diske
##   yazılır → ancak o zaman Play'e "tüketildi" denir. Herhangi bir adımda uygulama ölürse:
##     * gem diske yazılmadan öldüyse: satın alma tüketilmemiştir, açılışta query_purchases onu yeniden
##       getirir ve gem o zaman verilir;
##     * yazıldıktan sonra öldüyse: defterde "tüketilmedi" işaretlidir, açılışta YALNIZCA tüketilir.
##   Aynı satın alma (purchase_token) iki kez gem vermez: kayıttaki defter + cihaz defteri bakılır.
##   Satın alma PENDING ise (ör. kapıda ödeme) gem VERİLMEZ; ödeme tamamlanınca Play haber verir.
##
## BULUT: defter kayıtla birlikte buluta gider. Buluttan ESKİ bir kayıt gelirse (ör. misafirken alınıp
## hesaba geçildi) SaveManager.apply_snapshot → carry_over(): yerelde ödenmiş ama gelen kayıtta olmayan
## satın almaların gemi yeniden eklenir; parayla alınan gem kaybolmaz.
##
## SUNUCU DOĞRULAMASI (2026-10-22): gem vermeden önce satın alma firebase/functions iapVerify'a sorulur; o da Google
## Play Developer API'ye sorar (sahte satın alma araçları burada takılır). Sonuç:
##   ok → gem verilir · pending → bekler · canceled / consumed / invalid → gem YOK, tüketilmez (&"rejected")
##   sunucuya ulaşılamadı → gem YOK, tüketilmez, sonra yeniden sorulur (&"verifying"); Play tüketilmeyen satın almayı
##   3 gün içinde iade eder, oyuncu parasını kaybetmez. Sahte Play (MockBillingClient) doğrulamasız geçer.

## Ürün bilgisi / bağlantı durumu değişti (mağaza ekranı kendini tazelesin).
signal products_changed
## Bir satın alma akışı bitti. status: &"granted" · &"canceled" · &"pending" · &"error"
## · &"verifying" (sunucuya ulaşılamadı, sonra yeniden denenecek) · &"rejected" (Play satın almayı doğrulamadı)
signal purchase_finished(product_id: StringName, status: StringName)
## Gem verildi (satın alma ya da yeniden başlatmada tamamlanan ödeme).
signal gems_purchased(product_id: StringName, gems: int)
## Ön kayıt ödülü hesaba geçti (RewardPopup özeti: FounderReward.grant). Oyun içinde duyurulmalı (Play şartı).
signal founder_reward_granted(summary: Dictionary)
## İADE (2026-10-23): Play'de iade / ters ibraz edilen satın almanın gemi düşüldü. taken: düşülen, missing: bakiye
## yetmediği için düşülemeyen (bakiye 0'ın altına inmez; sunucuda iap kaydı işaretli kalır, yönetim panelinden bakılır).
signal refund_applied(product_id: StringName, taken: int, missing: int)

## Cihaz defteri: bu cihazda gem verilmiş satın almaların özetleri. Hesap değişince oyun kaydı sıfırlanır
## (SaveManager.new_game) ama Play'de tüketilmemiş kalan bir satın alma yeni oyuna İKİNCİ kez gem vermesin.
const DEVICE_LEDGER_PATH: String = "user://purchases_device.json"
## Bağlantı hatasında yeniden deneme beklemeleri (sn) — sonsuz döngü yok.
const RETRY_SEC: Array[float] = [15.0, 60.0, 180.0]
## İADELER sunucudan (users/{uid}/refunds, functions/refunds.js) bu sıklıkla ve oturum açılınca okunur.
const REFUND_POLL_SEC: float = 1800.0
## Doğrulama sunucusu (callable Cloud Function, düz HTTP) ve bekleme süresi.
const VERIFY_URL: String = CloudSaveManager.EMAIL_FUNCTIONS_URL + "iapVerify"
const VERIFY_TIMEOUT: float = 20.0
## Sunucuya ulaşılamayınca yeniden sorma beklemeleri (sn); açılışta ve oyuna dönünce de sorulur.
const VERIFY_RETRY_SEC: Array[float] = [20.0, 60.0, 180.0, 600.0]

var _client: BillingClient
var _connected: bool = false
var _products: Dictionary = {}       # id → Play ürün bilgisi (product_details sözlüğü)
var _busy_product: StringName = &""   # açık satın alma penceresi
var _ledger: Dictionary = {}         # token özeti → {product, gems, time, order, token, consumed}
var _device: Dictionary = {}         # token özeti → true
var _retry: int = 0
var _retry_timer: Timer
## Doğrulayıcı: func(product: StringName, token: String) -> Dictionary {status, quantity} (await edilir).
## Testler use_verifier ile verir; boşsa sahte Play'de doğrudan "ok", gerçekte sunucu.
var _verifier: Callable = Callable()
var _verifying: Dictionary = {}      # token özeti → true (aynı satın alma iki yoldan aynı anda gelirse)
var _rejected: Dictionary = {}       # token özeti → durum (bu oturumda sunucu reddetti: yeniden sorulmaz)
var _verify_retry: int = 0
var _verify_timer: Timer
var _refund_timer: Timer
var _refund_busy: bool = false
var _refund_uid: String = ""

## Ödemesi bekleyen (PENDING) satın alma var mı? Mağaza bilgi satırı gösterir.
var pending_payment: bool = false
## Ödenmiş ama sunucuya ulaşılamadığı için henüz doğrulanamamış satın alma var mı?
var awaiting_verification: bool = false


func _ready() -> void:
	add_to_group("purchases")
	_retry_timer = Timer.new()
	_retry_timer.one_shot = true
	_retry_timer.timeout.connect(_start_connection)
	add_child(_retry_timer)
	_verify_timer = Timer.new()
	_verify_timer.one_shot = true
	_verify_timer.timeout.connect(_requery)
	add_child(_verify_timer)
	_refund_timer = Timer.new()
	_refund_timer.wait_time = REFUND_POLL_SEC
	_refund_timer.timeout.connect(poll_refunds)
	add_child(_refund_timer)
	_refund_timer.start()
	_connect_refunds.call_deferred()
	_device = _read_device_ledger()
	if _client == null:
		_client = _pick_client()
	if _client == null:
		return   # bu platformda mağaza yok (masaüstü sürüm)
	add_child(_client)
	_client.connected.connect(_on_connected)
	_client.disconnected.connect(_on_disconnected)
	_client.connect_error.connect(_on_connect_error)
	_client.query_product_details_response.connect(_on_product_details)
	_client.query_purchases_response.connect(_on_purchases_query)
	_client.on_purchase_updated.connect(_on_purchase_updated)
	_client.consume_purchase_response.connect(_on_consumed)
	_start_connection()


## Test / geliştirme: istemciyi elle ver (_ready'den ÖNCE çağrılmalı).
func use_client(client: BillingClient) -> void:
	_client = client


## Test: doğrulayıcıyı elle ver. func(product, token) -> {status, quantity}; status: ok · pending · canceled ·
## consumed · invalid · unavailable.
func use_verifier(verifier: Callable) -> void:
	_verifier = verifier


func client() -> BillingClient:
	return _client


static func _pick_client() -> BillingClient:
	if Engine.has_singleton("GodotGooglePlayBilling"):
		return BillingClient.new()
	if OS.is_debug_build() and not OS.has_feature("android"):
		return MockBillingClient.new()   # masaüstü geliştirme: sahte Play
	return null


func _notification(what: int) -> void:
	# Oyuncu Play'den dönünce (bekleyen ödeme tamamlanmış olabilir) satın almalar yeniden sorulur.
	if what == NOTIFICATION_APPLICATION_RESUMED:
		_requery()
		poll_refunds()


# --- Dış API -------------------------------------------------------------------------------

## Mağaza kullanılabilir mi (Play'e bağlı ve fiyatlar geldi)?
func is_available() -> bool:
	return _connected and not _products.is_empty()


## Ürünün oyuncunun para birimindeki fiyatı ("₺49,99"). Bilinmiyorsa "".
func price_text(id: StringName) -> String:
	var offers: Variant = (_products.get(id, {}) as Dictionary).get("one_time_purchase_offer_details_list")
	if offers is Array and not (offers as Array).is_empty() and (offers as Array)[0] is Dictionary:
		return String(((offers as Array)[0] as Dictionary).get("formatted_price", ""))
	return ""


## Ürün şu an satın alınabilir mi? "" = evet; değilse sebep: "unavailable" · "owned" · "busy".
func block_reason(id: StringName) -> String:
	if GemProducts.get_entry(id).is_empty() or not _connected or not _products.has(id):
		return "unavailable"
	if GemProducts.is_once(id) and was_bought(id):
		return "owned"
	if _busy_product != &"":
		return "busy"
	return ""


## Bu ürün (bu kayıtta) daha önce alındı mı? Tek seferlik paketleri gizlemek için.
func was_bought(id: StringName) -> bool:
	for entry: Dictionary in _ledger.values():
		if StringName(entry.get("product", "")) == id:
			return true
	return false


## Play satın alma penceresini açar. Sonuç purchase_finished ile gelir.
func buy(id: StringName) -> bool:
	if not block_reason(id).is_empty():
		return false
	var result: Dictionary = _client.purchase(String(id))
	if int(result.get("response_code", -999)) != BillingClient.BillingResponseCode.OK:
		push_warning("PurchaseManager: satın alma açılamadı (%s): %s" % [id, result.get("debug_message", "")])
		purchase_finished.emit(id, &"error")
		return false
	_busy_product = id
	products_changed.emit()
	return true


func is_busy() -> bool:
	return _busy_product != &""


# --- Kayıt ---------------------------------------------------------------------------------

func state() -> Dictionary:
	return {"ledger": _ledger.duplicate(true)}


func load_state(data: Dictionary) -> void:
	_ledger.clear()
	var raw: Variant = data.get("ledger", {})
	if raw is Dictionary:
		for key: Variant in (raw as Dictionary):
			var e: Variant = (raw as Dictionary)[key]
			if not (key is String) or not (e is Dictionary):
				continue
			var entry: Dictionary = e
			_ledger[key] = {
				"product": SaveSafe.s(entry.get("product", "")),   # bozuk kayıtta String() / bool() yüklemeyi kesiyordu
				"gems": maxi(SaveSafe.i(entry.get("gems", 0)), 0),
				"time": SaveSafe.i(entry.get("time", 0)),
				"order": SaveSafe.s(entry.get("order", "")),
				"token": SaveSafe.s(entry.get("token", "")),
				"consumed": SaveSafe.b(entry.get("consumed", false)),
				"refunded": SaveSafe.b(entry.get("refunded", false)),
			}
	products_changed.emit()
	if _connected:
		_consume_leftovers()


## Yeni oyun (hesaptan çıkış / hesap silme): defter bu oyuna aittir, sıfırlanır. Cihaz defteri KALIR.
func reset() -> void:
	load_state({})


## Buluttan gelen kayıt uygulandı (SaveManager.apply_snapshot). `previous` = uygulanmadan önceki
## yerel defter. Yerelde gemi verilmiş ama yeni kayıtta olmayan satın almalar yeniden eklenir.
## Dönüş: eklenen toplam gem.
func carry_over(previous: Dictionary) -> int:
	var raw: Variant = previous.get("ledger", {})
	if not (raw is Dictionary):
		return 0
	var added: int = 0
	for key: Variant in (raw as Dictionary):
		if _ledger.has(key) or not ((raw as Dictionary)[key] is Dictionary):
			continue
		var entry: Dictionary = ((raw as Dictionary)[key] as Dictionary).duplicate(true)
		_ledger[key] = entry
		if SaveSafe.b(entry.get("refunded", false)):
			continue   # iade edilmiş satın alma: kayıt taşınır (ikinci kez düşülmesin), gemi geri verilmez
		added += maxi(SaveSafe.i(entry.get("gems", 0)), 0)
		if FounderReward.is_reward(StringName(String(entry.get("product", "")))):
			FounderReward.grant(get_tree(), false)   # para + kurucu eşyası da geri gelsin (elması yukarıda)
	if added > 0:
		var progress: PlayerProgress = _progress()
		if progress:
			progress.add_gems(added)
		products_changed.emit()
	return added


# --- Play olayları -----------------------------------------------------------------------------

func _start_connection() -> void:
	if _client:
		_client.start_connection()


func _on_connected() -> void:
	_connected = true
	_retry = 0
	_client.query_product_details(GemProducts.ids(), BillingClient.ProductType.INAPP)
	# Uygulama kapanmadan yarıda kalan / başka cihazda tamamlanan ödemeler
	_client.query_purchases(BillingClient.ProductType.INAPP)
	products_changed.emit()


func _on_disconnected() -> void:
	_connected = false
	products_changed.emit()
	_schedule_retry()


func _on_connect_error(code: int, message: String) -> void:
	push_warning("PurchaseManager: Play'e bağlanılamadı (%d): %s" % [code, message])
	_connected = false
	products_changed.emit()
	_schedule_retry()


func _schedule_retry() -> void:
	if _retry < RETRY_SEC.size() and _retry_timer.is_stopped():
		_retry_timer.start(RETRY_SEC[_retry])
		_retry += 1


func _on_product_details(response: Dictionary) -> void:
	if int(response.get("response_code", -999)) != BillingClient.BillingResponseCode.OK:
		push_warning("PurchaseManager: ürünler alınamadı: %s" % response.get("debug_message", ""))
		return
	_products.clear()
	for d: Variant in response.get("product_details", []):
		if d is Dictionary:
			_products[StringName(String((d as Dictionary).get("product_id", "")))] = d
	for u: Variant in response.get("unfetched_products", []):
		if u is Dictionary:
			push_warning("PurchaseManager: Play'de bulunmayan ürün: %s" % (u as Dictionary).get("product_id", ""))
	products_changed.emit()


func _on_purchases_query(response: Dictionary) -> void:
	if int(response.get("response_code", -999)) != BillingClient.BillingResponseCode.OK:
		return
	var pending: bool = false
	var unverified: bool = false
	for p: Variant in response.get("purchases", []):
		if p is Dictionary:
			var status: StringName = await _handle_purchase(p as Dictionary)
			pending = status == &"pending" or pending
			unverified = status == &"verifying" or unverified
	pending_payment = pending
	_set_awaiting(unverified)
	_consume_leftovers()
	products_changed.emit()


func _on_purchase_updated(response: Dictionary) -> void:
	var id: StringName = _busy_product
	var code: int = int(response.get("response_code", -999))
	if code == BillingClient.BillingResponseCode.USER_CANCELED:
		_busy_product = &""
		purchase_finished.emit(id, &"canceled")
	elif code != BillingClient.BillingResponseCode.OK:
		_busy_product = &""
		push_warning("PurchaseManager: satın alma başarısız (%d): %s" % [code, response.get("debug_message", "")])
		purchase_finished.emit(id, &"error")
	else:
		# Pencere doğrulama bitene kadar "meşgul" kalır (kartta "…"): ikinci satın alma araya girmesin
		for p: Variant in response.get("purchases", []):
			if not (p is Dictionary):
				continue
			var status: StringName = await _handle_purchase(p as Dictionary)
			if status == &"pending":
				pending_payment = true
			elif status == &"verifying":
				_set_awaiting(true)
			purchase_finished.emit(_product_of(p as Dictionary), status)
		_busy_product = &""
	products_changed.emit()


## Tek satın almayı işler. Dönüş: &"granted" · &"pending" · &"error" · &"verifying" · &"rejected"
## (zaten verilmişse &"granted").
func _handle_purchase(p: Dictionary) -> StringName:
	var token: String = String(p.get("purchase_token", ""))
	if token.is_empty():
		return &"error"
	if int(p.get("purchase_state", 0)) != BillingClient.PurchaseState.PURCHASED:
		return &"pending"
	var key: String = token.sha256_text()
	if _ledger.has(key) or _device.has(key):
		# Gem zaten verildi: yalnızca tüketmeyi tamamla (Play'de takılı kalmasın)
		_client.consume_purchase(token)
		return &"granted"
	var product: StringName = _product_of(p)
	var founder: bool = FounderReward.is_reward(product)
	if founder and was_bought(FounderReward.PRODUCT_ID):
		_client.consume_purchase(token)   # ödül bu kayda zaten verildi (başka belirteçle gelse bile)
		return &"granted"
	if not founder and GemProducts.gems_of(product) <= 0:
		# Bu sürümün tanımadığı ürün: TÜKETİLMEZ — tanıyan bir sürüm gemini verir.
		push_error("PurchaseManager: tanınmayan ürün %s, gem verilmedi" % product)
		return &"error"
	if _rejected.has(key):
		return &"rejected"
	if _verifying.has(key):
		return &"verifying"   # aynı satın alma başka yoldan (açılış sorgusu / güncelleme) şu an doğrulanıyor
	_verifying[key] = true
	var check: Dictionary = await _verify(product, token)
	_verifying.erase(key)
	if _ledger.has(key) or _device.has(key):
		return &"granted"   # beklerken başka yol verdi
	match String(check.get("status", "")):
		"ok":
			pass
		"pending":
			return &"pending"
		"invalid" when founder:
			# ÖN KAYIT ÖDÜLÜ ücretsizdir ve Play'in ödül belirteçlerini doğrulama API'sinin tanıyıp tanımadığı yayından
			# önce denenemez: tanımazsa ödül yine verilir (sahtesi kayıt başına bir kez 100 gem kazandırır, kayıp küçük)
			push_warning("PurchaseManager: ön kayıt ödülü Play'de doğrulanamadı, yine veriliyor")
		"canceled", "consumed", "invalid":
			push_warning("PurchaseManager: satın alma doğrulanmadı (%s): %s" % [product, check.get("status")])
			_rejected[key] = String(check.get("status"))
			return &"rejected"
		_:
			_schedule_verify_retry()
			return &"verifying"
	if founder:
		return _grant_founder(p, token, key)
	var quantity: int = maxi(SaveSafe.i(check.get("quantity", p.get("quantity", 1))), 1)
	var gems: int = GemProducts.gems_of(product) * quantity
	var progress: PlayerProgress = _progress()
	if progress:
		progress.add_gems(gems)
	_ledger[key] = {"product": String(product), "gems": gems, "time": int(Time.get_unix_time_from_system()),
		"order": String(p.get("order_id", "")), "token": token, "consumed": false}
	_device[key] = true
	_write_device_ledger()
	gems_purchased.emit(product, gems)
	if _save_now():
		_client.consume_purchase(token)
	# Yazılamadıysa tüketilmez: bir sonraki açılışta query_purchases yeniden getirir (cihaz defteri
	# gemi ikinci kez vermez, yalnızca tüketir).
	return &"granted"


## ÖN KAYIT ÖDÜLÜ: para + elmas + kurucu eşyası verilir, sonra (kayıt yazılınca) tüketilir. Bir kayda bir kez
## (_handle_purchase defterde varsa yalnızca tüketir). Sipariş no'su boş gelebilir.
func _grant_founder(p: Dictionary, token: String, key: String) -> StringName:
	var summary: Dictionary = FounderReward.grant(get_tree())
	_ledger[key] = {"product": String(FounderReward.PRODUCT_ID), "gems": FounderReward.GEMS,
		"time": int(Time.get_unix_time_from_system()), "order": String(p.get("order_id", "")), "token": token,
		"consumed": false}
	_device[key] = true
	_write_device_ledger()
	founder_reward_granted.emit(summary)
	if _save_now():
		_client.consume_purchase(token)
	return &"granted"


func _on_consumed(response: Dictionary) -> void:
	var token: String = String(response.get("token", ""))
	if token.is_empty():
		return
	var key: String = token.sha256_text()
	if int(response.get("response_code", -999)) != BillingClient.BillingResponseCode.OK:
		push_warning("PurchaseManager: tüketilemedi, sonraki açılışta yeniden denenecek: %s" % response.get("debug_message", ""))
		return
	if _ledger.has(key):
		var entry: Dictionary = _ledger[key]
		entry["consumed"] = true
		entry["token"] = ""   # tüketildi: ham anahtar artık gerekmez, kayıtta özet kalır
		_request_save()


## Defterde gemi verilmiş ama tüketilmemiş satın almaları tüketir.
func _consume_leftovers() -> void:
	for entry: Dictionary in _ledger.values():
		if not bool(entry["consumed"]) and not String(entry["token"]).is_empty():
			_client.consume_purchase(String(entry["token"]))


# --- İadeler ------------------------------------------------------------------------------------

func _connect_refunds() -> void:
	var social: SocialManager = get_tree().get_first_node_in_group("social") as SocialManager
	if social:
		# Oturum açılınca / hesap değişince hemen okunur (changed sık yayılır: aynı hesap için yeniden okunmaz)
		social.changed.connect(func() -> void:
			if social.uid() != _refund_uid:
				poll_refunds())


## Sunucudaki iade belgelerini okur, uygular, uygulananları siler. Yalnız hesaplı oyuncu (misafirin UID'si yok).
func poll_refunds() -> void:
	var social: SocialManager = get_tree().get_first_node_in_group("social") as SocialManager
	if social == null or social.uid().is_empty() or _refund_busy:
		return
	_refund_busy = true
	_refund_uid = social.uid()
	var listed: Dictionary = await social.list_refunds()
	if bool(listed.get("ok", false)):
		var docs: Dictionary = listed.get("docs", {})
		for id: String in apply_refunds(docs):
			await social.delete_refund(id)
	_refund_busy = false


## İade belgelerini uygular (belge kimliği = satın alma belirtecinin özeti = defter anahtarı). Gem, defterde verilen
## kadar (yoksa ürünün kataloğundaki kadar) düşülür; bakiye 0'ın altına inmez. Aynı iade iki kez düşülmez: defterde
## işaretlenir, kayıt hemen yazılır. Dönüş: silinebilecek belge kimlikleri (uygulanan + zaten uygulanmış + geçersiz).
func apply_refunds(docs: Dictionary) -> PackedStringArray:
	var done: PackedStringArray = PackedStringArray()
	var changed: bool = false
	for raw_id: Variant in docs:
		var id: String = str(raw_id)
		var doc: Dictionary = docs[raw_id] if docs[raw_id] is Dictionary else {}
		var product: StringName = StringName(SaveSafe.s(doc.get("product", "")))
		var entry: Dictionary = _ledger.get(id, {})
		if FounderReward.is_reward(product) or bool(entry.get("refunded", false)):
			done.append(id)   # ücretsiz ödül iade edilemez / zaten düşüldü
			continue
		var gems: int = SaveSafe.i(entry.get("gems", 0)) if not entry.is_empty() \
			else GemProducts.gems_of(product) * maxi(SaveSafe.i(doc.get("quantity", 1)), 1)
		if gems <= 0:
			done.append(id)   # tanınmayan ürün: düşülecek gem yok
			continue
		var progress: PlayerProgress = _progress()
		var have: int = progress.gems if progress else 0
		var taken: int = mini(gems, have)
		if progress and taken > 0:
			progress.add_gems(-taken)   # harcama sayılmaz (görev / başarım sayaçları ilerlemesin)
		if entry.is_empty():
			entry = {"product": String(product), "gems": gems, "time": SaveSafe.i(doc.get("at", 0)),
				"order": SaveSafe.s(doc.get("order", "")), "token": "", "consumed": true}
			_ledger[id] = entry
		entry["refunded"] = true
		changed = true
		done.append(id)
		refund_applied.emit(product, taken, gems - taken)
	if changed:
		_save_now()
		products_changed.emit()
	return done


# --- Sunucu doğrulaması --------------------------------------------------------------------------

func _verify(product: StringName, token: String) -> Dictionary:
	if _verifier.is_valid():
		var result: Variant = await _verifier.call(product, token)
		return result if result is Dictionary else {}
	if _client is MockBillingClient:
		return {"status": "ok"}   # sahte Play: doğrulanacak gerçek satın alma yok
	return await _verify_remote(product, token)


## iapVerify'ı düz HTTP ile çağırır (callable biçimi: {"data": …} → {"result": …}). Ağ / sunucu hatası → unavailable.
func _verify_remote(product: StringName, token: String) -> Dictionary:
	var http: HTTPRequest = HTTPRequest.new()
	http.timeout = VERIFY_TIMEOUT
	add_child(http)
	var social: SocialManager = get_tree().get_first_node_in_group("social") as SocialManager
	var body: Dictionary = {"data": {"package": AppInfo.package_name(), "product": String(product), "token": token,
		"uid": social.uid() if social else ""}}
	var out: Dictionary = {"status": "unavailable"}
	if http.request(VERIFY_URL, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(body)) == OK:
		var response: Array = await http.request_completed
		var parsed: Variant = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8()) \
			if int(response[0]) == HTTPRequest.RESULT_SUCCESS else null
		if int(response[1]) == 200 and parsed is Dictionary and (parsed as Dictionary).get("result") is Dictionary:
			out = (parsed as Dictionary)["result"]
		elif parsed is Dictionary:
			push_warning("PurchaseManager: doğrulama sunucusu %d: %s" % [int(response[1]), (parsed as Dictionary).get("error")])
	http.queue_free()
	return out


## Sunucuya ulaşılamadı: bir süre sonra Play'e satın almalar yeniden sorulur (tüketilmeyen geri gelir, yeniden doğrulanır).
func _schedule_verify_retry() -> void:
	if _verify_timer.is_stopped():
		_verify_timer.start(VERIFY_RETRY_SEC[mini(_verify_retry, VERIFY_RETRY_SEC.size() - 1)])
		_verify_retry += 1


func _requery() -> void:
	if _connected and _client:
		_client.query_purchases(BillingClient.ProductType.INAPP)


func _set_awaiting(on: bool) -> void:
	awaiting_verification = on
	if not on:
		_verify_retry = 0


# --- İç ----------------------------------------------------------------------------------------

static func _product_of(p: Dictionary) -> StringName:
	var ids: Variant = p.get("product_ids", PackedStringArray())
	if (ids is PackedStringArray or ids is Array) and ids.size() > 0:
		return StringName(String(ids[0]))
	return &""


func _progress() -> PlayerProgress:
	return get_tree().get_first_node_in_group("player_progress") as PlayerProgress


## Kayıt beklemeden diske yazılır. SaveManager yoksa (test) yazılmış sayılır.
func _save_now() -> bool:
	var save: SaveManager = get_tree().get_first_node_in_group("save_manager") as SaveManager
	return save == null or save.save_game()


func _request_save() -> void:
	var save: SaveManager = get_tree().get_first_node_in_group("save_manager") as SaveManager
	if save:
		save.request_save()


func _read_device_ledger() -> Dictionary:
	if not FileAccess.file_exists(DEVICE_LEDGER_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DEVICE_LEDGER_PATH))
	var out: Dictionary = {}
	if parsed is Dictionary and (parsed as Dictionary).get("granted") is Array:
		for key: Variant in (parsed as Dictionary)["granted"]:
			out[String(key)] = true
	return out


func _write_device_ledger() -> void:
	var file: FileAccess = FileAccess.open(DEVICE_LEDGER_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"granted": _device.keys()}))
