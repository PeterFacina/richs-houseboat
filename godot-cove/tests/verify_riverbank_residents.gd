extends SceneTree

const Residents = preload("res://riverbank_residents.gd")
const Calendar = preload("res://mowing_routes.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, label: String) -> void:
	print("CHECK ", label, ": ", condition)
	if not condition:
		failures += 1


func run() -> void:
	if not "houseboat-142" in OS.get_user_data_dir().to_lower():
		push_error("Run with an isolated APPDATA directory containing houseboat-142.")
		quit(2)
		return

	var game = load("res://game_world.tscn").instantiate()
	game.multiplayer_trip = "--crew" in OS.get_cmdline_user_args()
	root.add_child(game)
	await physics_frame
	await physics_frame
	var residents: Residents = game.get_node_or_null("RiverbankResidents")
	if game.multiplayer_trip:
		check(residents == null, "crew world leaves resident simulation disabled")
		game.queue_free()
		await process_frame
		quit(1 if failures > 0 else 0)
		return
	check(residents != null, "local world owns Riverbank Park residents")
	if residents == null:
		quit(1)
		return
	check(residents.get_child_count() == 5, "normal solo physics tick creates five avatars")
	game.set_physics_process(false)
	game.set_process(false)

	var origin: Vector3 = residents.park_center
	residents.tick(.1, 0, origin, 0)
	check(residents.residents.size() == 5, "five resident profiles")
	var profiles := Residents.PROFILES
	var monday: Array[int] = []
	var saturday: Array[int] = []
	for profile in profiles:
		monday.append(Residents.scheduled_stop(profile, 500))
		saturday.append(Residents.scheduled_stop(profile, 500 + 5 * Calendar.MINUTES_PER_DAY))
	check(monday != saturday and monday.has(0) and monday.has(1), "individual weekday and weekend schedules")
	var start_times := {}
	for day in 5:
		for minute in range(400, 500):
			if Residents.scheduled_stop(profiles[0], day * Calendar.MINUTES_PER_DAY + minute) == 1:
				start_times[minute] = true
				break
	check(start_times.size() > 1, "daily variation is stable by in-game day")
	for visit_minute in [650, 910, 1200]:
		for step in 200:
			residents.tick(.1, visit_minute, origin, float(step) * .1)
		for idx in profiles.size():
			var resident := residents.residents[idx]
			var expected := Residents.scheduled_stop(profiles[idx], visit_minute)
			check(resident.stop == expected and resident.feet.distance_to(resident.stops[expected]) < .05,
				"%s reaches stop %d on real park collision" % [profiles[idx].name, expected])

	var walker := residents.residents[0]
	var start := walker.feet
	var goal := walker.stops[1]
	var barrier := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(.8, 1.6, .8)
	shape.shape = box
	barrier.position = start.lerp(goal, .60) + Vector3.UP * .80
	barrier.add_child(shape)
	game.add_child(barrier)
	await physics_frame
	await physics_frame
	for step in 60:
		residents.tick(.1, 650, origin, float(step) * .1)
	check(walker.stop == 0 and walker.feet.distance_to(start) > .05 and walker.feet.distance_to(goal) > .6,
		"resident stops before a route obstruction")
	var paused_at := walker.feet
	for step in 20:
		residents.tick(.1, 650, origin, float(step) * .1)
	check(walker.feet == paused_at, "resident holds position while the route is obstructed")
	barrier.queue_free()
	await physics_frame
	await physics_frame
	for step in 60:
		residents.tick(.1, 650, origin, float(step) * .1)
	check(walker.stop == 1 and walker.feet.distance_to(goal) < .05, "resident resumes after obstruction clears")
	check(is_instance_valid(game.campaign.rich) and is_instance_valid(game.shannon_job),
		"Big Rich and Shannon Lapping still initialize")
	game.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
