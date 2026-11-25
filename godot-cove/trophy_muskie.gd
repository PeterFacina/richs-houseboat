extends RefCounted

const DeepRiverMap = preload("res://deep_river_map.gd")
const Species = preload("res://fish_species.gd")
const SURVIVAL_CHANCE := .10
const LAST_RUN := 9.80
const RUN_SECONDS := 1.26
const SLICK_LIFE := 71.0
const DRAW_RADIUS := 8.0

var water: DeepRiverMap
var slick := Vector3.ZERO
var opened := -INF
var attracted := false
var ready_at := 0.0
var reported := false
var hooked := false
var line_holds := false


func _init(river: DeepRiverMap) -> void:
	water = river


func start_slick(at: Vector3, time: float) -> void:
	if time - opened < .42:
		slick = slick.lerp(at, .5)
		return
	slick = at
	opened = time
	ready_at = time + 5.2
	attracted = water.can_fish(at) and water.depth_at(at) >= 1.16
	reported = false


func update(delta: float, time: float) -> bool:
	if not is_finite(opened):
		return false
	var age := time - opened
	if age >= SLICK_LIFE:
		water.set_surface_slick(Vector4.ZERO)
		opened = -INF
		attracted = false
		reported = false
		return false
	var next := slick + water.downstream(slick, time) * delta
	if water.depth_at(next) >= .30:
		slick = next
	var fade := smoothstep(.0, .60, age) * (1.0 - smoothstep(48.0, SLICK_LIFE, age))
	water.set_surface_slick(Vector4(slick.x, slick.z, .49 + sqrt(age) * .27, fade))
	if attracted and not reported and time >= ready_at:
		reported = true
		return true
	return false


func draws_bait(at: Vector3, time: float) -> bool:
	return attracted and time < opened + SLICK_LIFE and slick.distance_squared_to(at) <= DRAW_RADIUS * DRAW_RADIUS


func can_bite(at: Vector3, time: float) -> bool:
	return time >= ready_at and draws_bait(at, time)


func circling(time: float) -> Vector3:
	var phase := (time - ready_at) * .76
	var point := slick + Vector3(cos(phase), 0, sin(phase)) * (2.2 + sin(phase * .62) * .65)
	if water.depth_at(point) < 1.09:
		point = slick
	point.y = -clampf(water.depth_at(point) * .44, .34, 1.39)
	return point


func echo(from: Vector3, time: float, draft: float) -> Vector2:
	if not attracted or time < ready_at:
		return Vector2.ZERO
	var ray := circling(time) - from
	if ray.y > -.17 or Vector2(ray.x, ray.z).length() > .65 + absf(ray.y) * .53:
		return Vector2.ZERO
	return Vector2(ray.length() + draft, .97)


func hook(draw: float) -> int:
	for index in Species.all().size():
		if Species.profile(index).name == "Muskellunge":
			hooked = true
			line_holds = draw < SURVIVAL_CHANCE
			attracted = false
			return index
	return -1


func strain_floor(fight_time: float) -> float:
	if not hooked or line_holds or fight_time < LAST_RUN:
		return 0.0
	return .83 + .42 * smoothstep(0.0, .42, fight_time - LAST_RUN)


func can_net(fight_time: float) -> bool:
	return not hooked or (line_holds and fight_time >= LAST_RUN + RUN_SECONDS)
