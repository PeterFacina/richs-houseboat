extends Node3D

const Kit = preload("res://scenery.gd")
const IDLE_RPM := 760.0
const WIDE_OPEN_RPM := 5700.0

var swivel := Node3D.new()
var leg := Node3D.new()
var prop := Node3D.new()
var rpm := 0.0
var steering := 0.0
var thrust := 0.0
var gear := 0
var electric := false
var sound: AudioStreamPlayer3D
var cooling: CPUParticles3D


func _ready() -> void:
	name = "SternOutboard"
	var casing := Kit.paint(Color("#406764") if electric else Color("#273039"), .34, .21)
	var lower := Kit.paint(Color("#49565c"), .37, .36)
	var seal := Kit.paint(Color("#181e21"), .68)
	var metal := Kit.paint(Color("#a0a4a3"), .30, .63)
	var propeller := Kit.paint(Color("#848b8c"), .21, .73)
	var stripe := Kit.paint(Color("#a6ceac") if electric else Color("#9c4b34"), .42, .24)
	for side: float in [-1, 1]:
		Kit.box_at(self, Vector3(side * .245, -.05, -.065), Vector3(.13, .46, .19), lower)
		for y: float in [-.16, .108]:
			tube(self, Vector3(side * .245, y, -.178), Vector3(side * .245, y, .055), .041, .038, metal)
	tube(self, Vector3(-.30, -.13, .02), Vector3(.30, -.13, .02), .053, .053, seal)
	add_child(leg)
	leg.position = Vector3(0, -.10, .058)
	tube(self, Vector3(0, -.33, -.04), Vector3(0, -.077, .24), .046, .026, metal)
	leg.add_child(swivel)
	var cowling := shell([
		Vector3(.142, .205, .215), Vector3(.227, .245, .342), Vector3(.242, .445, .379),
		Vector3(.219, .665, .355), Vector3(.157, .724, .285), Vector3(.035, .738, .092)])
	Kit.mesh_at(swivel, cowling, Vector3(0, 0, .27), casing)
	Kit.mesh_at(swivel, shell([Vector3(.209, .228, .312), Vector3(.224, .254, .333), Vector3(.227, .279, .338)]),
		Vector3(0, 0, .27), seal)
	for side: float in [-1, 1]:
		for y in 4:
			Kit.box_at(swivel, Vector3(side * .223, .511 + .025 * y, .42), Vector3(.023, .011, .235), seal)
		Kit.box_at(swivel, Vector3(side * .239, .370, .25), Vector3(.006, .025, .40), stripe)
		var badge := Label3D.new()
		badge.text = "E-DRIVE" if electric else "RIVER 60"
		badge.font_size = 38
		badge.pixel_size = .00142
		badge.outline_size = 0
		badge.modulate = Color("#e7e7d9")
		badge.position = Vector3(side * .253, .433, .212)
		badge.rotation.y = side * PI / 2.0
		swivel.add_child(badge)
	tube(swivel, Vector3(0, -.83, .23), Vector3(0, .255, .23), .088, .162, lower)
	Kit.box_at(swivel, Vector3(0, -.48, .245), Vector3(.26, .036, .50), lower)
	Kit.box_at(swivel, Vector3(0, -.584, .246), Vector3(.32, .029, .55), lower)
	var gearcase := SphereMesh.new()
	gearcase.radial_segments = 22
	gearcase.rings = 10
	Kit.mesh_at(swivel, gearcase, Vector3(0, -.807, .284), lower).scale = Vector3(.222, .252, .510)
	var skeg := Kit.box_at(swivel, Vector3(0, -.981, .25), Vector3(.036, .35, .226), lower)
	skeg.rotation.x = -.22
	for y in 4:
		Kit.box_at(swivel, Vector3(.086, -.724 + y * .025, .23), Vector3(.012, .009, .085), seal)
		Kit.box_at(swivel, Vector3(-.086, -.724 + y * .025, .23), Vector3(.012, .009, .085), seal)
	swivel.add_child(prop)
	prop.position = Vector3(0, -.806, .556)
	tube(prop, Vector3(0, 0, -.066), Vector3(0, 0, .097), .055, .035, propeller)
	var blade := make_blade()
	for blade_index in 3:
		var mesh := Kit.mesh_at(prop, blade, Vector3.ZERO, propeller)
		mesh.rotation.z = TAU * blade_index / 3.0
	sound = AudioStreamPlayer3D.new()
	sound.position = Vector3(0, .13, .32)
	sound.unit_size = 5.1
	sound.max_distance = 87.0
	sound.stream = engine_loop()
	add_child(sound)
	add_cooling_water()


func run(delta: float, throttle: float, rudder: float, started: bool, underway: float) -> void:
	gear = 0 if absf(throttle) < .045 else (1 if throttle > 0.0 else -1)
	var load := clampf(absf(throttle), 0.0, 1.0)
	var idle := 0.0 if electric else IDLE_RPM
	var wanted := lerpf(idle, WIDE_OPEN_RPM, pow(load, .80)) if started else 0.0
	rpm = lerpf(rpm, wanted, 1.0 - exp(-delta * 2.7))
	steering = lerpf(steering, rudder * .53, 1.0 - exp(-delta * 7.0))
	swivel.rotation.y = steering
	leg.rotation.x = lerpf(leg.rotation.x, -.016 - smoothstep(1.1, 6.8, absf(underway)) * .095, 1.0 - exp(-delta * 2.2))
	thrust = lerpf(thrust, load if gear != 0 else 0.0, 1.0 - exp(-delta * 3.6))
	prop.rotate_z(rpm * (TAU / 60.0 / 2.31) * gear * delta)
	cooling.emitting = not electric and rpm > 430.0
	cooling.initial_velocity_max = 1.09 + rpm / WIDE_OPEN_RPM * .44
	if rpm > 165.0:
		if not sound.playing:
			sound.play()
		sound.pitch_scale = clampf(rpm / (2820.0 if electric else 1320.0), .60, 4.2)
		sound.volume_db = lerpf(-30.0 if electric else -23.0, -16.0 if electric else -7.0,
			smoothstep(idle, WIDE_OPEN_RPM, rpm))
	elif sound.playing:
		sound.stop()


func wash_direction() -> Vector3:
	var jet := swivel.global_basis.z.slide(Vector3.UP).normalized()
	return -jet if gear < 0 else jet


func add_cooling_water() -> void:
	cooling = CPUParticles3D.new()
	cooling.name = "CoolingWater"
	cooling.position = Vector3(.164, .216, .434)
	cooling.amount = 35
	cooling.lifetime = .48
	cooling.direction = Vector3(.84, -.31, .442)
	cooling.spread = 5.0
	cooling.gravity = Vector3(0, -4.8, 0)
	cooling.initial_velocity_min = .84
	cooling.initial_velocity_max = 1.30
	cooling.scale_amount_min = .62
	cooling.scale_amount_max = 1.19
	var drop := SphereMesh.new()
	drop.radius = .008
	drop.height = .019
	drop.radial_segments = 6
	drop.rings = 3
	drop.material = Kit.paint(Color("#aaccce"), .24, .12)
	cooling.mesh = drop
	cooling.emitting = false
	swivel.add_child(cooling)


# An elliptical loft keeps the cowling rounded with a flatter transverse section.
func shell(rings: Array) -> ArrayMesh:
	const SIDES := 28
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring: Vector3 in rings:
		for i in SIDES:
			var angle := TAU * float(i) / SIDES
			var section := Vector2(cos(angle), sin(angle))
			var x := signf(section.x) * pow(absf(section.x), .69)
			var z := signf(section.y) * pow(absf(section.y), .79)
			surface.add_vertex(Vector3(x * ring.x, ring.y, z * ring.z))
	for row in rings.size() - 1:
		for col in SIDES:
			var a := row * SIDES + col
			var b := row * SIDES + (col + 1) % SIDES
			for vertex in [a, b, a + SIDES, b, b + SIDES, a + SIDES]:
				surface.add_index(vertex)
	var top: Vector3 = rings[-1]
	var cap := rings.size() * SIDES
	surface.add_vertex(Vector3(0, top.y, 0))
	for col in SIDES:
		surface.add_index(cap)
		surface.add_index(cap - SIDES + col)
		surface.add_index(cap - SIDES + (col + 1) % SIDES)
	surface.generate_normals()
	return surface.commit()


func make_blade() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var root := Vector3(0, .038, 0)
	var rim := [Vector3(-.038, .075, -.035), Vector3(-.059, .135, -.019), Vector3(-.042, .196, .004),
		Vector3(.021, .209, .028), Vector3(.065, .158, .039), Vector3(.038, .076, .020)]
	for index in rim.size() - 1:
		for p in [root, rim[index], rim[index + 1], root, rim[index + 1], rim[index]]:
			surface.add_vertex(p)
	surface.generate_normals()
	return surface.commit()


func tube(parent: Node3D, start: Vector3, end: Vector3, r0: float, r1: float, material: Material) -> void:
	var shape := CylinderMesh.new()
	shape.top_radius = r1
	shape.bottom_radius = r0
	shape.height = start.distance_to(end)
	shape.radial_segments = 16
	var instance := Kit.mesh_at(parent, shape, start.lerp(end, .5), material)
	instance.quaternion = Quaternion(Vector3.UP, (end - start).normalized())


func engine_loop() -> AudioStreamWAV:
	const RATE := 22050
	var pcm := PackedByteArray()
	pcm.resize(RATE * 2)
	for frame in RATE:
		var t := float(frame) / RATE
		var pulse := sin(44.0 * TAU * t)
		var compression := pow(maxf(0.0, pulse), 4.0)
		var valve := sin(TAU * (132.0 * t + .088 * sin(6.0 * TAU * t)))
		var exhaust := .50 * pulse + .14 * sin(TAU * 88.0 * t + .9) + .15 * (compression - .18)
		var value := exhaust + valve * (.062 + .050 * compression) + .023 * sin(265.0 * TAU * t)
		if electric:
			value = .38 * sin(TAU * 120.0 * t) + .16 * sin(TAU * 240.0 * t) + .04 * sin(TAU * 360.0 * t)
		pcm.encode_s16(frame * 2, roundi(value * 24500.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = pcm
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = RATE
	return stream
