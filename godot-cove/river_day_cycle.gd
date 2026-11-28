extends RefCounted

const Routes = preload("res://mowing_routes.gd")
const DAY_MINUTES := float(Routes.MINUTES_PER_DAY)
const DAWN := 270.0
const SUNRISE := 360.0
const MORNING := 480.0
const MIDDAY := 660.0
const AFTERNOON := 900.0
const GOLDEN_HOUR := 1020.0
const SUNSET := 1140.0
const TWILIGHT := 1230.0
const NIGHT := 1290.0
const LIGHTS_OFF := 375.0
const LIGHTS_ON := 1200.0
const UPDATE_MINUTES := .16

# Minute, zenith, horizon, warm glow, direct light, ambient, fog, and
# sun/ambient/exposure/photograph weights. Wrap the night to the next dawn.
const PHASES := [
	[DAWN, Color("#162444"), Color("#343f65"), Color("#71476c"), Color("#b48da2"), Color("#879fc8"), Color("#424b64"), Vector4(0, .11, 1.13, 0)],
	[SUNRISE, Color("#49658b"), Color("#c18a91"), Color("#ffb06f"), Color("#ffc68f"), Color("#b2bfdb"), Color("#9d8a9c"), Vector4(0, .22, 1.09, .03)],
	[MORNING, Color("#548eb7"), Color("#c1cbd0"), Color("#f9dbb9"), Color("#fff2da"), Color("#c7d6e5"), Color("#b7bdb4"), Vector4(.73, .32, 1.04, .45)],
	[MIDDAY, Color("#4086c0"), Color("#b8d1dd"), Color("#f9e9d2"), Color("#fff6ed"), Color("#d1dce0"), Color("#b7bdb4"), Vector4(.88, .34, 1.02, .65)],
	[AFTERNOON, Color("#558bb6"), Color("#c2ccd0"), Color("#f8d5ac"), Color("#fff0d7"), Color("#cbd6e2"), Color("#b7bdb4"), Vector4(.84, .32, 1.04, .50)],
	[GOLDEN_HOUR, Color("#52799f"), Color("#cdb3a5"), Color("#ffc27f"), Color("#ffd5aa"), Color("#b9c7dd"), Color("#ad9b94"), Vector4(.65, .29, 1.06, .34)],
	[SUNSET, Color("#514b82"), Color("#aa728d"), Color("#fc8753"), Color("#ffbc88"), Color("#a8b3d3"), Color("#84788f"), Vector4(.41, .25, 1.08, .08)],
	[TWILIGHT, Color("#212d54"), Color("#51486f"), Color("#c37075"), Color("#e99179"), Color("#94a6cb"), Color("#585670"), Vector4(0, .16, 1.11, 0)],
	[NIGHT, Color("#0b142c"), Color("#263452"), Color("#575277"), Color("#b4c9ff"), Color("#8b9ec5"), Color("#303d54"), Vector4(0, .11, 1.13, 0)],
	[DAWN + DAY_MINUTES, Color("#162444"), Color("#343f65"), Color("#71476c"), Color("#b48da2"), Color("#879fc8"), Color("#424b64"), Vector4(0, .11, 1.13, 0)],
]


static func sample(work_minutes: float) -> Dictionary:
	var minute := fposmod(work_minutes - DAWN, DAY_MINUTES) + DAWN
	var phase := 0
	while minute >= float(PHASES[phase + 1][0]):
		phase += 1
	var from: Array = PHASES[phase]
	var to: Array = PHASES[phase + 1]
	var blend := smoothstep(float(from[0]), float(to[0]), minute)
	var weights: Vector4 = from[7].lerp(to[7], blend)
	var orbit := fposmod(minute - SUNRISE, DAY_MINUTES)
	var daylight := TWILIGHT - SUNRISE
	var angle := PI * orbit / daylight if orbit <= daylight \
		else PI + PI * (orbit - daylight) / (DAY_MINUTES - daylight)
	var sun := Vector3(cos(angle), .90 * sin(angle), .436 * sin(angle)).normalized()
	var night := (1.0 - smoothstep(DAWN, SUNRISE, minute)) + smoothstep(TWILIGHT, NIGHT, minute)
	var lights := (1.0 - smoothstep(DAWN, LIGHTS_OFF, minute)) + smoothstep(LIGHTS_ON, NIGHT, minute)
	return {
		"sun": sun, "night": night, "lights": lights, "direct": from[4].lerp(to[4], blend),
		"zenith": from[1].lerp(to[1], blend), "horizon": from[2].lerp(to[2], blend),
		"glow": from[3].lerp(to[3], blend), "ambient": from[5].lerp(to[5], blend),
		"fog": from[6].lerp(to[6], blend), "fog_density": lerpf(.00010, .00022, night),
		"sun_energy": weights.x, "moon_energy": .17 * night, "ambient_energy": weights.y,
		"exposure": weights.z, "photo": weights.w,
	}
