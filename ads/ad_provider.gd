class_name AdProvider
extends RefCounted
## REKLAM SAĞLAYICI SÖZLEŞMESİ — AdService hangi arka uçla konuştuğunu bilmez.
## APPLOVIN (Android, gerçek, 2026-10-19'dan beri) · ADMOB (Android, hesap reddedildi; kod duruyor) ·
## MOCK (masaüstü geliştirme / testler) · NONE (kapalı).
## Tüm geri çağrılar bir sonraki karede (call_deferred) gelir; senkron çağrı beklenmez.
## Reklamlar YUVA (slot) adıyla tutulur: her yuvanın kendi yüklü reklamı vardır.

## SDK hazırlığı bitti (onay penceresi + başlatma). ok=false → reklam bu oturumda yok.
func start(on_ready: Callable) -> void:
	on_ready.call(false)


## Yuva için ödüllü reklam yükle. on_result(ok: bool).
func load_rewarded(_slot: StringName, _unit_id: String, on_result: Callable) -> void:
	on_result.call(false)


## Yuvanın bu sağlayıcıdaki reklam birimi. Boş = yuva bu derlemede kapalı (kimlik yok / güvensiz).
func unit_for(_slot: StringName) -> String:
	return ""


## Yuvadaki yüklü reklamı göster. on_earned(): ödül hak edildi (TEK kez).
## on_finished(): reklam kapandı ya da gösterilemedi (her durumda TEK kez).
func show_rewarded(_slot: StringName, _on_earned: Callable, on_finished: Callable) -> void:
	on_finished.call()


## Oyuncunun reklam onayını sonradan değiştirebileceği giriş noktası GEREKLİ mi? (UMP: onay istenen
## bölgelerde Google zorunlu kılar; AYARLAR ekranı yalnızca gerekliyse düğmeyi gösterir.)
func privacy_options_required() -> bool:
	return false


## Reklam gizlilik seçenekleri formunu gösterir; kapanınca on_done().
func show_privacy_options(on_done: Callable) -> void:
	on_done.call()


## Sağlayıcı kişiselleştirilmiş reklamı AÇIK/KAPALI düğmesiyle mi yönetiyor? (AppLovin: evet — onay penceresi
## yok, karar AdPrivacy'de. AdMob: hayır — Google'ın kendi formu, privacy_options_required / show_privacy_options.)
func personalization_toggle() -> bool:
	return false


func personalized_ads() -> bool:
	return false


## Oyuncu AYARLAR'dan değiştirdi: kaydet ve SDK'ya hemen bildir.
func set_personalized_ads(_on: bool) -> void:
	pass


## Yuvada yüklenmiş ve gösterilmeye hazır reklam var mı?
func has_rewarded(_slot: StringName) -> bool:
	return false
