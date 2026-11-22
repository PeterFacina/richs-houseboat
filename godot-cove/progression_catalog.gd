extends RefCounted

static var catalog: Dictionary

static func skills() -> Dictionary:
	if catalog.is_empty():
		catalog = preload("res://progression_skills.json").data
	return catalog
