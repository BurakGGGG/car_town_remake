extends SceneTree
## HOŞ GELDİN KUTUSU — yeni oyuncu ilk aracını (Tofaş Şahin) doğrudan almaz; garajına hediye kutusu gelir, araç
## kutudan çıkar. Denetlenenler:
##   - katalog: hediye kasası mağazada / koleksiyon bölümlerinde yok, içinden %100 Şahin çıkar
##   - yeni oyun: araç yok, kutu bekliyor ve ilk kayda yazıldı; ikinci kez verilmez (ensure_welcome tek kutu)
##   - açılış: Şahin garaja + koleksiyona girer, elmas / keşif / kilometre taşı ödenmez, görevlerin kasa sayacı artmaz
##   - bekleyen ya da açılmış kutu "ilerleme" sayılmaz (Google girişinde bulut kaydı kendiliğinden gelsin)
##   - araçsız eski / bozuk kayıt yüklenince kutu gelir; araçlı kayda gelmez; YENİ OYUN kutuyu yeniden getirir
## Gerçek düğümlerle koşar (Main.tscn). Görsel akış: qa/hosgeldin_kutusu_qa.gd, eğitim: qa/tutorial_flow.gd.
##   tools/run_tests.sh welcome_crate_test

var fails: int = 0
var main: Node


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func g(group: StringName) -> Node:
	return get_first_node_in_group(group)


func reload() -> void:
	if main:
		main.free()
	await frames(4)
	main = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(10)
	await create_timer(1.2).timeout


func disk() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))


func write(data: Dictionary) -> void:
	var f: FileAccess = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	assert(not OS.get_user_data_dir().ends_with("/CarTownRemake"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))

	print("== 1) KATALOG ==")
	check(CrateCatalog.exists(CrateCatalog.WELCOME) and CrateCatalog.is_gift(CrateCatalog.WELCOME), "HOŞ GELDİN KUTUSU hediye kasası")
	check(not CrateCatalog.all().any(func(e: Dictionary) -> bool: return CrateCatalog.is_gift(e["id"])), "mağaza kasaları arasında hediye yok")
	var odds: Array[Dictionary] = CrateCatalog.odds(CrateCatalog.WELCOME)
	check(odds.size() == 1 and odds[0]["id"] == &"tofas_sahin" and is_equal_approx(float(odds[0]["chance"]), 1.0), "içinden %100 Tofaş Şahin")
	check(CrateCatalog.crate_of(&"tofas_sahin") == &"", "koleksiyonda Şahin BAŞLANGIÇ bölümünde kalır")
	check(ResourceLoader.exists(String(CrateCatalog.get_entry(CrateCatalog.WELCOME)["scene_path"])), "hediye kutusu modeli var")

	print("== 2) YENİ OYUN ==")
	await reload()
	var own: VehicleOwnership = g(&"vehicle_ownership")
	var crates: CrateManager = g(&"crates")
	var save: SaveManager = g(&"save_manager")
	var pp: PlayerProgress = g(&"player_progress")
	var missions: MissionManager = g(&"missions")
	var uid: int = crates.welcome_uid()
	check(own.owned_count() == 0 and not own.grant_starting_vehicle, "araç doğrudan verilmez")
	check(uid > 0 and crates.pending_count() == 1 and String(crates.get_crate(uid)["source"]) == "welcome", "garajda tek hediye kutusu")
	var on_disk: Array = (disk().get("crates", {}) as Dictionary).get("items", [])
	check(on_disk.size() == 1 and String((on_disk[0] as Dictionary).get("crate", "")) == String(CrateCatalog.WELCOME), "kutu ilk kayıtta")
	check(crates.ensure_welcome() == uid and crates.pending_count() == 1, "ensure_welcome ikinci kutu vermez")
	check(not save.has_progress(), "bekleyen kutu ilerleme sayılmaz")
	await reload()
	own = g(&"vehicle_ownership"); crates = g(&"crates"); save = g(&"save_manager")
	check(crates.welcome_uid() == uid and crates.pending_count() == 1 and own.owned_count() == 0, "yeniden açılışta aynı kutu (yenisi gelmez)")

	print("== 3) AÇILIŞ ==")
	pp = g(&"player_progress"); missions = g(&"missions")
	var gems: int = pp.gems
	# Kayıt varken açılan oturumda "yeni kurulum" tabanı yoktur: kutunun ilerleme sayılmadığı, açılıştan önceki ve
	# sonraki karşılaştırma metninin aynı kalmasıyla denetlenir (ilk kurulum hâli crate_test §1'de)
	var progress_before: String = save._progress_json()
	var opened_before: int = int((missions.get("_life") as Dictionary).get(&"crates_opened", 0))
	var result: Dictionary = crates.open(uid)
	check(bool(result.get("gift", false)) and result.get("vehicle") == &"tofas_sahin" and bool(result.get("discovered", false)), "kutudan Şahin çıktı")
	check(int(result.get("gems", -1)) == 0 and int(result.get("discovery_gems", -1)) == 0 and pp.gems == gems,
		"hediye elmas vermez (%d)" % pp.gems)
	check(int((missions.get("_life") as Dictionary).get(&"crates_opened", 0)) == opened_before, "görevlerin kasa sayacı artmadı")
	crates.claim(uid)
	check(own.owned_vehicle_ids() == [&"tofas_sahin"] and own.is_discovered(&"tofas_sahin") and own.discovered_count() == 1, "Şahin garajda ve koleksiyonda")
	check(crates.welcome_uid() == 0 and crates.ensure_welcome() == 0, "kutu açıldı: aracı olana yeni kutu gelmez")
	check(save._progress_json() == progress_before, "kutuyu açmak ilerleme sayılmaz")
	(g(&"economy") as EconomyManager).add_money(10)
	check(save.has_progress(), "gerçek ilerleme yine ilerleme sayılır")
	save.save_game()
	await reload()
	own = g(&"vehicle_ownership"); crates = g(&"crates")
	check(own.owned_vehicle_ids() == [&"tofas_sahin"] and crates.pending_count() == 0, "kayıttan: Şahin var, kutu geri gelmez")

	print("== 4) ESKİ / BOZUK KAYIT ==")
	write({"version": 1, "economy": {"money": 777}, "progress": {"xp": 0, "level": 4, "gems": 3}})
	await reload()
	own = g(&"vehicle_ownership"); crates = g(&"crates")
	check(own.owned_count() == 0 and crates.welcome_uid() > 0, "araçsız eski kayıt: HOŞ GELDİN KUTUSU geldi")
	check(((disk().get("crates", {}) as Dictionary).get("items", []) as Array).size() == 1, "kutu kayda yazıldı")
	write({"version": SaveManager.SAVE_VERSION, "economy": {"money": 900}, "progress": {"xp": 0, "level": 6, "gems": 5},
		"vehicles": {"owned": ["yok_boyle_arac"], "paint": {}}})
	await reload()
	own = g(&"vehicle_ownership"); crates = g(&"crates")
	check(own.owned_count() == 0 and crates.welcome_uid() > 0, "katalog dışı araçla kalan kayıt: kutu geldi")
	write({"version": SaveManager.SAVE_VERSION, "economy": {"money": 900}, "progress": {"xp": 0, "level": 6, "gems": 5},
		"vehicles": {"owned": ["hyundai_getz"], "paint": {}}})
	await reload()
	own = g(&"vehicle_ownership"); crates = g(&"crates")
	check(own.owned_vehicle_ids() == [&"hyundai_getz"] and crates.welcome_uid() == 0, "aracı olan oyuncuya kutu gelmez (Şahin de verilmez)")
	save = g(&"save_manager")
	var snap: Dictionary = save.snapshot()
	(snap["vehicles"] as Dictionary)["owned"] = []
	check(save.apply_snapshot(snap) and own.owned_count() == 0 and crates.welcome_uid() > 0, "bulut kaydı araçsızsa kutu gelir")

	print("== 5) YENİ OYUN (sıfırla) ==")
	own.add_vehicle(&"bmw_e46")
	save.new_game()
	await frames(10)
	check(own.owned_count() == 0 and crates.pending_count() == 1 and crates.welcome_uid() > 0, "YENİ OYUN: araç yok, tek hediye kutusu")
	var gift_items: Array = (disk().get("crates", {}) as Dictionary).get("items", [])
	check(int(disk()["economy"]["money"]) == 5000 and gift_items.size() == 1, "yeni oyun kutuyla birlikte kayda yazıldı")

	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
