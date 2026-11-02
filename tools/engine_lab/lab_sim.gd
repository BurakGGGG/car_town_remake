extends RefCounted
## MOTOR SES LABORATUVARI — sürüş benzetimi. Devir, gaz (yük), vites ve devir kesiciyi üretir; laboratuvar bunları
## her kare EngineVoice'a verir. Üç kip:
##   BOŞ    — vites boşta: pedal devri yükseltir, bırakınca motor freniyle düşer; kırmızıda kesici.
##   VİTES  — basit araç: hız ↔ devir vites oranıyla; otomatik (ya da Boşluk ile) vites atar, geçişte gaz kesilir.
##   ELLE   — devir ve gaz doğrudan sürgülerden.
## Senaryolar (düğmeler): kısa adımlar listesi [süre, pedal, olay].

enum Mode { FREE, GEARS, MANUAL }

const GEAR_RATIOS: Array[float] = [3.6, 2.15, 1.5, 1.15, 0.92, 0.78]
## Vites geçişinde gazın kesik kaldığı süre (sn).
const SHIFT_TIME: float = 0.22
## Devir = hız (m/sn) × oran × bu (1. vites kırmızıya ~50 km/sa'te varır).
const RPM_PER_SPEED: float = 125.0

var mode: Mode = Mode.FREE
var idle: float = 850.0
var red: float = 6500.0
var electric: bool = false

var pedal: float = 0.0          # girdi (klavye / senaryo)
var manual_rpm: float = 850.0
var manual_throttle: float = 0.0
var auto_shift: bool = true

var rpm: float = 850.0
var throttle: float = 0.0       # sese giden yük
var gear: int = 0
var speed: float = 0.0          # m/sn (VİTES kipi)
var limiter: bool = false
var shift_left: float = 0.0
## Senaryo sırasında olaylar (vites atıldı → patlama vb.): laboratuvar okuyup boşaltır.
var events: Array[String] = []

var _script: Array = []
var _script_t: float = 0.0
var _script_i: int = 0


func configure(idle_rpm: float, redline_rpm: float, is_electric: bool) -> void:
	idle = maxf(idle_rpm, 0.0)
	red = maxf(redline_rpm, idle + 500.0)
	electric = is_electric
	rpm = idle if not electric else 0.0
	manual_rpm = maxf(idle, 1000.0)


func step(delta: float) -> void:
	_run_script(delta)
	match mode:
		Mode.MANUAL:
			rpm = move_toward(rpm, manual_rpm, (red - idle) * 3.0 * delta)
			throttle = manual_throttle
			limiter = false
		Mode.FREE:
			_free(delta)
		Mode.GEARS:
			_gears(delta)


func _free(delta: float) -> void:
	var span: float = red - idle
	if electric:
		# Elektrik: boşta motor yok gibi — pedal "tekerleri havada" döndürür
		var goal: float = pedal * red * 0.6
		rpm = move_toward(rpm, goal, span * (0.9 if goal > rpm else 0.5) * delta)
		throttle = pedal
		limiter = false
		return
	if pedal > 0.02:
		rpm += span * 1.7 * pedal * (1.0 - 0.45 * (rpm - idle) / span) * delta
	else:
		rpm -= span * 0.85 * delta * (0.4 + 0.6 * (rpm - idle) / span)
	limiter = rpm >= red and pedal > 0.5
	if limiter:
		rpm = red - span * 0.025 * randf()
	rpm = clampf(rpm, idle, red)
	throttle = pedal


func _gears(delta: float) -> void:
	if shift_left > 0.0:
		shift_left -= delta
		throttle = 0.0
		var goal: float = _rpm_at(speed, gear)
		rpm = move_toward(rpm, goal, (red - idle) * 4.0 * delta)
		speed = maxf(speed - 0.6 * delta, 0.0)
		return
	var ratio: float = GEAR_RATIOS[gear]
	var power: float = 1.0 if electric else clampf(0.55 + 0.6 * (rpm - idle) / (red - idle), 0.4, 1.0)
	var accel: float = pedal * 9.5 * ratio / GEAR_RATIOS[0] * power - (0.25 + 0.0009 * speed * speed) - (1.0 - pedal) * 0.9
	speed = maxf(speed + accel * delta, 0.0)
	var geared: float = _rpm_at(speed, gear)
	if gear == 0 and not electric:
		# Kalkış: debriyaj kaydırır (devir tutulur)
		geared = maxf(geared, lerpf(idle, red * 0.55, pedal))
	rpm = move_toward(rpm, clampf(geared, idle, red), (red - idle) * 3.5 * delta)
	limiter = not electric and geared >= red and pedal > 0.5
	if limiter:
		speed = minf(speed, red / (GEAR_RATIOS[gear] * RPM_PER_SPEED) * 0.98)
	throttle = pedal
	if electric:
		return
	if auto_shift and pedal > 0.5 and rpm >= red * 0.94 and gear < GEAR_RATIOS.size() - 1:
		shift_up()
	elif gear > 0 and rpm < idle * 1.35 and pedal < 0.1:
		gear -= 1


## Devir = hız × oran × RPM_PER_SPEED (benzetim ölçeği; gerçek oranlar değil, kulağa doğru gelen eğri).
func _rpm_at(speed_value: float, gear_index: int) -> float:
	if electric:
		return speed_value * 260.0
	return speed_value * GEAR_RATIOS[gear_index] * RPM_PER_SPEED


func shift_up() -> void:
	if mode != Mode.GEARS or gear >= GEAR_RATIOS.size() - 1 or shift_left > 0.0:
		return
	gear += 1
	shift_left = SHIFT_TIME
	events.append("shift")


func shift_down() -> void:
	if mode != Mode.GEARS or gear <= 0:
		return
	gear -= 1
	events.append("downshift")


## Senaryo: [[süre, pedal (-1 = dokunma), olay ("" / "gears" / "free" / "stop" / "start" / "shift")], …]
func play(steps: Array) -> void:
	_script = steps
	_script_t = 0.0
	_script_i = 0
	if not _script.is_empty():
		_enter(_script[0])


func is_scripted() -> bool:
	return _script_i < _script.size()


func cancel_script() -> void:
	_script = []
	_script_i = 0


func _run_script(delta: float) -> void:
	if _script_i >= _script.size():
		return
	_script_t += delta
	while _script_i < _script.size() and _script_t >= float(_script[_script_i][0]):
		_script_t -= float(_script[_script_i][0])
		_script_i += 1
		if _script_i < _script.size():
			_enter(_script[_script_i])
	if _script_i >= _script.size():
		pedal = 0.0


func _enter(step_value: Array) -> void:
	var p: float = float(step_value[1])
	if p >= 0.0:
		pedal = p
	var event: String = step_value[2]
	match event:
		"gears":
			mode = Mode.GEARS
			gear = 0
			speed = 0.0
		"free":
			mode = Mode.FREE
		"shift":
			shift_up()
		"":
			pass
		_:
			events.append(event)


# --- Hazır senaryolar ------------------------------------------------------------------------------------------

static func blip() -> Array:
	return [[0.32, 1.0, "free"], [1.4, 0.0, ""]]


static func triple_blip() -> Array:
	return [[0.25, 1.0, "free"], [0.45, 0.0, ""], [0.3, 1.0, ""], [0.45, 0.0, ""], [0.45, 1.0, ""], [1.6, 0.0, ""]]


static func limiter_run() -> Array:
	return [[3.2, 1.0, "free"], [1.8, 0.0, ""]]


static func launch() -> Array:
	return [[1.2, 0.0, "gears"], [1.0, 0.65, ""], [7.5, 1.0, ""], [3.0, 0.0, ""], [0.5, 0.0, "free"]]


static func cruise() -> Array:
	return [[0.5, 0.0, "gears"], [2.5, 0.8, ""], [0.1, 0.8, "shift"], [2.0, 0.6, ""], [0.1, 0.5, "shift"],
		[4.0, 0.32, ""], [3.0, 0.0, ""], [0.5, 0.0, "free"]]
