class_name PetWorld
extends Node3D
## GARAJ DOSTLARI — kedinin garajdaki HAYATI: nereye yürür, ne yapar, neye tepki verir. Görünüm PetActor'da, veri
## PetManager'da. GarageSystem kodla kurar ("pet_world" grubu): GARAJ YUVASI başına bir tane (PetManager.MAX_OUT,
## 2026-11-03 "garajda aynı anda 2 hayvan"); her biri kendi yuvasındaki hayvanı (PetManager.pet_in_slot) gösterir, yuva
## boşsa sahnede kedi yoktur. Yuva 0 ilk kedinin geliş sinematiğini de oynatır. İki kedi aynı eşyaya / araç tavanına /
## kasaya çıkmaz (_taken).
##
## YOL: garaj zemini dekor ızgarasının (DecorGrid, göz 0,175) gözlerine bölünür; dekor eşyaları, tamir alanları, kasalar
## ve iç duvarlar (kedi yarıçapı kadar şişirilmiş) engeldir; AStarGrid2D yol bulur, görüş hattı olan ara noktalar atlanır.
## HAYAT: ağırlıklı rastgele işler (dolaş / otur / somun / şekerleme / uyku / kokla / sergideki aracın tavanına çık) —
## her iş bir eşzamansız rutindir; kesinti (dokunma, tepki) `_gen`'i artırır, eski rutin bir sonraki adımda bırakır.
## TEPKİLER (kullanıcı kararı): müşteri gelince garaj ağzına gidip bakar; kasa gelince üstüne çıkar; tamir bitince
## araca gidip ₺ balonuna pati atar. Uyurken tepki vermez (yalnız dokunma uyandırır).
## Uyurken yüz kameraya: kamera güneydoğuda, kedi kuzeye (yaw 0, −Z) dönük kıvrılınca yüzü görünür (tekir_clips
## SLEEP_FACE_DIR).

## Kediye dokunuldu (yakın kamera açılır).
signal pet_tapped
## Yakın kamera için hazır: kedi kamera tarafında oturdu ve kameraya bakıyor.
signal closeup_ready
## Geliş sinematiği: sokaktan giren kedi yerine vardı ve oturdu.
signal visitor_arrived
## Hayat döngüsünde bir iş başladı / bitti (QA, ölçüm). ok=false: iş yarıda kesildi ya da yapılamadı.
signal activity_started(act: StringName)
signal activity_finished(act: StringName, ok: bool)

## Kedinin yarıçapı (birim) + pay: engeller bu kadar şişirilir.
const CAT_RADIUS: float = 0.04 * PetActor.SIZE
## Yürüme klibi bu hızda çalar (garaj gerçek ölçekte çok büyük; ~0,35 m/sn sakin kedi yürüyüşü).
const WALK_SCALE: float = 1.35
const TURN_RATE: float = 6.0
## Zıplamada en yüksek tavan (birim; ~1,6 m — kedi daha yükseğe zıplamaz).
const MAX_JUMP: float = 0.37
const JUMP_AIR_TIME: float = 0.42

enum Mode { STILL, WALK, TURN, JUMP }

## KEDİ EŞYALARI (dekor, tools/decor/props_v10_kedi.py): kedinin konduğu noktalar eşyanın YEREL METRESİNDE
## (Blender ekseni: x sağ, y arka — ön −Y, z yükseklik), modelin ÖLÇEKSİZ tasarım ölçüsüyle; dışa aktarımda bütün
## eşya PET_FURNITURE_SCALE ile büyütülür (props_v10_kedi.py SCALE, kullanıcı kararı "kedi ×0,8, eşyalar ×1,25").
## Yatak: içinde kıvrılıp uyur; kule: tablaya, bazen direğin tepesindeki platforma çıkar; kap: önünde durup yer.
## Kullanıcı kararı: "kedi eşyaya gidip kullanır".
const PET_FURNITURE_SCALE: float = 1.25
const PET_FURNITURE: Dictionary = {
	&"cat_bed": {"kind": &"bed", "spots": [Vector3(0.0, 0.0, 0.086)]},
	&"lux_cat_bed": {"kind": &"bed", "spots": [Vector3(0.0, 0.0, 0.136)]},
	&"cat_tower": {"kind": &"tower", "spots": [Vector3(0.0, 0.0, 0.441), Vector3(0.36, 0.0, 0.903)]},
	&"lux_cat_tower": {"kind": &"tower", "spots": [Vector3(0.0, 0.0, 0.441), Vector3(0.36, 0.0, 0.903)]},
	&"cat_bowls": {"kind": &"bowl", "spots": [Vector3(-0.11, 0.015, 0.0)]},
	&"lux_cat_bowls": {"kind": &"bowl", "spots": [Vector3(-0.11, 0.0, 0.0)]},
	# Kedi eşyaları 2 (tools/decor/props_v11_kedi2.py; tünel / oyuncak sepeti / duvar basamakları yalnız süs)
	&"cat_box": {"kind": &"bed", "spots": [Vector3(0.0, 0.0, 0.03)]},
	&"cat_tire_bed": {"kind": &"bed", "spots": [Vector3(0.0, 0.0, 0.167)]},
	&"cat_hammock": {"kind": &"bed", "spots": [Vector3(0.0, 0.0, 0.202)]},
	&"cat_scratcher": {"kind": &"tower", "spots": [Vector3(0.0, 0.0, 0.577)]},
	&"cat_house": {"kind": &"tower", "spots": [Vector3(0.0, 0.02, 0.407)]},
	&"lux_cat_sakura": {"kind": &"tower", "spots": [Vector3(0.0, 0.0, 0.467), Vector3(0.38, 0.0, 0.973)]},
	&"cat_fountain": {"kind": &"bowl", "spots": [Vector3(0.0, 0.0, 0.0)]},
}
## Kabın önünde durma uzaklığı (m): baş kabın üstüne gelsin
const BOWL_STAND_M: float = 0.19
## Yatma pozlarında GÖVDENİN merkezi kedinin kendi noktasına göre (model metresi, kedinin yerel x / z'si; −z ileri).
## Kıvrılınca gövde ~10 cm yana, ~8 cm geriye kayıyor: yatağın ortasına atlayan kedi kenardan taşıyordu (kullanıcı
## 2026-10-31). Kedi, gövde ortaya gelecek noktaya iner. Ölçüm: tekir.glb klip ortası, kutu merkezi.
const POSE_CENTER: Dictionary = {&"sleep": Vector2(-0.096, 0.075), &"loaf": Vector2(0.014, -0.099),
	&"sit_idle": Vector2(0.023, -0.028)}
## Yol ızgarası dekor ızgarasının NAV_SUB katı ince. Küçük eşyalar (mama kabı ~0,08 birim) bir dekor gözünün (0,175)
## merkezine değmediği için engel sayılmıyordu, kedi içlerinden geçiyordu (kullanıcı 2026-10-31). Göz, (kedi
## yarıçapı kadar şişirilmiş) engele KISMEN bile giriyorsa kapalı.
const NAV_SUB: int = 3
const NAV_CELL: float = DecorGrid.CELL / NAV_SUB

## Garaj yuvası (0..PetManager.MAX_OUT-1); add_child'dan ÖNCE verilir.
var slot: int = 0
var _pets: PetManager
var _uid: String = ""         # yuvadaki hayvan (PetManager uid; "" = boş)
var _claim: String = ""       # gitmekte olduğu eşya / araç / kasa (öteki kedi aynısını seçmesin)
var _view: GarageDecorView
var _actor: PetActor
var _preview: StringName = &""
var _nav: AStarGrid2D
var _nav_dirty: bool = true
var _gen: int = 0
var _mode: Mode = Mode.STILL
var _path: PackedVector2Array = PackedVector2Array()
var _path_i: int = 0
var _turn_target: float = 0.0
var _jump: Dictionary = {}
var _roof: String = ""        # üstünde durduğu sergi aracının / kedi eşyasının iid'i ("" = zeminde)
var _perch_spot: int = 0      # kedi eşyasında hangi noktada (kule: 0 tabla, 1 direğin tepesi)
var _editing: bool = false    # GARAJI DÜZENLE açık: kedi gizli, işi durmuş
var _editor: GarageEditor
var _asleep: bool = false
var _busy_reaction: bool = false
var _in_closeup: bool = false
var _visitor: bool = false    # geliş sinematiğindeki (henüz sahiplenilmemiş) kedi
var _cu_gen: int = 0          # yakın kameradaki tek seferlik kliplerin kendi sayacı (yeni dokunuş eskisini keser)
var _cu_busy: bool = false
## Bekleyen rutinlerin (yürü / dön / zıpla / bekle) SceneTree'si: düğüm ağaçtan çıkınca get_tree() null olur.
## Dil değişince sahne baştan kurulur; eski sahne ağaçtan çıkarken yürüyen kedinin döngüsü bir kare daha uyanıp
## get_tree().process_frame'de çöküyordu (2026-11-01, İngilizceye geçince). Bekleme hep bu referansla yapılır.
var _tree: SceneTree
var _left_tree: bool = false


func _enter_tree() -> void:
	_tree = get_tree()
	if _left_tree and _actor != null and not _editing:
		_left_tree = false
		_restart()   # ağaca geri döndü: kesilen hayat yeniden başlar


## Ağaçtan çıkış (sahne yeniden kuruluyor): bütün rutinler kesilir — uyanan döngü sayaç değiştiği için hemen biter.
func _exit_tree() -> void:
	_left_tree = true
	_gen += 1
	_cu_gen += 1
	_mode = Mode.STILL


func _ready() -> void:
	add_to_group("pet_world")
	_setup.call_deferred()


func _setup() -> void:
	if GarageVisit.is_visiting():
		return   # arkadaş garajında kedi (yalnız görünür) — açık garaj verisine eklenince
	_pets = get_tree().get_first_node_in_group("pets") as PetManager
	_view = get_tree().get_first_node_in_group("garage_decor_view") as GarageDecorView
	if _pets == null or _view == null:
		return
	_pets.adopted.connect(func(_n: String) -> void: _sync())
	_pets.pets_changed.connect(_sync)
	_pets.accessories_changed.connect(_apply_accessories)
	_pets.fur_changed.connect(func(_f: StringName) -> void:
		if _actor and _uid != "":
			_actor.set_fur(_pets.fur_of(_uid)))
	var save: SaveManager = get_tree().get_first_node_in_group("save_manager") as SaveManager
	if save:
		save.game_loaded.connect(func(_ok: bool) -> void: _sync())
	_view.area_changed.connect(_mark_dirty)
	var decor: DecorManager = get_tree().get_first_node_in_group("decor") as DecorManager
	if decor:
		decor.placement_changed.connect(_on_decor_changed)
	_editor = get_tree().get_first_node_in_group("garage_editor") as GarageEditor
	if _editor:
		_editor.state_changed.connect(_on_editor_state)
	var bays: RepairBayManager = get_tree().get_first_node_in_group("repair_bays") as RepairBayManager
	if bays:
		bays.layout_changed.connect(_mark_dirty)
		bays.bays_changed.connect(_mark_dirty)
	var repairs: RepairManager = get_tree().get_first_node_in_group("repair_manager") as RepairManager
	if repairs:
		repairs.customer_stopped.connect(_on_customer)
		repairs.repair_ready.connect(_on_repair_ready)
	var crates: CrateManager = get_tree().get_first_node_in_group("crates") as CrateManager
	if crates:
		crates.crate_added.connect(_on_crate_added)
	_sync()


func _mark_dirty() -> void:
	_nav_dirty = true


## GARAJI DÜZENLE (kullanıcı 2026-10-31: "dekor koyarken kedinin üstüne koyabiliyorum, düzenleme ekranında kedi
## kaybolsun"): açılınca kedi gizlenir ve işi durur; kapanınca yol yeniden kurulur, kedi bir eşyanın içinde kaldıysa
## en yakın boş yere geçer, hayatına yeni yolla devam eder.
func _on_editor_state() -> void:
	if _editor == null or _actor == null:
		return
	if _editor.active and not _editing:
		_editing = true
		_gen += 1
		_cu_gen += 1
		_mode = Mode.STILL
		_actor.set_hidden(true)
	elif not _editor.active and _editing:
		_editing = false
		_nav_dirty = true
		_actor.set_hidden(false)
		if _roof != "":
			_on_decor_changed()
		if _roof == "" and not _cell_free(_ncell(_pos2())):
			var p: Vector2 = _nearest_free(_pos2())
			if p != Vector2.INF:
				_actor.global_position = Vector3(p.x, _floor_y(), p.y)
		_asleep = false
		_actor.set_shadow(Vector2.ONE)
		_restart(0.6)


func is_editing() -> bool:
	return _editing


## Dekor değişti: yol yeniden kurulur; kedinin üstünde durduğu eşya kaldırıldı / taşındıysa kedi yere iner.
func _on_decor_changed() -> void:
	_nav_dirty = true
	if _roof == "" or _actor == null:
		return
	var decor: DecorManager = get_tree().get_first_node_in_group("decor") as DecorManager
	var still: bool = decor != null and not decor.instance(_roof).is_empty()
	if still:
		for f: Dictionary in _furniture():
			if f["iid"] == _roof:
				var spot: Vector3 = (f["spots"] as Array)[mini(_perch_spot, (f["spots"] as Array).size() - 1)]
				still = spot.distance_to(_actor.global_position) < 0.03
	if not still:
		_roof = ""
		_perch_spot = 0
		_asleep = false
		_actor.set_shadow(Vector2.ONE)
		var p: Vector2 = _nearest_free(_pos2())
		if p == Vector2.INF:
			p = _random_free(_center(), 0.0, 9.0)
		_actor.global_position = Vector3(p.x, _floor_y(), p.y)
		_restart(0.3)


## Yuvanın hayvanı sahnede olsun: hayvan değiştiyse eskisi gider, yenisi gelir; görünüşü (tüy, giydikleri) tazelenir.
## Geliş sinematiğindeki (henüz sahibi olmayan) kedi silinmez, sahiplenilince bu yuvanın hayvanı olur. Yakın kameradayken
## kedi değişmez (kapanınca end_closeup yeniden eşitler).
func _sync() -> void:
	if _pets == null:
		return
	var want: String = _pets.pet_in_slot(slot)
	if _in_closeup:
		if _uid == "" and want != "":
			_uid = want   # gelişte ad verildi: sahnedeki kedi bu hayvan
			_apply_accessories()
		return
	if _actor != null and _uid != want and (_uid != "" or not _visitor):
		_despawn()
	_uid = want
	if _uid == "":
		return
	if _actor == null:
		_spawn()
	elif _mode == Mode.STILL and _visitor:
		_visitor = false   # geliş sinematiğindeki kedi sahiplenildi: hayatı başlar
		_restart()
	_apply_accessories()
	_actor.set_fur(_pets.fur_of(_uid))


## Yuvadaki hayvan eve gitti: sahneden kalkar, süren işi biter.
func _despawn() -> void:
	_gen += 1
	_cu_gen += 1
	_mode = Mode.STILL
	_roof = ""
	_claim = ""
	_perch_spot = 0
	_asleep = false
	_busy_reaction = false
	_actor.queue_free()
	_actor = null


func actor() -> PetActor:
	return _actor


## Bu yuvadaki hayvanın PetManager uid'i ("" = boş).
func pet_uid() -> String:
	return _uid


## Başka bir kedi bu eşyaya / araca / kasaya gidiyor ya da üstünde mi?
func _taken(iid: String) -> bool:
	for node: Node in get_tree().get_nodes_in_group("pet_world"):
		var other: PetWorld = node as PetWorld
		if other != null and other != self and other._actor != null and (other._roof == iid or other._claim == iid):
			return true
	return false


## QA / test: süren rutini kesip tek bir işi yaptırır (sonra hayat kaldığı yerden sürer).
func debug_do(act: StringName) -> void:
	if _actor == null:
		return
	_react(func(gen: int) -> bool: return await _do(act, gen))


## Hayatı durdurup kediyi bir yerde, bir yöne dönük, bir klipte tutar (yakın kamera / sinematik / QA). resume() sürdürür.
func hold(at: Vector2, yaw: float, clip: StringName = &"sit_idle") -> void:
	if _actor == null:
		return
	_gen += 1
	_mode = Mode.STILL
	_asleep = false
	_roof = ""
	_perch_spot = 0
	_actor.global_position = Vector3(at.x, _floor_y(), at.y)
	_actor.rotation.y = yaw
	_actor.play(clip, 0.0)


func resume() -> void:
	if _actor:
		_restart(0.3)


func is_asleep() -> bool:
	return _asleep


func on_roof() -> bool:
	return _roof != ""


func _spawn(at: Vector2 = Vector2.INF) -> void:
	_actor = PetActor.new()
	_actor.name = "Pet%d" % slot
	add_child(_actor)
	_actor.tapped.connect(func() -> void:
		if not _in_closeup:
			pet_tapped.emit())
	var p: Vector2 = at if at != Vector2.INF else _random_free(_center(), 0.0, 9.0)
	_actor.global_position = Vector3(p.x, _floor_y(), p.y)
	_actor.rotation.y = randf() * TAU
	_apply_accessories()
	_actor.set_fur(_pets.fur_of(_uid) if _pets and _uid != "" else PetManager.DEFAULT_FUR)
	_restart()


# --- Aksesuarlar --------------------------------------------------------------------------------

## Yakın kamerada rafta denenen (henüz alınmamış) aksesuar: kendi yuvasındakinin yerine geçici takılır. &"" = yok.
func set_accessory_preview(id: StringName) -> void:
	_preview = id
	_apply_accessories()


func accessory_preview() -> StringName:
	return _preview


func _apply_accessories() -> void:
	if _actor == null or _pets == null:
		return
	var ids: Array[StringName] = []
	for id: StringName in _pets.worn_of(_uid):
		if not PetManager.clashes(id, _preview):   # denenen, aynı yuvadakinin (ve çakışanın) yerine geçer
			ids.append(id)
	if _preview != &"" and not ids.has(_preview):
		ids.append(_preview)
	_actor.set_accessories(ids)


# --- Hayat döngüsü ----------------------------------------------------------------------------

## Süren rutini keser ve hayatı baştan başlatır.
func _restart(delay: float = 0.4) -> void:
	_gen += 1
	_mode = Mode.STILL
	_claim = ""
	_busy_reaction = false   # yakın kamera / düzenleyiciyle kesilen tepkinin bayrağı açık kalıyordu (bir daha tepki yok)
	if _editing:
		return   # düzenleyici kapanınca yeniden başlar
	_life(_gen, delay)


func _life(gen: int, delay: float) -> void:
	if not await _wait(delay, gen):
		return
	while gen == _gen and is_instance_valid(_actor):
		_claim = ""   # yarıda kalan işin eşyası bırakılır
		var act: StringName = _pick()
		activity_started.emit(act)
		var ok: bool = await _do(act, gen)
		activity_finished.emit(act, ok)
		if not ok and gen == _gen:
			await _wait(0.5, gen)


func _pick() -> StringName:
	var w: Dictionary = {&"wander": 30.0, &"sit": 18.0, &"loaf": 14.0, &"sleep": 8.0, &"sniff": 8.0, &"idle": 10.0}
	if _roof != "":
		return &"roof_rest"
	if not _display_cars().is_empty():
		w[&"roof"] = 12.0
	# Kedi eşyaları: varsa tercih edilir (uyku yerde değil yatakta)
	var have: Dictionary = {}
	for f: Dictionary in _furniture():
		have[f["kind"]] = true
	if have.has(&"bed"):
		w[&"bed"] = 22.0
		w[&"sleep"] = 2.0
	if have.has(&"tower"):
		w[&"tower"] = 16.0
	if have.has(&"bowl"):
		w[&"eat"] = 9.0
	var total: float = 0.0
	for k: StringName in w:
		total += float(w[k])
	var r: float = randf() * total
	for k: StringName in w:
		r -= float(w[k])
		if r <= 0.0:
			return k
	return &"wander"


func _do(act: StringName, gen: int) -> bool:
	match act:
		&"wander":
			return await _act_wander(gen)
		&"sit":
			return await _act_sit(gen)
		&"loaf":
			return await _act_loaf(gen)
		&"sleep":
			return await _act_sleep(gen)
		&"sniff":
			return await _once(&"sniff", gen)
		&"roof":
			return await _act_roof(gen)
		&"roof_rest":
			return await _act_roof_rest(gen)
		&"bed":
			return await _act_bed(gen)
		&"tower":
			return await _act_tower(gen)
		&"eat":
			return await _act_eat(gen)
		_:
			_actor.play(&"idle")
			return await _wait(randf_range(2.5, 6.0), gen)


func _act_wander(gen: int) -> bool:
	var target: Vector2 = _random_free(_pos2(), 0.35, 1.6)
	if not await _walk_to(target, gen):
		return false
	_actor.play(&"idle")
	return await _wait(randf_range(1.5, 4.0), gen)


func _act_sit(gen: int) -> bool:
	if not await _once(&"sit_down", gen):
		return false
	_actor.play(&"sit_idle")
	if not await _wait(randf_range(4.0, 9.0), gen):
		return false
	var r: float = randf()
	if r < 0.35:
		if not await _once(&"groom", gen):
			return false
	elif r < 0.55:
		if not await _once(&"scratch", gen):
			return false
	_actor.play(&"sit_idle")
	if not await _wait(randf_range(2.0, 6.0), gen):
		return false
	return await _once(&"stand_up", gen)


func _act_loaf(gen: int) -> bool:
	if not await _once(&"loaf_down", gen):
		return false
	_actor.play(&"loaf")
	if not await _wait(randf_range(6.0, 16.0), gen):
		return false
	if randf() < 0.5:
		if not await _doze(gen, randf_range(15.0, 40.0)):
			return false
	return await _once(&"loaf_up", gen)


func _doze(gen: int, seconds: float) -> bool:
	if not await _once(&"doze_down", gen):
		return false
	_asleep = true
	_actor.play(&"doze")
	var ok: bool = await _wait(seconds, gen)
	_asleep = false
	if not ok:
		return false
	if not await _once(&"doze_up", gen):
		return false
	_actor.play(&"loaf")
	return await _wait(randf_range(1.5, 3.0), gen)


func _act_sleep(gen: int) -> bool:
	if not await _turn_to(0.0, gen):   # yüz kameraya (bkz. sınıf açıklaması)
		return false
	if not await _once(&"sleep_down", gen):
		return false
	_asleep = true
	_actor.set_shadow(Vector2(1.25, 0.7))
	_actor.play(&"sleep")
	var ok: bool = await _wait(randf_range(40.0, 110.0), gen)
	_asleep = false
	_actor.set_shadow(Vector2.ONE)
	if not ok:
		return false
	return await _once(&"wake", gen)


# --- Sergideki aracın tavanı ---------------------------------------------------------------------

## Sergilenen araçlar (dekor "car:<id>"): iid → tavan ortası (dünya) ve taban dikdörtgeni.
func _display_cars() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var decor: DecorManager = get_tree().get_first_node_in_group("decor") as DecorManager
	if decor == null or _view == null:
		return out
	for inst: Dictionary in decor.instances():
		if not GarageDecor.is_vehicle(inst["item"]):
			continue
		var body: Node3D = _view.body_of(inst["iid"])
		var box: AABB = GarageDecorView._tree_box(body)
		if box.size == Vector3.ZERO:
			continue
		var roof_y: float = box.end.y
		if roof_y - _floor_y() > MAX_JUMP:
			continue
		var c: Vector3 = box.get_center()
		out.append({"iid": inst["iid"], "roof": Vector3(c.x, roof_y - 0.004, c.z),
			"rect": Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z))})
	return out


func _act_roof(gen: int) -> bool:
	var cars: Array[Dictionary] = _display_cars().filter(func(c: Dictionary) -> bool: return not _taken(c["iid"]))
	if cars.is_empty():
		return false
	var car: Dictionary = cars[randi() % cars.size()]
	var rect: Rect2 = car["rect"]
	var side: Vector2 = _free_near_rect(rect)
	if side == Vector2.INF:
		return false
	var iid: String = car["iid"]
	_claim = iid
	if not await _walk_to(side, gen):
		return false
	return await _jump_to(car["roof"], gen, func() -> void:
		_roof = iid
		_claim = "")


func _act_roof_rest(gen: int) -> bool:
	for f: Dictionary in _furniture():
		if f["iid"] == _roof:
			if f["kind"] == &"bed":
				return await _bed_rest(f, gen)
			return await _tower_rest(f, gen)
	if randf() < 0.45:
		if not await _turn_to(0.0, gen):
			return false
		if not await _once(&"sleep_down", gen):
			return false
		_asleep = true
		_actor.play(&"sleep")
		var ok: bool = await _wait(randf_range(30.0, 80.0), gen)
		_asleep = false
		if not ok or not await _once(&"wake", gen):
			return false
	else:
		if not await _once(&"loaf_down", gen):
			return false
		_actor.play(&"loaf")
		if not await _wait(randf_range(6.0, 14.0), gen):
			return false
		if randf() < 0.6 and not await _doze(gen, randf_range(15.0, 35.0)):
			return false
		if not await _once(&"loaf_up", gen):
			return false
	return await _jump_down(gen)


func _jump_down(gen: int) -> bool:
	var rect: Rect2 = Rect2()
	for c: Dictionary in _display_cars():
		if c["iid"] == _roof:
			rect = c["rect"]
	for f: Dictionary in _furniture():
		if f["iid"] == _roof:
			rect = f["rect"]
			if _perch_spot > 0:   # kulenin tepesinden önce tablaya
				if not await _jump_to((f["spots"] as Array)[0], gen, func() -> void: _perch_spot = 0):
					return false
	var land: Vector2 = _land_near(rect) if rect.size != Vector2.ZERO else _random_free(_pos2(), 0.1, 0.6)
	if land == Vector2.INF:
		land = _random_free(_pos2(), 0.1, 1.0)
	return await _jump_to(Vector3(land.x, _floor_y(), land.y), gen, func() -> void:
		_roof = ""
		_perch_spot = 0)


## Eşyanın / aracın yanında, kediye en yakın boş nokta; yoksa eşyaya en yakın boş göz.
func _land_near(rect: Rect2) -> Vector2:
	var p: Vector2 = _free_near_rect(rect)
	return p if p != Vector2.INF else _nearest_free(rect.get_center())


# --- Kedi eşyaları ----------------------------------------------------------------------------------

## Garajdaki kedi eşyaları: {iid, item, kind, spots (dünya), rect (taban, dünya)}. kind boşsa hepsi.
func _furniture(kind: StringName = &"") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var decor: DecorManager = get_tree().get_first_node_in_group("decor") as DecorManager
	if decor == null or _view == null:
		return out
	for inst: Dictionary in decor.instances():
		var item: StringName = StringName(inst["item"])
		if not PET_FURNITURE.has(item):
			continue
		var spec: Dictionary = PET_FURNITURE[item]
		if kind != &"" and spec["kind"] != kind:
			continue
		var model: Node3D = _furniture_model(inst["iid"])
		if model == null:
			continue
		var spots: Array[Vector3] = []
		for design: Vector3 in spec["spots"]:
			var sp: Vector3 = design * PET_FURNITURE_SCALE
			var w: Vector3 = model.global_transform * Vector3(sp.x, sp.z, -sp.y)   # Blender (x, y, z) → glTF (x, z, −y)
			if sp.z <= 0.0:
				w.y = _floor_y()
			spots.append(w)
		var box: AABB = GarageDecorView._tree_box(_view.body_of(inst["iid"]))
		var front: Vector3 = model.global_transform.basis.z   # Blender −Y (eşyanın önü) → glTF +Z
		out.append({"iid": inst["iid"], "item": item, "kind": spec["kind"], "spots": spots,
			"front": Vector2(front.x, front.z).normalized(),
			"rect": Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z))})
	return out


## Eşyanın glb kökü (gövde → ortalama tutucusu → model; toplu çizim düğümleri silmez, yalnız gizler).
func _furniture_model(iid: String) -> Node3D:
	var body: Node3D = _view.body_of(iid) if _view else null
	if body == null or body.get_child_count() == 0:
		return null
	var holder: Node3D = body.get_child(0) as Node3D
	if holder == null or holder.get_child_count() == 0:
		return null
	return holder.get_child(0) as Node3D


func _pick_furniture(kind: StringName) -> Dictionary:
	var list: Array[Dictionary] = _furniture(kind).filter(func(f: Dictionary) -> bool: return not _taken(f["iid"]))
	if list.is_empty():
		return {}
	var me: Vector2 = _pos2()
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["rect"] as Rect2).get_center().distance_to(me) < (b["rect"] as Rect2).get_center().distance_to(me))
	return list[0] if randf() < 0.7 or list.size() == 1 else list[randi() % list.size()]


## Eşyanın yanına yürüyüp noktasına zıplar (_roof = eşya).
func _climb(f: Dictionary, spot: int, gen: int, land: Vector3 = Vector3.INF) -> bool:
	var target: Vector3 = (f["spots"] as Array)[spot] if land == Vector3.INF else land
	var side: Vector2 = _land_near(f["rect"])
	if side == Vector2.INF:
		return false
	var iid: String = f["iid"]
	_claim = iid
	if not await _walk_to(side, gen):
		return false
	return await _jump_to(target, gen, func() -> void:
		_roof = iid
		_claim = ""
		_perch_spot = spot)


## Yatak: içine atlar, yüzü kameraya kıvrılıp uzun uyur (bazen tombul oturup uyuklar), uyanınca iner.
func _act_bed(gen: int) -> bool:
	var f: Dictionary = _pick_furniture(&"bed")
	if f.is_empty():
		return false
	var curl: bool = randf() < 0.7
	# Gövde yatağın ORTASINA gelsin: kedi, seçilen pozun gövde merkezi kadar kaydırılmış noktaya iner (yüz kameraya)
	if not await _climb(f, 0, gen, _settled((f["spots"] as Array)[0], &"sleep" if curl else &"loaf", 0.0)):
		return false
	return await _bed_rest(f, gen, curl)


## Yatakta dinlenme (yatağa yeni çıkınca da, kesilip yeniden başlayınca da): gövde ortaya gelecek noktaya kayar,
## yüzü kameraya döner; kıvrılıp uzun uyur ya da tombul oturup uyuklar; sonra iner.
func _bed_rest(f: Dictionary, gen: int, curl: bool = randf() < 0.7) -> bool:
	var at: Vector3 = _settled((f["spots"] as Array)[0], &"sleep" if curl else &"loaf", 0.0)
	if Vector2(at.x, at.z).distance_to(_pos2()) > 0.002 and not await _walk_direct(Vector2(at.x, at.z), gen):
		return false
	if not await _turn_to(0.0, gen):   # yüz kameraya (bkz. sınıf açıklaması)
		return false
	if curl:
		if not await _once(&"sleep_down", gen):
			return false
		_asleep = true
		_actor.set_shadow(Vector2(1.1, 0.65))
		_actor.play(&"sleep")
		var ok: bool = await _wait(randf_range(120.0, 300.0), gen)   # kullanıcı: "yatakta biraz daha uzun yatmalı"
		_asleep = false
		_actor.set_shadow(Vector2.ONE)
		if not ok or not await _once(&"wake", gen):
			return false
	else:
		if not await _once(&"loaf_down", gen):
			return false
		_actor.play(&"loaf")
		if not await _wait(randf_range(8.0, 15.0), gen):
			return false
		if not await _doze(gen, randf_range(60.0, 150.0)):
			return false
		if not await _once(&"loaf_up", gen):
			return false
	return await _jump_down(gen)


## Pozun gövde merkezi `center`a gelecek kedi noktası (yaw: kedinin yüzü, 0 = kameraya).
func _settled(center: Vector3, pose: StringName, yaw: float) -> Vector3:
	var o: Vector2 = POSE_CENTER.get(pose, Vector2.ZERO) * PetActor.METER
	var off: Vector3 = Basis(Vector3.UP, yaw) * Vector3(o.x, 0.0, o.y)
	return center - off


## Kule: tablaya çıkar; bazen direğin tepesindeki platforma da çıkıp garajı izler. Tablada yatar / uyuklar / uyur.
func _act_tower(gen: int) -> bool:
	var f: Dictionary = _pick_furniture(&"tower")
	if f.is_empty() or not await _climb(f, 0, gen):
		return false
	var spots: Array = f["spots"]
	if spots.size() > 1 and randf() < 0.45:
		if not await _wait(randf_range(0.6, 1.5), gen):
			return false
		if not await _jump_to(spots[1], gen, func() -> void: _perch_spot = 1):
			return false
	return await _tower_rest(f, gen)


## Kulede dinlenme: direğin tepesinde oturup izler; tablada gövde ortaya gelecek noktaya kayıp yatar / uyur.
func _tower_rest(f: Dictionary, gen: int) -> bool:
	var spots: Array = f["spots"]
	if _perch_spot > 0:
		if not await _turn_to(0.0, gen):
			return false
		if not await _once(&"sit_down", gen):
			return false
		_actor.play(&"sit_idle")
		if not await _wait(randf_range(8.0, 18.0), gen):
			return false
		if randf() < 0.4 and not await _once(&"groom", gen):
			return false
		if not await _once(&"stand_up", gen):
			return false
		return await _jump_down(gen)
	var curl: bool = randf() < 0.4
	var centered: Vector3 = _settled(spots[0], &"sleep" if curl else &"loaf", 0.0)
	if Vector2(centered.x, centered.z).distance_to(_pos2()) > 0.002 and not await _walk_direct(Vector2(centered.x,
			centered.z), gen):
		return false
	if not await _turn_to(0.0, gen):
		return false
	if curl:
		if not await _once(&"sleep_down", gen):
			return false
		_asleep = true
		_actor.play(&"sleep")
		var ok: bool = await _wait(randf_range(60.0, 150.0), gen)
		_asleep = false
		if not ok or not await _once(&"wake", gen):
			return false
	else:
		if not await _once(&"loaf_down", gen):
			return false
		_actor.play(&"loaf")
		if not await _wait(randf_range(8.0, 16.0), gen):
			return false
		if randf() < 0.6 and not await _doze(gen, randf_range(15.0, 40.0)):
			return false
		if not await _once(&"loaf_up", gen):
			return false
	return await _jump_down(gen)


## Kap: mama kabının ÖNÜNDEN ya da ARKASINDAN (eşyanın kısa kenarı; uzun kenardan gelince paspasa basıyordu) başı
## kabın üstüne gelecek kadar yaklaşıp yer; bazen ardından yalanır.
func _act_eat(gen: int) -> bool:
	var f: Dictionary = _pick_furniture(&"bowl")
	if f.is_empty():
		return false
	var food: Vector3 = (f["spots"] as Array)[0]
	var food2: Vector2 = Vector2(food.x, food.z)
	var reach: float = BOWL_STAND_M * PetActor.METER
	var stand: Vector2 = Vector2.INF
	var approach: Vector2 = Vector2.INF
	for side: Vector2 in [f["front"], -(f["front"] as Vector2)]:
		var s_pt: Vector2 = food2 + side * reach
		var a_pt: Vector2 = _nearest_free(food2 + side * (reach + NAV_CELL))
		if a_pt == Vector2.INF or not _view.area().floor_rect.has_point(s_pt):
			continue
		if stand == Vector2.INF or a_pt.distance_to(_pos2()) < approach.distance_to(_pos2()):
			stand = s_pt
			approach = a_pt
	if stand == Vector2.INF:
		return false
	_claim = f["iid"]   # yerken de kap ötekine kapalı (kesilirse _restart bırakır)
	if not await _walk_to(approach, gen):
		return false
	if not await _walk_direct(stand, gen):
		return false
	if not await _turn_to(_yaw_to(food2), gen):
		return false
	_actor.play(&"eat")
	if not await _wait(randf_range(6.0, 12.0), gen):
		return false
	if randf() < 0.5 and not await _once(&"groom", gen):
		return false
	var ok: bool = await _walk_direct(approach, gen)
	if gen == _gen:
		_claim = ""
	return ok


## Yol ızgarası dışında kısa düz yürüyüş (kabın önüne gelmek: kap ızgarada engel gözünde).
func _walk_direct(target: Vector2, gen: int) -> bool:
	_path = PackedVector2Array([target])
	_path_i = 0
	_mode = Mode.WALK
	_actor.play(&"walk", PetActor.BLEND, WALK_SCALE)
	while _mode == Mode.WALK and gen == _gen:
		await _tree.process_frame
	if gen != _gen:
		return false
	_actor.play(&"idle")
	return true


# --- Yakın kamera ---------------------------------------------------------------------------------

## Yakın kamerayı hazırlar. cam_dir: kediden kameraya (yatay) yön. Uyuyorsa gerinerek uyanır, tavandaysa iner, kamera
## tarafı kapalıysa birkaç adım boş bir yere yürür; oturup kameraya bakınca closeup_ready yayılır.
func begin_closeup(cam_dir: Vector3) -> void:
	if _actor == null:
		return
	_in_closeup = true
	_busy_reaction = false
	_gen += 1
	_mode = Mode.STILL
	_run_closeup(_gen, Vector2(cam_dir.x, cam_dir.z).normalized())


func _run_closeup(gen: int, dir: Vector2) -> void:
	if _asleep:
		_asleep = false
		_actor.set_shadow(Vector2.ONE)
		if _actor.current_clip() == &"doze":
			if not await _once(&"doze_up", gen) or not await _once(&"loaf_up", gen):
				return
		elif not await _once(&"wake", gen):   # kullanıcı kararı: uyanır, gerinip kalkar
			return
	elif _actor.current_clip() in [&"loaf", &"loaf_down"]:
		if not await _once(&"loaf_up", gen):
			return
	if _roof != "" and not await _jump_down(gen):
		return
	var spot: Vector2 = _closeup_spot(dir)
	if spot != Vector2.INF and spot.distance_to(_pos2()) > 0.04 and not await _walk_to(spot, gen):
		return
	if not await _turn_to(atan2(-dir.x, -dir.y), gen):
		return
	if not await _once(&"sit_down", gen):
		return
	_actor.play(&"sit_idle")
	if gen == _gen:
		closeup_ready.emit()


## Kameranın duracağı taraf (dir yönünde ~0,4 birim) boş olan, kediye en yakın göz.
func _closeup_spot(dir: Vector2) -> Vector2:
	if _nav_dirty:
		_rebuild_nav()
	var me: Vector2 = _pos2()
	var best: Vector2 = Vector2.INF
	var region: Rect2i = _nav.region
	for x: int in region.size.x:
		for y: int in region.size.y:
			var c: Vector2i = Vector2i(x, y)
			if _nav.is_point_solid(c):
				continue
			var q: Vector2 = _ncenter(c)
			if q.distance_to(me) > 1.2:
				continue
			if not _clear_line(q, q + dir * 0.4):
				continue
			if best == Vector2.INF or q.distance_to(me) < best.distance_to(me):
				best = q
	if best != Vector2.INF and best.distance_to(me) < 0.1 and _clear_line(me, me + dir * 0.4):
		return me
	return best


func end_closeup() -> void:
	_in_closeup = false
	_visitor = false
	_cu_gen += 1
	_cu_busy = false
	if _preview != &"":
		set_accessory_preview(&"")   # alınmadan çıkıldı: denenen aksesuar çıkar
	if _actor:
		_actor.set_eyes_shut(false)
		_restart(0.6)
	_sync()   # yakın kamera açıkken eve gönderilen / değişen hayvan


func in_closeup() -> bool:
	return _in_closeup


func closeup_busy() -> bool:
	return _cu_busy


## Yakın kamerada tek seferlik klip(ler), sonra döngü klibi (varsayılan oturuş). Yeni çağrı süreni keser.
func closeup_clips(clips: Array[StringName], then_loop: StringName = &"sit_idle") -> void:
	if _actor == null or not _in_closeup:
		return
	_cu_gen += 1
	_run_closeup_clips(_cu_gen, clips, then_loop)


func _run_closeup_clips(gen: int, clips: Array[StringName], then_loop: StringName) -> void:
	_cu_busy = true
	for clip: StringName in clips:
		if not _actor.has_clip(clip):
			continue
		_actor.play(clip, 0.16)
		await _tree.create_timer(maxf(_actor.clip_length(clip) - 0.06, 0.05), false).timeout
		if gen != _cu_gen or not _in_closeup:
			return
	_actor.play(then_loop, 0.2)
	_cu_busy = false


## Oltayı izlerken kedinin yüzünü yumuşakça çevirir (yakın kamera; yaw radyan).
func closeup_face(yaw: float, delta: float) -> void:
	if _actor and _in_closeup:
		_actor.rotation.y = rotate_toward(_actor.rotation.y, yaw, 3.0 * delta)


# --- Geliş sinematiği ---------------------------------------------------------------------------

## Henüz sahiplenilmemiş kediyi sokakta doğurur, garajın içindeki `to` noktasına yürütür, kameraya dönük oturtur
## (face_yaw); varınca visitor_arrived. Hayat döngüsü sahiplenilince başlar.
func spawn_visitor(from: Vector2, to: Vector2, face_yaw: float) -> void:
	if _actor == null:
		_actor = PetActor.new()
		_actor.name = "Tekir"
		add_child(_actor)
		_actor.tapped.connect(func() -> void:
			if not _in_closeup:
				pet_tapped.emit())
	_visitor = true
	_gen += 1
	_mode = Mode.STILL
	_actor.global_position = Vector3(from.x, _floor_y(), from.y)
	_actor.rotation.y = atan2(-(to - from).x, -(to - from).y)
	_run_visitor(_gen, to, face_yaw)


func _run_visitor(gen: int, to: Vector2, face_yaw: float) -> void:
	_path = PackedVector2Array([to])   # sokaktan doğrudan içeri (kaldırım yol ızgarasında değil)
	_path_i = 0
	_mode = Mode.WALK
	_actor.play(&"walk", PetActor.BLEND, WALK_SCALE)
	while _mode == Mode.WALK and gen == _gen:
		await _tree.process_frame
	if gen != _gen:
		return
	_actor.play(&"idle")
	if not await _wait(0.5, gen) or not await _turn_to(face_yaw, gen) or not await _once(&"sit_down", gen):
		return
	_actor.play(&"sit_idle")
	visitor_arrived.emit()


# --- Tepkiler -------------------------------------------------------------------------------

## Tepki seyrekliği (2026-10-31 uzun test: kalabalık garajda bir saatin 16 dakikası müşteriye koşmakla geçiyordu, yatağa
## giden kedi yolda kesiliyordu): müşteri / tamir tepkisi arasında en az REACT_COOLDOWN oyun saniyesi.
const REACT_COOLDOWN: float = 120.0
var _react_clock: float = 1000.0


func _can_react() -> bool:
	return _actor != null and not _asleep and _roof == "" and not _busy_reaction and not _in_closeup and not _editing


func _cooled() -> bool:
	return _react_clock >= REACT_COOLDOWN


func _on_customer(car: Node3D) -> void:
	if not _can_react() or not _cooled() or not is_instance_valid(car) or randf() > 0.35:
		return
	_react_clock = 0.0
	_react(func(gen: int) -> bool:
		var p: Vector2 = Vector2(car.global_position.x, car.global_position.z)
		var target: Vector2 = _nearest_free(_clamp_to_floor(p, 0.18))
		if not await _walk_to(target, gen):
			return false
		if not await _turn_to(_yaw_to(p), gen):
			return false
		if not await _once(&"sniff", gen):
			return false
		if not await _once(&"sit_down", gen):
			return false
		_actor.play(&"sit_idle")
		if not await _wait(randf_range(4.0, 7.0), gen):
			return false
		return await _once(&"stand_up", gen))


func _on_repair_ready(car: Node3D) -> void:
	if not _can_react() or not _cooled() or not is_instance_valid(car) or randf() > 0.4:
		return
	_react_clock = 0.0
	_react(func(gen: int) -> bool:
		var p: Vector2 = Vector2(car.global_position.x, car.global_position.z)
		var target: Vector2 = _random_free(p, 0.3, 0.6)
		if not await _walk_to(target, gen):
			return false
		if not await _turn_to(_yaw_to(p), gen):
			return false
		if not await _once(&"sit_down", gen):
			return false
		if not await _once(&"play_swat", gen):   # ₺ balonuna pati
			return false
		_actor.play(&"sit_idle")
		if not await _wait(2.5, gen):
			return false
		return await _once(&"stand_up", gen))


func _on_crate_added(uid: int) -> void:
	if not _can_react() or _taken("crate"):
		return   # öteki kedi kasaya çıkıyor
	_react(func(gen: int) -> bool:
		if not await _wait(3.5, gen):   # kasa yere otursun
			return false
		var delivery: CrateDelivery = get_tree().get_first_node_in_group("crate_delivery") as CrateDelivery
		var visual: Node3D = delivery.visual_of(uid) if delivery else null
		var box: AABB = GarageDecorView._tree_box(visual)
		if box.size == Vector3.ZERO or box.end.y - _floor_y() > MAX_JUMP:
			return false
		var rect: Rect2 = Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z))
		var side: Vector2 = _free_near_rect(rect)
		if side == Vector2.INF or _taken("crate"):
			return false
		_claim = "crate"
		if not await _walk_to(side, gen):
			return false
		var top: Vector3 = Vector3(box.get_center().x, box.end.y - 0.002, box.get_center().z)
		if not await _jump_to(top, gen, func() -> void:
				_roof = "crate"
				_claim = ""):   # kesilirse _jump_down rastgele iner
			return false
		if not await _once(&"sit_down", gen):
			return false
		_actor.play(&"sit_idle")
		if not await _wait(randf_range(5.0, 9.0), gen):
			return false
		if not await _once(&"stand_up", gen):
			return false
		var land: Vector2 = _free_near_rect(rect)
		if land == Vector2.INF:
			return false
		return await _jump_to(Vector3(land.x, _floor_y(), land.y), gen, func() -> void: _roof = ""))


func _react(routine: Callable) -> void:
	_gen += 1
	_mode = Mode.STILL
	var gen: int = _gen
	_busy_reaction = true
	_run_reaction(routine, gen)


func _run_reaction(routine: Callable, gen: int) -> void:
	await routine.call(gen)
	if gen == _gen:
		_busy_reaction = false
		_restart(0.2)


# --- Adımlar (hepsi kesintide false döner) ----------------------------------------------------------

func _wait(seconds: float, gen: int) -> bool:
	await _tree.create_timer(seconds, false).timeout
	return gen == _gen and is_instance_valid(_actor)


## Döngüsüz klibi baştan sona çalar.
func _once(clip: StringName, gen: int, speed: float = 1.0) -> bool:
	if gen != _gen or not _actor.has_clip(clip):
		return false
	_actor.play(clip, PetActor.BLEND, speed)
	return await _wait(maxf(_actor.clip_length(clip) / speed - 0.05, 0.05), gen)


func _walk_to(target: Vector2, gen: int) -> bool:
	var path: PackedVector2Array = _find_path(_pos2(), target)
	if path.is_empty():
		return false
	_path = path
	_path_i = 0
	_mode = Mode.WALK
	_actor.play(&"walk", PetActor.BLEND, WALK_SCALE)
	while _mode == Mode.WALK and gen == _gen:
		await _tree.process_frame
	if gen != _gen:
		return false
	_actor.play(&"idle")
	return true


func _turn_to(yaw: float, gen: int) -> bool:
	if absf(angle_difference(_actor.rotation.y, yaw)) < 0.12:
		return gen == _gen
	_turn_target = yaw
	_mode = Mode.TURN
	_actor.play(&"walk", PetActor.BLEND, 0.8)   # yerinde dönerken ayak adımı
	while _mode == Mode.TURN and gen == _gen:
		await _tree.process_frame
	if gen != _gen:
		return false
	_actor.play(&"idle")
	return true


## Zıplama: hazırlık klibi → yay (havada klibi) → iniş klibi. Hedef yüksekte de alçakta da olabilir. on_land: kedi
## hedefe VARDIĞI an çağrılır (yay bitti ya da kesilip hedefe konuldu) — "üstünde" bilgisi konumla hep birlikte değişsin
## (eskiden iniş klibinde kesilen kedi eşyanın yüksekliğinde kalıp _roof boş kalıyor, havada yürüyebiliyordu).
func _jump_to(target: Vector3, gen: int, on_land: Callable = Callable()) -> bool:
	var flat: Vector2 = Vector2(target.x, target.z)
	if not await _turn_to(_yaw_to(flat), gen):
		return false
	_actor.play(&"jump_start")
	if not await _wait(_actor.clip_length(&"jump_start") * 0.8, gen):
		return false
	var from: Vector3 = _actor.global_position
	var rise: float = maxf(target.y - from.y, 0.0)
	_jump = {"from": from, "to": target, "t": 0.0, "dur": JUMP_AIR_TIME + rise * 0.6, "h": 0.05 + rise * 0.35,
		"on_land": on_land, "landed": false}
	_mode = Mode.JUMP
	_actor.play(&"jump_air", 0.12)
	_actor.set_shadow(Vector2(0.6, 0.6))
	while _mode == Mode.JUMP and gen == _gen:
		await _tree.process_frame
	_actor.set_shadow(Vector2.ONE)
	if gen != _gen:
		if _actor.is_inside_tree():   # sahne yıkılırken (ağaç dışında) konum yazılamaz
			_actor.global_position = target   # kesilen zıplama havada kalmasın
			_land()
		return false
	_land()
	return await _once(&"jump_land", gen)


## Zıplama hedefe vardı: "üstünde" bilgisi tam o karede (yay biter bitmez) yazılır, bir kez.
func _land() -> void:
	if _jump.is_empty() or bool(_jump.get("landed", false)):
		return
	_jump["landed"] = true
	var cb: Callable = _jump.get("on_land", Callable())
	if cb.is_valid():
		cb.call()


func _process(delta: float) -> void:
	_react_clock += delta
	if _actor == null:
		return
	if _nav_dirty and _view:
		_rebuild_nav()
	match _mode:
		Mode.WALK:
			_step_walk(delta)
		Mode.TURN:
			_actor.rotation.y = rotate_toward(_actor.rotation.y, _turn_target, TURN_RATE * 0.7 * delta)
			if absf(angle_difference(_actor.rotation.y, _turn_target)) < 0.05:
				_mode = Mode.STILL
		Mode.JUMP:
			_step_jump(delta)


func _step_walk(delta: float) -> void:
	if _path_i >= _path.size():
		_mode = Mode.STILL
		return
	var pos: Vector2 = _pos2()
	var goal: Vector2 = _path[_path_i]
	var to: Vector2 = goal - pos
	var dist: float = to.length()
	if dist < 0.01:
		_path_i += 1
		return
	var want: float = atan2(-to.x, -to.y)
	_actor.rotation.y = rotate_toward(_actor.rotation.y, want, TURN_RATE * delta)
	var facing: float = absf(angle_difference(_actor.rotation.y, want))
	var speed: float = _actor.walk_speed(WALK_SCALE) * clampf(1.4 - facing, 0.15, 1.0)
	var step: float = minf(speed * delta, dist)
	var p: Vector2 = pos + to / dist * step
	_actor.global_position = Vector3(p.x, _actor.global_position.y, p.y)


func _step_jump(delta: float) -> void:
	_jump["t"] = float(_jump["t"]) + delta / float(_jump["dur"])
	var t: float = minf(float(_jump["t"]), 1.0)
	var from: Vector3 = _jump["from"]
	var to: Vector3 = _jump["to"]
	var p: Vector3 = from.lerp(to, t)
	p.y += float(_jump["h"]) * 4.0 * t * (1.0 - t)
	_actor.global_position = p
	if t >= 1.0:
		_mode = Mode.STILL
		_land()


# --- Yol ve zemin -------------------------------------------------------------------------------

func _floor_y() -> float:
	return _view.area().floor_y if _view else 0.0


func _pos2() -> Vector2:
	return Vector2(_actor.global_position.x, _actor.global_position.z)


func _center() -> Vector2:
	return _view.area().floor_rect.get_center()


func _yaw_to(p: Vector2) -> float:
	var d: Vector2 = p - _pos2()
	return atan2(-d.x, -d.y) if d.length() > 0.001 else _actor.rotation.y


func _clamp_to_floor(p: Vector2, inset: float) -> Vector2:
	var r: Rect2 = _view.area().floor_rect.grow(-inset)
	return Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))


func _rebuild_nav() -> void:
	_nav_dirty = false
	var area: DecorArea = _view.area()
	var cells: Vector2i = DecorGrid.lot_cells(_view.lot_rect()) * NAV_SUB
	_nav = AStarGrid2D.new()
	_nav.region = Rect2i(Vector2i.ZERO, cells)
	_nav.cell_size = Vector2.ONE
	_nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_nav.update()
	var inside: Rect2 = area.floor_rect.grow(-CAT_RADIUS)
	for x: int in cells.x:
		for y: int in cells.y:
			if not inside.has_point(_ncenter(Vector2i(x, y))):
				_nav.set_point_solid(Vector2i(x, y), true)
	# Dikdörtgen engeller (tamir alanı, kasa...) ve iç duvarlar: kedi yarıçapı kadar şişirilir, değdiği her göz kapalı.
	# İç duvar ızgara çizgisinde durur; ince ızgarada şişirilmiş duvar iki yanındaki gözlere de değer (yoldan geçilmez).
	for r: Rect2 in area.obstacles + area.wall_rects:
		_solid_rect(r.grow(CAT_RADIUS))
	var decor: DecorManager = get_tree().get_first_node_in_group("decor") as DecorManager
	if decor:
		for inst: Dictionary in decor.instances():
			if GarageDecor.placement(inst["item"]) == GarageDecor.PLACE_WALL:
				continue
			var poly: PackedVector2Array = _view.footprint(inst["item"], inst["pos"], float((inst["rot"] as Vector3).y))
			for grown: PackedVector2Array in Geometry2D.offset_polygon(poly, CAT_RADIUS):
				_solid_poly(grown)


func _ncell(p: Vector2) -> Vector2i:
	return Vector2i(floori((DecorGrid.CORNER.x - p.x) / NAV_CELL), floori((DecorGrid.CORNER.y - p.y) / NAV_CELL))


func _ncenter(c: Vector2i) -> Vector2:
	return DecorGrid.CORNER - (Vector2(c) + Vector2(0.5, 0.5)) * NAV_CELL


func _nrect(c: Vector2i) -> Rect2:
	var hi: Vector2 = DecorGrid.CORNER - Vector2(c) * NAV_CELL
	return Rect2(hi - Vector2(NAV_CELL, NAV_CELL), Vector2(NAV_CELL, NAV_CELL))


## Dikdörtgenin değdiği gözler (sınır kutusu aralığı).
func _cells_over(r: Rect2) -> Rect2i:
	var a: Vector2i = _ncell(r.position)
	var b: Vector2i = _ncell(r.end)
	var lo: Vector2i = Vector2i(mini(a.x, b.x), mini(a.y, b.y)).max(Vector2i.ZERO)
	var hi: Vector2i = Vector2i(maxi(a.x, b.x), maxi(a.y, b.y)).min(_nav.region.size - Vector2i.ONE)
	return Rect2i(lo, hi - lo + Vector2i.ONE)


func _solid_rect(r: Rect2) -> void:
	var span: Rect2i = _cells_over(r)
	for x: int in range(span.position.x, span.end.x):
		for y: int in range(span.position.y, span.end.y):
			if _nrect(Vector2i(x, y)).intersects(r):
				_nav.set_point_solid(Vector2i(x, y), true)


func _solid_poly(poly: PackedVector2Array) -> void:
	var box: Rect2 = Rect2(poly[0], Vector2.ZERO)
	for v: Vector2 in poly:
		box = box.expand(v)
	var span: Rect2i = _cells_over(box)
	for x: int in range(span.position.x, span.end.x):
		for y: int in range(span.position.y, span.end.y):
			var c: Vector2i = Vector2i(x, y)
			if _nav.is_point_solid(c):
				continue
			var r: Rect2 = _nrect(c)
			var cell: PackedVector2Array = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
				Vector2(r.position.x, r.end.y)])
			if not Geometry2D.intersect_polygons(cell, poly).is_empty():
				_nav.set_point_solid(c, true)


func _cell_free(c: Vector2i) -> bool:
	return _nav != null and _nav.is_in_boundsv(c) and not _nav.is_point_solid(c)


func _nearest_free(p: Vector2) -> Vector2:
	if _nav_dirty:
		_rebuild_nav()
	var c0: Vector2i = _ncell(p)
	if _cell_free(c0):
		return p
	for ring: int in range(1, 12):
		var best: Vector2 = Vector2.INF
		for dx: int in range(-ring, ring + 1):
			for dy: int in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var c: Vector2i = c0 + Vector2i(dx, dy)
				if _cell_free(c):
					var q: Vector2 = _ncenter(c)
					if best == Vector2.INF or q.distance_to(p) < best.distance_to(p):
						best = q
		if best != Vector2.INF:
			return best
	return Vector2.INF


## from çevresinde [min_r, max_r] uzaklıkta, yolu olan boş bir nokta (yoksa en yakın boş nokta).
func _random_free(from: Vector2, min_r: float, max_r: float) -> Vector2:
	if _nav_dirty:
		_rebuild_nav()
	var cands: Array[Vector2] = []
	var region: Rect2i = _nav.region
	for x: int in region.size.x:
		for y: int in region.size.y:
			var c: Vector2i = Vector2i(x, y)
			if _nav.is_point_solid(c):
				continue
			var q: Vector2 = _ncenter(c)
			var d: float = q.distance_to(from)
			if d >= min_r and d <= max_r:
				cands.append(q)
	if cands.is_empty():
		return _nearest_free(from)
	var jitter: Vector2 = Vector2(randf_range(-0.04, 0.04), randf_range(-0.04, 0.04))
	return cands[randi() % cands.size()] + jitter


## Dikdörtgenin (araç / kasa) hemen yanında boş bir nokta (zıplama yeri).
func _free_near_rect(rect: Rect2) -> Vector2:
	if _nav_dirty:
		_rebuild_nav()
	var best: Vector2 = Vector2.INF
	var region: Rect2i = _nav.region
	var me: Vector2 = _pos2()
	for x: int in region.size.x:
		for y: int in region.size.y:
			var c: Vector2i = Vector2i(x, y)
			if _nav.is_point_solid(c):
				continue
			var q: Vector2 = _ncenter(c)
			var edge: float = _rect_distance(rect, q)
			if edge > 0.22:
				continue
			if best == Vector2.INF or q.distance_to(me) < best.distance_to(me):
				best = q
	return best


static func _rect_distance(r: Rect2, p: Vector2) -> float:
	var dx: float = maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dy: float = maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return Vector2(dx, dy).length()


func _find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	if _nav_dirty:
		_rebuild_nav()
	var a: Vector2 = _nearest_free(from)
	var b: Vector2 = _nearest_free(to)
	if a == Vector2.INF or b == Vector2.INF:
		return PackedVector2Array()
	var ids: Array[Vector2i] = _nav.get_id_path(_ncell(a), _ncell(b))
	if ids.is_empty():
		return PackedVector2Array()
	var raw: PackedVector2Array = PackedVector2Array()
	for c: Vector2i in ids:
		raw.append(_ncenter(c))
	raw[raw.size() - 1] = to if _cell_free(_ncell(to)) else b
	# Görüş hattı olan ara noktaları atla (kedi göz göz zikzak çizmesin)
	var out: PackedVector2Array = PackedVector2Array()
	var anchor: Vector2 = from
	var i: int = 0
	while i < raw.size():
		var j: int = raw.size() - 1
		while j > i and not _clear_line(anchor, raw[j]):
			j -= 1
		out.append(raw[j])
		anchor = raw[j]
		i = j + 1
	return out


func _clear_line(a: Vector2, b: Vector2) -> bool:
	var steps: int = maxi(int(a.distance_to(b) / (NAV_CELL * 0.5)), 1)
	for k: int in range(1, steps + 1):
		if not _cell_free(_ncell(a.lerp(b, float(k) / steps))):
			return false
	return true
