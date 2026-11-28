extends RefCounted

const RIVER_WAVES := [
	Vector4(.178, .123, 1.46, 0.0),
	Vector4(-.126, .316, 1.82, 1.4),
	Vector4(.491, -.217, 2.29, 2.6),
	Vector4(.397, .662, 2.75, 0.0),
	Vector4(-.798, .762, 3.29, .9),
	Vector4(.735, .475, 2.85, 2.1),
]


static func height(x: float, z: float, clock: float) -> float:
	return (
		sin(0.31 * x + 0.43 * z - 1.45 * clock) * 0.15
		+ sin(-0.64 * x + 0.25 * z - 1.92 * clock) * 0.071
		+ sin(0.85 * x - 0.54 * z - 2.4 * clock) * 0.033
	)


static func river_amplitudes(wind: float) -> PackedFloat32Array:
	return PackedFloat32Array([
		lerpf(.118, .172, wind), lerpf(.066, .089, wind), lerpf(.031, .054, wind),
		lerpf(.012, .034, wind), lerpf(.006, .018, wind), .082 * wind * wind,
	])


# The same coefficients are uploaded to the mapped water shader.
static func river_height(point: Vector2, clock: float, amplitudes: PackedFloat32Array) -> float:
	var total := 0.0
	for i in RIVER_WAVES.size():
		var wave: Vector4 = RIVER_WAVES[i]
		total += amplitudes[i] * sin(point.x * wave.x + point.y * wave.y - wave.z * clock + wave.w)
	return total


static func shore_exposure(clearance: float) -> float:
	return lerpf(.24, 1.0, smoothstep(0.0, 57.0, clearance))
