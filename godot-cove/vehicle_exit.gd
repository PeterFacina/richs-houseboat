extends RefCounted

const ANGLES := [90.0, -90.0, 135.0, -135.0, 180.0, 45.0, -45.0, 0.0]
const LIFT := 1.35


static func find(vehicle: PhysicsBody3D, player: CharacterBody3D, half: Vector2,
		heading: float, mower := false) -> Vector3:
	var space := vehicle.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = .34
	capsule.height = 1.90
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	var excluded: Array[RID] = [vehicle.get_rid(), player.get_rid()]
	var origin := vehicle.global_position
	var gaps := [1.15, 1.65, 2.30, 3.0] if mower else [.85, 1.35, 2.05, 2.90]
	var forward := Vector3.FORWARD.rotated(Vector3.UP, heading)
	for gap: float in gaps:
		for angle: float in ANGLES:
			var offset := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(angle))
			var edge := minf(half.x / maxf(absf(offset.x), .001), half.y / maxf(absf(offset.z), .001))
			var direction := offset.rotated(Vector3.UP, heading)
			var candidate := origin + direction * (edge + gap)
			var place := ground_at(space, candidate, excluded)
			if not place.is_finite() or not capsule_clear(space, query, place):
				continue
			# Do not put the player on the other side of a fence or wall.
			var crossing := PhysicsRayQueryParameters3D.create(origin + Vector3.UP * .91,
				place + Vector3.UP * .88, 1, excluded)
			if not space.intersect_ray(crossing).is_empty():
				continue
			for walk_out: Vector3 in [direction, direction.rotated(Vector3.UP, .85),
					direction.rotated(Vector3.UP, -.85), forward, -forward]:
				if has_runway(space, query, place, walk_out, excluded):
					return place
	return Vector3.INF


static func ground_at(space: PhysicsDirectSpaceState3D, near: Vector3, excluded: Array[RID]) -> Vector3:
	var ray := PhysicsRayQueryParameters3D.create(near + Vector3.UP * 1.30, near - Vector3.UP * 1.70, 1, excluded)
	var hit := space.intersect_ray(ray)
	if hit.is_empty() or hit.normal.y < .63 or hit.position.y < .10 or hit.collider is CharacterBody3D \
			or hit.collider is AnimatableBody3D:
		return Vector3.INF
	return hit.position + Vector3.UP * .105


static func capsule_clear(space: PhysicsDirectSpaceState3D, query: PhysicsShapeQueryParameters3D, place: Vector3) -> bool:
	query.transform = Transform3D(Basis.IDENTITY, place + Vector3.UP * .95)
	return space.intersect_shape(query, 1).is_empty()


static func has_runway(space: PhysicsDirectSpaceState3D, query: PhysicsShapeQueryParameters3D,
		place: Vector3, direction: Vector3, excluded: Array[RID]) -> bool:
	var previous := place
	for step in range(1, 5):
		var next := ground_at(space, place + direction * (.37 * step), excluded)
		if not next.is_finite() or absf(next.y - previous.y) > .32 or not capsule_clear(space, query, next):
			return false
		previous = next
	return true
