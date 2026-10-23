extends SceneTree
## SÜPER ARABA TANITIMI QA: 2 yarışı bitmiş oyuncu gibi başlar, 3. rakibi (beyaz OVALE ÉCLAIR) getirir, yarışı oto-sürer
## (yeşilde kalkış, ideal devirde vites) ve dünya daveti → davet panosu → pist → sonuç → "BİR GÜN SENİN DE OLACAK!"
## karelerini alır. Kaydı değiştirir: yalıtılmış klasörde çalıştırın.
## Kullanım: CT_NO_TUTORIAL=1 QA_SAVE=<kayıt> tools/qa_isolated.sh res://qa/supercar_showcase_shots.gd \
##   --resolution 1280x720 [-- <çıktı_klasörü>]
const DEFAULT_OUT: String = "/home/burak/Projects/ct_shots/supercar_showcase/"

var _out: String = DEFAULT_OUT
var _hud: Hud
var _race: RaceManager
var _drag: DragRaceScreen


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0].path_join("")
	DirAccess.make_dir_recursive_absolute(_out)
	for file: String in DirAccess.get_files_at(_out):
		DirAccess.remove_absolute(_out + file)
	_run.call_deferred()


func _wait(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _shot(label: String) -> void:
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(_out + label + ".png")
	print("QA kare ", label)


func _run() -> void:
	change_scene_to_file(String(ProjectSettings.get_setting("application/run/main_scene")))
	var until: int = Time.get_ticks_msec() + 40000
	while Time.get_ticks_msec() < until and (current_scene == null or current_scene.name == "LoadingScreen" \
			or root.get_node_or_null("LoadingScreen") != null):
		await process_frame
	await _wait(1.5)
	_hud = current_scene.find_child("HUD", true, false) as Hud
	_race = get_first_node_in_group("race") as RaceManager
	_drag = _hud.drag_race_screen
	var own: VehicleOwnership = get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	if not own.is_owned(&"tofas_sahin"):
		own.add_vehicle(&"tofas_sahin")
	own.set_race_vehicle(&"tofas_sahin")
	_race.release_challenger()
	_race.showcase_enabled = true
	_race.load_state({"races": RaceManager.SHOWCASE_AFTER, "wins": 1})
	_race.challenge_timeout = 600.0
	until = Time.get_ticks_msec() + 40000
	while Time.get_ticks_msec() < until and not _race.has_challenge():
		await process_frame
		_race.request_challenge_now()
	print("QA rakip: %s sahibi %s tanıtım %s" % [_race.rival_id(), _race.rival_owner().get("name", ""), _race.is_showcase()])
	await _wait(2.0)
	_shot("1_davet_dunya")
	_hud.router.open(&"race_challenge")
	await _wait(1.2)
	_shot("2_davet_panosu")
	_hud.race_challenge_screen.race_accepted.emit()
	await _drive()
	await _wait(2.5)
	_shot("5_sonuc")
	_hud.race_result_screen.exit_requested.emit()
	await _wait(1.6)
	_shot("6_hedef")
	await _wait(2.0)
	_shot("6_hedef_b")
	quit(0)


func _drive() -> void:
	await _wait(0.5)
	var taken: Dictionary = {}
	var guard: int = 0
	while int(_drag.get("_phase")) != DragRaceScreen.Phase.DONE and guard < 60 * 90:
		await process_frame
		guard += 1
		if int(_drag.get("_phase")) != DragRaceScreen.Phase.RUNNING:
			continue
		var player: DragRaceSim.Runner = _drag.get("_player")
		var t: float = _drag.get("_time")
		if not player.running and t > 0.18:
			_drag.tap()
		elif player.running and player.gear < player.top_gear() and player.clutch <= 0.0 \
				and not player.shifting and player.rpm >= player.spec.shift_rpm[player.gear] * 0.995:
			_drag.tap()
		for at: float in [1.2, 3.5, 7.2]:
			if t >= at and not taken.has(at):
				taken[at] = true
				_shot("%d_pist_t%.1f" % [3 if at < 3.0 else 4, at])
	var player_run: DragRaceSim.Run = _drag.player_run()
	var rival_run: DragRaceSim.Run = _drag.rival_run()
	print("QA süreler: oyuncu %.3f rakip %.3f" % [player_run.time if player_run else -1.0, rival_run.time if rival_run else -1.0])
