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


## Kalan süre için elmas (süre bittiyse 0).
static func cost(remaining_seconds: float) -> int:
	if remaining_seconds <= 0.0:
		return 0
	return ceili(remaining_seconds / 60.0) * GEMS_PER_MINUTE
