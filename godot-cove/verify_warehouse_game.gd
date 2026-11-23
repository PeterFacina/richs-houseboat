extends SceneTree

const Warehouse = preload("res://warehouse_property.gd")
const Ledger = preload("res://river_ledger.gd")

var failed := false


func _initialize() -> void:
	call_deferred("exercise")

func check(condition: bool, detail: String) -> void:
	if not condition:
		push_error(detail)
		failed = true

func exercise() -> void:
	if not "houseboat-warehouse-" in OS.get_user_data_dir().to_lower() or FileAccess.file_exists(Ledger.SAVE):
		quit(2)
		return
	var game = load("res://fishing.tscn").instantiate()
	root.add_child(game)
	var build = game.properties
	var ledger = game.campaign.ledger
	ledger.set_wallet_cents(100025)
	check(build.sites.size() == 4, "Expected four sites on the live map")
	var low = build.sites.walker_works
	var high = build.sites.mcanulty_freight
	check(low.price == 1200 and high.price == 8000 and low.grid_size.x < high.grid_size.x, "Incorrect property tiers")
	game.campaign.request(build.ACTION, [low.property_id, "buy", null])
	check(ledger.wallet_cents() == 100025 and ledger.state.properties.is_empty(), "Remote purchase accepted")
	for site: Node3D in build.sites.values():
		check(not site.overlay.visible, "Grid leaked into gameplay")

	var warehouse := Warehouse.new()
	warehouse.property_id = "test_property"
	warehouse.property_name = "Property Test Fixture"
	warehouse.price = 350
	warehouse.floor_bounds = Rect2(-16, -9, 32, 18)
	warehouse.sale_position = Vector3(18.5, 0, 7.2)
	game.add_child(warehouse)
	warehouse.position = Vector3(18500, 220, 13800)
	var entrance := Vector3(16, 0, 7.2)
	var lock_body := StaticBody3D.new()
	warehouse.add_child(lock_body)
	preload("res://scenery.gd").collider(lock_body, entrance + Vector3.UP, Vector3(.22, 2.2, 1.44))
	warehouse.ownership_changed.connect(func(owned: bool):
		lock_body.process_mode = Node.PROCESS_MODE_DISABLED if owned else Node.PROCESS_MODE_INHERIT)
	build.register_site(warehouse)
	game.boarded = false
	game.player.global_position = warehouse.to_global(warehouse.sale_position)
	game.player.reset_physics_interpolation()
	check(game.campaign.local_interact() and build.panel.visible, "Purchase prompt failed")
	check(not build.layout_area.visible and not warehouse.overlay.visible, "Premature access to build grid")
	check(not warehouse.last_owned, "Property should begin unowned")
	var door := entrance + Vector3.UP
	var door_path := PhysicsRayQueryParameters3D.create(warehouse.to_global(door + Vector3.RIGHT), warehouse.to_global(door + Vector3.LEFT))
	await physics_frame
	var space: PhysicsDirectSpaceState3D = warehouse.get_world_3d().direct_space_state
	var lock_hit := space.intersect_ray(door_path)
	check(lock_hit.get("collider") == lock_body, "Unowned doorway did not block entry")
	build.purchase.pressed.emit()
	check(build.state().owned and ledger.wallet_cents() == 65025, "Purchase or wallet failed")
	build.close()
	game.player.global_position = warehouse.to_global(Vector3(14.8, .15, 8.3))
	game.player.reset_physics_interpolation()
	check(game.campaign.local_interact() and build.layout_area.visible and warehouse.overlay.visible, "Build menu failed to open indoors")
	build.request("place", ["crate", -1, 0, false])
	check(build.items().is_empty(), "Out-of-bounds placement permitted")
	var rack := Vector2i(2, 1)
	build.select_tile(rack)
	build.rotate.pressed.emit()
	build.place.pressed.emit()
	check(build.items()["2,1"].turned and Warehouse.capacity(build.items()) == 12, "Rotated rack or capacity failed")
	build.request("place", ["crate", 2, 2, false])
	check(build.items().size() == 1, "Overlap permitted")
	build.request("place", ["pot", 5, 2, false])
	build.select_tile(Vector2i(5, 2))
	build.batch.pressed.emit()
	build.request("harvest", "5,2")
	check(int(build.state().stock) == 0, "Early harvest permitted")
	ledger.state.work_minutes += Warehouse.BATCH_MINUTES + 1
	build.batch.pressed.emit()
	check(int(build.state().stock) == 3, "Harvest failed")
	build.sell.pressed.emit()
	check(int(build.state().stock) == 0 and ledger.wallet_cents() == 62125, "Sale or wallet failed")
	build.request("start", "5,2")
	var deadline: float = build.items()["5,2"].ready_at
	build.request("move", ["5,2", 6, 2, false])
	check(not build.items().has("5,2") and float(build.items()["6,2"].ready_at) == deadline
		and ledger.wallet_cents() == 61325, "Moving an active planter changed its batch or wallet")
	var loaded := Ledger.new()
	loaded.load_file()
	check(loaded.state.properties == JSON.parse_string(JSON.stringify(ledger.state.properties)), "Property or batch did not persist")
	check(loaded.wallet_cents() == 61325, "Wallet cents did not persist")
	await process_frame
	await process_frame
	check(warehouse.rendered_items.size() == 2 and warehouse.last_owned, "World props or door failed to update")
	await physics_frame
	check(space.intersect_ray(door_path).is_empty(), "Purchased doorway is physically blocked")
	build.close()
	check(not warehouse.overlay.visible, "Closing the build menu left the grid visible")

	ledger.set_wallet_cents(1000000)
	game.player.global_position = low.to_global(low.sale_position)
	game.player.reset_physics_interpolation()
	check(game.campaign.local_interact() and build.cells.size() == 16, "Starter listing grid size did not match")
	game.campaign.request(build.ACTION, [high.property_id, "buy", null])
	check(not build.state_for(high).get("owned", false), "Cross-site purchase accepted")
	build.purchase.pressed.emit()
	check(build.state_for(low).get("owned", false) and ledger.wallet_cents() == 880000,
		"Live $1200 listing was not independently purchased")
	check(not build.layout_area.visible and not low.overlay.visible, "Purchase exposed Build Mode outdoors")
	build.close()
	check(build.hint().is_empty() and not build.interact(), "Owned property opened from the street")
	game.player.global_position = low.to_global(Vector3(0, .1, 0))
	game.player.reset_physics_interpolation()
	check(game.campaign.local_interact() and low.overlay.visible and build.aiming and game.eye.current,
		"Live property did not enter first-person Build Mode")
	var world_tile: Vector3 = low.to_global(low.tile_center(Rect2i(0, 0, 1, 1)))
	game.eye.look_at(world_tile)
	var cursor: Vector2 = game.eye.unproject_position(world_tile)
	check(low.overlay.tile_under(cursor, low.grid_size, Warehouse.CELL) == Vector2i(0, 0), "Floor picking did not snap")
	var rotate := InputEventKey.new()
	rotate.physical_keycode = KEY_R
	rotate.pressed = true
	build.build_input(rotate)
	check(build.turned, "First-person rotate shortcut did not work")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	build.build_input(click)
	check(build.items().has("0,0") and ledger.wallet_cents() == 876000, "First-person placement click failed")
	build.request("remove", "0,0")
	build.close()
	check(not low.overlay.visible and not build.aiming and game.eye.current, "Build Mode did not restore controls")
	await physics_frame
	for site: Node3D in game.river.property_sites:
		check(not site.find_children("*", "SpotLight3D", true, false).is_empty(), "Missing interior fixtures at " + site.property_name)
		for x in site.grid_size.x:
			for z in site.grid_size.y:
				var tile_at: Vector3 = site.to_global(site.tile_center(Rect2i(x, z, 1, 1)))
				var floor_ray := PhysicsRayQueryParameters3D.create(tile_at + Vector3.UP, tile_at - Vector3.UP)
				floor_ray.exclude = [game.player.get_rid()]
				var floor_hit := space.intersect_ray(floor_ray)
				check(not floor_hit.is_empty() and site.is_ancestor_of(floor_hit.collider)
					and absf(floor_hit.position.y - tile_at.y) < .015, "Clipped or missing floor at " + site.property_name)
		var ceiling_ray := PhysicsRayQueryParameters3D.create(site.to_global(Vector3.UP), site.to_global(Vector3.UP * 10))
		ceiling_ray.exclude = [game.player.get_rid()]
		var ceiling_hit := space.intersect_ray(ceiling_ray)
		check(not ceiling_hit.is_empty() and site.is_ancestor_of(ceiling_hit.collider), "Missing solid ceiling at " + site.property_name)
		var wall_ray := PhysicsRayQueryParameters3D.create(site.to_global(Vector3(0, 1.2, 0)),
			site.to_global(Vector3(site.floor_bounds.end.x + 1, 1.2, 0)))
		wall_ray.exclude = [game.player.get_rid()]
		var wall_hit := space.intersect_ray(wall_ray)
		check(not wall_hit.is_empty() and site.is_ancestor_of(wall_hit.collider), "Missing solid wall at " + site.property_name)
	for kind in ["tree_detail", "tree_silhouette", "tree_stem", "regional_crown", "regional_trunk"]:
		for batch in get_nodes_in_group("river_graphics_" + kind):
			if not batch is MultiMeshInstance3D or not game.river.is_ancestor_of(batch):
				continue
			var aabb: AABB = batch.global_transform * batch.get_aabb()
			for site: Node3D in game.river.property_sites:
				if not aabb.grow(40).has_point(site.global_position):
					continue
				for i in batch.multimesh.instance_count:
					var pose: Transform3D = batch.multimesh.get_instance_transform(i)
					if pose.basis.x.is_zero_approx() and pose.basis.y.is_zero_approx() and pose.basis.z.is_zero_approx():
						continue
					var at := site.to_local(batch.to_global(pose.origin))
					check(not site.floor_bounds.has_point(Vector2(at.x, at.z)), "Tree inside " + site.property_name)
	print("Warehouse purchase, placement, collision, production, sale and save passed: ", not failed)
	quit(1 if failed else 0)
