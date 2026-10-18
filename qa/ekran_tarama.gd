extends SceneTree
## EKRAN TARAMASI — her ekranı ve alt görünümünü bir CİHAZ ORANINDA açar; kadrajdan taşan, kabından
## taşan, birbirinin üstüne binen ve kesilen (… / kırpılan) öğeleri listeler, her durumun görüntüsünü alır.
##
## Tuval: canvas_items + expand, telefonda/tablette scale 1,35 (project.godot scale.mobile). Bu yüzden
## tuvalin boyu PİKSEL çözünürlüğüne değil yalnızca ORANA bağlıdır:
##   20:9 telefon 1067x480 · 16:9 telefon 853x480 · 16:10 tablet 853x533 · 4:3 tablet 853x640 ·
##   katlanabilir iç ekran (6:5) 853x711 · 21:9 telefon 1120x480 · masaüstü 1152x648 (ölçek 1).
## Pencere boyu oranı verir, mobil ölçek betik içinde uygulanır (tools/ekran_tarama.sh hepsini koşar):
##   CT_NO_TUTORIAL=1 QA_SAVE=~/Projects/ct_shots/bench_saves/dev.json tools/qa_isolated.sh \
##     res://qa/ekran_tarama.gd --display-driver x11 --disable-vsync --resolution 1152x864 -- t4x3 mobil [durum ...]
## Dil: QA_LANG=en|es (tools/ekran_tarama.sh'de CT_LANG) — oyun ayar dosyasındaki dille açılır.
## Çıktı: ~/Projects/ct_shots/ekran_tarama/<etiket>/NN_<durum>.png + konsolda "SORUN" satırları.
const OUT_ROOT: String = "/home/burak/Projects/ct_shots/ekran_tarama/"
## Kabından bu kadar (birim) taşan çocuk raporlanır (rozet / gölge gibi küçük taşmalar sayılmaz).
const OVERFLOW_TOLERANCE: float = 3.0
## İki öğenin kesişimi küçüğün alanının bu oranını aşarsa çakışma sayılır.
const OVERLAP_RATIO: float = 0.18

var _out: String = ""
var _tag: String = ""
var _only: PackedStringArray = PackedStringArray()
var _hud: Hud
var _router: UiRouter
var _index: int = 0
var _total_issues: int = 0
## QA_HUD=0..4: HUD BOYUTU kademesi (boşsa ayardaki).
var _hud_size: int = -1


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_tag = args[0] if args.size() > 0 else "ekran"
	var mobile: bool = args.size() < 2 or args[1] != "masaustu"
	for i: int in range(2, args.size()):
		_only.append(args[i])
	if mobile:
		get_root().content_scale_factor = 1.35
	_hud_size = int(OS.get_environment("QA_HUD")) if OS.get_environment("QA_HUD") != "" else -1
	_out = OUT_ROOT + _tag + "/"
	DirAccess.make_dir_recursive_absolute(_out)
	for file: String in DirAccess.get_files_at(_out):
		DirAccess.remove_absolute(_out + file)
	_run.call_deferred()


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func wait(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


# --- Ölçüm ---------------------------------------------------------------------------------------

func _alpha(item: CanvasItem) -> float:
	var a: float = item.self_modulate.a
	var node: Node = item
	while node is CanvasItem:
		a *= (node as CanvasItem).modulate.a
		node = node.get_parent()
	return a


func _is_leaf(c: Control) -> bool:
	if c is Label or c is RichTextLabel or c is BaseButton or c is LineEdit or c is TextureRect \
			or c is ProgressBar:
		return true
	if c.get_script() == null or c is Container:
		return false
	for child: Node in c.get_children():
		if child is Control and (child as Control).visible:
			return false
	return true


func _path(c: Node) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var node: Node = c
	var depth: int = 0
	while node and node != root and depth < 4:
		var label: String = String(node.name)
		if label.begins_with("@"):
			label = node.get_class()
		parts.insert(0, label)
		node = node.get_parent()
		depth += 1
	return "/".join(parts)


func _text_of(c: Control) -> String:
	var text: String = ""
	if c is Label:
		text = (c as Label).text
	elif c is Button:
		text = (c as Button).text
	elif c is LineEdit:
		text = (c as LineEdit).text
	return text.replace("\n", " ⏎ ").left(28)


func _describe(c: Control) -> String:
	var text: String = _text_of(c)
	return "%s%s" % [_path(c), (" «%s»" % text) if text != "" else ""]


## Kırpan ata dikdörtgeni (ScrollContainer / clip_contents) ve kaydırma kabının içinde mi.
func _clip_of(c: Control) -> Dictionary:
	var clip: Rect2 = get_root().get_visible_rect()
	var in_scroll: bool = false
	var node: Node = c.get_parent()
	while node:
		if node is Control:
			var p: Control = node
			if p is ScrollContainer:
				in_scroll = true
				clip = clip.intersection(Hud.screen_rect(p))
			elif p.clip_contents:
				clip = clip.intersection(Hud.screen_rect(p))
		elif node is CanvasLayer:
			break
		node = node.get_parent()
	return {"clip": clip, "scroll": in_scroll}


func _text_cut(c: Control) -> String:
	if c is Label:
		var l: Label = c
		if l.text == "" or l.visible_characters == 0:
			return ""
		var font: Font = l.get_theme_font(&"font")
		var size: int = l.get_theme_font_size(&"font_size")
		var style: StyleBox = l.get_theme_stylebox(&"normal")
		var avail: float = l.size.x - (style.get_minimum_size().x if style else 0.0)
		if l.autowrap_mode == TextServer.AUTOWRAP_OFF:
			if l.clip_text or l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
				for line: String in l.text.split("\n"):
					var w: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
					if w > avail + 1.0:
						return "metin kesik (%.0f > %.0f)" % [w, avail]
		else:
			if l.max_lines_visible >= 0 and l.get_line_count() > l.max_lines_visible:
				return "satır kesik (%d > %d)" % [l.get_line_count(), l.max_lines_visible]
			if l.get_line_count() > l.get_visible_line_count():
				return "satır sığmıyor (%d > %d)" % [l.get_line_count(), l.get_visible_line_count()]
	elif c is Button:
		var b: Button = c
		if b.text != "" and (b.clip_text or b.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING):
			var font: Font = b.get_theme_font(&"font")
			var size: int = b.get_theme_font_size(&"font_size")
			var style: StyleBox = b.get_theme_stylebox(&"normal")
			var avail: float = b.size.x - (style.get_minimum_size().x if style else 0.0)
			var w: float = font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			if b.icon:
				avail -= b.get_theme_constant(&"h_separation") + b.icon.get_width()
			if w > avail + 1.0:
				return "düğme yazısı kesik (%.0f > %.0f)" % [w, avail]
	return ""


func _collect(node: Node, out: Array[Control]) -> void:
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	if node is Control:
		var c: Control = node
		if c.size.x >= 1.0 and c.size.y >= 1.0 and _alpha(c) > 0.05:
			out.append(c)
	for child: Node in node.get_children():
		_collect(child, out)


## Döndürülmüş / ölçeklenmiş (animasyonlu ya da süs: damga, ikaz şeridi) öğe: dikdörtgeni gerçek
## görüntüsünü anlatmaz, taşma denetimine girmez.
func _transformed(c: Control) -> bool:
	var node: Node = c
	while node is Control:
		var control: Control = node
		# HUD BOYUTU ölçeği yerleşimdir, süs değil: o kümelerin içi yine denetlenir (ekran dikdörtgeniyle)
		var layout_scale: bool = _hud != null and control in [_hud.top_left, _hud.top_right, _hud.bottom]
		if not layout_scale and (not control.scale.is_equal_approx(Vector2.ONE) or not is_zero_approx(control.rotation)):
			return true
		node = node.get_parent()
	return false


func _is_ancestor(a: Node, b: Node) -> bool:
	return a.is_ancestor_of(b) or b.is_ancestor_of(a)


func _analyze(state: String, scope: Node) -> PackedStringArray:
	var issues: PackedStringArray = PackedStringArray()
	var view: Rect2 = get_root().get_visible_rect()
	var controls: Array[Control] = []
	_collect(scope, controls)
	var leaves: Array[Dictionary] = []
	for c: Control in controls:
		var r: Rect2 = Hud.screen_rect(c)   # HUD boyutu ölçeği dahil
		var info: Dictionary = _clip_of(c)
		var clip: Rect2 = info["clip"]
		var in_scroll: bool = info["scroll"]
		var decor: bool = _transformed(c) or r.size.x > view.size.x + 1.0
		# 1) Kadraj dışı (arka plan gibi kadrajı tamamen kaplayanlar ve kadrajdan geniş süs bantları hariç;
		#    kaydırma içi hariç)
		if not in_scroll and not decor and not r.encloses(view):
			var out_l: float = view.position.x - r.position.x
			var out_t: float = view.position.y - r.position.y
			var out_r: float = r.end.x - view.end.x
			var out_b: float = r.end.y - view.end.y
			var worst: float = maxf(maxf(out_l, out_t), maxf(out_r, out_b))
			if worst > 2.0 and r.intersects(view):
				issues.append("KADRAJ DIŞI %.0f  %s %s" % [worst, _describe(c), r])
		# 2) Kabından taşan (Container çocuğu; kaydırma kabı içeriği hariç)
		var parent: Control = c.get_parent() as Control
		if parent and parent is Container and not parent is ScrollContainer and not in_scroll and not decor:
			var pr: Rect2 = Hud.screen_rect(parent)
			var over: float = maxf(maxf(pr.position.x - r.position.x, pr.position.y - r.position.y),
				maxf(r.end.x - pr.end.x, r.end.y - pr.end.y))
			if over > OVERFLOW_TOLERANCE:
				issues.append("KABINDAN TAŞIYOR %.0f  %s %s ⊄ %s" % [over, _describe(c), r, pr])
		# 3) Kesilen metin
		var cut: String = _text_cut(c)
		if cut != "":
			issues.append("KESİK %s  %s" % [cut, _describe(c)])
		# 4) Kırpılan (kaydırma dışı clip_contents ata öğeyi kesiyor)
		if not in_scroll and clip.size.x > 0.0 and not clip.encloses(r) and r.intersects(clip) \
				and not r.encloses(clip) and clip != view:
			var cr: Rect2 = r.intersection(clip)
			if cr.get_area() < r.get_area() * 0.9 and _is_leaf(c):
				issues.append("KIRPILIYOR  %s %s (görünen %s)" % [_describe(c), r, cr.size])
		if _is_leaf(c):
			var shown: Rect2 = r.intersection(clip) if clip.size.x > 0.0 else Rect2()
			if shown.get_area() > 4.0:
				leaves.append({"c": c, "r": shown})
	# 5) Çakışma: atası/çocuğu olmayan iki içerik öğesi üst üste
	for i: int in leaves.size():
		var a: Dictionary = leaves[i]
		for j: int in range(i + 1, leaves.size()):
			var b: Dictionary = leaves[j]
			var ra: Rect2 = a["r"]
			var rb: Rect2 = b["r"]
			if not ra.intersects(rb):
				continue
			var ca: Control = a["c"]
			var cb: Control = b["c"]
			if _is_ancestor(ca, cb):
				continue
			var inter: float = ra.intersection(rb).get_area()
			var smaller: float = minf(ra.get_area(), rb.get_area())
			if smaller > 0.0 and inter / smaller > OVERLAP_RATIO:
				# Aynı düğmenin içindeki ikon/yazı gibi (ortak ata BaseButton) bilinçli katmanlar hariç
				if _shared_button(ca, cb):
					continue
				# Bilinçli rozet (meta qa_badge): kendi kabındaki komşusunun köşesine biner (HUD seviye rozeti avatarın)
				if _badge_pair(ca, cb):
					continue
				# Arka plan: yazı olmayan bir öğe ötekini TAMAMEN kaplıyorsa (harita resmi, gölge) çakışma değil
				if (ra.encloses(rb) and not _is_text(ca)) or (rb.encloses(ra) and not _is_text(cb)):
					continue
				issues.append("ÇAKIŞMA %.0f%%  %s ⟷ %s" % [inter / smaller * 100.0, _describe(ca), _describe(cb)])
	return issues


## Biri `qa_badge` işaretli (ya da onun içinde) ve ikisi aynı kabın çocukları: bilerek üst üste konmuş rozet.
func _badge_pair(a: Node, b: Node) -> bool:
	for pair: Array in [[a, b], [b, a]]:
		var node: Node = pair[0]
		while node and not node is CanvasLayer:
			if node.has_meta(&"qa_badge"):
				return node.get_parent() != null and node.get_parent().is_ancestor_of(pair[1])
			node = node.get_parent()
	return false


func _is_text(c: Control) -> bool:
	return (c is Label and (c as Label).text != "") or (c is Button and (c as Button).text != "") \
		or c is LineEdit or c is RichTextLabel


func _shared_button(a: Node, b: Node) -> bool:
	var node: Node = a.get_parent()
	while node and not node is CanvasLayer:
		if node is BaseButton and node.is_ancestor_of(b):
			return true
		node = node.get_parent()
	return false


func _report(state: String, scope: Node) -> void:
	await frames(2)
	_index += 1
	var issues: PackedStringArray = _analyze(state, scope)
	_total_issues += issues.size()
	print("=== [%s] %02d_%s · tuval %s · %d sorun" % [_tag, _index, state, get_root().get_visible_rect().size,
		issues.size()])
	for line: String in issues:
		print("  SORUN ", line)
	RenderingServer.force_draw()
	get_root().get_texture().get_image().save_png("%s%02d_%s.png" % [_out, _index, state])


func _want(state: String) -> bool:
	if _only.is_empty():
		return true
	for prefix: String in _only:
		if state.begins_with(prefix):
			return true
	return false


## Ekranı açar, açılış animasyonunu bekler, ölçer, kapatır.
func _screen(id: StringName, state: String, setup: Callable = Callable(), settle: float = 0.7) -> void:
	if not _want(state):
		return
	_router.close_all()
	await wait(0.35)
	_router.open(id)
	await wait(settle)
	if setup.is_valid():
		await setup.call()
		await wait(0.35)
	await _report(state, _router.screen(id))


func _world(state: String, setup: Callable) -> void:
	if not _want(state):
		return
	_router.close_all()
	# Dünya plakaları oyunda birbirini kapatır (alan plakası ↔ araç plakası ↔ kasa): her durum temiz başlar
	_hud.hide_bay_plate()
	_hud.hide_car_info()
	_hud.crate_panel.hide_panel()
	_hud.restoration_result.hide_panel()
	_hud.set("_garage_panel_open", false)
	_hud.call("_sync_garage_panel")
	await wait(0.3)
	await setup.call()
	await wait(0.6)
	await _report(state, _hud.get_node("Root"))


# --- Akış ----------------------------------------------------------------------------------------

func _run() -> void:
	# Yükleme ekranı (gerçek ilk sahne) → Main arka planda yüklenir
	change_scene_to_file(String(ProjectSettings.get_setting("application/run/main_scene")))
	await wait(0.6)
	if _want("yukleme"):
		var loading: Node = current_scene if current_scene and current_scene.name == "LoadingScreen" \
			else root.get_node_or_null("LoadingScreen")
		if loading:
			await _report("yukleme", loading)
	var until: int = Time.get_ticks_msec() + 40000
	while Time.get_ticks_msec() < until and (current_scene == null or current_scene.name == "LoadingScreen" \
			or root.get_node_or_null("LoadingScreen") != null):
		await process_frame
	_hud = current_scene.find_child("HUD", true, false) as Hud
	_router = _hud.router
	if _hud_size >= 0:
		var settings: GameSettings = get_first_node_in_group("settings") as GameSettings
		settings.set_hud_size(_hud_size)
		print("HUD boyutu: %%%d" % roundi(settings.hud_scale() * 100.0))
	await wait(1.5)
	print("tuval: %s  pencere: %s" % [get_root().get_visible_rect().size, DisplayServer.window_get_size()])

	# --- Ana dünya HUD'u ---
	await _world("dunya", func() -> void: pass)
	await _world("dunya_garaj_paneli", func() -> void:
		_hud.garage_button.pressed.emit())
	await _world("dunya_alan_plakasi", func() -> void:
		_hud.show_bay_plate(mini(3, _hud._bays.bay_count() - 1) if _hud._bays else 1))
	await _world("dunya_genisletme_plakasi", func() -> void:
		_hud.show_expansion_plate())
	await _world("dunya_en_kalabalik", func() -> void:
		_hud.garage_button.pressed.emit()
		_hud.show_bay_plate(mini(3, _hud._bays.bay_count() - 1) if _hud._bays else 1)
		_hud._show_notice(Loc.t("TAMİR ALANI %d AÇILDI\nGARAJI DÜZENLE'DEN TAŞIYABİLİRSİN") % 3, HudPalette.COIN_DARK, 6.0)
		await wait(0.4))
	await _world("dunya_bildirim", func() -> void:
		_hud._show_notice(Loc.t("PARÇA HAZIR: %s\nTAMİR ALANINDAKİ ARACA DOKUN") % "BAVARIA FÜNF 07",
			HudPalette.COIN_DARK, 6.0)
		await wait(0.4))
	await _world("dunya_kamera", func() -> void:
		_hud.camera_button.button_pressed = true)
	_hud.camera_button.button_pressed = false
	await _world("dunya_foto_modu", func() -> void:
		_hud.open_photo_mode(PhotoMode.Mode.PHOTO))
	# Gerçek çekim: bildirim + köşedeki küçük resim; logolu JPEG etiket klasörüne kopyalanır (göz kontrolü)
	await _world("dunya_foto_cekildi", func() -> void:
		_hud.open_photo_mode(PhotoMode.Mode.PHOTO)
		await wait(0.4)
		GallerySaver.override_dir = _out + "foto"
		_hud.photo_mode.capture()
		await _hud.photo_mode.photo_saved
		GallerySaver.override_dir = ""
		await wait(0.2))
	await _world("dunya_hud_gizli", func() -> void:
		_hud.open_photo_mode(PhotoMode.Mode.CLEAN))
	var types: Array[RepairType] = RepairType.defaults()
	await _world("dunya_arac_ariza", func() -> void:
		_hud.show_car_info("WULF KOMBI 04")
		_hud._repair_panel.set_player_state(30, 9000000)
		_hud._repair_panel.set_issue(types[types.size() - 1])
		_hud._repair_panel.show_damaged(false))
	await _world("dunya_arac_tamirde", func() -> void:
		_hud.show_car_info("WULF KOMBI 04")
		_hud._repair_panel.set_info(types[types.size() - 1], 4800)
		_hud._repair_panel.show_repairing(0.42, 754.0, true, 14))
	await _world("dunya_arac_hazir", func() -> void:
		_hud.show_car_info("WULF KOMBI 04")
		_hud._repair_panel.set_info(types[0], 1200)
		_hud._repair_panel.show_ready())
	_hud.hide_car_info()
	var crate_id: StringName = StringName(String(CrateCatalog.all()[0]["id"]))
	await _world("dunya_kasa_soru", func() -> void:
		_hud.crate_panel.show_prompt(-1, crate_id))
	_hud.crate_panel.hide_panel()
	await _world("dunya_kasa_sonuc", func() -> void:
		_hud.crate_panel.show_result(-1, {"vehicle": &"hyundai_accent_blue", "rarity": &"common",
			"duplicate": true, "stars": 2, "reacquired": false, "gems": 5}))
	_hud.crate_panel.hide_panel()
	var classic: StringName = StringName(String(RestorationCatalog.cars()[0]["id"]))
	await _world("dunya_restorasyon_sonuc", func() -> void:
		_hud.restoration_result.show_result(classic)
		await wait(0.8))
	_hud.restoration_result.hide_panel()
	# Eğitim: Rıza Usta kartı (uzun metin) ve ders kartı
	if _want("egitim"):
		var overlay: TutorialOverlay = _hud.tutorial_overlay
		_router.close_all()
		await wait(0.3)
		overlay.activate()
		overlay.set_mode(true, true, true, false)
		overlay.set_target(Hud.screen_rect(_hud.quest_button), false)
		overlay.show_card("DERS 1", Loc.t("GÖREVLER"), Loc.t("Ne yapacağını bilmiyorsan GÖREVLER'e bak. Görevler sana yol gösterir ve her biri ödül verir; günlük ve haftalık görevler her gün yenilenir."),
			Loc.t("İLERİ"), 5, 6, &"bottom")
		await wait(1.0)
		overlay.card.call("_finish_typing")
		await wait(0.4)
		await _report("egitim_kart", overlay)
		overlay.place_card(&"top")
		await wait(0.5)
		await _report("egitim_kart_ust", overlay)
		overlay.hide_card()
		overlay.show_chapter(_hud.tutorial.call("_intro_info", TutorialManager.BASICS))
		await wait(1.6)
		await _report("egitim_ders", overlay)
		overlay.chapter.close()
		overlay.deactivate()
		await wait(0.6)

	# --- Yerler ve panolar ---
	await _screen(&"garage", "garaj")
	await _screen(&"garage", "garaj_detay", func() -> void:
		(_router.screen(&"garage") as GarageScreen).call("_open_detail"))
	if GameFeatures.PAINT:
		await _screen(&"garage", "garaj_boya", func() -> void:
			(_router.screen(&"garage") as GarageScreen).call("_open_paint"))
	await _screen(&"garage", "garaj_sat", func() -> void:
		var screen: GarageScreen = _router.screen(&"garage") as GarageScreen
		screen.sell_button.button_pressed = true)
	await _screen(&"garage", "garaj_modifiye", func() -> void:
		(_router.screen(&"garage") as GarageScreen).open_mods())
	await _screen(&"garage", "garaj_modifiye_kategori", func() -> void:
		var screen: GarageScreen = _router.screen(&"garage") as GarageScreen
		screen.open_mods()
		await wait(0.4)
		var workshop: ModWorkshop = screen.get("_workshop")
		workshop.open_category(&"motor"))
	await _screen(&"showroom", "magaza")
	await _screen(&"showroom", "magaza_son_kasa", func() -> void:   # en uzun oran listesi
		var crates: Array[Dictionary] = CrateCatalog.all()
		(_router.screen(&"showroom") as ShowroomScreen).call("_show_crate", StringName(String(crates.back()["id"]))))
	await _screen(&"quests", "gorevler")
	await _screen(&"quests", "gorevler_haftalik", func() -> void:
		_hud.quest_screen.call("_on_tab_pressed", 1))
	await _screen(&"quests", "gorevler_basarim", func() -> void:
		_hud.quest_screen.call("_on_tab_pressed", 2))
	if _want("gorevler_odul"):
		_router.close_all()
		await wait(0.35)
		_router.open(&"quests")
		await wait(0.7)
		var popup: RewardPopup = _hud.quest_screen.get("_reward_popup")
		popup.show_rewards({"money": 12500, "gems": 15, "xp": 240, "crates": [Loc.t("ŞEHİR KASASI")], "count": 3})
		await wait(1.4)
		await _report("gorevler_odul", popup)
		popup.hide()
	await _screen(&"mastery", "ustalik")
	await _screen(&"garage_value", "garaj_degeri")
	await _screen(&"profile", "profil")
	# PROFİL DÜZENLE (alt pano) — beş sekme, kırpıcı, kamera (masaüstünde kamera yok: "bulunamadı" yazısı)
	for tab: Array in [[0, "foto"], [1, "cerceve"], [2, "bayrak"], [3, "vitrin"], [4, "isim"]]:
		await _screen(&"profile_edit", "profil_duzenle_%s" % tab[1], func() -> void:
			_hud.profile_edit_screen.call("_select_tab", int(tab[0])))
	await _screen(&"avatar_crop", "profil_kirp", func() -> void:
		var image: Image = (load("res://assets/ui/avatars/featured_elif.png") as Texture2D).get_image()
		image.resize(600, 400)
		_hud.avatar_cropper.set_image(image))
	await _screen(&"avatar_camera", "profil_kamera", Callable(), 3.2)
	await _screen(&"friend_card", "arkadas_karti", func() -> void:
		_hud.friend_card_screen.show_for("featured_emre"))
	await _screen(&"account", "hesap")
	await _screen(&"account", "hesap_oneri", func() -> void:
		_hud.login_screen.show_prompt())
	await _screen(&"settings", "ayarlar")
	for page: int in [1, 2, 3, 4]:
		await _screen(&"settings", "ayarlar_%d" % page, func() -> void:
			_hud.settings_screen.call("_show_page", page))
	await _screen(&"account", "hesap_kayit_sec", func() -> void:
		_hud.login_screen.call("_on_conflict_found",
			{"money": 9993530, "level": 30, "vehicles": PackedStringArray(["BAVARIA FÜNF 07", "BURSAN ATMACA 95", "BULL MONSOON"])},
			{"money": 125000, "level": 8, "vehicles": PackedStringArray(["BURSAN ATMACA 95", "HYPER POCKET Z"])})
		(_hud.login_screen.get("_choice_row") as Control).visible = true)
	if _want("koleksiyon"):   # oyunda garajdan / showroom'dan açılır (YER açık: oyun HUD'u gizli)
		_router.close_all()
		await wait(0.35)
		_router.open(&"garage")
		await wait(0.6)
		_router.open(&"collection")
		await wait(0.9)
		await _report("koleksiyon", _router.screen(&"collection"))
	await _screen(&"friends", "arkadaslar")
	await _screen(&"gem_store", "elmas_magazasi")
	await _screen(&"garage_edit", "dekor")
	await _screen(&"race_challenge", "yaris_davet")
	# ARKADAŞ RAKİP: davet başlığı / rakip plakasında fotoğraf + ad, sonuçta "… YENDİN!"
	var race_mgr: RaceManager = get_first_node_in_group("race") as RaceManager
	if _want("yaris_arkadas") and race_mgr:
		race_mgr._rival_id = &"lambo_huracan"
		race_mgr._rival_owner = FeaturedFriends.rival_owner("featured_emre")
		await _screen(&"race_challenge", "yaris_arkadas_davet")
		await _screen(&"race_result", "yaris_arkadas_sonuc", func() -> void:
			var result: RaceResultScreen = _router.screen(&"race_result") as RaceResultScreen
			result.hide_bonus()
			result.show_result(true, 10.42, 10.87, 2000, 100, &"bmw_e60")
			result.show_record(true, true, 10.42, 10.9)
			result.offer_bonus(2000))
		race_mgr._rival_owner = {}
		race_mgr._rival_id = &""
	await _screen(&"drag_race", "yaris_pist", Callable(), 2.5)
	await _screen(&"race_result", "yaris_sonuc", func() -> void:
		var result: RaceResultScreen = _router.screen(&"race_result") as RaceResultScreen
		result.show_result(true, 11.42, 11.87, 12500, 40, &"bmw_e60")
		result.show_record(true, true, 11.42, 11.9)
		result.offer_bonus(12500))
	await _screen(&"race_result", "yaris_sonuc_kayip", func() -> void:
		var result: RaceResultScreen = _router.screen(&"race_result") as RaceResultScreen
		result.hide_bonus()
		result.show_result(false, 12.08, 11.42, 0, 30, &"lambo_huracan")
		result.show_record(true, false, 12.08, 11.9)
		result.offer_rematch(true))
	await _screen(&"race_result", "yaris_sonuc_rovans", func() -> void:
		var result: RaceResultScreen = _router.screen(&"race_result") as RaceResultScreen
		result.hide_bonus()
		result.show_result(false, 11.96, 11.42, 0, 0, &"lambo_huracan", 1)   # rövanş da kaybedildi: plaka yok
		result.show_record(true, false, 11.96, 11.9))
	await _screen(&"map", "harita")
	await _screen(&"junkyard", "hurdalik", Callable(), 1.5)
	await _screen(&"junkyard", "hurdalik_arac", func() -> void:
		(_router.screen(&"junkyard") as JunkyardScreen).call("_show_car", 0), 1.5)
	await _screen(&"junkyard", "hurdalik_parcalar", func() -> void:
		(_router.screen(&"junkyard") as JunkyardScreen).call("_toggle_parts"), 1.5)
	var jy: JunkyardManager = get_first_node_in_group("junkyard") as JunkyardManager
	var project: StringName = &""
	if jy:
		for id: StringName in jy.yard_cars():
			if jy.has_project(id) or jy.start(id):
				project = id
				break
	print("restorasyon projesi: ", project)
	_hud.restoration_panel.vehicle_id = project
	await _screen(&"restoration", "restorasyon")
	print("TOPLAM SORUN %d  (%s)" % [_total_issues, _tag])
	quit(0)
