extends RefCounted
## ÖNE ÇIKAN ARKADAŞLARIN GARAJ TASARIMLARI (build_featured.gd kurar, doğrular, dışa aktarır).
##
## Koordinat: garaj 4. seviye (5,6 × 3,6). Göz (i, j) ön-sağ köşeden: i → −x (ekranda SOLA), j → −z
## (ekranda SAĞA). Ekranda alt köşe (0, 0), sol köşe (31, 0), sağ köşe (0, 19), üst köşe (31, 19).
## Sol duvar ekranın sol üst kenarı ("left", z boyunca), arka duvar sağ üst kenarı ("back", x boyunca).
## Kameraya yakın uzun eşya arkasını kapatır: uzunlar duvar diplerine.
##
## items:  ["eşya", x, z, yön°]  ya da duvar eşyası ["eşya", "back" | "left", duvar boyunca konum]
## tiles:  ["desen", i0, j0, i1, j1] dikdörtgenleri, sırayla (sonraki üstüne boyar)
## walls:  ["parça", "kaplama", "x" | "z", sabit çizgi, baş, son]  (x: z-çizgisi b üzerinde a=baş..son)
## cars:   araç kimlikleri; araçlar FABRİKA renginde durur (boya yok).


static func all() -> Array[Dictionary]:
	return [gece(), pamuk()]


## Göz merkezinin dünya X'i / Z'si.
static func cx(i: float) -> float:
	return -0.2 - 0.175 * (i + 0.5)


static func cz(j: float) -> float:
	return -0.2 - 0.175 * (j + 0.5)


## Üç tamir alanı: sol köşedeki atölyede, sol duvara doğru yan yana (iki garajda aynı).
static func workshop_bays() -> Array:
	return [
		{"x": cx(19.5), "z": cz(3.0), "yaw": 0.0},
		{"x": cx(23.5), "z": cz(3.0), "yaw": 0.0},
		{"x": cx(27.5), "z": cz(3.0), "yaw": 0.0},
	]


# --- EMRE · GECE GARAJI (karanlık) ----------------------------------------------------------

static func gece() -> Dictionary:
	return {
		"id": "featured_emre", "name": "Emre Usta", "level": 48,
		"wall_surface": "wall_black",
		"bays": workshop_bays(),
		# Fabrika renkleri: kırmızı 488, beyaz Huracán, koyu yeşil GT3 (sergi); siyah E60, gri RS6, gümüş CLS
		"cars": ["ferrari_488_pista", "lambo_huracan", "porsche_gt3", "bmw_e60", "audi_rs6", "mercedes_cls"],
		"tiles": [
			["diamond_black", 0, 0, 31, 20],
			# atölye: kauçuk zemin, tehlike şeridi çerçeve
			["hazard", 17, 0, 31, 8],
			["rubber", 18, 0, 31, 7],
			# sergi: karbon, araç başına dama altlık
			["carbon", 15, 9, 31, 20],
			["checker_bw", 17, 11, 20, 15],
			["checker_bw", 22, 14, 25, 18],
			["checker_bw", 27, 11, 30, 15],
			# lounge: koyu parke, kırmızı dama halı
			["wood_dark", 0, 12, 13, 20],
			["checker_red", 3, 15, 8, 18],
			# giriş plazası: yarış şeridi, park yerleri, motosiklet altlığı
			["race_stripe", 7, 0, 8, 11],
			["checker_bw_big", 0, 0, 3, 3],
			["diamond_silver", 0, 5, 5, 11],
			["diamond_silver", 9, 5, 14, 8],
			["diamond_silver", 12, 1, 15, 4],
			["hazard", 0, 4, 5, 4],
			["hazard", 9, 4, 14, 4],
		],
		"walls": [
			# sergi camı: önden ve yandan
			["wall_glass", "", "x", 9, 15, 32],
			["wall_glass", "", "z", 15, 9, 15],
			# lounge: pencereli siyah bölme (sağda giriş boşluğu)
			["wall_window", "wall_black", "x", 12, 4, 14],
		],
		"items": [
			# araçlar
			["car:lambo_huracan", cx(18.5), cz(13.0), 30.0],
			["car:ferrari_488_pista", cx(23.5), cz(16.0), 30.0],
			["car:porsche_gt3", cx(28.5), cz(13.0), 30.0],
			["car:audi_rs6", cx(2.6), cz(6.5), 90.0],
			["car:bmw_e60", cx(2.6), cz(9.6), 90.0],
			["car:mercedes_cls", cx(11.5), cz(6.5), 90.0],
			# atölye
			["tool_cabinet", -5.68, cz(1.0), 90.0],
			["parts_shelf", -5.68, cz(5.2), 90.0],
			["workbench", cx(23.5), cz(6.6), 0.0],
			["tool_trolley", cx(21.0), cz(6.6), 0.0],
			["compressor", cx(26.5), cz(6.6), 0.0],
			["tyre_rack", cx(29.0), cz(6.6), 0.0],
			["barrel_rack", cx(19.2), cz(6.6), 0.0],
			["oil_drums", cx(17.6), cz(7.4), 0.0],
			["engine_block", cx(17.3), cz(1.0), 0.0],
			["jack_stand", -4.05, cz(1.0), 0.0],
			["welding_set", -4.75, cz(0.6), 0.0],
			["mechanic", -4.78, cz(4.4), 0.0],
			["traffic_cones", cx(15.0), cz(0.4), 0.0],
			# sergi
			["trophy_case", cx(16.5), cz(19.4), 0.0],
			["trophy_case", cx(20.2), cz(19.4), 0.0],
			["floodlight", cx(30.6), cz(19.5), 0.0],
			["floodlight", cx(30.6), cz(9.8), 0.0],
			["floodlight", cx(25.8), cz(19.5), 0.0],
			["bollards", cx(18.5), cz(10.4), 0.0],
			["bollards", cx(28.5), cz(10.4), 0.0],
			["bollards", cx(23.5), cz(13.4), 0.0],
			# lounge
			["sofa", cx(5.5), -3.66, 0.0],
			["sofa", cx(0.5), cz(16.0), 90.0],
			["coffee_table", cx(5.5), cz(17.2), 0.0],
			["jukebox", cx(1.0), -3.66, 0.0],
			["vending", cx(9.5), -3.66, 0.0],
			["vending", cx(11.0), -3.66, 0.0],
			["foosball", cx(5.5), cz(14.3), 0.0],
			["trophy_case", cx(12.5), cz(19.4), 0.0],
			["potted_plant", cx(12.8), cz(13.2), 0.0],
			["cooler", cx(8.6), cz(13.2), 0.0],
			# giriş plazası
			["motorcycle", cx(13.5), cz(2.5), 45.0],
			["bollards", cx(5.5), cz(0.3), 0.0],
			["bollards", cx(10.0), cz(0.3), 0.0],
			["arrow_sign", cx(3.9), cz(0.4), 0.0],
			["speed_bump", cx(7.5), cz(2.0), 90.0],
			["floodlight", cx(0.3), cz(10.6), 0.0],
			["floodlight", cx(16.0), cz(0.5), 0.0],
			["fuel_pump", cx(13.0), cz(10.3), 0.0],
			["air_station", cx(11.8), cz(10.3), 0.0],
			["parking_sign", cx(0.3), cz(4.4), 0.0],
			# arka duvar (x boyunca): lounge
			["wall_tv", "back", cx(1.5)],
			["led_strip", "back", cx(3.4)],
			["neon_garage", "back", cx(5.5)],
			["wall_lamp", "back", cx(7.6)],
			["neon_open", "back", cx(10.0)],
			["neon_sign", "back", cx(13.0)],
			["checkered_flags", "back", cx(15.6)],
			# arka duvar: sergi
			["led_strip", "back", cx(18.5)],
			["plate_frame", "back", cx(20.8)],
			["neon_car", "back", cx(23.5)],
			["wall_lamp", "back", cx(26.0)],
			["led_strip", "back", cx(28.5)],
			["poster_red", "back", cx(30.4)],
			# sol duvar (z boyunca): atölye
			["wall_shelf", "left", cz(0.6)],
			["pegboard", "left", cz(3.0)],
			["extinguisher_wall", "left", cz(5.2)],
			["tyre_hanger", "left", cz(7.4)],
			# sol duvar: sergi
			["neon_piston", "left", cz(10.0)],
			["rim_display", "left", cz(11.5)],
			["neon_flag", "left", cz(13.0)],
			["led_strip", "left", cz(14.8)],
			["neon_bolt", "left", cz(16.5)],
			["trophy_shelf", "left", cz(19.0)],
		],
	}


# --- ELİF · PAMUK GARAJ (ponçik) -------------------------------------------------------------

static func pamuk() -> Dictionary:
	return {
		"id": "featured_elif", "name": "Elif Usta", "level": 45,
		"wall_surface": "wall_candy",
		"bays": workshop_bays(),
		# Fabrika renkleri: beyaz Huracán, kırmızı Golf, beyaz Şahin, beyaz A3 (pembe otopark); gümüş CLS, kırmızı Getz
		"cars": ["lambo_huracan", "vw_golf_7", "tofas_sahin", "audi_a3", "mercedes_cls", "hyundai_getz"],
		"tiles": [
			["wood_white", 0, 0, 31, 20],
			# atölye: nane dama
			["checker_mint", 17, 0, 31, 8],
			# bahçe kafe: pastel karo
			["tile_pastel", 15, 10, 31, 20],
			# pastel otopark: pembe dama
			["checker_pink", 0, 3, 16, 10],
			# lounge: açık parke, ortada pastel halı
			["wood_light", 0, 12, 13, 20],
			["tile_pastel", 3, 16, 6, 18],
			# giriş yolu
			["checker_pink", 7, 0, 8, 2],
		],
		"walls": [
			["wall_half", "wall_mint", "x", 10, 15, 21],
			["wall_half", "wall_mint", "x", 10, 25, 32],
			["wall_half", "wall_pink", "z", 14, 10, 14],
			["wall_half", "wall_pink", "z", 14, 17, 21],
		],
		"items": [
			# araçlar
			["car:lambo_huracan", cx(1.8), cz(6.5), 60.0],
			["car:vw_golf_7", cx(6.0), cz(6.5), 60.0],
			["car:tofas_sahin", cx(10.2), cz(6.5), 60.0],
			["car:audi_a3", cx(14.4), cz(6.5), 60.0],
			["car:mercedes_cls", cx(3.0), cz(13.5), 90.0],
			["car:hyundai_getz", cx(9.5), cz(13.5), 90.0],
			# atölye
			["tool_cabinet", -5.68, cz(1.0), 90.0],
			["tyre_rack", -5.68, cz(5.2), 90.0],
			["workbench", cx(23.5), cz(6.6), 0.0],
			["tool_trolley", cx(21.0), cz(6.6), 0.0],
			["compressor", cx(26.5), cz(6.6), 0.0],
			["tyre_planter", cx(29.0), cz(6.6), 0.0],
			["tyre_planter", cx(29.7), cz(6.6), 0.0],
			["potted_plant", cx(17.3), cz(6.6), 0.0],
			["jack_stand", -4.05, cz(1.0), 0.0],
			["mechanic", -4.78, cz(4.4), 0.0],
			# bahçe kafe
			["tree_round", cx(30.0), -3.6, 0.0],
			["tree_round", cx(21.5), -3.6, 0.0],
			["tree_palm", cx(16.3), -3.58, 0.0],
			["tree_slim", cx(26.3), -3.65, 0.0],
			["parasol_table", cx(26.0), cz(15.5), 0.0],
			["parasol_table", cx(20.5), cz(15.5), 0.0],
			["string_lights", cx(23.3), cz(12.0), 0.0],
			["string_lights", cx(23.3), cz(18.4), 0.0],
			["picnic_table", cx(29.0), cz(16.0), 90.0],
			["dog_house", -5.68, cz(12.5), 90.0],
			["flower_bed", cx(23.3), -3.66, 0.0],
			["vase_large", cx(24.7), -3.66, 0.0],
			["bench", cx(19.5), -3.67, 0.0],
			["potted_plant", cx(28.0), -3.67, 0.0],
			["cooler", cx(28.5), cz(12.0), 0.0],
			["bbq", cx(17.0), cz(17.5), 0.0],
			["deck_chair", cx(18.0), cz(13.0), 0.0],
			["deck_chair", cx(17.3), cz(13.0), 0.0],
			["tyre_planter", cx(20.4), cz(11.0), 0.0],
			["tyre_planter", cx(25.6), cz(11.0), 0.0],
			["planter_box", cx(30.4), cz(11.0), 90.0],
			# otopark çevresi / giriş
			["flower_bed", cx(1.2), cz(0.6), 0.0],
			["planter_box", cx(4.5), cz(0.4), 0.0],
			["planter_box", cx(11.0), cz(0.4), 0.0],
			["vase_large", cx(13.5), cz(1.0), 0.0],
			["tyre_planter", cx(15.8), cz(0.6), 0.0],
			["string_lights", cx(8.0), cz(1.8), 0.0],
			["hedge", cx(6.5), cz(11.0), 0.0],
			["hedge", cx(2.5), cz(11.0), 0.0],
			["hedge", cx(11.0), cz(11.0), 0.0],
			# sağ köşe lounge
			["sofa", cx(4.0), -3.66, 0.0],
			["coffee_table", cx(4.0), cz(17.9), 0.0],
			["deck_chair", cx(7.0), cz(17.5), 0.0],
			["flower_bed", cx(10.5), cz(17.8), 0.0],
			["potted_plant", cx(0.8), -3.67, 0.0],
			["vase_large", cx(10.0), -3.66, 0.0],
			["jukebox", cx(11.9), -3.67, 0.0],
			["tree_slim", cx(13.0), -3.65, 0.0],
			# arka duvar: lounge
			["poster_vintage", "back", cx(1.5)],
			["wall_window_deco", "back", cx(4.0)],
			["wall_lamp", "back", cx(6.0)],
			["wall_clock", "back", cx(8.0)],
			["plate_frame", "back", cx(10.5)],
			["wall_lamp", "back", cx(12.5)],
			# arka duvar: kafe
			["wall_window_deco", "back", cx(17.6)],
			["wall_lamp", "back", cx(19.5)],
			["wall_window_deco", "back", cx(23.3)],
			["wall_lamp", "back", cx(27.0)],
			["wall_clock", "back", cx(29.0)],
			# sol duvar: atölye
			["wall_shelf", "left", cz(0.6)],
			["pegboard", "left", cz(3.0)],
			["first_aid", "left", cz(5.2)],
			["wall_clock", "left", cz(7.4)],
			# sol duvar: kafe
			["plate_frame", "left", cz(11.5)],
			["wall_lamp", "left", cz(13.5)],
			["wall_window_deco", "left", cz(15.5)],
			["wall_window_deco", "left", cz(18.5)],
		],
	}
