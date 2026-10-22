class_name RivalPool
extends RefCounted
## YAPAY ZEKÂ KOŞU HAVUZU (docs/KOSU_ESLESTIRME.md): Emre / Elif ve isimsiz rakip için her aracın SIZE tohumlu koşusunun
## süresi önceden hesaplanır (vehicles/rival_pool.json, tools/bake_rival_pool.gd). Seçici hedef kazanma şansına en
## yakın tohumu seçer; pist yalnızca o koşuyu bir kez üretir (`recording`) — telefonda onlarca benzetimi yarış
## açılışında koşmak takılma yapardı (masaüstünde koşu başına 2–3,5 ms ölçüldü).
## Koşu sıradan bir yapay zekâ koşusudur: sınıf becerisi + o günün formu (DragRaceSim.roll_form); tohum yalnızca hangi
## gün formunun çekildiğini sabitler.
##
## Havuz eskiyse (araç ayarı, fizik ya da yapay zekâ değişti) o araç için çalışma anında RUNTIME_SIZE koşu üretilir ve
## uyarı basılır; race_replay_test eskimeyi yakalar.

const PATH: String = "res://vehicles/rival_pool.json"
## Araç başına tohum sayısı.
const SIZE: int = 48
## Yapay zekâ sürüşü (form, vites planı, tepki) ya da tohum yöntemi değişince artırılır: havuz yeniden pişirilir.
const VERSION: int = 1
const SEED_BASE: int = 7000
const RUNTIME_SIZE: int = 12

static var _baked: Dictionary = {}
static var _loaded: bool = false
static var _runtime: Dictionary = {}
static var _warned: bool = false


## Havuz girdilerinin anahtarı: aracın ayarı + fizik + yapay zekâ sürümü. Biri değişirse havuz eskir.
static func key_of(vehicle_id: StringName) -> String:
	return "%s|%d|%d" % [DragRaceSim.tuning_key(vehicle_id), DragRaceSim.SIM_VERSION, VERSION]


## `index`. tohumun koşusu (her cihazda aynı girdiler).
static func recording(vehicle_id: StringName, index: int) -> DragRaceSim.Recording:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED_BASE + index
	return DragRaceSim.ai_recording(vehicle_id, {}, DragRaceSim.roll_form(vehicle_id, rng), rng)


## Havuzun süreleri (sıra = tohum). Pişmiş havuz eskiyse çalışma anında küçük bir havuz.
static func times(vehicle_id: StringName) -> PackedFloat64Array:
	var baked: PackedFloat64Array = baked_times(vehicle_id)
	if not baked.is_empty():
		return baked
	if not _runtime.has(vehicle_id):
		if not _warned:
			_warned = true
			push_warning("RivalPool: %s için pişmiş havuz yok / eski — çalışma anında üretiliyor; tools/bake_rival_pool.gd ile yenile"
				% vehicle_id)
		var out: PackedFloat64Array = PackedFloat64Array()
		for i: int in RUNTIME_SIZE:
			out.append(recording(vehicle_id, i).time)
		_runtime[vehicle_id] = out
	return _runtime[vehicle_id]


## Pişmiş havuz güncelse süreleri, değilse boş (seçici o zaman araç aramaz).
static func baked_times(vehicle_id: StringName) -> PackedFloat64Array:
	if not _loaded:
		_loaded = true
		if FileAccess.file_exists(PATH):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
			if parsed is Dictionary and (parsed as Dictionary).get("cars") is Dictionary:
				_baked = (parsed as Dictionary)["cars"]
	var row: Variant = _baked.get(String(vehicle_id), null)
	if not row is Dictionary or String((row as Dictionary).get("key", "")) != key_of(vehicle_id):
		return PackedFloat64Array()
	var out: PackedFloat64Array = PackedFloat64Array()
	var raw: Variant = (row as Dictionary).get("t", [])
	if raw is Array:
		for value: Variant in raw:
			out.append(SaveSafe.f(value))
	return out


## Önbellekleri boşaltır (bake aracı, test).
static func clear_cache() -> void:
	_baked.clear()
	_loaded = false
	_runtime.clear()
