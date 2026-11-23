extends "res://marina_fuel_model.gd"

const LITRES_PER_SECOND := 1.65
const FILLER_REACH := 2.6

var game: Node3D
var campaign: Node3D
var pump_number := 0
var holder := 0
var connected := false
var flowing := false
var litres := 0.0
var cost_cents := 0
var end_count := 0
var trigger_down := false
var trigger_age := 0.0
var cutoff := false
var cents_pending := 0.0
var saved_cost := 0
var save_elapsed := 0.0
var local_trigger := false
var keepalive := 0.0
var nozzle_pose := Transform3D.IDENTITY


func bind(fishing: Node3D, river_campaign: Node3D) -> void:
	game = fishing
	campaign = river_campaign


func is_local_holder() -> bool:
	return holder != 0 and holder == campaign.crew.my_id()


func filler() -> Marker3D:
	return game.vessel.fuel_filler


func filler_available() -> bool:
	var port := filler()
	return port != null and absf(game.vessel.speed) < .65 and absf(game.vessel.throttle) < .04 \
		and port.global_position.distance_to(to_global(REEL)) <= HOSE_REACH


func hint() -> String:
	var at_rack: bool = campaign.aiming(to_global(RACK), 2.55, .93)
	if holder == 0:
		return "E  Pick up Pump %d nozzle  ·  $%.2f/L" % [pump_number, PRICE_CENTS / 100.0] if at_rack else ""
	if not is_local_holder():
		return "Pump %d in use" % pump_number if at_rack else ""
	var tank := "%.2f / %.0f L   ·   $%.2f in wallet" % [
		campaign.ledger.state.fuel, campaign.ledger.FUEL_CAPACITY, campaign.ledger.wallet_cents() / 100.0]
	if connected:
		return "Hold left mouse to fuel   ·   E  Disconnect   ·   " + tank
	if at_rack:
		return "E  Return nozzle to Pump %d" % pump_number
	if filler_available() and campaign.aiming(filler().global_position, FILLER_REACH, .96):
		if campaign.marina_fuel.filler_in_use():
			return "Fuel filler in use"
		return "E  Insert fuel nozzle   ·   " + tank
	return "Aim at filler and press E   ·   Hold left mouse to spray   ·   E at Pump %d to return" % pump_number


func interact() -> bool:
	if is_local_holder():
		if connected:
			campaign.request("fuel_nozzle", [pump_number, "disconnect"])
		elif campaign.aiming(to_global(RACK), 2.55, .93):
			campaign.request("fuel_nozzle", [pump_number, "return"])
		elif filler_available() and campaign.aiming(filler().global_position, FILLER_REACH, .96):
			campaign.request("fuel_nozzle", [pump_number, "insert"])
		else:
			return false
		return true
	if holder == 0 and campaign.aiming(to_global(RACK), 2.55, .93):
		game.stow_for_fueling()
		campaign.request("fuel_nozzle", [pump_number, "pickup"])
		return true
	return false


func actor_eye(person: Dictionary) -> Vector3:
	return person.at + Vector3.UP * 1.58


func action(peer: int, command: String, person: Dictionary) -> void:
	if person.is_empty() or campaign.captain == peer:
		return
	var eye_at := actor_eye(person)
	if command == "pickup" and holder == 0 and eye_at.distance_to(to_global(RACK)) <= 2.70:
		holder = peer
		litres = 0.0
		cost_cents = 0
		saved_cost = 0
		return
	if peer != holder:
		return
	match command:
		"return":
			if eye_at.distance_to(to_global(RACK)) <= 2.70:
				rack()
		"insert":
			if not connected and not trigger_down and filler_available() and eye_at.distance_to(filler().global_position) <= FILLER_REACH + .15:
				connected = true
		"disconnect":
			if connected:
				disconnect_filler()


func trigger(peer: int, held: bool) -> void:
	if peer != holder or holder == 0:
		return
	trigger_age = 0.0
	if not held:
		finish()
		cutoff = false
	trigger_down = held


func tick(delta: float, usable: bool) -> void:
	var local := is_local_holder()
	var pressed := local and usable and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	keepalive += delta
	if pressed != local_trigger or (pressed and keepalive >= .20):
		local_trigger = pressed
		keepalive = 0.0
		if local:
			campaign.request("fuel_trigger", [pump_number, pressed])
	if not campaign.crew.is_guest() and holder != 0:
		advance(delta)
	var pose := rack_pose()
	if holder != 0:
		if connected and filler() != null:
			pose = inserted_pose(filler())
		elif is_local_holder():
			pose = carried_pose(game.eye.global_transform)
		else:
			pose = nozzle_pose
	render_station(pose, is_local_holder() and not connected, flowing, flowing and not connected,
		litres, cost_cents, end_count)


func advance(delta: float) -> void:
	var person: Dictionary = campaign.actor(holder)
	if person.is_empty() or campaign.captain == holder or actor_eye(person).distance_to(to_global(REEL)) > HOSE_REACH + .40:
		rack()
		return
	var eye_at := actor_eye(person)
	if holder == campaign.crew.my_id():
		nozzle_pose = carried_pose(game.eye.global_transform)
	else:
		var view := Basis.from_euler(Vector3(person.get("pitch", 0.0), person.get("yaw", 0.0), 0.0))
		nozzle_pose = carried_pose(Transform3D(view, eye_at))
	if connected and (not filler_available() or eye_at.distance_to(filler().global_position) > FILLER_REACH + .25):
		disconnect_filler()
	if trigger_down:
		trigger_age += delta
		if trigger_age > .65:
			trigger(holder, false)
		elif not cutoff:
			dispense(delta)


func dispense(delta: float) -> void:
	var ledger = campaign.ledger
	var funds: int = ledger.wallet_cents()
	var room: float = maxf(0.0, ledger.FUEL_CAPACITY - ledger.state.fuel) if connected else INF
	if room <= .00001 or funds <= 0:
		cut_off("Tank full." if room <= .00001 else "Fuel pump stopped. Wallet empty.")
		return
	cents_pending += delta * LITRES_PER_SECOND * PRICE_CENTS
	var charge := mini(floori(cents_pending), ceili(minf(room * PRICE_CENTS - .000001, funds)))
	if charge <= 0:
		return
	cents_pending -= charge
	var delivered := minf(float(charge) / PRICE_CENTS, room)
	ledger.set_wallet_cents(funds - charge)
	if connected:
		ledger.state.fuel = minf(ledger.FUEL_CAPACITY, ledger.state.fuel + delivered)
	litres += delivered
	cost_cents += charge
	flowing = true
	if delivered >= room - .00001:
		cut_off("Tank full.")
	elif funds == charge:
		cut_off("Fuel pump stopped. Wallet empty.")
	else:
		save_elapsed += delta
		if save_elapsed >= 5.0:
			persist_sale()


func cut_off(message: String) -> void:
	cutoff = true
	finish()
	campaign.tell(holder, message)


func finish() -> void:
	if flowing:
		flowing = false
		end_count += 1
		persist_sale()
	cents_pending = 0.0


func persist_sale() -> void:
	if saved_cost != cost_cents:
		campaign.ledger.save_file()
		if campaign.ledger.error.is_empty():
			saved_cost = cost_cents
		else:
			campaign.tell(holder, campaign.ledger.error)
	save_elapsed = 0.0


func disconnect_filler() -> void:
	finish()
	connected = false
	cutoff = trigger_down


func rack() -> void:
	if trigger_down and not campaign.crew.is_guest():
		finish()
	holder = 0
	connected = false
	flowing = false
	trigger_down = false
	cutoff = false
	local_trigger = false


func packet() -> Array:
	return [holder, connected, flowing, litres, cost_cents, end_count, nozzle_pose]


func receive(data: Array, first: bool) -> void:
	if data.size() != 7:
		return
	holder = data[0]
	connected = data[1]
	flowing = data[2]
	litres = data[3]
	cost_cents = data[4]
	end_count = data[5]
	nozzle_pose = data[6]
	if first:
		heard_end = end_count
		heard_step = floori(litres * 4.0)
