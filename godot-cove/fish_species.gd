extends RefCounted

const FILE := "res://deep_river/fish_species.json"
const RIGS := ["worm", "minnow", "bottom", "micro"]
const RIG_LABELS := ["Worm under float", "Minnow on slip float", "Deep slip float", "Micro jig under float"]
const PATTERNS := ["plain", "bars", "stripe", "speckle", "pike", "musky", "mottle", "saddle", "scales", "silver",
	"tail_spot", "gill_spot", "sunfish", "char", "brook_char", "trout", "pink", "bass_line", "dashes",
	"redbelly", "rose", "armor", "gar", "edge"]
static var records: Array = []
static var reach: Array[int] = []


static func all() -> Array:
	if records.is_empty():
		records = JSON.parse_string(FileAccess.get_file_as_string(FILE))
		for index in records.size():
			if records[index].record == "upper_allumette":
				reach.append(index)
	return records


static func local() -> Array[int]:
	all()
	return reach


static func profile(index: int) -> Dictionary:
	return all()[index]


static func habitat(row: Dictionary, depth: float) -> float:
	var limits: Array = row.bottom_m
	var lower: float = limits[0]
	var upper: float = limits[1]
	var spread := maxf(0.85, (upper - lower) * .28)
	var outside := maxf(maxf(lower - depth, depth - upper), 0.0)
	return exp(-pow(outside / spread, 2.0))


static func leader(slot: int, bottom: float) -> float:
	var desired: float = [1.45, 4.10, maxf(1.70, bottom - .55), .53][slot]
	return clampf(minf(desired, bottom - .20), .18, 25.0)


static func feeding_depth(row: Dictionary, bottom: float) -> float:
	match row.rig:
		"bottom":
			return maxf(.14, bottom - .63)
		"minnow":
			return clampf(bottom * .38, .22, 7.0)
		"watch":
			return maxf(.20, bottom - .82)
		"micro":
			return clampf(bottom * .26, .17, 3.8)
	return clampf(bottom * .48, .20, 5.3)


static func rig_affinity(row: Dictionary, slot: int) -> float:
	if row.rig in ["watch", "school"]:
		return 0.0
	if row.rig == RIGS[slot]:
		return 1.0
	if RIGS[slot] == "micro":
		return .14 if row.length_cm[0] < 23 else 0.0
	if row.rig == "micro":
		return .025 if slot == 0 else 0.0
	return .32 if row.rig == "worm" or slot == 0 else .20


static func typical_weight(row: Dictionary, length_cm: float) -> float:
	var mass := .000012
	match row.form:
		"bass", "bullhead", "drum", "sucker", "redhorse":
			mass = .000016
		"crappie", "sunfish", "carp":
			mass = .000023
		"esox", "silverside", "darter":
			mass = .0000074
		"eel", "gar", "lamprey":
			mass = .0000034
	return pow(length_cm, 3.0) * mass


static func burst(row: Dictionary, length_cm: int) -> float:
	var multiplier := 1.0
	match row.form:
		"esox", "bass", "salmonid", "gar":
			multiplier = 1.30
		"catfish", "carp", "drum", "redhorse":
			multiplier = 1.11
	return (0.47 + sqrt(float(length_cm)) * .21) * multiplier
