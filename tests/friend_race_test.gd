extends SceneTree
## ARKADAŞ RAKİP testi (başsız): Türkçe belirtme eki, Emre / Elif araç dağılımı, açık garajdaki modifiye yapıları,
## RaceManager.pick_rival (arkadaş oranı, gerçek arkadaşın uyan aracı, meşgul model, ilk yarış), rakip görünümü,
## fotoğraflı yarış balonu, davet ve sonuç panosu yazıları.
## tools/run_tests.sh friend_race_test

var fails: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _run() -> void:
	print("== 1) Türkçe belirtme eki ==")
	Loc.use("tr")
	var cases: Dictionary = {"Elif Usta": "Elif Usta'yı", "Emre Usta": "Emre Usta'yı", "Bob": "Bob'u", "Dave": "Dave'yi",
		"Usta1234": "Usta1234'ü", "Usta2": "Usta2'yi", "Usta10": "Usta10'u", "Usta40": "Usta40'ı", "Usta50": "Usta50'yi", "Usta300": "Usta300'ü", "Usta2000": "Usta2000'i",
		"Usta0": "Usta0'ı", "Ali": "Ali'yi", "Gül": "Gül'ü",
		"Şahin Çağrı": "Şahin Çağrı'yı", "Ömer": "Ömer'i", "Rüzgar": "Rüzgar'ı"}
	for name: String in cases:
		check(Loc.accusative(name) == cases[name], "%s → %s (%s)" % [name, cases[name], Loc.accusative(name)])
	check(Loc.upper(Loc.accusative("Elif Usta")) == "ELİF USTA'YI", "büyük harf: ELİF USTA'YI")
	Loc.use("en")
	check(Loc.accusative("Elif Usta") == "Elif Usta", "İngilizcede ek yok")
	Loc.use("tr")

	print("== 2) Emre / Elif araç dağılımı ==")
	var unmapped: Array[String] = []
	var emre: int = 0
	var eligible: int = 0
	for entry: Dictionary in CarCatalog.all():
		var id: StringName = entry["id"]
		if not RaceManager._rival_eligible(id):
			continue
		eligible += 1
		var owner: String = FeaturedFriends.owner_for_car(id)
		if not FeaturedFriends.EMRE_CARS.has(String(id)) and not FeaturedFriends.ELIF_CARS.has(String(id)):
			unmapped.append(String(id))
		if owner == "featured_emre":
			emre += 1
	check(unmapped.is_empty(), "rakip olabilen her araç listede: %s" % [unmapped])
	check(FeaturedFriends.owner_for_car(&"lambo_huracan") == "featured_emre" and FeaturedFriends.owner_for_car(&"tofas_sahin") == "featured_elif",
		"Huracán Emre'nin, Şahin Elif'in")
	# 2026-10-20: sabit 10–20 (29 araçta) yerine oran: araç partileri geldikçe sınır büyür
	check(emre >= eligible * 0.35 and emre <= eligible * 0.65, "dağılım dengeli (Emre %d / %d)" % [emre, eligible])
	var both: Array[String] = []
	for id: String in FeaturedFriends.EMRE_CARS:
		if FeaturedFriends.ELIF_CARS.has(id):
			both.append(id)
	check(both.is_empty(), "bir araç iki listede değil %s" % [both])
	var elif_owner: Dictionary = FeaturedFriends.rival_owner("featured_elif")
	check(elif_owner.get("name") == "Elif Usta" and bool(elif_owner.get("featured")) and (elif_owner.get("build") as Dictionary).is_empty()
		and SaveSafe.s(elif_owner.get("paint")) == "", "Elif rakip: fabrika rengi, modifiyesiz")

	print("== 3) Açık garajda yarış verisi ==")
	var snapshot: Dictionary = {"version": SaveManager.SAVE_VERSION, "progress": {"level": 9},
		"vehicles": {"owned": ["vw_golf_7", "vw_golf_7", "ufo_car", "tofas_sahin"], "paint": {"vw_golf_7": "d02020", "tofas_sahin": "zzz", "ufo_car": "00ff00"}},
		"performance": {"builds": {"vw_golf_7": {"motor": 3, "turbo": 9, "lazer": 2}, "tofas_sahin": {}}, "jobs": [{"car": "x"}], "floors": {"vw_golf_7": 0.9}}}
	var garage: Dictionary = PublicGarage.from_snapshot(snapshot)
	check(garage.has("performance") and not (garage["performance"] as Dictionary).has("jobs"), "açık garajda yalnız yapılar (takma işi yok)")
	var data: Dictionary = PublicGarage.race_data(garage)
	check(data["cars"] == ["vw_golf_7", "tofas_sahin"], "araçlar tekil, bilinmeyen atlandı %s" % [data["cars"]])
	check(data["paint"] == {"vw_golf_7": "d02020"}, "bozuk / bilinmeyen boya atlandı")
	check(data["builds"] == {"vw_golf_7": {"motor": 3, "turbo": 5}}, "yapı süzüldü (kademe sınırı, bilinmeyen kategori) %s" % [data["builds"]])
	check(PublicGarage.to_json(garage).length() < PublicGarage.MAX_JSON, "boyut sınırın altında")

	print("== 4) Rakip seçimi ==")
	var holder: Node = Node.new()
	root.add_child(holder)
	var social: SocialManager = SocialManager.new()
	holder.add_child(social)
	var race: RaceManager = RaceManager.new()
	holder.add_child(race)
	await frames(3)
	race._rng.seed = 11
	race.friend_chance = 0.0
	var pick: Dictionary = race.pick_rival(&"vw_golf_7")
	check((pick["owner"] as Dictionary).is_empty() and pick["id"] != &"", "friend_chance 0: isimsiz rakip")
	race.friend_chance = 1.0
	race._records[&"vw_golf_7"] = {"time": 11.0, "trace": PackedFloat32Array()}   # ilk yarış değil
	pick = race.pick_rival(&"vw_golf_7")
	var owner: Dictionary = pick["owner"]
	check(bool(owner.get("featured", false)) and owner.get("uid") == FeaturedFriends.owner_for_car(pick["id"]),
		"arkadaş yok: %s %s ile geldi" % [owner.get("name"), pick["id"]])
	var window: Vector2 = RaceManager.rival_window(&"vw_golf_7")
	check(window.x < DragRaceSim.base_time(&"vw_golf_7") and window.y > DragRaceSim.base_time(&"vw_golf_7"), "pencere oyuncu süresini kapsar")
	# Gerçek arkadaş: penceredeki aracı (Leon) ve pencere dışı (Huracán)
	social._state = SocialManager.State.READY
	var bob_garage: Dictionary = PublicGarage.from_snapshot({"version": SaveManager.SAVE_VERSION,
		"vehicles": {"owned": ["seat_leon", "lambo_huracan"], "paint": {"seat_leon": "1e90ff"}},
		"performance": {"builds": {"seat_leon": {"motor": 1}}}})
	social.friends = [{"uid": "bob", "name": "Bob Usta", "av": "p05", "frame": "gold", "flag": "DE",
		"race": PublicGarage.race_data(bob_garage)}]
	var hits: int = 0
	for i: int in 20:
		pick = race.pick_rival(&"vw_golf_7")
		owner = pick["owner"]
		if owner.get("uid") == "bob":
			hits += 1
			if pick["id"] != &"seat_leon":
				check(false, "Bob pencere dışı araçla geldi: %s" % pick["id"])
	check(hits == 20, "uyan aracı olan gerçek arkadaş önce gelir (20/%d)" % hits)
	owner = race.pick_rival(&"vw_golf_7")["owner"]
	check(owner.get("paint") == "1e90ff" and owner.get("build") == {&"motor": 1} and owner.get("frame") == "gold",
		"Bob'un boyası, modifiyesi ve çerçevesi taşındı %s" % [owner])
	var appearance: CarAppearance = RaceManager._appearance_for(&"seat_leon", owner)
	check(appearance.body_color.is_equal_approx(Color.html("1e90ff")), "yolda Bob'un boyasıyla")
	var factory: CarAppearance = RaceManager._appearance_for(&"tofas_sahin", FeaturedFriends.rival_owner("featured_elif"))
	check(factory.body_color.is_equal_approx(CarCatalog.default_color_for(CarCatalog.scene_path(&"tofas_sahin"))), "Elif fabrika renginde")
	check(RaceManager._appearance_for(&"tofas_sahin", {}) == null, "isimsiz rakip: trafik rengi")
	pick = race.pick_rival(&"vw_golf_7", {&"seat_leon": true})
	check(pick["owner"].get("uid") != "bob", "Bob'un aracı şehirdeyse Bob gelmez (Emre / Elif)")
	race._records.clear()
	pick = race.pick_rival(&"vw_golf_7")
	check(bool(pick["owner"].get("featured", false)), "ilk yarışta gerçek arkadaş gelmez")
	race._records[&"vw_golf_7"] = {"time": 11.0, "trace": PackedFloat32Array()}
	social.friends = []
	race.friend_chance = 0.7
	var friend_count: int = 0
	for i: int in 400:
		if not (race.pick_rival(&"vw_golf_7")["owner"] as Dictionary).is_empty():
			friend_count += 1
	check(friend_count > 240 and friend_count < 320, "~%%70 arkadaş (%d / 400)" % friend_count)

	print("== 5) Yarış balonu ==")
	var bubble: CarBubble = CarBubble.new()
	holder.add_child(bubble)
	bubble.show_avatar(ProfileCatalog.featured_texture("featured_elif"), true)
	check(bubble.visible and is_equal_approx(bubble.plate_size().x, CarBubble.WIDTH_AVATAR), "fotoğraflı balon (geniş plaka)")
	var small: Texture2D = CarBubble._avatar_texture(ProfileCatalog.featured_texture("featured_elif"), true)
	check(small != null and small.get_width() == CarBubble.AVATAR_PIXELS, "balon dokusu 96 px")
	check(CarBubble._avatar_texture(ProfileCatalog.featured_texture("featured_elif"), true) == small, "aynı doku önbellekten")
	bubble.show_avatar(null, true)
	check(bubble.visible and is_equal_approx(bubble.plate_size().x, CarBubble.WIDTH_ICON), "fotoğraf yoksa yalnız bayrak")

	print("== 6) Davet ve sonuç panosu ==")
	race._rival_id = &"tofas_sahin"
	race._rival_owner = FeaturedFriends.rival_owner("featured_elif")
	var invite: RaceChallengeScreen = RaceChallengeScreen.new()
	holder.add_child(invite)
	await frames(2)
	invite.call("_refresh")
	check((invite.get("_title") as Label).text == "ELİF USTA YARIŞMAK İSTİYOR!", "davet başlığı: %s" % (invite.get("_title") as Label).text)
	var rival_labels: Dictionary = invite.get("_rival_labels")
	check((rival_labels["owner_row"] as Control).visible and (rival_labels["owner_name"] as Label).text == "ELİF USTA", "rakip plakasında Elif")
	race._rival_owner = {"uid": "bob", "name": "Bob Usta", "av": "p05", "frame": "gold", "flag": "DE", "featured": false,
		"paint": "", "build": {&"motor": 5, &"turbo": 5}}
	race._rival_id = &"seat_leon"
	invite.call("_refresh")
	check((rival_labels["class"] as Label).text.contains("MODİFİYELİ"), "modifiyeli rakip etiketlendi")
	var result: RaceResultScreen = RaceResultScreen.new()
	holder.add_child(result)
	await frames(2)
	result.show_result(true, 11.2, 11.5, 1000, 50, &"vw_golf_7")
	check((result.get("_owner_text") as Label).text == "BOB USTA'YI YENDİN!",
		"kazanınca: %s" % (result.get("_owner_text") as Label).text)
	result.show_result(false, 11.6, 11.5, 0, 15, &"seat_leon")
	check((result.get("_owner_text") as Label).text == "BOB USTA KAZANDI", "kaybedince: BOB USTA KAZANDI")
	race._rival_owner = {}
	result.show_result(true, 11.2, 11.5, 1000, 50, &"vw_golf_7")
	check(not (result.get("_owner_row") as Control).visible, "isimsiz rakipte satır yok")

	holder.queue_free()
	await frames(2)
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
