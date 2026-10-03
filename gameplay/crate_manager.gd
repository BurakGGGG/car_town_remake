class_name CrateManager
extends Node
## ARAÇ TESLİMAT KASALARI — satın alma, sonuç, durum ve kalıcılık. Görsel YOKTUR: dünyadaki büyük
## kasayı world/crate_delivery.gd kurar ve açılış sahnesini oynatır; bu node yalnızca durumu tutar.
## "crates" grubundan bulunur (autoload yok — GarageSystem kodla kurar, sahne dosyası değişmez).
##
## AKIŞ (docs/vehicle_crate_design_v2.md):
##   Showroom → buy() → gem düşer + SONUÇ HEMEN ÇEKİLİR + kasa listeye girer → AYNI KAREDE diske
##   yazılır → CrateDelivery boş teslimat noktası bulur (DELIVERED → WAITING_TO_OPEN) → oyuncu
##   kasaya dokunur, AÇ → open(): araç koleksiyona / kopya yıldızına yazılır, REVEALED kaydedilir →
##   açılış sahnesi biter → claim(): kasa listeden çıkar (CLAIMED).
##
## GÜVENLİK:
##   * Sonuç satın alma anında belirlenir ve kasayla birlikte kaydedilir. Uygulamayı kapatıp açmak,
##     kaydı yüklemek ya da buluttan geri yüklemek sonucu DEĞİŞTİRMEZ (sonuç kasanın verisidir).
##   * Gem düşümü, kasa kaydı ve dosya yazımı aynı çağrıdadır: yazımdan önce uygulama kapanırsa
##     diskte ikisi de yoktur (gem de gitmez, kasa da gelmez); yazımdan sonra ikisi birdendir.
##   * Ödül open() içinde BİR KEZ verilir ve durum REVEALED olarak hemen kaydedilir. Açılış sahnesi
##     sırasında uygulama kapanırsa yüklemede REVEALED kasa ödül verilmeden kapatılır (çift ödül yok).
##   * Olasılık kasanın kayıtlı ağırlıklarından bağımsız çekilir; sahiplik / keşif oranı değiştirmez.

signal crate_added(uid: int)
signal crate_state_changed(uid: int, state: int)
## Kasa açıldı ve ödül verildi. result: bkz. open().
signal crate_opened(uid: int, result: Dictionary)
signal crate_claimed(uid: int)
signal crates_changed
## Satın alma olmadı (UI uyarısı). reason: "level" / "gems" / "unknown".
signal purchase_failed(crate_id: StringName, reason: String)

enum State { PURCHASED, DELIVERED, WAITING_TO_OPEN, OPENING, REVEALED, CLAIMED }

## Kopya hurdası (gem) — nadirliğe göre.
const DUP_SCRAP: Dictionary = {&"common": 2, &"rare": 5, &"epic": 12, &"legendary": 30}
## İlk keşif ödülü (gem) — nadirliğe göre.
const DISCOVERY_GEMS: Dictionary = {&"common": 3, &"rare": 8, &"epic": 20, &"legendary": 40}
## Koleksiyon kilometre taşları: keşfedilen araç sayısı → gem (Şahin dahil, 16'da).
const COLLECTION_MILESTONES: Dictionary = {5: 15, 10: 30, 14: 50, 16: 100}
## Aynı anda bekleyebilecek kasa sayısı (teslimat noktası sayısından bağımsız bir üst sınır).
const MAX_PENDING: int = 6

var _crates: Array[Dictionary] = []   # {uid, crate, vehicle, state, source, pos (Vector2 / null), yaw, result}
var _next_uid: int = 1
var _milestones: Array[int] = []      # ödenmiş koleksiyon kilometre taşları
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("crates")
	_rng.randomize()


# --- Sorgu -------------------------------------------------------------------------

## Satın alınabilir mi? "" = evet; değilse sebep ("level", "gems", "full", "unknown").
func buy_block_reason(crate_id: StringName) -> String:
	if not CrateCatalog.exists(crate_id):
		return "unknown"
	var progress: PlayerProgress = _progress()
	if progress and progress.level < CrateCatalog.min_level(crate_id):
		return "level"
	# Garajda yer bekleyen ("yolda") kasa varken yenisi satılmaz: aksi halde oyuncu görmediği kasalara
	# gem harcıyordu (QA: seviye 1 garaja 3 kasa sığıyor, 6 kasa alınabiliyordu).
	if pending_count() >= MAX_PENDING or not undelivered().is_empty():
		return "full"
	if progress and not progress.can_afford_gems(CrateCatalog.price(crate_id)):
		return "gems"
	return ""


func can_buy(crate_id: StringName) -> bool:
	return buy_block_reason(crate_id) == ""


## Açılmamış kasalar (sıralı kopyalar). REVEALED kasa da açılış sahnesi bitene kadar listededir.
func crates() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Dictionary in _crates:
		out.append(c.duplicate())
	return out


func pending_count() -> int:
	var n: int = 0
	for c: Dictionary in _crates:
		if int(c["state"]) < State.REVEALED:
			n += 1
	return n


func get_crate(uid: int) -> Dictionary:
	var c: Dictionary = _find(uid)
	return c.duplicate() if not c.is_empty() else {}


func state_of(uid: int) -> int:
	var c: Dictionary = _find(uid)
	return int(c["state"]) if not c.is_empty() else State.CLAIMED


## Teslimat noktası bekleyen kasalar (PURCHASED), sırayla.
func undelivered() -> Array[int]:
	var out: Array[int] = []
	for c: Dictionary in _crates:
		if int(c["state"]) == State.PURCHASED:
			out.append(int(c["uid"]))
	return out


# --- Satın alma --------------------------------------------------------------------

## KASA SATIN AL: gem düş → sonucu çek → listeye ekle → diske yaz. Başarılıysa kasanın uid'i, değilse 0.
func buy(crate_id: StringName) -> int:
	var reason: String = buy_block_reason(crate_id)
	if reason != "":
		purchase_failed.emit(crate_id, reason)
		return 0
	var progress: PlayerProgress = _progress()
	if progress and not progress.spend_gems(CrateCatalog.price(crate_id)):
		purchase_failed.emit(crate_id, "gems")
		return 0
	return _add(crate_id, "gems")


## Ücretsiz kasa (görev ödülü). Seviye ve gem aranmaz; sonuç yine hemen çekilip kaydedilir.
func grant_free(crate_id: StringName, source: String) -> int:
	if not CrateCatalog.exists(crate_id):
		return 0
	return _add(crate_id, source)


func _add(crate_id: StringName, source: String) -> int:
	var vehicle: StringName = CrateCatalog.roll(crate_id, _rng)
	if vehicle == &"":
		push_error("CrateManager: '%s' havuzu boş" % crate_id)
		return 0
	var uid: int = _next_uid
	_next_uid += 1
	_crates.append({"uid": uid, "crate": crate_id, "vehicle": vehicle, "state": State.PURCHASED,
		"source": source, "pos": null, "yaw": 0.0, "result": {}})
	_save_now()
	crate_added.emit(uid)
	crates_changed.emit()
	return uid


# --- Teslimat (CrateDelivery çağırır) ----------------------------------------------

## Kasa dünyada bir noktaya kondu. Konum kaydedilir: yeniden açılışta kasa AYNI yerde durur.
func mark_delivered(uid: int, pos: Vector2, yaw: float) -> void:
	var c: Dictionary = _find(uid)
	if c.is_empty() or int(c["state"]) != State.PURCHASED:
		return
	c["pos"] = pos
	c["yaw"] = yaw
	_set_state(c, State.DELIVERED)
	_request_save()


## Geliş animasyonu bitti: oyuncu açabilir.
func mark_waiting(uid: int) -> void:
	var c: Dictionary = _find(uid)
	if c.is_empty() or int(c["state"]) != State.DELIVERED:
		return
	_set_state(c, State.WAITING_TO_OPEN)
	_request_save()


## Açılabilir mi (dünyada duruyor ve henüz açılmadı)?
func can_open(uid: int) -> bool:
	var s: int = state_of(uid)
	return s == State.DELIVERED or s == State.WAITING_TO_OPEN


# --- Açılış ------------------------------------------------------------------------

## KASAYI AÇ: kayıtlı sonuç koleksiyona yazılır (bir kez) ve REVEALED hemen kaydedilir.
## Dönen sözlük: {uid, crate, vehicle, rarity, duplicate, reacquired, discovered, stars,
## scrap_gems, discovery_gems, milestone_gems, gems}. Açılamıyorsa boş sözlük.
func open(uid: int) -> Dictionary:
	var c: Dictionary = _find(uid)
	if c.is_empty() or not can_open(uid):
		return {}
	_set_state(c, State.OPENING)
	var vehicle: StringName = c["vehicle"]
	var rarity: StringName = CrateCatalog.rarity_of(vehicle)
	var ownership: VehicleOwnership = _ownership()
	var result: Dictionary = {"uid": uid, "crate": c["crate"], "vehicle": vehicle, "rarity": rarity,
		"duplicate": false, "reacquired": false, "discovered": false, "stars": 0,
		"scrap_gems": 0, "discovery_gems": 0, "milestone_gems": 0, "gems": 0}
	if ownership:
		if ownership.is_owned(vehicle):
			result["duplicate"] = true
			result["stars"] = ownership.add_duplicate(vehicle)
			result["scrap_gems"] = int(DUP_SCRAP.get(rarity, 0))
		else:
			var known: bool = ownership.is_discovered(vehicle)
			ownership.add_vehicle(vehicle)
			result["reacquired"] = known
			result["discovered"] = not known
			result["stars"] = ownership.stars(vehicle)
			if not known:
				result["discovery_gems"] = int(DISCOVERY_GEMS.get(rarity, 0))
				result["milestone_gems"] = _pay_milestones(ownership.discovered_count())
	result["gems"] = int(result["scrap_gems"]) + int(result["discovery_gems"]) + int(result["milestone_gems"])
	var progress: PlayerProgress = _progress()
	if progress and int(result["gems"]) > 0:
		progress.add_gems(int(result["gems"]))
	c["result"] = result
	_set_state(c, State.REVEALED)
	_save_now()
	crate_opened.emit(uid, result)
	return result


## Açılış sahnesi bitti: kasa dünyadan ve listeden kalkar.
func claim(uid: int) -> void:
	var c: Dictionary = _find(uid)
	if c.is_empty() or int(c["state"]) != State.REVEALED:
		return
	_crates.erase(c)
	_request_save()
	crate_state_changed.emit(uid, State.CLAIMED)
	crate_claimed.emit(uid)
	crates_changed.emit()


## Kasa sisteminden ÖNCEKİ kayıt (v9-): mevcut koleksiyonun geçtiği kilometre taşları ödenmiş sayılır,
## gem verilmez (eski ilerlemeye geriye dönük ödül yok). SaveManager göçte çağırır.
func mark_passed_milestones(count: int) -> void:
	for threshold: int in COLLECTION_MILESTONES:
		if count >= threshold and not _milestones.has(threshold):
			_milestones.append(threshold)


func _pay_milestones(count: int) -> int:
	var total: int = 0
	for threshold: int in COLLECTION_MILESTONES:
		if count >= threshold and not _milestones.has(threshold):
			_milestones.append(threshold)
			total += int(COLLECTION_MILESTONES[threshold])
	return total


# --- Kayıt -------------------------------------------------------------------------

## {"next_uid", "items": [{uid, crate, vehicle, state, source, pos, yaw}], "milestones": [..]}
func state() -> Dictionary:
	var items: Array = []
	for c: Dictionary in _crates:
		var pos: Variant = c["pos"]
		items.append({"uid": int(c["uid"]), "crate": String(c["crate"]), "vehicle": String(c["vehicle"]),
			"state": int(c["state"]), "source": String(c["source"]),
			"pos": [pos.x, pos.y] if pos is Vector2 else null, "yaw": float(c["yaw"])})
	var paid: Array = []
	for m: int in _milestones:
		paid.append(m)
	return {"next_uid": _next_uid, "items": items, "milestones": paid}


## Kayıttan. Geçersiz kasa / araç atlanır. REVEALED kasalar (ödülü verilmiş, sahnesi yarım kalmış)
## ödül verilmeden kapatılır. OPENING diske hiç yazılmaz; gelirse açılmamış sayılır.
func load_state(data: Dictionary) -> void:
	_crates.clear()
	_milestones.clear()
	_next_uid = maxi(SaveSafe.i(data.get("next_uid", 1)), 1)
	var items: Variant = data.get("items", [])
	if items is Array:
		for raw: Variant in items:
			if not (raw is Dictionary):
				continue
			var d: Dictionary = raw
			var crate_id: StringName = StringName(SaveSafe.s(d.get("crate", "")))
			var vehicle: StringName = StringName(SaveSafe.s(d.get("vehicle", "")))
			var uid: int = SaveSafe.i(d.get("uid", 0))
			if not CrateCatalog.exists(crate_id) or CarCatalog.get_entry(vehicle).is_empty() or uid <= 0 \
					or not _find(uid).is_empty():
				push_warning("CrateManager: kayıttaki kasa atlandı: %s" % d)
				continue
			var st: int = clampi(SaveSafe.i(d.get("state", State.PURCHASED)), State.PURCHASED, State.CLAIMED)
			if st >= State.REVEALED:
				continue
			if st == State.OPENING:
				st = State.WAITING_TO_OPEN
			var pos: Variant = null
			var raw_pos: Variant = d.get("pos", null)
			if raw_pos is Array and (raw_pos as Array).size() == 2:
				pos = Vector2(SaveSafe.f(raw_pos[0]), SaveSafe.f(raw_pos[1]))
			if pos == null and st != State.PURCHASED:
				st = State.PURCHASED   # konumsuz teslim edilmiş kasa: yeniden yer bulunur
			_crates.append({"uid": uid, "crate": crate_id, "vehicle": vehicle, "state": st,
				"source": SaveSafe.s(d.get("source", "")), "pos": pos, "yaw": SaveSafe.f(d.get("yaw", 0.0)), "result": {}})
			_next_uid = maxi(_next_uid, uid + 1)
	var paid: Variant = data.get("milestones", [])
	if paid is Array:
		for raw: Variant in paid:
			if COLLECTION_MILESTONES.has(SaveSafe.i(raw)) and not _milestones.has(SaveSafe.i(raw)):
				_milestones.append(SaveSafe.i(raw))
	crates_changed.emit()


func reset() -> void:
	_crates.clear()
	_milestones.clear()
	_next_uid = 1
	crates_changed.emit()


## Test / hata ayıklama: tekrarlanabilir çekiliş.
func set_rng_seed(value: int) -> void:
	_rng.seed = value


# --- İç ----------------------------------------------------------------------------

func _find(uid: int) -> Dictionary:
	for c: Dictionary in _crates:
		if int(c["uid"]) == uid:
			return c
	return {}


func _set_state(c: Dictionary, st: int) -> void:
	c["state"] = st
	crate_state_changed.emit(int(c["uid"]), st)
	crates_changed.emit()


func _progress() -> PlayerProgress:
	return get_tree().get_first_node_in_group("player_progress") as PlayerProgress


func _ownership() -> VehicleOwnership:
	return get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership


## Satın alma ve açılış anında debounce BEKLENMEZ: gem, kasa ve sonuç tek yazımda diske gider.
func _save_now() -> void:
	var save: Node = get_tree().get_first_node_in_group("save_manager")
	if save and save.has_method(&"save_game"):
		save.call(&"save_game")


func _request_save() -> void:
	var save: Node = get_tree().get_first_node_in_group("save_manager")
	if save and save.has_method(&"request_save"):
		save.request_save()
