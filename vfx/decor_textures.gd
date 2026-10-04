class_name DecorTextures
## ZEMİN DESENLERİ ve DUVAR KAPLAMALARI — dokular KODLA üretilir (asset yok, stil tutarlı, dil bağımsız).
##
## Zemin deseni bir karoyu (DecorGrid.CELL = 0,175 birim ≈ 1,3 m) tam kaplar; hepsi tek bir
## Texture2DArray'in katmanlarıdır, garaj zemini tek shader ile çizilir (vfx/floor_tiles.gdshader).
## Duvar kaplaması dünya uzayında üç düzlemli (triplanar) eşlenir: segmentler arası ek yeri olmaz,
## UV hesabı gerekmez. Üretim deterministiktir (sabit tohumlu gürültü), oyun başına bir kez yapılır.

const SIZE: int = 128
## Duvar dokusunun dünyadaki tekrar boyu (birim): 0,2 birim ≈ 1,5 m'lik bir tuğla / lambri bloğu.
const WALL_REPEAT: float = 0.2

static var _pattern_images: Dictionary = {}
static var _pattern_array: Texture2DArray
static var _array_ids: Array[StringName] = []
static var _swatches: Dictionary = {}
static var _wall_materials: Dictionary = {}


# --- Zemin desenleri -------------------------------------------------------------------

## Desenin malzeme özellikleri: [pürüzlülük, metalik].
static func pattern_surface(id: StringName) -> Vector2:
	match id:
		&"diamond_silver": return Vector2(0.35, 0.75)
		&"diamond_black": return Vector2(0.4, 0.55)
		&"carbon": return Vector2(0.3, 0.2)
		&"epoxy_blue", &"epoxy_red", &"epoxy_grey": return Vector2(0.18, 0.05)
		&"tile_white", &"tile_grey": return Vector2(0.45, 0.0)
		&"checker_bw", &"checker_bw_big", &"checker_blue", &"checker_red": return Vector2(0.4, 0.0)
		&"wood_light", &"wood_dark": return Vector2(0.6, 0.0)
		_: return Vector2(0.85, 0.0)


## Desenin karo görüntüsü (SIZE × SIZE, mipmap'li). Bilinmeyen desen → düz gri.
static func pattern_image(id: StringName) -> Image:
	if _pattern_images.has(id):
		return _pattern_images[id]
	var img: Image = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	match id:
		&"tile_grey": _tiles(img, 2, Color("C9CCD2"), Color("9EA2A8"), 3)
		&"tile_white": _tiles(img, 3, Color("ECEBE6"), Color("B9BAB6"), 2)
		&"concrete_light": _speckle(img, Color("B4B1AA"), 0.05, 11)
		&"concrete_dark": _speckle(img, Color("6B6A67"), 0.05, 12)
		&"asphalt": _speckle(img, Color("343A42"), 0.07, 13)
		&"checker_bw": _checker(img, 4, Color("F2F1EC"), Color("1C1D20"))
		&"checker_bw_big": _checker(img, 2, Color("F2F1EC"), Color("1C1D20"))
		&"checker_blue": _checker(img, 2, Color("2F9CDB"), Color("15171B"))
		&"checker_red": _checker(img, 2, Color("C8322B"), Color("15171B"))
		&"wood_light": _planks(img, Color("C49A62"), 14)
		&"wood_dark": _planks(img, Color("6E4528"), 15)
		&"diamond_silver": _diamond(img, Color("A9AEB4"))
		&"diamond_black": _diamond(img, Color("2C2F34"))
		&"carbon": _carbon(img)
		&"epoxy_blue": _speckle(img, Color("2C5C9E"), 0.025, 16)
		&"epoxy_red": _speckle(img, Color("A42A26"), 0.025, 17)
		&"epoxy_grey": _speckle(img, Color("8E949B"), 0.025, 18)
		&"hazard": _hazard(img)
		&"race_stripe": _race_stripe(img)
		&"rubber": _rubber(img)
		_: img.fill(Color("777777"))
	img.generate_mipmaps()
	_pattern_images[id] = img
	return img


## Bütün katalog desenleri tek dizide; katman sırası `ids` sırası (shader'a indeks + 1 olarak gider).
static func pattern_array(ids: Array[StringName]) -> Texture2DArray:
	if _pattern_array and _array_ids == ids:
		return _pattern_array
	var images: Array[Image] = []
	for id: StringName in ids:
		images.append(pattern_image(id))
	if images.is_empty():
		images.append(pattern_image(&""))
	_pattern_array = Texture2DArray.new()
	_pattern_array.create_from_images(images)
	_array_ids = ids.duplicate()
	return _pattern_array


## Kartta gösterilecek küçük önizleme (zemin deseni ya da duvar kaplaması).
static func swatch(id: StringName) -> Texture2D:
	if _swatches.has(id):
		return _swatches[id]
	var img: Image
	if GarageDecor.get_item(id).get("kind", -1) == GarageDecor.Kind.FLOOR_PATTERN:
		img = pattern_image(id).duplicate()
		img.clear_mipmaps()
	else:
		img = wall_image(id)
		if img == null:
			img = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
			img.fill(wall_color(id))
		else:
			img = img.duplicate()
			img.clear_mipmaps()
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_swatches[id] = tex
	return tex


# --- Duvar kaplamaları -----------------------------------------------------------------

## Kaplamanın temel rengi (dokusuz boya kaplamaları yalnızca bundan oluşur).
static func wall_color(id: StringName) -> Color:
	match id:
		&"wall_brick": return Color("8C4A3A")
		&"wall_panel": return Color("EDEAE3")
		&"wall_plaster": return Color("E8E3D8")
		&"wall_brick_grey": return Color("7D7F82")
		&"wall_wood": return Color("9A6A3E")
		&"wall_block": return Color("A6A49E")
		&"wall_metal": return Color("8E979F")
		&"wall_black": return Color("232427")
		&"wall_yellow": return Color("E6B53A")
		&"wall_blue": return Color("2F6FB3")
		&"wall_red": return Color("B53A30")
		&"wall_tile": return Color("EEEDE8")
		&"wall_checker": return Color("1E1F22")
		_: return Color(0.6, 0.6, 0.6)


## Dokulu kaplamanın görüntüsü (düz boyalar için null).
static func wall_image(id: StringName) -> Image:
	var key: StringName = StringName("wall:" + String(id))
	if _pattern_images.has(key):
		return _pattern_images[key]
	var img: Image = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	match id:
		&"wall_brick": _bricks(img, Color("8C4A3A"), Color("C9BBA6"), 21)
		&"wall_brick_grey": _bricks(img, Color("7D7F82"), Color("BDBAB2"), 22)
		&"wall_panel": _panels(img, Color("EDEAE3"), Color("C9C5BC"))
		&"wall_wood": _lambri(img, Color("9A6A3E"), 23)
		&"wall_block": _blocks(img, Color("A6A49E"), Color("85837E"))
		&"wall_metal": _corrugated(img, Color("8E979F"))
		&"wall_tile": _tiles(img, 4, Color("EEEDE8"), Color("BEBDB8"), 2)
		&"wall_checker": _checker(img, 4, Color("EFEEE9"), Color("1E1F22"))
		_: return null
	img.generate_mipmaps()
	_pattern_images[key] = img
	return img


## Kaplamanın malzemesi (dış duvar ve iç duvar segmentleri aynı malzemeyi paylaşır). id "" = varsayılan.
static func wall_material(id: StringName) -> StandardMaterial3D:
	if _wall_materials.has(id):
		return _wall_materials[id]
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE if wall_image(id) != null else wall_color(id)
	mat.roughness = 0.82
	match id:
		&"wall_metal": mat.metallic = 0.45
		&"wall_panel", &"wall_tile": mat.roughness = 0.45
		&"wall_black": mat.roughness = 0.6
	var img: Image = wall_image(id)
	if img:
		mat.albedo_texture = ImageTexture.create_from_image(img)
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_scale = Vector3.ONE / WALL_REPEAT
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_wall_materials[id] = mat
	return mat


# --- Çizim yardımcıları ----------------------------------------------------------------

static func _rect(img: Image, r: Rect2i, c: Color) -> void:
	img.fill_rect(r.intersection(Rect2i(0, 0, SIZE, SIZE)), c)


static func _shade(c: Color, k: float) -> Color:
	return Color(clampf(c.r * k, 0.0, 1.0), clampf(c.g * k, 0.0, 1.0), clampf(c.b * k, 0.0, 1.0), 1.0)


static func _speckle(img: Image, base: Color, amount: float, seed_value: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	for y: int in SIZE:
		for x: int in SIZE:
			img.set_pixel(x, y, _shade(base, 1.0 + rng.randf_range(-amount, amount)))


static func _tiles(img: Image, n: int, face: Color, grout: Color, line: int) -> void:
	_speckle(img, face, 0.02, 31 + n)
	var step: int = SIZE / n
	for k: int in n + 1:
		var p: int = k * step - line / 2
		_rect(img, Rect2i(p, 0, line, SIZE), grout)
		_rect(img, Rect2i(0, p, SIZE, line), grout)


static func _checker(img: Image, n: int, a: Color, b: Color) -> void:
	var step: int = SIZE / n
	for y: int in n:
		for x: int in n:
			_rect(img, Rect2i(x * step, y * step, step, step), a if (x + y) % 2 == 0 else b)


static func _planks(img: Image, base: Color, seed_value: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var rows: int = 6
	var h: int = SIZE / rows
	for r: int in rows:
		var offset: int = rng.randi_range(0, SIZE)
		var tone: float = rng.randf_range(0.88, 1.1)
		for y: int in range(r * h, (r + 1) * h):
			for x: int in SIZE:
				var grain: float = 0.04 * sin(float(x + offset) * 0.21 + float(y) * 0.9)
				img.set_pixel(x, y, _shade(base, tone + grain))
		_rect(img, Rect2i(0, r * h, SIZE, 1), _shade(base, 0.62))
		var joint: int = (offset % SIZE)
		_rect(img, Rect2i(joint, r * h, 1, h), _shade(base, 0.62))


static func _diamond(img: Image, base: Color) -> void:
	img.fill(base)
	var step: int = 16
	for cy: int in range(0, SIZE + step, step):
		for cx: int in range(0, SIZE + step, step):
			var ox: int = cx + (step / 2 if (cy / step) % 2 == 1 else 0)
			# Kısa çapraz çıkıntı: açık üst kenar + koyu alt kenar
			for t: int in range(-4, 5):
				var x: int = ox + t
				var y: int = cy - t
				if x >= 0 and x < SIZE and y >= 0 and y < SIZE:
					img.set_pixel(x, y, _shade(base, 1.35))
				if x >= 0 and x < SIZE and y + 1 >= 0 and y + 1 < SIZE:
					img.set_pixel(x, y + 1, _shade(base, 0.7))


static func _carbon(img: Image) -> void:
	var a: Color = Color("2A2C30")
	var b: Color = Color("17181B")
	var step: int = 8
	for y: int in SIZE:
		for x: int in SIZE:
			var cell: int = (x / step + y / step) % 2
			var t: float = float((x if cell == 0 else y) % step) / float(step)
			img.set_pixel(x, y, (a if cell == 0 else b).lerp(Color("3A3D42"), 0.25 * sin(t * PI)))


static func _hazard(img: Image) -> void:
	var stripe: int = SIZE / 4
	for y: int in SIZE:
		for x: int in SIZE:
			var band: int = ((x + y) / stripe) % 2
			img.set_pixel(x, y, Color("E6B12A") if band == 0 else Color("1B1C1F"))


static func _race_stripe(img: Image) -> void:
	img.fill(Color("26292E"))
	var w: int = SIZE / 8
	_rect(img, Rect2i(SIZE / 2 - w - w / 2, 0, w, SIZE), Color("EFEFEA"))
	_rect(img, Rect2i(SIZE / 2 + w / 2, 0, w, SIZE), Color("EFEFEA"))


static func _rubber(img: Image) -> void:
	img.fill(Color("26272A"))
	var step: int = 16
	for cy: int in range(step / 2, SIZE, step):
		for cx: int in range(step / 2, SIZE, step):
			for y: int in range(-3, 4):
				for x: int in range(-3, 4):
					if x * x + y * y <= 9:
						img.set_pixel(cx + x, cy + y, Color("3A3C40"))


static func _bricks(img: Image, brick: Color, mortar: Color, seed_value: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	img.fill(mortar)
	var rows: int = 8
	var h: int = SIZE / rows
	var w: int = SIZE / 4
	for r: int in rows:
		var shift: int = w / 2 if r % 2 == 1 else 0
		for k: int in range(-1, 5):
			var x0: int = k * w + shift
			_rect(img, Rect2i(x0 + 1, r * h + 1, w - 2, h - 2), _shade(brick, rng.randf_range(0.85, 1.12)))


static func _blocks(img: Image, face: Color, joint: Color) -> void:
	img.fill(joint)
	var rows: int = 4
	var h: int = SIZE / rows
	var w: int = SIZE / 2
	for r: int in rows:
		var shift: int = w / 2 if r % 2 == 1 else 0
		for k: int in range(-1, 3):
			_rect(img, Rect2i(k * w + shift + 2, r * h + 2, w - 4, h - 4), _shade(face, 1.0 + 0.04 * float((k + r) % 3 - 1)))


static func _panels(img: Image, face: Color, seam: Color) -> void:
	img.fill(face)
	for k: int in 2:
		_rect(img, Rect2i(k * SIZE / 2, 0, 2, SIZE), seam)
	_rect(img, Rect2i(0, SIZE - 10, SIZE, 10), _shade(face, 0.82))


static func _lambri(img: Image, base: Color, seed_value: int) -> void:
	_planks(img, base, seed_value)


static func _corrugated(img: Image, base: Color) -> void:
	for y: int in SIZE:
		for x: int in SIZE:
			img.set_pixel(x, y, _shade(base, 0.85 + 0.25 * (0.5 + 0.5 * sin(float(x) / float(SIZE) * TAU * 8.0))))
