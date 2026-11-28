extends CanvasLayer

const PRE_FRAMES := 600
const POST_FRAMES := 300
const MARK_KEY := KEY_F9

var game: Node3D
var status: Label
var frames: Array[Dictionary] = []
var incident_frames: Array[Dictionary] = []
var marker_events: Array[Dictionary] = []
var post_remaining := 0
var incident_id := 0
var frame_index := 0
var previous_process_usec := 0
var previous_render_post_usec := 0
var render_pre_usec := 0
var render_post_usec := 0
var render_duration_usec := 0
var previous_physics_frame := 0
var previous_camera_position := Vector3.ZERO
var previous_camera_rotation := Vector3.ZERO
var previous_player_position := Vector3.ZERO
var previous_probe_totals := {}
var previous_static_memory := 0.0
var previous_resource_count := 0.0
var output_directory := ""
var session_id := ""


func setup(owner_game: Node3D) -> void:
	game = owner_game
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	output_directory = requested_output_directory()
	DirAccess.make_dir_recursive_absolute(output_directory)
	session_id = Time.get_datetime_string_from_system(false, true).replace(":", "-")
	status = Label.new()
	status.text = "Performance recorder ON  ·  F9 marks a stutter"
	status.position = Vector2(18, 108)
	status.add_theme_color_override("font_color", Color("#ffdf79"))
	status.add_theme_color_override("font_shadow_color", Color(0, 0, 0, .9))
	status.add_theme_constant_override("shadow_offset_x", 2)
	status.add_theme_constant_override("shadow_offset_y", 2)
	status.add_theme_font_size_override("font_size", 18)
	add_child(status)
	RenderingServer.frame_pre_draw.connect(record_render_pre)
	RenderingServer.frame_post_draw.connect(record_render_post)
	previous_process_usec = Time.get_ticks_usec()
	previous_render_post_usec = previous_process_usec
	previous_physics_frame = Engine.get_physics_frames()
	previous_camera_position = game.eye.global_position
	previous_camera_rotation = game.eye.global_rotation
	previous_player_position = game.player.global_position
	previous_probe_totals = game.performance_probe_totals.duplicate()
	previous_static_memory = Performance.get_monitor(Performance.MEMORY_STATIC)
	previous_resource_count = Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	write_session_metadata()
	print("LIVE_RECORDER ready key=F9 output=", output_directory)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		if key == MARK_KEY:
			mark_incident()
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if game == null or game.eye == null or game.player == null:
		return
	var recorder_started := Time.get_ticks_usec()
	var now := recorder_started
	var wall_ms := float(now - previous_process_usec) / 1000.0
	var physics_frame := Engine.get_physics_frames()
	var physics_steps := physics_frame - previous_physics_frame
	var camera_position: Vector3 = game.eye.global_position
	var camera_rotation: Vector3 = game.eye.global_rotation
	var player_position: Vector3 = game.player.global_position
	var static_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
	var resource_count := Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	var row := {
		"frame": frame_index,
		"unix_ms": Time.get_unix_time_from_system() * 1000.0,
		"elapsed_ms": float(now) / 1000.0,
		"wall_frame_ms": wall_ms,
		"slow_33ms": wall_ms >= 33.33,
		"render_sync_ms": float(render_duration_usec) / 1000.0,
		"render_post_to_process_ms": float(now - previous_render_post_usec) / 1000.0,
		"physics_steps": physics_steps,
		"physics_frame": physics_frame,
		"engine_process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"engine_physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"render_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"video_memory_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"static_memory_bytes": static_memory,
		"static_memory_delta": static_memory - previous_static_memory,
		"resource_count": resource_count,
		"resource_count_delta": resource_count - previous_resource_count,
		"node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"object_count": Performance.get_monitor(Performance.OBJECT_COUNT),
		"orphan_nodes": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"camera_position": vector(camera_position),
		"camera_distance": camera_position.distance_to(previous_camera_position),
		"camera_rotation": vector(camera_rotation),
		"camera_rotation_delta": vector(camera_rotation - previous_camera_rotation),
		"player_position": vector(player_position),
		"player_distance": player_position.distance_to(previous_player_position),
		"player_velocity": vector(game.player.velocity),
		"game_mode": game.camera_mode(),
		"game_clock": game.clock,
		"process_sections_ms": probe_deltas(),
	}
	row["recorder_usec"] = Time.get_ticks_usec() - recorder_started
	frames.append(row)
	if frames.size() > PRE_FRAMES:
		frames.pop_front()
	if post_remaining > 0:
		incident_frames.append(row)
		post_remaining -= 1
		status.text = "STUTTER MARKED  ·  recording %d post frames" % post_remaining
		if post_remaining == 0:
			flush_incident()
	previous_process_usec = now
	previous_physics_frame = physics_frame
	previous_camera_position = camera_position
	previous_camera_rotation = camera_rotation
	previous_player_position = player_position
	previous_static_memory = static_memory
	previous_resource_count = resource_count
	frame_index += 1


func mark_incident() -> void:
	var marker := {
		"frame": frame_index,
		"unix_ms": Time.get_unix_time_from_system() * 1000.0,
		"elapsed_ms": float(Time.get_ticks_usec()) / 1000.0,
		"event": "manual_f9",
	}
	if post_remaining == 0:
		incident_id += 1
		incident_frames = frames.duplicate(true)
		marker_events = []
	marker_events.append(marker)
	post_remaining = POST_FRAMES
	status.text = "STUTTER MARKED  ·  recording %d post frames" % POST_FRAMES
	print("LIVE_RECORDER marker incident=", incident_id, " frame=", frame_index)


func flush_incident() -> void:
	var path := output_directory.path_join("incident-%s-%02d.json" % [session_id, incident_id])
	var payload := {
		"session": session_id,
		"incident": incident_id,
		"pre_target_frames": PRE_FRAMES,
		"post_target_frames": POST_FRAMES,
		"markers": marker_events,
		"frames": incident_frames,
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		status.text = "Recorder write failed  ·  press F9 to retry a new incident"
		push_error("LIVE_RECORDER failed path=" + path)
		return
	file.store_string(JSON.stringify(payload))
	file.close()
	status.text = "Incident saved  ·  F9 marks another stutter"
	print("LIVE_RECORDER saved path=", path, " frames=", incident_frames.size())
	incident_frames.clear()
	marker_events.clear()


func probe_deltas() -> Dictionary:
	var deltas := {}
	for section in game.performance_probe_totals:
		var current := int(game.performance_probe_totals[section])
		deltas[section] = float(current - int(previous_probe_totals.get(section, current))) / 1000.0
	previous_probe_totals = game.performance_probe_totals.duplicate()
	return deltas


func record_render_pre() -> void:
	render_pre_usec = Time.get_ticks_usec()


func record_render_post() -> void:
	render_post_usec = Time.get_ticks_usec()
	render_duration_usec = render_post_usec - render_pre_usec
	previous_render_post_usec = render_post_usec


func requested_output_directory() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--performance-output="):
			return argument.trim_prefix("--performance-output=").replace("\\", "/")
	return ProjectSettings.globalize_path("user://performance-incidents")


func write_session_metadata() -> void:
	var path := output_directory.path_join("session-%s.json" % session_id)
	var metadata := {
		"session": session_id,
		"started_unix_ms": Time.get_unix_time_from_system() * 1000.0,
		"engine": Engine.get_version_info(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"rendering_device": RenderingServer.get_video_adapter_name(),
		"os": OS.get_name(),
		"command_line": OS.get_cmdline_args(),
		"pre_frames": PRE_FRAMES,
		"post_frames": POST_FRAMES,
		"marker_key": "F9",
		"unavailable": [
			"per-frame GPU execution duration",
			"driver queue wait reason",
			"pipeline compilation events",
			"per-resource allocation/free event names",
			"per-frame disk I/O attribution inside Godot",
		],
		"external_sampler": "system-samples.csv from tools/Run Live Performance Recorder.ps1",
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(metadata, "  "))
		file.close()


func vector(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
