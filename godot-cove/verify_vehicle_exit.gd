extends SceneTree

const Exit = preload("res://vehicle_exit.gd")


func _initialize() -> void:
	call_deferred("exercise")


func exercise() -> void:
	var ground := StaticBody3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(18, 1, 18)
	var collision := CollisionShape3D.new()
	collision.shape = ground_shape
	ground.add_child(collision)
	ground.position.y = 2.0
	root.add_child(ground)
	var vehicle := AnimatableBody3D.new()
	vehicle.position.y = 2.5
	root.add_child(vehicle)
	var player := CharacterBody3D.new()
	root.add_child(player)
	await physics_frame
	await physics_frame
	var level_exit := Exit.find(vehicle, player, Vector2(.8, 1.2), 0.0)
	var flat_ok := level_exit.is_finite() and is_equal_approx(level_exit.y, 2.605)

	ground.rotation.z = .22
	await physics_frame
	await physics_frame
	var sloped_exit := Exit.find(vehicle, player, Vector2(.6, 1.0), 0.0, true)
	var slope_ok := sloped_exit.is_finite() and absf(sloped_exit.y - level_exit.y) > .2

	ground.queue_free()
	await physics_frame
	await physics_frame
	var refused := not Exit.find(vehicle, player, Vector2(.8, 1.2), 0.0).is_finite()
	print("Vehicle exit on level ground, mower exit on slope, no-ground refusal: ", flat_ok, ", ", slope_ok, ", ", refused)
	quit(0 if flat_ok and slope_ok and refused else 1)
