class_name ReferralRewards
## ARKADAŞ DAVETİ ÖDÜL MERDİVENİ (2026-10-23, docs/ARKADAS_DAVET.md): davet ettiğin n. arkadaş 3. seviyeye ulaşınca
## TIERS[n-1] POSTA ile gelir. Ödülü SUNUCU verir (firebase/functions/referral.js); bu tablo ekranda göstermek ve postayı
## açmak içindir. İki tablo AYNI olmalı: functions/test/referral.test.js bu dosyadaki TIERS'i okuyup karşılaştırır (bu
## yüzden TIERS düz JSON gibi yazılır: anahtarlar tırnaklı, sonda virgül ve araya yorum yok).
##   money_min: oyuncunun postayı aldığı andaki aktif gelirinin dakikası (giriş merdiveniyle aynı yuvarlama)
##   frame: yalnız davetle açılan profil çerçevesi (ProfileCatalog "exclusive")
##   choice "legendary_car": oyuncu SÜPER KASA havuzundan sahip olmadığı bir aracı seçer (ReferralManager.car_choices)

const TIERS: Array[Dictionary] = [
	{"gems": 50},
	{"money_min": 12},
	{"crates": {"sport_crate": 1}},
	{"gems": 75},
	{"decor": {"referral_neon": 1}, "frame": "inviter"},
	{"money_min": 30},
	{"crates": {"prestige_crate": 1}},
	{"gems": 120},
	{"money_min": 45},
	{"choice": "legendary_car", "frame": "envoy"}
]

## Davet edilen bu seviyeye ulaşınca davet sayılır (sunucuda QUALIFY_LEVEL ile aynı).
const QUALIFY_LEVEL: int = 3
## Yalnız bu kadar gün yeni hesap davetle gelebilir (sunucu Auth'tan denetler; oyun yalnız ekranda söyler).
const JOIN_DAYS: int = 7
## Davetle gelenin hoş geldin hediyesi (sunucu verir; ekranda gösterilir).
const WELCOME_GEMS: int = 50
const WELCOME_MONEY: int = 5000

const CHOICE_LEGENDARY: String = "legendary_car"
## Efsanevi araç seçiminin havuzu.
const LEGENDARY_CRATE: StringName = &"super_crate"
## Havuzdaki her araca zaten sahipse seçim yerine verilen elmas.
const LEGENDARY_FALLBACK_GEMS: int = 600
const FRAME_INVITER: String = "inviter"
const FRAME_ENVOY: String = "envoy"
const DECOR_NEON: StringName = &"referral_neon"
## Posta içinde gelir dakikasının üst sınırı (panelde yanlış yazılmış bir sayı oyunu bozmasın).
const MAX_MONEY_MIN: int = 240


static func max_tier() -> int:
	return TIERS.size()


## n. arkadaşın ödülü (1 ≤ n ≤ max_tier); dışındaysa boş.
static func tier(n: int) -> Dictionary:
	return TIERS[n - 1] if n >= 1 and n <= TIERS.size() else {}


## `minutes` dakikalık aktif gelir (₺), giriş merdiveniyle aynı okunur yuvarlama.
static func money_for(minutes: int, income: float) -> int:
	return LoginLadder.money_for(income, float(minutes)) if minutes > 0 else 0


## n. basamağın kısa adı (ekranlar): "+50 GEM", "+12.000 ₺" (şu anki gelirle), "SPOR KASASI", "NEON TABELA + DAVETÇİ
## ÇERÇEVESİ", "EFSANEVİ ARAÇ SEÇİMİ". tree: gelir dakikasının ₺ karşılığı için (yoksa yedek gelir).
static func label(n: int, tree: SceneTree) -> String:
	var entry: Dictionary = tier(n)
	var parts: Array[String] = []
	if entry.has("choice"):
		parts.append(Loc.t("EFSANEVİ ARAÇ SEÇİMİ"))
	if int(entry.get("gems", 0)) > 0:
		parts.append(Loc.t("+%d GEM") % int(entry["gems"]))
	if int(entry.get("money_min", 0)) > 0:
		parts.append("+%s ₺" % Hud.format_thousands(MailService.income_money(tree, int(entry["money_min"]))))
	for crate: Variant in (entry.get("crates", {}) as Dictionary):
		parts.append(MailService.crate_name(StringName(crate)))
	for item: Variant in (entry.get("decor", {}) as Dictionary):
		if GarageDecor.exists(StringName(item)):
			parts.append(MailService.decor_name(StringName(item)))
	if entry.has("frame") and not entry.has("choice"):
		parts.append(MailService.frame_name(String(entry["frame"])))
	return " + ".join(parts)


## Efsanevi araç seçiminde sunulan araçlar: SÜPER KASA havuzu, sahip olunanlar hariç (havuz sırasıyla).
static func car_pool(ownership: VehicleOwnership) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in CrateCatalog.pool(LEGENDARY_CRATE):
		if ownership == null or not ownership.is_owned(id):
			out.append(id)
	return out
