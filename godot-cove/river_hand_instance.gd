extends Node3D

# Standalone MakeHuman / Godot XR Tools CC0 authored hand, with actual skinning
# and finger poses. No XR plugin, controllers or runtime download is needed.
const Kit = preload("res://scenery.gd")
const RichModel = preload("res://rich_model.gd")
const LEFT = preload("res://deep_river/hands/Hand_Nails_L.gltf")
const RIGHT = preload("res://deep_river/hands/Hand_Nails_R.gltf")
const ALBEDO = preload("res://deep_river/hands/caucasian_realistic_baseColor.png")
const NORMAL = preload("res://deep_river/hands/hands_normal.png")
const ORM = preload("res://deep_river/hands/hands_occlusionRoughnessMetallic.png")
const POSES := {"relaxed": "Default_pose", "fist": "Grip", "shaft": "Grip_Shaft", "carry": "Cup", "hold": "Hold", "pinch": "Pinch_Tight", "bottle": "Grip_2", "can": "Grip_3"}
var skeleton: Skeleton3D
var model: Node3D
var wrist_anchor := Vector3.ZERO
var side := 1.0
var current_pose := ""
var targets: Dictionary = {}
var established := false
static var skin: ORMMaterial3D
static var pose_cache: Dictionary = {}


func initialize(hand_side: float, sleeve: bool, pose: String, tool: bool) -> void:
	side = hand_side
	name = "RightHand" if side > 0 else "LeftHand"
	model = (RIGHT if side > 0 else LEFT).instantiate()
	add_child(model)
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	if skin == null:
		skin = ORMMaterial3D.new()
		skin.albedo_texture = ALBEDO
		skin.orm_texture = ORM
		skin.normal_enabled = true
		skin.normal_texture = NORMAL
		skin.normal_scale = .25
		skin.disable_receive_shadows = true
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = skin
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The source palm is edge-on. Rotate its back upwards, then orient a tool
	# grip across a shaft. Each hand uses its own mesh, never negative scaling.
	var orientation := Basis(Vector3.BACK, side * PI * .5)
	if tool:
		orientation = Basis(Vector3.UP, side * PI * .5) * orientation
		wrist_anchor = Vector3(side * .105, -.015, .091)
	model.basis = orientation
	var wrist_index := skeleton.find_bone("Wrist_" + ("R" if side > 0 else "L"))
	var source_wrist := skeleton.get_bone_global_rest(wrist_index).origin
	model.position = wrist_anchor - orientation * source_wrist
	set_pose(pose)
	for bone: int in targets:
		skeleton.set_bone_pose_rotation(bone, targets[bone])
	if tool:
		# Align the inside of the curled fingers with the prop grip, rather than
		# placing the wrist at the prop. The wrist anchor then drives the sleeve.
		var suffix := "R" if side > 0 else "L"
		var knuckle := skeleton.get_bone_global_pose(skeleton.find_bone("Middle_Proximal_" + suffix)).origin
		var tip := skeleton.get_bone_global_pose(skeleton.find_bone("Middle_Tip_" + suffix)).origin
		var grip_center := model.transform * knuckle.lerp(tip, .55)
		model.position += Vector3(0, -.015, .035) - grip_center
		wrist_anchor = model.transform * skeleton.get_bone_global_pose(wrist_index).origin
	established = true
	if sleeve:
		var cloth := Kit.paint(Color("#465653"), .89)
		var arm := RichModel.loft(self, [Vector4(-.5,.025,.023,.025), Vector4(-.3,.030,.027,.031),
			Vector4(0,.035,.030,.036), Vector4(.5,.043,.036,.043)], cloth, 20)
		var end := Vector3(side * .18, -.14, .38)
		var up := (end - wrist_anchor).normalized()
		var right := up.cross(Vector3.FORWARD).normalized()
		arm.transform = Transform3D(Basis(right, up * wrist_anchor.distance_to(end), right.cross(up)), (wrist_anchor + end) * .5)
		arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func set_pose(pose: String) -> void:
	if pose == current_pose or not is_instance_valid(skeleton):
		return
	current_pose = pose
	var path := "res://deep_river/hands/%s_%s.res" % ["right" if side > 0 else "left", POSES.get(pose, "Grip_Shaft")]
	if not pose_cache.has(path):
		pose_cache[path] = load(path)
	var animation: Animation = pose_cache[path]
	targets.clear()
	for track in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_ROTATION_3D:
			continue
		var bone_name := animation.track_get_path(track).get_subname(0)
		var bone := skeleton.find_bone(bone_name)
		if bone >= 0:
			targets[bone] = animation.rotation_track_interpolate(track, 0)


func _process(delta: float) -> void:
	if not established or not is_visible_in_tree():
		return
	var blend := 1.0 - exp(-delta * 16)
	for bone: int in targets:
		skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_pose_rotation(bone).slerp(targets[bone], blend))


func contact_point() -> Vector3:
	var suffix := "R" if side > 0 else "L"
	var first := "Thumb_Tip_" if current_pose == "pinch" else "Middle_Proximal_"
	var second := "Index_Tip_" if current_pose == "pinch" else "Middle_Tip_"
	var a := skeleton.get_bone_global_pose(skeleton.find_bone(first + suffix)).origin
	var b := skeleton.get_bone_global_pose(skeleton.find_bone(second + suffix)).origin
	return model.transform * a.lerp(b, .5 if current_pose == "pinch" else .55)
