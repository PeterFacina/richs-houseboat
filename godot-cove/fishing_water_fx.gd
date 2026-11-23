extends Node3D

const Kit = preload("res://scenery.gd")
const AudioTexture = preload("res://audio_texture.gd")
const Swell = preload("res://swell.gd")
const RATE := 22050
const SOUNDS := {"cast": .38, "splash": .55, "bite": .19, "snap": .13, "reel": .6, "drag": .48,
	"door_latch": .20, "can_open": .29, "sip": .54, "lighter": .22, "bubble": .77, "draw": .59,
	"exhale": .73, "retch": .77, "spill": .24, "wipe": .23}

var bobber: Node3D
var line: MeshInstance3D
var line_mesh := ImmediateMesh.new()
var splash_mesh := ImmediateMesh.new()
var rings: Array[Dictionary] = []
var droplets: Array[Dictionary] = []
var samples := {}
var sound: AudioStreamPlayer3D
var reel: AudioStreamPlayer
var drag: AudioStreamPlayer
var random := RandomNumberGenerator.new()
var wave_sampler: Callable


func _ready() -> void:
	random.seed = 751
	make_float()
	line = Kit.mesh_at(self, line_mesh, Vector3.ZERO, overlay())
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var surface := Kit.mesh_at(self, splash_mesh, Vector3.ZERO, overlay())
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sound = AudioStreamPlayer3D.new()
	sound.unit_size = 5.6
	sound.max_distance = 47.0
	sound.volume_db = -6.0
	sound.max_polyphony = 3
	add_child(sound)
	reel = AudioStreamPlayer.new()
	drag = AudioStreamPlayer.new()
	add_child(reel)
	add_child(drag)
	for effect: String in SOUNDS:
		samples[effect] = synthesise(effect)
	reel.stream = samples.reel
	drag.stream = samples.drag


func make_float() -> void:
	bobber = Node3D.new()
	add_child(bobber)
	var ivory := Kit.paint(Color("#e8ead8"), .36)
	var tip := Kit.paint(Color("#f06b32"), .42)
	tip.emission = Color("#c44d20")
	tip.emission_enabled = true
	tip.emission_energy_multiplier = .23
	var stem := Kit.paint(Color("#333a2f"), .66)
	var shell := SphereMesh.new()
	shell.radial_segments = 18
	shell.rings = 10
	Kit.mesh_at(bobber, shell, Vector3(0, -.020, 0), ivory).scale = Vector3(.104, .146, .104)
	Kit.mesh_at(bobber, shell, Vector3(0, .016, 0), tip).scale = Vector3(.102, .117, .102)
	var pole := CylinderMesh.new()
	pole.height = .125
	pole.top_radius = .009
	pole.bottom_radius = .012
	pole.radial_segments = 10
	Kit.mesh_at(bobber, pole, Vector3(0, .064, 0), stem)
	var antenna := CylinderMesh.new()
	antenna.height = .049
	antenna.top_radius = .018
	antenna.bottom_radius = .015
	antenna.radial_segments = 10
	Kit.mesh_at(bobber, antenna, Vector3(0, .119, 0), tip)
	bobber.hide()


func draw_line(start: Vector3, end: Vector3, camera: Vector3, slack: float, clock: float, leader := 0.0) -> void:
	const STEPS := 36
	line.visible = true
	line.position = start
	line_mesh.clear_surfaces()
	line_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var span := end - start
	var crosswind := Vector3(-span.z, 0, span.x).normalized()
	for index in STEPS + 1:
		var fraction := float(index) / STEPS
		var curving := line_offset(span, crosswind, slack, clock, fraction)
		var tangent := span + Vector3.DOWN * slack * (4.0 - 8.0 * fraction)
		var sight := camera - (start + curving)
		var half_width := clampf(sight.length() * .00052, .00125, .012)
		var side := tangent.cross(sight).normalized() * half_width
		line_mesh.surface_set_color(Color(.81, .89, .82, .71 - fraction * .10))
		line_mesh.surface_add_vertex(curving - side)
		line_mesh.surface_add_vertex(curving + side)
	line_mesh.surface_end()
	if leader > 0.0:
		var fraction := clampf(1.0 - leader / maxf(leader, span.length()), .19, .95)
		bobber.global_position = start + line_offset(span, crosswind, slack, clock, fraction)
		bobber.rotation = Vector3(.45, atan2(span.x, span.z), .12 * sin(clock * 10.0))
		bobber.show()


func line_offset(span: Vector3, crosswind: Vector3, slack: float, clock: float, fraction: float) -> Vector3:
	var sweep := slack * 4.0 * fraction * (1.0 - fraction)
	return span * fraction + crosswind * sweep * (0.27 + .08 * sin(clock * 2.7 + fraction * 3.0)) - Vector3.UP * sweep * .73


func overlay() -> StandardMaterial3D:
	var paint := Kit.paint(Color.WHITE)
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	paint.vertex_color_use_as_albedo = true
	return paint


func break_surface(at: Vector3, strength: float, tag := "") -> void:
	rings.append({"at": at, "age": 0.0, "strength": strength})
	if strength >= .34:
		for index in roundi(6 + strength * 12):
			if droplets.size() >= 70:
				break
			var spin := random.randf_range(0, TAU)
			var outward := Vector3(sin(spin), 0, cos(spin))
			var throw := random.randf_range(.53, 1.48) * strength
			droplets.append({"at": at + outward * random.randf_range(.012, .08), "age": 0.0,
				"motion": outward * throw + Vector3.UP * random.randf_range(.46, 1.32) * strength,
				"life": random.randf_range(.26, .49), "size": random.randf_range(.012, .030)})
	if not tag.is_empty():
		play_sound(at, tag, lerpf(-13.0, -3.5, clampf(strength, 0.0, 1.0)))


func tick(delta: float, clock: float, camera: Vector3) -> void:
	splash_mesh.clear_surfaces()
	if rings.is_empty() and droplets.is_empty():
		return
	splash_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var shell := false
	for i in range(rings.size() - 1, -1, -1):
		var ripple: Dictionary = rings[i]
		ripple.age += delta
		if ripple.age > 1.44:
			rings.remove_at(i)
			continue
		var at: Vector3 = ripple.at
		for echo in 2:
			var age: float = ripple.age - echo * .19
			if age <= 0:
				continue
			var radius: float = .037 + age * (.39 + ripple.strength * .62)
			var width: float = .026 + .017 * ripple.strength
			var opacity: float = maxf(0, 1.0 - age / 1.44) * (.18 + ripple.strength * .32 - echo * .085)
			for wedge in 32:
				var a := float(wedge) / 32 * TAU
				var b := float(wedge + 1) / 32 * TAU
				var direction := Vector3(cos(a), 0, sin(a))
				var next := Vector3(cos(b), 0, sin(b))
				var alpha := opacity * (.78 + .22 * sin(a * 5.0 + age * 3.0))
				splash_mesh.surface_set_color(Color(.72, .88, .84, alpha))
				var low := on_water(at + direction * radius, clock)
				var high := on_water(at + next * radius, clock)
				var outer := on_water(at + direction * (radius + width), clock)
				var corner := on_water(at + next * (radius + width), clock)
				for vertex: Vector3 in [low, high, outer, outer, high, corner]:
					splash_mesh.surface_add_vertex(vertex)
				shell = true
	for i in range(droplets.size() - 1, -1, -1):
		var bead: Dictionary = droplets[i]
		bead.age += delta
		if bead.age > bead.life:
			droplets.remove_at(i)
			continue
		var age := float(bead.age)
		var center: Vector3 = bead.at + bead.motion * age + Vector3.DOWN * (age * age * 2.9)
		if center.y < surface_height(center, clock) + .019:
			continue
		var face := (camera - center).normalized()
		var side := face.cross(Vector3.UP).normalized() * float(bead.size)
		var up := side.cross(face).normalized() * float(bead.size) * 1.3
		splash_mesh.surface_set_color(Color(.73, .91, .89, (.90 - age / float(bead.life) * .58)))
		for p: Vector3 in [center - side, center + up, center + side, center - side, center + side, center - up]:
			splash_mesh.surface_add_vertex(p)
		shell = true
	if not shell:
		for i in 3:
			splash_mesh.surface_add_vertex(Vector3.ZERO)
	splash_mesh.surface_end()


func on_water(point: Vector3, clock: float) -> Vector3:
	return Vector3(point.x, surface_height(point, clock) + .043, point.z)


func surface_height(point: Vector3, clock: float) -> float:
	return wave_sampler.call(point, clock) if wave_sampler.is_valid() else Swell.height(point.x, point.z, clock)


func play_sound(at: Vector3, tag: String, volume: float) -> void:
	sound.global_position = at
	sound.stream = samples[tag]
	sound.pitch_scale = random.randf_range(.90, 1.11)
	sound.volume_db = volume
	sound.play()


func crank_sounds(retrieve: float, payout: float) -> void:
	if retrieve > .055:
		if not reel.playing:
			reel.play()
		reel.pitch_scale = lerpf(.82, 1.25, clampf(retrieve, 0.0, 1.0))
		reel.volume_db = -22.0 + retrieve * 4.8
	else:
		reel.stop()
	if payout > .09:
		if not drag.playing:
			drag.play()
		drag.pitch_scale = lerpf(.96, 1.27, clampf(payout, 0, 1))
		drag.volume_db = -19.0 + minf(payout, 1.0) * 5.0
	else:
		drag.stop()


func synthesise(tag: String) -> AudioStreamWAV:
	var seconds: float = SOUNDS[tag]
	var count := int(seconds * RATE)
	var frames := PackedFloat32Array()
	frames.resize(count)
	var slow := 0.0
	var wash := 0.0
	for index in count:
		var t := float(index) / RATE
		var white := random.randf_range(-1, 1)
		slow = slow * .947 + white * .053
		wash = wash * .79 + white * .21
		var level := 0.0
		match tag:
			"cast":
				var flick := sin(t / seconds * PI)
				level = (wash * .73 + (white - wash) * .14) * flick * flick
			"splash", "bite":
				var bump := smoothstep(0.0, .009, t) * exp(-t * (11.5 if tag == "splash" else 22.0))
				level = bump * (wash * .80 + slow * .60)
			"snap":
				level = exp(-t * 79.0) * (white * .35 + wash * .30)
			"reel", "drag":
				var pulse := fmod(t * (25.0 if tag == "reel" else 43.75), 1.0)
				var teeth := exp(-pulse * 14.0) * smoothstep(0.0, .043, pulse)
				level = teeth * (.48 * wash + .12 * white) + slow * .05
			"door_latch", "can_open", "lighter":
				var pop := exp(-t * 79.0) * (.40 * white + .25 * wash)
				var friction := wash * .46 * smoothstep(.014, .044, t) * exp(-maxf(0.0, t - .035) * 18.0)
				level = pop + friction * (1.0 if tag == "can_open" else .59)
			"sip", "bubble", "spill", "retch":
				var rate := 15.8 if tag == "bubble" else (7.2 if tag == "retch" else 10.8)
				var pulse := pow(maxf(0.0, sin(TAU * (t * rate + t * t * 1.6))), 2.0)
				var body := slow * 2.4
				var swell := sin(clampf(t / seconds, 0.0, 1.0) * PI)
				level = (wash * .59 + body * .32 + slow * .39) * swell * (.27 + pulse * .72)
			"draw", "exhale", "wipe":
				var breath := sin(clampf(t / seconds, 0.0, 1.0) * PI)
				level = (wash * .75 + (white - wash) * (.19 if tag == "wipe" else .10)) * breath * breath
		frames[index] = level * .65
	return AudioTexture.sample(frames, RATE, tag == "reel" or tag == "drag")
