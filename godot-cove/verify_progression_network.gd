extends SceneTree

const Crew = preload("res://river_crew.gd")
const Campaign = preload("res://river_campaign.gd")
const XP = preload("res://progression.gd")
var campaign: Campaign
var snapshots := {}

func _initialize() -> void:
	call_deferred("exercise")

func endpoint(id: String) -> Node:
	var group := Node.new()
	group.name = id
	root.add_child(group)
	var api := SceneMultiplayer.new()
	api.root_path = group.get_path()
	set_multiplayer(api, group.get_path())
	var crew := Crew.new()
	crew.name = "Crew"
	crew.local_profile = id.md5_text()
	crew.progression_secret = (id + "private").md5_text()
	group.add_child(crew)
	return crew

func until(check: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + 5000
	while not check.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	return check.call()

func handle(peer: int, action: String, value: Variant) -> void:
	var profile := campaign.progression_for(peer)
	if action == "connected":
		XP.award(profile, "delivery", "test_delivery")
	elif action == "purchase_skill":
		campaign.perform(peer, action, value)
		return
	campaign.crew.share_state.rpc_id(peer, campaign.snapshot_for(peer), 0, 0, 1)

func listen(client: Node, label: String) -> void:
	client.state_received.connect(func(state, _dock, _captain, _revision):
		snapshots[label] = state.progression)

func exercise() -> void:
	if not "houseboat-xp-" in OS.get_user_data_dir().to_lower():
		quit(2)
		return
	var game = load("res://fishing.tscn").instantiate()
	root.add_child(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	campaign = game.campaign
	var original_crew := campaign.crew
	var host := endpoint("Host")
	campaign.crew = host
	host.requested.connect(handle)
	host.host("Host")
	host.start_session()
	var one := endpoint("First")
	var two := endpoint("Second")
	listen(one, "one")
	listen(two, "two")
	one.join("First", "127.0.0.1")
	two.join("Second", "127.0.0.1")
	var passed := await until(func(): return snapshots.size() == 2)
	if passed:
		one.order.rpc_id(1, "purchase_skill", ["hard_worker", 0])
		one.order.rpc_id(1, "purchase_skill", ["hard_worker", 0])
		passed = await until(func(): return snapshots.one.self.get("ranks", {}).get("hard_worker", 0) == 1)
	if passed:
		passed = snapshots.one.size() == 1 and snapshots.two.self.xp == 100 and not snapshots.two.self.has("ranks") and not snapshots.one.self.has("events")
		one.stop()
		passed = passed and await until(func(): return host.people.size() == 2)
		snapshots.erase("one")
		one.join("First", "127.0.0.1")
		passed = passed and await until(func(): return snapshots.has("one"))
		if passed:
			passed = snapshots.one.self.xp == 100 and snapshots.one.self.ranks.hard_worker == 1
	print("ENet host, two guests, purchase isolation and reconnect: ", passed)
	campaign.crew = original_crew
	one.stop()
	two.stop()
	host.stop()
	game.free()
	quit(0 if passed else 1)
