class_name GemExchange
extends RefCounted
## GEM → ₺ ÇEVİRİ — MARKET ekranının PARAYA ÇEVİR sekmesi. TEK YÖN: ₺ geme çevrilmez (kullanıcı kararı
## 2026-10-20); gem yalnızca kazanılır ya da gerçek parayla alınır (GemProducts).
##
## KUR oyuncu SEVİYESİNE bağlıdır. Para ihtiyacı başta birkaç bin ₺, sonda milyonlar (garajlar ≈ 25 M):
## sabit kur ya ilk saatleri bozar (başlangıç gemleriyle ilk garaj yükseltmeleri alınırdı) ya da sonra işe
## yaramaz. 1 GEM = seviye × RATE_PER_LEVEL ₺ — o seviyedeki ~15–30 sn tamir kazancı; elmasla tamir bitirme
## (GemSkip: dakikada 2 gem = gem başına 30 sn) ile aynı mertebe. Büyük teklifte küçük bonus.

const RATE_PER_LEVEL: int = 100
## Teklifler: gem, bonus (%), kart çizimi. Kartlar bu sırayla dizilir.
const OFFERS: Array[Dictionary] = [
	{"gems": 10, "bonus": 0, "art": GemPackArt.Kind.CASH_1},
	{"gems": 50, "bonus": 5, "art": GemPackArt.Kind.CASH_2},
	{"gems": 200, "bonus": 10, "art": GemPackArt.Kind.CASH_3},
	{"gems": 1000, "bonus": 15, "art": GemPackArt.Kind.CASH_4},
]


## Bu seviyede 1 GEM kaç ₺.
static func rate(level: int) -> int:
	return maxi(level, 1) * RATE_PER_LEVEL


## Teklifin bu seviyede verdiği ₺ (bonus dahil).
static func money_for(offer: Dictionary, level: int) -> int:
	return int(round(float(int(offer["gems"]) * rate(level)) * (1.0 + float(int(offer["bonus"])) / 100.0)))


## Teklifi uygular: gem düşer, ₺ eklenir, kayıt istenir. Dönüş: eklenen ₺ (gem yetmiyorsa 0, hiçbir şey değişmez).
static func exchange(tree: SceneTree, offer: Dictionary) -> int:
	var progress: PlayerProgress = tree.get_first_node_in_group("player_progress") as PlayerProgress
	var economy: EconomyManager = tree.get_first_node_in_group("economy") as EconomyManager
	if progress == null or economy == null:
		return 0
	var money: int = money_for(offer, progress.level)
	if not progress.spend_gems(int(offer["gems"])):
		return 0
	economy.add_money(money)
	var save: SaveManager = tree.get_first_node_in_group("save_manager") as SaveManager
	if save:
		save.request_save()
	return money
