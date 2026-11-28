extends RefCounted

# Mounts are in the live houseboat's coordinates, with the deck at y = .75.
const COMPONENTS := {
	"pontoons": {"name": "Pontoons", "part": "Used pontoons", "tool": "", "time": 3.0, "at": Vector3(-1.54, .29, -1.75)},
	"port_rail": {"name": "Port railing", "part": "Welding wire", "tool": "welder", "time": 3.5, "at": Vector3(-1.43, 1.35, -2.87)},
	"starboard_rail": {"name": "Starboard railing", "part": "Welding wire", "tool": "welder", "time": 3.5, "at": Vector3(1.43, 1.35, -2.77)},
	"engine": {"name": "Outboard", "part": "Starter kit and plugs", "tool": "wrench", "time": 4.0, "at": Vector3(0, 1.38, 6.44)},
	"wiring": {"name": "Main wiring", "part": "Marine wire", "tool": "strippers", "time": 3.5, "at": Vector3(1.18, 1.52, .22)},
	"battery": {"name": "Battery", "part": "12 V battery", "tool": "strippers", "time": 3.5, "at": Vector3(1.16, 1.05, -.62)},
	"cabin_lights": {"name": "Cabin lights", "part": "Cabin lamp", "tool": "strippers", "time": 2.5, "at": Vector3(.45, 2.63, 1.98)},
	"nav_lights": {"name": "Navigation lights", "part": "Navigation lamps", "tool": "strippers", "time": 2.5, "at": Vector3(1.37, 1.55, -1.84)},
	"fuel_system": {"name": "Fuel system", "part": "Fuel and hose", "tool": "", "time": 3.0, "at": Vector3(-.92, 1.10, 8.15)},
}

const TOOLS := {
	"welder": "Welder", "wrench": "Wrench", "strippers": "Wire strippers",
	"princecraft": "Princecraft", "rod": "Old Fishing Rod",
	"transport": "Marina wagon", "fuel_can": "Fuel can",
}

const UPGRADES := {
	"solar": {"name": "Second-hand solar panel", "cash": 30, "parts": 3},
	"outboard": {"name": "Rebuilt high-output outboard", "cash": 45, "parts": 5},
}

static func repaired(state: Dictionary, component: String) -> bool:
	return float(state.get("components", {}).get(component, {}).get("condition", 0)) >= 1.0


static func install(state: Dictionary, component: String) -> void:
	state.components[component] = {"condition": 1.0, "installed": COMPONENTS[component].part}


static func all_repaired(state: Dictionary) -> bool:
	for component: String in COMPONENTS:
		if not repaired(state, component):
			return false
	return true


static func upgrade_installed(state: Dictionary, id: String) -> bool:
	return state.get("upgrades", {}).get(id, false) == true
