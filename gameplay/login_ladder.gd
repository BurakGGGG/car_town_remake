class_name LoginLadder
## GÜNLÜK GİRİŞ MERDİVENİ — ödül tablosu (2026-10-23; kararlar ve tasarım: docs/GIRIS_MERDIVENI.md).
##
## 4 hafta × 7 gün = 28 basamak. Sayaç GemRewards'tadır (ardışık giriş serisi; bir gün kaçırılınca 1. güne dönülür —
## kullanıcı kararı). Bu sınıf yalnızca "n. günün ödülü ne" sorusunu yanıtlar, durum tutmaz.
##   - hafta içi: elmas ve ₺ dönüşümlü. ₺ = oyuncunun ŞU ANKİ aktif oyun gelirinin (OfflineEarnings, ₺/dk) belli dakikası;
##     ay ilerledikçe artar (dengeleme 2026-10-23, kullanıcı: "20 gün oynayan ~300 bin ₺ sahibi, 4 bin cezbedici değil; ne
##     abartı ne az"). Seviye ödülüne bağlı eski hâl geç oyunda varlığın %1'i bile değildi.
##   - 7. / 14. / 21. gün: o haftanın ÖZEL DEKORU + elmas,
##   - 28. gün: "N. AY" dekoru + elmas (kahraman ödül).
## Her ay (tamamlanan merdiven) YENİ dekorlar verir (kullanıcı kararı: her hafta yeni dekor). Dekorlar katalogdadır
## (decor/decorations.json, `"exclusive": true` + `"login": {"month": m, "week": w}`; week 4 = ay ödülü): yeni ay =
## yalnızca o ayın kayıtları ve modelleri. O ayın dekoru henüz yoksa yerine FALLBACK elmas verilir.

const DAYS: int = 28
const WEEK: int = 7
const WEEKS: int = 4

enum Kind { GEMS, MONEY, DECOR }

## Haftanın 7 günü: [tür, değer]. GEMS: elmas; MONEY: bu kadar DAKİKALIK aktif oyun geliri (× WEEK_FACTOR); DECOR: hafta
## dekoru + bu kadar elmas. Eski 7 günlük seri haftada 110 elmastı (10-10-15-10-15-10-40); merdiven 80 elmas + ₺ + dekor.
const WEEK_PLAN: Array = [
	[Kind.GEMS, 10], [Kind.MONEY, 6.0], [Kind.GEMS, 15], [Kind.MONEY, 9.0], [Kind.GEMS, 15], [Kind.MONEY, 12.0],
	[Kind.DECOR, 40],
]
## Para günlerinin hafta çarpanı: merdiven çıktıkça ödül büyür (4. haftanın son para günü ≈ 19 dakikalık gelir).
const WEEK_FACTOR: Array[float] = [1.0, 1.15, 1.35, 1.6]
## Gelir bilinmiyorsa (yönetici yok: test sahnesi) kullanılan ₺/dk: ilk garajın ölçülmüş geliri.
const FALLBACK_INCOME: float = 372.0
## 28. gün: ay dekoru + bu kadar elmas.
const MONTH_GEMS: int = 50
## O ayın dekoru katalogda yoksa dekor yerine eklenen elmas.
const FALLBACK_WEEK_GEMS: int = 60
const FALLBACK_MONTH_GEMS: int = 100


## `day` (1..28) gününün ödülü; `month` 1'den başlar (kaçıncı merdiven), `income` oyuncunun aktif geliri (₺/dk; ₺ ölçeği).
## {"day", "week", "kind": Kind, "gems": int, "money": int, "decor": StringName, "milestone": bool, "month_end": bool}
static func reward(day: int, month: int, income: float) -> Dictionary:
	day = clampi(day, 1, DAYS)
	var week: int = (day - 1) / WEEK + 1
	var slot: Array = WEEK_PLAN[(day - 1) % WEEK]
	var out: Dictionary = {"day": day, "week": week, "kind": slot[0], "gems": 0, "money": 0, "decor": &"",
		"milestone": int(slot[0]) == Kind.DECOR, "month_end": day == DAYS}
	match int(slot[0]):
		Kind.GEMS:
			out["gems"] = int(slot[1])
		Kind.MONEY:
			out["money"] = money_for(income, float(slot[1]) * WEEK_FACTOR[week - 1])
		Kind.DECOR:
			var month_end: bool = day == DAYS
			out["decor"] = decor_for(month, WEEKS if month_end else week)
			out["gems"] = MONTH_GEMS if month_end else int(slot[1])
			if out["decor"] == &"":
				out["gems"] = int(out["gems"]) + (FALLBACK_MONTH_GEMS if month_end else FALLBACK_WEEK_GEMS)
	return out


## `minutes` dakikalık aktif gelir (₺), okunur bir sayıya yuvarlı: 10 binin altı 100'e, 100 binin altı 500'e, üstü 1000'e.
static func money_for(income: float, minutes: float) -> int:
	var value: float = maxf(income, 1.0) * minutes
	var step: float = 100.0 if value < 10000.0 else (500.0 if value < 100000.0 else 1000.0)
	return maxi(500, int(round(value / step) * step))


## Ayın `week`. hafta dekoru (week 4 = ay sonu); katalogda yoksa &"".
static func decor_for(month: int, week: int) -> StringName:
	return GarageDecor.login_item(month, week)
