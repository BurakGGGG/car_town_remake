extends RefCounted
## 17–20 sn GARAJ VİTRİNİ: dört farklı oyuncu garajı, her biri ~0,75 sn (ayrı süreç, bölüm adı tasarımı seçer).
##   vitrin_ev      — seviye 1, ev garajı: vosvos, tezgâh, köpek kulübesi, şezlong
##   vitrin_sanayi  — seviye 2, sanayi: üç lift (Toros, Murat 131, W123 kalkık), lastik/rot köşesi
##   vitrin_luks    — seviye 2, aşırı lüks: mermer + karbon, LED'li duvar önünde dört süper/klasik, piyano
##   vitrin_eglence — seviye 3, eğlence: arcade, DJ, diner, bilardo, palmiyeli çim, renkli klasikler
## Kamera garajın ön-sağ köşesinden çapraz bakar (dikey kadraja tüm garaj girer), hafifçe süzülür.
const D = preload("res://qa/teaser/teaser.gd")
const Kit = preload("res://qa/teaser/garage_kit.gd")

var d: D
var kit: Kit
var cam: Camera3D
var _t0: float = 0.0
var _t1: float = 0.0
var _orbit: float = 1.0


func run(director: D) -> void:
	d = director
	kit = Kit.new()
	await kit.boot(d)
	var design: Dictionary
	match d.segment:
		"vitrin_ev":
			await kit.set_level(1)
			design = _ev()
		"vitrin_sanayi":
			await kit.set_level(2)
			design = _sanayi()
		"vitrin_luks":
			await kit.set_level(2)
			design = _luks()
			_orbit = -1.0
		"vitrin_eglence":
			await kit.set_level(3)
			design = _eglence()
	await kit.build(design)
	match d.segment:
		"vitrin_sanayi":
			kit.lift_car(0, &"renault_toros")
			kit.lift_car(1, &"tofas_murat_131")
			kit.lift_car(2, &"mercedes_w123", 0.0)
		"vitrin_luks":
			kit.lift_car(0, &"porsche_gt3")
	cam = kit.attach_camera()
	var span: Array = D.SEGMENTS[d.segment]
	_t0 = float(span[0])
	_t1 = float(span[1])
	await d.frames(90)   # lift kalkışı ve dekor gölgeleri otursun
	await d.record(tick)


func tick(t: float) -> void:
	d.reset_post()
	var k: float = D.span(t, _t0, _t1)
	d.set_post(&"white", D.pulse(t, _t0, 0.12) * 0.6)
	d.set_post(&"aberration", 0.3 + D.pulse(t, _t0, 0.15) * 5.0)
	d.set_post(&"vignette", 0.4)
	d.set_post(&"grain", 0.02)
	var w: float = kit.width
	var dep: float = kit.depth
	var center: Vector3 = Vector3(Kit.X(w * 0.42), 0.04, Kit.Z(dep * 0.47))
	var size: float = maxf(w, dep * 1.3)
	# Ön-sağ köşeden çapraz, yüksekçe; kesme anında hafif yakından açılıp süzülür
	var ang: float = deg_to_rad(38.0 + _orbit * lerpf(-5.0, 5.0, k))
	var dist: float = size * lerpf(1.42, 1.3, D.ease_out(k, 2.0))
	var dir: Vector3 = Vector3(sin(ang), 1.3, cos(ang)).normalized()
	D.look_cam(cam, center + dir * dist, center + Vector3(0.0, -0.02, 0.0))
	cam.fov = 50.0


# --- Tasarımlar (u: sağ kenardan sola, v: ön kenardan arkaya; metre) ------------------------------

## SEVİYE 1 — EV GARAJI (2,1 × 1,575): sıcak, düzenli, aile garajı.
func _ev() -> Dictionary:
	return {
		"wall_surface": "wall_brick_white",
		"bays": [[1.74, 0.78, 0.0]],
		"cars": ["vw_beetle_1967"],
		"tiles": [
			["concrete_light", 0, 0, 11, 8],
			["wood_light", 0, 5, 3, 8],
			["brick_paver", 0, 0, 11, 0],
		],
		"items": [
			["car:vw_beetle_1967", 0.98, 0.76, 0.0],
			["workbench", 1.0, kit.back(0.097), 0.0],
			["tool_trolley", 1.3, kit.back(0.115), 0.0],
			["jerry_cans", kit.left(0.071), 1.38, 0.0],
			["deck_chair", 0.22, 1.2, 0.0],
			["cooler", 0.42, 1.25, 0.0],
			["potted_plant", 0.09, kit.back(0.113), 0.0],
			["fern_pot", 0.6, kit.back(0.128), 0.0],
			["dog_house", 0.45, 0.6, 270.0],
			["motorcycle", 0.07, 0.4, 90.0],
			["bbq", 0.62, 1.05, 0.0],
			["sunflowers", 0.95, 0.09, 0.0],
			["tyre_planter", 0.3, 0.1, 0.0],
			["hose_reel", kit.left(0.074), 0.25, 0.0],
			["kiddie_car", 0.42, 0.3, 20.0],
			["flower_bed", 1.62, 0.13, 0.0],
			["mailbox", 0.06, 0.09, 0.0],
			["pegboard", "back", 1.76],
			["wall_shelf", "back", 1.0],
			["wall_clock", "back", 0.55],
			["wall_calendar", "back", 0.3],
			["wall_lamp", "back", 1.42],
			["wall_window_deco", "left", 0.62],
			["poster_vintage", "back", 0.12],
			["tyre_hanger", "left", 1.25],
		],
	}


## SEVİYE 2 — SANAYİ (3,675 × 2,275): üç lift, arka duvar boyunca raf/lastik/varil, sol köşe lastik-rot.
func _sanayi() -> Dictionary:
	var items: Array = [
		["parts_shelf", 0.2, kit.back(0.125), 0.0],
		["tool_cabinet", 0.5, kit.back(0.115), 0.0],
		["workbench", 0.82, kit.back(0.097), 0.0],
		["drill_press", 1.03, kit.back(0.083), 0.0],
		["tyre_rack", 1.3, kit.back(0.127), 0.0],
		["oil_drums", 1.56, kit.back(0.162), 0.0],
		["pallet_stack", 1.84, kit.back(0.163), 0.0],
		["tyre_pile", 2.1, kit.back(0.158), 0.0],
		["wooden_crates", 2.38, kit.back(0.083), 0.0],
		["barrel_rack", 2.66, kit.back(0.068), 0.0],
		["utility_sink", 2.92, kit.back(0.077), 0.0],
		["engine_hoist", 3.3, 1.75, 0.0],
		["engine_block", 3.05, 1.6, 0.0],
		["tire_changer", 2.95, 0.95, 0.0],
		["wheel_balancer", 3.35, 0.95, 0.0],
		["rim_stack", 3.0, 0.62, 0.0],
		["compressor", kit.left(0.104), 0.35, 0.0],
		["welding_set", 3.2, 1.3, 0.0],
		["mechanic", 1.0, 1.05, 0.0],
		["mechanic", 1.8, 1.25, 180.0],
		["tool_trolley", 1.0, 0.45, 90.0],
		["jack_stand", 1.8, 0.4, 0.0],
		["creeper", 2.65, 0.3, 0.0],
		["oil_drain", 2.62, 1.55, 0.0],
		["diagnostic_cart", 2.62, 1.2, 0.0],
		["air_station", 0.06, 0.12, 0.0],
		["car_ramps", 3.3, 0.35, 0.0],
		["tyre_wall", 3.4, kit.back(0.07), 0.0],
		["battery_charger", 2.62, 0.78, 0.0],
		["wheel_chocks", 0.6, 0.2, 0.0],
		["wheel_chocks", 2.2, 0.2, 0.0],
		["spare_doors", 0.05, 1.2, 90.0],
		["jerry_cans", 0.95, 1.8, 0.0],
		["cable_reel", 1.4, 1.8, 0.0],
		["hose_reel", 1.85, 1.8, 0.0],
		["traffic_cones", 1.4, 0.13, 0.0],
		["extinguisher_stand", 0.06, 1.95, 0.0],
		["pegboard", "back", 0.45],
		["sign_service", "back", 0.85],
		["job_board", "back", 1.2],
		["steering_rack", "back", 1.6],
		["vent_grille", "back", 1.95],
		["exhaust_rack", "back", 2.3],
		["sign_oil", "back", 2.72],
		["tyre_hanger", "back", 3.2],
		["sign_tires", "left", 0.8],
		["rim_display", "left", 1.25],
		["license_plates", "left", 1.7],
		["extinguisher_wall", "left", 0.3],
		["first_aid", "left", 0.45],
		["wall_fan", "left", 2.1],
		["wall_lamp", "back", 0.08],
	]
	return {
		"wall_surface": "wall_metal",
		"bays": [[0.6, 1.02, 0.0], [1.4, 1.02, 0.0], [2.2, 1.02, 0.0]],
		"cars": [],
		"tiles": [
			["concrete_dark", 0, 0, 20, 12],
			["hazard", 1, 3, 14, 8],
			["steel_grate", 15, 2, 20, 11],
			["rubber", 0, 0, 14, 1],
		],
		"items": items,
	}


## SEVİYE 2 — AŞIRI LÜKS (3,675 × 2,275): mermer, karbon sergi şeridi, LED duvar, dört süper/klasik araç,
## sol arkada deri lounge + kuyruklu piyano, sol önde detaylı bakım lifti (Porsche GT3).
func _luks() -> Dictionary:
	var items: Array = [
		["car:ferrari_488_pista", 0.5, 1.45, 0.0],
		["car:lambo_huracan", 1.15, 1.45, 0.0],
		["car:mercedes_300sl", 1.8, 1.45, 0.0],
		["car:aston_martin_db5", 2.45, 1.45, 0.0],
		["topiary", 0.825, kit.back(0.092), 0.0],
		["topiary", 1.475, kit.back(0.092), 0.0],
		["topiary", 2.125, kit.back(0.092), 0.0],
		["trophy_case", 0.12, kit.back(0.071), 0.0],
		["leather_sofa", kit.left(0.118), 1.6, 90.0],
		["coffee_table", 3.33, 1.6, 90.0],
		["grand_piano", 3.0, 2.06, 0.0],
		["fern_pot", 3.6, kit.back(0.128), 0.0],
		["vase_large", 2.82, 1.25, 0.0],
		["manager_desk", 0.32, 0.42, 0.0],
		["water_cooler", 0.06, 0.82, 0.0],
		["topiary", 1.05, 0.1, 0.0],
		["topiary", 2.6, 0.1, 0.0],
		["car:mercedes_cls", 1.8, 0.55, 35.0],
		["leather_sofa", 3.12, 1.6, 270.0],
		["fern_pot", 0.62, 0.42, 0.0],
		["vase_large", 0.08, 1.95, 0.0],
		["bar_stools", 0.35, 0.85, 0.0],
		["led_strip", "back", 0.5],
		["led_strip", "back", 1.15],
		["led_strip", "back", 1.8],
		["led_strip", "back", 2.45],
		["neon_car", "back", 3.2],
		["wall_tv", "left", 1.6],
		["trophy_shelf", "left", 2.05],
		["plate_frame", "left", 1.15],
		["race_suit", "left", 0.95],
		["neon_sign", "back", 0.12],
	]
	return {
		"wall_surface": "wall_black",
		"bays": [[3.3, 0.5, 90.0]],
		"cars": ["ferrari_488_pista", "lambo_huracan", "mercedes_300sl", "aston_martin_db5", "mercedes_cls"],
		"tiles": [
			["marble", 0, 0, 20, 12],
			["carbon", 0, 6, 15, 10],
			["diamond_black", 16, 6, 20, 12],
			["terrazzo", 16, 0, 20, 5],
			["diamond_silver", 0, 0, 15, 1],
		],
		"items": items,
	}


## SEVİYE 3 — EĞLENCE (4,725 × 2,975): arcade köşesi, DJ + davul sahnesi, diner, bilardo / masa tenisi,
## önde palmiyeli çim ve oyuncak araçlar, ortada renkli klasikler.
func _eglence() -> Dictionary:
	var items: Array = [
		["car:vw_t1_bus", 1.15, 1.3, 0.0],
		["car:chevrolet_bel_air_1956", 1.8, 1.3, 0.0],
		["car:mini_cooper_1965", 2.45, 1.3, 0.0],
		["arcade_cabinet", 0.1, kit.back(0.095), 0.0],
		["arcade_cabinet", 0.22, kit.back(0.095), 0.0],
		["arcade_cabinet", 0.34, kit.back(0.095), 0.0],
		["arcade_cabinet", 0.46, kit.back(0.095), 0.0],
		["pinball", 0.6, kit.back(0.186), 0.0],
		["pinball", 0.72, kit.back(0.186), 0.0],
		["air_hockey", 0.4, 2.3, 0.0],
		["foosball", 0.95, 2.3, 0.0],
		["dj_booth", 1.55, kit.back(0.105), 0.0],
		["drum_kit", 2.05, 2.6, 0.0],
		["diner_booth", 3.0, 2.7, 0.0],
		["diner_booth", 3.3, 2.7, 0.0],
		["soda_machine", 3.65, kit.back(0.105), 0.0],
		["gumball", 3.82, kit.back(0.046), 0.0],
		["jukebox", 4.0, kit.back(0.086), 0.0],
		["ice_cream_cart", 2.95, 1.9, 0.0],
		["pool_table", 3.95, 1.6, 0.0],
		["ping_pong", 3.95, 1.05, 0.0],
		["bar_stools", 3.15, 2.3, 0.0],
		["tree_palm", 0.2, 0.55, 0.0],
		["parasol_table", 0.55, 0.3, 0.0],
		["kiddie_car", 1.2, 0.35, 0.0],
		["kiddie_rocket", 1.6, 0.35, 0.0],
		["phone_booth", 2.15, 0.22, 0.0],
		["string_lights", 3.2, 0.1, 0.0],
		["tree_palm", 3.5, 0.35, 0.0],
		["picnic_table", 3.3, 0.95, 0.0],
		["bbq", 0.75, 0.6, 0.0],
		["tree_blossom", 0.4, 1.5, 0.0],
		["string_lights", 1.6, 1.9, 0.0],
		["cactus", 0.9, 0.1, 0.0],
		["sunflowers", 2.6, 0.08, 0.0],
		["neon_bolt", "back", 0.25],
		["neon_open", "back", 0.65],
		["neon_flame", "back", 1.1],
		["wall_tv", "back", 1.55],
		["neon_flag", "back", 2.05],
		["dartboard", "back", 2.5],
		["poster_race", "back", 2.8],
		["neon_speed", "back", 3.3],
		["neon_piston", "back", 3.85],
		["license_plates", "left", 0.9],
		["neon_wrench", "left", 1.6],
		["helmet_shelf", "left", 2.3],
	]
	return {
		"wall_surface": "wall_candy",
		"bays": [[4.3, 0.5, 90.0]],
		"cars": ["vw_t1_bus", "chevrolet_bel_air_1956", "mini_cooper_1965"],
		"tiles": [
			["checker_mint", 0, 0, 26, 16],
			["checker_pink", 0, 11, 6, 16],
			["wood_dark", 7, 13, 13, 16],
			["checker_yellow", 15, 9, 26, 16],
			["turf", 0, 0, 5, 4],
			["race_stripe", 6, 5, 16, 10],
		],
		"items": items,
	}
