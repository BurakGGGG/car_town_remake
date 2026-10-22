extends SceneTree
## ARKADAŞ RAKİP testi (başsız): Türkçe belirtme eki, Emre / Elif araç dağılımı, açık garajdaki modifiye yapıları,
## RaceManager.pick_rival (arkadaş oranı, gerçek arkadaşın uyan aracı, meşgul model, ilk yarış), koşu eşleştirme (koşusu
## olmayan / başka modifiyeyle koşulmuş araç gelmez, pistteki koşu arkadaşın kendi koşusu), rakip görünümü,
## fotoğraflı yarış balonu, davet ve sonuç panosu yazıları.
## tools/run_tests.sh friend_race_test

var fails: int = 0


## Arkadaşın koşusu yerine: yapay zekânın becerisi / vites planı, ama OYUNCU koşusu gibi (gün formu gücü yok, kalkış
## devri optimum — Recording.is_player_run; açık garaj başkasını kabul etmez). Süre tekrarla yeniden hesaplanır.
static func _player_like(id: StringName, build: Dictionary, rng: RandomNumberGenerator) -> DragRaceSim.Recording:
	var form: DragRaceSim.Form = DragRaceSim.roll_form(id, rng)
	form.power = 1.0
	var recording: DragRaceSim.Recording = DragRaceSim.ai_recording(id, build, form, rng)
	recording.launch_rpm = roundf(recording.spec().launch_rpm)
	recording.time = DragRaceSim.replay(recording).finish_time
	return recording


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


## Aracın yapay zekâ koşularından süreye göre yayılmış `count` tanesi (arkadaşın gerçek koşuları yerine; seçici her kolu
## tutturabilsin).
func _spread_runs(id: StringName, build: Dictionary, count: int) -> Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 404
	var all: Array[DragRaceSim.Recording] = []
	for i: int in 60:
		all.append(_player_like(id, build, rng))
	all.sort_custom(func(a: DragRaceSim.Recording, b: DragRaceSim.Recording) -> bool: return a.time < b.time)
	var out: Array = []
	for i: int in count:
		out.append(all[int(float(i) / float(maxi(count - 1, 1)) * float(all.size() - 1))].to_dict())
	return out


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
	# Gerçek arkadaş: penceredeki aracı (Leon) ve pencere dışı (Huracán). KOŞU EŞLEŞTİRME: koşusu olmayan araç gelmez.
	social._state = SocialManager.State.READY
	var bob_snapshot: Dictionary = {"version": SaveManager.SAVE_VERSION,
		"vehicles": {"owned": ["seat_leon", "lambo_huracan"], "paint": {"seat_leon": "1e90ff"}},
		"performance": {"builds": {"seat_leon": {"motor": 1}}}}
	social.friends = [{"uid": "bob", "name": "Bob Usta", "av": "p05", "frame": "gold", "flag": "DE",
		"race": PublicGarage.race_data(PublicGarage.from_snapshot(bob_snapshot))}]
	var lonely: int = 0
	for i: int in 20:
		if race.pick_rival(&"vw_golf_7")["owner"].get("uid") == "bob":
			lonely += 1
	check(lonely == 0, "koşusu olmayan arkadaş aracı gelmez (%d / 20)" % lonely)
	bob_snapshot["race"] = {"runs": {"seat_leon": _spread_runs(&"seat_leon", {"motor": 2}, 8)}}
	social.friends[0]["race"] = PublicGarage.race_data(PublicGarage.from_snapshot(bob_snapshot))
	lonely = 0
	for i: int in 20:
		if race.pick_rival(&"vw_golf_7")["owner"].get("uid") == "bob":
			lonely += 1
	check(lonely == 0, "başka modifiyeyle koşulmuş koşu sayılmaz: pistteki araç davettekiyle aynı olmalı (%d / 20)" % lonely)
	bob_snapshot["race"] = {"runs": {"seat_leon": _spread_runs(&"seat_leon", {"motor": 1}, 8),
		"lambo_huracan": _spread_runs(&"lambo_huracan", {}, 2)}}
	var bob_garage: Dictionary = PublicGarage.from_snapshot(bob_snapshot)
	social.friends[0]["race"] = PublicGarage.race_data(bob_garage)
	check(((social.friends[0]["race"] as Dictionary)["runs"] as Dictionary).size() == 2, "açık garajdan koşular okundu")
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
		"Bob'un boyası, modifiyesi ve çerçevesi taşındı %s" % [owner.get("name")])
	check(owner.get("runs") is Array and not (owner.get("runs", []) as Array).is_empty(), "Bob'un Leon koşuları rakibe taşındı")
	race._rival_id = &"seat_leon"
	race._rival_owner = owner
	var bob_run: DragRaceSim.Recording = race.rival_recording(&"vw_golf_7")
	var bob_times: Array[float] = []
	for raw: Variant in owner.get("runs", []):
		bob_times.append(float((raw as Dictionary)["t"]))
	check(bob_run != null and bob_run.vehicle_id == &"seat_leon" and PerformanceMods.build_key(bob_run.build) == PerformanceMods.build_key({&"motor": 1}),
		"pistteki koşu Bob'un Leon'u, onun modifiyesiyle")
	check(bob_run != null and bob_times.any(func(t: float) -> bool: return absf(t - bob_run.time) < 0.0002),
		"pistteki koşu Bob'un GERÇEK koşularından biri (%.3f sn)" % (bob_run.time if bob_run else -1.0))
	check(race.chance() >= 0.0 and race.chance() <= 1.0 and race.arm() >= 0, "şans hesaplandı (%.2f, kol %d)" % [race.chance(), race.arm()])
	race.release_challenger()
	# Hedefe uymayan koşu: arkadaş yine gelir (kullanıcı kararı) — SERİ KIRICI hariç (iki kayıp → kolay koşusu olmayan gelmez)
	var hard_only: Dictionary = bob_snapshot.duplicate(true)
	hard_only["race"] = {"runs": {"seat_leon": (_spread_runs(&"seat_leon", {"motor": 1}, 8) as Array).slice(0, 3)}}
	social.friends[0]["race"] = PublicGarage.race_data(PublicGarage.from_snapshot(hard_only))
	var anyway: int = 0
	for i: int in 20:
		if race.pick_rival(&"vw_golf_7")["owner"].get("uid") == "bob":
			anyway += 1
	check(anyway == 20, "yalnız zor koşuları olan arkadaş da gelir, en yakın koşusuyla (%d / 20)" % anyway)
	race._history = [{"w": false, "a": 1, "p": 0.5}, {"w": false, "a": 1, "p": 0.5}]
	var breaker: int = 0
	for i: int in 20:
		if race.pick_rival(&"vw_golf_7")["owner"].get("uid") == "bob":
			breaker += 1
	check(breaker == 0 and race.arm() == RivalSelector.Arm.EASY, "iki kayıptan sonra kolay koşusu olmayan arkadaş gelmez (%d / 20)" % breaker)
	race._history.clear()
	social.friends[0]["race"] = PublicGarage.race_data(bob_garage)
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
