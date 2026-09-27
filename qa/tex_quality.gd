extends SceneTree
## VRAM sıkıştırmasının doku kalitesine etkisi: içe aktarılmış (DXT1) doku ile kaynak JPEG
## arasındaki PSNR. 40 dB üstü fark gözle ayırt edilemez kabul edilir.
func _initialize() -> void:
	_run.call_deferred()

func _psnr(a: Image, b: Image) -> float:
	if a.get_size() != b.get_size():
		b.resize(a.get_width(), a.get_height(), Image.INTERPOLATE_LANCZOS)
	var sum: float = 0.0
	var step: int = 4   # her 4. texel: 256K örnek, sonuç ±0.1 dB
	var n: int = 0
	for y: int in range(0, a.get_height(), step):
		for x: int in range(0, a.get_width(), step):
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			sum += (ca.r - cb.r) ** 2 + (ca.g - cb.g) ** 2 + (ca.b - cb.b) ** 2
			n += 3
	var mse: float = sum / maxf(float(n), 1.0)
	return 99.0 if mse <= 0.0 else 10.0 * log(1.0 / mse) / log(10.0)

func _run() -> void:
	var dir: String = "res://assets/cars/optimized/"
	var names: PackedStringArray = []
	for entry: Dictionary in CarCatalog.all():
		var base: String = String(entry["optimized_path"]).get_file().get_basename()
		names.append(base + "_car_albedo_albedo.jpg")
	print("%-46s %8s" % ["doku", "PSNR"])
	var worst: float = 99.0
	for n: String in names:
		var path: String = dir + n
		if not ResourceLoader.exists(path):
			print("  yok: ", n); continue
		var tex: Texture2D = load(path)
		var imported: Image = tex.get_image()
		imported.decompress()
		imported.convert(Image.FORMAT_RGB8)
		var source: Image = Image.new()
		if source.load(path) != OK:
			print("  kaynak okunamadı: ", n); continue
		source.convert(Image.FORMAT_RGB8)
		var db: float = _psnr(source, imported)
		worst = minf(worst, db)
		print("%-46s %7.1f dB" % [n.replace("_car_albedo_albedo.jpg", ""), db])
	print("EN KÖTÜ: %.1f dB" % worst)
	quit(0)
