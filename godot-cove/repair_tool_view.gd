extends Node3D

const Kit = preload("res://scenery.gd")
const Cable = preload("res://crew_tools.gd")
const Hands = preload("res://river_hands.gd")
const BASE := Vector3(.25, -.26, -.55)
const SOUNDS := {
	"welder": preload("res://deep_river/marina_fuel/flow.wav"),
	"wrench": preload("res://deep_river/marina_fuel/click.wav"),
	"strippers": preload("res://deep_river/marina_fuel/ding.wav"),
}

var models: Dictionary = {}
var audio := AudioStreamPlayer.new()
var sparks := CPUParticles3D.new()
var elapsed := 0.0
var sound_clock := 0.0


func setup() -> void:
	name = "RepairToolView"
	var metal := Kit.paint(Color("#89908a"), .56, .36)
	var grip := Kit.paint(Color("#323a3c"))
	var red := Kit.paint(Color("#ad5336"))
	var gold := Kit.paint(Color("#bf8d46"))
	for key: String in SOUNDS:
		var tool := Node3D.new()
		tool.name = key.capitalize()
		tool.position = BASE
		add_child(tool)
		models[key] = tool
		tool.hide()
		match key:
			"welder":
				Cable.tube(tool, Vector3(0, -.09, .07), Vector3(0, .035, -.12), .044, .039, grip)
				Cable.tube(tool, Vector3(0, .035, -.12), Vector3(0, .095, -.24), .022, .030, metal)
				Kit.box_at(tool, Vector3(0, .003, -.047), Vector3(.081, .09, .12), red).rotation.x = -.45
			"wrench":
				Kit.box_at(tool, Vector3(0, .037, -.085), Vector3(.050, .038, .26), metal).rotation.x = .16
				Kit.box_at(tool, Vector3(0, .061, -.200), Vector3(.089, .039, .059), metal)
				for side in [-1, 1]:
					Kit.box_at(tool, Vector3(.049 * side, .066, -.239), Vector3(.031, .037, .074), metal).rotation.y = side * .23
			"strippers":
				for side in [-1, 1]:
					Kit.box_at(tool, Vector3(side * .034, .02, .025), Vector3(.035, .04, .16), red).rotation.y = side * -.25
					Kit.box_at(tool, Vector3(side * .023, .027, -.087), Vector3(.032, .028, .109), metal).rotation.y = side * .16
				Kit.box_at(tool, Vector3(0, .048, -.032), Vector3(.058, .024, .061), gold)
		var hand := Hands.build(tool, 1.0, true)
		Hands.align(hand, Vector3(.026, -.030, .013), Basis.from_euler(Vector3(-.28, 0, -.24)))
	add_child(audio)
	audio.volume_db = -25.0
	audio.max_polyphony = 1
	set_up_sparks()


func set_up_sparks() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(.008, .008, .038)
	var glow := Kit.paint(Color("#ffc05c"))
	glow.emission_enabled = true
	glow.emission = Color("#ff9853")
	glow.emission_energy_multiplier = 2.0
	mesh.material = glow
	sparks.mesh = mesh
	sparks.amount = 22
	sparks.lifetime = .20
	sparks.direction = Vector3(-.2, .9, -.25)
	sparks.spread = 77
	sparks.gravity = Vector3(0, -5, 0)
	sparks.initial_velocity_min = .45
	sparks.initial_velocity_max = 1.65
	sparks.position = BASE + Vector3(-.04, .095, -.30)
	sparks.emitting = false
	add_child(sparks)


func update_view(tool_id: String, working: bool, delta: float) -> void:
	elapsed += delta
	for key: String in models:
		var tool: Node3D = models[key]
		tool.visible = key == tool_id
		if tool.visible:
			tool.position = BASE + Vector3(0, sin(elapsed * (16.0 if working else 2.5)) * (.024 if working else .006), 0)
			tool.rotation = Vector3(.16 * sin(elapsed * 14.0), .08 * cos(elapsed * 13.0), -.09) if working else Vector3.ZERO
	sparks.emitting = working and tool_id == "welder"
	if working and SOUNDS.has(tool_id):
		sound_clock -= delta
		if sound_clock <= 0.0:
			audio.stream = SOUNDS[tool_id]
			audio.pitch_scale = 1.22 if tool_id == "strippers" else 1.0
			audio.play()
			sound_clock = .52 if tool_id == "welder" else .38
	else:
		sound_clock = 0.0
		audio.stop()
