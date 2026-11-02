class_name EnginePreset
extends RefCounted
## MOTOR SESİ ÖN AYARI (2026-11-02, kullanıcı: "sesler çok yapay ve neredeyse hepsi birbirinin aynısı… bana bir ses
## yapıcı program yapsan ben yapsam daha iyi olur"). Bir aracın motor sesini tarif eden parametre sözlüğü: MOTOR SES
## LABORATUVARI (tools/engine_lab) bunu düzenler, EngineSynth bundan ses üretir, EngineBank pişirir.
##
## PARAMETRELERİN TEK TANIMI aşağıdaki PARAMS tablosudur (anahtar, grup, ad, alt/üst sınır, varsayılan, adım, birim,
## açıklama). Laboratuvarın sürgüleri bu tablodan kurulur; yeni parametre = bir satır + EngineSynth'te kullanımı.
##
## Kaynak sırası: res://vehicles/sound/presets/<id>.json (laboratuvarda KAYDET ile yazılır, "elle ayarlı") varsa o;
## yoksa auto(): cars.json motor bilgisinden (dizilim, hacim, turbo, yakıt, yıl) şablon + araca özgü küçük farklar.

const PRESET_DIR: String = "res://vehicles/sound/presets/"

## Motor dizilimi: [kimlik, laboratuvardaki ad]. Ateşleme açıları / taraf (bank) ataması EngineSynth.geometry'de.
const LAYOUTS: Array = [
	["i1", "Tek silindir"],
	["i2", "Sıra 2 (paralel)"],
	["i3", "Sıra 3"],
	["i4", "Sıra 4"],
	["i5", "Sıra 5"],
	["i6", "Sıra 6"],
	["v6_60", "V6 (eşit ateşleme)"],
	["v6_90", "V6 90° (tek-çift ateşleme)"],
	["v8_cross", "V8 çapraz krank (Amerikan)"],
	["v8_flat", "V8 düz krank (Ferrari)"],
	["v10", "V10"],
	["v12", "V12"],
	["w12", "W12"],
	["w16", "W16"],
	["b4", "Boksör 4"],
	["b6", "Boksör 6"],
	["r2", "Wankel 2 rotor"],
	["r3", "Wankel 3 rotor"],
	["ev", "Elektrik motoru"],
]
const BLOWOFF_KINDS: Array = [["psst", "Tıslama (psst)"], ["flutter", "Kesik kesik (stu-tu-tu)"]]
const RATES: Array = [[22050, "22 kHz"], [24000, "24 kHz"], [32000, "32 kHz"]]

## Seçmeli parametrelerin seçenekleri (laboratuvar açılır liste kurar).
const CHOICES: Dictionary = {
	"layout": LAYOUTS,
	"blowoff_kind": BLOWOFF_KINDS,
	"rate": RATES,
}

## [anahtar, grup, ad, alt, üst, varsayılan, adım, birim, açıklama]. Seçmeli parametrelerde alt/üst/adım yok sayılır.
const PARAMS: Array = [
	# --- Motor ---
	["layout", "Motor", "Dizilim", 0, 0, "i4", 0, "", "Silindirlerin dizilişi: ateşleme aralıklarını ve egzozun kaç taraftan çıktığını belirler. Sesin karakterinin temeli."],
	["idle_rpm", "Motor", "Rölanti devri", 0, 1600, 850.0, 10, "d/dk", "Dururken motorun dönme hızı. Elektrikte 0."],
	["redline_rpm", "Motor", "Kırmızı çizgi", 3000, 18000, 6500.0, 100, "d/dk", "En yüksek devir. Dizel ~4500, sıradan benzinli ~6500, süper araç 8500+, elektrik 12000-16000."],
	["layers", "Motor", "Devir katmanı", 4, 10, 7, 1, "adet", "Kaç devirde ayrı döngü pişirilir. Çok = devir değişimi daha pürüzsüz, paket daha büyük."],
	["rate", "Motor", "Örnekleme", 0, 0, 24000, 0, "", "Pişirme örnekleme hızı. Tiz çığlıklı motorlarda (V10, düz krank V8) 32 kHz."],
	# --- Ateşleme ---
	["pulse_deg", "Ateşleme", "Darbe genişliği", 100, 320, 220.0, 5, "°", "Egzoz supabının açık kaldığı krank açısı. Dar = kuru, tok; geniş = dolgun, yuvarlak."],
	["sharpness", "Ateşleme", "Darbe sertliği", 0.0, 1.0, 0.5, 0.01, "", "Egzoz darbesinin ne kadar ani yükseldiği. Yüksek = sert, çatlak, tiz; düşük = yumuşak, boğuk."],
	["comb_var", "Ateşleme", "Yanma düzensizliği", 0.0, 0.6, 0.12, 0.01, "", "Her yanmanın gücü biraz farklı. Biraz = canlı; çok = hırpalanmış, eski motor."],
	["jitter", "Ateşleme", "Zamanlama titremesi", 0.0, 1.0, 0.1, 0.01, "", "Ateşleme anlarının küçük kayması. Yapay 'makine' tekdüzeliğini kırar."],
	["lope", "Ateşleme", "Kam dalgalanması", 0.0, 1.0, 0.0, 0.01, "", "Sert kamlı motorların rölantide 'lop-lop' dalgalanması (Amerikan V8, yarış motoru). Devir arttıkça kaybolur."],
	["imbalance", "Ateşleme", "Silindir farkı", 0.0, 0.5, 0.08, 0.01, "", "Silindirlerin birbirinden sabit güç farkı: motorun 'yürüyüş' deseni."],
	["bank_inter", "Ateşleme", "Taraf etkileşimi", 0.0, 1.0, 0.3, 0.01, "", "Aynı egzoz tarafına sık gelen darbelerin birbirini bastırması. Çapraz krank V8'in 'gurultusu' buradan."],
	["misfire", "Ateşleme", "Gaz kesikte tekleme", 0.0, 0.6, 0.05, 0.01, "", "Gaz kesikken bazı yanmaların zayıf geçmesi: 'burble', tıkırtılı yavaşlama."],
	# --- Manifold ---
	["header_len", "Manifold", "Manifold boyu", 0.2, 1.6, 0.7, 0.01, "m", "Silindirden kolektöre boru boyu. Kısa = tiz renk, uzun = pes renk (300-600 Hz civarı)."],
	["header_spread", "Manifold", "Boy farkı", 0.0, 0.8, 0.1, 0.01, "", "Manifold borularının birbirinden farkı. Yüksek değer boksör motorun 'gurul gurul' sesini verir."],
	["header_refl", "Manifold", "Manifold yansıması", 0.0, 0.85, 0.35, 0.01, "", "Darbenin kolektörden geri yansıması. Yüksek = metalik, 'borulu' tını."],
	["collector_drive", "Manifold", "Kolektör doyumu", 0.5, 4.0, 1.2, 0.05, "", "Darbelerin kolektörde birbirine çarpması (doğrusal olmama). Yüksek = sert, kirli."],
	# --- Egzoz ---
	["pipe_len", "Egzoz", "Egzoz borusu boyu", 0.4, 5.0, 2.4, 0.05, "m", "Kolektörden çıkışa boru boyu. Borunun rezonans tonlarını belirler."],
	["pipe_reso", "Egzoz", "Boru rezonansı", 0.0, 0.92, 0.45, 0.01, "", "Borunun ne kadar 'öttüğü'. Yüksek = boru tonu belirgin, uğuldar."],
	["pipe_damp", "Egzoz", "Boru sönümü", 0.0, 1.0, 0.4, 0.01, "", "Borunun tizleri yutması. Yüksek = yumuşak rezonans."],
	["bank_offset", "Egzoz", "İki taraf farkı", 0.0, 0.5, 0.1, 0.01, "", "Çift egzozlu (V / boksör) motorda iki borunun boy farkı."],
	["crossover", "Egzoz", "X-boru karışımı", 0.0, 1.0, 0.3, 0.01, "", "İki tarafın egzozu ne kadar birleşiyor. 0 = ayrı (gurultulu), 1 = tek boru (düzgün)."],
	# --- Susturucu ---
	["muffler_cut", "Susturucu", "Susturucu açıklığı", 200, 10000, 1400.0, 10, "Hz", "Susturucunun geçirdiği en tiz ses. Düşük = boğuk sıradan araç, yüksek = düz egzoz / yarış."],
	["muffler_q", "Susturucu", "Susturucu tınısı", 0.5, 4.0, 0.8, 0.05, "", "Kesim noktasındaki tepe. Yüksek = 'boğazdan' ses."],
	["chamber_hz", "Susturucu", "Uğultu frekansı", 30, 700, 140.0, 1, "Hz", "Susturucu odasının rezonansı (yolda 'drone')."],
	["chamber_db", "Susturucu", "Uğultu düzeyi", -12.0, 15.0, 4.0, 0.5, "dB", "Uğultu rezonansının gücü."],
	["bass_db", "Susturucu", "Bas", -12.0, 14.0, 3.0, 0.5, "dB", "Kalın ses gövdesi (110 Hz altı)."],
	["hp_hz", "Susturucu", "Kesim (alt)", 15, 250, 35.0, 1, "Hz", "Bunun altındaki pes sesleri at (telefon hoparlörü zaten çalmaz)."],
	["rasp", "Susturucu", "Hırıltı", 0.0, 1.0, 0.15, 0.01, "", "Egzozdan tiz, cızırtılı akış sesi. Spor egzoz / eski araç."],
	["flow_noise", "Susturucu", "Yanma gürültüsü", 0.0, 1.0, 0.15, 0.01, "", "Darbelere bağlı orta frekans gürültü: sesi 'nefes alan' yapar."],
	# --- Emme ---
	["intake_db", "Emme", "Emme düzeyi", -50.0, 0.0, -16.0, 0.5, "dB", "Hava filtresinden emme uğultusu (gazda belirgin)."],
	["intake_hz", "Emme", "Emme tonu", 100, 3000, 450.0, 5, "Hz", "Emme borusunun rezonansı."],
	["intake_q", "Emme", "Emme keskinliği", 0.5, 8.0, 1.5, 0.1, "", "Yüksek = ıslığa yakın emme tonu."],
	# --- Turbo ---
	["turbo", "Turbo", "Turbo", 0.0, 1.0, 0.0, 0.01, "", "Turbonun varlığı ve gücü (0 = yok). Turbo egzozu biraz boğar."],
	["whistle_hz", "Turbo", "Islık perdesi", 600, 10000, 3200.0, 10, "Hz", "Tam basınçta turbo ıslığının tonu."],
	["whistle_db", "Turbo", "Islık düzeyi", -50.0, 0.0, -24.0, 0.5, "dB", "Turbo ıslığının gücü."],
	["spool_rpm", "Turbo", "Turbonun dolduğu devir", 800, 7000, 2300.0, 50, "d/dk", "Bu devrin üstünde basınç gelir."],
	["spool_lag", "Turbo", "Turbo gecikmesi", 0.05, 2.5, 0.6, 0.05, "sn", "Gaza basınca basıncın gelme süresi (eski / büyük turbo uzun)."],
	["blowoff_db", "Turbo", "Blow-off düzeyi", -50.0, 0.0, -14.0, 0.5, "dB", "Gaz kesince basınç boşaltma sesi."],
	["blowoff_kind", "Turbo", "Blow-off türü", 0, 0, "psst", 0, "", "Tıslama (blow-off valf) ya da kesik kesik 'stu-tu-tu' (kompresör geri tepmesi)."],
	# --- Kompresör / şanzıman ---
	["sc_db", "Kompresör", "Kompresör vınlaması", -60.0, 0.0, -60.0, 0.5, "dB", "Mekanik kompresör (supercharger) vınlaması; devirle incelir. -60 = yok."],
	["sc_ratio", "Kompresör", "Kompresör oranı", 1.0, 14.0, 4.0, 0.1, "×", "Vınlamanın devre oranı (yüksek = tiz)."],
	["gear_db", "Kompresör", "Düz dişli vınlaması", -60.0, 0.0, -60.0, 0.5, "dB", "Yarış şanzımanının gazda vınlaması. -60 = yok."],
	["gear_order", "Kompresör", "Dişli oranı", 4.0, 60.0, 22.0, 0.5, "×", "Dişli vınlamasının devre oranı."],
	# --- Mekanik ---
	["valve_db", "Mekanik", "Supap tıkırtısı", -60.0, -6.0, -38.0, 0.5, "dB", "Supap mekanizmasının ince tıkırtısı (eski / havayla soğutmalı motorda belirgin)."],
	["block_db", "Mekanik", "Blok çınlaması", -60.0, 0.0, -26.0, 0.5, "dB", "Motor gövdesinin her yanmada çınlaması: metalik renk."],
	["block_hz", "Mekanik", "Çınlama tonu", 400, 6000, 1800.0, 10, "Hz", "Blok çınlamasının frekansı."],
	["knock_db", "Mekanik", "Dizel tıkırtısı", -60.0, 0.0, -60.0, 0.5, "dB", "Dizelin her yanmadaki sert 'tak'ı (rölantide en belirgin). -60 = yok."],
	# --- Elektrik ---
	["ev_pitch", "Elektrik", "Ton yüksekliği", 0.2, 1.5, 0.45, 0.01, "×", "Devirle yükselen bütün tonların (gövde, vınlama, dişli) ölçeği. Düşük = kalın, tok; yüksek = ince, tiz vınlama."],
	["ev_body_db", "Elektrik", "Motor gövdesi", -60.0, 0.0, -8.0, 0.5, "dB", "Elektrik motorunun kalın uğultusu: sese ağırlık ve 'güç' verir."],
	["ev_drone_db", "Elektrik", "Fütüristik uğultu", -60.0, 0.0, -16.0, 0.5, "dB", "Uzay gemisi gibi akor (Taycan / Togg sürüş sesi gibi). -60 = yok."],
	["ev_drone_hz", "Elektrik", "Uğultu kök tonu", 30, 220, 62.0, 1, "Hz", "Fütüristik uğultunun düşük devirdeki kök tonu (devirle ~3,5 katına çıkar)."],
	["ev_road_db", "Elektrik", "Yol / rüzgâr", -60.0, 0.0, -24.0, 0.5, "dB", "Hızla artan lastik ve rüzgâr uğultusu (elektrikli araçta duyulan asıl ses)."],
	["ev_poles", "Elektrik", "Kutup çifti", 1, 8, 4, 1, "", "Elektrik motorunun kutup çifti: gövde ve vınlamanın devre oranı."],
	["ev_whine_db", "Elektrik", "Motor vınlaması", -60.0, 0.0, -20.0, 0.5, "dB", "Motorun devirle yükselen ince vınlaması."],
	["ev_gear_teeth", "Elektrik", "Redüktör dişi", 4, 60, 11, 1, "", "Redüktör dişli vınlamasının devre oranı (yüksek = tiz)."],
	["ev_gear_db", "Elektrik", "Redüktör vınlaması", -60.0, 0.0, -24.0, 0.5, "dB", "Dişli vınlamasının gücü."],
	["ev_carrier_hz", "Elektrik", "İnvertör tonu", 800, 11000, 3400.0, 10, "Hz", "İnvertörün sabit ince tonu (devirle değişmez)."],
	["ev_carrier_db", "Elektrik", "İnvertör düzeyi", -60.0, 0.0, -44.0, 0.5, "dB", "İnvertör tonunun gücü (gazda artar)."],
	["ev_tone_hz", "Elektrik", "Parlaklık", 400, 10000, 2400.0, 10, "Hz", "Vınlamaların üst sınırı. Düşük = yumuşak, yüksek = keskin."],
	# --- Gaz kesik / patlama ---
	["off_load", "Gaz kesik", "Gaz kesikte yanma", 0.0, 0.5, 0.12, 0.01, "", "Gaz kesikken yanmanın gücü (rölanti de buna göre)."],
	["off_db", "Gaz kesik", "Gaz kesik düzeyi", -24.0, 0.0, -7.0, 0.5, "dB", "Gaz kesik sesin gaza göre kısıklığı."],
	["off_muffle", "Gaz kesik", "Gaz kesik boğukluğu", 0.2, 1.0, 0.6, 0.01, "", "Gaz kesikte susturucu ne kadar kapanır (düşük = daha boğuk)."],
	["crackle", "Gaz kesik", "Patlama sıklığı", 0.0, 1.0, 0.15, 0.01, "", "Gaz kesince egzozdan patlama / çıtırtı. 0 = hiç."],
	["crackle_db", "Gaz kesik", "Patlama düzeyi", -30.0, 6.0, -8.0, 0.5, "dB", "Patlamaların gücü."],
	["pop_tone", "Gaz kesik", "Patlama tınısı", 0.0, 1.0, 0.5, 0.01, "", "Pes 'güm'den tiz 'çat'a."],
	["decel_pops", "Gaz kesik", "İnerken patlama (pat pat)", 0.0, 1.0, 0.0, 0.01, "", "Yüksek devirden gaz kesik inerken ritimli egzoz patlaması: 'pat pat pat'. Değer her vuruşta patlama olasılığı (0 = yok, 1 = her vuruşta)."],
	["pop_interval", "Gaz kesik", "Patlama aralığı", 0.05, 0.4, 0.13, 0.01, "sn", "İnerken patlamaların ritmi: kısa = hızlı 'patpatpat', uzun = tek tek 'pat… pat'."],
	["pop_rpm", "Gaz kesik", "Patlamanın sürdüğü devir", 0.1, 0.9, 0.35, 0.01, "", "Devir bu payın (rölanti 0, kırmızı 1) altına inince patlamalar biter."],
	# --- Devir kesici ---
	["limiter_hz", "Devir kesici", "Kesme hızı", 5.0, 30.0, 14.0, 0.5, "Hz", "Kırmızı çizgide motorun kesip açma hızı."],
	["limiter_duty", "Devir kesici", "Kesik oranı", 0.15, 0.8, 0.45, 0.01, "", "Kesik sürenin payı."],
	# --- Marş ---
	["crank_s", "Marş", "Marş süresi", 0.15, 2.0, 0.6, 0.05, "sn", "Motor çalışana kadar marşın dönme süresi (eski araç uzun)."],
	["crank_rpm", "Marş", "Marş devri", 100, 450, 240.0, 5, "d/dk", "Marşın motoru çevirme hızı."],
	["flare", "Marş", "İlk çalışma sıçraması", 1.0, 3.0, 1.7, 0.05, "× rölanti", "Çalışınca devrin rölantinin kaç katına fırladığı."],
	["starter_db", "Marş", "Marş motoru düzeyi", -50.0, 0.0, -14.0, 0.5, "dB", "Marş motorunun vızıltısı."],
	# --- Karışım ---
	["level_db", "Karışım", "Araç düzeyi", -12.0, 12.0, 0.0, 0.5, "dB", "Bu aracın diğerlerine göre gürlüğü (V8 gür, elektrik kısık)."],
	["rpm_slope_db", "Karışım", "Devirle yükselme", 0.0, 18.0, 8.0, 0.5, "dB", "Rölantiden kırmızı çizgiye ses ne kadar yükselir."],
	["drive", "Karışım", "Son doyum", 0.5, 5.0, 1.4, 0.05, "", "Son katta doyum: yüksek = sıkıştırılmış, sert, agresif."],
	["seed", "Karışım", "Varyasyon tohumu", 0, 999, 0, 1, "", "Rastgele farkların tohumu: aynı ayarla başka bir 'kopya' motor."],
]

## Şablonlar: laboratuvarda "Şablondan başla" ve auto() temeli. Yalnız varsayılandan farklı alanlar.
const TEMPLATES: Dictionary = {
	"Küçük benzinli": {"layout": "i4", "idle_rpm": 850.0, "redline_rpm": 6300.0, "header_len": 0.6, "pipe_len": 2.2,
		"muffler_cut": 1100.0, "chamber_hz": 165.0, "chamber_db": 3.0, "bass_db": 1.0, "rasp": 0.1, "level_db": -2.0},
	"Turbo benzinli": {"layout": "i4", "idle_rpm": 800.0, "redline_rpm": 6500.0, "turbo": 0.6, "whistle_hz": 3600.0,
		"whistle_db": -28.0, "spool_rpm": 1800.0, "spool_lag": 0.45, "blowoff_db": -20.0, "muffler_cut": 1050.0,
		"chamber_hz": 150.0, "bass_db": 3.0, "rasp": 0.08, "flow_noise": 0.12},
	"Dizel": {"layout": "i4", "idle_rpm": 780.0, "redline_rpm": 4600.0, "pulse_deg": 200.0, "sharpness": 0.8,
		"knock_db": -14.0, "turbo": 0.5, "whistle_hz": 2600.0, "whistle_db": -30.0, "spool_rpm": 1700.0, "blowoff_db": -40.0,
		"muffler_cut": 850.0, "chamber_hz": 120.0, "chamber_db": 5.0, "bass_db": 4.0, "rasp": 0.05, "crackle": 0.0,
		"block_db": -18.0, "block_hz": 1300.0, "valve_db": -32.0, "rpm_slope_db": 6.0, "flare": 1.4, "crank_s": 0.5},
	"Dizel kamyonet": {"layout": "i4", "idle_rpm": 720.0, "redline_rpm": 4200.0, "pulse_deg": 210.0, "sharpness": 0.8,
		"knock_db": -12.0, "turbo": 0.6, "whistle_hz": 2300.0, "whistle_db": -28.0, "blowoff_db": -40.0, "header_len": 0.9,
		"pipe_len": 3.6, "muffler_cut": 750.0, "chamber_hz": 95.0, "chamber_db": 6.0, "bass_db": 7.0, "crackle": 0.0,
		"block_db": -16.0, "block_hz": 1100.0, "level_db": 2.0, "rpm_slope_db": 6.0, "flare": 1.3},
	"Eski karbüratörlü": {"layout": "i4", "idle_rpm": 950.0, "redline_rpm": 5800.0, "comb_var": 0.26, "jitter": 0.3,
		"lope": 0.15, "imbalance": 0.16, "muffler_cut": 1700.0, "chamber_hz": 210.0, "chamber_db": 5.0, "rasp": 0.35,
		"flow_noise": 0.3, "valve_db": -27.0, "misfire": 0.15, "crackle": 0.25, "crank_s": 1.1, "crank_rpm": 200.0,
		"intake_db": -12.0, "intake_hz": 380.0, "level_db": 1.0},
	"Sıra 6": {"layout": "i6", "idle_rpm": 750.0, "redline_rpm": 6800.0, "pulse_deg": 235.0, "sharpness": 0.45,
		"header_len": 0.8, "pipe_len": 2.8, "muffler_cut": 1500.0, "chamber_hz": 120.0, "rasp": 0.1, "bass_db": 3.0,
		"imbalance": 0.05},
	"V6": {"layout": "v6_60", "idle_rpm": 720.0, "redline_rpm": 6600.0, "pulse_deg": 230.0, "header_len": 0.75,
		"pipe_len": 2.7, "muffler_cut": 1300.0, "chamber_hz": 125.0, "bass_db": 4.0, "crossover": 0.5},
	"Amerikan V8": {"layout": "v8_cross", "idle_rpm": 700.0, "redline_rpm": 6200.0, "pulse_deg": 240.0, "sharpness": 0.55,
		"lope": 0.35, "comb_var": 0.16, "bank_inter": 0.65, "crossover": 0.15, "bank_offset": 0.15, "header_len": 0.8,
		"pipe_len": 2.8, "pipe_reso": 0.5, "muffler_cut": 900.0, "chamber_hz": 90.0, "chamber_db": 6.0, "bass_db": 7.0,
		"rasp": 0.18, "misfire": 0.2, "crackle": 0.3, "crackle_db": -6.0, "pop_tone": 0.3, "level_db": 4.0,
		"collector_drive": 1.8, "drive": 1.8, "flare": 1.9},
	"Düz krank V8": {"layout": "v8_flat", "idle_rpm": 1000.0, "redline_rpm": 8300.0, "rate": 32000, "pulse_deg": 210.0,
		"sharpness": 0.72, "header_len": 0.55, "header_refl": 0.45, "pipe_len": 1.8, "muffler_cut": 3200.0, "muffler_q": 1.3,
		"chamber_hz": 180.0, "rasp": 0.32, "flow_noise": 0.2, "crackle": 0.45, "pop_tone": 0.65, "level_db": 4.0,
		"block_db": -22.0, "block_hz": 2300.0, "drive": 2.0, "rpm_slope_db": 11.0},
	"V10": {"layout": "v10", "idle_rpm": 1000.0, "redline_rpm": 8500.0, "rate": 32000, "pulse_deg": 215.0,
		"sharpness": 0.68, "header_len": 0.5, "header_refl": 0.45, "pipe_len": 1.9, "muffler_cut": 3600.0, "muffler_q": 1.4,
		"chamber_hz": 200.0, "rasp": 0.26, "crackle": 0.5, "pop_tone": 0.6, "level_db": 4.5, "drive": 2.0,
		"rpm_slope_db": 12.0, "flare": 2.1},
	"V12": {"layout": "v12", "idle_rpm": 950.0, "redline_rpm": 8500.0, "rate": 32000, "pulse_deg": 225.0,
		"sharpness": 0.6, "header_len": 0.55, "pipe_len": 2.0, "muffler_cut": 3000.0, "muffler_q": 1.2, "chamber_hz": 190.0,
		"rasp": 0.2, "crackle": 0.35, "level_db": 4.0, "drive": 1.8, "rpm_slope_db": 12.0},
	"W16 dört turbo": {"layout": "w16", "idle_rpm": 950.0, "redline_rpm": 6700.0, "pulse_deg": 240.0, "sharpness": 0.5,
		"turbo": 1.0, "whistle_hz": 2900.0, "whistle_db": -18.0, "spool_rpm": 2600.0, "spool_lag": 0.7, "blowoff_db": -8.0,
		"blowoff_kind": "flutter", "header_len": 0.7, "pipe_len": 2.2, "muffler_cut": 1300.0, "chamber_hz": 95.0,
		"chamber_db": 6.0, "bass_db": 8.0, "crackle": 0.25, "level_db": 4.0, "drive": 1.6},
	"Boksör 4 (hava soğutmalı)": {"layout": "b4", "idle_rpm": 900.0, "redline_rpm": 5000.0, "header_spread": 0.55,
		"header_len": 0.5, "pipe_len": 1.2, "muffler_cut": 1500.0, "chamber_hz": 230.0, "rasp": 0.3, "valve_db": -24.0,
		"block_db": -20.0, "block_hz": 2600.0, "comb_var": 0.2, "imbalance": 0.12, "crank_s": 0.9, "crackle": 0.15},
	"Boksör 6": {"layout": "b6", "idle_rpm": 900.0, "redline_rpm": 8500.0, "rate": 32000, "pulse_deg": 215.0,
		"sharpness": 0.65, "header_spread": 0.25, "header_len": 0.6, "header_refl": 0.5, "pipe_len": 1.6, "muffler_cut": 3000.0,
		"muffler_q": 1.2, "chamber_hz": 190.0, "rasp": 0.35, "block_db": -18.0, "block_hz": 2400.0, "valve_db": -30.0,
		"crackle": 0.4, "level_db": 3.0, "drive": 1.9, "rpm_slope_db": 11.0},
	"Wankel": {"layout": "r2", "idle_rpm": 1000.0, "redline_rpm": 8200.0, "rate": 32000, "pulse_deg": 260.0,
		"sharpness": 0.9, "lope": 0.55, "comb_var": 0.25, "misfire": 0.3, "header_len": 0.45, "pipe_len": 1.8,
		"muffler_cut": 2600.0, "chamber_hz": 170.0, "rasp": 0.35, "crackle": 0.7, "crackle_db": -4.0, "pop_tone": 0.7,
		"turbo": 0.8, "whistle_hz": 4200.0, "whistle_db": -24.0, "spool_rpm": 3000.0, "blowoff_db": -10.0, "level_db": 3.0,
		"drive": 2.2},
	"Sıra 5": {"layout": "i5", "idle_rpm": 800.0, "redline_rpm": 6800.0, "pulse_deg": 225.0, "header_len": 0.7,
		"pipe_len": 2.4, "muffler_cut": 1500.0, "chamber_hz": 140.0, "imbalance": 0.1, "rasp": 0.18, "bass_db": 3.0},
	"Ralli turbo": {"layout": "i4", "idle_rpm": 950.0, "redline_rpm": 7500.0, "sharpness": 0.7, "turbo": 0.9,
		"whistle_hz": 4400.0, "whistle_db": -20.0, "spool_rpm": 3200.0, "spool_lag": 0.8, "blowoff_db": -6.0,
		"blowoff_kind": "flutter", "muffler_cut": 2600.0, "muffler_q": 1.2, "rasp": 0.35, "crackle": 0.75, "crackle_db": -3.0,
		"pop_tone": 0.75, "misfire": 0.3, "lope": 0.2, "level_db": 3.0, "drive": 2.2, "rpm_slope_db": 11.0},
	"Yüksek devirli atmosferik": {"layout": "i4", "idle_rpm": 950.0, "redline_rpm": 8000.0, "sharpness": 0.7,
		"pulse_deg": 210.0, "header_len": 0.5, "header_refl": 0.5, "muffler_cut": 2400.0, "muffler_q": 1.3,
		"intake_db": -8.0, "intake_hz": 650.0, "intake_q": 2.5, "rasp": 0.28, "crackle": 0.35, "level_db": 2.0,
		"rpm_slope_db": 12.0, "drive": 1.8},
	"İki silindir": {"layout": "i2", "idle_rpm": 950.0, "redline_rpm": 5000.0, "pulse_deg": 230.0, "comb_var": 0.22,
		"header_len": 0.4, "pipe_len": 0.9, "muffler_cut": 1300.0, "chamber_hz": 260.0, "rasp": 0.3, "valve_db": -24.0,
		"block_db": -20.0, "block_hz": 2800.0, "level_db": -2.0, "crank_s": 0.8},
	"Elektrik": {"layout": "ev", "idle_rpm": 0.0, "redline_rpm": 14000.0, "level_db": -4.0, "rpm_slope_db": 10.0},
}

static var _defaults: Dictionary = {}


## Bütün parametrelerin varsayılanları.
static func defaults() -> Dictionary:
	if _defaults.is_empty():
		for row: Array in PARAMS:
			_defaults[row[0]] = row[5]
	return _defaults.duplicate()


## PARAMS satırı (anahtar → satır).
static func param(key: String) -> Array:
	for row: Array in PARAMS:
		if row[0] == key:
			return row
	return []


## Eksik alanları varsayılanla tamamlar, sayısal alanları sınırlar; bilinmeyen alanlar atılır.
static func sanitize(preset: Dictionary) -> Dictionary:
	var out: Dictionary = defaults()
	for row: Array in PARAMS:
		var key: String = row[0]
		if not preset.has(key):
			continue
		var value: Variant = preset[key]
		if key == "rate":
			value = int(value)   # JSON sayıları kayan noktalı okur
		if CHOICES.has(key):
			out[key] = value if _choice_ids(key).has(value) else row[5]
		elif row[5] is int:
			out[key] = clampi(int(value), int(row[3]), int(row[4]))
		else:
			out[key] = clampf(float(value), float(row[3]), float(row[4]))
	return out


static func _choice_ids(key: String) -> Array:
	var ids: Array = []
	for option: Array in CHOICES[key]:
		ids.append(option[0])
	return ids


## Şablon (varsayılan + şablon farkları).
static func from_template(template_name: String) -> Dictionary:
	var out: Dictionary = defaults()
	out.merge(TEMPLATES.get(template_name, {}), true)
	return sanitize(out)


# --- Araç başına ------------------------------------------------------------------------------------------------

static func preset_path(vehicle_id: StringName) -> String:
	return PRESET_DIR + String(vehicle_id) + ".json"


## Laboratuvarda kaydedilmiş (elle ayarlı) ön ayar var mı.
static func has_custom(vehicle_id: StringName) -> bool:
	return FileAccess.file_exists(preset_path(vehicle_id))


## Aracın ön ayarı: kaydedilmiş varsa o, yoksa auto().
static func for_vehicle(vehicle_id: StringName) -> Dictionary:
	if has_custom(vehicle_id):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(preset_path(vehicle_id)))
		if parsed is Dictionary:
			return sanitize(parsed)
	return auto(vehicle_id)


static func save(vehicle_id: StringName, preset: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PRESET_DIR))
	var file: FileAccess = FileAccess.open(preset_path(vehicle_id), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var clean: Dictionary = sanitize(preset)
	var ordered: Dictionary = {}
	for row: Array in PARAMS:   # PARAMS sırasıyla: dosya okunur kalsın, fark (diff) küçük olsun
		ordered[row[0]] = clean[row[0]]
	file.store_string(JSON.stringify(ordered, "\t", false))
	return OK


## Kaydedilmiş ön ayarı siler (araç otomatiğe döner).
static func remove_custom(vehicle_id: StringName) -> void:
	if has_custom(vehicle_id):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(preset_path(vehicle_id)))


# --- Otomatik ön ayar (cars.json'dan) ---------------------------------------------------------------------------

## Motor metninin söylemediği dizilimler ve karakter farkları (araç kimliği → [şablon, farklar]).
const KNOWN: Dictionary = {
	&"bmw_e46": ["Sıra 6", {"redline_rpm": 6500.0}],
	&"bmw_e60": ["Sıra 6", {"redline_rpm": 6500.0, "muffler_cut": 1200.0}],
	&"hyundai_getz": ["Dizel", {"layout": "i3", "level_db": -2.0}],
	&"vw_passat_b55": ["Dizel", {"turbo": 0.6}],
	&"skoda_kamiq": ["Dizel", {"muffler_cut": 800.0, "knock_db": -18.0}],
	&"tofas_sahin": ["Eski karbüratörlü", {"crank_s": 1.3, "rasp": 0.4}],
	&"renault_toros": ["Eski karbüratörlü", {"redline_rpm": 5600.0, "chamber_hz": 230.0}],
	&"volvo_s60": ["Sıra 5", {"turbo": 0.6, "whistle_db": -28.0, "muffler_cut": 1200.0}],
	&"alfa_romeo_159": ["Küçük benzinli", {"redline_rpm": 6600.0, "intake_db": -10.0, "rasp": 0.16, "level_db": 0.0}],
	&"mercedes_cls": ["V6", {"muffler_cut": 1150.0}],
	&"audi_rs6": ["Amerikan V8", {"redline_rpm": 6800.0, "lope": 0.1, "turbo": 0.8, "whistle_db": -26.0,
		"spool_rpm": 2000.0, "muffler_cut": 1300.0, "crackle": 0.55, "bank_inter": 0.45, "blowoff_db": -16.0}],
	&"porsche_gt3": ["Boksör 6", {"redline_rpm": 9000.0}],
	&"lambo_huracan": ["V10", {}],
	&"ferrari_488_pista": ["Düz krank V8", {"redline_rpm": 8000.0, "turbo": 0.7, "whistle_db": -26.0,
		"spool_rpm": 2500.0, "muffler_cut": 2600.0}],
	&"opel_corsa": ["Turbo benzinli", {"layout": "i4", "level_db": -2.0}],
	&"chevrolet_camaro": ["Amerikan V8", {"redline_rpm": 6500.0, "lope": 0.25}],
	&"mercedes_s400": ["V6", {"turbo": 0.6, "whistle_db": -32.0, "muffler_cut": 1000.0, "level_db": -2.0}],
	&"bugatti_chiron": ["W16 dört turbo", {"redline_rpm": 6800.0}],
	&"bugatti_veyron": ["W16 dört turbo", {"redline_rpm": 6400.0, "muffler_cut": 1150.0}],
	&"ferrari_laferrari": ["V12", {"redline_rpm": 9200.0, "sharpness": 0.7, "muffler_cut": 3600.0}],
	&"ford_transit": ["Dizel kamyonet", {}],
	&"mercedes_sprinter": ["Dizel kamyonet", {"layout": "i4", "pipe_len": 3.9}],
	&"mercedes_g": ["Amerikan V8", {"redline_rpm": 6500.0, "lope": 0.08, "turbo": 0.7, "whistle_db": -30.0,
		"crackle": 0.5, "muffler_cut": 1250.0, "bank_inter": 0.5}],
	&"police_vito": ["Dizel kamyonet", {"level_db": 0.0}],
	&"police_bentley": ["W16 dört turbo", {"layout": "w12", "redline_rpm": 6200.0, "blowoff_kind": "psst",
		"whistle_db": -26.0}],
	&"tofas_murat_124": ["Eski karbüratörlü", {"redline_rpm": 5600.0, "chamber_hz": 240.0, "crank_s": 1.3}],
	&"anadol_a1": ["Eski karbüratörlü", {"redline_rpm": 5400.0, "chamber_hz": 250.0, "rasp": 0.42, "crank_s": 1.4}],
	&"vw_beetle_1967": ["Boksör 4 (hava soğutmalı)", {}],
	&"fiat_500_1965": ["İki silindir", {}],
	&"tofas_murat_131": ["Eski karbüratörlü", {"redline_rpm": 5800.0}],
	&"mini_cooper_1965": ["Eski karbüratörlü", {"redline_rpm": 6200.0, "chamber_hz": 260.0, "level_db": -1.0}],
	&"willys_jeep_mb": ["Eski karbüratörlü", {"redline_rpm": 4200.0, "idle_rpm": 650.0, "chamber_hz": 120.0,
		"bass_db": 5.0, "pulse_deg": 240.0, "lope": 0.2, "crank_s": 1.5, "crank_rpm": 170.0}],
	&"peugeot_404": ["Eski karbüratörlü", {"redline_rpm": 5600.0}],
	&"mercedes_w123": ["Dizel", {"layout": "i4", "redline_rpm": 4400.0, "turbo": 0.0, "knock_db": -9.0,
		"crank_s": 1.5, "crank_rpm": 180.0, "flare": 1.25}],
	&"vw_t1_bus": ["Boksör 4 (hava soğutmalı)", {"redline_rpm": 4600.0, "pipe_len": 1.5, "bass_db": 3.0}],
	&"land_rover_series3": ["Eski karbüratörlü", {"redline_rpm": 4500.0, "idle_rpm": 700.0, "chamber_hz": 130.0,
		"bass_db": 4.0, "crank_s": 1.4}],
	&"chevrolet_bel_air_1956": ["Amerikan V8", {"redline_rpm": 5200.0, "muffler_cut": 750.0, "lope": 0.3,
		"rasp": 0.25, "crank_s": 1.2, "level_db": 3.0}],
	&"ford_mustang_1967": ["Amerikan V8", {"redline_rpm": 5800.0, "lope": 0.45, "rasp": 0.25, "crank_s": 1.0}],
	&"chevrolet_corvette_c2": ["Amerikan V8", {"redline_rpm": 6300.0, "lope": 0.5, "muffler_cut": 1200.0,
		"rasp": 0.25}],
	&"jaguar_e_type": ["Sıra 6", {"redline_rpm": 5800.0, "rasp": 0.25, "muffler_cut": 1700.0, "comb_var": 0.18,
		"crank_s": 1.0}],
	&"aston_martin_db5": ["Sıra 6", {"redline_rpm": 5900.0, "rasp": 0.28, "muffler_cut": 1800.0, "comb_var": 0.18,
		"level_db": 2.0, "crank_s": 1.0}],
	&"dodge_charger_1970": ["Amerikan V8", {"redline_rpm": 5400.0, "lope": 0.5, "bass_db": 9.0, "chamber_hz": 80.0,
		"level_db": 5.0, "crank_s": 1.1}],
	&"porsche_911_1973": ["Boksör 6", {"redline_rpm": 7200.0, "rate": 24000, "muffler_cut": 2200.0, "rasp": 0.4,
		"valve_db": -24.0, "comb_var": 0.18, "crank_s": 0.9}],
	&"mercedes_300sl": ["Sıra 6", {"redline_rpm": 6300.0, "rasp": 0.24, "muffler_cut": 1700.0, "crank_s": 1.0}],
	&"lamborghini_miura": ["V12", {"redline_rpm": 7700.0, "rate": 24000, "rasp": 0.35, "comb_var": 0.18,
		"intake_db": -6.0, "intake_hz": 700.0, "crank_s": 1.0}],
	&"ford_escort_rs1600": ["Yüksek devirli atmosferik", {"redline_rpm": 8000.0, "comb_var": 0.2}],
	&"lancia_stratos": ["V6", {"layout": "v6_60", "redline_rpm": 7800.0, "muffler_cut": 2600.0, "rasp": 0.35,
		"sharpness": 0.65, "crackle": 0.5, "level_db": 3.0, "intake_db": -8.0}],
	&"bmw_m3_e30": ["Yüksek devirli atmosferik", {"redline_rpm": 7250.0, "intake_db": -6.0}],
	&"toyota_celica_gt4": ["Ralli turbo", {"crackle": 0.6}],
	&"lancia_delta_integrale": ["Ralli turbo", {"whistle_hz": 3900.0}],
	&"audi_quattro_s1": ["Ralli turbo", {"layout": "i5", "redline_rpm": 7800.0, "whistle_hz": 3600.0, "crackle": 0.85}],
	&"ford_rs200": ["Ralli turbo", {"redline_rpm": 8000.0, "whistle_hz": 4600.0}],
	&"mitsubishi_evo6": ["Ralli turbo", {"redline_rpm": 7500.0, "lope": 0.1}],
	# 2026-11-02 kullanıcı: "Supra'da egzoz patlatma sesi olsun, pat pat pat diye yüksek devirden inerken"
	&"toyota_supra": ["Sıra 6", {"redline_rpm": 6800.0, "turbo": 0.85, "whistle_hz": 3300.0, "whistle_db": -20.0,
		"spool_rpm": 3000.0, "blowoff_db": -8.0, "muffler_cut": 2000.0, "rasp": 0.2, "crackle": 0.55, "crackle_db": -2.0,
		"pop_tone": 0.42, "misfire": 0.3, "decel_pops": 0.88, "pop_interval": 0.12, "pop_rpm": 0.28, "level_db": 2.0}],
	&"nissan_skyline_r34": ["Sıra 6", {"redline_rpm": 8000.0, "turbo": 0.85, "whistle_hz": 3900.0, "whistle_db": -20.0,
		"spool_rpm": 3200.0, "blowoff_db": -8.0, "blowoff_kind": "flutter", "muffler_cut": 2200.0, "rasp": 0.24,
		"sharpness": 0.6, "crackle": 0.45, "level_db": 2.0}],
	&"honda_nsx": ["V6", {"redline_rpm": 8000.0, "rate": 32000, "sharpness": 0.65, "muffler_cut": 2400.0,
		"intake_db": -7.0, "intake_hz": 620.0, "intake_q": 2.5, "rasp": 0.22, "level_db": 2.0, "rpm_slope_db": 12.0}],
	&"mazda_rx7": ["Wankel", {}],
	&"toyota_ae86": ["Yüksek devirli atmosferik", {"redline_rpm": 7600.0, "muffler_cut": 2000.0}],
	# Taycan: "Porsche Electric Sport Sound" gibi kalın fütüristik akor + sportif vınlama
	&"porsche_taycan": ["Elektrik", {"redline_rpm": 16000.0, "ev_drone_db": -9.0, "ev_drone_hz": 52.0, "ev_body_db": -6.0,
		"ev_whine_db": -17.0, "ev_gear_teeth": 9, "ev_tone_hz": 3000.0, "level_db": 0.0}],
	# Tesla: akor yok, temiz yükselen vınlama + belirgin yol sesi
	&"tesla_model_y": ["Elektrik", {"ev_drone_db": -60.0, "ev_whine_db": -16.0, "ev_gear_teeth": 12, "ev_road_db": -18.0,
		"ev_carrier_hz": 3100.0}],
	&"togg_t10x": ["Elektrik", {"ev_drone_db": -14.0, "ev_drone_hz": 66.0, "ev_poles": 3, "ev_gear_teeth": 10}],
	&"togg_t10f": ["Elektrik", {"ev_drone_db": -13.0, "ev_drone_hz": 70.0, "ev_poles": 3, "ev_gear_teeth": 10, "level_db": -3.0}],
	# Corolla hibrit: kısık, yumuşak; akor yok
	&"toyota_corolla": ["Elektrik", {"ev_drone_db": -60.0, "ev_pitch": 0.38, "ev_whine_db": -24.0, "ev_body_db": -10.0,
		"ev_tone_hz": 1800.0, "level_db": -5.0}],
}

## Sabit aralıklarla oynanan alanlar (araca özgü fark; kimlikten türetilen tohumla): [alan, ± oran].
const JITTER_FIELDS: Array = [
	["header_len", 0.12], ["pipe_len", 0.14], ["chamber_hz", 0.14], ["muffler_cut", 0.1], ["intake_hz", 0.15],
	["block_hz", 0.15], ["whistle_hz", 0.08],
]


## cars.json'dan otomatik ön ayar: motor metni (dizilim, hacim, turbo / dizel / elektrik), yıl ve kategori → şablon;
## KNOWN'daki araçlarda elle seçilmiş şablon + farklar; hacim tını kaydırır; araca özgü tohumla küçük farklar.
static func auto(vehicle_id: StringName) -> Dictionary:
	var entry: Dictionary = CarCatalog.get_entry(vehicle_id)
	var performance: Variant = entry.get("performance", {})
	var engine: String = String((performance as Dictionary).get("engine", "")).to_upper() if performance is Dictionary else ""
	var year: int = int(entry.get("year", 2010))
	var category: String = String(entry.get("category", ""))
	var litres: float = 1.6
	var number: RegExMatch = RegEx.create_from_string("(\\d+(?:\\.\\d+)?)").search(engine)
	if number:
		litres = float(number.get_string(1))
	var template: String = _template_for(engine, litres, year, category)
	var extra: Dictionary = {}
	if KNOWN.has(vehicle_id):
		template = String(KNOWN[vehicle_id][0])
		extra = KNOWN[vehicle_id][1]
	var out: Dictionary = from_template(template)
	if out["layout"] != "ev":
		# Hacim: büyük motor daha pes uğultu, daha çok bas, daha uzun boru
		var size: float = clampf(litres / 2.0, 0.3, 4.0)
		out["chamber_hz"] = float(out["chamber_hz"]) * pow(size, -0.25)
		out["bass_db"] = float(out["bass_db"]) + 2.0 * log(size) / log(2.0)
		out["pipe_len"] = float(out["pipe_len"]) * pow(size, 0.15)
		if year < 1985:
			out["comb_var"] = float(out["comb_var"]) + 0.05
			out["valve_db"] = float(out["valve_db"]) + 4.0
	out.merge(extra, true)
	var seed_value: int = absi(hash(String(vehicle_id))) % 1000
	out["seed"] = seed_value
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	for field: Array in JITTER_FIELDS:
		out[field[0]] = float(out[field[0]]) * (1.0 + rng.randf_range(-1.0, 1.0) * float(field[1]))
	return sanitize(out)


static func _template_for(engine: String, litres: float, year: int, category: String) -> String:
	if engine.contains("ELEKTR") or engine.contains("HİBRİT") or engine.contains("HIBRIT"):
		return "Elektrik"
	for token: String in ["TDI", "CDI", "CRDI", "DİZEL", "DIZEL", "ECOBLUE", "JTD", "DCI", "HDI"]:
		if engine.contains(token):
			return "Dizel kamyonet" if category == "van" else "Dizel"
	if engine.contains("W16"):
		return "W16 dört turbo"
	if engine.contains("V12") or engine.contains("W12"):
		return "V12"
	if engine.contains("V10"):
		return "V10"
	if engine.contains("V8") or litres >= 5.0:
		return "Amerikan V8"
	if engine.contains("V6"):
		return "V6"
	if litres >= 2.8:
		return "Sıra 6"
	if engine.contains("WANKEL"):
		return "Wankel"
	if year < 1990:
		return "Eski karbüratörlü"
	for token: String in ["TURBO", "TSI", "TFSI", "TGDI", "TCE", "2.5T"]:
		if engine.contains(token):
			return "Turbo benzinli"
	return "Küçük benzinli"
