extends Node
## TELEFON KARE SONDASI — gerçek cihazda kare süresini neyin doldurduğunu ölçer (release APK, logcat'e yazar):
## 3B çözünürlük %100 / %85 / %70 / %50, 3B kapalı, HUD gizli aşamalarında kaç kare çizilebildiği.
## Geçici kurulum (qa/ pakete girmez): dosya gameplay/'e kopyalanır, GameSettings._ready sonuna
## `add_child(load("res://gameplay/<kopya>.gd").new())` eklenir, APK derlenir, ikisi de geri alınır.
## Okuma: `adb logcat -d | grep SONDA`. Ekrana çıkan kareler için ayrıca tools/telefon_kare_olcum.py.
##
## Android'de GL dikey eşitlemesi kapanmıyor (window_set_vsync_mode etkisiz) ve Godot kare süresini yenilemeye
## yuvarlıyor (delta smoothing): kapasiteyi görebilmek için ölçüm boyunca FPS sınırı kalkar ve pencere en yüksek ekran
## hızını ister (DisplayRate, 90 Hz); bitince oyunun 60 Hz isteği geri konur. Ekran 60 Hz'den hızlı değilse bütün
## aşamalar 60'ta görünür — sonuç okunamaz. 2026-10-26 Samsung A24 (90 Hz): %100 ≈ 60, %85 ≈ 65, %70 ≈ 80,
## %50 ve 3B kapalı 89 (tavan), HUD gizli ≈ 66 kare/sn — darboğaz 3B'nin piksel doldurması.
## Aşamalar sırayla; her aşamanın ilk 2 sn'si atılır (ısınma), kalan sürede kare süreleri toplanır.

const WAIT_START: float = 25.0
## Ölçüm süresince istenen ekran hızı (telefonda yoksa sistem en yakın üst modu seçmez: 60'ta kalır).
const PROBE_RATE: int = 90
const PHASE_SECONDS: float = 9.0
const WARMUP: float = 2.0
const PHASES: Array[Dictionary] = [
	{"name": "taban %100", "scale": 1.0},
	{"name": "3B %85", "scale": 0.85},
	{"name": "3B %70", "scale": 0.7},
	{"name": "3B %50", "scale": 0.5},
	{"name": "3B KAPALI", "scale": 1.0, "no3d": true},
	{"name": "HUD GİZLİ", "scale": 1.0, "nohud": true},
	{"name": "taban %100 (tekrar)", "scale": 1.0},
]

var _t: float = 0.0
var _phase: int = -1
var _phase_t: float = 0.0
var _frames: PackedFloat32Array = PackedFloat32Array()
var _render_cpu: float = 0.0
var _setup_cpu: float = 0.0
var _physics: float = 0.0
var _samples: int = 0
var _calls: float = 0.0
var _prims: float = 0.0
var _hidden: Array[CanvasLayer] = []
var _cycle: int = 0


func _ready() -> void:
	process_priority = -1000
	print("SONDA hazır, %d sn sonra başlar (GPU %s)" % [int(WAIT_START), RenderingServer.get_video_adapter_name()])


func _process(delta: float) -> void:
	_t += delta
	if _phase < 0:
		if _t >= WAIT_START:
			Engine.max_fps = 0
			DisplayRate.request(PROBE_RATE)
			RenderingServer.viewport_set_measure_render_time(get_tree().root.get_viewport_rid(), true)
			_start(0)
		return
	_phase_t += delta
	if _phase_t > WARMUP:
		_frames.append(delta * 1000.0)
		var vp: RID = get_tree().root.get_viewport_rid()
		_render_cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		_setup_cpu += RenderingServer.get_frame_setup_time_cpu()
		# Fizik monitörü saniyede bir güncellenir (son saniyenin en uzunu); süreç monitörü dikey eşitleme beklemesini de
		# sayıyor — yazılmaz
		_physics += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		_calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		_prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		_samples += 1
	if _phase_t >= PHASE_SECONDS:
		_report()
		if _phase + 1 < PHASES.size():
			_start(_phase + 1)
		elif _cycle == 0:
			_cycle = 1
			_start(0)
		else:
			_restore()
			Engine.max_fps = GameSettings.FPS_NORMAL
			DisplayRate.request(GameSettings.FPS_NORMAL)
			print("SONDA bitti")
			set_process(false)


func _start(index: int) -> void:
	_restore()
	_phase = index
	_phase_t = 0.0
	_frames.clear()
	_render_cpu = 0.0
	_setup_cpu = 0.0
	_physics = 0.0
	_samples = 0
	_calls = 0.0
	_prims = 0.0
	var phase: Dictionary = PHASES[index]
	var root: Window = get_tree().root
	root.scaling_3d_scale = float(phase["scale"])
	root.disable_3d = bool(phase.get("no3d", false))
	if bool(phase.get("nohud", false)):
		for layer: Node in root.find_children("*", "CanvasLayer", true, false):
			if (layer as CanvasLayer).visible:
				(layer as CanvasLayer).visible = false
				_hidden.append(layer as CanvasLayer)


func _restore() -> void:
	var root: Window = get_tree().root
	root.scaling_3d_scale = 1.0
	root.disable_3d = false
	for layer: CanvasLayer in _hidden:
		if is_instance_valid(layer):
			layer.visible = true
	_hidden.clear()


func _report() -> void:
	if _frames.is_empty():
		return
	var sorted: PackedFloat32Array = _frames.duplicate()
	sorted.sort()
	var total: float = 0.0
	var over: int = 0
	for ms: float in _frames:
		total += ms
		if ms > 16.7:
			over += 1
	var n: float = float(_samples)
	print("SONDA %-20s fps %5.1f | kare ort %5.2f med %5.2f p95 %5.2f maks %6.2f ms | >16,7ms %%%4.1f | çizim-cpu %5.2f kurulum %5.2f fizik(maks) %5.2f ms | çağrı %4d üçgen %6dk" % [
		PHASES[_phase]["name"], 1000.0 * _frames.size() / total, total / _frames.size(),
		sorted[sorted.size() / 2], sorted[int(sorted.size() * 0.95)], sorted[sorted.size() - 1],
		100.0 * over / _frames.size(), _render_cpu / n, _setup_cpu / n, _physics / n,
		int(_calls / n), int(_prims / n / 1000.0)])
