class_name NewsSources
## OTO MANŞET — oyunun kendi (arkadaşsız) haberleri: sen yokken (OfflineEarnings.window_from … window_to) dolan hurda
## yığınları, biten modifiyeler, yenilenen günlük / haftalık görevler. NewsDigest ham haberleri döner; durum tutmaz.
## Arkadaş haberleri SocialManager.news_items'tan, kazanç OfflineEarnings.news_items'tan gelir (NewsFlow birleştirir).


static func local(tree: SceneTree, from: int, to: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if from <= 0 or to <= from:
		return out
	var junkyard: JunkyardManager = tree.get_first_node_in_group("junkyard") as JunkyardManager
	if junkyard and junkyard.is_open():
		var refilled: int = 0
		for i: int in junkyard.pile_count():
			var at: int = junkyard.pile_ready_at(i)
			if at > from and at <= to:
				refilled += 1
		if refilled > 0:
			out.append({"kind": NewsDigest.PILES, "count": refilled})
	var mods: PerformanceModManager = tree.get_first_node_in_group("performance_mods") as PerformanceModManager
	if mods:
		for job: Dictionary in mods.jobs():
			var end: float = float(job.get("end", 0.0))
			if end > float(from) and end <= float(to):
				out.append({"kind": NewsDigest.MOD_READY, "car": StringName(job.get("car", &"")),
					"category": StringName(job.get("category", &""))})
	var gem: GemRewards = tree.get_first_node_in_group("gem_rewards") as GemRewards
	var player: PlayerProgress = tree.get_first_node_in_group("player_progress") as PlayerProgress
	if gem and tree.get_first_node_in_group("missions") != null and (player == null or player.level >= MissionCatalog.MIN_LEVEL):
		var day_from: int = gem.day_key(from)
		var day_to: int = gem.day_key(to)
		var daily: bool = day_to > day_from
		var weekly: bool = GemRewards.week_key(day_to) > GemRewards.week_key(day_from)
		if daily or weekly:
			out.append({"kind": NewsDigest.MISSIONS, "daily": daily, "weekly": weekly})
	return out
