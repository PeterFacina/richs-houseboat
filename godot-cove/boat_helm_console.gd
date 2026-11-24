extends Node3D

const Kit = preload("res://scenery.gd")
const Tools = preload("res://crew_tools.gd")

var trim := Kit.paint(Color("#253332"), .64)
var metal := Kit.paint(Color("#b5bfbc"), .38, .49)
var accent := Kit.paint(Color("#b79355"), .43, .38)
var grip := Kit.paint(Color("#242b29"), .47)
var screen := Kit.paint(Color("#152622"), .58)
var speed_readout: Label3D
var throttle_readout: Label3D
var ignition_key: Node3D
var throttle_lever: Node3D


func build(boat: Node3D, lever_pose: Transform3D) -> void:
	Kit.box_at(self, Vector3.ZERO, Vector3(.638, .260, .049), trim)
	Kit.box_at(self, Vector3(-.036, .039, .027), Vector3(.384, .156, .014), metal)
	Kit.box_at(self, Vector3(-.036, .039, .037), Vector3(.366, .138, .010), screen)
	speed_readout = face("", Vector3(-.036, .063, .044), .00215, Color("#e7f4dc"))
	throttle_readout = face("", Vector3(-.036, .002, .044), .0012, Color("#c1d4bc"))
	face("KEY", Vector3(.225, -.085, .029), .0009, Color("#eee3ce"))
	ignition_key = build_ignition_key(self, Vector3(.225, -.038, .057))

	var quadrant := Node3D.new()
	quadrant.name = "ThrottleQuadrant"
	boat.add_child(quadrant)
	quadrant.transform = lever_pose
	Kit.box_at(quadrant, Vector3(.050, -.032, .008), Vector3(.127, .113, .249), trim)
	throttle_lever = Node3D.new()
	throttle_lever.name = "ThrottleLever"
	quadrant.add_child(throttle_lever)
	Tools.tube(throttle_lever, Vector3.ZERO, Vector3(0, .19, 0), .016, .014, metal)
	Kit.box_at(throttle_lever, Vector3(0, .192, 0), Vector3(.080, .043, .054), grip)
	Kit.box_at(throttle_lever, Vector3(-.017, .216, 0), Vector3(.022, .009, .025), accent)


static func build_ignition_key(panel: Node3D, at: Vector3) -> Node3D:
	var bezel := Kit.paint(Color("#b5bfbc"), .38, .49)
	var brass := Kit.paint(Color("#b79355"), .43, .38)
	var handle := Kit.paint(Color("#242b29"), .47)
	Tools.tube(panel, at - Vector3(0, 0, .032), at - Vector3(0, 0, .010), .034, .032, bezel)
	var key := Node3D.new()
	key.name = "IgnitionKey"
	panel.add_child(key)
	key.position = at
	Kit.box_at(key, Vector3(0, .006, .004), Vector3(.013, .016, .037), brass)
	Kit.box_at(key, Vector3(0, .016, .026), Vector3(.055, .032, .019), handle)
	Kit.box_at(key, Vector3(0, .026, .036), Vector3(.041, .007, .005), brass)
	return key


static func aims_at_key(key: Node3D, origin: Vector3, forward: Vector3) -> bool:
	var offset := key.global_position - origin
	var distance := offset.dot(forward)
	return distance > 0.0 and distance < 1.8 and (offset - forward * distance).length_squared() < .0025


func face(value: String, at: Vector3, pixel: float, ink: Color) -> Label3D:
	var label := Label3D.new()
	label.text = value
	label.position = at
	label.pixel_size = pixel
	label.font_size = 36
	label.outline_size = 0
	label.modulate = ink
	add_child(label)
	return label


func update_instruments(speed: float, throttle: float) -> void:
	throttle_lever.rotation.x = -throttle * 1.02
	var speed_text := "%.1f km/h" % absf(speed * 3.6)
	var throttle_text := "%s%d%% THROTTLE" % ["REV " if throttle < -.005 else "", roundi(absf(throttle) * 100.0)]
	if speed_readout.text != speed_text:
		speed_readout.text = speed_text
	if throttle_readout.text != throttle_text:
		throttle_readout.text = throttle_text
