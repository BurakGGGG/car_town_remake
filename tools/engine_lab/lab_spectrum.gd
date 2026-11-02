extends Control
## MOTOR SES LABORATUVARI — canlı spektrum (laboratuvar bus'ındaki AudioEffectSpectrumAnalyzer): 40 Hz–10 kHz
## logaritmik bantlar, tepe tutma. Hangi frekansın baskın olduğunu görmek için (uğultu, ıslık, hırıltı).

const BANDS: int = 56
const LOW_HZ: float = 40.0
const HIGH_HZ: float = 10000.0
const FLOOR_DB: float = -72.0

var analyzer: AudioEffectSpectrumAnalyzerInstance
var _levels: PackedFloat32Array = PackedFloat32Array()
var _peaks: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	custom_minimum_size = Vector2(0, 120)
	_levels.resize(BANDS)
	_levels.fill(0.0)
	_peaks.resize(BANDS)
	_peaks.fill(0.0)


func _process(delta: float) -> void:
	if analyzer == null:
		return
	for i: int in BANDS:
		var f0: float = LOW_HZ * pow(HIGH_HZ / LOW_HZ, float(i) / float(BANDS))
		var f1: float = LOW_HZ * pow(HIGH_HZ / LOW_HZ, float(i + 1) / float(BANDS))
		var mag: Vector2 = analyzer.get_magnitude_for_frequency_range(f0, f1)
		var db: float = linear_to_db(maxf(mag.length(), 1e-6))
		var level: float = clampf((db - FLOOR_DB) / -FLOOR_DB, 0.0, 1.0)
		_levels[i] = lerpf(_levels[i], level, 0.5)
		_peaks[i] = maxf(_peaks[i] - delta * 0.35, _levels[i])
	queue_redraw()


func _draw() -> void:
	var font: Font = get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), Color("101216"))
	var bw: float = size.x / float(BANDS)
	var h: float = size.y - 16.0
	for i: int in BANDS:
		var bar: float = h * _levels[i]
		var col: Color = Color("2E7D32").lerp(Color("F2C14E"), _levels[i]).lerp(Color("E74C3C"), maxf(_levels[i] - 0.8, 0.0) * 5.0)
		draw_rect(Rect2(i * bw + 1.0, h - bar, bw - 2.0, bar), col)
		draw_line(Vector2(i * bw + 1.0, h - h * _peaks[i]), Vector2((i + 1) * bw - 1.0, h - h * _peaks[i]), Color.WHITE, 1.0)
	for hz: float in [100.0, 300.0, 1000.0, 3000.0, 10000.0]:
		var x: float = size.x * log(hz / LOW_HZ) / log(HIGH_HZ / LOW_HZ)
		var text: String = ("%dk" % int(hz / 1000.0)) if hz >= 1000.0 else str(int(hz))
		draw_string(font, Vector2(x - 12.0, size.y - 2.0), text, HORIZONTAL_ALIGNMENT_CENTER, 24, 11, Color("8A93A3"))
