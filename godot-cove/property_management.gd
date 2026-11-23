extends CanvasLayer

const Warehouse = preload("res://warehouse_property.gd")
const ThemeKit = preload("res://river_menu_theme.gd")
const ACTION := "warehouse"
const RESULT := -40
const GRID_COLOR := Color("#25373e")
const EMPTY_COLOR := Color("#344950")
const READY_COLOR := Color("#537b53")
const SELECT_COLOR := Color("#83623d")

var game: Node
var property: Node3D
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


func setup(fishing_game: Node) -> void:
	game = fishing_game
	layer = 8
	add_child(panel)
	panel.hide()


func register_site(site: Node3D) -> void:
	if property != null or site.property_id.is_empty():
		return
	property = site
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.theme = ThemeKit.get_theme()
	panel.add_theme_stylebox_override("panel", ThemeKit.box(ThemeKit.CREAM, ThemeKit.GOLD, 14, 20))
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 8)
	panel.add_child(contents)
	var header := HBoxContainer.new()
	contents.add_child(header)
	var title := ThemeKit.text(property.property_name, 29, ThemeKit.NAVY, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(action_button("Close [Esc]", close))
	wallet = ThemeKit.text("", 16, ThemeKit.MUTED)
	contents.add_child(wallet)
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
	place = action_button("Buy & place", func(): request("place", [catalog_type(), selection.x, selection.y, turned]), &"MainAction")
	tools_bar.add_child(place)

	layout_area.add_child(ThemeKit.text("Back wall", 13, ThemeKit.MUTED, true))
	var grid := GridContainer.new()
	grid.columns = Warehouse.COLUMNS
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	layout_area.add_child(grid)
	for z in Warehouse.ROWS:
		for x in Warehouse.COLUMNS:
			var tile := Vector2i(x, z)
			var button := Button.new()
			button.custom_minimum_size = Vector2(47, 35)
			button.add_theme_font_size_override("font_size", 12)
			button.add_theme_color_override("font_color", ThemeKit.PAPER)
			button.add_theme_color_override("font_hover_color", ThemeKit.PAPER)
			button.add_theme_color_override("font_pressed_color", ThemeKit.PAPER)
			button.add_theme_color_override("font_focus_color", ThemeKit.PAPER)
			button.add_theme_stylebox_override("focus", ThemeKit.focus_box(4))
			button.pressed.connect(select_tile.bind(tile))
			cells.append(button)
			grid.add_child(button)
	var front := ThemeKit.text("Front wall", 13, ThemeKit.MUTED, true)
	layout_area.add_child(front)
	var bottom := HBoxContainer.new()
	layout_area.add_child(bottom)
	batch = action_button("", operate_batch, &"MainAction")
	bottom.add_child(batch)
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
	status.custom_minimum_size.x = 550
	contents.add_child(status)
	panel.hide()


func action_button(text: String, callback: Callable, style: StringName = &"Button") -> Button:
	var button := ThemeKit.button(text, style, "", 38)
	button.pressed.connect(callback)
	return button


func state() -> Dictionary:
	if property == null:
		return {}
	return game.campaign.ledger.state.get("properties", {}).get(property.property_id, {})


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


func hint() -> String:
	if property == null or not can_use():
		return ""
	if state().get("owned", false):
		return "E  Manage " + property.property_name if property.inside(game.player.global_position) else ""
	return "E  View " + property.property_name if property.at_sale_post(game.player.global_position) else ""


func interact() -> bool:
	if hint().is_empty():
		return false
	game.release_line()
	game.sonar_overlay.hide()
	previous_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	selection = Vector2i(-1, -1)
	turned = false
	status.text = ""
	panel.show()
	refresh()
	return true


func close() -> void:
	if panel.visible:
		panel.hide()
		Input.mouse_mode = previous_mouse


func select_tile(tile: Vector2i) -> void:
	selection = tile
	refresh()


func request(operation: String, value: Variant = null) -> void:
	game.campaign.request(ACTION, [operation, value])


func report(message: String) -> void:
	if panel.visible:
		status.text = message
		refresh()
	else:
		game.notify_angling(message, 3.5)


func _process(_delta: float) -> void:
	if property == null:
		return
	var current := state()
	var minute := floori(game.campaign.ledger.state.work_minutes)
	var changed := current != known_state
	if changed:
		known_state = current.duplicate(true)
		property.sync(current)
	if panel.visible and (minute != last_minute or not can_use() or changed):
		last_minute = minute
		if not can_use() or (not property.inside(game.player.global_position) and not property.at_sale_post(game.player.global_position)):
			close()
		else:
			refresh()


func refresh() -> void:
	var owned: bool = state().get("owned", false)
	var inside: bool = property.inside(game.player.global_position)
	wallet.text = "Wallet  /  $%.2f available" % (available_money() / 100.0)
	purchase.visible = not owned
	purchase.text = "Buy warehouse  /  $%d" % property.price
	purchase.disabled = available_money() < property.price * 100
	layout_area.visible = owned and inside
	if not owned:
		description.text = "Space for storage, furniture and production."
		return
	if not inside:
		description.text = "Purchase complete. Press E inside to manage the property."
		return
	var props := items()
	var type := catalog_type()
	var selected := selected_item()
	var item: Dictionary = props.get(selected, {})
	description.text = Warehouse.GOODS[type].description if item.is_empty() else Warehouse.GOODS[item.type].name
	var area := Rect2i(selection, Warehouse.footprint(type, turned))
	var can_place := placement_clear(props, area)
	place.disabled = not can_place or available_money() < int(Warehouse.GOODS[type].cost) * 100
	var stock := int(state().get("stock", 0))
	var capacity := Warehouse.capacity(props)
	var timer := float(item.get("ready_at", 0))
	var clock := float(game.campaign.ledger.state.work_minutes)
	var is_pot: bool = item.get("type") == "pot"
	batch.visible = is_pot
	if is_pot:
		batch.text = "Start batch  /  $%d" % Warehouse.BATCH_COST
		batch.disabled = available_money() < Warehouse.BATCH_COST * 100
		if timer > 0:
			batch.text = "Harvest batch" if timer <= clock else "Growing  /  %d game min" % ceili(timer - clock)
			batch.disabled = timer > clock or stock + Warehouse.BATCH_YIELD > capacity
	remove.visible = not item.is_empty()
	remove.disabled = timer > 0 or (item.get("type") == "rack" and stock > capacity - 6)
	remove.tooltip_text = "Remove without a refund."
	stock_label.text = "Stock  %d / %d" % [stock, capacity]
	sell.text = "Sell stock  /  $%d" % (stock * Warehouse.SALE_PRICE) if stock > 0 else "Sell stock"
	sell.disabled = stock == 0

	for i in cells.size():
		var tile := Vector2i(i % Warehouse.COLUMNS, i / Warehouse.COLUMNS)
		var id := Warehouse.item_at(props, tile)
		var tile_item: Dictionary = props.get(id, {})
		var is_selected := (id != "" and id == selected) or (selected == "" and area.has_point(tile))
		var color := EMPTY_COLOR if (tile.x + tile.y) % 2 == 0 else GRID_COLOR
		var finish := float(tile_item.get("ready_at", 0))
		if not tile_item.is_empty():
			color = READY_COLOR if finish > 0 and finish <= clock else Color("#49636a")
		if is_selected:
			color = SELECT_COLOR
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


static func placement_clear(props: Dictionary, area: Rect2i) -> bool:
	if not Rect2i(0, 0, Warehouse.COLUMNS, Warehouse.ROWS).encloses(area):
		return false
	for item: Dictionary in props.values():
		if area.intersects(Warehouse.tile_bounds(item)):
			return false
	return true


func perform(peer: int, arguments: Variant) -> void:
	if property == null or not arguments is Array or arguments.size() != 2 or not arguments[0] is String:
		return
	var campaign = game.campaign
	var person: Dictionary = campaign.actor(peer)
	if person.is_empty() or person.get("onboard", true):
		return
	var action: String = arguments[0]
	var value: Variant = arguments[1]
	var current := state().duplicate(true)
	var balance := available_money()
	if action == "buy":
		if current.get("owned", false) or not property.at_sale_post(person.at) or balance < property.price * 100:
			return
		commit(peer, {"owned": true, "items": {}, "stock": 0}, -property.price, "Warehouse purchased.")
		return
	if not current.get("owned", false) or not property.inside(person.at):
		return
	var props: Dictionary = current.items
	var stock := int(current.stock)
	match action:
		"place":
			if not value is Array or value.size() != 4 or not value[0] is String or not Warehouse.GOODS.has(value[0]) \
					or not value[1] is int or not value[2] is int or not value[3] is bool:
				return
			if not Rect2i(0, 0, Warehouse.COLUMNS, Warehouse.ROWS).has_point(Vector2i(value[1], value[2])):
				return
			var type: String = value[0]
			var area := Rect2i(Vector2i(value[1], value[2]), Warehouse.footprint(type, value[3]))
			var cost: int = Warehouse.GOODS[type].cost
			if balance < cost * 100 or not placement_clear(props, area):
				return
			var at: Vector3 = property.to_global(Warehouse.tile_center(area))
			var players: Array = campaign.crew.people.keys()
			if not players.has(campaign.crew.my_id()):
				players.append(campaign.crew.my_id())
			for player_id: int in players:
				var player_pose: Dictionary = campaign.actor(player_id)
				if not player_pose.is_empty() and player_pose.at.distance_to(at) < 2.4:
					campaign.tell(peer, "Move clear of the selected tiles first.", RESULT)
					return
			var id := "%d,%d" % [value[1], value[2]]
			props[id] = {"type": type, "x": value[1], "z": value[2], "turned": value[3]}
			commit(peer, current, -cost, "%s placed." % Warehouse.GOODS[type].name)
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
					commit(peer, current, 0, "Item removed.")
				"start":
					if item.type != "pot" or finish > 0 or balance < Warehouse.BATCH_COST * 100:
						return
					item.ready_at = float(campaign.ledger.state.work_minutes) + Warehouse.BATCH_MINUTES
					commit(peer, current, -Warehouse.BATCH_COST, "Batch started.")
				"harvest":
					if item.type != "pot" or finish <= 0 or finish > float(campaign.ledger.state.work_minutes) \
							or stock + Warehouse.BATCH_YIELD > Warehouse.capacity(props):
						return
					item.erase("ready_at")
					current.stock = stock + Warehouse.BATCH_YIELD
					commit(peer, current, 0, "Harvest moved to warehouse stock.")
		"sell":
			if not value is int or value != stock or stock <= 0:
				return
			current.stock = 0
			commit(peer, current, stock * Warehouse.SALE_PRICE, "Sold %d units to the local wholesaler." % stock)


func commit(peer: int, current: Dictionary, cash: int, message: String) -> void:
	var campaign = game.campaign
	campaign.ledger.state.properties[property.property_id] = current
	campaign.ledger.set_wallet_cents(available_money() + cash * 100)
	campaign.changed()
	campaign.tell(peer, message, RESULT)
