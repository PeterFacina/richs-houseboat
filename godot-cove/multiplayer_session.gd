extends Node3D

signal changed
signal stopped
signal requested(peer: int, action: String, argument: Variant)
signal command_received(throttle: float, rudder: float, center_wheel: bool)
signal state_received(state: Dictionary, dock: int, captain: int, revision: int)
signal ship_received(state: Dictionary)
signal weather_received(state: Dictionary, minute: float)
signal result_received(message: String, board_at: int, use_boat: bool)
signal rich_heard(line_id: String, toward: Vector3)
signal member_left(peer: int)

const Avatar = preload("res://crew_avatar.gd")
const Idle = preload("res://character_idle.gd")
const PORT := 28460
const MAX_GUESTS := 3

var mode := "solo"
var started := false
var people: Dictionary = {}
var poses: Dictionary = {}
var avatars: Dictionary = {}
var local_name := "Rich"
var local_profile := ""
var progression_secret := ""
var progression_keys := {}
var last_address := ""
var status := ""
var packet_timer := 0.0
var boat: Node3D


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load("user://river_identity.cfg") == OK:
		local_name = clean_name(str(config.get_value("player", "name", local_name)))
	multiplayer.peer_connected.connect(peer_arrived)
	multiplayer.peer_disconnected.connect(peer_departed)
	multiplayer.connected_to_server.connect(joined_server)
	multiplayer.connection_failed.connect(connection_failed)
	multiplayer.server_disconnected.connect(server_closed)


func on_server() -> bool:
	return mode == "host"


func is_guest() -> bool:
	return mode == "guest" or mode == "joining"


func my_id() -> int:
	return multiplayer.get_unique_id() if mode != "solo" else 1


func clean_name(display_name: String) -> String:
	var result := display_name.strip_edges().replace("\n", " ").replace("\r", "").substr(0, 18)
	return result if not result.is_empty() else "River crew"


func host(display_name: String) -> void:
	if mode != "solo":
		return
	var listener := ENetMultiplayerPeer.new()
	# Leave max_channels at its engine default. In the bundled Godot 4.7.2,
	# an explicit limit is passed into ENet's incoming bandwidth argument,
	# which throttles/drops pose and vehicle packets even though joins succeed.
	var fail := listener.create_server(PORT, MAX_GUESTS)
	if fail != OK:
		status = "Could not host on UDP %d (%s)." % [PORT, error_string(fail)]
		changed.emit()
		return
	set_display_name(display_name)
	people[1] = {"name": local_name, "profile": local_profile}
	mode = "host"
	multiplayer.multiplayer_peer = listener
	status = "Hosting on UDP %d   •   %s" % [PORT, local_addresses()]
	changed.emit()


func start_session() -> void:
	if not on_server() or started:
		return
	started = true
	for peer: int in people:
		if peer != 1:
			requested.emit(peer, "connected", null)
	changed.emit()


func join(display_name: String, host_address: String) -> void:
	if mode != "solo":
		return
	last_address = host_address.strip_edges()
	if last_address.is_empty():
		status = "Enter the host's LAN IP."
		changed.emit()
		return
	var connection := ENetMultiplayerPeer.new()
	var fail := connection.create_client(last_address, PORT, 3)
	if fail != OK:
		status = "Could not join (%s)." % error_string(fail)
		changed.emit()
		return
	set_display_name(display_name)
	mode = "joining"
	multiplayer.multiplayer_peer = connection
	status = "Connecting to %s…" % last_address
	changed.emit()


func local_addresses() -> String:
	var found := PackedStringArray()
	for address: String in IP.get_local_addresses():
		if "." in address and not address.begins_with("127.") and not address.begins_with("169.254."):
			found.append(address)
	return " / ".join(found) if not found.is_empty() else "127.0.0.1"


func stop(message := "") -> void:
	mode = "solo"
	started = false
	status = message
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	for avatar: Node3D in avatars.values():
		avatar.queue_free()
	avatars.clear()
	poses.clear()
	progression_keys.clear()
	people.clear()
	stopped.emit()
	changed.emit()


func peer_arrived(_id: int) -> void:
	if on_server():
		status = "Hosting on UDP %d   •   %s" % [PORT, local_addresses()]


func peer_departed(id: int) -> void:
	progression_keys.erase(id)
	people.erase(id)
	poses.erase(id)
	if avatars.has(id):
		avatars[id].queue_free()
		avatars.erase(id)
	member_left.emit(id)
	if on_server() and people.size() > 1:
		roster.rpc(people)
	changed.emit()


func joined_server() -> void:
	mode = "guest"
	status = "Joined %s." % last_address
	register.rpc_id(1, local_name, local_profile, progression_secret)
	changed.emit()


func connection_failed() -> void:
	stop("Could not reach the host. Check the address and UDP %d." % PORT)


func server_closed() -> void:
	stop("The host ended the session.")


func person(peer: int) -> Dictionary:
	return {"name": local_name, "profile": local_profile} if peer == my_id() else people.get(peer, {})


@rpc("any_peer", "call_remote", "reliable")
func register(display_name: String, profile: String, secret: String) -> void:
	if not on_server() or profile.length() != 32:
		return
	var peer := multiplayer.get_remote_sender_id()
	if secret.length() != 32 or not secret.is_valid_hex_number(false) or progression_keys.has(peer):
		return
	var key := secret.sha256_text()
	if progression_keys.values().has(key) or secret == progression_secret:
		key = Crypto.new().generate_random_bytes(32).hex_encode()
	progression_keys[peer] = key
	if profile == local_profile:
		# Two local test instances can share a Godot user directory.
		profile = ("%032x" % peer).right(32)
	people[peer] = {"name": clean_name(display_name), "profile": profile}
	roster.rpc(people)
	if started:
		requested.emit(peer, "connected", null)
	changed.emit()


@rpc("authority", "call_remote", "reliable")
func roster(names: Dictionary) -> void:
	people = names
	if people.has(my_id()):
		local_name = str(people[my_id()].name)
	for peer: int in avatars:
		if people.has(peer):
			avatars[peer].label.text = str(people[peer].name)
	changed.emit()


@rpc("authority", "call_remote", "reliable")
func enter_river(initial_ship: Dictionary) -> void:
	if mode == "guest" and not started:
		ship_received.emit(initial_ship)
		if initial_ship.has("weather"):
			weather_received.emit(initial_ship.weather, float(initial_ship.work_minutes))
		started = true
		changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func order(action: String, argument: Variant) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if on_server() and people.has(peer) and action != "connected":
		requested.emit(peer, action, argument)


@rpc("authority", "call_remote", "reliable")
func share_state(state: Dictionary, dock: int, captain: int, revision: int) -> void:
	state_received.emit(state, dock, captain, revision)


@rpc("authority", "call_remote", "reliable")
func result(message: String, board_at: int, use_boat: bool) -> void:
	result_received.emit(message, board_at, use_boat)


@rpc("authority", "call_remote", "reliable")
func rich_line(line_id: String, toward: Vector3) -> void:
	rich_heard.emit(line_id, toward)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func share_ship(state: Dictionary) -> void:
	ship_received.emit(state)


@rpc("authority", "call_remote", "reliable")
func share_weather(state: Dictionary, minute: float) -> void:
	if is_guest():
		weather_received.emit(state, minute)


@rpc("any_peer", "call_remote", "unreliable_ordered", 2)
func steer(throttle: float, rudder: float, center_wheel := false) -> void:
	if on_server() and is_finite(throttle) and is_finite(rudder):
		if int(get_meta("captain", 0)) == multiplayer.get_remote_sender_id():
			command_received.emit(clampf(throttle, -.32, 1.0), clampf(rudder, -1.0, 1.0), center_wheel)


@rpc("any_peer", "call_remote", "unreliable_ordered", 2)
func pose(position: Vector3, turn: float, onboard: bool, animation: Dictionary) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if not people.has(peer) or not position.is_finite() or not is_finite(turn):
		return
	if onboard and (absf(position.x) > 2.6 or position.z < -4.1 or position.z > 7.2 or absf(position.y) > 4.0):
		return
	if not onboard and (position.x < 0.0 or position.z < 0.0 or position.x > 31500 or position.z > 22600):
		return
	var visual := {}
	var idle: Variant = animation.get("idle")
	if idle is Vector3 and idle.is_finite() and idle.x >= Idle.SHIFT and idle.x <= Idle.PHONE:
		var gesture := int(idle.x)
		visual.idle = Vector3(gesture, clampf(idle.y, 0.0, Idle.DURATIONS[gesture]), -1.0 if idle.z < 0.0 else 1.0)
	for key in ["move", "end", "fish", "direction"]:
		var point: Variant = animation.get(key)
		if point is Vector3 and point.is_finite():
			visual[key] = point
	for key in ["rod", "line", "float", "hand_left_visible", "hand_right_visible", "lighter_visible", "use_smoke", "cabin_high", "roach_on_foot", "flashlight"]:
		visual[key] = animation.get(key, false) == true
	for key in ["stage", "species", "length", "hook_id", "hand_mode", "use_item", "use_serial"]:
		var value: Variant = animation.get(key)
		if value is int:
			visual[key] = value
	for key in ["age", "pitch", "tension", "reel", "reach", "scoop", "use_age", "view_roll"]:
		var amount: Variant = animation.get(key)
		if amount is float and is_finite(amount):
			visual[key] = clampf(amount, -1.5, 20.0 if key in ["age", "use_age"] else 1.5)
	for key in ["hand_left", "hand_right", "use_prop", "use_lighter", "rod_pose", "tool_pose"]:
		var pose: Variant = animation.get(key)
		if pose is Transform3D and pose.origin.is_finite() and pose.origin.length_squared() < 16 \
				and pose.basis.x.is_finite() and pose.basis.y.is_finite() and pose.basis.z.is_finite() \
				and pose.basis.determinant() > .2 and pose.basis.determinant() < 4:
			visual[key] = Transform3D(pose.basis.orthonormalized(), pose.origin)
	for key in ["rod_crank", "rod_rotor"]:
		var angle: Variant = animation.get(key)
		if angle is float and is_finite(angle):
			visual[key] = wrapf(angle, -PI, PI)
	for key in ["hand_left_pose", "hand_right_pose"]:
		var pose: Variant = animation.get(key)
		if pose is String and pose in ["relaxed", "fist", "shaft", "carry", "hold", "pinch", "bottle", "can"]:
			visual[key] = pose
	var tool: Variant = animation.get("tool")
	for key in ["sprint", "crouch", "eye_drop"]:
		var weight: Variant = animation.get(key)
		if weight is float and is_finite(weight):
			visual[key] = clampf(weight, 0, 1)
	if animation.get("seat", "") in ["", "bed", "toilet", "heli"]:
		visual.seat = animation.get("seat", "")
	if tool is String and tool in ["net", "cooler", "lamp", "helm", "fish"]:
		visual.tool = tool
	poses[peer] = {"at": position, "yaw": wrapf(turn, -PI, PI), "onboard": onboard, "animation": visual,
		"received": Time.get_ticks_msec()}


func last_pose(peer: int) -> Dictionary:
	var sample: Dictionary = poses.get(peer, {})
	if sample.is_empty():
		return sample
	var at: Vector3 = sample.at
	var facing: float = sample.yaw + (boat.rotation.y if sample.onboard else 0.0)
	return {"at": boat.to_global(at) if sample.onboard else at, "onboard": sample.onboard,
		"yaw": facing, "pitch": sample.animation.get("pitch", 0.0), "eye_drop": sample.animation.get("eye_drop", 0.0)}


func tick(delta: float, actor: CharacterBody3D, onboard: bool, yaw: float, visual: Callable, clock: float, eye: Vector3) -> bool:
	if mode not in ["host", "guest"]:
		return false
	if mode == "host" and people.size() < 2:
		return false
	for peer: int in poses:
		if not people.has(peer):
			continue
		if not avatars.has(peer):
			var avatar := Avatar.new()
			add_child(avatar)
			avatar.setup(str(people[peer].name), people.keys().find(peer))
			avatars[peer] = avatar
		var avatar: Avatar = avatars[peer]
		var sample: Dictionary = poses[peer]
		avatar.apply_sample(sample, boat, delta, clock, eye)
	packet_timer += delta
	if packet_timer < .064:
		return false
	packet_timer = 0.0
	pose.rpc(boat.to_local(actor.global_position) if onboard else actor.global_position,
		yaw - boat.rotation.y if onboard else yaw, onboard, visual.call())
	return true


func set_display_name(display_name: String) -> void:
	local_name = clean_name(display_name)
	var config := ConfigFile.new()
	config.set_value("player", "name", local_name)
	config.save("user://river_identity.cfg")
	if on_server():
		people[1].name = local_name
		roster.rpc(people)
	elif mode == "guest":
		rename_request.rpc_id(1, local_name)
	changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func rename_request(display_name: String) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if not on_server() or not people.has(peer):
		return
	people[peer].name = clean_name(display_name)
	if avatars.has(peer):
		avatars[peer].label.text = str(people[peer].name)
	roster.rpc(people)
	changed.emit()
