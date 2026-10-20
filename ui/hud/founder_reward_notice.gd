class_name FounderRewardNotice
extends Node
## ÖN KAYIT ÖDÜLÜ DUYURUSU — Play şartı: ödül verilince oyuncuya oyun içinde söylenir. Ödül çoğunlukla ilk
## açılışta, Play bağlanır bağlanmaz gelir (giriş ekranı / yükleme / Rıza Usta dersi sürerken). Pencere oyun
## SAKİNLEŞİNCE açılır: ekran yok, ders yok, kasa paneli yok. Kapanınca kamera garaja konan anahtara döner.
## Hud kurar (_setup_gem_store); ödülün kendisi FounderReward / PurchaseManager'da.

const CHECK_SEC: float = 0.5
## Oyun bu kadar sakin kalınca açılır (açılışta bir şey gelip pencerenin altında kalmasın).
const CALM_SEC: float = 1.5

var _hud: Hud
var _popup: RewardPopup
var _queue: Array[Dictionary] = []
var _calm: float = 0.0
var _timer: Timer


func _init(hud: Hud, purchases: PurchaseManager) -> void:
	name = "FounderRewardNotice"
	_hud = hud
	purchases.founder_reward_granted.connect(_on_granted)


func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = CHECK_SEC
	_timer.timeout.connect(_tick)
	add_child(_timer)


func _on_granted(summary: Dictionary) -> void:
	_queue.append(summary)
	_calm = 0.0
	_timer.start()


func _tick() -> void:
	if _queue.is_empty() or (_popup and _popup.visible):
		return
	if not _is_calm():
		_calm = 0.0
		return
	_calm += CHECK_SEC
	if _calm < CALM_SEC:
		return
	_timer.stop()
	if _popup == null:
		_popup = RewardPopup.new()
		_popup.hud = _hud
		_popup.closed.connect(_show_item)
		_hud.add_child(_popup)   # tam ekran, HUD'un en üstünde
	_popup.show_rewards(_queue.pop_front())


func _is_calm() -> bool:
	var tutorial: TutorialDirector = _hud.tutorial
	return _hud.router.top().is_empty() and not (tutorial and tutorial.is_running()) \
		and not (_hud.crate_panel and _hud.crate_panel.visible) \
		and not (_hud.restoration_result and _hud.restoration_result.visible) \
		and get_tree().root.get_node_or_null("LoadingScreen") == null


## Pencere kapandı: kamera garaja konan kurucu eşyasına gider (oyuncu ödülü yerinde görsün).
func _show_item() -> void:
	if not _queue.is_empty():
		_timer.start()
	var view: GarageDecorView = get_tree().get_first_node_in_group("garage_decor_view") as GarageDecorView
	var decor: DecorManager = get_tree().get_first_node_in_group("decor") as DecorManager
	var cam: WorldCamera = get_viewport().get_camera_3d() as WorldCamera
	if view == null or decor == null or cam == null:
		return
	for inst: Dictionary in decor.instances():
		if StringName(inst["item"]) == FounderReward.DECOR:
			var body: Node3D = view.body_of(String(inst["iid"]))
			if body:
				var center: Vector3 = body.global_position
				cam.frame_box(AABB(center - Vector3(0.25, 0.0, 0.25), Vector3(0.5, 0.35, 0.5)))
			return
