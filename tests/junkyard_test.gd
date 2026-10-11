extends SceneTree
## HURDALIK / RESTORASYON TESTİ — parça envanteri, proje tamir alanını kaplar, envanterden takma,
## gemle eksik alma, bitirme / bırakma, usta kademesinin açılması, kayıt (diske + yeniden yükleme),
## bozuk kayıt temizliği, yeni oyun.
## Restorasyon modelleri henüz olmadığı için mevcut araçlarla kurulan tests/fixtures/restorations_test.json
## kullanılır; gerçek katalog yalnızca 1. bölümde (yapı) denetlenir.
## Çalıştırma: tools/run_tests.sh junkyard_test   (yalıtılmış user dizini)
const FIXTURE: String = "res://tests/fixtures/restorations_test.json"

var fails: int = 0
var main: Node


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func load_main() -> Node:
	var node: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(node)
	current_scene = node
	await frames(10)
	return node


func reload() -> void:
	if main:
		main.free()
	await frames(4)
	main = await load_main()
	await create_timer(1.2).timeout


func disk() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))


func g(group: StringName) -> Node:
	return get_first_node_in_group(group)


func _init() -> void:
	_run()


func _run() -> void:
	await process_frame
	assert(not OS.get_user_data_dir().ends_with("/CarTownRemake"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))

	print("== 1) GERÇEK KATALOG ==")
	check(RestorationCatalog.load_from(), "vehicles/restorations.json okundu")
	check(RestorationCatalog.parts().size() == 9 and RestorationCatalog.tiers().size() == 3, "9 parça türü, 3 kademe")
	check(RestorationCatalog.all_planned().size() == 28, "28 plan aracı (12 temel + 8 klasik + 8 yarış)")
	check(RestorationCatalog.total_required(&"tofas_murat_124") == 6, "ilk temel araç 6 parça (orijinal Fiat 500: 6×1)")
	check(RestorationCatalog.total_required(&"lamborghini_miura") == 78, "klasiğin sonuncusu 78 parça (orijinal XJ220: 78)")
	check(RestorationCatalog.tier_requirement(&"classic") == 10 and RestorationCatalog.tier_requirement(&"race") == 10, "usta kademeleri 10 temel restorasyonla açılır")
	for entry: Dictionary in RestorationCatalog.all_planned():
		if RestorationCatalog.has_model(entry["id"]):
			continue
		check(RestorationCatalog.cars().all(func(e: Dictionary) -> bool: return e["id"] != entry["id"]), "%s modeli yok → oyunda görünmez" % entry["id"])
		break

	print("== 2) İLK AÇILIŞ ==")
	await reload()
	var jy: JunkyardManager = g(&"junkyard")
	var rm: RepairManager = g(&"repair_manager")
	var bays: RepairBayManager = g(&"repair_bays")
	var pp: PlayerProgress = g(&"player_progress")
	var own: VehicleOwnership = g(&"vehicle_ownership")
	var save: SaveManager = g(&"save_manager")
	check(jy != null and rm != null and bays != null, "JunkyardManager kodla kuruldu")
	check(jy.total_parts() == 0 and jy.project_count() == 0, "yeni oyunda envanter boş, proje yok")
	check(jy.status(&"lancia_delta_integrale") == JunkyardManager.Status.MODEL_PENDING, "modeli olmayan araç: MODEL_PENDING")
	check(jy.status(&"tofas_murat_124") == JunkyardManager.Status.AVAILABLE, "modeli gelen temel araç: AVAILABLE")
	check(RestorationCatalog.cars().size() == 24, "24 restorasyon aracının modeli hazır")
	check(not VehicleOwnership.is_paintable(&"tofas_murat_124") and VehicleOwnership.is_paintable(&"tofas_sahin"), "restorasyon aracı boyanamaz, kasa aracı boyanır")
	check(VehicleOwnership.collection_ids().size() == 26 and not VehicleOwnership.collection_ids().has(&"anadol_a1"), "kasa koleksiyonu 26 araç, restorasyon hariç")
	check(RaceManager.rival_pool(&"tofas_sahin").all(func(id: StringName) -> bool: return not RestorationCatalog.is_restoration(id)), "restorasyon aracı yarış rakibi olmaz")
	save.save_game()
	check(disk().has("junkyard"), "kayıtta junkyard bölümü var")

	print("== 3) TEST KATALOĞU, PROJE ALANI KAPLAR ==")
	check(RestorationCatalog.load_from(FIXTURE), "test kataloğu yüklendi")
	check(RestorationCatalog.total_required(&"hyundai_getz") == 4, "reçetedeki bilinmeyen parça atlandı")
	check(RestorationCatalog.cars().size() == 3, "modeli olmayan plan aracı listede yok")
	check(jy.status(&"opel_corsa") == JunkyardManager.Status.AVAILABLE, "temel araç başlatılabilir")
	check(jy.status(&"mercedes_cls") == JunkyardManager.Status.TIER_LOCKED, "usta aracı kilitli")
	check(not jy.start(&"mercedes_cls"), "kilitli kademedeki araç başlamaz")
	bays.load_state(1)
	check(rm.free_bay() == 0 and not rm.is_busy(), "tek alan açık ve boş")
	var started: Array = []
	jy.project_started.connect(func(id: StringName, bay: int) -> void: started.append([id, bay]))
	check(jy.start(&"opel_corsa"), "Corsa restorasyonu başladı")
	check(started == [[&"opel_corsa", 0]] and jy.bay_of(&"opel_corsa") == 0, "proje 0. tamir alanında")
	check(rm.free_bay() == -1 and rm.is_busy() and not rm.is_bay_free(0), "alan dolu: müşteri gönderilmez")
	check(not jy.start(&"opel_corsa"), "aynı araç ikinci kez başlamaz")
	check(not jy.start(&"hyundai_getz"), "boş alan yokken ikinci proje başlamaz")
	bays.load_state(2)
	check(rm.free_bay() == 1 and not rm.is_busy(), "ikinci alan açılınca boş")
	check(jy.start(&"hyundai_getz") and jy.bay_of(&"hyundai_getz") == 1, "Getz 1. alanda")
	check(not jy.start(&"no_model_car"), "modeli olmayan araç başlamaz")

	print("== 4) ENVANTER VE TAKMA ==")
	check(jy.install(&"opel_corsa", &"bolt") == 0, "envanter boşken takılmaz")
	check(not jy.add_parts(&"made_up", 3) and not jy.add_parts(&"bolt", 0), "bilinmeyen parça / 0 adet eklenmez")
	var gained: Array = []
	jy.parts_gained.connect(func(id: StringName, n: int, src: StringName) -> void: gained.append([id, n, src]))
	check(jy.add_parts(&"bolt", 3, &"pile"), "3 civata hurda yığınından")
	check(gained == [[&"bolt", 3, &"pile"]], "parts_gained kaynağıyla geldi")
	check(jy.install(&"opel_corsa", &"bolt") == 1 and jy.part_count(&"bolt") == 2, "Corsa'ya 1 civata (gereken kadar) takıldı, 2 kaldı")
	check(is_equal_approx(jy.progress(&"opel_corsa"), 0.25), "ilerleme %25 (1 / 4)")
	check(jy.install(&"opel_corsa", &"bolt") == 0, "tamamlanmış parça yeniden takılmaz")

	print("== 5) GEMLE EKSİK ==")
	pp.load_state(pp.level, pp.xp, 0)
	check(jy.missing_gem_cost(&"opel_corsa", &"nut") == 2, "1 somun = 2 gem")
	check(not jy.buy_missing(&"opel_corsa", &"nut") and jy.installed(&"opel_corsa", &"nut") == 0, "gem yokken alınmaz, hiçbir şey değişmez")
	pp.add_gems(100)
	check(jy.buy_missing(&"opel_corsa", &"nut") and pp.gems == 98, "somun gemle alındı (98 gem kaldı)")
	check(jy.all_missing_gem_cost(&"opel_corsa") == 6, "kalan eksik bedeli: piston 3 + dişli 3")
	check(jy.buy_all_missing(&"opel_corsa") and pp.gems == 92, "hepsini al tek ödeme: 6 gem")
	check(jy.status(&"opel_corsa") == JunkyardManager.Status.READY and is_equal_approx(jy.progress(&"opel_corsa"), 1.0), "Corsa %100: READY")
	jy.add_parts(&"piston", 1)   # Getz: 2 civata + 1 piston envanterden, 1 piston (3 gem) eksik
	pp.load_state(pp.level, pp.xp, 2)
	check(not jy.buy_all_missing(&"hyundai_getz") and pp.gems == 2, "gem yetmezse hiç gem harcanmaz")
	check(jy.installed(&"hyundai_getz", &"bolt") == 2 and jy.installed(&"hyundai_getz", &"piston") == 1, "...ama envanterdekiler takıldı")
	check(jy.part_count(&"bolt") == 0 and jy.part_count(&"piston") == 0, "envanter düştü")

	print("== 6) KAYIT VE YENİDEN YÜKLEME ==")
	jy.add_parts(&"gear", 7, &"repair")
	save.save_game()
	var data: Dictionary = disk().get("junkyard", {})
	check((data.get("projects", []) as Array).size() == 2 and int((data.get("parts", {}) as Dictionary).get("gear", 0)) == 7, "diskte 2 proje ve 7 dişli")
	await reload()
	jy = g(&"junkyard")
	rm = g(&"repair_manager")
	own = g(&"vehicle_ownership")
	pp = g(&"player_progress")
	save = g(&"save_manager")
	check(jy.project_count() == 2 and jy.bay_of(&"opel_corsa") == 0 and jy.bay_of(&"hyundai_getz") == 1, "projeler alanlarıyla geri geldi")
	check(jy.part_count(&"gear") == 7 and jy.installed(&"hyundai_getz", &"piston") == 1, "envanter ve takılı parçalar geri geldi")
	check(rm.is_busy() and rm.free_bay() == -1, "yüklemeden sonra da alanlar dolu")

	print("== 7) BİTİRME VE BIRAKMA ==")
	var done: Array = []
	jy.project_completed.connect(func(id: StringName) -> void: done.append(id))
	check(not jy.finish(&"hyundai_getz"), "eksik proje bitmez")
	check(jy.finish(&"opel_corsa") and done == [&"opel_corsa"], "Corsa bitti")
	check(own.is_owned(&"opel_corsa") and jy.is_completed(&"opel_corsa"), "Corsa garajda, tamamlananlarda")
	check(jy.status(&"opel_corsa") == JunkyardManager.Status.COMPLETED and rm.is_bay_free(0), "0. alan boşaldı")
	check(not jy.start(&"opel_corsa"), "sahip olunan restorasyon aracı yeniden başlamaz")
	check(jy.quit(&"hyundai_getz") and rm.is_bay_free(1), "Getz bırakıldı, 1. alan boşaldı")
	check(jy.part_count(&"bolt") == 2 and jy.part_count(&"piston") == 1, "takılı parçalar envantere döndü")

	print("== 8) USTA KADEMESİ ==")
	var tiers: Array = []
	jy.tier_unlocked.connect(func(id: StringName) -> void: tiers.append(id))
	check(jy.start(&"hyundai_getz"), "Getz yeniden başladı")
	pp.add_gems(50)
	check(jy.buy_all_missing(&"hyundai_getz") and jy.finish(&"hyundai_getz"), "Getz bitti")
	check(jy.basic_completed_count() == 2 and tiers == [&"classic"], "2 temel → USTA · KLASİK açıldı (sinyal bir kez)")
	check(jy.status(&"mercedes_cls") == JunkyardManager.Status.AVAILABLE, "CLS artık başlatılabilir")
	check(own.sell_vehicle(&"opel_corsa") and jy.status(&"opel_corsa") == JunkyardManager.Status.AVAILABLE, "satılan restorasyon aracı yeniden restore edilebilir")
	check(jy.basic_completed_count() == 2, "...tamamlanan sayısı düşmez")

	print("== 9) BOZUK KAYIT ==")
	jy.load_state({
		"parts": {"bolt": -4, "gear": 99999999, "made_up": 5, "belt": "abc"},
		"completed": ["opel_corsa", "opel_corsa", "not_a_car"],
		"projects": [
			{"car": "mercedes_cls", "bay": 0, "installed": {"gear": 10, "belt": 2}},
			{"car": "hyundai_getz", "bay": 0, "installed": {"bolt": 2}},
			{"car": "ghost", "bay": 1, "installed": {"piston": 1}},
			"bozuk",
		],
	})
	check(jy.part_count(&"bolt") == 2 and jy.part_count(&"gear") == JunkyardManager.MAX_STACK, "negatif adet atıldı, aşırı adet sınıra çekildi; çakışan projenin civatası iade")
	check(jy.inventory().size() == 3 and jy.part_count(&"piston") == 1, "bilinmeyen parça atlandı, bilinmeyen araçlı projenin pistonu iade")
	check(jy.completed_ids() == [&"opel_corsa"], "tamamlananlar tekilleşti, bilinmeyen atıldı")
	check(jy.project_count() == 1 and jy.installed(&"mercedes_cls", &"gear") == 3 and jy.installed(&"mercedes_cls", &"belt") == 2, "tek geçerli proje; reçeteden fazla dişli kırpıldı")

	print("== 10) YENİ OYUN ==")
	save.new_game()
	jy = g(&"junkyard")
	check(jy.total_parts() == 0 and jy.project_count() == 0 and jy.completed_ids().is_empty(), "yeni oyun hurdalığı sıfırladı")
	check((disk().get("junkyard", {}) as Dictionary).get("projects", [1]).is_empty(), "diskteki kayıt da boş")

	RestorationCatalog.load_from()
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
