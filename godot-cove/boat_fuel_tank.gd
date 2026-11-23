extends RefCounted

const Kit = preload("res://scenery.gd")
const Tools = preload("res://crew_tools.gd")


static func build(boat: Node3D, at: Vector3, marking := "FUEL") -> Marker3D:
	var tank := Node3D.new()
	tank.name = "MarineFuelTank"
	boat.add_child(tank)
	tank.position = at
	var red := Kit.paint(Color("#a53229"), .53)
	var metal := Kit.paint(Color("#a9ada4"), .36, .46)
	var rubber := Kit.paint(Color("#262724"), .82)
	Kit.box_at(tank, Vector3(0, .090, 0), Vector3(.34, .18, .46), red)
	Kit.box_at(tank, Vector3(0, .178, 0), Vector3(.31, .054, .42), red)
	for side: float in [-.112, .112]:
		Kit.box_at(tank, Vector3(side, .102, 0), Vector3(.024, .212, .468), rubber)
	Kit.box_at(tank, Vector3(0, .216, -.13), Vector3(.121, .025, .041), red)
	var throat := Vector3(-.046, .218, .103)
	Tools.tube(tank, throat - Vector3.UP * .018, throat, .049, .049, metal)
	Tools.tube(tank, throat, throat + Vector3.UP * .003, .031, .031, rubber)
	var label := Label3D.new()
	label.text = marking
	label.font_size = 32
	label.pixel_size = .0013
	label.outline_size = 0
	label.position = Vector3(0, .205, -.015)
	label.rotation.x = -PI * .5
	tank.add_child(label)
	var filler := Marker3D.new()
	filler.name = "FuelFiller"
	filler.position = throat + Vector3.UP * .007
	tank.add_child(filler)
	return filler
