extends Node3D

const Kit = preload("res://scenery.gd")
const Model = preload("res://mario_model.gd")
const Property = preload("res://mario_property.gd")
const Dialogue = preload("res://mario_companion_dialogue.gd")
const ACTION := "mario_project"
const PARTS := ["Battery", "Motor", "Controller"]
const PART_OFFSETS := {"Battery": Vector3(16.5, .16, -42.4), "Motor": Vector3(19.0, .16, -42.4), "Controller": Vector3(21.5, .16, -42.4)}
const INTERACT_DISTANCE := 2.5
const NPC_DISTANCE := 3.2

var game: Node3D
var property: Node3D
var mario: StaticBody3D
var model := Model.new()
var dialogue := Dialogue.new()
var markers: Dictionary = {}
var assembly: Dictionary = {}
var inspection_tool: Node3D
var last_dialogue_context: Dictionary = {}
var elapsed := 0.0


func setup(world: Node3D) -> void:
	game = world
	property = Property.build(game.river, game.river.ground_height, game.river.concrete_scan, game.river.wood_scan)
	build_workshop_props()
	build_inspection_tool()
	build_mario()
	build_assembly()
	for part: String in PARTS:
		build_part_marker(part)


func state() -> Dictionary:
	if not game.campaign.ledger.state.has("project_tomorrow"):
		game.campaign.ledger.state.project_tomorrow = {
			"step": 0, "intro_tool_found": false, "parts": [], "trial_started": false, "trial_distance": 0.0,
			"battery_warning": false, "safe_failure": false, "trial_attempts": 0, "unlocks": [],
		}
	return game.campaign.ledger.state.project_tomorrow


func build_mario() -> void:
	mario = StaticBody3D.new()
	mario.name = "MarioCompanion"
	var local_at := Vector3(21.8, 0.0, -43.0)
	property.add_child(mario)
	mario.position = local_at
	mario.rotation.y = -1.0
	mario.add_child(model)
	model.build()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .27
	capsule.height = 1.76
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	collision.position = Vector3(0, .89, 0)
	mario.add_child(collision)
	var tag := Label3D.new()
	tag.text = "MARIO"
	tag.position.y = 1.98
	tag.font_size = 25
	tag.pixel_size = .004
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color("#fff1d1")
	tag.outline_size = 4
	tag.outline_modulate = Color("#24313b")
	mario.add_child(tag)
	var talk_marker := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = .25
	ring.outer_radius = .33
	talk_marker.mesh = ring
	talk_marker.position = Vector3(0, .025, 0)
	talk_marker.material_override = Kit.paint(Color("#b4d9df"), .24, .32)
	property.add_child(talk_marker)
	talk_marker.position = local_at + Vector3(0, .02, 0)


func build_part_marker(part: String) -> void:
	var marker := Node3D.new()
	marker.name = "MarioPart" + part
	property.add_child(marker)
	marker.position = PART_OFFSETS[part]
	var paint := Kit.paint(Color("#c29a62"), .40, .38)
	var box := BoxMesh.new()
	box.size = Vector3(.36, .30, .30)
	Kit.mesh_at(marker, box, Vector3(0, .20, 0), paint)
	var label := Label3D.new()
	label.text = part
	label.position.y = .52
	label.font_size = 19
	label.pixel_size = .004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 3
	marker.add_child(label)
	markers[part] = marker


func build_inspection_tool() -> void:
	inspection_tool = Node3D.new()
	inspection_tool.name = "WorkshopMeasuringSquare"
	property.add_child(inspection_tool)
	inspection_tool.position = Vector3(16.5, 0.0, -41.0)
	var metal := Kit.paint(Color("#9ba4a1"), .38, .72)
	Kit.box_at(inspection_tool, Vector3(0, .18, 0), Vector3(.46, .05, .07), metal)
	Kit.box_at(inspection_tool, Vector3(-.19, .25, 0), Vector3(.05, .18, .07), metal)
	var label := Label3D.new()
	label.text = "MEASURING SQUARE"
	label.position.y = .48
	label.font_size = 16
	label.pixel_size = .004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 3
	inspection_tool.add_child(label)


func build_assembly() -> void:
	var stand := Node3D.new()
	stand.name = "ElectricOutboardAssembly"
	property.add_child(stand)
	stand.position = Vector3(19.0, .99, -42.4)
	var steel := Kit.paint(Color("#515b60"), .52, .44)
	var blue := Kit.paint(Color("#426a79"), .45, .32)
	var battery := Kit.box_at(stand, Vector3(-.46, .18, 0), Vector3(.36, .34, .31), steel)
	var motor := Kit.box_at(stand, Vector3(0, .18, 0), Vector3(.34, .31, .30), blue)
	var controller := Kit.box_at(stand, Vector3(.43, .18, 0), Vector3(.29, .22, .25), Kit.paint(Color("#b5b4a5"), .36, .65))
	for node: MeshInstance3D in [battery, motor, controller]:
		node.visible = false
	assembly = {"Battery": battery, "Motor": motor, "Controller": controller}


func build_workshop_props() -> void:
	var bench := Kit.paint(Color("#72523a"), .90)
	var metal := Kit.paint(Color("#455158"), .76, .18)
	var tools := Kit.paint(Color("#b5b4a5"), .36, .65)
	var garage := Node3D.new()
	garage.name = "MarioWorkshopEquipment"
	property.add_child(garage)
	garage.position = Vector3(19.0, 0, -43.5)
	Kit.box_at(garage, Vector3(-2.3, .91, -2.4), Vector3(4.6, .18, 1.05), bench)
	Kit.box_at(garage, Vector3(-2.3, .46, -2.4), Vector3(.13, .88, .82), metal)
	Kit.box_at(garage, Vector3(.75, .78, -2.9), Vector3(1.25, 1.52, .94), metal)
	Kit.box_at(garage, Vector3(2.6, 1.03, -1.2), Vector3(.5, 2.05, .6), metal)
	Kit.box_at(garage, Vector3(-2.3, 1.08, -2.94), Vector3(2.7, .035, .045), tools)
	# A small motor and test stand make the research goal visible before the first interaction.
	var engine := Node3D.new()
	engine.name = "ElectricOutboardPrototypeStand"
	garage.add_child(engine)
	engine.position = Vector3(-2.2, 1.03, -2.3)
	Kit.box_at(engine, Vector3(0, .23, 0), Vector3(.64, .46, .48), metal)
	Kit.box_at(engine, Vector3(0, .49, .02), Vector3(.33, .13, .31), Kit.paint(Color("#426a79"), .42, .26))
	Kit.box_at(engine, Vector3(0, -.18, .08), Vector3(.09, .42, .08), metal)
	var prop := CylinderMesh.new()
	prop.top_radius = .23
	prop.bottom_radius = .23
	prop.height = .025
	var blade := Kit.mesh_at(engine, prop, Vector3(0, -.40, .08), tools)
	blade.rotation.x = PI * .5


func _process(delta: float) -> void:
	elapsed += delta
	model.pose_idle(elapsed)
	advance_trial(delta)
	refresh_markers()


func can_interact() -> bool:
	if game == null or not game.can_talk_to_shannon():
		return false
	return interaction_target() != ""


func interaction_target() -> String:
	if game.player.global_position.distance_to(mario.global_position) <= NPC_DISTANCE:
		return "mario"
	var current := state()
	if int(current.step) == 0 and not current.get("intro_tool_found", false) \
			and game.player.global_position.distance_to(inspection_tool.global_position) <= INTERACT_DISTANCE:
		return "measuring_square"
	if int(current.step) == 1:
		for part: String in PARTS:
			if current.parts.has(part):
				continue
			if game.player.global_position.distance_to(markers[part].global_position) <= INTERACT_DISTANCE:
				return part
	return ""


func prompt() -> String:
	match interaction_target():
		"mario": return "E  Talk to Mario"
		"measuring_square": return "E  Inspect the measuring square"
		"Battery", "Motor", "Controller": return "E  Pick up " + interaction_target()
	return ""


func interact() -> void:
	var target := interaction_target()
	if target.is_empty():
		return
	if target == "mario":
		game.open_mario_offer(offer())
	elif target == "measuring_square":
		game.campaign.request(ACTION, ["inspect_tool", "measuring_square"])
	else:
		game.campaign.request(ACTION, ["collect", target])


func offer() -> Dictionary:
	var current := state()
	var stage := int(current.get("step", 0))
	last_dialogue_context = companion_context()
	var data := {"npc": ACTION, "name": "Mario", "status": "Project Tomorrow · %d of 3 missions" % mini(maxi(stage, 1), 3)}
	match stage:
		0:
			var mission_objective := "Pick up the measuring square, then hear Mario's challenge." if not current.get("intro_tool_found", false) else "Ask Mario about his electric outboard challenge."
			data.merge({"id": "meet_mario", "title": "The Man on Silvie Street",
				"description": dialogue.authored("greeting"), "objectives": mission_objective})
			if current.get("intro_tool_found", false):
				data.merge({"button": "Meet Mario", "action": "accept_intro"})
		1:
			data.merge({"title": "Mission 2 · Electric Outboard", "description": dialogue.authored("parts"),
				"objectives": "Collect the battery, motor and controller from the garage bench.  %d of 3 parts" % current.parts.size()})
		2:
			data.merge({"id": "first_test", "title": "Mission 3 · First Test", "description": dialogue.authored("test"),
				"objectives": "Take the boat out, run the prototype test and return safely to Mario.",
				"button": "Start the river test", "action": "start_trial"})
		3:
			data.merge({"title": "Mission 3 · First Test", "description": dialogue.authored("low_battery") if current.battery_warning else "The test run exposed a battery endurance problem.",
				"objectives": "Return to shore and slow down to protect the prototype." if not current.safe_failure else "The prototype is safe. Return to Mario to review the results."})
			if current.safe_failure:
				data.button = "Review the test"
				data.action = "complete_trial"
		4:
			data.merge({"title": "Mission 3 · First Test Complete", "description": dialogue.authored("complete"),
				"objectives": "Rich wants a fair race next. Mario has opened the workshop and logged an endurance upgrade for later.",
				"button": "Repeat the river test", "action": "replay_trial"})
	return data


func companion_context() -> Dictionary:
	var nearby: Array[String] = []
	var player_at: Vector3 = game.player.global_position
	if player_at.distance_to(mario.global_position) <= NPC_DISTANCE:
		nearby.append("Mario")
	if inspection_tool.visible and player_at.distance_to(inspection_tool.global_position) <= INTERACT_DISTANCE + 1.0:
		nearby.append("measuring square")
	for part: String in PARTS:
		if markers.has(part) and markers[part].visible and player_at.distance_to(markers[part].global_position) <= 4.0:
			nearby.append(part.to_lower())
	var current := state()
	var location := "Deep River"
	if player_at.distance_to(mario.global_position) <= 24.0:
		location = "16 Silvie Street workshop"
	elif current.get("trial_started", false):
		location = "Ottawa River first-test route"
	var stage_name: String = ["meet Mario", "assemble the electric outboard", "prepare the first test", "respond to the endurance warning", "review the test"][mini(int(current.get("step", 0)), 4)]
	return dialogue.context(location, stage_name, nearby,
		current.get("companion_memory", []))


func handle_request(peer: int, value: Variant) -> void:
	if not value is Array or value.size() != 2 or not value[0] is String:
		return
	var person: Dictionary = game.campaign.actor(peer)
	if person.is_empty() or person.get("onboard", false):
		return
	var current := state()
	var action := String(value[0])
	var target := String(value[1])
	match action:
		"inspect_tool":
			if int(current.step) == 0 and not current.get("intro_tool_found", false) \
					and person.at.distance_to(inspection_tool.global_position) <= INTERACT_DISTANCE + .55:
				current.intro_tool_found = true
				dialogue.remember(current, "You examined a measuring square in Mario's workshop.")
				notify_party("The square is ready for the bench. Rich introduced you to Mario, who wants to prove an electric outboard can compete with his old gas motor.")
				game.campaign.changed()
		"accept_intro":
			if int(current.step) == 0 and current.get("intro_tool_found", false) and person.at.distance_to(mario.global_position) <= NPC_DISTANCE:
				current.step = 1
				_add_unlock(current, "mario_companion")
				_add_unlock(current, "mario_workshop")
				dialogue.remember(current, "You met Mario and accepted the electric outboard challenge.")
				notify_party("Mario points you toward the workshop bench. Rich doubts the quiet motor will pull a full boat, but agrees a controlled river test is fair. Three meaningful assemblies are enough for a first prototype.")
				game.campaign.changed()
		"collect":
			if int(current.step) != 1 or not PARTS.has(target) or current.parts.has(target):
				return
			if person.at.distance_to(markers[target].global_position) > INTERACT_DISTANCE + .55:
				return
			current.parts.append(target)
			dialogue.remember(current, "You collected the %s assembly for the electric outboard." % target.to_lower())
			if current.parts.size() == PARTS.size():
				current.step = 2
				_add_unlock(current, "electric_outboard_prototype")
				notify_party("The battery, motor and controller click into the visible prototype. Talk to Mario when you're ready for a river test.")
			else:
				notify_party("%s collected. The bench still needs %d part(s)." % [target, PARTS.size() - current.parts.size()])
			game.campaign.changed()
		"start_trial", "replay_trial":
			var allowed_step := 2 if action == "start_trial" else 4
			if int(current.step) == allowed_step and person.at.distance_to(mario.global_position) <= NPC_DISTANCE:
				current.trial_started = true
				current.trial_distance = 0.0
				current.trial_last = [game.vessel.center.x, game.vessel.center.y, game.vessel.center.z]
				current.battery_warning = false
				current.safe_failure = false
				current.trial_attempts = int(current.get("trial_attempts", 0)) + 1
				current.step = 3
				dialogue.remember(current, "You began the electric outboard's first river test.")
				notify_party("Test started. Take the helm, accelerate on open water, then ease off when the endurance warning appears.")
				game.campaign.changed()
		"complete_trial":
			if int(current.step) == 3 and current.safe_failure and person.at.distance_to(mario.global_position) <= NPC_DISTANCE:
				current.trial_started = false
				current.step = 4
				_add_unlock(current, "friendly_outboard_rivalry")
				_add_unlock(current, "electric_endurance_research")
				dialogue.remember(current, "You returned safely after diagnosing the prototype's short endurance.")
				notify_party("First Test complete. Mario records the short endurance; Rich proposes a fair race once the design is ready. A longer-range battery is the next research milestone.")
				game.campaign.changed()


func _add_unlock(current: Dictionary, id: String) -> void:
	var unlocks: Array = current.get("unlocks", [])
	if not unlocks.has(id):
		unlocks.append(id)
	current.unlocks = unlocks


func notify_party(text: String) -> void:
	for peer: int in game.campaign.crew.people:
		game.campaign.tell(peer, text)


func advance_trial(delta: float) -> void:
	if game.campaign.crew.is_guest():
		return
	var current := state()
	if not current.get("trial_started", false):
		return
	var boat: Variant = game.vessel
	var last: Array = current.get("trial_last", [boat.center.x, boat.center.y, boat.center.z])
	var previous := Vector3(float(last[0]), float(last[1]), float(last[2]))
	var traveled := Vector2(boat.center.x - previous.x, boat.center.z - previous.z).length()
	current.trial_distance = float(current.get("trial_distance", 0.0)) + traveled
	current.trial_last = [boat.center.x, boat.center.y, boat.center.z]
	if float(current.trial_distance) >= 180.0 and not current.battery_warning:
		current.battery_warning = true
		game.campaign.changed(false)
		notify_party("Battery draw is higher than predicted. Reduce throttle and return safely.")
	if current.battery_warning and not current.safe_failure and boat.speed <= 1.1:
		current.safe_failure = true
		game.campaign.changed()
		notify_party("Prototype shut down safely. Return to Mario and review the test data.")


func refresh_markers() -> void:
	var current := state()
	inspection_tool.visible = int(current.step) == 0 and not current.get("intro_tool_found", false)
	for part: String in PARTS:
		if not markers.has(part):
			continue
		markers[part].visible = int(current.step) == 1 and not current.parts.has(part)
		assembly[part].visible = current.parts.has(part) or int(current.step) >= 2


func objective_text() -> String:
	var current := state()
	match int(current.get("step", 0)):
		0: return "Mission 1 · Meet Mario  ·  Find the measuring square in his garage"
		1: return "Mission 2 · Electric Outboard  ·  %d / 3 assemblies" % current.parts.size()
		2: return "Mission 3 · First Test  ·  Talk to Mario to launch the river trial"
		3:
			if not current.battery_warning:
				return "First Test  ·  Pilot the prototype on open water"
			if not current.safe_failure:
				return "First Test  ·  Reduce throttle to protect the prototype"
			return "First Test  ·  Return to Mario"
		4: return "Mission 3 complete  ·  Friendly race and battery research unlocked for later"
	return ""
