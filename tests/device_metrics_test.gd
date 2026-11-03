extends SceneTree
## CİHAZ METRİKLERİ TESTİ (DeviceMetrics): Android olmadan — force_enabled + sahte transport.
## Kimlik özeti, oturumun süreçte bir kez sayılması, anlık alanlar, sayaç farkı sözleşmesi (uçuştaki gönderim aynı seq ve
## farklarla yeniden gider, yeni farklar sonrakini bekler), sunucu reddi, satın alma / reklam sayaçları, oyun süresi
## küsuratı, dosyadan devam, rıza kapanınca silme isteği ve sıfırlama.
## Çalıştırma: tools/run_tests.sh device_metrics_test
var fails: int = 0
var calls: Array[Dictionary] = []
var reply: Dictionary = {"ok": true, "applied": "update"}

func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond: fails += 1

func frames(n: int) -> void:
	for i: int in n: await process_frame

func _init() -> void: _run()

func _transport(data: Dictionary) -> Dictionary:
	calls.append(data.duplicate(true))
	await process_frame
	return reply

func _make(settings: GameSettings) -> DeviceMetrics:
	var m: DeviceMetrics = DeviceMetrics.new()
	m.device_override = "test-phone"
	m.transport = _transport
	root.add_child(m)
	await frames(2)
	m._timer.paused = true   # zamanlayıcı kendiliğinden göndermesin: test gönderimi elle tetikler
	return m

func _run() -> void:
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DeviceMetrics.FILE))
	DeviceMetrics.force_enabled = true
	var settings: GameSettings = GameSettings.new()
	settings.reload_on_language_change = false
	root.add_child(settings)
	settings.set_analytics_enabled(true)
	await frames(1)

	print("== 1) Kimlik ==")
	var m: DeviceMetrics = await _make(settings)
	var id: String = m.device_id()
	check(id.length() == 64 and id == id.to_lower() and id.is_valid_hex_number(), "64 onaltılık özet")
	var ref: ReferralManager = ReferralManager.new()
	ref.device_override = "test-phone"
	check(ref.device_hash() != id, "davet özetinden ayrı tuz (iki kayıt bağlanamaz)")
	ref.free()
	var other: DeviceMetrics = DeviceMetrics.new()
	other.device_override = "test-phone"
	check(other.device_id() == id, "aynı telefon aynı kimlik")
	other.free()

	print("== 2) İlk gönderim ==")
	check(int(m.pending().get("sess", 0)) == 1, "açılış sayıldı")
	await m._send()
	check(calls.size() == 1, "bir gönderim")
	var first: Dictionary = calls[-1]
	check(first.get("dev") == id and String(first.get("inst", "")).length() == 32, "dev + inst")
	check(int(first.get("seq", 0)) == 1, "seq 1")
	check(int((first.get("d", {}) as Dictionary).get("sess", 0)) == 1, "fark: sess 1")
	check(not first.has("uid"), "UID gönderilmez")
	for key: String in ["acct", "lang", "model", "build", "sdk", "level", "money", "gems", "cars", "garages", "tut", "push",
			"push_os", "push_asked", "push_race", "push_gift", "push_news"]:
		if not first.has(key):
			check(false, "anlık alan var: " + key)
	check(first.get("acct") == "guest", "oturumsuz = misafir")
	check(DeviceMetrics.LANGS.has(String(first.get("lang"))), "dil sunucunun kabul ettiği beşten biri")
	check(first.get("push") == false and first.get("push_os") == true, "bildirim yok (masaüstü: telefon izni var sayılır)")
	check(m.pending().get("sess", 0.0) == 0.0, "gönderilen fark bekleyenden düştü")

	print("== 3) Oturum süreçte bir kez sayılır ==")
	m.queue_free()
	await frames(2)
	m = await _make(settings)
	check(float(m.pending().get("sess", 0.0)) == 0.0, "sahne yeniden kurulunca yeni açılış sayılmadı")

	print("== 4) Ağ yoksa uçuştaki gönderim aynı seq + aynı farkla yeniden gider ==")
	m._play_acc = 42.7
	m._on_ad_finished(&"repair_skip", true)
	m._on_ad_finished(&"repair_skip", false)
	reply = {"error": "network"}
	await m._send()
	var lost: Dictionary = calls[-1]
	check(int(lost.get("seq", 0)) == 2, "seq 2")
	var d: Dictionary = lost.get("d", {})
	check(int(d.get("play_s", 0)) == 42 and int(d.get("ads", 0)) == 1, "fark: 42 sn + 1 ödüllü reklam (ödülsüz sayılmadı)")
	var rest: float = float(m.pending().get("play_s", 0.0))
	check(rest >= 0.69 and rest < 1.0, "küsurat sonraki gönderime kaldı (%.2f)" % rest)
	m._on_gems_purchased(&"starter_pack", 400)
	reply = {"ok": true, "applied": "snapshot"}
	await m._send()
	var retry: Dictionary = calls[-1]
	check(int(retry.get("seq", 0)) == 2 and retry.get("d") == d, "yeniden gönderim: aynı seq, aynı fark")
	check(not (retry.get("d", {}) as Dictionary).has("iap"), "aradaki satın alma bu gönderime girmedi")
	await m._send()
	var next: Dictionary = calls[-1]
	check(int(next.get("seq", 0)) == 3, "onaydan sonra seq 3")
	check(int((next.get("d", {}) as Dictionary).get("iap", 0)) == 1, "satın alma sayıldı")
	check(int((next.get("d", {}) as Dictionary).get("iap_usd_c", 0)) == 199, "liste fiyatı 199 sent")

	print("== 5) Dosyadan devam: kapanmadan önce uçuşta kalan gönderim ==")
	m._on_ad_finished(&"race_double", true)
	reply = {"error": "network"}
	await m._send()
	var pending_seq: int = int(calls[-1].get("seq", 0))
	m.queue_free()
	await frames(2)
	m = await _make(settings)
	reply = {"ok": true, "applied": "snapshot"}
	await m._send()
	check(int(calls[-1].get("seq", 0)) == pending_seq and int((calls[-1].get("d", {}) as Dictionary).get("ads", 0)) == 1,
		"yeni düğüm aynı seq + farkı yeniden yolladı")

	print("== 6) Sunucu gövdeyi reddederse uçuştaki fark atılır (döngü yok) ==")
	m._on_ad_finished(&"race_double", true)
	reply = {"error": "bad_lang"}
	await m._send()
	reply = {"ok": true}
	await m._send()
	check(not (calls[-1].get("d", {}) as Dictionary).has("ads"), "reddedilen fark yeniden gönderilmedi")
	check(int(calls[-1].get("seq", 0)) == int(calls[-2].get("seq", 0)) + 1, "yeni seq ile devam")

	print("== 7) Rıza kapanınca: birikmez, silme isteği, sıfırlama ==")
	var inst_before: String = String(calls[-1].get("inst", ""))
	m._on_ad_finished(&"race_double", true)
	settings.set_analytics_enabled(false)
	await frames(1)
	check(m.pending().is_empty(), "bekleyen sayaçlar atıldı")
	m._on_ad_finished(&"race_double", true)
	m._play_acc = 0.0
	m._process(0.5)
	check(m.pending().is_empty() and m._play_acc == 0.0, "rıza yokken reklam / süre birikmedi")
	await m._send()
	check(calls[-1].get("forget") == true and calls[-1].get("dev") == id and calls[-1].size() == 2,
		"yalnız {dev, forget} gönderildi")
	var count: int = calls.size()
	await m._send()
	check(calls.size() == count, "silindikten sonra bir şey gönderilmez")
	settings.set_analytics_enabled(true)
	await frames(1)
	await m._send()
	check(String(calls[-1].get("inst", "")) != inst_before and int(calls[-1].get("seq", 0)) == 1,
		"rıza geri gelince yeni inst, seq 1")

	print("== 8) Android dışında (force yok) gönderilmez ==")
	DeviceMetrics.force_enabled = false
	count = calls.size()
	await m._send()
	check(calls.size() == count, "masaüstünde gönderim yok")

	m.queue_free()
	settings.set_analytics_enabled(true)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DeviceMetrics.FILE))
	await frames(2)
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
