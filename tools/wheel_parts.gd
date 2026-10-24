extends SceneTree
## Her aracın DÖNEN parçalarını (wheels / tires / rims rolleri + wheel_groups) JSON olarak basar:
## {"assets/cars/optimized/<ad>.glb": [parça no, ...]}. tools/resimplify_car.py bu parçalara dokunmaz:
## teker ekseni (wheel_axes) bu parçaların geometrisinden ölçüldü, sadeleşirse kayar.
## Kullanım: godot-4 --headless --path . -s res://tools/wheel_parts.gd | grep '^WHEELS ' | cut -c8-
## İkinci satır "AXES ": {"<glb>": {"id", "groups": {fl: {parts, axis: [y, z, yarıçap]}}}} — tools/tire_inner_paint.py.

const SPIN_ROLES: Array[String] = ["wheels", "tires", "rims"]


func _initialize() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://vehicles/cars.json"))
	var out: Dictionary = {}
	var axes: Dictionary = {}
	for car: Dictionary in data["cars"]:
		var map: Dictionary = CarPartMap.MAPS.get(car["scene_path"], {})
		var parts: Dictionary = {}
		for role: String in SPIN_ROLES:
			for p: int in map.get(role, []):
				parts[p] = true
		for group: Array in map.get("wheel_groups", {}).values():
			for p: int in group:
				parts[p] = true
		var ids: Array = parts.keys()
		ids.sort()
		out[(car["optimized_path"] as String).trim_prefix("res://")] = ids
		var groups: Dictionary = {}
		for key: String in map.get("wheel_groups", {}):
			groups[key] = {"parts": map["wheel_groups"][key], "axis": map.get("wheel_axes", {}).get(key, [])}
		axes[(car["optimized_path"] as String).trim_prefix("res://")] = {"id": car["id"], "groups": groups}
	print("WHEELS " + JSON.stringify(out))
	print("AXES " + JSON.stringify(axes))
	quit()
