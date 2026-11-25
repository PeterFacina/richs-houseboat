extends CanvasLayer

const Warehouse = preload("res://warehouse_property.gd")
const ThemeKit = preload("res://game_menu_theme.gd")
const FloorOverlay = preload("res://property_floor_overlay.gd")
const ACTION := "warehouse"
const RESULT := -40
const GRID_COLOR := Color("#25373e")
const EMPTY_COLOR := Color("#344950")
const READY_COLOR := Color("#537b53")
const SELECT_COLOR := Color("#83623d")
const BLOCKED_COLOR := Color("#8b5146")

var game: Node
var property: Node3D
var sites := {}
var title: Label
var grid: GridContainer
var move: Button
var moving := ""
var aiming := false
var aim_help: Label
var reticle := ColorRect.new()
var resume_aim: Button
var hud_before_build := true
var panel := PanelContainer.new()
var wallet: Label
var description: Label
var status: Label
var stock_label: Label
var cells: Array[Button] = []
var catalog := OptionButton.new()
var purchase: Button
var rotate: Button
var place: Button
var remove: Button
var batch: Button
var sell: Button
var layout_area: VBoxContainer
var selection := Vector2i(-1, -1)
var turned := false
var previous_mouse := Input.MOUSE_MODE_CAPTURED
var known_state: Dictionary
var last_minute := -1


func setup(game_world: Node) -> void:
	game = game_world
	layer = 8
	add_child(panel)
	panel.hide()
	build_panel()
	aim_help = ThemeKit.text("", 17, ThemeKit.PAPER, true)
	add_child(aim_help)
	aim_help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aim_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aim_help.add_theme_stylebox_override("normal", ThemeKit.box(ThemeKit.NAVY, ThemeKit.GOLD, 8, 12))
	aim_help.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	aim_help.grow_horizontal = Control.GROW_DIRECTION_BOTH
	aim_help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	aim_help.offset_bottom = -33
	add_child(reticle)
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reticle.color = ThemeKit.PAPER
	reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	reticle.offset_left = -2
	reticle.offset_top = -2
	reticle.offset_right = 2
	reticle.offset_bottom = 2
	reticle.hide()
	aim_help.hide()


func register_site(site: Node3D) -> void:
	if site.property_id.is_empty() or sites.has(site.property_id):
		return
	sites[site.property_id] = site
	site.overlay = FloorOverlay.new()
	site.add_child(site.overlay)
	site.overlay.setup(site, site.grid_size, Warehouse.CELL)
	site.sync(state_for(site))


func build_panel() -> void:
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	panel.offset_right = -16
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.theme = ThemeKit.get_theme()
	panel.add_theme_stylebox_override("panel", ThemeKit.box(ThemeKit.CREAM, ThemeKit.GOLD, 14, 20))
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 8)
	panel.add_child(contents)
	var header := HBoxContainer.new()
	contents.add_child(header)
	title = ThemeKit.text("", 25, ThemeKit.NAVY, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(action_button("Close [Esc]", close))
	wallet = ThemeKit.text("", 16, ThemeKit.MUTED)
	contents.add_child(wallet)
	resume_aim = action_button("Resume aiming [Tab]", func(): set_aiming(true); refresh(), &"MainAction")
	contents.add_child(resume_aim)
	description = ThemeKit.text("", 16)
	contents.add_child(description)
	purchase = action_button("Buy warehouse", func(): request("buy"), &"MainAction")
	contents.add_child(purchase)
	layout_area = VBoxContainer.new()
	layout_area.add_theme_constant_override("separation", 8)
	contents.add_child(layout_area)

	var tools_bar := HBoxContainer.new()
	layout_area.add_child(tools_bar)
	catalog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for type: String in Warehouse.GOODS:
		var item: Dictionary = Warehouse.GOODS[type]
		catalog.add_item("%s  /  $%d" % [item.name, item.cost])
		catalog.set_item_metadata(catalog.item_count - 1, type)
	catalog.item_selected.connect(func(_index: int): refresh())
	tools_bar.add_child(catalog)
	rotate = action_button("Rotate 90°", func(): turned = not turned; refresh())
	tools_bar.add_child(rotate)
	place = action_button("Buy & place", place_selected, &"MainAction")
	tools_bar.add_child(place)

	layout_area.add_child(ThemeKit.text("Back wall", 13, ThemeKit.MUTED, true))
	grid = GridContainer.new()
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	layout_area.add_child(grid)
	layout_area.add_child(ThemeKit.text("Front wall", 13, ThemeKit.MUTED, true))
	var bottom := HBoxContainer.new()
	layout_area.add_child(bottom)
	batch = action_button("", operate_batch, &"MainAction")
	bottom.add_child(batch)
	move = action_button("Move", start_move)
	bottom.add_child(move)
	remove = action_button("Remove", func(): request("remove", selected_item()))
	bottom.add_child(remove)
	stock_label = ThemeKit.text("", 15, ThemeKit.MUTED)
	stock_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(stock_label)
	sell = action_button("Sell stock", func(): request("sell", int(state().get("stock", 0))))
	bottom.add_child(sell)
	status = ThemeKit.text("", 15, ThemeKit.MUTED)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.x = 520
	contents.add_child(status)


func build_grid(size: Vector2i) -> void:
	for button in cells:
		grid.remove_child(button)
		button.queue_free()
	cells.clear()
	grid.columns = size.x
	for z in size.y:
		for x in size.x:
			var tile := Vector2i(x, z)
			var button := Button.new()
			button.custom_minimum_size = Vector2(34, 32)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.add_theme_font_size_override("font_size", 12)
			button.add_theme_color_override("font_color", ThemeKit.PAPER)
			button.add_theme_color_override("font_hover_color", ThemeKit.PAPER)
			button.add_theme_color_override("font_pressed_color", ThemeKit.PAPER)
			button.add_theme_color_override("font_focus_color", ThemeKit.PAPER)
			button.add_theme_stylebox_override("focus", ThemeKit.focus_box(4))
			button.pressed.connect(select_tile.bind(tile))
			cells.append(button)
			grid.add_child(button)


func action_button(text: String, callback: Callable, style: StringName = &"Button") -> Button:
	var button := ThemeKit.button(text, style, "", 38)
	button.pressed.connect(callback)
	return button


func state() -> Dictionary:
	if property == null:
		return {}
	return state_for(property)


func state_for(site: Node3D) -> Dictionary:
	return game.campaign.ledger.state.get("properties", {}).get(site.property_id, {})


func items() -> Dictionary:
	return state().get("items", {})


func catalog_type() -> String:
	return catalog.get_item_metadata(catalog.selected)


func selected_item() -> String:
	return Warehouse.item_at(items(), selection)


func available_money() -> int:
	return game.campaign.ledger.wallet_cents()


func can_use() -> bool:
	return not game.aboard() and not game.in_aircraft() and not game.flying and not game.swimming


func nearby_site() -> Node3D:
	if can_use():
		var at: Vector3 = game.player.global_position
		for site: Node3D in sites.values():
			var owned := bool(state_for(site).get("owned", false))
			if (owned and site.inside(at)) or (not owned and site.at_sale_post(at)):
				return site
	return null


func hint() -> String:
	var site := nearby_site()
	if site == null:
		return ""
	return ("E  Build Mode   ·   " if state_for(site).get("owned", false) else "E  View listing   ·   ") + site.property_name


func interact() -> bool:
	var site := nearby_site()
	if site == null:
		return false
	property = site
	title.text = property.property_name
	build_grid(property.grid_size)
	moving = ""
	game.release_line()
	game.sonar_overlay.hide()
	previous_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	selection = Vector2i(-1, -1)
	turned = false
	status.text = ""
	panel.show()
	if state().get("owned", false):
		hud_before_build = game.hud.visible
		game.hud.hide()
		property.overlay.enter()
		set_aiming(true)
	refresh()
	return true


func close() -> void:
	if panel.visible:
		if property.overlay.visible:
			game.hud.visible = hud_before_build
		catalog.get_popup().hide()
		set_aiming(false)
		panel.hide()
		property.overlay.leave()
		property = null
		Input.mouse_mode = previous_mouse


func select_tile(tile: Vector2i) -> void:
	selection = tile
	refresh()


func request(operation: String, value: Variant = null) -> void:
	if property != null:
		game.campaign.request(ACTION, [property.property_id, operation, value])


func set_aiming(enabled: bool) -> void:
	aiming = enabled and property != null and property.overlay.visible
	panel.modulate.a = 0.0 if aiming else 1.0
	aim_help.visible = aiming
	reticle.visible = aiming
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if aiming else Input.MOUSE_MODE_VISIBLE


func build_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		close()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_TAB \
			and property.overlay.visible and not catalog.get_popup().visible:
		set_aiming(not aiming)
		refresh()
	elif not aiming:
		return
	elif event is InputEventMouseMotion:
		game.yaw -= event.relative.x * game.mouse_sensitivity
		game.pitch = clampf(game.pitch - event.relative.y * game.mouse_sensitivity, -1.38, 1.38)
		game.update_view()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		turned = not turned
		refresh()
	elif event is InputEventMouseButton and event.pressed:
		update_aim()
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if not place.disabled:
					place_selected()
			MOUSE_BUTTON_RIGHT:
				if not selected_item().is_empty():
					set_aiming(false)
					refresh()
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if moving.is_empty():
					var step := 1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
					catalog.select(posmod(catalog.selected + step, catalog.item_count))
					refresh()
	get_viewport().set_input_as_handled()


func update_aim() -> void:
	var center := get_viewport().get_visible_rect().size * .5
	var tile: Vector2i = property.overlay.tile_under(center, property.grid_size, Warehouse.CELL)
	if not Rect2i(Vector2i.ZERO, property.grid_size).has_point(tile):
		tile = Vector2i(-1, -1)
	if tile != selection:
		select_tile(tile)


func start_move() -> void:
	if not moving.is_empty():
		moving = ""
	else:
		moving = selected_item()
		turned = bool(items()[moving].turned)
		selection = Vector2i(-1, -1)
	refresh()


func place_selected() -> void:
	if moving.is_empty():
		request("place", [catalog_type(), selection.x, selection.y, turned])
	else:
		var source := moving
		moving = ""
		request("move", [source, selection.x, selection.y, turned])
		refresh()


func report(message: String) -> void:
	if panel.visible:
		status.text = message
		refresh()
	else:
		game.notify_angling(message, 3.5)


func _process(_delta: float) -> void:
	var current: Dictionary = game.campaign.ledger.state.get("properties", {})
	var minute := floori(game.campaign.ledger.state.work_minutes)
	var changed := current != known_state
	if changed:
		for site: Node3D in sites.values():
			if current.get(site.property_id, {}) != known_state.get(site.property_id, {}):
				site.sync(state_for(site))
		known_state = current.duplicate(true)
	if not panel.visible:
		return
	var inside: bool = property.inside(game.player.global_position)
	var owned := bool(state().get("owned", false))
	if not can_use() or (property.overlay.visible and (not inside or not owned)) \
			or (not inside and not property.at_sale_post(game.player.global_position)):
		close()
	elif minute != last_minute or changed:
		last_minute = minute
		refresh()
	if aiming:
		update_aim()


func refresh() -> void:
	var owned: bool = state().get("owned", false)
	var inside: bool = property.inside(game.player.global_position)
	wallet.text = "Wallet  /  $%.2f available" % (available_money() / 100.0)
	purchase.visible = not owned
	purchase.text = "Buy warehouse  /  $%d" % property.price
	purchase.disabled = available_money() < property.price * 100
	layout_area.visible = owned and inside
	resume_aim.visible = layout_area.visible
	if not owned:
		description.text = "%d × %d build tiles for furniture, storage and production." % [grid.columns, property.grid_size.y]
		return
	if not inside:
		description.text = "Purchase complete. Press E inside to manage the property."
		return
	var props := items()
	if not props.has(moving):
		moving = ""
	var type: String = props[moving].type if not moving.is_empty() else catalog_type()
	var selected := selected_item()
	var item: Dictionary = props.get(selected, {})
	description.text = "Select a destination on the floor grid. Tab returns to aiming." if not moving.is_empty() else \
		(Warehouse.GOODS[type].description if item.is_empty() else Warehouse.GOODS[item.type].name)
	var area := Rect2i(selection, Warehouse.footprint(type, turned))
	var can_place := placement_clear(props, area, property.grid_size, moving) and \
		clear_of_player(property, area, game.player.global_position)
	place.text = "Place item" if not moving.is_empty() else "Buy & place"
	place.disabled = not can_place or (moving.is_empty() and available_money() < int(Warehouse.GOODS[type].cost) * 100)
	catalog.disabled = not moving.is_empty()
	move.visible = not moving.is_empty() or not item.is_empty()
	move.text = "Cancel move" if not moving.is_empty() else "Move"
	var marker := Warehouse.tile_bounds(item) if not item.is_empty() and moving.is_empty() else area
	property.overlay.mark(marker, can_place or (not item.is_empty() and moving.is_empty()), Warehouse.CELL)
	property.overlay.show_occupied(props)
	property.overlay.preview(type if item.is_empty() or not moving.is_empty() else "", area, turned, can_place)
	if aiming:
		var item_label: String = str(Warehouse.GOODS[type].name)
		if moving.is_empty():
			item_label += "  $%d" % Warehouse.GOODS[type].cost
		aim_help.text = item_label + "   |   Click Place   ·   R Rotate   ·   Scroll Select   ·   Tab Catalog   ·   Esc Exit"
		if not item.is_empty() and moving.is_empty():
			aim_help.text = str(Warehouse.GOODS[item.type].name) + "   |   Right-click Manage   ·   Tab Catalog   ·   Esc Exit"
	var stock := int(state().get("stock", 0))
	var capacity := Warehouse.capacity(props)
	var timer := float(item.get("ready_at", 0))
	var clock := float(game.campaign.ledger.state.work_minutes)
	var is_pot: bool = item.get("type") == "pot"
	batch.visible = is_pot and moving.is_empty()
	if is_pot:
		batch.text = "Start batch  /  $%d" % Warehouse.BATCH_COST
		batch.disabled = available_money() < Warehouse.BATCH_COST * 100
		if timer > 0:
			batch.text = "Harvest batch" if timer <= clock else "Growing  /  %d game min" % ceili(timer - clock)
			batch.disabled = timer > clock or stock + Warehouse.BATCH_YIELD > capacity
	remove.visible = not item.is_empty() and moving.is_empty()
	remove.disabled = timer > 0 or (item.get("type") == "rack" and stock > capacity - 6)
	remove.tooltip_text = "Remove without a refund."
	stock_label.text = "Stock  %d / %d" % [stock, capacity]
	sell.text = "Sell stock  /  $%d" % (stock * Warehouse.SALE_PRICE) if stock > 0 else "Sell stock"
	sell.disabled = stock == 0

	if aiming:
		return
	for i in cells.size():
		var tile := Vector2i(i % grid.columns, i / grid.columns)
		var id := Warehouse.item_at(props, tile)
		var tile_item: Dictionary = props.get(id, {})
		var is_selected := (id != "" and id == selected) or (selected == "" and area.has_point(tile))
		var color := EMPTY_COLOR if (tile.x + tile.y) % 2 == 0 else GRID_COLOR
		var finish := float(tile_item.get("ready_at", 0))
		if not tile_item.is_empty():
			color = READY_COLOR if finish > 0 and finish <= clock else Color("#49636a")
		if is_selected:
			color = SELECT_COLOR if can_place or not selected.is_empty() and moving.is_empty() else BLOCKED_COLOR
		var button := cells[i]
		button.text = ""
		button.tooltip_text = "Tile %d, %d" % [tile.x + 1, tile.y + 1]
		if not tile_item.is_empty():
			button.tooltip_text = Warehouse.GOODS[tile_item.type].name
			if tile == Warehouse.tile_bounds(tile_item).position:
				button.text = Warehouse.GOODS[tile_item.type].short
				if finish > 0:
					button.text = "Ready" if finish <= clock else "Grow"
		var rim := ThemeKit.GOLD if is_selected else color.lightened(.17)
		button.add_theme_stylebox_override("normal", ThemeKit.box(color, rim, 4, 2))
		button.add_theme_stylebox_override("hover", ThemeKit.box(color.lightened(.19), rim, 4, 2))
		button.add_theme_stylebox_override("pressed", ThemeKit.box(color.darkened(.12), rim, 4, 2))


func operate_batch() -> void:
	var id := selected_item()
	request("harvest" if float(items().get(id, {}).get("ready_at", 0)) > 0 else "start", id)


static func placement_clear(props: Dictionary, area: Rect2i, grid_size: Vector2i, ignore := "") -> bool:
	if not Rect2i(Vector2i.ZERO, grid_size).encloses(area):
		return false
	for key: String in props:
		if key != ignore and area.intersects(Warehouse.tile_bounds(props[key])):
			return false
	return true


static func clear_of_player(site: Node3D, area: Rect2i, player_at: Vector3) -> bool:
	return player_at.distance_squared_to(site.to_global(site.tile_center(area))) >= 2.4 * 2.4


func perform(peer: int, arguments: Variant) -> void:
	if not arguments is Array or arguments.size() != 3 or not arguments[0] is String or not arguments[1] is String:
		return
	var site: Node3D = sites.get(arguments[0])
	if site == null:
		return
	var campaign = game.campaign
	var person: Dictionary = campaign.actor(peer)
	if person.is_empty() or person.get("onboard", true):
		return
	var action: String = arguments[1]
	var value: Variant = arguments[2]
	var current := state_for(site).duplicate(true)
	var balance := available_money()
	if action == "buy":
		if current.get("owned", false) or not site.at_sale_post(person.at) or balance < site.price * 100:
			return
		commit(site, peer, {"owned": true, "items": {}, "stock": 0}, -site.price, "Warehouse purchased.")
		return
	if not current.get("owned", false) or not site.inside(person.at):
		return
	var props: Dictionary = current.items
	var stock := int(current.stock)
	match action:
		"place", "move":
			if not value is Array or value.size() != 4 or not value[0] is String \
					or not value[1] is int or not value[2] is int or not value[3] is bool:
				return
			var source: String = value[0] if action == "move" else ""
			if (action == "move" and not props.has(source)) or (action == "place" and not Warehouse.GOODS.has(value[0])):
				return
			if not Rect2i(Vector2i.ZERO, site.grid_size).has_point(Vector2i(value[1], value[2])):
				return
			var type: String = props[source].type if action == "move" else value[0]
			var area := Rect2i(Vector2i(value[1], value[2]), Warehouse.footprint(type, value[3]))
			var cost: int = Warehouse.GOODS[type].cost if action == "place" else 0
			if balance < cost * 100 or not placement_clear(props, area, site.grid_size, source):
				return
			var players: Array = campaign.crew.people.keys()
			if not players.has(campaign.crew.my_id()):
				players.append(campaign.crew.my_id())
			for player_id: int in players:
				var player_pose: Dictionary = campaign.actor(player_id)
				if not player_pose.is_empty() and not clear_of_player(site, area, player_pose.at):
					campaign.tell(peer, "Move clear of the selected tiles first.", RESULT)
					return
			var id := "%d,%d" % [value[1], value[2]]
			var stored: Dictionary = props.get(source, {"type": type})
			stored.merge({"x": value[1], "z": value[2], "turned": value[3]}, true)
			props.erase(source)
			props[id] = stored
			commit(site, peer, current, -cost, "%s placed." % Warehouse.GOODS[type].name)
		"remove", "start", "harvest":
			if not value is String or not props.has(value):
				return
			var item: Dictionary = props[value]
			var finish := float(item.get("ready_at", 0))
			match action:
				"remove":
					if finish > 0 or (item.type == "rack" and stock > Warehouse.capacity(props) - 6):
						return
					props.erase(value)
					commit(site, peer, current, 0, "Item removed.")
				"start":
					if item.type != "pot" or finish > 0 or balance < Warehouse.BATCH_COST * 100:
						return
					item.ready_at = float(campaign.ledger.state.work_minutes) + Warehouse.BATCH_MINUTES
					commit(site, peer, current, -Warehouse.BATCH_COST, "Batch started.")
				"harvest":
					if item.type != "pot" or finish <= 0 or finish > float(campaign.ledger.state.work_minutes) \
							or stock + Warehouse.BATCH_YIELD > Warehouse.capacity(props):
						return
					item.erase("ready_at")
					current.stock = stock + Warehouse.BATCH_YIELD
					commit(site, peer, current, 0, "Harvest moved to warehouse stock.")
		"sell":
			if not value is int or value != stock or stock <= 0:
				return
			current.stock = 0
			commit(site, peer, current, stock * Warehouse.SALE_PRICE, "Sold %d units to the local wholesaler." % stock)


func commit(site: Node3D, peer: int, current: Dictionary, cash: int, message: String) -> void:
	var campaign = game.campaign
	campaign.ledger.state.properties[site.property_id] = current
	campaign.ledger.set_wallet_cents(available_money() + cash * 100)
	campaign.changed()
	campaign.tell(peer, message, RESULT)
