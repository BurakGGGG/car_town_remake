extends SceneTree
## KEDİ SESİ QA (2026-11-02): yakın kamera açılır → selam → 3 sevme (mrrp + mırlama, söner) → numara (sevinç) → olta
## (cıvıltı) → kapanış. Master bus'ı kaydeder (müzik + garaj + kedi birlikte) ve olay çizelgesini basar; ölçüm / dinleme
## için ~/Projects/ct_shots/pets/ses/oyun_kaydi.wav. Garajda (yakın kamera dışında) kedinin sessiz kaldığını da sayar.
## Kullanım: QA_SAVE=<savegame.json> GODOT=<timeout sarmalayıcı> tools/qa_isolated.sh res://qa/pet_voice_qa.gd --resolution 1152x648
const OUT: String = "/home/burak/Projects/ct_shots/pets/ses/"

var _t0: int = 0
var _voice: PetVoice
var _last: StringName = &""
var _was_purring: bool = false


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	create_timer(150.0).timeout.connect(func() -> void: quit(2))   # takılırsa asılı kalmasın
	_run.call_deferred()


func _now() -> float:
	return (Time.get_ticks_msec() - _t0) / 1000.0


func _wait(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame
		_log_voice()


func _until(cond: Callable, limit: float) -> bool:
	var until: int = Time.get_ticks_msec() + int(limit * 1000.0)
	while Time.get_ticks_msec() < until:
		if cond.call():
			return true
		await process_frame
	return false


func _log_voice() -> void:
	if _voice == null:
		return
	if _voice.last_clip() != _last:
		_last = _voice.last_clip()
		print("  ·    %5.2f sn  ses   %s" % [_now(), _last])
	if _voice.purring() != _was_purring:
		_was_purring = _voice.purring()
		print("  ·    %5.2f sn  mırlama %s" % [_now(), "BAŞLADI" if _was_purring else "BİTTİ"])


func _mark(what: String) -> void:
	print("  ·    %5.2f sn  >> %s" % [_now(), what])


func _run() -> void:
	change_scene_to_file(String(ProjectSettings.get_setting("application/run/main_scene")))
	await _until(func() -> bool: return current_scene != null and current_scene.name != "LoadingScreen" \
		and current_scene.find_child("HUD", true, false) != null, 60.0)
	await _wait(3.0)
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	hud.router.close_all()
	var pets: PetManager = get_first_node_in_group("pets") as PetManager
	if not pets.is_adopted():
		pets.adopt("Tekir")
	await _wait(2.0)
	var closeup: PetCloseupScreen = hud.pet_closeup_screen
	_voice = closeup._voice
	var record: AudioEffectRecord = AudioEffectRecord.new()
	AudioServer.add_bus_effect(AudioServer.get_bus_index(&"Master"), record)
	record.set_recording_active(true)
	_t0 = Time.get_ticks_msec()
	_mark("garaj (yakın kamera kapalı) — 3 sn")
	await _wait(3.0)
	var garage_silent: bool = _voice.last_clip() == &"" and not _voice.purring()
	_mark("yakın kamera açılıyor")
	hud.router.open(&"pet_closeup")
	await _until(func() -> bool: return closeup._ready_to_pet, 15.0)
	_mark("kedi hazır (selam beklenir)")
	await _wait(2.0)
	for i: int in 3:
		var s: Dictionary = closeup._cat_screen()
		var press: InputEventMouseButton = InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = s["center"]
		_mark("SEV %d" % (i + 1))
		closeup._gui_input(press)
		await _wait(1.3)
	_mark("son sevme — mırlama ~%.1f sn sürüp sönmeli" % (PetVoice.PURR_HOLD + PetVoice.PURR_OUT))
	await _wait(PetVoice.PURR_HOLD + PetVoice.PURR_OUT + 0.8)
	_mark("NUMARA (pati ver)")
	closeup._world.closeup_clips([&"trick_paw"])
	_voice.happy(0.4)
	await _wait(3.0)
	_mark("OLTA")
	closeup._set_play(true)
	await _wait(1.0)
	var head: Vector2 = closeup._cat_screen()["head"]
	for k: int in 240:
		closeup._toy_target = head + Vector2(140.0 * sin(k * 0.35), -30.0 + 25.0 * sin(k * 0.9))
		await process_frame
		_log_voice()
	closeup._set_play(false)
	await _wait(1.5)
	_mark("kapanış")
	hud.router.back()
	await _wait(2.0)
	record.set_recording_active(false)
	var wav: AudioStreamWAV = record.get_recording()
	if wav:
		wav.save_to_wav(OUT + "oyun_kaydi.wav")
		print("  ·    kayıt %.1f sn → %soyun_kaydi.wav" % [wav.get_length(), OUT])
	print(("  OK   " if garage_silent else "  FAIL ") + "garajda kedi sessiz")
	print("SONUC: bitti")
	quit(0)
