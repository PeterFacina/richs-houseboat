extends RefCounted

# Feet positions are queried with a slightly inset capsule, so touching a floor
# is allowed while walls/ceilings must leave room for the entire character.
var game: Node3D
var capsule := CapsuleShape3D.new()
var last_clear := Vector3.INF
var last_boat_local := Vector3.INF
var sample_time := 0.0
var embedded_time := 0.0
var cooldown := 0.0


func setup(scene: Node3D) -> void:
	game = scene
	capsule.radius = .232
	capsule.height = 1.63
	game.player.safe_margin = .012
	game.player.max_slides = 8
	game.player.slide_on_ceiling = false
	game.player.floor_stop_on_slope = true


func clear_at(feet: Vector3) -> bool:
	if not feet.is_finite():
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * .855)
	query.collision_mask = 1
	query.exclude = [game.player.get_rid()]
	query.margin = .002
	return game.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func ground_at(nearby: Vector3) -> Vector3:
	var ray := PhysicsRayQueryParameters3D.create(nearby + Vector3.UP * 2.0,
		nearby + Vector3.DOWN * 4.0, 1, [game.player.get_rid()])
	var hit := game.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or Vector3(hit.normal).dot(Vector3.UP) < .65:
		return Vector3.INF
	var feet: Vector3 = hit.position + Vector3.UP * .045
	return feet if clear_at(feet) else Vector3.INF


func find_near(center: Vector3, radius := 4.0) -> Vector3:
	for ring in 9:
		for direction in (1 if ring == 0 else 16):
			var angle := direction * TAU / 16.0
			var feet := ground_at(center + Vector3(sin(angle), 0, cos(angle)) * radius * ring / 8.0)
			if feet.is_finite():
				return feet
	return Vector3.INF


func tick(delta: float) -> void:
	cooldown = maxf(0, cooldown - delta)
	if game.flying or game.swimming or game.driving or game.mower.rider != null \
			or game.marina_cars.active >= 0 or game.campaign.dive.active:
		embedded_time = 0
		return
	var at: Vector3 = game.player.global_position
	if not at.is_finite():
		rescue()
		return
	if not clear_at(at):
		embedded_time += delta
		if embedded_time > .4 and cooldown <= 0:
			# Resolve small penetrations locally before returning to a checkpoint.
			var escape := find_near(at, 1.4)
			if escape.is_finite():
				move_to(escape)
			else:
				rescue()
		return
	embedded_time = 0
	sample_time += delta
	if sample_time >= .3 and game.player.is_on_floor():
		sample_time = 0
		if game.aboard():
			last_boat_local = game.vessel.to_local(at)
		else:
			last_clear = at


func move_to(feet: Vector3) -> void:
	game.player.global_position = feet
	game.player.velocity = Vector3.ZERO
	game.player.reset_physics_interpolation()
	embedded_time = 0
	cooldown = 1.0


func rescue() -> bool:
	var at: Vector3 = game.player.global_position
	var destination := Vector3.INF
	if game.aboard() and last_boat_local.is_finite():
		var boat_feet: Vector3 = game.vessel.to_global(last_boat_local)
		if clear_at(boat_feet):
			destination = boat_feet
	if not destination.is_finite() and last_clear.is_finite() and at.is_finite() \
			and at.distance_to(last_clear) < 80 and clear_at(last_clear):
		destination = last_clear
	if not destination.is_finite() and at.is_finite():
		destination = find_near(at, 8.0)
	if not destination.is_finite():
		for site: Dictionary in game.campaign.landings.sites:
			var safe := find_near(site.stand, 4.0)
			if safe.is_finite():
				destination = safe
				break
	if not destination.is_finite():
		game.notify_angling("No clear recovery spot found. Try a chart waypoint.", 4)
		return false
	move_to(destination)
	game.notify_angling("Moved you to clear ground. Your inventory is safe.", 4)
	return true
