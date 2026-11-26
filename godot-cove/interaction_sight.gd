extends RefCounted


static func clear(eye: Camera3D, point: Vector3, target: CollisionObject3D = null) -> bool:
	var exclude: Array[RID] = []
	if eye.get_parent() is CollisionObject3D:
		exclude.append(eye.get_parent().get_rid())
	var ray := PhysicsRayQueryParameters3D.create(eye.global_position, point, 1, exclude)
	var hit := eye.get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or hit.collider == target or hit.position.distance_squared_to(point) < .018
