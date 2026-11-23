extends SceneTree

const XP = preload("res://progression.gd")

func _initialize() -> void:
	var p := {}
	var passed := XP.threshold(1) == 100 and XP.threshold(2) == 150
	passed = passed and not XP.buy(p, "hard_worker")
	passed = passed and XP.award(p, "route", "route:1") == 250
	passed = passed and XP.stats(p).level == 3 and XP.stats(p).points == 2
	passed = passed and XP.award(p, "route", "route:1") == 0
	passed = passed and XP.buy(p, "hard_worker") and XP.stats(p).points == 1
	passed = passed and not XP.buy(p, "master_angler") and XP.CATALOG.skills().size() == 42
	var cap_xp := 0
	for level in range(1, XP.CAP):
		cap_xp += XP.threshold(level)
	var veteran := {"xp": cap_xp - 1}
	passed = passed and XP.award(veteran, "route", "route:2") == 1
	passed = passed and XP.stats(veteran).level == 50 and XP.stats(veteran).points == 49
	passed = passed and XP.award(veteran, "route", "route:3") == 0
	passed = passed and not XP.buy(veteran, "quick_reel") and not XP.buy(veteran, "efficient_operator")
	for i in range(3):
		passed = passed and XP.buy(veteran, "steady_hands")
	passed = passed and not XP.buy(veteran, "steady_hands") and XP.buy(veteran, "quick_reel")
	for id: String in XP.CATALOG.skills():
		var skill: Dictionary = XP.CATALOG.skills()[id]
		for dep: String in skill.requires:
			var prior: Dictionary = XP.CATALOG.skills()[dep]
			passed = passed and prior.column < skill.column and prior.cap >= skill.requires[dep]
			if skill.enabled:
				passed = passed and prior.enabled
	print("Thresholds, points, duplicates, prerequisites, rank and XP caps, catalog: ", passed)
	quit(0 if passed else 1)
