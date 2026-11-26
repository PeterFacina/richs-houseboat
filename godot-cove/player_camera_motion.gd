extends RefCounted

var smoothing := .55
var bob_amount := .35
var phase := 0.0
var stride_weight := 0.0
var previous_feet := Vector3.INF
var previous_mode := ""
var transition := Vector3.ZERO
var rotation_error := Quaternion.IDENTITY
var last_view := Transform3D.IDENTITY
var source := Transform3D.IDENTITY
var presented := Transform3D.IDENTITY
var applied := false


func restore(eye: Camera3D) -> void:
	if applied and eye.transform.is_equal_approx(presented):
		eye.transform = source
	applied = false


func update(eye: Camera3D, player: CharacterBody3D, delta: float, mode: String,
		pace: float, sprint: float, crouch: float) -> void:
	restore(eye)
	var target := eye.global_transform
	var feet := player.global_position
	var gap := feet.distance_to(previous_feet)
	var reset := not previous_feet.is_finite() or gap > (9.0 if mode != previous_mode else 2.5) or not eye.current
	var factor := 1.0 - exp(-delta * lerpf(32.0, 14.0, smoothing))
	if reset:
		stride_weight = 0.0
		phase = 0.0
		transition = Vector3.ZERO
		rotation_error = Quaternion.IDENTITY
	elif mode != previous_mode and smoothing > 0.0:
		transition = (last_view.origin - target.origin).limit_length(1.35 * smoothing)
		rotation_error = target.basis.get_rotation_quaternion().inverse() * last_view.basis.get_rotation_quaternion()
		rotation_error = Quaternion.IDENTITY.slerp(rotation_error, .35 * smoothing)
	previous_feet = feet
	var same_mode := mode == previous_mode
	previous_mode = mode
	transition = transition.lerp(Vector3.ZERO, factor) if smoothing > 0.0 else Vector3.ZERO
	rotation_error = rotation_error.slerp(Quaternion.IDENTITY, factor) if smoothing > 0.0 else Quaternion.IDENTITY
	stride_weight = lerpf(stride_weight, smoothstep(.15, 2.8, pace) * (1.0 - crouch * .65), factor)
	phase = fposmod(phase + pace * delta * lerpf(3.4, 2.6, sprint), TAU)
	var bob := Vector3(sin(phase) * .012, -cos(phase * 2.0) * lerpf(.016, .026, sprint), 0)
	var offset := transition + target.basis * bob * stride_weight * bob_amount
	if not reset and same_mode and mode in ["foot", "deck"] and smoothing > 0.0:
		offset.y += clampf(last_view.origin.y - target.origin.y, -.115, .115) * exp(-delta * 36.0) * smoothing
	if offset.length_squared() > .000001:
		var clearance := PhysicsRayQueryParameters3D.create(target.origin, target.origin + offset, 1, [player.get_rid()])
		clearance.hit_from_inside = true
		var hit := eye.get_world_3d().direct_space_state.intersect_ray(clearance)
		if not hit.is_empty():
			offset = offset.normalized() * maxf(0.0, target.origin.distance_to(hit.position) - eye.near * 1.5)
	source = eye.transform
	var orientation := target.basis.get_rotation_quaternion() * rotation_error
	if not reset and same_mode and mode in ["foot", "deck", "swim", "helm"] and smoothing > 0.0:
		var last := last_view.basis.get_rotation_quaternion()
		var angle := orientation.angle_to(last)
		if angle > .0001:
			var lag := minf(.016 * smoothing / angle, exp(-delta * lerpf(115.0, 55.0, smoothing)))
			orientation = orientation.slerp(last, lag)
	eye.global_transform = Transform3D(Basis(orientation), target.origin + offset)
	presented = eye.transform
	applied = true
	last_view = eye.global_transform
