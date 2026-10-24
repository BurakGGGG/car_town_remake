extends SceneTree
## TOPLULUK BAĞLANTILARI (CommunityLinks) — MARKET › ÜCRETSİZ takip ödülleri (Instagram / TikTok, +10 gem, bir kez;
## bağlantı açılmadan alınmaz), GemRewards'ın farklı oyun günü sayacı (seri bozulunca sıfırlanmaz, saat geri alınınca
## artmaz), BİZİ DEĞERLENDİR zamanlaması (3. gün, SONRA → 4 gün sonra, en çok 2 kez, DEĞERLENDİR → bir daha yok; gem
## YOK), kayıt gidiş-dönüşü, MARKET kartları ve HUD'un pencereyi sakin anda açması. Bağlantılar açılmaz (opener sahte).
## Gerçek düğümlerle koşar (Main.tscn).
##   tools/run_tests.sh community_links_test

const DAY: int = 86400
const BASE: int = 1_790_000_000   # sabit bir gün başı (test saati)

var fails: int = 0
var hud: Hud
var player: PlayerProgress
var rewards: GemRewards
var community: CommunityLinks
var opened: Array[String] = []


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _initialize() -> void:
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(12)
	hud = main.find_child("HUD", true, false) as Hud
	player = get_first_node_in_group("player_progress")
	rewards = get_first_node_in_group("gem_rewards")
	community = get_first_node_in_group("community")
	check(community != null, "CommunityLinks kuruldu (\"community\" grubu)")
	if community == null:
		print("SONUC: fails=%d" % fails)
		quit(1)
		return
	community.opener = func(url: String) -> void: opened.append(url)
	_play_days()
	_follow()
	_rating()
	_save_roundtrip()
	await _market()
	await _prompt()
	print("SONUC: fails=%d" % fails)
	quit(1 if fails > 0 else 0)


func _play_days() -> void:
	print("== 1) Farklı oyun günü sayacı ==")
	rewards.load_state({})
	rewards.test_now = BASE
	rewards.check_day()
	check(rewards.play_days() == 1, "ilk giriş: 1 gün")
	rewards.test_now = BASE + 3600
	rewards.check_day()
	check(rewards.play_days() == 1, "aynı gün yeniden: yine 1")
	rewards.test_now = BASE + DAY
	rewards.check_day()
	check(rewards.play_days() == 2, "ertesi gün: 2")
	rewards.test_now = BASE + DAY * 5
	rewards.check_day()
	check(rewards.play_days() == 3 and rewards.streak() == 1, "3 gün ara verip gelince: 3 (seri 1'e döndü, sayaç sürer)")
	rewards.test_now = BASE + DAY * 2
	rewards.check_day()
	check(rewards.play_days() == 3, "saat geri alındı: artmaz")
	var saved: Dictionary = rewards.state()
	rewards.load_state({})
	check(rewards.play_days() == 0, "boş kayıt: 0")
	rewards.load_state(saved)
	check(rewards.play_days() == 3, "kayıttan geri geldi (login.days)")


func _follow() -> void:
	print("== 2) Takip ödülü ==")
	community.reset()
	opened.clear()
	player.load_state(1, 0, 0)
	check(community.unclaimed() == CommunityLinks.LINKS.size(), "başta hepsi alınmamış (%d)" % community.unclaimed())
	check(community.claim(&"instagram") == 0 and player.gems == 0, "bağlantı açılmadan ödül alınmaz")
	community.open_link(&"instagram")
	check(opened == ["https://www.instagram.com/autoyardgame"], "TAKİP ET Instagram hesabını açar")
	check(community.follow_state(&"instagram") == CommunityLinks.Follow.OPENED, "durum: açıldı")
	check(community.claim(&"instagram") == CommunityLinks.FOLLOW_GEMS and player.gems == 10, "ÖDÜLÜ AL: +10 gem")
	check(community.follow_state(&"instagram") == CommunityLinks.Follow.CLAIMED, "durum: alındı")
	check(community.claim(&"instagram") == 0 and player.gems == 10, "ikinci kez verilmez")
	community.open_link(&"instagram")
	check(opened.size() == 2 and community.follow_state(&"instagram") == CommunityLinks.Follow.CLAIMED,
		"alındıktan sonra da bağlantı açılır, durum geri dönmez")
	check(community.unclaimed() == 1, "bir kart kaldı")
	community.open_link(&"tiktok")
	check(opened[-1] == "https://www.tiktok.com/@autoyardgame", "TikTok hesabını açar")
	check(community.claim(&"tiktok") == 10 and player.gems == 20 and community.unclaimed() == 0, "TikTok: +10 gem, hepsi alındı")
	community.open_link(&"facebook")
	check(opened.size() == 3, "bilinmeyen ağ: hiçbir şey açılmaz")


func _rating() -> void:
	print("== 3) Değerlendirme zamanlaması ==")
	community.reset()
	opened.clear()
	var gems: int = player.gems
	check(not community.wants_rating(1) and not community.wants_rating(2), "1. ve 2. günde sorulmaz")
	check(community.wants_rating(CommunityLinks.RATE_FIRST_DAY), "3. günde sorulur")
	community.mark_rating_asked(3)
	check(not community.wants_rating(3) and not community.wants_rating(6), "SONRA: aynı gün ve 3 gün sonra sorulmaz")
	check(community.wants_rating(3 + CommunityLinks.RATE_RETRY_DAYS), "SONRA: 4 oyun günü sonra yeniden")
	community.mark_rating_asked(7)
	check(not community.wants_rating(100), "en çok 2 kez sorulur")
	community.reset()
	community.rate_now()
	check(community.is_rated() and not community.wants_rating(50), "DEĞERLENDİR: bir daha sorulmaz")
	check(opened.size() == 1 and opened[0].ends_with("details?id=" + AppConfig.STORE_PACKAGE), "mağaza sayfası açılır (%s)" % [
		opened[0] if not opened.is_empty() else "-"])
	check(player.gems == gems, "değerlendirmeye gem verilmez (Play politikası)")


func _save_roundtrip() -> void:
	print("== 4) Kayıt ==")
	community.reset()
	community.open_link(&"instagram")
	community.open_link(&"tiktok")
	community.claim(&"tiktok")
	community.mark_rating_asked(4)
	var save: SaveManager = get_first_node_in_group("save_manager")
	var snapshot: Dictionary = save.snapshot()
	var data: Dictionary = snapshot.get("community", {})
	check(data.get("follow", {}).get("instagram") == CommunityLinks.Follow.OPENED
		and data.get("follow", {}).get("tiktok") == CommunityLinks.Follow.CLAIMED, "kayıtta takip durumları")
	community.reset()
	save.apply_snapshot(snapshot)
	check(community.follow_state(&"instagram") == CommunityLinks.Follow.OPENED
		and community.follow_state(&"tiktok") == CommunityLinks.Follow.CLAIMED, "kayıttan geri geldi: açıldı / alındı")
	check(not community.wants_rating(7) and community.wants_rating(8), "kayıttan geri geldi: sıradaki soru günü 8")
	community.load_state({"follow": {"instagram": 99, "tiktok": "x", "facebook": 2}, "rate": {"asks": -5, "next": -1}})
	check(community.follow_state(&"instagram") == CommunityLinks.Follow.CLAIMED
		and community.follow_state(&"tiktok") == CommunityLinks.Follow.NONE and community.unclaimed() == 1,
		"bozuk değerler sınırlanır, bilinmeyen ağ yok sayılır")
	check(not community.wants_rating(2) and community.wants_rating(3), "bozuk soru günü ilk güne döner")


func _market() -> void:
	print("== 5) MARKET › ÜCRETSİZ ==")
	community.reset()
	opened.clear()
	player.load_state(1, 0, 0)
	hud.router.close_all()
	hud.router.open(&"gem_store")
	await frames(30)
	var screen: GemStoreScreen = hud.gem_store_screen
	var tabs: Dictionary = screen.get("_tab_buttons")
	check(tabs.has(GemStoreScreen.TAB_FREE) and (tabs[GemStoreScreen.TAB_FREE] as PlateButton).text == "ÜCRETSİZ",
		"ÜCRETSİZ sekmesi var")
	check((tabs[GemStoreScreen.TAB_FREE] as PlateButton).badge == 2, "sekme rozeti: 2 alınmamış ödül")
	var column: Control = screen.get("_column")
	var width: float = column.size.x
	screen._on_tab_pressed(GemStoreScreen.TAB_FREE)
	await frames(4)
	var list: HBoxContainer = screen.get("_list")
	check(list.get_child_count() == CommunityLinks.LINKS.size(), "%d takip kartı" % list.get_child_count())
	check(absf(column.size.x - width) < 1.0, "sekme değişince pano genişliği aynı")
	var insta: Node = list.get_node_or_null("Follow_instagram")
	check(insta != null and _find_label(insta, "+10 GEM") != null and _find_label(insta, "INSTAGRAM") != null,
		"Instagram kartı: +10 GEM, INSTAGRAM")
	var button: PlateButton = insta.find_child("FollowButton", true, false) as PlateButton if insta else null
	check(button != null and button.text == "TAKİP ET" and not button.disabled, "düğme TAKİP ET")
	if button == null:
		return
	button.pressed.emit()
	await frames(4)
	check(opened == ["https://www.instagram.com/autoyardgame"], "dokununca hesap açıldı")
	insta = list.get_node_or_null("Follow_instagram")
	button = insta.find_child("FollowButton", true, false) as PlateButton
	check(button.text == "ÖDÜLÜ AL" and button.highlight, "dönünce düğme amber ÖDÜLÜ AL")
	button.pressed.emit()
	await frames(4)
	check(player.gems == 10, "ödül alındı (+10 gem)")
	var popup: RewardPopup = screen.get("_reward_popup")
	check(popup.visible, "ödül penceresi açıldı")
	button = list.get_node("Follow_instagram").find_child("FollowButton", true, false) as PlateButton
	check(button.text == "ALINDI" and button.disabled, "düğme soluk ALINDI")
	check((tabs[GemStoreScreen.TAB_FREE] as PlateButton).badge == 1, "sekme rozeti 1'e indi")
	popup.close()
	await frames(30)
	hud.router.close_all()
	await frames(30)
	hud.router.open(&"gem_store")   # yeniden açılış GEM AL'da başlar
	await frames(4)
	check(screen.get("_tab") == GemStoreScreen.TAB_GEMS, "MARKET yine GEM AL ile açılır")
	hud.router.close_all()
	await frames(30)


func _prompt() -> void:
	print("== 6) BİZİ DEĞERLENDİR penceresi ==")
	community.reset()
	opened.clear()
	var gems: int = player.gems
	rewards.load_state({"login": {"day": rewards.day_key(rewards.now_unix()), "days": 2}})
	hud.router.close_all()
	hud._arm_rate_prompt()
	await _wait_prompt(3.0)
	check(not hud.rate_prompt.visible, "2. günde açılmaz")
	rewards.load_state({"login": {"day": rewards.day_key(rewards.now_unix()), "days": 3}})
	hud._arm_rate_prompt()
	await _wait_prompt(6.0)
	check(hud.rate_prompt.visible and hud.router.top() == &"rate_prompt", "3. günde oyun sakinken açılır")
	check(_find_label(hud.rate_prompt, "BİZİ DEĞERLENDİR") != null, "başlık BİZİ DEĞERLENDİR")
	check(not community.wants_rating(3), "açılınca sayıldı")
	(hud.rate_prompt.find_child("LaterButton", true, false) as PlateButton).pressed.emit()
	await frames(30)
	check(not hud.rate_prompt.visible and opened.is_empty(), "SONRA: kapandı, hiçbir şey açılmadı")
	hud._arm_rate_prompt()
	await _wait_prompt(3.0)
	check(not hud.rate_prompt.visible, "aynı gün yeniden açılmaz")
	community.reset()
	hud.router.open(&"rate_prompt")
	await frames(20)
	(hud.rate_prompt.find_child("RateButton", true, false) as PlateButton).pressed.emit()
	await frames(30)
	check(not hud.rate_prompt.visible and community.is_rated(), "DEĞERLENDİR: kapandı, değerlendirildi")
	check(opened.size() == 1 and opened[0].contains(AppConfig.STORE_PACKAGE), "mağaza sayfası açıldı")
	check(player.gems == gems, "gem verilmedi")
	hud.router.close_all()


## Pencere açılana ya da süre dolana kadar bekler; arada kendiliğinden açılan başka ekranları (merdiven, gazete) kapatır.
func _wait_prompt(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until and not hud.rate_prompt.visible:
		var top: StringName = hud.router.top()
		if not top.is_empty() and top != &"rate_prompt":
			hud.router.close_all()
		await frames(5)


func _find_label(node: Node, text: String) -> Label:
	for n: Node in node.find_children("*", "Label", true, false):
		if (n as Label).text == text and (n as Label).is_visible_in_tree():
			return n as Label
	return null
