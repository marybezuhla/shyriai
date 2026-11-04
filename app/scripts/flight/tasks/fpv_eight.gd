# SPDX-License-Identifier: GPL-3.0-or-later
# FPV lesson 3: two figure eights round two poles. Smooth arcs: lean, turn and throttle together.
extends FlightTask

const LIMIT := 90.0
const LEFT := Vector3(-6, 0, -15)
const RIGHT := Vector3(6, 0, -15)

var _t := 0.0


func setup_world() -> void:
	world.add_pole(LEFT)
	world.add_pole(RIGHT)
	var one: Array[Vector3] = [
		Vector3(0, 3, -15), Vector3(-6, 3, -19.5), Vector3(-10.5, 3, -15), Vector3(-6, 3, -10.5),
		Vector3(0, 3, -15), Vector3(6, 3, -19.5), Vector3(10.5, 3, -15), Vector3(6, 3, -10.5),
	]
	var pts: Array[Vector3] = []
	pts.append_array(one)
	pts.append_array(one)
	pts.append(Vector3(0, 3, -15))
	course(pts, 2.5, "")


func update(dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	if cp > 0:
		_t += dt
	if mode != "kids" and _t > LIMIT:
		cp = 0
		_t = 0.0
		say_for("HINT_FPV_EIGHT_SLOW")
		return
	var r := course_step(sim)
	progress = float(cp) / cps.size()
	if r == "done":
		pass_with("SUM_FPV_EIGHT", [int(ceil(_t))])
	elif sim.on_ground:
		say("HINT_FPV_THR_UP")
	else:
		say("HINT_FPV_EIGHT_GO", [cps.size() - cp])
