class_name PlateAnim
## PANO AÇILIŞ/KAPANIŞ RİTMİ — bütün panolar (görevler, ustalık, garaj değeri, profil, hesap)
## aynı hareketi kullansın diye tek yer. Açılış 0,22 sn hafif "yerine oturma" (BACK/EASE_OUT),
## kapanış daha hızlı (0,12 sn). Garaj ve showroom kendi zengin giriş animasyonlarını korur.

const OPEN_TIME: float = 0.22
const CLOSE_TIME: float = 0.12
const START_SCALE: float = 0.92


## Panoyu görünür yapar ve içeriği yerine oturtur. `content` animasyonu taşıyan iç kapsayıcıdır.
static func pop_in(screen: Control, content: Control) -> void:
	screen.show()
	screen.modulate.a = 0.0
	if content:
		content.pivot_offset = content.size * 0.5
		content.scale = Vector2.ONE * START_SCALE
	var tween: Tween = screen.create_tween()
	tween.set_parallel(true)
	tween.tween_property(screen, "modulate:a", 1.0, OPEN_TIME * 0.6)
	if content:
		tween.tween_property(content, "scale", Vector2.ONE, OPEN_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Panoyu kapatır; bitince `on_done` çağrılır (gizleme ve sinyal orada yapılır).
static func pop_out(screen: Control, content: Control, on_done: Callable) -> void:
	var tween: Tween = screen.create_tween()
	tween.set_parallel(true)
	tween.tween_property(screen, "modulate:a", 0.0, CLOSE_TIME)
	if content:
		tween.tween_property(content, "scale", Vector2.ONE * START_SCALE, CLOSE_TIME)
	tween.set_parallel(false)
	tween.tween_callback(on_done)
