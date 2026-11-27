extends SceneTree

const FRAMES := 720
const WARMUP := 180

var render_pre_usec := 0
var render_post_usec := 0
var render_duration_usec := 0


func _initialize() -> void:
	call_deferred("profile")


func profile() -> void:
	RenderingServer.frame_pre_draw.connect(record_render_pre)
	RenderingServer.frame_post_draw.connect(record_render_post)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.content_scale_size = Vector2i(1280, 720)
	var mode := argument_value("--control", "empty")
	var scene := Node3D.new()
	root.add_child(scene)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(0.0, 18.0, 32.0)
	camera.look_at(Vector3.ZERO)
	if mode == "static":
		build_static_stress(scene)
	for frame in WARMUP:
		await process_frame
	await sample(mode)
	quit()


func build_static_stress(scene: Node3D) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.72, 0.72, 0.72)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#6f8d67")
	material.roughness = 0.84
	mesh.material = material
	for z in 40:
		for x in 65:
			var item := MeshInstance3D.new()
			item.mesh = mesh
			item.position = Vector3((x - 32) * 0.92, sin(float(x * 7 + z * 11)) * 0.35, (z - 20) * 0.92)
			item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			scene.add_child(item)
	print("CONTROL_STATIC objects=2600 shared_mesh=true shared_material=true shadows=false")


func sample(label: String) -> void:
	var frame_ms: Array[float] = []
	var spike_count := 0
	var previous := Time.get_ticks_usec()
	for frame in FRAMES:
		await process_frame
		var now := Time.get_ticks_usec()
		var elapsed := float(now - previous) / 1000.0
		previous = now
		frame_ms.append(elapsed)
		if elapsed >= 33.33:
			spike_count += 1
			print("CONTROL_SPIKE mode=", label, " frame=", frame, " ms=", elapsed,
				" render_stage_ms=", float(render_duration_usec) / 1000.0,
				" post_to_process_ms=", float(now - render_post_usec) / 1000.0)
	frame_ms.sort()
	var tail_count := maxi(1, ceili(FRAMES * .01))
	var tail_total := 0.0
	for index in range(FRAMES - tail_count, FRAMES):
		tail_total += frame_ms[index]
	print("CONTROL_RESULT mode=", label, " frames=", FRAMES,
		" median_ms=", frame_ms[FRAMES / 2],
		" p95_ms=", frame_ms[floori(FRAMES * .95)],
		" p99_ms=", frame_ms[floori(FRAMES * .99)],
		" worst_ms=", frame_ms[-1],
		" fps_1pct_low=", 1000.0 / (tail_total / tail_count),
		" spikes_33ms=", spike_count)


func argument_value(prefix: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix + "="):
			return argument.trim_prefix(prefix + "=")
	return fallback


func record_render_pre() -> void:
	render_pre_usec = Time.get_ticks_usec()


func record_render_post() -> void:
	render_post_usec = Time.get_ticks_usec()
	render_duration_usec = render_post_usec - render_pre_usec
