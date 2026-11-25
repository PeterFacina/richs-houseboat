extends StaticBody3D

const Kit = preload("res://scenery.gd")
const Tools = preload("res://crew_tools.gd")
const Hand = preload("res://river_hand_instance.gd")
const FLOW = preload("res://deep_river/marina_fuel/flow.wav")
const CLICK = preload("res://deep_river/marina_fuel/click.wav")
const DING = preload("res://deep_river/marina_fuel/ding.wav")
const PRICE_CENTS := 180
const HOSE_REACH := 12.0
const SEGMENTS := 32
const RACK := Vector3(.42, .95, .29)
const REEL := Vector3(-.59, .39, .24)
const SPOUT := Vector3(0, -.029, -.247)
const COUPLER := Vector3(0, -.122, .092)
const GRIP := Vector3(.23, -.22, -.59)

var nozzle: Node3D
var handle_trigger: MeshInstance3D
var local_hand: Hand
var spray: CPUParticles3D
var hose: MultiMesh
var meter: Label3D
var flow_sound: AudioStreamPlayer3D
var nozzle_sound: AudioStreamPlayer3D
var meter_sound: AudioStreamPlayer3D
var stop_sound: AudioStreamPlayer3D
var heard_end := 0
var heard_step := 0
var hose_tip := Vector3.INF


func build(number: int) -> void:
	var cream := Kit.paint(Color("#ddd5bc"), .51, .16)
	var red := Kit.paint(Color("#993829"), .47, .16)
	var steel := Kit.paint(Color("#a7a99d"), .39, .55)
	var black := Kit.paint(Color("#222b29"), .76)
	Kit.box_at(self, Vector3(0, .055, 0), Vector3(.78, .11, .61), black)
	Kit.box_at(self, Vector3(0, .685, 0), Vector3(.64, 1.36, .50), red)
	Kit.collider(self, Vector3(0, .693, 0), Vector3(.65, 1.385, .51))
	Kit.box_at(self, Vector3(0, 1.139, .249), Vector3(.618, .413, .025), cream)
	Kit.box_at(self, Vector3(0, 1.113, .266), Vector3(.491, .187, .015), black)
	Kit.box_at(self, Vector3(0, .396, .253), Vector3(.51, .542, .012), cream)
	Kit.box_at(self, Vector3(0, 1.374, 0), Vector3(.70, .039, .538), steel)
	Kit.box_at(self, RACK - Vector3(.056, .06, .037), Vector3(.11, .23, .08), black)
	face("PUMP %d" % number, Vector3(0, 1.279, .274), .0029, Color("#352921"))
	meter = face("", Vector3(0, 1.113, .278), .00185, Color("#d9f1b4"))
	face("$%.2f / L" % (PRICE_CENTS / 100.0), Vector3(0, .986, .272), .00155, Color("#352921"))
	face("UNLEADED", Vector3(0, .484, .263), .0021, Color("#893225"))
	face("DEEP RIVER", Vector3(0, .399, .263), .00155, Color("#352921"))
	for side: float in [-1.0, 1.0]:
		var foot := REEL + Vector3(side * .18, -.36, -.05)
		Kit.beam(self, foot, REEL + Vector3(side * .16, 0, -.05), .047, steel)
		var axle := REEL + Vector3(side * .13, 0, -.10)
		Tools.tube(self, axle, axle + Vector3.RIGHT * .032, .189, .189, red)
	Tools.tube(self, REEL + Vector3(-.13, 0, -.10), REEL + Vector3(.16, 0, -.10), .151, .151, black)
	for i in 6:
		var wrap := TorusMesh.new()
		wrap.inner_radius = .132
		wrap.outer_radius = .162
		wrap.rings = 16
		wrap.ring_segments = 8
		Kit.mesh_at(self, wrap, REEL + Vector3(-.108 + i * .043, 0, -.10), black).rotation.z = PI * .5
	build_hose(black)
	build_nozzle(red, black, steel)
	local_hand = Hand.new()
	nozzle.add_child(local_hand)
	local_hand.position = Vector3(0, -.058, .036)
	local_hand.rotation.z = -.8
	local_hand.initialize(1.0, true, "shaft", true)
	var loop := FLOW.duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_end = roundi(loop.get_length() * loop.mix_rate)
	flow_sound = sound_at(self, loop, Vector3(0, .94, .11), -13.0)
	nozzle_sound = sound_at(nozzle, loop, SPOUT, -20.0)
	meter_sound = sound_at(self, CLICK, Vector3(0, 1.04, .25), -7.0)
	stop_sound = sound_at(self, DING, Vector3(0, 1.05, .27), -6.0)
	render_station(rack_pose(), false, false, false, 0.0, 0, 0)


func face(value: String, at: Vector3, size: float, ink: Color) -> Label3D:
	var label := Label3D.new()
	label.text = value
	label.position = at
	label.font_size = 32
	label.pixel_size = size
	label.line_spacing = -2
	label.outline_size = 0
	label.modulate = ink
	add_child(label)
	return label


func build_hose(rubber: Material) -> void:
	var pipe := CylinderMesh.new()
	pipe.top_radius = .019
	pipe.bottom_radius = .019
	pipe.height = 1.0
	pipe.radial_segments = 7
	pipe.rings = 0
	pipe.material = rubber
	hose = MultiMesh.new()
	hose.transform_format = MultiMesh.TRANSFORM_3D
	hose.mesh = pipe
	hose.instance_count = SEGMENTS
	hose.custom_aabb = AABB(Vector3(-14, -3, -14), Vector3(28, 8, 28))
	var line := MultiMeshInstance3D.new()
	line.name = "FuelHose"
	line.multimesh = hose
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(line)


func build_nozzle(red: Material, black: Material, steel: Material) -> void:
	nozzle = Node3D.new()
	nozzle.name = "FuelNozzle"
	add_child(nozzle)
	Kit.box_at(nozzle, Vector3(0, -.01, -.02), Vector3(.080, .065, .176), red)
	Kit.beam(nozzle, Vector3(0, -.013, .057), COUPLER, .052, black)
	Kit.beam(nozzle, Vector3(0, -.039, -.100), Vector3(0, -.119, -.073), .014, black)
	Kit.beam(nozzle, Vector3(0, -.119, -.073), COUPLER, .014, black)
	handle_trigger = Kit.beam(nozzle, Vector3(0, -.060, -.070), Vector3(0, -.093, .039), .022, steel)
	Tools.tube(nozzle, Vector3(0, -.012, -.090), Vector3(0, -.014, -.180), .023, .020, steel)
	Tools.tube(nozzle, Vector3(0, -.014, -.178), SPOUT, .020, .016, steel)
	Tools.tube(nozzle, COUPLER - Vector3.UP * .019, COUPLER + Vector3.UP * .029, .027, .027, steel)
	spray = CPUParticles3D.new()
	spray.name = "LooseFuelSpray"
	spray.position = SPOUT
	spray.emitting = false
	spray.amount = 80
	spray.lifetime = .36
	spray.local_coords = false
	spray.direction = Vector3.FORWARD
	spray.spread = 8.0
	spray.initial_velocity_min = 4.7
	spray.initial_velocity_max = 7.2
	spray.gravity = Vector3.DOWN * 9.8
	spray.scale_amount_min = .42
	var drop := SphereMesh.new()
	drop.radius = .008
	drop.height = .026
	drop.radial_segments = 5
	drop.rings = 2
	var droplets := Kit.paint(Color(.88, .80, .63, .74), .23)
	droplets.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop.material = droplets
	spray.mesh = drop
	nozzle.add_child(spray)


func sound_at(parent: Node3D, recording: AudioStream, at: Vector3, volume: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = recording
	player.position = at
	player.volume_db = volume
	player.unit_size = 3.0
	player.max_distance = 19.0
	parent.add_child(player)
	return player


func rack_pose() -> Transform3D:
	return global_transform * Transform3D(Basis(Vector3.RIGHT, .79), RACK)


func carried_pose(eye_pose: Transform3D) -> Transform3D:
	return Transform3D(eye_pose.basis, eye_pose * GRIP)


func inserted_pose(port: Marker3D) -> Transform3D:
	var aim := port.global_basis * Basis(Vector3.RIGHT, -PI * .5)
	return Transform3D(aim, port.global_position - aim * SPOUT)


func render_station(pose: Transform3D, hand: bool, flowing: bool, spilling: bool,
		litres: float, cost_cents: int, end_count: int) -> void:
	nozzle.global_transform = pose
	local_hand.visible = hand
	spray.emitting = spilling
	if flowing != flow_sound.playing:
		if flowing:
			flow_sound.play()
			nozzle_sound.play()
		else:
			flow_sound.stop()
			nozzle_sound.stop()
	if end_count != heard_end:
		heard_end = end_count
		stop_sound.play()
	var step := floori(litres * 4.0)
	if step > heard_step:
		meter_sound.play()
	heard_step = step
	var display := "%05.2f L\n$%06.2f" % [litres, cost_cents / 100.0]
	if meter.text != display:
		meter.text = display
	handle_trigger.rotation.x = -.29 if flowing else .29
	var tip := to_local(pose * COUPLER)
	if tip.distance_squared_to(hose_tip) > .000016:
		hose_tip = tip
		draw_hose(tip)


func draw_hose(tip: Vector3) -> void:
	var distance := REEL.distance_to(tip)
	var sag := minf(.94, .24 + distance * .16) * (1.0 - smoothstep(8.0, HOSE_REACH, distance) * .65)
	var previous := REEL
	for index in SEGMENTS:
		var t := float(index + 1) / SEGMENTS
		var point := REEL.lerp(tip, t)
		point.y = maxf(minf(tip.y, .028), point.y - sin(t * PI) * sag)
		var span := point - previous
		if span.length_squared() > .0000001:
			var basis := Basis(Quaternion(Vector3.UP, span.normalized()))
			hose.set_instance_transform(index, Transform3D(basis.scaled_local(Vector3(1, span.length() + .009, 1)), (point + previous) * .5))
		previous = point
