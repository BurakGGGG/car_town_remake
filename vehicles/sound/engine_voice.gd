class_name EngineVoice
extends RefCounted
## MOTOR SESİ OYNATICISI (2026-11-02). Bir AudioStreamPlayer ya da AudioStreamPlayer3D'ye AudioStreamPolyphonic takar
## ve aracın pişmiş bankasını (EngineBank) çalar. Sahibi her kare update(devir, gaz) ile besler; düzeyi (oyuncu /
## rakip / trafik) sahibi player.volume_db ile verir, aracın kendi gürlüğü (level_db) burada eklenir.
##
## KATMANLAR: devire en yakın iki katman eşit güçle karışır (log-devir aralığında) ve her biri devir / katman devri
## kadar perdelenir (en çok yarım aralık) → "sincap" yok. Gaz açık / kesik döngüleri gaz oranıyla eşit güçle karışır.
## LITE (trafik): yalnız baskın yük takımı (eşikte gecikmeli geçiş) → çoğu an 2 akış.
## EK: turbo basıncı (gecikmeli dolar, gaz kesince düşer) → ıslık; gaz bırakınca blow-off ve egzoz patlamaları
## (patlama sıklığı bankada); yüksek devirden gaz kesik inerken ritimli "pat pat pat" (decel_pops / pop_interval /
## pop_rpm); devir kesici kesik kesik; marş (rölantiye oturunca döngüler açılır), kontak kapatma.

## Egzoz patlaması çaldı (`strength` 0–1): dino atölyesi alevi bununla eş zamanlar.
signal popped(strength: float)

const POLYPHONY: int = 12
## Katman kazancının yumuşatma hızı (1/sn): devir sıçramasında tık olmasın, gecikme de hissedilmesin.
const GAIN_RATE: float = 30.0
## Kazancı bu kadar süre sıfırda kalan akış durdurulur.
const RELEASE_AFTER: float = 0.25
const SILENT: float = 0.0006
## Lite modda gaz açık takıma geçiş / dönüş eşikleri (gecikmeli).
const LITE_ON: float = 0.55
const LITE_OFF: float = 0.3
## Gaz bırakma algısı: gaz bundan yüksekken bunun altına inerse "bırakıldı".
const LIFT_FROM: float = 0.55
const LIFT_TO: float = 0.25
const STOP_FADE: float = 25.0

var bank: EngineBank
var player: Node
var lite: bool = false
## Kontak açık mı (kapalıyken döngüler susar; marş / kapatma tek seferlik çalar).
var running: bool = true
## Katmanlar arası gürlük farkının ne kadarı çalınır: 1 = pişmiş haliyle (drag, laboratuvar), 0,5 = farklar yarıya
## (trafik: rölanti ile tam gaz arası ~18 dB yerine ~9 dB — "kafa ağrıtmasın"). Ortalama düzey en gür katmana göre.
var dynamics: float = 1.0

var rpm: float = 0.0
var throttle: float = 0.0
var boost: float = 0.0

var _pb: AudioStreamPlaybackPolyphonic
var _ids: Dictionary = {}       # anahtar → akış kimliği (katman: i, gaz kesik: 100+i, ıslık: 200)
var _gains: Dictionary = {}     # anahtar → yumuşatılmış doğrusal kazanç
var _quiet: Dictionary = {}     # anahtar → sıfırda geçen süre
var _dying: Array = []          # banka değişince sönmekte olan akışlar (sonraki karede durur)
var _lite_on: bool = false
var _prev_throttle: float = 0.0
var _time: float = 0.0
var _pops_left: int = 0
var _pop_timer: float = 0.0
var _overrun_timer: float = 0.0
var _decel_timer: float = 0.0
var _last_rpm: float = 0.0
var _falling: float = 0.0       # devir düşüş hızı (d/dk/sn, yumuşatılmış; düşerken pozitif)
## Çalınan patlama sayısı (QA / test).
var pops_played: int = 0
var _starting: float = -1.0     # marş sesi başladığından beri (sn); -1 = marş yok
var _master: float = 1.0        # kontak kapatma / açma yumuşatması
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(target: Node, engine_bank: EngineBank, lite_mode: bool = false) -> void:
	player = target
	bank = engine_bank
	lite = lite_mode
	_rng.randomize()
	rpm = bank.idle_rpm() if bank else 0.0
	var poly: AudioStreamPolyphonic = AudioStreamPolyphonic.new()
	poly.polyphony = POLYPHONY
	player.set("stream", poly)


## Banka değişti (laboratuvar yeniden pişirdi / araç değişti): eski akışlar bir karıştırma tamponunda söner, yenileri
## aynı kazançla sessizden açılır (~20 ms çapraz geçiş).
func set_bank(engine_bank: EngineBank) -> void:
	if _pb:
		for key: int in _ids:
			_pb.set_stream_volume(_ids[key], -80.0)
		_dying.append_array(_ids.values())
	_ids.clear()
	_quiet.clear()
	bank = engine_bank


func stop_all() -> void:
	if _pb:
		for key: int in _ids:
			_pb.stop_stream(_ids[key])
	_ids.clear()
	_gains.clear()
	_quiet.clear()


## Oynatıcı çalmıyorsa başlatır ve oynatma nesnesini alır (durdurulup yeniden başlatılmış olabilir).
func _ensure() -> bool:
	if not player.is_inside_tree():
		return false
	if not bool(player.get("playing")):
		player.call("play")
		_ids.clear()
		_gains.clear()
		_quiet.clear()
		_pb = null
	if _pb == null:
		_pb = player.call("get_stream_playback") as AudioStreamPlaybackPolyphonic
	return _pb != null


## Her kare: `rpm_value` motor devri (d/dk, bankanın aralığında), `throttle_value` 0–1, `limiter` devir kesicide.
func update(delta: float, rpm_value: float, throttle_value: float, limiter: bool = false) -> void:
	if bank == null or delta <= 0.0 or not _ensure():
		return
	if bool(player.get("stream_paused")):
		return
	for id: int in _dying:
		_pb.stop_stream(id)
	_dying.clear()
	_time += delta
	rpm = clampf(rpm_value, 0.0, bank.redline_rpm() * 1.08)
	_falling = lerpf(_falling, (_last_rpm - rpm) / delta, 1.0 - exp(-12.0 * delta))
	_last_rpm = rpm
	throttle = clampf(throttle_value, 0.0, 1.0)
	var lifted: bool = _prev_throttle > LIFT_FROM and throttle < LIFT_TO
	_prev_throttle = throttle
	var norm: float = clampf((rpm - bank.idle_rpm()) / maxf(bank.redline_rpm() - bank.idle_rpm(), 1.0), 0.0, 1.0)
	_update_boost(delta, norm, lifted)
	if lifted:
		_on_lift(norm)
	_update_pops(delta, norm, limiter)
	_update_decel_pops(delta, norm)
	if _starting >= 0.0:
		_starting += delta
		if _starting > bank.start_idle_at + 1.0:
			_starting = -1.0
	var target_master: float = 1.0 if running and (_starting < 0.0 or _starting >= bank.start_idle_at - 0.12) else 0.0
	_master = move_toward(_master, target_master, delta * (4.0 if target_master > _master else STOP_FADE))

	var targets: Dictionary = {}
	if _master > 0.0 and not (bank.is_electric() and rpm < 40.0):
		_layer_targets(targets, norm, limiter)
	if bank.whistle and boost > 0.02:
		targets[200] = pow(boost, 1.5) * db_to_linear(bank.get_runtime("whistle_db", -24.0)) * _master
	_apply(targets, delta)


func _layer_targets(targets: Dictionary, norm: float, limiter: bool) -> void:
	var rpms: PackedFloat32Array = bank.rpms
	var count: int = rpms.size()
	var r: float = clampf(rpm, rpms[0] * 0.5, rpms[count - 1] * 1.3)
	var lo: int = 0
	while lo < count - 2 and r > rpms[lo + 1]:
		lo += 1
	var w: float = clampf(log(r / rpms[lo]) / log(rpms[lo + 1] / rpms[lo]), 0.0, 1.0)
	var g_lo: float = cos(w * PI * 0.5)
	var g_hi: float = sin(w * PI * 0.5)
	var on_w: float
	var off_w: float
	if lite:
		if throttle > LITE_ON:
			_lite_on = true
		elif throttle < LITE_OFF:
			_lite_on = false
		on_w = 1.0 if _lite_on else 0.0
		off_w = 1.0 - on_w
	else:
		on_w = sin(throttle * PI * 0.5)
		off_w = cos(throttle * PI * 0.5)
	if limiter:
		var cut: bool = fmod(_time * bank.get_runtime("limiter_hz", 14.0), 1.0) < bank.get_runtime("limiter_duty", 0.45)
		if cut:
			on_w *= 0.12
			off_w = maxf(off_w, 0.5)
	on_w *= _master
	off_w *= _master
	targets[lo] = g_lo * on_w
	targets[lo + 1] = g_hi * on_w
	targets[100 + lo] = g_lo * off_w
	targets[101 + lo] = g_hi * off_w


func _apply(targets: Dictionary, delta: float) -> void:
	var keys: Dictionary = {}
	for key: int in targets:
		keys[key] = true
	for key: int in _ids:
		keys[key] = true
	var level: float = bank.get_runtime("level_db", 0.0)
	var k: float = 1.0 - exp(-GAIN_RATE * delta)
	for key: int in keys:
		var target: float = float(targets.get(key, 0.0))
		var gain: float = float(_gains.get(key, 0.0))
		gain += (target - gain) * k
		if target <= SILENT and gain < SILENT * 2.0:
			gain = 0.0
		_gains[key] = gain
		var pitch: float = _pitch_of(key)
		if _ids.has(key):
			var id: int = _ids[key]
			if not _pb.is_stream_playing(id):
				_ids.erase(key)
				continue
			if gain <= 0.0:
				_quiet[key] = float(_quiet.get(key, 0.0)) + delta
				_pb.set_stream_volume(id, -80.0)
				if float(_quiet[key]) > RELEASE_AFTER:
					_pb.stop_stream(id)
					_ids.erase(key)
					_gains.erase(key)
					_quiet.erase(key)
				continue
			_quiet[key] = 0.0
			_pb.set_stream_volume(id, linear_to_db(gain) + level + _compress_db(key))
			_pb.set_stream_pitch_scale(id, pitch)
		elif gain > SILENT:
			var stream: AudioStreamWAV = _stream_of(key)
			if stream == null:
				continue
			# Sessiz başlar, hemen hedefe ayarlanır: karıştırıcı ilk tamponda rampayla açar (rastgele noktadan
			# başlayan döngü çıt etmez)
			var id: int = _pb.play_stream(stream, _rng.randf() * stream.get_length() * 0.9, -60.0, pitch,
				AudioServer.PLAYBACK_TYPE_DEFAULT, StringName(player.get("bus")))
			if id != AudioStreamPlaybackPolyphonic.INVALID_ID:
				_pb.set_stream_volume(id, linear_to_db(gain) + level + _compress_db(key))
				_ids[key] = id
				_quiet[key] = 0.0
		elif target <= 0.0:
			_gains.erase(key)


## Dinamik sıkıştırma: katmanın pişmiş kısıklığının (1 - dynamics) payı geri verilir.
func _compress_db(key: int) -> float:
	if dynamics >= 1.0 or key >= 200:
		return 0.0
	var table: PackedFloat32Array = bank.off_db if key >= 100 else bank.on_db
	var index: int = key % 100
	if index >= table.size():
		return 0.0
	return -table[index] * (1.0 - dynamics)


func _stream_of(key: int) -> AudioStreamWAV:
	if key == 200:
		return bank.whistle
	if key >= 100:
		return bank.off_loops[key - 100] if key - 100 < bank.off_loops.size() else null
	return bank.on_loops[key] if key < bank.on_loops.size() else null


func _pitch_of(key: int) -> float:
	if key == 200:
		var norm: float = clampf(rpm / maxf(bank.redline_rpm(), 1.0), 0.0, 1.0)
		return lerpf(0.35, 1.0, boost) * (0.88 + 0.12 * norm)
	var index: int = key % 100
	if index >= bank.rpms.size():
		return 1.0
	return clampf(maxf(rpm, 1.0) / bank.rpms[index], 0.5, 2.0)


# --- Turbo / patlama ---------------------------------------------------------------------------------------------

func _update_boost(delta: float, norm: float, lifted: bool) -> void:
	var amount: float = bank.get_runtime("turbo", 0.0)
	if amount <= 0.0:
		boost = 0.0
		return
	var spool: float = bank.get_runtime("spool_rpm", 2300.0)
	var available: float = clampf((rpm - spool * 0.6) / maxf(spool * 0.8, 1.0), 0.0, 1.0)
	var target: float = throttle * available * amount
	var lag: float = maxf(bank.get_runtime("spool_lag", 0.6), 0.05)
	var rate: float = 1.0 / lag if target > boost else 4.0 / lag
	boost += (target - boost) * (1.0 - exp(-rate * delta))
	if lifted and boost > 0.3 and bank.blowoff:
		play_oneshot(bank.blowoff, bank.get_runtime("blowoff_db", -14.0) + linear_to_db(boost), _rng.randf_range(0.94, 1.06))
		boost *= 0.35


func _on_lift(norm: float) -> void:
	var crackle: float = bank.get_runtime("crackle", 0.0)
	if crackle <= 0.0 or norm < 0.3 or bank.get_runtime("decel_pops", 0.0) > 0.0:
		return   # inerken patlama açıksa gaz bırakmanın patlamalarını o ritim çalar (üst üste binmesin)
	_pops_left += roundi(crackle * _rng.randf_range(1.5, 6.5) * (0.5 + norm))
	_pop_timer = _rng.randf_range(0.03, 0.12)


func _update_pops(delta: float, norm: float, limiter: bool) -> void:
	var crackle: float = bank.get_runtime("crackle", 0.0)
	if crackle <= 0.0 or bank.pops.is_empty() or not running:
		return
	# Uzun gaz kesik: devir yüksekken ara ara çıtırtı (inerken patlama açıksa onun ritmi çalar)
	if throttle < 0.15 and norm > 0.4 and bank.get_runtime("decel_pops", 0.0) <= 0.0:
		_overrun_timer -= delta
		if _overrun_timer <= 0.0:
			_overrun_timer = _rng.randf_range(0.15, 0.6) / maxf(crackle * norm, 0.05)
			_pops_left += 1
	if limiter and _rng.randf() < crackle * delta * 6.0:
		_pops_left += 1
	if _pops_left <= 0:
		return
	_pop_timer -= delta
	if _pop_timer <= 0.0:
		_pops_left -= 1
		_pop_timer = _rng.randf_range(0.045, 0.2)
		pop(_rng.randf_range(0.45, 1.0))


## İNERKEN PATLAMA: gaz kesik ve devir hızla düşerken (yüksek devirden iniş) her `pop_interval`'da (±%25) bir vuruş;
## vuruşta `decel_pops` olasılıkla patlama. Devir `pop_rpm` payının altına inince ya da gaz açılınca biter. Güç devirle
## azalır (yüksekte gür "PAT", aşağıda sönük "pat").
func _update_decel_pops(delta: float, norm: float) -> void:
	var chance: float = bank.get_runtime("decel_pops", 0.0)
	if chance <= 0.0 or bank.pops.is_empty() or not running:
		return
	var floor_norm: float = bank.get_runtime("pop_rpm", 0.35)
	var span: float = maxf(bank.redline_rpm() - bank.idle_rpm(), 1.0)
	var descending: bool = throttle < 0.2 and _falling > span * 0.02 and norm > floor_norm   # vitesteki yavaş iniş de sayılır
	if not descending:
		_decel_timer = minf(_decel_timer, 0.04)   # yeni inişte ilk patlama hemen gelsin
		return
	_decel_timer -= delta
	if _decel_timer > 0.0:
		return
	var depth: float = clampf((norm - floor_norm) / maxf(1.0 - floor_norm, 0.05), 0.0, 1.0)
	# Devir indikçe ritim hafifçe yavaşlar ve seyrekleşir: "PAT PAT PAT … pat … pat"
	# Hızlı düşüşte (boşta gaz pompası) ritim sıklaşır: kısa inişe de birkaç "pat" sığsın
	var urgency: float = clampf(sqrt(span * 0.25 / maxf(_falling, 1.0)), 0.5, 1.0)
	_decel_timer = bank.get_runtime("pop_interval", 0.13) * lerpf(1.5, 1.0, depth) * urgency * _rng.randf_range(0.8, 1.25)
	if _rng.randf() < chance * lerpf(0.55, 1.0, depth):
		pop(lerpf(0.4, 1.0, depth) * _rng.randf_range(0.8, 1.0))


## Egzoz patlaması (`strength` 0–1). Drag yarışı vites atarken de çağırır.
func pop(strength: float = 1.0) -> void:
	if bank == null or bank.pops.is_empty():
		return
	var stream: AudioStreamWAV = bank.pops[_rng.randi() % bank.pops.size()]
	pops_played += 1
	popped.emit(clampf(strength, 0.05, 1.0))
	play_oneshot(stream, bank.get_runtime("crackle_db", -8.0) + linear_to_db(clampf(strength, 0.05, 1.0)),
		_rng.randf_range(0.85, 1.18))


## Tek seferlik ses (patlama, blow-off, marş): aynı oynatıcıdan, aracın düzeyiyle.
func play_oneshot(stream: AudioStream, volume_db: float, pitch: float = 1.0) -> void:
	if stream == null or not _ensure():
		return
	_pb.play_stream(stream, 0.0, volume_db + bank.get_runtime("level_db", 0.0), pitch, AudioServer.PLAYBACK_TYPE_DEFAULT,
		StringName(player.get("bus")))


# --- Marş / kontak ------------------------------------------------------------------------------------------------

## Marşa basılır: marş sesi çalar, rölantiye oturunca döngüler açılır.
func start_engine() -> void:
	running = true
	_master = 0.0
	rpm = bank.idle_rpm()
	_starting = 0.0
	play_oneshot(bank.start, 0.0)


## Motor ÇALIŞIR hâlde gelir (marş sesi yok; dinamometre): döngüler rölantide kısa sürede sessizden açılır.
func resume() -> void:
	running = true
	_starting = -1.0
	_master = 0.0
	rpm = bank.idle_rpm()


## Kontak kapanır: döngüler hızla susar, kapatma sesi çalar.
func stop_engine() -> void:
	if not running:
		return
	running = false
	_starting = -1.0
	_pops_left = 0
	play_oneshot(bank.stop, 0.0)


## Marş sürüyor mu (döngüler henüz açılmadı).
func is_starting() -> bool:
	return _starting >= 0.0 and _starting < bank.start_idle_at


## Şu an çalan akış sayısı (QA / test: lite trafikte çoğunlukla 2).
func active_streams() -> int:
	return _ids.size()
