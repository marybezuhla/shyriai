# SPDX-License-Identifier: GPL-3.0-or-later
# FPV lesson 2: fly forward and turn. Leaning gives speed but takes height, so add throttle as you lean.
extends FlightTask

var _flying := false


func setup_world() -> void:
	var pts: Array[Vector3] = [Vector3(0, 4, -15), Vector3(-12, 4, -26), Vector3(6, 4, -32)]
	course(pts, 3.0, "")
	cp_height_tol = 2.0


func update(_dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	if not sim.on_ground:
		_flying = true
	elif _flying and cp > 0:
		# Touching the ground half-way counts as losing height: the route starts again.
		_flying = false
		cp = 0
		say_for("HINT_FPV_GROUND")
	var r := course_step(sim)
	progress = float(cp) / cps.size()
	if r == "done":
		pass_with("SUM_FPV_FORWARD")
	elif sim.on_ground:
		say("HINT_FPV_THR_UP")
	else:
		say("HINT_FPV_FORWARD_GO", [cps.size() - cp])
