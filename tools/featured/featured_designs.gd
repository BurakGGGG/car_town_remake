extends RefCounted
## ÖNE ÇIKAN ARKADAŞLARIN GARAJ TASARIMLARI (build_featured.gd kurar, doğrular, dışa aktarır).
##
## Koordinat: garaj 4. seviye (5,6 × 3,675 = 32 × 21 göz). Göz (i, j) ön-sağ köşeden: i → −x (ekranda
## SOLA), j → −z (ekranda SAĞA). Ekranda alt köşe (0, 0), sol köşe (31, 0), sağ köşe (0, 20), üst köşe
## (31, 20). Sol duvar ekranın sol üst kenarı ("left", z boyunca, iç yüzü x = −5,8), arka duvar sağ üst
## kenarı ("back", x boyunca, iç yüzü z = −3,875). Ön (j = 0) ve sağ (i = 0) kenarlar açıktır.
## Kameraya yakın uzun eşya arkasını kapatır: uzunlar duvar diplerine, öne alçaklar.
##
## items:  ["eşya", x, z, yön°]  ya da duvar eşyası ["eşya", "back" | "left", duvar boyunca konum]
## tiles:  ["desen", i0, j0, i1, j1] dikdörtgenleri, sırayla (sonraki üstüne boyar)
## walls:  ["parça", "kaplama", "x" | "z", sabit çizgi, baş, son]  (x: z-çizgisi b üzerinde a=baş..son)
## cars:   araç kimlikleri; araçlar FABRİKA renginde durur (boya yok: bazı modellerin boya maskesi
##         gövdeyi kapsamıyor, Fiat 500'de yalnız tavan boyandı).
##
## Duvar dibi yardımcıları (L / B / R / F) eşyanın o eksendeki boyunu alır (yön 90°'de en ve boy yer
## değiştirir): eşya duvara / açık kenara yaslanır. Boylar: qa/featured_katalog.gd dökümü.

const LEFT_FACE: float = -5.8
const BACK_FACE: float = -3.875
const RIGHT_EDGE: float = -0.2
const FRONT_EDGE: float = -0.2


static func all() -> Array[Dictionary]:
	return [gece(), pamuk()]


## Göz merkezinin dünya X'i / Z'si.
static func cx(i: float) -> float:
	return -0.2 - 0.175 * (i + 0.5)


static func cz(j: float) -> float:
	return -0.2 - 0.175 * (j + 0.5)


## Sol duvara yaslı eşyanın X'i (`ext`: eşyanın x boyu).
static func L(ext: float) -> float:
	return LEFT_FACE + 0.006 + ext * 0.5


## Arka duvara yaslı eşyanın Z'si (`ext`: eşyanın z boyu).
static func B(ext: float) -> float:
	return BACK_FACE + 0.006 + ext * 0.5


## Sağ açık kenara yaslı eşyanın X'i.
static func R(ext: float) -> float:
	return RIGHT_EDGE - 0.009 - ext * 0.5


## Ön açık kenara yaslı eşyanın Z'si.
static func F(ext: float) -> float:
	return FRONT_EDGE - 0.009 - ext * 0.5


## Üç tamir alanı: sol köşedeki atölyede, sol duvara doğru yan yana (iki garajda aynı).
static func workshop_bays() -> Array:
	return [
		{"x": cx(19.5), "z": cz(3.0), "yaw": 0.0},
		{"x": cx(23.5), "z": cz(3.0), "yaw": 0.0},
		{"x": cx(27.5), "z": cz(3.0), "yaw": 0.0},
	]


# --- EMRE · GECE GARAJI (karanlık, neon, süper araçlar) -------------------------------------
#
#   üst köşe   : CAM VİTRİN — karbon zemin, dört süper araç baklava dizilişte, dama kaideler,
#                projektörler, kupa vitrinleri, duvarda neon ve LED
#   sol köşe   : KIRMIZI ATÖLYE — kırmızı epoksi, tehlike şeridi çerçeve, üç tamir alanı
#   sağ köşe   : VIP LOUNGE — koyu parke, kırmızı dama halı, kanepeler, TV, jukebox, otomatlar
#   alt köşe   : GİRİŞ MEYDANI — yarış şeritli giriş yolu, sağda muscle, solda ralli efsaneleri

static func gece() -> Dictionary:
	return {
		"id": "featured_emre", "name": "Emre Usta", "level": 48,
		"wall_surface": "wall_black",
		"bays": workshop_bays(),
		"cars": ["ferrari_488_pista", "lambo_huracan", "porsche_gt3", "lamborghini_miura",
			"dodge_charger_1970", "chevrolet_camaro", "ford_mustang_1967",
			"audi_quattro_s1", "lancia_stratos", "bmw_m3_e30"],
		"tiles": [
			["diamond_black", 0, 0, 31, 20],
			# atölye: kırmızı epoksi, tehlike şeridi çerçeve
			["hazard", 17, 0, 31, 9],
			["epoxy_red", 18, 0, 31, 8],
			# vitrin: karbon, araç başına dama kaide (kahraman Ferrari iri dama)
			["carbon", 15, 9, 31, 20],
			["diamond_silver", 22, 10, 25, 14],
			["diamond_silver", 17, 13, 20, 18],
			["diamond_silver", 27, 13, 30, 18],
			["checker_bw", 21, 16, 26, 20],
			# geçit: vitrin ile lounge arası koyu sac
			["diamond_silver", 14, 12, 14, 20],
			# lounge: koyu parke, kırmızı dama halı
			["wood_dark", 0, 12, 13, 20],
			["checker_red", 3, 14, 9, 18],
			# giriş meydanı: asfalt, yarış şeridi, gümüş sac park yerleri, tehlike çizgisi bölücüler
			["asphalt", 0, 0, 16, 11],
			["race_stripe", 7, 0, 8, 11],
			["diamond_silver", 0, 0, 6, 11],
			["diamond_silver", 9, 0, 14, 11],
			["hazard", 0, 3, 6, 3],
			["hazard", 0, 7, 6, 7],
			["hazard", 9, 3, 14, 3],
			["hazard", 9, 7, 14, 7],
			["checker_bw_big", 15, 0, 16, 2],
		],
		"walls": [
			# vitrin camı: önden ve yandan (yan camın arkası açık: lounge geçidi)
			["wall_glass", "", "x", 9, 15, 32],
			["wall_glass", "", "z", 15, 9, 16],
			# lounge: pencereli siyah bölme (sağda giriş boşluğu)
			["wall_window", "wall_red", "x", 12, 4, 14],
		],
		"items": [
			# --- vitrin: baklava dizilişte dört süper araç
			["car:ferrari_488_pista", cx(23.5), cz(18.2), 0.0],
			["car:lamborghini_miura", cx(23.5), cz(11.9), 45.0],
			["car:lambo_huracan", cx(18.7), cz(15.5), 30.0],
			["car:porsche_gt3", cx(28.3), cz(15.5), -30.0],
			["trophy_case", cx(17.0), B(0.071), 0.0],
			["trophy_case", cx(19.0), B(0.071), 0.0],
			["trophy_case", cx(28.0), B(0.071), 0.0],
			["trophy_case", cx(30.0), B(0.071), 0.0],
			["floodlight", L(0.096), B(0.051), 0.0],
			["floodlight", L(0.096), cz(9.6), 0.0],
			["floodlight", cx(15.6), B(0.051), 0.0],
			["floodlight", cx(15.6), cz(9.6), 0.0],
			["bollards", cx(23.5), cz(9.4), 0.0],
			["bollards", cx(18.7), cz(12.6), 0.0],
			["bollards", cx(28.3), cz(12.6), 0.0],
			["potted_plant", L(0.128), cz(12.0), 0.0],
			["potted_plant", L(0.128), cz(19.0), 0.0],
			# --- atölye
			["tool_cabinet", L(0.115), cz(0.7), 90.0],
			["parts_shelf", L(0.125), cz(2.6), 90.0],
			["tyre_rack", L(0.127), cz(4.3), 90.0],
			["welding_set", L(0.057), cz(5.6), 0.0],
			["barrel_rack", L(0.068), cz(6.9), 90.0],
			["oil_drums", cx(18.3), cz(7.3), 0.0],
			["tool_trolley", cx(21.0), cz(7.3), 0.0],
			["workbench", cx(23.5), cz(7.3), 0.0],
			["compressor", cx(26.0), cz(7.3), 0.0],
			["engine_block", cx(28.0), cz(7.3), 0.0],
			["jack_stand", cx(29.5), cz(7.3), 0.0],
			["mechanic", cx(21.5), cz(2.0), 0.0],
			["mechanic", cx(25.5), cz(3.5), 0.0],
			["cable_reel", cx(21.5), F(0.062), 0.0],
			["extinguisher_stand", cx(17.6), cz(1.0), 0.0],
			["jerry_cans", cx(17.6), cz(3.0), 0.0],
			["traffic_cones", cx(29.3), F(0.101), 0.0],
			# --- lounge
			["sofa", cx(5.5), B(0.125), 0.0],
			["sofa", R(0.125), cz(16.0), 90.0],
			["coffee_table", cx(5.5), cz(17.6), 0.0],
			["foosball", cx(6.0), cz(14.6), 0.0],
			["jukebox", cx(1.0), B(0.086), 0.0],
			["vending", cx(9.3), B(0.115), 0.0],
			["vending", cx(10.2), B(0.115), 0.0],
			["trophy_case", cx(12.3), B(0.071), 0.0],
			["potted_plant", cx(12.6), cz(13.0), 0.0],
			["potted_plant", cx(2.6), B(0.113), 0.0],
			["potted_plant", R(0.128), cz(12.8), 0.0],
			["cooler", cx(8.8), cz(13.0), 0.0],
			["vase_large", cx(11.0), cz(13.0), 0.0],
			# --- giriş meydanı: sağda muscle, solda ralli (giriş yoluna bakar)
			["car:dodge_charger_1970", cx(3.0), cz(1.5), 90.0],
			["car:chevrolet_camaro", cx(3.0), cz(5.5), 90.0],
			["car:ford_mustang_1967", cx(3.0), cz(9.5), 90.0],
			["car:audi_quattro_s1", cx(11.5), cz(1.5), -90.0],
			["car:lancia_stratos", cx(11.5), cz(5.5), -90.0],
			["car:bmw_m3_e30", cx(11.5), cz(9.5), -90.0],
			["speed_bump", cx(7.5), cz(4.0), 0.0],
			["speed_bump", cx(7.5), cz(8.0), 0.0],
			["arrow_sign", cx(6.3), F(0.042), 0.0],
			["bollards", cx(7.5), cz(10.9), 0.0],
			["floodlight", R(0.096), cz(11.4), 0.0],
			["floodlight", cx(14.0), cz(10.6), 0.0],
			["fuel_pump", cx(15.6), cz(5.3), 90.0],
			["air_station", cx(15.6), cz(4.2), 0.0],
			["motorcycle", cx(15.6), cz(7.3), 90.0],
			["parking_sign", R(0.046), cz(3.5), 0.0],
			["parking_sign", R(0.046), cz(7.5), 0.0],
			["warning_sign", cx(15.6), cz(3.3), 0.0],
			# --- arka duvar: lounge
			["neon_garage", "back", cx(2.4)],
			["wall_tv", "back", cx(5.5)],
			["wall_lamp", "back", cx(7.3)],
			["neon_open", "back", cx(9.7)],
			["checkered_flags", "back", cx(12.3)],
			["led_strip", "back", cx(4.0)],
			# --- arka duvar: vitrin
			["neon_sign", "back", cx(23.5)],
			["led_strip", "back", cx(17.9)],
			["led_strip", "back", cx(29.0)],
			["neon_car", "back", cx(20.7)],
			["neon_car", "back", cx(26.3)],
			["neon_bolt", "back", cx(15.4)],
			["neon_flag", "back", cx(31.3)],
			# --- sol duvar: atölye
			["pegboard", "left", cz(0.9)],
			["wall_shelf", "left", cz(2.6)],
			["tyre_hanger", "left", cz(4.4)],
			["extinguisher_wall", "left", cz(5.6)],
			["job_board", "left", cz(7.0)],
			# --- sol duvar: vitrin
			["neon_piston", "left", cz(10.2)],
			["rim_display", "left", cz(11.9)],
			["led_strip", "left", cz(13.9)],
			["trophy_shelf", "left", cz(15.7)],
			["rim_display", "left", cz(17.4)],
			["neon_bolt", "left", cz(19.0)],
			["poster_red", "left", cz(20.2)],
		],
	}


# --- ELİF · PAMUK GARAJ (pastel, çiçekli, şirin araçlar) --------------------------------------
#
#   üst köşe   : BAHÇE KAFE — pastel karo, ortada dondurmacı gibi duran T1 minibüs, şemsiyeli
#                masalar, ışık dizileri, ağaçlar, çiçek tarhları, köpek kulübesi
#   sol köşe   : NANE ATÖLYE — nane dama, üç tamir alanı, saksılarla süslü tezgâh
#   sağ köşe   : PEMBE DİNER — pembe dama, Bel Air ve Fiat 500 sergide, jukebox, kanepe
#   alt köşe   : ŞEKER OTOPARK — pembe dama park yerleri, aralarda saksı sıraları, giriş yolunun
#                üstünde ışık dizileri, kenarlarda çiçek

static func pamuk() -> Dictionary:
	return {
		"id": "featured_elif", "name": "Elif Usta", "level": 45,
		"wall_surface": "wall_candy",
		"bays": workshop_bays(),
		"cars": ["vw_t1_bus", "chevrolet_bel_air_1956", "fiat_500_1965", "mini_cooper_1965",
			"vw_beetle", "vw_beetle_1967", "hyundai_getz", "tofas_murat_124", "peugeot_404"],
		"tiles": [
			["wood_white", 0, 0, 31, 20],
			# atölye: nane dama
			["checker_mint", 17, 0, 31, 8],
			# bahçe kafe: pastel karo, minibüsün altında pembe dama
			["tile_pastel", 15, 9, 31, 20],
			["checker_pink", 21, 12, 26, 17],
			# diner: pembe dama, araç kaideleri pastel
			["wood_light", 0, 12, 13, 20],
			["checker_pink", 1, 13, 6, 16],
			["checker_mint", 9, 13, 12, 17],
			# şeker otopark: beyaz parke üstünde pembe park yerleri, nane giriş yolu
			["checker_pink", 0, 0, 6, 11],
			["checker_pink", 9, 0, 14, 11],
			["checker_mint", 7, 0, 8, 11],
			["checker_mint", 0, 3, 6, 3],
			["checker_mint", 0, 7, 6, 7],
			["checker_mint", 9, 3, 14, 3],
			["checker_mint", 9, 7, 14, 7],
		],
		"walls": [
			["wall_half", "wall_mint", "x", 9, 15, 21],
			["wall_half", "wall_mint", "x", 9, 26, 32],
			["wall_half", "wall_pink", "z", 15, 9, 13],
			["wall_half", "wall_pink", "z", 15, 17, 21],
			["wall_half", "wall_lilac", "x", 12, 5, 14],
		],
		"items": [
			# --- bahçe kafe
			["car:vw_t1_bus", cx(23.5), cz(14.5), 60.0],
			["parasol_table", cx(18.2), cz(11.4), 0.0],
			["parasol_table", cx(28.6), cz(11.4), 0.0],
			["parasol_table", cx(18.2), cz(17.6), 0.0],
			["picnic_table", cx(28.4), cz(17.4), 90.0],
			["string_lights", cx(23.5), cz(10.4), 0.0],
			["string_lights", cx(23.5), cz(19.0), 0.0],
			["tree_round", cx(30.4), B(0.208), 0.0],
			["tree_palm", cx(21.0), B(0.273), 0.0],
			["tree_slim", cx(26.0), B(0.126), 0.0],
			["tree_slim", cx(16.0), B(0.126), 0.0],
			["tree_round", L(0.224), cz(14.4), 0.0],
			["flower_bed", cx(23.5), B(0.153), 0.0],
			["flower_bed", cx(18.4), B(0.153), 0.0],
			["vase_large", cx(28.2), B(0.109), 0.0],
			["dog_house", L(0.125), cz(11.0), 90.0],
			["bbq", L(0.091), cz(17.2), 0.0],
			["cooler", L(0.087), cz(16.4), 0.0],
			["bench", cx(23.5), cz(16.9), 0.0],
			["deck_chair", cx(26.6), cz(13.3), 0.0],
			["deck_chair", cx(27.2), cz(13.3), 0.0],
			["tyre_planter", cx(20.6), cz(14.0), 0.0],
			["tyre_planter", cx(26.4), cz(15.6), 0.0],
			["tyre_planter", cx(16.2), cz(14.7), 0.0],
			["planter_box", cx(23.5), cz(9.4), 0.0],
			["potted_plant", cx(15.8), cz(9.6), 0.0],
			["potted_plant", L(0.128), cz(9.6), 0.0],
			# --- atölye
			["tool_cabinet", L(0.115), cz(0.7), 90.0],
			["tyre_rack", L(0.127), cz(2.6), 90.0],
			["potted_plant", L(0.128), cz(4.2), 0.0],
			["compressor", L(0.104), cz(5.8), 0.0],
			["workbench", cx(23.5), cz(7.3), 0.0],
			["tool_trolley", cx(21.0), cz(7.3), 0.0],
			["flower_bed", cx(26.5), cz(7.3), 0.0],
			["tyre_planter", cx(28.4), cz(7.3), 0.0],
			["tyre_planter", cx(29.2), cz(7.3), 0.0],
			["potted_plant", cx(18.4), cz(7.3), 0.0],
			["vase_large", cx(30.3), cz(7.3), 0.0],
			["mechanic", cx(21.5), cz(2.0), 0.0],
			["mechanic", cx(25.5), cz(3.5), 0.0],
			["tyre_planter", cx(17.6), cz(1.0), 0.0],
			["tyre_planter", cx(17.6), cz(3.0), 0.0],
			["tyre_planter", cx(17.6), cz(5.0), 0.0],
			# --- diner
			["car:chevrolet_bel_air_1956", cx(3.5), cz(14.5), 90.0],
			["car:fiat_500_1965", cx(10.5), cz(15.0), 60.0],
			["sofa", cx(5.0), B(0.125), 0.0],
			["coffee_table", cx(5.0), cz(18.0), 0.0],
			["jukebox", cx(1.0), B(0.086), 0.0],
			["vending", cx(8.0), B(0.115), 0.0],
			["flower_bed", cx(10.5), B(0.153), 0.0],
			["potted_plant", cx(12.6), B(0.113), 0.0],
			["potted_plant", cx(2.6), B(0.113), 0.0],
			["vase_large", R(0.107), cz(12.6), 0.0],
			["vase_large", cx(12.8), cz(12.6), 0.0],
			["deck_chair", R(0.079), cz(17.6), 0.0],
			["tyre_planter", cx(7.5), cz(13.0), 0.0],
			["tyre_planter", cx(7.5), cz(16.6), 0.0],
			# --- şeker otopark
			["car:mini_cooper_1965", cx(3.0), cz(1.5), 90.0],
			["car:vw_beetle", cx(3.0), cz(5.5), 90.0],
			["car:vw_beetle_1967", cx(3.0), cz(9.5), 90.0],
			["car:hyundai_getz", cx(11.5), cz(1.5), -90.0],
			["car:tofas_murat_124", cx(11.5), cz(5.5), -90.0],
			["car:peugeot_404", cx(11.5), cz(9.5), -90.0],
			["planter_box", cx(1.6), cz(3.5), 0.0],
			["planter_box", cx(4.4), cz(3.5), 0.0],
			["planter_box", cx(1.6), cz(7.5), 0.0],
			["planter_box", cx(4.4), cz(7.5), 0.0],
			["planter_box", cx(10.4), cz(3.5), 0.0],
			["planter_box", cx(12.8), cz(3.5), 0.0],
			["planter_box", cx(10.4), cz(7.5), 0.0],
			["planter_box", cx(12.8), cz(7.5), 0.0],
			["string_lights", cx(7.5), cz(3.5), 0.0],
			["string_lights", cx(7.5), cz(7.5), 0.0],
			["flower_bed", cx(15.6), F(0.153), 0.0],
			["flower_bed", R(0.208), cz(11.4), 0.0],
			["hedge", cx(11.5), cz(10.8), 0.0],
			["hedge", cx(2.5), cz(10.8), 0.0],
			["tyre_planter", cx(6.3), F(0.086), 0.0],
			["tyre_planter", cx(8.7), F(0.086), 0.0],
			["vase_large", cx(15.6), cz(5.0), 0.0],
			["potted_plant", cx(15.6), cz(8.0), 0.0],
			["bench", cx(15.6), cz(2.6), 90.0],
			# --- arka duvar: diner
			["poster_vintage", "back", cx(1.2)],
			["wall_window_deco", "back", cx(3.3)],
			["neon_open", "back", cx(5.0)],
			["wall_window_deco", "back", cx(6.8)],
			["wall_clock", "back", cx(8.5)],
			["plate_frame", "back", cx(10.0)],
			["wall_lamp", "back", cx(11.6)],
			["poster_vintage", "back", cx(13.0)],
			# --- arka duvar: kafe
			["wall_window_deco", "back", cx(17.3)],
			["wall_lamp", "back", cx(19.6)],
			["wall_window_deco", "back", cx(23.5)],
			["wall_lamp", "back", cx(27.4)],
			["wall_clock", "back", cx(29.2)],
			# --- sol duvar: atölye
			["wall_shelf", "left", cz(0.8)],
			["pegboard", "left", cz(2.6)],
			["first_aid", "left", cz(4.3)],
			["wall_clock", "left", cz(5.7)],
			["poster_vintage", "left", cz(7.2)],
			# --- sol duvar: kafe
			["wall_window_deco", "left", cz(10.5)],
			["wall_lamp", "left", cz(12.3)],
			["wall_window_deco", "left", cz(16.4)],
			["plate_frame", "left", cz(18.2)],
			["wall_window_deco", "left", cz(19.9)],
		],
	}
