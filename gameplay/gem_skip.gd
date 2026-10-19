class_name GemSkip
extends RefCounted
## ELMASLA BİTİRME — uzun süren işin kalan süresi elmasla anında biter. Tek kural, iki kullanıcı:
## uzun tamirler (RepairManager.finish_with_gems: orta işler, 90 sn+) ve performans parçası takma
## (PerformanceModManager.finish_with_gems: 2 dk … 1,5 sa).
## Fiyat: kalan süre dakikaya YUKARI yuvarlanır, dakika başına GEMS_PER_MINUTE (1 dk 2 elmas; 1:01 → 4 elmas).

const GEMS_PER_MINUTE: int = 2
## Bu süreden kısa işler "uzun" sayılmaz (kısa tamirler 6–12 sn): elmasla bitirme sunulmaz.
const MIN_JOB_SECONDS: float = 60.0
## İlk dokunuştan sonra onay bu kadar açık kalır (sn): kazara harcama olmasın.
const CONFIRM_TIME: float = 3.0
## Uzun işlerin eğrisi (cost_long): 1 saatin elması ve saat üssü.
const LONG_HOUR_GEMS: float = 120.0
const LONG_EXPONENT: float = 0.6


## Kalan süre için elmas (süre bittiyse 0).
static func cost(remaining_seconds: float) -> int:
	if remaining_seconds <= 0.0:
		return 0
	return ceili(remaining_seconds / 60.0) * GEMS_PER_MINUTE


## UZUN İŞLER (GARAJLARIM inşaatı ve iç yükseltmeleri, saatler sürer): ilk saat `cost` ile aynı, sonrası
## AZALAN oranla — 2/dk kuralıyla 24 saatlik inşaat 2.880 elmas tutuyordu, oyuncu günde ~35 kazanıyor.
## 1 sa = 120, 4 sa ≈ 276, 12 sa ≈ 533, 24 sa ≈ 808. 60. dakikada iki eğri birleşir (docs/GARAJLAR_TASARIM.md §2).
static func cost_long(remaining_seconds: float) -> int:
	if remaining_seconds <= 3600.0:
		return cost(remaining_seconds)
	return ceili(LONG_HOUR_GEMS * pow(remaining_seconds / 3600.0, LONG_EXPONENT))
