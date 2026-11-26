extends Node3D
## A small local schedule for the existing Riverbank Park lookout.

const Avatar = preload("res://crew_avatar.gd")
const Park = preload("res://riverbank_park.gd")
const Calendar = preload("res://mowing_routes.gd")
const Idle = preload("res://character_idle.gd")

# Each resident walks a separate piece of the lookout paving, away from the parking lanes.
# Points are in the park survey frame (station, depth).
const PROFILES := [
	{"id": "mara", "name": "Mara Chen", "weekday": [450, 720, 1010], "weekend": [545, 690, 940],
		"stops": [Vector2(27.5, 13.1), Vector2(30.0, 13.4), Vector2(32.0, 14.4)], "pace": 1.12, "outfit": Color("#81523d")},
	{"id": "eli", "name": "Eli Mercer", "weekday": [500, 750, 965], "weekend": [470, 805, 1050],
		"stops": [Vector2(34.5, 12.3), Vector2(37.1, 12.9), Vector2(39.4, 14.0)], "pace": 1.32, "outfit": Color("#665b77")},
	{"id": "nadia", "name": "Nadia Roy", "weekday": [570, 810, 1080], "weekend": [592, 755, 960],
		"stops": [Vector2(42.1, 12.3), Vector2(44.3, 13.2), Vector2(47.0, 13.9)], "pace": 1.02, "outfit": Color("#416f77")},
	{"id": "gus", "name": "Gus Bell", "weekday": [435, 675, 945], "weekend": [490, 745, 990],
		"stops": [Vector2(49.4, 12.7), Vector2(51.6, 13.3), Vector2(53.9, 13.8)], "pace": .92, "outfit": Color("#776a44")},
	{"id": "jo", "name": "Jo Baptiste", "weekday": [520, 785, 1130], "weekend": [640, 850, 1070],
		"stops": [Vector2(56.4, 12.6), Vector2(59.0, 13.0), Vector2(62.0, 14.0)], "pace": 1.22, "outfit": Color("#684447")},
]
const SIMULATION_RADIUS := 85.0

class Resident:
	var avatar: Avatar
	var idle := Idle.new()
	var stops: Array[Vector3] = []
	var feet := Vector3.ZERO
	var heading := 0.0
	var stop := 0
	var destination := 0
	var next_stop := -1
	var was_moving := false

var residents: Array[Resident] = []
var park_center: Vector3
var sample_ground: Callable
var clearance := PhysicsShapeQueryParameters3D.new()
var schedule_minute := -1


func setup(ground_height: Callable) -> void:
	sample_ground = ground_height
	park_center = feet_at(Park.parking_point(45.0, 13.0))
	var capsule := CapsuleShape3D.new()
	capsule.radius = .31
	capsule.height = 1.45
	clearance.shape = capsule
	clearance.collision_mask = 1
	for profile in PROFILES:
		var resident := Resident.new()
		for point: Vector2 in profile.stops:
			resident.stops.append(feet_at(Park.parking_point(point.x, point.y)))
		residents.append(resident)


func feet_at(point: Vector2) -> Vector3:
	# The lookout paving is an overlay over terrain, with no separate floor collider.
	return Vector3(point.x, float(sample_ground.call(point.x, point.y)) + .06, point.y)


static func scheduled_stop(profile: Dictionary, work_minutes: float) -> int:
	var day := floori(work_minutes / Calendar.MINUTES_PER_DAY)
	var minute := fposmod(work_minutes, Calendar.MINUTES_PER_DAY)
	var times: Array = profile.weekend if posmod(day, Calendar.DAYS.size()) >= 5 else profile.weekday
	# Stable day-to-day variation after saving, loading or advancing the clock.
	for index in range(times.size() - 1, -1, -1):
		var offset := posmod(hash([profile.id, day, index]), 29) - 14
		if minute >= times[index] + offset:
			return [1, 2, 0][index]
	return 0


func tick(delta: float, work_minutes: float, player_at: Vector3, clock: float) -> void:
	var nearby := player_at.distance_squared_to(park_center) <= SIMULATION_RADIUS * SIMULATION_RADIUS
	var minute := floori(work_minutes)
	var update_schedule := minute != schedule_minute
	schedule_minute = minute
	for index in residents.size():
		var resident := residents[index]
		var profile: Dictionary = PROFILES[index]
		var first_pose := resident.avatar == null
		if update_schedule or first_pose:
			resident.destination = scheduled_stop(profile, work_minutes)
		if first_pose:
			resident.stop = resident.destination
			resident.feet = resident.stops[resident.stop]
			resident.avatar = Avatar.new()
			resident.avatar.name = profile.id
			add_child(resident.avatar)
			resident.avatar.setup(profile.name, index, profile.outfit)
		var movement := walk(resident, profile.pace * delta) / delta
		var moving := movement.length_squared() > .001
		if not moving and resident.stop == resident.destination and resident.next_stop < 0:
			var view := Park.TOWARD_WATER.rotated((index - 2.0) * .24 + (resident.stop - 1.0) * .3)
			resident.heading = atan2(-view.x, -view.y)
		if nearby or moving or resident.was_moving or first_pose:
			resident.idle.tick(delta, not moving, false)
			resident.avatar.apply_sample({"at": resident.feet, "yaw": resident.heading, "onboard": false,
				"animation": {"move": movement, "idle": resident.idle.packet()}}, null, delta, clock, player_at)
		resident.was_moving = moving
		resident.avatar.label.visible = nearby and player_at.distance_squared_to(resident.feet) < 25.0


func walk(resident: Resident, stride: float) -> Vector3:
	if resident.next_stop < 0:
		if resident.stop == resident.destination:
			return Vector3.ZERO
		resident.next_stop = resident.stop + (1 if resident.destination > resident.stop else -1)
	var target := resident.stops[resident.next_stop]
	var from := Vector2(resident.feet.x, resident.feet.z)
	var point := from.move_toward(Vector2(target.x, target.z), stride)
	var next := feet_at(point)
	var motion := next - resident.feet
	clearance.transform.origin = resident.feet + Vector3.UP * .85
	clearance.motion = motion
	var space := get_world_3d().direct_space_state
	var travel := space.cast_motion(clearance)
	# cast_motion ignores initial overlaps. Check the destination as well.
	clearance.transform.origin += motion
	clearance.motion = Vector3.ZERO
	if travel[0] < 1.0 or not space.intersect_shape(clearance, 1).is_empty():
		return Vector3.ZERO
	if point == Vector2(target.x, target.z):
		resident.stop = resident.next_stop
		resident.next_stop = -1
	if motion.length_squared() > .000001:
		resident.heading = atan2(-motion.x, -motion.z)
	resident.feet = next
	return motion
