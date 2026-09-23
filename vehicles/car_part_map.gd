class_name CarPartMap
## Araç modellerinin parça-rol haritası.
## Tripo GLB'lerinde node adları anlamsız ("tripo_part_N") ve tek materyal var; bu yüzden roller
## araç bazında ELLE eşlenir (her parça yakın plan render'larla tek tek teşhis edildi).
## Anahtar: aracın .tscn yolu (her instance'ın scene_file_path'i). İndeks N → "tripo_part_N".
## Model yeniden export edilirse indeksler değişebilir.
##
## Roller ve materyal kaynağı (CarRig):
##   body        → CarAppearance.body_color (boya)
##   mirrors     → body_color (ayna gövdesi; ayna camı modelde ayrı değil)
##   wheels      → lastik + jant TEK mesh olan tekerler: wheel_split.gdshader yarıçapa göre
##                 lastiği siyah kauçuk, jantı CarAppearance.wheel_color yapar
##   tires       → sabit siyah kauçuk (yalnızca lastik olan mesh'ler)
##   rims        → CarAppearance.wheel_color (ayrı jant kolu / göbek / fren diski parçaları)
##   glass       → CarAppearance.glass_color (opak füme; içerisi görünmez)
##   headlights  → sabit beyaz lens + headlights_enabled emissive
##   taillights  → sabit kırmızı lens + taillights_enabled emissive
##   grille, black_trim, plate, fog_lights, exhaust, antenna → sabit gerçekçi materyaller
##   hidden      → bozuk/çöp üçgenler, gizlenir
## wheel_groups: fl/fr/rl/rr — dönüş/direksiyon grupları (ilk eleman pivot kaynağı).
## split_z: tek mesh'te iki rol (Fluence ön cam + tavan): z > z eşiği → front rolü, gerisi → back.
## extract: kaynakta başka parçaya kaynamış teker; tools/optimize_car.gd silindir bölgesini yeni parçaya ayırır
##   ({part, new_part, center, radius, half_width}); çalışma zamanında ek bir şey gerekmez.

const ROLES: Array[StringName] = [
	&"body", &"mirrors", &"wheels", &"tires", &"rims", &"glass", &"headlights", &"taillights",
	&"grille", &"black_trim", &"plate", &"fog_lights", &"exhaust", &"antenna", &"hidden",
]

const MAPS: Dictionary = {
	# --- Dokulu Tripo serisi (2026-09-22): kaynak ~300–380K vertex, 63–77 parça, tek 4K basecolor dokusu;
	# --- pipeline 2048 JPEG + ~%12.5 üçgen. Ön = +Z, zemin y=0, uzunluk 1.0. Parçaların kendi pivotu var
	# --- (teker parçalarının orijini teker merkezi). Roller: geometri + doku rengi sınıflandırması, teker
	# --- grupları çeyreklere göre; BMW parça parça render'la elle doğrulandı. Dokulu modelde rol yalnızca
	# --- yeniden boyama maskesi / teker dönüşü / far emisyonu için önemlidir (görünüm dokudan gelir).
	# --- Kaynamış camlar (ör. BMW tavan + ön/arka cam = parça 0) ve tek mesh Toros dokudan görünür.
	"res://assets/cars/bmw_e_46.tscn": {
		"default_paint": Color(0.141, 0.180, 0.333),  # dokunun baskın kaporta rengi (#242E55); paint mask ile aynı olmalı
		"body": [0, 1, 5, 7, 8, 9, 10, 11, 12, 13, 15, 19, 21, 23, 26, 27, 37, 38, 54, 58, 64],
		"mirrors": [18, 25],
		"wheels": [2, 3, 4, 67],
		"glass": [28, 29, 32, 34, 59, 63],
		"headlights": [48, 50, 60, 65],
		"taillights": [44, 45],
		"grille": [16, 24, 33, 39, 40, 41, 43, 46, 51, 57],
		"black_trim": [6, 14, 20, 22, 30, 31, 35, 36, 42, 53, 55, 56, 61, 62, 66],
		"plate": [17],
		"fog_lights": [47, 49],
		"exhaust": [52],
		"extract": [{"part": 1, "new_part": 67, "center": [-0.199, 0.103, -0.326], "radius": 0.108, "half_width": 0.045}],  # arka-sol teker alt kabuğa (1) kaynamış
		"wheel_groups": {"fl": [4], "fr": [3], "rl": [67], "rr": [2]},
	},
	"res://assets/cars/hyundai_era.tscn": {
		"default_paint": Color(0.918, 0.910, 0.918),  # dokunun baskın kaporta rengi (#EAE8EA); paint mask ile aynı olmalı
		"body": [0, 1, 2, 7, 14, 15, 16, 17, 20, 21, 22, 26, 27, 31, 40, 53, 60, 62, 64, 65, 66, 70, 72, 73, 74],
		"mirrors": [34, 35],
		"wheels": [9],
		"tires": [8, 12, 13],
		"rims": [3, 4, 5, 11, 41],
		"glass": [6, 23, 24, 32, 52, 54],
		"headlights": [43, 47, 48, 68, 69, 71],
		"taillights": [38, 57, 59, 63],
		"grille": [25, 29, 33, 37, 42, 67],
		"black_trim": [10, 18, 19, 30, 36, 39, 44, 45, 46, 49, 50, 51, 55, 56, 58],
		"plate": [28],
		"antenna": [61],
		"wheel_groups": {"fl": [13, 4], "fr": [9, 3], "rl": [8, 5, 41], "rr": [12, 11]},
	},
	"res://assets/cars/hyundai_getz.tscn": {
		"default_paint": Color(0.847, 0.004, 0.039),  # dokunun baskın kaporta rengi (#D8010A); paint mask ile aynı olmalı
		"body": [0, 3, 5, 8, 9, 10, 13, 16, 17, 18, 21, 22, 23, 24, 26, 28, 32, 38, 41, 47, 50, 53, 54, 55, 56, 57, 59, 63, 64, 67],  # 3/10/23/50/54/55/57 siyah trim, 16/26 arka tampon (stop sanılmıştı): dokuda kırmızı kaporta
		"mirrors": [15, 25],
		"wheels": [1, 2, 19],
		"tires": [6],
		"rims": [4],
		"glass": [7, 33, 34, 37, 43, 60, 68],
		"headlights": [40, 51, 52, 58, 65],
		"taillights": [36, 44, 46, 48, 61],
		"grille": [39],
		"black_trim": [11, 12, 14, 20, 27, 29, 30, 31, 35, 42, 45, 49, 62, 66],
		"wheel_groups": {"fl": [19], "fr": [1], "rl": [2], "rr": [6, 4]},
	},
	"res://assets/cars/renault_fluence.tscn": {
		"default_paint": Color(0.659, 0.678, 0.682),  # dokunun baskın kaporta rengi (#A8ADAE); paint mask ile aynı olmalı
		"body": [0, 3, 5, 6, 7, 9, 11, 13, 14, 15, 16, 19, 21, 22, 24, 26, 27, 29, 30, 35, 36, 37, 38, 39, 40, 42, 45, 49],
		"mirrors": [23, 56],
		"wheels": [1, 2],
		"tires": [4, 10],
		"rims": [8, 17, 20, 25, 32, 50],
		"glass": [12, 18, 28, 31, 34, 52, 53, 54, 57, 58, 61, 62],
		"headlights": [41, 51, 59, 60],
		"taillights": [43, 44, 55],
		"grille": [33, 46, 47, 48],
		"wheel_groups": {"fl": [2], "fr": [1], "rl": [10, 25, 20, 32, 50], "rr": [4, 8, 17]},
	},
	"res://assets/cars/volswagen_passat_b_5_5.tscn": {
		"default_paint": Color(0.678, 0.690, 0.698),  # dokunun baskın kaporta rengi (#ADB0B2); paint mask ile aynı olmalı
		"body": [0, 6, 7, 8, 9, 11, 12, 16, 19, 20, 21, 22, 23, 30, 31, 32, 33, 35, 38, 45, 48, 61, 64, 66, 68],
		"mirrors": [15, 27],
		"wheels": [1, 2, 3, 4],
		"rims": [13, 14, 24, 26],
		"glass": [5, 17, 25, 29, 34, 46, 55],
		"headlights": [37, 42, 50, 51, 52],
		"taillights": [36, 67],
		"grille": [18, 43, 44, 47, 49, 54, 57, 58, 62, 63],
		"black_trim": [10, 39, 40, 41, 53, 56, 59, 60, 65],
		"plate": [28],
		"wheel_groups": {"fl": [1, 24], "fr": [4, 26], "rl": [2, 13], "rr": [3, 14]},
	},
	"res://assets/cars/tofas_sahin.tscn": {
		"default_paint": Color(0.918, 0.910, 0.918),  # dokunun baskın kaporta rengi (#EAE8EA); paint mask ile aynı olmalı
		"body": [0, 1, 4, 9, 11, 13, 15, 16, 17, 22, 28, 29, 30, 31, 33, 38, 41, 44, 47, 49, 50, 51, 54, 55, 56, 64, 65, 70, 71, 72, 76],
		"wheels": [2, 8],
		"tires": [6, 27, 77],
		"rims": [3, 5, 26],
		"glass": [7, 10, 12, 14, 20, 21, 23, 24, 25, 32, 34, 37, 39, 40, 42, 46, 52, 53, 61, 67],
		"headlights": [18, 36, 43, 45, 59, 62, 63, 66, 68, 69, 73, 74, 75],
		"taillights": [57],
		"grille": [48],
		"black_trim": [19, 58],
		"plate": [35],
		"antenna": [60],
		"extract": [{"part": 0, "new_part": 77, "center": [-0.196, 0.084, 0.313], "radius": 0.088, "half_width": 0.032}],  # ön-sol lastik kabuğa kaynamış (jant kapağı 2 ayrı)
		"wheel_groups": {"fl": [77, 2], "fr": [27, 5], "rl": [6, 3], "rr": [8, 26]},
	},
	"res://assets/cars/renault_toros.tscn": {
		"default_paint": Color(0.914, 0.929, 0.937),  # dokunun baskın kaporta rengi (#E9EDEF); paint mask ile aynı olmalı
		"body": [0],                   # kaynak TEK mesh (tripo_part_0, --rename): cam/far/tampon ayrılamaz, dokudan gelir
		"wheels": [1, 2, 3, 4],        # pipeline extract ile silindir bölgesinden ayrılan tekerler (lastik+jant tek mesh)
		"extract": [
			{"part": 0, "new_part": 1, "center": [-0.206, 0.110, 0.308], "radius": 0.100, "half_width": 0.04},
			{"part": 0, "new_part": 2, "center": [0.206, 0.110, 0.308], "radius": 0.100, "half_width": 0.04},
			{"part": 0, "new_part": 3, "center": [-0.208, 0.111, -0.272], "radius": 0.100, "half_width": 0.04},
			{"part": 0, "new_part": 4, "center": [0.208, 0.111, -0.272], "radius": 0.100, "half_width": 0.04},
		],
		"wheel_groups": {"fl": [1], "fr": [2], "rl": [3], "rr": [4]},
	},
}


static func has_map(scene_path: String) -> bool:
	return MAPS.has(scene_path)


static func get_map(scene_path: String) -> Dictionary:
	return MAPS.get(scene_path, {})


static func part_name(index: int) -> StringName:
	return StringName("tripo_part_%d" % index)
