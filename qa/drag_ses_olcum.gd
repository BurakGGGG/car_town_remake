extends "res://qa/drag_feel.gd"
## DRAG MOTOR SESİ DÜZEYİ QA (2026-11-02, kullanıcı: "araç sesleri dragta da çok kısık"): drag_feel'in yarışlarını koşturur,
## bu sırada yüksek motor sesi bus'ının (EngineVoice.LOUD_BUS, sınırlayıcı) ve SFX'in tepe düzeyini, müzik bus'ını ölçer.
##   CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/drag_ses_olcum.gd --resolution 1280x720 -- <çıktı> [<araç_id>]

var _peaks: Dictionary = {}


func _initialize() -> void:
	super._initialize()
	_meter.call_deferred()


func _meter() -> void:
	while true:
		await process_frame
		for bus: StringName in [EngineVoice.LOUD_BUS, GameSettings.SFX_BUS, GameSettings.MUSIC_BUS]:
			var index: int = AudioServer.get_bus_index(bus)
			if index < 0:
				continue
			var peak: float = maxf(AudioServer.get_bus_peak_volume_left_db(index, 0),
				AudioServer.get_bus_peak_volume_right_db(index, 0))
			if peak > float(_peaks.get(bus, -200.0)):
				_peaks[bus] = peak
				print("TEPE %s %.1f dB" % [bus, peak])
