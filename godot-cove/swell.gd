extends RefCounted


static func height(x: float, z: float, clock: float) -> float:
	return (
		sin(0.31 * x + 0.43 * z - 1.45 * clock) * 0.15
		+ sin(-0.64 * x + 0.25 * z - 1.92 * clock) * 0.071
		+ sin(0.85 * x - 0.54 * z - 2.4 * clock) * 0.033
	)


# Keep the five wave components in sync with river_wave in water.gdshader.
static func river_height(x: float, z: float, clock: float) -> float:
	return (
		.143 * sin(.178 * x + .123 * z - 1.46 * clock)
		+ .091 * sin(-.126 * x + .316 * z - 1.82 * clock + 1.4)
		+ .055 * sin(.491 * x - .217 * z - 2.29 * clock + 2.6)
		+ .033 * sin(.397 * x + .662 * z - 2.75 * clock)
		+ .016 * sin(-.798 * x + .762 * z - 3.29 * clock + .9)
	)
