extends RefCounted

const CAP := 50
const REWARDS := {"route": 250, "fish_delivery": 125, "delivery": 100, "fish": 30, "trophy": 100, "small_fish": 15, "grass": 10, "commercial": 400, "boat": 20, "road": 15, "discovery": 50}
const REWARD_SKILLS := {
	"fish": ["experienced_angler", "master_angler"], "small_fish": ["experienced_angler", "master_angler"],
	"trophy": ["experienced_angler", "master_angler", "trophy_hunter"],
	"route": ["hard_worker", "landscaping_master"], "commercial": ["hard_worker", "landscaping_master"],
	"grass": ["landscaping_master"], "delivery": ["hard_worker"], "fish_delivery": ["hard_worker"],
	"boat": ["master_mariner"], "discovery": ["explorer", "marine_explorer"],
}
const CATALOG := preload("res://progression_catalog.gd")

static func effect(profile: Dictionary, id: String) -> float:
	var rank := int(profile.get("ranks", {}).get(id, 0))
	if rank <= 0:
		return 0.0
	return rank * float(CATALOG.skills()[id].get("per_rank", 0))

static func threshold(level: int) -> int:
	var step := level - 1
	return 100 + 40 * step + 10 * step * step

static func stats(profile: Dictionary) -> Dictionary:
	var rest := int(profile.get("xp", 0))
	var level := 1
	while level < CAP and rest >= threshold(level):
		rest -= threshold(level)
		level += 1
	var points := level - 1
	for rank in profile.get("ranks", {}).values():
		points -= int(rank)
	return {"level": level, "rest": rest, "points": points}

static func award(profile: Dictionary, kind: String, event_id: String) -> int:
	if not REWARDS.has(kind) or event_id.is_empty():
		return 0
	var events: Dictionary = profile.get("events", {})
	if events.has(event_id):
		return 0
	var limit := 0
	for level in range(1, CAP):
		limit += threshold(level)
	var current := int(profile.get("xp", 0))
	var bonus := 0.0
	for skill: String in REWARD_SKILLS.get(kind, []):
		bonus += effect(profile, skill)
	var gain := mini(limit - current, roundi(REWARDS[kind] * (1.0 + bonus / 100.0)))
	if gain <= 0:
		return 0
	events[event_id] = true
	profile.merge({"xp": current + gain, "events": events, "version": 1, "reason": kind}, true)
	return gain

static func can_buy(profile: Dictionary, id: String) -> bool:
	var skill: Dictionary = CATALOG.skills().get(id, {})
	var ranks: Dictionary = profile.get("ranks", {})
	if skill.is_empty() or not skill.enabled or stats(profile).points < 1 or stats(profile).level < skill.level or int(ranks.get(id, 0)) >= skill.cap:
		return false
	for dep in skill.requires:
		if int(ranks.get(dep, 0)) < skill.requires[dep]:
			return false
	return true

static func buy(profile: Dictionary, id: String) -> bool:
	if not can_buy(profile, id):
		return false
	var ranks: Dictionary = profile.get("ranks", {})
	ranks[id] = int(ranks.get(id, 0)) + 1
	profile.ranks = ranks
	return true
