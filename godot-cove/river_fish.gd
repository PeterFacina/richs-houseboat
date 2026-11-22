extends Node3D

const Kit = preload("res://scenery.gd")
const FishMaterial = preload("res://river_fish.gdshader")
const Catalog = preload("res://fish_species.gd")

# Sections run from the lips to the caudal peduncle. Each row is length, height, width, back, belly.
const SECTIONS := [
	[[0, -0.01, .024, .025, .021], [.06, .003, .051, .052, .047], [.15, .014, .067, .082, .065],
		[.24, .015, .089, .108, .089], [.39, .013, .091, .107, .108], [.57, .020, .068, .081, .088],
		[.74, .011, .037, .045, .049], [.85, .005, .021, .025, .027], [.90, .004, .014, .019, .020]],
	[[0, -.018, .033, .041, .029], [.075, -.009, .065, .073, .050], [.15, .006, .090, .112, .076],
		[.25, .015, .113, .116, .106], [.39, .012, .115, .116, .122], [.57, .006, .085, .085, .090],
		[.74, .003, .048, .052, .054], [.86, .002, .024, .033, .033], [.90, .006, .016, .027, .024]],
	[[0, -.010, .024, .025, .021], [.070, -.009, .045, .049, .041], [.16, .012, .063, .072, .062],
		[.25, .016, .081, .084, .080], [.40, .011, .084, .096, .093], [.58, .009, .064, .067, .075],
		[.74, .008, .036, .042, .042], [.85, .005, .018, .024, .026], [.90, .003, .014, .020, .022]],
	[[0, -.021, .027, .010, .012], [.048, -.021, .037, .019, .018], [.105, -.011, .045, .031, .026],
		[.185, .002, .055, .055, .043], [.28, .006, .061, .065, .052], [.42, .004, .068, .065, .065],
		[.61, .006, .059, .061, .059], [.76, .002, .042, .039, .040], [.88, .002, .018, .025, .027]],
]
# Width, height, and back offset at the snout, shoulder, midbody and peduncle.
const PROPORTIONS := {
	"minnow": [Vector3(.023,.021,0), Vector3(.060,.061,.009), Vector3(.052,.076,.006), Vector3(.014,.019,.002)],
	"shiner": [Vector3(.018,.021,0), Vector3(.046,.074,.004), Vector3(.045,.090,.009), Vector3(.012,.020,.001)],
	"chub": [Vector3(.037,.027,0), Vector3(.070,.075,.006), Vector3(.061,.081,.010), Vector3(.013,.022,.002)],
	"silverside": [Vector3(.019,.015,-.002), Vector3(.041,.045,.003), Vector3(.034,.053,.004), Vector3(.010,.015,.001)],
	"carp": [Vector3(.033,.023,-.030), Vector3(.102,.123,.009), Vector3(.109,.146,.014), Vector3(.023,.030,.001)],
	"sucker": [Vector3(.029,.016,-.029), Vector3(.070,.066,-.004), Vector3(.082,.092,.005), Vector3(.017,.021,.001)],
	"redhorse": [Vector3(.029,.018,-.027), Vector3(.072,.073,.006), Vector3(.084,.109,.009), Vector3(.017,.025,.001)],
	"sunfish": [Vector3(.018,.030,-.012), Vector3(.063,.119,.008), Vector3(.069,.164,.007), Vector3(.015,.029,.001)],
	"crappie": [Vector3(.026,.033,-.012), Vector3(.060,.106,.006), Vector3(.057,.149,.020), Vector3(.015,.028,.003)],
	"drum": [Vector3(.032,.028,-.036), Vector3(.090,.132,.013), Vector3(.076,.130,.010), Vector3(.018,.027,.001)],
	"mooneye": [Vector3(.022,.021,.012), Vector3(.053,.089,.007), Vector3(.052,.105,.002), Vector3(.014,.022,.004)],
	"shad": [Vector3(.023,.020,.003), Vector3(.057,.086,.003), Vector3(.057,.119,.006), Vector3(.013,.020,.001)],
	"whitefish": [Vector3(.022,.018,-.016), Vector3(.065,.067,.004), Vector3(.066,.098,.006), Vector3(.015,.020,.001)],
	"salmonid": [Vector3(.031,.028,-.010), Vector3(.076,.075,.005), Vector3(.078,.090,.006), Vector3(.018,.023,.002)],
	"sculpin": [Vector3(.042,.030,-.012), Vector3(.126,.077,.005), Vector3(.051,.059,-.010), Vector3(.015,.019,.001)],
	"darter": [Vector3(.031,.022,-.009), Vector3(.072,.059,.007), Vector3(.060,.054,.005), Vector3(.014,.018,.002)],
	"stickle": [Vector3(.034,.024,-.007), Vector3(.055,.068,.005), Vector3(.052,.061,.008), Vector3(.011,.017,.001)],
	"mudminnow": [Vector3(.036,.024,-.009), Vector3(.063,.061,.005), Vector3(.059,.075,.003), Vector3(.022,.024,.002)],
	"bullhead": [Vector3(.048,.023,-.013), Vector3(.127,.081,-.006), Vector3(.087,.084,.002), Vector3(.026,.034,.002)],
	"catfish": [Vector3(.036,.026,-.017), Vector3(.097,.067,-.004), Vector3(.071,.076,.001), Vector3(.016,.027,.001)],
	"burbot": [Vector3(.043,.027,-.022), Vector3(.108,.076,.002), Vector3(.067,.059,-.003), Vector3(.014,.027,.005)],
	"bowfin": [Vector3(.048,.027,-.015), Vector3(.096,.081,.001), Vector3(.074,.081,.006), Vector3(.022,.036,.002)],
	"eel": [Vector3(.012,.010,-.006), Vector3(.036,.034,.002), Vector3(.041,.039,.007), Vector3(.006,.013,.002)],
	"lamprey": [Vector3(.025,.018,-.008), Vector3(.026,.027,.002), Vector3(.028,.029,.004), Vector3(.008,.013,.001)],
	"gar": [Vector3(.007,.008,-.006), Vector3(.049,.048,.001), Vector3(.052,.063,.004), Vector3(.015,.021,.001)],
	"sturgeon": [Vector3(.008,.009,-.032), Vector3(.068,.064,.011), Vector3(.069,.071,.006), Vector3(.010,.016,.020)]
}

var models: Array[Node3D] = []
var skins: Array[Array] = []
var current := -1
var metres := 0.4


func select_species(kind: int, length_cm: int) -> void:
	while models.size() < Catalog.all().size():
		models.append(null)
		skins.append([])
	if models[kind] == null:
		build_fish(kind)
	if current >= 0:
		models[current].hide()
	current = kind
	metres = length_cm / 100.0
	models[current].show()


func pose(head: Vector3, direction: Vector3, roll: float, tail: float, phase: float) -> void:
	if current < 0:
		return
	var forward := direction.normalized()
	var side := Vector3.UP if absf(forward.y) < 0.96 else Vector3.RIGHT
	var attitude := Basis.looking_at(forward, side).rotated(forward, roll)
	global_transform = Transform3D(attitude.scaled_local(Vector3.ONE * metres), head)
	for material: ShaderMaterial in skins[current]:
		material.set_shader_parameter("swim", tail)
		material.set_shader_parameter("phase", phase)


func build_fish(kind: int) -> void:
	var profile := Catalog.profile(kind)
	var form: String = profile.form
	var section := body_sections(form)
	var fish := Node3D.new()
	fish.name = profile.name
	add_child(fish)
	models[kind] = fish
	var body := ShaderMaterial.new()
	body.shader = FishMaterial
	body.set_shader_parameter("pattern", Catalog.PATTERNS.find(profile.pattern))
	body.set_shader_parameter("back", Color(profile.colors[0]))
	body.set_shader_parameter("flank", Color(profile.colors[1]))
	body.set_shader_parameter("belly", Color(profile.colors[2]))
	body.set_shader_parameter("pattern_phase", float(kind) * .79)
	body.set_shader_parameter("elongated", form in ["eel", "burbot", "lamprey"])
	var web := ShaderMaterial.new()
	web.shader = FishMaterial
	web.set_shader_parameter("fin", true)
	web.set_shader_parameter("elongated", form in ["eel", "burbot", "lamprey"])
	skins[kind] = [body, web]
	Kit.mesh_at(fish, body_mesh(section), Vector3.ZERO, body)
	var fin_color := Color(profile.colors[0]).lerp(Color(profile.colors[1]), .54)
	if form in ["redhorse", "perch"] or profile.pattern == "brook_char":
		fin_color = Color("#b47849")
	build_tail(fish, form, section, fin_color, web, profile.name == "Walleye")
	build_dorsal(fish, form, section, fin_color, web)
	if form not in ["lamprey", "eel"]:
		fin_web(fish, section, .62, .855, -.071, fin_color, web)
	for side: float in [-1.0, 1.0]:
		if form != "lamprey":
			build_paired_fins(fish, form, section, side, fin_color, web)
		draw_head(fish, profile, section, side)
	if form == "sturgeon":
		build_scutes(fish, section, fin_color.lightened(.44), web)


func body_sections(form: String) -> Array:
	var preset := ["perch", "bass", "zander", "esox"].find(form)
	if preset >= 0:
		return SECTIONS[preset]
	var proportions: Array = PROPORTIONS[form]
	var nose_end := .21 if form == "gar" else (.082 if form == "sturgeon" else .06)
	var tail_end := .94 if form in ["eel", "burbot", "lamprey", "bowfin"] else .88
	var result: Array = []
	for z: float in [0.0, nose_end * .65, nose_end, .30, .40, .48, .57, .68, .78, tail_end]:
		var a := 0 if z <= .30 else (1 if z <= .43 else 2)
		var starts: Array = [nose_end, .30, .43]
		var ends: Array = [.30, .43, tail_end]
		var shape: Vector3 = proportions[a].lerp(proportions[a + 1], smoothstep(starts[a], ends[a], z))
		if form in ["gar", "sturgeon"] and z <= nose_end:
			shape.x *= lerpf(.62, 1.66, z / nose_end)
			shape.y *= lerpf(.70, 1.51, z / nose_end)
		result.append([z, shape.z, shape.x, shape.y, shape.y * (.83 if form in ["gar", "catfish", "sculpin"] else .94)])
	return result


func section_at(section: Array, z: float) -> Vector4:
	for index in range(1, section.size()):
		var next: Array = section[index]
		if z <= next[0]:
			var prev: Array = section[index - 1]
			var weight := inverse_lerp(prev[0], next[0], z)
			return Vector4(prev[1], prev[2], prev[3], prev[4]).lerp(Vector4(next[1], next[2], next[3], next[4]), weight)
	var tail: Array = section[-1]
	return Vector4(tail[1], tail[2], tail[3], tail[4])


func build_tail(fish: Node3D, form: String, section: Array, color: Color, web: Material, white_tip: bool) -> void:
	var fork := .946 if form in ["minnow", "shiner", "whitefish", "salmonid", "catfish", "esox", "redhorse", "shad", "gar"] else .982
	var height := .107
	if form in ["eel", "lamprey", "burbot", "darter", "silverside"]:
		height = .049
	if form in ["drum", "crappie", "sunfish", "carp", "mooneye"]:
		height = .133
	var upper := height * (1.62 if form == "sturgeon" else 1.0)
	var lower := height * (.55 if form == "sturgeon" else .92)
	var tips := [Vector3(0, upper, .985), Vector3(0, upper * .50, 1.0), Vector3(0, .011, fork),
		Vector3(0, -.009, fork), Vector3(0, -lower * .60, .991), Vector3(0, -lower, .980)]
	build_fin(fish, Vector3(0, float(section[-1][1]), float(section[-1][0]) - .035), tips, color, web, white_tip)


func build_dorsal(fish: Node3D, form: String, section: Array, color: Color, web: Material) -> void:
	match form:
		"eel", "lamprey", "burbot", "bowfin":
			fin_web(fish, section, .34 if form in ["eel", "bowfin"] else .52, .966, .028, color, web)
			if form != "bowfin":
				fin_web(fish, section, .53, .965, -.032, color, web)
		"esox", "gar", "sturgeon", "mudminnow":
			fin_web(fish, section, .62, .86, .075, color, web)
		"perch", "zander", "bass", "darter", "sculpin", "sunfish", "crappie", "drum":
			fin_web(fish, section, .234, .56, .100, color.darkened(.15), web, true)
			fin_web(fish, section, .515, .78, .062, color, web)
		"stickle":
			for i in 5:
				var point := .27 + i * .052
				fin_web(fish, section, point, point + .035, .056, color.lightened(.22), web)
			fin_web(fish, section, .53, .77, .048, color, web)
		"salmonid", "whitefish", "bullhead", "catfish":
			fin_web(fish, section, .27, .53, .087, color, web)
			fin_web(fish, section, .68, .80, .030, color, web)
		_:
			fin_web(fish, section, .39, .62, .074, color, web)


func fin_web(fish: Node3D, section: Array, start: float, end: float, height: float,
		color: Color, web: Material, rays := false) -> void:
	var outline: Array[Vector3] = []
	for index in 13:
		var ratio := float(index) / 12.0
		var z := lerpf(start, end, ratio)
		var shape := section_at(section, z)
		var edge := shape.x + (shape.z if height > 0.0 else -shape.w)
		var ridge := sin(pow(ratio, .67) * PI) * (1.0 if not rays or index % 2 == 0 else .87)
		outline.append(Vector3(0, edge + height * ridge, z))
	var middle := lerpf(start, end, .42)
	var body := section_at(section, middle)
	var root := Vector3(0, body.x + (body.z if height > 0.0 else -body.w) * .78, middle)
	build_fin(fish, root, outline, color, web)


func build_paired_fins(fish: Node3D, form: String, section: Array, side: float, color: Color, web: Material) -> void:
	var shoulder := section_at(section, .27)
	var base := Vector3(side * shoulder.y * .84, shoulder.x - shoulder.w * .42, .266)
	var reach := .127 if form == "sculpin" else (.033 if form == "eel" else .064)
	build_fin(fish, base, [base + Vector3(side * .012, .016, .017),
		base + Vector3(side * reach, -.020, .086), base + Vector3(side * reach * .94, -.054, .154),
		base + Vector3(side * .019, -.046, .172), base + Vector3(0, -.022, .098)], color.lightened(.14), web)
	if form != "eel":
		var pelvic := section_at(section, .42)
		var root := Vector3(side * pelvic.y * .47, pelvic.x - pelvic.w * .77, .418)
		build_fin(fish, root, [root + Vector3(side * .019, -.044, .019), root + Vector3(side * .038, -.059, .084),
			root + Vector3(side * .027, -.042, .131), root + Vector3(0, -.013, .092)], color, web)


func body_mesh(section: Array) -> ArrayMesh:
	const SIDES := 32
	const SUBDIVISIONS := 4
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := (section.size() - 1) * SUBDIVISIONS + 1
	for row in rings:
		var segment := mini(floori(float(row) / SUBDIVISIONS), section.size() - 2)
		var t := float(row - segment * SUBDIVISIONS) / SUBDIVISIONS
		var a: Array = section[segment]
		var b: Array = section[segment + 1]
		for side in SIDES + 1:
			var u := float(side) / SIDES
			var angle := u * TAU
			var z := lerpf(a[0], b[0], t)
			var offset := lerpf(a[1], b[1], t)
			var width := lerpf(a[2], b[2], t)
			var rise := lerpf(a[3], b[3], t) if cos(angle) >= 0.0 else lerpf(a[4], b[4], t)
			var p := Vector3(sin(angle) * width, offset + cos(angle) * rise, z)
			surface.set_uv(Vector2(z, u))
			surface.set_normal(Vector3(sin(angle) / width, cos(angle) / rise, -maxf(0.0, .14 - z) * 36.0).normalized())
			surface.add_vertex(p)
	for row in rings - 1:
		for side in SIDES:
			var j := row * (SIDES + 1) + side
			var k := j + SIDES + 1
			for index in [j, j + 1, k, j + 1, k + 1, k]:
				surface.add_index(index)
	for rim: int in [0, rings - 1]:
		var data: Array = section[0] if rim == 0 else section[-1]
		surface.set_normal(Vector3.FORWARD if rim == 0 else Vector3.BACK)
		surface.set_uv(Vector2(data[0], 0.25))
		var cap := rings * (SIDES + 1) + int(rim > 0)
		surface.add_vertex(Vector3(0, data[1], data[0]))
		for edge in SIDES:
			var index := rim * (SIDES + 1) + edge
			var triangle := [cap, index + 1, index] if rim == 0 else [cap, index, index + 1]
			for key in triangle:
				surface.add_index(key)
	return surface.commit()


func build_fin(fish: Node3D, root: Vector3, edge: Array, color: Color, material: Material, white_tip := false) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in edge.size() - 1:
		var a: Vector3 = edge[i]
		var b: Vector3 = edge[i + 1]
		surface.set_normal((a - root).cross(b - root).normalized())
		surface.set_color(color.darkened(0.36))
		surface.add_vertex(root)
		surface.set_color(Color("#e9debf") if white_tip and a.y < -.065 else color.lightened(0.21))
		surface.add_vertex(a)
		surface.set_color(Color("#e9debf") if white_tip and b.y < -.065 else color.lightened(0.08))
		surface.add_vertex(b)
		var ray := (b - a).normalized() * .0028
		surface.set_color(color.lightened(0.26))
		for p: Vector3 in [root + Vector3.RIGHT * .0018, a + Vector3.RIGHT * .0018, a + ray + Vector3.RIGHT * .0018]:
			surface.add_vertex(p)
	var item := Kit.mesh_at(fish, surface.commit(), Vector3.ZERO, material)
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func draw_head(fish: Node3D, profile: Dictionary, section: Array, side: float) -> void:
	var form: String = profile.form
	var eye_size := .016 if form in ["bullhead", "sturgeon", "catfish", "eel", "lamprey"] else .021
	if form == "mooneye" or profile.name in ["Walleye", "Rock Bass", "Goldeye"]:
		eye_size = .027
	var eye_z := .271 if form == "gar" else (.18 if form == "sturgeon" else (.137 if form == "esox" else .133))
	var tissues := section_at(section, eye_z)
	var eye := Vector3(side * tissues.y * .94, tissues.x + tissues.z * .31, eye_z)
	var socket := Kit.paint(Color("#54482d"), .53)
	var eye_color := "#bda665"
	if profile.name in ["Walleye", "Cisco (lake herring)", "Lake Whitefish"]:
		eye_color = "#c9c7a6"
	elif profile.name in ["Rock Bass", "Smallmouth bass", "Longear Sunfish"]:
		eye_color = "#b45e3f"
	var iris := Kit.paint(Color(eye_color), .32, .16)
	var pupil := Kit.paint(Color("#111a17"), .14, .22)
	ellipsoid(fish, eye, Vector3(.009, eye_size * 1.15, eye_size * 1.11), socket)
	ellipsoid(fish, eye + Vector3.RIGHT * side * .0055, Vector3(.007, eye_size, eye_size), iris)
	ellipsoid(fish, eye + Vector3(side * .011, .0005, -.0021), Vector3(.004, eye_size * .58, eye_size * .55), pupil)
	var white := Kit.paint(Color("#e9eee3"), .22)
	ellipsoid(fish, eye + Vector3(side * .015, eye_size * .34, -eye_size * .25), Vector3(.0013, .0027, .0026), white)
	var seam := Kit.paint(Color(profile.colors[0]).darkened(.34), .61)
	if form == "lamprey":
		for i in 7:
			var z := .141 + i * .013
			var pore := section_at(section, z)
			ellipsoid(fish, Vector3(side * pore.y, pore.x, z), Vector3(.0016, .0043, .0039), seam)
		if side > 0.0:
			ellipsoid(fish, Vector3(0, -.012, -.004), Vector3(.020, .015, .006), seam)
		return
	var join := .269 if form == "gar" else (.175 if form in ["esox", "bass", "catfish"] else .102)
	var lip := section_at(section, .007)
	var angle := section_at(section, join * .63)
	var hinge := section_at(section, join)
	var edge := Vector3(side * lip.y * .84, lip.x - lip.w * .28, .004)
	var middle := Vector3(side * angle.y * .97, angle.x - angle.w * .27, join * .63)
	var corner := Vector3(side * hinge.y * .92, hinge.x - hinge.w * .44, join)
	Kit.beam(fish, edge, middle, .0031, seam)
	Kit.beam(fish, middle, corner, .0029, seam)
	if form in ["catfish", "bullhead", "sturgeon", "burbot", "carp"]:
		var long_whisker := .134 if form in ["catfish", "bullhead"] else (.058 if form == "sturgeon" else .035)
		var strand := Kit.paint(Color(profile.colors[0]).lerp(Color(profile.colors[2]), .41), .55)
		var base := edge if form not in ["sturgeon", "burbot"] else Vector3(side * .015, -.034, .085)
		if not (form == "burbot" and side < 0.0):
			var spread := side * long_whisker * (.77 if form != "burbot" else .05)
			var a := base + Vector3(spread * .59, -long_whisker * .19, long_whisker * .35)
			Kit.beam(fish, base, a, .0038, strand)
			Kit.beam(fish, a, base + Vector3(spread, -long_whisker * .39, long_whisker * .69), .0021, strand)
			if form in ["catfish", "bullhead"]:
				for i in 3:
					var chin := base + Vector3(-side * .011 * i, -.012, .004 * i)
					Kit.beam(fish, chin, chin + Vector3(side * (.029 - .004 * i), -.028, .037 - .003 * i), .0025, strand)


func build_scutes(fish: Node3D, section: Array, color: Color, web: Material) -> void:
	var plates := SurfaceTool.new()
	plates.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row: float in [-1.0, 0.0, 1.0]:
		for index in 11:
			var z := .219 + index * .049
			var shape := section_at(section, z)
			var middle := Vector3(row * shape.y * 1.01, shape.x + (shape.z * .96 if row == 0.0 else .015), z)
			var direction := Vector3(row * .82, .66, 0).normalized()
			var crosswise := direction.cross(Vector3.BACK) * .012
			var peak := middle + direction * .010
			plates.set_color(color if index % 2 == 0 else color.darkened(.20))
			plates.set_normal(direction)
			for v in [middle - crosswise, middle - Vector3.BACK * .021, peak,
					middle - Vector3.BACK * .021, middle + crosswise, peak,
					middle + crosswise, middle + Vector3.BACK * .024, peak,
					middle + Vector3.BACK * .024, middle - crosswise, peak]:
				plates.add_vertex(v)
	Kit.mesh_at(fish, plates.commit(), Vector3.ZERO, web)


func ellipsoid(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> void:
	var lens := SphereMesh.new()
	lens.radial_segments = 18
	lens.rings = 9
	Kit.mesh_at(parent, lens, at, material).scale = size * 2.0
