extends Node3D

const Kit = preload("res://scenery.gd")
const Data = preload("res://river_campaign_data.gd")
const Ledger = preload("res://river_ledger.gd")
const Ottawa = preload("res://ottawa_map.gd")
const Marina = preload("res://marina_art.gd")
const Beach = preload("res://lamure_beach.gd")
const DECK := .73
const PLOT_RADIUS := 10.0
const CHALK_LANDING := 4
const LOOKOUT_TRAIL_Z := -8.0

var river: Ottawa
var ledger: Ledger
var sites: Array[Dictionary] = []
var built: Dictionary = {}
var doors: Array[AnimatableBody3D] = []
var rotors: Array[Node3D] = []
var powered_lamps: Array[OmniLight3D] = []
var dry_lifts: Dictionary = {}
var wood: Material
var boards: Array[Material]
var logs: Array[Material]
var trim: Material
var roofing: Material
var glass: Material
var steel: Material
var rubber: Material
var light_paint: Material
var grass_mesh: ArrayMesh
var grasses: ShaderMaterial
var shale: Material
var gravel: StandardMaterial3D


func setup(map: Ottawa, account: Ledger) -> void:
	river = map
	ledger = account
	wood = finish(Color("#ab8866"), true)
	trim = finish(Color("#d4c2a3"), true)
	roofing = finish(Color("#3c494b"))
	steel = finish(Color("#687b82"))
	rubber = Kit.paint(Color("#343437"))
	for tint: Color in [Color("#a88e71"), Color("#b2997e"), Color("#aa9079"), Color("#a28d77")]:
		boards.append(finish(tint, true))
	for tint: Color in [Color("#8c6250"), Color("#90664f"), Color("#a27055")]:
		logs.append(finish(tint, true))
	var glazing := Kit.paint(Color(.53, .78, .78, .26), .18, .04)
	glazing.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glazing.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass = glazing
	var bulb := Kit.paint(Color("#ffc980"), .5)
	bulb.emission_enabled = true
	bulb.emission = Color("#ffc980")
	bulb.emission_energy_multiplier = .75
	light_paint = bulb
	var seed := RandomNumberGenerator.new()
	seed.seed = 601
	grass_mesh = Marina.new().reed_mesh(seed)
	grasses = ShaderMaterial.new()
	grasses.shader = preload("res://river_reeds.gdshader")
	shale = finish(Color("#7b7a70"))
	gravel = Kit.paint(Color("#857b66"), .93)
	gravel.vertex_color_use_as_albedo = true
	gravel.cull_mode = BaseMaterial3D.CULL_DISABLED
	for index in Data.SITES.size():
		make_landing(index)
	sync_structures()


func finish(tint: Color, timber := false) -> Material:
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://boat_finish.gdshader")
	paint.set_shader_parameter("coat", tint)
	paint.set_shader_parameter("matte", .63)
	paint.set_shader_parameter("timber", timber)
	return paint


func land_height(position: Vector3) -> float:
	return river.ground_height(position.x, position.z)


func site_range(at: Vector3, radius: float, use_berths: bool) -> int:
	var nearest := -1
	for index in sites.size():
		var position: Vector3 = sites[index].berth if use_berths else sites[index].plot
		var distance := Vector2(at.x - position.x, at.z - position.z).length()
		if distance <= radius:
			nearest = index
			radius = distance
	return nearest


func make_landing(index: int) -> void:
	var data: Dictionary = Data.SITES[index]
	var plot := Vector3(data.plot.x, 0, data.plot.y)
	plot.y = land_height(plot)
	var heading := float(data.turn) * PI / 8.0
	var frame := Basis(Vector3.UP, heading)
	var forward := -frame.z
	var right := frame.x
	var root := Node3D.new()
	root.name = "Landing%d" % index
	add_child(root)
	var end := plot + forward * float(data.pier)
	end.y = DECK
	var lead := plot + forward * 10.0
	var highest := land_height(lead)
	lead.y = highest + .04
	var ramp_end := lead + forward * minf(8.0, (end - lead).length() * .55)
	ramp_end.y = DECK
	var dock_end := end + forward * 1.65
	walkway(root, lead, ramp_end, 1.83)
	walkway(root, ramp_end, dock_end, 2.26)
	var berth := end + right * 2.63
	berth.y = 0
	var transfer := end + Vector3.UP * .035 - forward * 1.7
	var deck_entry := end + right * 1.13 - forward * 1.7
	walkway(root, transfer, deck_entry, 1.1, false)
	var stand := lead - forward * .94
	stand.y = land_height(stand) + .04
	var notice_origin := stand + right * 1.66
	notice_origin.y = land_height(notice_origin) + 1.32
	board_sign(root, notice_origin, data.name, data.service, heading, data.color)
	var buoy := Node3D.new()
	root.add_child(buoy)
	buoy.position = end + forward * 2.05 - right * .78
	buoy.position.y = .96
	Kit.box_at(buoy, Vector3(0, .38, 0), Vector3(.12, 1.25, .12), roofing)
	Kit.box_at(buoy, Vector3(0, 1.02, 0), Vector3(.29, .17, .29), roof_trim(data.color))
	Kit.box_at(buoy, Vector3(0, 1.13, 0), Vector3(.21, .11, .21), light_paint)
	for offset: Vector2 in [Vector2(-5.4, -5.4), Vector2(-5.4, 5.4), Vector2(5.4, -5.4), Vector2(5.4, 5.4)]:
		var stake := plot + Vector3(offset.x, 0, offset.y)
		stake.y = land_height(stake)
		Kit.box_at(root, stake + Vector3.UP * .28, Vector3(.10, .56, .10), trim)
		Kit.box_at(root, stake + Vector3.UP * .57, Vector3(.13, .08, .13), roof_trim(data.color))
	var label_point := plot + right * 1.12 + forward * 5.6
	label_point.y = land_height(label_point) + 1.26
	var parcel := board_sign(root, label_point, "Cabin plot", "B  Build here", heading, data.color)
	dress_bank(root, plot, frame, index)
	if index == CHALK_LANDING:
		make_chalk_lookout(root, plot, frame, heading, data.color)
	sites.append({"plot": plot, "heading": heading, "forward": forward, "right": right,
		"dock": dock_end, "berth": berth, "stand": stand, "transfer": transfer,
		"sign": notice_origin, "parcel": parcel, "root": root})


func dress_bank(parent: Node3D, plot: Vector3, frame: Basis, index: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2201 + index
	var grass: Array[Transform3D] = []
	var stone: Array[Transform3D] = []
	for entry in 122:
		var x := rng.randf_range(-15, 15)
		var z := rng.randf_range(-21, 14)
		if absf(x) < 2.0 or (absf(x) < 7.9 and absf(z) < 8.0):
			continue
		if index == CHALK_LANDING and x > -14.0 and x < -1.5 and absf(z - LOOKOUT_TRAIL_Z) < 2.0:
			continue
		var point := plot + frame * Vector3(x, 0, z)
		point.y = land_height(point)
		if point.y < -.09 or point.y > 5.5:
			continue
		var axis := Basis(Vector3.UP, rng.randf_range(0, TAU))
		if entry % 5 == 0:
			var width := rng.randf_range(.31, 1.07)
			stone.append(Transform3D(axis.scaled_local(Vector3(width, width * .38, width * .82)), point))
		else:
			grass.append(Transform3D(axis.scaled_local(Vector3(1.22, rng.randf_range(.37, .77), .94)), point))
	if not grass.is_empty():
		Kit.new().scatter(parent, grass_mesh, grass, grasses)
	if not stone.is_empty():
		var rock := SphereMesh.new()
		rock.radial_segments = 8
		rock.rings = 4
		Kit.new().scatter(parent, rock, stone, shale)
	gravel_trail(parent, plot - frame.z * 10.0, frame.z, 14, rng)


func make_chalk_lookout(parent: Node3D, plot: Vector3, frame: Basis, heading: float, color: Color) -> void:
	var lookout := Node3D.new()
	lookout.name = "ChalkRiverLookout"
	parent.add_child(lookout)
	var rng := RandomNumberGenerator.new()
	rng.seed = 28464
	var spur := plot + frame * Vector3(-.55, 0, LOOKOUT_TRAIL_Z)
	gravel_trail(lookout, spur, -frame.x, 21, rng, .047)
	var bench_at := plot + frame * Vector3(-12.0, 0, LOOKOUT_TRAIL_Z + .78)
	bench_at.y = land_height(bench_at)
	var seat := Beach.build_bench(lookout, bench_at, wood)
	seat.name = "RiverLookoutBench"
	seat.rotation.y = heading
	var bench_body := StaticBody3D.new()
	bench_body.collision_mask = 0
	seat.add_child(bench_body)
	Kit.collider(bench_body, Vector3(0, .48, .02), Vector3(1.89, .94, .53))
	var sign_at := plot + frame * Vector3(-2.15, 0, LOOKOUT_TRAIL_Z - 1.18)
	sign_at.y = land_height(sign_at) + 1.26
	board_sign(lookout, sign_at, "River lookout", "Follow the gravel path", heading, color)


func gravel_trail(parent: Node3D, start: Vector3, forward: Vector3, sections: int,
		rng: RandomNumberGenerator, height := .035) -> void:
	var right := forward.cross(Vector3.DOWN)
	var trail := SurfaceTool.new()
	trail.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in sections:
		var z := i * .58
		var spread := .62 + sin((z - 10.0) * 1.7) * .09
		for pair: Vector2 in [Vector2(-spread, z), Vector2(spread, z), Vector2(-spread, z + .58),
				Vector2(spread, z), Vector2(spread, z + .58), Vector2(-spread, z + .58)]:
			var vertex := start + right * pair.x + forward * pair.y
			vertex.y = land_height(vertex) + height
			trail.set_color(Color(1.0, .96, .87, 1.0).darkened(rng.randf_range(0, .13)))
			trail.add_vertex(vertex)
	trail.generate_normals()
	Kit.mesh_at(parent, trail.commit(), Vector3.ZERO, gravel)


func pier_clear(at: Vector3) -> bool:
	for index in sites.size():
		var site := sites[index]
		var relative: Vector3 = at - site.plot
		if relative.length_squared() > 74.0 * 74.0:
			continue
		var pier_length: float = Data.SITES[index].pier + (7.8 if ledger.has_at(index, "dock") else 1.6)
		var along: float = relative.dot(site.forward)
		if along >= 10.0 and along <= pier_length and absf(relative.dot(site.right)) < 1.07:
			return false
	return true


func roof_trim(tint: Color) -> Material:
	return Kit.paint(tint, .61)


func text_on(parent: Node3D, content: String, at: Vector3, size: int, pixel: float, color: Color) -> Label3D:
	var sign := Label3D.new()
	sign.text = content
	sign.position = at
	sign.font_size = size
	sign.pixel_size = pixel
	sign.outline_size = 3
	sign.modulate = color
	parent.add_child(sign)
	return sign


func board_sign(parent: Node3D, at: Vector3, title: String, subtitle: String, heading: float, color: Color) -> Label3D:
	var sign := Node3D.new()
	parent.add_child(sign)
	sign.global_position = river.roadside_sign_foot(parent.to_global(at), 1.2)
	sign.add_to_group(&"town_roadside_signs")
	sign.set_meta(&"sign_span", 1.2)
	sign.rotation.y = heading + PI
	for side in [-.78, .78]:
		Kit.box_at(sign, Vector3(side, -.56, -.13), Vector3(.12, 1.7, .13), wood)
	Kit.box_at(sign, Vector3.ZERO, Vector3(2.1, .65, .13), roofing)
	Kit.box_at(sign, Vector3(0, .355, 0), Vector3(2.22, .09, .22), trim)
	Kit.box_at(sign, Vector3(0, -.25, .077), Vector3(1.91, .025, .02), roof_trim(color))
	var title_label := text_on(sign, title, Vector3(0, .087, .078), 64, .0029, color)
	text_on(sign, subtitle, Vector3(0, -.12, .083), 51, .00158, Color("#f0e6d5"))
	sign.rotation.y += PI
	# Make the sign legible on the way back from the river as well.
	var back := text_on(sign, title, Vector3(0, .087, -.078), 64, .0029, color)
	back.rotation.y = PI
	var sub := text_on(sign, subtitle, Vector3(0, -.12, -.083), 51, .00158, Color("#f0e6d5"))
	sub.rotation.y = PI
	title_label.set_meta("rear", back)
	return title_label


func walkway(parent: Node3D, a: Vector3, b: Vector3, width: float, piles := true) -> void:
	var distance := a.distance_to(b)
	var body := StaticBody3D.new()
	parent.add_child(body)
	body.transform = Transform3D(Basis.looking_at(b - a), (a + b) * .5)
	body.collision_mask = 0
	Kit.collider(body, Vector3.DOWN * .09, Vector3(width, .18, distance))
	var count := maxi(1, ceili(distance / .43))
	for index in count:
		var z := (float(index) + .5) / count * distance - distance * .5
		Kit.box_at(body, Vector3(0, -.073, z), Vector3(width, .144, distance / count - .008), boards[index % boards.size()])
	for side in [-1.0, 1.0]:
		Kit.box_at(body, Vector3(side * (width * .5 - .039), -.18, 0), Vector3(.08, .13, distance), wood)
	if not piles:
		return
	var sections := maxi(1, ceili(distance / 4.5))
	for i in range(sections + 1):
		var center := a.lerp(b, float(i) / sections)
		var right := body.basis.x
		for side in [-1.0, 1.0]:
			var point: Vector3 = center + right * side * (width * .5 - .14)
			var world := parent.to_global(point)
			var bottom := maxf(land_height(world) - .15, -2.95)
			var length := maxf(.27, world.y - bottom + .18)
			Kit.box_at(parent, point + Vector3.UP * (.18 - length * .5), Vector3(.16, length, .16), wood)
			if i > 0 and i % 2 == 0:
				Kit.box_at(parent, point - Vector3.UP * .04, Vector3(.234, .23, .225), rubber)


func shallowest_base(position: Vector3, size: Vector2, angle: float) -> Vector2:
	var low := INF
	var high := -INF
	var basis_y := Basis(Vector3.UP, angle)
	for u in [-.5, 0.0, .5]:
		for v in [-.5, 0.0, .5]:
			var at := position + basis_y * Vector3(size.x * u, 0, size.y * v)
			var surface := land_height(at)
			low = minf(low, surface)
			high = maxf(high, surface)
	return Vector2(low, high)


func build_pose(index: int, id: String, point: Vector3, angle: float) -> Transform3D:
	var site: Dictionary = sites[index]
	var frame := Basis(Vector3.UP, site.heading)
	var berth: Vector3 = site.berth
	var root: Vector3 = site.plot
	var pos := Vector3(snappedf(point.x - root.x, .5) + root.x, point.y, snappedf(point.z - root.z, .5) + root.z)
	var size: Vector2 = Data.BUILDINGS[id].size
	match id:
		"porch":
			var cabin := ledger.building(index, "cabin")
			if not cabin.is_empty():
				var cabin_frame := read_pose(cabin)
				return cabin_frame.translated_local(Vector3(0, 0, 3.63))
		"dock":
			var tip: Vector3 = site.dock
			return Transform3D(frame, tip + -frame.z * 3.18)
		"boathouse":
			var center := berth + frame.x * 6.70 + frame.z * .65
			center.y = DECK
			return Transform3D(frame, center)
		"drydock":
			var center := berth - frame.x * 7.35 + frame.z * 2.0
			center.y = DECK
			return Transform3D(frame, center)
		"turbine":
			var center := berth - frame.x * 2.7 - frame.z * 11.0
			center.y = .65
			return Transform3D(frame, center)
	angle = snappedf(angle, PI / 2.0)
	pos.y = shallowest_base(pos, size, angle).y + .22
	return Transform3D(Basis(Vector3.UP, angle), pos)


func allowed_pose(index: int, id: String, pose: Transform3D) -> bool:
	if id == "porch":
		if not ledger.has_at(index, "cabin"):
			return false
	elif id not in ["cabin", "workshop"]:
		return true
	var site: Dictionary = sites[index]
	var center: Vector3 = site.plot
	var size: Vector2 = Data.BUILDINGS[id].size
	var angle := pose.basis.get_euler().y
	var ground := shallowest_base(pose.origin, size, angle)
	if Vector2(pose.origin.x - center.x, pose.origin.z - center.z).length() > PLOT_RADIUS - size.length() * .5 \
			or ground.x < .10 or ground.y - ground.x > 1.4:
		return false
	for existing in ["cabin", "workshop", "porch"]:
		if not ledger.has_at(index, existing) or (id == "porch" and existing == "cabin"):
			continue
		var other := read_pose(ledger.building(index, existing))
		var span := footprint(size, pose)
		var other_span := footprint(Data.BUILDINGS[existing].size, other)
		if span.grow(.67).intersects(other_span):
			return false
	return true


func footprint(size: Vector2, pose: Transform3D) -> Rect2:
	var across := pose.basis.x.abs()
	var along := pose.basis.z.abs()
	var span := Vector2(across.x, across.z) * size.x + Vector2(along.x, along.z) * size.y
	return Rect2(Vector2(pose.origin.x, pose.origin.z) - span * .5, span)


func record(pose: Transform3D) -> Dictionary:
	return {"x": pose.origin.x, "y": pose.origin.y, "z": pose.origin.z, "heading": pose.basis.get_euler().y}


func read_pose(data: Dictionary) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, float(data.heading)), Vector3(data.x, data.y, data.z))


func sync_structures() -> void:
	for index in sites.size():
		var claim := ledger.site(index)
		var plot_label: Label3D = sites[index].parcel
		plot_label.text = "%s's place" % claim.get("name", "Crew") if not claim.is_empty() else "Cabin plot"
		plot_label.get_meta("rear").text = plot_label.text
		for id: String in Data.BUILDINGS:
			var data := ledger.building(index, id)
			var key := "%d/%s" % [index, id]
			if data.is_empty():
				if built.has(key):
					built[key].queue_free()
					built.erase(key)
			elif not built.has(key):
				var structure := Node3D.new()
				structure.name = id.capitalize()
				add_child(structure)
				structure.transform = read_pose(data)
				built[key] = structure
				make_structure(structure, index, id)


func make_structure(parent: Node3D, index: int, id: String) -> void:
	match id:
		"cabin", "workshop":
			build_shell(parent, index, id == "workshop")
		"porch":
			build_porch(parent)
		"dock":
			walkway(parent, Vector3.BACK * 3.2, Vector3.FORWARD * 3.2, 2.58)
			Kit.box_at(parent, Vector3(-.85, .47, -2.4), Vector3(.15, 1.04, .15), wood)
			Kit.box_at(parent, Vector3(-.85, .58, -2.4), Vector3(.24, .08, .23), steel)
		"boathouse", "drydock":
			build_slip(parent, index, id == "drydock")
		"turbine":
			build_turbine(parent, index)


func solid(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> void:
	Kit.box_at(parent, at, size, material)
	var body := StaticBody3D.new()
	body.collision_mask = 0
	parent.add_child(body)
	Kit.collider(body, at, size)


func plank_deck(parent: Node3D, size: Vector2) -> void:
	walkway(parent, Vector3.BACK * size.y * .5, Vector3.FORWARD * size.y * .5, size.x, false)
	for x in [-.43, .43]:
		for z in [-.40, 0.0, .40]:
			var at := Vector3(size.x * x, -.065, size.y * z)
			var world := parent.to_global(at)
			var length := maxf(.25, world.y - land_height(world) + .32)
			Kit.box_at(parent, at - Vector3.UP * length * .5, Vector3(.21, length, .21), wood)


func clapboard(parent: Node3D, at: Vector3, size: Vector3) -> void:
	var count := maxi(2, roundi(size.y / .157))
	for row in count:
		var height := size.y / count
		var position := at + Vector3.UP * ((float(row) + .5) * height - size.y * .5)
		var planking := Vector3(size.x, height - .006, size.z)
		Kit.box_at(parent, position, planking, logs[row % logs.size()])
	var body := StaticBody3D.new()
	body.collision_mask = 0
	parent.add_child(body)
	Kit.collider(body, at, size)


func build_shell(parent: Node3D, index: int, workshop: bool) -> void:
	var size: Vector2 = Data.BUILDINGS["workshop" if workshop else "cabin"].size
	plank_deck(parent, size)
	var x := size.x * .5 - .09
	var z := size.y * .5 - .08
	var opening := 1.28
	clapboard(parent, Vector3(0, 1.19, -z), Vector3(size.x, 2.38, .18))
	for side in [-1.0, 1.0]:
		clapboard(parent, Vector3(side * (x + opening * .5) * .5, 1.18, z),
			Vector3(x - opening * .5, 2.36, .17))
		clapboard(parent, Vector3(side * x, .49, 0), Vector3(.17, .98, size.y))
		clapboard(parent, Vector3(side * x, 2.21, 0), Vector3(.17, .34, size.y))
		for edge in [-1.0, 1.0]:
			clapboard(parent, Vector3(side * x, 1.50, edge * (z + .72) * .5),
				Vector3(.17, 1.04, z - .72))
			Kit.box_at(parent, Vector3(side * x, 1.19, edge * z), Vector3(.21, 2.39, .22), trim)
		window_wall(parent, side * x)
		Kit.box_at(parent, Vector3(side * (.65 + .04), 1.06, z), Vector3(.11, 2.12, .22), trim)
	clapboard(parent, Vector3(0, 2.25, z), Vector3(1.35, .22, .18))
	Kit.box_at(parent, Vector3(0, 2.13, z), Vector3(1.43, .12, .23), trim)
	add_door(parent, Vector3(-.62, 0, z), index, workshop)
	gabled_roof(parent, size, 2.39)
	var step_end := parent.to_global(Vector3(0, 0, size.y * .5 + 1.06))
	var drop := parent.global_position.y - land_height(step_end)
	if drop > .21:
		var steps := clampi(ceili(drop / .20), 2, 6)
		for i in range(steps):
			var rise := drop * (float(steps - i) / steps)
			solid(parent, Vector3(0, -drop + rise * .5 - .006, size.y * .5 + .13 + i * .23),
				Vector3(1.55, rise, .26), trim)
	if workshop:
		furnish_shop(parent, index)
	else:
		furnish_cabin(parent)


func window_wall(parent: Node3D, x: float) -> void:
	solid(parent, Vector3(x, 1.50, 0), Vector3(.026, 1.045, 1.45), glass)
	for y in [1.00, 1.50, 2.01]:
		Kit.box_at(parent, Vector3(x, y, 0), Vector3(.23, .072, 1.56), trim)
	for z in [-.73, 0.0, .73]:
		Kit.box_at(parent, Vector3(x, 1.5, z), Vector3(.22, 1.03, .071), trim)
	Kit.box_at(parent, Vector3(x, .95, 0), Vector3(.29, .085, 1.73), trim)


func gabled_roof(parent: Node3D, size: Vector2, eave: float) -> void:
	var half := size.x * .5 + .30
	var angle := .41
	var high := half * tan(angle)
	for side in [-1.0, 1.0]:
		var panel := Node3D.new()
		parent.add_child(panel)
		panel.position = Vector3(side * half * .5, eave + high * .5, 0)
		panel.rotation.z = -side * angle
		Kit.box_at(panel, Vector3.ZERO, Vector3(half / cos(angle) + .06, .105, size.y + .68), roofing)
		for seam in 10:
			var offset := (float(seam) - 4.5) / 10.0 * (size.y + .61)
			Kit.box_at(panel, Vector3(0, .071, offset), Vector3(half / cos(angle), .034, .043), steel)
		for z in [-1.0, 1.0]:
			Kit.box_at(panel, Vector3(0, -.026, z * (size.y * .5 + .34)),
				Vector3(half / cos(angle) + .17, .166, .10), trim)
	Kit.box_at(parent, Vector3(0, eave + high + .068, 0), Vector3(.19, .14, size.y + .76), roofing)
	for end in [-1.0, 1.0]:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.add_vertex(Vector3(-half + .31, eave - .025, end * (size.y * .5 - .08)))
		surface.add_vertex(Vector3(half - .31, eave - .025, end * (size.y * .5 - .08)))
		surface.add_vertex(Vector3(0, eave + high - .018, end * (size.y * .5 - .08)))
		surface.generate_normals()
		Kit.mesh_at(parent, surface.commit(), Vector3.ZERO, logs[1])


func add_door(parent: Node3D, at: Vector3, index: int, workshop: bool) -> void:
	var hinge := AnimatableBody3D.new()
	hinge.collision_mask = 0
	hinge.sync_to_physics = false
	parent.add_child(hinge)
	hinge.position = at
	hinge.set_meta("door_id", "%d/%s" % [index, "workshop" if workshop else "cabin"])
	doors.append(hinge)
	var door_paint := finish(Color("#416060") if workshop else Color("#344a52"), true)
	Kit.box_at(hinge, Vector3(.61, 1.033, .015), Vector3(1.22, 2.06, .092), door_paint)
	Kit.collider(hinge, Vector3(.61, 1.033, .015), Vector3(1.22, 2.06, .092))
	for side in [-1.0, 1.0]:
		for y in [.21, 1.15, 1.89]:
			Kit.box_at(hinge, Vector3(.61, y, side * .069), Vector3(1.12, .079, .033), trim)
		Kit.box_at(hinge, Vector3(1.07, 1.02, side * .108), Vector3(.14, .035, .05), steel)


func bench(parent: Node3D, at: Vector3, size: Vector2, height: float, material: Material) -> void:
	Kit.box_at(parent, at + Vector3.UP * height, Vector3(size.x, .095, size.y), material)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			Kit.box_at(parent, at + Vector3(x * (size.x * .5 - .1), height * .5, z * (size.y * .5 - .10)),
				Vector3(.10, height, .10), wood)


func furnish_cabin(parent: Node3D) -> void:
	bench(parent, Vector3(-1.58, 0, -1.80), Vector2(1.60, .92), .34, wood)
	Kit.box_at(parent, Vector3(-1.58, .443, -1.80), Vector3(1.54, .15, .89), Kit.paint(Color("#586d64")))
	Kit.box_at(parent, Vector3(-2.09, .556, -1.8), Vector3(.36, .10, .60), trim)
	bench(parent, Vector3(1.56, 0, .35), Vector2(1.35, .79), .76, wood)
	bench(parent, Vector3(1.55, 0, 1.06), Vector2(.43, .40), .41, trim)
	Kit.box_at(parent, Vector3(1.64, .067, .4), Vector3(1.61, .024, 1.52), Kit.paint(Color("#a87858")))
	Kit.box_at(parent, Vector3(1.84, .48, -1.83), Vector3(.73, .83, .56), rubber)
	Kit.box_at(parent, Vector3(1.84, .96, -1.83), Vector3(.81, .12, .66), roofing)
	Kit.box_at(parent, Vector3(1.81, .52, -1.53), Vector3(.44, .28, .057), Kit.paint(Color("#a46439")))
	Kit.box_at(parent, Vector3(1.84, 1.81, -1.83), Vector3(.16, 1.67, .16), rubber)
	Kit.box_at(parent, Vector3(1.84, 2.88, -1.83), Vector3(.20, .60, .20), rubber)
	Kit.box_at(parent, Vector3(1.84, 3.2, -1.83), Vector3(.27, .08, .27), steel)
	Kit.box_at(parent, Vector3(.32, 2.21, -.40), Vector3(.40, .13, .26), light_paint)
	lamplight(parent, Vector3(.32, 2.10, -.39), 5.1, .66)


func furnish_shop(parent: Node3D, index: int) -> void:
	bench(parent, Vector3(0, 0, -1.43), Vector2(3.32, .68), .92, wood)
	Kit.box_at(parent, Vector3(0, 1.56, -1.84), Vector3(3.26, .75, .096), roofing)
	for i in 8:
		var offset := float(i) * .31 - 1.08
		Kit.box_at(parent, Vector3(offset, 1.57, -1.78), Vector3(.068, .32 + .02 * (i % 3), .045), steel)
		Kit.box_at(parent, Vector3(offset, 1.77, -1.756), Vector3(.121, .09, .048), rubber)
	Kit.box_at(parent, Vector3(-1.3, 1.04, -1.41), Vector3(.32, .15, .27), steel)
	Kit.box_at(parent, Vector3(1.05, .99, -1.33), Vector3(.36, .054, .28), trim)
	text_on(parent, "WORKBENCH", Vector3(0, 2.05, -1.77), 51, .0026, Color("#eed6ae"))
	var lamp := lamplight(parent, Vector3(0, 2.22, -.27), 5.3, .60)
	lamp.set_meta("site", index)
	powered_lamps.append(lamp)
	Kit.box_at(parent, Vector3(0, 2.26, -.27), Vector3(.61, .08, .19), light_paint)


func lamplight(parent: Node3D, at: Vector3, reach: float, strength: float) -> OmniLight3D:
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("#ffdb9c")
	lamp.light_energy = strength
	lamp.omni_range = reach
	parent.add_child(lamp)
	lamp.position = at
	return lamp


func build_porch(parent: Node3D) -> void:
	plank_deck(parent, Vector2(5.68, 1.98))
	for side in [-1.0, 1.0]:
		solid(parent, Vector3(side * 2.59, 1.10, .88), Vector3(.16, 2.31, .16), trim)
		Kit.box_at(parent, Vector3(side * 1.80, .85, .88), Vector3(1.40, .10, .135), trim)
		for step in 5:
			Kit.box_at(parent, Vector3(side * (1.14 + step * .25), .44, .88), Vector3(.052, .80, .058), wood)
		bench(parent, Vector3(side * 1.74, 0, .19), Vector2(.80, .61), .42, wood)
	var canopy := Kit.box_at(parent, Vector3(0, 2.35, .0), Vector3(5.98, .12, 2.37), roofing)
	canopy.rotation.x = .065
	var edge := parent.to_global(Vector3(0, 0, 1.46))
	var height := maxf(.0, parent.global_position.y - land_height(edge))
	for index in clampi(ceili(height / .19), 1, 5):
		var rise := maxf(.09, height - index * .19)
		solid(parent, Vector3(0, -height + rise * .5 - .006, 1.09 + index * .22),
			Vector3(1.75, rise, .25), trim)


func build_slip(parent: Node3D, index: int, dry: bool) -> void:
	for side in [-1.0, 1.0]:
		var x: float = 2.1 * side
		walkway(parent, Vector3(x, 0, 3.9), Vector3(x, 0, -3.95), .77, false)
		for z in [-3.62, 0.0, 3.47]:
			Kit.box_at(parent, Vector3(x, .60, z), Vector3(.21, 4.96, .23), trim)
	walkway(parent, Vector3(-2.44, 0, 3.53), Vector3(2.46, 0, 3.53), 1.21, false)
	var end_world := parent.to_local(sites[index].transfer)
	var start := Vector3(-2.15 if not dry else 2.15, 0, 3.55)
	walkway(parent, start, Vector3(end_world.x, 0, end_world.z + 2.5), .98, false)
	if dry:
		var cradle := Node3D.new()
		parent.add_child(cradle)
		cradle.position.y = -.74
		cradle.set_meta("pulleys", [])
		dry_lifts[index] = cradle
		for x: float in [-.78, .78]:
			Kit.box_at(cradle, Vector3(x, .194, 0), Vector3(.18, .35, 6.8), steel)
		for z in [-2.36, 1.7]:
			Kit.box_at(parent, Vector3(0, 2.83, z), Vector3(4.68, .39, .27), steel)
			Kit.box_at(cradle, Vector3(0, 0, z), Vector3(3.71, .18, .31), steel)
			for x: float in [-1.62, 1.62]:
				var cable := Kit.box_at(parent, Vector3(x, .92, z), Vector3(.038, 1, .038), rubber)
				cradle.get_meta("pulleys").append(cable)
				Kit.box_at(parent, Vector3(x, 2.59, z), Vector3(.25, .31, .24), steel)
		var lever := Kit.box_at(parent, Vector3(2.02, 1.10, 2.19), Vector3(.28, .78, .38), steel)
		Kit.box_at(lever, Vector3(0, .34, -.202), Vector3(.14, .085, .038), light_paint)
	else:
		gabled_roof(parent, Vector2(4.61, 7.9), 2.73)
		Kit.box_at(parent, Vector3(1.91, .58, 2.60), Vector3(.36, .99, .30), steel)
		Kit.box_at(parent, Vector3(1.91, 1.15, 2.60), Vector3(.39, .10, .32), light_paint)
	var sign := text_on(parent, "DRY DOCK" if dry else "BOATHOUSE", Vector3(0, 2.61, -4.01), 56, .0032, Color("#eed6ae"))
	sign.rotation.y = PI


func build_turbine(parent: Node3D, index: int) -> void:
	Kit.box_at(parent, Vector3(0, -.66, 0), Vector3(.27, 3.22, .28), steel)
	Kit.box_at(parent, Vector3(0, -.02, 0), Vector3(1.5, .20, 1.81), roofing)
	Kit.box_at(parent, Vector3(.56, .37, .38), Vector3(.31, .66, .43), steel)
	Kit.box_at(parent, Vector3(.56, .724, .38), Vector3(.17, .06, .21), light_paint)
	var rotor := Node3D.new()
	parent.add_child(rotor)
	rotor.position = Vector3(0, -.74, -.12)
	rotor.set_meta("site", index)
	rotors.append(rotor)
	var ring := TorusMesh.new()
	ring.inner_radius = .64
	ring.outer_radius = .73
	ring.rings = 12
	ring.ring_segments = 8
	Kit.mesh_at(parent, ring, rotor.position, steel).rotation.x = PI * .5
	for fin in 5:
		var theta := float(fin) * TAU / 5.0
		var vector := Vector3(cos(theta), sin(theta), 0)
		var blade := Kit.box_at(rotor, vector * .35, Vector3(.55, .12, .052), steel)
		blade.rotation.z = theta + .19
	var near_dock: Vector3 = parent.to_local(sites[index].dock)
	Kit.beam(parent, Vector3(0, -.20, 0), Vector3(near_dock.x, -.35, near_dock.z), .043, rubber)


func aimed_door(eye: Camera3D) -> AnimatableBody3D:
	for hinge in doors:
		if not is_instance_valid(hinge) or hinge.is_queued_for_deletion():
			continue
		var offset := hinge.to_global(Vector3(.61, 1.04, .025)) - eye.global_position
		if offset.length_squared() < 2.9 * 2.9 and (-eye.global_basis.z).dot(offset.normalized()) > .91:
			return hinge
	return null


func animate(delta: float, clock: float) -> void:
	for door in doors:
		if is_instance_valid(door):
			var wanted := 1.59 if ledger.state.doors.get(door.get_meta("door_id"), false) else 0.0
			door.rotation.y = move_toward(door.rotation.y, wanted, delta * 3.8)
	for rotor in rotors:
		if is_instance_valid(rotor):
			var current := river.downstream(rotor.global_position, clock).length()
			rotor.rotate_z(delta * (1.1 + current * 4.0))
	for lamp in powered_lamps:
		if is_instance_valid(lamp):
			lamp.light_energy = .83 if ledger.has_at(int(lamp.get_meta("site")), "turbine") else .26
	for index: int in dry_lifts:
		var cradle: Node3D = dry_lifts[index]
		if not is_instance_valid(cradle):
			continue
		var ready := ledger.has_at(index, "turbine") and bool(ledger.state.lifts.get(str(index), false))
		cradle.position.y = move_toward(cradle.position.y, .98 if ready else -.74, delta * .57)
		for cable: MeshInstance3D in cradle.get_meta("pulleys"):
			cable.position.y = (2.59 + cradle.position.y) * .5
			cable.scale.y = 2.59 - cradle.position.y
