class_name PetCloseupScreen
extends Control
## GARAJ DOSTLARI — YAKIN KAMERA (kullanıcı kararı 2026-10-31: taslak "C · Kedi kartı + olta oyunu"). Garajdaki kediye
## dokununca açılır; UiRouter'da PLACE "pet_closeup": oyun HUD'u gizlenir, dünya ve oyun sürer (tamirler / müşteriler).
##   - Kedi kamera tarafında oturur ve kameraya bakar (PetWorld.begin_closeup); kamera perspektif, kedi kadrajın SAĞINDA.
##   - SOL KART: ad (kalem → PetNameScreen), "turuncu tekir", DOSTLUK (sıradaki numaraya ilerleme), NUMARALAR (açılan:
##     YAP, kilitli: kaç sevgide), AKSESUAR rafı (dene → elmasla al → tak / çıkar), FOTOĞRAF ÇEK (logolu JPEG → galeri).
##   - Kediye DOKUN = sev (dokun-tepki): sevilme klibi, uçan kalpler, dostluk +1 (PetManager.pet bekleme süreli).
##   - OLTA (sağ alt, amber): parmakla gezdirilen tüy; kedi gözüyle izler, yakına gelince atlar / pati vurur.
##   - Sağ üst ✕ ve Android GERİ kapatır.
##   - SES (PetVoice, 2026-11-02): kedi YALNIZ burada sesli — kameraya dönünce selam miyavı, sevince mırlar (+ ara sıra
##     "mrrp"), numara / aksesuar / ad koymada sevinir, oltada tüye cıvıldar; kapanınca susar. Açıkken garaj müziği
##     GameMusic.PET_DB'ye iner (mırlama müziğin altında kalıyordu).
## GELİŞ (open_arrival): sinema şeritleri, kamera garaj ağzına, kedi sokaktan girip oturur, yakın kamera, ad ZORUNLU
## (PetNameScreen), sahiplenince kart açılır.

signal closed

const CARD_WIDTH: float = 300.0
const CAM_DISTANCE: float = 0.36 * PetActor.SIZE
const CAM_HEIGHT: float = 0.11 * PetActor.SIZE
const CAM_SIDE: float = 0.05 * PetActor.SIZE     # kediyi kadrajın sağına iter (sol kartın yeri)
const CAM_FOV: float = 34.0
const FADE: float = 0.18
## Olta: tüy parmağı bu yumuşaklıkla izler; kedinin atlaması için hız (px/sn) ve yakınlık (kedi yarıçapının katı).
const TOY_FOLLOW: float = 14.0
const POUNCE_SPEED: float = 380.0
const POUNCE_REACH: float = 1.7
const POUNCE_COOLDOWN: float = 1.4
## Aksesuar rafı: alınmamışa ilk dokunuş kediye DENETİR (fiyat "AL"a döner), ikinci dokunuş elmasla alır. Kaza ile
## çift dokunuş satın almasın diye iki dokunuş arasında en az bu kadar sn.
const BUY_GUARD: float = 0.35
const TRICK_NAMES: Dictionary = {&"trick_paw": "PATİ VER", &"trick_beg": "ARKA AYAKLAR", &"trick_roll": "YUVARLAN"}

var _pets: PetManager
var _world: PetWorld
var _router: UiRouter
var _name_screen: PetNameScreen
var _world_cam: Camera3D
var _cam: Camera3D
var _dir: Vector3 = Vector3(0.707, 0.0, 0.707)
var _ready_to_pet: bool = false
var _arrival: bool = false
var _closing: bool = false
var _play: bool = false
var _toy: Vector2 = Vector2.ZERO
var _toy_target: Vector2 = Vector2.ZERO
var _toy_speed: float = 0.0
var _pounce_wait: float = 0.0
var _dragging: bool = false
var _logo: Image
var _serial: int = 0

var _fade: ColorRect
var _bars: Array[ColorRect] = []
var _chrome: MarginContainer
var _card: PanelContainer
var _name_label: Label
var _friend_bar: _Bar
var _friend_label: Label
var _tricks: VBoxContainer
var _olta_button: PlateButton
var _hint: Label
var _toast: PanelContainer
var _toast_label: Label
var _hearts: Control
var _olta: _Olta
var _acc_slots: Dictionary = {}       # aksesuar kimliği → _AccSlot
var _armed: StringName = &""          # denenen (alınmamış) aksesuar
var _armed_msec: int = 0
var _voice: PetVoice


func _ready() -> void:
	name = "PetCloseupScreen"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_voice = PetVoice.new()
	add_child(_voice)
	set_process(false)


## Açıkken sahne yeniden kurulursa (dil değişimi vb.) kökteki müzik kısık kalmasın.
func _exit_tree() -> void:
	if visible:
		GameMusic.pet_closeup(get_tree(), false)


## Geliş sinematiğiyle açar (seviye ödülü; ad ekranı zorunlu).
func open_arrival() -> void:
	var router: UiRouter = get_tree().get_first_node_in_group("ui_router") as UiRouter
	if router == null or visible:
		return
	_arrival = true
	router.open(&"pet_closeup")


func open() -> void:
	_pets = get_tree().get_first_node_in_group("pets") as PetManager
	_world = get_tree().get_first_node_in_group("pet_world") as PetWorld
	_router = get_tree().get_first_node_in_group("ui_router") as UiRouter
	_world_cam = get_viewport().get_camera_3d()
	if _world_cam:
		var back: Vector3 = _world_cam.global_transform.basis.z
		back.y = 0.0
		if back.length() > 0.01:
			_dir = back.normalized()
	_closing = false
	_ready_to_pet = false
	_set_play(false)
	_chrome.visible = false
	_hint.text = ""
	_voice.begin()
	GameMusic.pet_closeup(get_tree(), true)
	show()
	set_process(true)
	if _arrival:
		_run_arrival()
	else:
		_start_closeup()


## Gelişte ad verilmeden çıkılmaz (UiRouter.back sorar).
func blocks_back() -> bool:
	return visible and _arrival and _pets != null and not _pets.is_adopted()


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	_voice.end()
	GameMusic.pet_closeup(get_tree(), false)
	_set_play(false)
	_armed = &""   # PetWorld.end_closeup denemeyi çıkarır
	var tween: Tween = create_tween()
	tween.tween_property(_fade, "color:a", 1.0, FADE)
	await tween.finished
	if _world_cam and is_instance_valid(_world_cam):
		_world_cam.current = true
	if is_instance_valid(_cam):
		_cam.queue_free()
	_cam = null
	for bar: ColorRect in _bars:
		bar.visible = false
	if _world:
		_world.end_closeup()
	_arrival = false
	hide()
	set_process(false)
	_fade.color.a = 0.0
	_closing = false
	closed.emit()


func _start_closeup() -> void:
	if _world == null or _world.actor() == null:
		close.call_deferred()
		return
	await _cut_to_close_camera()
	if not visible:
		return
	_world.begin_closeup(_dir)
	_refresh_card()
	_chrome.visible = true
	_hint.text = Loc.t("Sevmek için kediye dokun")
	await _world.closeup_ready
	_ready_to_pet = true
	_voice.greet(0.2)


func _cut_to_close_camera() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_fade, "color:a", 1.0, FADE)
	await tween.finished
	if not is_instance_valid(_cam):
		_cam = Camera3D.new()
		_cam.name = "PetCloseupCamera"
		_cam.fov = CAM_FOV
		_cam.near = 0.005
		_cam.far = 60.0
		var host: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
		host.add_child(_cam)
	_frame_cat(1.0)
	_cam.current = true
	var back: Tween = create_tween()
	back.tween_property(_fade, "color:a", 0.0, FADE)


## Kamera kediyi izler (kedi yerine yürürken / yuvarlanırken); t = 1 anında, küçük değer yumuşak.
func _frame_cat(t: float) -> void:
	if not is_instance_valid(_cam) or _world == null or _world.actor() == null:
		return
	var cat: Vector3 = _world.actor().global_position
	var side: Vector3 = _dir.cross(Vector3.UP).normalized()
	var want: Vector3 = cat + _dir * CAM_DISTANCE + Vector3(0.0, CAM_HEIGHT, 0.0) + side * CAM_SIDE
	_cam.global_position = _cam.global_position.lerp(want, t) if t < 1.0 else want
	_cam.look_at(cat + Vector3(0.0, 0.045 * PetActor.SIZE, 0.0) + side * CAM_SIDE, Vector3.UP)


func _process(delta: float) -> void:
	if _closing:
		return
	if _world and _world.actor() and is_instance_valid(_cam) and _cam.current:
		_frame_cat(minf(delta * 4.0, 1.0))
	if _play:
		_step_play(delta)


# --- Dokunma ----------------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if not _ready_to_pet:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb: InputEventMouseButton = event
		if _play:
			_dragging = mb.pressed
			if mb.pressed:
				_toy_target = mb.position
			accept_event()
			return
		if mb.pressed and _hits_cat(mb.position):
			_pet()
			accept_event()
	elif event is InputEventMouseMotion and _play and _dragging:
		_toy_target = (event as InputEventMouseMotion).position
		accept_event()


func _cat_screen() -> Dictionary:
	var actor: PetActor = _world.actor()
	var cat: Vector3 = actor.global_position + Vector3(0.0, 0.05 * PetActor.SIZE, 0.0)
	var side: Vector3 = _dir.cross(Vector3.UP).normalized()
	var c: Vector2 = _cam.unproject_position(cat)
	var r: float = c.distance_to(_cam.unproject_position(cat + side * 0.09 * PetActor.SIZE))
	var head: Vector2 = _cam.unproject_position(actor.head_point())
	return {"center": c, "radius": r, "head": head}


func _hits_cat(pos: Vector2) -> bool:
	if not is_instance_valid(_cam) or _world == null or _world.actor() == null:
		return false
	var s: Dictionary = _cat_screen()
	return pos.distance_to(s["center"]) <= float(s["radius"]) * 1.35


func _pet() -> void:
	_world.closeup_clips([&"pet"])
	_spawn_hearts(_cat_screen()["head"])
	_voice.petted()
	_count_love()


## Sevgi puanı (sevme / olta atlayışı): sayıldıysa kart tazelenir. Günlük sınır (PetManager.DAILY_LOVE) dolunca
## HİÇBİR şey söylenmez — kullanıcı kararı (2026-10-31): "bitince belirtmeyelim, kendi fark etsin"; çubuk ilerlemez.
func _count_love() -> void:
	if _pets and _pets.pet():
		_refresh_card()


func _spawn_hearts(at: Vector2) -> void:
	for i: int in 3:
		var heart: HudIcon = HudIcon.new()
		heart.kind = HudIcon.Kind.HEART
		heart.custom_minimum_size = Vector2(44.0, 44.0) * (1.0 - i * 0.2)
		heart.size = heart.custom_minimum_size
		heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
		heart.position = at + Vector2(randf_range(-34.0, 34.0), randf_range(-24.0, 0.0)) - heart.size * 0.5
		heart.scale = Vector2(0.4, 0.4)
		heart.pivot_offset = heart.size * 0.5
		_hearts.add_child(heart)
		var tween: Tween = heart.create_tween().set_parallel(true)
		tween.tween_property(heart, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
			.set_delay(i * 0.1)
		tween.tween_property(heart, "position:y", heart.position.y - randf_range(50.0, 80.0), 1.5 + i * 0.2) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE).set_delay(i * 0.1)
		tween.tween_property(heart, "modulate:a", 0.0, 0.5).set_delay(1.0 + i * 0.15)
		tween.chain().tween_callback(heart.queue_free)


# --- Olta -------------------------------------------------------------------------------------

func _set_play(on: bool) -> void:
	_play = on
	_dragging = false
	if _olta:
		_olta.visible = on
	if _olta_button:
		_olta_button.highlight = on
	if not _ready_to_pet or _world == null:
		return
	if on:
		var s: Dictionary = _cat_screen()
		_toy = s["head"] + Vector2(-90.0, -60.0)
		_toy_target = _toy
		_world.closeup_clips([&"play_enter"], &"play_crouch")
		_voice.hunt(true)
		_hint.text = Loc.t("Parmağını sürükle, oltayı gezdir")
	else:
		_world.closeup_clips([&"play_exit"], &"sit_idle")
		_hint.text = Loc.t("Sevmek için kediye dokun")


func _step_play(delta: float) -> void:
	var before: Vector2 = _toy
	_toy = _toy.lerp(_toy_target, minf(delta * TOY_FOLLOW, 1.0))
	_toy_speed = lerpf(_toy_speed, before.distance_to(_toy) / maxf(delta, 0.001), minf(delta * 8.0, 1.0))
	_olta.toy = _toy
	_olta.queue_redraw()
	if not is_instance_valid(_cam) or _world == null or _world.actor() == null:
		return
	# Kedi tüye döner: tüyü kedinin içinden geçen, kameraya bakan düşey düzleme düşür; yatayda sağa-sola izler
	var cat: Vector3 = _world.actor().global_position
	var on_plane: Variant = Plane(_dir, cat).intersects_ray(_cam.project_ray_origin(_toy), _cam.project_ray_normal(_toy))
	var base: float = atan2(-_dir.x, -_dir.z)
	if on_plane is Vector3:
		var side: Vector3 = _dir.cross(Vector3.UP).normalized()
		var lateral: float = ((on_plane as Vector3) - cat).dot(side)
		var want: float = base - atan2(lateral, 0.12)
		want = base + clampf(angle_difference(base, want), -0.9, 0.9)
		_world.closeup_face(want, delta)
	_pounce_wait -= delta
	if _pounce_wait > 0.0 or _world.closeup_busy():
		return
	var s: Dictionary = _cat_screen()
	var near: bool = _toy.distance_to(s["head"]) < float(s["radius"]) * POUNCE_REACH * 2.0
	if near and _toy_speed > POUNCE_SPEED:
		_pounce_wait = POUNCE_COOLDOWN
		var high: bool = _toy.y < (s["head"] as Vector2).y - float(s["radius"]) * 0.6
		_world.closeup_clips([&"play_swat" if high else &"play_pounce"], &"play_crouch")
		_voice.hunt(false)
		_count_love()


# --- Kart -------------------------------------------------------------------------------------

func _refresh_card() -> void:
	if _pets == null:
		return
	_name_label.text = _pets.pet_name().to_upper() if _pets.is_adopted() else Loc.t("TEKİR")
	var next: Dictionary = _pets.next_trick()
	var points: int = _pets.friendship()
	if next.is_empty():
		_friend_bar.value = 1.0
		_friend_label.text = str(points)
	else:
		_friend_bar.value = clampf(float(points) / float(next["points"]), 0.0, 1.0)
		_friend_label.text = "%d / %d" % [points, int(next["points"])]
	for c: Node in _tricks.get_children():
		c.queue_free()
	for t: Dictionary in PetManager.TRICKS:
		var id: StringName = t["id"]
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 6)
		row.custom_minimum_size = Vector2(0.0, 40.0)
		var label: Label = _label(&"HudInkValue", Loc.t(String(TRICK_NAMES.get(id, String(id)))))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if _pets.is_trick_unlocked(id):
			row.add_child(label)
			var go: PlateButton = PlateButton.new()
			go.theme_type_variation = &"HudPlateSmall"
			go.text = Loc.t("YAP")
			go.highlight = true
			go.focus_mode = Control.FOCUS_NONE
			go.pressed.connect(func() -> void:
				if _ready_to_pet and not _play and not _world.closeup_busy():
					_world.closeup_clips([id])
					_voice.happy(0.4))
			row.add_child(go)
		else:
			var lock: HudIcon = HudIcon.new()
			lock.kind = HudIcon.Kind.LOCK
			lock.custom_minimum_size = Vector2(18.0, 18.0)
			lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(lock)
			row.add_child(label)
			label.modulate.a = 0.7
			row.add_child(_label(&"HudInkCaption", Loc.t("%d SEVGİDE") % int(t["points"])))
		_tricks.add_child(row)
	_refresh_shelf()


# --- Aksesuar rafı ------------------------------------------------------------------------------

func _refresh_shelf() -> void:
	if _pets == null:
		return
	for id: StringName in _acc_slots:
		var slot: _AccSlot = _acc_slots[id]
		if _pets.is_worn(id):
			slot.state = _AccSlot.State.WORN
		elif _pets.owns_accessory(id):
			slot.state = _AccSlot.State.OWNED
		elif _armed == id:
			slot.state = _AccSlot.State.ARMED
		else:
			slot.state = _AccSlot.State.LOCKED


## Raf yuvasına dokunuldu. Sahip olunan: tak / çıkar. Alınmamış: ilk dokunuş dener, aynı yuvaya ikinci dokunuş alır
## (elmas yetmezse MARKET açılır, deneme sürer).
func _on_accessory(id: StringName) -> void:
	if _pets == null or _world == null or not _ready_to_pet or _closing:
		return
	if _pets.owns_accessory(id):
		_disarm()
		_pets.toggle_accessory(id)
		_refresh_shelf()
		return
	var info: Dictionary = PetManager.accessory(id)
	var cost: int = int(info.get("gems", 0))
	var now: int = Time.get_ticks_msec()
	if _armed != id:
		_armed = id
		_armed_msec = now
		_world.set_accessory_preview(id)
		_refresh_shelf()
		_show_toast(Loc.t("%s · %d GEM · ALMAK İÇİN BİR DAHA DOKUN") % [Loc.t(String(info["name"])), cost])
		return
	if now - _armed_msec < int(BUY_GUARD * 1000.0):
		return
	var player: PlayerProgress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress
	if player == null or not player.can_afford_gems(cost):
		_show_toast(Loc.t("GEM YETMİYOR\n%d GEM gerekiyor, %d GEM'in var.") % [cost, player.gems if player else 0])
		if _router:
			_router.open(&"gem_store")
		return
	if _pets.buy_accessory(id):
		_armed = &""
		_world.set_accessory_preview(&"")
		_refresh_shelf()
		_show_toast(Loc.t("%s TAKILDI!") % Loc.t(String(info["name"])))
		if is_instance_valid(_cam) and _world.actor():
			_spawn_hearts(_cat_screen()["head"])
		_voice.happy(0.2)


func _disarm() -> void:
	if _armed == &"":
		return
	_armed = &""
	if _world:
		_world.set_accessory_preview(&"")


func _rename() -> void:
	if _name_screen == null or _pets == null or not _pets.is_adopted():
		return
	_name_screen.mandatory = false
	_name_screen.start_name = _pets.pet_name()
	_router.open(&"pet_name")


func _on_named(pet_name: String) -> void:
	if _pets == null:
		return
	var first: bool = not _pets.is_adopted()
	_pets.adopt(pet_name)
	_refresh_card()
	if first:
		_finish_arrival(pet_name)


# --- Fotoğraf ---------------------------------------------------------------------------------

func _photo() -> void:
	if not _ready_to_pet:
		return
	_chrome.visible = false
	_hint.visible = false
	await RenderingServer.frame_post_draw
	_chrome.visible = true
	_hint.visible = true
	var shot: Image = get_viewport().get_texture().get_image()
	if _logo == null:
		_logo = PhotoCapture.load_logo()
	var logo: Image = _logo
	var out: Array = []
	var task: int = WorkerThreadPool.add_task(func() -> void: out.append(PhotoCapture.render_jpeg(shot, logo)))
	while not WorkerThreadPool.is_task_completed(task) and is_inside_tree():
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	if not is_inside_tree():
		return   # sahne yeniden kurulurken (dil / hesap) ağaçtan çıkıldı: get_tree() null, döngü beklemeden dönerdi
	var bytes: PackedByteArray = out[0] if out.size() > 0 else PackedByteArray()
	if GallerySaver.needs_legacy_permission():
		OS.request_permission(GallerySaver.LEGACY_PERMISSION)
		_show_toast(Loc.t("GALERİYE KAYDETMEK İÇİN İZİN GEREKİYOR"))
		return
	_serial += 1
	var result: Dictionary = GallerySaver.save_jpeg(bytes, PhotoCapture.file_name(Time.get_datetime_dict_from_system(), _serial))
	if bool(result.get("ok", false)):
		var missions: MissionManager = get_tree().get_first_node_in_group("missions") as MissionManager
		if missions:
			missions.count(&"photos")
		_show_toast(Loc.t("GALERİYE KAYDEDİLDİ"))
	else:
		_show_toast(Loc.t("FOTOĞRAF KAYDEDİLEMEDİ"))


func _show_toast(text: String) -> void:
	_toast_label.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	var tween: Tween = _toast.create_tween()
	tween.tween_interval(1.6)
	tween.tween_property(_toast, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func() -> void: _toast.visible = false)


# --- Geliş sinematiği ------------------------------------------------------------------------------

func _run_arrival() -> void:
	var view: GarageDecorView = get_tree().get_first_node_in_group("garage_decor_view") as GarageDecorView
	if _world == null or view == null:
		_arrival = false
		close.call_deferred()
		return
	for bar: ColorRect in _bars:
		bar.visible = true
	var floor_rect: Rect2 = view.area().floor_rect
	var door_in: Vector2 = _world._nearest_free(Vector2(floor_rect.get_center().x, floor_rect.end.y - 0.32))
	if door_in == Vector2.INF:
		door_in = floor_rect.get_center()
	var door_out: Vector2 = Vector2(door_in.x + 0.12, floor_rect.end.y + 0.42)
	var face: float = atan2(-_dir.x, -_dir.z)
	_world.spawn_visitor(door_out, door_in, face)
	var wc: WorldCamera = _world_cam as WorldCamera
	var arrived: Array[bool] = [false]
	_world.visitor_arrived.connect(func() -> void: arrived[0] = true, CONNECT_ONE_SHOT)
	var until: int = Time.get_ticks_msec() + 12000
	# is_inside_tree: sahne yeniden kurulurken ağaçtan çıkılırsa döngü 12 sn beklemeden dönüp oyunu donduruyordu
	while not arrived[0] and Time.get_ticks_msec() < until and visible and is_inside_tree():
		if wc and _world.actor():
			var p: Vector3 = _world.actor().global_position
			wc.follow(Vector3(p.x, 0.0, p.z - 0.15), 1.0)
		await get_tree().process_frame
	if not is_inside_tree():
		return
	await get_tree().create_timer(0.9).timeout
	if not visible or not is_inside_tree():
		return
	await _cut_to_close_camera()
	_world.begin_closeup(_dir)
	await _world.closeup_ready
	_voice.greet(0.2)
	_name_screen.mandatory = true
	_name_screen.start_name = ""
	_router.open(&"pet_name")


func _finish_arrival(pet_name: String) -> void:
	for bar: ColorRect in _bars:
		bar.visible = false
	_arrival = false
	_refresh_card()
	_chrome.visible = true
	_ready_to_pet = true
	_hint.text = Loc.t("Sevmek için kediye dokun")
	_show_toast(Loc.t("%s ARTIK SENİN DOSTUN!") % pet_name.to_upper())
	_voice.happy(0.4)


# --- Kurulum ----------------------------------------------------------------------------------

## Krem plaka zemini (kart, ad satırı): temadaki plakanın düz hâli.
static func plate_box() -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = HudPalette.PLATE
	box.border_color = HudPalette.PLATE_EDGE
	box.set_border_width_all(2)
	box.border_width_bottom = 5
	box.set_corner_radius_all(10)
	box.shadow_color = HudPalette.SHADOW
	box.shadow_size = 6
	box.shadow_offset = Vector2(0.0, 3.0)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	return box


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _build() -> void:
	_olta = _Olta.new()
	_olta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_olta.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_olta.visible = false
	add_child(_olta)
	_hearts = Control.new()
	_hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hearts.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_hearts)
	# Sinema şeritleri (geliş)
	for top: bool in [true, false]:
		var bar: ColorRect = ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		bar.custom_minimum_size = Vector2(0.0, 56.0)
		if not top:
			bar.offset_top = -56.0
		bar.visible = false
		add_child(bar)
		_bars.append(bar)

	_chrome = MarginContainer.new()
	_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		_chrome.add_theme_constant_override(side, 14)
	add_child(_chrome)
	var layout: HBoxContainer = HBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chrome.add_child(layout)
	_build_card(layout)
	var spacer: Control = Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer)
	var right: VBoxContainer = VBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(right)
	var close_button: PlateButton = PlateButton.new()
	close_button.shape = PlateButton.Shape.ROUND
	close_button.theme_type_variation = &"HudSign"
	close_button.kind = HudIcon.Kind.CROSS
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_button.pressed.connect(func() -> void:
		if _router and not blocks_back():
			_router.back())
	right.add_child(close_button)
	var gap: Control = Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(gap)
	_olta_button = PlateButton.new()
	_olta_button.shape = PlateButton.Shape.ROUND
	_olta_button.theme_type_variation = &"HudSign"
	_olta_button.custom_minimum_size = Vector2(84.0, 84.0)
	_olta_button.focus_mode = Control.FOCUS_NONE
	_olta_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_olta_button.pressed.connect(func() -> void:
		if _ready_to_pet:
			_set_play(not _play))
	var rod: _RodIcon = _RodIcon.new()
	rod.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rod.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_olta_button.add_child(rod)
	right.add_child(_olta_button)

	var bottom: VBoxContainer = VBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bottom.alignment = BoxContainer.ALIGNMENT_END
	add_child(bottom)
	_hint = _label(&"HudOutlined", "")
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override(&"font_size", 18)
	var hint_margin: MarginContainer = MarginContainer.new()
	hint_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_margin.add_theme_constant_override(&"margin_left", int(CARD_WIDTH) + 30)
	hint_margin.add_theme_constant_override(&"margin_right", 110)
	hint_margin.add_theme_constant_override(&"margin_bottom", 22)
	hint_margin.add_child(_hint)
	bottom.add_child(hint_margin)

	var top_box: VBoxContainer = VBoxContainer.new()
	top_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(top_box)
	var toast_margin: MarginContainer = MarginContainer.new()
	toast_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_margin.add_theme_constant_override(&"margin_top", 18)
	toast_margin.add_theme_constant_override(&"margin_left", int(CARD_WIDTH) + 30)
	top_box.add_child(toast_margin)
	_toast = PanelContainer.new()
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.add_theme_stylebox_override(&"panel", plate_box())
	_toast.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_toast.visible = false
	_toast_label = _label(&"HudInkValue", "")
	_toast.add_child(_toast_label)
	toast_margin.add_child(_toast)

	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)

	_name_screen = PetNameScreen.new()
	_name_screen.named.connect(_on_named)


## Ad ekranı ayrı bir MODAL'dır: Hud kurarken kendi ekran katmanına ekler ve kaydeder.
func name_screen() -> PetNameScreen:
	return _name_screen


func _build_card(parent: Control) -> void:
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override(&"panel", plate_box())
	_card.custom_minimum_size = Vector2(CARD_WIDTH, 0.0)
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(_card)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 6)
	_card.add_child(col)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 8)
	col.add_child(head)
	_name_label = _label(&"HudPlateTitle", "")
	_name_label.add_theme_font_size_override(&"font_size", 24)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.clip_text = true
	head.add_child(_name_label)
	var rename: PlateButton = PlateButton.new()
	rename.shape = PlateButton.Shape.ROUND
	rename.theme_type_variation = &"HudSignSmall"
	rename.kind = HudIcon.Kind.LETTERS
	rename.focus_mode = Control.FOCUS_NONE
	rename.pressed.connect(_rename)
	head.add_child(rename)
	col.add_child(_label(&"HudInkCaption", Loc.t("Turuncu tekir · garajın kedisi")))

	col.add_child(_label(&"HudInkCaption", Loc.t("DOSTLUK")))
	var friend: HBoxContainer = HBoxContainer.new()
	friend.add_theme_constant_override(&"separation", 6)
	col.add_child(friend)
	var heart: HudIcon = HudIcon.new()
	heart.kind = HudIcon.Kind.HEART
	heart.custom_minimum_size = Vector2(20.0, 20.0)
	heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	friend.add_child(heart)
	_friend_bar = _Bar.new()
	_friend_bar.custom_minimum_size = Vector2(0.0, 16.0)
	_friend_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_friend_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	friend.add_child(_friend_bar)
	_friend_label = _label(&"HudInkValue", "")
	friend.add_child(_friend_label)

	col.add_child(_label(&"HudInkCaption", Loc.t("NUMARALAR")))
	_tricks = VBoxContainer.new()
	_tricks.add_theme_constant_override(&"separation", 2)
	col.add_child(_tricks)

	col.add_child(_label(&"HudInkCaption", Loc.t("AKSESUAR")))
	var shelf: HBoxContainer = HBoxContainer.new()
	shelf.add_theme_constant_override(&"separation", 6)
	col.add_child(shelf)
	for acc: Dictionary in PetManager.ACCESSORIES:
		var id: StringName = acc["id"]
		var slot: _AccSlot = _AccSlot.new()
		slot.setup(load("res://assets/pets/acc/icon_%s.png" % id) as Texture2D, int(acc["gems"]))
		slot.tooltip_text = Loc.t(String(acc["name"]))
		slot.pressed.connect(_on_accessory.bind(id))
		shelf.add_child(slot)
		_acc_slots[id] = slot

	var fill: Control = Control.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(fill)
	var photo: PlateButton = PlateButton.new()
	photo.theme_type_variation = &"HudPlate"
	photo.kind = HudIcon.Kind.CAMERA
	photo.icon_left = true
	photo.text = Loc.t("FOTOĞRAF ÇEK")
	photo.focus_mode = Control.FOCUS_NONE
	photo.pressed.connect(_photo)
	col.add_child(photo)


## Aksesuar yuvası (taslak C): krem kutu + modelin küçük resmi + altta durum. Kilitli: elmas fiyatı; denenen:
## mavi (elmas) kutu, SATIN AL; sahip olunan: GİY; takılı: amber kutu, ÜSTÜNDE.
class _AccSlot extends Button:
	enum State { LOCKED, ARMED, OWNED, WORN }

	var state: State = State.LOCKED:
		set(v):
			state = v
			_apply()
	var _price: int = 0
	var _pic: TextureRect
	var _gem: HudIcon
	var _caption: Label

	func setup(tex: Texture2D, price: int) -> void:
		_price = price
		custom_minimum_size = Vector2(56.0, 66.0)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		focus_mode = Control.FOCUS_NONE
		var col: VBoxContainer = VBoxContainer.new()
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		col.offset_left = 3.0
		col.offset_right = -3.0
		col.offset_top = 3.0
		col.offset_bottom = -3.0
		col.add_theme_constant_override(&"separation", 0)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(col)
		_pic = TextureRect.new()
		_pic.texture = tex
		_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_pic.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(_pic)
		var line: HBoxContainer = HBoxContainer.new()
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		line.add_theme_constant_override(&"separation", 2)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(line)
		_gem = HudIcon.new()
		_gem.kind = HudIcon.Kind.GEM
		_gem.custom_minimum_size = Vector2(13.0, 13.0)
		_gem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(_gem)
		_caption = Label.new()
		_caption.theme_type_variation = &"HudInkCaption"
		_caption.add_theme_font_size_override(&"font_size", 11)
		_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(_caption)
		_apply()

	func _apply() -> void:
		if _caption == null:
			return
		var bg: Color = HudPalette.PLATE_HOVER
		var edge: Color = HudPalette.SIDEWALK
		match state:
			State.LOCKED:
				_caption.text = "%d" % _price
			State.ARMED:
				bg = HudPalette.GEM_LIGHT
				edge = HudPalette.GEM_DARK
				_caption.text = Loc.t("SATIN AL")
			State.OWNED:
				_caption.text = Loc.t("GİY")
			State.WORN:
				bg = HudPalette.PLATE_SELECTED
				edge = HudPalette.PLATE_SELECTED_EDGE
				_caption.text = Loc.t("ÜSTÜNDE")
		_gem.visible = state == State.LOCKED
		for style: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
			var b: StyleBoxFlat = StyleBoxFlat.new()
			b.bg_color = bg.lightened(0.06) if style == &"hover" else (bg.darkened(0.06) if style == &"pressed" else bg)
			b.border_color = edge
			b.set_border_width_all(3 if state == State.ARMED else 2)
			b.set_corner_radius_all(8)
			if style == &"focus":
				b.draw_center = false
				b.border_color = Color.TRANSPARENT
			add_theme_stylebox_override(style, b)


## Dostluk çubuğu: koyu yol şeridi üstünde amber dolgu (XP şeridinin dili).
class _Bar extends Control:
	var value: float = 0.0:
		set(v):
			value = v
			queue_redraw()

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		draw_style_box(_box(HudPalette.LANE_TRACK, HudPalette.INK, 2), r)
		if value > 0.0:
			var fill: Rect2 = Rect2(Vector2(2.0, 2.0), Vector2(maxf((size.x - 4.0) * value, 6.0), size.y - 4.0))
			draw_style_box(_box(HudPalette.LANE_PAINT, Color.TRANSPARENT, 0), fill)

	static func _box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
		var b: StyleBoxFlat = StyleBoxFlat.new()
		b.bg_color = bg
		b.border_color = border
		b.set_border_width_all(width)
		b.set_corner_radius_all(7)
		return b


## Olta düğmesinin çizimi: çapraz sopa, ip, kırmızı tüy.
class _RodIcon extends Control:
	func _draw() -> void:
		var s: float = minf(size.x, size.y) / 48.0
		var o: Vector2 = (size - Vector2(48.0, 48.0) * s) * 0.5
		var a: Vector2 = o + Vector2(9.0, 41.0) * s
		var b: Vector2 = o + Vector2(36.0, 9.0) * s
		draw_line(a, b, HudPalette.INK, 7.0 * s, true)
		draw_line(a, b, Color("A86B32"), 4.0 * s, true)
		var tip: Vector2 = o + Vector2(38.0, 25.0) * s
		draw_line(b, tip, HudPalette.INK, 1.6 * s, true)
		var feather: PackedVector2Array = PackedVector2Array([tip, tip + Vector2(-5.0, 7.0) * s,
			tip + Vector2(-1.0, 14.0) * s, tip + Vector2(4.0, 6.0) * s])
		draw_colored_polygon(feather, Color("C8463A"))
		draw_polyline(feather + PackedVector2Array([tip]), HudPalette.INK, 1.6 * s, true)


## Oyun sırasında ekranın sağ üstünden sarkan olta ve parmağı izleyen tüy.
class _Olta extends Control:
	var toy: Vector2 = Vector2.ZERO

	func _draw() -> void:
		var handle: Vector2 = Vector2(size.x + 20.0, -20.0)
		var tip: Vector2 = handle.lerp(toy, 0.55) + Vector2(0.0, -40.0)
		draw_line(handle, tip, HudPalette.INK, 12.0, true)
		draw_line(handle, tip, Color("A86B32"), 7.0, true)
		var mid: Vector2 = tip.lerp(toy, 0.5) + Vector2(0.0, 18.0)
		var string_pts: PackedVector2Array = PackedVector2Array()
		for i: int in 13:
			var u: float = float(i) / 12.0
			string_pts.append(tip.lerp(mid, u).lerp(mid.lerp(toy, u), u))
		draw_polyline(string_pts, HudPalette.INK, 2.2, true)
		var k: float = 1.8
		var f: PackedVector2Array = PackedVector2Array([toy, toy + Vector2(-12.0, 16.0) * k, toy + Vector2(-3.0, 34.0) * k,
			toy + Vector2(9.0, 15.0) * k])
		draw_colored_polygon(f, Color("C8463A"))
		draw_polyline(f + PackedVector2Array([toy]), HudPalette.INK, 3.0, true)
		draw_line(toy + Vector2(2.0, 4.0) * k, toy + Vector2(14.0, 22.0) * k, Color("E2B341"), 7.0, true)
		draw_line(toy + Vector2(-2.0, 6.0) * k, toy + Vector2(-12.0, 24.0) * k, Color("88E3FF"), 6.0, true)
