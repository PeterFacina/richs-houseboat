extends RefCounted

const CAPACITY := 12
const LIFETIME := 4.5
const INTERVAL := .38
const REACH := 28.0

var packets: Array[Dictionary] = []
var previous_emission: Dictionary = {}
var origins := PackedVector4Array()
var shapes := PackedVector4Array()
var serial := 0


func _init() -> void:
	origins.resize(CAPACITY)
	shapes.resize(CAPACITY)


func emit(source: int, at: Vector2, behind: Vector2, current: Vector2, speed: float, wash: float,
		spread: float, peak_speed: float, clock: float) -> void:
	var previous: Vector2 = previous_emission.get(source, Vector2(-INF, 0.0))
	if clock - previous.x < INTERVAL or maxf(speed, wash) <= .10:
		return
	previous_emission[source] = Vector2(clock, speed)
	var size := smoothstep(.33, .56, spread)
	var motion := smoothstep(.48, peak_speed, speed)
	var acceleration := maxf(0.0, speed - previous.y) / maxf(INTERVAL, clock - previous.x)
	var launch := smoothstep(.2, 2.4, acceleration) * smoothstep(.4, 2.0, speed)
	var amplitude := minf(.073, (motion + launch * .22) * lerpf(.052, .073, size))
	if packets.size() == CAPACITY:
		packets.pop_front()
	serial += 1
	packets.append({"serial": serial, "source": source, "at": at, "behind": behind, "current": current,
		"clock": clock, "amplitude": amplitude, "spread": spread, "wash": wash})


func advance(clock: float) -> void:
	while not packets.is_empty() and clock - float(packets[0].clock) >= LIFETIME:
		packets.pop_front()
	for source: int in previous_emission.keys():
		var emission: Vector2 = previous_emission[source]
		if clock - emission.x >= LIFETIME:
			previous_emission.erase(source)


func upload(material: ShaderMaterial, center: Vector2, clock: float) -> void:
	var count := 0
	for packet: Dictionary in packets:
		var age := clampf(clock - float(packet.clock), 0.0, LIFETIME)
		var at: Vector2 = packet.at + packet.current * age
		if at.distance_squared_to(center) > (112.0 + REACH) * (112.0 + REACH):
			continue
		var behind: Vector2 = packet.behind
		origins[count] = Vector4(at.x, at.y, behind.x, behind.y)
		shapes[count] = Vector4(age, packet.amplitude, packet.spread, packet.wash)
		count += 1
	material.set_shader_parameter("wake_count", count)
	if count != 0:
		material.set_shader_parameter("wake_origins", origins)
		material.set_shader_parameter("wake_shapes", shapes)


func height(point: Vector2, clock: float, excluded: int) -> float:
	var total := 0.0
	for packet: Dictionary in packets:
		if packet.source == excluded:
			continue
		var age := clampf(clock - float(packet.clock), 0.0, LIFETIME)
		var shift: Vector2 = point - (packet.at + packet.current * age)
		if absf(shift.x) > REACH or absf(shift.y) > REACH:
			continue
		var behind: Vector2 = packet.behind
		var along := shift.dot(behind)
		var across := shift.dot(Vector2(behind.y, -behind.x))
		# Keep the packet envelope in sync with wake_packet() in water.gdshader.
		var length_weight := 1.0 - smoothstep(1.8, 6.0, absf(along - (2.7 + age * 2.65)))
		var edge := absf(across) - (1.0 + maxf(0.0, along) * float(packet.spread) + age * .84)
		var width_weight := 1.0 - smoothstep(.45, 3.1, absf(edge))
		var life := smoothstep(0.0, .32, age) * (1.0 - smoothstep(1.4, LIFETIME, age))
		total += sin(edge * 1.40) * float(packet.amplitude) * life * length_weight * width_weight
	return clampf(total, -.14, .14)


# Ship updates repeat the last two packets. A reliable join includes the whole live trail.
func encode(full: bool) -> PackedVector4Array:
	var data := PackedVector4Array()
	var first := 0 if full else maxi(0, packets.size() - 2)
	for i in range(first, packets.size()):
		var packet := packets[i]
		var at: Vector2 = packet.at
		var behind: Vector2 = packet.behind
		var current: Vector2 = packet.current
		data.append(Vector4(at.x, at.y, behind.x, behind.y))
		data.append(Vector4(current.x, current.y, packet.clock, packet.amplitude))
		data.append(Vector4(packet.spread, packet.wash, packet.serial, 0.0))
	return data


func receive(data: PackedVector4Array, clock: float) -> void:
	if data.size() > CAPACITY * 3 or data.size() % 3 != 0:
		return
	var changed := false
	for i in range(0, data.size(), 3):
		var origin := data[i]
		var motion := data[i + 1]
		var style := data[i + 2]
		var id := int(style.z)
		if clock - motion.z >= LIFETIME or packets.any(func(packet: Dictionary) -> bool: return packet.serial == id):
			continue
		packets.append({"serial": id, "source": -1, "at": Vector2(origin.x, origin.y),
			"behind": Vector2(origin.z, origin.w), "current": Vector2(motion.x, motion.y),
			"clock": motion.z, "amplitude": motion.w, "spread": style.x, "wash": style.y})
		changed = true
	if changed:
		packets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.serial < b.serial)
		while packets.size() > CAPACITY:
			packets.pop_front()
