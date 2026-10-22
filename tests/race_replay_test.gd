extends SceneTree
## KOŞU KAYDI + SABİT ADIM (docs/KOSU_ESLESTIRME.md, Faz 0): bitiş anı adımın içinde bulunur, koşu kaydı başsız tekrarda
## AYNI süreyi verir, kayıt JSON gidiş-dönüşünde bozulmaz ve pistteki yarış hangi kare hızında oynanırsa oynansın
## kaydından birebir tekrar edilir (oyuncu da rakip de).
## Çalıştırma: tools/run_tests.sh race_replay_test
var fails: int = 0


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


const CARS: Array[StringName] = [&"tofas_sahin", &"vw_golf_7", &"bmw_e46", &"ferrari_488_pista"]


func _run() -> void:
	assert(not OS.get_user_data_dir().ends_with("/AUTO YARD") and not OS.get_user_data_dir().ends_with("/CarTownRemake"))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20261021

	print("== 1) Bitiş anı adımın içinde ==")
	var quantized: int = 0
	for id: StringName in CARS:
		var time: float = DragRaceSim.drive(id, 0.0, 1.0, 1.0, null).time
		var steps: float = time / DragRaceSim.STEP
		if absf(steps - roundf(steps)) < 0.0001:
			quantized += 1
	check(quantized == 0, "bitiş süresi adım boyuna yuvarlanmıyor (%d / %d araçta adım katı)" % [quantized, CARS.size()])
	var one: DragRaceSim.Recording = DragRaceSim.ai_recording(&"bmw_e46", {}, DragRaceSim.roll_form(&"bmw_e46", null), null)
	var finish_step: int = ceili(one.time / DragRaceSim.STEP)
	check(one.time > float(finish_step - 1) * DragRaceSim.STEP and one.time <= float(finish_step) * DragRaceSim.STEP,
		"bitiş, çizginin geçildiği adımın içinde (%.4f sn, adım %d)" % [one.time, finish_step])

	print("== 2) Yapay zekâ kaydı = başsız tekrar ==")
	var mismatches: int = 0
	var worst: float = 0.0
	var count: int = 0
	for id: StringName in CARS:
		for k: int in 12:
			var mods: Dictionary = {} if k % 3 != 0 else {&"motor": 1 + k % 5, &"gear": 2, &"tire": 3}
			var recording: DragRaceSim.Recording = DragRaceSim.ai_recording(id, mods, DragRaceSim.roll_form(id, rng), rng)
			var again: DragRaceSim.Runner = DragRaceSim.replay(recording)
			count += 1
			worst = maxf(worst, absf(again.finish_time - recording.time))
			if again.finish_time != recording.time or recording.time <= 0.0:
				mismatches += 1
	check(mismatches == 0, "%d yapay zekâ koşusu tekrarda birebir aynı (en büyük fark %s sn)" % [count, str(worst)])
	var rival_run: DragRaceSim.Run = DragRaceSim.run_rival(&"vw_golf_7", rng)
	check(rival_run.time > DragRaceSim.base_time(&"vw_golf_7") * 0.85 and rival_run.time < 40.0,
		"run_rival ekrandaki yoldan sürer (%.2f sn)" % rival_run.time)

	print("== 3) Kayıt JSON gidiş-dönüşü ==")
	var source: DragRaceSim.Recording = DragRaceSim.ai_recording(&"bmw_e46", {&"motor": 3, &"turbo": 2},
		DragRaceSim.roll_form(&"bmw_e46", rng), rng)
	var text: String = JSON.stringify(source.to_dict())
	var parsed: Variant = JSON.parse_string(text)
	var back: DragRaceSim.Recording = DragRaceSim.Recording.from_dict(parsed) if parsed is Dictionary else null
	check(back != null, "kayıt JSON'dan okunur")
	if back:
		check(back.jitter == source.jitter and back.power == source.power and back.launch_rpm == source.launch_rpm,
			"sapma, güç ve kalkış devri bit bit aynı")
		check(back.shift_steps == source.shift_steps and back.launch_step == source.launch_step, "adımlar aynı")
		check(PerformanceMods.build_key(back.build) == PerformanceMods.build_key(source.build), "modifiyeler aynı")
		check(DragRaceSim.replay(back).finish_time == source.time, "okunan kayıt aynı süreyi verir (%.4f)" % source.time)
	var bad: Array[Dictionary] = []
	for change: Array in [["v", 999], ["car", "yok_boyle_arac"], ["s", [900, 800]], ["l", -5], ["j", 9999999],
			["s", [10, 20, 30, 40, 50, 60, 70, 80]], ["lr", -1]]:
		var copy: Dictionary = source.to_dict()
		copy[change[0]] = change[1]
		bad.append(copy)
	var rejected: int = 0
	for data: Dictionary in bad:
		if DragRaceSim.Recording.from_dict(data) == null:
			rejected += 1
	check(rejected == bad.size(), "bozuk kayıtlar reddedilir (%d / %d)" % [rejected, bad.size()])
	var never: DragRaceSim.Recording = DragRaceSim.Recording.begin(&"tofas_sahin", {}, rng)
	check(DragRaceSim.replay(never).finish_time < 0.0, "kalkmamış koşu tekrarda bitmez")

	print("== 4) Pistte: her kare hızında kayıt = tekrar ==")
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(12)
	var save: SaveManager = get_first_node_in_group("save_manager") as SaveManager
	save.new_game()
	await frames(2)
	var hud: Hud = main.find_child("HUD", true, false)
	var drag: DragRaceScreen = hud.drag_race_screen
	var patterns: Array = [
		["30 FPS", [1.0 / 30.0]],
		["60 FPS", [1.0 / 60.0]],
		["144 FPS", [1.0 / 144.0]],
		["titrek 60", [0.014, 0.019, 0.016, 0.021, 0.013, 0.017]],
		["takılmalı", [1.0 / 60.0, 1.0 / 60.0, 1.0 / 60.0, 0.09, 1.0 / 60.0, 0.004]],
	]
	var times: Array[float] = []
	for i: int in patterns.size():
		var row: Array = patterns[i]
		var result: Dictionary = _drive_race(drag, row[1], rng, i == patterns.size() - 1)
		var player_run: DragRaceSim.Run = drag.player_run()
		var rival: DragRaceSim.Run = drag.rival_run()
		var player_again: DragRaceSim.Runner = DragRaceSim.replay(drag.player_recording())
		var rival_again: DragRaceSim.Runner = DragRaceSim.replay(drag.rival_recording())
		check(player_run != null and player_again.finish_time == player_run.time,
			"%s: oyuncu %.4f sn — tekrar %.4f sn (%d vites, tepki %.3f)" % [row[0],
				player_run.time if player_run else -1.0, player_again.finish_time,
				drag.player_recording().shift_steps.size(), player_run.reaction if player_run else -1.0])
		check(player_run != null and player_again.shift_log == player_run.shift_log, "%s: vites kaliteleri aynı" % row[0])
		check(rival != null and rival_again.finish_time == rival.time and drag.rival_recording().time == rival.time,
			"%s: rakip pistte kaydındaki süreyi koştu (%.4f sn)" % [row[0], rival.time if rival else -1.0])
		check(int(result["max_steps"]) <= ceili(DragRaceScreen.MAX_FRAME_SIM / DragRaceSim.STEP) + 1,
			"%s: bir karede en çok %d adım" % [row[0], int(result["max_steps"])])
		if bool(result["false_start"]):
			check(drag.player_recording().false_start and player_run.reaction >= DragRaceSim.FALSE_START_PENALTY
					and player_run.reaction < DragRaceSim.FALSE_START_PENALTY + DragRaceSim.STEP * 1.5,
				"%s: hatalı çıkış kayda geçti, ceza süresinde kalktı (%.3f)" % [row[0], player_run.reaction])
		if player_run:
			times.append(player_run.time)
	drag.close()

	print("== 5) Aynı girdi, farklı kare hızı → aynı süre ==")
	# Pistteki ilk koşunun girdileri adım adım, kare hızı çok farklı iki döngüde yeniden verilir.
	var template: DragRaceSim.Recording = DragRaceSim.ai_recording(&"vw_golf_7", {}, DragRaceSim.roll_form(&"vw_golf_7", rng), rng)
	var slow: float = _loop_with_frames(template, 1.0 / 24.0)
	var fast: float = _loop_with_frames(template, 1.0 / 240.0)
	check(slow == template.time and fast == template.time,
		"24 FPS %.4f · 240 FPS %.4f · kayıt %.4f" % [slow, fast, template.time])

	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)


## Pistteki yarışı `deltas` kare dizisiyle elle sürer; oyuncu yeşilde / sınırda vites atar (bazen kaçırır).
func _drive_race(drag: DragRaceScreen, deltas: Array, rng: RandomNumberGenerator, false_start: bool) -> Dictionary:
	drag.open()
	drag.set_process(false)
	for connection: Dictionary in drag.race_completed.get_connections():
		drag.race_completed.disconnect(connection["callable"])
	var launch_at: float = rng.randf_range(0.12, 0.40)
	var frame: int = 0
	var max_steps: int = 0
	var tapped_early: bool = false
	while drag.get("_phase") != DragRaceScreen.Phase.DONE and frame < 20000:
		var delta: float = float(deltas[frame % deltas.size()])
		frame += 1
		var before: int = drag.get("_steps")
		drag._process(delta)
		if drag.get("_phase") == DragRaceScreen.Phase.RUNNING:
			max_steps = maxi(max_steps, int(drag.get("_steps")) - before)
		var phase: int = drag.get("_phase")
		var player: DragRaceSim.Runner = drag.get("_player")
		if phase == DragRaceScreen.Phase.COUNTDOWN and false_start and not tapped_early \
				and float(drag.get("_countdown")) < 0.5:
			tapped_early = true
			drag.tap()
		elif phase == DragRaceScreen.Phase.RUNNING:
			if not player.running:
				if not false_start and float(drag.get("_time")) >= launch_at:
					drag.tap()
			elif player.finish_time < 0.0 and (bool(drag.get("_shift_hot")) and rng.randf() < 0.45
					or player.is_red() and rng.randf() < 0.3):
				drag.tap()
	for connection: Dictionary in drag.race_completed.get_connections():
		drag.race_completed.disconnect(connection["callable"])
	return {"max_steps": max_steps, "false_start": tapped_early}


## Ekranın sabit adım döngüsünün başsız eşi: kayıt girdileri adım numarasıyla, kareler `frame` boyunda.
func _loop_with_frames(recording: DragRaceSim.Recording, frame: float) -> float:
	var runner: DragRaceSim.Runner = recording.make_runner()
	var left: float = 0.0
	var steps: int = 0
	while runner.finish_time < 0.0 and steps < DragRaceSim.MAX_STEPS:
		left += frame
		while left >= DragRaceSim.STEP:
			left -= DragRaceSim.STEP
			recording.play(runner, steps)
			steps += 1
			runner.step(DragRaceSim.STEP, float(steps) * DragRaceSim.STEP)
	return runner.finish_time
