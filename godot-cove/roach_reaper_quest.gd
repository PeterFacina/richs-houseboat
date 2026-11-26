extends Node3D

const Model = preload("res://roach_reaper_model.gd")
const Chain = preload("res://quest_chain.gd")
const XP = preload("res://progression.gd")
const ID := "roach_reaper"
const NPC := "Roach Reaper"
const TITLE := "The Roach Reaper"
const STREET := 63 # Silvie Street in the Deep River road and sidewalk data.
const TARGET := 10
const QUESTS := [{"id": ID, "target": TARGET}]
const DEADLINE_MINUTES := 360.0
const SMOKING_SECONDS := 5.4
const INTRO := "I'm conducting a curbside census. Ten joint roaches, one very official sandwich bag. Think you can find the rest before my phone dies?"
const THANKS := "Ten out of ten. You're now the only person in town with a merit badge in curb archaeology. Allow me to inspect the evidence."
const OBJECTIVE := "Collect ten discarded joint roaches along Silvie Street and return within six in-game hours."

var game
var campaign
var street := PackedVector2Array()
var inside := {}
var npc: Model
var pickups: Array[Node3D] = []
var surfaces_ready := false
var finishing := false
var smoke_left := 0.0


func setup(world: Node3D, host: Node) -> void:
	game = world
	campaign = host
	for point: Array in game.river.meta.streets[STREET]:
		street.append(Vector2(point[0], point[1]))
	# The first 22 m from Hillcrest have sidewalks. Continue along both verges.
	npc = Model.new()
	npc.name = "RoachReaper"
	add_child(npc)
	npc.set_smoke_mesh(game.cabin.mist_mesh)
	place(npc, 15.0, 5.4)
	npc.rotation.y = atan2(street[1].x - street[0].x, street[1].y - street[0].y)
	npc.hide()
	var spots := [Vector2(8, 3.0), Vector2(12, -3.7), Vector2(19, 4.6), Vector2(22, -5.25),
		Vector2(27, 5.0), Vector2(34, -4.8), Vector2(43, 3.6), Vector2(53, -5.0),
		Vector2(64, 4.5), Vector2(77, -4.5)]
	for spot: Vector2 in spots:
		var pickup := Node3D.new()
		add_child(pickup)
		place(pickup, spot.x, spot.y)
		Model.build_roach(pickup, false).rotation.z = PI * .5 + spot.y * .15
		pickup.hide()
		pickups.append(pickup)


func place(node: Node3D, station: float, lateral: float) -> void:
	var axis := street[0].direction_to(street[1])
	var point := street[0] + axis * station + axis.orthogonal() * lateral
	node.position = Vector3(point.x, game.river.ground_height(point.x, point.y), point.y)


func snap_to_surface(node: Node3D) -> void:
	var at := node.global_position
	var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.5, at - Vector3.UP * 1.5)
	ray.exclude = [game.player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		node.global_position.y = hit.position.y + .022


func on_street(at: Vector3) -> bool:
	var point := Vector2(at.x, at.z)
	for index in street.size() - 1:
		var closest := Geometry2D.get_closest_point_to_segment(point, street[index], street[index + 1])
		if point.distance_squared_to(closest) <= 6.0 * 6.0:
			return true
	return false


func state(peer: int) -> Dictionary:
	return campaign.progression_for(peer).get(ID, {})


func minutes_left(quest: Dictionary) -> int:
	return maxi(0, ceili(float(quest.get("deadline", 0.0)) - campaign.ledger.state.work_minutes))


func status_text(quest: Dictionary) -> String:
	if quest.get("failed", false):
		return "Failed · Time expired"
	match Chain.status(quest, QUESTS):
		Chain.Status.FINISHED: return "Completed"
		Chain.Status.AVAILABLE: return "Rare quest"
	var left := minutes_left(quest)
	return "%d / %d · %dh %02dm left" % [int(quest.progress), TARGET, floori(left / 60.0), left % 60]


func expired(quest: Dictionary) -> bool:
	if quest.get("accepted", false) and not quest.get("failed", false) and minutes_left(quest) == 0:
		quest.failed = true
		quest.accepted = false
		quest.progress = 0.0
		quest.picked = []
		return true
	return false


func tick(delta: float) -> void:
	if not surfaces_ready:
		surfaces_ready = true
		snap_to_surface(npc)
		for pickup in pickups:
			snap_to_surface(pickup)
	var peer: int = campaign.crew.my_id()
	if not campaign.crew.is_guest():
		var modified := observe(peer)
		if campaign.crew.on_server():
			for guest: int in campaign.crew.people:
				if guest != peer:
					modified = observe(guest) or modified
		if modified:
			campaign.changed()
	var quest := state(peer)
	var active: bool = quest.get("accepted", false)
	var ended: bool = quest.get("failed", false) or Chain.status(quest, QUESTS) == Chain.Status.FINISHED
	if not ended:
		smoke_left = 0.0
	if finishing and not game.story_offer.visible:
		finishing = false
		smoke_left = SMOKING_SECONDS
	npc.visible = (not quest.is_empty() and not ended) or finishing or smoke_left > 0.0
	if npc.visible:
		npc.animate(game.clock, SMOKING_SECONDS - smoke_left if smoke_left > 0.0 else -1.0)
	smoke_left = maxf(0.0, smoke_left - delta)
	var picked: Array = quest.get("picked", [])
	for index in pickups.size():
		pickups[index].visible = active and str(index) not in picked
	game.backpack.set_quest_items(int(quest.get("progress", 0)))
	game.notebook.set_side_quest(quest, status_text(quest))
	if game.story_offer.visible and game.story_offer.npc_id == ID:
		var line: String = status_text(quest)
		game.story_offer.progress.text = line


func observe(peer: int) -> bool:
	var quest := state(peer)
	if not quest.is_empty():
		return expired(quest)
	var person := walker(peer)
	if person.is_empty():
		inside.erase(peer)
		return false
	var on_silvie := on_street(person.at) and absf(person.at.y - game.river.ground_height(person.at.x, person.at.z)) < 3.0
	var entered: bool = on_silvie and not inside.get(peer, false)
	inside[peer] = on_silvie
	if entered and person.get("high", false):
		var profile: Dictionary = campaign.progression_for(peer)
		if not profile.is_empty():
			profile[ID] = {"step": 0, "progress": 0, "accepted": false, "picked": []}
			return true
	return false


func walker(peer: int) -> Dictionary:
	if peer == campaign.crew.my_id():
		if game.can_talk_to_shannon() and not game.in_aircraft():
			return {"at": game.player.global_position, "high": game.cabin.high_until > game.cabin.clock}
		return {}
	var sample: Dictionary = campaign.crew.poses.get(peer, {})
	if sample.is_empty() or sample.onboard or Time.get_ticks_msec() - int(sample.received) > 1000:
		return {}
	if sample.animation.get("roach_on_foot", false):
		return {"at": sample.at, "high": sample.animation.get("cabin_high", false)}
	return {}


func perform(peer: int, value: Variant) -> void:
	if not value is Array or value.size() != 2 or not value[0] is String:
		return
	var quest := state(peer)
	if quest.is_empty() or quest.get("failed", false):
		return
	if expired(quest):
		campaign.changed()
		return
	var person := walker(peer)
	if person.is_empty():
		return
	match value[0]:
		"pickup":
			var index: Variant = value[1]
			if not index is int or index < 0 or index >= pickups.size() or str(index) in quest.picked:
				return
			if Vector3(person.at).distance_to(pickups[index].global_position) > 2.8:
				return
			if not Chain.credit(quest, QUESTS, ID, 1):
				return
			quest.picked.append(str(index))
		"accept", "complete":
			if value[1] != ID or Vector3(person.at).distance_to(npc.global_position) > 3.0:
				return
			if value[0] == "accept":
				if not Chain.accept(quest, QUESTS, ID):
					return
				quest.deadline = campaign.ledger.state.work_minutes + DEADLINE_MINUTES
			else:
				if not Chain.complete(quest, QUESTS, ID):
					return
				quest.picked = []
				XP.award(campaign.progression_for(peer), ID, ID)
		_:
			return
	campaign.changed()


func focus() -> int:
	if not game.can_talk_to_shannon() or game.in_aircraft():
		return -2
	var best := 1.0
	var selected := -2
	if npc.visible and not finishing and smoke_left <= 0.0:
		best = minf(1.0, game.cabin.sight(npc.global_position + Vector3.UP * .63, .67, 2.9))
		if best < 1.0:
			selected = -1
	for index in pickups.size():
		if pickups[index].visible:
			var score: float = game.cabin.sight(pickups[index].global_position + Vector3.UP * .04, .22, 2.75)
			if score < best:
				best = score
				selected = index
	return selected


func prompt() -> String:
	var target := focus()
	if target == -1:
		return "E · Talk to Roach Reaper"
	return "E · Pick up discarded joint roach" if target >= 0 else ""


func interact() -> bool:
	var target := focus()
	if target == -2:
		return false
	if target == -1:
		game.open_reaper_offer()
	else:
		campaign.request(ID, ["pickup", target])
	return true


func offer() -> Dictionary:
	var quest := state(campaign.crew.my_id())
	var data := {"npc": ID, "id": ID, "name": NPC, "title": TITLE, "status": status_text(quest),
		"description": INTRO, "objectives": OBJECTIVE,
		"rewards": "Rare · %d XP" % XP.REWARDS[ID]}
	if quest.get("failed", false):
		data.description = "Phone's dead. The census is officially closed."
		return data
	match Chain.status(quest, QUESTS):
		Chain.Status.AVAILABLE:
			data.merge({"action": "accept", "button": "Accept Quest"})
		Chain.Status.IN_PROGRESS:
			data.description = "Check the curb and both verges. The good ones always roll just out of reach."
		Chain.Status.READY:
			data.merge({"action": "complete", "button": "Hand over roaches"})
		Chain.Status.FINISHED:
			finishing = true
			data.description = THANKS
			data.objectives = ""
			data.rewards = ""
	return data
