extends SceneTree
## LİDER TABLOSU HİLE SINIRI (docs/LIDER_TABLOSU.md): her edinilebilir aracın EN YÜKSEK modifiyeyle (bütün kategoriler
## PerformanceMods.STAGES) kusursuz sürüşle (beceri 1, güç 1) koşulmuş 300 m süresi, MARGIN payıyla →
## firebase/functions/lb_limits.json ({araç: en düşük kabul edilen sn}). Sunucu (lbRun) bunun altındaki kaydı siler.
## Sapma (Recording.jitter) her koşuda değişir: birkaç tohumun en iyisi alınır. Oyunun fiziği / araç verisi değişince
## yeniden üret ve functions'ı yeniden yayınla.
##   godot-4 --headless --path . --script res://tools/lb_limits.gd

const OUT: String = "res://firebase/functions/lb_limits.json"
## Kusursuz yapay zekâ koşusunun bu kadarı: insanın şanslı sapması + kusursuz tepkisi için pay (hileyi değil yanlış alarmı önler).
const MARGIN: float = 0.93
const SEEDS: int = 8


func _initialize() -> void:
	var limits: Dictionary = {}
	var build: Dictionary = {}
	for category: StringName in PerformanceMods.CATEGORIES:
		build[category] = PerformanceMods.STAGES
	for entry: Dictionary in CarCatalog.all():
		var car: StringName = StringName(String(entry["id"]))
		if not CarCatalog.is_obtainable(car):
			continue
		var best: float = INF
		for s: int in SEEDS:
			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.seed = 1000 + s
			var form: DragRaceSim.Form = DragRaceSim.Form.new()
			form.power = 1.0
			form.skill = 1.0
			form.launch_skill = 1.0
			var recording: DragRaceSim.Recording = DragRaceSim.ai_recording(car, build, form, rng)
			if recording.time > 0.0:
				best = minf(best, recording.time)
		if best < INF:
			limits[String(car)] = snappedf(best * MARGIN, 0.01)
	var keys: Array = limits.keys()
	keys.sort()
	var ordered: Dictionary = {}
	for key: Variant in keys:
		ordered[key] = limits[key]
	var file: FileAccess = FileAccess.open(ProjectSettings.globalize_path(OUT), FileAccess.WRITE)
	file.store_string(JSON.stringify(ordered, "  ") + "\n")
	file.close()
	print("lb_limits: %d araç → %s" % [ordered.size(), OUT])
	quit()
