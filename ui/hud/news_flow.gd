class_name NewsFlow
extends Node
## OTO MANŞET AKIŞI (2026-10-17): gazetenin NE ZAMAN açılacağı ve kapanınca olanlar. Açılışta ve arka plandan LONG_AWAY'den
## uzun dönüşte (OfflineEarnings.away_resolved) haber TOPLAMA başlar: arkadaş verisi yüklenene dek (en çok SOCIAL_WAIT sn)
## beklenir, oyuncu boşta kalınca (açık pano, ders, kasa açılışı, restorasyon töreni, yükleme ekranı, bulut kayıt seçimi
## yok; IDLE sn) haberler birleştirilir ve gazete UiRouter MODAL "news" ile açılır. Haber yoksa açılmaz.
## Kaynaklar: ustanın kazancı + biten yarım işler (OfflineEarnings), arkadaşlar (SocialManager.news_items: yarış, hediye,
## yeni arkadaş, istek, parça isteği), oyun (NewsSources: hurda yığını, modifiye, görevler).
## Toplama sürerken arkadaş hediyesi / yarış haberi küçük bildirim olarak çıkmaz (gazeteye girer; kullanıcı kararı: oyun
## açıkken gelenler bildirim, girişte toplu gazete).
## TAMAM'da OfflineEarnings.collect() parayı verir, paralar kazanç fotoğrafından sayaca uçar (CoinFlight), arkadaş tabanı
## ilerler. Kullanıcı kararı: Rıza Usta pasif geliri iki kez anlatır — ilk kazançlı gazeteden sonra ve kasa ilk kez 8 saati
## doldurunca. Hud kurar.

const IDLE: float = 1.0
const POLL: float = 0.25
## Arkadaş listesi / haberleri yüklenmeden gazete en çok bu kadar bekler (boşta geçen süre; bulut senkronu sayılmaz).
const SOCIAL_WAIT: float = 6.0
## Paralar sayaca vardıktan sonra Rıza Usta konuşur.
const TIP_DELAY: float = 1.1

var hud: Hud
var screen: NewsScreen

var _away: OfflineEarnings
var _social: SocialManager
var _cloud: CloudSaveManager
var _sfx: RewardSfx
var _timer: Timer
var _idle: float = 0.0
var _waited: float = 0.0
var _gathering: bool = false


func _ready() -> void:
	name = "NewsFlow"
	_sfx = RewardSfx.new()
	add_child(_sfx)
	_timer = Timer.new()
	_timer.wait_time = POLL
	_timer.timeout.connect(_tick)
	add_child(_timer)
	_connect.call_deferred()


func _connect() -> void:
	_away = get_tree().get_first_node_in_group("offline_earnings") as OfflineEarnings
	_social = get_tree().get_first_node_in_group("social") as SocialManager
	_cloud = get_tree().get_first_node_in_group("cloud_save") as CloudSaveManager
	screen.closed.connect(_on_closed)
	if _away == null:
		return
	_away.away_resolved.connect(func(cold: bool, seconds: int) -> void:
		if cold or seconds >= OfflineEarnings.LONG_AWAY:
			gather(not cold))
	gather(false)   # açılış: yokluk henüz işlenmediyse _tick bekler


## Haber toplamayı başlatır (`refresh`: arka plandan dönüş — arkadaş listesi yeniden okunur).
func gather(refresh: bool) -> void:
	if GarageVisit.is_visiting():
		return
	_gathering = true
	_idle = 0.0
	_waited = 0.0
	if _social:
		_social.quiet = true
		if refresh and _social.is_ready():
			_social.refresh(true)
	if _timer.is_stopped():
		_timer.start()


## Toplama sürüyor: arkadaş hediyesi / yarış haberi bildirimi gösterilmez (HUD bakar).
func is_gathering() -> bool:
	return _gathering


func _tick() -> void:
	if screen.visible:
		return
	if _away == null or not _away.is_resolved():
		return
	if _busy():
		_idle = 0.0
		return
	_waited += POLL
	if not _social_ready() and _waited < SOCIAL_WAIT:
		return
	_idle += POLL
	if _idle < IDLE:
		return
	_timer.stop()
	if not present():
		_finish()


## Toplanan haberlerle gazeteyi şimdi açar (haber yoksa false).
func present() -> bool:
	if _away == null or screen.visible:
		return false
	var items: Array[Dictionary] = _away.news_items()
	var since: int = _away.window_from if _away.window_from > 0 else _away.last_seen
	if _social:
		items.append_array(_social.news_items(since))
	items.append_array(NewsSources.local(get_tree(), _away.window_from, _away.window_to))
	if items.is_empty() or not screen.prepare(items, _away.issue + 1):
		return false
	_away.next_issue()
	hud.router.open(&"news")
	return true


func _finish() -> void:
	_gathering = false
	if _social:
		_social.quiet = false


## Arkadaş verisi hazır mı (misafir / eklentisiz / profilsiz oyuncuda beklenecek bir şey yok).
func _social_ready() -> bool:
	if _social == null:
		return true
	match _social.get_state():
		SocialManager.State.READY:
			return _social.has_loaded() and not _social.is_busy()
		SocialManager.State.LOADING:
			return false
	return true


func _busy() -> bool:
	if hud.router.top() != &"" or GarageVisit.is_visiting():
		return true
	if (hud.tutorial and hud.tutorial.is_running()) or (hud.crate_panel and hud.crate_panel.visible) \
			or (hud.restoration_result and hud.restoration_result.visible):
		return true
	if get_tree().root.get_node_or_null("LoadingScreen") != null:
		return true
	# Bulut kaydı okunurken / oyuncu kayıt seçerken gazete açılmaz: seçimden sonra sahne başka kayıtla yeniden kurulabilir
	return _cloud != null and _cloud.get_state() in [CloudSaveManager.State.SIGNING_IN, CloudSaveManager.State.SYNCING,
		CloudSaveManager.State.CONFLICT, CloudSaveManager.State.DELETING]


## Gazete kapandı (TAMAM / GERİ): gösterilen kazanç verilir ve sayaca uçar, arkadaş tabanı ilerler, sonra (gerekirse)
## Rıza Usta konuşur.
func _on_closed() -> void:
	if _away == null:
		return
	var money: int = _away.shown_money()
	if money > 0:
		hud.hold_reward(money, 0)   # para hesaba şimdi girer, sayaç paralar varana dek eski değeri gösterir
	var result: Dictionary = _away.collect()
	_away.clear_window()
	if _social:
		_social.news_shown()
	_finish()
	if result.is_empty():
		return
	var from: Vector2 = screen.money_origin()
	await get_tree().process_frame   # pano kapandı: sol üst HUD (sayaç) yeniden görünsün
	if money > 0:
		CoinFlight.fly(hud, HudIcon.Kind.COIN, from, hud.coin_label, CoinFlight.coin_count(money),
			func() -> void: hud.land_reward(money, 0), _sfx.coin)
	await get_tree().create_timer(TIP_DELAY).timeout
	await _tips(result)


## Rıza Usta'nın tek seferlik açıklamaları (ders oynuyorsa sonraki gazeteye kalır).
func _tips(result: Dictionary) -> void:
	var director: TutorialDirector = hud.tutorial
	if director == null:
		return
	if bool(result.get("bank", false)) and not _away.told_first:
		if director.say("", Loc.t("DÜKKAN BANA EMANET"),
				Loc.t("Sen yokken dükkânı ben çeviririm. Ama yalnızım, senin kadar hızlı değilim!")):
			_away.told_first = true
			_away.save_soon()
			await director.said
	if bool(result.get("full", false)) and not _away.told_full:
		if director.say("", Loc.t("KEPENGİ İNDİRDİM"),
				Loc.t("8 saat çalıştım, kepengi indirdim. Sık uğra ki dükkân durmasın!")):
			_away.told_full = true
			_away.save_soon()
			await director.said
