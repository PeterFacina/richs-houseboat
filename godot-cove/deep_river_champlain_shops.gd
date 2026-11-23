extends RefCounted

# Each opening lists its face span as fractions of the footprint edge, setback in metres,
# and either door hardware or a display-window layout.
const FACADES := {
	"market": {
		2: [
			[Vector3(.026, .081, .15), {"panes": [1.0], "sill": .48, "head": 2.02, "upper": "clear", "display": "shelves", "interior": "#7d6956"}],
			[Vector3(.091, .165, .39), {"door_right": false}],
			[Vector3(.174, .343, .17), {"panes": [1.0, 1.0, .85], "sill": .52, "head": 2.10, "upper": "clear", "display": "counter", "interior": "#887b5a"}],
			[Vector3(.370, .541, .15), {"panes": [1.0, 1.05], "sill": .56, "head": 2.13, "upper": "clear", "display": "plinth", "interior": "#706354"}],
			[Vector3(.549, .620, .45), {"door_right": true}],
			[Vector3(.642, .858, .19), {"panes": [1.0, .95], "sill": .60, "head": 2.05, "upper": "clear", "display": "boarded", "interior": "#ad8956"}],
			[Vector3(.869, .972, .54), {"double": true}],
		],
		1: [
			[Vector3(.16, .185, .14), {"panes": [1.0], "sill": 1.60, "upper": "none", "top": 2.23, "display": "plain", "interior": "#52584d"}],
			[Vector3(.25, .275, .14), {"panes": [1.0], "sill": 1.60, "upper": "none", "top": 2.23, "display": "plain", "interior": "#52584d"}],
			[Vector3(.35, .375, .14), {"panes": [1.0], "sill": 1.60, "upper": "none", "top": 2.23, "display": "plain", "interior": "#52584d"}],
		],
	},
	"pharmacy": {
		2: [
			[Vector3(.084, .310, .24), {"head": 2.72, "left_sidelight": 2.05, "lower_infill": "#9baca2", "opaque_head": true}],
			[Vector3(.405, .600, .29), {"head": 2.67, "left_sidelight": .92, "right_sidelight": .92, "lower_infill": "#617992", "opaque_head": true}],
			[Vector3(.717, .932, .26), {"head": 2.67, "left_sidelight": 2.08, "lower_infill": "#bdb5ad", "opaque_head": true}],
		],
	},
	"drug_mart": {
		3: [
			[Vector3(.080, .291, .22), {"panes": [1.0, .95, 1.0], "sill": .78, "upper": "none", "top": 2.51, "frame": "#464942", "display": "shelves", "interior": "#79715c"}],
			[Vector3(.432, .558, .76), {"double": true, "sidelight": .36, "right_sidelight": .35, "head": 2.76, "frame": "#444641"}],
			[Vector3(.583, .674, .20), {"panes": [1.0], "sill": .78, "upper": "none", "top": 2.51, "frame": "#464942", "display": "shelves", "interior": "#79715c"}],
			[Vector3(.697, .822, .22), {"panes": [1.0, 1.0], "sill": .81, "upper": "none", "top": 2.49, "frame": "#464942", "display": "blinds", "interior": "#9ca994"}],
			[Vector3(.842, .940, .22), {"panes": [1.0, 1.0], "sill": .81, "upper": "none", "top": 2.49, "frame": "#464942", "display": "blinds", "interior": "#9ca994"}],
		],
		0: [
			[Vector3(.042, .112, .21), {"panes": [1.0], "sill": .83, "upper": "none", "top": 2.51, "frame": "#464942", "display": "blinds", "interior": "#939f8c"}],
		],
		2: [
			[Vector3(.880, .938, .21), {"panes": [1.0, 1.0], "sill": .83, "upper": "none", "top": 2.51, "frame": "#464942", "display": "blinds", "interior": "#939f8c"}],
		],
	},
	"forest_corner": {
		3: [
			[Vector3(.042, .232, .13), {"panes": [1.0], "sill": .50, "head": 2.03, "upper": "infill", "frame": "#b1a991", "display": "blinds", "interior": "#a3afa3"}],
			[Vector3(.293, .467, .15), {"panes": [1.0], "sill": .50, "head": 2.03, "upper": "infill", "frame": "#b1a991", "display": "blinds", "interior": "#a3afa3"}],
			[Vector3(.623, .769, .16), {"panes": [1.0], "sill": .57, "head": 2.04, "upper": "infill", "frame": "#b1a991", "display": "plinth", "interior": "#69715d"}],
			[Vector3(.793, .946, .16), {"panes": [1.0], "sill": .57, "head": 2.04, "upper": "infill", "frame": "#b1a991", "display": "plinth", "interior": "#69715d"}],
		],
		0: [
			[Vector3(.747, .889, .49), {"head": 2.54, "right_sidelight": 1.28, "frame": "#b7af9d"}],
		],
		2: [
			[Vector3(.876, .942, .39), {"head": 2.48, "door_height": 1.99, "frame": "#b7af9d"}],
		],
	},
}


static func openings(kind: String, edge: int) -> Array:
	return FACADES.get(kind, {}).get(edge, [])


static func build_frontage(builder, bays: Array, width: float, max_head: float) -> void:
	var previous := 0.0
	for bay: Array in bays:
		var span: Vector3 = bay[0]
		var layout: Dictionary = bay[1]
		var left := width * span.x
		var right := width * span.y
		var grade: float = builder.sidewalk((left + right) * .5)
		builder.wall_strip(previous, left, width)
		if layout.has("panes"):
			var top := minf(max_head, grade + float(layout.get("top", 2.78)))
			builder.display_window(left, right, layout, span.z, grade, top)
		else:
			var top := minf(max_head, grade + float(layout.get("head", 2.77)))
			builder.entryway(left, right, span.z, layout, top)
		previous = right
	builder.wall_strip(previous, width, width)
