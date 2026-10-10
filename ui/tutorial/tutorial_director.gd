class_name TutorialDirector
extends Node
## EĞİTİM YÖNETMENİ — Rıza Usta'nın dört ustalık dersini OYNATIR. Durum (hangi ders bitti)
## TutorialManager'da, görünüm TutorialOverlay'dedir; burada yalnızca akış vardır.
##
## Dersler oyunda KOŞULU OLUŞUNCA başlar (oyuncuya ders listesi dayatılmaz):
##   İLK TAMİR        ilk açılışta (hoş geldin kartıyla) — müşteri → TAMİRE AL → bekle → PARA TOPLA
##   ARAÇ KOLEKSİYONU İLK KASA görevi bitince ya da garaja kasa gelince — ödül → kasa → AÇ → ARAÇLAR → MAĞAZA
##   DRAG YARIŞI      ilk rakip 🏁 balonuyla yanaşınca — davet → YARIŞ → kurallar → canlı yarış → sonuç
##   GARAJINI SÜSLE   seviye 3'te — GARAJ → DÜZENLE → eşya seç → yerleştir → BİTİR
## Ders yalnızca oyuncu boştayken açılır (açık ekran, kasa açılışı yokken) ve dersler arasında nefes
## payı bırakılır. Her ders kartında SONRA (bir süre sonra yeniden sorulur), her adımda DERSİ GEÇ var.
##
## ADIM = sözlük. Anahtarlar:
##   title, text      Rıza Usta'nın kartı (Loc.t ile çevrilmiş)
##   target           Callable → Control | Node3D | null — spot ışığının hedefi (her karede okunur)
##   button           "" değilse adım bu düğmeyle ilerler
##   done             Callable → bool: adım tamamlandı (oyundaki eylem)
##   back             Callable → bool: oyuncu geri adım attı (ör. aracı bıraktı) → önceki adım
##   fail             Callable → bool: ders sürdürülemez (rakip gitti) → ders sonraya kalır
##   skip_if          Callable → bool: girerken bakılır, doğruysa adım atlanır
##   enter            Callable: adıma girerken (kamera çerçeveleme, yarışı bekletme)
##   dim / block / hand  görünüm (varsayılan: hedef varsa üçü de açık)
##   card             &"auto" | &"top" | &"bottom" | &"center" | &"none"
##   radius, lift     dünya hedefinin yarıçapı / yüksekliği (birim)
##   pad              düğme hedefinin çevresindeki pay (px)

const CarHitboxScript: GDScript = preload("res://car_hitbox.gd")

## Yükleme ekranı kalktıktan sonra ilk ders için bekleme (sn): oyuncu önce garajı görsün.
const START_DELAY: float = 1.6
## İki ders arasında en az bu kadar boşluk (sn).
const CHAPTER_GAP: float = 10.0
## SONRA denince ders bu kadar sonra yeniden sorulur (sn).
const POSTPONE: float = 150.0
## Ders yarıda kalırsa (rakip gitti, ekran kapandı) yeniden deneme (sn).
const ABORT_RETRY: float = 40.0
const TRIGGER_INTERVAL: float = 0.5
## Ders koşulları; DECOR bu seviyede açılır.
const DECOR_LEVEL: int = 3
## Gösterim sırası: koşulu aynı anda oluşan derslerden önce gelen.
const ORDER: Array[StringName] = [TutorialManager.BASICS, TutorialManager.VEHICLES, TutorialManager.RACE,
	TutorialManager.DECOR]

var hud: Hud
var overlay: TutorialOverlay

var _manager: TutorialManager
var _repair: RepairManager
var _race: RaceManager
var _crates: CrateManager
var _delivery: CrateDelivery
var _quests: QuestManager
var _player: PlayerProgress
var _ownership: VehicleOwnership
var _decor: DecorManager
var _economy: EconomyManager
var _editor: GarageEditor
var _traffic: TrafficManager
var _reward_popup: RewardPopup

## &"idle" · &"intro" (ders kartı) · &"steps" · &"complete" (damga + ödül)
var _state: StringName = &"idle"
var _chapter: StringName = &""
var _steps: Array[Dictionary] = []
var _index: int = -1
var _flags: Dictionary = {}
var _ctx: Dictionary = {}
var _clock: float = 0.0
var _trigger_timer: float = 0.0
var _ready_at: float = -1.0
var _next_allowed: float = 0.0
var _postponed: Dictionary = {}


func _ready() -> void:
	name = "TutorialDirector"
	add_to_group("tutorial_director")
	_connect.call_deferred()   # yöneticiler kendi _ready'lerini bitirsin


func _connect() -> void:
	var tree: SceneTree = get_tree()
	_manager = tree.get_first_node_in_group("tutorial") as TutorialManager
	_repair = tree.get_first_node_in_group("repair_manager") as RepairManager
	_race = tree.get_first_node_in_group("race") as RaceManager
	_crates = tree.get_first_node_in_group("crates") as CrateManager
	_delivery = tree.get_first_node_in_group("crate_delivery") as CrateDelivery
	_quests = tree.get_first_node_in_group("quests") as QuestManager
	_player = tree.get_first_node_in_group("player_progress") as PlayerProgress
	_ownership = tree.get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	_decor = tree.get_first_node_in_group("decor") as DecorManager
	_economy = tree.get_first_node_in_group("economy") as EconomyManager
	_traffic = tree.get_first_node_in_group("traffic") as TrafficManager
	if _manager == null:
		set_process(false)   # arkadaş garajı ziyareti: eğitim yok
		return
	_manager.changed.connect(_on_manager_changed)
	overlay.action_pressed.connect(_on_action)
	overlay.skip_pressed.connect(_on_skip)
	overlay.chapter_chosen.connect(_on_chosen)
	if _repair:
		_repair.repair_started.connect(func(_c: Node3D) -> void: _flag(&"repair_started"))
		_repair.repair_collected.connect(func(_c: Node3D, _r: int, _x: int) -> void: _flag(&"repair_collected"))
	if _delivery:
		_delivery.reveal_ready.connect(func(_u: int, _r: Dictionary) -> void: _flag(&"revealed"))
		_delivery.reveal_finished.connect(func(_u: int) -> void: _flag(&"reveal_finished"))
	if _decor:
		_decor.instance_added.connect(func(_i: StringName) -> void: _flag(&"decor_placed"))
	_reward_popup = RewardPopup.new()
	_reward_popup.hud = hud
	overlay.add_child(_reward_popup)
	_reward_popup.closed.connect(_on_reward_closed)


func _process(delta: float) -> void:
	_clock += delta
	match _state:
		&"idle":
			_trigger_timer -= delta
			if _trigger_timer <= 0.0:
				_trigger_timer = TRIGGER_INTERVAL
				_try_start()
		&"steps":
			_tick_step()


## AYARLAR → NASIL OYNANIR?: çalışan ders bırakılır, dersler baştan başlar.
func restart() -> void:
	_end_chapter()
	_postponed.clear()
	_next_allowed = _clock + 1.0
	if _manager:
		_manager.restart()


func is_running() -> bool:
	return _state != &"idle"


# --- Ders başlatma ----------------------------------------------------------------------

## Arayüzü kodla süren testler (tools/run_tests.sh) eğitimi kapatır: hoş geldin kartı dokunuşlarını tutmasın.
static func disabled_by_env() -> bool:
	return OS.get_environment("CT_NO_TUTORIAL") == "1"


func _try_start() -> void:
	if _manager == null or _manager.all_done() or GarageVisit.is_visiting() or disabled_by_env():
		return
	if get_tree().root.get_node_or_null("LoadingScreen") != null:
		_ready_at = -1.0
		return
	if _ready_at < 0.0:
		_ready_at = _clock
	if _clock - _ready_at < START_DELAY or _clock < _next_allowed or not _ui_idle():
		return
	for id: StringName in ORDER:
		if _manager.is_done(id) or _clock < float(_postponed.get(id, 0.0)):
			continue
		if _can_start(id):
			_begin(id)
			return


## Oyuncu boşta mı: ekran / pano açık değil, kasa açılmıyor, satın alma plakası yok.
func _ui_idle() -> bool:
	if hud == null or hud.router == null or hud.router.top() != &"":
		return false
	if hud.crate_panel and hud.crate_panel.visible:
		return false
	if _delivery and _delivery.is_revealing():
		return false
	return not (_reward_popup and _reward_popup.visible)


func _can_start(id: StringName) -> bool:
	if id != TutorialManager.BASICS and not _manager.is_done(TutorialManager.BASICS):
		return false
	match id:
		TutorialManager.BASICS:
			return true
		TutorialManager.VEHICLES:
			return _first_crate_claimable() or _openable_crate() >= 0 \
				or (_ownership != null and _ownership.owned_count() >= 2)
		TutorialManager.RACE:
			return _race != null and _race.has_challenge()
		TutorialManager.DECOR:
			return _player != null and _player.level >= DECOR_LEVEL
	return false


func _begin(id: StringName) -> void:
	_chapter = id
	_ctx = {}
	_steps = _build_steps(id)
	_index = -1
	_state = &"intro"
	CarHitboxScript.clear_selection(get_tree())
	if id == TutorialManager.RACE and _race:
		_race.tutorial_hold = true   # ders kartı açıkken rakip gitmesin
	var editor: GarageEditor = _editor_node()
	if id == TutorialManager.DECOR and editor and not editor.tool_changed.is_connected(_on_editor_tool):
		editor.tool_changed.connect(_on_editor_tool)
	overlay.show_chapter(_intro_info(id))


func _on_chosen(choice: StringName) -> void:
	match _state:
		&"intro":
			match choice:
				&"start":
					_state = &"steps"
					_next_step()
				&"skip_all":
					_manager.skip_all()
					_end_chapter()
				_:
					_postponed[_chapter] = _clock + POSTPONE
					_end_chapter()
		&"complete":
			_show_reward()


# --- Adım makinesi ------------------------------------------------------------------------

func _next_step() -> void:
	_index += 1
	while _index < _steps.size() and _skipped(_steps[_index]):
		_index += 1
	if _index >= _steps.size():
		_complete()
		return
	_enter_step()


## Önceki (atlanmayan) adıma döner; yoksa bu adımı yeniden başlatır.
func _step_back() -> void:
	var target: int = _index - 1
	while target >= 0 and _skipped(_steps[target]):
		target -= 1
	_index = maxi(target, 0)
	_enter_step()


func _skipped(step: Dictionary) -> bool:
	return step.has("skip_if") and bool((step["skip_if"] as Callable).call())


func _enter_step() -> void:
	var step: Dictionary = _steps[_index]
	_flags.clear()
	if step.has("enter"):
		(step["enter"] as Callable).call()
	var has_target: bool = step.has("target")
	overlay.activate()
	overlay.set_mode(bool(step.get("dim", has_target or step.has("button"))), bool(step.get("block", has_target or step.has("button"))),
		bool(step.get("hand", has_target and not step.has("button"))), not step.has("button"))
	var rect: Rect2 = _resolve(step)
	overlay.set_target(rect, _last_world)
	var place: StringName = step.get("card", &"auto")
	if place == &"none":
		overlay.hide_card()
		return
	if place == &"auto":
		place = _auto_place(step, rect)
	_card_place = place
	var chip: String = "%s  ·  %d / %d" % [_chapter_title(_chapter), _index + 1, _steps.size()]
	overlay.show_card(chip, String(step.get("title", "")), String(step.get("text", "")),
		String(step.get("button", "")), _index, _steps.size(), place)


## Kart hedefin karşı yarısına: hedef üstteyse alta, alttaysa üste. Hedef yoksa ortaya (bilgi) / alta.
func _auto_place(step: Dictionary, rect: Rect2) -> StringName:
	if rect.size == Vector2.ZERO:
		return &"center" if step.has("button") else &"bottom"
	return &"bottom" if rect.get_center().y < overlay.size.y * 0.5 else &"top"


func _tick_step() -> void:
	var step: Dictionary = _steps[_index]
	var rect: Rect2 = _resolve(step)
	overlay.set_target(rect, _last_world)
	# Hedef adıma girerken henüz yoktuysa (pano açılıyor) ya da yer değiştirdiyse kart yer değiştirir
	if step.get("card", &"auto") == &"auto" and rect.size != Vector2.ZERO:
		var place: StringName = _auto_place(step, rect)
		if place != _card_place:
			_card_place = place
			overlay.place_card(place)
	# Sıra önemli: eylem tamamlandıysa (ör. TAMİRE AL aracı seçimden düşürür) geri adım sayılmaz
	if step.has("done") and bool((step["done"] as Callable).call()):
		_step_done()
		return
	if step.has("fail") and bool((step["fail"] as Callable).call()):
		_postponed[_chapter] = _clock + ABORT_RETRY
		_end_chapter()
		return
	if step.has("back") and bool((step["back"] as Callable).call()):
		_step_back()


func _step_done() -> void:
	overlay.sfx.play(&"chime")
	_next_step()


func _on_action() -> void:
	if _state == &"steps" and _index >= 0 and _index < _steps.size() and _steps[_index].has("button"):
		_step_done()


## DERSİ GEÇ: ders bitmiş sayılır (ödül yok).
func _on_skip() -> void:
	if _chapter == &"":
		return
	var id: StringName = _chapter
	_end_chapter()
	_manager.mark_done(id)


func _complete() -> void:
	_state = &"complete"
	overlay.set_mode(false, false, false)
	overlay.set_target(Rect2(), false)
	overlay.show_complete(_chapter_title(_chapter))


## Damga kartı kapandı: ders kaydedilir, ödül (ilk kez oynanıyorsa) pencereyle verilir.
func _show_reward() -> void:
	var id: StringName = _chapter
	var amount: int = int(TutorialManager.REWARD.get(id, 0)) if _manager.rewarded() else 0
	_manager.mark_done(id)
	_release_holds()
	if amount <= 0 or _economy == null:
		_end_chapter()
		return
	_economy.add_money(amount)
	# Damga kartı sönsün, pencere temiz bir ekranda açılsın
	get_tree().create_timer(0.28).timeout.connect(func() -> void:
		if _state == &"complete":
			_reward_popup.show_rewards({"money": amount, "count": 1}))


func _on_reward_closed() -> void:
	if _state == &"complete":
		_end_chapter()


## Ders bitti / bırakıldı: bekletmeler kalkar, katman söner, sıradaki ders için nefes payı.
func _end_chapter() -> void:
	_release_holds()
	_state = &"idle"
	_chapter = &""
	_steps = []
	_index = -1
	_ctx = {}
	_next_allowed = _clock + CHAPTER_GAP
	if overlay:
		overlay.deactivate()


func _release_holds() -> void:
	if _race:
		_race.tutorial_hold = false
	if hud and hud.drag_race_screen:
		hud.drag_race_screen.hold_start = false


## Durum dışarıdan değişti (bulut kaydı yüklendi, eğitim atlandı): çalışan ders artık geçersizse bırakılır.
func _on_manager_changed() -> void:
	if _chapter != &"" and _manager.is_done(_chapter) and _state != &"complete":
		_end_chapter()


func _flag(id: StringName) -> void:
	_flags[id] = true


## Zemin boyama / duvar örme aracı açıldı: eşya yerine araç seçen oyuncu da "seçti" sayılır.
func _on_editor_tool() -> void:
	_flag(&"decor_tool")


# --- Hedefler -------------------------------------------------------------------------------

## Kartın şu anki yeri (otomatik yerleşimde hedef kayınca değişir).
var _card_place: StringName = &""
## Son çözülen hedef dünyada mıydı (delik yuvarlak çizilir)?
var _last_world: bool = false


## Adımın hedefi katman koordinatlarında. Görünmeyen / geçersiz hedef = boş dikdörtgen.
func _resolve(step: Dictionary) -> Rect2:
	_last_world = false
	if not step.has("target"):
		return Rect2()
	var target: Variant = (step["target"] as Callable).call()
	_last_world = target is Node3D
	if target is Control:
		var control: Control = target
		if not is_instance_valid(control) or not control.is_visible_in_tree() or control.size == Vector2.ZERO:
			return Rect2()
		var rect: Rect2 = control.get_global_rect()
		rect.position -= overlay.get_global_rect().position
		return rect.grow(float(step.get("pad", 6.0)))
	if target is Node3D:
		var node: Node3D = target
		if not is_instance_valid(node) or not node.is_inside_tree():
			return Rect2()
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera == null:
			return Rect2()
		var center: Vector3 = node.global_position + Vector3(0.0, float(step.get("lift", 0.12)), 0.0)
		var point: Vector2 = camera.unproject_position(center)
		var screen_height: float = get_viewport().get_visible_rect().size.y
		var pixels_per_unit: float = screen_height / maxf(camera.size, 0.01) if camera.projection == Camera3D.PROJECTION_ORTHOGONAL else 120.0
		var radius: float = clampf(float(step.get("radius", 0.5)) * pixels_per_unit, 44.0, 160.0)
		return Rect2(point - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
	return Rect2()


## Dünya hedefini ekranın ortasına (kart için üst/alt pay bırakarak) yumuşakça getirir.
func _frame(node: Node3D, span: float = 2.6) -> void:
	var camera: WorldCamera = get_viewport().get_camera_3d() as WorldCamera
	if camera == null or node == null or not is_instance_valid(node):
		return
	var c: Vector3 = node.global_position
	camera.frame_box(AABB(Vector3(c.x - span * 0.5, 0.0, c.z - span * 0.5), Vector3(span, 0.5, span)), 0.14, 0.86)


## Yol kenarında bekleyen (ya da yanaşmakta olan) müşteri; bekleyen önceliklidir.
func _customer() -> TrafficVehicle:
	if _traffic == null:
		return null
	var approaching: TrafficVehicle = null
	for vehicle: TrafficVehicle in _traffic.vehicles:
		if not is_instance_valid(vehicle):
			continue
		if vehicle.is_waiting():
			return vehicle
		if vehicle.is_customer() and approaching == null:
			approaching = vehicle
	return approaching


func _first_crate_claimable() -> bool:
	return _quests != null and _quests.is_active(&"first_crate") and _quests.is_complete(&"first_crate") \
		and not _quests.is_claimed(&"first_crate")


## Garajda açılmayı bekleyen ilk kasa (yoksa -1).
func _openable_crate() -> int:
	if _crates == null:
		return -1
	for crate: Dictionary in _crates.crates():
		var uid: int = int(crate["uid"])
		if _crates.can_open(uid) and _delivery != null and _delivery.visual_of(uid) != null:
			return uid
	return -1


func _place() -> StringName:
	return hud.router.current_place() if hud and hud.router else &""


func _top() -> StringName:
	return hud.router.top() if hud and hud.router else &""


func _editor_node() -> GarageEditor:
	if _editor == null:
		_editor = get_tree().get_first_node_in_group("garage_editor") as GarageEditor
	return _editor


# --- Ders içerikleri ------------------------------------------------------------------------

func _chapter_title(id: StringName) -> String:
	match id:
		TutorialManager.BASICS:
			return Loc.t("İLK TAMİR")
		TutorialManager.RACE:
			return Loc.t("DRAG YARIŞI")
		TutorialManager.VEHICLES:
			return Loc.t("ARAÇ KOLEKSİYONU")
		TutorialManager.DECOR:
			return Loc.t("GARAJINI SÜSLE")
	return ""


func _intro_info(id: StringName) -> Dictionary:
	var number: int = mini(_manager.done_count() + 1, TutorialManager.ALL.size())
	var caption: String = Loc.t("USTALIK DERSİ %d / %d") % [number, TutorialManager.ALL.size()]
	match id:
		TutorialManager.BASICS:
			return {"logo": true, "caption": caption, "icon": ChapterCard.Icon.WRENCH,
				"title": Loc.t("HOŞ GELDİN, USTA!"),
				"subtitle": Loc.t("Ben Rıza Usta. Bu garaj artık senin: arızalı araçları tamir et, para kazan, garajını büyüt. Hadi ilk müşterini karşılayalım!"),
				"primary": Loc.t("BAŞLAYALIM"), "secondary": Loc.t("EĞİTİMİ ATLA"), "secondary_choice": &"skip_all"}
		TutorialManager.RACE:
			return {"caption": caption, "icon": ChapterCard.Icon.FLAG, "title": _chapter_title(id),
				"subtitle": Loc.t("Bir rakip kapına dayandı! Drag yarışında kazanmak için doğru anda dokunmak yeter."),
				"primary": Loc.t("BAŞLA"), "secondary": Loc.t("SONRA")}
		TutorialManager.VEHICLES:
			return {"caption": caption, "icon": ChapterCard.Icon.CAR, "title": _chapter_title(id),
				"subtitle": Loc.t("Garajını araçlarla doldurma zamanı! Araçlar teslimat kasalarından çıkar."),
				"primary": Loc.t("BAŞLA"), "secondary": Loc.t("SONRA")}
		TutorialManager.DECOR:
			return {"caption": caption, "icon": ChapterCard.Icon.BRUSH, "title": _chapter_title(id),
				"subtitle": Loc.t("Güzel bir garaj müşteriyi de, arkadaşlarını da etkiler. Garajını kendi zevkine göre döşe!"),
				"primary": Loc.t("BAŞLA"), "secondary": Loc.t("SONRA")}
	return {}


func _build_steps(id: StringName) -> Array[Dictionary]:
	match id:
		TutorialManager.BASICS:
			return _basics_steps()
		TutorialManager.RACE:
			return _race_steps()
		TutorialManager.VEHICLES:
			return _vehicle_steps()
		TutorialManager.DECOR:
			return _decor_steps()
	return []


## İLK TAMİR: müşteri gelir → araca dokun → TAMİRE AL → süre → PARA TOPLA → kazanç → görevler → garaj.
func _basics_steps() -> Array[Dictionary]:
	var car: Callable = func() -> TrafficVehicle:
		var chosen: Variant = _ctx.get("car")
		return chosen if chosen is TrafficVehicle and is_instance_valid(chosen) else null
	return [
		{"title": Loc.t("MÜŞTERİ YOLDA"),
			"text": Loc.t("Şehirde arızalanan araçlar garajının önüne yanaşır. Biraz bekle, ilk müşterin geliyor..."),
			"skip_if": func() -> bool: return _customer() != null and _customer().is_waiting(),
			"done": func() -> bool: return _customer() != null and _customer().is_waiting(),
			"dim": false, "block": false},
		{"title": Loc.t("İLK MÜŞTERİN"),
			"text": Loc.t("Üstünde anahtar balonu olan araç tamir istiyor. Araca dokun!"),
			"enter": func() -> void:
				_ctx["car"] = _customer()
				_frame(car.call()),
			"target": car, "radius": 0.5,
			"done": func() -> bool: return _repair != null and _repair.get_target() != null and _repair.get_target() == car.call(),
			"fail": func() -> bool: return car.call() == null or not (car.call() as TrafficVehicle).is_customer()},
		{"title": Loc.t("TAMİRE AL"),
			"text": Loc.t("Plakada arızayı, süresini ve kazancını görürsün. TAMİRE AL'a bas, araç tamir alanına geçsin."),
			"target": func() -> Control: return _repair_button(),
			"done": func() -> bool: return _flags.has(&"repair_started"),
			"back": func() -> bool: return _repair == null or _repair.get_target() != car.call()},
		{"title": Loc.t("TAMİR SÜRÜYOR"),
			"text": Loc.t("Araç tamir alanında! Süre dolunca üstünde para balonu çıkar. Beklerken etrafa göz atabilirsin."),
			"target": car, "radius": 0.55, "dim": false, "block": false, "hand": false,
			"done": func() -> bool: return car.call() != null and _repair.can_collect(car.call()),
			"fail": func() -> bool: return car.call() == null},
		{"title": Loc.t("PARANI TOPLA"),
			"text": Loc.t("Tamir bitti! Araca dokun ve PARA TOPLA'ya bas."),
			"target": func() -> Variant:
				if _repair.get_target() == car.call() and _repair_button() != null:
					return _repair_button()
				return car.call(),
			"enter": func() -> void: _frame(car.call()),
			"done": func() -> bool: return _flags.has(&"repair_collected"),
			"fail": func() -> bool: return car.call() == null and not _flags.has(&"repair_collected")},
		{"title": Loc.t("İLK KAZANCIN!"),
			"text": Loc.t("Para kasana girdi! Her tamir para ve XP getirir. XP çubuğu dolunca seviye atlarsın: yeni arızalar, araçlar ve eşyalar açılır."),
			"target": func() -> Control: return hud.top_left, "pad": 4.0, "hand": false,
			"button": Loc.t("İLERİ")},
		{"title": Loc.t("GÖREVLER"),
			"text": Loc.t("Ne yapacağını bilmiyorsan GÖREVLER'e bak. Görevler sana yol gösterir ve her biri ödül verir; günlük ve haftalık görevler her gün yenilenir."),
			"target": func() -> Control: return hud.quest_button,
			"button": Loc.t("İLERİ")},
		{"title": Loc.t("GARAJINI BÜYÜT"),
			"text": Loc.t("Para biriktikçe GARAJ'dan garajını genişlet, tamir hızını yükselt ve yeni tamir alanları aç. Daha büyük garaj, daha çok müşteri demek!"),
			"target": func() -> Control: return hud.garage_button,
			"button": Loc.t("ANLADIM")},
	]


## Araç plakasındaki TAMİRE AL / PARA TOPLA (plaka kapalıysa null).
func _repair_button() -> Control:
	if hud == null or not hud.car_info_panel.visible:
		return null
	for child: Node in hud.car_stats_container.get_children():
		if child is RepairPanel:
			var button: PlateButton = (child as RepairPanel).action_button()
			return button if button.is_visible_in_tree() else null
	return null


## DRAG YARIŞI: rakibe dokun → YARIŞ → kurallar (geri sayım bekler) → canlı yarış → sonuç → garaja dön.
func _race_steps() -> Array[Dictionary]:
	var rival: Callable = func() -> Node3D: return _race.challenger() if _race else null
	var race_screen: DragRaceScreen = hud.drag_race_screen
	return [
		{"title": Loc.t("RAKİP GELDİ"),
			"text": Loc.t("Üstünde damalı bayrak olan araç seni yarışa çağırıyor. Araca dokun!"),
			"enter": func() -> void: _frame(rival.call()),
			"target": rival, "radius": 0.5,
			"done": func() -> bool: return _top() == &"race_challenge",
			"fail": func() -> bool: return not _race.has_challenge() and _top() != &"race_challenge"},
		{"title": Loc.t("DAVETİ KABUL ET"),
			"text": Loc.t("Burada iki aracı ve kazanırsan alacağın ödülü görürsün. YARIŞ'a bas!"),
			"target": func() -> Control: return hud.race_challenge_screen.find_child("AcceptButton", true, false) as Control,
			"enter": func() -> void: race_screen.hold_start = true,
			"done": func() -> bool: return _place() == &"drag_race",
			"back": func() -> bool: return _top() == &"" and _race.has_challenge(),
			"fail": func() -> bool: return _top() == &"" and not _race.has_challenge()},
		{"title": Loc.t("DRAG NASIL OYNANIR?"),
			"text": Loc.t("Aracı sen sürmezsin: işin ZAMANLAMA. Yarış iki dokunuşla kazanılır: doğru anda kalkış, doğru anda vites."),
			"card": &"center", "button": Loc.t("İLERİ"),
			"fail": func() -> bool: return _place() != &"drag_race"},
		{"title": Loc.t("YEŞİLDE KALK"),
			"text": Loc.t("Geri sayım biter, ışıklar YEŞİL yanar: o an ekrana dokun! Erken dokunursan HATALI ÇIKIŞ cezası yersin, geç kalırsan rakip kaçar."),
			"target": func() -> Control: return race_screen.tutorial_anchor(&"sign"), "hand": false,
			"button": Loc.t("İLERİ"),
			"fail": func() -> bool: return _place() != &"drag_race"},
		{"title": Loc.t("YEŞİLDE VİTES AT"),
			"text": Loc.t("Kalkınca ibre yükselir. İbre YEŞİL bölgeye girince tekrar dokun: vites atarsın. Kırmızıya kaçarsa motor boğulur, hız kaybedersin. Ekranın her yeri dokunma alanıdır!"),
			"target": func() -> Control: return race_screen.tutorial_anchor(&"dial"), "hand": false,
			"button": Loc.t("HAZIRIM!"),
			"fail": func() -> bool: return _place() != &"drag_race"},
		{"target": func() -> Control: return race_screen.tutorial_anchor(&"tap"),
			"enter": func() -> void: race_screen.hold_start = false,
			"card": &"none", "dim": false, "block": false, "hand": true,
			"done": func() -> bool: return _top() == &"race_result",
			"fail": func() -> bool: return _place() != &"drag_race"},
		{"title": Loc.t("YARIŞ BİTTİ!"),
			"text": Loc.t("Kazanınca para ve XP alırsın, kaybetsen de biraz XP kazanırsın. Her araçla kişisel rekorunu kır: üstteki çubukta eski rekorun hayalet olarak koşar."),
			"target": func() -> Control: return hud.race_result_screen.tutorial_anchor(&"column"),
			"hand": false, "button": Loc.t("TAMAM"), "card": &"top",
			"skip_if": func() -> bool: return _top() != &"race_result"},
		{"title": Loc.t("GARAJA DÖN"),
			"text": Loc.t("Garajına dön. Rakipler yarış şeridinden sık sık gelir; hangi araçla yarışacağını ARAÇLAR'dan seçersin."),
			"target": func() -> Control: return hud.race_result_screen.find_child("ExitButton", true, false) as Control,
			"skip_if": func() -> bool: return _top() == &"",
			"done": func() -> bool: return _top() == &""},
	]


## ARAÇ KOLEKSİYONU: (İLK KASA ödülünü al) → kasa iner → dokun → AÇ → sonuç → ARAÇLAR → MAĞAZA.
func _vehicle_steps() -> Array[Dictionary]:
	var crate_node: Callable = func() -> Node3D:
		var uid: int = _openable_crate()
		if uid < 0:
			uid = int(_ctx.get("crate", -1))
		else:
			_ctx["crate"] = uid
		return _delivery.visual_of(uid) if _delivery and uid >= 0 else null
	var no_crate: Callable = func() -> bool:
		return not _first_crate_claimable() and _openable_crate() < 0 and not _ctx.has("crate_flow")
	return [
		{"title": Loc.t("GÖREV TAMAMLANDI!"),
			"text": Loc.t("Seviye 2 oldun ve İLK KASA görevi bitti. Ödülünü almak için GÖREVLER'e dokun."),
			"skip_if": func() -> bool: return not _first_crate_claimable(),
			"enter": func() -> void: _ctx["crate_flow"] = true,
			"target": func() -> Control: return hud.quest_button,
			"done": func() -> bool: return _top() == &"quests"},
		{"title": Loc.t("ÖDÜLÜ AL"),
			"text": Loc.t("ÖDÜLÜ AL'a bas. Bu görevin ödülü bir ARAÇ KASASI!"),
			"skip_if": func() -> bool: return not _first_crate_claimable(),
			"target": func() -> Control: return hud.quest_screen.find_child("Claim_first_crate", true, false) as Control,
			"done": func() -> bool: return _quests.is_claimed(&"first_crate"),
			"back": func() -> bool: return _top() != &"quests" and _first_crate_claimable()},
		{"title": Loc.t("KASA YOLDA"),
			"text": Loc.t("Kasan garajının teslimat alanına iniyor..."),
			"skip_if": func() -> bool: return _openable_crate() >= 0 or not _ctx.has("crate_flow"),
			"dim": false, "block": false,
			"done": func() -> bool: return _openable_crate() >= 0},
		{"title": Loc.t("KASAYA DOKUN"),
			"text": Loc.t("Garajına bir araç teslimat kasası geldi. İçinde ne var? Kasaya dokun!"),
			"skip_if": func() -> bool: return _openable_crate() < 0,
			"enter": func() -> void: _ctx["crate_flow"] = true,
			"target": crate_node, "radius": 0.6, "lift": 0.2,
			"done": func() -> bool: return hud.crate_panel.visible and hud.crate_panel.mode() == &"prompt"},
		{"title": Loc.t("KASAYI AÇ"),
			"text": Loc.t("AÇ'a bas! Kasalar ŞEHİR, AİLE, SPOR ve PRESTİJ diye ayrılır; nadir araçlar daha değerlidir."),
			"skip_if": no_crate,
			"target": func() -> Control: return hud.crate_panel.find_child("CrateAction", true, false) as Control,
			"done": func() -> bool: return _flags.has(&"revealed") or hud.crate_panel.mode() == &"result",
			"back": func() -> bool: return not hud.crate_panel.visible and not (_delivery and _delivery.is_revealing())},
		{"title": Loc.t("YENİ ARACIN!"),
			"text": Loc.t("Araç artık senin! Aynı araç bir daha çıkarsa yıldız ve gem kazanırsın. Devam etmek için plakadaki düğmeye bas."),
			"skip_if": no_crate,
			"target": func() -> Control:
				return hud.crate_panel.find_child("CrateAction", true, false) as Control if hud.crate_panel.mode() == &"result" else null,
			"dim": false, "block": false,
			"done": func() -> bool: return _flags.has(&"reveal_finished") or (not hud.crate_panel.visible and not _delivery.is_revealing())},
		{"title": Loc.t("ARAÇLARIN"),
			"text": Loc.t("Bütün araçların ARAÇLAR'da durur. Hadi bir bak!"),
			"target": func() -> Control: return hud.cars_button,
			"done": func() -> bool: return _place() == &"garage",
			"skip_if": func() -> bool: return _ownership == null or _ownership.owned_count() < 2},
		{"title": Loc.t("YARIŞ ARACI"),
			"text": Loc.t("Araçlarını buradan incelersin. Beğendiğin aracı seçip YARIŞ ARACI YAP dersen drag yarışlarına o çıkar."),
			"target": func() -> Control: return hud.garage_screen.find_child("RacePickButton", true, false) as Control,
			"hand": false, "button": Loc.t("İLERİ"),
			"skip_if": func() -> bool: return _place() != &"garage"},
		{"title": Loc.t("YENİ ARAÇLAR"),
			"text": Loc.t("Yeni kasalar MAĞAZA'da: kasalar GEM ile alınır. Gem; seviye atlayınca, görevlerden ve günlük girişten gelir."),
			"enter": func() -> void:
				if hud.router.top() != &"":
					hud.router.close_all(),
			"target": func() -> Control: return hud.shop_button,
			"button": Loc.t("ANLADIM")},
	]


## GARAJINI SÜSLE: GARAJ → DÜZENLE → eşya seç → yerleştir → değer/rütbe → BİTİR.
func _decor_steps() -> Array[Dictionary]:
	var edit_screen: GarageEditScreen = hud.garage_edit_screen
	var editing: Callable = func() -> bool: return _place() == &"garage_edit"
	var placing: Callable = func() -> bool: return _editor_node() != null and _editor_node().is_placing()
	return [
		{"title": Loc.t("GARAJ MENÜSÜ"),
			"text": Loc.t("Garajınla ilgili her şey GARAJ'da. Dokun!"),
			"target": func() -> Control: return hud.garage_button,
			"skip_if": func() -> bool: return hud.garage_panel.visible,
			"done": func() -> bool: return hud.garage_panel.visible},
		{"title": Loc.t("DÜZENLE"),
			"text": Loc.t("Buradan garajı genişletir, tamir hızını yükseltir ve yeni tamir alanı açarsın. Şimdi DÜZENLE'ye bas!"),
			"target": func() -> Control: return hud.edit_button,
			"done": editing,
			"back": func() -> bool: return not hud.garage_panel.visible and not editing.call()},
		{"title": Loc.t("BİR EŞYA SEÇ"),
			"text": Loc.t("Alttan bir kategori ve eşya seç. Depondaki eşyalar bedava; yeni eşyayı almak için kartına iki kez dokun."),
			"target": func() -> Control: return edit_screen.tutorial_anchor(&"bottom"), "pad": 2.0, "hand": false,
			"done": func() -> bool: return placing.call() or _flags.has(&"decor_placed") or _flags.has(&"decor_tool"),
			"fail": func() -> bool: return not editing.call()},
		{"title": Loc.t("YERLEŞTİR"),
			"text": Loc.t("Eşyayı parmağınla sürükleyip istediğin yere götür. Oklarla döndür, YERLEŞTİR ile onayla."),
			"target": func() -> Control: return edit_screen.tutorial_anchor(&"place"),
			"dim": false, "block": false, "card": &"top",
			"skip_if": func() -> bool: return _flags.has(&"decor_placed") or not placing.call(),
			"done": func() -> bool: return _flags.has(&"decor_placed"),
			"back": func() -> bool: return not placing.call() and not _flags.has(&"decor_placed"),
			"fail": func() -> bool: return not editing.call()},
		{"title": Loc.t("HARİKA OLDU!"),
			"text": Loc.t("Dekorasyon GARAJ DEĞERİ'ni artırır; rütben yükseldikçe yeni eşyalar açılır. Zemini boyayabilir, iç duvar örebilirsin. Arkadaşların da garajını ziyaret edebilir!"),
			"target": func() -> Control: return edit_screen.tutorial_anchor(&"tabs"), "hand": false,
			"button": Loc.t("İLERİ"),
			"fail": func() -> bool: return not editing.call()},
		{"title": Loc.t("BİTİR"),
			"text": Loc.t("İşin bitince BİTİR'e bas. Garajını istediğin zaman yeniden düzenleyebilirsin."),
			"target": func() -> Control: return edit_screen.tutorial_anchor(&"done"),
			"done": func() -> bool: return not editing.call()},
	]
