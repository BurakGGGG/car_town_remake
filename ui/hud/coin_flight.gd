class_name CoinFlight
## PARA / GEM UÇUŞU — ödül penceresi (RewardPopup) ve açılış gazetesi (NewsFlow) aynı hareketi kullanır: ikonlar
## `from`dan saçılır, sırayla `label`ın ikonuna kavisle uçar; her biri değince ses + sayaç "pıt", SONUNCUSU değince
## on_landed (sayaç sayarak artar). İkonlar HUD katmanına eklenir: pencere kapanırken de uçuş sürer.

const SPREAD_TIME: float = 0.2
const FLY_TIME: float = 0.5
const STAGGER: float = 0.05
const ICON: float = 30.0


## Tutara göre uçan para sayısı (6–14).
static func coin_count(money: int) -> int:
	return clampi(int(log(float(maxi(money, 1))) / log(10.0) * 2.0) + 2, 6, 14)


## `sound` her varışta (sıra numarasıyla) çağrılır.
static func fly(hud: Hud, kind: HudIcon.Kind, from: Vector2, label: Label, count: int, on_landed: Callable,
		sound: Callable) -> void:
	var target_node: Control = hud.counter_target(label)
	for i: int in count:
		var icon: HudIcon = HudIcon.new()
		icon.kind = kind
		icon.icon_size = ICON
		icon.size = Vector2.ONE * ICON
		icon.pivot_offset = icon.size * 0.5
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.add_child(icon)
		var half: Vector2 = icon.size * 0.5
		icon.global_position = from - half
		var spread: Vector2 = from + Vector2.from_angle(randf() * TAU) * randf_range(50.0, 110.0)
		var last: bool = i == count - 1
		var index: int = i
		var tween: Tween = icon.create_tween()
		tween.tween_property(icon, "global_position", spread - half, SPREAD_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_interval(float(i) * STAGGER)
		tween.tween_method(func(t: float) -> void:
			# hedef her karede okunur: ekran boyutu değişse de sayaca varır
			var to: Vector2 = Hud.screen_rect(target_node).get_center() if is_instance_valid(target_node) else spread
			var control: Vector2 = Vector2(lerpf(spread.x, to.x, 0.25), minf(spread.y, to.y) - 80.0)
			icon.global_position = spread.lerp(control, t).lerp(control.lerp(to, t), t) - half
			icon.scale = Vector2.ONE * lerpf(1.15, 0.6, t), 0.0, 1.0, FLY_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_callback(func() -> void:
			sound.call(index)
			hud.pulse_counter(label)
			if last:
				on_landed.call()
			icon.queue_free())
