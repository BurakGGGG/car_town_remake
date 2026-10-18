extends SceneTree
## PROFİL testi (başsız): katalog (fotoğraf kodlama, hash, bayraklar, garaj adı), PlayerProfile (çerçeve kilidi /
## satın alma, kayıt, temizleme) ve sahte Firebase'le uçtan uca: açık profil + avatar belgesi yayını, arkadaşın
## fotoğrafı indirip önbelleğe alması, şikâyet, engelleme, yeni cihazda fotoğrafın geri yüklenmesi, hesap silme.
## tools/run_tests.sh profile_test

const SocialTest: GDScript = preload("res://tests/social_test.gd")
const SIGNALS: Array[StringName] = [&"auth_success", &"auth_failure", &"sign_out_success", &"user_deleted",
	&"firestore_get_task_completed", &"firestore_write_task_completed", &"firestore_delete_task_completed"]

var fails: int = 0
var fb: Object
var w: Dictionary = {}


func _initialize() -> void:
	if OS.get_user_data_dir().ends_with("/CarTownRemake") or OS.get_user_data_dir().ends_with("/AUTO YARD"):
		print("  FAIL izole user:// klasörü yok (tools/run_tests.sh ile çalıştır)")
		quit(1)
		return
	fb = SocialTest.FakeFB.new()
	fb.tree = self
	seed(777)
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func until(cond: Callable, limit: float = 5.0) -> bool:
	var end: int = Time.get_ticks_msec() + int(limit * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func wipe_device() -> void:
	for f: String in ["savegame.json", "cloud_sync.json", "social.json"]:
		DirAccess.remove_absolute(OS.get_user_data_dir().path_join(f))
	for dir: String in [PlayerProfile.DIR, SocialManager.AVATAR_CACHE_DIR]:
		var path: String = ProjectSettings.globalize_path(dir)
		for file: String in DirAccess.get_files_at(path):
			DirAccess.remove_absolute(path.path_join(file))


## Bir cihazda oturum (social_test ile aynı düzen + PlayerProfile).
func open_session(account: String, fresh_device: bool = true) -> void:
	if fresh_device:
		wipe_device()
	fb.account = account
	fb.user = {}
	var root_node: Node = Node.new()
	var prog: PlayerProgress = PlayerProgress.new()
	var own: VehicleOwnership = VehicleOwnership.new()
	var profile: PlayerProfile = PlayerProfile.new()
	var save: SaveManager = SaveManager.new()
	var cloud: CloudSaveManager = CloudSaveManager.new()
	var social: SocialManager = SocialManager.new()
	social.use_firebase(fb)
	social.publish_delay = 0.3
	social.request_timeout = 1.0
	for n: Node in [EconomyManager.new(), prog, GarageUpgradeManager.new(), own, JunkyardManager.new(), profile, save, cloud, social]:
		root_node.add_child(n)
	root.add_child(root_node)
	cloud._fb = fb
	fb.auth_success.connect(cloud._on_auth_success)
	fb.auth_failure.connect(cloud._on_auth_failure)
	fb.sign_out_success.connect(cloud._on_sign_out_result)
	fb.user_deleted.connect(cloud._on_user_deleted)
	fb.firestore_get_task_completed.connect(cloud._on_get_completed)
	fb.firestore_write_task_completed.connect(cloud._on_write_completed)
	fb.firestore_delete_task_completed.connect(cloud._on_delete_completed)
	w = {"root": root_node, "prog": prog, "own": own, "profile": profile, "save": save, "cloud": cloud, "social": social}
	await frames(6)
	cloud.sign_in()
	await until(func() -> bool: return cloud.get_state() == CloudSaveManager.State.SYNCED)
	await until(func() -> bool: return social.get_state() not in [SocialManager.State.SIGNED_OUT, SocialManager.State.LOADING])
	await until(func() -> bool: return not social.is_busy())


func close_session() -> void:
	await until(func() -> bool: return not social().is_busy() and not (w["cloud"] as CloudSaveManager).is_busy(), 3.0)
	# Bu düzenekte oyuncular aynı cihaz klasörünü sırayla kullanır: oturum kapanmadan kayıt buluta yazılsın
	# (oyunda kayıt 0,5 sn sonra diske, 1,5 sn sonra buluta gider; test oturumu ondan hızlı kapatıyor)
	(w["save"] as SaveManager).save_game()
	(w["cloud"] as CloudSaveManager).upload_save()
	await frames(2)
	await until(func() -> bool: return not (w["cloud"] as CloudSaveManager).is_busy(), 3.0)
	for s: StringName in SIGNALS:
		for c: Dictionary in fb.get_signal_connection_list(s):
			fb.disconnect(s, c["callable"])
	w["root"].queue_free()
	w = {}
	await frames(2)


func social() -> SocialManager:
	return w["social"]


func profile() -> PlayerProfile:
	return w["profile"]


func photo(color: Color) -> Image:
	var image: Image = Image.create(400, 300, false, Image.FORMAT_RGBA8)
	image.fill(color)
	image.fill_rect(Rect2i(100, 60, 120, 120), Color.WHITE)
	return image


func _run() -> void:
	print("== 1) Katalog ==")
	check(ProfileCatalog.preset_ids().size() == 12 and ProfileCatalog.is_preset("p12") and not ProfileCatalog.is_preset("p13"),
		"12 hazır avatar, p13 yok")
	for id: String in ProfileCatalog.preset_ids() + ["featured_emre", "featured_elif"]:
		var path: String = ProfileCatalog.AVATAR_DIR + ("preset_%s.png" % id.substr(1) if id.begins_with("p") else id + ".png")
		if not ResourceLoader.exists(path):
			check(false, "avatar resmi eksik: %s" % path)
	check(ProfileCatalog.is_valid_av("") and ProfileCatalog.is_valid_av("p07") and ProfileCatalog.is_valid_av("img:0a1b2c3d"),
		"geçerli avatar tanımları")
	check(not ProfileCatalog.is_valid_av("img:0A1B2C3D") and not ProfileCatalog.is_valid_av("https://x/y.jpg"),
		"büyük harfli hash / URL geçersiz (kuralla aynı)")
	var bytes: PackedByteArray = ProfileCatalog.encode_photo(photo(Color.RED))
	var decoded: Image = ProfileCatalog.image_from_bytes(bytes)
	check(decoded != null and decoded.get_width() == ProfileCatalog.PHOTO_SIZE, "fotoğraf 192 px JPEG'e çevrilir")
	check(Marshalls.raw_to_base64(bytes).length() <= ProfileCatalog.PHOTO_B64_MAX, "base64 boyu sınırın altında (%d)" % Marshalls.raw_to_base64(bytes).length())
	check(ProfileCatalog.hash_of(bytes) == ProfileCatalog.hash_of(bytes.duplicate()) and ProfileCatalog.is_hash(ProfileCatalog.hash_of(bytes)),
		"hash 8 hex ve kararlı")
	var noise: Image = Image.create(192, 192, false, Image.FORMAT_RGB8)
	for y: int in 192:
		for x: int in 192:
			noise.set_pixel(x, y, Color(randf(), randf(), randf()))
	check(Marshalls.raw_to_base64(ProfileCatalog.encode_photo(noise)).length() <= ProfileCatalog.PHOTO_B64_MAX,
		"gürültülü fotoğraf da sığar (kalite düşürülür)")
	check(ProfileCatalog.image_from_bytes(PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13])) == null,
		"tanınmayan baytlar reddedilir")
	# Başka oyuncunun fotoğrafı: başlıktaki boyut çözmeden okunur, dev boyutlu (bellek bombası) dosya reddedilir
	check(ProfileCatalog.jpeg_size(bytes) == Vector2i(ProfileCatalog.PHOTO_SIZE, ProfileCatalog.PHOTO_SIZE),
		"JPEG başlığından boyut okunur (%s)" % ProfileCatalog.jpeg_size(bytes))
	var net: Image = ProfileCatalog.image_from_net(bytes)
	check(net != null and net.get_width() == ProfileCatalog.PHOTO_SIZE, "oyunun yüklediği fotoğraf ağdan kabul edilir")
	var bomb: PackedByteArray = bytes.duplicate()
	var sof: int = 2
	while not (bomb[sof + 1] >= 0xC0 and bomb[sof + 1] <= 0xC3):
		sof += 2 + ((bomb[sof + 2] << 8) | bomb[sof + 3])
	bomb[sof + 5] = 0x3E; bomb[sof + 6] = 0x80; bomb[sof + 7] = 0x3E; bomb[sof + 8] = 0x80   # 16000 × 16000
	check(ProfileCatalog.jpeg_size(bomb) == Vector2i(16000, 16000) and ProfileCatalog.image_from_net(bomb) == null,
		"başlığında 16000×16000 yazan küçük JPEG çözülmeden reddedilir")
	check(ProfileCatalog.image_from_net(photo(Color.RED).save_png_to_buffer()) == null, "ağdan PNG kabul edilmez (oyun JPEG yükler)")
	check(ProfileCatalog.image_from_net(bytes.slice(0, 20)) == null and ProfileCatalog.image_from_net(PackedByteArray()) == null,
		"yarım / boş JPEG reddedilir")
	var bad_flags: Array[String] = []
	for code: String in ProfileCatalog.flag_codes():
		var img: Image = FlagIcon.image(code)
		if img.get_size() != Vector2i(FlagIcon.W + 2, FlagIcon.H + 2) or code.length() != 2:
			bad_flags.append(code)
	check(bad_flags.is_empty() and ProfileCatalog.flag_codes().size() == 44, "44 piksel bayrak çizilir %s" % [bad_flags])
	check(ProfileCatalog.clean_title("  Gece   Garajı ") == "Gece Garajı" and SocialNames.is_valid_title("Gece Garajı"),
		"garaj adı temizlenir")
	check(not SocialNames.is_valid_title("amk garaj") and not SocialNames.is_valid_title("<b>"), "küfürlü / işaretli garaj adı geçersiz")
	check(SocialNames.is_valid_title(""), "boş garaj adı geçerli")
	Loc.use("tr")
	check(Loc.upper("elif ılgaz") == "ELİF ILGAZ", "Türkçe büyük harf (i → İ, ı → I)")

	print("== 2) PlayerProfile ==")
	await open_session("alice")
	var p: PlayerProfile = profile()
	check(p.my_av() == "" and p.frame_id == "plate" and p.my_illustrated(), "varsayılan: kask, PLAKA çerçeve")
	p.set_preset("p03")
	check(p.my_av() == "p03" and p.my_illustrated(), "hazır avatar seçilir")
	check(p.set_photo(photo(Color.BLUE)), "fotoğraf kaydedilir")
	var hash: String = p.photo_hash
	check(p.my_av() == "img:" + hash and not p.my_illustrated() and ProfileCatalog.hash_of(p.upload_bytes()) == hash,
		"fotoğraf: img:<hash>, yüklenecek baytlar aynı hash")
	check(not p.frame_unlocked("gold") and not p.set_frame("gold"), "ALTIN seviye 20'de açılır (seviye 1)")
	(w["prog"] as PlayerProgress).load_state(20, 0, 120)
	check(p.frame_unlocked("gold") and p.set_frame("gold") and p.frame_id == "gold", "seviye 20: ALTIN takılır")
	check(not p.buy_frame("carbon") and (w["prog"] as PlayerProgress).gems == 120, "KARBON 200 GEM: 120 yetmez, gem gitmez")
	check(p.buy_frame("checker") and (w["prog"] as PlayerProgress).gems == 20 and p.frame_id == "checker", "DAMA 100 GEM'e alınır ve takılır")
	check(p.set_frame("gold") and p.set_frame("checker"), "alınan çerçeveye geri dönülür (yeniden ödenmez)")
	check((w["prog"] as PlayerProgress).gems == 20, "ikinci kez gem harcanmadı")
	p.set_flag("TR")
	p.set_flag("XX")
	check(p.flag == "", "bilinmeyen bayrak boşa düşer")
	p.set_flag("TR")
	check(p.set_title("Mavi Garaj") and not p.set_title("<script>") and p.title == "Mavi Garaj", "garaj adı: geçersiz reddedilir")
	(w["own"] as VehicleOwnership).add_vehicle(&"vw_golf_7")
	p.set_showcase(&"vw_golf_7")
	var saved: Dictionary = p.state()
	var copy: PlayerProfile = PlayerProfile.new()
	root.add_child(copy)
	copy.load_state(saved)
	check(copy.state() == saved, "kayıt gidiş-dönüş aynı")
	copy.load_state({"avatar": "img:zz", "frame": "nope", "frames": ["neon", "gold", 5], "flag": "TUR", "title": "<b>",
		"showcase": "ufo", "blocked": "x"})
	check(copy.avatar == "" and copy.frame_id == "plate" and copy.frames_owned == ["neon"] and copy.flag == "" \
		and copy.title == "" and copy.showcase == &"" and copy.blocked.is_empty(), "bozuk profil kaydı temizlenir")
	copy.queue_free()
	var fields: Dictionary = p.public_fields()
	check(fields["av"] == "img:" + hash and fields["frame"] == "checker" and fields["flag"] == "TR"
		and fields["title"] == "Mavi Garaj" and fields["car"] == "vw_golf_7" and fields["stats"] is Dictionary, "açık alanlar")

	print("== 3) Yayın: açık profil + avatar belgesi ==")
	check(await social().create_profile("Usta Ali"), "alice profil oluşturdu")
	var alice_code: String = social().my_code()
	await until(func() -> bool: return fb.store.has("avatars/a_alice"), 3.0)
	var g: Dictionary = fb.store.get("garages/g_alice", {})
	check(SaveSafe.s(g.get("av", "")) == "img:" + hash and SaveSafe.s(g.get("frame", "")) == "checker"
		and SaveSafe.s(g.get("flag", "")) == "TR" and SaveSafe.s(g.get("title", "")) == "Mavi Garaj", "garaj belgesinde profil alanları")
	var a: Dictionary = fb.store.get("avatars/a_alice", {})
	check(SaveSafe.s(a.get("hash", "")) == hash
		and ProfileCatalog.hash_of(Marshalls.base64_to_raw(SaveSafe.s(a.get("img", "")))) == hash, "avatars/a_alice: aynı resim")
	var avatar_writes: Callable = func() -> int: return fb.calls.filter(func(c: String) -> bool: return c == "set avatars/a_alice").size()
	var writes_before: int = avatar_writes.call()
	p.set_frame("plate")
	await social().publish_now()
	check(avatar_writes.call() == writes_before, "fotoğraf değişmedikçe resim yeniden yüklenmez (yalnız çerçeve değişti)")
	p.set_frame("checker")   # sonraki bölümler bu çerçeveyi bekler
	p.set_preset("p05")
	await social().publish_now()
	check(SaveSafe.s((fb.store["garages/g_alice"] as Dictionary).get("av", "")) == "p05", "hazır avatara geçiş yayınlandı")
	check(not fb.store.has("avatars/a_alice"), "hazır avatara geçince eski fotoğraf sunucudan silindi (2026-10-17)")
	p.set_photo(photo(Color.BLUE))
	await social().publish_now()
	check(avatar_writes.call() == writes_before + 1 and SaveSafe.s(fb.store.get("avatars/a_alice", {}).get("hash", "")) == hash,
		"aynı fotoğrafa dönünce yeniden yüklendi")
	p.set_photo(photo(Color.GREEN))
	var hash2: String = p.photo_hash
	await social().publish_now()
	check(SaveSafe.s((fb.store["avatars/a_alice"] as Dictionary).get("hash", "")) == hash2 and hash2 != hash, "yeni fotoğraf yüklendi")
	await close_session()

	print("== 4) Arkadaş fotoğrafı görür ==")
	await open_session("bob")
	check(await social().create_profile("Bob Usta"), "bob profil")
	check(await social().send_request(alice_code), "bob → alice istek")
	await close_session()
	await open_session("alice", false)
	await social().refresh(true)
	check(social().incoming.size() == 1 and social().incoming[0].has("av"), "gelen istekte gönderenin profili okundu")
	check(await social().accept("bob"), "alice kabul etti")
	await close_session()
	await open_session("bob", false)
	await social().refresh(true)
	var entry: Dictionary = social().person("alice")
	check(SaveSafe.s(entry.get("av", "")) == "img:" + hash2 and entry.get("frame") == "checker" and entry.get("flag") == "TR",
		"bob'un listesinde alice'in profili")
	var first: Dictionary = social().avatar_of("alice", entry["av"])
	check(bool(first["illustrated"]), "fotoğraf inene kadar kask")
	var got: bool = await until(func() -> bool: return not bool(social().avatar_of("alice", entry["av"])["illustrated"]), 3.0)
	check(got, "fotoğraf indi (avatar_ready)")
	check(FileAccess.file_exists(SocialManager.AVATAR_CACHE_DIR + "alice.jpg"), "cihaz önbelleğinde")
	var gets_before: int = fb.calls.filter(func(c: String) -> bool: return c == "get avatars/a_alice").size()
	social().avatar_of("alice", entry["av"])
	await frames(10)
	check(fb.calls.filter(func(c: String) -> bool: return c == "get avatars/a_alice").size() == gets_before, "önbellekteyken yeniden indirilmez")
	check(bool(social().avatar_of("featured_emre", "")["illustrated"]), "Emre'nin portresi oyunla gelir")

	print("== 5) Şikâyet ==")
	check(await social().report("alice", "photo"), "bob alice'in fotoğrafını şikâyet etti")
	var report: Dictionary = fb.store.get("reports/x_bob_alice", {})
	check(report.get("target") == "alice" and report.get("reason") == "photo" and SaveSafe.s(report.get("img", "")).length() > 100,
		"rapor belgesi (fotoğraf kopyasıyla)")
	check(bool(social().avatar_of("alice", entry["av"])["illustrated"]), "şikâyet edilen fotoğraf bob'da gizlendi")
	check(not await social().report("featured_emre", "photo"), "öne çıkan ustalar şikâyet edilemez")

	print("== 6) Engelleme ==")
	check(await social().block("alice"), "bob alice'i engelledi")
	check(not social().is_friend("alice") and not fb.store.has("users/bob/friends/f_alice")
		and not fb.store.has("users/alice/friends/f_bob"), "arkadaşlık iki taraftan silindi")
	check(profile().is_blocked("alice"), "engel kayıtta")
	await close_session()
	await open_session("alice", false)
	check(await social().send_request(SaveSafe.s((fb.store["garages/g_bob"] as Dictionary).get("code", ""))), "alice yeniden istek atar")
	await close_session()
	await open_session("bob", false)
	await social().refresh(true)
	check(social().incoming.is_empty() and not fb.store.has("users/bob/inbox/r_alice"), "engellenenin isteği sessizce silindi")
	await close_session()

	print("== 7) Yeni cihaz: fotoğraf geri yüklenir ==")
	await open_session("alice", true)
	await until(func() -> bool: return not profile().needs_photo_restore(), 3.0)
	check(profile().avatar == "photo" and profile().photo_hash == hash2 and profile().my_av() == "img:" + hash2,
		"kayıttaki fotoğraf avatar belgesinden geri geldi")

	print("== 8) Hesap silme avatar belgesini de siler ==")
	(w["cloud"] as CloudSaveManager).delete_account()
	await until(func() -> bool: return not fb.store.has("players/alice"), 8.0)
	check(not fb.store.has("avatars/a_alice") and not fb.store.has("garages/g_alice"), "avatars/a_alice silindi")
	check(fb.store.has("reports/x_bob_alice"), "başkasının şikâyeti kalır (inceleme için)")
	await close_session()

	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
