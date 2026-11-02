extends SceneTree
## DİNAMOMETRE FİZİĞİ (gameplay/dyno/dyno_sim.gd): rölantiden kesiciye tam gaz çekiş bir ölçüm sayılır ve fabrika
## aracında tepe güç katalog beygirine eşit (±%1,5), modifiye takınca artar; gaz verirken (vites yok) devir pedalı izler,
## merdane devre bağlı döner, rölantide durur, kesici kırmızıda; çeken aks katalogdaki çekişe göre (FWD / RWD / AWD).
## Çalıştırma: tools/run_tests.sh dyno_sim_test

var fails: int = 0


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	print("== tam gaz çekiş = ölçüm (fabrika) ==")
	for id: StringName in [&"toyota_supra", &"tofas_sahin", &"chevrolet_camaro", &"tesla_model_y", &"mercedes_sprinter"]:
		var sim: DynoSim = DynoSim.new(id)
		var t: float = _pull(sim)
		var err: float = absf(sim.peak_hp / maxf(sim.catalog_hp, 1.0) - 1.0)
		check(sim.pulls == 1, "%s: çekiş ölçüm sayıldı (%.1f sn)" % [id, t])
		check(err < 0.015, "%s: tepe güç %.0f bg ≈ katalog %.0f bg (%.1f%%)" % [id, sim.peak_hp, sim.catalog_hp, err * 100.0])
		check(sim.curve_power.size() >= 20 and sim.peak_hp_rpm > sim.spec.idle_rpm and sim.peak_torque > 0.0,
			"%s: eğri %d nokta, tepe %d d/dk, tork %.0f Nm" % [id, sim.curve_power.size(), roundi(sim.peak_hp_rpm),
				sim.peak_torque])
	var partial: DynoSim = DynoSim.new(&"toyota_supra")
	partial.start_engine()
	partial.throttle = 0.6
	for i: int in 120:
		partial.step(1.0 / 60.0)
	_pull(partial, false)
	check(partial.pulls == 0, "yüksek devirden başlayan çekiş ölçüm sayılmaz")

	print("== çekiş (katalog) ==")
	for pair: Array in [[&"toyota_supra", false, true], [&"vw_golf_7", true, false], [&"nissan_skyline_r34", true, true]]:
		var d: DynoSim = DynoSim.new(pair[0])
		check(d.drives_front == pair[1] and d.drives_rear == pair[2], "%s: ön %s, arka %s" % [pair[0], d.drives_front,
			d.drives_rear])

	print("== gaz verme (vites yok) ==")
	var sim: DynoSim = DynoSim.new(&"toyota_supra")
	sim.start_engine()
	check(is_equal_approx(sim.rpm, sim.spec.idle_rpm) and sim.gear == sim.measure_gear() and sim.speed == 0.0,
		"marş: rölanti, ölçüm vitesinde (%d), merdane duruyor" % sim.gear)
	sim.throttle = 1.0
	for i: int in 90:
		sim.step(1.0 / 60.0)
	check(sim.rpm > sim.spec.redline_rpm * 0.97 and sim.limiter, "tam gaz 1,5 sn: kırmızıda kesici (%.0f)" % sim.rpm)
	check(absf(sim.spec.rpm_at(sim.speed, sim.gear - 1) / sim.rpm - 1.0) < 0.02,
		"merdane devre bağlı döner (%.0f km/sa)" % sim.kmh())
	check(sim.power_hp > sim.catalog_hp * 0.6, "kesicide güç kırmızı çizgideki gibi okunur (%.0f bg)" % sim.power_hp)
	sim.throttle = 0.5
	for i: int in 120:
		sim.step(1.0 / 60.0)
	var half: float = lerpf(sim.spec.idle_rpm, sim.spec.redline_rpm * 1.01, 0.5)
	check(absf(sim.rpm / half - 1.0) < 0.02 and not sim.limiter, "yarım gaz: devir yarıda durur (%.0f / %.0f)" % [sim.rpm, half])
	sim.throttle = 0.0
	for i: int in 150:
		sim.step(1.0 / 60.0)
	check(absf(sim.rpm - sim.spec.idle_rpm) < 50.0 and sim.speed < 0.05 and sim.power_hp == 0.0,
		"gaz bırakınca 2,5 sn'de rölanti, merdane durur (%.0f d/dk, %.1f km/sa)" % [sim.rpm, sim.kmh()])
	sim.stop_engine()
	check(not sim.running and sim.throttle == 0.0, "kontak kapandı")

	print("== modifiye ==")
	var stock: DynoSim = DynoSim.new(&"tofas_sahin")
	_pull(stock)
	var build: Dictionary = {&"motor": 3, &"turbo": 2, &"air": 2}
	var mod_hp: float = float(PerformanceMods.power_curve(&"tofas_sahin", build)["peak"])
	check(mod_hp > stock.peak_hp * 1.03, "modifiye yapı daha güçlü (%.0f → %.0f bg)" % [stock.peak_hp, mod_hp])
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)


## Rölantiden (start: marş) kesiciye tam gaz çeker, kesicide biraz tutar; çekişin süresi (sn).
func _pull(sim: DynoSim, start: bool = true) -> float:
	if start:
		sim.start_engine()
	sim.throttle = 1.0
	var t: float = 0.0
	while not sim.limiter and t < 10.0:
		sim.step(1.0 / 60.0)
		t += 1.0 / 60.0
	for i: int in 30:
		sim.step(1.0 / 60.0)
	return t
