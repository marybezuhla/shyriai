# SPDX-License-Identifier: GPL-3.0-or-later
# What every lesson and mission of the plane shares: it starts in the air over the runway valley,
# warns when the wing is close to the stall, and can count how far the plane has turned.
class_name WingTask
extends FlightTask

## Most flying happens at this height over the ground.
const CRUISE_ALT := 30.0
## The nose at touchdown below this: flown onto the runway with no flare.
const NO_FLARE := deg_to_rad(-1.0)

## Kids: seconds with no ring passed before the plane starts to help.
const ASSIST_AFTER := 15.0

var _last_yaw := INF
var _stuck := 0.0


func start_position() -> Vector3:
	return Vector3(WorldLand.RUNWAY_X, CRUISE_ALT, -12.0)


## The wind blows from ahead of a heading, give or take a little: take-off and landing are into the
## wind, as on a real field. It is different on every flight: Simple a breeze, Adult up to a fresh
## wind with gusts.
func wind_from_ahead(sim: DroneSim, heading: float) -> void:
	var w := sim as WingSim
	if w == null or mode == "kids":
		return
	var r := RandomNumberGenerator.new()
	r.seed = task_seed
	var strength := r.randf_range(0.5, 1.5) if mode == "simple" else r.randf_range(1.5, 4.0)
	w.set_wind_from(heading + deg_to_rad(r.randf_range(-25.0, 25.0)), strength)
	w.p["gust"] = minf(float(w.p["gust"]), 0.35)  # gusts of a third either way, not more


## A point at a height over the ground, as a world position.
func over_ground(x: float, alt: float, z: float) -> Vector3:
	return Vector3(x, world.height(x, z) + alt, z)


## Says what the wing needs when it is slow or stalled. True if it said something.
func air_warnings(sim: DroneSim) -> bool:
	var w := sim as WingSim
	if w == null or mode == "kids" or w.on_ground:
		return false
	if w.stalled:
		say("HINT_WING_STALL")
		return true
	if w.stall_warn:
		say("HINT_WING_SLOW")
		return true
	return false


## How far the plane has turned since the last call, in radians; left is positive. Callers add it
## up with its sign, so S-turns cancel out and only real circles count.
func turned(sim: DroneSim) -> float:
	if _last_yaw == INF:
		_last_yaw = sim.yaw
		return 0.0
	var d := wrapf(sim.yaw - _last_yaw, -PI, PI)
	_last_yaw = sim.yaw
	return d


## Rings in the sky, from points given as (x, height over the ground, z). The hoops are drawn too.
func sky_rings(points: Array[Vector3], radius: float, color: Color) -> void:
	var abs_points: Array[Vector3] = []
	for p in points:
		abs_points.append(over_ground(p.x, p.y, p.z))
	var normals := normals_along(abs_points, start_position())
	for i in points.size():
		world.add_hoop(points[i], normals[i], color, radius)
		rings.append({"c": abs_points[i], "n": normals[i], "r": radius, "both": mode == "kids"})


## Kids: after a while with no ring passed, the plane is gently steered towards the next one
## while the stick is left alone. Call every step with whether a ring was just passed.
func kids_assist(sim: DroneSim, dt: float, passed: bool) -> void:
	var w := sim as WingSim
	if w == null or mode != "kids":
		return
	_stuck = 0.0 if passed else _stuck + dt
	w.assist = Vector3.INF
	if _stuck > ASSIST_AFTER and ring_i < rings.size():
		w.assist = rings[ring_i]["c"]
