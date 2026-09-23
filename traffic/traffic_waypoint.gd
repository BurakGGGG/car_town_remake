@tool
class_name TrafficWaypoint
extends Marker3D
## Şehir trafiği için yol noktası. Araç bu noktaya yaklaşınca next_points arasından
## (birden fazlaysa rastgele) bir sonrakine geçer. Kavşak dallanmaları buradan çözülür.

## Sonraki nokta(lar). Birden fazlaysa araç rastgele seçer (düz / sağ / sol).
@export var next_points: Array[NodePath] = []
## Araçlar burada doğar.
@export var is_spawn: bool = false
## Araç buraya ulaşınca silinir.
@export var is_despawn: bool = false
## Kavşağa giriş: araç geçmeden önce kavşak kilidini almalı.
@export var intersection_entry: bool = false
## Kavşaktan çıkış: kilit burada bırakılır.
@export var intersection_exit: bool = false
## Bu noktaya yaklaşırken uygulanan hız sınırı (birim/sn). 0 = sınır yok (dönüşler için).
@export var speed_limit: float = 0.0


func get_next() -> Array[TrafficWaypoint]:
	var out: Array[TrafficWaypoint] = []
	for path: NodePath in next_points:
		var node: TrafficWaypoint = get_node_or_null(path) as TrafficWaypoint
		if node:
			out.append(node)
	return out


## Rastgele bir sonraki nokta; yoksa null.
func pick_next() -> TrafficWaypoint:
	var options: Array[TrafficWaypoint] = get_next()
	return options.pick_random() if not options.is_empty() else null
