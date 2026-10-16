extends "res://qa/teaser/teaser.gd"
## REELS GALERİ — seviye 4 garaj şık / lüks araba galerisi olarak döşenir (oyunun kendi dekor sistemiyle: zemin karosu,
## duvar kaplaması, duvar eşyaları, SERGİ araçları), 4,5 sn, dikey 1080x1920, 30 fps. Araçlar oyunda var
## olan modeller, FABRİKA renginde (CarAppearance.get_for). Kamera OYUN KAMERASI (ortografik 45° / −25°):
## geniş bakışla başlar (çok sayıda araç), yavaşça araçların üzerinden kayıp yaklaşır.
## Yerleşim oyunun kuralıyla denetlenir (garage_kit._validate: geçersizse "DECOR HATA").
## HUD / 2B arayüz yok (yalnızca SubViewport'un 3B dünyası), dünya plakaları ve müşteri balonları gizli.
##   CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/teaser/reels_galeri.gd --display-driver x11 \
##       --disable-vsync --fixed-fps 30 --resolution 540x960 -- galeri <çıktı> [adım|probe|foto]
## foto: FOTO_KEYS bakışlarından tam boy (1080x1920) durağan kare — reels kapak görseli arka planı.
const Kit = preload("res://qa/teaser/garage_kit.gd")
const REEL_FPS: float = 30.0
const DURATION: float = 4.5
const SS: int = 2
const CAM_YAW: float = 45.0
const CAM_PITCH: float = -25.0
const LEVEL: int = 4
## Sergi araçları [araç, u, v, yaw]: iki sıra, arka sıra yarım aralık kaydırılmış (her araç kendi karbon
## alanında, aralarda mermer). Öndeki sağ köşe kahraman araç (Ferrari) — oyun kamerasına en yakın yer.
const CARS: Array = [
	[&"ferrari_488_pista", 0.85, 0.9, 0.0],
	[&"lamborghini_miura", 2.0, 0.9, 0.0],
	[&"chevrolet_camaro", 3.15, 0.9, 0.0],
	[&"ford_mustang_1967", 4.3, 0.9, 0.0],
	[&"lambo_huracan", 1.75, 2.4, 0.0],
	[&"mercedes_300sl", 2.9, 2.4, 0.0],
	[&"porsche_911_1973", 4.05, 2.4, 0.0],
]
## Lüks donatım: zemin [eşya, u, v, yaw] · duvar [eşya, "back"/"left", u_ya_da_v]. v yerine "B" = arka duvara
## yaslı. Sağ kenarın ortasında araçlara bakan VIP köşe (parke halı üstünde), arka duvar boyunca şampanya
## barı / şömine / akvaryum / altın motor, sol kenarda heykeller.
const DECOR: Array = [
	["lux_vip_rope", 0.85, 0.22, 0.0],
	["lux_crystal_lamp", 1.42, 0.5, 0.0],
	["topiary", 2.57, 0.5, 0.0],
	["lux_crystal_lamp", 3.72, 0.5, 0.0],
	["lux_gold_rim_tower", 0.2, 1.35, 0.0],
	["lux_velvet_lounge", 0.42, 2.25, 270.0],
	["lux_bonsai", 0.2, 2.9, 0.0],
	["fern_pot", 2.32, 2.4, 0.0],
	["fern_pot", 3.47, 2.4, 0.0],
	["lux_gold_car_statue", 5.15, 0.85, 0.0],
	["lux_diamond_statue", 5.2, 1.7, 0.0],
	["lux_champagne_bar", 0.75, "B", 0.0],
	["lux_marble_fireplace", 1.6, "B", 0.0],
	["lux_aquarium", 2.45, "B", 0.0],
	["lux_gold_palm", 3.5, "B", 0.0],
	["lux_gold_engine", 4.45, "B", 0.0],
	["lux_gold_painting", "back", 0.3],
	["lux_crystal_sconces", "back", 1.05],
	["lux_crystal_sconces", "back", 2.15],
	["lux_cinema_wall", "back", 3.0],
	["lux_neon_crown", "back", 4.45],
	["led_strip", "back", 5.25],
	["lux_gold_wheel", "left", 1.0],
	["lux_crystal_sconces", "left", 1.75],
]
## Zemin: mermer; sıralar arası koyu ahşap koridor; VIP köşenin altında parke halı (araç alanları en üstte).
const FLOOR: Array = [
	["marble", 0, 0, 31, 20],
	["wood_dark", 0, 8, 31, 10],
	["parquet_basket", 0, 9, 5, 17],
]
## Servis lifti (seviye zorunlu tutar): arka sol köşe, alçakta, üstünde araç (sergi platformu gibi).
const BAY: Array = [5.12, 2.55, 0.0]
const LIFT_CAR: StringName = &"aston_martin_db5"
## Kamera anahtarları: kare ortasındaki zemin noktası (u, v) ve ortografik size; zaman (sn).
const KEYS: Array = [
	[0.0, 3.85, 1.95, 6.2],
	[4.5, 1.2, 2.0, 3.9],
]

## foto kipi: geniş arka plan adayları [u, v, size] (u < 0: garajın sağı, showroom binası tarafı); tam boy
## yazılır. Dünya sınırına KISTIRILMAZ (bu boyda dikey kare haritadan taşar; kenar çim rengi, görsel zaten
## bulanıklaştırılıp soldurulur).
const FOTO_KEYS: Array = [
	[0.05, 1.82, 11.5],
]

var kit: Kit
var probe: bool = false
var foto: bool = false
var _basis: Basis
var _world_cam: WorldCamera


func _initialize() -> void:
	super()
	probe = OS.get_cmdline_user_args().has("probe")
	foto = OS.get_cmdline_user_args().has("foto")
	if preview_step == 0:
		vp.size = Vector2i(W * SS, H * SS)
	_basis = Basis.from_euler(Vector3(deg_to_rad(CAM_PITCH), deg_to_rad(CAM_YAW), 0.0))


func _run() -> void:
	kit = Kit.new()
	await kit.boot(self)
	var repair: RepairManager = get_first_node_in_group("repair_manager") as RepairManager
	if repair:
		repair.set_process(false)   # müşteri / balon yok; trafik akar
	await kit.set_level(LEVEL)
	print("GALERİ lot ", kit.width, " x ", kit.depth)
	await kit.build(_design())
	kit.lift_car(0, LIFT_CAR, 0.0)
	var cam: Camera3D = kit.attach_camera()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.near = 0.05
	cam.far = 60.0
	cam.cull_mask &= ~WorldCamera.LAYER_WORLD_UI
	cam.environment.background_mode = Environment.BG_COLOR
	# Harita kenarı görünürse çim rengi: arka plan bu ortamda ~0,63 kat koyu çıkar (ölçüldü), ışıklı çim #5f9a3c
	cam.environment.background_color = Color(0.6, 0.95, 0.37)
	_world_cam = current_scene.find_child("MainCamera", true, false) as WorldCamera
	await frames(120)   # lift kalkışı, gölgeler, trafik otursun
	for n: Node in current_scene.find_children("CarBubble", "", true, false):
		(n as Node3D).visible = false
	if probe or foto:
		var keys: Array = FOTO_KEYS if foto else KEYS
		for i: int in keys.size():
			var k: Array = [Vector3(Kit.X(float(keys[i][0])), 0.0, Kit.Z(float(keys[i][1]))), float(keys[i][2])] \
				if foto else _key(keys[i])
			_place(k[0], k[1])
			await frames(3)
			await RenderingServer.frame_post_draw
			var img: Image = vp.get_texture().get_image()
			img.resize(W if foto else W / 2, H if foto else H / 2, Image.INTERPOLATE_LANCZOS)
			img.save_png("%s/%s_%02d.png" % [out_dir, "foto" if foto else "probe", i])
			_saved += 1
	else:
		await record(tick)
	print("GALERİ bitti: %d kare → %s" % [_saved, out_dir])
	quit(0)


## Galeri: FLOOR karoları + her aracın altında ince karbon sergi alanı (kahraman araçta geniş elmas siyah),
## siyah duvar.
func _design() -> Dictionary:
	var items: Array = []
	var cars: Array = []
	var tiles: Array = FLOOR.duplicate()
	for c: Array in CARS:
		var item: StringName = GarageDecor.vehicle_item_id(c[0])
		var fp: Vector2 = kit.view.footprint_size(item)
		var u: float = float(c[1])
		var v: float = float(c[2])
		items.append([String(item), u, v, float(c[3])])
		cars.append(String(c[0]))
		var m: int = 1 if c == CARS[0] else 0   # kahraman aracın alanı bir göz geniş
		tiles.append(["diamond_black" if m > 0 else "carbon",
			floori((u - fp.x * 0.5) / Kit.CELL) - m, floori((v - fp.y * 0.5) / Kit.CELL) - m,
			floori((u + fp.x * 0.5) / Kit.CELL) + m, floori((v + fp.y * 0.5) / Kit.CELL) + m])
	for d: Array in DECOR:
		if d.size() == 3:
			items.append(d)
		elif d[2] is String:
			var fp2: Vector2 = kit.view.footprint_size(StringName(d[0]))
			items.append([d[0], d[1], kit.back(fp2.y), d[3]])
		else:
			items.append(d)
	return {
		"wall_surface": "wall_black",
		"bays": [BAY],
		"cars": cars,
		"tiles": tiles,
		"items": items,
	}


func _key(k: Array) -> Array:
	return _clamp_world([Vector3(Kit.X(float(k[1])), 0.0, Kit.Z(float(k[2]))), float(k[3])])


## Karenin köşelerinin zemindeki izi oyun kamerasının dünya sınırı içinde kalır (WorldCamera gibi).
func _clamp_world(key: Array) -> Array:
	if _world_cam == null:
		return key
	var focus: Vector3 = key[0]
	var size: float = float(key[1])
	var aspect: float = float(vp.size.x) / float(vp.size.y)
	var lo: Vector2 = Vector2(INF, INF)
	var hi: Vector2 = Vector2(-INF, -INF)
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var origin: Vector3 = focus + _basis.x * corner.x * size * aspect * 0.5 + _basis.y * corner.y * size * 0.5
		var dir: Vector3 = -_basis.z
		var hit: Vector3 = origin + dir * (-origin.y / dir.y)
		lo = lo.min(Vector2(hit.x, hit.z))
		hi = hi.max(Vector2(hit.x, hit.z))
	var a: Vector2 = _world_cam.world_min - lo
	var b: Vector2 = _world_cam.world_max - hi
	var shift: Vector2 = Vector2(clampf(0.0, a.x, b.x) if a.x <= b.x else (a.x + b.x) * 0.5,
		clampf(0.0, a.y, b.y) if a.y <= b.y else (a.y + b.y) * 0.5)
	return [focus + Vector3(shift.x, 0.0, shift.y), size]


func _place(focus: Vector3, size: float) -> void:
	kit.cam.global_transform = Transform3D(_basis, focus + _basis.z * 20.0)
	kit.cam.size = size


func record(tick_fn: Callable) -> void:
	var count: int = roundi(DURATION * REEL_FPS)
	for f: int in count:
		frame_index = f
		tick_fn.call(float(f) / REEL_FPS)
		await process_frame
		if preview_step > 0 and f % preview_step != 0:
			continue
		await RenderingServer.frame_post_draw
		var img: Image = vp.get_texture().get_image()
		if img.get_width() != W:
			img.resize(W, H, Image.INTERPOLATE_LANCZOS)
		if preview_step > 0:
			img.resize(W / 2, H / 2, Image.INTERPOLATE_BILINEAR)
		img.save_png("%s/%05d.png" % [out_dir, f])
		_saved += 1


## Tek yumuşak hareket: odak doğrusal, boy log uzayında; ilerleme yumuşak başlayıp yumuşak biter
## (ilk kare de hareket halinde: başta hız sıfır değil).
func tick(t: float) -> void:
	reset_post()
	set_post(&"vignette", 0.0)
	set_post(&"grain", 0.0)
	var a: Array = _key(KEYS[0])
	var b: Array = _key(KEYS[KEYS.size() - 1])
	var u: float = clampf(t / DURATION, 0.0, 1.0)
	var e: float = lerpf(u, smooth(u), 0.7)
	_place((a[0] as Vector3).lerp(b[0], e), exp(lerpf(log(float(a[1])), log(float(b[1])), e)))
