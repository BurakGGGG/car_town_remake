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
## wheel_groups: fl/fr/rl/rr — dönüş/direksiyon grupları (ilk eleman lastik).
## wheel_axes: fl/fr/rl/rr → [y, z, yarıçap] — lastiğin geometrisinden ÖLÇÜLMÜŞ dönme ekseni
##   (tools/wheel_fit.gd üretir, tools/wheel_blur.gd ile görsel doğrulanır). Varsa CarRig grubu elemeden
##   kullanır; yoksa eski davranış (kutu merkezi + boyut / eksen elemesi).
## split_z: tek mesh'te iki rol (Fluence ön cam + tavan): z > z eşiği → front rolü, gerisi → back.
## fill_arc: lastiğin modellenmemiş yayı ({part, center, from, to} derece; 0 = yukarı, 90 = ön): karşı yay
##   180° döndürülüp eklenir (tools/optimize_car.gd)
## paint_whole: boya maskesinde texel anahtarı atlanıp TAMAMI boyanan gövde parçaları (dokuda parlama fırınlanmış,
##   rengi boyadan sapan tavan gibi; tools/make_paint_mask.gd).
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
	# 2026-10-11: kaynak GLB yenilendi, parça numaraları değişti → otomatik sınıflandırıcıdan yeniden çıkarıldı
	"res://assets/cars/bmw_e_46.tscn": {
		"default_paint": Color(0.804, 0.827, 0.855),  # boya maskesi aracının ölçtüğü fabrika rengi (#CDD3DA); cars.json default_color ile aynı olmalı
		"body": [0, 3, 4, 6, 12, 15, 17, 19, 20, 21, 25, 28, 29, 31, 32, 34, 35, 36, 38, 39, 43, 44, 49, 51, 55, 56, 59],
		"mirrors": [16, 18, 33],
		"wheels": [1, 2, 5, 7, 13],
		"tires": [22, 23],
		"rims": [14, 50, 57],
		"glass": [10, 11, 24, 26, 27, 37, 40, 46, 47],
		"headlights": [45, 52],
		"taillights": [41, 42, 58],
		"grille": [9],
		"black_trim": [8, 30, 48, 53, 54],
		"wheel_groups": {"fl": [2], "fr": [1], "rl": [22, 5, 14, 57], "rr": [23, 7, 13, 50]},
		"wheel_axes": {"fl": [0.0796, 0.3355, 0.0777], "fr": [0.0789, 0.3357, 0.0775], "rl": [0.0768, -0.2813, 0.0768], "rr": [0.0773, -0.2815, 0.0765]},
	},
	"res://assets/cars/hyundai_era.tscn": {
		"default_paint": Color(0.918, 0.910, 0.918),  # dokunun baskın kaporta rengi (#EAE8EA); paint mask ile aynı olmalı
		"body": [0, 1, 2, 7, 14, 15, 16, 17, 20, 21, 22, 26, 27, 31, 40, 53, 60, 62, 64, 65, 66, 70, 72, 73, 74],
		"mirrors": [34, 35],
		"wheels": [9],
		"tires": [8, 12, 13],
		"rims": [3, 4, 5, 11, 39, 41, 51, 55, 56],
		"glass": [6, 23, 24, 32, 52, 54],
		"headlights": [43, 47, 48, 68, 69, 71],
		"taillights": [38, 57, 59, 63],
		"grille": [25, 29, 33, 37, 42, 67],
		"black_trim": [10, 18, 19, 30, 36, 44, 45, 46, 49, 50, 58],
		"plate": [28],
		"antenna": [61],
		"wheel_groups": {"fl": [13, 4, 55], "fr": [9, 3, 39, 51, 56], "rl": [8, 5, 41], "rr": [12, 11]},
		"wheel_axes": {"fl": [0.0849, 0.3079, 0.0839], "fr": [0.0845, 0.3116, 0.0871], "rl": [0.0853, -0.3059, 0.0843], "rr": [0.0849, -0.3054, 0.0909]},
	},
	# 2026-10-11: kaynak GLB yenilendi, parça numaraları değişti → otomatik sınıflandırıcıdan yeniden çıkarıldı
	"res://assets/cars/hyundai_getz.tscn": {
		"default_paint": Color(0.898, 0.004, 0.027),  # boya maskesi aracının ölçtüğü fabrika rengi (#E50107); cars.json default_color ile aynı olmalı
		"body": [0, 1, 5, 8, 9, 10, 12, 14, 15, 19, 20, 21, 22, 23, 24, 25, 26, 28, 35, 41, 42, 43, 50, 51, 53, 56, 62, 65, 66, 68, 69, 70, 71, 72, 75],
		"mirrors": [11, 18, 32, 45],
		"wheels": [2, 3, 4, 6],
		"rims": [27, 29, 34, 40, 63],
		"glass": [7, 16, 17, 30, 36, 37, 44, 49, 55, 58, 59, 67, 74],
		"headlights": [38],
		"taillights": [31, 46, 47],
		"grille": [33, 39, 57, 60, 61],
		"black_trim": [13, 48, 52, 54, 64, 73],
		"wheel_groups": {"fl": [6], "fr": [4, 27, 34], "rl": [2], "rr": [3, 29, 40, 63]},
		"wheel_axes": {"fl": [0.0875, 0.2985, 0.0843], "fr": [0.0871, 0.2990, 0.0848], "rl": [0.0861, -0.3375, 0.0853], "rr": [0.0858, -0.3376, 0.0859]},
		"paint_whole": [12, 19],  # 19 tavan (dokuda açık pembe parlama, texel anahtarı %3 tutuyordu), 12 arka spoyler
	},
	# 2026-10-11: kaynak GLB yenilendi, parça numaraları değişti → otomatik sınıflandırıcıdan yeniden çıkarıldı
	"res://assets/cars/renault_fluence.tscn": {
		"default_paint": Color(0.792, 0.824, 0.863),  # boya maskesi aracının ölçtüğü fabrika rengi (#CAD2DC); cars.json default_color ile aynı olmalı
		"body": [0, 2, 4, 9, 11, 12, 13, 14, 17, 18, 19, 23, 25, 27, 30, 40, 46, 47, 49, 51, 52, 54, 56, 57, 58, 69],
		"mirrors": [37, 45],
		"wheels": [1, 3, 6, 21],
		"tires": [5],
		"rims": [10, 16, 24, 26, 29, 34, 59, 60],
		"glass": [7, 8, 31, 32, 36, 39, 42, 55, 67],
		"headlights": [38, 61, 63, 64, 65],
		"taillights": [41, 43, 62, 66],
		"grille": [15, 20, 28, 33, 44, 48, 50, 53],
		"black_trim": [22, 35, 68],
		"wheel_groups": {"fl": [3, 10], "fr": [1], "rl": [5, 16, 21, 26, 59], "rr": [6, 24, 29, 34, 60]},
		"wheel_axes": {"fl": [0.0775, 0.2989, 0.0755], "fr": [0.0773, 0.2992, 0.0757], "rl": [0.0779, -0.2982, 0.0771], "rr": [0.0787, -0.2982, 0.0763]},
	},
	# 2026-10-11: kaynak GLB yenilendi, parça numaraları değişti → otomatik sınıflandırıcıdan yeniden çıkarıldı
	"res://assets/cars/volswagen_passat_b_5_5.tscn": {
		"default_paint": Color(0.792, 0.816, 0.843),  # boya maskesi aracının ölçtüğü fabrika rengi (#CAD0D7); cars.json default_color ile aynı olmalı
		"body": [0, 1, 7, 8, 9, 10, 13, 15, 16, 20, 22, 29, 30, 31, 34, 35, 36, 37, 38, 39, 40, 42, 44, 45, 46, 48, 54, 56, 57, 59, 63],
		"mirrors": [25],
		"wheels": [2, 3, 4, 5],
		"glass": [6, 11, 19, 23, 27, 32],
		"headlights": [47, 50, 53, 62],
		"taillights": [51, 55],
		"grille": [12, 21, 24, 28, 33, 43, 52, 58, 60, 61],
		"black_trim": [14, 17, 18, 26, 41, 49],
		"wheel_groups": {"fl": [5], "fr": [2], "rl": [3], "rr": [4]},
		"wheel_axes": {"fl": [0.0802, 0.3012, 0.0748], "fr": [0.0759, 0.3011, 0.0729], "rl": [0.0789, -0.2694, 0.0743], "rr": [0.0778, -0.2699, 0.0746]},
	},
	"res://assets/cars/tofas_sahin.tscn": {
		"default_paint": Color(0.918, 0.910, 0.918),  # dokunun baskın kaporta rengi (#EAE8EA); paint mask ile aynı olmalı
		"body": [0, 1, 4, 9, 11, 13, 15, 16, 17, 22, 28, 29, 30, 31, 33, 38, 41, 44, 47, 51, 56, 70, 72],
		"wheels": [2, 8],
		"tires": [6, 27, 77],
		"rims": [3, 5, 26, 49, 50, 54, 55, 64, 65, 71, 76],
		"glass": [7, 10, 12, 14, 20, 21, 23, 24, 25, 32, 34, 37, 39, 40, 42, 46, 52, 53, 61, 67],
		"headlights": [43, 45, 59, 62, 63, 66, 68, 69, 73, 74, 75],
		"taillights": [57],
		"grille": [18, 36, 48],  # 18/36: lamba olamayacak kadar büyük parçalar (CarRig eliyordu, uyarı basıyordu) — 2026-10-11
		"black_trim": [19, 58],
		"plate": [35],
		"antenna": [60],
		# Silindir merkezi aks merkezinin BİRAZ ALTINDA: alt ucu zemine değsin (lastiğin taban
		# dilimi gövdede kalmasın, dönmeyen bir hilal bırakırdı) ama ÜST ucu çamurluğun altında
		# kalsın (kesilirse kemerde siyah kamalar oluşuyor — ölçüldü ve geri alındı).
		"extract": [{"part": 0, "new_part": 77, "center": [-0.196, 0.084, 0.313], "radius": 0.088, "half_width": 0.032}],  # ön-sol lastik kabuğa kaynamış (jant kapağı 2 ayrı)
		"wheel_groups": {"fl": [77, 2, 50, 76], "fr": [27, 5, 49, 71], "rl": [6, 3, 55, 64], "rr": [8, 26, 54, 65]},
		"wheel_axes": {"fl": [0.0842, 0.3126, 0.0869], "fr": [0.0837, 0.3126, 0.0828], "rl": [0.0828, -0.2763, 0.0827], "rr": [0.0835, -0.2762, 0.0814]},
	},
	# renault_toros 2026-09-27'de çıkarılmıştı (tek mesh kaynakta tekerler silindirle kesiliyor,
	# kemerde iz kalıyordu). 2026-09-28'de GERİ ALINDI: tekerler artık kesilmiyor, Blender'da
	# kaynaktaki bozuk teker geometrisi silinip yerine temiz teker konuldu ve AYRI NESNE olarak
	# dışa aktarıldı (tools/decor/toros_tekerlek.py) → extract adımına gerek yok.
	# Eski extract'in neden tutmadığı ölçüldü: haritadaki aks üç eksende de yanlıştı —
	# x ±0,206 (gerçek ±0,188), y 0,103 (gerçek 0,0735), yarıçap 0,107 (gerçek 0,0735).
	# Silindir %45 iri ve 29 mm yüksek olduğu için lastiği ıskalayıp çamurluğu kesiyordu.
	# Kaynak: assets/cars/source/renault_toros_wheels.glb (renault_r12.glb'ye DOKUNULMADI).
	"res://assets/cars/renault_toros.tscn": {
		"default_paint": Color(0.914, 0.929, 0.937),  # boya maskesi aracının ölçtüğü fabrika rengi (#E9EDEF)
		"body": [0],                   # kaynak gövdesi TEK mesh: cam/far/tampon ayrılamaz, dokudan gelir
		"wheels": [1, 2, 3, 4],        # Blender'da üretilen temiz tekerler (lastik+jant+göbek tek mesh)
		"wheel_groups": {"fl": [1], "fr": [2], "rl": [3], "rr": [4]},
		"wheel_axes": {"fl": [0.0735, 0.3125, 0.0735], "fr": [0.0735, 0.3125, 0.0735], "rl": [0.0735, -0.2685, 0.0735], "rr": [0.0735, -0.2685, 0.0735]},
	},
	# --- 2026-09-27 ikinci parti (9 araç): roller OTOMATİK sınıflandırıcıyla çıkarıldı
	# (geometri: köşe/yükseklik/yuvarlaklık + doku rengi: aracın kendi parlaklık dağılımına göre
	# eşikler). Sınıflandırıcı mevcut 7 aracın elle doğrulanmış haritalarıyla ölçüldü: işlevsel
	# grup isabeti %75, teker %100, stop %100, far %95, ayna %100. Kalan hata gövde↔trim
	# ayrımındadır ve boya maskesi aracı bunu texel bazında zaten düzeltir.
	"res://assets/cars/audi_a3.tscn": {
		"default_paint": Color(0.871, 0.882, 0.898),  # boya maskesi aracının ölçtüğü fabrika rengi (#DEE1E5)
		"body": [2, 6, 8, 9, 10, 13, 17, 23, 25, 29, 32, 37, 38, 43, 48, 49, 51, 54, 56, 58, 59, 60, 65, 68, 78],
		"mirrors": [20, 22, 44, 61, 69],
		"wheels": [1, 3, 4, 5],
		"rims": [11, 12, 28, 34],
		"glass": [14, 18, 21, 26, 31, 39, 41, 47, 50, 63, 66, 71, 73, 76],
		"headlights": [42, 55, 64, 70, 75],
		"taillights": [24, 53, 57, 67, 74, 79],
		"grille": [15, 16, 19, 27, 35],  # 16/19: lamba olamayacak kadar büyük parçalar (CarRig eliyordu, uyarı basıyordu) — 2026-10-11
		"black_trim": [0, 7, 30, 33, 36, 40, 45, 46, 52, 62, 72, 77],
		"wheel_groups": {"fl": [5], "fr": [1], "rl": [3, 11], "rr": [4, 28]},
		"wheel_axes": {"fl": [0.0860, 0.2991, 0.0877], "fr": [0.0855, 0.2992, 0.0878], "rl": [0.0855, -0.3183, 0.0875], "rr": [0.0848, -0.3183, 0.0875]},
	},
	"res://assets/cars/bmw_e60.tscn": {
		"default_paint": Color(0.129, 0.133, 0.145),  # boya maskesi aracının ölçtüğü fabrika rengi (#212225)
		"body": [0, 1, 7, 8, 11, 15, 21, 22, 23, 24, 25, 29, 31, 33, 34, 35, 36, 38, 40, 41, 44, 47, 49, 51, 52],
		"mirrors": [19, 28],
		"wheels": [2, 3, 5, 10, 12, 53],
		"tires": [9],
		"rims": [13, 14, 16, 17, 20, 30],
		"glass": [6],
		"headlights": [32],
		"taillights": [37, 39],
		"grille": [18, 26, 27, 42, 46, 50],
		"black_trim": [4, 43, 45, 48],
		"extract": [{"part": 4, "new_part": 53, "center": [0.1815, 0.0741, 0.3149], "radius": 0.0792, "half_width": 0.0394}],
		"wheel_groups": {"fl": [53, 13, 17, 20], "fr": [5, 9], "rl": [3, 12, 30], "rr": [2, 10, 14, 16]},
		"wheel_axes": {"fl": [0.0741, 0.3149, 0.0754], "fr": [0.0755, 0.3149, 0.0754], "rl": [0.0765, -0.2843, 0.0763], "rr": [0.0751, -0.2844, 0.0763]},
	},
	"res://assets/cars/ford_focus.tscn": {
		"default_paint": Color(0.886, 0.910, 0.933),  # boya maskesi aracının ölçtüğü fabrika rengi (#E2E8EE)
		"body": [0, 4, 8, 9, 10, 11, 12, 15, 16, 17, 19, 20, 30, 32, 39, 43, 48, 51, 54, 55],
		"mirrors": [34, 36, 38],
		"wheels": [1, 2, 3, 6],
		"rims": [13, 14],
		"glass": [5, 18, 22, 24, 25, 26, 29, 33, 37, 40, 42, 46, 47, 50, 52, 53, 56],
		"headlights": [23, 35, 44, 45],
		"taillights": [31],
		"grille": [7, 27, 28, 41, 49],
		"black_trim": [21],
		"wheel_groups": {"fl": [6, 13], "fr": [2], "rl": [1, 14], "rr": [3]},
		"wheel_axes": {"fl": [0.0853, 0.3000, 0.0806], "fr": [0.0852, 0.2999, 0.0815], "rl": [0.0853, -0.2971, 0.0802], "rr": [0.0859, -0.2979, 0.0806]},
	},
	"res://assets/cars/honda_civic.tscn": {
		"default_paint": Color(0.820, 0.824, 0.831),  # boya maskesi aracının ölçtüğü fabrika rengi (#D1D2D4)
		"body": [0, 3, 4, 9, 17, 18, 26, 40],
		"mirrors": [21, 22],
		"wheels": [1, 2, 6, 8],
		"tires": [12, 14],
		"rims": [15, 16, 20, 32, 34, 38],
		"glass": [5, 10, 13, 19, 23, 24, 25, 36, 41],
		"headlights": [27, 28, 29, 30, 31, 35, 39],
		"grille": [7],
		"black_trim": [33, 37, 42, 43],
		"wheel_groups": {"fl": [1, 20], "fr": [2, 15], "rl": [14, 8, 16, 34], "rr": [12, 6, 32]},
		"wheel_axes": {"fl": [0.0804, 0.3164, 0.0805], "fr": [0.0803, 0.3161, 0.0807], "rl": [0.0784, -0.2808, 0.0817], "rr": [0.0779, -0.2809, 0.0813]},
	},
	"res://assets/cars/hyundai_accent_blue.tscn": {
		"default_paint": Color(0.922, 0.929, 0.925),  # boya maskesi aracının ölçtüğü fabrika rengi (#EBEDEC)
		"body": [0, 10, 13, 14, 15, 17, 20, 22, 23, 24, 25, 26, 27, 32, 37, 39, 46, 52],
		"mirrors": [28, 30, 33, 34],
		"wheels": [3, 4, 6, 7, 8, 11],
		"tires": [9],
		"rims": [16, 35, 42, 44, 45, 47, 50],
		"glass": [2, 18, 19, 21, 29, 38, 40, 48, 49, 51],
		"headlights": [41, 43],
		"taillights": [31, 36],
		"grille": [5, 12],
		"black_trim": [1],
		"wheel_groups": {"fl": [9, 6, 35], "fr": [3], "rl": [4, 11, 42, 44, 45], "rr": [8, 7, 16, 47, 50]},
		"wheel_axes": {"fl": [0.0873, 0.2948, 0.0909], "fr": [0.0884, 0.2952, 0.0905], "rl": [0.0894, -0.3026, 0.0909], "rr": [0.0895, -0.3023, 0.0905]},
	},
	"res://assets/cars/seat_leon.tscn": {
		"default_paint": Color(0.890, 0.902, 0.922),  # boya maskesi aracının ölçtüğü fabrika rengi (#E3E6EB)
		"body": [0, 6, 9, 10, 13, 14, 15, 19, 21, 27, 30, 43, 45],
		"mirrors": [23, 24, 31, 35],
		"wheels": [2, 3, 4, 5],
		"rims": [12, 16, 18],
		"glass": [8, 11, 20, 22, 25, 26, 28, 29, 33, 34, 37, 39, 40, 44],
		"headlights": [42],
		"taillights": [32, 36, 38, 41],
		"grille": [17],
		"black_trim": [1, 7],
		"wheel_groups": {"fl": [3, 12], "fr": [5, 18], "rl": [2], "rr": [4, 16]},
		"wheel_axes": {"fl": [0.0899, 0.2922, 0.0859], "fr": [0.0893, 0.2915, 0.0863], "rl": [0.0892, -0.3141, 0.0846], "rr": [0.0877, -0.3137, 0.0845]},
	},
	"res://assets/cars/skoda_kamiq.tscn": {
		"default_paint": Color(0.918, 0.925, 0.925),  # boya maskesi aracının ölçtüğü fabrika rengi (#EAECEC)
		"body": [0, 4, 9, 10, 12, 16, 17, 19, 22, 30, 31, 34, 38, 41, 42, 44, 46, 47, 49, 51],
		"mirrors": [23, 24, 26],
		"wheels": [6, 7, 8, 13],
		"tires": [2, 3, 14, 15],
		"rims": [18, 39],
		"glass": [5, 11, 20, 21, 25, 28, 29, 33, 35, 36, 37, 40, 50],
		"headlights": [45, 48, 53],
		"taillights": [27, 32],
		"grille": [43, 52],
		"black_trim": [1],
		"wheel_groups": {"fl": [15, 8], "fr": [14, 7, 18, 39], "rl": [3, 13], "rr": [2, 6]},
		"wheel_axes": {"fl": [0.0911, 0.3010, 0.0890], "fr": [0.0912, 0.3011, 0.0888], "rl": [0.0911, -0.2992, 0.0879], "rr": [0.0911, -0.2994, 0.0888]},
	},
	"res://assets/cars/volvo_s60.tscn": {
		"default_paint": Color(0.863, 0.878, 0.902),  # boya maskesi aracının ölçtüğü fabrika rengi (#DCE0E6)
		"body": [0, 5, 7, 8, 9, 15, 18, 20, 23, 25, 26, 28, 30, 37, 40, 42],
		"mirrors": [12, 17],
		"wheels": [2, 4],
		"tires": [3, 44],
		"glass": [6, 21, 22, 32, 36, 39],
		"headlights": [16, 27, 29, 38, 41, 43],
		"taillights": [14, 31],
		"grille": [10, 11, 19, 24, 35],  # 11/24: lamba olamayacak kadar büyük parçalar (CarRig eliyordu, uyarı basıyordu) — 2026-10-11
		"black_trim": [1, 13, 33, 34],
		"rims": [45, 46, 47, 48],
		"extract": [{"part": 1, "new_part": 44, "center": [-0.1828, 0.0873, -0.3048], "radius": 0.0849, "half_width": 0.0413},
			{"part": 4, "new_part": 45, "center": [0.183, 0.0835, 0.2987], "radius": 0.0703, "half_width": 0.0464, "hue": 0.979, "hue_tol": 0.05, "min_sat": 0.45},
			{"part": 2, "new_part": 46, "center": [-0.1823, 0.0853, 0.2985], "radius": 0.07, "half_width": 0.0458, "hue": 0.979, "hue_tol": 0.05, "min_sat": 0.45},
			{"part": 3, "new_part": 47, "center": [0.1831, 0.0872, -0.3044], "radius": 0.0695, "half_width": 0.0463, "hue": 0.979, "hue_tol": 0.05, "min_sat": 0.45},
			{"part": 44, "new_part": 48, "center": [-0.1828, 0.0873, -0.3048], "radius": 0.0688, "half_width": 0.0447, "hue": 0.979, "hue_tol": 0.05, "min_sat": 0.45}],
		"wheel_groups": {"fl": [4], "fr": [2], "rl": [3], "rr": [44]},
		"wheel_axes": {"fl": [0.0835, 0.2987, 0.0827], "fr": [0.0853, 0.2985, 0.0824], "rl": [0.0872, -0.3044, 0.0818], "rr": [0.0873, -0.3048, 0.0809]},
	},
	"res://assets/cars/vw_golf_7.tscn": {
		"default_paint": Color(0.784, 0.024, 0.102),  # boya maskesi aracının ölçtüğü fabrika rengi (#C8061A)
		"body": [1, 6, 7, 8, 15, 17, 19, 25, 26, 32, 40],
		"mirrors": [13, 16],
		"wheels": [2, 4, 5, 10, 20, 21],
		"rims": [14, 38, 46],
		"glass": [9, 12, 23, 24, 29, 31, 33, 34, 35],
		"headlights": [39, 43, 44, 45],
		"taillights": [18, 22, 27, 36, 37, 41, 42],
		"grille": [11, 28, 30],
		"black_trim": [0, 3],
		"extract": [{"part": 2, "new_part": 46, "center": [-0.1899, 0.0937, 0.296], "radius": 0.0785, "half_width": 0.0426, "hue": 0.104, "hue_tol": 0.06, "min_sat": 0.45}],
		"wheel_groups": {"fl": [4], "fr": [2], "rl": [5], "rr": [10, 38]},
		"wheel_axes": {"fl": [0.0939, 0.2957, 0.0928], "fr": [0.0937, 0.2960, 0.0924], "rl": [0.0941, -0.3192, 0.0941], "rr": [0.0948, -0.3199, 0.0947]},
	},
	# --- 2026-10-04 üçüncü parti (6 araç): roller tools/classify_roles.py ile (ikinci partiyle aynı
	# sınıflandırıcı; özellikler tools/part_features.gd). Boya rengi make_paint_mask.gd ölçümüyle eşitlenir.
	"res://assets/cars/alfa_romeo_159.tscn": {
		"default_paint": Color(0.847, 0.835, 0.843),  # boya maskesi aracının ölçtüğü fabrika rengi (#D8D5D7)
		"body": [0, 1, 8, 9, 10, 14, 24, 28, 29, 30, 32, 34, 35, 38, 41, 42],
		"mirrors": [11, 12],
		"wheels": [2, 4],
		"tires": [5, 46],
		"rims": [13, 16, 17, 20, 21, 39],
		"glass": [23, 25, 26, 44],
		"headlights": [27],
		"grille": [7, 15, 18, 19, 22, 37, 43, 45],
		"black_trim": [3, 6, 31, 33, 36, 40],
		"extract": [{"part": 3, "new_part": 46, "center": [-0.1963, 0.085, 0.2916], "radius": 0.0823, "half_width": 0.0415}],
		"wheel_groups": {"fl": [2, 20], "fr": [46, 16], "rl": [4, 13], "rr": [5, 21]},
		"wheel_axes": {"fl": [0.0832, 0.2934, 0.0793], "fr": [0.0850, 0.2916, 0.0784], "rl": [0.0804, -0.2944, 0.0807], "rr": [0.0807, -0.2947, 0.0805]},
	},
	"res://assets/cars/audi_rs6.tscn": {
		"default_paint": Color(0.561, 0.584, 0.600),  # boya maskesi aracının ölçtüğü fabrika rengi (#8F9599)
		"body": [2, 4, 10, 12, 15, 18, 19, 20, 22, 23, 24, 25, 26, 33, 34, 35, 37, 38, 39, 41, 44, 45, 48, 50, 51, 52, 61, 63, 67, 68, 69, 73, 74, 79, 80, 81],
		"mirrors": [5, 31, 56, 64],
		"wheels": [14, 32],
		"tires": [1, 7, 8, 9, 11, 13, 16, 17],
		"rims": [29, 30, 36, 40, 47, 58, 77, 78],
		"glass": [6, 28, 43, 49, 53, 57],
		"taillights": [42, 60],
		"grille": [3, 27, 62, 65, 70, 71, 72, 76],
		"black_trim": [0, 21, 46, 54, 55, 59, 66, 75],
		"wheel_groups": {"fl": [11, 16, 40, 58], "fr": [13, 9], "rl": [1, 8], "rr": [7, 17]},
		"wheel_axes": {"fl": [0.0814, 0.3129, 0.0816], "fr": [0.0824, 0.3127, 0.0814], "rl": [0.0803, -0.2828, 0.0806], "rr": [0.0817, -0.2829, 0.0804]},
	},
	"res://assets/cars/ferrari_488_pista.tscn": {
		"default_paint": Color(0.765, 0.000, 0.012),  # boya maskesi aracının ölçtüğü fabrika rengi (#C30003)
		"body": [1, 3, 4, 5, 6, 7, 8, 11, 12, 15, 17, 18, 19, 20, 21, 22, 23, 25, 26, 28, 29, 30, 31, 37, 38, 39, 40, 42, 46, 47, 55, 56, 57],
		"mirrors": [16, 27],
		"wheels": [0, 59, 60, 61],
		"rims": [9, 24, 62, 63, 64, 65, 66, 67],
		"taillights": [50, 51, 52, 54, 58],
		"grille": [14, 32, 44, 48, 53],
		"black_trim": [2, 10, 13, 33, 34, 35, 36, 41, 43, 45, 49],
		# Elle düzeltildi (vurgu render'ı): 41/45 ön hava girişi (teker değil); 18 armalı sol ön çamurluk,
		# 23 arka kanat, 25 arka tampon, 30 kanat altı panel GÖVDE (stop / trim sanılıp boyanmıyordu);
		# 9 arka-sol jant (gövde sanılmıştı); arka-sağ teker difüzörle (1) kaynamış → extract;
		# 3 / 7 lastik ayrıldıktan sonra kalan çamurluk kenarı (gövde). Lastikteki turuncu-kırmızı fren diski
		# bilerek lastikte kalır (dönmeli, boyanmamalı).
		"extract": [{"part": 1, "new_part": 59, "center": [-0.1904, 0.0866, -0.3275], "radius": 0.0895, "half_width": 0.046},
			{"part": 3, "new_part": 60, "center": [-0.1873, 0.0856, 0.244], "radius": 0.0874, "half_width": 0.0463},
			{"part": 7, "new_part": 61, "center": [0.1873, 0.0866, -0.3275], "radius": 0.089, "half_width": 0.0499},
			{"part": 0, "new_part": 62, "center": [0.1889, 0.0867, 0.2436], "radius": 0.0708, "half_width": 0.0504, "hue": 0.104, "hue_tol": 0.06, "min_sat": 0.45},
			{"part": 60, "new_part": 63, "center": [-0.1873, 0.0856, 0.244], "radius": 0.0707, "half_width": 0.0502, "hue": 0.104, "hue_tol": 0.06, "min_sat": 0.45},
			{"part": 61, "new_part": 64, "center": [0.1873, 0.0866, -0.3275], "radius": 0.0721, "half_width": 0.0541, "hue": 0.104, "hue_tol": 0.06, "min_sat": 0.45},
			{"part": 9, "new_part": 65, "center": [0.1873, 0.0866, -0.3275], "radius": 0.0721, "half_width": 0.0541, "hue": 0.104, "hue_tol": 0.06, "min_sat": 0.45},
			{"part": 59, "new_part": 66, "center": [-0.1904, 0.0866, -0.3275], "radius": 0.0721, "half_width": 0.0473, "hue": 0.104, "hue_tol": 0.06, "min_sat": 0.45},
			{"part": 24, "new_part": 67, "center": [-0.1904, 0.0866, -0.3275], "radius": 0.0721, "half_width": 0.0473, "hue": 0.104, "hue_tol": 0.06, "min_sat": 0.45}],
		"wheel_groups": {"fl": [0], "fr": [60], "rl": [61, 9], "rr": [59, 24]},
		"wheel_axes": {"fl": [0.0867, 0.2436, 0.0833], "fr": [0.0856, 0.2440, 0.0832], "rl": [0.0866, -0.3275, 0.0848], "rr": [0.0866, -0.3275, 0.0848]},
	},
	"res://assets/cars/lambo_huracan.tscn": {
		"default_paint": Color(0.859, 0.847, 0.859),  # boya maskesi aracının ölçtüğü fabrika rengi (#DBD8DB)
		"body": [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 19, 21, 23, 24, 25, 26, 27, 28, 29, 30, 32, 33, 34, 35, 36, 38, 39, 42, 43, 45, 47, 50, 52, 53, 54, 58, 59, 62, 63, 66, 67],
		"wheels": [1, 4, 5, 68],
		"glass": [41],
		"headlights": [40, 44, 56],
		"taillights": [64],
		"grille": [22, 60],
		"black_trim": [0, 2, 3, 17, 18, 20, 31, 37, 46, 48, 49, 51, 55, 57, 61, 65],
		# Elle düzeltildi (vurgu render'ı): 39/58 ön tampon (gövde), 46/51/61 ön hava girişi — jant değil.
		"rims": [69, 70, 71, 72],
		"extract": [{"part": 2, "new_part": 68, "center": [-0.1863, 0.0828, -0.3174], "radius": 0.0812, "half_width": 0.051},
			{"part": 5, "new_part": 69, "center": [0.186, 0.0822, 0.2642], "radius": 0.0667, "half_width": 0.0549, "hue": 0.62, "hue_tol": 0.07, "min_sat": 0.45},
			{"part": 4, "new_part": 70, "center": [-0.185, 0.0827, 0.2649], "radius": 0.0661, "half_width": 0.0545, "hue": 0.62, "hue_tol": 0.07, "min_sat": 0.45},
			{"part": 1, "new_part": 71, "center": [0.1866, 0.0821, -0.318], "radius": 0.0671, "half_width": 0.0562, "hue": 0.62, "hue_tol": 0.07, "min_sat": 0.45},
			{"part": 68, "new_part": 72, "center": [-0.1863, 0.0828, -0.3174], "radius": 0.0657, "half_width": 0.0553, "hue": 0.62, "hue_tol": 0.07, "min_sat": 0.45}],
		"wheel_groups": {"fl": [5], "fr": [4], "rl": [1], "rr": [68]},
		"wheel_axes": {"fl": [0.0822, 0.2642, 0.0785], "fr": [0.0827, 0.2649, 0.0778], "rl": [0.0821, -0.3180, 0.0789], "rr": [0.0828, -0.3174, 0.0773]},
	},
	"res://assets/cars/mercedes_cls.tscn": {
		"default_paint": Color(0.718, 0.710, 0.718),  # boya maskesi aracının ölçtüğü fabrika rengi (#B7B5B7)
		# Elle düzeltildi (vurgu render'ı): 8 kapı paneli (ayna sanılmıştı), 52 ön çamurluk (jant sanılmıştı).
		"body": [1, 5, 7, 8, 10, 11, 16, 19, 20, 21, 22, 24, 25, 28, 31, 32, 33, 35, 40, 42, 46, 47, 48, 50, 52, 53, 54, 55, 56, 58, 59, 65],
		"tires": [2, 3, 4, 9],
		"rims": [12, 13, 14, 26],
		"glass": [6, 23, 37, 39],
		"headlights": [30],
		"taillights": [18, 29],
		"grille": [15, 17, 27, 34, 36, 38, 44, 45, 51, 57, 60, 61, 62],
		"black_trim": [0, 41, 43, 49, 63, 64],
		"wheel_groups": {"fl": [2, 12], "fr": [9, 26], "rl": [3, 14], "rr": [4, 13]},
		"wheel_axes": {"fl": [0.0761, 0.3107, 0.0746], "fr": [0.0774, 0.3106, 0.0747], "rl": [0.0776, -0.2756, 0.0751], "rr": [0.0764, -0.2760, 0.0755]},
	},
	"res://assets/cars/porsche_gt3.tscn": {
		"default_paint": Color(0.184, 0.298, 0.161),  # boya maskesi aracının ölçtüğü fabrika rengi (#2F4C29)
		"body": [1, 5, 9, 10, 12, 13, 16, 18, 20, 22, 23, 24, 25, 27, 28, 32, 34, 35, 36, 40, 47, 50, 51, 52, 53, 55, 56, 57, 58, 61],
		"mirrors": [38, 42, 44, 45, 46],
		"wheels": [2, 3, 4, 6, 62],
		"tires": [7, 8, 15],
		"rims": [17, 26, 30, 33, 41, 49, 59],
		"glass": [29, 31, 39, 43, 48],
		"taillights": [37],
		"grille": [14, 21],
		"black_trim": [0, 19, 54, 60],
		"extract": [{"part": 11, "new_part": 62, "center": [-0.1803, 0.0826, 0.2873], "radius": 0.0915, "half_width": 0.0498}],
		# Sağ-ön lastiğin üstü (~80°, çamurluğun içi) kaynakta hiç yok: karşı yay döndürülüp eklenir
		"fill_arc": [{"part": 62, "center": [-0.1803, 0.0826, 0.2873], "from": 318, "to": 42}],
		"wheel_groups": {"fl": [15, 6], "fr": [62, 4, 33, 49], "rl": [7, 3], "rr": [8, 2, 41]},
		"wheel_axes": {"fl": [0.0826, 0.2873, 0.0861], "fr": [0.0826, 0.2873, 0.0861], "rl": [0.0844, -0.2712, 0.0863], "rr": [0.0844, -0.2714, 0.0863]},
	},
	# --- 2026-10-11 dördüncü parti (4 araç): Camaro, S400, Corsa, Model Y — roller otomatik sınıflandırıcıdan,
	# --- teker grupları/eksenleri tools/wheel_fit.gd ile ölçüldü.
	"res://assets/cars/chevrolet_camaro.tscn": {
		"default_paint": Color(0.969, 0.820, 0.133),  # boya maskesi aracının ölçtüğü fabrika rengi (#F7D122); cars.json default_color ile aynı olmalı
		"body": [0, 3, 6, 8, 9, 10, 11, 12, 14, 16, 17, 19, 20, 22, 23, 25, 26, 27, 30, 41, 44, 45, 46, 47, 48, 49],
		"mirrors": [21],
		"wheels": [4],
		"tires": [1, 2, 5],
		"rims": [18],
		"glass": [7, 24, 28, 29, 36, 39],
		"taillights": [34, 35, 37],
		"grille": [13, 15, 33, 38, 40],
		"black_trim": [31, 32, 42, 43],
		"wheel_groups": {"fl": [2], "fr": [5], "rl": [4, 18], "rr": [1]},
		"wheel_axes": {"fl": [0.0805, 0.3140, 0.0797], "fr": [0.0806, 0.3144, 0.0796], "rl": [0.0808, -0.2831, 0.0801], "rr": [0.0806, -0.2832, 0.0796]},
	},
	"res://assets/cars/mercedes_s400.tscn": {
		"default_paint": Color(0.243, 0.259, 0.263),  # boya maskesi aracının ölçtüğü fabrika rengi (#3E4243); cars.json default_color ile aynı olmalı
		"body": [0, 1, 2, 3, 8, 9, 14, 19, 21, 22, 23, 24, 35, 36, 38, 40, 44, 45, 47, 48, 50, 62, 63],
		"mirrors": [16, 27],
		"wheels": [4, 12, 13, 20],
		"tires": [6, 7, 11],
		"rims": [15, 17, 29, 31, 34, 37, 39, 41, 42, 46, 51, 59, 60, 61, 64, 66, 67, 68, 69, 70, 71],
		"glass": [10, 26, 30, 32],
		"headlights": [65],
		"taillights": [54, 56],
		"grille": [25, 28, 33, 43, 49, 52, 55, 57, 58, 72],
		"black_trim": [5, 18, 53],
		"wheel_groups": {"fl": [4, 29, 46, 60, 70, 71], "fr": [6, 20, 37, 39, 41, 51, 67, 69], "rl": [7, 13, 31, 34, 61, 68], "rr": [11, 12, 15, 17, 42, 59, 64, 66]},
		"wheel_axes": {"fl": [0.0773, 0.3191, 0.0714], "fr": [0.0768, 0.3189, 0.0716], "rl": [0.0764, -0.2787, 0.0720], "rr": [0.0757, -0.2782, 0.0730]},
	},
	"res://assets/cars/opel_corsa.tscn": {
		"default_paint": Color(0.902, 0.894, 0.910),  # boya maskesi aracının ölçtüğü fabrika rengi (#E6E4E8); cars.json default_color ile aynı olmalı
		"body": [1, 7, 10, 15, 26, 27, 28, 33, 36, 37, 39, 42, 43],
		"mirrors": [8, 9, 31, 34],
		"wheels": [3, 4, 5, 6],
		"rims": [12, 13, 14, 18],
		"glass": [2, 11, 17, 22, 23, 24, 25, 35, 40],
		"headlights": [29, 30, 38, 41],
		"grille": [16, 19, 20, 21],
		"black_trim": [0, 32],
		"wheel_groups": {"fl": [6, 18], "fr": [3, 12], "rl": [5, 14], "rr": [4, 13]},
		"wheel_axes": {"fl": [0.0822, 0.3109, 0.0834], "fr": [0.0843, 0.3102, 0.0839], "rl": [0.0860, -0.3527, 0.0843], "rr": [0.0843, -0.3529, 0.0845]},
	},
	"res://assets/cars/tesla_model_y.tscn": {
		"default_paint": Color(0.875, 0.894, 0.914),  # boya maskesi aracının ölçtüğü fabrika rengi (#DFE4E9); cars.json default_color ile aynı olmalı
		"body": [0, 5, 6, 7, 11, 12, 14, 16, 24, 25, 27, 33, 37, 38, 39, 40, 41, 43, 49],
		"mirrors": [9, 13, 32, 34, 35],
		"tires": [2, 3, 4, 19, 20],
		"rims": [47],
		"glass": [8, 17, 18, 26, 29, 31, 46, 48, 50, 51],
		"headlights": [28, 30],
		"taillights": [42, 45],
		"grille": [15, 23],
		"black_trim": [1, 10, 21, 22, 36, 44],
		"wheel_groups": {"fl": [19], "fr": [2, 47], "rl": [20], "rr": [4, 3]},  # 21/22 ön çamurluk kaplaması (sınıflandırıcı "teker" sanmıştı)
		"wheel_axes": {"fl": [0.0874, 0.3094, 0.0834], "fr": [0.0877, 0.3089, 0.0841], "rl": [0.0879, -0.3068, 0.0841], "rr": [0.0875, -0.3077, 0.0868]},
	},
	# --- KLASİK / RESTORASYON araçları (2026-10-11, 24 araç): sınıflandırıcı + tools/wheel_fit.gd çıktısı ---
	"res://assets/cars/anadol_a1.tscn": {
		"default_paint": Color(0.380, 0.745, 0.039),  # boya maskesi aracının ölçtüğü fabrika rengi (#61BE0A); cars.json default_color ile aynı olmalı
		"body": [0, 3, 5, 6, 12, 13, 14, 15, 23, 39, 43, 45],
		"mirrors": [20, 21],
		"wheels": [1, 10],
		"tires": [4, 7, 11],
		"rims": [8, 9, 27, 31, 32, 33, 34, 35, 36, 37, 46],
		"glass": [2, 16, 17, 19, 22, 24, 26, 28],
		"headlights": [25, 29, 30],
		"taillights": [38, 41, 42, 44],
		"grille": [40],
		"black_trim": [18, 47],
		"wheel_groups": {"fl": [11, 9, 36, 37], "fr": [1, 27, 31, 46], "rl": [4, 8, 33, 35], "rr": [7, 10, 32, 34]},
		"wheel_axes": {"fl": [0.0897, 0.3179, 0.0888], "fr": [0.0893, 0.3177, 0.0884], "rl": [0.0874, -0.2699, 0.0867], "rr": [0.0873, -0.2702, 0.0869]},
	},
	"res://assets/cars/aston_martin_db5.tscn": {
		"default_paint": Color(0.773, 0.808, 0.847),  # boya maskesi aracının ölçtüğü fabrika rengi (#C5CED8); cars.json default_color ile aynı olmalı
		"body": [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 18, 19, 20, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 39, 43, 45, 46, 48, 51, 52],
		"wheels": [1, 2, 3, 17],
		"glass": [47],
		"headlights": [22, 36, 38, 40, 41, 42, 44, 53],
		"grille": [21, 49],
		"black_trim": [0, 4, 5, 23, 24, 37, 50, 54],
		"wheel_groups": {"fl": [3], "fr": [2], "rl": [17], "rr": [1]},
		"wheel_axes": {"fl": [0.0830, 0.3173, 0.0813], "fr": [0.0824, 0.3168, 0.0810], "rl": [0.0807, -0.2209, 0.0793], "rr": [0.0815, -0.2212, 0.0789]},
	},
	"res://assets/cars/bmw_m3_e30.tscn": {
		"default_paint": Color(0.949, 0.004, 0.039),  # boya maskesi aracının ölçtüğü fabrika rengi (#F2010A); cars.json default_color ile aynı olmalı
		"body": [0, 3, 7, 8, 9, 10, 16, 21, 32, 33, 34, 35, 37, 38, 39, 41, 46],
		"mirrors": [25, 26],
		"wheels": [1, 2, 4, 5, 6, 19],
		"rims": [27, 30],
		"glass": [15, 22],
		"taillights": [12, 13, 14, 20, 29, 43, 45],
		"grille": [23, 24, 28, 31, 36, 40, 42],
		"black_trim": [11, 17, 18, 44],
		"wheel_groups": {"fl": [1], "fr": [6], "rl": [5, 19], "rr": [2, 4]},
		"wheel_axes": {"fl": [0.0780, 0.3071, 0.0741], "fr": [0.0785, 0.3077, 0.0743], "rl": [0.0776, -0.2742, 0.0755], "rr": [0.0770, -0.2743, 0.0761]},
	},
	"res://assets/cars/chevrolet_bel_air_1956.tscn": {
		"default_paint": Color(0.957, 0.937, 0.859),  # boya maskesi aracının ölçtüğü fabrika rengi (#F4EFDB); cars.json default_color ile aynı olmalı
		"body": [1, 2, 7, 8, 9, 10, 11, 12, 13, 14, 15, 17, 20, 21, 23, 24, 28, 29, 32, 34, 35, 36, 37, 38, 39, 40, 41, 42, 44, 45, 47, 49, 50, 51, 52, 54, 55, 58, 59, 60, 61, 62],
		"wheels": [3, 4, 5, 6],
		"rims": [26, 27, 56, 57],
		"headlights": [33, 43],
		"grille": [19, 22, 25, 30, 31],
		"black_trim": [0, 16, 18, 46, 48, 53],
		# Lastiklerin üstü (çamurluğun içi) kaynakta yok: karşı yay döndürülüp eklenir
		"fill_arc": [{"part": 3, "center": [-0.1596, 0.0876, -0.2428], "from": 290, "to": 60},
			{"part": 4, "center": [0.1602, 0.0876, -0.2427], "from": 290, "to": 60},
			{"part": 5, "center": [0.1767, 0.088, 0.3284], "from": 300, "to": 50},
			{"part": 6, "center": [-0.1766, 0.0876, 0.3288], "from": 300, "to": 50}],
		"wheel_groups": {"fl": [5, 56], "fr": [6, 57], "rl": [4], "rr": [3]},
		"wheel_axes": {"fl": [0.0876, 0.3285, 0.0866], "fr": [0.0876, 0.3286, 0.0865], "rl": [0.0873, -0.2424, 0.0861], "rr": [0.0876, -0.2427, 0.0863]},
	},
	"res://assets/cars/chevrolet_corvette_c2.tscn": {
		"default_paint": Color(0.631, 0.647, 0.655),  # boya maskesi aracının ölçtüğü fabrika rengi (#A1A5A7); cars.json default_color ile aynı olmalı
		"body": [0, 7, 8, 9, 11, 12, 13, 14, 16, 18, 19, 20, 23, 24, 25, 26, 32, 34, 35, 36, 37, 40, 42, 43, 46, 47, 48, 51, 52, 53, 55, 57, 58, 59, 61, 63],
		"wheels": [1, 2, 3, 4],
		"rims": [10, 31, 38, 49, 54],
		"headlights": [45, 50],
		"grille": [17, 27, 56],
		"black_trim": [5, 6, 15, 21, 22, 28, 29, 30, 33, 39, 41, 44, 60, 62],
		"wheel_groups": {"fl": [2, 31, 38, 54], "fr": [3, 10], "rl": [1, 49], "rr": [4]},
		"wheel_axes": {"fl": [0.0810, 0.2982, 0.0847], "fr": [0.0818, 0.2980, 0.0843], "rl": [0.0829, -0.2571, 0.0829], "rr": [0.0837, -0.2567, 0.0832]},
	},
	"res://assets/cars/dodge_charger_1970.tscn": {
		"default_paint": Color(0.557, 0.584, 0.608),  # boya maskesi aracının ölçtüğü fabrika rengi (#8E959B); cars.json default_color ile aynı olmalı
		"body": [0, 1, 2, 5, 7, 8, 10, 12, 13, 14, 16, 17, 22, 26, 27, 28, 29, 30, 31, 33, 34, 37, 38, 42, 46, 47, 48, 49, 51, 52, 53, 55, 56, 57, 58, 60, 61, 63, 64, 65],
		"wheels": [3, 4],
		"tires": [6, 66],
		"headlights": [36, 44],
		"grille": [54],
		"black_trim": [11, 15, 18, 19, 20, 21, 23, 24, 25, 32, 35, 39, 40, 41, 43, 45, 50, 59, 62],
		"rims": [9],
		# Sağ-arka lastik sol alt gövde parçasına (1) kaynamış: sol-arka lastiğin aynasından silindirle ayrılır
		"extract": [{"part": 1, "new_part": 66, "center": [-0.1735, 0.0785, -0.2676], "radius": 0.082, "half_width": 0.036}],
		"wheel_groups": {"fl": [4], "fr": [3], "rl": [6, 9], "rr": [66]},
		"wheel_axes": {"fl": [0.0689, 0.2879, 0.0776], "fr": [0.0690, 0.2880, 0.0773], "rl": [0.0696, -0.2676, 0.0778], "rr": [0.0697, -0.2671, 0.0772]},
	},
	"res://assets/cars/fiat_500_1965.tscn": {
		"default_paint": Color(0.259, 0.294, 0.318),  # boya maskesi aracının ölçtüğü fabrika rengi (#424B51); cars.json default_color ile aynı olmalı
		"body": [2, 9, 12, 18, 19, 20, 23, 25, 41, 44, 47, 49, 51, 54, 58, 64, 65, 68],
		"mirrors": [39, 40],
		"wheels": [5, 7, 8, 13],
		"rims": [28, 30, 32, 36, 38],
		"glass": [3, 6, 10, 15, 22, 24, 29, 31, 33, 34, 37, 43, 48, 50, 53, 55, 60],
		"headlights": [35, 42, 61, 67],
		"taillights": [11, 17, 45, 46, 59, 66],
		"grille": [63],
		"black_trim": [0, 1, 4, 14, 16, 21, 26, 27, 52, 56, 57, 62],
		"wheel_groups": {"fl": [8, 28], "fr": [7, 32], "rl": [13, 30], "rr": [5]},
		"wheel_axes": {"fl": [0.0946, 0.3209, 0.0953], "fr": [0.0936, 0.3205, 0.0950], "rl": [0.0960, -0.2779, 0.0948], "rr": [0.0950, -0.2778, 0.0946]},
	},
	"res://assets/cars/ford_escort_rs1600.tscn": {
		"default_paint": Color(0.914, 0.898, 0.886),  # boya maskesi aracının ölçtüğü fabrika rengi (#E9E5E2); cars.json default_color ile aynı olmalı
		"body": [0, 1, 2, 6, 8, 11, 15, 16, 17, 18, 20, 27, 28, 31, 32, 34, 35, 38, 39, 40, 42, 45, 46, 47, 48, 50, 54, 56],
		"mirrors": [33],
		"wheels": [3, 4, 5, 7, 10],
		"rims": [25],
		"glass": [26, 30],
		"headlights": [24, 41, 43],
		"taillights": [51],
		"grille": [21],
		"black_trim": [9, 12, 13, 14, 19, 22, 23, 29, 36, 37, 44, 49, 52, 53, 55],
		"wheel_groups": {"fl": [3], "fr": [5, 25], "rl": [7, 10], "rr": [4]},
		"wheel_axes": {"fl": [0.0807, 0.3431, 0.0764], "fr": [0.0790, 0.3426, 0.0768], "rl": [0.0739, -0.2520, 0.0767], "rr": [0.0733, -0.2522, 0.0749]},
	},
	"res://assets/cars/ford_mustang_1967.tscn": {
		"default_paint": Color(0.573, 0.557, 0.859),  # boya maskesi aracının ölçtüğü fabrika rengi (#928EDB); cars.json default_color ile aynı olmalı
		"body": [0, 5, 11, 13, 14, 18, 19, 20, 23, 24, 25, 26, 27, 29, 30, 31, 32, 35, 36, 37, 39, 40, 41, 43, 44, 45, 47, 53, 56, 57, 60, 61, 64, 65, 66, 69, 70, 71, 72, 74],
		"mirrors": [38, 42, 67, 68],
		"wheels": [7, 8, 9],
		"tires": [1, 2, 3, 4],
		"rims": [6, 12, 17, 50, 58, 62, 63],
		"headlights": [34, 48, 49, 51, 52, 59],
		"grille": [21, 22, 28, 46],
		"black_trim": [10, 15, 16, 33, 54, 55, 73],
		"wheel_groups": {"fl": [1, 9, 12, 58], "fr": [4, 7, 63], "rl": [3, 8, 17, 62], "rr": [2, 6]},
		"wheel_axes": {"fl": [0.0768, 0.2981, 0.0811], "fr": [0.0767, 0.2983, 0.0809], "rl": [0.0781, -0.2832, 0.0817], "rr": [0.0786, -0.2836, 0.0811]},
	},
	"res://assets/cars/jaguar_e_type.tscn": {
		"default_paint": Color(0.706, 0.616, 0.541),  # boya maskesi aracının ölçtüğü fabrika rengi (#B49D8A); cars.json default_color ile aynı olmalı
		"body": [5, 6, 7, 9, 10, 11, 12, 13, 14, 15, 16, 18, 19, 20, 21, 22, 23, 26, 32, 33, 34, 35, 36, 37, 40, 41, 47, 48, 49, 50],
		"wheels": [1, 2, 3, 4],
		"glass": [27],
		"headlights": [17, 24, 25, 31, 42, 43, 44, 45],
		"taillights": [38, 39, 46],
		"grille": [8, 29],
		"black_trim": [0, 28, 30],
		"wheel_groups": {"fl": [1], "fr": [2], "rl": [3], "rr": [4]},
		# Sağ-ön eksen lastikten yanlış ölçülüyordu (yarıçap 0,067; diğerleri 0,079): sol-ön ekseni aynalandı
		"wheel_axes": {"fl": [0.0776, 0.2841, 0.0788], "fr": [0.0776, 0.2841, 0.0788], "rl": [0.0720, -0.2576, 0.0795], "rr": [0.0734, -0.2568, 0.0794]},
	},
	"res://assets/cars/lamborghini_miura.tscn": {
		"default_paint": Color(0.004, 0.447, 0.941),  # boya maskesi aracının ölçtüğü fabrika rengi (#0172F0); cars.json default_color ile aynı olmalı
		"body": [1, 2, 3, 4, 9, 11, 15, 16, 17, 20, 21, 24, 26, 28, 31, 37, 38, 40, 41, 43, 44, 45, 47, 48, 50, 51, 53, 54, 56, 57, 58, 59, 60, 62, 63, 65, 66, 67, 68],
		"wheels": [6, 7, 13],
		"tires": [5, 8, 14],
		"rims": [12, 19, 23, 29, 30, 32, 34, 35, 39, 42, 46, 49, 52],
		"headlights": [61, 64],
		"grille": [18, 22, 36, 69],
		"black_trim": [0, 10, 25, 27, 33, 55],
		"wheel_groups": {"fl": [8, 12, 29, 39, 42], "fr": [6, 30], "rl": [14, 13, 23, 34, 35, 52], "rr": [5, 7, 46, 49]},  # 31 arka çamurluk kemeri
		"wheel_axes": {"fl": [0.0820, 0.2751, 0.0841], "fr": [0.0818, 0.2755, 0.0839], "rl": [0.0834, -0.2917, 0.0870], "rr": [0.0827, -0.2942, 0.0846]},
	},
	"res://assets/cars/lancia_stratos.tscn": {
		"default_paint": Color(0.420, 0.455, 0.482),  # boya maskesi aracının ölçtüğü fabrika rengi (#6B747B); cars.json default_color ile aynı olmalı
		"body": [0, 4, 8, 10, 11, 12, 14, 15, 18, 21, 22, 23, 24, 27, 28, 29, 30, 36, 38, 39, 40],
		"mirrors": [13, 17],
		"wheels": [2, 3, 5, 6, 9],
		"rims": [33, 35],
		"glass": [19, 34],
		"taillights": [7, 25, 37],
		"grille": [20],
		"black_trim": [1, 16, 26, 31, 32],
		"wheel_groups": {"fl": [6, 9], "fr": [2], "rl": [5], "rr": [3]},
		"wheel_axes": {"fl": [0.0916, 0.2677, 0.0896], "fr": [0.0923, 0.2675, 0.0885], "rl": [0.0916, -0.2995, 0.0871], "rr": [0.0924, -0.2994, 0.0866]},
	},
	"res://assets/cars/land_rover_series3.tscn": {
		"default_paint": Color(0.949, 0.945, 0.914),  # boya maskesi aracının ölçtüğü fabrika rengi (#F2F1E9); cars.json default_color ile aynı olmalı
		"body": [1, 3, 5, 7, 8, 13, 15, 16, 20, 21, 26, 27, 35, 36, 40, 41, 42, 43],
		"mirrors": [22, 37],
		"tires": [0, 2, 24, 25],
		"rims": [10, 12, 19, 23, 31, 32, 34, 38, 39],
		"glass": [4],
		"headlights": [47],
		"grille": [17, 30, 33, 45, 46],
		"black_trim": [6, 9, 11, 14, 18, 28, 29, 44],
		"wheel_groups": {"fl": [0, 12, 31], "fr": [25, 10, 32], "rl": [2, 23, 34, 39], "rr": [24, 19, 38]},
		"wheel_axes": {"fl": [0.1083, 0.3344, 0.1068], "fr": [0.1080, 0.3342, 0.1064], "rl": [0.1082, -0.2351, 0.1069], "rr": [0.1080, -0.2346, 0.1062]},
	},
	"res://assets/cars/mercedes_300sl.tscn": {
		"default_paint": Color(0.592, 0.612, 0.620),  # boya maskesi aracının ölçtüğü fabrika rengi (#979C9E); cars.json default_color ile aynı olmalı
		"body": [1, 2, 3, 5, 7, 8, 9, 12, 13, 15, 16, 17, 18, 22, 23, 24, 27, 31, 33, 35, 37, 39, 40, 42, 44, 47, 48, 51, 53, 55, 58, 60, 61, 63, 64, 67, 68],
		"wheels": [4, 14],
		"tires": [6, 10, 11],
		"rims": [19, 25, 36, 38, 43, 46, 49, 52, 66],
		"glass": [57],
		"headlights": [32, 41, 62],
		"grille": [21, 26, 28, 29, 30, 59],
		"black_trim": [0, 20, 34, 45, 50, 54, 56, 65],
		"wheel_groups": {"fl": [6, 19, 38, 49], "fr": [4, 43, 52, 66], "rl": [11, 14], "rr": [10, 25, 36]},
		"wheel_axes": {"fl": [0.0747, 0.3083, 0.0806], "fr": [0.0732, 0.3074, 0.0800], "rl": [0.0760, -0.2191, 0.0813], "rr": [0.0764, -0.2193, 0.0815]},
	},
	"res://assets/cars/mercedes_w123.tscn": {
		"default_paint": Color(0.882, 0.573, 0.231),  # boya maskesi aracının ölçtüğü fabrika rengi (#E1923B); cars.json default_color ile aynı olmalı
		"body": [1, 6, 11, 12, 14, 15, 18, 19, 20, 21, 24, 30, 31, 33, 34, 40, 42, 43, 44, 45, 49, 50, 53, 54, 55, 56, 57, 58, 61, 62, 65, 67, 71, 72, 74, 75, 77, 80, 84, 85, 86, 87, 89],
		"mirrors": [38, 51, 52, 60],
		"wheels": [2, 3, 4, 9, 25],
		"tires": [7],
		"glass": [16, 28, 47, 48, 68, 70],
		"headlights": [27, 41, 66, 69, 73],
		"taillights": [5, 29, 36, 64, 76, 81, 82],
		"grille": [10, 22, 37, 46, 79, 83],
		"black_trim": [0, 8, 13, 17, 23, 26, 32, 35, 39, 63, 78, 88, 90],
		"rims": [59],
		"wheel_groups": {"fl": [3, 59], "fr": [7, 9, 25], "rl": [4], "rr": [2]},
		"wheel_axes": {"fl": [0.0764, 0.3222, 0.0748], "fr": [0.0767, 0.3224, 0.0752], "rl": [0.0754, -0.2749, 0.0751], "rr": [0.0753, -0.2744, 0.0744]},
	},

	"res://assets/cars/mini_cooper_1965.tscn": {
		"default_paint": Color(0.608, 0.722, 0.604),  # boya maskesi aracının ölçtüğü fabrika rengi (#9BB89A); cars.json default_color ile aynı olmalı
		"body": [0, 5, 8, 9, 10, 11, 12, 13, 23, 24, 25, 27, 28, 29, 30, 33, 36, 39, 40, 42, 48, 51, 53, 54],
		"mirrors": [2, 15],
		"wheels": [1, 3, 4, 14],
		"glass": [6, 16, 17, 18, 19, 35, 52],
		"headlights": [26, 31, 32, 34, 37, 38, 41, 44, 46],
		"grille": [50],
		"black_trim": [7, 20, 21, 22, 43, 45, 47, 49],
		"wheel_groups": {"fl": [3], "fr": [4], "rl": [14], "rr": [1]},
		"wheel_axes": {"fl": [0.0969, 0.3368, 0.0930], "fr": [0.0964, 0.3362, 0.0935], "rl": [0.0931, -0.3281, 0.0919], "rr": [0.0926, -0.3284, 0.0916]},
	},
	"res://assets/cars/peugeot_404.tscn": {
		"default_paint": Color(0.929, 0.910, 0.894),  # boya maskesi aracının ölçtüğü fabrika rengi (#EDE8E4); cars.json default_color ile aynı olmalı
		"body": [1, 2, 3, 4, 11, 13, 15, 16, 18, 24, 25, 26, 27, 28, 30, 35, 38, 40, 42, 43, 45, 48, 50, 51, 53, 54, 56, 57, 58, 59, 60, 61, 64, 66, 67, 68, 70, 71, 72, 73, 74, 75, 76, 77],
		"mirrors": [17, 37],
		"wheels": [8, 9, 20, 21],
		"tires": [7, 10, 12, 19],
		"rims": [22, 23, 29, 31, 36, 65],
		"headlights": [39, 41, 52, 62],
		"taillights": [63, 69],
		"grille": [5, 6, 32, 47, 49],
		"black_trim": [0, 14, 33, 34, 44, 46, 55],
		"wheel_groups": {"fl": [19, 20], "fr": [10, 8, 36, 65], "rl": [7, 21], "rr": [12, 9]},
		"wheel_axes": {"fl": [0.0807, 0.3184, 0.0805], "fr": [0.0807, 0.3182, 0.0803], "rl": [0.0831, -0.2762, 0.0821], "rr": [0.0815, -0.2760, 0.0809]},
	},
	"res://assets/cars/porsche_911_1973.tscn": {
		"default_paint": Color(0.004, 0.573, 0.165),  # boya maskesi aracının ölçtüğü fabrika rengi (#01922A); cars.json default_color ile aynı olmalı
		"body": [0, 1, 6, 7, 8, 9, 11, 12, 13, 14, 17, 19, 22, 23, 25, 26, 30, 33, 36, 37, 38, 42, 43, 44, 48, 49, 50, 51, 52],
		"mirrors": [35],
		"wheels": [2, 4],
		"tires": [3, 5],
		"headlights": [20, 28, 29, 32],
		"taillights": [47],
		"grille": [41],
		"black_trim": [10, 15, 16, 18, 21, 24, 27, 31, 34, 39, 40, 46],
		"rims": [45],
		"wheel_groups": {"fl": [5], "fr": [4], "rl": [3], "rr": [2, 45]},
		"wheel_axes": {"fl": [0.0815, 0.3004, 0.0793], "fr": [0.0819, 0.3010, 0.0800], "rl": [0.0770, -0.2618, 0.0795], "rr": [0.0797, -0.2623, 0.0782]},
	},
	"res://assets/cars/tofas_murat_124.tscn": {
		"default_paint": Color(0.757, 0.000, 0.012),  # boya maskesi aracının ölçtüğü fabrika rengi (#C10003); cars.json default_color ile aynı olmalı
		"body": [1, 2, 6, 7, 8, 10, 12, 17, 18, 19, 23, 24, 32, 33, 34, 36, 39, 40],
		"mirrors": [25],
		"wheels": [3, 4, 5, 9],
		"glass": [13, 14, 15, 16, 21, 22, 29],
		"headlights": [28, 35, 37, 38],
		"taillights": [11, 26, 27],
		"black_trim": [0, 20, 30, 31],
		# Arka lastiklerin tepesi kaynakta yok
		"fill_arc": [{"part": 3, "center": [0.2147, 0.0925, -0.2811], "from": 350, "to": 10},
			{"part": 4, "center": [-0.2112, 0.0925, -0.2816], "from": 350, "to": 10}],
		"wheel_groups": {"fl": [9], "fr": [5], "rl": [3], "rr": [4]},
		"wheel_axes": {"fl": [0.0869, 0.3194, 0.0912], "fr": [0.0875, 0.3198, 0.0908], "rl": [0.0927, -0.2812, 0.0914], "rr": [0.0930, -0.2809, 0.0906]},
	},
	"res://assets/cars/tofas_murat_131.tscn": {
		"default_paint": Color(0.439, 0.580, 0.835),  # boya maskesi aracının ölçtüğü fabrika rengi (#7094D5); cars.json default_color ile aynı olmalı
		"body": [0, 2, 6, 9, 12, 13, 14, 15, 17, 18, 19, 20, 21, 22, 23, 24, 29, 32, 34, 35, 37, 42, 48],
		"mirrors": [30, 31],
		"wheels": [3, 4, 5, 10],
		"tires": [7],
		"rims": [11, 33, 36],
		"headlights": [44, 46, 47, 49],
		"taillights": [38, 40],
		"grille": [8, 50],
		"black_trim": [1, 16, 25, 26, 27, 28, 39, 41, 43, 45],
		"wheel_groups": {"fl": [3], "fr": [4], "rl": [5], "rr": [7, 10, 11]},
		"wheel_axes": {"fl": [0.0829, 0.3303, 0.0837], "fr": [0.0830, 0.3305, 0.0835], "rl": [0.0823, -0.2702, 0.0831], "rr": [0.0822, -0.2703, 0.0833]},
	},
	"res://assets/cars/toyota_celica_gt4.tscn": {
		"default_paint": Color(0.902, 0.894, 0.902),  # boya maskesi aracının ölçtüğü fabrika rengi (#E6E4E6); cars.json default_color ile aynı olmalı
		"body": [0, 1, 4, 7, 10, 12, 14, 17, 20, 23, 24, 33, 34, 36, 37, 40, 41, 42],
		"mirrors": [21, 22],
		"wheels": [2, 3, 5, 6],
		"rims": [8, 9, 11, 19, 29, 31],
		"glass": [15, 16],
		"headlights": [25, 26, 27, 35, 39],
		"taillights": [28],
		"grille": [18],
		"black_trim": [13, 30, 32, 38],
		"wheel_groups": {"fl": [2, 31], "fr": [6, 29], "rl": [3, 9, 19], "rr": [5, 8, 11]},
		"wheel_axes": {"fl": [0.0782, 0.2953, 0.0779], "fr": [0.0783, 0.2953, 0.0779], "rl": [0.0787, -0.2951, 0.0784], "rr": [0.0783, -0.2950, 0.0779]},
	},
	"res://assets/cars/vw_beetle_1967.tscn": {
		"default_paint": Color(0.945, 0.310, 0.133),  # boya maskesi aracının ölçtüğü fabrika rengi (#F14F22); cars.json default_color ile aynı olmalı
		"body": [0, 4, 5, 7, 8, 9, 10, 11, 12, 15, 16, 20, 22, 24, 30, 33, 37, 40, 42, 43, 46, 48, 51, 52, 54],
		"mirrors": [32, 35],
		"glass": [19, 50],
		"headlights": [29, 31, 47, 49],
		"taillights": [17, 23, 27, 28, 34],
		"black_trim": [13, 14, 18, 21, 25, 26, 36, 38, 39, 41, 44, 45],
		"rims": [53],
		"tires": [1, 2, 3, 6],
		"wheel_groups": {"fl": [1], "fr": [3], "rl": [6], "rr": [2]},  # 10/4/5/7 çamurluk (sınıflandırıcı "teker" sanmıştı)
		"wheel_axes": {"fl": [0.0985, 0.3039, 0.0954], "fr": [0.0971, 0.3041, 0.0958], "rl": [0.0970, -0.2728, 0.0956], "rr": [0.0997, -0.2731, 0.0951]},
	},
	"res://assets/cars/vw_t1_bus.tscn": {
		"default_paint": Color(0.941, 0.914, 0.867),  # boya maskesi aracının ölçtüğü fabrika rengi (#F0E9DD); cars.json default_color ile aynı olmalı
		"body": [0, 1, 9, 10, 12, 14, 19, 20, 21, 22, 23, 27, 30, 31, 32, 36, 38, 40, 42, 44, 45, 48, 51, 53, 55, 56, 62, 63, 67, 68],
		"mirrors": [8, 11, 25, 28, 33, 35, 43, 47, 49, 58],
		"wheels": [2, 3, 5, 6],
		"glass": [13, 15, 24, 26, 37, 41, 52, 57, 59, 60, 61],
		"headlights": [50, 54],
		"taillights": [17, 39, 46, 64, 65, 66, 69],
		"black_trim": [4, 7, 16, 18, 29, 34],
		# Arka lastiklerin üstü kaynakta yok
		"fill_arc": [{"part": 2, "center": [-0.1825, 0.0903, -0.2848], "from": 330, "to": 30},
			{"part": 3, "center": [0.1828, 0.0908, -0.2846], "from": 330, "to": 30}],
		"wheel_groups": {"fl": [5], "fr": [6], "rl": [3], "rr": [2]},
		"wheel_axes": {"fl": [0.0861, 0.2779, 0.0896], "fr": [0.0864, 0.2780, 0.0897], "rl": [0.0902, -0.2839, 0.0856], "rr": [0.0903, -0.2853, 0.0871]},
	},
	"res://assets/cars/willys_jeep_mb.tscn": {
		"default_paint": Color(0.278, 0.278, 0.149),  # boya maskesi aracının ölçtüğü fabrika rengi (#474726); cars.json default_color ile aynı olmalı
		"body": [0, 5, 6, 8, 9, 12, 16, 17, 19, 21, 22, 24, 25, 26, 27, 28, 30, 31, 32, 35, 38, 41, 42, 43, 44, 45],
		"mirrors": [39],
		"tires": [1, 2, 14, 15],
		"glass": [3],
		"taillights": [20, 37],
		"black_trim": [4, 7, 10, 11, 13, 18, 29, 34, 36, 40],
		"wheel_groups": {"fl": [1], "fr": [2], "rl": [15], "rr": [14]},
		"wheel_axes": {"fl": [0.1162, 0.3150, 0.1172], "fr": [0.1162, 0.3155, 0.1177], "rl": [0.1168, -0.2788, 0.1171], "rr": [0.1172, -0.2788, 0.1170]},
	},
}


static func has_map(scene_path: String) -> bool:
	return MAPS.has(scene_path)


static func get_map(scene_path: String) -> Dictionary:
	return MAPS.get(scene_path, {})


static func part_name(index: int) -> StringName:
	return StringName("tripo_part_%d" % index)
