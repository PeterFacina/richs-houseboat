extends RefCounted

const Kit = preload("res://scenery.gd")
const Plaza = preload("res://deep_river_plaza.gd")
const Shops = preload("res://deep_river_champlain_shops.gd")

# The footprints are the existing surveyed polygons, in Deep River Road to Forest Avenue order.
# A shop row lists the sign, relative bay width, sign colours and door position within the bay.
const BUILDINGS := {
	"392475700": {
		"kind": "lcbo", "front": 4, "eave": 3.78, "wall": "#8d5743", "cap": "#6e6b62",
	},
	"392475699": {
		"kind": "plaza", "front": 2, "eave": 3.78, "wall": "#935b46", "cap": "#766f64",
		"grade_anchor": [17946.7452, 13419.5157], # Shared fascia elevation at the LCBO party wall.
	},
	"392475698": {
		"kind": "market", "front": 2, "eave": 3.60, "wall": "#9b5f49", "cap": "#676965",
	},
	"392475697": {
		"kind": "pharmacy", "front": 2, "eave": 6.72, "wall": "#8d9187", "cap": "#6e6c62",
	},
	"375689703": {
		"kind": "drug_mart", "front": 3, "eave": 4.20, "wall": "#a4705b", "cap": "#c9c7b9",
		"hip": Vector2(3.2, 1.23), "metal": "#dddcd1",
	},
	"1333593098": {
		"kind": "forest_corner", "front": 3, "eave": 3.04, "wall": "#b4a487", "cap": "#837872",
		"hip": Vector2(1.55, 0.87), "metal": "#a89d8e",
	},
	"375689444": {
		"kind": "apartments", "eave": 7.75, "floors": 3, "wall": "#ab7257", "cap": "#524b45",
		"hip": Vector2(2.0, 0.43), "metal": "#62574c", "balcony_face": Vector3.BACK,
	},
	"379147766": {
		"kind": "apartments", "eave": 17.45, "floors": 6, "wall": "#b4a185", "cap": "#6f7066",
		"balcony_face": Vector3.RIGHT,
	},
}

const IVORY := Color("#d3cec0")
const ALUMINUM := Color("#a9aca4")
const DARK_METAL := Color("#494e4a")
const BLUE_GREEN := Color("#789296")
const WINDOW := Color("#52616b")
const SHOWCASE := Color("#596c70")
const PLAZA_AWNING_TOP := 3.40
const PLAZA_AWNING_DEPTH := 1.49
const PLAZA_AWNING_BAND := 0.51
const PLAZA_SOFFIT := Color("#b6ad99")
const PHARMACY_UPPER_BASE := 3.07

var roofs: SurfaceTool
var frames: SurfaceTool
var glass: SurfaceTool
var town: Node3D
var ground_height: Callable
var draw_panel: Callable
var supports: StaticBody3D
var plaza := Plaza.new()


func setup(parent: Node3D, wall_surface: SurfaceTool, trim_surface: SurfaceTool, glass_surface: SurfaceTool,
		ground: Callable, panel: Callable) -> void:
	town = parent
	frames = trim_surface
	glass = glass_surface
	ground_height = ground
	draw_panel = panel
	supports = null
	roofs = SurfaceTool.new()
	roofs.begin(Mesh.PRIMITIVE_TRIANGLES)
	plaza.setup(parent, wall_surface, trim_surface, ground, panel, shop_sign)


func build_roof(building: Dictionary, profile: Dictionary, eave: float) -> void:
	var footprint := PackedVector2Array()
	for edge: Array in building.walls:
		footprint.append(Vector2(edge[0][0], edge[0][1]))
	var hip: Vector2 = profile.get("hip", Vector2.ZERO)
	var crown := footprint.duplicate()
	if hip.x > 0.0:
		for i in footprint.size():
			var before := (footprint[i] - footprint[posmod(i - 1, footprint.size())]).normalized().orthogonal()
			var after := (footprint[(i + 1) % footprint.size()] - footprint[i]).normalized().orthogonal()
			crown[i] += (before + after) * hip.x / (1.0 + before.dot(after))
		for i in footprint.size():
			var next := (i + 1) % footprint.size()
			var a := at_height(footprint[i], eave)
			var b := at_height(footprint[next], eave)
			var c := at_height(crown[next], eave + hip.y)
			var d := at_height(crown[i], eave + hip.y)
			var tint := Color(profile.metal)
			if profile.kind == "apartments":
				quad(roofs, a, b, c, d, tint)
			else:
				var panels := maxi(1, roundi(a.distance_to(b) / 0.34))
				for sheet in panels:
					var start := float(sheet) / panels
					var end := float(sheet + 1) / panels
					var seam := start + 0.11 / panels
					quad(roofs, a.lerp(b, start), a.lerp(b, seam), d.lerp(c, seam),
						d.lerp(c, start), tint.darkened(0.16))
					quad(roofs, a.lerp(b, seam), a.lerp(b, end), d.lerp(c, end),
						d.lerp(c, seam), tint.lightened(float(sheet % 4) * 0.015))

	var indices := Geometry2D.triangulate_polygon(crown)
	for i in range(0, indices.size(), 3):
		var a := at_height(crown[indices[i]], eave + hip.y)
		var b := at_height(crown[indices[i + 1]], eave + hip.y)
		var c := at_height(crown[indices[i + 2]], eave + hip.y)
		triangle(roofs, a, b, c, Vector3.UP, Color(profile.cap))

	var center := at_height(Vector2(building.center[0], building.center[1]), eave + hip.y)
	match profile.kind:
		"lcbo", "plaza", "market", "drug_mart", "forest_corner":
			detail_box(center + Vector3.UP * 0.30, Vector3(2.1, 0.60, 1.25), Basis.IDENTITY, ALUMINUM)
			if profile.kind in ["lcbo", "plaza", "drug_mart"]:
				detail_box(center + Vector3(3.2, 0.19, 2.4), Vector3(1.4, 0.38, 1.1), Basis.IDENTITY, DARK_METAL)
			if profile.kind == "lcbo":
				wrap_awning_corners(footprint, eave - float(profile.eave))
			match profile.kind:
				"lcbo": add_parapet(footprint, eave, 5)
				"plaza": add_parapet(footprint, eave, 1)
				"market": add_parapet(footprint, eave, -1)
		"pharmacy":
			var front := at_height(footprint[profile.front], eave)
			var end := at_height(footprint[(profile.front + 1) % footprint.size()], eave)
			var along := front.direction_to(end)
			var outward := along.cross(Vector3.UP)
			var basis := Basis(along, Vector3.UP, outward)
			var dormer := front.lerp(end, .77) - outward * 1.62
			detail_box(dormer + Vector3.UP * .54, Vector3(5.08, 1.08, 2.22), basis, DARK_METAL, true)
			detail_box(dormer + Vector3.UP * 1.10, Vector3(5.16, .09, 2.29), basis, ALUMINUM, true)
			ribbed_panel(dormer - along * 2.53 + outward * 1.114, basis, 5.06, 1.08,
				Color("#6f6d60"), .15)
			add_parapet(footprint, eave, -1)
		"apartments":
			if profile.floors == 6:
				detail_box(center + Vector3(0.0, 0.70, 12.0), Vector3(5.3, 1.40, 4.8), Basis.IDENTITY, Color("#bfb498"))


func build_face(profile: Dictionary, edge: int, origin: Vector3, along: Vector3, normal: Vector3,
		width: float, height: float) -> void:
	var basis := Basis(along, Vector3.UP, normal)
	if profile.kind == "apartments":
		apartment_face(profile, origin, basis, width, height)
		return
	side_face(profile.kind, edge, origin, basis, width, height)


func build_shop_face(kind: String, edge: int, origin: Vector3, basis: Basis, width: float,
		height: float, wall_color: Color, bottom_a: float, bottom_b: float) -> bool:
	var openings := Shops.openings(kind, edge)
	if openings.is_empty():
		return false
	var wall_top := PHARMACY_UPPER_BASE if kind == "pharmacy" else height
	if kind == "forest_corner":
		wall_color.a = 0.32
	plaza.begin_facade(origin, basis, wall_top, wall_color, bottom_a, bottom_b)
	var largest_opening := {"market": 2.69, "pharmacy": 2.80, "drug_mart": 2.91, "forest_corner": 2.84}
	Shops.build_frontage(plaza, openings, width, largest_opening[kind])
	match kind:
		"market":
			if edge == 2:
				market_trim(origin, basis, width)
		"pharmacy":
			pharmacy_upper(origin, basis, width, height)
			pharmacy_signs(origin, basis, width)
			pharmacy_walk(origin, basis, width)
		"drug_mart":
			if edge == 3:
				drug_mart_front(origin, basis, width)
			else:
				drug_mart_corner(origin, basis, width, height, edge == 0)
		"forest_corner":
			forest_eave(origin, basis, width, height)
			if edge == 3:
				for offset: float in [.12, .41]:
					var mount := origin + basis.x * (width * offset) + Vector3.UP * 3.43 - basis.z * .30
					detail_box(mount, Vector3(.08, .53, .64), basis, DARK_METAL)
				store_sign(origin, basis, width, Vector2(.079, .455), 3.19, 0.57, 0.043,
					"DOJO", Color("#393438"), IVORY)
				store_sign(origin, basis, width, Vector2(.639, .932), 2.43, 0.36, 0.055,
					"LONG SHOT'S", Color("#e6ddcd"), Color("#863b3e"))
			elif edge == 0:
				forest_annex(origin, basis, width)
	return true


func build_recessed_front(kind: String, origin: Vector3, basis: Basis, width: float,
		height: float, wall_color: Color, bottom_a: float, bottom_b: float) -> void:
	var steps := Plaza.fascia_sections(kind, width)
	for segment: Vector3 in steps:
		awning_band(origin + basis.x * segment.x, basis, segment.y - segment.x,
			PLAZA_AWNING_TOP + segment.z, PLAZA_AWNING_DEPTH,
			BLUE_GREEN, PLAZA_AWNING_BAND + segment.z, true)
	awning_posts(origin, basis, width, PLAZA_AWNING_TOP - PLAZA_AWNING_BAND,
		PLAZA_AWNING_DEPTH, 0.075, 0, 0.65 if kind == "plaza" else 0.0)
	if kind == "lcbo":
		var join := origin + basis.x * width + basis.z * (PLAZA_AWNING_DEPTH - 0.045)
		detail_box(join + Vector3.UP * (PLAZA_AWNING_TOP - PLAZA_AWNING_BAND * 0.5),
			Vector3(0.13, PLAZA_AWNING_BAND + 0.025, 0.13), basis, BLUE_GREEN, true)
	plaza.build_front(kind, origin, basis, width, height, wall_color, bottom_a, bottom_b)


func add_parapet(footprint: PackedVector2Array, eave: float, shared_edge: int) -> void:
	for i in footprint.size():
		if i == shared_edge:
			continue
		var a := at_height(footprint[i], eave)
		var b := at_height(footprint[(i + 1) % footprint.size()], eave)
		var along := a.direction_to(b)
		var outward := along.cross(Vector3.UP)
		var basis := Basis(along, Vector3.UP, outward)
		var center := (a + b) * 0.5 - outward * 0.083
		detail_box(center + Vector3.UP * 0.078, Vector3(a.distance_to(b), 0.18, 0.18),
			basis, Color("#81756b"), true)
		detail_box(center + Vector3.UP * 0.173, Vector3(a.distance_to(b) + 0.12, 0.065, 0.25),
			basis, ALUMINUM, true)


func side_face(kind: String, edge: int, origin: Vector3, basis: Basis, width: float, height: float) -> void:
	if kind == "lcbo" and edge in [2, 3]:
		awning_band(origin, basis, width, PLAZA_AWNING_TOP, PLAZA_AWNING_DEPTH,
			BLUE_GREEN, PLAZA_AWNING_BAND, true)
		awning_posts(origin, basis, width, PLAZA_AWNING_TOP - PLAZA_AWNING_BAND,
			PLAZA_AWNING_DEPTH, 0.075)
		if edge == 2:
			shop_sign(origin + basis.x * (width * 0.18) + basis.z * 1.522 + Vector3.UP * 2.93,
				basis, width * 0.64, 0.44, "WINE  SPIRITS  BEER    LCBO    WINE  SPIRITS  BEER",
				Color("#515933"), IVORY, true)
	elif kind == "pharmacy" and edge == 1:
		var upper := origin + Vector3.UP * PHARMACY_UPPER_BASE + basis.z * 0.026
		var upper_height := height - PHARMACY_UPPER_BASE
		ribbed_panel(upper, basis, width, upper_height, Color("#c4c0b6"), 0.25)
		for pier in 5:
			var offset := 1.6 + float(pier) * (width - 3.5) / 4.0
			draw_panel.call(frames, upper + basis.x * offset + basis.z * 0.026,
				basis.x, basis.z, 0.43, upper_height, Color("#945b47"))
	elif kind == "forest_corner":
		forest_eave(origin, basis, width, height)


func market_trim(origin: Vector3, basis: Basis, width: float) -> void:
	awning_band(origin, basis, width, 3.23, 1.26, Color("#bdc3c1"), 0.43, true)
	awning_posts(origin, basis, width, 2.80, 1.26, 0.072, 4)
	fascia(origin, basis, width, 3.30, 1.24, 0.074, Color("#616c6d"))
	store_sign(origin, basis, width, Vector2(.035, .341), 2.77, .46, 1.295,
		"SWEETENED BY SHELLY", Color("#e8e0ce"), Color("#715c55"))
	store_sign(origin, basis, width, Vector2(.381, .620), 2.49, .26, .044,
		"FIGARO", Color("#d8cfb7"), Color("#554b45"))
	store_sign(origin, basis, width, Vector2(.641, .978), 2.78, .45, 1.296,
		"DEEP RIVER MART", Color("#eee5d4"), Color("#a7323e"))


func pharmacy_signs(origin: Vector3, basis: Basis, width: float) -> void:
	store_sign(origin, basis, width, Vector2(.076, .319), 2.63, .31, .059,
		"BUDSMOKE", Color("#6ca456"), Color("#253c28"))
	store_sign(origin, basis, width, Vector2(.398, .612), 2.62, .35, .059,
		"DEEP RIVER PHARMACY", Color("#426d9e"), Color("#faf2df"))
	store_sign(origin, basis, width, Vector2(.711, .939), 2.62, .34, .059,
		"ServiceOntario", Color("#e9e4d6"), Color("#536a62"))


func pharmacy_walk(origin: Vector3, basis: Basis, width: float) -> void:
	var slab_count := ceili(width / .8)
	var offset := basis.z * .027
	var across := basis.x * (width / slab_count)
	for i in slab_count:
		var start := origin + offset + across * float(i)
		var end := start + across
		var paver := Color("#ada594").lightened(float(i % 3) * .014)
		for row in 4:
			var near := basis.z * (float(row) * .68)
			var far := near + basis.z * .68
			quad(frames, on_grade(start + near), on_grade(start + far),
				on_grade(end + far), on_grade(end + near), paver)


func on_grade(point: Vector3) -> Vector3:
	point.y = float(ground_height.call(point.x, point.z)) + .016
	return point


func pharmacy_upper(origin: Vector3, basis: Basis, width: float, height: float) -> void:
	var face := origin + Vector3.UP * PHARMACY_UPPER_BASE + basis.z * 0.96
	var slope := Vector3.UP * (height - PHARMACY_UPPER_BASE) - basis.z * 0.92
	var tilted := Basis(basis.x, slope.normalized(), basis.x.cross(slope.normalized()))
	var sheet := Color("#b5aa95")
	var bottom := 1.30
	var top := 2.57
	var before := 0.0
	for center: float in [.145, .395, .572, .838]:
		var left := width * center - .46
		var right := left + .92
		ribbed_panel(face + basis.x * before, tilted, left - before, slope.length(), sheet, .123)
		ribbed_panel(face + basis.x * left, tilted, right - left, bottom, sheet, .123)
		ribbed_panel(face + basis.x * left + tilted.y * top, tilted, right - left, slope.length() - top, sheet, .123)
		mansard_window(face + basis.x * left, basis, tilted, right - left, bottom, top)
		before = right
	ribbed_panel(face + basis.x * before, tilted, width - before, slope.length(), sheet, .123)
	fascia(origin, basis, width, 3.03, .98, .105, DARK_METAL)
	fascia(origin, basis, width, height + .027, .13, .076, Color("#77746c"))
	triangle(frames, face, face - basis.z * .96, origin + Vector3.UP * height,
		-basis.x, Color("#a69a86"))
	var end := basis.x * width
	triangle(frames, face + end, face - basis.z * .96 + end,
		origin + end + Vector3.UP * height, basis.x, Color("#a69a86"))


func mansard_window(face: Vector3, basis: Basis, tilt: Basis, width: float,
		bottom: float, top: float) -> void:
	var a := face + tilt.y * bottom
	var b := face + tilt.y * top
	var across := basis.x * width
	var inner_bottom := a - basis.z * ((a - b).dot(basis.z) + .16)
	var inner_top := b - basis.z * .16
	var jamb := Color("#857b6c")
	quad(frames, a, inner_bottom, inner_top, b, jamb)
	quad(frames, inner_bottom + across, a + across, b + across, inner_top + across, jamb)
	quad(frames, a, a + across, inner_bottom + across, inner_bottom, Color("#b0a18b"))
	quad(frames, b + across, b, inner_top, inner_top + across, jamb.darkened(.15))
	var inner_height := inner_top.y - inner_bottom.y
	window(inner_bottom, basis, width, inner_height, Color("#797368"), WINDOW, 2)
	draw_panel.call(frames, inner_bottom + Vector3.UP * (inner_height * .31) + basis.z * .024,
		basis.x, basis.z, width, .036, ALUMINUM)


func drug_mart_front(origin: Vector3, basis: Basis, width: float) -> void:
	var blue := Color("#5a7494")
	awning_band(origin, basis, width, 3.90, 1.94, blue, .83, true)
	fascia(origin + basis.x * .49, basis, width - .98, 3.48, 1.97, .56, Color("#dfd9c6"))
	awning_posts(origin, basis, width, 3.07, 1.94, .51, 8)
	fascia(origin, basis, width, 3.95, 1.96, .09, Color("#d8d6c6"))
	var center := origin + basis.x * (width * .495) + basis.z * 1.39
	detail_box(center + Vector3.UP * 4.16, Vector3(4.58, 1.48, 1.27), basis, IVORY, true)
	detail_box(center + Vector3.UP * 4.92, Vector3(4.67, .091, 1.34), basis, ALUMINUM, true)
	detail_box(center + Vector3.UP * 3.46 + basis.z * .20, Vector3(4.84, .11, 1.27), basis, Color("#c4ae76"), true)
	var blade := center + Vector3.UP * 4.23 + basis.z * .662
	rx_oval(blade, basis, Vector2(1.69, .49), Color("#49545a"))
	rx_oval(blade + basis.z * .035, basis, Vector2(1.62, .45), Color("#e1ddcd"))
	rx_oval(blade + basis.z * .074, basis, Vector2(.42, .37), Color("#d2ae5f"))
	sign_label(blade + basis.z * .112, basis, .63, .55, "Rx", Color("#403734"), true)
	for span: Vector2 in [Vector2(.086, .352), Vector2(.642, .916)]:
		var split := lerpf(span.x, span.y, .64)
		store_sign(origin, basis, width, Vector2(span.x, split), 3.24, .43, 1.99,
			"DRUG MART", Color("#e8e2cd"), Color("#414855"))
		store_sign(origin, basis, width, Vector2(split, span.y), 3.24, .43, 1.99,
			"I.D.A.", Color("#4d6d9e"), IVORY)


func drug_mart_corner(origin: Vector3, basis: Basis, width: float, height: float, at_start: bool) -> void:
	var portion := minf(width, 2.4)
	var offset := 0.0 if at_start else width - portion
	var corner := origin + basis.x * offset
	fascia(corner, basis, portion, height - .34, .065, .67, Color("#607b9b"))
	var trim_at := 0.14 if at_start else portion - .29
	fascia(corner + basis.x * trim_at, basis, .15, height * .5, .074, height, Color("#516c95"))


func rx_oval(at: Vector3, basis: Basis, radius: Vector2, color: Color) -> void:
	var disk := CylinderMesh.new()
	disk.top_radius = 1.0
	disk.bottom_radius = 1.0
	disk.height = .036
	disk.radial_segments = 32
	var plate := Kit.mesh_at(town, disk, at, Kit.paint(color))
	plate.basis = Basis(basis.x * radius.x, basis.z, -Vector3.UP * radius.y)
	plate.add_to_group(Plaza.SIGNS)


func forest_eave(origin: Vector3, basis: Basis, width: float, height: float) -> void:
	fascia(origin, basis, width, height - .075, .14, .125, Color("#4b433e"))


func forest_annex(origin: Vector3, basis: Basis, width: float) -> void:
	var start := width * .20
	var span := width * .30
	var depth := 1.09
	var center := origin + basis.x * (start + span * .5)
	var grade: float = ground_height.call(center.x, center.z)
	var foot := origin + basis.x * start
	foot.y = minf(grade, origin.y) - .13
	var roof_y := 2.36
	var siding := Color("#c5c1b6")
	var head := foot + Vector3.UP * roof_y
	var trim_basis := Basis(basis.z, Vector3.UP, -basis.x)
	annex_siding(foot + basis.z * depth, basis, span, roof_y, siding)
	annex_siding(foot + basis.x * span + basis.z * depth, Basis(-basis.z, Vector3.UP, basis.x),
		depth, roof_y, siding.darkened(.07))
	var aperture := .53
	var sill := .77
	var sash_top := 1.91
	var left := .28
	annex_siding(foot, trim_basis, left, roof_y, siding)
	annex_siding(foot + basis.z * (left + aperture), trim_basis, depth - left - aperture, roof_y, siding)
	annex_siding(foot + basis.z * left, trim_basis, aperture, sill, siding)
	annex_siding(foot + basis.z * left + Vector3.UP * sash_top, trim_basis, aperture, roof_y - sash_top, siding)
	var frame_at := foot + basis.z * left - trim_basis.z * .098 + Vector3.UP * sill
	detail_box(frame_at + basis.z * (aperture * .5) + Vector3.UP * ((sash_top - sill) * .5),
		Vector3(aperture, sash_top - sill, .15), trim_basis, IVORY)
	window(frame_at + trim_basis.z * .081, trim_basis, aperture, sash_top - sill, IVORY, WINDOW, 1)
	draw_panel.call(frames, frame_at + trim_basis.z * .102 + Vector3.UP * .55, trim_basis.x, trim_basis.z,
		aperture, .045, IVORY)
	var roof_front := head + basis.z * (depth + .13) - Vector3.UP * .05
	var roof_back := head - basis.z * .04 + Vector3.UP * .23
	quad(roofs, roof_back - basis.x * .08, roof_front - basis.x * .08,
		roof_front + basis.x * (span + .08), roof_back + basis.x * (span + .08), Color("#504741"))
	detail_box(roof_front + basis.x * (span * .5), Vector3(span + .16, .12, .15), basis, Color("#5d5047"), true)
	var sign_at := foot + basis.x * (span * .19) + basis.z * (depth + .016) + Vector3.UP * 1.0
	shop_sign(sign_at, basis, span * .62, .72, "LONG SHOT'S", Color("#e6ddcd"), Color("#863b3e"), true)
	add_support_collision(foot + basis.x * (span * .5) + basis.z * (depth * .5) + Vector3.UP * (roof_y * .5),
		Vector3(span, roof_y, depth), basis)


func annex_siding(at: Vector3, basis: Basis, width: float, height: float, color: Color) -> void:
	draw_panel.call(frames, at, basis.x, basis.z, width, height, color)
	for line: int in range(1, ceili(height / .135)):
		var y := float(line) * .135
		draw_panel.call(frames, at + basis.z * .005 + Vector3.UP * y, basis.x, basis.z,
			width, minf(.013, height - y), color.darkened(.14))


func store_sign(origin: Vector3, basis: Basis, width: float, span: Vector2, y: float, height: float,
		depth: float, caption: String, color: Color, ink: Color) -> void:
	shop_sign(origin + basis.x * (width * span.x) + Vector3.UP * y + basis.z * depth,
		basis, width * (span.y - span.x), height, caption, color, ink, true)


func apartment_face(profile: Dictionary, origin: Vector3, basis: Basis, width: float, height: float) -> void:
	var floors: int = profile.floors
	var level := height / floors
	var bays := maxi(1, roundi(width / (3.25 if floors == 6 else 3.8)))
	var pitch := width / bays
	var face := origin + basis.z * 0.036
	var balcony_side := basis.z.dot(profile.balcony_face) > 0.82
	for storey in floors:
		for i in bays:
			var center := face + basis.x * (pitch * (i + 0.5)) + Vector3.UP * (level * storey + 0.79)
			var bay_w := minf(pitch * 0.53, 1.65)
			var balcony := balcony_side and storey > 0 and i % 5 == 2 and i < bays - 1
			if balcony:
				apartment_balcony(center, basis)
			else:
				window(center - basis.x * bay_w * 0.5, basis, bay_w,
					1.16 if storey > 0 else 0.92, ALUMINUM, WINDOW, 2)
	fascia(origin, basis, width, height - 0.15, 0.16, 0.20, Color(profile.cap))


func apartment_balcony(center: Vector3, basis: Basis) -> void:
	var balcony := center - Vector3.UP * 0.55
	window(balcony - basis.x * 0.90, basis, 1.80, 1.95, IVORY, WINDOW, 2)
	detail_box(balcony + basis.z * 0.56, Vector3(2.25, 0.16, 1.22), basis, Color("#9e9282"))
	var front := balcony + basis.z * 1.13 + Vector3.UP * 0.82
	detail_box(front, Vector3(2.22, 0.065, 0.065), basis, DARK_METAL)
	for i in 7:
		detail_box(front + basis.x * (-1.08 + i * 0.36) - Vector3.UP * 0.39,
			Vector3(0.040, 0.82, 0.040), basis, DARK_METAL)
	for side: float in [-1.0, 1.0]:
		var edge := balcony + basis.x * 1.08 * side + basis.z * 0.55 + Vector3.UP * 0.82
		detail_box(edge, Vector3(0.065, 0.065, 1.18), basis, DARK_METAL)


func window(origin: Vector3, basis: Basis, width: float, height: float, trim: Color,
		tint: Color, lites: int) -> void:
	draw_panel.call(frames, origin, basis.x, basis.z, width, height, trim, basis.y)
	var pitch := width / lites
	for i in lites:
		var corner := origin + basis.z * 0.012 + basis.x * (pitch * i + 0.047) + basis.y * 0.055
		draw_panel.call(glass, corner, basis.x, basis.z, pitch - 0.094, height - 0.11,
			tint.darkened(float(i % 3) * 0.10), basis.y)


func awning_band(origin: Vector3, basis: Basis, width: float, top: float, depth: float,
		color: Color, band: float, lined := false) -> void:
	fascia(origin, basis, width, top - band * 0.5, depth, band, color)
	var front := origin + basis.z * (depth + 0.005) + Vector3.UP * (top - band + 0.045)
	ribbed_panel(front, basis, width, band - 0.09, color, 0.19)
	var trim_edge := origin + basis.z * (depth + 0.017) + Vector3.UP * (top - 0.063)
	draw_panel.call(frames, trim_edge, basis.x, basis.z, width, 0.063, IVORY)
	if lined:
		var drip_edge := front - Vector3.UP * 0.044 + basis.z * 0.009
		draw_panel.call(frames, drip_edge, basis.x, basis.z, width, 0.033, IVORY)
		var underside := origin + Vector3.UP * (top - band - 0.008)
		quad(frames, underside, underside + basis.x * width, underside + basis.x * width + basis.z * depth,
			underside + basis.z * depth, PLAZA_SOFFIT)


func awning_posts(origin: Vector3, basis: Basis, width: float, bottom_height: float, depth: float,
		post_width: float, post_count := 0, first_post_offset := 0.0) -> void:
	if post_count == 0:
		post_count = maxi(2, roundi(width / 6.4) + 1)
	for i in post_count:
		var distance := lerpf(0.36 + first_post_offset, width - 0.36, float(i) / (post_count - 1))
		var bottom := origin + basis.x * distance + basis.z * (depth - 0.16)
		bottom.y = ground_height.call(bottom.x, bottom.z) - 0.025
		var post_height := origin.y + bottom_height + 0.03 - bottom.y
		var post_at := bottom + Vector3.UP * post_height * 0.5
		var post_size := Vector3(post_width, post_height, post_width)
		detail_box(post_at, post_size, basis, IVORY if post_width > 0.2 else DARK_METAL)
		if post_width > 0.2:
			var post_face := bottom - basis.x * post_width * 0.5 + basis.z * (post_width * 0.5 + 0.008)
			ribbed_panel(post_face, basis, post_width, post_height, IVORY, 0.091)
		add_support_collision(post_at, post_size, basis)


func add_support_collision(at: Vector3, size: Vector3, basis: Basis) -> void:
	if supports == null:
		supports = StaticBody3D.new()
		supports.name = "ChamplainBuildingProjections"
		town.add_child(supports)
	Kit.collider(supports, at, size)
	var collider := supports.get_child(-1) as CollisionShape3D
	collider.basis = basis


func wrap_awning_corners(footprint: PackedVector2Array, base: float) -> void:
	var top := base + PLAZA_AWNING_TOP
	var band := Vector3.UP * PLAZA_AWNING_BAND
	for i in [3, 4]:
		var corner := at_height(footprint[i], top)
		var before := footprint[i - 1].direction_to(footprint[i]).orthogonal()
		var after := footprint[i].direction_to(footprint[i + 1]).orthogonal()
		var a := corner - at_height(before, 0.0) * PLAZA_AWNING_DEPTH
		var b := corner - at_height(after, 0.0) * PLAZA_AWNING_DEPTH
		triangle(frames, corner, a, b, Vector3.UP, BLUE_GREEN)
		var soffit := band + Vector3.UP * 0.008
		triangle(frames, corner - soffit, a - soffit, b - soffit, Vector3.DOWN, PLAZA_SOFFIT)
		quad(frames, a - band, b - band, b, a, BLUE_GREEN)


func fascia(origin: Vector3, basis: Basis, width: float, center_y: float,
		depth: float, height: float, color: Color) -> void:
	detail_box(origin + basis.x * width * 0.5 + basis.z * depth * 0.5 + Vector3.UP * center_y,
		Vector3(width, height, depth), basis, color, true)


func ribbed_panel(origin: Vector3, basis: Basis, width: float, height: float,
		color: Color, spacing: float) -> void:
	draw_panel.call(frames, origin, basis.x, basis.z, width, height, color, basis.y)
	var highlight := color.lightened(0.15)
	for i in range(1, ceili(width / spacing)):
		var seam := origin + basis.x * (spacing * i) + basis.z * 0.008
		draw_panel.call(frames, seam, basis.x, basis.z, minf(0.022, width - spacing * i), height, highlight, basis.y)


func shop_sign(origin: Vector3, basis: Basis, width: float, height: float, caption: String,
		background: Color, ink: Color, plaza_board := false) -> void:
	if plaza_board:
		plaza.sign_board(origin, basis, width, height, background)
	else:
		draw_panel.call(frames, origin, basis.x, basis.z, width, height, background)
	var center := origin + basis.x * width * 0.5 + Vector3.UP * height * 0.51 + basis.z * 0.031
	sign_label(center, basis, width, height, caption, ink, plaza_board)


func sign_label(center: Vector3, basis: Basis, width: float, height: float, caption: String,
		ink: Color, hide_with_signs: bool) -> void:
	var label := Label3D.new()
	town.add_child(label)
	label.position = center
	label.basis = basis
	label.text = caption
	label.font_size = 48
	label.pixel_size = minf(height / 49.0, width / (caption.length() * 29.0))
	label.outline_size = 0
	label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	label.modulate = ink
	if hide_with_signs:
		label.add_to_group(Plaza.SIGNS)


func detail_box(center: Vector3, size: Vector3, basis: Basis, color: Color, shell := false) -> void:
	var surface := roofs if shell else frames
	var side := basis.x * size.x * 0.5
	var rise := basis.y * size.y * 0.5
	var depth := basis.z * size.z * 0.5
	box_face(surface, center + depth, side, rise, color)
	box_face(surface, center - depth, -side, rise, color)
	box_face(surface, center + side, -depth, rise, color)
	box_face(surface, center - side, depth, rise, color)
	box_face(surface, center + rise, side, -depth, color)
	box_face(surface, center - rise, side, depth, color)


func box_face(surface: SurfaceTool, center: Vector3, side: Vector3, rise: Vector3, color: Color) -> void:
	quad(surface, center - side - rise, center + side - rise, center + side + rise, center - side + rise, color)


func at_height(point: Vector2, y: float) -> Vector3:
	return Vector3(point.x, y, point.y)


func quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	var normal := (b - a).cross(d - a).normalized()
	triangle(surface, a, b, c, normal, color)
	triangle(surface, a, c, d, normal, color)


func triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		normal: Vector3, color: Color) -> void:
	surface.set_color(color)
	surface.set_normal(normal)
	for point: Vector3 in ([a, b, c] if (c - a).cross(b - a).dot(normal) > 0.0 else [a, c, b]):
		surface.set_uv(Vector2.ZERO)
		surface.add_vertex(point)
