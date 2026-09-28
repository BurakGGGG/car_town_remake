class_name GarageDecor
## GARAJ DEKORASYONU KATALOĞU — tek kaynak.
##
## Car Town'daki "Edit Garage" karşılığı. ÖNEMLİ FARK: Car Town'da eşyalar para ÜRETİRDİ
## (langırt, benzin pompası: tıklayınca 10 dakikada 13 coin). Bizde tamir döngüsü zaten
## dakikada ~3.400 ₺ basıyor ve 10. saatte 1,1 milyon ₺ ölü para birikiyor (ölçüldü,
## docs/AUDIT_2026_09.md §6). Bu yüzden eşyalar GELİR DEĞİL, GİDER: ödenen paranın bir kısmı
## GARAJ DEĞERİne yazılır, yani rütbe merdivenini uzatır ve biriken parayı emer.
##
## Yerleştirme DIŞ AVLUDA, sabit yuvalarladır (serbest ızgara değil): çirkin yerleşim imkânsız, yapımı hızlı.
## Bir eşya satın alınınca kalıcı olarak SAHİPLENİLİR; garaj değerine sahiplik katkı yapar,
## yuvaya konması yalnızca görsel düzenlemedir.

## Eşya türleri.
enum Kind {
	FLOOR_SURFACE,   # zemin kaplaması (tek yuva)
	WALL_SURFACE,    # duvar kaplaması (tek yuva)
	WORKSHOP,        # atölye eşyası (zemin yuvası)
	LOUNGE,          # yaşam alanı eşyası (zemin yuvası)
	WALL_ITEM,       # duvara asılan (duvar yuvası)
	YARD,            # avlu düzeni (zemin yuvası): bariyer, konteyner, pompa...
	PLANT,           # bitki / peyzaj (zemin yuvası): ağaç, saksı, çit...
}

## Yuva türleri ve hangi eşya türünü kabul ettikleri.
const SLOT_FLOOR_SURFACE: StringName = &"zemin"
const SLOT_WALL_SURFACE: StringName = &"duvar"
const SLOT_FLOOR: StringName = &"taban"      # taban_a … taban_e
const SLOT_WALL: StringName = &"pano"        # pano_a

## DIŞ AVLUDAKİ yuvalar (dünya koordinatı). Avlu sağdan (x=-0.2) ve önden (z=-0.2) sabittir,
## garaj seviyesi arttıkça -x ve -z yönüne büyür (garage_system.gd: 2.0x1.5 → 8.0x6.0).
## Her yuva, o alanın AÇILDIĞI garaj seviyesine bağlıdır: garajı büyütmek yeni yerleştirme
## alanı açar (Car Town'daki "land expansion" mantığı).
## Tamir alanları avlunun ortasında z=-1.05 hattında sıralanır (CarSpot x = -1.72, -3.10, -5.10);
## yuvalar bu hattın ÖNÜNE (z > -0.6) ve ARKASINA (z < -1.5) konuldu, en yakın engel mesafesi
## qa/slot_clear.gd ile ölçüldü (hepsi > 0.62 birim).
const FLOOR_SLOTS: Dictionary = {
	&"taban_01": Vector3(-1.10, 0.0, -1.38),
	&"taban_02": Vector3(-1.10, 0.0, -0.60),
	&"taban_03": Vector3(-3.88, 0.0, -2.88),
	&"taban_04": Vector3(-3.88, 0.0, -2.10),
	&"taban_05": Vector3(-3.88, 0.0, -1.32),
	&"taban_06": Vector3(-3.88, 0.0, -0.54),
	&"taban_07": Vector3(-3.10, 0.0, -2.88),
	&"taban_08": Vector3(-3.10, 0.0, -2.10),
	&"taban_09": Vector3(-2.32, 0.0, -2.88),
	&"taban_10": Vector3(-2.32, 0.0, -2.10),
	&"taban_11": Vector3(-2.32, 0.0, -0.54),
	&"taban_12": Vector3(-1.54, 0.0, -2.88),
	&"taban_13": Vector3(-1.54, 0.0, -2.10),
	&"taban_14": Vector3(-0.76, 0.0, -2.88),
	&"taban_15": Vector3(-0.76, 0.0, -2.10),
	&"taban_16": Vector3(-5.88, 0.0, -4.38),
	&"taban_17": Vector3(-5.88, 0.0, -3.60),
	&"taban_18": Vector3(-5.88, 0.0, -2.82),
	&"taban_19": Vector3(-5.88, 0.0, -2.04),
	&"taban_20": Vector3(-5.88, 0.0, -1.26),
	&"taban_21": Vector3(-5.10, 0.0, -4.38),
	&"taban_22": Vector3(-5.10, 0.0, -3.60),
	&"taban_23": Vector3(-5.10, 0.0, -2.82),
	&"taban_24": Vector3(-5.10, 0.0, -2.04),
	&"taban_25": Vector3(-4.32, 0.0, -4.38),
	&"taban_26": Vector3(-4.32, 0.0, -3.60),
	&"taban_27": Vector3(-3.54, 0.0, -4.38),
	&"taban_28": Vector3(-3.54, 0.0, -3.60),
	&"taban_29": Vector3(-2.76, 0.0, -4.38),
	&"taban_30": Vector3(-2.76, 0.0, -3.60),
	&"taban_31": Vector3(-1.98, 0.0, -4.38),
	&"taban_32": Vector3(-1.98, 0.0, -3.60),
	&"taban_33": Vector3(-1.20, 0.0, -4.38),
	&"taban_34": Vector3(-1.20, 0.0, -3.60),
	&"taban_35": Vector3(-7.88, 0.0, -5.88),
	&"taban_36": Vector3(-7.88, 0.0, -5.10),
	&"taban_37": Vector3(-7.88, 0.0, -4.32),
	&"taban_38": Vector3(-7.88, 0.0, -3.54),
	&"taban_39": Vector3(-7.88, 0.0, -2.76),
	&"taban_40": Vector3(-7.88, 0.0, -1.98),
	&"taban_41": Vector3(-7.88, 0.0, -1.20),
	&"taban_42": Vector3(-7.10, 0.0, -5.88),
	&"taban_43": Vector3(-7.10, 0.0, -5.10),
	&"taban_44": Vector3(-7.10, 0.0, -4.32),
	&"taban_45": Vector3(-7.10, 0.0, -3.54),
	&"taban_46": Vector3(-7.10, 0.0, -2.76),
	&"taban_47": Vector3(-7.10, 0.0, -1.98),
	&"taban_48": Vector3(-7.10, 0.0, -1.20),
	&"taban_49": Vector3(-6.32, 0.0, -5.88),
	&"taban_50": Vector3(-6.32, 0.0, -5.10),
	&"taban_51": Vector3(-5.54, 0.0, -5.88),
	&"taban_52": Vector3(-5.54, 0.0, -5.10),
	&"taban_53": Vector3(-4.76, 0.0, -5.88),
	&"taban_54": Vector3(-4.76, 0.0, -5.10),
	&"taban_55": Vector3(-3.98, 0.0, -5.88),
	&"taban_56": Vector3(-3.98, 0.0, -5.10),
	&"taban_57": Vector3(-3.20, 0.0, -5.88),
	&"taban_58": Vector3(-3.20, 0.0, -5.10),
	&"taban_59": Vector3(-2.42, 0.0, -5.88),
	&"taban_60": Vector3(-2.42, 0.0, -5.10),
	&"taban_61": Vector3(-1.64, 0.0, -5.88),
	&"taban_62": Vector3(-1.64, 0.0, -5.10),
	&"taban_63": Vector3(-0.86, 0.0, -5.88),
	&"taban_64": Vector3(-0.86, 0.0, -5.10),
}
## Yuvanın açılması için gereken garaj seviyesi (1 tabanlı).
const FLOOR_SLOT_LEVEL: Dictionary = {
	&"taban_01": 1,
	&"taban_02": 1,
	&"taban_03": 2,
	&"taban_04": 2,
	&"taban_05": 2,
	&"taban_06": 2,
	&"taban_07": 2,
	&"taban_08": 2,
	&"taban_09": 2,
	&"taban_10": 2,
	&"taban_11": 2,
	&"taban_12": 2,
	&"taban_13": 2,
	&"taban_14": 2,
	&"taban_15": 2,
	&"taban_16": 3,
	&"taban_17": 3,
	&"taban_18": 3,
	&"taban_19": 3,
	&"taban_20": 3,
	&"taban_21": 3,
	&"taban_22": 3,
	&"taban_23": 3,
	&"taban_24": 3,
	&"taban_25": 3,
	&"taban_26": 3,
	&"taban_27": 3,
	&"taban_28": 3,
	&"taban_29": 3,
	&"taban_30": 3,
	&"taban_31": 3,
	&"taban_32": 3,
	&"taban_33": 3,
	&"taban_34": 3,
	&"taban_35": 4,
	&"taban_36": 4,
	&"taban_37": 4,
	&"taban_38": 4,
	&"taban_39": 4,
	&"taban_40": 4,
	&"taban_41": 4,
	&"taban_42": 4,
	&"taban_43": 4,
	&"taban_44": 4,
	&"taban_45": 4,
	&"taban_46": 4,
	&"taban_47": 4,
	&"taban_48": 4,
	&"taban_49": 4,
	&"taban_50": 4,
	&"taban_51": 4,
	&"taban_52": 4,
	&"taban_53": 4,
	&"taban_54": 4,
	&"taban_55": 4,
	&"taban_56": 4,
	&"taban_57": 4,
	&"taban_58": 4,
	&"taban_59": 4,
	&"taban_60": 4,
	&"taban_61": 4,
	&"taban_62": 4,
	&"taban_63": 4,
	&"taban_64": 4,
}
## Zemin eşyalarının baktığı yön (dereceyle): avluya / yola dönük dururlar.
const FLOOR_SLOT_YAW: Dictionary = {
	&"taban_01": 0.0,
	&"taban_02": 180.0,
	&"taban_03": 0.0,
	&"taban_04": 0.0,
	&"taban_05": 180.0,
	&"taban_06": 180.0,
	&"taban_07": 0.0,
	&"taban_08": 0.0,
	&"taban_09": 0.0,
	&"taban_10": 0.0,
	&"taban_11": 180.0,
	&"taban_12": 0.0,
	&"taban_13": 0.0,
	&"taban_14": 0.0,
	&"taban_15": 0.0,
	&"taban_16": 0.0,
	&"taban_17": 0.0,
	&"taban_18": 0.0,
	&"taban_19": 180.0,
	&"taban_20": 180.0,
	&"taban_21": 0.0,
	&"taban_22": 0.0,
	&"taban_23": 0.0,
	&"taban_24": 180.0,
	&"taban_25": 0.0,
	&"taban_26": 0.0,
	&"taban_27": 0.0,
	&"taban_28": 0.0,
	&"taban_29": 0.0,
	&"taban_30": 0.0,
	&"taban_31": 0.0,
	&"taban_32": 0.0,
	&"taban_33": 0.0,
	&"taban_34": 0.0,
	&"taban_35": 0.0,
	&"taban_36": 0.0,
	&"taban_37": 0.0,
	&"taban_38": 0.0,
	&"taban_39": 180.0,
	&"taban_40": 180.0,
	&"taban_41": 180.0,
	&"taban_42": 0.0,
	&"taban_43": 0.0,
	&"taban_44": 0.0,
	&"taban_45": 0.0,
	&"taban_46": 180.0,
	&"taban_47": 180.0,
	&"taban_48": 180.0,
	&"taban_49": 0.0,
	&"taban_50": 0.0,
	&"taban_51": 0.0,
	&"taban_52": 0.0,
	&"taban_53": 0.0,
	&"taban_54": 0.0,
	&"taban_55": 0.0,
	&"taban_56": 0.0,
	&"taban_57": 0.0,
	&"taban_58": 0.0,
	&"taban_59": 0.0,
	&"taban_60": 0.0,
	&"taban_61": 0.0,
	&"taban_62": 0.0,
	&"taban_63": 0.0,
	&"taban_64": 0.0,
}
## Duvar yuvası: garajın ARKA duvarının avluya bakan yüzü. Duvar seviyeyle birlikte kaydığı
## için konum çalışma anında hesaplanır (bkz. GarageDecorView); buradaki değer seviye 1 içindir.
const WALL_SLOTS: Dictionary = {
	&"pano_a": Vector3(-1.20, 0.42, -1.62),
	&"pano_b": Vector3(-1.95, 0.42, -1.62),
	&"pano_c": Vector3(-0.45, 0.42, -1.62),
}
const WALL_SLOT_LEVEL: Dictionary = {&"pano_a": 1, &"pano_b": 2, &"pano_c": 2}
const WALL_SLOT_YAW: Dictionary = {&"pano_a": 0.0, &"pano_b": 0.0, &"pano_c": 0.0}

## KATALOG. `value` = garaj değerine katkı (fiyatın ~%40'ı: harcanan para prestije dönüşür ama
## satın alma "değer üretir" sömürüsüne dönüşmez). `min_rank` = garaj rütbesi kilidi.
const ITEMS: Array[Dictionary] = [
	# --- zemin kaplamaları
	{"id": &"floor_tile", "title": "KARO AVLU", "kind": Kind.FLOOR_SURFACE,
		"price": 6000, "value": 2400, "min_rank": 1,
		"desc": "Açık gri karo. Avluyu aydınlatır."},
	{"id": &"floor_epoxy", "title": "ASFALT AVLU", "kind": Kind.FLOOR_SURFACE,
		"price": 22000, "value": 8800, "min_rank": 3,
		"desc": "Koyu asfalt kaplama. Profesyonel görünüm."},
	# --- duvar kaplamaları
	{"id": &"wall_brick", "title": "TUĞLA DUVAR", "kind": Kind.WALL_SURFACE,
		"price": 9000, "value": 3600, "min_rank": 2,
		"desc": "Kırmızı tuğla. Klasik tamirhane havası."},
	{"id": &"wall_panel", "title": "PANEL DUVAR", "kind": Kind.WALL_SURFACE,
		"price": 30000, "value": 12000, "min_rank": 4,
		"desc": "Beyaz panel kaplama. Temiz ve modern."},
	# --- atölye
	{"id": &"tool_cabinet", "title": "TAKIM DOLABI", "kind": Kind.WORKSHOP,
		"price": 3000, "value": 1200, "min_rank": 1,
		"desc": "Kırmızı çekmeceli dolap."},
	{"id": &"tyre_rack", "title": "LASTİK RAFI", "kind": Kind.WORKSHOP,
		"price": 5000, "value": 2000, "min_rank": 1,
		"desc": "İstiflenmiş yedek lastikler."},
	{"id": &"compressor", "title": "KOMPRESÖR", "kind": Kind.WORKSHOP,
		"price": 12000, "value": 4800, "min_rank": 2,
		"desc": "Hava kompresörü ve hortum makarası."},
	{"id": &"tool_trolley", "title": "ALET ARABASI", "kind": Kind.WORKSHOP,
		"price": 16000, "value": 6400, "min_rank": 3,
		"desc": "Tekerlekli alet arabası."},
	# --- yaşam alanı
	{"id": &"sofa", "title": "KANEPE", "kind": Kind.LOUNGE,
		"price": 8000, "value": 3200, "min_rank": 2,
		"desc": "Müşteri bekleme kanepesi."},
	{"id": &"coffee_table", "title": "SEHPA", "kind": Kind.LOUNGE,
		"price": 4000, "value": 1600, "min_rank": 1,
		"desc": "Ahşap sehpa, üstünde dergiler."},
	{"id": &"vending", "title": "OTOMAT", "kind": Kind.LOUNGE,
		"price": 26000, "value": 10400, "min_rank": 4,
		"desc": "Işıklı atıştırmalık otomatı."},
	{"id": &"neon_sign", "title": "NEON TABELA", "kind": Kind.WALL_ITEM,
		"price": 60000, "value": 24000, "min_rank": 6,
		"desc": "Duvara asılan neon garaj tabelası."},
	# --- atölye (ikinci parti)
	{"id": &"oil_drums", "title": "YAĞ VARİLLERİ", "kind": Kind.WORKSHOP,
		"price": 3500, "value": 1400, "min_rank": 1,
		"desc": "Üç renkli yağ varili."},
	{"id": &"pallet_stack", "title": "PALET YIĞINI", "kind": Kind.WORKSHOP,
		"price": 2500, "value": 1000, "min_rank": 1,
		"desc": "İstiflenmiş ahşap paletler."},
	{"id": &"tyre_pile", "title": "LASTİK YIĞINI", "kind": Kind.WORKSHOP,
		"price": 12000, "value": 4800, "min_rank": 2,
		"desc": "Üst üste atılmış hurda lastikler."},
	{"id": &"jack_stand", "title": "KRİKO", "kind": Kind.WORKSHOP,
		"price": 9500, "value": 3800, "min_rank": 2,
		"desc": "Kırmızı zemin krikosu."},
	{"id": &"parts_shelf", "title": "PARÇA RAFI", "kind": Kind.WORKSHOP,
		"price": 34000, "value": 13600, "min_rank": 4,
		"desc": "Üç katlı metal raf, kasalarla dolu."},
	# --- avlu düzeni
	{"id": &"traffic_cones", "title": "TRAFİK KONİLERİ", "kind": Kind.YARD,
		"price": 1500, "value": 600, "min_rank": 1,
		"desc": "Üçlü turuncu koni takımı."},
	{"id": &"barrier", "title": "BARİYER", "kind": Kind.YARD,
		"price": 7000, "value": 2800, "min_rank": 2,
		"desc": "Kırmızı-beyaz yol bariyeri."},
	{"id": &"dumpster", "title": "ÇÖP KONTEYNERİ", "kind": Kind.YARD,
		"price": 11000, "value": 4400, "min_rank": 2,
		"desc": "Tekerlekli yeşil konteyner."},
	{"id": &"container", "title": "DEPO KONTEYNERİ", "kind": Kind.YARD,
		"price": 48000, "value": 19200, "min_rank": 5,
		"desc": "Nervürlü saç depo konteyneri."},
	{"id": &"fuel_pump", "title": "YAKIT POMPASI", "kind": Kind.YARD,
		"price": 85000, "value": 34000, "min_rank": 7,
		"desc": "Kırmızı yakıt pompası, ekranlı."},
	# --- yaşam alanı (ikinci parti)
	{"id": &"bench", "title": "BANK", "kind": Kind.LOUNGE,
		"price": 5500, "value": 2200, "min_rank": 1,
		"desc": "Ahşap latalı bahçe bankı."},
	{"id": &"picnic_table", "title": "PİKNİK MASASI", "kind": Kind.LOUNGE,
		"price": 14000, "value": 5600, "min_rank": 3,
		"desc": "Oturaklı ahşap piknik masası."},
	{"id": &"potted_plant", "title": "SAKSI BİTKİ", "kind": Kind.LOUNGE,
		"price": 6500, "value": 2600, "min_rank": 2,
		"desc": "Terracotta saksıda yeşillik."},
	# --- aydınlatma / tabela
	{"id": &"lamp_post", "title": "AYDINLATMA DİREĞİ", "kind": Kind.YARD,
		"price": 40000, "value": 16000, "min_rank": 5,
		"desc": "Işıklı avlu direği."},
	{"id": &"flagpole", "title": "BAYRAK DİREĞİ", "kind": Kind.YARD,
		"price": 120000, "value": 48000, "min_rank": 8,
		"desc": "Garaj bayrağı taşıyan direk."},
	# --- 2026-09-28: Blender script'leriyle üretilen 38 model (tools/decor/props_*.py)
	{"id": &"hedge", "title": "ÇİT BİTKİ", "kind": Kind.PLANT,
		"price": 3000, "value": 1200, "min_rank": 1,
		"desc": "Budanmış yeşil çit bloğu."},
	{"id": &"tyre_planter", "title": "LASTİK SAKSI", "kind": Kind.PLANT,
		"price": 3500, "value": 1400, "min_rank": 1,
		"desc": "Boyalı lastiğin içinde çiçek."},
	{"id": &"planter_box", "title": "AHŞAP SAKSI", "kind": Kind.PLANT,
		"price": 5000, "value": 2000, "min_rank": 1,
		"desc": "Ahşap kasada üç yeşillik."},
	{"id": &"flower_bed", "title": "ÇİÇEK TARHI", "kind": Kind.PLANT,
		"price": 7500, "value": 3000, "min_rank": 2,
		"desc": "Taş bordürlü çiçek tarhı."},
	{"id": &"vase_large", "title": "BÜYÜK VAZO", "kind": Kind.PLANT,
		"price": 9000, "value": 3600, "min_rank": 2,
		"desc": "Terracotta vazoda yeşillik."},
	{"id": &"tree_round", "title": "YUVARLAK AĞAÇ", "kind": Kind.PLANT,
		"price": 18000, "value": 7200, "min_rank": 3,
		"desc": "Geniş taçlı gölge ağacı."},
	{"id": &"tree_slim", "title": "İNCE AĞAÇ", "kind": Kind.PLANT,
		"price": 20000, "value": 8000, "min_rank": 3,
		"desc": "Uzun ve dar, sıraya dizilir."},
	{"id": &"tree_pine", "title": "ÇAM", "kind": Kind.PLANT,
		"price": 24000, "value": 9600, "min_rank": 4,
		"desc": "Üç katlı iğne yapraklı çam."},
	{"id": &"tree_palm", "title": "PALMİYE", "kind": Kind.PLANT,
		"price": 38000, "value": 15200, "min_rank": 5,
		"desc": "Yedi yapraklı palmiye."},
	{"id": &"speed_bump", "title": "KASİS", "kind": Kind.YARD,
		"price": 2000, "value": 800, "min_rank": 1,
		"desc": "Sarı-siyah hız kesici."},
	{"id": &"warning_sign", "title": "UYARI TABELASI", "kind": Kind.YARD,
		"price": 2800, "value": 1120, "min_rank": 1,
		"desc": "Katlanır sarı uyarı levhası."},
	{"id": &"jerry_cans", "title": "BENZİN BİDONLARI", "kind": Kind.YARD,
		"price": 3200, "value": 1280, "min_rank": 1,
		"desc": "Üç yedek yakıt bidonu."},
	{"id": &"sandbags", "title": "KUM TORBALARI", "kind": Kind.YARD,
		"price": 3800, "value": 1520, "min_rank": 1,
		"desc": "Üç sıra istiflenmiş torba."},
	{"id": &"wooden_crates", "title": "AHŞAP KASALAR", "kind": Kind.YARD,
		"price": 4000, "value": 1600, "min_rank": 1,
		"desc": "Dört ahşap nakliye kasası."},
	{"id": &"bollards", "title": "DUBA SIRASI", "kind": Kind.YARD,
		"price": 4500, "value": 1800, "min_rank": 1,
		"desc": "Üç sarı baba."},
	{"id": &"arrow_sign", "title": "YÖN OKU", "kind": Kind.YARD,
		"price": 5500, "value": 2200, "min_rank": 1,
		"desc": "Direkli sarı yön oku."},
	{"id": &"cable_reel", "title": "KABLO MAKARASI", "kind": Kind.YARD,
		"price": 6000, "value": 2400, "min_rank": 2,
		"desc": "Ahşap makarada kalın kablo."},
	{"id": &"extinguisher_stand", "title": "YANGIN TÜPÜ", "kind": Kind.YARD,
		"price": 7500, "value": 3000, "min_rank": 2,
		"desc": "İki tüplü stand."},
	{"id": &"hose_reel", "title": "HORTUM MAKARASI", "kind": Kind.YARD,
		"price": 8500, "value": 3400, "min_rank": 2,
		"desc": "Duvara sabit hortum makarası."},
	{"id": &"car_ramps", "title": "ÇIKIŞ RAMPALARI", "kind": Kind.YARD,
		"price": 9000, "value": 3600, "min_rank": 2,
		"desc": "Sarı çift servis rampası."},
	{"id": &"parking_sign", "title": "PARK TABELASI", "kind": Kind.YARD,
		"price": 13000, "value": 5200, "min_rank": 3,
		"desc": "Mavi park levhası."},
	{"id": &"air_station", "title": "HAVA İSTASYONU", "kind": Kind.YARD,
		"price": 28000, "value": 11200, "min_rank": 4,
		"desc": "Lastik hava ve basınç ünitesi."},
	{"id": &"spare_doors", "title": "YEDEK KAPILAR", "kind": Kind.WORKSHOP,
		"price": 11000, "value": 4400, "min_rank": 2,
		"desc": "Duvara yaslı üç kaporta kapısı."},
	{"id": &"welding_set", "title": "KAYNAK TAKIMI", "kind": Kind.WORKSHOP,
		"price": 17000, "value": 6800, "min_rank": 3,
		"desc": "İki tüplü kaynak arabası."},
	{"id": &"engine_block", "title": "MOTOR BLOĞU", "kind": Kind.WORKSHOP,
		"price": 22000, "value": 8800, "min_rank": 3,
		"desc": "Sehpaya alınmış motor."},
	{"id": &"barrel_rack", "title": "VARİL RAFI", "kind": Kind.WORKSHOP,
		"price": 26000, "value": 10400, "min_rank": 4,
		"desc": "İki katlı, altı varilli raf."},
	{"id": &"workbench", "title": "ÇALIŞMA TEZGÂHI", "kind": Kind.WORKSHOP,
		"price": 32000, "value": 12800, "min_rank": 4,
		"desc": "Alet panolu ahşap tezgâh."},
	{"id": &"cooler", "title": "BUZLUK", "kind": Kind.LOUNGE,
		"price": 4500, "value": 1800, "min_rank": 1,
		"desc": "Mavi taşınabilir buzluk."},
	{"id": &"deck_chair", "title": "ŞEZLONG", "kind": Kind.LOUNGE,
		"price": 6000, "value": 2400, "min_rank": 1,
		"desc": "Bez şezlong."},
	{"id": &"dog_house", "title": "KÖPEK KULÜBESİ", "kind": Kind.LOUNGE,
		"price": 8000, "value": 3200, "min_rank": 2,
		"desc": "Kırmızı çatılı kulübe."},
	{"id": &"bbq", "title": "MANGAL", "kind": Kind.LOUNGE,
		"price": 15000, "value": 6000, "min_rank": 3,
		"desc": "Kapaklı yuvarlak mangal."},
	{"id": &"parasol_table", "title": "ŞEMSİYELİ MASA", "kind": Kind.LOUNGE,
		"price": 21000, "value": 8400, "min_rank": 3,
		"desc": "Kırmızı şemsiyeli masa, üç tabure."},
	{"id": &"string_lights", "title": "IŞIK DİZİSİ", "kind": Kind.YARD,
		"price": 26000, "value": 10400, "min_rank": 4,
		"desc": "İki direk arası asma ampuller."},
	{"id": &"floodlight", "title": "PROJEKTÖR DİREĞİ", "kind": Kind.YARD,
		"price": 45000, "value": 18000, "min_rank": 5,
		"desc": "Çift başlı avlu projektörü."},
	{"id": &"garage_sign", "title": "GARAJ TABELASI", "kind": Kind.YARD,
		"price": 110000, "value": 44000, "min_rank": 7,
		"desc": "Çift direkli büyük tabela."},
	{"id": &"wall_clock", "title": "DUVAR SAATİ", "kind": Kind.WALL_ITEM,
		"price": 6500, "value": 2600, "min_rank": 2,
		"desc": "Klasik yuvarlak atölye saati."},
	{"id": &"wall_poster", "title": "POSTER", "kind": Kind.WALL_ITEM,
		"price": 8000, "value": 3200, "min_rank": 2,
		"desc": "Çerçeveli yarış posteri."},
	{"id": &"neon_garage", "title": "NEON 'GARAJ'", "kind": Kind.WALL_ITEM,
		"price": 75000, "value": 30000, "min_rank": 6,
		"desc": "Harf harf neon garaj tabelası."},
	# --- detaylı 'hero' eşyalar (tools/decor/props_detay_*.py); vending ve fuel_pump
	# zaten katalogdaydı, modelleri geldiği için kodla üretim yerine GLB kullanılıyor
	{"id": &"mechanic", "title": "TAMİRCİ FİGÜRÜ", "kind": Kind.YARD,
		"price": 25000, "value": 10000, "min_rank": 3,
		"desc": "Tulumlu, şapkalı tamirci."},
	{"id": &"foosball", "title": "LANGIRT MASASI", "kind": Kind.LOUNGE,
		"price": 30000, "value": 12000, "min_rank": 3,
		"desc": "Sekiz çubuklu langırt."},
	{"id": &"jukebox", "title": "JUKEBOX", "kind": Kind.LOUNGE,
		"price": 35000, "value": 14000, "min_rank": 4,
		"desc": "Kavisli, ışıklı müzik dolabı."},
	{"id": &"motorcycle", "title": "MOTOSİKLET", "kind": Kind.YARD,
		"price": 45000, "value": 18000, "min_rank": 5,
		"desc": "Telli jantlı klasik motor."},
	{"id": &"wreck", "title": "HURDA ARAÇ", "kind": Kind.YARD,
		"price": 55000, "value": 22000, "min_rank": 5,
		"desc": "Paslı, camı kırık, tek tekeri eksik."},
	{"id": &"water_tower", "title": "SU DEPOSU", "kind": Kind.YARD,
		"price": 65000, "value": 26000, "min_rank": 6,
		"desc": "Dört ayaklı, merdivenli su kulesi."},
	{"id": &"trophy_case", "title": "KUPA VİTRİNİ", "kind": Kind.LOUNGE,
		"price": 70000, "value": 28000, "min_rank": 6,
		"desc": "Işıklı camlı dokuz kupalı vitrin."},
	{"id": &"trailer", "title": "SERVİS RÖMORKU", "kind": Kind.YARD,
		"price": 80000, "value": 32000, "min_rank": 7,
		"desc": "Pencereli, kapılı servis karavanı."},
	{"id": &"car_lift", "title": "ARAÇ LİFTİ", "kind": Kind.YARD,
		"price": 95000, "value": 38000, "min_rank": 7,
		"desc": "İki sütunlu hidrolik lift."},
]


static func all() -> Array[Dictionary]:
	return ITEMS


static func get_item(id: StringName) -> Dictionary:
	for item: Dictionary in ITEMS:
		if item["id"] == id:
			return item
	return {}


static func exists(id: StringName) -> bool:
	return not get_item(id).is_empty()


## Bu eşyanın gireceği yuva türü.
static func slot_kind(id: StringName) -> StringName:
	match int(get_item(id).get("kind", -1)):
		Kind.FLOOR_SURFACE: return SLOT_FLOOR_SURFACE
		Kind.WALL_SURFACE: return SLOT_WALL_SURFACE
		Kind.WALL_ITEM: return SLOT_WALL
		Kind.WORKSHOP, Kind.LOUNGE, Kind.YARD, Kind.PLANT: return SLOT_FLOOR
		_: return &""


## Bu yuvaya konabilecek eşyalar.
static func items_for_slot(slot: StringName) -> Array[Dictionary]:
	var kind: StringName = slot_of(slot)
	var out: Array[Dictionary] = []
	for item: Dictionary in ITEMS:
		if slot_kind(item["id"]) == kind:
			out.append(item)
	return out


## Yuva adından yuva TÜRÜ ("taban_c" → "taban").
static func slot_of(slot: StringName) -> StringName:
	var text: String = String(slot)
	var cut: int = text.find("_")
	return StringName(text.substr(0, cut)) if cut > 0 else slot


## Bu yuva hangi garaj seviyesinde açılır?
static func slot_level(slot: StringName) -> int:
	if FLOOR_SLOT_LEVEL.has(slot):
		return int(FLOOR_SLOT_LEVEL[slot])
	if WALL_SLOT_LEVEL.has(slot):
		return int(WALL_SLOT_LEVEL[slot])
	return 1


## Verilen garaj seviyesinde kullanılabilir yuvalar.
static func slots_for_level(level: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for slot: StringName in slots():
		if slot_level(slot) <= level:
			out.append(slot)
	return out


## Tüm yuva adları (kayıt ve arayüz sırası).
static func slots() -> Array[StringName]:
	var out: Array[StringName] = [SLOT_FLOOR_SURFACE, SLOT_WALL_SURFACE]
	for key: StringName in FLOOR_SLOTS:
		out.append(key)
	for key: StringName in WALL_SLOTS:
		out.append(key)
	return out


## Kategori başlığı (arayüz).
static func kind_title(kind: int) -> String:
	match kind:
		Kind.FLOOR_SURFACE: return "AVLU ZEMİNİ"
		Kind.WALL_SURFACE: return "GARAJ DUVARI"
		Kind.WORKSHOP: return "ATÖLYE"
		Kind.LOUNGE: return "YAŞAM ALANI"
		Kind.YARD: return "AVLU DÜZENİ"
		Kind.PLANT: return "BİTKİ"
		_: return "PANO"
