extends SceneTree
## Vitessiz dino hissi (DynoSim GAZ VERME kipi): tam gaz rölanti → kesici süresi, bırakınca rölantiye iniş süresi,
## %35 gazda 3 sn sonra devir. 2026-11-02 ilk ölçüm (eski atalet kipiyle, viteste): kesiciye 9–16 sn, rölantiye 19–30 sn.

func _initialize() -> void:
	for id: StringName in [&"toyota_supra", &"tofas_sahin", &"chevrolet_camaro", &"tesla_model_y", &"mercedes_sprinter", &"fiat_500"]:
		if CarCatalog.get_entry(id).is_empty():
			continue
		var sim: DynoSim = DynoSim.new(id)
		sim.start_engine()
		var dt: float = 1.0 / 60.0
		var t: float = 0.0
		sim.throttle = 1.0
		while t < 30.0 and not sim.limiter:
			sim.step(dt)
			t += dt
		var up: float = t
		for i: int in 60:
			sim.step(dt)
		sim.throttle = 0.0
		t = 0.0
		var half: float = -1.0
		var mid: float = (sim.spec.idle_rpm + sim.spec.redline_rpm) * 0.5
		while t < 60.0 and sim.rpm > sim.spec.idle_rpm * 1.05:
			sim.step(dt)
			t += dt
			if half < 0.0 and sim.rpm < mid:
				half = t
		# yarım gaz
		var sim2: DynoSim = DynoSim.new(id)
		sim2.start_engine()
		sim2.throttle = 0.35
		var t2: float = 0.0
		while t2 < 3.0:
			sim2.step(dt)
			t2 += dt
		print("%-20s vites %d  tam gaz kesiciye %.1f sn | bırakınca orta devre %.1f sn, rölantiye %.1f sn | %%35 gazla 3 sn: %d d/dk (kırmızı %d)" % [
			id, sim.gear, up, half, t, roundi(sim2.rpm), roundi(sim.spec.redline_rpm)])
	quit()
