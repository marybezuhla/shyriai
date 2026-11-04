# SPDX-License-Identifier: GPL-3.0-or-later
# UGV lesson 1: drive a winding dirt road. Each stick drives one track (Kids steer like a car).
# Leaving the road for more than a second ends the run (outside Kids mode).
extends FlightTask

const ROAD: Array[Vector3] = [
	Vector3(0, 0, 0), Vector3(0, 0, -8), Vector3(5, 0, -14), Vector3(5, 0, -22),
	Vector3(-3, 0, -28), Vector3(-3, 0, -36),
]
const OFF := 2.1  # m from the middle of the road

var _off := 0.0


func setup_world() -> void:
	world.add_road(ROAD, 3.4)
	var pts: Array[Vector3] = []
	for i in range(1, ROAD.size()):
		pts.append(ROAD[i] + Vector3(0, 0.8, 0))
	course(pts, 2.0, "")
	cp_height_tol = 5.0


static func road_distance(p: Vector3, road: Array[Vector3]) -> float:
	var best := INF
	var q := Vector2(p.x, p.z)
	for i in road.size() - 1:
		var a := Vector2(road[i].x, road[i].z)
		var b := Vector2(road[i + 1].x, road[i + 1].z)
		var t := clampf((q - a).dot(b - a) / maxf((b - a).length_squared(), 1e-4), 0.0, 1.0)
		best = minf(best, q.distance_to(a.lerp(b, t)))
	return best


func update(dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	var off := road_distance(sim.pos, ROAD) > OFF
	_off = _off + dt if off else 0.0
	if off and mode != "kids" and _off > 1.0:
		fail_with("FAIL_UGV_OFF")
		return
	var r := course_step(sim)
	beacon = 1.0
	progress = float(cp) / cps.size()
	if r == "done":
		pass_with("SUM_UGV_DRIVE")
	elif off:
		say("HINT_UGV_OFF")
	elif cp == 0 and sim.vel.length() < 0.1:
		say("HINT_UGV_START_TANK" if (sim is UgvSim and sim.tank) else "HINT_UGV_START_CAR")
	else:
		say("HINT_UGV_DRIVE_GO", [cps.size() - cp])
