extends SceneTree
## UZAKTAN AYAR (AppConfig + AppGate) — Firestore REST biçiminin çözülmesi, dil yedeği, ZORUNLU GÜNCELLEME (min_code)
## ve BAKIM kapısı (kapanmaz, dokunuş geçmez, kural kalkınca söner), geliştirme sürümü kapıya takılmaz, YENİ SÜRÜM VAR
## (sürüm başına bir kez), DUYURU (kimlik başına bir kez, süresi dolan gösterilmez), son belge cihazda kalır (internet
## yokken de geçerli). Ağ kullanılmaz: belge apply() ile verilir. Gerçek düğümlerle koşar (Main.tscn: sakinlik kuralı).
##   tools/run_tests.sh app_config_test

var fails: int = 0
var hud: Hud
var config: AppConfig
var gate: AppGate


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func seconds(t: float) -> void:
	await create_timer(t).timeout


func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(AppConfig.FILE))
	_decode()
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(12)
	hud = main.find_child("HUD", true, false) as Hud
	config = AppConfig.new()
	config.name = AppConfig.NODE_NAME
	config.url = ""   # ağ yok: belge apply ile verilir
	root.add_child(config)
	await frames(2)
	gate = config.get_node("AppGate") as AppGate
	AppInfo.override_code = 10
	await _gates()
	await _soft_update()
	await _notice()
	await _cache()
	_event()
	await _event_banner()
	await _market_code_tab()
	AppInfo.override_code = 0
	print("SONUC: fails=%d" % fails)
	quit(1 if fails > 0 else 0)


func _decode() -> void:
	print("== 1) Firestore REST biçimi ==")
	var fields: Dictionary = {
		"min_code": {"integerValue": "11"},
		"maintenance": {"booleanValue": true},
		"ratio": {"doubleValue": 0.5},
		"update_text": {"mapValue": {"fields": {"tr": {"stringValue": "Yeni araçlar!"}, "en": {"stringValue": "New cars!"}}}},
		"list": {"arrayValue": {"values": [{"integerValue": "1"}, {"stringValue": "a"}]}},
		"empty_map": {"mapValue": {}},
		"nothing": {"nullValue": null},
	}
	var out: Dictionary = AppConfig.decode_fields(fields)
	check(out["min_code"] is int and out["min_code"] == 11, "integerValue → int")
	check(out["maintenance"] == true and is_equal_approx(float(out["ratio"]), 0.5), "booleanValue / doubleValue")
	check((out["update_text"] as Dictionary).get("en") == "New cars!", "mapValue → sözlük")
	check(out["list"] == [1, "a"], "arrayValue → dizi")
	check(out["empty_map"] == {} and out["nothing"] == null, "boş harita / null")
	var saved: String = Loc.current()
	Loc.use("de")
	check(AppConfig.text_of(out["update_text"]) == "New cars!", "dilde metin yoksa İngilizce")
	Loc.use("tr")
	check(AppConfig.text_of(out["update_text"]) == "Yeni araçlar!", "Türkçe metin")
	check(AppConfig.text_of({"tr": "Sadece Türkçe"}) == "Sadece Türkçe" and AppConfig.text_of("düz") == "düz",
		"İngilizce de yoksa Türkçe; düz metin olduğu gibi")
	Loc.use(saved)


func _gates() -> void:
	print("== 2) Zorunlu güncelleme + bakım ==")
	config.apply({})
	await frames(2)
	check(config.gate() == AppConfig.GATE_NONE and gate.blocker_kind() == &"", "kural yok: kapı yok")
	config.apply({"min_code": 11})
	await frames(3)
	check(config.gate() == AppConfig.GATE_UPDATE and gate.blocker_kind() == AppConfig.GATE_UPDATE,
		"sürüm 10 < min_code 11: GÜNCELLEME GEREKLİ")
	var screen: Control = _top_screen()
	check(screen != null and screen.mouse_filter == Control.MOUSE_FILTER_STOP and screen.is_visible_in_tree(),
		"kapı tam ekran, dokunuş oyuna geçmez")
	check(_button(screen, Loc.t("GÜNCELLE")) != null and _button(screen, Loc.t("SONRA")) == null, "yalnız GÜNCELLE (kapanmaz)")
	check(_has_text(screen, Loc.t("GÜNCELLEME GEREKLİ")), "tabela: GÜNCELLEME GEREKLİ")
	AppInfo.override_code = 0
	check(config.gate() == AppConfig.GATE_NONE, "geliştirme sürümü (kod 0) kapıya takılmaz")
	AppInfo.override_code = 10
	config.apply({"min_code": 10})
	await frames(3)
	check(gate.blocker_kind() == &"" and _top_screen() == null, "min_code 10 = bu sürüm: kapı söner")
	config.apply({"maintenance": true, "maintenance_text": {"tr": "Yeni garaj geliyor."},
		"maintenance_until": int(Time.get_unix_time_from_system()) + 3600})
	await frames(3)
	screen = _top_screen()
	check(gate.blocker_kind() == AppConfig.GATE_MAINTENANCE and _has_text(screen, "Yeni garaj geliyor."),
		"BAKIMDAYIZ + paneldeki metin")
	check(_button(screen, Loc.t("TEKRAR DENE")) != null and _has_text(screen, Loc.t("TAHMİNİ DÖNÜŞ %s").split(" %")[0])
		and _has_text(screen, Loc.t("Bakım bitince oyun kendiliğinden açılır")), "TEKRAR DENE + tahmini dönüş saati + not")
	check(screen is GateShutter and (screen as GateShutter).mode == GateShutter.Mode.MAINTENANCE, "bakım kepengi (tam iner)")
	_button(screen, Loc.t("TEKRAR DENE")).pressed.emit()
	await frames(2)
	check(_button(screen, Loc.t("KONTROL EDİLİYOR…")) != null, "TEKRAR DENE: düğme kontrol ettiğini söyler")
	await seconds(AppGate.RETRY_FEEDBACK_SEC + 0.3)
	check(_button(screen, Loc.t("TEKRAR DENE")) != null, "sonra yeniden TEKRAR DENE")
	config.apply({"maintenance": true, "min_code": 11})
	await frames(3)
	check(gate.blocker_kind() == AppConfig.GATE_UPDATE, "güncelleme bakımdan önce gelir")
	config.apply({})
	await frames(3)
	check(gate.blocker_kind() == &"" and _top_screen() == null, "kural kalkınca kapı yok")


func _soft_update() -> void:
	print("== 3) YENİ SÜRÜM VAR ==")
	config.apply({"latest_code": 12})
	check(config.soft_update(), "latest_code 12 > 10: öneri bekliyor")
	await seconds(AppGate.CALM_SEC + 1.5)
	check(gate.dialog_kind() == &"soft_update", "oyun sakinken pencere açıldı")
	var screen: Control = _top_screen()
	check(_button(screen, Loc.t("GÜNCELLE")) != null and _button(screen, Loc.t("SONRA")) != null, "GÜNCELLE / SONRA")
	_button(screen, Loc.t("SONRA")).pressed.emit()
	await seconds(0.4)
	check(gate.dialog_kind() == &"" and not config.soft_update(), "SONRA: kapandı, bu sürüm için bir daha sorulmaz")
	config.apply({"latest_code": 13})
	check(config.soft_update(), "daha yeni sürüm (13) yeniden sorar")
	config.dismiss_soft_update()
	config.apply({"latest_code": 13, "min_code": 11})
	await seconds(AppGate.CALM_SEC + 1.0)
	check(gate.blocker_kind() == AppConfig.GATE_UPDATE and gate.dialog_kind() == &"", "kapı varken kapatılabilir pencere açılmaz")
	config.apply({})
	await frames(3)


func _notice() -> void:
	print("== 4) DUYURU (2026-10-25'ten beri pencere değil, HABERLER kutusunda) ==")
	var now: int = int(Time.get_unix_time_from_system())
	config.apply({"notice": {"id": "n_eski", "text": {"tr": "Geçti"}, "until": now - 10}})
	check(config.notice().is_empty(), "süresi dolan duyuru yok sayılır")
	config.apply({"notice": {"id": "n1", "title": {"tr": "Hafta sonu etkinliği"}, "text": {"tr": "Tamirlerde çifte para!"}}})
	check(SaveSafe.s(config.notice().get("text")) == "Tamirlerde çifte para!"
		and SaveSafe.s(config.notice().get("title")) == "Hafta sonu etkinliği", "duyuru okunur (başlık + metin)")
	hud.router.close_all()
	await seconds(AppGate.CALM_SEC + 1.5)
	check(gate.dialog_kind() == &"", "oyun sakinken de duyuru penceresi açılmaz")


func _cache() -> void:
	print("== 5) Son belge cihazda ==")
	config.apply({"min_code": 11, "notice": {"id": "n1", "text": {"tr": "Tamirlerde çifte para!"}}})
	var fresh: AppConfig = AppConfig.new()   # yeni açılış: ağ yok, cihazdaki belge
	check(fresh.gate() == AppConfig.GATE_UPDATE, "internet yokken de son kural geçerli (uçak moduyla atlatılmaz)")
	check(SaveSafe.s(fresh.notice().get("id")) == "n1", "duyuru da cihazdaki belgeden okunur")
	fresh.free()
	config.apply({})


func _event() -> void:
	print("== 6) Canlı etkinlik ==")
	var now: int = int(Time.get_unix_time_from_system())
	var race: RaceManager = get_first_node_in_group("race") as RaceManager
	var rival: StringName = &"tofas_sahin"
	config.apply({})
	var base: Dictionary = race.reward_for(rival, true) if race else {}
	check(config.active_event().is_empty() and AppConfig.money_multiplier(self) == 1.0, "etkinlik yok: çarpan 1")
	config.apply({"event": {"id": "e1", "title": {"tr": "Hafta sonu"}, "money_mult": 2.0, "xp_mult": 1.5, "start": now - 60, "end": now + 3600}})
	check(config.active_event().get("title") == "Hafta sonu" and AppConfig.money_multiplier(self) == 2.0
		and AppConfig.xp_multiplier(self) == 1.5, "etkin: ×2 para, ×1,5 XP")
	if race:
		var doubled: Dictionary = race.reward_for(rival, true)
		check(int(doubled["money"]) == int(base["money"]) * 2 and int(doubled["xp"]) == int(round(float(base["xp"]) * 1.5)),
			"yarış ödülü çarpıldı (%d → %d ₺)" % [int(base["money"]), int(doubled["money"])])
	config.apply({"event": {"id": "e2", "money_mult": 9.0, "start": now - 60, "end": now + 60}})
	check(AppConfig.money_multiplier(self) == 3.0, "çarpan en çok 3")
	config.apply({"event": {"id": "e3", "money_mult": 2.0, "start": now + 600, "end": now + 3600}})
	check(config.active_event().is_empty(), "başlamamış etkinlik etkin değil")
	config.apply({"event": {"id": "e4", "money_mult": 2.0, "start": now - 7200, "end": now - 60}})
	check(config.active_event().is_empty(), "bitmiş etkinlik etkin değil")
	config.apply({"event": {"money_mult": 2.0, "start": now - 60, "end": now + 60}})
	check(config.active_event().is_empty(), "kimliksiz etkinlik yok sayılır")
	config.apply({})


func _event_banner() -> void:
	print("== 7) Etkinlik tabelası ==")
	var banner: EventBanner = hud.find_child("EventBanner", true, false) as EventBanner
	check(banner != null, "tabela HUD'da kurulu")
	if banner == null:
		return
	var now: int = int(Time.get_unix_time_from_system())
	config.apply({"event": {"id": "hs1", "title": {"tr": "Hafta sonu etkinliği"}, "money_mult": 2.0, "xp_mult": 2.0,
		"start": now - 60, "end": now + 3 * 3600 + 125}})
	await seconds(1.3)
	var texts: String = " ".join(banner.find_children("*", "Label", true, false).map(func(n: Node) -> String: return (n as Label).text))
	check(banner.visible and banner.event_id() == "hs1", "etkinlik varken üst ortada görünür")
	check(texts.contains("HAFTA SONU ETKİNLİĞİ") and texts.contains(Loc.t("ÇİFTE PARA")) and texts.contains(Loc.t("ÇİFTE XP"))
		and texts.contains("×2") and texts.contains("03:0"), "başlık, ÇİFTE PARA · ÇİFTE XP, ×2, geri sayım (%s)" % texts)
	check(EventBanner.countdown(2 * 86400 + 4 * 3600) == Loc.t("%dg %02ds") % [2, 4] and EventBanner.countdown(-5) == "00:00:00",
		"24 saatten uzunsa gün / saat; bitince 00:00:00")
	hud.router.open(&"settings")
	await seconds(1.3)
	check(not banner.visible, "ekran açıkken gizli")
	hud.router.close_all()
	config.apply({})
	await seconds(1.3)
	check(not banner.visible, "etkinlik bitince söner")


func _market_code_tab() -> void:
	print("== 8) MARKET › KOD GİR ==")
	hud.router.open(&"gem_store")
	await seconds(0.6)
	var store: GemStoreScreen = hud.router.screen(&"gem_store") as GemStoreScreen
	store._on_tab_pressed(GemStoreScreen.TAB_CODE)
	await frames(4)
	var panel: Control = store.find_child("CodePanel", true, false) as Control
	var edit: LineEdit = store.find_child("CodeEdit", true, false) as LineEdit
	var result: Label = store.find_child("CodeResult", true, false) as Label
	check(panel != null and edit != null and store.find_child("UseButton", true, false) != null, "KOD GİR: kutu + KULLAN")
	check(edit != null and not edit.editable and result.text == PromoService.status_text("signin"), "misafirde kilitli, neden yazılı")
	edit.text_changed.emit("reels-50")
	check(edit.text == "REELS50", "yazılan kod büyük harfe çevrilir")
	hud.router.close_all()
	await seconds(0.4)


func _top_screen() -> Control:
	var host: Control = gate.get_node("Root") as Control
	for i: int in range(host.get_child_count() - 1, -1, -1):
		var child: Control = host.get_child(i) as Control
		if child and not child.is_queued_for_deletion() and not bool(child.get("leaving")):   # kalkan kepenk sayılmaz
			return child
	return null


func _button(screen: Control, text: String) -> PlateButton:
	if screen == null:
		return null
	for node: Node in screen.find_children("*", "PlateButton", true, false):
		if (node as PlateButton).text == text:
			return node as PlateButton
	return null


func _has_text(screen: Control, text: String) -> bool:
	if screen == null:
		return false
	for node: Node in screen.find_children("*", "Label", true, false):
		if (node as Label).text.contains(text):
			return true
	return false
