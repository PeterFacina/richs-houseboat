extends Node3D

const Props = preload("res://cabin_props.gd")
const ACTION := "dab_pen"
const REACH := 2.6

var game: Node3D
var campaign: Node
var shelf: Node3D
var dropped: Node3D
var focused := false


func setup(world: Node3D) -> void:
	game = world
	campaign = world.campaign
	shelf = world.cabin.supplies[Props.Item.PEN]
	dropped = Props.make(self, Props.Item.PEN, Vector3.ZERO)
	dropped.rotation.x = PI * .5
	refresh()


func snapshot_for(peer: int) -> Dictionary:
	var saved: Dictionary = campaign.ledger.state.dab_pen
	var result := saved.duplicate()
	result.erase("owner")
	result.owned = owns(peer)
	return result


func owns(peer: int) -> bool:
	var saved: Dictionary = campaign.ledger.state.dab_pen
	if campaign.crew.is_guest():
		return bool(saved.get("owned", false))
	var owner := str(saved.get("owner", ""))
	return not owner.is_empty() and owner == campaign.profile_key(peer)


func space() -> String:
	return str(campaign.ledger.state.dab_pen.get("space", "shelf"))


func craft_for_space(where: String) -> Node3D:
	match where:
		"houseboat": return campaign.houseboat
		"skiff": return campaign.skiff
		"princecraft": return campaign.princecraft
	return null


func refresh() -> void:
	var where := space()
	var craft := craft_for_space(where)
	shelf.visible = where == "shelf"
	dropped.visible = where == "world" or (is_instance_valid(craft) and craft == game.vessel and craft.is_visible_in_tree())
	if dropped.visible:
		var coords: Variant = campaign.ledger.state.dab_pen.get("at")
		dropped.visible = coords is Array and coords.size() == 3
		if dropped.visible:
			var at := Vector3(float(coords[0]), float(coords[1]), float(coords[2]))
			var parent := craft if is_instance_valid(craft) else self
			if dropped.get_parent() != parent:
				dropped.reparent(parent, false)
			dropped.position = at
	game.backpack.set_pen_owned(owns(campaign.crew.my_id()))


func pickup_point() -> Vector3:
	if shelf.is_visible_in_tree() and game.vessel == campaign.houseboat:
		return shelf.global_position + shelf.global_basis.y * .062
	if dropped.visible:
		return dropped.global_position + dropped.global_basis.y * .062
	return Vector3.INF


func update_focus(available: bool) -> void:
	refresh()
	focused = false
	if not available or (space() == "shelf" and not game.aboard()):
		return
	var at := pickup_point()
	if at.is_finite() and game.cabin.sight(at, .15, REACH) < 1.0:
		focused = clear_path(game.eye.global_position, at)


func clear_path(from: Vector3, at: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(from, at, 1, [game.player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func request(verb: String) -> void:
	campaign.request(ACTION, [verb, int(campaign.ledger.state.dab_pen.get("serial", 0))])


func perform(peer: int, value: Variant, person: Dictionary) -> void:
	var state: Dictionary = campaign.ledger.state
	var serial := int(state.dab_pen.get("serial", 0))
	if value is not Array or value.size() != 2 or value[1] is not int or value[1] != serial:
		return
	var owner: String = campaign.profile_key(peer)
	if owner.is_empty() or campaign.captain == peer:
		return
	refresh()
	match value[0]:
		"pickup":
			if space() == "carried" or (space() == "shelf" and not person.onboard):
				return
			var at := pickup_point()
			var eyes: Vector3 = game.eye.global_position if peer == campaign.crew.my_id() \
				else Vector3(person.at) + Vector3.UP * (1.58 - float(person.eye_drop))
			if not at.is_finite() or eyes.distance_squared_to(at) > REACH * REACH or not clear_path(eyes, at):
				return
			if peer != campaign.crew.my_id():
				var look := -Basis.from_euler(Vector3(float(person.pitch), float(person.yaw), 0)).z
				if look.dot(eyes.direction_to(at)) < .75:
					return
			state.dab_pen = {"space": "carried", "owner": owner, "serial": serial + 1}
		"drop":
			if not owns(peer):
				return
			var at := drop_point(person)
			if not at.is_finite():
				campaign.tell(peer, "Stand on a clear surface to drop the dab pen.")
				return
			var where := "world"
			if person.onboard:
				where = str(state.craft)
				at = game.vessel.to_local(at)
			state.dab_pen = {"space": where, "at": [at.x, at.y, at.z], "serial": serial + 1}
		_:
			return
	refresh()
	campaign.changed()


func drop_point(person: Dictionary) -> Vector3:
	var feet: Vector3 = person.at
	var ray := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * .30,
		feet - Vector3.UP * .52, 1, [game.player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or Vector3(hit.normal).y < .7:
		return Vector3.INF
	if person.onboard and hit.collider != game.vessel:
		return Vector3.INF
	return Vector3(hit.position) + Vector3.UP * .025
