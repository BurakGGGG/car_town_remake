extends SceneTree
## DİNAMOMETRE EKRANI QA (oyunun içinden): garaj → araca dokun (YAKINDAN İNCELE) → dino (motor kendiliğinden çalışır)
## → gaz pedalı (tam gaz çekiş = ölçüm, YENİ REKOR) → bırak → ikinci çekiş; sonra modifiye menüsü (üç kart) →
## DİNAMOMETRE kartı → GERİ (modifiyeye dönüş). Her adımda kare. Ses: dinoda müzik düzeyi, SFX tepe düzeyi, dino dışından çalan ses var mı.
##   CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/dino_ekran_qa.gd --resolution 1152x648 -- <çıktı> [<araç_id>]
const DEFAULT_OUT: String = "/home/burak/Projects/ct_shots/dino/ekran/"

var _out: String = DEFAULT_OUT
var _peak: float = -200.0
var _watching: bool = false
var _foreign: Array[String] = []
var _dyno_player: AudioStreamPlayer


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0].path_join("")
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred(StringName(args[1]) if args.size() > 1 else &"toyota_supra")


func _run(id: StringName) -> void:
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await _wait(4.0)
	var own: VehicleOwnership = get_first_node_in_group(&"vehicle_ownership") as VehicleOwnership
	if not own.is_owned(id):
		own.add_vehicle(id)
	var hud: Node = main.find_child("HUD", true, false)
	var router: UiRouter = hud.get("router")
	var garage: GarageScreen = hud.get("garage_screen")
	router.open(&"garage")
	await _wait(2.0)
	garage.call(&"_on_vehicle_selected", id)
	await _wait(1.5)
	garage.call(&"_on_interior_car_tapped", id)
	await _wait(1.4)
	await _shot("1_yakindan_incele")
	var inspect: PlateButton = garage.find_child("InspectButton", true, false) as PlateButton
	print("YAKINDAN İNCELE görünür: ", inspect != null and inspect.is_visible_in_tree())
	if inspect:
		inspect.pressed.emit()
	await _wait(1.5)
	print("dino açık: ", garage.is_dyno())
	var ds: Control = garage.find_child("DynoScreen", true, false) as Control
	print("BOYUT ekran ", ds.size, " ebeveyn ", (ds.get_parent() as Control).size, " çapa ", [ds.anchor_left, ds.anchor_right],
		" kenar ", [ds.offset_left, ds.offset_right], " margin ", (ds.get_node("Margin") as Control).size)
	await _shot("2_dino_acilis")
	var view: DynoView = garage.find_child("DynoView", true, false) as DynoView
	var screen: DynoScreen = garage.find_child("DynoScreen", true, false) as DynoScreen
	_audio_watch(view)
	print("çalışır hâlde geldi: ", view.sim.running, " marş sesi: ", view.voice.is_starting())
	await _wait(2.0)
	var music: AudioStreamPlayer = root.get_node_or_null("GameMusic") as AudioStreamPlayer
	print("SES müzik %.1f dB (taban %.1f), motor %.1f dB" % [music.volume_db if music else -99.0, GameMusic.BASE_DB,
		view.get("_player").volume_db])
	_peak = -200.0
	await _wait(1.0)
	print("rölanti SFX tepe %.1f dB" % _peak)
	var pedal: DynoPedal = screen.find_child("Pedal", true, false) as DynoPedal
	pedal.call(&"_apply_throttle", 1.0)
	_peak = -200.0
	await _wait(1.3)
	await _shot("3_dino_gaz")
	print("rekor yazısı: ", (screen.find_child("Best", true, false) as Label).text)
	print("gaz: %.0f d/dk, %.0f km/sa, SFX tepe %.1f dB" % [view.sim.rpm, view.sim.kmh(), _peak])
	pedal.call(&"_apply_throttle", 0.0)
	await _wait(2.5)
	print("bırakınca: %.0f d/dk, %.1f km/sa" % [view.sim.rpm, view.sim.kmh()])
	print("en iyi: %.0f bg, rekor yazısı: %s" % [view.best_hp(), (screen.find_child("Best", true, false) as Label).text])
	pedal.call(&"_apply_throttle", 1.0)
	await _wait(1.0)
	await _shot("4_dino_ikinci_gaz")
	pedal.call(&"_apply_throttle", 0.0)
	await _wait(0.4)
	await _shot("5_dino_birakinca")
	print("DIŞ SES (dinodayken çalan): ", _foreign if not _foreign.is_empty() else "yok")
	(screen.find_child("BackButton", true, false) as PlateButton).pressed.emit()
	await _wait(1.5)
	print("dino kapandı: ", not garage.is_dyno())
	_watching = false
	await _shot("6_garaja_donus")
	garage.open_mods()
	await _wait(2.0)
	await _shot("7_modifiye_menu")
	var card: PlateButton = garage.find_child("Menu_dyno", true, false) as PlateButton
	card.pressed.emit()
	await _wait(1.5)
	print("modifiyeden dino: ", garage.is_dyno())
	await _shot("8_modifiyeden_dino")
	garage.call(&"_on_exit_pressed")
	await _wait(1.8)
	print("modifiyeye dönüş: ", garage.is_modding(), " dino ", garage.is_dyno())
	await _shot("9_modifiyeye_donus")
	quit()


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(_out + name + ".png")


## Dinodayken her kare: SFX bus tepe düzeyi + dino motoru ve müzik dışında çalmaya BAŞLAYAN ses (ad, bus, düzey).
func _audio_watch(view: DynoView) -> void:
	_dyno_player = view.get("_player")
	_watching = true
	var sfx: int = AudioServer.get_bus_index(GameSettings.SFX_BUS)
	var seen: Dictionary = {}
	var frame: int = 0
	while _watching:
		await process_frame
		_peak = maxf(_peak, maxf(AudioServer.get_bus_peak_volume_left_db(sfx, 0), AudioServer.get_bus_peak_volume_right_db(sfx, 0)))
		frame += 1
		if frame % 12 != 0:
			continue
		for node: Node in root.find_children("*", "", true, false):
			var playing: bool = (node is AudioStreamPlayer and (node as AudioStreamPlayer).playing) \
				or (node is AudioStreamPlayer3D and (node as AudioStreamPlayer3D).playing)
			if not playing or node == _dyno_player or node is GameMusic or node.get_parent() is GameMusic or seen.has(node):
				continue
			seen[node] = true
			var bus: StringName = node.get(&"bus")
			var bus_db: float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus))
			_foreign.append("%s [%s %.0f dB, bus %.0f dB]" % [node.get_path(), bus, float(node.get(&"volume_db")), bus_db])
