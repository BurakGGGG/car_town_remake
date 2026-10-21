class_name RaceManager
extends Node
## DRAG YARIŞI AKIŞI — rakibin yoldan gelmesi, davet, yarış sonucu ve ödül.
##
## Car Town zinciri: GARAJ → YARIŞ ŞERİDİNDEN rakip gelir → durup 🏁 balonu açar → davet plakası →
## YARIŞ → sonuç → garaja dönüş. Oyuncu normal trafikte araç SÜRMEZ; yarış ayrı bir moddur.
##
## YARIŞ ŞERİDİ: şehir trafiğinin bir şeridi yarışa ayrıldı (`TrafficManager.race_lane_spawn`).
## O şeritte normal NPC doğmaz; yalnızca buradan çağrılan davet araçları girer. Rakip şeridin
## başında doğar, duruş noktasına kadar normal sürer, orada durup balonunu açar. Oyuncu kabul
## etmezse süre dolunca DÜMDÜZ devam edip şeritten çıkar ve bir süre sonra arkadan yenisi gelir.
##
## MEVCUT SİSTEMLERİ YENİDEN KULLANIR, KOPYALAMAZ:
##   - rakip, TrafficManager'ın zaten yoldaki araçlarından seçilir (RepairManager'ın müşteri seçme
##     yöntemiyle aynı mantık: uygun, sağlam, meşgul olmayan bir NPC),
##   - araç, tamir müşterisiyle aynı "yol kenarına yanaş" koduyla durur (TrafficVehicle._pull_over),
##   - balon ve tıklama mevcut CarBubble + CarHitbox yoludur,
##   - ekranlar UiRouter'dan açılır (kendi ESC/navigation mantığı yok).
##
## RÖVANŞ: kaybedilen yarıştan sonra oyuncu İSTERSE aynı rakiple (aynı model, yeni gün formu) yeniden yarışır —
## sonuç panosunda RÖVANŞ plakası. Rakip panoda beklerken şeritte durur, GARAJA DÖN'de yola döner. Rakip başına
## TEK rövanş (MAX_REMATCHES; kullanıcı kararı): rövanşı da kaybedersen plaka çıkmaz, rakip gider. Ücret yok;
## teselli XP'si yalnızca İLK kayıpta, rövanşı kazanmak normal kazanma ödülünü verir.
##
## KAÇAN KAYBEDEN (nadir: kazanılan yarışların ~7'de 1'i, flee_chance): oyuncu kazanınca rakip, oyuncu dünyaya
## dönene kadar şeritte bekler (yarış ekranı açıkken dünya çizilmez, kaçış görünmezdi); GARAJA DÖN'de kırmızıya
## bakmadan, trafiği birbirine katarak kaçar (TrafficVehicle.flee). Diğerlerinde kaybeden normal trafiğe döner.
##
## ARKADAŞ RAKİP (2026-10-16, orijinal Car Town gibi): rakiplerin friend_chance'ı (%70) bir ARKADAŞIN aracıyla gelir —
## balonda arkadaşın fotoğrafı, davet / sonuç panosunda adı. Önce GERÇEK arkadaşların performansa uyan araçlarına
## bakılır (arkadaşın modifiyeli süresiyle, rival_window); uyan yoksa Emre / Elif gelir (yarışta her araca
## sahipler; hangisinin geleceği aracın karakterine göre: FeaturedFriends.owner_for_car). Kalan %30 isimsiz NPC.
## Arkadaşın aracı onun BOYASIYLA ve PERFORMANS MODİFİYELERİYLE gelir (rival_build); Emre / Elif fabrika
## renginde ve modifiyesiz. İlk yarışta (eğitim) gerçek arkadaş gelmez: yarış kazanılabilir kalsın.
##
## ARKADAŞ YARIŞI SONUÇLARI (aşama 3, 2026-10-17): gerçek arkadaşın aracıyla yarış bitince friend_race_finished →
## SocialManager arkadaşa HABER yazar (kazansan da kaybetsen de). Arkadaşın senin aracını yendiğini haber alınca
## İNTİKAM AL: start_revenge pisti yoldan gelen araç olmadan DOĞRUDAN açar (onun o aracı, boyası, modifiyeleri; rövanş
## yok). SKOR iki yönlü: kendi yönüm (ben onun aracına karşı: mw / ml) ve onun yönü (haberle gelen: tw / tl); karşı
## yönü yalnızca o sayar → iki tarafın tabelası aynı kalır. Gerçek arkadaşı yenmek +%20 para (FRIEND_BONUS),
## arkadaş başına günde bir kez. Emre / Elif'e karşı da kendi yönüm sayılır (haber / bonus yok).
##
## Sahnede World/Gameplay/RaceManager olarak durur, "race" grubundan bulunur (autoload yok).
## Kayıt: KİŞİSEL REKOR + profil kartındaki yarış / galibiyet sayıları ("wins", "races"; eski kayıtta 0). Rekor TEKTİR
## (kullanıcı 2026-10-20: araçtan araca tutulmaz): hangi araçla olursa olsun en iyi 300 m süresi + o koşunun mesafe izi
## (ilerleme çubuğundaki "hayalet"). SaveManager "race" bölümü olarak okur/yazar ("best": {araç id: {...}}, tek kayıt;
## eski kayıttaki araç başına rekorlardan en hızlısı alınır); bölüm yoksa rekorsuz başlanır (sürüm atlamaz).

## Yoldan gelen rakip durdu ve davet açık (HUD balonu/plakası için).
signal challenger_ready(vehicle: Node3D)
## Rakip davet vermeden çekildi ya da yarış bitti.
signal challenger_left(vehicle: Node3D)
## Yarış bitti: ödül verildi (HUD bildirimi için).
signal race_finished(won: bool, money: int, xp: int)
## Oyuncu rakibin 🏁 balonuna/aracına dokundu → davet panosu açılmalı.
signal challenge_clicked(vehicle: Node3D)
## Kişisel rekor değişti (otomatik kayıt için).
signal records_changed
## Önceki rekor GEÇİLDİ (ilk koşu sayılmaz; görev / başarım sayacı).
signal record_broken(vehicle_id: StringName, time: float)
## Oyuncu kaybettiği yarışın rövanşını başlattı (aynı rakip yeniden pistte).
signal rematch_started(count: int)
## Arkadaşın (gerçek ya da Emre / Elif) aracıyla yarış bitti: haber + skor (SocialManager dinler).
signal friend_race_finished(owner: Dictionary, won: bool, player_vehicle: StringName, rival_vehicle: StringName, revenge: bool)

## Bir rakip gittikten sonra yenisi ne kadar sonra gelir (sn).
## 2026-10-21 zorluk turu: 5–10 sn idi (ardı ardına yarış tamirden çok kazandırıyordu) → 25–45 sn denendi, kullanıcı
## 10–15 sn istedi; para kısıntısı ödülde (WIN_REWARD).
@export var challenge_interval_min: float = 10.0
@export var challenge_interval_max: float = 15.0
## Yarıştan sonra yeni rakip için beklenen en az süre.
@export var cooldown: float = 10.0   # yarış sonrası da 10–15 sn (12 idi; zorluk turunda 30)
## Rakibin durduğu nokta: yarış şeridindeki bu yol noktası. Yön bir sonraki noktadan türetilir,
## yani sahnede ayrı bir işaret (Marker3D) gerekmez. Garaja yakın şerit (x = 0,3) kuzeyden
## gelir, kavşağın hemen öncesinde durur; kabul edilmezse dümdüz devam edip güneyden çıkar.
@export var stop_waypoint: StringName = &"N_in_approach"
## İSTEĞE BAĞLI el ile duruş noktası. Yarış şeridinin üstünde DEĞİLSE yok sayılır (uyarı basar):
## eski sürümde davet tamir şeridinde açılıyordu, oradaki işaret artık geçerli değil.
@export var challenge_spot: Node3D

## KAZANMA ÖDÜLLERİ — rakibin sınıfına göre (₺, XP). Kaybetmek para KAYBETTİRMEZ: yalnızca
## teselli XP'si verilir, böylece yarış ekonomide geriye götürmez (yakıt/ücret de yoktur).
const WIN_REWARD: Dictionary = {
	"D": {"money": 300, "xp": 25},   # 2026-10-21 zorluk turu: 450 / 700 / 1000 / 1400 / 2000 idi
	"C": {"money": 480, "xp": 35},
	"B": {"money": 700, "xp": 50},
	"A": {"money": 1000, "xp": 70},
	"S": {"money": 1400, "xp": 100},   # süper sporlar (GT3, Huracán, 488 Pista, RS6)
}
## Sahiplik düğümü yoksa (test sahnesi) yarışa çıkan araç.
const FALLBACK_VEHICLE: StringName = &"tofas_sahin"

## Rekor izinin örnek aralığı (sn, yarış saatine göre: GO'dan itibaren).
const TRACE_STEP: float = 0.25
## Kayıttan gelen süre bu aralık dışındaysa yok sayılır (bozuk / elle oynanmış kayıt).
const RECORD_MIN: float = 3.0
const RECORD_MAX: float = 60.0
const TRACE_MAX: int = 240

## Bir rakiple en çok kaç rövanş (kullanıcı: "rövanş 1 kere olur, 2.ye yenilirse rövanş çıkmayacak").
const MAX_REMATCHES: int = 1

## Kaybeden rakibin kaçma olasılığı (kullanıcı: "7 araçta 1, nadir bir görüntü olsun"). Testler 1,0 verir.
@export_range(0.0, 1.0) var flee_chance: float = 1.0 / 7.0

## Kaybedince verilen XP oranı (para yok).
const LOSS_XP_RATIO: float = 0.3
## Gerçek arkadaşı yenince ek para oranı (kullanıcı kararı: +%20, arkadaş başına günde bir).
const FRIEND_BONUS: float = 0.2

## Rakibin bir arkadaşın (gerçek ya da Emre / Elif) aracıyla gelme olasılığı (kullanıcı kararı: %70). Testler 0 / 1 verir.
@export_range(0.0, 1.0) var friend_chance: float = 0.7

## Rakip duruş noktasına bu kadar yaklaşınca davet açılır (balon çıkar).
const ARRIVE_DISTANCE: float = 0.45
## El ile verilen duruş noktası şeritten bu kadar uzaksa yok sayılır.
const SPOT_TOLERANCE: float = 1.5

var _timer: float = 0.0
var _challenger: TrafficVehicle
## Duruş noktası: yarış şeridindeki waypoint'ten türetilen, gidiş yönüne dönük işaret.
var _stop: Marker3D
var _rival_id: StringName = &""
## Rakibin sahibi: {uid, name, av, frame, flag, featured, paint (Color hex ya da ""), build {kategori: kademe}};
## isimsiz NPC'de boş. Rakip seçilirken belirlenir, rakip gidene kadar (rövanş dahil) aynı kalır.
var _rival_owner: Dictionary = {}
var _rival_appearance: CarAppearance
var _traffic: TrafficManager
const CarHitbox: GDScript = preload("res://car_hitbox.gd")

var _rng := RandomNumberGenerator.new()
## Davet açıkken oyuncu kabul etmezse rakip bu süre sonunda yola döner (bekleyen araç kalıcı
## olarak yolu işgal etmesin). Yarış sürerken sayaç işlemez.
@export var challenge_timeout: float = 30.0
var _wait: float = 0.0
## Yarış ekranı açıkken rakip beklemeye devam eder (zaman aşımı durur).
var _racing: bool = false
## EĞİTİM (drag yarışı dersi) anlatırken rakip yoldan çekilip gitmesin: zaman aşımı durur.
var tutorial_hold: bool = false
## Aynı yarışın ödülü iki kez verilmesin diye: ödül verildiğinde işaretlenir.
var _reward_paid: bool = false
## Kaybedilen yarıştan sonra rakip rövanş için bekliyor mu; bu rakiple kaçıncı rövanş.
var _awaiting_rematch: bool = false
var _rematches: int = 0
## Oyuncu kazandı: kaybeden rakip oyuncu dünyaya dönünce yola çıkar; `_loser_flees` ise kaçarak (zar yarış bitince atılır).
var _loser_waiting: bool = false
var _loser_flees: bool = false
## KİŞİSEL REKOR: rekoru kıran araç id → {"time": sn, "trace": PackedFloat32Array (her TRACE_STEP'te metre)}.
## En çok BİR kayıt: daha hızlı koşu (hangi araçla olursa) öncekinin yerine geçer.
var _records: Dictionary = {}
## Profil kartı: biten yarış (rövanş dahil) ve galibiyet sayısı.
var _races: int = 0
var _wins: int = 0
## ARAÇ BAŞINA (ARAÇLAR ekranının EN ÇOK YARIŞILAN / EN ÇOK KAZANAN sıralaması): araç id → Vector2i(yarış, galibiyet).
## Toplamla aynı anda sayılır; satılan aracın sayacı silinmez (geri alınınca kaldığı yerden devam eder).
var _car_counts: Dictionary = {}
## ARKADAŞ SKORU: uid → {mw, ml: ben onun aracına karşı kazandım / kaybettim; tw, tl: o benim aracıma karşı (haberden)}.
var _rivals: Dictionary = {}
## Arkadaş bonusunun son verildiği gün: uid → UTC gün.
var _bonus_day: Dictionary = {}
## İNTİKAM: yoldan gelen araç yok, pist doğrudan açıldı (yarış oturumu bitene kadar yeni rakip gelmez).
var _direct: bool = false
var _revenge: bool = false


func _ready() -> void:
	add_to_group("race")
	_rng.randomize()
	_timer = _rng.randf_range(challenge_interval_min, challenge_interval_max)
	_connect_traffic.call_deferred()


func _process(delta: float) -> void:
	if _traffic == null or _direct:
		return
	if is_instance_valid(_challenger):
		if _challenger.mode == TrafficVehicle.Mode.TRAFFIC:
			# Şeritte geliyor: duruş noktasına varınca durup balonunu açar
			if _stop and _flat_distance(_challenger.global_position, _stop.global_position) <= ARRIVE_DISTANCE:
				_open_challenge()
			return
		# Davete dokunuldu mu? (mevcut araç seçimi yolu: CarHitbox.selected_car)
		if has_challenge() and CarHitbox.selected_car == _challenger:
			CarHitbox.clear_selection(get_tree())
			challenge_clicked.emit(_challenger)
		if not _racing and not tutorial_hold:
			_wait -= delta
			if _wait <= 0.0:
				release_challenger()   # oyuncu ilgilenmedi: dümdüz devam edip şeritten çıkar
		return
	_timer -= delta
	if _timer <= 0.0:
		_send_challenger()


## Yarış ekranı açık/kapalı: açıkken rakip beklemeye devam eder.
func set_racing(value: bool) -> void:
	_racing = value
	if not value:
		_wait = challenge_timeout


# --- Rakip seçimi -----------------------------------------------------------------

## RAKİP PERFORMANSA GÖRE seçilir (2026-10-11, kullanıcı onayı): oyuncunun aracının kusursuz 300 m
## süresine yakın araçlar — en fazla RIVAL_FASTER kadar hızlı, en fazla RIVAL_SLOWER kadar yavaş. Eskiden
## havuz "kendi sınıfı + bir üst sınıf"tı; sınıflar arası gerçek fark (~1 sn) rakibin gün formundan
## (~±0,4 sn) büyük olduğu için bir üst sınıftan gelen rakiplerin çoğu YENİLEMEZDİ (Golf'e karşı E46 %0).
## Pencere dar kalırsa (havuz < RIVAL_MIN_POOL) adım adım genişletilir. Katı kilit yok — oyuncunun sahip
## OLMADIĞI araçlar da rakip olabilir. Ölçüm: qa/matchup_report.gd.
const RIVAL_FASTER: float = 0.06
const RIVAL_SLOWER: float = 0.08
const RIVAL_MIN_POOL: int = 4


## Oyuncunun İLK yarışı mı (hiç rekor yok — eğitimin drag dersi de bu). İlk yarışta rakip havuzun en yavaşıdır
## ve GÜN FORMU çekilmez (DragRaceScreen): yeni oyuncu kusursuz oynadığı ilk yarışı rakibin iyi gününe kaybetmesin.
func is_first_race() -> bool:
	return _records.is_empty()


## `busy`: şehirde şu an olan modeller (TrafficManager.models_in_use) — aynı modelden ikinci araç yola çıkmaz,
## rakip boştakilerden seçilir. Havuzun hepsi meşgulse eski seçim (rakip, model boşalınca gelir).
func rival_id_for(player_id: StringName, busy: Dictionary = {}) -> StringName:
	var pool: Array[StringName] = rival_pool(player_id)
	var free: Array[StringName] = []
	for id: StringName in pool:
		if not busy.has(id):
			free.append(id)
	# İLK YARIŞ (hiç rekor yok — eğitimin drag dersi de bu): havuzun EN YAVAŞ aracı. Performansa göre havuzda
	# daha hızlı araç da var; QA'da yeni oyuncu ilk yarışını Şahin'le Corsa'ya karşı kaybediyordu (13,65 / 12,93 sn).
	# En yavaşı şehirdeyse boştaki en yavaş — yalnızca oyuncunun aracından hâlâ yavaşsa (ilk yarış kazanılabilir kalsın).
	if is_first_race():
		var slowest: StringName = _slowest(pool)
		var slowest_free: StringName = _slowest(free)
		if slowest_free != &"" and DragRaceSim.base_time(slowest_free) >= PerformanceMods.time_300(player_id):
			return slowest_free
		return slowest
	if free.is_empty():
		return pool[_rng.randi_range(0, pool.size() - 1)]
	return free[_rng.randi_range(0, free.size() - 1)]


## Rakip modeli + sahibi: {"id", "owner"}. friend_chance ile arkadaş turu: gerçek arkadaşın uyan aracı, yoksa
## havuzdan seçilen araç Emre / Elif'in (aracın karakterine göre). Değilse isimsiz rakip (owner boş).
func pick_rival(player_id: StringName, busy: Dictionary = {}) -> Dictionary:
	if _rng.randf() < friend_chance:
		if not is_first_race():
			var real: Dictionary = _real_friend_pick(player_id, busy)
			if not real.is_empty():
				return real
		var id: StringName = rival_id_for(player_id, busy)
		return {"id": id, "owner": FeaturedFriends.rival_owner(FeaturedFriends.owner_for_car(id))}
	return {"id": rival_id_for(player_id, busy), "owner": {}}


## Rakip olabilecek sürelerin aralığı (sn): rival_pool'un vardığı pencere (oyuncunun modifiyeli süresine göre).
static func rival_window(player_id: StringName) -> Vector2:
	var pool: Array[StringName] = rival_pool(player_id)
	var mine: float = PerformanceMods.time_300(player_id)
	var low: float = mine * (1.0 - RIVAL_FASTER)
	var high: float = mine * (1.0 + RIVAL_SLOWER)
	for id: StringName in pool:
		low = minf(low, DragRaceSim.base_time(id))
		high = maxf(high, DragRaceSim.base_time(id))
	return Vector2(low, high)


## Gerçek arkadaşlardan biri (rastgele) ve onun penceredeki, şehirde olmayan araçlarından biri. Yoksa boş.
func _real_friend_pick(player_id: StringName, busy: Dictionary) -> Dictionary:
	var social: SocialManager = get_tree().get_first_node_in_group("social") as SocialManager if is_inside_tree() else null
	if social == null or not social.is_ready():
		return {}
	var window: Vector2 = rival_window(player_id)
	var options: Array[Dictionary] = []   # {friend, cars: Array[StringName]}
	for friend: Dictionary in social.friends:
		var race_data: Dictionary = friend.get("race", {}) if friend.get("race") is Dictionary else {}
		var builds: Dictionary = race_data.get("builds", {}) if race_data.get("builds") is Dictionary else {}
		var fits: Array[StringName] = []
		for raw: Variant in race_data.get("cars", []):
			var id: StringName = StringName(SaveSafe.s(raw))
			if busy.has(id) or not _rival_eligible(id):
				continue
			var build: Dictionary = builds.get(String(id), {}) if builds.get(String(id)) is Dictionary else {}
			var t: float = float(PerformanceMods.measure(id, build)["t300"]) if not build.is_empty() else DragRaceSim.base_time(id)
			if t >= window.x and t <= window.y:
				fits.append(id)
		if not fits.is_empty():
			options.append({"friend": friend, "cars": fits})
	if options.is_empty():
		return {}
	var chosen: Dictionary = options[_rng.randi_range(0, options.size() - 1)]
	var cars: Array[StringName] = chosen["cars"]
	var car: StringName = cars[_rng.randi_range(0, cars.size() - 1)]
	var friend_entry: Dictionary = chosen["friend"]
	var race_info: Dictionary = friend_entry.get("race", {})
	var owner: Dictionary = {
		"uid": SaveSafe.s(friend_entry.get("uid", "")), "name": SaveSafe.s(friend_entry.get("name", "")),
		"av": SaveSafe.s(friend_entry.get("av", "")), "frame": SaveSafe.s(friend_entry.get("frame", "")),
		"flag": SaveSafe.s(friend_entry.get("flag", "")), "featured": false,
		"paint": SaveSafe.s((race_info.get("paint", {}) as Dictionary).get(String(car), "")) if race_info.get("paint") is Dictionary else "",
		"build": PerformanceMods.normalized((race_info.get("builds", {}) as Dictionary).get(String(car), {})) if race_info.get("builds") is Dictionary else {},
	}
	social.avatar_of(owner["uid"], owner["av"])   # fotoğraf önbellekte değilse araç yoldayken insin
	return {"id": car, "owner": owner}


## Rakip olabilir mi (katalogda, edinilebilir, hurdalık aracı değil): arkadaşın garajından gelen kimlik süzülür.
static func _rival_eligible(id: StringName) -> bool:
	var entry: Dictionary = CarCatalog.get_entry(id)
	return not entry.is_empty() and bool(entry.get("obtainable", true)) and not RestorationCatalog.is_restoration(id)


## Rakibin yoldaki görünümü: arkadaşın boyası (yoksa fabrika rengi); Emre / Elif fabrika renginde (kullanıcı kararı:
## öne çıkan araçlar boyanmaz); isimsiz rakip null → trafik rastgele renk verir.
static func _appearance_for(id: StringName, owner: Dictionary) -> CarAppearance:
	if owner.is_empty():
		return null
	var appearance: CarAppearance = CarAppearance.new()
	appearance.body_color = CarCatalog.default_color_for(CarCatalog.scene_path(id))
	var hex: String = SaveSafe.s(owner.get("paint", ""))
	if not hex.is_empty() and Color.html_is_valid(hex) and VehicleOwnership.is_paintable(id):
		appearance.body_color = Color.html(hex)
	return appearance


static func _slowest(ids: Array[StringName]) -> StringName:
	var slowest: StringName = &""
	for id: StringName in ids:
		if slowest == &"" or DragRaceSim.base_time(id) > DragRaceSim.base_time(slowest):
			slowest = id
	return slowest


## Oyuncunun aracına verilebilecek rakipler (oyuncunun kendi modeli dahil: aynalı yarış).
static func rival_pool(player_id: StringName) -> Array[StringName]:
	var mine: float = PerformanceMods.time_300(player_id)   # modifiyeli süre: yükseltme üst sınıf rakip getirir
	var widen: float = 1.0
	var pool: Array[StringName] = []
	while widen <= 4.0:
		pool.clear()
		for entry: Dictionary in CarCatalog.all():
			if RestorationCatalog.is_restoration(entry["id"]) or not entry["obtainable"]:
				continue   # hurdalık araçları trafikte yoktur, polis yalnızca kovalamacada: yoldan rakip olarak da gelmez
			var theirs: float = DragRaceSim.base_time(entry["id"])
			if theirs >= mine * (1.0 - RIVAL_FASTER * widen) and theirs <= mine * (1.0 + RIVAL_SLOWER * widen):
				pool.append(entry["id"])
		if pool.size() >= RIVAL_MIN_POOL:
			break
		widen += 0.5
	if pool.is_empty():
		pool.append(player_id)
	return pool


## Oyuncunun yarışa çıkaracağı araç: garajda YARIŞ ARACI olarak seçilen (VehicleOwnership.race_vehicle_id);
## seçilmemişse başlangıç aracı Tofaş Şahin. (Eskiden sahip olunan ilk araç dönüyordu: o da E46'ydı,
## oyuncu ilk dakikadan A sınıfıyla yarışıyordu.)
func player_vehicle_id() -> StringName:
	var ownership: VehicleOwnership = get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	if ownership == null:
		return FALLBACK_VEHICLE
	var id: StringName = ownership.race_vehicle_id()
	return id if id != &"" else FALLBACK_VEHICLE


func challenger() -> TrafficVehicle:
	return _challenger if is_instance_valid(_challenger) else null


func rival_id() -> StringName:
	return _rival_id


## Rakibin sahibi (arkadaş); isimsiz rakipte boş sözlük.
func rival_owner() -> Dictionary:
	return _rival_owner


## Rakip aracın modifiyeleri (arkadaşın yapısı; yoksa boş = fabrika).
func rival_build() -> Dictionary:
	return _rival_owner.get("build", {}) if _rival_owner.get("build") is Dictionary else {}


## Rakip aracın görünümü (yoldan gelen aracınki: pistte de aynı renk). Rakip yoksa null.
func rival_appearance() -> CarAppearance:
	return _rival_appearance


## Hemen bir rakip getirir ve davetini AÇAR (hata ayıklama / test): şeridi baştan sona sürmesini
## beklemez, doğrudan duruş noktasına konur.
func request_challenge_now() -> bool:
	if not is_instance_valid(_challenger):
		_send_challenger()
	if not is_instance_valid(_challenger):
		return false
	if _challenger.mode == TrafficVehicle.Mode.TRAFFIC and _stop:
		_challenger.global_position = _stop.global_position
		_open_challenge()
	return true


## Yarış daveti açık mı?
func has_challenge() -> bool:
	return is_instance_valid(_challenger) and _challenger.mode == TrafficVehicle.Mode.RACE_CHALLENGE


# --- Ödül -------------------------------------------------------------------------

## İNTİKAM: arkadaşın (haberdeki) aracına karşı pist doğrudan açılır. Yoldaki davet varsa kapanır. Rövanş yok.
func start_revenge(owner: Dictionary, vehicle_id: StringName) -> bool:
	# Araç arkadaşın yazdığı haberden gelir: edinilemeyen (polis) araç elle yazılmış olabilir, yarışa çıkmaz
	if owner.is_empty() or not CarCatalog.is_obtainable(vehicle_id):
		return false
	release_challenger()
	_direct = true
	_revenge = true
	_rival_id = vehicle_id
	_rival_owner = owner.duplicate(true)
	_rival_appearance = _appearance_for(vehicle_id, _rival_owner)
	_reward_paid = false
	_rematches = 0   # rövanş zaten çıkmaz (yolda bekleyen rakip yok); kayıpta normal teselli XP'si
	return true


func is_revenge() -> bool:
	return _revenge


## Rakip gerçek arkadaşsa ve bugün ondan bonus alınmadıysa kazanınca +%20.
func friend_bonus_available() -> bool:
	var uid: String = SaveSafe.s(_rival_owner.get("uid", ""))
	return not uid.is_empty() and not bool(_rival_owner.get("featured", false)) \
		and SaveSafe.i(_bonus_day.get(uid, -1)) != _today()


## Arkadaşla skor: x = benim galibiyetlerim, y = onunkiler (iki yön toplamı).
func score_with(uid: String) -> Vector2i:
	var r: Dictionary = _rivals.get(uid, {})
	return Vector2i(SaveSafe.i(r.get("mw", 0)) + SaveSafe.i(r.get("tl", 0)), SaveSafe.i(r.get("ml", 0)) + SaveSafe.i(r.get("tw", 0)))


## Kendi yönümdeki sayılar (habere yazılır): x = kazandığım, y = kaybettiğim.
func my_counts(uid: String) -> Vector2i:
	var r: Dictionary = _rivals.get(uid, {})
	return Vector2i(SaveSafe.i(r.get("mw", 0)), SaveSafe.i(r.get("ml", 0)))


## Arkadaşın yönü (haberden): o benim aracıma karşı kaç kez kazandı / kaybetti. Yalnızca o sayar → olduğu gibi alınır.
func set_their_counts(uid: String, wins: int, losses: int) -> void:
	if uid.is_empty():
		return
	var r: Dictionary = _rivals.get(uid, {})
	if SaveSafe.i(r.get("tw", 0)) == wins and SaveSafe.i(r.get("tl", 0)) == losses:
		return
	r["tw"] = maxi(wins, 0)
	r["tl"] = maxi(losses, 0)
	_rivals[uid] = r
	records_changed.emit()   # kayıt


static func _today() -> int:
	return floori(Time.get_unix_time_from_system() / 86400.0)


## Bir yarışın ödülü (₺, XP) — kazanan/kaybedene göre. UI de bunu kullanır (hardcode yok). Canlı etkinlik çarpanı dahil.
func reward_for(rival: StringName, won: bool) -> Dictionary:
	var rival_class: String = String(CarCatalog.get_entry(rival).get("class", "D"))
	var base: Dictionary = WIN_REWARD.get(rival_class, WIN_REWARD["D"])
	var money_mult: float = AppConfig.money_multiplier(get_tree()) if is_inside_tree() else 1.0
	var xp_mult: float = AppConfig.xp_multiplier(get_tree()) if is_inside_tree() else 1.0
	if won:
		return {"money": int(round(float(base["money"]) * money_mult)), "xp": int(round(float(base["xp"]) * xp_mult))}
	return {"money": 0, "xp": int(round(float(base["xp"]) * LOSS_XP_RATIO * xp_mult))}


## Yarış bitti: ödül BİR KEZ verilir (aynı yarış iki kez ödül vermez). Kazanınca rakip yola döner; kaybedince
## rövanş için bekler (GARAJA DÖN → end_race_session). Rövanş kaybı ödülsüzdür (teselli XP'si yalnız ilk kayıpta).
func finish_race(won: bool) -> Dictionary:
	var reward: Dictionary = reward_for(_rival_id, won)
	if not won and _rematches > 0:
		reward = {"money": 0, "xp": 0}
	if _reward_paid:
		return {"money": 0, "xp": 0}
	_reward_paid = true
	_races += 1
	if won:
		_wins += 1
	var car: StringName = player_vehicle_id()
	var counts: Vector2i = _car_counts.get(car, Vector2i.ZERO)
	_car_counts[car] = counts + Vector2i(1, 1 if won else 0)
	records_changed.emit()   # kayıt (ödülsüz rövanş kaybında para / XP değişmez, sayaç yine yazılsın)
	# Gerçek arkadaşı yendin: +%20, arkadaş başına günde bir
	if won and int(reward["money"]) > 0 and friend_bonus_available():
		var bonus: int = int(round(float(reward["money"]) * FRIEND_BONUS))
		reward["money"] = int(reward["money"]) + bonus
		reward["friend_bonus"] = bonus
		_bonus_day[SaveSafe.s(_rival_owner.get("uid", ""))] = _today()
	var economy: EconomyManager = get_tree().get_first_node_in_group("economy") as EconomyManager
	if economy and int(reward["money"]) > 0:
		economy.add_money(int(reward["money"]))
	var progress: PlayerProgress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress
	if progress and int(reward["xp"]) > 0:
		progress.add_xp(int(reward["xp"]))
	race_finished.emit(won, int(reward["money"]), int(reward["xp"]))
	if not _rival_owner.is_empty():
		var uid: String = SaveSafe.s(_rival_owner.get("uid", ""))
		var r: Dictionary = _rivals.get(uid, {})
		r["mw" if won else "ml"] = SaveSafe.i(r.get("mw" if won else "ml", 0)) + 1
		_rivals[uid] = r
		friend_race_finished.emit(_rival_owner.duplicate(true), won, player_vehicle_id(), _rival_id, _revenge)
	if _direct:
		pass   # İNTİKAM: sonuç panosu sahibini gösterir; oturum bitince (end_race_session) temizlenir
	elif won and is_instance_valid(_challenger):
		_loser_waiting = true   # kaybeden rakip oyuncu dünyaya dönünce yola çıkar (end_race_session)
		_loser_flees = _rng.randf() < flee_chance
	elif won or not is_instance_valid(_challenger) or _rematches >= MAX_REMATCHES:
		release_challenger()   # rövanş hakkı bitti: rakip yola döner
	else:
		_awaiting_rematch = true   # rakip şeritte bekler: oyuncu RÖVANŞ ya da GARAJA DÖN seçer
	return reward


## Kaybedilen yarışın rövanşı yapılabilir mi (rakip hâlâ şeritte bekliyor).
func can_rematch() -> bool:
	return _awaiting_rematch and _rematches < MAX_REMATCHES and is_instance_valid(_challenger) and _rival_id != &""


## Bu rakiple kaçıncı rövanş (0 = ilk yarış).
func rematch_count() -> int:
	return _rematches


## RÖVANŞ: aynı rakiple yeni yarış (ödül yeniden verilebilir hâle gelir). Pisti HUD yeniden açar.
func start_rematch() -> bool:
	if not can_rematch():
		return false
	_awaiting_rematch = false
	_reward_paid = false
	_rematches += 1
	rematch_started.emit(_rematches)
	return true


## Yarış modundan çıkıldı (GARAJA DÖN / GERİ): rövanş bekleyen rakip yola döner.
func end_race_session() -> void:
	if _direct:
		release_challenger()   # İNTİKAM bitti: yoldan yine rakip gelmeye başlar
		return
	if _loser_waiting:
		release_challenger(_loser_flees)   # ~7'de 1: kaçar gibi gider
	elif _awaiting_rematch:
		release_challenger()


## Kaybeden rakip oyuncunun dönüşünü mü bekliyor (kazanılan yarıştan sonra)?
func loser_waiting() -> bool:
	return _loser_waiting and is_instance_valid(_challenger)


## Bekleyen kaybeden dönüşte kaçacak mı (zar atıldı)?
func loser_flees() -> bool:
	return loser_waiting() and _loser_flees


## Rakibi normal trafiğe geri gönderir (yarış bitti ya da vazgeçildi). `fled`: yarışı kaybetti, kaçarak gider.
func release_challenger(fled: bool = false) -> void:
	var vehicle: TrafficVehicle = _challenger
	_challenger = null
	_rival_id = &""
	_rival_owner = {}
	_rival_appearance = null
	_direct = false
	_revenge = false
	_awaiting_rematch = false
	_loser_waiting = false
	_loser_flees = false
	_rematches = 0
	_timer = maxf(cooldown, _rng.randf_range(challenge_interval_min, challenge_interval_max))
	if is_instance_valid(vehicle):
		vehicle.end_race_challenge()
		if fled:
			vehicle.flee()
		challenger_left.emit(vehicle)


# --- Kişisel rekor ----------------------------------------------------------------

func wins() -> int:
	return _wins


func races() -> int:
	return _races


## Bu araçla biten yarış sayısı (rövanş dahil).
func vehicle_races(vehicle_id: StringName) -> int:
	return (_car_counts.get(vehicle_id, Vector2i.ZERO) as Vector2i).x


## Bu araçla kazanılan yarış sayısı.
func vehicle_wins(vehicle_id: StringName) -> int:
	return (_car_counts.get(vehicle_id, Vector2i.ZERO) as Vector2i).y


## Bütün araçlar arasında en iyi 300 m: {"vehicle": id, "time": sn}; rekor yoksa boş.
func overall_best() -> Dictionary:
	var out: Dictionary = {}
	for id: StringName in _records:
		var time: float = float(_records[id]["time"])
		if out.is_empty() or time < float(out["time"]):
			out = {"vehicle": id, "time": time}
	return out


## Rekor (sn; hangi araçla kırıldıysa); yoksa -1.
func best_time() -> float:
	return float(_record().get("time", -1.0))


## Rekor koşunun mesafe izi (metre, her TRACE_STEP saniyede bir); yoksa boş.
func best_trace() -> PackedFloat32Array:
	return _record().get("trace", PackedFloat32Array())


## Rekoru kıran araç (yoksa &"").
func best_vehicle() -> StringName:
	return _records.keys()[0] if not _records.is_empty() else &""


func _record() -> Dictionary:
	return _records.values()[0] if not _records.is_empty() else {}


## Bitmiş bir koşuyu bildirir. Rekoru (hangi araçla kırılmış olursa) geçtiyse onun yerine geçer ve true döner;
## ilk koşu da rekordur.
func submit_time(vehicle_id: StringName, time: float, trace: PackedFloat32Array) -> bool:
	if vehicle_id == &"" or time < RECORD_MIN or time > RECORD_MAX:
		return false
	var previous: float = best_time()
	if previous > 0.0 and time >= previous:
		return false
	_records = {vehicle_id: {"time": time, "trace": trace.slice(0, TRACE_MAX)}}
	records_changed.emit()
	if previous > 0.0:
		record_broken.emit(vehicle_id, time)
	return true


func state() -> Dictionary:
	var best: Dictionary = {}
	for id: StringName in _records:
		var record: Dictionary = _records[id]
		var trace: Array = []
		for meters: float in record["trace"]:
			trace.append(snappedf(meters, 0.1))
		best[String(id)] = {"time": snappedf(float(record["time"]), 0.001), "trace": trace}
	var rivals: Dictionary = {}
	for uid: String in _rivals:
		var r: Dictionary = _rivals[uid]
		rivals[uid] = {"mw": SaveSafe.i(r.get("mw", 0)), "ml": SaveSafe.i(r.get("ml", 0)),
			"tw": SaveSafe.i(r.get("tw", 0)), "tl": SaveSafe.i(r.get("tl", 0))}
	var cars: Dictionary = {}
	for id: StringName in _car_counts:
		var counts: Vector2i = _car_counts[id]
		cars[String(id)] = {"r": counts.x, "w": counts.y}
	return {"best": best, "races": _races, "wins": _wins, "cars": cars, "rivals": rivals, "bonus": _bonus_day.duplicate()}


func load_state(data: Dictionary) -> void:
	_records.clear()
	_races = maxi(SaveSafe.i(data.get("races", 0)), 0)
	_wins = clampi(SaveSafe.i(data.get("wins", 0)), 0, _races)
	_car_counts.clear()
	var cars: Variant = data.get("cars", {})
	if cars is Dictionary:
		for key: Variant in cars:
			var raw: Variant = (cars as Dictionary)[key]
			var id: StringName = StringName(SaveSafe.s(key))
			if not raw is Dictionary or id == &"" or CarCatalog.get_entry(id).is_empty():
				continue
			var count: int = maxi(SaveSafe.i((raw as Dictionary).get("r", 0)), 0)
			if count > 0:
				_car_counts[id] = Vector2i(count, clampi(SaveSafe.i((raw as Dictionary).get("w", 0)), 0, count))
	_rivals.clear()
	_bonus_day.clear()
	var rivals: Variant = data.get("rivals", {})
	if rivals is Dictionary:
		for uid: Variant in rivals:
			var r: Variant = (rivals as Dictionary)[uid]
			if r is Dictionary and _rivals.size() < 500:
				_rivals[SaveSafe.s(uid)] = {"mw": maxi(SaveSafe.i(r.get("mw", 0)), 0), "ml": maxi(SaveSafe.i(r.get("ml", 0)), 0),
					"tw": maxi(SaveSafe.i(r.get("tw", 0)), 0), "tl": maxi(SaveSafe.i(r.get("tl", 0)), 0)}
	var bonus: Variant = data.get("bonus", {})
	if bonus is Dictionary:
		for uid: Variant in bonus:
			_bonus_day[SaveSafe.s(uid)] = SaveSafe.i((bonus as Dictionary)[uid])
	var best: Variant = data.get("best", {})
	if not best is Dictionary:
		return
	for key: Variant in best:
		var raw: Variant = best[key]
		var id: StringName = StringName(SaveSafe.s(key))
		if not raw is Dictionary or id == &"" or CarCatalog.get_entry(id).is_empty():
			continue
		var time: float = SaveSafe.f((raw as Dictionary).get("time", 0.0))
		if time < RECORD_MIN or time > RECORD_MAX:
			continue
		if not _records.is_empty() and time >= best_time():
			continue   # tek rekor: eski kayıttaki araç başına rekorlardan en hızlısı kalır
		var trace: PackedFloat32Array = PackedFloat32Array()
		var raw_trace: Variant = (raw as Dictionary).get("trace", [])
		if raw_trace is Array:
			for value: Variant in (raw_trace as Array).slice(0, TRACE_MAX):
				trace.append(clampf(SaveSafe.f(value), 0.0, DragRaceSim.DISTANCE))
		_records = {id: {"time": time, "trace": trace}}


func reset() -> void:
	_records.clear()
	_races = 0
	_wins = 0
	_car_counts.clear()
	_rivals.clear()
	_bonus_day.clear()


# --- İç ---------------------------------------------------------------------------

func _connect_traffic() -> void:
	_traffic = _find_traffic(get_tree().current_scene if get_tree().current_scene else get_parent())
	if _traffic == null:
		push_warning("RaceManager: TrafficManager bulunamadı; yarış daveti gelmez")
		return
	if _traffic.race_spawn_point == null:
		push_warning("RaceManager: yarış şeridi (TrafficManager.race_lane_spawn) bulunamadı")
	_build_stop()


## Yarış şeridine yeni bir rakip salar. Şerit doluysa (önceki hâlâ çıkmadıysa) sonra denenir.
func _send_challenger() -> void:
	if _stop == null:
		_timer = 5.0
		return
	var ownership: VehicleOwnership = get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	if ownership and ownership.owned_count() == 0:
		_timer = 5.0   # henüz aracı yok (HOŞ GELDİN KUTUSU açılmadı): yarışacak araç olmadan rakip gelmez
		return
	# Rakip modeli ÖNCE seçilir (oyuncunun aracının performansına göre), araç o modelle yola çıkar: yoldan
	# gelen araç ile yarışta karşına çıkan araç AYNI olur. Sahibi (arkadaş / isimsiz) de o anda seçilir.
	# Seçilen model bu arada şehre çıktıysa (aynı modelden tek araç) boştakilerden yeniden seçilir
	if _rival_id == &"" or _traffic.is_model_in_use(_rival_id):
		var pick: Dictionary = pick_rival(player_vehicle_id(), _traffic.models_in_use())
		_rival_id = pick["id"]
		_rival_owner = pick["owner"]
		_rival_appearance = _appearance_for(_rival_id, _rival_owner)
	var vehicle: TrafficVehicle = _traffic.spawn_challenger(_rival_id, _rival_appearance)
	if vehicle == null:
		_timer = 2.0   # model yükleniyor ya da şerit dolu: birazdan yine dener
		return
	_challenger = vehicle
	_rival_id = vehicle.vehicle_id
	_rival_appearance = vehicle.appearance   # isimsiz rakibin rastgele rengi de pistte aynı kalsın
	_reward_paid = false


## Rakip duruş noktasına geldi: durur, 🏁 balonunu açar ve zaman aşımı sayacı başlar. Arkadaş rakipte balonda
## fotoğrafı da vardır (fotoğraf o ana kadar inmediyse kask).
func _open_challenge() -> void:
	_wait = challenge_timeout
	if not _rival_owner.is_empty():
		var art: Dictionary = ProfileCard.avatar_for(get_tree(), _rival_owner)
		_challenger.race_avatar = art.get("texture")
		_challenger.race_avatar_illustrated = bool(art.get("illustrated", true))
	else:
		_challenger.race_avatar = null
	_challenger.request_race_challenge(_stop)
	challenger_ready.emit(_challenger)


## Duruş noktası: yarış şeridindeki waypoint'in konumu + gidiş yönü. Sahnede işaret gerekmez;
## el ile bir işaret verildiyse (challenge_spot) ve şeridin üstündeyse o kullanılır.
func _build_stop() -> void:
	var point: TrafficWaypoint = _waypoint(stop_waypoint)
	if point == null:
		push_warning("RaceManager: '%s' yol noktası yok; davet açılamaz" % stop_waypoint)
		return
	_stop = Marker3D.new()
	_stop.name = "RaceStop"
	add_child(_stop)
	_stop.global_position = point.global_position
	var next: Array[TrafficWaypoint] = point.get_next()
	if not next.is_empty():
		var direction: Vector3 = next[0].global_position - point.global_position
		direction.y = 0.0
		if direction.length_squared() > 0.0001:
			# Model önü +Z: araç şeridin gidiş yönüne dönük park eder
			_stop.rotation.y = atan2(direction.x, direction.z)
	if is_instance_valid(challenge_spot):
		if _flat_distance(challenge_spot.global_position, _stop.global_position) <= SPOT_TOLERANCE:
			_stop.global_transform = challenge_spot.global_transform
		else:
			push_warning("RaceManager: challenge_spot yarış şeridinde değil, yok sayıldı " +
				Loc.t("(şerit noktası %s, verilen %s)") % [_stop.global_position, challenge_spot.global_position])


func _waypoint(point_name: StringName) -> TrafficWaypoint:
	for point: TrafficWaypoint in _traffic.waypoints:
		if point.name == point_name:
			return point
	return null


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _find_traffic(node: Node) -> TrafficManager:
	if node == null:
		return null
	if node is TrafficManager:
		return node
	for child: Node in node.get_children():
		var found: TrafficManager = _find_traffic(child)
		if found:
			return found
	return null
