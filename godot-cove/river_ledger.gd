extends RefCounted

const SAVE := "user://ottawa_river_campaign.json"
const CREW_SAVE := "user://ottawa_river_multiplayer.json"
const PROFILE := "user://ottawa_crew_id.txt"
const FUEL_CAPACITY := 34.0
const Data = preload("res://river_campaign_data.gd")

var state: Dictionary
var error := ""
var save_path := SAVE
var recovered_primary := ""


func _init() -> void:
	state = fresh()


func fresh() -> Dictionary:
	return {
		"format": 1, "wood": 36, "parts": 11, "cash": 28, "cash_change": 0, "fuel": FUEL_CAPACITY, "charge": .46,
		"sites": {}, "routes": {}, "equipment": {}, "visited": [0], "surveys": {}, "scores": {}, "records": {}, "doors": {}, "lifts": {},
		"job": -1, "stage": "", "job_fish": [], "freight_run": 0.0, "last_dock": -1, "craft": "houseboat", "tow": false,
		"bilge": 0.0, "pump_on": true, "modern_houseboat": false,
		"ice_chest": [], "meals": 0, "held_fish": {}, "camp_fish": {},
		"progression": {}, "properties": {}, "verified_job_fish": 0, "job_serial": 0, "catch_serial": 0, "work_minutes": 480.0, "last_mowing_day": -1, "last_commercial_day": -1,
	}


func load_file() -> void:
	recovered_primary = ""
	for path: String in [save_path, save_path + ".prev"]:
		if not FileAccess.file_exists(path):
			continue
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(path)) != OK:
			continue
		var value: Variant = json.data
		if value is Dictionary and value.get("format") == 1 and value.get("sites") is Dictionary:
			state = fresh()
			for key in state.keys():
				var old: Variant = value.get(key, state[key])
				if typeof(old) == typeof(state[key]):
					state[key] = old
				elif old is float and is_finite(old) and state[key] is int:
					state[key] = int(old)
				elif old is int and state[key] is float:
					state[key] = float(old)
			for fish: Variant in state.held_fish.values():
				if fish is Dictionary:
					state.ice_chest.append(fish)
			state.held_fish.clear()
			if path != save_path:
				recovered_primary = save_path
			return


func save_file() -> void:
	var stage := save_path + ".new"
	var file := FileAccess.open(stage, FileAccess.WRITE)
	if file == null:
		error = "The river save could not be written."
		return
	file.store_string(JSON.stringify(state))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		error = "The river save could not be written."
		return
	var main := ProjectSettings.globalize_path(save_path)
	var backup := main + ".prev"
	if recovered_primary != save_path and FileAccess.file_exists(save_path) and DirAccess.rename_absolute(main, backup) != OK:
		error = "The river save could not be backed up."
		return
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(stage), main) != OK:
		error = "The river save could not be updated."
		return
	recovered_primary = ""
	error = ""


func profile_id(path := PROFILE) -> String:
	var current := FileAccess.get_file_as_string(path).strip_edges() if FileAccess.file_exists(path) else ""
	if current.length() == 32:
		return current
	var generated := Crypto.new().generate_random_bytes(16).hex_encode()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(generated)
	return generated


func wallet_cents() -> int:
	return int(state.cash) * 100 + clampi(int(state.get("cash_change", 0)), 0, 99)


func set_wallet_cents(cents: int) -> void:
	@warning_ignore("integer_division")
	state.cash = cents / 100
	state.cash_change = cents % 100


func site(index: int) -> Dictionary:
	return state.sites.get(str(index), {})


func building(index: int, id: String) -> Dictionary:
	var structures: Dictionary = site(index).get("buildings", {})
	return structures.get(id, {})


func has_at(index: int, id: String) -> bool:
	return not building(index, id).is_empty()


func has_upgrade(id: String) -> bool:
	return state.equipment.has(id)


func active_job() -> Dictionary:
	var index := int(state.job)
	return Data.WORK[index] if index >= 0 and index < Data.WORK.size() else {}


func affordable(item: Dictionary) -> bool:
	return state.wood >= item.get("wood", 0) and state.parts >= item.get("parts", 0) and state.cash >= item.get("cash", 0)


func spend(item: Dictionary) -> void:
	state.wood -= item.get("wood", 0)
	state.parts -= item.get("parts", 0)
	state.cash -= item.get("cash", 0)


func power_at(index: int, speed_of_current: float) -> float:
	if not has_at(index, "turbine"):
		return 0.0
	# The commissioned unit is geared for low current and has a 2.6 kW inverter.
	return minf(2.6, .8 + maxf(0.0, speed_of_current) * 3.0)


func route_key(a: int, b: int) -> String:
	return "%d/%d" % [mini(a, b), maxi(a, b)]


func connected(a: int, b: int) -> bool:
	return state.routes.has(route_key(a, b))


func dock_network(index: int) -> bool:
	for route: Dictionary in state.routes.values():
		if index == int(route.a) or index == int(route.b):
			return true
	return false


func award(person: String, display_name: String, cash: int, wood: int, parts: int, site_index: int) -> void:
	state.cash += cash
	state.wood += wood
	state.parts += parts
	var score: Dictionary = state.scores.get(person, {"jobs": 0})
	score.name = display_name
	score.jobs += 1
	state.scores[person] = score
	var plot := site(site_index)
	if not plot.is_empty():
		plot.deliveries = int(plot.get("deliveries", 0)) + 1
