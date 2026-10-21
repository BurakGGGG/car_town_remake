class_name PromoService
extends RefCounted
## KUPON KODU (2026-10-21; giriş yeri kullanıcı kararı: MARKET › KOD GİR). Oyuncu kodu yazar → users/{uid}/redeem/{KOD}
## = {at} (SocialManager kuyruğuyla; kural kod başına bir kez yazdırır) → sunucu (functions/promo.js) doğrular ve sonucu
## aynı belgeye yazar → oyun belgeyi POLL_SEC aralıkla okur. Kabul edilen kodun ödülü POSTA'ya düşer (MailService hemen
## okunur, oyuncu MARKET'ten çıkınca POSTA penceresi açılır). Yalnızca hesaplı oyuncu (misafirin UID'si yok).
## Durumlar: ok · already · not_found · expired · inactive · used_up · rate (sunucu) · invalid · signin · offline · timeout.

const CODE_PATTERN: String = "^[A-Z0-9]{4,16}$"
const POLL_SEC: float = 0.75
const POLL_TRIES: int = 20


## Yazılan metin → kod biçimi (büyük harf, boşluk / tire atılır).
static func normalize(raw: String) -> String:
	return raw.strip_edges().to_upper().replace(" ", "").replace("-", "")


static func is_valid(code: String) -> bool:
	return RegEx.create_from_string(CODE_PATTERN).search(code) != null


## Kodu dener; sonucu bekler. Dönüş: {status, title (kabulde posta başlığı)}.
static func redeem(tree: SceneTree, raw: String) -> Dictionary:
	var code: String = normalize(raw)
	if not is_valid(code):
		return {"status": "invalid"}
	var social: SocialManager = tree.get_first_node_in_group("social") as SocialManager
	if social == null or social.uid().is_empty():
		return {"status": "signin"}
	var write: Dictionary = await social.write_redeem(code)
	var existed: bool = false
	if not bool(write.get("status", false)):
		# Kural belge varsa yeniden yazdırmaz: bu kod bu hesapta daha önce denendi, önceki sonuç okunur
		if not SocialManager._permission_denied(write):
			return {"status": "offline"}
		existed = true
	for i: int in POLL_TRIES:
		var read: Dictionary = await social.read_redeem(code)
		var doc: Dictionary = read.get("doc", {})
		var status: String = SaveSafe.s(doc.get("status", ""))
		if not status.is_empty():
			if existed and status == "ok":
				status = "already"   # daha önce bu hesapta kabul edilmişti
			if status == "ok":
				var mail: MailService = tree.get_first_node_in_group("mail") as MailService
				if mail:
					mail.poll()
			return {"status": status, "title": AppConfig.text_of(doc.get("title"))}
		if existed and bool(read.get("ok", false)) and doc.is_empty():
			return {"status": "offline"}
		await tree.create_timer(POLL_SEC).timeout
	return {"status": "timeout"}


## Oyuncuya gösterilen sonuç metni.
static func status_text(status: String) -> String:
	match status:
		"ok":
			return Loc.t("Kod kabul edildi: ödülün POSTA'da seni bekliyor.")
		"already":
			return Loc.t("Bu kodu zaten kullandın.")
		"not_found", "invalid":
			return Loc.t("Böyle bir kod yok. Harfleri kontrol et.")
		"expired":
			return Loc.t("Bu kodun süresi dolmuş.")
		"inactive":
			return Loc.t("Bu kod şu an kullanılamıyor.")
		"used_up":
			return Loc.t("Bu kodun kullanım hakkı dolmuş.")
		"rate":
			return Loc.t("Çok fazla deneme yaptın. Biraz sonra tekrar dene.")
		"signin":
			return Loc.t("Kod kullanmak için hesabınla giriş yap (PLAYER).")
	return Loc.t("Kod kontrol edilemedi. İnternet bağlantını kontrol edip tekrar dene.")
