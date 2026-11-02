extends SceneTree
## İNERKEN PATLAMA ölçümü (EngineVoice._update_decel_pops): aracın sesi gerçek oynatıcıyla, tam gazla kırmızıya çıkıp
## gaz kesik rölantiye iner (boşta, ~1,5 sn); kaç patlama çaldığını ve aralıklarını yazar. Ayrıca vitesteki yavaş iniş.
##   godot-4 --headless --path . -s res://qa/motor_patlama_olcum.gd -- <araç_id> …

var _player: AudioStreamPlayer


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var ids: Array[StringName] = []
	for arg: String in OS.get_cmdline_user_args():
		ids.append(StringName(arg))
	if ids.is_empty():
		ids = [&"toyota_supra", &"vw_golf_7", &"chevrolet_camaro"]
	for id: StringName in ids:
		for slow: bool in [false, true]:
			var player: AudioStreamPlayer = AudioStreamPlayer.new()
			root.add_child(player)
			var voice: EngineVoice = EngineVoice.new(player, EngineBank.for_vehicle(id))
			var idle: float = voice.bank.idle_rpm()
			var red: float = voice.bank.redline_rpm()
			var dt: float = 1.0 / 60.0
			var rpm: float = idle
			var times: PackedFloat32Array = PackedFloat32Array()
			var t: float = 0.0
			for i: int in 60 * 6:
				t += dt
				var throttle: float = 1.0 if t < 1.2 else 0.0
				if throttle > 0.0:
					rpm = minf(rpm + (red - idle) * 1.2 * dt, red)
				else:
					rpm = maxf(rpm - (red - idle) * (0.12 if slow else 0.7) * dt, idle)
				var before: int = voice.pops_played
				voice.update(dt, rpm, throttle)
				if voice.pops_played > before:
					times.append(t)
				await process_frame
			var gaps: PackedStringArray = PackedStringArray()
			for k: int in range(1, times.size()):
				gaps.append("%.2f" % (times[k] - times[k - 1]))
			print("%-18s %s: %d patlama, ilki %.2f sn, aralıklar [%s]" % [id, "vitesteki yavaş iniş" if slow else "boşta hızlı iniş",
				times.size(), times[0] if times.size() > 0 else -1.0, ", ".join(gaps)])
			voice.stop_all()
			player.queue_free()
	quit()
