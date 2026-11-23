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
	check(build.property == null and build.hint().is_empty() and not build.interact(), "Live game unexpectedly has a property listing")
	build.request("buy")
	check(ledger.wallet_cents() == 100025 and ledger.state.properties.is_empty(), "Unlisted property accepted a purchase")

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
	check(not build.layout_area.visible, "Premature access to build grid")
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
	check(game.campaign.local_interact() and build.layout_area.visible, "Build menu failed to open indoors")
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
	var loaded := Ledger.new()
	loaded.load_file()
	check(loaded.state.properties == JSON.parse_string(JSON.stringify(ledger.state.properties)), "Property or batch did not persist")
	check(loaded.wallet_cents() == 61325, "Wallet cents did not persist")
	await process_frame
	await process_frame
	check(warehouse.rendered_items.size() == 2 and warehouse.last_owned, "World props or door failed to update")
	await physics_frame
	check(space.intersect_ray(door_path).is_empty(), "Purchased doorway is physically blocked")
	print("Warehouse purchase, placement, collision, production, sale and save passed: ", not failed)
	quit(1 if failed else 0)
