extends RefCounted

# Plot centres and approach headings are in the Deep River map's metre grid.
const SITES := [
	{"name": "Marina Landing", "short": "Marina", "plot": Vector2(17939, 12642), "turn": 0, "pier": 34,
		"service": "Timber yard and public ferry", "color": Color("#e4ac6d"), "supply": "wood"},
	{"name": "Pine Reach", "short": "Pine Reach", "plot": Vector2(17122, 12038), "turn": 0, "pier": 34,
		"service": "Fishing camp and tackle exchange", "color": Color("#99c9a3"), "supply": "wood"},
	{"name": "Birch Point", "short": "Birch Point", "plot": Vector2(18812, 13122), "turn": 15, "pier": 34,
		"service": "Salvage yard and metal shop", "color": Color("#83cbd7"), "supply": "parts"},
	{"name": "Swisha Tailwater", "short": "Swisha", "plot": Vector2(2474, 3796), "turn": 0, "pier": 26,
		"service": "Hydro station and turbine parts", "color": Color("#e7c17b"), "supply": "parts"},
	{"name": "Chalk River Landing", "short": "Chalk River", "plot": Vector2(27540, 18706), "turn": 15, "pier": 44,
		"service": "Research launch and sonar parts", "color": Color("#a7b4e3"), "supply": "parts"},
]

const BUILDINGS := {
	"cabin": {"name": "Cedar cabin", "size": Vector2(5.8, 5.4), "wood": 16, "parts": 3,
		"detail": "An enclosed home with a working door, bunk, stove and windows."},
	"porch": {"name": "Covered porch", "size": Vector2(5.7, 2.0), "wood": 6, "parts": 0,
		"detail": "Snaps onto the cabin entrance. Adds outdoor seating."},
	"workshop": {"name": "Workshop", "size": Vector2(5.0, 4.0), "wood": 12, "parts": 5,
		"detail": "A workbench for fabricating onboard equipment and launching the skiff."},
	"boathouse": {"name": "Boathouse", "size": Vector2(4.5, 8.2), "wood": 14, "parts": 6,
		"detail": "A covered slip beside the landing. Refuel and recharge free at this dock."},
	"dock": {"name": "Fishing dock extension", "size": Vector2(2.6, 6.4), "wood": 7, "parts": 2,
		"detail": "Adds a walkable platform on the end of the public pier."},
	"turbine": {"name": "Current turbine", "size": Vector2(2.4, 2.4), "wood": 3, "parts": 10, "needs": "winch",
		"detail": "Makes electricity from the river and feeds the workshop and charger."},
	"drydock": {"name": "Dry dock", "size": Vector2(5.1, 8.2), "wood": 12, "parts": 12, "needs": "barge",
		"detail": "Powered slipway for building a hydrofoil and a tethered survey sub."},
}

const UPGRADES := {
	"pump": {"name": "Electric bilge pump", "wood": 0, "parts": 4, "cash": 12,
		"detail": "Clears bilge water automatically with power. A manual handle is always available."},
	"battery": {"name": "Battery bank", "wood": 0, "parts": 5, "cash": 16, "needs": "pump",
		"detail": "Adds onboard battery capacity and supports powered deck equipment."},
	"winch": {"name": "Deck winch", "wood": 2, "parts": 6, "cash": 20, "needs": "battery",
		"detail": "Raises tethered salvage. Use E at a salvage buoy to hook on."},
	"skiff": {"name": "Electric skiff", "wood": 7, "parts": 9, "cash": 26, "needs": "battery",
		"detail": "A faster, shallower boat for sheltered inlets. Launch from a landing."},
	"barge": {"name": "Crane barge", "wood": 10, "parts": 9, "cash": 30, "needs": "winch",
		"detail": "Tows a floating crane that can lift heavy crates and machine parts."},
	"sonar": {"name": "Survey sounder", "wood": 0, "parts": 7, "cash": 24, "needs": "battery", "surveys": 1,
		"detail": "Enables deepwater salvage and makes the survey readout more precise."},
	"foil": {"name": "Hydrofoil kit", "wood": 3, "parts": 13, "cash": 42, "needs": "skiff", "drydock": true,
		"detail": "Fits the electric skiff. Lifts clear of the waves at speed and draws extra charge."},
	"rov": {"name": "Survey submersible", "wood": 2, "parts": 14, "cash": 38, "needs": "sonar", "drydock": true,
		"detail": "Pilot a tethered camera, read the riverbed and recover submerged objects."},
}

const WORK := [
	{"name": "Fish for the marina", "kind": "fish", "home": 0, "reward": [12, 3, 1],
		"detail": "Land any two fish after accepting. You can release both."},
	{"name": "Pine Reach supply run", "kind": "freight", "home": 0, "dest": 1, "reward": [18, 4, 2],
		"detail": "Load a provision crate at the marina and deliver it to Pine Reach."},
	{"name": "Birch Point supply run", "kind": "freight", "home": 0, "dest": 2, "reward": [26, 5, 3],
		"detail": "Carry the marina's machine parts to Birch Point."},
	{"name": "Chart the open channel", "kind": "survey", "home": 0, "offset": Vector2(130, -115), "reward": [23, 4, 2],
		"detail": "Slow beside the green buoy and take a fish-finder reading with E. Opens the regional ferry."},
	{"name": "Give a stranded angler a tow", "kind": "rescue", "home": 0, "offset": Vector2(90, -165), "reward": [37, 7, 3],
		"detail": "Find the orange skiff, stop next to it and press E. Bring it back to the marina."},
	{"name": "Retrieve a lost tool crate", "kind": "salvage", "home": 2, "offset": Vector2(20, -105), "reward": [54, 8, 5],
		"needs": "winch", "detail": "Hook the marked crate with E and let the winch bring it aboard. Deliver at Birch Point."},
	{"name": "Heavy lift at Swisha", "kind": "salvage", "home": 3, "offset": Vector2(72, -65), "reward": [96, 14, 10],
		"needs": "barge", "detail": "Take the crane barge, lift the tailwater machinery and deliver it to Swisha."},
	{"name": "Chalk River depth survey", "kind": "survey", "home": 4, "offset": Vector2(16, -125), "reward": [48, 7, 4],
		"detail": "Log a deeper channel sounding at the Chalk River marker."},
	{"name": "Recover the lost survey recorder", "kind": "dive", "home": 4, "offset": Vector2(62, -133), "reward": [115, 16, 12],
		"needs": "rov", "detail": "Launch the tethered sub at the buoy, find the recorder and return it to Chalk River."},
	{"name": "Pine Reach species count", "kind": "fish", "home": 1, "reward": [31, 5, 3],
		"detail": "Log two different species around Pine Reach after accepting."},
	{"name": "Swisha to Chalk River freight", "kind": "freight", "home": 3, "dest": 4, "reward": [66, 10, 6],
		"detail": "Move a crate of hydro parts between the regional landings."},
	{"name": "Regional channel inspection", "kind": "survey", "home": 3, "offset": Vector2(118, -145), "skill": "expert_captain", "reward": [88, 12, 8], "detail": "Sound the channel by the inspection buoy and return with the readings."},
	{"name": "Contractor supply charter", "kind": "freight", "home": 1, "dest": 3, "skill": "trusted_contractor", "reward": [100, 11, 9], "detail": "Deliver workshop supplies from Pine Reach to Swisha."},
	{"name": "Private survey commission", "kind": "survey", "home": 2, "offset": Vector2(110, -138), "skill": "business_connections", "reward": [110, 13, 9], "detail": "Record a sounding for the dock owner and report back."},
]

static func dock_name(site: int) -> String:
	return SITES[site].name


static func requirement(id: String, records: Dictionary) -> bool:
	return id.is_empty() or records.has(id)
