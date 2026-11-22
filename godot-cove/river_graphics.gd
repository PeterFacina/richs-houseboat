extends RefCounted

const SETTINGS := "user://river_graphics.cfg"
const NAMES := ["Performance", "Balanced", "Scenic"]
const DRAW_DISTANCE := [2400.0, 4200.0, 8700.0]
const SHADOW_DISTANCE := [72.0, 125.0, 230.0]
const WATER_GRID := [72, 112, 180]
const RANGES := {
	"tree_detail": [135.0, 235.0, 360.0],
	"tree_silhouette": [1220.0, 2150.0, 4150.0],
	"tree_stem": [420.0, 680.0, 1150.0],
	"regional_crown": [1500.0, 2750.0, 5200.0],
	"regional_trunk": [320.0, 510.0, 750.0],
	"building_shell": [1700.0, 2950.0, 5650.0],
	"building_detail": [170.0, 320.0, 650.0],
}

var level := 1


static func batch(instance: GeometryInstance3D, kind: String) -> void:
	instance.add_to_group("river_graphics_" + kind)


func load_setting() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS) == OK:
		level = clampi(int(config.get_value("graphics", "level", 1)), 0, NAMES.size() - 1)


func advance() -> void:
	level = (level + 1) % NAMES.size()
	var config := ConfigFile.new()
	config.set_value("graphics", "level", level)
	config.save(SETTINGS)


func apply(river: Node3D, view: Camera3D) -> void:
	var viewport := view.get_viewport()
	viewport.msaa_3d = [Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X][level]
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	view.far = DRAW_DISTANCE[level]
	river.landscape_light.directional_shadow_max_distance = SHADOW_DISTANCE[level]
	river.set_water_grid(WATER_GRID[level])
	river.fog_scale = pow(DRAW_DISTANCE[2] / DRAW_DISTANCE[level], .82)
	river.landscape_environment.fog_density = lerpf(.00010, .00038, maxf(0.0, river.last_evening)) * river.fog_scale
	for kind: String in RANGES:
		for item: GeometryInstance3D in river.get_tree().get_nodes_in_group("river_graphics_" + kind):
			if not river.is_ancestor_of(item):
				continue
			item.visibility_range_end = RANGES[kind][level]
			item.visibility_range_end_margin = 14.0
			if kind == "tree_silhouette":
				item.visibility_range_begin = RANGES["tree_detail"][level]
				item.visibility_range_begin_margin = 14.0


func description() -> String:
	return "%s · %.1f km · %s" % [NAMES[level], DRAW_DISTANCE[level] / 1000.0, ["2x MSAA", "4x MSAA", "8x MSAA"][level]]
