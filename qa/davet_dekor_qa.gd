extends SceneTree
## DOSTLAR NEON TABELASI GÖRSEL QA (2026-10-23, ARKADAŞ DAVETİ 5. basamak; tools/decor/props_v8_davet.py): gerçek
## Main.tscn'de 5. basamağın postası alınır (MailService: tabela + DAVETÇİ çerçevesi), tabela arka duvara asılır; yanına
## kıyas için giriş merdiveninin NEON ANAHTAR TABELASI. Oyun kamerası + yakın plan.
##   CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/davet_dekor_qa.gd --display-driver x11 --disable-vsync --resolution 1152x648
## Çıktı: ~/Projects/ct_shots/davet_dekor/
const OUT: String = "/home/burak/Projects/ct_shots/davet_dekor/"

var _fails: int = 0
var decor: DecorManager
var view: GarageDecorView
var cam: WorldCamera
var hud: Hud


func check(ok: bool, what: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + what)
	if not ok:
		_fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func shot(file: String) -> void:
	await frames(4)
	RenderingServer.force_draw()
	get_root().get_texture().get_image().save_png(OUT + file)
	print("  foto: ", file)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await frames(90)
	hud = current_scene.find_child("HUD", true, false)
	decor = get_first_node_in_group("decor") as DecorManager
	view = get_first_node_in_group("garage_decor_view") as GarageDecorView
	cam = get_root().get_camera_3d() as WorldCamera
	var crates: CrateManager = get_first_node_in_group("crates") as CrateManager
	crates.get("_crates").clear()
	crates.crates_changed.emit()
	(get_first_node_in_group("garage_upgrades") as GarageUpgradeManager).apply_levels({GarageUpgradeManager.GARAGE_ID: 2})
	await frames(20)

	check(GarageDecor.exists(ReferralRewards.DECOR_NEON) and GarageDecor.is_exclusive(ReferralRewards.DECOR_NEON),
		"katalogda, yalnız verilen eşya")
	check(not GarageDecor.all().any(func(e: Dictionary) -> bool: return StringName(e["id"]) == ReferralRewards.DECOR_NEON),
		"mağaza listesinde yok")
	var mail: MailService = get_first_node_in_group("mail") as MailService
	var tier: Dictionary = (ReferralRewards.tier(5) as Dictionary).duplicate(true)
	tier.merge({"title": "Ece katıldı! 5. davet ödülün", "referral": "tier_5", "at": 605}, true)
	mail._pending = [MailService.normalize("ref_5", tier)]
	var summary: Dictionary = mail.claim("ref_5")
	check(decor.owned_of(ReferralRewards.DECOR_NEON) == 1, "5. basamağın postası tabelayı verdi")
	check((summary.get("items", []) as Array).any(func(s: String) -> bool: return s.contains(Loc.t("DOSTLAR NEON TABELASI"))),
		"ödül penceresinde tabela: %s" % [summary.get("items", [])])
	var profile: PlayerProfile = get_first_node_in_group("player_profile") as PlayerProfile
	check(profile.frame_unlocked(ReferralRewards.FRAME_INVITER), "DAVETÇİ çerçevesi de geldi")

	var iid: String = _place_wall(ReferralRewards.DECOR_NEON, "back", 0.35)
	check(iid != "", "arka duvara asıldı")
	decor.grant_exclusive(&"login_m01_w2")
	var other: String = _place_wall(&"login_m01_w2", "back", 0.8)
	view.refresh()
	await frames(30)
	hud.visible = false
	cam.reset_view()
	await frames(60)
	await shot("1_oyun.png")
	if iid != "":
		await _close_up(iid, "2_yakin.png")
	if other != "":
		await _close_up(other, "3_kiyas_neon_anahtar.png")
	print("SONUC: fails=%d" % _fails)
	quit()


## Duvarın `along` kesrine en yakın geçerli asma noktası (qa/kurucu_dekor_qa.gd ile aynı).
func _place_wall(id: StringName, side: String, along: float = 0.5) -> String:
	var area: DecorArea = view.area()
	var span: Vector2 = area.face(side)["span"]
	var mid: float = lerpf(span.x, span.y, along)
	for k: int in 60:
		for s: int in [1, -1]:
			var m: Dictionary = area.mount_on(side, mid + s * k * 0.03, view.wall_width(id))
			if view.is_valid(id, m["position"], float(m["yaw"])):
				return decor.add_instance(id, m["position"], float(m["yaw"]))
	return ""


func _box_of(iid: String) -> AABB:
	var body: Node3D = view.body_of(iid)
	var out: AABB = AABB()
	var first: bool = true
	for n: Node in body.find_children("*", "VisualInstance3D", true, false):
		var vi: VisualInstance3D = n as VisualInstance3D
		var b: AABB = vi.global_transform * vi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


## Oyunun ışığında, eşyaya oyun kamerası yönünden bakan geçici dar açılı kamera.
func _close_up(iid: String, file: String) -> void:
	var box: AABB = _box_of(iid)
	var center: Vector3 = box.get_center()
	var close: Camera3D = Camera3D.new()
	close.fov = 30.0
	current_scene.add_child(close)
	close.position = center + Vector3(0.45, 0.42, 1.0).normalized() * (box.size.length() * 1.55 + 0.04)
	close.look_at(center, Vector3.UP)
	close.make_current()
	await frames(12)
	await shot(file)
	cam.make_current()
	close.queue_free()
