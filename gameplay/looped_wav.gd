class_name LoopedWav
extends RefCounted
## KODLA ÜRETİLEN DÖNGÜLÜ SESİN İLERİ DÖNGÜSÜ (2026-10-28, çökme düzeltmesi). Godot 4.7'de AudioStreamWAV döngüde
## loop_end karesini de çalar (_mix_internal sınırı dahil) ve verinin arkasına pay bırakmaz: loop_end = kare sayısı
## verilince karıştırıcı verinin BİR KARE dışını okur. Android'in bellek ayırıcısı (Scudo) büyük tamponu koruma
## sayfasının hemen önüne koyar → ses iş parçacığında SIGSEGV (Crashlytics 1.1.2–1.1.3: libwilhelm →
## AudioStreamPlaybackWAV::_mix_internal, hata adresi sayfa başı). Masaüstünde okunan tek kare çöptür, fark edilmez.
## Çözüm: sona ilk karenin kopyası eklenir, loop_end eski kare sayısı kalır → çalınan sıra …, son, ilk (kopya), 1, 2, …
## (dikişsiz) ve okuma hep verinin içinde.


## `wav` 16 bitlik, verisi tam döngü (son kareden ilk kareye kesintisiz) olmalı. Döngüyü ileri yapar.
static func loop_forward(wav: AudioStreamWAV) -> void:
	var frame_bytes: int = 4 if wav.stereo else 2
	var data: PackedByteArray = wav.data
	var frames: int = data.size() / frame_bytes
	data.append_array(data.slice(0, frame_bytes))
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = frames
