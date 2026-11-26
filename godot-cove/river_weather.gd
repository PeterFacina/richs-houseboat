extends RefCounted

const NAMES := ["Clear", "Partly cloudy", "Overcast", "Light rain", "Heavy rain",
	"Thunderstorm", "Light fog", "Dense fog", "Windy"]
enum { CLEAR, PARTLY, OVERCAST, RAIN, HEAVY, STORM, FOG, DENSE_FOG, WINDY }
# Cloud cover, precipitation, fog density weight, wind speed weight.
const CONDITIONS := [
	Vector4(.05, 0, 0, .12), Vector4(.44, 0, 0, .23), Vector4(.91, 0, .07, .32),
	Vector4(.94, .38, .13, .33), Vector4(.98, .76, .23, .62), Vector4(1, 1, .29, .94),
	Vector4(.32, 0, .42, .13), Vector4(.62, 0, 1, .10), Vector4(.53, 0, .02, 1),
]
const NEXT := [[PARTLY, WINDY, FOG], [CLEAR, OVERCAST, WINDY, FOG],
	[PARTLY, RAIN, WINDY], [OVERCAST, HEAVY, FOG], [RAIN, STORM, OVERCAST],
	[HEAVY, RAIN], [CLEAR, PARTLY, DENSE_FOG], [FOG, OVERCAST], [PARTLY, OVERCAST]]

var random := RandomNumberGenerator.new()
var weights := PackedFloat32Array([4, 5, 4, 4, 2, 1, 3, 1, 2])
var duration_ranges: Array[Vector2] = [Vector2(140, 260), Vector2(95, 210), Vector2(80, 160),
	Vector2(65, 145), Vector2(50, 105), Vector2(50, 100), Vector2(65, 125), Vector2(65, 105), Vector2(90, 180)]
var transition_minutes := 24.0
var gameplay_strength := 1.0


func _init() -> void:
	random.randomize()


func ensure(record: Dictionary, minute: float) -> void:
	if record.has_all(["kind", "from", "start", "end", "advance", "wet", "lightning", "strike_at", "strength", "wind"]):
		var source: Variant = record["from"]
		if source is Array and source.size() == 4:
			return
	record.merge({"kind": CLEAR, "from": [CONDITIONS[CLEAR].x, 0.0, 0.0, CONDITIONS[CLEAR].w],
		"start": minute, "end": minute, "advance": minute + random.randf_range(duration_ranges[CLEAR].x, duration_ranges[CLEAR].y),
		"wet": 0.0, "lightning": 0, "strike_at": minute + 18.0, "strength": 1.0, "wind": -1.0}, true)


func sample(record: Dictionary, minute: float) -> Vector4:
	if record.is_empty():
		return CONDITIONS[CLEAR]
	var kind := clampi(int(record.kind), CLEAR, WINDY)
	var target: Vector4 = CONDITIONS[kind]
	var strength := clampf(float(record.strength), 0.0, 1.5)
	target = Vector4(clampf(target.x * strength, 0, 1), clampf(target.y * strength, 0, 1),
		clampf(target.z * strength, 0, 1), target.w)
	if float(record.wind) >= 0.0:
		target.w = clampf(float(record.wind), 0.0, 1.0)
	var source: Array = record["from"]
	var initial := Vector4(source[0], source[1], source[2], source[3])
	var blend := smoothstep(0, 1, (minute - float(record.start)) / maxf(.001, float(record.end) - float(record.start)))
	return initial.lerp(target, blend)


func force(record: Dictionary, kind: int, minute: float, strength := 1.0, wind := -1.0) -> void:
	ensure(record, minute)
	kind = clampi(kind, CLEAR, WINDY)
	var initial := sample(record, minute)
	var span := maxf(0.0, transition_minutes)
	var duration := duration_ranges[kind]
	record.merge({"kind": kind, "from": [initial.x, initial.y, initial.z, initial.w],
		"start": minute, "end": minute + span, "advance": minute + span + random.randf_range(duration.x, duration.y),
		"strike_at": minute + span + random.randf_range(7.0, 15.0), "strength": strength, "wind": wind}, true)


func strike(record: Dictionary, minute: float, near: Vector3) -> void:
	ensure(record, minute)
	var angle := random.randf_range(0.0, TAU)
	var distance := random.randf_range(28.0, 175.0)
	record.lightning = int(record.lightning) + 1
	record.strike_point = [near.x + cos(angle) * distance, near.y + 16.0, near.z + sin(angle) * distance]
	record.flash_minute = minute


func advance(record: Dictionary, minute: float, minutes_elapsed: float, near := Vector3.ZERO) -> void:
	ensure(record, minute)
	var current := sample(record, minute)
	var wet := float(record.wet)
	var rate := current.y * .020 if current.y >= .05 else .0035 * (1.0 + current.w - .5 * current.x)
	record.wet = move_toward(wet, 1.0 if current.y >= .05 else 0.0, minutes_elapsed * rate)
	if int(record.kind) == STORM and current.y > .68 and minute >= float(record.strike_at):
		strike(record, minute, near)
		record.strike_at = minute + random.randf_range(8.0, 24.0)
	if minute < float(record.advance):
		return
	var options: Array = NEXT[clampi(int(record.kind), CLEAR, WINDY)]
	var odds := PackedFloat32Array()
	var hour := fposmod(minute / 60.0, 24.0)
	for kind: int in options:
		var morning := 1.0 - smoothstep(6, 9, absf(hour - 5.0))
		odds.append(maxf(.0001, weights[kind]) * (lerpf(.22, 2.2, morning) if kind in [FOG, DENSE_FOG] else 1.0))
	force(record, options[random.rand_weighted(odds)], minute)
