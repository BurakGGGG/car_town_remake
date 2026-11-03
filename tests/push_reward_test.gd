extends SceneTree
## BİLDİRİM ÖNERİSİ v2 + 20 GEM TESTİ (2026-11-04): öneri sürümü (eski öneriyi görmüş oyuncuya bir kez daha), telefon
## izni sonradan kapatılmışsa "açık değil" sayılması, Android izin penceresi çıkmayınca telefonun bildirim ayarı + dönüşte
## yeniden deneme, yavaş ret (pencere çıktı, oyuncu reddetti), ödül (bir kez, yalnız bildirim fiilen açıkken, kayıtta),
## öneri ekranı (ödül etiketi, düğmeler, sığma, telemetri).
## Çalıştırma: tools/run_tests.sh push_reward_test
var fails: int = 0
var settings_opened: int = 0
var permission_answer: bool = true
var permission_delay: float = 0.0

func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond: fails += 1

func frames(n: int) -> void:
	for i: int in n: await process_frame

func _init() -> void: _run()

func _ask() -> bool:
	if permission_delay > 0.0:
		await create_timer(permission_delay).timeout
	else:
		await process_frame
	return permission_answer

func _open_settings() -> bool:
	settings_opened += 1
	return true

func _run() -> void:
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PushService.FILE))
	var progress: PlayerProgress = PlayerProgress.new()
	root.add_child(progress)
	root.add_child(Telemetry.new())   # olaylar Telemetry.recorded'a düşsün (masaüstü)
	var community: CommunityLinks = CommunityLinks.new()
	root.add_child(community)
	var push: PushService = PushService.new()
	root.add_child(push)
	await frames(2)
	PushService.force_available = true
	push.permission_asker = _ask
	push.settings_opener = _open_settings

	print("== 1) Öneri sürümü ==")
	push._state = {}
	check(push.should_ask() and not push.wants_reask(), "yeni oyuncu: sorulur, 'yeniden' değil (ilk yarışı bekler)")
	push.mark_asked()
	check(not push.should_ask() and int(push._state.get("asked_v", 0)) == PushService.ASK_VERSION, "gösterildi: bu sürüm bir daha sorulmaz")
	push._state = {"asked": true}
	check(push.should_ask() and push.wants_reask(), "eski öneriyi görmüş, bildirimi kapalı: güncellemeden sonra yeniden")
	push._state = {"asked": true, "enabled": true}
	check(not push.should_ask(), "eski sürümde açmış: sorulmaz")
	PushService.os_allows_override = 0
	check(not push.is_active() and push.should_ask(), "telefondan kapatmış: açık sayılmaz, yeniden sorulur")
	PushService.os_allows_override = -1
	push._state = {"asked": true, "asked_v": 2}
	check(not push.should_ask(), "yeni sürümü görmüş (ŞİMDİ DEĞİL): sorulmaz")

	print("== 2) Android pencere göstermedi → telefonun bildirim ayarı, dönüşte yeniden ==")
	push._state = {"asked": true}
	permission_answer = false
	permission_delay = 0.0
	var ok: bool = await push.enable()
	check(not ok and settings_opened == 1 and push._settings_pending, "hızlı ret: ayar açıldı, dönüş bekleniyor")
	check(push.last_failure.is_empty(), "hata yazısı yok (oyuncu ayarda)")
	check(not push.should_ask(), "soruldu sayılır")
	PushService.os_allows_override = 0
	push._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await frames(3)
	check(not push.is_enabled() and not push._settings_pending, "ayarda açmadan döndü: kapalı kaldı")
	permission_answer = false
	await push.enable()
	check(settings_opened == 2, "yeniden AÇ: ayar yeniden açıldı")
	PushService.os_allows_override = 1
	permission_answer = true
	push._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await create_timer(0.5).timeout
	check(push.is_enabled() and push.is_active(), "ayarda açıp döndü: bildirim açıldı (jeton)")
	PushService.os_allows_override = -1

	print("== 3) Yavaş ret: pencere çıktı, oyuncu reddetti ==")
	await push.disable()
	permission_answer = false
	permission_delay = 0.8
	var opened_before: int = settings_opened
	ok = await push.enable()
	check(not ok and settings_opened == opened_before and not push.last_failure.is_empty(), "ayar açılmadı, neden yazıldı")
	permission_delay = 0.0

	print("== 4) Telefon izin veriyor ama bildirimler telefondan kapalı (izin penceresi çıkmaz) ==")
	permission_answer = true
	PushService.os_allows_override = 0
	opened_before = settings_opened
	ok = await push.enable()
	check(not ok and settings_opened == opened_before + 1, "telefonun bildirim ayarı açıldı")
	PushService.os_allows_override = -1
	push._settings_pending = false

	print("== 5) Ödül: bir kez, yalnız bildirim fiilen açıkken ==")
	await push.disable()
	progress.load_state(5, 0, 100)
	check(community.push_reward_open() and community.claim_push_reward() == 0 and progress.gems == 100, "kapalıyken ödül yok")
	permission_answer = true
	check(await push.enable() and push.is_active(), "açıldı")
	PushService.os_allows_override = 0
	check(community.claim_push_reward() == 0, "telefondan kapalıyken ödül yok")
	PushService.os_allows_override = -1
	check(community.claim_push_reward() == CommunityLinks.PUSH_GEMS and progress.gems == 100 + CommunityLinks.PUSH_GEMS, "+20 gem")
	check(not community.push_reward_open() and community.claim_push_reward() == 0 and progress.gems == 120, "ikinci kez yok")
	for i: int in 3:   # sürekli kapatıp açan oyuncu: ödül yeniden doğmaz
		await push.disable()
		check(await push.enable() and push.is_active(), "kapat / aç %d" % (i + 1))
		check(community.claim_push_reward() == 0 and progress.gems == 120, "kapat / aç %d: gem yok (%d)" % [i + 1, progress.gems])
	var saved: Dictionary = community.state()
	check(saved.get("push") == true, "kayıtta: push alındı")
	community.load_state({})
	check(community.push_reward_open(), "yeni kayıt: ödül açık")
	community.load_state(saved)
	check(not community.push_reward_open(), "kayıttan geri: alınmış")
	community.load_state({})

	print("== 6) Öneri ekranı ==")
	Telemetry.recorded.clear()
	push._state = {"asked": true}
	var prompt: PushPrompt = PushPrompt.new()
	prompt.theme = load("res://ui/theme/hud_theme.tres") as Theme   # oyunda Hud'dan miras alır
	root.add_child(prompt)
	await frames(2)
	prompt.open()
	await create_timer(0.5).timeout
	check(prompt.visible and prompt._pill.visible, "ödül etiketi görünür (ödül alınmamış)")
	check(prompt._pill_amount.text.contains(str(CommunityLinks.PUSH_GEMS)), "etiket: %s" % prompt._pill_amount.text)
	check(prompt._ok.kind == HudIcon.Kind.BELL and not prompt._ok.text.is_empty(), "AÇ düğmesi zilli: %s" % prompt._ok.text)
	check(not push.should_ask(), "gösterilince soruldu sayıldı")
	var shown: Array = Telemetry.recorded.filter(func(e: Dictionary) -> bool: return e.get("name") == "push_prompt_show")
	check(shown.size() == 1 and int((shown[0].get("params", {}) as Dictionary).get("reask", 0)) == 1, "telemetri: yeniden soruldu (bool → 1)")
	var card: Vector2 = prompt._root.get_combined_minimum_size()
	check(card.x <= 853.0 - 24.0 and card.y <= 480.0 - 16.0, "en dar ekrana sığar: %s" % card)
	check(prompt._notes.size() == 3, "üç örnek bildirim")
	await create_timer(1.8).timeout
	check(prompt._notes[0].modulate.a > 0.9, "örnek bildirimler beliriyor")
	prompt._later.pressed.emit()
	await create_timer(0.4).timeout
	check(not prompt.visible, "ŞİMDİ DEĞİL: kapandı")
	community.load_state({"push": true})
	push._state = {}
	prompt.open()
	await frames(2)
	check(not prompt._pill.visible, "ödül alınmışsa etiket yok")
	prompt.close()
	await create_timer(0.3).timeout

	PushService.force_available = false
	PushService.os_allows_override = -1
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PushService.FILE))
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
